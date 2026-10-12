/**
 * Story 20.3's two stop outcomes through the agent's confirm, in a real browser against the throwaway
 * instance (DW-2157, DW-2162; AD-14, AD-53, AD-62).
 *
 * What it pins: with the probe production running in `USER`, a stop the agent proposes and the person
 * confirms on the Productions list -- one that messages still queued leave Suspended, and one whose job
 * outlasts the stop's wait -- leaves the list the person stands on re-read without a reload and the
 * production's row marked changed. The first leg shows the new state (Suspended) on the row; the second shows
 * the row marked while it still reads Running, the state the production was left in. The two 409 codes the
 * confirm answers (`INTEROP.PRODUCTION.SUSPENDED`, `INTEROP.PRODUCTION.PARTSTOPPED`) are pinned server-side by
 * `OcuPilot.Test.InteropStopOutcome`, not here.
 *
 * **It compiles and runs a probe production in `USER`** through `OcuPilot.Test.ProductionProbe` and drives a
 * scripted agent turn (`OcuPilot.Test.TurnProvider`), so it runs on a throwaway only; the `after` hook settles
 * and removes the probe production, its classes and its messages, and sweeps the turn state, whatever the
 * tests answered. The unit tier covers the store's publication with a fake bus; this is the real runtime.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/interop-stop-confirm.browser-spec.mjs` (after
 * `npm run build` and the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { ROW_SELECTOR, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { signedInAt } from './panel-spec.mjs';
import { assertThrowaway } from './structural-walk.mjs';
import {
  armProbeDefinition,
  disarmProbeDefinition,
  escapeOs,
  forgetTag as sharedForgetTag,
  markerValue,
  nextTag as sharedNextTag,
  requireFreeSlot,
  runIris,
  scriptReply as sharedScriptReply,
  setTag as sharedSetTag,
} from './turnprobe-spec.mjs';

const config = browserConfig();
const probe = { container: config.container, marker: 'STOPCONF' };
const PROBE = 'OcuPilot.Test.ProductionProbe';
const CONTROL = 'OcuPilot.Test.InteropControl';
const PRODUCTION = 'OcuPilotProbe.Interop.Production';
const LIST_URL = '/ocupilot/interoperability/productions?ns=USER';
/** The stop tool's provider-side name: the canonical dotted name with underscores (AD-42). */
const TOOL_WIRE_NAME = 'interop_productions_stop';
const CHANGED_ROW = '.ocu-data-table-row-changed';
const READ_PATH = '/api/ocupilot/screens/interop.productions/read';
/** How long the operation holds each message in the Suspended leg, and how many messages it is sent. */
const HANG_SECONDS = 5;
const MESSAGES = 6;
/** How long the teardown operation waits in the partial-stop leg, longer than a stop's 15 second wait. */
const TEARDOWN_SECONDS = 22;
/** A stop waits up to 15 seconds, and the confirm is the slowest step of a leg. */
const CONFIRM_TIMEOUT_MS = 90000;

let browser = null;
let created = false;
let preparedId = '';
let priorDefault = '';

/** Run one probe expression in the throwaway, after the `pre` lines, and answer its marker value. */
function probeCall(name, expression, pre = []) {
  const output = runIris(config.container, [...pre, `Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** Whether a status expression is OK, as `1` or `0`, for a marker. */
const ok = (expression) => `$System.Status.IsOK(${expression})`;

/** Stop and settle the probe, wait for a stuck teardown to end, put the probe's items back, and assert it. */
function settle(name, waitSeconds = 0) {
  const pre = waitSeconds > 0 ? [`Hang ${waitSeconds}`] : [];
  const result = probeCall(name, `${ok(`##class(${PROBE}).Settle()`)}_${ok(`##class(${PROBE}).ResetProduction()`)}_${ok(`##class(${PROBE}).Settle()`)}`, pre);
  assert.equal(result.value, '111', `the probe production is settled and its items are as its class declares them: ${result.output}`);
}

/** Start the probe through the port, and let its jobs come up. */
function startProbe(name) {
  const result = probeCall(name, '$System.Status.IsOK(sc)', [`Set sc=##class(${CONTROL}).StartIt()`, 'Hang 3']);
  assert.equal(result.value, '1', `the probe production is started: ${result.output}`);
}

/** Queue `MESSAGES` messages to the probe operation, which holds each for `HANG_SECONDS`. */
function queueMessages(name) {
  const lines = [];
  for (let index = 0; index < MESSAGES; index += 1) lines.push(`Set sc${index}=##class(${PROBE}).Send()`);
  const joined = Array.from({ length: MESSAGES }, (_, index) => ok(`sc${index}`)).join('_');
  const result = probeCall(name, joined, lines);
  assert.equal(result.value, '1'.repeat(MESSAGES), `${MESSAGES} messages are queued: ${result.output}`);
}

/** Remove this user's proposals, so none outlives a leg. */
function dropProposals() {
  const output = runIris(config.container, [
    `Set sc=##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForUser("${escapeOs(config.username)}")`,
    `Write "OCU-STOPCONFDROP-START:"_$System.Status.IsOK(sc)_":OCU-STOPCONFDROP-END",!`,
  ]);
  assert.equal(markerValue(output, 'STOPCONFDROP'), '1', `the probe proposals are removed: ${output}`);
}

/** Clear the probe definition's read-only flag, so its write tool mints rather than refusing. */
function allowWrites() {
  const output = runIris(config.container, [
    `Set sc=##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly("${escapeOs(preparedId)}",0)`,
    `Write "OCU-STOPCONFRW-START:"_$System.Status.IsOK(sc)_":OCU-STOPCONFRW-END",!`,
  ]);
  assert.equal(markerValue(output, 'STOPCONFRW'), '1', `the probe definition allows writes: ${output}`);
}

/** A `tool_use` reply proposing the stop of the probe production. */
function proposeStopReply() {
  const input = {
    Name: PRODUCTION,
    rationale: 'The probe production should stop.',
    expectedImpact: 'the production reads Stopped',
  };
  return `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_stopconf", "name": "${TOOL_WIRE_NAME}", "input": ${JSON.stringify(input)}}])`;
}

function textReply(text) {
  return `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs(text)}")`;
}

const nextTag = () => sharedNextTag(probe);
const setTag = (tag) => sharedSetTag(probe, preparedId, tag);
const forgetTag = (tag) => sharedForgetTag(probe, tag);
const scriptReply = (tag, hangSeconds, bodyExpr) => sharedScriptReply(probe, tag, hangSeconds, bodyExpr);

/** The probe row's cells, or `null`. */
function probeRow(page) {
  return page.evaluate(
    (rowSelector, wanted) => {
      const row = Array.from(document.querySelectorAll(rowSelector)).find((node) => node.textContent.includes(wanted));
      return row === undefined ? null : Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim());
    },
    ROW_SELECTOR,
    PRODUCTION
  );
}

/** Wait until the probe row reads `status`, carrying the Changed tag when `changed`. */
async function waitForStatus(page, status, changed, timeout) {
  await page.waitForFunction(
    (rowSelector, changedSelector, wanted, word, needsChanged) => {
      const row = Array.from(document.querySelectorAll(rowSelector)).find((node) => node.textContent.includes(wanted));
      if (row === undefined) return false;
      const cells = Array.from(row.querySelectorAll('[role="gridcell"]'));
      if (cells[1]?.textContent.trim() !== word) return false;
      return !needsChanged || row.matches(changedSelector);
    },
    { timeout },
    ROW_SELECTOR,
    CHANGED_ROW,
    PRODUCTION,
    status,
    changed
  );
}

/**
 * A signed-in page standing on the Productions list with the probe row reading Running, and one live card
 * proposing its stop. `reads` collects the list reads the page issues from here on.
 */
async function listWithLiveStopCard(reads) {
  await requireFreeSlot(config);
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 0, proposeStopReply());
  scriptReply(tag, 0, textReply('done'));
  const { context, page } = await signedInAt(browser, config, LIST_URL);
  page.on('request', (request) => {
    if (new URL(request.url()).pathname === READ_PATH) reads.push(Date.now());
  });
  await waitForRows(page, config.navigationTimeoutMs);
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  await waitForStatus(page, 'Running', false, config.navigationTimeoutMs);
  await page.waitForFunction(() => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'), { timeout: config.navigationTimeoutMs });
  await page.type('#ocu-panel-composer', 'stop the probe production');
  await page.click('.ocu-panel-send');
  await page.waitForSelector('app-proposal-card .ocu-proposal-card-confirm', { timeout: config.navigationTimeoutMs });
  return { context, page, tag };
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec compiles and runs a probe production, so it runs only in a throwaway; ${config.container} is not one`);
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);
  const removed = probeCall('STOPCONFCLEAN', ok(`##class(${PROBE}).Remove()`));
  assert.equal(removed.value, '1', `an earlier run's probe is removed: ${removed.output}`);
  const made = probeCall('STOPCONFMADE', ok(`##class(${PROBE}).Create()`));
  assert.equal(made.value, '1', `the probe production is created: ${made.output}`);
  created = true;
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
  allowWrites();
  dropProposals();
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    if (config.container !== LIVE_CONTAINER) {
      await requireFreeSlot(config).catch(() => {});
      dropProposals();
      disarmProbeDefinition(probe, priorDefault);
      if (created && /-ci$/.test(config.container)) {
        const removed = probeCall('STOPCONFGONE', `${ok(`##class(${PROBE}).Remove()`)}_##class(${PROBE}).Gone()`);
        assert.equal(removed.value, '11', `the probe production is stopped and removed: ${removed.output}`);
      }
    }
  }
});

// DW-2157. Mutation (Rule 19): skip the `PRODUCTION_STATE_MOVED` publication in `TurnStore.decideProposal`'s
// error branch, rebuild and redeploy -> the row stays Running and this goes red.
test('DW-2157: an agent stop that leaves the production Suspended re-reads the Productions list, which then reads Suspended, marked', { timeout: 240000 }, async () => {
  settle('STOPCONFSA');
  assert.equal(probeCall('STOPCONFSH', ok(`##class(${PROBE}).SetHang(${HANG_SECONDS})`)).value, '1', `the operation holds each message ${HANG_SECONDS} seconds`);
  startProbe('STOPCONFSS');
  const reads = [];
  const { context, page, tag } = await listWithLiveStopCard(reads);
  try {
    assert.equal(await page.$(CHANGED_ROW), null, 'nothing is marked before the confirm, so the mark below is about this stop');
    // The messages go in just before the confirm, so they are still queued when the stop quiesces the production.
    queueMessages('STOPCONFSM');
    const readsBefore = reads.length;
    await page.click('.ocu-proposal-card-confirm');
    await waitForStatus(page, 'Suspended', true, CONFIRM_TIMEOUT_MS);
    assert.ok(reads.length > readsBefore, 'the list read again after the confirm, without a reload');
    const row = await probeRow(page);
    assert.equal(row?.[1], 'Suspended', `the row reads the state the production was left in: ${JSON.stringify(row)}`);
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
  }
});

// DW-2162. Mutation (Rule 19): as above -> the row is never marked and this goes red.
test('DW-2162: an agent stop whose job outlasts the wait re-reads the Productions list, which marks the row and still reads Running', { timeout: 240000 }, async () => {
  settle('STOPCONFPA');
  const armed = probeCall('STOPCONFPT', ok(`##class(${PROBE}).AddTearItem(${TEARDOWN_SECONDS})`));
  assert.equal(armed.value, '1', `an operation whose teardown waits ${TEARDOWN_SECONDS} seconds is added: ${armed.output}`);
  startProbe('STOPCONFPS');
  const reads = [];
  const { context, page, tag } = await listWithLiveStopCard(reads);
  try {
    assert.equal(await page.$(CHANGED_ROW), null, 'nothing is marked before the confirm');
    const readsBefore = reads.length;
    await page.click('.ocu-proposal-card-confirm');
    await page.waitForSelector(CHANGED_ROW, { timeout: CONFIRM_TIMEOUT_MS });
    assert.ok(reads.length > readsBefore, 'the list read again after the confirm, without a reload');
    const row = await probeRow(page);
    assert.ok(row?.[0].startsWith(PRODUCTION), `the marked row is the production that was stopped: ${JSON.stringify(row)}`);
    assert.equal(row?.[1], 'Running', `and it reads the state the production was left in: ${JSON.stringify(row)}`);
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
    // The stuck job ends by itself; the probe is settled and restored once it has.
    settle('STOPCONFPZ', TEARDOWN_SECONDS);
  }
});

/**
 * Story 5.12 end to end in a real browser against the throwaway instance: the agent proposes
 * suspending one process, the user confirms, and the Processes list re-fetches and highlights that
 * row -- with the card's one state row, NFR-1's two-second budget, and the auto-refresh paused
 * while the proposal is live, on the list and on Process details.
 *
 * **It suspends a process.** It refuses outright to run outside a throwaway, it starts and
 * suspends a process of its own -- `OcuPilot.Test.ProcessControl`'s probe, owned by that class's
 * own account -- and never a daemon, the Task Manager, a Work Queue worker or `WRTDMN`, which
 * `processes.browser-spec.mjs` uses as its own selection anchor. Its `after` hook resumes and ends
 * that process whatever happened above.
 *
 * **What only a browser can answer here:** the card as drawn, NFR-1's budget measured on the
 * rendered page, and the auto-refresh chip. Everything about the write itself is
 * `OcuPilot.Test.ProcessControl`'s.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then re-run the installer and `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=...
 * node --test browser/process-control.browser-spec.mjs`. A spec run against a bundle that was not
 * rebuilt reads the old client and proves nothing.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { signedInAt } from './panel-spec.mjs';
import { filterToSubset, viewCount, waitForRows } from './list-spec.mjs';
import {
  armProbeDefinition,
  disarmProbeDefinition,
  escapeOs,
  forgetTag as sharedForgetTag,
  markerValue,
  nextTag as sharedNextTag,
  requireFreeSlot,
  runIris as sharedRunIris,
  scriptReply as sharedScriptReply,
  setTag as sharedSetTag,
} from './turnprobe-spec.mjs';

const config = browserConfig();
const probe = { container: config.container, marker: 'PROCCTL' };
const STRINGS = loadStrings();

const LIST_URL = '/ocupilot/os-management/processes?ns=HSCUSTOM';

/** Process details for `pid`, at the route the registry declares for it (AD-5, AD-13). */
const detailsUrl = (pid) => `/ocupilot/os-management/processes/details/${encodeURIComponent(pid)}?ns=HSCUSTOM`;

/** The two tools' provider-side names: the canonical dotted names with underscores (AD-42). */
const SUSPEND_WIRE_NAME = 'osmgmt_processes_suspend';

/** NFR-1's budget for a confirmed write's screen refresh. */
const HIGHLIGHT_BUDGET_MS = 2000;

/**
 * How long the leg waits for the highlight, deliberately longer than the budget it asserts: a wait
 * that timed out at the budget would make the budget assertion unreachable.
 */
const HIGHLIGHT_WAIT_MS = HIGHLIGHT_BUDGET_MS * 5;

const CHANGED_ROW = '.ocu-data-table-row-changed';

let browser = null;
let preparedId = '';
let priorDefault = '';
let probePid = '';

before(async () => {
  assert.notEqual(
    config.container,
    LIVE_CONTAINER,
    'this spec suspends a process, so it never runs inside the live container'
  );
  // And never inside an owner-managed slot instance either, which `notEqual(LIVE_CONTAINER)` does
  // not exclude. Throwaways are the only containers whose names end `-ci`
  // (`scripts/ci-throwaway.sh`).
  assert.match(
    config.container,
    /-ci$/,
    `this spec suspends a process on the instance, so it runs only in a throwaway; ${config.container} is not one`
  );
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);
  browser = await puppeteer.launch(launchOptions(config));
  // A crashed prior run leaves its scripted replies behind, and `nextTag`'s counter is per
  // process: the next run's first turn would be answered by the previous run's reply, naming a
  // process that no longer exists. Forget the whole range this file can reach before arming.
  for (let n = 1; n <= 12; n += 1) sharedForgetTag(probe, `${probe.marker}${n}`);
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
  // Cleared here rather than relying on the definition default; under read-only no proposal is minted (AD-30).
  allowWrites();
  dropProposals();
  probePid = startProbeProcess();
  assert.notEqual(probePid, '', 'a probe process of this suite own exists for this spec to suspend');
});

after(async () => {
  if (browser !== null) await browser.close();
  // The same test the `before` guard applies, in the same direction: a run refused there must not
  // have this hook end a process in a container the spec never touched.
  if (!/-ci$/.test(config.container)) return;
  // Unconditional and first: a suspended process holds every lock it had, and the rest of the
  // browser suite runs after this file.
  if (probePid !== '') stopProbeProcess(probePid);
  if (browser !== null) {
    await requireFreeSlot(config).catch(() => {});
    dropProposals();
    disarmProbeDefinition(probe, priorDefault);
  }
});

function runIris(lines) {
  return sharedRunIris(config.container, lines);
}

const nextTag = () => sharedNextTag(probe);
const setTag = (tag) => sharedSetTag(probe, preparedId, tag);
const forgetTag = (tag) => sharedForgetTag(probe, tag);

function scriptReply(tag, hangSeconds, bodyExpr) {
  sharedScriptReply(probe, tag, hangSeconds, bodyExpr);
}

/** Clear the probe definition's read-only flag, so its write tool mints rather than refusing. */
function allowWrites() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly("${escapeOs(preparedId)}",0)`,
    `Write "OCU-PCRW-START:"_$System.Status.IsOK(sc)_":OCU-PCRW-END",!`,
  ]);
  assert.equal(markerValue(output, 'PCRW'), '1', `the probe definition allows writes: ${output}`);
}

/** Remove every proposal this spec's own principal has minted. */
function dropProposals() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForUser("${escapeOs(config.username)}")`,
    `Write "OCU-PCDROP-START:"_$System.Status.IsOK(sc)_":OCU-PCDROP-END",!`,
  ]);
  assert.equal(markerValue(output, 'PCDROP'), '1', `the probe proposals are removed: ${output}`);
}

/**
 * Start this spec's own probe process and answer its pid.
 *
 * It is `OcuPilot.Test.ProcessControl`'s process and its helpers, called rather than copied, so
 * the browser leg and the instance suite act on one thing and end it one way.
 */
function startProbeProcess() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.ProcessControl).EnsureProbeOwner()`,
    `Write "OCU-PCPID-START:"_$Select($System.Status.IsOK(sc):##class(OcuPilot.Test.ProcessControl).StartProbeProcess(),1:"")_":OCU-PCPID-END",!`,
  ]);
  return markerValue(output, 'PCPID') ?? '';
}

/** Resume and end the probe process, and remove the account it ran as. */
function stopProbeProcess(pid) {
  runIris([
    `Do ##class(OcuPilot.Test.ProcessControl).StopProbeProcess("${escapeOs(pid)}")`,
    `Do ##class(OcuPilot.Test.ProcessControl).RemoveProbeOwner()`,
    `Write "OCU-PCEND-START:"_##class(OcuPilot.Test.ProcessControl).ProcessState("${escapeOs(pid)}")_":OCU-PCEND-END",!`,
  ]);
}

/** Put the probe process back into the running state. */
function resumeProbeProcess(pid) {
  const output = runIris([
    `Do ##class(OcuPilot.Test.ProcessControl).ResumeProcess("${escapeOs(pid)}")`,
    `Write "OCU-PCRES-START:"_##class(OcuPilot.Test.ProcessControl).ProcessState("${escapeOs(pid)}")_":OCU-PCRES-END",!`,
  ]);
  assert.ok(
    !(markerValue(output, 'PCRES') ?? '').includes('SUSP'),
    `the probe process is running again: ${output}`
  );
}

/** The instance's own `State` for the probe process, or `''` when it carries no such process. */
function processState(pid) {
  const output = runIris([
    `Write "OCU-PCSTATE-START:"_##class(OcuPilot.Test.ProcessControl).ProcessState("${escapeOs(pid)}")_":OCU-PCSTATE-END",!`,
  ]);
  return markerValue(output, 'PCSTATE') ?? '';
}

/**
 * The `tool_result` content the turn under `tag` sent back to the model on its second provider
 * call -- where a refusal's own `detail.problem` is.
 */
function lastToolResult(tag) {
  const output = runIris([
    `Write "OCU-PCRES2-START:"_##class(OcuPilot.Test.TurnProvider).Recorded("${escapeOs(tag)}",2,"messages")_":OCU-PCRES2-END",!`,
  ]);
  return markerValue(output, 'PCRES2') ?? '';
}

function textReply(text) {
  return `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs(text)}")`;
}

/** A `tool_use` reply proposing the suspend of process `pid`. */
function proposeReply(pid) {
  const input = {
    Pid: pid,
    rationale: 'The process is running a loop nobody is waiting on.',
    expectedImpact: 'it stops where it is until somebody resumes it',
    reverse: 'propose resuming it',
  };
  return `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_suspend", "name": "${SUSPEND_WIRE_NAME}", "input": ${JSON.stringify(input)}}])`;
}

/**
 * Narrow the Processes list to the probe process's own row, matched on its `Pid` cell -- the
 * screen's first column and its name column.
 *
 * **The filter is what makes the row readable at all.** `data-table.ts` virtualises, so an
 * instance running dozens of processes renders a window of rows the probe's need not be in; the
 * filter is also what keeps it in the window across the confirm's re-fetch, which preserves it.
 */
async function showProbeRow(page) {
  await waitForRows(page, config.navigationTimeoutMs);
  const total = await viewCount(page);
  assert.ok(total > 1, `the processes list answers more than one row: ${total}`);
  await filterToSubset(page, {
    text: probePid,
    expectRow: probePid,
    total,
    timeoutMs: config.navigationTimeoutMs,
  });
}

/** Wait until Process details draws its fields; the route it was opened on names the probe's pid. */
async function showProbeDetails(page) {
  await page.waitForSelector('.ocu-details-fields', { timeout: config.navigationTimeoutMs });
}

/**
 * Turn the screen's auto-refresh on, by cycling the command-bar chip off its published `off`
 * literal. The chip reads the setting the user chose, and "off wins over paused"
 * (`core/refresh.ts`), so a pause is only observable on a screen whose timer is running.
 */
async function enableAutoRefresh(page) {
  await page.waitForSelector('.ocu-command-bar-refresh', { timeout: config.navigationTimeoutMs });
  await page.click('.ocu-command-bar-refresh');
  await page.waitForFunction(
    (off) => (document.querySelector('.ocu-command-bar-refresh')?.textContent ?? '').trim() !== off,
    { timeout: config.navigationTimeoutMs },
    STRINGS.statusAutoRefreshOff
  );
}

/**
 * A signed-in page standing on `url` -- the Processes list unless told otherwise -- with one live
 * suspend card; `show` waits until that screen shows the probe process.
 */
async function screenWithLiveCard({ withRefresh = false, url = LIST_URL, show = showProbeRow } = {}) {
  await requireFreeSlot(config);
  resumeProbeProcess(probePid);
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 0, proposeReply(probePid));
  scriptReply(tag, 0, textReply('done'));
  const { context, page } = await signedInAt(browser, config, url);
  await show(page);
  if (withRefresh) await enableAutoRefresh(page);
  await page.waitForFunction(
    () => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'),
    { timeout: config.navigationTimeoutMs }
  );
  await page.type('#ocu-panel-composer', 'suspend the probe process');
  await page.click('.ocu-panel-send');
  try {
    await page.waitForSelector('app-proposal-card .ocu-proposal-card-confirm', {
      timeout: config.navigationTimeoutMs,
    });
  } catch (err) {
    // This helper throws before its caller can bind `tag`, so its caller's own `finally` never
    // runs: the cleanup is here, on the one path that reaches it.
    const state = await page.evaluate(() => ({
      cards: Array.from(document.querySelectorAll('app-tool-call-card')).map((card) =>
        (card.textContent ?? '').replace(/\s+/g, ' ').trim()
      ),
      lockBanner: document.querySelector('[data-slot="lock"] .ocu-banner[role="status"]') !== null,
      reply: document.querySelector('app-reply')?.textContent?.trim() ?? null,
    }));
    const result = lastToolResult(tag);
    const state2 = processState(probePid);
    await context.close();
    forgetTag(tag);
    dropProposals();
    throw new Error(
      `no proposal card appeared; the panel showed ${JSON.stringify(state.cards)}, reply ` +
        `${JSON.stringify(state.reply)}, ${state.lockBanner ? 'a TURN.BUSY lock banner' : 'no lock banner'}, ` +
        `process ${probePid} State ${JSON.stringify(state2)}, tool result ${JSON.stringify(result)} ` +
        `(underlying: ${err.message})`
    );
  }
  return { context, page, tag };
}

test('AC1: the card carries one state row, and the confirmed suspend re-fetches and highlights inside the budget', async () => {
  // Mutation (Rule 19): drop the `StateDiff` push in `OcuPilot.Screen.Tool.ProcessSuspend` -> the
  // card has no row and the diff assertion goes red; make `Confirm.ToolSendsBody` answer 1 -> the
  // port is given a body the vendor SUSPEND does not read and the write leg goes red; set that
  // tool's `DESTRUCTIVE` to 1 -> the card draws the destructive bar and the treatment assertion
  // goes red.
  const { context, page, tag } = await screenWithLiveCard();
  try {
    const drawn = await page.evaluate(() => ({
      destructive: document
        .querySelector('app-proposal-card .ocu-proposal-card')
        .classList.contains('ocu-proposal-card-destructive'),
      diff: Array.from(document.querySelectorAll('.ocu-diff-row:not(.ocu-diff-row-unchanged)')).map((row) =>
        (row.textContent ?? '').replace(/\s+/g, ' ').trim()
      ),
      unchanged: document.querySelector('.ocu-proposal-card-unchanged') !== null,
    }));
    assert.equal(drawn.diff.length, 1, `the card carries exactly one row: ${JSON.stringify(drawn.diff)}`);
    assert.ok(drawn.diff[0].includes('State'), `labelled State: ${drawn.diff[0]}`);
    assert.ok(drawn.diff[0].includes('Running'), `moving from Running: ${drawn.diff[0]}`);
    assert.ok(drawn.diff[0].includes('Suspended'), `to Suspended: ${drawn.diff[0]}`);
    assert.equal(drawn.unchanged, false, 'and no unchanged-fields caption, because no body is sent');
    assert.equal(
      drawn.destructive,
      false,
      'a suspend draws the ordinary Confirm treatment: proposing the resume puts the process back'
    );
    assert.equal(await page.$(CHANGED_ROW), null, 'nothing is highlighted before the confirm');

    await page.click('.ocu-proposal-card-confirm');
    // The clock starts at the earliest instant the browser can know the write completed, which is
    // also the instant the publisher fires.
    await page.waitForSelector('app-proposal-card .ocu-proposal-card-status', {
      timeout: config.navigationTimeoutMs,
    });
    const startedAt = Date.now();
    await page.waitForSelector(CHANGED_ROW, { timeout: HIGHLIGHT_WAIT_MS });
    const elapsed = Date.now() - startedAt;
    // Printed on a green run too: a budget assertion that only speaks when it fails leaves the
    // margin invisible.
    console.log(`process-control: the row carried the highlight ${elapsed} ms after the status line`);
    assert.ok(
      elapsed <= HIGHLIGHT_BUDGET_MS,
      `the re-fetch and highlight land inside NFR-1's ${HIGHLIGHT_BUDGET_MS} ms budget, took ${elapsed} ms`
    );
    const highlighted = await page.evaluate(
      (changed) => (document.querySelector(changed)?.querySelector('[role="gridcell"]')?.textContent ?? '').trim(),
      CHANGED_ROW
    );
    assert.ok(
      highlighted.startsWith(probePid),
      `the highlighted row is the suspended process, with the table's own Changed tag after its pid: ${highlighted}`
    );

    // The instance itself: the bodyless SUSPEND landed.
    assert.ok(processState(probePid).includes('SUSP'), 'the instance reports that process suspended');
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
    resumeProbeProcess(probePid);
  }
});

test('AC7, AD-43: Processes pauses its auto-refresh while the process proposal is live, and resumes on close', async () => {
  // Mutation (Rule 19): drop the `proposal-open` subscription in `ui/src/app/core/refresh.ts` ->
  // the chip never appears and this goes red.
  const { context, page, tag } = await screenWithLiveCard({ withRefresh: true });
  try {
    await page.waitForFunction(
      (sentence) =>
        (document.querySelector('.ocu-command-bar-refresh')?.textContent ?? '').includes(sentence) &&
        document.querySelector('.ocu-command-bar-refresh')?.getAttribute('data-paused') === 'true',
      { timeout: config.navigationTimeoutMs },
      STRINGS.statusAutoRefreshPaused
    );
    await page.click('.ocu-proposal-card-cancel');
    await page.waitForFunction(
      (sentence) =>
        !(document.querySelector('.ocu-command-bar-refresh')?.textContent ?? '').includes(sentence),
      { timeout: config.navigationTimeoutMs },
      STRINGS.statusAutoRefreshPaused
    );
    assert.ok(
      !processState(probePid).includes('SUSP'),
      'and the cancelled proposal left the process running'
    );
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
    resumeProbeProcess(probePid);
  }
});

test('AC7, AD-43: Process details pauses its auto-refresh while the process proposal is live, and resumes on close', async () => {
  // Mutation (Rule 19): make `ui/src/app/core/refresh.ts` ignore `proposal-open` for a screen that
  // declares a `parentScope` -> the chip never reads paused here, while the list leg above stays green.
  const { context, page, tag } = await screenWithLiveCard({
    withRefresh: true,
    url: detailsUrl(probePid),
    show: showProbeDetails,
  });
  try {
    await page.waitForFunction(
      (sentence) =>
        (document.querySelector('.ocu-command-bar-refresh')?.textContent ?? '').includes(sentence) &&
        document.querySelector('.ocu-command-bar-refresh')?.getAttribute('data-paused') === 'true',
      { timeout: config.navigationTimeoutMs },
      STRINGS.statusAutoRefreshPaused
    );
    await page.click('.ocu-proposal-card-cancel');
    // Resumed, not merely unpaused: the chip is still there and reads the running form
    // ("every <n> s"), never the off literal.
    await page.waitForFunction(
      ([paused, off, onPrefix]) => {
        const chip = document.querySelector('.ocu-command-bar-refresh');
        if (chip === null || chip.getAttribute('data-paused') === 'true') return false;
        const text = (chip.textContent ?? '').trim();
        return !text.includes(paused) && text !== off && text.startsWith(onPrefix);
      },
      { timeout: config.navigationTimeoutMs },
      [STRINGS.statusAutoRefreshPaused, STRINGS.statusAutoRefreshOff, STRINGS.statusAutoRefreshOn.split('<n>')[0]]
    );
    assert.ok(
      !processState(probePid).includes('SUSP'),
      'and the cancelled proposal left the process running'
    );
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
    resumeProbeProcess(probePid);
  }
});

/**
 * DW-1406, in a real browser (QA follow-up to Story 5.7).
 *
 * `change-highlight.browser-spec.mjs` writes to `/csp/ocupilotprobeconfirm`, which is already
 * canonical -- folding it changes nothing, so a browser leg built on it cannot tell a
 * `DataTable.viewKeyFor` that resolves the bus id through the view's row keys from one that
 * compares the raw id verbatim. The review's own HIGH finding was exactly this gap: `Mint` stores
 * a folded `targetRef`, but `Security.Applications` keeps a name's case exactly as created, so a
 * write to a non-canonically-spelled application produced no highlight, no scroll, no
 * announcement and no toast, with every existing test green. The fix was pinned at the component
 * tier with a mixed-case row key (`data-table.spec.ts`); this is the end-to-end path that defect
 * actually traveled, run against the deployed bundle rather than a mocked store.
 *
 * `OcuPilot.Test.ProposalFixture.EnsureMixedCaseWriteTarget` creates
 * `/csp/OcuPilotProbeConfirmMixedCase` -- its own application, spelled with mixed case at
 * creation, case-preserved by `Security.Applications` and distinct from
 * `change-highlight.browser-spec.mjs`'s canonical target, so the two specs' fixtures cannot
 * collide even run back to back.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test
 * browser/change-highlight-noncanonical.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { signedInAt } from './panel-spec.mjs';
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
// A marker prefix distinct from CHGHL (change-highlight.browser-spec.mjs), so the two files'
// probe tags and definitions never collide if a future run drops --test-concurrency=1.
const probe = { container: config.container, marker: 'CHGHLNC' };
const STRINGS = loadStrings();

const LIST_URL = '/ocupilot/web-applications/list?ns=HSCUSTOM';

/** This spec's own web application -- mixed case at creation (DW-1406). Created and deleted here. */
const TARGET = '/csp/OcuPilotProbeConfirmMixedCase';

const TOOL_WIRE_NAME = 'webapp_list_update';
const HIGHLIGHT_BUDGET_MS = 2000;
const HIGHLIGHT_WAIT_MS = HIGHLIGHT_BUDGET_MS * 5;
const COLUMN_LABEL = STRINGS.tableColumnEnabled;

const ROW_SELECTOR = '[role="grid"] .ocu-data-table-body [role="row"]';
const CHANGED_ROW = '.ocu-data-table-row-changed';

let browser = null;
let preparedId = '';
let priorDefault = '';

before(async () => {
  assert.notEqual(
    config.container,
    LIVE_CONTAINER,
    'this spec makes a real confirmed write, so it never runs inside the live container'
  );
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);
  browser = await puppeteer.launch(launchOptions(config));
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
  allowWrites();
  ensureTarget();
  dropProposals();
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  await requireFreeSlot(config).catch(() => {});
  dropProposals();
  removeTarget();
  disarmProbeDefinition(probe, priorDefault);
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

function allowWrites() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly("${escapeOs(preparedId)}",0)`,
    `Write "OCU-CHGHLNCRW-START:"_$System.Status.IsOK(sc)_":OCU-CHGHLNCRW-END",!`,
  ]);
  assert.equal(markerValue(output, 'CHGHLNCRW'), '1', `the probe definition allows writes: ${output}`);
}

function ensureTarget() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.ProposalFixture).EnsureMixedCaseWriteTarget($Namespace,.created)`,
    `Write "OCU-CHGHLNCAPP-START:"_$System.Status.IsOK(sc)_":OCU-CHGHLNCAPP-END",!`,
  ]);
  assert.equal(markerValue(output, 'CHGHLNCAPP'), '1', `the probe application is created: ${output}`);
}

function removeTarget() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.ProposalFixture).RemoveMixedCaseWriteTarget()`,
    `Write "OCU-CHGHLNCDEL-START:"_$System.Status.IsOK(sc)_":OCU-CHGHLNCDEL-END",!`,
  ]);
  assert.equal(markerValue(output, 'CHGHLNCDEL'), '1', `the probe application is removed: ${output}`);
}

/** The target's stored `Enabled`, read from the instance -- so each run proposes a real change. */
function storedEnabled() {
  const output = runIris([
    `Write "OCU-CHGHLNCVAL-START:"_##class(OcuPilot.Test.ProposalFixture).MixedCaseWriteTargetField("Enabled")_":OCU-CHGHLNCVAL-END",!`,
  ]);
  return markerValue(output, 'CHGHLNCVAL') ?? '';
}

function dropProposals() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForUser("${escapeOs(config.username)}")`,
    `Write "OCU-CHGHLNCDROP-START:"_$System.Status.IsOK(sc)_":OCU-CHGHLNCDROP-END",!`,
  ]);
  assert.equal(markerValue(output, 'CHGHLNCDROP'), '1', `the probe proposals are removed: ${output}`);
}

/**
 * A `tool_use` reply proposing `enabled` on this spec's own application, addressed by its
 * mixed-case spelling -- the exact spelling the row will render, which is the point.
 */
function proposeReply(enabled) {
  const input = {
    Name: TARGET,
    Enabled: enabled,
    rationale: 'The application is serving when it should not be.',
    expectedImpact: 'the list reports it as not enabled',
    reverse: 'set it back',
  };
  return `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_chghlnc", "name": "${TOOL_WIRE_NAME}", "input": ${JSON.stringify(input)}}])`;
}

function textReply(text) {
  return `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs(text)}")`;
}

async function waitForTargetRow(page) {
  await page.waitForFunction(
    (selector, path) =>
      [...document.querySelectorAll(selector)].some((row) => (row.textContent ?? '').includes(path)),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    TARGET
  );
}

async function listWithLiveCard(enabled) {
  await requireFreeSlot(config);
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 0, proposeReply(enabled));
  scriptReply(tag, 0, textReply('done'));
  const { context, page } = await signedInAt(browser, config, LIST_URL);
  await waitForTargetRow(page);
  await page.waitForFunction(
    () => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'),
    { timeout: config.navigationTimeoutMs }
  );
  await page.type('#ocu-panel-composer', 'stop the mixed-case probe application serving');
  await page.click('.ocu-panel-send');
  await page.waitForSelector('app-proposal-card .ocu-proposal-card-confirm', {
    timeout: config.navigationTimeoutMs,
  });
  return { context, page, tag };
}

function changedRowCells(changed, label) {
  const row = document.querySelector(changed);
  if (row === null) return null;
  const headers = [...document.querySelectorAll('[role="columnheader"] .ocu-data-table-header-label')].map(
    (header) => (header.textContent ?? '').trim()
  );
  const cells = [...row.querySelectorAll('[role="gridcell"]')].map((cell) => (cell.textContent ?? '').trim());
  return { at: headers.indexOf(label), cells };
}

function writtenCellReads(changed, label, want) {
  const row = document.querySelector(changed);
  if (row === null) return false;
  const headers = [...document.querySelectorAll('[role="columnheader"] .ocu-data-table-header-label')].map(
    (header) => (header.textContent ?? '').trim()
  );
  const at = headers.indexOf(label);
  if (at < 0) return false;
  const cells = [...row.querySelectorAll('[role="gridcell"]')].map((cell) => (cell.textContent ?? '').trim());
  return cells[at] === want;
}

test(
  'DW-1406: a confirmed write against a non-canonically-spelled application still highlights ' +
    'that row, scrolled into view, within the budget',
  async () => {
    // Mutation (Rule 19): `DataTable.viewKeyFor` answers an exact `lastKeys` hit or `''` (the
    // pre-patch shape) -> the row this spec writes to is spelled `/csp/OcuPilotProbeConfirmMixedCase`
    // in the view but the bus carries the folded `/csp/ocupilotprobeconfirmmixedcase`, so the
    // comparison misses and the wait below times out at HIGHLIGHT_WAIT_MS. This is the exact
    // defect DW-1406 named; the canonical-target spec (`change-highlight.browser-spec.mjs`) cannot
    // exercise it because folding its target changes nothing.
    const before = storedEnabled();
    const proposed = before !== '1';
    const { context, page, tag } = await listWithLiveCard(proposed);
    try {
      assert.equal(
        await page.$(CHANGED_ROW),
        null,
        'nothing is highlighted before the confirm, so the assertion below is about this write'
      );

      await page.click('.ocu-proposal-card-confirm');
      await page.waitForSelector('app-proposal-card .ocu-proposal-card-status', {
        timeout: config.navigationTimeoutMs,
      });
      const startedAt = Date.now();
      await page.waitForSelector(CHANGED_ROW, { timeout: HIGHLIGHT_WAIT_MS });
      const elapsed = Date.now() - startedAt;
      console.log(`change-highlight-noncanonical: the row carried the highlight ${elapsed} ms after the status line`);

      const shown = await page.evaluate(
        (changed, tagText, path) => {
          const row = document.querySelector(changed);
          return {
            text: (row?.textContent ?? '').trim(),
            tagged: (row?.textContent ?? '').includes(tagText),
            spelledAsCreated: (row?.textContent ?? '').includes(path),
          };
        },
        CHANGED_ROW,
        STRINGS.tableChangedTag,
        TARGET
      );

      assert.ok(
        shown.spelledAsCreated,
        `the highlighted row is rendered in the case-preserved spelling the instance created ` +
          `it with, not the folded bus id: ${shown.text}`
      );
      assert.equal(shown.tagged, true, 'and it carries the published Changed tag');
      assert.ok(
        elapsed <= HIGHLIGHT_BUDGET_MS,
        `the row carries the change highlight within ${HIGHLIGHT_BUDGET_MS} ms of the confirm's ` +
          `terminal status line: ${elapsed} ms`
      );

      const written = proposed ? STRINGS.tableStatusYes : STRINGS.tableStatusNo;
      await page
        .waitForFunction(writtenCellReads, { timeout: HIGHLIGHT_WAIT_MS }, CHANGED_ROW, COLUMN_LABEL, written)
        .catch(() => {});
      const value = await page.evaluate(changedRowCells, CHANGED_ROW, COLUMN_LABEL);
      assert.notEqual(value, null, 'the highlighted row is still rendered');
      assert.ok(value.at >= 0, `the ${COLUMN_LABEL} column is on screen: ${value.cells.join(' | ')}`);
      assert.equal(
        value.cells[value.at],
        written,
        `the re-fetch brought the confirmed write back, so the row reads ${written}: ${value.cells.join(' | ')}`
      );
    } finally {
      await context.close();
      forgetTag(tag);
      dropProposals();
    }
  }
);

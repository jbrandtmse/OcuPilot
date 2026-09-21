/**
 * The screen shows the change, measured in a real browser against the throwaway (Story 5.7).
 *
 * **What only a browser can answer.** Two things: NFR-1's two-second budget, which needs a clock
 * bracketing the moment the confirm's terminal status line appears and the moment the row carries
 * the change highlight; and where the row ends up, which needs layout -- jsdom computes none, so
 * "scrolled into view" is not a claim the component tier can make.
 *
 * **It never navigates between the confirm and the assertion.** `proposal-confirm.browser-spec.mjs`
 * re-reads the written value by navigating to the list afterwards, which is why no highlight is
 * observable there: a fresh navigation builds a fresh store. This spec stands on the list for the
 * whole flow, which is the case the AC is about.
 *
 * **The second tab is a second browser context**, so it carries its own per-tab storage (AD-47):
 * the bus is in-process and does not cross tabs, and this measures that rather than assuming it.
 *
 * It writes to its own web application and nothing else: `OcuPilot.Test.ProposalFixture` creates
 * `/csp/ocupilotprobeconfirm` before the first test and deletes it after the last, and it refuses
 * outright to run inside the live container.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test
 * browser/change-highlight.browser-spec.mjs`. A run against a bundle that was not rebuilt reads
 * the old client and proves nothing.
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
const probe = { container: config.container, marker: 'CHGHL' };
const STRINGS = loadStrings();

/** The web-applications list, which this spec stands on for the whole flow. */
const LIST_URL = '/ocupilot/web-applications/list?ns=HSCUSTOM';

/** This spec's own web application. Created here, written here, deleted here. */
const TARGET = '/csp/ocupilotprobeconfirm';

/** The write tool's provider-side name: the canonical dotted name with underscores (AD-42). */
const TOOL_WIRE_NAME = 'webapp_list_update';

/** NFR-1's budget for a confirmed write's screen refresh (`epics.md:194`, `prd.md:1068`). */
const HIGHLIGHT_BUDGET_MS = 2000;

/**
 * How long the leg waits for the highlight, deliberately **longer** than the budget it asserts: a
 * wait that timed out at the budget would make the budget assertion unreachable, and a breach
 * would surface as a puppeteer timeout instead of the measured figure
 * (`audit.browser-spec.mjs`'s `FIRST_ROW_WAIT_MS`; `data-table.browser-spec.mjs:141-151` sets its
 * timeout equal to its budget and is the mistake not to copy).
 */
const HIGHLIGHT_WAIT_MS = HIGHLIGHT_BUDGET_MS * 5;

/** The column the proposal writes, named by its published header so the cell is read by name. */
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

/** Clear the probe definition's read-only flag, so its write tool mints rather than refusing. */
function allowWrites() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly("${escapeOs(preparedId)}",0)`,
    `Write "OCU-CHGHLRW-START:"_$System.Status.IsOK(sc)_":OCU-CHGHLRW-END",!`,
  ]);
  assert.equal(markerValue(output, 'CHGHLRW'), '1', `the probe definition allows writes: ${output}`);
}

function ensureTarget() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.ProposalFixture).EnsureWriteTarget($Namespace,.created)`,
    `Write "OCU-CHGHLAPP-START:"_$System.Status.IsOK(sc)_":OCU-CHGHLAPP-END",!`,
  ]);
  assert.equal(markerValue(output, 'CHGHLAPP'), '1', `the probe application is created: ${output}`);
}

function removeTarget() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.ProposalFixture).RemoveWriteTarget()`,
    `Write "OCU-CHGHLDEL-START:"_$System.Status.IsOK(sc)_":OCU-CHGHLDEL-END",!`,
  ]);
  assert.equal(markerValue(output, 'CHGHLDEL'), '1', `the probe application is removed: ${output}`);
}

/** The target's stored `Enabled`, read from the instance -- so each run proposes a real change. */
function storedEnabled() {
  const output = runIris([
    `Write "OCU-CHGHLVAL-START:"_##class(OcuPilot.Test.ProposalFixture).WriteTargetField("Enabled")_":OCU-CHGHLVAL-END",!`,
  ]);
  return markerValue(output, 'CHGHLVAL') ?? '';
}

function dropProposals() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForUser("${escapeOs(config.username)}")`,
    `Write "OCU-CHGHLDROP-START:"_$System.Status.IsOK(sc)_":OCU-CHGHLDROP-END",!`,
  ]);
  assert.equal(markerValue(output, 'CHGHLDROP'), '1', `the probe proposals are removed: ${output}`);
}

/** A `tool_use` reply proposing `enabled` on this spec's own application. */
function proposeReply(enabled) {
  const input = {
    Name: TARGET,
    Enabled: enabled,
    rationale: 'The application is serving when it should not be.',
    expectedImpact: 'the list reports it as not enabled',
    reverse: 'set it back',
  };
  return `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_chghl", "name": "${TOOL_WIRE_NAME}", "input": ${JSON.stringify(input)}}])`;
}

function textReply(text) {
  return `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs(text)}")`;
}

/** Wait until the list has rendered the target's row, so the highlight has something to land on. */
async function waitForTargetRow(page) {
  await page.waitForFunction(
    (selector, path) =>
      [...document.querySelectorAll(selector)].some((row) => (row.textContent ?? '').includes(path)),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    TARGET
  );
}

/** A signed-in page standing on the list, with one live card proposing `enabled`. */
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
  await page.type('#ocu-panel-composer', 'stop the probe application serving');
  await page.click('.ocu-panel-send');
  await page.waitForSelector('app-proposal-card .ocu-proposal-card-confirm', {
    timeout: config.navigationTimeoutMs,
  });
  return { context, page, tag };
}

/** What the table looks like right now, so a tick that moved something is visible as a diff. */
function tableState() {
  const grid = document.querySelector('[role="grid"]');
  const viewport = document.querySelector('cdk-virtual-scroll-viewport');
  const filter = document.querySelector('.ocu-command-bar-filter input');
  return {
    rowCount: grid?.getAttribute('aria-rowcount') ?? '',
    sort: [...document.querySelectorAll('[role="columnheader"]')]
      .map((header) => header.getAttribute('aria-sort') ?? 'none')
      .join(','),
    filter: filter === null ? '' : filter.value,
    scrollTop: viewport?.scrollTop ?? 0,
    url: location.pathname + location.search,
  };
}

/**
 * The highlighted row's cell texts and the index of the column headed `label`, or `null` when no
 * row is highlighted. Read from the header's own label span rather than the header cell, because
 * the sorted column's cell also carries a sort arrow.
 */
function changedRowCells(changed, label) {
  const row = document.querySelector(changed);
  if (row === null) return null;
  const headers = [...document.querySelectorAll('[role="columnheader"] .ocu-data-table-header-label')].map(
    (header) => (header.textContent ?? '').trim()
  );
  const cells = [...row.querySelectorAll('[role="gridcell"]')].map((cell) => (cell.textContent ?? '').trim());
  return { at: headers.indexOf(label), cells };
}

/** The same read as a predicate, for the wait that precedes it. */
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

/** Whether the target's row is currently inside the scrolled viewport's own box. */
function targetInView(selector, path) {
  const row = [...document.querySelectorAll(selector)].find((candidate) =>
    (candidate.textContent ?? '').includes(path)
  );
  if (row === undefined) return false;
  const rowBox = row.getBoundingClientRect();
  const viewBox = document.querySelector('cdk-virtual-scroll-viewport').getBoundingClientRect();
  return rowBox.top >= viewBox.top - 1 && rowBox.bottom <= viewBox.bottom + 1;
}

/** Scroll the viewport until the target's row is inside it, and answer the offset that took. */
async function scrollTargetIntoView(page) {
  await page.evaluate(
    (selector, path) => {
      const row = [...document.querySelectorAll(selector)].find((candidate) =>
        (candidate.textContent ?? '').includes(path)
      );
      row?.scrollIntoView({ block: 'center' });
    },
    ROW_SELECTOR,
    TARGET
  );
  await new Promise((resolve) => setTimeout(resolve, 200));
  return page.evaluate(() => document.querySelector('cdk-virtual-scroll-viewport').scrollTop);
}

test('Integration AC: the confirmed row carries the change highlight inside the budget, scrolled into view, with the table otherwise untouched', async () => {
  // Mutation (Rule 19): drop the `changed` publish from `TurnStore.decideProposal`'s confirmed
  // branch -> the wait below times out at HIGHLIGHT_WAIT_MS and this goes red, which is the whole
  // path this story ships.
  const before = storedEnabled();
  const proposed = before !== '1';
  const { context, page, tag } = await listWithLiveCard(proposed);
  try {
    // Parked at the top, where this fixture's target row is below the fold: the scroll-into-view
    // assertion below is vacuous if the row is already visible, so "it was not" is asserted rather
    // than assumed -- a fixture that ever put it at the top fails here rather than passing.
    await page.evaluate(() => {
      document.querySelector('cdk-virtual-scroll-viewport').scrollTop = 0;
    });
    await new Promise((resolve) => setTimeout(resolve, 200));
    const stateBefore = await page.evaluate(tableState);
    assert.equal(
      await page.evaluate(targetInView, ROW_SELECTOR, TARGET),
      false,
      'the row is out of view before the confirm, so bringing it into view is something that happens'
    );
    assert.equal(
      await page.$(CHANGED_ROW),
      null,
      'nothing is highlighted before the confirm, so the assertion below is about this write'
    );
    assert.equal(await page.$('.ocu-toast-region'), null, 'and no toast stands');

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
    // margin invisible, and the margin is what says whether the budget is nearly being missed.
    console.log(`change-highlight: the row carried the highlight ${elapsed} ms after the status line`);

    // The 3px agent-accent bar is drawn as `.ocu-data-table-row-changed::before`, and
    // `data-table.browser-spec.mjs:477` is where it is measured; nothing here reads it.
    const shown = await page.evaluate(
      (changed, tagText) => {
        const row = document.querySelector(changed);
        const viewport = document.querySelector('cdk-virtual-scroll-viewport');
        const rowBox = row.getBoundingClientRect();
        const viewBox = viewport.getBoundingClientRect();
        return {
          text: (row.textContent ?? '').trim(),
          tagged: (row.textContent ?? '').includes(tagText),
          inView: rowBox.top >= viewBox.top - 1 && rowBox.bottom <= viewBox.bottom + 1,
          toast: document.querySelector('.ocu-toast-region') !== null,
        };
      },
      CHANGED_ROW,
      STRINGS.tableChangedTag
    );

    assert.ok(shown.text.includes(TARGET), `the highlighted row is the one that was written: ${shown.text}`);
    assert.equal(shown.tagged, true, 'and it carries the published Changed tag');
    assert.ok(
      elapsed <= HIGHLIGHT_BUDGET_MS,
      `the row carries the change highlight within ${HIGHLIGHT_BUDGET_MS} ms of the confirm's ` +
        `terminal status line: ${elapsed} ms`
    );
    // Outside the timed bracket, and the half the mark alone cannot answer: `markChanged` runs
    // synchronously with the publish, **before** `readNow()` returns, so a re-fetch that had
    // broken entirely would leave every assertion above green while the screen still showed the
    // old value. This is the story's own title.
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

    assert.equal(shown.inView, true, 'and it is inside the scrolled viewport, not merely in the DOM');
    // The screen the user is looking at shows this entity, so the highlight IS the confirmation:
    // a toast beside it would be the same news twice.
    assert.equal(shown.toast, false, 'no toast is raised for a change the open screen shows');

    const stateAfter = await page.evaluate(tableState);
    assert.equal(stateAfter.url, stateBefore.url, 'nothing navigated: this is a re-fetch in place (AD-14)');
    assert.equal(stateAfter.sort, stateBefore.sort, 'the sort is what it was');
    assert.equal(stateAfter.filter, stateBefore.filter, 'and the filter');
    assert.equal(stateAfter.rowCount, stateBefore.rowCount, 'and the row count, since a PUT creates nothing');
    // The scroll offset is the one thing that DID move, and only because `scrollChangedIntoView`
    // moved it: the tick itself preserves it, which the second test below measures on a row that
    // is already in view. Both halves of the AC are true, and each has its own subject.
    assert.notEqual(stateAfter.scrollTop, stateBefore.scrollTop, 'the viewport scrolled to reach it');
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
  }
});

test('AD-47: the bus does not cross tabs -- a second tab on the same list is untouched', async () => {
  // Mutation (Rule 19): broadcast the change over `localStorage` (or any cross-tab channel) ->
  // the second tab's row would highlight and this goes red. AD-47 makes per-tab storage and no
  // cross-tab broadcast an invariant, so this is the measurement of it rather than an omission.
  const before = storedEnabled();
  const { context, page, tag } = await listWithLiveCard(before !== '1');
  // A second browser CONTEXT, not a second page: per-tab storage is per context, so a second page
  // in the first one would share the token pair and prove less than AD-47 claims.
  const onlookerTab = await signedInAt(browser, config, LIST_URL);
  try {
    const onlooker = onlookerTab.page;
    await waitForTargetRow(onlooker);

    // With the row already in view, `scrollChangedIntoView` has nothing to do, so the offset after
    // the re-fetch is the offset before it -- which is "the scroll position is what it was", on
    // the one subject where it is not confounded by the scroll into view.
    const scrollBefore = await scrollTargetIntoView(page);
    assert.notEqual(scrollBefore, 0, 'parked at a non-zero offset, so a tick that reset it would show');

    await page.click('.ocu-proposal-card-confirm');
    await page.waitForSelector('app-proposal-card .ocu-proposal-card-status', {
      timeout: config.navigationTimeoutMs,
    });
    await page.waitForSelector(CHANGED_ROW, { timeout: HIGHLIGHT_WAIT_MS });

    // Given the same time again, and then some: if a cross-tab channel existed the second tab
    // would have drawn by now.
    await new Promise((resolve) => setTimeout(resolve, HIGHLIGHT_BUDGET_MS));
    assert.equal(await onlooker.$(CHANGED_ROW), null, "the second tab's row carries no change highlight");
    assert.equal(await onlooker.$('.ocu-toast-region'), null, 'and no toast appears there');

    assert.equal(
      await page.evaluate(() => document.querySelector('cdk-virtual-scroll-viewport').scrollTop),
      scrollBefore,
      'and in the first tab the re-fetch left the scroll position exactly where the user had it'
    );
    assert.equal(
      await page.evaluate(targetInView, ROW_SELECTOR, TARGET),
      true,
      'with the changed row still in view'
    );
  } finally {
    await onlookerTab.context.close();
    await context.close();
    forgetTag(tag);
    dropProposals();
  }
});

/**
 * Story 7.5 end to end in a real browser against the throwaway instance: Run on the On-demand
 * tasks list, from the screen and through the agent, on a harmless probe task of this spec's own
 * (`OcuPilot.Test.TaskRunFixture`: `RunLegacyTask` running `Quit`).
 *
 * **It runs a task.** It refuses outright to run outside a `-ci` throwaway, it creates its probe in
 * `before` and deletes it in `after`, and it never runs the demo task.
 *
 * **What only a browser can answer here:** that Run opens no dialog, that the row re-fetches in
 * place under its filter and selection (the Integration AC: `ListPage` consuming the `task` change
 * event), and that the card the agent's proposal draws carries the `NextScheduled` row. Each leg
 * then waits, bounded at 180 s, for the vendor's own history to record the run.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test
 * browser/task-run.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
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
const probe = { container: config.container, marker: 'TASKRUN' };
const STRINGS = loadStrings();

const LIST_URL = '/ocupilot/tasks/on-demand?ns=HSCUSTOM';
const ACTION_PATH = '/api/ocupilot/screens/tasks.ondemand/action';
const FIXTURE = 'OcuPilot.Test.TaskRunFixture';

/** The run tool's provider-side name: the canonical dotted name with underscores (AD-42). */
const RUN_WIRE_NAME = 'tasks_ondemand_run';

/** The vendor's history wait, in seconds: one Task Manager pass measured 26-43 s. */
const RUN_BUDGET_SECONDS = 180;

/** The Last run and Next run columns' positions in the declared table. */
const LAST_RUN_CELL = 4;
const NEXT_RUN_CELL = 5;

/** The name cell's own text element, which excludes the "Changed" tag a marked row carries. */
const NAME_TEXT = '.ocu-data-table-link, .ocu-data-table-text';

let browser = null;
let preparedId = '';
let priorDefault = '';
let taskId = '';
let taskName = '';

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs a task, so it never runs inside the live container');
  assert.match(
    config.container,
    /-ci$/,
    `this spec runs a task on the instance, so it runs only in a throwaway; ${config.container} is not one`
  );
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);
  browser = await puppeteer.launch(launchOptions(config));
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
  allowWrites();
  dropProposals();
  taskId = ensureProbe();
  assert.notEqual(taskId, '', 'the run probe task exists');
  taskName = probeName();
  assert.notEqual(taskName, '', "the probe task's declared name reads back");
});

after(async () => {
  if (browser !== null) await browser.close();
  if (!/-ci$/.test(config.container)) return;
  const output = runIris([
    `Do ##class(${FIXTURE}).DeleteRunProbeTask()`,
    `Write "OCU-TRUNGONE-START:"_##class(${FIXTURE}).ProbeCount()_":OCU-TRUNGONE-END",!`,
  ]);
  await requireFreeSlot(config).catch(() => {});
  dropProposals();
  disarmProbeDefinition(probe, priorDefault);
  assert.equal(markerValue(output, 'TRUNGONE'), '0', `no run probe task remains: ${output}`);
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
    `Write "OCU-TRUNRW-START:"_$System.Status.IsOK(sc)_":OCU-TRUNRW-END",!`,
  ]);
  assert.equal(markerValue(output, 'TRUNRW'), '1', `the probe definition allows writes: ${output}`);
}

/** Remove every proposal this spec's own principal has minted. */
function dropProposals() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForUser("${escapeOs(config.username)}")`,
    `Write "OCU-TRUNDROP-START:"_$System.Status.IsOK(sc)_":OCU-TRUNDROP-END",!`,
  ]);
  assert.equal(markerValue(output, 'TRUNDROP'), '1', `the probe proposals are removed: ${output}`);
}

function ensureProbe() {
  const output = runIris([
    `Set sc=##class(${FIXTURE}).EnsureRunProbeTask(.id)`,
    `Write "OCU-TRUNTASK-START:"_$Select($System.Status.IsOK(sc):id,1:"")_":OCU-TRUNTASK-END",!`,
  ]);
  return markerValue(output, 'TRUNTASK') ?? '';
}

function probeName() {
  const output = runIris([`Write "OCU-TRUNNAME-START:"_$Parameter("${FIXTURE}","PROBETASKNAME")_":OCU-TRUNNAME-END",!`]);
  return markerValue(output, 'TRUNNAME') ?? '';
}

/** The highest vendor history row id now. */
function historyHighWater() {
  const output = runIris([`Write "OCU-TRUNHW-START:"_##class(${FIXTURE}).HistoryHighWater()_":OCU-TRUNHW-END",!`]);
  return markerValue(output, 'TRUNHW') ?? '';
}

/** Whether the probe's history gains a Success row after `since` within the budget, and how long it took. */
function awaitRun(since) {
  const output = runIris([
    `Set ok=##class(${FIXTURE}).AwaitRun("${escapeOs(taskId)}",${Number(since)},${RUN_BUDGET_SECONDS},.e)`,
    `Write "OCU-TRUNWAIT-START:"_ok_"|"_$Get(e)_":OCU-TRUNWAIT-END",!`,
  ]);
  const [landed, waited] = (markerValue(output, 'TRUNWAIT') ?? '0|').split('|');
  return { landed: landed === '1', waited };
}

/** How many rows the shipped `tasks.taskhistory` read answers for the probe, or -1. */
function historyReadRows() {
  const output = runIris([`Write "OCU-TRUNHR-START:"_##class(${FIXTURE}).HistoryReadRows("${escapeOs(taskId)}")_":OCU-TRUNHR-END",!`]);
  return Number(markerValue(output, 'TRUNHR') ?? '-1');
}

function textReply(text) {
  return `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs(text)}")`;
}

function proposeReply(id) {
  const input = {
    Id: id,
    rationale: 'The probe task should run once now.',
    expectedImpact: "it runs at the Task Manager's next pass",
  };
  return `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_run", "name": "${RUN_WIRE_NAME}", "input": ${JSON.stringify(input)}}])`;
}

/** The probe row's cells, read by its name, or `null` while it is not rendered. */
function probeRow(page) {
  return page.evaluate(
    (selector, wanted, textSelector) => {
      const row = Array.from(document.querySelectorAll(selector)).find((candidate) => {
        const cell = candidate.querySelector('[role="gridcell"]');
        const text = cell?.querySelector(textSelector);
        return ((text ?? cell)?.textContent ?? '').trim() === wanted;
      });
      if (row === undefined) return null;
      return {
        cells: Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim()),
        selected: row.getAttribute('aria-selected') === 'true',
        changed: row.classList.contains('ocu-data-table-row-changed'),
      };
    },
    ROW_SELECTOR,
    taskName,
    NAME_TEXT
  );
}

/** Narrow the list to the probe task and select its row. */
async function selectProbe(page) {
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, taskName);
  await page.waitForFunction(
    (selector, wanted, textSelector) =>
      Array.from(document.querySelectorAll(selector)).some((row) => {
        const cell = row.querySelector('[role="gridcell"]');
        const text = cell?.querySelector(textSelector);
        return ((text ?? cell)?.textContent ?? '').trim() === wanted;
      }),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    taskName,
    NAME_TEXT
  );
  await clickRowCentre(page, { text: taskName });
  await page.waitForFunction(
    (selector) => Array.from(document.querySelectorAll(selector)).some((row) => row.getAttribute('aria-selected') === 'true'),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR
  );
}

test('AC1, Integration AC: Run from the row menu sends one POST with no dialog, the row re-fetches in place, and the run lands', async () => {
  // Mutation (Rule 19): drop the list from `SCREEN_ACTION_DESCRIPTORS`, rebuild and redeploy ->
  // no row menu entry and no command-bar Run, and this goes red. Integration AC: drop the re-fetch
  // from `RefreshService.onBusEvent` -> the row is marked but its Next run never fills.
  await requireFreeSlot(config);
  const { context, page } = await signedInAt(browser, config, LIST_URL);
  const posts = [];
  page.on('request', (request) => {
    if (new URL(request.url()).pathname === ACTION_PATH) posts.push({ method: request.method(), body: request.postData() ?? '' });
  });
  let dialogs = 0;
  page.on('dialog', async (dialog) => {
    dialogs += 1;
    await dialog.dismiss();
  });
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await selectProbe(page);
    const before = await probeRow(page);
    assert.ok(before !== null, 'the probe row is rendered');
    assert.ok(before.cells.length > NEXT_RUN_CELL, `the probe row renders a Next run cell: ${JSON.stringify(before.cells)}`);
    // Empty before the press, so the digit waited for below can only come from the re-fetch.
    assert.equal(before.cells[NEXT_RUN_CELL], STRINGS.tableEmptyValue, 'the probe has no next run before Run is pressed');
    const lastRunBefore = before.cells[LAST_RUN_CELL];

    const bar = await page.$$eval('.ocu-command-bar-action', (buttons) =>
      buttons.filter((button) => !button.classList.contains('ocu-command-bar-refresh-action')).map((button) => button.textContent.trim())
    );
    assert.deepEqual(bar, [STRINGS.actionRun], 'the command bar offers Run');

    await page.click('.ocu-data-table-trigger');
    await page.waitForSelector('[role="menu"]', { timeout: config.navigationTimeoutMs });
    const entries = await page.$$eval('[role="menu"] [role="menuitem"]', (items) =>
      items.map((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() ?? '')
    );
    assert.deepEqual(entries, [STRINGS.actionRun], 'the row menu offers Run');

    const since = historyHighWater();
    assert.ok(Number(since) > 0, `the history high-water mark reads: ${since}`);
    await page.evaluate((label) => {
      const items = Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'));
      items.find((item) => item.textContent.trim().startsWith(label)).click();
    }, STRINGS.actionRun);

    await page.waitForFunction(
      (selector, wanted, textSelector, index) => {
        const row = Array.from(document.querySelectorAll(selector)).find((candidate) => {
          const cell = candidate.querySelector('[role="gridcell"]');
          const text = cell?.querySelector(textSelector);
          return ((text ?? cell)?.textContent ?? '').trim() === wanted;
        });
        if (row === undefined || !row.classList.contains('ocu-data-table-row-changed')) return false;
        const next = row.querySelectorAll('[role="gridcell"]')[index]?.textContent.trim() ?? '';
        return /[0-9]/.test(next);
      },
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      taskName,
      NAME_TEXT,
      NEXT_RUN_CELL
    );
    assert.equal(
      await page.evaluate(() => document.querySelector('app-typed-name-dialog, app-warning-dialog, [role="dialog"], [role="alertdialog"]') !== null),
      false,
      'no dialog opened'
    );
    assert.equal(dialogs, 0, 'and no browser dialog either');
    assert.equal(posts.length, 1, `exactly one request: ${JSON.stringify(posts)}`);
    assert.equal(posts[0].method, 'POST');
    assert.deepEqual(JSON.parse(posts[0].body), { action: 'run', id: taskId }, "carrying the task's Id");

    const after = await probeRow(page);
    assert.equal(after.changed, true, 'the row is marked changed');
    assert.equal(after.selected, true, 'and is still selected');
    assert.equal(await page.$eval(FILTER_SELECTOR, (field) => field.value), taskName, 'under the same filter');

    const { landed, waited } = awaitRun(since);
    assert.ok(landed, `a Success history row lands within ${RUN_BUDGET_SECONDS} s (waited ${waited} s)`);

    await page.click('.ocu-command-bar-refresh-action');
    await page.waitForFunction(
      (selector, wanted, textSelector, index, previous) => {
        const row = Array.from(document.querySelectorAll(selector)).find((candidate) => {
          const cell = candidate.querySelector('[role="gridcell"]');
          const text = cell?.querySelector(textSelector);
          return ((text ?? cell)?.textContent ?? '').trim() === wanted;
        });
        const last = (row?.querySelectorAll('[role="gridcell"]')[index]?.textContent ?? '').trim();
        return row !== undefined && /[0-9]/.test(last) && last !== previous;
      },
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      taskName,
      NAME_TEXT,
      LAST_RUN_CELL,
      lastRunBefore
    );
  } finally {
    await context.close();
  }
});

test('AC2: the agent proposes the run, the card shows the next run, Confirm runs it, and its history shows it', async () => {
  // Mutation (Rule 19): set `OcuPilot.Screen.Tool.TaskRun.WRITETYPE` to `INFO` on the throwaway ->
  // the confirm writes nothing and the history wait goes red.
  await requireFreeSlot(config);
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 0, proposeReply(taskId));
  scriptReply(tag, 0, textReply('done'));
  const { context, page } = await signedInAt(browser, config, LIST_URL);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await page.waitForFunction(
      () => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'),
      { timeout: config.navigationTimeoutMs }
    );
    await page.type('#ocu-panel-composer', 'run the probe task');
    await page.click('.ocu-panel-send');
    await page.waitForSelector('app-proposal-card .ocu-proposal-card-confirm', { timeout: config.navigationTimeoutMs });
    const diff = await page.$$eval('.ocu-diff-row:not(.ocu-diff-row-unchanged)', (rows) =>
      rows.map((row) => (row.textContent ?? '').replace(/\s+/g, ' ').trim())
    );
    assert.ok(diff.length >= 1, `the card carries a row: ${JSON.stringify(diff)}`);
    assert.ok(diff[0].includes('NextScheduled'), `the first row is the next run: ${diff[0]}`);
    assert.ok(diff[0].includes('now'), `moving to now: ${diff[0]}`);

    const since = historyHighWater();
    assert.ok(Number(since) > 0, `the history high-water mark reads: ${since}`);
    const historyBefore = historyReadRows();
    assert.ok(historyBefore >= 0, `the task's history reads before the confirm: ${historyBefore}`);
    await page.click('.ocu-proposal-card-confirm');
    await page.waitForSelector('app-proposal-card .ocu-proposal-card-status', { timeout: config.navigationTimeoutMs });
    const { landed, waited } = awaitRun(since);
    assert.ok(landed, `a Success history row lands within ${RUN_BUDGET_SECONDS} s (waited ${waited} s)`);

    await page.goto(`${config.origin}/ocupilot/tasks/schedule/history/${encodeURIComponent(taskId)}?ns=HSCUSTOM`, { waitUntil: 'networkidle2' });
    await waitForRows(page, config.navigationTimeoutMs);
    const names = await page.$$eval(ROW_SELECTOR, (rows) =>
      rows.map((row) => Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim()))
    );
    const runs = names.filter((cells) => cells.some((cell) => cell.startsWith(taskName))).length;
    assert.ok(
      runs > historyBefore,
      `the task's history screen lists the new run: ${runs} rows against ${historyBefore} before (${JSON.stringify(names.slice(0, 3))})`
    );
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
  }
});

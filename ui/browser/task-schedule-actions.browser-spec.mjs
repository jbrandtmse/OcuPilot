/**
 * Story 7.6 end to end in a real browser against the throwaway instance: Run, Suspend, Resume and
 * Delete on the Task schedule, from the row menu and the command bar, on a harmless probe task of
 * this spec's own (`OcuPilot.Test.TaskRunFixture`'s schedule probe: `RunLegacyTask` running `Quit`,
 * daily at 03:00).
 *
 * **It writes a task.** It refuses outright to run outside a `-ci` throwaway, it creates its probe
 * in `before` and deletes it in `after`, and it never writes the demo task or a vendor task: the
 * system-task leg only opens the delete dialog on one and cancels it.
 *
 * **What only a browser can answer here:** that Run, Suspend and Resume open no dialog, that the
 * row re-reads in place through the list's `INFO` rowGet (the Integration AC: `ListPage` consuming
 * the `task` change event), that Delete's dialog names the task and releases only on its typed
 * name, and that a system task's dialog carries the consequence line.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test
 * browser/task-schedule-actions.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { escapeOs, markerValue, requireFreeSlot, runIris as sharedRunIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();

const LIST_URL = '/ocupilot/tasks/schedule?ns=HSCUSTOM';
const ACTION_PATH = '/api/ocupilot/screens/tasks.schedule/action';
const FIXTURE = 'OcuPilot.Test.TaskRunFixture';

/** A system task every instance ships, which the Cancel leg opens a delete dialog on and nothing else. */
const SYSTEM_TASK = 'Switch Journal';

/** The filter that keeps the probe and the demo task in view, so a row is left after the delete. */
const SHARED_PREFIX = 'OcuPilot';

/** The vendor's history wait, in seconds: one Task Manager pass measured 26-43 s. */
const RUN_BUDGET_SECONDS = 180;

/** The declared columns' positions: Suspended, then Last run, then Next run. */
const SUSPENDED_CELL = 3;
const NEXT_RUN_CELL = 5;

/** The name cell's own text element, which excludes the "Changed" tag a marked row carries. */
const NAME_TEXT = '.ocu-data-table-link, .ocu-data-table-text';

/** The four actions, in the order the list declares them. */
const ACTIONS = [STRINGS.actionRun, STRINGS.actionSuspend, STRINGS.actionResume, STRINGS.actionDelete];

let browser = null;
let taskId = '';
let taskName = '';

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec writes a task, so it never runs inside the live container');
  assert.match(
    config.container,
    /-ci$/,
    `this spec writes a task on the instance, so it runs only in a throwaway; ${config.container} is not one`
  );
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);
  browser = await puppeteer.launch(launchOptions(config));
  // A fresh probe every run: task ids are never reused, so its history holds only this run's rows.
  runIris([`Do ##class(${FIXTURE}).DeleteScheduleProbeTask()`]);
  taskId = ensureProbe();
  assert.notEqual(taskId, '', 'the schedule probe task exists');
  taskName = probeName();
  assert.notEqual(taskName, '', "the probe task's declared name reads back");
});

after(async () => {
  if (browser !== null) await browser.close();
  if (!/-ci$/.test(config.container)) return;
  const output = runIris([
    `Do ##class(${FIXTURE}).DeleteScheduleProbeTask()`,
    `Write "OCU-TSAGONE-START:"_##class(${FIXTURE}).ScheduleProbeCount()_":OCU-TSAGONE-END",!`,
  ]);
  assert.equal(markerValue(output, 'TSAGONE'), '0', `no schedule probe task remains: ${output}`);
});

function runIris(lines) {
  return sharedRunIris(config.container, lines);
}

function ensureProbe() {
  const output = runIris([
    `Set sc=##class(${FIXTURE}).EnsureScheduleProbeTask(.id,0)`,
    `Write "OCU-TSATASK-START:"_$Select($System.Status.IsOK(sc):id,1:"")_":OCU-TSATASK-END",!`,
  ]);
  return markerValue(output, 'TSATASK') ?? '';
}

function probeName() {
  const output = runIris([`Write "OCU-TSANAME-START:"_$Parameter("${FIXTURE}","SCHEDULETASKNAME")_":OCU-TSANAME-END",!`]);
  return markerValue(output, 'TSANAME') ?? '';
}

/** The probe's `Suspended` as its own `INFO` answers it: `true`, `false`, or `''` on a failed read. */
function infoSuspended() {
  const output = runIris([`Write "OCU-TSAINFO-START:"_##class(${FIXTURE}).InfoField("${escapeOs(taskId)}","Suspended")_":OCU-TSAINFO-END",!`]);
  return markerValue(output, 'TSAINFO') ?? '';
}

/** The HTTP status the probe's `INFO` answers now. */
function infoStatus() {
  const output = runIris([`Write "OCU-TSASTAT-START:"_##class(${FIXTURE}).InfoStatus("${escapeOs(taskId)}")_":OCU-TSASTAT-END",!`]);
  return markerValue(output, 'TSASTAT') ?? '';
}

function historyHighWater() {
  const output = runIris([`Write "OCU-TSAHW-START:"_##class(${FIXTURE}).HistoryHighWater()_":OCU-TSAHW-END",!`]);
  return markerValue(output, 'TSAHW') ?? '';
}

function awaitRun(since) {
  const output = runIris([
    `Set ok=##class(${FIXTURE}).AwaitRun("${escapeOs(taskId)}",${Number(since)},${RUN_BUDGET_SECONDS},.e)`,
    `Write "OCU-TSAWAIT-START:"_ok_"|"_$Get(e)_":OCU-TSAWAIT-END",!`,
  ]);
  const [landed, waited] = (markerValue(output, 'TSAWAIT') ?? '0|').split('|');
  return { landed: landed === '1', waited };
}

/** A signed-in page on the Task schedule, recording every request to the action route. */
async function signedInAtList() {
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
  await waitForRows(page, config.navigationTimeoutMs);
  return { context, page, posts, browserDialogs: () => dialogs };
}

/** The row named `name`, read by its name cell, or `null` while it is not rendered. */
function rowNamed(page, name) {
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
    name,
    NAME_TEXT
  );
}

/** Filter the list to `text`, and select the row named `name`. */
async function select(page, text, name) {
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, text);
  await page.waitForFunction(
    (selector, wanted, textSelector) =>
      Array.from(document.querySelectorAll(selector)).some((row) => {
        const cell = row.querySelector('[role="gridcell"]');
        const found = cell?.querySelector(textSelector);
        return ((found ?? cell)?.textContent ?? '').trim() === wanted;
      }),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name,
    NAME_TEXT
  );
  await clickRowCentre(page, { text: name });
  await page.waitForFunction(
    (selector) => Array.from(document.querySelectorAll(selector)).some((row) => row.getAttribute('aria-selected') === 'true'),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR
  );
}

/** The command bar's actions, Refresh aside. */
function commandBar(page) {
  return page.$$eval('.ocu-command-bar-action', (buttons) =>
    buttons.filter((button) => !button.classList.contains('ocu-command-bar-refresh-action')).map((button) => button.textContent.trim())
  );
}

/** Press the command-bar action labelled `label`. */
async function pressBar(page, label) {
  await page.evaluate((wanted) => {
    const buttons = Array.from(document.querySelectorAll('.ocu-command-bar-action'));
    buttons.find((button) => button.textContent.trim() === wanted).click();
  }, label);
}

/** Open the row menu on the selected row and answer its entries' labels. */
async function openRowMenu(page) {
  await page.evaluate(() => {
    const row = Array.from(document.querySelectorAll('[role="grid"] .ocu-data-table-body [role="row"]')).find(
      (candidate) => candidate.getAttribute('aria-selected') === 'true'
    );
    row.querySelector('.ocu-data-table-trigger').click();
  });
  await page.waitForSelector('[role="menu"]', { timeout: config.navigationTimeoutMs });
  return page.$$eval('[role="menu"] [role="menuitem"]', (items) =>
    items.map((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() ?? '')
  );
}

/** Choose the row-menu entry labelled `label`. */
async function chooseMenu(page, label) {
  await page.evaluate((wanted) => {
    const items = Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'));
    items.find((item) => item.textContent.trim().startsWith(wanted)).click();
  }, label);
}

/** Wait until the probe row is marked changed and its cell `index` satisfies `expected` (a string, or `null` for "not `previous`"). */
async function waitForProbeCell(page, index, expected, previous = '') {
  await page.waitForFunction(
    (selector, wanted, textSelector, at, value, prior) => {
      const row = Array.from(document.querySelectorAll(selector)).find((candidate) => {
        const cell = candidate.querySelector('[role="gridcell"]');
        const text = cell?.querySelector(textSelector);
        return ((text ?? cell)?.textContent ?? '').trim() === wanted;
      });
      if (row === undefined || !row.classList.contains('ocu-data-table-row-changed')) return false;
      const shown = (row.querySelectorAll('[role="gridcell"]')[at]?.textContent ?? '').trim();
      return value === null ? /[0-9]/.test(shown) && shown !== prior : shown === value;
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    taskName,
    NAME_TEXT,
    index,
    expected,
    previous
  );
}

function noDialog(page) {
  return page.evaluate(
    () => document.querySelector('app-typed-name-dialog, app-warning-dialog, [role="dialog"], [role="alertdialog"]') === null
  );
}

test('AC1: the row menu and the command bar offer all four actions, and Run sends one POST with no dialog and lands', async () => {
  // Mutation (Rule 19): drop the schedule from `SCREEN_ACTION_DESCRIPTORS`, rebuild and redeploy ->
  // neither surface offers an action and this goes red.
  const { context, page, posts, browserDialogs } = await signedInAtList();
  try {
    await select(page, taskName, taskName);
    assert.deepEqual(await commandBar(page), ACTIONS, 'the command bar offers Run, Suspend, Resume and Delete');
    assert.deepEqual(await openRowMenu(page), ACTIONS, 'and so does the row menu, destructive last');

    const before = await rowNamed(page, taskName);
    const nextBefore = before.cells[NEXT_RUN_CELL];
    const since = historyHighWater();
    assert.ok(Number(since) > 0, `the history high-water mark reads: ${since}`);
    await chooseMenu(page, STRINGS.actionRun);
    await waitForProbeCell(page, NEXT_RUN_CELL, null, nextBefore);
    assert.equal(await noDialog(page), true, 'no dialog opened');
    assert.equal(browserDialogs(), 0, 'and no browser dialog either');
    assert.equal(posts.length, 1, `exactly one request: ${JSON.stringify(posts)}`);
    assert.deepEqual(JSON.parse(posts[0].body), { action: 'run', id: taskId }, "carrying the task's Id");
    const after = await rowNamed(page, taskName);
    assert.equal(after.selected, true, 'the row is still selected');
    const { landed, waited } = awaitRun(since);
    assert.ok(landed, `a Success history row lands within ${RUN_BUDGET_SECONDS} s (waited ${waited} s)`);
  } finally {
    await context.close();
  }
});

test('AC1, AC2, Integration AC: Suspend and Resume re-read the row through INFO, and the history records the resume by this user', async () => {
  // Mutation (Rule 19): drop the list's INFO `rowGet` so the column reads the LIST's field -> the
  // Suspended cell never reads Yes and this goes red. Set `TaskResume.SCREENACTIONS` to "" -> the
  // route answers 404 to Resume and the cell never returns to No.
  const { context, page, posts } = await signedInAtList();
  try {
    await select(page, taskName, taskName);
    const before = await rowNamed(page, taskName);
    assert.equal(before.cells[SUSPENDED_CELL], STRINGS.tableStatusNo, 'the probe starts not suspended');

    await pressBar(page, STRINGS.actionSuspend);
    await waitForProbeCell(page, SUSPENDED_CELL, STRINGS.tableStatusYes);
    assert.equal(await noDialog(page), true, 'Suspend opens no dialog');
    assert.equal(posts.length, 1, `one request: ${JSON.stringify(posts)}`);
    assert.deepEqual(JSON.parse(posts[0].body), { action: 'suspend', id: taskId });
    assert.equal(infoSuspended(), 'true', "and the task's own INFO reads it suspended");
    assert.equal(await page.$eval(FILTER_SELECTOR, (field) => field.value), taskName, 'the filter survived');
    assert.equal((await rowNamed(page, taskName)).selected, true, 'and so did the selection');

    await openRowMenu(page);
    await chooseMenu(page, STRINGS.actionResume);
    await waitForProbeCell(page, SUSPENDED_CELL, STRINGS.tableStatusNo);
    assert.equal(await noDialog(page), true, 'Resume opens no dialog');
    assert.equal(posts.length, 2, `two requests: ${JSON.stringify(posts)}`);
    assert.deepEqual(JSON.parse(posts[1].body), { action: 'resume', id: taskId });
    assert.equal(infoSuspended(), 'false', "and the task's own INFO reads it not suspended");
  } finally {
    await context.close();
  }

  // Task history, in a page of its own: a signed-in session's first page load is what clears the
  // first-login gate, so a second full load in the same page would stand on the gate instead.
  const history = await signedInAt(browser, config, `/ocupilot/tasks/schedule/history/${encodeURIComponent(taskId)}?ns=HSCUSTOM`);
  try {
    await waitForRows(history.page, config.navigationTimeoutMs);
    const rows = await history.page.$$eval(ROW_SELECTOR, (list) =>
      list.map((row) => Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim()))
    );
    assert.ok(
      rows.some((cells) => cells.includes('Resumed task') && cells.includes(config.username)),
      `Task history shows "Resumed task" by ${config.username}: ${JSON.stringify(rows.slice(0, 5))}`
    );
  } finally {
    await history.context.close();
  }
});

test("AC5: a system task's Delete dialog carries the consequence line, and Cancel sends nothing", async () => {
  // Mutation (Rule 19): drop the advisory from the handler's `TYPED_NAME_ROWS`, rebuild and
  // redeploy -> the advisory assertion goes red.
  const { context, page, posts } = await signedInAtList();
  try {
    await select(page, SYSTEM_TASK, SYSTEM_TASK);
    const row = await rowNamed(page, SYSTEM_TASK);
    assert.equal(row.cells[2], 'System', 'the row is a system task');
    await pressBar(page, STRINGS.actionDelete);
    await page.waitForSelector('app-typed-name-dialog [data-slot="advisory"]', { timeout: config.navigationTimeoutMs });
    const opened = await page.evaluate(() => ({
      title: document.querySelector('.ocu-dialog-title').textContent.trim(),
      consequence: document.querySelector('.ocu-typed-name-consequence').textContent.trim(),
      advisory: document.querySelector('[data-slot="advisory"] .ocu-banner-message').textContent.trim(),
    }));
    assert.equal(opened.title, `${STRINGS.actionDelete} ${SYSTEM_TASK}`, "the title names the task's Name");
    assert.equal(opened.consequence, STRINGS.taskDeleteConsequence);
    assert.equal(opened.advisory, STRINGS.taskSystemDeleteConsequence, "and the system task's consequence line follows it");
    await page.keyboard.press('Escape');
    await page.waitForFunction(() => document.querySelector('app-typed-name-dialog') === null, { timeout: config.navigationTimeoutMs });
    await page.waitForNetworkIdle({ idleTime: 500, timeout: config.navigationTimeoutMs });
    assert.equal(posts.length, 0, 'Cancel sent nothing');
  } finally {
    await context.close();
  }
});

test('AC1: Delete names the task, refuses a mismatch, sends the Id on the typed Name, and the row leaves with focus in the grid', async () => {
  // Mutation (Rule 19): drop the schedule's `name` from `TYPED_NAME_ROWS` -> the dialog names the
  // Id and the title assertion goes red.
  const { context, page, posts } = await signedInAtList();
  try {
    await select(page, SHARED_PREFIX, taskName);
    await pressBar(page, STRINGS.actionDelete);
    await page.waitForSelector('app-typed-name-dialog', { timeout: config.navigationTimeoutMs });
    const opened = await page.evaluate(() => ({
      title: document.querySelector('.ocu-dialog-title').textContent.trim(),
      consequence: document.querySelector('.ocu-typed-name-consequence').textContent.trim(),
      advisory: document.querySelector('[data-slot="advisory"]') !== null,
    }));
    assert.equal(opened.title, `${STRINGS.actionDelete} ${taskName}`, "the title names the task's Name, not its Id");
    assert.equal(opened.consequence, STRINGS.taskDeleteConsequence, 'the body states the consequence');
    assert.equal(opened.advisory, false, 'and a user task carries no system-task line');

    await page.type('.ocu-typed-name-field', taskId);
    await page.evaluate(() => document.querySelector('.ocu-typed-name-field').blur());
    await page.waitForSelector('.ocu-typed-name-mismatch', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-typed-name-mismatch', (node) => node.textContent.trim()), STRINGS.formTypedNameMismatch);
    await page.focus('.ocu-typed-name-field');
    await page.keyboard.press('Enter');
    assert.equal(posts.length, 0, 'the Id typed in place of the Name sends nothing');

    await page.click('.ocu-typed-name-field', { clickCount: 3 });
    await page.keyboard.press('Backspace');
    await page.type('.ocu-typed-name-field', taskName);
    await page.waitForFunction(
      () => document.querySelector('.ocu-button-destructive')?.getAttribute('aria-disabled') === null,
      { timeout: config.navigationTimeoutMs }
    );
    await page.click('.ocu-button-destructive');
    await page.waitForFunction(
      (selector, wanted, textSelector) =>
        !Array.from(document.querySelectorAll(selector)).some((row) => {
          const cell = row.querySelector('[role="gridcell"]');
          const text = cell?.querySelector(textSelector);
          return ((text ?? cell)?.textContent ?? '').trim() === wanted;
        }),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      taskName,
      NAME_TEXT
    );
    assert.equal(posts.length, 1, `exactly one request: ${JSON.stringify(posts)}`);
    assert.deepEqual(JSON.parse(posts[0].body), { action: 'delete', id: taskId }, "carrying the task's Id");
    assert.equal(infoStatus(), '404', "the task's own INFO answers 404");
    await page
      .waitForFunction(() => document.activeElement?.closest('[role="grid"]') !== null, { timeout: 5000 })
      .catch(() => {});
    const inGrid = await page.evaluate(() => document.activeElement?.closest('[role="grid"]') !== null);
    assert.equal(inGrid, true, 'focus returns to the grid, where the remaining row takes its place');
  } finally {
    await context.close();
  }
});

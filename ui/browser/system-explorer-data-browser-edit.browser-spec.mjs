/**
 * Story 19.8 in a real browser, against the throwaway: Data browser edits the probe table keyed by
 * `Code` -- a name typed into a cell and a row another session changed are saved through the warning
 * dialog, the saved row read again and the changed one rolled back with its Change cell naming why,
 * and the instance holds the saved value (AC1, AC4, AC5); the editable page passes the structural
 * walk's checks at 1280 light, 720 light and 1280 dark (AC12); and a cut cell's tooltip shows under
 * it, inside the window, on the pointer's rest and on the active cell, and goes when an editor opens
 * (AC13).
 *
 * AC14 (Integration): a table SQL query (Story 19.6) creates and fills in USER is changed in Data
 * browser and saved, and SQL query's SELECT on it then reads the new value.
 *
 * The probe objects are `OcuPilot.Test.SqlSaveProbe`'s, made in `before` and removed in `after` with
 * the table AC14 creates, and `after` asserts none is left. Needs the throwaway: it refuses the live
 * container.
 *
 * Run: `node --test --test-concurrency=1 browser/system-explorer-data-browser-edit.browser-spec.mjs`
 * (after `npm run build`, the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const PROBE = 'OcuPilot.Test.SqlSaveProbe';
const SCHEMA = 'OcuProbe198';
const MADE = 'OcuProbe198.Made';
const ROUTE = 'system-explorer/sql-data';
const QUERY_ROUTE = 'system-explorer/sql-query';

/** The walk's own media feature (`structural-walk.mjs`): a theme flip lands at once rather than mid-transition. */
const REDUCED_MOTION = [{ name: 'prefers-reduced-motion', value: 'reduce' }];

/** A name long enough that its cell is cut. */
const LONG_NAME = 'd'.repeat(48);

let browser = null;

const marker = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/** Run `statements` in USER as the session's account, ignoring their answers. */
function inUser(statements) {
  runIris(config.container, ['Set $NAMESPACE="USER"', ...statements.map((statement) => `Do ##class(%SQL.Statement).%ExecDirect(,"${statement.replaceAll('"', '""')}")`)]);
}

/** The first cell `query` answers in USER, read as text. */
function valueInUser(query) {
  const output = runIris(config.container, [
    'Set $NAMESPACE="USER"',
    `Set r=##class(%SQL.Statement).%ExecDirect(,"${query.replaceAll('"', '""')}")`,
    marker('VALUE', '$Select(r.%Next():r.%GetData(1),1:"absent")'),
  ]);
  return markerValue(output, 'VALUE');
}

/** Drop the AC14 table and remove the probe objects; whether nothing of the probe schema is left. */
function removeProbe() {
  inUser([`DROP TABLE ${MADE}`]);
  const output = runIris(config.container, [marker('REMOVED', `$System.Status.GetErrorText(##class(${PROBE}).Remove())`)]);
  return markerValue(output, 'REMOVED') === '';
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates, changes and drops SQL tables, so it never runs inside the live container');
  await assertThrowaway(config);
  assert.ok(removeProbe(), 'USER holds no probe object before the run');
  const output = runIris(config.container, [marker('MADE', `$System.Status.GetErrorText(##class(${PROBE}).Make())`)]);
  assert.equal(markerValue(output, 'MADE'), '', 'the probe objects are made');
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  assert.ok(removeProbe(), 'no probe object is left in USER');
});

function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/** The walk of the screen on display at three passes, answering entries outside the baseline. */
async function structural(page, route) {
  const found = [];
  const passes = [
    { viewport: VIEWPORTS.wide, theme: 'light', checks: INVARIANTS },
    { viewport: VIEWPORTS.narrow, theme: 'light', checks: ['name', 'min-width', 'overflow'] },
    { viewport: VIEWPORTS.wide, theme: 'dark', checks: ['contrast'] },
  ];
  const minimums = componentMinimums();
  const surfaces = {};
  for (const { viewport, theme, checks } of passes) {
    await page.setViewport(viewport);
    await page.evaluate((dark) => document.documentElement.classList.toggle('ocu-theme-dark', dark), theme === 'dark');
    await frames(page);
    surfaces[theme] = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
    const { entries } = await detectScreen(page, { route, checks, viewport: viewport.width, theme, minimums });
    found.push(...entries);
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await frames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  return compare(collapse(found), readBaseline()?.entries ?? []).fresh.map((entry) => `${entry.key}: ${entry.measured}`);
}

/** Wait until the status line reads `text`, or begins with it when `prefix`. */
async function statusReads(page, text, prefix = false) {
  await page.waitForFunction(
    (wanted, starts) => {
      const line = (document.querySelector('[data-ocu-data="status"]')?.textContent ?? '').trim();
      return starts ? line.startsWith(wanted) : line === wanted;
    },
    { timeout: config.navigationTimeoutMs },
    text,
    prefix
  );
}

/** Click the tree node whose label reads `text` exactly, under `slot`. */
async function clickNode(page, slot, text) {
  await page.waitForFunction(
    (selector, wanted) => Array.from(document.querySelectorAll(selector)).some((node) => node.querySelector('.ocu-data-browser-tree-name')?.textContent.trim() === wanted),
    { timeout: config.navigationTimeoutMs },
    `[data-ocu-data="${slot}"]`,
    text
  );
  await page.evaluate(
    (selector, wanted) => {
      const node = Array.from(document.querySelectorAll(selector)).find((candidate) => candidate.querySelector('.ocu-data-browser-tree-name')?.textContent.trim() === wanted);
      node.click();
    },
    `[data-ocu-data="${slot}"]`,
    text
  );
}

/** Open `table` of the probe schema from the tree. */
async function openTable(page, table) {
  await clickNode(page, 'tree-schema', SCHEMA);
  await clickNode(page, 'tree-object', table);
  await page.waitForFunction((wanted) => (document.querySelector('[data-ocu-data="heading"]')?.textContent ?? '').trim() === wanted, { timeout: config.navigationTimeoutMs }, `${SCHEMA}.${table}`);
}

/** Replace the cell at grid `row` and grid `column` with `text`: Backspace opens it empty, Enter commits. */
async function typeInto(page, row, column, text) {
  await page.click(`#ocu-data-cell-r${row}-c${column}`);
  await page.waitForFunction((id) => document.querySelector('[data-ocu-data="grid"]')?.getAttribute('aria-activedescendant') === id, { timeout: config.navigationTimeoutMs }, `ocu-data-cell-r${row}-c${column}`);
  await page.keyboard.press('Backspace');
  await page.waitForSelector('[data-ocu-data="editor"]', { timeout: config.navigationTimeoutMs });
  await page.keyboard.type(text);
  await page.keyboard.press('Enter');
  await page.waitForFunction(() => document.querySelector('[data-ocu-data="editor"]') === null, { timeout: config.navigationTimeoutMs });
}

/** Press Save changes and Proceed in its warning dialog. */
async function saveConfirmed(page) {
  await page.click('[data-ocu-data="save"]');
  await page.waitForSelector('app-warning-dialog [role="dialog"]', { visible: true, timeout: config.navigationTimeoutMs });
  await page.click('[role="dialog"] .ocu-dialog-actions .ocu-button-primary');
  await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
}

/** The text of grid row `row`'s cell in grid column `column`. */
function cellText(page, row, column) {
  return page.$eval(`#ocu-data-cell-r${row}-c${column}`, (node) => node.textContent.trim());
}

// Mutation (Rule 19): `SqlPort.SaveOutcome` answers `saved` whenever the SQLCODE is 0 or more,
// recompiled on the throwaway -> b's Change cell reads Saved and this goes red.
test('AC1, AC4, AC5, AC12: a typed name and a concurrently changed row are saved through the dialog; one is saved, one rolls back; the page passes the walk', async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${ROUTE}?ns=USER`, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await openTable(page, 'Edit');
    await statusReads(page, 'Rows 1\u20136 of 6');
    await page.waitForSelector('[data-ocu-data="edit-actions"]', { timeout: config.navigationTimeoutMs });
    assert.equal(await cellText(page, 0, 1), 'a', 'row a is first, in key order, after the Change column');
    await typeInto(page, 0, 2, 'abd');
    await typeInto(page, 1, 2, 'new');
    assert.equal(await page.$eval('[data-ocu-data="save"]', (node) => node.textContent.trim()), 'Save changes (2)', 'two rows staged');
    assert.equal(await page.$eval('#ocu-data-cell-r0-c2', (node) => node.classList.contains('ocu-data-browser-staged')), true, 'the staged cell is marked');
    assert.equal(await page.evaluate(() => document.activeElement?.getAttribute('data-ocu-data')), 'grid', 'focus is back on the grid');
    assert.deepEqual(await structural(page, ROUTE), [], 'the editable page with staged rows adds no structural entry');

    inUser([`UPDATE ${SCHEMA}.Edit SET Name = 'BEE' WHERE Code = 'b'`]);
    await saveConfirmed(page);
    await statusReads(page, 'Saved 1 of 2 changes; 1 rolled back.', true);
    assert.equal(await cellText(page, 0, 2), 'abd', 'the saved row reads the saved value, read again');
    assert.equal(await cellText(page, 0, 0), STRINGS.formSaved, 'and its Change cell reads Saved');
    assert.equal(await cellText(page, 1, 2), 'BEE', 'the changed row reads what the instance holds');
    assert.equal(await cellText(page, 1, 0), STRINGS.explorerSqlDataOutcomeChanged, 'and its Change cell names why');
    assert.equal(await page.$eval('[data-ocu-data="save"]', (node) => node.textContent.trim()), 'Save changes (0)', 'nothing is left staged');
    assert.equal(valueInUser(`SELECT Name FROM ${SCHEMA}.Edit WHERE Code = 'a'`), 'abd', 'the instance holds the saved name');
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): `data-browser-grid.ts`'s `tooltipShown` answers false, rebuilt and copied in
// -> no tooltip shows and this goes red; `cutText` answers every cell's text -> the uncut cell shows
// one; the grid's two scroll hides are dropped -> the scroll leaves it shown.
test('AC13 (DW-2028): a cut cell shows its whole value under it, inside the window, on the pointer and on the active cell; an uncut cell shows none; a scroll and an editor hide it', async () => {
  inUser([`UPDATE ${SCHEMA}.Edit SET Name = '${LONG_NAME}' WHERE Code = 'd'`]);
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${ROUTE}?ns=USER`, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await openTable(page, 'Edit');
    await statusReads(page, 'Rows 1\u20136 of 6');
    const cell = '#ocu-data-cell-r3-c2';
    assert.equal(await page.$eval(`${cell} .ocu-data-table-text`, (node) => node.scrollWidth > node.clientWidth), true, 'the long name is cut');
    await page.hover(`${cell} .ocu-data-table-text`);
    await page.waitForSelector('.ocu-data-table-tooltip-placed', { visible: true, timeout: config.navigationTimeoutMs });
    const geometry = await page.evaluate((selector) => {
      const tip = document.querySelector('.ocu-data-table-tooltip').getBoundingClientRect();
      const box = document.querySelector(selector).getBoundingClientRect();
      return { text: document.querySelector('.ocu-data-table-tooltip').textContent.trim(), top: tip.top, bottom: box.bottom, left: tip.left, right: tip.right, width: document.documentElement.clientWidth };
    }, cell);
    assert.equal(geometry.text, LONG_NAME, 'the whole value');
    assert.ok(Math.abs(geometry.top - geometry.bottom) <= 1, `under the cell: ${JSON.stringify(geometry)}`);
    assert.ok(geometry.left >= 0 && geometry.right <= geometry.width, `inside the window: ${JSON.stringify(geometry)}`);
    await page.keyboard.press('Escape');
    await page.waitForFunction(() => document.querySelector('.ocu-data-table-tooltip') === null, { timeout: config.navigationTimeoutMs });

    await page.hover('#ocu-data-cell-r0-c2 .ocu-data-table-text');
    await new Promise((resolve) => setTimeout(resolve, 500));
    assert.equal(await page.$('.ocu-data-table-tooltip'), null, 'an uncut cell shows none');
    await page.hover(`${cell} .ocu-data-table-text`);
    await page.waitForSelector('.ocu-data-table-tooltip-placed', { visible: true, timeout: config.navigationTimeoutMs });
    await page.$eval('.ocu-data-browser-scroll', (node) => node.dispatchEvent(new Event('scroll')));
    await page.waitForFunction(() => document.querySelector('.ocu-data-table-tooltip') === null, { timeout: config.navigationTimeoutMs });

    await page.mouse.move(0, 0);
    await page.click('#ocu-data-cell-r2-c2');
    await page.keyboard.press('ArrowDown');
    await page.waitForSelector('.ocu-data-table-tooltip-placed', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-data-table-tooltip', (node) => node.textContent.trim()), LONG_NAME, 'the active cell shows it too');
    await page.keyboard.press('F2');
    await page.waitForSelector('[data-ocu-data="editor"]', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$('.ocu-data-table-tooltip'), null, 'and an open editor hides it');
    await page.keyboard.press('Escape');
  } finally {
    await context.close();
  }
});

/** Replace SQL query's statement with `text` and run it; with `confirm`, proceed through its confirmation. */
async function runQuery(page, text, confirm) {
  await page.waitForSelector('textarea[data-ocu-sql="statement"]', { timeout: config.navigationTimeoutMs });
  await page.click('textarea[data-ocu-sql="statement"]', { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type('textarea[data-ocu-sql="statement"]', text);
  await page.click('button[data-ocu-sql="run"]');
  if (!confirm) return;
  await page.waitForSelector('app-warning-dialog [role="dialog"]', { visible: true, timeout: config.navigationTimeoutMs });
  await page.click('[role="dialog"] .ocu-dialog-actions .ocu-button-primary');
  await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
  await page.waitForFunction(() => (document.querySelector('[data-ocu-sql="status"]')?.textContent ?? '').trim() !== '', { timeout: config.navigationTimeoutMs });
}

// Mutation (Rule 19): `SqlPort.Save` answers `saved` without running, recompiled on the throwaway ->
// SQL query still reads the old label and this goes red.
test('AC14: a table SQL query creates and fills is changed in Data browser, and SQL query then reads the new value', async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${QUERY_ROUTE}?ns=USER`, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await runQuery(page, `CREATE TABLE ${MADE} (K INTEGER PRIMARY KEY, Label VARCHAR(20))`, true);
    await runQuery(page, `INSERT INTO ${MADE} (K, Label) VALUES (1, 'before')`, true);

    await page.goto(`${config.origin}/ocupilot/${ROUTE}?ns=USER`, { waitUntil: 'networkidle2' });
    await openTable(page, 'Made');
    await statusReads(page, 'Rows 1\u20131 of 1');
    await typeInto(page, 0, 2, 'after');
    await saveConfirmed(page);
    await statusReads(page, 'Saved 1 of 1 changes; 0 rolled back.', true);

    await page.goto(`${config.origin}/ocupilot/${QUERY_ROUTE}?ns=USER`, { waitUntil: 'networkidle2' });
    await runQuery(page, `SELECT Label FROM ${MADE} WHERE K = 1`, false);
    await page.waitForFunction(() => (document.querySelector('[data-ocu-sql="cell"]')?.textContent ?? '').trim() !== '', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-ocu-sql="cell"]', (node) => node.textContent.trim()), 'after', "SQL query's SELECT reads the value Data browser saved");
  } finally {
    await context.close();
  }
});

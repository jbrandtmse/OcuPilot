/**
 * Story 19.16 in a real browser, against the throwaway: Data browser opens two probe tables in tabs,
 * a value staged in the first survives a switch to the second and back -- made with the strip's own
 * keys -- and Ctrl/Cmd+S with Proceed saves it, which SQL query's (Story 19.6) SELECT then reads
 * (AC12, AC10); the page passes the structural walk's checks at 1280 light, 720 light and 1280 dark
 * with two tabs open and again with each dialog open (AC10); Download CSV and Ctrl/Cmd+E hand the
 * browser the page as read, captured where the page passes it to `URL.createObjectURL` (AC1, AC2); Go
 * to row reads a row on another page of a 120-row table by its absolute number and refuses one past
 * the total (AC5); and Delete on a staged tab asks before it closes it (AC8).
 *
 * The probe objects are `OcuPilot.Test.SqlSaveProbe`'s, made in `before` with a 120-row table this
 * spec adds to the probe schema, and removed in `after`, which asserts none is left. Downloads are
 * refused through CDP, so no file lands on disk. Needs the throwaway: it refuses the live container.
 *
 * Run: `node --test --test-concurrency=1 browser/system-explorer-data-browser-tabs.browser-spec.mjs`
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
const MANY = 'OcuProbe198.Many';
const ROUTE = 'system-explorer/sql-data';
const QUERY_ROUTE = 'system-explorer/sql-query';

/** The walk's own media feature (`structural-walk.mjs`): a theme flip lands at once rather than mid-transition. */
const REDUCED_MOTION = [{ name: 'prefers-reduced-motion', value: 'reduce' }];

let browser = null;

const marker = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/** The first cell `query` answers in USER, read as text. */
function valueInUser(query) {
  const output = runIris(config.container, [
    'Set $NAMESPACE="USER"',
    `Set r=##class(%SQL.Statement).%ExecDirect(,"${query.replaceAll('"', '""')}")`,
    marker('VALUE', '$Select(r.%Next():r.%GetData(1),1:"absent")'),
  ]);
  return markerValue(output, 'VALUE');
}

/** Drop the 120-row table and remove the probe objects; whether nothing of the probe schema is left. */
function removeProbe() {
  runIris(config.container, ['Set $NAMESPACE="USER"', `Do ##class(%SQL.Statement).%ExecDirect(,"DROP TABLE ${MANY}")`]);
  const output = runIris(config.container, [marker('REMOVED', `$System.Status.GetErrorText(##class(${PROBE}).Remove())`)]);
  return markerValue(output, 'REMOVED') === '';
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates, changes and drops SQL tables, so it never runs inside the live container');
  await assertThrowaway(config);
  assert.ok(removeProbe(), 'USER holds no probe object before the run');
  const output = runIris(config.container, [marker('MADE', `$System.Status.GetErrorText(##class(${PROBE}).Make())`)]);
  assert.equal(markerValue(output, 'MADE'), '', 'the probe objects are made');
  runIris(config.container, [
    'Set $NAMESPACE="USER"',
    `Do ##class(%SQL.Statement).%ExecDirect(,"CREATE TABLE ${MANY} (K INTEGER PRIMARY KEY, Name VARCHAR(20))")`,
    `For i=1:1:120 { Do ##class(%SQL.Statement).%ExecDirect(,"INSERT INTO ${MANY} (K, Name) VALUES (?, ?)", i, "row"_i) }`,
  ]);
  assert.equal(valueInUser(`SELECT COUNT(*) FROM ${MANY}`), '120', 'the 120-row table is made');
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

/** Open `table` of the probe schema from the tree, expanding the schema the first time. */
async function openTable(page, table) {
  const expanded = await page.$$eval('[data-ocu-data="tree-object"]', (nodes) => nodes.length > 0);
  if (!expanded) await clickNode(page, 'tree-schema', SCHEMA);
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

/** Press `key` with Ctrl held. */
async function withControl(page, key) {
  await page.keyboard.down('Control');
  await page.keyboard.press(key);
  await page.keyboard.up('Control');
}

/** Each tab's accessible name, and which is selected. */
function tabs(page) {
  return page.$$eval('[data-ocu-data="tab"]', (nodes) => nodes.map((node) => ({ name: node.getAttribute('aria-label'), selected: node.getAttribute('aria-selected') === 'true' })));
}

/** The `data-ocu-data` slot of the focused element, and the tab it is on, if any. */
function focused(page) {
  return page.evaluate(() => ({ slot: document.activeElement?.getAttribute('data-ocu-data') ?? '', name: document.activeElement?.getAttribute('aria-label') ?? '' }));
}

/** Replace SQL query's statement with `text` and run it. */
async function runQuery(page, text) {
  await page.waitForSelector('textarea[data-ocu-sql="statement"]', { timeout: config.navigationTimeoutMs });
  await page.click('textarea[data-ocu-sql="statement"]', { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type('textarea[data-ocu-sql="statement"]', text);
  await page.click('button[data-ocu-sql="run"]');
}

// Mutation (Rule 19): `DataBrowserState.save` saves the tab opened last rather than the selected one,
// rebuilt and copied in -> the save sends nothing, no summary is read, and this goes red.
test('AC12, AC10: a value staged in the first of two tabs survives a switch made with the strip\'s keys; Ctrl/Cmd+S and Proceed save it and SQL query reads it; the walk passes with two tabs open', async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${ROUTE}?ns=USER`, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await openTable(page, 'Edit');
    await statusReads(page, 'Rows 1\u20136 of 6');
    await typeInto(page, 0, 2, 'tabbed');
    await openTable(page, 'Pair');
    await statusReads(page, 'Rows 1\u20132 of 2');
    assert.deepEqual(await tabs(page), [
      { name: `${SCHEMA}.Edit, 1 changes waiting to be saved.`, selected: false },
      { name: `${SCHEMA}.Pair`, selected: true },
    ]);
    assert.equal(await page.$eval('[data-ocu-data="tabs"]', (node) => `${node.getAttribute('role')}|${node.getAttribute('aria-label')}`), `tablist|${STRINGS.explorerSqlDataOpenTables}`);
    assert.deepEqual(await structural(page, ROUTE), [], 'Data browser with two tabs open adds no structural entry');

    await page.focus('[data-ocu-data="tab"][aria-selected="true"]');
    await page.keyboard.press('ArrowLeft');
    assert.equal((await focused(page)).name, `${SCHEMA}.Edit, 1 changes waiting to be saved.`, 'Left moves focus to the first tab');
    await page.keyboard.press('Enter');
    await page.waitForFunction((wanted) => (document.querySelector('[data-ocu-data="heading"]')?.textContent ?? '').trim() === wanted, { timeout: config.navigationTimeoutMs }, `${SCHEMA}.Edit`);
    assert.equal(await page.$eval('#ocu-data-cell-r0-c2', (node) => node.textContent.trim()), 'tabbed', 'the staged value came back with its tab');
    assert.equal(
      await page.$eval('[data-ocu-data="panel"]', (node) => node.getAttribute('aria-labelledby')),
      await page.$eval('[data-ocu-data="tab"][aria-selected="true"]', (node) => node.id),
      'the panel is labeled by the selected tab'
    );

    await page.focus('[data-ocu-data="grid"]');
    await withControl(page, 'KeyS');
    await page.waitForSelector('app-warning-dialog [role="dialog"]', { visible: true, timeout: config.navigationTimeoutMs });
    await page.click('[role="dialog"] .ocu-dialog-actions .ocu-button-primary');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await statusReads(page, 'Saved 1 of 1 changes; 0 rolled back.', true);

    await page.goto(`${config.origin}/ocupilot/${QUERY_ROUTE}?ns=USER`, { waitUntil: 'networkidle2' });
    await runQuery(page, `SELECT Name FROM ${SCHEMA}.Edit WHERE Code = 'a'`);
    await page.waitForFunction(() => (document.querySelector('[data-ocu-sql="cell"]')?.textContent ?? '').trim() !== '', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-ocu-sql="cell"]', (node) => node.textContent.trim()), 'tabbed', "SQL query's SELECT reads the value saved from the first tab");
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): `DataTab.exportPage` writes the overlaid rows, rebuilt and copied in -> the
// staged value reaches the file and this goes red.
test('AC1, AC2: Download CSV and Ctrl/Cmd+E hand the browser the page as read -- the BOM, the columns, the rows in order, NULL empty, BIT as its word -- and no staged value', async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${ROUTE}?ns=USER`, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    const cdp = await browser.target().createCDPSession();
    await cdp.send('Browser.setDownloadBehavior', { behavior: 'deny', browserContextId: context.id });
    await page.evaluateOnNewDocument(() => {
      window.ocuCsv = [];
      const original = URL.createObjectURL.bind(URL);
      URL.createObjectURL = (blob) => {
        blob.arrayBuffer().then((buffer) => {
          const bytes = new Uint8Array(buffer);
          window.ocuCsv.push({ type: blob.type, head: Array.from(bytes.slice(0, 3)), text: new TextDecoder().decode(bytes.slice(3)) });
        });
        return original(blob);
      };
    });
    await page.goto(`${config.origin}/ocupilot/${ROUTE}?ns=USER`, { waitUntil: 'networkidle2' });
    await openTable(page, 'Edit');
    await statusReads(page, 'Rows 1\u20136 of 6');
    await typeInto(page, 1, 2, 'stagedvalue');
    const headers = await page.$$eval('[data-ocu-data="header"]', (nodes) => nodes.map((node) => node.getAttribute('data-column')));

    await page.click('[data-ocu-data="export"]');
    await page.waitForFunction(() => window.ocuCsv.length === 1, { timeout: config.navigationTimeoutMs });
    const [file] = await page.evaluate(() => window.ocuCsv);
    assert.equal(file.type, 'text/csv;charset=utf-8');
    assert.deepEqual(file.head, [0xef, 0xbb, 0xbf], 'the byte-order mark');
    const lines = file.text.split('\r\n');
    assert.equal(lines[0], headers.join(','), 'the column names, in ordinal order');
    assert.deepEqual(lines.slice(1, 7).map((line) => line.split(',')[0]), ['a', 'b', 'c', 'd', 'e', 'f'], 'every row, in page order');
    assert.equal(lines[7], '', 'each line ends CRLF');
    const name = headers.indexOf('Name');
    const flag = headers.indexOf('Flag');
    assert.equal(lines[2].split(',')[name], 'bee', 'b is written as read, not as staged');
    assert.equal(lines[5].split(',')[name], '', 'e\'s NULL name is written empty');
    assert.equal(lines[1].split(',')[flag], STRINGS.tableStatusYes, 'a\'s BIT is written as its word');
    assert.ok(!file.text.includes('stagedvalue'), 'no staged value is written');
    await statusReads(page, `Saved rows 1\u20136 to ${SCHEMA.toLowerCase()}-edit-`, true);

    await page.focus('[data-ocu-data="grid"]');
    await withControl(page, 'KeyE');
    await page.waitForFunction(() => window.ocuCsv.length === 2, { timeout: config.navigationTimeoutMs });
    assert.equal((await page.evaluate(() => window.ocuCsv[1].text)), file.text, 'Ctrl/Cmd+E saves the same page');
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): `goToRow` reads offset `n * size`, rebuilt and copied in -> row 105 is read past
// the table's end and this goes red.
test('AC5, AC10: Go to row reads row 105 of 120 on its own page and makes it active in the column it was in; a row past the total is refused in the dialog; the walk passes with each dialog open', async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${ROUTE}?ns=USER`, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await openTable(page, 'Many');
    await statusReads(page, 'Rows 1\u2013100 of 120');
    await page.select('[data-ocu-data="size"]', '50');
    await statusReads(page, 'Rows 1\u201350 of 120');
    await page.click('#ocu-data-cell-r2-c2');
    await withControl(page, 'KeyG');
    await page.waitForSelector('[data-ocu-data="row-number"]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-ocu-data="row-range"]', (node) => node.textContent.trim()), 'Enter a row from 1 to 120.');
    await page.type('[data-ocu-data="row-number"]', '121');
    await page.keyboard.press('Enter');
    await page.waitForFunction(() => document.querySelector('[data-ocu-data="row-number"]')?.getAttribute('aria-invalid') === 'true', { timeout: config.navigationTimeoutMs });
    assert.deepEqual(await structural(page, ROUTE), [], 'Data browser with Go to row open adds no structural entry');

    await page.click('[data-ocu-data="row-number"]', { clickCount: 3 });
    await page.keyboard.press('Backspace');
    await page.type('[data-ocu-data="row-number"]', '105');
    await page.keyboard.press('Enter');
    await statusReads(page, 'Rows 101\u2013120 of 120');
    await page.waitForFunction(() => document.querySelector('[data-ocu-data="grid"]')?.getAttribute('aria-activedescendant') === 'ocu-data-cell-r4-c2', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('#ocu-data-cell-r4-c1', (node) => node.textContent.trim()), '105', 'row 105 is the active row');
    assert.equal(await page.$eval('#ocu-data-cell-r4-c2', (node) => node.closest('[role="row"]').getAttribute('aria-rowindex')), '106');
    assert.equal((await focused(page)).slot, 'grid', 'focus is on the grid');

    await withControl(page, 'Slash');
    await page.waitForSelector('[data-ocu-data="shortcut-list"]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal((await page.$$('[data-ocu-data="shortcut-label"]')).length, 10, 'every shortcut is listed');
    assert.deepEqual(await structural(page, ROUTE), [], 'Data browser with Keyboard shortcuts open adds no structural entry');
    await page.keyboard.press('Escape');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    assert.equal((await focused(page)).slot, 'grid', 'focus returns to the grid');
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): the page's close skips `requestLeave` for a staged tab, rebuilt and copied in ->
// Delete closes it at once and this goes red.
test('AC8: Delete on a tab holding a staged row asks Leave without saving?; Cancel keeps it, Confirm drops the row and closes it, and the instance is unchanged', async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${ROUTE}?ns=USER`, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await openTable(page, 'Edit');
    await statusReads(page, 'Rows 1\u20136 of 6');
    await typeInto(page, 2, 2, 'dropme');
    await openTable(page, 'Pair');
    const staged = `${SCHEMA}.Edit, 1 changes waiting to be saved.`;
    await page.focus(`[data-ocu-data="tab"][aria-label="${staged}"]`);
    await page.keyboard.press('Delete');
    await page.waitForSelector('[data-ocu-data="leave"]', { visible: true, timeout: config.navigationTimeoutMs });
    await page.click('[role="dialog"] .ocu-dialog-actions .ocu-button-secondary');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    assert.deepEqual((await tabs(page)).map((tab) => tab.name), [staged, `${SCHEMA}.Pair`], 'Cancel keeps the tab and its row');
    assert.equal((await focused(page)).name, staged, 'focus returns to the tab');
    await page.keyboard.press('Delete');
    await page.waitForSelector('[data-ocu-data="leave"]', { visible: true, timeout: config.navigationTimeoutMs });
    await page.click('[data-ocu-data="leave"]');
    await page.waitForFunction(() => document.querySelectorAll('[data-ocu-data="tab"]').length === 1, { timeout: config.navigationTimeoutMs });
    assert.deepEqual(await tabs(page), [{ name: `${SCHEMA}.Pair`, selected: true }]);
    await statusReads(page, `${SCHEMA}.Edit closed.`, true);
    assert.equal(valueInUser(`SELECT Name FROM ${SCHEMA}.Edit WHERE Code = 'c'`), 'sea', 'nothing was written');
  } finally {
    await context.close();
  }
});

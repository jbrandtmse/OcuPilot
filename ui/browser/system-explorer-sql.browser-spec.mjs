/**
 * Stories 19.5 and 19.14 in a real browser, against the throwaway: SQL tables lists the probe
 * schema's tables, the probe table's name opens its nine catalog tabs in the classic order, and Fields
 * then Triggers keep the table, each tab reading it through its own declared read and the trigger's
 * code shown as text (19.5 AC2, AC8); Partitions shows its empty state for the plain table and SQL
 * statements the probe's statement (19.14 AC1, AC4); the side bar marks SQL tables for every tab; the
 * System box adds system tables (19.5 AC1); a view's name opens View info with its text, then Fields
 * and SQL statements, and a procedure's name opens Stored procedure info, then SQL statements, each
 * tab reading the object through its own declared read (19.14 AC2, AC3, AC11). The list, the Triggers
 * tab and a view's three tabs, which the structural walk skips, pass its checks at 1280 light, 720
 * light and 1280 dark, with no entry beyond the baseline.
 *
 * The probe objects are `OcuPilot.Test.ExplorerSqlProbe`'s, created in `before` and removed in
 * `after` by that class. It refuses the live container.
 *
 * Run: `node --test --test-concurrency=1 browser/system-explorer-sql.browser-spec.mjs` (after
 * `npm run build`, the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { ROW_SELECTOR, clickRowCentre } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { encodeEntityId } = await import(join(uiRoot, 'src', 'app', 'core', 'entity-id.ts'));

const config = browserConfig();
const STRINGS = loadStrings();
const PROBE = 'OcuPilot.Test.ExplorerSqlProbe';
const SCHEMA = 'OcuProbe195';
const TABLE = 'OcuProbe195.Visible';
const VIEW = 'OcuProbe195.VisibleNames';
const QUERY = 'OcuProbe195.Names';
const CODE_MARK = 'OcuProbe195Code';
const LITERAL = 'OcuProbe195Literal';
const VIEW_LITERAL = 'OcuProbe195ViewLiteral';
const VIEWS_ROUTE = 'system-explorer/sql-views';
const PROCEDURES_ROUTE = 'system-explorer/sql-procedures';
const TABLES_ROUTE = 'system-explorer/sql-tables';
const TABS_ROUTE = 'system-explorer/sql-tables';
const READ_PREFIX = '/api/ocupilot/screens/';

/** The walk's own media feature (`structural-walk.mjs`): a theme flip lands at once rather than mid-transition. */
const REDUCED_MOTION = [{ name: 'prefers-reduced-motion', value: 'reduce' }];

let browser = null;

const marker = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates and removes SQL objects, so it never runs inside the live container');
  await assertThrowaway(config);
  const output = runIris(config.container, [`Set tSC=##class(${PROBE}).Make("USER")`, marker('OK', '$System.Status.IsOK(tSC)')]);
  assert.equal(markerValue(output, 'OK'), '1', `the probe objects are created in USER: ${output}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  const output = runIris(config.container, [`Set tSC=##class(${PROBE}).Remove("USER")`, marker('OK', '$System.Status.IsOK(tSC)')]);
  assert.equal(markerValue(output, 'OK'), '1', `no probe object is left in USER: ${output}`);
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

/** Record every screen read the page issues, as path and query. */
function recordReads(page) {
  const reads = [];
  page.on('request', (request) => {
    const parsed = new URL(request.url());
    if (parsed.pathname.startsWith(READ_PREFIX)) reads.push(parsed.pathname + parsed.search);
  });
  return reads;
}

/** Search the list on display with `schema`, and with the System box checked when `system` is. */
async function searchList(page, { schema, system }) {
  await page.waitForSelector('input[data-ocu-criterion="schema"]', { timeout: config.navigationTimeoutMs });
  await page.click('input[data-ocu-criterion="schema"]', { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type('input[data-ocu-criterion="schema"]', schema);
  const checked = await page.$eval('input[type="checkbox"][data-ocu-criterion="system"]', (box) => box.checked);
  if (checked !== system) await page.click('input[type="checkbox"][data-ocu-criterion="system"]');
  await page.click('.ocu-criteria-controls button[type="submit"]');
}

/** Wait until the grid shows a row whose text holds `text`. */
async function rowShowing(page, text) {
  await page.waitForFunction(
    (selector, wanted) => Array.from(document.querySelectorAll(selector)).some((row) => row.textContent.includes(wanted)),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    text
  );
}

/**
 * Open the tab at `route` from the strip as a keyboard user does: focus it and press Enter. A strip
 * wider than the content column pages its tabs, so a tab paged out of view is reached this way.
 */
async function openTab(page, route) {
  await page.focus(`.ocu-detail-tab[data-route="${route}"]`);
  await page.keyboard.press('Enter');
}

/** The side bar's current entry's label, or `''`, opening the bar first where the width has yielded it. */
async function currentEntry(page) {
  if ((await page.$('app-side-bar nav.ocu-side-bar')) === null) {
    await page.keyboard.down('Control');
    await page.keyboard.press('b');
    await page.keyboard.up('Control');
  }
  await page.waitForSelector('app-side-bar nav.ocu-side-bar', { timeout: config.navigationTimeoutMs });
  return page.evaluate(() => document.querySelector('app-side-bar .ocu-side-bar-item[aria-current="page"] .ocu-side-bar-label')?.textContent?.trim() ?? '');
}

test('AC2, AC8: the probe table opens to its tabs, and Fields then Triggers keep it, each reading it, the code shown as text', async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${TABLES_ROUTE}?ns=USER`, VIEWPORTS.wide, REDUCED_MOTION);
  const reads = recordReads(page);
  try {
    await searchList(page, { schema: SCHEMA, system: false });
    await rowShowing(page, TABLE);
    const names = await page.$$eval(ROW_SELECTOR, (rows) => rows.map((row) => row.querySelector('[role="gridcell"]')?.textContent.trim()));
    assert.deepEqual(names, ['OcuProbe195.A.B', 'OcuProbe195.Hidden', 'OcuProbe195.Parted', TABLE], 'the probe schema\'s tables');
    assert.deepEqual(await structural(page, TABLES_ROUTE), [], 'SQL tables with its rows adds no structural entry');

    // Mutation (Rule 19): skip `documentScreenFor` for the Tables list in `data-table.ts`'s link chain,
    // so its name cell links to the list itself -> the click selects the row and the path wait times out.
    await clickRowCentre(page, { text: TABLE, link: true });
    const id = encodeEntityId(TABLE);
    await page.waitForFunction((path) => location.pathname === path, { timeout: config.navigationTimeoutMs }, `/ocupilot/${TABS_ROUTE}/document/${id}`);
    await page.waitForSelector('nav.ocu-detail-tabs', { timeout: config.navigationTimeoutMs });
    const labels = await page.$$eval('.ocu-detail-tab-label', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(
      labels,
      [
        STRINGS.explorerSqlTabInfo,
        STRINGS.explorerSqlTabFields,
        STRINGS.explorerSqlTabIndices,
        STRINGS.explorerSqlTabPartitions,
        STRINGS.explorerSqlTabPartitionMappings,
        STRINGS.explorerSqlTabTriggers,
        STRINGS.explorerSqlTabConstraints,
        STRINGS.explorerSqlTabCachedQueries,
        STRINGS.explorerSqlTabStatements,
      ],
      'the nine tabs, in the classic order'
    );
    await rowShowing(page, 'OcuProbe195.Visible');
    assert.equal(await currentEntry(page), STRINGS.explorerSqlTablesLabel, 'the side bar marks SQL tables');

    await openTab(page, `${TABS_ROUTE}/fields`);
    await page.waitForFunction((path) => location.pathname === path, { timeout: config.navigationTimeoutMs }, `/ocupilot/${TABS_ROUTE}/fields/${id}`);
    await rowShowing(page, 'Parent');
    assert.ok(reads.some((read) => read.startsWith(`${READ_PREFIX}explorer.sqlfields/read?`) && read.includes(`table=${encodeURIComponent(TABLE)}`)), `Fields reads the table: ${JSON.stringify(reads)}`);

    // Mutation (Rule 19): open the bare tab route in `DetailPage.open` -> each tab opens with no table
    // and the path waits time out.
    await openTab(page, `${TABS_ROUTE}/triggers`);
    await page.waitForFunction((path) => location.pathname === path, { timeout: config.navigationTimeoutMs }, `/ocupilot/${TABS_ROUTE}/triggers/${id}`);
    await rowShowing(page, 'VisibleStamp');
    assert.ok(reads.some((read) => read.startsWith(`${READ_PREFIX}explorer.sqltriggers/read?`) && read.includes(`table=${encodeURIComponent(TABLE)}`)), `Triggers reads the table through its own read: ${JSON.stringify(reads)}`);
    const code = await page.evaluate((mark) => {
      const cell = Array.from(document.querySelectorAll('[role="gridcell"]')).find((node) => node.textContent.includes(mark));
      return cell === undefined ? null : { text: cell.textContent, elements: cell.querySelectorAll('*').length };
    }, CODE_MARK);
    assert.ok(code !== null && code.text.includes('Set {Code} = "probe"'), `the trigger's code is shown: ${JSON.stringify(code)}`);
    assert.ok(code.elements <= 1, 'as text, not markup');
    assert.equal(await currentEntry(page), STRINGS.explorerSqlTablesLabel, 'and the side bar still marks SQL tables');
    assert.deepEqual(await structural(page, `${TABS_ROUTE}/triggers/:id`), [], 'the Triggers tab adds no structural entry');

    // Story 19.14 AC4: the plain table reads no partition, and shows the empty state.
    await openTab(page, `${TABS_ROUTE}/partitions`);
    await page.waitForFunction((path) => location.pathname === path, { timeout: config.navigationTimeoutMs }, `/ocupilot/${TABS_ROUTE}/partitions/${id}`);
    await page.waitForSelector('.ocu-data-table-empty', { timeout: config.navigationTimeoutMs });
    // Story 19.14 AC1: SQL statements shows the probe statement, its kept literal as text.
    await openTab(page, `${TABS_ROUTE}/statements`);
    await page.waitForFunction((path) => location.pathname === path, { timeout: config.navigationTimeoutMs }, `/ocupilot/${TABS_ROUTE}/statements/${id}`);
    await rowShowing(page, LITERAL);
    assert.ok(reads.some((read) => read.startsWith(`${READ_PREFIX}explorer.sqltablestatements/read?`) && read.includes(`table=${encodeURIComponent(TABLE)}`)), `SQL statements reads the table through its own read: ${JSON.stringify(reads)}`);
  } finally {
    await context.close();
  }
});

test('Story 19.14 AC2, AC11: a view opens to View info with its text, then Fields and SQL statements keep it, each reading it', async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${VIEWS_ROUTE}?ns=USER`, VIEWPORTS.wide, REDUCED_MOTION);
  const reads = recordReads(page);
  try {
    await searchList(page, { schema: SCHEMA, system: false });
    await rowShowing(page, VIEW);
    // Mutation (Rule 19): skip `documentScreenFor` for the Views list in `data-table.ts`'s link chain,
    // so its name cell links to the list itself -> the click selects the row and the path wait times out.
    await clickRowCentre(page, { text: VIEW, link: true });
    const id = encodeEntityId(VIEW);
    await page.waitForFunction((path) => location.pathname === path, { timeout: config.navigationTimeoutMs }, `/ocupilot/${VIEWS_ROUTE}/document/${id}`);
    await page.waitForSelector('nav.ocu-detail-tabs', { timeout: config.navigationTimeoutMs });
    const labels = await page.$$eval('.ocu-detail-tab-label', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(labels, [STRINGS.explorerSqlTabViewInfo, STRINGS.explorerSqlTabFields, STRINGS.explorerSqlTabStatements], 'the view\'s three tabs');
    await rowShowing(page, `SELECT Id, Name FROM ${TABLE}`);
    assert.equal(await currentEntry(page), STRINGS.explorerSqlViewsLabel, 'the side bar marks SQL views');
    assert.deepEqual(await structural(page, `${VIEWS_ROUTE}/document/:id`), [], 'View info adds no structural entry');

    await openTab(page, `${VIEWS_ROUTE}/fields`);
    await page.waitForFunction((path) => location.pathname === path, { timeout: config.navigationTimeoutMs }, `/ocupilot/${VIEWS_ROUTE}/fields/${id}`);
    await rowShowing(page, '%Library.String');
    assert.deepEqual(await structural(page, `${VIEWS_ROUTE}/fields/:id`), [], 'Fields adds no structural entry');

    await openTab(page, `${VIEWS_ROUTE}/statements`);
    await page.waitForFunction((path) => location.pathname === path, { timeout: config.navigationTimeoutMs }, `/ocupilot/${VIEWS_ROUTE}/statements/${id}`);
    await rowShowing(page, VIEW_LITERAL);
    assert.deepEqual(await structural(page, `${VIEWS_ROUTE}/statements/:id`), [], 'SQL statements adds no structural entry');
    for (const tool of ['explorer.sqlview', 'explorer.sqlviewfields', 'explorer.sqlviewstatements']) {
      assert.ok(reads.some((read) => read.startsWith(`${READ_PREFIX}${tool}/read?`) && read.includes(`view=${encodeURIComponent(VIEW)}`)), `${tool} reads the view through its own read: ${JSON.stringify(reads)}`);
    }
  } finally {
    await context.close();
  }
});

test('Story 19.14 AC3, AC11: a procedure opens to Stored procedure info, then SQL statements keeps it, each reading it', async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${PROCEDURES_ROUTE}?ns=USER`, VIEWPORTS.wide, REDUCED_MOTION);
  const reads = recordReads(page);
  try {
    await searchList(page, { schema: SCHEMA, system: false });
    await rowShowing(page, QUERY);
    await clickRowCentre(page, { text: QUERY, link: true });
    const id = encodeEntityId(QUERY);
    await page.waitForFunction((path) => location.pathname === path, { timeout: config.navigationTimeoutMs }, `/ocupilot/${PROCEDURES_ROUTE}/document/${id}`);
    await page.waitForSelector('nav.ocu-detail-tabs', { timeout: config.navigationTimeoutMs });
    const labels = await page.$$eval('.ocu-detail-tab-label', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(labels, [STRINGS.explorerSqlTabProcedureInfo, STRINGS.explorerSqlTabStatements], 'the procedure\'s two tabs');
    await rowShowing(page, 'OcuProbe195.queryNames');
    assert.equal(await currentEntry(page), STRINGS.explorerSqlProceduresLabel, 'the side bar marks SQL procedures');

    await openTab(page, `${PROCEDURES_ROUTE}/statements`);
    await page.waitForFunction((path) => location.pathname === path, { timeout: config.navigationTimeoutMs }, `/ocupilot/${PROCEDURES_ROUTE}/statements/${id}`);
    await rowShowing(page, '"NAMES"');
    for (const tool of ['explorer.sqlprocedure', 'explorer.sqlprocedurestatements']) {
      assert.ok(reads.some((read) => read.startsWith(`${READ_PREFIX}${tool}/read?`) && read.includes(`procedure=${encodeURIComponent(QUERY)}`)), `${tool} reads the procedure through its own read: ${JSON.stringify(reads)}`);
    }
  } finally {
    await context.close();
  }
});

test('AC1: the System box adds system tables', async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${TABLES_ROUTE}?ns=USER`, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await page.waitForSelector('input[type="checkbox"][data-ocu-criterion="system"]', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('input[type="checkbox"][data-ocu-criterion="system"]', (box) => box.checked), false, 'the System box opens unchecked');
    await searchList(page, { schema: '%Dictionary', system: false });
    await page.waitForSelector('.ocu-data-table-empty', { timeout: config.navigationTimeoutMs });
    await searchList(page, { schema: '%Dictionary', system: true });
    await rowShowing(page, '%Dictionary.ClassDefinition');
  } finally {
    await context.close();
  }
});

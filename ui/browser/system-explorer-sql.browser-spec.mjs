/**
 * Stories 19.5 and 19.14 in a real browser, against the throwaway: SQL tables lists the probe
 * schema's tables, the probe table's name opens its nine catalog tabs in the classic order, and Fields
 * then Triggers keep the table, each tab reading it through its own declared read and the trigger's
 * code shown as text (19.5 AC2, AC8); Partitions shows its empty state for the plain table and SQL
 * statements the probe's statement (19.14 AC1, AC4); the side bar marks SQL tables for every tab; the
 * System box adds system tables (19.5 AC1); a view's name opens View info with its text, then Fields
 * and SQL statements, and a procedure's name opens Stored procedure info, then SQL statements, each
 * tab reading the object through its own declared read (19.14 AC2, AC3, AC11); each SQL statements tab
 * shows the statistics note above its rows, and Partitions shows none. The list, the Triggers
 * tab and a view's three tabs, which the structural walk skips, pass its checks at 1280 light, 720
 * light and 1280 dark, with no entry beyond the baseline. The table's nine tabs all lie inside
 * their strip at 1,024 and 1,280, wrapped onto 40px rows with no pagination, and a view whose text
 * runs past its cell shows that text whole beneath its row in a long block, which a pointer or the
 * keyboard reaches to the end, in light and in dark. The keyboard path is walked from Tab: Tab
 * reaches Show more, Enter opens it and End brings the last line on screen. The one trigger of the
 * probe table shows its code in a long block named by the Code header. A schema's name on SQL
 * schemas opens its Tables, Views and Procedures tabs under the locator SQL schemas, then the
 * schema, the Tables read carries the schema and no system choice, a procedure's name on the
 * Procedures tab opens that procedure, and a schema holding one table and nothing else shows the
 * Views tab's empty sentence (Story 20.38 AC1, AC2, AC5). A direct visit to a system schema's tabs
 * lists its objects with no System choice and opens a `%Library` procedure, and a schema tab opened
 * with no schema shows the request refused.
 *
 * The probe objects are `OcuPilot.Test.ExplorerSqlProbe`'s, created in `before` and removed in
 * `after` by that class, the bare schema's by its `MakeBare` and `RemoveBare`. It refuses the live
 * container.
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
import { ROW_SELECTOR, clickRowCentre, filterToSubset, viewCount, waitForRows } from './list-spec.mjs';
import { setDarkTheme, settleViewport, signedInAt, transitionsSettled } from './panel-spec.mjs';
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
const LONG_VIEW = 'OcuProbe195.LongView';
const LONG_VIEW_MARK = 'OcuProbe195View';
const BARE_SCHEMA = 'OcuProbe2038';
const BARE_TABLE = 'OcuProbe2038.Bare';
const PROCEDURE = 'OcuProbe195.Echo';
const SYSTEM_SCHEMA = '%Dictionary';
const SYSTEM_TABLE = '%Dictionary.ClassDefinition';
const PROCEDURE_SCHEMA = '%Library';
const SCHEMAS_ROUTE = 'system-explorer/sql-schemas';
const VIEWS_ROUTE = 'system-explorer/sql-views';
const PROCEDURES_ROUTE = 'system-explorer/sql-procedures';
const TABLES_ROUTE = 'system-explorer/sql-tables';
const TABS_ROUTE = 'system-explorer/sql-tables';
const READ_PREFIX = '/api/ocupilot/screens/';
/** Tab presses allowed from the tab strip to the long block's control. */
const TAB_LIMIT = 60;
/** `ExplorerSqlProbe`'s `LONGLENGTH`: the long view's text and the probe trigger's comment line each carry a run this long. */
const LONG_TEXT_LENGTH = 1500;

/** The walk's own media feature (`structural-walk.mjs`): a theme flip lands at once rather than mid-transition. */
const REDUCED_MOTION = [{ name: 'prefers-reduced-motion', value: 'reduce' }];

let browser = null;

const marker = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates and removes SQL objects, so it never runs inside the live container');
  await assertThrowaway(config);
  const output = runIris(config.container, [
    `Set tSC=##class(${PROBE}).Make("USER")`,
    marker('OK', '$System.Status.IsOK(tSC)'),
    `Set tBare=##class(${PROBE}).MakeBare("USER")`,
    marker('BARE', '$System.Status.IsOK(tBare)'),
  ]);
  assert.equal(markerValue(output, 'OK'), '1', `the probe objects are created in USER: ${output}`);
  assert.equal(markerValue(output, 'BARE'), '1', `the bare probe schema is created in USER: ${output}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  const output = runIris(config.container, [
    `Set tSC=##class(${PROBE}).Remove("USER")`,
    marker('OK', '$System.Status.IsOK(tSC)'),
    `Set tBare=##class(${PROBE}).RemoveBare("USER")`,
    marker('BARE', '$System.Status.IsOK(tBare)'),
  ]);
  assert.equal(markerValue(output, 'OK'), '1', `no probe object is left in USER: ${output}`);
  assert.equal(markerValue(output, 'BARE'), '1', `no bare probe object is left in USER: ${output}`);
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
    await settleViewport(page, viewport);
    await page.evaluate((dark) => document.documentElement.classList.toggle('ocu-theme-dark', dark), theme === 'dark');
    await frames(page);
    await transitionsSettled(page, config.navigationTimeoutMs);
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

/** Open the tab at `route` from the strip as a keyboard user does: focus it and press Enter. */
async function openTab(page, route) {
  await page.focus(`.ocu-detail-tab[data-route="${route}"]`);
  await page.keyboard.press('Enter');
}

/** The locator's segments, area first, as the text the page shows. */
function locatorSegments(page) {
  return page.$$eval('nav.ocu-locator-bar .ocu-locator-link, nav.ocu-locator-bar .ocu-locator-segment', (nodes) => nodes.map((node) => node.textContent.trim()));
}

/** The value query parameter `name` carries in a recorded read, or `null` when the read does not send it. */
function readParam(read, name) {
  return new URL(read, 'http://localhost').searchParams.get(name);
}

/** The first recorded read of screen tool `tool`, or `undefined`. */
function readOf(reads, tool) {
  return reads.find((read) => read.startsWith(`${READ_PREFIX}${tool}/read?`));
}

/** Open the schema `name` from SQL schemas: filter the list to it and click its name. */
async function openSchema(page, name) {
  await waitForRows(page, config.navigationTimeoutMs);
  const total = await viewCount(page);
  await filterToSubset(page, { text: name, expectRow: name, total, timeoutMs: config.navigationTimeoutMs });
  await clickRowCentre(page, { text: name, link: true });
  await page.waitForFunction((path) => location.pathname === path, { timeout: config.navigationTimeoutMs }, `/ocupilot/${SCHEMAS_ROUTE}/document/${encodeEntityId(name)}`);
  await page.waitForSelector('nav.ocu-detail-tabs', { timeout: config.navigationTimeoutMs });
}

/** The text of the read's note the list page draws above its table, or `null` when it draws none. */
function noteShown(page) {
  return page.evaluate(() => document.querySelector('app-list-page .ocu-list-page-note')?.textContent?.trim() ?? null);
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

/** The tab strip's geometry: its link container's box, every tab's box, and how each pagination control displays. */
function stripGeometry(page) {
  return page.evaluate(() => {
    const box = (element) => {
      const { left, right, top, bottom, width, height } = element.getBoundingClientRect();
      return { left, right, top, bottom, width, height };
    };
    const container = document.querySelector('nav.ocu-detail-tabs .mat-mdc-tab-link-container');
    return {
      container: box(container),
      tabs: Array.from(document.querySelectorAll('.ocu-detail-tab')).map(box),
      pagination: Array.from(document.querySelectorAll('nav.ocu-detail-tabs .mat-mdc-tab-header-pagination')).map((control) => getComputedStyle(control).display),
    };
  });
}

/**
 * The strip on display at 1,024 and 1,280 px, in light and in dark: every one of its tabs lies inside
 * the link container, each is 40px tall, no pagination control is displayed, and at 1,024 the tabs
 * take more than one row. Leaves the page at the wide viewport in light.
 *
 * Mutation (Rule 19): drop `flex-wrap: wrap` from `.ocu-detail-tabs .mat-mdc-tab-links`, rebuilt and
 * redeployed -> the containment assertion goes red at 1,024 in light, naming the tab past the edge.
 */
async function assertTabsWrap(page, count) {
  for (const width of [1024, 1280]) {
    for (const dark of [false, true]) {
      const where = `${width}px ${dark ? 'dark' : 'light'}`;
      await settleViewport(page, { width, height: VIEWPORTS.wide.height });
      await setDarkTheme(page, dark);
      await transitionsSettled(page, config.navigationTimeoutMs);
      const { container, tabs, pagination } = await stripGeometry(page);
      assert.equal(tabs.length, count, `${where}: every tab is drawn`);
      tabs.forEach((tab, index) => {
        assert.ok(
          tab.left >= container.left - 1 && tab.right <= container.right + 1 && tab.top >= container.top - 1 && tab.bottom <= container.bottom + 1,
          `${where}: tab ${index + 1} lies inside the strip (${JSON.stringify(tab)} in ${JSON.stringify(container)})`
        );
        assert.equal(Math.round(tab.height), 40, `${where}: tab ${index + 1} is 40px tall`);
      });
      assert.ok(pagination.every((display) => display === 'none'), `${where}: no pagination control is displayed (${JSON.stringify(pagination)})`);
      const rows = new Set(tabs.map((tab) => Math.round(tab.top))).size;
      if (width === 1024) assert.ok(rows > 1, `${where}: nine tabs do not fit one row`);
    }
  }
  await setDarkTheme(page, false);
  await settleViewport(page, VIEWPORTS.wide);
  await transitionsSettled(page, config.navigationTimeoutMs);
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

    // Mutation (Rule 19): skip `documentScreenFor` for the Tables list in `nameLinkTarget`,
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
    await assertTabsWrap(page, 9);

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
    assert.equal(await noteShown(page), null, 'Partitions declares no note and draws none');
    // Story 19.14 AC1: SQL statements shows the probe statement, its kept literal as text.
    await openTab(page, `${TABS_ROUTE}/statements`);
    await page.waitForFunction((path) => location.pathname === path, { timeout: config.navigationTimeoutMs }, `/ocupilot/${TABS_ROUTE}/statements/${id}`);
    await rowShowing(page, LITERAL);
    // Mutation (Rule 19): drop the note paragraph from `ListPage`'s template, rebuilt and redeployed ->
    // the three note assertions go red.
    assert.equal(await noteShown(page), STRINGS.explorerSqlStatementsNote, 'SQL statements shows the statistics note above its rows');
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
    // Mutation (Rule 19): skip `documentScreenFor` for the Views list in `nameLinkTarget`,
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
    assert.equal(await noteShown(page), STRINGS.explorerSqlStatementsNote, 'the view\'s SQL statements shows the statistics note');
    assert.deepEqual(await structural(page, `${VIEWS_ROUTE}/statements/:id`), [], 'SQL statements adds no structural entry');
    for (const tool of ['explorer.sqlview', 'explorer.sqlviewfields', 'explorer.sqlviewstatements']) {
      assert.ok(reads.some((read) => read.startsWith(`${READ_PREFIX}${tool}/read?`) && read.includes(`view=${encodeURIComponent(VIEW)}`)), `${tool} reads the view through its own read: ${JSON.stringify(reads)}`);
    }
  } finally {
    await context.close();
  }
});

/**
 * The long block's geometry: its region, the wrapper that scrolls it, where the text's last line
 * sits, and the first row's name text against the part of the row viewport a person sees.
 */
function longBlockGeometry(page) {
  return page.evaluate((rowSelector) => {
    const wrapper = document.querySelector('.ocu-data-table-long');
    const region = wrapper.querySelector('.ocu-long-block-region');
    const text = wrapper.querySelector('.ocu-data-table-long-text');
    const range = document.createRange();
    range.selectNodeContents(text);
    const lines = Array.from(range.getClientRects());
    const last = lines[lines.length - 1];
    const box = wrapper.getBoundingClientRect();
    const host = document.querySelector('app-data-table').getBoundingClientRect();
    const viewport = document.querySelector('app-data-table .ocu-data-table-viewport');
    const viewTop = viewport.getBoundingClientRect().top + viewport.clientTop;
    const name = document.createRange();
    name.selectNodeContents(document.querySelector(rowSelector).querySelector('[role="gridcell"]'));
    const nameBox = name.getBoundingClientRect();
    return {
      viewTop,
      viewBottom: viewTop + viewport.clientHeight,
      rowTextTop: nameBox.top,
      rowTextBottom: nameBox.bottom,
      hostHeight: host.height,
      wrapperHeight: box.height,
      regionScrollHeight: region.scrollHeight,
      regionClientHeight: region.clientHeight,
      wrapperScrollHeight: wrapper.scrollHeight,
      wrapperClientHeight: wrapper.clientHeight,
      wrapperScrollWidth: wrapper.scrollWidth,
      wrapperClientWidth: wrapper.clientWidth,
      wrapperScrollTop: wrapper.scrollTop,
      wrapperBottom: box.bottom,
      wrapperTop: box.top,
      windowHeight: window.innerHeight,
      lastLineTop: last.top,
      lastLineBottom: last.bottom,
      text: text.textContent,
      collapsed: wrapper.querySelector('.ocu-long-block-collapsed') !== null,
      toggle: wrapper.querySelector('.ocu-long-block-toggle')?.textContent.trim() ?? null,
    };
  }, ROW_SELECTOR);
}

test('DW-1976: a view whose text runs past its cell shows it whole beneath its row, reached to the end by pointer and by keyboard, in light and in dark', async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${VIEWS_ROUTE}/document/${encodeEntityId(LONG_VIEW)}?ns=USER`, VIEWPORTS.narrow, REDUCED_MOTION);
  try {
    await page.waitForSelector('.ocu-data-table-long .ocu-long-block-toggle', { timeout: config.navigationTimeoutMs });
    const cellText = await page.$eval(ROW_SELECTOR, (row) => row.querySelectorAll('[role="gridcell"]')[7].textContent.trim());
    assert.ok(cellText.includes(LONG_VIEW_MARK) && cellText.length > LONG_TEXT_LENGTH, `the view's text runs past its cell: ${cellText.length} characters`);
    assert.equal(await page.$eval('.ocu-data-table-long-label', (label) => label.textContent.trim()), STRINGS.explorerSearchTextLabel, 'the block is named by the Text column\'s header');

    for (const dark of [false, true]) {
      const where = dark ? 'dark' : 'light';
      await setDarkTheme(page, dark);
      const closed = await longBlockGeometry(page);
      assert.equal(closed.collapsed, true, `${where}: the block starts collapsed`);
      assert.equal(closed.toggle, STRINGS.longBlockShowMore, `${where}: and offers Show more`);
      assert.ok(closed.text.trim() === cellText, `${where}: its text is the cell's, whole, in the page while collapsed (${closed.text.length} against ${cellText.length} characters)`);
      assert.ok(closed.rowTextTop >= closed.viewTop - 1 && closed.rowTextBottom <= closed.viewBottom + 1, `${where}: the table keeps its row's text in view beside the block (${closed.rowTextTop}..${closed.rowTextBottom} in ${closed.viewTop}..${closed.viewBottom})`);

      // Mutation (Rule 19), each on a rebuilt and redeployed bundle: remove `long: true` from
      // `ExplorerSqlView`'s Text column and regenerate the mirror -> the wait for the block times out
      // before this loop starts. Delete the frame's floor beside `.ocu-data-table-long` -> the
      // row-text assertion goes red. Drop `overflow-wrap: anywhere` from `.ocu-data-table-long-text` -> the
      // sideways-scroll assertion goes red. Give `.ocu-long-block-region` a `max-height` with
      // `overflow: hidden` -> the not-clipped assertion goes red. Restore `max-height: 40vh` on
      // `.ocu-data-table-long` -> the half-column assertion goes red. Drop its
      // `max-height` and `overflow-y` -> the wheel's wait for the last line times out.
      // Light opens it with the keyboard, dark with the pointer.
      if (dark) await page.click('.ocu-data-table-long .ocu-long-block-toggle');
      else {
        await page.focus('.ocu-data-table-long .ocu-long-block-toggle');
        await page.keyboard.press('Enter');
      }
      await page.waitForFunction(() => document.querySelector('.ocu-data-table-long .ocu-long-block-collapsed') === null);
      const open = await longBlockGeometry(page);
      assert.equal(open.toggle, STRINGS.longBlockShowLess, `${where}: the control now offers Show less`);
      assert.ok(open.text.includes(LONG_VIEW_MARK) && open.text.trim() === cellText, `${where}: the block holds the mark and the whole text (${open.text.length} against ${cellText.length} characters)`);
      assert.ok(open.regionScrollHeight <= open.regionClientHeight + 1, `${where}: its region is not clipped (${open.regionScrollHeight} in ${open.regionClientHeight})`);
      assert.ok(open.wrapperScrollWidth <= open.wrapperClientWidth + 1, `${where}: the unbroken text wraps rather than scrolling sideways (${open.wrapperScrollWidth} in ${open.wrapperClientWidth})`);
      assert.ok(open.wrapperBottom <= open.windowHeight + 1, `${where}: the scrolling region ends inside the window (${open.wrapperBottom} of ${open.windowHeight})`);
      assert.ok(open.wrapperHeight <= open.hostHeight / 2 + 1, `${where}: the scrolling region takes at most half the table's column (${open.wrapperHeight} of ${open.hostHeight})`);
      assert.ok(open.wrapperScrollHeight > open.wrapperClientHeight, `${where}: the text is taller than the region that scrolls it, so reaching its end takes scrolling (${open.wrapperScrollHeight} in ${open.wrapperClientHeight})`);
      assert.ok(open.rowTextTop >= open.viewTop - 1 && open.rowTextBottom <= open.viewBottom + 1, `${where}: and with the block open (${open.rowTextTop}..${open.rowTextBottom} in ${open.viewTop}..${open.viewBottom})`);

      // Pointer: the wheel over the region scrolls it to the last line.
      await page.evaluate(() => { document.querySelector('.ocu-data-table-long').scrollTop = 0; });
      const box = await page.$eval('.ocu-data-table-long', (wrapper) => {
        const { left, top, width, height } = wrapper.getBoundingClientRect();
        return { x: left + width / 2, y: top + height / 2 };
      });
      await page.mouse.move(box.x, box.y);
      for (let step = 0; step < 40; step += 1) await page.mouse.wheel({ deltaY: 400 });
      await page.waitForFunction(() => {
        const wrapper = document.querySelector('.ocu-data-table-long');
        return wrapper.scrollTop + wrapper.clientHeight >= wrapper.scrollHeight - 1;
      });
      let end = await longBlockGeometry(page);
      assert.ok(end.lastLineTop >= end.wrapperTop - 1 && end.lastLineBottom <= end.wrapperBottom + 1, `${where}: the last line is on screen after the wheel (${end.lastLineTop}..${end.lastLineBottom} in ${end.wrapperTop}..${end.wrapperBottom})`);

      // Keyboard: from the top, with focus on the control and nothing scrolled into view, End reaches the same line.
      await page.evaluate(() => {
        const wrapper = document.querySelector('.ocu-data-table-long');
        wrapper.scrollTop = 0;
        wrapper.querySelector('.ocu-long-block-toggle').focus({ preventScroll: true });
      });
      const atTop = await longBlockGeometry(page);
      assert.ok(atTop.lastLineBottom > atTop.wrapperBottom + 1, `${where}: before End the last line is below the region (${atTop.lastLineBottom} past ${atTop.wrapperBottom})`);
      await page.keyboard.press('End');
      await page.waitForFunction(() => {
        const wrapper = document.querySelector('.ocu-data-table-long');
        return wrapper.scrollTop + wrapper.clientHeight >= wrapper.scrollHeight - 1;
      });
      end = await longBlockGeometry(page);
      assert.ok(end.lastLineTop >= end.wrapperTop - 1 && end.lastLineBottom <= end.wrapperBottom + 1, `${where}: the last line is on screen after the End key (${end.lastLineTop}..${end.lastLineBottom} in ${end.wrapperTop}..${end.wrapperBottom})`);

      await page.click('.ocu-data-table-long .ocu-long-block-toggle');
      await page.waitForFunction(() => document.querySelector('.ocu-data-table-long .ocu-long-block-collapsed') !== null);
    }
    await setDarkTheme(page, false);
  } finally {
    await context.close();
  }
});

/** Press Tab until an element matching `selector` holds focus: the number of presses it took, or -1 after `limit`. */
async function tabUntil(page, selector, limit) {
  for (let presses = 1; presses <= limit; presses += 1) {
    await page.keyboard.press('Tab');
    if (await page.evaluate((wanted) => document.activeElement?.matches(wanted) === true, selector)) return presses;
  }
  return -1;
}

test('DW-1976: the keyboard alone reads a view\'s whole text: Tab reaches Show more, Enter opens it, End brings the last line on screen', async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${VIEWS_ROUTE}/document/${encodeEntityId(LONG_VIEW)}?ns=USER`, VIEWPORTS.narrow, REDUCED_MOTION);
  const toggle = '.ocu-data-table-long .ocu-long-block-toggle';
  try {
    await page.waitForSelector(toggle, { timeout: config.navigationTimeoutMs });
    // The tab strip is the stop before the table, so every press after this focus is a person's own Tab.
    // Mutation (Rule 19), on a rebuilt and redeployed bundle: `tabindex="-1"` on `LongBlock`'s toggle
    // -> the Tab assertion goes red, naming the press limit.
    await page.focus('.ocu-detail-tab');
    const presses = await tabUntil(page, toggle, TAB_LIMIT);
    assert.ok(presses > 0, `Tab reaches Show more within ${TAB_LIMIT} presses of the tab strip`);
    assert.equal(await page.$eval(toggle, (button) => button.getAttribute('aria-expanded')), 'false', 'the block is collapsed when Tab reaches it');

    await page.keyboard.press('Enter');
    await page.waitForFunction(() => document.querySelector('.ocu-data-table-long .ocu-long-block-collapsed') === null);
    const open = await longBlockGeometry(page);
    assert.equal(open.toggle, STRINGS.longBlockShowLess, 'Enter opened the block');
    assert.ok(open.lastLineBottom > open.wrapperBottom + 1, `before End the last line is below the region (${open.lastLineBottom} past ${open.wrapperBottom}), so reaching it takes scrolling`);

    await page.keyboard.press('End');
    await page.waitForFunction(() => {
      const wrapper = document.querySelector('.ocu-data-table-long');
      return wrapper.scrollTop + wrapper.clientHeight >= wrapper.scrollHeight - 1;
    });
    const end = await longBlockGeometry(page);
    assert.ok(end.text.includes(LONG_VIEW_MARK), 'the block holds the view\'s text');
    assert.ok(end.lastLineTop >= end.wrapperTop - 1 && end.lastLineBottom <= end.wrapperBottom + 1, `the last line is on screen after End (${end.lastLineTop}..${end.lastLineBottom} in ${end.wrapperTop}..${end.wrapperBottom})`);
  } finally {
    await context.close();
  }
});

test('DW-1976: the table\'s one trigger shows its code whole beneath its row in a long block named by the Code header', async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${TABS_ROUTE}/triggers/${encodeEntityId(TABLE)}?ns=USER`, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await rowShowing(page, 'VisibleStamp');
    // Mutation (Rule 19), on a rebuilt and redeployed bundle: remove `long: true` from
    // `ExplorerSqlTriggers`' Code column and regenerate the mirror -> this wait times out.
    await page.waitForSelector('.ocu-data-table-long .ocu-data-table-long-text', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$$eval(ROW_SELECTOR, (rows) => rows.length), 1, 'the table lists the one trigger of the probe table');
    const blocks = await page.$$eval('.ocu-data-table-long-block', (nodes) =>
      nodes.map((node) => ({ label: node.querySelector('.ocu-data-table-long-label').textContent.trim(), text: node.querySelector('.ocu-data-table-long-text').textContent }))
    );
    assert.equal(blocks.length, 1, 'one long column gives one block');
    assert.equal(blocks[0].label, STRINGS.webAppPromptGroupCode, 'the block is named by the Code column\'s header');
    assert.ok(blocks[0].text.includes(CODE_MARK) && blocks[0].text.includes('Set {Code} = "probe"'), `the block holds the code from its first line to its last (${blocks[0].text.length} characters)`);
    // Mutation (Rule 19), on a rebuilt and redeployed bundle: drop `white-space: pre-wrap` from
    // `.ocu-data-table-long-text` -> this assertion goes red.
    assert.ok(blocks[0].text.includes('\n'), 'the trigger\'s code carries its own line breaks');
    assert.equal(await page.$eval('.ocu-data-table-long-text', (text) => getComputedStyle(text).whiteSpace), 'pre-wrap', 'the block keeps the code\'s line breaks');
    assert.ok(blocks[0].text.length > LONG_TEXT_LENGTH, `the code runs past a cell: ${blocks[0].text.length} characters`);
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
    assert.equal(await noteShown(page), STRINGS.explorerSqlStatementsNote, 'the procedure\'s SQL statements shows the statistics note');
    for (const tool of ['explorer.sqlprocedure', 'explorer.sqlprocedurestatements']) {
      assert.ok(reads.some((read) => read.startsWith(`${READ_PREFIX}${tool}/read?`) && read.includes(`procedure=${encodeURIComponent(QUERY)}`)), `${tool} reads the procedure through its own read: ${JSON.stringify(reads)}`);
    }
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): drop `ExplorerSqlSchemaProcedures`' `rowTarget`, regenerate the mirror, rebuild and
// redeploy -> the procedure's name is text, and the click on it fails.
test('Story 20.38 AC1, AC2, AC5: a schema\'s name opens Tables, Views and Procedures, a procedure\'s name opens its screen, and a kind the schema lacks says so', async () => {
  const first = await signedInAt(browser, config, `/ocupilot/${SCHEMAS_ROUTE}?ns=USER`, VIEWPORTS.wide, REDUCED_MOTION);
  const reads = recordReads(first.page);
  try {
    const { page } = first;
    // Mutation (Rule 19): drop the `documentScreenFor` arm from `nameLinkTarget`, so the name cell links to
    // the list itself -> the click selects the row and the path wait times out.
    await openSchema(page, SCHEMA);
    const id = encodeEntityId(SCHEMA);
    const labels = await page.$$eval('.ocu-detail-tab-label', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(labels, [STRINGS.explorerSqlColumnTables, STRINGS.explorerSqlColumnViews, STRINGS.explorerSqlColumnProcedures], 'the schema\'s three tabs');
    assert.deepEqual((await locatorSegments(page)).slice(-2), [STRINGS.explorerSqlSchemasLabel, SCHEMA], 'the locator reads SQL schemas, then the schema');
    await rowShowing(page, TABLE);
    assert.ok(
      reads.some((read) => read.startsWith(`${READ_PREFIX}explorer.sqlschematables/read?`) && read.includes(`schema=${SCHEMA}`) && !read.includes('system')),
      `the Tables tab reads the schema and sends no system choice: ${JSON.stringify(reads)}`
    );
    assert.equal(await currentEntry(page), STRINGS.explorerSqlSchemasLabel, 'the side bar marks SQL schemas');

    await openTab(page, `${SCHEMAS_ROUTE}/procedures`);
    await page.waitForFunction((path) => location.pathname === path, { timeout: config.navigationTimeoutMs }, `/ocupilot/${SCHEMAS_ROUTE}/procedures/${id}`);
    await rowShowing(page, PROCEDURE);
    assert.deepEqual((await locatorSegments(page)).slice(-2), [STRINGS.explorerSqlSchemasLabel, SCHEMA], 'and the same on the Procedures tab');
    assert.ok(reads.some((read) => read.startsWith(`${READ_PREFIX}explorer.sqlschemaprocedures/read?`) && read.includes(`schema=${SCHEMA}`)), `the Procedures tab reads the schema: ${JSON.stringify(reads)}`);

    await clickRowCentre(page, { text: PROCEDURE, link: true });
    await page.waitForFunction((path) => location.pathname === path, { timeout: config.navigationTimeoutMs }, `/ocupilot/${PROCEDURES_ROUTE}/document/${encodeEntityId(PROCEDURE)}`);
    await page.waitForSelector('nav.ocu-detail-tabs', { timeout: config.navigationTimeoutMs });
    const procedureTabs = await page.$$eval('.ocu-detail-tab-label', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(procedureTabs, [STRINGS.explorerSqlTabProcedureInfo, STRINGS.explorerSqlTabStatements], 'the procedure opens to Stored procedure info');
    await rowShowing(page, 'OcuProbe195.procEcho');
  } finally {
    await first.context.close();
  }

  const second = await signedInAt(browser, config, `/ocupilot/${SCHEMAS_ROUTE}?ns=USER`, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    const { page } = second;
    await openSchema(page, BARE_SCHEMA);
    await rowShowing(page, BARE_TABLE);
    await openTab(page, `${SCHEMAS_ROUTE}/views`);
    await page.waitForFunction((path) => location.pathname === path, { timeout: config.navigationTimeoutMs }, `/ocupilot/${SCHEMAS_ROUTE}/views/${encodeEntityId(BARE_SCHEMA)}`);
    await page.waitForSelector('.ocu-data-table-empty-title', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-data-table-empty-title', (node) => node.textContent.trim()), STRINGS.explorerSqlSchemaViewsEmpty, 'a schema with no views says so');
    assert.equal(STRINGS.explorerSqlSchemaViewsEmpty, 'This schema has no SQL views.', 'in the ruled sentence');
    // Mutation (Rule 19): label `ExplorerSqlSchemaViews` `explorerSqlColumnViews` instead of
    // `explorerSqlSchemasLabel`, regenerate, rebuild and redeploy -> the locator reads Views, and this goes red.
    assert.deepEqual((await locatorSegments(page)).slice(-2), [STRINGS.explorerSqlSchemasLabel, BARE_SCHEMA], 'and the same on the Views tab');
  } finally {
    await second.context.close();
  }
});

// Mutation (Rule 19): decode the id segment once instead of twice in `routeIdSegment` (`navigation.ts`), rebuild and
// redeploy -> the tab reads `schema=%25Dictionary`, lists no row, and the wait for `%Dictionary.ClassDefinition` times out.
test('Story 20.38 QA AC1, AC2, AD-13: a direct visit to a system schema opens its tabs and lists its objects with no System choice, and a procedure of %Library opens its screen', async () => {
  let reads = [];
  const record = async (page) => {
    reads = recordReads(page);
  };
  const first = await signedInAt(browser, config, `/ocupilot/${SCHEMAS_ROUTE}/document/${encodeEntityId(SYSTEM_SCHEMA)}?ns=USER`, VIEWPORTS.wide, REDUCED_MOTION, record);
  try {
    const { page } = first;
    await page.waitForSelector('nav.ocu-detail-tabs', { timeout: config.navigationTimeoutMs });
    const labels = await page.$$eval('.ocu-detail-tab-label', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(labels, [STRINGS.explorerSqlColumnTables, STRINGS.explorerSqlColumnViews, STRINGS.explorerSqlColumnProcedures], 'the system schema opens to the same three tabs');
    assert.deepEqual((await locatorSegments(page)).slice(-2), [STRINGS.explorerSqlSchemasLabel, SYSTEM_SCHEMA], 'under the locator SQL schemas, then the schema, spelled with its percent sign');
    await waitForRows(page, config.navigationTimeoutMs);
    const total = await viewCount(page);
    await filterToSubset(page, { text: SYSTEM_TABLE, expectRow: SYSTEM_TABLE, total, timeoutMs: config.navigationTimeoutMs });
    const read = readOf(reads, 'explorer.sqlschematables');
    assert.ok(read !== undefined, `the Tables tab read the schema: ${JSON.stringify(reads)}`);
    assert.equal(readParam(read, 'schema'), SYSTEM_SCHEMA, 'the read carries the decoded schema');
    assert.equal(new URL(read, 'http://localhost').searchParams.has('system'), false, 'and sends no system choice');
  } finally {
    await first.context.close();
  }

  const second = await signedInAt(browser, config, `/ocupilot/${SCHEMAS_ROUTE}/procedures/${encodeEntityId(PROCEDURE_SCHEMA)}?ns=USER`, VIEWPORTS.wide, REDUCED_MOTION, record);
  try {
    const { page } = second;
    await page.waitForSelector('nav.ocu-detail-tabs', { timeout: config.navigationTimeoutMs });
    await waitForRows(page, config.navigationTimeoutMs);
    assert.equal(readParam(readOf(reads, 'explorer.sqlschemaprocedures'), 'schema'), PROCEDURE_SCHEMA, 'and reads the decoded schema');
    const procedure = await page.$eval(`${ROW_SELECTOR} [role="gridcell"]`, (cell) => cell.textContent.trim());
    assert.ok(procedure.startsWith(`${PROCEDURE_SCHEMA}.`), `the first procedure is the schema's own: ${procedure}`);
    await clickRowCentre(page, { text: procedure, link: true });
    await page.waitForFunction((path) => location.pathname === path, { timeout: config.navigationTimeoutMs }, `/ocupilot/${PROCEDURES_ROUTE}/document/${encodeEntityId(procedure)}`);
    await page.waitForSelector('nav.ocu-detail-tabs', { timeout: config.navigationTimeoutMs });
    const tabs = await page.$$eval('.ocu-detail-tab-label', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(tabs, [STRINGS.explorerSqlTabProcedureInfo, STRINGS.explorerSqlTabStatements], `${procedure} opens to Stored procedure info`);
    await waitForRows(page, config.navigationTimeoutMs);
  } finally {
    await second.context.close();
  }
});

// Mutation (Rule 19): drop `(tSchemaTab && (tSchema = ""))` from `OcuPilot.Port.AtelierPort.CatalogRows`, reload `src` ->
// the tab answers every table in the namespace instead of a refusal, and the wait for the refusal times out.
test('Story 20.38 QA AC1: a schema tab opened with no schema shows the request refused, never an empty tab or every schema', async () => {
  let reads = [];
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${SCHEMAS_ROUTE}/document?ns=USER`, VIEWPORTS.wide, REDUCED_MOTION, async (opened) => {
    reads = recordReads(opened);
  });
  try {
    await page.waitForSelector('.ocu-data-table-refusal', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-data-table-refusal', (node) => node.getAttribute('role')), 'alert', 'the refusal is announced');
    assert.equal(await page.$eval('.ocu-data-table-refusal-message', (node) => node.textContent.trim()), STRINGS.connectivityRequestRefused, 'and says the request was refused');
    assert.equal(await page.$('.ocu-data-table-empty-title'), null, 'a refused read is not the empty sentence');
    assert.equal((await page.$$(ROW_SELECTOR)).length, 0, 'and lists no row');
    const read = readOf(reads, 'explorer.sqlschematables');
    assert.ok(read !== undefined && readParam(read, 'schema') === null, `the tab asked with no schema: ${JSON.stringify(reads)}`);
    const labels = await page.$$eval('.ocu-detail-tab-label', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(labels, [STRINGS.explorerSqlColumnTables, STRINGS.explorerSqlColumnViews, STRINGS.explorerSqlColumnProcedures], 'the tab strip stays');
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

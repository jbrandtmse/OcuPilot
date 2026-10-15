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
 * keyboard reaches to the end, in light and in dark.
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

/** Open the tab at `route` from the strip as a keyboard user does: focus it and press Enter. */
async function openTab(page, route) {
  await page.focus(`.ocu-detail-tab[data-route="${route}"]`);
  await page.keyboard.press('Enter');
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
 * the link container, each is 40px tall, no pagination control is displayed, and a strip wider than
 * its container sits on more than one row. Leaves the page at the wide viewport in light.
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
      const natural = tabs.reduce((total, tab) => total + tab.width, 0);
      assert.equal(rows > 1, natural > container.width + 1, `${where}: the strip wraps exactly when its tabs are wider than it (${rows} rows, ${Math.round(natural)}px in ${Math.round(container.width)}px)`);
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
    assert.equal(await noteShown(page), STRINGS.explorerSqlStatementsNote, 'the view\'s SQL statements shows the statistics note');
    assert.deepEqual(await structural(page, `${VIEWS_ROUTE}/statements/:id`), [], 'SQL statements adds no structural entry');
    for (const tool of ['explorer.sqlview', 'explorer.sqlviewfields', 'explorer.sqlviewstatements']) {
      assert.ok(reads.some((read) => read.startsWith(`${READ_PREFIX}${tool}/read?`) && read.includes(`view=${encodeURIComponent(VIEW)}`)), `${tool} reads the view through its own read: ${JSON.stringify(reads)}`);
    }
  } finally {
    await context.close();
  }
});

/** The long block's geometry: its region, the wrapper that scrolls it, and where the text's last line sits. */
function longBlockGeometry(page) {
  return page.evaluate(() => {
    const wrapper = document.querySelector('.ocu-data-table-long');
    const region = wrapper.querySelector('.ocu-long-block-region');
    const text = wrapper.querySelector('.ocu-data-table-long-text');
    const range = document.createRange();
    range.selectNodeContents(text);
    const lines = Array.from(range.getClientRects());
    const last = lines[lines.length - 1];
    const box = wrapper.getBoundingClientRect();
    const host = document.querySelector('app-data-table').getBoundingClientRect();
    return {
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
  });
}

test('DW-1976: a view whose text runs past its cell shows it whole beneath its row, reached to the end by pointer and by keyboard, in light and in dark', async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${VIEWS_ROUTE}/document/${encodeEntityId(LONG_VIEW)}?ns=USER`, VIEWPORTS.narrow, REDUCED_MOTION);
  try {
    await page.waitForSelector('.ocu-data-table-long .ocu-long-block-toggle', { timeout: config.navigationTimeoutMs });
    const cellText = await page.$eval(ROW_SELECTOR, (row) => row.querySelectorAll('[role="gridcell"]')[7].textContent.trim());
    assert.ok(cellText.includes(LONG_VIEW_MARK) && cellText.length > 1500, `the view's text runs past its cell: ${cellText.length} characters`);
    assert.equal(await page.$eval('.ocu-data-table-long-label', (label) => label.textContent.trim()), STRINGS.explorerSearchTextLabel, 'the block is named by the Text column\'s header');

    for (const dark of [false, true]) {
      const where = dark ? 'dark' : 'light';
      await setDarkTheme(page, dark);
      const closed = await longBlockGeometry(page);
      assert.equal(closed.collapsed, true, `${where}: the block starts collapsed`);
      assert.equal(closed.toggle, STRINGS.longBlockShowMore, `${where}: and offers Show more`);
      assert.ok(closed.text.trim() === cellText, `${where}: its text is the cell's, whole, in the page while collapsed (${closed.text.length} against ${cellText.length} characters)`);

      // Mutation (Rule 19), each on a rebuilt and redeployed bundle: remove `long: true` from
      // `ExplorerSqlView`'s Text column and regenerate the mirror -> the wait for the block times out
      // before this loop starts. Drop `overflow-wrap: anywhere` from `.ocu-data-table-long-text` -> the
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

      // Keyboard: from the top, focus on the control and the End key reach the same line.
      await page.evaluate(() => { document.querySelector('.ocu-data-table-long').scrollTop = 0; });
      await page.focus('.ocu-data-table-long .ocu-long-block-toggle');
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

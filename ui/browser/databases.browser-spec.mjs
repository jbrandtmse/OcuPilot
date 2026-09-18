/**
 * The Databases screen in a real browser, against the throwaway instance (Story 6.11): the General
 * view's headers and rows (AC1), the View control switching route (AD-5's `list (two views)`), the
 * Free-space view's skeleton cells before the async figures land and their filling together in one
 * tick (AC2, AC3), and the header column boundaries and row height sampled before and after,
 * identical to two decimal places (AC4).
 *
 * **It needs no fixture and creates nothing.** A mounted instance always holds at least its own
 * IRISSYS database, so neither view is ever empty. It creates no security principal -- AC7's pair
 * sets are proven over HTTP by `OcuPilot.Test.WireSecurityRead`.
 *
 * Run: `npm run test:browser` (after `npm run build`, `docker cp`-ing the bundle, and
 * `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { ROW_SELECTOR, viewCount, waitForRows } from './list-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const GENERAL_URL = '/ocupilot/os-management/databases?ns=HSCUSTOM';
const GENERAL_READ_PATH = '/api/ocupilot/screens/osmgmt.databases/read';
const FREE_SPACE_READ_PATH = '/api/ocupilot/screens/osmgmt.databasefreespace/read';

const VIEW_TRIGGER = '.ocu-command-bar-view-trigger';
const VIEW_ITEM = '.ocu-command-bar-view-item';
const CELL_SKELETON = '.ocu-data-table-cell-skeleton';

let browser = null;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec drives the throwaway, never the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
});

/** A fresh context signed in through the shell's own form at the General view's deep link. */
async function signedInAtGeneral() {
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  const reads = [];
  page.on('request', (request) => {
    if (new URL(request.url()).pathname.startsWith('/api/ocupilot/screens/')) reads.push(request.url());
  });
  await page.goto(`${config.origin}${GENERAL_URL}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', config.username);
  await page.type('#ocu-signin-password', config.password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, GENERAL_URL);
  return { context, page, reads };
}

/** Every rendered row, cell by cell, in row order, with which cells are drawn as a skeleton bar. */
function describeRows(page) {
  return page.evaluate(
    (rowSelector, skeletonSelector) => {
      const rows = Array.from(document.querySelectorAll(rowSelector));
      return rows.map((row) => ({
        cells: Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim()),
        pending: Array.from(row.querySelectorAll('[role="gridcell"]')).map(
          (cell) => cell.querySelector(skeletonSelector) !== null
        ),
      }));
    },
    ROW_SELECTOR,
    CELL_SKELETON
  );
}

/**
 * The header row's column boundaries, the first body row's own height, and that same row's own
 * per-cell boundaries, all rounded to two decimals.
 *
 * The header row and every body row are each their own `display: grid` container
 * (`data-table.ts`'s template binds `[style.grid-template-columns]="columnTemplate"` separately on
 * the header row and on each `*cdkVirtualFor` row), so a track-sizing function that reads from cell
 * content -- `auto` in place of `minmax(0, <n>fr)` -- computes independently for each of those
 * single-row grids. The header's own row never gets new content between "before" and "after" (its
 * labels are static), so comparing the header to itself across time cannot observe such a mutation:
 * the header column would sit at the same place before and after regardless of how the body's
 * column is sized, since the header is a different grid element that never re-renders. What the
 * mutation actually breaks is **alignment between the header and the data row directly under it**,
 * because the header grid sizes that column to fit "Available"/"Disk free"/"Mounted" while the body
 * grid sizes it to fit whatever that one row's own cell holds (nothing, under a skeleton bar's
 * percentage width; a short number or string once the figures land) -- two different single-row
 * grids, two different `auto` answers. Comparing `rowCells` to `headers` below is what catches that.
 */
function measureGeometry(page) {
  return page.evaluate(
    (rowSelector) => {
      const headers = Array.from(document.querySelectorAll('.ocu-data-table-header-cell')).map((cell) => {
        const rect = cell.getBoundingClientRect();
        return { left: Math.round(rect.left * 100) / 100, width: Math.round(rect.width * 100) / 100 };
      });
      const row = document.querySelector(rowSelector);
      const rowHeight = row === null ? null : Math.round(row.getBoundingClientRect().height * 100) / 100;
      const rowCells = row === null
        ? []
        : Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => {
            const rect = cell.getBoundingClientRect();
            return { left: Math.round(rect.left * 100) / 100, width: Math.round(rect.width * 100) / 100 };
          });
      return { headers, rowHeight, rowCells };
    },
    ROW_SELECTOR
  );
}

test('AC1: the General view reads once under its five declared headers, and every row carries five cells', async () => {
  const { context, page, reads } = await signedInAtGeneral();
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const headers = await page.$$eval('.ocu-data-table-header-label', (labels) => labels.map((label) => label.textContent.trim()));
    assert.deepEqual(headers, [
      STRINGS.lockColumnDirectory,
      STRINGS.databaseColumnSize,
      STRINGS.databaseColumnMaxSize,
      STRINGS.taskHistoryColumnStatus,
      STRINGS.webAppColumnResource,
    ]);

    const total = await viewCount(page);
    assert.ok(total >= 1, `the instance holds at least one database (its own IRISSYS): ${total}`);

    const rows = await describeRows(page);
    for (const row of rows) {
      assert.equal(row.cells.length, 5, `every row carries five cells: ${JSON.stringify(row)}`);
      assert.notEqual(row.cells[0], '', 'Directory is never blank');
    }
    assert.equal(reads.length, 1, `exactly one screen read was issued: ${JSON.stringify(reads)}`);
    assert.equal(new URL(reads[0]).pathname, GENERAL_READ_PATH);
  } finally {
    await context.close();
  }
});

test('the View control switches route to the Free-space view and back, carrying the namespace', async () => {
  const { context, page } = await signedInAtGeneral();
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await page.waitForSelector(VIEW_TRIGGER, { timeout: config.navigationTimeoutMs });
    // The trigger's own text node carries the down-triangle caret alongside the label (the same
    // two-span shape as the command bar's Sort trigger, `command-bar.ts`), so the label is read
    // from its own span rather than the whole button's `textContent`.
    assert.equal(
      await page.$eval(VIEW_TRIGGER + ' .ocu-command-bar-sort-label', (el) => el.textContent.trim()),
      STRINGS.viewMenuLabel
    );

    await page.click(VIEW_TRIGGER);
    await page.waitForSelector(VIEW_ITEM, { timeout: config.navigationTimeoutMs });
    const items = await page.$$eval(VIEW_ITEM, (buttons) => buttons.map((button) => button.textContent.trim()));
    assert.deepEqual(items, ['General', STRINGS.databaseFreeSpaceLabel]);

    await page.click(VIEW_ITEM + ':nth-of-type(2)');
    await page.waitForFunction(
      (path) => window.location.pathname === path,
      { timeout: config.navigationTimeoutMs },
      '/ocupilot/os-management/database-free-space'
    );
    assert.equal(new URL(page.url()).searchParams.get('ns'), 'HSCUSTOM', 'the namespace is carried across the navigation');
    await waitForRows(page, config.navigationTimeoutMs);

    await page.click(VIEW_TRIGGER);
    await page.waitForSelector(VIEW_ITEM, { timeout: config.navigationTimeoutMs });
    await page.click(VIEW_ITEM + ':nth-of-type(1)');
    await page.waitForFunction(
      (path) => window.location.pathname === path,
      { timeout: config.navigationTimeoutMs },
      '/ocupilot/os-management/databases'
    );
  } finally {
    await context.close();
  }
});

test('AC2, AC3, AC4: the Free-space view paints rows immediately with skeleton figure cells, fills them together, and never reflows', async () => {
  const { context, page, reads } = await signedInAtGeneral();
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await page.waitForSelector(VIEW_TRIGGER, { timeout: config.navigationTimeoutMs });
    await page.click(VIEW_TRIGGER);
    await page.waitForSelector(VIEW_ITEM, { timeout: config.navigationTimeoutMs });
    await page.click(VIEW_ITEM + ':nth-of-type(2)');
    await page.waitForFunction(
      (path) => window.location.pathname === path,
      { timeout: config.navigationTimeoutMs },
      '/ocupilot/os-management/database-free-space'
    );

    // AC2: rows are on screen -- Directory and Size filled -- with the three figure cells drawn as
    // skeletons, before the async read has resolved. The General view's own fast read already
    // landed a moment ago, and the Free-space read's own vendor round trip (measured at 0.852s for
    // fourteen databases against NFR-1's 2s) is what leaves this window open to observe.
    await waitForRows(page, config.navigationTimeoutMs);
    const staged = await describeRows(page);
    assert.ok(staged.length >= 1, 'the staged row is on screen');
    for (const row of staged) {
      assert.notEqual(row.cells[0], '', 'Directory is filled from the General view');
      assert.notEqual(row.cells[1], '', 'Size is filled from the General view');
      assert.deepEqual(row.pending.slice(2), [true, true, true], `Available, Disk free and Mounted are skeletons: ${JSON.stringify(row)}`);
    }
    const before = await measureGeometry(page);
    // AC4, load-bearing half: the header row and each body row are independent single-row grid
    // containers (`data-table.ts` binds `columnTemplate` on each separately), so a track-sizing
    // function that reads from content would size the header's column (fit to "Available" etc.)
    // differently from the body row's column (fit to a skeleton bar, here) even at a single point
    // in time -- a divergence that comparing the header to itself across time can never observe,
    // since the header's own content never changes. This is what actually falsifies the no-reflow
    // claim; see `measureGeometry`'s own comment.
    assert.deepEqual(
      before.rowCells.map((cell) => cell.left),
      before.headers.slice(0, before.rowCells.length).map((header) => header.left),
      `row cells align under their headers while the figure cells are skeletons: ${JSON.stringify(before)}`
    );
    assert.deepEqual(
      before.rowCells.map((cell) => cell.width),
      before.headers.slice(0, before.rowCells.length).map((header) => header.width),
      `row cell widths match their headers' while the figure cells are skeletons: ${JSON.stringify(before)}`
    );

    // AC3: once the read resolves, all three figures land together, in one tick, with no skeleton
    // left anywhere in the table.
    await page.waitForFunction(
      (selector) => document.querySelector(selector) === null,
      { timeout: config.navigationTimeoutMs },
      CELL_SKELETON
    );
    const filled = await describeRows(page);
    for (const row of filled) {
      assert.ok(row.pending.every((pending) => pending === false), `no skeleton remains: ${JSON.stringify(row)}`);
      assert.notEqual(row.cells[2], '', 'Available is filled');
      assert.notEqual(row.cells[3], '', 'Disk free is filled');
      assert.notEqual(row.cells[4], '', 'Mounted is filled');
    }

    // AC4: the header column boundaries and the row height are identical to two decimal places
    // before and after, because DataTable's grid tracks come from the declared column kinds, never
    // from the figures widening a cell.
    const after = await measureGeometry(page);
    assert.deepEqual(after.headers, before.headers, `header boundaries are unchanged: ${JSON.stringify({ before, after })}`);
    assert.equal(after.rowHeight, before.rowHeight, `row height is unchanged: ${JSON.stringify({ before, after })}`);
    // Same alignment check, now that the figures have landed: the body row's cells still line up
    // under the header, even though the row's own content just changed from a skeleton bar to a
    // real value.
    assert.deepEqual(
      after.rowCells.map((cell) => cell.left),
      after.headers.slice(0, after.rowCells.length).map((header) => header.left),
      `row cells align under their headers once the figures have landed: ${JSON.stringify(after)}`
    );
    assert.deepEqual(
      after.rowCells.map((cell) => cell.width),
      after.headers.slice(0, after.rowCells.length).map((header) => header.width),
      `row cell widths match their headers' once the figures have landed: ${JSON.stringify(after)}`
    );

    // No second query: the General view's own fast read and the Free-space screen's own declared
    // read, once each (AD-36) -- never a per-figure request.
    const freeSpaceReads = reads.filter((url) => new URL(url).pathname === FREE_SPACE_READ_PATH);
    assert.equal(freeSpaceReads.length, 1, `exactly one Free-space read was issued: ${JSON.stringify(reads)}`);
  } finally {
    await context.close();
  }
});

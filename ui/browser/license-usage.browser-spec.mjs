/**
 * Story 16.7's License usage in a real browser, against the throwaway instance (AC1, AC6).
 *
 * What it pins: OS management's side bar lists its twelve entries in order, the Integrity log
 * (Story 18.17) fifth, License usage eighth, the Dashboard ninth, External language servers
 * (Story 16.10) tenth, Local databases eleventh and Remote databases (Story 18.16) twelfth;
 * License usage's strip shows its four tabs; Summary lists the vendor's five
 * rows under its three headers; By process lists rows whose first cell is a process id; By user and
 * Distributed each list rows or show their own empty text; and all four tabs pass the structural and
 * contrast checks at 1280 light, 720 light and 1280 dark, with no entry beyond the baseline
 * (DW-1337).
 *
 * It reads only, but it signs in and resets the account's remembered state, so it runs on a
 * throwaway only.
 *
 * Run: `node --test --test-concurrency=1 browser/license-usage.browser-spec.mjs` (after
 * `npm run build`, the bundle copied into the throwaway, and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { ROW_SELECTOR, waitForRows } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const SUMMARY_ROUTE = 'os-management/license-usage';
const PROCESSES_ROUTE = 'os-management/license-usage/processes';
const USERS_ROUTE = 'os-management/license-usage/users';
const DISTRIBUTED_ROUTE = 'os-management/license-usage/distributed';
const at = (route) => `/ocupilot/${route}?ns=HSCUSTOM`;
const REDUCED_MOTION = [{ name: 'prefers-reduced-motion', value: 'reduce' }];

let browser = null;

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/** The DW-1337 walk of `route` at 1280 light, 720 light and 1280 dark, answering every entry the baseline does not hold. */
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

/** Every rendered row's cells, in row order. */
function rowCells(page) {
  return page.evaluate((rowSelector) => {
    return Array.from(document.querySelectorAll(rowSelector)).map((row) => Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim()));
  }, ROW_SELECTOR);
}

/** The table's header labels, in order. */
function headers(page) {
  return page.$$eval('.ocu-data-table-header-label', (labels) => labels.map((label) => label.textContent.trim()));
}

/**
 * Open the tab at `route` from the strip, and wait until its own read has landed: its table, whose
 * second header reads `secondHeader`, holds rows, or its own empty text `emptyText` shows.
 */
async function openTab(page, route, secondHeader, emptyText = null) {
  await page.click(`.ocu-detail-tab[data-route="${route}"]`);
  await page.waitForFunction(
    (wanted, header, empty, rowSelector) => {
      if (!window.location.pathname.endsWith(wanted)) return false;
      const headers = Array.from(document.querySelectorAll('.ocu-data-table-header-label')).map((label) => label.textContent.trim());
      if (headers[1] === header && document.querySelector(rowSelector) !== null) return true;
      return empty !== null && document.querySelector('.ocu-data-table-empty-title')?.textContent.trim() === empty;
    },
    { timeout: config.navigationTimeoutMs },
    route,
    secondHeader,
    emptyText,
    ROW_SELECTOR
  );
}

before(async () => {
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec signs in and resets the account's remembered state, so it runs only in a throwaway; ${config.container} is not one`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
});

// AC1. Mutation (Rule 19): read the whole LICENSEUSAGE answer rather than its member in
// `OcuPilot.Screen.Read` -> every tab's read fails, no row renders, and the row waits go red.
test('AC1: OS management lists twelve entries, License usage eighth; its strip shows four tabs; Summary lists the five vendor rows', async () => {
  const { context, page } = await signedInAt(browser, config, at(SUMMARY_ROUTE), VIEWPORTS.wide);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    // A rail click opens the area's side bar without navigating (`shell-state.ts`'s `activateArea`).
    await page.click(`.ocu-rail-item[aria-label="${STRINGS.navAreaOsManagement}"]`);
    await page.waitForFunction(
      (label) => Array.from(document.querySelectorAll('.ocu-side-bar-label')).some((node) => node.textContent.trim() === label),
      { timeout: config.navigationTimeoutMs },
      STRINGS.dashboardLabel
    );
    const labels = await page.$$eval('.ocu-side-bar-item .ocu-side-bar-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(
      labels,
      [
        STRINGS.processListLabel,
        STRINGS.lockListLabel,
        STRINGS.systemUsageLabel,
        STRINGS.databaseListLabel,
        STRINGS.databaseIntegrityLogLabel,
        STRINGS.deviceListLabel,
        STRINGS.namespaceListLabel,
        STRINGS.licenseUsageLabel,
        STRINGS.dashboardLabel,
        STRINGS.languageServersLabel,
        STRINGS.localDatabaseListLabel,
        STRINGS.remoteDatabaseListLabel,
      ],
      'the side bar lists the Integrity log fifth, License usage eighth, the Dashboard ninth, External language servers tenth, Local databases eleventh and Remote databases twelfth'
    );
    const tabs = await page.$$eval('.ocu-detail-tab .ocu-detail-tab-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(tabs, [STRINGS.openApiColumnSummary, STRINGS.licenseUsageByProcess, STRINGS.licenseUsageByUser, STRINGS.licenseUsageDistributed], 'the strip shows the four tabs');
    assert.deepEqual((await headers(page)).slice(0, 3), [STRINGS.licenseUsageUnitUse, STRINGS.licenseUsageLocal, STRINGS.licenseUsageDistributed], 'the Summary headers');
    const rows = await rowCells(page);
    assert.equal(rows.length, 5, `the vendor's five summary rows: ${JSON.stringify(rows)}`);
    assert.ok(rows.every((cells) => cells[0] !== ''), 'each carrying its label');
  } finally {
    await context.close();
  }
});

test('AC1: By process lists rows whose first cell is a process id, and By user and Distributed each list rows or their own empty text', async () => {
  const { context, page } = await signedInAt(browser, config, at(PROCESSES_ROUTE), VIEWPORTS.wide);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    assert.deepEqual((await headers(page)).slice(0, 4), [STRINGS.processColumnPid, STRINGS.licenseUsageLoginId, STRINGS.licenseUsageUserId, STRINGS.tableColumnType], 'the By process headers');
    const rows = await rowCells(page);
    assert.ok(rows.length >= 1, 'at least one process holds a license entry');
    assert.match(rows[0][0], /^[0-9,]+$/, `the first cell is a process id: ${JSON.stringify(rows[0])}`);

    for (const [route, emptyKey, secondHeader] of [
      [USERS_ROUTE, 'licenseUsageUsersEmpty', STRINGS.tableColumnType],
      [DISTRIBUTED_ROUTE, 'licenseUsageDistributedEmpty', STRINGS.licenseUsageLicenseUnits],
    ]) {
      await openTab(page, route, secondHeader, STRINGS[emptyKey]);
      const listed = await rowCells(page);
      if (listed.length === 0) {
        const empty = await page.$eval('.ocu-data-table-empty-title', (node) => node.textContent.trim());
        assert.equal(empty, STRINGS[emptyKey], `${route} shows its own empty text`);
      } else {
        assert.ok(listed.every((cells) => cells.length > 0), `${route} lists its rows`);
      }
    }
  } finally {
    await context.close();
  }
});

// AC6: the DW-1337 gate, with no new allowance.
test('AC6: all four tabs pass DW-1337 wide and narrow, light and dark, with no entry beyond the baseline', async () => {
  // Reduced motion, as the baseline's own walk runs, so no tab label is measured mid-transition.
  const { context, page } = await signedInAt(browser, config, at(SUMMARY_ROUTE), VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    assert.deepEqual(await structural(page, SUMMARY_ROUTE), [], 'Summary: no violation beyond the baseline');
    await openTab(page, PROCESSES_ROUTE, STRINGS.licenseUsageLoginId);
    assert.deepEqual(await structural(page, PROCESSES_ROUTE), [], 'By process: no violation beyond the baseline');
    await openTab(page, USERS_ROUTE, STRINGS.tableColumnType, STRINGS.licenseUsageUsersEmpty);
    assert.deepEqual(await structural(page, USERS_ROUTE), [], 'By user: no violation beyond the baseline');
    await openTab(page, DISTRIBUTED_ROUTE, STRINGS.licenseUsageLicenseUnits, STRINGS.licenseUsageDistributedEmpty);
    assert.deepEqual(await structural(page, DISTRIBUTED_ROUTE), [], 'Distributed: no violation beyond the baseline');
  } finally {
    await context.close();
  }
});

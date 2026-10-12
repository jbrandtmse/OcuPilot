/**
 * Story 18.36's Dashboard drill-downs in a real browser, against the throwaway instance (C4): from the
 * Dashboard, the Performance group's two links, the ECP group's link and the System usage group's link each
 * open their screen, and each screen answers -- Global and routine statistics and ECP statistics with their
 * groups of counters, System resource statistics with its rows under their six headers, Most active
 * processes with rows that each name a process, or its empty text -- while the side bar lists none of them;
 * and the four pass the structural and contrast checks at 1280 light, 720 light and 1280 dark, with no entry
 * beyond the baseline (DW-1337).
 *
 * It creates nothing on the instance and signs in and resets the account's remembered state, so it runs on a
 * throwaway only.
 *
 * Run: `node --test --test-concurrency=1 browser/dashboard-drill-downs.browser-spec.mjs` (after
 * `npm run build`, the bundle copied into the throwaway, and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { atDashboard as openDashboard } from './dashboard-spec.mjs';
import { ROW_SELECTOR, waitForRows } from './list-spec.mjs';
import { sideBarLabels } from './side-bar-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';

const config = browserConfig();
const STRINGS = loadStrings();

/** The four drill-downs: the route each opens and the label of the Dashboard link that opens it. */
const GLOBALS = { route: 'os-management/global-statistics', label: STRINGS.globalStatisticsLabel };
const RESOURCES = { route: 'os-management/resource-statistics', label: STRINGS.resourceStatisticsLabel };
const ECP = { route: 'os-management/ecp-statistics', label: STRINGS.ecpStatisticsLabel };
const PROCESSES = { route: 'os-management/active-processes', label: STRINGS.activeProcessesLabel };

let browser = null;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec never runs against the live container');
  await assertThrowaway(config);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
});

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/** Signed in at the Dashboard, with its first read landed. */
function atDashboard() {
  return openDashboard(browser, config);
}

/** Follow the Dashboard link to `target` and wait for its address; the link's own address, which a modified click opens, is the same. */
async function follow(page, target) {
  const selector = `a.ocu-details-link[data-drill-down="${target.route}"]`;
  const href = await page.$eval(selector, (link) => new URL(link.href).pathname);
  assert.equal(href, `/ocupilot/${target.route}`, `${target.label}'s link addresses its screen under the application's base`);
  await page.click(selector);
  await page.waitForFunction((path) => window.location.pathname === path, { timeout: config.navigationTimeoutMs }, `/ocupilot/${target.route}`);
}

/** The links the Dashboard draws under the group headed `heading`: their labels, in order. */
function linksUnder(page, heading) {
  return page.evaluate((wanted) => {
    const group = Array.from(document.querySelectorAll('.ocu-dashboard-group')).find(
      (item) => item.querySelector('.ocu-dashboard-heading')?.textContent.trim() === wanted
    );
    return Array.from(group?.querySelectorAll('nav.ocu-details-links a.ocu-details-link') ?? []).map((link) => link.textContent.trim());
  }, heading);
}

/** The statistics page once it has answered: not busy, with its groups drawn. */
async function statisticsAnswered(page) {
  await page.waitForFunction(
    () => document.querySelector('[aria-busy="true"]') === null && document.querySelectorAll('.ocu-details-group').length > 0,
    { timeout: config.navigationTimeoutMs }
  );
  return page.evaluate(() =>
    Array.from(document.querySelectorAll('.ocu-details-group')).map((group) => ({
      heading: group.querySelector('.ocu-details-heading')?.textContent.trim() ?? '',
      labels: Array.from(group.querySelectorAll('.ocu-details-field-label')).map((label) => label.textContent.trim()),
      values: Array.from(group.querySelectorAll('.ocu-details-field-value')).map((value) => value.textContent.trim()),
    }))
  );
}

/** The side bar as rendered: its entry labels, opening it first. */
async function sideBarEntries(page) {
  if ((await page.$('app-side-bar nav.ocu-side-bar')) === null) {
    await page.keyboard.down('Control');
    await page.keyboard.press('b');
    await page.keyboard.up('Control');
  }
  await page.waitForSelector('app-side-bar nav.ocu-side-bar', { timeout: config.navigationTimeoutMs });
  const entries = await page.$$eval('app-side-bar .ocu-side-bar-item .ocu-side-bar-label', (nodes) => nodes.map((node) => node.textContent.trim()));
  return entries;
}

/** The side bar lists OS management's declared entries and none of the four drill-downs. */
async function assertSideBarListsNone(page) {
  const entries = await sideBarEntries(page);
  assert.deepEqual(entries, sideBarLabels('os-management'), 'the OS management entries in their declared order');
  for (const target of [GLOBALS, RESOURCES, ECP, PROCESSES]) {
    assert.ok(!entries.includes(target.label), `the side bar does not list ${target.label}`);
  }
}

// C4. Mutation (Rule 19): drop the Performance group's `drillDowns` from `dashboard.store.ts`, rebuild and
// redeploy -> the links assertion goes red; declare `DashboardGlobals` page-less in `DESCRIPTOR_PAGES` -> the
// groups wait goes red.
test('C4: the Performance group links Global and routine statistics, whose page answers with a Globals group of twelve and a Routines group of six', async () => {
  const { context, page } = await atDashboard();
  try {
    assert.deepEqual(await linksUnder(page, STRINGS.performanceHeading), [GLOBALS.label, RESOURCES.label]);
    await follow(page, GLOBALS);
    const groups = await statisticsAnswered(page);
    assert.deepEqual(groups.map((group) => [group.heading, group.labels.length]), [
      [STRINGS.processColumnGlobals, 12],
      [STRINGS.explorerRoutineListLabel, 6],
    ]);
    for (const group of groups) {
      assert.equal(group.values.length, group.labels.length, `${group.heading} shows a value beside every label`);
      assert.ok(group.values.every((value) => /^\d+$/.test(value)), `${group.heading} reads whole numbers: ${JSON.stringify(group.values)}`);
    }
    assert.equal(groups[0].labels[0], STRINGS.statsGlobalReferencesLocal, 'in declared order');
    await assertSideBarListsNone(page);
  } finally {
    await context.close();
  }
});

// C4. Mutation (Rule 19): list ECP statistics' fields as one group in `statistics.store.ts`, rebuild and
// redeploy -> the two headings and counts go red.
test('C4: the ECP group links ECP statistics, whose page answers under Application server and Data server', async () => {
  const { context, page } = await atDashboard();
  try {
    assert.deepEqual(await linksUnder(page, STRINGS.dashboardGroupEcp), [ECP.label]);
    await follow(page, ECP);
    const groups = await statisticsAnswered(page);
    assert.deepEqual(groups.map((group) => [group.heading, group.labels.length]), [
      [STRINGS.statsGroupAppServer, 16],
      [STRINGS.remoteDatabaseServer, 17],
    ]);
    for (const group of groups) {
      assert.equal(group.values.length, group.labels.length, `${group.heading} shows a value beside every label`);
      assert.ok(group.values.every((value) => /^\d+$/.test(value)), `${group.heading} reads whole numbers: ${JSON.stringify(group.values)}`);
    }
    await assertSideBarListsNone(page);
  } finally {
    await context.close();
  }
});

// C4. Mutation (Rule 19): drop `DashboardResources` from the Performance group's drill-downs -> the link
// wait goes red; declare its table columns in another order -> the header assertion goes red.
test('C4: the Performance group links System resource statistics, whose list shows its rows under the six headers, most seized first', async () => {
  const { context, page } = await atDashboard();
  try {
    await follow(page, RESOURCES);
    await waitForRows(page, config.navigationTimeoutMs);
    const headers = await page.$$eval('.ocu-data-table-header-label', (labels) => labels.map((label) => label.textContent.trim()));
    assert.deepEqual(headers, [
      STRINGS.tableColumnName,
      STRINGS.resourceColumnSeizes,
      STRINGS.resourceColumnNseizes,
      STRINGS.resourceColumnAseizes,
      STRINGS.resourceColumnBseizes,
      STRINGS.resourceColumnBusySets,
    ]);
    const rows = await page.$$eval(ROW_SELECTOR, (items) => items.map((row) => Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim())));
    assert.ok(rows.length >= 2, `the instance lists system resources: ${rows.length}`);
    assert.ok(rows.every((cells) => cells[0] !== '' && cells[0] !== STRINGS.tableEmptyValue), 'each row names its resource');
    const seizes = rows.map((cells) => Number(cells[1].replace(/,/g, '')));
    assert.deepEqual(seizes, [...seizes].sort((a, b) => b - a), `most seized first: ${seizes.join(', ')}`);
    await assertSideBarListsNone(page);
  } finally {
    await context.close();
  }
});

// C4. Mutation (Rule 19): keep the empty rows in `OcuPilot.Port.AdminPort.ComposedAnswer`, redeploy the
// code -> a row with no process appears and the leg goes red.
test('C4: the System usage group links Most active processes, whose rows each name a process, or which says none reports commands', async () => {
  const { context, page } = await atDashboard();
  try {
    assert.deepEqual(await linksUnder(page, STRINGS.systemUsageLabel), [PROCESSES.label]);
    await follow(page, PROCESSES);
    await page.waitForFunction(
      (rowSelector) => document.querySelector(rowSelector) !== null || document.querySelector('.ocu-data-table-empty-title') !== null,
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR
    );
    const shown = await page.evaluate((rowSelector) => ({
      rows: Array.from(document.querySelectorAll(rowSelector)).map((row) => Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim())),
      empty: document.querySelector('.ocu-data-table-empty-title')?.textContent.trim() ?? null,
    }), ROW_SELECTOR);
    if (shown.rows.length === 0) {
      assert.equal(shown.empty, STRINGS.activeProcessesEmpty, 'with no row, the screen says no process reports commands');
    } else {
      assert.ok(shown.rows.length <= 10, `at most ten rows: ${shown.rows.length}`);
      assert.ok(shown.rows.every((cells) => cells[0] !== '' && cells[0] !== STRINGS.tableEmptyValue), `each row names a process: ${JSON.stringify(shown.rows)}`);
    }
    if (shown.rows.length > 0) {
      const headers = await page.$$eval('.ocu-data-table-header-label', (labels) => labels.map((label) => label.textContent.trim()));
      assert.deepEqual(headers, [STRINGS.processColumnPid, STRINGS.processColumnCommands]);
    }
    await assertSideBarListsNone(page);
  } finally {
    await context.close();
  }
});

// The DW-1337 gate, with no new allowance, over the four screens.
test('the four drill-downs pass DW-1337 wide and narrow, light and dark, with no entry beyond the baseline', async () => {
  const minimums = componentMinimums();
  for (const target of [GLOBALS, ECP, RESOURCES, PROCESSES]) {
    const { context, page } = await signedInAt(browser, config, `/ocupilot/${target.route}?ns=HSCUSTOM`, VIEWPORTS.wide);
    try {
      await page.waitForFunction(
        () => document.querySelector('[aria-busy="true"]') === null && document.querySelector('.ocu-details-group, [role="grid"] .ocu-data-table-body [role="row"], .ocu-data-table-empty-title') !== null,
        { timeout: config.navigationTimeoutMs }
      );
      const found = [];
      const passes = [
        { viewport: VIEWPORTS.wide, theme: 'light', checks: INVARIANTS },
        { viewport: VIEWPORTS.narrow, theme: 'light', checks: ['name', 'min-width', 'overflow'] },
        { viewport: VIEWPORTS.wide, theme: 'dark', checks: ['contrast'] },
      ];
      const surfaces = {};
      for (const { viewport, theme, checks } of passes) {
        await page.setViewport(viewport);
        await page.evaluate((dark) => document.documentElement.classList.toggle('ocu-theme-dark', dark), theme === 'dark');
        await frames(page);
        surfaces[theme] = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
        const { entries } = await detectScreen(page, { route: target.route, checks, viewport: viewport.width, theme, minimums });
        found.push(...entries);
      }
      assert.notEqual(surfaces.dark, surfaces.light, `${target.route}: the dark pass measured the dark theme, not the light one`);
      const fresh = compare(collapse(found), readBaseline()?.entries ?? []).fresh.map((entry) => `${entry.key}: ${entry.measured}`);
      assert.deepEqual(fresh, [], `${target.route}: no violation beyond the baseline`);
    } finally {
      await context.close();
    }
  }
});

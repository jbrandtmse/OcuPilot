/**
 * Story 18.37's Interoperability usage in a real browser, against the throwaway instance (C4): OS
 * management's side bar lists the screen at position 22 and its entry opens it; its strip shows three tabs,
 * Interfaces, Message volume and Database impact; each tab, once it has answered, shows the note and either
 * as many rows as its read answers or its own empty state; an Interfaces totals row, whose namespace and
 * protocol the instance leaves empty, reads "All" in both cells; and the three tabs pass the structural and
 * contrast checks at 1280 light, 720 light and 1280 dark, with no entry beyond the baseline (DW-1337).
 *
 * The rows each tab is compared with come from the same read route (`GET /screens/<tool>/read`) at the
 * moment of its leg, so the legs hold no row this file names. It creates nothing on the instance and signs in
 * and resets the account's remembered state, so it runs on a throwaway only.
 *
 * Run: `node --test --test-concurrency=1 browser/interop-usage.browser-spec.mjs` (after
 * `npm run build`, the bundle copied into the throwaway, and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { ROW_SELECTOR, viewCount, waitForRows } from './list-spec.mjs';
import { authHeader, signedInAt } from './panel-spec.mjs';
import { sideBarLabels } from './side-bar-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const START_URL = '/ocupilot/os-management/locks?ns=HSCUSTOM';
const REDUCED_MOTION = [{ name: 'prefers-reduced-motion', value: 'reduce' }];

/** The three tabs, in strip order: the route, the read tool, the tab's label and its empty state. */
const INTERFACES = {
  route: 'os-management/interoperability-usage',
  tool: 'osmgmt.interopusage',
  label: STRINGS.interopUsageInterfacesTab,
  empty: STRINGS.interopUsageInterfacesEmpty,
  headers: [STRINGS.tableColumnType, STRINGS.headerNamespaceLabel, STRINGS.interopUsageColumnProtocol, STRINGS.interopColumnActive, STRINGS.interopColumnCount],
};
const VOLUME = {
  route: 'os-management/interoperability-usage/volume',
  tool: 'osmgmt.interopvolume',
  label: STRINGS.interopUsageVolumeLabel,
  empty: STRINGS.interopUsageVolumeEmpty,
  headers: [STRINGS.headerNamespaceLabel, STRINGS.tableColumnType, STRINGS.interopItemTabMessages],
};
const IMPACT = {
  route: 'os-management/interoperability-usage/impact',
  tool: 'osmgmt.interopimpact',
  label: STRINGS.interopUsageImpactLabel,
  empty: STRINGS.interopUsageImpactEmpty,
  headers: [STRINGS.systemInfoDatabase, STRINGS.interopUsageColumnDataCreated],
};
const TABS = [INTERFACES, VOLUME, IMPACT];
const at = (route) => `/ocupilot/${route}?ns=HSCUSTOM`;

let browser = null;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec never runs against the live container');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec signs in and resets the account's remembered state, so it runs only in a throwaway; ${config.container} is not one`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
});

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

/** The rows a tab's own read answers now, through the route the page reads, and whether it was cut. */
async function routeRead(tab) {
  const answer = await fetch(`${config.origin}/api/ocupilot/screens/${tab.tool}/read?maxRows=1000&ns=HSCUSTOM`, {
    headers: { Authorization: authHeader(config) },
  });
  assert.equal(answer.status, 200, `${tab.tool}'s read route answers (HTTP ${answer.status})`);
  const body = await answer.json();
  assert.ok(Array.isArray(body.rows), `${tab.tool} answers rows`);
  return { rows: body.rows, truncated: body.truncated === true };
}

/**
 * Wait until the tab at `route` has answered: the address is the tab's, nothing is marked busy, and
 * the table holds rows or shows its empty state.
 */
async function answered(page, route) {
  await page.waitForFunction(
    (wanted, rowSelector) =>
      window.location.pathname === `/ocupilot/${wanted}` &&
      document.querySelector('[aria-busy="true"]') === null &&
      (document.querySelector(rowSelector) !== null || document.querySelector('.ocu-data-table-empty-title') !== null),
    { timeout: config.navigationTimeoutMs },
    route,
    ROW_SELECTOR
  );
}

/** Open the tab at `route` from the strip and wait until it has answered. */
async function openTab(page, tab) {
  await page.click(`.ocu-detail-tab[data-route="${tab.route}"]`);
  await answered(page, tab.route);
}

/** Every rendered row's cells, in row order. */
function rowCells(page) {
  return page.evaluate((rowSelector) => {
    return Array.from(document.querySelectorAll(rowSelector)).map((row) => Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim()));
  }, ROW_SELECTOR);
}

/** The side bar as rendered: its area and its entry labels, opening it first. */
async function sideBarOf(page) {
  if ((await page.$('app-side-bar nav.ocu-side-bar')) === null) {
    await page.keyboard.down('Control');
    await page.keyboard.press('b');
    await page.keyboard.up('Control');
  }
  await page.waitForSelector('app-side-bar nav.ocu-side-bar', { timeout: config.navigationTimeoutMs });
  return page.evaluate(() => {
    const nav = document.querySelector('app-side-bar nav.ocu-side-bar');
    return {
      area: nav.querySelector('.ocu-side-bar-eyebrow').textContent.trim(),
      entries: Array.from(nav.querySelectorAll('.ocu-side-bar-item .ocu-side-bar-label')).map((label) => label.textContent.trim()),
    };
  });
}

/** Signed in at the Interfaces tab, answered. */
async function atInterfaces(mediaFeatures = null) {
  const { context, page } = await signedInAt(browser, config, at(INTERFACES.route), VIEWPORTS.wide, mediaFeatures);
  await answered(page, INTERFACES.route);
  return { context, page };
}

// C4. Mutation (Rule 19): unlist InteropUsageTab (`sideBarPosition` 0), regenerate the mirror, rebuild and
// redeploy -> the side-bar assertion goes red.
test('C4: OS management lists Interoperability usage at position 22, its entry opens it, and its strip shows three tabs', async () => {
  const { context, page } = await signedInAt(browser, config, START_URL, VIEWPORTS.wide);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const bar = await sideBarOf(page);
    assert.equal(bar.area, STRINGS.navAreaOsManagement);
    assert.deepEqual(bar.entries, sideBarLabels('os-management'), 'the OS management entries in their declared order');
    assert.equal(bar.entries[21], STRINGS.interopUsageLabel, 'Interoperability usage is the twenty-second');

    const handles = await page.$$('app-side-bar .ocu-side-bar-item');
    let target = null;
    for (const handle of handles) {
      const label = await handle.$eval('.ocu-side-bar-label', (node) => node.textContent.trim());
      if (label === STRINGS.interopUsageLabel) target = handle;
    }
    assert.ok(target !== null, 'the side bar offers the Interoperability usage entry');
    await target.click();
    await answered(page, INTERFACES.route);

    const tabs = await page.$$eval('.ocu-detail-tab .ocu-detail-tab-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(tabs, TABS.map((tab) => tab.label), 'the strip shows the three tabs');
    assert.equal(await page.$('.ocu-command-bar-refresh'), null, 'and offers no refresh');
  } finally {
    await context.close();
  }
});

// C4. Mutation (Rule 19): change the `read.note` key of InteropUsageVolumeTab, regenerate the mirror, rebuild
// and redeploy -> the note leg goes red. A tab's declared endpoint is pinned by InteropUsageDescriptor, not here.
test("C4: each tab, once answered, shows the note and its read's rows under its headers, or its empty state", async () => {
  const { context, page } = await atInterfaces();
  try {
    for (const tab of TABS) {
      if (tab !== INTERFACES) await openTab(page, tab);
      const { rows, truncated } = await routeRead(tab);
      const text = await page.evaluate(() => document.body.textContent);
      assert.ok(text.includes(STRINGS.interopUsageNote), `${tab.label}: the note says the counts have no date range`);
      if (rows.length === 0) {
        const empty = await page.$eval('.ocu-data-table-empty-title', (node) => node.textContent.trim());
        assert.equal(empty, tab.empty, `${tab.label}: no row is recorded, so its own empty state shows`);
        continue;
      }
      const headers = await page.$$eval('.ocu-data-table-header-label', (labels) => labels.map((label) => label.textContent.trim()));
      assert.deepEqual(headers, tab.headers, `${tab.label}: the declared headers`);
      const shown = await viewCount(page);
      if (truncated) assert.ok(shown > 0, `${tab.label}: rows show`);
      else assert.equal(shown, rows.length, `${tab.label}: as many rows as its read answers`);
    }
  } finally {
    await context.close();
  }
});

// C4. Mutation (Rule 19): drop `emptyKey` from InteropUsageTab's Namespace and Protocol columns, regenerate the
// mirror, rebuild and redeploy -> the totals row's cells read empty and the leg goes red.
test('C4: an Interfaces totals row, whose namespace and protocol are empty, reads All in both cells', async () => {
  const { context, page } = await atInterfaces();
  try {
    const { rows, truncated } = await routeRead(INTERFACES);
    const totals = rows.filter((row) => row.Namespace === '' && row.Protocol === '');
    assert.ok(totals.length > 0, 'the instance answers its totals rows');
    const shown = await rowCells(page);
    const reading = shown.filter((cells) => cells[1] === STRINGS.interopUsageAll && cells[2] === STRINGS.interopUsageAll);
    if (!truncated) assert.equal(reading.length, totals.length, `every totals row reads All in its namespace and protocol cells: ${JSON.stringify(shown.slice(0, 8))}`);
    else assert.ok(reading.length > 0, 'a totals row reads All in its namespace and protocol cells');
    assert.ok(
      shown.every((cells) => cells[1] !== '' && cells[2] !== ''),
      'and no namespace or protocol cell reads empty'
    );
  } finally {
    await context.close();
  }
});

// The DW-1337 gate, with no new allowance.
test('the three tabs pass DW-1337 wide and narrow, light and dark, with no entry beyond the baseline', async () => {
  // Reduced motion, as the baseline's own walk runs, so no tab label is measured mid-transition.
  const { context, page } = await atInterfaces(REDUCED_MOTION);
  try {
    for (const tab of TABS) {
      if (tab !== INTERFACES) await openTab(page, tab);
      assert.deepEqual(await structural(page, tab.route), [], `${tab.label}: no violation beyond the baseline`);
    }
  } finally {
    await context.close();
  }
});

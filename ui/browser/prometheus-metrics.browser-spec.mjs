/**
 * Story 18.11's Prometheus metrics in a real browser, against the throwaway instance (C4): OS
 * management's side bar lists the screen at position 21 and its entry opens the table; the table shows
 * the read's rows under its four headers and the note that says why it never refreshes; a metric's
 * filter leaves only that metric's rows; a labeled row shows its labels; and the screen passes the
 * structural and contrast checks at 1280 light, 720 light and 1280 dark, with no entry beyond the
 * baseline (DW-1337).
 *
 * The rows the page is compared with come from the same read route (`GET /screens/osmgmt.metrics/read`)
 * at the moment of each leg, so the legs pick their metric from what the instance answers now rather
 * than from a name this file holds. It creates nothing on the instance and signs in and resets the
 * account's remembered state, so it runs on a throwaway only.
 *
 * Run: `node --test --test-concurrency=1 browser/prometheus-metrics.browser-spec.mjs` (after
 * `npm run build`, the bundle copied into the throwaway, and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { ROW_SELECTOR, filterToSubset, viewCount, waitForRows } from './list-spec.mjs';
import { authHeader, signedInAt } from './panel-spec.mjs';
import { sideBarLabels } from './side-bar-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const ROUTE = 'os-management/metrics';
const PAGE_URL = `/ocupilot/${ROUTE}?ns=HSCUSTOM`;
const START_URL = '/ocupilot/os-management/locks?ns=HSCUSTOM';
const READ_PATH = '/api/ocupilot/screens/osmgmt.metrics/read';

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

/** The rows the screen's own read answers now, through the route the page reads. */
async function routeRows() {
  const answer = await fetch(`${config.origin}${READ_PATH}?maxRows=1000&ns=HSCUSTOM`, {
    headers: { Authorization: authHeader(config) },
  });
  assert.equal(answer.status, 200, `the read route answers (HTTP ${answer.status})`);
  const body = await answer.json();
  assert.ok(Array.isArray(body.rows) && body.rows.length > 0, 'the instance answers metrics');
  return body.rows;
}

/** Every rendered row's cells, in row order. */
function describeRows(page) {
  return page.evaluate((rowSelector) => {
    const rows = Array.from(document.querySelectorAll(rowSelector));
    return rows.map((row) => Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim()));
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

/** Signed in at Prometheus metrics with its rows rendered. */
async function atMetrics() {
  const { context, page } = await signedInAt(browser, config, PAGE_URL, VIEWPORTS.wide);
  await waitForRows(page, config.navigationTimeoutMs);
  return { context, page };
}

// C4. Mutation (Rule 19): give MetricsList `sideBarPosition` 0 and regenerate the mirror, rebuild and
// redeploy -> the side-bar assertion goes red; set `refreshes` true -> the chip leg goes red.
test('C4: OS management lists Prometheus metrics at position 21, its entry opens the table under the note, and it offers no refresh', async () => {
  const { context, page } = await signedInAt(browser, config, START_URL, VIEWPORTS.wide);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const bar = await sideBarOf(page);
    assert.equal(bar.area, STRINGS.navAreaOsManagement);
    assert.deepEqual(bar.entries, sideBarLabels('os-management'), 'the OS management entries in their declared order');
    assert.equal(bar.entries[20], STRINGS.metricsLabel, 'Prometheus metrics is the twenty-first');

    const handles = await page.$$('app-side-bar .ocu-side-bar-item');
    let target = null;
    for (const handle of handles) {
      const label = await handle.$eval('.ocu-side-bar-label', (node) => node.textContent.trim());
      if (label === STRINGS.metricsLabel) target = handle;
    }
    assert.ok(target !== null, 'the side bar offers the Prometheus metrics entry');
    await target.click();
    await page.waitForFunction(() => window.location.pathname === '/ocupilot/os-management/metrics', { timeout: config.navigationTimeoutMs });
    await waitForRows(page, config.navigationTimeoutMs);

    const headers = await page.$$eval('.ocu-data-table-header-label', (labels) => labels.map((label) => label.textContent.trim()));
    assert.deepEqual(headers, [STRINGS.metricsColumnMetric, STRINGS.metricsColumnLabels, STRINGS.errorLogColumnValue, STRINGS.tableColumnDescription]);
    const text = await page.evaluate(() => document.body.textContent);
    assert.ok(text.includes(STRINGS.metricsNote), 'the note says each read shortens an external scraper\'s intervals');
    assert.equal(await page.$('.ocu-command-bar-refresh'), null, 'no auto-refresh chip: each read rewrites the sensor baseline');
  } finally {
    await context.close();
  }
});

// C4. Mutation (Rule 19): drop `Metric` from MetricsList's `read.filter`, regenerate the mirror,
// rebuild and redeploy -> filtering on the metric's name narrows nothing and the leg goes red.
test("C4: filtering on the first unlabeled metric's name leaves only that metric's rows", async () => {
  const { context, page } = await atMetrics();
  try {
    const rows = await routeRows();
    const haystack = (row) => `${row.Metric}\n${row.Labels}\n${row.Help}`.toLowerCase();
    const needle = rows
      .filter((row) => row.Labels === '')
      .map((row) => row.Metric)
      .find((metric) => rows.every((row) => row.Metric === metric || !haystack(row).includes(metric.toLowerCase())));
    assert.ok(needle !== undefined, 'the instance answers an unlabeled metric no other row mentions');
    const expected = rows.filter((row) => row.Metric === needle).length;
    const total = await viewCount(page);
    assert.ok(total > expected, `the unfiltered view (${total}) holds more rows than the metric's (${expected})`);

    const kept = await filterToSubset(page, { text: needle, expectRow: needle, total, timeoutMs: config.navigationTimeoutMs });
    assert.equal(kept, expected, `only ${needle}'s rows are left`);
    const shown = await describeRows(page);
    assert.ok(shown.length > 0 && shown.every((cells) => cells[0] === needle), `every shown row is ${needle}: ${JSON.stringify(shown)}`);
    assert.equal(shown[0][1], STRINGS.tableEmptyValue, 'an unlabeled row reads (none) under Labels');
  } finally {
    await context.close();
  }
});

// C4. Mutation (Rule 19): blank `Labels` in `OcuPilot.Port.MonitorPort.Samples` -> the labeled row's
// Labels cell reads (none) and the leg goes red.
test('C4: a labeled row shows its labels as the instance answers them', async () => {
  const { context, page } = await atMetrics();
  try {
    const rows = await routeRows();
    const labeled = rows.filter((row) => row.Labels !== '');
    assert.ok(labeled.length > 0, 'the instance answers labeled metrics');
    const frequency = (row) => labeled.filter((other) => other.Labels === row.Labels).length;
    const pick = labeled.reduce((best, row) => (frequency(row) < frequency(best) ? row : best), labeled[0]);
    const total = await viewCount(page);
    await filterToSubset(page, { text: pick.Labels, expectRow: pick.Metric, total, timeoutMs: config.navigationTimeoutMs });
    const shown = await describeRows(page);
    const row = shown.find((cells) => cells[0] === pick.Metric && cells[1] === pick.Labels);
    assert.ok(row !== undefined, `${pick.Metric} shows ${pick.Labels}: ${JSON.stringify(shown)}`);
  } finally {
    await context.close();
  }
});

// The DW-1337 gate, with no new allowance.
test('Prometheus metrics passes DW-1337 wide and narrow, light and dark, with no entry beyond the baseline', async () => {
  const { context, page } = await atMetrics();
  try {
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
      const { entries } = await detectScreen(page, { route: ROUTE, checks, viewport: viewport.width, theme, minimums });
      found.push(...entries);
    }
    assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
    const fresh = compare(collapse(found), readBaseline()?.entries ?? []).fresh.map((entry) => `${entry.key}: ${entry.measured}`);
    assert.deepEqual(fresh, [], 'no violation beyond the baseline');
  } finally {
    await context.close();
  }
});

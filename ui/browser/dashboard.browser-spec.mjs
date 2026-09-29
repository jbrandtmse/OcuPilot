/**
 * Story 16.7's Dashboard in a real browser, against the throwaway instance (AC2, AC5, AC6).
 *
 * What it pins: the seven group headings in the classic page's order; a CPU meter reading a
 * percentage with its `%` unit and a state word; Database space reading the vendor's "Normal" in
 * the success color; a value meter carrying no word and no track; the Task manager group drawing
 * Upcoming tasks' rows or that screen's empty text; the refresh chip offering the declared rates
 * and starting off; and the screen passing the structural and contrast checks at 1280 light, 720
 * light and 1280 dark, with no entry beyond the baseline (DW-1337).
 *
 * It reads only, but it signs in and resets the account's remembered state, so it runs on a
 * throwaway only.
 *
 * Run: `node --test --test-concurrency=1 browser/dashboard.browser-spec.mjs` (after
 * `npm run build`, the bundle copied into the throwaway, and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const ROUTE = 'os-management/dashboard';
const PAGE_URL = `/ocupilot/${ROUTE}?ns=HSCUSTOM`;

let browser = null;

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/** The DW-1337 walk of the Dashboard at 1280 light, 720 light and 1280 dark, answering every entry the baseline does not hold. */
async function structural(page) {
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
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await frames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  return compare(collapse(found), readBaseline()?.entries ?? []).fresh.map((entry) => `${entry.key}: ${entry.measured}`);
}

/** Reduced motion, as the baseline's own walk runs, so nothing is measured mid-transition. */
const REDUCED_MOTION = [{ name: 'prefers-reduced-motion', value: 'reduce' }];

/** Signed in at the Dashboard, with its first read landed and the Task manager group settled. */
async function atDashboard() {
  const { context, page } = await signedInAt(browser, config, PAGE_URL, VIEWPORTS.wide, REDUCED_MOTION);
  await page.waitForFunction(
    (label) => {
      const meter = Array.from(document.querySelectorAll('app-meter')).find((node) => node.querySelector('.ocu-meter-label')?.textContent.trim() === label);
      return meter !== undefined && meter.querySelector('.ocu-meter-word') !== null;
    },
    { timeout: config.navigationTimeoutMs },
    STRINGS.dashboardCpu
  );
  await page.waitForFunction(
    () => document.querySelector('.ocu-dashboard-tasks-table, .ocu-dashboard-tasks-empty, .ocu-dashboard-tasks-gated, .ocu-dashboard-tasks-refused') !== null,
    { timeout: config.navigationTimeoutMs }
  );
  return { context, page };
}

/** The meter labelled `label`: its readout, word, and fill and word classes. */
function meter(page, label) {
  return page.evaluate((wanted) => {
    const node = Array.from(document.querySelectorAll('app-meter')).find((item) => item.querySelector('.ocu-meter-label')?.textContent.trim() === wanted);
    if (node === undefined) return null;
    return {
      value: node.querySelector('.ocu-meter-value')?.textContent.trim() ?? null,
      word: node.querySelector('.ocu-meter-word')?.textContent.trim() ?? null,
      wordClass: node.querySelector('.ocu-meter-word')?.className ?? '',
      fillClass: node.querySelector('.ocu-meter-fill')?.className ?? '',
      track: node.querySelector('.ocu-meter-track') !== null,
    };
  }, label);
}

before(async () => {
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec signs in and resets the account's remembered state, so it runs only in a throwaway; ${config.container} is not one`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
});

// AC2. Mutation (Rule 19): drop the monitor part from `Dashboard.cls` -> the read no longer carries
// CPU, the CPU meter never shows a word and the page wait goes red.
test('AC2: the seven groups draw in order; CPU is a percent meter with a word; Database space reads Normal in the success color; a value meter carries no word', async () => {
  const { context, page } = await atDashboard();
  try {
    const headings = await page.$$eval('.ocu-dashboard-heading', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(headings, [
      STRINGS.performanceHeading,
      STRINGS.dashboardGroupEcp,
      STRINGS.dashboardGroupStatus,
      STRINGS.systemUsageLabel,
      STRINGS.dashboardGroupAlerts,
      STRINGS.dashboardGroupLicensing,
      STRINGS.dashboardGroupTasks,
    ]);

    const cpu = await meter(page, STRINGS.dashboardCpu);
    assert.ok(cpu !== null, 'a CPU meter is drawn');
    assert.match(cpu.value, /^\d+(\.\d+)? %$/, `CPU reads a percentage with its unit: ${cpu.value}`);
    assert.ok(['Normal', 'Warning', 'Troubled'].includes(cpu.word), `and a state word: ${cpu.word}`);
    assert.ok(cpu.track, 'on a track');

    const space = await meter(page, STRINGS.systemUsageDatabaseSpace);
    assert.equal(space?.word, 'Normal', 'Database space reads the vendor\'s word');
    assert.match(space?.wordClass ?? '', /ocu-meter-word-normal/, 'in the success color');
    assert.match(space?.fillClass ?? '', /ocu-meter-fill-normal/);

    const refs = await meter(page, STRINGS.processDetailsGlobalReferences);
    assert.equal(refs?.word, null, 'a value meter carries no word');
    assert.equal(refs?.track, false, 'and no track');
    assert.match(refs?.value ?? '', /^[0-9,]+$/, `its readout is a grouped whole number: ${refs?.value}`);

    const tasks = await page.evaluate(() => ({
      rows: document.querySelectorAll('.ocu-dashboard-tasks-table tbody tr').length,
      empty: document.querySelector('.ocu-dashboard-tasks-empty')?.textContent.trim() ?? null,
    }));
    assert.ok(tasks.rows > 0 || tasks.empty === STRINGS.taskUpcomingEmpty, `the Task manager group draws Upcoming tasks' rows or its empty text: ${JSON.stringify(tasks)}`);
    assert.ok(tasks.rows <= 5, 'at most five occurrences');
  } finally {
    await context.close();
  }
});

// AC5. Mutation (Rule 19): declare `refreshes` false on `Dashboard.cls` -> no chip renders and the
// chip wait goes red.
test('AC5: the refresh chip starts off with no rate remembered, and offers 5, 10, 30 and 60 s', async () => {
  const { context, page } = await atDashboard();
  try {
    await page.waitForSelector('.ocu-command-bar-refresh', { timeout: config.navigationTimeoutMs });
    const chip = await page.$('.ocu-command-bar-refresh');
    assert.equal(await page.$eval('.ocu-command-bar-refresh', (button) => button.textContent.trim()), STRINGS.statusAutoRefreshOff, 'the chip reads off');
    for (const rate of [5, 10, 30, 60]) {
      await chip.click();
      await page.waitForFunction(
        (wanted) => document.querySelector('.ocu-command-bar-refresh').textContent.trim() === wanted,
        { timeout: config.navigationTimeoutMs },
        STRINGS.statusAutoRefreshOn.replace('<n>', String(rate))
      );
    }
    await chip.click();
    await page.waitForFunction(
      (wanted) => document.querySelector('.ocu-command-bar-refresh').textContent.trim() === wanted,
      { timeout: config.navigationTimeoutMs },
      STRINGS.statusAutoRefreshOff
    );
  } finally {
    await context.close();
  }
});

// AC6: the DW-1337 gate, with no new allowance.
test('AC6: the Dashboard passes DW-1337 wide and narrow, light and dark, with no entry beyond the baseline', async () => {
  const { context, page } = await atDashboard();
  try {
    assert.deepEqual(await structural(page), [], 'no violation beyond the baseline');
  } finally {
    await context.close();
  }
});

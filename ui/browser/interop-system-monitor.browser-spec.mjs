/**
 * Story 24.17 Batch 5 in a real browser, against the throwaway instance: Interoperability's System monitor and its Most active queues drill-down (AD-5, AD-43, AD-62).
 *
 * What it pins: System monitor opens with its eight group headings and twenty-five meters, its Productions running meter shows the count the screen's own read answers,
 * the three tables' links open their drill-downs, and Most active queues opens answered, with its rows or its empty text, while the side bar lists the System monitor
 * and none of the three drill-downs.
 *
 * It starts no production and creates nothing on the instance; it signs in and resets the account's remembered state, so it runs on a throwaway only.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/interop-system-monitor.browser-spec.mjs` (after `npm run build` and the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const ROUTE = 'interoperability/system-monitor';
const QUEUES_ROUTE = 'interoperability/system-monitor/queues';
const READ_PATH = '/api/ocupilot/screens/interop.systemmonitor/read';
const REDUCED_MOTION = [{ name: 'prefers-reduced-motion', value: 'reduce' }];

let browser = null;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec never runs against the live container');
  await assertThrowaway(config);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
});

/** Signed in at System monitor, with its first read landed: the Productions running meter shows a value. */
async function atMonitor() {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${ROUTE}?ns=HSCUSTOM`, VIEWPORTS.wide, REDUCED_MOTION);
  await page.waitForFunction(
    (label) => {
      const meter = Array.from(document.querySelectorAll('app-meter')).find((node) => node.querySelector('.ocu-meter-label')?.textContent.trim() === label);
      const value = meter?.querySelector('.ocu-meter-value')?.textContent.trim() ?? '';
      return value !== '' && value.charCodeAt(0) !== 0x2014;
    },
    { timeout: config.navigationTimeoutMs },
    STRINGS.interopSystemMonitorMeterProductionsRunning
  );
  await page.waitForFunction(() => document.querySelector('.ocu-dashboard')?.getAttribute('aria-busy') === 'false', { timeout: config.navigationTimeoutMs });
  return { context, page };
}

// AC8. Mutation (Rule 19): bind the Productions running meter to `Processes` in `interop-system-monitor.store.ts`, rebuild and redeploy -> the count assertion goes red
// (the instance runs no production, so `EnsJobs` reads 0 as Productions running does and would not).
test('AC8: System monitor draws its groups and meters, and Productions running shows the count the screen\'s own read answers', async () => {
  const { context, page } = await atMonitor();
  try {
    const headings = await page.$$eval('.ocu-dashboard-heading', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(headings, [
      STRINGS.interopSystemMonitorGroupThroughput,
      STRINGS.interopSystemMonitorGroupJobs,
      STRINGS.interopSystemMonitorGroupTime,
      STRINGS.systemUsageLabel,
      STRINGS.interopSystemMonitorGroupQueues,
      STRINGS.dashboardGroupAlerts,
      STRINGS.dashboardGroupLicensing,
      STRINGS.dashboardGroupTasks,
    ]);
    assert.equal((await page.$$('app-meter')).length, 25, 'twenty-five meters');
    const shown = await page.evaluate(
      (label) => {
        const meter = Array.from(document.querySelectorAll('app-meter')).find((node) => node.querySelector('.ocu-meter-label')?.textContent.trim() === label);
        return meter?.querySelector('.ocu-meter-value')?.textContent.trim() ?? '';
      },
      STRINGS.interopSystemMonitorMeterProductionsRunning
    );
    const response = await fetch(`${config.origin}${READ_PATH}?ns=HSCUSTOM`, {
      headers: { Authorization: `Basic ${Buffer.from(`${config.username}:${config.password}`).toString('base64')}` },
    });
    assert.equal(response.status, 200, 'the screen\'s read answers');
    const answered = String((await response.json()).rows[0].EnsProductionsRunning);
    assert.equal(shown, answered, `the meter shows ${shown} and the screen's read answers ${answered}`);
  } finally {
    await context.close();
  }
});

test('AC8: the Production queues group links Most active queues, which opens answered, and the side bar lists System monitor and no drill-down', async () => {
  const { context, page } = await atMonitor();
  try {
    const links = await page.$$eval('a.ocu-details-link', (nodes) => nodes.map((node) => node.getAttribute('data-drill-down')));
    assert.deepEqual(links, ['interoperability/system-monitor/processes', QUEUES_ROUTE, 'interoperability/system-monitor/tasks']);
    const selector = `a.ocu-details-link[data-drill-down="${QUEUES_ROUTE}"]`;
    assert.equal(await page.$eval(selector, (link) => new URL(link.href).pathname), `/ocupilot/${QUEUES_ROUTE}`, 'the link addresses its screen under the application\'s base');
    await page.click(selector);
    await page.waitForFunction((path) => window.location.pathname === path, { timeout: config.navigationTimeoutMs }, `/ocupilot/${QUEUES_ROUTE}`);
    await page.waitForFunction(
      (empty) => document.querySelector('[aria-busy="true"]') === null && (document.querySelector('tbody tr') !== null || document.body.textContent.includes(empty)),
      { timeout: config.navigationTimeoutMs },
      STRINGS.interopSystemMonitorQueuesEmpty
    );
    if ((await page.$('app-side-bar nav.ocu-side-bar')) === null) {
      await page.keyboard.down('Control');
      await page.keyboard.press('b');
      await page.keyboard.up('Control');
    }
    await page.waitForSelector('app-side-bar nav.ocu-side-bar', { timeout: config.navigationTimeoutMs });
    const entries = await page.$$eval('app-side-bar .ocu-side-bar-item .ocu-side-bar-label', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.ok(entries.includes(STRINGS.interopSystemMonitorLabel), 'the side bar lists System monitor');
    for (const label of [STRINGS.activeProcessesLabel, STRINGS.interopSystemMonitorQueuesLabel, STRINGS.taskUpcomingLabel]) {
      assert.ok(!entries.includes(label), `the side bar does not list ${label}`);
    }
  } finally {
    await context.close();
  }
});

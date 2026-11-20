/**
 * Story 21.20's System alerts in a real browser, against the throwaway instance (AC4): OS management's one-row list of the
 * instance's alert state. The row reads the instance's own state text, alert count and last alert; and Reset alerts warns first
 * with the published sentence, after which Proceed sends one request and the row reads OK and 0.
 *
 * The reset leg first puts the instance in an alert state (`$SYSTEM.Monitor.SetState(2)` in `%SYS`), so the row has something to
 * reset, and resets it from the screen; the throwaway's own monitor raises the state again afterwards. It signs in and resets the
 * account's remembered state, so it runs on a throwaway only.
 *
 * Run: `node --test --test-concurrency=1 browser/system-alerts.browser-spec.mjs` (after `npm run build`, the bundle copied into
 * the throwaway, and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const ROUTE = 'os-management/system-alerts';
const PAGE_URL = `/ocupilot/${ROUTE}?ns=HSCUSTOM`;

let browser = null;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec never runs against the live container');
  await assertThrowaway(config);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
});

/** Every rendered row's cells, in row order. */
function describeRows(page) {
  return page.evaluate((rowSelector) => {
    const rows = Array.from(document.querySelectorAll(rowSelector));
    return rows.map((row) => Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim()));
  }, ROW_SELECTOR);
}

/** The instance's own state, as `State|AlertCount`. */
function instanceState() {
  const output = runIris(config.container, [
    'Set $NAMESPACE="%SYS" Write "OCU-ALERTSTATE-START:",$SYSTEM.Monitor.State(),"|",$SYSTEM.Monitor.Alerts(),":OCU-ALERTSTATE-END",!',
  ]);
  return markerValue(output, 'ALERTSTATE');
}

// AC4. Mutation (Rule 19): swap the `StateText` and `AlertCount` columns' fields in `SystemAlertsList.cls` and regenerate the
// mirror -> the row leg goes red.
test("AC4: the screen is one row, under the declared headers, of the instance's own state and alert count", async () => {
  const { context, page } = await signedInAt(browser, config, PAGE_URL, VIEWPORTS.wide);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const headers = await page.$$eval('.ocu-data-table-header-label', (labels) => labels.map((label) => label.textContent.trim()));
    assert.deepEqual(headers, [STRINGS.processColumnState, STRINGS.systemAlertsColumnAlerts, STRINGS.systemAlertsColumnLast, STRINGS.commandBoxGroupActions]);
    const rows = await describeRows(page);
    assert.equal(rows.length, 1, `one row: ${JSON.stringify(rows)}`);
    const [state, count] = (instanceState() ?? '').split('|');
    assert.ok(['OK', 'Warning', 'Alert', 'Hung'].includes(rows[0][0]), `the state reads one of the instance's words: ${rows[0][0]}`);
    assert.equal(rows[0][1], count, `and the alert count is the instance's (${state} state)`);
  } finally {
    await context.close();
  }
});

// AC4. Mutation (Rule 19): skip `$SYSTEM.Monitor.Clear()` in `OcuPilot.Port.Harvest.Alerts.AlertsManage` -> the row stays in the
// alert state and the row wait goes red.
test('AC4: Reset alerts warns with the published sentence, and Proceed leaves the row reading OK and 0', async () => {
  runIris(config.container, ['Set $NAMESPACE="%SYS" Do $SYSTEM.Monitor.SetState(2)']);
  const { context, page } = await signedInAt(browser, config, PAGE_URL, VIEWPORTS.wide);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const before = (await describeRows(page))[0];
    assert.equal(before[0], 'Alert', `the row reads the alert state the leg set: ${JSON.stringify(before)}`);
    const posts = [];
    page.on('request', (request) => {
      if (request.method() === 'POST' && new URL(request.url()).pathname.endsWith('/screens/osmgmt.systemalerts/action')) posts.push(request.postData() ?? '');
    });
    await clickRowCentre(page, { index: 0 });
    await page.waitForFunction((selector) => document.querySelector(selector) !== null, { timeout: config.navigationTimeoutMs }, `${ROW_SELECTOR}[aria-selected="true"]`);
    await page.click(`${ROW_SELECTOR}[aria-selected="true"] .ocu-data-table-trigger`);
    await page.waitForSelector('[role="menu"]', { timeout: config.navigationTimeoutMs });
    await page.evaluate((wanted) => {
      const items = Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'));
      items.find((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted).click();
    }, STRINGS.systemAlertsResetAction);
    await page.waitForSelector('app-warning-dialog', { timeout: config.navigationTimeoutMs });
    const opened = await page.evaluate(() => {
      const surface = document.querySelector('[role="dialog"]');
      return {
        title: (surface.querySelector('.ocu-dialog-title')?.textContent ?? '').trim(),
        body: (surface.querySelector('.ocu-warning-consequence')?.textContent ?? '').trim(),
      };
    });
    assert.equal(opened.title, STRINGS.systemAlertsResetAction, 'the warning is titled with the verb');
    assert.equal(opened.body, STRINGS.systemAlertsResetConsequence, 'and states the published consequence');
    assert.equal(posts.length, 0, 'nothing is sent before Proceed');
    await page.click('[role="dialog"] .ocu-dialog-actions .ocu-button-primary');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await page.waitForFunction(
      (rowSelector) => {
        const cells = Array.from(document.querySelector(rowSelector)?.querySelectorAll('[role="gridcell"]') ?? []).map((cell) => cell.textContent.trim());
        return cells[0] === 'OK' && cells[1] === '0';
      },
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR
    );
    assert.equal(posts.length, 1, 'Proceed sent one request');
    assert.equal(JSON.parse(posts[0]).action, 'reset', 'the reset action');
    assert.match(instanceState() ?? '', /^0\|0$/, 'and the instance itself reads OK and 0');
  } finally {
    await context.close();
  }
});

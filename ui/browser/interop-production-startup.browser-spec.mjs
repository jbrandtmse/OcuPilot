/**
 * Story 24.3 in a real browser, against the throwaway instance: the Productions screen's startup settings (AD-5, AD-53, AD-62).
 *
 * What it pins, in `USER`, whose two probe productions this spec creates: the list draws the three startup columns after the four it had
 * and the row menu offers Start with the instance and Shutdown group beside its five actions; Start with the instance opens its dialog on
 * the selected row, sends the checkbox and the priority, and the list then re-reads and shows the production Yes at that priority and the
 * production it replaced No; turning it off sends the box alone; Shutdown group opens its dialog at the row's group, sends the group typed,
 * keeps the instance's sentence in the dialog for a value outside its shape and for one the production already holds, and the list shows
 * the group set.
 *
 * Each test puts the startup settings back as it found them, so every test passes alone and in any order.
 *
 * **It compiles two probe productions in `USER` and sets their startup settings** through `OcuPilot.Test.ProductionProbe` and
 * `OcuPilot.Test.InteropStartupControl`, so it runs on a throwaway only; the `after` hook puts the settings back and removes the probe,
 * whatever the tests answered. It starts no production.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/interop-production-startup.browser-spec.mjs` (after `npm run build` and the bundle copied
 * into the throwaway).
 */

import { test, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const PROBE = 'OcuPilot.Test.ProductionProbe';
const CONTROL = 'OcuPilot.Test.InteropStartupControl';
const PRODUCTION = 'OcuPilotProbe.Interop.Production';
const OTHER = 'OcuPilotProbe.Interop.Other';
const LIST_URL = '/ocupilot/interoperability/productions?ns=USER';
const ACTION_PATH = '/api/ocupilot/screens/interop.productions/action';
const FIELD = '[data-interop-startup-value]';
const BOX = '[data-interop-startup-checkbox]';
const CONFIRM = '[data-interop-startup-confirm]';
const DIALOG = '[role="dialog"]';

let browser = null;
let created = false;
/** The startup settings of `USER` before the run, as the probe saves them (`~`-joined). */
let saved = '';

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** Put the startup settings back as the run found them. */
function restore() {
  const put = probe('SURESTORE', `$System.Status.IsOK(##class(${PROBE}).RestoreStartup($ListFromString("${saved}", "~")))`);
  assert.equal(put.value, '1', `the startup settings are put back: ${put.output}`);
}

/** The vendor's own state of `USER` as `auto-start|priority|probe group|other group|probe holds a group node`. */
function vendor() {
  return probe('SUSTATE', `##class(${CONTROL}).Vendor()`).value;
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec compiles probe productions and sets startup settings, so it runs only in a throwaway; ${config.container} is not one`);
  saved = probe('SUSAVE', `$ListToString(##class(${PROBE}).SaveStartup(), "~")`).value;
  const removed = probe('SUCLEAN', `$System.Status.IsOK(##class(${PROBE}).Remove())`);
  assert.equal(removed.value, '1', `an earlier run's probe is removed: ${removed.output}`);
  const made = probe('SUMADE', `$System.Status.IsOK(##class(${PROBE}).Create())`);
  assert.equal(made.value, '1', `the probe productions are created: ${made.output}`);
  created = true;
  browser = await puppeteer.launch(launchOptions(config));
});

beforeEach(() => {
  if (created) restore();
});

after(async () => {
  try {
    if (created && /-ci$/.test(config.container)) {
      restore();
      const removed = probe('SUGONE', `$System.Status.IsOK(##class(${PROBE}).Remove())_##class(${PROBE}).Gone()`);
      assert.equal(removed.value, '11', `the probe productions are removed: ${removed.output}`);
      assert.equal(probe('SUAFTER', `$ListToString(##class(${PROBE}).SaveStartup(), "~")`).value, saved, 'the startup settings are as the run found them');
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

/** The cells of the row whose name cell holds `name` (a changed row adds its tag to the cell), or `null`. */
function rowOf(page, name) {
  return page.evaluate(
    (rowSelector, wanted) => {
      const row = Array.from(document.querySelectorAll(rowSelector)).find((node) => node.querySelector('[role="gridcell"]')?.textContent.includes(wanted));
      return row === undefined ? null : Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim());
    },
    ROW_SELECTOR,
    name
  );
}

/** Wait until the row named `name` shows `cells` in its first seven cells. */
async function rowShows(page, name, cells) {
  await page.waitForFunction(
    (rowSelector, wanted, expected) => {
      const row = Array.from(document.querySelectorAll(rowSelector)).find((node) => node.querySelector('[role="gridcell"]')?.textContent.includes(wanted));
      if (row === undefined) return false;
      const found = Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim());
      return expected.every(([index, text]) => found[index] === text);
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name,
    cells
  );
}

/** Open the list and select the row named `name`, by a cell that is not the name. */
async function select(page, name) {
  await waitForRows(page, config.navigationTimeoutMs);
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, name);
  await page.waitForFunction(
    (rowSelector, wanted) => {
      const rows = Array.from(document.querySelectorAll(rowSelector));
      return rows.length === 1 && rows[0].textContent.includes(wanted);
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name
  );
  await clickRowCentre(page, { index: 0, cell: 2 });
  await page.waitForFunction((rowSelector) => document.querySelector(rowSelector)?.getAttribute('aria-selected') === 'true', { timeout: config.navigationTimeoutMs }, ROW_SELECTOR);
}

/** The entries of the selected row's menu. */
async function menuLabels(page) {
  await page.click(`${ROW_SELECTOR}[aria-selected="true"] .ocu-data-table-trigger`);
  await page.waitForSelector('[role="menu"]', { timeout: config.navigationTimeoutMs });
  const labels = await page.$$eval('[role="menu"] [role="menuitem"] .ocu-data-table-menu-label', (items) => items.map((item) => item.textContent.trim()));
  await page.keyboard.press('Escape');
  return labels;
}

/** Open the selected row's menu and click the entry labeled `label`. */
async function rowAction(page, label) {
  await page.click(`${ROW_SELECTOR}[aria-selected="true"] .ocu-data-table-trigger`);
  await page.waitForSelector('[role="menu"]', { timeout: config.navigationTimeoutMs });
  await page.evaluate((wanted) => {
    const items = Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'));
    items.find((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted).click();
  }, label);
  await page.waitForSelector(`${DIALOG} ${CONFIRM}`, { visible: true, timeout: config.navigationTimeoutMs });
}

async function fill(page, selector, value) {
  await page.click(selector, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  if (value !== '') await page.type(selector, value);
}

const dialogClosed = (page) => page.waitForFunction((selector) => document.querySelector(selector) === null, { timeout: config.navigationTimeoutMs }, DIALOG);

/** Record each action the page posts for the probe productions, with its body. */
function recordActions(page) {
  const posts = [];
  page.on('request', (request) => {
    if (request.method() === 'POST' && new URL(request.url()).pathname === ACTION_PATH) posts.push(JSON.parse(request.postData() ?? '{}'));
  });
  return posts;
}

test('Productions draws the startup columns after its four, and offers Start with the instance and Shutdown group beside its five actions', async () => {
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const headers = await page.$$eval('.ocu-data-table-header-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(
      headers.slice(4, 7),
      [STRINGS.interopProductionColumnAutoStart, STRINGS.interopProductionColumnStartupPriority, STRINGS.interopProductionColumnShutdownGroup],
      'the three startup headers, after the four it had'
    );
    assert.deepEqual((await rowOf(page, PRODUCTION)).slice(4, 7), ['No', STRINGS.tableEmptyValue, '2'], 'a probe production that does not start with the instance reads No, no priority and the default group');
    await select(page, PRODUCTION);
    const labels = await menuLabels(page);
    for (const label of [STRINGS.actionStart, STRINGS.actionStop, STRINGS.actionRestart, STRINGS.actionUpdate, STRINGS.actionRecover, STRINGS.interopProductionAutoStartAction, STRINGS.interopProductionColumnShutdownGroup]) {
      assert.equal(labels.filter((entry) => entry === label).length, 1, `the row menu offers ${label} once: ${JSON.stringify(labels)}`);
    }
  } finally {
    await context.close();
  }
});

test('Start with the instance sets the production and its priority, the list shows it and the production it replaced, and turning it off sends the box alone', async () => {
  assert.equal(probe('SUSEED', `$System.Status.IsOK(##class(${CONTROL}).Seed("${OTHER}", 5))`).value, '1', 'the other production starts with the instance at priority 5');
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const posts = recordActions(page);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await rowShows(page, OTHER, [[4, 'Yes'], [5, '5']]);
    await select(page, PRODUCTION);
    await rowAction(page, STRINGS.interopProductionAutoStartAction);
    const opened = await page.evaluate((box) => ({
      title: document.querySelector('[role="dialog"] .ocu-dialog-title').textContent.trim(),
      help: document.querySelector('[data-interop-startup-help]').textContent.trim(),
      checked: document.querySelector(box).checked,
      hasField: document.querySelector('[data-interop-startup-value]') !== null,
    }), BOX);
    assert.deepEqual(
      opened,
      { title: STRINGS.interopProductionAutoStartTitle.replace('<production>', PRODUCTION), help: STRINGS.interopProductionAutoStartHelp, checked: false, hasField: false },
      'the dialog is titled with the production, states how the instance starts productions and opens unchecked with no priority'
    );
    await page.click(BOX);
    await page.waitForSelector(FIELD, { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval(FIELD, (node) => node.value), '0', 'the priority opens at 0 for a production that has none');
    await fill(page, FIELD, '4');
    const sentBefore = posts.length;
    await page.click(CONFIRM);
    await dialogClosed(page);
    assert.equal(posts.length, sentBefore + 1, 'the confirm sent one request');
    await rowShows(page, PRODUCTION, [[4, 'Yes'], [5, '4']]);
    await page.click(FILTER_SELECTOR, { clickCount: 3 });
    await page.keyboard.press('Backspace');
    await rowShows(page, OTHER, [[4, 'No'], [5, STRINGS.tableEmptyValue]]);
    assert.deepEqual(posts.at(-1), { action: 'autostart', id: PRODUCTION, values: { AutoStart: '1', StartupPriority: '4' } }, 'one request, with the checkbox and the priority under the tool\'s names');
    assert.equal(vendor(), `${PRODUCTION}|4|2|2|0`, 'the vendor reads the production at priority 4 in place of the other');

    await select(page, PRODUCTION);
    await rowAction(page, STRINGS.interopProductionAutoStartAction);
    assert.equal(await page.$eval(BOX, (node) => node.checked), true, 'the dialog opens checked for a production that starts with the instance');
    assert.equal(await page.$eval(FIELD, (node) => node.value), '4', 'at its own priority');
    await page.click(BOX);
    const offBefore = posts.length;
    await page.click(CONFIRM);
    await dialogClosed(page);
    assert.equal(posts.length, offBefore + 1, 'turning it off sent one request');
    await rowShows(page, PRODUCTION, [[4, 'No'], [5, STRINGS.tableEmptyValue]]);
    assert.deepEqual(posts.at(-1), { action: 'autostart', id: PRODUCTION, values: { AutoStart: '0' } }, 'turning it off sends the box alone');
    assert.equal(vendor(), '||2|2|0', 'and no production of USER starts with the instance');
  } finally {
    await context.close();
  }
});

test('Shutdown group opens at the row\'s group, sends the group typed, and keeps the instance\'s sentence in the dialog for a bad value and for one already held', async () => {
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const posts = recordActions(page);
  // The namespace's own auto-start production and priority, which this test does not change.
  const autoStart = vendor().split('|').slice(0, 2).join('|');
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await select(page, PRODUCTION);
    await rowAction(page, STRINGS.interopProductionColumnShutdownGroup);
    assert.equal(await page.$eval('[role="dialog"] .ocu-dialog-title', (node) => node.textContent.trim()), STRINGS.interopProductionShutdownGroupTitle.replace('<production>', PRODUCTION), 'the dialog is titled with the production');
    assert.equal(await page.$eval('[data-interop-startup-help]', (node) => node.textContent.trim()), STRINGS.interopProductionShutdownGroupHelp, 'and states how the instance stops productions');
    assert.equal(await page.$eval(FIELD, (node) => node.value), '2', 'it opens at the production\'s group');
    await fill(page, FIELD, 'abc');
    await page.click(CONFIRM);
    await page.waitForSelector('[data-interop-startup-violation]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-interop-startup-violation]', (node) => node.textContent.trim()), STRINGS.interopStartupRefusalGroup, 'a value outside its shape is refused with the server\'s sentence under the field');
    await fill(page, FIELD, '2');
    await page.click(CONFIRM);
    await page.waitForFunction((sentence) => document.querySelector('[data-interop-startup-reason]')?.textContent.trim() === sentence, { timeout: config.navigationTimeoutMs }, STRINGS.interopStartupRefusalSame);
    assert.equal(vendor(), `${autoStart}|2|2|0`, 'nothing was written by either refusal');
    await fill(page, FIELD, '3');
    const groupBefore = posts.length;
    await page.click(CONFIRM);
    await dialogClosed(page);
    await rowShows(page, PRODUCTION, [[6, '3']]);
    assert.equal(posts.length, groupBefore + 1, 'the confirm sent one request');
    assert.deepEqual(posts.at(-1), { action: 'shutdowngroup', id: PRODUCTION, values: { ShutdownGroup: '3' } }, 'one request, with the group typed under the tool\'s name');
    assert.equal(vendor(), `${autoStart}|3|2|1`, 'the vendor reads the group');
  } finally {
    await context.close();
  }
});

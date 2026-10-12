/**
 * Story 20.6 in a real browser, against the throwaway instance: a production item's Test tab and its Send test dialog (AD-5, AD-8,
 * AD-35, AD-39, AD-47, AD-53, AD-62).
 *
 * What it pins: in `USER`, whose probe production this spec creates and starts with an operation that echoes a request class of its
 * own, the operation's name cell on Production items opens its tabs and the Test tab lists the request classes the operation takes
 * and the fields of each; Send test builds one request from the fields typed in the dialog and shows the status sentence, the
 * session and the response's line, and a value that is markup (`<b>x</b>`) is drawn as the text it is, with no element made of it;
 * a field that names a credential is drawn disabled with its sentence; a business service's tab lists no row, says so, and Send test
 * opens no dialog and says why on the list; and the tab passes the structural and contrast checks at 1280
 * light, 720 light and 1280 dark, with no entry beyond the baseline (DW-1337).
 *
 * **It compiles, starts and writes a probe production in `USER`** through `OcuPilot.Test.ProductionProbe` and
 * `OcuPilot.Test.InteropTestFixture`, so it runs on a throwaway only; the `after` hook stops and removes the production, its
 * classes, its messages and its saved requests, whatever the tests answered.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/interop-item-test.browser-spec.mjs` (after `npm run build` and the bundle copied into
 * the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const PROBE = 'OcuPilot.Test.ProductionProbe';
const FIXTURE = 'OcuPilot.Test.InteropTestFixture';
const PRODUCTION = 'OcuPilotProbe.Interop.Production';
const ECHO = 'OcuPilotProbeEchoOp';
const SERVICE = 'OcuPilotProbeSvc';
const REQUEST = 'OcuPilotProbe.Interop.TestRequest';
const ITEMS = 'interoperability/productions/items';
const GROUP = `${ITEMS}/document`;
const TEST_ROUTE = `${ITEMS}/test`;
const PRODUCTIONS_URL = '/ocupilot/interoperability/productions?ns=USER';
const NAME_TEXT = '.ocu-data-table-link, .ocu-data-table-text';
const MARKUP = '<b>x</b>';
/** The walk's own emulation: the tab strip's label colour transitions, and a measurement taken mid-transition reads neither theme. */
const REDUCED_MOTION = [{ name: 'prefers-reduced-motion', value: 'reduce' }];

let browser = null;
let created = false;

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

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

/** Every body row's cells, each as its trimmed text. */
function allRows(page) {
  return page.evaluate(
    (rowSelector) => Array.from(document.querySelectorAll(rowSelector)).map((row) => Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim())),
    ROW_SELECTOR
  );
}

/** Wait until the table holds a row whose name cell reads `name`. */
async function rowNamed(page, name) {
  await page.waitForFunction(
    (rowSelector, wanted, textSelector) =>
      Array.from(document.querySelectorAll(rowSelector)).some((row) => {
        const cell = row.querySelector('[role="gridcell"]');
        return ((cell?.querySelector(textSelector) ?? cell)?.textContent ?? '').trim() === wanted;
      }),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name,
    NAME_TEXT
  );
}

/** Wait until the page's path holds `suffix`. */
function pathHolds(page, suffix) {
  return page.waitForFunction((wanted) => new URL(window.location.href).pathname.includes(wanted), { timeout: config.navigationTimeoutMs }, suffix);
}

/** The screen has answered the navigation map and drawn its rows. */
async function answered(page) {
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  await waitForRows(page, config.navigationTimeoutMs);
}

/**
 * Open `item` (the echo operation unless another is named) from the Productions list's name cell and Production items' name cell,
 * then its Test tab. An item that takes no test request lists no row, so the tab is drawn once its empty state is (`rows` false).
 */
async function openTestTab(page, item = ECHO, rows = true) {
  await answered(page);
  await clickRowCentre(page, { text: PRODUCTION, link: true });
  await pathHolds(page, `/${ITEMS}/`);
  await answered(page);
  await rowNamed(page, item);
  await clickRowCentre(page, { text: item, link: true });
  await pathHolds(page, `/${GROUP}/`);
  await answered(page);
  await (await page.waitForSelector(`button.ocu-detail-tab[data-route="${TEST_ROUTE}"]`, { visible: true, timeout: config.navigationTimeoutMs })).click();
  await pathHolds(page, `/${TEST_ROUTE}/`);
  if (rows) {
    await answered(page);
  } else {
    await waitForMapAnswered(page, config.navigationTimeoutMs);
    await page.waitForSelector('.ocu-data-table-empty', { visible: true, timeout: config.navigationTimeoutMs });
  }
}

/** Open the Send test dialog from the command bar and wait for it. */
async function openDialog(page) {
  await (await page.waitForSelector('.ocu-command-bar button.ocu-command-bar-primary', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector('[role="dialog"] [data-interop-test-class]', { visible: true, timeout: config.navigationTimeoutMs });
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec compiles and starts a probe production, so it runs only in a throwaway; ${config.container} is not one`);
  const removed = probe('ITCLEAN', `$System.Status.IsOK(##class(${FIXTURE}).Remove())_$System.Status.IsOK(##class(${PROBE}).Remove())`);
  assert.equal(removed.value, '11', `an earlier run's probe is removed: ${removed.output}`);
  const made = probe('ITMADE', `$System.Status.IsOK(##class(${PROBE}).Create())_$System.Status.IsOK(##class(${FIXTURE}).Create())`);
  assert.equal(made.value, '11', `the probe production and the fixture's classes are created: ${made.output}`);
  created = true;
  const started = probe('ITSTART', `$System.Status.IsOK(##class(${FIXTURE}).Start())`);
  assert.equal(started.value, '1', `the probe production runs with the testing service registered: ${started.output}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (created && /-ci$/.test(config.container)) {
      const gone = probe('ITGONE', `$System.Status.IsOK(##class(${PROBE}).Settle())_$System.Status.IsOK(##class(${FIXTURE}).Remove())_$System.Status.IsOK(##class(${PROBE}).Remove())_##class(${PROBE}).Gone()`);
      assert.equal(gone.value, '1111', `the probe production is removed: ${gone.output}`);
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

// AC1. Mutation (Rule 19): drop `InteropItemTestTab`'s `tab` -> the Test tab is not on the strip and this goes red.
test('AC1: the Test tab lists the request classes the echo operation takes and the fields of each, and passes the structural walk', async () => {
  const { context, page } = await signedInAt(browser, config, PRODUCTIONS_URL, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await openTestTab(page);
    const rows = await allRows(page);
    const classes = [...new Set(rows.map((row) => row[0]))];
    assert.deepEqual(classes, ['Ens.StringRequest', 'EnsLib.HL7.Message', REQUEST, `${REQUEST}Sub`], 'the operation\'s own request classes, in name order, then a subclass of them');
    const fields = rows.filter((row) => row[0] === REQUEST).map((row) => row[1]);
    assert.deepEqual(fields, ['Text', 'Count', 'Kind', 'Password', 'Address.Street', 'Address.City', 'Flag', 'Level', 'Credential.Value'], 'the request class\'s fields, an embedded object\'s under a dotted path');
    assert.deepEqual(await structural(page, TEST_ROUTE), [], 'Test: no violation beyond the baseline\'s entries');
  } finally {
    await context.close();
  }
});

// AC2, AC8. Mutation (Rule 19): draw the dialog's lines through `innerHTML` -> a `b` element is drawn and the last assertion goes red.
test('AC2, AC8: Send test sends the request built from the typed fields and shows the session and the response as text, markup left as the text it is', async () => {
  const { context, page } = await signedInAt(browser, config, PRODUCTIONS_URL, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await openTestTab(page);
    await openDialog(page);
    await page.select('[role="dialog"] [data-interop-test-class]', REQUEST);
    const text = await page.waitForSelector('[role="dialog"] [data-interop-test-field][data-field="Text"] [data-interop-test-input]', { visible: true, timeout: config.navigationTimeoutMs });
    await text.type(MARKUP);
    await (await page.waitForSelector('[role="dialog"] [data-interop-test-send]', { visible: true })).click();
    await page.waitForSelector('[role="dialog"] [data-interop-test-result] pre', { timeout: config.navigationTimeoutMs });
    const shown = await page.evaluate(() => ({
      status: document.querySelector('[data-interop-test-status]')?.textContent?.trim() ?? '',
      lines: document.querySelector('[data-interop-test-result] pre')?.textContent ?? '',
      markupElements: document.querySelectorAll('[role="dialog"] [data-interop-test-result] b, [role="dialog"] pre b').length,
    }));
    assert.ok(/^The target answered in session \d+ with Ens\.StringResponse\.$/.test(shown.status), `the status sentence names the session and the response class: ${shown.status}`);
    assert.equal(shown.lines, `StringValue: echo:${MARKUP}`, 'the response\'s line, with its markup as text');
    assert.equal(shown.markupElements, 0, 'no element was made of the markup');
  } finally {
    await context.close();
  }
});

// AC2, AD-35. Mutation (Rule 19): drop `disabled` from the credential field -> the first assertion goes red.
test('AD-35: a field that names a credential is drawn disabled with its sentence', async () => {
  const { context, page } = await signedInAt(browser, config, PRODUCTIONS_URL, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await openTestTab(page);
    await openDialog(page);
    await page.select('[role="dialog"] [data-interop-test-class]', REQUEST);
    const field = '[role="dialog"] [data-interop-test-field][data-field="Password"]';
    await page.waitForSelector(`${field} [data-interop-test-input]`, { visible: true, timeout: config.navigationTimeoutMs });
    const drawn = await page.evaluate((selector) => ({
      disabled: document.querySelector(`${selector} [data-interop-test-input]`)?.disabled === true,
      caption: document.querySelector(`${selector} [data-interop-test-caption]`)?.textContent?.trim() ?? '',
    }), field);
    assert.equal(drawn.disabled, true, 'the credential field is disabled');
    assert.equal(drawn.caption, STRINGS.interopTestRefusalSecret, 'and states why');
  } finally {
    await context.close();
  }
});

// AC1. Mutation (Rule 19): let `InteropItemTestPage.onOpen` open the dialog on an item that lists no row -> the banner wait goes red.
test('AC1: a business service\'s Test tab lists no row and says so, and Send test opens no dialog and says why', async () => {
  const { context, page } = await signedInAt(browser, config, PRODUCTIONS_URL, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await openTestTab(page, SERVICE, false);
    const drawn = await page.evaluate((rowSelector) => ({
      rows: document.querySelectorAll(rowSelector).length,
      title: document.querySelector('.ocu-data-table-empty-title')?.textContent?.trim() ?? '',
    }), ROW_SELECTOR);
    assert.equal(drawn.rows, 0, 'a business service takes no test request, so the tab lists no row');
    assert.equal(drawn.title, STRINGS.interopItemTestEmpty, 'and says so');
    await (await page.waitForSelector('.ocu-data-table-empty-action', { visible: true, timeout: config.navigationTimeoutMs })).click();
    await page.waitForFunction((sentence) => (document.querySelector('.ocu-banner-message')?.textContent ?? '').trim() === sentence, { timeout: config.navigationTimeoutMs }, STRINGS.interopTestRefusalTargetType);
    assert.equal(await page.evaluate(() => document.querySelectorAll('[role="dialog"]').length), 0, 'Send test says why on the list and opens no dialog');
  } finally {
    await context.close();
  }
});

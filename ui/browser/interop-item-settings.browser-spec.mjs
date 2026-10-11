/**
 * Story 20.22 in a real browser, against the throwaway instance: Interoperability's Item settings list and its
 * Set value and Reset to default (AD-5, AD-35, AD-36, AD-44, AD-53, AD-55, AD-56, AD-62).
 *
 * What it pins: in `USER`, whose probe production this spec creates, the Production items list's name cell opens
 * the Item settings list of the probe operation under the published headers, listing its settings; Set value opens
 * the dialog, titled with the setting, which shows the current value and the default and the pending-update
 * sentence, sends the typed value, and stores it; Reset to default warns with the same sentence and, past Proceed,
 * removes the production's own value; on a setting whose name holds a credential, given a value and a system default,
 * neither reaches the screen, Set value opens no dialog and the list's banner states the published secret sentence; and
 * the list passes the structural and contrast checks at
 * 1280 light, 720 light and 1280 dark, with no entry beyond the baseline (DW-1337).
 *
 * **It compiles and writes a probe production in `USER`** through `OcuPilot.Test.ProductionProbe`, so it runs on a
 * throwaway only; the `after` hook removes the production, its classes and its messages, whatever the tests
 * answered. It starts nothing: a setting write on a stopped production is stored and saved to the class.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/interop-item-settings.browser-spec.mjs` (after `npm run build` and the
 * bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const PROBE = 'OcuPilot.Test.ProductionProbe';
const CONTROL = 'OcuPilot.Test.InteropSettingControl';
const PRODUCTION = 'OcuPilotProbe.Interop.Production';
const OPERATION = 'OcuPilotProbeOp';
const ROUTE = 'interoperability/productions/items/settings';
const PRODUCTIONS_URL = '/ocupilot/interoperability/productions?ns=USER';
const ACTION_PATH = '/api/ocupilot/screens/interop.itemsettings/action';
const ROW_ID = (target, name) => `${PRODUCTION}\u0001${OPERATION}\u0001${target}\u0001${name}`;
const NAME_TEXT = '.ocu-data-table-link, .ocu-data-table-text';
/** What AC3 plants as the credential-named setting's own value and its system default, which the screen never shows. */
const SECRET_VALUE = 'ocu2022plantedvalue';
const SECRET_DEFAULT = 'ocu2022planteddefault';

let browser = null;
let created = false;

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** The probe operation's stored value of its Host setting `name`, `<none>` when it holds no element. */
function stored(name) {
  return probe('SETTING', `##class(${CONTROL}).Stored("Host","${name}")`).value;
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

/** The cells of the row whose name cell reads `name`, or `null`. */
function settingRow(page, name) {
  return page.evaluate(
    (rowSelector, wanted, textSelector) => {
      const row = Array.from(document.querySelectorAll(rowSelector)).find((node) => {
        const cell = node.querySelector('[role="gridcell"]');
        return ((cell?.querySelector(textSelector) ?? cell)?.textContent ?? '').trim() === wanted;
      });
      return row === undefined ? null : Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim());
    },
    ROW_SELECTOR,
    name,
    NAME_TEXT
  );
}

/** Wait until the list holds a row named `name`. */
function rowPresent(page, name) {
  return page.waitForFunction(
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

/** Wait until the row named `name` reads `word` in its cell number `index`. */
function waitForCell(page, name, index, word) {
  return page.waitForFunction(
    (rowSelector, wanted, textSelector, at, expected) => {
      const row = Array.from(document.querySelectorAll(rowSelector)).find((node) => {
        const cell = node.querySelector('[role="gridcell"]');
        return ((cell?.querySelector(textSelector) ?? cell)?.textContent ?? '').trim() === wanted;
      });
      const cells = row === undefined ? [] : Array.from(row.querySelectorAll('[role="gridcell"]'));
      return cells[at]?.textContent.trim() === expected;
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name,
    NAME_TEXT,
    index,
    word
  );
}

/** Narrow the list to `name`, select its row, open its menu and choose the entry labeled `label`. */
async function rowAction(page, name, label) {
  await waitForRows(page, config.navigationTimeoutMs);
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, name);
  await rowPresent(page, name);
  // The filter leaves the one row, whose name cell can carry the Changed tag and the read-back note beside the name.
  await clickRowCentre(page, { index: 0, cell: 2 });
  await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
  await page.evaluate((wanted) => {
    Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'))
      .find((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted)
      .click();
  }, label);
}

/** Open the probe operation's settings: the probe production's items from the Productions list, then the operation's name cell. */
async function openSettings(page) {
  await waitForRows(page, config.navigationTimeoutMs);
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  await clickRowCentre(page, { text: PRODUCTION, link: true });
  await page.waitForFunction((suffix) => new URL(window.location.href).pathname.includes(suffix), { timeout: config.navigationTimeoutMs }, '/interoperability/productions/items/');
  await waitForRows(page, config.navigationTimeoutMs);
  await rowPresent(page, OPERATION);
  await clickRowCentre(page, { text: OPERATION, link: true });
  await page.waitForFunction((suffix) => new URL(window.location.href).pathname.includes(suffix), { timeout: config.navigationTimeoutMs }, `/${ROUTE}/`);
  await waitForRows(page, config.navigationTimeoutMs);
  await rowPresent(page, 'InitSeconds');
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec compiles a probe production, so it runs only in a throwaway; ${config.container} is not one`);
  const removed = probe('ISCLEAN', `$System.Status.IsOK(##class(${PROBE}).Remove())`);
  assert.equal(removed.value, '1', `an earlier run's probe is removed: ${removed.output}`);
  const made = probe('ISMADE', `$System.Status.IsOK(##class(${PROBE}).Create())`);
  assert.equal(made.value, '1', `the probe production is created: ${made.output}`);
  created = true;
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (created && /-ci$/.test(config.container)) {
      const removed = probe('ISGONE', `$System.Status.IsOK(##class(${PROBE}).Remove())_##class(${PROBE}).Gone()`);
      assert.equal(removed.value, '11', `the probe production is removed: ${removed.output}`);
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

// AC1, AC8. Mutation (Rule 19): make `childListFor` answer null for Production items, rebuild and redeploy -> the
// operation's name cell opens nothing and this goes red. `routeIdFor` is the toast's route, pinned by navigation.test.mjs.
test('AC1, AC8: the Production items name cell opens the operation\'s settings, under the published headers, and the walk passes', async () => {
  const { context, page } = await signedInAt(browser, config, PRODUCTIONS_URL, VIEWPORTS.wide);
  try {
    await openSettings(page);
    const headers = await page.$$eval('.ocu-data-table-header-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(
      headers.slice(0, 5),
      [STRINGS.tableColumnName, STRINGS.agentLedgerColumnTarget, STRINGS.errorLogColumnValue, STRINGS.auditEventFieldSource, STRINGS.tableColumnDefault],
      'the declared headers, ahead of the row actions'
    );
    const initSeconds = await settingRow(page, 'InitSeconds');
    const comment = await settingRow(page, 'Comment');
    assert.ok(initSeconds !== null && comment !== null, 'a Host and a Core setting are listed');
    assert.deepEqual([initSeconds[1], initSeconds[2], initSeconds[3], initSeconds[4]], ['Host', '0', 'classDefault', '0'], 'InitSeconds reads its class default');
    assert.equal(comment[1], 'Core', 'a Core setting reads its group');
    assert.equal(await settingRow(page, 'Enabled'), null, 'and the item\'s Enabled is not a setting here');
    assert.deepEqual(await structural(page, ROUTE), [], 'Item settings: no violation beyond the baseline\'s entries');
  } finally {
    await context.close();
  }
});

// AC2, AC5. Mutation (Rule 19): make `InteropItemSettingListPage.onOpen` return at once, rebuild and redeploy -> the dialog
// never opens and this goes red; remove the list's entry from WARNING_CONSEQUENCES -> Reset is sent at once.
test('AC2: Set value opens its dialog and stores the typed value; Reset to default warns, then removes the production\'s own value', async () => {
  const { context, page } = await signedInAt(browser, config, PRODUCTIONS_URL, VIEWPORTS.wide);
  const posts = [];
  page.on('request', (request) => {
    if (new URL(request.url()).pathname === ACTION_PATH) posts.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    await openSettings(page);
    await rowAction(page, 'InitSeconds', STRINGS.interopItemSettingSetAction);
    await page.waitForSelector('input[data-interop-setting-value]', { visible: true, timeout: config.navigationTimeoutMs });
    const opened = await page.evaluate(() => {
      const text = (selector) => document.querySelector(selector)?.textContent?.trim();
      return {
        title: text('[role="dialog"] .ocu-dialog-title'),
        current: text('[data-interop-setting-current]'),
        default: text('[data-interop-setting-default]'),
        consequence: text('[data-interop-setting-consequence]'),
        hint: text('[data-interop-setting-hint]'),
      };
    });
    assert.deepEqual(
      opened,
      {
        title: 'Set value of InitSeconds',
        current: 'Current value: 0',
        default: 'Default: 0',
        consequence: STRINGS.interopItemPendingConsequence,
        hint: STRINGS.interopSettingEmptyHint,
      },
      'the dialog names the setting, its current value and its default, and states the pending update'
    );
    assert.deepEqual(posts, [], 'nothing is sent while the dialog is open');
    await page.click('input[data-interop-setting-value]', { clickCount: 3 });
    await page.type('input[data-interop-setting-value]', '7');
    await page.click('[data-interop-setting-confirm]');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    assert.deepEqual(posts, [{ action: 'set', id: ROW_ID('Host', 'InitSeconds'), values: { Value: '7' } }], 'Set value sent the typed value once');
    await waitForCell(page, 'InitSeconds', 2, '7');
    await waitForCell(page, 'InitSeconds', 3, 'production');
    assert.equal(stored('InitSeconds'), '7', 'the stored configuration holds the production\'s own value');

    await rowAction(page, 'InitSeconds', STRINGS.interopItemSettingResetAction);
    await page.waitForSelector('app-warning-dialog', { timeout: config.navigationTimeoutMs });
    const warning = await page.evaluate(() => {
      const surface = document.querySelector('[role="dialog"]');
      return {
        title: (surface.querySelector('.ocu-dialog-title')?.textContent ?? '').trim(),
        body: (surface.querySelector('.ocu-warning-consequence')?.textContent ?? '').trim(),
        destructive: surface.querySelector('.ocu-button-destructive') !== null,
      };
    });
    assert.deepEqual(warning, { title: STRINGS.interopItemSettingResetAction, body: STRINGS.interopItemPendingConsequence, destructive: false }, 'Reset warns with the published sentence, not destructively');
    assert.equal(posts.length, 1, 'nothing more is sent while the warning is open');
    await page.click('[role="dialog"] .ocu-dialog-actions .ocu-button-primary');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    assert.deepEqual(posts.at(-1), { action: 'reset', id: ROW_ID('Host', 'InitSeconds') }, 'Reset sent once, past Proceed');
    await waitForCell(page, 'InitSeconds', 3, 'classDefault');
    assert.equal(stored('InitSeconds'), '<none>', 'and the production holds no value of its own again');
  } finally {
    await context.close();
  }
});

// AC3. Mutation (Rule 19): drop the secret test from `InteropItemSettingListPage.onOpen`, rebuild and redeploy -> the
// dialog opens over ApiToken and this goes red; stop blanking `Value` in `InteropPort.SettingRow` -> the planted value
// reaches the row and this goes red.
test('AC3: a credential-named setting\'s value and default never reach the list; Set value opens no dialog and states the secret sentence', async () => {
  const planted = probe('PLANTED', `$System.Status.IsOK(##class(${PROBE}).PutItemSetting("${OPERATION}","Host","ApiToken","${SECRET_VALUE}"))_$System.Status.IsOK(##class(${PROBE}).PutDefault("${OPERATION}","Host","ApiToken","${SECRET_DEFAULT}"))`);
  assert.equal(planted.value, '11', `the setting holds a value of its own and a system default: ${planted.output}`);
  const { context, page } = await signedInAt(browser, config, PRODUCTIONS_URL, VIEWPORTS.wide);
  const posts = [];
  page.on('request', (request) => {
    if (new URL(request.url()).pathname === ACTION_PATH) posts.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    await openSettings(page);
    const row = await settingRow(page, 'ApiToken');
    assert.ok(row !== null, 'the secret-named setting is listed');
    assert.deepEqual([row[2], row[4]], [STRINGS.tableEmptyValue, STRINGS.tableEmptyValue], 'its value and default read as empty');
    const shown = await page.evaluate(() => document.body.innerText);
    assert.equal(shown.includes(SECRET_VALUE) || shown.includes(SECRET_DEFAULT), false, 'and neither the value nor the default is anywhere on the screen');
    await rowAction(page, 'ApiToken', STRINGS.interopItemSettingSetAction);
    await page.waitForSelector('.ocu-list-page-banner', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-list-page-banner .ocu-banner-message', (node) => node.textContent.trim()), STRINGS.interopSettingRefusalSecret, 'the list states the published secret sentence');
    assert.equal(await page.$('[role="dialog"]'), null, 'and no dialog opens');
    assert.deepEqual(posts, [], 'nothing was sent');
    assert.equal(stored('ApiToken'), SECRET_VALUE, 'and nothing was stored');
  } finally {
    await context.close();
    runIris(config.container, [`Do ##class(${PROBE}).RemoveDefaults()`]);
  }
});

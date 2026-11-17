/**
 * Story 21.14 in a real browser, against the throwaway instance: NLS configured defaults and Locale definitions (AD-5, AD-29, AD-53, AD-58).
 *
 * What it pins: both screens answer the navigation map and their rows before anything is read; Set value on `LocaleFormat` opens its dialog over
 * the row, states the reload sentence, flips the switch on the instance and the list shows it without a reload, and flips it back; a table row
 * (`Collation`) draws Set value unavailable with the published sentence and opens no dialog. On Locale definitions, Validate on the current locale
 * shows "This locale is valid." and no line the instance wrote; Delete is drawn unavailable with the published sentence on a locale
 * InterSystems ships; Install of the current locale and Delete of a custom locale each ask the typed name, state their published consequence and
 * apply, with the screen announcing the change and the instance reading it. A person's confirmed write is not governance's to refuse; the
 * agent's refusal is pinned by `OcuPilot.Test.LocaleRead`.
 *
 * **It changes the locale-format switch** through the shipped screen, so it runs on a throwaway only; the `after` hook puts the node back to what
 * it found and reloads the current locale, whatever the tests answered. It creates one custom locale, `yzzw`, for Delete to remove, and removes
 * it again if a test left it; its Install is of the current locale (a reload), so it installs no other locale.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/nls-locales.browser-spec.mjs` (after `npm run build` and the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const route = (name) => `/ocupilot/os-management/${name}`;
const SWITCH = 'LocaleFormat';
const NODE = '^SYS("NLS","Config","LocaleFormat")';
const VENDOR = 'OcuPilot.Test.LocaleWriteVendor';
const CUSTOM = 'yzzw';

let browser = null;
let foundSwitch = '';
let foundCurrent = '';
let touched = false;

/** Run one `%SYS` expression on the throwaway and answer its marker. */
function probe(name, lines) {
  const output = runIris(config.container, ['Set $NAMESPACE="%SYS"', ...lines, `Write "OCU-${name}-START:"_result_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** The switch's node as the instance stores it, `''` where it is undefined. */
const storedSwitch = () => probe('NLSNODE', [`Set result=$Get(${NODE})`]);

/** The instance's current locale. */
const storedCurrent = () => probe('NLSCUR', ['Set result=$Get(^%SYS("LOCALE","CURRENT"))']);

/** Put the switch back to `value` (`''` kills it) and reload the current locale, answering the reload's status. */
function restoreSwitch(value) {
  return probe('NLSPUT', [
    value === '' ? `Kill ${NODE}` : `Set ${NODE}=${Number(value)}`,
    'Set result=$System.Status.IsOK(##class(Config.NLS.Locales).Reload())',
  ]);
}

/** One `LocaleWriteVendor` call in the throwaway, answering its marker. */
function vendor(name, method, argument) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_##class(${VENDOR}).${method}("${argument}")_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** The screen has answered the navigation map and drew its rows. */
async function answered(page) {
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  await waitForRows(page, config.navigationTimeoutMs);
}

/**
 * Narrow the list to the rows naming `name`, then click that row on its second cell, which selects it. A row the instance has just changed
 * carries its marker in its first cell, so it is found by its start and clicked by its index.
 */
async function selectRow(page, name) {
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, name);
  await page.waitForFunction(
    (rowSelector, wanted) => {
      // The list has narrowed once only a few rows stand, so an index read now is the narrowed list's.
      const rows = [...document.querySelectorAll(rowSelector)];
      return rows.length <= 3 && rows.some((row) => row.querySelector('[role="gridcell"]')?.textContent.trim().startsWith(wanted));
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name
  );
  const at = await page.$$eval(ROW_SELECTOR, (rows, wanted) => rows.findIndex((row) => row.querySelector('[role="gridcell"]')?.textContent.trim().startsWith(wanted)), name);
  await clickRowCentre(page, { index: at, cell: 2 });
}

/** Open the selected row's menu and answer its entry labeled `label`: `aria-disabled` and its reason, or `null` where the menu has none. */
async function menuEntry(page, label) {
  await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
  return page.evaluate((wanted) => {
    const item = [...document.querySelectorAll('[role="menu"] [role="menuitem"]')].find((entry) => entry.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted);
    if (item === undefined) return null;
    return { disabled: item.getAttribute('aria-disabled') === 'true', reason: item.querySelector('.ocu-data-table-menu-reason')?.textContent.trim() ?? '' };
  }, label);
}

/** Click the open menu's entry labeled `label`. */
function clickEntry(page, label) {
  return page.evaluate((wanted) => [...document.querySelectorAll('[role="menu"] [role="menuitem"]')].find((entry) => entry.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted).click(), label);
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec changes the locale-format switch, so it runs only in a throwaway; ${config.container} is not one`);
  const read = storedSwitch();
  assert.match(read.value ?? '', /^[01]?$/, `the switch's node reads 0, 1 or nothing: ${read.output}`);
  foundSwitch = read.value;
  const current = storedCurrent();
  assert.match(current.value ?? '', /^\w+$/, `the instance has a current locale: ${current.output}`);
  foundCurrent = current.value;
  touched = true;
  assert.equal(vendor('NLSMAKE', 'Create', CUSTOM).value, '1', `the custom locale ${CUSTOM} is created from the current one`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (touched && /-ci$/.test(config.container)) {
      const put = restoreSwitch(foundSwitch);
      const removed = vendor('NLSGONE', 'RemoveCustom', CUSTOM);
      assert.equal(removed.value, '1', `the custom locale ${CUSTOM} is removed: ${removed.output}`);
      assert.equal(put.value, '1', `the switch is put back to ${JSON.stringify(foundSwitch)} and the locale reloaded: ${put.output}`);
      assert.equal(storedSwitch().value, foundSwitch, 'and its node reads as found');
      assert.equal(storedCurrent().value, foundCurrent, 'and the current locale is as found');
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

test('both screens answer their rows before anything is read', async () => {
  for (const [screen, expected] of [
    ['nls-defaults', [SWITCH, 'Collation']],
    ['locales', [foundCurrent, CUSTOM]],
  ]) {
    const { context, page } = await signedInAt(browser, config, route(screen), VIEWPORTS.wide);
    try {
      await answered(page);
      for (const name of expected) {
        await selectRow(page, name);
      }
    } finally {
      await context.close();
    }
  }
});

test('Set value on LocaleFormat states the reload sentence, flips the switch on the instance, shown without a reload, and flips it back', async () => {
  const { context, page } = await signedInAt(browser, config, route('nls-defaults'), VIEWPORTS.wide);
  try {
    await answered(page);
    await page.evaluate(() => {
      window.__ocuNoReload = 'standing';
    });
    for (const direction of ['forward', 'back']) {
      const before = storedSwitch().value === '1' ? '1' : '0';
      const flipped = before === '1' ? '0' : '1';
      await selectRow(page, SWITCH);
      assert.deepEqual(await menuEntry(page, STRINGS.interopItemSettingSetAction), { disabled: false, reason: '' }, `Set value is offered on the switch (${direction})`);
      await clickEntry(page, STRINGS.interopItemSettingSetAction);
      await page.waitForSelector('[data-interop-setting-consequence]', { visible: true, timeout: config.navigationTimeoutMs });
      const statement = await page.$eval('[data-interop-setting-consequence]', (node) => node.textContent.trim());
      assert.ok(statement.endsWith(STRINGS.nlsDefaultReloadConsequence), `the dialog states the reload sentence: ${statement}`);
      await page.click('[data-interop-setting-checkbox]');
      await page.click('[data-interop-setting-confirm]');
      await page.waitForSelector('[data-interop-setting-confirm]', { hidden: true, timeout: config.navigationTimeoutMs });
      assert.equal(storedSwitch().value, flipped, `the instance stores ${flipped} (${direction})`);
      await page.waitForFunction(
        (rowSelector, wanted, value) => [...document.querySelectorAll(rowSelector)].some((row) => {
          const cells = row.querySelectorAll('[role="gridcell"]');
          // The row the instance has just changed carries its marker in its first cell, so it is matched by its start.
          return cells[0]?.textContent.trim().startsWith(wanted) && cells[1]?.textContent.trim() === value;
        }),
        { timeout: config.navigationTimeoutMs },
        ROW_SELECTOR,
        SWITCH,
        flipped
      );
      assert.equal(await page.$eval('[data-config-setting-reload]', (node) => node.textContent.trim()), STRINGS.nlsDefaultReloadConsequence, 'and the line above the list states the reload');
    }
    assert.equal(await page.evaluate(() => window.__ocuNoReload), 'standing', 'the list re-read without the page reloading');
  } finally {
    await context.close();
  }
});

test('a table row draws Set value unavailable with the published sentence, and opens no dialog', async () => {
  const { context, page } = await signedInAt(browser, config, route('nls-defaults'), VIEWPORTS.wide);
  try {
    await answered(page);
    await selectRow(page, 'Collation');
    assert.deepEqual(await menuEntry(page, STRINGS.interopItemSettingSetAction), { disabled: true, reason: STRINGS.configRefusalReadOnly }, 'Set value is unavailable, naming why');
    await clickEntry(page, STRINGS.interopItemSettingSetAction);
    await new Promise((resolve) => setTimeout(resolve, 500));
    assert.equal(await page.$('[data-interop-setting-consequence]'), null, 'and pressing it opens no dialog');
  } finally {
    await context.close();
  }
});

test('Validate on the current locale shows the valid sentence and no line the instance wrote', async () => {
  const { context, page } = await signedInAt(browser, config, route('locales'), VIEWPORTS.wide);
  try {
    await answered(page);
    await selectRow(page, foundCurrent);
    assert.deepEqual(await menuEntry(page, STRINGS.licenseKeyValidate), { disabled: false, reason: '' }, 'Validate is offered');
    await clickEntry(page, STRINGS.licenseKeyValidate);
    await page.waitForSelector('[data-locale-validate-result]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-locale-validate-name]', (node) => node.textContent.trim()), foundCurrent, 'the dialog names the locale');
    assert.equal(await page.$eval('[data-locale-validate-result]', (node) => node.textContent.trim()), STRINGS.localeValidateValid, 'and says it is valid');
    assert.equal(await page.$$eval('[role="dialog"] li', (items) => items.length), 0, 'with no line beneath');
  } finally {
    await context.close();
  }
});

test('Delete is drawn unavailable with the published sentence on a locale InterSystems ships', async () => {
  const { context, page } = await signedInAt(browser, config, route('locales'), VIEWPORTS.wide);
  try {
    await answered(page);
    await selectRow(page, foundCurrent);
    assert.deepEqual(await menuEntry(page, STRINGS.actionDelete), { disabled: true, reason: STRINGS.localeRefusalSystem }, 'Delete is unavailable, naming why');
    await clickEntry(page, STRINGS.actionDelete);
    await new Promise((resolve) => setTimeout(resolve, 500));
    assert.equal(await page.$('.ocu-typed-name-field'), null, 'and pressing it opens no dialog');
  } finally {
    await context.close();
  }
});

/** The announcement the table makes once an action has applied, once it stands. */
async function announcement(page, expected) {
  await page.waitForFunction(
    (text) => (document.querySelector('.ocu-data-table-announcement')?.textContent ?? '').startsWith(text),
    { timeout: config.navigationTimeoutMs },
    expected
  );
  return page.$eval('.ocu-data-table-announcement', (node) => node.textContent.trim());
}

/** Type `name` into the open typed-name dialog and press its destructive button once the exact name has released it. */
async function confirmWith(page, name) {
  await page.type('.ocu-typed-name-field', name);
  await page.waitForFunction(() => document.querySelector('[role="dialog"] .ocu-button-destructive')?.getAttribute('aria-disabled') !== 'true', { timeout: config.navigationTimeoutMs });
  await page.evaluate(() => document.querySelector('[role="dialog"] .ocu-button-destructive').click());
}

// Mutation (Rule 19): drop `LOCALE_LIST` from `DESTRUCTIVE_ON` in `screen-action-handler.ts` (rebuilt and redeployed) -> no typed-name dialog opens and this goes red; drop
// the `delete` entry of `ROW_REASONS` the same way -> the system-locale Delete case goes red.
test('Install of the current locale asks its name, states the consequence and applies, leaving the current locale as it was', async () => {
  const { context, page } = await signedInAt(browser, config, route('locales'), VIEWPORTS.wide);
  try {
    await answered(page);
    await selectRow(page, foundCurrent);
    assert.equal((await menuEntry(page, STRINGS.localeInstallAction))?.disabled, false, 'Install is offered');
    await clickEntry(page, STRINGS.localeInstallAction);
    await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-typed-name-consequence', (node) => node.textContent.trim()), STRINGS.localeInstallConsequence, 'the dialog states what an install does');
    await confirmWith(page, foundCurrent);
    assert.ok((await announcement(page, `${foundCurrent} was updated`)).startsWith(`${foundCurrent} was updated`), 'the screen announces the install');
    assert.equal(storedCurrent().value, foundCurrent, 'and the instance holds its current locale');
  } finally {
    await context.close();
  }
});

test('Delete of a custom locale asks its name, states the consequence and removes it, and the instance no longer lists it', async () => {
  const { context, page } = await signedInAt(browser, config, route('locales'), VIEWPORTS.wide);
  try {
    await answered(page);
    await selectRow(page, CUSTOM);
    assert.deepEqual(await menuEntry(page, STRINGS.actionDelete), { disabled: false, reason: '' }, 'Delete is offered on a custom locale that is not current');
    await clickEntry(page, STRINGS.actionDelete);
    await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-typed-name-consequence', (node) => node.textContent.trim()), STRINGS.localeDeleteConsequence, 'the dialog states what a delete does');
    await confirmWith(page, CUSTOM);
    assert.ok((await announcement(page, `${CUSTOM} was deleted`)).startsWith(`${CUSTOM} was deleted`), 'the screen announces the delete');
    assert.equal(vendor('NLSHAS', 'Exists', CUSTOM).value, '0', 'and the instance no longer holds the locale');
  } finally {
    await context.close();
  }
});

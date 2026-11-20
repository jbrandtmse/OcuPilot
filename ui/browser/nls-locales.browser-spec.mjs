/**
 * Story 21.14 in a real browser, against the throwaway instance: NLS configured defaults and Locale definitions (AD-5, AD-29, AD-53, AD-58).
 *
 * What it pins: both screens answer the navigation map and their rows before anything is read; Set value on `LocaleFormat` opens its dialog over
 * the row, states the reload sentence, flips the switch on the instance and the list shows it without a reload, and flips it back; a table row
 * (`Collation`) draws Set value unavailable with the published sentence and opens no dialog. On Locale definitions, Validate on the current locale
 * shows "This locale is valid." and no line the instance wrote; Delete is drawn unavailable with the published sentence on a locale
 * InterSystems ships; Install of the current locale and Delete of a custom locale each ask the typed name, state their published consequence and
 * are accepted, with the screen announcing the change; the deleted locale is gone from the instance. That an install changes the current locale
 * is pinned by the armed `OcuPilot.Test.LocaleWrite`. A person's confirmed write is not governance's to refuse; the agent's refusal is pinned
 * by `OcuPilot.Test.LocaleRead`.
 *
 * **It changes the locale-format switch** through the shipped screen, so it runs on a throwaway only; the `after` hook puts the node back to what
 * it found and reloads the current locale, whatever the tests answered. It creates one custom locale, `yzzw`, for Delete to remove, and removes
 * it first and again after, in case a run left it; its Install is of the current locale (a reload), so it installs no other locale.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/nls-locales.browser-spec.mjs` (after `npm run build` and the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
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
/** The custom locale the Copy test makes, and removes afterwards. */
const COPIED = 'yzcw';

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
  assert.equal(vendor('NLSCLEAR', 'RemoveCustom', CUSTOM).value, '1', `a custom locale ${CUSTOM} a stopped run left is removed first`);
  assert.equal(vendor('NLSCLEAR2', 'RemoveCustom', COPIED).value, '1', `a custom locale ${COPIED} a stopped run left is removed first`);
  assert.equal(vendor('NLSMAKE', 'Create', CUSTOM).value, '1', `the custom locale ${CUSTOM} is created from the current one`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (touched && /-ci$/.test(config.container)) {
      const put = restoreSwitch(foundSwitch);
      const removed = vendor('NLSGONE', 'RemoveCustom', CUSTOM);
      const removedCopy = vendor('NLSGONE2', 'RemoveCustom', COPIED);
      assert.equal(removed.value, '1', `the custom locale ${CUSTOM} is removed: ${removed.output}`);
      assert.equal(removedCopy.value, '1', `the custom locale ${COPIED} is removed: ${removedCopy.output}`);
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
test('Install of the current locale asks its name, states the consequence and is accepted, leaving the current locale as it was', async () => {
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
    assert.equal(storedCurrent().value, foundCurrent, 'and the instance is still on the locale it was on');
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

/**
 * Narrow the Locale properties list to the rows naming `name` and click the row whose second cell (its Name) starts with it, on its third cell.
 * The first column is the Group, so `selectRow`'s first-cell match does not apply here.
 */
async function selectProperty(page, name) {
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, name);
  await page.waitForFunction(
    (rowSelector, wanted) => {
      const rows = [...document.querySelectorAll(rowSelector)];
      // The list has narrowed once every row standing names the property, so an index read now is the narrowed list's.
      return rows.length > 0 && rows.length <= 3 && rows.every((row) => row.querySelectorAll('[role="gridcell"]')[1]?.textContent.trim().startsWith(wanted));
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name
  );
  const at = await page.$$eval(ROW_SELECTOR, (rows, wanted) => rows.findIndex((row) => row.querySelectorAll('[role="gridcell"]')[1]?.textContent.trim().startsWith(wanted)), name);
  await clickRowCentre(page, { index: at, cell: 2 });
}

const GROUP_WORDS = [
  STRINGS.localeGroupBasic,
  STRINGS.localeGroupFormats,
  STRINGS.localeGroupTables,
  STRINGS.localeGroupIoTables,
  STRINGS.localeGroupTableDefaults,
  STRINGS.localeGroupIoDefaults,
  STRINGS.localeGroupStrings,
];

// Mutation (Rule 19): drop `LocalePropertyList` from `VALUE_WORDS` in `table-model.ts` (rebuilt and redeployed) -> the cells read the codes and this goes red.
test('the properties of the current locale draw each group as its ruled word, and Add table, Set value and Remove table are unavailable with the published sentence', async () => {
  const { context, page } = await signedInAt(browser, config, `${route('locales/properties')}/${encodeURIComponent(foundCurrent)}`, VIEWPORTS.wide);
  try {
    await answered(page);
    const groups = await page.$$eval(ROW_SELECTOR, (rows) => [...new Set(rows.map((row) => row.querySelectorAll('[role="gridcell"]')[0]?.textContent.trim()))]);
    assert.ok(groups.length > 0 && groups.every((group) => GROUP_WORDS.includes(group)), `every group cell reads one of the seven ruled words: ${groups.join(' | ')}`);
    const addTable = await page.evaluate((label) => {
      const button = [...document.querySelectorAll('.ocu-command-bar-primary')].find((entry) => entry.textContent.trim() === label);
      if (button === undefined) return null;
      const id = button.getAttribute('aria-describedby');
      return { disabled: button.getAttribute('aria-disabled') === 'true', reason: id === null ? '' : (document.getElementById(id)?.textContent.trim() ?? '') };
    }, STRINGS.localeAddTableAction);
    assert.deepEqual(addTable, { disabled: true, reason: STRINGS.localeRefusalEditCurrent }, 'Add table is unavailable on the current locale, naming why');
    await selectProperty(page, 'DateFormat');
    assert.deepEqual(await menuEntry(page, STRINGS.interopItemSettingSetAction), { disabled: true, reason: STRINGS.localeRefusalEditCurrent }, 'Set value is unavailable on the current locale, naming why');
    await clickEntry(page, STRINGS.interopItemSettingSetAction);
    await new Promise((resolve) => setTimeout(resolve, 500));
    assert.equal(await page.$('[data-interop-setting-consequence]'), null, 'and pressing it opens no dialog');
    await selectProperty(page, 'PatternTables:Unicode');
    assert.deepEqual(await menuEntry(page, STRINGS.localeRemoveTableAction), { disabled: true, reason: STRINGS.localeRefusalEditCurrent }, 'Remove table is unavailable on a table of the current locale');
  } finally {
    await context.close();
  }
});

test('Load table is unavailable on a row that is not a table, naming why', async () => {
  const { context, page } = await signedInAt(browser, config, `${route('locales/properties')}/${encodeURIComponent(foundCurrent)}`, VIEWPORTS.wide);
  try {
    await answered(page);
    await selectProperty(page, 'DateFormat');
    assert.deepEqual(await menuEntry(page, STRINGS.localeLoadTableAction), { disabled: true, reason: STRINGS.localeRefusalTableNotLoadable }, 'Load table is unavailable on a property row');
  } finally {
    await context.close();
  }
});

test('Set value on a custom locale changes its date format on the instance', async () => {
  ensureCustom('SET');
  const { context, page } = await signedInAt(browser, config, `${route('locales/properties')}/${encodeURIComponent(CUSTOM)}`, VIEWPORTS.wide);
  try {
    await answered(page);
    await selectProperty(page, 'DateFormat');
    assert.deepEqual(await menuEntry(page, STRINGS.interopItemSettingSetAction), { disabled: false, reason: '' }, 'Set value is offered on a custom locale that is not current');
    await clickEntry(page, STRINGS.interopItemSettingSetAction);
    await page.waitForSelector('[data-interop-setting-confirm]', { visible: true, timeout: config.navigationTimeoutMs });
    const field = await page.$('[data-interop-setting-value]');
    assert.notEqual(field, null, 'the dialog has its value field');
    await page.click('[data-interop-setting-value]', { clickCount: 3 });
    await page.keyboard.press('Backspace');
    await page.type('[data-interop-setting-value]', '5');
    await page.click('[data-interop-setting-confirm]');
    await page.waitForSelector('[data-interop-setting-confirm]', { hidden: true, timeout: config.navigationTimeoutMs });
    assert.equal(probe('NLSDATE', [`Set tSC=##class(Config.NLS.Locales).Get("${CUSTOM}",.p) Set result=$Get(p("DateFormat"))`]).value, '5', 'the instance holds the new date format');
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): drop the `LOCALE_PROPERTY_LIST` entry of `TYPED_NAME_ROWS` in `screen-action-handler.ts` (rebuilt and redeployed) -> the dialog asks for the
// composite id, typing the row's name never releases its button, and this goes red.
test('Load table on a custom locale asks the row name, states the consequence and loads the table', async () => {
  ensureCustom('LOAD');
  const { context, page } = await signedInAt(browser, config, `${route('locales/properties')}/${encodeURIComponent(CUSTOM)}`, VIEWPORTS.wide);
  try {
    await answered(page);
    await selectProperty(page, 'PatternTables:Unicode');
    assert.deepEqual(await menuEntry(page, STRINGS.localeLoadTableAction), { disabled: false, reason: '' }, 'Load table is offered on a loadable table of a custom locale');
    await clickEntry(page, STRINGS.localeLoadTableAction);
    await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-typed-name-consequence', (node) => node.textContent.trim()), STRINGS.localeLoadConsequence, 'the dialog states what a load does');
    await confirmWith(page, 'PatternTables:Unicode');
    // The load changes no row, but its change event re-reads the list, which marks the row it names once that read has landed.
    await page.waitForFunction(
      (rowSelector, wanted) => [...document.querySelectorAll(rowSelector)].some((row) => row.classList.contains('ocu-data-table-row-changed') && row.querySelectorAll('[role="gridcell"]')[1]?.textContent.trim().startsWith(wanted)),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      'PatternTables:Unicode'
    );
  } finally {
    await context.close();
  }
});

/** Make sure the custom locale `CUSTOM` stands, whichever test ran before. */
function ensureCustom(name) {
  if (vendor(`NLSHAS${name}`, 'Exists', CUSTOM).value !== '1') assert.equal(vendor(`NLSMAKE${name}`, 'Create', CUSTOM).value, '1', `the custom locale ${CUSTOM} is created`);
}

/** Type `value` into the field `selector`, replacing what it holds. */
async function replaceText(page, selector, value) {
  await page.click(selector, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(selector, value);
}

// Mutation (Rule 19): post the copy to the screen's action route instead of `/api/ocupilot/locales` in `locale-list.page.ts` (rebuilt and redeployed) -> the
// sentence and the instance assertions go red.
test('Copy of a locale refuses a name the instance lists with the published sentence, then makes the custom locale the spec names', async () => {
  ensureCustom('COPY');
  const { context, page } = await signedInAt(browser, config, route('locales'), VIEWPORTS.wide);
  try {
    await answered(page);
    await selectRow(page, foundCurrent);
    assert.deepEqual(await menuEntry(page, STRINGS.auditDatabaseCopyConfirm), { disabled: false, reason: '' }, 'Copy is offered on any locale');
    await clickEntry(page, STRINGS.auditDatabaseCopyConfirm);
    await page.waitForSelector('[data-locale-copy-confirm]', { visible: true, timeout: config.navigationTimeoutMs });
    await replaceText(page, '[data-locale-copy-field="Name"]', CUSTOM);
    await page.click('[data-locale-copy-confirm]');
    await page.waitForSelector('[data-locale-copy-reason]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-locale-copy-reason]', (node) => node.textContent.trim()), STRINGS.localeRefusalCopyTaken, 'a name the instance lists is refused with the published sentence, in the dialog');
    await replaceText(page, '[data-locale-copy-field="Name"]', COPIED);
    await page.click('[data-locale-copy-confirm]');
    await page.waitForSelector('[data-locale-copy-confirm]', { hidden: true, timeout: config.navigationTimeoutMs });
    assert.equal(vendor('NLSHASCOPY', 'Exists', COPIED).value, '1', 'the instance holds the new locale');
    assert.equal(
      probe('NLSCOPYSAME', [
        `Set tSC=##class(Config.NLS.Locales).Get("${COPIED}",.p) Set tSC=##class(Config.NLS.Locales).Get("${foundCurrent}",.q)`,
        'Set result=($Get(p("DateFormat"))=$Get(q("DateFormat")))&&($Get(p("Currency"))=$Get(q("Currency")))&&($Get(p("CharacterSet"))=$Get(q("CharacterSet")))',
      ]).value,
      '1',
      'and it holds the definition of the locale it copies'
    );
    await selectRow(page, COPIED);
  } finally {
    await context.close();
    vendor('NLSGONECOPY', 'RemoveCustom', COPIED);
  }
});

// Mutation (Rule 19): post the add to the screen's action route instead of `/api/ocupilot/locale-properties` in `config-settings.page.ts` (rebuilt and redeployed) ->
// the instance assertion goes red.
test('Add table on a custom locale refuses a table it lists with the published sentence, then lists the table on the instance', async () => {
  ensureCustom('ADD');
  const { context, page } = await signedInAt(browser, config, `${route('locales/properties')}/${encodeURIComponent(CUSTOM)}`, VIEWPORTS.wide);
  try {
    await answered(page);
    await (await page.waitForSelector('.ocu-command-bar button.ocu-command-bar-primary', { visible: true, timeout: config.navigationTimeoutMs })).click();
    await page.waitForSelector('[data-locale-table-confirm]', { visible: true, timeout: config.navigationTimeoutMs });
    await replaceText(page, '[data-locale-table-field="Table"]', 'Unicode');
    await page.click('[data-locale-table-confirm]');
    await page.waitForSelector('[data-locale-table-reason]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-locale-table-reason]', (node) => node.textContent.trim()), STRINGS.localeRefusalTableTaken, 'a table the locale lists is refused with the published sentence, in the dialog');
    await replaceText(page, '[data-locale-table-field="Table"]', 'Latin2');
    await page.click('[data-locale-table-confirm]');
    await page.waitForSelector('[data-locale-table-confirm]', { hidden: true, timeout: config.navigationTimeoutMs });
    assert.equal(probe('NLSADDED', [`Set tSC=##class(Config.NLS.Locales).Get("${CUSTOM}",.p) Set result=$Data(p("PatternTables","Latin2"))`]).value, '1', 'the instance lists the table');
    // The list re-reads in place once the create is announced: the new row stands, marked as changed, once that read has landed.
    await page.waitForFunction(
      (rowSelector, wanted) => [...document.querySelectorAll(rowSelector)].some((row) => row.classList.contains('ocu-data-table-row-changed') && row.querySelectorAll('[role="gridcell"]')[1]?.textContent.trim().startsWith(wanted)),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      'PatternTables:Latin2'
    );
    await selectProperty(page, 'PatternTables:Latin2');
    assert.deepEqual(await menuEntry(page, STRINGS.localeRemoveTableAction), { disabled: false, reason: '' }, 'and the new row offers Remove table');
  } finally {
    await context.close();
  }
});

/** Record the files this browser is asked to save, without leaving the page. */
function captureDownloads(page) {
  return page.evaluate(() => {
    window.__ocuSaved = [];
    const create = URL.createObjectURL.bind(URL);
    let blob = null;
    URL.createObjectURL = (made) => {
      blob = made;
      return create(made);
    };
    const click = HTMLAnchorElement.prototype.click;
    HTMLAnchorElement.prototype.click = function () {
      if (this.download && blob !== null) {
        const kept = blob;
        const name = this.download;
        void kept.text().then((text) => window.__ocuSaved.push({ name, type: kept.type, text }));
        return;
      }
      click.call(this);
    };
  });
}

// Mutation (Rule 19): send the export to this browser on the server file's action in `locale-list.page.ts` (rebuilt and redeployed) -> no file is saved and this goes red.
test('Export of the current locale to this browser saves <locale>.xml holding its record', async () => {
  const { context, page } = await signedInAt(browser, config, route('locales'), VIEWPORTS.wide);
  try {
    await answered(page);
    await captureDownloads(page);
    await selectRow(page, foundCurrent);
    assert.deepEqual(await menuEntry(page, STRINGS.taskExportAction), { disabled: false, reason: '' }, 'Export is offered on any locale');
    await clickEntry(page, STRINGS.taskExportAction);
    await page.waitForSelector('app-explorer-export-dialog .ocu-dialog-title', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('app-explorer-export-dialog .ocu-dialog-title', (node) => node.textContent.trim()), STRINGS.localeExportTitle.replace('<locale>', foundCurrent), 'the dialog is titled by the locale');
    await page.click('input[data-explorer-export-destination="browser"]');
    await page.click('[data-explorer-export-confirm]');
    await page.waitForFunction(() => window.__ocuSaved.length === 1, { timeout: config.navigationTimeoutMs });
    const saved = await page.evaluate(() => window.__ocuSaved[0]);
    assert.equal(saved.name, `${foundCurrent}.xml`, 'the browser saves <locale>.xml');
    assert.equal(saved.type, 'application/xml');
    assert.ok(saved.text.includes(`<Name>${foundCurrent}</Name>`) && saved.text.includes('<LocalesDeepExport>'), 'the file is the vendor\'s export of that locale');
    await page.waitForFunction(
      (wanted) => document.querySelector('[data-locale-transfer-status]')?.textContent.trim() === wanted,
      { timeout: config.navigationTimeoutMs },
      STRINGS.localeExportSaved.replace('<locale>', foundCurrent).replace('<file>', `${foundCurrent}.xml`)
    );
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): drop the `TASK_IMPORT_ACTION_ID` registration in `locale-list.page.ts` (rebuilt and redeployed) -> the command bar draws no Import and this goes red.
test('Import opens its dialog, and a local file that holds only a locale InterSystems ships shows the ruled sentence and imports nothing', async () => {
  const folder = mkdtempSync(join(tmpdir(), 'ocu-locale-import-'));
  const { context, page } = await signedInAt(browser, config, route('locales'), VIEWPORTS.wide);
  try {
    await answered(page);
    await page.waitForFunction(
      (wanted) => [...document.querySelectorAll('.ocu-command-bar-action')].some((button) => button.textContent.trim() === wanted && button.getAttribute('aria-disabled') === null),
      { timeout: config.navigationTimeoutMs },
      STRINGS.actionImport
    );
    await page.evaluate((wanted) => [...document.querySelectorAll('.ocu-command-bar-action')].find((button) => button.textContent.trim() === wanted).click(), STRINGS.actionImport);
    await page.waitForSelector('app-explorer-import-dialog .ocu-dialog-title', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('app-explorer-import-dialog .ocu-dialog-title', (node) => node.textContent.trim()), STRINGS.localeImportTitle, 'the dialog is titled with the ruled words');
    assert.equal(await page.$eval('[data-explorer-import-replaces]', (node) => node.textContent.trim()), STRINGS.localeImportReplaces, 'and states what an import replaces');
    const local = join(folder, 'shipped.xml');
    writeFileSync(local, `<?xml version="1.0" encoding="UTF-8"?><LocalesDeepExport><LocalesExport><Locales><Name>${foundCurrent}</Name></Locales></LocalesExport></LocalesDeepExport>`, 'utf8');
    await page.click('input[data-explorer-import-source="local"]');
    await page.waitForSelector('input[data-explorer-import-file]', { timeout: config.navigationTimeoutMs });
    await (await page.$('input[data-explorer-import-file]')).uploadFile(local);
    await page.waitForFunction(() => document.querySelector('[data-explorer-import-confirm]')?.getAttribute('aria-disabled') === null, { timeout: config.navigationTimeoutMs });
    await page.click('[data-explorer-import-confirm]');
    await page.waitForSelector('[data-explorer-transfer-refusal]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-explorer-transfer-refusal]', (node) => node.textContent.trim()), STRINGS.localeRefusalImportEmpty, 'a file of shipped records alone is refused with the published sentence, in the dialog');
    assert.equal(storedCurrent().value, foundCurrent, 'and the current locale is as it was');
  } finally {
    await context.close();
    rmSync(folder, { recursive: true, force: true });
  }
});

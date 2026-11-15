/**
 * Stories 21.3 and 21.4 in a real browser, against the throwaway instance: Startup, Memory, Compatibility, SQL, SQL Shell, TSQL and ISQL
 * settings (AD-5, AD-29, AD-53).
 *
 * What it pins: each screen answers the navigation map and its rows before anything is read; Set value on `LineRecall` opens its dialog over
 * the row, the checkbox flips it, the instance stores the new value and the list shows it without a reload; the dialog over `NullSubscripts`
 * states the restart sentence and, canceled, sends nothing; a row that is shown and never changed (`DefaultPort`) draws Set value unavailable
 * with the published sentence and opens no dialog. The four SQL screens answer their rows; Set value on `SaveMAC` flips `Config.SQL` and the list
 * shows it; the dialog over `FastDistinct` states the purge sentence and, canceled, sends nothing; `DefaultSchema` and `EscapeCondition` draw
 * Set value unavailable.
 *
 * **It changes one compatibility setting and one SQL setting** through the shipped screens, so it runs on a throwaway only; the `after` hook puts
 * `LineRecall` and `SaveMAC` back to the values it found, whatever the tests answered.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/config-settings.browser-spec.mjs` (after `npm run build` and the bundle copied into the throwaway).
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
const NAME = 'LineRecall';
const SQL_NAME = 'SaveMAC';

let browser = null;
let found = '';
let foundSql = '';
let touched = false;

/** The setting `name` of `Config.Miscellaneous`, as the instance stores it. */
function stored(name) {
  const output = runIris(config.container, [
    'Set $NAMESPACE="%SYS"',
    'Do ##class(Config.Miscellaneous).Get(.p)',
    `Write "OCU-CFGGET-START:"_$Get(p("${name}"))_":OCU-CFGGET-END",!`,
  ]);
  return { value: markerValue(output, 'CFGGET'), output };
}

/** Put `LineRecall` back to `value`, answering the status of the write. */
function restore(value) {
  const output = runIris(config.container, [
    'Set $NAMESPACE="%SYS"',
    'Do ##class(Config.Miscellaneous).Get(.p)',
    `Set p("${NAME}")=${Number(value)}`,
    'Write "OCU-CFGPUT-START:"_$System.Status.IsOK(##class(Config.Miscellaneous).Modify(.p))_":OCU-CFGPUT-END",!',
  ]);
  return { value: markerValue(output, 'CFGPUT'), output };
}

/** The setting `name` of `Config.SQL`, as the instance stores it. */
function storedSql(name) {
  const output = runIris(config.container, [
    'Set $NAMESPACE="%SYS"',
    'Do ##class(Config.SQL).Get(.p)',
    `Write "OCU-SQLGET-START:"_$Get(p("${name}"))_":OCU-SQLGET-END",!`,
  ]);
  return { value: markerValue(output, 'SQLGET'), output };
}

/** Put `SaveMAC` back to `value`, answering the status of the write. */
function restoreSql(value) {
  const output = runIris(config.container, [
    'Set $NAMESPACE="%SYS"',
    'Do ##class(Config.SQL).Get(.p)',
    `Set p("${SQL_NAME}")=${Number(value)}`,
    'Write "OCU-SQLPUT-START:"_$System.Status.IsOK(##class(Config.SQL).Modify(.p))_":OCU-SQLPUT-END",!',
  ]);
  return { value: markerValue(output, 'SQLPUT'), output };
}

/** The screen has answered the navigation map and drew its rows. */
async function answered(page) {
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  await waitForRows(page, config.navigationTimeoutMs);
}

/** The first cell of every rendered body row. */
function names(page) {
  return page.$$eval(ROW_SELECTOR, (rows) => rows.map((row) => row.querySelector('[role="gridcell"]')?.textContent.trim() ?? ''));
}

/** Narrow the list to the rows naming `name`, then click that row on its second cell, which selects it. */
async function selectRow(page, name) {
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, name);
  await page.waitForFunction(
    (rowSelector, wanted) => [...document.querySelectorAll(rowSelector)].some((row) => row.querySelector('[role="gridcell"]')?.textContent.trim() === wanted),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name
  );
  await clickRowCentre(page, { text: name, cell: 2 });
}

/** Open the selected row's menu and answer its Set value entry, `aria-disabled` and its reason included. */
async function setValueEntry(page) {
  await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
  return page.evaluate((wanted) => {
    const item = [...document.querySelectorAll('[role="menu"] [role="menuitem"]')].find((entry) => entry.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted);
    if (item === undefined) return null;
    return { disabled: item.getAttribute('aria-disabled') === 'true', reason: item.querySelector('.ocu-data-table-menu-reason')?.textContent.trim() ?? '' };
  }, STRINGS.interopItemSettingSetAction);
}

/** Click the menu's Set value entry, which opens the dialog. */
async function clickSetValue(page) {
  await page.evaluate((wanted) => [...document.querySelectorAll('[role="menu"] [role="menuitem"]')].find((entry) => entry.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted).click(), STRINGS.interopItemSettingSetAction);
  await page.waitForSelector('[data-interop-setting-consequence]', { visible: true, timeout: config.navigationTimeoutMs });
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec changes a compatibility setting, so it runs only in a throwaway; ${config.container} is not one`);
  const read = stored(NAME);
  assert.match(read.value ?? '', /^[01]$/, `${NAME} reads 0 or 1 on the instance: ${read.output}`);
  found = read.value;
  const readSql = storedSql(SQL_NAME);
  assert.match(readSql.value ?? '', /^[01]$/, `${SQL_NAME} reads 0 or 1 on the instance: ${readSql.output}`);
  foundSql = readSql.value;
  touched = true;
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (touched && /-ci$/.test(config.container)) {
      const put = restore(found);
      assert.equal(put.value, '1', `${NAME} is put back to ${found}: ${put.output}`);
      assert.equal(stored(NAME).value, found, `and reads ${found} again`);
      const putSql = restoreSql(foundSql);
      assert.equal(putSql.value, '1', `${SQL_NAME} is put back to ${foundSql}: ${putSql.output}`);
      assert.equal(storedSql(SQL_NAME).value, foundSql, `and reads ${foundSql} again`);
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

test('each of the seven screens answers its rows before anything is read', async () => {
  for (const [screen, expected] of [
    ['startup-settings', ['ErrorPurge', 'ShutdownTimeout', 'DefaultPort']],
    ['memory-settings', ['errlog', 'history', 'bbsiz']],
    ['compatibility-settings', [NAME, 'NullSubscripts', 'Undefined']],
    ['sql-settings', [SQL_NAME, 'FastDistinct', 'LockTimeout']],
    ['sql-shell-settings', ['SelectMode', 'Path', 'EchoMode']],
    ['tsql-settings', ['DIALECT', 'ANSI_NULLS', 'TRACE']],
    ['isql-settings', ['DELIMIDENT', 'RESERVEDWORDPREFIX', 'FUNCTIONRETURNSSET']],
  ]) {
    const { context, page } = await signedInAt(browser, config, route(screen), VIEWPORTS.wide);
    try {
      await answered(page);
      await page.click(FILTER_SELECTOR, { clickCount: 3 });
      for (const name of expected) {
        await page.keyboard.press('Backspace');
        await page.type(FILTER_SELECTOR, name);
        await page.waitForFunction(
          (rowSelector, wanted) => [...document.querySelectorAll(rowSelector)].some((row) => row.querySelector('[role="gridcell"]')?.textContent.trim() === wanted),
          { timeout: config.navigationTimeoutMs },
          ROW_SELECTOR,
          name
        );
        assert.ok((await names(page)).includes(name), `${screen} lists ${name}`);
        await page.click(FILTER_SELECTOR, { clickCount: 3 });
      }
    } finally {
      await context.close();
    }
  }
});

test('Set value on LineRecall flips it on the instance, shown without a reload', async () => {
  const flipped = found === '1' ? '0' : '1';
  const { context, page } = await signedInAt(browser, config, route('compatibility-settings'), VIEWPORTS.wide);
  try {
    await answered(page);
    await page.evaluate(() => {
      window.__ocuNoReload = 'standing';
    });
    await selectRow(page, NAME);
    const entry = await setValueEntry(page);
    assert.deepEqual(entry, { disabled: false, reason: '' }, 'Set value is offered on a setting that may change');
    await clickSetValue(page);
    assert.equal(await page.$eval('[data-interop-setting-consequence]', (node) => node.textContent.trim()), '0 (off) or 1 (on).', 'the dialog states what the setting accepts, and no restart');
    await page.click('[data-interop-setting-checkbox]');
    await page.click('[data-interop-setting-confirm]');
    await page.waitForSelector('[data-interop-setting-confirm]', { hidden: true, timeout: config.navigationTimeoutMs });
    assert.equal(stored(NAME).value, flipped, `the instance stores ${flipped}`);
    await page.waitForFunction(
      (rowSelector, wanted, value) => [...document.querySelectorAll(rowSelector)].some((row) => {
        const cells = row.querySelectorAll('[role="gridcell"]');
        // The row the instance has just changed carries its marker in its first cell, so it is matched by its start.
        return cells[0]?.textContent.trim().startsWith(wanted) && cells[1]?.textContent.trim() === value;
      }),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      NAME,
      flipped
    );
    assert.equal(await page.evaluate(() => window.__ocuNoReload), 'standing', 'the list re-read without the page reloading');
    assert.equal(await page.$('[data-config-setting-restart]'), null, 'and a setting that needs no restart states none');
  } finally {
    await context.close();
  }
});

test('the dialog over NullSubscripts states the restart sentence, and canceled sends nothing', async () => {
  const before = stored('NullSubscripts').value;
  const { context, page } = await signedInAt(browser, config, route('compatibility-settings'), VIEWPORTS.wide);
  try {
    await answered(page);
    await selectRow(page, 'NullSubscripts');
    assert.equal((await setValueEntry(page))?.disabled, false, 'Set value is offered');
    await clickSetValue(page);
    const statement = await page.$eval('[data-interop-setting-consequence]', (node) => node.textContent.trim());
    assert.ok(statement.endsWith(STRINGS.encryptionStartupRestart), `the dialog states the restart sentence: ${statement}`);
    await page.evaluate((wanted) => [...document.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent.trim() === wanted).click(), STRINGS.actionCancel);
    await page.waitForSelector('[data-interop-setting-consequence]', { hidden: true, timeout: config.navigationTimeoutMs });
    assert.equal(stored('NullSubscripts').value, before, 'nothing was sent: the setting reads as before');
  } finally {
    await context.close();
  }
});

test('a row that is shown and never changed draws Set value unavailable with the published sentence, and opens no dialog', async () => {
  const { context, page } = await signedInAt(browser, config, route('startup-settings'), VIEWPORTS.wide);
  try {
    await answered(page);
    await selectRow(page, 'DefaultPort');
    const entry = await setValueEntry(page);
    assert.deepEqual(entry, { disabled: true, reason: STRINGS.configRefusalReadOnly }, 'Set value is unavailable, naming why');
    await page.evaluate((wanted) => [...document.querySelectorAll('[role="menu"] [role="menuitem"]')].find((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted).click(), STRINGS.interopItemSettingSetAction);
    await new Promise((resolve) => setTimeout(resolve, 500));
    assert.equal(await page.$('[data-interop-setting-consequence]'), null, 'and pressing it opens no dialog');
  } finally {
    await context.close();
  }
});

test('Set value on SaveMAC flips it in Config.SQL, shown without a reload, and states no purge', async () => {
  const flipped = foundSql === '1' ? '0' : '1';
  const { context, page } = await signedInAt(browser, config, route('sql-settings'), VIEWPORTS.wide);
  try {
    await answered(page);
    await page.evaluate(() => {
      window.__ocuNoReload = 'standing';
    });
    await selectRow(page, SQL_NAME);
    assert.deepEqual(await setValueEntry(page), { disabled: false, reason: '' }, 'Set value is offered on a setting that may change');
    await clickSetValue(page);
    assert.equal(await page.$eval('[data-interop-setting-consequence]', (node) => node.textContent.trim()), '0 (off) or 1 (on).', 'the dialog states what the setting accepts, and no purge');
    await page.click('[data-interop-setting-checkbox]');
    await page.click('[data-interop-setting-confirm]');
    await page.waitForSelector('[data-interop-setting-confirm]', { hidden: true, timeout: config.navigationTimeoutMs });
    assert.equal(storedSql(SQL_NAME).value, flipped, `the instance stores ${flipped}`);
    await page.waitForFunction(
      (rowSelector, wanted, value) => [...document.querySelectorAll(rowSelector)].some((row) => {
        const cells = row.querySelectorAll('[role="gridcell"]');
        return cells[0]?.textContent.trim().startsWith(wanted) && cells[1]?.textContent.trim() === value;
      }),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      SQL_NAME,
      flipped
    );
    assert.equal(await page.evaluate(() => window.__ocuNoReload), 'standing', 'the list re-read without the page reloading');
    assert.equal(await page.$('[data-config-setting-purge]'), null, 'and a setting that does not purge states no purge');
  } finally {
    await context.close();
  }
});

test('the dialog over FastDistinct states the purge sentence, and canceled sends nothing', async () => {
  const before = storedSql('FastDistinct').value;
  const { context, page } = await signedInAt(browser, config, route('sql-settings'), VIEWPORTS.wide);
  try {
    await answered(page);
    await selectRow(page, 'FastDistinct');
    assert.equal((await setValueEntry(page))?.disabled, false, 'Set value is offered');
    await clickSetValue(page);
    const statement = await page.$eval('[data-interop-setting-consequence]', (node) => node.textContent.trim());
    assert.ok(statement.endsWith(STRINGS.configSettingPurge), `the dialog states the purge sentence: ${statement}`);
    await page.click('[data-interop-setting-checkbox]');
    await page.evaluate((wanted) => [...document.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent.trim() === wanted).click(), STRINGS.actionCancel);
    await page.waitForSelector('[data-interop-setting-consequence]', { hidden: true, timeout: config.navigationTimeoutMs });
    assert.equal(storedSql('FastDistinct').value, before, 'nothing was sent: the setting reads as before, although the value was changed in the dialog');
  } finally {
    await context.close();
  }
});

test('DefaultSchema and the shell EscapeCondition draw Set value unavailable with the published sentence', async () => {
  for (const [screen, name] of [
    ['sql-settings', 'DefaultSchema'],
    ['sql-shell-settings', 'EscapeCondition'],
  ]) {
    const { context, page } = await signedInAt(browser, config, route(screen), VIEWPORTS.wide);
    try {
      await answered(page);
      await selectRow(page, name);
      assert.deepEqual(await setValueEntry(page), { disabled: true, reason: STRINGS.configRefusalReadOnly }, `Set value is unavailable on ${name}, naming why`);
      await page.evaluate((wanted) => [...document.querySelectorAll('[role="menu"] [role="menuitem"]')].find((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted).click(), STRINGS.interopItemSettingSetAction);
      await new Promise((resolve) => setTimeout(resolve, 500));
      assert.equal(await page.$('[data-interop-setting-consequence]'), null, `and pressing it opens no dialog over ${name}`);
    } finally {
      await context.close();
    }
  }
});

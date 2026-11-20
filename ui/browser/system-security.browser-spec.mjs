/**
 * Story 21.10 in a real browser, against the throwaway instance: System-wide security (AD-5, AD-29, AD-35, AD-53).
 *
 * What it pins: the Security side bar lists System-wide security at its declared index and its entry opens the screen; the screen answers the
 * navigation map and the roster's rows, and none of the properties the roster leaves out (`PrivateJWKS`, `SMTPPassword`); Set value on
 * `InactiveLimit` opens its dialog over the row with the accepted range and the published consequence sentence, a value outside the range
 * is refused in the dialog and sent nowhere, the instance stores a valid value and the list shows it without a reload; canceled, the dialog
 * sends nothing; a row that is shown and never changed (`RequiredRole`) draws Set value unavailable with the published sentence and opens no dialog.
 *
 * **It changes one system-wide security parameter** through the shipped screen, so it runs on a throwaway only; the `after` hook puts
 * `InactiveLimit` back to the value it found, whatever the tests answered.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/system-security.browser-spec.mjs` (after `npm run build` and the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { signedInAt } from './panel-spec.mjs';
import { assertDrawnAtDeclaredIndex, sideBarLabels } from './side-bar-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const ROUTE = '/ocupilot/security/system-security';
const NAME = 'InactiveLimit';

let browser = null;
let found = '';
let touched = false;

/** The parameter `name` of `Security.System`, as the instance stores it. */
function stored(name) {
  const output = runIris(config.container, [
    'Set $NAMESPACE="%SYS"',
    'Do ##class(Security.System).Get("SYSTEM",.p)',
    `Write "OCU-SECGET-START:"_$Get(p("${name}"))_":OCU-SECGET-END",!`,
  ]);
  return { value: markerValue(output, 'SECGET'), output };
}

/** Put `InactiveLimit` back to `value`, answering the status of the write. */
function restore(value) {
  const output = runIris(config.container, [
    'Set $NAMESPACE="%SYS"',
    `Set p("${NAME}")=${Number(value)}`,
    'Write "OCU-SECPUT-START:"_$System.Status.IsOK(##class(Security.System).Modify("SYSTEM",.p))_":OCU-SECPUT-END",!',
  ]);
  return { value: markerValue(output, 'SECPUT'), output };
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

/** Replace the dialog's value with `value`. */
async function typeValue(page, value) {
  await page.click('[data-interop-setting-value]', { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type('[data-interop-setting-value]', value);
}

/** Press the dialog's Cancel. */
async function cancel(page) {
  await page.evaluate((wanted) => [...document.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent.trim() === wanted).click(), STRINGS.actionCancel);
  await page.waitForSelector('[data-interop-setting-consequence]', { hidden: true, timeout: config.navigationTimeoutMs });
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec changes a system-wide security parameter, so it runs only in a throwaway; ${config.container} is not one`);
  const read = stored(NAME);
  assert.match(read.value ?? '', /^[0-9]+$/, `${NAME} reads a whole number on the instance: ${read.output}`);
  found = read.value;
  touched = true;
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (touched && /-ci$/.test(config.container)) {
      const put = restore(found);
      assert.equal(put.value, '1', `${NAME} is put back to ${found}: ${put.output}`);
      assert.equal(stored(NAME).value, found, `and reads ${found} again`);
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

// Mutation (Rule 19): drop the entry from the Security area's declared list, regenerate, rebuild and redeploy -> the label assertion goes red.
test('Security lists System-wide security at its declared index and its entry opens the screen', async () => {
  const { context, page } = await signedInAt(browser, config, '/ocupilot/security/ssl?ns=HSCUSTOM');
  try {
    if ((await page.$('app-side-bar nav.ocu-side-bar')) === null) {
      await page.keyboard.down('Control');
      await page.keyboard.press('b');
      await page.keyboard.up('Control');
    }
    await page.waitForSelector('app-side-bar nav.ocu-side-bar', { timeout: config.navigationTimeoutMs });
    const labels = await page.$$eval('app-side-bar .ocu-side-bar-item .ocu-side-bar-label', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(labels, sideBarLabels('security'), 'the side bar lists its entries in their declared order');
    assertDrawnAtDeclaredIndex(labels, 'security', STRINGS.systemSecuritySettingsLabel);
    await page.evaluate((label) => {
      Array.from(document.querySelectorAll('app-side-bar .ocu-side-bar-item')).find((item) => item.textContent.trim() === label).click();
    }, STRINGS.systemSecuritySettingsLabel);
    await page.waitForFunction(() => new URL(window.location.href).pathname.endsWith('/security/system-security'), { timeout: config.navigationTimeoutMs });
  } finally {
    await context.close();
  }
});

test('the screen answers the roster rows and none of the key material or the mail password', async () => {
  const { context, page } = await signedInAt(browser, config, ROUTE, VIEWPORTS.wide);
  try {
    await answered(page);
    await page.click(FILTER_SELECTOR, { clickCount: 3 });
    for (const name of [NAME, 'InvalidLoginLimit', 'PasswordPattern', 'RequiredRole']) {
      await page.keyboard.press('Backspace');
      await page.type(FILTER_SELECTOR, name);
      await page.waitForFunction(
        (rowSelector, wanted) => [...document.querySelectorAll(rowSelector)].some((row) => row.querySelector('[role="gridcell"]')?.textContent.trim() === wanted),
        { timeout: config.navigationTimeoutMs },
        ROW_SELECTOR,
        name
      );
      assert.ok((await names(page)).includes(name), `System-wide security lists ${name}`);
      await page.click(FILTER_SELECTOR, { clickCount: 3 });
    }
    for (const hidden of ['PrivateJWKS', 'SMTPPassword']) {
      await page.keyboard.press('Backspace');
      await page.type(FILTER_SELECTOR, hidden);
      await new Promise((resolve) => setTimeout(resolve, 400));
      assert.ok(!(await names(page)).includes(hidden), `and does not list ${hidden}`);
      await page.click(FILTER_SELECTOR, { clickCount: 3 });
    }
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): drop the consequence sentence from the page's dialog statement for this screen -> the statement assertion goes red.
test('Set value on InactiveLimit states the range and the consequence, refuses a value outside the range, and stores a valid one without a reload', async () => {
  const next = found === '88' ? '87' : '88';
  const { context, page } = await signedInAt(browser, config, ROUTE, VIEWPORTS.wide);
  try {
    await answered(page);
    await page.evaluate(() => {
      window.__ocuNoReload = 'standing';
    });
    await selectRow(page, NAME);
    assert.deepEqual(await setValueEntry(page), { disabled: false, reason: '' }, 'Set value is offered on a parameter that may change');
    await clickSetValue(page);
    const statement = await page.$eval('[data-interop-setting-consequence]', (node) => node.textContent.trim());
    assert.equal(statement, `A whole number from 0 to 365. ${STRINGS.systemSecuritySetConsequence}`, 'the dialog states what the parameter accepts and what a change reaches');
    await typeValue(page, '366');
    await page.click('[data-interop-setting-confirm]');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]')?.textContent?.includes('This setting does not accept that value.'), { timeout: config.navigationTimeoutMs });
    assert.equal(stored(NAME).value, found, 'a value over the limit is refused and the instance still reads the value it held');
    await typeValue(page, next);
    await page.click('[data-interop-setting-confirm]');
    await page.waitForSelector('[data-interop-setting-confirm]', { hidden: true, timeout: config.navigationTimeoutMs });
    assert.equal(stored(NAME).value, next, `the instance stores ${next}`);
    await page.waitForFunction(
      (rowSelector, wanted, value) => [...document.querySelectorAll(rowSelector)].some((row) => {
        const cells = row.querySelectorAll('[role="gridcell"]');
        return cells[0]?.textContent.trim().startsWith(wanted) && cells[1]?.textContent.trim() === value;
      }),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      NAME,
      next
    );
    assert.equal(await page.evaluate(() => window.__ocuNoReload), 'standing', 'the list re-read without the page reloading');
  } finally {
    await context.close();
  }
});

test('canceled, the dialog sends nothing', async () => {
  const before = stored(NAME).value;
  const { context, page } = await signedInAt(browser, config, ROUTE, VIEWPORTS.wide);
  try {
    await answered(page);
    await selectRow(page, NAME);
    assert.equal((await setValueEntry(page))?.disabled, false, 'Set value is offered');
    await clickSetValue(page);
    await typeValue(page, '77');
    await cancel(page);
    assert.equal(stored(NAME).value, before, 'nothing was sent: the parameter reads as before, although the value was typed in the dialog');
  } finally {
    await context.close();
  }
});

test('a row that is shown and never changed draws Set value unavailable with the published sentence, and opens no dialog', async () => {
  const { context, page } = await signedInAt(browser, config, ROUTE, VIEWPORTS.wide);
  try {
    await answered(page);
    await selectRow(page, 'RequiredRole');
    assert.deepEqual(await setValueEntry(page), { disabled: true, reason: STRINGS.configRefusalReadOnly }, 'Set value is unavailable, naming why');
    await page.evaluate((wanted) => [...document.querySelectorAll('[role="menu"] [role="menuitem"]')].find((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted).click(), STRINGS.interopItemSettingSetAction);
    await new Promise((resolve) => setTimeout(resolve, 500));
    assert.equal(await page.$('[data-interop-setting-consequence]'), null, 'and pressing it opens no dialog');
  } finally {
    await context.close();
  }
});

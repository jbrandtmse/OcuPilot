/**
 * Story 21.13 in a real browser, against the throwaway instance: System DDL mappings and User DDL mappings (AD-5, AD-29, AD-53, AD-55).
 *
 * What it pins: both screens answer the navigation map and their entries before anything is counted; the system list offers no New mapping; New
 * mapping on the user list creates `ZZOCU<n>` and the list shows it without a reload; a held name shows the published sentence in the dialog and a name the
 * instance cannot hold shows its own sentence under the field; Set value changes the datatype; Delete types the name, states the published
 * consequence, and removes it.
 *
 * **It creates, changes and deletes one user DDL mapping** through the shipped screens, so it runs on a throwaway only; the `after` hook deletes
 * every `ZZOCU` mapping it left, whatever the tests answered.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/ddl-mappings.browser-spec.mjs` (after `npm run build` and the bundle copied into the throwaway).
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
const MARKER = `ZZOCU${process.pid}`;
const FIRST_TYPE = '%Library.String(MAXLEN=%1)';
const SECOND_TYPE = '%Library.Integer';

let browser = null;
let touched = false;

/** The datatype of the user mapping `name` as the instance stores it, or `<absent>`. */
function stored(name) {
  const output = runIris(config.container, [
    'Set $NAMESPACE="%SYS"',
    `If '##class(Config.SqlUserDatatypes).Exists("${name}") { Write "OCU-DDLGET-START:<absent>:OCU-DDLGET-END",! Halt }`,
    `Do ##class(Config.SqlUserDatatypes).Get("${name}",.p)`,
    'Write "OCU-DDLGET-START:"_$Get(p("Datatype"))_":OCU-DDLGET-END",!',
  ]);
  return { value: markerValue(output, 'DDLGET'), output };
}

/** Make the user mapping `name` hold `type` through the vendor's own calls, whatever it held before. */
function seed(name, type) {
  const output = runIris(config.container, [
    'Set $NAMESPACE="%SYS"',
    `Do ##class(Config.SqlUserDatatypes).Delete("${name}")`,
    `Set p("Datatype")="${type}"`,
    `Set sc=##class(Config.SqlUserDatatypes).Create("${name}",.p)`,
    'Write "OCU-DDLSEED-START:"_sc_":OCU-DDLSEED-END",!',
  ]);
  return { value: markerValue(output, 'DDLSEED'), output };
}

/** Delete every user mapping this run named, answering how many remain. */
function sweep() {
  const output = runIris(config.container, [
    'Set $NAMESPACE="%SYS"',
    `Do ##class(Config.SqlUserDatatypes).Delete("${MARKER}")`,
    `Write "OCU-DDLSWEEP-START:"_##class(Config.SqlUserDatatypes).Exists("${MARKER}")_":OCU-DDLSWEEP-END",!`,
  ]);
  return { value: markerValue(output, 'DDLSWEEP'), output };
}

/** The first system mapping's name, as the instance lists it. */
function firstSystemName() {
  const output = runIris(config.container, [
    'Set $NAMESPACE="%SYS"',
    'Set rs=##class(%ResultSet).%New("Config.SqlSysDatatypes:List")',
    'Set sc=rs.Execute("*")',
    'Set n="" If rs.Next() Set n=rs.Get("Name")',
    'Write "OCU-DDLFIRST-START:"_n_":OCU-DDLFIRST-END",!',
  ]);
  return { value: markerValue(output, 'DDLFIRST'), output };
}

/** The screen has answered the navigation map. */
async function answered(page) {
  await waitForMapAnswered(page, config.navigationTimeoutMs);
}

/** The first cell of every rendered body row. */
function names(page) {
  return page.$$eval(ROW_SELECTOR, (rows) => rows.map((row) => row.querySelector('[role="gridcell"]')?.textContent.trim() ?? ''));
}

/** Narrow the list to the rows naming `name`, wait for that row, and click its second cell, which selects it. */
async function selectRow(page, name) {
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, name);
  await page.waitForFunction(
    (rowSelector, wanted) => [...document.querySelectorAll(rowSelector)].some((row) => row.querySelector('[role="gridcell"]')?.textContent.trim().startsWith(wanted)),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name
  );
  await clickRowCentre(page, { index: 0, cell: 1 });
}

/** Click the selected row's menu entry labelled `label`. */
async function menuClick(page, label) {
  await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
  await page.evaluate((wanted) => {
    [...document.querySelectorAll('[role="menu"] [role="menuitem"]')].find((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted).click();
  }, label);
}

async function fill(page, selector, value) {
  await page.click(selector, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  if (value !== '') await page.type(selector, value);
}

const field = (name) => `[data-ddl-mapping-field="${name}"]`;

/** Open the New mapping dialog from the command bar. */
async function openNew(page) {
  await (await page.waitForSelector('.ocu-command-bar button.ocu-command-bar-primary', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector(field('Name'), { visible: true, timeout: config.navigationTimeoutMs });
}

/** Wait for the open dialog to go. */
async function dialogClosed(page) {
  await page.waitForSelector('[role="dialog"]', { hidden: true, timeout: config.navigationTimeoutMs });
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec creates a DDL mapping, so it runs only in a throwaway; ${config.container} is not one`);
  const swept = sweep();
  assert.equal(swept.value, '0', `an earlier run's mapping is removed: ${swept.output}`);
  touched = true;
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (touched && /-ci$/.test(config.container)) {
      const swept = sweep();
      assert.equal(swept.value, '0', `the mapping this run named is gone: ${swept.output}`);
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

test('both screens answer their entries before anything is counted, and the system list offers no New mapping', async () => {
  const first = firstSystemName();
  assert.ok((first.value ?? '') !== '', `the instance lists a system mapping: ${first.output}`);
  const system = await signedInAt(browser, config, route('system-ddl-mappings'), VIEWPORTS.wide);
  try {
    await answered(system.page);
    await waitForRows(system.page, config.navigationTimeoutMs);
    assert.ok((await names(system.page)).length > 0, 'the system list draws rows');
    await system.page.click(FILTER_SELECTOR, { clickCount: 3 });
    await system.page.type(FILTER_SELECTOR, first.value);
    await system.page.waitForFunction(
      (rowSelector, wanted) => [...document.querySelectorAll(rowSelector)].some((row) => row.querySelector('[role="gridcell"]')?.textContent.trim() === wanted),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      first.value
    );
    assert.equal(await system.page.$('.ocu-command-bar button.ocu-command-bar-primary'), null, 'the system list offers no New mapping');
  } finally {
    await system.context.close();
  }
  const user = await signedInAt(browser, config, route('user-ddl-mappings'), VIEWPORTS.wide);
  try {
    await answered(user.page);
    assert.equal(await user.page.$eval('.ocu-command-bar button.ocu-command-bar-primary', (node) => node.textContent.trim()), STRINGS.ddlMappingNewAction, 'the user list offers New mapping');
  } finally {
    await user.context.close();
  }
});

test('New mapping creates a user mapping, a held name and a name the instance cannot hold are refused in the dialog, and the list shows the mapping without a reload', async () => {
  const { context, page } = await signedInAt(browser, config, route('user-ddl-mappings'), VIEWPORTS.wide);
  try {
    await answered(page);
    await page.evaluate(() => {
      window.__ocuNoReload = 'standing';
    });
    await openNew(page);
    assert.equal(await page.$eval('[role="dialog"] .ocu-dialog-title', (node) => node.textContent.trim()), STRINGS.ddlMappingDialogTitle, 'the dialog is titled with the published words');
    await fill(page, field('Name'), 'ZZ*OCU');
    await fill(page, field('Value'), FIRST_TYPE);
    await page.click('[data-ddl-mapping-confirm]');
    await page.waitForSelector('[data-ddl-mapping-violation="Name"]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-ddl-mapping-violation="Name"]', (node) => node.textContent.trim()), STRINGS.configMappingName, 'a name the instance cannot hold shows its sentence under the field');
    assert.equal(stored('ZZ*OCU').value, '<absent>', 'and nothing is stored');
    await fill(page, field('Name'), MARKER);
    await page.click('[data-ddl-mapping-confirm]');
    await dialogClosed(page);
    assert.equal(stored(MARKER).value, FIRST_TYPE, 'the instance stores the mapping with what was typed');
    await selectRow(page, MARKER);
    assert.deepEqual((await names(page)).filter((name) => name.startsWith(MARKER)).length, 1, 'and the list shows it');
    assert.equal(await page.evaluate(() => window.__ocuNoReload), 'standing', 'without the page reloading');
    await openNew(page);
    await fill(page, field('Name'), MARKER);
    await fill(page, field('Value'), SECOND_TYPE);
    await page.click('[data-ddl-mapping-confirm]');
    await page.waitForSelector('[data-ddl-mapping-reason]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-ddl-mapping-reason]', (node) => node.textContent.trim()), STRINGS.configMappingTaken, 'a held name shows the published sentence in the dialog');
    assert.equal(stored(MARKER).value, FIRST_TYPE, 'and leaves the held mapping as it was');
    await page.evaluate((wanted) => [...document.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent.trim() === wanted).click(), STRINGS.actionCancel);
    await dialogClosed(page);
  } finally {
    await context.close();
  }
});

test('Set value changes the datatype, and Delete types the name, states the published consequence and removes the mapping', async () => {
  touched = true;
  assert.equal(seed(MARKER, FIRST_TYPE).value, '1', 'the mapping this test changes is made by the test, through the vendor, before the screen loads');
  const { context, page } = await signedInAt(browser, config, route('user-ddl-mappings'), VIEWPORTS.wide);
  try {
    await answered(page);
    await waitForRows(page, config.navigationTimeoutMs);
    await selectRow(page, MARKER);
    await menuClick(page, STRINGS.interopItemSettingSetAction);
    await page.waitForSelector('[data-interop-setting-value]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-interop-setting-consequence]', (node) => node.textContent.trim()), STRINGS.configAcceptsDatatype, 'the dialog states what a datatype is held to');
    await fill(page, '[data-interop-setting-value]', SECOND_TYPE);
    await page.click('[data-interop-setting-confirm]');
    await page.waitForSelector('[data-interop-setting-confirm]', { hidden: true, timeout: config.navigationTimeoutMs });
    assert.equal(stored(MARKER).value, SECOND_TYPE, 'the instance stores the new datatype');
    await selectRow(page, MARKER);
    await menuClick(page, STRINGS.actionDelete);
    await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-typed-name-consequence', (node) => node.textContent.trim()), STRINGS.configMappingDelete, 'Delete states the published consequence');
    await page.type('.ocu-typed-name-field', MARKER);
    await page.keyboard.press('Enter');
    await dialogClosed(page);
    await page.waitForFunction(
      (rowSelector, wanted) => ![...document.querySelectorAll(rowSelector)].some((row) => row.querySelector('[role="gridcell"]')?.textContent.trim().startsWith(wanted)),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      MARKER
    );
    assert.equal(stored(MARKER).value, '<absent>', 'the mapping is gone from the instance, and from the list');
  } finally {
    await context.close();
  }
});

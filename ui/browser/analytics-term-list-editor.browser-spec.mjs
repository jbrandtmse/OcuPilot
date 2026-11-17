/**
 * Story 24.2 in a real browser, against the throwaway instance: Analytics' Term lists and their entries, with their New term list, Edit term
 * list, Delete, Add entry, Change entry and Remove entry actions (AD-5, AD-8, AD-29, AD-53, AD-55, AD-65).
 *
 * What it pins, in `USER`, with lists named by this spec's own marker: New term list creates a list with a caption, a field and the hide-value
 * flag, which the list shows and the vendor reads back; Edit term list opens on what the instance holds and a changed caption shows in the row;
 * Add entry writes an entry with its field value, which the entries list shows joined as `Region: West` and `%Lookup` answers; Change entry opens
 * on the row's values and the new value shows; Remove entry asks for the key typed and states its consequence; and Delete asks for the list's
 * name typed, states its consequence, and the list leaves. Story 24.10 adds the transfers: Export writes the list to a server file, which Import
 * reads back after the list is deleted, with the same header, fields and values; Export to this browser saves `<name>.csv`, which Import reads
 * back from the file this computer holds; and Copy term list makes a second list equal to the source, refusing a name already held.
 *
 * **It turns analytics on for `USER` and writes term lists there** through `OcuPilot.Test.AnalyticsProbe`, so it runs on a throwaway only; the
 * `after` hook removes every marked list and restores `USER`'s flags, whatever the tests answered.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/analytics-term-list-editor.browser-spec.mjs` (after `npm run build` and the bundle copied into the
 * throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const PROBE = 'OcuPilot.Test.AnalyticsProbe';
const EDIT = 'OcuPilot.Test.AnalyticsTermListEdit';
const TRANSFER = 'OcuPilot.Test.AnalyticsTermListTransfer';
const FILES = 'OcuPilot.Test.ExplorerTransferProbe';
const MARKER = 'OcuProbeTL24B';
const NEW = `${MARKER}New`;
const EXISTING = `${MARKER}Held`;
const LISTS = '/ocupilot/analytics/term-lists?ns=USER';
const ENTRIES = (name) => `/ocupilot/analytics/term-lists/entries/${encodeURIComponent(name)}?ns=USER`;

let browser = null;
let created = false;
let localDirectory = '';

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** The vendor's value of the entry `key` of `list` under `field` (the entry's own when empty), read in `USER`. */
function lookup(list, key, field = '') {
  return probe('TLLOOK', `##class(${EDIT}).Lookup("${list}","${key}","${field}")`).value;
}

/** Every body row's cells, each as its trimmed text. */
function allRows(page) {
  return page.evaluate(
    (rowSelector) => Array.from(document.querySelectorAll(rowSelector)).map((row) => Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim())),
    ROW_SELECTOR
  );
}

/** Wait until a row whose first cell starts with `name` carries `text` in its cell `column`. */
function rowReads(page, name, column, text) {
  return page.waitForFunction(
    (rowSelector, wanted, at, expected) => {
      const row = Array.from(document.querySelectorAll(rowSelector)).find((candidate) => candidate.querySelector('[role="gridcell"]')?.textContent.trim().startsWith(wanted));
      return row?.querySelectorAll('[role="gridcell"]')[at]?.textContent.trim() === expected;
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name,
    column,
    text
  );
}

/** Wait until no row's first cell starts with `name`. */
function rowGone(page, name) {
  return page.waitForFunction(
    (rowSelector, wanted) => !Array.from(document.querySelectorAll(rowSelector)).some((row) => row.querySelector('[role="gridcell"]')?.textContent.trim().startsWith(wanted)),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name
  );
}

/** The screen has answered the navigation map and drawn its rows. */
async function answered(page) {
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  await waitForRows(page, config.navigationTimeoutMs);
}

/** Replace the text of the field `selector` with `value`. */
async function fill(page, selector, value) {
  await page.click(selector, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  if (value !== '') await page.type(selector, value);
}

/** Open the primary action's dialog on the current list, and answer its heading. */
async function openPrimary(page, selector) {
  await (await page.waitForSelector('.ocu-command-bar button.ocu-command-bar-primary', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector(selector, { visible: true, timeout: config.navigationTimeoutMs });
  return page.$eval('[role="dialog"] .ocu-dialog-title', (node) => node.textContent.trim());
}

/** The first cell's whole text of the row whose first cell starts with `prefix`: a row the instance has just changed carries its marker and read-back there. */
function firstCell(page, prefix) {
  return page.evaluate(
    (rowSelector, wanted) => Array.from(document.querySelectorAll(rowSelector)).map((row) => row.querySelector('[role="gridcell"]')?.textContent.trim()).find((text) => text?.startsWith(wanted)),
    ROW_SELECTOR,
    prefix
  );
}

/** Select the row whose first cell starts with `prefix`, click its cell `cell`, open its menu and choose the entry labeled `label`; answers the menu's labels. */
async function rowAction(page, prefix, cell, label) {
  await clickRowCentre(page, { text: await firstCell(page, prefix), cell });
  await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
  const labels = await page.$$eval('[role="menu"] [role="menuitem"] .ocu-data-table-menu-label', (items) => items.map((item) => item.textContent.trim()));
  assert.ok(labels.includes(label), `the row menu offers ${label}; it offers ${JSON.stringify(labels)}`);
  await page.evaluate((wanted) => {
    Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'))
      .find((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted)
      .click();
  }, label);
  return labels;
}

/** Confirm the dialog that stands with its primary button and wait for it to close. */
async function confirmDialog(page, selector) {
  await page.click(selector);
  await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
}

/** The open typed-name dialog's consequence, with the name typed and confirmed. */
async function typedName(page, name) {
  await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
  const consequence = await page.$eval('.ocu-typed-name-consequence', (node) => node.textContent.trim());
  await page.type('.ocu-typed-name-field', name);
  await page.keyboard.press('Enter');
  await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
  return consequence;
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec turns analytics on in USER and writes term lists there, so it runs only in a throwaway; ${config.container} is not one`);
  const removed = probe('TLCLEAN', `$System.Status.IsOK(##class(${PROBE}).Remove())`);
  assert.equal(removed.value, '1', `an earlier run's probe is removed: ${removed.output}`);
  created = true;
  const enabled = probe('TLENABLE', `$System.Status.IsOK(##class(${PROBE}).Enable())`);
  assert.equal(enabled.value, '1', `analytics is turned on for USER: ${enabled.output}`);
  runIris(config.container, [`Do ##class(${EDIT}).Arrange("${EXISTING}")`]);
  assert.ok(probe('TLARRANGED', `##class(${EDIT}).Marked()`).value.includes(EXISTING.toUpperCase()), 'a list is arranged so the screen has rows');
  runIris(config.container, [`Do ##class(${FILES}).RemoveDirectory()`, `Do ##class(${FILES}).MakeDirectory()`]);
  localDirectory = mkdtempSync(join(tmpdir(), 'epic-24-2410-'));
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (localDirectory !== '') rmSync(localDirectory, { recursive: true, force: true });
    if (created && /-ci$/.test(config.container)) {
      runIris(config.container, [`Do ##class(${FILES}).RemoveDirectory()`]);
      probe('TLSWEEP', `##class(${EDIT}).Sweep()`);
      const removed = probe('TLGONE', `$System.Status.IsOK(##class(${PROBE}).Remove())_##class(${PROBE}).Gone()_(##class(${EDIT}).Marked()="")`);
      assert.equal(removed.value, '111', `the probe and the marked lists are removed and USER is left as found: ${removed.output}`);
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

// AC1, AC2, AC5. Mutation (Rule 19): drop `%SetValue`'s field argument in `AnalyticsPort.VendorTermListSetValue` (reload the class) -> the Region leg
// goes red; send `FieldValues: []` from the entry dialog's add in term-list-entry-dialog.ts, rebuild and redeploy -> the Region leg goes red; drop the
// entries' `TYPED_NAME_ROWS` entry in screen-action-handler.ts, rebuild and redeploy -> the key typed for Remove entry is refused.
test('AC1, AC2: a list is created, edited and deleted, and an entry added, changed and removed, from the two screens', async () => {
  const { context, page } = await signedInAt(browser, config, LISTS, VIEWPORTS.wide);
  try {
    await answered(page);
    assert.equal(await openPrimary(page, '[data-term-list-field="Name"]'), STRINGS.analyticsTermListNewAction, 'New term list opens its dialog');
    await fill(page, '[data-term-list-field="Name"]', NEW);
    await fill(page, '[data-term-list-field="Caption"]', 'First caption');
    await fill(page, '[data-term-list-field="Fields"]', 'Region');
    await page.click('[data-term-list-hide]');
    await confirmDialog(page, '[data-term-list-confirm]');
    await rowReads(page, NEW, 1, 'First caption');
    assert.equal(probe('TLNODE', `$Get(^|"USER"|DeepSee.TermList("${NEW.toUpperCase()}","hideValue"))_"|"_$Get(^|"USER"|DeepSee.TermList("${NEW.toUpperCase()}","fieldList"))`).value, '1|Region', 'the vendor holds the hide-value flag and the field');

    const menu = await rowAction(page, NEW, 1 + 1, STRINGS.analyticsTermListEditAction);
    assert.deepEqual(menu, [STRINGS.analyticsTermListEditAction, STRINGS.analyticsTermListDeleteAction, STRINGS.taskExportAction, STRINGS.analyticsTermListCopyAction], 'the row menu offers Edit term list, Delete term list, Export and Copy term list');
    await page.waitForSelector('[data-term-list-field="Caption"]', { visible: true, timeout: config.navigationTimeoutMs });
    await page.waitForFunction(() => document.querySelector('[data-term-list-field="Caption"]').value !== '', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-term-list-field="Caption"]', (node) => node.value), 'First caption', 'Edit opens on what the instance holds');
    await fill(page, '[data-term-list-field="Caption"]', 'Second caption');
    await confirmDialog(page, '[data-term-list-confirm]');
    await rowReads(page, NEW, 1, 'Second caption');

    await page.goto(new URL(ENTRIES(NEW), page.url()).href);
    await waitForMapAnswered(page, config.navigationTimeoutMs);
    assert.equal(await openPrimary(page, '[data-term-list-entry-key]'), STRINGS.analyticsEntryAddTitle.replace('<name>', NEW), 'Add entry opens its dialog');
    await page.waitForSelector('[data-term-list-entry-field="Region"]', { visible: true, timeout: config.navigationTimeoutMs });
    await fill(page, '[data-term-list-entry-key]', 'K1');
    await fill(page, '[data-term-list-entry-value]', 'V1');
    await fill(page, '[data-term-list-entry-field="Region"]', 'West');
    await confirmDialog(page, '[data-term-list-entry-confirm]');
    await rowReads(page, 'K1', 2, 'Region: West');
    assert.equal(`${lookup(NEW, 'K1')}|${lookup(NEW, 'K1', 'Region')}`, 'V1|West', '%Lookup answers the value and the field value');

    await rowAction(page, 'K1', 1 + 1, STRINGS.analyticsEntryChangeAction);
    await page.waitForFunction(() => document.querySelector('[data-term-list-entry-value]').value !== '', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-term-list-entry-field="Region"]', (node) => node.value), 'West', 'Change entry opens on the row\'s field value');
    await fill(page, '[data-term-list-entry-value]', 'V2');
    await confirmDialog(page, '[data-term-list-entry-confirm]');
    await rowReads(page, 'K1', 1, 'V2');
    assert.equal(`${lookup(NEW, 'K1')}|${lookup(NEW, 'K1', 'Region')}`, 'V2|West', 'the value changed and the field kept its value');

    await rowAction(page, 'K1', 1 + 1, STRINGS.analyticsEntryRemoveAction);
    assert.equal(await typedName(page, 'K1'), STRINGS.analyticsTermListRemoveConsequence, 'Remove entry states its consequence and asks for the key typed');
    await rowGone(page, 'K1');
    assert.equal(lookup(NEW, 'K1'), '<default>', 'the key answers the vendor\'s default');

    await page.goto(new URL(LISTS, page.url()).href);
    await answered(page);
    await rowAction(page, NEW, 1 + 1, STRINGS.analyticsTermListDeleteAction);
    assert.equal(await typedName(page, NEW), STRINGS.analyticsTermListDeleteConsequence, 'Delete states its consequence and asks for the name typed');
    await rowGone(page, NEW);
    assert.equal(probe('TLMARKED', `##class(${EDIT}).Marked()`).value.includes(NEW.toUpperCase()), false, 'and the list is gone');
  } finally {
    await context.close();
  }
});

/** The text of the first element that matches `selector` once it shows. */
async function shownText(page, selector) {
  await page.waitForSelector(selector, { visible: true, timeout: config.navigationTimeoutMs });
  return page.$eval(selector, (node) => node.textContent.trim());
}

// AC3. Mutation (Rule 19): drop `this.reason.set(...)` from `onConfirm` in term-list-dialog.ts, or the same in term-list-entry-dialog.ts, rebuild and redeploy -> the
// refusal never shows and the matching wait goes red.
test('AC3: a refusal the instance answers is shown in the dialog and writes nothing', async () => {
  const { context, page } = await signedInAt(browser, config, LISTS, VIEWPORTS.wide);
  try {
    await answered(page);
    const before = probe('TLSNAP', `##class(${EDIT}).Snapshot()`).value;
    await openPrimary(page, '[data-term-list-field="Name"]');
    await fill(page, '[data-term-list-field="Name"]', EXISTING.toLowerCase());
    await page.click('[data-term-list-confirm]');
    assert.equal(await shownText(page, '[data-term-list-reason]'), STRINGS.analyticsRefusalTermListTaken, 'a name the namespace holds is refused with the server\'s sentence');
    await page.keyboard.press('Escape');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });

    await page.goto(new URL(ENTRIES(EXISTING), page.url()).href);
    await waitForMapAnswered(page, config.navigationTimeoutMs);
    await openPrimary(page, '[data-term-list-entry-key]');
    await fill(page, '[data-term-list-entry-key]', 'K1');
    await fill(page, '[data-term-list-entry-value]', 'other');
    await page.click('[data-term-list-entry-confirm]');
    assert.equal(await shownText(page, '[data-term-list-entry-reason]'), STRINGS.analyticsRefusalTermListEntryTaken, 'a key the list holds is refused with the server\'s sentence');
    await page.keyboard.press('Escape');
    assert.equal(probe('TLSNAP', `##class(${EDIT}).Snapshot()`).value, before, 'and nothing was written');
  } finally {
    await context.close();
  }
});

/** The vendor's reading of the list `name` as the transfer test dumps it, which compares header, fields, keys and values in one string. */
function dump(name) {
  return probe('TLDUMP', `##class(${TRANSFER}).Dump("${name}")`).value;
}

/** Remove the list `name` through the vendor's own delete, in USER. */
function drop(name) {
  runIris(config.container, ['Set $NAMESPACE="USER"', `Do ##class(%DeepSee.TermList).%DeleteTermList("${name}")`]);
  assert.equal(probe('TLDROPPED', `##class(${TRANSFER}).Dump("${name}")`).value, '', `${name} is removed`);
}

/** Press the command bar's action labelled `label`, once it is offered. */
async function commandBar(page, label) {
  await page.waitForFunction(
    (wanted) => Array.from(document.querySelectorAll('.ocu-command-bar-action')).some((button) => button.textContent.trim() === wanted && button.getAttribute('aria-disabled') === null),
    { timeout: config.navigationTimeoutMs },
    label
  );
  await page.evaluate((wanted) => {
    Array.from(document.querySelectorAll('.ocu-command-bar-action')).find((button) => button.textContent.trim() === wanted).click();
  }, label);
}

/** Wait until the page's transfer status line reads `line`. */
function statusReads(page, line) {
  return page.waitForFunction((wanted) => document.querySelector('[data-term-list-transfer-status]')?.textContent.trim() === wanted, { timeout: config.navigationTimeoutMs }, line);
}

/** The open dialog's server-path picker, ready on its one root: the root it offers. */
async function pickerRoot(page) {
  await page.waitForSelector('.ocu-dialog-body .ocu-path-picker select', { timeout: config.navigationTimeoutMs });
  return page.$eval('.ocu-dialog-body .ocu-path-picker select', (select) => select.value);
}

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

/** Narrow the list to `name`, select its row, open its menu and choose the entry labeled `label`. */
async function listRowAction(page, name, label) {
  await rowAction(page, name, 1 + 1, label);
}

// AC1, AC2. Mutation (Rule 19): make `AnalyticsPort.PerformExport` answer 200 without writing the file (skip the seam's export) -> the import below finds no file and
// this goes red; drop `'export'` from the Term lists' `UNDRAWN_ACTIONS` entry in screen-action-handler.ts, rebuild and redeploy -> the handler registers it and the
// menu assertion of the first test goes red.
test('AC1, AC2: a list is exported to a server file, deleted, and imported back from it with the same header, fields and values', async () => {
  const name = `${MARKER}Move`;
  const file = `${probe('TLDIR', `##class(${FILES}).RelativeName("move.csv")`).value}`;
  runIris(config.container, [`Do ##class(${TRANSFER}).Arrange("${name}")`]);
  const { context, page } = await signedInAt(browser, config, LISTS, VIEWPORTS.wide);
  try {
    await answered(page);
    const before = dump(name);
    assert.ok(before.includes('~a,b^West^n1^v1'), `the list is arranged: ${before}`);

    await listRowAction(page, name, STRINGS.taskExportAction);
    await page.waitForSelector('app-explorer-export-dialog .ocu-dialog-title', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('app-explorer-export-dialog .ocu-dialog-title', (node) => node.textContent.trim()), STRINGS.analyticsTermListExportTitle.replace('<name>', name), 'the export dialog is titled by the list');
    assert.equal(await page.$eval('[data-explorer-export-replaces]', (node) => node.textContent.trim()), STRINGS.analyticsTermListExportHelp, 'and says what the file holds and that a file at the name is replaced');
    const root = await pickerRoot(page);
    assert.ok(root !== '', 'the picker offers the instance\'s one allowed root');
    await page.type('.ocu-dialog-body .ocu-path-picker input[type="text"]', file);
    await page.click('[data-explorer-export-confirm]');
    await statusReads(page, STRINGS.analyticsTermListExportDone.replace('<name>', name));

    drop(name);
    await page.reload();
    await answered(page);
    await commandBar(page, STRINGS.actionImport);
    await page.waitForSelector('app-explorer-import-dialog .ocu-dialog-title', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('app-explorer-import-dialog .ocu-dialog-title', (node) => node.textContent.trim()), STRINGS.analyticsTermListImportTitle, 'the import dialog is titled in the list\'s words');
    assert.equal(await page.$('input[data-explorer-import-compile]'), null, 'and offers no compile choice');
    assert.equal(await page.$eval('[data-explorer-import-replaces]', (node) => node.textContent.trim()), STRINGS.analyticsTermListImportHelp, 'it states that the file creates the list it names');
    assert.equal(await pickerRoot(page), root);
    await page.type('.ocu-dialog-body .ocu-path-picker input[type="text"]', file);
    await page.click('[data-explorer-import-confirm]');
    await statusReads(page, STRINGS.analyticsTermListImportDone.replace('<name>', name));
    await rowReads(page, name, 1, 'Cap, "q"');
    assert.equal(dump(name), before, 'the list is back with the same header, fields and values');
  } finally {
    await context.close();
  }
});

// AC1, AC2, AC3. Mutation (Rule 19): drop `content` in `OcuPilot.Screen.Tool.AnalyticsTermListImport.ScreenActionDelta` -> the local import is refused and this goes red;
// drop the copy dialog's `NewName` value in term-list-copy-dialog.ts, rebuild and redeploy -> the copy is refused and this goes red.
test('AC1, AC2, AC3: a list is exported to this browser and imported back from the file this computer holds, and copied under a new name', async () => {
  const name = `${MARKER}Browse`;
  runIris(config.container, [`Do ##class(${TRANSFER}).Arrange("${name}")`]);
  const { context, page } = await signedInAt(browser, config, LISTS, VIEWPORTS.wide);
  try {
    await answered(page);
    const before = dump(name);
    await captureDownloads(page);
    await listRowAction(page, name, STRINGS.taskExportAction);
    await page.waitForSelector('app-explorer-export-dialog .ocu-dialog-title', { timeout: config.navigationTimeoutMs });
    await pickerRoot(page);
    await page.click('input[data-explorer-export-destination="browser"]');
    await page.waitForFunction(() => document.querySelector('.ocu-dialog-body .ocu-path-picker') === null, { timeout: config.navigationTimeoutMs });
    await page.click('[data-explorer-export-confirm]');
    await statusReads(page, STRINGS.analyticsTermListExportDone.replace('<name>', name));
    await page.waitForFunction(() => window.__ocuSaved.length === 1, { timeout: config.navigationTimeoutMs });
    const saved = await page.evaluate(() => window.__ocuSaved[0]);
    assert.equal(saved.name, `${name}.csv`, 'the browser saves <name>.csv');
    assert.equal(saved.type, 'text/csv');
    assert.ok(saved.text.startsWith(`%%NAME,${name}\n`) && saved.text.includes('"a,b",v1,West,n1'), 'the file is the vendor\'s CSV export of that one list');

    drop(name);
    await page.reload();
    await answered(page);
    const local = join(localDirectory, `${name}.csv`);
    writeFileSync(local, saved.text, 'utf8');
    await commandBar(page, STRINGS.actionImport);
    await pickerRoot(page);
    await page.click('input[data-explorer-import-source="local"]');
    await page.waitForSelector('input[data-explorer-import-file]', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('input[data-explorer-import-file]', (input) => input.getAttribute('accept')), '.csv,.txt', 'the file input offers .csv and .txt files');
    const input = await page.$('input[data-explorer-import-file]');
    await input.uploadFile(local);
    await page.waitForFunction(() => document.querySelector('[data-explorer-import-confirm]')?.getAttribute('aria-disabled') === null, { timeout: config.navigationTimeoutMs });
    await page.click('[data-explorer-import-confirm]');
    await statusReads(page, STRINGS.analyticsTermListImportDone.replace('<name>', name));
    assert.equal(dump(name), before, 'the list is back with the same header, fields and values, the accented key included');

    const copy = `${name}Copy`;
    await listRowAction(page, name, STRINGS.analyticsTermListCopyAction);
    await page.waitForSelector('[data-term-list-copy-name]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[role="dialog"] .ocu-dialog-title', (node) => node.textContent.trim()), STRINGS.analyticsTermListCopyTitle.replace('<name>', name), 'Copy term list is titled by the source');
    await fill(page, '[data-term-list-copy-name]', name.toLowerCase());
    await page.click('[data-term-list-copy-confirm]');
    assert.equal(await shownText(page, '[data-term-list-copy-reason]'), STRINGS.analyticsRefusalTermListTaken, 'a name held in another case is refused with the server\'s sentence');
    await fill(page, '[data-term-list-copy-name]', copy);
    await confirmDialog(page, '[data-term-list-copy-confirm]');
    await statusReads(page, STRINGS.analyticsTermListCopyDone.replace('<name>', name).replace('<new>', copy));
    await rowReads(page, copy, 1, 'Cap, "q"');
    assert.equal(dump(copy), before, 'the copy equals the source');
    assert.equal(dump(name), before, 'and the source is unchanged');
  } finally {
    await context.close();
  }
});

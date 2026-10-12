/**
 * Story 20.5, Part B, in a real browser against the throwaway instance: Interoperability's Lookup tables export and import
 * (AD-5, AD-21, AD-44, AD-53, AD-62).
 *
 * What it pins, in `USER`, whose probe table this spec creates and removes: the table is exported to a file on the server through
 * the export dialog, deleted, and imported back from that file through the import dialog with the same entries; then it is
 * exported to this browser, which saves `<table>.xml` with the vendor's export of that one `.LUT` document, deleted again, and
 * imported back from that file read on this computer through the dialog's file input, again with the same entries. The export
 * dialog and the import dialog, on each of its sources, pass the structural walk at 1280 light, 720 light and 1280 dark, with no
 * entry beyond the baseline (DW-1337).
 *
 * **It writes a probe lookup table in `USER`** through `OcuPilot.Test.InteropLookupFixture` and a probe directory through
 * `OcuPilot.Test.ExplorerTransferProbe`, so it runs on a throwaway only; the `after` hook removes both, whatever the tests
 * answered.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/interop-lookup-transfer.browser-spec.mjs` (after `npm run build` and the bundle
 * copied into the throwaway).
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
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const FIXTURE = 'OcuPilot.Test.InteropLookupFixture';
const PROBE = 'OcuPilot.Test.ExplorerTransferProbe';
const TABLE = 'OcuProbe205Transfer';
const OTHER = 'OcuProbe205TransferOther';
const TABLES_URL = '/ocupilot/interoperability/lookup-tables?ns=USER';
const TABLES_ROUTE = 'interoperability/lookup-tables';
const ACTION_PATH = '/api/ocupilot/screens/interop.lookuptables/action';
const FILE = 'OcuProbe1913/lookup-table.xml';
const NAME_TEXT = '.ocu-data-table-link, .ocu-data-table-text';

let browser = null;
let localDirectory = '';
let created = false;

const marker = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [marker(name, expression)]);
  return { value: markerValue(output, name), output };
}

/** A SHA-256 of the stored entries of `table` as UTF-8, so a non-ASCII key compares without crossing the terminal. */
function digest(table) {
  return probe('DIGEST', `##class(%xsd.hexBinary).LogicalToXSD($System.Encryption.SHAHash(256,$ZConvert(##class(${FIXTURE}).Entries("${table}"),"O","UTF8")))`).value;
}

/** Whether the stored lookup global holds `table` under exactly that name. */
function exists(table) {
  return probe('EXISTS', `##class(${FIXTURE}).Exists("${table}")`).value === '1';
}

/** Wait, up to ten probes, until `exists(table)` reads `wanted`; answers the last reading. */
async function settled(table, wanted) {
  let last = exists(table);
  for (let tries = 0; last !== wanted && tries < 10; tries += 1) {
    await new Promise((resolve) => setTimeout(resolve, 500));
    last = exists(table);
  }
  return last;
}

/** Remove every probe table and the probe directory: the names only these probes hold. */
function clean() {
  const output = runIris(config.container, [
    `Set tSC=##class(${FIXTURE}).Clear()`,
    `If tSC Set tSC=##class(${PROBE}).RemoveDirectory()`,
    marker('CLEAN', '$System.Status.IsOK(tSC)'),
  ]);
  return { value: markerValue(output, 'CLEAN'), output };
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec writes probe lookup tables and files, so it never runs inside the live container');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec writes probe lookup tables, so it runs only in a throwaway; ${config.container} is not one`);
  const cleared = clean();
  assert.equal(cleared.value, '1', `an earlier run's probe tables and directory are removed: ${cleared.output}`);
  const made = runIris(config.container, [`Set tSC=##class(${PROBE}).MakeDirectory()`, marker('DIR', '$System.Status.IsOK(tSC)')]);
  assert.equal(markerValue(made, 'DIR'), '1', `the probe directory is made: ${made}`);
  created = true;
  const other = probe('OTHER', `$System.Status.IsOK(##class(${FIXTURE}).Put("${OTHER}","only","entry"))`);
  assert.equal(other.value, '1', `a second table keeps the list from reading empty: ${other.output}`);
  localDirectory = mkdtempSync(join(tmpdir(), 'epic-20-205-'));
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
    if (localDirectory !== '') rmSync(localDirectory, { recursive: true, force: true });
  } finally {
    if (created && /-ci$/.test(config.container)) {
      const removed = clean();
      assert.equal(removed.value, '1', `the probe table and directory are removed: ${removed.output}`);
    }
  }
});

/** The probe table: a plain key, a key with a space and markup, a non-ASCII key and an empty value. */
function arrange() {
  drop();
  const put = (key, value) => `$System.Status.IsOK(##class(${FIXTURE}).Put("${TABLE}",${key},${value}))`;
  const result = probe('ARRANGE', [put('"alpha"', '"first value"'), put('"with space"', '"a & b < c > d"'), put('"caf"_$Char(233)', '"x"_$Char(233)'), put('"empty"', '""')].join('_'));
  assert.equal(result.value, '1111', `the probe table is arranged: ${result.output}`);
}

/** Remove the probe table through the vendor's own removals, key by key, which leaves the other probe table where it is. */
function drop() {
  const remove = (key) => `$System.Status.IsOK(##class(${FIXTURE}).Remove("${TABLE}",${key}))`;
  probe('DROP', [remove('"alpha"'), remove('"with space"'), remove('"caf"_$Char(233)'), remove('"empty"')].join('_'));
  assert.equal(exists(TABLE), false, 'the probe table is removed');
}

function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/** Wait until no CSS transition is running, so a contrast read measures the theme it is in. */
function transitionsSettled(page) {
  return page.waitForFunction(
    () => document.getAnimations().every((animation) => !(animation instanceof CSSTransition) || animation.playState !== 'running'),
    { timeout: config.navigationTimeoutMs }
  );
}

/** The walk of the screen on display at three passes, with its open dialog, answering entries outside the baseline. */
async function structural(page) {
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
    await transitionsSettled(page);
    surfaces[theme] = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
    const { entries } = await detectScreen(page, { route: TABLES_ROUTE, checks, viewport: viewport.width, theme, minimums });
    found.push(...entries);
    const body = await page.$eval('.ocu-dialog-body', (element) => ({ scroll: element.scrollWidth, client: element.clientWidth }));
    assert.ok(body.scroll <= body.client, `the dialog body does not scroll sideways at ${viewport.width}px ${theme}: ${JSON.stringify(body)}`);
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await frames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  return compare(collapse(found), readBaseline()?.entries ?? []).fresh.map((entry) => `${entry.key}: ${entry.measured}`);
}

/** Wait until the list holds a row named `name`, or, with `present` false, none. */
function rowPresent(page, name, present = true) {
  return page.waitForFunction(
    (rowSelector, wanted, textSelector, want) =>
      Array.from(document.querySelectorAll(rowSelector)).some((row) => {
        const cell = row.querySelector('[role="gridcell"]');
        return ((cell?.querySelector(textSelector) ?? cell)?.textContent ?? '').trim() === wanted;
      }) === want,
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name,
    NAME_TEXT,
    present
  );
}

/** Narrow the list to `name`, select its row, open its menu and choose the entry labeled `label`. */
async function rowAction(page, name, label) {
  await waitForRows(page, config.navigationTimeoutMs);
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, name);
  await rowPresent(page, name);
  // The filter leaves the one row; its second cell is not the name's link.
  await clickRowCentre(page, { index: 0, cell: 1 });
  await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
  await page.evaluate((wanted) => {
    Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'))
      .find((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted)
      .click();
  }, label);
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
  return page.waitForFunction(
    (wanted) => document.querySelector('[data-interop-lookup-transfer-status]')?.textContent.trim() === wanted,
    { timeout: config.navigationTimeoutMs },
    line
  );
}

/** The open dialog's server-path picker, ready on its one root: the root it offers. */
async function pickerRoot(page) {
  await page.waitForSelector('.ocu-dialog-body .ocu-path-picker select', { timeout: config.navigationTimeoutMs });
  return page.$eval('.ocu-dialog-body .ocu-path-picker select', (select) => select.value);
}

/** Open the Lookup tables list for the probe namespace and wait for its rows and the namespace features. */
async function openTables(page) {
  await waitForRows(page, config.navigationTimeoutMs);
  await waitForMapAnswered(page, config.navigationTimeoutMs);
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

// AC8, AC9. Mutation (Rule 19): make `ExportTable` write the legacy `%Export` form -> the import below is refused for its shape and this goes red.
test('AC8, AC9: the table is exported to a server file, deleted, and imported back from it with the same entries', async () => {
  const { context, page } = await signedInAt(browser, config, TABLES_URL, VIEWPORTS.wide);
  const posts = [];
  page.on('request', (request) => {
    if (request.method() === 'POST' && new URL(request.url()).pathname === ACTION_PATH) posts.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    arrange();
    await page.reload();
    await openTables(page);
    await rowPresent(page, TABLE);
    const before = digest(TABLE);
    assert.notEqual(before, '', 'the probe table reads');

    await rowAction(page, TABLE, STRINGS.taskExportAction);
    await page.waitForSelector('app-explorer-export-dialog .ocu-dialog-title', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('app-explorer-export-dialog .ocu-dialog-title', (node) => node.textContent.trim()), STRINGS.interopLookupExportTitle.replace('<table>', TABLE), 'the dialog is titled by the table');
    assert.equal(await page.$eval('[data-explorer-export-replaces]', (node) => node.textContent.trim()), STRINGS.interopLookupExportReplaces, 'and says a file at the name is replaced and holds every key and value');
    const root = await pickerRoot(page);
    assert.ok(root !== '', 'the picker offers the instance\'s one allowed root');
    await page.type('.ocu-dialog-body .ocu-path-picker input[type="text"]', FILE);
    assert.deepEqual(await structural(page), [], 'the export dialog adds no structural entry');
    await page.click('[data-explorer-export-confirm]');
    await statusReads(page, STRINGS.interopLookupExportDone.replace('<table>', TABLE).replace('<path>', `${root}${FILE}`));
    assert.deepEqual(posts.at(-1), { action: 'export', id: TABLE, values: { root, path: FILE } }, 'one export of the table, naming the file');

    // Delete the table through the fixture, then import it back from the file.
    drop();
    await page.reload();
    await openTables(page);
    await rowPresent(page, TABLE, false);

    await commandBar(page, STRINGS.actionImport);
    await page.waitForSelector('app-explorer-import-dialog .ocu-dialog-title', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('app-explorer-import-dialog .ocu-dialog-title', (node) => node.textContent.trim()), STRINGS.interopLookupImportTitle, 'the import dialog is titled in the table\'s words');
    assert.equal(await page.$('input[data-explorer-import-compile]'), null, 'and offers no compile choice');
    assert.equal(await page.$eval('[data-explorer-import-replaces]', (node) => node.textContent.trim()), STRINGS.interopLookupImportConsequence, 'it states that the table\'s entries are replaced');
    assert.equal(await pickerRoot(page), root);
    await page.type('.ocu-dialog-body .ocu-path-picker input[type="text"]', FILE);
    assert.deepEqual(await structural(page), [], 'the import dialog adds no structural entry');
    await page.click('[data-explorer-import-confirm]');
    await statusReads(page, STRINGS.interopLookupImportDone.replace('<file>', `${root}${FILE}`));
    assert.deepEqual(posts.at(-1), { action: 'import', id: 'import', values: { root, path: FILE } }, 'one import of the file, on the one target');
    await rowPresent(page, TABLE);
    assert.equal(await settled(TABLE, true), true, 'the table is back on the instance');
    assert.equal(digest(TABLE), before, 'with the same entries');
  } finally {
    await context.close();
  }
});

// AC8, AC9. Mutation (Rule 19): drop `content` in `OcuPilot.Screen.Tool.InteropLookupTableImport.ScreenActionDelta` -> the local import is refused and this goes red.
test('AC8, AC9: the table is exported to this browser, deleted, and imported back from the file this computer holds', async () => {
  const { context, page } = await signedInAt(browser, config, TABLES_URL, VIEWPORTS.wide);
  const posts = [];
  page.on('request', (request) => {
    if (request.method() === 'POST' && new URL(request.url()).pathname === ACTION_PATH) posts.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    arrange();
    await page.reload();
    await openTables(page);
    await rowPresent(page, TABLE);
    const before = digest(TABLE);
    await captureDownloads(page);

    await rowAction(page, TABLE, STRINGS.taskExportAction);
    await page.waitForSelector('app-explorer-export-dialog .ocu-dialog-title', { timeout: config.navigationTimeoutMs });
    await pickerRoot(page);
    await page.click('input[data-explorer-export-destination="browser"]');
    await page.waitForFunction(() => document.querySelector('.ocu-dialog-body .ocu-path-picker') === null, { timeout: config.navigationTimeoutMs });
    assert.deepEqual(await structural(page), [], 'the export dialog on its browser destination adds no structural entry');
    await page.click('[data-explorer-export-confirm]');
    await statusReads(page, STRINGS.interopLookupExportSaved.replace('<table>', TABLE).replace('<file>', `${TABLE}.xml`));
    assert.deepEqual(posts.at(-1), { action: 'export-browser', id: TABLE }, 'one export to this browser, naming no file');
    await page.waitForFunction(() => window.__ocuSaved.length === 1, { timeout: config.navigationTimeoutMs });
    const saved = await page.evaluate(() => window.__ocuSaved[0]);
    assert.equal(saved.name, `${TABLE}.xml`, 'the browser saves <table>.xml');
    assert.equal(saved.type, 'application/xml');
    assert.ok(saved.text.includes(`<Document name="${TABLE}.LUT">`) && saved.text.includes('<lookupTable>') && !saved.text.includes('<Class'), 'the file is the vendor\'s export of that one .LUT document');

    drop();
    await page.reload();
    await openTables(page);
    await rowPresent(page, TABLE, false);

    const local = join(localDirectory, `${TABLE}.xml`);
    writeFileSync(local, saved.text, 'utf8');
    await commandBar(page, STRINGS.actionImport);
    assert.ok((await pickerRoot(page)) !== '', 'the dialog opens on the server file, its picker drawn');
    await page.click('input[data-explorer-import-source="local"]');
    await page.waitForSelector('input[data-explorer-import-file]', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('input[data-explorer-import-file]', (input) => input.getAttribute('accept')), '.xml', 'the file input offers .xml files');
    assert.deepEqual(await structural(page), [], 'the import dialog with its local file input adds no structural entry');
    const input = await page.$('input[data-explorer-import-file]');
    await input.uploadFile(local);
    await page.waitForFunction(() => document.querySelector('[data-explorer-import-confirm]')?.getAttribute('aria-disabled') === null, { timeout: config.navigationTimeoutMs });
    await page.click('[data-explorer-import-confirm]');
    await statusReads(page, STRINGS.interopLookupImportDone.replace('<file>', `${TABLE}.xml`));
    const sent = posts.at(-1);
    assert.deepEqual([sent.action, sent.id, sent.values.fileName], ['import-local', TABLE, `${TABLE}.xml`], 'one local import, on the table the file names, so the write holds that table');
    assert.equal(sent.values.content, saved.text, 'carrying the file\'s text');
    assert.equal(await settled(TABLE, true), true, 'the table is back on the instance');
    assert.equal(digest(TABLE), before, 'with the same entries, the non-ASCII key included');
  } finally {
    await context.close();
  }
});

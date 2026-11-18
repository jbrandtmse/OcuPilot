/**
 * Story 21.17 in a real browser, against the throwaway instance: System Explorer's Globals list exports one global and imports it back (AD-5, AD-21, AD-53).
 *
 * What it pins: the spec's own global's row Export, to a server file through the export dialog, reports done; the screen's Import of that file, after the
 * spec kills the global, restores it, read back through the node page; and a local import of a file holding a `%`-global shows the protected-global sentence in
 * the dialog and loads nothing.
 *
 * **It writes only its own global**, `^ZZOcuGlbT<pid>` in `HSCUSTOM`, which it kills first and again after, and the files `OcuPilot.Test.GlobalTransferProbe`
 * names, so it runs on a throwaway only. The `%`-global is never loaded: the instance refuses the file before anything loads, and the spec kills it
 * either way.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1 browser/system-explorer-global-transfer.browser-spec.mjs` (after
 * `npm run build` and the bundle copied into the throwaway).
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
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const GLOBAL = `ZZOcuGlbT${process.pid}`;
const ROOT = `^${GLOBAL}`;
const PERCENT = `%${GLOBAL}`;
const PROBE = 'OcuPilot.Test.GlobalTransferProbe';
const FILE = 'OcuProbe2117/browser.xml';
const listRoute = '/ocupilot/system-explorer/globals?ns=HSCUSTOM';
const nodesRoute = `/ocupilot/system-explorer/globals/document/${encodeURIComponent(encodeURIComponent(GLOBAL))}?ns=HSCUSTOM`;

let browser = null;
let localDirectory = '';

/** One expression on the throwaway, answering its marker. */
function probe(name, lines) {
  const output = runIris(config.container, [...lines, `Write "OCU-${name}-START:"_result_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** Kill the spec's global and make it again: three nodes, the second a long value and the third with a node below it. */
function makeGlobal() {
  return probe('GTMAKE', [`Kill ${ROOT}`, `Set ${ROOT}(1)="plain",${ROOT}(2)=$Translate($Justify("",40000)," ","x"),${ROOT}(3)="top",${ROOT}(3,1)="below"`, 'Set result=1']);
}

/** The value of a node, or `<none>` where it is undefined. */
const nodeValue = (subscripts) => probe('GTVAL', [`Set result=$Select($Data(${ROOT}(${subscripts}))#2:$Length($Get(${ROOT}(${subscripts})))_":"_$Extract($Get(${ROOT}(${subscripts})),1,6),1:"<none>")`]).value;

/** Whether the spec's global holds anything. */
const globalData = () => probe('GTDATA', [`Set result=$Data(${ROOT})`]).value;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec writes a global, so it runs only in a throwaway; ${config.container} is not one`);
  const made = probe('GTDIR', [`Set tSC=##class(${PROBE}).RemoveDirectory()`, `If tSC Set tSC=##class(${PROBE}).MakeDirectory()`, 'Set result=$System.Status.IsOK(tSC)']);
  assert.equal(made.value, '1', `the probe directory is made: ${made.output}`);
  localDirectory = mkdtempSync(join(tmpdir(), 'epic-21-2117-'));
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    probe('GTKILL', [`Kill ${ROOT}`, `Kill ^${PERCENT}`, `Set tSC=##class(${PROBE}).RemoveDirectory()`, 'Set result=$System.Status.IsOK(tSC)']);
  } finally {
    if (browser !== null) await browser.close();
    if (localDirectory !== '') rmSync(localDirectory, { recursive: true, force: true });
  }
});

/** Filter the list to the spec's global, select its row and answer its index. */
async function selectGlobalRow(page, name) {
  await waitForRows(page, config.navigationTimeoutMs);
  await page.click('input[data-ocu-criterion="pattern"]', { clickCount: 3 });
  await page.type('input[data-ocu-criterion="pattern"]', name);
  await page.click('.ocu-criteria-controls button[type="submit"]');
  await page.waitForFunction(
    (selector, wanted) => [...document.querySelectorAll(selector)].some((row) => row.querySelector('[role="gridcell"]')?.textContent.trim().startsWith(wanted)),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name
  );
  const at = await page.$$eval(ROW_SELECTOR, (rows, wanted) => rows.findIndex((row) => row.querySelector('[role="gridcell"]')?.textContent.trim().startsWith(wanted)), name);
  assert.ok(at >= 0, `${name} is listed`);
  await clickRowCentre(page, { index: at, cell: 2 });
  await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs });
}

/** Open the selected row's menu and press the entry labelled `label`. */
async function rowMenu(page, label) {
  await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
  await page.evaluate((wanted) => [...document.querySelectorAll('[role="menu"] [role="menuitem"]')].find((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted)?.click(), label);
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

/** Wait until the status line reads `line`. */
function statusReads(page, line) {
  return page.waitForFunction((wanted) => document.querySelector('[data-explorer-write="status"]')?.textContent.trim() === wanted, { timeout: config.navigationTimeoutMs }, line);
}

/** The open dialog's server-path picker, ready on its one root: the root it offers. */
async function pickerRoot(page) {
  await page.waitForSelector('.ocu-dialog-body .ocu-path-picker select', { timeout: config.navigationTimeoutMs });
  return page.$eval('.ocu-dialog-body .ocu-path-picker select', (select) => select.value);
}

/** The node page has drawn at least `count` rows; their references. */
async function nodeRows(page, count) {
  await page.waitForFunction((wanted) => document.querySelectorAll('[data-global-node-row]').length >= wanted, { timeout: config.navigationTimeoutMs }, count);
  return page.$$eval('[data-global-node-row]', (rows) => rows.map((row) => row.querySelector('.ocu-global-reference')?.textContent.trim()));
}

test('AC5: the global is exported from its row to a server file, killed, and imported back from the Import dialog, its nodes as they were', async () => {
  assert.equal(makeGlobal().value, '1', 'the spec\'s own global is made afresh');
  const before = [nodeValue('1'), nodeValue('2'), nodeValue('3'), nodeValue('3,1')];
  assert.deepEqual(before, ['5:plain', '40000:xxxxxx', '3:top', '5:below'], 'its four nodes read');
  const { context, page } = await signedInAt(browser, config, listRoute, VIEWPORTS.wide);
  const posts = [];
  page.on('request', (request) => {
    if (new URL(request.url()).pathname === '/api/ocupilot/screens/explorer.globals/action') posts.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    await selectGlobalRow(page, GLOBAL);
    await rowMenu(page, STRINGS.taskExportAction);
    await page.waitForSelector('app-explorer-export-dialog .ocu-dialog-title', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('app-explorer-export-dialog .ocu-dialog-title', (node) => node.textContent.trim()), STRINGS.explorerExportTitleOne, 'the dialog is titled for one document');
    const root = await pickerRoot(page);
    assert.ok(root !== '', 'the picker offers the instance\'s one allowed root');
    await page.type('.ocu-dialog-body .ocu-path-picker input[type="text"]', FILE);
    await page.click('[data-explorer-export-confirm]');
    await statusReads(page, STRINGS.explorerExportDoneOne.replace('<path>', `${root}${FILE}`));
    assert.deepEqual(posts.at(-1), { action: 'export', id: GLOBAL, values: { root, path: FILE } }, 'one export of the selected global, naming the file');
    assert.equal(probe('GTFILE', [`Set result=##class(${PROBE}).FileExists("browser.xml")`]).value, '1', 'the file is on the instance');

    probe('GTKILL2', [`Kill ${ROOT}`, 'Set result=1']);
    assert.equal(globalData(), '0', 'the global is killed');
    await commandBar(page, STRINGS.actionImport);
    await page.waitForSelector('app-explorer-import-dialog .ocu-dialog-title', { timeout: config.navigationTimeoutMs });
    assert.equal(await pickerRoot(page), root, 'the import dialog opens on the server file');
    await page.type('.ocu-dialog-body .ocu-path-picker input[type="text"]', FILE);
    await page.click('[data-explorer-import-confirm]');
    await statusReads(page, STRINGS.explorerImportDoneOne);
    assert.deepEqual(posts.at(-1), { action: 'import', id: 'import', values: { root, path: FILE, Compile: 'true' } }, 'one import of the file, on the one target');
    assert.deepEqual([nodeValue('1'), nodeValue('2'), nodeValue('3'), nodeValue('3,1')], before, 'the instance holds every node as it was');
  } finally {
    await context.close();
  }
  const second = await signedInAt(browser, config, nodesRoute, VIEWPORTS.wide);
  try {
    const references = await nodeRows(second.page, 4);
    assert.deepEqual(references, [`${ROOT}(1)`, `${ROOT}(2)`, `${ROOT}(3)`, `${ROOT}(3,1)`], 'and the node page reads them back');
  } finally {
    await second.context.close();
  }
});

test('a local import of a file holding a % global shows the protected-global sentence and loads nothing', async () => {
  const xml = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<Export generator="IRIS" version="26">',
    '<Global>',
    `<Node><Sub>^${PERCENT}</Sub>`,
    '<Node><Sub>1</Sub>',
    '<Data>a</Data>',
    '</Node>',
    '</Node>',
    '</Global>',
    '</Export>',
    '',
  ].join('\n');
  const local = join(localDirectory, 'percent.xml');
  writeFileSync(local, xml);
  const { context, page } = await signedInAt(browser, config, listRoute, VIEWPORTS.wide);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await commandBar(page, STRINGS.actionImport);
    assert.ok((await pickerRoot(page)) !== '', 'the dialog opens on the server file, its picker drawn');
    await page.click('input[data-explorer-import-source="local"]');
    await page.waitForSelector('input[data-explorer-import-file]', { timeout: config.navigationTimeoutMs });
    await (await page.$('input[data-explorer-import-file]')).uploadFile(local);
    await page.waitForFunction(() => document.querySelector('[data-explorer-import-confirm]')?.getAttribute('aria-disabled') === null, { timeout: config.navigationTimeoutMs });
    await page.click('[data-explorer-import-confirm]');
    await page.waitForSelector('[data-explorer-transfer-refusal]', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-explorer-transfer-refusal]', (node) => node.textContent.trim()), STRINGS.globalRefusalProtected, 'the dialog shows the protected-global sentence');
    assert.equal(probe('GTPCT', [`Set result=$Data(^${PERCENT})`]).value, '0', 'and the % global stays undefined');
  } finally {
    await context.close();
  }
});

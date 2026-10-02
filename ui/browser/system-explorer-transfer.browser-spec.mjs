/**
 * Story 19.13 in a real browser, against the throwaway: two probe classes checked on the Classes list
 * in `USER` are exported to a server file through the export dialog, deleted, and imported back from
 * that file through the import dialog, the list showing them again (AC1); a third class is imported
 * from a file on this computer through the dialog's file input. The export dialog and the import
 * dialog, on each of its two sources, pass the structural walk at 1280 light, 720 light and 1280
 * dark, with no entry beyond the baseline (AC7).
 *
 * The probes and the probe directory are `OcuPilot.Test.ExplorerTransferProbe`'s, created in `before`
 * and removed in `after` by that class, which names only its own package and directory. It refuses
 * the live container.
 *
 * Run: `node --test --test-concurrency=1 browser/system-explorer-transfer.browser-spec.mjs` (after
 * `npm run build`, the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { ROW_SELECTOR, waitForRows } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const ROUTE = 'system-explorer/classes';
const LIST_URL = `/ocupilot/${ROUTE}?ns=USER`;
const ACTION_PATH = '/api/ocupilot/screens/explorer.classes/action';
const PROBE = 'OcuPilot.Test.ExplorerTransferProbe';
const ALPHA = 'OcuProbe1913.Alpha.cls';
const BETA = 'OcuProbe1913.Beta.cls';
const GAMMA = 'OcuProbe1913.Gamma.cls';
const FILE = 'OcuProbe1913/browser.xml';

let browser = null;
let localDirectory = '';

const marker = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/** Whether `document` is held in `USER`, read in the container. */
function exists(document) {
  const output = runIris(config.container, [marker('HELD', `##class(${PROBE}).Exists("USER","${document}")`)]);
  return markerValue(output, 'HELD');
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates, exports, deletes and imports classes, so it never runs inside the live container');
  await assertThrowaway(config);
  const output = runIris(config.container, [
    `Set tSC=##class(${PROBE}).Remove("USER")`,
    `If tSC Set tSC=##class(${PROBE}).RemoveDirectory()`,
    `If tSC Set tSC=##class(${PROBE}).MakeDirectory()`,
    `If tSC Set tSC=##class(${PROBE}).MakeClass("USER","OcuProbe1913.Alpha")`,
    `If tSC Set tSC=##class(${PROBE}).MakeClass("USER","OcuProbe1913.Beta")`,
    marker('OK', '$System.Status.IsOK(tSC)'),
  ]);
  assert.equal(markerValue(output, 'OK'), '1', `the probe classes and directory are made in USER: ${output}`);
  localDirectory = mkdtempSync(join(tmpdir(), 'epic-19-1913-'));
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (localDirectory !== '') rmSync(localDirectory, { recursive: true, force: true });
  if (config.container === LIVE_CONTAINER) return;
  const output = runIris(config.container, [
    `Set tSC=##class(${PROBE}).Remove("USER")`,
    `If tSC Set tSC=##class(${PROBE}).RemoveDirectory()`,
    marker('OK', '$System.Status.IsOK(tSC)'),
  ]);
  assert.equal(markerValue(output, 'OK'), '1', `no probe document or file is left: ${output}`);
});

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
    const { entries } = await detectScreen(page, { route: ROUTE, checks, viewport: viewport.width, theme, minimums });
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

/** The names the list shows, in its order. */
function rowNames(page) {
  return page.$$eval(ROW_SELECTOR, (rows) =>
    rows.map((row) => (row.querySelector('[role="gridcell"] .ocu-data-table-link, [role="gridcell"] .ocu-data-table-text')?.textContent ?? '').trim())
  );
}

/** Check the row whose name reads `name`. */
async function check(page, name) {
  const box = await page.evaluateHandle(
    (selector, wanted) =>
      Array.from(document.querySelectorAll(selector))
        .find((row) => (row.querySelector('[role="gridcell"] .ocu-data-table-link, [role="gridcell"] .ocu-data-table-text')?.textContent ?? '').trim() === wanted)
        ?.querySelector('.ocu-data-table-check') ?? null,
    ROW_SELECTOR,
    name
  );
  await box.click();
  await page.waitForFunction((element) => element.checked === true, { timeout: config.navigationTimeoutMs }, box);
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
  return page.waitForFunction(
    (wanted) => document.querySelector('[data-explorer-write="status"]')?.textContent.trim() === wanted,
    { timeout: config.navigationTimeoutMs },
    line
  );
}

/** Wait until the list shows exactly `names` among the probe package. */
function rowsRead(page, names) {
  return page.waitForFunction(
    (selector, wanted) => {
      const shown = Array.from(document.querySelectorAll(selector)).map((row) => row.textContent);
      return wanted.every((name) => shown.some((text) => text.includes(name))) && shown.length === wanted.length;
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    names
  );
}

/** The open dialog's server-path picker, ready on its one root: the root it offers. */
async function pickerRoot(page) {
  await page.waitForSelector('.ocu-dialog-body .ocu-path-picker select', { timeout: config.navigationTimeoutMs });
  return page.$eval('.ocu-dialog-body .ocu-path-picker select', (select) => select.value);
}

test('AC1: two checked probes are exported to a server file, deleted, and imported back from it; a third is imported from a local file', async () => {
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const posts = [];
  page.on('request', (request) => {
    if (new URL(request.url()).pathname === ACTION_PATH) posts.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await page.click('input[data-ocu-criterion="pattern"]', { clickCount: 3 });
    await page.type('input[data-ocu-criterion="pattern"]', 'OcuProbe1913.*');
    await page.click('.ocu-criteria-controls button[type="submit"]');
    await rowsRead(page, [ALPHA, BETA]);
    assert.deepEqual(await rowNames(page), [ALPHA, BETA], 'the two probes, and nothing else');
    await check(page, BETA);
    await check(page, ALPHA);

    // Export: the dialog opens on the server file, and the walk covers it.
    await commandBar(page, STRINGS.taskExportAction);
    await page.waitForSelector('app-explorer-export-dialog .ocu-dialog-title', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('app-explorer-export-dialog .ocu-dialog-title', (node) => node.textContent.trim()), STRINGS.explorerExportTitle.replace('<n>', '2'));
    const root = await pickerRoot(page);
    assert.ok(root !== '', 'the picker offers the instance\'s one allowed root');
    await page.type('.ocu-dialog-body .ocu-path-picker input[type="text"]', FILE);
    assert.deepEqual(await structural(page), [], 'the export dialog adds no structural entry');
    await page.click('[data-explorer-export-confirm]');
    await statusReads(page, STRINGS.explorerExportDone.replace('<n>', '2').replace('<path>', `${root}${FILE}`));
    assert.deepEqual(posts.at(-1), { action: 'export', id: `${ALPHA},${BETA}`, values: { root, path: FILE } }, 'one export over the canonical set, naming the file');

    // Delete both, then import them back from the file.
    await commandBar(page, STRINGS.actionDelete);
    await page.waitForSelector('app-typed-name-dialog .ocu-typed-name-field', { timeout: config.navigationTimeoutMs });
    await page.type('.ocu-typed-name-field', '2');
    await page.click('app-typed-name-dialog .ocu-button-destructive');
    await statusReads(page, STRINGS.explorerDeleteSummary.replace('<done>', '2').replace('<n>', '2'));
    assert.equal(exists(ALPHA), '0', 'Alpha is deleted');
    await commandBar(page, STRINGS.actionImport);
    await page.waitForSelector('app-explorer-import-dialog .ocu-dialog-title', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('input[data-explorer-import-compile]', (box) => box.checked), true, 'the compile box opens checked');
    assert.equal(await pickerRoot(page), root);
    await page.type('.ocu-dialog-body .ocu-path-picker input[type="text"]', FILE);
    assert.deepEqual(await structural(page), [], 'the import dialog adds no structural entry');
    await page.click('[data-explorer-import-confirm]');
    await statusReads(page, STRINGS.explorerImportDone.replace('<n>', '2'));
    assert.deepEqual(posts.at(-1), { action: 'import', id: 'import', values: { root, path: FILE, Compile: 'true' } }, 'one import of the file, on the one target');
    const pane = await page.$eval('[data-explorer-write="output"]', (node) => node.textContent);
    assert.ok(pane.startsWith(`${ALPHA}\n${BETA}\n`), `the pane lists the documents loaded, then the console: ${pane}`);
    await rowsRead(page, [ALPHA, BETA]);
    assert.equal(exists(ALPHA), '1', 'Alpha is back on the instance');
    assert.equal(exists(BETA), '1', 'and so is Beta');

    // A local file, read by the browser through the dialog's file input.
    const local = join(localDirectory, 'Gamma.cls');
    writeFileSync(local, 'Class OcuProbe1913.Gamma Extends %RegisteredObject\n{\n}\n');
    await commandBar(page, STRINGS.actionImport);
    // The dialog opens on the server file while the allowed directories are read. Their answer grows
    // the picker and re-centres the dialog, moving the source radio, so it is pressed once the picker is drawn.
    assert.equal(await pickerRoot(page), root, 'the dialog opens on the server file, its picker drawn');
    await page.click('input[data-explorer-import-source="local"]');
    await page.waitForSelector('input[data-explorer-import-file]', { timeout: config.navigationTimeoutMs });
    assert.deepEqual(await structural(page), [], 'the import dialog with its local file input adds no structural entry');
    const input = await page.$('input[data-explorer-import-file]');
    await input.uploadFile(local);
    await page.waitForFunction(() => document.querySelector('[data-explorer-import-confirm]')?.getAttribute('aria-disabled') === null, { timeout: config.navigationTimeoutMs });
    await page.click('[data-explorer-import-confirm]');
    await statusReads(page, STRINGS.explorerImportDone.replace('<n>', '1'));
    const sent = posts.at(-1);
    assert.deepEqual([sent.action, sent.id, sent.values.fileName, sent.values.Compile], ['import-local', 'import', 'Gamma.cls', 'true'], 'one local import, named by the file');
    await rowsRead(page, [ALPHA, BETA, GAMMA]);
    assert.equal(exists(GAMMA), '1', 'Gamma is on the instance');
  } finally {
    await context.close();
  }
});

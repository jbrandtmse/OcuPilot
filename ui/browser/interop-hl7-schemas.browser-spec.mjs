/**
 * Story 24.18 Batch 1 in a real browser, against the throwaway instance: Interoperability's HL7 schemas, added, exported, deleted and imported
 * (AD-5, AD-21, AD-53, AD-54, AD-55, AD-62).
 *
 * What it pins, in `USER`, whose probe schemas this spec creates and removes: the list offers New HL7 schema and lists a probe schema under the
 * published headers with its base and description, and passes the structural and contrast checks at 1280 light, 720 light and 1280 dark, with no
 * entry beyond the baseline (DW-1337); and the AC10 walk, in which a person adds a schema based on 2.5.1, exports it to this browser, deletes it,
 * typing its name, and imports the saved file from this computer, with the list and the stored schema showing each change.
 *
 * Each test arranges the probes it needs through the fixture and removes them when it ends, so every test passes alone and in any order. It shares its
 * page helpers with the other Interoperability list specs (`interop-list-spec.mjs`); the four small helpers for the transfer dialogs are this spec's own,
 * since `interop-lookup-transfer.browser-spec.mjs` declares tests and hooks and so cannot be imported.
 *
 * **It writes probe HL7 schemas in `USER`** through `OcuPilot.Test.InteropHl7Fixture`, so it runs on a throwaway only; the `after` hook removes every
 * one, whatever the tests answered.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/interop-hl7-schemas.browser-spec.mjs` (after `npm run build` and the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { interopListHelpers } from './interop-list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const FIXTURE = 'OcuPilot.Test.InteropHl7Fixture';
/** The probe names carry the fixture's marker, which is what `DropProbes` removes by. */
const SCHEMA = 'OcuProbe2418b1';
const LISTED = 'OcuProbe2418b1Listed';
const LIST_URL = '/ocupilot/interoperability/hl7-schemas?ns=USER';
const LIST_ROUTE = 'interoperability/hl7-schemas';
const ADD_PATH = '/api/ocupilot/interop/hl7-schemas';
const ACTION_PATH = '/api/ocupilot/screens/interop.hl7schemas/action';
/** The cells of the list: the name, the base, the description, the standard mark and the time it was changed. */
const NAME_CELL = 0;
const BASE_CELL = 1;
const DESCRIPTION_CELL = 2;
const STANDARD_CELL = 3;

const { structural, rowOf, rowPresent, rowAction, dialogClosed, fill, openList, openPrimary } = interopListHelpers(config, NAME_CELL);

let browser = null;
let localDirectory = '';
let created = false;

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** The stored schema as `base|description|standard`, `<absent>` when `USER` does not hold it. */
function stored(name) {
  return probe('H7TEXT', `##class(${FIXTURE}).Text("${name}")`).value;
}

/** Wait, up to ten probes, until `read` answers `<absent>` (`absent` true) or something else; answers the last reading. */
async function settled(read, absent) {
  let last = read();
  for (let tries = 0; (last === '<absent>') !== absent && tries < 10; tries += 1) {
    await new Promise((resolve) => setTimeout(resolve, 500));
    last = read();
  }
  return last;
}

/** Remove every probe schema this spec makes, in both namespaces, whatever an earlier step left. */
function drop() {
  const cleared = probe('H7DROP', `##class(${FIXTURE}).DropProbes()`);
  assert.equal(cleared.value, '1', `the probes are removed: ${cleared.output}`);
}

const schemaField = (name) => `[data-interop-hl7-schema-field="${name}"]`;

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
    (wanted) => document.querySelector('[data-interop-hl7-transfer-status]')?.textContent.trim() === wanted,
    { timeout: config.navigationTimeoutMs },
    line
  );
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

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec writes probe HL7 schemas, so it runs only in a throwaway; ${config.container} is not one`);
  drop();
  created = true;
  localDirectory = mkdtempSync(join(tmpdir(), 'epic-24-hl7-'));
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (localDirectory !== '') rmSync(localDirectory, { recursive: true, force: true });
    if (created && /-ci$/.test(config.container)) drop();
  } finally {
    if (browser !== null) await browser.close();
  }
});

// Mutation (Rule 19): drop the descriptor's primary action, regenerate the mirror, rebuild and redeploy -> the command bar offers none and the New HL7 schema assertion goes red.
test('HL7 schemas lists a probe schema under the published headers, with its base and description, and the walk passes', async () => {
  drop();
  const made = probe('H7LIST', `$System.Status.IsOK(##class(${FIXTURE}).ProbeSchema("${LISTED}","USER","2.5.1","Browser schema"))`);
  assert.equal(made.value, '1', `the probe schema is arranged: ${made.output}`);
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  try {
    await openList(page);
    await rowPresent(page, LISTED);
    const headers = await page.$$eval('.ocu-data-table-header-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(
      headers.slice(0, 5),
      [STRINGS.tableColumnName, STRINGS.interopHl7ColumnBase, STRINGS.tableColumnDescription, STRINGS.interopHl7ColumnStandard, STRINGS.analyticsColumnModified],
      'the declared headers'
    );
    const row = await rowOf(page, LISTED);
    assert.deepEqual([row[NAME_CELL], row[BASE_CELL], row[DESCRIPTION_CELL]], [LISTED, '2.5.1', 'Browser schema'], 'the schema reads its name, base and description');
    assert.equal(row[STANDARD_CELL], STRINGS.tableStatusNo, 'and is marked as not standard');
    assert.equal(await page.$eval('.ocu-command-bar button.ocu-command-bar-primary', (node) => node.textContent.trim()), STRINGS.interopHl7SchemaAddAction, 'the command bar offers New HL7 schema');
    assert.deepEqual(await structural(page, LIST_ROUTE), [], 'HL7 schemas: no violation beyond the baseline\'s entries');
  } finally {
    await context.close();
    drop();
  }
});

// AC10. Mutation (Rule 19): make the New HL7 schema dialog send no base, rebuild and redeploy -> the stored base reads empty and this goes red.
test('AC10: a person adds a schema based on 2.5.1, exports it to this browser, deletes it typing its name, and imports the saved file from this computer', async () => {
  drop();
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const adds = [];
  const actions = [];
  page.on('request', (request) => {
    if (request.method() !== 'POST') return;
    const path = new URL(request.url()).pathname;
    const body = JSON.parse(request.postData() ?? '{}');
    if (path === ADD_PATH) adds.push(body);
    if (path === ACTION_PATH) actions.push(body);
  });
  try {
    await openList(page);
    await captureDownloads(page);

    // The schema is added through New HL7 schema, based on 2.5.1.
    await openPrimary(page, schemaField('Name'));
    const opened = await page.evaluate(() => ({
      title: document.querySelector('[role="dialog"] .ocu-dialog-title')?.textContent?.trim(),
      text: document.querySelector('[role="dialog"]').textContent,
    }));
    assert.equal(opened.title, STRINGS.interopHl7SchemaAddAction, 'the dialog is titled with the published words');
    assert.ok(opened.text.includes(STRINGS.interopHl7Help), 'and says what a custom schema adds');
    await fill(page, schemaField('Name'), SCHEMA);
    await page.select(schemaField('Base'), '2.5.1');
    await fill(page, schemaField('Description'), 'Browser schema');
    await page.click('[data-interop-hl7-schema-confirm]');
    await dialogClosed(page);
    await rowPresent(page, SCHEMA);
    assert.deepEqual(adds.at(-1), { Name: SCHEMA, Base: '2.5.1', Description: 'Browser schema' }, 'the Save carries the name, the base and the description');
    assert.equal(await settled(() => stored(SCHEMA), false), '2.5.1|Browser schema|0', 'the schema is stored with what was typed, and is not standard');
    const added = await rowOf(page, SCHEMA);
    assert.deepEqual([added[BASE_CELL], added[DESCRIPTION_CELL]], ['2.5.1', 'Browser schema'], 'and the list shows its base and description');

    // It is exported to this browser, which saves <schema>.xml.
    const before = stored(SCHEMA);
    await rowAction(page, SCHEMA, STRINGS.taskExportAction);
    await page.waitForSelector('app-explorer-export-dialog .ocu-dialog-title', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('app-explorer-export-dialog .ocu-dialog-title', (node) => node.textContent.trim()), STRINGS.interopHl7ExportTitle.replace('<schema>', SCHEMA), 'the export dialog is titled by the schema');
    await pickerRoot(page);
    await page.click('input[data-explorer-export-destination="browser"]');
    await page.waitForFunction(() => document.querySelector('.ocu-dialog-body .ocu-path-picker') === null, { timeout: config.navigationTimeoutMs });
    await page.click('[data-explorer-export-confirm]');
    await statusReads(page, STRINGS.interopHl7ExportSaved.replace('<schema>', SCHEMA).replace('<file>', `${SCHEMA}.xml`));
    assert.deepEqual(actions.at(-1), { action: 'export-browser', id: SCHEMA }, 'one export to this browser, naming no file');
    await page.waitForFunction(() => window.__ocuSaved.length === 1, { timeout: config.navigationTimeoutMs });
    const saved = await page.evaluate(() => window.__ocuSaved[0]);
    assert.equal(saved.name, `${SCHEMA}.xml`, 'the browser saves <schema>.xml');
    assert.equal(saved.type, 'application/xml');
    assert.ok(saved.text.includes(`<Document name="${SCHEMA}.HL7">`), 'the file is the vendor\'s export of that one .HL7 document');
    assert.ok(saved.text.includes('Browser schema'), 'and holds the description the schema was given');

    // It is deleted after typing its name.
    await rowAction(page, SCHEMA, STRINGS.actionDelete);
    await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    const removal = await page.evaluate(() => ({
      title: document.querySelector('[role="dialog"] .ocu-dialog-title').textContent.trim(),
      consequence: document.querySelector('.ocu-typed-name-consequence').textContent.trim(),
    }));
    assert.deepEqual(removal, { title: STRINGS.interopHl7DeleteTitle.replace('<schema>', SCHEMA), consequence: STRINGS.interopHl7DeleteConsequence }, 'Delete asks for the name and states what deleting the schema does');
    const sent = actions.length;
    await page.type('.ocu-typed-name-field', SCHEMA);
    await page.keyboard.press('Enter');
    await dialogClosed(page);
    await rowPresent(page, SCHEMA, false);
    assert.equal(actions.length, sent + 1, 'one delete was sent');
    assert.deepEqual(actions.at(-1), { action: 'delete', id: SCHEMA }, 'with the row key once the name matched');
    assert.equal(await settled(() => stored(SCHEMA), true), '<absent>', 'the schema is gone from the instance');

    // The saved file is imported from this computer, which restores the schema as it was.
    const local = join(localDirectory, `${SCHEMA}.xml`);
    writeFileSync(local, saved.text, 'utf8');
    await commandBar(page, STRINGS.actionImport);
    assert.ok((await pickerRoot(page)) !== '', 'the dialog opens on the server file, its picker drawn');
    assert.equal(await page.$eval('app-explorer-import-dialog .ocu-dialog-title', (node) => node.textContent.trim()), STRINGS.interopHl7ImportTitle, 'the import dialog is titled in the schema\'s words');
    assert.equal(await page.$eval('[data-explorer-import-replaces]', (node) => node.textContent.trim()), STRINGS.interopHl7ImportConsequence, 'it states that the schema of the same name is replaced');
    await page.click('input[data-explorer-import-source="local"]');
    await page.waitForSelector('input[data-explorer-import-file]', { timeout: config.navigationTimeoutMs });
    const input = await page.$('input[data-explorer-import-file]');
    await input.uploadFile(local);
    await page.waitForFunction(() => document.querySelector('[data-explorer-import-confirm]')?.getAttribute('aria-disabled') === null, { timeout: config.navigationTimeoutMs });
    await page.click('[data-explorer-import-confirm]');
    await statusReads(page, STRINGS.interopHl7ImportDone.replace('<file>', `${SCHEMA}.xml`));
    const imported = actions.at(-1);
    assert.deepEqual([imported.action, imported.id, imported.values.fileName], ['import-local', SCHEMA, `${SCHEMA}.xml`], 'one local import, on the schema the file names');
    assert.equal(imported.values.content, saved.text, 'carrying the file\'s text');
    await rowPresent(page, SCHEMA);
    assert.equal(await settled(() => stored(SCHEMA), false), before, 'the schema is back on the instance as it was');
    const restored = await rowOf(page, SCHEMA);
    assert.deepEqual([restored[BASE_CELL], restored[DESCRIPTION_CELL]], ['2.5.1', 'Browser schema'], 'and the list shows its base and description again');
  } finally {
    await context.close();
    drop();
  }
});

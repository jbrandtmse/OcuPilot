/**
 * Story 21.19 in a real browser, against the throwaway instance: the Resources list exports a resource of the spec's own and imports it back (AD-5, AD-21, AD-53).
 *
 * What it pins: the spec's own resource's row Export, to a server file through the export dialog, which offers a server file alone and reports the count; the
 * instance holds the resource's record in that file; after the spec deletes the resource, the screen's Import of that file restores it with the description and
 * permission it had; and a local import of a file naming one of OcuPilot's own resources with a public permission it does not hold shows the refusal in the
 * dialog and changes nothing.
 *
 * **It writes only its own resource**, `OcuPilotProbeResourceTransfer`, which it deletes first and again after, and the files `OcuPilot.Test.ExplorerTransferProbe`
 * names, so it runs on a throwaway only.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1 browser/resources-transfer.browser-spec.mjs` (after `npm run build`
 * and the bundle copied into the throwaway).
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
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const NAME = 'OcuPilotProbeResourceTransfer';
const PROBE = 'OcuPilot.Test.ExplorerTransferProbe';
const DESCRIPTION = 'OcuPilot transfer probe';
const listRoute = '/ocupilot/permissions/resources?ns=HSCUSTOM';

let browser = null;
let localDirectory = '';

/** One expression in `%SYS` on the throwaway, answering its marker. */
function probe(name, lines) {
  const output = runIris(config.container, ['Set $NAMESPACE="%SYS"', ...lines, `Write "OCU-${name}-START:"_result_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** One expression in the product's namespace on the throwaway, where OcuPilot's own classes are, answering its marker. */
function product(name, lines) {
  const output = runIris(config.container, [...lines, `Write "OCU-${name}-START:"_result_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** Make the spec's resource afresh: public permission R, the description above. */
const makeResource = () => probe('RTMAKE', [`If ##class(Security.Resources).Exists("${NAME}") Do ##class(Security.Resources).Delete("${NAME}")`, `Set result=$System.Status.IsOK(##class(Security.Resources).Create("${NAME}","${DESCRIPTION}","R"))`]);

/** The spec's resource as `description|bits`, or `<none>`. */
const readResource = () => probe('RTREAD', [`If ##class(Security.Resources).Exists("${NAME}",.r) { Set result=r.Description_"|"_r.PublicPermission } Else { Set result="<none>" }`]).value;

const deleteResource = () => probe('RTDEL', [`If ##class(Security.Resources).Exists("${NAME}") Do ##class(Security.Resources).Delete("${NAME}")`, 'Set result=1']);

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec writes a resource, so it runs only in a throwaway; ${config.container} is not one`);
  deleteResource();
  const made = product('RTDIR', [`Set tSC=##class(${PROBE}).RemoveDirectory()`, `If tSC Set tSC=##class(${PROBE}).MakeDirectory()`, 'Set result=$System.Status.IsOK(tSC)']);
  assert.equal(made.value, '1', `the probe directory is made: ${made.output}`);
  localDirectory = mkdtempSync(join(tmpdir(), 'epic-21-pm24-'));
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    deleteResource();
    product('RTCLEAN', [`Set tSC=##class(${PROBE}).RemoveDirectory()`, 'Set result=$System.Status.IsOK(tSC)']);
  } finally {
    if (browser !== null) await browser.close();
    if (localDirectory !== '') rmSync(localDirectory, { recursive: true, force: true });
  }
});

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

/** Wait until the page's status line reads `line`. */
function statusReads(page, line) {
  return page.waitForFunction((wanted) => document.querySelector('[data-resource-transfer-status]')?.textContent.trim() === wanted, { timeout: config.navigationTimeoutMs }, line);
}

/** Filter the list to the spec's resource and select its row. */
async function selectResourceRow(page) {
  await waitForRows(page, config.navigationTimeoutMs);
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, NAME);
  await page.waitForFunction(
    (rowSelector, wanted) => {
      // The list has narrowed once only a few rows stand, so an index read now is the narrowed list's.
      const rows = [...document.querySelectorAll(rowSelector)];
      return rows.length <= 3 && rows.some((row) => row.querySelector('[role="gridcell"]')?.textContent.trim().startsWith(wanted));
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    NAME
  );
  const at = await page.$$eval(ROW_SELECTOR, (rows, wanted) => rows.findIndex((row) => row.querySelector('[role="gridcell"]')?.textContent.trim().startsWith(wanted)), NAME);
  assert.ok(at >= 0, `${NAME} is listed`);
  await clickRowCentre(page, { index: at, cell: 2 });
  await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs });
}

/** The open dialog's server-path picker, ready on its one root: the root it offers. */
async function pickerRoot(page) {
  await page.waitForSelector('.ocu-dialog-body .ocu-path-picker select', { timeout: config.navigationTimeoutMs });
  return page.$eval('.ocu-dialog-body .ocu-path-picker select', (select) => select.value);
}

// Mutation (Rule 19): drop the `export` registration in `resource-list.page.ts` (rebuilt and redeployed) -> the row menu offers no Export and this goes red.
test('the resource is exported from its row to a server file, deleted, and imported back from the Import dialog, as it was', async () => {
  assert.equal(makeResource().value, '1', 'the spec\'s own resource is made afresh');
  const before = readResource();
  assert.equal(before, `${DESCRIPTION}|1`, 'it reads with its description and public permission');
  const file = product('RTREL', [`Set result=##class(${PROBE}).RelativeName("resource.xml")`]).value;
  const { context, page } = await signedInAt(browser, config, listRoute, VIEWPORTS.wide);
  const posts = [];
  page.on('request', (request) => {
    if (new URL(request.url()).pathname === '/api/ocupilot/screens/permissions.resources/action') posts.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    await selectResourceRow(page);
    await rowMenu(page, STRINGS.taskExportAction);
    await page.waitForSelector('app-explorer-export-dialog .ocu-dialog-title', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('app-explorer-export-dialog .ocu-dialog-title', (node) => node.textContent.trim()), STRINGS.resourceExportTitle, 'the dialog is titled with the ruled words');
    assert.equal(await page.$('input[data-explorer-export-destination="browser"]'), null, 'and offers a server file alone');
    const root = await pickerRoot(page);
    assert.ok(root !== '', 'the picker offers an allowed root');
    await page.type('.ocu-dialog-body .ocu-path-picker input[type="text"]', file);
    await page.click('[data-explorer-export-confirm]');
    await statusReads(page, STRINGS.resourceExportDone.replace('<path>', `${root}${file}`).replace('<count>', '1'));
    assert.deepEqual(posts.at(-1), { action: 'export', id: NAME, values: { root, path: file } }, 'one export of the selected resource, naming the file');
    assert.equal(product('RTFILE', [`Set result=##class(${PROBE}).FileExists("resource.xml")`]).value, '1', 'the file is on the instance');
    assert.ok(product('RTTEXT', [`Set result=(##class(${PROBE}).ReadFile("resource.xml")["<Name>${NAME}</Name>")`]).value === '1', 'and holds the resource\'s record');

    deleteResource();
    assert.equal(readResource(), '<none>', 'the resource is deleted');
    await commandBar(page, STRINGS.actionImport);
    await page.waitForSelector('app-explorer-import-dialog .ocu-dialog-title', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('app-explorer-import-dialog .ocu-dialog-title', (node) => node.textContent.trim()), STRINGS.resourceImportTitle, 'the import dialog is titled with the ruled words');
    assert.equal(await page.$eval('[data-explorer-import-replaces]', (node) => node.textContent.trim()), STRINGS.resourceImportReplaces, 'and states what an import overwrites');
    assert.equal(await pickerRoot(page), root, 'it opens on the server file');
    await page.type('.ocu-dialog-body .ocu-path-picker input[type="text"]', file);
    await page.click('[data-explorer-import-confirm]');
    await statusReads(page, STRINGS.resourceImportDone.replace('<count>', '1'));
    assert.deepEqual(posts.at(-1), { action: 'import', id: 'import', values: { root, path: file } }, 'one import of the file, on the one target');
    assert.equal(readResource(), before, 'the instance holds the resource as it was');
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): drop the `TASK_IMPORT_ACTION_ID` registration in `resource-list.page.ts` (rebuilt and redeployed) -> the command bar draws no Import and this goes red.
test('a local import naming an OcuPilot resource with a public permission it does not hold shows the refusal in the dialog and changes nothing', async () => {
  const own = product('RTOWN', ['Set tSC=##class(OcuPilot.Kernel.Proposal.Prohibited).OcuPilotResources(.tOwn)', 'Set result=$ListGet(tOwn,1)']).value;
  assert.ok(own !== '', 'the kernel names an own resource');
  const heldBefore = probe('RTHELD', [`Do ##class(Security.Resources).Exists("${own}",.r)`, 'Set result=r.PublicPermission']).value;
  const local = join(localDirectory, 'own.xml');
  writeFileSync(local, `<?xml version="1.0" encoding="UTF-8"?><ResourcesExport><Resources><Description>x</Description><Name>${own}</Name><PublicPermission>7</PublicPermission><Type>2147483648</Type><Version>2</Version></Resources></ResourcesExport>`, 'utf8');
  const { context, page } = await signedInAt(browser, config, listRoute, VIEWPORTS.wide);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await commandBar(page, STRINGS.actionImport);
    await page.waitForSelector('app-explorer-import-dialog .ocu-dialog-title', { visible: true, timeout: config.navigationTimeoutMs });
    // The picker's answer re-centres the dialog and moves the source radio, so it is pressed once the picker is drawn.
    await pickerRoot(page);
    await page.click('input[data-explorer-import-source="local"]');
    await page.waitForSelector('input[data-explorer-import-file]', { timeout: config.navigationTimeoutMs });
    await (await page.$('input[data-explorer-import-file]')).uploadFile(local);
    await page.waitForFunction(() => document.querySelector('[data-explorer-import-confirm]')?.getAttribute('aria-disabled') === null, { timeout: config.navigationTimeoutMs });
    await page.click('[data-explorer-import-confirm]');
    await page.waitForSelector('[data-explorer-transfer-refusal]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.ok((await page.$eval('[data-explorer-transfer-refusal]', (node) => node.textContent.trim())).length > 0, 'a sentence is shown in the dialog');
    assert.equal(probe('RTHELD2', [`Do ##class(Security.Resources).Exists("${own}",.r)`, 'Set result=r.PublicPermission']).value, heldBefore, 'and the own resource is as it was');
  } finally {
    await context.close();
  }
});

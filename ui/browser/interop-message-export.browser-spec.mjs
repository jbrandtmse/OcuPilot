/**
 * Story 24.16 Batch 3 in a real browser, against the throwaway instance: exporting two checked messages from the Messages screen (AD-5, AD-8, AD-13, AD-39,
 * AD-47, AD-53, AD-62).
 *
 * What it pins, in `USER`, with an HL7 message and an XML-adaptor message stored by `OcuPilot.Test.InteropMessageExportFixture`:
 *
 * - AC6: the two rows are checked and Export is chosen; the dialog titles itself for two messages, lists each message's line with the verdict "will be exported", offers
 *   the instance's separators and character sets with CRLF and UTF8 preselected and states what an export does; Export saves one file, `USER-messages.txt`, in this
 *   browser's downloads, which holds both bodies in id order, the status line names the two messages and the file, the dialog closes and the rows are unchecked.
 *
 * **It stores probe messages in `USER` and writes no production**, so it runs on a throwaway only. Its `after` hook removes every probe message and body and
 * checks that nothing is left.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/interop-message-export.browser-spec.mjs` (after `npm run build` and the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { ROW_SELECTOR, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const FIXTURE = 'OcuPilot.Test.InteropMessageExportFixture';
const NAMESPACE = 'USER';
const MESSAGES_URL = `/ocupilot/interoperability/messages?ns=${NAMESPACE}`;
const REDUCED_MOTION = [{ name: 'prefers-reduced-motion', value: 'reduce' }];
const FILE_NAME = `${NAMESPACE}-messages.txt`;

let browser = null;
let created = false;
let downloads = '';

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** Store a probe message of `kind` and answer its header id. */
function store(kind, suffix) {
  const { value, output } = probe('EXMAKE', `##class(${FIXTURE}).Store("${NAMESPACE}","${kind}","${suffix}")`);
  assert.match(value ?? '', /^[1-9]\d*$/, `the ${kind} probe message is stored: ${output}`);
  return value;
}

/** Wait until the table holds a row for every id of `ids`. */
function rowsHold(page, ids) {
  return page.waitForFunction(
    (rowSelector, wanted) => {
      const found = new Set(Array.from(document.querySelectorAll(rowSelector)).map((row) => row.querySelector('[role="gridcell"]')?.textContent.trim() ?? ''));
      return wanted.every((id) => found.has(id));
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    ids
  );
}

/** Check the row of message `id`. */
async function checkRow(page, id) {
  const checked = await page.evaluate(
    (rowSelector, wanted) => {
      const row = Array.from(document.querySelectorAll(rowSelector)).find((candidate) => (candidate.querySelector('[role="gridcell"]')?.textContent ?? '').trim() === wanted);
      const box = row?.querySelector('.ocu-data-table-check');
      if (box === null || box === undefined) return false;
      box.click();
      return true;
    },
    ROW_SELECTOR,
    id
  );
  assert.ok(checked, `the row of message ${id} has a check box`);
}

/** Press the command bar's action named `label`. */
async function pressAction(page, label) {
  try {
    await page.waitForFunction(
      (wanted) => Array.from(document.querySelectorAll('.ocu-command-bar button')).some((button) => button.textContent.trim() === wanted && button.getAttribute('aria-disabled') !== 'true'),
      { timeout: config.navigationTimeoutMs },
      label
    );
  } catch (error) {
    const drawn = await page.$$eval('.ocu-command-bar button', (buttons) => buttons.map((button) => `${button.textContent.trim()}:${button.getAttribute('aria-disabled')}`));
    throw new Error(`the command bar offers no available '${label}' (it draws ${drawn.join(' | ')}): ${error.message}`);
  }
  await page.evaluate((wanted) => Array.from(document.querySelectorAll('.ocu-command-bar button')).find((button) => button.textContent.trim() === wanted).click(), label);
}

/** Wait for the file the browser saves to appear in the download directory and answer its bytes. */
async function savedFile() {
  const path = join(downloads, FILE_NAME);
  const deadline = Date.now() + config.navigationTimeoutMs;
  while (Date.now() < deadline) {
    if (existsSync(path) && !existsSync(`${path}.crdownload`)) return readFileSync(path);
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error(`the browser saved no ${FILE_NAME} in ${downloads}`);
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec stores probe messages, so it runs only in a throwaway; ${config.container} is not one`);
  created = true;
  downloads = mkdtempSync(join(tmpdir(), 'ocu-export-'));
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (created && /-ci$/.test(config.container)) {
      const gone = probe('EXGONE', `##class(${FIXTURE}).DropProbes()_"|"_##class(${FIXTURE}).Left()`);
      assert.equal(gone.value, '1|headers=0/0 bodies=0', `no probe message or body is left in either namespace: ${gone.output}`);
    }
  } finally {
    if (browser !== null) await browser.close();
    if (downloads !== '') rmSync(downloads, { recursive: true, force: true });
  }
});

// AC6. Mutation (Rule 19): the page saves the outcome lines in place of the file, rebuild and redeploy -> the saved bytes leg goes red; leave `Reviewed` out of the
// action's values, rebuild and redeploy -> the export is refused and the status leg goes red.
test('AC6: a person checks two messages and exports them, the browser saves one file holding both bodies and the status line names the count', async () => {
  const hl7 = store('hl7', 'b1');
  const xml = store('xml', 'b2');
  const { context, page } = await signedInAt(browser, config, MESSAGES_URL, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    // The page's context is its own browser context, so the download behavior names it.
    const session = await browser.target().createCDPSession();
    await session.send('Browser.setDownloadBehavior', { behavior: 'allow', downloadPath: downloads, browserContextId: context.id });
    await waitForMapAnswered(page, config.navigationTimeoutMs);
    await waitForRows(page, config.navigationTimeoutMs);
    await rowsHold(page, [hl7, xml]);
    await checkRow(page, hl7);
    await checkRow(page, xml);
    await pressAction(page, STRINGS.taskExportAction);
    await page.waitForSelector('[role="dialog"] [data-interop-export-line]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[role="dialog"] .ocu-dialog-title', (title) => title.textContent.trim()), STRINGS.interopMessageExportTitle.replace('<n>', '2'), 'the title counts the two messages');
    const lines = await page.$$eval('[role="dialog"] [data-interop-export-line]', (items) => items.map((item) => item.textContent));
    assert.equal(lines.length, 2, `the dialog lists one line for each message: ${lines.join(' | ')}`);
    for (const [line, id] of [[lines[0], hl7], [lines[1], xml]]) {
      assert.ok(line.startsWith(`${id} `) && line.endsWith(`: ${STRINGS.interopExportVerdictExport}`), `the line of message ${id} reads "will be exported": ${line}`);
    }
    assert.equal(await page.$eval('[data-interop-export-consequence]', (node) => node.textContent.trim()), STRINGS.interopMessageExportConsequence, 'the dialog states what an export does');
    assert.equal(await page.$eval('[data-interop-export-separator]', (select) => select.value), 'CRLF', 'CRLF is preselected');
    assert.equal(await page.$eval('[data-interop-export-charset]', (select) => select.value), 'UTF8', 'UTF8 is preselected');
    const charsets = await page.$$eval('[data-interop-export-charset] option', (options) => options.map((option) => option.value));
    assert.ok(charsets.includes('CP1252'), `the instance's own character sets are offered: ${charsets.join(' ')}`);
    await page.evaluate(() => document.querySelector('[data-interop-export-confirm]').click());
    const bytes = await savedFile();
    const text = bytes.toString('latin1');
    assert.ok(text.includes('MSH|^~\\&|PROBE'), 'the file holds the HL7 body');
    assert.ok(text.includes('ZqExportSentinel2416 xml'), 'and the XML body');
    assert.ok(text.indexOf('MSH|') < text.indexOf('<?xml'), 'in message id order');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    const status = await page.$eval('[data-interop-export-status]', (node) => node.textContent.trim());
    assert.equal(status, STRINGS.interopMessageExportSaved.replace('<n>', '2').replace('<file>', FILE_NAME), 'the status line names the two messages and the file');
  } finally {
    await context.close();
  }
});

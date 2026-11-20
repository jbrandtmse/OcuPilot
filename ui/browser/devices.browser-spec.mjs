/**
 * The Devices list in a real browser, against the throwaway instance (Story 6.12): the declared
 * read, table and headers end to end (AC7), and the `|TRM|` name cell reading that text literally
 * rather than being mangled by percent-encoding or markup escaping.
 *
 * **It needs no fixture and creates nothing.** A stock instance always carries its console
 * devices (`0`, `2`, the terminal and spool queues among them), so the list is never empty here;
 * the true empty state and the string set behind it are `ui/tools/strings.test.mjs`'s. It creates
 * no security principal -- AC4's pair set is proven over HTTP by
 * `OcuPilot.Test.WireSecurityRead`.
 *
 * Run: `npm run test:browser` (after `npm run build` and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { ROW_SELECTOR, clickRowCentre, filterToSubset, viewCount, waitForRows } from './list-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const LIST_URL = '/ocupilot/os-management/devices?ns=HSCUSTOM';
const READ_PATH = '/api/ocupilot/screens/osmgmt.devices/read';

let browser = null;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec drives the throwaway, never the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
});

/** A fresh context signed in through the shell's own form at the list's deep link. */
async function signedInAtList(user, password) {
  // Story 15.5: the remembered screen and shell state lives on the instance now, keyed by the
  // one account every spec signs in as, so a fresh context is no longer a fresh slate on its
  // own -- see `preferences-reset.mjs`.
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  const reads = [];
  page.on('request', (request) => {
    if (new URL(request.url()).pathname.startsWith('/api/ocupilot/screens/')) reads.push(request.url());
  });
  await page.goto(`${config.origin}${LIST_URL}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', user);
  await page.type('#ocu-signin-password', password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, LIST_URL);
  return { context, page, reads };
}

/** Every rendered row, cell by cell, in row order. */
function describeRows(page) {
  return page.evaluate((rowSelector) => {
    const rows = Array.from(document.querySelectorAll(rowSelector));
    return rows.map((row) => Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim()));
  }, ROW_SELECTOR);
}

test('AC7: the list reads once under the declared six headers, in order, with one row per device', async () => {
  const { context, page, reads } = await signedInAtList(config.username, config.password);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const headers = await page.$$eval('.ocu-data-table-header-label', (labels) => labels.map((label) => label.textContent.trim()));
    assert.deepEqual(headers, [
      STRINGS.tableColumnName,
      STRINGS.deviceColumnPhysical,
      STRINGS.tableColumnType,
      STRINGS.deviceColumnSubtype,
      STRINGS.tableColumnDescription,
      STRINGS.x509ColumnAlias,
      STRINGS.commandBoxGroupActions,
    ]);
    assert.deepEqual(headers, ['Name', 'Physical device', 'Type', 'Subtype', 'Description', 'Alias', 'Actions']);

    const total = await viewCount(page);
    assert.ok(total >= 1, `the instance configures at least one device: ${total}`);

    const rows = await describeRows(page);
    for (const cells of rows) {
      assert.equal(cells.length, 7, `every row carries six cells and the actions menu's trigger: ${JSON.stringify(cells)}`);
      assert.notEqual(cells[0], '', 'Name is never blank');
    }

    assert.equal(reads.length, 1, `exactly one screen read was issued: ${JSON.stringify(reads)}`);
    assert.equal(new URL(reads[0]).pathname, READ_PATH);
  } finally {
    await context.close();
  }
});

// Story 21.20, AC2 (DW-1562). Mutation (Rule 19): drop `SCREENACTIONS` from `DeviceDelete.cls` -> the list draws no Delete and the
// menu wait goes red. The leg creates one probe device of its own, deletes it from the list by typing its name, and removes the
// device itself if the screen's delete did not.
test('Story 21.20 AC2: Delete on a row states the consequence, releases on the typed name, and removes the device', async () => {
  assert.match(config.container, /-ci$/, `this leg creates and deletes a probe device, so it runs only in a throwaway; ${config.container} is not one`);
  const name = `OcuPilotProbe88Br${Date.now()}`;
  const created = runIris(config.container, [
    `Set tSC=##class(OcuPilot.Test.DeviceProbe).Add("${name}") Write "OCU-DEVADD-START:",$Select($System.Status.IsOK(tSC):"ok",1:$System.Status.GetErrorText(tSC)),":OCU-DEVADD-END",!`,
  ]);
  assert.equal(markerValue(created, 'DEVADD'), 'ok', `the probe device is created: ${created.slice(-400)}`);
  const { context, page } = await signedInAtList(config.username, config.password);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const total = await viewCount(page);
    await filterToSubset(page, { text: name, expectRow: name, total, timeoutMs: config.navigationTimeoutMs });
    // The first cell is the name, whose link opens the editor, so the row is selected by its Type cell.
    await clickRowCentre(page, { index: 0, cell: 2 });
    await page.waitForFunction((selector) => document.querySelector(selector) !== null, { timeout: config.navigationTimeoutMs }, `${ROW_SELECTOR}[aria-selected="true"]`);
    await page.click(`${ROW_SELECTOR}[aria-selected="true"] .ocu-data-table-trigger`);
    await page.waitForSelector('[role="menu"]', { timeout: config.navigationTimeoutMs });
    await page.evaluate((wanted) => {
      const items = Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'));
      items.find((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted).click();
    }, STRINGS.actionDelete);
    await page.waitForSelector('.ocu-typed-name-field', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-typed-name-consequence', (node) => node.textContent.trim()), STRINGS.deviceDeleteConsequence, 'the dialog states the published consequence');
    await page.type('.ocu-typed-name-field', name);
    await page.waitForFunction(() => document.querySelector('.ocu-button-destructive')?.getAttribute('aria-disabled') === null, { timeout: config.navigationTimeoutMs });
    await page.click('.ocu-button-destructive');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await page.waitForFunction(
      (rowSelector, wanted) => !Array.from(document.querySelectorAll(rowSelector)).some((row) => row.textContent.includes(wanted)),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      name
    );
    const held = runIris(config.container, [`Write "OCU-DEVHELD-START:",##class(OcuPilot.Test.DeviceProbe).Holds("${name}"),":OCU-DEVHELD-END",!`]);
    assert.equal(markerValue(held, 'DEVHELD'), '0', `the configuration no longer holds the device: ${held.slice(-200)}`);
  } finally {
    await context.close();
    runIris(config.container, [`Do ##class(OcuPilot.Test.DeviceProbe).Remove("${name}")`]);
  }
});

test("AC7: the pipe-bracketed device name '|TRM|' renders literally, not percent-encoded or markup-escaped", async () => {
  const { context, page } = await signedInAtList(config.username, config.password);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const total = await viewCount(page);
    await filterToSubset(page, { text: '|TRM|', expectRow: '|TRM|', total, timeoutMs: config.navigationTimeoutMs });
    const rows = await describeRows(page);
    const row = rows.find((cells) => cells[0] === '|TRM|');
    assert.ok(row !== undefined, `a row named '|TRM|' literally is rendered: ${JSON.stringify(rows)}`);
  } finally {
    await context.close();
  }
});

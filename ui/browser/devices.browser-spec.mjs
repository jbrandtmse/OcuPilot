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
import { ROW_SELECTOR, filterToSubset, viewCount, waitForRows } from './list-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';

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
    ]);
    assert.deepEqual(headers, ['Name', 'Physical device', 'Type', 'Subtype', 'Description', 'Alias']);

    const total = await viewCount(page);
    assert.ok(total >= 1, `the instance configures at least one device: ${total}`);

    const rows = await describeRows(page);
    for (const cells of rows) {
      assert.equal(cells.length, 6, `every row carries six cells: ${JSON.stringify(cells)}`);
      assert.notEqual(cells[0], '', 'Name is never blank');
    }

    assert.equal(reads.length, 1, `exactly one screen read was issued: ${JSON.stringify(reads)}`);
    assert.equal(new URL(reads[0]).pathname, READ_PATH);
  } finally {
    await context.close();
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

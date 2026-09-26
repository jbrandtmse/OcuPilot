/**
 * The Locks list in a real browser, against the throwaway instance (Story 6.10): the declared
 * read, table and headers end to end (AC1, AC2, AC9), the empty `System` cell reading "This
 * instance" for a local lock (AC10), and the owner cell's declared `rowTarget` opening Process
 * details for that row's own `Pid` -- not the row's own composite id, its `DeleteID` -- (AC4).
 *
 * **It needs no fixture and creates nothing.** A running instance always holds at least the
 * license monitor's own lock, so the list is never empty here; the true empty state and the
 * string set behind it are `ui/tools/strings.test.mjs`'s. It creates no security principal --
 * AC7's pair set is proven over HTTP by `OcuPilot.Test.WireSecurityRead`.
 *
 * Run: `npm run test:browser` (after `npm run build` and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { ROW_SELECTOR, clickRowCentre, viewCount, waitForRows } from './list-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const LIST_URL = '/ocupilot/os-management/locks?ns=HSCUSTOM';
const READ_PATH = '/api/ocupilot/screens/osmgmt.locks/read';

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
    return rows.map((row) => ({
      cells: Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim()),
      link: row.querySelector('.ocu-data-table-link') !== null,
    }));
  }, ROW_SELECTOR);
}

test('AC1, AC2, AC9: the list reads once under the declared headers, and every row carries its seven columns', async () => {
  const { context, page, reads } = await signedInAtList(config.username, config.password);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const headers = await page.$$eval('.ocu-data-table-header-label', (labels) => labels.map((label) => label.textContent.trim()));
    assert.deepEqual(headers, [
      STRINGS.processColumnPid,
      STRINGS.processColumnUser,
      STRINGS.processColumnRoutine,
      STRINGS.lockColumnMode,
      STRINGS.lockColumnReference,
      STRINGS.lockColumnDirectory,
      STRINGS.lockColumnSystem,
    ]);
    assert.deepEqual(headers, ['Process ID', 'User', 'Routine', 'Mode', 'Reference', 'Directory', 'System']);

    const total = await viewCount(page);
    assert.ok(total >= 1, `the instance holds at least one lock (the license monitor's own): ${total}`);

    const rows = await describeRows(page);
    for (const row of rows) {
      assert.equal(row.cells.length, 7, `every row carries seven cells: ${JSON.stringify(row)}`);
      assert.notEqual(row.cells[0], '', 'Pid is never blank');
    }
    // AC10: a local lock's own scope marker is empty, and the emptyKey rule renders it as the
    // instance's own name rather than "(none)".
    assert.ok(
      rows.some((row) => row.cells[6] === STRINGS.lockSystemLocal),
      `at least one local lock's System cell reads "${STRINGS.lockSystemLocal}": ${JSON.stringify(rows)}`
    );
    assert.equal(STRINGS.lockSystemLocal, 'This instance');

    assert.equal(reads.length, 1, `exactly one screen read was issued: ${JSON.stringify(reads)}`);
    assert.equal(new URL(reads[0]).pathname, READ_PATH);
  } finally {
    await context.close();
  }
});

test("AC4: the owner cell opens Process details for that row's Pid, encoded once, not the row's own composite removal id", async () => {
  const { context, page } = await signedInAtList(config.username, config.password);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const rows = await describeRows(page);
    assert.ok(rows.length >= 1, 'at least one row is rendered');
    assert.equal(rows[0].link, true, "the first row's owner cell is a link");
    const pid = rows[0].cells[0];

    // A real hit-tested pointer click at the first row's link (DW-273), which is what a user does.
    await clickRowCentre(page, { index: 0, link: true });
    await page.waitForFunction(
      () => /^\/ocupilot\/os-management\/processes\/details\/[^/]+$/.test(window.location.pathname),
      { timeout: config.navigationTimeoutMs }
    );
    const routeId = new URL(page.url()).pathname.split('/').pop();
    assert.equal(routeId, pid, "the route id is the row's own Pid -- fieldOf(row, 'Pid'), not rowKey(row, screen)'s DeleteID");
    // Process details renders for a pid that is still alive; a RemoteOwner row (DW-1074) would
    // answer "This process no longer exists." instead, which is accepted and not this row's case
    // for a local instance's own locks.
    await page.waitForSelector('.ocu-details-fields, .ocu-empty-state', { timeout: config.navigationTimeoutMs });
  } finally {
    await context.close();
  }
});

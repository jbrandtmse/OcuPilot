/**
 * Story 21.20's Transactions in a real browser, against the throwaway instance (AC3): OS management's list of the open
 * transactions the System Monitor records. The screen answers its rows under the declared headers, or its empty state, once
 * its read has answered; and a read that answers a local and a remote row draws the local row's Process ID as a link to
 * Process details and the remote row's as text.
 *
 * The first leg reads the instance as it is, so it asserts on whichever of the two answers comes and never expects a
 * transaction to be open. The second answers the screen's read itself, with one local and one remote row, so the link
 * rule is pinned without holding a transaction open on the instance. It creates nothing and signs in and resets the
 * account's remembered state, so it runs on a throwaway only.
 *
 * Run: `node --test --test-concurrency=1 browser/transactions.browser-spec.mjs` (after `npm run build`, the bundle copied
 * into the throwaway, and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { ROW_SELECTOR, waitForRows } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const ROUTE = 'os-management/transactions';
const PAGE_URL = `/ocupilot/${ROUTE}?ns=HSCUSTOM`;
const READ_PATH = '/api/ocupilot/screens/osmgmt.transactions/read';

let browser = null;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec never runs against the live container');
  await assertThrowaway(config);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
});

/** Every rendered row's cells, in row order. */
function describeRows(page) {
  return page.evaluate((rowSelector) => {
    const rows = Array.from(document.querySelectorAll(rowSelector));
    return rows.map((row) => ({
      cells: Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim()),
      link: row.querySelector('.ocu-data-table-link') !== null,
    }));
  }, ROW_SELECTOR);
}

// AC3. The headers are pinned by the next test, which answers the read itself, so this one carries no mutation of its own.
test('AC3: the screen answers its rows under the declared headers, or its empty state, once its read has answered', async () => {
  const { context, page } = await signedInAt(browser, config, PAGE_URL, VIEWPORTS.wide);
  try {
    await page.waitForFunction(
      (rowSelector) => document.querySelector(rowSelector) !== null || document.querySelector('.ocu-data-table-empty-title') !== null,
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR
    );
    const rows = await describeRows(page);
    if (rows.length === 0) {
      assert.equal(await page.$eval('.ocu-data-table-empty-title', (node) => node.textContent.trim()), STRINGS.transactionsEmpty, 'with no open transaction the screen says so');
    } else {
      const headers = await page.$$eval('.ocu-data-table-header-label', (labels) => labels.map((label) => label.textContent.trim()));
      assert.deepEqual(headers, [STRINGS.processColumnPid, STRINGS.agentLedgerColumnKind, STRINGS.transactionsColumnSeconds, STRINGS.taskHistoryColumnStatus]);
    }
  } finally {
    await context.close();
  }
});

// AC3. Mutation (Rule 19): remove `"unless": "Remote"` from `TransactionList.cls` and regenerate the mirror -> the remote row's
// Process ID is a link and the link leg goes red. Mutation (Rule 19): rename the `Seconds` column's label key in
// `TransactionList.cls` and regenerate the mirror -> the header leg goes red.
test("AC3: a local row's Process ID opens Process details, a remote row's is text, and the columns are headed as declared", async () => {
  const { context, page } = await signedInAt(browser, config, PAGE_URL, VIEWPORTS.wide);
  try {
    let answered = 0;
    await page.setRequestInterception(true);
    page.on('request', (request) => {
      if (new URL(request.url()).pathname === READ_PATH) {
        answered += 1;
        const rows = [
          { Kind: 'Local', ProcessID: '4101', Seconds: 42, Status: 'Normal', Remote: false },
          { Kind: 'Remote', ProcessID: 'node-b:77', Seconds: 9, Status: 'Warning', Remote: true },
        ];
        void request.respond({ status: 200, contentType: 'application/json', body: JSON.stringify({ rows, truncated: false }) });
        return;
      }
      void request.continue();
    });
    await page.goto(`${config.origin}${PAGE_URL}`, { waitUntil: 'networkidle0', timeout: config.navigationTimeoutMs });
    await waitForRows(page, config.navigationTimeoutMs);
    const rows = await describeRows(page);
    assert.ok(answered > 0, `the screen's read went to ${READ_PATH} and this test answered it`);
    const headers = await page.$$eval('.ocu-data-table-header-label', (labels) => labels.map((label) => label.textContent.trim()));
    assert.deepEqual(headers, [STRINGS.processColumnPid, STRINGS.agentLedgerColumnKind, STRINGS.transactionsColumnSeconds, STRINGS.taskHistoryColumnStatus], 'the columns are headed as the screen declares them');
    assert.equal(rows.length, 2, `both rows are drawn: ${JSON.stringify(rows)}`);
    const local = rows.find((row) => row.cells[0] === '4101');
    const remote = rows.find((row) => row.cells[0] === 'node-b:77');
    assert.ok(local !== undefined && remote !== undefined, `each row carries its Process ID: ${JSON.stringify(rows)}`);
    assert.deepEqual(local.cells.slice(1, 4), ['Local', '42', 'Normal'], 'the local row reads its kind, seconds and status');
    assert.deepEqual(remote.cells.slice(1, 4), ['Remote', '9', 'Warning'], 'and the remote row its own');
    assert.equal(local.link, true, "the local row's Process ID is a link");
    assert.equal(remote.link, false, "and the remote row's is text");
  } finally {
    await context.close();
  }
});

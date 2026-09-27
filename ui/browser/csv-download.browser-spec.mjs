/**
 * Download CSV in a real browser, against the throwaway instance (Story 16.23): the file a filtered,
 * descending Web applications list saves -- its name, BOM, header and rows against the grid's own --
 * (AC1), the control on Upcoming tasks, a page that mounts the data table itself (AC3), and the cap
 * description and a capped file at Max rows 2 (AC4).
 *
 * The browser saves through CDP `Browser.setDownloadBehavior` into a temporary directory, which is
 * read from disk and removed. It needs nothing the stock container does not hold, and it changes
 * nothing on the instance but the remembered Max rows, which the cap leg restores.
 *
 * Run: `npm run test:browser` (after `npm run build` and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readdir, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { browserConfig, launchOptions } from '../browser.config.mjs';
import { filterToSubset, viewCount, waitForRows } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const LIST_URL = '/ocupilot/web-applications/list?ns=HSCUSTOM';
const UPCOMING_URL = '/ocupilot/tasks/upcoming?ns=HSCUSTOM';
const DOWNLOAD = 'app-command-bar .ocu-command-bar-download';
const SORT_TRIGGER = '#ocu-command-bar-sort-trigger';
const SORT_ITEM = '.ocu-command-bar-sort-item';
const MAX_ROWS = '.ocu-data-table-max-rows';

let browser = null;

before(async () => {
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
});

/** Let `context` save downloads into a fresh temporary directory, and answer the directory. */
async function allowDownloads(context) {
  const dir = await mkdtemp(join(tmpdir(), 'ocupilot-csv-'));
  const cdp = await browser.target().createCDPSession();
  await cdp.send('Browser.setDownloadBehavior', { behavior: 'allow', downloadPath: dir, browserContextId: context.id });
  return dir;
}

/** Press Download CSV and answer the one finished file's name and bytes. */
async function download(page, dir) {
  await page.click(DOWNLOAD);
  const deadline = Date.now() + config.navigationTimeoutMs;
  for (;;) {
    const names = (await readdir(dir)).filter((name) => name.endsWith('.csv'));
    if (names.length === 1) return { name: names[0], bytes: await readFile(join(dir, names[0])) };
    assert.ok(Date.now() < deadline, `a CSV file landed in ${dir}: ${JSON.stringify(await readdir(dir))}`);
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
}

/** RFC 4180 records of the file's text after its BOM, with the formula guard's apostrophe removed. */
function records(bytes) {
  const text = bytes.subarray(3).toString('utf8');
  const out = [];
  let record = [];
  let field = '';
  let quoted = false;
  const push = () => {
    record.push(/^'[=+\-@\t\r]/.test(field) ? field.slice(1) : field);
    field = '';
  };
  for (let at = 0; at < text.length; at += 1) {
    const ch = text[at];
    if (quoted) {
      if (ch === '"' && text[at + 1] === '"') {
        field += '"';
        at += 1;
      } else if (ch === '"') quoted = false;
      else field += ch;
    } else if (ch === '"') quoted = true;
    else if (ch === ',') push();
    else if (ch === '\r' && text[at + 1] === '\n') {
      push();
      out.push(record);
      record = [];
      at += 1;
    } else field += ch;
  }
  return out;
}

/** The footer's row count, as a number. */
async function footerCount(page) {
  const text = await page.$eval('.ocu-data-table-count', (node) => node.textContent.trim());
  return Number(text.replace(/[^0-9]/g, ''));
}

async function chooseSort(page, label) {
  await page.click(SORT_TRIGGER);
  await page.waitForSelector(SORT_ITEM, { timeout: config.navigationTimeoutMs });
  const chosen = await page.evaluate(
    (selector, wanted) => {
      const item = Array.from(document.querySelectorAll(selector)).find((candidate) => candidate.textContent.trim() === wanted);
      if (item === undefined) return false;
      item.click();
      return true;
    },
    SORT_ITEM,
    label
  );
  assert.ok(chosen, `the sort menu offers ${JSON.stringify(label)}`);
  await page.waitForFunction((selector) => document.querySelector(selector) === null, {}, SORT_ITEM);
}

async function setMaxRows(page, value) {
  await page.click(MAX_ROWS, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(MAX_ROWS, value);
  await page.keyboard.press('Enter');
}

test('AC1: a filtered, descending Web applications list saves its view: name, BOM, header labels and the grid rows', async () => {
  const { context, page } = await signedInAt(browser, config, LIST_URL);
  const dir = await allowDownloads(context);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const total = await viewCount(page);
    await filterToSubset(page, { text: '/api/', expectRow: '/api/atelier', total, timeoutMs: config.navigationTimeoutMs });
    await chooseSort(page, STRINGS.sortDirectionDescending);
    await page.waitForSelector(`[role="columnheader"][aria-sort="descending"]`, { timeout: config.navigationTimeoutMs });
    await page.waitForSelector(DOWNLOAD, { visible: true, timeout: config.navigationTimeoutMs });

    const grid = await page.evaluate(() => {
      const headers = Array.from(document.querySelectorAll('.ocu-data-table-header-label:not(.ocu-data-table-hidden-label)')).map(
        (label) => label.textContent.trim()
      );
      const rows = Array.from(document.querySelectorAll('.ocu-data-table-body [role="row"]'))
        .sort((a, b) => Number(a.getAttribute('aria-rowindex')) - Number(b.getAttribute('aria-rowindex')))
        .map((row) => ({
          index: Number(row.getAttribute('aria-rowindex')) - 2,
          cells: Array.from(row.querySelectorAll('[role="gridcell"]:not(.ocu-data-table-cell-trigger)')).map((cell) =>
            cell.querySelector('.ocu-data-table-empty-value') !== null ? '' : cell.textContent.trim()
          ),
        }));
      return { headers, rows };
    });
    const count = await footerCount(page);
    const { name, bytes } = await download(page, dir);

    assert.match(name, /^web-applications-\d{8}-\d{6}\.csv$/, 'the file is named for the screen and the local time');
    assert.deepEqual(Array.from(bytes.subarray(0, 3)), [0xef, 0xbb, 0xbf], 'the file starts with the UTF-8 BOM');
    const [header, ...body] = records(bytes);
    assert.deepEqual(header, grid.headers, "the header row is the header cells' labels, in order");
    assert.equal(body.length, count, "the file holds the footer's count of rows");
    assert.ok(grid.rows.length > 0 && grid.rows[0].index === 0, 'the grid rendered from its first row');
    for (const row of grid.rows) {
      assert.deepEqual(body[row.index], row.cells, `row ${row.index} is the grid's row, cell for cell`);
    }
  } finally {
    await context.close();
    await rm(dir, { recursive: true, force: true });
  }
});

test('AC3: Upcoming tasks, a page that mounts the data table itself, shows Download CSV once its read lands', async () => {
  const { context, page } = await signedInAt(browser, config, UPCOMING_URL);
  try {
    await page.waitForSelector('.ocu-data-table-grid, .ocu-data-table-empty', { timeout: config.navigationTimeoutMs });
    await page.waitForSelector(DOWNLOAD, { visible: true, timeout: config.navigationTimeoutMs });
    const label = await page.$eval(DOWNLOAD, (node) => node.textContent.trim());
    assert.equal(label, STRINGS.tableDownloadCsv);
  } finally {
    await context.close();
  }
});

test('AC4: at Max rows 2 the control is described by the cap sentence and the file holds 2 rows', async () => {
  const { context, page } = await signedInAt(browser, config, LIST_URL);
  const dir = await allowDownloads(context);
  let prior = '';
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await page.waitForSelector(DOWNLOAD, { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval(DOWNLOAD, (node) => node.getAttribute('aria-describedby')), null, 'below the cap there is no description');
    prior = await page.$eval(MAX_ROWS, (node) => node.value);
    await setMaxRows(page, '2');
    await page.waitForSelector('.ocu-data-table-cap-notice', { timeout: config.navigationTimeoutMs });
    await page.waitForFunction((selector) => document.querySelector(selector)?.hasAttribute('aria-describedby'), { timeout: config.navigationTimeoutMs }, DOWNLOAD);

    const description = await page.$eval(DOWNLOAD, (node) => {
      const reason = document.getElementById(node.getAttribute('aria-describedby'));
      return { text: reason?.textContent.trim() ?? null, role: reason?.getAttribute('role') ?? null };
    });
    assert.deepEqual(description, { text: 'The file holds the first 2 rows only.', role: 'tooltip' });

    const { bytes } = await download(page, dir);
    assert.equal(records(bytes).length - 1, 2, 'the capped file holds two data rows');
  } finally {
    if (prior !== '') {
      await setMaxRows(page, prior).catch(() => {});
      await page
        .waitForFunction(() => document.querySelector('.ocu-data-table-cap-notice') === null, { timeout: config.navigationTimeoutMs })
        .catch(() => {});
    }
    await context.close();
    await rm(dir, { recursive: true, force: true });
  }
});

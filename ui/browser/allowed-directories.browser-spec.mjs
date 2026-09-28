/**
 * The Allowed directories list in a real browser, against the throwaway instance (Story 18.1): the
 * declared read, table and headers end to end on a fresh instance, where the one row is the manager
 * directory, and on an instance whose `%GUIFileSelector` allow-list is restricted to two roots
 * (AC1); and the screen passing the structural walk in both themes (AC4, DW-1337).
 *
 * **It changes the instance's allow-list**, so it runs on a throwaway only: it clears the purpose
 * before each leg, sets it up through `OcuPilot.Test.PathPortFixture` over `docker exec`, and clears
 * it again when it ends, which is how a fresh instance has it. It creates no security principal --
 * AC2's pair set is proven over HTTP by `OcuPilot.Test.PathPortPrivilege`.
 *
 * Run: `node --test --test-concurrency=1 browser/allowed-directories.browser-spec.mjs` (after
 * `npm run build`, the bundle copied into the throwaway, and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { ROW_SELECTOR, viewCount, waitForRows } from './list-spec.mjs';
import { authHeader, signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const ROUTE = 'security/allowed-directories';
const LIST_URL = `/ocupilot/${ROUTE}?ns=HSCUSTOM`;
const READ_PATH = '/api/ocupilot/screens/security.alloweddirectories/read';
const FIXTURE = 'OcuPilot.Test.PathPortFixture';

let browser = null;

/** Run one allow-list helper inside the throwaway and require it to answer OK. */
function allowList(call) {
  const output = runIris(config.container, [`Set sc=##class(${FIXTURE}).${call} Write "OCU-PATHSC-START:",$Select($System.Status.IsOK(sc):"ok",1:$System.Status.GetErrorText(sc)),":OCU-PATHSC-END",!`]);
  assert.equal(markerValue(output, 'PATHSC'), 'ok', `${call} answered: ${output}`);
}

/** One value the instance computes, read through a marker. */
function instanceValue(expression) {
  const output = runIris(config.container, [`Write "OCU-PATHVAL-START:",${expression},":OCU-PATHVAL-END",!`]);
  const value = markerValue(output, 'PATHVAL');
  assert.ok(value, `${expression} answered: ${output}`);
  return value;
}

before(async () => {
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec changes the instance's allow-list, so it runs only in a throwaway; ${config.container} is not one`);
  allowList('Clear()');
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (/-ci$/.test(config.container)) allowList('Clear()');
  } finally {
    if (browser !== null) await browser.close();
  }
});

/** Signed in at the list, its rows rendered. */
async function atList() {
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  await waitForRows(page, config.navigationTimeoutMs);
  return { context, page };
}

/** The rows the screen's own read answers, through the route the page reads. */
async function routeRows() {
  const answer = await fetch(`${config.origin}${READ_PATH}?maxRows=1000&ns=HSCUSTOM`, {
    headers: { Authorization: authHeader(config) },
  });
  assert.equal(answer.status, 200, `the read route answers (HTTP ${answer.status})`);
  return (await answer.json()).rows;
}

/** Every rendered row, cell by cell, in row order. */
function describeRows(page) {
  return page.evaluate((rowSelector) => {
    const rows = Array.from(document.querySelectorAll(rowSelector));
    return rows.map((row) => Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim()));
  }, ROW_SELECTOR);
}

async function headers(page) {
  return page.$$eval('.ocu-data-table-header-label', (labels) => labels.map((label) => label.textContent.trim()));
}

test('AC1, fresh: with no allow-list the one row is the manager directory, unrestricted, under the two declared headers', async () => {
  allowList('Clear()');
  const manager = instanceValue('$System.Util.ManagerDirectory()');
  assert.deepEqual(await routeRows(), [{ Directory: manager, Restricted: false }], 'the read route answers the one root');
  const { context, page } = await atList();
  try {
    assert.deepEqual(await headers(page), [STRINGS.lockColumnDirectory, STRINGS.allowedDirectoriesColumnRestricted]);
    assert.equal(await viewCount(page), 1, 'one root');
    const rows = await describeRows(page);
    assert.deepEqual(rows.map((cells) => cells.slice(0, 2)), [[manager, STRINGS.tableStatusNo]], `the manager directory, not restricted: ${JSON.stringify(rows)}`);
  } finally {
    await context.close();
  }
});

test('AC1, restricted: an allow-list restricted to two roots lists exactly those two, restricted, and not the manager directory', async () => {
  allowList('SetUp(1,$ListBuild("/tmp/",$System.Util.InstallDirectory()))');
  const install = instanceValue('$System.Util.InstallDirectory()');
  const { context, page } = await atList();
  try {
    assert.equal(await viewCount(page), 2, 'two roots');
    const rows = await describeRows(page);
    assert.deepEqual(
      rows.map((cells) => cells.slice(0, 2)),
      [
        ['/tmp/', STRINGS.tableStatusYes],
        [install, STRINGS.tableStatusYes],
      ],
      `the two roots in the declared order, each restricted: ${JSON.stringify(rows)}`
    );
  } finally {
    await context.close();
    allowList('Clear()');
  }
});

test('Matrix "Restricted, empty": an allow-list restricted to no root shows the empty state and no row', async () => {
  allowList('SetUp(1,"")');
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  try {
    await page.waitForSelector('.ocu-data-table-empty-title', { timeout: config.navigationTimeoutMs });
    const title = await page.$eval('.ocu-data-table-empty-title', (element) => element.textContent.trim());
    assert.equal(title, STRINGS.allowedDirectoriesEmpty, 'the empty state names the allow-list');
    assert.equal((await page.$$(ROW_SELECTOR)).length, 0, 'and no row is drawn');
  } finally {
    await context.close();
    allowList('Clear()');
  }
});

test('AC4 (DW-1337): the list passes the structural walk at wide light, narrow light and wide dark', async () => {
  allowList('Clear()');
  const found = [];
  const minimums = componentMinimums();
  const passes = [
    { viewport: VIEWPORTS.wide, theme: 'light', checks: INVARIANTS },
    { viewport: VIEWPORTS.narrow, theme: 'light', checks: ['name', 'min-width', 'overflow'] },
    { viewport: VIEWPORTS.wide, theme: 'dark', checks: ['contrast'] },
  ];
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    for (const { viewport, theme, checks } of passes) {
      await page.setViewport(viewport);
      await page.evaluate((isDark) => document.documentElement.classList.toggle('ocu-theme-dark', isDark), theme === 'dark');
      await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
      const { entries } = await detectScreen(page, { route: ROUTE, checks, viewport: viewport.width, theme, minimums });
      found.push(...entries);
    }
  } finally {
    await context.close();
  }
  const fresh = compare(collapse(found), readBaseline()?.entries ?? []).fresh;
  assert.deepEqual(fresh.map((entry) => `${entry.key}: ${entry.measured}`), [], 'no violation beyond the baseline');
});

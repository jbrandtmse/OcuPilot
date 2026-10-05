/**
 * Story 19.10's SQL activity in a real browser, against the throwaway instance (AC1, AC4, AC5, AC6,
 * AC8).
 *
 * What it pins: a probe statement running in USER is a row under the declared headers, carrying its
 * Process ID, Namespace, a numeric Elapsed and its Statement text, and never the value it binds; its
 * Process ID cell opens Process details for that pid; the command bar's auto-refresh chip starts off
 * and offers 5, 10, 30 and 60 s; and the screen passes the structural and contrast checks at 1280
 * light, 720 light and 1280 dark, with no entry beyond the baseline (DW-1337).
 *
 * It starts one probe job (`OcuPilot.Test.SqlActivityProbe.Start`, a read-only statement that ends
 * itself within 600 s) before the first test and stops it after the last, and it signs in and resets
 * the account's remembered state, so it runs on a throwaway only.
 *
 * Run: `node --test --test-concurrency=1 browser/sql-activity.browser-spec.mjs` (after `npm run build`,
 * the bundle copied into the throwaway, and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const ROUTE = 'os-management/sql-activity';
const PAGE_URL = `/ocupilot/${ROUTE}?ns=HSCUSTOM`;
const PROBE = 'OcuPilot.Test.SqlActivityProbe';
const LITERAL = `OcuSeedBrowser1910${Date.now()}`;
const VALUE = `OcuSecretProbe1910Browser${Date.now()}`;

let browser = null;
let pid = null;

before(async () => {
  await assertThrowaway(config);
  const output = runIris(config.container, [
    `Set tSC=##class(${PROBE}).Start("USER","${LITERAL}","${VALUE}",.tPid) Write "OCU-SQLPROBE-START:",$Select($System.Status.IsOK(tSC):tPid,1:"error "_$System.Status.GetErrorText(tSC)),":OCU-SQLPROBE-END",!`,
  ]);
  const started = markerValue(output, 'SQLPROBE');
  assert.match(started ?? '', /^[0-9]+$/, `the probe job starts: ${output.slice(-400)}`);
  pid = started;
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (pid !== null) {
    const output = runIris(config.container, [
      `Set tSC=##class(${PROBE}).Stop(${pid}) Write "OCU-SQLSTOP-START:",$Select($System.Status.IsOK(tSC):"ok",1:$System.Status.GetErrorText(tSC)),":OCU-SQLSTOP-END",!`,
    ]);
    assert.equal(markerValue(output, 'SQLSTOP'), 'ok', `the probe job is stopped: ${output.slice(-400)}`);
  }
});

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

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

/** Signed in at SQL activity with its rows rendered. */
async function atSqlActivity() {
  const { context, page } = await signedInAt(browser, config, PAGE_URL, VIEWPORTS.wide);
  await waitForRows(page, config.navigationTimeoutMs);
  return { context, page };
}

// AC1, AC4. Mutation (Rule 19): set no `Namespace` in `OcuPilot.Port.SqlActivityPort.Rows` -> the
// probe row's Namespace cell reads "(none)" and the row leg goes red.
test("AC1, AC4: the probe is a row under the declared headers, with its Process ID, Namespace, Elapsed and Statement, and its bound value is nowhere on the page", async () => {
  const { context, page } = await atSqlActivity();
  try {
    const headers = await page.$$eval('.ocu-data-table-header-label', (labels) => labels.map((label) => label.textContent.trim()));
    assert.deepEqual(headers, [
      STRINGS.processColumnPid,
      STRINGS.processColumnUser,
      STRINGS.headerNamespaceLabel,
      STRINGS.sqlActivityColumnRunType,
      STRINGS.sqlActivityColumnElapsed,
      STRINGS.explorerSqlColumnStatement,
      STRINGS.processColumnRoutine,
      STRINGS.taskHistoryColumnStarted,
    ]);
    const rows = await describeRows(page);
    const row = rows.find((candidate) => candidate.cells[0] === pid);
    assert.ok(row !== undefined, `the probe ${pid} is a row: ${JSON.stringify(rows)}`);
    assert.equal(row.cells[2], 'USER', 'in USER');
    assert.match(row.cells[4], /^[0-9.,]+$/, `with a numeric elapsed time: ${row.cells[4]}`);
    assert.ok(row.cells[5].includes(LITERAL), `and the statement's text, carrying its literal: ${row.cells[5]}`);
    assert.equal(row.link, true, 'its Process ID cell is a link');
    const note = await page.evaluate(() => document.body.textContent);
    assert.ok(note.includes(STRINGS.sqlActivityNote), 'the note says whose statement text shows');
    assert.ok(!note.includes(VALUE), 'the bound value is nowhere on the page');
  } finally {
    await context.close();
  }
});

// AC5. Mutation (Rule 19): remove `rowTarget` from `SqlActivityList.cls` and regenerate the mirror ->
// the Process ID cell is text and the link leg goes red.
test("AC5: the probe's Process ID cell opens Process details for that pid", async () => {
  const { context, page } = await atSqlActivity();
  try {
    await clickRowCentre(page, { text: pid, link: true });
    await page.waitForFunction(
      () => /^\/ocupilot\/os-management\/processes\/details\/[^/]+$/.test(window.location.pathname),
      { timeout: config.navigationTimeoutMs }
    );
    assert.equal(new URL(page.url()).pathname.split('/').pop(), pid, "the route id is the row's ProcessID");
  } finally {
    await context.close();
  }
});

// AC6. Mutation (Rule 19): declare `refreshes` false on `SqlActivityList.cls` -> no chip renders and
// the chip wait goes red.
test('AC6: the refresh chip starts off with no rate remembered, and offers 5, 10, 30 and 60 s', async () => {
  const { context, page } = await atSqlActivity();
  try {
    await page.waitForSelector('.ocu-command-bar-refresh', { timeout: config.navigationTimeoutMs });
    const chip = await page.$('.ocu-command-bar-refresh');
    assert.equal(await page.$eval('.ocu-command-bar-refresh', (button) => button.textContent.trim()), STRINGS.statusAutoRefreshOff, 'the chip reads off');
    for (const rate of [5, 10, 30, 60]) {
      await chip.click();
      await page.waitForFunction(
        (wanted) => document.querySelector('.ocu-command-bar-refresh').textContent.trim() === wanted,
        { timeout: config.navigationTimeoutMs },
        STRINGS.statusAutoRefreshOn.replace('<n>', String(rate))
      );
    }
    await chip.click();
    await page.waitForFunction(
      (wanted) => document.querySelector('.ocu-command-bar-refresh').textContent.trim() === wanted,
      { timeout: config.navigationTimeoutMs },
      STRINGS.statusAutoRefreshOff
    );
  } finally {
    await context.close();
  }
});

// AC8: the DW-1337 gate, with no new allowance.
test('AC8: SQL activity passes DW-1337 wide and narrow, light and dark, with no entry beyond the baseline', async () => {
  const { context, page } = await atSqlActivity();
  try {
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
      surfaces[theme] = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
      const { entries } = await detectScreen(page, { route: ROUTE, checks, viewport: viewport.width, theme, minimums });
      found.push(...entries);
    }
    assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
    const fresh = compare(collapse(found), readBaseline()?.entries ?? []).fresh.map((entry) => `${entry.key}: ${entry.measured}`);
    assert.deepEqual(fresh, [], 'no violation beyond the baseline');
  } finally {
    await context.close();
  }
});

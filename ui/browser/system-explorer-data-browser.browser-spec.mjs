/**
 * Story 19.7 in a real browser, against the throwaway: Data browser in USER lists the probe schema in
 * its tree, expands it to its tables and its views, the view marked, and opens the 40-row probe table
 * to its first page (AC1, AC3); a wildcard filter applied with Enter narrows it and Escape clears it
 * (AC4); a header activated twice sorts it descending, `aria-sort` set (AC5); a keyed table's header
 * carries its key marker (AC2); and the page with rows passes the structural walk's checks at 1280
 * light, 720 light and 1280 dark, with no entry beyond the baseline (AC10).
 *
 * AC11 (Integration): a table SQL query (Story 19.6) creates and fills in USER, each statement
 * confirmed, is read into the tree through SQL tables' declared read (Story 19.5) and opens to its
 * row.
 *
 * The probe objects are `OcuPilot.Test.SqlBrowseProbe`'s, made in `before` and removed in `after`
 * with the table AC11 creates, and `after` asserts none is left. Needs the throwaway: it refuses the
 * live container.
 *
 * Run: `node --test --test-concurrency=1 browser/system-explorer-data-browser.browser-spec.mjs` (after
 * `npm run build`, the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const PROBE = 'OcuPilot.Test.SqlBrowseProbe';
const SCHEMA = 'OcuProbe197';
const MADE = 'OcuProbe197.Made';
const ROUTE = 'system-explorer/sql-data';
const QUERY_ROUTE = 'system-explorer/sql-query';

/** The walk's own media feature (`structural-walk.mjs`): a theme flip lands at once rather than mid-transition. */
const REDUCED_MOTION = [{ name: 'prefers-reduced-motion', value: 'reduce' }];

let browser = null;

const marker = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/** Drop the AC11 table and remove the probe objects; whether nothing of the probe schema is left. */
function removeProbe() {
  const output = runIris(config.container, [
    'Set $NAMESPACE="USER"',
    `Do ##class(%SQL.Statement).%ExecDirect(,"DROP TABLE ${MADE}")`,
    'Set $NAMESPACE=$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"):"HSCUSTOM",1:"USER")',
    marker('REMOVED', `$System.Status.GetErrorText(##class(${PROBE}).Remove())`),
  ]);
  return markerValue(output, 'REMOVED') === '';
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates and drops SQL tables, so it never runs inside the live container');
  await assertThrowaway(config);
  assert.ok(removeProbe(), 'USER holds no probe object before the run');
  const output = runIris(config.container, [marker('MADE', `$System.Status.GetErrorText(##class(${PROBE}).Make())`)]);
  assert.equal(markerValue(output, 'MADE'), '', 'the probe objects are made');
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  assert.ok(removeProbe(), 'no probe object is left in USER');
});

function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/** The walk of the screen on display at three passes, answering entries outside the baseline. */
async function structural(page, route) {
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
    const { entries } = await detectScreen(page, { route, checks, viewport: viewport.width, theme, minimums });
    found.push(...entries);
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await frames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  return compare(collapse(found), readBaseline()?.entries ?? []).fresh.map((entry) => `${entry.key}: ${entry.measured}`);
}

/** Wait until the status line reads `text`. */
async function statusReads(page, text) {
  await page.waitForFunction(
    (wanted) => (document.querySelector('[data-ocu-data="status"]')?.textContent ?? '').trim() === wanted,
    { timeout: config.navigationTimeoutMs },
    text
  );
}

/** Click the tree node whose label reads `text` exactly, under `slot`. */
async function clickNode(page, slot, text) {
  await page.waitForFunction(
    (selector, wanted) => Array.from(document.querySelectorAll(selector)).some((node) => node.querySelector('.ocu-data-browser-tree-name')?.textContent.trim() === wanted),
    { timeout: config.navigationTimeoutMs },
    `[data-ocu-data="${slot}"]`,
    text
  );
  await page.evaluate(
    (selector, wanted) => {
      const node = Array.from(document.querySelectorAll(selector)).find((candidate) => candidate.querySelector('.ocu-data-browser-tree-name')?.textContent.trim() === wanted);
      node.click();
    },
    `[data-ocu-data="${slot}"]`,
    text
  );
}

/** The first column's cells, in order. */
function firstColumn(page) {
  return page.$$eval('[data-ocu-data="row"]', (rows) => rows.map((row) => row.querySelector('[role="gridcell"]')?.textContent.trim() ?? ''));
}

test('AC1-AC5, AC10: the tree opens the probe table, its filter, its sort and its key marker, and the page passes the walk', async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${ROUTE}?ns=USER`, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await page.waitForSelector('[data-ocu-data="empty"]', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-ocu-data="empty"]', (node) => node.textContent.trim()), STRINGS.explorerSqlDataPick, 'the empty state until a table opens');
    await clickNode(page, 'tree-schema', SCHEMA);
    await page.waitForFunction(() => document.querySelectorAll('[data-ocu-data="tree-object"]').length >= 2, { timeout: config.navigationTimeoutMs });
    const objects = await page.$$eval('[data-ocu-data="tree-object"]', (nodes) => nodes.map((node) => node.textContent.replace(/\s+/g, '').trim()));
    assert.ok(objects.includes('Plain') && objects.includes('Keyed'), `the schema's tables are listed: ${JSON.stringify(objects)}`);
    assert.ok(objects.includes(`Over30${STRINGS.viewMenuLabel}`), `and its views, marked: ${JSON.stringify(objects)}`);
    assert.ok(objects.indexOf('Plain') < objects.indexOf(`Over30${STRINGS.viewMenuLabel}`), 'tables before views');

    await clickNode(page, 'tree-object', 'Plain');
    await statusReads(page, 'Rows 1\u201340 of 40');
    assert.equal(await page.$eval('[data-ocu-data="heading"]', (node) => node.textContent.trim()), `${SCHEMA}.Plain`, 'the open table is the heading');
    assert.equal(await page.$eval('[role="grid"]', (node) => node.getAttribute('aria-rowcount')), '41', 'aria-rowcount is the total plus the header');
    assert.deepEqual(await structural(page, ROUTE), [], 'Data browser with rows adds no structural entry');

    await page.focus('input[data-ocu-data="filter"][data-column="Name"]');
    await page.keyboard.type('n3*');
    await page.keyboard.press('Enter');
    await statusReads(page, 'Rows 1\u201311 of 11');
    const narrowed = await firstColumn(page);
    assert.deepEqual([...narrowed].sort(), ['n3', 'n30', 'n31', 'n32', 'n33', 'n34', 'n35', 'n36', 'n37', 'n38', 'n39'], 'n3* is n3 and n30 to n39');
    await page.keyboard.press('Escape');
    await statusReads(page, 'Rows 1\u201340 of 40');

    const numHeader = '[role="columnheader"][data-column="Num"]';
    await page.click(numHeader);
    await page.waitForFunction((selector) => document.querySelector(selector)?.getAttribute('aria-sort') === 'ascending', { timeout: config.navigationTimeoutMs }, numHeader);
    await page.click(numHeader);
    await page.waitForFunction((selector) => document.querySelector(selector)?.getAttribute('aria-sort') === 'descending', { timeout: config.navigationTimeoutMs }, numHeader);
    await page.waitForFunction(() => (document.querySelector('[data-ocu-data="row"] [role="gridcell"]')?.textContent ?? '').trim() === 'n40', { timeout: config.navigationTimeoutMs });

    await clickNode(page, 'tree-object', 'Keyed');
    await page.waitForFunction(() => (document.querySelector('[data-ocu-data="heading"]')?.textContent ?? '').trim().endsWith('.Keyed'), { timeout: config.navigationTimeoutMs });
    await page.waitForSelector('[role="columnheader"][data-column="Code"] .ocu-data-browser-key-mark', { timeout: config.navigationTimeoutMs });
    assert.deepEqual(await firstColumn(page), ['c1', 'c2', 'c3'], 'an unsorted keyed page is in key order');
  } finally {
    await context.close();
  }
});

/** Replace SQL query's statement with `text`, run it, and proceed through its confirmation. */
async function runConfirmed(page, text) {
  await page.waitForSelector('textarea[data-ocu-sql="statement"]', { timeout: config.navigationTimeoutMs });
  await page.click('textarea[data-ocu-sql="statement"]', { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type('textarea[data-ocu-sql="statement"]', text);
  await page.click('button[data-ocu-sql="run"]');
  await page.waitForSelector('app-warning-dialog [role="dialog"]', { visible: true, timeout: config.navigationTimeoutMs });
  await page.click('[role="dialog"] .ocu-dialog-actions .ocu-button-primary');
  await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
}

// Mutation (Rule 19): `SqlPort.BrowseRun` answers its rows empty, recompiled on the throwaway -> the
// created table opens to "No rows." and this goes red.
test('AC11: a table SQL query creates and fills opens from the tree to its row', async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${QUERY_ROUTE}?ns=USER`, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await runConfirmed(page, `CREATE TABLE ${MADE} (X INTEGER, Label VARCHAR(20))`);
    await page.waitForFunction((done) => (document.querySelector('[data-ocu-sql="status"]')?.textContent ?? '').trim() === done, { timeout: config.navigationTimeoutMs }, STRINGS.explorerSqlDone);
    await runConfirmed(page, `INSERT INTO ${MADE} (X, Label) VALUES (7, 'made by SQL query')`);
    await page.waitForFunction(() => (document.querySelector('[data-ocu-sql="status"]')?.textContent ?? '').trim() !== '', { timeout: config.navigationTimeoutMs });

    await page.goto(`${config.origin}/ocupilot/${ROUTE}?ns=USER`, { waitUntil: 'networkidle2' });
    await clickNode(page, 'tree-schema', SCHEMA);
    await clickNode(page, 'tree-object', 'Made');
    await statusReads(page, 'Rows 1\u20131 of 1');
    const cells = await page.$$eval('[data-ocu-data="cell"]', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(cells, ['7', 'made by SQL query'], 'the row SQL query inserted shows');
  } finally {
    await context.close();
  }
});

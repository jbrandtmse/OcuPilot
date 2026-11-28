/**
 * Story 21.28 in a real browser, against the throwaway: SQL query's Alternate plans, Show plan and Compare plans (AD-7, AD-29, AD-36).
 *
 * What it pins: Alternate plans lists the probe statement's possible plans, nothing run; Show plan puts one plan's text in the plan pane with the list
 * still drawn; Compare plans with two checked plans shows two compared rows with their statistics and the ruled note.
 *
 * **Comparing runs the probe statement** once for each checked plan, so it runs on a throwaway only and records runtime statistics, a statement-index row
 * and a cached query. Its `after` hook removes the probe table by the probe's own `RemoveAlternates` and asserts that no table, cached query, statistics
 * row or statement-index row of the probe is left.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/system-explorer-sql-alternate-plans.browser-spec.mjs` (after `npm run build` and the bundle copied into
 * the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const PROBE = 'OcuPilot.Test.SqlTuningProbe';
const NS = 'HSCUSTOM';
const QUERY_ROUTE = `/ocupilot/system-explorer/sql-query?ns=${NS}`;
/** The probe's statement: a condition on each of two indexed columns, so the instance lists more than one plan. */
const STATEMENT = "SELECT A AS Probe228 FROM OcuProbe228.T WHERE B = 5 AND C = 'c5'";
/** The state an unmade probe reads: tables, cached queries, statistics rows, statement-index rows. */
const UNMADE = '0|0|0|0';

let browser = null;
let touched = false;

/** Run one probe expression in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** What the namespace holds of the probe: tables, cached queries, statistics rows, statement-index rows. */
function probeState() {
  return probe('ASTATE', `##class(${PROBE}).AlternateState("${NS}")`).value;
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec runs the probe statement and records statistics on the instance, so it runs only in a throwaway; ${config.container} is not one`);
  touched = true; // from here on, `after` removes what MakeAlternates created, even when it fails part-way
  const made = probe('AMADE', `$System.Status.IsOK(##class(${PROBE}).MakeAlternates("${NS}"))`);
  assert.equal(made.value, '1', `the probe table is created: ${made.output}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    if (touched && /-ci$/.test(config.container)) {
      const removed = probe('AGONE', `$System.Status.IsOK(##class(${PROBE}).RemoveAlternates("${NS}"))`);
      assert.equal(removed.value, '1', `the probe table is removed: ${removed.output}`);
      assert.equal(probeState(), UNMADE, 'no table, cached query, statistics row or statement-index row of the probe is left');
    }
  }
});

/** Open SQL query, write the probe's statement and choose Alternate plans; resolves once the possible plans are drawn. */
async function listPlans(page) {
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  await page.waitForSelector('textarea[data-ocu-sql="statement"]', { timeout: config.navigationTimeoutMs });
  await page.click('textarea[data-ocu-sql="statement"]', { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type('textarea[data-ocu-sql="statement"]', STATEMENT);
  assert.equal(await page.$eval('button[data-ocu-sql="alternate-plans"]', (node) => node.textContent.trim()), STRINGS.sqlAlternatePlansAction, 'the button is labeled as published');
  // Mutation (Rule 19): drop the `alternate-plans` button from `SqlQueryPage`'s template -> this wait times out.
  await page.click('button[data-ocu-sql="alternate-plans"]');
  await page.waitForSelector('[data-ocu-sql="alternate"]', { timeout: config.navigationTimeoutMs });
}

/** The cells of every row of `slot`, one array of texts per row. */
function rowsOf(page, slot) {
  return page.$$eval(`[data-ocu-sql="${slot}"]`, (nodes) => nodes.map((node) => Array.from(node.querySelectorAll('td')).map((cell) => cell.textContent.replace(/\s+/g, ' ').trim())));
}

test('AC1: Alternate plans lists the probe statement\'s possible plans with their cost, map type and starting map, and runs nothing', async () => {
  const held = probeState();
  const { context, page } = await signedInAt(browser, config, QUERY_ROUTE, VIEWPORTS.wide);
  try {
    await listPlans(page);
    const shown = await rowsOf(page, 'alternate');
    assert.ok(shown.length >= 2, `the statement has at least two possible plans: ${JSON.stringify(shown)}`);
    assert.ok(shown.every((cells) => /^[0-9]+$/.test(cells[1]) && cells[2] !== '' && cells[3] !== '' && cells[4].includes('OcuProbe228.T')), `each row shows its number, cost, map type and starting map: ${JSON.stringify(shown)}`);
    assert.equal(await page.$eval('[data-ocu-sql="alternates-hint"]', (node) => node.textContent.trim()), STRINGS.sqlAlternateHint, 'the hint under the table is as published');
    assert.equal(await page.$('[data-ocu-sql="compare-note"]'), null, 'no compare note beside a list');
    assert.equal(await page.$('[data-ocu-sql="compared-row"]'), null, 'nothing is compared by a list');
    assert.equal(probeState().split('|')[2], held.split('|')[2], 'a list records no runtime statistics');
  } finally {
    await context.close();
  }
});

test('AC2: Show plan shows one plan\'s text in the plan pane and keeps the possible plans drawn', async () => {
  const { context, page } = await signedInAt(browser, config, QUERY_ROUTE, VIEWPORTS.wide);
  try {
    await listPlans(page);
    const listed = (await rowsOf(page, 'alternate')).length;
    // Mutation (Rule 19): `SqlQueryPage.onShowPlan` sends no request -> this wait times out.
    await page.evaluate(() => document.querySelectorAll('[data-ocu-sql="show-plan"]')[1].click());
    await page.waitForSelector('[data-ocu-sql="plan"]', { timeout: config.navigationTimeoutMs });
    const plan = await page.$eval('[data-ocu-sql="plan"]', (node) => node.textContent);
    assert.match(plan, /OcuProbe228/, `the pane shows a plan of the statement's table: ${plan.slice(0, 400)}`);
    assert.equal((await rowsOf(page, 'alternate')).length, listed, 'the possible plans stay drawn');
    assert.equal(await page.$('[data-ocu-sql="compare-note"]'), null, 'no compare note beside a plan\'s text');
  } finally {
    await context.close();
  }
});

test('AC4: Compare plans with two checked plans shows two compared rows and the ruled note', async () => {
  const { context, page } = await signedInAt(browser, config, QUERY_ROUTE, VIEWPORTS.wide);
  try {
    await listPlans(page);
    assert.equal(await page.$eval('button[data-ocu-sql="compare"]', (node) => node.getAttribute('aria-disabled')), 'true', 'Compare plans waits for a checked plan');
    await page.evaluate(() => {
      for (const at of [0, 1]) document.querySelectorAll('[data-ocu-sql="alternate-check"]')[at].click();
    });
    await page.waitForFunction(() => document.querySelector('button[data-ocu-sql="compare"]')?.getAttribute('aria-disabled') === 'false', { timeout: config.navigationTimeoutMs });
    // Mutation (Rule 19): `SqlQueryPage.onCompare` sends no request (the page drops Compare plans' post) -> this wait times out.
    await page.click('button[data-ocu-sql="compare"]');
    await page.waitForFunction(() => document.querySelectorAll('[data-ocu-sql="compared-row"]').length === 2, { timeout: config.navigationTimeoutMs });
    const shown = await rowsOf(page, 'compared-row');
    assert.deepEqual(shown.map((cells) => cells[0]), ['1', '2'], `the two checked plans are compared: ${JSON.stringify(shown)}`);
    assert.ok(shown.every((cells) => /^[0-9,.]+$/.test(cells[3]) && /^[0-9,.]+$/.test(cells[6])), `each run reports its global references and rows: ${JSON.stringify(shown)}`);
    // Mutation (Rule 19): the store drops the note (`SqlQueryState.comparedAnswer` answers false) -> this wait times out.
    await page.waitForSelector('[data-ocu-sql="compare-note"]', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-ocu-sql="compare-note"]', (node) => node.textContent.trim()), STRINGS.sqlAlternateCompareNote, 'the result carries the ruled note');
    assert.equal((await rowsOf(page, 'alternate')).length >= 2, true, 'the possible plans stay drawn beside the compared plans');
  } finally {
    await context.close();
  }
  const state = probeState().split('|');
  assert.ok(Number(state[1]) > 0 && Number(state[2]) > 0 && Number(state[3]) > 0, `the compare's runs recorded a cached query, statistics rows and a statement-index row, which the after hook removes: ${state.join('|')}`);
});

/**
 * Story 21.26 in a real browser, against the throwaway: System Explorer's SQL runtime statistics list, the Runtime statistics collection list,
 * and SQL query's Plan with statistics (AD-5, AD-29, AD-7, AD-51, AD-53).
 *
 * What it pins: the list shows the probe statement's rows, one summary row and one row per module, with the columns beyond the statement; the
 * settings list shows the instance's collection level; Plan with statistics on SQL query shows each module's statistics and its run's rows reach
 * the list; Purge statistics asks, confirms and empties the list.
 *
 * **It purges the namespace's runtime statistics** through the shipped screen, so it runs on a throwaway only. It records the probe's statement in
 * its own process (`SetSQLStatsFlagJob`) and never changes the instance's collection setting, which it reads before and after. Its `after` hook
 * removes the probe's rows by routine and the probe's tables, and asserts that no statistics row of the probe is left.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/system-explorer-sql-runtime-stats.browser-spec.mjs` (after `npm run build` and the bundle copied into
 * the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const PROBE = 'OcuPilot.Test.SqlTuningProbe';
const NS = 'HSCUSTOM';
const STATS_ROUTE = `/ocupilot/system-explorer/sql-runtime-stats?ns=${NS}`;
const SETTINGS_ROUTE = `/ocupilot/system-explorer/sql-runtime-stats-settings?ns=${NS}`;
const QUERY_ROUTE = `/ocupilot/system-explorer/sql-query?ns=${NS}`;
/** The statement the list is read for, and the token every probe statement's text carries. */
const TOKEN = 'Probe226';
const PLANNED = 'SELECT B AS Probe226Plan FROM OcuProbe216.T1';
/** The list's columns, by position in a row. */
const COLUMN = { routine: 0, module: 2, runs: 3, statement: 10 };
/** The settings list's columns, by position in a row. */
const SETTING = { name: 0, value: 1 };
/** The level names the collection level shows, by the level the instance reports. */
const LEVEL_NAMES = ['Off', 'Off with collection code', 'On for open and close', 'On for all modules'];

let browser = null;
let touched = false;
let flagBefore = '';

/** Run one probe expression in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** How many runtime statistics rows the probe's statements hold in the namespace. */
function statsRows() {
  return probe('SROWS', `##class(${PROBE}).StatsRowCount("${NS}")`).value;
}

/** The instance's collection flag, as the vendor reports it. */
function collectionFlag() {
  return probe('SFLAG', `##class(%SYS.PTools.StatsSQL).GetSQLStatsFlag(0,0)`).value;
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec purges runtime statistics on the instance, so it runs only in a throwaway; ${config.container} is not one`);
  touched = true; // from here on, `after` removes what Make and RecordStats created, even when it fails part-way
  flagBefore = collectionFlag();
  assert.ok(flagBefore !== null && flagBefore !== '', `the collection flag is read before the spec starts: ${flagBefore}`);
  const made = probe('SMADE', `$System.Status.IsOK(##class(${PROBE}).Make("${NS}"))`);
  assert.equal(made.value, '1', `the probe objects are created: ${made.output}`);
  record();
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    if (touched && /-ci$/.test(config.container)) {
      probe('SCLEAR', `##class(${PROBE}).RemoveStats("${NS}")`);
      const removed = probe('SGONE', `$System.Status.IsOK(##class(${PROBE}).Remove("${NS}"))`);
      assert.equal(removed.value, '1', `the probe objects are removed: ${removed.output}`);
      assert.equal(statsRows(), '0', 'no runtime statistics row of the probe is left');
      assert.equal(probe('SROUTINES', `##class(${PROBE}).StatsRoutines("${NS}")`).value, '', 'no routine of the probe holds statistics');
      assert.equal(collectionFlag(), flagBefore, 'the instance\'s collection setting is as it was before the spec');
    }
  }
});

/** Record the probe's statement in this namespace, in a process of its own. */
function record() {
  const recorded = probe('SREC', `$System.Status.IsOK(##class(${PROBE}).RecordStats("${NS}"))`);
  assert.equal(recorded.value, '1', `the probe's statement is recorded: ${recorded.output}`);
  assert.notEqual(statsRows(), '0', 'the probe\'s statistics rows are held');
}

/** The shell has answered the navigation map and the screen drew rows. */
async function answered(page) {
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  await waitForRows(page, config.navigationTimeoutMs);
}

/** The cells of every row drawn, one array of texts per row. */
function rows(page) {
  return page.$$eval(ROW_SELECTOR, (nodes) => nodes.map((node) => Array.from(node.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim())));
}

/** The rows drawn whose statement cell carries the probe's token. */
async function probeRows(page) {
  return (await rows(page)).filter((cells) => (cells[COLUMN.statement] ?? '').includes(TOKEN));
}

/** Wait until at least `count` rows carry the probe's token. */
async function waitForProbeRows(page, count) {
  await page.waitForFunction(
    (selector, token, column, wanted) =>
      Array.from(document.querySelectorAll(selector)).filter((row) => (row.querySelectorAll('[role="gridcell"]')[column]?.textContent ?? '').includes(token)).length >= wanted,
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    TOKEN,
    COLUMN.statement,
    count
  );
}

/** The command-bar buttons' labels. */
function barLabels(page) {
  return page.$$eval('.ocu-command-bar button', (buttons) => buttons.map((button) => button.textContent.trim()));
}

/** Click the command-bar button labeled `label` once it is drawn (an element click, not a pointer event). */
async function bar(page, label) {
  await page.waitForFunction(
    (wanted) => [...document.querySelectorAll('.ocu-command-bar button')].some((button) => button.textContent.trim() === wanted),
    { timeout: config.navigationTimeoutMs },
    label
  );
  await page.evaluate((wanted) => [...document.querySelectorAll('.ocu-command-bar button')].find((button) => button.textContent.trim() === wanted).click(), label);
}

/** Confirm the warning the action opened: it states `consequence`, and the primary button sends the write. */
async function confirmWarning(page, consequence) {
  await page.waitForSelector('.ocu-warning-consequence', { visible: true, timeout: config.navigationTimeoutMs });
  assert.equal(await page.$eval('.ocu-warning-consequence', (node) => node.textContent.trim()), consequence, 'the warning states what the action does');
  await page.evaluate(() => document.querySelector('[role="dialog"] .ocu-button-primary').click());
  await page.waitForFunction(() => document.querySelector('.ocu-warning-consequence') === null, { timeout: config.navigationTimeoutMs });
}

test('AC1: the list shows the probe statement, one summary row and one row per module', async () => {
  const { context, page } = await signedInAt(browser, config, STATS_ROUTE, VIEWPORTS.wide);
  try {
    await answered(page);
    await waitForProbeRows(page, 2);
    const shown = await probeRows(page);
    assert.ok(shown.length >= 2, `the probe's statement lists a summary row and a row per module: ${JSON.stringify(shown)}`);
    assert.equal(new Set(shown.map((cells) => cells[COLUMN.routine])).size, 1, 'all of them belong to one routine');
    assert.ok(shown.some((cells) => cells[COLUMN.module] === 'INFO'), `one is the summary row, module INFO: ${JSON.stringify(shown)}`);
    assert.ok(shown.some((cells) => cells[COLUMN.module] !== 'INFO'), `and one is a module's: ${JSON.stringify(shown)}`);
    assert.ok(shown.every((cells) => /^[0-9]+$/.test(cells[COLUMN.runs])), `each shows its run count: ${JSON.stringify(shown)}`);
    assert.ok(await barLabels(page).then((labels) => labels.includes(STRINGS.sqlRuntimeStatsPurgeAction)), 'the command bar offers Purge statistics');
  } finally {
    await context.close();
  }
});

test('AC2: the settings list shows the collection level the instance reports', async () => {
  const level = Number(flagBefore.split(':')[0]);
  assert.ok(level >= 0 && level <= 3, `the flag's level is 0 to 3: ${flagBefore}`);
  const { context, page } = await signedInAt(browser, config, SETTINGS_ROUTE, VIEWPORTS.wide);
  try {
    await answered(page);
    const shown = await rows(page);
    const names = shown.map((cells) => cells[SETTING.name]);
    for (const name of ['CollectionLevel', 'StopAfterMinutes', 'LevelAfterStop', 'StopsAt']) {
      assert.ok(names.includes(name), `the list shows ${name}: ${JSON.stringify(names)}`);
    }
    const levelRow = shown.find((cells) => cells[SETTING.name] === 'CollectionLevel');
    assert.equal(levelRow[SETTING.value], LEVEL_NAMES[level], 'the level reads as the instance reports it');
  } finally {
    await context.close();
  }
});

test('AC4: Plan with statistics on SQL query shows module statistics, and the run\'s rows reach the list', async () => {
  const { context, page } = await signedInAt(browser, config, QUERY_ROUTE, VIEWPORTS.wide);
  try {
    await waitForMapAnswered(page, config.navigationTimeoutMs);
    await page.waitForSelector('textarea[data-ocu-sql="statement"]', { timeout: config.navigationTimeoutMs });
    await page.click('textarea[data-ocu-sql="statement"]', { clickCount: 3 });
    await page.keyboard.press('Backspace');
    await page.type('textarea[data-ocu-sql="statement"]', PLANNED);
    assert.equal(await page.$eval('button[data-ocu-sql="explain-stats"]', (node) => node.textContent.trim()), STRINGS.explorerSqlPlanWithStatistics, 'the button is labeled as published');
    // Mutation (Rule 19): drop the `explain-stats` button from `SqlQueryPage`'s template -> this wait times out.
    await page.click('button[data-ocu-sql="explain-stats"]');
    await page.waitForSelector('[data-ocu-sql="plan"]', { timeout: config.navigationTimeoutMs });
    const plan = await page.$eval('[data-ocu-sql="plan"]', (node) => node.textContent);
    assert.match(plan, /Stats:/, `the plan carries each module's statistics: ${plan.slice(0, 400)}`);
    // Mutation (Rule 19): `SqlQueryPage` drops the `stats-note` paragraph from its template -> this wait times out.
    await page.waitForSelector('[data-ocu-sql="stats-note"]', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-ocu-sql="stats-note"]', (node) => node.textContent.trim()), STRINGS.sqlPlanStatisticsNote, 'the result carries the ruled note about the statement running without its values');
  } finally {
    await context.close();
  }
  const listed = await signedInAt(browser, config, STATS_ROUTE, VIEWPORTS.wide);
  try {
    await answered(listed.page);
    await waitForProbeRows(listed.page, 4);
    const shown = await probeRows(listed.page);
    assert.ok(
      shown.some((cells) => cells[COLUMN.statement].includes('Probe226Plan')),
      `the planned statement's rows are on the list: ${JSON.stringify(shown)}`
    );
  } finally {
    await listed.context.close();
  }
});

test('AC6: Purge statistics asks, confirms and empties the list', async () => {
  const { context, page } = await signedInAt(browser, config, STATS_ROUTE, VIEWPORTS.wide);
  try {
    await answered(page);
    await waitForProbeRows(page, 1);
    // The command bar draws a declared action once a row is selected, though the purge names the namespace's whole store.
    const first = (await rows(page)).findIndex((cells) => (cells[COLUMN.statement] ?? '').includes(TOKEN));
    assert.ok(first >= 0, 'a row of the probe is drawn');
    await clickRowCentre(page, { index: first, cell: 2 });
    await page.waitForFunction((selector, at) => document.querySelectorAll(selector)[at]?.getAttribute('aria-selected') === 'true', { timeout: config.navigationTimeoutMs }, ROW_SELECTOR, first);
    // Mutation (Rule 19): `SqlRuntimeStatsPage` drops its `actions.register` of Purge statistics -> the command bar never draws it and this wait times out.
    await bar(page, STRINGS.sqlRuntimeStatsPurgeAction);
    await confirmWarning(page, STRINGS.sqlRuntimeStatsPurgeConsequence);
    await page.waitForFunction((selector) => document.querySelectorAll(selector).length === 0, { timeout: config.navigationTimeoutMs }, ROW_SELECTOR);
    assert.equal(statsRows(), '0', 'the instance holds none of the probe\'s statistics after the purge');
    assert.ok((await page.evaluate(() => document.body.textContent)).includes(STRINGS.explorerSqlRuntimeStatsEmpty), 'the list says the namespace holds none');
  } finally {
    await context.close();
  }
});

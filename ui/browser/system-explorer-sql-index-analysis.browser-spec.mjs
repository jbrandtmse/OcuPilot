/**
 * Story 21.27 in a real browser, against the throwaway: System Explorer's SQL index analyzer list and its Run report, Gather statements and Purge
 * analysis, and SQL query's Advise (AD-5, AD-29, AD-7, AD-51, AD-53).
 *
 * What it pins: the list shows the probe table's Index usage rows; Run report asks, confirms and lists the probe's Table scan row; Gather statements
 * asks, confirms and replaces the statements and every report's results; Advise on SQL query shows Missing index for the probe's condition; Purge
 * analysis asks, confirms and empties the list.
 *
 * **It gathers, runs and purges the namespace's index analysis** through the shipped screens, so it runs on a throwaway only. The probe is a table and a
 * class whose method holds the scanning statement, so the vendor's gathering finds it. Its `after` hook purges the analysis and removes the probe, and
 * asserts that no gathered statement and no analysis row is left.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/system-explorer-sql-index-analysis.browser-spec.mjs` (after `npm run build` and the bundle copied into
 * the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const PROBE = 'OcuPilot.Test.SqlTuningProbe';
const NS = 'HSCUSTOM';
const LIST_ROUTE = `/ocupilot/system-explorer/sql-index-analysis?ns=${NS}`;
const QUERY_ROUTE = `/ocupilot/system-explorer/sql-query?ns=${NS}`;
/** The probe's schema, and the statement Advise reads: a condition on the probe table's one unindexed column. */
const SCHEMA = 'OcuProbe227';
const ADVISED = `SELECT COUNT(*) FROM ${SCHEMA}.T WHERE B = 'x'`;
/** The list's columns, by position in a row. */
const COLUMN = { report: 0, schema: 1, table: 2, index: 3 };
/** The vendor's own time to gather and run a report on this namespace, with system classes skipped, is under 15 seconds; a send is given a minute. */
const SEND_MS = 90000;

let browser = null;
let touched = false;

/** Run one probe expression in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** The vendor's own count for the probe table under report `code` (`IU`, `TS`, ...), or of the gathered statements for `Statements`. */
function count(code) {
  return probe(`A${code}`, `##class(${PROBE}).AnalysisCounts("${NS}").%Get("${code}")`).value;
}

/** Gather the namespace's statements and run Index usage over them, as the vendor does, so the list has rows to open on. */
function seed() {
  const seeded = probe('ASEED', `$System.Status.IsOK(##class(${PROBE}).SeedAnalysis("${NS}"))`);
  assert.equal(seeded.value, '1', `the probe's analysis is seeded: ${seeded.output}`);
  assert.notEqual(count('IU'), '0', 'the probe table has Index usage rows');
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec gathers and purges the index analysis on the instance, so it runs only in a throwaway; ${config.container} is not one`);
  touched = true; // from here on, `after` removes what MakeAnalysis created, even when it fails part-way
  const made = probe('AMADE', `$System.Status.IsOK(##class(${PROBE}).MakeAnalysis("${NS}"))`);
  assert.equal(made.value, '1', `the probe objects are created: ${made.output}`);
  seed();
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    if (touched && /-ci$/.test(config.container)) {
      const removed = probe('AGONE', `$System.Status.IsOK(##class(${PROBE}).RemoveAnalysis("${NS}"))`);
      assert.equal(removed.value, '1', `the probe objects are removed: ${removed.output}`);
      for (const code of ['Statements', 'IU', 'TS', 'TI', 'JI', 'OI']) {
        assert.equal(count(code), '0', `no ${code} row of the probe's analysis is left`);
      }
    }
  }
});

/** The shell has answered the navigation map and the screen drew rows. */
async function answered(page) {
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  await waitForRows(page, config.navigationTimeoutMs);
}

/**
 * Narrow the list to the probe's rows: the namespace's own tables hold many Index usage rows ahead of the probe's other reports, and the grid draws
 * only the rows in view, so the probe's rows are found through the filter.
 */
async function filterToProbe(page) {
  await page.waitForSelector(FILTER_SELECTOR, { timeout: config.navigationTimeoutMs });
  await page.type(FILTER_SELECTOR, SCHEMA);
  await page.waitForFunction(
    (selector, schema) => {
      const drawn = Array.from(document.querySelectorAll(selector));
      return drawn.length > 0 && drawn.every((row) => (row.querySelectorAll('[role="gridcell"]')[1]?.textContent ?? '').trim().toUpperCase() === schema);
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    SCHEMA.toUpperCase()
  );
}

/** The cells of every row drawn, one array of texts per row. */
function rows(page) {
  return page.$$eval(ROW_SELECTOR, (nodes) => nodes.map((node) => Array.from(node.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim())));
}

/** The rows drawn that belong to the probe table. */
async function probeRows(page) {
  return (await rows(page)).filter((cells) => (cells[COLUMN.schema] ?? '').toUpperCase() === SCHEMA.toUpperCase());
}

/** Wait until the probe table has a row under `report`, the report's name as the list shows it. */
async function waitForProbeReport(page, report) {
  await page.waitForFunction(
    (selector, schema, name, columns) =>
      Array.from(document.querySelectorAll(selector)).some((row) => {
        const cells = row.querySelectorAll('[role="gridcell"]');
        return (cells[columns.schema]?.textContent ?? '').trim().toUpperCase() === schema && (cells[columns.report]?.textContent ?? '').trim() === name;
      }),
    { timeout: SEND_MS },
    ROW_SELECTOR,
    SCHEMA.toUpperCase(),
    report,
    COLUMN
  );
}

/** Select the first row drawn, so the command bar takes a row action. */
async function selectFirstRow(page) {
  await clickRowCentre(page, { index: 0, cell: 2 });
  await page.waitForFunction((selector) => document.querySelectorAll(selector)[0]?.getAttribute('aria-selected') === 'true', { timeout: config.navigationTimeoutMs }, ROW_SELECTOR);
}

/** Click the command-bar button labeled `label` once it is drawn and not held back (an element click, not a pointer event). */
async function bar(page, label) {
  await page.waitForFunction(
    (wanted) => [...document.querySelectorAll('.ocu-command-bar button')].some((button) => button.textContent.trim() === wanted && button.getAttribute('aria-disabled') !== 'true'),
    { timeout: config.navigationTimeoutMs },
    label
  );
  await page.evaluate((wanted) => [...document.querySelectorAll('.ocu-command-bar button')].find((button) => button.textContent.trim() === wanted).click(), label);
}

/** The command-bar buttons' labels. */
function barLabels(page) {
  return page.$$eval('.ocu-command-bar button', (buttons) => buttons.map((button) => button.textContent.trim()));
}

/** The dialog the action opened: its title and its consequence sentence. */
async function openedDialog(page, title) {
  await page.waitForSelector('[data-slot="consequence"]', { visible: true, timeout: config.navigationTimeoutMs });
  assert.equal(await page.$eval('.ocu-dialog-title', (node) => node.textContent.trim()), title, 'the dialog is titled with the action');
  return page.$eval('[data-slot="consequence"]', (node) => node.textContent.trim());
}

/** Proceed in the page's own dialog, and wait for it to go: the send ran and the instance applied it. */
async function proceed(page) {
  await page.evaluate(() => document.querySelector('[data-slot="proceed"]').click());
  await page.waitForFunction(() => document.querySelector('[data-slot="consequence"]') === null, { timeout: SEND_MS });
}

/** Confirm the warning the action opened: it states `consequence`, and the primary button sends the write. */
async function confirmWarning(page, consequence) {
  await page.waitForSelector('.ocu-warning-consequence', { visible: true, timeout: config.navigationTimeoutMs });
  assert.equal(await page.$eval('.ocu-warning-consequence', (node) => node.textContent.trim()), consequence, 'the warning states what the action does');
  await page.evaluate(() => document.querySelector('[role="dialog"] .ocu-button-primary').click());
  await page.waitForFunction(() => document.querySelector('.ocu-warning-consequence') === null, { timeout: SEND_MS });
}

test('AC1: the list shows the probe table\'s Index usage rows and offers the three actions', async () => {
  const { context, page } = await signedInAt(browser, config, LIST_ROUTE, VIEWPORTS.wide);
  try {
    await answered(page);
    await filterToProbe(page);
    await waitForProbeReport(page, STRINGS.sqlIndexAnalysisReportIU);
    const shown = await probeRows(page);
    assert.ok(shown.length > 0, `the probe table's rows are listed: ${JSON.stringify(await rows(page))}`);
    assert.ok(shown.every((cells) => cells[COLUMN.report] === STRINGS.sqlIndexAnalysisReportIU), `each reads Index usage: ${JSON.stringify(shown)}`);
    assert.ok(shown.every((cells) => (cells[COLUMN.table] ?? '').toUpperCase() === 'T'), `each names the probe table: ${JSON.stringify(shown)}`);
    const labels = await barLabels(page);
    for (const label of [STRINGS.sqlIndexAnalysisGatherAction, STRINGS.sqlIndexAnalysisRunAction, STRINGS.sqlIndexAnalysisPurgeAction]) {
      assert.ok(labels.includes(label), `the command bar offers ${label}: ${JSON.stringify(labels)}`);
    }
  } finally {
    await context.close();
  }
});

test('AC2: Run report asks for the report, confirms and lists the probe\'s Table scan row', async () => {
  const { context, page } = await signedInAt(browser, config, LIST_ROUTE, VIEWPORTS.wide);
  try {
    await answered(page);
    await filterToProbe(page);
    await selectFirstRow(page);
    // Mutation (Rule 19): `SqlIndexAnalysisPage` drops its `actions.register` of Run report -> the command bar never draws it and this wait times out.
    await bar(page, STRINGS.sqlIndexAnalysisRunAction);
    const consequence = await openedDialog(page, STRINGS.sqlIndexAnalysisRunAction);
    assert.equal(consequence, STRINGS.sqlIndexAnalysisRunConsequence, 'the dialog states what the run does');
    assert.deepEqual(
      await page.$$eval('[data-slot="report"] option', (nodes) => nodes.map((node) => node.textContent.trim())),
      [STRINGS.sqlIndexAnalysisReportIU, STRINGS.sqlIndexAnalysisReportTS, STRINGS.sqlIndexAnalysisReportTI, STRINGS.sqlIndexAnalysisReportJI, STRINGS.sqlIndexAnalysisReportOI],
      'the dialog offers the five reports'
    );
    await page.select('[data-slot="report"] select', 'TS');
    await proceed(page);
    assert.notEqual(count('TS'), '0', 'the instance holds the probe table\'s Table scan row');
    await waitForProbeReport(page, STRINGS.sqlIndexAnalysisReportTS).catch(async (error) => {
      throw new Error(`${error.message}; the list shows ${JSON.stringify(await rows(page))}`);
    });
    assert.notEqual(count('IU'), '0', 'the Index usage rows are still there');
  } finally {
    await context.close();
  }
});

test('AC3: Advise on SQL query shows Missing index for the probe\'s condition, and the note', async () => {
  const { context, page } = await signedInAt(browser, config, QUERY_ROUTE, VIEWPORTS.wide);
  try {
    await waitForMapAnswered(page, config.navigationTimeoutMs);
    await page.waitForSelector('textarea[data-ocu-sql="statement"]', { timeout: config.navigationTimeoutMs });
    await page.click('textarea[data-ocu-sql="statement"]', { clickCount: 3 });
    await page.keyboard.press('Backspace');
    await page.type('textarea[data-ocu-sql="statement"]', ADVISED);
    assert.equal(await page.$eval('button[data-ocu-sql="advise"]', (node) => node.textContent.trim()), STRINGS.sqlAdviceAction, 'the button is labeled as published');
    // Mutation (Rule 19): drop the `advise` button from `SqlQueryPage`'s template -> this wait times out.
    await page.click('button[data-ocu-sql="advise"]');
    await page.waitForSelector('[data-ocu-sql="finding"]', { timeout: config.navigationTimeoutMs });
    const found = await page.$$eval('[data-ocu-sql="finding"]', (nodes) =>
      nodes.map((node) => ({ kind: node.getAttribute('data-ocu-kind'), cells: Array.from(node.querySelectorAll('td')).map((cell) => cell.textContent.replace(/\s+/g, ' ').trim()) }))
    );
    const missing = found.find((finding) => finding.kind === 'missingindex');
    assert.ok(missing !== undefined, `Missing index is among the findings: ${JSON.stringify(found)}`);
    assert.ok(missing.cells[0].startsWith(STRINGS.sqlAdviceKindMissingIndex), `it is named as published: ${missing.cells[0]}`);
    assert.ok(missing.cells[2].toUpperCase().includes(`${SCHEMA}.T`.toUpperCase()), `it names the probe table: ${missing.cells[2]}`);
    assert.ok(found.some((finding) => finding.kind === 'fullscan'), `the scan is a finding too: ${JSON.stringify(found)}`);
    assert.equal(await page.$eval('[data-ocu-sql="advice-note"]', (node) => node.textContent.trim()), STRINGS.sqlAdviceNote, 'the result carries the ruled note');
    assert.match(await page.$eval('[data-ocu-sql="plan"]', (node) => node.textContent), /Read master map/, 'the plan is shown above the findings');
  } finally {
    await context.close();
  }
});

test('AC2: Gather statements asks, confirms and replaces the statements and every report\'s results', async () => {
  const { context, page } = await signedInAt(browser, config, LIST_ROUTE, VIEWPORTS.wide);
  try {
    await answered(page);
    await selectFirstRow(page);
    await bar(page, STRINGS.sqlIndexAnalysisGatherAction);
    const consequence = await openedDialog(page, STRINGS.sqlIndexAnalysisGatherAction);
    assert.equal(consequence, STRINGS.sqlIndexAnalysisGatherConsequence, 'the dialog states what the gathering does, with system classes and routines skipped');
    assert.equal(await page.$eval('[data-slot="skip-system"] input', (node) => node.checked), true, 'system classes and routines are skipped to begin with');
    assert.equal(await page.$eval('[data-slot="skip-inserts"] input', (node) => node.checked), true, 'INSERT statements are skipped to begin with');
    await proceed(page);
    await page.waitForFunction((selector) => document.querySelectorAll(selector).length === 0, { timeout: SEND_MS }, ROW_SELECTOR);
    assert.notEqual(count('Statements'), '0', 'the instance holds the namespace\'s gathered statements');
    for (const code of ['IU', 'TS', 'TI', 'JI', 'OI']) assert.equal(count(code), '0', `no ${code} row is left after a gathering`);
    assert.ok((await page.evaluate(() => document.body.textContent)).includes(STRINGS.explorerSqlIndexAnalysisEmpty), 'the list says the namespace holds no analysis');
  } finally {
    await context.close();
  }
});

test('AC4: Purge analysis asks, confirms and empties the list', async () => {
  seed();
  const { context, page } = await signedInAt(browser, config, LIST_ROUTE, VIEWPORTS.wide);
  try {
    await answered(page);
    await selectFirstRow(page);
    // Mutation (Rule 19): `SqlIndexAnalysisPage` drops its `actions.register` of Purge analysis -> the command bar never draws it and this wait times out.
    await bar(page, STRINGS.sqlIndexAnalysisPurgeAction);
    await confirmWarning(page, STRINGS.sqlIndexAnalysisPurgeConsequence);
    await page.waitForFunction((selector) => document.querySelectorAll(selector).length === 0, { timeout: SEND_MS }, ROW_SELECTOR);
    assert.equal(count('Statements'), '0', 'the instance holds no gathered statement after the purge');
    for (const code of ['IU', 'TS', 'TI', 'JI', 'OI']) assert.equal(count(code), '0', `no ${code} row is left after the purge`);
    assert.ok((await page.evaluate(() => document.body.textContent)).includes(STRINGS.explorerSqlIndexAnalysisEmpty), 'the list says the namespace holds no analysis');
  } finally {
    await context.close();
  }
});

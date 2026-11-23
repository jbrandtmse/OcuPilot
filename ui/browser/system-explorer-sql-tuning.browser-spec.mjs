/**
 * Story 21.25 in a real browser, against the throwaway: a table's index rebuild, statistics collection and clearing of fixed statistics, and the
 * refusal of OcuPilot's own table (AD-5, AD-7, AD-10, AD-29, AD-51, AD-53).
 *
 * What it pins: on the probe table's Indices tab, Rebuild index on a killed index warns, confirms, and the index holds every row again while its
 * untouched sibling is as it was; on the Table info tab, Collect statistics warns, offers no box, and the table's extent size then reads the
 * probe's rows; Clear fixed statistics removes the extent size the fixture fixed; and Collect statistics on
 * one of OcuPilot's own tables shows the published refusal and changes nothing. Story 21.31 adds two: Set extent size on the Table info tab asks
 * for a whole number, warns with the setters' sentence, and the instance then holds that fixed size; Set selectivity on the Field statistics tab
 * takes text, and the field's row then reads the fixed selectivity the instance holds. Each step waits for the shell's answered signal and then for
 * the instance, read through the vendor's own calls, to show the result.
 *
 * **It rebuilds, measures and clears on the instance** through the shipped screens, so it runs on a throwaway only. `SqlTuningProbe.Table` makes
 * the probe tables in `HSCUSTOM`, and the `after` hook clears their fixed statistics, then removes them through `SqlTuningProbe.Remove` (purging
 * their cached queries before it drops them) and asserts that no probe table, statistic or cached query is left, whatever the tests answered.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/system-explorer-sql-tuning.browser-spec.mjs` (after `npm run build` and the bundle copied into the
 * throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { encodeEntityId } = await import(join(uiRoot, 'src', 'app', 'core', 'entity-id.ts'));

const config = browserConfig();
const STRINGS = loadStrings();
const PROBE = 'OcuPilot.Test.SqlTuningProbe';
const NS = 'HSCUSTOM';
const ROWS = { indexed: 5, measured: 7 };
const OWN_TABLE = 'OcuPilot_Kernel_State.Convo';
const TABLE_ROUTE = 'system-explorer/sql-tables';
const route = (tab, table) => `/ocupilot/${TABLE_ROUTE}/${tab}/${encodeEntityId(table)}?ns=${NS}`;

let browser = null;
let touched = false;
const tables = { indexed: '', measured: '' };

/** Run one probe expression in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** Make the probe table `number` with `rows` rows and answer its name. */
function makeTable(number, rows) {
  const output = runIris(config.container, [
    `Set tSC=##class(${PROBE}).Table("${NS}",${number},${rows},.tTable)`,
    'Write "OCU-TMADE-START:"_$System.Status.IsOK(tSC)_":OCU-TMADE-END",!',
    'Write "OCU-TNAME-START:"_tTable_":OCU-TNAME-END",!',
  ]);
  assert.equal(markerValue(output, 'TMADE'), '1', `the probe table ${number} is created: ${output}`);
  return markerValue(output, 'TNAME');
}

/** What the instance holds for the table, read directly: `kind size`. */
const statistics = (table) => probe('TSTAT', `##class(${PROBE}).Statistics("${NS}","${table}")`).value;

/** The entries the table's index holds, counted in its global. */
const entries = (table, index) => Number(probe('TENT', `##class(${PROBE}).IndexEntries("${NS}","${table}","${index}")`).value);

/** Poll `read` until it answers `wanted`, and answer what it read last. */
async function waitForInstance(read, wanted) {
  const stop = Date.now() + config.navigationTimeoutMs;
  let seen = read();
  while (seen !== wanted && Date.now() < stop) {
    await new Promise((resolve) => setTimeout(resolve, 500));
    seen = read();
  }
  return seen;
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec rebuilds and measures on the instance, so it runs only in a throwaway; ${config.container} is not one`);
  touched = true; // from here on, `after` removes what Table created, even when it fails part-way
  tables.indexed = makeTable(1, ROWS.indexed);
  tables.measured = makeTable(2, ROWS.measured);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    if (touched && /-ci$/.test(config.container)) {
      for (const table of Object.values(tables).filter((name) => name !== '')) {
        probe('TCLEAR', `$System.Status.IsOK($SYSTEM.SQL.Stats.Table.ClearTableStats("${table}"))`);
      }
      const removed = probe('TGONE', `$System.Status.IsOK(##class(${PROBE}).Remove("${NS}"))`);
      assert.equal(removed.value, '1', `the probe objects are removed: ${removed.output}`);
      assert.equal(probe('TLEFT', `$ListLength(##class(${PROBE}).TablesOf("${NS}"))`).value, '0', 'no probe table is left');
      assert.equal(probe('TCQ', `##class(${PROBE}).CachedQueryCount("${NS}")`).value, '0', 'no probe cached query is left');
      for (const table of Object.values(tables).filter((name) => name !== '')) {
        assert.ok(['none 100000', 'unread'].includes(statistics(table)), `no statistic of ${table} is left: ${statistics(table)}`);
      }
    }
  }
});

/** The shell has answered the navigation map and the screen drew rows. */
async function answered(page) {
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  await waitForRows(page, config.navigationTimeoutMs);
}

/** The first cell of every row drawn. */
function firstCells(page) {
  return page.$$eval(ROW_SELECTOR, (rows) => rows.map((row) => row.querySelector('[role="gridcell"]')?.textContent.trim() ?? ''));
}

/** Select the row whose first cell reads `first`, unless it already is selected. */
async function selectRow(page, first) {
  const at = (await firstCells(page)).indexOf(first);
  assert.ok(at >= 0, `the row of ${first} is drawn`);
  const selected = await page.$$eval(ROW_SELECTOR, (rows, index) => rows[index].getAttribute('aria-selected') === 'true', at);
  if (!selected) await clickRowCentre(page, { index: at, cell: 2 });
  await page.waitForFunction((selector, index) => document.querySelectorAll(selector)[index]?.getAttribute('aria-selected') === 'true', { timeout: config.navigationTimeoutMs }, ROW_SELECTOR, at);
}

/** Select the one row the Table info tab draws, which is what the command bar's actions wait for. */
async function selectTheTable(page) {
  const [first] = await firstCells(page);
  await selectRow(page, first);
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

/** The warning the action opened: it states `consequence`. */
async function warningStates(page, consequence) {
  await page.waitForSelector('.ocu-warning-consequence', { visible: true, timeout: config.navigationTimeoutMs });
  assert.equal(await page.$eval('.ocu-warning-consequence', (node) => node.textContent.trim()), consequence, 'the warning states what the action does');
}

/** Press the warning's primary button and wait for the dialog to close. */
async function proceed(page) {
  await page.evaluate(() => document.querySelector('[role="dialog"] .ocu-button-primary').click());
  await page.waitForFunction(() => document.querySelector('.ocu-warning-consequence') === null, { timeout: config.navigationTimeoutMs });
}

/** The refusal the screen shows, or `''` while none stands. */
function refusal(page) {
  return page.evaluate(() => document.querySelector('p.ocu-banner-warning[role="alert"] .ocu-banner-message')?.textContent.trim() ?? '');
}

test('AC2: Rebuild index on a killed index warns, confirms, and the index holds every row again', async () => {
  const table = tables.indexed;
  probe('TKILL', `##class(${PROBE}).KillIndex("${NS}","${table}","IdxB")`);
  assert.equal(entries(table, 'IdxB'), 0, 'the fixture emptied IdxB');
  assert.equal(entries(table, 'IdxC'), ROWS.indexed, 'and left IdxC as it was');
  const { context, page } = await signedInAt(browser, config, route('indices', table), VIEWPORTS.wide);
  try {
    await answered(page);
    await selectRow(page, 'IdxB');
    assert.ok((await barLabels(page)).includes(STRINGS.sqlIndexRebuildAction), `the command bar offers ${STRINGS.sqlIndexRebuildAction}`);
    // Mutation (Rule 19): drop `ExplorerSqlIndices` from `SCREEN_ACTION_DESCRIPTORS`, so the Indices tab registers no `rebuild` (and rebuild and redeploy
    // the bundle) -> the command bar never draws Rebuild index and the label assertion goes red.
    await bar(page, STRINGS.sqlIndexRebuildAction);
    await warningStates(page, STRINGS.sqlTableRebuildConsequence);
    await proceed(page);
    assert.equal(await waitForInstance(() => entries(table, 'IdxB'), ROWS.indexed), ROWS.indexed, 'IdxB holds every row again when the confirm has answered');
    assert.equal(entries(table, 'IdxC'), ROWS.indexed, 'and IdxC is as it was');
    assert.equal(Number(probe('TCOUNT', `##class(${PROBE}).IndexedCount("${NS}","${table}","B")`).value), ROWS.indexed, 'a query through IdxB returns every row');
  } finally {
    await context.close();
  }
});

test('AC3: Collect statistics warns with no box, and the extent size then reads the probe\'s rows', async () => {
  const table = tables.measured;
  assert.ok(!statistics(table).startsWith('collected'), `the table holds no collected statistics yet: ${statistics(table)}`);
  const { context, page } = await signedInAt(browser, config, route('document', table), VIEWPORTS.wide);
  try {
    await answered(page);
    await selectTheTable(page);
    assert.ok((await barLabels(page)).includes(STRINGS.sqlTableTuneAction), `the command bar offers ${STRINGS.sqlTableTuneAction}`);
    // Mutation (Rule 19): do not register the tune handler (drop `SQL_TABLE_TUNE` from `SqlTablePage`'s actions, and rebuild and redeploy the bundle) ->
    // the command bar never draws Collect statistics and the label assertion goes red.
    await bar(page, STRINGS.sqlTableTuneAction);
    await warningStates(page, STRINGS.sqlTableTuneConsequence);
    assert.equal(await page.$('[data-slot="flag"]'), null, 'the warning draws no box');
    await proceed(page);
    assert.equal(await waitForInstance(() => statistics(table), `collected ${ROWS.measured}`), `collected ${ROWS.measured}`, 'the extent size reads the probe\'s rows');
  } finally {
    await context.close();
  }
});

test('AC3: Clear fixed statistics removes the extent size the fixture fixed', async () => {
  const table = tables.measured;
  const wanted = statistics(table);
  assert.notEqual(wanted.split(' ')[0], 'fixed', `the table holds no fixed statistics to begin with: ${wanted}`);
  assert.equal(probe('TFIX',`$System.Status.IsOK(##class(${PROBE}).FixExtent("${NS}","${table}",777))`).value, '1', 'the fixture fixes the extent size');
  assert.equal(statistics(table), 'fixed 777', 'the instance holds the fixed size');
  const { context, page } = await signedInAt(browser, config, route('document', table), VIEWPORTS.wide);
  try {
    await answered(page);
    await selectTheTable(page);
    await bar(page, STRINGS.sqlTableClearStatisticsAction);
    await warningStates(page, STRINGS.sqlTableClearStatisticsConsequence);
    await proceed(page);
    assert.equal(await waitForInstance(() => statistics(table), wanted), wanted, 'the table is back to the statistics it held before the fixture fixed one');
  } finally {
    await context.close();
  }
});

/** The dialog's one field, once drawn, and the hint under it. */
async function dialogField(page) {
  const selector = '[role="dialog"] [data-slot="field"] .ocu-field-input';
  await page.waitForSelector(selector, { visible: true, timeout: config.navigationTimeoutMs });
  const hint = await page.$eval('[role="dialog"] .ocu-field-caption', (node) => node.textContent.trim());
  return { selector, hint };
}

/** The Field statistics tab's cell of the row whose Field reads `field`, in the column headed `heading`. */
async function fieldCell(page, field, heading) {
  return page.evaluate(
    (rowSelector, wanted, column) => {
      const headings = [...document.querySelectorAll('[role="columnheader"] .ocu-data-table-header-label')].map((node) => node.textContent.trim());
      const at = headings.indexOf(column);
      // A changed row's first cell carries the change note after the name, so the name is matched as its start.
      const row = [...document.querySelectorAll(rowSelector)].find((candidate) => candidate.querySelector('[role="gridcell"]')?.textContent.trim().startsWith(wanted));
      return at < 0 || row === undefined ? null : (row.querySelectorAll('[role="gridcell"]')[at]?.textContent.trim() ?? null);
    },
    ROW_SELECTOR,
    field,
    heading
  );
}

test('AC1: Set extent size asks for a whole number, warns, and the instance then holds the fixed extent size', async () => {
  const table = tables.measured;
  const wanted = statistics(table);
  assert.notEqual(wanted.split(' ')[0], 'fixed', `the table holds no fixed statistics to begin with: ${wanted}`);
  const { context, page } = await signedInAt(browser, config, route('document', table), VIEWPORTS.wide);
  try {
    await answered(page);
    await selectTheTable(page);
    assert.ok((await barLabels(page)).includes(STRINGS.sqlTableSetExtentSizeAction), `the command bar offers ${STRINGS.sqlTableSetExtentSizeAction}`);
    // Mutation (Rule 19): do not register the handler (drop `SQL_TABLE_SET_EXTENT_SIZE` from `SqlTablePage`'s actions, and rebuild and redeploy the
    // bundle) -> the command bar never draws Set extent size and the label assertion goes red.
    await bar(page, STRINGS.sqlTableSetExtentSizeAction);
    await warningStates(page, STRINGS.sqlTableSetConsequence);
    const { selector, hint } = await dialogField(page);
    assert.equal(hint, STRINGS.sqlTableExtentSizeShape, 'the field is hinted by its shape sentence');
    await page.type(selector, '5000');
    await proceed(page);
    assert.equal(await waitForInstance(() => statistics(table), 'fixed 5000'), 'fixed 5000', 'the instance holds the fixed extent size when the confirm has answered');
    await selectTheTable(page);
    await bar(page, STRINGS.sqlTableClearStatisticsAction);
    await warningStates(page, STRINGS.sqlTableClearStatisticsConsequence);
    await proceed(page);
    assert.equal(await waitForInstance(() => statistics(table), wanted), wanted, 'the table is back to the statistics it held before the set, through the product\'s own Clear fixed statistics');
  } finally {
    await context.close();
  }
});

test('AC1: Set selectivity on the Field statistics tab takes text, and the field\'s row reads the fixed selectivity', async () => {
  const table = tables.indexed;
  assert.equal(probe('TFSB', `##class(${PROBE}).FixedField("${NS}","${table}","B")`).value.split('|')[0], '', 'the field holds no fixed selectivity to begin with');
  const { context, page } = await signedInAt(browser, config, route('field-statistics', table), VIEWPORTS.wide);
  try {
    await answered(page);
    await selectRow(page, 'B');
    assert.ok((await barLabels(page)).includes(STRINGS.sqlFieldSetSelectivityAction), `the command bar offers ${STRINGS.sqlFieldSetSelectivityAction}`);
    // Mutation (Rule 19): `ExplorerSqlFieldStatistics` loses its `set-selectivity` row action (and rebuild and redeploy the bundle) -> the command bar
    // never draws Set selectivity and the label assertion goes red.
    await bar(page, STRINGS.sqlFieldSetSelectivityAction);
    await warningStates(page, STRINGS.sqlTableSetConsequence);
    const { selector, hint } = await dialogField(page);
    assert.equal(hint, STRINGS.sqlTableSelectivityShape, 'the field is hinted by its shape sentence');
    await page.type(selector, '2.5%');
    await proceed(page);
    const held = await waitForInstance(() => probe('TFSA', `##class(${PROBE}).FixedField("${NS}","${table}","B")`).value.split('|')[0], '2.5000%');
    assert.equal(held, '2.5000%', 'the instance holds the fixed selectivity when the confirm has answered');
    const heading = STRINGS.explorerSqlColumnFixedSelectivity;
    await page.waitForFunction(
      (rowSelector, column) => {
        const headings = [...document.querySelectorAll('[role="columnheader"] .ocu-data-table-header-label')].map((node) => node.textContent.trim());
        const row = [...document.querySelectorAll(rowSelector)].find((candidate) => candidate.querySelector('[role="gridcell"]')?.textContent.trim().startsWith('B'));
        return row !== undefined && row.querySelectorAll('[role="gridcell"]')[headings.indexOf(column)]?.textContent.trim() === '2.5000%';
      },
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      heading
    );
    assert.equal(await fieldCell(page, 'B', heading), held, 'the field\'s row reads the fixed selectivity the instance holds');
    assert.notEqual(await fieldCell(page, 'C', heading), held, 'and a sibling field\'s row does not');
  } finally {
    await context.close();
  }
  const cleared = await signedInAt(browser, config, route('document', table), VIEWPORTS.wide);
  try {
    await answered(cleared.page);
    await selectTheTable(cleared.page);
    await bar(cleared.page, STRINGS.sqlTableClearStatisticsAction);
    await warningStates(cleared.page, STRINGS.sqlTableClearStatisticsConsequence);
    await proceed(cleared.page);
    const left = await waitForInstance(() => probe('TFSC', `##class(${PROBE}).FixedField("${NS}","${table}","B")`).value.split('|')[0], '');
    assert.equal(left, '', 'the fixed selectivity is cleared through the product\'s own Clear fixed statistics');
  } finally {
    await cleared.context.close();
  }
});

test('AC5: Collect statistics on one of OcuPilot\'s own tables shows the refusal and changes nothing', async () => {
  const before = statistics(OWN_TABLE);
  const { context, page } = await signedInAt(browser, config, route('document', OWN_TABLE), VIEWPORTS.wide);
  try {
    await answered(page);
    await selectTheTable(page);
    await bar(page, STRINGS.sqlTableTuneAction);
    await warningStates(page, STRINGS.sqlTableTuneConsequence);
    await proceed(page);
    await page.waitForFunction(() => document.querySelector('p.ocu-banner-warning[role="alert"] .ocu-banner-message') !== null, { timeout: config.navigationTimeoutMs });
    assert.equal(await refusal(page), STRINGS.sqlTableRefusalOcuPilot, 'the published refusal is shown');
    assert.equal(statistics(OWN_TABLE), before, 'and the table\'s statistics are unchanged');
  } finally {
    await context.close();
  }
});

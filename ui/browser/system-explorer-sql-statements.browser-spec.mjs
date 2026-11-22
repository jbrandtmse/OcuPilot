/**
 * Story 21.6 in a real browser, against the throwaway: System Explorer's SQL statements list and a table's Cached queries tab (AD-5, AD-29,
 * AD-51, AD-53, AD-10).
 *
 * What it pins: the list shows the probe's statement with its plan state and statistics; on the probe table's Cached queries tab, Purge removes
 * one cached query and the other stays; Freeze plan asks, confirms and the row reads `Frozen/Explicit`, and Unfreeze plan restores it through
 * the same action; Clear plan error removes the fixture's error; and Freeze plan on a statement over OcuPilot's own table shows the published
 * refusal and changes nothing. Each step waits for the shell's answered signal and then for the row or the tab to show the result.
 *
 * **It freezes, clears and purges on the instance** through the shipped screens, so it runs on a throwaway only; the `after` hook removes
 * `SqlTuningProbe`'s objects (unfreezing and clearing the plan error through the vendor calls that set them, purging both tables' cached queries
 * before it drops them) and asserts that no frozen plan, plan error or probe cached query is left, whatever the tests answered.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/system-explorer-sql-statements.browser-spec.mjs` (after `npm run build` and the bundle copied into
 * the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { ROW_SELECTOR, clickRowCentre, filterToSubset, viewCount, waitForRows } from './list-spec.mjs';
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
const TABLE = 'OcuProbe216.T1';
const STATEMENTS_ROUTE = `/ocupilot/system-explorer/sql-statements?ns=${NS}`;
const CACHED_ROUTE = `/ocupilot/system-explorer/sql-tables/cached-queries/${encodeEntityId(TABLE)}?ns=${NS}`;
/** The statement list's columns, by position in a row. */
const COLUMN = { hash: 0, planState: 3, planError: 5, executions: 8 };

let browser = null;
let touched = false;
const hashes = { one: '', two: '', stale: '', other: '', own: '' };

/** Run one probe expression in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** What the information schema holds for `hash`, read directly: the field `name` of `SqlTuningProbe.Facts`. */
function fact(hash, name) {
  return probe('FACT', `##class(${PROBE}).Facts("${NS}","${hash}").%Get("${name}")`).value;
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec freezes, clears and purges on the instance, so it runs only in a throwaway; ${config.container} is not one`);
  touched = true; // from here on, `after` removes what Make created, even when it fails part-way
  const made = probe('TMADE', `$System.Status.IsOK(##class(${PROBE}).Make("${NS}"))`);
  assert.equal(made.value, '1', `the probe objects are created: ${made.output}`);
  hashes.one = probe('TONE', `##class(${PROBE}).HashOf("${NS}","SELECT A FROM")`).value;
  hashes.two = probe('TTWO', `##class(${PROBE}).HashOf("${NS}","SELECT B FROM")`).value;
  hashes.stale = probe('TSTALE', `##class(${PROBE}).HashOf("${NS}","SELECT A , B FROM")`).value;
  hashes.other = probe('TOTHER', `##class(${PROBE}).HashOf("${NS}","SELECT A FROM","OCUPROBE216.T2")`).value;
  for (const [name, hash] of Object.entries(hashes)) {
    if (name !== 'own') assert.ok(hash !== null && hash !== '', `the probe statement ${name} is in the index`);
  }
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    if (touched && /-ci$/.test(config.container)) {
      if (hashes.own !== '') probe('TOWNGONE', `##class(${PROBE}).RemoveOwn("${NS}","${hashes.own}")`);
      const removed = probe('TGONE', `$System.Status.IsOK(##class(${PROBE}).Remove("${NS}"))`);
      assert.equal(removed.value, '1', `the probe objects are removed: ${removed.output}`);
      for (const [name, hash] of Object.entries(hashes).filter(([, value]) => value !== '')) {
        assert.equal(fact(hash, 'PlanState'), 'Unfrozen', `no frozen plan is left on ${name}`);
        assert.equal(fact(hash, 'PlanError'), '', `no plan error is left on ${name}`);
        // The own statement reads OcuPilot's table, not a probe table, so its cached query is the instance's own.
        if (name !== 'own') assert.equal(fact(hash, 'Location'), '', `no probe cached query is left for ${name}`);
      }
    }
  }
});

/** The shell has answered the navigation map and the screen drew rows. */
async function answered(page) {
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  await waitForRows(page, config.navigationTimeoutMs);
}

/** Narrow the list on display to the row whose first cell is `hash`. */
async function narrowTo(page, hash) {
  const total = await viewCount(page);
  await filterToSubset(page, { text: hash, expectRow: hash, total, timeoutMs: config.navigationTimeoutMs });
}

/**
 * Each in-page function below decides whether a first cell names `wanted` the same way: the cell reads it, with or without the tag the shell
 * appends to a row it has just changed. The tag begins with a letter and a cached query's class name ends in a digit, so a name followed by a digit
 * is another name.
 */

/** The first cell of every row drawn. */
function firstCells(page) {
  return page.$$eval(ROW_SELECTOR, (rows) => rows.map((row) => row.querySelector('[role="gridcell"]')?.textContent.trim() ?? ''));
}

/** The text of cell `column` of the row whose first cell names `first`, or `null` where no such row is drawn. */
function cellOf(page, first, column) {
  return page.evaluate(
    (selector, wanted, at) => {
      const named = (cell) => cell === wanted || (cell.startsWith(wanted) && !/[0-9]/.test(cell.charAt(wanted.length)));
      const row = Array.from(document.querySelectorAll(selector)).find((candidate) => named(candidate.querySelector('[role="gridcell"]')?.textContent?.trim() ?? ''));
      return row === undefined ? null : (row.querySelectorAll('[role="gridcell"]')[at]?.textContent?.trim() ?? null);
    },
    ROW_SELECTOR,
    first,
    column
  );
}

/** Wait until cell `column` of the row whose first cell names `first` reads one of `wanted`. */
async function waitForCell(page, first, column, wanted) {
  await page.waitForFunction(
    (selector, row, at, accepted) => {
      const named = (cell) => cell === row || (cell.startsWith(row) && !/[0-9]/.test(cell.charAt(row.length)));
      const found = Array.from(document.querySelectorAll(selector)).find((candidate) => named(candidate.querySelector('[role="gridcell"]')?.textContent?.trim() ?? ''));
      const text = found?.querySelectorAll('[role="gridcell"]')[at]?.textContent?.trim();
      return text !== undefined && accepted.includes(text);
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    first,
    column,
    wanted
  );
}

/** Wait until no row's first cell names `first`. */
async function waitForRowGone(page, first) {
  await page.waitForFunction(
    (selector, gone) => {
      const named = (cell) => cell === gone || (cell.startsWith(gone) && !/[0-9]/.test(cell.charAt(gone.length)));
      return !Array.from(document.querySelectorAll(selector)).some((row) => named(row.querySelector('[role="gridcell"]')?.textContent?.trim() ?? ''));
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    first
  );
}

/** Select the row whose first cell names `first`, unless it already is selected. */
async function selectRow(page, first) {
  const state = () =>
    page.evaluate(
      (selector, wanted) => {
        const named = (cell) => cell === wanted || (cell.startsWith(wanted) && !/[0-9]/.test(cell.charAt(wanted.length)));
        const rows = Array.from(document.querySelectorAll(selector));
        const at = rows.findIndex((row) => named(row.querySelector('[role="gridcell"]')?.textContent?.trim() ?? ''));
        return { at, selected: at >= 0 && rows[at].getAttribute('aria-selected') === 'true' };
      },
      ROW_SELECTOR,
      first
    );
  const found = await state();
  assert.ok(found.at >= 0, `the row of ${first} is drawn`);
  if (!found.selected) await clickRowCentre(page, { index: found.at, cell: 2 });
  await page.waitForFunction(
    (selector, wanted) => {
      const named = (cell) => cell === wanted || (cell.startsWith(wanted) && !/[0-9]/.test(cell.charAt(wanted.length)));
      return Array.from(document.querySelectorAll(selector)).some(
        (row) => row.getAttribute('aria-selected') === 'true' && named(row.querySelector('[role="gridcell"]')?.textContent?.trim() ?? '')
      );
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    first
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

/** The refusal the list shows, or `''` while none stands. */
function refusal(page) {
  return page.evaluate(() => document.querySelector('p.ocu-banner-warning[role="alert"] .ocu-banner-message')?.textContent.trim() ?? '');
}

const BLANK = ['', STRINGS.tableEmptyValue];

test('AC1: the list shows the probe statement with its plan state and statistics', async () => {
  const { context, page } = await signedInAt(browser, config, STATEMENTS_ROUTE, VIEWPORTS.wide);
  try {
    await answered(page);
    await narrowTo(page, hashes.one);
    assert.equal(await cellOf(page, hashes.one, COLUMN.hash), hashes.one, 'the probe statement is listed by its hash');
    assert.equal(await cellOf(page, hashes.one, COLUMN.planState), 'Unfrozen', 'it reads its plan state');
    assert.equal(await cellOf(page, hashes.one, COLUMN.executions), '3', 'and the run statistics the fixture recorded');
  } finally {
    await context.close();
  }
});

test('AC4: on the probe table\'s Cached queries tab, Purge removes one query and the other stays', async () => {
  const { context, page } = await signedInAt(browser, config, CACHED_ROUTE, VIEWPORTS.wide);
  try {
    await answered(page);
    const before = await firstCells(page);
    assert.equal(before.length, 2, `the probe table holds two cached queries: ${JSON.stringify(before)}`);
    await selectRow(page, before[0]);
    const labels = await barLabels(page);
    for (const label of [STRINGS.auditDatabasePurgeConfirm, STRINGS.sqlCachedQueryPurgeTableAction, STRINGS.sqlCachedQueryPurgeAllAction]) {
      assert.ok(labels.includes(label), `the command bar offers ${label}: ${JSON.stringify(labels)}`);
    }
    await bar(page, STRINGS.auditDatabasePurgeConfirm);
    await confirmWarning(page, STRINGS.sqlCachedQueryPurgeConsequence);
    await waitForRowGone(page, before[0]);
    const after = await firstCells(page);
    assert.deepEqual(after, [before[1]], 'the purged query is gone and the table\'s other query stays');
  } finally {
    await context.close();
  }
});

test('AC2: Freeze plan asks and confirms and the row reads Frozen/Explicit, and Unfreeze plan restores it', async () => {
  const { context, page } = await signedInAt(browser, config, STATEMENTS_ROUTE, VIEWPORTS.wide);
  try {
    await answered(page);
    await narrowTo(page, hashes.one);
    await selectRow(page, hashes.one);
    // Mutation (Rule 19): remove the `freeze` row action from `ExplorerSqlStatementList` -> the command bar never draws Freeze plan and this wait times out.
    await bar(page, STRINGS.sqlStatementFreezeAction);
    await confirmWarning(page, STRINGS.sqlStatementFreezeConsequence);
    await waitForCell(page, hashes.one, COLUMN.planState, ['Frozen/Explicit']);
    assert.equal(fact(hashes.one, 'PlanState'), 'Frozen/Explicit', 'the instance holds the plan frozen');

    await selectRow(page, hashes.one);
    await bar(page, STRINGS.sqlStatementUnfreezeAction);
    await confirmWarning(page, STRINGS.sqlStatementUnfreezeConsequence);
    await waitForCell(page, hashes.one, COLUMN.planState, ['Unfrozen']);
    assert.equal(fact(hashes.one, 'PlanState'), 'Unfrozen', 'Unfreeze plan restores it through the same action');
  } finally {
    await context.close();
  }
});

test('AC3: Clear plan error removes the fixture\'s error', async () => {
  const { context, page } = await signedInAt(browser, config, STATEMENTS_ROUTE, VIEWPORTS.wide);
  try {
    await answered(page);
    await narrowTo(page, hashes.two);
    assert.notEqual(await cellOf(page, hashes.two, COLUMN.planError), null, 'the statement with the fixture\'s plan error is listed');
    assert.ok(!BLANK.includes(await cellOf(page, hashes.two, COLUMN.planError)), 'and shows the error');
    await selectRow(page, hashes.two);
    await bar(page, STRINGS.sqlStatementClearErrorAction);
    await confirmWarning(page, STRINGS.sqlStatementClearErrorConsequence);
    await waitForCell(page, hashes.two, COLUMN.planError, BLANK);
    assert.equal(fact(hashes.two, 'PlanError'), '', 'the instance holds no plan error for it');
  } finally {
    await context.close();
  }
});

test('AC5: Freeze plan on a statement over OcuPilot\'s own table shows the refusal and changes nothing', async () => {
  hashes.own = probe('TOWN', `##class(${PROBE}).MakeOwn("${NS}")`).value ?? '';
  assert.notEqual(hashes.own, '', 'the statement over OcuPilot\'s own table is in the index');
  const { context, page } = await signedInAt(browser, config, STATEMENTS_ROUTE, VIEWPORTS.wide);
  try {
    await answered(page);
    await narrowTo(page, hashes.own);
    await selectRow(page, hashes.own);
    await bar(page, STRINGS.sqlStatementFreezeAction);
    await confirmWarning(page, STRINGS.sqlStatementFreezeConsequence);
    await page.waitForFunction(() => document.querySelector('p.ocu-banner-warning[role="alert"] .ocu-banner-message') !== null, { timeout: config.navigationTimeoutMs });
    assert.equal(await refusal(page), STRINGS.explorerSqlRefusalOcuPilot, 'the published refusal is shown');
    assert.equal(fact(hashes.own, 'PlanState'), 'Unfrozen', 'and the statement is unchanged');
  } finally {
    await context.close();
  }
});

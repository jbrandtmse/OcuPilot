/**
 * Story 19.6 in a real browser, against the throwaway: SQL query in USER runs a SELECT with a `?`
 * after asking for its one value, the value bound and shown in the grid (AC1); `CREATE TABLE
 * OcuProbe196.Made (X INTEGER)` waits on a warning naming its kind, creates nothing until Proceed,
 * and once confirmed SQL tables (Story 19.5) lists the table and its Fields tab reads `X` (AC2, AC9).
 * The page with rows, and with the run's answer, passes the structural walk's checks at 1280 light,
 * 720 light and 1280 dark, with no entry beyond the baseline.
 *
 * Story 19.15 (AC11): a background COUNT started with Run in background leaves Run answering a SELECT
 * at once, and the Background run section later shows the COUNT's row; Cancel on a second background
 * COUNT shows Canceled. The probe tables (`OcuPilot.Test.SqlBackgroundProbe`) are made and removed by
 * that test, and the signed-in account's run rows are removed after it.
 *
 * Needs the throwaway (it refuses the live container); the table it creates is dropped in `before`
 * and `after`, and `after` asserts none is left.
 *
 * Run: `node --test --test-concurrency=1 browser/system-explorer-sql-query.browser-spec.mjs` (after
 * `npm run build`, the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { ROW_SELECTOR, clickRowCentre } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { encodeEntityId } = await import(join(uiRoot, 'src', 'app', 'core', 'entity-id.ts'));

const config = browserConfig();
const STRINGS = loadStrings();
const PROBE = 'OcuPilot.Test.SqlConsoleProbe';
const SCHEMA = 'OcuProbe196';
const MADE = 'OcuProbe196.Made';
const ECHO = 'OcuProbe196Echo';
const ROUTE = 'system-explorer/sql-query';
const BACKGROUND_PROBE = 'OcuPilot.Test.SqlBackgroundProbe';
/** A five-way cross join's count over the probe table: about five seconds. */
const COUNT = 'SELECT COUNT(*) AS N FROM OcuProbe1915.Granted a, OcuProbe1915.Granted b, OcuProbe1915.Granted c, OcuProbe1915.Granted d, OcuProbe1915.Granted e';
/** A six-way cross join's count: minutes, so only Cancel or the bound ends it. */
const LONGER = `${COUNT}, OcuProbe1915.Granted f`;
const TABLES_ROUTE = 'system-explorer/sql-tables';

/** The walk's own media feature (`structural-walk.mjs`): a theme flip lands at once rather than mid-transition. */
const REDUCED_MOTION = [{ name: 'prefers-reduced-motion', value: 'reduce' }];

let browser = null;

const marker = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/** Whether USER holds the probe table, read through the probe class: `'1'`, `'0'`, or `null` when unread. */
function holdsMade() {
  return markerValue(runIris(config.container, [marker('HOLDS', `##class(${PROBE}).HoldsTable("${MADE}")`)]), 'HOLDS');
}

/** Drop the probe table in USER, answering whether no table and no class of that name is left. */
function dropMade() {
  const output = runIris(config.container, [
    'Set $NAMESPACE="USER"',
    `Do ##class(%SQL.Statement).%ExecDirect(,"DROP TABLE ${MADE}")`,
    marker('LEFT', `##class(%Dictionary.ClassDefinition).%ExistsId("${MADE}")`),
  ]);
  return markerValue(output, 'LEFT') === '0' && holdsMade() === '0';
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates and drops an SQL table, so it never runs inside the live container');
  await assertThrowaway(config);
  assert.ok(dropMade(), 'USER holds no probe table before the run');
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  assert.ok(dropMade(), 'no probe table or class is left in USER');
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

/** Replace the statement with `text`. */
async function writeStatement(page, text) {
  await page.waitForSelector('textarea[data-ocu-sql="statement"]', { timeout: config.navigationTimeoutMs });
  await page.click('textarea[data-ocu-sql="statement"]', { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type('textarea[data-ocu-sql="statement"]', text);
}

/** Make the background probe tables and remove the signed-in account's run rows; whether both took. */
function makeBackgroundProbe() {
  const output = runIris(config.container, [
    marker('MADE', `$System.Status.GetErrorText(##class(${BACKGROUND_PROBE}).Make())`),
    marker('FORGOT', `##class(OcuPilot.Kernel.State.SqlRun).GuardedForgetUser("${config.username}")`),
  ]);
  return markerValue(output, 'MADE') === '' && markerValue(output, 'FORGOT') === '1';
}

/** Remove the background probe tables and the signed-in account's run rows; whether both took and no run of its is live. */
function removeBackgroundProbe() {
  const output = runIris(config.container, [
    marker('REMOVED', `$System.Status.GetErrorText(##class(${BACKGROUND_PROBE}).Remove())`),
    marker('FORGOT', `##class(OcuPilot.Kernel.State.SqlRun).GuardedForgetUser("${config.username}")`),
    `Set tLive=##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(UserName) = ?","${config.username}")`,
    marker('LEFT', 'tLive.%Next()_"/"_tLive.%GetData(1)'),
  ]);
  return markerValue(output, 'REMOVED') === '' && markerValue(output, 'FORGOT') === '1' && markerValue(output, 'LEFT') === '1/0';
}

/** Wait until the Background run section's status line reads `text`. */
async function backgroundReads(page, text, timeout = config.navigationTimeoutMs) {
  await page.waitForFunction(
    (wanted) => (document.querySelector('[data-ocu-sql="background-status"]')?.textContent ?? '').trim() === wanted,
    { timeout },
    text
  );
}

/** Wait until the status line reads `text`. */
async function statusReads(page, text) {
  await page.waitForFunction(
    (wanted) => (document.querySelector('[data-ocu-sql="status"]')?.textContent ?? '').trim() === wanted,
    { timeout: config.navigationTimeoutMs },
    text
  );
}

test('AC1: a SELECT with a ? asks for its one value, and the value is bound and shown', async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${ROUTE}?ns=USER`, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await writeStatement(page, 'SELECT ? AS Echo');
    await page.click('button[data-ocu-sql="run"]');
    await statusReads(page, STRINGS.explorerSqlTakesValuesOne);
    assert.equal((await page.$$('input[data-ocu-sql="value"]')).length, 1, 'one value field, for the one ?');
    await page.type('input[data-ocu-sql="value"]', ECHO);
    await page.click('button[data-ocu-sql="run"]');
    await page.waitForSelector('[data-ocu-sql="cell"]', { timeout: config.navigationTimeoutMs });
    const cells = await page.$$eval('[data-ocu-sql="cell"]', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(cells, [ECHO], 'the value comes back as the one row\'s one cell');
    assert.equal(await page.$('app-warning-dialog'), null, 'a query runs without a confirmation');
    assert.deepEqual(await structural(page, ROUTE), [], 'SQL query with rows adds no structural entry');
  } finally {
    await context.close();
  }
});

test('AC2, AC9: a confirmed CREATE TABLE runs only at Proceed, and SQL tables then lists the table with its field', async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${ROUTE}?ns=USER`, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await writeStatement(page, `CREATE TABLE ${MADE} (X INTEGER)`);
    await page.click('button[data-ocu-sql="run"]');
    await page.waitForSelector('app-warning-dialog [role="dialog"]', { visible: true, timeout: config.navigationTimeoutMs });
    const opened = await page.evaluate(() => {
      const surface = document.querySelector('[role="dialog"]');
      return {
        title: (surface.querySelector('.ocu-dialog-title')?.textContent ?? '').trim(),
        body: (surface.querySelector('.ocu-warning-consequence')?.textContent ?? '').trim(),
      };
    });
    assert.deepEqual(opened, { title: STRINGS.explorerSqlConfirmTitle, body: STRINGS.explorerSqlConfirmDdl }, 'the warning names the statement\'s kind');
    assert.equal(holdsMade(), '0', 'nothing runs while the warning waits');

    await page.click('[role="dialog"] .ocu-dialog-actions .ocu-button-primary');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await statusReads(page, STRINGS.explorerSqlDone);
    assert.equal(holdsMade(), '1', 'Proceed created the table');
    assert.deepEqual(await structural(page, ROUTE), [], 'SQL query with a run\'s answer adds no structural entry');

    // Mutation (Rule 19): `SqlPort.Run` answers `done` for a `ddl` kind without executing it, recompiled
    // on the throwaway -> "Proceed created the table" goes red, and SQL tables would list no table.
    await page.goto(`${config.origin}/ocupilot/${TABLES_ROUTE}?ns=USER`, { waitUntil: 'networkidle2' });
    await page.waitForSelector('input[data-ocu-criterion="schema"]', { timeout: config.navigationTimeoutMs });
    await page.click('input[data-ocu-criterion="schema"]', { clickCount: 3 });
    await page.keyboard.press('Backspace');
    await page.type('input[data-ocu-criterion="schema"]', SCHEMA);
    await page.click('.ocu-criteria-controls button[type="submit"]');
    await page.waitForFunction(
      (selector, wanted) => Array.from(document.querySelectorAll(selector)).some((row) => row.querySelector('[role="gridcell"]')?.textContent.trim() === wanted),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      MADE
    );
    await clickRowCentre(page, { text: MADE, link: true });
    const id = encodeEntityId(MADE);
    await page.waitForFunction((path) => location.pathname === path, { timeout: config.navigationTimeoutMs }, `/ocupilot/${TABLES_ROUTE}/document/${id}`);
    // The address bar moves before the detail page renders its tab strip, so wait for the tab itself.
    const fieldsTab = `.ocu-detail-tab[data-route="${TABLES_ROUTE}/fields"]`;
    await page.waitForSelector(fieldsTab, { visible: true, timeout: config.navigationTimeoutMs });
    await page.focus(fieldsTab);
    await page.keyboard.press('Enter');
    await page.waitForFunction((path) => location.pathname === path, { timeout: config.navigationTimeoutMs }, `/ocupilot/${TABLES_ROUTE}/fields/${id}`);
    await page.waitForFunction(
      (selector) => Array.from(document.querySelectorAll(selector)).some((row) => row.querySelector('[role="gridcell"]')?.textContent.trim() === 'X'),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR
    );
  } finally {
    await context.close();
  }
});

test('AC11: a background COUNT leaves Run answering at once, its row arrives later, and Cancel on a second shows Canceled', async () => {
  assert.ok(makeBackgroundProbe(), 'the background probe tables exist and the account holds no run row');
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${ROUTE}?ns=USER`, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await writeStatement(page, COUNT);
    await page.click('button[data-ocu-sql="background"]');
    await backgroundReads(page, STRINGS.explorerSqlBackgroundRunning);

    await writeStatement(page, 'SELECT Name FROM OcuProbe1915.Granted WHERE Num = 1');
    await page.click('button[data-ocu-sql="run"]');
    await page.waitForSelector('[data-ocu-sql="cell"]', { timeout: config.navigationTimeoutMs });
    assert.deepEqual(await page.$$eval('[data-ocu-sql="cell"]', (nodes) => nodes.map((node) => node.textContent.trim())), ['n1'], 'Run answers its rows');
    const meanwhile = await page.$eval('[data-ocu-sql="background-status"]', (node) => node.textContent.trim());
    assert.equal(meanwhile, STRINGS.explorerSqlBackgroundRunning, 'while the background COUNT still runs');

    // Mutation (Rule 19): `SqlQueryState.readBackground` never adopts the polled answer, rebuilt and
    // redeployed to the throwaway -> the COUNT's row never reaches the section and this goes red.
    await backgroundReads(page, STRINGS.explorerSqlRowCountOne, 60000);
    assert.deepEqual(await page.$$eval('[data-ocu-sql="background-cell"]', (nodes) => nodes.map((node) => node.textContent.trim())), ['102400000'], 'the section shows the COUNT\'s row');
    assert.deepEqual(await structural(page, ROUTE), [], 'SQL query with a background run\'s rows adds no structural entry');

    await writeStatement(page, LONGER);
    await page.click('button[data-ocu-sql="background"]');
    await backgroundReads(page, STRINGS.explorerSqlBackgroundRunning);
    await page.waitForSelector('button[data-ocu-sql="background-cancel"]', { timeout: config.navigationTimeoutMs });
    await page.click('button[data-ocu-sql="background-cancel"]');
    await backgroundReads(page, STRINGS.explorerSqlBackgroundCanceled, 15000);
  } finally {
    await context.close();
    assert.ok(removeBackgroundProbe(), 'the background probe tables and the account\'s run rows are removed, and no run of its is live');
  }
});

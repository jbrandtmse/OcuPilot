/**
 * Story 19.10's SQL activity in a real browser, against the throwaway instance (AC1, AC4, AC5, AC6,
 * AC8); two legs signed in as throwaway principals, a caller whose statement text is withheld ("Not
 * shown", AC3) and a caller lacking one pair (AC2); and the empty state.
 *
 * What it pins: a probe statement running in USER is a row under the declared headers, carrying its
 * Process ID, Namespace, a numeric Elapsed and its Statement text, and never the value it binds; its
 * Process ID cell opens Process details for that pid; the command bar's auto-refresh chip starts off
 * and offers 5, 10, 30 and 60 s; and the screen passes the structural and contrast checks at 1280
 * light, 720 light and 1280 dark, with no entry beyond the baseline (DW-1337).
 *
 * It starts one probe job (`OcuPilot.Test.SqlActivityProbe.Start`, a read-only statement that ends
 * itself within 600 s) before the first test and stops it before the empty-state leg, creates two
 * principals (`OcuP1910Br*`) it removes after the last, and signs in and resets the account's
 * remembered state, so it runs on a throwaway only.
 *
 * Run: `node --test --test-concurrency=1 browser/sql-activity.browser-spec.mjs` (after `npm run build`,
 * the bundle copied into the throwaway, and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { resetRememberedState } from './preferences-reset.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const ROUTE = 'os-management/sql-activity';
const PAGE_URL = `/ocupilot/${ROUTE}?ns=HSCUSTOM`;
const PROBE = 'OcuPilot.Test.SqlActivityProbe';
const LITERAL = `OcuSeedBrowser1910${Date.now()}`;
const VALUE = `OcuSecretProbe1910Browser${Date.now()}`;

const PAIR_READ = '%DB_IRISSYS:READ';
const password = `OcuPilotSqlAct${randomBytes(12).toString('hex')}Aa9`;
const WITHHELD_USER = 'OcuP1910BrExact';
const NOSYS_USER = 'OcuP1910BrNoSys';
const PRINCIPALS = `${WITHHELD_USER}:%Admin_Operate:U,%DB_IRISSYS:R;${NOSYS_USER}:%Admin_Operate:U`;

let browser = null;
let pid = null;
let principalsMade = false;

/** Run ObjectScript lines in the install namespace with the principal helpers armed, answering stdout+stderr. */
function armedIris(lines) {
  const result = spawnSync(
    'docker',
    ['exec', '-i', '-e', 'OCUPILOT_ALLOW_PRINCIPALS=1', config.container, 'iris', 'session', 'iris', '-U', 'HSCUSTOM'],
    { input: `${[...lines, 'Halt'].join('\n')}\n`, encoding: 'utf8', timeout: 600000 }
  );
  return `${result.stdout ?? ''}${result.stderr ?? ''}`;
}

/** Signed in as `user` at SQL activity, the shell's panel rendered. */
async function signedInAs(user) {
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  await page.setViewport(VIEWPORTS.wide);
  await page.goto(`${config.origin}${PAGE_URL}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', user);
  await page.type('#ocu-signin-password', password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-panel aside.ocu-panel', { timeout: config.navigationTimeoutMs });
  return { context, page };
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates principals with docker exec, so it never runs against the live container');
  await assertThrowaway(config);
  const output = runIris(config.container, [
    `Set tSC=##class(${PROBE}).Start("USER","${LITERAL}","${VALUE}",.tPid) Write "OCU-SQLPROBE-START:",$Select($System.Status.IsOK(tSC):tPid,1:"error "_$System.Status.GetErrorText(tSC)),":OCU-SQLPROBE-END",!`,
  ]);
  const started = markerValue(output, 'SQLPROBE');
  assert.match(started ?? '', /^[0-9]+$/, `the probe job starts: ${output.slice(-400)}`);
  pid = started;
  const made = armedIris([
    `Set tSC=##class(${PROBE}).EnsurePrincipals("${PRINCIPALS}","${password}") Write "OCU-SQLPRIN-START:",$Select($System.Status.IsOK(tSC):"ok",1:$System.Status.GetErrorText(tSC)),":OCU-SQLPRIN-END",!`,
  ]);
  principalsMade = true;
  assert.equal(markerValue(made, 'SQLPRIN'), 'ok', `the principals are created: ${made.slice(-400)}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  const failures = [];
  try {
    if (browser !== null) await browser.close();
  } finally {
    if (pid !== null) {
      const output = runIris(config.container, [
        `Set tSC=##class(${PROBE}).Stop(${pid}) Write "OCU-SQLSTOP-START:",$Select($System.Status.IsOK(tSC):"ok",1:$System.Status.GetErrorText(tSC)),":OCU-SQLSTOP-END",!`,
      ]);
      if (markerValue(output, 'SQLSTOP') !== 'ok') failures.push(`the probe job is stopped: ${output.slice(-400)}`);
    }
    if (principalsMade) {
      const removed = armedIris([
        `Set tSC=##class(${PROBE}).RemovePrincipals("${PRINCIPALS}") Write "OCU-SQLPRIN-START:",$Select($System.Status.IsOK(tSC):"ok",1:$System.Status.GetErrorText(tSC)),":OCU-SQLPRIN-END",!`,
      ]);
      if (markerValue(removed, 'SQLPRIN') !== 'ok') failures.push(`the principals are removed: ${removed.slice(-400)}`);
    }
  }
  assert.deepEqual(failures, [], 'the probe and the principals are cleaned up');
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

// AC3. Mutation (Rule 19): set the generated mirror's Statement `emptyKey` to `sqlActivityLabel`,
// rebuilt and deployed -> the cell reads "SQL activity" and the withheld leg goes red. This principal
// holds no READ on USER's database, so the port's pre-check withholds the text without calling the
// vendor; `SqlActivityGate` pins that pre-check and the #921 case.
test("AC3: a caller holding the two pairs but no READ on USER's database sees the probe row with its Statement cell reading \"Not shown\"", async () => {
  const { context, page } = await signedInAs(WITHHELD_USER);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const rows = await describeRows(page);
    const row = rows.find((candidate) => candidate.cells[0] === pid);
    assert.ok(row !== undefined, `the probe ${pid} is a row: ${JSON.stringify(rows)}`);
    assert.equal(row.cells[5], STRINGS.sqlActivityTextWithheld, `its text is withheld: ${row.cells[5]}`);
    const text = await page.evaluate(() => document.body.textContent);
    assert.ok(!text.includes(LITERAL), 'the probe literal is nowhere on the page');
    assert.ok(!text.includes(VALUE), 'nor is the bound value');
  } finally {
    await context.close();
  }
});

// AC2. Mutation (Rule 19): drop `%DB_IRISSYS:READ` from `SqlActivityList.cls`'s `privileges`,
// recompiled on the throwaway -> the screen opens and the sentence wait goes red; so does granting the
// NoSys principal `%DB_IRISSYS:READ`. The refusal is the descriptor's verdict from `GET /navigation`:
// the page never mounts and sends no read, so the port's `PAIRS` is not on this path.
// `SqlActivityGate` and `PortGate` pin the port's 403, and `SqlActivityDescriptor` holds the
// descriptor's pairs equal to `PAIRS`.
test('AC2: a caller lacking the %DB_IRISSYS:READ pair is refused the screen, naming that pair, with no statement on the page', async () => {
  const { context, page } = await signedInAs(NOSYS_USER);
  try {
    const sentence = STRINGS.privilegeDeniedScreen.replace('<resource>', PAIR_READ).replace('<screen>', STRINGS.sqlActivityLabel);
    await page.waitForFunction(
      (wanted) => document.body.innerText.includes(wanted),
      { timeout: config.navigationTimeoutMs },
      sentence
    );
    assert.equal((await describeRows(page)).length, 0, 'no statement row is on the screen');
    assert.ok(!(await page.evaluate(() => document.body.textContent)).includes(LITERAL), 'the probe literal is nowhere on the page');
  } finally {
    await context.close();
  }
});

// Nothing running. Mutation (Rule 19): set the descriptor's `emptyStateKey` to `sqlActivityLabel` ->
// the empty state reads "SQL activity" and the sentence assertion goes red. Last, because it stops the
// probe the other legs read.
test('Nothing running: with the probe stopped the screen shows its empty state sentence and no row', async () => {
  const stopped = runIris(config.container, [
    `Set tSC=##class(${PROBE}).Stop(${pid}) Write "OCU-SQLSTOP-START:",$Select($System.Status.IsOK(tSC):"ok",1:$System.Status.GetErrorText(tSC)),":OCU-SQLSTOP-END",!`,
  ]);
  assert.equal(markerValue(stopped, 'SQLSTOP'), 'ok', `the probe job is stopped: ${stopped.slice(-400)}`);
  pid = null;
  const { context, page } = await signedInAt(browser, config, PAGE_URL, VIEWPORTS.wide);
  try {
    await page.waitForFunction(
      (sentence) => document.body.textContent.includes(sentence),
      { timeout: config.navigationTimeoutMs },
      STRINGS.sqlActivityEmpty
    );
    assert.equal((await describeRows(page)).length, 0, 'no row');
  } finally {
    await context.close();
  }
});

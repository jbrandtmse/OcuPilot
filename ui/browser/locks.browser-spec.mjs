/**
 * The Locks list in a real browser, against the throwaway instance: Story 6.10's declared read,
 * table and headers end to end, the empty `System` cell reading "This instance" for a local lock,
 * and the owner cell's declared `rowTarget` opening Process details for that row's own `Pid`; and
 * Story 16.12's Remove locks -- the dialog's three scopes with the one that does not fit the owner
 * `aria-disabled`, a removal of one lock and of every lock of a process with another process's lock
 * left standing, the in-transaction warning and its "Remove anyway", and the dialog's DW-1337 walk in
 * both themes.
 *
 * **Story 16.12's legs hold and remove probe locks, so they run on a throwaway only.** Each starts
 * its own holder processes (`OcuPilot.Test.LockRemoveLive.StartHolder`, locks on `^OcuProbeLock`,
 * each ending on its own within 300 s) and ends them in `finally`, whatever the test answered; no
 * other lock is removed.
 *
 * Run: `node --test --test-concurrency=1 browser/locks.browser-spec.mjs` (after `npm run build`, the
 * bundle copied into the throwaway, and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, viewCount, waitForRows } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';
import { INVARIANTS, VIEWPORTS, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const ROUTE = 'os-management/locks';
const LIST_URL = '/ocupilot/os-management/locks?ns=HSCUSTOM';
const READ_PATH = '/api/ocupilot/screens/osmgmt.locks/read';
const ACTION_PATH = '/api/ocupilot/screens/osmgmt.locks/action';
const HOLDERS = 'OcuPilot.Test.LockRemoveLive';

let browser = null;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec drives the throwaway, never the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
});

/** A fresh context signed in through the shell's own form at the list's deep link. */
async function signedInAtList(user, password) {
  // Story 15.5: the remembered screen and shell state lives on the instance now, keyed by the
  // one account every spec signs in as, so a fresh context is no longer a fresh slate on its
  // own -- see `preferences-reset.mjs`.
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  const reads = [];
  page.on('request', (request) => {
    if (new URL(request.url()).pathname.startsWith('/api/ocupilot/screens/')) reads.push(request.url());
  });
  await page.goto(`${config.origin}${LIST_URL}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', user);
  await page.type('#ocu-signin-password', password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, LIST_URL);
  return { context, page, reads };
}

/** Every rendered row, cell by cell, in row order. */
function describeRows(page) {
  return page.evaluate((rowSelector) => {
    const rows = Array.from(document.querySelectorAll(rowSelector));
    return rows.map((row) => ({
      cells: Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim()),
      link: row.querySelector('.ocu-data-table-link') !== null,
    }));
  }, ROW_SELECTOR);
}

test('AC1, AC2, AC9: the list reads once under the declared headers, and every row carries its seven columns and its actions', async () => {
  const { context, page, reads } = await signedInAtList(config.username, config.password);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const headers = await page.$$eval('.ocu-data-table-header-label', (labels) => labels.map((label) => label.textContent.trim()));
    assert.deepEqual(headers, [
      STRINGS.processColumnPid,
      STRINGS.processColumnUser,
      STRINGS.processColumnRoutine,
      STRINGS.lockColumnMode,
      STRINGS.lockColumnReference,
      STRINGS.lockColumnDirectory,
      STRINGS.lockColumnSystem,
      STRINGS.commandBoxGroupActions,
    ]);
    // Story 16.12: the screen declares row actions, so the table draws its actions column last.
    assert.deepEqual(headers, ['Process ID', 'User', 'Routine', 'Mode', 'Reference', 'Directory', 'System', 'Actions']);

    const total = await viewCount(page);
    assert.ok(total >= 1, `the instance holds at least one lock (the license monitor's own): ${total}`);

    const rows = await describeRows(page);
    for (const row of rows) {
      assert.equal(row.cells.length, 8, `every row carries its seven data cells, then its actions cell: ${JSON.stringify(row)}`);
      assert.notEqual(row.cells[0], '', 'Pid is never blank');
    }
    // AC10: a local lock's own scope marker is empty, and the emptyKey rule renders it as the
    // instance's own name rather than "(none)".
    assert.ok(
      rows.some((row) => row.cells[6] === STRINGS.lockSystemLocal),
      `at least one local lock's System cell reads "${STRINGS.lockSystemLocal}": ${JSON.stringify(rows)}`
    );
    assert.equal(STRINGS.lockSystemLocal, 'This instance');

    assert.equal(reads.length, 1, `exactly one screen read was issued: ${JSON.stringify(reads)}`);
    assert.equal(new URL(reads[0]).pathname, READ_PATH);
  } finally {
    await context.close();
  }
});

test("AC4: the owner cell opens Process details for that row's Pid, encoded once, not the row's own composite removal id", async () => {
  const { context, page } = await signedInAtList(config.username, config.password);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const rows = await describeRows(page);
    assert.ok(rows.length >= 1, 'at least one row is rendered');
    assert.equal(rows[0].link, true, "the first row's owner cell is a link");
    const pid = rows[0].cells[0];

    // A real hit-tested pointer click at the first row's link (DW-273), which is what a user does.
    await clickRowCentre(page, { index: 0, link: true });
    await page.waitForFunction(
      () => /^\/ocupilot\/os-management\/processes\/details\/[^/]+$/.test(window.location.pathname),
      { timeout: config.navigationTimeoutMs }
    );
    const routeId = new URL(page.url()).pathname.split('/').pop();
    assert.equal(routeId, pid, "the route id is the row's own Pid -- fieldOf(row, 'Pid'), not rowKey(row, screen)'s DeleteID");
    // Process details renders for a pid that is still alive. A RemoteOwner row has no local pid and
    // its cell is text (Story 16.12, DW-1074), which `data-table.spec.ts` pins on canned rows: no
    // remote owner holds a lock on a throwaway without ECP.
    await page.waitForSelector('.ocu-details-fields, .ocu-empty-state', { timeout: config.navigationTimeoutMs });
  } finally {
    await context.close();
  }
});

// --- Story 16.12: Remove locks ----------------------------------------------------------------

/** A tag no earlier run used, letters and digits, so a filter by it finds this run's probe rows alone. */
function freshTag() {
  return `brw${Date.now().toString(36)}`;
}

/** Start a holder of `count` probe locks under `tag`, in a transaction when `inTxn`, and answer its pid. */
function startHolder(tag, count, inTxn) {
  const output = runIris(config.container, [
    `Set pid=##class(${HOLDERS}).StartHolder("${tag}",${count},${inTxn ? 1 : 0})`,
    'Write "OCU-LOCKHOLDER-START:"_pid_":OCU-LOCKHOLDER-END",!',
  ]);
  const pid = markerValue(output, 'LOCKHOLDER');
  assert.ok(pid !== null && /^[1-9][0-9]*$/.test(pid), `a holder of ${count} probe lock(s) under ${tag} started: ${output}`);
  return pid;
}

/** End each holder this spec started, and forget its beat. */
function stopHolders(pids) {
  for (const pid of pids) {
    runIris(config.container, [`Do ##class(${HOLDERS}).StopHolder("${pid}")`, 'Write "OCU-LOCKSTOP-START:ok:OCU-LOCKSTOP-END",!']);
  }
}

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/**
 * The DW-1337 walk of this screen at 1280 light, 720 light and 1280 dark, answering every entry the
 * baseline does not already hold; the open dialog's body is also held to scrolling nothing sideways.
 */
async function structural(page) {
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
    const body = await page.$eval('.ocu-dialog-body', (element) => ({ scroll: element.scrollWidth, client: element.clientWidth }));
    assert.ok(body.scroll <= body.client, `the dialog body does not scroll sideways at ${viewport.width}px ${theme}: ${JSON.stringify(body)}`);
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await frames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  return compare(collapse(found), readBaseline()?.entries ?? []).fresh.map((entry) => `${entry.key}: ${entry.measured}`);
}

/** Signed in at the list with its rows rendered, recording every request to the action route. */
async function atLocks() {
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const posts = [];
  page.on('request', (request) => {
    if (new URL(request.url()).pathname === ACTION_PATH) posts.push({ method: request.method(), body: request.postData() ?? '' });
  });
  await waitForRows(page, config.navigationTimeoutMs);
  return { context, page, posts };
}

/** Filter the list by `text` and wait until exactly `count` rows show it. */
async function filterTo(page, text, count) {
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, text);
  await waitForProbeRows(page, text, count);
}

/** Wait until exactly `count` rendered rows carry `text`. */
function waitForProbeRows(page, text, count) {
  return page.waitForFunction(
    (rowSelector, wanted, expected) => Array.from(document.querySelectorAll(rowSelector)).filter((row) => row.textContent.includes(wanted)).length === expected,
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    text,
    count
  );
}

/** The rendered rows' cells, in row order. */
function probeRows(page, text) {
  return page.evaluate(
    (rowSelector, wanted) =>
      Array.from(document.querySelectorAll(rowSelector))
        .filter((row) => row.textContent.includes(wanted))
        .map((row) => Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim())),
    ROW_SELECTOR,
    text
  );
}

/** Select the rendered row whose Reference cell reads `reference`, by its Routine cell, and open Remove locks from its row menu. */
async function openRemove(page, reference) {
  const index = await page.evaluate(
    (rowSelector, wanted) => Array.from(document.querySelectorAll(rowSelector)).findIndex((row) => Array.from(row.querySelectorAll('[role="gridcell"]')).some((cell) => cell.textContent.trim() === wanted)),
    ROW_SELECTOR,
    reference
  );
  assert.ok(index >= 0, `the row for ${reference} is rendered`);
  await clickRowCentre(page, { index, cell: 3 });
  await page.waitForFunction(
    (rowSelector, at) => document.querySelectorAll(rowSelector)[at]?.getAttribute('aria-selected') === 'true',
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    index
  );
  await page.click(`${ROW_SELECTOR}[aria-selected="true"] .ocu-data-table-trigger`);
  await page.waitForSelector('[role="menu"]', { timeout: config.navigationTimeoutMs });
  const labels = await page.evaluate(() => Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"] .ocu-data-table-menu-label')).map((label) => label.textContent.trim()));
  assert.deepEqual(labels, [STRINGS.lockRemoveAction], 'the row menu draws one entry, Remove locks');
  await page.evaluate((label) => {
    Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'))
      .find((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === label)
      .click();
  }, STRINGS.lockRemoveAction);
  await page.waitForSelector('app-lock-remove-dialog [role="dialog"]', { timeout: config.navigationTimeoutMs });
}

/** The open dialog's scopes as drawn: each one's label, whether it is checked, its aria-disabled and its reason. */
function scopes(page) {
  return page.evaluate(() =>
    Array.from(document.querySelectorAll('app-lock-remove-dialog [data-scope]')).map((label) => {
      const input = label.querySelector('input');
      const describedBy = input.getAttribute('aria-describedby');
      return {
        scope: label.getAttribute('data-scope'),
        label: label.textContent.trim(),
        checked: input.checked,
        disabled: input.getAttribute('aria-disabled'),
        reason: describedBy === null ? '' : (document.getElementById(describedBy)?.textContent.trim() ?? ''),
      };
    })
  );
}

/** Type `pid` into the dialog's name field and press Remove. */
async function typeAndRemove(page, pid) {
  await page.click('.ocu-typed-name-field', { clickCount: 3 });
  await page.type('.ocu-typed-name-field', pid);
  await page.waitForFunction(() => document.querySelector('.ocu-lock-remove-submit')?.getAttribute('aria-disabled') === null, { timeout: config.navigationTimeoutMs });
  await page.click('.ocu-lock-remove-submit');
}

test('Story 16.12, AC1: Remove locks offers the three scopes with the remote client\'s aria-disabled, and removes this lock alone', async () => {
  assert.match(config.container, /-ci$/, `this leg holds and removes probe locks, so it runs only in a throwaway; ${config.container} is not one`);
  const tag = freshTag();
  const pid = startHolder(tag, 2, false);
  const { context, page, posts } = await atLocks();
  try {
    await filterTo(page, tag, 2);
    const first = `^OcuProbeLock("${tag}",1)`;
    await openRemove(page, first);
    assert.equal(await page.$eval('.ocu-dialog-title', (title) => title.textContent.trim()), STRINGS.lockRemoveTitle.split('<PID>').join(pid), 'the title names the Process ID');
    assert.deepEqual(await scopes(page), [
      { scope: 'remove', label: STRINGS.lockRemoveScopeLock.split('<REFERENCE>').join(first), checked: true, disabled: null, reason: '' },
      { scope: 'removeprocess', label: STRINGS.lockRemoveScopeProcess, checked: false, disabled: null, reason: '' },
      { scope: 'removeclient', label: STRINGS.lockRemoveScopeClient, checked: false, disabled: 'true', reason: STRINGS.lockRemoveRefusalLocal },
    ], 'three scopes, each naming what it removes, the remote client\'s unavailable with its reason');
    await page.click('[data-scope="removeclient"] input');
    await frames(page);
    assert.equal((await scopes(page))[2].checked, false, 'a click leaves the remote client\'s scope unselected');
    assert.equal(await page.$eval('.ocu-lock-remove-consequence', (line) => line.textContent.trim()), STRINGS.lockRemoveConsequence, 'the body states the consequence');
    await typeAndRemove(page, pid);
    await page.waitForFunction(() => document.querySelector('app-lock-remove-dialog') === null, { timeout: config.navigationTimeoutMs });
    await waitForProbeRows(page, tag, 1);
    assert.equal((await probeRows(page, tag))[0][4], `^OcuProbeLock("${tag}",2)`, 'the removed lock leaves the list and the other stays');
    assert.equal(posts.length, 1, `one request: ${JSON.stringify(posts)}`);
    assert.equal(JSON.parse(posts[0].body).action, 'remove', 'for this lock');
  } finally {
    await context.close();
    stopHolders([pid]);
  }
});

test('Story 16.12, AC4: every lock of a process is removed, and another process\'s lock stays', async () => {
  assert.match(config.container, /-ci$/, `this leg holds and removes probe locks, so it runs only in a throwaway; ${config.container} is not one`);
  const tag = freshTag();
  const first = startHolder(`${tag}p`, 2, false);
  const other = startHolder(`${tag}q`, 1, false);
  const { context, page } = await atLocks();
  try {
    await filterTo(page, tag, 3);
    await openRemove(page, `^OcuProbeLock("${tag}p",1)`);
    await page.click('[data-scope="removeprocess"] input');
    await frames(page);
    assert.equal((await scopes(page))[1].checked, true, 'every lock of the process is chosen');
    await typeAndRemove(page, first);
    await page.waitForFunction(() => document.querySelector('app-lock-remove-dialog') === null, { timeout: config.navigationTimeoutMs });
    await waitForProbeRows(page, tag, 1);
    assert.equal((await probeRows(page, tag))[0][4], `^OcuProbeLock("${tag}q",1)`, 'the other process\'s lock stays');
  } finally {
    await context.close();
    stopHolders([first, other]);
  }
});

test('Story 16.12, AC2: a holder in a transaction is warned about before anything is removed, and Remove anyway removes it', async () => {
  assert.match(config.container, /-ci$/, `this leg holds and removes probe locks, so it runs only in a throwaway; ${config.container} is not one`);
  const tag = freshTag();
  const pid = startHolder(tag, 1, true);
  const { context, page, posts } = await atLocks();
  try {
    await filterTo(page, tag, 1);
    await openRemove(page, `^OcuProbeLock("${tag}",1)`);
    await typeAndRemove(page, pid);
    await page.waitForSelector('.ocu-lock-remove-warning', { timeout: config.navigationTimeoutMs });
    assert.deepEqual(
      await page.evaluate(() => ({
        role: document.querySelector('.ocu-lock-remove-warning').getAttribute('role'),
        text: document.querySelector('.ocu-lock-remove-warning .ocu-banner-message').textContent.trim(),
        button: document.querySelector('.ocu-lock-remove-submit').textContent.trim(),
      })),
      { role: 'alert', text: STRINGS.lockRemoveInTransaction, button: STRINGS.lockRemoveAnyway },
      'the dialog stays open and warns, and Remove becomes Remove anyway'
    );
    assert.equal((await probeRows(page, tag)).length, 1, 'and the lock is still listed');
    await page.click('.ocu-lock-remove-submit');
    await page.waitForFunction(() => document.querySelector('app-lock-remove-dialog') === null, { timeout: config.navigationTimeoutMs });
    await waitForProbeRows(page, tag, 0);
    assert.deepEqual(posts.map((post) => JSON.parse(post.body).values), [{ RemoveInTransaction: 'false' }, { RemoveInTransaction: 'true' }], 'the second send overrides the check');
  } finally {
    await context.close();
    stopHolders([pid]);
  }
});

test('Story 16.12, DW-1337: the Remove locks dialog, warning shown, passes the structural walk in both themes', async () => {
  assert.match(config.container, /-ci$/, `this leg holds a probe lock, so it runs only in a throwaway; ${config.container} is not one`);
  const tag = freshTag();
  const pid = startHolder(tag, 1, true);
  const { context, page } = await atLocks();
  try {
    await filterTo(page, tag, 1);
    await openRemove(page, `^OcuProbeLock("${tag}",1)`);
    await typeAndRemove(page, pid);
    await page.waitForSelector('.ocu-lock-remove-warning', { timeout: config.navigationTimeoutMs });
    assert.deepEqual(await structural(page), [], 'with the dialog open and its warning showing, no violation beyond the baseline\'s entries');
  } finally {
    await context.close();
    stopHolders([pid]);
  }
});


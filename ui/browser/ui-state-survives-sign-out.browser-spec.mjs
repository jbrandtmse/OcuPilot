/**
 * Story 15.5's Integration AC (Rule 1), end to end in a real browser: the six things the portal
 * remembers -- a screen's sort, filter, max-rows cap and auto-refresh rate, the side bar's open
 * state and the panel's width -- set in one browser context, and rendered unchanged after a real
 * sign-out and a sign-in in a **brand-new** one.
 *
 * preferences-reset-exempt: it is about state surviving a sign-out, so it sets and clears its own rows.
 *
 * **Why this file.** Each link has its own pinning test -- `OcuPilot.Test.PreferencesWire` proves
 * the instance keeps the rows, `ui/tools/api.test.mjs` bans `localStorage` everywhere under
 * `ui/src`, and the component specs prove each store reads `AccountPreferences` -- but nothing
 * drives the deployed client through a genuine second session and asks whether the *composition*
 * holds. jsdom has no second context and no real storage, so this claim can only be settled here.
 *
 * **A brand-new `BrowserContext`, not a second tab.** Puppeteer's incognito-style context starts
 * with an empty cookie jar, `localStorage` and `sessionStorage`, so none of the first context's
 * state can carry over by construction -- which also settles the spec's manual check ("clear the
 * browser's site data for the origin and repeat"). The explicit Sign out is what ends the CSP
 * session, so the second context's sign-in cannot be a silent probe over a cookie it does not have.
 *
 * Refuses the live container, the way every write-driving spec here does. Clears this caller's
 * preferences before and after, so a re-run starts clean and leaves the throwaway as it found it.
 *
 * Run: `npm run build`, redeploy the bundle, then
 * `OCUPILOT_BROWSER_ORIGIN=<your slot's browser_origin> OCUPILOT_BROWSER_CONTAINER=<its container> \
 *   node --test --test-concurrency=1 browser/ui-state-survives-sign-out.browser-spec.mjs`
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();

/** A roster screen (AD-43), so the auto-refresh chip is one of the six things under test. */
const LIST_URL = '/ocupilot/os-management/processes?ns=HSCUSTOM';
const PREFERENCES_PATH = '/api/ocupilot/account/preferences';
const SORT_TRIGGER = '.ocu-command-bar-sort-trigger';
const SORT_ITEM = '.ocu-command-bar-sort-item';

/** The cap and the filter this spec sets: neither is any screen's default, so neither can pass by accident. */
const CAP = 7;
const FILTER = 'IRIS';

/**
 * The only two keys AC2 lets the browser hold: the per-tab token pair and the nonce that scopes
 * it to this tab (`core/token-store.ts`, Story 1.6). Anything else in `sessionStorage` is state
 * this story moved to the instance leaking back into the browser.
 */
const ALLOWED_SESSION_KEYS = ['ocupilot.tab-nonce', 'ocupilot.token-pair'];

let browser = null;

before(async () => {
  // Not required by DW-159's gate, which only binds specs that run a docker command: this one
  // writes the signed-in account's own rows, which is reason enough to refuse the live instance.
  assert.notEqual(config.container, LIVE_CONTAINER, "this spec writes the signed-in user's remembered state, so it never runs against the live container");
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await clearPreferences();
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  // The browser closes first, the way `preferences-integration.browser-spec.mjs` orders it: a
  // `before` that failed its own assertion must not have its error masked by a teardown.
  if (browser === null) return;
  await browser.close();
  browser = null;
  await clearPreferences();
});

function authHeader() {
  return 'Basic ' + Buffer.from(`${config.username}:${config.password}`).toString('base64');
}

/** This caller's whole preference body, read over the shipped route. */
async function preferences() {
  const answer = await fetch(`${config.origin}${PREFERENCES_PATH}`, {
    headers: { Authorization: authHeader() },
  });
  const text = await answer.text();
  assert.equal(answer.status, 200, `the preferences read answers: ${text}`);
  return JSON.parse(text);
}

/**
 * Put this caller's remembered state back to empty.
 *
 * Every kind clears through the shipped route: `clear` is the one action all five take, value
 * kinds included (`Api/Preferences.cls` `ACTIONCLEAR`). Doing it over HTTP keeps the setup inside
 * what this spec is about -- a container-exec failure here would fail the Integration AC for a
 * reason it does not test.
 */
async function clearPreferences() {
  for (const kind of ['favorite', 'recent', 'view', 'refresh', 'shell']) {
    const answer = await fetch(`${config.origin}${PREFERENCES_PATH}`, {
      method: 'POST',
      headers: { Authorization: authHeader(), 'Content-Type': 'application/json' },
      body: JSON.stringify({ kind, action: 'clear' }),
    });
    assert.equal(answer.status, 200, `the ${kind} kind cleared: ${await answer.text()}`);
  }
  const held = await preferences();
  assert.deepEqual(
    [held.views.length, held.refreshRates.length, held.shell.length],
    [0, 0, 0],
    `and nothing survives: ${JSON.stringify(held)}`
  );
}

/** A fresh context signed in through the shell's own form, landed at `url`. */
async function signedInAt(url) {
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  await page.goto(`${config.origin}${url}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', config.username);
  await page.type('#ocu-signin-password', config.password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, url);
  await page.waitForSelector('.ocu-data-table-row', { timeout: config.navigationTimeoutMs });
  return { context, page };
}

/** Pick one entry from the command bar's sort menu by its own label. */
async function chooseSort(page, label) {
  await page.click(SORT_TRIGGER);
  await page.waitForSelector(SORT_ITEM, { timeout: config.navigationTimeoutMs });
  const offered = await page.evaluate(
    (selector, wanted) => {
      const item = Array.from(document.querySelectorAll(selector)).find(
        (candidate) => candidate.textContent.trim() === wanted
      );
      if (item === undefined) {
        return Array.from(document.querySelectorAll(selector)).map((candidate) => candidate.textContent.trim());
      }
      item.click();
      return null;
    },
    SORT_ITEM,
    label
  );
  assert.equal(offered, null, `the sort menu offers ${JSON.stringify(label)}; it offered ${JSON.stringify(offered)}`);
  await page.waitForFunction((selector) => document.querySelector(selector) === null, {}, SORT_ITEM);
}

/** The six remembered things, as the rendered shell reports each of them. */
async function rendered(page) {
  return page.evaluate(() => ({
    sorts: Array.from(document.querySelectorAll('[role="columnheader"]')).map((cell) => cell.getAttribute('aria-sort')),
    filter: document.querySelector('#ocu-command-bar-filter')?.value ?? null,
    maxRows: document.querySelector('.ocu-data-table-max-rows')?.value ?? null,
    rate: document.querySelector('.ocu-command-bar-refresh')?.textContent.trim() ?? null,
    sideBar: document.querySelector('app-side-bar nav') !== null,
    panelWidth: Math.round(document.querySelector('app-panel aside.ocu-panel')?.getBoundingClientRect().width ?? 0),
  }));
}

/** Every key this document's own storage holds, read as plain pairs. */
async function clientStorageEntries(page) {
  return page.evaluate(() => ({
    local: Object.keys(localStorage).map((key) => [key, localStorage.getItem(key)]),
    session: Object.keys(sessionStorage).map((key) => [key, sessionStorage.getItem(key)]),
  }));
}

test('Integration AC: all six remembered things return after a real sign-out and a sign-in in a brand-new context, and none of them was in browser storage', async () => {
  let first = null;
  let second = null;
  try {
    first = await signedInAt(LIST_URL);
    const before = await rendered(first.page);
    assert.equal(before.sideBar, true, 'the side bar starts open, which is the published default');
    assert.equal(before.rate, STRINGS.statusAutoRefreshOff, 'and auto-refresh starts off');
    assert.equal(before.panelWidth, 400, 'and the panel starts at its published default width');

    // 1 and 2: a sort field and a direction, neither of them the declared default.
    await chooseSort(first.page, STRINGS.processColumnCommands);
    await first.page.waitForFunction(
      () => Array.from(document.querySelectorAll('[role="columnheader"]')).some((cell) => cell.getAttribute('aria-sort') === 'ascending'),
      { timeout: config.navigationTimeoutMs }
    );
    await chooseSort(first.page, STRINGS.sortDirectionDescending);
    await first.page.waitForFunction(
      () => Array.from(document.querySelectorAll('[role="columnheader"]')).some((cell) => cell.getAttribute('aria-sort') === 'descending'),
      { timeout: config.navigationTimeoutMs }
    );

    // 3: a filter.
    await first.page.click('#ocu-command-bar-filter');
    await first.page.type('#ocu-command-bar-filter', FILTER);
    await first.page.waitForFunction(
      (wanted) => document.querySelector('#ocu-command-bar-filter').value === wanted,
      { timeout: config.navigationTimeoutMs },
      FILTER
    );

    // 4: a max-rows cap.
    await first.page.click('.ocu-data-table-max-rows', { clickCount: 3 });
    await first.page.keyboard.press('Backspace');
    await first.page.type('.ocu-data-table-max-rows', String(CAP));
    await first.page.keyboard.press('Enter');
    await first.page.waitForFunction(
      (wanted) => document.querySelector('.ocu-data-table-max-rows').value === wanted,
      { timeout: config.navigationTimeoutMs },
      String(CAP)
    );

    // 5: the auto-refresh rate -- the chip's first advance from off is the lowest declared rate.
    await first.page.click('.ocu-command-bar-refresh');
    await first.page.waitForFunction(
      () => document.querySelector('.ocu-command-bar-refresh').textContent.trim() !== 'Auto-refresh: off',
      { timeout: config.navigationTimeoutMs }
    );
    const rate = await first.page.$eval('.ocu-command-bar-refresh', (chip) => chip.textContent.trim());

    // 6: the side bar collapsed by the chord, which is the user answering rather than a dismissal.
    await first.page.focus('main#ocu-content');
    await first.page.keyboard.down('Control');
    await first.page.keyboard.press('KeyB');
    await first.page.keyboard.up('Control');
    await first.page.waitForFunction(() => document.querySelector('app-side-bar nav') === null, {
      timeout: config.navigationTimeoutMs,
    });

    // 7: the panel's width, moved off its default by the handle's own keyboard step.
    await first.page.focus('app-panel [role="separator"]');
    await first.page.keyboard.press('ArrowLeft');
    await first.page.keyboard.press('ArrowLeft');
    await first.page.waitForFunction(
      () => Math.round(document.querySelector('app-panel aside.ocu-panel').getBoundingClientRect().width) === 432,
      { timeout: config.navigationTimeoutMs }
    );

    const set = await rendered(first.page);
    assert.equal(set.filter, FILTER);
    assert.equal(set.maxRows, String(CAP));
    assert.equal(set.rate, rate);
    assert.equal(set.sideBar, false);
    assert.equal(set.panelWidth, 432);
    assert.ok(set.sorts.includes('descending'), `a column is sorted descending: ${JSON.stringify(set.sorts)}`);

    // AC2's other half, read in the context that did the writing: a client that mirrored any of
    // this to browser storage on write would leave it here, and the second context -- which only
    // reads -- would show nothing either way.
    //
    // Asserted as the KEY SET rather than by searching the stored values for the figures this
    // spec set. Those values are a JWT and a random per-tab nonce, and a needle as short as
    // `432` turns up inside random material often enough to redden this row on an otherwise
    // green run -- which is what CI did on 2026-09-21 while the same tree passed locally. The
    // key set is also what AC2 actually claims ("the browser holding only the per-tab token
    // pair"), and it catches a seventh key whatever its value happens to contain.
    const wrote = await clientStorageEntries(first.page);
    const unexpectedSession = (entries) =>
      entries.map(([key]) => key).filter((key) => !ALLOWED_SESSION_KEYS.includes(key)).sort();
    assert.equal(wrote.local.length, 0, `nothing at all is in localStorage: ${JSON.stringify(wrote.local)}`);
    assert.deepEqual(unexpectedSession(wrote.session), [], `sessionStorage holds only the per-tab token pair: ${JSON.stringify(wrote.session)}`);

    // The instance is where they went. Read over the shipped route, as the account itself.
    const held = await preferences();
    const shellNames = held.shell.map((row) => row.name).sort();
    assert.deepEqual(shellNames, ['panelWidth', 'sideBarOpen'], `the instance holds both shell members: ${JSON.stringify(held.shell)}`);
    assert.equal(held.views.length, 1, `and one remembered view: ${JSON.stringify(held.views)}`);
    assert.equal(held.refreshRates.length, 1, `and one remembered rate: ${JSON.stringify(held.refreshRates)}`);

    // Sign out for real: the CSP session this context held is ended, so the second context's own
    // sign-in cannot be a silent probe over a cookie it does not even have.
    await first.page.click('#ocu-account-trigger');
    await first.page.waitForSelector('[role="menuitem"]', { visible: true, timeout: config.navigationTimeoutMs });
    const signedOut = await first.page.evaluate((label) => {
      const item = [...document.querySelectorAll('[role="menuitem"]')].find(
        (candidate) => candidate.textContent.trim() === label
      );
      if (item === undefined) return false;
      item.id = 'ocu-probe-sign-out';
      return true;
    }, STRINGS.actionSignOut);
    assert.ok(signedOut, 'the account menu lists Sign out');
    await first.page.click('#ocu-probe-sign-out');
    await first.page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });

    // A brand-new context: no cookie, no localStorage, no sessionStorage, nothing of the first.
    second = await signedInAt(LIST_URL);
    await second.page.waitForFunction(
      (wanted) => document.querySelector('#ocu-command-bar-filter')?.value === wanted,
      { timeout: config.navigationTimeoutMs },
      FILTER
    );
    // The width change animates over 120 ms (EXPERIENCE.md "Right of every route."), so the
    // remembered width is measured once it has arrived rather than part-way through: a snapshot
    // taken mid-animation reads a pixel short and says the preference did not come back.
    await second.page.waitForFunction(
      () => Math.round(document.querySelector('app-panel aside.ocu-panel').getBoundingClientRect().width) === 432,
      { timeout: config.navigationTimeoutMs }
    );
    const after = await rendered(second.page);

    assert.deepEqual(after.sorts, set.sorts, 'the sort field and direction return as they were');
    assert.equal(after.filter, set.filter, 'and the filter');
    assert.equal(after.maxRows, set.maxRows, 'and the max-rows cap');
    assert.equal(after.rate, set.rate, 'and the auto-refresh rate');
    assert.equal(after.sideBar, false, 'and the side bar is still collapsed');
    assert.equal(after.panelWidth, 432, 'and the panel is still at the width it was dragged to');

    // And this context's own storage, which never held the first one's token pair either.
    const storage = await clientStorageEntries(second.page);
    assert.equal(storage.local.length, 0, `nothing reached localStorage: ${JSON.stringify(storage.local)}`);
    assert.deepEqual(unexpectedSession(storage.session), [], `nor does the signed-in second context: ${JSON.stringify(storage.session)}`);
  } finally {
    if (first !== null) await first.context.close();
    if (second !== null) await second.context.close();
  }
});

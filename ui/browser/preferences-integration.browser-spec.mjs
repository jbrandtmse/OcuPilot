/**
 * The Integration AC (Rule 1) of Story 15.2, end to end in a real browser (DW-1329, QA):
 * favorites and recents held before a sign-out render unchanged after signing back in in a new
 * tab, because the state was read from the instance and no browser storage holds it.
 *
 * **Why this file, and why it was missing.** Every link in the chain has its own pinning test --
 * `OcuPilot.Test.PreferencesWire` proves the instance keeps the rows, `ui/tools/api.test.mjs`
 * bans `localStorage` outside `core/preferences.ts`, and the component specs prove the locator
 * toggle and Home's two blocks read `AccountPreferences` correctly -- but nothing drove the real
 * deployed client through a genuine second session and asked whether the *composition* holds.
 * jsdom has no second tab and no real `sessionStorage`/`localStorage`/cookie jar, so this claim
 * can only be settled here.
 *
 * **A brand-new `BrowserContext`, not merely `browser.newPage()`.** Puppeteer's incognito-style
 * context starts with an empty cookie jar, `localStorage` and `sessionStorage` -- none of the
 * first context's state carries over by construction. That is a strict superset of "a new tab":
 * it also settles the spec's own manual check ("clear the browser's site data for the origin and
 * repeat"), which its `## Verification` records as **not performed by this pass**. Signing in
 * there again is what "signs back in in a new tab" means once the CSP session the first context
 * held has been ended by an explicit Sign out -- `token-store.ts`'s per-tab `sessionStorage` pair
 * is not on its own conclusive, because a page reached by an ordinary navigation (not a reload)
 * re-authenticates silently over the CSP browser-id cookie; only an explicit Sign out kills that.
 *
 * Refuses the live container, the way every write-driving spec here does. Clears both lists for
 * this caller before and after, so a re-run starts clean and leaves the throwaway as it found it.
 *
 * Run: `npm run build` (only if client source changed -- this file adds no production code),
 * then, against the already-deployed bundle:
 * `OCUPILOT_BROWSER_ORIGIN=http://localhost:52779 OCUPILOT_BROWSER_CONTAINER=ocupilot-c-ci \
 *   node --test --test-concurrency=1 browser/preferences-integration.browser-spec.mjs`
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';

const config = browserConfig();
const STRINGS = loadStrings();

const HOME_URL = '/ocupilot/?ns=HSCUSTOM';
/** Favorited through the locator bar's own toggle -- the real client write path. */
const USERS_URL = '/ocupilot/permissions/users?ns=HSCUSTOM';
/** Visited, never favorited: registers as a recent with no explicit action (AC3). */
const ALERTS_URL = '/ocupilot/logs/alerts?ns=HSCUSTOM';
const PREFERENCES_PATH = '/api/ocupilot/account/preferences';

let browser = null;

before(async () => {
  assert.notEqual(
    config.container,
    LIVE_CONTAINER,
    'this spec writes the signed-in user\'s favorites and recents, so it never runs against the live container'
  );
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await clearPreferences();
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  // The browser closes first, the way `switches.browser-spec.mjs` orders it: a `before` that
  // failed its own assertion, or a throwaway that is simply gone, must not have its own error
  // masked by a teardown that runs anyway.
  if (browser === null) return;
  await browser.close();
  browser = null;
  await clearPreferences();
});

function authHeader() {
  return 'Basic ' + Buffer.from(`${config.username}:${config.password}`).toString('base64');
}

/** Put this caller's favorites and recents back to empty, over the shipped route. */
async function clearPreferences() {
  for (const kind of ['favorite', 'recent']) {
    const answer = await fetch(`${config.origin}${PREFERENCES_PATH}`, {
      method: 'POST',
      headers: { Authorization: authHeader(), 'Content-Type': 'application/json' },
      body: JSON.stringify({ kind, action: 'clear' }),
    });
    assert.equal(answer.status, 200, `${kind}s cleared: ${await answer.text()}`);
  }
}

/** A fresh context signed in through the shell's own form, landed at `url` -- one browser tab's worth of storage. */
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
  return { context, page };
}

/** The labels rendered in one Home block, found by its own `<h2>` text -- there is no other hook. */
async function blockLabels(page, heading) {
  return page.evaluate((wantedHeading) => {
    const section = [...document.querySelectorAll('.ocu-home-block')].find(
      (candidate) => candidate.querySelector('.ocu-home-block-heading')?.textContent.trim() === wantedHeading
    );
    if (section === undefined) return null;
    return [...section.querySelectorAll('.ocu-home-block-label')].map((label) => label.textContent.trim());
  }, heading);
}

/** Every key this document's own `localStorage`/`sessionStorage` holds, read as plain pairs. */
async function clientStorageEntries(page) {
  return page.evaluate(() => ({
    local: Object.keys(localStorage).map((key) => [key, localStorage.getItem(key)]),
    session: Object.keys(sessionStorage).map((key) => [key, sessionStorage.getItem(key)]),
  }));
}

test('DW-1329 (Integration AC): favorites and recents held before sign-out render unchanged after signing back in in a new tab, and no browser storage carried them', async () => {
  let first = null;
  let second = null;
  try {
    first = await signedInAt(USERS_URL);

    // AC1: pin the screen through the locator bar's own toggle -- the real client write path.
    await first.page.waitForSelector('.ocu-locator-favorite', { timeout: config.navigationTimeoutMs });
    await first.page.click('.ocu-locator-favorite');
    await first.page.waitForFunction(
      () => document.querySelector('.ocu-locator-favorite')?.getAttribute('aria-pressed') === 'true',
      { timeout: config.navigationTimeoutMs }
    );

    // AC3: a recent is registered by visiting a second built screen, with no explicit action.
    await first.page.goto(`${config.origin}${ALERTS_URL}`, { waitUntil: 'networkidle2' });
    await first.page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
    // `registerVisit` is fire and forget (`recents-recorder.ts`): give its POST a turn to land
    // before reading Home, the way `recents-recorder.spec.ts`'s own `settled()` does.
    await new Promise((resolve) => setTimeout(resolve, 500));

    await first.page.goto(`${config.origin}${HOME_URL}`, { waitUntil: 'networkidle2' });
    await first.page.waitForSelector('.ocu-home-block', { timeout: config.navigationTimeoutMs });
    const beforeFavorites = await blockLabels(first.page, STRINGS.favoritesHeading);
    const beforeRecents = await blockLabels(first.page, STRINGS.recentsHeading);
    assert.deepEqual(
      beforeFavorites,
      [STRINGS.userListLabel],
      `Favorites lists the pinned screen before sign-out: ${JSON.stringify(beforeFavorites)}`
    );
    assert.ok(
      beforeRecents.includes(STRINGS.alertLogListLabel),
      `Recent items lists the visited screen before sign-out: ${JSON.stringify(beforeRecents)}`
    );

    // Sign out for real: the CSP session the first context held is ended, so the second
    // context's own sign-in cannot be a silent probe over a cookie it does not even have.
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

    // A brand-new browser context: no cookie, no localStorage, no sessionStorage -- none of the
    // first context's storage of any kind. Signing in here is the Integration AC's "signs back
    // in in a new tab", strengthened to the manual check's "cleared site data" the spec's own
    // Verification records as not yet performed.
    second = await signedInAt(HOME_URL);
    await second.page.waitForSelector('.ocu-home-block', { timeout: config.navigationTimeoutMs });
    const afterFavorites = await blockLabels(second.page, STRINGS.favoritesHeading);
    const afterRecents = await blockLabels(second.page, STRINGS.recentsHeading);
    assert.deepEqual(afterFavorites, beforeFavorites, 'Favorites is unchanged after signing in fresh, in a tab with none of the first tab\'s storage');
    assert.deepEqual(afterRecents, beforeRecents, 'Recent items is unchanged after signing in fresh, in a tab with none of the first tab\'s storage');

    // And the surface the claim is actually about: this (second) tab's own storage, which never
    // held the token pair the first tab minted, holds neither favorited nor visited route either.
    const storage = await clientStorageEntries(second.page);
    const holdsEither = (entries) =>
      entries.some(([, value]) => value.includes('permissions/users') || value.includes('logs/alerts'));
    assert.equal(holdsEither(storage.local), false, `no favorite or recent route reached localStorage: ${JSON.stringify(storage.local)}`);
    assert.equal(holdsEither(storage.session), false, `no favorite or recent route reached sessionStorage: ${JSON.stringify(storage.session)}`);
  } finally {
    if (first !== null) await first.context.close();
    if (second !== null) await second.context.close();
  }
});

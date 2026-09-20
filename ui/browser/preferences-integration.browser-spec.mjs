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
 * `OCUPILOT_BROWSER_ORIGIN=<your slot's browser_origin> OCUPILOT_BROWSER_CONTAINER=<its container> \
 *   node --test --test-concurrency=1 browser/preferences-integration.browser-spec.mjs`
 *
 * Both values come from your own slot's `throwaway` block in `_bmad/custom/parallel.yaml`; the
 * spec itself reads them through `browserConfig()` and hardcodes no port, so it runs on any slot.
 * Setting only the origin execs into another slot's throwaway -- `browser.config.mjs` carries its
 * own container default.
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
    // `page.goto` is a fresh SPA bootstrap, and the first-login gate re-fires on every one of
    // those on a throwaway with no enabled definition -- so every `goto` to a non-gate route
    // needs its own `leaveFirstLoginGate`, the same as `signedInAt`'s own sign-in navigation.
    await first.page.goto(`${config.origin}${ALERTS_URL}`, { waitUntil: 'networkidle2' });
    await leaveFirstLoginGate(first.page, config.navigationTimeoutMs, ALERTS_URL);
    await first.page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
    // `registerVisit` is fire and forget (`recents-recorder.ts`): give its POST a turn to land
    // before reading Home, the way `recents-recorder.spec.ts`'s own `settled()` does.
    await new Promise((resolve) => setTimeout(resolve, 500));

    await first.page.goto(`${config.origin}${HOME_URL}`, { waitUntil: 'networkidle2' });
    await leaveFirstLoginGate(first.page, config.navigationTimeoutMs, HOME_URL);
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

    // DW-1331: a long remembered-screen label ellipsizes rather than widening the block or its
    // row. The property that actually gates this is `.ocu-home-block-open`'s `min-width: 0` in
    // `_components.scss` -- verified by removing it, rebuilding and redeploying: the button grows
    // to the label's full content width and the assertion below reddens. `.ocu-home-block-label`'s
    // own `min-width: 0` is not load-bearing for this element: its `overflow: hidden` already
    // gives it an automatic minimum size of 0 per the flexbox spec, so removing that declaration
    // alone (verified the same way) leaves this assertion green. jsdom computes no layout, so
    // only a browser can observe any of this, and no shipped screen's own label is long enough to
    // overflow on its own -- the label is stretched here the same way
    // `classic-link-card.browser-spec.mjs` pads its own probe label, rather than standing up a
    // second fixture harness for one assertion.
    const overflow = await first.page.evaluate(() => {
      const label = document.querySelector('.ocu-home-block-label');
      label.textContent = 'A remembered screen name long enough to overrun the block it sits in for sure'.padEnd(
        140,
        'x'
      );
      return {
        scrollWidth: label.scrollWidth,
        clientWidth: label.clientWidth,
        textOverflow: getComputedStyle(label).textOverflow,
      };
    });
    assert.equal(overflow.textOverflow, 'ellipsis', 'a remembered-screen label ends in an ellipsis');
    assert.ok(
      overflow.scrollWidth > overflow.clientWidth,
      `and there is more label than room, so the ellipsis is showing: ${JSON.stringify(overflow)}`
    );

    // The writing context's own storage, read before the sign-out clears anything. This is the
    // half that matters: the second context only ever *read* the lists, so a client that mirrored
    // them to browser storage **on write** would leave nothing there and the assertion at the end
    // of this test would pass anyway. `api.test.mjs` bans `localStorage` outside
    // `core/preferences.ts` by source scan, but it scores `sessionStorage` as no violation, so
    // that ban does not cover this on its own.
    const wroteStorage = await clientStorageEntries(first.page);
    const holdsRoute = (entries) =>
      entries.some(([, value]) => value.includes('permissions/users') || value.includes('logs/alerts'));
    assert.equal(
      holdsRoute(wroteStorage.local),
      false,
      `the tab that pinned and visited put no route in localStorage: ${JSON.stringify(wroteStorage.local)}`
    );
    assert.equal(
      holdsRoute(wroteStorage.session),
      false,
      `nor in sessionStorage: ${JSON.stringify(wroteStorage.session)}`
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
    assert.equal(holdsRoute(storage.local), false, `no favorite or recent route reached localStorage: ${JSON.stringify(storage.local)}`);
    assert.equal(holdsRoute(storage.session), false, `no favorite or recent route reached sessionStorage: ${JSON.stringify(storage.session)}`);

    // AC2, in a real browser rather than in jsdom: the per-row remove and the Clear control both
    // drive the instance and both announce afterwards. Their announcement path fires only once
    // the write settles, which `stubAccountPreferences` cannot exercise -- it never refuses and
    // never fails -- so this is the first time either is driven against a real one.
    const removeFirst = async (page, heading) =>
      page.evaluate((wantedHeading) => {
        const section = [...document.querySelectorAll('.ocu-home-block')].find(
          (candidate) => candidate.querySelector('.ocu-home-block-heading')?.textContent.trim() === wantedHeading
        );
        const control = section?.querySelector('.ocu-home-block-remove');
        if (!control) return false;
        control.id = 'ocu-probe-remove';
        return true;
      }, heading);

    assert.ok(await removeFirst(second.page, STRINGS.favoritesHeading), 'Favorites offers a per-row remove');
    await second.page.click('#ocu-probe-remove');
    await second.page.waitForFunction(
      (empty) => document.querySelector('.ocu-home-block-empty')?.textContent.trim() === empty,
      { timeout: config.navigationTimeoutMs },
      STRINGS.favoritesEmpty
    );
    assert.deepEqual(
      await blockLabels(second.page, STRINGS.favoritesHeading),
      [],
      'removing the only favorite empties the block against the real instance'
    );
    const removedSentence = await second.page.evaluate(
      () => document.querySelector('.ocu-home-status')?.textContent.trim() ?? ''
    );
    assert.equal(removedSentence, STRINGS.favoritesRemoved, 'and the polite region says so once the write landed');

    // Clear the other block the same way, then read both back over the wire: what the screen
    // shows and what the instance holds have to be the same answer.
    const cleared = await second.page.evaluate((heading) => {
      const section = [...document.querySelectorAll('.ocu-home-block')].find(
        (candidate) => candidate.querySelector('.ocu-home-block-heading')?.textContent.trim() === heading
      );
      const control = section?.querySelector('.ocu-home-block-clear');
      if (!control) return false;
      control.id = 'ocu-probe-clear';
      return true;
    }, STRINGS.recentsHeading);
    assert.ok(cleared, 'Recent items offers a Clear control');
    await second.page.click('#ocu-probe-clear');
    await second.page.waitForFunction(
      (sentence) => document.querySelector('.ocu-home-status')?.textContent.trim() === sentence,
      { timeout: config.navigationTimeoutMs },
      STRINGS.recentsCleared
    );
    assert.deepEqual(
      await blockLabels(second.page, STRINGS.recentsHeading),
      [],
      'and Clear empties Recent items'
    );

    const held = await (
      await fetch(`${config.origin}${PREFERENCES_PATH}`, { headers: { Authorization: authHeader() } })
    ).json();
    assert.deepEqual(held.favorites, [], 'the instance holds no favorite after the removal');
    assert.deepEqual(held.recents, [], 'and no recent item after the clear');
  } finally {
    if (first !== null) await first.context.close();
    if (second !== null) await second.context.close();
  }
});

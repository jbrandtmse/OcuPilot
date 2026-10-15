/**
 * The Integration AC (Rule 1) of Story 15.2, end to end in a real browser (DW-1329, QA):
 * favorites and recents held before a sign-out render unchanged after signing back in in a new
 * tab, because the state was read from the instance and no browser storage holds it.
 *
 * preferences-reset-exempt: it is about remembered state surviving, so it arranges and clears its own rows.
 *
 * **Why this file, and why it was missing.** Every link in the chain has its own pinning test --
 * `OcuPilot.Test.PreferencesWire` proves the instance keeps the rows, `ui/tools/api.test.mjs`
 * bans `localStorage` everywhere under `ui/src`, and the component specs prove the locator
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
 * **Two writes the client must not send (Story 23.5), watched on the wire.** A signed-out tab that
 * goes Back to a listed screen sends no preference write (DW-1341), and two activations of the
 * favorite star inside one round trip send one (DW-1342). A request list is the only place either
 * can be read from the page's side: a component spec's transport is a stub that counts what it
 * was handed.
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
import { openFromSideBar } from './panel-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';

const config = browserConfig();
const STRINGS = loadStrings();

const HOME_URL = '/ocupilot/?ns=HSCUSTOM';
/** Favorited through the locator bar's own toggle -- the real client write path. */
const USERS_URL = '/ocupilot/permissions/users?ns=HSCUSTOM';
/** Visited, never favorited: registers as a recent with no explicit action (AC3). */
const ALERTS_URL = '/ocupilot/logs/alerts?ns=HSCUSTOM';
const PREFERENCES_PATH = '/api/ocupilot/account/preferences';
const LOGIN_PATH = '/api/ocupilot/login';

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

/**
 * A fresh context signed in through the shell's own form, landed at `url` -- one browser tab's worth of storage.
 *
 * `prepare` runs against the page before it navigates, which is where a test installs its request
 * interception.
 */
async function signedInAt(url, prepare = null) {
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  if (prepare !== null) await prepare(page);
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
    // `page.goto` is a fresh SPA bootstrap, which is a sign-in the first-login gate acts on while
    // this account's first-sign-in record is absent -- so every `goto` to a non-gate route passes
    // through `leaveFirstLoginGate`, which tolerates either, as `signedInAt`'s own sign-in does.
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
    // of this test would pass anyway. `api.test.mjs` bans `localStorage` everywhere under
    // `ui/src` by source scan, but it scores `sessionStorage` as no violation, so that ban does
    // not cover this on its own.
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

/**
 * Record every write this page sends to the preferences route into `writes`, as the body it carried.
 * With a `gate` promise, a favorite write is held until the gate settles, which keeps one round
 * trip open for as long as the test wants it open. With a `probe` object, the silent sign-in
 * (`POST /api/ocupilot/login` with no body) is held while `probe.hold` is true, until
 * `probe.release` settles, and `probe.held` counts the requests held. Every other request goes on
 * untouched.
 */
function watchPreferenceWrites(writes, gate = null, probe = null) {
  return async (page) => {
    await page.setRequestInterception(true);
    page.on('request', (request) => {
      if (
        probe !== null &&
        probe.hold &&
        request.method() === 'POST' &&
        request.url().endsWith(LOGIN_PATH) &&
        !request.postData()
      ) {
        probe.held += 1;
        void probe.release.then(() => request.continue()).catch(() => {});
        return;
      }
      if (request.method() !== 'POST' || !request.url().includes(PREFERENCES_PATH)) {
        void request.continue();
        return;
      }
      const body = JSON.parse(request.postData() ?? '{}');
      writes.push(body);
      if (gate !== null && body.kind === 'favorite') {
        void gate.then(() => request.continue());
        return;
      }
      void request.continue();
    });
  };
}

/** Poll in the test process until `condition` holds, or fail naming `what`. */
async function until(condition, what) {
  const deadline = Date.now() + config.navigationTimeoutMs;
  while (!condition()) {
    assert.ok(Date.now() < deadline, `timed out waiting for ${what}`);
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
}

// Mutation (Rule 19): drop the `favoritePendingRoute() === route` guard from `toggleFavorite` in
// `locator-bar.ts`, rebuild and redeploy -> two favorite writes leave the page and the first
// assertion below reads 2.
test('DW-1342: two activations of the favorite star inside one round trip send one write, and the star is aria-disabled until it settles', async () => {
  let session = null;
  let release = () => {};
  try {
    await clearPreferences();
    const writes = [];
    const gate = new Promise((resolve) => {
      release = resolve;
    });
    session = await signedInAt(USERS_URL, watchPreferenceWrites(writes, gate));
    const { page } = session;
    await page.waitForSelector('.ocu-locator-favorite', { timeout: config.navigationTimeoutMs });
    // The preferences read is the screen's answered signal: acting before it lands would toggle
    // against a store that has not yet said which side the star is on.
    await page.waitForNetworkIdle({ idleTime: 400, timeout: config.navigationTimeoutMs });
    await page.waitForFunction(
      () => document.querySelector('.ocu-locator-favorite')?.getAttribute('aria-pressed') === 'false',
      { timeout: config.navigationTimeoutMs }
    );

    // Two activations in one task: the second lands while the first write is still open.
    await page.evaluate(() => {
      const star = document.querySelector('.ocu-locator-favorite');
      star.click();
      star.click();
    });
    await until(() => writes.some((write) => write.kind === 'favorite'), 'the favorite write to leave the page');
    await page.waitForFunction(
      () => document.querySelector('.ocu-locator-favorite')?.getAttribute('aria-disabled') === 'true',
      { timeout: config.navigationTimeoutMs }
    );
    const held = await page.evaluate(() => {
      const star = document.querySelector('.ocu-locator-favorite');
      return { disabled: star.disabled, pressed: star.getAttribute('aria-pressed') };
    });
    assert.deepEqual(held, { disabled: false, pressed: 'false' }, 'the star is aria-disabled and not disabled, and the instance has not answered yet');
    assert.equal(writes.filter((write) => write.kind === 'favorite').length, 1, `one favorite write while the first is open: ${JSON.stringify(writes)}`);

    // The instance answers: the star settles on the pressed side and takes its attribute off.
    release();
    await page.waitForFunction(
      () => {
        const star = document.querySelector('.ocu-locator-favorite');
        return star?.getAttribute('aria-pressed') === 'true' && !star.hasAttribute('aria-disabled');
      },
      { timeout: config.navigationTimeoutMs }
    );
    assert.equal(writes.filter((write) => write.kind === 'favorite').length, 1, 'and still one once it has settled');
    const heldRows = await (
      await fetch(`${config.origin}${PREFERENCES_PATH}`, { headers: { Authorization: authHeader() } })
    ).json();
    assert.equal(heldRows.favorites.length, 1, `the instance holds the one favorite: ${JSON.stringify(heldRows.favorites)}`);
  } finally {
    release();
    if (session !== null) await session.context.close();
    await clearPreferences();
  }
});

// Mutation (Rule 19): drop the `if (!waiting && !isSignedIn(state)) return;` guard from
// `RecentsRecorder.record` in `recents-recorder.ts`, rebuild and redeploy -> the Back lands on a
// listed screen and a recent write leaves the signed-out tab.
test('DW-1341: a signed-out tab that goes Back to a listed screen sends no preference write', async () => {
  let session = null;
  try {
    await clearPreferences();
    const writes = [];
    session = await signedInAt(USERS_URL, watchPreferenceWrites(writes));
    const { page } = session;

    // Signed in, opening a second listed screen registers a recent: the observer sees a write.
    await openFromSideBar(page, config, '#ocu-rail-item-logs', STRINGS.alertLogListLabel);
    await page.waitForFunction(() => window.location.pathname.endsWith('/logs/alerts'), { timeout: config.navigationTimeoutMs });
    await until(() => writes.some((write) => write.kind === 'recent'), 'the signed-in visit to register a recent');

    await page.click('#ocu-account-trigger');
    await page.waitForSelector('[role="menuitem"]', { visible: true, timeout: config.navigationTimeoutMs });
    await page.evaluate((label) => {
      const item = [...document.querySelectorAll('[role="menuitem"]')].find((candidate) => candidate.textContent.trim() === label);
      item.id = 'ocu-probe-sign-out';
    }, STRINGS.actionSignOut);
    await page.click('#ocu-probe-sign-out');
    await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });

    // From here on the tab holds no principal. Back is a navigation like any other.
    const signedOutAt = writes.length;
    await page.goBack();
    await page.waitForFunction(() => window.location.pathname.endsWith('/permissions/users'), { timeout: config.navigationTimeoutMs });
    await page.waitForNetworkIdle({ idleTime: 750, timeout: config.navigationTimeoutMs });
    assert.equal(
      await page.evaluate(() => document.querySelector('#ocu-signin-user') !== null),
      true,
      'the tab is still on the sign-in card after Back'
    );
    assert.deepEqual(writes.slice(signedOutAt), [], 'and no preference write left it');
  } finally {
    if (session !== null) await session.context.close();
    await clearPreferences();
  }
});

// Mutation (Rule 19), each with the bundle rebuilt and redeployed: make `RecentsRecorder.record`
// return for a waiting arrival instead of holding it (delete `this.pendingRoute = screen.route;`) ->
// no `recent` write for the screen leaves the page once the sign-in answers; make it register a
// waiting arrival at once (`this.register(screen.route);` in that place) -> a write leaves the page
// while the sign-in is still held.
test('DW-1329: a listed screen reached while the silent sign-in is still in flight is registered as a recent once the session signs in', async () => {
  let session = null;
  let release = () => {};
  try {
    await clearPreferences();
    const writes = [];
    const probe = { hold: false, held: 0, release: null };
    probe.release = new Promise((resolve) => {
      release = resolve;
    });
    session = await signedInAt(USERS_URL, watchPreferenceWrites(writes, null, probe));
    const { page } = session;
    await page.waitForNetworkIdle({ idleTime: 400, timeout: config.navigationTimeoutMs });

    // A fresh document is not a resumed tab, so this arrival starts a silent sign-in of its own.
    // The held sign-in is the one request left open once every chunk the router's first navigation
    // needs has landed, so that navigation has ended while the session is still waiting.
    writes.length = 0;
    probe.hold = true;
    await page.goto(`${config.origin}${ALERTS_URL}`, { waitUntil: 'domcontentloaded' });
    await until(() => probe.held > 0, 'the silent sign-in to leave the page');
    const quiet = await page
      .waitForNetworkIdle({ idleTime: 1000, concurrency: 1, timeout: config.navigationTimeoutMs })
      .then(
        () => true,
        () => false
      );
    assert.deepEqual(writes, [], 'nothing is written for a principal the instance has not yet answered for');
    assert.ok(quiet, 'the page settles with the held sign-in as its one open request');

    release();
    await until(
      () => writes.some((write) => write.kind === 'recent' && write.route === 'logs/alerts'),
      'the held visit to register once the session signs in'
    );
  } finally {
    release();
    if (session !== null) await session.context.close();
    await clearPreferences();
  }
});

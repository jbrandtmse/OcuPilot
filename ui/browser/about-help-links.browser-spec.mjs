/**
 * About, per-screen help, the links panel and DW-3's stale-bundle prompt, in a real browser
 * against the throwaway instance (Story 15.3).
 *
 * **What only this tier can settle.** Four things:
 *
 * - **The Integration AC (Rule 1).** The stale-bundle comparison has one artifact on both sides --
 *   the hashed `main-*.js` the installer recorded and the one the running document loaded -- and
 *   jsdom loads no bundle at all, so the only place the two can be read from the same page is
 *   here. The match case is the shipped state, and the mismatch is driven by serving the page a
 *   `buildIdentity` its own bundle does not carry.
 * - **AC5, that these surfaces cause no off-origin request.** A component spec's `fetch` is a stub;
 *   only a real browser can be watched for what it actually asked for. **The request list alone is
 *   not enough**, and measuring it is what showed why: an anchor replaced by a `fetch` of the same
 *   URL never reaches the network at all, because the bundle's own `connect-src 'self'` refuses it
 *   in the renderer first (AD-47) -- so the request list stays empty and the claim reads as held
 *   when the surface did try to leave. The console is watched beside it, where that refusal is the
 *   only thing that shows.
 * - **The Help control's real href**, resolved by the instance from the descriptor's own
 *   `classicPage`, rather than from a stub that was told the answer.
 * - **The links panel's three destinations as the instance answers them**, including the
 *   documentation address the degraded (no local DocBook) branch produces on this image.
 *
 * Reads only. It signs in, opens a dialog and reads attributes; it writes nothing to the instance
 * and needs no teardown, so it is safe to run in any order beside the others. It still refuses the
 * live container, the way every spec here does.
 *
 * Run: `npm run build`, then bring the throwaway up so the installer records the bundle it
 * deployed (`scripts/ci-throwaway.sh up ...` copies `ui/dist`), then
 * `OCUPILOT_BROWSER_ORIGIN=<your slot's browser_origin> OCUPILOT_BROWSER_CONTAINER=<its container> \
 *   node --test --test-concurrency=1 browser/about-help-links.browser-spec.mjs`
 *
 * Both values come from your own slot's `throwaway` block in `_bmad/custom/parallel.yaml`; the
 * spec reads them through `browserConfig()` and hardcodes no port.
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
/** A screen whose classic page publishes a HELPADDRESS, so it offers a Help control. */
const USERS_URL = '/ocupilot/permissions/users?ns=HSCUSTOM';
/** A screen whose classic page is a CSP page publishing none, so it offers no control. */
const ALERTS_URL = '/ocupilot/logs/alerts?ns=HSCUSTOM';
const ABOUT_PATH = '/api/ocupilot/ui/about';
const INSTANCE_PATH = '/api/ocupilot/instance';

let browser = null;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec drives a browser session, so it never runs against the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser === null) return;
  await browser.close();
  browser = null;
});

function authHeader() {
  return 'Basic ' + Buffer.from(`${config.username}:${config.password}`).toString('base64');
}

/** What the instance answers for one of the two reads, over the wire and outside the browser. */
async function read(path) {
  const answer = await fetch(`${config.origin}${path}`, { headers: { Authorization: authHeader() } });
  assert.equal(answer.status, 200, `${path} answers 200`);
  return answer.json();
}

/**
 * A fresh context signed in through the shell's own form, landed at `url`.
 *
 * `prepare` runs against the page before it navigates, which is where a test that needs the
 * instance identity rewritten installs its interception.
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

/**
 * Serve every `/instance` answer with `buildIdentity` replaced by `identity`.
 *
 * Interception rather than a write to the version row: the row is the instance's record of what
 * it installed, and a spec that rewrote it would be changing shared state to observe a client
 * comparison. What the client compares is the body it is served, and this serves it.
 */
function rewriteBuildIdentity(identity) {
  return async (page) => {
    await page.setRequestInterception(true);
    page.on('request', (request) => {
      if (!request.url().includes(INSTANCE_PATH)) {
        void request.continue();
        return;
      }
      void (async () => {
        const response = await fetch(`${config.origin}${INSTANCE_PATH}`, {
          headers: { Authorization: request.headers().authorization ?? authHeader() },
        });
        const body = await response.json();
        body.buildIdentity = identity;
        await request.respond({
          status: response.status,
          contentType: 'application/json',
          body: JSON.stringify(body),
        });
      })();
    });
  };
}

/** The hashed `main-*.js` filename the loaded document names in its own script tags. */
async function documentBundle(page) {
  return page.evaluate(() => {
    for (const script of document.querySelectorAll('script[src]')) {
      const path = script.getAttribute('src').split('?')[0];
      const leaf = path.slice(path.lastIndexOf('/') + 1);
      if (/^main-[A-Za-z0-9]+\.js$/.test(leaf)) return leaf;
    }
    return '';
  });
}

test('AC1: About opens from the account menu and shows the values the instance reports', async () => {
  let session = null;
  try {
    session = await signedInAt(HOME_URL);
    const { page } = session;
    const answered = await read(ABOUT_PATH);

    await page.click('#ocu-account-trigger');
    await page.waitForSelector('[role="menuitem"]', { visible: true, timeout: config.navigationTimeoutMs });
    const opened = await page.evaluate((label) => {
      const item = [...document.querySelectorAll('[role="menuitem"]')].find(
        (candidate) => candidate.textContent.trim() === label
      );
      if (item === undefined) return false;
      item.id = 'ocu-probe-about';
      return true;
    }, STRINGS.aboutTitle);
    assert.ok(opened, 'the account menu lists About');
    await page.click('#ocu-probe-about');
    await page.waitForSelector('.ocu-about-list', { timeout: config.navigationTimeoutMs });

    const rows = await page.evaluate(() => {
      const terms = [...document.querySelectorAll('.ocu-about-term')].map((el) => el.textContent.trim());
      const values = [...document.querySelectorAll('.ocu-about-value')].map((el) => el.textContent.trim());
      return terms.map((term, index) => [term, values[index]]);
    });
    assert.equal(rows.length, 13, `thirteen labelled members: ${JSON.stringify(rows)}`);

    const byLabel = Object.fromEntries(rows);
    assert.equal(byLabel[STRINGS.aboutVersion], answered.version, 'the Version row is the instance\u2019s own banner');
    assert.equal(byLabel[STRINGS.aboutJournalFile], answered.journalFile, 'and the journal file is the one it reports');
    assert.equal(byLabel[STRINGS.aboutBuild], answered.buildIdentity, 'and Build is the version row\u2019s stamp');
    assert.equal(byLabel[STRINGS.statusSegmentLicensedTo], answered.licensedTo);

    // Escape closes it and focus returns to the trigger it was opened from.
    await page.keyboard.press('Escape');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, {
      timeout: config.navigationTimeoutMs,
    });
    const focused = await page.evaluate(() => document.activeElement?.id ?? '');
    assert.equal(focused, 'ocu-account-trigger', 'focus returns to the account-menu trigger');
  } finally {
    if (session !== null) await session.context.close();
  }
});

test('AC2: the Help control opens the classic page\u2019s own documentation address, and a screen with none has no control', async () => {
  let session = null;
  try {
    session = await signedInAt(USERS_URL);
    const { page } = session;
    await page.waitForSelector('.ocu-locator-help', { timeout: config.navigationTimeoutMs });

    const link = await page.evaluate(() => {
      const anchor = document.querySelector('.ocu-locator-help');
      return {
        href: anchor.getAttribute('href'),
        target: anchor.getAttribute('target'),
        rel: anchor.getAttribute('rel'),
        name: anchor.getAttribute('aria-label'),
        text: anchor.textContent.trim(),
      };
    });
    // The address the instance resolves from the descriptor's own classicPage.
    const resolved = await read('/api/ocupilot/ui/help?route=permissions%2Fusers');
    assert.equal(resolved.available, true, `the instance resolves an address: ${JSON.stringify(resolved)}`);
    assert.equal(link.href, resolved.href, 'and the control opens exactly it');
    assert.ok(link.href.includes('KEY='), `carried as the DocBook KEY: ${link.href}`);
    assert.equal(link.target, '_blank');
    assert.equal(link.rel, 'noreferrer');
    assert.equal(link.name, STRINGS.helpForScreen);
    assert.ok(link.text.includes(STRINGS.helpLabel), `its visible word is Help: ${link.text}`);

    // A screen whose classic page publishes no HELPADDRESS gets no control at all.
    await page.goto(`${config.origin}${ALERTS_URL}`, { waitUntil: 'networkidle2' });
    await leaveFirstLoginGate(page, config.navigationTimeoutMs, ALERTS_URL);
    await page.waitForSelector('app-locator-bar .ocu-locator-bar', { timeout: config.navigationTimeoutMs });
    await new Promise((resolve) => setTimeout(resolve, 500));
    const absent = await page.evaluate(() => document.querySelector('.ocu-locator-help') === null);
    assert.equal(absent, true, 'the alerts.log viewer offers no Help control');
  } finally {
    if (session !== null) await session.context.close();
  }
});

test('AC3 and AC5: Home\u2019s Links block names the three destinations, and nothing on these surfaces leaves the origin', async () => {
  let session = null;
  try {
    const offOrigin = [];
    const refused = [];
    session = await signedInAt(HOME_URL, async (page) => {
      page.on('request', (request) => {
        if (!request.url().startsWith(config.origin)) offOrigin.push(`${request.method()} ${request.url()}`);
      });
      // The other half of AC5: a surface that TRIED to leave the origin and was stopped by the
      // bundle's own policy. That attempt is a console error and nothing else, so without this the
      // request list would read empty and the claim would read as held.
      page.on('console', (message) => {
        if (message.type() !== 'error') return;
        if (/Content Security Policy/i.test(message.text())) refused.push(message.text().trim());
      });
    });
    const { page } = session;
    await page.waitForSelector('.ocu-home-block-fixed', { timeout: config.navigationTimeoutMs });

    const answered = await read(ABOUT_PATH);
    const links = await page.evaluate(() => {
      const blocks = [...document.querySelectorAll('.ocu-home-block-fixed')];
      const panel = blocks[blocks.length - 1];
      return [...panel.querySelectorAll('.ocu-home-block-link')].map((anchor) => ({
        label: anchor.querySelector('.ocu-home-block-label').textContent.trim(),
        href: anchor.getAttribute('href'),
        target: anchor.getAttribute('target'),
        rel: anchor.getAttribute('rel'),
      }));
    });
    assert.deepEqual(
      links.map((link) => link.label),
      [STRINGS.linksDocumentation, STRINGS.linksSupport, STRINGS.linksInterSystems]
    );
    assert.deepEqual(
      links.map((link) => link.href),
      [answered.links.documentation, answered.links.support, answered.links.intersystems],
      'each anchor opens the address the instance answered'
    );
    // The panel's Documentation entry is the documentation's front door, which is a different
    // DocBook page from the per-screen help one: that page renders the help for one KEY and shows
    // nothing without one, so naming it here would ship a link that opens an error.
    assert.ok(
      answered.links.documentation.endsWith('/csp/docbook/DocBook.UI.Page.cls'),
      `Documentation opens the documentation home: ${answered.links.documentation}`
    );
    const help = await read('/api/ocupilot/ui/help?route=permissions%2Fusers');
    assert.ok(
      help.href.includes('DocBook.UI.PortalHelpPage.cls') && !links[0].href.includes('PortalHelpPage'),
      'and per-screen help opens the help page, which the panel does not'
    );
    for (const link of links) {
      assert.equal(link.target, '_blank', `${link.label} opens in a new tab`);
      assert.equal(link.rel, 'noreferrer', `${link.label} carries the house rel`);
    }

    // The Shortcuts block beside it, rendering the roster's built screens and nothing else.
    const shortcuts = await page.evaluate(() => {
      const panel = document.querySelectorAll('.ocu-home-block-fixed')[0];
      return [...panel.querySelectorAll('.ocu-home-block-label')].map((el) => el.textContent.trim());
    });
    assert.ok(shortcuts.length > 0, `Shortcuts lists the roster's built screens: ${JSON.stringify(shortcuts)}`);
    assert.ok(shortcuts.includes(STRINGS.userListLabel), 'including the Users list');

    // Open About too, so the dialog's own render is inside the window being watched.
    await page.click('#ocu-account-trigger');
    await page.waitForSelector('[role="menuitem"]', { visible: true, timeout: config.navigationTimeoutMs });
    await page.evaluate((label) => {
      const item = [...document.querySelectorAll('[role="menuitem"]')].find(
        (candidate) => candidate.textContent.trim() === label
      );
      item.id = 'ocu-probe-about';
    }, STRINGS.aboutTitle);
    await page.click('#ocu-probe-about');
    await page.waitForSelector('.ocu-about-list', { timeout: config.navigationTimeoutMs });

    // AC5: the only off-origin traffic any of these can cause is a navigation the user clicks,
    // and nobody clicked one -- nothing was sent, and nothing was refused for trying.
    assert.deepEqual(offOrigin, [], `no request left the instance's origin: ${JSON.stringify(offOrigin)}`);
    assert.deepEqual(refused, [], `and none of these surfaces was refused for trying: ${JSON.stringify(refused)}`);
  } finally {
    if (session !== null) await session.context.close();
  }
});

test('Integration AC (DW-3): the shipped bundle matches the stamp the installer recorded, so no prompt stands', async () => {
  let session = null;
  try {
    session = await signedInAt(HOME_URL);
    const { page } = session;
    const identity = await read('/api/ocupilot/instance');
    const loaded = await documentBundle(page);

    // The server half, observed rather than assumed: the version row carries the name of the
    // bundle the install actually deployed, which is the one this document loaded.
    assert.match(identity.buildIdentity, /^main-[A-Za-z0-9]+\.js$/, `a bundle-derived stamp, not a literal: ${identity.buildIdentity}`);
    assert.equal(loaded, identity.buildIdentity, 'and it is the bundle this page is running');

    const prompt = await page.evaluate(() => document.querySelector('.ocu-stale-bundle') === null);
    assert.equal(prompt, true, 'so no reload prompt stands');
  } finally {
    if (session !== null) await session.context.close();
  }
});

test('Integration AC (DW-3): a buildIdentity the bundle does not carry raises the polite prompt, which never reloads by itself', async () => {
  let session = null;
  try {
    session = await signedInAt(HOME_URL, rewriteBuildIdentity('main-NOTTHISONE.js'));
    const { page } = session;
    await page.waitForSelector('.ocu-stale-bundle', { timeout: config.navigationTimeoutMs });

    const notice = await page.evaluate(() => {
      const region = document.querySelector('.ocu-stale-bundle');
      return {
        role: region.getAttribute('role'),
        text: region.querySelector('.ocu-stale-bundle-text').textContent.trim(),
        action: region.querySelector('button').textContent.trim(),
      };
    });
    assert.equal(notice.role, 'status', 'polite, never an alert');
    assert.equal(notice.text, STRINGS.staleBundleNotice);
    assert.equal(notice.action, STRINGS.actionReload);

    // It never reloads by itself: the document that was loaded is still the one on screen a
    // moment later, and the shell underneath it is untouched.
    const before = await page.evaluate(() => performance.getEntriesByType('navigation').length);
    await new Promise((resolve) => setTimeout(resolve, 1500));
    const after = await page.evaluate(() => performance.getEntriesByType('navigation').length);
    assert.equal(after, before, 'no navigation happened on its own');
    const frame = await page.evaluate(() => document.querySelector('app-rail .ocu-rail') !== null);
    assert.equal(frame, true, 'and the shell is still usable underneath it');

    // ...but the one control it offers does. Nothing else in any tier activates it, and an inert
    // control is what this epic's contract forbids outright; `location.reload()` is observable
    // only in a real browser.
    //
    // A marker on the document under test, not a navigation counter: `performance`'s entries
    // belong to the document, so a reload resets them to one and a count comparison cannot tell a
    // reload from a dead handler. A marker the new document does not carry can.
    await page.evaluate(() => {
      window.__ocuBeforeReload = true;
    });
    await Promise.all([
      page.waitForNavigation({ waitUntil: 'networkidle2', timeout: config.navigationTimeoutMs }),
      page.click('.ocu-stale-bundle button'),
    ]);
    await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
    const survived = await page.evaluate(() => window.__ocuBeforeReload === true);
    assert.equal(survived, false, 'Reload fetched the document again, so the marker is gone');
  } finally {
    if (session !== null) await session.context.close();
  }
});

test('Integration AC (DW-3): an instance that reports no build identity raises no prompt -- absence is not a mismatch', async () => {
  let session = null;
  try {
    session = await signedInAt(HOME_URL, rewriteBuildIdentity(''));
    const { page } = session;
    await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
    await new Promise((resolve) => setTimeout(resolve, 1000));
    const absent = await page.evaluate(() => document.querySelector('.ocu-stale-bundle') === null);
    assert.equal(absent, true, 'an empty identity is nothing to compare, so no prompt');
  } finally {
    if (session !== null) await session.context.close();
  }
});

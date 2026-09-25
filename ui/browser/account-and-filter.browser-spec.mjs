/**
 * Story 15.9 in a real browser, against the throwaway instance: sign-out where people look, and no
 * filter where there is nothing to filter.
 *
 * What only this tier can settle: the header's account button opening its menu downward with Sign
 * out under its own centre point, the button staying inside the header and clear of the command box
 * at 720 px, the command box's Sign out row reaching the same `Session.signOut()` -- which posts
 * `/logout` with the Bearer and the cookie (AD-28) and leaves a reload on the sign-in form rather
 * than silently signed back in -- and which screens draw the command bar's filter at all.
 * `header.spec.ts`, `status-bar.spec.ts`, `command-box.spec.ts` and `command-bar.spec.ts` pin the
 * DOM shape in jsdom.
 *
 * Each sign-out runs in its own context. It writes nothing to the instance beyond the reset every
 * context makes, and it refuses the live container.
 *
 * Run: `npm run build`, `docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/account-and-filter.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { FILTER_SELECTOR, filterToSubset, viewCount, waitForRows } from './list-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';

const config = browserConfig();
const STRINGS = loadStrings();

const HOME_URL = '/ocupilot/?ns=HSCUSTOM';
const USERS_URL = '/ocupilot/permissions/users?ns=HSCUSTOM';
const ERRORS_URL = '/ocupilot/logs/errors?ns=HSCUSTOM';
const USER_EDITOR_URL = '/ocupilot/permissions/users/edit/_SYSTEM?ns=HSCUSTOM';
const LOGOUT_PATH = '/api/ocupilot/logout';
const SIGN_OUT_ROW = '#ocu-command-box-account-sign-out';

let browser = null;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec signs a browser session out, so it never runs against the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser === null) return;
  await browser.close();
  browser = null;
});

/** Open `url` in an already signed-in page, returning to it if the first-login gate moves off it. */
async function openAt(page, url) {
  await page.goto(`${config.origin}${url}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, url);
}

/** A fresh context signed in through the shell's own form, landed at `url`. */
async function signedInAt(url, viewport = config.viewport) {
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  await page.setViewport(viewport);
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
 * Record the full request headers of every `/logout` the page sends, cookie included. Puppeteer's
 * own request headers leave the cookie out, so this reads the network layer's extra info.
 */
async function watchLogout(page) {
  const client = await page.createCDPSession();
  await client.send('Network.enable');
  const ids = new Set();
  const seen = [];
  client.on('Network.requestWillBeSent', (event) => {
    if (new URL(event.request.url).pathname === LOGOUT_PATH && event.request.method === 'POST') ids.add(event.requestId);
  });
  client.on('Network.requestWillBeSentExtraInfo', (event) => {
    const headers = Object.fromEntries(Object.entries(event.headers).map(([key, value]) => [key.toLowerCase(), value]));
    seen.push({ id: event.requestId, headers });
  });
  return () => seen.filter((entry) => ids.has(entry.id)).map((entry) => entry.headers);
}

/** After a sign-out: the form shows, the logout carried both credentials, and a reload stays signed out. */
async function assertSignedOutOfTheInstance(page, logouts) {
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.waitForFunction((path) => performance.getEntriesByType('resource').some((entry) => entry.name.includes(path)), {
    timeout: config.navigationTimeoutMs,
  }, LOGOUT_PATH);
  await new Promise((resolve) => setTimeout(resolve, 300));
  const sent = logouts();
  assert.equal(sent.length, 1, `one /logout was posted: ${JSON.stringify(sent.length)}`);
  assert.match(sent[0].authorization ?? '', /^Bearer \S+/, 'it carries the Bearer (AD-28)');
  assert.ok((sent[0].cookie ?? '') !== '', 'and the cookie, so the browser-level login ends (AD-28)');

  // Not silently signed back in: a reload's silent-first probe finds no login to mint from.
  await page.reload({ waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await new Promise((resolve) => setTimeout(resolve, 500));
  assert.equal(await page.$('app-rail .ocu-rail'), null, 'the reload shows the sign-in form, not the shell');
}

// Mutation (Rule 19): mount `<app-account-menu />` back in the status bar -> the no-button assertion
// goes red. Integration AC: make `Session.signOut()` skip its `/logout` post -> the /logout
// assertion goes red. `overflow: hidden` on `.ocu-header` -> the hit test goes red.
test('Header menu and status bar: the header\'s account button opens About, Change password, Dark theme and Sign out downward, Sign out is under its own centre and signs out of the instance; the status bar shows the user with no button', async () => {
  const { context, page } = await signedInAt(HOME_URL);
  try {
    const band = await page.$eval('app-status-bar', (bar) => ({
      text: bar.textContent ?? '',
      buttons: bar.querySelectorAll('button').length,
    }));
    assert.ok(band.text.includes(config.username), `the status bar shows the user name: ${band.text}`);
    assert.equal(band.buttons, 0, 'the status bar holds no button');

    const trigger = await page.$('app-header .ocu-header-end #ocu-account-trigger');
    assert.notEqual(trigger, null, 'the account button is at the header\'s right end');
    await page.click('app-header #ocu-account-trigger');
    await page.waitForSelector('.ocu-account-panel [role="menuitem"]', { visible: true, timeout: config.navigationTimeoutMs });
    const menu = await page.evaluate(() => {
      const button = document.querySelector('#ocu-account-trigger').getBoundingClientRect();
      const panel = document.querySelector('.ocu-account-panel').getBoundingClientRect();
      const items = [...document.querySelectorAll('.ocu-account-panel [role^="menuitem"]')];
      const last = items[items.length - 1];
      const box = last.getBoundingClientRect();
      last.id = 'ocu-probe-sign-out';
      return {
        labels: items.map((item) => item.firstChild.textContent.trim()),
        opensDown: panel.top >= button.bottom - 0.5,
        inWindow: panel.bottom <= document.documentElement.clientHeight && panel.right <= document.documentElement.clientWidth,
        hit: last.contains(document.elementFromPoint(box.left + box.width / 2, box.top + box.height / 2)),
      };
    });
    assert.deepEqual(menu.labels, [STRINGS.aboutTitle, STRINGS.accountChangePassword, STRINGS.accountDarkTheme, STRINGS.actionSignOut]);
    assert.ok(menu.opensDown, 'the menu opens downward from the header');
    assert.ok(menu.inWindow, 'and stays inside the window');
    assert.equal(menu.hit, true, 'Sign out is the element under its own centre point');

    const logouts = await watchLogout(page);
    await page.click('#ocu-probe-sign-out');
    await assertSignedOutOfTheInstance(page, logouts);
  } finally {
    await context.close();
  }
});

test('Narrow header: at 720 px the account button lies inside the header and clear of the command box, and a long name ellipsizes with its text whole', async () => {
  const { context, page } = await signedInAt(HOME_URL, { width: 720, height: 800 });
  try {
    const long = 'A user name far too long for the header at this width to show whole';
    const measured = await page.evaluate((name) => {
      const label = document.querySelector('#ocu-account-trigger .ocu-account-name');
      label.firstChild.data = name;
      const rect = (element) => element.getBoundingClientRect();
      const header = rect(document.querySelector('app-header .ocu-header'));
      const button = rect(document.querySelector('#ocu-account-trigger'));
      const box = rect(document.querySelector('app-command-box .ocu-command-box'));
      return {
        inside: button.left >= header.left - 0.5 && button.right <= header.right + 0.5 && button.top >= header.top - 0.5 && button.bottom <= header.bottom + 0.5,
        clear: button.left >= box.right - 0.5 || button.right <= box.left + 0.5,
        cut: label.scrollWidth > label.clientWidth,
        ellipsis: getComputedStyle(label).textOverflow,
        text: document.querySelector('#ocu-account-trigger').textContent,
        page: document.documentElement.scrollWidth <= document.documentElement.clientWidth,
      };
    }, long);
    assert.ok(measured.inside, `the account button is inside the header: ${JSON.stringify(measured)}`);
    assert.ok(measured.clear, `and does not intersect the command box: ${JSON.stringify(measured)}`);
    assert.ok(measured.cut && measured.ellipsis === 'ellipsis', `a long name ellipsizes: ${JSON.stringify(measured)}`);
    assert.ok(measured.text.includes(long), 'the button\'s text content stays whole');
    assert.ok(measured.page, 'the page does not scroll sideways');
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): drop the Sign out row -> the wait for it goes red. Integration AC: replace the
// row's `Session.signOut()` with a local token clear -> the /logout and reload assertions go red.
test('Command Sign out: typing "sign out" offers an active Sign out row, and Enter signs out of the instance; an empty query offers none', async () => {
  const { context, page } = await signedInAt(HOME_URL);
  try {
    await page.click('#ocu-command-box-field');
    await page.waitForSelector('#ocu-command-box-list', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$(SIGN_OUT_ROW), null, 'an empty query lists no Sign out row');

    await page.type('#ocu-command-box-field', 'sign out');
    await page.waitForSelector(SIGN_OUT_ROW, { visible: true, timeout: config.navigationTimeoutMs });
    const row = await page.evaluate((selector) => {
      const option = document.querySelector(selector);
      return {
        label: option.textContent.trim(),
        group: option.closest('[role="group"]').getAttribute('aria-label'),
        active: document.querySelector('#ocu-command-box-field').getAttribute('aria-activedescendant') === option.id,
      };
    }, SIGN_OUT_ROW);
    assert.deepEqual(row, { label: STRINGS.actionSignOut, group: STRINGS.commandBoxGroupActions, active: true });

    const logouts = await watchLogout(page);
    await page.keyboard.press('Enter');
    await assertSignedOutOfTheInstance(page, logouts);
  } finally {
    await context.close();
  }
});

// Mutations (Rule 19): render the filter unconditionally, or force `hasContent` true -> the Home leg,
// the first the mutation reaches, goes red; hide the filter everywhere -> the list leg goes red.
test('No read, no filter: Home draws no command bar, the error log and a user editor draw no filter or count, and a list still filters', async () => {
  const { context, page } = await signedInAt(HOME_URL);
  try {
    await page.waitForSelector('main .ocu-home', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$('.ocu-command-bar'), null, 'Home draws no command bar');
    assert.equal(await page.$(FILTER_SELECTOR), null, 'and no filter');

    await openAt(page, ERRORS_URL);
    await page.waitForSelector('.ocu-command-bar-refresh-action', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$(FILTER_SELECTOR), null, 'the error log draws no filter');
    assert.equal(await page.$('.ocu-command-bar-count'), null, 'and no count');

    await openAt(page, USER_EDITOR_URL);
    await page.waitForSelector('main .ocu-form-page', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$(FILTER_SELECTOR), null, 'a user editor draws no filter');
    assert.equal(await page.$('.ocu-command-bar-count'), null, 'and no count');

    await openAt(page, USERS_URL);
    await waitForRows(page, config.navigationTimeoutMs);
    const total = await viewCount(page);
    assert.ok(total > 1, `the Users list has rows to narrow: ${total}`);
    const kept = await filterToSubset(page, { text: 'system', expectRow: '_SYSTEM', total, timeoutMs: config.navigationTimeoutMs });
    const count = await page.$eval('.ocu-command-bar-count', (region) => region.textContent.trim());
    assert.equal(count, STRINGS.tableRowCount.replace('<n>', String(kept)), 'the count reads the narrowed number');
  } finally {
    await context.close();
  }
});

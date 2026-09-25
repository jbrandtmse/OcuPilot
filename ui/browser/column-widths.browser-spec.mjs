/**
 * Story 15.8 on the deployed bundle: the Users list at 720 wide scrolls sideways inside its frame
 * with its header aligned and its name links at least 24x24 (DW-1586), and a column width the user
 * set comes back on return and after a real sign-out and a sign-in in a brand-new context, drawn by
 * `ListPage`'s table from the `view` row `ScreenStore` keeps through `AccountPreferences` (the
 * Integration AC). Browser storage holds only the per-tab token pair throughout.
 *
 * It clears the account's remembered rows through `resetRememberedState` before each test and after
 * the last, never between the sign-out and the sign-in it is about. Refuses the live container: it
 * writes the signed-in account's remembered state.
 *
 * Run: `npm run build`, redeploy the bundle, then
 * `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/column-widths.browser-spec.mjs`
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { resetRememberedState } from './preferences-reset.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();

const USERS_URL = '/ocupilot/permissions/users?ns=HSCUSTOM';
const USERS_ROUTE = 'permissions/users';
const PREFERENCES_PATH = '/api/ocupilot/account/preferences';
const NARROW = { width: 720, height: 450 };
const WIDE = { width: 1280, height: 900 };

/** The only keys the browser may hold: the per-tab token pair and its nonce (AD-28, AD-50). */
const ALLOWED_SESSION_KEYS = ['ocupilot.tab-nonce', 'ocupilot.token-pair'];

let browser = null;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, "this spec writes the signed-in user's remembered state, so it never runs against the live container");
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await resetRememberedState();
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser === null) return;
  await browser.close();
  browser = null;
  await resetRememberedState();
});

function authHeader() {
  return 'Basic ' + Buffer.from(`${config.username}:${config.password}`).toString('base64');
}

async function preferences() {
  const answer = await fetch(`${config.origin}${PREFERENCES_PATH}`, { headers: { Authorization: authHeader() } });
  const text = await answer.text();
  assert.equal(answer.status, 200, `the preferences read answers: ${text}`);
  return JSON.parse(text);
}

/** A brand-new context signed in through the shell's own form, landed on the Users list. */
async function signedInAt(viewport) {
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  await page.setViewport(viewport);
  await page.goto(`${config.origin}${USERS_URL}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', config.username);
  await page.type('#ocu-signin-password', config.password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, USERS_URL);
  await page.waitForSelector('.ocu-data-table-body .ocu-data-table-row', { timeout: config.navigationTimeoutMs });
  await page.evaluate(() => document.fonts.ready);
  await settle(page);
  return { context, page };
}

function settle(page, ms = 200) {
  return page.evaluate((wait) => new Promise((resolve) => setTimeout(() => requestAnimationFrame(() => resolve()), wait)), ms);
}

/**
 * The Integration AC sizes Name and, beside it, Full name, whose label is not its field, so a width
 * stored under the wrong one of the two is one the table never draws.
 */
const SIZED = 'FullName';

function sizedWidth(page, field = SIZED) {
  return page.$eval(`.ocu-data-table-header-cell[data-column="${field}"]`, (cell) => cell.getBoundingClientRect().width);
}

async function press(page, key, modifiers = []) {
  for (const modifier of modifiers) await page.keyboard.down(modifier);
  await page.keyboard.press(key);
  for (const modifier of [...modifiers].reverse()) await page.keyboard.up(modifier);
}

async function clientStorageKeys(page) {
  return page.evaluate(
    (allowed) => ({
      local: Object.keys(localStorage),
      session: Object.keys(sessionStorage).filter((key) => !allowed.includes(key)),
    }),
    ALLOWED_SESSION_KEYS
  );
}

test('Overflow and DW-1586: the Users list at 720 wide scrolls sideways inside its frame, its header follows, the page does not, and every name link is at least 24x24', async () => {
  await resetRememberedState();
  const { context, page } = await signedInAt(NARROW);
  try {
    const before = await page.evaluate(() => {
      const viewport = document.querySelector('app-data-table cdk-virtual-scroll-viewport');
      return { scrollWidth: viewport.scrollWidth, clientWidth: viewport.clientWidth };
    });
    assert.ok(before.scrollWidth > before.clientWidth, `the viewport scrolls sideways: ${JSON.stringify(before)}`);
    await page.evaluate(() => {
      document.querySelector('app-data-table cdk-virtual-scroll-viewport').scrollLeft = 200;
    });
    await settle(page);
    const seen = await page.evaluate(() => {
      const heads = Array.from(document.querySelectorAll('app-data-table .ocu-data-table-header-cell'));
      const cells = Array.from(document.querySelector('app-data-table .ocu-data-table-body .ocu-data-table-row').children);
      return {
        pairs: heads.map((head, index) => [head.getBoundingClientRect().left, cells[index].getBoundingClientRect().left]),
        page: { scrollWidth: document.documentElement.scrollWidth, clientWidth: document.documentElement.clientWidth },
        links: Array.from(document.querySelectorAll('app-data-table .ocu-data-table-link')).map((link) => ({
          text: link.textContent,
          width: link.getBoundingClientRect().width,
          height: link.getBoundingClientRect().height,
        })),
      };
    });
    for (const [index, [head, body]] of seen.pairs.entries()) {
      assert.ok(Math.abs(head - body) <= 0.5, `header cell ${index} at ${head}, body cell at ${body}`);
    }
    assert.equal(seen.page.scrollWidth, seen.page.clientWidth, 'the document does not scroll sideways');
    assert.ok(seen.links.length > 0, 'the list draws name links');
    const small = seen.links.filter((link) => link.width < 24 || link.height < 24);
    assert.deepEqual(small, [], 'no name link is under 24x24');
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): key the stored width by the column's label instead of its field -> the
// width drawn after the return and after the sign-out goes red.
test('Integration AC: widths set on Users\' Name and Full name come back on return and after a real sign-out and a sign-in in a brand-new context, from the view row and never from browser storage', async () => {
  await resetRememberedState();
  let first = null;
  let second = null;
  try {
    first = await signedInAt(WIDE);
    const nameStart = await sizedWidth(first.page, 'Name');
    await first.page.focus('app-data-table [role="grid"]');
    await press(first.page, 'ArrowDown');
    await press(first.page, 'ArrowRight');
    await press(first.page, 'ArrowRight', ['Alt', 'Shift']);
    await settle(first.page);
    const nameSet = await sizedWidth(first.page, 'Name');
    assert.ok(Math.abs(nameSet - (nameStart + 16)) <= 1, `Name is ${nameSet}, ${nameStart} + 16`);
    const start = await sizedWidth(first.page);
    await press(first.page, 'ArrowRight');
    await press(first.page, 'ArrowRight', ['Alt', 'Shift']);
    await settle(first.page);
    await press(first.page, 'ArrowRight', ['Alt', 'Shift']);
    await settle(first.page);
    const set = await sizedWidth(first.page);
    assert.ok(Math.abs(set - (start + 32)) <= 1, `${SIZED} is ${set}, ${start} + 32`);

    // Leave for another screen and come back.
    // An in-app navigation, which the router takes from the history entry as it takes Back.
    await first.page.evaluate(() => {
      history.pushState(null, '', '/ocupilot/permissions/roles?ns=HSCUSTOM');
      dispatchEvent(new PopStateEvent('popstate', { state: null }));
    });
    await first.page.waitForFunction(() => location.pathname.endsWith('/permissions/roles'), { timeout: config.navigationTimeoutMs });
    await first.page.goBack();
    await first.page.waitForSelector(`.ocu-data-table-header-cell[data-column="${SIZED}"]`, { timeout: config.navigationTimeoutMs });
    await settle(first.page);
    assert.ok(Math.abs((await sizedWidth(first.page)) - set) <= 0.5, 'the same width on return');
    assert.ok(Math.abs((await sizedWidth(first.page, 'Name')) - nameSet) <= 0.5, 'and the same Name width');

    const held = await preferences();
    const view = held.views.find((entry) => entry.route === USERS_ROUTE);
    assert.ok(view !== undefined, `the instance holds the Users view: ${JSON.stringify(held.views)}`);
    assert.deepEqual(JSON.parse(view.value).widths, { Name: Math.round(nameSet), [SIZED]: Math.round(set) }, `beside sort, filter and max rows: ${view.value}`);
    assert.deepEqual(await clientStorageKeys(first.page), { local: [], session: [] }, 'browser storage holds only the token pair');

    await first.page.click('#ocu-account-trigger');
    await first.page.waitForSelector('[role="menuitem"]', { visible: true, timeout: config.navigationTimeoutMs });
    const signedOut = await first.page.evaluate((label) => {
      const item = [...document.querySelectorAll('[role="menuitem"]')].find((candidate) => candidate.textContent.trim() === label);
      if (item === undefined) return false;
      item.id = 'ocu-probe-sign-out';
      return true;
    }, STRINGS.actionSignOut);
    assert.ok(signedOut, 'the account menu lists Sign out');
    await first.page.click('#ocu-probe-sign-out');
    await first.page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });

    second = await signedInAt(WIDE);
    await second.page.waitForFunction(
      (field, wanted) => {
        const cell = document.querySelector(`.ocu-data-table-header-cell[data-column="${field}"]`);
        return cell !== null && Math.abs(cell.getBoundingClientRect().width - wanted) <= 0.5;
      },
      { timeout: config.navigationTimeoutMs },
      SIZED,
      set
    );
    const template = await second.page.$eval('app-data-table .ocu-data-table-header-row', (element) => element.style.gridTemplateColumns);
    assert.ok(template.startsWith(`${Math.round(nameSet)}px ${Math.round(set)}px `), `Name and ${SIZED} are drawn at their stored widths: ${template}`);
    assert.deepEqual(await clientStorageKeys(second.page), { local: [], session: [] }, 'and the new context holds only the token pair');
  } finally {
    if (first !== null) await first.context.close();
    if (second !== null) await second.context.close();
  }
});

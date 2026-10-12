/**
 * Screens load on demand, in a real browser against the throwaway instance (Story 20.29, AD-5).
 *
 * Every screen's page is a lazily loaded chunk the router fetches the first time a person opens
 * the screen. jsdom fetches no module over HTTP, enforces no content-security policy and has no
 * module map, so only this tier can say what the claim is made of:
 *
 * - **A person's navigation brings the screen's code.** From Home, a rail click and a side-bar click
 *   to an area whose page has not loaded fetch at least one new `chunk-*.js`, and the page renders in
 *   the outlet. Each chunk answers 200, `application/javascript`, with the immutable cache header
 *   the installed handler gives a hashed file.
 * - **A return visit fetches nothing.** The route keeps the component it loaded.
 * - **The policy admits it.** No `securitypolicyviolation` fires during the navigation, and nothing
 *   is logged as a console error from the shell's own path.
 *
 * Reads only: it signs in and clicks navigation, and writes nothing to the instance.
 *
 * Run: `npm run build`, then copy the bundle into the throwaway (`.claude/rules/objectscript-testing.md`,
 * "a browser spec runs against the deployed bundle"), then
 * `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/lazy-screens.browser-spec.mjs`
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, SHELL_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { signedInAt } from './panel-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();

const HOME_URL = '/ocupilot/?ns=HSCUSTOM';
/** The Permissions area's rail item, and the Users list its side bar offers: a list the Home page never loads. */
const PERMISSIONS_RAIL = '#ocu-rail-item-permissions';
const HOME_RAIL = '#ocu-rail-item-home';
const USERS_ROUTE = 'permissions/users';
/** The Users list is the shared list page; its component definition compiles to `selectors:[["app-list-page"]]`. */
const USERS_PAGE_DEFINITION = /selectors:\[\[["'`]app-list-page["'`]/;

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

/** Record every `chunk-*.js` the page fetches, with what the instance answered. */
function watchChunks(page) {
  const chunks = [];
  page.on('response', (response) => {
    const url = new URL(response.url());
    if (!url.pathname.startsWith(SHELL_PATH) || !/\/chunk-[^/]+\.js$/.test(url.pathname)) return;
    const headers = response.headers();
    chunks.push({
      path: url.pathname,
      status: response.status(),
      contentType: headers['content-type'] ?? '',
      cacheControl: headers['cache-control'] ?? '',
    });
  });
  return chunks;
}

/**
 * Collect what the navigation must not cause: a content-security-policy violation in the document,
 * and a console error from the shell's own path (an error from the origin root, such as the
 * browser's own favicon request, is the browser's and not counted).
 */
async function watchFaults(page) {
  const consoleErrors = [];
  page.on('console', (message) => {
    if (message.type() !== 'error') return;
    const url = message.location()?.url ?? '';
    if (url !== '' && !url.includes(SHELL_PATH)) return;
    consoleErrors.push(`${message.text()} (${url})`);
  });
  page.on('pageerror', (error) => consoleErrors.push(`uncaught: ${String(error)}`));
  await page.evaluate(() => {
    window.__ocuViolations = [];
    document.addEventListener('securitypolicyviolation', (event) => {
      window.__ocuViolations.push(`${event.violatedDirective} ${event.blockedURI}`);
    });
  });
  return {
    consoleErrors,
    violations: () => page.evaluate(() => window.__ocuViolations),
  };
}

/** Click a rail item, then the side-bar entry named `label` it reveals, with a real pointer. */
async function openFromSideBar(page, railItem, label) {
  await page.click(railItem);
  await page.waitForFunction(
    (wanted) => [...document.querySelectorAll('.ocu-side-bar-item .ocu-side-bar-label')].some((node) => node.textContent.trim() === wanted),
    { timeout: config.navigationTimeoutMs },
    label
  );
  const index = await page.evaluate(
    (wanted) => [...document.querySelectorAll('.ocu-side-bar-item')].findIndex((node) => node.querySelector('.ocu-side-bar-label').textContent.trim() === wanted),
    label
  );
  await page.click(`.ocu-side-bar-item:nth-of-type(${index + 1})`);
}

/** Wait until the outlet holds `route`'s screen and a page has mounted beside the router outlet. */
async function waitForPage(page, route) {
  await page.waitForFunction(
    (wanted) => {
      const outlet = document.querySelector('.ocu-screen-outlet');
      return outlet !== null && outlet.dataset.screen === wanted && outlet.querySelector('router-outlet + *') !== null;
    },
    { timeout: config.navigationTimeoutMs },
    route
  );
}

// AC3. Mutation (Rule 19): import the Users list's page statically from eager code (`ListPage` in
// `shell/panel.ts`, used) and rebuild and redeploy -> the click fetches only a re-export stub, no
// chunk it fetched defines the page, and the page-definition assertion goes red.
test('AC3: opening an unvisited screen fetches its page chunk once, with no policy violation, and a return visit fetches none', async () => {
  const { context, page } = await signedInAt(browser, config, HOME_URL);
  try {
    await page.waitForSelector('.ocu-screen-outlet', { timeout: config.navigationTimeoutMs });
    const chunks = watchChunks(page);
    const faults = await watchFaults(page);

    await openFromSideBar(page, PERMISSIONS_RAIL, STRINGS.userListLabel);
    await waitForPage(page, USERS_ROUTE);

    assert.ok(chunks.length > 0, 'the click fetched at least one new chunk-*.js for the screen it opened');
    for (const chunk of chunks) {
      assert.equal(chunk.status, 200, `${chunk.path} answers 200`);
      assert.match(chunk.contentType, /^application\/javascript\b/, `${chunk.path} is served as JavaScript`);
      assert.match(chunk.cacheControl, /\bimmutable\b/, `${chunk.path} carries the immutable cache header`);
    }
    assert.equal(new Set(chunks.map((chunk) => chunk.path)).size, chunks.length, 'and each chunk was fetched once');
    const bodies = await Promise.all(chunks.map(async (chunk) => (await fetch(`${config.origin}${chunk.path}`)).text()));
    assert.ok(
      bodies.some((body) => USERS_PAGE_DEFINITION.test(body)),
      `the page's own code arrived with the click: none of ${JSON.stringify(chunks.map((chunk) => chunk.path))} defines app-list-page`
    );

    // Away and back: the screen's code is already here, so the second visit asks for nothing.
    await page.click(HOME_RAIL);
    await page.waitForFunction(() => document.querySelector('.ocu-screen-outlet')?.dataset.archetype === 'home', { timeout: config.navigationTimeoutMs });
    const homeFetched = chunks.length;
    await openFromSideBar(page, PERMISSIONS_RAIL, STRINGS.userListLabel);
    await waitForPage(page, USERS_ROUTE);
    assert.equal(chunks.length, homeFetched, 'a return visit to the same screen fetches no chunk');

    assert.deepEqual(await faults.violations(), [], 'no content-security-policy violation fired during the navigation');
    assert.deepEqual(faults.consoleErrors, [], 'and nothing was logged as a console error from the shell');
  } finally {
    await context.close();
  }
});

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
 * - **The outlet is never ready without its page.** The router creates the outlet before it renders,
 *   and the page after it; from creation until the page is in it the outlet reads `aria-busy="true"`.
 * - **A full page load at a screen's own URL brings its code too.** A list screen's URL and an id
 *   route's URL (whose edit page is not the screen's base page) each fetch a chunk outside the
 *   initial set that defines the page they render once the person has signed in.
 * - **The policy admits it.** No `securitypolicyviolation` fires during the navigation, and nothing
 *   is logged as a console error from the shell's own path.
 *
 * It signs in, clicks navigation and opens two URLs. It writes nothing to the instance beyond the
 * reset every context makes and the recent-screen visit the shell records for each screen it opens.
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
import { staticImportsOf } from '../tools/bundle-imports.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { openFromSideBar, signedInAt } from './panel-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();

const HOME_URL = '/ocupilot/?ns=HSCUSTOM';
/** The Permissions area's rail item, and the Users list its side bar offers: a list the Home page never loads. */
const PERMISSIONS_RAIL = '#ocu-rail-item-permissions';
const HOME_RAIL = '#ocu-rail-item-home';
const USERS_ROUTE = 'permissions/users';
/** The Users list is the shared list page; its component definition compiles to `selectors:[["app-list-page"]]`. */
const USERS_PAGE_DEFINITION = /selectors:\[\[["'`]app-list-page["'`]/;
const USERS_URL = '/ocupilot/permissions/users?ns=HSCUSTOM';
/**
 * An id route whose edit page is not the screen's base page: the Users editor, opened on the account
 * every spec signs in as (a read; nothing is saved). The base page at `permissions/users/edit` is the
 * create form, `app-user-create-form-page`.
 */
const USER_EDIT_ROUTE = 'permissions/users/edit';
const USER_EDIT_URL = `/ocupilot/${USER_EDIT_ROUTE}/${config.username}?ns=HSCUSTOM`;
const USER_EDIT_PAGE_DEFINITION = /selectors:\[\[["'`]app-user-editor-page["'`]/;

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
 *
 * With `cold` the page has not loaded yet: the listener goes into the document it is about to open,
 * and only an error about a file under the shell's own path (`/ocupilot/`) counts, because a full
 * page load signs in first and the API's 401s before that are the ordinary path.
 */
async function watchFaults(page, { cold = false } = {}) {
  const consoleErrors = [];
  page.on('console', (message) => {
    if (message.type() !== 'error') return;
    const url = message.location()?.url ?? '';
    const ours = cold ? new URL(url, config.origin).pathname.startsWith(SHELL_PATH) : url.includes(SHELL_PATH);
    if (url !== '' && !ours) return;
    consoleErrors.push(`${message.text()} (${url})`);
  });
  page.on('pageerror', (error) => consoleErrors.push(`uncaught: ${String(error)}`));
  const listen = () => {
    window.__ocuViolations = [];
    document.addEventListener('securitypolicyviolation', (event) => {
      window.__ocuViolations.push(`${event.violatedDirective} ${event.blockedURI}`);
    });
  };
  if (cold) await page.evaluateOnNewDocument(listen);
  else await page.evaluate(listen);
  return {
    consoleErrors,
    violations: () => page.evaluate(() => window.__ocuViolations),
  };
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

/** Every chunk answered 200 as JavaScript, with the immutable cache header the handler gives a hashed file. */
function assertServedAsModules(chunks) {
  for (const chunk of chunks) {
    assert.equal(chunk.status, 200, `${chunk.path} answers 200`);
    assert.match(chunk.contentType, /^application\/javascript\b/, `${chunk.path} is served as JavaScript`);
    assert.match(chunk.cacheControl, /\bimmutable\b/, `${chunk.path} carries the immutable cache header`);
  }
}

/**
 * Some chunk in `chunks` defines the component `selector`. Chunk names are content hashes, so the
 * bytes fetched here are the bytes the page ran.
 */
async function assertDefinesPage(chunks, definition, selector) {
  const bodies = await Promise.all(chunks.map(async (chunk) => (await fetch(`${config.origin}${chunk.path}`)).text()));
  assert.ok(
    bodies.some((body) => definition.test(body)),
    `the page's own code arrived: none of ${JSON.stringify(chunks.map((chunk) => chunk.path))} defines ${selector}`
  );
}

/**
 * The scripts a cold open loads before any screen is chosen: what `index.html` names, and what those
 * import statically, read from the files the instance serves along the edges `build-output.test.mjs`
 * follows over the built ones.
 */
async function initialScripts() {
  const html = await (await fetch(`${config.origin}${SHELL_PATH}`)).text();
  const initial = new Set([...html.matchAll(/<(?:script|link)\b[^>]*\b(?:src|href)=["']([^"']+\.js)["']/gi)].map((match) => match[1]));
  const queue = [...initial];
  while (queue.length > 0) {
    const text = await (await fetch(`${config.origin}${SHELL_PATH}${queue.pop()}`)).text();
    for (const imported of staticImportsOf(text)) {
      if (!initial.has(imported)) {
        initial.add(imported);
        queue.push(imported);
      }
    }
  }
  return initial;
}

/**
 * A fresh context that opens `url` as a full page load, signs in through the shell's own form and
 * stands on `url` again, watching chunks and faults from the first request.
 */
async function openCold(url) {
  let chunks = [];
  let faults = null;
  const { context, page } = await signedInAt(browser, config, url, config.viewport, null, async (fresh) => {
    chunks = watchChunks(fresh);
    faults = await watchFaults(fresh, { cold: true });
  });
  return { context, page, chunks, faults };
}

/** The chunks a cold open fetched beyond the initial set: the ones the router asked for to show the screen. */
async function lazyChunksOf(chunks) {
  const initial = await initialScripts();
  return chunks.filter((chunk) => !initial.has(chunk.path.slice(SHELL_PATH.length)));
}

// AC3. Mutation (Rule 19): import the Users list's page statically from eager code (`ListPage` in
// `shell/panel.ts`, used) and rebuild and redeploy -> the click fetches only a re-export stub, no
// chunk it fetched defines the page, and the page-definition assertion goes red. Mutation (Rule 19):
// drop the static `aria-busy` from `ScreenOutlet`'s host metadata and rebuild and redeploy -> the
// outlet the router has created and not yet rendered reads ready, and the busy assertion goes red.
test('AC3: opening an unvisited screen fetches its page chunk once, with no policy violation, and a return visit fetches none', async () => {
  const { context, page } = await signedInAt(browser, config, HOME_URL);
  try {
    await page.waitForSelector('.ocu-screen-outlet', { timeout: config.navigationTimeoutMs });
    const chunks = watchChunks(page);
    const faults = await watchFaults(page);
    await page.evaluate(() => {
      window.__ocuReadyWithoutPage = [];
      new MutationObserver(() => {
        for (const host of document.querySelectorAll('app-screen-outlet')) {
          if (host.getAttribute('aria-busy') !== 'true' && host.querySelector('router-outlet + *') === null) window.__ocuReadyWithoutPage.push(location.pathname);
        }
      }).observe(document.body, { subtree: true, childList: true, attributes: true });
    });

    await openFromSideBar(page, config, PERMISSIONS_RAIL, STRINGS.userListLabel);
    await waitForPage(page, USERS_ROUTE);

    assert.ok(chunks.length > 0, 'the click fetched at least one new chunk-*.js for the screen it opened');
    assertServedAsModules(chunks);
    assert.equal(new Set(chunks.map((chunk) => chunk.path)).size, chunks.length, 'and each chunk was fetched once');
    await assertDefinesPage(chunks, USERS_PAGE_DEFINITION, 'app-list-page');

    // Away and back: the screen's code is already here, so the second visit asks for nothing.
    await page.click(HOME_RAIL);
    await page.waitForFunction(() => document.querySelector('.ocu-screen-outlet')?.dataset.archetype === 'home', { timeout: config.navigationTimeoutMs });
    const homeFetched = chunks.length;
    await openFromSideBar(page, config, PERMISSIONS_RAIL, STRINGS.userListLabel);
    await waitForPage(page, USERS_ROUTE);
    assert.equal(chunks.length, homeFetched, 'a return visit to the same screen fetches no chunk');
    assert.deepEqual(
      await page.evaluate(() => window.__ocuReadyWithoutPage),
      [],
      'no outlet the router created read ready before its page was in it'
    );

    assert.deepEqual(await faults.violations(), [], 'no content-security-policy violation fired during the navigation');
    assert.deepEqual(faults.consoleErrors, [], 'and nothing was logged as a console error from the shell');
  } finally {
    await context.close();
  }
});

// AC3, I/O matrix "Cold deep link". Mutation (Rule 19): drop the `children` from the base route push in
// `buildRoutes` and rebuild and redeploy -> no page mounts at the Users URL and `waitForPage` times out.
test('AC3: a full page load at a list screen\'s URL fetches that screen\'s page chunk, and the page renders after sign-in', async () => {
  const { context, page, chunks, faults } = await openCold(USERS_URL);
  try {
    await waitForPage(page, USERS_ROUTE);

    const lazy = await lazyChunksOf(chunks);
    assert.ok(lazy.length > 0, 'the deep link fetched a chunk outside the initial set for the screen it opened');
    assertServedAsModules(chunks);
    await assertDefinesPage(lazy, USERS_PAGE_DEFINITION, 'app-list-page');

    assert.deepEqual(await faults.violations(), [], 'no content-security-policy violation fired during the page load');
    assert.deepEqual(faults.consoleErrors, [], 'and nothing was logged as a console error from the shell');
  } finally {
    await context.close();
  }
});

// AC1 and AC3, I/O matrix "Cold deep link". Mutation (Rule 19): give every `:id` route the base loader in
// `buildRoutes` and rebuild and redeploy -> the id route mounts the create form, not the editor, and this goes red.
test('AC3: a full page load at an id route fetches the edit page\'s chunk, and the editor, not the screen\'s base page, renders', async () => {
  const { context, page, chunks, faults } = await openCold(USER_EDIT_URL);
  try {
    await waitForPage(page, USER_EDIT_ROUTE);

    const lazy = await lazyChunksOf(chunks);
    assert.ok(lazy.length > 0, 'the deep link fetched a chunk outside the initial set for the id route it opened');
    assertServedAsModules(chunks);
    await assertDefinesPage(lazy, USER_EDIT_PAGE_DEFINITION, 'app-user-editor-page');
    assert.equal(
      await page.evaluate(() => document.querySelector('.ocu-screen-outlet router-outlet + *').localName),
      'app-user-editor-page',
      'and the id route renders the edit page, not the base page the same screen shows without an id'
    );

    assert.deepEqual(await faults.violations(), [], 'no content-security-policy violation fired during the page load');
    assert.deepEqual(faults.consoleErrors, [], 'and nothing was logged as a console error from the shell');
  } finally {
    await context.close();
  }
});

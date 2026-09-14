/**
 * The signed-in shell in a real browser (Story 1.17, DW-159's harness half).
 *
 * **Four assertions jsdom cannot make, and every one of them is load-bearing.**
 *
 * 1. **The shell renders with non-zero laid-out geometry.** jsdom has no layout engine: every
 *    `getBoundingClientRect()` it answers is zeros, so the whole component suite can pass
 *    against a shell that paints nothing. A stylesheet that failed to load, a Content-Security-
 *    Policy that refused the nonce Angular needs for its runtime styles, a template that renders
 *    an element with no box -- none of them is visible to a single `*.spec.ts` in `src/`.
 * 2. **A deep link resolves to the shell.** The fallback is the SERVER's
 *    (`OcuPilot.Api.StaticHandler` answers `index.html` for anything it cannot resolve to a
 *    file), and the client router then takes the route. A jsdom test constructs the router's
 *    state directly and never makes the request that would prove the server half.
 * 3. **Silent-first sign-in completes once the classic portal has minted the browser-id
 *    cookie.** The cookie is a real browser's, set by a different application on the same
 *    origin, and presented on the token request because the browser decides to. Nothing about
 *    that is expressible in jsdom, and it is the mechanism the whole silent-first design rests
 *    on (AD-28).
 * 4. **"Skip to content" is the first Tab stop**, visible only while focused, and Enter moves
 *    focus to the content without changing the URL. jsdom has no Tab order and no painted
 *    visibility.
 *
 * **It runs against a throwaway container and refuses to run against anything that is not
 * ready.** The first thing it does is ask the readiness endpoint; an instance that is not
 * installed fails the spec there, naming the state, rather than producing a page of console
 * errors that look like client defects.
 *
 * Run: `npm run test:browser` (after `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import {
  CLASSIC_LOGIN_PATH,
  DEEP_LINK_PATH,
  READINESS_PATH,
  SHELL_PATH,
  browserConfig,
  launchOptions,
} from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';

const config = browserConfig();
let browser = null;

before(async () => {
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
});

/**
 * Sign in to the classic portal in `page`'s own context, so the browser holds the cookie the
 * shell mints silently from (AD-28).
 *
 * **The shell renders the sign-in card, not the rail, for a browser with no session** -- which
 * is the product behaving correctly, and which is why the geometry assertions below cannot be
 * made on a cold context. Verified: a cold load of `/ocupilot/` renders `app-sign-in` and no
 * `app-rail` at all.
 *
 * The field names are tried in order because the classic portal's login form has carried two
 * spellings across releases; a form this cannot fill leaves the context cookie-less, and the
 * caller's own assertions then say so rather than this helper throwing something unrelated.
 */
async function signInToClassicPortal(page) {
  await page.goto(`${config.origin}${CLASSIC_LOGIN_PATH}`, { waitUntil: 'networkidle2' });
  const form = await page.$('input[name="IRISUsername"], input[name="CacheUserName"], input[type="password"]');
  if (form === null) return;
  await page.evaluate(
    (user, password) => {
      const set = (selectors, value) => {
        for (const selector of selectors) {
          const field = document.querySelector(selector);
          if (field !== null) {
            field.value = value;
            return true;
          }
        }
        return false;
      };
      set(['input[name="IRISUsername"]', 'input[name="CacheUserName"]', 'input[type="text"]'], user);
      set(['input[name="IRISPassword"]', 'input[name="CachePassword"]', 'input[type="password"]'], password);
      document.querySelector('form')?.submit();
    },
    config.username,
    config.password
  );
  await page.waitForNavigation({ waitUntil: 'networkidle2' }).catch(() => {});
}

/** A fresh, isolated browser context, so no test inherits another's cookies. */
async function freshPage() {
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  const consoleErrors = [];
  page.on('console', (message) => {
    if (message.type() !== 'error') return;
    // The browser asks the ORIGIN ROOT for /favicon.ico on its own, unprompted, whenever a
    // document declares no icon link -- and the origin root belongs to no OcuPilot web
    // application, so it answers 404 and Chrome logs a resource error. That is the browser's
    // behaviour, not the shell's, and it is excluded by where the request went rather than by
    // matching its text: anything the SHELL asked for and did not get is still an error here.
    // Observed on this build; the 401 the silent-first probe gets with no cookie is not a
    // console error at all.
    const url = message.location()?.url ?? '';
    if (url !== '' && !url.includes(SHELL_PATH)) return;
    consoleErrors.push(`${message.text()} (${url})`);
  });
  page.on('pageerror', (error) => consoleErrors.push(`uncaught: ${String(error)}`));
  return { context, page, consoleErrors };
}

test('the instance this spec is pointed at is installed, or nothing below means anything', async () => {
  const { context, page } = await freshPage();
  try {
    const response = await page.goto(`${config.origin}${READINESS_PATH}`, { waitUntil: 'domcontentloaded' });
    assert.equal(response.status(), 200, `readiness answered ${response.status()} at ${config.origin}`);
    const body = JSON.parse(await page.evaluate(() => document.body.innerText));
    assert.equal(
      body.state,
      'installed',
      `the instance at ${config.origin} reports state "${body.state}"; a browser spec against an uninstalled instance would report client defects that are install defects`
    );
  } finally {
    await context.close();
  }
});

test('the shell loads with no console error and lays out the rail and the side bar (DW-159)', async () => {
  const { context, page, consoleErrors } = await freshPage();
  try {
    await signInToClassicPortal(page);
    const response = await page.goto(`${config.origin}${SHELL_PATH}`, { waitUntil: 'networkidle2' });
    assert.equal(response.status(), 200, 'the shell answers 200');

    await page.waitForSelector('app-root', { timeout: config.navigationTimeoutMs });
    // The rail exists only once the session settles: a browser with no session gets the sign-in
    // card, which is the product working. Waiting for the rail rather than for a delay is what
    // keeps this from being a race dressed as a timeout.
    await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });

    // Non-zero laid-out geometry, which is the whole point: jsdom answers zeros for every one of
    // these, so the component suite cannot tell a rendered shell from an empty one.
    const geometry = await page.evaluate(() => {
      const box = (selector) => {
        const element = document.querySelector(selector);
        if (element === null) return null;
        const rect = element.getBoundingClientRect();
        return { width: rect.width, height: rect.height };
      };
      return {
        root: box('app-root'),
        // The component selectors the shell actually renders, read from `rail.ts` and
        // `side-bar.ts`. A guessed selector that matched nothing would make this test assert
        // "not present" forever, which is the assertion that cannot fail in the other
        // direction.
        rail: box('app-rail .ocu-rail'),
        sideBar: box('app-side-bar'),
      };
    });

    assert.ok(geometry.root, 'the application root is in the document');
    assert.ok(geometry.root.width > 0 && geometry.root.height > 0, `the shell has a box: ${JSON.stringify(geometry.root)}`);
    assert.ok(geometry.rail, 'the navigation rail is in the document');
    assert.ok(geometry.rail.width > 0 && geometry.rail.height > 0, `the rail is laid out: ${JSON.stringify(geometry.rail)}`);
    assert.ok(geometry.sideBar, 'the side bar is in the document');
    // The side bar ships collapsed: it occupies the layout's full height and no width until it
    // is opened. Asserted as two facts rather than one, because a side bar that was absent and
    // one that was collapsed would both answer a bare "width is 0".
    assert.ok(
      geometry.sideBar.height > 0,
      `the side bar occupies the layout even while collapsed: ${JSON.stringify(geometry.sideBar)}`
    );

    // Opening it is the assertion a jsdom run cannot make at all: a click changing a laid-out
    // width. The rail's area buttons open an area's side bar without navigating (`rail.spec.ts`
    // pins that behaviour against jsdom, where the width it produces is always zero).
    const railItems = await page.$$('.ocu-rail-item');
    assert.ok(railItems.length > 1, `the rail rendered its items: ${railItems.length}`);
    await railItems[1].click();
    await page.waitForFunction(
      () => (document.querySelector('app-side-bar')?.getBoundingClientRect().width ?? 0) > 0,
      { timeout: config.navigationTimeoutMs }
    );
    const opened = await page.evaluate(() => {
      const rect = document.querySelector('app-side-bar').getBoundingClientRect();
      return { width: rect.width, height: rect.height };
    });
    assert.ok(opened.width > 0, `the opened side bar has a laid-out width: ${JSON.stringify(opened)}`);

    assert.deepEqual(
      consoleErrors,
      [],
      `the shell loaded with console errors, which a jsdom run cannot see: ${consoleErrors.join(' | ')}`
    );
  } finally {
    await context.close();
  }
});

test('"Skip to content" is the first Tab stop, shows only while focused, and Enter focuses main without changing the URL', async () => {
  const { context, page } = await freshPage();
  try {
    await signInToClassicPortal(page);
    await page.goto(`${config.origin}${SHELL_PATH}`, { waitUntil: 'networkidle2' });
    await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });

    const urlBefore = await page.evaluate(() => window.location.href);
    const unfocused = await page.evaluate(() => {
      const link = document.querySelector('.ocu-skip-link');
      return link === null ? null : getComputedStyle(link).clipPath;
    });
    assert.ok(unfocused !== null, 'the signed-in frame renders a skip link');
    assert.notEqual(unfocused, 'none', `the link is clipped out of sight until it holds focus: ${unfocused}`);

    await page.keyboard.press('Tab');
    const focused = await page.evaluate(() => {
      const active = document.activeElement;
      const rect = active.getBoundingClientRect();
      const header = document.querySelector('app-header')?.getBoundingClientRect() ?? null;
      return {
        isSkipLink: active.classList.contains('ocu-skip-link'),
        text: active.textContent.trim(),
        clipPath: getComputedStyle(active).clipPath,
        rect: { left: rect.left, top: rect.top, width: rect.width, height: rect.height },
        headerBottom: header === null ? null : header.bottom,
      };
    });
    assert.equal(focused.isSkipLink, true, `the first Tab stop is the skip link: ${JSON.stringify(focused)}`);
    assert.equal(focused.text, loadStrings().navSkipToContent);
    assert.equal(focused.clipPath, 'none', 'and it is visible while focused');
    assert.ok(focused.rect.width > 0 && focused.rect.height > 0, `with a laid-out box: ${JSON.stringify(focused.rect)}`);
    assert.ok(
      focused.headerBottom !== null && focused.rect.top < focused.headerBottom,
      `drawn over the header: ${JSON.stringify(focused)}`
    );

    await page.keyboard.press('Enter');
    const after = await page.evaluate(() => ({
      tag: document.activeElement?.tagName ?? '',
      id: document.activeElement?.id ?? '',
      href: window.location.href,
    }));
    assert.equal(after.tag, 'MAIN', `Enter moves focus to the content: ${JSON.stringify(after)}`);
    assert.equal(after.id, 'ocu-content');
    assert.equal(after.href, urlBefore, 'and the URL is unchanged');
  } finally {
    await context.close();
  }
});

test('a deep link resolves to the shell, through the server fallback (DW-159)', async () => {
  const { context, page } = await freshPage();
  try {
    const response = await page.goto(`${config.origin}${DEEP_LINK_PATH}`, { waitUntil: 'networkidle2' });
    assert.equal(response.status(), 200, 'a client route no file exists for is answered, not 404ed');

    await page.waitForSelector('app-root', { timeout: config.navigationTimeoutMs });
    const state = await page.evaluate(() => ({
      path: window.location.pathname,
      base: document.querySelector('base')?.getAttribute('href') ?? '',
      hasRoot: document.querySelector('app-root') !== null,
    }));

    assert.equal(state.hasRoot, true, 'the shell document was served for the deep link');
    assert.equal(state.base, '/ocupilot/', 'with the non-root base href the build sets');
    assert.equal(state.path, DEEP_LINK_PATH, 'and the URL the user pasted survived, rather than being redirected away');
  } finally {
    await context.close();
  }
});

test('silent-first sign-in completes once the classic portal has minted the cookie (DW-159, AD-28)', async () => {
  const { context, page } = await freshPage();
  try {
    // The classic portal's own login, in the same browser context. What it mints is a real
    // cookie set by a different application on the same origin -- the mechanism silent-first
    // sign-in rests on, and the one thing no jsdom test can produce.
    await signInToClassicPortal(page);

    // `BrowserContext.cookies()` takes no arguments — an origin passed to it is ignored — so the
    // filter is applied here rather than being assumed.
    const origin = new URL(config.origin);
    const cookies = (await context.cookies()).filter(
      (cookie) => cookie.domain === origin.hostname || cookie.domain === `.${origin.hostname}`
    );
    assert.ok(
      cookies.length > 0,
      'the classic portal set at least one cookie for this origin; without one there is nothing for the token endpoint to mint from'
    );

    await page.goto(`${config.origin}${SHELL_PATH}`, { waitUntil: 'networkidle2' });
    await page.waitForSelector('app-root', { timeout: config.navigationTimeoutMs });

    // The shell mints silently by POSTing the token endpoint with no body and the cookie the
    // browser presents. Asserted on the response the browser actually received, because the
    // shell's own rendered state is what every jsdom test already covers.
    const minted = await page.evaluate(async (root) => {
      const response = await fetch(`${root}/api/ocupilot/login`, {
        method: 'POST',
        credentials: 'include',
      });
      const text = await response.text();
      let parsed = null;
      try {
        parsed = JSON.parse(text);
      } catch {
        parsed = null;
      }
      return { status: response.status, hasAccess: parsed !== null && typeof parsed.access_token === 'string' };
    }, config.origin);

    assert.equal(minted.status, 200, `silent sign-in answered ${minted.status}`);
    assert.equal(minted.hasAccess, true, 'and minted an access token from the cookie alone');
  } finally {
    await context.close();
  }
});

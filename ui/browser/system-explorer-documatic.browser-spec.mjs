/**
 * Story 19.9 in a real browser, against the throwaway: the class viewer's Class reference loads the
 * instance's own class page for `OcuProbe199.Doc` in USER, signed in by the browser-level login
 * alone, with no token in its address or its requests (AC1); the frame is sandboxed with no flag, so
 * the probe description's script never runs and the tab's storage is out of its reach (AC2); a link
 * followed inside the frame is replaced by the class page again, with the status line saying so,
 * and none can be followed before the class page has loaded (AC3); and the view is a toggle button,
 * the frame named for the class and reached by Tab, the status line a live region, and the view
 * passes the structural walk at 1280 light, 720 light and 1280 dark with no entry beyond the
 * baseline (AC6).
 *
 * The probe class is `OcuPilot.Test.DocumaticProbe`'s, created in `before` and removed in `after` by
 * that class, which names only its own package. `before` refuses any container but a throwaway, and
 * `after` removes the probe only from a container `before` accepted.
 *
 * Run: `node --test --test-concurrency=1 browser/system-explorer-documatic.browser-spec.mjs` (after
 * `npm run build`, the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { encodeEntityId } = await import(join(uiRoot, 'src', 'app', 'core', 'entity-id.ts'));
const { PAIR_STORAGE_KEY } = await import(join(uiRoot, 'src', 'app', 'core', 'token-store.ts'));

const config = browserConfig();
const STRINGS = loadStrings();
const PROBE = 'OcuPilot.Test.DocumaticProbe';
const CLASS = 'OcuProbe199.Doc';
const CLASS_VIEWER_ROUTE = 'system-explorer/classes/document';
const FRAME = 'iframe[data-ocu-source="reference-frame"]';
const STATUS = '[data-ocu-source="reference-status"]';
const REFERENCE_PATH = `/csp/documatic/%25CSP.Documatic.cls?PAGE=CLASS&SHOWCLASSONLY=1&LIBRARY=USER&CLASSNAME=${CLASS}`;
const VENDOR_TITLE = `Class ${CLASS}`;
const PROBE_TEXT = 'OcuProbe199 class reference probe.';
const PROBE_IMAGE = '/csp/documatic/ocuprobe199.png';

let browser = null;
let accepted = false;

const marker = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates and removes a class, so it never runs inside the live container');
  await assertThrowaway(config);
  accepted = true;
  const output = runIris(config.container, [
    `Set tSC=##class(${PROBE}).Remove("USER")`,
    `If tSC Set tSC=##class(${PROBE}).Make("USER")`,
    marker('OK', '$System.Status.IsOK(tSC)'),
  ]);
  assert.equal(markerValue(output, 'OK'), '1', `the probe class is created in USER: ${output}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (!accepted) return;
  const output = runIris(config.container, [`Set tSC=##class(${PROBE}).Remove("USER")`, marker('OK', '$System.Status.IsOK(tSC)')]);
  assert.equal(markerValue(output, 'OK'), '1', `no probe class is left in USER: ${output}`);
});

function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/**
 * Poll `read` from here until it answers `wanted`, answering the last value read. The frame runs no
 * script, so nothing can be waited for inside it.
 */
async function until(read, wanted, what) {
  const deadline = Date.now() + config.navigationTimeoutMs;
  let last;
  while (Date.now() < deadline) {
    try {
      last = await read();
    } catch (error) {
      last = `(${error.message})`;
    }
    if (last === wanted) return last;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  assert.fail(`${what}: waited for ${JSON.stringify(wanted)}, last read ${JSON.stringify(last)}`);
}

/** The walk of the screen on display at three passes, answering entries outside the baseline. */
async function structural(page, route) {
  const found = [];
  const passes = [
    { viewport: VIEWPORTS.wide, theme: 'light', checks: INVARIANTS },
    { viewport: VIEWPORTS.narrow, theme: 'light', checks: ['name', 'min-width', 'overflow'] },
    { viewport: VIEWPORTS.wide, theme: 'dark', checks: ['contrast'] },
  ];
  const minimums = componentMinimums();
  const surfaces = {};
  for (const { viewport, theme, checks } of passes) {
    await page.setViewport(viewport);
    await page.evaluate((dark) => document.documentElement.classList.toggle('ocu-theme-dark', dark), theme === 'dark');
    await frames(page);
    surfaces[theme] = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
    const { entries } = await detectScreen(page, { route, checks, viewport: viewport.width, theme, minimums });
    found.push(...entries);
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await frames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  return compare(collapse(found), readBaseline()?.entries ?? []).fresh.map((entry) => `${entry.key}: ${entry.measured}`);
}

/**
 * Signed in on the probe class's viewer in USER with Class reference chosen and its page shown,
 * every request to the class reference recorded. The page has loaded and the frame is interactive
 * again, unless `held` is an array: then each request for the probe's image is held in it, so the
 * page's own load stays pending.
 */
async function onClassReference(held = null) {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${CLASS_VIEWER_ROUTE}/${encodeEntityId(`${CLASS}.cls`)}?ns=USER`, VIEWPORTS.wide);
  const documatic = [];
  if (held !== null) {
    await page.setRequestInterception(true);
    page.on('request', (request) => {
      if (new URL(request.url()).pathname === PROBE_IMAGE) held.push(request);
      else void request.continue();
    });
  }
  page.on('request', (request) => {
    if (new URL(request.url()).pathname.startsWith('/csp/documatic/')) documatic.push(request.url());
  });
  await page.waitForSelector('pre[data-ocu-source="text"]', { timeout: config.navigationTimeoutMs });
  await page.click('[data-ocu-source-view="reference"]');
  await page.waitForSelector(FRAME, { timeout: config.navigationTimeoutMs });
  const frame = await (await page.$(FRAME)).contentFrame();
  await until(() => frame.title(), VENDOR_TITLE, 'the frame shows the class page');
  if (held === null) {
    await until(() => frame.evaluate(() => document.readyState), 'complete', 'the class page has loaded');
    await until(() => page.$eval(FRAME, (node) => node.hasAttribute('inert')), false, 'the page has counted its load and the frame is interactive');
  }
  return { context, page, frame, documatic };
}

test('AC1, AC2: Class reference shows the class page in an inert frame, signed in by the browser-level login alone, out of reach of the tab storage', async () => {
  const { context, page, frame, documatic } = await onClassReference();
  try {
    // Mutation (Rule 19): the page appends the tab's access token to the frame's address -> this goes red.
    const pair = await page.evaluate((key) => JSON.parse(sessionStorage.getItem(key) ?? 'null'), PAIR_STORAGE_KEY);
    const tokens = [pair?.accessToken, pair?.refreshToken];
    assert.ok(tokens.every((token) => typeof token === 'string' && token.length > 16), 'the tab holds its token pair');
    assert.ok(documatic.length > 0, `the class page was requested: ${JSON.stringify(documatic)}`);
    for (const url of documatic) {
      const address = decodeURIComponent(url);
      for (const token of tokens) assert.ok(!url.includes(token) && !address.includes(token), `no token is in its address: ${url}`);
    }
    // Mutation (Rule 19): `classReferenceUrl` drops `PAGE=CLASS&SHOWCLASSONLY=1` -> the frame loads the
    // frameset, whose inner frames ask for a sign-in, and this goes red.
    assert.equal(await page.$eval(FRAME, (node) => node.getAttribute('src')), REFERENCE_PATH, 'the class page alone, for the class and namespace on screen');
    const text = await frame.evaluate(() => document.body.innerText);
    assert.ok(text.includes(`persistent class ${CLASS} extends %Persistent`), `the vendor page names the class: ${text.slice(0, 200)}`);
    assert.ok(text.includes(PROBE_TEXT), 'and shows its description');

    // Mutation (Rule 19): the template's `sandbox=""` becomes `sandbox="allow-scripts allow-same-origin"`
    // -> the description's script runs and the frame reads the tab's storage, and this goes red.
    assert.equal(await frame.evaluate(() => typeof window.ocuprobe199), 'undefined', "the description's script did not run");
    const reach = await frame.evaluate(() => {
      try {
        return `read ${window.top.sessionStorage.length}`;
      } catch (error) {
        return error.name;
      }
    });
    assert.equal(reach, 'SecurityError', "the tab's storage is out of the frame's reach");
    assert.equal(await page.$eval(FRAME, (node) => node.getAttribute('sandbox')), '', 'sandboxed with no flag');
  } finally {
    await context.close();
  }
});

test('AC3: a link followed inside the frame is replaced by the class page again, and the status line says so', async () => {
  const { context, page, frame } = await onClassReference();
  try {
    assert.equal(await page.$eval(STATUS, (node) => node.textContent.trim()), '', 'the status line opens empty');
    // A fragment link is a navigation within the page, which fires no `load`, so it is left alone.
    const fragment = await frame.$('a[href^="#"]');
    assert.ok(fragment !== null, 'the class page holds a fragment link');
    await fragment.click();
    await until(() => frame.url().includes('#'), true, 'the frame moves to the fragment');
    await new Promise((resolve) => setTimeout(resolve, 500));
    assert.equal(await page.$eval(STATUS, (node) => node.textContent.trim()), '', 'a fragment link restores nothing');
    assert.ok(frame.url().startsWith(`${config.origin}${REFERENCE_PATH}#`), `and the frame stays at the fragment: ${frame.url()}`);
    const link = await frame.$('a[href*="CLASSNAME=%25Library.Persistent"]');
    assert.ok(link !== null, 'the class page links its superclass');
    await link.click();
    // Mutation (Rule 19): the load counter treats every load as the page's own -> the sign-in page
    // stays in the frame and the status line stays empty, and this goes red.
    const restored = STRINGS.explorerClassReferenceRestored.replace('<class>', CLASS);
    await until(() => page.$eval(STATUS, (node) => node.textContent.trim()), restored, 'the status line names the class shown again');
    const current = await (await page.$(FRAME)).contentFrame();
    await until(() => current.title(), VENDOR_TITLE, 'the frame shows the class page again, not the sign-in page');
    assert.equal(current.url(), `${config.origin}${REFERENCE_PATH}`);
  } finally {
    await context.close();
  }
});

test('AC3: no link inside the frame can be followed before the class page has loaded', async () => {
  const held = [];
  const { context, page, frame } = await onClassReference(held);
  try {
    await until(() => held.length, 1, "the probe's image is held");
    assert.equal(await frame.evaluate(() => document.readyState), 'interactive', 'the class page is shown and its load is pending');
    // Mutation (Rule 19): the frame is not made `inert` while the page's own load is pending -> the link
    // cancels that load, its sign-in page is counted as the page's own load and stays, and this goes red.
    assert.equal(await page.$eval(FRAME, (node) => node.hasAttribute('inert')), true, 'the frame is inert while its load is pending');
    await (await frame.$('a[href*="CLASSNAME=%25Library.Persistent"]')).click();
    await new Promise((resolve) => setTimeout(resolve, 1500));
    const current = await (await page.$(FRAME)).contentFrame();
    assert.equal(current.url(), `${config.origin}${REFERENCE_PATH}`, 'the link was not followed');
    assert.equal(await current.title(), VENDOR_TITLE);
    await held[0].respond({ status: 404, body: '' });
    await until(() => page.$eval(FRAME, (node) => node.hasAttribute('inert')), false, 'the frame is interactive once its load answers');
    assert.equal(await page.$eval(STATUS, (node) => node.textContent.trim()), '', 'its own load restores nothing');
  } finally {
    await context.close();
  }
});

test('AC6: the view is a toggle button, the frame is named for the class and reached by Tab, the status line is a live region, and the view walks clean', async () => {
  const { context, page } = await onClassReference();
  try {
    const control = await page.$eval('[data-ocu-source-view="reference"]', (node) => ({
      tag: node.tagName,
      pressed: node.getAttribute('aria-pressed'),
      label: node.textContent.trim(),
    }));
    assert.deepEqual(control, { tag: 'BUTTON', pressed: 'true', label: STRINGS.explorerViewClassReference });
    // Mutation (Rule 19): the frame's `title` binding is removed -> the frame has no name and this goes red.
    const handle = await page.$(FRAME);
    const node = await page.accessibility.snapshot({ root: handle, interestingOnly: false });
    assert.equal(node?.name, STRINGS.explorerClassReferenceTitle.replace('<class>', CLASS), `the frame's accessible name: ${JSON.stringify(node)}`);
    assert.equal(await page.$eval(STATUS, (status) => status.getAttribute('role')), 'status');

    await page.focus('[data-ocu-source-view="reference"]');
    let reached = false;
    for (let press = 0; press < 8 && !reached; press += 1) {
      await page.keyboard.press('Tab');
      reached = await page.evaluate((selector) => document.activeElement === document.querySelector(selector), FRAME);
    }
    assert.ok(reached, 'Tab reaches the frame from the view control');

    await page.focus('[data-ocu-source-view="reference"]');
    assert.deepEqual(await structural(page, `${CLASS_VIEWER_ROUTE}/:id`), [], 'Class reference adds no structural entry');
  } finally {
    await context.close();
  }
});

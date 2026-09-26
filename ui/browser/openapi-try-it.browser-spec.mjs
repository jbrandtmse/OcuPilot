/**
 * Story 16.1 in a real browser, against the throwaway instance: the try-it console on the OpenAPI
 * document viewer (AD-57).
 *
 * What it pins, each on rendered DOM and on the wire the page itself produced:
 *
 * 1. `/api/admin`'s `GET /v2/web-apps` is sent from the browser with the tab's own Bearer, no cookie,
 *    and its 200 and JSON body render as text on the code surface; the page passes DW-1337 in both
 *    themes with the console and its answer open, against the viewer's existing allowance alone.
 * 2. `/api/mgmnt`'s `GET /v2/` is sent and its 401 is shown as the round trip's answer.
 * 3. A `DELETE` on `/api/mgmnt` opens the confirmation dialog, which passes DW-1337; Cancel sends
 *    nothing.
 * 4. A `DELETE` in `/api/admin`'s document offers no Send and shows the admin-write refusal.
 * 5. `/api/ocupilot`'s document offers no Send on any operation of the path opened.
 *
 * **It sends reads only.** No mutating request is ever sent: the one write it composes is cancelled,
 * and the refused ones have no Send. Refuses the live container.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test
 * browser/openapi-try-it.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));
const { encodeEntityId } = await import(join(uiRoot, 'src', 'app', 'core', 'entity-id.ts'));
const { MASKED_VALUE } = await import(join(uiRoot, 'src', 'app', 'core', 'proposal-view.ts'));

const config = browserConfig();
const VIEWER_PATH = '/ocupilot/web-applications/rest-apis/document/';
const VIEWER_ROUTE = 'web-applications/rest-apis/document/:id';

let browser = null;

before(async () => {
  await assertThrowaway(config);
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
});

/**
 * Signed in on `application`'s document, with every request the page issues recorded. `sentHeaders` holds
 * the headers each request actually carried, by request id, from CDP's `requestWillBeSentExtraInfo`:
 * Puppeteer's `request.headers()` is read before the network stack attaches cookies.
 */
async function atDocument(application) {
  const { context, page } = await signedInAt(browser, config, `${VIEWER_PATH}${encodeEntityId(application)}?ns=HSCUSTOM`);
  const requests = [];
  const sentHeaders = new Map();
  const cdp = await page.createCDPSession();
  cdp.on('Network.requestWillBeSentExtraInfo', (event) => sentHeaders.set(event.requestId, event.headers));
  await cdp.send('Network.enable');
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (!url.pathname.startsWith('/api/ocupilot')) requests.push({ id: request.id, method: request.method(), path: url.pathname + url.search, headers: request.headers() });
  });
  await page.waitForSelector('[data-ocu-openapi="path"]', { timeout: config.navigationTimeoutMs });
  return { context, page, requests, sentHeaders };
}

/** Open the path disclosure reading `path`, then the Try it console of its operation whose verb chip reads `verb`. */
async function openConsole(page, path, verb) {
  const opened = await page.evaluate((wanted) => {
    const button = Array.from(document.querySelectorAll('[data-ocu-openapi="path"]')).find((node) => node.textContent.trim() === wanted);
    button?.click();
    return button !== undefined;
  }, path);
  assert.equal(opened, true, `the document lists ${path}`);
  await page.waitForSelector('[data-ocu-openapi="operation"]', { timeout: config.navigationTimeoutMs });
  const index = await page.evaluate((wanted) => {
    const sections = Array.from(document.querySelectorAll('[data-ocu-openapi="operation"]'));
    const at = sections.findIndex((section) => section.querySelector('[data-ocu-openapi="verb"]')?.textContent.trim() === wanted);
    sections[at]?.querySelector('[data-ocu-try-it="toggle"]')?.click();
    return at;
  }, verb);
  assert.ok(index >= 0, `${path} declares ${verb}`);
  await page.waitForSelector('[data-ocu-try-it="console"]', { timeout: config.navigationTimeoutMs });
  return `[data-ocu-openapi="operation"]:nth-of-type(${index + 1})`;
}

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/**
 * DW-1337 on the viewer as it stands: 1280 light (every invariant), 720 light and 1280 dark, against
 * the viewer route's own baseline entries and nothing more.
 */
async function assertStructure(page) {
  const allowance = (readBaseline()?.entries ?? []).filter((entry) => entry.route === VIEWER_ROUTE);
  const passes = [
    { viewport: VIEWPORTS.wide, theme: 'light', checks: INVARIANTS },
    { viewport: VIEWPORTS.narrow, theme: 'light', checks: ['name', 'min-width', 'overflow'] },
    { viewport: VIEWPORTS.wide, theme: 'dark', checks: ['contrast'] },
  ];
  const minimums = componentMinimums();
  const found = [];
  const surfaces = {};
  for (const { viewport, theme, checks } of passes) {
    await page.setViewport(viewport);
    await page.evaluate((dark) => document.documentElement.classList.toggle('ocu-theme-dark', dark), theme === 'dark');
    await frames(page);
    await page.waitForFunction(
      () => document.getAnimations().every((animation) => !(animation instanceof CSSTransition) || animation.playState !== 'running'),
      { timeout: config.navigationTimeoutMs }
    );
    surfaces[theme] = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
    const { entries } = await detectScreen(page, { route: VIEWER_ROUTE, checks, viewport: viewport.width, theme, minimums });
    found.push(...entries);
    const sideways = await page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth);
    assert.equal(sideways, false, `the page does not scroll sideways at ${viewport.width}px ${theme}`);
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(config.viewport);
  await frames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme');
  const fresh = compare(collapse(found), allowance).fresh;
  assert.deepEqual(fresh.map((entry) => `${entry.key}: ${entry.measured}`), [], 'no structural or contrast violation with the console open');
}

test('GET /v2/web-apps on /api/admin is sent with the tab\'s Bearer and no cookie, answers 200 as text, and passes DW-1337', async () => {
  const { context, page, requests, sentHeaders } = await atDocument('/api/admin');
  try {
    const operation = await openConsole(page, '/v2/web-apps', 'Get');
    const answered = page.waitForResponse((response) => new URL(response.url()).pathname === '/api/admin/v2/web-apps', { timeout: config.navigationTimeoutMs });
    await page.click(`${operation} [data-ocu-try-it="send"]`);
    const response = await answered;
    assert.equal(response.status(), 200);
    const wire = await response.json();
    await page.waitForSelector(`${operation} [data-ocu-try-it="answer"]`, { timeout: config.navigationTimeoutMs });

    const sent = requests.filter((request) => request.path === '/api/admin/v2/web-apps');
    assert.equal(sent.length, 1, `one request reached the admin API: ${JSON.stringify(sent.map((request) => request.path))}`);
    assert.equal(sent[0].method, 'GET');
    assert.match(sent[0].headers.authorization ?? '', /^Bearer \S+$/, 'the tab\'s access token is the credential');
    const onWire = Object.keys(sentHeaders.get(sent[0].id) ?? {}).map((name) => name.toLowerCase());
    assert.ok(onWire.includes('authorization'), `the headers on the wire were captured: ${JSON.stringify(onWire)}`);
    assert.equal(onWire.includes('cookie'), false, 'no cookie is sent');

    const shown = await page.evaluate((selector) => {
      const pre = document.querySelector(`${selector} [data-ocu-try-it="answer"]`);
      const record = document.querySelector(`${selector} [data-ocu-try-it="record"]`);
      const probe = document.createElement('div');
      probe.style.backgroundColor = 'var(--ocu-code-surface)';
      document.body.appendChild(probe);
      const surface = getComputedStyle(probe).backgroundColor;
      probe.remove();
      return { tag: pre.tagName, text: pre.textContent, record: record.textContent, background: getComputedStyle(pre).backgroundColor, surface, children: pre.children.length };
    }, operation);
    assert.equal(shown.tag, 'PRE');
    assert.equal(shown.children, 0, 'the answer is one text node, never markup');
    assert.ok(shown.text.startsWith('200'), `the status leads the answer: ${shown.text.slice(0, 40)}`);
    assert.ok(shown.text.includes(JSON.stringify(wire, null, 2).slice(0, 200)), 'the body is the JSON the wire carried, pretty-printed');
    assert.equal(shown.background, shown.surface, 'on the code surface');
    assert.ok(shown.record.includes(`Authorization: ${MASKED_VALUE}`), `the record masks the Bearer: ${shown.record}`);
    assert.equal(shown.record.includes(sent[0].headers.authorization.slice(7)), false, 'and never holds the token');

    await assertStructure(page);
  } finally {
    await context.close();
  }
});

test('GET /v2/ on /api/mgmnt, a password application without JWT, is sent and its 401 is the answer shown', async () => {
  const { context, page } = await atDocument('/api/mgmnt');
  try {
    const operation = await openConsole(page, '/v2/', 'Get');
    await page.click(`${operation} [data-ocu-try-it="send"]`);
    await page.waitForSelector(`${operation} [data-ocu-try-it="answer"]`, { timeout: config.navigationTimeoutMs });
    const text = await page.$eval(`${operation} [data-ocu-try-it="answer"]`, (pre) => pre.textContent);
    assert.ok(text.startsWith('401'), `the answer is the 401: ${text.slice(0, 60)}`);
  } finally {
    await context.close();
  }
});

test('a DELETE on /api/mgmnt asks first in a dialog that passes DW-1337, and Cancel sends nothing', async () => {
  const { context, page, requests } = await atDocument('/api/mgmnt');
  try {
    const operation = await openConsole(page, '/v2/{namespace}/{applicationName}', 'Delete');
    await page.click(`${operation} [data-ocu-try-it="send"]`);
    await page.waitForSelector('[role="dialog"]', { timeout: config.navigationTimeoutMs });
    const heading = await page.$eval('[role="dialog"] .ocu-dialog-title', (node) => node.textContent.trim());
    assert.equal(heading, STRINGS.tryItConfirmTitle.replace('<VERB>', 'DELETE').replace('<URL>', `${config.origin}/api/mgmnt/v2//`));
    await assertStructure(page);
    await page.click('[role="dialog"] .ocu-dialog-actions button');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await frames(page);
    assert.deepEqual(requests.filter((request) => request.path.startsWith('/api/mgmnt')), [], 'nothing reached the management API');
    assert.equal(await page.$(`${operation} [data-ocu-try-it="answer"]`), null);
  } finally {
    await context.close();
  }
});

test('a DELETE in /api/admin\'s document offers no Send and shows the admin-write refusal', async () => {
  const { context, page } = await atDocument('/api/admin');
  try {
    const operation = await openConsole(page, '/v2/web-app', 'Delete');
    assert.equal(await page.$(`${operation} [data-ocu-try-it="send"]`), null);
    assert.equal(await page.$eval(`${operation} [data-ocu-try-it="refusal"]`, (node) => node.textContent.trim()), STRINGS.tryItAdminWrite);
    await assertStructure(page);
  } finally {
    await context.close();
  }
});

test('/api/ocupilot\'s document offers no Send on any operation of the path opened', async () => {
  const { context, page } = await atDocument('/api/ocupilot');
  try {
    await page.click('[data-ocu-openapi="path"]');
    await page.waitForSelector('[data-ocu-try-it="toggle"]', { timeout: config.navigationTimeoutMs });
    await page.evaluate(() => {
      for (const toggle of document.querySelectorAll('[data-ocu-try-it="toggle"]')) toggle.click();
    });
    await page.waitForSelector('[data-ocu-try-it="console"]', { timeout: config.navigationTimeoutMs });
    const consoles = await page.$$eval('[data-ocu-try-it="console"]', (nodes) =>
      nodes.map((node) => ({ send: node.querySelector('[data-ocu-try-it="send"]') !== null, refusal: node.querySelector('[data-ocu-try-it="refusal"]')?.textContent.trim() ?? '' }))
    );
    assert.ok(consoles.length > 0);
    assert.equal(consoles.length, await page.$$eval('[data-ocu-openapi="operation"]', (nodes) => nodes.length), 'every operation of the path has its console open');
    assert.deepEqual(consoles.filter((entry) => entry.send || entry.refusal !== STRINGS.tryItOwnApplication), [], 'every console refuses');
  } finally {
    await context.close();
  }
});

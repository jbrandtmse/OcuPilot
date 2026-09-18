/**
 * The REST API explorer and the OpenAPI document viewer in a real browser, against the throwaway
 * instance (Story 6.1): the explorer as the Web applications area's second side-bar entry and its
 * name cell opening the viewer, which is never listed; the viewer's closed path disclosures, verb
 * chips and Raw view on the code surface with its own scroll; the management API's refused service
 * rendered as the refusal it gave; and a namespace switch re-reading the explorer.
 *
 * **It issues reads only.** It creates no principal and runs nothing inside the container; the denial
 * legs are `OcuPilot.Test.MgmntPortDenial`'s, over HTTP with real principals. The read answers it
 * compares against are the ones the page itself received, captured off the wire.
 *
 * Run: `npm run test:browser` (after `npm run build` and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { clickRowCentre, filterToSubset, viewCount, waitForRows } from './list-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));
const { encodeEntityId } = await import(join(uiRoot, 'src', 'app', 'core', 'entity-id.ts'));

const config = browserConfig();
const EXPLORER_URL = '/ocupilot/web-applications/rest-apis?ns=HSCUSTOM';
const VIEWER_PATH = '/ocupilot/web-applications/rest-apis/document/';
const OCUPILOT_API = '/api/ocupilot';
const REFUSED_SERVICE = '%Api.InteropEditors.v7';
const READ_PREFIX = '/api/ocupilot/screens/';

let browser = null;

before(async () => {
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
});

/**
 * A fresh context signed in through the shell's own form at `url`, with every screen read's URL
 * recorded and every screen read's JSON answer captured, newest last.
 */
async function signedInAt(url) {
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  const reads = [];
  const answers = [];
  page.on('request', (request) => {
    const parsed = new URL(request.url());
    if (parsed.pathname.startsWith(READ_PREFIX)) reads.push(parsed.pathname + parsed.search);
  });
  page.on('response', async (response) => {
    const parsed = new URL(response.url());
    if (!parsed.pathname.startsWith(READ_PREFIX) || response.request().method() !== 'GET') return;
    try {
      answers.push({ path: parsed.pathname + parsed.search, status: response.status(), body: await response.json() });
    } catch {
      // A body that is not JSON is not a read answer this spec compares against.
    }
  });
  await page.goto(`${config.origin}${url}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', config.username);
  await page.type('#ocu-signin-password', config.password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, url);
  return { context, page, reads, answers };
}

/** The newest captured answer whose path starts with `prefix`. */
async function answerFor(page, answers, prefix) {
  for (let attempt = 0; attempt < 100; attempt += 1) {
    const found = [...answers].reverse().find((answer) => answer.path.startsWith(prefix));
    if (found !== undefined) return found;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error(`no read answer for ${prefix} was captured`);
}

/** The side bar's entry labels, opening it first when it is closed. */
async function sideBarLabels(page) {
  if ((await page.$('app-side-bar nav.ocu-side-bar')) === null) {
    await page.keyboard.down('Control');
    await page.keyboard.press('b');
    await page.keyboard.up('Control');
  }
  await page.waitForSelector('app-side-bar nav.ocu-side-bar', { timeout: config.navigationTimeoutMs });
  return page.$$eval('app-side-bar .ocu-side-bar-item .ocu-side-bar-label', (labels) =>
    labels.map((label) => label.textContent.trim())
  );
}

test('the explorer is the second side-bar entry, and its /api/ocupilot name cell opens the unlisted document viewer', async () => {
  const { context, page, reads } = await signedInAt(EXPLORER_URL);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const labels = await sideBarLabels(page);
    assert.deepEqual(labels.slice(0, 2), [STRINGS.webAppListLabel, STRINGS.restApiListLabel], 'REST API explorer is the area\'s second entry');
    assert.equal(labels.includes(STRINGS.openApiViewerLabel), false, 'and the document viewer is never listed');
    assert.ok(reads.some((read) => read.startsWith(`${READ_PREFIX}webapp.restapis/read?`) && read.includes('ns=HSCUSTOM')), `the explorer was read in HSCUSTOM: ${JSON.stringify(reads)}`);

    await filterToSubset(page, { text: 'OcuPilot.Api.Router', expectRow: OCUPILOT_API, total: await viewCount(page), timeoutMs: config.navigationTimeoutMs });
    await clickRowCentre(page, { text: OCUPILOT_API, link: true });
    const wanted = `${VIEWER_PATH}${encodeEntityId(OCUPILOT_API)}`;
    assert.equal(wanted, '/ocupilot/web-applications/rest-apis/document/%252Fapi%252Focupilot');
    await page.waitForFunction((path) => window.location.pathname === path, { timeout: config.navigationTimeoutMs }, wanted);
    assert.equal(new URL(page.url()).search, '?ns=HSCUSTOM', 'the viewer keeps the namespace scope');
    await page.waitForSelector('[data-ocu-openapi="path"]', { timeout: config.navigationTimeoutMs });
    assert.equal((await sideBarLabels(page)).includes(STRINGS.openApiViewerLabel), false, 'and the viewer is still not listed once open');
  } finally {
    await context.close();
  }
});

test('the viewer shows closed path disclosures in document order, sentence-case verb chips on one token pair, and Raw scrolling in its own block', async () => {
  const url = `${VIEWER_PATH}${encodeEntityId(OCUPILOT_API)}?ns=HSCUSTOM`;
  const { context, page, answers } = await signedInAt(url);
  try {
    await page.waitForSelector('[data-ocu-openapi="path"]', { timeout: config.navigationTimeoutMs });
    const answer = await answerFor(page, answers, `${READ_PREFIX}webapp.openapi/read?`);
    assert.equal(answer.status, 200);
    assert.ok(answer.path.includes('ns=HSCUSTOM'), `the document is read in the route's namespace: ${answer.path}`);
    const expectedPaths = [];
    for (const row of [...answer.body.rows].sort((a, b) => a.Order - b.Order)) {
      if (!expectedPaths.includes(row.Path)) expectedPaths.push(row.Path);
    }
    assert.deepEqual(expectedPaths, Object.keys(answer.body.document.paths), 'the answer\'s rows follow the document\'s own path order');

    const disclosures = await page.$$eval('[data-ocu-openapi="path"]', (buttons) =>
      buttons.map((button) => ({ text: button.textContent.trim(), expanded: button.getAttribute('aria-expanded') }))
    );
    assert.deepEqual(disclosures.map((entry) => entry.text), expectedPaths, 'paths render in document order');
    assert.ok(disclosures.every((entry) => entry.expanded === 'false'), 'every path starts closed');

    const withParameters = expectedPaths.findIndex((path) => {
      const operations = answer.body.rows.filter((row) => row.Path === path);
      return operations.length >= 2 && operations.some((row) => row.Parameters.length > 0 && row.Responses.length > 0);
    });
    assert.ok(withParameters >= 0, 'the document has a path with two or more operations, one carrying parameters and responses');
    const toggles = await page.$$('[data-ocu-openapi="path"]');
    await toggles[withParameters].click();
    await page.waitForSelector('[data-ocu-openapi="operation"]', { timeout: config.navigationTimeoutMs });
    const opened = await page.evaluate((index) => {
      const button = document.querySelectorAll('[data-ocu-openapi="path"]')[index];
      const chips = Array.from(document.querySelectorAll('[data-ocu-openapi="verb"]'));
      const styles = chips.map((chip) => {
        const style = getComputedStyle(chip);
        return `${style.backgroundColor}|${style.color}`;
      });
      const probe = document.createElement('span');
      probe.style.backgroundColor = 'var(--ocu-secondary-container)';
      probe.style.color = 'var(--ocu-on-secondary-container)';
      document.body.appendChild(probe);
      const tokens = `${getComputedStyle(probe).backgroundColor}|${getComputedStyle(probe).color}`;
      probe.remove();
      return {
        tokens,
        expanded: button.getAttribute('aria-expanded'),
        verbs: chips.map((chip) => chip.textContent.trim()),
        pairs: [...new Set(styles)],
        parameters: document.querySelectorAll('[data-ocu-openapi="parameters"] li').length,
        responses: document.querySelectorAll('[data-ocu-openapi="responses"] li').length,
      };
    }, withParameters);
    const rowsOfPath = answer.body.rows.filter((row) => row.Path === expectedPaths[withParameters]).sort((a, b) => a.Order - b.Order);
    assert.equal(opened.expanded, 'true', 'the opened path reads expanded');
    assert.deepEqual(opened.verbs, rowsOfPath.map((row) => row.Verb.charAt(0).toUpperCase() + row.Verb.slice(1).toLowerCase()), 'its verbs render in sentence case');
    assert.ok(opened.verbs.length >= 2, `the opened path carries two or more verb chips: ${JSON.stringify(opened.verbs)}`);
    assert.equal(opened.pairs.length, 1, `every verb chip shares one token pair: ${JSON.stringify(opened.pairs)}`);
    assert.equal(opened.pairs[0], opened.tokens, 'and that pair is secondary-container / on-secondary-container');
    assert.equal(opened.parameters, rowsOfPath.reduce((sum, row) => sum + row.Parameters.length, 0), 'each operation lists its parameters');
    assert.equal(opened.responses, rowsOfPath.reduce((sum, row) => sum + row.Responses.length, 0), 'and its response codes');

    await page.click('[data-ocu-openapi="raw-toggle"]');
    await page.waitForSelector('[data-ocu-openapi="raw"]', { timeout: config.navigationTimeoutMs });
    const raw = await page.evaluate(() => {
      const pre = document.querySelector('[data-ocu-openapi="raw"]');
      const probe = document.createElement('div');
      probe.style.backgroundColor = 'var(--ocu-code-surface)';
      probe.style.color = 'var(--ocu-on-code-surface)';
      document.body.appendChild(probe);
      const surface = getComputedStyle(probe).backgroundColor;
      const onSurface = getComputedStyle(probe).color;
      probe.remove();
      const style = getComputedStyle(pre);
      return {
        pressed: document.querySelector('[data-ocu-openapi="raw-toggle"]').getAttribute('aria-pressed'),
        text: pre.textContent,
        background: style.backgroundColor,
        surface,
        color: style.color,
        onSurface,
        overflowX: style.overflowX,
        overflowY: style.overflowY,
        scrollsInside: pre.scrollWidth > pre.clientWidth,
        pageScrollsSideways: document.documentElement.scrollWidth > document.documentElement.clientWidth,
      };
    });
    assert.equal(raw.pressed, 'true', 'Raw reads pressed');
    assert.equal(raw.text, JSON.stringify(answer.body.document, null, 2), 'Raw is the whole document, pretty-printed');
    assert.equal(raw.background, raw.surface, 'on the code surface');
    assert.equal(raw.color, raw.onSurface, 'in its on-code-surface text color');
    assert.equal(raw.overflowX, 'auto');
    assert.equal(raw.overflowY, 'auto');
    assert.equal(raw.scrollsInside, true, 'the document is wider than its block, which scrolls inside itself');
    assert.equal(raw.pageScrollsSideways, false, 'while the page does not scroll horizontally');
  } finally {
    await context.close();
  }
});

test('in %SYS, the refused vendor service shows the refusal the instance wrote, with no path browser and no empty state', async () => {
  const { context, page, answers } = await signedInAt('/ocupilot/web-applications/rest-apis?ns=%25SYS');
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await filterToSubset(page, { text: 'InteropEditors.v7', expectRow: REFUSED_SERVICE, total: await viewCount(page), timeoutMs: config.navigationTimeoutMs });
    await clickRowCentre(page, { text: REFUSED_SERVICE, link: true });
    await page.waitForSelector('[data-ocu-openapi="refusal"]', { timeout: config.navigationTimeoutMs });
    const answer = await answerFor(page, answers, `${READ_PREFIX}webapp.openapi/read?`);
    assert.equal(answer.status, 404);
    assert.ok(answer.path.includes('ns=%25SYS'), `the document is read in the route's namespace: ${answer.path}`);
    assert.equal(answer.body.code, 'PORT.NOTFOUND');
    const shown = await page.evaluate(() => ({
      refusal: document.querySelector('[data-ocu-openapi="refusal"]').textContent.trim(),
      paths: document.querySelector('[data-ocu-openapi="paths"]') !== null,
      empty: document.querySelector('[data-ocu-openapi="empty"]') !== null,
      skeleton: document.querySelector('[data-ocu-openapi="skeleton"]') !== null,
    }));
    assert.equal(shown.refusal, answer.body.reason, 'the refusal is the reason the envelope carried');
    assert.equal(shown.refusal, 'The management API refused this document: it reports no REST application by that name.');
    assert.equal(shown.paths, false, 'with no path browser');
    assert.equal(shown.empty, false, 'and no empty state');
    assert.equal(shown.skeleton, false, 'and no skeleton left standing');
  } finally {
    await context.close();
  }
});

test('switching the explorer from HSCUSTOM to %SYS re-reads it, and the spec-based %Api services appear', async () => {
  const { context, page, reads, answers } = await signedInAt(EXPLORER_URL);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const explorerReads = () => reads.filter((read) => read.startsWith(`${READ_PREFIX}webapp.restapis/read?`));
    const before = explorerReads().length;
    await page.click('.ocu-namespace-switch-trigger');
    await page.waitForSelector('.ocu-namespace-switch-option', { timeout: config.navigationTimeoutMs });
    const chose = await page.evaluate(() => {
      const option = Array.from(document.querySelectorAll('.ocu-namespace-switch-option')).find((node) => node.textContent.trim() === '%SYS');
      option?.click();
      return option !== undefined;
    });
    assert.equal(chose, true, 'the namespace switch offers %SYS');
    await page.waitForFunction(() => new URL(window.location.href).searchParams.get('ns') === '%SYS', { timeout: config.navigationTimeoutMs });

    const answer = await answerFor(page, answers, `${READ_PREFIX}webapp.restapis/read?maxRows=1000&ns=%25SYS`);
    assert.ok(explorerReads().length > before, `the switch issued a new explorer read: ${JSON.stringify(explorerReads())}`);
    assert.equal(answer.status, 200);
    const services = answer.body.rows.filter((row) => row.Name.startsWith('%Api.') && row.SpecBased === true);
    assert.ok(services.some((row) => row.Name === REFUSED_SERVICE), 'the %SYS answer carries the spec-based %Api services');
    await page.waitForFunction(
      (wanted) => Number(document.querySelector('[role="grid"]')?.getAttribute('aria-rowcount')) - 1 === wanted,
      { timeout: config.navigationTimeoutMs },
      answer.body.rows.length
    );
    await filterToSubset(page, { text: '%Api.InteropEditors', expectRow: REFUSED_SERVICE, total: await viewCount(page), timeoutMs: config.navigationTimeoutMs });
  } finally {
    await context.close();
  }
});

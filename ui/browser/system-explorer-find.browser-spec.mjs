/**
 * Story 19.4 in a real browser, against the throwaway: a search of the probe needle in `USER` lists
 * each match, and a routine's and a class's hit each open their own viewer, which reads the document
 * through its own declared read (AC1, AC9); Compare draws two probe classes' line diff from the two
 * viewers' reads (AC4); and Macros shows a probe macro's definition in a subclass's context, its
 * "Defined in" opening the include's viewer (AC5, AC9). Each screen passes the structural walk at
 * 1280 light, 720 light and 1280 dark, with no entry beyond the baseline.
 *
 * The probes are `OcuPilot.Test.ExplorerFindProbe`'s, created in `before` and removed in `after` by
 * that class, which names only its own documents. It refuses the live container.
 *
 * Run: `node --test --test-concurrency=1 browser/system-explorer-find.browser-spec.mjs` (after
 * `npm run build`, the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const PROBE = 'OcuPilot.Test.ExplorerFindProbe';
const NEEDLE = 'OcuProbe194Needle';
const SEARCH_ROUTE = 'system-explorer/search';
const COMPARE_ROUTE = 'system-explorer/compare';
const MACROS_ROUTE = 'system-explorer/macros';

let browser = null;

const marker = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates and removes code documents, so it never runs inside the live container');
  await assertThrowaway(config);
  const output = runIris(config.container, [
    `Set tSC=##class(${PROBE}).Remove("USER")`,
    `If tSC Set tSC=##class(${PROBE}).Make("USER")`,
    marker('OK', '$System.Status.IsOK(tSC)'),
  ]);
  assert.equal(markerValue(output, 'OK'), '1', `the probe documents are created in USER: ${output}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  const output = runIris(config.container, [`Set tSC=##class(${PROBE}).Remove("USER")`, marker('OK', '$System.Status.IsOK(tSC)')]);
  assert.equal(markerValue(output, 'OK'), '1', `no probe document is left in USER: ${output}`);
});

function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
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

/** Replace the text of the input `selector` names with `text`. */
async function typeInto(page, selector, text) {
  await page.click(selector, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(selector, text);
}

/** Wait for the source viewer to show text containing `text`, and answer the URL it is at. */
async function viewerShows(page, text) {
  await page.waitForFunction((wanted) => (document.querySelector('pre[data-ocu-source="text"]')?.textContent ?? '').includes(wanted), { timeout: config.navigationTimeoutMs }, text);
  return new URL(page.url()).pathname;
}

/** Run the search of `NEEDLE` on the Search screen in `USER`, answering the documents its hits name. */
async function searchNeedle(page) {
  await page.waitForSelector('[data-ocu-search="text"]', { timeout: config.navigationTimeoutMs });
  await typeInto(page, '[data-ocu-search="text"]', NEEDLE);
  await page.click('[data-ocu-search="submit"]');
  await page.waitForSelector('[data-ocu-search="document"]', { timeout: config.navigationTimeoutMs });
  return page.$$eval('[data-ocu-search="document"]', (links) => links.map((link) => link.textContent.trim()));
}

test("AC1, AC9: a search lists each match, and a routine's and a class's hit each open their own viewer, which reads the document", async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${SEARCH_ROUTE}?ns=USER`, VIEWPORTS.wide);
  try {
    assert.equal(await page.$eval('[data-ocu-search="empty"]', (node) => node.textContent.trim()), STRINGS.explorerSearchInvite, 'the screen opens inviting a search');
    const documents = await searchNeedle(page);
    assert.deepEqual(documents, ['OcuProbe194.Parent.cls', 'OcuProbe194.Parent.cls', 'OcuProbe194.Parent.cls', 'OcuProbe194Mac.mac', 'OcuProbe194Mac.mac'], 'one row per match, in the instance order');
    const locations = await page.$$eval('[data-ocu-search="location"]', (cells) => cells.map((cell) => cell.textContent.trim()));
    assert.deepEqual(locations, ['[Description]', 'Probe+1', 'Marked', '3', '4'], 'each located as the instance answers it');
    assert.deepEqual(await structural(page, SEARCH_ROUTE), [], 'Search with its results adds no structural entry');

    await page.evaluate(() => document.querySelectorAll('[data-ocu-search="document"]')[3].click());
    // Mutation (Rule 19): route every hit to the class viewer -> the routine opens nowhere and this goes red.
    assert.equal(await viewerShows(page, `${NEEDLE} in a routine`), '/ocupilot/system-explorer/routines/document/OcuProbe194Mac%252Emac', 'the routine hit opens the routine viewer, which reads the routine');

    await page.goBack({ waitUntil: 'networkidle2' });
    await searchNeedle(page);
    await page.evaluate(() => document.querySelectorAll('[data-ocu-search="document"]')[0].click());
    assert.match(await viewerShows(page, `${NEEDLE} in a method`), /\/system-explorer\/classes\/document\//, 'and a class hit opens the class viewer');
  } finally {
    await context.close();
  }
});

test("AC4: Compare draws two probe classes' line diff from the viewers' reads", async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${COMPARE_ROUTE}?ns=USER&left=OcuProbe194.Parent.cls`, VIEWPORTS.wide);
  const reads = [];
  page.on('request', (request) => {
    const parsed = new URL(request.url());
    if (parsed.pathname.startsWith('/api/ocupilot/screens/')) reads.push(parsed.pathname + parsed.search);
  });
  try {
    await page.waitForSelector('[data-ocu-compare-side="right"] [data-ocu-compare="name"]', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-ocu-compare-side="left"] [data-ocu-compare="name"]', (input) => input.value), 'OcuProbe194.Parent.cls', 'the first document is prefilled from the link');
    await typeInto(page, '[data-ocu-compare-side="right"] [data-ocu-compare="name"]', 'OcuProbe194.Child.cls');
    await page.click('[data-ocu-compare="submit"]');
    await page.waitForSelector('[data-ocu-compare="diff"]', { timeout: config.navigationTimeoutMs });
    assert.deepEqual(
      reads.filter((path) => path.includes('/read?')).map((path) => path.replace(/maxRows=\d+&/, '')),
      ['/api/ocupilot/screens/explorer.class/read?name=OcuProbe194.Parent.cls&form=udl&ns=USER', '/api/ocupilot/screens/explorer.class/read?name=OcuProbe194.Child.cls&form=udl&ns=USER'],
      "one read per side, through the class viewer's declared read, in USER"
    );
    const lines = await page.$$eval('[data-ocu-diff="removed"], [data-ocu-diff="added"]', (nodes) => nodes.map((node) => `${node.dataset.ocuDiff}:${node.querySelector('.ocu-line-diff-text').textContent}`));
    assert.ok(lines.includes('removed:Include OcuProbe194Inc') && lines.some((line) => line.startsWith('added:Class OcuProbe194.Child')), `the Parent's lines removed and the Child's added: ${JSON.stringify(lines)}`);
    const status = await page.$eval('[data-ocu-compare="status"]', (node) => node.textContent.trim());
    assert.match(status, /^\d+ lines removed \u00b7 \d+ lines added$/, `the one-line result counts both: ${status}`);
    assert.deepEqual(await structural(page, COMPARE_ROUTE), [], 'Compare with its diff adds no structural entry');
  } finally {
    await context.close();
  }
});

test("AC5, AC9: Macros shows a probe macro found through a superclass, and Defined in opens the include's viewer", async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${MACROS_ROUTE}?ns=USER&document=OcuProbe194.Child.cls`, VIEWPORTS.wide);
  try {
    await page.waitForSelector('[data-ocu-macro="macro"]', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-ocu-macro="document"]', (input) => input.value), 'OcuProbe194.Child.cls', 'the document is prefilled from the link');
    await typeInto(page, '[data-ocu-macro="macro"]', '$$$OcuProbe194Value');
    await page.click('[data-ocu-macro="submit"]');
    await page.waitForSelector('[data-ocu-macro="definition"]', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-ocu-macro="definition"]', (node) => node.textContent), 'OcuProbe194Value 42', 'the definition the subclass context resolves');
    const definedIn = await page.$eval('[data-ocu-macro="defined-in"]', (node) => node.textContent.trim());
    assert.equal(definedIn, STRINGS.explorerMacroDefinedIn.replace('<document>', 'OcuProbe194Inc.inc').replace('<n>', '1'));
    assert.deepEqual(await structural(page, MACROS_ROUTE), [], 'Macros with its definition adds no structural entry');
    await page.click('[data-ocu-macro="defined-in"]');
    assert.equal(await viewerShows(page, '#define OcuProbe194Value 42'), '/ocupilot/system-explorer/routines/document/OcuProbe194Inc%252Einc', "Defined in opens the include's viewer, which reads it");
  } finally {
    await context.close();
  }
});

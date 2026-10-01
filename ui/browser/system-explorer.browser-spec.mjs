/**
 * Story 19.1 in a real browser, against the throwaway instance: System Explorer's rail item, Home
 * tile and command-box aliases (AC4); the Classes list opening on the classic defaults (AC1); the
 * class and routine viewers' header and five views, each text view a re-read with its form (AC2);
 * and the four screens' structural and contrast checks at 1280 light, 720 light and 1280 dark, with
 * no entry beyond the baseline (DW-1337).
 *
 * **It issues reads only.** It creates nothing on the instance; the denial legs are
 * `OcuPilot.Test.AtelierPortDenial`'s, over the port with real principals.
 *
 * Run: `node --test --test-concurrency=1 browser/system-explorer.browser-spec.mjs` (after
 * `npm run build`, the bundle copied into the throwaway, and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { resetRememberedState } from './preferences-reset.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { encodeEntityId } = await import(join(uiRoot, 'src', 'app', 'core', 'entity-id.ts'));

const config = browserConfig();
const STRINGS = loadStrings();
const CLASSES_ROUTE = 'system-explorer/classes';
const ROUTINES_ROUTE = 'system-explorer/routines';
const CLASS_VIEWER_ROUTE = 'system-explorer/classes/document';
const ROUTINE_VIEWER_ROUTE = 'system-explorer/routines/document';
const CLASS = 'OcuPilot.Port.AtelierPort.cls';
const ROUTINE = 'HS.HC.Info.mac';
const READ_PREFIX = '/api/ocupilot/screens/';

let browser = null;

before(async () => {
  await assertThrowaway(config);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
});

function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/** Signed in through the shell's own form at `url`, every screen read's path and query recorded from the start. */
async function at(url) {
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  await page.setViewport(VIEWPORTS.wide);
  const reads = [];
  page.on('request', (request) => {
    const parsed = new URL(request.url());
    if (parsed.pathname.startsWith(READ_PREFIX)) reads.push(parsed.pathname + parsed.search);
  });
  await page.goto(`${config.origin}${url}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', config.username);
  await page.type('#ocu-signin-password', config.password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, url);
  return { context, page, reads };
}

/** Wait until `predicate` holds over the recorded reads. */
async function readsUntil(reads, predicate, what) {
  for (let attempt = 0; attempt < 100; attempt += 1) {
    if (predicate(reads)) return;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  assert.fail(`${what}: ${JSON.stringify(reads)}`);
}

/** The structural walk of the screen on display at three passes, answering entries outside the baseline. */
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

/** Click view `key` of the viewer on display. */
async function view(page, key) {
  await page.click(`[data-ocu-source-view="${key}"]`);
  await page.waitForFunction((k) => document.querySelector(`[data-ocu-source-view="${k}"]`)?.getAttribute('aria-pressed') === 'true', {}, key);
}

test('AC4: System Explorer is the eighth rail item with its own icon, Home draws its tile, and the command box finds both lists', async () => {
  const { context, page } = await at('/ocupilot/?ns=HSCUSTOM');
  try {
    await page.waitForSelector('.ocu-area-tile', { timeout: config.navigationTimeoutMs });
    const rail = await page.$$eval('.ocu-rail-item', (items) =>
      items.map((item) => ({ label: item.getAttribute('aria-label'), shapes: item.querySelectorAll('svg > *').length }))
    );
    assert.equal(rail.length, 9, `nine rail items: ${JSON.stringify(rail)}`);
    assert.equal(rail[7].label, STRINGS.navAreaSystemExplorer, 'the eighth is System Explorer, after Security and secrets');
    assert.equal(rail[6].label, STRINGS.navAreaSecurity);
    assert.equal(rail[7].shapes, 3, 'drawn with its own three-shape icon');
    const bottom = await page.$eval('.ocu-rail-slot-bottom .ocu-rail-item', (item) => item.getAttribute('aria-label'));
    assert.equal(bottom, STRINGS.navAreaAgent, 'Agent co-pilot stays pinned at the bottom');

    const tiles = await page.$$eval('.ocu-area-tile', (nodes) => nodes.map((node) => node.textContent.replace(/\s+/g, '')));
    assert.equal(tiles.length, 7, `seven tiles: ${JSON.stringify(tiles)}`);
    assert.equal(
      tiles[6],
      `${STRINGS.navAreaSystemExplorer}${STRINGS.explorerClassListLabel}\u00b7${STRINGS.explorerRoutineListLabel}`.replace(/\s+/g, ''),
      'the seventh tile is System Explorer, captioned Classes \u00b7 Routines'
    );

    // Words only an alias carries: neither list's label nor route holds them.
    for (const [alias, label] of [
      ['source code', STRINGS.explorerClassListLabel],
      ['include files', STRINGS.explorerRoutineListLabel],
    ]) {
      await page.click('#ocu-command-box-field', { clickCount: 3 });
      await page.keyboard.press('Backspace');
      await page.type('#ocu-command-box-field', alias);
      await page.waitForSelector('#ocu-command-box-list', { visible: true, timeout: config.navigationTimeoutMs });
      const offered = await page.$$eval('.ocu-command-box-group-screens .ocu-command-box-option-label', (nodes) =>
        nodes.map((node) => node.textContent.trim())
      );
      assert.ok(offered.includes(label), `"${alias}" finds ${label}: ${JSON.stringify(offered)}`);
    }
    await page.keyboard.press('Escape');
  } finally {
    await context.close();
  }
});

test('AC1: the Classes list opens on one default read with the classic defaults shown, and its name cell opens the class viewer', async () => {
  const { context, page, reads } = await at(`/ocupilot/${CLASSES_ROUTE}?ns=HSCUSTOM`);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const opening = reads.filter((read) => read.startsWith(`${READ_PREFIX}explorer.classes/read?`));
    assert.equal(opening.length, 1, `one read on open: ${JSON.stringify(reads)}`);
    assert.doesNotMatch(opening[0], /[?&](pattern|system|generated|mapped|from|to)=/, 'sending no criterion, so the instance applies the defaults');
    const form = await page.evaluate(() => ({
      pattern: document.querySelector('input[data-ocu-criterion="pattern"]')?.value,
      boxes: Array.from(document.querySelectorAll('input[type="checkbox"][data-ocu-criterion]')).map((box) => `${box.dataset.ocuCriterion}=${box.checked}`),
    }));
    assert.deepEqual(form, { pattern: '*', boxes: ['system=false', 'generated=false', 'mapped=true'] });
    const notice = await page.$eval('.ocu-data-table-cap-notice', (element) => element.textContent.trim());
    assert.equal(notice, STRINGS.tableRowCapNotice.replace('<n>', '1,000'), 'HSCUSTOM holds more classes than the cap, so the footer shows the cap notice');

    await page.click('input[data-ocu-criterion="pattern"]', { clickCount: 3 });
    await page.type('input[data-ocu-criterion="pattern"]', 'OcuPilot.Port.*');
    await page.click('.ocu-criteria-controls button[type="submit"]');
    await readsUntil(reads, (all) => all.some((read) => read.includes('pattern=OcuPilot.Port.*')), 'Search sends the pattern');
    await page.waitForFunction(
      (selector, name) => Array.from(document.querySelectorAll(selector)).some((row) => row.textContent.includes(name)),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      CLASS
    );
    const issues = await structural(page, CLASSES_ROUTE);
    assert.deepEqual(issues, [], 'the Classes list adds no structural entry');

    await clickRowCentre(page, { text: CLASS, link: true });
    await page.waitForFunction((path) => location.pathname === path, { timeout: config.navigationTimeoutMs }, `/ocupilot/${CLASS_VIEWER_ROUTE}/${encodeEntityId(CLASS)}`);
    await page.waitForSelector('pre[data-ocu-source="text"]', { timeout: config.navigationTimeoutMs });
  } finally {
    await context.close();
  }
});

test('AC2: the class viewer shows its header and five views, each text view a re-read with its form', async () => {
  const { context, page, reads } = await at(`/ocupilot/${CLASS_VIEWER_ROUTE}/${encodeEntityId(CLASS)}?ns=HSCUSTOM`);
  try {
    await page.waitForSelector('pre[data-ocu-source="text"]', { timeout: config.navigationTimeoutMs });
    const header = await page.$eval('[data-ocu-source="header"]', (node) => node.textContent);
    assert.ok(header.includes(CLASS), `the header names the class: ${header}`);
    assert.ok(header.includes(STRINGS.explorerGenerates), 'and the routines it generates');
    const source = await page.$eval('pre[data-ocu-source="text"]', (node) => ({ text: node.textContent, tabindex: node.getAttribute('tabindex') }));
    assert.ok(source.text.includes('Class OcuPilot.Port.AtelierPort'), 'Source is the UDL text');
    assert.equal(source.tabindex, '0');

    await view(page, 'xml');
    await readsUntil(reads, (all) => all.some((read) => read.includes('form=xml')), 'XML re-reads with form=xml');
    await page.waitForFunction(() => document.querySelector('pre[data-ocu-source="text"]')?.textContent.includes('<Class name="OcuPilot.Port.AtelierPort">'), { timeout: config.navigationTimeoutMs });

    await view(page, 'int');
    await readsUntil(reads, (all) => all.some((read) => read.includes('form=int')), 'Intermediate code re-reads with form=int');
    await page.waitForFunction(() => /^ ?;OcuPilot\.Port\.AtelierPort\.1/m.test(document.querySelector('pre[data-ocu-source="text"]')?.textContent ?? '') || document.querySelector('[data-ocu-source="not-available"]') !== null, { timeout: config.navigationTimeoutMs });

    const before = reads.length;
    await view(page, 'structure');
    await waitForRows(page, config.navigationTimeoutMs);
    const kinds = await page.$$eval(ROW_SELECTOR, (rows) => rows.map((row) => row.querySelector('[role="gridcell"]')?.textContent.trim()));
    assert.equal(kinds[0], 'class', `Structure opens on the class row: ${JSON.stringify(kinds.slice(0, 5))}`);
    assert.ok(kinds.includes('parameter'), 'followed by its members');
    const issues = await structural(page, `${CLASS_VIEWER_ROUTE}/:id`);
    assert.deepEqual(issues, [], 'the class viewer adds no structural entry');

    await view(page, 'documentation');
    await page.waitForSelector('[data-ocu-source="documentation"], [data-ocu-source="no-documentation"]', { timeout: config.navigationTimeoutMs });
    assert.equal(reads.length, before, 'Structure and Documentation read nothing');
  } finally {
    await context.close();
  }
});

test('AC2: the Routines list and the routine viewer, whose Structure says a routine has no class structure', async () => {
  const { context, page, reads } = await at(`/ocupilot/${ROUTINES_ROUTE}?ns=HSCUSTOM`);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const pattern = await page.$eval('input[data-ocu-criterion="pattern"]', (input) => input.value);
    assert.equal(pattern, '*.mac', 'the Routines list opens on *.mac');
    const issues = await structural(page, ROUTINES_ROUTE);
    assert.deepEqual(issues, [], 'the Routines list adds no structural entry');

    await page.goto(`${config.origin}/ocupilot/${ROUTINE_VIEWER_ROUTE}/${encodeEntityId(ROUTINE)}?ns=HSCUSTOM`, { waitUntil: 'networkidle2' });
    await page.waitForSelector('pre[data-ocu-source="text"]', { timeout: config.navigationTimeoutMs });
    await view(page, 'structure');
    const sentence = await page.$eval('[data-ocu-source="no-structure"]', (node) => node.textContent.trim());
    assert.equal(sentence, STRINGS.explorerRoutineNoStructure);
    await view(page, 'source');
    await readsUntil(reads, (all) => all.filter((read) => read.startsWith(`${READ_PREFIX}explorer.routine/read?`)).length >= 2, 'Source re-reads');
    await page.waitForSelector('pre[data-ocu-source="text"]', { timeout: config.navigationTimeoutMs });
    const viewerIssues = await structural(page, `${ROUTINE_VIEWER_ROUTE}/:id`);
    assert.deepEqual(viewerIssues, [], 'the routine viewer adds no structural entry');
  } finally {
    await context.close();
  }
});

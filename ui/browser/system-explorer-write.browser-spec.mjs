/**
 * Story 19.2 in a real browser, against the throwaway: two probe classes checked on the Classes list
 * in `USER` are compiled through the compile dialog, their console lines landing in the output pane
 * in list order (AC1), then deleted through the typed-name dialog by their count, the list
 * re-fetching without them and the instance holding neither (AC2). The compile dialog, the pane and
 * the delete dialog each pass the structural walk at 1280 light, 720 light and 1280 dark, with no
 * entry beyond the baseline (AC9).
 *
 * The probes are `OcuPilot.Test.ExplorerProbe`'s, created in `before` and removed in `after` by that
 * class, which names only its own package. It refuses the live container.
 *
 * Run: `node --test --test-concurrency=1 browser/system-explorer-write.browser-spec.mjs` (after
 * `npm run build`, the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { ROW_SELECTOR, waitForRows } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const ROUTE = 'system-explorer/classes';
const LIST_URL = `/ocupilot/${ROUTE}?ns=USER`;
const ACTION_PATH = '/api/ocupilot/screens/explorer.classes/action';
const PROBE = 'OcuPilot.Test.ExplorerProbe';
const ALPHA = 'OcuProbe192.Alpha.cls';
const BETA = 'OcuProbe192.Beta.cls';

let browser = null;

const marker = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/** Whether `document` is held in `USER`, read in the container. */
function exists(document) {
  const output = runIris(config.container, [marker('HELD', `##class(${PROBE}).Exists("USER","${document}")`)]);
  return markerValue(output, 'HELD');
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates and deletes classes, so it never runs inside the live container');
  await assertThrowaway(config);
  const output = runIris(config.container, [
    `Set tSC=##class(${PROBE}).Remove("USER")`,
    `If tSC Set tSC=##class(${PROBE}).MakeClass("USER","OcuProbe192.Alpha")`,
    `If tSC Set tSC=##class(${PROBE}).MakeClass("USER","OcuProbe192.Beta")`,
    marker('OK', '$System.Status.IsOK(tSC)'),
  ]);
  assert.equal(markerValue(output, 'OK'), '1', `the probe classes are saved in USER: ${output}`);
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

/** Wait until no CSS transition is running, so a contrast read measures the theme it is in. */
function transitionsSettled(page) {
  return page.waitForFunction(
    () => document.getAnimations().every((animation) => !(animation instanceof CSSTransition) || animation.playState !== 'running'),
    { timeout: config.navigationTimeoutMs }
  );
}

/**
 * The walk of the screen on display at three passes, answering entries outside the baseline. A
 * compiled row carries the change highlight, whose background transitions on a theme switch, so
 * each pass waits for transitions to settle.
 */
async function structural(page, dialog = false) {
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
    await transitionsSettled(page);
    surfaces[theme] = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
    const { entries } = await detectScreen(page, { route: ROUTE, checks, viewport: viewport.width, theme, minimums });
    found.push(...entries);
    if (dialog) {
      const body = await page.$eval('.ocu-dialog-body', (element) => ({ scroll: element.scrollWidth, client: element.clientWidth }));
      assert.ok(body.scroll <= body.client, `the dialog body does not scroll sideways at ${viewport.width}px ${theme}: ${JSON.stringify(body)}`);
    }
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await frames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  return compare(collapse(found), readBaseline()?.entries ?? []).fresh.map((entry) => `${entry.key}: ${entry.measured}`);
}

/** The names the list shows, in its order. */
function rowNames(page) {
  return page.$$eval(ROW_SELECTOR, (rows) =>
    rows.map((row) => (row.querySelector('[role="gridcell"] .ocu-data-table-link, [role="gridcell"] .ocu-data-table-text')?.textContent ?? '').trim())
  );
}

/** Check the row whose name reads `name`. */
async function check(page, name) {
  const box = await page.evaluateHandle(
    (selector, wanted) =>
      Array.from(document.querySelectorAll(selector))
        .find((row) => (row.querySelector('[role="gridcell"] .ocu-data-table-link, [role="gridcell"] .ocu-data-table-text')?.textContent ?? '').trim() === wanted)
        ?.querySelector('.ocu-data-table-check') ?? null,
    ROW_SELECTOR,
    name
  );
  await box.click();
  await page.waitForFunction((element) => element.checked === true, { timeout: config.navigationTimeoutMs }, box);
}

/** Press the command bar's action labelled `label`, once it is offered. */
async function commandBar(page, label) {
  await page.waitForFunction(
    (wanted) => Array.from(document.querySelectorAll('.ocu-command-bar-action')).some((button) => button.textContent.trim() === wanted && button.getAttribute('aria-disabled') === null),
    { timeout: config.navigationTimeoutMs },
    label
  );
  await page.evaluate((wanted) => {
    Array.from(document.querySelectorAll('.ocu-command-bar-action')).find((button) => button.textContent.trim() === wanted).click();
  }, label);
}

/** The status line's text once it reads `line`. */
function statusReads(page, line) {
  return page.waitForFunction(
    (wanted) => document.querySelector('[data-explorer-write="status"]')?.textContent.trim() === wanted,
    { timeout: config.navigationTimeoutMs },
    line
  );
}

test('AC1, AC2: two checked probe classes compile one request each with their console in the pane, then delete by their count and leave the list', async () => {
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const posts = [];
  page.on('request', (request) => {
    if (new URL(request.url()).pathname === ACTION_PATH) posts.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await page.click('input[data-ocu-criterion="pattern"]', { clickCount: 3 });
    await page.type('input[data-ocu-criterion="pattern"]', 'OcuProbe192.*');
    await page.click('.ocu-criteria-controls button[type="submit"]');
    await page.waitForFunction(
      (selector, names) => {
        const shown = Array.from(document.querySelectorAll(selector)).map((row) => row.textContent);
        return names.every((name) => shown.some((text) => text.includes(name)));
      },
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      [ALPHA, BETA]
    );
    assert.deepEqual(await rowNames(page), [ALPHA, BETA], 'the two probes, and nothing else');
    await check(page, BETA);
    await check(page, ALPHA);

    // Compile: the dialog opens on the three flags, and the walk covers it.
    await commandBar(page, STRINGS.explorerCompileAction);
    await page.waitForSelector('app-explorer-compile-dialog .ocu-dialog-title', { timeout: config.navigationTimeoutMs });
    const dialog = await page.evaluate(() => ({
      title: document.querySelector('app-explorer-compile-dialog .ocu-dialog-title')?.textContent.trim(),
      flags: Array.from(document.querySelectorAll('input[data-explorer-compile-flag]')).map((box) => `${box.dataset.explorerCompileFlag}=${box.checked}`),
    }));
    assert.deepEqual(dialog, {
      title: STRINGS.explorerCompileTitle.replace('<n>', '2'),
      flags: ['KeepSource=true', 'CompileDependents=false', 'SkipUpToDate=true'],
    });
    assert.deepEqual(await structural(page, true), [], 'the compile dialog adds no structural entry');
    await page.click('[data-explorer-compile-confirm]');
    await statusReads(page, STRINGS.explorerCompileSummary.replace('<done>', '2').replace('<n>', '2').replace('<errors>', '0'));
    assert.deepEqual(
      posts.map((post) => `${post.action} ${post.id} ${JSON.stringify(post.values)}`),
      [ALPHA, BETA].map((name) => `compile ${name} {"KeepSource":"true","CompileDependents":"false","SkipUpToDate":"true"}`),
      'one compile per document, in list order, with the dialog flags'
    );
    const pane = await page.$eval('[data-explorer-write="output"]', (node) => ({
      text: node.textContent,
      tabindex: node.getAttribute('tabindex'),
      label: node.getAttribute('aria-label'),
    }));
    assert.equal(pane.tabindex, '0');
    assert.equal(pane.label, STRINGS.explorerOutputLabel);
    const alphaAt = pane.text.indexOf('OcuProbe192.Alpha');
    const betaAt = pane.text.indexOf('OcuProbe192.Beta');
    assert.ok(alphaAt >= 0 && betaAt > alphaAt, `the console names Alpha before Beta: ${pane.text}`);
    assert.deepEqual(await structural(page), [], 'the list with its output pane adds no structural entry');

    // Delete: the typed-name dialog asks for the count, and the walk covers it.
    await commandBar(page, STRINGS.actionDelete);
    await page.waitForSelector('app-typed-name-dialog .ocu-typed-name-field', { timeout: config.navigationTimeoutMs });
    const consequence = await page.$eval('.ocu-typed-name-consequence', (node) => node.textContent.trim());
    assert.equal(consequence, STRINGS.explorerDeleteSetConsequence.replace('<n>', '2'));
    assert.deepEqual(await structural(page, true), [], 'the delete dialog adds no structural entry');
    await page.type('.ocu-typed-name-field', '2');
    await page.click('app-typed-name-dialog .ocu-button-destructive');
    await statusReads(page, STRINGS.explorerDeleteSummary.replace('<done>', '2').replace('<n>', '2'));
    assert.deepEqual(posts.at(-1), { action: 'delete', id: `${ALPHA},${BETA}` }, 'one delete over the canonical set');
    const lines = await page.$eval('[data-explorer-write="output"]', (node) => node.textContent);
    assert.equal(lines, [ALPHA, BETA].map((name) => STRINGS.explorerDeleteDeleted.replace('<name>', name)).join('\n'));
    await page.waitForFunction(
      (selector, names) => !Array.from(document.querySelectorAll(selector)).some((row) => names.some((name) => row.textContent.includes(name))),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      [ALPHA, BETA]
    );
    assert.equal(exists(ALPHA), '0', 'Alpha is gone from the instance');
    assert.equal(exists(BETA), '0', 'and so is Beta');
  } finally {
    await context.close();
  }
});

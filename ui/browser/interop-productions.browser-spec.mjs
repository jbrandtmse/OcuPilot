/**
 * Story 20.2 in a real browser, against the throwaway instance: Interoperability's four lists and the
 * Productions row actions (AD-5, AD-36, AD-44, AD-53, AD-62).
 *
 * What it pins: in `USER`, whose probe production this spec creates, the side bar lists the area's four
 * screens in order and Productions shows the probe, Stopped; Start sends one request with no dialog and
 * the row then reads Running with the Changed tag; Stop opens the warning dialog stating the published
 * wait, whose Proceed sends one request, after which the row reads Stopped; a second Stop is refused
 * with the published sentence; the command box offers Productions in `USER` and not in `%SYS`, the
 * locator names Interoperability on the route, and in `%SYS` neither the side bar nor the locator names
 * the area, each read once the map has answered; Business processes in `HSCUSTOM` lists rows whose names
 * are document names; and each screen passes the structural and contrast checks at 1280 light, 720 light
 * and 1280 dark, with no entry beyond the baseline (DW-1337).
 *
 * **It compiles and runs a probe production in `USER`** through `OcuPilot.Test.ProductionProbe`, so it
 * runs on a throwaway only; the `after` hook stops the production and removes it, its classes and its
 * messages, whatever the tests answered.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/interop-productions.browser-spec.mjs` (after
 * `npm run build` and the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { signedInAt } from './panel-spec.mjs';
import { sideBarLabels } from './side-bar-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const PROBE = 'OcuPilot.Test.ProductionProbe';
const PRODUCTION = 'OcuPilotProbe.Interop.Production';
const ROUTE = 'interoperability/productions';
const PROCESSES_ROUTE = 'interoperability/processes';
const LIST_URL = `/ocupilot/${ROUTE}?ns=USER`;
const ACTION_PATH = '/api/ocupilot/screens/interop.productions/action';
const CHANGED_ROW = '.ocu-data-table-row-changed';
/** A production started the moment before it is stopped stops Suspended, so Stop waits for the start to settle. */
const SETTLE_MS = 4000;

let browser = null;
let created = false;

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/** The DW-1337 walk of `route` at 1280 light, 720 light and 1280 dark, answering every entry the baseline does not hold. */
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

/** The probe row's cells, or `null`. */
function probeRow(page) {
  return page.evaluate(
    (rowSelector, wanted) => {
      const row = Array.from(document.querySelectorAll(rowSelector)).find((node) => node.textContent.includes(wanted));
      return row === undefined ? null : Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim());
    },
    ROW_SELECTOR,
    PRODUCTION
  );
}

/** Select the probe row, by a cell that is not the name. */
async function selectProbe(page) {
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, PRODUCTION);
  await page.waitForFunction(
    (rowSelector, wanted) => {
      const rows = Array.from(document.querySelectorAll(rowSelector));
      return rows.length === 1 && rows[0].textContent.includes(wanted);
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    PRODUCTION
  );
  await clickRowCentre(page, { index: 0, cell: 2 });
  await page.waitForFunction(
    (rowSelector) => document.querySelector(rowSelector)?.getAttribute('aria-selected') === 'true',
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR
  );
}

/** Open the selected row's menu and click the entry labeled `label`. */
async function rowAction(page, label) {
  await page.click(`${ROW_SELECTOR}[aria-selected="true"] .ocu-data-table-trigger`);
  await page.waitForSelector('[role="menu"]', { timeout: config.navigationTimeoutMs });
  await page.evaluate((wanted) => {
    const items = Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'));
    items.find((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted).click();
  }, label);
}

/** Wait until the probe row reads `status`, carrying the Changed tag when `changed`. */
async function waitForStatus(page, status, changed) {
  await page.waitForFunction(
    (rowSelector, changedSelector, wanted, word, needsChanged) => {
      const row = Array.from(document.querySelectorAll(rowSelector)).find((node) => node.textContent.includes(wanted));
      if (row === undefined) return false;
      const cells = Array.from(row.querySelectorAll('[role="gridcell"]'));
      if (cells[1]?.textContent.trim() !== word) return false;
      return !needsChanged || row.matches(changedSelector);
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    CHANGED_ROW,
    PRODUCTION,
    status,
    changed
  );
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec compiles and runs a probe production, so it runs only in a throwaway; ${config.container} is not one`);
  const removed = probe('PPCLEAN', `$System.Status.IsOK(##class(${PROBE}).Remove())`);
  assert.equal(removed.value, '1', `an earlier run's probe is removed: ${removed.output}`);
  const made = probe('PPMADE', `$System.Status.IsOK(##class(${PROBE}).Create())`);
  assert.equal(made.value, '1', `the probe production is created: ${made.output}`);
  created = true;
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (created && /-ci$/.test(config.container)) {
      const removed = probe('PPGONE', `$System.Status.IsOK(##class(${PROBE}).Remove())_##class(${PROBE}).Gone()`);
      assert.equal(removed.value, '11', `the probe production is stopped and removed: ${removed.output}`);
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

// AC1, AC5. The row's state cell was not mutated in this spec: dropping `Status` from the descriptor's
// `read.fields` is caught by OcuPilot.Test.InteropDescriptor, which the registry's filter check reddens.
test('AC1: the side bar lists the four screens in order, and Productions shows the probe stopped, with its columns', async () => {
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    // The rows can arrive before the map answers for USER, and the side bar and the locator draw
    // Interoperability only after that answer (fail closed).
    await waitForMapAnswered(page, config.navigationTimeoutMs);
    if ((await page.$('app-side-bar nav.ocu-side-bar')) === null) {
      await page.keyboard.down('Control');
      await page.keyboard.press('b');
      await page.keyboard.up('Control');
    }
    await page.waitForSelector('app-side-bar nav.ocu-side-bar', { timeout: config.navigationTimeoutMs });
    const bar = await page.$$eval('.ocu-side-bar-item .ocu-side-bar-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(bar, sideBarLabels('interoperability'), "the area's side bar lists its screens in their declared order");
    const headers = await page.$$eval('.ocu-data-table-header-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(
      headers.slice(0, 4),
      [STRINGS.tableColumnName, STRINGS.taskHistoryColumnStatus, STRINGS.interopProductionColumnLastStarted, STRINGS.interopProductionColumnLastStopped],
      'the declared headers, ahead of the row actions'
    );
    const listed = await probeRow(page);
    assert.ok(listed !== null, 'the probe production is listed');
    assert.deepEqual(listed.slice(0, 2), [PRODUCTION, 'Stopped'], 'configured and stopped');
    const locator = await page.$eval('.ocu-locator-bar', (nav) => nav.textContent);
    assert.ok(locator.includes(STRINGS.navAreaInteroperability), `the locator names the area: ${locator}`);
    assert.deepEqual(await structural(page, ROUTE), [], 'Productions: no violation beyond the baseline\'s entries');
  } finally {
    await context.close();
  }
});

// AC2, AC3. Mutation (Rule 19): make Start's WARNING_CONSEQUENCES entry name a warning, rebuild and
// redeploy -> Start opens a dialog and the no-dialog assertion goes red.
test('AC2, AC3: Start reads Running changed with no dialog; Stop warns, then reads Stopped; a second Stop is refused with the published sentence', async () => {
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const posts = [];
  page.on('request', (request) => {
    if (new URL(request.url()).pathname === ACTION_PATH) posts.push({ method: request.method(), body: request.postData() ?? '' });
  });
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await selectProbe(page);
    await rowAction(page, STRINGS.actionStart);
    await waitForStatus(page, 'Running', true);
    assert.deepEqual(posts.map((post) => JSON.parse(post.body)), [{ action: 'start', id: PRODUCTION }], 'Start sent one request, with no dialog');

    await new Promise((resolve) => setTimeout(resolve, SETTLE_MS));
    await selectProbe(page);
    await rowAction(page, STRINGS.actionStop);
    await page.waitForSelector('app-warning-dialog', { timeout: config.navigationTimeoutMs });
    const opened = await page.evaluate(() => {
      const surface = document.querySelector('[role="dialog"]');
      return {
        title: (surface.querySelector('.ocu-dialog-title')?.textContent ?? '').trim(),
        body: (surface.querySelector('.ocu-warning-consequence')?.textContent ?? '').trim(),
        destructive: surface.querySelector('.ocu-button-destructive') !== null,
      };
    });
    assert.equal(opened.title, STRINGS.actionStop, 'the warning is titled with the verb');
    assert.equal(opened.body, STRINGS.interopStopConsequence, 'and states the published wait');
    assert.equal(opened.destructive, false, 'never a destructive one');
    await page.click('[role="dialog"] .ocu-dialog-actions .ocu-button-primary');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await waitForStatus(page, 'Stopped', false);
    assert.deepEqual(JSON.parse(posts.at(-1).body), { action: 'stop', id: PRODUCTION }, 'Stop sent at Proceed');

    await selectProbe(page);
    await rowAction(page, STRINGS.actionStop);
    await page.waitForSelector('app-warning-dialog', { timeout: config.navigationTimeoutMs });
    await page.click('[role="dialog"] .ocu-dialog-actions .ocu-button-primary');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await page.waitForFunction(
      (sentence) => document.body.textContent.includes(sentence),
      { timeout: config.navigationTimeoutMs },
      STRINGS.interopRefusalNotRunning
    );
  } finally {
    await context.close();
  }
});

// AC5. Each leg types only once the map has answered for its namespace: before that answer
// Interoperability is offered nowhere (fail closed), so USER would offer nothing and %SYS's absence
// would prove nothing.
test('AC5: the command box offers Productions in USER and not in %SYS', async () => {
  for (const [namespace, offered] of [['USER', true], ['%SYS', false]]) {
    const { context, page } = await signedInAt(browser, config, `/ocupilot/?ns=${encodeURIComponent(namespace)}`, VIEWPORTS.wide);
    try {
      await waitForMapAnswered(page, config.navigationTimeoutMs);
      await page.waitForSelector('#ocu-command-box-field', { timeout: config.navigationTimeoutMs });
      await page.click('#ocu-command-box-field');
      await page.type('#ocu-command-box-field', STRINGS.interopProductionsLabel);
      await page.waitForSelector('.ocu-command-box-sheet', { timeout: config.navigationTimeoutMs });
      await page.waitForFunction(() => document.querySelector('.ocu-command-box-count')?.textContent.trim() !== '', { timeout: config.navigationTimeoutMs });
      const labels = await page.$$eval('.ocu-command-box-group-screens .ocu-command-box-option-label', (nodes) => nodes.map((node) => node.textContent.trim()));
      assert.equal(labels.includes(STRINGS.interopProductionsLabel), offered, `${namespace}: Productions is ${offered ? '' : 'not '}offered: ${JSON.stringify(labels)}`);
    } finally {
      await context.close();
    }
  }
});

// AC5. Read only once the map has answered for %SYS, as the command-box leg is; the locator is drawn on
// the route either way, so it must name the screen and not the area.
test('AC5: in %SYS the side bar lists no Interoperability screen and the locator does not name the area', async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${ROUTE}?ns=%25SYS`, VIEWPORTS.wide);
  try {
    await waitForMapAnswered(page, config.navigationTimeoutMs);
    assert.equal(await page.$('#ocu-rail-item-interoperability'), null, '%SYS: the rail draws no Interoperability item');
    if ((await page.$('app-side-bar nav.ocu-side-bar')) === null) {
      await page.keyboard.down('Control');
      await page.keyboard.press('b');
      await page.keyboard.up('Control');
    }
    await frames(page);
    const bar = await page.$$eval('.ocu-side-bar-item .ocu-side-bar-label', (items) => items.map((item) => item.textContent.trim()));
    for (const label of sideBarLabels('interoperability')) {
      assert.ok(!bar.includes(label), `%SYS: the side bar does not list ${label}: ${JSON.stringify(bar)}`);
    }
    const locator = await page.$eval('.ocu-locator-bar', (nav) => nav.textContent);
    assert.ok(locator.includes(STRINGS.interopProductionsLabel), `%SYS: the locator is drawn for the route: ${locator}`);
    assert.ok(!locator.includes(STRINGS.navAreaInteroperability), `%SYS: the locator does not name the area: ${locator}`);
  } finally {
    await context.close();
  }
});

// AC1. Mutation (Rule 19): make InteropPort's `ListClasses` read Ens.Rule.Definition for every
// endpoint -> the processes leg lists no rows and goes red.
test('AC1: Business processes in HSCUSTOM lists the namespace\'s classes by document name, and passes DW-1337', async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${PROCESSES_ROUTE}?ns=HSCUSTOM`, VIEWPORTS.wide);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const first = await page.$eval(`${ROW_SELECTOR}`, (row) => Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim()));
    assert.match(first[0], /\.cls$/, `the first row's name is a document name: ${JSON.stringify(first)}`);
    const headers = await page.$$eval('.ocu-data-table-header-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(headers.slice(0, 2), [STRINGS.tableColumnName, STRINGS.explorerColumnModified], 'its two columns');
    assert.deepEqual(await structural(page, PROCESSES_ROUTE), [], 'Business processes: no violation beyond the baseline\'s entries');
  } finally {
    await context.close();
  }
});

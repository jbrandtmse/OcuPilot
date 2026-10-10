/**
 * Story 20.3 in a real browser, against the throwaway instance: Interoperability's Production items list and
 * its four writes (AD-5, AD-36, AD-44, AD-53, AD-55, AD-62).
 *
 * What it pins: in `USER`, whose probe production this spec creates, the Productions list's name cell opens
 * the Production items list of that production, which lists the probe's two items under the published
 * headers; Disable warns with the published pending-update sentence and, past Proceed, stores the item
 * disabled, and Enable stores it enabled again; Add item opens the dialog, whose item then appears in the list
 * and in the stored configuration; Remove asks for the item's name typed, states what it deletes, and removes
 * it; a refused Add shows the server's sentence in the dialog; and the list passes the structural and
 * contrast checks at 1280 light, 720 light and 1280 dark, with no entry beyond the baseline (DW-1337).
 *
 * **It compiles and writes a probe production in `USER`** through `OcuPilot.Test.ProductionProbe`, so it runs
 * on a throwaway only; the `after` hook removes the production, its classes and its messages, whatever the
 * tests answered. It starts nothing: an item write on a stopped production is stored and saved to the class.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/interop-items.browser-spec.mjs` (after `npm run build` and the
 * bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const PROBE = 'OcuPilot.Test.ProductionProbe';
const CONTROL = 'OcuPilot.Test.InteropItemControl';
const PRODUCTION = 'OcuPilotProbe.Interop.Production';
const OPERATION = 'OcuPilotProbeOp';
const ADDED = 'OcuPilotProbeAdded';
const ROUTE = 'interoperability/productions/items';
const PRODUCTIONS_URL = '/ocupilot/interoperability/productions?ns=USER';
const ACTION_PATH = '/api/ocupilot/screens/interop.items/action';
const ADD_PATH = '/api/ocupilot/interop/items';
const ROW_ID = (name) => `${PRODUCTION}\u0001${name}`;
const NAME_TEXT = '.ocu-data-table-link, .ocu-data-table-text';

let browser = null;
let created = false;

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** The stored `Enabled` of the probe production's item `name`, `''` when it holds none. */
function stored(name) {
  return probe('ITEM', `##class(${CONTROL}).StoredEnabled("${name}")`).value;
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

/** The cells of the row whose name cell reads `name`, or `null`. */
function itemRow(page, name) {
  return page.evaluate(
    (rowSelector, wanted, textSelector) => {
      const row = Array.from(document.querySelectorAll(rowSelector)).find((node) => {
        const cell = node.querySelector('[role="gridcell"]');
        return ((cell?.querySelector(textSelector) ?? cell)?.textContent ?? '').trim() === wanted;
      });
      return row === undefined ? null : Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim());
    },
    ROW_SELECTOR,
    name,
    NAME_TEXT
  );
}

/** Wait until the list holds a row named `name`, or, with `present` false, none. */
function rowPresent(page, name, present = true) {
  return page.waitForFunction(
    (rowSelector, wanted, textSelector, want) =>
      Array.from(document.querySelectorAll(rowSelector)).some((row) => {
        const cell = row.querySelector('[role="gridcell"]');
        return ((cell?.querySelector(textSelector) ?? cell)?.textContent ?? '').trim() === wanted;
      }) === want,
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name,
    NAME_TEXT,
    present
  );
}

/** Wait until the row named `name` reads `word` in its Enabled cell, or, with `equal` false, anything else. */
function waitForEnabledCell(page, name, word, equal = true) {
  return page.waitForFunction(
    (rowSelector, wanted, textSelector, expected, wantEqual) => {
      const row = Array.from(document.querySelectorAll(rowSelector)).find((node) => {
        const cell = node.querySelector('[role="gridcell"]');
        return ((cell?.querySelector(textSelector) ?? cell)?.textContent ?? '').trim() === wanted;
      });
      const cells = row === undefined ? [] : Array.from(row.querySelectorAll('[role="gridcell"]'));
      const text = cells[3]?.textContent.trim();
      return text !== undefined && (text === expected) === wantEqual;
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name,
    NAME_TEXT,
    word,
    equal
  );
}

/** Narrow the list to `name`, select its row, open its menu and choose the entry labeled `label`. */
async function rowAction(page, name, label) {
  await waitForRows(page, config.navigationTimeoutMs);
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, name);
  await rowPresent(page, name);
  // The filter leaves the one row, whose name cell can carry the Changed tag and the read-back note beside the name.
  await clickRowCentre(page, { index: 0, cell: 2 });
  await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
  await page.evaluate((wanted) => {
    Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'))
      .find((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted)
      .click();
  }, label);
}

/** Open the probe production's items from its name cell on the Productions list. */
async function openItems(page) {
  await waitForRows(page, config.navigationTimeoutMs);
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  await clickRowCentre(page, { text: PRODUCTION, link: true });
  await page.waitForFunction((suffix) => new URL(window.location.href).pathname.includes(suffix), { timeout: config.navigationTimeoutMs }, `/${ROUTE}/`);
  await waitForRows(page, config.navigationTimeoutMs);
  await rowPresent(page, OPERATION);
}

/** Type `value` into the add dialog's field `field`. */
async function fill(page, field, value) {
  const selector = `input[data-interop-item-add-${field}]`;
  await page.click(selector, { clickCount: 3 });
  await page.type(selector, value);
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec compiles a probe production, so it runs only in a throwaway; ${config.container} is not one`);
  const removed = probe('PICLEAN', `$System.Status.IsOK(##class(${PROBE}).Remove())`);
  assert.equal(removed.value, '1', `an earlier run's probe is removed: ${removed.output}`);
  const made = probe('PIMADE', `$System.Status.IsOK(##class(${PROBE}).Create())`);
  assert.equal(made.value, '1', `the probe production is created: ${made.output}`);
  created = true;
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (created && /-ci$/.test(config.container)) {
      const removed = probe('PIGONE', `$System.Status.IsOK(##class(${PROBE}).Remove())_##class(${PROBE}).Gone()`);
      assert.equal(removed.value, '11', `the probe production is removed: ${removed.output}`);
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

// AC1. Mutation (Rule 19): drop the `production` criterion's route-id fill by making `childListFor` answer
// null -> the name cell opens nothing and this goes red; rebuild and redeploy first.
test('AC1: the Productions name cell opens the probe production\'s items, under the published headers, and the walk passes', async () => {
  const { context, page } = await signedInAt(browser, config, PRODUCTIONS_URL, VIEWPORTS.wide);
  try {
    await openItems(page);
    const headers = await page.$$eval('.ocu-data-table-header-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(
      headers.slice(0, 7),
      [
        STRINGS.tableColumnName,
        STRINGS.interopItemColumnClass,
        STRINGS.tableColumnType,
        STRINGS.tableColumnEnabled,
        STRINGS.interopItemColumnPoolSize,
        STRINGS.interopItemColumnCategory,
        STRINGS.userFieldComment,
      ],
      'the declared headers, ahead of the row actions'
    );
    const op = await itemRow(page, OPERATION);
    const svc = await itemRow(page, 'OcuPilotProbeSvc');
    assert.ok(op !== null && svc !== null, 'both probe items are listed');
    assert.equal(op[1], 'OcuPilotProbe.Interop.Op', 'the operation reads its class');
    assert.equal(op[2], 'operation', 'and its type');
    assert.equal(svc[2], 'service', 'the service reads its own');
    assert.deepEqual(await structural(page, ROUTE), [], 'Production items: no violation beyond the baseline\'s entries');
  } finally {
    await context.close();
  }
});

// AC2, AC3. Mutation (Rule 19): remove the list's entry from WARNING_CONSEQUENCES, rebuild and redeploy -> Disable
// is sent at once and the dialog assertion goes red.
test('AC2: Disable warns with the pending-update sentence and stores the item disabled; Enable stores it enabled again', async () => {
  const { context, page } = await signedInAt(browser, config, PRODUCTIONS_URL, VIEWPORTS.wide);
  const posts = [];
  page.on('request', (request) => {
    if (new URL(request.url()).pathname === ACTION_PATH) posts.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    await openItems(page);
    const before = (await itemRow(page, OPERATION))[3];
    await rowAction(page, OPERATION, STRINGS.agentDefinitionDisable);
    await page.waitForSelector('app-warning-dialog', { timeout: config.navigationTimeoutMs });
    const opened = await page.evaluate(() => {
      const surface = document.querySelector('[role="dialog"]');
      return {
        title: (surface.querySelector('.ocu-dialog-title')?.textContent ?? '').trim(),
        body: (surface.querySelector('.ocu-warning-consequence')?.textContent ?? '').trim(),
        destructive: surface.querySelector('.ocu-button-destructive') !== null,
      };
    });
    assert.equal(opened.title, STRINGS.agentDefinitionDisable, 'the warning is titled with the verb');
    assert.equal(opened.body, STRINGS.interopItemPendingConsequence, 'and states the published pending-update sentence');
    assert.equal(opened.destructive, false, 'never a destructive one');
    assert.deepEqual(posts, [], 'nothing is sent while the dialog is open');
    await page.click('[role="dialog"] .ocu-dialog-actions .ocu-button-primary');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    assert.deepEqual(posts, [{ action: 'disable', id: ROW_ID(OPERATION) }], 'Disable sent once, past Proceed');
    await waitForEnabledCell(page, OPERATION, before, false);
    assert.equal(stored(OPERATION), '0', 'the stored configuration holds the item disabled');
    const after = (await itemRow(page, OPERATION))[3];
    assert.notEqual(after, before, 'and the row\'s Enabled cell reads the change');

    await rowAction(page, OPERATION, STRINGS.agentDefinitionEnable);
    await page.waitForSelector('app-warning-dialog', { timeout: config.navigationTimeoutMs });
    await page.click('[role="dialog"] .ocu-dialog-actions .ocu-button-primary');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await waitForEnabledCell(page, OPERATION, before);
    assert.deepEqual(posts.at(-1), { action: 'enable', id: ROW_ID(OPERATION) }, 'Enable sent at Proceed');
    assert.equal(stored(OPERATION), '1', 'the stored configuration holds the item enabled again');
  } finally {
    await context.close();
  }
});

// AC2, AC3. Mutation (Rule 19): make `InteropItemListPage.onOpen` return at once, rebuild and redeploy -> the
// dialog never opens and this goes red.
test('AC2, AC3: Add item opens its dialog; a held name is refused with the server\'s sentence; a new item is added, then removed with its typed name', async () => {
  const { context, page } = await signedInAt(browser, config, PRODUCTIONS_URL, VIEWPORTS.wide);
  const adds = [];
  const actions = [];
  page.on('request', (request) => {
    const path = new URL(request.url()).pathname;
    if (request.method() !== 'POST') return;
    if (path === ADD_PATH) adds.push(JSON.parse(request.postData() ?? '{}'));
    if (path === ACTION_PATH) actions.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    await openItems(page);
    await (await page.waitForSelector('.ocu-command-bar button.ocu-command-bar-primary', { visible: true, timeout: config.navigationTimeoutMs })).click();
    await page.waitForSelector('input[data-interop-item-add-name]', { visible: true, timeout: config.navigationTimeoutMs });
    const opened = await page.evaluate(() => ({
      title: document.querySelector('[role="dialog"] .ocu-dialog-title')?.textContent?.trim(),
      pending: document.querySelector('[data-interop-item-add-pending]')?.textContent?.trim(),
    }));
    assert.deepEqual(opened, { title: STRINGS.interopItemAddTitle, pending: STRINGS.interopItemPendingConsequence }, 'the dialog is titled with the published words and states the pending update');

    await fill(page, 'name', OPERATION);
    await fill(page, 'class', 'OcuPilotProbe.Interop.Op');
    await page.click('[data-interop-item-add-confirm]');
    await page.waitForSelector('[data-interop-item-add-reason]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(
      await page.$eval('[data-interop-item-add-reason]', (node) => node.textContent.trim()),
      STRINGS.interopItemRefusalTaken,
      'a name the production holds is refused with the server\'s sentence'
    );
    assert.equal(adds.length, 1, 'one request was sent');
    assert.equal(stored(ADDED), '', 'and nothing was stored');

    await fill(page, 'name', ADDED);
    await page.click('[data-interop-item-add-confirm]');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await rowPresent(page, ADDED);
    assert.deepEqual(
      adds.at(-1),
      { Production: PRODUCTION, Name: ADDED, ClassName: 'OcuPilotProbe.Interop.Op', Enabled: false },
      'the Save carries the production, the name, the class and the item disabled'
    );
    assert.equal(stored(ADDED), '0', 'the stored configuration holds the new item, disabled');

    await rowAction(page, ADDED, STRINGS.actionRemove);
    await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    const dialog = await page.evaluate(() => ({
      title: document.querySelector('[role="dialog"] .ocu-dialog-title').textContent.trim(),
      consequence: document.querySelector('.ocu-typed-name-consequence').textContent.trim(),
    }));
    assert.deepEqual(dialog, { title: `${STRINGS.actionRemove} ${ADDED}`, consequence: STRINGS.interopItemRemoveConsequence }, 'Remove asks for the name and states what it deletes');
    assert.deepEqual(actions, [], 'nothing is sent while the dialog is open');
    await page.type('.ocu-typed-name-field', ADDED);
    await page.keyboard.press('Enter');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await rowPresent(page, ADDED, false);
    assert.deepEqual(actions, [{ action: 'remove', id: ROW_ID(ADDED) }], 'one remove, sent with the row key once the name matched');
    assert.equal(stored(ADDED), '', 'the stored configuration no longer holds the item');
  } finally {
    await context.close();
  }
});

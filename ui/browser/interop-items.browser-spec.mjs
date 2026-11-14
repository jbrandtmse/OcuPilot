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
 * contrast checks at 1280 light, 720 light and 1280 dark, with no entry beyond the baseline (DW-1337). Story
 * 20.40's Copy opens its dialog on the selected item, refuses a held name with the server's sentence, adds a disabled copy of the item under a new
 * name and removes it. Story 20.41's Change class opens its dialog on a probe item of the operation class, lists the classes the Classes tab lists but the
 * item's own, reviews the settings the new class does not take, and changes the class once the item's name is typed, which the list then reads. Story 20.25's last test starts the probe production, then Stop warns with the published sentence and, past Proceed,
 * ends the operation's jobs, so its Jobs tab lists none; Start warns and runs a job again.
 *
 * **It compiles and writes a probe production in `USER`** through `OcuPilot.Test.ProductionProbe`, so it runs
 * on a throwaway only; the `after` hook removes the production, its classes and its messages, whatever the
 * tests answered. It starts nothing until its last test: an item write on a stopped production is stored and
 * saved to the class.
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
import { settleViewport, signedInAt, transitionsSettled } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const PROBE = 'OcuPilot.Test.ProductionProbe';
const CONTROL = 'OcuPilot.Test.InteropItemControl';
const RUN = 'OcuPilot.Test.InteropItemRun';
const PRODUCTION = 'OcuPilotProbe.Interop.Production';
const OPERATION = 'OcuPilotProbeOp';
const ADDED = 'OcuPilotProbeAdded';
const ROUTE = 'interoperability/productions/items';
const PRODUCTIONS_URL = '/ocupilot/interoperability/productions?ns=USER';
const ACTION_PATH = '/api/ocupilot/screens/interop.items/action';
const ADD_PATH = '/api/ocupilot/interop/items';
const COPY_PATH = '/api/ocupilot/interop/items/copy';
const DRY_RUN_PATH = '/api/ocupilot/screens/interop.items/dryrun';
const CHANGE = 'OcuPilot.Test.InteropItemChangeClass';
const CHANGED = 'OcuPilotProbeChg';
const OLD_CLASS = 'OcuPilotProbe.Interop.Op';
const NEW_CLASS = 'OcuPilotProbe.Interop.TearOp';
const COPIED = 'OcuPilotProbeCopy';
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
    await settleViewport(page, viewport);
    await page.evaluate((dark) => document.documentElement.classList.toggle('ocu-theme-dark', dark), theme === 'dark');
    await frames(page);
    await transitionsSettled(page, config.navigationTimeoutMs);
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

/** Wait until the row named `name` reads `word` in its class cell. */
function waitForClassCell(page, name, word) {
  return page.waitForFunction(
    (rowSelector, wanted, textSelector, expected) => {
      const row = Array.from(document.querySelectorAll(rowSelector)).find((node) => {
        const cell = node.querySelector('[role="gridcell"]');
        return ((cell?.querySelector(textSelector) ?? cell)?.textContent ?? '').trim() === wanted;
      });
      return row !== undefined && row.querySelectorAll('[role="gridcell"]')[1]?.textContent.trim() === expected;
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name,
    NAME_TEXT,
    word
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

/** The operation's runtime as `InteropItemRun.Facts` reads it, once it equals `want` (a failing assertion after twenty seconds). */
async function waitForFacts(want) {
  let facts = '';
  for (let attempt = 0; attempt < 40; attempt += 1) {
    facts = probe('FACTS', `##class(${RUN}).Facts()`).value;
    if (facts === want) return;
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  assert.equal(facts, want, 'the operation reads as the action leaves it');
}

/** Click the row action `label` of `name`, assert its warning states `sentence`, and answer Proceed once nothing was sent while it was open. */
async function warnAndProceed(page, posts, name, label, sentence) {
  const sent = posts.length;
  await rowAction(page, name, label);
  await page.waitForSelector('app-warning-dialog', { timeout: config.navigationTimeoutMs });
  const opened = await page.evaluate(() => {
    const surface = document.querySelector('[role="dialog"]');
    return {
      title: (surface.querySelector('.ocu-dialog-title')?.textContent ?? '').trim(),
      body: (surface.querySelector('.ocu-warning-consequence')?.textContent ?? '').trim(),
      destructive: surface.querySelector('.ocu-button-destructive') !== null,
    };
  });
  assert.deepEqual(opened, { title: label, body: sentence, destructive: false }, `${label} warns with its published sentence, never a destructive one`);
  assert.equal(posts.length, sent, 'nothing is sent while the dialog is open');
  await page.click('[role="dialog"] .ocu-dialog-actions .ocu-button-primary');
  await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
}

/** Open the operation's Jobs tab from the Production items list and answer the job rows' first cells, `[]` for the empty state. */
async function jobsTab(page) {
  await rowPresent(page, OPERATION);
  // The list is still narrowed to the operation by the row action's filter, and its name cell can carry the Changed tag.
  await clickRowCentre(page, { index: 0, link: true });
  await page.waitForFunction((suffix) => new URL(window.location.href).pathname.includes(suffix), { timeout: config.navigationTimeoutMs }, '/interoperability/productions/items/document/');
  await (await page.waitForSelector('button.ocu-detail-tab[data-route="interoperability/productions/items/jobs"]', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForFunction(
    (rowSelector, empty, header) => {
      if (!new URL(window.location.href).pathname.includes('/interoperability/productions/items/jobs/')) return false;
      if (document.querySelector('.ocu-data-table-empty-title')?.textContent.trim() === empty) return true;
      const first = document.querySelector('.ocu-data-table-header-label')?.textContent.trim();
      return first === header && document.querySelectorAll(rowSelector).length > 0;
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    STRINGS.interopItemJobsEmpty,
    STRINGS.interopColumnJob
  );
  return page.evaluate(
    (rowSelector) => Array.from(document.querySelectorAll(rowSelector)).map((row) => row.querySelector('[role="gridcell"]')?.textContent.trim() ?? ''),
    ROW_SELECTOR
  );
}

/** Type `value` into the add dialog's field `field`. */
async function fill(page, field, value) {
  const selector = `input[data-interop-item-add-${field}]`;
  await page.click(selector, { clickCount: 3 });
  await page.type(selector, value);
}

/** Type `value` into the copy dialog's name field. */
async function fillCopyName(page, value) {
  const selector = 'input[data-interop-item-copy-name]';
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

// AC1. Mutation (Rule 19): make the copy dialog post to the add's route (`INTEROP_ITEM_COPY_PATH` -> `/api/ocupilot/interop/items`),
// rebuild and redeploy -> the copy request is never seen and this goes red.
test('AC1: Copy opens its dialog on the selected item; a held name is refused with the server\'s sentence; a new name adds a disabled copy of the item, which is then removed', async () => {
  const { context, page } = await signedInAt(browser, config, PRODUCTIONS_URL, VIEWPORTS.wide);
  const copies = [];
  const actions = [];
  page.on('request', (request) => {
    const path = new URL(request.url()).pathname;
    if (request.method() !== 'POST') return;
    if (path === COPY_PATH) copies.push(JSON.parse(request.postData() ?? '{}'));
    if (path === ACTION_PATH) actions.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    await openItems(page);
    await rowAction(page, OPERATION, STRINGS.auditDatabaseCopyConfirm);
    await page.waitForSelector('input[data-interop-item-copy-name]', { visible: true, timeout: config.navigationTimeoutMs });
    const opened = await page.evaluate(() => ({
      title: document.querySelector('[role="dialog"] .ocu-dialog-title')?.textContent?.trim(),
      consequence: document.querySelector('[data-interop-item-copy-consequence]')?.textContent?.trim(),
      name: document.querySelector('input[data-interop-item-copy-name]').value,
    }));
    assert.deepEqual(opened, { title: STRINGS.interopItemCopyTitle, consequence: STRINGS.interopItemCopyConsequence, name: '' }, 'the dialog is titled with the published words, states the copy\'s consequence and starts with an empty name');
    assert.deepEqual(actions, [], 'the screen action route is never used for a copy');

    await fillCopyName(page, OPERATION);
    await page.click('[data-interop-item-copy-confirm]');
    await page.waitForSelector('[data-interop-item-copy-reason]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(
      await page.$eval('[data-interop-item-copy-reason]', (node) => node.textContent.trim()),
      STRINGS.interopItemRefusalTaken,
      'a name the production holds is refused with the server\'s sentence'
    );
    assert.equal(copies.length, 1, 'one request was sent');
    assert.equal(stored(COPIED), '', 'and nothing was stored');

    await fillCopyName(page, COPIED);
    await page.click('[data-interop-item-copy-confirm]');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    assert.deepEqual(copies.at(-1), { Production: PRODUCTION, Name: COPIED, CopyFrom: OPERATION }, 'the Save carries the production, the new name and the item copied');
    await page.click(FILTER_SELECTOR, { clickCount: 3 });
    await page.keyboard.press('Backspace');
    await rowPresent(page, COPIED);
    const source = await itemRow(page, OPERATION);
    const copy = await itemRow(page, COPIED);
    assert.equal(copy[1], source[1], 'the copy reads the source\'s class');
    assert.notEqual(copy[3], source[3], 'and, unlike the enabled source, is disabled');
    assert.equal(stored(COPIED), '0', 'the stored configuration holds the copy, disabled');
    assert.equal(stored(OPERATION), '1', 'and the source is unchanged');

    await rowAction(page, COPIED, STRINGS.actionRemove);
    await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    await page.type('.ocu-typed-name-field', COPIED);
    await page.keyboard.press('Enter');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await rowPresent(page, COPIED, false);
    assert.deepEqual(actions, [{ action: 'remove', id: ROW_ID(COPIED) }], 'the copy is removed with its typed name');
    assert.equal(stored(COPIED), '', 'the stored configuration no longer holds it');
  } finally {
    await context.close();
  }
});

// AC1. Mutation (Rule 19): make the review's typed name the item's composite id (drop the `name` argument of `startDryRun` in
// `InteropItemListPage.onChosenClass`), or read the Production items list in place of the Classes tab in the dialog's store; rebuild and
// redeploy first -> the typed name or the option list goes red.
test('AC1: Change class lists the Classes tab\'s other classes, reviews the settings the new class drops, and changes the class once the item\'s name is typed', async () => {
  const prepared = probe('CHGPREP', `$System.Status.IsOK(##class(${CHANGE}).Prepare())`);
  assert.equal(prepared.value, '1', `the probe item and its settings are stored: ${prepared.output}`);
  const { context, page } = await signedInAt(browser, config, PRODUCTIONS_URL, VIEWPORTS.wide);
  const posts = [];
  const dryRuns = [];
  page.on('request', (request) => {
    if (request.method() !== 'POST') return;
    const path = new URL(request.url()).pathname;
    if (path === ACTION_PATH) posts.push(JSON.parse(request.postData() ?? '{}'));
    if (path === DRY_RUN_PATH) dryRuns.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    await openItems(page);
    await rowPresent(page, CHANGED);
    await rowAction(page, CHANGED, STRINGS.interopItemChangeClassAction);
    await page.waitForSelector('select[data-interop-item-class-select]', { visible: true, timeout: config.navigationTimeoutMs });
    await page.waitForFunction(() => document.querySelectorAll('select[data-interop-item-class-select] option').length > 1, { timeout: config.navigationTimeoutMs });
    const opened = await page.evaluate(() => ({
      title: document.querySelector('[role="dialog"] .ocu-dialog-title')?.textContent?.trim(),
      consequence: document.querySelector('[data-interop-item-class-consequence]')?.textContent?.trim(),
      options: Array.from(document.querySelectorAll('select[data-interop-item-class-select] option')).map((option) => option.value),
    }));
    assert.equal(opened.title, STRINGS.interopItemChangeClassAction, 'the dialog is titled with the published words');
    assert.equal(opened.consequence, STRINGS.interopItemChangeClassConsequence, 'and states the change\'s consequence');
    assert.ok(opened.options.includes(NEW_CLASS), 'it lists the other operation class the Classes tab lists');
    assert.ok(!opened.options.includes(OLD_CLASS), 'and not the class the item has');
    assert.deepEqual(dryRuns, [], 'nothing is reviewed before a class is chosen');

    await page.select('select[data-interop-item-class-select]', NEW_CLASS);
    await page.click('[data-interop-item-class-review]');
    await page.waitForSelector('[data-ocu-review]', { visible: true, timeout: config.navigationTimeoutMs });
    const review = await page.$$eval('[data-ocu-review] li', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(
      review,
      [`- ClassName: ${OLD_CLASS}`, `+ ClassName: ${NEW_CLASS}`, '- Host.HangSeconds: 4471', '- Host.ApiToken:'],
      'the review lists the class change and the two settings the new class does not take, the credential-named one with no value'
    );
    assert.deepEqual(dryRuns, [{ action: 'changeclass', id: ROW_ID(CHANGED), values: { NewClass: NEW_CLASS } }], 'one review, of the class chosen');
    assert.deepEqual(posts, [], 'and the change is not sent before the name is typed');
    assert.equal(
      await page.$eval('.ocu-typed-name-consequence', (node) => node.textContent.trim()),
      STRINGS.interopItemChangeClassConsequence,
      'the review states the destructive consequence'
    );
    await page.type('.ocu-typed-name-field', CHANGED);
    await page.keyboard.press('Enter');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    assert.equal(posts.length, 1, 'one change was sent once the item\'s name matched');
    assert.deepEqual({ ...posts[0], values: { NewClass: posts[0].values?.NewClass } }, { action: 'changeclass', id: ROW_ID(CHANGED), values: { NewClass: NEW_CLASS } }, 'with the row key and the class');
    assert.match(posts[0].values?.Reviewed ?? '', /^[0-9a-f]{64}$/, 'and the digest of the review');
    await waitForClassCell(page, CHANGED, NEW_CLASS);
    assert.equal(probe('CHGSTORED', `##class(${CHANGE}).Stored("${CHANGED}")`).value, `${NEW_CLASS}|Host.TearDownSeconds=7`, 'the stored configuration holds the new class and the one setting it takes');

    await rowAction(page, CHANGED, STRINGS.actionRemove);
    await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    await page.type('.ocu-typed-name-field', CHANGED);
    await page.keyboard.press('Enter');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await rowPresent(page, CHANGED, false);
    assert.equal(stored(CHANGED), '', 'the item is removed again');
  } finally {
    await context.close();
  }
});

// AC1 (the dialog's dismissal). Mutation (Rule 19): drop `(closed)="cancelled.emit()"` from the Change class dialog's template, or have the
// page's `onCloseClass` leave the dialog open; rebuild and redeploy first -> the dialog is still on screen after Escape, Cancel or the scrim.
test('AC1: the Change class dialog closes on Escape, Cancel and the scrim, and each leaves the item as it was with nothing reviewed or sent', async () => {
  const { context, page } = await signedInAt(browser, config, PRODUCTIONS_URL, VIEWPORTS.wide);
  const sent = [];
  page.on('request', (request) => {
    if (request.method() !== 'POST') return;
    const path = new URL(request.url()).pathname;
    if (path === ACTION_PATH || path === DRY_RUN_PATH) sent.push(path);
  });
  const dialogGone = () => page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
  const open = async () => {
    await rowAction(page, OPERATION, STRINGS.interopItemChangeClassAction);
    await page.waitForSelector('[role="dialog"] [data-interop-item-class-review]', { visible: true, timeout: config.navigationTimeoutMs });
  };
  try {
    await openItems(page);
    const before = stored(OPERATION);
    await open();
    await page.keyboard.press('Escape');
    await dialogGone();
    await open();
    await page.evaluate((cancel) => {
      Array.from(document.querySelectorAll('[role="dialog"] .ocu-dialog-actions button')).find((button) => button.textContent.trim() === cancel).click();
    }, STRINGS.actionCancel);
    await dialogGone();
    await open();
    await page.mouse.click(4, 4);
    await dialogGone();
    assert.deepEqual(sent, [], 'no review and no change was sent');
    assert.equal(stored(OPERATION), before, 'and the stored item is as it was');
    await open();
    await page.keyboard.press('Escape');
    await dialogGone();
  } finally {
    await context.close();
  }
});

// AC3. Mutation (Rule 19): make the spec's Stop send `start` (change the label passed to `warnAndProceed` for the stop) -> the
// Stop warning's sentence assertion goes red; rebuild and redeploy first for any client mutation.
test('AC3: Stop warns and ends the operation\'s jobs, so its Jobs tab lists none; Start warns and runs a job again', async () => {
  const reset = probe('RUNRESET', `$System.Status.IsOK(##class(${CONTROL}).Reset())`);
  assert.equal(reset.value, '1', `the probe production's items are as they began: ${reset.output}`);
  const started = probe('RUNSTART', `$System.Status.IsOK(##class(${CONTROL}).StartProduction())`);
  assert.equal(started.value, '1', `the probe production runs with the operation's job: ${started.output}`);
  const { context, page } = await signedInAt(browser, config, PRODUCTIONS_URL, VIEWPORTS.wide);
  const posts = [];
  page.on('request', (request) => {
    if (request.method() === 'POST' && new URL(request.url()).pathname === ACTION_PATH) posts.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    await openItems(page);
    const itemsUrl = page.url();
    await waitForFacts('enabled=1 stopped=0 own=1 jobs=1 needs=0');

    await warnAndProceed(page, posts, OPERATION, STRINGS.actionStop, STRINGS.interopItemStopConsequence);
    assert.deepEqual(posts, [{ action: 'stop', id: ROW_ID(OPERATION) }], 'Stop sent once, past Proceed');
    await waitForFacts('enabled=1 stopped=1 own=0 jobs=0 needs=0');
    assert.deepEqual(await jobsTab(page), [], 'the Jobs tab lists no job after the stop');

    await page.goto(itemsUrl, { waitUntil: 'networkidle2' });
    await waitForRows(page, config.navigationTimeoutMs);
    await warnAndProceed(page, posts, OPERATION, STRINGS.actionStart, STRINGS.interopItemStartConsequence);
    assert.deepEqual(posts.at(-1), { action: 'start', id: ROW_ID(OPERATION) }, 'Start sent once, past Proceed');
    await waitForFacts('enabled=1 stopped=0 own=1 jobs=1 needs=0');
    const jobs = await jobsTab(page);
    assert.ok(jobs.length >= 1 && jobs.every((cell) => /^\d+$/.test(cell)), `the Jobs tab lists a job after the start: ${JSON.stringify(jobs)}`);
  } finally {
    await context.close();
  }
});

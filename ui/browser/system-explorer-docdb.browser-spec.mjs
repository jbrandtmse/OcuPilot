/**
 * System Explorer's Document databases in a real browser, against the throwaway instance (Story 19.17).
 *
 * What it pins, each on rendered DOM, on the request the page sent, or on the instance itself:
 *
 * 1. **The disabled service** (AC2): with `%Service_DocDB` disabled the screen states the published
 *    sentence in a status strip above the list, and the service stays disabled.
 * 2. **Create and drop** (AC1, AC4, AC5): with the service enabled, the list's Create opens the dialog,
 *    a probe database is created in USER and its row appears; the row menu's Drop opens the typed-name
 *    dialog with the published consequence, sends the delete, and the row leaves the list. The
 *    instance holds the database between the two and not after.
 * 3. **A refusal on its field** (AC4): a name with an underscore keeps the dialog open with the Name
 *    field marked and the server's sentence under it, and nothing reaches the instance.
 * 4. **DW-1337** (AC8): the strip, the list, the create dialog and the Drop dialog pass the
 *    structural walk at wide light, narrow light and wide dark.
 *
 * **It refuses the live and development containers.** It touches only `OcuProbe1917*` document
 * databases through `OcuPilot.Test.DocDbProbe`, which refuses unless the throwaway is armed: `before`
 * disables the service and removes every probe database, and `after` puts the service back as it was
 * and removes them again, asserting none survives.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1
 * browser/system-explorer-docdb.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { sideBarLabels } from './side-bar-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();

const PROBE = 'OcuPilot.Test.DocDbProbe';
const NAMESPACE = 'USER';
const DATABASE = 'OcuProbe1917B';
const INVALID = 'OcuProbe1917_bad';

const LIST_ROUTE = 'system-explorer/docdb';
const LIST_URL = `/ocupilot/${LIST_ROUTE}?ns=${NAMESPACE}`;
const SAVE_PATH = '/api/ocupilot/explorer/docdb';
const ACTION_PATH = '/api/ocupilot/screens/explorer.docdb/action';

const STRIP = '[data-docdb-service-strip]';
const NAME_FIELD = 'input[data-docdb-create-name]';

/** The row cells' own text selector, a name cell being a link. */
const NAME_TEXT = '.ocu-data-table-link, .ocu-data-table-text';

let browser = null;

/** The service's state before this spec changed it, which `after` puts back. */
let prior = '';

const marker = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/** Run `lines` in the throwaway and answer the value `name`'s marker carries, with the whole output. */
function iris(lines, name) {
  const output = runIris(config.container, lines);
  return { value: markerValue(output, name), output };
}

/** Set the service's `Enabled` to `enabled` through the armed fixture, and assert it read back. */
function setService(enabled) {
  const { value, output } = iris([`Set tSC=##class(${PROBE}).RestoreService(${enabled})`, marker('OK', '$System.Status.IsOK(tSC)')], 'OK');
  assert.equal(value, '1', `%Service_DocDB reads Enabled ${enabled}:\n${output}`);
}

/** Remove every probe database and class in USER and assert none survives. */
function removeAll() {
  const { value, output } = iris([`Set tSC=##class(${PROBE}).RemoveAll("${NAMESPACE}")`, marker('OK', '$System.Status.IsOK(tSC)')], 'OK');
  assert.equal(value, '1', `no OcuProbe1917 database or class survives in ${NAMESPACE}:\n${output}`);
}

/** Whether USER holds the document database `name`. */
function exists(name) {
  const { value, output } = iris([marker('EXISTS', `##class(${PROBE}).Exists("${NAMESPACE}","${name}")`)], 'EXISTS');
  assert.ok(value === '0' || value === '1', `the database read answered:\n${output}`);
  return value === '1';
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec enables a service and creates and drops document databases, so it never runs inside the live container');
  assert.ok(!/^ocupilot-slot-/.test(config.container), 'nor inside a development instance');
  await assertThrowaway(config);
  const read = iris([`Set tSC=##class(${PROBE}).ServiceEnabled(.tOn)`, marker('PRIOR', '$Select($System.Status.IsOK(tSC):tOn,1:"refused")')], 'PRIOR');
  assert.ok(read.value === '0' || read.value === '1', `the armed fixture reads the service:\n${read.output}`);
  prior = read.value;
  setService(0);
  removeAll();
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    if (config.container !== LIVE_CONTAINER && prior !== '') {
      removeAll();
      setService(Number(prior));
    }
  }
});

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
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
 * DW-1337 on the screen: 1280 light (every invariant), 720 light and 1280 dark, against the baseline;
 * with a dialog open, also the dialog body's own sideways overflow.
 */
async function assertStructure(page, dialog = false) {
  const entriesFound = [];
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
    const { entries } = await detectScreen(page, { route: LIST_ROUTE, checks, viewport: viewport.width, theme, minimums });
    entriesFound.push(...entries);
    if (!dialog) continue;
    const body = await page.$eval('.ocu-dialog-body', (element) => ({ scroll: element.scrollWidth, client: element.clientWidth }));
    assert.ok(body.scroll <= body.client, `the dialog body does not scroll sideways at ${viewport.width}px ${theme}: ${JSON.stringify(body)}`);
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await frames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  const fresh = compare(collapse(entriesFound), readBaseline()?.entries ?? []).fresh;
  assert.deepEqual(fresh.map((entry) => `${entry.key}: ${entry.measured}`), [], `no structural or contrast violation on ${LIST_ROUTE}`);
}

/** The side bar as rendered: its area and its entry labels, opening it first. */
async function sideBarOf(page) {
  if ((await page.$('app-side-bar nav.ocu-side-bar')) === null) {
    await page.keyboard.down('Control');
    await page.keyboard.press('b');
    await page.keyboard.up('Control');
  }
  await page.waitForSelector('app-side-bar nav.ocu-side-bar', { timeout: config.navigationTimeoutMs });
  return page.evaluate(() => {
    const nav = document.querySelector('app-side-bar nav.ocu-side-bar');
    return {
      area: nav.querySelector('.ocu-side-bar-eyebrow').textContent.trim(),
      entries: Array.from(nav.querySelectorAll('.ocu-side-bar-item .ocu-side-bar-label')).map((label) => label.textContent.trim()),
    };
  });
}

/** Open the create dialog from the command bar's Create. */
async function openCreate(page) {
  await (await page.waitForSelector('.ocu-command-bar button.ocu-command-bar-primary', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector(NAME_FIELD, { visible: true, timeout: config.navigationTimeoutMs });
}

/** Wait until the list holds a row whose name cell reads `name`. */
async function waitForRow(page, name) {
  await page.waitForFunction(
    (selector, wanted, textSelector) =>
      Array.from(document.querySelectorAll(selector)).some((row) => {
        const cell = row.querySelector('[role="gridcell"]');
        const text = cell?.querySelector(textSelector);
        return ((text ?? cell)?.textContent ?? '').trim() === wanted;
      }),
    { timeout: 90000 },
    ROW_SELECTOR,
    name,
    NAME_TEXT
  );
}

/** Narrow the list to `name`, select its row, open its row menu and choose Drop; answer the dialog's words. */
async function openDrop(page, name) {
  await waitForRows(page, config.navigationTimeoutMs);
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, name);
  await waitForRow(page, name);
  await clickRowCentre(page, { text: name, cell: 2 });
  await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
  await page.evaluate((label) => {
    Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'))
      .find((item) => item.textContent.trim().startsWith(label))
      .click();
  }, STRINGS.explorerDocDbDropLabel);
  await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
  return page.evaluate(() => ({
    title: document.querySelector('[role="dialog"] .ocu-dialog-title').textContent.trim(),
    consequence: document.querySelector('.ocu-typed-name-consequence').textContent.trim(),
  }));
}

// AC2. Mutation (Rule 19): skip `ServiceStatus` in DocDbPort.Invoke, reload the throwaway -> the read
// answers rows instead of the refusal, no strip is drawn, and this goes red.
test('AC2, AC8: with the DocDB service disabled the screen states the published sentence, and passes DW-1337', async () => {
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  try {
    await page.waitForSelector(STRIP, { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval(STRIP, (node) => node.textContent.trim()), STRINGS.explorerDocDbServiceDisabled);
    assert.equal(await page.$eval(STRIP, (node) => node.getAttribute('role')), 'status');
    const bar = await sideBarOf(page);
    assert.equal(bar.area, STRINGS.navAreaSystemExplorer);
    assert.deepEqual(bar.entries, sideBarLabels('system-explorer'), 'the System Explorer entries in their declared order');
    assert.ok(bar.entries.includes(STRINGS.explorerDocDbListLabel), 'Document databases is a System Explorer entry');
    await assertStructure(page);
    const { value } = iris([`Set tSC=##class(${PROBE}).ServiceEnabled(.tOn)`, marker('ON', 'tOn')], 'ON');
    assert.equal(value, '0', 'the service stays disabled');
  } finally {
    await context.close();
  }
});

// AC4, AC5. Mutation (Rule 19): drop the ExplorerDocDbList entry from DESTRUCTIVE_CONSEQUENCES, rebuild
// and redeploy -> no Drop is drawn in the row menu and this goes red.
test('AC1, AC4, AC5, AC8: create a probe database through the dialog, see its row, refuse a bad name on its field, then drop it', async () => {
  setService(1);
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const saves = [];
  const actions = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (request.method() === 'POST' && url.pathname === SAVE_PATH) saves.push({ ns: url.searchParams.get('ns'), body: JSON.parse(request.postData() ?? '{}') });
    if (request.method() === 'POST' && url.pathname === ACTION_PATH) actions.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    await page.waitForSelector('.ocu-data-table-empty', { visible: true, timeout: config.navigationTimeoutMs });
    assert.ok((await page.$eval('.ocu-data-table-empty', (node) => node.textContent)).includes(STRINGS.explorerDocDbListEmpty), 'USER holds no document database, and the list says so');
    assert.equal(await page.$(STRIP), null, 'no strip while the service is enabled');

    // A refusal on Name: the dialog stays open with the server's sentence under the field.
    await openCreate(page);
    assert.equal(await page.$eval('[role="dialog"] .ocu-dialog-title', (node) => node.textContent.trim()), STRINGS.explorerDocDbCreateTitle);
    await page.type(NAME_FIELD, INVALID);
    await page.click('[data-docdb-create-confirm]');
    await page.waitForFunction(
      (field) => document.querySelector(field)?.getAttribute('aria-invalid') === 'true' && (document.querySelector('[data-docdb-create-violation]')?.textContent ?? '').trim() !== '',
      { timeout: 90000 },
      NAME_FIELD
    );
    assert.equal(await page.$eval('[data-docdb-create-violation]', (node) => node.textContent.trim()), STRINGS.explorerDocDbNameInvalid);
    await assertStructure(page, true);
    assert.equal(exists(INVALID), false, 'nothing was created for the refused name');

    // Create.
    await page.click(NAME_FIELD, { clickCount: 3 });
    await page.keyboard.press('Backspace');
    await page.type(NAME_FIELD, DATABASE);
    await page.click('[data-docdb-create-confirm]');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: 90000 });
    assert.deepEqual(saves, [{ ns: NAMESPACE, body: { Name: INVALID } }, { ns: NAMESPACE, body: { Name: DATABASE } }]);
    await waitForRow(page, DATABASE);
    assert.equal(exists(DATABASE), true, 'the instance holds the new document database');
    const headers = await page.$$eval('.ocu-data-table-header-label', (labels) => labels.map((label) => label.textContent.trim()));
    assert.deepEqual(headers.slice(0, 4), [STRINGS.tableColumnName, STRINGS.explorerClassDocumentLabel, STRINGS.explorerDocDbColumnDocumentType, STRINGS.webAppColumnResource]);
    const cells = await page.$eval(
      ROW_SELECTOR,
      (row, textSelector) => {
        const [name, type] = Array.from(row.querySelectorAll('[role="gridcell"]'));
        return [(name.querySelector(textSelector) ?? name).textContent.trim(), type.textContent.trim()];
      },
      NAME_TEXT
    );
    assert.deepEqual(cells, [DATABASE, `ISC.DM.${DATABASE}`], 'the row names the database and the class its name created');
    await assertStructure(page);

    // Drop, through the typed-name dialog, on a fresh load that no longer marks the row changed.
    await page.goto(`${config.origin}${LIST_URL}`, { waitUntil: 'networkidle2' });
    const dialog = await openDrop(page, DATABASE);
    assert.deepEqual(dialog, { title: `${STRINGS.explorerDocDbDropLabel} ${DATABASE}`, consequence: STRINGS.explorerDocDbDropConsequence });
    await assertStructure(page, true);
    assert.deepEqual(actions, [], 'nothing is sent while the dialog is open');
    await page.type('.ocu-typed-name-field', DATABASE);
    await page.keyboard.press('Enter');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: 90000 });
    await page.waitForFunction(
      (selector, name) => !Array.from(document.querySelectorAll(selector)).some((row) => row.textContent.includes(name)),
      { timeout: 90000 },
      ROW_SELECTOR,
      DATABASE
    );
    assert.deepEqual(actions, [{ action: 'delete', id: DATABASE }]);
    assert.equal(exists(DATABASE), false, 'the document database is gone');
  } finally {
    await context.close();
    setService(0);
  }
});

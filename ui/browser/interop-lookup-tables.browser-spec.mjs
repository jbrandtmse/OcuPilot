/**
 * Story 20.5 in a real browser, against the throwaway instance: Interoperability's Lookup tables, a table's entries
 * and Business partners (AD-5, AD-36, AD-44, AD-53, AD-55, AD-62).
 *
 * What it pins, in `USER`, whose probe table and probe business partner this spec creates and removes: New table creates
 * a table with its first entry; the table's name opens its entries under the published headers; Add entry, Set value and
 * Remove (typing the key) each change the rows and the stored table, and removing the last entry removes the table;
 * Delete (typing the table's name) removes it from the list; a refused add shows the server's sentence in the dialog;
 * Business partners lists the probe partner and offers no action trigger; and each list passes the structural and contrast
 * checks at 1280 light, 720 light and 1280 dark, with no entry beyond the baseline (DW-1337).
 *
 * Each test arranges the table it needs through the fixture and removes it when it ends, so every test passes alone and in
 * any order; only the second table and the probe partner are arranged once, in `before`.
 *
 * **It writes probe lookup tables in `USER`** through `OcuPilot.Test.InteropLookupFixture`, so it runs on a throwaway
 * only; the `after` hook removes every table and the partner, whatever the tests answered. It starts no production.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/interop-lookup-tables.browser-spec.mjs` (after `npm run build` and the
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
const FIXTURE = 'OcuPilot.Test.InteropLookupFixture';
const TABLE = 'OcuProbe205Browser';
const OTHER = 'OcuProbe205Other';
const TABLES_URL = '/ocupilot/interoperability/lookup-tables?ns=USER';
const PARTNERS_URL = '/ocupilot/interoperability/business-partners?ns=USER';
const TABLES_ROUTE = 'interoperability/lookup-tables';
const ENTRIES_ROUTE = 'interoperability/lookup-tables/entries';
const PARTNERS_ROUTE = 'interoperability/business-partners';
const ENTRY_ACTION_PATH = '/api/ocupilot/screens/interop.lookupentries/action';
const TABLE_ACTION_PATH = '/api/ocupilot/screens/interop.lookuptables/action';
const ADD_PATH = '/api/ocupilot/interop/lookup-entries';
const NAME_TEXT = '.ocu-data-table-link, .ocu-data-table-text';
const MULTILINE = 'line one\nline two';

let browser = null;
let created = false;

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** The stored entries of `table` as `key=value` joined by `;`, `''` for a table that is absent; a line break reads `|`. */
function entries(table) {
  return probe('ENTRIES', `$Translate(##class(${FIXTURE}).Entries("${table}"),$Char(10),"|")`).value;
}

/** `text` as `entries` reads a stored value. */
function flat(text) {
  return text.replace(/\n/g, '|');
}

/** Wait, up to ten probes, until `exists(table)` reads `wanted`; answers the last reading. */
async function settled(table, wanted) {
  let last = exists(table);
  for (let tries = 0; last !== wanted && tries < 10; tries += 1) {
    await new Promise((resolve) => setTimeout(resolve, 500));
    last = exists(table);
  }
  return last;
}

/** Whether the stored lookup global holds `table` under exactly that name. */
function exists(table) {
  return probe('EXISTS', `##class(${FIXTURE}).Exists("${table}")`).value === '1';
}

/** `text` as an ObjectScript string expression, a line break spelled as a `$Char`. */
function literal(text) {
  return `"${text.replace(/"/g, '""').replace(/\n/g, '"_$Char(10)_"')}"`;
}

/** Remove `TABLE` and every entry it holds, whatever an earlier step left; the other probe table stays. */
function drop() {
  probe('DROP', `$System.Status.IsOK(##class(${FIXTURE}).Drop("${TABLE}"))`);
  assert.equal(exists(TABLE), false, 'the probe table is removed');
}

/** `TABLE` holding exactly `pairs` (`[key, value]`), through the fixture's own writes. */
function arrange(pairs) {
  drop();
  const puts = pairs.map(([key, value]) => `$System.Status.IsOK(##class(${FIXTURE}).Put("${TABLE}",${literal(key)},${literal(value)}))`);
  const result = probe('ARRANGE', puts.join('_'));
  assert.equal(result.value, '1'.repeat(pairs.length), `the probe table is arranged: ${result.output}`);
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
    const { entries: measured } = await detectScreen(page, { route, checks, viewport: viewport.width, theme, minimums });
    found.push(...measured);
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await frames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  return compare(collapse(found), readBaseline()?.entries ?? []).fresh.map((entry) => `${entry.key}: ${entry.measured}`);
}

/** The cells of the row whose first cell reads `name`, or `null`. */
function rowOf(page, name) {
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

/** Wait until the row named `name` reads `text` in its cell number `cell`. */
function waitForCell(page, name, cell, text) {
  return page.waitForFunction(
    (rowSelector, wanted, textSelector, at, expected) => {
      const row = Array.from(document.querySelectorAll(rowSelector)).find((node) => {
        const first = node.querySelector('[role="gridcell"]');
        return ((first?.querySelector(textSelector) ?? first)?.textContent ?? '').trim() === wanted;
      });
      const cells = row === undefined ? [] : Array.from(row.querySelectorAll('[role="gridcell"]'));
      return cells[at]?.textContent.trim() === expected;
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name,
    NAME_TEXT,
    cell,
    text
  );
}

/** Narrow the list to `name`, select its row, open its menu and choose the entry labeled `label`. */
async function rowAction(page, name, label) {
  await waitForRows(page, config.navigationTimeoutMs);
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, name);
  await rowPresent(page, name);
  // The filter leaves the one row; its second cell is not the name's link.
  await clickRowCentre(page, { index: 0, cell: 1 });
  await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
  await page.evaluate((wanted) => {
    Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'))
      .find((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted)
      .click();
  }, label);
}

/** Wait until the dialog closes. */
function dialogClosed(page) {
  return page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
}

/** Replace the text of the dialog field `selector` with `value`. */
async function fill(page, selector, value) {
  await page.click(selector, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(selector, value);
}

/** Open the Lookup tables list for the probe namespace and wait for its rows and the namespace features. */
async function openTables(page) {
  await waitForRows(page, config.navigationTimeoutMs);
  await waitForMapAnswered(page, config.navigationTimeoutMs);
}

/** Open the primary action's dialog on the current list. */
async function openPrimary(page, selector) {
  await (await page.waitForSelector('.ocu-command-bar button.ocu-command-bar-primary', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector(selector, { visible: true, timeout: config.navigationTimeoutMs });
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec writes probe lookup tables, so it runs only in a throwaway; ${config.container} is not one`);
  const cleared = probe('LKCLEAN', `$System.Status.IsOK(##class(${FIXTURE}).Clear())`);
  assert.equal(cleared.value, '1', `an earlier run's probe tables are removed: ${cleared.output}`);
  const other = probe('LKOTHER', `$System.Status.IsOK(##class(${FIXTURE}).Put("${OTHER}","only","entry"))`);
  assert.equal(other.value, '1', `a second table is arranged: ${other.output}`);
  const partner = probe('LKPARTNER', `$System.Status.IsOK(##class(${FIXTURE}).PutPartner())`);
  assert.equal(partner.value, '1', `the probe partner is created: ${partner.output}`);
  created = true;
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (created && /-ci$/.test(config.container)) {
      const removed = probe('LKGONE', `$System.Status.IsOK(##class(${FIXTURE}).Clear())_##class(${FIXTURE}).Tables()`);
      assert.equal(removed.value, '1', `the probe tables and partner are removed: ${removed.output}`);
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

// AC1, AC2. Mutation (Rule 19): remove `secondaryEntityTypes` from the tables list's descriptor, regenerate the mirror,
// rebuild and redeploy -> the new table never appears in the list and this goes red.
test('AC2: New table creates a table with its first entry, which the list shows under the published headers', async () => {
  drop();
  const { context, page } = await signedInAt(browser, config, TABLES_URL, VIEWPORTS.wide);
  const adds = [];
  page.on('request', (request) => {
    if (request.method() === 'POST' && new URL(request.url()).pathname === ADD_PATH) adds.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    await openTables(page);
    await rowPresent(page, OTHER);
    const headers = await page.$$eval('.ocu-data-table-header-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(headers.slice(0, 2), [STRINGS.tableColumnName, STRINGS.explorerColumnModified], 'the declared headers');
    assert.deepEqual(await structural(page, TABLES_ROUTE), [], 'Lookup tables: no violation beyond the baseline\'s entries');

    await openPrimary(page, 'input[data-interop-lookup-table]');
    const opened = await page.evaluate(() => ({
      title: document.querySelector('[role="dialog"] .ocu-dialog-title')?.textContent?.trim(),
      help: document.querySelector('[role="dialog"]').textContent,
    }));
    assert.equal(opened.title, STRINGS.interopLookupTableDialogTitle, 'the dialog is titled with the published words');
    assert.ok(opened.help.includes(STRINGS.interopLookupNewTableHelp) && opened.help.includes(STRINGS.interopLookupEntryHelp), 'and states that a table is created by its first entry, in effect at once');

    await fill(page, 'input[data-interop-lookup-table]', OTHER.toUpperCase());
    await fill(page, 'input[data-interop-lookup-key]', 'first');
    await fill(page, '[data-interop-lookup-value]', MULTILINE);
    await page.click('[data-interop-lookup-confirm]');
    await page.waitForSelector('[data-interop-lookup-reason], [data-interop-lookup-violation]', { visible: true, timeout: config.navigationTimeoutMs });
    const refused = await page.evaluate(() => document.querySelector('[data-interop-lookup-reason]')?.textContent?.trim() ?? '');
    assert.equal(refused, STRINGS.interopLookupRefusalTableCase, 'a name that differs from a held table only in letter case is refused with the server\'s sentence');
    assert.equal(adds.length, 1, 'one request was sent');
    assert.equal(exists(OTHER.toUpperCase()), false, 'and nothing was stored');

    await fill(page, 'input[data-interop-lookup-table]', TABLE);
    await page.click('[data-interop-lookup-confirm]');
    await dialogClosed(page);
    await rowPresent(page, TABLE);
    assert.deepEqual(adds.at(-1), { Table: TABLE, Key: 'first', Value: MULTILINE }, 'the Save carries the table, the key and the value as typed');
    assert.equal(entries(TABLE), `first=${flat(MULTILINE)}`, 'the table is created with its first entry');
    const row = await rowOf(page, TABLE);
    assert.ok(row !== null && row[1] !== '', 'and its row reads a Modified time');
  } finally {
    await context.close();
    drop();
  }
});

// AC1, AC2. Mutation (Rule 19): make `childListFor` answer null for the tables list -> the name cell opens nothing and
// this goes red.
test('AC1, AC2: the table\'s name opens its entries; Add entry, Set value and Remove each change the rows', async () => {
  arrange([['first', MULTILINE]]);
  const { context, page } = await signedInAt(browser, config, TABLES_URL, VIEWPORTS.wide);
  const adds = [];
  const actions = [];
  page.on('request', (request) => {
    if (request.method() !== 'POST') return;
    const path = new URL(request.url()).pathname;
    if (path === ADD_PATH) adds.push(JSON.parse(request.postData() ?? '{}'));
    if (path === ENTRY_ACTION_PATH) actions.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    await openTables(page);
    await rowPresent(page, TABLE);
    await clickRowCentre(page, { text: TABLE, link: true });
    await page.waitForFunction((suffix) => new URL(window.location.href).pathname.includes(suffix), { timeout: config.navigationTimeoutMs }, `/${ENTRIES_ROUTE}/`);
    await waitForRows(page, config.navigationTimeoutMs);
    await rowPresent(page, 'first');
    const headers = await page.$$eval('.ocu-data-table-header-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(headers.slice(0, 3), [STRINGS.interopLookupColumnKey, STRINGS.errorLogColumnValue, STRINGS.interopLookupColumnSecret], 'the declared headers');
    assert.deepEqual(await structural(page, ENTRIES_ROUTE), [], 'the entries: no violation beyond the baseline\'s entries');

    await openPrimary(page, 'input[data-interop-lookup-key]');
    assert.equal(await page.$eval('input[data-interop-lookup-table]', (node) => node.value), TABLE, 'the add dialog names the route\'s table');
    await fill(page, 'input[data-interop-lookup-key]', 'first');
    await page.click('[data-interop-lookup-confirm]');
    await page.waitForSelector('[data-interop-lookup-reason]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-interop-lookup-reason]', (node) => node.textContent.trim()), STRINGS.interopLookupRefusalTaken, 'a held key is refused with the server\'s sentence');
    await fill(page, 'input[data-interop-lookup-key]', 'second');
    await fill(page, '[data-interop-lookup-value]', 'two');
    await page.click('[data-interop-lookup-confirm]');
    await dialogClosed(page);
    await rowPresent(page, 'second');
    assert.deepEqual(adds.at(-1), { Table: TABLE, Key: 'second', Value: 'two' }, 'the Save carries the route\'s table with the key and value');
    assert.equal(entries(TABLE), `first=${flat(MULTILINE)};second=two`, 'the entry is added to the stored table');

    await rowAction(page, 'second', STRINGS.interopLookupEntrySetAction);
    await page.waitForSelector('[data-interop-setting-value]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[role="dialog"] .ocu-dialog-title', (node) => node.textContent.trim()), STRINGS.interopLookupSetDialogTitle, 'Set value opens its dialog');
    await fill(page, '[data-interop-setting-value]', 'changed');
    await page.click('[data-interop-setting-confirm]');
    await dialogClosed(page);
    await waitForCell(page, 'second', 1, 'changed');
    assert.deepEqual(actions.at(-1), { action: 'set', id: `${TABLE}\u0001second`, values: { Value: 'changed' } }, 'one set, sent with the row key and the typed value');
    assert.equal(entries(TABLE), `first=${flat(MULTILINE)};second=changed`, 'the stored value changed');

    await rowAction(page, 'second', STRINGS.actionRemove);
    await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    const dialog = await page.evaluate(() => ({
      title: document.querySelector('[role="dialog"] .ocu-dialog-title').textContent.trim(),
      consequence: document.querySelector('.ocu-typed-name-consequence').textContent.trim(),
    }));
    assert.deepEqual(dialog, { title: `${STRINGS.actionRemove} second`, consequence: STRINGS.interopLookupRemoveConsequence }, 'Remove asks for the key and states what it removes');
    const sent = actions.length;
    await page.type('.ocu-typed-name-field', 'second');
    await page.keyboard.press('Enter');
    await dialogClosed(page);
    await rowPresent(page, 'second', false);
    assert.equal(actions.length, sent + 1, 'one remove was sent');
    assert.deepEqual(actions.at(-1), { action: 'remove', id: `${TABLE}\u0001second` }, 'with the row key once the key matched');
    assert.equal(entries(TABLE), `first=${flat(MULTILINE)}`, 'the entry is gone from the stored table');
  } finally {
    await context.close();
    drop();
  }
});

// AC2, AC3. Mutation (Rule 19): drop the table delete's entry from TYPED_NAME_ROWS, rebuild and redeploy -> Delete is not
// confirmed by the typed name and this goes red.
test('AC2, AC3: removing the last entry removes the table; Delete types the table\'s name and removes it from the list', async () => {
  arrange([['first', 'one']]);
  const { context, page } = await signedInAt(browser, config, TABLES_URL, VIEWPORTS.wide);
  const tableActions = [];
  page.on('request', (request) => {
    if (request.method() === 'POST' && new URL(request.url()).pathname === TABLE_ACTION_PATH) tableActions.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    await openTables(page);
    await rowPresent(page, TABLE);
    await clickRowCentre(page, { text: TABLE, link: true });
    await page.waitForFunction((suffix) => new URL(window.location.href).pathname.includes(suffix), { timeout: config.navigationTimeoutMs }, `/${ENTRIES_ROUTE}/`);
    await waitForRows(page, config.navigationTimeoutMs);
    await rowAction(page, 'first', STRINGS.actionRemove);
    await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    await page.type('.ocu-typed-name-field', 'first');
    await page.keyboard.press('Enter');
    await dialogClosed(page);
    assert.equal(await settled(TABLE, false), false, 'the last entry\'s removal took the table with it');
    // The table is gone, so the entries list's re-read is refused and the row stays marked removed; the tables list no longer holds it.
    await page.goto(`${config.origin}${TABLES_URL}`, { waitUntil: 'networkidle2' });
    await openTables(page);
    await rowPresent(page, OTHER);
    await rowPresent(page, TABLE, false);
    // A table to delete, with two entries, every one of which the delete takes.
    const made = probe('LKMADE', `$System.Status.IsOK(##class(${FIXTURE}).Put("${TABLE}","a","1"))_$System.Status.IsOK(##class(${FIXTURE}).Put("${TABLE}","b","2"))`);
    assert.equal(made.value, '11', `the table to delete is arranged: ${made.output}`);
    await page.reload();
    await openTables(page);
    await rowPresent(page, TABLE);
    await rowAction(page, TABLE, STRINGS.actionDelete);
    await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    const dialog = await page.evaluate(() => ({
      title: document.querySelector('[role="dialog"] .ocu-dialog-title').textContent.trim(),
      consequence: document.querySelector('.ocu-typed-name-consequence').textContent.trim(),
    }));
    assert.deepEqual(dialog, { title: `${STRINGS.actionDelete} ${TABLE}`, consequence: STRINGS.interopLookupDeleteConsequence }, 'Delete asks for the table\'s name and states what it deletes');
    assert.deepEqual(tableActions, [], 'nothing is sent while the dialog is open');
    await page.type('.ocu-typed-name-field', TABLE);
    await page.keyboard.press('Enter');
    await dialogClosed(page);
    await rowPresent(page, TABLE, false);
    assert.deepEqual(tableActions, [{ action: 'delete', id: TABLE }], 'one delete, sent with the table\'s name once it matched');
    assert.equal(await settled(TABLE, false), false, 'the table and every entry are gone from the stored lookup global');
    assert.equal(exists(OTHER), true, 'and the other table is untouched');
  } finally {
    await context.close();
    drop();
  }
});

// AC6. Mutation (Rule 19): give the partners descriptor a row action, regenerate the mirror, rebuild and redeploy -> the
// trigger appears and the no-action assertion goes red.
test('AC6: Business partners lists the probe partner under the published headers and offers no action', async () => {
  const { context, page } = await signedInAt(browser, config, PARTNERS_URL, VIEWPORTS.wide);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await waitForMapAnswered(page, config.navigationTimeoutMs);
    await rowPresent(page, 'OcuProbe205Partner');
    const headers = await page.$$eval('.ocu-data-table-header-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(
      headers.slice(0, 5),
      [STRINGS.tableColumnName, STRINGS.tableColumnDescription, STRINGS.interopPartnerColumnContact, STRINGS.interopPartnerColumnPhone, STRINGS.userFieldEmail],
      'the declared headers'
    );
    const row = await rowOf(page, 'OcuProbe205Partner');
    assert.deepEqual(row.slice(0, 5), ['OcuProbe205Partner', 'Probe partner description', 'Pat Primary', '555-0101', 'pat@example.test'], 'the partner reads its description and its primary contact');
    assert.equal(await page.$('.ocu-data-table-trigger'), null, 'and no row offers an action trigger');
    assert.equal(await page.$('.ocu-command-bar button.ocu-command-bar-primary'), null, 'nor does the command bar offer a primary action');
    assert.deepEqual(await structural(page, PARTNERS_ROUTE), [], 'Business partners: no violation beyond the baseline\'s entries');
  } finally {
    await context.close();
  }
});

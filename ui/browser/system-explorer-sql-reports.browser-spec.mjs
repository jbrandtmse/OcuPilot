/**
 * Story 21.29 in a real browser, against the throwaway: System Explorer's SQL troubleshooting reports list with its Save query, Generate report and
 * Delete (AD-5, AD-29, AD-7, AD-21, AD-51, AD-53).
 *
 * What it pins: Save query is offered with no row selected, asks for the support case and the statement, confirms, and lists the probe's row, which the
 * vendor's own table holds; Generate report to this browser downloads `WRC<case>.xml` holding the statement; Delete asks for the saved query's ID,
 * confirms and empties the probe's rows; and the page draws no mail action or link (AC4).
 *
 * **It saves and deletes the namespace's troubleshooting report queries** through the shipped screens, so it runs on a throwaway only. The probe is a table
 * and a query over it, saved under the support case the probe names. Each test starts from `fresh`, so it passes alone and in any order. Its `after` hook
 * removes the probe's saved queries by id, its cached queries and its table, and asserts that none is left.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/system-explorer-sql-reports.browser-spec.mjs` (after `npm run build` and the bundle copied into the
 * throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const PROBE = 'OcuPilot.Test.SqlTuningProbe';
const NS = 'HSCUSTOM';
const LIST_ROUTE = `/ocupilot/system-explorer/sql-reports?ns=${NS}`;
/** The probe's schema, its support case and the statement saved under it. */
const SCHEMA = 'OcuProbe229';
const WRC = '2291';
const STATEMENT = `SELECT A, B FROM ${SCHEMA}.T WHERE A > 0`;
/** The list's columns, by position in a row. */
const COLUMN = { id: 0, wrc: 1, statement: 6 };
/** The vendor saves a probe query in a fraction of a second; a send is given a minute. */
const SEND_MS = 60000;

let browser = null;
let touched = false;

/** Run one probe expression in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** How many saved queries the probe's support case holds in the vendor's own table. */
function savedCount() {
  return probe('RIDS', `$ListLength(##class(${PROBE}).ReportIds("${NS}", ${WRC}))`).value;
}

/** The text of the probe case's first saved query, read from the vendor's own table. */
function savedStatement() {
  return probe('RTEXT', `##class(${PROBE}).ReportStatement("${NS}", $ListGet(##class(${PROBE}).ReportIds("${NS}", ${WRC}), 1))`).value;
}

/** Put the probe back as `MakeReport` leaves it: its table made, and no saved query of its case or schema in the namespace. */
function fresh() {
  const made = probe('RMADE', `$System.Status.IsOK(##class(${PROBE}).MakeReport("${NS}"))`);
  assert.equal(made.value, '1', `the probe objects are created: ${made.output}`);
  assert.equal(probe('RLEFT', `##class(${PROBE}).ReportLeft("${NS}")`).value, '0', 'the namespace starts with no saved query of the probe');
}

/** Start from `fresh`, then save the probe's query under the probe's case through the vendor, so the list has the row the test needs. */
function seed() {
  fresh();
  const saved = probe('RSEED', `$System.Status.IsOK(##class(%SQL.Manager.QButtons.Base).InsertQuery(##class(${PROBE}).#REPORTQUERY, ${WRC}, 0, 0))`);
  assert.equal(saved.value, '1', `the probe's query is saved: ${saved.output}`);
  assert.equal(savedCount(), '1', 'the probe case holds one saved query');
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec saves and deletes troubleshooting report queries on the instance, so it runs only in a throwaway; ${config.container} is not one`);
  touched = true; // from here on, `after` removes what MakeReport created, even when it fails part-way
  fresh();
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    if (touched && /-ci$/.test(config.container)) {
      const removed = probe('RGONE', `$System.Status.IsOK(##class(${PROBE}).RemoveReport("${NS}"))`);
      assert.equal(removed.value, '1', `the probe objects are removed: ${removed.output}`);
      assert.equal(probe('RLEFT2', `##class(${PROBE}).ReportLeft("${NS}")`).value, '0', 'no saved query of the probe is left');
      assert.equal(probe('RTABLE', `##class(%Dictionary.CompiledClass).%ExistsId("${SCHEMA}.T")`).value, '0', 'the probe table is gone');
      assert.equal(probe('RCACHE', `##class(${PROBE}).CachedQueryCount("${NS}", "${SCHEMA}")`).value, '0', 'no cached query of the probe is left');
    }
  }
});

/** The cells of every row drawn, one array of texts per row. */
function rows(page) {
  return page.$$eval(ROW_SELECTOR, (nodes) => nodes.map((node) => Array.from(node.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim())));
}

/** Narrow the list to the probe's rows through the filter, which reads each row's statement. */
async function filterToProbe(page) {
  await page.waitForSelector(FILTER_SELECTOR, { timeout: config.navigationTimeoutMs });
  await page.type(FILTER_SELECTOR, SCHEMA);
  await page.waitForFunction(
    (selector, column, schema) => {
      const drawn = Array.from(document.querySelectorAll(selector));
      return drawn.length > 0 && drawn.every((row) => (row.querySelectorAll('[role="gridcell"]')[column]?.textContent ?? '').includes(schema));
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    COLUMN.statement,
    SCHEMA
  );
}

/** Wait until a row of the probe's case holds the probe's statement. */
async function waitForProbeRow(page) {
  await page.waitForFunction(
    (selector, columns, wrc, schema) =>
      Array.from(document.querySelectorAll(selector)).some((row) => {
        const cells = row.querySelectorAll('[role="gridcell"]');
        return (cells[columns.wrc]?.textContent ?? '').trim() === wrc && (cells[columns.statement]?.textContent ?? '').includes(schema);
      }),
    { timeout: SEND_MS },
    ROW_SELECTOR,
    COLUMN,
    WRC,
    SCHEMA
  );
}

/** Select the first row drawn, so the command bar takes a row action. */
async function selectFirstRow(page) {
  await clickRowCentre(page, { index: 0, cell: 2 });
  await page.waitForFunction((selector) => document.querySelectorAll(selector)[0]?.getAttribute('aria-selected') === 'true', { timeout: config.navigationTimeoutMs }, ROW_SELECTOR);
}

/** The command-bar buttons, each with whether it is held back. */
function barState(page) {
  return page.$$eval('.ocu-command-bar button', (buttons) =>
    Object.fromEntries(buttons.map((button) => [button.textContent.trim(), button.getAttribute('aria-disabled') === 'true']))
  );
}

/**
 * Take the action labeled `label` through the command bar once it is drawn and not held back (an element click, not a pointer event), or, where the bar
 * draws no such button, through the selected row's menu.
 */
async function act(page, label) {
  const onBar = await page
    .waitForFunction(
      (wanted) => [...document.querySelectorAll('.ocu-command-bar button')].some((button) => button.textContent.trim() === wanted && button.getAttribute('aria-disabled') !== 'true'),
      { timeout: 5000 },
      label
    )
    .then(
      () => true,
      () => false
    );
  if (onBar) {
    await page.evaluate((wanted) => [...document.querySelectorAll('.ocu-command-bar button')].find((button) => button.textContent.trim() === wanted).click(), label);
    return;
  }
  await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
  await page.evaluate(
    (wanted) => [...document.querySelectorAll('[role="menu"] [role="menuitem"]')].find((entry) => entry.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted).click(),
    label
  );
}

/** The dialog the action opened: its title. */
async function dialogTitle(page) {
  await page.waitForSelector('.ocu-dialog-title', { visible: true, timeout: config.navigationTimeoutMs });
  return page.$eval('.ocu-dialog-title', (node) => node.textContent.trim());
}

/** Wait until no dialog stands: the send ran and the instance applied it. */
function dialogClosed(page) {
  return page.waitForFunction(() => document.querySelector('.ocu-dialog') === null, { timeout: SEND_MS });
}

/** The status line the page leaves behind. */
function statusLine(page) {
  return page.$eval('[data-sql-reports-status]', (node) => node.textContent.trim());
}

/** Record the files this browser is asked to save, without leaving the page. */
function captureDownloads(page) {
  return page.evaluate(() => {
    window.__ocuSaved = [];
    const create = URL.createObjectURL.bind(URL);
    let blob = null;
    URL.createObjectURL = (made) => {
      blob = made;
      return create(made);
    };
    const click = HTMLAnchorElement.prototype.click;
    HTMLAnchorElement.prototype.click = function () {
      if (this.download && blob !== null) {
        const kept = blob;
        const name = this.download;
        void kept.text().then((text) => window.__ocuSaved.push({ name, type: kept.type, text }));
        return;
      }
      click.call(this);
    };
  });
}

test('AC1: Save query, with no row selected, asks for the case and the statement, confirms and lists the probe\'s row', async () => {
  fresh();
  const { context, page } = await signedInAt(browser, config, LIST_ROUTE, VIEWPORTS.wide);
  try {
    await waitForMapAnswered(page, config.navigationTimeoutMs);
    // Mutation (Rule 19): `SqlReportsPage` drops its `actions.register` of Save query, or the descriptor declares no primary action -> the command bar draws
    // no usable Save query and this wait times out.
    await page.waitForFunction(
      (wanted) => [...document.querySelectorAll('.ocu-command-bar button')].some((button) => button.textContent.trim() === wanted),
      { timeout: config.navigationTimeoutMs },
      STRINGS.sqlReportsSaveAction
    );
    const held = await barState(page);
    assert.equal(held[STRINGS.sqlReportsSaveAction], false, `Save query is offered and not held back with no row selected: ${JSON.stringify(held)}`);
    assert.equal(held[STRINGS.sqlReportsGenerateAction], true, `Generate report waits for a row: ${JSON.stringify(held)}`);
    await act(page, STRINGS.sqlReportsSaveAction);
    assert.equal(await dialogTitle(page), STRINGS.sqlReportsSaveTitle, 'the dialog is titled as published');
    assert.equal(await page.$eval('[data-slot="consequence"]', (node) => node.textContent.trim()), STRINGS.sqlReportsSaveConsequence, 'it states what the save does');
    assert.equal(await page.$eval('.ocu-field-caption', (node) => node.textContent.trim()), STRINGS.sqlReportsWrcHelp, 'it helps with the case number');
    assert.equal(await page.$eval('[data-slot="proceed"]', (node) => node.getAttribute('aria-disabled')), 'true', 'Proceed waits for a statement');
    await page.type('[data-slot="wrc"]', WRC);
    await page.type('[data-slot="statement"]', STATEMENT);
    await page.evaluate(() => document.querySelector('[data-slot="proceed"]').click());
    await dialogClosed(page);
    assert.equal(savedCount(), '1', 'the vendor\'s own table holds the probe case\'s new row');
    assert.equal(savedStatement(), STATEMENT, 'it holds the statement as written');
    assert.equal(await statusLine(page), STRINGS.sqlReportsSaveDone.replace('<wrc>', WRC), 'the page says which case was saved');
    await filterToProbe(page);
    // Mutation (Rule 19): `SqlReportsPage.onSave` sends nothing (rebuilt and redeployed) -> the dialog never closes and this wait times out.
    await waitForProbeRow(page);
  } finally {
    await context.close();
  }
});

test('AC3: Generate report to this browser downloads WRC<case>.xml holding the statement', async () => {
  seed();
  const { context, page } = await signedInAt(browser, config, LIST_ROUTE, VIEWPORTS.wide);
  try {
    await waitForMapAnswered(page, config.navigationTimeoutMs);
    await waitForRows(page, config.navigationTimeoutMs);
    await filterToProbe(page);
    await captureDownloads(page);
    await selectFirstRow(page);
    await act(page, STRINGS.sqlReportsGenerateAction);
    assert.equal(await dialogTitle(page), STRINGS.sqlReportsGenerateTitle.replace('<wrc>', WRC), 'the dialog names the selected row\'s support case');
    assert.equal(await page.$eval('[data-explorer-export-replaces]', (node) => node.textContent.trim()), STRINGS.sqlReportsGenerateConsequence, 'it states what the report holds and that a file is replaced');
    await page.click('input[data-explorer-export-destination="browser"]');
    // Mutation (Rule 19): `SqlReportsPage.onGenerate` drops its `saveText` for this browser (rebuilt and redeployed) -> no file is saved and this wait times out.
    await page.click('[data-explorer-export-confirm]');
    await page.waitForFunction(() => window.__ocuSaved.length === 1, { timeout: SEND_MS });
    const saved = await page.evaluate(() => window.__ocuSaved[0]);
    assert.equal(saved.name, `WRC${WRC}.xml`, 'the browser saves WRC<case>.xml');
    assert.equal(saved.type, 'application/xml');
    assert.ok(saved.text.includes('<QButtons>'), 'the file is the vendor\'s report');
    assert.ok(saved.text.includes(`FROM ${SCHEMA}.T`), 'it holds the saved statement');
    await dialogClosed(page);
    assert.equal(await statusLine(page), STRINGS.sqlReportsExportSaved.replace('<wrc>', WRC).replace('<file>', `WRC${WRC}.xml`), 'the page says which file was saved');
    assert.equal(savedCount(), '1', 'a report changes no saved query');
  } finally {
    await context.close();
  }
});

test('AC4: the page draws no mail action and no mail link', async () => {
  seed();
  const { context, page } = await signedInAt(browser, config, LIST_ROUTE, VIEWPORTS.wide);
  try {
    await waitForMapAnswered(page, config.navigationTimeoutMs);
    await waitForRows(page, config.navigationTimeoutMs);
    await filterToProbe(page);
    await selectFirstRow(page);
    await act(page, STRINGS.sqlReportsGenerateAction);
    await dialogTitle(page);
    // Mutation (Rule 19): the descriptor declares a `mail` row action, or the dialog draws a `mailto:` link (rebuilt and redeployed) -> this goes red.
    const mail = await page.evaluate(() => ({
      links: [...document.querySelectorAll('a[href^="mailto:"]')].length,
      controls: [...document.querySelectorAll('button, [role="menuitem"]')].map((node) => node.textContent.trim()).filter((text) => /mail/i.test(text)),
    }));
    assert.deepEqual(mail, { links: 0, controls: [] }, 'nothing on the page mails anyone');
  } finally {
    await context.close();
  }
});

test('AC2: Delete asks for the saved query\'s ID, confirms and empties the probe\'s rows', async () => {
  seed();
  const { context, page } = await signedInAt(browser, config, LIST_ROUTE, VIEWPORTS.wide);
  try {
    await waitForMapAnswered(page, config.navigationTimeoutMs);
    await waitForRows(page, config.navigationTimeoutMs);
    await filterToProbe(page);
    await selectFirstRow(page);
    const id = (await rows(page))[0][COLUMN.id];
    assert.match(id, /^\d+$/, `the row's ID is a whole number: ${id}`);
    // Mutation (Rule 19): `ExplorerSqlReports` drops `delete` from the handler's destructive consequences (rebuilt and redeployed) -> no Delete is drawn and this wait times out.
    await act(page, STRINGS.actionDelete);
    await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-typed-name-consequence', (node) => node.textContent.trim()), STRINGS.sqlReportsDeleteConsequence, 'the dialog states what the delete does');
    assert.equal(savedCount(), '1', 'nothing is deleted before the name is typed');
    await page.type('.ocu-typed-name-field', id);
    await page.waitForFunction(() => document.querySelector('.ocu-dialog-actions .ocu-button-destructive')?.getAttribute('aria-disabled') !== 'true', { timeout: config.navigationTimeoutMs });
    await page.click('.ocu-dialog-actions .ocu-button-destructive');
    await dialogClosed(page);
    await page.waitForFunction((selector) => document.querySelectorAll(selector).length === 0, { timeout: SEND_MS }, ROW_SELECTOR);
    assert.equal(savedCount(), '0', 'the vendor\'s own table holds no row of the probe case');
    assert.equal(probe('RLEFT3', `##class(${PROBE}).ReportLeft("${NS}")`).value, '0', 'and none naming the probe schema');
    assert.equal(await statusLine(page), STRINGS.sqlReportsDeleteDone, 'the page says the saved query was deleted');
  } finally {
    await context.close();
  }
});

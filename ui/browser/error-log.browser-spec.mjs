/**
 * The application error log in a real browser, against the throwaway instance: the full drill --
 * namespaces to dates to errors to one error's captured variable table (AC3) -- and the two things
 * jsdom cannot show, that each level is a rendered table and that the detail renders in place
 * rather than in a dialog (AC5).
 *
 * **It writes nothing.** Every level is a read; the instance already holds errors, because the
 * installer's own `SeedApplicationError` puts one in on every start. There is no seeding step and
 * no teardown. The one class that writes an application error is `OcuPilot.Test.ErrorLogSeed`, and
 * it runs under its own arming variable; this spec creates no principal either -- AC6's denials are
 * `OcuPilot.Test.ErrorLogDenial`'s, over HTTP with real principals.
 *
 * **DW-273 constrains how a row is opened.** The table frame collapses to header height, so a real
 * pointer click at a row's centre lands on the footer; every drill step here dispatches a synthetic
 * click on the row's own link, as the audit, users, tasks and processes specs do.
 *
 * **The three scope-naming empty states are not asserted here, and could not be.** Each level's
 * empty state is reachable only when the level below it holds nothing, and the port refuses a
 * namespace or a date the instance's own enumerations do not carry -- so on an instance that
 * records errors at all, no level this drill can reach renders one. `error-log.page.spec.ts` drives
 * all three against a stub that answers zero rows, which is where the scope resolution is pinned.
 *
 * Run: `npm run test:browser` (after `npm run build` and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { ROW_SELECTOR, viewCount } from './list-spec.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const SCREEN_URL = '/ocupilot/logs/errors';

/** The drill's own parts, so a markup change is one edit. */
const BACK_BUTTON = '[data-ocu-drill="back"]';
const SCOPE_LINE = '[data-ocu-drill="scope"]';
const LEVEL_FRAME = '[data-ocu-level]';
const SECTION_FRAME = '[data-ocu-section]';

let browser = null;

before(async () => {
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
});

/** A fresh context signed in through the shell's own form at the screen's deep link, reads counted. */
async function signedInAtScreen() {
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  const reads = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.pathname.startsWith('/api/ocupilot/logs/errors/')) reads.push(url.pathname + url.search);
  });
  await page.goto(`${config.origin}${SCREEN_URL}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', config.username);
  await page.type('#ocu-signin-password', config.password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await settled(page, 'namespaces');
  return { context, page, reads };
}

/**
 * Wait until the page is on `level` **and** that level's read has landed -- rows rendered, or the
 * empty state, or the detail's sections.
 *
 * The level attribute alone is not enough: it is on the frame the moment the store switches level,
 * which is before the request it issued has answered, so a test that waited on it would read an
 * empty grid and report the page as having no columns.
 */
async function settled(page, level) {
  await page.waitForFunction(
    (frame, rowSelector, sectionSelector, wanted) => {
      const node = document.querySelector(frame);
      if (node === null || node.getAttribute('data-ocu-level') !== wanted) return false;
      if (wanted === 'detail') return document.querySelector(sectionSelector) !== null;
      return (
        document.querySelector(rowSelector) !== null ||
        document.querySelector('.ocu-data-table-empty') !== null
      );
    },
    { timeout: config.navigationTimeoutMs },
    LEVEL_FRAME,
    ROW_SELECTOR,
    SECTION_FRAME,
    level
  );
}

/** The level the page says it is on, read from the frame's own attribute. */
function levelOf(page) {
  return page.evaluate((selector) => document.querySelector(selector)?.getAttribute('data-ocu-level') ?? '', LEVEL_FRAME);
}

/** The column headers the current level renders. */
function headersOf(page) {
  return page.$$eval('[role="grid"] [role="columnheader"]', (cells) =>
    cells.map((cell) => cell.textContent.trim())
  );
}

/** The first cell of every rendered row. */
function firstCells(page) {
  return page.$$eval(ROW_SELECTOR, (rows) =>
    rows.map((row) => row.querySelector('[role="gridcell"]')?.textContent?.trim() ?? '')
  );
}

/**
 * Open the row whose first cell reads `text` and wait until the page says it is on `nextLevel`.
 *
 * The click is dispatched on the row's own link in page, for DW-273's reason; the wait is on the
 * level attribute rather than on a row appearing, so a level that answers zero rows is still a
 * drill this helper can complete.
 */
async function drillInto(page, text, nextLevel) {
  await page.evaluate(
    (rowSelector, wanted) => {
      const row = Array.from(document.querySelectorAll(rowSelector)).find(
        (candidate) => candidate.querySelector('[role="gridcell"]')?.textContent?.trim() === wanted
      );
      const link = row.querySelector('.ocu-data-table-link');
      link.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, button: 0 }));
    },
    ROW_SELECTOR,
    text
  );
  await settled(page, nextLevel);
}

test('AC3: the drill walks namespaces to dates to errors, each level a table with its own columns', async () => {
  const { context, page, reads } = await signedInAtScreen();
  try {
    assert.equal(await levelOf(page), 'namespaces', 'the screen opens on the namespaces level');
    assert.deepEqual(await headersOf(page), [STRINGS.headerNamespaceLabel], 'whose one column is the namespace');
    const namespaces = await firstCells(page);
    assert.ok(namespaces.length > 0, `the instance records errors for at least one namespace: ${JSON.stringify(namespaces)}`);
    assert.ok(
      (await viewCount(page)) === namespaces.length,
      'and the grid declares the row count it rendered'
    );
    // No Back from the first level: there is nowhere above it.
    assert.equal(await page.$(BACK_BUTTON), null, 'the first level offers no Back');

    await drillInto(page, namespaces[0], 'dates');
    assert.deepEqual(
      await headersOf(page),
      [STRINGS.errorLogColumnDate, STRINGS.errorLogColumnCount],
      'the dates level renders the date and its count'
    );
    assert.equal(
      await page.$eval(SCOPE_LINE, (node) => node.textContent.trim()),
      namespaces[0],
      'and the scope line names the namespace drilled to'
    );
    const dates = await firstCells(page);
    assert.ok(dates.length > 0, `that namespace records errors on at least one date: ${JSON.stringify(dates)}`);

    await drillInto(page, dates[0], 'list');
    assert.deepEqual(
      await headersOf(page),
      [
        STRINGS.errorLogColumnNumber,
        STRINGS.auditColumnTime,
        STRINGS.errorLogColumnText,
        STRINGS.processColumnRoutine,
        STRINGS.errorLogColumnLine,
        STRINGS.processColumnUser,
        STRINGS.processColumnPid,
      ],
      'the errors level renders the summary projection'
    );
    const errorRow = await page.$$eval(ROW_SELECTOR, (rows) =>
      Array.from(rows[0].querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim())
    );
    assert.ok(errorRow[0] !== '', 'each error shows its number');
    assert.ok(errorRow[1] !== '', 'and its time');
    assert.ok(errorRow[2] !== '', `and its error text: ${JSON.stringify(errorRow[2])}`);

    // Every call this screen made carried its own namespace parameter and no route scope.
    assert.ok(reads.length >= 3, `three levels were read: ${JSON.stringify(reads)}`);
    assert.ok(
      reads.every((path) => !path.includes('ns=')),
      `and none of them carried a route scope: ${JSON.stringify(reads)}`
    );
    assert.ok(
      reads.some((path) => path.startsWith('/api/ocupilot/logs/errors/list?namespace=')),
      `the errors level named its own namespace: ${JSON.stringify(reads)}`
    );
  } finally {
    await context.close();
  }
});

test('AC5: one error opens its captured variable table in place, and Back returns through every level', async () => {
  const { context, page } = await signedInAtScreen();
  try {
    const namespaces = await firstCells(page);
    await drillInto(page, namespaces[0], 'dates');
    const dates = await firstCells(page);
    await drillInto(page, dates[0], 'list');
    const errors = await firstCells(page);
    assert.ok(errors.length > 0, 'the date records at least one error');

    await drillInto(page, errors[0], 'detail');
    const sections = await page.$$eval(SECTION_FRAME, (frames) =>
      frames.map((frame) => frame.getAttribute('data-ocu-section'))
    );
    assert.deepEqual(
      sections,
      [STRINGS.errorLogDetailExpressions, STRINGS.errorLogDetailStack, STRINGS.errorLogDetailVariables],
      'the detail renders the three captured sections'
    );
    // In place, never in a dialog: Dialog is 440px fixed and single-action, which a variable table
    // of several hundred rows fits none of.
    assert.equal(await page.$('[role="dialog"]'), null, 'and renders no dialog');

    const variables = await page.$$eval(
      `${SECTION_FRAME} .ocu-data-table-body [role="row"]`,
      (rows) => rows.length
    );
    assert.ok(variables > 0, `with the captured rows on screen: ${variables}`);
    const hasRoles = await page.evaluate(
      (selector, wanted) => {
        const frame = Array.from(document.querySelectorAll(selector)).find(
          (candidate) => candidate.getAttribute('data-ocu-section') === wanted
        );
        return frame === undefined ? false : /\$ROLES|\$Roles/.test(frame.textContent);
      },
      SECTION_FRAME,
      STRINGS.errorLogDetailExpressions
    );
    assert.equal(hasRoles, true, 'including the identity the user reads on screen and the agent never does (AD-48)');

    // Back walks the drill up one level at a time, and the scope line shrinks with it.
    await page.click(BACK_BUTTON);
    await settled(page, 'list');
    await page.click(BACK_BUTTON);
    await settled(page, 'dates');
    await page.click(BACK_BUTTON);
    await settled(page, 'namespaces');
    assert.equal(await page.$(BACK_BUTTON), null, 'and the first level offers no Back again');
  } finally {
    await context.close();
  }
});

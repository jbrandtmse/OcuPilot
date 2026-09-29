/**
 * Story 16.5 in a real browser, against the throwaway instance: the Background tasks list and its
 * Cancel task row action (AD-5, AD-53).
 *
 * What it pins: Background tasks is the fifth Tasks side-bar entry; a Management Portal compact this
 * spec seeds and pauses is listed under the declared headers as "Compact DB Space" from the
 * Management Portal, in %SYS, Paused; Cancel task opens the warning dialog titled with the verb and
 * stating the published consequence, whose Cancel sends nothing and whose Proceed sends one request,
 * after which the row reads Cancelled with the Changed tag. With the warning open, the screen passes
 * the structural and contrast checks at 1280 light, 720 light and 1280 dark, with no entry beyond
 * the baseline (DW-1337).
 *
 * **It creates a database and starts, pauses and cancels a compact of it**, so it runs on a throwaway
 * only. It seeds through `OcuPilot.Test.BackgroundSeed.PausedCompact()` over `docker exec`, and its
 * `after` hook calls that class's `Remove()`, whatever the tests answered.
 *
 * Run: `node --test --test-concurrency=1 browser/background-tasks.browser-spec.mjs` (after
 * `npm run build`, the bundle copied into the throwaway, and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const ROUTE = 'tasks/background';
const LIST_URL = `/ocupilot/${ROUTE}?ns=HSCUSTOM`;
const ACTION_PATH = '/api/ocupilot/screens/tasks.background/action';
const SEED = 'OcuPilot.Test.BackgroundSeed';
const DATABASE = 'OCUBGSEED';
const CHANGED_ROW = '.ocu-data-table-row-changed';

let browser = null;

/** Seed a paused portal compact, answering its job number. */
function seedPausedCompact() {
  const output = runIris(config.container, [
    `Set sc=##class(${SEED}).PausedCompact(.job,.task)`,
    'Write "OCU-BGSEED-START:"_$Select($System.Status.IsOK(sc):"ok#"_job,1:$System.Status.GetErrorText(sc))_":OCU-BGSEED-END",!',
  ]);
  const value = markerValue(output, 'BGSEED');
  assert.ok(value !== null && value.startsWith('ok#'), `a paused compact is seeded: ${output}`);
  return value.slice(3);
}

/** Remove the seeded database and every task over it. */
function removeSeed() {
  const output = runIris(config.container, [
    `Set sc=##class(${SEED}).Remove()`,
    'Write "OCU-BGREMOVE-START:"_$Select($System.Status.IsOK(sc):"ok",1:$System.Status.GetErrorText(sc))_":OCU-BGREMOVE-END",!',
  ]);
  assert.equal(markerValue(output, 'BGREMOVE'), 'ok', `the seed is removed: ${output}`);
}

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/**
 * The DW-1337 walk of this screen at 1280 light, 720 light and 1280 dark, answering every entry the
 * baseline does not already hold; with `dialog`, the open dialog's body is also held to scrolling
 * nothing sideways, which the walk skips inside a scroll container.
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

/** Signed in at the list with its rows rendered, recording every request to the action route. */
async function atList() {
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const posts = [];
  page.on('request', (request) => {
    if (new URL(request.url()).pathname === ACTION_PATH) posts.push({ method: request.method(), body: request.postData() ?? '' });
  });
  await waitForRows(page, config.navigationTimeoutMs);
  return { context, page, posts };
}

/** Every rendered row's cells, in row order. */
function rowCells(page) {
  return page.evaluate((rowSelector) => {
    return Array.from(document.querySelectorAll(rowSelector)).map((row) => Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim()));
  }, ROW_SELECTOR);
}

/** Filter the list to the seeded database's one row and select it. */
async function selectSeeded(page) {
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, DATABASE);
  await page.waitForFunction(
    (rowSelector, filterSelector, wanted) => {
      if (document.querySelector(filterSelector)?.value !== wanted) return false;
      const rows = Array.from(document.querySelectorAll(rowSelector));
      return rows.length === 1 && rows[0].textContent.includes(wanted);
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    FILTER_SELECTOR,
    DATABASE
  );
  await clickRowCentre(page, { index: 0, cell: 1 });
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

before(async () => {
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec starts and cancels a compact, so it runs only in a throwaway; ${config.container} is not one`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (/-ci$/.test(config.container)) removeSeed();
  } finally {
    if (browser !== null) await browser.close();
  }
});

// AC1. Mutation (Rule 19): declare Background tasks' sideBarPosition 4 -> the side-bar order goes red.
test('AC1: Background tasks is the fifth Tasks entry, and a seeded compact is listed as the portal reports it', async () => {
  seedPausedCompact();
  const { context, page } = await atList();
  try {
    // A rail click opens the area's side bar without navigating (`shell-state.ts`'s `activateArea`).
    await page.click(`.ocu-rail-item[aria-label="${STRINGS.navAreaTasks}"]`);
    await page.waitForFunction(
      (label) => Array.from(document.querySelectorAll('.ocu-side-bar-label')).some((node) => node.textContent.trim() === label),
      { timeout: config.navigationTimeoutMs },
      STRINGS.backgroundTaskListLabel
    );
    const labels = await page.$$eval('.ocu-side-bar-item .ocu-side-bar-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(
      labels,
      [STRINGS.taskListLabel, STRINGS.taskOnDemandLabel, STRINGS.taskUpcomingLabel, STRINGS.taskHistoryLabel, STRINGS.backgroundTaskListLabel],
      'the side bar lists Background tasks fifth'
    );
    const headers = await page.$$eval('.ocu-data-table-header-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(
      headers.slice(0, 7),
      [
        STRINGS.proposalEntityTask,
        STRINGS.auditEventFieldSource,
        STRINGS.taskHistoryColumnStatus,
        STRINGS.headerNamespaceLabel,
        STRINGS.backgroundTaskColumnDetails,
        STRINGS.backgroundTaskColumnErrorCount,
        STRINGS.taskStartTime,
      ],
      'the declared headers, ahead of the row actions'
    );
    const row = (await rowCells(page)).find((cells) => cells[4]?.startsWith(DATABASE));
    assert.ok(row !== undefined, `the seeded compact is listed: ${JSON.stringify(await rowCells(page))}`);
    assert.deepEqual(row.slice(0, 4), ['Compact DB Space', 'Management Portal', 'Paused', '%SYS'], 'as the portal\'s compact, in %SYS, paused');
  } finally {
    await context.close();
    removeSeed();
  }
});

// AC2. Mutation (Rule 19): remove `cancel` from WARNING_CONSEQUENCES' BackgroundTaskList entry, then
// rebuild and redeploy -> no warning opens, the request is sent at once, and the dialog wait fails.
test('AC2: Cancel task warns first, its Cancel sends nothing, its Proceed sends one request and the row reads Cancelled, changed; the warning passes DW-1337', async () => {
  const job = seedPausedCompact();
  const { context, page, posts } = await atList();
  try {
    await selectSeeded(page);
    await rowAction(page, STRINGS.backgroundTaskCancelAction);
    await page.waitForSelector('app-warning-dialog', { timeout: config.navigationTimeoutMs });
    const opened = await page.evaluate(() => {
      const surface = document.querySelector('[role="dialog"]');
      return {
        title: (surface.querySelector('.ocu-dialog-title')?.textContent ?? '').trim(),
        body: (surface.querySelector('.ocu-warning-consequence')?.textContent ?? '').trim(),
        proceed: (surface.querySelector('.ocu-dialog-actions .ocu-button-primary')?.textContent ?? '').trim(),
        destructive: surface.querySelector('.ocu-button-destructive') !== null,
      };
    });
    assert.equal(opened.title, STRINGS.backgroundTaskCancelAction, 'the warning is titled with the verb');
    assert.equal(opened.body, STRINGS.backgroundTaskCancelConsequence, 'and states the published consequence');
    assert.equal(opened.proceed, STRINGS.actionProceed, 'Proceed is the button-primary');
    assert.equal(opened.destructive, false, 'never a destructive one');

    assert.deepEqual(await structural(page, true), [], 'with the warning open, no violation beyond the baseline\'s entries');

    // The dialog's own Cancel dismisses it and sends nothing.
    await page.evaluate((label) => {
      const buttons = Array.from(document.querySelectorAll('[role="dialog"] .ocu-dialog-actions button'));
      buttons.find((button) => button.textContent.trim() === label).click();
    }, STRINGS.actionCancel);
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await frames(page);
    assert.equal(posts.length, 0, 'the dialog\'s Cancel sends nothing');

    await rowAction(page, STRINGS.backgroundTaskCancelAction);
    await page.waitForSelector('app-warning-dialog', { timeout: config.navigationTimeoutMs });
    await page.click('[role="dialog"] .ocu-dialog-actions .ocu-button-primary');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await page.waitForFunction(
      (changed, status, tag) => {
        const row = document.querySelector(changed);
        return row !== null && (row.textContent ?? '').includes(status) && (row.textContent ?? '').includes(tag);
      },
      { timeout: config.navigationTimeoutMs },
      CHANGED_ROW,
      'Cancelled',
      STRINGS.tableChangedTag
    );
    assert.equal(posts.length, 1, `exactly one request, sent at Proceed: ${JSON.stringify(posts)}`);
    assert.equal(posts[0].method, 'POST');
    assert.deepEqual(JSON.parse(posts[0].body), { action: 'cancel', id: `Management Portal\u0001${job}` });
  } finally {
    await context.close();
    removeSeed();
  }
});

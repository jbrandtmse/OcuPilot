/**
 * Story 20.34 in a real browser, against the throwaway instance: Analytics' Cube manager and its Build and Synchronize row actions
 * (AD-5, AD-8, AD-29, AD-51, AD-53, AD-65).
 *
 * What it pins: in `USER`, whose probe cubes this spec creates (and for which it turns analytics on), the Cube manager lists each cube with
 * its facts, last build and update, whether it synchronizes, whether it is updating and the cubes that depend on it; Build on Categories
 * asks for the cube's name typed, states what it does, rebuilds Categories and its dependent Visits, lists the two facts lines the
 * instance answered, and the rows show the new last build without a reload, as the Cubes list then does; Synchronize on Visits after ten
 * changed rows is sent at once and lists the ten changes; Synchronize on Categories, whose source records no changes, shows the published
 * sentence; and the screen passes the structural and contrast checks at 1280 light, 720 light and 1280 dark, with three suggested prompts.
 *
 * **It turns analytics on for `USER` and builds, changes and rebuilds cubes there** through `OcuPilot.Test.AnalyticsProbe`, so it runs on a
 * throwaway only; the `after` hook removes all of it and restores `USER`'s flags, whatever the tests answered.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/analytics-cube-manager.browser-spec.mjs` (after `npm run build` and the bundle copied into
 * the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { settleViewport, signedInAt, transitionsSettled } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { escapeOs, markerValue, runIris } from './turnprobe-spec.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { SCREENS } = await import(join(uiRoot, 'src', 'app', 'core', 'screens.generated.ts'));
const { stringFor } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const STRINGS = loadStrings();
const PROBE = 'OcuPilot.Test.AnalyticsProbe';
const VISITS = 'OcuPilotProbeVisits';
const CATEGORIES = 'OcuPilotProbeCategories';
const MANAGER = 'analytics/cube-manager';
const CUBES = 'analytics/cubes';
const url = (route) => `/ocupilot/${route}?ns=USER`;
/** The walk's own emulation: a measurement taken mid-transition reads neither theme. */
const REDUCED_MOTION = [{ name: 'prefers-reduced-motion', value: 'reduce' }];
/** The columns of a manager row. */
const [NAME, CAPTION, FACTS, LAST_BUILD, LAST_UPDATE, SYNCHRONIZES, UPDATING, DEPENDENTS] = [0, 1, 2, 3, 4, 5, 6, 7];

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

/** Every body row's cells, each as its trimmed text, with the thousands separators of a number cell removed. */
function allRows(page) {
  return page.evaluate(
    (rowSelector) =>
      Array.from(document.querySelectorAll(rowSelector)).map((row) =>
        Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim().replace(/^(\d{1,3}(,\d{3})+)$/, (digits) => digits.replace(/,/g, '')))
      ),
    ROW_SELECTOR
  );
}

/** The probe row named `name`, or `undefined`. */
async function rowNamed(page, name) {
  // A row the instance has just changed carries its marker and read-back in its name cell, so the name leads the cell.
  return (await allRows(page)).find((row) => row[NAME].startsWith(name));
}

/** The screen has answered the navigation map and drawn its rows. */
async function answered(page) {
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  await waitForRows(page, config.navigationTimeoutMs);
}

/** Wait until the row `name` reads something other than `before` in `column`. */
function rowMoves(page, name, column, before) {
  return page.waitForFunction(
    (rowSelector, wanted, at, was) => {
      const row = Array.from(document.querySelectorAll(rowSelector)).find((candidate) => candidate.querySelector('[role="gridcell"]')?.textContent.trim().startsWith(wanted));
      const text = row?.querySelectorAll('[role="gridcell"]')[at]?.textContent.trim();
      return text !== undefined && text !== was;
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name,
    column,
    before
  );
}

/** Select the row named `name` by its Caption cell (the second, a non-link cell), open its menu and choose the entry labeled `label`. */
async function rowAction(page, name, label) {
  await clickRowCentre(page, { text: name, cell: CAPTION + 1 });
  await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
  const labels = await page.$$eval('[role="menu"] [role="menuitem"] .ocu-data-table-menu-label', (items) => items.map((item) => item.textContent.trim()));
  await page.evaluate((wanted) => {
    Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'))
      .find((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted)
      .click();
  }, label);
  return labels;
}

/** The open typed-name dialog's title and consequence. */
async function typedNameDialog(page) {
  await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
  return page.evaluate(() => ({
    title: document.querySelector('[role="dialog"] .ocu-dialog-title').textContent.trim(),
    consequence: document.querySelector('.ocu-typed-name-consequence').textContent.trim(),
    released: document.querySelector('[role="dialog"] .ocu-button-destructive')?.getAttribute('aria-disabled'),
  }));
}

/** The lines of the outcome dialog once it stands. */
async function outcome(page) {
  await page.waitForSelector('[role="dialog"] [data-ocu-outcome]', { visible: true, timeout: config.navigationTimeoutMs });
  return page.evaluate(() => ({
    title: document.querySelector('[role="dialog"] .ocu-dialog-title').textContent.trim(),
    lines: Array.from(document.querySelectorAll('[role="dialog"] [data-ocu-outcome] li')).map((item) => item.textContent),
  }));
}

/** Close the dialog that stands with its Close. */
async function closeDialog(page) {
  await page.evaluate(() => document.querySelector('[role="dialog"] .ocu-dialog-actions .ocu-button-secondary').click());
  await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
}

/** Open the Analytics side bar if it is shut, then click its entry named `label` with a real pointer. */
async function openEntry(page, label) {
  if ((await page.$('.ocu-side-bar-item')) === null) await page.click('#ocu-rail-item-analytics');
  await page.waitForFunction(
    (wanted) => [...document.querySelectorAll('.ocu-side-bar-item .ocu-side-bar-label')].some((node) => node.textContent.trim() === wanted),
    { timeout: config.navigationTimeoutMs },
    label
  );
  const index = await page.evaluate(
    (wanted) => [...document.querySelectorAll('.ocu-side-bar-item')].findIndex((node) => node.querySelector('.ocu-side-bar-label').textContent.trim() === wanted),
    label
  );
  await page.click(`.ocu-side-bar-item:nth-of-type(${index + 1})`);
}

/** Pause `ms` milliseconds, so two builds never share the second a last build reads to. */
function pause(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec turns analytics on in USER and builds cubes there, so it runs only in a throwaway; ${config.container} is not one`);
  const removed = probe('CMCLEAN', `$System.Status.IsOK(##class(${PROBE}).Remove())`);
  assert.equal(removed.value, '1', `an earlier run's probe is removed: ${removed.output}`);
  created = true; // from here on, `after` removes whatever the probe made, even when Enable or Create fails part-way
  const enabled = probe('CMENABLE', `$System.Status.IsOK(##class(${PROBE}).Enable())`);
  assert.equal(enabled.value, '1', `analytics is turned on for USER: ${enabled.output}`);
  const made = probe('CMMADE', `$System.Status.IsOK(##class(${PROBE}).Create("${escapeOs(config.username)}"))`);
  assert.equal(made.value, '1', `the probe cubes are created: ${made.output}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (created && /-ci$/.test(config.container)) {
      const removed = probe('CMGONE', `$System.Status.IsOK(##class(${PROBE}).Remove())_##class(${PROBE}).Gone()`);
      assert.equal(removed.value, '11', `the probe is removed and USER is left as found: ${removed.output}`);
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

// AC1, AC7. Mutation (Rule 19): answer OK without calling the vendor in `AnalyticsPort.VendorBuild` (reload the class) -> the rows' last build
// never moves and the Cubes leg goes red; drop `OUTCOME_ACTIONS` from the handler, rebuild and redeploy -> no outcome stands and the lines leg
// goes red.
test('AC1, AC7: Build on Categories asks for its name typed, lists the two facts lines, and the rows and the Cubes list show the new last build with no reload', async () => {
  const { context, page } = await signedInAt(browser, config, url(MANAGER), VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await answered(page);
    await page.evaluate(() => {
      window.__ocuNoReload = 'standing';
    });
    const first = await rowNamed(page, CATEGORIES);
    const visits = await rowNamed(page, VISITS);
    assert.deepEqual(
      [first[FACTS], first[SYNCHRONIZES], first[UPDATING], first[DEPENDENTS], visits[FACTS], visits[SYNCHRONIZES], visits[DEPENDENTS]],
      ['5', STRINGS.tableStatusNo, STRINGS.tableStatusNo, VISITS, '1000', STRINGS.tableStatusYes, STRINGS.tableEmptyValue],
      'the manager shows the facts, whether each synchronizes, that none is updating and Categories\' dependent cube'
    );
    await pause(1500);
    const menu = await rowAction(page, CATEGORIES, STRINGS.aboutBuild);
    assert.deepEqual(menu, [STRINGS.aboutBuild, STRINGS.actionSynchronize], 'the row menu offers Build and Synchronize');
    const dialog = await typedNameDialog(page);
    assert.deepEqual(
      [dialog.title, dialog.consequence, dialog.released],
      [`${STRINGS.aboutBuild} ${CATEGORIES}`, STRINGS.analyticsCubeBuildConsequence, 'true'],
      'Build asks for the cube\'s name and states what it does, and is unavailable until it is typed'
    );
    await page.type('.ocu-typed-name-field', CATEGORIES);
    await page.keyboard.press('Enter');
    const answer = await outcome(page);
    assert.deepEqual(answer.lines, [`Facts in ${CATEGORIES}: 5`, `Facts in ${VISITS}: 1000`], 'the dialog lists the two facts lines');
    assert.equal(answer.title, `${STRINGS.aboutBuild} ${CATEGORIES}`, 'under the action and the cube');
    await closeDialog(page);
    await rowMoves(page, CATEGORIES, LAST_BUILD, first[LAST_BUILD]);
    await rowMoves(page, VISITS, LAST_BUILD, visits[LAST_BUILD]);
    assert.equal(await page.evaluate(() => window.__ocuNoReload), 'standing', 'the rows re-read without the page reloading');
    const built = await rowNamed(page, CATEGORIES);
    assert.deepEqual([built[FACTS], built[LAST_BUILD] === built[LAST_UPDATE]], ['5', true], 'Categories holds its facts and its last build is its last update');

    await openEntry(page, STRINGS.analyticsCubesLabel);
    await page.waitForFunction((wanted) => new URL(window.location.href).pathname.includes(wanted), { timeout: config.navigationTimeoutMs }, `/${CUBES}`);
    await answered(page);
    const listed = (await allRows(page)).find((row) => row[0].startsWith(CATEGORIES));
    assert.deepEqual([listed[3], listed[4]], [built[LAST_BUILD], '5'], 'the Cubes list shows the same last build and facts');
  } finally {
    await context.close();
  }
});

// AC2. Mutation (Rule 19): call `%BuildCube` from `AnalyticsPort.VendorSynchronize` (reload the class) -> the line reads 1000 and this goes
// red; add `synchronize` to `DESTRUCTIVE_ACTIONS` in the handler, rebuild and redeploy -> the dialog stands first and the outcome wait times out.
test('AC2: Synchronize on Visits after ten changed rows is sent at once and lists the ten changes', async () => {
  const changed = probe('CMCHANGE', `$System.Status.IsOK(##class(${PROBE}).ChangeVisits(10))`);
  assert.equal(changed.value, '1', `ten Visit rows are changed: ${changed.output}`);
  const { context, page } = await signedInAt(browser, config, url(MANAGER), VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await answered(page);
    const visits = await rowNamed(page, VISITS);
    await pause(1500);
    await rowAction(page, VISITS, STRINGS.actionSynchronize);
    const answer = await outcome(page);
    assert.deepEqual(answer.lines, [`Facts updated in ${VISITS}: 10`], 'the dialog lists the ten changes, with no dialog before it');
    await closeDialog(page);
    await rowMoves(page, VISITS, LAST_UPDATE, visits[LAST_UPDATE]);
    const after = await rowNamed(page, VISITS);
    assert.deepEqual([after[FACTS], after[LAST_BUILD]], ['1000', visits[LAST_BUILD]], 'Visits keeps its facts and its last build');
  } finally {
    await context.close();
  }
});

// AC3. Mutation (Rule 19): skip the `Synchronizes` test in `AnalyticsPort.StateRefusal` (reload the class) -> the vendor answers its own error and
// the banner shows the FAILED sentence, so this goes red.
test('AC3: Synchronize on Categories, whose source records no changes, shows the published sentence and opens no dialog', async () => {
  const { context, page } = await signedInAt(browser, config, url(MANAGER), VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await answered(page);
    await rowAction(page, CATEGORIES, STRINGS.actionSynchronize);
    await page.waitForSelector('.ocu-list-page-banner .ocu-banner-message', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-list-page-banner .ocu-banner-message', (node) => node.textContent.trim()), STRINGS.analyticsRefusalCubeNoDstime, 'the refusal shows the published sentence');
    assert.equal(await page.$('[role="dialog"]'), null, 'and no dialog stands');
  } finally {
    await context.close();
  }
});

// AC6. Mutation (Rule 19): give `.ocu-data-table-cell` the colour `var(--ocu-surface-container-high)` in `styles/_components.scss` -> the
// `analytics/cube-manager|contrast` entries are fresh and this goes red; rebuild and redeploy first.
test('AC6: the Cube manager passes the structural and contrast checks at 1280 light, 720 light and 1280 dark, and offers three suggested prompts', async () => {
  const declared = SCREENS.find((screen) => screen.route === MANAGER);
  assert.ok(declared !== undefined, 'the mirror declares the Cube manager');
  assert.equal(declared.suggestedPrompts.length, 3, 'with three suggested prompts');
  for (const prompt of declared.suggestedPrompts) assert.notEqual(stringFor(prompt.textKey), '', `${prompt.textKey} is a published string`);
  const { context, page } = await signedInAt(browser, config, url(MANAGER), VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await answered(page);
    assert.deepEqual(await structural(page, MANAGER), [], `${MANAGER}: no violation beyond the baseline's entries`);
  } finally {
    await context.close();
  }
});

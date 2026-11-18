/**
 * Story 20.11 in a real browser, against the throwaway instance: Analytics' Cubes with a cube's model tabs, Term lists with a
 * list's entries, and Folder items (AD-5, AD-8, AD-29, AD-36, AD-44, AD-65).
 *
 * What it pins: in `USER`, whose probe analytics objects this spec creates (and for which it turns analytics on), the side bar's
 * Analytics entries are Cubes, Term lists and Folder items, then the three links Story 20.32 adds (`analytics-links.browser-spec.mjs` pins
 * them), then MDX query (Story 20.33, `analytics-mdx.browser-spec.mjs`), and each list's rows equal what the vendor's own classes answer; a Cubes
 * name cell opens the cube's Measures tab under a strip of Measures, Dimensions and Relationships, the Relationships row opens the
 * related cube's Measures tab, and a Term lists name cell opens the list's entries with the `Note` field shown; a cube or term list no
 * one holds draws its tab's own empty sentence and no row; in `HSCUSTOM`, which
 * is not analytics-enabled, a direct Cubes route shows the refusal sentence; and each of the seven screens passes the structural and
 * contrast checks at 1280 light, 720 light and 1280 dark, with no entry beyond the baseline (DW-1337).
 *
 * **It turns analytics on for `USER`, compiles cubes and writes a term list and folder items there** through
 * `OcuPilot.Test.AnalyticsProbe`, so it runs on a throwaway only; the `after` hook removes all of it and restores `USER`'s flags,
 * whatever the tests answered.
 *
 * Story 24.11 adds one test: Listing groups lists the probe's listing groups with what the vendor's model reads, a name cell opens the group's Listings,
 * and both screens pass the structural and contrast checks.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/analytics.browser-spec.mjs` (after `npm run build` and the bundle copied into the
 * throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
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
const { encodeEntityId } = await import(join(uiRoot, 'src', 'app', 'core', 'entity-id.ts'));

const config = browserConfig();
const STRINGS = loadStrings();
const PROBE = 'OcuPilot.Test.AnalyticsProbe';
const VISITS = 'OcuPilotProbeVisits';
const CATEGORIES = 'OcuPilotProbeCategories';
const TERMS = 'OcuPilotProbeTerms';
const CUBES = 'analytics/cubes';
const GROUP = `${CUBES}/document`;
const DIMENSIONS = `${CUBES}/dimensions`;
const RELATIONSHIPS = `${CUBES}/relationships`;
const TERM_LISTS = 'analytics/term-lists';
const ENTRIES = `${TERM_LISTS}/entries`;
const FOLDER_ITEMS = 'analytics/folder-items';
const LISTING_GROUPS = 'analytics/listing-groups';
const LISTINGS = `${LISTING_GROUPS}/listings`;
const LISTING_GROUP = 'OcuPilotProbeListings';
const FOLDER_PROBE = 'OcuPilot.Test.AnalyticsFolderItemTransfer';
const FOLDER_ITEM = 'OcuProbeFI2410/Browse.dashboard';
const TABS = [
  { route: GROUP, label: STRINGS.analyticsTabMeasures },
  { route: DIMENSIONS, label: STRINGS.analyticsTabDimensions },
  { route: RELATIONSHIPS, label: STRINGS.analyticsTabRelationships },
];
const url = (route) => `/ocupilot/${route}?ns=USER`;
/** The walk's own emulation: the tab strip's label colour transitions, and a measurement taken mid-transition reads neither theme. */
const REDUCED_MOTION = [{ name: 'prefers-reduced-motion', value: 'reduce' }];

let browser = null;
let created = false;
let localDirectory = '';

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** Run `lines` in `USER` and answer the marker `name` they write. */
function inUser(name, lines) {
  const output = runIris(config.container, ['Set $NAMESPACE="USER"', ...lines, `Write "OCU-${name}-START:"_out_":OCU-${name}-END",!`]);
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
        // The cell that holds a row's action menu (Story 24.2's term list screens carry actions) is no column of the data.
        Array.from(row.querySelectorAll('[role="gridcell"]'))
          .filter((cell) => cell.querySelector('.ocu-data-table-trigger') === null)
          .map((cell) => cell.textContent.trim().replace(/^(\d{1,3}(,\d{3})+)$/, (digits) => digits.replace(/,/g, '')))
      ),
    ROW_SELECTOR
  );
}

/** The rows of `allRows` whose first cell starts with `prefix`. */
async function rowsStartingWith(page, prefix) {
  return (await allRows(page)).filter((row) => row[0].startsWith(prefix));
}

/** The screen has answered the navigation map and drawn its rows. */
async function answered(page) {
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  await waitForRows(page, config.navigationTimeoutMs);
}

/** Wait until the page's path holds `suffix`. */
function pathHolds(page, suffix) {
  return page.waitForFunction((wanted) => new URL(window.location.href).pathname.includes(wanted), { timeout: config.navigationTimeoutMs }, suffix);
}

/** The labels of the cube strip's tabs, in order. */
function stripLabels(page) {
  return page.$$eval('button.ocu-detail-tab .ocu-detail-tab-label', (labels) => labels.map((label) => label.textContent.trim()));
}

/** The side bar's entry labels, in order. */
function sideBarLabels(page) {
  return page.$$eval('.ocu-side-bar-item .ocu-side-bar-label', (labels) => labels.map((label) => label.textContent.trim()));
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

/** Open the strip's tab on `route` and wait for its rows. */
async function openTab(page, route) {
  await (await page.waitForSelector(`button.ocu-detail-tab[data-route="${route}"]`, { visible: true, timeout: config.navigationTimeoutMs })).click();
  await pathHolds(page, `/${route}/`);
  await answered(page);
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec turns analytics on in USER and writes cubes there, so it runs only in a throwaway; ${config.container} is not one`);
  const removed = probe('ANCLEAN', `$System.Status.IsOK(##class(${PROBE}).Remove())`);
  assert.equal(removed.value, '1', `an earlier run's probe is removed: ${removed.output}`);
  created = true; // from here on, `after` removes whatever the probe made, even when Enable or Create fails part-way
  const enabled = probe('ANENABLE', `$System.Status.IsOK(##class(${PROBE}).Enable())`);
  assert.equal(enabled.value, '1', `analytics is turned on for USER: ${enabled.output}`);
  const made = probe('ANMADE', `$System.Status.IsOK(##class(${PROBE}).Create("${escapeOs(config.username)}"))`);
  assert.equal(made.value, '1', `the probe cubes, term list and folder items are created: ${made.output}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (localDirectory !== '') rmSync(localDirectory, { recursive: true, force: true });
    if (created && /-ci$/.test(config.container)) {
      runIris(config.container, [`Do ##class(${FOLDER_PROBE}).Sweep()`]);
      const removed = probe('ANGONE', `$System.Status.IsOK(##class(${PROBE}).Remove())_##class(${PROBE}).Gone()`);
      assert.equal(removed.value, '11', `the probe is removed and USER is left as found: ${removed.output}`);
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

// AC1. Mutation (Rule 19): make the Cubes read answer `Facts` as 0 -> the Facts cell of every probe row reads 0 and the Cubes leg goes red;
// drop `Favorite` from the Folder items read -> its favorite cell reads No and the Folder items leg goes red; rebuild and redeploy first
// for a client mutation.
test('AC1: the side bar lists Cubes, Term lists, Folder items, the three links, MDX query and the Cube manager, and each list\'s rows equal the instance\'s', async () => {
  const { context, page } = await signedInAt(browser, config, url(CUBES), VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await answered(page);
    if ((await page.$('.ocu-side-bar-item')) === null) await page.click('#ocu-rail-item-analytics');
    await page.waitForSelector('.ocu-side-bar-item', { timeout: config.navigationTimeoutMs });
    assert.deepEqual(
      await sideBarLabels(page),
      [
        STRINGS.analyticsCubesLabel,
        STRINGS.analyticsTermListsLabel,
        STRINGS.analyticsFolderItemsLabel,
        STRINGS.analyticsArchitectLabel,
        STRINGS.analyticsAnalyzerLabel,
        STRINGS.analyticsUserPortalLabel,
        STRINGS.analyticsMdxQueryLabel,
        STRINGS.analyticsCubeManagerLabel,
        STRINGS.analyticsListingGroupsLabel,
      ],
      'the Analytics side bar lists Cubes, Term lists and Folder items, then the Architect, Analyzer and User Portal links (Story 20.32), then MDX query (Story 20.33), the Cube manager (Story 20.34) and Listing groups (Story 24.11)'
    );

    const cubes = inUser('ANCUBES', [
      'Set sc=##class(%DeepSee.Utils).%GetCubeList(.l,"cubes",1),k="",out=""',
      'For { Set k=$Order(l(k))  Quit:k=""  Set n=$List(l(k),1)  If $Extract(n,1,13)="OcuPilotProbe" Set out=out_n_"~"_$List(l(k),2)_"~"_##class(%DeepSee.Utils).%GetCubeClass(n)_"~"_$Extract(##class(%DeepSee.CubeManager.Utils).GetLastUpdate(n,"build"),1,19)_"~"_##class(%DeepSee.Utils).%GetCubeFactCount(n)_"|" }',
    ]);
    const expectedCubes = cubes.value.split('|').filter((entry) => entry !== '').map((entry) => entry.split('~'));
    assert.equal(expectedCubes.length, 4, `the instance holds the four probe cubes: ${cubes.output}`);
    assert.deepEqual(await rowsStartingWith(page, 'OcuPilotProbe'), expectedCubes, 'Cubes shows each probe cube with the caption, class, last build and fact count the vendor answers');
    assert.deepEqual(expectedCubes.map((entry) => entry[4]).sort(), ['1000', '5', '5', '50000'], 'the Visits cube holds 1,000 facts and the grid cube 50,000');

    await openEntry(page, STRINGS.analyticsTermListsLabel);
    await pathHolds(page, `/${TERM_LISTS}`);
    await answered(page);
    const terms = inUser('ANTERMS', [
      'Set sc=##class(%DeepSee.TermList).%GetTermLists(.l),k="",out=""',
      'For { Set k=$Order(l(k))  Quit:k=""  If $List(l(k),1)="OcuPilotProbeTerms" Set out=$List(l(k),1)_"~"_$List(l(k),2)_"~"_$ZDate($List(l(k),3),3) }',
    ]);
    assert.deepEqual(await rowsStartingWith(page, 'OcuPilotProbe'), [terms.value.split('~')], `Term lists shows the probe list with its caption and modified date: ${terms.output}`);

    await openEntry(page, STRINGS.analyticsFolderItemsLabel);
    await pathHolds(page, `/${FOLDER_ITEMS}`);
    await answered(page);
    const items = inUser('ANITEMS', [
      'Set sc=##class(%DeepSee.UserLibrary.Utils).%GetFolderItemList(.l,"",0,""),k="",out=""',
      `For { Set k=$Order(l(k))  Quit:k=""  Set i=##class(%DeepSee.UserLibrary.FolderItem).%OpenId(l(k))  If $Extract(i.fullName,1,14)="OcuPilotProbe/" Set out=out_i.fullName_"~"_i.%GetTypeName()_"~"_i.owner_"~"_$Select($Data(^DeepSee.UserPreferences("${escapeOs(config.username)}","favorite",i.fullName)):"Yes",1:"No")_"|" }`,
    ]);
    const expectedItems = items.value.split('|').filter((entry) => entry !== '').map((entry) => entry.split('~'));
    const seen = (await rowsStartingWith(page, 'OcuPilotProbe/')).map((row) => [row[0], row[1], row[2], row[4]]);
    assert.deepEqual(seen, expectedItems, 'Folder items shows each probe item with the type, owner and favorite flag the vendor answers');
    assert.deepEqual(
      seen.filter((row) => row[3] === STRINGS.tableStatusYes).map((row) => row[0]),
      ['OcuPilotProbe/Visits.pivot'],
      'and marks the pivot the signed-in person favorited, and no other item'
    );
    const modified = (await rowsStartingWith(page, 'OcuPilotProbe/')).map((row) => row[3]);
    assert.ok(modified.every((value) => /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/.test(value)), `each item's modified time reads as YYYY-MM-DD HH:MM:SS: ${JSON.stringify(modified)}`);
  } finally {
    await context.close();
  }
});

// AC2. Mutation (Rule 19): drop `rowTarget` from AnalyticsCubeRelationshipsTab -> the Relationships name cell is text and the related-cube
// leg goes red; stop joining `%ToObj`'s extra fields into `Fields` -> the Note clause goes red; rebuild and redeploy first.
test('AC2: a Cubes name cell opens the cube\'s model, a Relationships row the related cube\'s, and a Term lists name cell its entries', async () => {
  const { context, page } = await signedInAt(browser, config, url(CUBES), VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await answered(page);
    await clickRowCentre(page, { text: VISITS, link: true });
    await pathHolds(page, `/${GROUP}/${encodeEntityId(VISITS)}`);
    await answered(page);
    assert.deepEqual(await stripLabels(page), TABS.map((tab) => tab.label), 'the strip reads Measures, Dimensions, Relationships');
    const measures = await allRows(page);
    assert.deepEqual(measures.map((row) => [row[0], row[2], row[3]]).sort(), [['%COUNT', 'integer', STRINGS.tableStatusNo], ['Amount', 'number', STRINGS.tableStatusNo], ['Minutes', 'integer', STRINGS.tableStatusYes]].sort(), 'Measures shows the cube\'s three measures, the hidden one marked');

    await openTab(page, DIMENSIONS);
    assert.deepEqual(await stripLabels(page), TABS.map((tab) => tab.label), 'the Dimensions tab carries the same strip');
    assert.deepEqual((await allRows(page)).map((row) => row.join('/')), ['1/Seen/H1/Year', '2/Seen/H1/Month', '3/Place/H1/Category'], 'Dimensions shows one row per level, in model order from 1');

    await openTab(page, RELATIONSHIPS);
    assert.deepEqual(await allRows(page), [['CategoryRel', CATEGORIES]], 'Relationships shows the one relationship and the cube it relates to');
    await clickRowCentre(page, { text: 'CategoryRel', link: true });
    await pathHolds(page, `/${GROUP}/${encodeEntityId(CATEGORIES)}`);
    await answered(page);
    assert.deepEqual((await allRows(page)).map((row) => row[0]), ['%COUNT'], 'the related cube\'s Measures tab opens, showing its one measure');
    assert.deepEqual(await stripLabels(page), TABS.map((tab) => tab.label), 'under the same strip');
  } finally {
    await context.close();
  }
  const termContext = await signedInAt(browser, config, url(TERM_LISTS), VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await answered(termContext.page);
    await clickRowCentre(termContext.page, { text: TERMS, link: true });
    await pathHolds(termContext.page, `/${ENTRIES}/${encodeEntityId(TERMS)}`);
    await answered(termContext.page);
    assert.deepEqual(
      await allRows(termContext.page),
      [['k1', 'Alpha', 'Note: first note'], ['k2', 'Beta', 'Note: second note'], ['k3', 'Gamma', 'Note: third note']],
      'the entries show each key with its value and its Note field'
    );
  } finally {
    await termContext.context.close();
  }
});

// Matrix, Unknown cube. Mutation (Rule 19): point the Measures tab's `emptyStateKey` at `analyticsCubesEmpty` in `AnalyticsCubeMeasuresTab.cls`
// (mirror regenerated, bundle rebuilt and redeployed) -> the Measures leg draws the Cubes sentence and goes red.
test('Matrix: a cube or term list no one holds draws its tab\'s empty sentence and no row', async () => {
  const unknown = 'OcuPilotProbeNoSuchOne';
  const screens = [
    { route: GROUP, empty: STRINGS.analyticsCubeMeasuresEmpty },
    { route: DIMENSIONS, empty: STRINGS.analyticsCubeDimensionsEmpty },
    { route: RELATIONSHIPS, empty: STRINGS.analyticsCubeRelationshipsEmpty },
    { route: ENTRIES, empty: STRINGS.analyticsTermListEntriesEmpty },
  ];
  assert.equal(new Set(screens.map((screen) => screen.empty)).size, screens.length, 'the four screens have four sentences of their own');
  for (const screen of screens) {
    const { context, page } = await signedInAt(browser, config, `/ocupilot/${screen.route}/${encodeEntityId(unknown)}?ns=USER`, VIEWPORTS.wide, REDUCED_MOTION);
    try {
      await waitForMapAnswered(page, config.navigationTimeoutMs);
      await page.waitForSelector('.ocu-data-table-empty-title', { timeout: config.navigationTimeoutMs });
      assert.equal(await page.$eval('.ocu-data-table-empty-title', (node) => node.textContent.trim()), screen.empty, `${screen.route}: the tab draws its own empty sentence`);
      assert.equal((await allRows(page)).length, 0, `${screen.route}: and no row`);
    } finally {
      await context.close();
    }
  }
});

// AC3. Mutation (Rule 19): drop the analytics check from `AnalyticsPort.Admit` -> the read answers 200 with no rows, the 409 wait
// goes red; reload the class first. The page draws the shell's own read refusal, not the sentence: a read refusal's text is the shell's
// (`ReadRefusal`), and the sentence travels on the wire.
test('AC3: a direct Cubes route in a namespace without analytics is refused 409 with the refusal sentence, and draws no row', async () => {
  const reads = [];
  const { context, page } = await signedInAt(browser, config, '/ocupilot/analytics/cubes?ns=HSCUSTOM', VIEWPORTS.wide, REDUCED_MOTION, async (opened) => {
    opened.on('response', (response) => {
      if (new URL(response.url()).pathname.endsWith('/screens/analytics.cubes/read')) reads.push(response.text().catch(() => '').then((body) => ({ status: response.status(), body })));
    });
  });
  try {
    await page.waitForSelector('.ocu-data-table-refusal-message', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-data-table-refusal-message', (node) => node.textContent.trim()), STRINGS.connectivityRequestRefused, 'the page draws the shell\'s read refusal');
    assert.equal((await allRows(page)).length, 0, 'and no row');
    assert.ok(reads.length > 0, 'the Cubes read was issued');
    const read = await reads[0];
    const answer = JSON.parse(read.body);
    assert.equal(read.status, 409, 'and refused 409');
    assert.equal(answer.code, 'ANALYTICS.NAMESPACE', 'with the analytics code');
    assert.equal(answer.reason, STRINGS.analyticsRefusalNamespace, 'and its one sentence');
  } finally {
    await context.close();
  }
});

// AC5. Mutation (Rule 19): give `.ocu-data-table-cell` the colour `var(--ocu-surface-container-high)` in `shell/data-table.ts` -> the
// `analytics/cubes|contrast` entries are fresh and this goes red; rebuild and redeploy first.
test('AC5: each of the seven screens passes the structural and contrast checks at 1280 light, 720 light and 1280 dark', async () => {
  const screens = [
    { route: CUBES, url: url(CUBES) },
    { route: GROUP, url: `/ocupilot/${GROUP}/${encodeEntityId(VISITS)}?ns=USER` },
    { route: DIMENSIONS, url: `/ocupilot/${DIMENSIONS}/${encodeEntityId(VISITS)}?ns=USER` },
    { route: RELATIONSHIPS, url: `/ocupilot/${RELATIONSHIPS}/${encodeEntityId(VISITS)}?ns=USER` },
    { route: TERM_LISTS, url: url(TERM_LISTS) },
    { route: ENTRIES, url: `/ocupilot/${ENTRIES}/${encodeEntityId(TERMS)}?ns=USER` },
    { route: FOLDER_ITEMS, url: url(FOLDER_ITEMS) },
  ];
  for (const screen of screens) {
    const { context, page } = await signedInAt(browser, config, screen.url, VIEWPORTS.wide, REDUCED_MOTION);
    try {
      await answered(page);
      assert.deepEqual(await structural(page, screen.route), [], `${screen.route}: no violation beyond the baseline's entries`);
    } finally {
      await context.close();
    }
  }
});

/** Wait until no row's first cell starts with `name`. */
function rowGone(page, name) {
  return page.waitForFunction(
    (rowSelector, wanted) => !Array.from(document.querySelectorAll(rowSelector)).some((row) => row.querySelector('[role="gridcell"]')?.textContent.trim().startsWith(wanted)),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name
  );
}

/** The first cell's whole text of the row whose first cell starts with `prefix`: a row the instance has just changed carries its marker and read-back there. */
function firstCell(page, prefix) {
  return page.evaluate(
    (rowSelector, wanted) => Array.from(document.querySelectorAll(rowSelector)).map((row) => row.querySelector('[role="gridcell"]')?.textContent.trim()).find((text) => text?.startsWith(wanted)),
    ROW_SELECTOR,
    prefix
  );
}

/** Select the row whose first cell starts with `name`, open its menu and choose the entry labeled `label`; answers the menu's labels. */
async function rowAction(page, name, label) {
  await clickRowCentre(page, { text: await firstCell(page, name), cell: 3 });
  await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
  const labels = await page.$$eval('[role="menu"] [role="menuitem"] .ocu-data-table-menu-label', (items) => items.map((item) => item.textContent.trim()));
  assert.ok(labels.includes(label), `the row menu offers ${label}; it offers ${JSON.stringify(labels)}`);
  await page.evaluate((wanted) => {
    Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'))
      .find((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted)
      .click();
  }, label);
  return labels;
}

/** Wait until the page's transfer status line reads `line`. */
function statusReads(page, line) {
  return page.waitForFunction((wanted) => document.querySelector('[data-folder-item-transfer-status]')?.textContent.trim() === wanted, { timeout: config.navigationTimeoutMs }, line);
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

// Story 24.10, Batch 2. Mutation (Rule 19): send the export's output lines nowhere in `OcuPilot.Screen.Tool.AnalyticsFolderItemExport.WriteOutput` (reload the class) -> no file is
// saved and the export leg goes red; read `Name` in place of `Count` in `folder-item-list.page.ts`, rebuild and redeploy -> the import's status line goes red.
test('Story 24.10: a folder item is exported to this browser, deleted by typing its full name, and imported back from the file this computer holds', async () => {
  localDirectory = mkdtempSync(join(tmpdir(), 'epic-24-2410b-'));
  runIris(config.container, [`Set x=##class(${FOLDER_PROBE}).Item("${FOLDER_ITEM}")`]);
  assert.equal(probe('FIHELD', `##class(${FOLDER_PROBE}).Exists("${FOLDER_ITEM}")`).value, '1', 'the item is saved');
  const { context, page } = await signedInAt(browser, config, url(FOLDER_ITEMS), VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await answered(page);
    await captureDownloads(page);
    const menu = await rowAction(page, FOLDER_ITEM, STRINGS.taskExportAction);
    assert.deepEqual(menu, [STRINGS.taskExportAction, STRINGS.actionDelete], 'the row menu offers Export and Delete');
    await page.waitForSelector('app-explorer-export-dialog .ocu-dialog-title', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('app-explorer-export-dialog .ocu-dialog-title', (node) => node.textContent.trim()), STRINGS.analyticsFolderItemExportTitle.replace('<name>', FOLDER_ITEM), 'the export dialog is titled by the item');
    assert.equal(await page.$eval('[data-explorer-export-replaces]', (node) => node.textContent.trim()), STRINGS.analyticsFolderItemExportHelp, 'and says what the file holds and that a file at the name is replaced');
    await page.waitForSelector('.ocu-dialog-body .ocu-path-picker select', { timeout: config.navigationTimeoutMs });
    await page.click('input[data-explorer-export-destination="browser"]');
    await page.waitForFunction(() => document.querySelector('.ocu-dialog-body .ocu-path-picker') === null, { timeout: config.navigationTimeoutMs });
    await page.click('[data-explorer-export-confirm]');
    await statusReads(page, STRINGS.analyticsTermListExportDone.replace('<name>', FOLDER_ITEM));
    await page.waitForFunction(() => window.__ocuSaved.length === 1, { timeout: config.navigationTimeoutMs });
    const saved = await page.evaluate(() => window.__ocuSaved[0]);
    assert.equal(saved.name, 'OcuProbeFI2410-Browse-dashboard.xml', 'the browser saves the full name, its slash and dot made dashes, as <name>.xml');
    assert.equal(saved.type, 'application/xml');
    assert.ok(saved.text.startsWith('<?xml version="1.0" encoding="UTF-8"?>\n<dashboard ') && saved.text.includes('name="Browse" folderName="OcuProbeFI2410"'), 'the file is the vendor\'s XML export of that one item');

    await rowAction(page, FOLDER_ITEM, STRINGS.actionDelete);
    await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-typed-name-consequence', (node) => node.textContent.trim()), STRINGS.analyticsFolderItemDeleteConsequence, 'Delete states its consequence and asks for the full name typed');
    await page.type('.ocu-typed-name-field', FOLDER_ITEM);
    await page.keyboard.press('Enter');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await rowGone(page, FOLDER_ITEM);
    await statusReads(page, STRINGS.analyticsFolderItemDeleteDone.replace('<name>', FOLDER_ITEM));
    assert.equal(probe('FIGONE', `##class(${FOLDER_PROBE}).Exists("${FOLDER_ITEM}")`).value, '0', 'and the vendor reads the item gone');

    const local = join(localDirectory, 'Browse.xml');
    writeFileSync(local, saved.text, 'utf8');
    await page.waitForFunction(
      (wanted) => Array.from(document.querySelectorAll('.ocu-command-bar-action')).some((button) => button.textContent.trim() === wanted && button.getAttribute('aria-disabled') === null),
      { timeout: config.navigationTimeoutMs },
      STRINGS.actionImport
    );
    await page.evaluate((wanted) => {
      Array.from(document.querySelectorAll('.ocu-command-bar-action')).find((button) => button.textContent.trim() === wanted).click();
    }, STRINGS.actionImport);
    await page.waitForSelector('app-explorer-import-dialog .ocu-dialog-title', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('app-explorer-import-dialog .ocu-dialog-title', (node) => node.textContent.trim()), STRINGS.analyticsFolderItemImportTitle, 'the import dialog is titled in the folder items\' words');
    assert.equal(await page.$eval('[data-explorer-import-replaces]', (node) => node.textContent.trim()), STRINGS.analyticsFolderItemImportHelp, 'it states that the file creates the items it holds');
    await page.waitForSelector('.ocu-dialog-body .ocu-path-picker select', { timeout: config.navigationTimeoutMs });
    await page.click('input[data-explorer-import-source="local"]');
    await page.waitForSelector('input[data-explorer-import-file]', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('input[data-explorer-import-file]', (input) => input.getAttribute('accept')), '.xml,.dfi', 'the file input offers .xml and .dfi files');
    await (await page.$('input[data-explorer-import-file]')).uploadFile(local);
    await page.waitForFunction(() => document.querySelector('[data-explorer-import-confirm]')?.getAttribute('aria-disabled') === null, { timeout: config.navigationTimeoutMs });
    await page.click('[data-explorer-import-confirm]');
    await statusReads(page, STRINGS.analyticsFolderItemImportDone.replace('<count>', '1'));
    assert.equal(probe('FIBACK', `##class(${FOLDER_PROBE}).Exists("${FOLDER_ITEM}")`).value, '1', 'the item is back, and Folder items lists it');
    await page.waitForFunction(
      (rowSelector, wanted) => Array.from(document.querySelectorAll(rowSelector)).some((row) => row.querySelector('[role="gridcell"]')?.textContent.trim().startsWith(wanted)),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      FOLDER_ITEM
    );
  } finally {
    await context.close();
    runIris(config.container, [`Do ##class(${FOLDER_PROBE}).Sweep()`]);
  }
});

// Story 24.11 AC3. Mutation (Rule 19): make the Listings descriptor's parentScope empty (mirror regenerated, bundle rebuilt and redeployed) -> the Listing groups name cell is
// text and the click leg goes red; drop `Compiled` from the Listing groups read in `AnalyticsPort.Collect` (reload the class) -> the Compiled column reads No and the first leg goes red.
test('Story 24.11: Listing groups shows each group with what the vendor\'s model reads, a name cell opens its Listings, and both screens pass the structural checks', async () => {
  const made = probe('LGMADE', `$System.Status.IsOK(##class(${PROBE}).CreateListingGroups())`);
  assert.equal(made.value, '1', `the probe's listing groups are saved and compiled: ${made.output}`);
  const { context, page } = await signedInAt(browser, config, url(CUBES), VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await answered(page);
    await openEntry(page, STRINGS.analyticsListingGroupsLabel);
    await pathHolds(page, `/${LISTING_GROUPS}`);
    await answered(page);
    const groups = inUser('LGGROUPS', [
      'Set sc=##class(%DeepSee.ListingGroup).%GetListingGroups(.l,0),k="",out=""',
      `For { Set k=$Order(l(k))  Quit:k=""  Set m=##class(%DeepSee.ListingGroup).%GetModel($List(l(k,1),5))  If $Extract(m.name,1,21)="${LISTING_GROUP}" Set out=out_m.name_"~"_$List(l(k,1),3)_"~"_m.targetCubes_"~"_''##class(%DeepSee.ListingGroup).%ListingGroupExists(m.name,1)_"~"_m.listings.Count()_"|" }`,
    ]);
    const byName = (left, right) => (left[0] < right[0] ? -1 : left[0] > right[0] ? 1 : 0);
    const expectedGroups = groups.value
      .split('|')
      .filter((entry) => entry !== '')
      .map((entry) => entry.split('~'))
      .map(([name, caption, cubes, compiled, listings]) => [name, caption, cubes, compiled === '1' ? STRINGS.tableStatusYes : STRINGS.tableStatusNo, listings])
      .sort(byName);
    assert.equal(expectedGroups.length, 4, `the instance holds the four probe groups the vendor reads: ${groups.output}`);
    assert.deepEqual((await rowsStartingWith(page, LISTING_GROUP)).sort(byName), expectedGroups, 'Listing groups shows each probe group with the caption, target cubes, compiled flag and listing count the vendor\'s model reads');
    assert.deepEqual(
      expectedGroups.filter((row) => row[3] === STRINGS.tableStatusYes).map((row) => row[0]),
      [LISTING_GROUP, `${LISTING_GROUP}Hidden`],
      'the compiled group and the guarded one are compiled, and the saved and disabled groups are not'
    );
    assert.deepEqual(await structural(page, LISTING_GROUPS), [], `${LISTING_GROUPS}: no violation beyond the baseline's entries`);

    await clickRowCentre(page, { text: LISTING_GROUP, link: true });
    await pathHolds(page, `/${LISTINGS}/${encodeEntityId(LISTING_GROUP)}`);
    await answered(page);
    const listings = inUser('LGLISTINGS', [
      `Set m=##class(%DeepSee.ListingGroup).%GetModel(##class(%DeepSee.ListingGroup).%GetClassName("${LISTING_GROUP}",0)),out=""`,
      'For i=1:1:m.listings.Count() { Set l=m.listings.GetAt(i)  Set out=out_l.name_"~"_l.listingType_"~"_l.fieldList_"~"_l.sourceClass_"~"_l.description_"|" }',
    ]);
    // An empty cell draws the table's own placeholder.
    const expectedListings = listings.value
      .split('|')
      .filter((entry) => entry !== '')
      .map((entry) => entry.split('~').map((cell) => (cell === '' ? STRINGS.tableEmptyValue : cell)));
    assert.deepEqual(expectedListings.map((row) => row[0]), ['ByAmount', 'CustomSql'], `the vendor reads the compiled group's two listings: ${listings.output}`);
    assert.deepEqual(await allRows(page), expectedListings, 'Listings shows each listing with the type, fields, data connector and description the vendor\'s model reads');
    assert.deepEqual(await structural(page, LISTINGS), [], `${LISTINGS}: no violation beyond the baseline's entries`);
  } finally {
    await context.close();
    probe('LGGONE', `$System.Status.IsOK(##class(${PROBE}).RemoveListingGroups())`);
  }
});

const WRITE_GROUP = 'OcuPilotProbeLGWBrowse';
const WRITE_CLASS = 'OcuPilotProbe.Analytics.LGWBrowse';
const WRITE_LISTING = 'LGWBrowseOne';

/** Click the command bar's primary action, which opens the listing group dialog titled `label`. */
async function commandBarAction(page, label) {
  await (await page.waitForSelector('.ocu-command-bar button.ocu-command-bar-primary', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector('app-listing-group-dialog [data-listing-group-confirm]', { timeout: config.navigationTimeoutMs });
  assert.equal(await page.$eval('[role="dialog"] .ocu-dialog-title', (node) => node.textContent.trim()), label, `the primary action opens ${label}`);
}

/** Type `text` into the listing group dialog's field `member` and confirm the dialog, which closes once the write was applied. */
async function fillAndConfirm(page, fields) {
  for (const [member, text] of Object.entries(fields)) {
    await page.type(`app-listing-group-dialog [data-listing-group-field="${member}"]`, text);
  }
  await page.waitForFunction(() => document.querySelector('[data-listing-group-confirm]')?.getAttribute('aria-disabled') === null, { timeout: config.navigationTimeoutMs });
  await page.click('[data-listing-group-confirm]');
  await page.waitForFunction(() => document.querySelector('app-listing-group-dialog') === null, { timeout: config.navigationTimeoutMs });
}

// Story 24.11 AC4 (Batch 2). Mutation (Rule 19): make the New listing group dialog post to the term lists' route (bundle rebuilt and redeployed) -> the first row never appears and the first leg goes red;
// the Listing groups' own `TYPED_NAME_ROWS` entry is pinned by no mutation: a group's id is its name, so the dialog asks for the same text whether or not the entry is declared.
test('Story 24.11: a person creates a listing group, edits it, adds a listing to it and deletes the group by typing its name, and each screen shows each change', async () => {
  const { context, page } = await signedInAt(browser, config, url(LISTING_GROUPS), VIEWPORTS.wide, REDUCED_MOTION);
  try {
    // The group list is empty when the test starts, so only the navigation map is awaited.
    await waitForMapAnswered(page, config.navigationTimeoutMs);
    await commandBarAction(page, STRINGS.analyticsListingGroupNewAction);
    await fillAndConfirm(page, { Name: WRITE_GROUP, Class: WRITE_CLASS, TargetCubes: VISITS });
    await page.waitForFunction((rowSelector, wanted) => Array.from(document.querySelectorAll(rowSelector)).some((row) => row.querySelector('[role="gridcell"]')?.textContent.trim().startsWith(wanted)), { timeout: config.navigationTimeoutMs }, ROW_SELECTOR, WRITE_GROUP);
    // A row the instance has just changed carries its marker and read-back in its first cell, and a group with no caption shows its name as the caption.
    assert.deepEqual(
      (await rowsStartingWith(page, WRITE_GROUP)).map((row) => row.slice(1, 5)),
      [[WRITE_GROUP, VISITS, STRINGS.tableStatusYes, '0']],
      'Listing groups shows the new group, compiled and holding no listing'
    );
    assert.equal(inUser('LGWNEW', [`Set out=##class(%Dictionary.ClassDefinition).%ExistsId("${WRITE_CLASS}")`]).value, '1', 'and the instance holds its class');

    await rowAction(page, WRITE_GROUP, STRINGS.agentPanelSecretWarningEdit);
    await page.waitForSelector('app-listing-group-dialog [data-listing-group-field="Caption"]', { timeout: config.navigationTimeoutMs });
    await page.waitForFunction(() => document.querySelector('[data-listing-group-field="Name"]')?.value !== '', { timeout: config.navigationTimeoutMs });
    await fillAndConfirm(page, { Caption: 'Browser caption' });
    await page.waitForFunction((rowSelector, wanted) => Array.from(document.querySelectorAll(rowSelector)).some((row) => row.textContent.includes(wanted)), { timeout: config.navigationTimeoutMs }, ROW_SELECTOR, 'Browser caption');
    assert.equal(
      inUser('LGWEDIT', [`Set out=##class(%DeepSee.ListingGroup).%GetModel("${WRITE_CLASS}").displayName`]).value,
      'Browser caption',
      'the edit changed the vendor\'s model, and Listing groups shows the caption'
    );

    await clickRowCentre(page, { text: await firstCell(page, WRITE_GROUP), link: true });
    await pathHolds(page, `/${LISTINGS}/${encodeEntityId(WRITE_GROUP)}`);
    await waitForMapAnswered(page, config.navigationTimeoutMs);
    await commandBarAction(page, STRINGS.analyticsListingAddAction);
    await fillAndConfirm(page, { Name: WRITE_LISTING, Fields: 'Amount' });
    await page.waitForFunction((rowSelector, wanted) => Array.from(document.querySelectorAll(rowSelector)).some((row) => row.querySelector('[role="gridcell"]')?.textContent.trim().startsWith(wanted)), { timeout: config.navigationTimeoutMs }, ROW_SELECTOR, WRITE_LISTING);
    assert.deepEqual(
      (await rowsStartingWith(page, WRITE_LISTING)).map((row) => row.slice(1, 4)),
      [['table', 'Amount', STRINGS.tableEmptyValue]],
      'Listings shows the new listing with its type, fields and no data connector'
    );

    await page.goto(new URL(url(LISTING_GROUPS), page.url()).href, { waitUntil: 'networkidle2' });
    await answered(page);
    await rowAction(page, WRITE_GROUP, STRINGS.actionDelete);
    await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-typed-name-consequence', (node) => node.textContent.trim()), STRINGS.analyticsListingGroupDeleteConsequence, 'Delete states its consequence and asks for the group\'s name typed');
    await page.type('.ocu-typed-name-field', WRITE_GROUP);
    await page.keyboard.press('Enter');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await rowGone(page, WRITE_GROUP);
    assert.equal(inUser('LGWGONE', [`Set out=##class(%Dictionary.ClassDefinition).%ExistsId("${WRITE_CLASS}")_$Data(^DeepSee.ListingGroups("groups","${WRITE_GROUP.toUpperCase()}"))`]).value, '00', 'the class and the group\'s registry nodes are gone');
  } finally {
    await context.close();
    probe('LGWCLEAN', `$System.Status.IsOK(##class(${PROBE}).RemoveListingGroups())`);
  }
});

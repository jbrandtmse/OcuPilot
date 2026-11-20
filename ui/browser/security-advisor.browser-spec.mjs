/**
 * Story 21.19 in a real browser, against the throwaway instance: the Security advisor list and its Ignore and Stop ignoring row
 * actions (AD-5, AD-29, AD-53, AD-58).
 *
 * What it pins: the Security advisor is a Security side-bar entry at its declared position; its rows draw once the navigation map has
 * answered, under the declared headers, each row's Area and Recommendation being the published words; Ignore on a row the instance reads
 * as not ignored sends one request naming the row and the row's Ignored cell changes after the screen re-fetches, which the
 * instance's own advisor confirms; Stop ignoring puts both back. The empty state (a read of no rows) cannot be driven on a
 * live instance; `ui/tools/advisor-strings.test.mjs` pins its two lines.
 *
 * **It sets one recommendation's ignore flag** through the shipped screen, so it runs on a throwaway only. It takes a real row from the
 * instance's own recommendations, preferring one that is not ignored and has an item, and its `after` hook restores that row's flag whatever
 * the tests answered, then asserts that the count of ignored rows is the count it found.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/security-advisor.browser-spec.mjs` (after `npm run build` and the bundle copied into the
 * throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { signedInAt } from './panel-spec.mjs';
import { assertDrawnAtDeclaredIndex, sideBarLabels } from './side-bar-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { escapeOs, markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const ROUTE = 'security/advisor';
const LIST_URL = `/ocupilot/${ROUTE}?ns=HSCUSTOM`;
const ACTION_PATH = '/api/ocupilot/screens/security.advisor/action';
const PANE = '##class(%CSP.UI.System.SecurityAdvisorPane)';
/** The composite id's separator: the type, the element and the code. */
const SEPARATOR = '\u0001';

let browser = null;
/** The row the spec works on, `{type, element, code}`, and the ignored count the instance held before it. */
let chosen = null;
let ignoredBefore = -1;

/** The instance's own advisor, in %SYS: the count of ignored rows and the first row that is not ignored and has an item. */
function readAdvisor() {
  const output = runIris(config.container, [
    'Set $NAMESPACE="%SYS"',
    `Set sc=${PANE}.GetRecommendations(.rec)`,
    'Set n=0,ig=0,pick="",t="" For { Set t=$Order(rec(t)) Quit:t=""  Set e="" For { Set e=$Order(rec(t,e)) Quit:e=""  Set c="" For { Set c=$Order(rec(t,e,"list",c),1,f) Quit:c=""  Set n=n+1 Set:f ig=ig+1 Set:(pick="")&&(\'f)&&(e\'=" ") pick=t_$Char(1)_e_$Char(1)_c } } }',
    'Write "OCU-ADVREAD-START:"_$System.Status.IsOK(sc)_"#"_n_"#"_ig_"#"_$Translate(pick,$Char(1),"|")_":OCU-ADVREAD-END",!',
  ]);
  const value = markerValue(output, 'ADVREAD');
  assert.ok(value !== null, `the advisor read answers: ${output}`);
  const [ok, rows, ignored, pick] = value.split('#');
  assert.equal(ok, '1', `the advisor read succeeds: ${output}`);
  return { rows: Number(rows), ignored: Number(ignored), pick };
}

/** Whether the instance's advisor holds `row` ignored. */
function flagOf(row) {
  const output = runIris(config.container, [
    'Set $NAMESPACE="%SYS"',
    `Set sc=${PANE}.GetRecommendations(.rec)`,
    `Set f=$Get(rec("${escapeOs(row.type)}","${escapeOs(row.element)}","list","${escapeOs(row.code)}"))`,
    'Write "OCU-ADVFLAG-START:"_(\'\'f)_":OCU-ADVFLAG-END",!',
  ]);
  const value = markerValue(output, 'ADVFLAG');
  assert.ok(value === '0' || value === '1', `the flag reads: ${output}`);
  return value === '1';
}

/** Put the row's flag back to not ignored, through the pane's own method. */
function clearFlag(row) {
  runIris(config.container, ['Set $NAMESPACE="%SYS"', `Do ${PANE}.SetIgnoreFlag("${escapeOs(row.type)}","${escapeOs(row.element)}","${escapeOs(row.code)}",0,"")`]);
}

/** Signed in at the list with its rows drawn after the navigation map answered, recording every request to the action route. */
async function atList() {
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const posts = [];
  page.on('request', (request) => {
    if (new URL(request.url()).pathname === ACTION_PATH) posts.push({ method: request.method(), body: request.postData() ?? '' });
  });
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  await waitForRows(page, config.navigationTimeoutMs);
  return { context, page, posts };
}

/** The cells of every rendered row whose Item cell reads `element`. */
function rowsOf(page, element) {
  return page.evaluate(
    (rowSelector, wanted, tag) =>
      Array.from(document.querySelectorAll(rowSelector))
        .map((row) => Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim()))
        .filter((cells) => cells[1] === wanted || cells[1].startsWith(wanted + tag)),
    ROW_SELECTOR,
    element,
    STRINGS.tableChangedTag
  );
}

/** Narrow the list to the rows naming the chosen item and select the chosen recommendation's row. */
async function selectChosen(page) {
  const sentence = STRINGS[`securityAdvisorText${chosen.code === 'UserNoNamespace' ? 'UserNoDefault' : chosen.code}`];
  assert.ok(sentence !== undefined, `the string source holds a sentence for ${chosen.code}`);
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, chosen.element);
  await page.waitForFunction(
    (rowSelector, filterSelector, wanted) => {
      if (document.querySelector(filterSelector)?.value !== wanted) return false;
      const rows = Array.from(document.querySelectorAll(rowSelector));
      return rows.length > 0 && rows.length <= 40 && rows.every((row) => row.textContent.includes(wanted));
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    FILTER_SELECTOR,
    chosen.element
  );
  const at = await page.$$eval(
    ROW_SELECTOR,
    (rows, element, text, tag) =>
      rows.findIndex((row) => {
        const cells = Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim());
        return (cells[1] === element || cells[1].startsWith(element + tag)) && cells[2] === text;
      }),
    chosen.element,
    sentence,
    STRINGS.tableChangedTag
  );
  assert.ok(at >= 0, `the chosen row is drawn: ${JSON.stringify(await rowsOf(page, chosen.element))}`);
  await clickRowCentre(page, { index: at, cell: 2 });
  await page.waitForFunction(
    (rowSelector, index) => document.querySelectorAll(rowSelector)[index]?.getAttribute('aria-selected') === 'true',
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    at
  );
  return sentence;
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

/** Wait until `count` requests to the action route have been sent, answering what was recorded. */
async function sentCount(posts, count) {
  const deadline = Date.now() + config.navigationTimeoutMs;
  while (posts.length < count && Date.now() < deadline) await new Promise((resolve) => setTimeout(resolve, 100));
  assert.equal(posts.length, count, `the action route was asked ${count} time(s): ${JSON.stringify(posts)}`);
}

/** The chosen row's Ignored cell once the re-fetched list draws it differently from `previous`. */
async function ignoredCellChangedFrom(page, sentence, previous) {
  try {
    await page.waitForFunction(
      (rowSelector, element, text, before, tag) => {
        const row = Array.from(document.querySelectorAll(rowSelector)).find((candidate) => {
          const cells = Array.from(candidate.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim());
          return (cells[1] === element || cells[1].startsWith(element + tag)) && cells[2] === text;
        });
        if (row === undefined) return false;
        const cells = Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim());
        return cells[3] !== before;
      },
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      chosen.element,
      sentence,
      previous,
      STRINGS.tableChangedTag
    );
  } catch (error) {
    throw new Error(
      `the Ignored cell never changed from ${JSON.stringify(previous)}; the instance holds the row ignored: ${flagOf(chosen)}; the chosen item's rows read ${JSON.stringify(await rowsOf(page, chosen.element))}: ${error.message}`
    );
  }
  return (await rowsOf(page, chosen.element)).find((cells) => cells[2] === sentence)[3];
}

/** The chosen row's Ignored cell as drawn now. */
async function ignoredCell(page, sentence) {
  return (await rowsOf(page, chosen.element)).find((cells) => cells[2] === sentence)?.[3];
}

before(async () => {
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec sets an ignore flag, so it runs only in a throwaway; ${config.container} is not one`);
  const found = readAdvisor();
  ignoredBefore = found.ignored;
  assert.ok(found.pick !== '', `the instance holds a recommendation that is not ignored and names an item: ${JSON.stringify(found)}`);
  const [type, element, code] = found.pick.split('|');
  chosen = { type, element, code };
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (chosen !== null && /-ci$/.test(config.container) && flagOf(chosen)) clearFlag(chosen);
    if (ignoredBefore >= 0 && /-ci$/.test(config.container)) {
      assert.equal(readAdvisor().ignored, ignoredBefore, 'the ignored count is what the spec found');
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

// AC1. Mutation (Rule 19): give the Security advisor `sideBarPosition` 0, regenerate the mirror, rebuild and redeploy -> the wait for
// its side-bar entry, or the declared-index assertion, goes red.
test('AC1: the Security advisor is a Security entry and draws its rows, with the published words, once the map has answered', async () => {
  const { context, page } = await atList();
  try {
    await page.click(`.ocu-rail-item[aria-label="${STRINGS.navAreaSecurity}"]`);
    await page.waitForFunction(
      (label) => Array.from(document.querySelectorAll('.ocu-side-bar-label')).some((node) => node.textContent.trim() === label),
      { timeout: config.navigationTimeoutMs },
      STRINGS.securityAdvisorLabel
    );
    const labels = await page.$$eval('.ocu-side-bar-item .ocu-side-bar-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(labels, sideBarLabels('security'), 'the side bar lists the Security entries in their declared order');
    assertDrawnAtDeclaredIndex(labels, 'security', STRINGS.securityAdvisorLabel);
    const headers = await page.$$eval('.ocu-data-table-header-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(
      headers.slice(0, 4),
      [STRINGS.screenPermissionsColumnArea, STRINGS.interopItemSettingsCriterionItem, STRINGS.securityAdvisorColumnRecommendation, STRINGS.securityAdvisorColumnIgnored],
      'the declared headers'
    );
    const rows = await page.$$eval(ROW_SELECTOR, (items) => items.map((item) => Array.from(item.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim())));
    assert.ok(rows.length > 0, 'rows are drawn');
    const areas = new Set([
      'Auditing',
      'Services',
      'Roles',
      'Users',
      'Web applications',
      'Privileged routine applications',
      STRINGS.securityAdvisorAreaClientApplications,
    ]);
    const sentences = new Set(Object.entries(STRINGS).filter(([key]) => key.startsWith('securityAdvisorText')).map(([, value]) => value));
    for (const cells of rows) {
      assert.ok(areas.has(cells[0]), `a row's Area is one of the seven published names: ${JSON.stringify(cells)}`);
      assert.ok(sentences.has(cells[2]), `a row's Recommendation is a published sentence: ${JSON.stringify(cells)}`);
    }
  } finally {
    await context.close();
  }
});

// AC2. Mutation (Rule 19): point the `ignore` entry of SCREEN_ACTION_DESCRIPTORS' handler at the unignore action (the action sent is
// `unignore`), rebuild and redeploy -> the request names the wrong action and the instance still reads the row not ignored.
test('AC2: Ignore sends one request for the row and its Ignored cell changes after the re-fetch; Stop ignoring puts it back', async () => {
  const { context, page, posts } = await atList();
  try {
    const sentence = await selectChosen(page);
    const before = await ignoredCell(page, sentence);
    assert.equal(flagOf(chosen), false, 'the instance reads the chosen row as not ignored');

    await rowAction(page, STRINGS.securityAdvisorIgnoreAction);
    await sentCount(posts, 1);
    const ignoredCellText = await ignoredCellChangedFrom(page, sentence, before);
    assert.notEqual(ignoredCellText, before, 'the row\'s Ignored cell changed');
    assert.equal(posts.length, 1, `exactly one request: ${JSON.stringify(posts)}`);
    assert.equal(posts[0].method, 'POST');
    assert.deepEqual(JSON.parse(posts[0].body), { action: 'ignore', id: [chosen.type, chosen.element, chosen.code].join(SEPARATOR) });
    assert.equal(flagOf(chosen), true, 'the instance\'s own advisor reads the row ignored');

    await selectChosen(page);
    await rowAction(page, STRINGS.securityAdvisorUnignoreAction);
    await sentCount(posts, 2);
    const restored = await ignoredCellChangedFrom(page, sentence, ignoredCellText);
    assert.equal(restored, before, 'Stop ignoring restores the cell');
    assert.equal(posts.length, 2, `a second request: ${JSON.stringify(posts)}`);
    assert.deepEqual(JSON.parse(posts[1].body), { action: 'unignore', id: [chosen.type, chosen.element, chosen.code].join(SEPARATOR) });
    assert.equal(flagOf(chosen), false, 'and the instance reads it not ignored again');
  } finally {
    await context.close();
    if (flagOf(chosen)) clearFlag(chosen);
  }
});

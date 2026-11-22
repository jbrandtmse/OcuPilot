/**
 * Story 21.37 in a real browser, against the throwaway (AC12): a principal holding exactly `%Admin_Secure:USE` and `%DB_IRISSYS:READ` opens Page
 * resources, assigns a resource to a probe page through the Assign dialog and sees its row, changes it, clears it, and tries a page a Home screen
 * declares, whose refusal reads the existing sentence and writes nothing. Each write is read back from the instance's own store.
 *
 * The principal, two resources and the probe page's original resource are handled inside the container through `OcuPilot.Test.PageResourceFixture`
 * and the vendor's own calls, with a password generated per run. Everything is removed or restored afterwards, and the spec reads the instance back to
 * prove it.
 *
 * It refuses the live and development containers.
 *
 * Run: `node --test --test-concurrency=1 browser/page-resources.browser-spec.mjs` (after `npm run build`, the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { parseMarkers } from './iris-session.mjs';
import { ROW_SELECTOR, clickRowCentre } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { resetRememberedState } from './preferences-reset.mjs';
import { VIEWPORTS } from './structural-walk.mjs';

const config = browserConfig();
const STRINGS = loadStrings();

const ROUTE = 'permissions/pageresources';
const LIST_URL = `/ocupilot/${ROUTE}?ns=HSCUSTOM`;

/** The two resources the spec creates, and the Home screen's classic page, which no assignment may reach. */
const FIRST = 'OcuProbe2137BrA';
const SECOND = 'OcuProbe2137BrB';
const HOME_PAGE = '%CSP.Portal.Home';

const password = `OcuPilotPageRes${randomBytes(12).toString('hex')}Aa9`;
let user = '';
let probe = '';
let original = '';
let homeOriginal = '';
let browser = null;

/** Run ObjectScript lines in the throwaway, in `%SYS`, and answer the named markers. */
function irisSession(lines, names) {
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', '%SYS'], {
    input: `${[...lines, 'Halt'].join('\n')}\n`,
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  return { values: parseMarkers(output, names), output };
}

const marker = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/** The resource the instance stores for the page `expression` names, as the classic portal reads it. */
const heldExpression = (expression) => `##class(%CSP.Portal.Utils).%GetCustomResource($ZConvert(${expression},"O","URL"))`;

/** The same for the literal page `page`. */
const held = (page) => heldExpression(`"${page}"`);

/** The resource the instance stores for `page` now. */
function heldBy(page) {
  const read = irisSession(['Set $NAMESPACE="HSCUSTOM"', marker('HELD', held(page))], ['HELD']);
  assert.notEqual(read.values.HELD, null, `the store was read: ${read.output}`);
  return read.values.HELD;
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates a principal and assigns custom resources, so it never runs inside the live container');
  assert.ok(!/slot-[a-z]$/.test(config.container), 'nor inside a development container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  const created = irisSession(
    [
      'Set $NAMESPACE="%SYS"',
      `For tName="${FIRST}","${SECOND}" { If ##class(Security.Resources).Exists(tName) Do ##class(Security.Resources).Delete(tName) }`,
      `Set tSC1=##class(Security.Resources).Create("${FIRST}","OcuPilot page resources browser spec (throwaway)","")`,
      `Set tSC2=##class(Security.Resources).Create("${SECOND}","OcuPilot page resources browser spec (throwaway)","")`,
      'Set $NAMESPACE="HSCUSTOM"',
      `Set tSC3=##class(OcuPilot.Test.PageResourceFixture).Prepare("${password}")`,
      'Set tProbe=""',
      'For tCandidate="%CSP.UI.Portal.About","%UnitTest.Portal.Index" { If tProbe="" { Set tSC4=##class(OcuPilot.Port.PortalResourcePort).Normalized(tCandidate,.tNormal) If $System.Status.IsOK(tSC4),tNormal\'="" { Set tDeclaring=##class(OcuPilot.Screen.Registry).ScreensDeclaringPage(tNormal,.tResolved) If tResolved,$ListLength(tDeclaring)=0 Set tProbe=tNormal } } }',
      marker('OK', '$System.Status.IsOK(tSC1)&&$System.Status.IsOK(tSC2)&&$System.Status.IsOK(tSC3)'),
      marker('USER', '$Parameter("OcuPilot.Test.PageResourceFixture","LEASTUSER")'),
      marker('PROBE', 'tProbe'),
      marker('ORIGINAL', heldExpression('tProbe')),
      marker('HOME', held(HOME_PAGE)),
    ],
    ['OK', 'USER', 'PROBE', 'ORIGINAL', 'HOME']
  );
  user = created.values.USER ?? '';
  probe = created.values.PROBE ?? '';
  original = created.values.ORIGINAL ?? '';
  homeOriginal = created.values.HOME ?? '';
  assert.equal(created.values.OK, '1', `the resources and the principal were created:\n${created.output}`);
  assert.notEqual(probe, '', `a classic page no OcuPilot screen declares was found:\n${created.output}`);
  assert.equal(original, '', 'the probe page holds no custom resource before the spec');
  assert.equal(homeOriginal, '', "and neither does the Home screen's page");
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  // `before` refused the live container; nothing was created there, and nothing is removed.
  if (config.container === LIVE_CONTAINER) return;
  const probeLines = probe === '' ? [] : [`Set tSC9=##class(%CSP.Portal.Utils).%SetCustomResource($ZConvert("${probe}","O","URL"),"${original}")`];
  const cleaned = irisSession(
    [
      'Set $NAMESPACE="HSCUSTOM"',
      ...probeLines,
      marker('PROBE', probe === '' ? '""' : held(probe)),
      marker('HOME', held(HOME_PAGE)),
      marker('USERS', '##class(OcuPilot.Test.PageResourceFixture).RemovePrincipals()'),
      'Set $NAMESPACE="%SYS"',
      `For tName="${FIRST}","${SECOND}" { If ##class(Security.Resources).Exists(tName) Do ##class(Security.Resources).Delete(tName) }`,
      `Set tRS=##class(%ResultSet).%New("%SYS.Portal.Resources:List") Do tRS.Execute("*","OcuProbe2137Br*") Set tRows=0 While tRS.Next() { Set tRows=tRows+1 }`,
      marker('ROWS', 'tRows'),
      marker('RESOURCES', `##class(Security.Resources).Exists("${FIRST}")+##class(Security.Resources).Exists("${SECOND}")`),
    ],
    ['PROBE', 'HOME', 'USERS', 'ROWS', 'RESOURCES']
  );
  assert.equal(cleaned.values.PROBE, original, `the probe page holds what it held before: ${cleaned.output}`);
  assert.equal(cleaned.values.HOME, homeOriginal, "the Home screen's page was never assigned");
  assert.equal(cleaned.values.USERS, '', `the principals and their roles are gone: ${cleaned.output}`);
  assert.equal(cleaned.values.ROWS, '0', 'no page holds either probe resource');
  assert.equal(cleaned.values.RESOURCES, '0', 'and both probe resources are gone');
});

/** Sign the least principal in at `url` through the shell's own form and wait for the answered map and the answered list. */
async function signIn(url) {
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  await page.setViewport(VIEWPORTS.wide);
  await page.goto(`${config.origin}${url}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', user);
  await page.type('#ocu-signin-password', password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  // The list is answered once it draws a row or its empty state; this instance may hold no custom resource yet.
  await page.waitForSelector(`${ROW_SELECTOR}, .ocu-data-table-empty`, { timeout: config.navigationTimeoutMs });
  return { context, page };
}

/** Click the command-bar button labeled `label` once it is drawn and available (an element click, not a pointer event). */
async function bar(page, label) {
  await page.waitForFunction(
    (wanted) => [...document.querySelectorAll('.ocu-command-bar button')].some((button) => button.textContent.trim() === wanted && button.getAttribute('aria-disabled') === null),
    { timeout: config.navigationTimeoutMs },
    label
  );
  await page.evaluate((wanted) => [...document.querySelectorAll('.ocu-command-bar button')].find((button) => button.textContent.trim() === wanted).click(), label);
}

/** The cells of the rendered row whose first cell starts with `name`, or `null`. */
function rowCells(page, name) {
  return page.evaluate(
    (selector, wanted) => {
      const row = [...document.querySelectorAll(selector)].find((candidate) => candidate.querySelector('[role="gridcell"]')?.textContent.trim().startsWith(wanted));
      return row === undefined ? null : [...row.querySelectorAll('[role="gridcell"]')].map((cell) => cell.textContent.trim());
    },
    ROW_SELECTOR,
    name
  );
}

/** Wait until the row for `name` is drawn with `resource` in its Resource cell, or, for `null`, until it is gone. */
async function waitForRow(page, name, resource) {
  await page.waitForFunction(
    (selector, wanted, expected) => {
      const row = [...document.querySelectorAll(selector)].find((candidate) => candidate.querySelector('[role="gridcell"]')?.textContent.trim().startsWith(wanted));
      if (expected === null) return row === undefined;
      return row !== undefined && [...row.querySelectorAll('[role="gridcell"]')].some((cell) => cell.textContent.trim() === expected);
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name,
    resource
  );
}

/** Select the row for `name` and choose its row-menu item `label`. */
async function chooseRowAction(page, name, label) {
  const at = await page.evaluate(
    (selector, wanted) => [...document.querySelectorAll(selector)].findIndex((row) => row.querySelector('[role="gridcell"]')?.textContent.trim().startsWith(wanted)),
    ROW_SELECTOR,
    name
  );
  assert.ok(at >= 0, `the row for ${name} is drawn`);
  // The row the instance has just changed carries its marker in its first cell, so it is clicked by position on its second cell.
  await clickRowCentre(page, { index: at, cell: 2 });
  await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
  await page.evaluate((wanted) => [...document.querySelectorAll('[role="menu"] [role="menuitem"]')].find((item) => item.textContent.trim().startsWith(wanted)).click(), label);
  await page.waitForSelector('app-page-resources-dialog [role="dialog"]', { visible: true, timeout: config.navigationTimeoutMs });
}

/** Replace the text of `selector`'s field with `value`. */
async function replaceText(page, selector, value) {
  await page.click(selector, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(selector, value);
}

const dialogText = (page, selector) => page.evaluate((wanted) => document.querySelector(wanted)?.textContent.trim() ?? '', selector);

/** Wait until the dialog's `selector` reads `expected`. */
function waitForDialogText(page, selector, expected) {
  return page.waitForFunction((wanted, text) => document.querySelector(wanted)?.textContent.trim() === text, { timeout: config.navigationTimeoutMs }, selector, expected);
}

/** Click the dialog's Save once it is available. */
async function save(page) {
  await page.waitForFunction(() => document.querySelector('.ocu-page-resources-submit')?.getAttribute('aria-disabled') === null, { timeout: config.navigationTimeoutMs });
  await page.click('.ocu-page-resources-submit');
}

const dialogClosed = (page) => page.waitForFunction(() => document.querySelector('app-page-resources-dialog') === null, { timeout: config.navigationTimeoutMs });

// AC12. Mutation (Rule 19): remove the `clear` row action from `PageResourceList`'s declaration, regenerate, rebuild and redeploy the bundle -> the
// Clear step goes red, since no menu item carries the word.
test('AC12: a page is assigned a resource, changed, cleared and refused as a Home screen\'s, each step shown by the screen without a reload', async () => {
  const { context, page } = await signIn(LIST_URL);
  let stage = 'the list opens';
  try {
    await page.evaluate(() => {
      window.__ocuNoReload = 'standing';
    });
    assert.equal(await rowCells(page, probe), null, 'the probe page is not on the list');

    // Assign: the page and the resource are typed, the review names that no screen replaces the page, and Save stores it.
    stage = 'assign';
    await bar(page, STRINGS.pageResourcesAssignAction);
    await page.waitForSelector('app-page-resources-dialog [role="dialog"]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await dialogText(page, '.ocu-dialog-title'), STRINGS.pageResourcesAssignTitle);
    await page.type('[data-field="page"]', probe);
    await page.type('[data-field="resource"]', FIRST);
    // Leaving the field asks for the review.
    await page.keyboard.press('Tab');
    await waitForDialogText(page, '.ocu-page-resources-line', STRINGS.pageResourcesLineNone);
    await save(page);
    await dialogClosed(page);
    await waitForRow(page, probe, FIRST);
    assert.equal(heldBy(probe), FIRST, 'the instance stores the assignment');

    // Change: its page is read-only beside the resource the page holds, and Save waits for a different one.
    stage = 'change';
    await chooseRowAction(page, probe, STRINGS.pageResourcesChangeAction);
    assert.equal(await dialogText(page, '.ocu-dialog-title'), STRINGS.pageResourcesChangeTitle.replace('<page>', () => probe));
    assert.equal(await page.$eval('[data-field="page"]', (field) => field.readOnly), true, 'the page cannot be edited');
    assert.equal(await page.$eval('[data-field="resource"]', (field) => field.value), FIRST, 'the resource is the one the page holds');
    assert.equal(await page.$eval('.ocu-page-resources-submit', (button) => button.getAttribute('aria-disabled')), 'true', 'Save waits for a different resource');
    await waitForDialogText(page, '.ocu-page-resources-line', STRINGS.pageResourcesLineNone);
    await replaceText(page, '[data-field="resource"]', SECOND);
    // Enter without leaving the field asks for the review, and Save waits for it.
    await page.keyboard.press('Enter');
    await save(page);
    await dialogClosed(page);
    await waitForRow(page, probe, SECOND);
    assert.equal(heldBy(probe), SECOND, 'the instance stores the change');

    // Clear: its confirmation carries the warning and its button names the action.
    stage = 'clear';
    await chooseRowAction(page, probe, STRINGS.pageResourcesClearAction);
    assert.equal(await dialogText(page, '.ocu-dialog-title'), STRINGS.pageResourcesSummaryClear.replace('<page>', () => probe));
    assert.equal(await dialogText(page, '.ocu-page-resources-warning'), STRINGS.pageResourcesClearWarning);
    assert.equal(await dialogText(page, '.ocu-page-resources-submit'), STRINGS.pageResourcesClearAction);
    await save(page);
    await dialogClosed(page);
    await waitForRow(page, probe, null);
    assert.equal(heldBy(probe), '', 'the instance holds no resource for the page again');

    // A page a Home screen declares: the review and the save both read the existing sentence, and nothing is stored.
    stage = 'home';
    await bar(page, STRINGS.pageResourcesAssignAction);
    await page.waitForSelector('app-page-resources-dialog [role="dialog"]', { visible: true, timeout: config.navigationTimeoutMs });
    await page.type('[data-field="page"]', HOME_PAGE);
    await page.type('[data-field="resource"]', FIRST);
    await page.keyboard.press('Tab');
    await waitForDialogText(page, '.ocu-page-resources-refusal', STRINGS.screenPermissionsRefusalOcuPilot);
    const sent = page.waitForResponse((response) => response.request().method() === 'POST' && new URL(response.url()).pathname.endsWith('/action'), { timeout: config.navigationTimeoutMs });
    await save(page);
    assert.equal((await sent).status(), 403, 'the save is refused');
    await waitForDialogText(page, '.ocu-page-resources-refusal', STRINGS.screenPermissionsRefusalOcuPilot);
    assert.notEqual(await page.$('app-page-resources-dialog'), null, 'the dialog stays open on the refusal');
    assert.equal(heldBy(HOME_PAGE), '', "the Home screen's page was not assigned");
    await page.click('app-page-resources-dialog .ocu-dialog-actions .ocu-button-secondary');
    await dialogClosed(page);

    assert.equal(await page.evaluate(() => window.__ocuNoReload), 'standing', 'every step re-read the list without the page reloading');
  } catch (error) {
    const state = await page.evaluate(() => ({
      title: document.querySelector('.ocu-dialog-title')?.textContent.trim() ?? '',
      line: document.querySelector('.ocu-page-resources-line')?.textContent.trim() ?? '',
      refusal: document.querySelector('.ocu-page-resources-refusal')?.textContent.trim() ?? '',
      banner: document.querySelector('.ocu-banner-message')?.textContent.trim() ?? '',
      rows: [...document.querySelectorAll('[role="grid"] .ocu-data-table-body [role="row"]')].map((row) => row.textContent.trim()),
    }));
    error.message = `at "${stage}": ${error.message} -- ${JSON.stringify(state)}`;
    throw error;
  } finally {
    await context.close();
  }
});

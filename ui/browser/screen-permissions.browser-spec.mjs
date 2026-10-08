/**
 * Story 20.15 in a real browser, against the throwaway (AC7, DW-1337): Dev, a `%Developer` principal who
 * holds `%Development:USE`, opens Screen permissions, adds `%Admin_Secure:USE` to Classes through the Change
 * permissions dialog, sees the row show the adjustment, and finds System Explorer's side bar listing Classes
 * unavailable, naming that pair, in the same page and without a reload. Reset restores it. The list and the
 * dialog pass the structural walk at wide light, narrow light and wide dark.
 *
 * Dev and Op are created inside the container through `OcuPilot.Test.ScreenAccessFixture`, with a password
 * generated per run, and removed afterwards, with every adjustment this spec made.
 *
 * It refuses the live and development containers.
 *
 * Run: `node --test --test-concurrency=1 browser/screen-permissions.browser-spec.mjs` (after `npm run build`,
 * the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { parseMarkers } from './iris-session.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { resetRememberedState } from './preferences-reset.mjs';
import { INVARIANTS, VIEWPORTS, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';

const config = browserConfig();
const STRINGS = loadStrings();

/** Screen permissions, which Dev opens. */
const ROUTE = 'agent/screenpermissions';
const LIST_URL = `/ocupilot/${ROUTE}?ns=HSCUSTOM`;

/** The screen the spec adjusts, its declared pair, and the pair it adds. */
const SCREEN = 'explorer.classes';
const DECLARED = '%Development:USE';
const RAISED = '%Admin_Secure:USE';

const password = `OcuPilotAccess${randomBytes(12).toString('hex')}Aa9`;
let user = '';
let browser = null;

/** Run ObjectScript lines in the throwaway and answer the named markers. */
function irisSession(lines, names) {
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', '%SYS'], {
    input: `${['Set $NAMESPACE=$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"):"HSCUSTOM",1:"USER")', ...lines, 'Halt'].join('\n')}\n`,
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  return { values: parseMarkers(output, names), output };
}

const marker = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/** Remove every adjustment and answer how many the store still holds. */
function resetAdjustments() {
  const reset = irisSession(
    ['Set tSC=##class(OcuPilot.Test.ScreenAccessFixture).ResetAll()', 'Do ##class(OcuPilot.Kernel.State.Access).GuardedAll(.tAll)', 'Set tN=0,tK="" For { Set tK=$Order(tAll(tK)) Quit:tK=""  Set tN=tN+1 }', marker('LEFT', 'tN')],
    ['LEFT']
  );
  assert.equal(reset.values.LEFT, '0', `no adjustment survives: ${reset.output}`);
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates a principal and adjusts screens, so it never runs inside the live container');
  assert.ok(!/slot-[a-z]$/.test(config.container), 'nor inside a development container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  const created = irisSession(
    [
      `Set tSC=##class(OcuPilot.Test.ScreenAccessFixture).Prepare("${password}")`,
      marker('USER', '##class(OcuPilot.Test.ScreenAccessFixture).Dev()'),
      marker('OK', '$System.Status.IsOK(tSC)'),
    ],
    ['USER', 'OK']
  );
  assert.equal(created.values.OK, '1', `the fixture created the principals: ${created.output}`);
  user = created.values.USER;
  resetAdjustments();
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  // `before` refused the live container; nothing was created there, and nothing is removed.
  if (config.container === LIVE_CONTAINER) return;
  resetAdjustments();
  const removed = irisSession([marker('LEFT', '##class(OcuPilot.Test.ScreenAccessFixture).RemovePrincipals()')], ['LEFT']);
  assert.equal(removed.values.LEFT, '', `the principals and their roles are gone: ${removed.output}`);
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

/** DW-1337 on `route`: 1280 light (every invariant), 720 light and 1280 dark, against the baseline. */
async function assertStructure(page, route, dialog = false) {
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
    await transitionsSettled(page);
    surfaces[theme] = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
    const { entries } = await detectScreen(page, { route, checks, viewport: viewport.width, theme, minimums });
    found.push(...entries);
    if (!dialog) continue;
    const body = await page.$eval('.ocu-dialog-body', (element) => ({ scroll: element.scrollWidth, client: element.clientWidth }));
    assert.ok(body.scroll <= body.client, `the dialog body does not scroll sideways at ${viewport.width}px ${theme}: ${JSON.stringify(body)}`);
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await frames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  const fresh = compare(collapse(found), readBaseline()?.entries ?? []).fresh;
  assert.deepEqual(fresh.map((entry) => `${entry.key}: ${entry.measured}`), [], `no structural or contrast violation on ${route}`);
}

/** Sign Dev in at `url` through the shell's own form and wait for the frame and the answered map. */
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
  await waitForRows(page, config.navigationTimeoutMs);
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  return { context, page };
}

/** Select `screen`'s row and open its row menu. */
async function openRowMenu(page, screen) {
  await page.waitForSelector(FILTER_SELECTOR, { visible: true, timeout: config.navigationTimeoutMs });
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, screen);
  await page.waitForFunction(
    (selector, wanted) => Array.from(document.querySelectorAll(selector)).some((row) => row.querySelector('[role="gridcell"]')?.textContent.trim().startsWith(wanted)),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    screen
  );
  // The filter leaves the one row, whose name cell also carries the change mark after a write, so it is
  // clicked by position rather than by its exact text.
  await page.waitForFunction((selector) => document.querySelectorAll(selector).length === 1, { timeout: config.navigationTimeoutMs }, ROW_SELECTOR);
  await clickRowCentre(page, { index: 0, cell: 2 });
  await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
}

/** Choose the open menu's item whose label starts with `label`. */
async function chooseMenuItem(page, label) {
  await page.evaluate((wanted) => {
    Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'))
      .find((item) => item.textContent.trim().startsWith(wanted))
      .click();
  }, label);
}

/** The rendered row whose name cell reads `screen`, as its cells' text, or `null`. */
function rowCells(page, screen) {
  return page.evaluate(
    (selector, wanted) => {
      const row = Array.from(document.querySelectorAll(selector)).find((candidate) => candidate.querySelector('[role="gridcell"]')?.textContent.trim().startsWith(wanted));
      return row === undefined ? null : Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim());
    },
    ROW_SELECTOR,
    screen
  );
}

/** System Explorer's side bar entry `label` as rendered: whether it is unavailable, and the reason it names. */
async function sideBarEntry(page, label) {
  await page.waitForSelector('app-side-bar nav.ocu-side-bar', { timeout: config.navigationTimeoutMs });
  return page.evaluate((wanted) => {
    const item = Array.from(document.querySelectorAll('app-side-bar .ocu-side-bar-item')).find((candidate) => candidate.querySelector('.ocu-side-bar-label')?.textContent.trim() === wanted);
    if (item === undefined) return null;
    const reasonId = item.getAttribute('aria-describedby');
    return {
      disabled: item.getAttribute('aria-disabled') === 'true',
      reason: reasonId === null ? '' : (document.getElementById(reasonId)?.textContent ?? '').trim(),
    };
  }, label);
}

/** Open a rail item without reloading the page. */
async function openRail(page, key) {
  await page.click(`#ocu-rail-item-${key}`);
  await page.waitForSelector('app-side-bar nav.ocu-side-bar', { timeout: config.navigationTimeoutMs });
  await frames(page);
}

// AC7. Mutation (Rule 19): make `NavigationService.onChange` ignore `screen-permission` events, rebuild and
// redeploy -> System Explorer's side bar stays stale after the change and the unavailable wait goes red.
test('AC7: adding %Admin_Secure:USE to Classes shows on its row and in System Explorer\'s side bar without a reload, and Reset restores it', async () => {
  resetAdjustments();
  const { context, page } = await signIn(LIST_URL);
  try {
    await page.evaluate(() => {
      window.__ocuNoReload = true;
    });
    await openRowMenu(page, SCREEN);
    await chooseMenuItem(page, STRINGS.screenPermissionsChangeAction);
    await page.waitForSelector('app-screen-permissions-dialog [role="dialog"]', { visible: true, timeout: config.navigationTimeoutMs });
    const opened = await page.evaluate(() => ({
      title: document.querySelector('.ocu-dialog-title').textContent.trim(),
      pairs: Array.from(document.querySelectorAll('.ocu-screen-permissions-pair .ocu-screen-permissions-text')).map((node) => node.textContent.trim()),
      consequence: document.querySelector('.ocu-screen-permissions-consequence')?.textContent.trim() ?? '',
    }));
    assert.equal(opened.title, STRINGS.screenPermissionsDialogTitle.replace('<screen>', () => SCREEN));
    assert.deepEqual(opened.pairs, [DECLARED], 'the dialog lists the declared set');
    assert.equal(opened.consequence, STRINGS.screenPermissionsLowerConsequence);
    await assertStructure(page, ROUTE, true);

    await page.type('app-screen-permissions-dialog [data-field="resource"]', RAISED.split(':')[0]);
    await page.click('app-screen-permissions-dialog .ocu-screen-permissions-add-button');
    await page.waitForFunction(
      (wanted) => Array.from(document.querySelectorAll('app-screen-permissions-dialog .ocu-screen-permissions-text')).some((node) => node.textContent.trim() === wanted),
      { timeout: config.navigationTimeoutMs },
      RAISED
    );
    await page.click('app-screen-permissions-dialog .ocu-dialog-actions .ocu-button-secondary');
    await page.waitForFunction(() => document.querySelector('app-screen-permissions-dialog') === null, { timeout: config.navigationTimeoutMs });
    const raised = await rowCells(page, SCREEN);
    assert.notEqual(raised, null, 'Classes is listed');
    assert.ok(raised.some((cell) => cell === `${DECLARED}, ${RAISED}`), `the row shows the adjustment: ${JSON.stringify(raised)}`);

    // System Explorer, in the same page: its side bar lists Classes unavailable, naming the raised pair.
    await openRail(page, 'system-explorer');
    await page.waitForFunction(
      (label) => Array.from(document.querySelectorAll('app-side-bar .ocu-side-bar-item')).some((item) => item.querySelector('.ocu-side-bar-label')?.textContent.trim() === label && item.getAttribute('aria-disabled') === 'true'),
      { timeout: config.navigationTimeoutMs },
      STRINGS.explorerClassListLabel
    );
    const entry = await sideBarEntry(page, STRINGS.explorerClassListLabel);
    assert.deepEqual(entry, { disabled: true, reason: STRINGS.privilegeRequiresResource.replace('<resource>', () => RAISED) });
    assert.equal(await page.evaluate(() => window.__ocuNoReload === true), true, 'the page was not reloaded');

    // Back to Screen permissions: Reset warns first, then restores the declared set everywhere.
    await openRail(page, 'agent');
    await waitForRows(page, config.navigationTimeoutMs);
    await openRowMenu(page, SCREEN);
    await chooseMenuItem(page, STRINGS.screenPermissionsResetAction);
    await page.waitForSelector('[role="dialog"] .ocu-warning-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[role="dialog"] .ocu-warning-consequence', (node) => node.textContent.trim()), STRINGS.screenPermissionsResetConsequence);
    await assertStructure(page, ROUTE, true);
    await page.click('[role="dialog"] .ocu-button-primary');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await openRail(page, 'system-explorer');
    await page.waitForFunction(
      (label) => Array.from(document.querySelectorAll('app-side-bar .ocu-side-bar-item')).some((item) => item.querySelector('.ocu-side-bar-label')?.textContent.trim() === label && item.getAttribute('aria-disabled') !== 'true'),
      { timeout: config.navigationTimeoutMs },
      STRINGS.explorerClassListLabel
    );
    assert.equal(await page.evaluate(() => window.__ocuNoReload === true), true, 'and still not reloaded');
    await openRail(page, 'agent');
    await waitForRows(page, config.navigationTimeoutMs);
    await assertStructure(page, ROUTE);
  } finally {
    await context.close();
    resetAdjustments();
  }
});

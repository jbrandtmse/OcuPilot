/**
 * The Namespaces list and its editor in a real browser, against the throwaway instance (Story 18.2).
 *
 * What it pins, each on rendered DOM, on the real URL or on the instance itself:
 *
 * 1. **The list** (AC1): OS management's sixth side-bar entry reads "Namespaces", and HSCUSTOM's and
 *    USER's rows show the databases the instance holds for them.
 * 2. **Create, edit and delete through the screens** (AC1, AC2): a taken name, in another case, is
 *    refused on its field and changes nothing; Create over USER/USER replaces the route with the new
 *    namespace's edit and stores `TempGlobals` `IRISTEMP`; the editor's Routines change sends that
 *    field alone; the row shows both on the list; the namespace switch offers the new namespace
 *    without a reload, and after the row's Delete no longer offers it.
 * 3. **Delete with bound applications** (AC2): the typed-name dialog's advisory names both probe
 *    applications as deleted with the namespace and its databases as staying, passes DW-1337 in both
 *    themes, and the typed name removes the namespace and both applications while the databases stay.
 * 4. **OcuPilot's own namespace** (AC2): its Delete dialog states the kernel's refusal when it opens;
 *    the leg only opens and cancels it.
 * 5. **DW-1337** (AC4): the list and the create form pass the structural walk at wide light, narrow
 *    light and wide dark.
 *
 * **It refuses the live container.** It creates `OCUPROBE182BR` through the form, seeds
 * `OCUPROBE182BD` with two bound web applications in `%SYS` (test-only), and removes every one of
 * them by exact name before and after, asserting none survives.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1
 * browser/namespaces.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { authHeader, saveAndSettle, signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));
const { encodeEntityId } = await import(join(uiRoot, 'src', 'app', 'core', 'entity-id.ts'));

const config = browserConfig();

/** The namespace the create leg makes, and the one `before` seeds with two bound applications. */
const CREATED = 'OCUPROBE182BR';
const SEEDED = 'OCUPROBE182BD';
const APPS = ['/csp/ocuprobe182bd1', '/csp/ocuprobe182bd2'];
const MARKER = 'OcuPilot namespaces browser spec probe (throwaway)';

const LIST_ROUTE = 'os-management/namespaces';
const FORM_ROUTE = 'os-management/namespaces/edit';
const LIST_URL = `/ocupilot/${LIST_ROUTE}?ns=HSCUSTOM`;
const CREATE_URL = `/ocupilot/${FORM_ROUTE}?ns=HSCUSTOM`;
const SAVE_PATH = '/api/ocupilot/namespace';
const ACTION_PATH = '/api/ocupilot/screens/osmgmt.namespaces/action';
const ID = 'ocu-namespace';

/** The row cells' own text selector, a name cell being a link. */
const NAME_TEXT = '.ocu-data-table-link, .ocu-data-table-text';

let browser = null;

const mark = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/** Run `lines` in `%SYS` inside the throwaway and return the value each named marker carries. */
function irisSys(lines, names = []) {
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', '%SYS'], {
    input: `${[...lines, 'Halt'].join('\n')}\n`,
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const values = {};
  for (const name of names) {
    const found = new RegExp(`OCU-${name}-START:(.*?):OCU-${name}-END`).exec(output);
    values[name] = found === null ? null : found[1].trim();
  }
  return { values, output };
}

/** Remove the probe applications, then the probe namespaces, each by its exact name. */
const cleanupLines = [
  ...APPS.map((app) => `If ##class(Security.Applications).Exists("${app}") Do ##class(Security.Applications).Delete("${app}")`),
  ...[CREATED, SEEDED].map((name) => `If ##class(Config.Namespaces).Exists("${name}") Do ##class(Config.Namespaces).Delete("${name}")`),
];

/** Whether no probe object survives. */
const noneSurvives = [...APPS.map((app) => `('##class(Security.Applications).Exists("${app}"))`), ...[CREATED, SEEDED].map((name) => `('##class(Config.Namespaces).Exists("${name}"))`)].join('&&');

/** The instance's `{Globals, Routines, TempGlobals}` for namespace `name`, or `null` when it holds none. */
function stored(name) {
  const { values, output } = irisSys(
    [
      `Kill p Set tSC=##class(Config.Namespaces).Get("${name}",.p)`,
      mark('NS', '$Select($System.Status.IsOK(tSC):$Get(p("Globals"))_","_$Get(p("Routines"))_","_$Get(p("TempGlobals")),1:"<absent>")'),
    ],
    ['NS']
  );
  assert.notEqual(values.NS, null, `the namespace read answered:\n${output}`);
  if (values.NS === '<absent>') return null;
  const [Globals, Routines, TempGlobals] = values.NS.split(',');
  return { Globals, Routines, TempGlobals };
}

/** The web applications whose namespace is `name`, ignoring case, in name order. */
function boundApps(name) {
  const { values, output } = irisSys(
    [
      `Set tR=##class(%SQL.Statement).%ExecDirect(,"SELECT Name FROM Security.Applications WHERE UPPER(NameSpace) = ? ORDER BY Name","${name}"),tL=""`,
      'While tR.%Next() { Set tL=tL_$Select(tL="":"",1:",")_tR.%Get("Name") }',
      mark('APPS', 'tL'),
    ],
    ['APPS']
  );
  assert.notEqual(values.APPS, null, `the application read answered:\n${output}`);
  return values.APPS === '' ? [] : values.APPS.split(',');
}

/** Whether the instance still configures database `name`. */
function databaseExists(name) {
  return irisSys([mark('DB', `##class(Config.Databases).Exists("${name}")`)], ['DB']).values.DB === '1';
}

/** The namespace OcuPilot's own API application runs in, as the instance holds it. */
function installNamespace() {
  const { values, output } = irisSys(['Kill p Set tSC=##class(Security.Applications).Get("/api/ocupilot",.p)', mark('INSTALL', '$Get(p("NameSpace"))')], ['INSTALL']);
  assert.ok(values.INSTALL, `OcuPilot's API application names its namespace:\n${output}`);
  return values.INSTALL.toUpperCase();
}

/** Up to three names joined by ", ", then " and <n> more", as the impact line lists them. */
function namesOf(names) {
  const shown = names.slice(0, 3).join(', ');
  const rest = names.length - 3;
  return rest > 0 ? `${shown}${STRINGS.readBackMore.replace('<n>', () => String(rest))}` : shown;
}

/**
 * The advisory a namespace delete's dialog states for `apps` deleted with it and the distinct
 * databases of `held`, in the instance's name order.
 */
function impactLine(apps, held) {
  const databases = [...new Set([held.Globals, held.Routines, held.TempGlobals].filter((name) => name !== ''))].sort();
  const counted = (list, many, one, none) =>
    list.length === 0 ? none : (list.length === 1 ? one : many.replace('<n>', () => String(list.length))).replace('<names>', () => namesOf(list));
  const parts = [
    counted(apps, STRINGS.impactBoundApplications, STRINGS.impactBoundApplicationsOne, STRINGS.impactBoundApplicationsNone),
    counted(databases, STRINGS.impactDatabasesStay, STRINGS.impactDatabasesStayOne, ''),
  ].filter((phrase) => phrase !== '');
  return STRINGS.impactLine.replace('<parts>', () => parts.join('; '));
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates and deletes namespaces and web applications, so it never runs inside the live container');
  await assertThrowaway(config);
  const { values, output } = irisSys(
    [
      ...cleanupLines,
      'Kill p Set p("Globals")="USER",p("Routines")="USER"',
      `Set tSC=##class(Config.Namespaces).Create("${SEEDED}",.p)`,
      ...APPS.map(
        (app) =>
          `If $System.Status.IsOK(tSC) Kill a Set a("NameSpace")="${SEEDED}",a("Enabled")=1,a("AutheEnabled")=32,a("Description")="${MARKER}",tSC=##class(Security.Applications).Create("${app}",.a)`
      ),
      mark('MADE', '$System.Status.IsOK(tSC)'),
      mark('BR', `##class(Config.Namespaces).Exists("${CREATED}")`),
    ],
    ['MADE', 'BR']
  );
  assert.equal(values.MADE, '1', `the seeded namespace and its two applications were made:\n${output}`);
  assert.equal(values.BR, '0', 'and the namespace the create leg makes does not exist yet');
  assert.deepEqual(boundApps(SEEDED), APPS, 'exactly the two probe applications run in the seeded namespace');
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  const { values, output } = irisSys([...cleanupLines, mark('CLEAN', noneSurvives)], ['CLEAN']);
  assert.equal(values.CLEAN, '1', `no probe namespace or application survives:\n${output}`);
});

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

/** The rendered row whose name cell reads `name`, as its first four cells' text, or `null`. */
function rowCells(page, name) {
  return page.evaluate(
    (selector, wanted, textSelector) => {
      const rows = Array.from(document.querySelectorAll(selector));
      const row = rows.find((candidate) => {
        const cell = candidate.querySelector('[role="gridcell"]');
        const text = cell?.querySelector(textSelector);
        return ((text ?? cell)?.textContent ?? '').trim() === wanted;
      });
      if (row === undefined) return null;
      return Array.from(row.querySelectorAll('[role="gridcell"]'))
        .slice(0, 4)
        .map((cell) => cell.textContent.trim());
    },
    ROW_SELECTOR,
    name,
    NAME_TEXT
  );
}

/** Wait until the list draws a row for `name` reading `cells`. */
async function rowReads(page, name, cells) {
  await waitForRows(page, config.navigationTimeoutMs);
  await page.waitForFunction(
    (selector, wanted, expected, textSelector) => {
      const row = Array.from(document.querySelectorAll(selector)).find((candidate) => {
        const cell = candidate.querySelector('[role="gridcell"]');
        const text = cell?.querySelector(textSelector);
        return ((text ?? cell)?.textContent ?? '').trim() === wanted;
      });
      if (row === undefined) return false;
      return JSON.stringify(Array.from(row.querySelectorAll('[role="gridcell"]')).slice(0, 4).map((cell) => cell.textContent.trim())) === JSON.stringify(expected);
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name,
    cells,
    NAME_TEXT
  );
}

/** Narrow the list to `name`, select its row and open its row menu. */
async function openRowMenu(page, name) {
  await waitForRows(page, config.navigationTimeoutMs);
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, name);
  await page.waitForFunction(
    (selector, wanted, textSelector) =>
      Array.from(document.querySelectorAll(selector)).some((row) => {
        const cell = row.querySelector('[role="gridcell"]');
        const text = cell.querySelector(textSelector);
        return (text === null ? cell : text).textContent.trim() === wanted;
      }),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name,
    NAME_TEXT
  );
  await clickRowCentre(page, { text: name, cell: 2 });
  await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
}

/** Open the Delete dialog on `name`'s row and answer its consequence and advisory once both render. */
async function openDelete(page, name, expectedAdvisory) {
  await openRowMenu(page, name);
  await page.evaluate((label) => {
    Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'))
      .find((item) => item.textContent.trim().startsWith(label))
      .click();
  }, STRINGS.actionDelete);
  await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
  await page.waitForFunction(
    (wanted) => (document.querySelector('[role="dialog"] [data-slot="advisory"] .ocu-banner-message')?.textContent ?? '').trim() === wanted,
    { timeout: config.navigationTimeoutMs },
    expectedAdvisory
  );
  return page.evaluate(() => ({
    title: document.querySelector('[role="dialog"] .ocu-dialog-title').textContent.trim(),
    consequence: document.querySelector('.ocu-typed-name-consequence').textContent.trim(),
    advisory: (document.querySelector('[role="dialog"] [data-slot="advisory"] .ocu-banner-message')?.textContent ?? '').trim(),
  }));
}

/** Escape the open dialog and wait for it to close. */
async function dismiss(page) {
  await page.keyboard.press('Escape');
  await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
}

/** Type the namespace's name into the open dialog and confirm, then wait for the dialog to close. */
async function confirmDelete(page, name) {
  await page.type('.ocu-typed-name-field', name);
  await page.keyboard.press('Enter');
  await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: 90000 });
}

/** The namespaces the switch offers, read by opening it and closed again afterwards. */
async function switchOffers(page, name, offered) {
  await page.waitForSelector('.ocu-namespace-switch-trigger', { visible: true, timeout: config.navigationTimeoutMs });
  await page.click('.ocu-namespace-switch-trigger');
  await page.waitForSelector('.ocu-namespace-switch-option', { timeout: config.navigationTimeoutMs });
  await page.waitForFunction(
    (wanted, present) => Array.from(document.querySelectorAll('.ocu-namespace-switch-option')).some((node) => node.textContent.trim() === wanted) === present,
    { timeout: config.navigationTimeoutMs },
    name,
    offered
  );
  const names = await page.$$eval('.ocu-namespace-switch-option', (nodes) => nodes.map((node) => node.textContent.trim()));
  await page.keyboard.press('Escape');
  await page.waitForFunction(() => document.querySelector('.ocu-namespace-switch-list') === null, { timeout: config.navigationTimeoutMs });
  return names;
}

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
 * DW-1337 on `route`: 1280 light (every invariant), 720 light and 1280 dark, against the baseline;
 * with a dialog open, also the dialog body's own sideways overflow.
 */
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

// AC1. Mutation (Rule 19): give NamespaceList `sideBarPosition` 0, regenerate the mirror, rebuild and
// redeploy -> the side-bar assertion goes red.
test('AC1: Namespaces is the sixth OS management entry, and HSCUSTOM and USER show the databases the instance holds', async () => {
  const hscustom = stored('HSCUSTOM');
  const user = stored('USER');
  assert.ok(hscustom !== null && user !== null, 'the instance holds both namespaces');
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const bar = await sideBarOf(page);
    assert.equal(bar.area, STRINGS.navAreaOsManagement);
    assert.deepEqual(bar.entries.slice(0, 6), [
      STRINGS.processListLabel,
      STRINGS.lockListLabel,
      STRINGS.systemUsageLabel,
      STRINGS.databaseListLabel,
      STRINGS.deviceListLabel,
      STRINGS.namespaceListLabel,
    ]);
    const headers = await page.$$eval('.ocu-data-table-header-label', (labels) => labels.map((label) => label.textContent.trim()));
    assert.deepEqual(headers.slice(0, 4), [STRINGS.tableColumnName, STRINGS.namespaceColumnGlobals, STRINGS.namespaceColumnRoutines, STRINGS.namespaceColumnTemp]);
    assert.deepEqual(await rowCells(page, 'HSCUSTOM'), ['HSCUSTOM', hscustom.Globals, hscustom.Routines, hscustom.TempGlobals]);
    assert.deepEqual(await rowCells(page, 'USER'), ['USER', user.Globals, user.Routines, user.TempGlobals]);
  } finally {
    await context.close();
  }
});

// AC1. Mutation (Rule 19): drop the bus subscription from `ScopeService`'s constructor, rebuild and
// redeploy -> the switch never offers the new namespace and the switch leg goes red.
test('AC1: a taken name is refused, Create round-trips, the Routines change sends one field, and the switch follows the create and the delete without a reload', async () => {
  const userBefore = stored('USER');
  const taken = await (
    await fetch(`${config.origin}${SAVE_PATH}/name?name=user`, { headers: { Authorization: authHeader(config) } })
  ).json();
  assert.equal(taken.taken, true, `the instance answers "user" taken: ${JSON.stringify(taken)}`);
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const loads = [];
  page.on('load', () => loads.push(page.url()));
  const saves = [];
  page.on('request', (request) => {
    const path = new URL(request.url()).pathname;
    if (request.method() !== 'GET' && (path === SAVE_PATH || path.startsWith(`${SAVE_PATH}/`))) saves.push({ method: request.method(), path, body: request.postData() ?? '' });
  });
  const answers = [];
  page.on('response', (response) => {
    const path = new URL(response.url()).pathname;
    if (response.request().method() === 'POST' && path === SAVE_PATH) answers.push(response.status());
  });
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await (await page.waitForSelector('.ocu-command-bar button.ocu-button-primary', { visible: true, timeout: config.navigationTimeoutMs })).click();
    await page.waitForFunction((route) => new URL(window.location.href).pathname.endsWith(`/${route}`), { timeout: config.navigationTimeoutMs }, FORM_ROUTE);
    await page.waitForSelector(`#${ID}-Name`, { visible: true, timeout: config.navigationTimeoutMs });
    const labels = await page.$$eval('.ocu-form-fields .ocu-field-label', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(labels, [STRINGS.tableColumnName, STRINGS.namespaceColumnGlobals, STRINGS.namespaceColumnRoutines, STRINGS.namespaceColumnTemp]);

    // A taken name, in another case: refused on its field at blur and at Save, and nothing changes.
    await page.type(`#${ID}-Name`, 'user');
    await page.keyboard.press('Tab');
    await page.waitForFunction((id, sentence) => document.querySelector(`#${id}-Name-reason`)?.textContent.trim() === sentence, { timeout: config.navigationTimeoutMs }, ID, taken.reason);
    await page.select(`#${ID}-Globals`, 'USER');
    await page.select(`#${ID}-Routines`, 'USER');
    const refused = page.waitForResponse((response) => response.request().method() === 'POST' && new URL(response.url()).pathname === SAVE_PATH, { timeout: config.navigationTimeoutMs });
    await page.click('.ocu-form-bar-actions .ocu-button-primary');
    await refused;
    await page.waitForFunction(() => document.querySelector('.ocu-form-summary') !== null, { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval(`#${ID}-Name-reason`, (node) => node.textContent.trim()), taken.reason, 'the Save is refused on the name');
    assert.ok(answers.length === 1 && answers[0] >= 400, `the create was refused: ${JSON.stringify(answers)}`);
    assert.deepEqual(stored('USER'), userBefore, 'and USER is unchanged');

    // The create: USER for both, no temporary database chosen.
    await page.click(`#${ID}-Name`, { clickCount: 3 });
    await page.type(`#${ID}-Name`, CREATED);
    await saveAndSettle(page, config);
    await page.waitForFunction((suffix) => new URL(window.location.href).pathname.endsWith(suffix), { timeout: config.navigationTimeoutMs }, `/${FORM_ROUTE}/${encodeEntityId(CREATED)}`);
    const posted = saves.filter((save) => save.method === 'POST').map((save) => JSON.parse(save.body));
    assert.deepEqual(posted.at(-1), { Name: CREATED, Globals: 'USER', Routines: 'USER' }, 'the create sends no empty temporary database');
    assert.deepEqual(stored(CREATED), { Globals: 'USER', Routines: 'USER', TempGlobals: 'IRISTEMP' }, 'the instance holds the namespace at its default temporary database');
    assert.deepEqual(boundApps(CREATED), [], 'and the create made no web application');
    const offered = await switchOffers(page, CREATED, true);
    assert.ok(offered.includes(CREATED), `the switch offers the new namespace: ${JSON.stringify(offered)}`);

    // The edit: another routines database, sent alone.
    await page.waitForFunction((id) => document.querySelector(`#${id}-Routines`)?.value === 'USER', { timeout: config.navigationTimeoutMs }, ID);
    assert.equal(await page.$eval(`#${ID}-Name`, (node) => node.readOnly), true, 'the edit shows the name read-only');
    const choices = await page.$$eval(`#${ID}-Routines option`, (options) => options.map((option) => option.value));
    const routines = choices.includes('IRISTEMP') ? 'IRISTEMP' : choices.find((value) => value !== '' && value !== 'USER');
    assert.ok(routines, 'the instance offers a second database');
    await page.select(`#${ID}-Routines`, routines);
    await saveAndSettle(page, config);
    const put = saves.filter((save) => save.method === 'PUT');
    assert.deepEqual(put.map((save) => [save.path, JSON.parse(save.body)]), [[`${SAVE_PATH}/${encodeEntityId(CREATED)}`, { Routines: routines }]], 'the edit sends the one changed field');
    const held = stored(CREATED);
    assert.deepEqual(held, { Globals: 'USER', Routines: routines, TempGlobals: 'IRISTEMP' }, 'and the instance holds the complete set');

    // The list shows the row, then its Delete removes it and the switch drops it.
    await page.click('.ocu-form-bar-actions .ocu-button-text');
    await page.waitForFunction((route) => new URL(window.location.href).pathname.endsWith(`/${route}`), { timeout: config.navigationTimeoutMs }, LIST_ROUTE);
    await rowReads(page, CREATED, [CREATED, held.Globals, held.Routines, held.TempGlobals]);
    const expected = impactLine(boundApps(CREATED), held);
    const dialog = await openDelete(page, CREATED, expected);
    assert.deepEqual(dialog, { title: `${STRINGS.actionDelete} ${CREATED}`, consequence: STRINGS.namespaceDeleteConsequence, advisory: expected });
    await confirmDelete(page, CREATED);
    await page.waitForFunction((selector, name) => !Array.from(document.querySelectorAll(selector)).some((row) => row.textContent.includes(name)), { timeout: 90000 }, ROW_SELECTOR, CREATED);
    assert.equal(stored(CREATED), null, 'the instance no longer holds the namespace');
    const after = await switchOffers(page, CREATED, false);
    assert.ok(!after.includes(CREATED), `the switch no longer offers it: ${JSON.stringify(after)}`);
    assert.deepEqual(loads, [], 'every step was reached without a page load');
  } finally {
    await context.close();
  }
});

// AC2. Mutation (Rule 19): drop `namespace-delete` from `Impact.KindOf`, recompile on the throwaway
// -> the dialog opens with no advisory and this goes red.
test('AC2: Delete on a namespace with two bound applications names both and its databases, passes DW-1337, and removes the namespace and both applications', async () => {
  const held = stored(SEEDED);
  assert.ok(held !== null, 'the seeded namespace exists');
  const expected = impactLine(APPS, held);
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const loads = [];
  page.on('load', () => loads.push(page.url()));
  const writes = [];
  page.on('request', (request) => {
    if (request.method() === 'POST' && request.url().includes(ACTION_PATH)) writes.push(request.postData() ?? '');
  });
  try {
    const before = await switchOffers(page, SEEDED, true);
    assert.ok(before.includes(SEEDED), 'the switch offers the seeded namespace');
    const dialog = await openDelete(page, SEEDED, expected);
    assert.deepEqual(dialog, { title: `${STRINGS.actionDelete} ${SEEDED}`, consequence: STRINGS.namespaceDeleteConsequence, advisory: expected });
    assert.ok(expected.includes(APPS[0]) && expected.includes(APPS[1]), `the advisory names both applications: ${expected}`);
    await assertStructure(page, LIST_ROUTE, true);
    assert.deepEqual(writes, [], 'nothing is sent while the dialog is open');
    await confirmDelete(page, SEEDED);
    await page.waitForFunction((selector, name) => !Array.from(document.querySelectorAll(selector)).some((row) => row.textContent.includes(name)), { timeout: 90000 }, ROW_SELECTOR, SEEDED);
    assert.deepEqual(writes.map((body) => JSON.parse(body)), [{ action: 'delete', id: SEEDED }], 'one delete, sent once the name matched');
    assert.equal(stored(SEEDED), null, 'the namespace is gone');
    assert.deepEqual(boundApps(SEEDED), [], 'and so are both applications');
    for (const app of APPS) {
      assert.equal(irisSys([mark('APP', `##class(Security.Applications).Exists("${app}")`)], ['APP']).values.APP, '0', `${app} is deleted`);
    }
    for (const database of new Set([held.Globals, held.Routines, held.TempGlobals])) {
      assert.equal(databaseExists(database), true, `${database} stays`);
    }
    const after = await switchOffers(page, SEEDED, false);
    assert.ok(!after.includes(SEEDED), `the switch no longer offers it: ${JSON.stringify(after)}`);
    assert.deepEqual(loads, [], 'without a page load');
  } finally {
    await context.close();
  }
});

test("AC2: Delete on OcuPilot's own namespace opens with the kernel's refusal as its advisory", async () => {
  const own = installNamespace();
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const writes = [];
  page.on('request', (request) => {
    if (request.method() === 'POST' && request.url().includes(ACTION_PATH)) writes.push(request.postData() ?? '');
  });
  try {
    const dialog = await openDelete(page, own, STRINGS.namespaceRefusalOcuPilot);
    assert.equal(dialog.advisory, STRINGS.namespaceRefusalOcuPilot);
    await dismiss(page);
    assert.deepEqual(writes, [], 'the leg sends nothing');
    assert.notEqual(stored(own), null, `${own} still exists`);
  } finally {
    await context.close();
  }
});

// AC4. Mutation (Rule 19), over a rebuilt and redeployed bundle: draw `.ocu-field-label` in
// `--ocu-surface` -> the contrast legs go red in both themes.
test('AC4 (DW-1337): the list and the create form pass the structural walk at wide light, narrow light and wide dark', async () => {
  for (const [url, route, ready] of [
    [LIST_URL, LIST_ROUTE, ROW_SELECTOR],
    [CREATE_URL, FORM_ROUTE, `#${ID}-Name`],
  ]) {
    const { context, page } = await signedInAt(browser, config, url, VIEWPORTS.wide);
    try {
      await page.waitForSelector(ready, { visible: true, timeout: config.navigationTimeoutMs });
      await assertStructure(page, route);
    } finally {
      await context.close();
    }
  }
});

/**
 * A namespace's mappings and Copy mappings in a real browser, against the throwaway instance
 * (Story 18.14).
 *
 * What it pins, each on rendered DOM, on the real URL or on the instance itself:
 *
 * 1. **The Mappings line** (AC1): the editor of a probe namespace holding one mapping of each kind
 *    links its global, routine and package mapping lists; each opens at the namespace as its route id
 *    and shows the mapping the instance holds, none takes a side-bar position, and each list's
 *    locator leads back to Namespaces.
 * 2. **Create, edit and delete a global mapping through the screens** (AC2, AC3): the list's Create
 *    carries the namespace into the form, a name beginning with `%` shows the system-global line under
 *    Name, the create replaces the route with the new mapping's edit, the name cell opens that edit,
 *    whose Database change sends that field alone, and the typed-name Delete removes the mapping.
 * 3. **Copy mappings** (AC6): the Namespaces list's row action copies the source's mappings into the
 *    destination behind its dialog, the status line reads running then done, and the destination holds
 *    every mapping the source held.
 * 4. **DW-1337** (AC8): a mapping list, the mapping form and the copy dialog pass the structural walk
 *    at wide light, narrow light and wide dark.
 *
 * **It refuses the live container.** It creates `OCUPROBE1814BA` and `OCUPROBE1814BB` over USER in
 * `%SYS` (test-only seeding), seeds the first with one `OcuProbe1814`-named mapping of each kind, and
 * removes every probe mapping and both namespaces by exact name before and after, asserting none
 * survives. It writes no mapping of USER, HSCUSTOM or %SYS.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1
 * browser/namespace-mappings.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { saveAndSettle, signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));
const { encodeEntityId, joinCompositeId } = await import(join(uiRoot, 'src', 'app', 'core', 'entity-id.ts'));

const config = browserConfig();

/** The namespace seeded with one mapping of each kind, and the one mappings are created in and copied into. */
const SOURCE = 'OCUPROBE1814BA';
const DESTINATION = 'OCUPROBE1814BB';
const NAMESPACES = [SOURCE, DESTINATION];

/** The seeded mappings, by kind, and the global mapping the create leg makes. */
const SEEDED = { global: 'OcuProbe1814SG', routine: 'OcuProbe1814SR', package: 'OcuProbe1814SP' };
const CREATED = 'OcuProbe1814G';

/** Each kind's vendor configuration class and its list's side-bar title. */
const KINDS = [
  { kind: 'global', config: 'Config.MapGlobals', label: STRINGS.globalMappingListLabel },
  { kind: 'routine', config: 'Config.MapRoutines', label: STRINGS.routineMappingListLabel },
  { kind: 'package', config: 'Config.MapPackages', label: STRINGS.packageMappingListLabel },
];

/** Every probe mapping this spec may leave, by class and name, in every probe namespace. */
const PROBE_MAPPINGS = [
  ['Config.MapGlobals', SEEDED.global],
  ['Config.MapGlobals', CREATED],
  ['Config.MapRoutines', SEEDED.routine],
  ['Config.MapPackages', SEEDED.package],
];

const LIST_ROUTE = 'os-management/namespaces';
const EDITOR_ROUTE = 'os-management/namespaces/edit';
const GLOBAL_LIST_ROUTE = 'os-management/namespaces/global-mappings';
const GLOBAL_FORM_ROUTE = 'os-management/namespaces/global-mappings/edit';
const LIST_URL = `/ocupilot/${LIST_ROUTE}?ns=HSCUSTOM`;
const MAPPING_PATH = '/api/ocupilot/mapping/global';
const ACTION_PATH = '/api/ocupilot/screens/osmgmt.namespaces/action';
const ID = 'ocu-mapping';

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

/** Remove every probe mapping from each probe namespace, then the namespaces, each by its exact name. */
const cleanupLines = [
  ...NAMESPACES.flatMap((namespace) =>
    PROBE_MAPPINGS.map(([cls, name]) => `If ##class(${cls}).Exists("${namespace}","${name}") Do ##class(${cls}).Delete("${namespace}","${name}")`)
  ),
  ...NAMESPACES.map((name) => `If ##class(Config.Namespaces).Exists("${name}") Do ##class(Config.Namespaces).Delete("${name}")`),
];

/** Whether no probe mapping and no probe namespace survives. */
const noneSurvives = [
  ...NAMESPACES.flatMap((namespace) => PROBE_MAPPINGS.map(([cls, name]) => `('##class(${cls}).Exists("${namespace}","${name}"))`)),
  ...NAMESPACES.map((name) => `('##class(Config.Namespaces).Exists("${name}"))`),
].join('&&');

/** The database the instance maps `name` of kind `cls` to in `namespace`, or `null` when it holds no such mapping. */
function mappedDatabase(cls, namespace, name) {
  const { values, output } = irisSys(
    [`Kill p Set tSC=##class(${cls}).Get("${namespace}","${name}",.p)`, mark('MAP', '$Select($System.Status.IsOK(tSC):$Get(p("Database")),1:"<absent>")')],
    ['MAP']
  );
  assert.notEqual(values.MAP, null, `the mapping read answered:\n${output}`);
  return values.MAP === '<absent>' ? null : values.MAP;
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates and deletes namespaces and mappings, so it never runs inside the live container');
  await assertThrowaway(config);
  const { values, output } = irisSys(
    [
      ...cleanupLines,
      'Kill p Set p("Globals")="USER",p("Routines")="USER",tSC=1',
      ...NAMESPACES.map((name) => `If $System.Status.IsOK(tSC) Set tSC=##class(Config.Namespaces).Create("${name}",.p)`),
      'Kill m Set m("Database")="USER"',
      `If $System.Status.IsOK(tSC) Set tSC=##class(Config.MapGlobals).Create("${SOURCE}","${SEEDED.global}",.m)`,
      `If $System.Status.IsOK(tSC) Set tSC=##class(Config.MapRoutines).Create("${SOURCE}","${SEEDED.routine}",.m)`,
      `If $System.Status.IsOK(tSC) Set tSC=##class(Config.MapPackages).Create("${SOURCE}","${SEEDED.package}",.m)`,
      mark('MADE', '$System.Status.IsOK(tSC)'),
    ],
    ['MADE']
  );
  assert.equal(values.MADE, '1', `the two probe namespaces and the source's three mappings were made:\n${output}`);
  for (const { config: cls, kind } of KINDS) {
    assert.equal(mappedDatabase(cls, SOURCE, SEEDED[kind]), 'USER', `the source holds its ${kind} mapping`);
    assert.equal(mappedDatabase(cls, DESTINATION, SEEDED[kind]), null, `and the destination holds no ${kind} mapping yet`);
  }
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  const { values, output } = irisSys([...cleanupLines, mark('CLEAN', noneSurvives)], ['CLEAN']);
  assert.equal(values.CLEAN, '1', `no probe mapping or namespace survives:\n${output}`);
});

/** Wait until the path ends with `suffix`. */
function arrivedAt(page, suffix) {
  return page.waitForFunction((wanted) => new URL(window.location.href).pathname.endsWith(wanted), { timeout: config.navigationTimeoutMs }, suffix);
}

/** The side bar's entry labels, opening it first. */
async function sideBarEntries(page) {
  if ((await page.$('app-side-bar nav.ocu-side-bar')) === null) {
    await page.keyboard.down('Control');
    await page.keyboard.press('b');
    await page.keyboard.up('Control');
  }
  await page.waitForSelector('app-side-bar nav.ocu-side-bar', { timeout: config.navigationTimeoutMs });
  return page.$$eval('app-side-bar nav.ocu-side-bar .ocu-side-bar-item .ocu-side-bar-label', (labels) => labels.map((label) => label.textContent.trim()));
}

/** The first cells' text of every rendered row. */
function names(page) {
  return page.$$eval(ROW_SELECTOR, (rows, textSelector) =>
    rows.map((row) => {
      const cell = row.querySelector('[role="gridcell"]');
      const text = cell?.querySelector(textSelector);
      return ((text ?? cell)?.textContent ?? '').trim();
    }), NAME_TEXT);
}

/** Wait until the list draws a row whose name cell reads `name`, or, with `present` false, none. */
function rowPresent(page, name, present = true) {
  return page.waitForFunction(
    (selector, wanted, textSelector, want) =>
      Array.from(document.querySelectorAll(selector)).some((row) => {
        const cell = row.querySelector('[role="gridcell"]');
        const text = cell?.querySelector(textSelector);
        return ((text ?? cell)?.textContent ?? '').trim() === wanted;
      }) === want,
    { timeout: 90000 },
    ROW_SELECTOR,
    name,
    NAME_TEXT,
    present
  );
}

/** Narrow the list to `name`, select its row and open its row menu. */
async function openRowMenu(page, name) {
  await waitForRows(page, config.navigationTimeoutMs);
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, name);
  await rowPresent(page, name);
  await clickRowCentre(page, { text: name, cell: 2 });
  await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
}

/** Choose the row menu's item labeled `label`. */
async function chooseMenuItem(page, label) {
  await page.evaluate((wanted) => {
    Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'))
      .find((item) => item.textContent.trim().startsWith(wanted))
      .click();
  }, label);
}

/** Every text the copy line shows from now on, recorded in the page so a short-lived line is not missed. */
async function recordOperationLine(page) {
  await page.evaluate(() => {
    const seen = [];
    window.__ocuOperationLines = seen;
    const line = document.querySelector('[data-copy-mappings-operation]');
    new MutationObserver(() => seen.push((line?.textContent ?? '').trim())).observe(line, { childList: true, characterData: true, subtree: true });
  });
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

// AC1. Mutation (Rule 19): answer `[]` from `NamespaceFormPage.mappingLinks`, rebuild and redeploy ->
// the editor shows no Mappings line and this goes red.
test('AC1: the namespace editor links its three mapping lists, each showing the mapping the instance holds, and each leads back to Namespaces', async () => {
  const editorUrl = `/ocupilot/${EDITOR_ROUTE}/${encodeEntityId(SOURCE)}?ns=HSCUSTOM`;
  const { context, page } = await signedInAt(browser, config, editorUrl, VIEWPORTS.wide);
  const loads = [];
  page.on('load', () => loads.push(page.url()));
  try {
    await page.waitForSelector(`#ocu-namespace-Name`, { visible: true, timeout: config.navigationTimeoutMs });
    for (const { kind, label } of KINDS) {
      await page.waitForSelector('[data-namespace-mappings] a.ocu-details-link', { visible: true, timeout: config.navigationTimeoutMs });
      const line = await page.evaluate(() => ({
        label: document.querySelector('#ocu-namespace-mappings-label')?.textContent?.trim(),
        links: Array.from(document.querySelectorAll('[data-namespace-mappings] a.ocu-details-link')).map((link) => link.textContent.trim()),
      }));
      assert.deepEqual(line, { label: STRINGS.oauthResourceServerTabMappings, links: KINDS.map((entry) => entry.label) }, 'the Mappings line names the three lists');
      await page.evaluate((wanted) => {
        Array.from(document.querySelectorAll('[data-namespace-mappings] a.ocu-details-link'))
          .find((link) => link.textContent.trim() === wanted)
          .click();
      }, label);
      await arrivedAt(page, `/os-management/namespaces/${kind}-mappings/${encodeEntityId(SOURCE)}`);
      await waitForRows(page, config.navigationTimeoutMs);
      await rowPresent(page, SEEDED[kind]);
      assert.deepEqual(await names(page), [SEEDED[kind]], `the ${kind} list shows the one ${kind} mapping the source holds`);
      assert.equal(await page.$eval('#ocu-locator-screen', (heading) => heading.textContent.trim()), label, `the locator names the ${kind} list`);
      const entries = await sideBarEntries(page);
      assert.ok(!entries.includes(label), `the ${kind} list takes no side-bar position: ${JSON.stringify(entries)}`);

      // The locator's screen segment leads back to Namespaces, not to the list with no namespace, and
      // the source's name cell opens its editor again.
      await page.click('#ocu-locator-screen button.ocu-locator-link');
      await arrivedAt(page, `/${LIST_ROUTE}`);
      await waitForRows(page, config.navigationTimeoutMs);
      await page.click(FILTER_SELECTOR, { clickCount: 3 });
      await page.keyboard.press('Backspace');
      await page.type(FILTER_SELECTOR, SOURCE);
      await rowPresent(page, SOURCE);
      await clickRowCentre(page, { text: SOURCE, link: true });
      await arrivedAt(page, `/${EDITOR_ROUTE}/${encodeEntityId(SOURCE)}`);
    }
    assert.deepEqual(loads, [], 'every step was reached without a page load');
  } finally {
    await context.close();
  }
});

// AC2, AC3. Mutation (Rule 19): drop the `@if (systemGlobal)` block from the mapping form's create
// Name field, rebuild and redeploy -> the system-global line assertion goes red.
test('AC2, AC3: a global mapping is created from the list, edited from its name cell and deleted with its typed name', async () => {
  const listUrl = `/ocupilot/${GLOBAL_LIST_ROUTE}/${encodeEntityId(DESTINATION)}?ns=HSCUSTOM`;
  const { context, page } = await signedInAt(browser, config, listUrl, VIEWPORTS.wide);
  const saves = [];
  page.on('request', (request) => {
    const path = new URL(request.url()).pathname;
    if (request.method() !== 'GET' && (path === MAPPING_PATH || path.startsWith(`${MAPPING_PATH}/`))) saves.push({ method: request.method(), path, body: request.postData() ?? '' });
  });
  const actions = [];
  page.on('request', (request) => {
    if (request.method() === 'POST' && new URL(request.url()).pathname === '/api/ocupilot/screens/osmgmt.globalmappings/action') actions.push(request.postData() ?? '');
  });
  try {
    await page.waitForSelector('.ocu-data-table-empty-title, [role="grid"]', { timeout: config.navigationTimeoutMs });
    await (await page.waitForSelector('.ocu-command-bar button.ocu-button-primary', { visible: true, timeout: config.navigationTimeoutMs })).click();
    await arrivedAt(page, `/${GLOBAL_FORM_ROUTE}`);
    assert.equal(new URL(page.url()).searchParams.get('namespace'), DESTINATION, 'the Create carries the namespace into the form');
    await page.waitForSelector(`#${ID}-Name`, { visible: true, timeout: config.navigationTimeoutMs });
    const labels = await page.$$eval('.ocu-form-fields .ocu-field-label', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(labels, [STRINGS.tableColumnName, STRINGS.systemInfoDatabase, STRINGS.mappingColumnLockDatabase, STRINGS.mappingColumnCollation]);

    // A name beginning with % states the system-global consequence under Name before any Save.
    await page.type(`#${ID}-Name`, '%OcuProbe1814');
    await page.waitForFunction(() => document.querySelector('[data-mapping-system-global]') !== null, { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-mapping-system-global]', (node) => node.textContent.trim()), STRINGS.mappingSystemGlobalConsequence);
    await page.click(`#${ID}-Name`, { clickCount: 3 });
    await page.type(`#${ID}-Name`, CREATED);
    await page.waitForFunction(() => document.querySelector('[data-mapping-system-global]') === null, { timeout: config.navigationTimeoutMs });

    // The create.
    await page.select(`#${ID}-Database`, 'USER');
    await saveAndSettle(page, config);
    const id = joinCompositeId([DESTINATION, CREATED]);
    await arrivedAt(page, `/${GLOBAL_FORM_ROUTE}/${encodeEntityId(id)}`);
    assert.deepEqual(saves.filter((save) => save.method === 'POST').map((save) => JSON.parse(save.body)), [{ Namespace: DESTINATION, Name: CREATED, Database: 'USER' }], 'the create sends the namespace, the name and the database');
    assert.equal(mappedDatabase('Config.MapGlobals', DESTINATION, CREATED), 'USER', 'the instance holds the new mapping');

    // Back to the list, and the edit from the name cell.
    await page.click('.ocu-form-bar-actions .ocu-button-text');
    await arrivedAt(page, `/${GLOBAL_LIST_ROUTE}/${encodeEntityId(DESTINATION)}`);
    await rowPresent(page, CREATED);
    await clickRowCentre(page, { text: CREATED, link: true });
    await arrivedAt(page, `/${GLOBAL_FORM_ROUTE}/${encodeEntityId(id)}`);
    await page.waitForFunction((field) => document.querySelector(`#${field}-Database`)?.value === 'USER', { timeout: config.navigationTimeoutMs }, ID);
    assert.equal(await page.$eval(`#${ID}-Name`, (node) => node.readOnly), true, 'the edit shows the name read-only');
    const choices = await page.$$eval(`#${ID}-Database option`, (options) => options.map((option) => option.value));
    const other = choices.includes('IRISTEMP') ? 'IRISTEMP' : choices.find((value) => value !== '' && value !== 'USER');
    assert.ok(other, 'the instance offers a second database');
    await page.select(`#${ID}-Database`, other);
    await saveAndSettle(page, config);
    const put = saves.filter((save) => save.method === 'PUT');
    assert.deepEqual(put.map((save) => [save.path, JSON.parse(save.body)]), [[`${MAPPING_PATH}/${encodeEntityId(id)}`, { Database: other }]], 'the edit sends the one changed field to the composite id');
    assert.equal(mappedDatabase('Config.MapGlobals', DESTINATION, CREATED), other, 'and the instance holds it');

    // The typed-name Delete.
    await page.click('.ocu-form-bar-actions .ocu-button-text');
    await arrivedAt(page, `/${GLOBAL_LIST_ROUTE}/${encodeEntityId(DESTINATION)}`);
    await openRowMenu(page, CREATED);
    await chooseMenuItem(page, STRINGS.actionDelete);
    await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    const dialog = await page.evaluate(() => ({
      title: document.querySelector('[role="dialog"] .ocu-dialog-title').textContent.trim(),
      consequence: document.querySelector('.ocu-typed-name-consequence').textContent.trim(),
    }));
    assert.deepEqual(dialog, { title: `${STRINGS.actionDelete} ${CREATED}`, consequence: STRINGS.globalMappingDeleteConsequence });
    assert.deepEqual(actions, [], 'nothing is sent while the dialog is open');
    await page.type('.ocu-typed-name-field', CREATED);
    await page.keyboard.press('Enter');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: 90000 });
    await rowPresent(page, CREATED, false);
    assert.deepEqual(actions.map((body) => JSON.parse(body)), [{ action: 'delete', id }], 'one delete, sent with the row key once the name matched');
    assert.equal(mappedDatabase('Config.MapGlobals', DESTINATION, CREATED), null, 'the instance no longer holds the mapping');
  } finally {
    await context.close();
  }
});

// AC6. Mutation (Rule 19): drop the `continued()` branch from `NamespaceListPage.onCopy`, or read the
// done line before the request answers, rebuild and redeploy -> the running-line assertion goes red.
// AC8 over the status line while it holds text: draw `.ocu-namespace-copy-status` in `--ocu-surface`,
// rebuild and redeploy -> the walk below goes red.
test('AC6: Copy mappings copies the source\u2019s mappings into the destination behind its dialog, with a running line then the done line', async () => {
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const writes = [];
  page.on('request', (request) => {
    if (request.method() === 'POST' && new URL(request.url()).pathname === ACTION_PATH) writes.push(request.postData() ?? '');
  });
  try {
    await openRowMenu(page, DESTINATION);
    await chooseMenuItem(page, STRINGS.namespaceCopyMappingsAction);
    await page.waitForSelector('select[data-copy-mappings-source]', { visible: true, timeout: config.navigationTimeoutMs });
    const opened = await page.evaluate(() => ({
      title: document.querySelector('.ocu-dialog-title')?.textContent?.trim(),
      options: Array.from(document.querySelectorAll('select[data-copy-mappings-source] option')).map((option) => option.value),
      consequence: document.querySelector('[data-copy-mappings-consequence]')?.textContent?.trim(),
    }));
    assert.equal(opened.title, STRINGS.namespaceCopyMappingsAction, 'the dialog is titled with the published words');
    assert.ok(opened.options.includes(SOURCE) && !opened.options.includes(DESTINATION), `the select offers the source and never the row's own namespace: ${JSON.stringify(opened.options)}`);
    assert.equal(opened.consequence, STRINGS.namespaceCopyMappingsConsequence, 'and states the published consequence');
    assert.deepEqual(writes, [], 'nothing is sent while the dialog is open');

    await page.select('select[data-copy-mappings-source]', SOURCE);
    await recordOperationLine(page);
    await page.click('[data-copy-mappings-confirm]');
    const done = STRINGS.namespaceCopyMappingsDone.split('<source>').join(SOURCE).split('<namespace>').join(DESTINATION);
    await page.waitForFunction(
      (expected, still) => [expected, still].includes(document.querySelector('[data-copy-mappings-operation]')?.textContent?.trim()),
      { timeout: 90000 },
      done,
      STRINGS.auditDatabaseStillRunning
    );
    const lines = await page.evaluate(() => window.__ocuOperationLines);
    const running = STRINGS.namespaceCopyMappingsRunning.split('<source>').join(SOURCE).split('<namespace>').join(DESTINATION).split('<time>')[0];
    assert.ok(lines.some((line) => line.startsWith(running)), `the line read running on the instance first: ${JSON.stringify(lines)}`);
    assert.equal(lines.at(-1), done, `and then done, the copy finishing within the port's wait: ${JSON.stringify(lines)}`);
    await assertStructure(page, LIST_ROUTE);
    assert.deepEqual(writes.map((body) => JSON.parse(body)), [{ action: 'copy-mappings', id: DESTINATION, values: { SourceNamespace: SOURCE } }], 'exactly one request, naming the source');
    for (const { config: cls, kind } of KINDS) {
      assert.equal(mappedDatabase(cls, DESTINATION, SEEDED[kind]), 'USER', `the destination holds the source's ${kind} mapping`);
      assert.equal(mappedDatabase(cls, SOURCE, SEEDED[kind]), 'USER', `and the source keeps it`);
    }
  } finally {
    await context.close();
  }
});

// AC8. Mutation (Rule 19), over a rebuilt and redeployed bundle: draw `.ocu-field-label` in
// `--ocu-surface` -> the contrast legs go red in both themes. The copy status line is empty here, so
// the AC6 leg walks it once it holds its done line.
test('AC8 (DW-1337): a mapping list, the mapping form and the copy dialog pass the structural walk at wide light, narrow light and wide dark', async () => {
  for (const [url, route, ready] of [
    [`/ocupilot/${GLOBAL_LIST_ROUTE}/${encodeEntityId(SOURCE)}?ns=HSCUSTOM`, GLOBAL_LIST_ROUTE, ROW_SELECTOR],
    [`/ocupilot/${GLOBAL_FORM_ROUTE}?ns=HSCUSTOM&namespace=${SOURCE}`, GLOBAL_FORM_ROUTE, `#${ID}-Name`],
    [`/ocupilot/${GLOBAL_FORM_ROUTE}/${encodeEntityId(joinCompositeId([SOURCE, SEEDED.global]))}?ns=HSCUSTOM`, GLOBAL_FORM_ROUTE, `#${ID}-Database:not([disabled])`],
  ]) {
    const { context, page } = await signedInAt(browser, config, url, VIEWPORTS.wide);
    try {
      await page.waitForSelector(ready, { visible: true, timeout: config.navigationTimeoutMs });
      await assertStructure(page, route);
    } finally {
      await context.close();
    }
  }
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  try {
    await openRowMenu(page, DESTINATION);
    await chooseMenuItem(page, STRINGS.namespaceCopyMappingsAction);
    await page.waitForSelector('select[data-copy-mappings-source]', { visible: true, timeout: config.navigationTimeoutMs });
    await assertStructure(page, LIST_ROUTE, true);
    await page.keyboard.press('Escape');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
  } finally {
    await context.close();
  }
});

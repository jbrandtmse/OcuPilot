/**
 * Story 20.8 in a real browser, against the throwaway: Interoperability's Schema viewer and Configuration diagram open
 * InterSystems' schema viewer and production configuration app in place, in a frame the signed-in shell draws, read-only
 * where the viewer is (AD-5, AD-44, AD-62, AD-63).
 *
 * What it pins, on `HSCUSTOM` for the Schema viewer and on a probe production in `USER` it creates for the diagram:
 *
 * - AC1: Side bar > Interoperability > Schema viewer draws one frame at the builder's address, the viewer signs itself in
 *   silently, lists as many categories for ASC X12, HL7 v2.x and ASTM as the instance's schema globals hold when the person
 *   picks each in its own list, makes no request but GETs apart from its login, sends no message, fills its host, and
 *   passes the structural and contrast checks in three themes; the structural walk opens it at its bare route.
 * - AC2: the viewer ignores its `&ST` parameter (DW-2396), so the builder sends no document for it. This is a tripwire on the
 *   vendor: a red there means the vendor now honors `&ST`.
 * - AC3: from the probe production's Production items screen, Configuration diagram opens the production configuration app on
 *   it, signed in, showing its four items, and the Productions name cell still opens Production items.
 * - AC4: the app's BPL Editor panel menu > Open in New Tab opens the vendor's standalone editor in a tab holding its own
 *   keys and a copy of the shell's token pair, the shell and its frame are left as they were, and Sign out revokes the copy.
 * - AC5: a production the Productions list does not answer draws its sentence and no frame and no request, and Refresh draws a
 *   new frame element at the same address on both screens.
 * - AC6: Sign out in the account menu ends each app's sign-in.
 *
 * **It compiles and writes a probe production in `USER`, records and restores USER's `^EnsPortal.Settings` nodes for the
 * signed-in user, and removes the message-search row the diagram app stores for the user on each load**
 * (`Ens.Message.Search` rows above the recorded id, and the id counter), so it runs on a throwaway only. It starts nothing.
 * Each test signs in in its own context, waits for the screen's answered signal before it counts, clicks or types, and the
 * `after` hook restores what the run touched and removes the production, whatever the tests answered.
 *
 * Run: `npm run build`, `docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`, then
 * `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> node --test --test-concurrency=1 browser/interop-viewers.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import {
  armMessageCounters,
  assertSignOutEndsEditors,
  assertSignedInSilently,
  editorSessionControls,
  signOutThroughMenu,
  tabSnapshot,
  until,
  waitForEditorTokens,
  watchEditorTraffic,
  watchPolicyViolations,
} from './interop-editor-spec.mjs';
import { clickRowCentre, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { openFromSideBar, signedInAt } from './panel-spec.mjs';
import { INVARIANTS, SKIP, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, keyRoute, needsId, readBaseline } from './structural-walk.mjs';
import { escapeOs, markerValue, runIris } from './turnprobe-spec.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { interopEditorSource } = await import(join(uiRoot, 'src', 'app', 'core', 'vendor-frame.ts'));
const { encodeEntityId } = await import(join(uiRoot, 'src', 'app', 'core', 'entity-id.ts'));
const { SCREENS } = await import(join(uiRoot, 'src', 'app', 'core', 'screens.generated.ts'));
const { PAIR_STORAGE_KEY } = await import(join(uiRoot, 'src', 'app', 'core', 'token-store.ts'));

const config = browserConfig();
const STRINGS = loadStrings();

const NAMESPACE = 'HSCUSTOM';
const PROBE_NAMESPACE = 'USER';
const PROBE = 'OcuPilot.Test.ProductionProbe';
const PRODUCTION = 'OcuPilotProbe.Interop.Production';
const ABSENT = 'OcuPilotProbe.Interop.Absent';
const ITEMS = ['OcuPilotProbeOp', 'OcuPilotProbeSvc', 'OcuPilotProbeRouter', 'OcuPilotProbeBpl'];
const SCHEMA_ROUTE = 'interoperability/schema-viewer';
const DIAGRAM_ROUTE = 'interoperability/productions/diagram';
const FRAME = 'app-interop-editor-frame iframe';
const NOTE = '[data-ocu-editor="note"]';
const AGENT = '[data-ocu-editor="agent"]';
const REDUCED_MOTION = [{ name: 'prefers-reduced-motion', value: 'reduce' }];
/** The schema types, in the viewer's own list, with the path segment and global the instance keeps each family under. */
const FAMILIES = [
  { label: 'HL7 v2.x', segment: 'HL7', global: '^EnsHL7.Schema' },
  { label: 'ASTM', segment: 'ASTM', global: '^EnsEDI.ASTM.Schema' },
  { label: 'ASC X12', segment: 'X12', global: '^EnsEDI.X12.Schema' },
];

let browser = null;
let created = false;
/** USER's settings nodes for the signed-in user and the message-search store, as they were before this run. */
let heldSettings = null;
let heldSearch = null;

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** The user's `^EnsPortal.Settings` nodes in USER as `[reference, value]` pairs, read on the instance. */
function readSettings() {
  const user = escapeOs(config.username);
  const output = runIris(config.container, [
    `Set $NAMESPACE="${PROBE_NAMESPACE}"`,
    `Set q="^EnsPortal.Settings(""${user}"")",o=[]`,
    'If $Data(@q)#2 Do o.%Push([(q),(@q)])',
    `For { Set q=$Query(@q) Quit:q=""  Quit:$QSubscript(q,1)'="${user}"  Do o.%Push([(q),(@q)]) }`,
    'Write "OCU-VWSET-START:"_o.%ToJSON()_":OCU-VWSET-END",!',
  ]);
  const json = markerValue(output, 'VWSET');
  assert.notEqual(json, null, `USER's settings nodes read: ${output}`);
  return JSON.parse(json);
}

/** Put the user's settings nodes in USER back as `held` recorded them: the subtree is killed, then each node is set. */
function restoreSettings(held) {
  const user = escapeOs(config.username);
  runIris(config.container, [
    `Set $NAMESPACE="${PROBE_NAMESPACE}"`,
    `Kill ^EnsPortal.Settings("${user}")`,
    `Set o=##class(%DynamicAbstractObject).%FromJSON("${escapeOs(JSON.stringify(held))}")`,
    'Set it=o.%GetIterator() While it.%GetNext(.i,.pair) { Set @pair.%Get(0)=pair.%Get(1) }',
  ]);
}

/** The message-search store in USER: whether its global is defined and holds a counter, the counter, and the highest row id. */
function readSearch() {
  const output = runIris(config.container, [
    `Set $NAMESPACE="${PROBE_NAMESPACE}"`,
    'Set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT MAX(ID) FROM Ens_Message.Search") Do rs.%Next() Set m=+rs.%GetData(1)',
    'Write "OCU-VWSEARCH-START:"_$Data(^Ens.Message.SearchD)_"|"_$Get(^Ens.Message.SearchD)_"|"_m_":OCU-VWSEARCH-END",!',
  ]);
  const [data, counter, max] = String(markerValue(output, 'VWSEARCH') ?? '').split('|');
  assert.match(data ?? '', /^\d+$/, `the message-search store reads: ${output}`);
  return { data: Number(data), counter, max: Number(max) };
}

/** Delete the message-search rows above `held.max`, and put the id counter back, or kill the global it was undefined and holds no row. */
function restoreSearch(held) {
  runIris(config.container, [
    `Set $NAMESPACE="${PROBE_NAMESPACE}"`,
    `Set rs=##class(%SQL.Statement).%ExecDirect(,"DELETE FROM Ens_Message.Search WHERE ID > ?",${held.max})`,
    held.data === 0
      ? 'If $Order(^Ens.Message.SearchD(""))="" Kill ^Ens.Message.SearchD'
      : `If $Data(^Ens.Message.SearchD)#2 Set ^Ens.Message.SearchD="${escapeOs(held.counter)}"`,
  ]);
}

/** How many categories the instance holds for each family, by label, counted from its schema globals in `HSCUSTOM`. */
function categoryCounts() {
  const output = runIris(config.container, [
    `Set $NAMESPACE="${NAMESPACE}"`,
    `Set s="" For g="${FAMILIES.map((family) => family.global).join('","')}" { Set n=0,k="" For { Set k=$Order(@g@(k)) Quit:k=""  Set n=n+1 } Set s=s_n_"," }`,
    'Write "OCU-VWCAT-START:"_s_":OCU-VWCAT-END",!',
  ]);
  const counts = String(markerValue(output, 'VWCAT') ?? '').split(',').filter((entry) => entry !== '').map(Number);
  assert.equal(counts.length, FAMILIES.length, `the schema globals are counted: ${output}`);
  return Object.fromEntries(FAMILIES.map((family, index) => [family.label, counts[index]]));
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec compiles a probe production and writes message-search rows, so it runs only in a throwaway; ${config.container} is not one`);
  heldSettings = readSettings();
  heldSearch = readSearch();
  const removed = probe('VWCLEAN', `$System.Status.IsOK(##class(${PROBE}).Remove())`);
  assert.equal(removed.value, '1', `an earlier run's probe is removed: ${removed.output}`);
  created = true;
  const made = probe('VWMADE', `$System.Status.IsOK(##class(${PROBE}).Create())`);
  assert.equal(made.value, '1', `the probe production is created: ${made.output}`);
  const router = probe('VWROUTER', `$System.Status.IsOK(##class(${PROBE}).AddItem("OcuPilotProbeRouter","EnsLib.MsgRouter.RoutingEngine",1,1,"BusinessRuleName","OcuPilotProbe.Interop.Rule"))`);
  assert.equal(router.value, '1', `the routing engine item is added: ${router.output}`);
  const bpl = probe('VWBPL', `$System.Status.IsOK(##class(${PROBE}).AddItem("OcuPilotProbeBpl","EnsLib.Background.Process.ExportMessageSearch",1,1))`);
  assert.equal(bpl.value, '1', `the BPL item is added: ${bpl.output}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    browser = null;
    if (created && /-ci$/.test(config.container)) {
      // What the app wrote is restored first, so a failed removal below still leaves the instance as it was.
      if (heldSettings !== null) restoreSettings(heldSettings);
      if (heldSearch !== null) restoreSearch(heldSearch);
      const gone = probe('VWGONE', `$System.Status.IsOK(##class(${PROBE}).Remove())_##class(${PROBE}).Gone()`);
      if (heldSettings !== null) assert.deepEqual(readSettings(), heldSettings, "the user's settings nodes in USER are as they were");
      if (heldSearch !== null) assert.deepEqual(readSearch(), heldSearch, 'the message-search store in USER is as it was');
      assert.equal(gone.value, '11', `the probe production is removed: ${gone.output}`);
    }
  }
});

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function twoFrames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/** Wait until no CSS transition is running, so a contrast read measures the theme it is in. */
function transitionsSettled(page) {
  return page.waitForFunction(
    () => document.getAnimations().every((animation) => !(animation instanceof CSSTransition) || animation.playState !== 'running'),
    { timeout: config.navigationTimeoutMs }
  );
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
    await page.setViewport(viewport);
    await page.evaluate((dark) => document.documentElement.classList.toggle('ocu-theme-dark', dark), theme === 'dark');
    await twoFrames(page);
    await transitionsSettled(page);
    surfaces[theme] = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
    const { entries } = await detectScreen(page, { route, checks, viewport: viewport.width, theme, minimums });
    found.push(...entries);
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await twoFrames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  return compare(collapse(found), readBaseline()?.entries ?? []).fresh.map((entry) => `${entry.key}: ${entry.measured}`);
}

/** A fresh signed-in context at `url`, with the apps' observers armed before the first request, so nothing a screen draws goes unseen. */
async function shellAt(url) {
  const observers = {};
  const { context, page } = await signedInAt(browser, config, url, VIEWPORTS.wide, REDUCED_MOTION, async (opened) => {
    observers.traffic = watchEditorTraffic(opened);
    observers.violations = watchPolicyViolations(opened);
    observers.messages = await armMessageCounters(opened);
  });
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  return { context, page, ...observers };
}

/** The screen has answered: its section is no longer busy and it draws a block. */
async function answered(page) {
  await page.waitForFunction(
    () => {
      const section = document.querySelector('app-interop-editor-page section');
      return section !== null && section.getAttribute('aria-busy') === 'false' && section.querySelector('[data-ocu-editor]') !== null;
    },
    { timeout: config.navigationTimeoutMs }
  );
}

/** The screen's frame, as a puppeteer frame, once it is drawn. */
async function appFrame(page) {
  const handle = await page.waitForSelector(FRAME, { timeout: config.navigationTimeoutMs });
  return handle.contentFrame();
}

/** Wait until the frame's app shows the signed-in person and every text in `texts`. */
async function appShows(page, texts) {
  const frame = await appFrame(page);
  await until(
    () => frame.evaluate(() => document.body.innerText),
    (body) => body.includes(config.username) && texts.every((text) => body.includes(text)),
    `the app shows ${JSON.stringify(texts)}`,
    config.navigationTimeoutMs
  );
  return frame;
}

/** The path of the page's address, with the entity encoding the router applies to an id undone twice. */
const decodedPath = (page) => decodeURIComponent(decodeURIComponent(new URL(page.url()).pathname));

/** The box of the frame, its host and the outlet, which the layout assertions compare. */
function boxes(page) {
  return page.evaluate(() => {
    const rect = (node) => {
      const box = node.getBoundingClientRect();
      return { left: box.left, top: box.top, width: box.width, height: box.height, bottom: box.bottom };
    };
    const host = document.querySelector('app-interop-editor-frame');
    return { host: rect(host), frame: rect(host.querySelector('iframe')), outlet: rect(document.querySelector('.ocu-screen-outlet')) };
  });
}

/** The frame fills its host, to a pixel, ends at the outlet's bottom edge, and is at least 400 px tall. */
async function assertFillsHost(page) {
  const box = await boxes(page);
  for (const side of ['left', 'top', 'width', 'height']) {
    assert.ok(Math.abs(box.frame[side] - box.host[side]) <= 1, `the frame's ${side} equals its host's: ${JSON.stringify(box)}`);
  }
  assert.ok(Math.abs(box.host.bottom - box.outlet.bottom) <= 1, `the host ends at the outlet's bottom edge: ${JSON.stringify(box)}`);
  assert.ok(box.frame.height >= 400, `the frame is at least 400 px tall: ${box.frame.height}`);
}

/** The frame's `src` attributes, one per drawn frame. */
const frameSources = (page) => page.$$eval(FRAME, (nodes) => nodes.map((node) => node.getAttribute('src')));

/** What the viewer says about its category list: the number after "Total Categories:", or `null`. */
async function totalCategories(frame) {
  const match = /Total Categories: (\d+)/.exec(await frame.evaluate(() => document.body.innerText));
  return match === null ? null : Number(match[1]);
}

/** Pick `label` in the viewer's own schema type list, and wait until the viewer shows it as the chosen type. */
async function chooseSchemaType(frame, label) {
  await frame.click('mat-select[name="schema_type_list"]');
  await frame.waitForSelector('mat-option', { visible: true, timeout: config.navigationTimeoutMs });
  const chosen = await frame.evaluate((wanted) => {
    const option = [...document.querySelectorAll('mat-option')].find((node) => node.textContent.trim() === wanted);
    option?.click();
    return option !== undefined;
  }, label);
  assert.equal(chosen, true, `the viewer's schema type list offers ${label}`);
  await until(
    () => frame.$eval('.schema-type-select .mat-mdc-select-value-text', (node) => node.textContent.trim()),
    (text) => text === label,
    `the viewer shows ${label} as its schema type`,
    config.navigationTimeoutMs
  );
}

/** Open the probe production's Production items screen from its Productions name cell, and wait for its rows. */
async function openItems(page) {
  await waitForRows(page, config.navigationTimeoutMs);
  await clickRowCentre(page, { text: PRODUCTION, link: true });
  await page.waitForFunction((suffix) => new URL(window.location.href).pathname.includes(suffix), { timeout: config.navigationTimeoutMs }, '/interoperability/productions/items/');
  await waitForRows(page, config.navigationTimeoutMs);
}

/** From the Production items screen, choose its Configuration diagram link and wait for the diagram screen to answer. */
async function openDiagram(page) {
  await page.waitForSelector('.ocu-interop-item-links a', { timeout: config.navigationTimeoutMs });
  assert.equal(await page.$eval('.ocu-interop-item-links a', (node) => node.textContent.trim()), STRINGS.interopProductionDiagramTitle, 'the link reads the diagram\'s title');
  await page.click('.ocu-interop-item-links a');
  await answered(page);
}

/** The probe production's diagram screen, reached by its own address. */
const diagramUrl = (production) => `/ocupilot/${DIAGRAM_ROUTE}/${encodeEntityId(production)}?ns=${PROBE_NAMESPACE}`;

// Mutation (Rule 19): the page maps `InteropSchemaViewer` with `listFrom: 'document'` (bundle rebuilt and redeployed) -> no list resolves,
// no frame is drawn and the frame wait goes red, and so does the page spec.
// Mutation (Rule 19): `structural-walk.mjs` `needsId` restored to every `viewer (source)` -> the walk assertions go red, naming the schema
// viewer as unresolved.
test('AC1: the Schema viewer opens in place from the side bar: the builder\'s address, a silent sign-in, each family\'s categories from its own list, only GETs after its login, a frame that fills the screen', async () => {
  const counts = categoryCounts();
  const { context, page, traffic, violations, messages } = await shellAt(`/ocupilot/interoperability/productions?ns=${NAMESPACE}`);
  try {
    const before = await tabSnapshot(page);
    await openFromSideBar(page, config, '#ocu-rail-item-interoperability', STRINGS.interopSchemaViewerTitle);
    await answered(page);
    assert.equal(decodedPath(page), `/ocupilot/${SCHEMA_ROUTE}`, 'the route is the Schema viewer\'s');
    assert.deepEqual(await frameSources(page), [interopEditorSource('schema-viewer', NAMESPACE)], 'one frame, at the builder\'s address for the viewer and the namespace');
    assert.equal(await page.$eval(NOTE, (node) => node.textContent.trim()), STRINGS.interopSchemaViewerNote, 'with the note that names the schema type it opens on');
    assert.equal(await page.$(AGENT), null, 'and no agent line, since the agent saves nothing here');

    await assertSignedInSilently({ page, config, editor: 'schema-viewer', namespace: NAMESPACE, documentName: '', traffic, messages, violations, before, frameSelector: FRAME });
    const frame = await appShows(page, ['Total Categories']);
    assert.equal(await totalCategories(frame), counts['ASC X12'], 'the viewer opens on ASC X12 and lists as many categories as the instance holds');

    for (const family of FAMILIES) {
      await chooseSchemaType(frame, family.label);
      await until(() => totalCategories(frame), (total) => total === counts[family.label], `${family.label} lists ${counts[family.label]} categories`, config.navigationTimeoutMs);
      const read = traffic.filter((entry) => entry.path === `/api/interop-editors/v7/${NAMESPACE}/schemas/${family.segment}/categories`);
      assert.ok(read.length > 0 && read.every((entry) => entry.method === 'GET' && entry.status === 200), `${family.label}: the viewer read its categories, answered 200`);
    }
    assert.deepEqual(
      traffic.filter((entry) => entry.method !== 'GET').map((entry) => `${entry.method} ${entry.path} ${entry.status}`),
      ['POST /api/interop-editors/login 200'],
      'apart from its empty-body login, every request the frame made is a GET'
    );
    assert.deepEqual(await messages.seen(), [], 'no message reached the shell or the frame');
    assert.deepEqual(violations, [], 'and no content-security-policy violation was reported');
    await assertFillsHost(page);

    const screen = SCREENS.find((candidate) => candidate.route === SCHEMA_ROUTE);
    assert.equal(needsId(screen), false, 'the structural walk opens the Schema viewer at its bare route, as it takes no id');
    assert.equal(keyRoute(screen), SCHEMA_ROUTE);
    assert.equal(Object.hasOwn(SKIP, SCHEMA_ROUTE), false, 'and does not skip it');
    assert.deepEqual(await structural(page, keyRoute(screen)), [], `${SCHEMA_ROUTE}: no violation beyond the baseline's entries`);
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): `interopEditorSource` appends `&%26ST=<document>` for the schema viewer -> the builder clause goes red, and so does
// `vendor-frame.test.mjs`. The harness frame's clauses go red when the vendor honors `&ST`: that is this test's tripwire (DW-2396).
test('AC2: the schema viewer ignores &ST (DW-2396): the builder sends no document for it, and a frame at the classic pages\' own address form opens on ASC X12', async () => {
  for (const document of ['HL7 v2.x', 'HL7', 'ASTM', 'X12']) {
    assert.equal(interopEditorSource('schema-viewer', NAMESPACE, document), null, `the builder answers null for the viewer with the document ${JSON.stringify(document)}`);
  }
  const { context, page } = await shellAt(`/ocupilot/?ns=${NAMESPACE}`);
  try {
    // The classic schema pages' own address form, which the shell never builds: only this harness frame carries it.
    await page.evaluate(() => {
      const frame = document.createElement('iframe');
      frame.setAttribute('id', 'ocu-st-harness');
      frame.setAttribute('title', 'harness');
      frame.setAttribute('src', '/ui/interop/schema-viewer/index.html?%24NAMESPACE=HSCUSTOM&%26ST=HL7+v2.x');
      frame.style.width = '100%';
      frame.style.height = '600px';
      document.querySelector('app-screen-outlet').appendChild(frame);
    });
    const harness = await (await page.waitForSelector('#ocu-st-harness', { timeout: config.navigationTimeoutMs })).contentFrame();
    await until(() => harness.evaluate(() => document.body.innerText), (body) => body.includes('Total Categories'), 'the harness frame lists categories', config.navigationTimeoutMs);
    // The viewer writes its address after it has read it, so the address is read once it has settled.
    await until(() => harness.url(), (address) => address.endsWith('&%26ST='), 'the viewer rewrites its address with an empty &ST', config.navigationTimeoutMs);
    const text = await harness.evaluate(() => document.body.innerText);
    const chosen = await harness.$eval('.schema-type-select .mat-mdc-select-value-text', (node) => node.textContent.trim());
    assert.equal(chosen, 'ASC X12', `the viewer ignored &ST=HL7 v2.x and opened on ASC X12; a red here means the vendor now honors &ST (DW-2396), and the builder can take it for the schema viewer: ${text.slice(0, 200)}`);
    assert.ok(harness.url().endsWith('&%26ST='), `its address ends with an empty &ST: ${harness.url()}`);
    // The read above sees a choice when there is one: picking HL7 v2.x in the viewer's own list changes it.
    await chooseSchemaType(harness, 'HL7 v2.x');
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): the store requires `.cls` for every kind (bundle rebuilt and redeployed) -> the production is gone, no frame is drawn
// and this goes red, and so does the store test.
// Mutation (Rule 19): `InteropProductionDiagram` declared `detail` (bundle rebuilt and redeployed) -> the Productions name cell opens the
// diagram, not Production items, and the final clause goes red, and so does `navigation.test.mjs`.
test('AC3: Configuration diagram, from Production items, draws the production configuration app on the production: the builder\'s address, a silent sign-in, its four items, a frame that fills the screen; the Productions name cell still opens Production items', async () => {
  const { context, page, traffic, violations, messages } = await shellAt(`/ocupilot/interoperability/productions?ns=${PROBE_NAMESPACE}`);
  try {
    await openItems(page);
    const before = await tabSnapshot(page);
    await openDiagram(page);
    assert.equal(decodedPath(page), `/ocupilot/${DIAGRAM_ROUTE}/${PRODUCTION}`, 'the route is the diagram\'s, with the production as its one id segment');
    assert.deepEqual(await frameSources(page), [interopEditorSource('interop-editor', PROBE_NAMESPACE, PRODUCTION)], 'one frame, at the builder\'s address for the app, the namespace and the production');
    assert.equal(await page.$eval(NOTE, (node) => node.textContent.trim()), STRINGS.interopProductionDiagramNote, 'with the note that leaving discards what is not saved');
    assert.equal(await page.$(AGENT), null, 'and no agent line');

    await assertSignedInSilently({ page, config, editor: 'interop-editor', namespace: PROBE_NAMESPACE, documentName: PRODUCTION, traffic, messages, violations, before, frameSelector: FRAME, documentStatus: 200 });
    await appShows(page, ITEMS);
    await assertFillsHost(page);

    const diagram = SCREENS.find((candidate) => candidate.route === DIAGRAM_ROUTE);
    assert.equal(Object.hasOwn(SKIP, DIAGRAM_ROUTE), true, 'the structural walk skips the diagram, which this spec walks on the probe production');
    assert.equal(needsId(diagram), true);
    assert.deepEqual(await structural(page, keyRoute(diagram)), [], `${keyRoute(diagram)}: no violation beyond the baseline's entries`);

    assert.equal(await page.$eval('#ocu-locator-screen .ocu-locator-link', (node) => node.textContent.trim()), STRINGS.interopProductionDiagramTitle, 'the locator names the diagram as a link');
    await page.click('#ocu-locator-screen .ocu-locator-link');
    await page.waitForFunction((route) => location.pathname === `/ocupilot/${route}`, { timeout: config.navigationTimeoutMs }, 'interoperability/productions');
    await openItems(page);
    assert.equal(decodedPath(page), `/ocupilot/interoperability/productions/items/${PRODUCTION}`, 'and from Productions, the probe row\'s name cell still opens Production items');
  } finally {
    await context.close();
  }
});

/** The menu trigger of the app's panel named `label`, or `null` while the app has not drawn that panel's bar. */
function findPanelMenuTrigger(wanted) {
  const bar = [...document.querySelectorAll('.navbuttons')].find((node) => node.querySelector('.navbuttonText')?.textContent.trim() === wanted);
  return bar?.querySelector('.buttonTabMenu') ?? null;
}

/** Open the app's panel menu for the panel named `label`, once the app has drawn it, and answer the menu entry `entry`, once it is visible. */
async function panelMenuEntry(frame, label, panelClass, entry) {
  await frame.waitForFunction(findPanelMenuTrigger, { timeout: config.navigationTimeoutMs }, label);
  const trigger = await frame.evaluateHandle(findPanelMenuTrigger, label);
  assert.notEqual(trigger.asElement(), null, `the app has a ${label} panel with a menu`);
  await trigger.asElement().click();
  return frame.waitForSelector(`.${panelClass} .paneMenuItem ::-p-text(${entry})`, { visible: true, timeout: config.navigationTimeoutMs });
}

// Mutation (Rule 19): the test does not sign out in the shell (the `signOutThroughMenu` step removed) -> the copy's refresh token is still
// accepted, answering 200, and the revoke clause goes red.
test('AC4: the app\'s BPL Editor panel menu opens the vendor\'s editor in a new tab, with its own keys and a copy of the shell\'s pair, leaving the shell and its frame as they were; Sign out revokes the copy', async () => {
  const { context, page } = await shellAt(diagramUrl(PRODUCTION));
  try {
    await answered(page);
    const handle = await page.waitForSelector(FRAME, { timeout: config.navigationTimeoutMs });
    const frame = await appShows(page, ITEMS);
    const shellUrl = page.url();
    const source = await handle.evaluate((node) => node.getAttribute('src'));
    const shellPair = (await tabSnapshot(page)).pair;
    assert.notEqual(shellPair, null, 'the shell holds its token pair');

    const opened = context.waitForTarget((target) => target.url().includes('/ui/interop/bpl-editor/'), { timeout: config.navigationTimeoutMs });
    const entry = await panelMenuEntry(frame, 'BPL Editor', 'changePanel_BPL', 'Open in New Tab');
    await entry.click();
    const tab = await (await opened).page();
    assert.equal(new URL(tab.url()).pathname, '/ui/interop/bpl-editor/index.html', 'a new tab opens at the vendor\'s own BPL editor');
    assert.equal(new URL(tab.url()).searchParams.get('$NAMESPACE'), PROBE_NAMESPACE, 'in the namespace the diagram is in');
    const keys = await until(
      () => tab.evaluate(() => Object.keys(sessionStorage)),
      (held) => held.some((key) => /^BPL_Editor-\d+-accessToken$/.test(key)) && held.some((key) => /^BPL_Editor-\d+-refreshToken$/.test(key)),
      'the tab holds its own BPL_Editor keys',
      config.navigationTimeoutMs
    );
    assert.ok(keys.includes(PAIR_STORAGE_KEY), 'the tab was handed a copy of the shell\'s storage');
    const copy = await tab.evaluate((key) => sessionStorage.getItem(key), PAIR_STORAGE_KEY);
    assert.equal(copy, shellPair, 'whose token pair equals the shell\'s');

    assert.equal(page.url(), shellUrl, 'the shell\'s URL is unchanged');
    assert.equal(await handle.evaluate((node) => node.isConnected), true, 'the diagram\'s frame element is still connected');
    assert.equal(await handle.evaluate((node) => node.getAttribute('src')), source, 'with the address it was drawn with');

    // The refresh a person's own pair is answered by: the control mints a fresh pair and refreshes with it, so a refusal afterwards is the sign-out's.
    const refreshWith = (refreshToken) =>
      page.evaluate(async (token) => {
        const answer = await fetch('/api/ocupilot/refresh', { method: 'POST', credentials: 'omit', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ refresh_token: token }) });
        return answer.status;
      }, refreshToken);
    const login = await page.evaluate(async () => {
      const answer = await fetch('/api/ocupilot/login', { method: 'POST', credentials: 'include' });
      return { status: answer.status, text: await answer.text() };
    });
    assert.equal(login.status, 200, 'while signed in the empty-body login answers 200');
    assert.equal(await refreshWith(JSON.parse(login.text).refresh_token), 200, 'and a refresh with a live refresh token answers 200');

    await page.bringToFront();
    await signOutThroughMenu(page, config.navigationTimeoutMs);
    assert.equal(await refreshWith(JSON.parse(copy).refreshToken), 401, 'after Sign out the tab copy\'s refresh token is refused');
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): the store opens a row the read did not return (bundle rebuilt and redeployed) -> a frame is drawn for the absent
// production and the gone leg goes red, and so does the store test.
// Mutation (Rule 19): the frame component's `@for` tracks a constant key (bundle rebuilt and redeployed) -> the element is kept, and the
// Refresh legs go red, and so does `interop-editor-frame.spec.ts`.
test('AC5: a production the Productions list does not answer draws its sentence, no frame and no app request, and Refresh draws a new frame element at the same address on both screens', async (t) => {
  await t.test('gone', async () => {
    const { context, page, traffic } = await shellAt(diagramUrl(ABSENT));
    try {
      await answered(page);
      assert.equal(await page.$eval('[data-ocu-editor="gone"]', (node) => node.textContent.trim()), STRINGS.interopProductionDiagramEmpty, 'the screen says the production no longer exists');
      assert.deepEqual(await page.$$('iframe'), [], 'and draws no frame');
      assert.equal(await page.$(NOTE), null, 'nor the note about the diagram');
      assert.deepEqual(traffic, [], 'and nothing is requested under /ui/interop/ or /api/interop-editors/');
    } finally {
      await context.close();
    }
  });

  for (const { label, url, editor, namespace, document, shown } of [
    { label: 'Schema viewer', url: `/ocupilot/${SCHEMA_ROUTE}?ns=${NAMESPACE}`, editor: 'schema-viewer', namespace: NAMESPACE, document: '', shown: ['Total Categories'] },
    { label: 'Configuration diagram', url: diagramUrl(PRODUCTION), editor: 'interop-editor', namespace: PROBE_NAMESPACE, document: PRODUCTION, shown: ITEMS },
  ]) {
    await t.test(`Refresh: ${label}`, async () => {
      const { context, page } = await shellAt(url);
      try {
        await answered(page);
        const first = await page.waitForSelector(FRAME, { timeout: config.navigationTimeoutMs });
        await appShows(page, shown);
        await page.click('[data-ocu-editor="refresh"]');
        await until(() => first.evaluate((node) => node.isConnected), (connected) => connected === false, 'the old frame element is detached', config.navigationTimeoutMs);
        await answered(page);
        const second = await page.waitForSelector(FRAME, { timeout: config.navigationTimeoutMs });
        assert.equal(await second.evaluate((node) => node.getAttribute('src')), interopEditorSource(editor, namespace, document), 'a new element at the same address');
        assert.equal((await page.$$(FRAME)).length, 1, 'and it is the only frame');
        await appShows(page, shown);
      } finally {
        await context.close();
      }
    });
  }
});

// Mutation (Rule 19): `Session.signOut()` posts `/logout` with `credentials: 'omit'` (bundle rebuilt and redeployed) -> the browser-level login
// survives and the empty-body login answers 200 for both screens, so this goes red.
test('AC6: Sign out in the account menu ends each app\'s sign-in on the real screens: no frame, no app key, and its login, access token and refresh token are refused', async (t) => {
  for (const { label, url, editor, shown } of [
    { label: 'Schema viewer', url: `/ocupilot/${SCHEMA_ROUTE}?ns=${NAMESPACE}`, editor: 'schema-viewer', shown: ['Total Categories'] },
    { label: 'Configuration diagram', url: diagramUrl(PRODUCTION), editor: 'interop-editor', shown: ITEMS },
  ]) {
    await t.test(label, async () => {
      const { context, page, traffic } = await shellAt(url);
      try {
        await answered(page);
        await appShows(page, shown);
        const held = await waitForEditorTokens(page, editor, config.navigationTimeoutMs);
        await until(() => traffic.filter((entry) => entry.path === '/api/interop-editors/login'), (entries) => entries.some((entry) => entry.status === 200), 'the app signed in', config.navigationTimeoutMs);
        assert.equal((await page.$$(FRAME)).length, 1, 'one frame is drawn before the sign-out');

        await editorSessionControls(page, held);
        await signOutThroughMenu(page, config.navigationTimeoutMs);
        await assertSignOutEndsEditors(page, held);
      } finally {
        await context.close();
      }
    });
  }
});

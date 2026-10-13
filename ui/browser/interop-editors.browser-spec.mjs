/**
 * Story 20.7 in a real browser, against the throwaway: the Business rules, Business processes and Data transformations name cells open
 * the class in InterSystems' rule, BPL or DTL editor, in place, in a frame the signed-in shell draws (AD-5, AD-44, AD-63).
 *
 * What it pins, on three probe classes in `HSCUSTOM` it creates (`OcuPilotProbe.EditorScreen.Rule`, `.Process` and `.Transform`, each
 * compiled, and `.Broken`, a transformation stored without compiling whose code does not compile):
 *
 * - AC1 and the walk: from each list's name cell the route is `<list>/document/<class>.cls`, one frame is drawn with the builder's
 *   address, the editor signs itself in silently and reads its document (200), every `/ui/interop/` request is the editor's own on the
 *   instance's origin, the frame fills its host and the host ends at the outlet's bottom edge, the locator links to the list, and the
 *   DW-1337 checks find nothing beyond the baseline at 1280 light, 720 light and 1280 dark.
 * - AC2: the DTL editor's saved and compiled notices, and the compile error of `.Broken`, appear inside the frame and no message
 *   reaches the shell or the frame; the list's Modified is the class definition's `TimeChanged`. The vendor's compile route uses the
 *   null device without opening it, so in a web process that has closed that device it fails with the editor's generic server-error
 *   notice whatever the class holds; a Compile leg takes that notice for its outcome only when the instance log records the failure
 *   for its click.
 * - AC3: a class the list does not answer, and a process or transformation written as a class, draw their sentences and no frame and
 *   no editor request.
 * - AC4: the editor moving itself (its Back to standard UI) is left alone, Refresh draws a new frame, and a route change in the screen
 *   draws a new frame at the new document, with no unsaved-changes alert from an editor holding a change; the old frame element is
 *   detached each time.
 * - Namespace move: the header's switch takes the frame away, a namespace that does not hold the class draws the screen's sentence
 *   and requests nothing, and moving back draws a new frame (the real scope service, which the component specs stub).
 * - AC5: Sign out ends the editor's sign-in on the real screen.
 *
 * **It creates classes in `HSCUSTOM` and records and restores two of the editors' own settings nodes**
 * (`^EnsPortal.Settings(<user>, "LastDTL")` and `"LastBP"`), so it runs on a throwaway only. Each test signs in in its own context, waits
 * for the screen's answered signal before it counts, clicks or types, and the `after` hook restores the nodes and removes the classes.
 * The namespace move also needs a second interoperability namespace the switch offers, which the image ships (`USER`, `HSLIB`, `HSSYS`).
 *
 * Run: `npm run build`, `docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`, then
 * `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> node --test --test-concurrency=1 browser/interop-editors.browser-spec.mjs`.
 */

import { spawnSync } from 'node:child_process';
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
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { readNamespaceFeatures, waitForMapAnswered } from './namespace-features.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { escapeOs, markerValue, runIris } from './turnprobe-spec.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { interopEditorSource } = await import(join(uiRoot, 'src', 'app', 'core', 'vendor-frame.ts'));
const { encodeEntityId } = await import(join(uiRoot, 'src', 'app', 'core', 'entity-id.ts'));

const config = browserConfig();
const STRINGS = loadStrings();

const NAMESPACE = 'HSCUSTOM';
const PACKAGE = 'OcuPilotProbe.EditorScreen';
const FRAME = 'app-interop-editor-frame iframe';
const NOTE = '[data-ocu-editor="note"]';
/** A Data transformations row of the vendor's own, which opens in the DTL editor. */
const VENDOR_DTL = 'Ens.Util.DTL.Audit.MessageView.cls';
const REDUCED_MOTION = [{ name: 'prefers-reduced-motion', value: 'reduce' }];
/** The editor's notice when its compile route fails inside the vendor's code, which names neither the class nor the compiler's text. */
const VENDOR_FAILURE_NOTICE = /Internal Server Error/;
/** What the instance's log records when the vendor's DTL compile route uses a null device that its web process has closed. */
const NULL_DEVICE_FAILURE = '<NOTOPEN>CompileDTL';
const INSTANCE_LOG = '/durable/iris/mgr/messages.log';

/** The three screens: each list, the editor it opens, and the probe class and title it is tested with. */
const KINDS = [
  { key: 'rule', listRoute: 'interoperability/rules', editor: 'rule-editor', name: `${PACKAGE}.Rule.cls`, title: STRINGS.interopRuleEditorTitle, empty: STRINGS.interopRuleEditorEmpty },
  { key: 'process', listRoute: 'interoperability/processes', editor: 'bpl-editor', name: `${PACKAGE}.Process.cls`, title: STRINGS.interopBplEditorTitle, empty: STRINGS.interopBplEditorEmpty },
  { key: 'transform', listRoute: 'interoperability/transforms', editor: 'dtl-editor', name: `${PACKAGE}.Transform.cls`, title: STRINGS.interopDtlEditorTitle, empty: STRINGS.interopDtlEditorEmpty },
];
const TRANSFORM = KINDS[2];
const BROKEN = `${PACKAGE}.Broken.cls`;

/** The probe classes' source, one line each, as UDL. */
const SOURCE = {
  Rule: [
    `Class ${PACKAGE}.Rule Extends Ens.Rule.Definition`,
    '{',
    'XData RuleDefinition [ XMLNamespace = "http://www.intersystems.com/rule" ]',
    '{',
    '<ruleDefinition alias="" context="EnsLib.MsgRouter.RoutingEngine" production="">',
    '<ruleSet name="" effectiveBegin="" effectiveEnd=""><rule name=""><when condition="1"></when></rule></ruleSet>',
    '</ruleDefinition>',
    '}',
    '}',
  ],
  Process: [
    `Class ${PACKAGE}.Process Extends Ens.BusinessProcessBPL`,
    '{',
    'XData BPL [ XMLNamespace = "http://www.intersystems.com/bpl" ]',
    '{',
    "<process language='objectscript' request='Ens.Request' response='Ens.Response' height='2000' width='2000'>",
    "<sequence xend='200' yend='350'/>",
    '</process>',
    '}',
    '}',
  ],
  Transform: [
    `Class ${PACKAGE}.Transform Extends Ens.DataTransformDTL`,
    '{',
    'Parameter IGNOREMISSINGSOURCE = 1;',
    'Parameter REPORTERRORS = 1;',
    'XData DTL [ XMLNamespace = "http://www.intersystems.com/dtl" ]',
    '{',
    "<transform sourceClass='Ens.StringRequest' targetClass='Ens.StringResponse' create='new' language='objectscript'>",
    "<assign value='source.StringValue' property='target.StringValue' action='set' />",
    '</transform>',
    '}',
    '}',
  ],
  Broken: [
    `Class ${PACKAGE}.Broken Extends Ens.DataTransformDTL`,
    '{',
    'Parameter IGNOREMISSINGSOURCE = 1;',
    'Parameter REPORTERRORS = 1;',
    'XData DTL [ XMLNamespace = "http://www.intersystems.com/dtl" ]',
    '{',
    "<transform sourceClass='Ens.StringRequest' targetClass='Ens.StringResponse' create='new' language='objectscript'>",
    '<code><![CDATA[ Set tBroken = (]]></code>',
    '</transform>',
    '}',
    '}',
  ],
};

/** The editors' own settings nodes the vendor's DTL and BPL editors write when they open a document. */
const SETTINGS = ['LastDTL', 'LastBP'];

let browser = null;
let created = false;
/** What each settings node held before this run: `{ present, value }`, by node name. */
let heldSettings = null;

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** An ObjectScript expression for the lines of a class, joined by the line break UDL expects. */
function textOf(lines) {
  return lines.map((line) => `"${escapeOs(line)}"`).join('_$Char(13,10)_');
}

/** The node `^EnsPortal.Settings(<user>, <name>)` as an ObjectScript reference. */
const settingsNode = (name) => `^EnsPortal.Settings("${escapeOs(config.username)}","${name}")`;

/** Whether each settings node exists and what it holds, read on the instance. */
function readSettings() {
  const held = {};
  for (const name of SETTINGS) {
    const read = probe(`SET${name}`, `$Data(${settingsNode(name)})_"|"_$Get(${settingsNode(name)})`);
    const [present, ...value] = String(read.value).split('|');
    assert.match(present, /^\d+$/, `the ${name} node reads: ${read.output}`);
    held[name] = { present: Number(present) > 0, value: value.join('|') };
  }
  return held;
}

/** The class definition's `TimeChanged` as the list reads it, from the instance. */
function definitionModified(name) {
  const read = probe('DEFTIME', `$ZDateTime(##class(%Dictionary.ClassDefinition).%OpenId("${escapeOs(name)}").TimeChanged,3)`);
  assert.match(String(read.value), /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/, `the definition's TimeChanged reads: ${read.output}`);
  return String(read.value);
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec compiles probe classes and edits settings nodes, so it runs only in a throwaway; ${config.container} is not one`);
  const removed = probe('EDCLEAN', `$System.Status.IsOK($System.OBJ.DeletePackage("${PACKAGE}","-d"))`);
  assert.equal(removed.value, '1', `an earlier run's probe classes are removed: ${removed.output}`);
  heldSettings = readSettings();
  created = true;
  for (const [name, lines] of Object.entries(SOURCE)) {
    const made = probe(`EDDEF${name}`, `$System.Status.IsOK(##class(%Compiler.UDL.TextServices).SetTextFromString("${NAMESPACE}","${PACKAGE}.${name}",${textOf(lines)}))`);
    assert.equal(made.value, '1', `the probe class ${name} is stored: ${made.output}`);
  }
  const compiled = probe('EDCOMPILE', `$System.Status.IsOK($System.OBJ.Compile("${PACKAGE}.Rule,${PACKAGE}.Process,${PACKAGE}.Transform","ck-d"))`);
  assert.equal(compiled.value, '1', `the probe classes compile (the broken one is left uncompiled): ${compiled.output}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    browser = null;
    if (created && /-ci$/.test(config.container)) {
      // The nodes are restored first, so a failed removal below still leaves them as they were.
      if (heldSettings !== null) {
        for (const name of SETTINGS) {
          const held = heldSettings[name];
          runIris(config.container, [held.present ? `Set ${settingsNode(name)}="${escapeOs(held.value)}"` : `Kill ${settingsNode(name)}`]);
        }
      }
      const gone = probe('EDGONE', `$System.Status.IsOK($System.OBJ.DeletePackage("${PACKAGE}","-d"))`);
      const exists = Object.keys(SOURCE).map((name) => `##class(%Dictionary.ClassDefinition).%ExistsId("${PACKAGE}.${name}")`);
      const left = probe('EDLEFT', exists.join('+'));
      if (heldSettings !== null) assert.deepEqual(readSettings(), heldSettings, "the editors' settings nodes are as they were");
      assert.equal(gone.value, '1', `the probe classes are removed: ${gone.output}`);
      assert.equal(left.value, '0', `no probe class is left: ${left.output}`);
    }
  }
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
    await frames(page);
    await transitionsSettled(page);
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

/** The editor screen's URL for `name` under `listRoute`, as the name cell builds it. */
const screenUrl = (listRoute, name) => `/ocupilot/${listRoute}/document/${encodeEntityId(name)}?ns=${NAMESPACE}`;

/** A fresh signed-in context at `url`, with the editors' observers armed before the first request, so nothing a screen draws goes unseen. */
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

/** The editor screen has answered the list's read: its section is no longer busy and it draws a block. */
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
async function editorFrame(page) {
  const handle = await page.waitForSelector(FRAME, { timeout: config.navigationTimeoutMs });
  return handle.contentFrame();
}

/** Wait until the frame's editor shows the signed-in person and `text`. */
async function editorShows(page, text) {
  const frame = await editorFrame(page);
  await until(() => frame.evaluate(() => document.body.innerText), (body) => body.includes(config.username) && body.includes(text), `the editor shows ${text}`, config.navigationTimeoutMs);
  return frame;
}

/** Wait until the list on screen has drawn its rows, narrow it to `name`, and answer that row's cells once it is the one shown. */
async function narrowTo(page, name) {
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  await waitForRows(page, config.navigationTimeoutMs);
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, name.slice(0, -'.cls'.length));
  return rowCells(page, name);
}

/** Wait until the table holds a row whose name cell reads `name`, and answer that row's cells. */
async function rowCells(page, name) {
  await page.waitForFunction(
    (rowSelector, wanted) => Array.from(document.querySelectorAll(rowSelector)).some((row) => row.querySelector('[role="gridcell"]')?.textContent.trim() === wanted),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name
  );
  return page.evaluate(
    (rowSelector, wanted) =>
      Array.from(document.querySelectorAll(rowSelector))
        .map((row) => Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim()))
        .find((cells) => cells[0] === wanted),
    ROW_SELECTOR,
    name
  );
}

/** Load the list at `listRoute` afresh, as a person returning to it does. */
async function openList(page, listRoute) {
  await page.goto(`${config.origin}/ocupilot/${listRoute}?ns=${NAMESPACE}`, { waitUntil: 'networkidle2' });
}

/** The path of the page's address, with the entity encoding the router applies to an id undone twice. */
const decodedPath = (page) => decodeURIComponent(decodeURIComponent(new URL(page.url()).pathname));

/** The box of each element the layout assertions compare. */
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

/** Wait until the editor's snackbar reads a sentence `accept` takes, and answer the sentence. */
async function snackbarWhere(frame, accept, what) {
  return until(
    () => frame.evaluate(() => Array.from(document.querySelectorAll('.mdc-snackbar__label')).map((node) => node.innerText.trim())),
    (labels) => labels.some(accept),
    what,
    config.navigationTimeoutMs
  ).then((labels) => labels.find(accept));
}

/** Wait until the editor's snackbar reads a sentence containing `text`, and answer the sentence. */
const snackbarWith = (frame, text) => snackbarWhere(frame, (label) => label.includes(text), `the editor's notice contains ${JSON.stringify(text)}`);

/** How many lines of the instance's log record the vendor's DTL compile route failing on a null device its web process has closed. */
function nullDeviceFailures() {
  const read = spawnSync('docker', ['exec', config.container, 'grep', '-c', '-F', NULL_DEVICE_FAILURE, INSTANCE_LOG], { encoding: 'utf8' });
  // `grep -c` answers no match with a count of 0 and status 1.
  assert.ok(read.status === 0 || read.status === 1, `the instance log reads: ${read.stderr}`);
  return Number(read.stdout.trim());
}

/**
 * Choose Compile in the DTL editor and answer the editor's own notice, and whether it is the vendor's failure notice.
 *
 * The vendor's compile route uses the null device without opening it, so in a web process that has closed that device it fails
 * whatever the class holds, and the editor shows its generic server-error notice. That notice is taken for the outcome only when the
 * instance's log records the failure after this click. A notice that is neither `expected` nor that one is never taken.
 */
async function compileNotice(frame, expected) {
  const failures = nullDeviceFailures();
  await frame.click('#top-banner-button-4-secondary');
  const notice = await snackbarWhere(
    frame,
    (label) => label.includes(expected) || VENDOR_FAILURE_NOTICE.test(label),
    `the editor reports the compile in its own notice (${JSON.stringify(expected)}, or the vendor's failure notice)`
  );
  if (notice.includes(expected)) return { notice, vendorFailure: false };
  await until(nullDeviceFailures, (count) => count > failures, `the instance's log records ${NULL_DEVICE_FAILURE} for the notice ${JSON.stringify(notice)}`, config.navigationTimeoutMs);
  return { notice, vendorFailure: true };
}

// Mutation (Rule 19): the page passes `document` with its `.cls` kept (bundle rebuilt and redeployed) -> the editor's document read answers
// 404 and the 200 clause goes red, and so does the page spec.
// Mutation (Rule 19): the frame component's `:host` loses `height: 100%` (bundle rebuilt and redeployed) -> the frame is 150 px tall and
// the box clauses go red.
test('AC1: each list\'s name cell opens its editor in place: the builder\'s address, a silent sign-in, only the editor\'s own requests, a frame that fills the screen', async (t) => {
  for (const kind of KINDS) {
    await t.test(kind.key, async () => {
      const { context, page, traffic, violations, messages } = await shellAt(`/ocupilot/${kind.listRoute}?ns=${NAMESPACE}`);
      try {
        const before = await tabSnapshot(page);
        await narrowTo(page, kind.name);
        await clickRowCentre(page, { text: kind.name, link: true });
        await answered(page);
        assert.equal(decodedPath(page), `/ocupilot/${kind.listRoute}/document/${kind.name}`, 'the route is the list\'s document route for the class');
        const document = kind.name.slice(0, -'.cls'.length);
        const frames = await page.$$eval(FRAME, (nodes) => nodes.map((node) => node.getAttribute('src')));
        assert.deepEqual(frames, [interopEditorSource(kind.editor, NAMESPACE, document)], 'one frame, at the builder\'s address for the editor, the namespace and the document');
        assert.equal(await page.$eval(NOTE, (node) => node.textContent.trim()), STRINGS.interopEditorNote, 'with the note that asks the person to save first');

        await assertSignedInSilently({ page, config, editor: kind.editor, namespace: NAMESPACE, documentName: document, traffic, messages, violations, before, frameSelector: FRAME, documentStatus: 200 });
        await editorShows(page, document);

        const owned = await until(
          () => traffic.filter((entry) => entry.path.startsWith('/ui/interop/')),
          (entries) => entries.length > 0 && entries.every((entry) => entry.status !== null),
          'every file the editor requested under /ui/interop/ is answered',
          config.navigationTimeoutMs
        );
        for (const entry of owned) {
          assert.equal(entry.origin, new URL(config.origin).origin, `${entry.path} is on the instance's origin`);
          assert.ok(entry.path.startsWith(`/ui/interop/${kind.editor}/`), `${entry.path} is the ${kind.editor}'s own`);
          assert.equal(entry.status, 200, `${entry.path} is answered by the instance`);
        }

        const box = await boxes(page);
        for (const side of ['left', 'top', 'width', 'height']) {
          assert.ok(Math.abs(box.frame[side] - box.host[side]) <= 1, `the frame's ${side} equals its host's: ${JSON.stringify(box)}`);
        }
        assert.ok(Math.abs(box.host.bottom - box.outlet.bottom) <= 1, `the host ends at the outlet's bottom edge: ${JSON.stringify(box)}`);
        assert.ok(box.frame.height >= 400, `the frame is at least 400 px tall: ${box.frame.height}`);

        const link = await page.$eval('#ocu-locator-screen .ocu-locator-link', (node) => node.textContent.trim());
        assert.equal(link, kind.title, 'the locator names the editor screen as a link');
        await page.click('#ocu-locator-screen .ocu-locator-link');
        await page.waitForFunction((route) => location.pathname === `/ocupilot/${route}`, { timeout: config.navigationTimeoutMs }, kind.listRoute);
      } finally {
        await context.close();
      }
    });
  }
});

test('AC1: each editor screen passes the structural and contrast checks at 1280 light, 720 light and 1280 dark, with no entry beyond the baseline', async (t) => {
  for (const kind of KINDS) {
    await t.test(kind.key, async () => {
      const { context, page } = await shellAt(screenUrl(kind.listRoute, kind.name));
      try {
        await answered(page);
        await editorShows(page, kind.name.slice(0, -'.cls'.length));
        assert.deepEqual(await structural(page, `${kind.listRoute}/document/:id`), [], `${kind.listRoute}/document/:id: no violation beyond the baseline's entries`);
      } finally {
        await context.close();
      }
    });
  }
});

// Mutation (Rule 19): `ListClasses` reads `Modified` from the compiled class rather than the definition -> the Modified leg goes red (the
// list then reads the compile's time, which the wait below keeps at least a second after the save's).
// Mutation (Rule 19): `interopEditorSource` appends the editor's mode flag (bundle rebuilt and redeployed) -> the editor posts the message
// that flag selects and the sign-in the notices need never happens, so the message and notice clauses go red, and so does
// `vendor-frame.test.mjs`.
// Mutation (Rule 19): `compileNotice` does not choose Compile (no notice appears) -> its wait for the editor's notice goes red, whichever
// web process serves the compile.
// Mutation (Rule 19): the editor posts a message to the shell after Compile -> the no-message clause goes red, in either outcome.
// Mutation (Rule 19): `NULL_DEVICE_FAILURE` names a line the log never holds -> with every web process's null device closed, the log
// clause goes red.
test('AC2: the DTL editor\'s saved and compiled notices appear in the frame and send no message, the list\'s Modified is the definition\'s TimeChanged, and a class that does not compile is reported in the editor\'s own notice', async (t) => {
  const document = TRANSFORM.name.slice(0, -'.cls'.length);
  const { context, page, messages } = await shellAt(`/ocupilot/${TRANSFORM.listRoute}?ns=${NAMESPACE}`);
  try {
    const modifiedBefore = (await narrowTo(page, TRANSFORM.name))[1];
    await clickRowCentre(page, { text: TRANSFORM.name, link: true });
    await answered(page);
    const frame = await editorShows(page, document);
    await frame.waitForSelector('#transform-settings-iconbutton', { timeout: config.navigationTimeoutMs });
    await frame.click('#transform-settings-iconbutton');
    await frame.waitForSelector('#transform-settings-description-textarea', { visible: true, timeout: config.navigationTimeoutMs });
    await frame.type('#transform-settings-description-textarea', 'edited by the browser spec');
    // The editor enables Save once it has taken the change.
    await frame.waitForFunction(() => document.querySelector('#top-banner-button-2-secondary')?.disabled === false, { timeout: config.navigationTimeoutMs });
    await frame.click('#top-banner-button-2-secondary');
    assert.equal(await snackbarWith(frame, `${document} saved.`), `${document} saved.`, 'the editor says the class is saved');
    // The compile is at least a second after the save, so the compiled class's time and the definition's cannot be equal at the list's resolution.
    await new Promise((resolve) => setTimeout(resolve, 1100));
    const compiled = await compileNotice(frame, 'compiled successfully');
    if (compiled.vendorFailure) t.diagnostic(`the vendor's compile route failed in the web process that served it; the editor's notice is ${JSON.stringify(compiled.notice)}`);
    else assert.equal(compiled.notice, `${document} compiled successfully`, 'and then that it compiled');
    assert.deepEqual(await messages.seen(), [], 'no message reached the shell or the frame');

    await openList(page, TRANSFORM.listRoute);
    const modifiedAfter = (await narrowTo(page, TRANSFORM.name))[1];
    assert.equal(modifiedAfter, definitionModified(document), 'the list\'s Modified is the class definition\'s TimeChanged');
    assert.notEqual(modifiedAfter, modifiedBefore, 'and it moved with the save');
  } finally {
    await context.close();
  }

  const broken = await shellAt(screenUrl(TRANSFORM.listRoute, BROKEN));
  try {
    await answered(broken.page);
    const frame = await editorShows(broken.page, BROKEN.slice(0, -'.cls'.length));
    await frame.waitForSelector('#top-banner-button-4-secondary', { timeout: config.navigationTimeoutMs });
    const failed = await compileNotice(frame, 'error occurred while compiling');
    if (failed.vendorFailure) t.diagnostic(`the vendor's compile route failed in the web process that served it; the editor's notice is ${JSON.stringify(failed.notice)}`);
    assert.deepEqual(await broken.messages.seen(), [], 'a class that does not compile sends no message either');
  } finally {
    await broken.context.close();
  }
});

// Mutation (Rule 19): the page draws the frame from the route id without checking the row -> the gone leg shows an iframe and sends
// editor requests, and the store test goes red.
// Mutation (Rule 19): `ListClasses` answers `Coded` false for every row -> the coded leg shows an iframe, and the port test's two true rows
// go red.
test('AC3: a class the list does not answer, and a process or transformation written as a class, draw their sentence and no frame and no editor request', async (t) => {
  const cases = [
    { label: 'a rule that does not exist', route: 'interoperability/rules', name: `${PACKAGE}.Absent.cls`, block: 'gone', text: STRINGS.interopRuleEditorEmpty },
    { label: 'a process that does not exist', route: 'interoperability/processes', name: `${PACKAGE}.Absent.cls`, block: 'gone', text: STRINGS.interopBplEditorEmpty },
    { label: 'a transformation that does not exist', route: 'interoperability/transforms', name: `${PACKAGE}.Absent.cls`, block: 'gone', text: STRINGS.interopDtlEditorEmpty },
    { label: 'a process written as a class', route: 'interoperability/processes', name: 'EnsLib.HL7.MsgRouter.RoutingEngine.cls', block: 'coded', text: STRINGS.interopBplEditorCoded },
    {
      label: 'a transformation written as a class',
      route: 'interoperability/transforms',
      name: 'EnsLib.ITK.AdapterKit.Transform.PHDEToXMLDETransform.cls',
      block: 'coded',
      text: STRINGS.interopDtlEditorCoded,
    },
  ];
  for (const { label, route, name, block, text } of cases) {
    await t.test(label, async () => {
      const { context, page, traffic } = await shellAt(screenUrl(route, name));
      try {
        await answered(page);
        assert.equal(await page.$eval(`[data-ocu-editor="${block}"]`, (node) => node.textContent.trim()), text, 'the screen shows its sentence');
        assert.deepEqual(await page.$$('iframe'), [], 'and draws no frame');
        assert.equal(await page.$(NOTE), null, 'nor the note about the editor');
        assert.deepEqual(traffic, [], 'and nothing is requested under /ui/interop/ or /api/interop-editors/');
      } finally {
        await context.close();
      }
    });
  }
});

// Mutation (Rule 19): the component's `@for` tracks a constant key (it keeps the element) (bundle rebuilt and redeployed) ->
// `interop-editor-frame.spec.ts`'s redraw tests go red, and here the old element stays connected and shows the standard page after Refresh.
// Mutation (Rule 19): the store drops its generation check -> the store test's stale-answer row goes red.
// Mutation (Rule 19): the dirty editor's frame has its `src` set again in place before the route change (the design DW-2350 rejected)
// -> the editor raises its unsaved-changes alert and the no-alert clause goes red.
test('AC4: OcuPilot never navigates a drawn frame: the editor moving itself is left alone, Refresh draws a new frame, and a route change draws one at the new document', async () => {
  const document = TRANSFORM.name.slice(0, -'.cls'.length);
  const { context, page } = await shellAt(screenUrl(TRANSFORM.listRoute, TRANSFORM.name));
  try {
    await answered(page);
    const first = await page.waitForSelector(FRAME, { timeout: config.navigationTimeoutMs });
    const frame = await editorShows(page, document);
    const route = decodedPath(page);
    const note = await page.$eval(NOTE, (node) => node.textContent);

    await frame.waitForSelector('#back-to-zen-secondary', { timeout: config.navigationTimeoutMs });
    await frame.click('#back-to-zen-secondary');
    await until(() => frame.url(), (address) => address.includes('/csp/hscustom/EnsPortal.DTLEditor.zen'), 'the editor shows the standard page', config.navigationTimeoutMs);
    assert.equal(decodedPath(page), route, 'the screen\'s route is as it was');
    assert.equal(await page.$eval(NOTE, (node) => node.textContent), note, 'and so is its note');
    assert.equal(await first.evaluate((node) => node.isConnected), true, 'and the frame element is the one drawn');
    assert.equal(await first.evaluate((node) => node.getAttribute('src')), interopEditorSource('dtl-editor', NAMESPACE, document), 'with the address it was drawn with');

    await page.click('[data-ocu-editor="refresh"]');
    await until(() => first.evaluate((node) => node.isConnected), (connected) => connected === false, 'the old frame element is detached', config.navigationTimeoutMs);
    await answered(page);
    const second = await page.waitForSelector(FRAME, { timeout: config.navigationTimeoutMs });
    assert.equal(await second.evaluate((node) => node.getAttribute('src')), interopEditorSource('dtl-editor', NAMESPACE, document), 'a new element at the builder\'s address');
    const reopened = await editorShows(page, document);
    assert.ok(reopened.url().includes('/ui/interop/dtl-editor/'), 'and it shows the DTL editor again');

    // The editor holds a change it has not saved, so a navigation of its frame would raise its unsaved-changes alert.
    await reopened.waitForSelector('#transform-settings-iconbutton', { timeout: config.navigationTimeoutMs });
    await reopened.click('#transform-settings-iconbutton');
    await reopened.waitForSelector('#transform-settings-description-textarea', { visible: true, timeout: config.navigationTimeoutMs });
    await reopened.type('#transform-settings-description-textarea', 'not saved');
    await reopened.waitForFunction(() => document.querySelector('#top-banner-button-2-secondary')?.disabled === false, { timeout: config.navigationTimeoutMs });
    const alerts = [];
    page.on('dialog', (dialog) => {
      alerts.push(dialog.type());
      void dialog.dismiss();
    });
    await page.evaluate((target) => {
      history.pushState({}, '', target);
      window.dispatchEvent(new PopStateEvent('popstate', { state: {} }));
    }, screenUrl(TRANSFORM.listRoute, VENDOR_DTL));
    await until(() => second.evaluate((node) => node.isConnected), (connected) => connected === false, 'the previous frame element is detached by the route change', config.navigationTimeoutMs);
    await answered(page);
    const third = await page.waitForSelector(FRAME, { timeout: config.navigationTimeoutMs });
    assert.equal(await third.evaluate((node) => node.getAttribute('src')), interopEditorSource('dtl-editor', NAMESPACE, VENDOR_DTL.slice(0, -'.cls'.length)), 'a new element with the new document\'s source');
    await editorShows(page, VENDOR_DTL.slice(0, -'.cls'.length));
    assert.deepEqual(alerts, [], 'the editor holding a change is removed with no unsaved-changes alert');
  } finally {
    await context.close();
  }
});

/** An interoperability namespace other than `NAMESPACE` that the header's switch offers, read from the instance and the switch. */
async function otherNamespace(page) {
  const reported = readNamespaceFeatures(config.container);
  await page.click('.ocu-namespace-switch-trigger');
  await page.waitForSelector('.ocu-namespace-switch-option', { timeout: config.navigationTimeoutMs });
  const offered = await page.$$eval('.ocu-namespace-switch-option', (nodes) => nodes.map((node) => node.textContent.trim()));
  await page.keyboard.press('Escape');
  await page.waitForFunction(() => document.querySelector('.ocu-namespace-switch-list') === null, { timeout: config.navigationTimeoutMs });
  const other = offered.find((name) => name !== NAMESPACE && reported[name]?.interoperability === true);
  assert.ok(other !== undefined, `the switch offers an interoperability namespace besides ${NAMESPACE}: ${JSON.stringify(offered)}`);
  return other;
}

/** Choose `namespace` in the header's switch and wait for the route to carry it. */
async function switchTo(page, namespace) {
  await page.click('.ocu-namespace-switch-trigger');
  await page.waitForSelector('.ocu-namespace-switch-option', { timeout: config.navigationTimeoutMs });
  const chose = await page.evaluate((wanted) => {
    const option = [...document.querySelectorAll('.ocu-namespace-switch-option')].find((node) => node.textContent.trim() === wanted);
    option?.click();
    return option !== undefined;
  }, namespace);
  assert.equal(chose, true, `the namespace switch offers ${namespace}`);
  await page.waitForFunction((wanted) => new URL(window.location.href).searchParams.get('ns') === wanted, { timeout: config.navigationTimeoutMs }, namespace);
}

// Mutation (Rule 19): the page ignores a move of the scope (bundle rebuilt and redeployed) -> the move leaves neither the sentence nor a new
// frame, and the gone clause waits out its timeout and goes red.
test('Namespace move: the header\'s switch takes the frame away, a namespace without the class draws its sentence and requests nothing, and moving back draws a new frame', async () => {
  const document = TRANSFORM.name.slice(0, -'.cls'.length);
  const { context, page, traffic } = await shellAt(screenUrl(TRANSFORM.listRoute, TRANSFORM.name));
  try {
    await answered(page);
    const first = await page.waitForSelector(FRAME, { timeout: config.navigationTimeoutMs });
    await editorShows(page, document);
    const other = await otherNamespace(page);

    await switchTo(page, other);
    await until(() => first.evaluate((node) => node.isConnected), (connected) => connected === false, 'the editor of the old namespace is gone', config.navigationTimeoutMs);
    // Counted from the old editor's removal, so nothing it requested before it went is read as the new namespace's.
    const mark = traffic.length;
    await page.waitForSelector('[data-ocu-editor="gone"]', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-ocu-editor="gone"]', (node) => node.textContent.trim()), TRANSFORM.empty, `${other} does not hold the class, so the screen says so`);
    assert.deepEqual(await page.$$('iframe'), [], 'and no frame is drawn');
    assert.equal(await page.$(NOTE), null, 'nor the note about the editor');
    assert.deepEqual(traffic.slice(mark), [], 'and nothing is requested under /ui/interop/ or /api/interop-editors/');
    assert.equal(decodedPath(page), `/ocupilot/${TRANSFORM.listRoute}/document/${TRANSFORM.name}`, 'the screen\'s route still names the class');

    await switchTo(page, NAMESPACE);
    const second = await page.waitForSelector(FRAME, { timeout: config.navigationTimeoutMs });
    assert.equal(await second.evaluate((node) => node.getAttribute('src')), interopEditorSource('dtl-editor', NAMESPACE, document), 'a new element at the builder\'s address for the namespace moved back to');
    assert.equal(await first.evaluate((node) => node.isConnected), false, 'which is not the element drawn before');
    await editorShows(page, document);
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): `Session.signOut()` posts `/logout` with `credentials: 'omit'` (bundle rebuilt and redeployed) -> the browser-level
// login survives and the empty-body editors login answers 200, so this goes red.
test('AC5: Sign out in the account menu ends the editor\'s sign-in on the real screen: no frame, no editor key, and its login, access token and refresh token are refused', async () => {
  const { context, page, traffic } = await shellAt(screenUrl(TRANSFORM.listRoute, TRANSFORM.name));
  try {
    await answered(page);
    await editorShows(page, TRANSFORM.name.slice(0, -'.cls'.length));
    const held = await waitForEditorTokens(page, 'dtl-editor', config.navigationTimeoutMs);
    await until(() => traffic.filter((entry) => entry.path === '/api/interop-editors/login'), (entries) => entries.some((entry) => entry.status === 200), 'the editor signed in', config.navigationTimeoutMs);
    assert.equal((await page.$$(FRAME)).length, 1, 'one editor frame is drawn before the sign-out');

    await editorSessionControls(page, held);
    await signOutThroughMenu(page, config.navigationTimeoutMs);
    await assertSignOutEndsEditors(page, held);
  } finally {
    await context.close();
  }
});

/**
 * Story 20.10 in a real browser, against the throwaway: on a namespace under source control, the vendor's rule and DTL editors, drawn in
 * place by the Business rules and Data transformations screens, exchange the hooks, the menu, the user actions and the status with the
 * instance themselves, as the signed-in person, and nothing reaches OcuPilot's shell (AD-61 rule 8, AD-63).
 *
 * What it pins, on one data transformation and one business rule in `USER` (package `OcuProbe2010Ui`, made by
 * `OcuPilot.Test.InteropEditorProbe`), with `OcuPilot.Test.SourceControlProbe`'s source-control class enabled in `USER`:
 *
 * - AC1: the DTL editor's Source Control menu lists "Undo Check Out", "Check In" and "Source Control Messages" (disabled); the probe's
 *   "Check In" asks its question in the editor's own dialog; the log holds `UserAction` then `AfterUserAction` with the answer Yes,
 *   then, for the Description's save, `GetStatus`, `OnBeforeSave` and `OnAfterSave`, each for the document as the signed-in person; the
 *   editor says the document is saved; every `sourcecontrol` request is the frame's own, the shell's main frame sends nothing under
 *   `/api/interop-editors/`, and no message reaches the shell or the frame.
 * - AC2: a DTL the probe no longer releases is refused by the editor's own notice, with the definition's `TimeChanged` unchanged and no
 *   `OnBeforeSave` logged; a rule the probe has not released opens read-only, with the editor's sentence and its "Check Out" and "Get
 *   Latest" menu.
 * - AC3: the rule editor's Compile saves and compiles, running `OnBeforeSave`, `OnAfterSave`, `OnBeforeCompile` and `OnAfterCompile` in
 *   that order, and enables "Source Control Messages".
 *
 * **It enables a source-control class in `USER`, creates classes there and records and restores two of the editors' own settings nodes**
 * (`^EnsPortal.Settings(<user>, "LastDTL")` and `"LastBP"`), so it runs on a throwaway only and refuses a container that is not one.
 * `after` takes the source-control class, its log and the probe package away and asserts that none is left. Each test signs in in its own
 * context and waits for the screen's answered signal before it counts, clicks or types.
 *
 * Run: `npm run build`, `docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`, then
 * `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> node --test --test-concurrency=1 browser/interop-editor-source-control.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import {
  answered as screenAnswered,
  armMessageCounters,
  editorShows as screenShows,
  snackbarWhere as editorSnackbarWhere,
  until,
  watchEditorTraffic,
} from './interop-editor-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { escapeOs, markerValue, runIris } from './turnprobe-spec.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { encodeEntityId } = await import(join(uiRoot, 'src', 'app', 'core', 'entity-id.ts'));

const config = browserConfig();

const NAMESPACE = 'USER';
const PACKAGE = 'OcuProbe2010Ui';
const SC = 'OcuPilot.Test.SourceControlProbe';
const PROBES = 'OcuPilot.Test.InteropEditorProbe';
const RULE = { class: `${PACKAGE}.Rule`, listRoute: 'interoperability/rules' };
const TRANSFORM = { class: `${PACKAGE}.Transform`, listRoute: 'interoperability/transforms' };
const REDUCED_MOTION = [{ name: 'prefers-reduced-motion', value: 'reduce' }];
const MENU_BUTTON = 'interop-source-control-menu button';
const MENU_ITEM = '.mat-mdc-menu-panel .mat-mdc-menu-item';
const QUESTION = 'OcuPilot probe asks: proceed?';
const READ_ONLY = 'This is marked Read Only by Server Side Source Control.';
/** The editors' own settings nodes, which the vendor's editors write when they open a document. */
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

/** Run one expression in `NAMESPACE` (the install namespace is restored before the answer is written) and answer its marker. */
function probeIn(name, expression) {
  const output = runIris(config.container, [
    `Set $NAMESPACE="${NAMESPACE}" Set ocuValue=${expression} Set $NAMESPACE="HSCUSTOM"`,
    `Write "OCU-${name}-START:"_ocuValue_":OCU-${name}-END",!`,
  ]);
  return { value: markerValue(output, name), output };
}

/** The node `^EnsPortal.Settings(<user>, <name>)` in `USER` as an ObjectScript reference. */
const settingsNode = (name) => `^["${NAMESPACE}"]EnsPortal.Settings("${escapeOs(config.username)}","${name}")`;

/** Whether each settings node exists and what it holds, read on the instance. */
function readSettings() {
  const held = {};
  for (const name of SETTINGS) {
    const read = probe(`SCSET${name}`, `$Data(${settingsNode(name)})_"|"_$Get(${settingsNode(name)})`);
    const [present, ...value] = String(read.value).split('|');
    assert.match(present, /^\d+$/, `the ${name} node reads: ${read.output}`);
    held[name] = { present: Number(present) > 0, value: value.join('|') };
  }
  return held;
}

/** The probe class definition's `TimeChanged` as stored, read in `USER`. */
function definitionModified(name) {
  const read = probeIn('SCDEFTIME', `##class(%Dictionary.ClassDefinition).%OpenId("${escapeOs(name)}").TimeChanged`);
  assert.match(String(read.value), /^\d+,\d+/, `the definition's TimeChanged reads: ${read.output}`);
  return String(read.value);
}

/** Set the probe's switches back to where `Enable` leaves them, and forget its log. */
function resetProbe() {
  const output = runIris(config.container, [
    `Do ##class(${SC}).Clear("${NAMESPACE}")`,
    `Do ##class(${SC}).Action("${NAMESPACE}",0)`,
    ...[RULE, TRANSFORM].flatMap((kind) => [`Do ##class(${SC}).Refuse("${NAMESPACE}","${kind.class}.cls",0)`, `Do ##class(${SC}).Veto("${NAMESPACE}","${kind.class}.cls",0)`]),
    'Write "OCU-SCRESET-START:1:OCU-SCRESET-END",!',
  ]);
  assert.equal(markerValue(output, 'SCRESET'), '1', `the probe is reset: ${output}`);
}

/** Mark `name` not checked out (`on` 1) or checked out (`on` 0) by the probe. */
function refuse(name, on) {
  const output = runIris(config.container, [`Do ##class(${SC}).Refuse("${NAMESPACE}","${escapeOs(name)}",${on})`, 'Write "OCU-SCREFUSE-START:1:OCU-SCREFUSE-END",!']);
  assert.equal(markerValue(output, 'SCREFUSE'), '1', `the probe's refusal of ${name} is set to ${on}: ${output}`);
}

/** Forget the hook calls the probe has logged. */
function clearLog() {
  const output = runIris(config.container, [`Do ##class(${SC}).Clear("${NAMESPACE}")`, 'Write "OCU-SCCLEAR-START:1:OCU-SCCLEAR-END",!']);
  assert.equal(markerValue(output, 'SCCLEAR'), '1', `the probe's log is cleared: ${output}`);
}

/** Set the answer the probe's `UserAction` gives. */
function setAction(action) {
  const output = runIris(config.container, [`Do ##class(${SC}).Action("${NAMESPACE}",${action})`, 'Write "OCU-SCACTION-START:1:OCU-SCACTION-END",!']);
  assert.equal(markerValue(output, 'SCACTION'), '1', `the probe's user action is ${action}: ${output}`);
}

/** Every hook call the probe has logged, oldest first, as `{ hook, name, user, job, extra }`. */
function readEntries() {
  const output = runIris(config.container, [`Write "OCU-SCLOG-START:"_##class(${SC}).Entries("${NAMESPACE}").%ToJSON()_":OCU-SCLOG-END",!`]);
  const text = markerValue(output, 'SCLOG');
  assert.notEqual(text, null, `the probe's log is read: ${output}`);
  return JSON.parse(text);
}

/** The entries of `entries` that name `name`, a class with its `.cls`, whatever the case the caller wrote its extension in. */
const forDocument = (entries, name) => entries.filter((entry) => entry.name.toUpperCase() === name.toUpperCase());

/** The hook names of `entries`, in order, without those in `omit`. */
const hooks = (entries, omit = []) => entries.filter((entry) => !omit.includes(entry.hook)).map((entry) => entry.hook);

/** Whether `names` appear in `entries` in this order, not necessarily next to one another. */
function inOrder(entries, names) {
  let from = 0;
  for (const name of names) {
    const found = entries.findIndex((entry, index) => index >= from && entry.hook === name);
    if (found < 0) return false;
    from = found + 1;
  }
  return true;
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec enables source control in ${NAMESPACE}, compiles probe classes and edits settings nodes, so it runs only in a throwaway; ${config.container} is not one`);
  const removed = probe('SCCLEAN', `$System.Status.IsOK($System.OBJ.DeletePackage("${PACKAGE}","-d"))`);
  assert.equal(removed.value, '1', `an earlier run's probe classes are removed: ${removed.output}`);
  const disabled = probe('SCDISABLE', `$System.Status.GetErrorText(##class(${SC}).Disable("${NAMESPACE}"))`);
  assert.equal(disabled.value, '', `an earlier run's source-control class is taken out of ${NAMESPACE}: ${disabled.output}`);
  heldSettings = readSettings();
  created = true;
  for (const [kind, label] of [['rule', 'rule'], ['transform', 'transformation']]) {
    const made = probe(`SCMAKE${kind}`, `$System.Status.IsOK(##class(${PROBES}).Make("${kind}","${PACKAGE}"))`);
    assert.equal(made.value, '1', `the probe ${label} is written and compiled: ${made.output}`);
  }
  const enabled = probe('SCENABLE', `$System.Status.GetErrorText(##class(${SC}).Enable("${NAMESPACE}"))`);
  assert.equal(enabled.value, '', `the probe's source-control class is enabled in ${NAMESPACE}: ${enabled.output}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    browser = null;
    if (created && /-ci$/.test(config.container)) {
      // The source-control class goes first, so removing the probe documents runs no hook, and the nodes are restored before anything
      // below can fail.
      const disabled = probe('SCOFF', `$System.Status.GetErrorText(##class(${SC}).Disable("${NAMESPACE}"))`);
      if (heldSettings !== null) {
        for (const name of SETTINGS) {
          const held = heldSettings[name];
          runIris(config.container, [held.present ? `Set ${settingsNode(name)}="${escapeOs(held.value)}"` : `Kill ${settingsNode(name)}`]);
        }
      }
      const gone = probe('SCGONE', `$System.Status.IsOK(##class(${PROBES}).Remove("${PACKAGE}"))`);
      const left = probeIn(
        'SCLEFT',
        `"["_##class(%Studio.SourceControl.Interface).SourceControlClassGet("${NAMESPACE}")_"|"_(''##class(%Dictionary.ClassDefinition).%ExistsId("OcuProbe2010.SourceControl"))_"|"_$Data(^["${NAMESPACE}"]OcuProbe2010SourceControl)`
      );
      if (heldSettings !== null) assert.deepEqual(readSettings(), heldSettings, "the editors' settings nodes are as they were");
      assert.equal(disabled.value, '', `the probe's source-control class is taken out of ${NAMESPACE}: ${disabled.output}`);
      assert.equal(gone.value, '1', `the probe classes are removed: ${gone.output}`);
      assert.equal(left.value, '[|0|0', `${NAMESPACE} names no source-control class and holds neither the probe's class nor its log: ${left.output}`);
    }
  }
});

/** The editor screen has answered the list's read. */
const answered = (page) => screenAnswered(page, config.navigationTimeoutMs);

/** Wait until the frame's editor shows the signed-in person and `text`. */
const editorShows = (page, text) => screenShows(page, config.username, text, config.navigationTimeoutMs);

/** Wait until the editor's snackbar holds a sentence containing `text`, and answer the sentence. */
const snackbarWith = (frame, text) =>
  editorSnackbarWhere(frame, (label) => label.includes(text), `the editor's notice contains ${JSON.stringify(text)}`, config.navigationTimeoutMs);

/**
 * Record each request the page's main frame makes under `/api/interop-editors/`, and each `sourcecontrol` request any frame makes
 * with the address of the frame that made it, so the clauses about whose requests they are read what the browser saw.
 */
function watchSourceControlRequests(page) {
  const seen = { mainFrame: [], sourceControl: [] };
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (!url.pathname.startsWith('/api/interop-editors/')) return;
    const frame = request.frame();
    if (frame === page.mainFrame()) seen.mainFrame.push(`${request.method()} ${url.pathname}`);
    if (url.pathname.includes('/sourcecontrol/')) seen.sourceControl.push({ path: url.pathname, frameUrl: frame === null ? '' : frame.url() });
  });
  return seen;
}

/** A fresh signed-in context at `url`, with the observers armed before the first request, so nothing the screen draws goes unseen. */
async function shellAt(url) {
  const observers = {};
  const { context, page } = await signedInAt(browser, config, url, VIEWPORTS.wide, REDUCED_MOTION, async (opened) => {
    observers.traffic = watchEditorTraffic(opened);
    observers.requests = watchSourceControlRequests(opened);
    observers.messages = await armMessageCounters(opened);
  });
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  return { context, page, ...observers };
}

/** The editor screen for `kind`'s probe class, as the list's name cell builds its address. */
const screenUrl = (kind) => `/ocupilot/${kind.listRoute}/document/${encodeEntityId(`${kind.class}.cls`)}?ns=${NAMESPACE}`;

/** Open `kind`'s probe in its editor, and answer the context, the page and the editor's frame once the editor shows the class. */
async function openEditor(kind) {
  const opened = await shellAt(screenUrl(kind));
  try {
    await answered(opened.page);
    const frame = await editorShows(opened.page, kind.class);
    return { ...opened, frame };
  } catch (error) {
    await opened.context.close();
    throw error;
  }
}

/** Open the editor's Source Control menu, wait until it lists `expected`, and answer its items as `{ text, disabled }`. */
async function openMenu(frame, expected) {
  await frame.waitForSelector(MENU_BUTTON, { timeout: config.navigationTimeoutMs });
  await frame.click(MENU_BUTTON);
  const read = () =>
    frame.evaluate((selector) => Array.from(document.querySelectorAll(selector)).map((node) => ({ text: node.innerText.trim(), disabled: node.getAttribute('aria-disabled') === 'true' })), MENU_ITEM);
  return until(read, (items) => JSON.stringify(items.map((item) => item.text)) === JSON.stringify(expected), `the Source Control menu lists ${expected.join(', ')}`, config.navigationTimeoutMs);
}

/** Close the editor's open menu and wait until it is gone. */
async function closeMenu(frame) {
  await frame.page().keyboard.press('Escape');
  await frame.waitForSelector('.mat-mdc-menu-panel', { hidden: true, timeout: config.navigationTimeoutMs });
}

/**
 * Change the DTL's Description in the editor's settings panel and wait until the editor enables Save. The panel's form takes a change
 * only once the panel has been opened by a click made after the form exists, which the first opening does not always follow when the
 * namespace is under source control, so the panel is brought to open, to closed and to open again, whatever state it was found in.
 */
async function editDescription(frame, text) {
  const button = '#transform-settings-iconbutton';
  const field = '#transform-settings-description-textarea';
  const isOpen = () =>
    frame.evaluate((selector) => {
      const node = document.querySelector(selector);
      if (node === null) return false;
      // A closed panel sits to the right of the editor's window, still laid out.
      const box = node.getBoundingClientRect();
      return box.width > 0 && box.left < window.innerWidth;
    }, field);
  const setOpen = async (open) => {
    if ((await isOpen()) === open) return;
    await frame.click(button);
    await until(isOpen, (now) => now === open, `the settings panel is ${open ? 'open' : 'closed'}`, config.navigationTimeoutMs);
  };
  await frame.waitForSelector(button, { timeout: config.navigationTimeoutMs });
  await setOpen(true);
  await setOpen(false);
  await setOpen(true);
  await frame.type(field, text);
  await frame.waitForFunction(() => document.querySelector('#top-banner-button-2-secondary')?.disabled === false, { timeout: config.navigationTimeoutMs });
}

/** Choose the banner button labelled `label` in the editor, which the rule editor gives no id. */
async function chooseBannerButton(frame, label) {
  const chose = await frame.evaluate((wanted) => {
    const button = Array.from(document.querySelectorAll('button')).find((node) => node.innerText.trim() === wanted);
    button?.click();
    return button !== undefined;
  }, label);
  assert.equal(chose, true, `the editor has a ${label} button`);
}

// Mutation (Rule 19): `interop-editor.page.ts` hands the frame `HSCUSTOM` whatever the scope (bundle rebuilt and redeployed) -> the frame is
// never drawn, and the opening wait of every test goes red.
// Mutation (Rule 19): the probe's `OnBeforeSave` records nothing -> the order clause goes red, and so does AC3's.
test('AC1: the DTL editor lists the probe\'s menu, shows its user action\'s dialog and runs its save hooks as the signed-in person, and nothing reaches the shell', async () => {
  resetProbe();
  const documentName = `${TRANSFORM.class}.cls`;
  const { context, frame, requests, messages } = await openEditor(TRANSFORM);
  try {
    const items = await openMenu(frame, ['Undo Check Out', 'Check In', 'Source Control Messages']);
    assert.deepEqual(
      items.map((item) => item.disabled),
      [false, false, true],
      'the menu holds Undo Check Out and Check In, and Source Control Messages is disabled until a message arrives'
    );

    setAction(1);
    await frame.evaluate((selector) => Array.from(document.querySelectorAll(selector)).find((node) => node.innerText.trim() === 'Check In')?.click(), MENU_ITEM);
    await frame.waitForSelector('mat-dialog-container', { timeout: config.navigationTimeoutMs });
    const dialog = await frame.$eval('mat-dialog-container', (node) => node.innerText);
    assert.ok(dialog.includes('Server Side Source Control') && dialog.includes(QUESTION), `the editor's own dialog shows the probe's question: ${JSON.stringify(dialog)}`);
    const answeredYes = await frame.evaluate(() => {
      const yes = Array.from(document.querySelectorAll('mat-dialog-container button')).find((node) => node.innerText.trim() === 'Yes');
      yes?.click();
      return yes !== undefined;
    });
    assert.equal(answeredYes, true, 'the dialog offers Yes');
    await until(readEntries, (entries) => entries.some((entry) => entry.hook === 'AfterUserAction'), 'the probe logs the answer', config.navigationTimeoutMs);
    // The dialog is answered, so the Description's save is not itself asked a question.
    setAction(0);

    await editDescription(frame, 'edited by the browser spec');
    await frame.click('#top-banner-button-2-secondary');
    assert.equal(await snackbarWith(frame, `${TRANSFORM.class} saved.`), `${TRANSFORM.class} saved.`, 'the editor says the class is saved');
    const entries = await until(readEntries, (found) => found.some((entry) => entry.hook === 'OnAfterSave'), 'the probe logs the save', config.navigationTimeoutMs);

    const own = forDocument(entries, documentName);
    assert.ok(inOrder(own, ['UserAction', 'AfterUserAction', 'GetStatus', 'OnBeforeSave', 'OnAfterSave']), `the document's hooks ran in order: ${JSON.stringify(hooks(own))}`);
    const action = own.find((entry) => entry.hook === 'UserAction');
    const after = own.find((entry) => entry.hook === 'AfterUserAction');
    assert.equal(action.extra, '0|%SourceMenu,%CheckIn', 'the user action is the menu\'s Check In');
    assert.equal(after.extra, '0|%SourceMenu,%CheckIn|1', 'and its answer is Yes');
    assert.deepEqual(
      [...new Set(entries.map((entry) => entry.user))],
      [config.username],
      'every hook ran as the signed-in person'
    );

    const foreign = requests.sourceControl.filter((request) => !request.frameUrl.includes('/ui/interop/dtl-editor/'));
    assert.ok(requests.sourceControl.length > 0, 'the editor made source-control requests');
    assert.deepEqual(foreign, [], 'and every one of them is the frame\'s own');
    assert.deepEqual(requests.mainFrame, [], 'the shell\'s main frame sends nothing under /api/interop-editors/');
    assert.deepEqual(await messages.seen(), [], 'no message reached the shell or the frame');
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): the probe's `GetStatus` answers editable whatever the document's marking -> the DTL leg's save reaches `OnBeforeSave`
// and the rule leg shows no sentence, so both go red.
test('AC2: a DTL the probe no longer releases is refused by the editor\'s own notice and changes nothing, and a rule it has not released opens read-only', async (t) => {
  await t.test('the DTL editor refuses the save', async () => {
    resetProbe();
    const documentName = `${TRANSFORM.class}.cls`;
    const { context, frame } = await openEditor(TRANSFORM);
    try {
      const before = definitionModified(TRANSFORM.class);
      await editDescription(frame, 'edited by the browser spec');
      refuse(documentName, 1);
      clearLog();
      await frame.click('#top-banner-button-2-secondary');
      assert.equal(await snackbarWith(frame, `Unable to save ${TRANSFORM.class}`), `Unable to save ${TRANSFORM.class}`, 'the editor says it could not save the class');
      const names = hooks(forDocument(readEntries(), documentName));
      assert.equal(names.includes('GetStatus'), true, `the editor asked the source-control class for the document's status: ${JSON.stringify(names)}`);
      assert.equal(names.includes('OnBeforeSave'), false, `no OnBeforeSave ran: ${JSON.stringify(names)}`);
      assert.equal(definitionModified(TRANSFORM.class), before, "and the definition's TimeChanged is unchanged");
    } finally {
      await context.close();
    }
  });

  await t.test('the rule editor opens the rule read-only', async () => {
    resetProbe();
    refuse(`${RULE.class}.cls`, 1);
    const { context, frame } = await openEditor(RULE);
    try {
      await until(() => frame.evaluate(() => document.body.innerText), (body) => body.includes(READ_ONLY), `the editor says ${READ_ONLY}`, config.navigationTimeoutMs);
      const items = await openMenu(frame, ['Check Out', 'Get Latest', 'Source Control Messages']);
      assert.deepEqual(
        items.map((item) => item.disabled),
        [false, false, true],
        'the menu holds Check Out and Get Latest, and Source Control Messages is disabled'
      );
    } finally {
      await context.close();
    }
  });
});

// Mutation (Rule 19): the probe's `OnBeforeCompile` records nothing -> this goes red alone, and so does `SourceControlSave`'s compile leg.
test('AC3: the rule editor\'s Compile saves and compiles through the probe\'s hooks in order, and enables Source Control Messages', async () => {
  resetProbe();
  const documentName = `${RULE.class}.cls`;
  const { context, page, frame, messages } = await openEditor(RULE);
  try {
    const before = await openMenu(frame, ['Undo Check Out', 'Check In', 'Source Control Messages']);
    assert.equal(before[2].disabled, true, 'Source Control Messages is disabled before the compile');
    await closeMenu(frame);
    clearLog();

    await chooseBannerButton(frame, 'Compile');
    assert.equal(await snackbarWith(frame, 'Rule saved and compiled.'), 'Rule saved and compiled.', 'the editor says the rule is saved and compiled');
    const entries = await until(readEntries, (found) => found.some((entry) => entry.hook === 'OnAfterCompile'), 'the probe logs the compile', config.navigationTimeoutMs);
    const own = forDocument(entries, documentName);
    const SAVE_AND_COMPILE = ['OnBeforeSave', 'OnAfterSave', 'OnBeforeCompile', 'OnAfterCompile'];
    assert.deepEqual(hooks(own).filter((hook) => SAVE_AND_COMPILE.includes(hook)), SAVE_AND_COMPILE, `the save and compile hooks ran once each, in order: ${JSON.stringify(hooks(own))}`);
    assert.deepEqual([...new Set(own.map((entry) => entry.user))], [config.username], 'as the signed-in person');

    const after = await openMenu(frame, ['Undo Check Out', 'Check In', 'Source Control Messages']);
    assert.equal(after[2].disabled, false, 'Source Control Messages is enabled after the compile');
    assert.deepEqual(await messages.seen(), [], 'no message reached the shell or the frame');
    assert.ok((await page.$$('app-interop-editor-frame iframe')).length === 1, 'the editor is still the one frame the screen drew');
  } finally {
    await context.close();
  }
});

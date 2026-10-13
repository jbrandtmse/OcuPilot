/**
 * The agent's save behind the Data transformations editor in a real browser against the throwaway (Story 20.16): on the
 * editor's own screen a scripted turn reads the saved class with `interop_transformeditor_source` and proposes a change with
 * `interop_transformeditor_save`; the card draws the changed lines as a line diff and says that Confirm saves, compiles and
 * opens the document again; Confirm saves the text, and the screen then draws a new frame at the same address whose own
 * document read answers the new value and whose editor shows it. A breaking edit says it did not compile and still opens a new
 * frame. The bar says, before any request, that the agent reads only what is saved. The live card passes the DW-1337 invariants.
 *
 * The probe is a data transformation `OcuProbe2016Ui.Transform` in `USER`, written, compiled and removed by this file, which
 * also records and restores `^EnsPortal.Settings(<user>, "LastDTL")`, the node the DTL editor writes when it opens a document.
 * `before` puts the governance policy back to its default, so the save's key reads enabled; `after` removes its proposals and the
 * probe and puts the definition back. It refuses to run in the live container or a slot instance before any docker call. Each test
 * signs in in its own context and waits for the screen's answered signal before it counts, clicks or types.
 *
 * Run: `npm run build`, `docker cp` the bundle into the throwaway, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test browser/agent-editor-save.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { EDITOR_API, until, watchEditorTraffic } from './interop-editor-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { signedInAt } from './panel-spec.mjs';
import { resetGovernancePolicy, resetRememberedState } from './preferences-reset.mjs';
import {
  INVARIANTS,
  VIEWPORTS,
  assertThrowaway,
  compare,
  componentMinimums,
  detectScreen,
  readBaseline,
  toggleThemeThroughMenu,
} from './structural-walk.mjs';
import {
  armProbeDefinition,
  disarmProbeDefinition,
  escapeOs,
  forgetTag as sharedForgetTag,
  markerValue,
  nextTag as sharedNextTag,
  requireFreeSlot,
  runIris as sharedRunIris,
  scriptReply as sharedScriptReply,
  setTag as sharedSetTag,
} from './turnprobe-spec.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { encodeEntityId } = await import(join(uiRoot, 'src', 'app', 'core', 'entity-id.ts'));

const config = browserConfig();
const probe = { container: config.container, marker: 'AGENTEDITORSAVE' };
const STRINGS = loadStrings();

const NAMESPACE = 'USER';
const PACKAGE = 'OcuProbe2016Ui';
const CLASS = `${PACKAGE}.Transform`;
const DOCUMENT = `${CLASS}.cls`;
const KEY = 'interop.transformeditor.save';
const READ_KEY = 'interop.transformeditor.source';
const SAVE_WIRE = 'interop_transformeditor_save';
const READ_WIRE = 'interop_transformeditor_source';
/** The baseline key of the screen the card is drawn over. */
const ROUTE = 'interoperability/transforms/document/:id';
const SCREEN_URL = `/ocupilot/interoperability/transforms/document/${encodeEntityId(DOCUMENT)}?ns=${NAMESPACE}`;
const FRAME = 'app-interop-editor-frame iframe';
const DOCUMENT_READ = `${EDITOR_API}v7/${NAMESPACE}/dtl/${CLASS}`;
const REDUCED_MOTION = [{ name: 'prefers-reduced-motion', value: 'reduce' }];

/** The probe's assignment line (`OcuPilot.Test.InteropEditorProbe.DTLASSIGN`), its edit and the code that does not compile. */
const ASSIGN = "<assign value='source.StringValue' property='target.StringValue' action='set'/>";
const EDITED = "<assign value='source.StringValue_\"-agent-edit\"' property='target.StringValue' action='set'/>";
const EDITED_VALUE = '-agent-edit';
const BROKEN_CODE = '<code><![CDATA[ Set x = (1 ]]></code>';
const SETTINGS_NODE = `^EnsPortal.Settings("${escapeOs(config.username)}","LastDTL")`;

let browser = null;
let preparedId = '';
let priorDefault = '';
/** What the editor's settings node held before this run, as `{ present, value }`. */
let heldSetting = null;

const runIris = (lines) => sharedRunIris(config.container, lines);
const nextTag = () => sharedNextTag(probe);
const setTag = (tag) => sharedSetTag(probe, preparedId, tag);
const forgetTag = (tag) => sharedForgetTag(probe, tag);
const scriptReply = (tag, bodyExpr) => sharedScriptReply(probe, tag, 0, bodyExpr, 200);

/** Run one single-line ObjectScript expression in the throwaway and answer its marker. */
function ask(name, expression) {
  const output = runIris([`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

function readSetting() {
  const read = ask('AGENTEDITORSET', `$Data(${SETTINGS_NODE})_"|"_$Get(${SETTINGS_NODE})`);
  const [present, ...value] = String(read.value).split('|');
  assert.match(present, /^\d+$/, `the LastDTL node reads: ${read.output}`);
  return { present: Number(present) > 0, value: value.join('|') };
}

function restoreSetting() {
  if (heldSetting === null) return;
  runIris([heldSetting.present ? `Set ${SETTINGS_NODE}="${escapeOs(heldSetting.value)}"` : `Kill ${SETTINGS_NODE}`]);
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec saves and compiles a class, so it never runs inside the live container');
  assert.match(config.container, /-ci$/, `this spec compiles a probe class and edits a settings node, so it runs only in a throwaway; ${config.container} is not one`);
  await assertThrowaway(config);
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);
  heldSetting = readSetting();
  browser = await puppeteer.launch(launchOptions(config));
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
  allowWrites();
  await resetGovernancePolicy();
  dropProposals();
  makeProbe();
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  await requireFreeSlot(config).catch(() => {});
  dropProposals();
  removeProbe();
  restoreSetting();
  await resetRememberedState();
  disarmProbeDefinition(probe, priorDefault);
});

function allowWrites() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly("${escapeOs(preparedId)}",0)`,
    `Write "OCU-AGENTEDITORRW-START:"_$System.Status.IsOK(sc)_":OCU-AGENTEDITORRW-END",!`,
  ]);
  assert.equal(markerValue(output, 'AGENTEDITORRW'), '1', `the probe definition allows writes: ${output}`);
}

function dropProposals() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForUser("${escapeOs(config.username)}")`,
    `Do ##class(%SQL.Statement).%ExecDirect(,"DELETE FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(Name) IN ('${KEY}','${READ_KEY}')")`,
    `Write "OCU-AGENTEDITORDROP-START:"_$System.Status.IsOK(sc)_":OCU-AGENTEDITORDROP-END",!`,
  ]);
  assert.equal(markerValue(output, 'AGENTEDITORDROP'), '1', `the probe proposals are removed: ${output}`);
}

/** Write, compile and leave in `USER` the probe transformation as the server tests' fixture builds it. */
function makeProbe() {
  const output = runIris([
    `Do ##class(OcuPilot.Test.InteropEditorProbe).Remove("${PACKAGE}")`,
    `Set sc=##class(OcuPilot.Test.InteropEditorProbe).Make("transform","${PACKAGE}")`,
    `Write "OCU-AGENTEDITORMAKE-START:"_$System.Status.IsOK(sc)_":OCU-AGENTEDITORMAKE-END",!`,
  ]);
  assert.equal(markerValue(output, 'AGENTEDITORMAKE'), '1', `the probe transformation is made: ${output}`);
}

function removeProbe() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.InteropEditorProbe).Remove("${PACKAGE}")`,
    `Write "OCU-AGENTEDITORGONE-START:"_$System.Status.IsOK(sc)_":OCU-AGENTEDITORGONE-END",!`,
  ]);
  assert.equal(markerValue(output, 'AGENTEDITORGONE'), '1', `the probe package, its generated classes and its cache node are removed: ${output}`);
}

/** Whether the probe's stored text holds `fragment`. */
function storedHolds(fragment) {
  const output = runIris([
    `Set tOrigNS=$NAMESPACE Set $NAMESPACE="${NAMESPACE}" Set sc=##class(%Compiler.UDL.TextServices).GetTextAsString("${NAMESPACE}","${CLASS}",.t) Set $NAMESPACE=tOrigNS`,
    `Write "OCU-AGENTEDITORHOLD-START:"_(t[${JSON.stringify(fragment)})_":OCU-AGENTEDITORHOLD-END",!`,
  ]);
  return markerValue(output, 'AGENTEDITORHOLD') === '1';
}

/** The names of the tools the first provider request of `tag` carried without `defer_loading`: the turn's starting set. */
function startingTools(tag) {
  const output = runIris([
    `Set t=##class(OcuPilot.Test.TurnProvider).Recorded("${escapeOs(tag)}",1,"tools") Set a=##class(%DynamicAbstractObject).%FromJSON(t) Set it=a.%GetIterator() Set s="" While it.%GetNext(.i,.o) { If $IsObject(o) { If 'o."defer_loading" Set s=s_o.name_"," } }`,
    `Write "OCU-AGENTEDITORSTART-START:"_s_":OCU-AGENTEDITORSTART-END",!`,
  ]);
  const names = (markerValue(output, 'AGENTEDITORSTART') ?? '').split(',').filter((name) => name !== '');
  assert.ok(names.length > 0, `the first provider request carried a starting set: ${output}`);
  return names;
}

/** A scripted reply that reads the probe class through the editor's read tool. */
function readReply() {
  return `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_read", "name": "${READ_WIRE}", "input": ${JSON.stringify({ name: DOCUMENT })}}])`;
}

/** A scripted reply that proposes one exact replacement of the probe class's text through the editor's save tool. */
function saveReply(oldText, newText) {
  const input = {
    Names: DOCUMENT,
    Edits: [{ Old: oldText, New: newText }],
    rationale: 'The transformation changes.',
    expectedImpact: 'the target value changes',
    reverse: 'run the same save the other way round',
  };
  return `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_save", "name": "${SAVE_WIRE}", "input": ${JSON.stringify(input)}}])`;
}

const endReply = `##class(OcuPilot.Test.TurnProvider).TextReply("saved")`;

/**
 * A fresh signed-in context at the probe's editor screen, with the editors' traffic observed from the first request and every
 * answer to the editor's own document read kept with its body, so nothing the editor asks goes unseen.
 */
async function shellAtEditor() {
  const observers = { reads: [] };
  const { context, page } = await signedInAt(browser, config, SCREEN_URL, VIEWPORTS.wide, REDUCED_MOTION, async (opened) => {
    observers.traffic = watchEditorTraffic(opened);
    opened.on('response', (response) => {
      const url = new URL(response.url());
      if (response.request().method() !== 'GET' || url.pathname !== DOCUMENT_READ) return;
      const entry = { status: response.status(), body: null };
      observers.reads.push(entry);
      response.text().then(
        (text) => {
          entry.body = text;
        },
        () => {
          entry.body = '';
        }
      );
    });
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

/** Wait until the frame's editor shows the signed-in person and `text`, answering the puppeteer frame. */
async function editorShows(page, text) {
  const handle = await page.waitForSelector(FRAME, { timeout: config.navigationTimeoutMs });
  const frame = await handle.contentFrame();
  await until(() => frame.evaluate(() => document.body.innerText), (body) => body.includes(config.username) && body.includes(text), `the editor shows ${text}`, config.navigationTimeoutMs);
  return frame;
}

/** Wait for the composer, send one prompt, and wait for the card's Confirm button. */
async function proposeSave(page, prompt) {
  await page.waitForFunction(() => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'), { timeout: config.navigationTimeoutMs });
  await page.type('#ocu-panel-composer', prompt);
  await page.click('.ocu-panel-send');
  await page.waitForSelector('app-proposal-card .ocu-proposal-card-confirm', { timeout: config.navigationTimeoutMs });
}

/** The card's slot text, without its glyph, or `null` when the slot is absent. */
async function slotText(page, name) {
  return page.$eval(`app-proposal-card [data-slot="${name}"]`, (node) => (node.querySelector('.ocu-banner-message') ?? node).textContent.trim()).catch(() => null);
}

/** Every DW-1337 invariant over the card in light at both widths and dark at the wide width, outside the baseline. */
async function cardViolations(page) {
  const minimums = componentMinimums();
  const baseline = (readBaseline()?.entries ?? []).filter((entry) => entry.route === ROUTE);
  const requests = { inflight: new Set(), last: 0 };
  const found = [];
  for (const { viewport, theme } of [
    { viewport: VIEWPORTS.wide, theme: 'light' },
    { viewport: VIEWPORTS.narrow, theme: 'light' },
    { viewport: VIEWPORTS.wide, theme: 'dark' },
  ]) {
    await page.setViewport(viewport);
    // The docked panel re-lays out on the resize; measure once its right edge has come inside the viewport.
    await page.waitForFunction((width) => {
      const panel = document.querySelector('app-panel');
      return panel === null || panel.getBoundingClientRect().right <= width + 1;
    }, { timeout: 3000 }, viewport.width).catch(() => {});
    if (theme === 'dark') await toggleThemeThroughMenu(page, requests, config.navigationTimeoutMs);
    try {
      const { entries } = await detectScreen(page, { route: ROUTE, checks: INVARIANTS, viewport: viewport.width, theme, minimums });
      found.push(...entries);
    } finally {
      if (theme === 'dark') await toggleThemeThroughMenu(page, requests, config.navigationTimeoutMs);
    }
  }
  await page.setViewport(VIEWPORTS.wide);
  return compare(found, baseline).fresh.map((entry) => `${entry.key}: ${entry.measured}`);
}

// Mutation (Rule 19): the page omits the agent line (bundle rebuilt and redeployed) -> the bar assertion goes red.
test('AC1: the bar says the agent reads only what is saved, beside the note and before any request of the agent', async () => {
  makeProbe();
  const { context, page } = await shellAtEditor();
  try {
    await answered(page);
    const bar = await page.$eval('[data-ocu-editor="agent"]', (node) => ({
      text: node.textContent.trim(),
      after: node.previousElementSibling?.getAttribute('data-ocu-editor') ?? '',
      inBar: node.parentElement?.classList.contains('ocu-interop-editor-bar') === true,
    }));
    assert.equal(bar.text, STRINGS.interopEditorAgentNote, 'the bar says the agent reads only what is saved');
    assert.equal(bar.after, 'note', "right after 20.7's note");
    assert.ok(bar.inBar, 'inside the bar');
    assert.equal(await page.$eval('[data-ocu-editor="note"]', (node) => node.textContent.trim()), STRINGS.interopEditorNote, "20.7's note is still there");
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): `shows` answers false for every event (bundle rebuilt and redeployed) -> the old frame stays attached and the
// reload assertions go red. `consequenceSentence` drops the new branch -> the consequence assertion goes red.
test('AC1, AC2, AC3: a scripted turn reads and proposes, the card shows the diff and the reload consequence, and Confirm opens the document again in a new frame that shows the saved value', async () => {
  makeProbe();
  await requireFreeSlot(config);
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, readReply());
  scriptReply(tag, saveReply(ASSIGN, EDITED));
  scriptReply(tag, endReply);
  const { context, page, reads } = await shellAtEditor();
  try {
    await answered(page);
    const oldFrame = await page.waitForSelector(FRAME, { timeout: config.navigationTimeoutMs });
    const address = await oldFrame.evaluate((node) => node.getAttribute('src'));
    await editorShows(page, CLASS);
    assert.equal(reads.length >= 1 && reads[0].status === 200, true, 'the editor read its document');

    await proposeSave(page, 'append -agent-edit to the value this transformation sets');
    assert.deepEqual(
      startingTools(tag)
        .filter((name) => name.includes('editor'))
        .sort(),
      [READ_WIRE, SAVE_WIRE].sort(),
      "the turn's starting tools hold this editor's read and its save, and no other editor's"
    );
    const card = await page.$eval('app-proposal-card', (node) => ({
      removed: node.querySelector('app-text-diff [data-ocu-diff="removed"]')?.textContent.replace(/\s+/g, ' ').trim() ?? '',
      added: node.querySelector('app-text-diff [data-ocu-diff="added"]')?.textContent.replace(/\s+/g, ' ').trim() ?? '',
    }));
    assert.ok(card.removed.includes("source.StringValue'"), `the removed line is drawn: ${card.removed}`);
    assert.ok(card.added.includes(EDITED_VALUE), `the added line is drawn: ${card.added}`);
    assert.equal(await slotText(page, 'consequence'), STRINGS.interopEditorSaveOnConfirm, 'the card says confirming opens the document again and drops unsaved changes');
    assert.equal(await slotText(page, 'saved-not-compiled'), null, 'nothing is said about a compile before Confirm');
    assert.equal(storedHolds(EDITED_VALUE), false, 'nothing was saved before Confirm');
    const readsBefore = reads.length;

    await page.click('.ocu-proposal-card-confirm');
    await page.waitForSelector('app-proposal-card .ocu-proposal-card-status', { timeout: config.navigationTimeoutMs });
    assert.equal(await slotText(page, 'saved-not-compiled'), null, 'a clean compile says nothing extra');
    assert.equal(storedHolds(EDITED_VALUE), true, 'the confirmed save holds the new text');

    await page.waitForFunction((node) => !node.isConnected, { timeout: config.navigationTimeoutMs }, oldFrame);
    const newFrame = await page.waitForSelector(FRAME, { timeout: config.navigationTimeoutMs });
    assert.equal(await newFrame.evaluate((node) => node.getAttribute('src')), address, 'the new frame is drawn at the same address');
    assert.equal(await page.$$eval(FRAME, (nodes) => nodes.length), 1, 'and it is the only frame');
    const read = await until(
      () => reads.slice(readsBefore).find((entry) => entry.body !== null && entry.body.includes(EDITED_VALUE)) ?? null,
      (entry) => entry !== null,
      "the new frame's own document read answers the new value",
      config.navigationTimeoutMs
    );
    assert.equal(read.status, 200, "the new frame's document read is answered 200");
    const frame = await newFrame.contentFrame();
    await until(() => frame.evaluate(() => document.body.innerText), (body) => body.includes(EDITED_VALUE), "the editor's rendered text holds the saved value", config.navigationTimeoutMs);
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
  }
});

// Mutation (Rule 19): `savedNotCompiledVisible` keeps its single code (bundle rebuilt and redeployed) -> the banner assertion goes red.
test('AC6: a breaking edit, confirmed, says it did not compile, leaves the new text on the instance and opens the document again in a new frame', async () => {
  makeProbe();
  await requireFreeSlot(config);
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, saveReply(ASSIGN, `${ASSIGN}\n${BROKEN_CODE}`));
  scriptReply(tag, endReply);
  const { context, page } = await shellAtEditor();
  try {
    await answered(page);
    const oldFrame = await page.waitForSelector(FRAME, { timeout: config.navigationTimeoutMs });
    const address = await oldFrame.evaluate((node) => node.getAttribute('src'));
    await proposeSave(page, 'add a code line that does not compile');
    await page.click('.ocu-proposal-card-confirm');
    await page.waitForSelector('app-proposal-card [data-slot="saved-not-compiled"]', { timeout: config.navigationTimeoutMs });
    assert.equal(await slotText(page, 'saved-not-compiled'), STRINGS.explorerSaveNotCompiled, 'the card says the save did not compile');
    assert.equal(storedHolds(BROKEN_CODE), true, 'the instance holds the new text, uncompiled');
    await page.waitForFunction((node) => !node.isConnected, { timeout: config.navigationTimeoutMs }, oldFrame);
    const newFrame = await page.waitForSelector(FRAME, { timeout: config.navigationTimeoutMs });
    assert.equal(await newFrame.evaluate((node) => node.getAttribute('src')), address, 'a new frame is drawn at the same address');
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
  }
});

test('DW-1337: the live card on the editor screen passes the invariants in light at both widths and in dark, outside the baseline', async () => {
  makeProbe();
  await requireFreeSlot(config);
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, saveReply(ASSIGN, EDITED));
  scriptReply(tag, endReply);
  const { context, page } = await shellAtEditor();
  try {
    await answered(page);
    await editorShows(page, CLASS);
    await proposeSave(page, 'append -agent-edit to the value this transformation sets');
    assert.deepEqual(await cardViolations(page), [], 'the card adds no structural violation in light or dark, at either width');
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
  }
});

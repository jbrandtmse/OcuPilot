/**
 * The agent's class and routine creates in a real browser against the throwaway (Story 20.20): a scripted turn
 * proposes a new class through `explorer.classes.create`, and the card draws the whole new text as added lines from
 * line 1 and says Confirm compiles; Confirm creates and compiles it, and no saved-but-not-compiled line shows. A
 * routine create of twelve lines starts collapsed under its summary line, and Confirm works unopened; the live card
 * passes the DW-1337 invariants in light and dark. A broken class, confirmed, says it did not compile.
 *
 * The probes are a class `OcuProbe2022.BrowserCreate` and a routine `OcuProbe2022Browser.mac` in `USER`, created and
 * removed by this file. `before` puts the governance policy back to its default, so both creates' keys read enabled;
 * `after` removes the proposals and both documents and puts the definition back. It refuses to run in the live
 * container before any docker call.
 *
 * Run: `npm run build`, `docker cp` the bundle into the throwaway, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test browser/agent-code-create.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { signedInAt } from './panel-spec.mjs';
import { resetGovernancePolicy, resetRememberedState } from './preferences-reset.mjs';
import {
  INVARIANTS,
  VIEWPORTS,
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
  setTag as sharedSetTag,
} from './turnprobe-spec.mjs';

const config = browserConfig();
const probe = { container: config.container, marker: 'AGENTCODECREATE' };
const STRINGS = loadStrings();

const USER_URL = '/ocupilot/?ns=USER';
/** The screen the card is drawn over, the baseline key the walk compares against. */
const ROUTE = 'system-explorer/classes';
const CLASS_KEY = 'explorer.classes.create';
const ROUTINE_KEY = 'explorer.routines.create';
const CLASS_WIRE_NAME = 'explorer_classes_create';
const ROUTINE_WIRE_NAME = 'explorer_routines_create';
const CLASS = 'OcuProbe2022.BrowserCreate';
const DOCUMENT = `${CLASS}.cls`;
const ROUTINE = 'OcuProbe2022Browser.mac';

/** A seven-line class, its whole text, as the create proposes it. */
const CLASS_TEXT = [
  `Class ${CLASS} Extends %RegisteredObject`,
  '{',
  'ClassMethod Probe() As %Integer',
  '{',
  '    Quit 1',
  '}',
  '}',
].join('\n');

/** A class whose property names a type that does not exist: it saves and does not compile. */
const BROKEN_TEXT = CLASS_TEXT.replace('{\nClassMethod', '{\nProperty Broken As OcuProbe2022.NoSuchType;\nClassMethod');

/** A routine of twelve lines: its header and eleven lines of code. */
const ROUTINE_TEXT = [`ROUTINE ${ROUTINE.replace('.mac', '')}`, ...Array.from({ length: 11 }, (_, index) => `    Set x${index + 1} = ${index + 1}`)].join('\n');

let browser = null;
let preparedId = '';
let priorDefault = '';

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates and compiles classes, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);
  browser = await puppeteer.launch(launchOptions(config));
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
  allowWrites();
  await resetGovernancePolicy();
  dropProposals();
  dropDocuments();
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  await requireFreeSlot(config).catch(() => {});
  dropProposals();
  dropDocuments();
  await resetRememberedState();
  disarmProbeDefinition(probe, priorDefault);
});

const runIris = (lines) => sharedRunIris(config.container, lines);
const nextTag = () => sharedNextTag(probe);
const setTag = (tag) => sharedSetTag(probe, preparedId, tag);
const forgetTag = (tag) => sharedForgetTag(probe, tag);

/** An ObjectScript string literal for `text`, its line feeds spelled as `$Char(10)`. */
function osString(text) {
  return `"${text.replace(/"/g, '""').split('\n').join('"_$Char(10)_"')}"`;
}

/**
 * Script the provider's reply to one tool call: a tool use of `wire` with `input`, whose `Text` is the document. The
 * input is built ObjectScript variable by variable, so a document's line feeds never meet the one-line script call.
 */
function scriptToolUse(tag, wire, input) {
  const name = `${probe.marker}-SCRIPT`;
  const output = runIris([
    `Set tInput={}`,
    ...Object.entries(input).map(([key, value]) => `Do tInput.%Set("${key}", ${osString(value)}, "string")`),
    `Set tBlock={"id": "toolu_create", "name": "${wire}"}`,
    `Do tBlock.%Set("input", tInput)`,
    `Set sc=##class(OcuPilot.Test.TurnProvider).Script("${escapeOs(tag)}",0,##class(OcuPilot.Test.TurnProvider).ToolUseReply([(tBlock)]),200,"")`,
    `Write "OCU-${name}-START:"_$System.Status.IsOK(sc)_":OCU-${name}-END",!`,
  ]);
  assert.equal(markerValue(output, name), '1', `Script succeeded: ${output}`);
}

/** Script the reply that ends the turn with a line of text. */
function scriptText(tag, text) {
  const name = `${probe.marker}-SCRIPT`;
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.TurnProvider).Script("${escapeOs(tag)}",0,##class(OcuPilot.Test.TurnProvider).TextReply(${osString(text)}),200,"")`,
    `Write "OCU-${name}-START:"_$System.Status.IsOK(sc)_":OCU-${name}-END",!`,
  ]);
  assert.equal(markerValue(output, name), '1', `Script succeeded: ${output}`);
}

function allowWrites() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly("${escapeOs(preparedId)}",0)`,
    `Write "OCU-AGENTCODECREATERW-START:"_$System.Status.IsOK(sc)_":OCU-AGENTCODECREATERW-END",!`,
  ]);
  assert.equal(markerValue(output, 'AGENTCODECREATERW'), '1', `the probe definition allows writes: ${output}`);
}

function dropProposals() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForUser("${escapeOs(config.username)}")`,
    `Do ##class(%SQL.Statement).%ExecDirect(,"DELETE FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(Name) IN ('${CLASS_KEY}', '${ROUTINE_KEY}')")`,
    `Write "OCU-AGENTCODECREATEDROP-START:"_$System.Status.IsOK(sc)_":OCU-AGENTCODECREATEDROP-END",!`,
  ]);
  assert.equal(markerValue(output, 'AGENTCODECREATEDROP'), '1', `the probe proposals are removed: ${output}`);
}

/** Remove the probe class and routine from USER, the namespace switched by explicit save and restore. */
function dropDocuments() {
  runIris([
    `Set tOrigNS=$NAMESPACE Set $NAMESPACE="USER" Do ##class(%SYSTEM.OBJ).Delete("${DOCUMENT}","-d") If ##class(%RoutineMgr).Exists("${ROUTINE}") Do ##class(%RoutineMgr).Delete("${ROUTINE}") Set $NAMESPACE=tOrigNS`,
  ]);
}

/** Whether a document of `name` is held in USER (`1`) or not (`0`). */
function held(name) {
  const output = runIris([
    `Set tOrigNS=$NAMESPACE Set $NAMESPACE="USER" Set tHeld=##class(%RoutineMgr).Exists("${name}") Set $NAMESPACE=tOrigNS`,
    `Write "OCU-AGENTCODECREATEHELD-START:"_(+tHeld)_":OCU-AGENTCODECREATEHELD-END",!`,
  ]);
  return markerValue(output, 'AGENTCODECREATEHELD') === '1';
}

/** Whether class `CLASS` is compiled in USER. */
function compiled() {
  const output = runIris([
    `Set tOrigNS=$NAMESPACE Set $NAMESPACE="USER" Set tCompiled=##class(%Dictionary.CompiledClass).%ExistsId("${CLASS}") Set $NAMESPACE=tOrigNS`,
    `Write "OCU-AGENTCODECREATECOMPILED-START:"_(+tCompiled)_":OCU-AGENTCODECREATECOMPILED-END",!`,
  ]);
  return markerValue(output, 'AGENTCODECREATECOMPILED') === '1';
}

/** Wait for the composer, send one prompt, and wait for the card's Confirm button. */
async function proposeCreate(page, prompt) {
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

test('a new class draws its whole text as added lines and says Confirm compiles; Confirm creates and compiles it with no compile warning', async () => {
  // Mutation (Rule 19): make `ComposeCreate` answer no diff row -> no added line is drawn and this goes red.
  dropDocuments();
  await requireFreeSlot(config);
  const tag = nextTag();
  setTag(tag);
  scriptToolUse(tag, CLASS_WIRE_NAME, { Names: DOCUMENT, Text: CLASS_TEXT, rationale: 'A probe class.', expectedImpact: 'the probe class is held' });
  scriptText(tag, 'created');
  const { context, page } = await signedInAt(browser, config, USER_URL);
  try {
    await proposeCreate(page, 'create the probe class');
    const drawn = await page.$$eval('app-proposal-card app-text-diff [data-ocu-diff="added"]', (nodes) => nodes.map((node) => ({
      text: node.textContent.replace(/\s+/g, ' ').trim(),
      number: node.querySelector('.ocu-line-diff-number')?.textContent.trim() ?? '',
    })));
    assert.equal(drawn.length, CLASS_TEXT.split('\n').length, `every line of the new class is drawn as added: ${JSON.stringify(drawn)}`);
    assert.equal(drawn[0].number, '1', 'the first added line is numbered 1');
    assert.ok(drawn[0].text.includes(`Class ${CLASS}`), `the first line is the class header: ${drawn[0].text}`);
    assert.equal(await page.$$eval('app-proposal-card app-text-diff [data-ocu-diff="removed"]', (nodes) => nodes.length), 0, 'nothing is removed');
    assert.equal(await slotText(page, 'consequence'), STRINGS.explorerSaveCompilesOnConfirm, 'the card says Confirm compiles');
    assert.equal(held(DOCUMENT), false, 'nothing is created before Confirm');

    await page.click('.ocu-proposal-card-confirm');
    await page.waitForSelector('app-proposal-card .ocu-proposal-card-status-confirmed', { timeout: config.navigationTimeoutMs });
    assert.equal(await slotText(page, 'saved-not-compiled'), null, 'a clean compile says nothing extra');
    assert.equal(held(DOCUMENT), true, 'Confirm creates the class');
    assert.equal(compiled(), true, 'and compiles it');
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
    dropDocuments();
  }
});

test('a new twelve-line routine starts collapsed under its summary line, Confirm works unopened, and the card passes the DW-1337 invariants', async () => {
  // Mutation (Rule 19): drop the `proposalSummaryLines` branch for a create's row -> the summary assertion goes red.
  dropDocuments();
  await requireFreeSlot(config);
  const tag = nextTag();
  setTag(tag);
  scriptToolUse(tag, ROUTINE_WIRE_NAME, { Names: ROUTINE, Text: ROUTINE_TEXT, rationale: 'A probe routine.', expectedImpact: 'the probe routine is held' });
  scriptText(tag, 'created');
  const { context, page } = await signedInAt(browser, config, USER_URL);
  try {
    await proposeCreate(page, 'create the probe routine');
    const summary = await page.$eval('app-proposal-card .ocu-proposal-card-summary-fields', (node) => node.textContent.replace(/\s+/g, ' ').trim());
    assert.match(summary, /lines changed, 0 removed and 12 added$/, `the summary counts the added lines: ${summary}`);
    const buttons = await page.$$eval('app-proposal-card button', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.ok(buttons.includes(STRINGS.longBlockShowMore), 'the diff starts collapsed behind Show more');
    assert.deepEqual(await cardViolations(page), [], 'the card adds no structural violation in light or dark, at either width');

    await page.click('.ocu-proposal-card-confirm');
    await page.waitForSelector('app-proposal-card .ocu-proposal-card-status-confirmed', { timeout: config.navigationTimeoutMs });
    assert.equal(held(ROUTINE), true, 'Confirm creates the routine without the diff being opened');
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
    dropDocuments();
  }
});

test('a new class that does not compile, confirmed, is said to be saved but not compiled, and is held uncompiled', async () => {
  // Mutation (Rule 19): make the saved-not-compiled condition always false -> the banner assertion goes red.
  dropDocuments();
  await requireFreeSlot(config);
  const tag = nextTag();
  setTag(tag);
  scriptToolUse(tag, CLASS_WIRE_NAME, { Names: DOCUMENT, Text: BROKEN_TEXT, rationale: 'A broken probe class.', expectedImpact: 'the class is held uncompiled' });
  scriptText(tag, 'created');
  const { context, page } = await signedInAt(browser, config, USER_URL);
  try {
    await proposeCreate(page, 'create the broken probe class');
    await page.click('.ocu-proposal-card-confirm');
    await page.waitForSelector('app-proposal-card [data-slot="saved-not-compiled"]', { timeout: config.navigationTimeoutMs });
    assert.equal(await slotText(page, 'saved-not-compiled'), STRINGS.explorerSaveNotCompiled, 'the card says the create did not compile');
    assert.equal(held(DOCUMENT), true, 'the instance holds the new class');
    assert.equal(compiled(), false, 'and it is not compiled');
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
    dropDocuments();
  }
});

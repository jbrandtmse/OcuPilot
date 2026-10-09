/**
 * The agent's class save in a real browser against the throwaway (Story 20.21): a scripted turn
 * proposes an exact replacement through `explorer.classes.save`; the card draws the changed lines as a
 * line diff and says that Confirm compiles; Confirm saves the text, and a save whose compile fails
 * says so under the status line. A 12-line hunk shows its lines summary, with the diff collapsed and
 * Confirm usable unopened. The live card passes the DW-1337 invariants in light and dark.
 *
 * The probe is a class `OcuProbe2021.BrowserSave` in `USER`, written and removed by this file. `before`
 * puts the governance policy back to its default, so both saves' keys read enabled; `after` removes its
 * proposals and the class and puts the definition back. It refuses to run in the live container or a slot
 * instance before any docker call.
 *
 * Run: `npm run build`, `docker cp` the bundle into the throwaway, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test browser/agent-code-save.browser-spec.mjs`.
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
  scriptReply as sharedScriptReply,
  setTag as sharedSetTag,
} from './turnprobe-spec.mjs';

const config = browserConfig();
const probe = { container: config.container, marker: 'AGENTCODESAVE' };
const STRINGS = loadStrings();

const USER_URL = '/ocupilot/?ns=USER';
/** The screen the card is drawn over, the baseline key the walk compares against. */
const ROUTE = 'system-explorer/classes';
const KEY = 'explorer.classes.save';
const TOOL_WIRE_NAME = 'explorer_classes_save';
const CLASS = 'OcuProbe2021.BrowserSave';
const DOCUMENT = `${CLASS}.cls`;

/** The probe's one method body line, and the twelve lines a long hunk replaces. */
const ONE_LINE = '    Quit 1';
const TWELVE = (offset) => Array.from({ length: 12 }, (_, index) => `    Set x${index + 1} = ${index + 1 + offset}`).join('\n');

let browser = null;
let preparedId = '';
let priorDefault = '';

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec saves and compiles a class, so it never runs inside the live container');
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
  writeClass(ONE_LINE);
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  await requireFreeSlot(config).catch(() => {});
  dropProposals();
  dropClass();
  await resetRememberedState();
  disarmProbeDefinition(probe, priorDefault);
});

const runIris = (lines) => sharedRunIris(config.container, lines);
const nextTag = () => sharedNextTag(probe);
const setTag = (tag) => sharedSetTag(probe, preparedId, tag);
const forgetTag = (tag) => sharedForgetTag(probe, tag);
const scriptReply = (tag, bodyExpr) => sharedScriptReply(probe, tag, 0, bodyExpr, 200);

function allowWrites() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly("${escapeOs(preparedId)}",0)`,
    `Write "OCU-AGENTCODESAVERW-START:"_$System.Status.IsOK(sc)_":OCU-AGENTCODESAVERW-END",!`,
  ]);
  assert.equal(markerValue(output, 'AGENTCODESAVERW'), '1', `the probe definition allows writes: ${output}`);
}

function dropProposals() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForUser("${escapeOs(config.username)}")`,
    `Do ##class(%SQL.Statement).%ExecDirect(,"DELETE FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(Name) = '${KEY}'")`,
    `Write "OCU-AGENTCODESAVEDROP-START:"_$System.Status.IsOK(sc)_":OCU-AGENTCODESAVEDROP-END",!`,
  ]);
  assert.equal(markerValue(output, 'AGENTCODESAVEDROP'), '1', `the probe proposals are removed: ${output}`);
}

/** Save the probe class in USER with the method body lines given, uncompiled, LF-ended. */
function writeClass(bodyLines) {
  const output = runIris([
    `Set t="Class ${CLASS} Extends %RegisteredObject"_$Char(10)_"{"_$Char(10)_"ClassMethod Probe() As %Integer"_$Char(10)_"{"_$Char(10)`,
    `Set t=t_"${bodyLines.split('\n').join('"_$Char(10)_"')}"_$Char(10)_"}"_$Char(10)_"}"_$Char(10)`,
    `Set sc=##class(%Compiler.UDL.TextServices).SetTextFromString("USER","${CLASS}",t,$Char(10))`,
    `Write "OCU-AGENTCODESAVEWRITE-START:"_$System.Status.IsOK(sc)_":OCU-AGENTCODESAVEWRITE-END",!`,
  ]);
  assert.equal(markerValue(output, 'AGENTCODESAVEWRITE'), '1', `the probe class is written: ${output}`);
}

function dropClass() {
  runIris([
    `Set tOrigNS=$NAMESPACE Set $NAMESPACE="USER" Do ##class(%SYSTEM.OBJ).Delete("${DOCUMENT}","-d") Set $NAMESPACE=tOrigNS`,
  ]);
}

/** The probe's stored text, as one line: `1` when it holds the marker, `0` when it does not. */
function storedHolds(fragment) {
  const output = runIris([
    `Set tOrigNS=$NAMESPACE Set $NAMESPACE="USER" Set sc=##class(%Compiler.UDL.TextServices).GetTextAsString("USER","${CLASS}",.t) Set $NAMESPACE=tOrigNS`,
    `Write "OCU-AGENTCODESAVEHOLD-START:"_(t[${JSON.stringify(fragment)})_":OCU-AGENTCODESAVEHOLD-END",!`,
  ]);
  return markerValue(output, 'AGENTCODESAVEHOLD') === '1';
}

/** The 1-based line of the probe's stored text that holds `fragment`, or 0 when none does. */
function storedLineOf(fragment) {
  const output = runIris([
    `Set tOrigNS=$NAMESPACE Set $NAMESPACE="USER" Set sc=##class(%Compiler.UDL.TextServices).GetTextAsString("USER","${CLASS}",.t) Set $NAMESPACE=tOrigNS`,
    `Write "OCU-AGENTCODESAVELINE-START:"_$Select(t[${JSON.stringify(fragment)}:$Length($Piece(t,${JSON.stringify(fragment)},1),$Char(10)),1:0)_":OCU-AGENTCODESAVELINE-END",!`,
  ]);
  return Number(markerValue(output, 'AGENTCODESAVELINE') ?? '0');
}

/** A scripted reply that proposes one exact replacement of the probe class's text. */
function saveReply(oldText, newText) {
  const input = {
    Names: DOCUMENT,
    Edits: [{ Old: oldText, New: newText }],
    rationale: 'The probe method changes.',
    expectedImpact: 'the method answers the new value',
    reverse: 'run the same save the other way round',
  };
  return `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_save", "name": "${TOOL_WIRE_NAME}", "input": ${JSON.stringify(input)}}])`;
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

test('a one-line edit draws a line diff and says Confirm compiles, and Confirm saves it with no compile warning', async () => {
  // Mutation (Rule 19): make the card ignore `kind` -> no `app-text-diff` and this goes red. The removed line's
  // number is the document's own line, which `ExplorerSaveMint.Hunk` sends as the hunk's first line.
  writeClass(ONE_LINE);
  await requireFreeSlot(config);
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, saveReply(ONE_LINE, '    Quit 2'));
  scriptReply(tag, `##class(OcuPilot.Test.TurnProvider).TextReply("saved")`);
  const { context, page } = await signedInAt(browser, config, USER_URL);
  try {
    await proposeSave(page, 'change the probe method');
    const card = await page.$eval('app-proposal-card', (node) => ({
      removed: node.querySelector('app-text-diff [data-ocu-diff="removed"]')?.textContent.replace(/\s+/g, ' ').trim() ?? '',
      added: node.querySelector('app-text-diff [data-ocu-diff="added"]')?.textContent.replace(/\s+/g, ' ').trim() ?? '',
      removedNumber: node.querySelector('app-text-diff [data-ocu-diff="removed"] .ocu-line-diff-number')?.textContent.trim() ?? '',
    }));
    assert.ok(card.removed.includes('Quit 1'), `the removed line is drawn: ${card.removed}`);
    assert.ok(card.added.includes('Quit 2'), `the added line is drawn: ${card.added}`);
    const documentLine = storedLineOf(ONE_LINE);
    assert.ok(documentLine > 1, `the probe's stored text holds the line: ${documentLine}`);
    assert.equal(card.removedNumber, String(documentLine), 'the removed line carries its line number in the document');
    assert.equal(await slotText(page, 'consequence'), STRINGS.explorerSaveCompilesOnConfirm, 'the card says Confirm compiles');
    assert.equal(await slotText(page, 'saved-not-compiled'), null, 'nothing is said about a compile before Confirm');
    assert.equal(storedHolds('Quit 1'), true, 'nothing was saved before Confirm');

    await page.click('.ocu-proposal-card-confirm');
    await page.waitForSelector('app-proposal-card .ocu-proposal-card-status', { timeout: config.navigationTimeoutMs });
    assert.equal(await slotText(page, 'saved-not-compiled'), null, 'a clean compile says nothing extra');
    assert.equal(storedHolds('Quit 2'), true, 'the confirmed save holds the new text');
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
  }
});

test('a breaking edit, confirmed, says it did not compile and leaves the new text on the instance', async () => {
  // Mutation (Rule 19): make the saved-not-compiled condition always false -> the banner assertion goes red.
  writeClass(ONE_LINE);
  await requireFreeSlot(config);
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, saveReply(ONE_LINE, '    Quit 1 Set x ='));
  scriptReply(tag, `##class(OcuPilot.Test.TurnProvider).TextReply("saved")`);
  const { context, page } = await signedInAt(browser, config, USER_URL);
  try {
    await proposeSave(page, 'break the probe method');
    await page.click('.ocu-proposal-card-confirm');
    await page.waitForSelector('app-proposal-card [data-slot="saved-not-compiled"]', { timeout: config.navigationTimeoutMs });
    assert.equal(await slotText(page, 'saved-not-compiled'), STRINGS.explorerSaveNotCompiled, 'the card says the save did not compile');
    assert.equal(storedHolds('Set x ='), true, 'the instance holds the new text, uncompiled');
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
  }
});

test('a 12-line hunk shows its lines summary, starts collapsed, and Confirm works unopened; the card passes the DW-1337 invariants', async () => {
  // Mutation (Rule 19): drop the `proposalSummaryLines` branch from `summaryFields` -> the summary assertion goes red.
  writeClass(TWELVE(0));
  await requireFreeSlot(config);
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, saveReply(TWELVE(0), TWELVE(100)));
  scriptReply(tag, `##class(OcuPilot.Test.TurnProvider).TextReply("saved")`);
  const { context, page } = await signedInAt(browser, config, USER_URL);
  try {
    await proposeSave(page, 'rewrite the probe values');
    const summary = await page.$eval('app-proposal-card .ocu-proposal-card-summary-fields', (node) => node.textContent.replace(/\s+/g, ' ').trim());
    assert.match(summary, /lines changed, 12 removed and 12 added$/, `the summary counts the lines: ${summary}`);
    const expand = await page.$$eval('app-proposal-card button', (buttons) => buttons.map((button) => button.textContent.trim()));
    assert.ok(expand.includes(STRINGS.longBlockShowMore), 'the diff starts collapsed behind Show more');
    assert.deepEqual(await cardViolations(page), [], 'the card adds no structural violation in light or dark, at either width');

    await page.click('.ocu-proposal-card-confirm');
    await page.waitForSelector('app-proposal-card .ocu-proposal-card-status', { timeout: config.navigationTimeoutMs });
    assert.equal(storedHolds('Set x12 = 112'), true, 'Confirm saved the hunk without the diff being opened');
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
  }
});

/** Where the card's diff sits: the clamp's box, whether a toggle is offered, and the box of each changed line. */
async function diffGeometry(page) {
  return page.$eval('app-proposal-card .ocu-proposal-card-diff', (node) => {
    const region = node.querySelector('.ocu-long-block-region').getBoundingClientRect();
    const toggle = node.querySelector('.ocu-long-block-toggle');
    const changed = [...node.querySelectorAll('[data-ocu-diff="removed"], [data-ocu-diff="added"]')].map((line) => {
      const box = line.getBoundingClientRect();
      return { kind: line.getAttribute('data-ocu-diff'), top: box.top, bottom: box.bottom };
    });
    const scroller = node.querySelector('.ocu-line-diff');
    return {
      regionTop: region.top,
      regionBottom: region.bottom,
      regionRight: region.right,
      toggle: toggle === null ? null : toggle.textContent.trim(),
      changed,
      scrollWidth: scroller.scrollWidth,
      clientWidth: scroller.clientWidth,
    };
  });
}

test('(QA) a one-line edit shows its changed lines inside the diff box without opening it, and the card passes the DW-1337 invariants', async () => {
  // Mutation (Rule 19): estimate a lines row from its `field before after` in `diffLines` -> the one-line diff starts
  // collapsed behind Show more and the no-toggle assertion goes red (after a rebuild and redeploy).
  writeClass(ONE_LINE);
  await requireFreeSlot(config);
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, saveReply(ONE_LINE, '    Quit 2'));
  scriptReply(tag, `##class(OcuPilot.Test.TurnProvider).TextReply("saved")`);
  const { context, page } = await signedInAt(browser, config, USER_URL);
  try {
    await proposeSave(page, 'change the probe method');
    const geometry = await diffGeometry(page);
    assert.equal(geometry.toggle, null, `a one-line edit's diff is short and offers no Show more: ${JSON.stringify(geometry)}`);
    assert.equal(geometry.changed.length, 2, 'the removed and the added line are drawn');
    for (const line of geometry.changed) {
      assert.ok(line.top >= geometry.regionTop - 1 && line.bottom <= geometry.regionBottom + 1, `the ${line.kind} line is inside the diff's box without opening it: ${JSON.stringify(geometry)}`);
    }
    assert.deepEqual(await cardViolations(page), [], 'the card adds no structural violation in light or dark, at either width');
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
  }
});

test('(QA) a long changed line in an opened diff scrolls inside it, widens neither the card nor the page, and passes the DW-1337 invariants', async () => {
  // Mutation (Rule 19): drop `contain: inline-size` from `.ocu-text-diff` -> the card is wider than the panel and the
  // containment assertions go red; drop `display: grid` from `.ocu-line-diff` -> the long line's text overflows its
  // row and the row-containment leg goes red (each after a rebuild and redeploy).
  writeClass(ONE_LINE);
  await requireFreeSlot(config);
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, saveReply(ONE_LINE, `    Set note = "${'w'.repeat(240)}"`));
  scriptReply(tag, `##class(OcuPilot.Test.TurnProvider).TextReply("saved")`);
  const { context, page } = await signedInAt(browser, config, USER_URL);
  try {
    await proposeSave(page, 'add a long note to the probe method');
    // Opened, so the long block's own clip is gone and only the diff's containment keeps the line in.
    await page.click('app-proposal-card .ocu-proposal-card-diff .ocu-long-block-toggle');
    await page.waitForFunction(() => document.querySelector('app-proposal-card .ocu-proposal-card-diff .ocu-long-block-toggle')?.getAttribute('aria-expanded') === 'true', { timeout: config.navigationTimeoutMs });
    for (const viewport of [VIEWPORTS.wide, VIEWPORTS.narrow]) {
      await page.setViewport(viewport);
      await page.waitForFunction((width) => {
        const panel = document.querySelector('app-panel');
        return panel === null || panel.getBoundingClientRect().right <= width + 1;
      }, { timeout: 3000 }, viewport.width).catch(() => {});
      const fit = await page.evaluate(() => {
        const root = document.documentElement;
        const card = document.querySelector('app-proposal-card .ocu-proposal-card').getBoundingClientRect();
        const panel = document.querySelector('app-panel').getBoundingClientRect();
        const scroller = document.querySelector('app-proposal-card .ocu-line-diff');
        return {
          pageScroll: root.scrollWidth - root.clientWidth,
          cardRight: card.right,
          panelRight: panel.right,
          scrollerRight: scroller.getBoundingClientRect().right,
          scrolls: scroller.scrollWidth - scroller.clientWidth,
          overflowX: getComputedStyle(scroller).overflowX,
        };
      });
      assert.ok(fit.pageScroll <= 1, `the page does not scroll sideways at ${viewport.width}px: ${JSON.stringify(fit)}`);
      assert.ok(fit.cardRight <= fit.panelRight + 1, `the card stays inside the panel at ${viewport.width}px: ${JSON.stringify(fit)}`);
      assert.ok(fit.scrollerRight <= fit.cardRight + 1, `the diff stays inside the card at ${viewport.width}px: ${JSON.stringify(fit)}`);
      assert.ok(fit.scrolls > 100 && ['auto', 'scroll'].includes(fit.overflowX), `the long line scrolls inside the diff at ${viewport.width}px: ${JSON.stringify(fit)}`);
    }
    await page.setViewport(VIEWPORTS.wide);
    const rows = await page.$$eval('app-proposal-card app-text-diff .ocu-line-diff-line', (nodes) =>
      nodes.map((node) => ({ right: node.getBoundingClientRect().right, text: node.querySelector('.ocu-line-diff-text').getBoundingClientRect().right }))
    );
    assert.ok(rows.every((row) => row.text <= row.right + 1), `every drawn line's text stays inside its row: ${JSON.stringify(rows)}`);
    assert.ok(rows.every((row) => Math.abs(row.right - rows[0].right) <= 1), `every row is as wide as the longest: ${JSON.stringify(rows)}`);
    assert.deepEqual(await cardViolations(page), [], 'the opened diff with a long line adds no structural violation in light or dark, at either width');
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
  }
});

test('(QA) an opened 12-line diff passes the DW-1337 invariants in light and dark, at both widths', async () => {
  // Mutation (Rule 19): give `.ocu-line-diff-removed` the surface background in dark theme only -> the contrast
  // invariant goes red (after a rebuild and redeploy).
  writeClass(TWELVE(0));
  await requireFreeSlot(config);
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, saveReply(TWELVE(0), TWELVE(100)));
  scriptReply(tag, `##class(OcuPilot.Test.TurnProvider).TextReply("saved")`);
  const { context, page } = await signedInAt(browser, config, USER_URL);
  try {
    await proposeSave(page, 'rewrite the probe values');
    await page.click('app-proposal-card .ocu-proposal-card-diff .ocu-long-block-toggle');
    await page.waitForFunction(() => document.querySelector('app-proposal-card .ocu-proposal-card-diff .ocu-long-block-toggle')?.getAttribute('aria-expanded') === 'true', { timeout: config.navigationTimeoutMs });
    const drawn = await page.$$eval('app-proposal-card app-text-diff [data-ocu-diff="removed"], app-proposal-card app-text-diff [data-ocu-diff="added"]', (nodes) => nodes.length);
    assert.equal(drawn, 24, 'all twelve removed and twelve added lines are drawn');
    assert.deepEqual(await cardViolations(page), [], 'the opened diff adds no structural violation in light or dark, at either width');
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
  }
});

test('(QA) a document changed after the mint is refused at Confirm, says so, and keeps the other writer\'s text', async () => {
  // Mutation (Rule 19): make `Confirm.FingerprintMatches` skip the fresh digest's comparison -> the port's own version
  // conflict answers instead, the target-changed status never shows, and this goes red.
  writeClass(ONE_LINE);
  await requireFreeSlot(config);
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, saveReply(ONE_LINE, '    Quit 2'));
  scriptReply(tag, `##class(OcuPilot.Test.TurnProvider).TextReply("saved")`);
  const { context, page } = await signedInAt(browser, config, USER_URL);
  try {
    await proposeSave(page, 'change the probe method');
    writeClass('    Quit 3');
    await page.click('.ocu-proposal-card-confirm');
    await page.waitForSelector('app-proposal-card .ocu-proposal-card-status-target-changed', { timeout: config.navigationTimeoutMs });
    const status = await page.$eval('app-proposal-card .ocu-proposal-card-status-target-changed', (node) => node.textContent.replace(/\s+/g, ' ').trim());
    assert.ok(status.includes(STRINGS.proposalTargetChanged), `the card says the target changed: ${status}`);
    assert.equal(await slotText(page, 'saved-not-compiled'), null, 'and says nothing about a compile');
    assert.equal(storedHolds('Quit 3'), true, "the other writer's text stays");
    assert.equal(storedHolds('Quit 2'), false, 'and the proposed text was not saved');
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
  }
});

/**
 * The guided workflow in a real browser against the throwaway (Story 20.12, AD-66): on the Classes list, choosing
 * "Fix a class until it compiles, step by step" starts a workflow turn -- the chip shows its label and the prompt's
 * text, the first provider request holds the `compileclass` workflow result whose steps name `explorer.classes.save`,
 * and the scripted save mints one card; Continue waits, `aria-disabled` and naming why, while that card is live; Confirm
 * saves the class; Continue then sends "Continue the guided workflow." and the second turn's first request reads the
 * first proposal as `confirmed` in `previous`; its scripted save mints a second card, confirmed on its own, so no
 * control ever confirms two cards. The chip with a live card passes the DW-1337 invariants `cardViolations` measures
 * (light at both widths, dark at the wide one); End workflow and New conversation remove the chip, a typed message
 * while the chip shows carries the workflow, and the first message after either names none.
 *
 * The probe is a class `OcuProbe2012.BrowserFlow` in `USER`, written and removed by this file. `before` puts the
 * governance policy back to its default, so the save's key reads enabled; `after` removes its proposals and the class
 * and puts the definition back. It refuses to run in the live container or a slot instance before any docker call.
 *
 * Run: `npm run build`, `docker cp` the bundle into the throwaway, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test browser/guided-workflow.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { signedInAt } from './panel-spec.mjs';
import { resetGovernancePolicy, resetRememberedState } from './preferences-reset.mjs';
import { cardViolations } from './proposal-card-spec.mjs';
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
const probe = { container: config.container, marker: 'GUIDEDWORKFLOW' };
const STRINGS = loadStrings();

const CLASSES_URL = '/ocupilot/system-explorer/classes?ns=USER';
/** The screen the chip and card are drawn over, the baseline key the walk compares against. */
const ROUTE = 'system-explorer/classes';
const TOOL_WIRE_NAME = 'explorer_classes_save';
const CLASS = 'OcuProbe2012.BrowserFlow';
const DOCUMENT = `${CLASS}.cls`;
const WAIT_ID = 'ocu-panel-workflow-wait-reason';

let browser = null;
let preparedId = '';
let priorDefault = '';

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec saves a class, so it never runs inside the live container');
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
  writeClass();
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
    `Write "OCU-GUIDEDWORKFLOWRW-START:"_$System.Status.IsOK(sc)_":OCU-GUIDEDWORKFLOWRW-END",!`,
  ]);
  assert.equal(markerValue(output, 'GUIDEDWORKFLOWRW'), '1', `the probe definition allows writes: ${output}`);
}

function dropProposals() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForUser("${escapeOs(config.username)}")`,
    `Do ##class(%SQL.Statement).%ExecDirect(,"DELETE FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(Name) = 'explorer.classes.save'")`,
    `Write "OCU-GUIDEDWORKFLOWDROP-START:"_$System.Status.IsOK(sc)_":OCU-GUIDEDWORKFLOWDROP-END",!`,
  ]);
  assert.equal(markerValue(output, 'GUIDEDWORKFLOWDROP'), '1', `the probe proposals are removed: ${output}`);
}

/** Save the probe class in USER, its one method answering 1, uncompiled. */
function writeClass() {
  const output = runIris([
    `Set t=##class(OcuPilot.Test.ExplorerSaveProbe).ClassText("${CLASS}",1)`,
    `Set sc=##class(%Compiler.UDL.TextServices).SetTextFromString("USER","${CLASS}",t,$Char(10))`,
    `Write "OCU-GUIDEDWORKFLOWWRITE-START:"_$System.Status.IsOK(sc)_":OCU-GUIDEDWORKFLOWWRITE-END",!`,
  ]);
  assert.equal(markerValue(output, 'GUIDEDWORKFLOWWRITE'), '1', `the probe class is written: ${output}`);
}

function dropClass() {
  runIris([`Set tOrigNS=$NAMESPACE Set $NAMESPACE="USER" Do ##class(%SYSTEM.OBJ).Delete("${DOCUMENT}","-d") Set $NAMESPACE=tOrigNS`]);
}

/** Whether the probe's stored text holds `fragment`. */
function storedHolds(fragment) {
  const output = runIris([
    `Set tOrigNS=$NAMESPACE Set $NAMESPACE="USER" Set sc=##class(%Compiler.UDL.TextServices).GetTextAsString("USER","${CLASS}",.t) Set $NAMESPACE=tOrigNS`,
    `Write "OCU-GUIDEDWORKFLOWHOLD-START:"_(t[${JSON.stringify(fragment)})_":OCU-GUIDEDWORKFLOWHOLD-END",!`,
  ]);
  return markerValue(output, 'GUIDEDWORKFLOWHOLD') === '1';
}

/** `OcuPilot.Test.WorkflowTurnCase.WorkflowSummary` of provider request `call` of `tag`. */
function workflowSummary(tag, call) {
  const output = runIris([`Write "OCU-GUIDEDWORKFLOWSUM-START:"_##class(OcuPilot.Test.WorkflowTurnCase).WorkflowSummary("${escapeOs(tag)}",${call})_":OCU-GUIDEDWORKFLOWSUM-END",!`]);
  return markerValue(output, 'GUIDEDWORKFLOWSUM');
}

/** A scripted reply that proposes one exact replacement of the probe class's text. */
function saveReply(id, oldText, newText) {
  const input = {
    Names: DOCUMENT,
    Edits: [{ Old: oldText, New: newText }],
    rationale: 'The probe method changes.',
    expectedImpact: 'the method answers the new value',
    reverse: 'run the same save the other way round',
  };
  return `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "${id}", "name": "${TOOL_WIRE_NAME}", "input": ${JSON.stringify(input)}}])`;
}

/** Wait for the composer, find the suggested prompt whose text is `text`, and click it. */
async function choosePrompt(page, text) {
  await page.waitForFunction(() => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'), { timeout: config.navigationTimeoutMs });
  await page.waitForFunction(
    (wanted) => [...document.querySelectorAll('.ocu-suggested-starter')].some((node) => node.querySelector('span')?.textContent.trim() === wanted),
    { timeout: config.navigationTimeoutMs },
    text
  );
  await page.evaluate((wanted) => {
    [...document.querySelectorAll('.ocu-suggested-starter')].find((node) => node.querySelector('span')?.textContent.trim() === wanted).click();
  }, text);
}

/** Type `text` into the composer, send it, and wait until the panel shows the scripted reply `reply`. */
async function sendTyped(page, text, reply) {
  await page.waitForFunction(() => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'), { timeout: config.navigationTimeoutMs });
  await page.type('#ocu-panel-composer', text);
  await page.click('.ocu-panel-send');
  await page.waitForFunction((wanted) => document.querySelector('app-panel')?.textContent.includes(wanted), { timeout: config.navigationTimeoutMs }, reply);
}

/** The chip's facts: its label, its text and Continue's wiring, or `null` when it is not drawn. */
function readChip(page) {
  return page.evaluate(() => {
    const chip = document.querySelector('[data-ocu-workflow-chip]');
    if (chip === null) return null;
    const next = chip.querySelector('.ocu-workflow-chip-continue');
    const reasonId = next.getAttribute('aria-describedby');
    return {
      label: chip.querySelector('.ocu-workflow-chip-label')?.textContent.trim(),
      name: chip.querySelector('.ocu-workflow-chip-name')?.textContent.trim(),
      continueText: next.textContent.trim(),
      endText: chip.querySelector('.ocu-workflow-chip-end')?.textContent.trim(),
      disabled: next.getAttribute('aria-disabled'),
      nativelyDisabled: next.hasAttribute('disabled'),
      reasonId,
      reason: reasonId === null ? null : (document.getElementById(reasonId)?.textContent.trim() ?? null),
    };
  });
}

test('a workflow runs as a sequence of confirmations: two turns, two cards, each confirmed on its own', async () => {
  // Mutation (Rule 19): `Loop.Run` adds no `workflow` pair -> the first summary goes red; `previous` is read from the
  // current turn -> the second summary goes red; `TurnStore.send` drops `workflow` -> the first summary goes red (the
  // bundle rebuilt and redeployed first).
  await requireFreeSlot(config);
  writeClass();
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, saveReply('toolu_one', '    Quit 1', '    Quit 2'));
  scriptReply(tag, `##class(OcuPilot.Test.TurnProvider).TextReply("first")`);
  scriptReply(tag, saveReply('toolu_two', '    Quit 2', '    Quit 3'));
  scriptReply(tag, `##class(OcuPilot.Test.TurnProvider).TextReply("second")`);
  scriptReply(tag, `##class(OcuPilot.Test.TurnProvider).TextReply("AFTERENDREPLY")`);
  const { context, page } = await signedInAt(browser, config, CLASSES_URL);
  try {
    assert.equal(await readChip(page), null, 'no chip before a workflow starts');
    await choosePrompt(page, STRINGS.explorerClassListWorkflowCompile);
    await page.waitForSelector('app-proposal-card .ocu-proposal-card-confirm', { timeout: config.navigationTimeoutMs });

    const chip = await readChip(page);
    assert.equal(chip?.label, STRINGS.agentWorkflowLabel, 'the chip reads Guided workflow');
    assert.equal(chip?.name, STRINGS.explorerClassListWorkflowCompile, 'and the prompt that started it');
    assert.equal(chip?.continueText, STRINGS.agentWorkflowContinue);
    assert.equal(chip?.endText, STRINGS.agentWorkflowEnd);
    assert.equal(workflowSummary(tag, 1), 'compileclass|1|0||', 'the first request holds the compileclass result, its steps naming the save, with no previous');

    // The turn has ended (the composer is available again), so only the live card can be holding Continue.
    await page.waitForFunction(() => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'), { timeout: config.navigationTimeoutMs });
    const waiting = await readChip(page);
    assert.equal(waiting?.disabled, 'true', 'Continue is aria-disabled while the card is live');
    assert.equal(waiting?.nativelyDisabled, false, 'never natively disabled');
    assert.equal(waiting?.reasonId, WAIT_ID, 'and is described by the live-card reason');
    assert.equal(waiting?.reason, STRINGS.agentWorkflowContinueWait, 'which names it');
    assert.equal(await page.$$eval('app-proposal-card .ocu-proposal-card-confirm', (nodes) => nodes.length), 1, 'one card, one Confirm');
    assert.deepEqual(await cardViolations(page, ROUTE, config.navigationTimeoutMs), [], 'the chip beside the live card adds no structural violation cardViolations measures');

    await page.click('.ocu-proposal-card-confirm');
    await page.waitForSelector('app-proposal-card .ocu-proposal-card-status', { timeout: config.navigationTimeoutMs });
    assert.equal(storedHolds('Quit 2'), true, 'Confirm saved the first change');
    await page.waitForFunction(() => !document.querySelector('.ocu-workflow-chip-continue').hasAttribute('aria-disabled'), { timeout: config.navigationTimeoutMs });
    assert.equal(storedHolds('Quit 3'), false, 'the second change is not made by anything but its own card');

    await page.waitForFunction(() => document.querySelectorAll('app-proposal-card .ocu-proposal-card-confirm').length === 0, { timeout: config.navigationTimeoutMs });
    await page.click('.ocu-workflow-chip-continue');
    await page.waitForSelector('app-proposal-card .ocu-proposal-card-confirm', { timeout: config.navigationTimeoutMs });
    const lastMessage = await page.$$eval('.ocu-panel-message-user', (nodes) => nodes.at(-1)?.textContent.trim());
    assert.equal(lastMessage, STRINGS.agentWorkflowContinueMessage, 'Continue sent its sentence');
    assert.equal(
      workflowSummary(tag, 3),
      'compileclass|1|1|explorer.classes.save|confirmed',
      'the second turn reads the first proposal as confirmed in previous'
    );
    assert.equal(await page.$$eval('app-proposal-card .ocu-proposal-card-confirm', (nodes) => nodes.length), 1, 'the second turn holds its own one card');
    assert.equal(storedHolds('Quit 3'), false, 'and nothing has confirmed it');

    await page.click('.ocu-proposal-card-confirm');
    await page.waitForFunction(() => document.querySelectorAll('app-proposal-card .ocu-proposal-card-status').length === 2, { timeout: config.navigationTimeoutMs });
    assert.equal(storedHolds('Quit 3'), true, 'the second card, confirmed on its own, saved the second change');

    await page.click('.ocu-workflow-chip-end');
    await page.waitForFunction(() => document.querySelector('[data-ocu-workflow-chip]') === null, { timeout: config.navigationTimeoutMs });
    assert.equal(await page.evaluate(() => document.activeElement?.id), 'ocu-panel-composer', 'End workflow removes the chip and focuses the composer');
    await sendTyped(page, 'a plain message', 'AFTERENDREPLY');
    assert.equal(workflowSummary(tag, 5), 'none', 'the first request after End workflow holds no workflow result');
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
  }
});

test('New conversation removes the chip of a workflow that proposes nothing', async () => {
  // Mutation (Rule 19): `newConversation` keeps the workflow -> the chip assertion goes red; a store that sends the
  // workflow it last carried after the chip is gone -> the `none` assertions go red (the bundle rebuilt and redeployed first).
  await requireFreeSlot(config);
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, `##class(OcuPilot.Test.TurnProvider).TextReply("reviewed")`);
  scriptReply(tag, `##class(OcuPilot.Test.TurnProvider).TextReply("TYPEDREPLY")`);
  scriptReply(tag, `##class(OcuPilot.Test.TurnProvider).TextReply("FRESHREPLY")`);
  const { context, page } = await signedInAt(browser, config, CLASSES_URL);
  try {
    await choosePrompt(page, STRINGS.explorerClassListWorkflowReview);
    await page.waitForSelector('[data-ocu-workflow-chip]', { timeout: config.navigationTimeoutMs });
    await page.waitForFunction(() => !document.querySelector('.ocu-workflow-chip-continue').hasAttribute('aria-disabled'), { timeout: config.navigationTimeoutMs });
    assert.equal(workflowSummary(tag, 1), 'reviewclass|0|0||', 'the review workflow names no write tool');
    const chip = await readChip(page);
    assert.equal(chip?.name, STRINGS.explorerClassListWorkflowReview);
    assert.equal(chip?.disabled, null, 'Continue is available once the turn has ended with nothing to decide');

    await sendTyped(page, 'and what else?', 'TYPEDREPLY');
    assert.equal(workflowSummary(tag, 2), 'reviewclass|0|0||', 'a typed message while the chip shows carries the workflow to the instance');
    assert.notEqual(await readChip(page), null, 'and the chip stays');

    await page.click(`button[aria-label="${STRINGS.actionNewConversation}"]`);
    await page.waitForFunction(() => document.querySelector('[data-ocu-workflow-chip]') === null, { timeout: config.navigationTimeoutMs });
    assert.equal(await readChip(page), null, 'a new conversation ends the workflow');
    await sendTyped(page, 'a fresh start', 'FRESHREPLY');
    assert.equal(workflowSummary(tag, 3), 'none', 'the first request of the new conversation holds no workflow result');
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
  }
});

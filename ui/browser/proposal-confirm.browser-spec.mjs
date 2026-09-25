/**
 * One confirmed write, end to end, in a real browser against the throwaway instance (Story 5.3).
 *
 * **This is the only spec in the tree that makes a real instance write through the agent.** A real
 * turn mints a real proposal, the user presses Confirm, `OcuPilot.Kernel.Proposal.Confirm` claims
 * it and `OcuPilot.Port.AdminPort` issues the vendor `PUT` -- and the value the diff promised is
 * then read back off the web-applications list screen, re-fetched in the browser rather than
 * inspected on the instance (AC10, Rule 1).
 *
 * **It writes to its own web application and nothing else.** `OcuPilot.Test.ProposalFixture`
 * creates `/csp/ocupilotprobeconfirm` before the first test and deletes it after the last; nothing
 * this spec touches existed before it ran. It refuses outright to run inside the live container.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test
 * browser/proposal-confirm.browser-spec.mjs`. The build output is `dist/ocupilot-ui`; a spec run
 * against a bundle that was not rebuilt reads the old client and proves nothing.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { signedInAt } from './panel-spec.mjs';
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
const probe = { container: config.container, marker: 'CONFIRM' };
const STRINGS = loadStrings();

const HOME_URL = '/ocupilot/?ns=HSCUSTOM';

/** The web-applications list, which AC10 re-fetches the written value from. */
const LIST_URL = '/ocupilot/web-applications/list?ns=HSCUSTOM';

/** This spec's own web application. Created here, written here, deleted here. */
const TARGET = '/csp/ocupilotprobeconfirm';

/** The write tool's provider-side name: the canonical dotted name with underscores (AD-42). */
const TOOL_WIRE_NAME = 'webapp_list_update';

let browser = null;
let preparedId = '';
let priorDefault = '';

before(async () => {
  assert.notEqual(
    config.container,
    LIVE_CONTAINER,
    'this spec makes a real confirmed write, so it never runs inside the live container'
  );
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);
  browser = await puppeteer.launch(launchOptions(config));
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
  // Cleared here rather than relying on the definition default; under read-only no proposal is minted (AD-30).
  allowWrites();
  ensureTarget();
  dropProposals();
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  await requireFreeSlot(config).catch(() => {});
  dropProposals();
  removeTarget();
  disarmProbeDefinition(probe, priorDefault);
});

function runIris(lines) {
  return sharedRunIris(config.container, lines);
}

const nextTag = () => sharedNextTag(probe);
const setTag = (tag) => sharedSetTag(probe, preparedId, tag);
const forgetTag = (tag) => sharedForgetTag(probe, tag);

function scriptReply(tag, hangSeconds, bodyExpr) {
  sharedScriptReply(probe, tag, hangSeconds, bodyExpr);
}

/** Clear the probe definition's read-only flag, so its write tool mints rather than refusing. */
function allowWrites() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly("${escapeOs(preparedId)}",0)`,
    `Write "OCU-CONFRW-START:"_$System.Status.IsOK(sc)_":OCU-CONFRW-END",!`,
  ]);
  assert.equal(markerValue(output, 'CONFRW'), '1', `the probe definition allows writes: ${output}`);
}

/** Create this spec's own web application, and refuse to run if it could not be created. */
function ensureTarget() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.ProposalFixture).EnsureWriteTarget($Namespace,.created)`,
    `Write "OCU-CONFAPP-START:"_$System.Status.IsOK(sc)_":OCU-CONFAPP-END",!`,
  ]);
  assert.equal(markerValue(output, 'CONFAPP'), '1', `the probe application is created: ${output}`);
}

function removeTarget() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.ProposalFixture).RemoveWriteTarget()`,
    `Write "OCU-CONFDEL-START:"_$System.Status.IsOK(sc)_":OCU-CONFDEL-END",!`,
  ]);
  assert.equal(markerValue(output, 'CONFDEL'), '1', `the probe application is removed: ${output}`);
}

/** The target's stored `Enabled`, read from the instance -- the write's other witness. */
function storedEnabled() {
  const output = runIris([
    `Write "OCU-CONFVAL-START:"_##class(OcuPilot.Test.ProposalFixture).WriteTargetField("Enabled")_":OCU-CONFVAL-END",!`,
  ]);
  return markerValue(output, 'CONFVAL') ?? '';
}

/** How many live proposals this spec's own principal still holds, read off the instance. */
function liveProposalCount() {
  const output = runIris([
    `Set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(UserName) = ? AND %EXACT(State) = 'live'","${escapeOs(config.username)}")`,
    `Set n=-1 If rs.%Next() Set n=rs.%GetData(1)`,
    `Write "OCU-CONFLIVE-START:"_n_":OCU-CONFLIVE-END",!`,
  ]);
  return Number(markerValue(output, 'CONFLIVE') ?? '-1');
}

/** Remove every proposal this spec's own principal has minted. */
function dropProposals() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForUser("${escapeOs(config.username)}")`,
    `Write "OCU-CONFDROP-START:"_$System.Status.IsOK(sc)_":OCU-CONFDROP-END",!`,
  ]);
  assert.equal(markerValue(output, 'CONFDROP'), '1', `the probe proposals are removed: ${output}`);
}

/**
 * A `tool_use` reply proposing `enabled` on this spec's own application.
 *
 * `Enabled` is the field under test because it is one the web-applications list actually draws, so
 * AC10's read-back is off the screen a user would look at rather than off a column nobody sees.
 * `Resource`, `DispatchClass` and `AutheEnabled` are deliberately never proposed here: a change that
 * clears the resource, repoints the code or admits unauthenticated callers is minted destructive
 * (AD-10), which is not the flow this spec confirms.
 */
function proposeReply(enabled) {
  const input = {
    Name: TARGET,
    Enabled: enabled,
    rationale: 'The application is serving when it should not be.',
    expectedImpact: 'the list reports it as not enabled',
    reverse: 'enable it again',
  };
  return `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_conf", "name": "${TOOL_WIRE_NAME}", "input": ${JSON.stringify(input)}}])`;
}

function textReply(text) {
  return `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs(text)}")`;
}

/** A signed-in page standing on Home with one live card proposing `enabled`. */
async function withLiveCard(enabled) {
  await requireFreeSlot(config);
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 0, proposeReply(enabled));
  scriptReply(tag, 0, textReply('done'));
  const { context, page } = await signedInAt(browser, config, HOME_URL);
  await page.waitForFunction(
    () => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'),
    { timeout: config.navigationTimeoutMs }
  );
  await page.type('#ocu-panel-composer', 'stop the probe application serving');
  await page.click('.ocu-panel-send');
  await page.waitForSelector('app-proposal-card .ocu-proposal-card-confirm', {
    timeout: config.navigationTimeoutMs,
  });
  return { context, page, tag };
}

test('AC10: Confirm writes to the instance, and the list re-fetched shows the value the diff promised', async () => {
  // Mutation (Rule 19): stop issuing the port call after the claim commits in
  // `OcuPilot.Kernel.Proposal.Confirm.Transition` -> the card still reads confirmed and the two
  // read-backs below both go red, which is what separates "the row was burned" from "the instance
  // was changed".
  assert.equal(storedEnabled(), '1', 'the target starts enabled, so the proposal has something to change');

  const { context, page, tag } = await withLiveCard(false);
  try {
    // Focus is inside the card when the transition happens, which is the case the status line is
    // a destination for (AC8).
    await page.focus('.ocu-proposal-card-confirm');
    await page.click('.ocu-proposal-card-confirm');
    await page.waitForSelector('app-proposal-card .ocu-proposal-card-status', {
      timeout: config.navigationTimeoutMs,
    });

    const settled = await page.evaluate(() => ({
      status: document.querySelector('.ocu-proposal-card-status').textContent.trim(),
      focused: document.activeElement === document.querySelector('.ocu-proposal-card-status'),
      confirm: document.querySelector('.ocu-proposal-card-confirm') === null,
      send: document.querySelector('.ocu-panel-send').className,
    }));
    assert.match(
      settled.status,
      /^Confirmed by .+ \u00b7 \d\d:\d\d:\d\d$/,
      `the buttons are replaced by the confirmed line: ${settled.status}`
    );
    assert.ok(settled.status.includes(config.username), settled.status);
    assert.equal(settled.focused, true, 'and the status line takes focus, because a button held it');
    assert.equal(settled.confirm, true, 'the outgoing buttons are gone once focus has landed');
    // The last live card is gone, so Send is a primary again (DESIGN.md `:1184` Live row).
    assert.ok(
      settled.send.includes('ocu-button-primary'),
      `Send returns to primary: ${settled.send}`
    );

    // The instance itself: the write landed.
    assert.equal(storedEnabled(), '0', 'the vendor PUT wrote the value the diff promised');

    // And the screen a user would look at: the list, re-fetched in the browser.
    await page.goto(`${config.origin}${LIST_URL}`, { waitUntil: 'networkidle2' });
    await page.waitForSelector('[role="grid"] .ocu-data-table-body [role="row"]', {
      timeout: config.navigationTimeoutMs,
    });
    const shown = await page.evaluate(
      (path) =>
        [...document.querySelectorAll('[role="grid"] .ocu-data-table-body [role="row"]')]
          .map((row) => (row.textContent ?? '').trim())
          .find((text) => text.includes(path)) ?? '',
      TARGET
    );
    assert.ok(shown !== '', `the list carries the target's row: ${shown}`);
    assert.ok(
      shown.includes(STRINGS.tableStatusNo),
      `the list re-fetched shows the value the diff promised: ${shown}`
    );
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
  }
});

test('a card the user cancels writes nothing, and the row is closed on the instance', async () => {
  // Propose the opposite of whatever the target currently reads, so this test stands on its own
  // rather than on the value the test above happened to leave behind: a proposal whose diff
  // changes nothing mints no card at all.
  const before = storedEnabled();
  const { context, page, tag } = await withLiveCard(before !== '1');
  try {
    await page.click('.ocu-proposal-card-cancel');
    await page.waitForFunction(
      (line) => document.querySelector('.ocu-proposal-card-status')?.textContent.trim() === line,
      { timeout: config.navigationTimeoutMs },
      STRINGS.proposalStatusCanceledByYou
    );
    assert.equal(storedEnabled(), before, 'nothing was written');
    // The instance holds the decision too, so a later confirm of the same id cannot claim it.
    // Mutation (Rule 19): drop `await this.turn.cancelProposal(proposalId)` from
    // `Panel.onCardCancel` -> the card still reads "Canceled by you" and this goes red.
    assert.equal(liveProposalCount(), 0, 'the instance carries no live proposal for this account');
    assert.equal(
      await page.evaluate(() => document.querySelector('.ocu-proposal-card-repropose') === null),
      true,
      'a cancel offers no Re-propose: the user declined, they did not lose the window'
    );
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
  }
});

/**
 * A confirmed create says "created", and a turn survives one dropped provider connection (Story
 * 10.6), in a real browser against the throwaway instance.
 *
 * **It creates one web application and nothing else.** `/csp/ocupilotprobecreated` is removed
 * through `%SYS` `Security.Applications` before the first test and after the last, so nothing this
 * spec touches existed before it ran. It refuses outright to run inside the live container.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test
 * browser/create-outcome.browser-spec.mjs`. A spec run against a bundle that was not rebuilt reads
 * the old client and proves nothing.
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
const probe = { container: config.container, marker: 'CREATED' };
const STRINGS = loadStrings();

const HOME_URL = '/ocupilot/?ns=HSCUSTOM';

/** The application the create proposes. Removed before and after this file runs. */
const TARGET = '/csp/ocupilotprobecreated';

/** The create tool's provider-side name: the canonical dotted name with underscores (AD-42). */
const TOOL_WIRE_NAME = 'webapp_list_create';

/** The published change sentences for the target. */
const CREATED_SENTENCE = STRINGS.tableChangeCreated.replace('<entity>', TARGET);
const UPDATED_SENTENCE = STRINGS.tableChangeUpdated.replace('<entity>', TARGET);

let browser = null;
let preparedId = '';
let priorDefault = '';

before(async () => {
  assert.notEqual(
    config.container,
    LIVE_CONTAINER,
    'this spec creates a web application, so it never runs inside the live container'
  );
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);
  browser = await puppeteer.launch(launchOptions(config));
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
  allowWrites();
  removeTarget();
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

function scriptReply(tag, bodyExpr, httpStatus = 200) {
  sharedScriptReply(probe, tag, 0, bodyExpr, httpStatus);
}

/** Clear the probe definition's read-only flag, so its write tool mints rather than refusing. */
function allowWrites() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly("${escapeOs(preparedId)}",0)`,
    `Write "OCU-CREATEDRW-START:"_$System.Status.IsOK(sc)_":OCU-CREATEDRW-END",!`,
  ]);
  assert.equal(markerValue(output, 'CREATEDRW'), '1', `the probe definition allows writes: ${output}`);
}

/** Whether the target exists on the instance, read in `%SYS`. */
function targetExists() {
  const output = runIris([
    'Set ns=$Namespace Set $Namespace="%SYS"',
    `Set e=##class(Security.Applications).Exists("${escapeOs(TARGET)}")`,
    'Set $Namespace=ns',
    `Write "OCU-CREATEDEX-START:"_e_":OCU-CREATEDEX-END",!`,
  ]);
  return markerValue(output, 'CREATEDEX');
}

/** Remove the target through `%SYS` `Security.Applications`, when it exists. */
function removeTarget() {
  const output = runIris([
    'Set ns=$Namespace Set $Namespace="%SYS"',
    `Set sc=1 If ##class(Security.Applications).Exists("${escapeOs(TARGET)}") Set sc=##class(Security.Applications).Delete("${escapeOs(TARGET)}")`,
    'Set $Namespace=ns',
    `Write "OCU-CREATEDRM-START:"_$System.Status.IsOK(sc)_":OCU-CREATEDRM-END",!`,
  ]);
  assert.equal(markerValue(output, 'CREATEDRM'), '1', `the probe application is absent: ${output}`);
}

/** Remove every proposal this spec's own principal has minted. */
function dropProposals() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForUser("${escapeOs(config.username)}")`,
    `Write "OCU-CREATEDDROP-START:"_$System.Status.IsOK(sc)_":OCU-CREATEDDROP-END",!`,
  ]);
  assert.equal(markerValue(output, 'CREATEDDROP'), '1', `the probe proposals are removed: ${output}`);
}

/** How many calls the scripted provider answered, or began answering, for `tag`. */
function providerCalls(tag) {
  const output = runIris([
    `Write "OCU-CREATEDCALLS-START:"_##class(OcuPilot.Test.TurnProvider).Calls("${escapeOs(tag)}")_":OCU-CREATEDCALLS-END",!`,
  ]);
  return Number(markerValue(output, 'CREATEDCALLS') ?? '-1');
}

/** A `tool_use` reply proposing the target's creation, password-authenticated in `HSCUSTOM`. */
function createReply() {
  const input = {
    Name: TARGET,
    NameSpace: 'HSCUSTOM',
    AutheEnabled: '32',
    Description: 'OcuPilot create-outcome probe',
    rationale: 'A probe application is needed.',
    expectedImpact: 'a new application answers at its path',
    reverse: 'delete it',
  };
  return `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_created", "name": "${TOOL_WIRE_NAME}", "input": ${JSON.stringify(input)}}])`;
}

function textReply(text) {
  return `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs(text)}")`;
}

/** Send one message from Home and wait for the create's card to offer Confirm. */
async function sendForCard(page) {
  await page.waitForFunction(
    () => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'),
    { timeout: config.navigationTimeoutMs }
  );
  await page.type('#ocu-panel-composer', 'create the probe application');
  await page.click('.ocu-panel-send');
  await page.waitForSelector('app-proposal-card .ocu-proposal-card-confirm', {
    timeout: config.navigationTimeoutMs,
  });
}

/**
 * Wait until the last agent reply starts with `want` and, where `names` is given, also carries it,
 * and answer its whole text. `names` is what the panel appends once the confirm has answered, so a
 * reply read before that is never mistaken for the settled one.
 */
async function lastReplyStartingWith(page, want, names = '') {
  await page.waitForFunction(
    (text, carried) => {
      const replies = document.querySelectorAll('.ocu-panel-message-agent-text');
      const last = replies[replies.length - 1]?.textContent ?? '';
      return last.startsWith(text) && last.includes(carried);
    },
    { timeout: config.navigationTimeoutMs },
    want,
    names
  );
  return page.evaluate(() => {
    const replies = document.querySelectorAll('.ocu-panel-message-agent-text');
    return replies[replies.length - 1]?.textContent ?? '';
  });
}

test('AC4: a confirmed create reads "was created" in the reply and the toast, and the application exists', async () => {
  // Mutation (Rule 19): revert `Panel.replyWithChangeSentence` to `STRINGS.tableChangeUpdated` ->
  // the reply assertion goes red; make `changeSentenceTemplate` answer updated for created -> the
  // toast assertion does, ahead of the reply's.
  assert.equal(targetExists(), '0', 'the target is absent before the create');
  await requireFreeSlot(config);
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, createReply());
  scriptReply(tag, textReply('created-done'));
  const { context, page } = await signedInAt(browser, config, HOME_URL);
  try {
    await sendForCard(page);
    await page.click('.ocu-proposal-card-confirm');
    await page.waitForSelector('app-proposal-card .ocu-proposal-card-status', {
      timeout: config.navigationTimeoutMs,
    });
    // Both surfaces are read before either is asserted, so a fault in one cannot hide the other.
    const reply = await lastReplyStartingWith(page, 'created-done', `${TARGET} was `);
    await page.waitForSelector('.ocu-toast-message', { timeout: config.navigationTimeoutMs });
    const toast = await page.evaluate(() => ({
      message: document.querySelector('.ocu-toast-message')?.textContent.trim() ?? '',
      link: document.querySelector('.ocu-toast-action')?.textContent.trim() ?? '',
    }));
    assert.equal(toast.message, CREATED_SENTENCE, 'the toast reads the create');
    assert.equal(
      toast.link,
      STRINGS.tableChangeToastLink.replace('<screen>', 'Web applications'),
      'with the Web applications link'
    );
    assert.ok(reply.includes(CREATED_SENTENCE), `the reply names the same create: ${reply}`);
    assert.ok(!reply.includes(UPDATED_SENTENCE), `and not an update: ${reply}`);

    assert.equal(targetExists(), '1', 'and the application exists on the instance');
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
    removeTarget();
  }
});

test('AC1: a turn whose model call breaks once before a status line still answers, with one card', async () => {
  // Mutation (Rule 19): remove the transport-retry branch in
  // `OcuPilot.Kernel.Provider.Base.Attempts` -> the turn fails at its second call and this goes red.
  await requireFreeSlot(config);
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, createReply());
  scriptReply(tag, '""', -1);
  scriptReply(tag, textReply('recovered-reply'));
  const { context, page } = await signedInAt(browser, config, HOME_URL);
  try {
    await sendForCard(page);
    await lastReplyStartingWith(page, 'recovered-reply');
    const settled = await page.evaluate(() => ({
      error: document.querySelector('.ocu-panel-error-banner') === null,
      cards: document.querySelectorAll('app-proposal-card').length,
    }));
    assert.equal(settled.error, true, 'the reply renders with no error');
    assert.equal(settled.cards, 1, 'and exactly one proposal card');
    assert.equal(providerCalls(tag), 3, 'the provider was reached three times: the proposal, the break, the retry');

    await page.click('.ocu-proposal-card-cancel');
    await page.waitForFunction(
      (line) => document.querySelector('.ocu-proposal-card-status')?.textContent.trim() === line,
      { timeout: config.navigationTimeoutMs },
      STRINGS.proposalStatusCanceledByYou
    );
    assert.equal(targetExists(), '0', 'the canceled card created nothing');
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
  }
});

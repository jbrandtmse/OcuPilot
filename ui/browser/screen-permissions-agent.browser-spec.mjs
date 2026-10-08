/**
 * Story 20.18 in a real browser, against the throwaway (AC1, AC2): the agent proposes a change to the
 * permissions of Locks (`osmgmt.locks`) through a scripted turn. A remove-pair draws the standard destructive
 * agent card -- the destructive bar and Confirm, no typed-name field, the `Pairs` row before and after, the
 * "requires" line naming the either-of Screen permissions admits, and the lowering's consequence sentence --
 * and Confirm writes the store. An add-pair draws a card that is not destructive and names no consequence.
 *
 * The signed-in user is the configured one. The spec resets Locks' adjustment before each test and after the
 * last, and never asserts the store empty beyond Locks' own row.
 *
 * It refuses the live container and any container that is not a throwaway.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test
 * browser/screen-permissions-agent.browser-spec.mjs`.
 */

import { test, before, after, beforeEach } from 'node:test';
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
const probe = { container: config.container, marker: 'SCREENACCESS' };
const STRINGS = loadStrings();

const HOME_URL = '/ocupilot/?ns=HSCUSTOM';

/** The screen the spec adjusts and the pairs its proposals name. */
const SCREEN = 'osmgmt.locks';
const LOWERED_PAIR = '%DB_IRISSYS:READ';
const RAISED_PAIR = '%Admin_Secure:USE';

/** What the card's "requires" line names: the either-of Screen permissions admits. */
const REQUIRES = '%Development:USE or %Admin_Secure:USE';

let browser = null;
let preparedId = '';
let priorDefault = '';

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec adjusts a screen, so it never runs inside the live container');
  assert.match(config.container, /-ci$/, `this spec runs only in a throwaway; ${config.container} is not one`);
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);
  browser = await puppeteer.launch(launchOptions(config));
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
  allowWrites();
  dropProposals();
  resetLocks();
});

beforeEach(() => {
  resetLocks();
});

after(async () => {
  if (browser !== null) await browser.close();
  if (!/-ci$/.test(config.container)) return;
  resetLocks();
  await requireFreeSlot(config).catch(() => {});
  dropProposals();
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

/** Clear the probe definition's read-only flag, so its write tools mint rather than refusing. */
function allowWrites() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly("${escapeOs(preparedId)}",0)`,
    `Write "OCU-SAWRITE-START:"_$System.Status.IsOK(sc)_":OCU-SAWRITE-END",!`,
  ]);
  assert.equal(markerValue(output, 'SAWRITE'), '1', `the probe definition allows writes: ${output}`);
}

/** Remove Locks' adjustment, whatever state it is in. */
function resetLocks() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Kernel.State.Access).GuardedGet("${SCREEN}",.p,.v,.f)`,
    `If $System.Status.IsOK(sc),f Set sc=##class(OcuPilot.Kernel.State.Access).GuardedRemove("${SCREEN}",v)`,
    `Write "OCU-SARESET-START:"_$System.Status.IsOK(sc)_":OCU-SARESET-END",!`,
  ]);
  assert.equal(markerValue(output, 'SARESET'), '1', `Locks is unadjusted: ${output}`);
}

/** Locks' stored adjustment, comma-separated, or the empty string when it has none. */
function storedAdjustment() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Kernel.State.Access).GuardedGet("${SCREEN}",.p,.v,.f)`,
    `Write "OCU-SASTORED-START:"_$Select(f:p,1:"")_":OCU-SASTORED-END",!`,
  ]);
  return markerValue(output, 'SASTORED') ?? '';
}

/** Remove every proposal this spec's own principal has minted. */
function dropProposals() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForUser("${escapeOs(config.username)}")`,
    `Write "OCU-SADROP-START:"_$System.Status.IsOK(sc)_":OCU-SADROP-END",!`,
  ]);
  assert.equal(markerValue(output, 'SADROP'), '1', `the probe proposals are removed: ${output}`);
}

/** A `tool_use` reply calling `wireName` for Locks with `pair`. */
function proposeReply(wireName, pair) {
  const input = {
    Screen: SCREEN,
    Pair: pair,
    rationale: 'You asked for a change to who can open Locks.',
    expectedImpact: 'the permissions Locks requires change',
  };
  return `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_screenaccess", "name": "${wireName}", "input": ${JSON.stringify(input)}}])`;
}

function textReply(text) {
  return `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs(text)}")`;
}

/** A signed-in page standing on Home with one live card for `wireName` and `pair`. */
async function withLiveCard(wireName, pair, message) {
  await requireFreeSlot(config);
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 0, proposeReply(wireName, pair));
  scriptReply(tag, 0, textReply('done'));
  const { context, page } = await signedInAt(browser, config, HOME_URL);
  await page.waitForFunction(() => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'), {
    timeout: config.navigationTimeoutMs,
  });
  await page.type('#ocu-panel-composer', message);
  await page.click('.ocu-panel-send');
  await page.waitForSelector('app-proposal-card .ocu-proposal-card-confirm', { timeout: config.navigationTimeoutMs });
  return { context, page, tag };
}

/** What the live card draws. */
function readCard(page) {
  return page.evaluate(() => {
    const card = document.querySelector('app-proposal-card .ocu-proposal-card');
    const confirm = document.querySelector('.ocu-proposal-card-confirm');
    return {
      destructiveCard: card.classList.contains('ocu-proposal-card-destructive'),
      destructiveConfirm: confirm.classList.contains('ocu-button-destructive'),
      typedName: document.querySelector('.ocu-typed-name-field') !== null,
      confirmDisabled: confirm.getAttribute('aria-disabled'),
      diff: Array.from(document.querySelectorAll('.ocu-diff-row')).map((row) => (row.textContent ?? '').replace(/\s+/g, ' ').trim()),
      requires: (document.querySelector('app-proposal-card [data-slot="privilege"]')?.textContent ?? '').replace(/\s+/g, ' ').trim(),
      consequence: (document.querySelector('app-proposal-card [data-slot="consequence"] .ocu-banner-message')?.textContent ?? '').trim(),
    };
  });
}

test('AC1: a remove-pair draws the destructive card with no typed name, and Confirm lowers Locks', async () => {
  // Mutation (Rule 19): remove the screen-permission arm from `Prohibited.WeakensByEffect` -> the card draws
  // plain and the destructive and consequence assertions go red.
  const { context, page, tag } = await withLiveCard('agent_screenpermissions_removepair', LOWERED_PAIR, 'let more accounts open Locks');
  try {
    const drawn = await readCard(page);
    assert.equal(drawn.destructiveCard, true, 'the card draws its left-edge bar destructive');
    assert.equal(drawn.destructiveConfirm, true, 'and Confirm takes the destructive treatment');
    assert.equal(drawn.typedName, false, 'with no typed-name field');
    assert.equal(drawn.confirmDisabled, null, 'so Confirm is pressable');
    assert.ok(
      drawn.diff.some((row) => row.startsWith('Pairs') && row.includes(LOWERED_PAIR)),
      `the Pairs row shows the set before: ${JSON.stringify(drawn.diff)}`
    );
    assert.ok(drawn.requires.includes(REQUIRES), `the requires line names the either-of: ${drawn.requires}`);
    assert.equal(drawn.consequence, STRINGS.screenPermissionsLowerConsequence, 'and the lowering sentence is stated');
    assert.equal(storedAdjustment(), '', 'nothing is stored before Confirm');

    await page.click('.ocu-proposal-card-confirm');
    await page.waitForSelector('app-proposal-card .ocu-proposal-card-status', { timeout: config.navigationTimeoutMs });
    assert.equal(storedAdjustment(), '%Admin_Operate:USE', 'Confirm stores the lowered set');
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
  }
});

test('AC1: an add-pair draws a card that is not destructive, and Confirm raises Locks', async () => {
  // Mutation (Rule 19): make `Prohibited.LowersScreenPermission` answer 1 -> the card draws destructive and
  // the first assertion goes red.
  const { context, page, tag } = await withLiveCard('agent_screenpermissions_addpair', RAISED_PAIR, 'require %Admin_Secure:USE for Locks');
  try {
    const drawn = await readCard(page);
    assert.equal(drawn.destructiveCard, false, 'the card is not destructive');
    assert.equal(drawn.destructiveConfirm, false, 'and neither is Confirm');
    assert.equal(drawn.consequence, '', 'it states no consequence');
    assert.ok(
      drawn.diff.some((row) => row.startsWith('Pairs') && row.includes(RAISED_PAIR)),
      `the Pairs row shows the set after: ${JSON.stringify(drawn.diff)}`
    );
    assert.ok(drawn.requires.includes(REQUIRES), `the requires line names the either-of: ${drawn.requires}`);

    await page.click('.ocu-proposal-card-confirm');
    await page.waitForSelector('app-proposal-card .ocu-proposal-card-status', { timeout: config.navigationTimeoutMs });
    assert.ok(storedAdjustment().split(',').includes(RAISED_PAIR), 'Confirm stores the raised set');
  } finally {
    await context.close();
    forgetTag(tag);
    dropProposals();
  }
});

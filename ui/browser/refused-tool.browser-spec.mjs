/**
 * A privilege refusal as a user sees it, in a real browser against the throwaway (Story 5.4, AC2).
 *
 * A **real least-privileged principal** -- created inside the container through
 * `OcuPilot.Test.TurnWireFixture`, holding read on the install namespace's databases,
 * `%Ens_Credentials:READ` and `%Admin_Operate:USE`, and nothing else -- runs a scripted turn whose
 * model calls a tool that requires `%Admin_Secure:USE`. The card's status word has to name that
 * pair: AD-8's "a denial names the pair that failed, so the UX can say which privilege is
 * missing".
 *
 * **Why a browser and not jsdom.** `tool-call-card.spec.ts` pins the component's own mapping
 * against a hand-built step. What is only observable here is the whole path: the instance's real
 * `$SYSTEM.Security.CheckUserPermission` refusing this principal, the pair travelling on the
 * progress poll, and the deployed bundle rendering it. A mutation to the card proves nothing until
 * the bundle is rebuilt and redeployed (`.claude/rules/objectscript-testing.md`).
 *
 * **No second call.** OcuPilot cannot stop a model from asking again; what it guarantees is that
 * no second path exists. The script arms exactly one tool call and one reply, and the spec asserts
 * the turn made exactly the two provider calls that implies -- a fallback attempt would be a third.
 *
 * Run: `npm run build`, `docker cp` the bundle into the throwaway, then `npm run test:browser`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import {
  armProbeDefinition,
  disarmProbeDefinition,
  escapeOs,
  forgetTag,
  markerValue,
  nextTag,
  runIris,
  scriptReply,
  setTag,
} from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const probe = { container: config.container, marker: 'REFUSED' };

const HOME_URL = '/ocupilot/?ns=HSCUSTOM';

/** The tool the principal may not call, and the pair the instance refuses it at. */
const REFUSED_TOOL = 'webapp_restapis_read';
const REFUSED_PAIR = '%Admin_Secure:USE';

const password = `OcuPilotRefused${randomBytes(12).toString('hex')}Aa9`;
let browser = null;
let user = '';
let preparedId = '';
let priorDefault = '';

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates a principal and arms the turnprobe provider, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);

  const output = runIris(config.container, [
    'Set tUser=##class(OcuPilot.Test.TurnWireFixture).#USERA',
    `Set tSC=##class(OcuPilot.Test.TurnWireFixture).EnsurePrincipal(tUser,"${escapeOs(password)}",##class(OcuPilot.Test.TurnWireFixture).Resources(1))`,
    'Write "OCU-REFUSED-USER-START:"_$System.Status.IsOK(tSC)_"|"_tUser_":OCU-REFUSED-USER-END",!',
  ]);
  const created = markerValue(output, 'REFUSED-USER');
  assert.ok(created, `EnsurePrincipal answered: ${output}`);
  const [ok, name] = created.split('|');
  assert.equal(ok, '1', `the fixture created the principal: ${output}`);
  user = name;

  // The principal really is refused this pair on the instance, read from the instance rather
  // than inferred from the role's resource list. Without this the refusal below could be a
  // principal that was never granted anything at all, or a tool that never gates.
  const held = runIris(config.container, [
    `Write "OCU-REFUSED-HELD-START:"_$SYSTEM.Security.CheckUserPermission("${escapeOs(user)}","%Admin_Secure","USE")_"|"_$SYSTEM.Security.CheckUserPermission("${escapeOs(user)}","%Admin_Operate","USE")_":OCU-REFUSED-HELD-END",!`,
  ]);
  assert.equal(markerValue(held, 'REFUSED-HELD'), '0|1', `the principal holds %Admin_Operate and not %Admin_Secure: ${held}`);

  browser = await puppeteer.launch(launchOptions(config));
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  disarmProbeDefinition(probe, priorDefault);
  const removed = runIris(config.container, [
    'Write "OCU-REFUSED-LEFT-START:"_##class(OcuPilot.Test.TurnWireFixture).RemovePrincipals()_":OCU-REFUSED-LEFT-END",!',
  ]);
  assert.equal(markerValue(removed, 'REFUSED-LEFT'), '', `the probe principal and its role are gone: ${removed}`);
});

/** How many provider calls `tag` has answered. */
function callCount(tag) {
  const output = runIris(config.container, [
    `Write "OCU-REFUSED-CALLS-START:"_##class(OcuPilot.Test.TurnProvider).Calls("${escapeOs(tag)}")_":OCU-REFUSED-CALLS-END",!`,
  ]);
  return Number(markerValue(output, 'REFUSED-CALLS') ?? -1);
}

test('AC2: a tool the principal may not call renders a card naming the pair, and no second call is issued', async () => {
  // Mutation (Rule 19): make `tool-call-card.ts` resolve the `<reason>` slot with `step.reason`
  // again, rebuild and redeploy -> the status word reads the generic sentence and this goes red.
  const tag = nextTag(probe);
  setTag(probe, preparedId, tag);
  scriptReply(probe, tag, 0, `##class(OcuPilot.Test.TurnProvider).ToolUseReply("${escapeOs(REFUSED_TOOL)}")`);
  scriptReply(probe, tag, 0, '##class(OcuPilot.Test.TurnProvider).TextReply("I could not read that.")');

  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  await page.setViewport(config.viewport);
  try {
    await page.goto(`${config.origin}${HOME_URL}`, { waitUntil: 'networkidle2' });
    await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
    await page.type('#ocu-signin-user', user);
    await page.type('#ocu-signin-password', password);
    await page.click('.ocu-signin-card button[type="submit"]');
    await page.waitForSelector('app-panel aside.ocu-panel', { timeout: config.navigationTimeoutMs });
    await leaveFirstLoginGate(page, config.navigationTimeoutMs, HOME_URL);
    await page.waitForFunction(() => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'), {
      timeout: config.navigationTimeoutMs,
    });

    await page.type('#ocu-panel-composer', 'list the rest apis');
    await page.click('.ocu-panel-send');

    await page.waitForFunction(
      () => document.querySelector('.ocu-tool-call-status-warning') !== null,
      { timeout: config.navigationTimeoutMs }
    );
    const seen = await page.evaluate(() => ({
      status: document.querySelector('.ocu-tool-call-status-warning')?.textContent?.trim() ?? '',
      cards: document.querySelectorAll('.ocu-tool-call-card').length,
      name: document.querySelector('.ocu-tool-call-name')?.textContent?.trim() ?? '',
    }));

    assert.equal(
      seen.status,
      STRINGS.toolCallStatusFailed.split('<reason>').join(REFUSED_PAIR),
      'the card names the pair the caller has to be granted'
    );
    assert.ok(seen.status.includes(REFUSED_PAIR), `the pair itself is on screen: ${seen.status}`);
    assert.equal(seen.cards, 1, 'one card for one refused call');
    assert.ok(seen.name.length > 0, 'and the card names the tool it refused');

    // Exactly the two scripted calls: the one that asked for the tool, and the one that answered
    // the refusal. A third would be OcuPilot retrying the refused call by another path.
    assert.equal(callCount(tag), 2, 'the turn made two provider calls, so no refused call was retried');
  } finally {
    await context.close();
    forgetTag(probe, tag);
  }
});

/**
 * The proposal card's privilege line in a real browser, against the throwaway (Story 11.8, AD-8).
 *
 * The proposal is a real one: the armed `turnprobe` row answers a `tool_use` for the shipped
 * `webapp.list.update` tool, the instance mints it and records the pair set its gate resolves, and
 * the panel renders what the progress poll carries. The second provider call hangs, so the panel
 * keeps polling while the test changes what the signed-in user holds.
 *
 * (b) signs in as a **real least-privileged principal** (`OcuPilot.Test.TurnWireFixture`) whose
 * role holds the tool's pairs and what OcuPilot itself needs, then takes `%Admin_Secure` away: the
 * next poll's line is the warning, Confirm stays offered, and the instance refuses it naming the
 * pair.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test
 * browser/proposal-privilege.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { signedInAt } from './panel-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';
import {
  abandonTurns,
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
const probe = { container: config.container, marker: 'PRIVLINE' };
const STRINGS = loadStrings();

const HOME_URL = '/ocupilot/?ns=HSCUSTOM';

/** The demo fixture's own web application, which a clean throwaway always serves (AD-25). */
const TARGET = '/csp/myapp';

const TOOL_WIRE_NAME = 'webapp_list_update';

/** The pair (b) takes away, and the resource spelling a role grants it with. */
const REVOKED_PAIR = '%Admin_Secure:USE';

/** The tool's own pairs as a role grants them, beside what OcuPilot needs (`Resources(1)`). */
const TOOL_GRANTS = ',%Admin_Secure:U,%DB_IRISSYS:R';
const TOOL_GRANTS_REVOKED = ',%DB_IRISSYS:R';

/** How long the panel has to show the revoked line once the role changes. */
const REVOKE_WINDOW_MS = 5000;

const password = `OcuPilotPrivLine${randomBytes(12).toString('hex')}Aa9`;
let browser = null;
let preparedId = '';
let priorDefault = '';
let user = '';
let baseResources = '';

before(async () => {
  assert.notEqual(
    config.container,
    LIVE_CONTAINER,
    'this spec creates a principal, arms the turnprobe provider and mints proposals, so it never runs inside the live container'
  );
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);

  const resources = runIris([
    'Write "OCU-PRIVLINE-RES-START:"_##class(OcuPilot.Test.TurnWireFixture).Resources(1)_":OCU-PRIVLINE-RES-END",!',
  ]);
  baseResources = markerValue(resources, 'PRIVLINE-RES') ?? '';
  assert.ok(baseResources !== '', `the fixture resolved the principal's base resources: ${resources}`);
  const output = runIris([
    'Set tUser=##class(OcuPilot.Test.TurnWireFixture).#USERA',
    `Set tSC=##class(OcuPilot.Test.TurnWireFixture).EnsurePrincipal(tUser,"${escapeOs(password)}","${escapeOs(baseResources + TOOL_GRANTS)}")`,
    'Write "OCU-PRIVLINE-USER-START:"_$System.Status.IsOK(tSC)_"|"_tUser_":OCU-PRIVLINE-USER-END",!',
  ]);
  const created = markerValue(output, 'PRIVLINE-USER');
  assert.ok(created, `EnsurePrincipal answered: ${output}`);
  const [ok, name] = created.split('|');
  assert.equal(ok, '1', `the fixture created the principal: ${output}`);
  user = name;

  browser = await puppeteer.launch(launchOptions(config));
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
  allowWrites();
  dropProposals(config.username);
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  await requireFreeSlot(config).catch(() => {});
  if (user !== '') {
    await abandonTurns({ ...config, username: user, password }).catch(() => {});
    dropProposals(user);
  }
  dropProposals(config.username);
  disarmProbeDefinition(probe, priorDefault);
  const removed = runIris([
    'Write "OCU-PRIVLINE-LEFT-START:"_##class(OcuPilot.Test.TurnWireFixture).RemovePrincipals()_":OCU-PRIVLINE-LEFT-END",!',
  ]);
  assert.equal(markerValue(removed, 'PRIVLINE-LEFT'), '', `the probe principal and its role are gone: ${removed}`);
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
    `Write "OCU-PRIVLINE-RW-START:"_$System.Status.IsOK(sc)_":OCU-PRIVLINE-RW-END",!`,
  ]);
  assert.equal(markerValue(output, 'PRIVLINE-RW'), '1', `the probe definition allows writes: ${output}`);
}

function dropProposals(userName) {
  const output = runIris([
    `Set sc=##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForUser("${escapeOs(userName)}")`,
    `Write "OCU-PRIVLINE-DROP-START:"_$System.Status.IsOK(sc)_":OCU-PRIVLINE-DROP-END",!`,
  ]);
  assert.equal(markerValue(output, 'PRIVLINE-DROP'), '1', `the probe proposals are removed: ${output}`);
}

/** The `RequiredPairs` the instance stored on `userName`'s newest proposal. */
function storedPairs(userName) {
  const output = runIris([
    `Set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT TOP 1 RequiredPairs FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(UserName) = ? ORDER BY ID DESC","${escapeOs(userName)}")`,
    'Set v=$Select(rs.%Next():rs.%GetData(1),1:"")',
    'Write "OCU-PRIVLINE-PAIRS-START:"_v_":OCU-PRIVLINE-PAIRS-END",!',
  ]);
  return markerValue(output, 'PRIVLINE-PAIRS') ?? '';
}

function setRole(resources) {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.TurnWireFixture).SetRoleResources("${escapeOs(resources)}")`,
    `Write "OCU-PRIVLINE-ROLE-START:"_$System.Status.IsOK(sc)_":OCU-PRIVLINE-ROLE-END",!`,
  ]);
  assert.equal(markerValue(output, 'PRIVLINE-ROLE'), '1', `the probe role was changed: ${output}`);
}

function proposeReply() {
  const input = {
    Name: TARGET,
    Description: `Reviewed by the agent co-pilot at ${Date.now()}`,
    rationale: 'The application carries no description, so nobody can tell what it is for.',
    expectedImpact: 'the list names what the application is for',
    reverse: 'clear the description again',
  };
  return `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_priv", "name": "${TOOL_WIRE_NAME}", "input": ${JSON.stringify(input)}}])`;
}

function textReply(text) {
  return `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs(text)}")`;
}

/** Arm a turn that proposes, then hangs `hangSeconds` on its second call. */
function armProposal(hangSeconds) {
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 0, proposeReply());
  scriptReply(tag, hangSeconds, textReply('done'));
  return tag;
}

/** Send one message and wait for the live card's Confirm. */
async function sendAndAwaitCard(page) {
  await page.waitForFunction(
    () => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'),
    { timeout: config.navigationTimeoutMs }
  );
  await page.type('#ocu-panel-composer', 'give /csp/myapp a description');
  await page.click('.ocu-panel-send');
  await page.waitForSelector('app-proposal-card .ocu-proposal-card-confirm', { timeout: config.navigationTimeoutMs });
}

/** What the card's privilege line reads, whether it is the warning, and Confirm's aria-disabled. */
async function readLine(page) {
  return page.evaluate(() => {
    const line = document.querySelector('app-proposal-card [data-slot="privilege"]');
    const confirm = document.querySelector('app-proposal-card .ocu-proposal-card-confirm');
    return {
      present: line !== null,
      text: line?.querySelector('.ocu-banner-message')?.textContent?.trim() ?? line?.textContent?.trim() ?? '',
      warning: line?.classList.contains('ocu-banner-warning') ?? false,
      role: line?.getAttribute('role') ?? null,
      confirmDisabled: confirm?.getAttribute('aria-disabled') ?? null,
    };
  });
}

test('(a) the administrator sees every pair the gate requires, held, and Confirm is offered', async () => {
  // Mutation (Rule 19): make Mint record "" always, or drop `privilege` from `toCardView`, rebuild
  // and redeploy -> the line is absent and this goes red.
  await requireFreeSlot(config);
  const tag = armProposal(20);
  const { context, page } = await signedInAt(browser, config, HOME_URL);
  try {
    await sendAndAwaitCard(page);
    await page.waitForSelector('app-proposal-card [data-slot="privilege"]', { timeout: config.navigationTimeoutMs });
    const stored = storedPairs(config.username);
    assert.ok(stored.split(',').includes(REVOKED_PAIR), `the stored set names ${REVOKED_PAIR}: ${stored}`);
    const seen = await readLine(page);
    assert.equal(
      seen.text,
      STRINGS.privilegeProposalHeld.split('<resources>').join(stored.split(',').join(', ')),
      'the line names the stored set and says it is held'
    );
    assert.equal(seen.warning, false, 'a held line is not a warning');
    assert.equal(seen.confirmDisabled, null, 'and Confirm is offered');
  } finally {
    await context.close();
    forgetTag(tag);
  }
});

test('(b) a principal who loses a pair sees the warning within one poll, Confirm stays offered, and the instance refuses it by name', async () => {
  // Mutation (Rule 19): make Disclosure.Privilege answer missing "" always, or make
  // confirmAriaDisabled answer 'true' when a pair is missing -> this goes red.
  setRole(baseResources + TOOL_GRANTS);
  // The principal's own single turn slot (AD-41): an earlier run's hanging turn may still hold it.
  await requireFreeSlot({ ...config, username: user, password });
  const tag = armProposal(30);
  await resetRememberedState();
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
    await sendAndAwaitCard(page);
    await page.waitForSelector('app-proposal-card [data-slot="privilege"]', { timeout: config.navigationTimeoutMs });
    const held = await readLine(page);
    assert.equal(held.warning, false, `the principal holds the whole set at first: ${held.text}`);
    assert.ok(held.text.startsWith('Requires ') && held.text.includes(REVOKED_PAIR), `the held line names ${REVOKED_PAIR}: ${held.text}`);

    setRole(baseResources + TOOL_GRANTS_REVOKED);
    await page.waitForFunction(
      () => document.querySelector('app-proposal-card [data-slot="privilege"]')?.classList.contains('ocu-banner-warning') === true,
      { timeout: REVOKE_WINDOW_MS }
    );
    const revoked = await readLine(page);
    const stored = storedPairs(user);
    assert.equal(
      revoked.text,
      STRINGS.privilegeProposalMissing
        .split('<resources>')
        .join(stored.split(',').join(', '))
        .split('<resource>')
        .join(REVOKED_PAIR),
      `the warning names the stored set and ${REVOKED_PAIR}`
    );
    assert.equal(revoked.role, 'status', 'the warning is a status');
    assert.equal(revoked.confirmDisabled, null, 'and Confirm is still offered');

    await page.click('app-proposal-card .ocu-proposal-card-confirm');
    await page.waitForFunction(
      (pair) => [...document.querySelectorAll('.ocu-tool-call-status-warning')].some((node) => (node.textContent ?? '').includes(pair)),
      { timeout: config.navigationTimeoutMs },
      REVOKED_PAIR
    );
  } finally {
    await context.close();
    forgetTag(tag);
  }
});

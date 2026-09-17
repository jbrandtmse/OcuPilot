/**
 * The context chip, its toggle and the paste warning, in a real browser against the throwaway
 * instance (Story 4.11): chip text on the Users list, the egress pill and its tooltip, the key
 * glyph on the Definition form, the toggle surviving a reload, the paste warning's two buttons,
 * the Integration AC -- a sent turn's recorded provider messages carry the synthetic
 * `screen_context` pair naming the route, the namespace and exactly the rows the chip displayed --
 * and two legs the component suite could only approximate: the row cap following a real Switches
 * save with no reload -- which the bus wiring alone explains, so it is this file's pin for that
 * AC -- and a live 409 refusal (the AD-41 single-turn-slot conflict) leaving an acknowledged
 * paste warning un-re-armed, which is the observable behavior end to end but not a falsification
 * of `syncSecretRecord()`'s guard (see that test's own note).
 *
 * Uses the same `turnprobe` wire fixture `turn.browser-spec.mjs` drives
 * (`OcuPilot.Test.TurnWireFixture`): one definition, enabled and marked default, backed by
 * `OcuPilot.Test.TurnProvider`, which records every request it receives and can be read back
 * with `Recorded(tag, call, field)` -- the one way to observe what actually reached the provider
 * without trusting the client's own account of it.
 *
 * The per-user sharing choice (`GET/PUT /agent/context`) is server state keyed by the signed-in
 * user, not by browser context, so every test that changes it restores `share: true` before it
 * ends -- the default every other test in this file, and every other browser spec, assumes.
 *
 * Run: `npm run build` then `docker cp` the bundle into the throwaway, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test browser/context-chip.browser-spec.mjs`
 * (`.claude/rules/objectscript-testing.md`'s "a browser spec runs against the deployed bundle").
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';

const config = browserConfig();
const STRINGS = loadStrings();

const USERS_URL = '/ocupilot/permissions/users?ns=HSCUSTOM';
const FORM_URL = '/ocupilot/agent/definitions/edit?ns=HSCUSTOM';
const CONTEXT_PATH = '/api/ocupilot/agent/context';
const SWITCHES_PATH = '/api/ocupilot/agent/switches';
const TAG_PREFIX = 'chipbrowser';

let browser = null;
let tagCounter = 0;
let preparedId = '';
let priorDefault = '';

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec arms the turnprobe provider, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  browser = await puppeteer.launch(launchOptions(config));
  removeDefinition('');
  priorDefault = markedDefault();
  preparedId = ensureDefinition(nextTag());
  await putShare(true);
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  await putShare(true);
  removeDefinition(priorDefault);
});

function nextTag() {
  tagCounter += 1;
  return `${TAG_PREFIX}${tagCounter}`;
}

function escapeOs(value) {
  return String(value).replace(/"/g, '""');
}

function runIris(lines) {
  const script = [
    'Set $NAMESPACE=$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"):"HSCUSTOM",1:"USER")',
    ...lines,
    'Halt',
  ].join('\n');
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', '%SYS'], {
    input: `${script}\n`,
    encoding: 'utf8',
    timeout: 600000,
  });
  return `${result.stdout ?? ''}${result.stderr ?? ''}`;
}

function markerValue(output, marker) {
  const re = new RegExp(`${marker}-START:(.*?):${marker}-END`);
  return re.exec(output)?.[1] ?? null;
}

/**
 * The id currently carrying the default marker, or `''`. Read through the marker convention like
 * every other value here: `runIris` answers the whole IRIS session transcript, so a bare `Write`
 * yields the banner and the prompts as well -- and a multi-line value embedded in the next
 * script's string literal breaks that script instead of failing loudly.
 */
function markedDefault() {
  const output = runIris([
    'Write "OCUCHIP-PRIOR-START:"_##class(OcuPilot.Test.TurnWireFixture).MarkedDefault()_":OCUCHIP-PRIOR-END",!',
  ]);
  const value = markerValue(output, 'OCUCHIP-PRIOR');
  assert.notEqual(value, null, `MarkedDefault answered: ${output}`);
  return value;
}

/**
 * Remove every probe definition and restore `prior` as the default marker, asserting that none
 * survived. The assertion is the point: a leftover enabled, default-marked definition is
 * instance-wide state that changes what later specs see -- `switches.browser-spec.mjs`'s AC2
 * reads the panel's read-only line on the stated assumption that nothing is configured -- and a
 * cleanup whose status nobody reads is how that reaches them.
 */
function removeDefinition(prior) {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.TurnWireFixture).RemoveDefinition("${escapeOs(prior)}")`,
    'Write "OCUCHIP-RM-START:"_$System.Status.IsOK(sc)_":OCUCHIP-RM-END",!',
  ]);
  assert.equal(markerValue(output, 'OCUCHIP-RM'), '1', `RemoveDefinition succeeded: ${output}`);
}

function ensureDefinition(tag) {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.TurnWireFixture).EnsureDefinition("${escapeOs(tag)}",.id)`,
    'Write "OCUCHIP-DEF-START:"_$System.Status.IsOK(sc)_"|"_id_":OCUCHIP-DEF-END",!',
  ]);
  const value = markerValue(output, 'OCUCHIP-DEF');
  assert.ok(value, `EnsureDefinition answered: ${output}`);
  const [ok, id] = value.split('|');
  assert.equal(ok, '1', `EnsureDefinition succeeded: ${output}`);
  return id;
}

function setTag(tag) {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.TurnWireFixture).SetTag("${escapeOs(preparedId)}","${escapeOs(tag)}")`,
    'Write "OCUCHIP-TAG-START:"_$System.Status.IsOK(sc)_":OCUCHIP-TAG-END",!',
  ]);
  assert.equal(markerValue(output, 'OCUCHIP-TAG'), '1', `SetTag succeeded: ${output}`);
}

function scriptReply(tag, hangSeconds, bodyExpr) {
  const output = runIris([
    `Do ##class(OcuPilot.Test.TurnProvider).Script("${escapeOs(tag)}",${hangSeconds},${bodyExpr})`,
    'Write "OCUCHIP-SCRIPT-START:ok:OCUCHIP-SCRIPT-END",!',
  ]);
  assert.ok(markerValue(output, 'OCUCHIP-SCRIPT'), `Script recorded: ${output}`);
}

function textReply(text) {
  return `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs(text)}")`;
}

function forgetTag(tag) {
  runIris([`Do ##class(OcuPilot.Test.TurnProvider).Forget("${escapeOs(tag)}")`]);
}

/** Call `call`'s recorded `messages` array (JSON), the same shape a real Anthropic-style request carries. */
function recordedMessages(tag, call = 1) {
  const output = runIris([
    `Write "OCUCHIP-MSGS-START:"_##class(OcuPilot.Test.TurnProvider).Recorded("${escapeOs(tag)}",${call},"messages")_":OCUCHIP-MSGS-END",!`,
  ]);
  const value = markerValue(output, 'OCUCHIP-MSGS');
  assert.ok(value, `Recorded answered: ${output}`);
  return JSON.parse(value);
}

/**
 * The `screen_context` payload from a recorded `messages` array (Anthropic wire shape: each
 * message's `content` is an array of blocks), or `null` when none is present.
 */
function screenContextPayload(messages) {
  const useIndex = messages.findIndex(
    (entry) =>
      entry.role === 'assistant' &&
      Array.isArray(entry.content) &&
      entry.content.some((block) => block.type === 'tool_use' && block.name === 'screen_context')
  );
  if (useIndex < 0) return null;
  const resultEntry = messages[useIndex + 1];
  if (resultEntry?.role !== 'user' || !Array.isArray(resultEntry.content)) return null;
  const resultBlock = resultEntry.content.find((block) => block.type === 'tool_result');
  if (!resultBlock) return null;
  return JSON.parse(resultBlock.content);
}

function authHeader() {
  return 'Basic ' + Buffer.from(`${config.username}:${config.password}`).toString('base64');
}

async function putShare(share) {
  const answer = await fetch(`${config.origin}${CONTEXT_PATH}`, {
    method: 'PUT',
    headers: { Authorization: authHeader(), 'Content-Type': 'application/json' },
    body: JSON.stringify({ share }),
  });
  assert.ok(answer.ok, `PUT /agent/context {share:${share}} (HTTP ${answer.status})`);
}

/** Writes only `contextRowCap` -- `/agent/switches` patches the fields supplied, per
 * `switches.browser-spec.mjs`'s own partial `setSwitches` calls. */
async function putContextRowCap(cap) {
  const answer = await fetch(`${config.origin}${SWITCHES_PATH}`, {
    method: 'PUT',
    headers: { Authorization: authHeader(), 'Content-Type': 'application/json' },
    body: JSON.stringify({ contextRowCap: cap }),
  });
  assert.ok(answer.ok, `PUT /agent/switches {contextRowCap:${cap}} (HTTP ${answer.status})`);
}

/** Click a rail item, then the named side-bar entry it reveals -- both agent's and permissions'
 * areas declare `"navigates": false`, so neither auto-selects a screen on the rail click alone
 * (the same two-step pattern `context-chip.browser-spec.mjs`'s "Fresh at Send" test already
 * uses for os-management/Processes). The entry itself is clicked through Puppeteer's own
 * `page.click` (a real simulated pointer event) rather than an in-page `element.click()`: the
 * synthetic call was observed to leave `Router.navigateByUrl` never invoked when the click
 * landed right after a Switches save, where the real click reliably navigates. */
async function navigateViaSideBar(page, railItemId, sideBarLabel) {
  await page.click(railItemId);
  await page.waitForFunction(
    (label) => [...document.querySelectorAll('.ocu-side-bar-item')].some((el) => el.textContent.includes(label)),
    { timeout: config.navigationTimeoutMs },
    sideBarLabel
  );
  const index = await page.evaluate((label) => {
    return [...document.querySelectorAll('.ocu-side-bar-item')].findIndex((el) => el.textContent.includes(label));
  }, sideBarLabel);
  assert.ok(index >= 0, `a side-bar entry named "${sideBarLabel}" exists`);
  await page.click(`.ocu-side-bar-item:nth-of-type(${index + 1})`);
}

/** A fresh context signed in as the configured user, standing on `url` with the panel laid out. */
async function signedInAt(url) {
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  await page.setViewport(config.viewport);
  await page.goto(`${config.origin}${url}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', config.username);
  await page.type('#ocu-signin-password', config.password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-panel aside.ocu-panel', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, url);
  await page.waitForFunction(() => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'), {
    timeout: config.navigationTimeoutMs,
  });
  return { context, page };
}

async function typeAndSend(page, text) {
  await page.type('#ocu-panel-composer', text);
  await page.click('.ocu-panel-send');
}

function chipState(page) {
  return page.evaluate(() => {
    const chip = document.querySelector('.ocu-context-chip');
    if (chip === null) return null;
    return {
      text: chip.querySelector('.ocu-context-chip-text')?.textContent ?? '',
      pill: chip.querySelector('.ocu-context-chip-pill')?.textContent?.trim() ?? null,
      pillTitle: chip.querySelector('.ocu-context-chip-pill')?.getAttribute('title') ?? null,
      glyph: chip.querySelector('.ocu-context-chip-glyph') !== null,
      switchChecked: chip.querySelector('.ocu-context-chip-switch')?.checked ?? null,
    };
  });
}

test('List screen, remote provider: the chip carries the row count, provider and host, with the egress pill and its tooltip', async () => {
  const { context, page } = await signedInAt(USERS_URL);
  try {
    await page.waitForFunction(() => (document.querySelector('.ocu-context-chip-text')?.textContent ?? '').includes('rows'), {
      timeout: config.navigationTimeoutMs,
    });
    const state = await chipState(page);
    assert.match(state.text, /^Users, HSCUSTOM \u00b7 \d+ rows \u00b7 turnprobe \u00b7 192\.0\.2\.10/);
    assert.equal(state.pill, STRINGS.contextChipLeavesInstance);
    assert.equal(state.pillTitle, STRINGS.contextChipSentToHost.split('<host>').join('192.0.2.10'));
    assert.equal(state.glyph, false);
    assert.equal(state.switchChecked, true);
  } finally {
    await context.close();
  }
});

test('Secret-typed screen: the key glyph is present and no row segment appears', async () => {
  const { context, page } = await signedInAt(FORM_URL);
  try {
    await page.waitForSelector('.ocu-context-chip', { timeout: config.navigationTimeoutMs });
    const state = await chipState(page);
    assert.equal(state.glyph, true);
    assert.doesNotMatch(state.text, /rows/);
    const glyphName = await page.evaluate(
      () => document.querySelector('.ocu-context-chip-glyph + .ocu-visually-hidden')?.textContent ?? ''
    );
    assert.equal(glyphName, STRINGS.agentContextChipSecretGlyph);
  } finally {
    await context.close();
  }
});

test('Toggle off survives a reload: the chip reads the sharing-off sentence both before and after', async () => {
  const { context, page } = await signedInAt(USERS_URL);
  try {
    await page.waitForSelector('.ocu-context-chip-switch', { timeout: config.navigationTimeoutMs });
    await page.click('.ocu-context-chip-switch');
    await page.waitForFunction(
      (expected) => (document.querySelector('.ocu-context-chip-text')?.textContent ?? '').trim() === expected,
      { timeout: config.navigationTimeoutMs },
      STRINGS.contextChipSharingOff
    );
    await page.reload({ waitUntil: 'networkidle2' });
    await page.waitForSelector('app-panel aside.ocu-panel', { timeout: config.navigationTimeoutMs });
    await page.waitForFunction(
      (expected) => (document.querySelector('.ocu-context-chip-text')?.textContent ?? '').trim() === expected,
      { timeout: config.navigationTimeoutMs },
      STRINGS.contextChipSharingOff
    );
    const switchChecked = await page.evaluate(() => document.querySelector('.ocu-context-chip-switch').checked);
    assert.equal(switchChecked, false, 'the per-user choice was re-read from the instance, not remembered locally');
  } finally {
    await context.close();
    await putShare(true);
  }
});

test("the paste warning's two buttons: Send anyway sends the exact text; Edit refocuses without recording", async () => {
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 0, textReply('acknowledged'));
  const { context, page } = await signedInAt(USERS_URL);
  const secret = 'sk-ant-api03-abcdefghijklmnopqrstuvwxyz';
  try {
    await page.type('#ocu-panel-composer', secret);
    await page.click('.ocu-panel-send');
    await page.waitForSelector('.ocu-panel-warning[role="status"]', { timeout: config.navigationTimeoutMs });

    await page.click('.ocu-panel-warning-edit');
    await page.waitForFunction(() => document.querySelector('.ocu-panel-warning') === null, {
      timeout: config.navigationTimeoutMs,
    });
    const focusedComposer = await page.evaluate(() => document.activeElement.id === 'ocu-panel-composer');
    assert.ok(focusedComposer, 'Edit returned focus to the composer');

    await page.click('.ocu-panel-send');
    await page.waitForSelector('.ocu-panel-warning[role="status"]', { timeout: config.navigationTimeoutMs });
    await page.click('.ocu-panel-warning-send');
    await page.waitForFunction(() => document.querySelector('.ocu-panel-warning') === null, {
      timeout: config.navigationTimeoutMs,
    });
    await page.waitForFunction(
      () => (document.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '') === 'acknowledged',
      { timeout: config.navigationTimeoutMs }
    );
    const sentMessage = await page.evaluate(() => document.querySelector('.ocu-panel-message-user')?.textContent ?? '');
    assert.equal(sentMessage, secret, 'the exact acknowledged text was sent');
  } finally {
    await context.close();
    forgetTag(tag);
  }
});

test('Integration AC: a sent turn carries the synthetic screen_context pair naming the route, the namespace and the rows the chip displayed', async () => {
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 0, textReply('read the users'));
  const { context, page } = await signedInAt(USERS_URL);
  try {
    await page.waitForFunction(() => (document.querySelector('.ocu-context-chip-text')?.textContent ?? '').includes('rows'), {
      timeout: config.navigationTimeoutMs,
    });
    const rowsShown = await page.evaluate(() => {
      const match = /(\d+) rows/.exec(document.querySelector('.ocu-context-chip-text').textContent);
      return match ? Number(match[1]) : null;
    });
    assert.ok(Number.isInteger(rowsShown), 'the chip showed a row count');

    await typeAndSend(page, 'who are the users');
    await page.waitForFunction(
      () => (document.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '') === 'read the users',
      { timeout: config.navigationTimeoutMs }
    );

    const payload = screenContextPayload(recordedMessages(tag, 1));
    assert.ok(payload, 'a screen_context tool_use/tool_result pair was recorded');
    assert.equal(payload.route, 'permissions/users');
    assert.equal(payload.namespace, 'HSCUSTOM');
    assert.equal(payload.rows.length, rowsShown, 'exactly the rows the chip displayed');
  } finally {
    await context.close();
    forgetTag(tag);
  }
});

test('Fresh at Send: context is assembled at the moment of the click, not cached from an earlier screen', async () => {
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 0, textReply('first'));
  scriptReply(tag, 0, textReply('second'));
  const { context, page } = await signedInAt(USERS_URL);
  try {
    await page.waitForFunction(() => (document.querySelector('.ocu-context-chip-text')?.textContent ?? '').includes('rows'), {
      timeout: config.navigationTimeoutMs,
    });
    await typeAndSend(page, 'first turn, on Users');
    await page.waitForFunction(
      () => (document.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '') === 'first',
      { timeout: config.navigationTimeoutMs }
    );

    // A real in-app navigation (the rail then the side bar, client-side routed), not a page
    // reload -- the AC is about the screen the user moved to inside the running shell. Only
    // Home's rail item navigates directly; every other area opens its side bar first.
    await page.click('#ocu-rail-item-os-management');
    // `.ocu-side-bar-item` can already exist for the PREVIOUS area (Users' own single entry), so
    // waiting for the selector alone can resolve before the side bar has actually swapped to this
    // area's -- wait for the specific text instead.
    await page.waitForFunction(
      () => [...document.querySelectorAll('.ocu-side-bar-item')].some((el) => el.textContent.includes('Processes')),
      { timeout: config.navigationTimeoutMs }
    );
    await page.evaluate(() => {
      const item = [...document.querySelectorAll('.ocu-side-bar-item')].find((el) =>
        el.textContent.includes('Processes')
      );
      item?.click();
    });
    await page.waitForFunction(
      () => (document.querySelector('.ocu-context-chip-text')?.textContent ?? '').startsWith('Processes'),
      { timeout: config.navigationTimeoutMs }
    );
    await typeAndSend(page, 'second turn, on Processes');
    // The SAME conversation now holds two turns, so two `.ocu-panel-message-agent-text`
    // paragraphs exist -- the last one is this turn's.
    await page.waitForFunction(
      () => {
        const replies = document.querySelectorAll('.ocu-panel-message-agent-text');
        return replies[replies.length - 1]?.textContent === 'second';
      },
      { timeout: config.navigationTimeoutMs }
    );

    const payload = screenContextPayload(recordedMessages(tag, 2));
    assert.ok(payload, 'a screen_context pair was recorded for the second turn');
    assert.equal(
      payload.route,
      'os-management/processes',
      "the second turn's context names the second screen, not the first"
    );
  } finally {
    await context.close();
    forgetTag(tag);
  }
});

test('Cap follows agent-switch: raising the row cap through the Switches screen updates the mounted chip and the next Send, with no reload', async () => {
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 0, textReply('counted'));
  // `contextRowCap` is instance-wide, so the lowering and the sign-in both sit inside the `try`:
  // a throw between them would otherwise leave every later spec in this run reading a cap of 1.
  let context = null;
  let page = null;
  try {
    await putContextRowCap(1);
    ({ context, page } = await signedInAt(USERS_URL));
    // The row segment is a middle segment, not the last one (provider and host follow it), so
    // this reads the count out rather than matching against the end of the string.
    await page.waitForFunction(
      () => {
        const match = /(\d+) rows/.exec(document.querySelector('.ocu-context-chip-text')?.textContent ?? '');
        return match !== null && Number(match[1]) === 1;
      },
      { timeout: config.navigationTimeoutMs }
    );

    // The whole leg stays on this one document: an in-app navigation to Switches, raising the
    // cap and Save -- `switches.store.ts` publishes `agent-switch` on the one client bus (AD-14)
    // in this same running app, which is what `AgentContext` re-reads on (Story 4.11), not a
    // page reload navigating back to Users would also explain away.
    await navigateViaSideBar(page, '#ocu-rail-item-agent', STRINGS.agentSwitchesLabel);
    await page.waitForSelector('#ocu-switches-contextRowCap', { visible: true, timeout: config.navigationTimeoutMs });
    await page.waitForFunction(() => document.querySelector('#ocu-switches-contextRowCap')?.value === '1', {
      timeout: config.navigationTimeoutMs,
    });
    await page.$eval('#ocu-switches-contextRowCap', (node) => {
      node.value = '200';
      node.dispatchEvent(new Event('input', { bubbles: true }));
    });
    await page.click('.ocu-form-bar-actions .ocu-button-primary');
    await page.waitForFunction(() => document.querySelector('#ocu-switches-contextRowCap')?.value === '200', {
      timeout: config.navigationTimeoutMs,
    });

    await navigateViaSideBar(page, '#ocu-rail-item-permissions', STRINGS.userListLabel);
    await page.waitForFunction(() => new URL(window.location.href).pathname === '/ocupilot/permissions/users', {
      timeout: config.navigationTimeoutMs,
    });
    // `1` was the pre-raise reading; anything higher proves the re-read actually landed on the
    // mounted chip rather than a value it happened to start with.
    await page.waitForFunction(
      () => {
        const match = /(\d+) rows/.exec(document.querySelector('.ocu-context-chip-text')?.textContent ?? '');
        return match !== null && Number(match[1]) > 1;
      },
      { timeout: config.navigationTimeoutMs }
    );
    const shownAfterRaise = await page.evaluate(() => {
      const match = /(\d+) rows/.exec(document.querySelector('.ocu-context-chip-text').textContent);
      return Number(match[1]);
    });

    await typeAndSend(page, 'how many users');
    await page.waitForFunction(
      () => (document.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '') === 'counted',
      { timeout: config.navigationTimeoutMs }
    );
    const payload = screenContextPayload(recordedMessages(tag, 1));
    assert.ok(payload, 'a screen_context pair was recorded');
    assert.equal(payload.route, 'permissions/users');
    assert.equal(payload.rows.length, shownAfterRaise, "the posted rows follow the raised cap, not the pre-raise one");
    assert.equal(payload.rowsAvailable, shownAfterRaise, 'the raised cap (200) is not below the real population');
  } finally {
    await context?.close();
    forgetTag(tag);
    await putContextRowCap(200);
  }
});

test('A failed send preserves the paste-warning acknowledgment: a live 409 (AD-41\'s one-turn-slot conflict) does not re-arm the warning', async () => {
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 15, textReply('done'));
  const secret = 'sk-ant-api03-abcdefghijklmnopqrstuvwxyz';
  // Both contexts open inside the `try`: the holder's 15-second scripted turn occupies this
  // user's one AD-41 turn slot, so a throw before the `finally` would hold that slot -- and leak
  // the browser context -- for whichever spec runs next.
  let holder = null;
  let context = null;
  let page = null;
  try {
    holder = await signedInAt(USERS_URL);
    ({ context, page } = await signedInAt(USERS_URL));
    // Occupy this user's one AD-41 turn slot for the whole leg below, from a second tab -- the
    // same live refusal `turn.browser-spec.mjs`'s "Second send" test drives, here used as the
    // "failed send" this story's follow-up risk names, not a stubbed/mocked failure.
    await typeAndSend(holder.page, 'holding the turn slot');
    await holder.page.waitForSelector('.ocu-panel-message-user', { timeout: config.navigationTimeoutMs });

    await page.type('#ocu-panel-composer', secret);
    await page.click('.ocu-panel-send');
    await page.waitForSelector('.ocu-panel-warning[role="status"]', { timeout: config.navigationTimeoutMs });

    // Send anyway: records the acknowledgment and attempts the send, which the instance refuses
    // 409 because the other tab still holds the slot -- a genuine network refusal, not a client
    // guess. The warning must clear (the attempt was made) and the draft must survive (nothing
    // was sent).
    await page.click('.ocu-panel-warning-send');
    await page.waitForSelector('[data-slot="lock"] .ocu-banner[role="status"]', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$('.ocu-panel-warning'), null, 'the warning cleared once the attempt was made');
    const composerValue = await page.evaluate(() => document.querySelector('#ocu-panel-composer').value);
    assert.equal(composerValue, secret, 'the failed send kept the draft');

    // The immediate retry of the identical, still-acknowledged text must not re-raise the
    // warning. What this leg proves live is that observable behavior end to end: a real 409, a
    // kept draft, a cleared warning and a silent retry. It does NOT falsify
    // `syncSecretRecord()`'s transition guard -- `TurnStore.send()` creates the conversation
    // before it posts the turn, so `conversationId()` is non-null throughout, and the guard's
    // `current === null` leg is false here either way. That guard's pin is the component test
    // "a failed send preserves the paste-warning acknowledgment" in `panel.spec.ts`, which
    // drives the conversation POST to a 500 and so leaves the id null.
    await page.click('.ocu-panel-send');
    await new Promise((resolve) => setTimeout(resolve, 500));
    assert.equal(await page.$('.ocu-panel-warning'), null, 'no warning on the retry: the acknowledgment was not forgotten');
  } finally {
    await context?.close();
    // The holder's turn keeps the AD-41 slot until it finishes; wait it out before closing, the
    // same discipline `turn.browser-spec.mjs`'s "Second send" test follows, so the slot is free
    // for whichever test runs next.
    await holder?.page
      .waitForFunction(() => (document.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '') === 'done', {
        timeout: config.navigationTimeoutMs,
      })
      .catch(() => {});
    await holder?.context.close();
    forgetTag(tag);
  }
});

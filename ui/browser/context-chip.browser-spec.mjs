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
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import {
  armProbeDefinition,
  disarmProbeDefinition,
  escapeOs,
  forgetTag as sharedForgetTag,
  markerValue,
  nextTag as sharedNextTag,
  runIris as sharedRunIris,
  scriptReply as sharedScriptReply,
  setTag as sharedSetTag,
} from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const probe = { container: config.container, marker: 'CHIP' };

const USERS_URL = '/ocupilot/permissions/users?ns=HSCUSTOM';
const FORM_URL = '/ocupilot/agent/definitions/edit?ns=HSCUSTOM';
const CONTEXT_PATH = '/api/ocupilot/agent/context';
const SWITCHES_PATH = '/api/ocupilot/agent/switches';

let browser = null;
let preparedId = '';
let priorDefault = '';

/** The slot every turn-arming test here competes for: one concurrent turn per user (AD-31, AD-41). */
const SLOT_GLOBAL = `^OcuPilotTurnSlot("${config.username}")`;
/** How long a turn left running by an earlier spec is given to end. */
const SLOT_FREE_TIMEOUT_MS = 15000;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec arms the turnprobe provider, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot();
  browser = await puppeteer.launch(launchOptions(config));
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
  await putShare(true);
});

after(async () => {
  try {
    try {
      if (config.container === LIVE_CONTAINER) return;
      // Hand the slot back before disarming, the same discipline navigate.browser-spec.mjs's
      // requireFreeSlot follows (DW-1092, extended here per DW-1167): closing the browser context
      // does not end a server-side turn, so a leftover holder would fail whichever spec runs next
      // with a bare puppeteer timeout instead of a named cause.
      await requireFreeSlot();
    } finally {
      // DW-1048: both restorations run even when the slot assertion above throws -- the disarm
      // first, since an enabled definition and a probe `agentDefault` break every later spec's
      // `leaveFirstLoginGate`, while a share left false breaks only this file's own premise.
      if (config.container !== LIVE_CONTAINER) {
        disarmProbeDefinition(probe, priorDefault);
        await putShare(true);
      }
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

function runIris(lines) {
  return sharedRunIris(config.container, lines);
}

/**
 * Abandon every turn the configured user still has running, and answer how many were abandoned
 * (`-1` when the route itself did not answer) -- the same `POST /turn/abandon` route
 * `navigate.browser-spec.mjs`'s `requireFreeSlot` uses.
 */
async function abandonTurns() {
  try {
    const response = await fetch(`${config.origin}/api/ocupilot/turn/abandon`, {
      method: 'POST',
      headers: { Authorization: authHeader() },
    });
    if (!response.ok) return -1;
    return Number((await response.json()).abandoned ?? -1);
  } catch {
    return -1;
  }
}

/** Which process holds the configured user's turn slot this instant -- `''` while none does. */
function slotOwner() {
  const output = runIris([
    `Write "OCU-CHIP-SLOT-START:"_##class(OcuPilot.Test.TurnFixture).SlotOwner("${escapeOs(config.username)}")_":OCU-CHIP-SLOT-END",!`,
  ]);
  return markerValue(output, 'CHIP-SLOT') ?? '';
}

/**
 * Refuse to start (or finish) until the configured user's one turn slot is free, naming the
 * global, the holding pid and TURN.BUSY on failure rather than the bare 30 s puppeteer timeout a
 * taken slot would otherwise produce on this file's first Send. Copied from
 * navigate.browser-spec.mjs's requireFreeSlot (DW-1092) and applied here per DW-1167, since this
 * file also arms a turn probe and can be left holding the slot by whichever spec ran before it.
 */
async function requireFreeSlot() {
  const abandoned = await abandonTurns();
  const deadline = Date.now() + SLOT_FREE_TIMEOUT_MS;
  let owner = slotOwner();
  while (owner !== '' && Date.now() < deadline) {
    await new Promise((resolve) => setTimeout(resolve, 500));
    owner = slotOwner();
  }
  assert.equal(
    owner,
    '',
    `${SLOT_GLOBAL} is still held by pid ${owner} after abandoning ${abandoned} turn(s) and waiting ` +
      `${SLOT_FREE_TIMEOUT_MS} ms, so this file's first Send would be refused TURN.BUSY`
  );
}

/** One `turnprobe` tag per test, so a stale script from an earlier test cannot answer a later one. */
function nextTag() {
  return sharedNextTag(probe);
}

/** Point the current definition at a fresh tag, so this test's scripts cannot answer another's turn. */
function setTag(tag) {
  sharedSetTag(probe, preparedId, tag);
}

/** Script one scripted reply for `tag`: `hangSeconds` before answering, then `bodyExpr` (ObjectScript). */
function scriptReply(tag, hangSeconds, bodyExpr) {
  sharedScriptReply(probe, tag, hangSeconds, bodyExpr);
}

function textReply(text) {
  return `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs(text)}")`;
}

function forgetTag(tag) {
  sharedForgetTag(probe, tag);
}

/** Call `call`'s recorded `messages` array (JSON), the same shape a real Anthropic-style request carries. */
function recordedMessages(tag, call = 1) {
  const output = runIris([
    `Write "OCU-CHIP-MSGS-START:"_##class(OcuPilot.Test.TurnProvider).Recorded("${escapeOs(tag)}",${call},"messages")_":OCU-CHIP-MSGS-END",!`,
  ]);
  const value = markerValue(output, 'CHIP-MSGS');
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
  try {
    await page.waitForFunction(
      (label) => [...document.querySelectorAll('.ocu-side-bar-item')].some((el) => el.textContent.includes(label)),
      { timeout: config.navigationTimeoutMs },
      sideBarLabel
    );
  } catch (err) {
    const items = await page
      .evaluate(() => [...document.querySelectorAll('.ocu-side-bar-item')].map((el) => el.textContent.trim()))
      .catch(() => ['(side bar unreadable)']);
    throw new Error(
      `expected a side-bar entry named "${sideBarLabel}" after clicking ${railItemId}; the side bar held ${JSON.stringify(items)} (underlying: ${err.message})`
    );
  }
  const index = await page.evaluate((label) => {
    return [...document.querySelectorAll('.ocu-side-bar-item')].findIndex((el) => el.textContent.includes(label));
  }, sideBarLabel);
  assert.ok(index >= 0, `a side-bar entry named "${sideBarLabel}" exists`);
  await page.click(`.ocu-side-bar-item:nth-of-type(${index + 1})`);
}

/**
 * Run `page.waitForFunction(fn, ...args)` and, on timeout, replace puppeteer's bare
 * "Waiting failed: Nms exceeded" with a message naming what this wait wanted and what `diagnose`
 * found on the page instead -- the pattern `audit.browser-spec.mjs`'s `waitForCount` and
 * `waitForDisabled` already use, generalized here so this file's multi-step legs do not each
 * hand-roll the same try/catch.
 */
async function namedWaitForFunction(page, fn, args, wanted, diagnose) {
  try {
    await page.waitForFunction(fn, { timeout: config.navigationTimeoutMs }, ...args);
  } catch (err) {
    const detail = await diagnose(page).catch((e) => `(diagnosis failed: ${e.message})`);
    throw new Error(`expected ${wanted}; found ${detail} (underlying: ${err.message})`);
  }
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
    try {
      ({ context, page } = await signedInAt(USERS_URL));
    } catch (err) {
      // signedInAt's own waits (sign-in form, panel, first-login gate, an enabled composer) give
      // no indication which one failed on a slow container; name the leg instead of letting a
      // bare puppeteer timeout stand for all four.
      throw new Error(`sign-in at Users (row-cap leg) did not complete: ${err.message}`);
    }
    // The row segment is a middle segment, not the last one (provider and host follow it), so
    // this reads the count out rather than matching against the end of the string.
    await namedWaitForFunction(
      page,
      (low, high) => {
        const match = /(\d+) rows/.exec(document.querySelector('.ocu-context-chip-text')?.textContent ?? '');
        return match !== null && Number(match[1]) >= low && Number(match[1]) <= high;
      },
      [1, 1],
      'the chip to read "1 rows" (the lowered cap, pre-raise)',
      (p) => p.evaluate(() => document.querySelector('.ocu-context-chip-text')?.textContent ?? '(chip absent)')
    );

    // The whole leg stays on this one document: an in-app navigation to Switches, raising the
    // cap and Save -- `switches.store.ts` publishes `agent-switch` on the one client bus (AD-14)
    // in this same running app, which is what `AgentContext` re-reads on (Story 4.11), not a
    // page reload navigating back to Users would also explain away.
    await navigateViaSideBar(page, '#ocu-rail-item-agent', STRINGS.agentSwitchesLabel);
    try {
      await page.waitForSelector('#ocu-switches-contextRowCap', { visible: true, timeout: config.navigationTimeoutMs });
    } catch (err) {
      throw new Error(
        'expected #ocu-switches-contextRowCap to render (visible) after navigating to Switches from ' +
          `the side bar; it never appeared (underlying: ${err.message})`
      );
    }
    await namedWaitForFunction(
      page,
      () => document.querySelector('#ocu-switches-contextRowCap')?.value === '1',
      [],
      '#ocu-switches-contextRowCap to read "1" once the Switches form has loaded its saved value',
      (p) => p.$eval('#ocu-switches-contextRowCap', (node) => node.value).catch(() => '(field absent)')
    );
    await page.$eval('#ocu-switches-contextRowCap', (node) => {
      node.value = '200';
      node.dispatchEvent(new Event('input', { bubbles: true }));
    });
    await page.click('.ocu-form-bar-actions .ocu-button-primary');
    await namedWaitForFunction(
      page,
      () => document.querySelector('#ocu-switches-contextRowCap')?.value === '200',
      [],
      '#ocu-switches-contextRowCap to read "200" after clicking Save',
      (p) => p.$eval('#ocu-switches-contextRowCap', (node) => node.value).catch(() => '(field absent)')
    );

    // This is the leg's most timing-sensitive step: navigateViaSideBar's own doc comment records
    // that a synthetic click landing right after a Switches save was once observed to leave
    // Router.navigateByUrl never invoked, where a real simulated pointer event (what this uses)
    // reliably navigates -- so a cold/slow CI host re-running that same click-right-after-Save
    // sequence is the most plausible loser of the six waits in this leg.
    await navigateViaSideBar(page, '#ocu-rail-item-permissions', STRINGS.userListLabel);
    await namedWaitForFunction(
      page,
      () => new URL(window.location.href).pathname === '/ocupilot/permissions/users',
      [],
      'the URL to land on /ocupilot/permissions/users after navigating back from Switches',
      (p) => p.evaluate(() => window.location.href)
    );
    // `1` was the pre-raise reading; anything higher proves the re-read actually landed on the
    // mounted chip rather than a value it happened to start with.
    await namedWaitForFunction(
      page,
      (low, high) => {
        const match = /(\d+) rows/.exec(document.querySelector('.ocu-context-chip-text')?.textContent ?? '');
        return match !== null && Number(match[1]) >= low && Number(match[1]) <= high;
      },
      [2, Number.MAX_SAFE_INTEGER],
      'the chip to re-read more than 1 row after navigating back (the agent-switch bus re-read landing)',
      (p) => p.evaluate(() => document.querySelector('.ocu-context-chip-text')?.textContent ?? '(chip absent)')
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

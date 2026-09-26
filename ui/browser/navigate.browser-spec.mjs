/**
 * The agent's navigation tool (`shell.screen.open`), driven through a real browser against the
 * throwaway instance (Story 4.7, AD-11 rule 3): the announcement renders before the browser
 * moves; the arrived screen's heading takes focus and carries
 * the published `aria-label`; Back restores the departing screen with its selection intact and
 * the announcement carries no undo button of its own; a dirty `form-page`'s decline leaves the
 * URL where it was and withdraws the announcement, with the recorded `tool_result` answering
 * `is_error` false; and the next turn's own screen context names the arrived route, never the
 * departed one (AC11).
 *
 * jsdom computes no layout, so focus and a real `history.pushState` timeline are only observable
 * here. Every test scripts its own `turnprobe` tag (`OcuPilot.Test.TurnProvider`) through
 * `turnprobe-spec.mjs` (**DW-1086**), the same fixture the other turn-shaped browser specs use.
 *
 * Run: `npm run build` then `docker cp` the bundle into the throwaway, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test browser/navigate.browser-spec.mjs`
 * (`.claude/rules/objectscript-testing.md`'s "a browser spec runs against the deployed bundle").
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { leaveFirstLoginGate, pathOf } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';
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
  requireFreeSlot as sharedRequireFreeSlot,
} from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const probe = { container: config.container, marker: 'NAV' };

const HOME_URL = '/ocupilot/?ns=HSCUSTOM';
const FORM_URL = '/ocupilot/agent/definitions/edit?ns=HSCUSTOM';

let browser = null;
let preparedId = '';
let priorDefault = '';

/** The slot every test here competes for: one concurrent turn per user (AD-31, AD-41). */
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
});

after(async () => {
  try {
    try {
      if (config.container === LIVE_CONTAINER) return;
      // Hand the slot back rather than leaving this file's tail running into whatever runs next:
      // closing a browser context does not end the server-side job. Asserted, not merely attempted --
      // an abandon whose result nothing reads passes the taken slot to the next spec silently, which
      // is the condition `requireFreeSlot` exists to name.
      await requireFreeSlot();
    } finally {
      // DW-1048: the disarm runs even when the slot assertion above throws. A held slot must not
      // also cost every later spec an enabled definition and a probe `agentDefault`, which is what
      // turns `leaveFirstLoginGate` into a no-op and reports this file's failure against innocent
      // ones.
      if (config.container !== LIVE_CONTAINER) disarmProbeDefinition(probe, priorDefault);
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

function runIris(lines) {
  return sharedRunIris(config.container, lines);
}

/** The Basic header the configured user authenticates the API with. */
function basicHeader() {
  return `Basic ${Buffer.from(`${config.username}:${config.password}`).toString('base64')}`;
}

/**
 * Abandon every turn the configured user still has running, and answer how many were abandoned
 * (`-1` when the route itself did not answer). This is the instance's own path, not a global
 * write: the same `POST /turn/abandon` the client calls at sign-out.
 */
async function abandonTurns() {
  try {
    const response = await fetch(`${config.origin}/api/ocupilot/turn/abandon`, {
      method: 'POST',
      headers: { Authorization: basicHeader() },
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
    `Write "OCU-NAV-SLOT-START:"_##class(OcuPilot.Test.TurnFixture).SlotOwner("${escapeOs(config.username)}")_":OCU-NAV-SLOT-END",!`,
  ]);
  return markerValue(output, 'NAV-SLOT') ?? '';
}

/**
 * Refuse to start until the configured user's one turn slot is free, and say so in a sentence
 * that names the cause.
 *
 * Every test here signs in as the same user, so it competes with whatever this suite ran before
 * it for the one slot AD-41 allows -- and a taken slot makes the first Send answer 409
 * `TURN.BUSY`, after which the composer never renders a reply and the test dies on a bare
 * 30-second puppeteer timeout that names none of this. So the slot is abandoned through the
 * instance's own route first, then polled, and a slot still held after
 * `SLOT_FREE_TIMEOUT_MS` fails here with the global, the holding pid and the code the Send
 * would otherwise have been refused with.
 */
async function requireFreeSlot() {
  await sharedRequireFreeSlot(config);
}

function nextTag() {
  return sharedNextTag(probe);
}

function setTag(tag) {
  sharedSetTag(probe, preparedId, tag);
}

function scriptReply(tag, hangSeconds, bodyExpr) {
  sharedScriptReply(probe, tag, hangSeconds, bodyExpr);
}

function forgetTag(tag) {
  sharedForgetTag(probe, tag);
}

function textReply(text) {
  return `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs(text)}")`;
}

/** A `tool_use` reply calling `shell.screen.open` with `route` and, when given, `entityId`. */
function navToolUse(route, entityId) {
  const input = entityId === undefined ? { route } : { route, entityId };
  return `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_nav", "name": "shell_screen_open", "input": ${JSON.stringify(input)}}])`;
}

/** Call `call`'s recorded `messages` array (JSON), the wire shape a real Anthropic request carries. */
function recordedMessages(tag, call) {
  const output = runIris([
    `Write "OCU-NAV-MSGS-START:"_##class(OcuPilot.Test.TurnProvider).Recorded("${escapeOs(tag)}",${call},"messages")_":OCU-NAV-MSGS-END",!`,
  ]);
  const value = markerValue(output, 'NAV-MSGS');
  assert.ok(value, `Recorded answered: ${output}`);
  return JSON.parse(value);
}

/** A fresh context signed in as the configured user, standing on `url` with the frame laid out. */
async function signedInAt(url) {
  // Story 15.5: the remembered screen and shell state lives on the instance now, keyed by the
  // one account every spec signs in as, so a fresh context is no longer a fresh slate on its
  // own -- see `preferences-reset.mjs`.
  await resetRememberedState();
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

/**
 * Wait for the turn's own final reply, exactly `turn.browser-spec.mjs`'s own note: every test in
 * this file signs in as the same configured user and so shares one AD-41 turn slot, and closing
 * the browser context does not end the server-side job. A test that stops watching once the URL
 * moves leaves its own tail (the settle POST, the final provider call) still running when the
 * next test's Send lands, which then answers 409 for a reason this file never touches.
 */
async function awaitReply(page, text) {
  // Scoped to `app-reply` specifically: the announcement paragraph carries the same
  // `.ocu-panel-message-agent-text` class (`panel.ts`'s own styling reuse) and renders first, so
  // a bare class selector would find it instead of the turn's own final reply. The LAST such
  // element, not the first: a second turn in the same conversation appends its own `app-reply`
  // after the first turn's, which a first-match `querySelector` would keep finding instead.
  await page.waitForFunction(
    (expected) => {
      const replies = document.querySelectorAll('app-reply.ocu-panel-message-agent-text');
      const last = replies[replies.length - 1];
      return (last?.textContent ?? '') === expected;
    },
    { timeout: config.navigationTimeoutMs },
    text
  );
}

/**
 * Wait for the announcement paragraph to name `screen`, naming what was wanted and what the panel
 * was actually showing when it does not -- `waitForFunction`'s own timeout says neither, and the
 * two things it is usually showing instead are a `TURN.BUSY` lock banner and a Send that was
 * refused before any message was appended.
 */
async function waitForAnnouncement(page, screen) {
  try {
    await page.waitForFunction(
      (wanted) => (document.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '').includes(wanted),
      { timeout: config.navigationTimeoutMs },
      screen
    );
  } catch (err) {
    const state = await page.evaluate(() => ({
      lockBanner: document.querySelector('[data-slot="lock"] .ocu-banner[role="status"]') !== null,
      userMessages: document.querySelectorAll('.ocu-panel-message-user').length,
      agentText: document.querySelector('.ocu-panel-message-agent-text')?.textContent ?? null,
    }));
    throw new Error(
      `expected an announcement naming "${screen}"; the panel showed ` +
        `${state.userMessages} user message(s), agent text ${JSON.stringify(state.agentText)}, and ` +
        `${state.lockBanner ? 'a TURN.BUSY lock banner (the turn slot was taken)' : 'no lock banner'}` +
        ` (underlying: ${err.message})`
    );
  }
}

/** The announcement paragraph's own text, once one is on screen -- `null` while none is. */
function announcementText(page) {
  return page.evaluate(() => {
    for (const el of document.querySelectorAll('.ocu-panel-message-agent-text')) {
      if (el.tagName === 'P') return el.textContent;
    }
    return null;
  });
}

test('AC4: the announcement renders first, and the browser has not moved when it appears', async () => {
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 0, navToolUse('permissions/users', '_SYSTEM'));
  scriptReply(tag, 0, textReply('Opened.'));
  const { context, page } = await signedInAt(HOME_URL);
  try {
    const before = pathOf(page);
    await typeAndSend(page, 'open the users screen');
    await waitForAnnouncement(page, 'Users');
    // The announcement is committed to the log before the URL has moved at all. This ordering is
    // the whole of what a browser can assert: the 1,000 ms timer starts inside `check()`, when the
    // poll response is processed, so any elapsed time measured from here is short by however long
    // change detection and paint took -- a machine-dependent figure. The delay's own length is
    // pinned deterministically with fake timers in `agent-navigator.spec.ts`.
    assert.equal(pathOf(page), before, 'the URL has not moved the instant the announcement appears');
    const text = await announcementText(page);
    assert.equal(text, STRINGS.agentNavigationAnnouncement.split('<screen>').join('Users').split('<entity>').join('_SYSTEM'));
    // No button in the announcement itself -- Back is the only undo (AC6).
    const hasButton = await page.evaluate(
      () => document.querySelector('.ocu-panel-message-agent-text button') !== null
    );
    assert.equal(hasButton, false, 'the announcement carries no button of its own');

    await page.waitForFunction(() => window.location.pathname.includes('/permissions/users/'), {
      timeout: config.navigationTimeoutMs,
    });
    assert.equal(pathOf(page), '/ocupilot/permissions/users/_SYSTEM');
    await awaitReply(page, 'Opened.');
  } finally {
    await context.close();
    forgetTag(tag);
  }
});

test('AC5: the arrival focuses the screen heading, labelled with the published sentence', async () => {
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 0, navToolUse('permissions/users', '_SYSTEM'));
  scriptReply(tag, 0, textReply('Opened.'));
  const { context, page } = await signedInAt(HOME_URL);
  try {
    await typeAndSend(page, 'open the users screen');
    await page.waitForFunction(() => window.location.pathname.includes('/permissions/users/'), {
      timeout: config.navigationTimeoutMs,
    });
    await page.waitForFunction(
      () => {
        const el = document.getElementById('ocu-locator-screen');
        return el !== null && document.activeElement === el && el.getAttribute('aria-label') !== null;
      },
      { timeout: config.navigationTimeoutMs }
    );
    const label = await page.$eval('#ocu-locator-screen', (el) => el.getAttribute('aria-label'));
    assert.equal(label, STRINGS.agentNavigationHeadingAnnouncement.split('<title>').join('Users'));
    await awaitReply(page, 'Opened.');
  } finally {
    await context.close();
    forgetTag(tag);
  }
});

test('AC6: Back restores the departing screen with its selected row, after the agent moved elsewhere', async () => {
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 0, navToolUse('tasks/schedule'));
  scriptReply(tag, 0, textReply('Opened.'));
  const { context, page } = await signedInAt('/ocupilot/permissions/users?ns=HSCUSTOM');
  try {
    await page.waitForSelector('[role="row"][aria-rowindex="2"]', { timeout: config.navigationTimeoutMs });
    // A non-name cell: the name cell navigates to the row's own editor rather than selecting it.
    await page.click('[role="row"][aria-rowindex="2"] [role="gridcell"]:nth-child(2)');
    await page.waitForSelector('[role="row"][aria-rowindex="2"][aria-selected="true"]', {
      timeout: config.navigationTimeoutMs,
    });
    const selectedName = await page.$eval(
      '[role="row"][aria-rowindex="2"] [role="gridcell"]:nth-child(1)',
      (node) => node.textContent.trim()
    );

    await typeAndSend(page, 'open the task schedule screen');
    await page.waitForFunction(() => window.location.pathname === '/ocupilot/tasks/schedule', {
      timeout: config.navigationTimeoutMs,
    });
    await awaitReply(page, 'Opened.');

    await page.goBack();
    await page.waitForFunction(() => window.location.pathname === '/ocupilot/permissions/users', {
      timeout: config.navigationTimeoutMs,
    });
    await page.waitForSelector('[role="row"][aria-rowindex="2"][aria-selected="true"]', {
      timeout: config.navigationTimeoutMs,
    });
    const restoredName = await page.$eval(
      '[role="row"][aria-rowindex="2"] [role="gridcell"]:nth-child(1)',
      (node) => node.textContent.trim()
    );
    assert.equal(restoredName, selectedName, 'the same row reads selected again after Back');
  } finally {
    await context.close();
    forgetTag(tag);
  }
});

test('AC7: a dirty form declines the move -- the URL stays, the announcement is withdrawn, and the tool result is is_error false', async () => {
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 0, navToolUse('permissions/users'));
  scriptReply(tag, 0, textReply('Never mind.'));
  const { context, page } = await signedInAt(FORM_URL);
  try {
    await page.waitForSelector('#ocu-definition-name', { visible: true, timeout: config.navigationTimeoutMs });
    await page.click('#ocu-definition-name', { clickCount: 3 });
    await page.type('#ocu-definition-name', 'unsaved work, never sent');
    const before = pathOf(page);

    await typeAndSend(page, 'open the users screen');
    await page.waitForFunction(
      () => (document.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '').includes('Users'),
      { timeout: config.navigationTimeoutMs }
    );

    await page.waitForSelector('[role="dialog"]', { visible: true, timeout: config.navigationTimeoutMs });
    const heading = await page.$eval('[role="dialog"] .ocu-dialog-title', (node) => node.textContent.trim());
    assert.equal(heading, STRINGS.formLeaveWithoutSaving);
    const decline = await page.$('[role="dialog"] .ocu-dialog-actions button');
    assert.equal(await decline.evaluate((node) => node.textContent.trim()), STRINGS.actionCancel);
    await decline.click();
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, {
      timeout: config.navigationTimeoutMs,
    });

    assert.equal(pathOf(page), before, 'the URL never moved');
    await awaitReply(page, 'Never mind.');
    const announcementGone = await page.evaluate(() => {
      for (const el of document.querySelectorAll('.ocu-panel-message-agent-text')) {
        if (el.tagName === 'P' && el.textContent.includes('Users')) return false;
      }
      return true;
    });
    assert.equal(announcementGone, true, 'the withdrawn announcement is a removal');
    assert.equal(
      await page.$eval('#ocu-definition-name', (node) => node.value),
      'unsaved work, never sent',
      'the unsaved work is still on screen'
    );

    const messages = recordedMessages(tag, 2);
    // The synthetic `screen_context` tool call (Story 4.11) settles first and carries its own
    // `tool_result` with no `is_error` key at all -- matching on `tool_use_id` finds the
    // navigation tool's own result rather than that one.
    const resultEntry = messages.find(
      (entry) =>
        entry.role === 'user' &&
        Array.isArray(entry.content) &&
        entry.content.some((block) => block.type === 'tool_result' && block.tool_use_id === 'toolu_nav')
    );
    const resultBlock = resultEntry?.content.find((block) => block.tool_use_id === 'toolu_nav');
    assert.ok(resultBlock, 'the tool result reached the next provider call');
    assert.equal(resultBlock.is_error, false, 'AD-11 rule 3: a refusal is an ordinary result, never an error');
    // DW-1095: `entityId` is absent, not null. This call named no row, and the member is declared
    // "type": "string" outside `ResultSchema`'s `required`, so a null would be a value the
    // declared type does not admit. `deepEqual` on the parsed object is what makes the absence an
    // assertion rather than something nothing looks at.
    assert.deepEqual(JSON.parse(resultBlock.content), { navigated: false, route: 'permissions/users', code: 'NAV.REFUSEDUNSAVED' });
  } finally {
    await context.close();
    forgetTag(tag);
  }
});

test('QA: a second turn whose announce step lands on the same seq as an earlier, already-settled turn is still navigated (activeSeq cross-turn reset)', async () => {
  // Story 4.7's own follow-up-review risk: `AgentNavigator.activeSeq`'s per-turn reset (the
  // `directive === null` branch in `check()`) was pinned only at the unit level, against a
  // stubbed `TurnStore` whose `clearNavigation()` was called by hand -- never end to end against
  // two consecutive real turns, where the reset trigger is `TurnStore.send()`'s own
  // `pendingNavigationValue = null` (turn.ts:454), fired synchronously on every new turn. Every
  // navigating turn here is a single-tool-call turn (model step Seq 1, tool step Seq 2, announce
  // step Seq 3 -- `Step.TurnSeqIdx` is unique per turn, not globally), so both turns' announce
  // steps land on the identical Seq 3 the review finding names. Without the reset,
  // `directive.seq === this.activeSeq` would still hold from the first, already-settled turn and
  // the second navigation would never be scheduled at all.
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 0, navToolUse('tasks/schedule'));
  scriptReply(tag, 0, textReply('Opened one.'));
  const { context, page } = await signedInAt(HOME_URL);
  try {
    await typeAndSend(page, 'open the task schedule screen');
    await page.waitForFunction(() => window.location.pathname === '/ocupilot/tasks/schedule', {
      timeout: config.navigationTimeoutMs,
    });
    await awaitReply(page, 'Opened one.');

    scriptReply(tag, 0, navToolUse('permissions/users', '_SYSTEM'));
    scriptReply(tag, 0, textReply('Opened two.'));
    await typeAndSend(page, 'open the users screen for _SYSTEM');
    await page.waitForFunction(() => window.location.pathname === '/ocupilot/permissions/users/_SYSTEM', {
      timeout: config.navigationTimeoutMs,
    });
    await awaitReply(page, 'Opened two.');
  } finally {
    await context.close();
    forgetTag(tag);
  }
});

test('AC11: the next turn carries the arrived route as its own screen context, never the departed one', async () => {
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 0, navToolUse('tasks/schedule'));
  scriptReply(tag, 0, textReply('Opened.'));
  const { context, page } = await signedInAt('/ocupilot/permissions/users?ns=HSCUSTOM');
  try {
    await typeAndSend(page, 'open the task schedule screen');
    await page.waitForFunction(() => window.location.pathname === '/ocupilot/tasks/schedule', {
      timeout: config.navigationTimeoutMs,
    });

    // The first turn is still finishing (settling the directive, then this final reply) after
    // the URL has already moved -- sending the second message before it completes would find
    // Send still showing Stop.
    await awaitReply(page, 'Opened.');

    // AC11's second named consumer: the chip names the arrived screen, not the departed one.
    await page.waitForFunction(() => (document.querySelector('.ocu-context-chip-text')?.textContent ?? '') !== '', {
      timeout: config.navigationTimeoutMs,
    });
    const chipText = await page.$eval('.ocu-context-chip-text', (node) => node.textContent ?? '');
    assert.match(chipText, /^Task schedule, HSCUSTOM/, `the chip names the arrived screen; got ${chipText}`);

    scriptReply(tag, 0, textReply('Noted.'));
    await typeAndSend(page, 'what am I looking at now');
    await awaitReply(page, 'Noted.');

    // The synthetic `screen_context` tool call's own `input` is always `{}` -- the route is in
    // its paired `tool_result`'s content (JSON, `context-chip.browser-spec.mjs`'s own shape).
    const messages = recordedMessages(tag, 3);
    const resultEntry = messages.find(
      (entry) =>
        entry.role === 'user' &&
        Array.isArray(entry.content) &&
        entry.content.some((block) => block.type === 'tool_result' && block.tool_use_id === 'ocupilot_screen_context')
    );
    assert.ok(resultEntry, 'the third call still carries the synthetic screen_context tool result');
    const resultBlock = resultEntry.content.find((block) => block.tool_use_id === 'ocupilot_screen_context');
    const payload = JSON.parse(resultBlock.content);
    assert.equal(payload.route, 'tasks/schedule', 'the arrived route, not the departed one');
  } finally {
    await context.close();
    forgetTag(tag);
  }
});

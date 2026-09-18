/**
 * The agent's navigation tool (`shell.screen.open`), driven through a real browser against the
 * throwaway instance (Story 4.7, AD-11 rule 3): the announcement renders before the browser
 * moves, and only after `NAVIGATIONDELAYMS`; the arrived screen's heading takes focus and carries
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
const probe = { container: config.container, marker: 'NAV' };

const HOME_URL = '/ocupilot/?ns=HSCUSTOM';
const FORM_URL = '/ocupilot/agent/definitions/edit?ns=HSCUSTOM';

/** The delay `agent-navigator.ts` waits between announcing and moving (Story 4.7, AC4). Kept in
 * sync with `ui/src/app/shell/agent-navigator.ts`'s own `NAVIGATIONDELAYMS` by this comment
 * alone -- a real browser test cannot import a `.ts` constant, so a mismatch here would need
 * fixing at both ends by hand if the published delay ever changes. */
const NAVIGATIONDELAYMS = 1000;

let browser = null;
let preparedId = '';
let priorDefault = '';

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec arms the turnprobe provider, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  browser = await puppeteer.launch(launchOptions(config));
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  disarmProbeDefinition(probe, priorDefault);
});

function runIris(lines) {
  return sharedRunIris(config.container, lines);
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

/** The path the browser is actually on, with no origin and no fragment. */
function pathOf(page) {
  return new URL(page.url()).pathname;
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

test('AC4: the announcement renders first, and the browser moves only after NAVIGATIONDELAYMS', async () => {
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 0, navToolUse('permissions/users', '_SYSTEM'));
  scriptReply(tag, 0, textReply('Opened.'));
  const { context, page } = await signedInAt(HOME_URL);
  try {
    const before = pathOf(page);
    await typeAndSend(page, 'open the users screen');
    await page.waitForFunction(
      () => (document.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '').includes('Users'),
      { timeout: config.navigationTimeoutMs }
    );
    const announcedAt = Date.now();
    // The announcement is committed to the log before the URL has moved at all.
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
    const elapsedMs = Date.now() - announcedAt;
    assert.ok(elapsedMs >= NAVIGATIONDELAYMS - 100, `the move waited at least ~${NAVIGATIONDELAYMS} ms; took ${elapsedMs}`);
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
    assert.deepEqual(JSON.parse(resultBlock.content), { navigated: false, route: 'permissions/users', entityId: null, code: 'NAV.REFUSEDUNSAVED' });
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

/**
 * A turn, watched, in a real browser against the throwaway instance (Story 4.5): Send through a
 * completed reply within NFR-1's 10 s budget, a read card's rows line, Stop mid-call, the lock banner
 * on a second send in this tab and from another, a failed tool whose name is markup, reload restoring the transcript with no running card, a navigation
 * that is not a reload starting fresh, New conversation, and markup rendered as literal text with no
 * off-origin request.
 *
 * jsdom computes no layout and issues no real network request, so the wall-clock budget (NFR-1)
 * and "no request left this origin" are only observable here. Every test scripts its own
 * `turnprobe` tag (`OcuPilot.Test.TurnProvider`) through `docker exec`, the same fixture
 * `OcuPilot.Test.TurnWire` drives over HTTP -- this drives the same provider through the real
 * panel instead.
 *
 * Run: `npm run build` then `docker cp` the bundle into the throwaway, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test browser/turn.browser-spec.mjs`
 * (`.claude/rules/objectscript-testing.md`'s "a browser spec runs against the deployed bundle").
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { leaveFirstLoginGate, pathOf } from './shell-entry.mjs';
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
const probe = { container: config.container, marker: 'TURN' };

const HOME_URL = '/ocupilot/?ns=HSCUSTOM';

let browser = null;
let preparedId = '';
let priorDefault = '';

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec arms the turnprobe provider, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  browser = await puppeteer.launch(launchOptions(config));
  // Defensive: a prior run whose own `after` did not get to run (a crash, a killed process)
  // leaves the uniquely-named probe definition behind, and `EnsureDefinition` always inserts --
  // it does not upsert -- so a stale row here would fail every test in this file at `before`.
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

function toolUseReply(toolWireName) {
  return `##class(OcuPilot.Test.TurnProvider).ToolUseReply("${escapeOs(toolWireName)}")`;
}

function textReply(text) {
  return `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs(text)}")`;
}

function forgetTag(tag) {
  sharedForgetTag(probe, tag);
}

/** Poll (server-side, blocking) until `tag` has begun answering call number `pCall`. */
function awaitCall(tag, call, seconds) {
  const output = runIris([
    `Write "OCU-TURN-CALL-START:"_##class(OcuPilot.Test.TurnWireFixture).AwaitCall("${escapeOs(tag)}",${call},${seconds})_":OCU-TURN-CALL-END",!`,
  ]);
  return markerValue(output, 'TURN-CALL') === '1';
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

test('AC1/NFR-1: the first card is visible within 10,000 ms of Send, and the final reply follows', async () => {
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 0, toolUseReply('shell_namespaces_read'));
  scriptReply(tag, 0, textReply('Here is what I found.'));
  const { context, page } = await signedInAt(HOME_URL);
  try {
    const clickedAt = Date.now();
    await typeAndSend(page, 'list the namespaces');
    await page.waitForSelector('.ocu-tool-call-toggle, .ocu-tool-call-card-stopped', {
      timeout: config.navigationTimeoutMs,
    });
    const elapsedMs = Date.now() - clickedAt;
    assert.ok(elapsedMs < 10000, `the first card appeared within 10,000 ms; took ${elapsedMs}`);

    await page.waitForFunction(
      () => (document.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '') === 'Here is what I found.',
      { timeout: config.navigationTimeoutMs }
    );
    // One tool call was made: exactly one card, never one per model round-trip (the `kind:
    // 'model'` steps -- the provider call that asked for the tool, and the one that answered with
    // the final text -- must never render their own cards).
    const toolCallCardCount = await page.evaluate(() => document.querySelectorAll('.ocu-tool-call-card').length);
    assert.equal(toolCallCardCount, 1, 'exactly the one real tool card, not one per model round-trip');
    const sendLabel = await page.evaluate(() => document.querySelector('.ocu-panel-send').textContent.trim());
    assert.equal(sendLabel, 'Send', 'Send returned to Send once the turn ended');
    const userMessage = await page.evaluate(
      () => document.querySelector('.ocu-panel-message-user')?.textContent
    );
    assert.equal(userMessage, 'list the namespaces');
  } finally {
    await context.close();
    forgetTag(tag);
  }
});

test('Stop mid-call: the running card becomes "Stopped by you at <step>", no reply, no error banner', async () => {
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 4, toolUseReply('shell_namespaces_read'));
  scriptReply(tag, 0, textReply('should never be seen'));
  const { context, page } = await signedInAt(HOME_URL);
  try {
    await typeAndSend(page, 'stop me');
    // Busy flips the label to Stop synchronously, before `POST /turn` has even resolved -- wait
    // for the user message instead, which appears only once the turn is actually accepted and
    // `currentTurnId` is set, so a Stop click here is never a no-op racing an unset turn id.
    await page.waitForSelector('.ocu-panel-message-user', { timeout: config.navigationTimeoutMs });
    // "Mid-call" means the provider's own hanging call has actually started -- otherwise Stop
    // can win the race against the job even issuing it, and the stopped step names "provider"
    // (Boundary caught it before the model call) rather than the tool the model was about to run.
    assert.ok(awaitCall(tag, 1, 15), 'the provider call began');
    await page.click('.ocu-panel-send');

    await page.waitForSelector('.ocu-tool-call-card-stopped', { timeout: config.navigationTimeoutMs });
    const text = await page.evaluate(() => document.querySelector('.ocu-tool-call-card-stopped').textContent.trim());
    assert.equal(text, 'Stopped by you at shell.namespaces.read');
    const hasBody = await page.evaluate(() => document.querySelector('.ocu-tool-call-body') !== null);
    assert.equal(hasBody, false, 'a stopped card has no body');
    const errorBanner = await page.evaluate(() => document.querySelector('.ocu-panel-error-banner'));
    assert.equal(errorBanner, null, 'a stop is never an error');
    const reply = await page.evaluate(() => document.querySelector('.ocu-panel-message-agent-text'));
    assert.equal(reply, null, 'no reply for a stopped turn');
  } finally {
    await context.close();
    forgetTag(tag);
  }
});

test('Second send: Enter while busy shows the lock banner, keeps the draft, appends nothing', async () => {
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 15, textReply('done'));
  const { context, page } = await signedInAt(HOME_URL);
  try {
    await page.type('#ocu-panel-composer', 'first message');
    await page.click('.ocu-panel-send');
    // Wait for the turn to be genuinely accepted (see the Stop-mid-call test's own note), with an
    // 15 s hang behind it, so the other tab below signs in and sends before it completes.
    await page.waitForSelector('.ocu-panel-message-user', { timeout: config.navigationTimeoutMs });

    await page.type('#ocu-panel-composer', 'second, while busy');
    await page.keyboard.press('Enter');

    await page.waitForSelector('[data-slot="lock"] .ocu-banner[role="status"]', { timeout: config.navigationTimeoutMs });
    const draft = await page.evaluate(() => document.querySelector('#ocu-panel-composer').value);
    assert.equal(draft, 'second, while busy', 'the draft is kept');
    const userMessages = await page.evaluate(() => document.querySelectorAll('.ocu-panel-message-user').length);
    assert.equal(userMessages, 1, 'no second message was appended');

    // The same user's other tab: the instance refuses its send 409, and it shows the same banner.
    const other = await signedInAt(HOME_URL);
    try {
      await typeAndSend(other.page, 'from the other tab');
      await other.page.waitForSelector('[data-slot="lock"] .ocu-banner[role="status"]', { timeout: config.navigationTimeoutMs });
      const otherState = await other.page.evaluate(() => ({
        draft: document.querySelector('#ocu-panel-composer').value,
        messages: document.querySelectorAll('.ocu-panel-message-user').length,
      }));
      assert.deepEqual(otherState, { draft: 'from the other tab', messages: 0 }, 'the other tab keeps its draft and appends nothing');
    } finally {
      await other.context.close();
    }

    // Closing the context does not end the server-side job: every test here signs in as the same
    // configured user and so shares one AD-41 turn slot. Waiting for this turn to actually finish
    // is what keeps this test's own hang from still holding that slot when the next test's
    // own Send lands, which would otherwise answer 409 for a reason this test never touches.
    await page.waitForFunction(() => (document.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '') === 'done', {
      timeout: config.navigationTimeoutMs,
    });
  } finally {
    await context.close();
    forgetTag(tag);
  }
});

test('AC2: a read card, expanded, shows the rows the read returned and the rows it sent', async () => {
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 0, toolUseReply('osmgmt_processes_read'));
  scriptReply(tag, 0, textReply('Read the processes.'));
  const { context, page } = await signedInAt(HOME_URL);
  try {
    await typeAndSend(page, 'list the processes');
    await page.waitForFunction(
      () => (document.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '') === 'Read the processes.',
      { timeout: config.navigationTimeoutMs }
    );
    const label = await page.evaluate(() => document.querySelector('.ocu-tool-call-name')?.textContent ?? '');
    assert.equal(label, 'osmgmt.processes.read');
    await page.click('.ocu-tool-call-toggle');
    await page.waitForSelector('.ocu-tool-call-rows', { timeout: config.navigationTimeoutMs });
    const rowsLine = await page.evaluate(() => document.querySelector('.ocu-tool-call-rows').textContent.trim());
    assert.match(rowsLine, /^\d+ rows returned \u00b7 \d+ sent$/, `the rows line: ${rowsLine}`);
  } finally {
    await context.close();
    forgetTag(tag);
  }
});

test('Failed tool: an unknown tool named with markup renders "failed \u2014 <reason>" as literal text, with no off-origin request', async () => {
  const tag = nextTag();
  setTag(tag);
  const markup = '<img src="' + 'http:' + '//' + '203.0.113.9' + '/y">';
  scriptReply(tag, 0, toolUseReply(markup));
  scriptReply(tag, 0, textReply('That tool does not exist.'));
  const { context, page } = await signedInAt(HOME_URL);
  const offOriginRequests = [];
  page.on('request', (request) => {
    if (new URL(request.url()).hostname === '203.0.113.9') offOriginRequests.push(request.url());
  });
  try {
    await typeAndSend(page, 'call a missing tool');
    await page.waitForFunction(
      () => (document.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '') === 'That tool does not exist.',
      { timeout: config.navigationTimeoutMs }
    );
    const card = await page.evaluate(() => ({
      name: document.querySelector('.ocu-tool-call-name')?.textContent ?? '',
      status: document.querySelector('.ocu-tool-call-status-word')?.textContent?.trim() ?? '',
      images: document.querySelectorAll('.ocu-tool-call-card img').length,
    }));
    assert.equal(card.name, markup, 'the unknown name renders as literal text');
    assert.match(card.status, /^failed \u2014 \S/, `the status names the failure and its reason: ${card.status}`);
    assert.equal(card.images, 0, 'no <img> element was created from it');
    assert.deepEqual(offOriginRequests, [], 'no request left the origin');
  } finally {
    await context.close();
    forgetTag(tag);
  }
});

test('Reload restores a completed turn with no running card; a navigation that is not a reload starts fresh', async () => {
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 0, toolUseReply('shell_namespaces_read'));
  scriptReply(tag, 0, textReply('reload me'));
  const { context, page } = await signedInAt(HOME_URL);
  try {
    await typeAndSend(page, 'remember this');
    await page.waitForFunction(
      () => (document.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '') === 'reload me',
      { timeout: config.navigationTimeoutMs }
    );

    await page.reload({ waitUntil: 'networkidle2' });
    await page.waitForSelector('app-panel aside.ocu-panel', { timeout: config.navigationTimeoutMs });
    await page.waitForFunction(
      () => (document.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '') === 'reload me',
      { timeout: config.navigationTimeoutMs }
    );
    const cards = await page.evaluate(() => ({
      toggles: document.querySelectorAll('.ocu-tool-call-toggle').length,
      expanded: document.querySelectorAll('.ocu-tool-call-toggle[aria-expanded="true"]').length,
      spinners: document.querySelectorAll('.ocu-tool-call-spinner').length,
    }));
    assert.deepEqual(cards, { toggles: 1, expanded: 0, spinners: 0 }, 'the restored card is there, and not running');

    // A new or duplicated tab navigates rather than reloads, so it must not adopt the id this tab
    // stored: the same tab, navigated, reads it the same way.
    const storedBefore = await page.evaluate(() => sessionStorage.getItem('ocupilot.conversation'));
    assert.ok(storedBefore, 'this tab stored its conversation id');
    await page.goto(`${config.origin}${HOME_URL}`, { waitUntil: 'networkidle2' });
    const storedAfter = await page.evaluate(() => sessionStorage.getItem('ocupilot.conversation'));
    assert.equal(storedAfter, null, 'a navigation that is not a reload drops the stored id, so it starts empty');
  } finally {
    await context.close();
    forgetTag(tag);
  }
});

test('New conversation clears the transcript, and the next turn carries no earlier message', async () => {
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 0, textReply('turn one'));
  const { context, page } = await signedInAt(HOME_URL);
  try {
    await typeAndSend(page, 'first turn');
    await page.waitForFunction(
      () => (document.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '') === 'turn one',
      { timeout: config.navigationTimeoutMs }
    );

    await page.click('.ocu-panel-new-conversation');
    await page.waitForFunction(
      () => document.querySelector('.ocu-panel-message-user') === null,
      { timeout: config.navigationTimeoutMs }
    );

    scriptReply(tag, 0, textReply('turn two'));
    await typeAndSend(page, 'second turn, new conversation');
    await page.waitForFunction(
      () => (document.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '') === 'turn two',
      { timeout: config.navigationTimeoutMs }
    );

    const recordedOutput = runIris([
      `Write "OCU-TURN-MSGS-START:"_##class(OcuPilot.Test.TurnProvider).Recorded("${escapeOs(tag)}",2,"messages")_":OCU-TURN-MSGS-END",!`,
    ]);
    const sent = JSON.parse(markerValue(recordedOutput, 'TURN-MSGS') ?? '[]');
    assert.equal(sent.length, 1, 'the new conversation carries no earlier turn');
    assert.equal(sent[0].content, 'second turn, new conversation');
  } finally {
    await context.close();
    forgetTag(tag);
  }
});

test('Markup in a reply renders as literal text, and the browser makes no request to any other origin', async () => {
  const tag = nextTag();
  setTag(tag);
  const markup = '<img src="' + 'http:' + '//' + '203.0.113.9' + '/x">';
  scriptReply(tag, 0, textReply(markup));
  const { context, page } = await signedInAt(HOME_URL);
  const offOriginRequests = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.hostname === '203.0.113.9') offOriginRequests.push(request.url());
  });
  try {
    await typeAndSend(page, 'send me markup');
    await page.waitForFunction(
      () => (document.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '') !== '',
      { timeout: config.navigationTimeoutMs }
    );
    const rendered = await page.evaluate(() => document.querySelector('.ocu-panel-message-agent-text').textContent);
    assert.equal(rendered, markup, 'the markup renders as literal text');
    const hasImg = await page.evaluate(() => document.querySelector('.ocu-panel-message-agent-text img') !== null);
    assert.equal(hasImg, false, 'no <img> element was created from it');
    assert.deepEqual(offOriginRequests, [], 'no request left the origin for the off-origin host');
  } finally {
    await context.close();
    forgetTag(tag);
  }
});

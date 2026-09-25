/**
 * "Explain this screen" in a real browser against the throwaway instance (Story 11.1): on the
 * process list one click sends the fixed sentence with the screen's context, leaves the draft as it
 * was, and a scripted reply naming the read tool renders verbatim; on Home the turn carries Home's
 * identity; with sharing off the button is unavailable and sends nothing.
 *
 * Arms the `turnprobe` definition the way `screen-grounding.browser-spec.mjs` does and reads what
 * reached the provider back through `OcuPilot.Test.TurnProvider.Recorded`. The per-user sharing
 * choice is server state, so the sharing-off leg restores `share: true` in its own `finally`, and
 * `after` restores it again.
 *
 * Run: `npm run build` then `docker cp` the bundle into the throwaway, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test browser/explain-screen.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { authHeader, signedInAt } from './panel-spec.mjs';
import {
  armProbeDefinition,
  disarmProbeDefinition,
  escapeOs,
  forgetTag,
  markerValue,
  nextTag,
  requireFreeSlot,
  runIris,
  scriptReply,
  setTag,
} from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const probe = { container: config.container, marker: 'EXPLAIN' };

const PROCESSES_URL = '/ocupilot/os-management/processes?ns=HSCUSTOM';
const HOME_URL = '/ocupilot/?ns=HSCUSTOM';
const CONTEXT_PATH = '/api/ocupilot/agent/context';
const EXPLAIN = '[data-slot="explain"]';

/** A reply naming the process list's read tool, which must render character for character. */
const REPLY = 'This screen lists the processes running on the instance. Its rows come from osmgmt_processes_read.';

let browser = null;
let preparedId = '';
let priorDefault = '';

async function putShare(share) {
  const answer = await fetch(`${config.origin}${CONTEXT_PATH}`, {
    method: 'PUT',
    headers: { Authorization: authHeader(config), 'Content-Type': 'application/json' },
    body: JSON.stringify({ share }),
  });
  assert.ok(answer.ok, `PUT /agent/context {share:${share}} (HTTP ${answer.status})`);
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec arms the turnprobe provider, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);
  browser = await puppeteer.launch(launchOptions(config));
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
  await putShare(true);
});

after(async () => {
  try {
    try {
      if (config.container !== LIVE_CONTAINER) await requireFreeSlot(config);
    } finally {
      if (config.container !== LIVE_CONTAINER) {
        disarmProbeDefinition(probe, priorDefault);
        await putShare(true);
      }
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

/** Call 1's recorded `messages` for `tag`. */
function recordedMessages(tag) {
  const output = runIris(config.container, [
    `Write "OCU-EXPLAIN-MSGS-START:"_##class(OcuPilot.Test.TurnProvider).Recorded("${escapeOs(tag)}",1,"messages")_":OCU-EXPLAIN-MSGS-END",!`,
  ]);
  const value = markerValue(output, 'EXPLAIN-MSGS');
  assert.ok(value, `Recorded answered: ${output}`);
  return JSON.parse(value);
}

/** Whether call 1's recorded system prompt carries the prompt's explain statement. */
function systemCarriesExplainStatement(tag) {
  const output = runIris(config.container, [
    `Write "OCU-EXPLAIN-SYS-START:"_(##class(OcuPilot.Test.TurnProvider).Recorded("${escapeOs(tag)}",1,"system")[##class(OcuPilot.Test.ScreenGrounding).Statement(7))_":OCU-EXPLAIN-SYS-END",!`,
  ]);
  return markerValue(output, 'EXPLAIN-SYS') === '1';
}

/** The `screen_context` payload in a recorded `messages` array, or `null`. */
function screenContextPayload(messages) {
  const useIndex = messages.findIndex(
    (entry) =>
      entry.role === 'assistant' &&
      Array.isArray(entry.content) &&
      entry.content.some((block) => block.type === 'tool_use' && block.name === 'screen_context')
  );
  if (useIndex < 0) return null;
  const resultBlock = messages[useIndex + 1]?.content?.find?.((block) => block.type === 'tool_result');
  return resultBlock ? JSON.parse(resultBlock.content) : null;
}

/** The text of the last user entry in a recorded `messages` array. */
function lastUserText(messages) {
  const last = [...messages].reverse().find((entry) => entry.role === 'user');
  if (last === undefined) return '';
  if (typeof last.content === 'string') return last.content;
  return last.content.filter((block) => block.type === 'text').map((block) => block.text).join('');
}

/** The button can show while the panel is still loading, `aria-disabled` and deaf to a click. */
async function waitForExplainAvailable(page) {
  await page.waitForFunction((selector) => !document.querySelector(selector)?.hasAttribute('aria-disabled'), { timeout: config.navigationTimeoutMs }, EXPLAIN);
}

async function waitForReply(page, text) {
  await page.waitForFunction(
    (expected) => (document.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '') === expected,
    { timeout: config.navigationTimeoutMs },
    text
  );
}

test('(a) List screen: one click sends the sentence with the screen context and the draft kept; a reply naming the read tool renders verbatim', async () => {
  await requireFreeSlot(config);
  const tag = nextTag(probe);
  setTag(probe, preparedId, tag);
  scriptReply(probe, tag, 0, `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs(REPLY)}")`);
  const { context, page } = await signedInAt(browser, config, PROCESSES_URL);
  try {
    await page.waitForSelector(EXPLAIN, { visible: true, timeout: config.navigationTimeoutMs });
    await waitForExplainAvailable(page);
    assert.equal(await page.$eval(EXPLAIN, (el) => el.textContent.trim()), STRINGS.agentExplainScreenAction);
    await page.type('#ocu-panel-composer', 'keep me');
    await page.click(EXPLAIN);
    await waitForReply(page, REPLY);

    assert.equal(await page.$eval('.ocu-panel-message-user', (el) => el.textContent.trim()), STRINGS.agentExplainScreenAction, 'the user bubble is the sentence');
    assert.equal(await page.$eval('#ocu-panel-composer', (el) => el.value), 'keep me', 'the draft is left as it was');

    const messages = recordedMessages(tag);
    const payload = screenContextPayload(messages);
    assert.ok(payload, 'a screen_context pair was recorded');
    assert.equal(payload.route, 'os-management/processes');
    assert.equal(payload.tools[0], 'osmgmt_processes_read', 'the screen names its read tool first');
    assert.equal(lastUserText(messages), STRINGS.agentExplainScreenAction, 'the user message is the sentence');
    assert.ok(systemCarriesExplainStatement(tag), 'the system prompt carries the explain statement');
  } finally {
    await context.close();
    forgetTag(probe, tag);
  }
});

test('(b) Home: the turn carries Home\'s identity, with no tool and no row', async () => {
  await requireFreeSlot(config);
  const tag = nextTag(probe);
  setTag(probe, preparedId, tag);
  scriptReply(probe, tag, 0, `##class(OcuPilot.Test.TurnProvider).TextReply("home explained")`);
  const { context, page } = await signedInAt(browser, config, HOME_URL);
  try {
    await page.waitForSelector(EXPLAIN, { visible: true, timeout: config.navigationTimeoutMs });
    await waitForExplainAvailable(page);
    await page.click(EXPLAIN);
    await waitForReply(page, 'home explained');

    const payload = screenContextPayload(recordedMessages(tag));
    assert.ok(payload, 'Home posts a screen_context pair');
    assert.equal(payload.screen, 'shell.home');
    assert.equal(payload.route, '');
    assert.deepEqual(payload.tools, []);
    assert.equal(typeof payload.readOnly, 'boolean');
    assert.equal(payload.rowsSent, 0);
  } finally {
    await context.close();
    forgetTag(probe, tag);
  }
});

test('(c) Sharing off: the button is aria-disabled, described by the sharing-off sentence, and a click sends nothing', async () => {
  await requireFreeSlot(config);
  const tag = nextTag(probe);
  setTag(probe, preparedId, tag);
  await putShare(false);
  let context = null;
  try {
    const signedIn = await signedInAt(browser, config, PROCESSES_URL);
    context = signedIn.context;
    const page = signedIn.page;
    const turnPosts = [];
    page.on('request', (request) => {
      if (request.method() === 'POST' && new URL(request.url()).pathname === '/api/ocupilot/turn') turnPosts.push(request.url());
    });
    await page.waitForSelector(EXPLAIN, { visible: true, timeout: config.navigationTimeoutMs });
    await page.waitForFunction((selector) => document.querySelector(selector)?.getAttribute('aria-disabled') === 'true', { timeout: config.navigationTimeoutMs }, EXPLAIN);
    const describedText = await page.$eval(EXPLAIN, (el) => document.getElementById(el.getAttribute('aria-describedby') ?? '')?.textContent?.trim() ?? '');
    assert.equal(describedText, STRINGS.contextChipSharingOff, 'described by the chip\'s sharing-off sentence');

    await page.click(EXPLAIN);
    await new Promise((resolve) => setTimeout(resolve, 1500));
    assert.deepEqual(turnPosts, [], 'no turn was posted');
    assert.equal(await page.$('.ocu-panel-message-user'), null, 'and no user bubble appeared');
  } finally {
    if (context !== null) await context.close();
    forgetTag(probe, tag);
    await putShare(true);
  }
});

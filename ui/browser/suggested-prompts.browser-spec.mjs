/**
 * Suggested prompts in a real browser against the throwaway instance (Story 11.3): on the Users
 * list, with the probe definition and an empty transcript, choosing a prompt sends its exact text
 * as the user message and the scripted reply renders; on Home, with the dates read answered clean in
 * the page, exactly one prompt set shows, of at least three, and it is the block's.
 *
 * Arms the `turnprobe` definition the way `explain-screen.browser-spec.mjs` does and reads what
 * reached the provider back through `OcuPilot.Test.TurnProvider.Recorded`.
 *
 * Run: `npm run build` then `docker cp` the bundle into the throwaway, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test browser/suggested-prompts.browser-spec.mjs`.
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
const probe = { container: config.container, marker: 'PROMPTS' };

const USERS_URL = '/ocupilot/permissions/users?ns=HSCUSTOM';
/** Home's application-errors read, answered clean in the page for leg (b). */
const DATES_PATHNAME = '/api/ocupilot/logs/errors/dates';
const PROMPT = STRINGS.userListPrompt2;
const REPLY = 'Two users hold %All on this instance.';

let browser = null;
let preparedId = '';
let priorDefault = '';

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec arms the turnprobe provider, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);
  browser = await puppeteer.launch(launchOptions(config));
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
});

after(async () => {
  try {
    try {
      if (config.container !== LIVE_CONTAINER) await requireFreeSlot(config);
    } finally {
      if (config.container !== LIVE_CONTAINER) disarmProbeDefinition(probe, priorDefault);
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

/** Call 1's recorded `messages` for `tag`. */
function recordedMessages(tag) {
  const output = runIris(config.container, [
    `Write "OCU-PROMPTS-MSGS-START:"_##class(OcuPilot.Test.TurnProvider).Recorded("${escapeOs(tag)}",1,"messages")_":OCU-PROMPTS-MSGS-END",!`,
  ]);
  const value = markerValue(output, 'PROMPTS-MSGS');
  assert.ok(value, `Recorded answered: ${output}`);
  return JSON.parse(value);
}

/** The text of the last user entry in a recorded `messages` array. */
function lastUserText(messages) {
  const last = [...messages].reverse().find((entry) => entry.role === 'user');
  if (last === undefined) return '';
  if (typeof last.content === 'string') return last.content;
  return last.content.filter((block) => block.type === 'text').map((block) => block.text).join('');
}

test('(a) Users list: choosing a prompt sends its exact text as the user message, and the reply renders', async () => {
  // Mutation (Rule 19): make `onSuggestedPrompt` call `onSuggestion`, or the `promptGroups` getter
  // answer `[]` off Home -> this goes red.
  await requireFreeSlot(config);
  const tag = nextTag(probe);
  setTag(probe, preparedId, tag);
  scriptReply(probe, tag, 0, `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs(REPLY)}")`);
  const { context, page } = await signedInAt(browser, config, USERS_URL);
  try {
    await page.waitForSelector('[role="log"] .ocu-prompt-group', { visible: true, timeout: config.navigationTimeoutMs });
    const groups = await page.$$eval('[role="log"] .ocu-prompt-group', (nodes) =>
      nodes.map((node) => ({
        role: node.getAttribute('role'),
        label: node.querySelector('.ocu-prompt-group-label').textContent.trim(),
        prompts: [...node.querySelectorAll('.ocu-suggested-starter > span:first-child')].map((span) => span.textContent.trim()),
      }))
    );
    assert.deepEqual(groups, [
      { role: 'group', label: STRINGS.userPromptGroupSignIn, prompts: [STRINGS.userListPrompt1] },
      { role: 'group', label: STRINGS.userPromptGroupAccess, prompts: [STRINGS.userListPrompt2, STRINGS.userListPrompt3] },
    ]);

    await page.waitForFunction(
      (text) =>
        [...document.querySelectorAll('.ocu-suggested-starter')].some(
          (node) => node.querySelector('span')?.textContent.trim() === text && !node.hasAttribute('aria-disabled')
        ),
      { timeout: config.navigationTimeoutMs },
      PROMPT
    );
    await page.evaluate((text) => {
      const button = [...document.querySelectorAll('.ocu-suggested-starter')].find(
        (node) => node.querySelector('span')?.textContent.trim() === text
      );
      button.click();
    }, PROMPT);
    await page.waitForFunction(
      (expected) => (document.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '') === expected,
      { timeout: config.navigationTimeoutMs },
      REPLY
    );

    assert.equal(await page.$eval('.ocu-panel-message-user', (el) => el.textContent.trim()), PROMPT, 'the user bubble is the prompt');
    assert.equal(lastUserText(recordedMessages(tag)), PROMPT, 'the user message is exactly the prompt');
  } finally {
    await context.close();
    forgetTag(probe, tag);
  }
});

test('(b) Home: exactly one prompt set shows, of at least three, and on a clean log it is the block\'s', async () => {
  // Mutation (Rule 19): render the greeting's prompts whatever `homeBlockPrompts` answers -> this
  // goes red. The dates read is answered clean in the page, so the block offers its set whatever the
  // throwaway's own log holds.
  const { context, page } = await signedInAt(browser, config, USERS_URL);
  try {
    await page.setRequestInterception(true);
    page.on('request', (request) => {
      if (new URL(request.url()).pathname === DATES_PATHNAME) {
        request.respond({ status: 200, contentType: 'application/json', body: JSON.stringify({ rows: [] }) });
        return;
      }
      request.continue();
    });
    await page.click(`.ocu-rail-item[aria-label="${STRINGS.navAreaHome}"]`);
    await page.waitForSelector('.ocu-suggested-eyebrow', { timeout: config.navigationTimeoutMs });
    await page.waitForSelector('.ocu-panel-greeting', { timeout: config.navigationTimeoutMs });
    await page.waitForSelector('.ocu-prompt-group', { timeout: config.navigationTimeoutMs });
    const shown = await page.evaluate(() => ({
      inBlock: document.querySelectorAll('.ocu-suggested .ocu-prompt-group').length,
      inGreeting: document.querySelectorAll('[role="log"] .ocu-prompt-group').length,
      prompts: [...document.querySelectorAll('.ocu-prompt-group .ocu-suggested-starter > span:first-child')].map((span) =>
        span.textContent.trim()
      ),
    }));
    assert.equal(shown.inBlock, 1, `the block offers Home's set: ${JSON.stringify(shown)}`);
    assert.equal(shown.inGreeting, 0, `and the greeting offers none: ${JSON.stringify(shown)}`);
    assert.deepEqual(shown.prompts, [
      STRINGS.homeStarterPromptExplainScreen,
      STRINGS.homeStarterPromptExplainLog,
      STRINGS.homeStarterPromptChangeOneThing,
    ]);
  } finally {
    await context.close();
  }
});

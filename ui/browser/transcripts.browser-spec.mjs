/**
 * Transcripts in a real browser, against the throwaway instance (Story 14.4, AC4, AD-19, AD-36,
 * AD-46). Two turns in one conversation, started from the Processes list, are answered by the
 * `turnprobe` provider; New conversation replaces the transcript; the Transcripts list then names
 * the first conversation by its first message, and its name cell opens the transcript page, which
 * shows both messages, both replies and the stored screen context.
 *
 * Run: `npm run build`, `docker cp` the bundle into the throwaway, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test browser/transcripts.browser-spec.mjs`.
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
const probe = { container: config.container, marker: 'TRNS' };

const START_URL = '/ocupilot/os-management/processes?ns=HSCUSTOM';
const LIST_URL = '/ocupilot/agent/transcripts?ns=HSCUSTOM';

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
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  await requireFreeSlot(config).catch(() => {});
  disarmProbeDefinition(probe, priorDefault);
});

/** Type `message`, send it, and wait until the agent's reply reads `reply`. */
async function sendAndAwait(page, message, reply) {
  await page.waitForFunction(() => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'), {
    timeout: config.navigationTimeoutMs,
  });
  await page.type('#ocu-panel-composer', message);
  await page.click('.ocu-panel-send');
  await page.waitForFunction(
    (sendLabel, wanted) =>
      document.querySelector('.ocu-panel-send')?.textContent?.trim() === sendLabel &&
      [...document.querySelectorAll('.ocu-panel-message-agent-text')].some((node) => node.textContent === wanted),
    { timeout: 60000 },
    STRINGS.actionSend,
    reply
  );
}

test('AC4: a conversation New conversation replaced is listed by its first message and reopens whole', async () => {
  const stamp = String(Date.now());
  const first = `transcripts spec first question ${stamp}`;
  const second = `transcripts spec second question ${stamp}`;
  const tag = nextTag(probe);
  setTag(probe, preparedId, tag);
  scriptReply(probe, tag, 0, `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs('first answer ' + stamp)}")`);
  scriptReply(probe, tag, 0, `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs('second answer ' + stamp)}")`);
  await requireFreeSlot(config);
  const { context, page } = await signedInAt(browser, config, START_URL);
  try {
    await sendAndAwait(page, first, `first answer ${stamp}`);
    await sendAndAwait(page, second, `second answer ${stamp}`);
    await page.click('.ocu-panel-new-conversation');
    await page.waitForFunction(() => document.querySelector('.ocu-panel-message-user') === null, {
      timeout: config.navigationTimeoutMs,
    });

    await page.goto(`${config.origin}${LIST_URL}`, { waitUntil: 'networkidle2' });
    await page.waitForFunction(
      (wanted) =>
        [...document.querySelectorAll('[role="row"]')].some((row) =>
          [...row.querySelectorAll('[role="gridcell"]')].some((cell) => cell.textContent?.trim() === wanted)
        ),
      { timeout: config.navigationTimeoutMs },
      first
    );
    await page.evaluate((wanted) => {
      const row = [...document.querySelectorAll('[role="row"]')].find((candidate) =>
        [...candidate.querySelectorAll('[role="gridcell"]')].some((cell) => cell.textContent?.trim() === wanted)
      );
      row.querySelector('a.ocu-data-table-link').click();
    }, first);

    await page.waitForFunction(() => window.location.pathname.startsWith('/ocupilot/agent/transcripts/details/'), {
      timeout: config.navigationTimeoutMs,
    });
    await page.waitForFunction(
      () => document.querySelectorAll('app-transcript-page .ocu-panel-message-user').length === 2,
      { timeout: config.navigationTimeoutMs }
    );
    const shown = await page.evaluate(() => ({
      messages: [...document.querySelectorAll('app-transcript-page .ocu-panel-message-user')].map((node) => node.textContent.trim()),
      replies: [...document.querySelectorAll('app-transcript-page app-reply')].map((node) => node.textContent.trim()),
      withheld: document.querySelector('app-transcript-page .ocu-transcript-withheld') !== null,
    }));
    assert.deepEqual(shown.messages, [first, second], 'both messages, in order');
    assert.deepEqual(shown.replies, [`first answer ${stamp}`, `second answer ${stamp}`], 'and both replies');
    assert.equal(shown.withheld, false, 'nothing is withheld from the owner');

    await page.click('app-transcript-page .ocu-transcript-context-toggle');
    await page.waitForSelector('app-transcript-page .ocu-transcript-context-route', { timeout: config.navigationTimeoutMs });
    const route = await page.$eval('app-transcript-page .ocu-transcript-context-route', (node) => node.textContent.trim());
    assert.equal(route, 'os-management/processes', 'the first turn carries the screen context it was sent with');
    const payload = await page.$eval('app-transcript-page .ocu-transcript-context-payload', (node) => node.textContent);
    assert.ok(payload.includes('"route"'), 'shown as the stored payload text');

    // Mutation (Rule 19): pass "" for the definition in `Job.AppendConvoEntry` -> the stored entry
    // names no definition and this goes red.
    const stored = markerValue(
      runIris(config.container, [
        `Set rs=##class(%SQL.Statement).%ExecDirect(,"SELECT DefinitionId FROM OcuPilot_Kernel_State.Entry WHERE %EXACT(Message) = ?","${escapeOs(first)}")`,
        'Write "OCU-TRDEF-START:",$Select(rs.%Next():rs.%GetData(1),1:"none"),":OCU-TRDEF-END",!',
      ]),
      'TRDEF'
    );
    assert.equal(stored, String(preparedId), 'the entry records the definition the turn ran under, which its retention reads');
  } finally {
    await context.close();
    forgetTag(probe, tag);
  }
});

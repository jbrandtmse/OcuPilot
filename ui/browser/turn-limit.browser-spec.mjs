/**
 * The turns-an-hour limit in a real browser, against the throwaway instance (Story 14.6, AD-41).
 *
 * Two claims, each on rendered DOM:
 *
 * 1. **AC1 on Switches**: an administrator sets agent turns per user an hour to 1 and saves; a
 *    reload shows 1, and the concurrent field reads 1, read-only, described by its reason.
 * 2. **AC3 and the integration AC in the panel**: with a limit of one, a first Send completes and a
 *    second is refused by the instance -- the panel shows the published banner with the instance's
 *    `retryAt` in the browser's own time zone (emulated as `Asia/Kolkata`, UTC+05:30, so a UTC
 *    rendering cannot pass), and the refused turn's line under its message.
 *
 * **It refuses the live container**: it writes the instance's switches and arms the `turnprobe`
 * provider. `after` puts the limit back to none and forgets the account's start records, whatever
 * happened before it; `resetRememberedState` does the first on every spec's sign-in as well.
 *
 * Run: `npm run build`, `docker cp` the bundle into the throwaway, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test browser/turn-limit.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { authHeader as sharedAuthHeader, saveAndSettle } from './panel-spec.mjs';
import { resetRememberedState, resetTurnLimit } from './preferences-reset.mjs';
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

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const probe = { container: config.container, marker: 'TURNLIMIT' };

const SWITCHES_URL = '/ocupilot/agent/switches?ns=HSCUSTOM';
const HOME_URL = '/ocupilot/?ns=HSCUSTOM';
const SWITCHES_PATH = '/api/ocupilot/agent/switches';
const TURN_PATH = '/api/ocupilot/turn';

/** A zone whose offset has a half hour, so neither the hours nor the minutes of UTC pass. */
const TIME_ZONE = 'Asia/Kolkata';

let browser = null;
let preparedId = '';
let priorDefault = '';

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec writes the switches and arms the turnprobe provider, so it never runs inside the live container');
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
  try {
    await resetTurnLimit();
  } finally {
    try {
      forgetStarts();
    } finally {
      disarmProbeDefinition(probe, priorDefault);
    }
  }
});

/** Forget every start the signing-in account has on record, so an earlier spec's turns do not count. */
function forgetStarts() {
  const output = runIris(config.container, [
    `Set sc=##class(OcuPilot.Kernel.State.Turn).GuardedForgetStarts("${escapeOs(config.username)}")`,
    `Write "OCU-TURNLIMIT-FORGET-START:"_$System.Status.IsOK(sc)_":OCU-TURNLIMIT-FORGET-END",!`,
  ]);
  assert.equal(markerValue(output, 'TURNLIMIT-FORGET'), '1', `GuardedForgetStarts succeeded: ${output}`);
}

/** Store a limit over the shipped route, at the version a fresh read answers. */
async function setLimit(limit) {
  const read = await fetch(`${config.origin}${SWITCHES_PATH}`, { headers: { Authorization: sharedAuthHeader(config) } });
  const current = await read.json();
  const answer = await fetch(`${config.origin}${SWITCHES_PATH}`, {
    method: 'PUT',
    headers: { Authorization: sharedAuthHeader(config), 'Content-Type': 'application/json' },
    body: JSON.stringify({ turnsPerHour: limit, rowVersion: current.rowVersion }),
  });
  assert.equal(answer.status, 200, `the limit was stored: ${await answer.text()}`);
}

/** A fresh context in `TIME_ZONE`, signed in through the shell's own form, landed at `url`. */
async function signedInAt(url) {
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  await page.emulateTimezone(TIME_ZONE);
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  await page.setViewport(config.viewport);
  await page.goto(`${config.origin}${url}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', config.username);
  await page.type('#ocu-signin-password', config.password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, url);
  return { context, page };
}

test('AC1: an administrator sets turns an hour on Switches, a reload reads it back, and the concurrent bound is read-only with its reason', async () => {
  const { context, page } = await signedInAt(SWITCHES_URL);
  try {
    await page.waitForSelector('#ocu-switches-turnsPerHour', { visible: true, timeout: config.navigationTimeoutMs });
    await page.click('#ocu-switches-turnsPerHour', { clickCount: 3 });
    await page.keyboard.press('Backspace');
    await page.type('#ocu-switches-turnsPerHour', '1');
    await saveAndSettle(page, config);

    await page.reload({ waitUntil: 'networkidle2' });
    await page.waitForSelector('#ocu-switches-turnsPerHour', { visible: true, timeout: config.navigationTimeoutMs });
    await page.waitForFunction(() => document.querySelector('#ocu-switches-turnsPerHour').value === '1', {
      timeout: config.navigationTimeoutMs,
    });
    const concurrent = await page.$eval('#ocu-switches-concurrentTurns', (input) => ({
      value: input.value,
      readOnly: input.readOnly,
      reason: document.getElementById(input.getAttribute('aria-describedby') ?? '')?.textContent?.trim() ?? '',
    }));
    assert.deepEqual(concurrent, { value: '1', readOnly: true, reason: STRINGS.agentSwitchesConcurrentTurnsReason });
    const stored = await (await fetch(`${config.origin}${SWITCHES_PATH}`, { headers: { Authorization: sharedAuthHeader(config) } })).json();
    assert.equal(stored.turnsPerHour, 1, 'the instance holds the saved limit');
  } finally {
    await context.close();
    await resetTurnLimit();
  }
});

test('AC3: past the limit the instance refuses the Send, and the panel shows the banner in local time and the refused line', async () => {
  const tag = nextTag(probe);
  setTag(probe, preparedId, tag);
  scriptReply(probe, tag, 0, '##class(OcuPilot.Test.TurnProvider).TextReply("done")');
  const { context, page } = await signedInAt(HOME_URL);
  try {
    // After the sign-in, whose reset puts the limit back to none.
    forgetStarts();
    await setLimit(1);
    await page.waitForFunction(() => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'), {
      timeout: config.navigationTimeoutMs,
    });
    await page.type('#ocu-panel-composer', 'first');
    await page.click('.ocu-panel-send');
    await page.waitForFunction(
      () => (document.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '') === 'done',
      { timeout: config.navigationTimeoutMs }
    );
    await page.waitForFunction((label) => document.querySelector('.ocu-panel-send')?.textContent?.trim() === label, {
      timeout: config.navigationTimeoutMs,
    }, STRINGS.actionSend);

    await page.type('#ocu-panel-composer', 'second');
    const answered = page.waitForResponse(
      (response) => new URL(response.url()).pathname === TURN_PATH && response.request().method() === 'POST',
      { timeout: config.navigationTimeoutMs }
    );
    await page.click('.ocu-panel-send');
    const second = await answered;
    assert.equal(second.status(), 403, 'the instance answered the second Send 403');
    const refusal = await second.json();
    await page.waitForSelector('[data-slot="turn-limit"]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(refusal.code, 'TURN.LIMITHOUR', 'refused for the limit');
    assert.equal(refusal.detail.limit, 1);

    const retryAt = new Date(refusal.detail.retryAt);
    const local = new Intl.DateTimeFormat('en-GB', { timeZone: TIME_ZONE, hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }).format(retryAt);
    assert.equal(await page.evaluate(() => new Date().getTimezoneOffset()), -330, 'the page runs in the emulated zone');
    const banner = await page.$eval('[data-slot="turn-limit"]', (element) => ({
      role: element.getAttribute('role'),
      text: element.querySelector('.ocu-banner-message')?.textContent?.trim() ?? '',
    }));
    assert.deepEqual(banner, {
      role: 'alert',
      text: STRINGS.agentTurnLimitBanner.split('<n>').join('1').split('<hh:mm>').join(local),
    });
    const line = await page.$$eval('.ocu-panel-turn', (turns) => {
      const last = turns[turns.length - 1];
      return {
        message: last?.querySelector('.ocu-panel-message-user')?.textContent?.trim() ?? '',
        line: last?.querySelector('.ocu-panel-error-banner')?.textContent?.trim() ?? '',
      };
    });
    assert.deepEqual(line, { message: 'second', line: STRINGS.agentTurnLimitLine.split('<n>').join('1') });
    assert.equal(await page.$('[data-slot="send-error"]'), null, 'and no send-error banner');
  } finally {
    await context.close();
    forgetTag(probe, tag);
    await resetTurnLimit();
    forgetStarts();
  }
});

/**
 * The Guardrails screen in a real browser, against the throwaway instance (Story 16.22).
 *
 * 1. **AC1**: the side bar lists Guardrails after Switches; opened from there, the page lists under
 *    "Refused outright" one item per code `GET /ui/guardrails` answers, in that order, each with that
 *    row's sentence and code.
 * 2. **AC2**: with enforced read-only on and a row cap of 150, the page reads "Enforced read-only:
 *    on" and the kill-switch line of the caller's verdict, lists `permissions.users.delete` under the
 *    Users label, `permissions.users.password: Password` under "Never sent to the agent" with both
 *    sentences, and the limits line with 150, 65,536 and 1,000.
 * 3. **Story 18.12**: the last section is headed "Limits" and, with no turns-an-hour limit set, reads that
 *    turns are not limited (AC1); with turns an hour set to 7 on Switches, the line beneath the limits
 *    line names 7.
 * 4. **A failed read draws one alert (Story 23.11, DW-2449).** A read that cannot reach the instance is the shell's
 *    banner to say once, and the page adds nothing and reads again once the instance answers. A 404 is the page's own
 *    `FaultBanner` with Retry, and Retry reads again. The alert count is taken over the whole document.
 *
 * **It refuses the live container**: it writes the instance's switches, and restores them through
 * the shipped route in `after` and at the end of the leg that changed them. The fault legs only intercept their own
 * page's read.
 *
 * Run: `npm run test:browser` (after `npm run build` and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { authHeader as sharedAuthHeader, framesGoBy, interceptRead, readAlerts } from './panel-spec.mjs';
import { requireFreeSlot } from './turnprobe-spec.mjs';
import { resetRememberedState } from './preferences-reset.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS, stringFor } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));
const { SCREENS } = await import(join(uiRoot, 'src', 'app', 'core', 'screens.generated.ts'));

const config = browserConfig();
const SWITCHES_URL = '/ocupilot/agent/switches?ns=HSCUSTOM';
const SWITCHES_PATH = '/api/ocupilot/agent/switches';
const GUARDRAILS_PATH = '/api/ocupilot/ui/guardrails';

let browser = null;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec drives the throwaway, never the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser === null) return;
  await browser.close();
  browser = null;
  await restoreSwitches();
});

function authHeader() {
  return sharedAuthHeader(config);
}

/** Write the switches over HTTP, asserting the answer. */
async function setSwitches(body) {
  const answer = await fetch(`${config.origin}${SWITCHES_PATH}`, {
    method: 'PUT',
    headers: { Authorization: authHeader(), 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  assert.equal(answer.status, 200, `the switches were written: ${await answer.text()}`);
}

/** Put the switches back where a clean install leaves them. */
async function restoreSwitches() {
  await setSwitches({
    killSwitch: false,
    killSwitchReason: '',
    enforcedReadOnly: false,
    shareContextByDefault: true,
    contextRowCap: 200,
    turnsPerHour: 0,
  });
}

/** The route's own answer for the signed-in account. */
async function guardrailsAnswer() {
  const answer = await fetch(`${config.origin}${GUARDRAILS_PATH}`, { headers: { Authorization: authHeader() } });
  assert.equal(answer.status, 200, 'the guardrails route answers');
  return answer.json();
}

/** A fresh context signed in through the shell's own form, landed at `url`; `prepare` runs against the page first. */
async function signedInAt(url, { prepare = null } = {}) {
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  if (prepare !== null) await prepare(page);
  await page.goto(`${config.origin}${url}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', config.username);
  await page.type('#ocu-signin-password', config.password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, url);
  return { context, page };
}

/** Open Guardrails through the side bar, after asserting where it sits there. */
async function openFromSideBar(page) {
  await page.waitForSelector('app-side-bar .ocu-side-bar-label', { timeout: config.navigationTimeoutMs });
  const labels = await page.$$eval('app-side-bar .ocu-side-bar-label', (nodes) => nodes.map((node) => node.textContent.trim()));
  const switchesAt = labels.indexOf(STRINGS.agentSwitchesLabel);
  assert.ok(switchesAt >= 0, `the side bar lists Switches: ${JSON.stringify(labels)}`);
  assert.equal(labels[switchesAt + 1], STRINGS.agentGuardrailsLabel, 'and Guardrails right after it');
  await page.evaluate((label) => {
    const entry = Array.from(document.querySelectorAll('app-side-bar .ocu-side-bar-label')).find((node) => node.textContent.trim() === label);
    (entry.closest('button') ?? entry).click();
  }, STRINGS.agentGuardrailsLabel);
  await page.waitForFunction(() => new URL(window.location.href).pathname === '/ocupilot/agent/guardrails', {
    timeout: config.navigationTimeoutMs,
  });
  await page.waitForSelector('app-guardrails-page .ocu-guardrails-refused', { timeout: config.navigationTimeoutMs });
}

const textsOf = (page, selector) =>
  page.$$eval(selector, (nodes) => nodes.map((node) => node.textContent.replace(/\s+/g, ' ').trim()));

test('AC1: opened from the side bar after Switches, the page lists every refused code the route answers, in order, with its sentence', async () => {
  await restoreSwitches();
  const answer = await guardrailsAnswer();
  assert.ok(answer.prohibited.length > 0, 'the route answers refused codes');
  const { context, page } = await signedInAt(SWITCHES_URL);
  try {
    await openFromSideBar(page);
    const reasons = await textsOf(page, 'app-guardrails-page .ocu-guardrails-refused .ocu-guardrails-reason');
    const codes = await textsOf(page, 'app-guardrails-page .ocu-guardrails-refused .ocu-guardrails-code');
    assert.deepEqual(codes, answer.prohibited.map((row) => row.code), 'one item per code, in the answer\'s order');
    assert.deepEqual(reasons, answer.prohibited.map((row) => row.reason), 'each with that row\'s sentence');
    assert.deepEqual(await readAlerts(page, 'app-guardrails-page'), [], 'and no alert, in the page or the shell');
    const headings = await textsOf(page, 'app-guardrails-page h2');
    assert.equal(headings.at(-1), STRINGS.agentGuardrailsLimitsHeading, 'the last section is headed Limits');
    assert.deepEqual(await textsOf(page, 'app-guardrails-page .ocu-guardrails-turns'), [STRINGS.agentGuardrailsTurnsNone], 'and with no turns-an-hour limit set it reads that turns are not limited');
  } finally {
    await context.close();
  }
});

test('AC2: with enforced read-only on and a row cap of 150, the page reads both, the Users tools, the password secret and the limits', async () => {
  await setSwitches({ enforcedReadOnly: true, contextRowCap: 150 });
  try {
    const answer = await guardrailsAnswer();
    assert.equal(answer.switches.enforcedReadOnly, true, 'the route reads enforced read-only on');
    const { context, page } = await signedInAt(SWITCHES_URL);
    try {
      await openFromSideBar(page);
      assert.deepEqual(await textsOf(page, 'app-guardrails-page .ocu-guardrails-read-only'), [STRINGS.agentGuardrailsReadOnlyOn]);
      assert.equal(answer.switches.killSwitch, false, 'the route reads the kill switch off for this caller');
      assert.deepEqual(await textsOf(page, 'app-guardrails-page .ocu-guardrails-kill-switch'), [STRINGS.agentGuardrailsKillSwitchOff]);

      const users = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.UserList');
      const usersLabel = stringFor(users.labelKey);
      const usersTools = await page.$$eval(
        'app-guardrails-page .ocu-guardrails-group',
        (groups, label) => {
          const group = groups.find((node) => node.querySelector('.ocu-guardrails-group-heading')?.textContent.trim() === label);
          return group === undefined ? null : Array.from(group.querySelectorAll('code')).map((node) => node.textContent.trim());
        },
        usersLabel
      );
      assert.ok(usersTools !== null, `a group is headed ${usersLabel}`);
      assert.ok(usersTools.includes('permissions.users.delete'), 'permissions.users.delete is under the Users label');

      const never = await textsOf(page, 'app-guardrails-page section[aria-labelledby="ocu-guardrails-never"] .ocu-guardrails-line');
      assert.deepEqual(never, [STRINGS.agentGuardrailsNeverSecrets, STRINGS.agentGuardrailsNeverErrorVariables], 'both sentences');
      const secrets = await textsOf(page, 'app-guardrails-page .ocu-guardrails-secrets .ocu-guardrails-item');
      assert.ok(secrets.includes('permissions.users.password: Password'), `the password tool's secret is listed: ${JSON.stringify(secrets)}`);

      const [limits] = await textsOf(page, 'app-guardrails-page .ocu-guardrails-limits');
      const expected = STRINGS.agentGuardrailsContextLimits.replace('<rows>', '150').replace('<total>', '65,536').replace('<field>', '1,000');
      assert.equal(limits, expected, 'the limits line reads 150, 65,536 and 1,000');
    } finally {
      await context.close();
    }
  } finally {
    await restoreSwitches();
  }
});

test('Story 18.12: with turns an hour set to 7 on Switches, the Limits section names 7 beneath the limits line', async () => {
  await restoreSwitches();
  // The limit is set after sign-in: `signedInAt` clears a turns-an-hour limit already set, which would refuse other specs' Sends.
  const { context, page } = await signedInAt(SWITCHES_URL);
  try {
    await setSwitches({ turnsPerHour: 7 });
    const answer = await guardrailsAnswer();
    assert.equal(answer.limits.turnsPerHour, 7, 'the route reads turns an hour 7');
    await openFromSideBar(page);
    assert.deepEqual(
      await textsOf(page, 'app-guardrails-page .ocu-guardrails-turns'),
      [STRINGS.agentGuardrailsTurnsLimit.replace('<n>', '7')],
      'the turns line names 7'
    );
    assert.equal(
      await page.$eval('app-guardrails-page .ocu-guardrails-limits + .ocu-guardrails-turns', (node) => node.tagName),
      'P',
      'directly beneath the limits line'
    );
  } finally {
    await context.close();
    await restoreSwitches();
  }
});

const GUARDRAILS_URL = '/ocupilot/agent/guardrails?ns=HSCUSTOM';

/** The page's own sections, which a failed read leaves undrawn. */
const SECTION = 'app-guardrails-page .ocu-guardrails-refused';

test('a Guardrails read that cannot reach the instance leaves the shell\'s banner as the one alert, and reads again once the instance answers', async () => {
  // Mutation (Rule 19): answer the banner fault from `inPlaceFault` in `guardrails.page.ts`, rebuild and redeploy ->
  // the page draws an alert of its own beside the shell's banner and the count below reads two. Drop the
  // `retryWhenReachable` park from `Guardrails.load`, or the `connectivity` argument from `main.ts` -> the sections
  // never return once the instance answers, and the last wait times out.
  const control = { path: GUARDRAILS_PATH, mode: 'abort', hits: 0 };
  const { context, page } = await signedInAt(GUARDRAILS_URL, { prepare: interceptRead(control) });
  try {
    // The shell's banner is the answered signal: the failed read reports to it before the page learns of the failure.
    await page.waitForSelector('app-fault-banner .ocu-fault-banner', { timeout: config.navigationTimeoutMs });
    await page.waitForSelector('app-guardrails-page .ocu-guardrails-intro', { timeout: config.navigationTimeoutMs });
    await framesGoBy(page);
    assert.ok(control.hits >= 1, 'the page asked for the read this leg fails');

    assert.deepEqual(
      await readAlerts(page, 'app-guardrails-page'),
      [{ where: 'shell', message: STRINGS.connectivityBannerUnreachable, actions: [STRINGS.actionRetry] }],
      'one alert in the whole document, and it is the shell\'s unreachable banner'
    );
    assert.equal(await page.$('app-guardrails-page .ocu-fault-banner'), null, 'and the page draws no banner of its own');
    assert.equal(await page.$(SECTION), null, 'and no section, since nothing the instance said is on screen');

    // The instance answers again: the parked read runs at the next answer and the sections replace the empty page.
    control.mode = null;
    await page.waitForSelector(SECTION, { timeout: config.navigationTimeoutMs });
    // The shell's banner stays mounted for a moment after its fault clears, so the count is taken once it is gone.
    await page.waitForSelector('app-fault-banner .ocu-fault-banner', { hidden: true, timeout: config.navigationTimeoutMs });
    assert.deepEqual(await readAlerts(page, 'app-guardrails-page'), [], 'no alert stands once the read answers');
  } finally {
    await context.close();
  }
});

test('a Guardrails read the instance answers with a 500 leaves the shell\'s banner as the one alert, and the banner\'s Retry reads again', async () => {
  // Mutation (Rule 19): make `inPlaceFault` in `guardrails.page.ts` draw every fault but an unreachable one, rebuild and
  // redeploy -> the page draws a banner of its own beside the shell's and the count below reads two. Drop the
  // `retryWhenReachable` park from `Guardrails.load` -> the sections never return after the shell's Retry, and the last
  // wait times out.
  const control = { path: GUARDRAILS_PATH, mode: 'fault', hits: 0 };
  const { context, page } = await signedInAt(GUARDRAILS_URL, { prepare: interceptRead(control) });
  try {
    // A 5xx arms no probe, so the shell's banner stays until something answers; its own Retry is what asks.
    await page.waitForSelector('app-fault-banner .ocu-fault-banner[data-fault="server-fault"]', { timeout: config.navigationTimeoutMs });
    await page.waitForSelector('app-guardrails-page .ocu-guardrails-intro', { timeout: config.navigationTimeoutMs });
    await framesGoBy(page);
    assert.ok(control.hits >= 1, 'the page asked for the read this leg fails');

    assert.deepEqual(
      await readAlerts(page, 'app-guardrails-page'),
      [{ where: 'shell', message: STRINGS.connectivityServerFault, actions: [STRINGS.actionRetry, STRINGS.actionOpenMessagesLog] }],
      'one alert in the whole document, and it is the shell\'s generic banner'
    );
    assert.equal(await page.$('app-guardrails-page .ocu-fault-banner'), null, 'and the page draws no banner of its own');
    assert.equal(await page.$(SECTION), null, 'and no section, since nothing the instance said is on screen');

    // The instance answers again; the shell's Retry probes, and the answer runs the parked read.
    control.mode = null;
    await page.evaluate((retry) => {
      const page = document.querySelector('app-guardrails-page');
      const banner = Array.from(document.querySelectorAll('app-fault-banner .ocu-fault-banner')).find((candidate) => !page.contains(candidate));
      Array.from(banner.querySelectorAll('button')).find((button) => button.textContent.trim() === retry).click();
    }, STRINGS.actionRetry);
    await page.waitForSelector(SECTION, { timeout: config.navigationTimeoutMs });
    await page.waitForSelector('app-fault-banner .ocu-fault-banner', { hidden: true, timeout: config.navigationTimeoutMs });
    assert.deepEqual(await readAlerts(page, 'app-guardrails-page'), [], 'no alert stands once the read answers');
  } finally {
    await context.close();
  }
});

test('a Guardrails read the instance answers with a 404 shows the page\'s own alert, and Retry reads again', async () => {
  // Mutation (Rule 19): make `inPlaceFault` answer `null` for every fault, rebuild and redeploy -> the page draws
  // no banner and the first wait below times out.
  const control = { path: GUARDRAILS_PATH, mode: 'absent', hits: 0 };
  const { context, page } = await signedInAt(GUARDRAILS_URL, { prepare: interceptRead(control) });
  try {
    // The page's own banner is the answered signal: a 404 raises nothing in the shell.
    await page.waitForSelector('app-guardrails-page .ocu-fault-banner', { timeout: config.navigationTimeoutMs });
    await framesGoBy(page);
    assert.ok(control.hits >= 1, 'the page asked for the read this leg fails');
    assert.deepEqual(
      await readAlerts(page, 'app-guardrails-page'),
      [{ where: 'surface', message: STRINGS.connectivityServerFault, actions: [STRINGS.actionRetry, STRINGS.actionOpenMessagesLog] }],
      'one alert in the whole document, inside the page, with the generic sentence and both actions'
    );
    assert.equal(await page.$(SECTION), null, 'and no section beside it');

    // The instance answers again; Retry reads again and the sections replace the alert.
    control.mode = null;
    await page.evaluate((retry) => {
      const button = Array.from(document.querySelectorAll('app-guardrails-page .ocu-fault-banner button')).find((candidate) => candidate.textContent.trim() === retry);
      button.click();
    }, STRINGS.actionRetry);
    await page.waitForSelector(SECTION, { timeout: config.navigationTimeoutMs });
    await framesGoBy(page);
    assert.deepEqual(await readAlerts(page, 'app-guardrails-page'), [], 'the alert is gone once the read answers');
    assert.equal(await page.$('app-guardrails-page .ocu-fault-banner'), null, 'and so is the banner');
  } finally {
    await context.close();
  }
});

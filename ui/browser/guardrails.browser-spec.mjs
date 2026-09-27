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
 *
 * **It refuses the live container**: it writes the instance's switches, and restores them through
 * the shipped route in `after` and at the end of the leg that changed them.
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
import { authHeader as sharedAuthHeader } from './panel-spec.mjs';
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
  });
}

/** The route's own answer for the signed-in account. */
async function guardrailsAnswer() {
  const answer = await fetch(`${config.origin}${GUARDRAILS_PATH}`, { headers: { Authorization: authHeader() } });
  assert.equal(answer.status, 200, 'the guardrails route answers');
  return answer.json();
}

/** A fresh context signed in through the shell's own form, landed at `url`. */
async function signedInAt(url) {
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
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
    assert.equal(await page.$('app-guardrails-page .ocu-guardrails-fault'), null, 'and no fault line');
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

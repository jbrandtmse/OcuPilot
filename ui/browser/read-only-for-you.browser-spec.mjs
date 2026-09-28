/**
 * The panel's "Read-only for me" switch in a real browser, against the throwaway instance
 * (Story 14.5).
 *
 * Three claims, each on rendered DOM and on the instance's own answer rather than on store state:
 *
 * 1. **AC1**: pressing the switch stores the choice on the instance, and the footer line it is
 *    described by reads "Read-only: on -- for you" once the instance has answered.
 * 2. **AC3**: a separate HTTP client and a fresh browser context both read the choice on, because
 *    it lives on the instance (AD-50) rather than in the browser.
 * 3. **AC2**: under enforced read-only the switch reads on and is `aria-disabled`, and a press
 *    changes nothing and sends nothing.
 *
 * **Every context resets the account's remembered state first**, as every spec here does. The AC3
 * leg's second context keeps the read-only choice through that reset (`keepReadOnlyForYou`),
 * because reading what the first context stored is the claim.
 *
 * **It refuses the live container**, for the reason its siblings do: it writes the instance's
 * switches and the signing-in account's read-only choice. `after` restores both and asserts the
 * choice reads off, because a choice left on blocks every later spec's agent writes.
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
import { resetReadOnlyForYou, resetRememberedState } from './preferences-reset.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const HOME_URL = '/ocupilot/?ns=HSCUSTOM';
const SWITCHES_PATH = '/api/ocupilot/agent/switches';
const RESTRAINT_PATH = '/api/ocupilot/agent/restraint';

const SWITCH = 'input.ocu-read-only-switch';
const FOOTER = '.ocu-panel-read-only';

let browser = null;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec drives the throwaway, never the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser === null) return;
  await browser.close();
  browser = null;
  await setSwitches({ killSwitch: false, killSwitchReason: '', enforcedReadOnly: false });
  await resetReadOnlyForYou();
  const left = await restraint();
  assert.equal(left.readOnlyForYou, false, 'the spec leaves the account\'s read-only choice off');
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

/** The signing-in account's verdict, read by a client that is not the browser. */
async function restraint() {
  const answer = await fetch(`${config.origin}${RESTRAINT_PATH}`, { headers: { Authorization: authHeader() } });
  const text = await answer.text();
  assert.equal(answer.status, 200, `the restraint read answers: ${text}`);
  return JSON.parse(text);
}

/**
 * A fresh context signed in through the shell's own form, landed at `url`, after the account's
 * remembered state is reset -- keeping its read-only choice when `keepReadOnlyForYou` is set.
 */
async function signedInAt(url, keepReadOnlyForYou = false) {
  await resetRememberedState({ keepReadOnlyForYou });
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

/** Wait until the footer line reads `expected`. */
async function footerReads(page, expected) {
  await page.waitForFunction(
    (selector, text) => document.querySelector(selector)?.textContent?.trim() === text,
    { timeout: config.navigationTimeoutMs },
    FOOTER,
    expected
  );
}

/** The switch's rendered state. */
function switchState(page) {
  return page.$eval(SWITCH, (node) => ({
    checked: node.checked,
    ariaDisabled: node.getAttribute('aria-disabled'),
    name: node.getAttribute('aria-label'),
    describedBy: node.getAttribute('aria-describedby'),
    footerId: document.querySelector('.ocu-panel-read-only')?.id ?? '',
  }));
}

test('AC1, AC3: the switch stores the choice, the footer says so, and a fresh context and another client read it on', async () => {
  await setSwitches({ killSwitch: false, killSwitchReason: '', enforcedReadOnly: false });
  const first = await signedInAt(HOME_URL);
  try {
    await first.page.waitForSelector(SWITCH, { visible: true, timeout: config.navigationTimeoutMs });
    const off = await switchState(first.page);
    assert.equal(off.checked, false, 'the switch starts off');
    assert.equal(off.name, STRINGS.agentReadOnlyForYouLabel, 'named "Read-only for me"');
    assert.equal(off.describedBy, off.footerId, 'and described by the footer line');
    await footerReads(first.page, STRINGS.statusReadOnlyOff);

    await first.page.click(SWITCH);
    await footerReads(first.page, STRINGS.statusReadOnlyForYou);
    assert.equal((await switchState(first.page)).checked, true, 'the switch follows the instance on');

    const stored = await restraint();
    assert.equal(stored.readOnlyForYou, true, `another client reads the choice on: ${JSON.stringify(stored)}`);
    assert.equal(stored.code, 'AGENT.READONLY.USER', 'and the verdict blocks under the per-user code');
  } finally {
    await first.context.close();
  }

  const second = await signedInAt(HOME_URL, true);
  try {
    await second.page.waitForSelector(SWITCH, { visible: true, timeout: config.navigationTimeoutMs });
    await footerReads(second.page, STRINGS.statusReadOnlyForYou);
    assert.equal((await switchState(second.page)).checked, true, 'a fresh context reads the choice on');

    await second.page.click(SWITCH);
    await footerReads(second.page, STRINGS.statusReadOnlyOff);
    assert.equal((await restraint()).readOnlyForYou, false, 'and turning it off there is stored');
  } finally {
    await second.context.close();
    await resetReadOnlyForYou();
  }
});

test('AC2: under enforced read-only the switch reads on, is aria-disabled, and a press sends nothing', async () => {
  await setSwitches({ enforcedReadOnly: true });
  const { context, page } = await signedInAt(HOME_URL);
  try {
    const puts = [];
    page.on('request', (request) => {
      if (request.method() === 'PUT' && new URL(request.url()).pathname === RESTRAINT_PATH) puts.push(request.url());
    });
    await page.waitForSelector(SWITCH, { visible: true, timeout: config.navigationTimeoutMs });
    await footerReads(page, STRINGS.statusReadOnlyEnforced);
    const held = await switchState(page);
    assert.equal(held.checked, true, 'the switch reads on');
    assert.equal(held.ariaDisabled, 'true', 'and is aria-disabled');

    await page.click(SWITCH);
    // A press that sent anything would land within a round trip; give it several.
    await new Promise((resolve) => setTimeout(resolve, 1000));
    assert.equal((await switchState(page)).checked, true, 'the press changed nothing');
    assert.deepEqual(puts, [], 'and sent nothing');
    await footerReads(page, STRINGS.statusReadOnlyEnforced);

    const answer = await fetch(`${config.origin}${RESTRAINT_PATH}`, {
      method: 'PUT',
      headers: { Authorization: authHeader(), 'Content-Type': 'application/json' },
      body: JSON.stringify({ readOnly: false }),
    });
    const body = await answer.json();
    assert.equal(answer.status, 200, `a PUT false is accepted: ${JSON.stringify(body)}`);
    assert.equal(body.code, 'AGENT.READONLY.ENFORCED', 'and the verdict stays enforced');
  } finally {
    await context.close();
    await setSwitches({ killSwitch: false, killSwitchReason: '', enforcedReadOnly: false });
  }
});

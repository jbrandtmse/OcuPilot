/**
 * The Switches screen in a real browser, against the throwaway instance (Story 3.7).
 *
 * Three claims, each on rendered DOM and the real URL rather than on store state:
 *
 * 1. **DW-369 end to end**: two `form-page` screens, two different pages. The Switches route
 *    renders the Switches controls and the Definition form route renders the definition's, which
 *    is what a map keyed by archetype alone could not do.
 * 2. **The whole vertical answers**: a switch flipped in the browser reaches the instance, the
 *    read gives it back, and the panel's own footer line follows it -- the client reading the
 *    server's verdict rather than its own buffer.
 * 3. **The kill switch reaches every surface it is published on**: the panel's banner with the
 *    operator's reason, and the rail's attention dot.
 *
 * **It refuses the live container**, for the reason its siblings do: this spec writes the
 * instance's switches. It restores them in `after`, through the shipped routes, so the agent is
 * left switched on and unrestrained. The switch row itself survives -- writing one is what a PUT
 * does -- which is why the spec runs only against a container that is then discarded.
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

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));
const { formatKillSwitch } = await import(join(uiRoot, 'src', 'app', 'core', 'agent-status.ts'));

const config = browserConfig();
const SWITCHES_URL = '/ocupilot/agent/switches?ns=HSCUSTOM';
const FORM_URL = '/ocupilot/agent/definitions/edit?ns=HSCUSTOM';
const SWITCHES_PATH = '/api/ocupilot/agent/switches';

/** The reason this spec writes, so an assertion can tell it from anything else on the instance. */
const REASON = 'OcuPilotBrowserProbe: switched off for this run';

let browser = null;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec drives the throwaway, never the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  await restoreSwitches();
  if (browser !== null) await browser.close();
});

function authHeader() {
  return 'Basic ' + Buffer.from(`${config.username}:${config.password}`).toString('base64');
}

/**
 * Put the instance's switches back where a clean install leaves them.
 *
 * It asserts its own answer: a restore that failed silently would leave the next leg -- or the
 * next spec file sharing this container -- starting from an agent that is switched off, and the
 * failure would surface as an unrelated assertion somewhere else.
 */
async function restoreSwitches() {
  const answer = await fetch(`${config.origin}${SWITCHES_PATH}`, {
    method: 'PUT',
    headers: { Authorization: authHeader(), 'Content-Type': 'application/json' },
    body: JSON.stringify({
      killSwitch: false,
      killSwitchReason: '',
      enforcedReadOnly: false,
      shareContextByDefault: true,
    }),
  });
  assert.equal(answer.status, 200, `the switches were restored: ${await answer.text()}`);
}

/** Write the switches over HTTP, so a browser leg starts from a state it did not have to type. */
async function setSwitches(body) {
  const answer = await fetch(`${config.origin}${SWITCHES_PATH}`, {
    method: 'PUT',
    headers: { Authorization: authHeader(), 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  assert.equal(answer.status, 200, `the switches were written: ${await answer.text()}`);
}

/** A fresh context signed in through the shell's own form, landed at `url`. */
async function signedInAt(url) {
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

test('DW-369: the two form-page screens render two different pages, each at its own route', async () => {
  await restoreSwitches();
  const { context, page } = await signedInAt(SWITCHES_URL);
  try {
    await page.waitForSelector('#ocu-switches-kill', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(new URL(page.url()).pathname, '/ocupilot/agent/switches');
    // The Switches controls, and none of the Definition form's.
    assert.ok(await page.$('#ocu-switches-read-only'), 'the enforced-read-only toggle is on screen');
    assert.equal(await page.$('#ocu-definition-name'), null, 'and the definition form is not');

    // The other form-page route still renders its own page, which is the half a map keyed by
    // archetype alone would have got wrong the moment a second screen took that archetype.
    await page.goto(`${config.origin}${FORM_URL}`, { waitUntil: 'networkidle2' });
    await page.waitForSelector('#ocu-definition-name', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$('#ocu-switches-kill'), null, 'and Switches is not on the definition form');
  } finally {
    await context.close();
  }
});

test('AC2: a switch flipped in the browser reaches the instance, and the panel footer line follows it', async () => {
  await restoreSwitches();
  const { context, page } = await signedInAt(SWITCHES_URL);
  try {
    await page.waitForSelector('#ocu-switches-read-only', { visible: true, timeout: config.navigationTimeoutMs });
    // The panel is drawn on this throwaway because nothing is configured, so its footer line is
    // on screen before anything is flipped.
    await page.waitForSelector('.ocu-panel-read-only', { timeout: config.navigationTimeoutMs });
    assert.equal(
      await page.$eval('.ocu-panel-read-only', (node) => node.textContent.trim()),
      STRINGS.statusReadOnlyOff,
      'the footer line starts at the off key'
    );

    await page.click('#ocu-switches-read-only');
    await page.click('.ocu-form-bar-actions .ocu-button-primary');
    // The instance is what decides: the footer line moves only once the read that follows the
    // change event has answered.
    await page.waitForFunction(
      (expected) => document.querySelector('.ocu-panel-read-only')?.textContent?.trim() === expected,
      { timeout: config.navigationTimeoutMs },
      STRINGS.statusReadOnlyEnforced
    );
    assert.ok(
      await page.$eval('.ocu-panel-banner', (node) => node.textContent),
      'and the panel carries a banner'
    );
    const banners = await page.$$eval('.ocu-panel-banner', (nodes) =>
      nodes.map((node) => node.textContent.trim())
    );
    assert.ok(
      banners.some((text) => text.includes(STRINGS.agentReadOnlyEnforcedBanner)),
      `the published enforced banner is among them: ${JSON.stringify(banners)}`
    );

    // And the instance really holds it, read back through the route rather than from the screen.
    const stored = await (
      await fetch(`${config.origin}${SWITCHES_PATH}`, { headers: { Authorization: authHeader() } })
    ).json();
    assert.equal(stored.enforcedReadOnly, true, 'the instance holds the switch the browser flipped');
  } finally {
    await context.close();
  }
});

test('AC3, AC4: the kill switch reaches the panel banner and the rail dot, with the operator\'s reason', async () => {
  await setSwitches({ killSwitch: true, killSwitchReason: REASON, enforcedReadOnly: false });
  const { context, page } = await signedInAt(SWITCHES_URL);
  try {
    await page.waitForSelector('.ocu-panel-banner', { timeout: config.navigationTimeoutMs });
    const expected = formatKillSwitch(STRINGS.agentKillSwitchBanner, 'everyone', REASON);
    const banners = await page.$$eval('.ocu-panel-banner', (nodes) =>
      nodes.map((node) => node.textContent.trim())
    );
    assert.ok(
      banners.some((text) => text.includes(expected)),
      `the published kill-switch banner, with the operator's reason: ${JSON.stringify(banners)}`
    );

    // The rail's attention dot names the same sentence, and the rail item's own description
    // carries it too (DW-383) -- the reason reaching the item, not only the badge.
    await page.waitForSelector('.ocu-rail-dot', { timeout: config.navigationTimeoutMs });
    const rail = await page.evaluate(() => {
      const dot = document.querySelector('.ocu-rail-dot');
      const slot = dot.closest('.ocu-rail-slot');
      const button = slot.querySelector('.ocu-rail-item');
      const tip = document.getElementById(button.getAttribute('aria-describedby'));
      return {
        dotName: dot.getAttribute('aria-label'),
        buttonName: button.getAttribute('aria-label'),
        tooltip: tip?.textContent?.trim() ?? '',
      };
    });
    assert.equal(rail.dotName, expected, 'the dot is named for the reason');
    assert.equal(rail.buttonName, STRINGS.navAreaAgent, "and the button's own name is still the area's");
    assert.ok(rail.tooltip.includes(REASON), `the item's description carries the reason: ${rail.tooltip}`);
  } finally {
    await context.close();
  }
});

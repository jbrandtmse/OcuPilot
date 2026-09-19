/**
 * The Switches screen in a real browser, against the throwaway instance (Story 3.7).
 *
 * Four claims, each on rendered DOM and the real URL rather than on store state:
 *
 * 1. **DW-369 end to end**: two `form-page` screens, two different pages. The Switches route
 *    renders the Switches controls and the Definition form route renders the definition's, which
 *    is what a map keyed by archetype alone could not do.
 * 2. **The whole vertical answers**: a switch flipped in the browser reaches the instance, the
 *    read gives it back, and the panel's own footer line follows it -- the client reading the
 *    server's verdict rather than its own buffer.
 * 3. **The kill switch reaches every surface it is published on**: the panel's banner with the
 *    operator's reason, and the rail's attention dot.
 * 4. **And it restrains the agent, not the product**: with the switch on, a route in another area
 *    and the other form-page route both still render, which is AC3's last clause.
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
import { requireFreeSlot } from './turnprobe-spec.mjs';

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
  // This spec arms no probe, but it saves the Switches form -- and a save made while an earlier
  // spec's turn still holds this user's one slot (AD-41) is refused, after which the form's own
  // wait dies on a bare thirty-second timeout naming none of that. DW-1167: the guard is the
  // shared one, not a third copy.
  await requireFreeSlot(config);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  // The browser closes first, and the restore runs only if `before` got far enough to open one.
  // Ordered the other way round, a `before` that failed its readiness assertion -- or a throwaway
  // that is simply gone -- made the teardown throw its own error over the original one, which is
  // the failure shape CI's own comment describes for this job.
  if (browser === null) return;
  await browser.close();
  browser = null;
  await restoreSwitches();
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
      contextRowCap: 200,
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

    // AC3's last clause: "and every screen still loads". The kill switch restrains the agent, not
    // the product, so another screen mounts with it on -- and the banner is still up there, which
    // is what tells a screen that rendered under the kill switch from one that rendered because
    // the switch had been dropped.
    //
    // Navigated through the shell's own side bar rather than with a second `page.goto`: a fresh
    // document clears the token pair and re-fires the first-login gate (shell-entry.mjs), so a
    // deep link would land on the Definition form whatever it asked for.
    await page.waitForSelector('app-side-bar .ocu-side-bar-label', { timeout: config.navigationTimeoutMs });
    const moved = await page.evaluate((label) => {
      const entry = Array.from(document.querySelectorAll('app-side-bar .ocu-side-bar-label')).find(
        (node) => node.textContent.trim() === label
      );
      if (entry === undefined) return false;
      (entry.closest('a') ?? entry.closest('button') ?? entry).click();
      return true;
    }, STRINGS.agentDefinitionListLabel);
    assert.ok(moved, 'the area lists a second screen to navigate to');
    await page.waitForFunction(
      () => new URL(window.location.href).pathname === '/ocupilot/agent/definitions',
      { timeout: config.navigationTimeoutMs }
    );
    // The outlet swapped and the new screen actually mounted: the Switches page component is gone
    // and the list page's own component is in the outlet. `app-screen-outlet` itself is not the
    // subject -- it always holds its wrapper div, so counting its children asserts nothing.
    await page.waitForSelector('app-screen-outlet app-list-page', { timeout: config.navigationTimeoutMs });
    assert.equal(
      await page.$('app-screen-outlet app-switches-page'),
      null,
      'and the Switches page is no longer the one mounted'
    );
    const stillBannered = await page.$$eval('.ocu-panel-banner', (nodes) =>
      nodes.map((node) => node.textContent.trim())
    );
    assert.ok(
      stillBannered.some((text) => text.includes(expected)),
      `the second screen rendered with the kill switch still on: ${JSON.stringify(stillBannered)}`
    );
  } finally {
    await context.close();
  }
});

test('Story 4.4: the context row cap saves as a number and renders the server violation', async () => {
  await restoreSwitches();
  const { context, page } = await signedInAt(SWITCHES_URL);
  try {
    await page.waitForSelector('#ocu-switches-contextRowCap', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(
      await page.$eval('#ocu-switches-contextRowCap', (node) => node.value),
      '200',
      'the stored default renders on load'
    );

    await page.$eval('#ocu-switches-contextRowCap', (node) => {
      node.value = '500';
      node.dispatchEvent(new Event('input', { bubbles: true }));
    });
    await page.click('.ocu-form-bar-actions .ocu-button-primary');
    await page.waitForFunction(
      () => document.querySelector('#ocu-switches-contextRowCap')?.value === '500',
      { timeout: config.navigationTimeoutMs }
    );
    const stored = await (
      await fetch(`${config.origin}${SWITCHES_PATH}`, { headers: { Authorization: authHeader() } })
    ).json();
    assert.equal(stored.contextRowCap, 500, 'the instance holds the number the browser saved');

    // A refused value renders on its own field, not the reason field.
    await page.$eval('#ocu-switches-contextRowCap', (node) => {
      node.value = '5000';
      node.dispatchEvent(new Event('input', { bubbles: true }));
    });
    await page.click('.ocu-form-bar-actions .ocu-button-primary');
    await page.waitForSelector('#ocu-switches-contextRowCap-reason', { timeout: config.navigationTimeoutMs });
    const reason = await page.$eval('#ocu-switches-contextRowCap-reason', (node) => node.textContent.trim());
    assert.ok(reason.length > 0, 'the row-cap violation renders beside its own control');
    assert.equal(
      await page.$eval('#ocu-switches-contextRowCap', (node) => node.getAttribute('aria-invalid')),
      'true',
      'and the control itself is marked invalid'
    );
  } finally {
    await context.close();
  }
});

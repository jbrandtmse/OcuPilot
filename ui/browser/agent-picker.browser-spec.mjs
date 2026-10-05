/**
 * The agent picker in a real browser against the throwaway (Story 19.11): with two enabled
 * definitions the panel header carries a named picker; choosing the other one moves the context chip
 * and the next turn's egress line with no reload, is stored as the account's own `shell` preference,
 * survives a reload, and the open menu passes the DW-1337 invariants in both themes.
 *
 * Uses two `turnprobe` definitions of `OcuPilot.Test.TurnWireFixture`: A, armed default at
 * `192.0.2.10`, and B at the private `10.0.0.5`. `after` removes both, restores the default the
 * instance held, forgets the pick, and hands the turn slot back. It refuses to run in the live
 * container or a slot instance before any docker call.
 *
 * Run: `npm run build`, `docker cp` the bundle into the throwaway, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test browser/agent-picker.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { signedInAt } from './panel-spec.mjs';
import { rememberedShellMember, resetRememberedState } from './preferences-reset.mjs';
import {
  INVARIANTS,
  VIEWPORTS,
  compare,
  componentMinimums,
  detectScreen,
  readBaseline,
  toggleThemeThroughMenu,
} from './structural-walk.mjs';
import {
  armProbeDefinition,
  disarmProbeDefinition,
  ensureLocalDefinition,
  escapeOs,
  nextTag,
  requireFreeSlot,
  scriptReply,
  setTag,
} from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const probe = { container: config.container, marker: 'PICKER' };

const USERS_URL = '/ocupilot/permissions/users?ns=HSCUSTOM';
const NAME_A = 'OcuPilotProbeAgentTurnWire';
const NAME_B = 'OcuPilotProbeAgentTurnWireLocal';
const PUBLIC_HOST = '192.0.2.10';
const PRIVATE_HOST = '10.0.0.5';
const PICK_MEMBER = 'agentDefinition';

let browser = null;
let priorDefault = '';
let idA = '';
let idB = '';

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec arms the turnprobe provider, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);
  browser = await puppeteer.launch(launchOptions(config));
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  idA = armed.preparedId;
  idB = ensureLocalDefinition(probe, nextTag(probe));
});

after(async () => {
  try {
    try {
      if (config.container === LIVE_CONTAINER) return;
      await requireFreeSlot(config);
    } finally {
      if (config.container !== LIVE_CONTAINER) {
        await resetRememberedState();
        disarmProbeDefinition(probe, priorDefault);
      }
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

/** Point definition `id` at a fresh tag scripted to answer one text reply. */
function scripted(id) {
  const tag = nextTag(probe);
  setTag(probe, id, tag);
  scriptReply(probe, tag, 0, `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs('ok')}")`);
}

async function signedInReady(url) {
  const { context, page } = await signedInAt(browser, config, url);
  await page.waitForFunction(() => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'), {
    timeout: config.navigationTimeoutMs,
  });
  await page.waitForSelector('.ocu-agent-picker-button', { timeout: config.navigationTimeoutMs });
  return { context, page };
}

const pickerLabel = (page) => page.$eval('.ocu-agent-picker-button', (button) => button.getAttribute('aria-label'));

const chipText = (page) => page.evaluate(() => document.querySelector('.ocu-context-chip-text')?.textContent ?? '');

function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

async function openMenu(page) {
  await page.click('.ocu-agent-picker-button');
  await page.waitForSelector('.ocu-agent-picker-menu [role="menuitemradio"]', { timeout: config.navigationTimeoutMs });
  await frames(page);
}

async function closeMenu(page) {
  await page.keyboard.press('Escape');
  await page.waitForFunction(() => document.querySelector('.ocu-agent-picker-menu') === null, { timeout: config.navigationTimeoutMs });
}

/** Every DW-1337 invariant over `route` with the picker's menu open, in light at both widths and dark at 1280, outside the baseline. */
async function openMenuViolations(page, route) {
  const minimums = componentMinimums();
  const baseline = (readBaseline()?.entries ?? []).filter((entry) => entry.route === route);
  const requests = { inflight: new Set(), last: 0 };
  const found = [];
  for (const { viewport, theme } of [
    { viewport: VIEWPORTS.wide, theme: 'light' },
    { viewport: VIEWPORTS.narrow, theme: 'light' },
    { viewport: VIEWPORTS.wide, theme: 'dark' },
  ]) {
    await page.setViewport(viewport);
    if (theme === 'dark') await toggleThemeThroughMenu(page, requests, config.navigationTimeoutMs);
    try {
      await openMenu(page);
      const { entries } = await detectScreen(page, { route, checks: INVARIANTS, viewport: viewport.width, theme, minimums });
      found.push(...entries);
      await closeMenu(page);
    } finally {
      if (theme === 'dark') await toggleThemeThroughMenu(page, requests, config.navigationTimeoutMs);
    }
  }
  await page.setViewport(VIEWPORTS.wide);
  return compare(found, baseline).fresh.map((entry) => `${entry.key}: ${entry.measured}`);
}

test('Leg 1: two enabled definitions give a named picker whose open menu lists both and passes every invariant', async () => {
  // Mutation (Rule 19): render the single-definition text branch for two options -> the button never appears and this times out.
  const { context, page } = await signedInReady(USERS_URL);
  try {
    assert.equal(await pickerLabel(page), STRINGS.agentPickerLabel.replace('<name>', NAME_A), 'the default is in force');
    await openMenu(page);
    const items = await page.$$eval('[role="menuitemradio"]', (nodes) =>
      nodes.map((node) => ({ text: node.textContent.replace(/\s+/g, ' ').trim(), checked: node.getAttribute('aria-checked') }))
    );
    assert.equal(items.length, 2);
    assert.ok(items[0].text.includes(NAME_A) && items[0].text.includes(STRINGS.tableColumnDefault), `A is the default: ${items[0].text}`);
    assert.equal(items[0].checked, 'true');
    assert.ok(items[1].text.includes(NAME_B) && items[1].text.includes('turnprobe'), `B names its provider: ${items[1].text}`);
    assert.equal(items[1].checked, 'false');
    await closeMenu(page);
    assert.deepEqual(await openMenuViolations(page, 'permissions/users'), [], 'the open menu adds no structural violation in either theme');
  } finally {
    await context.close();
  }
});

test('Leg 2: choosing B moves the header and the chip, is stored as the account\'s pick, drives the next turn and survives a reload', async () => {
  // Mutation (Rule 19): resolve the turn's definition with ResolveDefault -> the egress line names A and this goes red.
  scripted(idA);
  scripted(idB);
  const { context, page } = await signedInReady(USERS_URL);
  try {
    await page.waitForFunction((host) => (document.querySelector('.ocu-context-chip-text')?.textContent ?? '').includes(host), { timeout: config.navigationTimeoutMs }, PUBLIC_HOST);
    await openMenu(page);
    await page.evaluate((name) => {
      [...document.querySelectorAll('[role="menuitemradio"]')].find((node) => node.textContent.includes(name)).click();
    }, NAME_B);
    await page.waitForFunction(
      (host) => (document.querySelector('.ocu-context-chip-text')?.textContent ?? '').includes(host),
      { timeout: config.navigationTimeoutMs },
      PRIVATE_HOST
    );
    assert.equal(await pickerLabel(page), STRINGS.agentPickerLabel.replace('<name>', NAME_B), 'the header names B');
    assert.equal(await rememberedShellMember(PICK_MEMBER), idB, 'the instance holds the pick as the account\'s own member');

    await page.type('#ocu-panel-composer', 'which definition runs');
    await page.click('.ocu-panel-send');
    const expected = STRINGS.egressLineStayed.replace('<provider>', 'turnprobe').replace('<host>', PRIVATE_HOST);
    await page.waitForFunction(
      (line) => document.querySelector('.ocu-panel-transcript .ocu-panel-egress-line')?.textContent.trim() === line,
      { timeout: config.navigationTimeoutMs },
      expected
    );

    await page.reload({ waitUntil: 'networkidle2' });
    await page.waitForSelector('.ocu-agent-picker-button', { timeout: config.navigationTimeoutMs });
    assert.equal(await pickerLabel(page), STRINGS.agentPickerLabel.replace('<name>', NAME_B), 'and a reload still names B');
    assert.ok((await chipText(page)).length > 0);
  } finally {
    await context.close();
  }
});

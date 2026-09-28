/**
 * The Governance policy screen in a real browser, against the throwaway instance (Story 14.2, AC1).
 *
 * One claim, on rendered DOM and the instance's own read: a key set to Disabled under the
 * Read-only preset and saved in the browser reaches the instance, the row reads "Disabled" beside
 * "by this setting", a reload shows the same, and the route reads it back.
 *
 * **It refuses the live container**: it writes the instance's governance policy, and puts it back
 * to the default in `finally` through the shipped route, so no later spec starts from a disabled
 * key.
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
import { authHeader as sharedAuthHeader, saveAndSettle } from './panel-spec.mjs';
import { resetGovernancePolicy, resetRememberedState } from './preferences-reset.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const GOVERNANCE_URL = '/ocupilot/agent/governance?ns=HSCUSTOM';
const GOVERNANCE_PATH = '/api/ocupilot/agent/governance';
const TOOL = 'webapp.list.update';

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
});

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

/** What the row for `key` reads under In effect. */
function effectOf(page, key) {
  return page.$eval(`[id="ocu-governance-key-${key}"]`, (cell) => cell.parentElement.cells[3].textContent.trim());
}

test('AC1: a key disabled under Read-only in the browser is stored, shown by its setting, and survives a reload', async () => {
  const { context, page } = await signedInAt(GOVERNANCE_URL);
  try {
    const select = `[id="ocu-governance-setting-${TOOL}"]`;
    await page.waitForSelector(select, { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await effectOf(page, TOOL), `${STRINGS.tableColumnEnabled} \u00B7 ${STRINGS.agentGovernanceSourceBaseline}`, 'the key starts enabled by the baseline');

    await page.click('#ocu-governance-preset-read-only');
    await page.select(select, 'disabled');
    await saveAndSettle(page, config);
    const expected = `${STRINGS.agentGovernanceDisabled} \u00B7 ${STRINGS.agentGovernanceSourceSetting}`;
    await page.waitForFunction(
      (id, text) => document.getElementById(id)?.parentElement?.cells[3]?.textContent?.trim() === text,
      { timeout: config.navigationTimeoutMs },
      `ocu-governance-key-${TOOL}`,
      expected
    );

    await page.reload({ waitUntil: 'networkidle2' });
    await page.waitForSelector(select, { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await effectOf(page, TOOL), expected, 'a reload shows the key disabled by its setting');
    assert.equal(await page.$eval(select, (node) => node.value), 'disabled', 'with its setting selected');
    assert.equal(await page.$eval('#ocu-governance-preset-read-only', (node) => node.checked), true, 'and Read-only chosen');

    const stored = await (
      await fetch(`${config.origin}${GOVERNANCE_PATH}`, { headers: { Authorization: sharedAuthHeader(config) } })
    ).json();
    const row = stored.keys.find((entry) => entry.key === TOOL);
    assert.equal(stored.preset, 'read-only', 'the instance holds the preset the browser chose');
    assert.deepEqual(
      { setting: row.setting, enabled: row.enabled, source: row.source },
      { setting: 'disabled', enabled: false, source: 'setting' },
      'and the key the browser disabled'
    );
  } finally {
    await context.close();
    await resetGovernancePolicy();
  }
});

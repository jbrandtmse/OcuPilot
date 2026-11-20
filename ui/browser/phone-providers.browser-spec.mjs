/**
 * Mobile phone providers, their editor and the delete in a real browser, against the throwaway instance (Story 21.10).
 *
 * What it pins, each on rendered DOM, on the request the page sent, or on the instance itself:
 *
 * 1. **The way in**: Security and secrets lists Mobile phone providers last, and the side-bar entry opens the list.
 * 2. **Create, edit and delete**: from the list's Create provider, a probe provider is created on the form and the instance holds it; a
 *    changed SMS gateway is sent alone and stored; and the typed-name dialog states the delete's consequence and deletes it.
 *
 * **It refuses the live and development containers.** It touches only the probe provider `OcuPhoneProbeB`: `before` and `after` remove it
 * by exact name through the vendor's own `%SYS.PhoneProviders.Delete`.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1 browser/phone-providers.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { assertDrawnAtDeclaredIndex, sideBarLabels } from './side-bar-spec.mjs';
import { assertThrowaway } from './structural-walk.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const NAME = 'OcuPhoneProbeB';
const FIRST_GATEWAY = 'first.ocuphoneprobe.invalid';
const SECOND_GATEWAY = 'second.ocuphoneprobe.invalid';
const LIST_URL = '/ocupilot/security/phone-providers?ns=HSCUSTOM';
const FORM_ROUTE = 'security/phone-providers/edit';
const SAVE_PATH = '/api/ocupilot/phone-provider';
const ACTION_PATH = '/api/ocupilot/screens/security.phoneproviders/action';

let browser = null;

const mark = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/** Run `lines` in `%SYS` inside the throwaway and return the value each named marker carries. */
function iris(lines, names = []) {
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', 'HSCUSTOM'], {
    input: `${['Set $NAMESPACE="%SYS"', ...lines, 'Halt'].join('\n')}\n`,
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const values = {};
  for (const name of names) {
    const hit = new RegExp(`OCU-${name}-START:(.*?):OCU-${name}-END`).exec(output);
    values[name] = hit === null ? null : hit[1].trim();
  }
  return { values, output };
}

/** Delete the probe provider by exact name. */
function removeProbes() {
  iris([`Do ##class(%SYS.PhoneProviders).Delete("${NAME}")`]);
}

/** The probe provider's SMS gateway as the instance holds it, or `'absent'` when it holds none. */
function stored() {
  const { values, output } = iris([`Set held=##class(%SYS.PhoneProviders).Exists("${NAME}",.provider)`, mark('STORED', '$Select(held:provider.SMSGateway,1:"absent")')], ['STORED']);
  assert.ok(values.STORED !== null, `the instance is read:\n${output}`);
  return values.STORED;
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec sends a Save, so it never runs inside the live container');
  assert.ok(!/^ocupilot-slot-/.test(config.container), 'nor inside a development instance');
  await assertThrowaway(config);
  removeProbes();
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    if (config.container !== LIVE_CONTAINER) {
      removeProbes();
      assert.equal(stored(), 'absent', 'the probe provider is gone');
    }
  }
});

// Mutation (Rule 19): drop the entry from the Security area's declared list, regenerate, rebuild and redeploy -> the label assertion goes red.
test('Security lists Mobile phone providers and its entry opens the list', async () => {
  const { context, page } = await signedInAt(browser, config, LIST_URL);
  try {
    if ((await page.$('app-side-bar nav.ocu-side-bar')) === null) {
      await page.keyboard.down('Control');
      await page.keyboard.press('b');
      await page.keyboard.up('Control');
    }
    await page.waitForSelector('app-side-bar nav.ocu-side-bar', { timeout: config.navigationTimeoutMs });
    const labels = await page.$$eval('app-side-bar .ocu-side-bar-item .ocu-side-bar-label', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(labels, sideBarLabels('security'), 'the side bar lists its entries in their declared order');
    assertDrawnAtDeclaredIndex(labels, 'security', STRINGS.phoneProviderListLabel);
    await page.goto(`${config.origin}/ocupilot/security/ssl?ns=HSCUSTOM`, { waitUntil: 'networkidle2' });
    await page.evaluate((label) => {
      Array.from(document.querySelectorAll('app-side-bar .ocu-side-bar-item')).find((item) => item.textContent.trim() === label).click();
    }, STRINGS.phoneProviderListLabel);
    await page.waitForFunction(() => new URL(window.location.href).pathname.endsWith('/security/phone-providers'), { timeout: config.navigationTimeoutMs });
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): send the form without the typed name -> the create's body assertion goes red; drop the list's entry from
// `DESTRUCTIVE_CONSEQUENCES` -> the consequence assertion goes red. The agent card's sentence is pinned by `proposal-view.test.mjs`.
test('create a probe provider, change its SMS gateway and delete it with the typed name', async () => {
  removeProbes();
  const { context, page } = await signedInAt(browser, config, LIST_URL);
  const saves = [];
  const actions = [];
  page.on('request', (request) => {
    const path = new URL(request.url()).pathname;
    if (request.method() !== 'GET' && path.startsWith(SAVE_PATH)) saves.push({ method: request.method(), path, body: JSON.parse(request.postData() ?? '{}') });
    if (request.method() === 'POST' && path === ACTION_PATH) actions.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    await waitForRows(page, config.navigationTimeoutMs).catch(() => undefined);
    const primary = await page.waitForSelector('.ocu-command-bar button.ocu-command-bar-primary', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await primary.evaluate((node) => node.textContent.trim()), STRINGS.phoneProviderCreateAction, 'the command bar names the create');
    await primary.click();
    await page.waitForFunction((route) => new URL(window.location.href).pathname.endsWith(`/${route}`), { timeout: config.navigationTimeoutMs }, FORM_ROUTE);
    await page.waitForSelector('#ocu-phone-provider-Name', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('#ocu-phone-provider-Name', (input) => input.readOnly), false, 'a create takes the name');
    await page.type('#ocu-phone-provider-Name', NAME);
    await page.type('#ocu-phone-provider-SMSGateway', FIRST_GATEWAY);
    await page.click('.ocu-form-bar-actions button.ocu-button-primary');
    await page.waitForFunction((route) => new URL(window.location.href).pathname.includes(`/${route}/`), { timeout: 90000 }, FORM_ROUTE);
    assert.equal(saves[0].method, 'POST');
    assert.equal(saves[0].path, SAVE_PATH);
    assert.deepEqual(saves[0].body, { Name: NAME, SMSGateway: FIRST_GATEWAY }, 'the create carries the name and the gateway, each as typed');
    assert.equal(stored(), FIRST_GATEWAY, 'the instance holds the new provider');

    // Edit the gateway: the edit sends that field alone, and the instance holds it.
    await page.waitForSelector('#ocu-phone-provider-SMSGateway', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('#ocu-phone-provider-Name', (input) => input.readOnly), true, 'an edit never changes the name');
    await page.click('#ocu-phone-provider-SMSGateway', { clickCount: 3 });
    await page.keyboard.press('Backspace');
    await page.type('#ocu-phone-provider-SMSGateway', SECOND_GATEWAY);
    await page.click('.ocu-form-bar-actions button.ocu-button-primary');
    await page.waitForFunction(() => (document.querySelector('.ocu-form-bar-status [role="status"]')?.textContent ?? '').trim() !== '', { timeout: 90000 });
    assert.deepEqual(saves[1].body, { SMSGateway: SECOND_GATEWAY });
    assert.equal(saves[1].method, 'PUT');
    assert.equal(stored(), SECOND_GATEWAY, 'the instance holds the change');

    // Delete it through the typed-name dialog on the list.
    await page.goto(`${config.origin}${LIST_URL}`, { waitUntil: 'networkidle2' });
    await waitForRows(page, config.navigationTimeoutMs);
    await page.click(FILTER_SELECTOR, { clickCount: 3 });
    await page.keyboard.press('Backspace');
    await page.type(FILTER_SELECTOR, NAME);
    await page.waitForFunction((selector, text) => Array.from(document.querySelectorAll(selector)).some((row) => row.textContent.includes(text)), { timeout: config.navigationTimeoutMs }, ROW_SELECTOR, NAME);
    await clickRowCentre(page, { text: NAME, cell: 1 });
    await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
    await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
    await page.evaluate((label) => {
      Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]')).find((item) => item.textContent.trim().startsWith(label)).click();
    }, STRINGS.actionDelete);
    await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-typed-name-consequence', (node) => node.textContent.trim()), STRINGS.phoneProviderDeleteConsequence);
    await page.type('.ocu-typed-name-field', NAME);
    await page.keyboard.press('Enter');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: 90000 });
    await page.waitForFunction(
      (selector, wanted) => !Array.from(document.querySelectorAll(selector)).some((row) => row.textContent.includes(wanted)),
      { timeout: 90000 },
      ROW_SELECTOR,
      NAME
    );
    assert.equal(actions.length, 1, 'one action was sent');
    assert.equal(actions[0].action, 'delete');
    assert.equal(stored(), 'absent', 'the provider is gone');
  } finally {
    await context.close();
    removeProbes();
  }
});

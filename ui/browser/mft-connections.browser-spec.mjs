/**
 * Managed file transfer connections, their editor, the token revoke and the delete in a real browser, against the
 * throwaway instance (Story 18.26).
 *
 * What it pins, each on rendered DOM, on the request the page sent, or on the instance itself:
 *
 * 1. **The way in** (C6): Security and secrets lists Managed file transfer thirteenth, and the side-bar entry
 *    opens the list.
 * 2. **Create, edit, revoke and delete** (C2, C3, C4): from the list's Create, a probe connection is created on the
 *    form and the instance holds it; a changed email address is sent alone and stored; Revoke token on it is
 *    refused because it holds no token; and the typed-name dialog states the delete's consequence and deletes it.
 *
 * **It refuses the live and development containers.** It touches only connections named `OcuMftProbe...`:
 * `before` and `after` remove them by exact name with `OcuPilot.Test.MftProbe.RemoveAll`, which refuses any other
 * name.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1
 * browser/mft-connections.browser-spec.mjs`.
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
import { sideBarLabels } from './side-bar-spec.mjs';
import { assertThrowaway } from './structural-walk.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const PROBE = 'OcuPilot.Test.MftProbe';
const NAME = 'OcuMftProbeB';
const SSL_CONFIG = 'OcuMftProbeClientTLS';
const LIST_URL = '/ocupilot/security/mft-connections?ns=HSCUSTOM';
const FORM_ROUTE = 'security/mft-connections/edit';
const SAVE_PATH = '/api/ocupilot/mft-connection';
const ACTION_PATH = '/api/ocupilot/screens/security.mftconnections/action';
const NO_TOKEN = 'This connection holds no access token to revoke.';

let browser = null;

const mark = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/** Run `lines` in `HSCUSTOM` inside the throwaway and return the value each named marker carries. */
function iris(lines, names = []) {
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', 'HSCUSTOM'], {
    input: `${[...lines, 'Halt'].join('\n')}\n`,
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

/** Delete every probe connection, and the client configurations and descriptions they name, by exact name. */
function removeProbes() {
  iris([`Do ##class(${PROBE}).RemoveAll()`]);
}

/** Create the client SSL/TLS configuration the form offers, which a fresh instance lacks. */
function ensureSsl() {
  iris([`Do ##class(${PROBE}).EnsureSsl()`]);
}

/** One member of the probe connection as the instance holds it, or `'absent'` when it holds none. */
function stored(member) {
  const expression = `$Select($IsObject(##class(${PROBE}).Stored("${NAME}")):##class(${PROBE}).Stored("${NAME}").%Get("${member}"),1:"absent")`;
  const { values, output } = iris([mark('STORED', expression)], ['STORED']);
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
      assert.equal(stored('Service'), 'absent', 'the probe connection is gone');
    }
  }
});

// Mutation (Rule 19): drop the entry from the Security area's declared list, regenerate, rebuild and
// redeploy -> the label assertion goes red.
test('C6: Security lists Managed file transfer thirteenth and its entry opens the list', async () => {
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
    assert.equal(labels[12], STRINGS.mftConnectionListLabel, 'Managed file transfer is the thirteenth');
    await page.goto(`${config.origin}/ocupilot/security/ssl?ns=HSCUSTOM`, { waitUntil: 'networkidle2' });
    await page.evaluate((label) => {
      Array.from(document.querySelectorAll('app-side-bar .ocu-side-bar-item')).find((item) => item.textContent.trim() === label).click();
    }, STRINGS.mftConnectionListLabel);
    await page.waitForFunction(() => new URL(window.location.href).pathname.endsWith('/security/mft-connections'), { timeout: config.navigationTimeoutMs });
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): send the form without the typed name -> the create's body assertion goes red; map
// `MFT.DELETE` to no sentence in proposal-view.ts -> the consequence assertion goes red.
test('C2, C3, C4: create a probe connection, change its email address, refuse its token revoke and delete it with the typed name', async () => {
  removeProbes();
  ensureSsl();
  const { context, page } = await signedInAt(browser, config, LIST_URL);
  const saves = [];
  const actions = [];
  page.on('request', (request) => {
    const path = new URL(request.url()).pathname;
    if (request.method() !== 'GET' && path.startsWith(SAVE_PATH)) saves.push({ method: request.method(), path, body: JSON.parse(request.postData() ?? '{}') });
    if (request.method() === 'POST' && path === ACTION_PATH) actions.push(JSON.parse(request.postData() ?? '{}'));
  });
  const openRowMenu = async (wanted) => {
    await page.click(FILTER_SELECTOR, { clickCount: 3 });
    await page.keyboard.press('Backspace');
    await page.type(FILTER_SELECTOR, NAME);
    await page.waitForFunction((selector, text) => Array.from(document.querySelectorAll(selector)).some((row) => row.textContent.includes(text)), { timeout: config.navigationTimeoutMs }, ROW_SELECTOR, NAME);
    await clickRowCentre(page, { text: NAME, cell: 1 });
    await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
    await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
    await page.evaluate((label) => {
      Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]')).find((item) => item.textContent.trim().startsWith(label)).click();
    }, wanted);
  };
  try {
    await waitForRows(page, config.navigationTimeoutMs).catch(() => undefined);
    await (await page.waitForSelector('.ocu-command-bar button.ocu-command-bar-primary', { visible: true, timeout: config.navigationTimeoutMs })).click();
    await page.waitForFunction((route) => new URL(window.location.href).pathname.endsWith(`/${route}`), { timeout: config.navigationTimeoutMs }, FORM_ROUTE);
    await page.waitForSelector('#ocu-mft-connection-Name', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('#ocu-mft-connection-Name', (input) => input.readOnly), false, 'a create takes the name');
    await page.type('#ocu-mft-connection-Name', NAME);
    await page.type('#ocu-mft-connection-URL', 'https://api.box.ocumftprobe.invalid/');
    await page.waitForSelector(`#ocu-mft-connection-SSLConfiguration option[value="${SSL_CONFIG}"]`, { timeout: config.navigationTimeoutMs });
    await page.select('#ocu-mft-connection-SSLConfiguration', SSL_CONFIG);
    await page.type('#ocu-mft-connection-Username', 'browser@ocumftprobe.invalid');
    await page.type('#ocu-mft-connection-ApplicationName', `${NAME}App`);
    await page.click('.ocu-form-bar-actions button.ocu-button-primary');
    await page.waitForFunction((route) => new URL(window.location.href).pathname.includes(`/${route}/`), { timeout: 90000 }, FORM_ROUTE);
    assert.equal(saves[0].method, 'POST');
    assert.equal(saves[0].path, SAVE_PATH);
    assert.deepEqual(
      saves[0].body,
      {
        Name: NAME,
        Service: 'Box',
        URL: 'https://api.box.ocumftprobe.invalid/',
        SSLConfiguration: SSL_CONFIG,
        Username: 'browser@ocumftprobe.invalid',
        ApplicationName: `${NAME}App`,
      },
      'the create carries the name and the five fields, each as typed'
    );
    assert.equal(stored('Username'), 'browser@ocumftprobe.invalid', 'the instance holds the new connection');

    // Edit the email address: the edit sends that field alone, and the instance holds it.
    await page.waitForSelector('#ocu-mft-connection-Username', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('#ocu-mft-connection-Name', (input) => input.readOnly), true, 'an edit never changes the name');
    await page.click('#ocu-mft-connection-Username', { clickCount: 3 });
    await page.keyboard.press('Backspace');
    await page.type('#ocu-mft-connection-Username', 'changed@ocumftprobe.invalid');
    await page.click('.ocu-form-bar-actions button.ocu-button-primary');
    await page.waitForFunction(() => (document.querySelector('.ocu-form-bar-status [role="status"]')?.textContent ?? '').trim() !== '', { timeout: 90000 });
    assert.deepEqual(saves[1].body, { Username: 'changed@ocumftprobe.invalid' });
    assert.equal(saves[1].method, 'PUT');
    assert.equal(stored('Username'), 'changed@ocumftprobe.invalid', 'the instance holds the change');

    // Revoke its token: it holds none, so the instance refuses and nothing changes.
    await page.goto(`${config.origin}${LIST_URL}`, { waitUntil: 'networkidle2' });
    await waitForRows(page, config.navigationTimeoutMs);
    await openRowMenu(STRINGS.mftConnectionRevokeAction);
    await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-typed-name-consequence', (node) => node.textContent.trim()), STRINGS.mftRevokeConsequence);
    await page.type('.ocu-typed-name-field', NAME);
    await page.keyboard.press('Enter');
    await page.waitForFunction((sentence) => document.body.innerText.includes(sentence), { timeout: 90000 }, NO_TOKEN);
    assert.equal(actions.length, 1, 'one action was sent');
    assert.equal(actions[0].action, 'revoke-token');
    assert.equal(stored('Service'), 'Box', 'the connection is as it was');

    // Delete it through the typed-name dialog on the list.
    await page.goto(`${config.origin}${LIST_URL}`, { waitUntil: 'networkidle2' });
    await waitForRows(page, config.navigationTimeoutMs);
    await openRowMenu(STRINGS.actionDelete);
    await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-typed-name-consequence', (node) => node.textContent.trim()), STRINGS.mftDeleteConsequence);
    await page.type('.ocu-typed-name-field', NAME);
    await page.keyboard.press('Enter');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: 90000 });
    await page.waitForFunction(
      (selector, wanted) => !Array.from(document.querySelectorAll(selector)).some((row) => row.textContent.includes(wanted)),
      { timeout: 90000 },
      ROW_SELECTOR,
      NAME
    );
    assert.equal(actions.length, 2, 'a second action was sent');
    assert.equal(actions[1].action, 'delete');
    assert.equal(stored('Service'), 'absent', 'the connection is gone');
  } finally {
    await context.close();
    removeProbes();
  }
});

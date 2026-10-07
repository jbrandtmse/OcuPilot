/**
 * Superservers, the superserver editor and its delete in a real browser, against the throwaway instance
 * (Story 18.25).
 *
 * What it pins, each on rendered DOM, on the request the page sent, or on the instance itself:
 *
 * 1. **The way in** (B1, B5): Security and secrets lists Superservers twelfth, and the list shows the system
 *    default superserver on 1972.
 * 2. **The serving lock** (B4): 1972's editor draws Enabled and the web connections `aria-disabled`, described by
 *    the published sentence, and a click turns neither off. No spec presses Save or Delete on 1972.
 * 3. **Create, edit and delete** (B2): from the list's Create, a probe superserver on 21825 is created on the
 *    form, the address bar then names it and the instance holds it; a changed description is sent alone and
 *    stored; and the typed-port dialog deletes it.
 *
 * **It refuses the live and development containers.** It touches only the port 21825 and never 1972: `before`
 * and `after` remove the probe by exact port with `OcuPilot.Test.SuperserverProbe.RemoveAll`, which refuses any
 * other port.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1
 * browser/superservers.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { sideBarLabels } from './side-bar-spec.mjs';
import { assertThrowaway } from './structural-walk.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const repoRoot = join(uiRoot, '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const PROBE = 'OcuPilot.Test.SuperserverProbe';
const PORT = '21825';
const LIST_URL = '/ocupilot/security/superservers?ns=HSCUSTOM';
const FORM_ROUTE = 'security/superservers/edit';
const SAVE_PATH = '/api/ocupilot/superserver';
const ACTION_PATH = '/api/ocupilot/screens/security.superservers/action';
const SYSTEM_ID = `1972${String.fromCharCode(1)}0.0.0.0`;
const SYSTEM_URL = `/ocupilot/security/superservers/edit/${encodeURIComponent(encodeURIComponent(SYSTEM_ID))}?ns=HSCUSTOM`;

/** The serving refusal's sentence, read from the kernel class rather than restated here. */
function servingSentence() {
  const source = readFileSync(join(repoRoot, 'src', 'OcuPilot', 'Kernel', 'Proposal', 'Prohibited.cls'), 'utf8');
  const found = /Parameter SERVINGSUPERSERVERREASON = "([^"]+)";/.exec(source);
  assert.notEqual(found, null, 'Prohibited.cls declares SERVINGSUPERSERVERREASON');
  return found[1];
}

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

/** Delete the probe superserver by exact port, through the admin API. */
function removeProbe() {
  iris([`Do ##class(${PROBE}).RemoveAll()`]);
}

/** One member of the probe superserver as the instance holds it, or `''` when it holds none. */
function stored(member) {
  const { values, output } = iris([mark('STORED', `$Select($IsObject(##class(${PROBE}).Stored(${PORT})):##class(${PROBE}).Stored(${PORT}).%Get("${member}"),1:"absent")`)], ['STORED']);
  assert.ok(values.STORED !== null, `the instance is read:\n${output}`);
  return values.STORED;
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec sends a Save, so it never runs inside the live container');
  assert.ok(!/^ocupilot-slot-/.test(config.container), 'nor inside a development instance');
  await assertThrowaway(config);
  removeProbe();
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    if (config.container !== LIVE_CONTAINER) {
      removeProbe();
      assert.equal(stored('Port'), 'absent', 'the probe superserver is gone');
    }
  }
});

// Mutation (Rule 19): drop the entry from the Security area's declared list, regenerate, rebuild and
// redeploy -> the label assertion goes red.
test('B1, B5: Security lists Superservers twelfth and the list shows 1972', async () => {
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
    assert.equal(labels[11], STRINGS.superserverListLabel, 'Superservers is the twelfth');
    await waitForRows(page, config.navigationTimeoutMs);
    const rows = await page.$$eval(ROW_SELECTOR, (nodes) => nodes.map((node) => node.textContent));
    assert.ok(rows.some((text) => text.includes('1972') && text.includes('0.0.0.0')), 'the system default is listed on 1972');
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): stop the form read answering the serving locks, or draw a locked flag as an ordinary one
// -> the aria-disabled assertion goes red.
test("B4: 1972's editor draws Enabled and the web connections aria-disabled with the published sentence, and a click turns neither off", async () => {
  const { context, page } = await signedInAt(browser, config, SYSTEM_URL);
  try {
    const sentence = servingSentence();
    for (const field of ['Enabled', 'EnableCSP']) {
      const id = `ocu-superserver-${field}`;
      await page.waitForSelector(`#${id}[aria-disabled="true"]`, { timeout: config.navigationTimeoutMs });
      const held = await page.$eval(`#${id}`, (input) => ({
        checked: input.checked,
        reason: document.getElementById(input.getAttribute('aria-describedby') ?? '')?.textContent.trim() ?? '',
      }));
      assert.ok(held.checked, `${field} starts on`);
      assert.equal(held.reason, sentence, `${field} is described by the serving sentence`);
      await page.click(`#${id}`);
      assert.equal(await page.$eval(`#${id}`, (input) => input.checked), true, `a click does not turn ${field} off`);
    }
    assert.equal(await page.$eval('#ocu-superserver-Port', (input) => input.readOnly), true, 'the port is the id and takes no input');
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): send the form without the typed port -> the create's body assertion goes red.
test('B2: create a probe superserver on the form, change its description, and delete it with the typed port', async () => {
  removeProbe();
  const { context, page } = await signedInAt(browser, config, LIST_URL);
  const saves = [];
  const actions = [];
  page.on('request', (request) => {
    const path = new URL(request.url()).pathname;
    if (request.method() !== 'GET' && path.startsWith(SAVE_PATH)) saves.push({ method: request.method(), path, body: JSON.parse(request.postData() ?? '{}') });
    if (request.method() === 'POST' && path === ACTION_PATH) actions.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await (await page.waitForSelector('.ocu-command-bar button.ocu-command-bar-primary', { visible: true, timeout: config.navigationTimeoutMs })).click();
    await page.waitForFunction((route) => new URL(window.location.href).pathname.endsWith(`/${route}`), { timeout: config.navigationTimeoutMs }, FORM_ROUTE);
    await page.waitForSelector('#ocu-superserver-Port', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('#ocu-superserver-Port', (input) => input.readOnly), false, 'a create takes the port');
    await page.type('#ocu-superserver-Port', PORT);
    await page.click('#ocu-superserver-EnableCSP');
    await page.click('.ocu-form-bar-actions button.ocu-button-primary');
    await page.waitForFunction(
      (route) => new URL(window.location.href).pathname.includes(`/${route}/`),
      { timeout: 90000 },
      FORM_ROUTE
    );
    assert.equal(saves[0].method, 'POST');
    assert.equal(saves[0].path, SAVE_PATH);
    assert.equal(saves[0].body.Port, PORT);
    assert.equal(saves[0].body.EnableCSP, true);
    assert.equal(Object.keys(saves[0].body).includes('SystemDefault'), false, 'no body carries SystemDefault');
    assert.equal(stored('EnableCSP'), '1', 'the instance holds the new superserver with its web connections on');

    // Edit the description: the edit sends that setting alone, and the instance holds it.
    await page.waitForSelector('#ocu-superserver-Description', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('#ocu-superserver-Port', (input) => input.readOnly), true, 'an edit never changes the port');
    await page.type('#ocu-superserver-Description', 'browser probe');
    await page.click('.ocu-form-bar-actions button.ocu-button-primary');
    await page.waitForFunction(() => (document.querySelector('.ocu-form-bar-status [role="status"]')?.textContent ?? '').trim() !== '', { timeout: 90000 });
    assert.deepEqual(saves[1].body, { Description: 'browser probe' });
    assert.equal(saves[1].method, 'PUT');
    assert.equal(stored('Description'), 'browser probe', 'the instance holds the description');

    // Delete it through the typed-port dialog on the list.
    await page.goto(`${config.origin}${LIST_URL}`, { waitUntil: 'networkidle2' });
    await waitForRows(page, config.navigationTimeoutMs);
    await page.click(FILTER_SELECTOR, { clickCount: 3 });
    await page.keyboard.press('Backspace');
    await page.type(FILTER_SELECTOR, PORT);
    await page.waitForFunction((selector, wanted) => Array.from(document.querySelectorAll(selector)).some((row) => row.textContent.includes(wanted)), { timeout: config.navigationTimeoutMs }, ROW_SELECTOR, PORT);
    await clickRowCentre(page, { text: PORT, cell: 2 });
    await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
    await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
    await page.evaluate((label) => {
      Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]')).find((item) => item.textContent.trim().startsWith(label)).click();
    }, STRINGS.actionDelete);
    await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-typed-name-consequence', (node) => node.textContent.trim()), STRINGS.superserverDeleteConsequence);
    assert.deepEqual(actions, [], 'nothing is sent while the dialog is open');
    await page.type('.ocu-typed-name-field', PORT);
    await page.keyboard.press('Enter');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: 90000 });
    await page.waitForFunction(
      (selector, wanted) => !Array.from(document.querySelectorAll(selector)).some((row) => row.textContent.includes(wanted)),
      { timeout: 90000 },
      ROW_SELECTOR,
      PORT
    );
    assert.equal(actions.length, 1, 'one action was sent');
    assert.equal(actions[0].action, 'delete');
    assert.equal(stored('Port'), 'absent', 'the superserver is gone');
  } finally {
    await context.close();
    removeProbe();
  }
});

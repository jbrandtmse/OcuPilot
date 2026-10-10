/**
 * Doc DB applications, their editor and the delete in a real browser, against the throwaway instance (Story 18.30).
 *
 * What it pins, each on rendered DOM, on the request the page sent, or on the instance itself:
 *
 * 1. **The way in** (C6): Web applications lists Doc DB applications fourth, and the side-bar entry opens the list.
 * 2. **Create, change and delete** (C2, C3): from the list's Create, a probe record is created on the form in USER and
 *    the instance holds it under the name as typed; a changed description is sent alone and stored; and the typed-name
 *    dialog deletes it from the list.
 *
 * **It refuses the live and development containers.** It touches only probe records named `OcuProbe1830...`: `before`
 * and `after` remove them by exact namespace and name with `OcuPilot.Test.DocDbAppProbe.RemoveAll`. Every read of the
 * list waits for the list's own answer, the empty state or its rows, before it counts or clicks.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1
 * browser/docdb-applications.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { sideBarLabels } from './side-bar-spec.mjs';
import { assertThrowaway } from './structural-walk.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const PROBE = 'OcuPilot.Test.DocDbAppProbe';
const NAME = 'OcuProbe1830Browser';
const NAMESPACE = 'USER';
const LIST_URL = '/ocupilot/web-applications/docdb-applications?ns=HSCUSTOM';
const FORM_ROUTE = 'web-applications/docdb-applications/edit';
const SAVE_PATH = '/api/ocupilot/docdb-application';
const ACTION_PATH = '/api/ocupilot/screens/webapp.docdbapps/action';
const EMPTY_SELECTOR = '.ocu-data-table-empty';

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

/** Delete every probe record by exact namespace and name. */
function removeProbes() {
  iris([`Do ##class(${PROBE}).RemoveAll()`]);
}

/** One member of the probe record as the instance holds it, or `'absent'` when it holds none. */
function stored(member) {
  const expression = `$Select($IsObject(##class(${PROBE}).Stored("${NAMESPACE}","${NAME}")):##class(${PROBE}).Stored("${NAMESPACE}","${NAME}").%Get("${member}"),1:"absent")`;
  const { values, output } = iris([mark('STORED', expression)], ['STORED']);
  assert.ok(values.STORED !== null, `the instance is read:\n${output}`);
  return values.STORED;
}

/** The names of the probe records the instance holds, as `Namespace|Name` text. */
function held() {
  const { values, output } = iris([mark('NAMES', `$ListToString(##class(${PROBE}).Names())`)], ['NAMES']);
  assert.ok(values.NAMES !== null, `the instance is read:\n${output}`);
  return values.NAMES;
}

/** Wait until the list has answered: its empty state or at least one row. */
async function waitForListAnswered(page) {
  await page.waitForFunction(
    (rows, empty) => document.querySelector(rows) !== null || document.querySelector(empty) !== null,
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    EMPTY_SELECTOR
  );
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
      assert.equal(held(), '', 'the probe record is gone');
    }
  }
});

// Mutation (Rule 19): drop the entry from the Web applications area's declared list, regenerate, rebuild and
// redeploy -> the label assertion goes red.
test('C6: Web applications lists Doc DB applications fourth and its entry opens the list', async () => {
  const { context, page } = await signedInAt(browser, config, LIST_URL);
  try {
    if ((await page.$('app-side-bar nav.ocu-side-bar')) === null) {
      await page.keyboard.down('Control');
      await page.keyboard.press('b');
      await page.keyboard.up('Control');
    }
    await page.waitForSelector('app-side-bar nav.ocu-side-bar', { timeout: config.navigationTimeoutMs });
    const labels = await page.$$eval('app-side-bar .ocu-side-bar-item .ocu-side-bar-label', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(labels, sideBarLabels('web-applications'), 'the side bar lists its entries in their declared order');
    assert.equal(labels[3], STRINGS.docDbAppListLabel, 'Doc DB applications is the fourth');
    await page.goto(`${config.origin}/ocupilot/web-applications/list?ns=HSCUSTOM`, { waitUntil: 'networkidle2' });
    await page.evaluate((label) => {
      Array.from(document.querySelectorAll('app-side-bar .ocu-side-bar-item')).find((item) => item.textContent.trim() === label).click();
    }, STRINGS.docDbAppListLabel);
    await page.waitForFunction(() => new URL(window.location.href).pathname.endsWith('/web-applications/docdb-applications'), { timeout: config.navigationTimeoutMs });
    await waitForListAnswered(page);
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): send the form without the namespace -> the create's body assertion goes red; make the Delete
// send no id -> the delete assertion goes red.
test('C2, C3: create a probe record, change its description and delete it with the typed name', async () => {
  removeProbes();
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
    await clickRowCentre(page, { text: NAME, cell: 2 });
    await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
    await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
    await page.evaluate((label) => {
      Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]')).find((item) => item.textContent.trim().startsWith(label)).click();
    }, wanted);
  };
  try {
    await waitForListAnswered(page);
    assert.equal(await page.$$eval(ROW_SELECTOR, (rows) => rows.filter((row) => row.textContent.includes('OcuProbe1830')).length), 0, 'the list holds no probe record before the create');
    await (await page.waitForSelector('.ocu-command-bar button.ocu-command-bar-primary', { visible: true, timeout: config.navigationTimeoutMs })).click();
    await page.waitForFunction((route) => new URL(window.location.href).pathname.endsWith(`/${route}`), { timeout: config.navigationTimeoutMs }, FORM_ROUTE);
    await page.waitForSelector('#ocu-docdb-app-Name', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('#ocu-docdb-app-Name', (input) => input.readOnly), false, 'a create takes the name');
    await page.waitForSelector(`#ocu-docdb-app-Namespace option[value="${NAMESPACE}"]`, { timeout: config.navigationTimeoutMs });
    await page.select('#ocu-docdb-app-Namespace', NAMESPACE);
    await page.type('#ocu-docdb-app-Name', NAME);
    await page.type('#ocu-docdb-app-Description', 'browser');
    await page.click('.ocu-form-bar-actions button.ocu-button-primary');
    await page.waitForFunction((route) => new URL(window.location.href).pathname.includes(`/${route}/`), { timeout: 90000 }, FORM_ROUTE);
    assert.equal(saves[0].method, 'POST');
    assert.equal(saves[0].path, SAVE_PATH);
    assert.deepEqual(
      saves[0].body,
      { Namespace: NAMESPACE, Name: NAME, Description: 'browser', Enabled: true, Resource: '' },
      'the create carries the namespace and name and the three settings, each as entered'
    );
    assert.equal(held(), `${NAMESPACE}|${NAME}`, 'the instance holds the new record, under the name as typed');
    assert.equal(stored('Description'), 'browser', 'with its description');

    // Edit the description: the edit sends that field alone, and the instance holds it.
    await page.waitForSelector('#ocu-docdb-app-Description', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('#ocu-docdb-app-Name', (input) => input.readOnly), true, 'an edit never changes the name');
    assert.equal(await page.$eval('#ocu-docdb-app-Namespace', (select) => select.disabled), true, 'nor the namespace');
    await page.click('#ocu-docdb-app-Description', { clickCount: 3 });
    await page.keyboard.press('Backspace');
    await page.type('#ocu-docdb-app-Description', 'changed');
    await page.click('.ocu-form-bar-actions button.ocu-button-primary');
    await page.waitForFunction(() => (document.querySelector('.ocu-form-bar-status [role="status"]')?.textContent ?? '').trim() !== '', { timeout: 90000 });
    assert.deepEqual(saves[1].body, { Description: 'changed' });
    assert.equal(saves[1].method, 'PUT');
    assert.equal(stored('Description'), 'changed', 'the instance holds the change');

    // Delete it through the typed-name dialog on the list.
    await page.goto(`${config.origin}${LIST_URL}`, { waitUntil: 'networkidle2' });
    await waitForListAnswered(page);
    await openRowMenu(STRINGS.actionDelete);
    await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-typed-name-consequence', (node) => node.textContent.trim()), STRINGS.docDbAppDeleteConsequence, 'the dialog states what the delete does');
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
    assert.equal(held(), '', 'the record is gone');
  } finally {
    await context.close();
    removeProbes();
  }
});

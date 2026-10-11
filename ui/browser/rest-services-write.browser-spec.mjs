/**
 * The REST API explorer's Delete in a real browser, against the throwaway instance (Story 18.32).
 *
 * What it pins, each on rendered DOM, on the request the page sent, or on the instance itself:
 *
 * 1. **The delete** (Integration): a probe service built in USER is listed by the explorer, and the row's Delete, through
 *    the typed-name dialog, sends `webapp.restapis.delete` through the screen action route; the row leaves the list, the
 *    instance no longer lists the service, its specification and dispatch classes are gone, and its implementation class
 *    is kept.
 * 2. **The refusal after the click** (C3): a probe service a probe web application dispatches to is listed under the web
 *    application's path; its Delete, typed with that path, is sent, the instance refuses it, the page draws the
 *    instance's sentence, and nothing is deleted.
 * 3. **The create** (Story 18.34, Integration): the command bar's Create opens the dialog; a package and an OpenAPI 2.0
 *    text create a probe service, with one `POST /api/ocupilot/rest-service` carrying `{Name, Document}`; the dialog
 *    closes, the row appears, and the instance lists the service with its three classes.
 * 4. **The refusal on the Document field** (Story 18.34): a `{"swagger": "3.0"}` text keeps the dialog open with the
 *    Document field marked and the instance's sentence under it, and nothing is built.
 *
 * **It refuses the live and development containers.** It touches only probe services named `OcuProbe1832...` and a probe
 * web application under `/api/ocuprobe1832`: `before` and `after` remove them with
 * `OcuPilot.Test.RestServiceProbe.RemoveAll`. Every read of the list waits for the list's own answer, the empty state or
 * its rows, before it counts or clicks.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1
 * browser/rest-services-write.browser-spec.mjs`.
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
import { assertThrowaway } from './structural-walk.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const PROBE = 'OcuPilot.Test.RestServiceProbe';
const NAMESPACE = 'USER';
const NAME = 'OcuProbe1832Browser';
const APPLICATION = '/api/ocuprobe1832browser';
const LIST_URL = `/ocupilot/web-applications/rest-apis?ns=${NAMESPACE}`;
const ACTION_PATH = '/api/ocupilot/screens/webapp.restapis/action';
const SAVE_PATH = '/api/ocupilot/rest-service';
const DIALOG_NAME = 'OcuProbe1832Dialog';
const REFUSED_NAME = 'OcuProbe1832Refused';
const DOCUMENT_TEXT = JSON.stringify({ swagger: '2.0', info: { title: 'dialog', version: '1' }, basePath: '/probe', paths: { '/ping': { get: { operationId: 'ping', responses: { 200: { description: 'ok' } } } } } });
const NAME_FIELD = 'input[data-rest-service-create-name]';
const DOCUMENT_FIELD = 'textarea[data-rest-service-create-document]';
const DOCUMENT_VIOLATION = '[data-rest-service-create-document-violation]';
const CONFIRM = '[data-rest-service-create-confirm]';
const PRIMARY = '.ocu-command-bar button.ocu-command-bar-primary';
const EMPTY_SELECTOR = '.ocu-data-table-empty';
const REFUSAL_SELECTOR = 'p.ocu-list-page-banner[role="alert"] .ocu-banner-message';

let browser = null;

const mark = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/** Run `lines` in `HSCUSTOM` inside the throwaway and return the value each named marker carries. */
function runIris(lines, names = []) {
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

/** Delete every probe web application, service and class. */
function removeProbes() {
  runIris([`Do ##class(${PROBE}).RemoveAll("${NAMESPACE}")`]);
}

/** One value read off the instance by the ObjectScript `expression`, which must be defined. */
function read(name, expression) {
  const { values, output } = runIris([mark(name, expression)], [name]);
  assert.ok(values[name] !== null, `the instance is read:\n${output}`);
  return values[name];
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

/** Filter to `text`, select its row and choose the row menu's Delete, which opens the typed-name dialog. */
async function startDelete(page, text) {
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, text);
  await page.waitForFunction((selector, wanted) => Array.from(document.querySelectorAll(selector)).some((row) => row.textContent.includes(wanted)), { timeout: config.navigationTimeoutMs }, ROW_SELECTOR, text);
  await clickRowCentre(page, { text, cell: 2 });
  await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
  await page.evaluate((label) => {
    Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]')).find((item) => item.textContent.trim().startsWith(label)).click();
  }, STRINGS.actionDelete);
  await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec sends a delete, so it never runs inside the live container');
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
      assert.equal(read('REMAINING', `##class(${PROBE}).Remaining("${NAMESPACE}")`), '0', 'no probe object is left');
    }
  }
});

// Mutation (Rule 19): drop `RestApiList` from `DESTRUCTIVE_CONSEQUENCES` in the client, rebuild and redeploy -> the list
// draws no Delete and the menu assertion goes red; make the Delete send no id -> the action assertion goes red.
test('Integration: the explorer deletes a probe service with the typed name and the row leaves the list', async () => {
  removeProbes();
  assert.equal(read('SEEDED', `##class(${PROBE}).Seed("${NAMESPACE}","${NAME}")`), '1', 'a probe service is built');
  assert.equal(read('BEFORE', `##class(${PROBE}).Classes("${NAMESPACE}","${NAME}")`), '111', 'with its three classes');
  const { context, page } = await signedInAt(browser, config, LIST_URL);
  const actions = [];
  page.on('request', (request) => {
    if (request.method() === 'POST' && new URL(request.url()).pathname === ACTION_PATH) actions.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    await waitForListAnswered(page);
    await startDelete(page, NAME);
    assert.equal(await page.$eval('.ocu-typed-name-consequence', (node) => node.textContent.trim()), STRINGS.restServiceDeleteConsequence, 'the dialog states what the delete does');
    await page.type('.ocu-typed-name-field', NAME);
    await page.keyboard.press('Enter');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: 90000 });
    await page.waitForFunction(
      (selector, wanted) => !Array.from(document.querySelectorAll(selector)).some((row) => row.textContent.includes(wanted)),
      { timeout: 90000 },
      ROW_SELECTOR,
      NAME
    );
    assert.deepEqual(actions, [{ action: 'delete', id: NAME }], 'one delete was sent, naming the package');
    assert.equal(read('LISTED', `##class(${PROBE}).Listed("${NAMESPACE}","${NAME}")`), '0', 'the instance no longer lists the service');
    assert.equal(read('AFTER', `##class(${PROBE}).Classes("${NAMESPACE}","${NAME}")`), '001', 'its specification and dispatch classes are gone and its implementation class is kept');
  } finally {
    await context.close();
    removeProbes();
  }
});

// Mutation (Rule 19): drop the leading-slash refusal from `OcuPilot.Port.MgmntPort.Resolved` -> the instance answers
// that no such service is listed, and the sentence assertion goes red.
test('C3: a service a web application dispatches to is refused by the instance after the click, and nothing is deleted', async () => {
  removeProbes();
  assert.equal(read('SEEDED', `##class(${PROBE}).Seed("${NAMESPACE}","${NAME}")`), '1', 'a probe service is built');
  assert.equal(read('DEPLOYED', `##class(${PROBE}).Deploy("${NAMESPACE}","${NAME}","${APPLICATION}")`), '1', 'and a web application is made to dispatch to it');
  const sentence = read('SENTENCE', '##class(OcuPilot.Api.RestServiceError).#REASONDEPLOYED');
  const { context, page } = await signedInAt(browser, config, LIST_URL);
  const actions = [];
  page.on('request', (request) => {
    if (request.method() === 'POST' && new URL(request.url()).pathname === ACTION_PATH) actions.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    await waitForListAnswered(page);
    await startDelete(page, APPLICATION);
    await page.type('.ocu-typed-name-field', APPLICATION);
    await page.keyboard.press('Enter');
    await page.waitForFunction((selector) => (document.querySelector(selector)?.textContent ?? '').trim() !== '', { timeout: 90000 }, REFUSAL_SELECTOR);
    assert.equal(await page.$eval(REFUSAL_SELECTOR, (node) => node.textContent.trim()), sentence, 'the page draws the instance\u2019s sentence');
    assert.deepEqual(actions, [{ action: 'delete', id: APPLICATION }], 'the delete was sent once, naming the web application');
    assert.equal(read('AFTER', `##class(${PROBE}).Classes("${NAMESPACE}","${NAME}")`), '111', 'nothing was deleted');
  } finally {
    await context.close();
    removeProbes();
  }
});

/** Open the create dialog from the command bar's Create, and fill both fields: the package typed, the document text set as a paste does. */
async function fillCreate(page, name, text) {
  const create = await page.waitForSelector(PRIMARY, { visible: true, timeout: config.navigationTimeoutMs });
  assert.equal(await create.evaluate((node) => node.textContent.trim()), STRINGS.actionCreate, 'the command bar offers Create');
  await create.click();
  await page.waitForSelector(NAME_FIELD, { visible: true, timeout: config.navigationTimeoutMs });
  assert.equal(await page.$eval('[role="dialog"] .ocu-dialog-title', (node) => node.textContent.trim()), STRINGS.restServiceCreateTitle);
  await page.type(NAME_FIELD, name);
  await page.$eval(
    DOCUMENT_FIELD,
    (node, value) => {
      node.value = value;
      node.dispatchEvent(new Event('input', { bubbles: true }));
    },
    text
  );
}

/** Record the creates the page sends. */
function recordSaves(page) {
  const saves = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (request.method() === 'POST' && url.pathname === SAVE_PATH) saves.push({ ns: url.searchParams.get('ns'), body: JSON.parse(request.postData() ?? '{}') });
  });
  return saves;
}

// Mutation (Rule 19): drop the `actions.register` of `create` from `RestApiListPage`, rebuild and redeploy -> the command bar
// draws no Create and the first assertion goes red.
test('Integration: the explorer\u2019s Create builds a probe service from a pasted document and its row appears', async () => {
  removeProbes();
  const { context, page } = await signedInAt(browser, config, LIST_URL);
  const saves = recordSaves(page);
  try {
    await waitForListAnswered(page);
    await fillCreate(page, DIALOG_NAME, DOCUMENT_TEXT);
    await page.click(CONFIRM);
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: 90000 });
    assert.deepEqual(saves, [{ ns: NAMESPACE, body: { Name: DIALOG_NAME, Document: DOCUMENT_TEXT } }], 'one create was sent, carrying the package and the text as typed');
    await page.waitForFunction((selector, wanted) => Array.from(document.querySelectorAll(selector)).some((row) => row.textContent.includes(wanted)), { timeout: 90000 }, ROW_SELECTOR, DIALOG_NAME);
    assert.equal(read('LISTED', `##class(${PROBE}).Listed("${NAMESPACE}","${DIALOG_NAME}")`), '1', 'the instance lists the service');
    assert.equal(read('BUILT', `##class(${PROBE}).Classes("${NAMESPACE}","${DIALOG_NAME}")`), '111', 'with its three classes');
  } finally {
    await context.close();
    removeProbes();
  }
});

// Mutation (Rule 19): drop the document violation paragraph from the dialog's template, rebuild and redeploy -> no
// sentence is drawn under the field and the sentence assertion goes red.
test('a document whose swagger is 3.0 is refused on the Document field with the instance\u2019s sentence, and nothing is built', async () => {
  removeProbes();
  const sentence = read('SENTENCE', '##class(OcuPilot.Api.RestServiceError).#REASONDOCUMENT');
  const { context, page } = await signedInAt(browser, config, LIST_URL);
  const saves = recordSaves(page);
  try {
    await waitForListAnswered(page);
    const text = JSON.stringify({ swagger: '3.0' });
    await fillCreate(page, REFUSED_NAME, text);
    await page.click(CONFIRM);
    await page.waitForFunction((selector) => (document.querySelector(selector)?.textContent ?? '').trim() !== '', { timeout: 90000 }, DOCUMENT_VIOLATION);
    assert.equal(await page.$eval(DOCUMENT_VIOLATION, (node) => node.textContent.trim()), sentence, 'the instance\u2019s sentence is drawn under the field');
    assert.equal(await page.$eval(DOCUMENT_FIELD, (node) => node.getAttribute('aria-invalid')), 'true', 'the Document field is marked');
    assert.notEqual(await page.$('[role="dialog"]'), null, 'and the dialog stays open');
    assert.deepEqual(saves, [{ ns: NAMESPACE, body: { Name: REFUSED_NAME, Document: text } }], 'one create was sent');
    assert.equal(read('BUILT', `##class(${PROBE}).Classes("${NAMESPACE}","${REFUSED_NAME}")`), '000', 'and nothing is built');
  } finally {
    await context.close();
    removeProbes();
  }
});

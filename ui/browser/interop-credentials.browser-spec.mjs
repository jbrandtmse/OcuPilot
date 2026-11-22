/**
 * Story 24.15 Batch 2 in a real browser, against the throwaway instance: Interoperability's Credentials, added, edited, given a password and
 * removed (AD-5, AD-35, AD-53, AD-54, AD-55, AD-56, AD-62).
 *
 * What it pins, in `USER`, whose probe credentials and partner this spec creates and removes: the list offers New credential and a row action
 * menu, and lists the probe credentials under the published headers with whether a password is stored and never a value; New credential
 * creates a credential with a password typed in the masked field, a held name in another letter case refused with the server's sentence in the
 * dialog; Edit opens the same dialog on the selected row with the name read-only and sends only the value that changed; Set password sends the
 * password alone and the list then reads it stored; Remove, which types the credential's name, removes it with its password; no request, row or
 * text the page shows carries a password; and the list passes the structural and contrast checks at 1280 light, 720 light and 1280 dark, with no
 * entry beyond the baseline (DW-1337).
 *
 * Each test arranges the credentials it needs through the fixture and removes them when it ends, so every test passes alone and in any order. It
 * shares its page helpers with the Business partners spec (`interop-list-spec.mjs`).
 *
 * **It writes probe credentials in `USER`** through `OcuPilot.Test.InteropLookupFixture`, so it runs on a throwaway only; the `after` hook removes
 * every credential and password node, whatever the tests answered. It starts no production.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/interop-credentials.browser-spec.mjs` (after `npm run build` and the bundle copied into the
 * throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { interopListHelpers } from './interop-list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const FIXTURE = 'OcuPilot.Test.InteropLookupFixture';
const HELD = 'OcuProbe2415Held';
const NEW = 'OcuProbe2415New';
const PARTNER = 'OcuProbe205Partner';
const PASSWORD = 'OcuBrowserPw2415x';
const SECOND_PASSWORD = 'OcuBrowserPw2415y';
const LIST_URL = '/ocupilot/interoperability/credentials?ns=USER';
const LIST_ROUTE = 'interoperability/credentials';
const ACTION_PATH = '/api/ocupilot/screens/interop.credentials/action';
const ADD_PATH = '/api/ocupilot/interop/credentials';
/** The cell that holds a credential's name, and the one that holds whether a password is stored. */
const NAME_CELL = 0;
const PASSWORD_CELL = 3;

const { structural, rowOf, rowPresent, waitForCell, rowAction, dialogClosed, fill, openList, openPrimary: openPrimaryWhenReady } = interopListHelpers(config, NAME_CELL);

let browser = null;
let created = false;

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** The stored credential as `username|partner|stored`, `<absent>` when the namespace does not hold it. */
function stored(name) {
  return probe('CRTEXT', `##class(${FIXTURE}).CredentialText("${name}")`).value;
}

/** Whether the vendor holds a password node for the credential, empty or not. */
function node(name) {
  return probe('CRNODE', `##class(${FIXTURE}).PasswordNode("${name}")`).value;
}

/** Wait, up to ten probes, until the stored credential reads `<absent>` (`absent` true) or something else; answers the last reading. */
async function settled(name, absent) {
  let last = stored(name);
  for (let tries = 0; (last === '<absent>') !== absent && tries < 10; tries += 1) {
    await new Promise((resolve) => setTimeout(resolve, 500));
    last = stored(name);
  }
  return last;
}

/** Remove every probe credential, its password node and the probe partner this spec makes, whatever an earlier step left. */
function drop() {
  const cleared = probe('CRDROP', `$System.Status.IsOK(##class(${FIXTURE}).Clear())`);
  assert.equal(cleared.value, '1', `the probe credentials are removed: ${cleared.output}`);
}

/** The held credential `name` with `username`, a partner and a password. */
function arrange(name, username, partner = '', password = '') {
  const made = probe('CRMADE', `$System.Status.IsOK(##class(${FIXTURE}).PutCredential("${name}","${username}","${partner}","${password}"))`);
  assert.equal(made.value, '1', `the probe credential ${name} is arranged: ${made.output}`);
}

/** Make the probe partner the Credentials dialog offers. */
function arrangePartner() {
  const made = probe('CRPARTNER', `$System.Status.IsOK(##class(${FIXTURE}).PutPartner())`);
  assert.equal(made.value, '1', `the probe partner is arranged: ${made.output}`);
}

const field = (name) => `[data-interop-credential-field="${name}"]`;

/** Open the primary action's dialog on the current list. */
const openPrimary = (page) => openPrimaryWhenReady(page, field('Name'));

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec writes probe credentials, so it runs only in a throwaway; ${config.container} is not one`);
  drop();
  created = true;
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (created && /-ci$/.test(config.container)) drop();
  } finally {
    if (browser !== null) await browser.close();
  }
});

// Mutation (Rule 19): drop the list descriptor's primary action, regenerate the mirror, rebuild and redeploy -> the command bar offers none and
// the New credential assertion goes red.
test('Credentials lists the probe credentials under the published headers, shows whether a password is stored and never a value, and the walk passes', async () => {
  drop();
  arrangePartner();
  arrange(HELD, 'held', PARTNER, PASSWORD);
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const bodies = [];
  page.on('response', async (response) => {
    if (!response.url().includes('/api/ocupilot/')) return;
    try {
      bodies.push(await response.text());
    } catch {
      // A response whose body is gone is no evidence either way.
    }
  });
  try {
    await openList(page);
    await rowPresent(page, HELD);
    const headers = await page.$$eval('.ocu-data-table-header-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(
      headers.slice(0, 4),
      [STRINGS.tableColumnName, STRINGS.fieldUserName, STRINGS.interopCredentialBusinessPartner, STRINGS.fieldPassword],
      'the declared headers'
    );
    const row = await rowOf(page, HELD);
    assert.deepEqual(row.slice(0, 3), [HELD, 'held', PARTNER], 'the credential reads its name, user name and partner');
    assert.match(row[PASSWORD_CELL], /^stored$/i, 'and that a password is stored');
    assert.equal(await page.$eval('.ocu-command-bar button.ocu-command-bar-primary', (node) => node.textContent.trim()), STRINGS.interopCredentialAddAction, 'the command bar offers New credential');
    assert.ok(!(await page.content()).includes(PASSWORD), 'the page shows no password');
    assert.ok(bodies.length > 0 && bodies.every((text) => !text.includes(PASSWORD)), 'and no answer of the server carries one');
    assert.deepEqual(await structural(page, LIST_ROUTE), [], 'Credentials: no violation beyond the baseline\'s entries');
  } finally {
    await context.close();
    drop();
  }
});

// AC5. Mutation (Rule 19): make the page's Set password send no password, rebuild and redeploy -> the dialog never closes and the spec
// times out waiting for it.
test('AC5: New credential adds a credential with a password, Edit changes its user name, Set password stores one, and Remove types its name', async () => {
  drop();
  arrangePartner();
  arrange(HELD, 'held');
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const adds = [];
  const actions = [];
  page.on('request', (request) => {
    if (request.method() !== 'POST') return;
    const path = new URL(request.url()).pathname;
    if (path === ADD_PATH) adds.push(JSON.parse(request.postData() ?? '{}'));
    if (path === ACTION_PATH) actions.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    await openList(page);
    await rowPresent(page, HELD);
    await openPrimary(page);
    await page.waitForFunction(() => document.querySelectorAll('[data-interop-credential-field="BusinessPartner"] option').length > 1, { timeout: config.navigationTimeoutMs });
    const opened = await page.evaluate(() => ({
      title: document.querySelector('[role="dialog"] .ocu-dialog-title')?.textContent?.trim(),
      text: document.querySelector('[role="dialog"]').textContent,
      type: document.querySelector('[data-interop-credential-field="Password"]').type,
      partners: Array.from(document.querySelectorAll('[data-interop-credential-field="BusinessPartner"] option')).map((option) => option.textContent.trim()),
    }));
    assert.equal(opened.title, STRINGS.interopCredentialAddAction, 'the dialog is titled with the published words');
    assert.ok(opened.text.includes(STRINGS.interopCredentialHelp), 'and says what a credential is and that its password is never shown');
    assert.equal(opened.type, 'password', 'the password is typed in a masked field');
    assert.ok(opened.partners.includes(PARTNER) && opened.partners[0] === STRINGS.sslVerifyPeerNone, 'and the business partner is a choice of the namespace\'s partners, or None');

    await fill(page, field('Name'), HELD.toLowerCase());
    await fill(page, field('Password'), PASSWORD);
    await page.click('[data-interop-credential-confirm]');
    await page.waitForSelector('[data-interop-credential-reason]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-interop-credential-reason]', (node) => node.textContent.trim()), STRINGS.interopCredentialRefusalTaken, 'a held name in another letter case is refused with the server\'s sentence');
    assert.equal(stored(HELD.toLowerCase()), '<absent>', 'and nothing is stored under it');

    await fill(page, field('Name'), NEW);
    await fill(page, field('Username'), 'browser');
    await page.select(field('BusinessPartner'), PARTNER);
    await fill(page, field('Password'), PASSWORD);
    await page.click('[data-interop-credential-confirm]');
    await dialogClosed(page);
    await rowPresent(page, NEW);
    assert.deepEqual(Object.keys(adds.at(-1)).sort(), ['BusinessPartner', 'Name', 'Password', 'Username'], 'the Save carries the name, the user name, the partner and the password');
    assert.equal(stored(NEW), `browser|${PARTNER}|1`, 'the credential is stored with what was typed, and a password');
    assert.match((await rowOf(page, NEW))[PASSWORD_CELL], /^stored$/i, 'and the list says a password is stored');

    await rowAction(page, NEW, STRINGS.agentPanelSecretWarningEdit);
    await page.waitForSelector(field('Username'), { visible: true, timeout: config.navigationTimeoutMs });
    const edit = await page.evaluate((name) => ({
      title: document.querySelector('[role="dialog"] .ocu-dialog-title').textContent.trim(),
      readOnly: document.querySelector(name).readOnly,
      held: document.querySelector(name).value,
      password: document.querySelector('[data-interop-credential-field="Password"]'),
    }), field('Name'));
    assert.deepEqual(edit, { title: STRINGS.interopCredentialEditTitle.replace('<name>', NEW), readOnly: true, held: NEW, password: null }, 'Edit opens the dialog on the row, with the name read-only and no password field');
    await fill(page, field('Username'), 'changed');
    await page.click('[data-interop-credential-confirm]');
    await dialogClosed(page);
    await waitForCell(page, NEW, 1, 'changed');
    const editSent = actions.at(-1);
    assert.deepEqual([editSent.action, editSent.id], ['edit', NEW], 'one edit, sent with the row key');
    assert.deepEqual(editSent.values, { Username: 'changed' }, 'carrying only the value that was changed, and never the name');
    assert.equal(stored(NEW), `changed|${PARTNER}|1`, 'the user name changed and nothing else did');

    await rowAction(page, HELD, STRINGS.userActionSetPassword);
    await page.waitForSelector(field('Password'), { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$(field('Name')), null, 'Set password draws the masked field alone');
    await fill(page, field('Password'), SECOND_PASSWORD);
    await page.click('[data-interop-credential-confirm]');
    await dialogClosed(page);
    assert.deepEqual(actions.at(-1), { action: 'password', id: HELD, values: { Password: SECOND_PASSWORD } }, 'the password is sent alone, once');
    assert.equal(await settled(HELD, false), 'held||1', 'the credential then holds a password and the rest is as it was');
    await waitForCell(page, HELD, PASSWORD_CELL, 'stored');
    assert.ok(!(await page.content()).includes(SECOND_PASSWORD), 'and the page shows no password');

    await rowAction(page, NEW, STRINGS.actionRemove);
    await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    const dialog = await page.evaluate(() => ({
      title: document.querySelector('[role="dialog"] .ocu-dialog-title').textContent.trim(),
      consequence: document.querySelector('.ocu-typed-name-consequence').textContent.trim(),
    }));
    assert.deepEqual(dialog, { title: `${STRINGS.actionRemove} ${NEW}`, consequence: STRINGS.x509DeleteConsequence }, 'Remove asks for the name and states what removing it does');
    const sent = actions.length;
    await page.type('.ocu-typed-name-field', NEW);
    await page.keyboard.press('Enter');
    await dialogClosed(page);
    await rowPresent(page, NEW, false);
    assert.equal(actions.length, sent + 1, 'one remove was sent');
    assert.equal(actions.at(-1).action, 'remove', 'a remove');
    assert.equal(await settled(NEW, true), '<absent>', 'the credential is gone from the instance');
    assert.equal(node(NEW), '0', 'with its password node');
    assert.notEqual(stored(HELD), '<absent>', 'and the other credential is untouched');
  } finally {
    await context.close();
    drop();
  }
});

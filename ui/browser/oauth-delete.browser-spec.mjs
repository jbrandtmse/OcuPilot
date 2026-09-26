/**
 * Story 7.3 in a real browser, against the throwaway instance: the OAuth 2.0 screen's Client
 * configurations and Server client descriptions tabs each delete one entry through
 * `POST /screens/:screen/action` (AD-5, AD-53), behind the shell's typed-name dialog.
 *
 * What it pins, per tab: Delete from the row menu opens a dialog titled with the verb and the entry,
 * stating the tab's own published consequence, with focus in the typed-name field and the
 * destructive button `aria-disabled`; a mismatch on blur reads the published message; the exact name
 * sends one request, the row leaves the tab in place and the other rows stay. The server client leg
 * also opens the dialog from the command bar, types and sends the `ClientId`, and its namesake
 * survives.
 *
 * **It needs the demo fixture** (`OCUPILOT_DEMO=1`, AD-25), whose SSL/TLS configuration the probe's
 * client configurations name. `before` refuses the live container, then runs
 * `OcuPilot.Test.OAuthProbe.Create()` and `CreateDisposable()`; `after` runs `Remove()`.
 *
 * Run: `npm run test:browser` (after `npm run build` and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const CLIENTS_URL = '/ocupilot/security/oauth/clients?ns=HSCUSTOM';
const SERVER_CLIENTS_URL = '/ocupilot/security/oauth/server-clients?ns=HSCUSTOM';
const ACTION_SUFFIX = '/action';

/** `OcuPilot.Test.OAuthProbe`'s objects this spec reads or removes. */
const CLIENT_DELETE = 'OcuPilotTestDelete';
const CLIENT_A = 'OcuPilotTestA';
const CLIENT_B = 'OcuPilotTestB';

let browser = null;

/** Run ObjectScript in `iris session` inside the throwaway, in HSCUSTOM, and read back the named markers. */
function irisSession(lines, names) {
  const input = `${[...lines, 'Halt'].join('\n')}\n`;
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', 'HSCUSTOM'], {
    input,
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const values = {};
  for (const name of names) {
    const match = new RegExp(`OCU-${name}-START:(.*?):OCU-${name}-END`).exec(output);
    values[name] = match === null ? null : match[1];
  }
  return { values, output };
}

const mark = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/** Whether the disposable configuration exists, and the disposable server clients' ids. */
function disposables() {
  const { values } = irisSession(
    [
      mark('CLIENT', '##class(OcuPilot.Test.OAuthProbe).DisposableClientExists()'),
      mark('IDS', '$ListToString(##class(OcuPilot.Test.OAuthProbe).DisposableRegistrationIds())'),
    ],
    ['CLIENT', 'IDS']
  );
  return { client: values.CLIENT, ids: values.IDS === null || values.IDS === '' ? [] : values.IDS.split(',') };
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates and deletes OAuth 2.0 objects, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  const { values, output } = irisSession(
    [
      'Set tSC=##class(OcuPilot.Test.OAuthProbe).Create()',
      'If $System.Status.IsOK(tSC) Set tSC=##class(OcuPilot.Test.OAuthProbe).CreateDisposable()',
      mark('MADE', '$System.Status.IsOK(tSC)'),
    ],
    ['MADE']
  );
  assert.equal(values.MADE, '1', `the probe OAuth 2.0 objects were made:\n${output}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  const { values, output } = irisSession(
    ['Set tSC=##class(OcuPilot.Test.OAuthProbe).Remove()', mark('REMOVED', '$System.Status.IsOK(tSC)')],
    ['REMOVED']
  );
  assert.equal(values.REMOVED, '1', `the probe OAuth 2.0 objects are removed:\n${output}`);
});

/** A fresh context signed in at `url`, with the action requests it issues counted. */
async function signedInAt(url) {
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  const writes = [];
  page.on('request', (request) => {
    const path = new URL(request.url()).pathname;
    if (path.endsWith(ACTION_SUFFIX)) writes.push({ path, method: request.method(), body: request.postData() ?? '' });
  });
  await page.goto(`${config.origin}${url}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', config.username);
  await page.type('#ocu-signin-password', config.password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, url);
  await waitForRows(page, config.navigationTimeoutMs);
  return { context, page, writes };
}

/** Every rendered row's cell texts. */
function rowsOf(page) {
  return page.$$eval(ROW_SELECTOR, (rows) =>
    rows.map((row) => Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim()))
  );
}

/** Narrow the tab with `filter` until exactly one row is rendered, and select it by a non-link cell. */
async function selectOnly(page, filter) {
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, filter);
  await page.waitForFunction((selector) => document.querySelectorAll(selector).length === 1, { timeout: config.navigationTimeoutMs }, ROW_SELECTOR);
  await clickRowCentre(page, { index: 0, cell: 3 });
  await page.waitForFunction(
    (selector) => document.querySelector(selector)?.getAttribute('aria-selected') === 'true',
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR
  );
}

/** Clear the filter and wait until the tab renders at least `atLeast` rows. */
async function clearFilter(page, atLeast) {
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.waitForFunction((selector, n) => document.querySelectorAll(selector).length >= n, { timeout: config.navigationTimeoutMs }, ROW_SELECTOR, atLeast);
}

/**
 * Open the typed-name dialog from the selected row's overflow menu, which offers exactly `offered`:
 * the tab's declared row actions, Delete first.
 */
async function deleteFromRowMenu(page, offered = [STRINGS.actionDelete]) {
  await page.click('.ocu-data-table-trigger');
  await page.waitForSelector('[role="menu"]', { timeout: config.navigationTimeoutMs });
  const labels = await page.$$eval('[role="menu"] [role="menuitem"] .ocu-data-table-menu-label', (items) => items.map((item) => item.textContent.trim()));
  assert.deepEqual(labels, offered, 'the row menu offers the declared actions');
  await page.evaluate((label) => {
    const items = Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'));
    items.find((item) => item.textContent.trim().startsWith(label)).click();
  }, STRINGS.actionDelete);
  await page.waitForSelector('[role="dialog"]', { timeout: config.navigationTimeoutMs });
}

/** Open the typed-name dialog from the command bar's Delete. */
async function deleteFromCommandBar(page) {
  await page.evaluate((label) => {
    const actions = Array.from(document.querySelectorAll('.ocu-command-bar-action'));
    actions.find((action) => action.textContent.trim() === label).click();
  }, STRINGS.actionDelete);
  await page.waitForSelector('[role="dialog"]', { timeout: config.navigationTimeoutMs });
}

/**
 * The dialog's contract up to the send: title, consequence, focus, the button held `aria-disabled`,
 * and the mismatch message on blur with Enter sending nothing; then the exact `target` and Enter.
 */
async function confirmDialog(page, writes, target, consequence) {
  const opened = await page.evaluate(() => ({
    title: document.querySelector('.ocu-dialog-title').textContent.trim(),
    consequence: document.querySelector('.ocu-typed-name-consequence').textContent.trim(),
    action: document.querySelector('.ocu-button-destructive').textContent.trim(),
    ariaDisabled: document.querySelector('.ocu-button-destructive').getAttribute('aria-disabled'),
    disabled: document.querySelector('.ocu-button-destructive').hasAttribute('disabled'),
    focused: document.activeElement.className,
  }));
  assert.equal(opened.title, `${STRINGS.actionDelete} ${target}`, 'the title names the verb and the entry');
  assert.equal(opened.consequence, consequence, "the body states this tab's published consequence");
  assert.equal(opened.action, `${STRINGS.actionDelete} ${target}`, 'the button names the verb and the entry');
  assert.equal(opened.ariaDisabled, 'true', 'and is aria-disabled to begin with');
  assert.equal(opened.disabled, false, 'never the disabled attribute');
  assert.ok(opened.focused.includes('ocu-typed-name-field'), `initial focus is the typed-name field, not ${opened.focused}`);

  await page.type('.ocu-typed-name-field', target.toUpperCase());
  await page.evaluate(() => document.querySelector('.ocu-typed-name-field').blur());
  await page.waitForSelector('.ocu-typed-name-mismatch', { timeout: config.navigationTimeoutMs });
  const mismatch = await page.evaluate(() => ({
    message: document.querySelector('.ocu-typed-name-mismatch').textContent.trim(),
    invalid: document.querySelector('.ocu-typed-name-field').getAttribute('aria-invalid'),
    ariaDisabled: document.querySelector('.ocu-button-destructive').getAttribute('aria-disabled'),
  }));
  assert.equal(mismatch.message, STRINGS.formTypedNameMismatch);
  assert.equal(mismatch.invalid, 'true');
  assert.equal(mismatch.ariaDisabled, 'true', 'a re-cased name keeps the button aria-disabled');
  await page.focus('.ocu-typed-name-field');
  await page.keyboard.press('Enter');
  assert.equal(writes.length, 0, 'Enter on a mismatch sends nothing');

  await page.click('.ocu-typed-name-field', { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type('.ocu-typed-name-field', target);
  await page.waitForFunction(() => document.querySelector('.ocu-button-destructive')?.getAttribute('aria-disabled') === null, {
    timeout: config.navigationTimeoutMs,
  });
  await page.keyboard.press('Enter');
}

test('AC1: a client configuration is deleted from the row menu behind the typed-name dialog', async () => {
  const { context, page, writes } = await signedInAt(CLIENTS_URL);
  try {
    await selectOnly(page, CLIENT_DELETE);
    // Story 12.5: the client tab also declares Rotate Keys and Register.
    await deleteFromRowMenu(page, [STRINGS.actionDelete, STRINGS.oauthClientRotateKeys, STRINGS.oauthClientRegister]);
    await confirmDialog(page, writes, CLIENT_DELETE, STRINGS.oauthClientDeleteConsequence);
    await page.waitForFunction((selector) => document.querySelectorAll(selector).length === 0, { timeout: config.navigationTimeoutMs }, ROW_SELECTOR);
    assert.equal(writes.length, 1, 'exactly one request, sent once the name matched');
    assert.equal(writes[0].path, '/api/ocupilot/screens/security.oauthclients/action');
    assert.deepEqual(JSON.parse(writes[0].body), { action: 'delete', id: CLIENT_DELETE });
    assert.equal(disposables().client, '0', 'the instance no longer holds the configuration');

    await clearFilter(page, 2);
    const names = (await rowsOf(page)).map((cells) => cells[0]);
    assert.ok(!names.includes(CLIENT_DELETE), 'the re-read tab no longer lists it');
    assert.ok(names.includes(CLIENT_A) && names.includes(CLIENT_B), `and the other rows stay: ${JSON.stringify(names)}`);
  } finally {
    await context.close();
  }
});

test('AC1, AC2: a server client is deleted by its ClientId from the row menu or the command bar, and its namesake stays', async () => {
  const initial = disposables();
  assert.equal(initial.ids.length, 2, 'two server clients share one name');
  const [gone, kept] = initial.ids;
  const { context, page, writes } = await signedInAt(SERVER_CLIENTS_URL);
  try {
    await selectOnly(page, gone);
    await deleteFromCommandBar(page);
    const barTitle = await page.evaluate(() => document.querySelector('.ocu-dialog-title').textContent.trim());
    assert.equal(barTitle, `${STRINGS.actionDelete} ${gone}`, 'the command bar opens the same dialog on the ClientId');
    await page.keyboard.press('Escape');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await deleteFromRowMenu(page, [STRINGS.actionDelete, STRINGS.oauthServerUpdateJwks]);
    await confirmDialog(page, writes, gone, STRINGS.oauthServerClientDeleteConsequence);
    await page.waitForFunction((selector) => document.querySelectorAll(selector).length === 0, { timeout: config.navigationTimeoutMs }, ROW_SELECTOR);
    assert.equal(writes.length, 1, 'exactly one request, sent once the client id matched');
    assert.equal(writes[0].path, '/api/ocupilot/screens/security.oauthserverclients/action');
    assert.deepEqual(JSON.parse(writes[0].body), { action: 'delete', id: gone }, 'the id sent is the ClientId');
    assert.deepEqual(disposables().ids, [kept], 'the instance holds only the namesake');

    await clearFilter(page, 2);
    const clientIds = (await rowsOf(page)).map((cells) => cells[1]);
    assert.ok(!clientIds.includes(gone), 'the re-read tab no longer lists the deleted client');
    assert.ok(clientIds.includes(kept), `and its namesake stays: ${JSON.stringify(clientIds)}`);
  } finally {
    await context.close();
  }
});

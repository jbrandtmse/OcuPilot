/**
 * Story 9.5 in a real browser, against the throwaway instance: the X.509 credentials, Secrets and
 * SSL/TLS configurations lists each delete one entry through `POST /screens/:screen/action` (AD-53),
 * behind the shell's typed-name dialog (AC6, AC9).
 *
 * What it pins, per list: Delete from the row menu opens a dialog titled with the verb and the entry,
 * stating the list's own published consequence, with the destructive button `aria-disabled` until the
 * exact name is typed; the name sends one request, the instance no longer holds the object and the
 * re-read list no longer shows it. On the SSL/TLS list, OcuPilot's own provider configuration's
 * Delete is drawn refused with its published sentence before any click, and choosing it sends
 * nothing.
 *
 * **It refuses the live container.** `before` runs `OcuPilot.Test.SecurityDeleteProbe.Create()`,
 * which makes one probe of each kind by exact name -- the credential from a certificate the
 * instance's own OpenSSL makes and deletes at once, so no key material is stored -- and `after`
 * runs `Remove()`.
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
const ACTION_SUFFIX = '/action';
const PROBE = 'OcuPilot.Test.SecurityDeleteProbe';

/** `OcuPilot.Test.SecurityDeleteProbe`'s objects, as each list names them. */
const X509_ALIAS = 'OcuPilotProbe95X509';
const COLLECTION = 'OcuPilotProbe86';
const SECRET = `${COLLECTION}.Del95`;
const SSL_NAME = 'OcuPilotProbe95Delete';
const OWN_SSL = 'OcuPilotProvider';

let browser = null;

const mark = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/** Run ObjectScript in `iris session` inside the throwaway, in HSCUSTOM, and read back the named markers. */
function irisSession(lines, names) {
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', 'HSCUSTOM'], {
    input: `${[...lines, 'Halt'].join('\n')}\n`,
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

/** Whether the probe of `kind` (`x509`, `secret` or `ssl`) exists on the instance, as '1' or '0'. */
function exists(kind) {
  return irisSession([mark('EXISTS', `##class(${PROBE}).Exists("${kind}")`)], ['EXISTS']).values.EXISTS;
}

/** OcuPilot's own provider configuration as the vendor reads it, as JSON, to show it unchanged. */
function ownConfiguration() {
  return irisSession(
    [
      'New $Namespace Set $Namespace="%SYS"',
      `Set tSC=##class(Security.SSLConfigs).Get("${OWN_SSL}",.p)`,
      mark('OWN', '$Get(p("Enabled"))_"|"_$Get(p("VerifyPeer"))_"|"_$Get(p("Type"))_"|"_$Get(p("CAFile"))'),
    ],
    ['OWN']
  ).values.OWN;
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates and deletes security objects, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  const { values, output } = irisSession([`Set tSC=##class(${PROBE}).Create()`, mark('MADE', '$System.Status.IsOK(tSC)')], ['MADE']);
  assert.equal(values.MADE, '1', `the probe objects were made:\n${output}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  const { values, output } = irisSession([`Set tSC=##class(${PROBE}).Remove()`, mark('REMOVED', '$System.Status.IsOK(tSC)')], ['REMOVED']);
  assert.equal(values.REMOVED, '1', `the probe objects are removed:\n${output}`);
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

/** Every rendered row's first cell. */
function firstCells(page) {
  return page.$$eval(ROW_SELECTOR, (rows) => rows.map((row) => row.querySelector('[role="gridcell"]')?.textContent.trim() ?? ''));
}

/** Narrow the list with `filter` until exactly one row is rendered, and select it by a non-link cell. */
async function selectOnly(page, filter) {
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, filter);
  await page.waitForFunction((selector) => document.querySelectorAll(selector).length === 1, { timeout: config.navigationTimeoutMs }, ROW_SELECTOR);
  await clickRowCentre(page, { index: 0, cell: 2 });
  await page.waitForFunction(
    (selector) => document.querySelector(selector)?.getAttribute('aria-selected') === 'true',
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR
  );
}

/** Open the selected row's overflow menu and describe every entry. */
async function openRowMenu(page) {
  await page.click('.ocu-data-table-trigger');
  await page.waitForSelector('[role="menu"]', { timeout: config.navigationTimeoutMs });
  return page.$$eval('[role="menu"] [role="menuitem"]', (items) =>
    items.map((item) => ({
      label: item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() ?? '',
      reason: item.querySelector('.ocu-data-table-menu-reason')?.textContent.trim() ?? '',
      ariaDisabled: item.getAttribute('aria-disabled'),
    }))
  );
}

/** Choose Delete from the open row menu. */
async function chooseDelete(page) {
  await page.evaluate((label) => {
    const items = Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'));
    items.find((item) => item.textContent.trim().startsWith(label)).click();
  }, STRINGS.actionDelete);
}

/** The dialog's title, consequence and held button, then the exact `target` and Enter. */
async function confirmDialog(page, writes, target, consequence) {
  await page.waitForSelector('[role="dialog"]', { timeout: config.navigationTimeoutMs });
  const opened = await page.evaluate(() => ({
    title: document.querySelector('.ocu-dialog-title').textContent.trim(),
    consequence: document.querySelector('.ocu-typed-name-consequence').textContent.trim(),
    ariaDisabled: document.querySelector('.ocu-button-destructive').getAttribute('aria-disabled'),
  }));
  assert.equal(opened.title, `${STRINGS.actionDelete} ${target}`, 'the title names the verb and the entry');
  assert.equal(opened.consequence, consequence, "the body states this list's published consequence");
  assert.equal(opened.ariaDisabled, 'true', 'the button is aria-disabled to begin with');
  await page.keyboard.press('Enter');
  assert.equal(writes.length, 0, 'Enter before the name is typed sends nothing');
  await page.type('.ocu-typed-name-field', target);
  await page.waitForFunction(() => document.querySelector('.ocu-button-destructive')?.getAttribute('aria-disabled') === null, {
    timeout: config.navigationTimeoutMs,
  });
  await page.keyboard.press('Enter');
}

/** Delete `target` from the list at `url`, asserting the request, the instance and the re-read list. */
async function deletesFrom({ url, screen, target, kind, consequence }) {
  const { context, page, writes } = await signedInAt(url);
  try {
    assert.equal(exists(kind), '1', `${target} exists before the delete`);
    await selectOnly(page, target);
    const entries = await openRowMenu(page);
    assert.deepEqual(entries.map((entry) => entry.label), [STRINGS.actionDelete], 'the row menu offers Delete');
    assert.equal(entries[0].ariaDisabled, null, 'offered, not refused');
    await chooseDelete(page);
    await confirmDialog(page, writes, target, consequence);
    await page.waitForFunction((selector) => document.querySelectorAll(selector).length === 0, { timeout: config.navigationTimeoutMs }, ROW_SELECTOR);
    assert.equal(writes.length, 1, 'exactly one request, sent once the name matched');
    assert.equal(writes[0].path, `/api/ocupilot/screens/${screen}/action`);
    assert.deepEqual(JSON.parse(writes[0].body), { action: 'delete', id: target });
    assert.equal(exists(kind), '0', 'the instance no longer holds it');
    await page.click(FILTER_SELECTOR, { clickCount: 3 });
    await page.keyboard.press('Backspace');
    await page.waitForNetworkIdle({ idleTime: 500, timeout: config.navigationTimeoutMs });
    assert.ok(!(await firstCells(page)).includes(target), 'and the re-read list no longer shows it');
  } finally {
    await context.close();
  }
}

test('AC6: an X.509 credential is deleted from its list behind the typed-name dialog', async () => {
  await deletesFrom({
    url: '/ocupilot/security/x509?ns=HSCUSTOM',
    screen: 'security.x509',
    target: X509_ALIAS,
    kind: 'x509',
    consequence: STRINGS.x509DeleteConsequence,
  });
});

test('AC6: a wallet secret is deleted from the Secrets list behind the typed-name dialog', async () => {
  await deletesFrom({
    url: `/ocupilot/security/wallet/secrets/${COLLECTION}?ns=HSCUSTOM`,
    screen: 'security.secrets',
    target: SECRET,
    kind: 'secret',
    consequence: STRINGS.walletSecretDeleteConsequence,
  });
});

test('AC9: an SSL/TLS configuration is deleted from its list behind the typed-name dialog', async () => {
  await deletesFrom({
    url: '/ocupilot/security/ssl?ns=HSCUSTOM',
    screen: 'security.ssl',
    target: SSL_NAME,
    kind: 'ssl',
    consequence: STRINGS.sslDeleteConsequence,
  });
});

test("AC9: OcuPilot's own provider configuration's Delete is drawn refused and sends nothing", async () => {
  const before = ownConfiguration();
  assert.ok(before !== null && before !== '', 'the own configuration reads');
  const { context, page, writes } = await signedInAt('/ocupilot/security/ssl?ns=HSCUSTOM');
  try {
    await selectOnly(page, OWN_SSL);
    const entries = await openRowMenu(page);
    assert.deepEqual(entries, [{ label: STRINGS.actionDelete, reason: STRINGS.sslRefusalOcuPilot, ariaDisabled: 'true' }], 'Delete is refused before a click, with the published sentence');
    await chooseDelete(page);
    await page.waitForNetworkIdle({ idleTime: 500, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$('[role="dialog"]'), null, 'choosing it opens no dialog');
    assert.equal(writes.length, 0, 'and sends nothing');
    assert.equal(ownConfiguration(), before, 'the configuration is unchanged');
  } finally {
    await context.close();
  }
});

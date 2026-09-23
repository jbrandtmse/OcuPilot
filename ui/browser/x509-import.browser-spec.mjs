/**
 * The X.509 credential form in a real browser, against the throwaway instance (Story 8.5).
 *
 * Four claims, each asserted on rendered DOM, on the real URL or on the instance itself:
 *
 * 1. **The X.509 list's Create reads Import and opens the form** (AC1), whose fields are alias,
 *    certificate, private key, its password, authorized users and intended peers, in that order,
 *    with the key and password masked and empty and no field taking a path.
 * 2. **An import loaded from local files creates the credential with its key** (AC1, AC3):
 *    "Load from file" reads the certificate and the key in the browser, Save replaces the route with
 *    `security/x509/edit/<alias>`, reads the saved sentence, and the page then shows the subject and
 *    a key present while no text of the key is anywhere on it.
 * 3. **The X.509 list then shows the row's subject, issuer and validity** (AC2), reached by the
 *    form's own Cancel, a navigation inside the page rather than a load. The change event itself is
 *    pinned in `x509-form.store.spec.ts`.
 * 4. **A changed form asks before it is left** (AC6).
 *
 * The certificate and key are made in `before` by the host's own `openssl` in a directory of their
 * own, which `after` deletes and asserts gone, so the repository holds no key.
 *
 * **It refuses the live container.** Every credential it imports is named below and removed by that
 * exact alias through the vendor's own `%SYS.X509Credentials.Delete` inside the throwaway, before and
 * after.
 *
 * Run: `npm run test:browser` (after `npm run build` and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { ROW_SELECTOR, waitForRows } from './list-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const LIST_URL = '/ocupilot/security/x509?ns=HSCUSTOM';
const FORM_URL = '/ocupilot/security/x509/edit?ns=HSCUSTOM';

/** Every credential this spec imports, removed by exact alias in `before` and `after`. */
const ALIASES = ['OcuPilotProbe85Browser'];

const SUBJECT = 'OcuPilot Browser Probe';

let browser = null;

/** The directory the host's openssl writes the certificate and key into, and their paths. */
let material = { directory: '', certificate: '', key: '' };

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec drives the throwaway, never the live container');
  assert.notEqual(config.container, '', 'it removes the credentials it imports, so it needs the container that serves the origin');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  material = makeMaterial();
  removeProbeCredentials();
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  removeProbeCredentials();
  if (browser !== null) await browser.close();
  if (material.directory !== '') {
    rmSync(material.directory, { recursive: true, force: true });
    assert.equal(existsSync(material.directory), false, 'the certificate and key the host made are gone');
  }
});

/** A self-signed certificate and its unencrypted key, made by the host's openssl for this run alone. */
function makeMaterial() {
  const directory = mkdtempSync(join(tmpdir(), 'ocupilot-x509-browser-'));
  const certificate = join(directory, 'cert.pem');
  const key = join(directory, 'key.pem');
  const made = spawnSync(
    'openssl',
    ['req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-keyout', key, '-out', certificate, '-days', '36500', '-subj', `/CN=${SUBJECT}`],
    { encoding: 'utf8' }
  );
  if (made.status !== 0) {
    rmSync(directory, { recursive: true, force: true });
    assert.fail(`openssl could not make the probe certificate: ${made.stderr}`);
  }
  return { directory, certificate, key };
}

function credentials() {
  return { user: config.username, password: config.password };
}

/** Run `lines` in `%SYS` inside the throwaway, returning the combined transcript. */
function irisSys(lines) {
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', '%SYS'], {
    input: `${[...lines, 'Halt'].join('\n')}\n`,
    encoding: 'utf8',
    timeout: 600000,
  });
  return `${result.stdout ?? ''}${result.stderr ?? ''}`;
}

/** Remove every credential this spec imports, by its exact alias -- never a prefix sweep. */
function removeProbeCredentials() {
  irisSys(ALIASES.map((alias) => `If ##class(%SYS.X509Credentials).Exists("${alias}") Do ##class(%SYS.X509Credentials).Delete("${alias}")`));
}

/** Whether the instance holds `alias`, compared exactly, and whether it holds a key for it. */
function storedCredential(alias) {
  const output = irisSys([
    `Set tCred = ##class(%SYS.X509Credentials).GetByAlias("${alias}")`,
    'Write "OCU-HELD-START:",$IsObject(tCred),":OCU-HELD-END",!',
    'If $IsObject(tCred) Write "OCU-KEY-START:",tCred.HasPrivateKey,":OCU-KEY-END",!',
  ]);
  const held = /OCU-HELD-START:(.*?):OCU-HELD-END/.exec(output);
  const key = /OCU-KEY-START:(.*?):OCU-KEY-END/.exec(output);
  return { held: held !== null && held[1].trim() === '1', hasKey: key !== null && key[1].trim() === '1' };
}

/** A fresh context signed in through the shell's own form, landed at `url`. */
async function signedInAt(url) {
  const { user, password } = credentials();
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  await page.goto(`${config.origin}${url}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', user);
  await page.type('#ocu-signin-password', password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, url);
  return { context, page };
}

/** Type `value` into the form control `id`, replacing whatever is there. */
async function fill(page, id, value) {
  await page.waitForSelector(`#${id}`, { visible: true, timeout: config.navigationTimeoutMs });
  await page.click(`#${id}`, { clickCount: 3 });
  await page.type(`#${id}`, value);
}

/** The sticky bar's buttons: Cancel, then Save. */
async function barButtons(page) {
  const buttons = await page.$$('.ocu-form-bar-actions button');
  assert.equal(buttons.length, 2, 'the sticky bar carries Cancel and Save');
  return { cancel: buttons[0], save: buttons[1] };
}

/** Hand `path` to the file picker beside `field`, as a person choosing it in the browser's dialog would. */
async function loadFromFile(page, field, path) {
  const picker = await page.evaluateHandle((id) => document.getElementById(id)?.previousElementSibling ?? null, `ocu-x509-${field}-load`);
  const element = picker.asElement();
  assert.ok(element !== null, `${field} carries a file picker beside its Load from file button`);
  assert.equal(await element.evaluate((node) => node instanceof HTMLInputElement && node.type === 'file'), true, 'and it is a file input');
  await element.uploadFile(path);
}

// AC1. Mutation (Rule 19): swap the Private key and Certificate blocks in the page template and
// redeploy -> the order assertion goes red.
test('AC1: the X.509 list offers Import, and the form takes alias, certificate, key, password, users and peers, in that order', async () => {
  const { context, page } = await signedInAt(LIST_URL);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const create = await page.waitForSelector('.ocu-command-bar button.ocu-button-primary', {
      visible: true,
      timeout: config.navigationTimeoutMs,
    });
    assert.equal(await create.evaluate((node) => node.textContent.trim()), STRINGS.actionImport, 'the declared Create reads Import');
    await create.click();
    await page.waitForFunction(() => new URL(window.location.href).pathname.endsWith('/security/x509/edit'), {
      timeout: config.navigationTimeoutMs,
    });
    await page.waitForSelector('#ocu-x509-Alias', { visible: true, timeout: config.navigationTimeoutMs });
    const labels = await page.$$eval('.ocu-form-fields .ocu-field-label', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(labels, [
      STRINGS.x509ColumnAlias,
      STRINGS.x509FieldCertificate,
      STRINGS.x509FieldPrivateKey,
      STRINGS.x509FieldPrivateKeyPassword,
      STRINGS.x509FieldOwnerList,
      STRINGS.x509FieldPeerNames,
    ]);
    for (const id of ['ocu-x509-PrivateKey', 'ocu-x509-PrivateKeyPassword']) {
      assert.equal(await page.$eval(`#${id}`, (node) => node.type), 'password', `${id} is masked`);
      assert.equal(await page.$eval(`#${id}`, (node) => node.value), '', `${id} is not pre-filled`);
    }
    const toggles = await page.$$eval('.ocu-reveal-toggle', (nodes) => nodes.map((node) => node.getAttribute('aria-label')));
    assert.deepEqual(toggles, [STRINGS.accountShowPassword, STRINGS.accountShowPassword], 'each masked field has a labelled toggle');
    const typed = await page.$$eval('.ocu-form-fields input:not([type="file"]), .ocu-form-fields textarea', (nodes) => nodes.map((node) => node.id));
    assert.deepEqual(
      typed,
      ['ocu-x509-Alias', 'ocu-x509-Certificate', 'ocu-x509-PrivateKey', 'ocu-x509-PrivateKeyPassword', 'ocu-x509-OwnerList', 'ocu-x509-PeerNames'],
      'no field takes a path'
    );
  } finally {
    await context.close();
  }
});

// AC1, AC3. Mutation (Rule 19): drop the route replacement from `onSave` and redeploy -> the URL
// leg goes red.
test('AC3: an import loaded from local files creates the credential with its key, and no text of the key is on the page', async () => {
  const keyText = readFileSync(material.key, 'utf8');
  const keyBody = keyText.split('\n')[5];
  assert.ok(keyBody !== undefined && keyBody.length >= 60, 'a line from the middle of the key body to look for');
  const { context, page } = await signedInAt(FORM_URL);
  try {
    await page.waitForSelector('#ocu-x509-Alias', { visible: true, timeout: config.navigationTimeoutMs });
    await fill(page, 'ocu-x509-Alias', ALIASES[0]);
    await loadFromFile(page, 'Certificate', material.certificate);
    await page.waitForFunction(() => document.querySelector('#ocu-x509-Certificate')?.value.includes('BEGIN CERTIFICATE') === true, {
      timeout: config.navigationTimeoutMs,
    });
    await loadFromFile(page, 'PrivateKey', material.key);
    await page.waitForFunction(() => (document.querySelector('#ocu-x509-PrivateKey')?.value ?? '') !== '', {
      timeout: config.navigationTimeoutMs,
    });
    await fill(page, 'ocu-x509-PeerNames', 'probe.example');
    await (await barButtons(page)).save.click();

    await page.waitForFunction(
      (sentence) => document.querySelector('.ocu-form-bar-status')?.textContent?.includes(sentence) === true,
      { timeout: config.navigationTimeoutMs },
      STRINGS.formSaved
    );
    await page.waitForFunction(
      (alias) => new URL(window.location.href).pathname.endsWith(`/security/x509/edit/${alias}`),
      { timeout: config.navigationTimeoutMs },
      ALIASES[0]
    );
    await page.waitForSelector('#ocu-x509-SubjectDN', { visible: true, timeout: config.navigationTimeoutMs });
    assert.ok((await page.$eval('#ocu-x509-SubjectDN', (node) => node.value)).includes(SUBJECT), 'the edit shows the imported subject');
    assert.equal(await page.$eval('#ocu-x509-HasPrivateKey', (node) => node.value), STRINGS.tableStatusYes, 'and a key present');
    assert.equal(await page.$('#ocu-x509-PrivateKey'), null, 'and no key field');
    const html = await page.content();
    assert.ok(!html.includes(keyBody), 'no text of the key is anywhere on the page');

    const stored = storedCredential(ALIASES[0]);
    assert.ok(stored.held, 'the instance holds the credential the form imported');
    assert.ok(stored.hasKey, 'with its private key');
  } finally {
    await context.close();
  }
});

// AC2. Mutation (Rule 19): drop `rowGet` from the X.509 list's declared read -> the subject and
// issuer cells are empty and this goes red.
test('AC2: the X.509 list shows the imported row with its subject, issuer and validity, reached by the form\'s own Cancel', async () => {
  assert.ok(storedCredential(ALIASES[0]).held, 'the import leg left the credential for this one');
  const editUrl = `/ocupilot/security/x509/edit/${ALIASES[0]}?ns=HSCUSTOM`;
  const { context, page } = await signedInAt(editUrl);
  try {
    await page.waitForSelector('#ocu-x509-SubjectDN', { visible: true, timeout: config.navigationTimeoutMs });
    const loads = [];
    page.on('load', () => loads.push(page.url()));
    await (await barButtons(page)).cancel.click();
    await page.waitForFunction(() => new URL(window.location.href).pathname.endsWith('/security/x509'), {
      timeout: config.navigationTimeoutMs,
    });
    await waitForRows(page, config.navigationTimeoutMs);
    await page.waitForFunction(
      (selector, alias) => [...document.querySelectorAll(selector)].some((row) => row.textContent.includes(alias)),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      ALIASES[0]
    );
    const row = await page.$$eval(
      ROW_SELECTOR,
      (nodes, alias) => nodes.find((node) => node.textContent.includes(alias))?.textContent ?? '',
      ALIASES[0]
    );
    assert.ok(row.split(SUBJECT).length - 1 >= 2, `the row carries the subject and the issuer: ${row}`);
    assert.match(row, /20\d\d-\d\d-\d\d/, 'and its validity dates');
    assert.deepEqual(loads, [], 'the list was reached without a page load');
  } finally {
    await context.close();
  }
});

// AC6. Mutation (Rule 19): make the store's `change` clear `FormDirty` and redeploy -> Cancel
// leaves without asking and this goes red.
test('AC6: a changed form asks before it is left, and staying keeps the edit', async () => {
  const { context, page } = await signedInAt(FORM_URL);
  try {
    await fill(page, 'ocu-x509-Alias', 'OcuPilotProbeUnsaved');
    await (await barButtons(page)).cancel.click();
    await page.waitForSelector('[role="dialog"] .ocu-dialog-title', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[role="dialog"] .ocu-dialog-title', (node) => node.textContent.trim()), STRINGS.formLeaveWithoutSaving);
    const stay = await page.$('[role="dialog"] .ocu-dialog-actions button');
    await stay.click();
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    assert.ok(new URL(page.url()).pathname.endsWith('/security/x509/edit'), 'the form is still open');
    assert.equal(await page.$eval('#ocu-x509-Alias', (node) => node.value), 'OcuPilotProbeUnsaved', 'with the edit');
  } finally {
    await context.close();
  }
});

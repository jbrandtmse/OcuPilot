/**
 * The wallet secret form in a real browser, against the throwaway instance (Story 8.6).
 *
 * Four claims, each asserted on rendered DOM, on the real URL or on the instance itself:
 *
 * 1. **A create from the Secrets list's Create stores the secret and never shows its value** (AC1):
 *    the value is masked and empty, Save replaces the route with
 *    `security/wallet/secrets/edit/<name>` and reads the saved sentence, and the page then shows the
 *    value empty, captioned as stored, with the typed value nowhere on it.
 * 2. **The Secrets list shows the new row, and its name cell opens the form** (AC7), the list reached
 *    by the form's own Cancel, a navigation inside the page rather than a load. The change event
 *    itself is pinned in `wallet-secret-form.store.spec.ts`.
 * 3. **A deep link to the form without the wallet resource is the screen-wide denial** (AC5), for a
 *    create and for an edit.
 * 4. **A changed form asks before it is left** (AC8).
 *
 * Story 18.24 adds three legs for RSA and symmetric keys: a create generates an RSA key and imports a
 * symmetric one and the form then shows each key's metadata with no key text anywhere on the page; a
 * replacement sends nothing until the secret's full name has been typed into the destructive dialog; and
 * the key form passes the structural and contrast walk in both themes.
 *
 * **It refuses the live container.** It makes its own collection, secret and principal inside the
 * throwaway and removes each by exact name, before and after.
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
import { ROW_SELECTOR, waitForRows } from './list-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';
import { INVARIANTS, VIEWPORTS, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));
const { formatDeniedScreen } = await import(join(uiRoot, 'src', 'app', 'core', 'navigation.ts'));

const config = browserConfig();

/** The probe collection, the secret the create leg stores in it, and its full name. */
const COLLECTION = 'OcuPilotProbe86Browser';
const PART = 'Probe';
const SECRET = `${COLLECTION}.${PART}`;

const LIST_URL = `/ocupilot/security/wallet/secrets/${COLLECTION}?ns=HSCUSTOM`;
const CREATE_URL = `/ocupilot/security/wallet/secrets/edit?ns=HSCUSTOM&collection=${COLLECTION}`;
const EDIT_URL = `/ocupilot/security/wallet/secrets/edit/${SECRET}?ns=HSCUSTOM`;

/** Story 18.24: the two key secrets the key legs store, and the symmetric key the import leg sends. */
const RSA_SECRET = `${COLLECTION}.GenRsa`;
const SYMMETRIC_SECRET = `${COLLECTION}.ImpSym`;
const SYMMETRIC_KEY = Buffer.from(Array.from({ length: 32 }, () => Math.floor(Math.random() * 256))).toString('base64');
const keyEditUrl = (name) => `/ocupilot/security/wallet/secrets/edit/${name}?ns=HSCUSTOM`;

/** The purpose-built principal without the wallet resource, and its role. */
const NO_WALLET_USER = 'OcuPilotWalletNoWallet';
const NO_WALLET_ROLE = 'OcuPilotWalletNoWalletRole';
const NO_WALLET_PASSWORD = 'OcuPilotWallet1';
const WALLET_PAIR = '%Admin_Wallet:USE';

/** The value the create leg types, made for this run. */
const VALUE = `OcuPilotProbe86Browser${Date.now()}`;

let browser = null;

const mark = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/** Run `lines` in `%SYS` inside the throwaway and return the value each named marker carries. */
function irisSys(lines, names = []) {
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', '%SYS'], {
    input: `${[...lines, 'Halt'].join('\n')}\n`,
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const values = {};
  for (const name of names) {
    const found = new RegExp(`OCU-${name}-START:(.*?):OCU-${name}-END`).exec(output);
    values[name] = found === null ? '' : found[1].trim();
  }
  return { values, output };
}

/** Remove the probe secret, the collection and the principal, each by its exact name. */
const cleanupLines = [
  `If ##class(%Wallet.Secret).Exists("${SECRET}") Do ##class(%Wallet.Secret).Delete("${SECRET}")`,
  `If ##class(%Wallet.Secret).Exists("${RSA_SECRET}") Do ##class(%Wallet.Secret).Delete("${RSA_SECRET}")`,
  `If ##class(%Wallet.Secret).Exists("${SYMMETRIC_SECRET}") Do ##class(%Wallet.Secret).Delete("${SYMMETRIC_SECRET}")`,
  `If ##class(%Wallet.Collection).Exists("${COLLECTION}") Do ##class(%Wallet.Collection).Delete("${COLLECTION}")`,
  `If ##class(Security.Users).Exists("${NO_WALLET_USER}") Do ##class(Security.Users).Delete("${NO_WALLET_USER}")`,
  `If ##class(Security.Roles).Exists("${NO_WALLET_ROLE}") Do ##class(Security.Roles).Delete("${NO_WALLET_ROLE}")`,
];

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec drives the throwaway, never the live container');
  assert.notEqual(config.container, '', 'it removes what it makes, so it needs the container that serves the origin');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  const { values, output } = irisSys(
    [
      ...cleanupLines,
      `Set tSC0=##class(%Wallet.Collection).Create("${COLLECTION}",{"Resource":"%Admin_Wallet:USE"})`,
      'Set tNS=$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"):"HSCUSTOM",1:"USER")',
      'Set tRes=##class(SYS.Database).%OpenId(##class(Config.Databases).Open(##class(Config.Namespaces).Open(tNS).Routines).Directory).ResourceName',
      `Set tSC1=##class(Security.Roles).Create("${NO_WALLET_ROLE}","OcuPilot wallet browser spec probe (throwaway)",tRes_":R,%Admin_Secure:U,%DB_IRISSYS:R","")`,
      `Set tSC2=##class(Security.Users).Create("${NO_WALLET_USER}","${NO_WALLET_ROLE}","${NO_WALLET_PASSWORD}","OcuPilot wallet browser spec probe (throwaway)","","","",0,1,"")`,
      mark('CREATED', '$System.Status.IsOK(tSC0)&&$System.Status.IsOK(tSC1)&&$System.Status.IsOK(tSC2)'),
      mark('WALLET', `$SYSTEM.Security.CheckUserPermission("${NO_WALLET_USER}","%Admin_Wallet","USE")`),
    ],
    ['CREATED', 'WALLET']
  );
  assert.equal(values.CREATED, '1', `the collection, role and principal were created:\n${output}`);
  assert.equal(values.WALLET, '0', 'and the principal does not hold %Admin_Wallet:USE');
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  const { values, output } = irisSys(
    [
      ...cleanupLines,
      mark('CLEAN', `('##class(%Wallet.Collection).Exists("${COLLECTION}"))&&('##class(Security.Users).Exists("${NO_WALLET_USER}"))&&('##class(Security.Roles).Exists("${NO_WALLET_ROLE}"))`),
    ],
    ['CLEAN']
  );
  assert.equal(values.CLEAN, '1', `the collection, the principal and its role are gone:\n${output}`);
});

/** Whether the instance holds the secret `name`, compared exactly. */
function holds(name) {
  const { values } = irisSys([mark('HELD', `##class(%Wallet.Secret).Exists("${name}")`)], ['HELD']);
  return values.HELD === '1';
}

/** A fresh context signed in through the shell's own form, landed at `url`. */
async function signedInAt(url, user = config.username, password = config.password) {
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

test('AC1: the Secrets list\'s Create opens the form, and a create stores the secret with its value masked, emptied and captioned', async () => {
  const { context, page } = await signedInAt(LIST_URL);
  try {
    const create = await page.waitForSelector('.ocu-command-bar button.ocu-button-primary', {
      visible: true,
      timeout: config.navigationTimeoutMs,
    });
    await create.click();
    await page.waitForFunction(
      (collection) => {
        const url = new URL(window.location.href);
        return url.pathname.endsWith('/security/wallet/secrets/edit') && url.searchParams.get('collection') === collection;
      },
      { timeout: config.navigationTimeoutMs },
      COLLECTION
    );
    await page.waitForSelector('#ocu-wallet-Secret', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('#ocu-wallet-Collection', (node) => node.value), COLLECTION, 'the collection is the one the list showed');
    assert.equal(await page.$eval('#ocu-wallet-Secret', (node) => node.type), 'password', 'the value is masked');
    assert.equal(await page.$eval('#ocu-wallet-Secret', (node) => node.value), '', 'and not pre-filled');
    assert.equal(
      await page.$eval('.ocu-reveal-toggle', (node) => node.getAttribute('aria-label')),
      STRINGS.accountShowPassword,
      'behind a labelled toggle'
    );

    await fill(page, 'ocu-wallet-Name', PART);
    await fill(page, 'ocu-wallet-Secret', VALUE);
    await fill(page, 'ocu-wallet-AllowedHosts', 'probe.example');
    await (await barButtons(page)).save.click();

    await page.waitForFunction(
      (sentence) => document.querySelector('.ocu-form-bar-status')?.textContent?.includes(sentence) === true,
      { timeout: config.navigationTimeoutMs },
      STRINGS.formSaved
    );
    await page.waitForFunction(
      (name) => decodeURIComponent(decodeURIComponent(new URL(window.location.href).pathname)).endsWith(`/security/wallet/secrets/edit/${name}`),
      { timeout: config.navigationTimeoutMs },
      SECRET
    );
    await page.waitForSelector('#ocu-wallet-Secret-caption', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('#ocu-wallet-Secret-caption', (node) => node.textContent.trim()), STRINGS.formSecretStored, 'the value is captioned as stored');
    assert.equal(await page.$eval('#ocu-wallet-Secret', (node) => node.value), '', 'and the field is empty');
    assert.equal(await page.$eval('#ocu-wallet-AllowedHosts', (node) => node.value), 'probe.example', 'the edit shows the settings saved');
    assert.ok(!(await page.content()).includes(VALUE), 'the value is nowhere on the page');
    assert.ok(holds(SECRET), 'and the instance holds the secret');
  } finally {
    await context.close();
  }
});

test('AC7: the Secrets list shows the new secret, reached by the form\'s own Cancel, and its name cell opens the form', async () => {
  assert.ok(holds(SECRET), 'the create leg left the secret for this one');
  const { context, page } = await signedInAt(EDIT_URL);
  try {
    await page.waitForSelector('#ocu-wallet-Secret', { visible: true, timeout: config.navigationTimeoutMs });
    const loads = [];
    page.on('load', () => loads.push(page.url()));
    await (await barButtons(page)).cancel.click();
    await page.waitForFunction(
      (collection) => new URL(window.location.href).pathname.endsWith(`/security/wallet/secrets/${collection}`),
      { timeout: config.navigationTimeoutMs },
      COLLECTION
    );
    await waitForRows(page, config.navigationTimeoutMs);
    await page.waitForFunction(
      (selector, name) => [...document.querySelectorAll(selector)].some((row) => row.textContent.includes(name)),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      SECRET
    );
    assert.deepEqual(loads, [], 'the list was reached without a page load');
    await page.evaluate((name) => {
      const links = [...document.querySelectorAll('[role="grid"] .ocu-data-table-body .ocu-data-table-link')];
      links.find((link) => link.textContent.trim() === name).click();
    }, SECRET);
    await page.waitForFunction(
      (name) => decodeURIComponent(decodeURIComponent(new URL(window.location.href).pathname)).endsWith(`/security/wallet/secrets/edit/${name}`),
      { timeout: config.navigationTimeoutMs },
      SECRET
    );
    await page.waitForSelector('#ocu-wallet-Name', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('#ocu-wallet-Name', (node) => node.value), PART, 'the name cell opens the form over that secret');
  } finally {
    await context.close();
  }
});

test('AC5: a deep link to the form without the wallet resource is the screen-wide denial naming it', async () => {
  for (const url of [CREATE_URL, EDIT_URL]) {
    const { context, page } = await signedInAt(url, NO_WALLET_USER, NO_WALLET_PASSWORD);
    try {
      await page.waitForSelector('app-screen-denied .ocu-screen-denied-reason', { timeout: config.navigationTimeoutMs });
      const denied = await page.evaluate(() => ({
        title: document.querySelector('app-screen-denied .ocu-screen-denied-title').textContent.trim(),
        reason: document.querySelector('app-screen-denied .ocu-screen-denied-reason').textContent.trim(),
        form: document.querySelector('#ocu-wallet-Secret') !== null,
      }));
      assert.equal(denied.title, STRINGS.walletSecretFormLabel, `${url}: the screen title`);
      assert.equal(denied.reason, formatDeniedScreen(STRINGS.privilegeDeniedScreen, WALLET_PAIR, STRINGS.walletSecretFormLabel), `${url}: naming the wallet pair`);
      assert.equal(denied.form, false, `${url}: and no form`);
    } finally {
      await context.close();
    }
  }
});

test('AC8: a changed form asks before it is left, and staying keeps the edit', async () => {
  const { context, page } = await signedInAt(CREATE_URL);
  try {
    await fill(page, 'ocu-wallet-Name', 'Unsaved');
    await (await barButtons(page)).cancel.click();
    await page.waitForSelector('[role="dialog"] .ocu-dialog-title', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[role="dialog"] .ocu-dialog-title', (node) => node.textContent.trim()), STRINGS.formLeaveWithoutSaving);
    await (await page.$('[role="dialog"] .ocu-dialog-actions button')).click();
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    assert.ok(new URL(page.url()).pathname.endsWith('/security/wallet/secrets/edit'), 'the form is still open');
    assert.equal(await page.$eval('#ocu-wallet-Name', (node) => node.value), 'Unsaved', 'with the edit');
  } finally {
    await context.close();
  }
});

/** The stored length of the key secret `name` as the instance holds it, or `''` for none. */
function storedLength(name) {
  const { values } = irisSys(
    [`Set tE=##class(%Wallet.Secret).Exists("${name}",.tS)`, mark('LEN', '$Select(tE:tS.Length,1:"")')],
    ['LEN']
  );
  return values.LEN;
}

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/** Wait until no CSS transition is running, so a contrast read measures the theme it is in. */
function transitionsSettled(page) {
  return page.waitForFunction(
    () => document.getAnimations().every((animation) => !(animation instanceof CSSTransition) || animation.playState !== 'running'),
    { timeout: config.navigationTimeoutMs }
  );
}

/** DW-1337 on `route`: 1280 light (every invariant), 720 light and 1280 dark, against the baseline. */
async function assertStructure(page, route) {
  const found = [];
  const passes = [
    { viewport: VIEWPORTS.wide, theme: 'light', checks: INVARIANTS },
    { viewport: VIEWPORTS.narrow, theme: 'light', checks: ['name', 'min-width', 'overflow'] },
    { viewport: VIEWPORTS.wide, theme: 'dark', checks: ['contrast'] },
  ];
  const minimums = componentMinimums();
  const surfaces = {};
  for (const { viewport, theme, checks } of passes) {
    await page.setViewport(viewport);
    await page.evaluate((dark) => document.documentElement.classList.toggle('ocu-theme-dark', dark), theme === 'dark');
    await frames(page);
    await transitionsSettled(page);
    surfaces[theme] = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
    const { entries } = await detectScreen(page, { route, checks, viewport: viewport.width, theme, minimums });
    found.push(...entries);
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await frames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  const fresh = compare(collapse(found), readBaseline()?.entries ?? []).fresh;
  assert.deepEqual(fresh.map((entry) => `${entry.key}: ${entry.measured}`), [], `no structural or contrast violation on ${route}`);
}

/** Save the open create form and wait for the route to become the new secret's edit. */
async function saveCreateAndLand(page, name) {
  await (await barButtons(page)).save.click();
  await page.waitForFunction(
    (wanted) => decodeURIComponent(decodeURIComponent(new URL(window.location.href).pathname)).endsWith(`/security/wallet/secrets/edit/${wanted}`),
    { timeout: config.navigationTimeoutMs },
    name
  );
  await page.waitForFunction(
    (sentence) => document.querySelector('.ocu-form-bar-status')?.textContent?.includes(sentence) === true,
    { timeout: config.navigationTimeoutMs },
    STRINGS.formSaved
  );
}

test('Story 18.24: a create generates an RSA key and imports a symmetric key, each shown by its metadata alone', async () => {
  const rsa = await signedInAt(CREATE_URL);
  try {
    await page_waitForType(rsa.page);
    await rsa.page.select('#ocu-wallet-Type', 'rsa');
    await rsa.page.waitForSelector('#ocu-wallet-Length', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await rsa.page.$('#ocu-wallet-Secret'), null, 'a key choice replaces the value field');
    await fill(rsa.page, 'ocu-wallet-Name', 'GenRsa');
    await saveCreateAndLand(rsa.page, RSA_SECRET);
    await rsa.page.waitForSelector('#ocu-wallet-HasPrivateKey', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await rsa.page.$eval('#ocu-wallet-KeyLength', (node) => node.value), STRINGS.walletKeyBits2048, 'the new key reads 2048 bits');
    assert.equal(await rsa.page.$eval('#ocu-wallet-HasPrivateKey', (node) => node.value), STRINGS.tableStatusYes, 'with a private key');
    assert.equal(await rsa.page.$eval('#ocu-wallet-HasCertificate', (node) => node.value), STRINGS.tableStatusNo, 'and no certificate');
    assert.equal(storedLength(RSA_SECRET), '2048', 'and the instance holds a 2048-bit pair');
    assert.ok(!(await rsa.page.content()).includes('BEGIN'), 'no key block is on the page');
  } finally {
    await rsa.context.close();
  }

  const sym = await signedInAt(CREATE_URL);
  try {
    await page_waitForType(sym.page);
    await sym.page.select('#ocu-wallet-Type', 'symmetric');
    await sym.page.waitForSelector('#ocu-wallet-SourceImport', { visible: true, timeout: config.navigationTimeoutMs });
    await sym.page.click('#ocu-wallet-SourceImport');
    await fill(sym.page, 'ocu-wallet-Name', 'ImpSym');
    await fill(sym.page, 'ocu-wallet-Secret64', SYMMETRIC_KEY);
    assert.equal(await sym.page.$eval('#ocu-wallet-Secret64', (node) => node.type), 'password', 'the key is masked');
    await saveCreateAndLand(sym.page, SYMMETRIC_SECRET);
    await sym.page.waitForSelector('#ocu-wallet-KeyId', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await sym.page.$eval('#ocu-wallet-KeyLength', (node) => node.value), STRINGS.walletKeyBytes32, 'the imported key reads 32 bytes');
    assert.notEqual(await sym.page.$eval('#ocu-wallet-KeyId', (node) => node.value), '', 'with a key id');
    assert.equal(await sym.page.$eval('#ocu-wallet-Secret64', (node) => node.value), '', 'and the key field is empty');
    assert.ok(!(await sym.page.content()).includes(SYMMETRIC_KEY), 'the key is nowhere on the page');
    assert.equal(storedLength(SYMMETRIC_SECRET), '32', 'and the instance holds the key with its length');
  } finally {
    await sym.context.close();
  }
});

/** Wait for the create form's Type choice. */
function page_waitForType(page) {
  return page.waitForSelector('#ocu-wallet-Type', { visible: true, timeout: config.navigationTimeoutMs });
}

test('Story 18.24: a replacement sends nothing until the secret\'s full name is typed into the destructive dialog', async () => {
  assert.equal(storedLength(RSA_SECRET), '2048', 'the create leg left a 2048-bit key');
  const { context, page } = await signedInAt(keyEditUrl(RSA_SECRET));
  try {
    await page.waitForSelector('#ocu-wallet-Length', { visible: true, timeout: config.navigationTimeoutMs });
    await page.select('#ocu-wallet-Length', '3072');
    await (await barButtons(page)).save.click();
    await page.waitForSelector('[role="dialog"] .ocu-typed-name-field', { visible: true, timeout: config.navigationTimeoutMs });
    const dialog = await page.$eval('[role="dialog"]', (node) => ({
      title: node.querySelector('.ocu-dialog-title')?.textContent.trim() ?? '',
      text: node.textContent,
    }));
    assert.ok(dialog.title.includes(STRINGS.walletReplaceKey) && dialog.title.includes(RSA_SECRET), `the title names the action and the secret: ${dialog.title}`);
    assert.ok(dialog.text.includes(STRINGS.walletKeyReplaceRsaConsequence), 'the body states the consequence');
    assert.equal(storedLength(RSA_SECRET), '2048', 'nothing was sent before the name was typed');
    await page.type('[role="dialog"] .ocu-typed-name-field', RSA_SECRET);
    await page.click('[role="dialog"] button.ocu-button-destructive');
    await page.waitForFunction(
      (sentence) => document.querySelector('.ocu-form-bar-status')?.textContent?.includes(sentence) === true,
      { timeout: config.navigationTimeoutMs },
      STRINGS.formSaved
    );
    assert.equal(storedLength(RSA_SECRET), '3072', 'the typed name released the replacement, and the instance holds the new pair');
    assert.equal(await page.$eval('#ocu-wallet-KeyLength', (node) => node.value), STRINGS.walletKeyBits3072, 'and the form reads it');
  } finally {
    await context.close();
  }
});

test('Story 18.24: the key form passes the structural and contrast walk in both themes', async () => {
  const { context, page } = await signedInAt(keyEditUrl(RSA_SECRET));
  try {
    await page.waitForSelector('#ocu-wallet-HasPrivateKey', { visible: true, timeout: config.navigationTimeoutMs });
    await assertStructure(page, 'security/wallet/secrets/edit');
    await page.waitForSelector('#ocu-wallet-SourceImport', { visible: true, timeout: config.navigationTimeoutMs });
    await page.click('#ocu-wallet-SourceImport');
    await page.waitForSelector('#ocu-wallet-Certificate', { visible: true, timeout: config.navigationTimeoutMs });
    await assertStructure(page, 'security/wallet/secrets/edit');
  } finally {
    await context.close();
  }
});

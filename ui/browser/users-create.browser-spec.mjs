/**
 * The create-a-user form in a real browser, against the throwaway instance (Story 8.2).
 *
 * Five claims, each asserted on rendered DOM, on the real URL or on the instance itself:
 *
 * 1. **The form captures the field set in the classic order** (AC1): name, full name, password,
 *    expiration date, startup namespace, startup routine, then roles.
 * 2. **The password is never pre-filled or echoed** (AC2): the field is empty on arrival and asks
 *    the browser for a new password, and after a Save the user editor the create opens (Story 9.1)
 *    carries no password field and shows the password nowhere.
 * 3. **A privileged role is available, and ticking it states the privilege-grant consequence at the
 *    Roles field** (AC3, AD-10), from the bootstrap read's mark; an ordinary role states none.
 * 4. **A valid Save creates the account** (AC4) with the fields sent, replaces the route with
 *    `permissions/users/edit/<id>` -- the user editor, over the new account -- reads the saved
 *    sentence, and the Users list then shows it. The
 *    change event itself is pinned in `user-create-form.store.spec.ts`, for the reason
 *    `web-applications-create.browser-spec.mjs` gives.
 * 5. **The Users list offers Create** (AC1), and it opens this form.
 *
 * **It refuses the live container.** Every account it creates is named below and removed by that
 * exact name through the vendor's own `Security.Users.Delete` inside the throwaway, before and after.
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
import { waitForRows } from './list-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const LIST_URL = '/ocupilot/permissions/users?ns=HSCUSTOM';
const FORM_URL = '/ocupilot/permissions/users/edit?ns=HSCUSTOM';

/** Every account this spec creates, removed by exact name in `before` and `after`. */
const NAMES = ['OcuPilotProbeUserCreate', 'OcuPilotProbeUserNoEcho'];

/** A password the instance's default pattern (`3.255ANP`) accepts. Never asserted on screen. */
const PROBE_PASSWORD = 'ProbePass2026';

const PROBE_FULL_NAME = 'OcuPilot probe account';

/**
 * Roles whose grant is privileged: %All by name, and %Manager through an administrative resource
 * it carries (AD-10).
 */
const PRIVILEGED = ['%All', '%Manager'];

/** The Roles field's consequence line, which the page draws while a privileged role is ticked. */
const ROLES_EFFECT = '#ocu-user-Roles-effect';

let browser = null;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec drives the throwaway, never the live container');
  assert.notEqual(config.container, '', 'it removes the accounts it creates, so it needs the container that serves the origin');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  removeProbeUsers();
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  removeProbeUsers();
  if (browser !== null) await browser.close();
});

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

/** Remove every account this spec creates, by its exact name -- never a prefix sweep. */
function removeProbeUsers() {
  irisSys(NAMES.map((name) => `Do ##class(Security.Users).Delete("${name}")`));
}

/** The stored account `name` as the vendor reads it, or `null` when it does not exist. */
function storedUser(name) {
  const output = irisSys([
    `Set tOK = ##class(Security.Users).Get("${name}", .tProps)`,
    'Write "OCU-OK-START:",tOK,":OCU-OK-END",!',
    'Write "OCU-FULL-START:",$Get(tProps("FullName")),":OCU-FULL-END",!',
    'Write "OCU-ROLES-START:",$Get(tProps("Roles")),":OCU-ROLES-END",!',
  ]);
  const ok = /OCU-OK-START:(.*?):OCU-OK-END/.exec(output);
  if (ok === null || ok[1].trim() !== '1') return null;
  const fullName = /OCU-FULL-START:(.*?):OCU-FULL-END/.exec(output);
  const roles = /OCU-ROLES-START:(.*?):OCU-ROLES-END/.exec(output);
  return {
    fullName: fullName === null ? '' : fullName[1],
    roles: roles === null || roles[1] === '' ? [] : roles[1].split(','),
  };
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

/** The Save button in the sticky bar. */
async function saveButton(page) {
  const buttons = await page.$$('.ocu-form-bar-actions button');
  const save = buttons.at(-1);
  assert.ok(save, 'the sticky bar carries a primary action');
  return save;
}

/** Every role checkbox the form draws: its role name, whether it is disabled, and its description. */
async function roleBoxes(page) {
  return page.$$eval('fieldset.ocu-form-authe .ocu-field-checkbox', (labels) =>
    labels.map((label) => {
      const input = label.querySelector('input[type="checkbox"]');
      const describedBy = input.getAttribute('aria-describedby');
      const description = describedBy === null ? '' : document.getElementById(describedBy)?.textContent?.trim() ?? '';
      return { name: label.textContent.trim(), id: input.id, disabled: input.disabled, description };
    })
  );
}

/** Wait for the sticky bar's saved sentence and the route replaced with the new account's URL. */
async function waitForSaved(page) {
  await page.waitForFunction(
    (sentence) => document.querySelector('.ocu-form-bar-status')?.textContent?.includes(sentence) === true,
    { timeout: config.navigationTimeoutMs },
    STRINGS.formSaved
  );
  await page.waitForFunction(
    () => /\/permissions\/users\/edit\/[^/]+$/.test(new URL(window.location.href).pathname),
    { timeout: config.navigationTimeoutMs }
  );
}

// AC1. Mutation (Rule 19): swap the Password and Full name blocks in the page template -> this
// goes red naming the order.
test('AC1: the form captures name, full name, password, expiry, startup namespace, startup routine and roles, in that order', async () => {
  const { context, page } = await signedInAt(FORM_URL);
  try {
    await page.waitForSelector('#ocu-user-Name', { visible: true, timeout: config.navigationTimeoutMs });
    const labels = await page.$$eval(
      [
        '.ocu-form-fields > .ocu-field:not(.ocu-form-authe) > .ocu-field-label',
        '.ocu-form-fields > .ocu-form-authe > legend',
      ].join(', '),
      (nodes) => nodes.map((node) => node.textContent.trim())
    );
    assert.deepEqual(labels, [
      STRINGS.tableColumnName,
      STRINGS.userColumnFullName,
      STRINGS.fieldPassword,
      STRINGS.userFormExpiry,
      STRINGS.userFormNamespace,
      STRINGS.userFormRoutine,
      STRINGS.userColumnRoles,
    ]);
    assert.equal(await page.$eval('#ocu-user-Password', (node) => node.type), 'password', 'the password is masked');
    assert.equal(await page.$eval('#ocu-user-ExpirationDate', (node) => node.type), 'date', 'the expiry is a date control');
    const roles = await roleBoxes(page);
    assert.ok(roles.length > 0, 'the roles are the instance\'s own, and it holds some');
  } finally {
    await context.close();
  }
});

// AC2. Mutation (Rule 19): render the create page on the id route instead of the editor -> the
// after-save leg goes red on the password field still standing.
test('AC2: the password is never pre-filled, asks for a new password, and is on no screen after a Save', async () => {
  const { context, page } = await signedInAt(FORM_URL);
  try {
    await page.waitForSelector('#ocu-user-Password', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('#ocu-user-Password', (node) => node.value), '', 'nothing is pre-filled');
    assert.equal(
      await page.$eval('#ocu-user-Password', (node) => node.getAttribute('autocomplete')),
      'new-password',
      'and the browser is asked for a new password, never a saved one'
    );
    assert.equal(await page.$('#ocu-user-Password-caption'), null, 'no stored caption before a Save');

    await fill(page, 'ocu-user-Name', NAMES[1]);
    await fill(page, 'ocu-user-Password', PROBE_PASSWORD);
    await (await saveButton(page)).click();
    await waitForSaved(page);

    // Story 9.1: the create opens the user editor over the new account, which carries no password.
    await page.waitForSelector('#ocu-user-edit-Name', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('#ocu-user-edit-Name', (node) => node.value.toLowerCase()), NAMES[1].toLowerCase(), 'the editor opens on the new account');
    assert.equal(await page.$('input[type="password"]'), null, 'and no password field stands on it');
    const text = await page.evaluate(() => document.body.innerText);
    assert.ok(!text.includes(PROBE_PASSWORD), 'the password is echoed nowhere on the page');
    assert.ok(storedUser(NAMES[1]) !== null, 'the account was created');
  } finally {
    await context.close();
  }
});

// AC3, AD-10. Mutation (Rule 19): make the page's `privilegedChecked` answer false -> the
// consequence leg goes red on %All; restore `[disabled]` on a privileged checkbox -> the
// availability leg goes red.
test('AC3: a privileged role is available, and ticking it states the privilege-grant consequence', async () => {
  const { context, page } = await signedInAt(FORM_URL);
  try {
    await page.waitForSelector('fieldset.ocu-form-authe', { visible: true, timeout: config.navigationTimeoutMs });
    const roles = await roleBoxes(page);
    assert.equal(await page.$(ROLES_EFFECT), null, 'no consequence is stated before a privileged role is ticked');
    for (const name of PRIVILEGED) {
      const role = roles.find((entry) => entry.name === name);
      assert.ok(role, `the instance offers ${name}: ${JSON.stringify(roles.map((entry) => entry.name))}`);
      assert.equal(role.disabled, false, `${name} is available`);
      await page.evaluate((id) => document.getElementById(id).click(), role.id);
      await page.waitForSelector(ROLES_EFFECT, { visible: true, timeout: config.navigationTimeoutMs });
      assert.equal(await page.$eval(ROLES_EFFECT, (node) => node.textContent.trim()), STRINGS.privilegedGrantEffect);
      const ticked = (await roleBoxes(page)).find((entry) => entry.name === name);
      assert.equal(ticked.description, STRINGS.privilegedGrantEffect, `${name} is described by the consequence while ticked`);
      await page.evaluate((id) => document.getElementById(id).click(), role.id);
      await page.waitForFunction((selector) => document.querySelector(selector) === null, { timeout: config.navigationTimeoutMs }, ROLES_EFFECT);
    }
    const ordinary = roles.find((entry) => entry.name === '%Developer');
    assert.ok(ordinary, 'the instance offers %Developer');
    await page.evaluate((id) => document.getElementById(id).click(), ordinary.id);
    assert.equal(await page.$(ROLES_EFFECT), null, 'an ordinary role states no consequence');
  } finally {
    await context.close();
  }
});

// AC4. Mutation (Rule 19): drop the route replacement from `onSave` -> the URL leg goes red; drop
// the `arriveSaved` call from `onSave` -> the editor's Saved leg goes red.
test('AC4: a valid Save creates the account with the sent fields, replaces the route, and the Users list shows it', async () => {
  const { context, page } = await signedInAt(FORM_URL);
  try {
    await page.waitForSelector('#ocu-user-Name', { visible: true, timeout: config.navigationTimeoutMs });
    await fill(page, 'ocu-user-Name', NAMES[0]);
    await fill(page, 'ocu-user-FullName', PROBE_FULL_NAME);
    await fill(page, 'ocu-user-Password', PROBE_PASSWORD);
    // A privileged role applies on Save (AD-10): the account holds %All once created.
    const boxes = await roleBoxes(page);
    const granted = boxes.find((entry) => entry.name === '%Developer');
    const privileged = boxes.find((entry) => entry.name === '%All');
    assert.ok(granted && privileged, 'the instance offers %Developer and %All');
    await page.evaluate((id) => document.getElementById(id).click(), granted.id);
    await page.evaluate((id) => document.getElementById(id).click(), privileged.id);
    await (await saveButton(page)).click();
    await waitForSaved(page);

    const path = await page.evaluate(() => new URL(window.location.href).pathname);
    // Case-insensitive: the instance keys an account on its lowercased name (AD-13).
    assert.ok(
      path.toLowerCase().endsWith(`/permissions/users/edit/${NAMES[0].toLowerCase()}`),
      `the URL names the account: ${path}`
    );
    // Story 9.1: that URL is the user editor, reading the account the create made.
    await page.waitForFunction(
      (fullName) => document.querySelector('#ocu-user-edit-FullName')?.value === fullName,
      { timeout: config.navigationTimeoutMs },
      PROBE_FULL_NAME
    );
    assert.equal(
      await page.$eval('app-user-editor-page .ocu-form-bar-status', (node) => node.textContent.trim()),
      STRINGS.formSaved,
      'and the editor\u2019s own form bar reads Saved'
    );

    const stored = storedUser(NAMES[0]);
    assert.ok(stored !== null, 'the instance holds the account the form created');
    assert.equal(stored.fullName, PROBE_FULL_NAME, 'with the full name sent');
    assert.ok(stored.roles.includes(granted.name), `and the role sent: ${JSON.stringify(stored.roles)}`);
    assert.ok(stored.roles.includes('%All'), `and %All, granted: ${JSON.stringify(stored.roles)}`);

    await page.goto(`${config.origin}${LIST_URL}`, { waitUntil: 'networkidle2' });
    await leaveFirstLoginGate(page, config.navigationTimeoutMs, LIST_URL);
    await waitForRows(page, config.navigationTimeoutMs);
    const rows = await page.$$eval('[role="grid"] .ocu-data-table-body [role="row"]', (nodes) =>
      nodes.map((node) => node.textContent)
    );
    assert.ok(
      rows.some((text) => text.includes(NAMES[0])),
      `the account the form created is in the Users list: ${JSON.stringify(rows.slice(0, 8))}`
    );
  } finally {
    await context.close();
  }
});

// AC1's entry point. Mutation (Rule 19): drop the `UserActions` injection from `app.ts` -> the
// command bar offers no Create on the Users list and this goes red.
test('AC1: the Users list offers Create, and it opens the create form', async () => {
  const { context, page } = await signedInAt(LIST_URL);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const create = await page.waitForSelector('.ocu-command-bar button.ocu-button-primary', {
      visible: true,
      timeout: config.navigationTimeoutMs,
    });
    assert.equal(
      await create.evaluate((node) => node.textContent.trim()),
      STRINGS.actionCreate,
      'the command bar offers the declared primary action'
    );
    await create.click();
    await page.waitForFunction(
      () => new URL(window.location.href).pathname.endsWith('/permissions/users/edit'),
      { timeout: config.navigationTimeoutMs }
    );
    await page.waitForSelector('#ocu-user-Name', { visible: true, timeout: config.navigationTimeoutMs });
  } finally {
    await context.close();
  }
});

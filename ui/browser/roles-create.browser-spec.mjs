/**
 * The create-a-role form in a real browser, against the throwaway instance (Story 8.3).
 *
 * Five claims, each asserted on rendered DOM, on the real URL or on the instance itself:
 *
 * 1. **The form captures the field set in the classic order** (AC1): name, description, the
 *    resource grants, then the granted roles.
 * 2. **A resource grant is added, edited and removed in its dialog** (AC2), which shows the current
 *    and the resulting grant before Confirm applies it, and offers only the letters the resource
 *    admits.
 * 3. **A privileged choice is available and states its consequence** (AC4, AD-10): a granted role
 *    or a resource grant that grants `%All` or an administrative privilege shows the privilege-grant
 *    line at its field and in the grant dialog, and a Save applies it. Write on a database ticks and
 *    locks Read (DW-1514).
 * 4. **A valid Save creates the role** (AC5) with the grants sent, replaces the route with
 *    `permissions/roles/edit/<id>` -- the role editor, reading the saved sentence and, after a hard
 *    reload, the role -- and the Roles list then shows it. The change event itself is pinned in
 *    `role-create-form.store.spec.ts`.
 * 5. **The Roles list offers Create** (AC1), and it opens this form.
 *
 * **It refuses the live container.** Every role it creates is named below and removed by that exact
 * name through the vendor's own `Security.Roles.Delete` inside the throwaway, before and after.
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
import { filterToSubset, viewCount, waitForRows } from './list-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const LIST_URL = '/ocupilot/permissions/roles?ns=HSCUSTOM';
const FORM_URL = '/ocupilot/permissions/roles/edit?ns=HSCUSTOM';

/** Every role this spec creates, removed by exact name in `before` and `after`. */
const NAMES = ['OcuPilotProbeRoleCreate', 'OcuPilotProbeRolePrivileged'];

const PROBE_DESCRIPTION = 'OcuPilot probe role';

/** Granted roles whose grant is privileged: %All by name, %Manager through an administrative resource. */
const PRIVILEGED_ROLES = ['%All', '%Manager'];

/** The consequence lines the page and the dialog draw while a privileged choice is made. */
const ROLES_EFFECT = '#ocu-role-GrantedRoles-effect';
const RESOURCES_EFFECT = '#ocu-role-Resources-effect';
const DIALOG_EFFECT = '#ocu-role-grant-effect';

let browser = null;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec drives the throwaway, never the live container');
  assert.notEqual(config.container, '', 'it removes the roles it creates, so it needs the container that serves the origin');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  removeProbeRoles();
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  removeProbeRoles();
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

/** Remove every role this spec creates, by its exact name -- never a prefix sweep. */
function removeProbeRoles() {
  irisSys(NAMES.map((name) => `If ##class(Security.Roles).Exists("${name}") Do ##class(Security.Roles).Delete("${name}")`));
}

/** The stored role `name` as the vendor reads it, or `null` when it does not exist. */
function storedRole(name) {
  const output = irisSys([
    `Set tOK = ##class(Security.Roles).Get("${name}", .tProps)`,
    'Write "OCU-OK-START:",tOK,":OCU-OK-END",!',
    'Write "OCU-DESC-START:",$Get(tProps("Description")),":OCU-DESC-END",!',
    'Write "OCU-RES-START:",$Get(tProps("Resources")),":OCU-RES-END",!',
    'Write "OCU-ROLES-START:",$Get(tProps("GrantedRoles")),":OCU-ROLES-END",!',
  ]);
  const ok = /OCU-OK-START:(.*?):OCU-OK-END/.exec(output);
  if (ok === null || ok[1].trim() !== '1') return null;
  const read = (tag) => {
    const match = new RegExp(`OCU-${tag}-START:(.*?):OCU-${tag}-END`).exec(output);
    return match === null ? '' : match[1];
  };
  return {
    description: read('DESC'),
    resources: read('RES') === '' ? [] : read('RES').split(','),
    grantedRoles: read('ROLES') === '' ? [] : read('ROLES').split(','),
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

/** Every granted-role checkbox the form draws: its name, whether it is disabled, and its description. */
async function roleBoxes(page) {
  return page.$$eval('#ocu-role-GrantedRoles .ocu-field-checkbox', (labels) =>
    labels.map((label) => {
      const input = label.querySelector('input[type="checkbox"]');
      const describedBy = input.getAttribute('aria-describedby');
      const description = describedBy === null ? '' : document.getElementById(describedBy)?.textContent?.trim() ?? '';
      return { name: label.textContent.trim(), id: input.id, disabled: input.disabled, description };
    })
  );
}

/** Click the button inside `scope` whose text is `label`. */
async function clickButton(page, scope, label) {
  const clicked = await page.$$eval(
    `${scope} button`,
    (buttons, wanted) => {
      const button = buttons.find((candidate) => candidate.textContent.trim() === wanted);
      if (button === undefined) return false;
      button.click();
      return true;
    },
    label
  );
  assert.ok(clicked, `${scope} offers ${label}`);
}

/** The grant dialog's current and resulting lines. */
async function grantLines(page) {
  return {
    current: await page.$eval('#ocu-role-grant-current', (node) => node.textContent.trim()),
    resulting: await page.$eval('#ocu-role-grant-resulting', (node) => node.textContent.trim()),
  };
}

/**
 * Assert the grant dialog's two lines read `expected`, once the view has rendered the last click:
 * a zoneless view paints on the next frame, so the lines are waited for and then read.
 */
async function expectLines(page, expected, message) {
  await page
    .waitForFunction(
      (current, resulting) =>
        document.getElementById('ocu-role-grant-current')?.textContent?.trim() === current &&
        document.getElementById('ocu-role-grant-resulting')?.textContent?.trim() === resulting,
      { timeout: config.navigationTimeoutMs },
      expected.current,
      expected.resulting
    )
    .catch(() => undefined);
  assert.deepEqual(await grantLines(page), expected, message);
}

/** Wait until the form lists exactly `expected` grant lines, then assert it. */
async function expectListed(page, expected) {
  await page
    .waitForFunction(
      (wanted) =>
        JSON.stringify([...document.querySelectorAll('.ocu-role-grant-line')].map((node) => node.textContent.trim())) === wanted,
      { timeout: config.navigationTimeoutMs },
      JSON.stringify(expected)
    )
    .catch(() => undefined);
  assert.deepEqual(await listedGrants(page), expected);
}

/** The grant lines the form lists. */
async function listedGrants(page) {
  return page.$$eval('.ocu-role-grant-line', (nodes) => nodes.map((node) => node.textContent.trim()));
}

/** Open the Add dialog, choose `resource` and tick `letters`, leaving the dialog open. */
async function addGrant(page, resource, letters) {
  await page.click('#ocu-role-grant-add');
  await page.waitForSelector('[role="dialog"] #ocu-role-grant-resource', { visible: true, timeout: config.navigationTimeoutMs });
  await page.select('#ocu-role-grant-resource', resource);
  for (const letter of letters) await page.click(`#ocu-role-grant-${letter}`);
}

async function waitForDialogClosed(page) {
  await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, {
    timeout: config.navigationTimeoutMs,
  });
}

// AC1. Mutation (Rule 19): swap the Description and Resources blocks in the page template -> this
// goes red naming the order.
test('AC1: the form captures name, description, resources and granted roles, in that order', async () => {
  const { context, page } = await signedInAt(FORM_URL);
  try {
    await page.waitForSelector('#ocu-role-Name', { visible: true, timeout: config.navigationTimeoutMs });
    const labels = await page.$$eval(
      [
        '.ocu-form-fields > .ocu-field:not(.ocu-form-authe) > .ocu-field-label',
        '.ocu-form-fields > .ocu-form-authe > legend',
      ].join(', '),
      (nodes) => nodes.map((node) => node.textContent.trim())
    );
    assert.deepEqual(labels, [
      STRINGS.tableColumnName,
      STRINGS.tableColumnDescription,
      STRINGS.resourceListLabel,
      STRINGS.roleFormGrantedRoles,
    ]);
    assert.ok((await roleBoxes(page)).length > 0, 'the granted roles are the instance\'s own, and it holds some');
  } finally {
    await context.close();
  }
});

// AC2. Mutation (Rule 19): render the resulting grant in the current line -> the add leg goes red.
test('AC2: a grant is added, edited and removed in its dialog, which shows the current and the resulting grant', async () => {
  const { context, page } = await signedInAt(FORM_URL);
  try {
    await page.waitForSelector('#ocu-role-grant-add', { visible: true, timeout: config.navigationTimeoutMs });
    const readWrite = `%DB_USER: ${STRINGS.permissionRead}, ${STRINGS.permissionWrite}`;
    const readOnly = `%DB_USER: ${STRINGS.permissionRead}`;

    await addGrant(page, '%DB_USER', 'RW');
    assert.equal(await page.$('#ocu-role-grant-U'), null, 'a database offers no Use');
    await expectLines(page, { current: STRINGS.roleGrantNone, resulting: readWrite }, 'add: nothing held, the grant to be');
    await clickButton(page, '[role="dialog"]', STRINGS.actionConfirm);
    await waitForDialogClosed(page);
    await expectListed(page, [readWrite]);

    await clickButton(page, '.ocu-role-grant', STRINGS.agentPanelSecretWarningEdit);
    await page.waitForSelector('[role="dialog"] #ocu-role-grant-W', { visible: true, timeout: config.navigationTimeoutMs });
    await page.click('#ocu-role-grant-W');
    await expectLines(page, { current: readWrite, resulting: readOnly }, 'edit: the held grant, then the edited one');
    await clickButton(page, '[role="dialog"]', STRINGS.actionConfirm);
    await waitForDialogClosed(page);
    await expectListed(page, [readOnly]);

    await clickButton(page, '.ocu-role-grant', STRINGS.actionRemove);
    await page.waitForSelector('[role="dialog"] #ocu-role-grant-current', { visible: true, timeout: config.navigationTimeoutMs });
    await expectLines(page, { current: readOnly, resulting: STRINGS.roleGrantNone }, 'remove: the held grant, then none');
    await clickButton(page, '[role="dialog"]', STRINGS.actionConfirm);
    await waitForDialogClosed(page);
    await expectListed(page, []);
  } finally {
    await context.close();
  }
});

/** The text of the element `selector`, once it is drawn. */
async function textOf(page, selector) {
  await page.waitForSelector(selector, { visible: true, timeout: config.navigationTimeoutMs });
  return page.$eval(selector, (node) => node.textContent.trim());
}

// AC4, AD-10. Mutation (Rule 19): make the page's `privilegedRoleChecked` answer false -> the
// granted-role consequence leg goes red; make the dialog's `showEffect` answer false -> the dialog
// leg goes red; drop the `writeChanged` line from the dialog's `onLetter` -> the DW-1514 leg goes red;
// give the Resources fieldset its refusal alone as `aria-describedby` -> the description leg goes red.
test('AC4: a privileged choice is available, states its consequence, and a Save applies it', async () => {
  const { context, page } = await signedInAt(FORM_URL);
  try {
    await page.waitForSelector('#ocu-role-GrantedRoles', { visible: true, timeout: config.navigationTimeoutMs });
    const roles = await roleBoxes(page);
    for (const name of PRIVILEGED_ROLES) {
      const role = roles.find((entry) => entry.name === name);
      assert.ok(role, `the instance offers ${name}`);
      assert.equal(role.disabled, false, `${name} is available`);
    }
    assert.equal(await page.$(ROLES_EFFECT), null, 'no consequence before a privileged role is ticked');
    const all = roles.find((entry) => entry.name === '%All');
    await page.evaluate((id) => document.getElementById(id).click(), all.id);
    assert.equal(await textOf(page, ROLES_EFFECT), STRINGS.privilegedGrantEffect, 'ticking %All states the consequence');

    // DW-1514: Write on a database carries Read, locked, as the classic dialog does.
    await page.click('#ocu-role-grant-add');
    await page.waitForSelector('[role="dialog"] #ocu-role-grant-resource', { visible: true, timeout: config.navigationTimeoutMs });
    await page.select('#ocu-role-grant-resource', '%DB_IRISSECURITY');
    await page.waitForSelector('#ocu-role-grant-W', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('#ocu-role-grant-W', (node) => node.disabled), false, 'write on the security database is available');
    await page.click('#ocu-role-grant-W');
    await page.waitForFunction(() => document.getElementById('ocu-role-grant-R')?.disabled === true, { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('#ocu-role-grant-R', (node) => node.checked), true, 'and ticking it ticks Read');
    assert.equal(await page.$(DIALOG_EFFECT), null, 'which states no privilege consequence');

    await page.select('#ocu-role-grant-resource', '%Admin_Secure');
    await page.waitForSelector('#ocu-role-grant-U', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(
      await page.$eval('#ocu-role-grant-resource option[value="%Admin_Secure"]', (node) => node.disabled),
      false,
      'an administrative resource is available'
    );
    await page.click('#ocu-role-grant-U');
    assert.equal(await textOf(page, DIALOG_EFFECT), STRINGS.privilegedGrantEffect, 'and the dialog states its consequence');
    await clickButton(page, '[role="dialog"]', STRINGS.actionConfirm);
    await waitForDialogClosed(page);
    assert.equal(await textOf(page, RESOURCES_EFFECT), STRINGS.privilegedGrantEffect, 'as does the Resources field once it is held');
    const resourcesDescribedBy = await page.$eval('#ocu-role-Resources', (node) => node.getAttribute('aria-describedby') ?? '');
    assert.ok(resourcesDescribedBy.split(' ').includes(RESOURCES_EFFECT.slice(1)), 'which describes the Resources field');

    await fill(page, 'ocu-role-Name', NAMES[1]);
    await (await saveButton(page)).click();
    await page.waitForFunction(
      (sentence) => document.querySelector('.ocu-form-bar-status')?.textContent?.includes(sentence) === true,
      { timeout: config.navigationTimeoutMs },
      STRINGS.formSaved
    );
    const stored = storedRole(NAMES[1]);
    assert.ok(stored !== null, 'the Save creates the role');
    assert.deepEqual(stored.resources, ['%Admin_Secure:U'], 'with the administrative resource granted');
    assert.deepEqual(stored.grantedRoles, ['%All'], 'and %All granted');
  } finally {
    await context.close();
  }
});

// AC5. Mutation (Rule 19): drop the route replacement from `onSave` -> the URL leg goes red.
test('AC5: a valid Save creates the role with the sent grants, replaces the route, and the Roles list shows it', async () => {
  const { context, page } = await signedInAt(FORM_URL);
  try {
    await page.waitForSelector('#ocu-role-Name', { visible: true, timeout: config.navigationTimeoutMs });
    await fill(page, 'ocu-role-Name', NAMES[0]);
    await fill(page, 'ocu-role-Description', PROBE_DESCRIPTION);
    await addGrant(page, '%DB_USER', 'RW');
    await expectLines(page, { current: STRINGS.roleGrantNone, resulting: `%DB_USER: ${STRINGS.permissionRead}, ${STRINGS.permissionWrite}` }, 'the grant to be');
    await clickButton(page, '[role="dialog"]', STRINGS.actionConfirm);
    await waitForDialogClosed(page);
    const granted = (await roleBoxes(page)).find((entry) => entry.name === '%Developer');
    assert.ok(granted !== undefined, 'the instance offers %Developer');
    await page.evaluate((id) => document.getElementById(id).click(), granted.id);
    await (await saveButton(page)).click();

    await page.waitForFunction(
      (sentence) => document.querySelector('.ocu-form-bar-status')?.textContent?.includes(sentence) === true,
      { timeout: config.navigationTimeoutMs },
      STRINGS.formSaved
    );
    await page.waitForFunction(
      () => /\/permissions\/roles\/edit\/[^/]+$/.test(new URL(window.location.href).pathname),
      { timeout: config.navigationTimeoutMs }
    );
    const path = await page.evaluate(() => new URL(window.location.href).pathname);
    assert.ok(
      path.toLowerCase().endsWith(`/permissions/roles/edit/${NAMES[0].toLowerCase()}`),
      `the URL names the role: ${path}`
    );
    // Story 9.3: that URL is the role editor, which reads the role and opens showing "Saved".
    // Mutation (Rule 19): drop `arriveSaved` from `onSave` and redeploy -> the editor's Saved leg goes red.
    const editorHolds = (description) =>
      page.waitForFunction(
        (name, wanted) =>
          document.querySelector('#ocu-role-edit-Name')?.value?.toLowerCase() === name.toLowerCase() &&
          document.querySelector('#ocu-role-edit-Description')?.value === wanted,
        { timeout: config.navigationTimeoutMs },
        NAMES[0],
        description
      );
    await editorHolds(PROBE_DESCRIPTION);
    assert.equal(
      await page.$eval('.ocu-form-bar-status', (node) => node.textContent.trim()),
      STRINGS.formSaved,
      'the role editor opens reading Saved'
    );
    await page.reload({ waitUntil: 'networkidle2' });
    await leaveFirstLoginGate(page, config.navigationTimeoutMs, path);
    await editorHolds(PROBE_DESCRIPTION);

    const stored = storedRole(NAMES[0]);
    assert.ok(stored !== null, 'the instance holds the role the form created');
    assert.equal(stored.description, PROBE_DESCRIPTION, 'with the description sent');
    assert.deepEqual(stored.resources, ['%DB_USER:RW'], 'the grant sent');
    assert.deepEqual(stored.grantedRoles, ['%Developer'], 'and the granted role sent');

    await page.goto(`${config.origin}${LIST_URL}`, { waitUntil: 'networkidle2' });
    await leaveFirstLoginGate(page, config.navigationTimeoutMs, LIST_URL);
    await waitForRows(page, config.navigationTimeoutMs);
    // The list holds more roles than it renders at once, so it is filtered to the new one.
    const total = await viewCount(page);
    const kept = await filterToSubset(page, { text: NAMES[0], expectRow: NAMES[0], total, timeoutMs: config.navigationTimeoutMs });
    assert.ok(kept > 0, 'the role the form created is in the Roles list');
  } finally {
    await context.close();
  }
});

// AC1's entry point. Mutation (Rule 19): drop the `RoleActions` injection from `app.ts` -> the
// command bar offers no Create on the Roles list and this goes red.
test('AC1: the Roles list offers Create, and it opens the create form', async () => {
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
      () => new URL(window.location.href).pathname.endsWith('/permissions/roles/edit'),
      { timeout: config.navigationTimeoutMs }
    );
    await page.waitForSelector('#ocu-role-Name', { visible: true, timeout: config.navigationTimeoutMs });
  } finally {
    await context.close();
  }
});

/**
 * The role editor in a real browser, against the throwaway instance (Story 9.3).
 *
 * What it pins, each on rendered DOM, on the real URL or on the instance itself:
 *
 * 1. **A row's name opens the editor** at `permissions/roles/edit/<id>`, on General, Members and
 *    Assigned to.
 * 2. **A two-field Save reaches the instance and leaves the grants as they were**, and the Roles list
 *    shows the new description without a page load.
 * 3. **A grant added and edited in the dialog** shows the current and the resulting grant, and each
 *    reaches the instance as a delta.
 * 4. **Assigned to's Assign and Remove, and Members' Assign user and Remove**, reach the instance.
 * 5. **A refusal on General while Members is open** opens General with its dot and count.
 * 6. **A changed editor asks before it is left.**
 * 7. **The Roles list's Delete** states how many accounts hold the role, deletes it once the name is
 *    typed, and the list re-reads; a predefined role's Delete is drawn refused.
 * 8. **The visual gate** (DW-1337): every control is named, none is narrower than its minimum,
 *    nothing overflows, and the form bar is flush at the bottom of the content area.
 *
 * **It creates and deletes roles and accounts**, so it refuses the live container. Every principal it
 * makes is named below and removed by that exact name inside the throwaway, before and after.
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
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre } from './list-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const LIST_URL = '/ocupilot/permissions/roles?ns=HSCUSTOM';

/** The role every editor leg opens, the role it is assigned to, the one its Delete leg removes, and two holders. */
const PROBE = 'OcuPilotProbeRoleEditor';
const OUTER = 'OcuPilotProbeRoleEditorOuter';
const DOOMED = 'OcuPilotProbeRoleEditorDelete';
const HOLDERS = ['OcuPilotProbeRoleEditorA', 'OcuPilotProbeRoleEditorB'];
const MARKER = 'OcuPilot roles-editor browser spec probe (throwaway)';
const PASSWORD = 'OcuPilotRoleEditor9Aa';
const EDIT_URL = `/ocupilot/permissions/roles/edit/${PROBE}?ns=HSCUSTOM`;

let browser = null;

const mark = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/** Run ObjectScript in `%SYS` inside the throwaway and read back the named markers. */
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
    values[name] = found === null ? null : found[1];
  }
  return { values, output };
}

/** Remove every probe principal by its exact name, and only where it carries this spec's marker. */
function removeLines() {
  const users = HOLDERS.map(
    (name) => `If ##class(Security.Users).Exists("${name}") { Kill tP Do ##class(Security.Users).Get("${name}",.tP) If $Get(tP("Comment"))="${MARKER}" Do ##class(Security.Users).Delete("${name}") }`
  );
  const roles = [OUTER, DOOMED, PROBE].map(
    (name) => `If ##class(Security.Roles).Exists("${name}") { Kill tP Do ##class(Security.Roles).Get("${name}",.tP) If $Get(tP("Description"))="${MARKER}"!($Extract($Get(tP("Description")),1,${MARKER.length})="${MARKER}") Do ##class(Security.Roles).Delete("${name}") }`
  );
  return [...users, ...roles];
}

/** Make every probe principal afresh: the probe role, the role to assign, the doomed role and its two holders. */
function createProbes() {
  return irisSys(
    [
      ...removeLines(),
      `Set tSC=##class(Security.Roles).Create("${PROBE}","${MARKER}","%Development:U","%Developer")`,
      `If $System.Status.IsOK(tSC) Set tSC=##class(Security.Roles).Create("${OUTER}","${MARKER}","","")`,
      `If $System.Status.IsOK(tSC) Set tSC=##class(Security.Roles).Create("${DOOMED}","${MARKER}","","")`,
      ...HOLDERS.map((name) => `If $System.Status.IsOK(tSC) Set tSC=##class(Security.Users).Create("${name}","${DOOMED}","${PASSWORD}","Probe","","","",0,1,"${MARKER}")`),
      mark('MADE', '$System.Status.IsOK(tSC)'),
    ],
    ['MADE']
  );
}

/** One property of role `name` as the instance holds it; `gone` when it is not there. */
function roleField(name, field) {
  const { values } = irisSys(
    [`Kill tP Set tThere=##class(Security.Roles).Exists("${name}") If tThere Do ##class(Security.Roles).Get("${name}",.tP)`, mark('FIELD', `$Select(tThere: $Get(tP("${field}")), 1: "gone")`)],
    ['FIELD']
  );
  return values.FIELD;
}

/** The roles account `name` holds, as the instance holds them. */
function userRoles(name) {
  const { values } = irisSys([`Kill tP Do ##class(Security.Users).Get("${name}",.tP)`, mark('ROLES', '$Get(tP("Roles"))')], ['ROLES']);
  return values.ROLES;
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates and deletes roles and accounts, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  const { values, output } = createProbes();
  assert.equal(values.MADE, '1', `the probe principals were created:\n${output}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  const { values, output } = irisSys([...removeLines(), mark('CLEAN', `('##class(Security.Roles).Exists("${PROBE}"))&&('##class(Security.Roles).Exists("${DOOMED}"))`)], ['CLEAN']);
  assert.equal(values.CLEAN, '1', `the probe principals are gone:\n${output}`);
});

/** A fresh context signed in through the shell's own form, landed at `url`. */
async function signedInAt(url) {
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  await page.goto(`${config.origin}${url}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', config.username);
  await page.type('#ocu-signin-password', config.password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, url);
  return { context, page };
}

/** Wait until the editor holds the probe role's read. */
async function editorReady(page, name = PROBE) {
  await page.waitForFunction(
    (wanted) => document.querySelector('#ocu-role-edit-Name')?.value === wanted && document.querySelector('#ocu-role-edit-Description')?.readOnly === false,
    { timeout: config.navigationTimeoutMs },
    name
  );
}

/** Replace control `id`'s text with `value`. */
async function fill(page, id, value) {
  await page.click(`#${id}`, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(`#${id}`, value);
}

/** The tab strip: each tab's label, accessible name, selection and dot. */
function tabState(page) {
  return page.$$eval('app-form-tabs [role="tab"]', (tabs) =>
    tabs.map((tab) => ({
      label: tab.querySelector('.ocu-form-tab-label')?.textContent.trim() ?? '',
      name: tab.getAttribute('aria-label'),
      selected: tab.getAttribute('aria-selected') === 'true',
      dot: tab.querySelector('.ocu-form-tab-dot') !== null,
    }))
  );
}

async function openTab(page, label) {
  await page.evaluate((wanted) => {
    const tabs = Array.from(document.querySelectorAll('app-form-tabs [role="tab"]'));
    tabs.find((tab) => tab.querySelector('.ocu-form-tab-label')?.textContent.trim() === wanted).click();
  }, label);
  await page.waitForFunction(
    (wanted) =>
      Array.from(document.querySelectorAll('app-form-tabs [role="tab"]')).some(
        (tab) => tab.getAttribute('aria-selected') === 'true' && tab.querySelector('.ocu-form-tab-label')?.textContent.trim() === wanted
      ),
    { timeout: config.navigationTimeoutMs },
    label
  );
}

/** Click the visible button inside `scope` whose text is `label`. */
async function clickButton(page, scope, label) {
  const clicked = await page.$$eval(
    `${scope} button`,
    (buttons, wanted) => {
      const button = buttons.find((candidate) => candidate.offsetParent !== null && candidate.textContent.trim() === wanted);
      if (button === undefined) return false;
      button.click();
      return true;
    },
    label
  );
  assert.ok(clicked, `${scope} offers ${label}`);
}

/** Wait until `selector`'s visible texts are exactly `expected`. */
async function expectTexts(page, selector, expected, message) {
  await page
    .waitForFunction(
      (css, wanted) => JSON.stringify(Array.from(document.querySelectorAll(css)).filter((node) => node.offsetParent !== null).map((node) => node.textContent.trim())) === wanted,
      { timeout: config.navigationTimeoutMs },
      selector,
      JSON.stringify(expected)
    )
    .catch(() => undefined);
  const actual = await page.$$eval(selector, (nodes) => nodes.filter((node) => node.offsetParent !== null).map((node) => node.textContent.trim()));
  assert.deepEqual(actual, expected, message);
}

/** Narrow the list to `name` and wait until a row whose first cell reads it is rendered. */
async function filterTo(page, name) {
  await page.waitForSelector(FILTER_SELECTOR, { visible: true, timeout: config.navigationTimeoutMs });
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, name);
  await page.waitForFunction(
    (selector, wanted) =>
      Array.from(document.querySelectorAll(selector)).some((row) => row.querySelector('[role="gridcell"]')?.textContent?.trim() === wanted),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name
  );
}

/** A comma-separated list as the instance stores it, sorted, so order is not asserted. */
function sorted(list) {
  return (list ?? '').split(',').filter((entry) => entry !== '').sort().join(',');
}

async function save(page) {
  await page.click('.ocu-form-bar .ocu-button-primary');
}

test('a row\u2019s name opens the editor on General, Members and Assigned to', async () => {
  // Mutation (Rule 19): put RoleForm back in `CREATE_ONLY_FORMS` and redeploy -> the name cell opens
  // no editor and the URL wait goes red.
  const { context, page } = await signedInAt(LIST_URL);
  try {
    await filterTo(page, PROBE);
    await page.evaluate((name) => {
      const links = Array.from(document.querySelectorAll('[role="grid"] .ocu-data-table-body .ocu-data-table-link'));
      links.find((link) => link.textContent.trim() === name).click();
    }, PROBE);
    await page.waitForFunction(
      (name) => new URL(window.location.href).pathname.toLowerCase().endsWith(`/permissions/roles/edit/${name.toLowerCase()}`),
      { timeout: config.navigationTimeoutMs },
      PROBE
    );
    await editorReady(page);
    const tabs = await tabState(page);
    assert.deepEqual(tabs.map((tab) => tab.label), [STRINGS.processDetailsGroupGeneral, STRINGS.roleEditorTabMembers, STRINGS.roleEditorTabAssignedTo]);
    assert.equal(tabs[0].selected, true, 'General is open first');
    assert.equal(await page.$eval('#ocu-role-edit-Description', (node) => node.value), MARKER, 'with the role as the instance holds it');
  } finally {
    await context.close();
  }
});

test('a two-field Save reaches the instance, the grants survive, and the list shows the description without a reload', async () => {
  createProbes();
  const { context, page } = await signedInAt(EDIT_URL);
  try {
    await editorReady(page);
    await fill(page, 'ocu-role-edit-Description', `${MARKER} saved`);
    await page.click('#ocu-role-edit-EscalationOnly');
    await save(page);
    await page.waitForFunction(
      (sentence) => document.querySelector('.ocu-form-bar-status')?.textContent?.includes(sentence) === true,
      { timeout: config.navigationTimeoutMs },
      STRINGS.formSaved
    );
    assert.equal(roleField(PROBE, 'Description'), `${MARKER} saved`, 'the description reached the instance');
    assert.equal(roleField(PROBE, 'EscalationOnly'), '1', 'and so did the escalation flag');
    assert.equal(roleField(PROBE, 'Resources'), '%Development:U', 'the grants survived');
    assert.equal(roleField(PROBE, 'GrantedRoles'), '%Developer', 'and the granted roles');

    await page.click('.ocu-form-bar-actions .ocu-button-text');
    await page.waitForFunction(() => new URL(window.location.href).pathname.endsWith('/permissions/roles'), { timeout: config.navigationTimeoutMs });
    await filterTo(page, PROBE);
    const row = await page.$$eval(ROW_SELECTOR, (nodes, name) => nodes.find((node) => node.querySelector('[role="gridcell"]')?.textContent?.trim() === name)?.textContent ?? '', PROBE);
    assert.ok(row.includes(`${MARKER} saved`), `the list shows the saved description: ${row}`);
  } finally {
    await context.close();
  }
});

// AC2. Mutation (Rule 19): pass [] as the dialog's `granted` and redeploy -> the edit's current line
// reads "No grant" and this goes red.
test('AC2: a grant added and edited in the dialog shows the current and resulting grant, and each reaches the instance', async () => {
  createProbes();
  const { context, page } = await signedInAt(EDIT_URL);
  try {
    await editorReady(page);
    const readWrite = `%DB_USER: ${STRINGS.permissionRead}, ${STRINGS.permissionWrite}`;
    const readOnly = `%DB_USER: ${STRINGS.permissionRead}`;
    await page.click('#ocu-role-edit-grant-add');
    await page.waitForSelector('[role="dialog"] #ocu-role-grant-resource', { visible: true, timeout: config.navigationTimeoutMs });
    await page.select('#ocu-role-grant-resource', '%DB_USER');
    await page.click('#ocu-role-grant-R');
    await page.click('#ocu-role-grant-W');
    await expectTexts(page, '#ocu-role-grant-current, #ocu-role-grant-resulting', [STRINGS.roleGrantNone, readWrite], 'add: nothing held, the grant to be');
    await clickButton(page, '[role="dialog"]', STRINGS.actionConfirm);
    await expectTexts(page, '.ocu-role-grant-line', [readWrite, `%Development: ${STRINGS.permissionUse}`].sort(), 'the grant is listed from the instance\u2019s own read');
    assert.equal(sorted(roleField(PROBE, 'Resources')), '%DB_USER:RW,%Development:U', 'and the instance holds it beside the other');

    await page.evaluate(() => {
      const row = Array.from(document.querySelectorAll('.ocu-role-grant')).find((node) => node.textContent.includes('%DB_USER'));
      row.querySelector('button').click();
    });
    await page.waitForSelector('[role="dialog"] #ocu-role-grant-W', { visible: true, timeout: config.navigationTimeoutMs });
    await page.click('#ocu-role-grant-W');
    await expectTexts(page, '#ocu-role-grant-current, #ocu-role-grant-resulting', [readWrite, readOnly], 'edit: the held grant, then the edited one');
    await clickButton(page, '[role="dialog"]', STRINGS.actionConfirm);
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await expectTexts(page, '.ocu-role-grant-line', [readOnly, `%Development: ${STRINGS.permissionUse}`].sort(), 'the edited grant is listed');
    assert.equal(sorted(roleField(PROBE, 'Resources')), '%DB_USER:R,%Development:U', 'and the instance holds Read alone');
  } finally {
    await context.close();
  }
});

test('Assigned to\u2019s Assign and Remove, and Members\u2019 Assign user and Remove, reach the instance', async () => {
  createProbes();
  const { context, page } = await signedInAt(EDIT_URL);
  try {
    await editorReady(page);
    await openTab(page, STRINGS.roleEditorTabAssignedTo);
    await page.select('#ocu-role-edit-granted-role', OUTER);
    await page.click('[data-action="add-granted-role"]');
    await page.waitForFunction(
      (label, name) => Array.from(document.querySelectorAll(`[aria-label="${label}"] .ocu-form-role-name`)).some((node) => node.textContent.trim() === name),
      { timeout: config.navigationTimeoutMs },
      STRINGS.roleEditorTabAssignedTo,
      OUTER
    );
    assert.equal(sorted(roleField(PROBE, 'GrantedRoles')), sorted(`%Developer,${OUTER}`), 'the assigned role is listed, and the instance holds it');
    await page.evaluate((label) => {
      const buttons = Array.from(document.querySelectorAll(`[aria-label="${label}"] .ocu-form-role button`));
      buttons.find((button) => button.getAttribute('aria-label')?.endsWith('%Developer')).click();
    }, STRINGS.roleEditorTabAssignedTo);
    await expectTexts(page, `[aria-label="${STRINGS.roleEditorTabAssignedTo}"] .ocu-form-role-name`, [OUTER], 'the removed role is gone');
    assert.equal(roleField(PROBE, 'GrantedRoles'), OUTER, 'from the instance too');

    await openTab(page, STRINGS.roleEditorTabMembers);
    await page.type('#ocu-role-edit-member-user', HOLDERS[0]);
    await page.click('[data-action="assign-user"]');
    await page.waitForFunction(
      (label, name) => Array.from(document.querySelectorAll(`[aria-label="${label}"] .ocu-form-role-name`)).some((node) => node.textContent.trim() === name),
      { timeout: config.navigationTimeoutMs },
      STRINGS.roleEditorTabMembers,
      HOLDERS[0]
    );
    assert.ok(userRoles(HOLDERS[0]).split(',').includes(PROBE), 'the account holds the role');
    await page.evaluate((label, name) => {
      const rows = Array.from(document.querySelectorAll(`[aria-label="${label}"] .ocu-form-role`));
      rows.find((row) => row.querySelector('.ocu-form-role-name').textContent.trim() === name).querySelector('button').click();
    }, STRINGS.roleEditorTabMembers, HOLDERS[0]);
    await page.waitForFunction(
      (label, name) => !Array.from(document.querySelectorAll(`[aria-label="${label}"] .ocu-form-role-name`)).some((node) => node.textContent.trim() === name),
      { timeout: config.navigationTimeoutMs },
      STRINGS.roleEditorTabMembers,
      HOLDERS[0]
    );
    assert.ok(!userRoles(HOLDERS[0]).split(',').includes(PROBE), 'and no longer does once removed');
  } finally {
    await context.close();
  }
});

// Integration. Mutation (Rule 19): skip `tabToOpen` in the page's `afterRefusal` and redeploy -> the
// selected-tab assertion goes red.
test('a refusal on General while Members is open opens General, with its dot and count, and focuses the field', async () => {
  createProbes();
  const { context, page } = await signedInAt(EDIT_URL);
  try {
    await editorReady(page);
    // The field's maxlength stops typing past the stored length, so the over-long value is set as a
    // paste would leave it and the server's rule is what refuses it.
    await page.evaluate(() => {
      const input = document.getElementById('ocu-role-edit-Description');
      input.value = 'x'.repeat(300);
      input.dispatchEvent(new Event('input', { bubbles: true }));
    });
    await openTab(page, STRINGS.roleEditorTabMembers);
    await save(page);
    await page.waitForSelector('.ocu-form-summary', { visible: true, timeout: config.navigationTimeoutMs });
    await page.waitForFunction(() => document.activeElement?.id === 'ocu-role-edit-Description', { timeout: config.navigationTimeoutMs });
    const tabs = await tabState(page);
    assert.equal(tabs[0].selected, true, 'General opened');
    assert.equal(tabs[0].dot, true, 'with the destructive dot');
    assert.equal(tabs[0].name, `${STRINGS.processDetailsGroupGeneral}, 1 error`, 'and its count in its accessible name');
    assert.equal(tabs[1].dot, false, 'Members carries none');
    assert.equal(roleField(PROBE, 'Description'), MARKER, 'and nothing reached the instance');
  } finally {
    await context.close();
  }
});

test('a changed editor asks before it is left, and staying keeps the edit', async () => {
  const { context, page } = await signedInAt(EDIT_URL);
  try {
    await editorReady(page);
    await fill(page, 'ocu-role-edit-Description', 'unsaved');
    await page.click('.ocu-form-bar-actions .ocu-button-text');
    await page.waitForSelector('[role="dialog"] .ocu-dialog-title', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[role="dialog"] .ocu-dialog-title', (node) => node.textContent.trim()), STRINGS.formLeaveWithoutSaving);
    await (await page.$('[role="dialog"] .ocu-dialog-actions button')).click();
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    assert.ok(new URL(page.url()).pathname.endsWith(`/permissions/roles/edit/${PROBE}`), 'the editor is still open');
    assert.equal(await page.$eval('#ocu-role-edit-Description', (node) => node.value), 'unsaved', 'with the edit');
  } finally {
    await context.close();
  }
});

// AC3, DW-1513. Mutation (Rule 19): drop the advisory from the handler's role delete and redeploy ->
// the holder-line assertion goes red; clear the `system-role` rule -> the %Developer leg goes red.
test('AC3: the Roles list\u2019s Delete states the holders, deletes the role once typed, and the list re-reads; %Developer is drawn refused', async () => {
  createProbes();
  const { context, page } = await signedInAt(LIST_URL);
  try {
    await filterTo(page, DOOMED);
    await clickRowCentre(page, { text: DOOMED, cell: 2 });
    await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
    await page.waitForSelector('[role="menu"]', { timeout: config.navigationTimeoutMs });
    await page.evaluate((label) => {
      const items = Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'));
      items.find((item) => item.textContent.trim().startsWith(label)).click();
    }, STRINGS.actionDelete);
    await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-typed-name-consequence', (node) => node.textContent.trim()), STRINGS.roleDeleteConsequence);
    assert.equal(
      await page.$eval('[data-slot="advisory"] .ocu-banner-message', (node) => node.textContent.trim()),
      '2 users hold this role.',
      'the dialog states how many accounts hold the role'
    );
    await page.type('.ocu-typed-name-field', DOOMED);
    await page.keyboard.press('Enter');
    await page.waitForFunction(
      (selector, name) => !Array.from(document.querySelectorAll(selector)).some((row) => row.querySelector('[role="gridcell"]')?.textContent?.trim() === name),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      DOOMED
    );
    assert.equal(roleField(DOOMED, 'Description'), 'gone', 'the instance no longer holds the role');

    await filterTo(page, '%Developer');
    await clickRowCentre(page, { text: '%Developer', cell: 2 });
    await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
    await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
    const entry = await page.$eval('[role="menu"] [role="menuitem"]', (node) => ({
      disabled: node.getAttribute('aria-disabled'),
      reason: node.querySelector('.ocu-data-table-menu-reason')?.textContent.trim() ?? '',
    }));
    assert.deepEqual(entry, { disabled: 'true', reason: STRINGS.roleRefusalSystem }, 'a predefined role\u2019s Delete is drawn refused');
  } finally {
    await context.close();
  }
});

test('the visual gate: every control is named, none is narrower than its minimum, nothing overflows, and the bar is flush', async () => {
  createProbes();
  const { context, page } = await signedInAt(EDIT_URL);
  try {
    await page.setViewport({ width: 1440, height: 900 });
    await editorReady(page);
    for (const label of [STRINGS.processDetailsGroupGeneral, STRINGS.roleEditorTabMembers, STRINGS.roleEditorTabAssignedTo]) {
      await openTab(page, label);
      const report = await page.evaluate(() => {
        const nameOf = (node) => {
          const labelled = node.getAttribute('aria-labelledby');
          if (labelled) return labelled.split(' ').map((id) => document.getElementById(id)?.textContent.trim() ?? '').join(' ').trim();
          if (node.getAttribute('aria-label')) return node.getAttribute('aria-label').trim();
          if (node.labels && node.labels.length > 0) return Array.from(node.labels).map((label) => label.textContent.trim()).join(' ');
          return node.textContent.trim();
        };
        const root = document.querySelector('app-role-editor-page');
        const controls = Array.from(root.querySelectorAll('input, select, button, [role="tab"]')).filter((node) => node.offsetParent !== null);
        const unnamed = controls.filter((node) => nameOf(node) === '').map((node) => node.outerHTML.slice(0, 120));
        const narrow = controls
          .filter((node) => {
            const min = parseFloat(getComputedStyle(node).minWidth);
            return Number.isFinite(min) && node.getBoundingClientRect().width + 0.5 < min;
          })
          .map((node) => node.outerHTML.slice(0, 120));
        const overflowing = Array.from(root.querySelectorAll('*'))
          .filter((node) => node.offsetParent !== null && node.parentElement !== null)
          .filter((node) => {
            const own = node.getBoundingClientRect();
            const parent = node.parentElement.getBoundingClientRect();
            const style = getComputedStyle(node.parentElement);
            if (style.overflowX !== 'visible') return false;
            return own.width > 0 && own.right > parent.right + 1;
          })
          .map((node) => node.outerHTML.slice(0, 120));
        const content = document.querySelector('.ocu-content');
        const bar = document.querySelector('.ocu-form-bar');
        return {
          controls: controls.length,
          unnamed,
          narrow,
          overflowing,
          pageOverflow: document.documentElement.scrollWidth > document.documentElement.clientWidth,
          contentBottom: content === null ? null : content.getBoundingClientRect().bottom,
          contentScrolled: content === null ? null : content.scrollTop,
          barBottom: bar === null ? null : bar.getBoundingClientRect().bottom,
        };
      });
      assert.ok(report.controls > 3, `${label}: the gate looked at the editor's controls: ${report.controls}`);
      assert.deepEqual(report.unnamed, [], `${label}: every control has an accessible name`);
      assert.deepEqual(report.narrow, [], `${label}: none is narrower than its declared minimum`);
      assert.deepEqual(report.overflowing, [], `${label}: nothing overflows its container`);
      assert.equal(report.pageOverflow, false, `${label}: and the page does not scroll sideways`);
      assert.equal(report.contentScrolled, 0, `${label}: nothing was scrolled to reach the bar`);
      assert.ok(report.barBottom !== null && Math.abs(report.barBottom - report.contentBottom) <= 1, `${label}: the bar is flush at the bottom of the content area: ${JSON.stringify(report)}`);
    }
  } finally {
    await context.close();
  }
});

/**
 * The user editor in a real browser, against the throwaway instance (Story 9.1).
 *
 * What it pins, each on rendered DOM, on the real URL or on the instance itself:
 *
 * 1. **A row's name opens the editor** at `permissions/users/edit/<id>`, on the General and Roles
 *    tabs.
 * 2. **A two-field Save reaches the instance and leaves every other setting as it was**, and the
 *    route stays open reading "Saved".
 * 3. **A refusal on the General tab while Roles is open** switches to General, whose tab carries the
 *    destructive dot and "General, 1 error", and focuses the refused field.
 * 4. **A changed form asks before it is left.**
 * 5. **The editor's own Set password and Add role** are the Users list's actions: the password lands
 *    on the account, and a privileged role states its consequence in the list's own dialog.
 * 6. **Delete** returns to the list, and the account is gone.
 * 7. **The visual gate** (DW-1337): every control on the editor has an accessible name, none is
 *    narrower than its declared minimum, and nothing overflows its container.
 * 8. **The change-toast stack stands clear above the form bar**, so a toast never covers Save or
 *    Cancel.
 *
 * **It creates and deletes a user account**, so it refuses the live container. `before` makes the
 * probe account by exact name and `after` removes it whether or not a test failed.
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
import { FILTER_SELECTOR, ROW_SELECTOR, waitForRows } from './list-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const LIST_URL = '/ocupilot/permissions/users?ns=HSCUSTOM';

/** This spec's own account, never one the instance had, and the password it starts with. */
const PROBE = 'OcuPilotProbeUserEditor';
const PROBE_PASSWORD = 'OcuPilotEditorStart9Aa';
const PROBE_MARKER = 'OcuPilot users-editor browser spec probe (throwaway)';
const EDIT_URL = `/ocupilot/permissions/users/edit/${PROBE}?ns=HSCUSTOM`;

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

/** Remove the probe account by its exact name, and only where it carries this spec's marker. */
const REMOVE = `If ##class(Security.Users).Exists("${PROBE}") { Kill tP Do ##class(Security.Users).Get("${PROBE}",.tP) If $Extract($Get(tP("Comment")),1,${PROBE_MARKER.length})="${PROBE_MARKER}" Do ##class(Security.Users).Delete("${PROBE}") }`;

function createProbe() {
  return irisSys(
    [
      REMOVE,
      `Set tSC=##class(Security.Users).Create("${PROBE}","%SQL","${PROBE_PASSWORD}","Probe Editor","","","",0,1,"${PROBE_MARKER}")`,
      `Kill tQ Set tQ("EmailAddress")="probe@example.invalid",tQ("PhoneNumber")="5550100",tQ("PasswordNeverExpires")=1,tQ("ExpirationDate")="2099-12-31"`,
      'If $System.Status.IsOK(tSC) Set tSC=##class(Security.Users).Modify("' + PROBE + '",.tQ)',
      mark('MADE', '$System.Status.IsOK(tSC)'),
    ],
    ['MADE']
  );
}

/** One property of the probe account as the instance holds it; `gone` when it is not there. */
function probeField(field) {
  const { values } = irisSys(
    [
      `Kill tP Set tThere=##class(Security.Users).Exists("${PROBE}") If tThere Do ##class(Security.Users).Get("${PROBE}",.tP)`,
      mark('FIELD', `$Select(tThere: $Get(tP("${field}")), 1: "gone")`),
    ],
    ['FIELD']
  );
  return values.FIELD;
}

/** The login route's status for the probe account with `password`. */
async function loginStatus(password) {
  const response = await fetch(`${config.origin}/api/ocupilot/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ user: PROBE, password }),
  });
  return response.status;
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates and deletes a user account, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  const { values, output } = createProbe();
  assert.equal(values.MADE, '1', `the probe account was created:\n${output}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  const { values, output } = irisSys([REMOVE, mark('CLEAN', `('##class(Security.Users).Exists("${PROBE}"))`)], ['CLEAN']);
  assert.equal(values.CLEAN, '1', `the probe account is gone:\n${output}`);
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

/** Wait until the editor holds the probe account's read. */
async function editorReady(page) {
  await page.waitForFunction(
    (name) => document.querySelector('#ocu-user-edit-Name')?.value === name && document.querySelector('#ocu-user-edit-FullName')?.readOnly === false,
    { timeout: config.navigationTimeoutMs },
    PROBE
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

async function save(page) {
  await page.click('.ocu-form-bar .ocu-button-primary');
}

test('a row\u2019s name opens the editor on the General and Roles tabs', async () => {
  // Mutation (Rule 19): put UserForm back in `CREATE_ONLY_FORMS` and redeploy -> the name cell opens
  // no editor and the URL wait goes red.
  const { context, page } = await signedInAt(LIST_URL);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await page.type(FILTER_SELECTOR, PROBE);
    await page.waitForFunction(
      (selector, name) => Array.from(document.querySelectorAll(selector)).some((row) => row.textContent.includes(name)),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      PROBE
    );
    await page.evaluate((name) => {
      const links = Array.from(document.querySelectorAll('[role="grid"] .ocu-data-table-body .ocu-data-table-link'));
      links.find((link) => link.textContent.trim() === name).click();
    }, PROBE);
    await page.waitForFunction(
      (name) => new URL(window.location.href).pathname.toLowerCase().endsWith(`/permissions/users/edit/${name.toLowerCase()}`),
      { timeout: config.navigationTimeoutMs },
      PROBE
    );
    await editorReady(page);
    const tabs = await tabState(page);
    assert.deepEqual(tabs.map((tab) => tab.label), [STRINGS.processDetailsGroupGeneral, STRINGS.userColumnRoles]);
    assert.equal(tabs[0].selected, true, 'General is open first');
  } finally {
    await context.close();
  }
});

test('a two-field Save reaches the instance, every other setting survives, and the route stays open reading Saved', async () => {
  const { context, page } = await signedInAt(EDIT_URL);
  try {
    await editorReady(page);
    await fill(page, 'ocu-user-edit-FullName', 'Probe Editor Saved');
    await fill(page, 'ocu-user-edit-Comment', `${PROBE_MARKER} saved`);
    await save(page);
    await page.waitForFunction(
      (sentence) => document.querySelector('.ocu-form-bar-status')?.textContent?.includes(sentence) === true,
      { timeout: config.navigationTimeoutMs },
      STRINGS.formSaved
    );
    assert.ok(new URL(page.url()).pathname.endsWith(`/permissions/users/edit/${PROBE}`), 'the route stays open');
    assert.equal(probeField('FullName'), 'Probe Editor Saved', 'the full name reached the instance');
    assert.equal(probeField('Comment'), `${PROBE_MARKER} saved`, 'and so did the comment');
    assert.equal(probeField('EmailAddress'), 'probe@example.invalid', 'the email survived');
    assert.equal(probeField('PhoneNumber'), '5550100', 'and the phone number');
    assert.equal(probeField('PasswordNeverExpires'), '1', 'and the password expiry');
    assert.equal(probeField('ExpirationDate'), '2099-12-31', 'and the account expiry');
    assert.equal(probeField('Roles'), '%SQL', 'and the roles');
  } finally {
    await context.close();
  }
});

test('a refusal on General while Roles is open opens General, with its dot and count, and focuses the field', async () => {
  // Mutation (Rule 19): skip `tabToOpen` in the page's `afterRefusal` and redeploy -> the
  // selected-tab assertion goes red.
  const { context, page } = await signedInAt(EDIT_URL);
  try {
    await editorReady(page);
    await fill(page, 'ocu-user-edit-NameSpace', 'OCUPILOTNOSUCHNAMESPACE');
    await openTab(page, STRINGS.userColumnRoles);
    await save(page);
    await page.waitForSelector('.ocu-form-summary', { visible: true, timeout: config.navigationTimeoutMs });
    await page.waitForFunction(() => document.activeElement?.id === 'ocu-user-edit-NameSpace', { timeout: config.navigationTimeoutMs });
    const tabs = await tabState(page);
    assert.equal(tabs[0].selected, true, 'General opened');
    assert.equal(tabs[0].dot, true, 'with the destructive dot');
    assert.equal(tabs[0].name, `${STRINGS.processDetailsGroupGeneral}, 1 error`, 'and its count in its accessible name');
    assert.equal(tabs[1].dot, false, 'Roles carries none');
    const dot = await page.$eval('app-form-tabs .ocu-form-tab-dot', (node) => getComputedStyle(node).backgroundColor);
    assert.notEqual(dot, 'rgba(0, 0, 0, 0)', `the dot is painted: ${dot}`);
    assert.equal(probeField('NameSpace'), '', 'and nothing reached the instance');
  } finally {
    await context.close();
  }
});

test('a changed editor asks before it is left, and staying keeps the edit', async () => {
  const { context, page } = await signedInAt(EDIT_URL);
  try {
    await editorReady(page);
    await fill(page, 'ocu-user-edit-EmailAddress', 'unsaved@example.invalid');
    await page.click('.ocu-form-bar-actions .ocu-button-text');
    await page.waitForSelector('[role="dialog"] .ocu-dialog-title', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[role="dialog"] .ocu-dialog-title', (node) => node.textContent.trim()), STRINGS.formLeaveWithoutSaving);
    await (await page.$('[role="dialog"] .ocu-dialog-actions button')).click();
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    assert.ok(new URL(page.url()).pathname.endsWith(`/permissions/users/edit/${PROBE}`), 'the editor is still open');
    assert.equal(await page.$eval('#ocu-user-edit-EmailAddress', (node) => node.value), 'unsaved@example.invalid', 'with the edit');
  } finally {
    await context.close();
  }
});

test('the editor\u2019s Set password and Add role are the list\u2019s own actions, a privileged role stating its consequence', async () => {
  // Mutation (Rule 19): drop the `[privileged]` binding from `app-screen-action-dialogs` and
  // redeploy -> the consequence assertion goes red.
  const { context, page } = await signedInAt(EDIT_URL);
  try {
    await editorReady(page);
    const password = 'OcuPilotEditorNew9Bb';
    await page.click('[data-action="set-password"]');
    await page.waitForSelector('[role="dialog"] input[autocomplete="new-password"]', { visible: true, timeout: config.navigationTimeoutMs });
    await page.type('[role="dialog"] input[autocomplete="new-password"]', password);
    await page.click('[role="dialog"] .ocu-button-primary');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await page.waitForNetworkIdle({ idleTime: 500, timeout: config.navigationTimeoutMs });
    assert.equal(await loginStatus(password), 200, 'the account signs in with the password set from the editor');

    await openTab(page, STRINGS.userColumnRoles);
    await page.click('[data-action="add-role"]');
    await page.waitForSelector('[role="dialog"] select', { visible: true, timeout: config.navigationTimeoutMs });
    const effectOf = () =>
      page.evaluate(() => {
        const id = document.querySelector('[role="dialog"] select').getAttribute('aria-describedby');
        return id === null ? null : (document.getElementById(id)?.textContent.trim() ?? '');
      });
    await page.select('[role="dialog"] select', '%Manager');
    assert.equal(await effectOf(), STRINGS.privilegedGrantEffect, 'a privileged role states its consequence');
    await page.select('[role="dialog"] select', '%Developer');
    assert.equal(await effectOf(), null, 'an ordinary one states none');
    await page.click('[role="dialog"] .ocu-button-primary');
    await page.waitForFunction(
      () => Array.from(document.querySelectorAll('.ocu-form-role-name')).some((node) => node.textContent.trim() === '%Developer'),
      { timeout: config.navigationTimeoutMs }
    );
    assert.ok(probeField('Roles').includes('%Developer'), 'the instance holds the added role');
    assert.ok(probeField('Roles').includes('%SQL'), 'and the one it had');
  } finally {
    await context.close();
  }
});

test('the visual gate: every control is named, none is narrower than its minimum, nothing overflows', async () => {
  const { context, page } = await signedInAt(EDIT_URL);
  try {
    await editorReady(page);
    for (const label of [STRINGS.processDetailsGroupGeneral, STRINGS.userColumnRoles]) {
      await openTab(page, label);
      const report = await page.evaluate(() => {
        const nameOf = (node) => {
          const labelled = node.getAttribute('aria-labelledby');
          if (labelled) return labelled.split(' ').map((id) => document.getElementById(id)?.textContent.trim() ?? '').join(' ').trim();
          if (node.getAttribute('aria-label')) return node.getAttribute('aria-label').trim();
          if (node.labels && node.labels.length > 0) return Array.from(node.labels).map((label) => label.textContent.trim()).join(' ');
          return node.textContent.trim();
        };
        const root = document.querySelector('app-user-editor-page');
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
        return {
          controls: controls.length,
          unnamed,
          narrow,
          overflowing,
          pageOverflow: document.documentElement.scrollWidth > document.documentElement.clientWidth,
        };
      });
      assert.ok(report.controls > 3, `${label}: the gate looked at the editor's controls: ${report.controls}`);
      assert.deepEqual(report.unnamed, [], `${label}: every control has an accessible name`);
      assert.deepEqual(report.narrow, [], `${label}: none is narrower than its declared minimum`);
      assert.deepEqual(report.overflowing, [], `${label}: nothing overflows its container`);
      assert.equal(report.pageOverflow, false, `${label}: and the page does not scroll sideways`);
    }
  } finally {
    await context.close();
  }
});

// DESIGN.md `toast`: a toast must not cover the primary control of the surface it reports on. The
// stack's bottom edge is measured whether or not a toast stands, since the host is placed either way.
// Mutation (Rule 19): drop `+ var(--ocu-space-4)` from the `_components.scss` lift, or double it, and
// redeploy -> the stack sits flush on the bar, or too high above it, and this goes red.
test('the change-toast stack stands clear above the form bar holding Save and Cancel', async () => {
  const { context, page } = await signedInAt(EDIT_URL);
  try {
    await editorReady(page);
    const geometry = await page.evaluate(() => {
      const host = document.querySelector('app-toast-host');
      const bar = document.querySelector('.ocu-form-bar');
      // The editor is taller than the content area, so the bar is brought into view where a user
      // reaches it before anything is measured.
      bar?.scrollIntoView({ block: 'end' });
      const space4 = Number.parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--ocu-space-4'));
      const shell = document.querySelector('.ocu-shell');
      return {
        hostBottom: host === null ? null : host.getBoundingClientRect().bottom,
        barTop: bar === null ? null : bar.getBoundingClientRect().top,
        barBottom: bar === null ? null : bar.getBoundingClientRect().bottom,
        barHeight: bar === null ? 0 : bar.getBoundingClientRect().height,
        shellBottom: shell === null ? null : shell.getBoundingClientRect().bottom,
        space4,
      };
    });
    assert.ok(geometry.hostBottom !== null && geometry.barTop !== null, `the toast host and the form bar are both drawn: ${JSON.stringify(geometry)}`);
    assert.ok(geometry.space4 > 0 && geometry.barHeight > 0, `the offsets are measured, not 0 against 0: ${JSON.stringify(geometry)}`);
    assert.ok(geometry.barBottom <= geometry.shellBottom + 0.5, `the bar is measured on screen: ${JSON.stringify(geometry)}`);
    assert.ok(
      Math.abs(geometry.hostBottom - (geometry.barTop - geometry.space4)) <= 1,
      `the stack's bottom edge sits spacing.4 above the bar's top edge: ${JSON.stringify(geometry)}`
    );
  } finally {
    await context.close();
  }
});

test('Delete confirms the typed name and returns to the list, and the account is gone', async () => {
  const { context, page } = await signedInAt(EDIT_URL);
  try {
    await editorReady(page);
    await page.click('[data-action="delete"]');
    await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-typed-name-consequence', (node) => node.textContent.trim()), STRINGS.userDeleteConsequence);
    await page.type('.ocu-typed-name-field', PROBE);
    await page.keyboard.press('Enter');
    await page.waitForFunction(() => new URL(window.location.href).pathname.endsWith('/permissions/users'), {
      timeout: config.navigationTimeoutMs,
    });
    assert.equal(probeField('Enabled'), 'gone', 'the instance no longer holds the account');
  } finally {
    createProbe();
    await context.close();
  }
});

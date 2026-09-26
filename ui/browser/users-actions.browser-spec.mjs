/**
 * Story 7.2 in a real browser, against the throwaway instance: the Users list's row actions, end
 * to end through `POST /screens/permissions.users/action` (AD-5, AD-53, AD-56).
 *
 * What it pins: disable and enable from the row menu and the command bar, set password through its
 * own dialog -- the value sent exactly as typed, a trailing space included, and the account then
 * signing in with it -- a role added and removed through the role dialog, and the typed-name delete,
 * each re-fetching the row in place (AC1, AC2, AC4, AC5); and the protected accounts listing
 * disable and delete refused with their published sentences, sending nothing (AC3).
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
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const LIST_URL = '/ocupilot/permissions/users?ns=HSCUSTOM';
const ACTION_PATH = '/api/ocupilot/screens/permissions.users/action';

/** This spec's own account, never one the instance had, and the password it starts with. */
const PROBE = 'OcuPilotProbeUserBrowserActions';
const PROBE_PASSWORD = 'OcuPilotBrowserStart9Aa';
const PROBE_MARKER = 'OcuPilot users-actions browser spec probe (throwaway)';

/** The password set through the dialog: the trailing space is the paste AC2 means. */
const NEW_PASSWORD = 'OcuPilotBrowserNew9Bb ';

/** The two cells this spec reads, by column index. */
const ENABLED_CELL = 2;
const ROLES_CELL = 5;

/** The selector the name cell's own text element carries. */
const NAME_TEXT = '.ocu-data-table-link, .ocu-data-table-text';

let browser = null;

/** Run ObjectScript in `iris session` inside the throwaway and read back the named markers. */
function irisSession(lines, names) {
  const input = `${[...lines, 'Halt'].join('\n')}\n`;
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', '%SYS'], {
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

/** Remove the probe account by its exact name, and only where it carries this spec's marker. */
const REMOVE = `If ##class(Security.Users).Exists("${PROBE}") { Kill tP Do ##class(Security.Users).Get("${PROBE}",.tP) If $Get(tP("Comment"))="${PROBE_MARKER}" Do ##class(Security.Users).Delete("${PROBE}") }`;

function createProbe() {
  return irisSession(
    [
      REMOVE,
      `Set tSC=##class(Security.Users).Create("${PROBE}","%SQL","${PROBE_PASSWORD}","probe","","","",0,1,"${PROBE_MARKER}")`,
      mark('MADE', '$System.Status.IsOK(tSC)'),
    ],
    ['MADE']
  );
}

function deleteProbe() {
  return irisSession([REMOVE, mark('CLEAN', `('##class(Security.Users).Exists("${PROBE}"))`)], ['CLEAN']);
}

/** One property of the probe account as the instance holds it; `gone` when it is not there. */
function probeField(field) {
  const { values } = irisSession(
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
  const { values, output } = deleteProbe();
  assert.equal(values.CLEAN, '1', `the probe account is gone:\n${output}`);
});

/** A fresh context signed in at the list, with the action requests it issues recorded. */
async function signedInAtList() {
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  const writes = [];
  page.on('request', (request) => {
    if (new URL(request.url()).pathname === ACTION_PATH) writes.push(request.postData() ?? '');
  });
  await page.goto(`${config.origin}${LIST_URL}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', config.username);
  await page.type('#ocu-signin-password', config.password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, LIST_URL);
  await waitForRows(page, config.navigationTimeoutMs);
  return { context, page, writes };
}

/** Narrow the list to `name` and select that row, leaving the filter in place. */
async function selectOnly(page, name) {
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, name);
  await page.waitForFunction(
    (selector, wanted, textSelector) =>
      Array.from(document.querySelectorAll(selector)).some((row) => {
        const cell = row.querySelector('[role="gridcell"]');
        const text = cell.querySelector(textSelector);
        return (text === null ? cell : text).textContent.trim() === wanted;
      }),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name,
    NAME_TEXT
  );
  await clickRowCentre(page, { text: name });
}

/** The text of cell `index` of the row named `name`, or `null` when no row carries that name. */
function cellText(page, name, index) {
  return page.evaluate(
    (selector, wanted, textSelector, column) => {
      const row = Array.from(document.querySelectorAll(selector)).find((candidate) => {
        const cell = candidate.querySelector('[role="gridcell"]');
        const text = cell.querySelector(textSelector);
        return (text === null ? cell : text).textContent.trim() === wanted;
      });
      return row === undefined ? null : row.querySelectorAll('[role="gridcell"]')[column].textContent.trim();
    },
    ROW_SELECTOR,
    name,
    NAME_TEXT,
    index
  );
}

/** Wait until cell `index` of the row named `name` satisfies `wanted` (a substring, or absence). */
async function waitForCell(page, name, index, wanted, present = true) {
  await page.waitForFunction(
    (selector, rowName, textSelector, column, text, want) => {
      const row = Array.from(document.querySelectorAll(selector)).find((candidate) => {
        const cell = candidate.querySelector('[role="gridcell"]');
        const own = cell.querySelector(textSelector);
        return (own === null ? cell : own).textContent.trim() === rowName;
      });
      if (row === undefined) return false;
      return row.querySelectorAll('[role="gridcell"]')[column].textContent.includes(text) === want;
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name,
    NAME_TEXT,
    index,
    wanted,
    present
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
      disabled: item.hasAttribute('disabled'),
    }))
  );
}

/** Choose the row-menu entry whose label is `label`. */
async function chooseFromMenu(page, label) {
  await openRowMenu(page);
  await page.evaluate((wanted) => {
    const items = Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'));
    items.find((item) => item.textContent.trim().startsWith(wanted)).click();
  }, label);
}

test('AC1, AC2, AC4, AC5: every Users row action reaches the route and the row re-fetches in place', async () => {
  const { context, page, writes } = await signedInAtList();
  try {
    await selectOnly(page, PROBE);
    const entries = await openRowMenu(page);
    assert.deepEqual(
      entries.map((entry) => entry.label),
      [
        STRINGS.agentDefinitionEnable,
        STRINGS.agentDefinitionDisable,
        STRINGS.userActionSetPassword,
        STRINGS.userActionAddRole,
        STRINGS.userActionRemoveRole,
        STRINGS.actionDelete,
        STRINGS.userActionRevokeTokens,
      ],
      'the menu lists the seven drawn actions in declared order, destructive last, and not the flag'
    );
    for (const entry of entries) assert.equal(entry.ariaDisabled, null, `${entry.label} is selectable on an ordinary account`);
    await page.keyboard.press('Escape');

    // Disable from the row menu, enable from the command bar.
    await chooseFromMenu(page, STRINGS.agentDefinitionDisable);
    await waitForCell(page, PROBE, ENABLED_CELL, STRINGS.tableStatusNo);
    assert.equal(probeField('Enabled'), '0', 'the instance reports the account disabled');
    assert.equal(await page.$eval(FILTER_SELECTOR, (field) => field.value), PROBE, 'the filter survived the write');
    await page.evaluate((label) => {
      const actions = Array.from(document.querySelectorAll('.ocu-command-bar-action'));
      actions.find((action) => action.textContent.trim() === label).click();
    }, STRINGS.agentDefinitionEnable);
    await waitForCell(page, PROBE, ENABLED_CELL, STRINGS.tableStatusYes);
    assert.equal(probeField('Enabled'), '1', 'and enabled again');

    // Set password: its own dialog, the value pasted with a trailing space, sent exactly once.
    await chooseFromMenu(page, STRINGS.userActionSetPassword);
    await page.waitForSelector('[role="dialog"] input[autocomplete="new-password"]', { timeout: config.navigationTimeoutMs });
    const opened = await page.evaluate(() => {
      const field = document.querySelector('[role="dialog"] input[autocomplete="new-password"]');
      return {
        value: field.value,
        type: field.type,
        focused: document.activeElement === field,
        flag: document.querySelector('[role="dialog"] input[type="checkbox"]').checked,
        title: document.querySelector('.ocu-dialog-title').textContent.trim(),
      };
    });
    assert.deepEqual(opened, { value: '', type: 'password', focused: true, flag: false, title: `${STRINGS.userActionSetPassword} ${PROBE}` }, 'empty, masked and focused, the flag unchecked');
    await page.evaluate((value) => {
      const field = document.querySelector('[role="dialog"] input[autocomplete="new-password"]');
      field.value = value;
      field.dispatchEvent(new Event('input', { bubbles: true }));
    }, NEW_PASSWORD);
    const before = writes.length;
    await page.click('[role="dialog"] .ocu-button-primary');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await page.waitForNetworkIdle({ idleTime: 500, timeout: config.navigationTimeoutMs });
    const sent = writes.slice(before).map((body) => JSON.parse(body));
    assert.deepEqual(sent, [{ action: 'set-password', id: PROBE, values: { Password: NEW_PASSWORD } }], 'one request carrying the value byte for byte');
    assert.equal(await loginStatus(NEW_PASSWORD), 200, 'the account signs in with the password as pasted');
    assert.equal(await loginStatus(NEW_PASSWORD.trim()), 401, 'and not with it trimmed');

    // Add a role, then remove it, through the role dialog.
    await chooseFromMenu(page, STRINGS.userActionAddRole);
    await page.waitForSelector('[role="dialog"] select', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[role="dialog"] label', (label) => label.textContent.trim()), STRINGS.userRoleField);
    // DW-1523: a privileged choice states the grant's consequence under the select, read with it.
    const effectOf = () =>
      page.evaluate(() => {
        const select = document.querySelector('[role="dialog"] select');
        const id = select.getAttribute('aria-describedby');
        return id === null ? null : (document.getElementById(id)?.textContent.trim() ?? '');
      });
    await page.select('[role="dialog"] select', '%Manager');
    assert.equal(await effectOf(), STRINGS.privilegedGrantEffect, 'a privileged role states its consequence');
    await page.select('[role="dialog"] select', '%Developer');
    assert.equal(await effectOf(), null, 'and an ordinary one states none');
    await page.click('[role="dialog"] .ocu-button-primary');
    await waitForCell(page, PROBE, ROLES_CELL, '%Developer');
    assert.ok(probeField('Roles').includes('%Developer'), 'the instance holds the added role');
    assert.ok(probeField('Roles').includes('%SQL'), 'and the one it had');
    await chooseFromMenu(page, STRINGS.userActionRemoveRole);
    await page.waitForSelector('[role="dialog"] select', { timeout: config.navigationTimeoutMs });
    await page.select('[role="dialog"] select', '%Developer');
    await page.click('[role="dialog"] .ocu-button-primary');
    await waitForCell(page, PROBE, ROLES_CELL, '%Developer', false);
    assert.ok(!probeField('Roles').includes('%Developer'), 'and no longer holds it');

    // Delete, through the typed-name dialog with its own consequence.
    await chooseFromMenu(page, STRINGS.actionDelete);
    await page.waitForSelector('.ocu-typed-name-consequence', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-typed-name-consequence', (body) => body.textContent.trim()), STRINGS.userDeleteConsequence);
    await page.type('.ocu-typed-name-field', PROBE);
    await page.keyboard.press('Enter');
    await page.waitForFunction(
      (selector, wanted, textSelector) =>
        !Array.from(document.querySelectorAll(selector)).some((row) => {
          const cell = row.querySelector('[role="gridcell"]');
          const text = cell.querySelector(textSelector);
          return (text === null ? cell : text).textContent.trim() === wanted;
        }),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      PROBE,
      NAME_TEXT
    );
    assert.equal(probeField('Enabled'), 'gone', 'the instance no longer holds the account');
    assert.equal(writes.length, 6, 'one request per action: disable, enable, password, add, remove, delete');
  } finally {
    createProbe();
    await context.close();
  }
});

test('AC3: a protected account lists disable and delete refused with its published sentence and sends nothing', async () => {
  // DW-1520 (Story 9.1): a service account's Set password is refused too, with the sign-in
  // sentence; _SYSTEM's is offered.
  const { context, page, writes } = await signedInAtList();
  try {
    for (const [account, sentence, signIn] of [
      ['_SYSTEM', STRINGS.userRefusalSystemAccount, ''],
      ['CSPSystem', STRINGS.userRefusalServiceAccount, STRINGS.userRefusalServiceAccountSignIn],
    ]) {
      await selectOnly(page, account);
      const entries = await openRowMenu(page);
      for (const entry of entries) {
        const protectedAction = entry.label === STRINGS.agentDefinitionDisable || entry.label === STRINGS.actionDelete;
        const expected = protectedAction ? sentence : entry.label === STRINGS.userActionSetPassword ? signIn : '';
        assert.equal(entry.reason, expected, `${account} ${entry.label}: ${expected === '' ? 'offered' : 'explained'}`);
        assert.equal(entry.ariaDisabled, expected === '' ? null : 'true', `${account} ${entry.label}: aria-disabled only where refused`);
        assert.equal(entry.disabled, false, 'never the disabled attribute');
      }
      await page.evaluate((label) => {
        const items = Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'));
        items.find((item) => item.textContent.trim().startsWith(label)).click();
      }, STRINGS.agentDefinitionDisable);
      await page.waitForNetworkIdle({ idleTime: 500, timeout: config.navigationTimeoutMs });
      await page.keyboard.press('Escape');
    }
    assert.equal(writes.length, 0, 'no request left the browser');
  } finally {
    await context.close();
  }
});

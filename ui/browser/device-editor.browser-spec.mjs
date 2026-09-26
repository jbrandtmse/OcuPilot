/**
 * The device editor in a real browser, against the throwaway instance (Story 8.8).
 *
 * Four claims, each asserted on rendered DOM, on the real URL or on the instance itself:
 *
 * 1. **The Devices list's Create opens the editor** (AC1), whose nine fields are the classic device
 *    page's, in its order.
 * 2. **A create and an edit reach the Devices list without a refresh** (AC2): Save replaces the
 *    route with `os-management/devices/edit/<name>` and reads the saved sentence; the list, reached by
 *    the form's own Cancel rather than a load, shows the row; its name cell opens the editor, and an
 *    edit's change shows on the row the same way. The change event itself is pinned in
 *    `device-form.store.spec.ts`.
 * 3. **A deep link to the editor without `%Admin_Manage` is the screen-wide denial** (AC5), for a
 *    create and for an edit.
 * 4. **A changed form asks before it is left** (AC6).
 *
 * **It refuses the live container.** It makes its own device and principal inside the throwaway and
 * removes each by exact name, before and after.
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

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));
const { formatDeniedScreen } = await import(join(uiRoot, 'src', 'app', 'core', 'navigation.ts'));

const config = browserConfig();

/** The probe device the create leg makes. */
const DEVICE = 'OcuPilotProbe88Browser';

const LIST_URL = '/ocupilot/os-management/devices?ns=HSCUSTOM';
const CREATE_URL = '/ocupilot/os-management/devices/edit?ns=HSCUSTOM';
const EDIT_URL = `/ocupilot/os-management/devices/edit/${DEVICE}?ns=HSCUSTOM`;

/** The purpose-built principal without the manage resource, and its role. */
const NO_MANAGE_USER = 'OcuPilotDeviceNoManage';
const NO_MANAGE_ROLE = 'OcuPilotDeviceNoManageRole';
const NO_MANAGE_PASSWORD = `OcuPilotDev${Date.now()}Aa9`;
const MANAGE_PAIR = '%Admin_Manage:USE';

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

/** Remove the probe device and the principal, each by its exact name. */
const cleanupLines = [
  `If ##class(Config.Devices).Exists("${DEVICE}") Do ##class(Config.Devices).Delete("${DEVICE}")`,
  `If ##class(Security.Users).Exists("${NO_MANAGE_USER}") Do ##class(Security.Users).Delete("${NO_MANAGE_USER}")`,
  `If ##class(Security.Roles).Exists("${NO_MANAGE_ROLE}") Do ##class(Security.Roles).Delete("${NO_MANAGE_ROLE}")`,
];

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec drives the throwaway, never the live container');
  assert.notEqual(config.container, '', 'it removes what it makes, so it needs the container that serves the origin');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  const { values, output } = irisSys(
    [
      ...cleanupLines,
      'Set tNS=$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"):"HSCUSTOM",1:"USER")',
      'Set tRes=##class(SYS.Database).%OpenId(##class(Config.Databases).Open(##class(Config.Namespaces).Open(tNS).Routines).Directory).ResourceName',
      `Set tSC1=##class(Security.Roles).Create("${NO_MANAGE_ROLE}","OcuPilot device browser spec probe (throwaway)",tRes_":R,%Admin_Operate:U,%DB_IRISSYS:R","")`,
      `Set tSC2=##class(Security.Users).Create("${NO_MANAGE_USER}","${NO_MANAGE_ROLE}","${NO_MANAGE_PASSWORD}","OcuPilot device browser spec probe (throwaway)","","","",0,1,"")`,
      mark('CREATED', '$System.Status.IsOK(tSC1)&&$System.Status.IsOK(tSC2)'),
      mark('MANAGE', `$SYSTEM.Security.CheckUserPermission("${NO_MANAGE_USER}","%Admin_Manage","USE")`),
    ],
    ['CREATED', 'MANAGE']
  );
  assert.equal(values.CREATED, '1', `the role and principal were created:\n${output}`);
  assert.equal(values.MANAGE, '0', 'and the principal does not hold %Admin_Manage:USE');
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  const { values, output } = irisSys(
    [
      ...cleanupLines,
      mark('CLEAN', `('##class(Config.Devices).Exists("${DEVICE}"))&&('##class(Security.Users).Exists("${NO_MANAGE_USER}"))&&('##class(Security.Roles).Exists("${NO_MANAGE_ROLE}"))`),
    ],
    ['CLEAN']
  );
  assert.equal(values.CLEAN, '1', `the device, the principal and its role are gone:\n${output}`);
});

/** The instance's stored value of `property` for the device `name`, or '' when it holds none. */
function stored(name, property) {
  const { values } = irisSys(
    [`Kill p Set tSC=##class(Config.Devices).Get("${name}",.p)`, mark('VALUE', `$Select($System.Status.IsOK(tSC):$Get(p("${property}")),1:"<absent>")`)],
    ['VALUE']
  );
  return values.VALUE;
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

/** Wait until the Devices list carries a row naming DEVICE whose text includes `text`, and answer it. */
async function rowFor(page, text) {
  await waitForRows(page, config.navigationTimeoutMs);
  await page.waitForFunction(
    (selector, name, wanted) => [...document.querySelectorAll(selector)].some((row) => row.textContent.includes(name) && row.textContent.includes(wanted)),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    DEVICE,
    text
  );
  return page.$$eval(ROW_SELECTOR, (nodes, name) => nodes.find((node) => node.textContent.includes(name))?.textContent ?? '', DEVICE);
}

// AC1. Mutation (Rule 19): move the Alias block above Description in the page template and
// redeploy -> the order assertion goes red.
test("AC1: the Devices list's Create opens the editor, whose nine fields are the classic device page's, in its order", async () => {
  const { context, page } = await signedInAt(LIST_URL);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const create = await page.waitForSelector('.ocu-command-bar button.ocu-button-primary', {
      visible: true,
      timeout: config.navigationTimeoutMs,
    });
    await create.click();
    await page.waitForFunction(() => new URL(window.location.href).pathname.endsWith('/os-management/devices/edit'), {
      timeout: config.navigationTimeoutMs,
    });
    await page.waitForSelector('#ocu-device-Name', { visible: true, timeout: config.navigationTimeoutMs });
    const labels = await page.$$eval('.ocu-form-fields .ocu-field-label', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(labels, [
      STRINGS.tableColumnName,
      STRINGS.deviceColumnPhysical,
      STRINGS.tableColumnType,
      STRINGS.deviceColumnSubtype,
      STRINGS.deviceFieldOpenParameters,
      STRINGS.tableColumnDescription,
      STRINGS.x509ColumnAlias,
      STRINGS.deviceFieldAlternate,
      STRINGS.deviceFieldPrompt,
    ]);
    assert.equal(await page.$eval('#ocu-device-Type', (node) => node.value), 'OTH', 'the type starts at the classic default');
    assert.equal(await page.$eval('#ocu-device-SubType', (node) => node.value), 'P-DEC', 'and so does the subtype');
    const subTypes = await page.$$eval('#ocu-device-SubType option', (nodes) => nodes.length);
    assert.ok(subTypes > 1, 'the subtype offers the instance\'s own list');
  } finally {
    await context.close();
  }
});

// AC2. Mutation (Rule 19): drop the route replacement from `onSave` and redeploy -> the URL leg
// goes red.
test('AC2: a create and an edit reach the Devices list without a refresh, and its name cell opens the editor', async () => {
  const { context, page } = await signedInAt(CREATE_URL);
  try {
    await fill(page, 'ocu-device-Name', DEVICE);
    await fill(page, 'ocu-device-PhysicalDevice', '/tmp/p88browser.txt');
    await fill(page, 'ocu-device-Description', 'first');
    await fill(page, 'ocu-device-Alias', '9900');
    // The form page scrolls inside itself under its sticky bar (DW-1596), so the control is brought
    // clear of the bar before the pointer reaches it, as a person scrolls to it.
    await page.$eval('#ocu-device-Prompt-1', (node) => node.scrollIntoView({ block: 'center' }));
    await page.click('#ocu-device-Prompt-1');
    await (await barButtons(page)).save.click();
    await page.waitForFunction(
      (sentence) => document.querySelector('.ocu-form-bar-status')?.textContent?.includes(sentence) === true,
      { timeout: config.navigationTimeoutMs },
      STRINGS.formSaved
    );
    await page.waitForFunction(
      (name) => new URL(window.location.href).pathname.endsWith(`/os-management/devices/edit/${name}`),
      { timeout: config.navigationTimeoutMs },
      DEVICE
    );
    assert.equal(stored(DEVICE, 'Alias'), '9900', 'the instance holds the device with its alias');
    assert.equal(stored(DEVICE, 'Prompt'), '1', 'and its prompt');

    const loads = [];
    page.on('load', () => loads.push(page.url()));
    await (await barButtons(page)).cancel.click();
    await page.waitForFunction(() => new URL(window.location.href).pathname.endsWith('/os-management/devices'), {
      timeout: config.navigationTimeoutMs,
    });
    const created = await rowFor(page, 'first');
    assert.ok(created.includes('/tmp/p88browser.txt') && created.includes('9900'), `the row shows the new device: ${created}`);

    await page.evaluate((name) => {
      const links = [...document.querySelectorAll('[role="grid"] .ocu-data-table-body .ocu-data-table-link')];
      links.find((link) => link.textContent.trim() === name).click();
    }, DEVICE);
    await page.waitForFunction(
      (name) => new URL(window.location.href).pathname.endsWith(`/os-management/devices/edit/${name}`),
      { timeout: config.navigationTimeoutMs },
      DEVICE
    );
    await page.waitForFunction(() => document.querySelector('#ocu-device-Description')?.value === 'first', {
      timeout: config.navigationTimeoutMs,
    });
    assert.equal(await page.$eval('#ocu-device-Name', (node) => node.readOnly), true, 'the name cell opens the editor over that device, its name read-only');
    await fill(page, 'ocu-device-Description', 'second');
    await (await barButtons(page)).save.click();
    await page.waitForFunction(
      (sentence) => document.querySelector('.ocu-form-bar-status')?.textContent?.includes(sentence) === true,
      { timeout: config.navigationTimeoutMs },
      STRINGS.formSaved
    );
    await (await barButtons(page)).cancel.click();
    const edited = await rowFor(page, 'second');
    assert.ok(edited.includes('9900'), `the row shows the edit and keeps the alias: ${edited}`);
    assert.deepEqual(loads, [], 'the list was reached each time without a page load');
  } finally {
    await context.close();
  }
});

// AC5. Mutation (Rule 19): drop `%Admin_Manage` from DeviceForm's privileges, rebuild the mirror
// and redeploy -> the form renders and this goes red.
test('AC5: a deep link to the editor without the manage resource is the screen-wide denial naming it', async () => {
  for (const url of [CREATE_URL, EDIT_URL]) {
    const { context, page } = await signedInAt(url, NO_MANAGE_USER, NO_MANAGE_PASSWORD);
    try {
      await page.waitForSelector('app-screen-denied .ocu-screen-denied-reason', { timeout: config.navigationTimeoutMs });
      const denied = await page.evaluate(() => ({
        title: document.querySelector('app-screen-denied .ocu-screen-denied-title').textContent.trim(),
        reason: document.querySelector('app-screen-denied .ocu-screen-denied-reason').textContent.trim(),
        form: document.querySelector('#ocu-device-PhysicalDevice') !== null,
      }));
      assert.equal(denied.title, STRINGS.deviceFormLabel, `${url}: the screen title`);
      assert.equal(denied.reason, formatDeniedScreen(STRINGS.privilegeDeniedScreen, MANAGE_PAIR, STRINGS.deviceFormLabel), `${url}: naming the manage pair`);
      assert.equal(denied.form, false, `${url}: and no form`);
    } finally {
      await context.close();
    }
  }
});

// AC6. Mutation (Rule 19): make the store's `change` clear `FormDirty` and redeploy -> Cancel
// leaves without asking and this goes red.
test('AC6: a changed form asks before it is left, and staying keeps the edit', async () => {
  const { context, page } = await signedInAt(CREATE_URL);
  try {
    await fill(page, 'ocu-device-Name', 'OcuPilotProbe88Unsaved');
    await (await barButtons(page)).cancel.click();
    await page.waitForSelector('[role="dialog"] .ocu-dialog-title', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[role="dialog"] .ocu-dialog-title', (node) => node.textContent.trim()), STRINGS.formLeaveWithoutSaving);
    await (await page.$('[role="dialog"] .ocu-dialog-actions button')).click();
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    assert.ok(new URL(page.url()).pathname.endsWith('/os-management/devices/edit'), 'the form is still open');
    assert.equal(await page.$eval('#ocu-device-Name', (node) => node.value), 'OcuPilotProbe88Unsaved', 'with the edit');
  } finally {
    await context.close();
  }
});

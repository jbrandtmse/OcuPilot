/**
 * Privileged routine applications, their editor and the delete in a real browser, against the throwaway instance
 * (Story 18.31).
 *
 * What it pins, each on rendered DOM, on the request the page sent, or on the instance itself:
 *
 * 1. **The way in** (C4): Web applications lists Privileged routine applications fifth, and the side-bar entry opens the
 *    list, which lists OcuPilot's own `OcuPilotState` with its Delete drawn `aria-disabled` and described by the
 *    published sentence (C3).
 * 2. **Create, change and delete** (C2): from the list's Create, a probe application is created on the form and the
 *    instance holds it under the name as typed; a changed description is sent alone and stored; and the typed-name
 *    dialog deletes it from the list.
 * 3. **The editor's tabs** (Story 18.33, C2, C4, C5): on a probe of its own, the Application roles, Matching roles and
 *    Routines and classes tabs add and remove a role, a matching role and a routine, each row appearing and going and
 *    the instance holding the change; a privileged role states its effect and a routine added under it does too; and
 *    OcuPilot's own application draws every tab control `aria-disabled`, which a click leaves as it was.
 *
 * **It refuses the live and development containers.** It touches only probe applications named `OcuProbe1831...` and
 * probe roles named `OcuProbe1833Role...`: `before` and `after` remove them by exact name with
 * `OcuPilot.Test.RoutineAppProbe.RemoveAll`. It never sends a write naming `OcuPilotState` or `OcuPilotIdentity`: its
 * clicks on the own application's refused Delete and refused tab controls are asserted to send nothing. Every read of the list waits for the list's own answer, its rows, before it counts or clicks.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1
 * browser/routine-applications.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { sideBarLabels } from './side-bar-spec.mjs';
import { assertThrowaway } from './structural-walk.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const PROBE = 'OcuPilot.Test.RoutineAppProbe';
const NAME = 'OcuProbe1831Browser';
const OWN = 'OcuPilotState';
const LIST_URL = '/ocupilot/web-applications/routine-applications?ns=HSCUSTOM';
const FORM_ROUTE = 'web-applications/routine-applications/edit';
const SAVE_PATH = '/api/ocupilot/routine-application';
const ACTION_PATH = '/api/ocupilot/screens/webapp.routineapps/action';

let browser = null;

const mark = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/** Run `lines` in `HSCUSTOM` inside the throwaway and return the value each named marker carries. */
function iris(lines, names = []) {
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', 'HSCUSTOM'], {
    input: `${[...lines, 'Halt'].join('\n')}\n`,
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const values = {};
  for (const name of names) {
    const hit = new RegExp(`OCU-${name}-START:(.*?):OCU-${name}-END`).exec(output);
    values[name] = hit === null ? null : hit[1].trim();
  }
  return { values, output };
}

/** Delete every probe application by exact name. */
function removeProbes() {
  iris([`Do ##class(${PROBE}).RemoveAll()`]);
}

/** One member of the probe application as the instance holds it, or `'absent'` when it holds none. */
function stored(member) {
  const expression = `$Select($IsObject(##class(${PROBE}).Stored("","${NAME}")):##class(${PROBE}).Stored("","${NAME}").%Get("${member}"),1:"absent")`;
  const { values, output } = iris([mark('STORED', expression)], ['STORED']);
  assert.ok(values.STORED !== null, `the instance is read:\n${output}`);
  return values.STORED;
}

/** The names of the probe applications the instance holds, comma-joined. */
function held() {
  const { values, output } = iris([mark('NAMES', `$ListToString(##class(${PROBE}).Names())`)], ['NAMES']);
  assert.ok(values.NAMES !== null, `the instance is read:\n${output}`);
  return values.NAMES;
}

/** Wait until the list has answered: at least one row (OcuPilot's own two are always listed). */
async function waitForListAnswered(page) {
  await page.waitForFunction((rows) => document.querySelector(rows) !== null, { timeout: config.navigationTimeoutMs }, ROW_SELECTOR);
}

// The filter has applied: the list shows rows, and every one of them holds `wanted`.
async function waitForFilteredTo(page, wanted) {
  await page.waitForFunction(
    (selector, text) => {
      const rows = Array.from(document.querySelectorAll(selector));
      return rows.length > 0 && rows.every((row) => row.textContent.includes(text));
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    wanted
  );
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec sends a Save, so it never runs inside the live container');
  assert.ok(!/^ocupilot-slot-/.test(config.container), 'nor inside a development instance');
  await assertThrowaway(config);
  removeProbes();
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    if (config.container !== LIVE_CONTAINER) {
      removeProbes();
      assert.equal(held(), '', 'the probe application is gone');
    }
  }
});

// Mutation (Rule 19): give the list a `sideBarPosition` of 0, regenerate the mirror, rebuild and redeploy -> the
// fifth-place assertion goes red; drop the `ocupilot-routine-application` branch from `selfProtectionReason`, rebuild
// and redeploy -> the aria-disabled assertion goes red.
test("C4, C3: Web applications lists Privileged routine applications fifth, its entry opens the list, and OcuPilot's own application is drawn with its Delete refused", async () => {
  const { context, page } = await signedInAt(browser, config, LIST_URL);
  try {
    if ((await page.$('app-side-bar nav.ocu-side-bar')) === null) {
      await page.keyboard.down('Control');
      await page.keyboard.press('b');
      await page.keyboard.up('Control');
    }
    await page.waitForSelector('app-side-bar nav.ocu-side-bar', { timeout: config.navigationTimeoutMs });
    const labels = await page.$$eval('app-side-bar .ocu-side-bar-item .ocu-side-bar-label', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(labels, sideBarLabels('web-applications'), 'the side bar lists its entries in their declared order');
    assert.equal(labels[4], STRINGS.routineAppListLabel, 'Privileged routine applications is the fifth');
    await page.goto(`${config.origin}/ocupilot/web-applications/list?ns=HSCUSTOM`, { waitUntil: 'networkidle2' });
    await page.waitForFunction(
      (label) => Array.from(document.querySelectorAll('app-side-bar .ocu-side-bar-item')).some((item) => item.textContent.trim() === label),
      { timeout: config.navigationTimeoutMs },
      STRINGS.routineAppListLabel
    );
    await page.evaluate((label) => {
      Array.from(document.querySelectorAll('app-side-bar .ocu-side-bar-item')).find((item) => item.textContent.trim() === label).click();
    }, STRINGS.routineAppListLabel);
    await page.waitForFunction(() => new URL(window.location.href).pathname.endsWith('/web-applications/routine-applications'), { timeout: config.navigationTimeoutMs });
    await waitForListAnswered(page);
    await page.waitForFunction((selector, wanted) => Array.from(document.querySelectorAll(selector)).some((row) => row.textContent.includes(wanted)), { timeout: config.navigationTimeoutMs }, ROW_SELECTOR, OWN);
    await page.click(FILTER_SELECTOR, { clickCount: 3 });
    await page.keyboard.press('Backspace');
    await page.type(FILTER_SELECTOR, OWN);
    await waitForFilteredTo(page, OWN);
    await clickRowCentre(page, { text: OWN, cell: 2 });
    await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
    await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
    const drawn = await page.evaluate((label) => {
      const item = Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]')).find(
        (candidate) => candidate.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === label
      );
      if (item === undefined) return null;
      const entry = { disabled: item.getAttribute('aria-disabled'), reason: item.querySelector('.ocu-data-table-menu-reason')?.textContent.trim() ?? '' };
      item.click();
      return entry;
    }, STRINGS.actionDelete);
    assert.deepEqual(drawn, { disabled: 'true', reason: STRINGS.routineAppRefusalOcuPilot }, "OcuPilot's own application's Delete is aria-disabled with the published sentence");
    assert.equal(await page.$('app-typed-name-dialog'), null, 'and a click opens no dialog');
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19), each rebuilt and redeployed: the store's create body without its description -> the create's body
// assertion goes red; the action handler sending the id upper-cased -> the delete's id assertion goes red; the list
// descriptor without its `rowGet`, recompiled -> the row assertion goes red.
test('C2: create a probe application, change its description and delete it with the typed name', async () => {
  removeProbes();
  const { context, page } = await signedInAt(browser, config, LIST_URL);
  const saves = [];
  const actions = [];
  page.on('request', (request) => {
    const path = new URL(request.url()).pathname;
    if (request.method() !== 'GET' && path.startsWith(SAVE_PATH)) saves.push({ method: request.method(), path, body: JSON.parse(request.postData() ?? '{}') });
    if (request.method() === 'POST' && path === ACTION_PATH) actions.push(JSON.parse(request.postData() ?? '{}'));
  });
  const openRowMenu = async (wanted) => {
    await page.click(FILTER_SELECTOR, { clickCount: 3 });
    await page.keyboard.press('Backspace');
    await page.type(FILTER_SELECTOR, NAME);
    await waitForFilteredTo(page, NAME);
    const listed = await page.$$eval(ROW_SELECTOR, (nodes, text) => nodes.filter((node) => node.textContent.includes(text)).map((node) => node.textContent.replace(/\s+/g, ' ').trim()), NAME);
    assert.equal(listed.length, 1, 'the list holds the probe application once');
    assert.ok(listed[0].startsWith(`${NAME}${STRINGS.tableStatusYes}${STRINGS.tableEmptyValue}changed`), `the row lists the name, the enabled flag, the empty resource and the description the instance holds: ${listed[0]}`);
    await clickRowCentre(page, { text: NAME, cell: 2 });
    await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
    await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
    await page.evaluate((label) => {
      Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]')).find((item) => item.textContent.trim().startsWith(label)).click();
    }, wanted);
  };
  try {
    await waitForListAnswered(page);
    assert.equal(await page.$$eval(ROW_SELECTOR, (rows) => rows.filter((row) => row.textContent.includes('OcuProbe1831')).length), 0, 'the list holds no probe application before the create');
    await (await page.waitForSelector('.ocu-command-bar button.ocu-command-bar-primary', { visible: true, timeout: config.navigationTimeoutMs })).click();
    await page.waitForFunction((route) => new URL(window.location.href).pathname.endsWith(`/${route}`), { timeout: config.navigationTimeoutMs }, FORM_ROUTE);
    await page.waitForSelector('#ocu-routine-app-Name', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('#ocu-routine-app-Name', (input) => input.readOnly), false, 'a create takes the name');
    assert.equal(await page.$('#ocu-routine-app-Namespace'), null, 'and offers no namespace');
    await page.type('#ocu-routine-app-Name', NAME);
    await page.type('#ocu-routine-app-Description', 'browser');
    await page.click('.ocu-form-bar-actions button.ocu-button-primary');
    await page.waitForFunction((route) => new URL(window.location.href).pathname.includes(`/${route}/`), { timeout: 90000 }, FORM_ROUTE);
    assert.equal(saves[0].method, 'POST');
    assert.equal(saves[0].path, SAVE_PATH);
    assert.deepEqual(
      saves[0].body,
      { Name: NAME, Description: 'browser', Enabled: true, Resource: '' },
      'the create carries the name and the three settings, each as entered'
    );
    assert.equal(held(), NAME, 'the instance holds the new application, under the name as typed');
    assert.equal(stored('Description'), 'browser', 'with its description');

    // Edit the description: the edit sends that field alone, and the instance holds it.
    await page.waitForSelector('#ocu-routine-app-Description', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('#ocu-routine-app-Name', (input) => input.readOnly), true, 'an edit never changes the name');
    assert.equal(await page.$('[data-routine-app="own-refusal"]'), null, 'and draws no own-application refusal for a probe');
    await page.click('#ocu-routine-app-Description', { clickCount: 3 });
    await page.keyboard.press('Backspace');
    await page.type('#ocu-routine-app-Description', 'changed');
    await page.click('.ocu-form-bar-actions button.ocu-button-primary');
    await page.waitForFunction(() => (document.querySelector('.ocu-form-bar-status [role="status"]')?.textContent ?? '').trim() !== '', { timeout: 90000 });
    assert.deepEqual(saves[1].body, { Description: 'changed' });
    assert.equal(saves[1].method, 'PUT');
    assert.equal(stored('Description'), 'changed', 'the instance holds the change');

    // Delete it through the typed-name dialog on the list.
    await page.goto(`${config.origin}${LIST_URL}`, { waitUntil: 'networkidle2' });
    await waitForListAnswered(page);
    await openRowMenu(STRINGS.actionDelete);
    await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-typed-name-consequence', (node) => node.textContent.trim()), STRINGS.routineAppDeleteConsequence, 'the dialog states what the delete does');
    await page.type('.ocu-typed-name-field', NAME);
    await page.keyboard.press('Enter');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: 90000 });
    await page.waitForFunction(
      (selector, wanted) => !Array.from(document.querySelectorAll(selector)).some((row) => row.textContent.includes(wanted)),
      { timeout: 90000 },
      ROW_SELECTOR,
      NAME
    );
    assert.equal(actions.length, 1, 'one action was sent');
    assert.deepEqual(actions[0], { action: 'delete', id: NAME }, 'naming the probe application');
    assert.equal(held(), '', 'the application is gone');
  } finally {
    await context.close();
    removeProbes();
  }
});

// Mutation (Rule 19), each rebuilt and redeployed: send `Role` under another name in the tabs' `onAssignApplicationRole`
// -> the first action assertion goes red; the tabs' `ruleReason` answering `''` -> the own application's aria-disabled
// legs go red (its clicks then post, refused 403 by the instance, so the own two are never written).
test("C2, C4, C5: the editor's tabs add and remove a role, a matching role and a routine; OcuPilot's own application's tab controls are aria-disabled", async () => {
  removeProbes();
  const tabsName = 'OcuProbe1831Tabs';
  const privilegedRole = 'OcuProbe1833RoleTab';
  const own = () => iris([mark('OWN', `$Translate(##class(OcuPilot.Test.RoutineAppWrite).OwnTwo(),$Char(10),"|")`)], ['OWN']).values.OWN;
  const targets = (match) => iris([mark('T', `##class(${PROBE}).Targets("${tabsName}","${match}")`)], ['T']).values.T;
  const entries = () => iris([mark('E', `##class(${PROBE}).Entries("${tabsName}")`)], ['E']).values.E;
  iris([`Do ##class(${PROBE}).EnsureRole("Tab","%Admin_Secure:U")`, `Do ##class(${PROBE}).Seed("","${tabsName}")`]);
  const ownBefore = own();
  assert.ok(ownBefore !== null && ownBefore.includes('OcuPilotState'), "OcuPilot's own applications are read before");
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${FORM_ROUTE}/${tabsName}?ns=HSCUSTOM`);
  const actions = [];
  page.on('request', (request) => {
    if (request.method() === 'POST' && new URL(request.url()).pathname === ACTION_PATH) actions.push(JSON.parse(request.postData() ?? '{}'));
  });
  const openTab = async (key) => {
    await page.click(`button[data-tab="${key}"]`);
    await page.waitForFunction((tab) => document.querySelector(`[data-tab-body="${tab}"]`)?.hidden === false, { timeout: config.navigationTimeoutMs }, key);
  };
  const rowTexts = (selector) => page.$$eval(selector, (nodes) => nodes.map((node) => node.textContent.replace(/\s+/g, ' ').trim()));
  const waitForRows = async (selector, predicate) => {
    const deadline = Date.now() + 90000;
    for (;;) {
      const texts = await rowTexts(selector);
      if (predicate(texts)) return texts;
      if (Date.now() > deadline) assert.fail(`${selector} never matched: ${JSON.stringify(texts)}`);
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
  };
  const act = async (selector) => {
    const before = actions.length;
    await page.click(selector);
    for (let wait = 0; wait < 90 && actions.length === before; wait += 1) await new Promise((resolve) => setTimeout(resolve, 100));
    assert.equal(actions.length, before + 1, `${selector} sends one action`);
    return actions[actions.length - 1];
  };
  try {
    await page.waitForSelector('#ocu-routine-app-Description', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(
      (await rowTexts('[role="tab"] .ocu-form-tab-label')).join(','),
      [STRINGS.processDetailsGroupGeneral, STRINGS.webAppFormApplicationRoles, STRINGS.webAppTabMatchingRoles, STRINGS.routineAppTabRoutines].join(','),
      'an edit opens on the four tabs'
    );

    // Application roles: an unprivileged role, then a privileged one that states its effect.
    const roleRows = `ul[aria-label="${STRINGS.webAppFormApplicationRoles}"] .ocu-form-role-name`;
    await openTab('application-roles');
    await page.select('#ocu-routine-app-application-role', '%Developer');
    await page.waitForSelector('[data-action="add-application-role"]:not([aria-disabled="true"])', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$('#ocu-routine-app-application-role-effect'), null, 'an unprivileged role states no effect');
    assert.deepEqual(await act('[data-action="add-application-role"]'), { action: 'add-application-role', id: tabsName, values: { Role: '%Developer' } });
    await waitForRows(roleRows, (texts) => texts.includes('%Developer'));
    assert.equal(targets(''), '%Developer', 'the instance holds the application role');
    await page.select('#ocu-routine-app-application-role', privilegedRole);
    await page.waitForSelector('#ocu-routine-app-application-role-effect', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('#ocu-routine-app-application-role-effect', (node) => node.textContent.trim()), STRINGS.privilegedGrantEffect, 'a privileged role states the privilege at the field');
    assert.deepEqual(await act('[data-action="add-application-role"]'), { action: 'add-application-role', id: tabsName, values: { Role: privilegedRole } });
    await waitForRows(roleRows, (texts) => texts.length === 2);
    assert.equal(targets(''), `%Developer,${privilegedRole}`, 'and both roles');

    // Matching roles: add one and remove it.
    const matchRows = `ul[aria-label="${STRINGS.webAppTabMatchingRoles}"] .ocu-form-role-name`;
    await openTab('matching-roles');
    await page.select('#ocu-routine-app-match-role', '%Developer');
    await page.select('#ocu-routine-app-match-target', '%SQL');
    assert.deepEqual(await act('[data-action="add-matching-role"]'), { action: 'add-matching-role', id: tabsName, values: { MatchRole: '%Developer', Role: '%SQL' } });
    await waitForRows(matchRows, (texts) => texts.length === 2);
    assert.deepEqual(await rowTexts(matchRows), ['%Developer', '%SQL'], 'the matching role is listed with its target');
    assert.equal(targets('%Developer'), '%SQL', 'the instance holds it');

    // Routines: a class added under the privileged role states the privilege, then removed.
    await openTab('routines');
    assert.equal(await page.$eval('#ocu-routine-app-routine-effect', (node) => node.textContent.trim()), STRINGS.privilegedGrantEffect, 'a routine added while a privileged role is granted states the privilege');
    await page.type('#ocu-routine-app-routine-name', 'OcuProbe1833.Tab');
    await page.select('#ocu-routine-app-routine-db', 'HSCUSTOM');
    await page.select('#ocu-routine-app-routine-type', 'Class');
    assert.deepEqual(await act('[data-action="add-routine"]'), { action: 'add-routine', id: tabsName, values: { RoutineOrClass: 'OcuProbe1833.Tab', Db: 'HSCUSTOM', Type: 'Class' } });
    const routineCells = `table[aria-label="${STRINGS.routineAppTabRoutines}"] tbody td`;
    await waitForRows(routineCells, (texts) => texts.includes('OcuProbe1833.Tab'));
    assert.deepEqual((await rowTexts(routineCells)).slice(0, 3), ['HSCUSTOM', 'OcuProbe1833.Tab', 'Class'], 'the routine is listed with its database and type');
    assert.equal(entries(), 'OcuProbe1833.Tab:HSCUSTOM:Class', 'the instance holds it');
    assert.deepEqual(await act('[data-action="remove-routine"]'), { action: 'remove-routine', id: tabsName, values: { RoutineOrClass: 'OcuProbe1833.Tab', Db: 'HSCUSTOM', Type: 'Class' } });
    await waitForRows(routineCells, (texts) => texts.length === 0);
    assert.equal(entries(), '', 'the routine is gone from the instance');

    // Remove what was added, tab by tab.
    await openTab('matching-roles');
    assert.deepEqual(await act('[data-action="remove-matching-role"]'), { action: 'remove-matching-role', id: tabsName, values: { MatchRole: '%Developer', Role: '%SQL' } });
    await waitForRows(matchRows, (texts) => texts.length === 0);
    assert.equal(targets('%Developer'), '', 'the matching role is gone');
    await openTab('application-roles');
    await act('[data-action="remove-application-role"]');
    await waitForRows(roleRows, (texts) => texts.length === 1);
    await act('[data-action="remove-application-role"]');
    await waitForRows(roleRows, (texts) => texts.length === 0);
    assert.equal(targets(''), '', 'and both application roles');
    assert.equal(actions.length, 8, 'eight actions were sent in all');

    // OcuPilot's own application: every tab control is aria-disabled, and a click sends nothing.
    await page.goto(`${config.origin}/ocupilot/${FORM_ROUTE}/${OWN}?ns=HSCUSTOM`, { waitUntil: 'networkidle2' });
    await page.waitForSelector('[data-routine-app="own-refusal"]', { timeout: config.navigationTimeoutMs });
    const sent = actions.length;
    for (const key of ['application-roles', 'matching-roles', 'routines']) {
      await openTab(key);
      const controls = await page.$$eval(`[data-tab-body="${key}"] button[data-action]`, (nodes) =>
        nodes.map((node) => ({ action: node.dataset.action, disabled: node.getAttribute('aria-disabled'), described: node.getAttribute('aria-describedby') ?? '' }))
      );
      assert.ok(controls.some((control) => control.action.startsWith('add-')), `${key} draws its Assign`);
      for (const control of controls) {
        assert.equal(control.disabled, 'true', `${key} ${control.action} is aria-disabled`);
        assert.ok(control.described.split(' ').includes(`ocu-routine-app-members-refusal-${key}`), `${key} ${control.action} is described by the sentence`);
      }
      assert.equal(await page.$eval(`[data-tab-body="${key}"] #ocu-routine-app-members-refusal-${key}`, (node) => node.textContent.trim()), STRINGS.routineAppRefusalOcuPilot, `${key} says why`);
      await page.$$eval(`[data-tab-body="${key}"] button[data-action]`, (nodes) => nodes.forEach((node) => node.click()));
    }
    await page.waitForNetworkIdle({ idleTime: 500, timeout: config.navigationTimeoutMs });
    assert.equal(actions.length, sent, 'and a click on any of them sends nothing');
    assert.equal(own(), ownBefore, "OcuPilot's own applications read as before");
  } finally {
    await context.close();
    removeProbes();
  }
});

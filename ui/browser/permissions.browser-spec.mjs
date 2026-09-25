/**
 * The Roles, Resources and Services lists in a real browser, against the throwaway instance (Story
 * 6.2): the Permissions side bar in its declared order and each new list under its declared headers
 * from one read; the Roles filter; the Resources list's Deletable word for a system resource and for
 * one this spec creates; the Services list's cells against its own read answer, an empty allowed
 * address list reading "Unrestricted"; and the deep-link denial for a principal holding
 * `%Admin_Secure` without `%DB_IRISSYS:READ`.
 *
 * **It creates a resource and a security principal and restricts a service, so it refuses the live
 * container.** `before` creates a deletable resource and a principal holding read on the install
 * namespace's code database plus `%Admin_Secure:USE`, and gives the disabled `%Service_Shadow` two
 * allowed addresses so the Services list draws a restricted row; `after` deletes the resource, the
 * principal and its role and restores the service's addresses whether or not a test failed.
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
import { parseMarkers } from './iris-session.mjs';
import { filterToSubset, viewCount, waitForRows } from './list-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));
const { formatDeniedScreen } = await import(join(uiRoot, 'src', 'app', 'core', 'navigation.ts'));

const config = browserConfig();
const READ_PREFIX = '/api/ocupilot/screens/';
const PROBE_RESOURCE = 'OcuPilotPermissionsProbe';
const SECURE_USER = 'OcuPilotPermissionsSecure';
const SECURE_ROLE = 'OcuPilotPermissionsSecureRole';
const PASSWORD = 'OcuPilotPermissions1';
const DENIED_PAIR = '%DB_IRISSYS:READ';
const RESTRICTED_SERVICE = '%Service_Shadow';
const RESTRICTED_ADDRESSES = ['127.0.0.1', '10.0.0.1'];

/** The three new lists: their deep link, their read, their title key and their declared headers. */
const LISTS = {
  roles: {
    url: '/ocupilot/permissions/roles?ns=HSCUSTOM',
    read: `${READ_PREFIX}permissions.roles/read`,
    label: STRINGS.userColumnRoles,
    // Story 9.3: the Roles list declares Delete, so its table carries the row-actions column.
    headers: [STRINGS.tableColumnName, STRINGS.tableColumnDescription, STRINGS.roleColumnCreatedBy, STRINGS.roleColumnEscalationOnly, STRINGS.commandBoxGroupActions],
    literal: ['Name', 'Description', 'Created by', 'Escalation only', 'Actions'],
  },
  resources: {
    url: '/ocupilot/permissions/resources?ns=HSCUSTOM',
    read: `${READ_PREFIX}permissions.resources/read`,
    label: STRINGS.resourceListLabel,
    headers: [
      STRINGS.tableColumnName,
      STRINGS.tableColumnDescription,
      STRINGS.resourceColumnPublicPermission,
      STRINGS.tableColumnType,
      STRINGS.resourceColumnDeletable,
      // Story 9.3: the Resources list declares Delete, so its table carries the row-actions column.
      STRINGS.commandBoxGroupActions,
    ],
    literal: ['Name', 'Description', 'Public permission', 'Type', 'Deletable', 'Actions'],
  },
  services: {
    url: '/ocupilot/permissions/services?ns=HSCUSTOM',
    read: `${READ_PREFIX}permissions.services/read`,
    label: STRINGS.serviceListLabel,
    headers: [
      STRINGS.tableColumnName,
      STRINGS.tableColumnEnabled,
      STRINGS.serviceColumnAuthentication,
      STRINGS.serviceColumnAllowedAddresses,
      STRINGS.tableColumnDescription,
    ],
    literal: ['Name', 'Enabled', 'Authentication methods', 'Allowed IP addresses', 'Description'],
  },
};

let browser = null;
/** `RESTRICTED_SERVICE`'s allowed addresses as `before` found them, restored by `after`. */
let originalAddresses = null;

/**
 * Run ObjectScript lines in `iris session` inside the throwaway, starting in `%SYS`, and return the
 * value each named marker carries.
 */
function irisSession(lines, names) {
  const input = `${[...lines, 'Halt'].join('\n')}\n`;
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', '%SYS'], {
    input,
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  return { values: parseMarkers(output, names), output };
}

const mark = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

const deleteLines = [
  `If ##class(Security.Users).Exists("${SECURE_USER}") Do ##class(Security.Users).Delete("${SECURE_USER}")`,
  `If ##class(Security.Roles).Exists("${SECURE_ROLE}") Do ##class(Security.Roles).Delete("${SECURE_ROLE}")`,
  `If ##class(Security.Resources).Exists("${PROBE_RESOURCE}") Do ##class(Security.Resources).Delete("${PROBE_RESOURCE}")`,
];

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates a resource and a principal, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);

  const { values, output } = irisSession(
    [
      ...deleteLines,
      'Set tNS=$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"):"HSCUSTOM",1:"USER")',
      'Set tRes=##class(SYS.Database).%OpenId(##class(Config.Databases).Open(##class(Config.Namespaces).Open(tNS).Routines).Directory).ResourceName',
      `Set tSC1=##class(Security.Resources).Create("${PROBE_RESOURCE}","OcuPilot permissions browser spec resource (throwaway)","")`,
      `Set tSC2=##class(Security.Roles).Create("${SECURE_ROLE}","OcuPilot permissions browser spec probe (throwaway)",tRes_":R,%Admin_Secure:U","")`,
      `Set tSC3=##class(Security.Users).Create("${SECURE_USER}","${SECURE_ROLE}","${PASSWORD}","OcuPilot permissions browser spec probe (throwaway)","","","",0,1,"")`,
      mark('CREATED', '$System.Status.IsOK(tSC1)&&$System.Status.IsOK(tSC2)&&$System.Status.IsOK(tSC3)'),
      mark('SECURE', `$SYSTEM.Security.CheckUserPermission("${SECURE_USER}","%Admin_Secure","USE")`),
      mark('SYSREAD', `$SYSTEM.Security.CheckUserPermission("${SECURE_USER}","%DB_IRISSYS","READ")`),
      `Set tSC4=##class(Security.Services).Get("${RESTRICTED_SERVICE}",.tService)`,
      mark('ADDRESSES', '$Get(tService("ClientSystems"))'),
      `Kill tChange Set tChange("ClientSystems")="${RESTRICTED_ADDRESSES.join(';')}" Set tSC5=##class(Security.Services).Modify("${RESTRICTED_SERVICE}",.tChange)`,
      mark('RESTRICTED', '$System.Status.IsOK(tSC4)&&$System.Status.IsOK(tSC5)'),
    ],
    ['CREATED', 'SECURE', 'SYSREAD', 'ADDRESSES', 'RESTRICTED']
  );
  // Saved before any assertion below can throw, so `after` restores a service this session changed.
  originalAddresses = values.ADDRESSES;
  assert.equal(values.CREATED, '1', `the resource, role and principal were created:\n${output}`);
  assert.equal(values.SECURE, '1', 'the probe holds %Admin_Secure:USE');
  assert.equal(values.SYSREAD, '0', 'and not %DB_IRISSYS:READ');
  assert.equal(values.RESTRICTED, '1', `${RESTRICTED_SERVICE} was given allowed addresses:\n${output}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  const restoreLines =
    originalAddresses === null
      ? []
      : [
          `Kill tChange Set tChange("ClientSystems")="${originalAddresses}" Set tSC6=##class(Security.Services).Modify("${RESTRICTED_SERVICE}",.tChange)`,
          `Set tSC7=##class(Security.Services).Get("${RESTRICTED_SERVICE}",.tService)`,
          mark('RESTORED', `$System.Status.IsOK(tSC6)&&$System.Status.IsOK(tSC7)&&($Get(tService("ClientSystems"))="${originalAddresses}")`),
        ];
  const { values, output } = irisSession(
    [
      ...deleteLines,
      ...restoreLines,
      mark(
        'CLEAN',
        `('##class(Security.Users).Exists("${SECURE_USER}"))&&('##class(Security.Roles).Exists("${SECURE_ROLE}"))&&('##class(Security.Resources).Exists("${PROBE_RESOURCE}"))`
      ),
    ],
    ['CLEAN', 'RESTORED']
  );
  assert.equal(values.CLEAN, '1', `the resource, the principal and its role are gone:\n${output}`);
  if (originalAddresses !== null) {
    assert.equal(values.RESTORED, '1', `${RESTRICTED_SERVICE}'s allowed addresses are restored:\n${output}`);
  }
});

/**
 * A fresh context signed in through the shell's own form at `url`, with every screen read's path
 * recorded and every screen read's JSON answer captured.
 */
async function signedInAt(url, user, password) {
  // Story 15.5: the remembered screen and shell state lives on the instance now, keyed by the
  // one account every spec signs in as, so a fresh context is no longer a fresh slate on its
  // own -- see `preferences-reset.mjs`.
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  const reads = [];
  const answers = [];
  page.on('request', (request) => {
    const parsed = new URL(request.url());
    if (parsed.pathname.startsWith(READ_PREFIX)) reads.push(parsed.pathname);
  });
  page.on('response', (response) => {
    const parsed = new URL(response.url());
    if (!parsed.pathname.startsWith(READ_PREFIX) || response.request().method() !== 'GET') return;
    answers.push(
      response
        .json()
        .then((body) => ({ path: parsed.pathname, status: response.status(), body }))
        .catch(() => ({ path: parsed.pathname, status: response.status(), body: null }))
    );
  });
  await page.goto(`${config.origin}${url}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', user);
  await page.type('#ocu-signin-password', password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  // The first-login gate takes an administrator to the Definition form on an instance with no
  // enabled definition, whatever URL was asked for (Story 3.6). Back returns to this one.
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, url);
  return { context, page, reads, answers };
}

/** The rendered row whose name cell reads `name`, described cell by cell, or `null`. */
function describeRow(page, name) {
  return page.evaluate((wanted) => {
    const rows = Array.from(document.querySelectorAll('[role="grid"] .ocu-data-table-body [role="row"]'));
    const row = rows.find((candidate) => candidate.querySelector('[role="gridcell"]').textContent.trim() === wanted);
    if (row === undefined) return null;
    return Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => ({
      text: cell.textContent.trim(),
      muted: cell.querySelector('.ocu-data-table-empty-value') !== null,
    }));
  }, name);
}

/**
 * Show `area`'s side bar, whatever the first-login gate left showing.
 *
 * The gate lands an administrator in the Agent co-pilot area before Back returns to the list, and a
 * side bar left open on that area stays on it when the route moves (`ShellState.setActiveArea`).
 * The rail item toggles, so a click is never assumed to have opened anything: the side bar's own
 * landmark name says which area is listed, and the loop reads that.
 */
async function openSideBar(page, area) {
  const wanted = STRINGS.navSideBarLandmark.split('<Area>').join(area);
  for (let attempt = 0; attempt < 4; attempt += 1) {
    const shown = await page.$$eval(
      'app-side-bar nav.ocu-side-bar',
      (nodes, label) => nodes.some((node) => node.getAttribute('aria-label') === label),
      wanted
    );
    if (shown) return;
    await page.click(`.ocu-rail-item[aria-label="${area}"]`);
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  assert.fail(`the ${area} side bar never showed`);
}

/** The table's header labels, in order. */
function headersOf(page) {
  return page.$$eval('.ocu-data-table-header-label', (labels) => labels.map((label) => label.textContent.trim()));
}

test('AC1: the Permissions side bar reads Users, Roles, Resources, Services, and each new list renders its declared headers from exactly one read', async () => {
  for (const [key, list] of Object.entries(LISTS)) {
    const { context, page, reads } = await signedInAt(list.url, config.username, config.password);
    try {
      await waitForRows(page, config.navigationTimeoutMs);
      const headers = await headersOf(page);
      assert.deepEqual(headers, list.headers, `${key}: the declared headers`);
      assert.deepEqual(headers, list.literal, `${key}: in the published words`);
      assert.deepEqual(reads, [list.read], `${key}: exactly one screen read was issued`);

      await openSideBar(page, STRINGS.navAreaPermissions);
      const sideBar = await page.evaluate(() => {
        const nav = document.querySelector('app-side-bar nav.ocu-side-bar');
        const current = nav.querySelector('.ocu-side-bar-item[aria-current="page"] .ocu-side-bar-label');
        return {
          area: nav.querySelector('.ocu-side-bar-eyebrow').textContent.trim(),
          entries: Array.from(nav.querySelectorAll('.ocu-side-bar-item .ocu-side-bar-label')).map((label) => label.textContent.trim()),
          current: current === null ? null : current.textContent.trim(),
        };
      });
      assert.equal(sideBar.area, STRINGS.navAreaPermissions, `${key}: in the Permissions area`);
      assert.deepEqual(
        sideBar.entries,
        [STRINGS.userListLabel, STRINGS.userColumnRoles, STRINGS.resourceListLabel, STRINGS.serviceListLabel],
        `${key}: the side bar lists the four entries in their declared order`
      );
      assert.deepEqual(sideBar.entries, ['Users', 'Roles', 'Resources', 'Services']);
      assert.equal(sideBar.current, list.label, `${key}: and the current entry is this list`);
    } finally {
      await context.close();
    }
  }
});

test('AC2: the Roles filter on %Admin narrows the list to a proper subset', async () => {
  const { context, page } = await signedInAt(LISTS.roles.url, config.username, config.password);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const total = await viewCount(page);
    assert.ok(total >= 2, `the instance lists at least two roles: ${total}`);
    const kept = await filterToSubset(page, { text: '%Admin', expectRow: '%Admin_Secure', total, timeoutMs: config.navigationTimeoutMs });
    assert.ok(kept < total, `%Admin narrows the list: ${kept} of ${total}`);
  } finally {
    await context.close();
  }
});

test("AC3: %DB_IRISSYS's Deletable cell reads No, and the resource this spec created reads Yes", async () => {
  const { context, page } = await signedInAt(LISTS.resources.url, config.username, config.password);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const total = await viewCount(page);
    const leg = { total, timeoutMs: config.navigationTimeoutMs };
    await filterToSubset(page, { ...leg, text: '%DB_IRISSYS', expectRow: '%DB_IRISSYS' });
    const system = await describeRow(page, '%DB_IRISSYS');
    assert.ok(system !== null, 'the %DB_IRISSYS row is rendered');
    assert.equal(system[4].text, STRINGS.tableStatusNo, '%DB_IRISSYS is not deletable');

    await filterToSubset(page, { ...leg, text: PROBE_RESOURCE, expectRow: PROBE_RESOURCE });
    const probe = await describeRow(page, PROBE_RESOURCE);
    assert.ok(probe !== null, `the ${PROBE_RESOURCE} row is rendered`);
    assert.equal(probe[4].text, STRINGS.tableStatusYes, 'the resource this spec created is deletable');
  } finally {
    await context.close();
  }
});

test("AC4: every Services row's Enabled, Authentication methods and Allowed IP addresses cells match the read, and an empty address list reads Unrestricted", async () => {
  const { context, page, answers } = await signedInAt(LISTS.services.url, config.username, config.password);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const answered = await Promise.all(answers);
    const read = answered.find((entry) => entry.path === LISTS.services.read);
    assert.ok(read !== undefined && read.body !== null, 'the read answer was captured');
    const rows = read.body.rows;
    const total = await viewCount(page);
    assert.equal(total, rows.length, 'the table lists every row the read answered');

    let unrestricted = 0;
    let restricted = 0;
    for (const row of rows) {
      let cells = await describeRow(page, row.Name);
      if (cells === null) {
        await filterToSubset(page, { text: row.Name, expectRow: row.Name, total, timeoutMs: config.navigationTimeoutMs });
        cells = await describeRow(page, row.Name);
      }
      assert.ok(cells !== null, `the ${row.Name} row is rendered`);
      assert.equal(cells[1].text, row.Enabled ? STRINGS.tableStatusYes : STRINGS.tableStatusNo, `${row.Name}: Enabled`);
      assert.equal(
        cells[2].text,
        row.AuthenticationMethods.length === 0 ? STRINGS.tableEmptyValue : row.AuthenticationMethods.join(', '),
        `${row.Name}: Authentication methods`
      );
      if (row.AllowedConnections.length === 0) {
        unrestricted += 1;
        assert.equal(cells[3].text, STRINGS.serviceAllowedUnrestricted, `${row.Name}: an empty address list reads Unrestricted`);
        assert.equal(cells[3].text, 'Unrestricted');
        assert.equal(cells[3].muted, false, `${row.Name}: as a word, not as the muted (none)`);
      } else {
        restricted += 1;
        assert.equal(cells[3].text, row.AllowedConnections.join(', '), `${row.Name}: Allowed IP addresses`);
        assert.equal(cells[3].muted, false, `${row.Name}: as addresses, not as the muted (none)`);
      }
    }
    assert.ok(unrestricted > 0, `at least one service is unrestricted, so the Unrestricted leg ran: ${unrestricted} of ${rows.length}`);
    assert.ok(restricted > 0, `at least one service is restricted, so the address leg ran: ${restricted} of ${rows.length}`);
    const shadow = rows.find((row) => row.Name === RESTRICTED_SERVICE);
    assert.deepEqual(shadow?.AllowedConnections, RESTRICTED_ADDRESSES, `the read carries ${RESTRICTED_SERVICE}'s addresses as an array`);
  } finally {
    await context.close();
  }
});

test('AC5: a principal holding %Admin_Secure without %DB_IRISSYS:READ is refused each deep link by name and issues no read', async () => {
  for (const [key, list] of Object.entries(LISTS)) {
    const { context, page, reads } = await signedInAt(list.url, SECURE_USER, PASSWORD);
    try {
      await page.waitForSelector('app-screen-denied .ocu-screen-denied-title', { timeout: config.navigationTimeoutMs });
      const denied = await page.evaluate(() => ({
        title: document.querySelector('app-screen-denied .ocu-screen-denied-title').textContent.trim(),
        reason: document.querySelector('app-screen-denied .ocu-screen-denied-reason').textContent.trim(),
        grid: document.querySelector('[role="grid"]') !== null,
      }));
      assert.equal(denied.title, list.label, `${key}: the deep link renders the screen title`);
      assert.equal(denied.reason, formatDeniedScreen(STRINGS.privilegeDeniedScreen, DENIED_PAIR, list.label), `${key}: naming the pair`);
      assert.equal(denied.reason, `You need %DB_IRISSYS:READ to open ${list.label}.`);
      assert.equal(denied.grid, false, `${key}: and no table`);
      assert.deepEqual(reads, [], `${key}: no screen read was issued`);
    } finally {
      await context.close();
    }
  }
});

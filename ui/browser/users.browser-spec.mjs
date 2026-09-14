/**
 * The users list in a real browser, against the throwaway instance: the declared read with its
 * per-row detail call end to end (AC1), each account state as a word (AC2), the pair set for a
 * principal holding `%Admin_Secure` without `%DB_IRISSYS:READ` (AC6), and the entity id carried in
 * one route segment (AC7).
 *
 * **It creates security principals, so it refuses the live container.** `before` creates a disabled
 * account, an expired one and a principal holding read on the install namespace's code database
 * plus `%Admin_Secure:USE`; `after` deletes all three and the principal's role whether or not a test
 * failed. The expired account is created enabled and then given an expiration date thirty days back
 * through `%OpenId` and `%Save`, because `Security.Users.Modify` refuses a past date; nothing signs in
 * as it.
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

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));
const { formatDeniedScreen } = await import(join(uiRoot, 'src', 'app', 'core', 'navigation.ts'));

const config = browserConfig();
const LIST_URL = '/ocupilot/permissions/users?ns=HSCUSTOM';
const READ_PATH = '/api/ocupilot/screens/permissions.users/read';
const DISABLED_USER = 'OcuPilotDemoDisabled';
const EXPIRED_USER = 'OcuPilotDemoExpired';
const SECURE_USER = 'OcuPilotUsersSecure';
const SECURE_ROLE = 'OcuPilotUsersSecureRole';
const PASSWORD = 'OcuPilotUsers1';
const DENIED_PAIR = '%DB_IRISSYS:READ';

let browser = null;

/**
 * Run ObjectScript lines in `iris session` inside the throwaway, starting in `%SYS`, and return the
 * value each named marker carries. Markers are split on their source line, so the echoed source
 * cannot supply one.
 */
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

const deleteLines = [
  ...[DISABLED_USER, EXPIRED_USER, SECURE_USER].map(
    (user) => `If ##class(Security.Users).Exists("${user}") Do ##class(Security.Users).Delete("${user}")`
  ),
  `If ##class(Security.Roles).Exists("${SECURE_ROLE}") Do ##class(Security.Roles).Delete("${SECURE_ROLE}")`,
];

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates security principals, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);

  const { values, output } = irisSession(
    [
      ...deleteLines,
      'Set tNS=$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"):"HSCUSTOM",1:"USER")',
      'Set tRes=##class(SYS.Database).%OpenId(##class(Config.Databases).Open(##class(Config.Namespaces).Open(tNS).Routines).Directory).ResourceName',
      `Set tSC1=##class(Security.Users).Create("${DISABLED_USER}","","${PASSWORD}","OcuPilot users browser spec disabled account (throwaway)","","","",0,0,"")`,
      `Set tSC2=##class(Security.Users).Create("${EXPIRED_USER}","","${PASSWORD}","OcuPilot users browser spec expired account (throwaway)","","","",0,1,"")`,
      `Set tU=##class(Security.Users).%OpenId($ZConvert("${EXPIRED_USER}","L")) Set tU.ExpirationDate=+$Horolog-30 Set tSC3=tU.%Save() Kill tU`,
      `Set tSC4=##class(Security.Roles).Create("${SECURE_ROLE}","OcuPilot users browser spec probe (throwaway)",tRes_":R,%Admin_Secure:U","")`,
      `Set tSC5=##class(Security.Users).Create("${SECURE_USER}","${SECURE_ROLE}","${PASSWORD}","OcuPilot users browser spec probe (throwaway)","","","",0,1,"")`,
      mark('CREATED', '$System.Status.IsOK(tSC1)&&$System.Status.IsOK(tSC2)&&$System.Status.IsOK(tSC3)&&$System.Status.IsOK(tSC4)&&$System.Status.IsOK(tSC5)'),
      mark('SECURE', `$SYSTEM.Security.CheckUserPermission("${SECURE_USER}","%Admin_Secure","USE")`),
      mark('SYSREAD', `$SYSTEM.Security.CheckUserPermission("${SECURE_USER}","%DB_IRISSYS","READ")`),
    ],
    ['CREATED', 'SECURE', 'SYSREAD']
  );
  assert.equal(values.CREATED, '1', `the three accounts were created:\n${output}`);
  assert.equal(values.SECURE, '1', 'the probe holds %Admin_Secure:USE');
  assert.equal(values.SYSREAD, '0', 'and not %DB_IRISSYS:READ');
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  const { values, output } = irisSession(
    [
      ...deleteLines,
      mark(
        'CLEAN',
        [DISABLED_USER, EXPIRED_USER, SECURE_USER].map((user) => `('##class(Security.Users).Exists("${user}"))`).join('&&') +
          `&&('##class(Security.Roles).Exists("${SECURE_ROLE}"))`
      ),
    ],
    ['CLEAN']
  );
  assert.equal(values.CLEAN, '1', `the three accounts and the role are gone:\n${output}`);
});

/** A fresh context signed in through the shell's own form at the list's deep link, with its read requests counted. */
async function signedInAtList(user, password) {
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  const reads = [];
  page.on('request', (request) => {
    if (new URL(request.url()).pathname.startsWith('/api/ocupilot/screens/')) reads.push(request.url());
  });
  await page.goto(`${config.origin}${LIST_URL}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', user);
  await page.type('#ocu-signin-password', password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  return { context, page, reads };
}

/** The rendered row whose name cell reads `name`, described cell by cell. */
function describeRow(page, name) {
  return page.evaluate((wanted) => {
    const style = (element) => (element === null ? null : getComputedStyle(element).fontFamily.replace(/["']/g, ''));
    const root = getComputedStyle(document.documentElement);
    const rows = Array.from(document.querySelectorAll('[role="grid"] .ocu-data-table-body [role="row"]'));
    const row = rows.find((candidate) => candidate.querySelector('[role="gridcell"]').textContent.trim() === wanted);
    if (row === undefined) return null;
    const cells = Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => {
      const text = cell.querySelector('.ocu-data-table-link, .ocu-data-table-text');
      const disc = cell.querySelector('.ocu-data-table-disc');
      return {
        text: cell.textContent.trim(),
        family: style(text),
        disc: disc === null ? null : { width: disc.getBoundingClientRect().width, kind: disc.getAttribute('data-disc'), next: disc.nextElementSibling?.textContent.trim() },
      };
    });
    return { cells, code: root.getPropertyValue('--ocu-type-code-family').trim().replace(/["']/g, '') };
  }, name);
}

test('AC1: the list reads once, with roles from the detail call, under the declared headers, and filters on a role', async () => {
  const { context, page, reads } = await signedInAtList(config.username, config.password);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const headers = await page.$$eval('.ocu-data-table-header-label', (labels) => labels.map((label) => label.textContent.trim()));
    assert.deepEqual(headers, [
      STRINGS.tableColumnName,
      STRINGS.userColumnFullName,
      STRINGS.tableColumnEnabled,
      STRINGS.userColumnExpired,
      STRINGS.tableColumnType,
      STRINGS.userColumnRoles,
    ]);
    assert.deepEqual(headers, ['Name', 'Full name', 'Enabled', 'Account expired', 'Type', 'Roles']);

    // Each filter leg runs from the whole list and must leave a proper, non-empty subset
    // (DW-267): chained onto the previous leg, a needle the survivors already carried satisfied
    // the old helper before the new filter narrowed anything.
    const total = await viewCount(page);
    assert.ok(total >= 2, `the instance lists at least two users: ${total}`);
    await filterToSubset(page, { text: '%all', expectRow: '_SYSTEM', total, timeoutMs: config.navigationTimeoutMs });
    const system = await describeRow(page, '_SYSTEM');
    assert.ok(system !== null, 'filtering on %all keeps the _SYSTEM row');
    assert.ok(system.cells[5].text.split(', ').includes('%All'), `its Roles cell lists %All: ${system.cells[5].text}`);
    assert.equal(system.cells[5].family, system.code, 'in the code face');

    assert.equal(reads.length, 1, `exactly one screen read was issued: ${JSON.stringify(reads)}`);
    assert.equal(new URL(reads[0]).pathname, READ_PATH);
  } finally {
    await context.close();
  }
});

test('AC2: a disabled account reads No after an outline disc, an expired one reads Yes with no disc, and _SYSTEM is not expired', async () => {
  const { context, page } = await signedInAtList(config.username, config.password);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const total = await viewCount(page);
    const leg = { total, timeoutMs: config.navigationTimeoutMs };
    await filterToSubset(page, { ...leg, text: DISABLED_USER, expectRow: DISABLED_USER });
    const disabled = await describeRow(page, DISABLED_USER);
    assert.deepEqual(disabled.cells[2].disc, { width: 7, kind: 'outline', next: STRINGS.tableStatusNo }, 'Enabled shows a 7px outline disc and then "No"');
    assert.equal(disabled.cells[2].text, STRINGS.tableStatusNo);

    await filterToSubset(page, { ...leg, text: EXPIRED_USER, expectRow: EXPIRED_USER });
    const expired = await describeRow(page, EXPIRED_USER);
    assert.equal(expired.cells[3].text, STRINGS.tableStatusYes, 'Account expired reads "Yes"');
    assert.equal(expired.cells[3].disc, null, 'with no status disc');
    assert.equal(expired.cells[2].text, STRINGS.tableStatusYes, 'and the account is still enabled');

    await filterToSubset(page, { ...leg, text: '_SYSTEM', expectRow: '_SYSTEM' });
    const system = await describeRow(page, '_SYSTEM');
    assert.equal(system.cells[3].text, STRINGS.tableStatusNo, "_SYSTEM's Account expired reads No");
  } finally {
    await context.close();
  }
});

test('AC7: the _SYSTEM name link carries the id in one route segment', async () => {
  const { context, page } = await signedInAtList(config.username, config.password);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await filterToSubset(page, {
      text: '_SYSTEM',
      expectRow: '_SYSTEM',
      total: await viewCount(page),
      timeoutMs: config.navigationTimeoutMs,
    });
    await page.evaluate(() => {
      const rows = Array.from(document.querySelectorAll('[role="grid"] .ocu-data-table-body [role="row"]'));
      const row = rows.find((candidate) => candidate.querySelector('[role="gridcell"]').textContent.trim() === '_SYSTEM');
      row.querySelector('.ocu-data-table-link').click();
    });
    await page.waitForFunction(() => window.location.pathname.endsWith('/permissions/users/_SYSTEM'), {
      timeout: config.navigationTimeoutMs,
    });
    await page.waitForSelector('.ocu-screen-outlet[data-id="_SYSTEM"]', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-screen-outlet', (outlet) => outlet.getAttribute('data-id')), '_SYSTEM');
  } finally {
    await context.close();
  }
});

test('AC6: a principal holding %Admin_Secure without %DB_IRISSYS:READ is refused the deep link and issues no read', async () => {
  const { context, page, reads } = await signedInAtList(SECURE_USER, PASSWORD);
  try {
    await page.waitForSelector('app-screen-denied .ocu-screen-denied-title', { timeout: config.navigationTimeoutMs });
    const denied = await page.evaluate(() => ({
      title: document.querySelector('app-screen-denied .ocu-screen-denied-title').textContent.trim(),
      reason: document.querySelector('app-screen-denied .ocu-screen-denied-reason').textContent.trim(),
      grid: document.querySelector('[role="grid"]') !== null,
    }));
    assert.equal(denied.title, STRINGS.userListLabel, 'the deep link renders the screen title');
    assert.equal(denied.reason, formatDeniedScreen(STRINGS.privilegeDeniedScreen, DENIED_PAIR, STRINGS.userListLabel));
    assert.equal(denied.reason, 'You need %DB_IRISSYS:READ to open Users.');
    assert.equal(denied.grid, false, 'and no table');
    assert.deepEqual(reads, [], 'no screen read was issued');
  } finally {
    await context.close();
  }
});

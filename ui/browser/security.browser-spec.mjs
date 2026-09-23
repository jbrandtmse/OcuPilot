/**
 * The X.509, LDAP / Kerberos, Wallet and Secrets lists in a real browser, against the throwaway
 * instance (Story 6.3): the Security and secrets side bar in its declared order and each new list
 * under its declared headers from one read (AC1); the demo X.509 credential's certificate cells
 * against its own read answer (AC2); a Wallet collection's name cell opening its Secrets list, read
 * once for that collection, with the locator bar leading back to the Wallet list (AC3); and a
 * principal holding the Security pairs without `%Admin_Wallet:USE` gated on the wallet pair in the
 * rail, the command box and two deep links, while X.509 still reads (AC5).
 *
 * **It needs the demo fixture** (`OCUPILOT_DEMO=1`, AD-25): `OcuPilotDemoCert` and the
 * `OcuPilotDemo` wallet collection with its one secret are the rows AC2 and AC3 are asserted on.
 *
 * **It creates a security principal, so it refuses the live container.** `before` creates a role and
 * an account holding read on the install namespace's code database plus `%Admin_Secure:USE` and
 * `%DB_IRISSYS:READ`; `after` deletes both whether or not a test failed.
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
import { clickRowCentre, filterToSubset, viewCount, waitForRows } from './list-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));
const { formatDeniedScreen, formatRequires } = await import(join(uiRoot, 'src', 'app', 'core', 'navigation.ts'));

const config = browserConfig();
const READ_PREFIX = '/api/ocupilot/screens/';
const SECURE_USER = 'OcuPilotSecurityNoWallet';
const SECURE_ROLE = 'OcuPilotSecurityNoWalletRole';
const PASSWORD = 'OcuPilotSecurity1';
const WALLET_PAIR = '%Admin_Wallet:USE';
const DEMO_CERT = 'OcuPilotDemoCert';
const DEMO_COLLECTION = 'OcuPilotDemo';
const DEMO_SECRET = 'OcuPilotDemo.Sample';
const SECRETS_URL = `/ocupilot/security/wallet/secrets/${DEMO_COLLECTION}?ns=HSCUSTOM`;

/** The four new lists: their deep link, their read, their title and their declared headers. */
const LISTS = {
  x509: {
    url: '/ocupilot/security/x509?ns=HSCUSTOM',
    read: `${READ_PREFIX}security.x509/read`,
    label: STRINGS.x509ListLabel,
    headers: [STRINGS.x509ColumnAlias, STRINGS.x509ColumnSubject, STRINGS.x509ColumnIssuer, STRINGS.x509ColumnValidFrom, STRINGS.x509ColumnValidUntil],
    literal: ['Alias', 'Subject', 'Issuer', 'Valid from', 'Valid until'],
    listed: true,
  },
  ldap: {
    url: '/ocupilot/security/ldap?ns=HSCUSTOM',
    read: `${READ_PREFIX}security.ldap/read`,
    label: STRINGS.ldapListLabel,
    headers: [STRINGS.tableColumnName, STRINGS.tableColumnEnabled, STRINGS.tableColumnDescription],
    literal: ['Name', 'Enabled', 'Description'],
    listed: true,
  },
  wallet: {
    url: '/ocupilot/security/wallet?ns=HSCUSTOM',
    read: `${READ_PREFIX}security.wallet/read`,
    label: STRINGS.walletListLabel,
    headers: [STRINGS.tableColumnName, STRINGS.walletColumnUseResource, STRINGS.walletColumnEditResource],
    literal: ['Name', 'Use resource', 'Edit resource'],
    listed: true,
  },
  secrets: {
    url: SECRETS_URL,
    read: `${READ_PREFIX}security.secrets/read`,
    label: STRINGS.walletSecretListLabel,
    headers: [STRINGS.tableColumnName, STRINGS.tableColumnType],
    literal: ['Name', 'Type'],
    listed: false,
  },
};

let browser = null;

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
];

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates a principal, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);

  const { values, output } = irisSession(
    [
      ...deleteLines,
      'Set tNS=$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"):"HSCUSTOM",1:"USER")',
      'Set tRes=##class(SYS.Database).%OpenId(##class(Config.Databases).Open(##class(Config.Namespaces).Open(tNS).Routines).Directory).ResourceName',
      `Set tSC1=##class(Security.Roles).Create("${SECURE_ROLE}","OcuPilot security browser spec probe (throwaway)",tRes_":R,%Admin_Secure:U,%DB_IRISSYS:R","")`,
      `Set tSC2=##class(Security.Users).Create("${SECURE_USER}","${SECURE_ROLE}","${PASSWORD}","OcuPilot security browser spec probe (throwaway)","","","",0,1,"")`,
      mark('CREATED', '$System.Status.IsOK(tSC1)&&$System.Status.IsOK(tSC2)'),
      mark('SECURE', `$SYSTEM.Security.CheckUserPermission("${SECURE_USER}","%Admin_Secure","USE")`),
      mark('SYSREAD', `$SYSTEM.Security.CheckUserPermission("${SECURE_USER}","%DB_IRISSYS","READ")`),
      mark('WALLET', `$SYSTEM.Security.CheckUserPermission("${SECURE_USER}","%Admin_Wallet","USE")`),
    ],
    ['CREATED', 'SECURE', 'SYSREAD', 'WALLET']
  );
  assert.equal(values.CREATED, '1', `the role and principal were created:\n${output}`);
  assert.equal(values.SECURE, '1', 'the probe holds %Admin_Secure:USE');
  assert.equal(values.SYSREAD, '1', 'and %DB_IRISSYS:READ');
  assert.equal(values.WALLET, '0', 'and not %Admin_Wallet:USE');
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  const { values, output } = irisSession(
    [...deleteLines, mark('CLEAN', `('##class(Security.Users).Exists("${SECURE_USER}"))&&('##class(Security.Roles).Exists("${SECURE_ROLE}"))`)],
    ['CLEAN']
  );
  assert.equal(values.CLEAN, '1', `the principal and its role are gone:\n${output}`);
});

/**
 * A fresh context signed in through the shell's own form at `url`, with every screen read's path and
 * query recorded and every screen read's JSON answer captured.
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
    if (parsed.pathname.startsWith(READ_PREFIX)) reads.push({ path: parsed.pathname, search: parsed.searchParams });
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
      link: cell.querySelector('.ocu-data-table-link') !== null,
    }));
  }, name);
}

/** The side bar as rendered: its area, its entry labels and its current entry, opening it first. */
async function sideBarOf(page) {
  if ((await page.$('app-side-bar nav.ocu-side-bar')) === null) {
    await page.keyboard.down('Control');
    await page.keyboard.press('b');
    await page.keyboard.up('Control');
  }
  await page.waitForSelector('app-side-bar nav.ocu-side-bar', { timeout: config.navigationTimeoutMs });
  return page.evaluate(() => {
    const nav = document.querySelector('app-side-bar nav.ocu-side-bar');
    const current = nav.querySelector('.ocu-side-bar-item[aria-current="page"] .ocu-side-bar-label');
    return {
      area: nav.querySelector('.ocu-side-bar-eyebrow').textContent.trim(),
      entries: Array.from(nav.querySelectorAll('.ocu-side-bar-item .ocu-side-bar-label')).map((label) => label.textContent.trim()),
      current: current === null ? null : current.textContent.trim(),
    };
  });
}

/** The table's header labels, in order. */
function headersOf(page) {
  return page.$$eval('.ocu-data-table-header-label', (labels) => labels.map((label) => label.textContent.trim()));
}

/** The answer captured for `readPath`, newest last, or `undefined`. */
async function answerFor(answers, readPath) {
  const answered = await Promise.all(answers);
  return answered.filter((entry) => entry.path === readPath).pop();
}

test('AC1: the Security and secrets side bar reads SSL/TLS, X.509, LDAP / Kerberos, Wallet, OAuth 2.0, and each new list renders its declared headers from exactly one read', async () => {
  for (const [key, list] of Object.entries(LISTS)) {
    const { context, page, reads } = await signedInAt(list.url, config.username, config.password);
    try {
      await waitForRows(page, config.navigationTimeoutMs);
      const headers = await headersOf(page);
      assert.deepEqual(headers, list.headers, `${key}: the declared headers`);
      assert.deepEqual(headers, list.literal, `${key}: in the published words`);
      assert.deepEqual(reads.map((read) => read.path), [list.read], `${key}: exactly one screen read was issued`);

      const sideBar = await sideBarOf(page);
      assert.equal(sideBar.area, STRINGS.navAreaSecurity, `${key}: in the Security and secrets area`);
      assert.deepEqual(
        sideBar.entries,
        [STRINGS.sslListLabel, STRINGS.x509ListLabel, STRINGS.ldapListLabel, STRINGS.walletListLabel, STRINGS.oauthLabel],
        `${key}: the side bar lists the five entries in their declared order`
      );
      assert.deepEqual(sideBar.entries, ['SSL/TLS', 'X.509', 'LDAP / Kerberos', 'Wallet', 'OAuth 2.0']);
      if (list.listed) assert.equal(sideBar.current, list.label, `${key}: and the current entry is this list`);
      else assert.equal(sideBar.entries.includes(list.label), false, `${key}: which is never listed`);
    } finally {
      await context.close();
    }
  }
});

test('AC2: the demo credential\'s Subject, Issuer, Valid from and Valid until cells equal its row of the read answer, and Subject names CN=OcuPilotDemo', async () => {
  const { context, page, answers } = await signedInAt(LISTS.x509.url, config.username, config.password);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const read = await answerFor(answers, LISTS.x509.read);
    assert.ok(read !== undefined && read.body !== null, 'the read answer was captured');
    const row = read.body.rows.find((candidate) => candidate.Alias === DEMO_CERT);
    assert.ok(row !== undefined, `the read answers ${DEMO_CERT}`);

    let cells = await describeRow(page, DEMO_CERT);
    if (cells === null) {
      await filterToSubset(page, { text: DEMO_CERT, expectRow: DEMO_CERT, total: await viewCount(page), timeoutMs: config.navigationTimeoutMs });
      cells = await describeRow(page, DEMO_CERT);
    }
    assert.ok(cells !== null, `the ${DEMO_CERT} row is rendered`);
    assert.deepEqual(
      cells.slice(1).map((cell) => cell.text),
      [row.SubjectDN, row.IssuerDN, row.ValidityNotBefore, row.ValidityNotAfter],
      'Subject, Issuer, Valid from and Valid until are the read row\'s'
    );
    assert.ok(cells[1].text.includes('CN=OcuPilotDemo'), `Subject names CN=OcuPilotDemo: ${cells[1].text}`);
  } finally {
    await context.close();
  }
});

test("AC3: the demo collection's name cell opens its Secrets list, read once for that collection, whose name cell is text and whose locator leads back to Wallet", async () => {
  const { context, page, reads } = await signedInAt(LISTS.wallet.url, config.username, config.password);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    if ((await describeRow(page, DEMO_COLLECTION)) === null) {
      await filterToSubset(page, { text: DEMO_COLLECTION, expectRow: DEMO_COLLECTION, total: await viewCount(page), timeoutMs: config.navigationTimeoutMs });
    }
    const readsBefore = reads.length;
    await clickRowCentre(page, { text: DEMO_COLLECTION, link: true });
    const wanted = `/ocupilot/security/wallet/secrets/${DEMO_COLLECTION}`;
    await page.waitForFunction((path) => window.location.pathname === path, { timeout: config.navigationTimeoutMs }, wanted);
    assert.equal(new URL(page.url()).pathname, wanted, 'the URL names the collection under the Secrets list');
    await page.waitForFunction(
      (name) =>
        Array.from(document.querySelectorAll('[role="grid"] .ocu-data-table-body [role="row"]')).some(
          (row) => row.querySelector('[role="gridcell"]')?.textContent.trim() === name
        ),
      { timeout: config.navigationTimeoutMs },
      DEMO_SECRET
    );

    const secretsReads = reads.slice(readsBefore);
    assert.equal(secretsReads.length, 1, `exactly one read was issued: ${JSON.stringify(secretsReads.map((read) => read.path))}`);
    assert.equal(secretsReads[0].path, LISTS.secrets.read, 'the Secrets list\'s read');
    assert.equal(secretsReads[0].search.get('collection'), DEMO_COLLECTION, 'carrying collection=OcuPilotDemo');

    const secret = await describeRow(page, DEMO_SECRET);
    assert.ok(secret !== null, `the ${DEMO_SECRET} row is rendered`);
    assert.equal(secret[1].text, '%Wallet.KeyValue', 'as a key-value secret');
    assert.ok(await page.$$eval('[role="grid"] .ocu-data-table-body .ocu-data-table-link', (links, name) => links.some((link) => link.textContent.trim() === name && decodeURIComponent(decodeURIComponent(new URL(link.href).pathname)).endsWith(`/security/wallet/secrets/edit/${name}`)), DEMO_SECRET), 'and its name cell is a link that opens security/wallet/secrets/edit/<name>');

    const segment = await page.evaluate((label) => {
      const links = Array.from(document.querySelectorAll('app-locator-bar .ocu-locator-link'));
      const link = links.find((candidate) => candidate.textContent.trim() === label);
      return link === undefined ? null : link.textContent.trim();
    }, STRINGS.walletSecretListLabel);
    assert.equal(segment, STRINGS.walletSecretListLabel, 'the locator bar\'s screen segment is a link');
    await page.evaluate((label) => {
      const links = Array.from(document.querySelectorAll('app-locator-bar .ocu-locator-link'));
      links.find((candidate) => candidate.textContent.trim() === label).click();
    }, STRINGS.walletSecretListLabel);
    await page.waitForFunction(() => window.location.pathname === '/ocupilot/security/wallet', { timeout: config.navigationTimeoutMs });
    assert.equal(new URL(page.url()).pathname, '/ocupilot/security/wallet', 'and it leads to the Wallet list');
  } finally {
    await context.close();
  }
});

test('AC5: without %Admin_Wallet:USE the Security rail item and the command box Wallet entry are gated, both wallet deep links are refused by name with no read, and X.509 reads', async () => {
  const requires = formatRequires(STRINGS.privilegeRequiresResource, WALLET_PAIR);
  assert.equal(requires, 'Requires %Admin_Wallet:USE');

  const x509 = await signedInAt(LISTS.x509.url, SECURE_USER, PASSWORD);
  try {
    await waitForRows(x509.page, config.navigationTimeoutMs);
    assert.deepEqual(x509.reads.map((read) => read.path), [LISTS.x509.read], 'the X.509 deep link reads');

    const rail = await x509.page.evaluate((label) => {
      const item = document.querySelector(`.ocu-rail-item[aria-label="${label}"]`);
      return { disabled: item.getAttribute('aria-disabled'), tip: document.getElementById(item.getAttribute('aria-describedby'))?.textContent.trim() };
    }, STRINGS.navAreaSecurity);
    assert.deepEqual(rail, { disabled: 'true', tip: requires }, 'the Security rail item is gated on the wallet pair');

    await x509.page.click('[role="combobox"]');
    await x509.page.type('[role="combobox"]', STRINGS.walletListLabel);
    await x509.page.waitForSelector('#ocu-command-box-screen-security-wallet', { timeout: config.navigationTimeoutMs });
    const row = await x509.page.$eval('#ocu-command-box-screen-security-wallet', (option) => ({
      disabled: option.getAttribute('aria-disabled'),
      text: option.textContent,
    }));
    assert.equal(row.disabled, 'true', 'the command box Wallet entry is gated');
    assert.ok(row.text.includes(STRINGS.walletListLabel) && row.text.includes(requires), `with the reason inline: ${row.text}`);
  } finally {
    await x509.context.close();
  }

  for (const list of [LISTS.wallet, LISTS.secrets]) {
    const { context, page, reads } = await signedInAt(list.url, SECURE_USER, PASSWORD);
    try {
      await page.waitForSelector('app-screen-denied .ocu-screen-denied-title', { timeout: config.navigationTimeoutMs });
      const denied = await page.evaluate(() => ({
        title: document.querySelector('app-screen-denied .ocu-screen-denied-title').textContent.trim(),
        reason: document.querySelector('app-screen-denied .ocu-screen-denied-reason').textContent.trim(),
        grid: document.querySelector('[role="grid"]') !== null,
      }));
      assert.equal(denied.title, list.label, `${list.label}: the deep link renders the screen title`);
      assert.equal(denied.reason, formatDeniedScreen(STRINGS.privilegeDeniedScreen, WALLET_PAIR, list.label), `${list.label}: naming the wallet pair`);
      assert.equal(denied.reason, `You need %Admin_Wallet:USE to open ${list.label}.`);
      assert.equal(denied.grid, false, `${list.label}: and no table`);
      assert.deepEqual(reads, [], `${list.label}: no screen read was issued`);
    } finally {
      await context.close();
    }
  }
});

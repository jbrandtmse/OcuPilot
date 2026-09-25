/**
 * The OAuth 2.0 screen in a real browser, against the throwaway instance (Story 6.4): the Security and
 * secrets side bar with its OAuth 2.0 entry, the five-tab strip, and each tab's route, headers and one
 * read, reached by Right then Enter and by a click (AC1); the authorization server tab's cells against
 * its own read answer (AC2); a client configuration's name cell opening OcuPilot's own editor, Story
 * 12.5's (AC4); and a principal holding the Resource servers tab's three pairs without the wallet,
 * authorization server or registration resources, gated on the rail, reading the Resource servers tab
 * under a strip whose authorization server and server client tabs are gated, and refused Server client
 * descriptions by name (AC5); and, Story 12.9, every tab's name cells opening OcuPilot's own editor
 * in this tab, with no link to the classic portal and no classic-link card on any of the five (AD-44).
 *
 * **It needs the demo fixture** (`OCUPILOT_DEMO=1`, AD-25), whose SSL/TLS configuration the probe's
 * client configurations name. `before` runs `OcuPilot.Test.OAuthProbe.Create()` and `after` its
 * `Remove()`.
 *
 * **It creates a security principal and OAuth 2.0 objects, so it refuses the live container.**
 * `before` creates a role and an account holding read on the install namespace's code database plus
 * `%Admin_Secure:USE`, `%DB_IRISSYS:READ` and `%Admin_OAuth2_Client:USE`; `after` deletes both whether
 * or not a test failed.
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
import { checkClassicLinks } from '../tools/classic-links.mjs';
import { parseMarkers } from './iris-session.mjs';
import { clickRowCentre, waitForRows } from './list-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));
const { formatDeniedScreen, formatRequires } = await import(join(uiRoot, 'src', 'app', 'core', 'navigation.ts'));
const { encodeEntityId } = await import(join(uiRoot, 'src', 'app', 'core', 'entity-id.ts'));

const config = browserConfig();
const READ_PREFIX = '/api/ocupilot/screens/';
const SECURE_USER = 'OcuPilotOAuthSecure';
const SECURE_ROLE = 'OcuPilotOAuthSecureRole';
const PASSWORD = 'OcuPilotOAuth1';
const CLIENT_B = 'OcuPilotTestB';
const EDITOR_ROUTE = 'security/oauth/clients/edit';

/** The five tabs in strip order: their route, read, label and declared headers. */
const TABS = [
  {
    route: 'security/oauth',
    read: `${READ_PREFIX}security.oauthserverdescriptions/read`,
    label: STRINGS.oauthTabServerDescriptions,
    // Story 12.4: the tab declares row actions, so the table carries the actions column's header.
    headers: [STRINGS.x509ColumnIssuer, STRINGS.oauthTabClients, STRINGS.oauthTabResourceServers, STRINGS.commandBoxGroupActions],
  },
  {
    route: 'security/oauth/clients',
    read: `${READ_PREFIX}security.oauthclients/read`,
    label: STRINGS.oauthTabClients,
    // Story 7.3: the tab declares a row action, so the table carries the actions column's header.
    headers: [
      STRINGS.tableColumnName,
      STRINGS.x509ColumnIssuer,
      STRINGS.oauthColumnClientType,
      STRINGS.oauthColumnDefaultScope,
      STRINGS.commandBoxGroupActions,
    ],
  },
  {
    route: 'security/oauth/resource-servers',
    read: `${READ_PREFIX}security.oauthresourceservers/read`,
    label: STRINGS.oauthTabResourceServers,
    // Story 12.6: the tab declares a row action, so the table carries the actions column's header.
    headers: [STRINGS.tableColumnName, STRINGS.x509ColumnIssuer, STRINGS.commandBoxGroupActions],
  },
  {
    route: 'security/oauth/server',
    read: `${READ_PREFIX}security.oauthserver/read`,
    label: STRINGS.oauthTabServer,
    // Story 12.7: the tab declares row actions, so the table carries the actions column's header.
    headers: [
      STRINGS.x509ColumnIssuer,
      STRINGS.oauthColumnScopes,
      STRINGS.oauthColumnGrantTypes,
      STRINGS.oauthColumnSigningAlgorithm,
      STRINGS.oauthColumnEncryptionAlgorithm,
      STRINGS.oauthColumnKeyAlgorithm,
      STRINGS.oauthColumnServerCredentials,
      STRINGS.commandBoxGroupActions,
    ],
  },
  {
    route: 'security/oauth/server-clients',
    read: `${READ_PREFIX}security.oauthserverclients/read`,
    label: STRINGS.oauthTabServerClients,
    // Story 7.3: as the Client configurations tab.
    headers: [
      STRINGS.tableColumnName,
      STRINGS.oauthColumnClientId,
      STRINGS.oauthColumnClientType,
      STRINGS.oauthColumnRedirectUrls,
      STRINGS.tableColumnDescription,
      STRINGS.commandBoxGroupActions,
    ],
  },
];

const urlOf = (route) => `/ocupilot/${route}?ns=HSCUSTOM`;

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
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates a principal and OAuth 2.0 objects, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);

  const { values, output } = irisSession(
    [
      ...deleteLines,
      'Set tNS=$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"):"HSCUSTOM",1:"USER")',
      'Set tRes=##class(SYS.Database).%OpenId(##class(Config.Databases).Open(##class(Config.Namespaces).Open(tNS).Routines).Directory).ResourceName',
      `Set tSC1=##class(Security.Roles).Create("${SECURE_ROLE}","OcuPilot OAuth browser spec probe (throwaway)",tRes_":R,%Admin_Secure:U,%DB_IRISSYS:R,%Admin_OAuth2_Client:U","")`,
      `Set tSC2=##class(Security.Users).Create("${SECURE_USER}","${SECURE_ROLE}","${PASSWORD}","OcuPilot OAuth browser spec probe (throwaway)","","","",0,1,"")`,
      mark('CREATED', '$System.Status.IsOK(tSC1)&&$System.Status.IsOK(tSC2)'),
      mark('WALLET', `$SYSTEM.Security.CheckUserPermission("${SECURE_USER}","%Admin_Wallet","USE")`),
      mark('REGISTRATION', `$SYSTEM.Security.CheckUserPermission("${SECURE_USER}","%Admin_OAuth2_Registration","USE")`),
      'ZNspace tNS',
      'Set tSC3=##class(OcuPilot.Test.OAuthProbe).Create()',
      mark('PROBE', '$System.Status.IsOK(tSC3)'),
    ],
    ['CREATED', 'WALLET', 'REGISTRATION', 'PROBE']
  );
  assert.equal(values.CREATED, '1', `the role and principal were created:\n${output}`);
  assert.equal(values.WALLET, '0', 'the principal does not hold %Admin_Wallet:USE');
  assert.equal(values.REGISTRATION, '0', 'nor %Admin_OAuth2_Registration:USE');
  assert.equal(values.PROBE, '1', `the probe OAuth 2.0 objects were made:\n${output}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  const { values, output } = irisSession(
    [
      ...deleteLines,
      mark('CLEAN', `('##class(Security.Users).Exists("${SECURE_USER}"))&&('##class(Security.Roles).Exists("${SECURE_ROLE}"))`),
      'ZNspace $Select(##class(%SYS.Namespace).Exists("HSCUSTOM"):"HSCUSTOM",1:"USER")',
      'Set tSC=##class(OcuPilot.Test.OAuthProbe).Remove()',
      mark('REMOVED', '$System.Status.IsOK(tSC)'),
    ],
    ['CLEAN', 'REMOVED']
  );
  assert.equal(values.CLEAN, '1', `the principal and its role are gone:\n${output}`);
  assert.equal(values.REMOVED, '1', `the probe OAuth 2.0 objects are removed:\n${output}`);
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
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, url);
  return { context, page, reads, answers };
}

/** The side bar as rendered: its entry labels and its current entry, opening it first. */
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
      entries: Array.from(nav.querySelectorAll('.ocu-side-bar-item .ocu-side-bar-label')).map((label) => label.textContent.trim()),
      current: current === null ? null : current.textContent.trim(),
    };
  });
}

/** The tab strip as rendered: each tab's label, selection, gating and reason. */
function stripOf(page) {
  return page.evaluate(() =>
    Array.from(document.querySelectorAll('app-detail-page .ocu-detail-tab')).map((tab) => ({
      label: tab.querySelector('.ocu-detail-tab-label').textContent.trim(),
      selected: tab.getAttribute('aria-selected'),
      disabled: tab.getAttribute('aria-disabled'),
      reason: tab.querySelector('.ocu-detail-tab-reason')?.textContent.trim() ?? null,
    }))
  );
}

/** The table's header labels, in order. */
function headersOf(page) {
  return page.$$eval('.ocu-data-table-header-label', (labels) => labels.map((label) => label.textContent.trim()));
}

/** Wait until the page is at `route` and its table has rendered rows under `headers`. */
async function atTab(page, tab) {
  await page.waitForFunction((path) => window.location.pathname === path, { timeout: config.navigationTimeoutMs }, `/ocupilot/${tab.route}`);
  await page.waitForFunction(
    (wanted) => {
      const labels = Array.from(document.querySelectorAll('.ocu-data-table-header-label')).map((label) => label.textContent.trim());
      return JSON.stringify(labels) === JSON.stringify(wanted) && document.querySelector('[role="grid"] .ocu-data-table-body [role="row"]') !== null;
    },
    { timeout: config.navigationTimeoutMs },
    tab.headers
  );
}

/** The answer captured for `readPath`, newest last, or `undefined`. */
async function answerFor(answers, readPath) {
  const answered = await Promise.all(answers);
  return answered.filter((entry) => entry.path === readPath).pop();
}

test('AC1: the side bar lists OAuth 2.0 fifth; its strip reads the five tabs, and Right then Enter and a click on each tab open that tab under its headers from one read of its own tool', async () => {
  const { context, page, reads } = await signedInAt(urlOf(TABS[0].route), config.username, config.password);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await atTab(page, TABS[0]);
    assert.deepEqual(reads, [TABS[0].read], 'the OAuth 2.0 screen issued exactly one read, its first tab\'s');

    const sideBar = await sideBarOf(page);
    assert.deepEqual(sideBar.entries, [STRINGS.sslListLabel, STRINGS.x509ListLabel, STRINGS.ldapListLabel, STRINGS.walletListLabel, STRINGS.oauthLabel, STRINGS.auditingConfigurationLink]);
    assert.deepEqual(sideBar.entries, ['SSL/TLS', 'X.509', 'LDAP / Kerberos', 'Wallet', 'OAuth 2.0', 'Auditing configuration'], 'in the published words');
    assert.equal(sideBar.current, STRINGS.oauthLabel, 'and OAuth 2.0 is the current entry');

    const strip = await stripOf(page);
    assert.deepEqual(strip.map((tab) => tab.label), TABS.map((tab) => tab.label), 'the strip reads the five tabs in order');
    assert.deepEqual(strip.map((tab) => tab.label), ['Client server descriptions', 'Client configurations', 'Resource servers', 'Authorization server', 'Server client descriptions']);
    assert.deepEqual(strip.map((tab) => tab.selected), ['true', 'false', 'false', 'false', 'false'], 'the first selected');

    await page.focus('app-detail-page .ocu-detail-tab:nth-child(1)');
    await page.keyboard.press('ArrowRight');
    const focused = await page.evaluate(() => document.activeElement?.querySelector('.ocu-detail-tab-label')?.textContent.trim() ?? null);
    assert.equal(focused, TABS[1].label, 'Right moves focus to the second tab');
    const beforeEnter = reads.length;
    await page.keyboard.press('Enter');
    await atTab(page, TABS[1]);
    assert.deepEqual(reads.slice(beforeEnter), [TABS[1].read], 'Enter opens it, under its headers, from one read of its own tool');
    await page.waitForFunction(
      (route) => document.activeElement?.getAttribute('data-route') === route,
      { timeout: 5000 },
      TABS[1].route
    ).catch(() => undefined);
    const arrived = await page.evaluate(() => document.activeElement?.getAttribute('data-route') ?? document.activeElement?.tagName ?? null);
    assert.equal(arrived, TABS[1].route, 'and the tab it opened holds focus on the page that replaced the strip');
    assert.equal((await sideBarOf(page)).current, STRINGS.oauthLabel, 'and the side bar still marks OAuth 2.0 current');

    for (const index of [2, 3, 4, 0, 1]) {
      const tab = TABS[index];
      const beforeClick = reads.length;
      // A strip wider than the content column pages; focusing a tab scrolls it into view first.
      await page.focus(`app-detail-page .ocu-detail-tab[data-route="${tab.route}"]`);
      await new Promise((resolve) => setTimeout(resolve, 600));
      await page.click(`app-detail-page .ocu-detail-tab[data-route="${tab.route}"]`);
      await atTab(page, tab);
      assert.deepEqual(await headersOf(page), tab.headers, `${tab.label}: the declared headers`);
      assert.deepEqual(reads.slice(beforeClick), [tab.read], `${tab.label}: exactly one read of its own tool`);
      const selected = (await stripOf(page)).filter((entry) => entry.selected === 'true').map((entry) => entry.label);
      assert.deepEqual(selected, [tab.label], `${tab.label}: and it is the selected tab`);
    }
  } finally {
    await context.close();
  }
});

test("AC2: the authorization server tab's Issuer, Scopes, Grant types and Signing algorithm cells equal the read's row, Scopes names openid, and the row's keys are the declared fields", async () => {
  const tab = TABS[3];
  const { context, page, answers } = await signedInAt(urlOf(tab.route), config.username, config.password);
  try {
    await atTab(page, tab);
    const read = await answerFor(answers, tab.read);
    assert.ok(read !== undefined && read.body !== null, 'the read answer was captured');
    assert.equal(read.body.rows.length, 1, 'one row');
    const row = read.body.rows[0];
    assert.deepEqual(Object.keys(row), read.body.fields, 'the row carries exactly the declared fields');
    assert.deepEqual(read.body.fields, ['IssuerEndpoint', 'Metadata.scopes_supported', 'Metadata.grant_types_supported', 'SigningAlgorithm', 'EncryptionAlgorithm', 'KeyAlgorithm', 'ServerCredentials']);

    const cells = await page.evaluate(() =>
      Array.from(document.querySelectorAll('[role="grid"] .ocu-data-table-body [role="row"] [role="gridcell"]')).map((cell) => cell.textContent.trim())
    );
    assert.deepEqual(
      cells.slice(0, 4),
      [row.IssuerEndpoint, row['Metadata.scopes_supported'].join(', '), row['Metadata.grant_types_supported'].join(', '), row.SigningAlgorithm],
      'Issuer, Scopes, Grant types and Signing algorithm are the read row\'s'
    );
    assert.ok(row['Metadata.scopes_supported'].includes('openid'), `Scopes names openid: ${cells[1]}`);
  } finally {
    await context.close();
  }
});

// A client configuration's name cell opens OcuPilot's own editor, in this tab (AD-44). Mutation
// (Rule 19): restore the tab's classic-link exemption -> the honored-set and in-app anchor assertions go red.
test("AC4: a client configuration's name cell opens OcuPilot's own editor at the configuration's route, in this tab", async () => {
  const honored = checkClassicLinks().honored.map((entry) => entry.file).sort();
  assert.deepEqual(
    honored,
    ['LdapConfigForm.cls', 'ServiceForm.cls'],
    'classic-links honors the two reduced editors alone: no OAuth 2.0 tab links out (AD-44)'
  );

  const tab = TABS[1];
  const { context, page, answers } = await signedInAt(urlOf(tab.route), config.username, config.password);
  try {
    await atTab(page, tab);
    const read = await answerFor(answers, tab.read);
    assert.ok(read.body.rows.some((candidate) => candidate.ApplicationName === CLIENT_B), `the read answers ${CLIENT_B}`);
    const wanted = `/ocupilot/${EDITOR_ROUTE}/${encodeEntityId(CLIENT_B)}`;

    const anchor = await page.evaluate((name) => {
      const rows = Array.from(document.querySelectorAll('[role="grid"] .ocu-data-table-body [role="row"]'));
      const row = rows.find((candidate) => candidate.querySelector('[role="gridcell"]').textContent.trim() === name);
      const link = row?.querySelector('[role="gridcell"] a');
      if (link === undefined || link === null) return null;
      return { path: new URL(link.getAttribute('href'), window.location.href).pathname, target: link.getAttribute('target') };
    }, CLIENT_B);
    assert.deepEqual(anchor, { path: wanted, target: null }, 'the name cell is an in-app anchor at the editor');

    await clickRowCentre(page, { text: CLIENT_B, link: true });
    await page.waitForFunction((path) => new URL(window.location.href).pathname === path, { timeout: config.navigationTimeoutMs }, wanted);
    // `?? ''`: an absent field is not loaded, so the wait holds until the form read has rendered it.
    await page.waitForFunction(() => (document.querySelector('#ocu-oauth-client-ApplicationName')?.value ?? '') !== '', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('#ocu-oauth-client-ApplicationName', (node) => node.value), CLIENT_B, 'the editor reads the configuration');
  } finally {
    await context.close();
  }
});

// No OAuth 2.0 tab links to the classic portal: every name cell is an in-app anchor at the tab's own
// editor, no anchor anywhere on the screen resolves under `/csp/sys/`, and no classic-link card renders
// (AD-44). The Help control's DocBook anchor is documentation and passes. Mutation (Rule 19): restore
// `OAuthClientTab`'s exemption with its `rowLink`, regenerate the mirror and redeploy -> this leg goes red.
test('AC1 (Story 12.9): no OAuth 2.0 tab links to the classic portal', async () => {
  for (const tab of TABS) {
    const { context, page } = await signedInAt(urlOf(tab.route), config.username, config.password);
    try {
      await waitForRows(page, config.navigationTimeoutMs);
      await atTab(page, tab);
      const seen = await page.evaluate(() => {
        const pathOf = (link) => new URL(link.getAttribute('href'), window.location.href).pathname;
        return {
          cells: Array.from(document.querySelectorAll('[role="grid"] .ocu-data-table-body [role="gridcell"] a[href]')).map((link) => ({
            path: pathOf(link),
            target: link.getAttribute('target'),
          })),
          classic: Array.from(document.querySelectorAll('a[href]')).map(pathOf).filter((path) => path.startsWith('/csp/sys/')),
          cards: document.querySelectorAll('.ocu-classic-link-card').length,
        };
      });
      assert.ok(seen.cells.length > 0, `${tab.label}: at least one name cell is an anchor`);
      for (const cell of seen.cells) {
        assert.ok(cell.path.startsWith(`/ocupilot/${tab.route}/edit`), `${tab.label}: the name cell opens the tab's editor, not ${cell.path}`);
        assert.equal(cell.target, null, `${tab.label}: in this tab`);
      }
      assert.deepEqual(seen.classic, [], `${tab.label}: nothing on the screen links to the classic portal`);
      assert.equal(seen.cards, 0, `${tab.label}: and no classic-link card renders`);
    } finally {
      await context.close();
    }
  }
});

test('AC5: with the Resource servers pairs alone the Security rail item is gated on the wallet pair, Resource servers reads under a strip whose server tabs are gated and focusable, and Server client descriptions is refused by name', async () => {
  const walletRequires = formatRequires(STRINGS.privilegeRequiresResource, '%Admin_Wallet:USE');
  const resources = TABS[2];
  const { context, page, reads } = await signedInAt(urlOf(resources.route), SECURE_USER, PASSWORD);
  try {
    await atTab(page, resources);
    assert.deepEqual(reads, [resources.read], 'the Resource servers deep link reads, once');

    const rail = await page.evaluate((label) => {
      const item = document.querySelector(`.ocu-rail-item[aria-label="${label}"]`);
      return { disabled: item.getAttribute('aria-disabled'), tip: document.getElementById(item.getAttribute('aria-describedby'))?.textContent.trim() };
    }, STRINGS.navAreaSecurity);
    assert.deepEqual(rail, { disabled: 'true', tip: walletRequires }, 'the Security rail item is gated naming %Admin_Wallet:USE');

    const strip = await stripOf(page);
    assert.deepEqual(
      strip.map((entry) => [entry.label, entry.disabled, entry.reason]),
      [
        [TABS[0].label, 'false', null],
        [TABS[1].label, 'false', null],
        [TABS[2].label, 'false', null],
        [TABS[3].label, 'true', 'Requires %Admin_OAuth2_Server:USE'],
        [TABS[4].label, 'true', 'Requires %Admin_OAuth2_Registration:USE'],
      ],
      'the two server tabs are gated, each naming its pair'
    );
    await page.focus('app-detail-page .ocu-detail-tab:nth-child(3)');
    await page.keyboard.press('ArrowRight');
    const focused = await page.evaluate(() => document.activeElement?.querySelector('.ocu-detail-tab-label')?.textContent.trim() ?? null);
    assert.equal(focused, TABS[3].label, 'a gated tab takes focus');
    await page.keyboard.press('Enter');
    await new Promise((resolve) => setTimeout(resolve, 500));
    assert.equal(new URL(page.url()).pathname, `/ocupilot/${resources.route}`, 'and opens nothing');
    assert.deepEqual(reads, [resources.read], 'and reads nothing');
  } finally {
    await context.close();
  }

  const serverClients = TABS[4];
  const denied = await signedInAt(urlOf(serverClients.route), SECURE_USER, PASSWORD);
  try {
    await denied.page.waitForSelector('app-screen-denied .ocu-screen-denied-title', { timeout: config.navigationTimeoutMs });
    const refusal = await denied.page.evaluate(() => ({
      title: document.querySelector('app-screen-denied .ocu-screen-denied-title').textContent.trim(),
      reason: document.querySelector('app-screen-denied .ocu-screen-denied-reason').textContent.trim(),
      grid: document.querySelector('[role="grid"]') !== null,
    }));
    assert.equal(refusal.title, serverClients.label, 'the deep link renders the tab title');
    assert.equal(refusal.reason, formatDeniedScreen(STRINGS.privilegeDeniedScreen, '%Admin_OAuth2_Registration:USE', serverClients.label));
    assert.equal(refusal.reason, 'You need %Admin_OAuth2_Registration:USE to open Server client descriptions.');
    assert.equal(refusal.grid, false, 'with no table');
    assert.deepEqual(denied.reads, [], 'and no read');
  } finally {
    await denied.context.close();
  }
});

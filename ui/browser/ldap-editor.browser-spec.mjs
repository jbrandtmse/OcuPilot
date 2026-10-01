/**
 * Story 16.14 in a real browser, against the throwaway instance: the LDAP and Kerberos editor (AD-5,
 * AD-55).
 *
 * What it pins, each on rendered DOM, on the real URL or on the instance itself:
 *
 * 1. **An LDAP / Kerberos row's name opens the editor**, on General, Groups and Attributes, with the
 *    Kerberos pair (Kerberos authentication is on in the throwaway) and no classic-portal card (AC1).
 * 2. **A field and a flag are saved**: Description and Use TLS/SSL, each read back inside the
 *    container (Integration).
 * 3. **The search password is entered, then cleared**, each read back by presence alone (AC5).
 * 4. **Create from the command bar, then Delete from the row**, the name typed (AC6, AC7).
 * 5. **Test authentication shows the instance's own lines** for a probe pointing at an unreachable
 *    host (AC3).
 * 6. **The list reads Enabled from the flags** (AC9, DW-1639).
 * 7. **The DW-1337 structural walk** of the editor at an id route, each tab in turn, in both themes.
 *
 * **It runs only in a throwaway** (`-ci`), and writes only `ocup99*` configurations through
 * `OcuPilot.Test.ServiceLdapProbe`, armed by `OCUPILOT_ALLOW_SERVICE_CONFIG`; every leg that writes
 * makes its probe again first, and `after` removes every probe. Its passwords are obviously fake.
 *
 * Run: `node --test --test-concurrency=1 browser/ldap-editor.browser-spec.mjs` (after `npm run
 * build`, the bundle copied into the throwaway, and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { saveAndSettle, signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const PROBE_CLASS = 'OcuPilot.Test.ServiceLdapProbe';
const LIST_ROUTE = 'security/ldap';
const ROUTE = 'security/ldap/edit';
const LIST_URL = `/ocupilot/${LIST_ROUTE}?ns=HSCUSTOM`;
const ACTION_PATH = '/api/ocupilot/screens/security.ldap/action';
const PROBE = 'ocup99browser.invalid';
const CREATED = 'ocup99created.invalid';
/** An unreachable host, so a test answers the instance's own failure lines quickly. */
const UNREACHABLE = '127.0.0.1:1';
/** An obviously fake search password; it is never printed. */
const FAKE_PASSWORD = 'ocup99-fake-search-password';

const NAME_TEXT = '.ocu-data-table-link, .ocu-data-table-text';

let browser = null;

/** The editor's address for configuration `name`: its id encoded twice for the route (AD-13). */
const editUrl = (name) => `/ocupilot/${ROUTE}/${encodeURIComponent(encodeURIComponent(name).replaceAll('.', '%2E'))}?ns=HSCUSTOM`;

/** Make probe `name` again with `flags` and `host`, through the probe class. */
function makeProbe(name, flags, host) {
  const output = runIris(config.container, [
    `Set sc=##class(${PROBE_CLASS}).CreateLdap("${name}",${flags},"${host}")`,
    'Write "OCU-MADE-START:"_$Select($System.Status.IsOK(sc):"ok",1:$System.Status.GetErrorText(sc))_":OCU-MADE-END",!',
  ]);
  assert.equal(markerValue(output, 'MADE'), 'ok', `${name} is made (is OCUPILOT_ALLOW_SERVICE_CONFIG set?): ${output}`);
}

/** Remove every probe configuration. */
function removeProbes() {
  const output = runIris(config.container, [
    `Set sc=##class(${PROBE_CLASS}).RemoveAll()`,
    'Write "OCU-GONE-START:"_$Select($System.Status.IsOK(sc):"ok",1:$System.Status.GetErrorText(sc))_":OCU-GONE-END",!',
  ]);
  assert.equal(markerValue(output, 'GONE'), 'ok', `the probes are removed: ${output}`);
}

/** The vendor's read of configuration `name`, parsed, or null when it is absent. */
function readBack(name) {
  const output = runIris(config.container, [
    `Set sc=##class(${PROBE_CLASS}).Read("${name}",.read,"Security.LDAP")`,
    'Write "OCU-READ-START:"_$Select($IsObject($Get(read)):read.%ToJSON(),1:"")_":OCU-READ-END",!',
  ]);
  const value = markerValue(output, 'READ');
  assert.notEqual(value, null, `${name} is read: ${output}`);
  return value === '' ? null : JSON.parse(value);
}

/** Whether configuration `name` holds a search password, read by presence alone. */
function passwordSet(name) {
  const output = runIris(config.container, [`Write "OCU-PW-START:"_##class(${PROBE_CLASS}).LdapPasswordSet("${name}")_":OCU-PW-END",!`]);
  const value = markerValue(output, 'PW');
  assert.ok(value === '0' || value === '1', `the password's presence is read for ${name}`);
  return value === '1';
}

/** Whether configuration `name` exists. */
function exists(name) {
  const output = runIris(config.container, [`Write "OCU-HAS-START:"_##class(${PROBE_CLASS}).LdapExists("${name}")_":OCU-HAS-END",!`]);
  return markerValue(output, 'HAS') === '1';
}

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/** Wait until no CSS transition is running, so a read is not taken mid-transition. */
function transitionsSettled(page) {
  return page.waitForFunction(
    () => document.getAnimations().every((animation) => !(animation instanceof CSSTransition) || animation.playState !== 'running'),
    { timeout: config.navigationTimeoutMs }
  );
}

/** Signed in at `url`, recording every write to the LDAP routes and the screen action route; the bodies are kept, never printed. */
async function signedIn(url) {
  const { context, page } = await signedInAt(browser, config, url, VIEWPORTS.wide);
  const writes = [];
  page.on('request', (request) => {
    const path = new URL(request.url()).pathname;
    if ((path.startsWith('/api/ocupilot/ldap') || path === ACTION_PATH) && request.method() !== 'GET') {
      writes.push({ method: request.method(), path, body: request.postData() ?? '' });
    }
  });
  return { context, page, writes };
}

/** Wait until the editor holds its read. */
async function editorReady(page) {
  await page.waitForSelector('app-ldap-editor-page app-form-tabs', { timeout: config.navigationTimeoutMs });
}

function tabLabels(page) {
  return page.$$eval('app-ldap-editor-page [role="tab"] .ocu-form-tab-label', (tabs) => tabs.map((tab) => tab.textContent.trim()));
}

async function openTab(page, key) {
  await page.click(`app-ldap-editor-page [role="tab"][data-tab="${key}"]`);
  await page.waitForSelector(`app-ldap-editor-page [data-tab-body="${key}"]:not([hidden])`, { timeout: config.navigationTimeoutMs });
}

/** Wait until the path ends with `suffix`. */
function pathEnds(page, suffix) {
  return page.waitForFunction((wanted) => new URL(window.location.href).pathname.endsWith(wanted), { timeout: config.navigationTimeoutMs }, suffix);
}

/** Narrow the list to `name` and wait for its one row, answering its cells. */
async function listedRow(page, name) {
  await waitForRows(page, config.navigationTimeoutMs);
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, name);
  await page.waitForFunction(
    (selector, wanted, textSelector) =>
      Array.from(document.querySelectorAll(selector)).some((row) => {
        const cell = row.querySelector('[role="gridcell"]');
        return ((cell?.querySelector(textSelector) ?? cell)?.textContent ?? '').trim() === wanted;
      }),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name,
    NAME_TEXT
  );
  return page.evaluate(
    (selector, wanted) => {
      const row = Array.from(document.querySelectorAll(selector)).find((node) => node.textContent.includes(wanted));
      return Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim());
    },
    ROW_SELECTOR,
    name
  );
}

/** The column headers of the list, in order. */
function headers(page) {
  return page.$$eval('[role="columnheader"]', (cells) => cells.map((cell) => cell.textContent.trim()));
}

/**
 * Press the editor's control `selector` with the pointer, once it is brought clear of the sticky form
 * bar. The editor scrolls inside itself under that bar (DW-1596), and a control lying in the scroll
 * port beneath the bar takes no scroll from a click, which then lands on the bar. Where a control
 * lies depends on the fonts and on whether the stale-bundle notice stands above the form (it does on
 * a throwaway whose bundle was copied in after its install), so the point is checked to hit the
 * control before it is pressed.
 */
async function press(page, selector) {
  await page.waitForSelector(selector, { visible: true, timeout: config.navigationTimeoutMs });
  await page.$eval(selector, (node) => node.scrollIntoView({ block: 'center' }));
  const hit = await page.$eval(selector, (node) => {
    const box = node.getBoundingClientRect();
    const at = document.elementFromPoint(box.left + box.width / 2, box.top + box.height / 2);
    return at !== null && (at === node || node.contains(at) || Array.from(node.labels ?? []).some((label) => label.contains(at)));
  });
  assert.ok(hit, `${selector} is clear of the form bar before it is pressed`);
  await page.click(selector);
}

/** Clear the field `selector` and type `text` into it. */
async function retype(page, selector, text) {
  await page.click(selector, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  if (text !== '') await page.type(selector, text);
}

/**
 * The DW-1337 walk of the editor at 1280 light, 720 light and 1280 dark with each of its tabs
 * showing, answering every entry the baseline does not already hold.
 */
async function structural(page, tabs) {
  const found = [];
  const passes = [
    { viewport: VIEWPORTS.wide, theme: 'light', checks: INVARIANTS },
    { viewport: VIEWPORTS.narrow, theme: 'light', checks: ['name', 'min-width', 'overflow'] },
    { viewport: VIEWPORTS.wide, theme: 'dark', checks: ['contrast'] },
  ];
  const minimums = componentMinimums();
  const surfaces = {};
  for (const tab of tabs) {
    await openTab(page, tab);
    if (tab === 'groups' && (await page.$('#ocu-ldap-advanced')) === null) await press(page, 'app-ldap-editor-page .ocu-form-disclosure');
    for (const { viewport, theme, checks } of passes) {
      await page.setViewport(viewport);
      await page.evaluate((dark) => document.documentElement.classList.toggle('ocu-theme-dark', dark), theme === 'dark');
      await frames(page);
      await transitionsSettled(page);
      surfaces[theme] = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
      const { entries } = await detectScreen(page, { route: ROUTE, checks, viewport: viewport.width, theme, minimums });
      found.push(...entries);
    }
    await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
    await page.setViewport(VIEWPORTS.wide);
    await frames(page);
  }
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  return compare(collapse(found), readBaseline()?.entries ?? []).fresh.map((entry) => `${entry.key}: ${entry.measured}`);
}

before(async () => {
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec creates and deletes LDAP configurations, so it runs only in a throwaway; ${config.container} is not one`);
  removeProbes();
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (/-ci$/.test(config.container)) removeProbes();
  } finally {
    if (browser !== null) await browser.close();
  }
});

test('AC1, AC9: a row reads Enabled from the flags, and its name opens the editor on three tabs with the Kerberos pair and no classic card', async () => {
  // Mutation (Rule 19): draw the Groups tab only while `kerberos` is false, rebuild and redeploy -> the tab list goes red.
  makeProbe(PROBE, 72, UNREACHABLE);
  const { context, page } = await signedIn(LIST_URL);
  try {
    const cells = await listedRow(page, PROBE);
    const enabled = (await headers(page)).indexOf(STRINGS.tableColumnEnabled);
    assert.ok(enabled >= 0, 'the list has an Enabled column');
    assert.equal(cells[enabled], STRINGS.tableStatusYes, 'an enabled configuration reads Enabled Yes (DW-1639)');
    await clickRowCentre(page, { text: PROBE, link: true });
    await pathEnds(page, `/${ROUTE}/ocup99browser%252Einvalid`);
    await editorReady(page);
    assert.deepEqual(await tabLabels(page), [STRINGS.processDetailsGroupGeneral, STRINGS.ldapTabGroups, STRINGS.ldapTabAttributes]);
    assert.equal(await page.$eval('#ocu-ldap-Name', (node) => node.readOnly && node.value), PROBE, 'the name is read from the instance, read-only');
    assert.equal(await page.$eval('#ocu-ldap-kerberos', (node) => node.checked && node.disabled), true, 'Kerberos configuration is checked and unavailable');
    assert.equal(await page.$eval('#ocu-ldap-ldap-configuration', (node) => node.checked), true, 'and LDAP configuration is ticked');
    assert.equal(await page.$eval('#ocu-ldap-LDAPCACertFile', (node) => node.readOnly), true, 'the CA certificate file is text');
    assert.equal(await page.$('app-classic-link-card, .ocu-classic-link-card'), null, 'and no classic-portal card is drawn');
  } finally {
    await context.close();
  }
});

test('Integration: a description and a flag are saved and read back, and the list shows the change', async () => {
  makeProbe(PROBE, 72, UNREACHABLE);
  const { context, page, writes } = await signedIn(editUrl(PROBE));
  try {
    await editorReady(page);
    await retype(page, '#ocu-ldap-Description', 'browser save');
    await press(page, '#ocu-ldap-flag-2');
    await saveAndSettle(page, config);
    assert.deepEqual(
      writes.map((write) => [write.method, write.path, JSON.parse(write.body)]),
      [['PUT', '/api/ocupilot/ldap/ocup99browser%252Einvalid', { Description: 'browser save', LDAPFlags: 74 }]]
    );
    const after = readBack(PROBE);
    assert.equal(after.Description, 'browser save', 'the instance holds the description');
    assert.equal(after.LDAPFlags, 74, 'and the TLS bit beside the bits it had');
    assert.deepEqual(after.LDAPHostNames, [UNREACHABLE], 'and keeps the host names');
    await page.click('app-ldap-editor-page .ocu-form-bar-actions .ocu-button-text');
    await pathEnds(page, `/${LIST_ROUTE}`);
    assert.ok((await listedRow(page, PROBE)).includes('browser save'), 'the list shows the description');
  } finally {
    await context.close();
  }
});

test('AC5: a search password is entered, then cleared, each read back by presence alone', async () => {
  makeProbe(PROBE, 72, UNREACHABLE);
  assert.equal(passwordSet(PROBE), false, 'the probe starts with no password');
  const { context, page, writes } = await signedIn(editUrl(PROBE));
  try {
    await editorReady(page);
    await press(page, '#ocu-ldap-LDAPSearchPassword-enter');
    await page.waitForSelector('#ocu-ldap-password', { visible: true, timeout: config.navigationTimeoutMs });
    await page.type('#ocu-ldap-password', FAKE_PASSWORD);
    await page.type('#ocu-ldap-password-confirm', FAKE_PASSWORD);
    await saveAndSettle(page, config);
    assert.equal(writes.length, 1, 'one Save was sent');
    assert.deepEqual(Object.keys(JSON.parse(writes[0].body)), ['LDAPSearchPassword'], 'carrying the password alone');
    assert.equal(passwordSet(PROBE), true, 'the instance holds a password');
    assert.equal(await page.$eval('#ocu-ldap-LDAPSearchPassword-leave', (node) => node.checked), true, 'and the form is back to Leave as is');
    await press(page, '#ocu-ldap-LDAPSearchPassword-clear');
    await saveAndSettle(page, config);
    assert.equal(writes.length, 2, 'a second Save was sent');
    assert.equal(JSON.parse(writes[1].body).LDAPSearchPassword, '', 'carrying an empty password');
    assert.equal(passwordSet(PROBE), false, 'and the instance holds none');
  } finally {
    await context.close();
  }
});

test('AC6, AC7: Create from the command bar saves a configuration under its stored name, and Delete from its row removes it', async () => {
  const { context, page, writes } = await signedIn(LIST_URL);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await (await page.waitForSelector('.ocu-command-bar button.ocu-button-primary', { visible: true, timeout: config.navigationTimeoutMs })).click();
    await pathEnds(page, `/${ROUTE}`);
    await page.waitForSelector('#ocu-ldap-Name:not([readonly])', { visible: true, timeout: config.navigationTimeoutMs });
    await page.type('#ocu-ldap-Name', CREATED);
    await page.focus('#ocu-ldap-Description');
    await page.waitForFunction(() => document.querySelector('#ocu-ldap-LDAPBaseDN')?.value === 'DC=ocup99created,DC=invalid', { timeout: config.navigationTimeoutMs });
    await page.type('#ocu-ldap-LDAPHostNames', UNREACHABLE);
    await press(page, '[data-action="add-host"]');
    await page.type('#ocu-ldap-LDAPSearchUsername', 'CN=ocup99,DC=ocup99created,DC=invalid');
    await saveAndSettle(page, config);
    await pathEnds(page, `/${ROUTE}/ocup99created%252Einvalid`);
    const posted = writes.filter((write) => write.method === 'POST' && write.path === '/api/ocupilot/ldap').map((write) => JSON.parse(write.body));
    assert.equal(posted.length, 1, 'one create was sent');
    assert.equal(posted[0].Name, CREATED, 'naming the configuration');
    assert.equal(exists(CREATED), true, 'the instance holds it');
    assert.deepEqual(readBack(CREATED).LDAPHostNames, [UNREACHABLE], 'with its host');

    await page.click('app-ldap-editor-page .ocu-form-bar-actions .ocu-button-text');
    await pathEnds(page, `/${LIST_ROUTE}`);
    await listedRow(page, CREATED);
    await clickRowCentre(page, { text: CREATED, cell: 2 });
    await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
    await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
    await page.evaluate((label) => {
      Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'))
        .find((item) => item.textContent.trim().startsWith(label))
        .click();
    }, STRINGS.actionDelete);
    await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-typed-name-consequence', (node) => node.textContent.trim()), STRINGS.ldapDeleteConsequence);
    await page.type('.ocu-typed-name-field', CREATED);
    await page.keyboard.press('Enter');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await page.waitForFunction((selector, name) => !Array.from(document.querySelectorAll(selector)).some((row) => row.textContent.includes(name)), { timeout: config.navigationTimeoutMs }, ROW_SELECTOR, CREATED);
    const actions = writes.filter((write) => write.path === ACTION_PATH).map((write) => JSON.parse(write.body));
    assert.deepEqual(actions, [{ action: 'delete', id: CREATED }], 'one delete, sent once the name matched');
    assert.equal(exists(CREATED), false, 'the instance no longer holds it');
  } finally {
    await context.close();
  }
});

test('AC3: Test authentication shows the instance\u2019s own lines for a configuration whose host cannot be reached', async () => {
  makeProbe(PROBE, 72, UNREACHABLE);
  const { context, page } = await signedIn(editUrl(PROBE));
  try {
    await editorReady(page);
    await press(page, '[data-action="ldap-test"]');
    await page.waitForSelector('app-ldap-test-dialog [role="dialog"]', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('app-ldap-test-dialog .ocu-dialog-title', (node) => node.textContent.trim()), STRINGS.ldapTestAction);
    await page.type('#ocu-ldap-test-user', 'ocup99user');
    await page.type('#ocu-ldap-test-password', FAKE_PASSWORD);
    await page.click('[data-action="ldap-test-run"]');
    await page.waitForSelector('app-ldap-test-dialog [data-test-output]', { timeout: config.navigationTimeoutMs });
    const lines = await page.$$eval('app-ldap-test-dialog .ocu-ssl-test-lines li', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.ok(lines.length > 0, 'the dialog shows lines');
    assert.ok(lines.some((line) => line.includes('Test completed')), `the instance's own text: ${JSON.stringify(lines)}`);
    await page.click('app-ldap-test-dialog .ocu-dialog-actions .ocu-button-secondary');
    await page.waitForFunction(() => document.querySelector('app-ldap-test-dialog') === null, { timeout: config.navigationTimeoutMs });
  } finally {
    await context.close();
  }
});

test('DW-1337: the editor passes the structural walk at an id route with each tab showing, in both themes', async () => {
  makeProbe(PROBE, 72, UNREACHABLE);
  const { context, page } = await signedIn(editUrl(PROBE));
  try {
    await editorReady(page);
    assert.deepEqual(await structural(page, ['general', 'groups', 'attributes']), [], 'no violation beyond the baseline with the editor showing');
  } finally {
    await context.close();
  }
});

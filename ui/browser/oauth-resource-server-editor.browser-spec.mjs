/**
 * Story 12.6 in a real browser, against the throwaway instance: the OAuth 2.0 resource server editor
 * at `security/oauth/resource-servers/edit`, reached from the Resource servers tab.
 *
 * What it pins, each on rendered DOM, on the real URL or on the instance itself:
 *
 * 1. **Create** (AC1, AC11): the tab's Create opens the editor in four tabs with the two default
 *    mappings on an instance that holds no resource server, every tab passes DW-1337, and Save
 *    replaces the route with the server's own and stores the fields and both mappings.
 * 2. **Edit and secret** (AC2, AC4): the tab's name cell opens the editor with the secret masked and
 *    empty; turning JWT off turns introspection on, and the description, client ID and typed secret
 *    reach the instance.
 * 3. **Authenticator** (AC6): another namespace's class is chosen, its credential-named setting is
 *    never drawn, and its ordinary setting reaches the instance.
 * 4. **Mappings** (AC5): a key another server holds shows the move sentence, the Save moves it here,
 *    and a removed row leaves the instance.
 * 5. **Delete from the row menu** (AC3, AC11): the editor's delete dialog passes DW-1337, the row menu
 *    offers the one declared action, and the typed name deletes the server and its mappings.
 *
 * **It refuses the live container**, and needs the demo fixture's SSL/TLS configuration. Every probe
 * object is removed by exact name before and after (`OcuPilot.Test.OAuthResourceServerProbe`).
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test
 * browser/oauth-resource-server-editor.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { saveAndSettle, signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));
const { encodeEntityId } = await import(join(uiRoot, 'src', 'app', 'core', 'entity-id.ts'));

const config = browserConfig();

/** This spec's server, the other server that holds a mapping it moves, and the description both trust. */
const NAME = 'OcuPilotProbe126Browser';
const OTHER = 'OcuPilotProbe126Holder';
const ISSUER = 'https://ocupilotprobe126.invalid/browser';
const AUDIENCE = 'https://ocupilotprobe126.invalid/api';
const MOVED_KEY = '/csp/user';
const CLIENT_ID = 'ocupilotprobe126client';
const SECRET = 'ocupilotbrowserprobe126secret';
const PROBE_AUTHENTICATOR = 'OcuPilot.Test.OAuthProbeAuthenticator';
const TAB_ROUTE = 'security/oauth/resource-servers';
const EDITOR_ROUTE = 'security/oauth/resource-servers/edit';
const TAB_URL = `/ocupilot/${TAB_ROUTE}?ns=HSCUSTOM`;
const EDIT_URL = `/ocupilot/${EDITOR_ROUTE}/${encodeEntityId(NAME)}?ns=HSCUSTOM`;
const ACTION_PATH = '/api/ocupilot/screens/security.oauthresourceservers/action';
const ID = 'ocu-oauth-resource-server';
const PROBE = 'OcuPilot.Test.OAuthResourceServerProbe';

/** The editor's four tabs, in order. */
const TAB_KEYS = ['general', 'token', 'authenticator', 'mappings'];

let browser = null;

/** The namespace the probe authenticator is compiled in. */
let probeNamespace = '';

/** Run ObjectScript in `iris session` inside the throwaway, in HSCUSTOM, and read back the named markers. */
function irisSession(lines, names = []) {
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', 'HSCUSTOM'], {
    input: `${[...lines, 'Halt'].join('\n')}\n`,
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

/** The instance's own read of the server, the secret as its length, or `null` when it holds none. */
function stored() {
  const { values } = irisSession([`Set tStored=##class(${PROBE}).Stored("${NAME}")`, mark('STORED', '$Select($IsObject(tStored):tStored.%ToJSON(),1:"")')], ['STORED']);
  return values.STORED === '' || values.STORED === null ? null : JSON.parse(values.STORED);
}

/** The server's mappings as the instance holds them, sorted and comma-separated. */
function mappingsOf(name) {
  return irisSession([mark('MAPS', `##class(${PROBE}).MappingsOf("${name}")`)], ['MAPS']).values.MAPS;
}

function removeAll() {
  const { values, output } = irisSession([`Set tSC=##class(${PROBE}).RemoveAll(.tLeft)`, mark('LEFT', '$System.Status.IsOK(tSC)_"/"_tLeft')], ['LEFT']);
  assert.equal(values.LEFT, '1/0', `every probe object is removed:\n${output}`);
}

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/**
 * Wait until no CSS transition is running: a tab label's color eases between themes, so a contrast
 * read taken mid-transition measures the theme it is leaving.
 */
function transitionsSettled(page) {
  return page.waitForFunction(
    () => document.getAnimations().every((animation) => !(animation instanceof CSSTransition) || animation.playState !== 'running'),
    { timeout: config.navigationTimeoutMs }
  );
}

/** The baseline's allowance for this route: the shell's own DW-1583 and DW-1584 entries alone. */
function shellAllowance() {
  return (readBaseline()?.entries ?? []).filter((entry) => entry.route === EDITOR_ROUTE && (entry.dw === 'DW-1583' || entry.dw === 'DW-1584'));
}

/**
 * DW-1337: 1280 light (every invariant), 720 light and 1280 dark, compared against the shell's
 * allowance alone, and, with a dialog open, the dialog body's own sideways overflow.
 */
async function assertStructure(page, dialog = false) {
  const found = [];
  const passes = [
    { viewport: VIEWPORTS.wide, theme: 'light', checks: INVARIANTS },
    { viewport: VIEWPORTS.narrow, theme: 'light', checks: ['name', 'min-width', 'overflow'] },
    { viewport: VIEWPORTS.wide, theme: 'dark', checks: ['contrast'] },
  ];
  const minimums = componentMinimums();
  const surfaces = {};
  for (const { viewport, theme, checks } of passes) {
    await page.setViewport(viewport);
    await page.evaluate((dark) => document.documentElement.classList.toggle('ocu-theme-dark', dark), theme === 'dark');
    await frames(page);
    await transitionsSettled(page);
    surfaces[theme] = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
    const { entries } = await detectScreen(page, { route: EDITOR_ROUTE, checks, viewport: viewport.width, theme, minimums });
    found.push(...entries);
    if (!dialog) continue;
    const body = await page.$eval('.ocu-dialog-body', (element) => ({ scroll: element.scrollWidth, client: element.clientWidth }));
    assert.ok(body.scroll <= body.client, `the dialog body does not scroll sideways at ${viewport.width}px ${theme}: ${JSON.stringify(body)}`);
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await frames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  const fresh = compare(collapse(found), shellAllowance()).fresh;
  assert.deepEqual(fresh.map((entry) => `${entry.key}: ${entry.measured}`), [], 'no structural or contrast violation on the editor');
}

/** Open the form tab keyed `key`, and wait until its body is the one shown. */
async function openTab(page, key) {
  await page.click(`[data-tab="${key}"]`);
  // `?? true`: an absent body is not shown, so the wait holds until the tab's body has rendered.
  await page.waitForFunction((tab) => !(document.querySelector(`[data-tab-body="${tab}"]`)?.hidden ?? true), { timeout: config.navigationTimeoutMs }, key);
}

/** Open the tab that holds form control `id`. */
async function openTabOf(page, id) {
  await page.waitForSelector(`#${id}`, { timeout: config.navigationTimeoutMs });
  const key = await page.$eval(`#${id}`, (node) => node.closest('[data-tab-body]')?.getAttribute('data-tab-body') ?? '');
  if (key !== '') await openTab(page, key);
}

/** Type `value` into the form control `id`, replacing whatever is there, its tab opened first. */
async function fill(page, id, value) {
  await openTabOf(page, id);
  await page.waitForSelector(`#${id}`, { visible: true, timeout: config.navigationTimeoutMs });
  await page.click(`#${id}`, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  if (value !== '') await page.type(`#${id}`, value);
}

/** Choose `value` in select `id`, its tab opened first, once the select offers it. */
async function choose(page, id, value) {
  await openTabOf(page, id);
  // `?? false`: an absent select offers nothing, so the wait holds until it renders with the option.
  await page.waitForFunction(
    (selector, wanted) => Array.from(document.querySelector(selector)?.options ?? []).some((option) => option.value === wanted),
    { timeout: config.navigationTimeoutMs },
    `#${id}`,
    value
  );
  await page.select(`#${id}`, value);
}

/** Click the form bar button labelled `label`. */
async function barButton(page, label) {
  await page.waitForFunction(
    (text) => Array.from(document.querySelectorAll('.ocu-form-bar-actions button')).some((button) => button.textContent.trim() === text),
    { timeout: config.navigationTimeoutMs },
    label
  );
  await page.evaluate((text) => {
    Array.from(document.querySelectorAll('.ocu-form-bar-actions button')).find((button) => button.textContent.trim() === text).click();
  }, label);
}

async function statusLine(page, text, timeout = config.navigationTimeoutMs) {
  await page.waitForFunction(
    (expected) => document.querySelector('.ocu-form-bar-status [role="status"]')?.textContent?.trim() === expected,
    { timeout },
    text
  );
}

/** Wait until the edit's form read has rendered the server's name. */
async function editLoaded(page) {
  // `?? ''`: an absent field is not loaded, so the wait holds until the form read has rendered it.
  await page.waitForFunction((id) => (document.querySelector(`#${id}-Name`)?.value ?? '') !== '', { timeout: config.navigationTimeoutMs }, ID);
}

/** The keys a mapping table draws, each with its move sentence when it has one. */
function mappingRows(page, table) {
  return page.$$eval(`#${ID}-${table}-mappings tbody tr td:first-child`, (cells) =>
    cells.map((cell) => Array.from(cell.querySelectorAll('span')).map((span) => span.textContent.trim()).join(' '))
  );
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates and deletes OAuth 2.0 configuration, so it never runs inside the live container');
  await assertThrowaway(config);
  removeAll();
  const made = irisSession(
    [`Set tSC=##class(${PROBE}).AddServer("${ISSUER}")`, mark('MADE', '$System.Status.IsOK(tSC)'), mark('NS', `##class(${PROBE}).Namespace()`)],
    ['MADE', 'NS']
  );
  assert.equal(made.values.MADE, '1', `the server description is made:\n${made.output}`);
  probeNamespace = made.values.NS;
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  removeAll();
});

// AC1, AC11. Mutation (Rule 19), over a rebuilt and redeployed bundle: give
// `.ocu-oauth-resource-server-mappings` a 1400px min-inline-size -> the structural assertion goes red.
test('AC1, AC11: Create opens the editor in four tabs with the default mappings, and Save stores the fields and both mappings', async () => {
  const { values } = irisSession(
    ['Set $NAMESPACE="%SYS",tR=##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) FROM OAuth2.ResourceServer"),tN=$Select(tR.%Next():tR.%GetData(1),1:-1)', mark('COUNT', 'tN')],
    ['COUNT']
  );
  assert.equal(values.COUNT, '0', 'the instance holds no resource server, so this create is a first one');
  const { context, page } = await signedInAt(browser, config, TAB_URL, VIEWPORTS.wide);
  try {
    const create = await page.waitForSelector('.ocu-command-bar button.ocu-button-primary', { visible: true, timeout: config.navigationTimeoutMs });
    await create.click();
    await page.waitForFunction((route) => new URL(window.location.href).pathname.endsWith(`/${route}`), { timeout: config.navigationTimeoutMs }, EDITOR_ROUTE);
    await page.waitForSelector(`#${ID}-Name`, { visible: true, timeout: config.navigationTimeoutMs });
    const tabs = await page.$$eval('[role="tab"] .ocu-form-tab-label', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(tabs, [
      STRINGS.processDetailsGroupGeneral,
      STRINGS.oauthResourceServerTabToken,
      STRINGS.oauthResourceServerTabAuthenticator,
      STRINGS.oauthResourceServerTabMappings,
    ]);
    for (const key of TAB_KEYS) {
      await openTab(page, key);
      await assertStructure(page);
    }
    assert.deepEqual(await mappingRows(page, 'gateway'), [STRINGS.oauthResourceServerDefaultKey], 'the Web Gateway default mapping is offered');
    assert.deepEqual(await mappingRows(page, 'bindings'), [STRINGS.oauthResourceServerDefaultKey], 'and the ODBC/JDBC one');

    await fill(page, `${ID}-Name`, NAME);
    await choose(page, `${ID}-IssuerEndpoint`, ISSUER);
    await page.click(`#${ID}-add-audience`);
    await fill(page, `${ID}-Audiences-1`, AUDIENCE);
    await saveAndSettle(page, config);
    await statusLine(page, STRINGS.formSaved);
    await page.waitForFunction((suffix) => new URL(window.location.href).pathname.endsWith(suffix), { timeout: config.navigationTimeoutMs }, `/${EDITOR_ROUTE}/${encodeEntityId(NAME)}`);
    const held = stored();
    assert.ok(held !== null, 'the instance holds the server');
    assert.deepEqual([held.IssuerEndpoint, held.Audiences], [ISSUER, [AUDIENCE]]);
    assert.equal(mappingsOf(NAME), '%Service_Bindings/*,%Service_WebGateway/*', 'and both default mappings');
  } finally {
    await context.close();
  }
});

test("AC2, AC4: the tab's name cell opens the editor with the secret masked and empty, and JWT off stores introspection, the client ID and the secret", async () => {
  const { context, page } = await signedInAt(browser, config, TAB_URL, VIEWPORTS.wide);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await clickRowCentre(page, { text: NAME, link: true });
    await page.waitForFunction((suffix) => new URL(window.location.href).pathname.endsWith(suffix), { timeout: config.navigationTimeoutMs }, `/${EDITOR_ROUTE}/${encodeEntityId(NAME)}`);
    await editLoaded(page);
    assert.equal(await page.$eval(`#${ID}-ClientSecret`, (node) => `${node.type}|${node.value}|${node.readOnly}`), 'password||true', 'the secret is masked, empty, and locked while introspection is off');
    await fill(page, `${ID}-Description`, 'edited in the browser');
    await openTab(page, 'token');
    await page.click(`#${ID}-AccessTokenIsJWT`);
    await page.waitForFunction((id) => document.querySelector(`#${id}-AlwaysCallIntrospection`)?.checked === true, { timeout: config.navigationTimeoutMs }, ID);
    await fill(page, `${ID}-ClientId`, CLIENT_ID);
    await fill(page, `${ID}-ClientSecret`, SECRET);
    await saveAndSettle(page, config);
    await statusLine(page, STRINGS.formSaved);
    const held = stored();
    assert.deepEqual(
      [held.Description, held.AccessTokenIsJWT, held.AlwaysCallIntrospection, held.ClientId, held.SecretLength],
      ['edited in the browser', false, true, CLIENT_ID, SECRET.length]
    );
    assert.equal(await page.$eval(`#${ID}-ClientSecret`, (node) => node.value), '', 'the typed secret is forgotten');
  } finally {
    await context.close();
  }
});

test("AC6: another namespace's authenticator is chosen, its credential setting is never drawn, and its ordinary setting is stored", async () => {
  const { context, page } = await signedInAt(browser, config, EDIT_URL, VIEWPORTS.wide);
  try {
    await editLoaded(page);
    await choose(page, `${ID}-Authenticator-Namespace`, probeNamespace);
    await choose(page, `${ID}-Authenticator-Implementation`, PROBE_AUTHENTICATOR);
    await fill(page, `${ID}-Authenticator-Claim`, 'email');
    assert.equal(await page.$(`#${ID}-Authenticator-ApiKey`), null, 'the credential-named setting is not drawn');
    await saveAndSettle(page, config);
    await statusLine(page, STRINGS.formSaved);
    const held = stored();
    assert.deepEqual([held.Authenticator.Namespace, held.Authenticator.Implementation, held.Authenticator.Claim], [probeNamespace, PROBE_AUTHENTICATOR, 'email']);
  } finally {
    await context.close();
  }
});

test('AC5: a key another server holds shows the move sentence, the Save moves it here, and a removed row leaves the instance', async () => {
  const made = irisSession(
    [
      `Set tSC=##class(${PROBE}).AddResource("${OTHER}","${ISSUER}",$ListBuild("${AUDIENCE}"))`,
      `If tSC Set tSC=##class(${PROBE}).Map("%Service_WebGateway","${MOVED_KEY}","${OTHER}")`,
      mark('MADE', '$System.Status.IsOK(tSC)'),
    ],
    ['MADE']
  );
  assert.equal(made.values.MADE, '1', `the holding server and its mapping are made:\n${made.output}`);
  const { context, page } = await signedInAt(browser, config, EDIT_URL, VIEWPORTS.wide);
  try {
    await editLoaded(page);
    await choose(page, `${ID}-Mappings-Key`, MOVED_KEY);
    const move = STRINGS.oauthResourceServerMoves.split('<server>').join(OTHER);
    await page.waitForFunction((id, text) => document.querySelector(`#${id}-move`)?.textContent.trim() === text, { timeout: config.navigationTimeoutMs }, ID, move);
    await page.click(`#${ID}-add-mapping`);
    await page.waitForFunction((id) => document.querySelector(`#${id}-gateway-mappings tbody`)?.children.length === 2, { timeout: config.navigationTimeoutMs }, ID);
    assert.deepEqual(await mappingRows(page, 'gateway'), [STRINGS.oauthResourceServerDefaultKey, `${MOVED_KEY} ${move}`], 'the added row says what it moves');
    await page.$eval(`#${ID}-bindings-mappings tbody tr button`, (button) => button.click());
    await page.waitForFunction((id) => document.querySelector(`#${id}-bindings-mappings tbody`)?.children.length === 0, { timeout: config.navigationTimeoutMs }, ID);
    await saveAndSettle(page, config);
    await statusLine(page, STRINGS.formSaved);
    assert.equal(mappingsOf(NAME), `%Service_WebGateway/*,%Service_WebGateway/${MOVED_KEY}`, 'the key moved here and the removed row is gone');
    assert.equal(mappingsOf(OTHER), '', 'the other server no longer holds it');
  } finally {
    await context.close();
  }
});

test("AC3, AC11: the editor's delete dialog passes DW-1337, and the row menu's Delete removes the server and its mappings after the typed name", async () => {
  const { context, page } = await signedInAt(browser, config, EDIT_URL, VIEWPORTS.wide);
  try {
    await editLoaded(page);
    await barButton(page, STRINGS.actionDelete);
    await page.waitForSelector('[role="dialog"]', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-typed-name-consequence', (node) => node.textContent.trim()), STRINGS.oauthResourceServerDeleteConsequence);
    await assertStructure(page, true);
    await page.keyboard.press('Escape');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });

    const writes = [];
    page.on('request', (request) => {
      if (request.method() === 'POST' && request.url().includes(ACTION_PATH)) writes.push(request.postData() ?? '');
    });
    await barButton(page, STRINGS.actionCancel);
    await waitForRows(page, config.navigationTimeoutMs);
    await page.type(FILTER_SELECTOR, NAME);
    await page.waitForFunction((selector) => document.querySelectorAll(selector).length === 1, { timeout: config.navigationTimeoutMs }, ROW_SELECTOR);
    await clickRowCentre(page, { index: 0, cell: 2 });
    await page.waitForFunction((selector) => document.querySelector(selector)?.getAttribute('aria-selected') === 'true', { timeout: config.navigationTimeoutMs }, ROW_SELECTOR);
    await page.click('.ocu-data-table-trigger');
    await page.waitForSelector('[role="menu"]', { timeout: config.navigationTimeoutMs });
    const labels = await page.$$eval('[role="menu"] [role="menuitem"] .ocu-data-table-menu-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(labels, [STRINGS.actionDelete], 'the row menu offers the one declared action');
    await page.evaluate((label) => {
      Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]')).find((item) => item.textContent.trim().startsWith(label)).click();
    }, STRINGS.actionDelete);
    await page.waitForSelector('[role="dialog"]', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-dialog-title', (node) => node.textContent.trim()), `${STRINGS.actionDelete} ${NAME}`);
    await page.type('.ocu-typed-name-field', NAME);
    await page.keyboard.press('Enter');
    await page.waitForFunction((selector) => document.querySelectorAll(selector).length === 0, { timeout: 90000 }, ROW_SELECTOR);
    assert.deepEqual(writes.map((body) => JSON.parse(body)), [{ action: 'delete', id: NAME }], 'one delete, sent once the name matched');
    assert.equal(stored(), null, 'the instance no longer holds it');
    assert.equal(mappingsOf(NAME), '', 'nor its mappings');
  } finally {
    await context.close();
  }
});

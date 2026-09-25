/**
 * Story 12.7 in a real browser, against the throwaway instance: the OAuth 2.0 authorization server
 * editor at `security/oauth/server/edit`, reached from the Authorization server tab.
 *
 * What it pins, each on rendered DOM, on the real URL or on the instance itself:
 *
 * 1. **Create** (AC1, AC10): the tab's Create opens the editor in five tabs on an instance with no
 *    configuration, every tab passes DW-1337, and Save replaces the route with the issuer's own and
 *    stores what was entered.
 * 2. **Edit and password** (AC2, AC4, AC9): the tab's name cell opens the editor with the key password
 *    masked and empty; a scope removed and one added, a grant type and an interval changed, and a
 *    typed password reach the instance, and every other member reads as before.
 * 3. **Rotate Keys** (AC5): the editor reports the rotation and the key set grows.
 * 4. **Delete from the row menu** (AC3, AC10): the editor's delete dialog passes DW-1337, the row menu
 *    offers the two declared actions, and the typed issuer deletes the configuration and its client.
 *
 * **It refuses the live container.** The configuration, its clients and every probe credential are
 * removed before and after (`OcuPilot.Test.OAuthAuthorizationServerProbe`), and `/oauth2` is left as
 * found.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test
 * browser/oauth-server-editor.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { saveAndSettle, signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));
const { encodeEntityId } = await import(join(uiRoot, 'src', 'app', 'core', 'entity-id.ts'));

const config = browserConfig();

const PROBE = 'OcuPilot.Test.OAuthAuthorizationServerProbe';
const ISSUER = 'https://ocupilotprobe127.invalid/browser';
const CLIENT = 'OcuPilotProbe127BrowserClient';
const TAB_ROUTE = 'security/oauth/server';
const EDITOR_ROUTE = 'security/oauth/server/edit';
const TAB_URL = `/ocupilot/${TAB_ROUTE}?ns=HSCUSTOM`;
const EDIT_URL = `/ocupilot/${EDITOR_ROUTE}/${encodeEntityId(ISSUER)}?ns=HSCUSTOM`;
const ACTION_PATH = '/api/ocupilot/screens/security.oauthserver/action';
const ID = 'ocu-oauth-server';

/** The editor's five tabs, in order. */
const TAB_KEYS = ['general', 'scopes', 'intervals', 'jwt', 'customization'];

let browser = null;

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

/** The instance's own read of the configuration, the password as its length, or `null` when it holds none. */
function stored() {
  const { values } = irisSession([`Set tStored=##class(${PROBE}).Stored()`, mark('STORED', '$Select($IsObject(tStored):tStored.%ToJSON(),1:"")')], ['STORED']);
  return values.STORED === '' || values.STORED === null ? null : JSON.parse(values.STORED);
}

/** How many clients are registered with the instance's authorization server. */
function clientCount() {
  return Number(irisSession([mark('COUNT', `##class(${PROBE}).ClientCount()`)], ['COUNT']).values.COUNT);
}

function removeAll() {
  const { values, output } = irisSession([`Set tSC=##class(${PROBE}).RemoveAll(.tLeft)`, mark('LEFT', '$System.Status.IsOK(tSC)_"/"_tLeft')], ['LEFT']);
  assert.equal(values.LEFT, '1/0', `the configuration, its clients and every probe credential are removed:\n${output}`);
  const web = irisSession(['Set $NAMESPACE="%SYS"', mark('WEB', '##class(Security.Applications).Exists("/oauth2")')], ['WEB']);
  assert.equal(web.values.WEB, '1', 'and /oauth2 is left in place');
}

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/** Wait until no CSS transition is running, so a contrast read measures the theme it is in. */
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

/**
 * Type `value` into the form control `id`, replacing whatever is there, its tab opened first. The
 * control is reached by focus, not a click: one lying in the scroll port under the sticky form bar
 * takes no scroll from a click, which lands on the bar, while focus reaches it wherever it lies, as
 * Tab does.
 */
async function fill(page, id, value) {
  await openTabOf(page, id);
  await page.waitForSelector(`#${id}`, { visible: true, timeout: config.navigationTimeoutMs });
  await page.focus(`#${id}`);
  await page.$eval(`#${id}`, (node) => node.select());
  await page.keyboard.press('Backspace');
  if (value !== '') await page.keyboard.type(value);
}

/** Set checkbox `id` to `on`, its tab opened first, by focus and Space for the reason `fill` gives. */
async function check(page, id, on) {
  await openTabOf(page, id);
  if ((await page.$eval(`#${id}`, (node) => node.checked)) !== on) {
    await page.focus(`#${id}`);
    await page.keyboard.press('Space');
  }
  await page.waitForFunction((selector, wanted) => document.querySelector(selector)?.checked === wanted, { timeout: config.navigationTimeoutMs }, `#${id}`, on);
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

/** Wait until the edit's form read has rendered the issuer. */
async function editLoaded(page) {
  // `?? ''`: an absent field is not loaded, so the wait holds until the form read has rendered it.
  await page.waitForFunction((id) => (document.querySelector(`#${id}-IssuerEndpoint`)?.value ?? '') !== '', { timeout: config.navigationTimeoutMs }, ID);
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates and deletes the authorization server configuration, so it never runs inside the live container');
  await assertThrowaway(config);
  removeAll();
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  removeAll();
});

// AC1, AC10. Mutation (Rule 19), over a rebuilt and redeployed bundle: give `.ocu-oauth-server-scopes`
// a 1400px min-inline-size -> the structural assertion goes red.
test('AC1, AC10: Create opens the editor in five tabs, each passes DW-1337, and Save stores what was entered', async () => {
  assert.equal(stored(), null, 'the instance holds no configuration, so this is a create');
  const { context, page } = await signedInAt(browser, config, TAB_URL, VIEWPORTS.wide);
  try {
    const create = await page.waitForSelector('.ocu-command-bar button.ocu-button-primary', { visible: true, timeout: config.navigationTimeoutMs });
    await create.click();
    await page.waitForFunction((route) => new URL(window.location.href).pathname.endsWith(`/${route}`), { timeout: config.navigationTimeoutMs }, EDITOR_ROUTE);
    await page.waitForSelector(`#${ID}-IssuerEndpoint`, { visible: true, timeout: config.navigationTimeoutMs });
    const tabs = await page.$$eval('[role="tab"] .ocu-form-tab-label', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(tabs, [
      STRINGS.processDetailsGroupGeneral,
      STRINGS.oauthColumnScopes,
      STRINGS.oauthAuthServerTabIntervals,
      STRINGS.oauthClientSectionJwt,
      STRINGS.oauthAuthServerTabCustomization,
    ]);
    await openTab(page, 'scopes');
    await page.click(`#${ID}-add-scope`);
    for (const key of TAB_KEYS) {
      await openTab(page, key);
      await assertStructure(page);
    }

    await fill(page, `${ID}-IssuerEndpoint`, ISSUER);
    await fill(page, `${ID}-Description`, 'created in the browser');
    await fill(page, `${ID}-SupportedScopes-1`, 'openid');
    await fill(page, `${ID}-SupportedScopes-1-description`, 'OpenID');
    await openTab(page, 'scopes');
    await page.click(`#${ID}-add-scope`);
    await fill(page, `${ID}-SupportedScopes-2`, 'profile');
    await check(page, `${ID}-CustomizationRoles--Manager`, false);
    await saveAndSettle(page, config);
    await statusLine(page, STRINGS.formSaved);
    await page.waitForFunction((suffix) => new URL(window.location.href).pathname.endsWith(suffix), { timeout: config.navigationTimeoutMs }, `/${EDITOR_ROUTE}/${encodeEntityId(ISSUER)}`);
    const held = stored();
    assert.ok(held !== null, 'the instance holds the configuration');
    assert.deepEqual(
      [held.IssuerEndpoint, held.Description, held.SupportedScopes, held.CustomizationRoles, held.CustomizationNamespace, held.AccessTokenInterval],
      [ISSUER, 'created in the browser', 'openid,profile', '%DB_IRISSYS', '%SYS', 3600]
    );
    assert.deepEqual([held.GrantTypes, held.frontchannel_logout_supported], ['authorization_code,refresh_token', true], 'with the classic page\'s grant and logout values');
  } finally {
    await context.close();
  }
});

test("AC2, AC4, AC9: the tab's name cell opens the editor with the password masked and empty, and scopes, a grant, an interval and the password reach the instance", async () => {
  const before = stored();
  const { context, page } = await signedInAt(browser, config, TAB_URL, VIEWPORTS.wide);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await clickRowCentre(page, { text: ISSUER, link: true });
    await page.waitForFunction((suffix) => new URL(window.location.href).pathname.endsWith(suffix), { timeout: config.navigationTimeoutMs }, `/${EDITOR_ROUTE}/${encodeEntityId(ISSUER)}`);
    await editLoaded(page);
    await openTab(page, 'jwt');
    assert.equal(await page.$eval(`#${ID}-ServerPassword`, (node) => `${node.type}|${node.value}`), 'password|', 'the key password is masked and empty');

    await openTab(page, 'scopes');
    await page.$eval(`#${ID}-SupportedScopes tbody tr:nth-child(2) button`, (button) => button.click());
    await page.waitForFunction((id) => document.querySelectorAll(`#${id}-SupportedScopes tbody tr`).length === 1, { timeout: config.navigationTimeoutMs }, ID);
    await page.click(`#${ID}-add-scope`);
    await fill(page, `${ID}-SupportedScopes-2`, 'email');
    await check(page, `${ID}-Metadata-grant_types_supported-client_credentials`, true);
    await fill(page, `${ID}-AccessTokenInterval`, '1800');
    const password = `ocupilotbrowser127probe${Date.now()}`;
    await fill(page, `${ID}-ServerPassword`, password);
    await saveAndSettle(page, config);
    await statusLine(page, STRINGS.formSaved);
    const held = stored();
    assert.deepEqual(
      [held.SupportedScopes, held.GrantTypes, held.AccessTokenInterval, held.PasswordLength],
      ['email,openid', 'authorization_code,client_credentials,refresh_token', 1800, password.length]
    );
    const unchanged = { ...before, SupportedScopes: held.SupportedScopes, GrantTypes: held.GrantTypes, AccessTokenInterval: held.AccessTokenInterval, PasswordLength: held.PasswordLength };
    assert.deepEqual(held, unchanged, 'every other field and metadata member reads as before');
    await openTab(page, 'jwt');
    assert.equal(await page.$eval(`#${ID}-ServerPassword`, (node) => node.value), '', 'the typed password is forgotten');
  } finally {
    await context.close();
  }
});

test('AC5: Rotate Keys grows the key set and the editor reports it', async () => {
  const keys = stored().KeyCount;
  const { context, page } = await signedInAt(browser, config, EDIT_URL, VIEWPORTS.wide);
  try {
    await editLoaded(page);
    await barButton(page, STRINGS.oauthClientRotateKeys);
    await statusLine(page, STRINGS.oauthAuthServerRotated, 90000);
    assert.ok(stored().KeyCount > keys, `the key set grew from ${keys}`);
  } finally {
    await context.close();
  }
});

test("AC3, AC10: the editor's delete dialog passes DW-1337, and the row menu's Delete removes the configuration and its client after the typed issuer", async () => {
  const seeded = irisSession([`Set tSC=##class(${PROBE}).SeedClient("${CLIENT}",.tId)`, mark('MADE', '$System.Status.IsOK(tSC)')], ['MADE']);
  assert.equal(seeded.values.MADE, '1', `a client is registered:\n${seeded.output}`);
  assert.equal(clientCount(), 1, 'one client is registered with the server');
  const { context, page } = await signedInAt(browser, config, EDIT_URL, VIEWPORTS.wide);
  try {
    await editLoaded(page);
    await barButton(page, STRINGS.actionDelete);
    await page.waitForSelector('[role="dialog"]', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-typed-name-consequence', (node) => node.textContent.trim()), STRINGS.oauthAuthServerDeleteConsequence);
    await assertStructure(page, true);
    await page.keyboard.press('Escape');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });

    const writes = [];
    page.on('request', (request) => {
      if (request.method() === 'POST' && request.url().includes(ACTION_PATH)) writes.push(request.postData() ?? '');
    });
    await barButton(page, STRINGS.actionCancel);
    await waitForRows(page, config.navigationTimeoutMs);
    await clickRowCentre(page, { index: 0, cell: 2 });
    await page.waitForFunction((selector) => document.querySelector(selector)?.getAttribute('aria-selected') === 'true', { timeout: config.navigationTimeoutMs }, ROW_SELECTOR);
    await page.click('.ocu-data-table-trigger');
    await page.waitForSelector('[role="menu"]', { timeout: config.navigationTimeoutMs });
    const labels = await page.$$eval('[role="menu"] [role="menuitem"] .ocu-data-table-menu-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(labels, [STRINGS.actionDelete, STRINGS.oauthClientRotateKeys], 'the row menu offers the two declared actions');
    await page.evaluate((label) => {
      Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]')).find((item) => item.textContent.trim().startsWith(label)).click();
    }, STRINGS.actionDelete);
    await page.waitForSelector('[role="dialog"]', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-dialog-title', (node) => node.textContent.trim()), `${STRINGS.actionDelete} ${ISSUER}`);
    await page.type('.ocu-typed-name-field', ISSUER);
    await page.keyboard.press('Enter');
    await page.waitForFunction((selector) => document.querySelectorAll(selector).length === 0, { timeout: 90000 }, ROW_SELECTOR);
    assert.deepEqual(writes.map((body) => JSON.parse(body).action), ['delete'], 'one delete, sent once the issuer matched');
    assert.equal(stored(), null, 'the instance no longer holds the configuration');
    assert.equal(clientCount(), 0, 'nor its client');
  } finally {
    await context.close();
  }
});

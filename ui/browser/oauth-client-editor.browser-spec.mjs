/**
 * Story 12.5 in a real browser, against the throwaway instance: the OAuth 2.0 client configuration
 * editor at `security/oauth/clients/edit`, reached from the Client configurations tab.
 *
 * What it pins, each on rendered DOM, on the real URL or on the instance itself:
 *
 * 1. **Create** (AC1, AC10): the tab's Create opens the editor, its four tabs in the classic
 *    page's order; Save with a client secret typed replaces the route with the configuration's own,
 *    reads "Saved", and the instance holds the fields, the grant type and the secret.
 * 2. **Edit and secrets** (AC2, AC3): the tab's name cell opens the editor with every secret masked
 *    and empty; a changed description reaches the instance and the stored secret is kept.
 * 3. **Register** (AC5): a typed initial access token is stored with the Save, and Register against
 *    the local issuer reports the client ID it issued, which the instance holds.
 * 4. **Rotate Keys** (AC6): the editor reports the rotation and the key set changes.
 * 5. **Delete from the row menu** (AC6, AC10): the editor's delete dialog passes DW-1337, the row menu
 *    offers the three declared actions, and the typed name deletes it.
 * 6. **DW-1337** (AC10): the editor and its delete dialog pass the structural and contrast checks at
 *    1280 light, 720 light and 1280 dark, allowed only the shell's own two findings.
 *
 * **It refuses the live container.** The issuer is `OcuPilot.Test.OAuthIssuerFixture`, started in
 * `before` and stopped in `after`; every probe object is removed by exact name before and after.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test
 * browser/oauth-client-editor.browser-spec.mjs`.
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

/** The probe prefix `OcuPilot.Test.OAuthClientProbe` removes by, and this spec's one configuration. */
const NAME = 'OcuPilotProbe125Browser';
const ISSUER = 'https://ocupilotprobe125.invalid/browser';
/** The local issuer's registration endpoint, and the client ID it issues. */
const REGISTRATION_ENDPOINT = 'http://localhost:18764/register';
const ISSUED_CLIENT_ID = 'ocupilotprobe000client';
const SSL = 'OcuPilotDemoTLS';
const REDIRECT = 'https://localhost:57773/csp/sys/oauth2';
const SECRET = 'ocupilotbrowserprobe000secret';
const INITIAL_TOKEN = 'ocupilotbrowserprobe000initial';
const TAB_ROUTE = 'security/oauth/clients';
const EDITOR_ROUTE = 'security/oauth/clients/edit';
const TAB_URL = `/ocupilot/${TAB_ROUTE}?ns=HSCUSTOM`;
const EDIT_URL = `/ocupilot/${EDITOR_ROUTE}/${encodeEntityId(NAME)}?ns=HSCUSTOM`;
const ACTION_PATH = '/api/ocupilot/screens/security.oauthclients/action';
const ID = 'ocu-oauth-client';

let browser = null;

/** The server description the configuration names, made in `before`. */
let serverId = '';

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

/** The instance's own read of the configuration, secrets as lengths, or `null` when it holds none. */
function stored() {
  const { values } = irisSession(
    [`Set tStored=##class(OcuPilot.Test.OAuthClientProbe).Stored("${NAME}")`, mark('STORED', '$Select($IsObject(tStored):tStored.%ToJSON(),1:"")')],
    ['STORED']
  );
  return values.STORED === '' || values.STORED === null ? null : JSON.parse(values.STORED);
}

function removeAll() {
  const { values, output } = irisSession(['Set tSC=##class(OcuPilot.Test.OAuthClientProbe).RemoveAll(.tLeft)', mark('LEFT', '$System.Status.IsOK(tSC)_"/"_tLeft')], ['LEFT']);
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

/** The editor's four tabs, in the classic page's order. */
const TAB_KEYS = ['general', 'information', 'jwt', 'credentials'];

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
    // Story 16.17: the text, or the text and the instance's read-back line after it.
    (expected) => ((shown) => shown === expected || shown.startsWith(`${expected} \u00b7 `))(document.querySelector('.ocu-form-bar-status [role="status"]')?.textContent?.trim() ?? ''),
    { timeout },
    text
  );
}

/** Wait until the edit's form read has rendered the configuration's name. */
async function editLoaded(page) {
  // `?? ''`: an absent field is not loaded, so the wait holds until the form read has rendered it.
  await page.waitForFunction((id) => (document.querySelector(`#${id}-ApplicationName`)?.value ?? '') !== '', { timeout: config.navigationTimeoutMs }, ID);
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates and deletes OAuth 2.0 configuration, so it never runs inside the live container');
  await assertThrowaway(config);
  removeAll();
  const started = irisSession(['Set tSC=##class(OcuPilot.Test.OAuthIssuerFixture).Start(,.tIssuer)', mark('STARTED', '$System.Status.IsOK(tSC)')], ['STARTED']);
  assert.equal(started.values.STARTED, '1', `the local issuer is serving:\n${started.output}`);
  const made = irisSession(
    [`Set tSC=##class(OcuPilot.Test.OAuthClientProbe).AddServer("${ISSUER}",.tId,"${REGISTRATION_ENDPOINT}")`, mark('SERVER', '$System.Status.IsOK(tSC)_"/"_tId')],
    ['SERVER']
  );
  assert.match(made.values.SERVER ?? '', /^1\/\d+$/, `a server description publishing the local registration endpoint is made:\n${made.output}`);
  serverId = made.values.SERVER.split('/')[1];
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  // The issuer is still serving while a registered client is removed, which asks it to deregister.
  removeAll();
  const { values } = irisSession(['Set tSC=##class(OcuPilot.Test.OAuthIssuerFixture).Stop()', mark('STOPPED', '$System.Status.IsOK(tSC)')], ['STOPPED']);
  assert.equal(values.STOPPED, '1', 'the local issuer stops');
});

// AC1, AC10. Mutation (Rule 19), over a rebuilt and redeployed bundle: give
// `.ocu-oauth-client-metadata-table` a 1400px min-inline-size -> the structural assertion goes red.
test('AC1, AC10: Create opens the editor in four tabs, and Save stores the fields, the grant type and the secret', async () => {
  const { context, page } = await signedInAt(browser, config, TAB_URL, VIEWPORTS.wide);
  try {
    const create = await page.waitForSelector('.ocu-command-bar button.ocu-button-primary', { visible: true, timeout: config.navigationTimeoutMs });
    await create.click();
    await page.waitForFunction((route) => new URL(window.location.href).pathname.endsWith(`/${route}`), { timeout: config.navigationTimeoutMs }, EDITOR_ROUTE);
    await page.waitForSelector(`#${ID}-ApplicationName`, { visible: true, timeout: config.navigationTimeoutMs });
    const tabs = await page.$$eval('[role="tab"] .ocu-form-tab-label', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(tabs, [
      STRINGS.processDetailsGroupGeneral,
      STRINGS.oauthClientSectionClientInformation,
      STRINGS.oauthClientSectionJwt,
      STRINGS.oauthClientSectionCredentials,
    ]);
    for (const key of TAB_KEYS) {
      await openTab(page, key);
      await assertStructure(page);
    }
    await openTab(page, 'general');

    await fill(page, `${ID}-ApplicationName`, NAME);
    await page.select(`#${ID}-ServerDefinition`, serverId);
    await page.select(`#${ID}-SSLConfiguration`, SSL);
    await fill(page, `${ID}-RedirectionEndpoint`, REDIRECT);
    await page.click(`#${ID}-grant-authorization_code`);
    await fill(page, `${ID}-ClientSecret`, SECRET);
    await saveAndSettle(page, config);
    await statusLine(page, STRINGS.formSaved);
    await page.waitForFunction((suffix) => new URL(window.location.href).pathname.endsWith(suffix), { timeout: config.navigationTimeoutMs }, `/${EDITOR_ROUTE}/${encodeEntityId(NAME)}`);
    const held = stored();
    assert.ok(held !== null, 'the instance holds the configuration');
    assert.deepEqual([held.ClientType, held.SSLConfiguration, held.SecretLength], ['confidential', SSL, SECRET.length]);
    assert.deepEqual(held.Metadata.grant_types, ['authorization_code']);
    assert.equal(await page.$eval(`#${ID}-ClientSecret`, (node) => node.value), '', 'the typed secret is forgotten');
  } finally {
    await context.close();
  }
});

test("AC2, AC3: the tab's name cell opens the editor with every secret masked and empty, and an edit keeps the stored secret", async () => {
  const { context, page } = await signedInAt(browser, config, TAB_URL, VIEWPORTS.wide);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await clickRowCentre(page, { text: NAME, link: true });
    await page.waitForFunction((suffix) => new URL(window.location.href).pathname.endsWith(suffix), { timeout: config.navigationTimeoutMs }, `/${EDITOR_ROUTE}/${encodeEntityId(NAME)}`);
    await editLoaded(page);
    for (const field of ['ClientSecret', 'ClientPassword', 'RegistrationAccessToken', 'InitialAccessToken']) {
      assert.equal(await page.$eval(`#${ID}-${field}`, (node) => `${node.type}|${node.value}`), 'password|', `${field} is masked and never pre-filled`);
    }
    await fill(page, `${ID}-Description`, 'edited in the browser');
    await saveAndSettle(page, config);
    await statusLine(page, STRINGS.formSaved);
    const held = stored();
    assert.equal(held.Description, 'edited in the browser', 'the changed field is stored');
    assert.equal(held.SecretLength, SECRET.length, 'and the stored secret is kept');
    assert.deepEqual(held.Metadata.grant_types, ['authorization_code'], 'and so is every other member');
  } finally {
    await context.close();
  }
});

test('AC5: Register, after the initial access token is stored, reports the client ID the issuer issued', async () => {
  const { context, page } = await signedInAt(browser, config, EDIT_URL, VIEWPORTS.wide);
  try {
    await editLoaded(page);
    await fill(page, `${ID}-InitialAccessToken`, INITIAL_TOKEN);
    await saveAndSettle(page, config);
    await statusLine(page, STRINGS.formSaved);
    await barButton(page, STRINGS.oauthClientRegister);
    await statusLine(page, STRINGS.oauthClientRegistered.split('<issuer>').join(ISSUER).split('<clientId>').join(ISSUED_CLIENT_ID), 90000);
    const held = stored();
    assert.equal(held.ClientId, ISSUED_CLIENT_ID, 'the instance holds the issued client ID');
    assert.equal(held.Metadata.registration_client_uri, `${REGISTRATION_ENDPOINT}/${ISSUED_CLIENT_ID}`, 'and the registration URI');
    const buttons = await page.$$eval('.ocu-form-bar-actions button', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.ok(!buttons.includes(STRINGS.oauthClientRegister), `a registered client offers no Register: ${buttons.join(', ')}`);
  } finally {
    await context.close();
  }
});

test('AC6: Rotate Keys adds to the key set and the editor reports it', async () => {
  const keysBefore = stored().PublicJWKS;
  const { context, page } = await signedInAt(browser, config, EDIT_URL, VIEWPORTS.wide);
  try {
    await editLoaded(page);
    await barButton(page, STRINGS.oauthClientRotateKeys);
    await statusLine(page, STRINGS.oauthClientKeysRotated);
    assert.notEqual(stored().PublicJWKS, keysBefore, 'the key set changed');
  } finally {
    await context.close();
  }
});

test("AC6, AC10: the editor's delete dialog passes DW-1337, and the row menu's Delete removes the configuration after the typed name", async () => {
  const { context, page } = await signedInAt(browser, config, EDIT_URL, VIEWPORTS.wide);
  try {
    await editLoaded(page);
    await barButton(page, STRINGS.actionDelete);
    await page.waitForSelector('[role="dialog"]', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-typed-name-consequence', (node) => node.textContent.trim()), STRINGS.oauthClientDeleteConsequence);
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
    await clickRowCentre(page, { index: 0, cell: 3 });
    await page.waitForFunction((selector) => document.querySelector(selector)?.getAttribute('aria-selected') === 'true', { timeout: config.navigationTimeoutMs }, ROW_SELECTOR);
    await page.click('.ocu-data-table-trigger');
    await page.waitForSelector('[role="menu"]', { timeout: config.navigationTimeoutMs });
    const labels = await page.$$eval('[role="menu"] [role="menuitem"] .ocu-data-table-menu-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(labels, [STRINGS.actionDelete, STRINGS.oauthClientRotateKeys, STRINGS.oauthClientRegister], 'the row menu offers the three declared actions');
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
  } finally {
    await context.close();
  }
});

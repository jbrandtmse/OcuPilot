/**
 * Story 12.8 in a real browser, against the throwaway instance: the OAuth 2.0 server client
 * description editor at `security/oauth/server-clients/edit`, reached from the Server client
 * descriptions tab.
 *
 * What it pins, each on rendered DOM, on the real URL or on the instance itself:
 *
 * 1. **Create** (AC1, AC10): the tab's Create opens the editor in four tabs, every tab passes DW-1337,
 *    and Save with a generated secret replaces the route with the new client id and stores what was
 *    entered, the secret included.
 * 2. **Edit and secret** (AC2, AC4, AC8): the tab's name cell opens the editor with the secret masked
 *    and empty; a redirect URL removed and one added and a Client Information member changed reach
 *    the instance, and every other field reads as before.
 * 3. **Update JWKS** (AC5): from the in-container JWKS URL the stored public keys grow, and the editor
 *    reports it.
 * 4. **Delete from the editor** (AC3, AC10): the delete dialog passes DW-1337, and the typed client id
 *    deletes the client.
 *
 * **It refuses the live container.** The configuration and every client are removed before and after
 * (`OcuPilot.Test.OAuthRegisteredClientProbe`).
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test
 * browser/oauth-registered-client-editor.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { clickRowCentre, waitForRows } from './list-spec.mjs';
import { saveAndSettle, signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));
const { encodeEntityId } = await import(join(uiRoot, 'src', 'app', 'core', 'entity-id.ts'));

const config = browserConfig();

const PROBE = 'OcuPilot.Test.OAuthRegisteredClientProbe';
const NAME = 'OcuPilotProbe128BrowserClient';
const REDIRECT_A = 'https://app.ocupilotprobe128.invalid/a';
const REDIRECT_B = 'https://app.ocupilotprobe128.invalid/b';
const REDIRECT_C = 'https://app.ocupilotprobe128.invalid/c';
const JWKS_URL = 'http://localhost:52773/oauth2/jwks';
const TAB_ROUTE = 'security/oauth/server-clients';
const EDITOR_ROUTE = 'security/oauth/server-clients/edit';
const TAB_URL = `/ocupilot/${TAB_ROUTE}?ns=HSCUSTOM`;
const ID = 'ocu-oauth-registered-client';

/** The editor's four tabs, in order. */
const TAB_KEYS = ['general', 'credentials', 'information', 'jwt'];

let browser = null;

/** The client id the create leg registered. */
let clientId = '';

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

/** The instance's own read of client `id`, the secrets as their lengths, or `null` when it holds none. */
function stored(id) {
  const { values } = irisSession([`Set tStored=##class(${PROBE}).Stored("${id}")`, mark('STORED', '$Select($IsObject(tStored):tStored.%ToJSON(),1:"")')], ['STORED']);
  return values.STORED === '' || values.STORED === null ? null : JSON.parse(values.STORED);
}

function removeAll() {
  const { values, output } = irisSession([`Set tSC=##class(${PROBE}).RemoveAll(.tLeft)`, mark('LEFT', '$System.Status.IsOK(tSC)_"/"_tLeft')], ['LEFT']);
  assert.equal(values.LEFT, '1/0', `the configuration and every client are removed:\n${output}`);
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

/** Press button `id`, its tab opened first, by focus and Enter for the reason `fill` gives. */
async function press(page, id) {
  await openTabOf(page, id);
  await page.focus(`#${id}`);
  await page.keyboard.press('Enter');
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

/** Wait until the edit's form read has rendered the client id. */
async function editLoaded(page) {
  // `?? ''`: an absent field is not loaded, so the wait holds until the form read has rendered it.
  await page.waitForFunction((id) => (document.querySelector(`#${id}-ClientId`)?.value ?? '') !== '', { timeout: config.navigationTimeoutMs }, ID);
}

function editUrl(id) {
  return `/ocupilot/${EDITOR_ROUTE}/${encodeEntityId(id)}?ns=HSCUSTOM`;
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates and deletes OAuth 2.0 clients, so it never runs inside the live container');
  await assertThrowaway(config);
  removeAll();
  const seeded = irisSession([`Set tSC=##class(${PROBE}).Seed()`, mark('SEEDED', '$System.Status.IsOK(tSC)')], ['SEEDED']);
  assert.equal(seeded.values.SEEDED, '1', `the authorization server configuration is made:\n${seeded.output}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  removeAll();
});

// AC1, AC10. Mutation (Rule 19), over a rebuilt and redeployed bundle: give
// `.ocu-oauth-registered-client-row` a 1400px min-inline-size -> the structural assertion goes red.
test('AC1, AC10: Create opens the editor in four tabs, each passes DW-1337, and Save with a generated secret stores what was entered', async () => {
  const { context, page } = await signedInAt(browser, config, TAB_URL, VIEWPORTS.wide);
  try {
    const create = await page.waitForSelector('.ocu-command-bar button.ocu-button-primary', { visible: true, timeout: config.navigationTimeoutMs });
    await create.click();
    await page.waitForFunction((route) => new URL(window.location.href).pathname.endsWith(`/${route}`), { timeout: config.navigationTimeoutMs }, EDITOR_ROUTE);
    await page.waitForSelector(`#${ID}-Name`, { visible: true, timeout: config.navigationTimeoutMs });
    const tabs = await page.$$eval('[role="tab"] .ocu-form-tab-label', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(tabs, [STRINGS.processDetailsGroupGeneral, STRINGS.oauthClientSectionCredentials, STRINGS.oauthClientSectionClientInformation, STRINGS.oauthClientSectionJwt]);
    await press(page, `${ID}-add-redirect`);
    await page.waitForSelector(`#${ID}-RedirectURL-1`, { timeout: config.navigationTimeoutMs });
    for (const key of TAB_KEYS) {
      await openTab(page, key);
      await assertStructure(page);
    }

    await fill(page, `${ID}-Name`, NAME);
    await fill(page, `${ID}-RedirectURL-1`, REDIRECT_A);
    await press(page, `${ID}-add-redirect`);
    await page.waitForSelector(`#${ID}-RedirectURL-2`, { timeout: config.navigationTimeoutMs });
    await fill(page, `${ID}-RedirectURL-2`, REDIRECT_B);
    await fill(page, `${ID}-Metadata-client_name`, 'Browser probe');
    await press(page, `${ID}-generate`);
    await page.waitForFunction((id) => (document.querySelector(`#${id}-ClientSecret`)?.value ?? '') !== '', { timeout: config.navigationTimeoutMs }, ID);
    const secret = await page.$eval(`#${ID}-ClientSecret`, (node) => `${node.type}|${node.value}`);
    assert.match(secret, /^password\|[A-Za-z0-9_-]{64}$/, 'Generate fills the field with a masked 64-character secret');
    await saveAndSettle(page, config);
    await statusLine(page, STRINGS.formSaved);
    clientId = irisSession([mark('ID', `##class(${PROBE}).IdOf("${NAME}")`)], ['ID']).values.ID ?? '';
    assert.notEqual(clientId, '', 'the instance registered the client');
    await page.waitForFunction((suffix) => new URL(window.location.href).pathname.endsWith(suffix), { timeout: config.navigationTimeoutMs }, `/${EDITOR_ROUTE}/${encodeEntityId(clientId)}`);
    const held = stored(clientId);
    assert.deepEqual(
      [held.Name, held.RedirectURL, held.ClientType, held.Metadata.client_name, held.Metadata.token_endpoint_auth_method],
      [NAME, `${REDIRECT_A},${REDIRECT_B}`, 'confidential', 'Browser probe', 'client_secret_basic']
    );
    const matches = irisSession([mark('SAME', `##class(${PROBE}).SecretIs("${clientId}","${secret.split('|')[1]}")`)], ['SAME']).values.SAME;
    assert.equal(matches, '1', 'the instance stores the generated secret');
    await openTab(page, 'credentials');
    assert.equal(await page.$eval(`#${ID}-ClientSecret`, (node) => node.value), '', 'the secret is forgotten once saved');
  } finally {
    await context.close();
  }
});

test("AC2, AC4, AC8: the tab's name cell opens the editor with the secret masked and empty, and redirect URLs and a Client Information member reach the instance", async () => {
  assert.notEqual(clientId, '', 'the create leg registered a client');
  const before = stored(clientId);
  const { context, page } = await signedInAt(browser, config, TAB_URL, VIEWPORTS.wide);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await clickRowCentre(page, { text: NAME, link: true });
    await page.waitForFunction((suffix) => new URL(window.location.href).pathname.endsWith(suffix), { timeout: config.navigationTimeoutMs }, `/${EDITOR_ROUTE}/${encodeEntityId(clientId)}`);
    await editLoaded(page);
    await openTab(page, 'credentials');
    assert.equal(await page.$eval(`#${ID}-ClientSecret`, (node) => `${node.type}|${node.value}`), 'password|', 'the client secret is masked and empty');

    await openTab(page, 'general');
    await page.$eval(`#${ID}-RedirectURL .ocu-oauth-registered-client-row button`, (button) => button.click());
    await page.waitForFunction((id) => document.querySelectorAll(`#${id}-RedirectURL input`).length === 1, { timeout: config.navigationTimeoutMs }, ID);
    await press(page, `${ID}-add-redirect`);
    await page.waitForSelector(`#${ID}-RedirectURL-2`, { timeout: config.navigationTimeoutMs });
    await fill(page, `${ID}-RedirectURL-2`, REDIRECT_C);
    await fill(page, `${ID}-Metadata-client_name`, 'Browser probe edited');
    await saveAndSettle(page, config);
    await statusLine(page, STRINGS.formSaved);
    const held = stored(clientId);
    assert.deepEqual([held.RedirectURL, held.Metadata.client_name], [`${REDIRECT_B},${REDIRECT_C}`, 'Browser probe edited']);
    const unchanged = { ...before, RedirectURL: held.RedirectURL, Metadata: { ...before.Metadata, client_name: held.Metadata.client_name } };
    assert.deepEqual(held, unchanged, 'every other field and metadata member reads as before, the secret included');
  } finally {
    await context.close();
  }
});

test('AC5: Update JWKS fetches the in-container key set, the public keys grow, and the editor reports it', async () => {
  assert.notEqual(clientId, '', 'the create leg registered a client');
  const set = irisSession([`Set tSC=##class(${PROBE}).SetMember("${clientId}","jwks_uri","${JWKS_URL}")`, mark('SET', '$System.Status.IsOK(tSC)')], ['SET']);
  assert.equal(set.values.SET, '1', `the client names the in-container JWKS URL:\n${set.output}`);
  const keys = stored(clientId).PublicKeys;
  const { context, page } = await signedInAt(browser, config, editUrl(clientId), VIEWPORTS.wide);
  try {
    await editLoaded(page);
    await barButton(page, STRINGS.oauthServerUpdateJwks);
    await statusLine(page, STRINGS.oauthRegisteredClientJwksUpdated, 90000);
    assert.ok(stored(clientId).PublicKeys > keys, `the public keys grew from ${keys}`);
  } finally {
    await context.close();
  }
});

test("AC3, AC10: the editor's delete dialog passes DW-1337, and the typed client id deletes the client", async () => {
  assert.notEqual(clientId, '', 'the create leg registered a client');
  const { context, page } = await signedInAt(browser, config, editUrl(clientId), VIEWPORTS.wide);
  try {
    await editLoaded(page);
    await barButton(page, STRINGS.actionDelete);
    await page.waitForSelector('[role="dialog"]', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-typed-name-consequence', (node) => node.textContent.trim()), STRINGS.oauthServerClientDeleteConsequence);
    await assertStructure(page, true);
    await page.type('.ocu-typed-name-field', clientId);
    await page.keyboard.press('Enter');
    await page.waitForFunction((route) => new URL(window.location.href).pathname.endsWith(`/${route}`), { timeout: 90000 }, TAB_ROUTE);
    assert.equal(stored(clientId), null, 'the instance no longer holds the client');
  } finally {
    await context.close();
  }
});

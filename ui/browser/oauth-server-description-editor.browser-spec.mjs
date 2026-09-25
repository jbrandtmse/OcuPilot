/**
 * Story 12.4 in a real browser, against the throwaway instance: the OAuth 2.0 client server
 * description editor at `security/oauth/edit`, reached from the Server descriptions tab.
 *
 * What it pins, each on rendered DOM, on the real URL or on the instance itself:
 *
 * 1. **Create, by way of Discover** (AC1, AC4): the tab's Create opens the editor; Discover fills the
 *    endpoints and the metadata table from the local issuer and saves nothing; Save replaces the
 *    route with the description's own and reads "Saved", and the instance holds the discovered
 *    members.
 * 2. **Edit** (AC2): the tab's name cell opens the editor; one endpoint changed and one cleared reach
 *    the instance exactly, and every other member is kept.
 * 3. **Update JWKS** (AC5): the editor reports the refresh and the instance holds the key set.
 * 4. **Delete from the row menu** (AC3): the typed issuer deletes it and the row leaves the tab.
 * 6. **DW-1337** (AC10): the editor and its delete dialog pass the structural and contrast checks at
 *    1280 light, 720 light and 1280 dark, with no baseline allowance.
 *
 * **It refuses the live container.** The issuer is `OcuPilot.Test.OAuthIssuerFixture`, started in
 * `before` and stopped in `after`; the description is removed by exact issuer before and after.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test
 * browser/oauth-server-description-editor.browser-spec.mjs`.
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

/** The local issuer `OcuPilot.Test.OAuthIssuerFixture` answers as, on its default port. */
const ISSUER = 'http://localhost:18764';
const SSL = 'OcuPilotDemoTLS';
const TAB_ROUTE = 'security/oauth';
const EDITOR_ROUTE = 'security/oauth/edit';
const TAB_URL = `/ocupilot/${TAB_ROUTE}?ns=HSCUSTOM`;
const ACTION_PATH = '/api/ocupilot/screens/security.oauthserverdescriptions/action';

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

/** The instance's own read of the description, as JSON, or `""` when it holds none. */
function stored() {
  const { values } = irisSession(
    [`Set tStored=##class(OcuPilot.Test.OAuthServerProbe).Stored("${ISSUER}")`, mark('STORED', '$Select($IsObject(tStored):tStored.%ToJSON(),1:"")')],
    ['STORED']
  );
  return values.STORED === '' || values.STORED === null ? null : JSON.parse(values.STORED);
}

function removeAll() {
  const { values, output } = irisSession(['Set tSC=##class(OcuPilot.Test.OAuthServerProbe).RemoveAll(.tLeft)', mark('LEFT', '$System.Status.IsOK(tSC)_"/"_tLeft')], ['LEFT']);
  assert.equal(values.LEFT, '1/0', `every probe description is removed:\n${output}`);
}

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/**
 * The only allowance: the shell's own two open findings, which every route carries and no screen
 * owns -- the panel's resize handle (DW-1583) and the status bar's connection line (DW-1584) --
 * re-keyed to this route. Nothing this screen draws is allowed (a new screen has no allowance).
 */
function shellAllowance() {
  const seen = new Map();
  for (const entry of readBaseline()?.entries ?? []) {
    if (entry.dw !== 'DW-1583' && entry.dw !== 'DW-1584') continue;
    const key = [EDITOR_ROUTE, ...entry.key.split('|').slice(1)].join('|');
    seen.set(key, { ...entry, key, route: EDITOR_ROUTE });
  }
  return [...seen.values()];
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

/** Type `value` into the form control `id`, replacing whatever is there. */
async function fill(page, id, value) {
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

async function statusLine(page, text) {
  await page.waitForFunction(
    (expected) => document.querySelector('.ocu-form-bar-status [role="status"]')?.textContent?.trim() === expected,
    { timeout: config.navigationTimeoutMs },
    text
  );
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates and deletes OAuth 2.0 configuration, so it never runs inside the live container');
  await assertThrowaway(config);
  removeAll();
  const { values, output } = irisSession(['Set tSC=##class(OcuPilot.Test.OAuthIssuerFixture).Start(,.tIssuer)', mark('STARTED', '$System.Status.IsOK(tSC)_"/"_tIssuer')], ['STARTED']);
  assert.equal(values.STARTED, `1/${ISSUER}`, `the local issuer is serving:\n${output}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  const { values } = irisSession(['Set tSC=##class(OcuPilot.Test.OAuthIssuerFixture).Stop()', mark('STOPPED', '$System.Status.IsOK(tSC)')], ['STOPPED']);
  assert.equal(values.STOPPED, '1', 'the local issuer stops');
  removeAll();
});

// AC1, AC4, AC10. Mutation (Rule 19), over a rebuilt and redeployed bundle: give
// `.ocu-oauth-server-metadata-table` a 1400px min-inline-size -> the structural assertion goes red.
test('AC1, AC4, AC10: Create opens the editor, Discover fills it and saves nothing, and Save stores the members', async () => {
  const { context, page } = await signedInAt(browser, config, TAB_URL, VIEWPORTS.wide);
  try {
    const create = await page.waitForSelector('.ocu-command-bar button.ocu-button-primary', { visible: true, timeout: config.navigationTimeoutMs });
    await create.click();
    await page.waitForFunction((route) => new URL(window.location.href).pathname.endsWith(`/${route}`), { timeout: config.navigationTimeoutMs }, EDITOR_ROUTE);
    await page.waitForSelector('#ocu-oauth-server-IssuerEndpoint', { visible: true, timeout: config.navigationTimeoutMs });
    await assertStructure(page);

    await fill(page, 'ocu-oauth-server-IssuerEndpoint', ISSUER);
    await fill(page, 'ocu-oauth-server-SSLConfiguration', SSL);
    await barButton(page, STRINGS.oauthServerDiscover);
    await statusLine(page, STRINGS.oauthServerDiscovered.split('<issuer>').join(ISSUER));
    assert.equal(await page.$eval('#ocu-oauth-server-Metadata-token_endpoint', (node) => node.value), `${ISSUER}/token`, 'the token endpoint is filled');
    assert.equal(await page.$eval('#ocu-oauth-server-jwt-url', (node) => node.checked), true, 'the JWKS URL is chosen');
    const table = await page.$$eval('.ocu-oauth-server-metadata-table tr', (rows) => rows.map((row) => Array.from(row.children).map((cell) => cell.textContent.trim())));
    assert.ok(table.some(([name, value]) => name === 'scopes_supported' && value === 'openid, profile'), `the metadata table shows the lists: ${JSON.stringify(table)}`);
    assert.equal(stored(), null, 'the discovery saved nothing');
    await assertStructure(page);

    await saveAndSettle(page, config);
    await statusLine(page, STRINGS.formSaved);
    await page.waitForFunction(
      (suffix) => new URL(window.location.href).pathname.endsWith(suffix),
      { timeout: config.navigationTimeoutMs },
      `/${EDITOR_ROUTE}/${encodeEntityId(ISSUER)}`
    );
    const held = stored();
    assert.ok(held !== null, 'the instance holds the description');
    assert.equal(held.Metadata.token_endpoint, `${ISSUER}/token`);
    assert.deepEqual(held.Metadata.scopes_supported, ['openid', 'profile']);
    assert.equal(held.SSLConfiguration, SSL);
  } finally {
    await context.close();
  }
});

test("AC2: the tab's name cell opens the editor, and an endpoint changed and one cleared reach the instance exactly", async () => {
  const { context, page } = await signedInAt(browser, config, TAB_URL, VIEWPORTS.wide);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await clickRowCentre(page, { text: ISSUER, link: true });
    await page.waitForFunction(
      (suffix) => new URL(window.location.href).pathname.endsWith(suffix),
      { timeout: config.navigationTimeoutMs },
      `/${EDITOR_ROUTE}/${encodeEntityId(ISSUER)}`
    );
    // `?? ''`: an absent field is not loaded, so the wait holds until the form read has rendered it.
    await page.waitForFunction(() => (document.querySelector('#ocu-oauth-server-Metadata-token_endpoint')?.value ?? '') !== '', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('#ocu-oauth-server-InitialAccessToken', (node) => `${node.type}|${node.value}`), 'password|', 'the token is masked and never pre-filled');
    await fill(page, 'ocu-oauth-server-Metadata-token_endpoint', `${ISSUER}/token2`);
    await fill(page, 'ocu-oauth-server-Metadata-userinfo_endpoint', '');
    await saveAndSettle(page, config);
    await statusLine(page, STRINGS.formSaved);
    const held = stored();
    assert.equal(held.Metadata.token_endpoint, `${ISSUER}/token2`, 'the changed endpoint is stored');
    assert.equal(held.Metadata.userinfo_endpoint, undefined, 'the cleared one is gone');
    assert.equal(held.Metadata.authorization_endpoint, `${ISSUER}/authorize`, 'and every other member is kept');
    assert.deepEqual(held.Metadata.response_types_supported, ['code']);
  } finally {
    await context.close();
  }
});

test('AC5: Update JWKS refreshes the stored key set and the editor reports it', async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${EDITOR_ROUTE}/${encodeEntityId(ISSUER)}?ns=HSCUSTOM`, VIEWPORTS.wide);
  try {
    await barButton(page, STRINGS.oauthServerUpdateJwks);
    await statusLine(page, STRINGS.oauthServerJwksUpdated.split('<url>').join(`${ISSUER}/jwks`));
    assert.notEqual(stored().PublicJWKS, '', 'the instance holds the key set');
  } finally {
    await context.close();
  }
});

test("AC3, AC10: the editor's delete dialog passes DW-1337, and the row menu's Delete removes the description after the typed issuer", async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${EDITOR_ROUTE}/${encodeEntityId(ISSUER)}?ns=HSCUSTOM`, VIEWPORTS.wide);
  try {
    await barButton(page, STRINGS.actionDelete);
    await page.waitForSelector('[role="dialog"]', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-typed-name-consequence', (node) => node.textContent.trim()), STRINGS.oauthServerDeleteConsequence);
    await assertStructure(page, true);
    await page.keyboard.press('Escape');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });

    const writes = [];
    page.on('request', (request) => {
      if (request.method() === 'POST' && request.url().includes(ACTION_PATH)) writes.push(request.postData() ?? '');
    });
    // The editor's own Cancel returns to the tab, inside the signed-in shell.
    await barButton(page, STRINGS.actionCancel);
    await waitForRows(page, config.navigationTimeoutMs);
    await page.type(FILTER_SELECTOR, 'localhost');
    await page.waitForFunction((selector) => document.querySelectorAll(selector).length === 1, { timeout: config.navigationTimeoutMs }, ROW_SELECTOR);
    await clickRowCentre(page, { index: 0, cell: 1 });
    await page.click('.ocu-data-table-trigger');
    await page.waitForSelector('[role="menu"]', { timeout: config.navigationTimeoutMs });
    const labels = await page.$$eval('[role="menu"] [role="menuitem"] .ocu-data-table-menu-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(labels, [STRINGS.actionDelete, STRINGS.oauthServerUpdateJwks], 'the row menu offers the two declared actions');
    await page.evaluate((label) => {
      Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]')).find((item) => item.textContent.trim().startsWith(label)).click();
    }, STRINGS.actionDelete);
    await page.waitForSelector('[role="dialog"]', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-dialog-title', (node) => node.textContent.trim()), `${STRINGS.actionDelete} ${ISSUER}`);
    await page.type('.ocu-typed-name-field', ISSUER);
    await page.keyboard.press('Enter');
    await page.waitForFunction((selector) => document.querySelectorAll(selector).length === 0, { timeout: config.navigationTimeoutMs }, ROW_SELECTOR);
    assert.deepEqual(writes.map((body) => JSON.parse(body)), [{ action: 'delete', id: ISSUER }], 'one delete, sent once the issuer matched');
    assert.equal(stored(), null, 'the instance no longer holds it');
  } finally {
    await context.close();
  }
});

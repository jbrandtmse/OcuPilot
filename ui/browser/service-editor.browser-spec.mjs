/**
 * Story 16.13 in a real browser, against the throwaway instance: the service editor (AD-5, AD-55).
 *
 * What it pins, each on rendered DOM, on the real URL or on the instance itself:
 *
 * 1. **A Services row's name opens the editor**, whose tabs for `%Service_CacheDirect` are General,
 *    Authentication methods (one box per method the form read offers, with the instance's own
 *    labels) and Allowed incoming connections, with no classic-portal card (AC1).
 * 2. **An address is added and saved, then removed and saved**: each reads "Saved", reaches the
 *    instance with the service's other fields kept, and the Services list shows the address, then
 *    "Unrestricted" (AC2, Integration).
 * 3. **On `%Service_ECP`, Edit roles and Apply give an address a role**, which the Save stores as
 *    `address|role`, read back inside the container (AC3).
 * 4. **On the service OcuPilot is served through**, Service enabled is drawn unavailable with the
 *    published sentence and a click leaves it on, while a drawn change to its addresses shows the
 *    served-through line; the change is then discarded, and nothing is ever sent (AC5).
 * 5. **The DW-1337 structural walk** of the editor at an id route, each tab in turn, in both themes.
 *
 * **It runs only in a throwaway** (`-ci`), and writes only `%Service_CacheDirect` and
 * `%Service_ECP`, both disabled, each through `OcuPilot.Test.ServiceLdapProbe`'s snapshot and
 * restore, armed by `OCUPILOT_ALLOW_SERVICE_CONFIG`; every leg that writes restores in `finally`.
 * `%Service_WebGateway` is only read.
 *
 * Run: `node --test --test-concurrency=1 browser/service-editor.browser-spec.mjs` (after
 * `npm run build`, the bundle copied into the throwaway, and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const PROBE_CLASS = 'OcuPilot.Test.ServiceLdapProbe';
const ROUTE = 'permissions/services/edit';
const LIST_URL = '/ocupilot/permissions/services?ns=HSCUSTOM';
const CACHEDIRECT = '%Service_CacheDirect';
const ECP = '%Service_ECP';
const SERVING = '%Service_WebGateway';
const FORM_PATH = '/api/ocupilot/services/form';

let browser = null;

/** The editor's address for service `name`: its id encoded twice for the route (AD-13). */
const editUrl = (name) => `/ocupilot/${ROUTE}/${encodeURIComponent(encodeURIComponent(name))}?ns=HSCUSTOM`;

/** An ObjectScript string literal carrying `text`. */
const literal = (text) => `"${text.replaceAll('"', '""')}"`;

/** The snapshot `ServiceLdapProbe.SnapshotOf` takes of service `name`, as JSON text. */
function snapshotOf(name) {
  const output = runIris(config.container, [
    `Set sc=##class(${PROBE_CLASS}).SnapshotOf(${literal(name)},.snap)`,
    'Write "OCU-SNAP-START:"_$Select($System.Status.IsOK(sc):"ok#"_$Get(snap),1:$System.Status.GetErrorText(sc))_":OCU-SNAP-END",!',
  ]);
  const value = markerValue(output, 'SNAP');
  assert.ok(value !== null && value.startsWith('ok#'), `${name} is snapshotted (is OCUPILOT_ALLOW_SERVICE_CONFIG set?): ${output}`);
  return value.slice(3);
}

/** Put service `name` back as `json` holds it, through `ServiceLdapProbe.RestoreOf`. */
function restoreOf(name, json) {
  const output = runIris(config.container, [
    `Set sc=##class(${PROBE_CLASS}).RestoreOf(${literal(name)},${literal(json)})`,
    'Write "OCU-RESTORE-START:"_$Select($System.Status.IsOK(sc):"ok",1:$System.Status.GetErrorText(sc))_":OCU-RESTORE-END",!',
  ]);
  assert.equal(markerValue(output, 'RESTORE'), 'ok', `${name} is written back: ${output}`);
}

/** The vendor's read of service `name`, parsed. */
function readBack(name) {
  const output = runIris(config.container, [
    `Set sc=##class(${PROBE_CLASS}).Read(${literal(name)},.read)`,
    'Write "OCU-READ-START:"_$Select($IsObject($Get(read)):read.%ToJSON(),1:"")_":OCU-READ-END",!',
  ]);
  const value = markerValue(output, 'READ');
  assert.ok(value !== null && value !== '', `${name} reads back: ${output}`);
  return JSON.parse(value);
}

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/**
 * Wait until no CSS transition is running: a tab label's color eases between themes and a tab's
 * indicator slides to the tab chosen, so a read taken mid-transition measures the state it is
 * leaving.
 */
function transitionsSettled(page) {
  return page.waitForFunction(
    () => document.getAnimations().every((animation) => !(animation instanceof CSSTransition) || animation.playState !== 'running'),
    { timeout: config.navigationTimeoutMs }
  );
}

/** Signed in at `url`, recording every write to the service routes and every form read's answer. */
async function signedIn(url) {
  const { context, page } = await signedInAt(browser, config, url, VIEWPORTS.wide);
  const writes = [];
  const reads = [];
  page.on('request', (request) => {
    const path = new URL(request.url()).pathname;
    if (path.startsWith('/api/ocupilot/services') && request.method() !== 'GET') writes.push({ method: request.method(), path, body: request.postData() ?? '' });
  });
  page.on('response', async (response) => {
    if (new URL(response.url()).pathname !== FORM_PATH) return;
    try {
      reads.push(await response.json());
    } catch {
      // A body the page never read is not one this spec asserts on.
    }
  });
  return { context, page, writes, reads };
}

/** Wait until the editor holds its fresh read. */
async function editorReady(page) {
  await page.waitForSelector('app-service-editor-page app-form-tabs', { timeout: config.navigationTimeoutMs });
}

/** The tab strip's labels, in order. */
function tabLabels(page) {
  return page.$$eval('app-service-editor-page [role="tab"] .ocu-form-tab-label', (tabs) => tabs.map((tab) => tab.textContent.trim()));
}

/** Open the tab `key`. */
async function openTab(page, key) {
  await page.click(`app-service-editor-page [role="tab"][data-tab="${key}"]`);
  await page.waitForSelector(`app-service-editor-page [data-tab-body="${key}"]:not([hidden])`, { timeout: config.navigationTimeoutMs });
}

/** Press Save and wait for "Saved". */
async function save(page) {
  await page.click('app-service-editor-page .ocu-form-bar-actions .ocu-button-primary');
  await page.waitForFunction(
    (text) => ((shown) => shown === text || shown.startsWith(`${text} \u00b7 `))(document.querySelector('.ocu-form-bar-status [role="status"]')?.textContent.trim() ?? ''),
    { timeout: config.navigationTimeoutMs },
    STRINGS.formSaved
  );
}

/** Filter the Services list to the one row whose name contains `text`, and answer its cells. */
async function listedRow(page, text) {
  await waitForRows(page, config.navigationTimeoutMs);
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, text);
  await page.waitForFunction((selector) => document.querySelectorAll(selector).length === 1, { timeout: config.navigationTimeoutMs }, ROW_SELECTOR);
  return page.$eval(ROW_SELECTOR, (row) => Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim()));
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
  assert.match(config.container, /-ci$/, `this spec writes %Service_CacheDirect and %Service_ECP, so it runs only in a throwaway; ${config.container} is not one`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
});

test('AC1: a Services row\u2019s name opens the editor with the service\u2019s groups as tabs, the instance\u2019s method labels, and no classic-portal card', async () => {
  const { context, page, reads } = await signedIn(LIST_URL);
  try {
    await listedRow(page, 'CacheDirect');
    await clickRowCentre(page, { index: 0, link: true });
    await page.waitForFunction((route) => window.location.pathname.endsWith(`/${route}/%2525Service_CacheDirect`), { timeout: config.navigationTimeoutMs }, ROUTE);
    await editorReady(page);
    assert.deepEqual(await tabLabels(page), [STRINGS.processDetailsGroupGeneral, STRINGS.serviceColumnAuthentication, STRINGS.serviceFieldClientSystems]);
    assert.equal(await page.$eval('#ocu-service-edit-Name', (node) => node.value), CACHEDIRECT, 'the name is read from the instance');
    await openTab(page, 'methods');
    const labels = await page.$$eval('#ocu-service-edit-AutheEnabled .ocu-field-checkbox span', (nodes) => nodes.map((node) => node.textContent.trim()));
    const offered = (reads.at(-1)?.authenticationMethods ?? []).map((method) => method.label);
    assert.ok(offered.length > 0, `the form read offers CacheDirect methods: ${JSON.stringify(reads.at(-1))}`);
    assert.deepEqual(labels, offered, 'one box per offered method, labelled as the instance labels it');
    await openTab(page, 'connections');
    assert.notEqual(await page.$('#ocu-service-edit-ClientSystems'), null, 'the add field is drawn');
    assert.equal(await page.$('[data-action="edit-roles"]'), null, 'and no Edit roles, since CacheDirect gives an address none');
    assert.equal(await page.$('app-classic-link-card, .ocu-classic-link-card'), null, 'and no classic-portal card is drawn');
  } finally {
    await context.close();
  }
});

// AC2, Integration. The list re-reads on return whatever the change event says; the publish itself
// is pinned by `service-editor.store.spec.ts`.
test('AC2, Integration: an address is added, saved and listed, then removed, saved and listed "Unrestricted", with every other field kept', async () => {
  const snapshot = snapshotOf(CACHEDIRECT);
  const before = JSON.parse(snapshot);
  const { context, page, writes } = await signedIn(editUrl(CACHEDIRECT));
  try {
    await editorReady(page);
    await openTab(page, 'connections');
    await page.type('#ocu-service-edit-ClientSystems', '10.0.0.1');
    await page.click('[data-action="add-address"]');
    await save(page);
    assert.deepEqual(writes.map((write) => [write.method, write.path, JSON.parse(write.body)]), [['PUT', '/api/ocupilot/services/%2525Service_CacheDirect', { ClientSystems: ['10.0.0.1'] }]]);
    const added = readBack(CACHEDIRECT);
    assert.deepEqual(
      { ClientSystems: added.ClientSystems, AutheEnabled: added.AutheEnabled, Enabled: added.Enabled },
      { ClientSystems: ['10.0.0.1'], AutheEnabled: before.AutheEnabled, Enabled: before.Enabled },
      'the instance holds the address and keeps its methods and enablement'
    );
    await page.click('app-service-editor-page .ocu-form-bar-actions .ocu-button-text');
    await page.waitForFunction(() => window.location.pathname.endsWith('/permissions/services'), { timeout: config.navigationTimeoutMs });
    assert.ok((await listedRow(page, 'CacheDirect')).some((cell) => cell.includes('10.0.0.1')), 'the list shows the address');
    await clickRowCentre(page, { index: 0, link: true });
    await editorReady(page);
    await openTab(page, 'connections');
    await page.click('[data-action="remove-address"]');
    await save(page);
    assert.deepEqual(readBack(CACHEDIRECT).ClientSystems, [], 'the instance holds no address');
    await page.click('app-service-editor-page .ocu-form-bar-actions .ocu-button-text');
    await page.waitForFunction(() => window.location.pathname.endsWith('/permissions/services'), { timeout: config.navigationTimeoutMs });
    assert.ok((await listedRow(page, 'CacheDirect')).includes(STRINGS.serviceAllowedUnrestricted), 'and the list reads it Unrestricted');
  } finally {
    await context.close();
    restoreOf(CACHEDIRECT, snapshot);
  }
  assert.equal(JSON.stringify(readBack(CACHEDIRECT)), snapshot, 'CacheDirect reads back as its snapshot');
});

test('AC3: on %Service_ECP, Edit roles and Apply give an address a role, stored as address|role', async () => {
  const snapshot = snapshotOf(ECP);
  try {
    restoreOf(ECP, JSON.stringify({ ...JSON.parse(snapshot), ClientSystems: ['10.0.0.5'] }));
    const { context, page, writes } = await signedIn(editUrl(ECP));
    try {
      await editorReady(page);
      assert.deepEqual(await tabLabels(page), [STRINGS.processDetailsGroupGeneral, STRINGS.serviceFieldClientSystems], 'ECP has no methods tab');
      await openTab(page, 'connections');
      await page.click('[data-action="edit-roles"]');
      await page.waitForSelector('app-service-roles-dialog [role="dialog"]', { timeout: config.navigationTimeoutMs });
      assert.equal(
        await page.$eval('app-service-roles-dialog .ocu-dialog-title', (node) => node.textContent.trim()),
        STRINGS.serviceAddressRolesTitle.replace('<address>', '10.0.0.5'),
        'the dialog is titled with the address'
      );
      await page.evaluate(() => {
        const box = Array.from(document.querySelectorAll('#ocu-service-roles .ocu-field-checkbox')).find((label) => label.textContent.trim() === '%Operator');
        box.querySelector('input').click();
      });
      await page.evaluate((apply) => {
        Array.from(document.querySelectorAll('app-service-roles-dialog .ocu-dialog-actions button')).find((button) => button.textContent.trim() === apply).click();
      }, STRINGS.actionApply);
      await page.waitForFunction(() => document.querySelector('app-service-roles-dialog') === null, { timeout: config.navigationTimeoutMs });
      assert.equal(await page.$eval('[data-slot="roles"]', (node) => node.textContent.trim()), '%Operator', 'the entry shows its new role before Save');
      await save(page);
      assert.deepEqual(writes.map((write) => JSON.parse(write.body)), [{ ClientSystems: ['10.0.0.5|%Operator'] }]);
      assert.deepEqual(readBack(ECP).ClientSystems, ['10.0.0.5|%Operator'], 'the instance holds the address with its role');
    } finally {
      await context.close();
    }
  } finally {
    restoreOf(ECP, snapshot);
  }
  assert.equal(JSON.stringify(readBack(ECP)), snapshot, 'ECP reads back as its snapshot');
});

// AC5. The serving service is only read and drawn here: nothing is saved.
test('AC5: on the service OcuPilot is served through, Service enabled is unavailable with the published sentence, and a drawn change shows the served-through line and is discarded unsent', async () => {
  const { context, page, writes } = await signedIn(editUrl(SERVING));
  try {
    await editorReady(page);
    assert.equal(await page.$eval('#ocu-service-edit-Enabled', (node) => node.getAttribute('aria-disabled')), 'true', 'Service enabled is aria-disabled');
    assert.equal(await page.$eval('#ocu-service-edit-Enabled-refusal', (node) => node.textContent.trim()), STRINGS.serviceRefusalServing, 'with the published sentence');
    await page.click('#ocu-service-edit-Enabled');
    assert.equal(await page.$eval('#ocu-service-edit-Enabled', (node) => node.checked), true, 'a click leaves it on');
    await openTab(page, 'connections');
    assert.equal(await page.$('#ocu-service-edit-ClientSystems-effect'), null, 'no line before a change');
    await page.type('#ocu-service-edit-ClientSystems', '10.0.0.1');
    await page.click('[data-action="add-address"]');
    await page.waitForSelector('#ocu-service-edit-ClientSystems-effect', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('#ocu-service-edit-ClientSystems-effect', (node) => node.textContent.trim()), STRINGS.serviceEffectServesOcuPilot, 'the address change carries the served-through line');
    await page.click('app-service-editor-page .ocu-form-bar-actions .ocu-button-text');
    await page.waitForSelector('app-dialog [role="dialog"]', { timeout: config.navigationTimeoutMs });
    await page.click('app-dialog .ocu-dialog-actions .ocu-button-primary');
    await page.waitForFunction(() => window.location.pathname.endsWith('/permissions/services'), { timeout: config.navigationTimeoutMs });
    assert.deepEqual(writes, [], 'and nothing was sent');
  } finally {
    await context.close();
  }
  const serving = readBack(SERVING);
  assert.equal(serving.Enabled, true, 'the serving service is still enabled');
});

test('DW-1337: the editor passes the structural walk at an id route with each tab showing, in both themes', async () => {
  const { context, page } = await signedIn(editUrl(CACHEDIRECT));
  try {
    await editorReady(page);
    assert.deepEqual(await structural(page, ['general', 'methods', 'connections']), [], 'no violation beyond the baseline with the editor showing');
  } finally {
    await context.close();
  }
});

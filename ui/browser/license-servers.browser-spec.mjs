/**
 * License servers, the license server form and its delete in a real browser, against the throwaway
 * instance (Story 18.6).
 *
 * What it pins, each on rendered DOM, on the request the page sent, or on the instance itself:
 *
 * 1. **The list** (A7): OS management's sixteenth side-bar entry reads "License servers", and the
 *    list shows its four columns.
 * 2. **Create, edit and delete** (A5): from the list's Create, a probe server is created with its
 *    address and port, the address bar then names it in upper case, and the instance holds it; an
 *    edit of its port sends that field alone, the form shows the key directory read-only with its
 *    hint, and the instance holds the new port; the typed-name dialog states the published
 *    consequence, sends the delete, and the row leaves the list.
 * 3. **DW-1337** (A7): the list, the form and the Delete dialog pass the structural walk at wide
 *    light, narrow light and wide dark.
 * 4. **A refusal on its field** (A6): a create with port 0 stays on the form with the Port field
 *    marked and its reason shown, and nothing reaches the instance.
 *
 * **It refuses the live and development containers.** It touches only `OCUPROBE186*` license servers,
 * removing every probe object with `OcuPilot.Test.LicenseProbe.RemoveAll` before and after and
 * asserting none survives.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1
 * browser/license-servers.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();

const PROBE = 'OcuPilot.Test.LicenseProbe';

/** The probe server this spec creates, typed in lower case; the instance stores it in upper case. */
const TYPED = 'ocuprobe186u';
const SERVER = 'OCUPROBE186U';

const LIST_ROUTE = 'os-management/license-servers';
const FORM_ROUTE = 'os-management/license-servers/edit';
const LIST_URL = `/ocupilot/${LIST_ROUTE}?ns=HSCUSTOM`;
const SAVE_PATH = '/api/ocupilot/license-server';
const ACTION_PATH = '/api/ocupilot/screens/osmgmt.licenseservers/action';

/** The row cells' own text selector, a name cell being a link. */
const NAME_TEXT = '.ocu-data-table-link, .ocu-data-table-text';

let browser = null;

const mark = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/** Run `lines` in `HSCUSTOM` inside the throwaway and return the value each named marker carries. */
function iris(lines, names = []) {
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', 'HSCUSTOM'], {
    input: `${[...lines, 'Halt'].join('\n')}\n`,
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const values = {};
  for (const name of names) {
    const hit = new RegExp(`OCU-${name}-START:(.*?):OCU-${name}-END`).exec(output);
    values[name] = hit === null ? null : hit[1].trim();
  }
  return { values, output };
}

/** Remove every probe object and assert none survives. */
function removeAll() {
  const { values, output } = iris([`Set sc=##class(${PROBE}).RemoveAll(.r)`, mark('LEFT', `##class(${PROBE}).Remaining()`)], ['LEFT']);
  assert.equal(values.LEFT, '0', `no OCUPROBE186 object survives:\n${output}`);
}

/** Whether the instance holds the license server `name`, and its stored port. */
function stored(name) {
  const { values, output } = iris(
    [mark('EXISTS', `##class(${PROBE}).ServerExists("${name}")`), mark('PORT', `##class(${PROBE}).Stored("${name}","Port")`)],
    ['EXISTS', 'PORT']
  );
  assert.ok(values.EXISTS === '0' || values.EXISTS === '1', `the license server read answered:\n${output}`);
  return { exists: values.EXISTS === '1', port: values.PORT };
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates and deletes license servers, so it never runs inside the live container');
  assert.ok(!/^ocupilot-slot-/.test(config.container), 'nor inside a development instance');
  await assertThrowaway(config);
  removeAll();
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    if (config.container !== LIVE_CONTAINER) removeAll();
  }
});

/** The side bar as rendered: its area and its entry labels, opening it first. */
async function sideBarOf(page) {
  if ((await page.$('app-side-bar nav.ocu-side-bar')) === null) {
    await page.keyboard.down('Control');
    await page.keyboard.press('b');
    await page.keyboard.up('Control');
  }
  await page.waitForSelector('app-side-bar nav.ocu-side-bar', { timeout: config.navigationTimeoutMs });
  return page.evaluate(() => {
    const nav = document.querySelector('app-side-bar nav.ocu-side-bar');
    return {
      area: nav.querySelector('.ocu-side-bar-eyebrow').textContent.trim(),
      entries: Array.from(nav.querySelectorAll('.ocu-side-bar-item .ocu-side-bar-label')).map((label) => label.textContent.trim()),
    };
  });
}

/** Narrow the list to `name`, select its row and open its row menu. */
async function openRowMenu(page, name) {
  await waitForRows(page, config.navigationTimeoutMs);
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, name);
  await page.waitForFunction(
    (selector, wanted, textSelector) =>
      Array.from(document.querySelectorAll(selector)).some((row) => {
        const cell = row.querySelector('[role="gridcell"]');
        const text = cell.querySelector(textSelector);
        return (text === null ? cell : text).textContent.trim() === wanted;
      }),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name,
    NAME_TEXT
  );
  await clickRowCentre(page, { text: name, cell: 2 });
  await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
}

/** Open the Delete dialog on `name`'s row and answer its title and consequence. */
async function openDelete(page, name) {
  await openRowMenu(page, name);
  await page.evaluate((label) => {
    Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'))
      .find((item) => item.textContent.trim().startsWith(label))
      .click();
  }, STRINGS.actionDelete);
  await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
  return page.evaluate(() => ({
    title: document.querySelector('[role="dialog"] .ocu-dialog-title').textContent.trim(),
    consequence: document.querySelector('.ocu-typed-name-consequence').textContent.trim(),
  }));
}

/** Replace the text of input `selector` with `value`. */
async function retype(page, selector, value) {
  await page.click(selector, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  if (value !== '') await page.type(selector, value);
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

/**
 * DW-1337 on `route`: 1280 light (every invariant), 720 light and 1280 dark, against the baseline;
 * with a dialog open, also the dialog body's own sideways overflow.
 */
async function assertStructure(page, route, dialog = false) {
  const entriesFound = [];
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
    const { entries } = await detectScreen(page, { route, checks, viewport: viewport.width, theme, minimums });
    entriesFound.push(...entries);
    if (!dialog) continue;
    const body = await page.$eval('.ocu-dialog-body', (element) => ({ scroll: element.scrollWidth, client: element.clientWidth }));
    assert.ok(body.scroll <= body.client, `the dialog body does not scroll sideways at ${viewport.width}px ${theme}: ${JSON.stringify(body)}`);
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await frames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  const fresh = compare(collapse(entriesFound), readBaseline()?.entries ?? []).fresh;
  assert.deepEqual(fresh.map((entry) => `${entry.key}: ${entry.measured}`), [], `no structural or contrast violation on ${route}`);
}

// A6. Mutation (Rule 19): let LicenseRules.IsPort's shape match admit port 0, reload the throwaway
// -> the Port field never refuses and this goes red.
test('A6: a create with port 0 is refused on the Port field and nothing reaches the instance', async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${FORM_ROUTE}?ns=HSCUSTOM`, VIEWPORTS.wide);
  try {
    await page.waitForSelector('#ocu-license-server-Name', { visible: true, timeout: config.navigationTimeoutMs });
    await page.type('#ocu-license-server-Name', 'ocuprobe186v');
    await page.type('#ocu-license-server-Address', '127.0.0.1');
    await page.type('#ocu-license-server-Port', '0');
    await page.click('.ocu-form-bar-actions button.ocu-button-primary');
    await page.waitForFunction(
      () => document.querySelector('#ocu-license-server-Port')?.getAttribute('aria-invalid') === 'true' && (document.querySelector('#ocu-license-server-Port-reason')?.textContent ?? '').trim() !== '',
      { timeout: 90000 }
    );
    assert.equal(new URL(page.url()).pathname.endsWith(`/${FORM_ROUTE}`), true, 'the form stays open on the refusal');
    assert.equal(stored('OCUPROBE186V').exists, false, 'no license server was written');
  } finally {
    await context.close();
  }
});

// A7. Mutation (Rule 19): give LicenseServerList `sideBarPosition` 0 and regenerate the mirror,
// rebuild and redeploy -> the side-bar assertion goes red.
test('A7: License servers is the sixteenth OS management entry, lists its four columns, and passes DW-1337', async () => {
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  try {
    await page.waitForSelector('.ocu-data-table-header-label', { visible: true, timeout: config.navigationTimeoutMs });
    const bar = await sideBarOf(page);
    assert.equal(bar.area, STRINGS.navAreaOsManagement);
    // Story 18.20: ECP data servers follows it, and Story 18.21's two follow that.
    assert.equal(bar.entries.length, 19, `nineteen entries: ${JSON.stringify(bar.entries)}`);
    assert.equal(bar.entries[15], STRINGS.licenseServerListLabel, 'License servers is the sixteenth');
    const headers = await page.$$eval('.ocu-data-table-header-label', (labels) => labels.map((label) => label.textContent.trim()));
    assert.deepEqual(headers.slice(0, 4), [STRINGS.tableColumnName, STRINGS.languageServerFieldAddress, STRINGS.sslTestPort, STRINGS.licenseServerKeyDirectory]);
    await assertStructure(page, LIST_ROUTE);
  } finally {
    await context.close();
  }
});

// A5. Mutation (Rule 19): send every field in the form store's `changedFields`, rebuild and redeploy ->
// the edit's body assertion goes red.
test('A5: Create, edit and delete a probe license server through the UI; the form and the Delete dialog pass DW-1337', async () => {
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const saves = [];
  const actions = [];
  page.on('request', (request) => {
    const path = new URL(request.url()).pathname;
    if (request.method() !== 'GET' && path.startsWith(SAVE_PATH)) saves.push({ method: request.method(), path, body: JSON.parse(request.postData() ?? '{}') });
    if (request.method() === 'POST' && path === ACTION_PATH) actions.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    // Create, from the list's Create.
    await (await page.waitForSelector('.ocu-command-bar button.ocu-command-bar-primary', { visible: true, timeout: config.navigationTimeoutMs })).click();
    await page.waitForFunction((route) => new URL(window.location.href).pathname.endsWith(`/${route}`), { timeout: config.navigationTimeoutMs }, FORM_ROUTE);
    await page.waitForSelector('#ocu-license-server-Name', { visible: true, timeout: config.navigationTimeoutMs });
    await page.type('#ocu-license-server-Name', TYPED);
    await page.type('#ocu-license-server-Address', '127.0.0.1');
    await page.type('#ocu-license-server-Port', '4999');
    await assertStructure(page, FORM_ROUTE);
    await page.click('.ocu-form-bar-actions button.ocu-button-primary');
    await page.waitForFunction(
      (route, name) => new URL(window.location.href).pathname.endsWith(`/${route}/${name}`),
      { timeout: 90000 },
      FORM_ROUTE,
      SERVER
    );
    assert.deepEqual(saves[0], { method: 'POST', path: SAVE_PATH, body: { Name: TYPED, Address: '127.0.0.1', Port: 4999 } });
    let held = stored(SERVER);
    assert.equal(held.exists, true, 'the instance holds the new license server, its name in upper case');
    assert.equal(held.port, '4999');

    // Edit its port: the form shows the key directory read-only, and the edit sends the port alone.
    await page.waitForSelector('#ocu-license-server-KeyDirectory', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('#ocu-license-server-KeyDirectory', (input) => input.readOnly), true);
    assert.equal(await page.$eval('#ocu-license-server-KeyDirectory-hint', (node) => node.textContent.trim()), STRINGS.licenseServerKeyDirectoryHint);
    await retype(page, '#ocu-license-server-Port', '4998');
    await page.click('.ocu-form-bar-actions button.ocu-button-primary');
    await page.waitForFunction(() => (document.querySelector('.ocu-form-bar-status [role="status"]')?.textContent ?? '').trim() !== '', { timeout: 90000 });
    assert.deepEqual(saves[1], { method: 'PUT', path: `${SAVE_PATH}/${SERVER}`, body: { Port: 4998 } });
    held = stored(SERVER);
    assert.equal(held.port, '4998', 'the instance holds the new port');

    // Delete, through the typed-name dialog on the list.
    await page.goto(`${config.origin}${LIST_URL}`, { waitUntil: 'networkidle2' });
    const dialog = await openDelete(page, SERVER);
    assert.deepEqual(dialog, { title: `${STRINGS.actionDelete} ${SERVER}`, consequence: STRINGS.licenseServerDeleteConsequence });
    await assertStructure(page, LIST_ROUTE, true);
    assert.deepEqual(actions, [], 'nothing is sent while the dialog is open');
    await page.type('.ocu-typed-name-field', SERVER);
    await page.keyboard.press('Enter');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: 90000 });
    await page.waitForFunction(
      (selector, name) => !Array.from(document.querySelectorAll(selector)).some((row) => row.textContent.includes(name)),
      { timeout: 90000 },
      ROW_SELECTOR,
      SERVER
    );
    assert.deepEqual(actions, [{ action: 'delete', id: SERVER }]);
    assert.equal(stored(SERVER).exists, false, 'the license server is gone');
  } finally {
    await context.close();
  }
});

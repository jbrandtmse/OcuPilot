/**
 * ECP data servers, the data server form, its delete and its Change status dialog in a real browser,
 * against the throwaway instance (Story 18.20).
 *
 * What it pins, each on rendered DOM, on the request the page sent, or on the instance itself:
 *
 * 1. **The list** (B1, B7): OS management's seventeenth side-bar entry reads "ECP data servers", the
 *    page says each status is what the instance reported when the list was read, and a seeded probe
 *    data server is listed Not Connected under the seven columns.
 * 2. **A refusal on its field** (B2): a create whose address `Config.Host` would not store stays on
 *    the form with the Address field marked and its reason shown, and nothing reaches the instance.
 * 3. **Create, edit and delete** (B2, B3): from the list's Create a probe server is created at the
 *    default port, the address bar then names it in upper case and the instance holds it; an edit of
 *    Batch mode sends that field alone and the instance holds it; the typed-name dialog deletes it;
 *    and the Delete of a seeded server a seeded remote database uses names that remote database as
 *    its advisory and is refused, the server kept.
 * 4. **Change status** (B4, B5): the dialog names the current status, draws the current one and an
 *    unlicensed Normal unavailable with their reasons, changes the seeded server to Disabled and back
 *    to Not connected, and the list and the instance show each.
 * 5. **DW-1337** (B7): the list, the form and both dialogs pass the structural walk at wide light,
 *    narrow light and wide dark.
 *
 * **It refuses the live and development containers.** It touches only `OCUPROBEECP*` objects, holds at
 * most two probe data servers at any moment (the instance's limit), points each at a TEST-NET-1
 * address on port 1972 so no write can connect anywhere, never chooses Normal, and removes every probe
 * object with `OcuPilot.Test.EcpProbe.RemoveAll` before and after each test, asserting none survives
 * and no ECP process runs.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1
 * browser/ecp-data-servers.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const repoRoot = join(uiRoot, '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();

/** A published server sentence, read from its class rather than restated here. */
function serverSentence(file, parameter) {
  const source = readFileSync(join(repoRoot, 'src', 'OcuPilot', ...file.split('/')), 'utf8');
  const found = new RegExp(`Parameter ${parameter} = "([^"]+)";`).exec(source);
  assert.notEqual(found, null, `${file} declares ${parameter}`);
  return found[1];
}

const INUSE_REASON = serverSentence('Api/EcpError.cls', 'REASONINUSE');
const ADDRESS_REASON = serverSentence('Api/EcpError.cls', 'REASONADDRESS');

const PROBE = 'OcuPilot.Test.EcpProbe';

/** The probe server the UI creates, typed in lower case; the instance stores it in upper case. */
const TYPED = 'ocuprobeecpu';
const SERVER = 'OCUPROBEECPU';
/** The seeded probe server, and the seeded remote database that uses it in the in-use leg. */
const SEEDED = 'OCUPROBEECPA';
const REMOTE = 'OCUPROBEECPR';
/** The name the refused create types; nothing of that name is ever stored. */
const NEVER = 'OCUPROBEECPV';

/** A TEST-NET-1 address (RFC 5737), which no configuration write can connect to, on an in-range port. */
const ADDRESS = '192.0.2.10';
const PORT = 1972;

const LIST_ROUTE = 'os-management/ecp-data-servers';
const FORM_ROUTE = 'os-management/ecp-data-servers/edit';
const LIST_URL = `/ocupilot/${LIST_ROUTE}?ns=HSCUSTOM`;
const SAVE_PATH = '/api/ocupilot/ecp-data-server';
const ACTION_PATH = '/api/ocupilot/screens/osmgmt.ecpdataservers/action';

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
    const found = new RegExp(`OCU-${name}-START:(.*?):OCU-${name}-END`).exec(output);
    values[name] = found === null ? null : found[1].trim();
  }
  return { values, output };
}

/** Remove every probe object, and assert none survives and no ECP process runs. */
function removeAll() {
  const { values, output } = iris(
    [`Set sc=##class(${PROBE}).RemoveAll(.r)`, mark('LEFT', `##class(${PROBE}).Remaining()`), mark('JOBS', `##class(${PROBE}).EcpJobs()`)],
    ['LEFT', 'JOBS']
  );
  assert.equal(values.LEFT, '0', `no OCUPROBEECP object survives:\n${output}`);
  assert.equal(values.JOBS, '0', `no ECP process runs:\n${output}`);
}

/** Run one seeding call of the probe class, asserting it answered OK. */
function seed(call) {
  const { values, output } = iris([`Set sc=##class(${PROBE}).${call}`, mark('SEED', '$Select($System.Status.IsOK(sc):"ok",1:$System.Status.GetErrorText(sc))')], ['SEED']);
  assert.equal(values.SEED, 'ok', `${call} answered OK:\n${output}`);
}

/** Whether the instance holds the data server `name`, read through the admin API. */
function holds(name) {
  const { values, output } = iris([mark('HOLDS', `##class(${PROBE}).Holds("${name}")`)], ['HOLDS']);
  assert.ok(values.HOLDS === '0' || values.HOLDS === '1', `the data server read answered a holding or a 404:\n${output}`);
  return values.HOLDS === '1';
}

/** The data server `name`'s stored `field`, as the vendor's own read answers it, or `''`. */
function stored(name, field) {
  const call = `##class(${PROBE}).Stored("${name}")`;
  const { values, output } = iris([mark('FIELD', `$Select($IsObject(${call}):${call}.%Get("${field}"),1:"")`)], ['FIELD']);
  assert.notEqual(values.FIELD, null, `the data server read answered:\n${output}`);
  return values.FIELD;
}

/** The data server `name`'s connection state (1 Not Connected, 4 Disabled). */
function connState(name) {
  const { values, output } = iris([mark('STATE', `##class(${PROBE}).ConnState("${name}")`)], ['STATE']);
  assert.notEqual(values.STATE, null, `the connection state read answered:\n${output}`);
  return values.STATE;
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates and deletes ECP data servers, so it never runs inside the live container');
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

/** The rendered row whose name cell reads `name`, as its seven cells' text, or `null`. */
function rowCells(page, name) {
  return page.evaluate(
    (selector, wanted, textSelector) => {
      const row = Array.from(document.querySelectorAll(selector)).find((candidate) => {
        const cell = candidate.querySelector('[role="gridcell"]');
        const text = cell?.querySelector(textSelector);
        return ((text ?? cell)?.textContent ?? '').trim() === wanted;
      });
      if (row === undefined) return null;
      return Array.from(row.querySelectorAll('[role="gridcell"]'))
        .slice(0, 7)
        .map((cell) => cell.textContent.trim());
    },
    ROW_SELECTOR,
    name,
    NAME_TEXT
  );
}

/** Wait until `name`'s row reads `status` in its Status cell, the fourth. */
async function waitForStatus(page, name, status) {
  await page.waitForFunction(
    (selector, wanted, textSelector, expected) =>
      Array.from(document.querySelectorAll(selector)).some((row) => {
        const cells = Array.from(row.querySelectorAll('[role="gridcell"]'));
        const text = cells[0]?.querySelector(textSelector);
        return ((text ?? cells[0])?.textContent ?? '').trim() === wanted && (cells[3]?.textContent ?? '').trim() === expected;
      }),
    { timeout: 90000 },
    ROW_SELECTOR,
    name,
    NAME_TEXT,
    status
  );
}

/**
 * Narrow the list to `name`, select its row and open its row menu. The filter is cleared before the
 * rows are awaited: a filter left from an earlier row can match no row at all.
 */
async function openRowMenu(page, name) {
  await page.waitForSelector(FILTER_SELECTOR, { visible: true, timeout: config.navigationTimeoutMs });
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await waitForRows(page, config.navigationTimeoutMs);
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

/** Choose the row menu entry whose label starts `label`. */
async function chooseMenuItem(page, label) {
  await page.evaluate((wanted) => {
    Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'))
      .find((item) => item.textContent.trim().startsWith(wanted))
      .click();
  }, label);
}

/** Open the Delete dialog on `name`'s row and answer its title, consequence and advisory once the advisory reads `expectedAdvisory`. */
async function openDelete(page, name, expectedAdvisory) {
  await openRowMenu(page, name);
  await chooseMenuItem(page, STRINGS.actionDelete);
  await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
  await page.waitForFunction(
    (wanted) => (document.querySelector('[role="dialog"] [data-slot="advisory"] .ocu-banner-message')?.textContent ?? '').trim() === wanted,
    { timeout: config.navigationTimeoutMs },
    expectedAdvisory
  );
  return page.evaluate(() => ({
    title: document.querySelector('[role="dialog"] .ocu-dialog-title').textContent.trim(),
    consequence: document.querySelector('.ocu-typed-name-consequence').textContent.trim(),
    advisory: (document.querySelector('[role="dialog"] [data-slot="advisory"] .ocu-banner-message')?.textContent ?? '').trim(),
  }));
}

/** Type the server's name into the open dialog and confirm, then wait for the dialog to close. */
async function confirmDelete(page, name) {
  await page.type('.ocu-typed-name-field', name);
  await page.keyboard.press('Enter');
  await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: 90000 });
}

/** The advisory a data server delete states for the remote databases that use it (none, or one). */
function impactLine(remotes) {
  const part =
    remotes.length === 0
      ? STRINGS.impactRemoteDatabasesUseNone
      : STRINGS.impactRemoteDatabasesUseOne.replace('<names>', () => remotes.join(', '));
  return STRINGS.impactLine.replace('<parts>', () => part);
}

/** Open Change status on `name`'s row and answer what its dialog draws. */
async function openChangeStatus(page, name) {
  await openRowMenu(page, name);
  await chooseMenuItem(page, STRINGS.ecpDataServerChangeStatus);
  await page.waitForSelector('app-ecp-data-server-status-dialog [role="dialog"]', { visible: true, timeout: config.navigationTimeoutMs });
  return page.evaluate(() => {
    const dialog = document.querySelector('app-ecp-data-server-status-dialog [role="dialog"]');
    const choice = (status) => {
      const input = dialog.querySelector(`[data-status="${status}"] input`);
      const reasonId = input.getAttribute('aria-describedby');
      return {
        disabled: input.getAttribute('aria-disabled') === 'true',
        checked: input.checked,
        reason: reasonId === null ? '' : (document.getElementById(reasonId)?.textContent ?? '').trim(),
      };
    };
    return {
      title: dialog.querySelector('.ocu-dialog-title').textContent.trim(),
      current: dialog.querySelector('.ocu-ecp-status-current').textContent.trim(),
      notconnected: choice('notconnected'),
      disabled: choice('disabled'),
      normal: choice('normal'),
    };
  });
}

/** Choose `status` in the open Change status dialog. */
async function chooseStatus(page, status) {
  await page.click(`app-ecp-data-server-status-dialog [data-status="${status}"] input`);
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
    const { entries } = await detectScreen(page, { route, checks, viewport: viewport.width, theme, minimums });
    found.push(...entries);
    if (!dialog) continue;
    const body = await page.$eval('.ocu-dialog-body', (element) => ({ scroll: element.scrollWidth, client: element.clientWidth }));
    assert.ok(body.scroll <= body.client, `the dialog body does not scroll sideways at ${viewport.width}px ${theme}: ${JSON.stringify(body)}`);
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await frames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  const fresh = compare(collapse(found), readBaseline()?.entries ?? []).fresh;
  assert.deepEqual(fresh.map((entry) => `${entry.key}: ${entry.measured}`), [], `no structural or contrast violation on ${route}`);
}

// B1, B7. Mutation (Rule 19): give EcpDataServerList `sideBarPosition` 0 and regenerate the mirror,
// rebuild and redeploy -> the side-bar assertion goes red.
test('B1, B7: ECP data servers is the seventeenth OS management entry, says what each status is, lists the seeded server, and passes DW-1337', async () => {
  removeAll();
  seed(`SeedServer("${SEEDED}")`);
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const bar = await sideBarOf(page);
    assert.equal(bar.area, STRINGS.navAreaOsManagement);
    assert.equal(bar.entries.length, 17, `seventeen entries: ${JSON.stringify(bar.entries)}`);
    assert.equal(bar.entries[16], STRINGS.ecpDataServerListLabel, 'ECP data servers is the seventeenth');
    assert.equal(await page.$eval('[data-ecp="caveat"]', (node) => node.textContent.trim()), STRINGS.ecpDataServerStatusCaveat);
    const headers = await page.$$eval('.ocu-data-table-header-label', (labels) => labels.map((label) => label.textContent.trim()));
    assert.deepEqual(headers.slice(0, 7), [
      STRINGS.tableColumnName,
      STRINGS.languageServerFieldAddress,
      STRINGS.sslTestPort,
      STRINGS.taskHistoryColumnStatus,
      STRINGS.ecpDataServerMirrorConnection,
      STRINGS.sslListLabel,
      STRINGS.ecpDataServerBatchMode,
    ]);
    const cells = await rowCells(page, SEEDED);
    assert.notEqual(cells, null, 'the seeded data server is listed');
    assert.deepEqual(cells.slice(0, 4), [SEEDED, ADDRESS, String(PORT), 'Not Connected'], 'at its address and port, as the instance reported its status');
    await assertStructure(page, LIST_ROUTE);
  } finally {
    await context.close();
    removeAll();
  }
});

// B2. Mutation (Rule 19): let EcpRules.Validate admit any address, reload the throwaway -> the
// Address field never refuses and this goes red.
test('B2: a create whose address the instance would not store is refused on the Address field and nothing reaches the instance', async () => {
  removeAll();
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${FORM_ROUTE}?ns=HSCUSTOM`, VIEWPORTS.wide);
  try {
    await page.waitForSelector('#ocu-ecp-data-server-Name', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('#ocu-ecp-data-server-Port', (input) => input.value), String(PORT), 'a create offers the default port');
    await page.type('#ocu-ecp-data-server-Name', NEVER.toLowerCase());
    await page.type('#ocu-ecp-data-server-Address', 'my host');
    await page.click('.ocu-form-bar-actions button.ocu-button-primary');
    await page.waitForFunction(
      () => document.querySelector('#ocu-ecp-data-server-Address')?.getAttribute('aria-invalid') === 'true',
      { timeout: 90000 }
    );
    assert.equal(await page.$eval('#ocu-ecp-data-server-Address-reason', (node) => node.textContent.trim()), ADDRESS_REASON);
    assert.equal(new URL(page.url()).pathname.endsWith(`/${FORM_ROUTE}`), true, 'the form stays open on the refusal');
    assert.equal(holds(NEVER), false, 'no data server was written');
  } finally {
    await context.close();
    removeAll();
  }
});

// B2, B3. Mutation (Rule 19): drop ECP_DATA_SERVER_LIST from IMPACT_ACTIONS in screen-action-handler.ts,
// rebuild and redeploy -> the Delete dialogs open with no advisory and the advisory waits go red.
test('B2, B3: create, edit and delete a probe server through the UI; the in-use delete names its remote database and is refused; the form and the dialog pass DW-1337', async () => {
  removeAll();
  // Two probe data servers at most: the seeded one carrying the remote database, and the one the UI creates.
  seed(`SeedRemote("${REMOTE}","${SEEDED}")`);
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const saves = [];
  const actions = [];
  page.on('request', (request) => {
    const path = new URL(request.url()).pathname;
    if (request.method() !== 'GET' && path.startsWith(SAVE_PATH)) saves.push({ method: request.method(), path, body: JSON.parse(request.postData() ?? '{}') });
    if (request.method() === 'POST' && path === ACTION_PATH) actions.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    // Create, from the list's Create, at the default port.
    await (await page.waitForSelector('.ocu-command-bar button.ocu-command-bar-primary', { visible: true, timeout: config.navigationTimeoutMs })).click();
    await page.waitForFunction((route) => new URL(window.location.href).pathname.endsWith(`/${route}`), { timeout: config.navigationTimeoutMs }, FORM_ROUTE);
    await page.waitForSelector('#ocu-ecp-data-server-Name', { visible: true, timeout: config.navigationTimeoutMs });
    await page.type('#ocu-ecp-data-server-Name', TYPED);
    await page.type('#ocu-ecp-data-server-Address', ADDRESS);
    assert.equal(await page.$eval('#ocu-ecp-data-server-Port', (input) => input.value), String(PORT));
    await assertStructure(page, FORM_ROUTE);
    await page.click('.ocu-form-bar-actions button.ocu-button-primary');
    await page.waitForFunction(
      (route, name) => new URL(window.location.href).pathname.endsWith(`/${route}/${name}`),
      { timeout: 90000 },
      FORM_ROUTE,
      SERVER
    );
    assert.deepEqual(saves[0], {
      method: 'POST',
      path: SAVE_PATH,
      body: { Name: TYPED, Address: ADDRESS, Port: PORT, MirrorConnection: 0, SSLConfig: 0, BatchMode: false },
    });
    assert.equal(holds(SERVER), true, 'the instance holds the new data server, its name in upper case');

    // Edit Batch mode: the edit sends that field alone, and the instance holds it.
    await page.waitForSelector('#ocu-ecp-data-server-BatchMode', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('#ocu-ecp-data-server-Name', (input) => input.readOnly), true, 'the name is never changed');
    assert.equal(await page.$eval('#ocu-ecp-data-server-BatchMode', (input) => input.checked), false);
    await page.click('#ocu-ecp-data-server-BatchMode');
    await page.click('.ocu-form-bar-actions button.ocu-button-primary');
    await page.waitForFunction(() => (document.querySelector('.ocu-form-bar-status [role="status"]')?.textContent ?? '').trim() !== '', { timeout: 90000 });
    assert.deepEqual(saves[1], { method: 'PUT', path: `${SAVE_PATH}/${SERVER}`, body: { BatchMode: true } });
    assert.equal(stored(SERVER, 'BatchMode'), '1', 'the instance holds batch mode on');
    assert.equal(stored(SERVER, 'Port'), String(PORT), 'and the port it had');

    // Delete the unused one through the typed-name dialog on the list.
    await page.goto(`${config.origin}${LIST_URL}`, { waitUntil: 'networkidle2' });
    const unused = await openDelete(page, SERVER, impactLine([]));
    assert.deepEqual(unused, { title: `${STRINGS.actionDelete} ${SERVER}`, consequence: STRINGS.ecpDataServerDeleteConsequence, advisory: impactLine([]) });
    assert.deepEqual(actions, [], 'nothing is sent while the dialog is open');
    await confirmDelete(page, SERVER);
    await page.waitForFunction(
      (selector, name) => !Array.from(document.querySelectorAll(selector)).some((row) => row.textContent.includes(name)),
      { timeout: 90000 },
      ROW_SELECTOR,
      SERVER
    );
    assert.deepEqual(actions, [{ action: 'delete', id: SERVER }]);
    assert.equal(holds(SERVER), false, 'the data server is gone');

    // The in-use one: the advisory names the remote database, and the instance refuses the delete.
    const inUse = await openDelete(page, SEEDED, impactLine([REMOTE]));
    assert.deepEqual(inUse, { title: `${STRINGS.actionDelete} ${SEEDED}`, consequence: STRINGS.ecpDataServerDeleteConsequence, advisory: impactLine([REMOTE]) });
    await assertStructure(page, LIST_ROUTE, true);
    await confirmDelete(page, SEEDED);
    await page.waitForFunction(
      (wanted) => (document.querySelector('.ocu-list-page-banner[role="alert"] .ocu-banner-message')?.textContent ?? '').trim() === wanted,
      { timeout: 90000 },
      INUSE_REASON
    );
    assert.deepEqual(actions.at(-1), { action: 'delete', id: SEEDED });
    assert.equal(holds(SEEDED), true, 'the data server a remote database uses stays');
  } finally {
    await context.close();
    removeAll();
  }
});

// B4, B5. Mutation (Rule 19): send `values: { Status: 'normal' }` whatever the dialog chose in the list
// page's `onChange`, rebuild and redeploy -> the instance refuses ECP.LICENSE, the dialog stays open and
// the Disabled wait goes red. Never choose Normal itself: no instance here may be sent Action 3.
test('B4, B5: Change status draws the current status and an unlicensed Normal unavailable, changes the server to Disabled and back, and passes DW-1337', async () => {
  removeAll();
  seed(`SeedServer("${SEEDED}")`);
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const actions = [];
  page.on('request', (request) => {
    if (request.method() === 'POST' && new URL(request.url()).pathname === ACTION_PATH) actions.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    const opened = await openChangeStatus(page, SEEDED);
    assert.equal(opened.title, STRINGS.ecpDataServerStatusTitle.replace('<name>', () => SEEDED));
    assert.equal(opened.current, STRINGS.ecpDataServerCurrentStatus.replace('<status>', () => 'Not Connected'));
    assert.deepEqual(opened.notconnected, { disabled: true, checked: false, reason: STRINGS.ecpDataServerCurrentReason });
    assert.deepEqual(opened.disabled, { disabled: false, checked: false, reason: '' });
    assert.deepEqual(opened.normal, { disabled: true, checked: false, reason: STRINGS.ecpLicenseRefusal });
    // A click on the unavailable Normal selects nothing.
    await chooseStatus(page, 'normal');
    assert.equal(await page.$eval('app-ecp-data-server-status-dialog [data-status="normal"] input', (input) => input.checked), false, 'Normal is never chosen');
    assert.equal(
      await page.$eval('.ocu-ecp-status-submit', (button) => button.getAttribute('aria-disabled')),
      'true',
      'and Change status stays unavailable'
    );
    await chooseStatus(page, 'disabled');
    await page.waitForSelector('.ocu-ecp-status-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-ecp-status-consequence', (node) => node.textContent.trim()), STRINGS.ecpDataServerDisconnectConsequence);
    await assertStructure(page, LIST_ROUTE, true);
    assert.deepEqual(actions, [], 'nothing is sent while the dialog is open');
    await page.click('.ocu-ecp-status-submit');
    await page.waitForFunction(() => document.querySelector('app-ecp-data-server-status-dialog') === null, { timeout: 90000 });
    await waitForStatus(page, SEEDED, 'Disabled');
    assert.deepEqual(actions, [{ action: 'changestatus', id: SEEDED, values: { Status: 'disabled' } }]);
    assert.equal(connState(SEEDED), '4', 'the instance reads it Disabled');

    // And back to Not connected, from a fresh read: the changed row's mark joins its name cell's text.
    await page.goto(`${config.origin}${LIST_URL}`, { waitUntil: 'networkidle2' });
    await waitForStatus(page, SEEDED, 'Disabled');
    const again = await openChangeStatus(page, SEEDED);
    assert.equal(again.current, STRINGS.ecpDataServerCurrentStatus.replace('<status>', () => 'Disabled'));
    assert.deepEqual(again.disabled, { disabled: true, checked: false, reason: STRINGS.ecpDataServerCurrentReason });
    assert.deepEqual(again.notconnected, { disabled: false, checked: false, reason: '' });
    await chooseStatus(page, 'notconnected');
    await page.click('.ocu-ecp-status-submit');
    await page.waitForFunction(() => document.querySelector('app-ecp-data-server-status-dialog') === null, { timeout: 90000 });
    await waitForStatus(page, SEEDED, 'Not Connected');
    assert.deepEqual(actions.at(-1), { action: 'changestatus', id: SEEDED, values: { Status: 'notconnected' } });
    assert.equal(connState(SEEDED), '1', 'the instance reads it Not Connected');
    assert.ok(actions.every((action) => action.values?.Status !== 'normal'), 'Normal was never sent');
  } finally {
    await context.close();
    removeAll();
  }
});

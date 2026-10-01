/**
 * Story 16.25 in a real browser, against the throwaway instance: the external language server editor
 * (AD-3, AD-4, AD-21, AD-55).
 *
 * What it pins, on rendered DOM, on the real URL or on the instance itself:
 *
 * 1. **Create, edit and delete through the screens** (AC1, AC2, AC4, AC9): the list's Create opens
 *    the form; a Java probe is saved with a name, a port and JVM arguments, and the instance holds
 *    them with the type's Resource default; the list shows its row; the name cell opens its editor with Name and
 *    Type fixed, whose Port change sends that field alone and keeps the rest; the editor's Activity
 *    log link opens the server's log and Back returns to it; the row's Delete, typed by the name,
 *    removes the server from the instance and the list.
 * 2. **Each type's own fields** (AC1): Python and .NET offer their settable members, with the file
 *    locations read-only under the published caption.
 * 3. **A started probe's editor reads only** (AC3), stating the running sentence; the probe is then
 *    stopped.
 * 4. **DW-1337** (AC9): the create form and the edit form pass the structural walk at wide light,
 *    narrow light and wide dark, with no entry beyond the baseline.
 *
 * **It creates, starts, stops and deletes probe servers**, so it runs on a throwaway only. Each is
 * named `OcuPilotProbeELS*`, and every one is stopped, deleted and its activity rows removed before
 * and after, whatever the tests answered. No vendor `%` server is touched. Every probe port sits
 * below the container's ephemeral port range, which `before` reads and asserts, so no outbound
 * connection's source port can hold the port a probe starts on.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1
 * browser/language-server-editor.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { authHeader, saveAndSettle, signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();

const LIST_ROUTE = 'os-management/language-servers';
const FORM_ROUTE = 'os-management/language-servers/edit';
const ACTIVITY_ROUTE = 'os-management/language-servers/activity';
const LIST_URL = `/ocupilot/${LIST_ROUTE}?ns=HSCUSTOM`;
const CREATE_URL = `/ocupilot/${FORM_ROUTE}?ns=HSCUSTOM`;
const SAVE_PATH = '/api/ocupilot/language-server';
const ACTION_PATH = '/api/ocupilot/screens/osmgmt.languageservers/action';
const ID = 'ocu-language-server';

/** The server the create leg makes, and the one `before` seeds for the running and walk legs. */
const CREATED = 'OcuPilotProbeELSEditor';
const SEEDED = 'OcuPilotProbeELSSeeded';
const CREATED_PORT = 31294;
const EDITED_PORT = 31295;
const SEEDED_PORT = 31296;
/** The kernel file whose first number is the low bound of the container's ephemeral port range. */
const PORT_RANGE_FILE = '/proc/sys/net/ipv4/ip_local_port_range';
const JVM_ARGS = '-Xmx48m';
/** A start blocks until the Java server answers, about 11 s here. */
const START_TIMEOUT_MS = 90000;

const NAME_TEXT = '.ocu-data-table-link, .ocu-data-table-text';

let browser = null;

/** One call to the throwaway's own admin API as the configured account; answers the status and the parsed body, `null` when it is not JSON. */
async function adminAnswer(method, path, body = null) {
  const answer = await fetch(`${config.origin}/api/admin/v2${path}`, {
    method,
    headers: { Authorization: authHeader(config), 'Content-Type': 'application/json' },
    body: body === null ? undefined : JSON.stringify(body),
  });
  const text = await answer.text();
  let parsed = null;
  try {
    parsed = JSON.parse(text);
  } catch {
    parsed = null;
  }
  return { status: answer.status, body: parsed };
}

/** The same call, answering the status alone. */
async function adminApi(method, path, body = null) {
  return (await adminAnswer(method, path, body)).status;
}

/** The admin API's HTML console text as plain lines: `<br>` ends a line and entities read as their characters. */
function consoleLines(html) {
  return String(html)
    .split(/<br\s*\/?>/i)
    .map((line) =>
      line
        .replace(/&nbsp;/g, ' ')
        .replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>')
        .replace(/&quot;/g, '"')
        .replace(/&#x([0-9a-f]+);/gi, (_, code) => String.fromCodePoint(parseInt(code, 16)))
        .replace(/&#(\d+);/g, (_, code) => String.fromCodePoint(Number(code)))
        .replace(/&amp;/g, '&')
        .trim()
    )
    .filter((line) => line !== '');
}

/** The vendor's own reason for a refused admin API call: its `status.errors` text and the console's last lines. */
function vendorReason(body) {
  const errors = (body?.status?.errors ?? []).map((entry) => String(entry?.error ?? '').replace(/\s+/g, ' ').trim()).filter((text) => text !== '');
  const lines = (body?.console ?? []).flatMap(consoleLines).slice(-3);
  return `${errors.join('; ') || 'no status.errors'} | console: ${lines.join(' / ') || 'none'}`;
}

/** The low bound of `container`'s ephemeral port range, the first number in `PORT_RANGE_FILE`; fails naming the file when it cannot be read. */
function ephemeralLow(container) {
  const result = spawnSync('docker', ['exec', container, 'cat', PORT_RANGE_FILE], { encoding: 'utf8', timeout: 60000 });
  const low = Number(/^\s*(\d+)/.exec(result.stdout ?? '')?.[1]);
  assert.ok(result.status === 0 && Number.isInteger(low), `${PORT_RANGE_FILE} is read in ${container}: ${result.stderr ?? ''}${result.error?.message ?? ''}`);
  return low;
}

/** Stop the probe server `name`, delete it and remove its activity rows, asserting none is left. */
async function removeServer(name) {
  const query = encodeURIComponent(name);
  const stopped = await adminApi('POST', `/ext-lang-server/stop?name=${query}`);
  // A deleted running server keeps listening, so nothing is deleted unless the stop answered.
  assert.ok(stopped === 200 || stopped === 404, `${name} stops, or is absent (HTTP ${stopped})`);
  await adminApi('DELETE', `/ext-lang-server?name=${query}`);
  const output = runIris(config.container, [
    'Set $NAMESPACE="%SYS"',
    `Set rs=##class(%SQL.Statement).%ExecDirect(,"DELETE FROM %Net_Remote.ActivityLog WHERE %EXACT(GatewayName) = ?","${name}")`,
    `Write "OCU-ELSEDGONE-START:"_('##class(Config.Gateways).Exists("${name}"))_(rs.%SQLCODE>=0)_":OCU-ELSEDGONE-END",!`,
  ]);
  assert.equal(markerValue(output, 'ELSEDGONE'), '11', `${name} and its activity rows are removed: ${output}`);
}

/** The instance's `Type|Port|Resource|JVMArgs` for server `name`, or `null` when it holds none. */
function stored(name) {
  const output = runIris(config.container, [
    'Set $NAMESPACE="%SYS"',
    `Kill p Set sc=##class(Config.Gateways).Get("${name}",.p)`,
    'Write "OCU-ELSEDHELD-START:"_$Select(sc:$Get(p("Type"))_"|"_$Get(p("Port"))_"|"_$Get(p("Resource"))_"|"_$Get(p("JVMArgs")),1:"<absent>")_":OCU-ELSEDHELD-END",!',
  ]);
  const value = markerValue(output, 'ELSEDHELD');
  assert.notEqual(value, null, `the server read answered: ${output}`);
  return value === '<absent>' ? null : value;
}

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/** The DW-1337 walk of `route` at 1280 light, 720 light and 1280 dark, answering every entry the baseline does not hold. */
async function structural(page, route) {
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
    const { entries } = await detectScreen(page, { route, checks, viewport: viewport.width, theme, minimums });
    found.push(...entries);
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await frames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  return compare(collapse(found), readBaseline()?.entries ?? []).fresh.map((entry) => `${entry.key}: ${entry.measured}`);
}

/** The ids of the form's controls that take input, in drawing order. */
function inputs(page) {
  return page.$$eval('.ocu-form-fields input, .ocu-form-fields select', (nodes) =>
    nodes.filter((node) => !(node.tagName === 'INPUT' && node.readOnly) && !node.disabled).map((node) => node.id)
  );
}

/** The ids of the read-only file locations, each described by the classic caption. */
function locations(page) {
  return page.$$eval(`.ocu-form-fields input[aria-describedby="${ID}-classic-caption"]`, (nodes) =>
    nodes.map((node) => `${node.id}${node.readOnly ? '' : ':editable'}`)
  );
}

/** Wait until the path ends with `suffix`. */
function pathEnds(page, suffix) {
  return page.waitForFunction((wanted) => new URL(window.location.href).pathname.endsWith(wanted), { timeout: config.navigationTimeoutMs }, suffix);
}

/** Narrow the list to `name` and wait for its one row. */
async function filterTo(page, name) {
  await waitForRows(page, config.navigationTimeoutMs);
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, name);
  await page.waitForFunction(
    (selector, wanted, textSelector) =>
      Array.from(document.querySelectorAll(selector)).some((row) => {
        const cell = row.querySelector('[role="gridcell"]');
        const text = cell?.querySelector(textSelector);
        return ((text ?? cell)?.textContent ?? '').trim() === wanted;
      }),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name,
    NAME_TEXT
  );
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec creates, starts, stops and deletes probe servers, so it runs only in a throwaway; ${config.container} is not one`);
  const low = ephemeralLow(config.container);
  for (const port of [CREATED_PORT, EDITED_PORT, SEEDED_PORT]) {
    assert.ok(port < low, `probe port ${port} is below ${config.container}'s ephemeral port range, which starts at ${low}`);
  }
  for (const name of [CREATED, SEEDED]) await removeServer(name);
  const status = await adminApi('PUT', `/ext-lang-server?name=${encodeURIComponent(SEEDED)}`, { Type: 'Java', Port: SEEDED_PORT });
  assert.equal(status, 201, `the seeded probe server is created (HTTP ${status})`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (/-ci$/.test(config.container)) {
      for (const name of [CREATED, SEEDED]) await removeServer(name);
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

// AC1, AC2, AC4, AC9. Mutation (Rule 19): drop the Activity link from the editor's template, rebuild
// and redeploy -> the link wait goes red.
test('AC1, AC2, AC4: Create saves a Java probe with its type default, the name opens its editor, a Port change sends one field, the Activity log is linked, and Delete removes it', async () => {
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const loads = [];
  page.on('load', () => loads.push(page.url()));
  const saves = [];
  const actions = [];
  page.on('request', (request) => {
    const path = new URL(request.url()).pathname;
    if (request.method() !== 'GET' && (path === SAVE_PATH || path.startsWith(`${SAVE_PATH}/`))) saves.push({ method: request.method(), path, body: request.postData() ?? '' });
    if (path === ACTION_PATH) actions.push(request.postData() ?? '');
  });
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await (await page.waitForSelector('.ocu-command-bar button.ocu-button-primary', { visible: true, timeout: config.navigationTimeoutMs })).click();
    await pathEnds(page, `/${FORM_ROUTE}`);
    await page.waitForSelector(`#${ID}-Type`, { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-form-title]', (node) => node.textContent.trim()), STRINGS.languageServerFormNew);

    await page.type(`#${ID}-Name`, CREATED);
    await page.select(`#${ID}-Type`, 'Java');
    await page.waitForSelector(`#${ID}-Custom-JVMArgs`, { visible: true, timeout: config.navigationTimeoutMs });
    assert.deepEqual(await locations(page), [`${ID}-LogFile`, `${ID}-Custom-ClassPath`, `${ID}-Custom-JavaHome`], 'the Java file locations are shown read-only');
    assert.equal(await page.$eval('[data-classic-caption]', (node) => node.textContent.trim()), STRINGS.languageServerPathClassicOnly);
    assert.equal(await page.$eval(`#${ID}-Resource`, (node) => node.getAttribute('placeholder')), '%Gateway_Object', 'an empty resource shows the type default');
    await page.type(`#${ID}-Custom-JVMArgs`, JVM_ARGS);
    await page.type(`#${ID}-Port`, String(CREATED_PORT));
    await saveAndSettle(page, config);
    await pathEnds(page, `/${FORM_ROUTE}/${CREATED}`);
    const posted = saves.filter((save) => save.method === 'POST').map((save) => JSON.parse(save.body));
    assert.deepEqual(posted, [{ Name: CREATED, Type: 'Java', Port: CREATED_PORT, Custom: { JVMArgs: JVM_ARGS } }], 'the create sends the name, the type, the port and the JVM arguments');
    assert.equal(stored(CREATED), `Java|${CREATED_PORT}|%Gateway_Object|${JVM_ARGS}`, 'the instance holds the Java server with its JVM arguments and the type default resource');

    // The list, reached by the form's own Cancel rather than a load, re-reads and shows the row; its
    // name opens the editor.
    await page.click('.ocu-form-bar-actions .ocu-button-text');
    await pathEnds(page, `/${LIST_ROUTE}`);
    await filterTo(page, CREATED);
    const listed = await page.evaluate(
      (selector, name) => {
        const row = Array.from(document.querySelectorAll(selector)).find((node) => node.textContent.includes(name));
        return Array.from(row.querySelectorAll('[role="gridcell"]')).slice(0, 4).map((cell) => cell.textContent.trim());
      },
      ROW_SELECTOR,
      CREATED
    );
    assert.deepEqual(listed, [CREATED, 'Java', String(CREATED_PORT), STRINGS.tableStatusNo], 'the list shows the created server, stopped');
    await clickRowCentre(page, { text: CREATED, link: true });
    await pathEnds(page, `/${FORM_ROUTE}/${CREATED}`);
    await page.waitForFunction((id, port) => document.querySelector(`#${id}-Port`)?.value === port, { timeout: config.navigationTimeoutMs }, ID, String(CREATED_PORT));
    for (const field of ['Name', 'Type']) {
      assert.equal(await page.$eval(`#${ID}-${field}`, (node) => node.tagName === 'INPUT' && node.readOnly), true, `${field} is fixed on an edit`);
    }
    assert.equal(await page.$eval(`#${ID}-Type`, (node) => node.value), 'Java');
    await page.click(`#${ID}-Port`, { clickCount: 3 });
    await page.type(`#${ID}-Port`, String(EDITED_PORT));
    await saveAndSettle(page, config);
    const put = saves.filter((save) => save.method === 'PUT');
    assert.deepEqual(put.map((save) => [save.path, JSON.parse(save.body)]), [[`${SAVE_PATH}/${CREATED}`, { Port: EDITED_PORT }]], 'the edit sends the one changed field');
    assert.equal(stored(CREATED), `Java|${EDITED_PORT}|%Gateway_Object|${JVM_ARGS}`, 'and the instance keeps every other value, the JVM arguments among them');

    // The Activity log, linked from the editor, and back.
    const link = await page.waitForSelector('[data-activity-log] a', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await link.evaluate((node) => node.textContent.trim()), STRINGS.languageServerActivityLabel);
    await link.click();
    await pathEnds(page, `/${ACTIVITY_ROUTE}/${CREATED}`);
    await page.goBack();
    await pathEnds(page, `/${FORM_ROUTE}/${CREATED}`);
    await page.waitForSelector(`#${ID}-Port`, { visible: true, timeout: config.navigationTimeoutMs });

    // Delete, typed by the name.
    await page.click('.ocu-form-bar-actions .ocu-button-text');
    await pathEnds(page, `/${LIST_ROUTE}`);
    await filterTo(page, CREATED);
    await clickRowCentre(page, { text: CREATED, cell: 2 });
    await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
    await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
    await page.evaluate((label) => {
      Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'))
        .find((item) => item.textContent.trim().startsWith(label))
        .click();
    }, STRINGS.actionDelete);
    await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-typed-name-consequence', (node) => node.textContent.trim()), STRINGS.languageServerDeleteConsequence);
    assert.deepEqual(actions, [], 'nothing is sent while the dialog is open');
    await page.type('.ocu-typed-name-field', CREATED);
    await page.keyboard.press('Enter');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await page.waitForFunction((selector, name) => !Array.from(document.querySelectorAll(selector)).some((row) => row.textContent.includes(name)), { timeout: config.navigationTimeoutMs }, ROW_SELECTOR, CREATED);
    assert.deepEqual(actions.map((body) => JSON.parse(body)), [{ action: 'delete', id: CREATED }], 'one delete, sent once the name matched');
    assert.equal(stored(CREATED), null, 'the instance no longer holds the server');
    assert.deepEqual(loads, [], 'every step was reached without a page load');
  } finally {
    await context.close();
  }
});

// AC1. Mutation (Rule 19): offer a type's path members as inputs in the store's `customMembers()`,
// rebuild and redeploy -> Python's executable is offered and this goes red.
test('AC1: Python and .NET offer their own settings, with their file locations read-only', async () => {
  const { context, page } = await signedInAt(browser, config, CREATE_URL, VIEWPORTS.wide);
  try {
    await page.waitForSelector(`#${ID}-Type`, { visible: true, timeout: config.navigationTimeoutMs });
    const shared = [`${ID}-Port`, `${ID}-ConnectionTimeout`, `${ID}-InitializationTimeout`, `${ID}-BindToIPAddress`, `${ID}-Resource`, `${ID}-SSLConfigurationServer`, `${ID}-SSLConfigurationClient`, `${ID}-UseSharedMemory`, `${ID}-VerifySSLHostName`];
    for (const [type, own, paths] of [
      ['Python', [`${ID}-Custom-PythonOptions`], [`${ID}-LogFile`, `${ID}-Custom-PythonPath`]],
      ['.NET', [`${ID}-Custom-DotNetVersion`, `${ID}-Custom-Exec32`], [`${ID}-LogFile`, `${ID}-Custom-FilePath`]],
      ['ODBC', [], [`${ID}-LogFile`]],
    ]) {
      await page.select(`#${ID}-Type`, type);
      await page.waitForFunction((id, wanted) => document.querySelectorAll(`.ocu-form-fields input[aria-describedby="${id}-classic-caption"]`).length === wanted, { timeout: config.navigationTimeoutMs }, ID, paths.length);
      assert.deepEqual(await inputs(page), [`${ID}-Name`, `${ID}-Type`, ...shared, ...own], `${type}: exactly its settable members take input`);
      assert.deepEqual(await locations(page), paths, `${type}: its file locations are read-only`);
    }
  } finally {
    await context.close();
  }
});

// AC3. Mutation (Rule 19): answer true from the store's `editable()` while running, rebuild and
// redeploy -> the running editor's inputs take input and this goes red.
test('AC3: a started probe\u2019s editor states the running sentence and reads only; the probe is then stopped', async () => {
  const query = encodeURIComponent(SEEDED);
  const { status: started, body: answer } = await adminAnswer('POST', `/ext-lang-server/start?name=${query}`);
  assert.equal(started, 200, `the seeded probe starts (HTTP ${started}): ${vendorReason(answer)}`);
  try {
    const { context, page } = await signedInAt(browser, config, `/ocupilot/${FORM_ROUTE}/${SEEDED}?ns=HSCUSTOM`, VIEWPORTS.wide);
    try {
      await page.waitForSelector('[data-running]', { visible: true, timeout: START_TIMEOUT_MS });
      assert.equal(await page.$eval('[data-running]', (node) => node.textContent.trim()), STRINGS.languageServerRefusalRunningEdit);
      assert.deepEqual(await inputs(page), [], 'every control reads only');
      assert.equal(await page.$eval('.ocu-form-bar-actions .ocu-button-primary', (node) => node.getAttribute('aria-disabled')), 'true', 'and Save is unavailable');
    } finally {
      await context.close();
    }
  } finally {
    const stopped = await adminApi('POST', `/ext-lang-server/stop?name=${query}`);
    assert.equal(stopped, 200, `the seeded probe stops (HTTP ${stopped})`);
  }
});

// AC9 (DW-1337). Mutation (Rule 19), over a rebuilt and redeployed bundle: draw the classic caption in
// `--ocu-surface` -> the contrast legs go red in both themes.
test('AC9 (DW-1337): the create form and the edit form pass the structural walk at wide light, narrow light and wide dark', async () => {
  for (const [url, ready, type] of [
    [CREATE_URL, `#${ID}-Type`, 'Java'],
    [`/ocupilot/${FORM_ROUTE}/${SEEDED}?ns=HSCUSTOM`, `#${ID}-Custom-JVMArgs:not([readonly])`, null],
  ]) {
    const { context, page } = await signedInAt(browser, config, url, VIEWPORTS.wide);
    try {
      await page.waitForSelector(ready, { visible: true, timeout: config.navigationTimeoutMs });
      if (type !== null) {
        await page.select(`#${ID}-Type`, type);
        await page.waitForSelector('[data-classic-caption]', { visible: true, timeout: config.navigationTimeoutMs });
      }
      assert.deepEqual(await structural(page, FORM_ROUTE), [], `${url}: no violation beyond the baseline's entries`);
    } finally {
      await context.close();
    }
  }
});

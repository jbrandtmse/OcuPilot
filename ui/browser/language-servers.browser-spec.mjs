/**
 * Story 16.10 in a real browser, against the throwaway instance: External language servers, its
 * Start and Stop row actions and the Activity log (AD-5, AD-8, AD-36, AD-53).
 *
 * What it pins: a probe Java server this spec seeds is listed reading Running "No"; Start sends one
 * request and the row then reads "Yes" with the Changed tag; the server's name opens its editor
 * (Story 16.25), whose link opens its Activity log in the shared log viewer, whose rows carry the
 * time, pid, severity chip and text with "Explain this entry" beside each; back on the list, Stop opens the warning dialog stating the published
 * consequence, whose Proceed sends one request after which the row reads "No"; a second Stop is
 * refused with the published sentence. A principal holding OS management's pairs but not
 * `%Admin_ExternalLanguageServerEdit:USE` sees this entry alone unavailable, naming that pair. Both
 * screens pass the structural and contrast checks at 1280 light, 720 light and 1280 dark, with no
 * entry beyond the baseline (DW-1337).
 *
 * **It creates, starts, stops and deletes a probe Java server, a principal and an agent
 * definition**, so it runs on a throwaway only. The server is seeded through the throwaway's admin
 * API as `_SYSTEM`; the `after` hook stops it before deleting it, since a deleted running server keeps
 * listening, removes its activity rows and the principal, and disarms the definition, whatever the
 * tests answered. No vendor `%` server is started, stopped or deleted.
 *
 * Run: `node --test --test-concurrency=1 browser/language-servers.browser-spec.mjs` (after
 * `npm run build`, the bundle copied into the throwaway, and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { authHeader, signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { armProbeDefinition, disarmProbeDefinition, markerValue, requireFreeSlot, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const probe = { container: config.container, marker: 'LANGSRV' };
const ROUTE = 'os-management/language-servers';
const ACTIVITY_ROUTE = 'os-management/language-servers/activity';
const FORM_ROUTE = 'os-management/language-servers/edit';
const LIST_URL = `/ocupilot/${ROUTE}?ns=HSCUSTOM`;
const ACTION_PATH = '/api/ocupilot/screens/osmgmt.languageservers/action';
const SERVER = 'OcuPilotProbeELSBrowser';
const SERVER_PORT = 53293;
const OWN_PAIR = '%Admin_ExternalLanguageServerEdit:USE';
const PRINCIPAL = 'OcuPilotELSBrowserArea';
const PRINCIPAL_ROLE = 'OcuPilotELSBrowserAreaRole';
const PRINCIPAL_PASSWORD = 'OcuPilotELSBrowser1!';
const CHANGED_ROW = '.ocu-data-table-row-changed';
/** A start blocks until the Java server answers, about 11 s here, so its waits are longer. */
const START_TIMEOUT_MS = 90000;

let browser = null;
let priorDefault = '';
let armed = false;
let principal = false;

/** One call to the throwaway's own admin API as the configured account. */
async function adminApi(method, path, body = null) {
  const answer = await fetch(`${config.origin}/api/admin/v2${path}`, {
    method,
    headers: { Authorization: authHeader(config), 'Content-Type': 'application/json' },
    body: body === null ? undefined : JSON.stringify(body),
  });
  return answer.status;
}

/** Seed the probe Java server, stopped, replacing one an earlier run left. */
async function seedServer() {
  await removeServer();
  const status = await adminApi('PUT', `/ext-lang-server?name=${encodeURIComponent(SERVER)}`, { Type: 'Java', Port: SERVER_PORT });
  assert.equal(status, 201, `the probe server is created (HTTP ${status})`);
}

/** Stop the probe server, delete it and remove its activity rows. */
async function removeServer() {
  const name = encodeURIComponent(SERVER);
  const stopped = await adminApi('POST', `/ext-lang-server/stop?name=${name}`);
  // A deleted running server keeps listening, so nothing is deleted unless the stop answered.
  assert.ok(stopped === 200 || stopped === 404, `the probe server stops, or is absent (HTTP ${stopped})`);
  await adminApi('DELETE', `/ext-lang-server?name=${name}`);
  const output = runIris(config.container, [
    'Set $NAMESPACE="%SYS"',
    `Set rs=##class(%SQL.Statement).%ExecDirect(,"DELETE FROM %Net_Remote.ActivityLog WHERE %EXACT(GatewayName) = ?","${SERVER}")`,
    `Write "OCU-ELSGONE-START:"_('##class(Config.Gateways).Exists("${SERVER}"))_(rs.%SQLCODE>=0)_":OCU-ELSGONE-END",!`,
  ]);
  assert.equal(markerValue(output, 'ELSGONE'), '11', `the probe server and its activity rows are removed: ${output}`);
}

/** A principal holding the code read and OS management's three pairs, and not the own pair. */
function createPrincipal() {
  const output = runIris(config.container, [
    'Set $NAMESPACE="%SYS"',
    `If ##class(Security.Users).Exists("${PRINCIPAL}") Do ##class(Security.Users).Delete("${PRINCIPAL}")`,
    `If ##class(Security.Roles).Exists("${PRINCIPAL_ROLE}") Do ##class(Security.Roles).Delete("${PRINCIPAL_ROLE}")`,
    `Set sc=##class(Security.Roles).Create("${PRINCIPAL_ROLE}","OcuPilot language server browser role (throwaway)","%DB_HSCUSTOM:R,%DB_IRISSYS:R,%Admin_Operate:U,%Admin_Manage:U","")`,
    `If sc Set sc=##class(Security.Users).Create("${PRINCIPAL}","${PRINCIPAL_ROLE}","${PRINCIPAL_PASSWORD}","OcuPilot language server browser principal (throwaway)","","","",0,1,"")`,
    'Write "OCU-ELSUSER-START:"_$System.Status.IsOK(sc)_":OCU-ELSUSER-END",!',
  ]);
  assert.equal(markerValue(output, 'ELSUSER'), '1', `the principal was created: ${output}`);
}

function removePrincipal() {
  const output = runIris(config.container, [
    'Set $NAMESPACE="%SYS"',
    `If ##class(Security.Users).Exists("${PRINCIPAL}") Do ##class(Security.Users).Delete("${PRINCIPAL}")`,
    `If ##class(Security.Roles).Exists("${PRINCIPAL_ROLE}") Do ##class(Security.Roles).Delete("${PRINCIPAL_ROLE}")`,
    `Write "OCU-ELSUSERGONE-START:"_('##class(Security.Users).Exists("${PRINCIPAL}"))_":OCU-ELSUSERGONE-END",!`,
  ]);
  assert.equal(markerValue(output, 'ELSUSERGONE'), '1', `the principal was removed: ${output}`);
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

/** Filter the list to the probe server's one row and select it. */
async function selectServer(page) {
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, SERVER);
  await page.waitForFunction(
    (rowSelector, filterSelector, wanted) => {
      if (document.querySelector(filterSelector)?.value !== wanted) return false;
      const rows = Array.from(document.querySelectorAll(rowSelector));
      return rows.length === 1 && rows[0].textContent.includes(wanted);
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    FILTER_SELECTOR,
    SERVER
  );
  // The first cell is the name, whose link opens the editor, so the row is selected by its Type cell.
  await clickRowCentre(page, { index: 0, cell: 2 });
  await page.waitForFunction(
    (rowSelector) => document.querySelector(rowSelector)?.getAttribute('aria-selected') === 'true',
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR
  );
}

/** The probe row's cells, or `null`. */
function serverRow(page) {
  return page.evaluate(
    (rowSelector, wanted) => {
      const row = Array.from(document.querySelectorAll(rowSelector)).find((node) => node.textContent.includes(wanted));
      return row === undefined ? null : Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim());
    },
    ROW_SELECTOR,
    SERVER
  );
}

/** Open the selected row's menu and click the entry labeled `label`. */
async function rowAction(page, label) {
  await page.click(`${ROW_SELECTOR}[aria-selected="true"] .ocu-data-table-trigger`);
  await page.waitForSelector('[role="menu"]', { timeout: config.navigationTimeoutMs });
  await page.evaluate((wanted) => {
    const items = Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'));
    items.find((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted).click();
  }, label);
}

/** Wait until the probe row reads `running` in its Running cell. */
async function waitForRunning(page, running, changed, timeout = config.navigationTimeoutMs) {
  await page.waitForFunction(
    (rowSelector, changedSelector, wanted, word, needsChanged) => {
      const row = Array.from(document.querySelectorAll(rowSelector)).find((node) => node.textContent.includes(wanted));
      if (row === undefined) return false;
      const cells = Array.from(row.querySelectorAll('[role="gridcell"]'));
      if (cells[3]?.textContent.trim() !== word) return false;
      return !needsChanged || row.matches(changedSelector);
    },
    { timeout },
    ROW_SELECTOR,
    CHANGED_ROW,
    SERVER,
    running,
    changed
  );
}

before(async () => {
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec starts and stops a probe server, so it runs only in a throwaway; ${config.container} is not one`);
  await requireFreeSlot(config);
  browser = await puppeteer.launch(launchOptions(config));
  const definition = armProbeDefinition(probe);
  priorDefault = definition.prior;
  armed = true;
  createPrincipal();
  principal = true;
  await seedServer();
});

after(async () => {
  try {
    if (/-ci$/.test(config.container)) {
      try {
        await removeServer();
      } finally {
        if (principal) removePrincipal();
        if (armed) disarmProbeDefinition(probe, priorDefault);
      }
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

// AC1, AC2, AC3, AC7. Mutation (Rule 19): drop the Activity link from the language server editor's
// template, then rebuild and redeploy -> the editor offers no Activity log and the link wait goes red.
test('AC1-AC3: Start reads Running "Yes" changed; the name opens the editor, which links the Activity log; Stop warns and reads "No"; a second Stop is refused; both screens pass DW-1337', async () => {
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const posts = [];
  page.on('request', (request) => {
    if (new URL(request.url()).pathname === ACTION_PATH) posts.push({ method: request.method(), body: request.postData() ?? '' });
  });
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const headers = await page.$$eval('.ocu-data-table-header-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(
      headers.slice(0, 4),
      [STRINGS.tableColumnName, STRINGS.tableColumnType, STRINGS.sslTestPort, STRINGS.languageServerColumnRunning],
      'the declared headers, ahead of the row actions'
    );
    const listed = await serverRow(page);
    assert.ok(listed !== null, 'the probe server is listed');
    assert.deepEqual(listed.slice(0, 4), [SERVER, 'Java', String(SERVER_PORT), STRINGS.tableStatusNo], 'a stopped Java server on its port');

    await selectServer(page);
    await rowAction(page, STRINGS.actionStart);
    await waitForRunning(page, STRINGS.tableStatusYes, true, START_TIMEOUT_MS);
    assert.deepEqual(posts.map((post) => JSON.parse(post.body)), [{ action: 'start', id: SERVER }], 'Start sent one request, with no dialog');

    await clickRowCentre(page, { index: 0, link: true });
    await page.waitForFunction((route) => location.pathname.startsWith(`/ocupilot/${route}/`), { timeout: config.navigationTimeoutMs }, FORM_ROUTE);
    await (await page.waitForSelector('[data-activity-log] a', { visible: true, timeout: config.navigationTimeoutMs })).click();
    await page.waitForFunction((route) => location.pathname.startsWith(`/ocupilot/${route}/`), { timeout: config.navigationTimeoutMs }, ACTIVITY_ROUTE);
    await page.waitForSelector('.ocu-log-row', { timeout: config.navigationTimeoutMs });
    const lines = await page.$$eval('.ocu-log-row', (rows) =>
      rows.map((row) => Array.from(row.querySelectorAll('.ocu-log-cell')).map((cell) => cell.textContent.trim()))
    );
    assert.ok(lines.length > 0, 'the Activity log lists the server\'s activity');
    const newest = lines.at(-1);
    assert.match(newest[0], /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.000$/, `the newest line carries its local time: ${JSON.stringify(newest)}`);
    assert.match(newest[1], /^\d+$/, 'and its job as the pid');
    assert.ok(lines.some((line) => line[3].includes('successfully started')), `the start is recorded: ${JSON.stringify(lines)}`);
    const chips = await page.$$eval('.ocu-log-row .ocu-log-chip-static', (items) => items.map((item) => item.textContent.trim()));
    assert.ok(chips.every((chip) => chip !== ''), 'every line carries its severity chip');
    assert.ok((await page.$$('[data-ocu-log="explain"]')).length > 0, '"Explain this entry" sits beside each line');
    assert.ok((await page.$('[data-ocu-log="load-newer"]')) !== null, 'and Load newer is offered');
    assert.deepEqual(await structural(page, ACTIVITY_ROUTE), [], 'the Activity log: no violation beyond the baseline\'s entries');

    // Back through the editor to the list.
    await page.goBack();
    await page.waitForFunction((route) => location.pathname.startsWith(`/ocupilot/${route}/`), { timeout: config.navigationTimeoutMs }, FORM_ROUTE);
    await page.goBack();
    await waitForRows(page, config.navigationTimeoutMs);
    await selectServer(page);
    await rowAction(page, STRINGS.actionStop);
    await page.waitForSelector('app-warning-dialog', { timeout: config.navigationTimeoutMs });
    const opened = await page.evaluate(() => {
      const surface = document.querySelector('[role="dialog"]');
      return {
        title: (surface.querySelector('.ocu-dialog-title')?.textContent ?? '').trim(),
        body: (surface.querySelector('.ocu-warning-consequence')?.textContent ?? '').trim(),
        destructive: surface.querySelector('.ocu-button-destructive') !== null,
      };
    });
    assert.equal(opened.title, STRINGS.actionStop, 'the warning is titled with the verb');
    assert.equal(opened.body, STRINGS.languageServerStopConsequence, 'and states the published consequence');
    assert.equal(opened.destructive, false, 'never a destructive one');
    await page.click('[role="dialog"] .ocu-dialog-actions .ocu-button-primary');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await waitForRunning(page, STRINGS.tableStatusNo, false);
    assert.deepEqual(JSON.parse(posts.at(-1).body), { action: 'stop', id: SERVER }, 'Stop sent at Proceed');

    await selectServer(page);
    await rowAction(page, STRINGS.actionStop);
    await page.waitForSelector('app-warning-dialog', { timeout: config.navigationTimeoutMs });
    await page.click('[role="dialog"] .ocu-dialog-actions .ocu-button-primary');
    await page.waitForFunction(
      (sentence) => (document.querySelector('app-list-page')?.textContent ?? '').includes(sentence),
      { timeout: config.navigationTimeoutMs },
      STRINGS.languageServerRefusalStopped
    );
    assert.deepEqual(await structural(page, ROUTE), [], 'the list: no violation beyond the baseline\'s entries');
  } finally {
    await context.close();
  }
});

// AC5. Mutation (Rule 19): drop the own pair from LanguageServerList's `privileges` and
// `ownPrivileges` and recompile on the throwaway -> External language servers reads open and the
// refused-entry assertion goes red.
test('AC5: a holder of OS management\'s pairs without the own pair sees External language servers alone unavailable', async () => {
  const { context, page } = await signedInAt(browser, { ...config, username: PRINCIPAL, password: PRINCIPAL_PASSWORD }, '/ocupilot/os-management/processes?ns=HSCUSTOM', VIEWPORTS.wide);
  try {
    await page.click(`.ocu-rail-item[aria-label="${STRINGS.navAreaOsManagement}"]`);
    await page.waitForFunction(
      (label) => Array.from(document.querySelectorAll('.ocu-side-bar-label')).some((node) => node.textContent.trim() === label),
      { timeout: config.navigationTimeoutMs },
      STRINGS.languageServersLabel
    );
    const entries = await page.$$eval('.ocu-side-bar-item', (items) =>
      items.map((item) => ({
        label: (item.querySelector('.ocu-side-bar-label')?.textContent ?? '').trim(),
        disabled: item.getAttribute('aria-disabled') === 'true' || item.querySelector('[aria-disabled="true"]') !== null,
        reason: (item.querySelector('.ocu-side-bar-reason')?.textContent ?? '').trim(),
      }))
    );
    const refused = entries.filter((entry) => entry.disabled);
    assert.deepEqual(
      refused.map((entry) => `${entry.label}: ${entry.reason}`),
      [`${STRINGS.languageServersLabel}: ${STRINGS.privilegeRequiresResource.replace('<resource>', OWN_PAIR)}`],
      `only External language servers is unavailable, naming its own pair: ${JSON.stringify(entries)}`
    );
    assert.ok(entries.length >= 9, 'while the other OS management entries stay open');
  } finally {
    await context.close();
  }
});

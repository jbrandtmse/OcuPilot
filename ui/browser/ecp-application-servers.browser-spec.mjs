/**
 * ECP application servers and its SSL/TLS authorizations tab in a real browser, against the throwaway
 * instance (Story 18.21).
 *
 * What it pins, each on rendered DOM or on the instance itself:
 *
 * 1. **Connections** (C4, C8): OS management's nineteenth side-bar entry reads "ECP application
 *    servers", its strip holds Connections and SSL/TLS authorizations, and Connections says each status
 *    is what the instance reported when the list was read and, with no application server connected,
 *    shows its empty state.
 * 2. **A seeded authorization** (C5): a probe SSL/TLS computer name seeded as authorized is listed
 *    Authorized, and its row menu draws Authorize and Reject `aria-disabled` with the tools' sentence.
 * 3. **Delete** (C5): the typed-name dialog states the consequence, takes the name, and the instance no
 *    longer holds it.
 * 4. **DW-1337** (C8): each tab and the dialog pass the structural walk at wide light, narrow light and
 *    wide dark.
 *
 * **It refuses the live and development containers.** It touches only `CN=OCUPROBEECP*` names and
 * removes every probe object with `OcuPilot.Test.EcpProbe.RemoveAll` before and after each test,
 * asserting none survives and no ECP process runs.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1
 * browser/ecp-application-servers.browser-spec.mjs`.
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

const NOT_PENDING_REASON = serverSentence('Screen/Tool/EcpSslConnectionAuthorize.cls', 'NOTPENDINGREASON');

const PROBE = 'OcuPilot.Test.EcpProbe';

/** The probe SSL/TLS computer name, seeded as authorized. */
const NAME = 'CN=OCUPROBEECPB';

const APP_ROUTE = 'os-management/ecp-application-servers';
const SSL_ROUTE = 'os-management/ecp-application-servers/ssl';
const APP_URL = `/ocupilot/${APP_ROUTE}?ns=HSCUSTOM`;
const SSL_URL = `/ocupilot/${SSL_ROUTE}?ns=HSCUSTOM`;

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

/** Whether the instance's authorized list holds `name`. */
function authorized(name) {
  const { values, output } = iris([mark('HELD', `''$ListFind(##class(${PROBE}).AuthorizedNames(),"${name}")`)], ['HELD']);
  assert.ok(values.HELD === '0' || values.HELD === '1', `the authorized list is read:\n${output}`);
  return values.HELD === '1';
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec seeds and deletes SSL/TLS authorizations, so it never runs inside the live container');
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
  await page.waitForSelector(FILTER_SELECTOR, { visible: true, timeout: config.navigationTimeoutMs });
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await waitForRows(page, config.navigationTimeoutMs);
  await page.type(FILTER_SELECTOR, name);
  await page.waitForFunction(
    (selector, wanted) => Array.from(document.querySelectorAll(selector)).some((row) => (row.querySelector('[role="gridcell"]')?.textContent ?? '').trim() === wanted),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name
  );
  await clickRowCentre(page, { text: name, cell: 2 });
  await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
}

/** The open row menu's entries: label, whether `aria-disabled`, and the reason drawn. */
function menuItems(page) {
  return page.$$eval('[role="menu"] [role="menuitem"]', (items) =>
    items.map((item) => ({
      label: (item.querySelector('.ocu-data-table-menu-label')?.textContent ?? '').trim(),
      disabled: item.getAttribute('aria-disabled') === 'true',
      reason: (item.querySelector('.ocu-data-table-menu-reason')?.textContent ?? '').trim(),
    }))
  );
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

// C4, C8. Mutation (Rule 19): drop EcpAppServerTab's `read.note`, regenerate the mirror, rebuild and
// redeploy -> the note assertion goes red.
test('C4, C8: ECP application servers is the nineteenth OS management entry, its Connections tab says what each status is, and both tabs pass DW-1337', async () => {
  removeAll();
  const { context, page } = await signedInAt(browser, config, APP_URL, VIEWPORTS.wide);
  try {
    await page.waitForSelector('nav.ocu-detail-tabs', { timeout: config.navigationTimeoutMs });
    const bar = await sideBarOf(page);
    assert.equal(bar.area, STRINGS.navAreaOsManagement);
    assert.equal(bar.entries.length, 19, `nineteen entries: ${JSON.stringify(bar.entries)}`);
    assert.equal(bar.entries[18], STRINGS.ecpAppServersLabel, 'ECP application servers is the nineteenth');
    const labels = await page.$$eval('.ocu-detail-tab-label', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(labels, [STRINGS.sslPromptGroupConnections, STRINGS.ecpSslConnectionsLabel]);
    await page.waitForSelector('app-list-page .ocu-list-page-note', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('app-list-page .ocu-list-page-note', (node) => node.textContent.trim()), STRINGS.ecpDataServerStatusCaveat);
    await page.waitForSelector('.ocu-data-table-empty-title', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-data-table-empty-title', (node) => node.textContent.trim()), STRINGS.ecpAppServerListEmpty, 'with no application server connected');
    await assertStructure(page, APP_ROUTE);
    await page.click(`.ocu-detail-tab[data-route="${SSL_ROUTE}"]`);
    await page.waitForFunction((route) => new URL(location.href).pathname.endsWith(`/${route}`), { timeout: config.navigationTimeoutMs }, SSL_ROUTE);
    await page.waitForSelector('.ocu-data-table-empty-title', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-data-table-empty-title', (node) => node.textContent.trim()), STRINGS.ecpSslConnectionListEmpty, 'and no SSL/TLS authorization held');
    await assertStructure(page, SSL_ROUTE);
  } finally {
    await context.close();
    removeAll();
  }
});

// C5. Mutation (Rule 19): drop the `ecp-ssl-pending` branch from `selfProtectionReason`, rebuild and
// redeploy -> Authorize reads enabled and the disabled-entry assertion goes red.
test('C5: a seeded authorization is listed Authorized, Authorize and Reject are aria-disabled with the tools\u2019 sentence, and Delete removes it', async () => {
  removeAll();
  seed(`SeedAuthorized("${NAME}")`);
  const { context, page } = await signedInAt(browser, config, SSL_URL, VIEWPORTS.wide);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const headers = await page.$$eval('.ocu-data-table-header-label', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(headers.slice(0, 3), [STRINGS.ecpSslComputerName, STRINGS.ecpClientIp, STRINGS.taskHistoryColumnStatus]);
    await openRowMenu(page, NAME);
    const cells = await page.$$eval('[role="row"][aria-selected="true"] [role="gridcell"]', (nodes) => nodes.slice(0, 3).map((node) => node.textContent.trim()));
    assert.equal(cells[0], NAME, 'the seeded name is listed');
    assert.equal(cells[2], 'Authorized', 'as the instance reports it');
    const items = await menuItems(page);
    const entry = (label) => items.find((item) => item.label === label);
    assert.deepEqual(entry(STRINGS.ecpSslAuthorize), { label: STRINGS.ecpSslAuthorize, disabled: true, reason: NOT_PENDING_REASON }, `Authorize is refused, saying why: ${JSON.stringify(items)}`);
    assert.deepEqual(entry(STRINGS.ecpSslReject), { label: STRINGS.ecpSslReject, disabled: true, reason: NOT_PENDING_REASON }, 'and Reject');
    assert.equal(entry(STRINGS.actionDelete)?.disabled, false, 'while Delete is offered');

    await page.evaluate((wanted) => {
      Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'))
        .find((item) => (item.querySelector('.ocu-data-table-menu-label')?.textContent ?? '').trim() === wanted)
        .click();
    }, STRINGS.actionDelete);
    await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-typed-name-consequence', (node) => node.textContent.trim()), STRINGS.ecpSslConnectionDeleteConsequence);
    await assertStructure(page, SSL_ROUTE, true);
    await page.type('.ocu-typed-name-field', NAME);
    await page.keyboard.press('Enter');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: 90000 });
    await page.waitForFunction(
      (selector, wanted) => !Array.from(document.querySelectorAll(selector)).some((row) => (row.querySelector('[role="gridcell"]')?.textContent ?? '').trim() === wanted),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      NAME
    );
    assert.equal(authorized(NAME), false, 'the instance no longer holds the name');
  } finally {
    await context.close();
    removeAll();
  }
});

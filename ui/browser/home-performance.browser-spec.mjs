/**
 * Home's performance row in a real browser against the throwaway instance (Story 16.18).
 *
 * **What only this tier can settle.**
 *
 * - **AC1 and the Integration AC (AC6).** The five readings are the instance's own answer,
 *   travelling through `GET /api/ocupilot/ui/performance`, the store and the rendered row: each
 *   rendered value is compared with the answer the browser itself received, and the row is walked
 *   by the DW-1337 structural gate in both themes, wide and narrow, against the baseline with no
 *   new allowance. AC4, the screen context, is pinned at the component and store tiers
 *   (`home.page.spec.ts`, `screen-context.test.mjs`) and on the instance
 *   (`OcuPilot.Test.ScreenGrounding`).
 * - **AC2.** With Home at every 5 s, the line appears only once a second answer has arrived and
 *   carries exactly as many points as answers; leaving Home and returning starts it empty again.
 * - **AC3.** A principal holding `%Admin_Operate:USE` and not `%DB_IRISSYS:READ` is answered 403
 *   and sees no heading, no value and no zero, and Home's blocks and tiles are all there.
 * - **AC5.** A rate set on Home's chip survives leaving Home and a real sign-out.
 *
 * **It creates a security principal**, so it refuses the live container. The principal holds read
 * on the install namespace's routine database and `%Admin_Operate:USE`; its password is generated
 * for the run, and `after` deletes it and its role whether or not a test failed. Every sign-in
 * forgets the signing-in account's remembered state first (`preferences-reset.mjs`), and `after`
 * forgets it again.
 *
 * Run: `npm run build`, redeploy the bundle into the throwaway, then
 * `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/home-performance.browser-spec.mjs`
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';
import { INVARIANTS, VIEWPORTS, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));
const { formatPerformance, PERFORMANCE_FIELDS } = await import(join(uiRoot, 'src', 'app', 'core', 'performance.ts'));
const { formatAutoRefreshOn } = await import(join(uiRoot, 'src', 'app', 'core', 'refresh.ts'));

const config = browserConfig();
const HOME_URL = '/ocupilot/?ns=HSCUSTOM';
const PERFORMANCE_PATH = '/api/ocupilot/ui/performance';
const PREFERENCES_PATH = '/api/ocupilot/account/preferences';
const HOME_ROUTE_KEY = '/';

const DENIED_USER = 'OcuPilotPerformanceProbe';
const DENIED_ROLE = 'OcuPilotPerformanceProbeRole';
const DENIED_PASSWORD = `Ocu${randomBytes(12).toString('hex')}a1`;

/** The five readings' labels and units, in the row's order. */
const LABELS = [
  [STRINGS.systemUsageCacheEfficiency, STRINGS.performanceCacheUnit],
  [STRINGS.processDetailsGlobalReferences, STRINGS.performanceRateUnit],
  [STRINGS.systemUsageGlobalUpdates, STRINGS.performanceRateUnit],
  [STRINGS.performanceDiskReads, STRINGS.performanceRateUnit],
  [STRINGS.performanceDiskWrites, STRINGS.performanceRateUnit],
];

let browser = null;

function irisSession(lines, names) {
  const input = `${[...lines, 'Halt'].join('\n')}\n`;
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', '%SYS'], {
    input,
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

function deletePrincipal() {
  return irisSession(
    [
      `If ##class(Security.Users).Exists("${DENIED_USER}") Do ##class(Security.Users).Delete("${DENIED_USER}")`,
      `If ##class(Security.Roles).Exists("${DENIED_ROLE}") Do ##class(Security.Roles).Delete("${DENIED_ROLE}")`,
      mark('CLEAN', `('##class(Security.Users).Exists("${DENIED_USER}"))&&('##class(Security.Roles).Exists("${DENIED_ROLE}"))`),
    ],
    ['CLEAN']
  );
}

function authHeader() {
  return 'Basic ' + Buffer.from(`${config.username}:${config.password}`).toString('base64');
}

async function setHomeRate(seconds) {
  const answer = await fetch(`${config.origin}${PREFERENCES_PATH}`, {
    method: 'POST',
    headers: { Authorization: authHeader(), 'Content-Type': 'application/json' },
    body: JSON.stringify({ kind: 'refresh', action: 'set', route: 'home', value: String(seconds) }),
  });
  assert.equal(answer.status, 200, `Home's rate is remembered: ${await answer.text()}`);
}

async function rememberedHomeRate() {
  const answer = await fetch(`${config.origin}${PREFERENCES_PATH}`, { headers: { Authorization: authHeader() } });
  const body = await answer.json();
  return body.refreshRates.find((entry) => entry.route === 'home')?.value ?? null;
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates a security principal, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  const { values, output } = irisSession(
    [
      'Set tNS=$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"):"HSCUSTOM",1:"USER")',
      'Set tRes=##class(SYS.Database).%OpenId(##class(Config.Databases).Open(##class(Config.Namespaces).Open(tNS).Routines).Directory).ResourceName',
      `If ##class(Security.Users).Exists("${DENIED_USER}") Do ##class(Security.Users).Delete("${DENIED_USER}")`,
      `If ##class(Security.Roles).Exists("${DENIED_ROLE}") Do ##class(Security.Roles).Delete("${DENIED_ROLE}")`,
      `Set tSC=##class(Security.Roles).Create("${DENIED_ROLE}","OcuPilot performance row browser spec probe (throwaway)",tRes_":R,%Admin_Operate:U","")`,
      `Set tSC2=##class(Security.Users).Create("${DENIED_USER}","${DENIED_ROLE}","${DENIED_PASSWORD}","OcuPilot performance row browser spec probe (throwaway)","","","",0,1,"")`,
      mark('USER', '$System.Status.IsOK(tSC)&&$System.Status.IsOK(tSC2)'),
      mark('OPERATE', `$SYSTEM.Security.CheckUserPermission("${DENIED_USER}","%Admin_Operate","USE")`),
      mark('IRISSYS', `$SYSTEM.Security.CheckUserPermission("${DENIED_USER}","%DB_IRISSYS","READ")`),
    ],
    ['USER', 'OPERATE', 'IRISSYS']
  );
  assert.equal(values.USER, '1', `the denied principal was created:\n${output}`);
  assert.equal(values.OPERATE, '1', 'and holds %Admin_Operate:USE');
  assert.equal(values.IRISSYS, '0', 'and not %DB_IRISSYS:READ');
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  browser = null;
  const { values, output } = deletePrincipal();
  await resetRememberedState();
  assert.equal(values.CLEAN, '1', `the denied principal and its role are gone:\n${output}`);
});

/**
 * A fresh context signed in as `user` and landed on Home at `viewport`, with every answer to the
 * performance read recorded as `{status, body}` in arrival order. `before` runs after the account's
 * remembered state is forgotten and before the page loads; `reset` false keeps it (a sign-in after
 * a sign-out).
 */
async function signedInAtHome({ user = config.username, password = config.password, viewport = VIEWPORTS.wide, prepare = null, reset = true } = {}) {
  if (reset) await resetRememberedState();
  if (prepare !== null) await prepare();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  await page.setViewport(viewport);
  const answers = [];
  page.on('response', async (response) => {
    if (new URL(response.url()).pathname !== PERFORMANCE_PATH) return;
    let body = null;
    try {
      body = await response.json();
    } catch {
      body = null;
    }
    answers.push({ status: response.status(), body });
  });
  await signIn(page, user, password);
  return { context, page, answers };
}

async function signIn(page, user, password) {
  await page.goto(`${config.origin}${HOME_URL}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', user);
  await page.type('#ocu-signin-password', password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, HOME_URL);
  await page.waitForSelector('app-home-page .ocu-area-tile', { timeout: config.navigationTimeoutMs });
}

/** The rendered readings, label, value and unit each. */
function readings(page) {
  return page.evaluate(() =>
    Array.from(document.querySelectorAll('.ocu-home-performance-item')).map((item) => ({
      label: item.querySelector('.ocu-home-performance-label')?.textContent?.trim() ?? '',
      value: item.querySelector('.ocu-home-performance-value')?.textContent?.trim() ?? '',
      unit: item.querySelector('.ocu-home-performance-unit')?.textContent?.trim() ?? '',
    }))
  );
}

/** The line's path data, or `null` when no line is drawn. */
function lineData(page) {
  return page.evaluate(() => document.querySelector('.ocu-home-performance-line')?.getAttribute('d') ?? null);
}

const chipText = (page) => page.evaluate(() => document.querySelector('.ocu-command-bar-refresh')?.textContent?.trim() ?? null);

async function waitForAnswers(answers, count) {
  const deadline = Date.now() + 60_000;
  while (answers.filter((answer) => answer.status === 200).length < count) {
    assert.ok(Date.now() < deadline, `waited for ${count} answers, received ${JSON.stringify(answers.map((answer) => answer.status))}`);
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
}

function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/** Leave Home through its first open tile, and come back through the rail's Home item. */
async function leaveAndReturn(page) {
  await page.evaluate(() => {
    const tile = Array.from(document.querySelectorAll('.ocu-area-tile')).find((candidate) => candidate.getAttribute('aria-disabled') !== 'true');
    tile?.click();
  });
  await page.waitForFunction(() => new URL(window.location.href).pathname !== '/ocupilot/', { timeout: config.navigationTimeoutMs });
  await page.waitForFunction(() => document.querySelector('app-home-page') === null, { timeout: config.navigationTimeoutMs });
  await page.evaluate(() => document.querySelector('app-rail .ocu-rail-item')?.click());
  await page.waitForSelector('app-home-page .ocu-area-tile', { timeout: config.navigationTimeoutMs });
}

// Mutation (Rule 19): drop `globalReferencesPerSecond` from `OcuPilot.Port.MonitorPort.METRICS`
// and recompile -> the route answers four members, the client reads a server fault, the row never
// renders, and this test goes red on the five readings.
test('AC1 and the Integration AC: the row shows the five values the instance answered, each with its unit, and passes the structural gate in both themes', async () => {
  const { context, page, answers } = await signedInAtHome();
  try {
    await page.waitForFunction(() => document.querySelectorAll('.ocu-home-performance-item').length === 5, { timeout: config.navigationTimeoutMs });
    const heading = await page.$eval('app-performance-row .ocu-home-block-heading', (element) => element.textContent.trim());
    assert.equal(heading, STRINGS.performanceHeading);

    // Compared against the answer the browser itself received -- the newest one, since a tick may
    // land between the two reads.
    let rendered = null;
    let expected = null;
    for (let attempt = 0; attempt < 5; attempt += 1) {
      rendered = await readings(page);
      const last = answers.filter((answer) => answer.status === 200).at(-1);
      assert.ok(last, `the browser received an answer: ${JSON.stringify(answers.map((answer) => answer.status))}`);
      assert.deepEqual(Object.keys(last.body).sort(), [...PERFORMANCE_FIELDS].sort(), 'the answer carries the five members and nothing else');
      const formatted = formatPerformance(last.body);
      expected = LABELS.map(([label, unit], index) => ({ label, value: formatted[PERFORMANCE_FIELDS[index]], unit }));
      if (JSON.stringify(rendered) === JSON.stringify(expected)) break;
      await new Promise((resolve) => setTimeout(resolve, 200));
    }
    assert.deepEqual(rendered, expected, 'each reading is the instance\u2019s own value, with its label and unit');

    assert.equal(await chipText(page), formatAutoRefreshOn(STRINGS.statusAutoRefreshOn, 10), 'Home starts at every 10 s');

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
      await page.evaluate((isDark) => document.documentElement.classList.toggle('ocu-theme-dark', isDark), theme === 'dark');
      await frames(page);
      surfaces[theme] = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
      assert.equal(await page.evaluate(() => document.querySelectorAll('.ocu-home-performance-item').length), 5, `the row is showing at ${viewport.width}px ${theme}`);
      const { entries } = await detectScreen(page, { route: HOME_ROUTE_KEY, checks, viewport: viewport.width, theme, minimums });
      found.push(...entries);
      if (viewport === VIEWPORTS.narrow) {
        const layout = await page.evaluate(() => {
          const items = Array.from(document.querySelectorAll('.ocu-home-performance-item')).map((item) => item.getBoundingClientRect());
          return {
            firstTop: Math.round(items[0].top),
            lastTop: Math.round(items[items.length - 1].top),
            hidden: items.filter((box) => box.width === 0 || box.height === 0).length,
            scrollWidth: document.documentElement.scrollWidth,
            clientWidth: document.documentElement.clientWidth,
          };
        });
        assert.ok(layout.lastTop > layout.firstTop, `the readings wrap at ${viewport.width}px: ${JSON.stringify(layout)}`);
        assert.equal(layout.hidden, 0, `and none is hidden: ${JSON.stringify(layout)}`);
        assert.ok(layout.scrollWidth <= layout.clientWidth, `and Home does not scroll horizontally: ${JSON.stringify(layout)}`);
      }
    }
    await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
    assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
    const fresh = compare(collapse(found), readBaseline()?.entries ?? []).fresh;
    assert.deepEqual(fresh.map((entry) => `${entry.key}: ${entry.measured}`), [], 'no violation beyond the baseline on Home with the row showing');
  } finally {
    await context.close();
  }
});

test('AC2: at every 5 s the line appears with the second answer, through exactly the points received, and starts empty again after leaving Home', async () => {
  const { context, page, answers } = await signedInAtHome({ prepare: () => setHomeRate(5) });
  try {
    await page.waitForFunction((wanted) => document.querySelector('.ocu-command-bar-refresh')?.textContent?.trim() === wanted, { timeout: config.navigationTimeoutMs }, formatAutoRefreshOn(STRINGS.statusAutoRefreshOn, 5));
    await page.waitForSelector('.ocu-home-performance-sparkline', { timeout: config.navigationTimeoutMs });
    if (answers.filter((answer) => answer.status === 200).length === 1) {
      assert.equal(await lineData(page), null, 'on the first answer no line is drawn');
    }
    await waitForAnswers(answers, 2);
    await page.waitForSelector('.ocu-home-performance-line', { timeout: config.navigationTimeoutMs });
    await waitForAnswers(answers, 3);
    await frames(page);
    const received = answers.filter((answer) => answer.status === 200).length;
    const segments = ((await lineData(page)) ?? '').match(/[ML]/g) ?? [];
    assert.ok(segments.length === received || segments.length === received - 1, `one point per answer received: ${segments.length} points, ${received} answers`);
    assert.equal(segments[0], 'M');

    await leaveAndReturn(page);
    assert.equal(await lineData(page), null, 'the line starts empty again after leaving Home');
    assert.equal(await page.evaluate(() => document.querySelectorAll('.ocu-home-performance-item').length), 5, 'while the last values stand');
    const settledCount = answers.filter((answer) => answer.status === 200).length;
    await waitForAnswers(answers, settledCount + 2);
    await page.waitForSelector('.ocu-home-performance-line', { timeout: config.navigationTimeoutMs });
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): render the row for a 403 as zeros (keep `values` at 0s in `read`) -> this
// goes red on the heading.
test('AC3: a caller without %DB_IRISSYS:READ is answered 403 and sees no heading, no value and no zero, and the rest of Home is there', async () => {
  const { context, page, answers } = await signedInAtHome({ user: DENIED_USER, password: DENIED_PASSWORD });
  try {
    const deadline = Date.now() + 30_000;
    while (!answers.some((answer) => answer.status === 403)) {
      assert.ok(Date.now() < deadline, `the performance read was answered: ${JSON.stringify(answers.map((answer) => answer.status))}`);
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
    assert.equal(answers.find((answer) => answer.status === 403)?.body?.detail?.failedPair, '%DB_IRISSYS:READ', 'the refusal names the pair');
    await frames(page);
    const state = await page.evaluate((heading) => ({
      row: document.querySelector('app-performance-row') !== null,
      items: document.querySelectorAll('.ocu-home-performance-item').length,
      heading: Array.from(document.querySelectorAll('h2')).some((element) => element.textContent.trim() === heading),
      tiles: document.querySelectorAll('.ocu-area-tile').length,
      blocks: document.querySelectorAll('.ocu-home-remembered .ocu-home-block').length,
    }), STRINGS.performanceHeading);
    assert.equal(state.row, false, 'no row');
    assert.equal(state.items, 0, 'no value and no zero');
    assert.equal(state.heading, false, 'no heading');
    assert.equal(state.tiles, 6, 'the tiles are all there');
    assert.ok(state.blocks >= 4, `and so are the blocks: ${JSON.stringify(state)}`);
  } finally {
    await context.close();
  }
});

test("AC5: a rate set on Home's chip survives leaving Home and a real sign-out", async () => {
  let first = null;
  let second = null;
  try {
    first = await signedInAtHome();
    const { page } = first;
    await page.waitForFunction((wanted) => document.querySelector('.ocu-command-bar-refresh')?.textContent?.trim() === wanted, { timeout: config.navigationTimeoutMs }, formatAutoRefreshOn(STRINGS.statusAutoRefreshOn, 10));
    await page.click('.ocu-command-bar-refresh');
    const thirty = formatAutoRefreshOn(STRINGS.statusAutoRefreshOn, 30);
    await page.waitForFunction((wanted) => document.querySelector('.ocu-command-bar-refresh')?.textContent?.trim() === wanted, { timeout: config.navigationTimeoutMs }, thirty);
    const deadline = Date.now() + 10_000;
    while ((await rememberedHomeRate()) !== '30') {
      assert.ok(Date.now() < deadline, 'the instance remembers Home at 30 s under home');
      await new Promise((resolve) => setTimeout(resolve, 100));
    }

    await leaveAndReturn(page);
    assert.equal(await chipText(page), thirty, 'the chip reads every 30 s after leaving Home and returning');

    await page.click('#ocu-account-trigger');
    await page.waitForSelector('[role="menuitem"]', { visible: true, timeout: config.navigationTimeoutMs });
    const found = await page.evaluate((label) => {
      const item = [...document.querySelectorAll('[role="menuitem"]')].find((candidate) => candidate.textContent.trim() === label);
      if (item === undefined) return false;
      item.id = 'ocu-probe-sign-out';
      return true;
    }, STRINGS.actionSignOut);
    assert.ok(found, 'the account menu lists Sign out');
    await page.click('#ocu-probe-sign-out');
    await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
    await first.context.close();
    first = null;

    second = await signedInAtHome({ reset: false });
    await second.page.waitForFunction((wanted) => document.querySelector('.ocu-command-bar-refresh')?.textContent?.trim() === wanted, { timeout: config.navigationTimeoutMs }, thirty);
    assert.equal(await chipText(second.page), thirty, 'and after signing out and back in');
  } finally {
    if (first !== null) await first.context.close();
    if (second !== null) await second.context.close();
  }
});

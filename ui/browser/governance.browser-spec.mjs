/**
 * The Governance policy screen in a real browser, against the throwaway instance (Story 14.2, AC1).
 *
 * Two claims, on rendered DOM and the instance's own read.
 *
 * AC1: a key set to Disabled under the Read-only preset and saved in the browser reaches the
 * instance, the row reads "Disabled" beside "by this setting", a reload shows the same, and the
 * route reads it back.
 *
 * AC2 (Story 21.40): at 1280 px light, with the renderer's CPU throttled 4x and the read's keys
 * doubled inside the test's own browser, the page opened from the shell settles within a bound,
 * draws twice the instance's keys, and runs no single task longer than a bound. The doubling is a
 * `.x2` copy of every row added to the GET answer by the browser's own network layer; the instance
 * never holds those keys and the test saves nothing. AC2 needs the rebuilt bundle deployed and an
 * instance answering at least one governance key.
 *
 * **It refuses the live container**: AC1 writes the instance's governance policy, and puts it back
 * to the default in `finally` through the shipped route, so no later spec starts from a disabled
 * key.
 *
 * Run: `npm run test:browser` (after `npm run build` and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { authHeader as sharedAuthHeader, saveAndSettle, signedInAt as walkSignedInAt } from './panel-spec.mjs';
import { governanceRowVersion, resetGovernancePolicy, resetRememberedState } from './preferences-reset.mjs';
import { VIEWPORTS, goInApp, settle, trackRequests } from './structural-walk.mjs';
import { clearGovernancePolicy } from './turnprobe-spec.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const GOVERNANCE_URL = '/ocupilot/agent/governance?ns=HSCUSTOM';
const GOVERNANCE_PATH = '/api/ocupilot/agent/governance';
const TOOL = 'webapp.list.update';

let browser = null;
// Whether no policy was stored before this file ran: the resets below save a default row, which the end clears.
let noStoredPolicy = false;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec drives the throwaway, never the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  noStoredPolicy = (await governanceRowVersion()) === 0;
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  browser = null;
  if (noStoredPolicy) {
    clearGovernancePolicy(config.container);
    assert.equal(await governanceRowVersion(), 0, 'no governance policy is stored, as before this file ran');
  }
});

/** A fresh context signed in through the shell's own form, landed at `url`. */
async function signedInAt(url) {
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  await page.goto(`${config.origin}${url}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', config.username);
  await page.type('#ocu-signin-password', config.password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, url);
  return { context, page };
}

/** What the row for `key` reads under In effect. */
function effectOf(page, key) {
  return page.$eval(`[id="ocu-governance-key-${key}"]`, (cell) => cell.parentElement.cells[3].textContent.trim());
}

test('AC1: a key disabled under Read-only in the browser is stored, shown by its setting, and survives a reload', async () => {
  const { context, page } = await signedInAt(GOVERNANCE_URL);
  try {
    const select = `[id="ocu-governance-setting-${TOOL}"]`;
    await page.waitForSelector(select, { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await effectOf(page, TOOL), `${STRINGS.tableColumnEnabled} \u00B7 ${STRINGS.agentGovernanceSourceBaseline}`, 'the key starts enabled by the baseline');

    await page.click('#ocu-governance-preset-read-only');
    await page.select(select, 'disabled');
    await saveAndSettle(page, config);
    const expected = `${STRINGS.agentGovernanceDisabled} \u00B7 ${STRINGS.agentGovernanceSourceSetting}`;
    await page.waitForFunction(
      (id, text) => document.getElementById(id)?.parentElement?.cells[3]?.textContent?.trim() === text,
      { timeout: config.navigationTimeoutMs },
      `ocu-governance-key-${TOOL}`,
      expected
    );

    await page.reload({ waitUntil: 'networkidle2' });
    await page.waitForSelector(select, { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await effectOf(page, TOOL), expected, 'a reload shows the key disabled by its setting');
    assert.equal(await page.$eval(select, (node) => node.value), 'disabled', 'with its setting selected');
    assert.equal(await page.$eval('#ocu-governance-preset-read-only', (node) => node.checked), true, 'and Read-only chosen');

    const stored = await (
      await fetch(`${config.origin}${GOVERNANCE_PATH}`, { headers: { Authorization: sharedAuthHeader(config) } })
    ).json();
    const row = stored.keys.find((entry) => entry.key === TOOL);
    assert.equal(stored.preset, 'read-only', 'the instance holds the preset the browser chose');
    assert.deepEqual(
      { setting: row.setting, enabled: row.enabled, source: row.source },
      { setting: 'disabled', enabled: false, source: 'setting' },
      'and the key the browser disabled'
    );
  } finally {
    await context.close();
    await resetGovernancePolicy();
  }
});

/** The CPU throttle AC2 runs under, which covers the CI runner's measured slowdown. */
const THROTTLE_RATE = 4;
/** How long AC2 lets the page take to settle, in ms: 1.5 times the worst of twelve cold runs (1,818 ms), rounded up. */
const SETTLE_BOUND_MS = 3000;
/** The longest single task AC2 allows after the throttle starts, in ms. */
const LONGEST_TASK_BOUND_MS = 1000;
/** What a doubled row's key ends in. */
const DOUBLED_SUFFIX = '.x2';

/**
 * Answer every GET of the governance read on `page` with a `DOUBLED_SUFFIX` copy of each row added,
 * in name order, and everything else untouched. Answers the CDP session, which the caller throttles,
 * and `failures`, the errors the handler met.
 */
async function doubleGovernanceAnswer(page) {
  const cdp = await page.createCDPSession();
  const failures = [];
  cdp.on('Fetch.requestPaused', async (event) => {
    const { requestId, request, responseStatusCode } = event;
    try {
      if (request.method !== 'GET' || responseStatusCode !== 200) {
        await cdp.send('Fetch.continueRequest', { requestId });
        return;
      }
      const { body, base64Encoded } = await cdp.send('Fetch.getResponseBody', { requestId });
      const answer = JSON.parse(base64Encoded ? Buffer.from(body, 'base64').toString('utf8') : body);
      answer.keys = [...answer.keys, ...answer.keys.map((row) => ({ ...row, key: row.key + DOUBLED_SUFFIX }))].sort((a, b) =>
        a.key < b.key ? -1 : a.key > b.key ? 1 : 0
      );
      const headers = (event.responseHeaders ?? []).filter((header) => !['content-length', 'content-encoding'].includes(header.name.toLowerCase()));
      await cdp.send('Fetch.fulfillRequest', {
        requestId,
        responseCode: 200,
        responseHeaders: headers,
        body: Buffer.from(JSON.stringify(answer), 'utf8').toString('base64'),
      });
    } catch (error) {
      failures.push(error);
      await cdp.send('Fetch.continueRequest', { requestId }).catch(() => {});
    }
  });
  await cdp.send('Fetch.enable', { patterns: [{ urlPattern: `*${GOVERNANCE_PATH}*`, requestStage: 'Response' }] });
  return { cdp, failures };
}

test('AC2 (Story 21.40): the page opened under a 4x CPU throttle with its keys doubled settles within its bound and draws every key', async () => {
  const read = await fetch(`${config.origin}${GOVERNANCE_PATH}`, { headers: { Authorization: sharedAuthHeader(config) } });
  assert.equal(read.status, 200, 'the instance answers the governance read');
  const unmodified = await read.json();
  assert.ok(unmodified.keys.length > 0, 'the instance answers governance keys');
  const { context, page } = await walkSignedInAt(browser, config, '/ocupilot/?ns=HSCUSTOM', VIEWPORTS.wide, [
    { name: 'prefers-reduced-motion', value: 'reduce' },
    { name: 'prefers-color-scheme', value: 'light' },
  ]);
  let cdp = null;
  try {
    const requests = trackRequests(page);
    const home = await settle(page, requests, 'home');
    assert.equal(home.settled, true, `home settles before the throttle starts: ${home.why}`);
    const doubling = await doubleGovernanceAnswer(page);
    cdp = doubling.cdp;
    await cdp.send('Emulation.setCPUThrottlingRate', { rate: THROTTLE_RATE });
    await page.evaluate(() => {
      window.__ocuLongTasks = [];
      new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) window.__ocuLongTasks.push({ start: entry.startTime, duration: entry.duration });
      }).observe({ type: 'longtask' });
      window.__ocuLongTaskMark = performance.now();
    });

    const visit = await goInApp(page, requests, GOVERNANCE_URL, config.navigationTimeoutMs);

    assert.deepEqual(doubling.failures, [], 'the answer was doubled without an error');
    assert.equal(visit.settled, true, `the page settles: ${visit.why}`);
    assert.ok(visit.ms <= SETTLE_BOUND_MS, `the page settled in ${visit.ms} ms, over ${SETTLE_BOUND_MS} ms`);
    const drawn = await page.$$eval('.ocu-governance-key', (cells) => cells.length);
    assert.equal(drawn, 2 * unmodified.keys.length, 'the page draws twice the instance\'s keys');
    const durations = await page.evaluate(() => window.__ocuLongTasks.filter((task) => task.start >= window.__ocuLongTaskMark).map((task) => task.duration));
    const longest = Math.round(Math.max(0, ...durations));
    assert.ok(longest <= LONGEST_TASK_BOUND_MS, `the longest task ran ${longest} ms, over ${LONGEST_TASK_BOUND_MS} ms`);
    console.log(`governance AC2: ${drawn} keys, settled in ${visit.ms} ms, ${durations.length} long task(s), longest ${longest} ms`);
  } finally {
    if (cdp !== null) await cdp.send('Emulation.setCPUThrottlingRate', { rate: 1 }).catch(() => {});
    await context.close();
  }
});

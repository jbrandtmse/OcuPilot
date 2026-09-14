/**
 * DW-96 end to end: a revoked grant on a real throwaway instance, observed by every consumer the
 * `unreadable` gate state exists for, then repaired by running install again.
 *
 * **What the other tiers cannot show.** `GateLadder`, `Gate` and `Readiness` drive the gate through
 * seams that stand in for the version-row read; `session.test.mjs`, `app.spec.ts` and
 * `instance-notice.spec.ts` hand-build the 503 or set the session state directly. None of them
 * revokes a grant, so none proves that the real read under a real revoke reaches readiness, the
 * API envelope, `wait-readiness.sh` and a real browser as `unreadable`, or that install repairs it.
 *
 * **It changes the throwaway's security state, so it refuses the live container.** `npm run
 * test:browser` runs one file at a time, in name order, so a file after this one meets the
 * instance its final test repaired. The grant is revoked from the
 * role install grants it to, for a non-`%All` principal this file creates: a `%All` caller bypasses
 * SQL privileges and keeps reading `installed`. `after` runs install again and deletes the
 * principal whether or not a test failed.
 *
 * Mutation (Rule 19): in the throwaway, rewrite the served client bundle's `INSTALL.UNREADABLE`
 * literal -> the SPA classifies the refusal as install-in-flight, shows "Signing in..." and backs
 * off, and the SPA test goes red. In the throwaway, load an `Installer.cls` whose `GateStatus`
 * sets `installing` where it sets `unreadable` -> the readiness, envelope and `wait-readiness.sh`
 * tests go red.
 *
 * Run: `npm run test:browser` (after `npm run build` and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { setTimeout as sleep } from 'node:timers/promises';
import puppeteer from 'puppeteer';

import {
  LIVE_CONTAINER,
  READINESS_PATH,
  SHELL_PATH,
  browserConfig,
  launchOptions,
} from '../browser.config.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const PROBE_USER = 'OcuPilotBrowserProbe';
const PROBE_ROLE = 'OcuPilotBrowserProbeRole';
const PROBE_PASSWORD = 'OcuPilotProbe1';
const INSTANCE_PATH = '/api/ocupilot/instance';
const QUIET_WINDOW_MS = 4000;

let browser = null;
let revoked = false;

/**
 * Run ObjectScript lines in `iris session` inside the throwaway, starting in `%SYS`, and return the
 * value each named marker carries. Markers are split on their source line, so the echoed source
 * cannot supply one.
 */
function irisSession(lines, names) {
  const input = `${[...lines, 'Halt'].join('\n')}\n`;
  const result = spawnSync(
    'docker',
    ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', '%SYS'],
    { input, encoding: 'utf8', timeout: 600000 }
  );
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const values = {};
  for (const name of names) {
    const match = new RegExp(`OCU-${name}-START:(.*?):OCU-${name}-END`).exec(output);
    values[name] = match === null ? null : match[1];
  }
  return { values, output };
}

const mark = (name, expression) => `Write "OCU"_"-${name}-START:"_${expression}_":OCU"_"-${name}-END",!`;
const toInstallNamespace = 'Set $NAMESPACE=$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"):"HSCUSTOM",1:"USER")';

async function readiness() {
  const response = await fetch(`${config.origin}${READINESS_PATH}`);
  return { status: response.status, body: await response.json() };
}

/** A token pair for the probe principal, minted at the API's own token endpoint, which is not gated. */
async function probeAccessToken() {
  const response = await fetch(`${config.origin}/api/ocupilot/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ user: PROBE_USER, password: PROBE_PASSWORD }),
  });
  assert.equal(response.status, 200, `the probe principal signs in at the token endpoint (HTTP ${response.status})`);
  const pair = await response.json();
  assert.equal(typeof pair.access_token, 'string', 'and is handed an access token');
  return pair.access_token;
}

function repair() {
  const { values, output } = irisSession(
    [
      toInstallNamespace,
      'Set tSC=##class(OcuPilot.Install.Installer).Install("")',
      mark('INSTALL', '$System.Status.IsOK(tSC)'),
      'Set $NAMESPACE="%SYS"',
      `If ##class(Security.Users).Exists("${PROBE_USER}") Do ##class(Security.Users).Delete("${PROBE_USER}")`,
      `If ##class(Security.Roles).Exists("${PROBE_ROLE}") Do ##class(Security.Roles).Delete("${PROBE_ROLE}")`,
      mark('CLEAN', `'##class(Security.Users).Exists("${PROBE_USER}")`),
    ],
    ['INSTALL', 'CLEAN']
  );
  revoked = false;
  return { values, output };
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec revokes a grant, so it never runs inside the live container');
  const ready = await readiness();
  assert.equal(ready.body.state, 'installed', `the throwaway must start installed, not ${JSON.stringify(ready.body)}`);
  browser = await puppeteer.launch(launchOptions(config));

  const { values, output } = irisSession(
    [
      'Set tNS=$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"):"HSCUSTOM",1:"USER")',
      'Set tRes=##class(SYS.Database).%OpenId(##class(Config.Databases).Open(##class(Config.Namespaces).Open(tNS).Routines).Directory).ResourceName',
      `If '##class(Security.Roles).Exists("${PROBE_ROLE}") Do ##class(Security.Roles).Create("${PROBE_ROLE}","OcuPilot browser spec probe (throwaway)",tRes_":R,%Admin_Operate:U","")`,
      `If ##class(Security.Users).Exists("${PROBE_USER}") Do ##class(Security.Users).Delete("${PROBE_USER}")`,
      `Set tSC=##class(Security.Users).Create("${PROBE_USER}","${PROBE_ROLE}","${PROBE_PASSWORD}","OcuPilot browser spec probe (throwaway)","","","",0,1,"")`,
      mark('USER', '$System.Status.IsOK(tSC)'),
      'Set $NAMESPACE=tNS',
      'Do ##class(OcuPilot.Install.Installer).StateTables(.tT)',
      'Set tSQL="REVOKE SELECT,INSERT,UPDATE,DELETE ON SCHEMA "_$Order(tT(""))_" FROM "_$Parameter("OcuPilot.Kernel.State.Base","DBRESOURCE")',
      'Set tRS=##class(%SQL.Statement).%ExecDirect(,tSQL)',
      mark('REVOKE', 'tRS.%SQLCODE'),
    ],
    ['USER', 'REVOKE']
  );
  assert.equal(values.USER, '1', `the probe principal was created:\n${output}`);
  revoked = values.REVOKE !== null;
  assert.equal(values.REVOKE, '0', `the grant was revoked:\n${output}`);
});

after(async () => {
  if (browser !== null) await browser.close();
  if (revoked) repair();
});

test('DW-96: readiness reports unreadable inside its three keys', async () => {
  const { status, body } = await readiness();
  assert.equal(status, 200);
  assert.deepEqual(body, { installed: false, version: '', state: 'unreadable' });
});

test('DW-96: a non-%All API request is refused 503 INSTALL.UNREADABLE, naming no schema or role', async () => {
  const access = await probeAccessToken();
  const response = await fetch(`${config.origin}${INSTANCE_PATH}`, {
    headers: { Authorization: `Bearer ${access}` },
  });
  assert.equal(response.status, 503);
  const envelope = await response.json();
  assert.equal(envelope.error, 'unavailable');
  assert.equal(envelope.code, 'INSTALL.UNREADABLE');
  assert.doesNotMatch(envelope.reason, /OcuPilot_Kernel_State|%DB_/, `the reason names no schema or role: ${envelope.reason}`);
});

test('DW-96, DW-229: wait-readiness.sh exits 1 on its first poll, naming the state', () => {
  const result = spawnSync(
    'sh',
    [join(uiRoot, '..', 'scripts', 'wait-readiness.sh'), '--url', `${config.origin}${READINESS_PATH}`, '--timeout', '60'],
    { encoding: 'utf8', timeout: 90000 }
  );
  assert.equal(result.status, 1, `exit ${result.status}: ${result.stdout}${result.stderr}`);
  assert.match(result.stdout, /UNREADABLE after 0s/, result.stdout);
});

test('DW-96: the SPA shows the unreadable notice, never "Signing in", arms no retry, and Retry re-checks once', async () => {
  const context = await browser.createBrowserContext();
  try {
    const page = await context.newPage();
    page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
    const apiRequests = [];
    page.on('request', (request) => {
      const path = new URL(request.url()).pathname;
      if (path.startsWith('/api/ocupilot/')) apiRequests.push(path);
    });
    const instanceReads = () => apiRequests.filter((path) => path === INSTANCE_PATH).length;
    const noticeShown = () =>
      page.waitForFunction(
        (sentence) =>
          document.querySelector('app-instance-notice section[role="alert"] h1')?.textContent?.trim() === sentence,
        { timeout: config.navigationTimeoutMs },
        STRINGS.authInstallStateUnreadable
      );

    await page.goto(`${config.origin}${SHELL_PATH}`, { waitUntil: 'networkidle2' });
    await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
    await page.type('#ocu-signin-user', PROBE_USER);
    await page.type('#ocu-signin-password', PROBE_PASSWORD);
    await page.click('.ocu-signin-card button[type="submit"]');
    await noticeShown();

    const focused = await page.evaluate(
      () => document.activeElement === document.querySelector('app-instance-notice section[role="alert"]')
    );
    assert.equal(focused, true, 'the notice takes focus');

    const settled = apiRequests.length;
    await sleep(QUIET_WINDOW_MS);
    assert.deepEqual(apiRequests.slice(settled), [], 'no backoff probe or re-read was issued while the notice showed');
    const text = await page.evaluate(() => document.body.innerText);
    assert.ok(!text.includes(STRINGS.statusConnectionSigningIn), 'and "Signing in" never appears');

    const readsBefore = instanceReads();
    const clicked = await page.evaluate((label) => {
      const retry = Array.from(document.querySelectorAll('app-instance-notice button')).find(
        (button) => button.textContent?.trim() === label
      );
      retry?.click();
      return retry !== undefined;
    }, STRINGS.actionRetry);
    assert.equal(clicked, true, 'the notice offers Retry');

    const deadline = Date.now() + config.navigationTimeoutMs;
    while (instanceReads() === readsBefore && Date.now() < deadline) await sleep(100);
    await noticeShown();
    await sleep(QUIET_WINDOW_MS);
    assert.equal(instanceReads(), readsBefore + 1, 'Retry issued exactly one identity read, and the notice returned');
  } finally {
    await context.close();
  }
});

test('DW-96: running install again restores the grant, and the gate serves', async () => {
  const { values, output } = repair();
  assert.equal(values.INSTALL, '1', `install ran again successfully:\n${output}`);
  assert.equal(values.CLEAN, '1', 'and the probe principal is gone');
  const { body } = await readiness();
  assert.equal(body.state, 'installed', `readiness reports installed after the repair: ${JSON.stringify(body)}`);
});

/**
 * The SSL/TLS configuration editor in a real browser, against the throwaway instance (Story 9.5).
 *
 * What it pins, each on rendered DOM, on the real URL or on the instance itself:
 *
 * 1. **A row's name opens the editor** at `security/ssl/edit/<name>`, on General, Verification,
 *    Credentials, Cryptographic settings and OCSP settings, each value read from the instance, a
 *    file location read-only and the CRL caption on Verification (AC1, Integration).
 * 2. **Create lands on "Saved"** at the new configuration's own route, and the instance holds it
 *    (AC5).
 * 3. **A two-field Save preserves every other field**, read back inside the container (AC5).
 * 4. **OcuPilot's own provider configuration** shows its role, draws its type, peer verification,
 *    trusted certificates and enablement disabled with the published sentence, and a change to one
 *    of them sends nothing (AC3). The server's refusal of such a change is pinned by
 *    `OcuPilot.Test.SslSave` over a port that holds the write; this spec never sends one.
 * 5. **A refusal on General while another tab is open** opens General with its dot and count, and a
 *    changed editor asks before it is left (Integration).
 * 6. **Test connection** fails against the instance's own plain-HTTP port and passes against an
 *    `openssl s_server` started inside the container, each under its published heading with the
 *    instance's own lines (AC4). The server's key material is made at run time in a directory this
 *    spec deletes by exact path afterwards.
 * 7. **The visual gate** at 1440x900 (DW-1337).
 *
 * **It refuses the live container.** Its probe configurations are made and removed by exact name
 * through `OcuPilot.Test.SecurityDeleteProbe`, which deletes only a configuration carrying its own
 * description.
 *
 * Run: `npm run test:browser` (after `npm run build` and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const PROBE_CLASS = 'OcuPilot.Test.SecurityDeleteProbe';
const MARKER = 'OcuPilot 9.5 browser probe';
const LIST_URL = '/ocupilot/security/ssl?ns=HSCUSTOM';

/** The configuration every editor leg opens, and the one the create leg makes. */
const PROBE = 'OcuPilotProbe95Editor';
const CREATED = 'OcuPilotProbe95Created';
const OWN = 'OcuPilotProvider';
const EDIT_URL = `/ocupilot/security/ssl/edit/${PROBE}?ns=HSCUSTOM`;

/** The TLS server Test connection reaches, and where its run-time material lives. */
const SERVER_PORT = 44395;
const PLAIN_PORT = 52773;
const SERVER_DIRECTORY = '/tmp/ocupilot-ssl-editor-spec';

const TABS = [STRINGS.processDetailsGroupGeneral, STRINGS.sslTabVerification, STRINGS.sslTabCredentials, STRINGS.sslTabCryptography, STRINGS.sslTabOcsp];

let browser = null;

const mark = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

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
    const found = new RegExp(`OCU-${name}-START:(.*?):OCU-${name}-END`).exec(output);
    values[name] = found === null ? null : found[1];
  }
  return { values, output };
}

/** Run `script` in a shell inside the throwaway. */
function inContainer(script) {
  const result = spawnSync('docker', ['exec', config.container, 'sh', '-c', script], { encoding: 'utf8', timeout: 120000 });
  return { status: result.status, output: `${result.stdout ?? ''}${result.stderr ?? ''}` };
}

/** Configuration `name` as the vendor's `Get` answers it: `gone`, or `field=value` pairs joined by `|`. */
function stored(name, fields) {
  const { values } = irisSession(
    [
      'New $Namespace Set $Namespace="%SYS"',
      `Kill p Set tThere=##class(Security.SSLConfigs).Exists("${name}") If tThere Do ##class(Security.SSLConfigs).Get("${name}",.p)`,
      mark('GOT', `$Select(tThere: ${fields.map((field) => `"${field}="_$Get(p("${field}"))`).join('_"|"_')}, 1: "gone")`),
    ],
    ['GOT']
  );
  return values.GOT;
}

/** Remove both probes by exact name (only where they carry the probe's description) and make the editor's afresh. */
function resetProbes() {
  return irisSession(
    [
      `Set tSC=##class(${PROBE_CLASS}).RemoveSsl("${PROBE}")`,
      `If $System.Status.IsOK(tSC) Set tSC=##class(${PROBE_CLASS}).RemoveSsl("${CREATED}")`,
      `If $System.Status.IsOK(tSC) Set tSC=##class(${PROBE_CLASS}).CreateSsl("${PROBE}")`,
      mark('MADE', '$System.Status.IsOK(tSC)'),
    ],
    ['MADE']
  );
}

/** Stop the TLS server and delete its directory by exact path; true when neither survives. */
function stopServer() {
  inContainer(`[ -f ${SERVER_DIRECTORY}/pid ] && kill $(cat ${SERVER_DIRECTORY}/pid) 2>/dev/null; sleep 1; rm -rf ${SERVER_DIRECTORY}`);
  return inContainer(`[ ! -e ${SERVER_DIRECTORY} ] && ! ps -eo args | grep -q "[s]_server -accept ${SERVER_PORT}"`).status === 0;
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates and deletes SSL/TLS configurations, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  const { values, output } = resetProbes();
  assert.equal(values.MADE, '1', `the probe configuration was made:\n${output}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  assert.ok(stopServer(), 'the TLS server and its material are gone');
  const { values, output } = irisSession(
    [
      `Set tSC=##class(${PROBE_CLASS}).RemoveSsl("${PROBE}")`,
      `If $System.Status.IsOK(tSC) Set tSC=##class(${PROBE_CLASS}).RemoveSsl("${CREATED}")`,
      mark('CLEAN', '$System.Status.IsOK(tSC)'),
    ],
    ['CLEAN']
  );
  assert.equal(values.CLEAN, '1', `the probe configurations are removed:\n${output}`);
});

/** A fresh context signed in through the shell's own form, landed at `url`, with its writes to `/ssl` counted. */
async function signedInAt(url) {
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  const writes = [];
  page.on('request', (request) => {
    const path = new URL(request.url()).pathname;
    if (path.startsWith('/api/ocupilot/ssl') && request.method() !== 'GET') writes.push({ path, method: request.method(), body: request.postData() ?? '' });
  });
  await page.goto(`${config.origin}${url}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', config.username);
  await page.type('#ocu-signin-password', config.password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, url);
  return { context, page, writes };
}

/** Wait until the editor holds configuration `name`'s read. */
async function editorReady(page, name) {
  await page.waitForFunction(
    (wanted) => document.querySelector('#ocu-ssl-Name')?.value === wanted && document.querySelector('#ocu-ssl-Description')?.readOnly === false,
    { timeout: config.navigationTimeoutMs },
    name
  );
}

/** Replace control `id`'s text with `value`. */
async function fill(page, id, value) {
  await page.click(`#${id}`, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(`#${id}`, value);
}

/** The tab strip: each tab's label, accessible name, selection and dot. */
function tabState(page) {
  return page.$$eval('app-form-tabs [role="tab"]', (tabs) =>
    tabs.map((tab) => ({
      label: tab.querySelector('.ocu-form-tab-label')?.textContent.trim() ?? '',
      name: tab.getAttribute('aria-label'),
      selected: tab.getAttribute('aria-selected') === 'true',
      dot: tab.querySelector('.ocu-form-tab-dot') !== null,
    }))
  );
}

async function openTab(page, label) {
  await page.evaluate((wanted) => {
    const tabs = Array.from(document.querySelectorAll('app-form-tabs [role="tab"]'));
    tabs.find((tab) => tab.querySelector('.ocu-form-tab-label')?.textContent.trim() === wanted).click();
  }, label);
  await page.waitForFunction(
    (wanted) =>
      Array.from(document.querySelectorAll('app-form-tabs [role="tab"]')).some(
        (tab) => tab.getAttribute('aria-selected') === 'true' && tab.querySelector('.ocu-form-tab-label')?.textContent.trim() === wanted
      ),
    { timeout: config.navigationTimeoutMs },
    label
  );
}

async function save(page) {
  await page.click('.ocu-form-bar-actions .ocu-button-primary');
}

/** Wait for the form bar's "Saved". */
async function saved(page) {
  await page.waitForFunction(
    (text) => document.querySelector('.ocu-form-bar-status [role="status"]')?.textContent.trim() === text,
    { timeout: config.navigationTimeoutMs },
    STRINGS.formSaved
  );
}

/** Text of element `id`, or null. */
function textOf(page, id) {
  return page.evaluate((wanted) => document.getElementById(wanted)?.textContent.trim() ?? null, id);
}

// AC1, Integration. Mutation (Rule 19): drop the Credentials tab from the page's tab list and
// redeploy -> the five-tab assertion goes red.
test('AC1: a row\u2019s name opens the editor on its five tabs, each value read from the instance', async () => {
  const { context, page } = await signedInAt(LIST_URL);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await page.type(FILTER_SELECTOR, PROBE);
    await page.waitForFunction((selector) => document.querySelectorAll(selector).length === 1, { timeout: config.navigationTimeoutMs }, ROW_SELECTOR);
    await clickRowCentre(page, { index: 0, link: true });
    await page.waitForFunction((name) => new URL(window.location.href).pathname.endsWith(`/security/ssl/edit/${name}`), { timeout: config.navigationTimeoutMs }, PROBE);
    await editorReady(page, PROBE);
    assert.deepEqual((await tabState(page)).map((tab) => tab.label), TABS, 'General, Verification, Credentials, Cryptographic settings and OCSP settings');
    assert.equal(await page.$eval('#ocu-ssl-Description', (node) => node.value), MARKER, "General reads the instance's description");
    await openTab(page, STRINGS.sslTabVerification);
    assert.equal(await page.$eval('#ocu-ssl-VerifyPeer', (node) => node.value), '0', 'Verification reads its peer verification');
    assert.equal(await textOf(page, 'ocu-ssl-crl'), STRINGS.sslCrlDeprecated, 'and states that a CRL is not set on a configuration');
    await openTab(page, STRINGS.sslTabCredentials);
    const files = await page.$$eval('app-ssl-form-page input[readonly]', (inputs) => inputs.map((input) => input.id));
    assert.ok(files.includes('ocu-ssl-CertificateFile') && files.includes('ocu-ssl-PrivateKeyFile'), `the file locations are shown read-only: ${JSON.stringify(files)}`);
    assert.equal(await textOf(page, 'ocu-ssl-classic-credentials'), STRINGS.sslFileClassicOnly, 'and captioned as set on the classic page');
    await openTab(page, STRINGS.sslTabCryptography);
    assert.equal(await page.$eval('#ocu-ssl-TLSMinVersion', (node) => node.value), '16', 'Cryptographic settings reads the protocol minimum');
    await openTab(page, STRINGS.sslTabOcsp);
    assert.equal(await page.$eval('#ocu-ssl-OCSP', (node) => node.checked), false, 'and OCSP settings reads OCSP as off');
  } finally {
    await context.close();
  }
});

test('AC5: Create saves a client configuration, lands on its own route reading "Saved", and the instance holds it', async () => {
  const { context, page } = await signedInAt(LIST_URL);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const create = await page.waitForSelector('.ocu-command-bar button.ocu-button-primary', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await create.evaluate((node) => node.textContent.trim()), STRINGS.actionCreate, 'the list offers Create');
    await create.click();
    await page.waitForFunction(() => new URL(window.location.href).pathname.endsWith('/security/ssl/edit'), { timeout: config.navigationTimeoutMs });
    await page.waitForSelector('#ocu-ssl-Name:not([readonly])', { visible: true, timeout: config.navigationTimeoutMs });
    await page.type('#ocu-ssl-Name', CREATED);
    await fill(page, 'ocu-ssl-Description', MARKER);
    await save(page);
    await page.waitForFunction((name) => new URL(window.location.href).pathname.endsWith(`/security/ssl/edit/${name}`), { timeout: config.navigationTimeoutMs }, CREATED);
    await saved(page);
    assert.equal(stored(CREATED, ['Type', 'Enabled', 'Description']), `Type=0|Enabled=1|Description=${MARKER}`, 'the instance holds the new client');
  } finally {
    await context.close();
  }
});

// AC5. The merge over the fresh read is pinned by `OcuPilot.Test.SslSave`'s key-count assertion
// (mutation: merge over {Name}); this leg reads the result back from the instance.
test('AC5: a two-field Save changes those two and every other field reads back as it was', async () => {
  resetProbes();
  const others = ['Type', 'VerifyPeer', 'VerifyDepth', 'TLSMaxVersion', 'CipherList', 'Ciphersuites', 'OCSP', 'Enabled', 'CAFile'];
  const before = stored(PROBE, others);
  const { context, page, writes } = await signedInAt(EDIT_URL);
  try {
    await editorReady(page, PROBE);
    await fill(page, 'ocu-ssl-Description', 'OcuPilot 9.5 browser probe edited');
    await openTab(page, STRINGS.sslTabCryptography);
    await page.select('#ocu-ssl-TLSMinVersion', '32');
    await save(page);
    await saved(page);
    assert.equal(writes.length, 1, 'one Save');
    assert.equal(writes[0].method, 'PUT');
    assert.equal(stored(PROBE, ['Description', 'TLSMinVersion']), 'Description=OcuPilot 9.5 browser probe edited|TLSMinVersion=32', 'the two fields read back as saved');
    assert.equal(stored(PROBE, others), before, 'and every other field reads back as it was');
  } finally {
    await context.close();
    resetProbes();
  }
});

// AC3. Mutation (Rule 19): drop the `[disabled]` binding on the peer verification select and
// redeploy -> the disabled assertion goes red.
test("AC3: OcuPilot's own configuration shows its role and draws its four installer-owned fields refused, and a change to one sends nothing", async () => {
  const fields = ['Type', 'VerifyPeer', 'CAFile', 'Enabled', 'Description'];
  const before = stored(OWN, fields);
  const { context, page, writes } = await signedInAt(`/ocupilot/security/ssl/edit/${OWN}?ns=HSCUSTOM`);
  try {
    // Any write this page attempts is aborted in the browser and only counted, so no regression in
    // the client's guard can reach the instance's own configuration from this leg.
    await page.setRequestInterception(true);
    page.on('request', (request) => {
      if (new URL(request.url()).pathname.startsWith('/api/ocupilot/ssl') && request.method() !== 'GET') request.abort();
      else request.continue();
    });
    await editorReady(page, OWN);
    assert.equal(await textOf(page, 'ocu-ssl-own-role'), STRINGS.sslOwnRole, 'the role sentence is visible');
    const refused = [];
    for (const [tab, field] of [
      [STRINGS.processDetailsGroupGeneral, 'Enabled'],
      [STRINGS.processDetailsGroupGeneral, 'Type'],
      [STRINGS.sslTabVerification, 'VerifyPeer'],
      [STRINGS.sslTabVerification, 'CAFile'],
    ]) {
      await openTab(page, tab);
      refused.push(
        await page.evaluate((id) => ({ id, disabled: document.getElementById(id)?.disabled ?? null, caption: document.getElementById(`${id}-refusal`)?.textContent.trim() ?? null }), `ocu-ssl-${field}`)
      );
    }
    for (const entry of refused) {
      assert.deepEqual(entry, { id: entry.id, disabled: true, caption: STRINGS.sslRefusalOcuPilot }, `${entry.id} is drawn refused with the published sentence`);
    }
    await page.evaluate(() => {
      const select = document.getElementById('ocu-ssl-VerifyPeer');
      select.disabled = false;
      select.value = '0';
      select.dispatchEvent(new Event('change', { bubbles: true }));
    });
    await save(page);
    await page.waitForNetworkIdle({ idleTime: 500, timeout: config.navigationTimeoutMs });
    assert.equal(writes.length, 0, 'a change forced onto a refused field attempts no write');
    assert.equal(stored(OWN, fields), before, 'and the configuration reads back unchanged');
  } finally {
    await context.close();
  }
});

// Integration. Mutation (Rule 19): skip `tabToOpen` in the page's refusal handling and redeploy ->
// the selected-tab assertion goes red.
test('a refusal on General while OCSP settings is open opens General, with its dot and count; a changed editor asks before it is left', async () => {
  const { context, page, writes } = await signedInAt(EDIT_URL);
  try {
    await editorReady(page, PROBE);
    // The field's maxlength stops typing past the vendor's length, so the over-long value is set as a
    // paste would leave it and the server's rule is what refuses it.
    await page.evaluate(() => {
      const input = document.getElementById('ocu-ssl-Description');
      input.value = 'x'.repeat(300);
      input.dispatchEvent(new Event('input', { bubbles: true }));
    });
    await openTab(page, STRINGS.sslTabOcsp);
    await save(page);
    await page.waitForSelector('.ocu-form-summary', { visible: true, timeout: config.navigationTimeoutMs });
    await page.waitForFunction(() => document.activeElement?.id === 'ocu-ssl-Description', { timeout: config.navigationTimeoutMs });
    const tabs = await tabState(page);
    assert.equal(tabs[0].selected, true, 'General opened');
    assert.equal(tabs[0].dot, true, 'with the destructive dot');
    assert.equal(tabs[0].name, `${STRINGS.processDetailsGroupGeneral}, 1 error`, 'and its count in its accessible name');
    assert.equal(tabs[4].dot, false, 'OCSP settings carries none');
    assert.equal(stored(PROBE, ['Description']), `Description=${MARKER}`, 'and nothing reached the instance');
    assert.ok(writes.length <= 1, 'at most the one refused Save');

    await page.click('.ocu-form-bar-actions .ocu-button-text');
    await page.waitForSelector('[role="dialog"] .ocu-dialog-title', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[role="dialog"] .ocu-dialog-title', (node) => node.textContent.trim()), STRINGS.formLeaveWithoutSaving);
    await (await page.$('[role="dialog"] .ocu-dialog-actions button')).click();
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    assert.ok(new URL(page.url()).pathname.endsWith(`/security/ssl/edit/${PROBE}`), 'staying keeps the editor open');
    assert.equal((await page.$eval('#ocu-ssl-Description', (node) => node.value)).length, 300, 'with the edit');
  } finally {
    await context.close();
  }
});

// AC4. The route's answer is pinned by `OcuPilot.Test.SslTest` (whose mutation answers the ordinary
// fault for a TEST); this leg pins what the page draws from it.
test('AC4: Test connection fails against a plain port and passes against a TLS server, each with the instance\u2019s own lines', async () => {
  const started = inContainer(
    `rm -rf ${SERVER_DIRECTORY} && mkdir -p ${SERVER_DIRECTORY} && cd ${SERVER_DIRECTORY} && ` +
      'openssl req -x509 -newkey rsa:2048 -nodes -keyout key.pem -out cert.pem -days 1 -subj /CN=localhost >/dev/null 2>&1 && ' +
      `(nohup openssl s_server -accept ${SERVER_PORT} -cert cert.pem -key key.pem -www >out.log 2>&1 & echo $! > pid) && sleep 1`
  );
  assert.equal(started.status, 0, `the TLS server started:\n${started.output}`);
  const { context, page } = await signedInAt(EDIT_URL);
  try {
    await editorReady(page, PROBE);
    const run = async (port) => {
      await fill(page, 'ocu-ssl-Host', 'localhost');
      await fill(page, 'ocu-ssl-Port', String(port));
      await page.click('[data-action="ssl-test"]');
      await page.waitForFunction(
        (previous) => {
          const heading = document.querySelector('[data-test-outcome]');
          return heading !== null && document.querySelector('.ocu-ssl-test-lines')?.textContent !== previous;
        },
        { timeout: config.navigationTimeoutMs },
        await page.evaluate(() => document.querySelector('.ocu-ssl-test-lines')?.textContent ?? '')
      );
      return page.evaluate(() => ({
        heading: document.querySelector('[data-test-outcome]').textContent.trim(),
        lines: Array.from(document.querySelectorAll('.ocu-ssl-test-lines li')).map((line) => line.textContent.trim()),
      }));
    };
    const failed = await run(PLAIN_PORT);
    assert.equal(failed.heading, STRINGS.sslTestFailed);
    assert.ok(failed.lines.some((line) => line.includes('wrong version number')), `under it the instance's own line: ${JSON.stringify(failed.lines)}`);
    const passed = await run(SERVER_PORT);
    assert.equal(passed.heading, STRINGS.sslTestPassed);
    assert.ok(passed.lines.some((line) => line.includes('SSL connection succeeded')), `under it the instance's own lines: ${JSON.stringify(passed.lines)}`);
  } finally {
    await context.close();
    assert.ok(stopServer(), 'the TLS server and its key material are gone');
  }
});

test('the visual gate at 1440x900: every control is named and at least 24x24, nothing overflows, and the bar sits inside the content area', async () => {
  const { context, page } = await signedInAt(EDIT_URL);
  try {
    await page.setViewport({ width: 1440, height: 900 });
    await editorReady(page, PROBE);
    for (const label of TABS) {
      await openTab(page, label);
      const report = await page.evaluate(() => {
        const nameOf = (node) => {
          const labelled = node.getAttribute('aria-labelledby');
          if (labelled) return labelled.split(' ').map((id) => document.getElementById(id)?.textContent.trim() ?? '').join(' ').trim();
          if (node.getAttribute('aria-label')) return node.getAttribute('aria-label').trim();
          if (node.labels && node.labels.length > 0) return Array.from(node.labels).map((item) => item.textContent.trim()).join(' ');
          return node.textContent.trim();
        };
        const root = document.querySelector('app-ssl-form-page');
        const controls = Array.from(root.querySelectorAll('input, select, textarea, button, [role="tab"]')).filter((node) => node.offsetParent !== null);
        const unnamed = controls.filter((node) => nameOf(node) === '').map((node) => node.outerHTML.slice(0, 120));
        // A checkbox wrapped in its label is targeted through the label, so the label is what is measured.
        const targetOf = (node) => (node.type === 'checkbox' && node.parentElement?.tagName === 'LABEL' ? node.parentElement : node);
        const small = controls
          .filter((node) => {
            const box = targetOf(node).getBoundingClientRect();
            const min = parseFloat(getComputedStyle(node).minWidth);
            return box.width < 24 || box.height < 24 || (Number.isFinite(min) && box.width + 0.5 < min);
          })
          .map((node) => node.outerHTML.slice(0, 120));
        const overflowing = Array.from(root.querySelectorAll('*'))
          .filter((node) => node.offsetParent !== null && node.parentElement !== null)
          .filter((node) => {
            const own = node.getBoundingClientRect();
            const parent = node.parentElement.getBoundingClientRect();
            if (getComputedStyle(node.parentElement).overflowX !== 'visible') return false;
            return own.width > 0 && own.right > parent.right + 1;
          })
          .map((node) => node.outerHTML.slice(0, 120));
        const content = document.querySelector('.ocu-content');
        const bar = document.querySelector('.ocu-form-bar');
        return {
          controls: controls.length,
          unnamed,
          small,
          overflowing,
          pageOverflow: document.documentElement.scrollWidth > document.documentElement.clientWidth,
          contentBottom: content === null ? null : content.getBoundingClientRect().bottom,
          barBottom: bar === null ? null : bar.getBoundingClientRect().bottom,
        };
      });
      assert.ok(report.controls > 3, `${label}: the gate looked at the editor's controls: ${report.controls}`);
      assert.deepEqual(report.unnamed, [], `${label}: every control has an accessible name`);
      assert.deepEqual(report.small, [], `${label}: none is smaller than 24x24 or narrower than its declared minimum`);
      assert.deepEqual(report.overflowing, [], `${label}: nothing overflows its container`);
      assert.equal(report.pageOverflow, false, `${label}: and the page does not scroll sideways`);
      assert.ok(report.barBottom !== null && report.barBottom <= report.contentBottom + 1, `${label}: the bar sits inside the content area: ${JSON.stringify(report)}`);
    }
  } finally {
    await context.close();
  }
});

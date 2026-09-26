/**
 * The two reduced editors in a real browser, against the throwaway instance (Story 9.9).
 *
 * What it pins, each on rendered DOM, on the real URL or on the instance itself:
 *
 * 1. **A Services row's name opens the reduced service form** at `permissions/services/edit/<name>`
 *    with Enabled and the allowed connections read from the instance, no tab, and the
 *    classic-link-card last: titled, captioned, naming the Services page and opening it in a new tab
 *    (AC1, AC2).
 * 2. **A Save adds an address**, reads "Saved", reaches the instance with the service's other
 *    fields unchanged (read back inside the container), and the list shows it (Integration).
 * 3. **An LDAP / Kerberos row opens the reduced LDAP form**, whose description Save reaches the
 *    instance and the list (AC1, Integration).
 * 4. **On the service OcuPilot is served through**, Enabled is drawn unavailable with the published
 *    sentence and a click sends nothing, while an address change shows the consequence line. This
 *    spec never saves that service (AC5).
 * 5. **The visual gate** at 1440x900 on both forms at an id route (DW-1337).
 *
 * **It refuses the live container.** It writes only `%Service_CallIn`, which is disabled, and
 * restores the snapshot it took; its LDAP probe is made and removed by exact name through
 * `OcuPilot.Test.ServiceLdapProbe`, armed by `OCUPILOT_ALLOW_SERVICE_CONFIG`.
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
const PROBE_CLASS = 'OcuPilot.Test.ServiceLdapProbe';
const SERVICE = '%Service_CallIn';
const SERVING = '%Service_WebGateway';
const LDAP = 'ocup99browser.invalid';
const SERVICES_URL = '/ocupilot/permissions/services?ns=HSCUSTOM';
const LDAP_URL = '/ocupilot/security/ldap?ns=HSCUSTOM';
const SERVICE_EDIT_URL = `/ocupilot/permissions/services/edit/%2525Service_CallIn?ns=HSCUSTOM`;
const SERVING_EDIT_URL = `/ocupilot/permissions/services/edit/%2525Service_WebGateway?ns=HSCUSTOM`;
/** The configuration's id as the shell writes it in a route: encoded twice, a dot included (AD-13). */
const LDAP_SEGMENT = 'ocup99browser%252Einvalid';
const LDAP_EDIT_URL = `/ocupilot/security/ldap/edit/${LDAP_SEGMENT}?ns=HSCUSTOM`;

let browser = null;
let snapshot = '';

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

/** The vendor's read of service or configuration `name`, as JSON text, or null. */
function readBack(name, endpoint = 'Security.Service') {
  const { values } = irisSession(
    [`Set tSC=##class(${PROBE_CLASS}).Read("${name}",.tRead,"${endpoint}")`, mark('READ', '$Select($IsObject($Get(tRead)):tRead.%ToJSON(),1:"")')],
    ['READ']
  );
  return values.READ === null || values.READ === '' ? null : JSON.parse(values.READ);
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec writes a service and an LDAP configuration, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  const { values, output } = irisSession(
    [
      `Set tSC=##class(${PROBE_CLASS}).Snapshot(.tSnapshot)`,
      `If $System.Status.IsOK(tSC) Set tSC=##class(${PROBE_CLASS}).RemoveAll()`,
      `If $System.Status.IsOK(tSC) Set tSC=##class(${PROBE_CLASS}).CreateLdap("${LDAP}")`,
      mark('SNAP', '$Get(tSnapshot)'),
      mark('MADE', '$System.Status.IsOK(tSC)'),
    ],
    ['SNAP', 'MADE']
  );
  assert.equal(values.MADE, '1', `the service snapshot and the LDAP probe were made (is OCUPILOT_ALLOW_SERVICE_CONFIG set?):\n${output}`);
  snapshot = values.SNAP ?? '';
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  const { values, output } = irisSession(
    [
      `Set tSC=##class(${PROBE_CLASS}).Restore(${JSON.stringify(snapshot).replaceAll('\\"', '""')})`,
      `If $System.Status.IsOK(tSC) Set tSC=##class(${PROBE_CLASS}).RemoveAll()`,
      mark('CLEAN', '$System.Status.IsOK(tSC)'),
    ],
    ['CLEAN']
  );
  assert.equal(values.CLEAN, '1', `the service is restored and the LDAP probe removed:\n${output}`);
});

/** A fresh context signed in through the shell's own form, landed at `url`, with its writes to the two Save routes counted. */
async function signedInAt(url) {
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  const writes = [];
  page.on('request', (request) => {
    const path = new URL(request.url()).pathname;
    if ((path.startsWith('/api/ocupilot/services') || path.startsWith('/api/ocupilot/ldap')) && request.method() !== 'GET') {
      writes.push({ path, method: request.method(), body: request.postData() ?? '' });
    }
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

/** Wait until the reduced form holds its fresh read. */
async function formReady(page) {
  await page.waitForSelector('app-reduced-form-page .ocu-form-fields', { timeout: config.navigationTimeoutMs });
}

/** Open the row whose name contains `text` from the list the page is on. */
async function openRow(page, text) {
  await waitForRows(page, config.navigationTimeoutMs);
  await page.type(FILTER_SELECTOR, text);
  await page.waitForFunction((selector) => document.querySelectorAll(selector).length === 1, { timeout: config.navigationTimeoutMs }, ROW_SELECTOR);
  await clickRowCentre(page, { index: 0, link: true });
}

/** The form's field labels, in order. */
function labels(page) {
  return page.$$eval('app-reduced-form-page .ocu-form-fields .ocu-field-label, app-reduced-form-page .ocu-form-fields .ocu-field-checkbox > span', (nodes) =>
    nodes.map((node) => node.textContent.trim())
  );
}

/** The card as the content column's last child: its title, caption, and one anchor's text, href, target and rel. */
function card(page) {
  return page.evaluate(() => {
    const column = document.querySelector('app-reduced-form-page .ocu-form-page');
    const last = column?.lastElementChild ?? null;
    const anchor = last?.querySelector('a') ?? null;
    return {
      last: last?.tagName.toLowerCase() ?? null,
      title: last?.querySelector('.ocu-classic-link-card-title')?.textContent.trim() ?? null,
      caption: last?.querySelector('.ocu-classic-link-card-caption')?.textContent.trim() ?? null,
      label: anchor?.querySelector('.ocu-classic-link-card-label')?.textContent.trim() ?? null,
      href: anchor?.getAttribute('href') ?? null,
      target: anchor?.getAttribute('target') ?? null,
      rel: anchor?.getAttribute('rel') ?? null,
    };
  });
}

/** Add one entry to the list field `key`. */
async function addEntry(page, key, value) {
  await page.type(`#ocu-reduced-${key}`, value);
  await page.click(`[data-action="add-${key}"]`);
}

async function saved(page) {
  await page.waitForFunction(
    // Story 16.17: the text, or the text and the instance's read-back line after it.
    (text) => ((shown) => shown === text || shown.startsWith(`${text} \u00b7 `))(document.querySelector('.ocu-form-bar-status [role="status"]')?.textContent.trim() ?? ''),
    { timeout: config.navigationTimeoutMs },
    STRINGS.formSaved
  );
}

// AC1, AC2. Mutation (Rule 19): drop `target` from the classic-link-card's anchor and redeploy ->
// the target assertion goes red.
test('AC1, AC2: a Services row\u2019s name opens the reduced service form, ended by the classic-portal card', async () => {
  const { context, page } = await signedInAt(SERVICES_URL);
  try {
    await openRow(page, 'CallIn');
    await page.waitForFunction(() => window.location.pathname.endsWith('/permissions/services/edit/%2525Service_CallIn'), { timeout: config.navigationTimeoutMs });
    await formReady(page);
    assert.deepEqual(await labels(page), [STRINGS.serviceFieldEnabled, STRINGS.serviceFieldClientSystems, STRINGS.serviceAddressField]);
    assert.equal(await page.$eval('#ocu-reduced-Enabled', (node) => node.checked), false, 'Enabled is read from the instance');
    assert.equal(await page.$('[role="tablist"]'), null, 'and the form has no tabs');
    assert.deepEqual(await card(page), {
      last: 'app-classic-link-card',
      title: STRINGS.classicLinkCardTitle,
      caption: STRINGS.classicLinkCardCaption,
      label: 'Services',
      href: '/csp/sys/sec/%25CSP.UI.Portal.Services.zen',
      target: '_blank',
      rel: 'noreferrer',
    });
  } finally {
    await context.close();
  }
});

// Integration. Mutation (Rule 19): skip the `updated` publish in the store and redeploy -> the list
// re-reads on return regardless, so this stays green; the publish is pinned by
// `reduced-form.store.spec.ts`.
test('Integration: an added address is saved, reaches the instance with every other field kept, and the list shows it', async () => {
  const before = readBack(SERVICE);
  assert.notEqual(before, null, 'the service reads before the Save');
  const { context, page, writes } = await signedInAt(SERVICE_EDIT_URL);
  try {
    await formReady(page);
    await addEntry(page, 'ClientSystems', '10.0.0.1');
    await page.click('.ocu-form-bar-actions .ocu-button-primary');
    await saved(page);
    assert.deepEqual(writes.map((write) => [write.method, write.path, JSON.parse(write.body)]), [['PUT', '/api/ocupilot/services/%2525Service_CallIn', { ClientSystems: ['10.0.0.1'] }]]);
    const after = readBack(SERVICE);
    assert.deepEqual(after.ClientSystems, ['10.0.0.1'], 'the instance holds the address');
    assert.equal(after.AutheEnabled, before.AutheEnabled, 'its methods are kept');
    assert.equal(after.Enabled, before.Enabled, 'and its enablement');
    await page.click('.ocu-form-bar-actions .ocu-button-text');
    await page.waitForFunction(() => window.location.pathname.endsWith('/permissions/services'), { timeout: config.navigationTimeoutMs });
    await waitForRows(page, config.navigationTimeoutMs);
    await page.type(FILTER_SELECTOR, 'CallIn');
    await page.waitForFunction((selector) => {
      const rows = document.querySelectorAll(selector);
      return rows.length === 1 && rows[0].textContent.includes('10.0.0.1');
    }, { timeout: config.navigationTimeoutMs }, ROW_SELECTOR);
  } finally {
    await context.close();
  }
});

test('AC1, Integration: an LDAP / Kerberos row opens the reduced LDAP form, whose description Save reaches the instance and the list', async () => {
  const { context, page } = await signedInAt(LDAP_URL);
  try {
    await openRow(page, 'ocup99browser');
    await page.waitForFunction((segment) => window.location.pathname.endsWith(`/security/ldap/edit/${segment}`), { timeout: config.navigationTimeoutMs }, LDAP_SEGMENT);
    await formReady(page);
    assert.deepEqual(await labels(page), [
      STRINGS.tableColumnDescription,
      STRINGS.ldapFieldEnabled,
      STRINGS.ldapFieldHostNames,
      STRINGS.ldapHostField,
      STRINGS.ldapFieldSearchUsername,
      STRINGS.ldapFieldBaseDn,
      STRINGS.ldapFieldUniqueAttribute,
    ]);
    assert.equal(await page.$eval('#ocu-reduced-LDAPBaseDN', (node) => node.value), 'DC=ocup99,DC=invalid', 'the base DN is read from the instance');
    assert.equal((await card(page)).label, 'Security LDAP Configs', 'and the card names the classic page');
    await page.click('#ocu-reduced-Description', { clickCount: 3 });
    await page.keyboard.press('Backspace');
    await page.type('#ocu-reduced-Description', 'browser save');
    await page.click('.ocu-form-bar-actions .ocu-button-primary');
    await saved(page);
    const after = readBack(LDAP, 'Security.LDAP');
    assert.equal(after.Description, 'browser save', 'the instance holds the description');
    assert.deepEqual(after.LDAPHostNames, ['ocup99.invalid'], 'and keeps the host names');
    await page.click('.ocu-form-bar-actions .ocu-button-text');
    await waitForRows(page, config.navigationTimeoutMs);
    // The list keeps the filter it was left with (AD-19), so the row is read under it.
    await page.waitForFunction((selector) => {
      const rows = document.querySelectorAll(selector);
      return rows.length === 1 && rows[0].textContent.includes('browser save');
    }, { timeout: config.navigationTimeoutMs }, ROW_SELECTOR);
  } finally {
    await context.close();
  }
});

// AC5. The serving service is only read here: nothing is saved.
test('AC5: on the service OcuPilot is served through, Enabled is unavailable with the published sentence, and an address change shows the consequence', async () => {
  const { context, page, writes } = await signedInAt(SERVING_EDIT_URL);
  try {
    await formReady(page);
    assert.equal(await page.$eval('#ocu-reduced-Enabled', (node) => node.getAttribute('aria-disabled')), 'true', 'Enabled is aria-disabled');
    assert.equal(await page.$eval('#ocu-reduced-Enabled-refusal', (node) => node.textContent.trim()), STRINGS.serviceRefusalServing, 'with the published sentence');
    await page.click('#ocu-reduced-Enabled');
    assert.equal(await page.$eval('#ocu-reduced-Enabled', (node) => node.checked), true, 'a click leaves it on');
    assert.equal(await page.$('#ocu-reduced-ClientSystems-effect'), null, 'no consequence before a change');
    await addEntry(page, 'ClientSystems', '10.0.0.1');
    await page.waitForSelector('#ocu-reduced-ClientSystems-effect', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('#ocu-reduced-ClientSystems-effect', (node) => node.textContent.trim()), STRINGS.serviceEffectServesOcuPilot, 'the address change carries the consequence');
    assert.deepEqual(writes, [], 'and nothing was sent');
  } finally {
    await context.close();
  }
});

test('the visual gate at 1440x900 on both forms: every control named and at least 24x24, nothing overflows, the bar inside the content area', async () => {
  for (const url of [SERVICE_EDIT_URL, LDAP_EDIT_URL]) {
    const { context, page } = await signedInAt(url);
    try {
      await page.setViewport({ width: 1440, height: 900 });
      await formReady(page);
      const report = await page.evaluate(() => {
        const nameOf = (node) => {
          const labelled = node.getAttribute('aria-labelledby');
          if (labelled) return labelled.split(' ').map((id) => document.getElementById(id)?.textContent.trim() ?? '').join(' ').trim();
          if (node.getAttribute('aria-label')) return node.getAttribute('aria-label').trim();
          if (node.labels && node.labels.length > 0) return Array.from(node.labels).map((item) => item.textContent.trim()).join(' ');
          return node.textContent.trim();
        };
        const root = document.querySelector('app-reduced-form-page');
        const controls = Array.from(root.querySelectorAll('input, select, textarea, button, a')).filter((node) => node.offsetParent !== null);
        const unnamed = controls.filter((node) => nameOf(node) === '').map((node) => node.outerHTML.slice(0, 120));
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
      assert.ok(report.controls > 3, `${url}: the gate looked at the form's controls: ${report.controls}`);
      assert.deepEqual(report.unnamed, [], `${url}: every control has an accessible name`);
      assert.deepEqual(report.small, [], `${url}: none is smaller than 24x24 or narrower than its declared minimum`);
      assert.deepEqual(report.overflowing, [], `${url}: nothing overflows its container`);
      assert.equal(report.pageOverflow, false, `${url}: and the page does not scroll sideways`);
      assert.ok(report.barBottom !== null && report.barBottom <= report.contentBottom + 1, `${url}: the bar sits inside the content area: ${JSON.stringify(report)}`);
    } finally {
      await context.close();
    }
  }
});

/**
 * The web application editor in a real browser, against the throwaway instance (Story 9.2).
 *
 * What it pins, each on rendered DOM, on the real URL or on the instance itself:
 *
 * 1. **A row's name opens the editor** at `web-applications/list/edit/<id>`, on its four tabs.
 * 2. **A two-field Save reaches the instance**, and the change toast's "Open in Web applications"
 *    lands on the list, whose row shows the new resource without a reload (AC2).
 * 3. **Each weakening change states its own line at its own field**, the repointed line once, and
 *    the Save applies all three on an application that is not OcuPilot's own (AD-10).
 * 4. **A refusal on General while another tab is open** opens General with its dot and count, and a
 *    changed form asks before it is left.
 * 5. **A privileged application role on an unauthenticated application** states one combined line,
 *    and the role reaches the instance through the list's own action route.
 * 6. **OcuPilot's own API application is drawn refused.**
 * 7. **The visual gate** (DW-1337) on every tab, and **the form bar flush** at the bottom of the
 *    content area at 1440x900 with nothing scrolled (DW-1596).
 *
 * **It creates and deletes two web applications**, so it refuses the live container. Each test
 * that changes them creates them afresh by exact name, and `after` removes them whether or not a
 * test failed.
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
import { FILTER_SELECTOR, ROW_SELECTOR, waitForRows } from './list-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));
const { encodeEntityId } = await import(join(uiRoot, 'src', 'app', 'core', 'entity-id.ts'));

const config = browserConfig();
const LIST_URL = '/ocupilot/web-applications/list?ns=HSCUSTOM';

/** This spec's own applications, never ones the instance had: one password-authenticated, one not. */
const PROBE = '/csp/ocupilotprobebrowsereditor';
const PROBE_OPEN = '/csp/ocupilotprobebrowsereditoropen';
const PROBE_MARKER = 'OcuPilot web application editor browser spec probe (throwaway)';

const editUrl = (name) => `/ocupilot/web-applications/list/edit/${encodeEntityId(name)}?ns=HSCUSTOM`;

let browser = null;

const mark = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/** Run ObjectScript in `%SYS` inside the throwaway and read back the named markers. */
function irisSys(lines, names = []) {
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', '%SYS'], {
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

/** Remove `name` by its exact name, and only where it carries this spec's marker. */
const remove = (name) =>
  `If ##class(Security.Applications).Exists("${name}") { Kill tP Do ##class(Security.Applications).Get("${name}",.tP) If $Extract($Get(tP("Description")),1,${PROBE_MARKER.length})="${PROBE_MARKER}" Do ##class(Security.Applications).Delete("${name}") }`;

/** Create both probes afresh: password authentication and a resource, and unauthenticated. */
function createProbes() {
  return irisSys(
    [
      remove(PROBE),
      remove(PROBE_OPEN),
      `Kill tP Set tP("NameSpace")="HSCUSTOM",tP("AutheEnabled")=32,tP("Resource")="%Development",tP("Description")="${PROBE_MARKER}",tP("Enabled")=1`,
      `Set tSC=##class(Security.Applications).Create("${PROBE}",.tP)`,
      `Kill tP Set tP("NameSpace")="HSCUSTOM",tP("AutheEnabled")=64,tP("Description")="${PROBE_MARKER}",tP("Enabled")=1`,
      `If $System.Status.IsOK(tSC) Set tSC=##class(Security.Applications).Create("${PROBE_OPEN}",.tP)`,
      mark('MADE', '$System.Status.IsOK(tSC)'),
    ],
    ['MADE']
  );
}

/** One property of application `name` as the instance holds it; `gone` when it is not there. */
function probeField(name, field) {
  const { values } = irisSys(
    [
      `Kill tP Set tThere=##class(Security.Applications).Exists("${name}") If tThere Do ##class(Security.Applications).Get("${name}",.tP)`,
      mark('FIELD', `$Select(tThere: $Get(tP("${field}")), 1: "gone")`),
    ],
    ['FIELD']
  );
  return values.FIELD;
}

function freshProbes() {
  const { values, output } = createProbes();
  assert.equal(values.MADE, '1', `the probe applications were created:\n${output}`);
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates and deletes web applications, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  freshProbes();
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  const { values, output } = irisSys(
    [remove(PROBE), remove(PROBE_OPEN), mark('CLEAN', `('##class(Security.Applications).Exists("${PROBE}"))&&('##class(Security.Applications).Exists("${PROBE_OPEN}"))`)],
    ['CLEAN']
  );
  assert.equal(values.CLEAN, '1', `the probe applications are gone:\n${output}`);
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

/** Wait until the editor holds application `name`'s read. */
async function editorReady(page, name) {
  await page.waitForFunction(
    (wanted) => document.querySelector('#ocu-web-app-edit-Name')?.value === wanted && document.querySelector('#ocu-web-app-edit-NameSpace') !== null,
    { timeout: config.navigationTimeoutMs },
    name
  );
}

/** Replace control `id`'s text with `value`. */
async function fill(page, id, value) {
  await page.click(`#${id}`, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  if (value !== '') await page.type(`#${id}`, value);
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

async function saved(page) {
  await page.click('.ocu-form-bar .ocu-button-primary');
  await page.waitForFunction(
    (sentence) => document.querySelector('.ocu-form-bar-status')?.textContent?.includes(sentence) === true,
    { timeout: config.navigationTimeoutMs },
    STRINGS.formSaved
  );
}

/** Every consequence line on screen, in document order. */
function effects(page) {
  return page.$$eval('app-web-app-editor-page [id$="-effect"]', (nodes) => nodes.map((node) => node.textContent.trim()));
}

const TAB_LABELS = [STRINGS.processDetailsGroupGeneral, STRINGS.webAppFormApplicationRoles, STRINGS.webAppTabMatchingRoles, STRINGS.webAppTabCors];

test('a row\u2019s name opens the editor on its four tabs', async () => {
  // Mutation (Rule 19): put WebAppForm back in `CREATE_ONLY_FORMS` and redeploy -> the name cell
  // opens no editor and the URL wait goes red.
  const { context, page } = await signedInAt(LIST_URL);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await page.type(FILTER_SELECTOR, 'ocupilotprobebrowsereditor');
    await page.waitForFunction(
      (selector, name) => Array.from(document.querySelectorAll(selector)).some((row) => row.textContent.includes(name)),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      PROBE
    );
    await page.evaluate((name) => {
      const links = Array.from(document.querySelectorAll('[role="grid"] .ocu-data-table-body .ocu-data-table-link'));
      links.find((link) => link.textContent.trim() === name).click();
    }, PROBE);
    await page.waitForFunction(
      (segment) => new URL(window.location.href).pathname.endsWith(`/web-applications/list/edit/${segment}`),
      { timeout: config.navigationTimeoutMs },
      encodeEntityId(PROBE)
    );
    await editorReady(page, PROBE);
    const tabs = await tabState(page);
    assert.deepEqual(tabs.map((tab) => tab.label), TAB_LABELS);
    assert.equal(tabs[0].selected, true, 'General is open first');
  } finally {
    await context.close();
  }
});

test('AC2: a two-field Save reaches the instance, and the toast opens the list showing the new resource', async () => {
  freshProbes();
  const { context, page } = await signedInAt(editUrl(PROBE));
  try {
    await editorReady(page, PROBE);
    await fill(page, 'ocu-web-app-edit-Description', `${PROBE_MARKER} saved`);
    await fill(page, 'ocu-web-app-edit-Resource', '%Admin_Operate');
    await saved(page);
    assert.equal(probeField(PROBE, 'Description'), `${PROBE_MARKER} saved`, 'the description reached the instance');
    assert.equal(probeField(PROBE, 'Resource'), '%Admin_Operate', 'and so did the resource');
    assert.equal(probeField(PROBE, 'AutheEnabled'), '32', 'and the authentication survived');
    assert.equal(probeField(PROBE, 'NameSpace'), 'HSCUSTOM', 'as did the namespace');

    const link = STRINGS.tableChangeToastLink.replace('<screen>', STRINGS.webAppListLabel);
    await page.waitForFunction(
      (text) => Array.from(document.querySelectorAll('.ocu-toast-action')).some((node) => node.textContent.trim() === text),
      { timeout: config.navigationTimeoutMs },
      link
    );
    await page.evaluate((text) => {
      Array.from(document.querySelectorAll('.ocu-toast-action')).find((node) => node.textContent.trim() === text).click();
    }, link);
    await page.waitForFunction(() => new URL(window.location.href).pathname.includes('/web-applications/list/'), { timeout: config.navigationTimeoutMs });
    await page.waitForFunction(
      (selector, name) =>
        Array.from(document.querySelectorAll(selector)).some((row) => row.textContent.includes(name) && row.textContent.includes('%Admin_Operate')),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      PROBE
    );
  } finally {
    await context.close();
  }
});

test('each weakening change states its own line at its own field, and the Save applies all three', async () => {
  // Mutation (Rule 19): restore the three refusal arms for every application in
  // `Prohibited.WebApplication` and recompile -> the Save is refused and the read-back goes red.
  freshProbes();
  const { context, page } = await signedInAt(editUrl(PROBE));
  try {
    await editorReady(page, PROBE);
    await page.click('#ocu-web-app-edit-AutheEnabled-64');
    await fill(page, 'ocu-web-app-edit-Resource', '');
    await fill(page, 'ocu-web-app-edit-DispatchClass', 'OcuPilot.Api.Router');
    await fill(page, 'ocu-web-app-edit-Package', 'OcuPilotProbe');
    assert.deepEqual(await effects(page), [STRINGS.webAppRepointedEffect, STRINGS.webAppNoResourceEffect, STRINGS.webAppUnauthenticatedEffect]);
    assert.equal(await page.$eval('#ocu-web-app-edit-DispatchClass-effect', (node) => node.textContent.trim()), STRINGS.webAppRepointedEffect);
    assert.equal(await page.$('#ocu-web-app-edit-Package-effect'), null, 'the repointed line is stated once');
    await saved(page);
    assert.equal((Number(probeField(PROBE, 'AutheEnabled')) & 64) !== 0, true, 'the application is reachable without signing in');
    assert.equal(probeField(PROBE, 'Resource'), '', 'guarded by no resource');
    assert.equal(probeField(PROBE, 'DispatchClass'), 'OcuPilot.Api.Router', 'and answered by the new class');
  } finally {
    await context.close();
  }
});

test('a refusal on General while another tab is open opens General with its dot and count, and a changed form asks before it is left', async () => {
  // Mutation (Rule 19): skip `tabToOpen` in the page's `afterRefusal` and redeploy -> the
  // selected-tab assertion goes red.
  freshProbes();
  const { context, page } = await signedInAt(editUrl(PROBE));
  try {
    await editorReady(page, PROBE);
    await fill(page, 'ocu-web-app-edit-Timeout', '-1');
    await openTab(page, STRINGS.webAppTabCors);
    await page.click('.ocu-form-bar .ocu-button-primary');
    await page.waitForSelector('.ocu-form-summary', { visible: true, timeout: config.navigationTimeoutMs });
    await page.waitForFunction(() => document.activeElement?.id === 'ocu-web-app-edit-Timeout', { timeout: config.navigationTimeoutMs });
    const tabs = await tabState(page);
    assert.equal(tabs[0].selected, true, 'General opened');
    assert.equal(tabs[0].dot, true, 'with the destructive dot');
    assert.equal(tabs[0].name, `${STRINGS.processDetailsGroupGeneral}, 1 error`, 'and its count in its accessible name');
    assert.equal(tabs[3].dot, false, 'Cross-origin settings carries none');
    assert.equal(probeField(PROBE, 'Timeout'), '900', 'and nothing reached the instance');

    await page.click('.ocu-form-bar-actions .ocu-button-text');
    await page.waitForSelector('[role="dialog"] .ocu-dialog-title', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[role="dialog"] .ocu-dialog-title', (node) => node.textContent.trim()), STRINGS.formLeaveWithoutSaving);
    await (await page.$('[role="dialog"] .ocu-dialog-actions button')).click();
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    assert.ok(new URL(page.url()).pathname.endsWith(`/web-applications/list/edit/${encodeEntityId(PROBE)}`), 'the editor is still open');
    assert.equal(await page.$eval('#ocu-web-app-edit-Timeout', (node) => node.value), '-1', 'with the edit');
  } finally {
    await context.close();
  }
});

test('Integration: %All on an unauthenticated application states one combined line, and the role reaches the instance', async () => {
  // Mutation (Rule 19): render `privilegedGrantEffect` whatever the authentication state and
  // redeploy -> the combined-line assertion goes red.
  freshProbes();
  const { context, page } = await signedInAt(editUrl(PROBE_OPEN));
  try {
    await editorReady(page, PROBE_OPEN);
    await openTab(page, STRINGS.webAppFormApplicationRoles);
    await page.select('#ocu-web-app-edit-application-role', '%All');
    assert.deepEqual(await effects(page), [STRINGS.privilegedGrantEffectUnauthenticated], 'one line, the combined one');
    await page.click('[data-action="add-application-role"]');
    await page.waitForFunction(
      () => Array.from(document.querySelectorAll('.ocu-form-role-name')).some((node) => node.textContent.trim() === '%All'),
      { timeout: config.navigationTimeoutMs }
    );
    assert.ok(probeField(PROBE_OPEN, 'MatchRoles').includes('%All'), `the instance holds the application role: ${probeField(PROBE_OPEN, 'MatchRoles')}`);
  } finally {
    await context.close();
  }
});

test('OcuPilot\u2019s own API application is drawn refused: its fields, its Save and its role controls', async () => {
  const { context, page } = await signedInAt(editUrl('/api/ocupilot'));
  try {
    await editorReady(page, '/api/ocupilot');
    assert.equal(await page.$eval('#ocu-web-app-edit-serves-refusal', (node) => node.textContent.trim()), STRINGS.webAppServesOcuPilotRefusal);
    assert.equal(await page.$eval('#ocu-web-app-edit-Description', (node) => node.readOnly), true, 'the fields take no input');
    assert.equal(await page.$eval('.ocu-form-bar .ocu-button-primary', (node) => node.getAttribute('aria-disabled')), 'true', 'and Save is drawn refused');
    await openTab(page, STRINGS.webAppFormApplicationRoles);
    assert.equal(await page.$eval('#ocu-web-app-edit-roles-refusal', (node) => node.textContent.trim()), STRINGS.webAppPrivilegeGrantRefusal);
    assert.equal(await page.$eval('[data-action="add-application-role"]', (node) => node.getAttribute('aria-disabled')), 'true');
  } finally {
    await context.close();
  }
});

test('the visual gate on every tab, and the form bar flush at the bottom of the content area with nothing scrolled', async () => {
  // Mutation (Rule 19): drop the form-page host rule from `_components.scss` and redeploy -> the
  // flush assertion goes red.
  freshProbes();
  const { context, page } = await signedInAt(editUrl(PROBE));
  try {
    await editorReady(page, PROBE);
    const geometry = await page.evaluate(() => {
      const bar = document.querySelector('.ocu-form-bar').getBoundingClientRect();
      const content = document.querySelector('.ocu-content');
      const form = document.querySelector('.ocu-form-page');
      return {
        barBottom: bar.bottom,
        contentBottom: content.getBoundingClientRect().bottom,
        contentScrolled: content.scrollTop,
        formScrolls: form.scrollHeight > form.clientHeight,
      };
    });
    assert.equal(geometry.contentScrolled, 0, `nothing was scrolled: ${JSON.stringify(geometry)}`);
    assert.ok(Math.abs(geometry.barBottom - geometry.contentBottom) <= 1, `the bar is flush at the bottom of the content area: ${JSON.stringify(geometry)}`);
    assert.equal(geometry.formScrolls, true, `and the form page scrolls inside itself: ${JSON.stringify(geometry)}`);

    for (const label of TAB_LABELS) {
      await openTab(page, label);
      const report = await page.evaluate(() => {
        const nameOf = (node) => {
          const labelled = node.getAttribute('aria-labelledby');
          if (labelled) return labelled.split(' ').map((id) => document.getElementById(id)?.textContent.trim() ?? '').join(' ').trim();
          if (node.getAttribute('aria-label')) return node.getAttribute('aria-label').trim();
          if (node.labels && node.labels.length > 0) return Array.from(node.labels).map((one) => one.textContent.trim()).join(' ');
          return node.textContent.trim();
        };
        const root = document.querySelector('app-web-app-editor-page');
        const controls = Array.from(root.querySelectorAll('input, select, textarea, button, [role="tab"]')).filter((node) => node.offsetParent !== null);
        const unnamed = controls.filter((node) => nameOf(node) === '').map((node) => node.outerHTML.slice(0, 120));
        const narrow = controls
          .filter((node) => {
            const min = parseFloat(getComputedStyle(node).minWidth);
            return Number.isFinite(min) && node.getBoundingClientRect().width + 0.5 < min;
          })
          .map((node) => node.outerHTML.slice(0, 120));
        const overflowing = Array.from(root.querySelectorAll('*'))
          .filter((node) => node.offsetParent !== null && node.parentElement !== null)
          .filter((node) => {
            const own = node.getBoundingClientRect();
            const parent = node.parentElement.getBoundingClientRect();
            const style = getComputedStyle(node.parentElement);
            if (style.overflowX !== 'visible') return false;
            return own.width > 0 && own.right > parent.right + 1;
          })
          .map((node) => node.outerHTML.slice(0, 120));
        return {
          controls: controls.length,
          unnamed,
          narrow,
          overflowing,
          pageOverflow: document.documentElement.scrollWidth > document.documentElement.clientWidth,
        };
      });
      assert.ok(report.controls > 3, `${label}: the gate looked at the editor's controls: ${report.controls}`);
      assert.deepEqual(report.unnamed, [], `${label}: every control has an accessible name`);
      assert.deepEqual(report.narrow, [], `${label}: none is narrower than its declared minimum`);
      assert.deepEqual(report.overflowing, [], `${label}: nothing overflows its container`);
      assert.equal(report.pageOverflow, false, `${label}: and the page does not scroll sideways`);
    }
  } finally {
    await context.close();
  }
});

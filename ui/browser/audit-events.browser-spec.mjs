/**
 * Story 7.11 end to end in a real browser against the throwaway instance: the System events and
 * User events lists' row actions, the warning before OcuPilot's own marker event is disabled and the
 * panel banner that follows it, the typed-name delete of a probe user event this spec creates, and
 * the Selective SQL auditing dialog on the Auditing configuration page.
 *
 * **It changes audit event configuration.** It refuses to run anywhere but a `-ci` throwaway; its
 * `before` asserts auditing is on and creates the probe event, and its `after` puts the marker event,
 * the SQL event it toggles and auditing back, and removes the probe, whatever happened above.
 *
 * **The banner is read through a consumer** (the Integration AC): the screen caller records the
 * observed marking fact after the marker disable, `GET /agent/restraint` answers it, and what is
 * asserted is the panel strip -- never a mock.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test
 * browser/audit-events.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { escapeOs, markerValue, requireFreeSlot, runIris as sharedRunIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();

const SYSTEM_URL = '/ocupilot/security/auditing/system-events?ns=HSCUSTOM';
const USER_URL = '/ocupilot/security/auditing/user-events?ns=HSCUSTOM';
const AUDITING_URL = '/ocupilot/security/auditing?ns=HSCUSTOM';
const SYSTEM_ACTION = '/api/ocupilot/screens/security.auditsystemevents/action';
const USER_ACTION = '/api/ocupilot/screens/security.audituserevents/action';
const HELPER = 'OcuPilot.Test.AuditingUpdate';

/** The granular SQL event the system and wizard legs toggle, and the one both put back. */
const SQL_EVENT = ['%System', '%SQL', 'XDBCStatementUtility'];
const SQL_ID = SQL_EVENT.join('/');

/** OcuPilot's own marker event, and the probe user event this spec creates and deletes. */
const MARKER = ['OcuPilot', 'Security', 'AgentWrite'];
const MARKER_ID = MARKER.join('/');
const PROBE_ID = 'OcuPilotProbe/Story711/ProbeEvent';

const NAME_TEXT = '.ocu-data-table-link, .ocu-data-table-text';

let browser = null;
let sqlInitial = '';

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec changes audit events, so it never runs inside the live container');
  assert.match(config.container, /-ci$/, `this spec changes audit events, so it runs only in a throwaway; ${config.container} is not one`);
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  assert.equal(iris(`##class(${HELPER}).AuditEnabled()`), '1', 'the instance starts audited');
  assert.equal(eventFlag(MARKER), '1', 'and its marker event starts enabled');
  sqlInitial = eventFlag(SQL_EVENT);
  assert.match(sqlInitial, /^[01]$/, `the SQL event reads (${sqlInitial})`);
  assert.equal(iris(`$System.Status.IsOK(##class(${HELPER}).ProbeCreate())`), '1', 'the probe user event is created');
  await requireFreeSlot(config);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (!/-ci$/.test(config.container)) return;
  // Unconditional: each of these is instance configuration a failed leg could leave moved.
  runIris([`Do ##class(${HELPER}).RestoreMarker()`, `Do ##class(${HELPER}).ProbeDelete()`, `Do ##class(${HELPER}).RestoreAuditing()`]);
  if (/^[01]$/.test(sqlInitial)) setEventFlag(SQL_EVENT, sqlInitial);
  assert.equal(eventFlag(MARKER), '1', 'the marker event is left enabled');
  assert.equal(iris(`##class(${HELPER}).AuditEnabled()`), '1', 'auditing is left on');
  assert.equal(iris(`##class(${HELPER}).ProbeExists()`), '0', 'the probe user event is gone');
  if (/^[01]$/.test(sqlInitial)) assert.equal(eventFlag(SQL_EVENT), sqlInitial, 'and the SQL event is as it was');
});

function runIris(lines) {
  return sharedRunIris(config.container, lines);
}

/** One ObjectScript expression's value, read off the instance. */
function iris(expression) {
  return markerValue(runIris([`Write "OCU-AEV-START:"_(${expression})_":OCU-AEV-END",!`]), 'AEV') ?? '';
}

/** `1` or `0` for an event's `Enabled`, or `-1`. */
function eventFlag([source, type, name]) {
  return iris(`##class(${HELPER}).EventFlag("${escapeOs(source)}","${escapeOs(type)}","${escapeOs(name)}",1)`);
}

function setEventFlag([source, type, name], value) {
  runIris([
    'Set tNs=$NAMESPACE,$NAMESPACE="%SYS"',
    `Kill p Set p("Enabled")=${Number(value)} Do ##class(Security.Events).Modify("${escapeOs(source)}","${escapeOs(type)}","${escapeOs(name)}",.p)`,
    'Set $NAMESPACE=tNs',
  ]);
}

/** An event's `Total`, as the vendor's own list answers it. */
function eventTotal(id) {
  const output = runIris([
    `Kill q Set q("names")="${escapeOs(id)}" Set sc=##class(OcuPilot.Port.AdminPort).Invoke("Security.Audit.Event","LIST",.q,"",.r,.h,.f)`,
    'Write "OCU-AEVT-START:"_$Select($System.Status.IsOK(sc)&&$IsObject(r)&&(r.%Size()=1):r.%Get(0).%Get("Total"),1:-1)_":OCU-AEVT-END",!',
  ]);
  return markerValue(output, 'AEVT') ?? '';
}

/**
 * A signed-in page at `url`, recording every POST to `actionPath` and the HTTP status each answered,
 * so a refused action cannot pass for a sent one.
 */
async function signedInAtList(url, actionPath) {
  const { context, page } = await signedInAt(browser, config, url);
  const { posts, statuses } = recordActions(page, actionPath);
  await waitForRows(page, config.navigationTimeoutMs);
  return { context, page, posts, statuses };
}

function recordActions(page, actionPath) {
  const posts = [];
  const statuses = [];
  page.on('request', (request) => {
    if (request.method() === 'POST' && new URL(request.url()).pathname === actionPath) posts.push(JSON.parse(request.postData() ?? '{}'));
  });
  page.on('response', (response) => {
    if (response.request().method() === 'POST' && new URL(response.url()).pathname === actionPath) statuses.push(response.status());
  });
  return { posts, statuses };
}

/** Filter the list to `text`, and select the row named `name`. */
async function select(page, text, name) {
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, text);
  await page.waitForFunction(
    (selector, wanted, textSelector) =>
      Array.from(document.querySelectorAll(selector)).some((row) => {
        const cell = row.querySelector('[role="gridcell"]');
        return ((cell?.querySelector(textSelector) ?? cell)?.textContent ?? '').trim() === wanted;
      }),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name,
    NAME_TEXT
  );
  await clickRowCentre(page, { text: name });
  await page.waitForFunction(
    (selector) => Array.from(document.querySelectorAll(selector)).some((row) => row.getAttribute('aria-selected') === 'true'),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR
  );
}

/** The command bar's action labels, Refresh aside. */
function commandBar(page) {
  return page.$$eval('.ocu-command-bar-action', (buttons) =>
    buttons.filter((button) => !button.classList.contains('ocu-command-bar-refresh-action')).map((button) => button.textContent.trim())
  );
}

async function pressBar(page, label) {
  await page.evaluate((wanted) => {
    Array.from(document.querySelectorAll('.ocu-command-bar-action'))
      .find((button) => button.textContent.trim() === wanted)
      .click();
  }, label);
}

async function waitFor(predicate, message) {
  const deadline = Date.now() + config.navigationTimeoutMs;
  while (Date.now() < deadline) {
    if (predicate()) return;
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  assert.fail(message);
}

function noDialog(page) {
  return page.evaluate(() => document.querySelector('[role="dialog"]') === null);
}

function bannerShowing(page) {
  return page.evaluate(
    (sentence) =>
      Array.from(document.querySelectorAll('[data-slot="not-marked"] .ocu-banner-message')).some((node) => (node.textContent ?? '').trim() === sentence),
    STRINGS.auditingOffBanner
  );
}

test('AC1: a system event is enabled, disabled and reset at once, with no dialog, and offers no delete', async () => {
  const { context, page, posts, statuses } = await signedInAtList(SYSTEM_URL, SYSTEM_ACTION);
  try {
    await select(page, 'XDBCStatementUtility', SQL_ID);
    const bar = await commandBar(page);
    for (const label of [STRINGS.agentDefinitionEnable, STRINGS.agentDefinitionDisable, STRINGS.actionResetCounters]) {
      assert.ok(bar.includes(label), `the command bar offers ${label}: ${bar.join(', ')}`);
    }
    assert.ok(!bar.includes(STRINGS.actionDelete), 'and no Delete on a system event');

    const first = sqlInitial === '1' ? 'disable' : 'enable';
    const second = first === 'enable' ? 'disable' : 'enable';
    for (const [action, label, expected] of [
      [first, first === 'enable' ? STRINGS.agentDefinitionEnable : STRINGS.agentDefinitionDisable, first === 'enable' ? '1' : '0'],
      [second, second === 'enable' ? STRINGS.agentDefinitionEnable : STRINGS.agentDefinitionDisable, sqlInitial],
    ]) {
      await pressBar(page, label);
      await waitFor(() => posts.length > 0 && posts[posts.length - 1].action === action, `${action} was sent`);
      assert.equal(await noDialog(page), true, `${action} opened no dialog`);
      await waitFor(() => eventFlag(SQL_EVENT) === expected, `the SQL event reads ${expected} after ${action}`);
    }

    const before = posts.length;
    await pressBar(page, STRINGS.actionResetCounters);
    await waitFor(() => posts.length === before + 1, 'Reset counters was sent');
    assert.deepEqual(posts[posts.length - 1], { action: 'reset', id: SQL_ID }, 'the reset names the row');
    assert.equal(await noDialog(page), true, 'and opened no dialog');
    await waitFor(() => statuses.length === posts.length, 'every action has answered');
    assert.deepEqual(statuses, posts.map(() => 200), 'and each answered 200');
  } finally {
    await context.close();
  }
});

test('AC5: disabling the marker event warns first, shows the banner, and enabling it clears the banner', async () => {
  const { context, page, posts } = await signedInAtList(USER_URL, USER_ACTION);
  try {
    await select(page, 'AgentWrite', MARKER_ID);
    assert.equal(await bannerShowing(page), false, 'the banner is absent while agent writes are marked');
    await pressBar(page, STRINGS.agentDefinitionDisable);
    await page.waitForSelector('[role="dialog"]', { timeout: config.navigationTimeoutMs });
    const dialog = await page.evaluate(() => {
      const surface = document.querySelector('[role="dialog"]');
      return {
        title: (surface.querySelector('.ocu-dialog-title')?.textContent ?? '').trim(),
        body: (surface.querySelector('.ocu-warning-consequence')?.textContent ?? '').trim(),
        proceed: (surface.querySelector('.ocu-dialog-actions .ocu-button-primary')?.textContent ?? '').trim(),
        destructive: surface.querySelector('.ocu-button-destructive') !== null,
        focused: document.activeElement?.textContent?.trim() ?? '',
      };
    });
    assert.equal(dialog.title, STRINGS.agentDefinitionDisable, 'the warning is titled with the verb');
    assert.equal(dialog.body, STRINGS.proposalAuditWarning, 'and states that agent writes stop being marked');
    assert.equal(dialog.proceed, STRINGS.actionProceed, 'Proceed is the button-primary');
    assert.equal(dialog.destructive, false, 'never a destructive one');
    assert.equal(dialog.focused, STRINGS.actionCancel, 'Cancel takes initial focus');
    assert.equal(posts.length, 0, 'nothing is sent before Proceed');

    await page.click('[role="dialog"] .ocu-dialog-actions .ocu-button-primary');
    await page.waitForFunction(
      (sentence) =>
        Array.from(document.querySelectorAll('[data-slot="not-marked"] .ocu-banner-message')).some((node) => (node.textContent ?? '').trim() === sentence),
      { timeout: config.navigationTimeoutMs },
      STRINGS.auditingOffBanner
    );
    assert.deepEqual(posts, [{ action: 'disable', id: MARKER_ID }], 'Proceed sent the one disable');
    assert.equal(eventFlag(MARKER), '0', 'the marker event is disabled');

    await pressBar(page, STRINGS.agentDefinitionEnable);
    await page.waitForFunction(
      (sentence) =>
        !Array.from(document.querySelectorAll('[data-slot="not-marked"] .ocu-banner-message')).some((node) => (node.textContent ?? '').trim() === sentence),
      { timeout: config.navigationTimeoutMs },
      STRINGS.auditingOffBanner
    );
    assert.deepEqual(posts[1], { action: 'enable', id: MARKER_ID }, 'the enable was sent at once');
    assert.equal(eventFlag(MARKER), '1', 'and the marker event is enabled again');

    // AC5's delete half: the typed-name dialog carries the advisory on the marker row. Cancelled.
    await pressBar(page, STRINGS.actionDelete);
    await page.waitForSelector('[role="dialog"] .ocu-typed-name-field', { timeout: config.navigationTimeoutMs });
    const advisory = await page.$eval('[role="dialog"]', (surface) => (surface.querySelector('[data-slot="advisory"] .ocu-banner-message')?.textContent ?? '').trim());
    assert.equal(advisory, STRINGS.proposalAuditWarning, 'the marker row\u2019s delete states the advisory');
    await page.click('[role="dialog"] .ocu-dialog-actions .ocu-button-secondary');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    assert.equal(posts.length, 2, 'and Cancel sent nothing');
  } finally {
    await context.close();
  }
});

test('AC3: a probe user event\u2019s counters are reset, and it is deleted through the typed-name dialog, with no advisory', async () => {
  const { context, page, posts, statuses } = await signedInAtList(USER_URL, USER_ACTION);
  try {
    await select(page, 'Story711', PROBE_ID);
    assert.equal(iris('$System.Security.Audit("OcuPilotProbe","Story711","ProbeEvent","Story 7.11 probe","Story 7.11 probe")'), '1', 'a record is emitted for the probe');
    await waitFor(() => Number(eventTotal(PROBE_ID)) > 0, 'so the probe\u2019s Total counts it');
    await pressBar(page, STRINGS.actionResetCounters);
    await waitFor(() => posts.length === 1, 'Reset counters was sent');
    assert.deepEqual(posts[0], { action: 'reset', id: PROBE_ID }, 'the reset names the probe');
    assert.equal(await noDialog(page), true, 'and opened no dialog');
    await waitFor(() => eventTotal(PROBE_ID) === '0', 'and the probe\u2019s Total reads 0');

    await pressBar(page, STRINGS.actionDelete);
    await page.waitForSelector('[role="dialog"] .ocu-typed-name-field', { timeout: config.navigationTimeoutMs });
    const surface = await page.$eval('[role="dialog"]', (node) => ({
      body: (node.querySelector('.ocu-typed-name-consequence')?.textContent ?? '').trim(),
      advisory: node.querySelector('[data-slot="advisory"]') !== null,
      released: node.querySelector('.ocu-button-destructive')?.getAttribute('aria-disabled') !== 'true',
    }));
    assert.equal(surface.body, STRINGS.auditUserEventDeleteConsequence, 'the dialog states the delete\u2019s consequence');
    assert.equal(surface.advisory, false, 'and no advisory on an event that is not the marker');
    assert.equal(surface.released, false, 'the delete is held until the name is typed');
    await page.type('[role="dialog"] .ocu-typed-name-field', PROBE_ID);
    await page.click('[role="dialog"] .ocu-button-destructive');
    await waitFor(() => posts.length === 2, 'the delete was sent');
    assert.deepEqual(posts[1], { action: 'delete', id: PROBE_ID }, 'naming the probe');
    await waitFor(() => statuses.length === 2, 'the delete answered');
    assert.deepEqual(statuses, [200, 200], 'the reset and the delete each with 200');
    await waitFor(() => iris(`##class(${HELPER}).ProbeExists()`) === '0', 'and the probe user event is gone');
  } finally {
    await context.close();
  }
});

test('AC2: Selective SQL auditing sends exactly the one changed box, and the list re-reads it', async () => {
  const { context, page } = await signedInAt(browser, config, AUDITING_URL);
  const { posts, statuses } = recordActions(page, SYSTEM_ACTION);
  try {
    const box = `[role="dialog"] input[aria-label="${STRINGS.auditSqlSourceXdbc} ${STRINGS.auditSqlKindUtility}"]`;
    for (const round of [0, 1]) {
      const was = eventFlag(SQL_EVENT);
      await page.waitForSelector('[data-sql-wizard]', { timeout: config.navigationTimeoutMs });
      await page.click('[data-sql-wizard]');
      await page.waitForSelector(box, { timeout: config.navigationTimeoutMs });
      assert.equal(await page.$eval('[role="dialog"] .ocu-dialog-title', (node) => node.textContent.trim()), STRINGS.auditSqlWizardAction, 'the dialog is Selective SQL auditing');
      assert.equal(await page.$$eval('[role="dialog"] input[type="checkbox"]', (boxes) => boxes.length), 12, 'with the twelve granular SQL events');
      assert.equal(await page.$eval(box, (node) => node.checked), was === '1', 'each box starting as the list reads it');
      await page.click(box);
      await page.click('[role="dialog"] .ocu-dialog-actions .ocu-button-primary');
      await waitFor(() => posts.length === round + 1, `round ${round}: the one changed box was sent`);
      assert.equal(posts[round].action, was === '1' ? 'disable' : 'enable', `round ${round}: through the list\u2019s own action`);
      assert.equal(String(posts[round].id).toLowerCase(), SQL_ID.toLowerCase(), 'naming the XDBC Utility event');
      await waitFor(() => eventFlag(SQL_EVENT) === (was === '1' ? '0' : '1'), `round ${round}: the event moved`);
      await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    }
    assert.equal(posts.length, 2, 'one POST per Apply, and none for the unchanged boxes');
    assert.deepEqual(statuses, [200, 200], 'each answered 200');
    assert.equal(eventFlag(SQL_EVENT), sqlInitial, 'and the second round put the event back');
  } finally {
    await context.close();
  }
});

/**
 * Story 24.16 Batch 1 in a real browser, against the throwaway instance: Interoperability's Purge data settings and Purge management data (AD-5, AD-53,
 * AD-55, AD-56, AD-62).
 *
 * What it pins, in `USER`, whose probe records this spec creates and removes and whose purge setting nodes it puts back: on Purge data settings a person
 * sets Include message bodies from the Set value dialog and the list shows the value and the global holds it; on Purge management data the Purge row action
 * reviews the purge first and opens a dialog that shows the three settings the purge will use, asks for the days and the namespace's name, and refuses to go
 * on until both are right; the one request it sends names the namespace and carries the days as text; the back-dated probe headers, bodies, event log and
 * I/O log rows and the closed managed alert are gone, the record made now stays, and the list's Messages count shows the change.
 *
 * Each test arranges what it needs through the fixture and removes it when it ends, so every test passes alone and in any order.
 *
 * **It writes and deletes probe records in `USER`** through `OcuPilot.Test.InteropPurgeFixture`, so it runs on a throwaway only; the `after` hook removes
 * every one and puts the setting nodes back, whatever the tests answered. It starts no production. The structural walk of the two screens is left to the
 * suite's walk over every screen.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/interop-purge.browser-spec.mjs` (after `npm run build` and the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { interopListHelpers } from './interop-list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { escapeOs, markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const FIXTURE = 'OcuPilot.Test.InteropPurgeFixture';
const SETTINGS_URL = '/ocupilot/interoperability/purge-settings?ns=USER';
const PURGE_URL = '/ocupilot/interoperability/purge?ns=USER';
const ACTION_PATH = '/api/ocupilot/screens/interop.purge/action';
const NODES = ['BodiesToo', 'KeepIntegrity', 'NamespaceBitmapMaint', 'Desc'];
const ARRANGED = 'header=2 body=2 log=1 io=1 alertClosed=1 alertOpen=1';
const PURGED = 'header=1 body=1 log=0 io=0 alertClosed=0 alertOpen=1';

const { rowOf, rowPresent, waitForCell, rowAction, dialogClosed, fill, openList } = interopListHelpers(config, 0);

let browser = null;
let created = false;
let savedSettings = '';

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** USER's four purge setting nodes as `a|b|c|d`, `<absent>` for a node that is not stored. */
const settings = () => probe('PSET', `##class(${FIXTURE}).SettingsText("USER")`).value;

/** USER's probe record counts as the fixture words them. */
const counts = () => probe('PCOUNT', `##class(${FIXTURE}).Counts("USER")`).value;

/** Remove every probe record this spec makes, from both namespaces. */
function drop() {
  const dropped = probe('PDROP', `##class(${FIXTURE}).DropProbes()`);
  assert.equal(dropped.value, '1', `the probe records are removed: ${dropped.output}`);
}

/** Put USER's setting nodes as `text` (`a|b|c|d`) says. */
function putSettings(text) {
  const pieces = text.split('|');
  NODES.forEach((node, at) => {
    probe(`PPUT${at}`, `##class(${FIXTURE}).PutSetting("USER","${node}","${pieces[at] ?? '<absent>'}")`);
  });
}

/** Arrange, back-dated, a header with a body, an event log row, an I/O log row and a closed and an open managed alert, and a header with a body made now. */
function arrange() {
  const made = probe(
    'PMADE',
    `(##class(${FIXTURE}).Header("USER",9,7300,1,"","Old")>0)_(##class(${FIXTURE}).Others("USER",7300))_(##class(${FIXTURE}).Header("USER",9,0,1,"","Cur")>0)`
  );
  assert.equal(made.value, '111', `the probe records are arranged: ${made.output}`);
  assert.equal(counts(), ARRANGED, 'and read as arranged');
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec writes probe records, so it runs only in a throwaway; ${config.container} is not one`);
  // Saved as JSON, one line, because a stored description is text over several lines.
  savedSettings = probe('PSAVE', `##class(${FIXTURE}).SaveSettings()`).value;
  assert.ok(savedSettings, 'the purge setting nodes of both namespaces are saved');
  drop();
  putSettings('<absent>|<absent>|<absent>|<absent>');
  created = true;
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (created && /-ci$/.test(config.container)) {
      drop();
      if (savedSettings) {
        const restored = probe('PRESTORE', `$System.Status.IsOK(##class(${FIXTURE}).RestoreSettings("${escapeOs(savedSettings)}"))`);
        assert.equal(restored.value, '1', `the purge setting nodes are put back as they were: ${restored.output}`);
      }
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

// AC5. Mutation (Rule 19): drop `INTEROP_PURGE_SETTING_LIST` from `config-settings.page.ts`'s served lists, rebuild and redeploy -> the screen offers no Set value dialog and
// the wait for its checkbox times out.
test('AC5: Purge data settings sets Include message bodies from the Set value dialog, and the list and the global show it', async () => {
  putSettings('<absent>|<absent>|<absent>|<absent>');
  const { context, page } = await signedInAt(browser, config, SETTINGS_URL, VIEWPORTS.wide);
  try {
    await openList(page);
    await rowPresent(page, STRINGS.interopPurgeSettingBodies);
    const headers = await page.$$eval('.ocu-data-table-header-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(headers.slice(0, 3), [STRINGS.agentGovernanceColumnSetting, STRINGS.errorLogColumnValue, STRINGS.analyticsColumnStored], 'the declared headers');
    assert.equal((await rowOf(page, STRINGS.interopPurgeSettingBodies))[1], '0', 'an unset setting reads the classic default');
    await rowAction(page, STRINGS.interopPurgeSettingBodies, STRINGS.interopItemSettingSetAction);
    await page.waitForSelector('[data-interop-setting-checkbox]', { visible: true, timeout: config.navigationTimeoutMs });
    await page.click('[data-interop-setting-checkbox]');
    await page.click('[data-interop-setting-confirm]');
    await dialogClosed(page);
    await waitForCell(page, STRINGS.interopPurgeSettingBodies, 1, '1');
    assert.equal(settings(), '1|<absent>|<absent>|<absent>', 'the global holds the value, under its own node and no other');
  } finally {
    await context.close();
    putSettings('<absent>|<absent>|<absent>|<absent>');
  }
});

// AC5. Mutation (Rule 19): make the dialog send `DaysToKeep` 0 (bundle rebuilt and redeployed) -> the old records go but so does the one made now, and the kept-record assertion goes red.
test('AC5: Purge management data reviews the purge, asks for the days and the namespace, and deletes the old records only', async () => {
  drop();
  putSettings('1|<absent>|<absent>|<absent>');
  arrange();
  // The vendor's own total, read once the probe records stand, so the count the list shows afterwards is judged against it, never against an empty namespace.
  const messagesBefore = Number(probe('PMSGS', `##class(${FIXTURE}).VendorCount("USER","Messages")`).value);
  assert.ok(messagesBefore >= 2, 'the arranged headers are counted');
  const { context, page } = await signedInAt(browser, config, PURGE_URL, VIEWPORTS.wide);
  const actions = [];
  page.on('request', (request) => {
    if (request.method() === 'POST' && new URL(request.url()).pathname === ACTION_PATH) actions.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    await openList(page);
    await rowPresent(page, 'Messages');
    const headers = await page.$$eval('.ocu-data-table-header-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(headers.slice(0, 2), [STRINGS.tableColumnType, STRINGS.interopColumnCount], 'the declared headers');
    await rowAction(page, 'Messages', STRINGS.auditDatabasePurgeConfirm);
    await page.waitForSelector('[data-interop-purge-days]', { visible: true, timeout: config.navigationTimeoutMs });
    const opened = await page.evaluate(() => ({
      title: document.querySelector('[role="dialog"] .ocu-dialog-title').textContent.trim(),
      bodies: document.querySelector('[data-interop-purge-setting="bodies"]').textContent.trim(),
      integrity: document.querySelector('[data-interop-purge-setting="integrity"]').textContent.trim(),
      bitmap: document.querySelector('[data-interop-purge-setting="bitmap"]').textContent.trim(),
      consequence: document.querySelector('[data-interop-purge-consequence]').textContent.trim(),
      held: document.querySelector('[data-interop-purge-confirm]').getAttribute('aria-disabled'),
    }));
    assert.deepEqual(
      opened,
      {
        title: STRINGS.auditDatabasePurgeConfirm,
        bodies: `${STRINGS.interopPurgeSettingBodies}: ${STRINGS.tableStatusYes}`,
        integrity: `${STRINGS.interopPurgeSettingIntegrity}: ${STRINGS.tableStatusYes}`,
        bitmap: `${STRINGS.interopPurgeSettingBitmap}: ${STRINGS.tableStatusNo}`,
        consequence: STRINGS.interopPurgeRunConsequence,
        held: 'true',
      },
      'the dialog shows the three settings the purge will use and the consequence, and holds Purge'
    );
    await fill(page, '[data-interop-purge-days]', '3650');
    assert.equal(
      await page.evaluate(() => document.querySelector('[data-interop-purge-confirm]')?.getAttribute('aria-disabled')),
      'true',
      'Purge is held until the namespace is typed'
    );
    await page.click('[data-interop-purge-confirm]');
    await page.evaluate(() => new Promise((resolve) => setTimeout(resolve, 300)));
    assert.equal(actions.length, 0, 'Purge sends nothing until the namespace is typed');
    await fill(page, '[data-interop-purge-typed]', 'USER');
    await page.click('[data-interop-purge-confirm]');
    await dialogClosed(page);
    await waitForCell(page, 'Messages', 1, String(messagesBefore - 1));
    assert.equal(actions.length, 1, 'one purge was sent');
    assert.deepEqual(actions[0], { action: 'purge', id: 'USER', values: { DaysToKeep: '3650' } }, 'naming the namespace, with the days as text');
    assert.equal(counts(), PURGED, 'the back-dated records are gone, the one made now stays, and so does the open managed alert');
  } finally {
    await context.close();
    drop();
    putSettings('<absent>|<absent>|<absent>|<absent>');
  }
});

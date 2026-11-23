/**
 * Story 24.16 Batch 4 in a real browser, against the throwaway instance: Interoperability's Archive settings and Archive manager (AD-5, AD-53, AD-55, AD-56, AD-62).
 *
 * What it pins, in `HSCUSTOM`, whose probe messages this spec creates and removes and whose archive settings it puts back: on Archive settings a person sets Archive to
 * namespace and Number of days before archiving from the Set value dialog, and the list shows each value and the vendor's globals hold them; on Archive manager the Run archive row
 * action reviews the run first and opens a dialog that shows the target, the days, the class and how many messages the run would move, and refuses to go on until the namespace's
 * name is typed; the one request it sends names the namespace and carries no value; the back-dated probe messages are in `USER` under their own ids and gone from `HSCUSTOM`, the
 * message made now stays, and the history's counts show the run.
 *
 * Each test arranges what it needs through the fixture and removes it when it ends, so every test passes alone and in any order.
 *
 * **It writes and deletes probe messages in `HSCUSTOM` and `USER`** through `OcuPilot.Test.InteropArchiveFixture`, so it runs on a throwaway only; the `after` hook removes every
 * one and puts both namespaces' archive trees back, whatever the tests answered. It starts no production. The structural walk of the screens is left to the suite's walk over every
 * screen.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/interop-archive.browser-spec.mjs` (after `npm run build` and the bundle copied into the throwaway).
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
const FIXTURE = 'OcuPilot.Test.InteropArchiveFixture';
const SETTINGS_URL = '/ocupilot/interoperability/archive-settings?ns=HSCUSTOM';
const ARCHIVE_URL = '/ocupilot/interoperability/archive?ns=HSCUSTOM';
const ACTION_PATH = '/api/ocupilot/screens/interop.archive/action';
const EMPTY_TREES = '{"HSCUSTOM":[],"USER":[]}';

const { rowOf, rowPresent, waitForCell, rowAction, dialogClosed, fill, openList } = interopListHelpers(config, 0);

let browser = null;
let created = false;
let savedTrees = '';

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** HSCUSTOM's archive settings as `target|class|days`, `<absent>` for a node that is not stored. */
const settings = () => probe('ASET', `##class(${FIXTURE}).SettingsText("HSCUSTOM")`).value;

/** The probe message ids `namespace` holds, ascending, comma-separated. */
const ids = (namespace) => probe(`AIDS${namespace}`, `##class(${FIXTURE}).HeaderIds("${namespace}")`).value;

/** Remove every probe message this spec makes, and their archived copies, from both namespaces. */
function drop() {
  const dropped = probe('ADROP', `##class(${FIXTURE}).DropProbes()`);
  assert.equal(dropped.value, '1', `the probe messages are removed: ${dropped.output}`);
}

/** Put both namespaces' archive trees as `text` (JSON) says. */
function putTrees(text) {
  const restored = probe('ATREES', `$System.Status.IsOK(##class(${FIXTURE}).RestoreTrees("${escapeOs(text)}"))`);
  assert.equal(restored.value, '1', `the archive trees are put as asked: ${restored.output}`);
}

/** Arrange five back-dated messages (an HL7 message, an XML object, a stream, one with no body and a Queued one) and one made now, in HSCUSTOM. */
function arrange() {
  const made = probe(
    'AMADE',
    `(##class(${FIXTURE}).Store("HSCUSTOM","hl7","A")>0)_(##class(${FIXTURE}).Store("HSCUSTOM","xml","B")>0)_(##class(${FIXTURE}).Store("HSCUSTOM","chars","C")>0)_(##class(${FIXTURE}).Store("HSCUSTOM","none","D")>0)_(##class(${FIXTURE}).Store("HSCUSTOM","none","E",7300,2)>0)_(##class(${FIXTURE}).Store("HSCUSTOM","xml","F",0)>0)`
  );
  assert.equal(made.value, '111111', `the probe messages are arranged: ${made.output}`);
  assert.equal(ids('USER'), '', 'and none is in USER yet');
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec writes probe messages, so it runs only in a throwaway; ${config.container} is not one`);
  savedTrees = probe('ASAVE', `##class(${FIXTURE}).SaveTrees()`).value;
  assert.ok(savedTrees, 'the archive trees of both namespaces are saved');
  drop();
  putTrees(EMPTY_TREES);
  created = true;
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (created && /-ci$/.test(config.container)) {
      drop();
      if (savedTrees) putTrees(savedTrees);
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

// AC6. Mutation (Rule 19): drop `INTEROP_ARCHIVE_SETTING_LIST` from `config-settings.page.ts`'s served lists, rebuild and redeploy -> the screen offers no Set value dialog and the
// wait for its field times out.
test('AC6: Archive settings sets Archive to namespace and the days from the Set value dialog, and the list and the globals show them', async () => {
  putTrees(EMPTY_TREES);
  const { context, page } = await signedInAt(browser, config, SETTINGS_URL, VIEWPORTS.wide);
  try {
    await openList(page);
    await rowPresent(page, STRINGS.interopArchiveSettingTarget);
    const headers = await page.$$eval('.ocu-data-table-header-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(headers.slice(0, 3), [STRINGS.agentGovernanceColumnSetting, STRINGS.errorLogColumnValue, STRINGS.analyticsColumnStored], 'the declared headers');
    assert.equal((await rowOf(page, STRINGS.interopArchiveSettingDays))[1], '30', 'an unset setting reads the vendor default');
    await rowAction(page, STRINGS.interopArchiveSettingTarget, STRINGS.interopItemSettingSetAction);
    await page.waitForSelector('[data-interop-setting-value]', { visible: true, timeout: config.navigationTimeoutMs });
    await fill(page, '[data-interop-setting-value]', 'USER');
    await page.click('[data-interop-setting-confirm]');
    await dialogClosed(page);
    await waitForCell(page, STRINGS.interopArchiveSettingTarget, 1, 'USER');
    await rowAction(page, STRINGS.interopArchiveSettingDays, STRINGS.interopItemSettingSetAction);
    await page.waitForSelector('[data-interop-setting-value]', { visible: true, timeout: config.navigationTimeoutMs });
    await fill(page, '[data-interop-setting-value]', '3650');
    await page.click('[data-interop-setting-confirm]');
    await dialogClosed(page);
    await waitForCell(page, STRINGS.interopArchiveSettingDays, 1, '3650');
    assert.equal(settings(), 'USER|Ens.Archive.Manager|3650', 'the vendor holds both values, and the class at its own');
  } finally {
    await context.close();
    putTrees(EMPTY_TREES);
  }
});

// AC6. Mutation (Rule 19): make the dialog send a value with the run (bundle rebuilt and redeployed) -> the request assertion goes red; make it send without the typed name -> the held
// assertion goes red.
test('AC6: Archive manager reviews the run, asks for the namespace, moves the old messages only and shows the run in its history', async () => {
  drop();
  putTrees(EMPTY_TREES);
  probe('ASETS', `##class(${FIXTURE}).PutSettings("HSCUSTOM","USER","<absent>",3650)`);
  arrange();
  const { context, page } = await signedInAt(browser, config, ARCHIVE_URL, VIEWPORTS.wide);
  const actions = [];
  page.on('request', (request) => {
    if (request.method() === 'POST' && new URL(request.url()).pathname === ACTION_PATH) actions.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    await openList(page);
    await rowPresent(page, STRINGS.interopArchiveRowStatus);
    const headers = await page.$$eval('.ocu-data-table-header-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(headers.slice(0, 2), [STRINGS.tableColumnName, STRINGS.errorLogColumnValue], 'the declared headers');
    assert.equal((await rowOf(page, STRINGS.interopArchiveRowStatus))[1], STRINGS.interopArchiveStatusIdle, 'no run is running');
    await rowAction(page, STRINGS.interopArchiveRowArchived, STRINGS.interopArchiveAction);
    await page.waitForSelector('[data-interop-archive-typed]', { visible: true, timeout: config.navigationTimeoutMs });
    const opened = await page.evaluate(() => ({
      title: document.querySelector('[role="dialog"] .ocu-dialog-title').textContent.trim(),
      target: document.querySelector('[data-interop-archive-setting="target"]').textContent.trim(),
      days: document.querySelector('[data-interop-archive-setting="days"]').textContent.trim(),
      classname: document.querySelector('[data-interop-archive-setting="class"]').textContent.trim(),
      messages: document.querySelector('[data-interop-archive-setting="messages"]').textContent.trim(),
      consequence: document.querySelector('[data-interop-archive-consequence]').textContent.trim(),
      held: document.querySelector('[data-interop-archive-confirm]').getAttribute('aria-disabled'),
    }));
    assert.deepEqual(
      opened,
      {
        title: STRINGS.interopArchiveAction,
        target: `${STRINGS.interopArchiveSettingTarget}: USER`,
        days: `${STRINGS.interopArchiveSettingDays}: 3650`,
        classname: `${STRINGS.interopArchiveSettingClass}: Ens.Archive.Manager`,
        messages: `${STRINGS.interopArchiveMessages}: 5`,
        consequence: STRINGS.interopArchiveRunConsequence,
        held: 'true',
      },
      'the dialog shows what the run will use and move, and the consequence, and holds Run archive'
    );
    await page.click('[data-interop-archive-confirm]');
    await page.evaluate(() => new Promise((resolve) => setTimeout(resolve, 300)));
    assert.equal(actions.length, 0, 'Run archive sends nothing until the namespace is typed');
    await fill(page, '[data-interop-archive-typed]', 'HSCUSTOM');
    await page.click('[data-interop-archive-confirm]');
    await dialogClosed(page);
    // The list is still narrowed to the row the action was opened from, so that row's count is the one that shows the run.
    await waitForCell(page, STRINGS.interopArchiveRowArchived, 1, '5');
    assert.equal(actions.length, 1, 'one run was sent');
    assert.deepEqual(actions[0], { action: 'archive', id: 'HSCUSTOM', values: {} }, 'naming the namespace, with no value');
    assert.equal(probe('ACNT', '##class(Ens.Archive.Manager).GetRunningCount()').value, '6,5,5,3,0', 'the vendor counts six processed, five archived, five headers and three bodies deleted, no error');
    assert.equal(ids('USER').split(',').length, 5, 'the five back-dated messages are in USER');
    assert.equal(ids('HSCUSTOM').split(',').length, 1, 'and the one made now is the one left in HSCUSTOM');
  } finally {
    await context.close();
    drop();
    putTrees(EMPTY_TREES);
  }
});

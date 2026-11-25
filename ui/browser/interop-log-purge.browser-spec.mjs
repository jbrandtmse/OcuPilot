/**
 * Story 24.17 Batch 2 in a real browser, against the throwaway instance: Interoperability's Business rule log and Business process log (AD-5, AD-53, AD-55, AD-56, AD-62).
 *
 * What it pins, in `USER`, whose probe log rows this spec creates and removes: on each log a person opens Purge from a row, sees the dialog's title, the log's record count and
 * the log's own consequence, is held until the days and the namespace's name are right, and purges with 3650 days typing the namespace's name; the one request it sends names the
 * namespace and carries the days as text; the back-dated probe leaves the list and the vendor, and the probe made now stays, and so does, on the business process log, a back-dated
 * business process that is still running.
 *
 * It arranges what it needs through the fixture and removes it when it ends, so every test passes alone and in any order.
 *
 * **It writes and deletes probe rows in `USER`** through `OcuPilot.Test.InteropLogPurgeFixture`, so it runs on a throwaway only, and refuses to start while `USER` holds a rule log entry
 * older than 3,650 days or a completed business process that is not a probe, which the purge would delete; the `after` hook removes every probe, whatever the tests answered. It starts no
 * production. The structural walk of the two screens is left to the suite's walk over every screen.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/interop-log-purge.browser-spec.mjs` (after `npm run build` and the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { interopListHelpers } from './interop-list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const FIXTURE = 'OcuPilot.Test.InteropLogPurgeFixture';
const MARKER = 'OcuProbe2417';
const OLD_DAYS = 7300;
const RULE_URL = '/ocupilot/interoperability/rule-log?ns=USER';
const PROCESS_URL = '/ocupilot/interoperability/process-log?ns=USER';
const RULE_ACTION_PATH = '/api/ocupilot/screens/interop.rulelog/action';
const PROCESS_ACTION_PATH = '/api/ocupilot/screens/interop.processlog/action';

const { rowPresent, rowAction, dialogClosed, fill, openList } = interopListHelpers(config, 0);

let browser = null;
let created = false;

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** Remove every probe rule log entry and business process from both namespaces. */
function drop() {
  const dropped = probe('LDROP', `##class(${FIXTURE}).DropProbes()`);
  assert.equal(dropped.value, '1', `the probe rows are removed: ${dropped.output}`);
}

/** Store one probe through `expression` and answer its id. */
function stored(name, expression) {
  const id = probe(name, expression).value;
  assert.match(id, /^[1-9][0-9]*$/, `the probe ${name} is stored`);
  return id;
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec writes probe rows, so it runs only in a throwaway; ${config.container} is not one`);
  assert.equal(probe('LFOREIGN', `##class(${FIXTURE}).Foreign("USER")`).value, '0', 'USER holds no rule log entry or business process a 3650-day purge could delete that is not a probe');
  drop();
  created = true;
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (created && /-ci$/.test(config.container)) drop();
  } finally {
    if (browser !== null) await browser.close();
  }
});

/**
 * Purge the log at `url` from the row of `rowId` with 3650 days, typing the namespace's name, and answer the requests sent to `actionPath`. Asserts what the dialog shows and holds
 * on the way.
 */
async function purgeFromRow(url, actionPath, rowId, consequence) {
  const { context, page } = await signedInAt(browser, config, url, VIEWPORTS.wide);
  const actions = [];
  page.on('request', (request) => {
    if (request.method() === 'POST' && new URL(request.url()).pathname === actionPath) actions.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    await openList(page);
    await rowPresent(page, rowId);
    await rowAction(page, rowId, STRINGS.auditDatabasePurgeConfirm, MARKER);
    await page.waitForSelector('[data-interop-purge-days]', { visible: true, timeout: config.navigationTimeoutMs });
    const opened = await page.evaluate(() => ({
      title: document.querySelector('[role="dialog"] .ocu-dialog-title').textContent.trim(),
      count: document.querySelector('[data-interop-purge-count]')?.textContent.trim() ?? null,
      settings: document.querySelector('[data-interop-purge-settings]') !== null,
      consequence: document.querySelector('[data-interop-purge-consequence]').textContent.trim(),
      held: document.querySelector('[data-interop-purge-confirm]').getAttribute('aria-disabled'),
    }));
    assert.equal(opened.title, STRINGS.auditDatabasePurgeConfirm, 'the dialog is titled Purge');
    assert.match(opened.count ?? '', new RegExp(`^${STRINGS.interopColumnCount}: [0-9]+$`), 'it shows the log\'s record count');
    assert.ok(Number((opened.count ?? '').split(': ')[1]) >= 2, 'and the count includes the probes');
    assert.equal(opened.settings, false, 'it shows no purge settings');
    assert.equal(opened.consequence, consequence, 'it states the log\'s own consequence');
    assert.equal(opened.held, 'true', 'and holds Purge');
    await fill(page, '[data-interop-purge-days]', '3650');
    await page.click('[data-interop-purge-confirm]');
    await page.evaluate(() => new Promise((resolve) => setTimeout(resolve, 300)));
    assert.equal(actions.length, 0, 'Purge sends nothing until the namespace is typed');
    await fill(page, '[data-interop-purge-typed]', 'USER');
    await page.click('[data-interop-purge-confirm]');
    await dialogClosed(page);
    assert.equal(actions.length, 1, 'one purge was sent');
    assert.deepEqual(actions[0], { action: 'purge', id: 'USER', values: { DaysToKeep: '3650' } }, 'naming the namespace, with the days as text');
    return { context, page };
  } catch (error) {
    await context.close();
    throw error;
  }
}

// AC9. Mutation (Rule 19): make the dialog send `DaysToKeep` 0 (bundle rebuilt and redeployed) -> the entry made now goes too and the kept-entry assertion goes red.
test('AC9: Business rule log purges the old probe entry with 3650 days, typing the namespace, and the new one stays', async () => {
  drop();
  const oldId = stored('LRULEOLD', `##class(${FIXTURE}).ProbeRule("USER",${OLD_DAYS},0,0)`);
  const newId = stored('LRULENEW', `##class(${FIXTURE}).ProbeRule("USER",0,0,0)`);
  let context = null;
  try {
    const purged = await purgeFromRow(RULE_URL, RULE_ACTION_PATH, oldId, STRINGS.interopRuleLogPurgeConsequence);
    context = purged.context;
    const { page } = purged;
    await rowPresent(page, oldId, false);
    await rowPresent(page, newId);
    assert.equal(probe('LRULEGONE', `##class(${FIXTURE}).RuleExists("USER",${oldId})`).value, '0', 'the vendor no longer holds the old entry');
    assert.equal(probe('LRULEKEPT', `##class(${FIXTURE}).RuleExists("USER",${newId})`).value, '1', 'and still holds the one made now');
  } finally {
    if (context !== null) await context.close();
    drop();
  }
});

// AC9. Mutation (Rule 19): make the dialog send `DaysToKeep` 0 (bundle rebuilt and redeployed) -> the record made now goes too and the kept-record assertion goes red.
test('AC9: Business process log purges the old completed probe with 3650 days, typing the namespace, and the new one and a running one stay', async () => {
  drop();
  const oldId = stored('LPROCOLD', `##class(${FIXTURE}).ProbeProcess("USER",${OLD_DAYS},1)`);
  const runningId = stored('LPROCRUN', `##class(${FIXTURE}).ProbeProcess("USER",${OLD_DAYS},0)`);
  const newId = stored('LPROCNEW', `##class(${FIXTURE}).ProbeProcess("USER",0,1)`);
  let context = null;
  try {
    const purged = await purgeFromRow(PROCESS_URL, PROCESS_ACTION_PATH, oldId, STRINGS.interopProcessLogPurgeConsequence);
    context = purged.context;
    const { page } = purged;
    await rowPresent(page, oldId, false);
    await rowPresent(page, newId);
    await rowPresent(page, runningId);
    assert.equal(probe('LPROCGONE', `##class(${FIXTURE}).ProcessExists("USER",${oldId})`).value, '0', 'the vendor no longer holds the old completed record');
    assert.equal(probe('LPROCKEPT', `##class(${FIXTURE}).ProcessExists("USER",${newId})`).value, '1', 'and still holds the one made now');
    assert.equal(probe('LPROCKEPTRUN', `##class(${FIXTURE}).ProcessExists("USER",${runningId})`).value, '1', 'and the old one still running');
  } finally {
    if (context !== null) await context.close();
    drop();
  }
});

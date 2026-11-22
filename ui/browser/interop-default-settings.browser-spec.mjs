/**
 * Story 24.15 in a real browser, against the throwaway instance: Interoperability's System default settings, saved and removed, and
 * Compare default settings (AD-5, AD-36, AD-53, AD-54, AD-55, AD-62; DW-2636).
 *
 * What it pins, in `USER` and `HSCUSTOM`, whose probe default settings this spec creates and removes: the list offers New default
 * setting and a row action menu, and lists the probe setting under the published headers; New default setting creates a setting, a held
 * key and a value the setting does not accept each refused with the server's sentence in the dialog; Edit opens the same dialog on the
 * selected row with the key read-only and changes its value; Compare default settings for `HSCUSTOM` lists the setting as differing,
 * with each side's value, and one held only here; Remove, which types the setting's name, removes it; and the list passes the
 * structural and contrast checks at 1280 light, 720 light and 1280 dark, with no entry beyond the baseline (DW-1337).
 *
 * Each test arranges the settings it needs through the fixture and removes them when it ends, so every test passes alone and in any
 * order. It shares its page helpers with the Business partners spec (`interop-list-spec.mjs`).
 *
 * **It writes probe default settings in `USER` and `HSCUSTOM`** through `OcuPilot.Test.InteropLookupFixture`, so it runs on a throwaway
 * only; the `after` hook removes every setting, whatever the tests answered. It starts no production.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/interop-default-settings.browser-spec.mjs` (after `npm run build` and the
 * bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { interopListHelpers } from './interop-list-spec.mjs';
import { ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const FIXTURE = 'OcuPilot.Test.InteropLookupFixture';
const PRODUCTION = 'OcuProbe2415.Production';
const SETTING = 'ArchiveIO';
const HELD = 'OcuHeld2415';
const LIST_URL = '/ocupilot/interoperability/default-settings?ns=USER';
const LIST_ROUTE = 'interoperability/default-settings';
const DIFF_URL = '/ocupilot/interoperability/default-settings-diff?ns=USER';
const ACTION_PATH = '/api/ocupilot/screens/interop.defaultsettings/action';
const ADD_PATH = '/api/ocupilot/interop/default-settings';
const AUDIT_READ_PATH = '/api/ocupilot/screens/logs.audit/read';
/** The cell that holds a setting's name, and the one that holds its value. */
const SETTING_CELL = 3;
const VALUE_CELL = 4;

const { structural, rowOf, rowPresent, waitForCell, rowAction, dialogClosed, fill, openList, openPrimary: openPrimaryWhenReady } = interopListHelpers(config, SETTING_CELL);

let browser = null;
let created = false;

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** The stored setting as `value|description|deployable`, `<absent>` when the namespace does not hold it. */
function stored(setting, namespace = 'USER') {
  return probe('DSTEXT', `##class(${FIXTURE}).DefaultText("${PRODUCTION}","*","*","${setting}","${namespace}")`).value;
}

/** Wait, up to ten probes, until the stored setting reads `<absent>` (`absent` true) or something else; answers the last reading. */
async function settled(setting, absent) {
  let last = stored(setting);
  for (let tries = 0; (last === '<absent>') !== absent && tries < 10; tries += 1) {
    await new Promise((resolve) => setTimeout(resolve, 500));
    last = stored(setting);
  }
  return last;
}

/** Remove every probe default setting this spec makes, in both namespaces, whatever an earlier step left. */
function drop() {
  const cleared = probe('DSDROP', `$System.Status.IsOK(##class(${FIXTURE}).DropDefaults("OcuProbe2415"))`);
  assert.equal(cleared.value, '1', `the probe settings are removed: ${cleared.output}`);
}

/** The held setting `setting` of `namespace` with `value`, a description and the flag. */
function arrange(setting, value, namespace = 'USER', description = 'probe description', deployable = 0) {
  const made = probe('DSMADE', `$System.Status.IsOK(##class(${FIXTURE}).PutDefault("${PRODUCTION}","*","*","${setting}","${value}","${description}",${deployable},"${namespace}"))`);
  assert.equal(made.value, '1', `the probe setting ${setting} is arranged: ${made.output}`);
}

const field = (name) => `[data-interop-default-setting-field="${name}"]`;

/** Open the primary action's dialog on the current list. */
const openPrimary = (page) => openPrimaryWhenReady(page, field('Setting'));

/** Every body row's cells, each as its trimmed text. */
function allRows(page) {
  return page.evaluate(
    (rowSelector) => Array.from(document.querySelectorAll(rowSelector)).map((row) => Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim())),
    ROW_SELECTOR
  );
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec writes probe default settings, so it runs only in a throwaway; ${config.container} is not one`);
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

// Mutation (Rule 19): drop the list descriptor's primary action, regenerate the mirror, rebuild and redeploy -> the command bar offers
// none and the New default setting assertion goes red.
test('System default settings lists the probe setting under the published headers, offers New default setting and a row action menu, and the walk passes', async () => {
  drop();
  arrange(HELD, '3');
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  try {
    await openList(page);
    await rowPresent(page, HELD);
    const headers = await page.$$eval('.ocu-data-table-header-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(
      headers.slice(0, 6),
      [STRINGS.systemInfoProduction, STRINGS.interopItemSettingsCriterionItem, STRINGS.interopItemColumnClass, STRINGS.agentGovernanceColumnSetting, STRINGS.errorLogColumnValue, STRINGS.interopDefaultSettingColumnDeployable],
      'the declared headers'
    );
    const row = await rowOf(page, HELD);
    assert.deepEqual(row.slice(0, 5), [PRODUCTION, '*', '*', HELD, '3'], 'the setting reads its key and its value');
    assert.equal(await page.$eval('.ocu-command-bar button.ocu-command-bar-primary', (node) => node.textContent.trim()), STRINGS.interopDefaultSettingAddAction, 'the command bar offers New default setting');
    assert.deepEqual(await structural(page, LIST_ROUTE), [], 'System default settings: no violation beyond the baseline\'s entries');
  } finally {
    await context.close();
    drop();
  }
});

// AC5. Mutation (Rule 19): make the Edit dialog send no `Value`, rebuild and redeploy -> the stored value does not change and the
// changed-value assertion goes red.
test('AC5: New default setting adds a setting, Edit changes its value with the key read-only, Compare lists it, and Remove types its name', async () => {
  drop();
  arrange(HELD, '3');
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const adds = [];
  const actions = [];
  page.on('request', (request) => {
    if (request.method() !== 'POST') return;
    const path = new URL(request.url()).pathname;
    if (path === ADD_PATH) adds.push(JSON.parse(request.postData() ?? '{}'));
    if (path === ACTION_PATH) actions.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    await openList(page);
    await rowPresent(page, HELD);
    await openPrimary(page);
    const opened = await page.evaluate(() => ({
      title: document.querySelector('[role="dialog"] .ocu-dialog-title')?.textContent?.trim(),
      text: document.querySelector('[role="dialog"]').textContent,
      production: document.querySelector('[data-interop-default-setting-field="Production"]').value,
    }));
    assert.equal(opened.title, STRINGS.interopDefaultSettingAddAction, 'the dialog is titled with the published words');
    assert.ok(opened.text.includes(STRINGS.interopDefaultSettingHelp), 'and says what a default setting does');
    assert.ok(opened.text.includes(STRINGS.interopDefaultSettingDeployableHelp), 'and what Deployable means');
    assert.equal(opened.production, '*', 'a new setting starts for any production');

    await fill(page, field('Production'), PRODUCTION);
    await fill(page, field('Setting'), HELD);
    await page.click('[data-interop-default-setting-confirm]');
    await page.waitForSelector('[data-interop-default-setting-reason]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-interop-default-setting-reason]', (node) => node.textContent.trim()), STRINGS.interopDefaultSettingRefusalTaken, 'a held key is refused with the server\'s sentence');

    await fill(page, field('Setting'), 'PoolSize');
    await fill(page, field('Value'), '0');
    await page.click('[data-interop-default-setting-confirm]');
    await page.waitForSelector('[data-interop-default-setting-violation="Value"]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-interop-default-setting-violation="Value"]', (node) => node.textContent.trim()), STRINGS.interopDefaultSettingRefusalValue, 'a value the setting does not accept is refused under the value');
    assert.equal(await settled('PoolSize', true), '<absent>', 'and nothing is stored');

    await fill(page, field('Setting'), SETTING);
    await fill(page, field('Value'), '1');
    await fill(page, field('Description'), 'browser description');
    await page.click(field('Deployable'));
    await page.click('[data-interop-default-setting-confirm]');
    await dialogClosed(page);
    await rowPresent(page, SETTING);
    assert.equal(adds.at(-1).Setting, SETTING, 'the Save carries the setting as typed');
    assert.equal(adds.at(-1).Deployable, true, 'and the flag as a boolean');
    assert.equal(stored(SETTING), '1|browser description|1', 'the setting is stored with what was typed');
    const added = await rowOf(page, SETTING);
    // A row the person just added carries the changed marker and the read-back after its name.
    assert.ok(added[3].startsWith(SETTING) && added[4] === '1', `and the list shows it: ${JSON.stringify(added)}`);

    await rowAction(page, SETTING, STRINGS.agentPanelSecretWarningEdit);
    await page.waitForSelector(field('Value'), { visible: true, timeout: config.navigationTimeoutMs });
    const edit = await page.evaluate((name) => ({
      title: document.querySelector('[role="dialog"] .ocu-dialog-title').textContent.trim(),
      readOnly: document.querySelector(name).readOnly,
      held: document.querySelector(name).value,
    }), field('Setting'));
    assert.deepEqual(edit, { title: STRINGS.interopDefaultSettingEditTitle.replace('<setting>', SETTING), readOnly: true, held: SETTING }, 'Edit opens the same dialog on the row, with the key read-only');
    assert.equal(await page.$eval(field('Value'), (node) => node.value), '1', 'holding the value the row reported');
    await fill(page, field('Value'), '2');
    await page.click('[data-interop-default-setting-confirm]');
    await dialogClosed(page);
    await waitForCell(page, SETTING, VALUE_CELL, '2');
    const editSent = actions.at(-1);
    assert.deepEqual([editSent.action, editSent.id.split('\u0001').at(-1)], ['edit', SETTING], 'one edit, sent with the row key');
    assert.deepEqual(editSent.values, { Value: '2' }, 'carrying only the value that was changed, and never the key');
    assert.equal(stored(SETTING), '2|browser description|1', 'the stored value changed and nothing else did');

    // Compare default settings: this setting differs from HSCUSTOM's, the held one is held only here.
    arrange(SETTING, '9', 'HSCUSTOM');
    await page.goto(`${config.origin}${DIFF_URL}`, { waitUntil: 'networkidle2' });
    await waitForMapAnswered(page, config.navigationTimeoutMs);
    await page.waitForSelector('#ocu-audit-criterion-target', { timeout: config.navigationTimeoutMs });
    await fill(page, '#ocu-audit-criterion-target', 'HSCUSTOM');
    await page.click('.ocu-criteria-controls button[type="submit"]');
    await waitForRows(page, config.navigationTimeoutMs);
    const headers = await page.$$eval('.ocu-data-table-header-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(
      headers.slice(0, 7),
      [STRINGS.systemInfoProduction, STRINGS.interopItemSettingsCriterionItem, STRINGS.interopItemColumnClass, STRINGS.agentGovernanceColumnSetting, STRINGS.databaseDirectoryChange, STRINGS.interopDefaultSettingColumnValueHere, STRINGS.interopDefaultSettingColumnValueThere],
      'Compare default settings draws its published headers'
    );
    const rows = (await allRows(page)).filter((cells) => cells[0] === PRODUCTION);
    assert.deepEqual(
      rows.map((cells) => [cells[3], cells[4], cells[5], cells[6]]),
      [
        [SETTING, 'differs', '2', '9'],
        [HELD, 'only here', '3', STRINGS.tableEmptyValue],
      ],
      'the comparison lists the differing setting with each side\'s value, and the one held only here'
    );

    await page.goto(`${config.origin}${LIST_URL}`, { waitUntil: 'networkidle2' });
    await openList(page);
    await rowAction(page, SETTING, STRINGS.actionRemove);
    await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    const dialog = await page.evaluate(() => ({
      title: document.querySelector('[role="dialog"] .ocu-dialog-title').textContent.trim(),
      consequence: document.querySelector('.ocu-typed-name-consequence').textContent.trim(),
    }));
    assert.deepEqual(dialog, { title: `${STRINGS.actionRemove} ${SETTING}`, consequence: STRINGS.interopDefaultSettingRemoveConsequence }, 'Remove asks for the name and states what removing it does');
    const sent = actions.length;
    await page.type('.ocu-typed-name-field', SETTING);
    await page.keyboard.press('Enter');
    await dialogClosed(page);
    await rowPresent(page, SETTING, false);
    assert.equal(actions.length, sent + 1, 'one remove was sent');
    assert.equal(actions.at(-1).action, 'remove', 'a remove');
    assert.equal(await settled(SETTING, true), '<absent>', 'the setting is gone from the instance');
    assert.notEqual(stored(HELD), '<absent>', 'and the other setting is untouched');
    assert.equal(stored(SETTING, 'HSCUSTOM'), '9|probe description|0', 'as is the setting HSCUSTOM holds');
  } finally {
    await context.close();
    drop();
  }
});

const THERE = 'OcuThere2415';
const SAME = 'OcuSame2415';
const SECRET = 'SSLPassword';
const HERE_MARKER = 'OcuBrowserMarker2415Here';
const THERE_MARKER = 'OcuBrowserMarker2415There';

/** Open Compare default settings with `target` typed, and wait for its rows. */
async function openDiff(page, target) {
  await page.goto(`${config.origin}${DIFF_URL}`, { waitUntil: 'networkidle2' });
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  await page.waitForSelector('#ocu-audit-criterion-target', { timeout: config.navigationTimeoutMs });
  await fill(page, '#ocu-audit-criterion-target', target);
  await page.click('.ocu-criteria-controls button[type="submit"]');
  await waitForRows(page, config.navigationTimeoutMs);
}

/** The compare's probe rows as `[setting, change, value here, value there]`. */
async function diffRows(page) {
  return (await allRows(page)).filter((cells) => cells[0] === PRODUCTION).map((cells) => [cells[3], cells[4], cells[5], cells[6]]);
}

// Mutation (Rule 19): drop the only-there branch of `InteropPort.ListDefaultSettingDiff` (a server change, so no rebuild) -> the
// comparison lists no only-there row and this goes red.
test('Compare default settings lists the only-here, only-there and differing settings and never an identical one', async () => {
  drop();
  arrange(SETTING, '1');
  arrange(SETTING, '9', 'HSCUSTOM');
  arrange(HELD, '3');
  arrange(THERE, '7', 'HSCUSTOM');
  arrange(SAME, 'alike');
  arrange(SAME, 'alike', 'HSCUSTOM');
  const { context, page } = await signedInAt(browser, config, DIFF_URL, VIEWPORTS.wide);
  try {
    await openDiff(page, 'HSCUSTOM');
    assert.deepEqual(
      await diffRows(page),
      [
        [SETTING, 'differs', '1', '9'],
        [HELD, 'only here', '3', STRINGS.tableEmptyValue],
        [THERE, 'only there', STRINGS.tableEmptyValue, '7'],
      ],
      'the three kinds of change are listed with each side\'s value, and the identical setting is absent'
    );
    assert.ok(!(await page.evaluate(() => document.body.textContent)).includes(SAME), 'no part of the page names the identical setting');
  } finally {
    await context.close();
    drop();
  }
});

// Mutation (Rule 19): make `InteropPort.DefaultSettingRow` keep a secret-named setting's value (a server change) -> the list and the
// comparison carry the marker and this goes red; make `OcuPilot.Screen.Read` stop masking the audit rows -> the audit rows carry it.
test('a secret-named setting\'s value appears in no list, comparison or audit row the screens show', async () => {
  drop();
  const since = probe('DSSTAMP', '$ZDateTime($Horolog,3)').value;
  assert.match(since, /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/, 'the instance\'s own clock reads as the audit criterion spells it');
  arrange(SECRET, HERE_MARKER);
  arrange(SECRET, THERE_MARKER, 'HSCUSTOM');
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const bodyText = () => page.evaluate(() => document.body.textContent);
  try {
    await openList(page);
    await rowPresent(page, SECRET);
    const row = await rowOf(page, SECRET);
    assert.ok(!row.some((cell) => cell.includes(HERE_MARKER)), `the list row carries no value: ${JSON.stringify(row)}`);
    assert.ok(!(await bodyText()).includes(HERE_MARKER), 'and no part of the list does');

    await openDiff(page, 'HSCUSTOM');
    const compared = (await diffRows(page)).find((cells) => cells[0] === SECRET);
    assert.ok(compared !== undefined && compared[1] === 'differs', `the comparison lists the setting as differing: ${JSON.stringify(compared)}`);
    assert.ok(!compared.some((cell) => cell.includes(HERE_MARKER) || cell.includes(THERE_MARKER)), 'showing neither value');
    const compareText = await bodyText();
    assert.ok(!compareText.includes(HERE_MARKER) && !compareText.includes(THERE_MARKER), 'and no part of the comparison does');

    // Logs > Audit: the vendor's own rows of these two inserts, read since before they were written.
    await page.goto(`${config.origin}/ocupilot/logs/audit?ns=USER`, { waitUntil: 'networkidle2' });
    await page.waitForSelector('#ocu-audit-criterion-events', { timeout: config.navigationTimeoutMs });
    // The screen opens on its default search: wait for that read to render, rows or the empty state, so its answer
    // cannot overwrite the begin criterion typed below.
    await page.waitForFunction(
      () => document.querySelector('[role="grid"] .ocu-data-table-body [role="row"]') !== null
        || document.querySelector('.ocu-data-table-empty') !== null,
      { timeout: config.navigationTimeoutMs }
    );
    await fill(page, '#ocu-audit-criterion-beginDateTime', since);
    await fill(page, '#ocu-audit-criterion-events', 'ModifyDefaultSetting');
    const answered = page.waitForResponse(
      (response) => {
        const url = new URL(response.url());
        return url.pathname === AUDIT_READ_PATH
          && url.searchParams.get('events') === 'ModifyDefaultSetting'
          && url.searchParams.get('beginDateTime') === since;
      },
      { timeout: config.navigationTimeoutMs }
    );
    await page.click('.ocu-criteria-controls button[type="submit"]');
    await answered;
    await page.waitForFunction(
      (rowSelector) => {
        const rows = Array.from(document.querySelectorAll(rowSelector));
        return rows.length > 0 && rows.every((row) => row.textContent.includes('ModifyDefaultSetting'));
      },
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR
    );
    const opened = [];
    for (let index = 0; index < 2; index += 1) {
      await clickRowCentre(page, { index, link: true });
      await page.waitForSelector('[role="dialog"] .ocu-dialog-payload', { timeout: config.navigationTimeoutMs });
      opened.push(await page.$eval('[role="dialog"] .ocu-dialog-payload', (node) => node.textContent));
      await page.keyboard.press('Escape');
      await dialogClosed(page);
    }
    for (const payload of opened) {
      assert.ok(payload.includes(`SettingName: ${SECRET}`), `an audit row names the setting: ${payload.slice(0, 200)}`);
      assert.ok(payload.includes('*****'), 'and reads the mask where its value was');
      assert.ok(!payload.includes(HERE_MARKER) && !payload.includes(THERE_MARKER), 'and carries neither value');
    }
    const auditText = await bodyText();
    assert.ok(!auditText.includes(HERE_MARKER) && !auditText.includes(THERE_MARKER), 'no part of the audit screen does either');
  } finally {
    await context.close();
    drop();
  }
});

// Mutation (Rule 19): put back the `Value '= ""` test in `InteropPort.DefaultSettingViolations` (a server change) -> the add answers a
// generic failure, no value sentence shows and this goes red.
test('New default setting with no value for an integer setting is refused under the value and stores nothing', async () => {
  drop();
  arrange(HELD, '3');
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  try {
    await openList(page);
    await openPrimary(page);
    await fill(page, field('Production'), PRODUCTION);
    await fill(page, field('Setting'), 'PoolSize');
    await page.click('[data-interop-default-setting-confirm]');
    await page.waitForSelector('[data-interop-default-setting-violation="Value"]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-interop-default-setting-violation="Value"]', (node) => node.textContent.trim()), STRINGS.interopDefaultSettingRefusalValue, 'the value is refused with the published sentence');
    assert.equal(await settled('PoolSize', true), '<absent>', 'and nothing is stored');
  } finally {
    await context.close();
    drop();
  }
});

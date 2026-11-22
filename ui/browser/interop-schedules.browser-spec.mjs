/**
 * Story 24.15 Batch 3 in a real browser, against the throwaway instance: Interoperability's Schedule specs, added, edited and removed (AD-5, AD-53,
 * AD-54, AD-55, AD-56, AD-62).
 *
 * What it pins, in `USER`, whose probe schedule specs this spec creates and removes: the list offers New schedule spec and a row action menu, and
 * lists the probe schedule specs under the published headers with the spec as text; New schedule spec creates one from a typed name, schedule and
 * description with the Deployable box ticked, a held name in another letter case refused with the server's sentence in the dialog; Edit opens the same
 * dialog on the selected row with the name read-only and sends only the value that changed; Remove, which types the schedule spec's name and states what
 * removing it does to the items that name it, removes it; and the list passes the structural and contrast checks at 1280 light, 720 light and 1280 dark,
 * with no entry beyond the baseline (DW-1337).
 *
 * Each test arranges the schedule specs it needs through the fixture and removes them when it ends, so every test passes alone and in any order. It
 * shares its page helpers with the Credentials spec (`interop-list-spec.mjs`).
 *
 * **It writes probe schedule specs in `USER`** through `OcuPilot.Test.InteropScheduleFixture`, so it runs on a throwaway only; the `after` hook removes
 * every one, whatever the tests answered. It starts no production.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/interop-schedules.browser-spec.mjs` (after `npm run build` and the bundle copied into the throwaway).
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
const FIXTURE = 'OcuPilot.Test.InteropScheduleFixture';
const CLEARER = 'OcuPilot.Test.InteropLookupFixture';
const HELD = 'OcuProbe2415SHeld';
const NEW = 'OcuProbe2415SNew';
const SPEC1 = 'START:*-*-*T08:00:00,STOP:*-*-*T17:00:00';
const SPEC2 = 'START:*-*-*T09:00:00,STOP:*-*-*T18:00:00';
const LIST_URL = '/ocupilot/interoperability/schedules?ns=USER';
const LIST_ROUTE = 'interoperability/schedules';
const ACTION_PATH = '/api/ocupilot/screens/interop.schedules/action';
const ADD_PATH = '/api/ocupilot/interop/schedules';
/** The cell that holds a schedule spec's name, and the one that holds its spec. */
const NAME_CELL = 0;
const SPEC_CELL = 2;

const { structural, rowOf, rowPresent, waitForCell, rowAction, dialogClosed, fill, openList, openPrimary: openPrimaryWhenReady } = interopListHelpers(config, NAME_CELL);

let browser = null;
let created = false;

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** The stored schedule spec as `spec|description|deployable`, `<absent>` when the namespace does not hold it. */
function stored(name) {
  return probe('SCTEXT', `##class(${FIXTURE}).ScheduleText("${name}")`).value;
}

/** Wait, up to ten probes, until the stored schedule spec reads `<absent>` (`absent` true) or something else; answers the last reading. */
async function settled(name, absent) {
  let last = stored(name);
  for (let tries = 0; (last === '<absent>') !== absent && tries < 10; tries += 1) {
    await new Promise((resolve) => setTimeout(resolve, 500));
    last = stored(name);
  }
  return last;
}

/** Remove every probe schedule spec this spec makes, whatever an earlier step left. */
function drop() {
  const cleared = probe('SCDROP', `$System.Status.IsOK(##class(${CLEARER}).Clear())`);
  assert.equal(cleared.value, '1', `the probe schedule specs are removed: ${cleared.output}`);
}

/** The held schedule spec `name` with `spec` and `description`. */
function arrange(name, spec, description = '') {
  const made = probe('SCMADE', `$System.Status.IsOK(##class(${FIXTURE}).PutSchedule("${name}","${spec}","${description}"))`);
  assert.equal(made.value, '1', `the probe schedule spec ${name} is arranged: ${made.output}`);
}

const field = (name) => `[data-interop-schedule-field="${name}"]`;

/** Open the primary action's dialog on the current list. */
const openPrimary = (page) => openPrimaryWhenReady(page, field('Name'));

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec writes probe schedule specs, so it runs only in a throwaway; ${config.container} is not one`);
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

// Mutation (Rule 19): drop the list descriptor's primary action, regenerate the mirror, rebuild and redeploy -> the command bar offers none and
// the New schedule spec assertion goes red.
test('Schedule specs lists the probe schedule specs under the published headers, shows the spec as text, and the walk passes', async () => {
  drop();
  arrange(HELD, SPEC1, 'held');
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  try {
    await openList(page);
    await rowPresent(page, HELD);
    const headers = await page.$$eval('.ocu-data-table-header-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(
      headers.slice(0, 4),
      [STRINGS.tableColumnName, STRINGS.tableColumnDescription, STRINGS.taskDetailsSchedule, STRINGS.interopDefaultSettingColumnDeployable],
      'the declared headers'
    );
    const row = await rowOf(page, HELD);
    assert.deepEqual(row.slice(0, 3), [HELD, 'held', SPEC1], 'the schedule spec reads its name, description and spec as text');
    assert.equal(await page.$eval('.ocu-command-bar button.ocu-command-bar-primary', (node) => node.textContent.trim()), STRINGS.interopScheduleAddAction, 'the command bar offers New schedule spec');
    assert.deepEqual(await structural(page, LIST_ROUTE), [], 'Schedule specs: no violation beyond the baseline\'s entries');
  } finally {
    await context.close();
    drop();
  }
});

// AC5. Mutation (Rule 19): make the page's Edit send no ScheduleSpec, rebuild and redeploy -> the stored spec never changes and the wait for the
// list's changed cell times out.
test('AC5: New schedule spec adds a schedule spec, Edit changes its spec, and Remove types its name', async () => {
  drop();
  arrange(HELD, SPEC1, 'held');
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
      flag: document.querySelector('[data-interop-schedule-field="Deployable"]').type,
    }));
    assert.equal(opened.title, STRINGS.interopScheduleAddAction, 'the dialog is titled with the published words');
    assert.ok(opened.text.includes(STRINGS.interopScheduleHelp), 'and says what a schedule spec does and how a schedule is written');
    assert.ok(opened.text.includes(STRINGS.interopScheduleDeployableHelp), 'and what Deployable means');
    assert.equal(opened.flag, 'checkbox', 'Deployable is a checkbox');

    await fill(page, field('Name'), HELD.toLowerCase());
    await fill(page, field('ScheduleSpec'), SPEC1);
    await page.click('[data-interop-schedule-confirm]');
    await page.waitForSelector('[data-interop-schedule-reason]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-interop-schedule-reason]', (node) => node.textContent.trim()), STRINGS.interopScheduleRefusalTaken, 'a held name in another letter case is refused with the server\'s sentence');
    assert.equal(stored(HELD.toLowerCase()), '<absent>', 'and nothing is stored under it');

    await fill(page, field('Name'), NEW);
    await fill(page, field('ScheduleSpec'), SPEC1);
    await fill(page, field('Description'), 'browser');
    await page.click(field('Deployable'));
    await page.click('[data-interop-schedule-confirm]');
    await dialogClosed(page);
    await rowPresent(page, NEW);
    assert.deepEqual(Object.keys(adds.at(-1)).sort(), ['Deployable', 'Description', 'Name', 'ScheduleSpec'], 'the Save carries the name, the schedule, the description and the flag');
    assert.equal(adds.at(-1).Deployable, true, 'the flag as a boolean');
    assert.equal(stored(NEW), `${SPEC1}|browser|1`, 'the schedule spec is stored with what was typed');
    assert.equal((await rowOf(page, NEW))[SPEC_CELL], SPEC1, 'and the list shows its spec');

    await rowAction(page, NEW, STRINGS.agentPanelSecretWarningEdit);
    await page.waitForSelector(field('ScheduleSpec'), { visible: true, timeout: config.navigationTimeoutMs });
    const edit = await page.evaluate((name) => ({
      title: document.querySelector('[role="dialog"] .ocu-dialog-title').textContent.trim(),
      readOnly: document.querySelector(name).readOnly,
      held: document.querySelector(name).value,
    }), field('Name'));
    assert.deepEqual(edit, { title: STRINGS.interopCredentialEditTitle.replace('<name>', NEW), readOnly: true, held: NEW }, 'Edit opens the dialog on the row, with the name read-only');
    await fill(page, field('ScheduleSpec'), SPEC2);
    await page.click('[data-interop-schedule-confirm]');
    await dialogClosed(page);
    await waitForCell(page, NEW, SPEC_CELL, SPEC2);
    const editSent = actions.at(-1);
    assert.deepEqual([editSent.action, editSent.id], ['edit', NEW], 'one edit, sent with the row key');
    assert.deepEqual(editSent.values, { ScheduleSpec: SPEC2 }, 'carrying only the value that was changed, and never the name');
    assert.equal(stored(NEW), `${SPEC2}|browser|1`, 'the spec changed and nothing else did');

    await rowAction(page, NEW, STRINGS.actionRemove);
    await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    const dialog = await page.evaluate(() => ({
      title: document.querySelector('[role="dialog"] .ocu-dialog-title').textContent.trim(),
      consequence: document.querySelector('.ocu-typed-name-consequence').textContent.trim(),
    }));
    assert.deepEqual(dialog, { title: `${STRINGS.actionRemove} ${NEW}`, consequence: STRINGS.interopScheduleRemoveConsequence }, 'Remove asks for the name and states what removing it does');
    const sent = actions.length;
    await page.type('.ocu-typed-name-field', NEW);
    await page.keyboard.press('Enter');
    await dialogClosed(page);
    await rowPresent(page, NEW, false);
    assert.equal(actions.length, sent + 1, 'one remove was sent');
    assert.equal(actions.at(-1).action, 'remove', 'a remove');
    assert.equal(await settled(NEW, true), '<absent>', 'the schedule spec is gone from the instance');
    assert.notEqual(stored(HELD), '<absent>', 'and the other schedule spec is untouched');
  } finally {
    await context.close();
    drop();
  }
});

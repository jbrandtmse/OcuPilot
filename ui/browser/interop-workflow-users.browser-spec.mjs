/**
 * Story 24.17 Batch 3a in a real browser, against the throwaway instance: Interoperability's Workflow users, added, edited and removed (AD-5, AD-53,
 * AD-54, AD-55, AD-56, AD-62).
 *
 * What it pins, in `USER`, whose probe workflow users and probe instance users this spec creates and removes: the list offers New workflow user and a
 * row action menu, and lists a probe workflow user under the published headers with its full name and role count; New workflow user offers the
 * instance's users the list does not already hold as a choice of Name, and adds the one chosen with a typed full name; Edit opens the same dialog on
 * the selected row with the name read-only and sends only the value that changed; Remove, which types the workflow user's name and states what
 * removing it does, removes it; and the list passes the structural and contrast checks at 1280 light, 720 light and 1280 dark, with no entry beyond
 * the baseline (DW-1337).
 *
 * Each test arranges the probes it needs through the fixture and removes them when it ends, so every test passes alone and in any order. It shares its
 * page helpers with the Schedule specs spec (`interop-list-spec.mjs`).
 *
 * **It writes probe workflow users in `USER` and probe instance users** through `OcuPilot.Test.InteropWorkflowFixture`, so it runs on a throwaway only;
 * the `after` hook removes every one, whatever the tests answered. It starts no production.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/interop-workflow-users.browser-spec.mjs` (after `npm run build` and the bundle copied into the throwaway).
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
const FIXTURE = 'OcuPilot.Test.InteropWorkflowFixture';
const HELD = 'OcuP2417wBrHeld';
const NEW = 'OcuP2417wBrNew';
const LIST_URL = '/ocupilot/interoperability/workflow-users?ns=USER';
const LIST_ROUTE = 'interoperability/workflow-users';
const ACTION_PATH = '/api/ocupilot/screens/interop.workflowusers/action';
const ADD_PATH = '/api/ocupilot/interop/workflow-users';
/** The cells that hold a workflow user's name, its full name and its role count. */
const NAME_CELL = 0;
const FULL_NAME_CELL = 1;
const ROLES_CELL = 3;

const { structural, rowOf, rowPresent, waitForCell, rowAction, dialogClosed, fill, openList, openPrimary: openPrimaryWhenReady } = interopListHelpers(config, NAME_CELL);

let browser = null;
let created = false;

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** The stored workflow user as `full name|active`, `<absent>` when `USER` does not hold it. */
function stored(name) {
  return probe('WUTEXT', `##class(${FIXTURE}).UserText("USER","${name}")`).value;
}

/** Wait, up to ten probes, until the stored workflow user reads `<absent>` (`absent` true) or something else; answers the last reading. */
async function settled(name, absent) {
  let last = stored(name);
  for (let tries = 0; (last === '<absent>') !== absent && tries < 10; tries += 1) {
    await new Promise((resolve) => setTimeout(resolve, 500));
    last = stored(name);
  }
  return last;
}

/** Remove every probe workflow user and probe instance user this spec makes, whatever an earlier step left. */
function drop() {
  const cleared = probe('WUDROP', `##class(${FIXTURE}).DropProbes()`);
  assert.equal(cleared.value, '1', `the probes are removed: ${cleared.output}`);
}

/** The held workflow user `name`, with its instance user, with `fullName`. */
function arrange(name, fullName) {
  const made = probe('WUMADE', `$System.Status.IsOK(##class(${FIXTURE}).ProbeUser("${name}","${fullName}",1))`);
  assert.equal(made.value, '1', `the probe workflow user ${name} is arranged: ${made.output}`);
}

/** The instance user `name`, which is no workflow user. */
function arrangeInstanceUser(name) {
  const made = probe('WUINST', `$System.Status.IsOK(##class(${FIXTURE}).InstanceUser("${name}"))`);
  assert.equal(made.value, '1', `the probe instance user ${name} is arranged: ${made.output}`);
}

const field = (name) => `[data-interop-workflow-user-field="${name}"]`;

/** Open the primary action's dialog on the current list, once its Name choice has the probe instance user among its options. */
async function openPrimary(page, wanted) {
  await openPrimaryWhenReady(page, field('Name'));
  await page.waitForFunction(
    (selector, name) => Array.from(document.querySelector(selector).options).some((option) => option.value === name),
    { timeout: config.navigationTimeoutMs },
    field('Name'),
    wanted
  );
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec writes probe workflow users and instance users, so it runs only in a throwaway; ${config.container} is not one`);
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
// the New workflow user assertion goes red.
test('Workflow users lists a probe workflow user under the published headers, and the walk passes', async () => {
  drop();
  arrange(HELD, 'Held Hannah');
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  try {
    await openList(page);
    await rowPresent(page, HELD);
    const headers = await page.$$eval('.ocu-data-table-header-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(
      headers.slice(0, 4),
      [STRINGS.tableColumnName, STRINGS.userColumnFullName, STRINGS.interopColumnActive, STRINGS.userColumnRoles],
      'the declared headers'
    );
    const row = await rowOf(page, HELD);
    assert.equal(row[NAME_CELL], HELD, 'the workflow user reads its name');
    assert.equal(row[FULL_NAME_CELL], 'Held Hannah', 'its full name');
    assert.equal(row[ROLES_CELL], '0', 'and the roles it belongs to');
    assert.equal(await page.$eval('.ocu-command-bar button.ocu-command-bar-primary', (node) => node.textContent.trim()), STRINGS.interopWorkflowUserAddAction, 'the command bar offers New workflow user');
    assert.deepEqual(await structural(page, LIST_ROUTE), [], 'Workflow users: no violation beyond the baseline\'s entries');
  } finally {
    await context.close();
    drop();
  }
});

// AC9. Mutation (Rule 19): make the dialog send no full name, rebuild and redeploy -> the stored full name never matches and this goes red.
test('AC9: New workflow user adds an instance user, Edit changes its full name, and Remove types its name', async () => {
  drop();
  arrange(HELD, 'Held Hannah');
  arrangeInstanceUser(NEW);
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
    await openPrimary(page, NEW);
    const opened = await page.evaluate((selector) => ({
      title: document.querySelector('[role="dialog"] .ocu-dialog-title')?.textContent?.trim(),
      text: document.querySelector('[role="dialog"]').textContent,
      kind: document.querySelector(selector).tagName,
      offered: Array.from(document.querySelector(selector).options).map((option) => option.value),
    }), field('Name'));
    assert.equal(opened.title, STRINGS.interopWorkflowUserAddAction, 'the dialog is titled with the published words');
    assert.ok(opened.text.includes(STRINGS.interopWorkflowUserHelp), 'and says what a workflow user is');
    assert.equal(opened.kind, 'SELECT', 'the name is a choice');
    assert.ok(opened.offered.includes(NEW), 'the probe instance user is offered');
    assert.ok(!opened.offered.includes(HELD), 'a user the list already holds is not');

    await page.select(field('Name'), NEW);
    await fill(page, field('FullName'), 'Browser Bea');
    await page.click('[data-interop-workflow-user-confirm]');
    await dialogClosed(page);
    await rowPresent(page, NEW);
    assert.deepEqual(Object.keys(adds.at(-1)).sort(), ['FullName', 'IsActive', 'Name'], 'the Save carries the name, the full name and the flag');
    assert.equal(adds.at(-1).IsActive, true, 'the flag as a boolean');
    assert.equal(stored(NEW), 'Browser Bea|1', 'the workflow user is stored with what was typed');
    assert.equal((await rowOf(page, NEW))[FULL_NAME_CELL], 'Browser Bea', 'and the list shows its full name');

    await rowAction(page, NEW, STRINGS.agentPanelSecretWarningEdit);
    await page.waitForSelector(field('FullName'), { visible: true, timeout: config.navigationTimeoutMs });
    const edit = await page.evaluate((name) => ({
      title: document.querySelector('[role="dialog"] .ocu-dialog-title').textContent.trim(),
      readOnly: document.querySelector(name).readOnly,
      held: document.querySelector(name).value,
    }), field('Name'));
    assert.deepEqual(edit, { title: STRINGS.interopCredentialEditTitle.replace('<name>', NEW), readOnly: true, held: NEW }, 'Edit opens the dialog on the row, with the name read-only');
    await fill(page, field('FullName'), 'Browser Bea Two');
    await page.click('[data-interop-workflow-user-confirm]');
    await dialogClosed(page);
    await waitForCell(page, NEW, FULL_NAME_CELL, 'Browser Bea Two');
    const editSent = actions.at(-1);
    assert.deepEqual([editSent.action, editSent.id], ['edit', NEW], 'one edit, sent with the row key');
    assert.deepEqual(editSent.values, { FullName: 'Browser Bea Two' }, 'carrying only the value that was changed, and never the name');
    assert.equal(stored(NEW), 'Browser Bea Two|1', 'the full name changed and nothing else did');

    await rowAction(page, NEW, STRINGS.actionRemove);
    await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    const dialog = await page.evaluate(() => ({
      title: document.querySelector('[role="dialog"] .ocu-dialog-title').textContent.trim(),
      consequence: document.querySelector('.ocu-typed-name-consequence').textContent.trim(),
    }));
    assert.deepEqual(dialog, { title: `${STRINGS.actionRemove} ${NEW}`, consequence: STRINGS.interopWorkflowUserRemoveConsequence }, 'Remove asks for the name and states what removing it does');
    const sent = actions.length;
    await page.type('.ocu-typed-name-field', NEW);
    await page.keyboard.press('Enter');
    await dialogClosed(page);
    await rowPresent(page, NEW, false);
    assert.equal(actions.length, sent + 1, 'one remove was sent');
    assert.equal(actions.at(-1).action, 'remove', 'a remove');
    assert.equal(await settled(NEW, true), '<absent>', 'the workflow user is gone from the instance');
    assert.notEqual(stored(HELD), '<absent>', 'and the other workflow user is untouched');
  } finally {
    await context.close();
    drop();
  }
});

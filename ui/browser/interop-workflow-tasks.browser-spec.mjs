/**
 * Story 24.17 Batch 4 in a real browser, against the throwaway instance: Interoperability's Workflow tasks and Workflow worklist, with a task assigned
 * to a user and then to Unassigned (AD-5, AD-53, AD-56, AD-62).
 *
 * What it pins, in `USER`, whose probe workflow users, roles and tasks this spec creates and removes: the tasks list lists a probe task under the published
 * headers with its role, status, priority and assignee, offers no primary action and passes the structural and contrast checks at 1280 light, 720 light and
 * 1280 dark, with no entry beyond the baseline (DW-1337), as the worklist does; and the AC9 walk, in which a person opens Assign, chooses the probe user
 * and priority 2, saves, then assigns Unassigned, with the Workflow tasks list showing each assignment, the stored task reading the same and the Workflow worklist
 * showing the user's item and then each active member's.
 *
 * Each test arranges the probes it needs through the fixture and removes them when it ends, so every test passes alone and in any order. It shares its page
 * helpers with the Workflow users spec (`interop-list-spec.mjs`).
 *
 * **It writes probe workflow users, roles and tasks in `USER`** through `OcuPilot.Test.InteropWorkflowTaskFixture`, so it runs on a throwaway only; the `after`
 * hook removes every one, whatever the tests answered. It starts no production.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/interop-workflow-tasks.browser-spec.mjs` (after `npm run build` and the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { interopListHelpers } from './interop-list-spec.mjs';
import { waitForRows } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const FIXTURE = 'OcuPilot.Test.InteropWorkflowTaskFixture';
/** The probe names carry the fixture's marker, which is what `DropProbes` removes by. */
const ROLE = 'OcuP2417wBtRole';
const USER_A = 'OcuP2417wBtAnn';
const USER_B = 'OcuP2417wBtBob';
const TASKS_URL = '/ocupilot/interoperability/workflow-tasks?ns=USER';
const WORKLIST_URL = '/ocupilot/interoperability/workflow-worklist?ns=USER';
const TASKS_ROUTE = 'interoperability/workflow-tasks';
const WORKLIST_ROUTE = 'interoperability/workflow-worklist';
const ACTION_PATH = '/api/ocupilot/screens/interop.workflowtasks/action';
/** The cells of the tasks list: the id, the role, the status, the priority, whether it is complete, the source and the assignee. */
const ROLE_CELL = 1;
const PRIORITY_CELL = 3;
const ASSIGNEE_CELL = 6;
/** The cells of the worklist: the task, the user, the role and the priority. */
const USER_CELL = 1;

const { structural, rowOf, rowPresent, waitForCell, rowAction, dialogClosed, openList } = interopListHelpers(config, 0);

let browser = null;
let created = false;

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** The stored task as `role|assignedTo|priority|status|complete`, `<absent>` when `USER` does not hold it. */
function storedTask(id) {
  return probe('WTTEXT', `##class(${FIXTURE}).TaskText("USER","${id}")`).value;
}

/** The users the task sits on the worklist of, comma-separated, `-` for none. */
function storedItems(id) {
  return probe('WTITEMS', `##class(${FIXTURE}).ItemUsers("USER","${id}")`).value;
}

/** Wait, up to ten probes, until `read` answers `expected`; answers the last reading. */
async function settled(read, expected) {
  let last = read();
  for (let tries = 0; last !== expected && tries < 10; tries += 1) {
    await new Promise((resolve) => setTimeout(resolve, 500));
    last = read();
  }
  return last;
}

/** Remove every probe workflow row and probe instance user this spec makes, whatever an earlier step left. */
function drop() {
  const cleared = probe('WTDROP', `##class(${FIXTURE}).DropProbes()`);
  assert.equal(cleared.value, '1', `the probes are removed: ${cleared.output}`);
}

/** The probe role with two active members, and an unassigned task of it with one worklist item; answers the task's id. */
function arrange() {
  const made = probe(
    'WTARR',
    `$System.Status.IsOK(##class(${FIXTURE}).ProbeUser("${USER_A}","Ann",1,"USER",0))&&$System.Status.IsOK(##class(${FIXTURE}).ProbeUser("${USER_B}","Bob",1,"USER",0))` +
      `&&$System.Status.IsOK(##class(${FIXTURE}).ProbeRole("${ROLE}","USER","browser"))&&$System.Status.IsOK(##class(${FIXTURE}).ProbeMember("${ROLE}","${USER_A}"))` +
      `&&$System.Status.IsOK(##class(${FIXTURE}).ProbeMember("${ROLE}","${USER_B}"))`
  );
  assert.equal(made.value, '1', `the probe users and role are arranged: ${made.output}`);
  const task = probe('WTTASK', `##class(${FIXTURE}).ProbeTask("${ROLE}","","${USER_B}")`);
  assert.match(task.value, /^[1-9][0-9]*$/, `the probe task is arranged: ${task.output}`);
  return task.value;
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec writes probe workflow users, roles and tasks, so it runs only in a throwaway; ${config.container} is not one`);
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

// Mutation (Rule 19): drop the tasks descriptor's Assign row action, regenerate the mirror, rebuild and redeploy -> the walk finds no Assign entry and the AC9 test goes red.
test('Workflow tasks and Workflow worklist list a probe task under the published headers and both pass the structural checks', async () => {
  drop();
  const id = arrange();
  const { context, page } = await signedInAt(browser, config, TASKS_URL, VIEWPORTS.wide);
  try {
    await openList(page);
    await rowPresent(page, id);
    const headers = await page.$$eval('.ocu-data-table-header-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(
      headers.slice(0, 7),
      [
        STRINGS.taskHistoryColumnTaskId,
        STRINGS.userRoleField,
        STRINGS.taskHistoryColumnStatus,
        STRINGS.taskDetailsPriority,
        STRINGS.interopLogColumnCompleted,
        STRINGS.auditEventFieldSource,
        STRINGS.roleEditorTabAssignedTo,
      ],
      'the declared headers'
    );
    const row = await rowOf(page, id);
    assert.deepEqual([row[ROLE_CELL], row[ASSIGNEE_CELL]], [ROLE, STRINGS.tableEmptyValue], 'the task reads its role and no assignee');
    assert.equal(await page.$('.ocu-command-bar button.ocu-command-bar-primary'), null, 'the command bar offers no primary action: a business process makes a task');
    assert.deepEqual(await structural(page, TASKS_ROUTE), [], 'Workflow tasks: no violation beyond the baseline\'s entries');

    await page.goto(new URL(WORKLIST_URL, page.url()).href);
    await waitForRows(page, config.navigationTimeoutMs);
    await rowPresent(page, id);
    const itemHeaders = await page.$$eval('.ocu-data-table-header-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(
      itemHeaders.slice(0, 6),
      [
        STRINGS.taskHistoryColumnTaskId,
        STRINGS.processColumnUser,
        STRINGS.userRoleField,
        STRINGS.taskDetailsPriority,
        STRINGS.journalColumnCreated,
        STRINGS.interopWorkflowWorklistColumnAge,
      ],
      'the worklist\'s declared headers'
    );
    assert.equal((await rowOf(page, id))[USER_CELL], USER_B, 'the item reads the user it was sent to');
    assert.deepEqual(await structural(page, WORKLIST_ROUTE), [], 'Workflow worklist: no violation beyond the baseline\'s entries');
  } finally {
    await context.close();
    drop();
  }
});

// AC9. Mutation (Rule 19): make the task dialog send no priority, rebuild and redeploy -> the stored priority reads 0 and this goes red.
test('AC9: a person assigns a task to a user at priority 2, then to Unassigned, and the list, the instance and the worklist show each', async () => {
  drop();
  const id = arrange();
  const { context, page } = await signedInAt(browser, config, TASKS_URL, VIEWPORTS.wide);
  const actions = [];
  page.on('request', (request) => {
    if (request.method() !== 'POST') return;
    if (new URL(request.url()).pathname === ACTION_PATH) actions.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    await openList(page);
    await rowPresent(page, id);

    // Assign opens the dialog, which offers Unassigned and the active workflow users and priorities 1 to 5.
    await rowAction(page, id, STRINGS.webAppRoleAssign, ROLE);
    await page.waitForSelector('[data-interop-workflow-task-field="User"] option[value="' + USER_A + '"]', { timeout: config.navigationTimeoutMs });
    const opened = await page.evaluate(() => ({
      title: document.querySelector('[role="dialog"] .ocu-dialog-title')?.textContent?.trim(),
      users: Array.from(document.querySelectorAll('[data-interop-workflow-task-field="User"] option')).map((option) => option.value),
      consequence: document.querySelector('[data-interop-workflow-task-consequence]')?.textContent?.trim(),
    }));
    assert.equal(opened.title, STRINGS.interopWorkflowTaskAssignTitle, 'the dialog is titled with the published words');
    assert.deepEqual(opened.users.slice(0, 3), ['', USER_A, USER_B], 'it offers Unassigned and the active workflow users');
    await page.select('[data-interop-workflow-task-field="User"]', USER_A);
    await page.select('[data-interop-workflow-task-field="Priority"]', '2');
    const chosen = await page.$eval('[data-interop-workflow-task-consequence]', (node) => node.textContent.trim());
    assert.equal(chosen, STRINGS.interopWorkflowTaskAssignConsequence, 'it says an assigned task leaves every other worklist');
    const sent = actions.length;
    await page.click('[data-interop-workflow-task-confirm]');
    await dialogClosed(page);
    assert.equal(actions.length, sent + 1, 'one assign was sent');
    assert.deepEqual(actions.at(-1), { action: 'assign', id, values: { User: USER_A, Priority: '2' } }, 'with the user and the priority as text');
    await waitForCell(page, id, ASSIGNEE_CELL, USER_A);
    await waitForCell(page, id, PRIORITY_CELL, '2');
    assert.equal(await settled(() => storedTask(id), `${ROLE}|${USER_A}|2|Assigned|0`), `${ROLE}|${USER_A}|2|Assigned|0`, 'the task is stored as assigned at priority 2');
    assert.equal(storedItems(id), USER_A, 'and sits on the assignee\'s worklist alone');

    // The worklist shows the assignee's item.
    await page.goto(new URL(WORKLIST_URL, page.url()).href);
    await waitForRows(page, config.navigationTimeoutMs);
    await rowPresent(page, id);
    assert.equal((await rowOf(page, id))[USER_CELL], USER_A, 'the worklist shows the assignee\'s item');

    // Back on the tasks list, Unassigned sends the task to every active member.
    await page.goto(new URL(TASKS_URL, page.url()).href);
    await openList(page);
    await rowPresent(page, id);
    await rowAction(page, id, STRINGS.webAppRoleAssign, ROLE);
    await page.waitForSelector('[data-interop-workflow-task-field="User"] option[value="' + USER_B + '"]', { timeout: config.navigationTimeoutMs });
    await page.select('[data-interop-workflow-task-field="User"]', '');
    const unassigning = await page.$eval('[data-interop-workflow-task-consequence]', (node) => node.textContent.trim());
    assert.equal(unassigning, STRINGS.interopWorkflowTaskUnassignConsequence, 'it says an unassigned task goes to every active member');
    const second = actions.length;
    await page.click('[data-interop-workflow-task-confirm]');
    await dialogClosed(page);
    assert.equal(actions.length, second + 1, 'one unassign was sent');
    assert.deepEqual(actions.at(-1), { action: 'assign', id, values: { User: '' } }, 'with an empty user and no priority, which did not change');
    await waitForCell(page, id, ASSIGNEE_CELL, STRINGS.tableEmptyValue);
    assert.equal(await settled(() => storedTask(id), `${ROLE}||2|Unassigned|0`), `${ROLE}||2|Unassigned|0`, 'the task is stored as unassigned and keeps its priority');
    assert.equal(await settled(() => storedItems(id), `${USER_A},${USER_B}`), `${USER_A},${USER_B}`, 'and sits on each active member\'s worklist');

    await page.goto(new URL(WORKLIST_URL, page.url()).href);
    await waitForRows(page, config.navigationTimeoutMs);
    await rowPresent(page, id);
    const users = await page.evaluate((wanted) => {
      const rows = Array.from(document.querySelectorAll('[role="row"]')).filter((row) => row.querySelectorAll('[role="gridcell"]')[0]?.textContent.trim() === wanted);
      return rows.map((row) => row.querySelectorAll('[role="gridcell"]')[1].textContent.trim()).sort();
    }, id);
    assert.deepEqual(users, [USER_A, USER_B], 'the worklist shows each active member\'s item');
  } finally {
    await context.close();
    drop();
  }
});

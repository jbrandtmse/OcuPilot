/**
 * Story 24.17 Batch 3b in a real browser, against the throwaway instance: Interoperability's Workflow roles and Role members, added, edited and
 * removed (AD-5, AD-53, AD-54, AD-55, AD-56, AD-62).
 *
 * What it pins, in `USER`, whose probe workflow roles, workflow users and instance users this spec creates and removes: the roles list offers New
 * workflow role and lists a probe role under the published headers with its description, capacity and member count, and passes the structural and
 * contrast checks at 1280 light, 720 light and 1280 dark, with no entry beyond the baseline (DW-1337), as its members list does; and the AC10 walk, in
 * which a person adds a role, opens its members from the role's name, adds the probe workflow user at rank 2, removes the member, which warns first
 * and types no name, goes back to the roles list, and removes the role, typing its name, with each screen and the stored rows showing each change.
 *
 * Each test arranges the probes it needs through the fixture and removes them when it ends, so every test passes alone and in any order. It shares its
 * page helpers with the Workflow users spec (`interop-list-spec.mjs`).
 *
 * **It writes probe workflow roles, workflow users and instance users in `USER`** through `OcuPilot.Test.InteropWorkflowFixture`, so it runs on a
 * throwaway only; the `after` hook removes every one, whatever the tests answered. It starts no production.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/interop-workflow-roles.browser-spec.mjs` (after `npm run build` and the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { interopListHelpers } from './interop-list-spec.mjs';
import { clickRowCentre, waitForRows } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const FIXTURE = 'OcuPilot.Test.InteropWorkflowFixture';
/** The probe names carry the fixture's marker, which is what `DropProbes` removes by. */
const HELD = 'OcuP2417wBrHeld';
const ROLE = 'OcuP2417wBrRole';
const MEMBER_USER = 'OcuP2417wBrMember';
const OTHER_ROLE = 'OcuP2417wBrOther';
const LIST_URL = '/ocupilot/interoperability/workflow-roles?ns=USER';
const LIST_ROUTE = 'interoperability/workflow-roles';
const MEMBERS_ROUTE = 'interoperability/workflow-roles/members';
const ROLE_ADD_PATH = '/api/ocupilot/interop/workflow-roles';
const MEMBER_ADD_PATH = '/api/ocupilot/interop/workflow-members';
const ROLE_ACTION_PATH = '/api/ocupilot/screens/interop.workflowroles/action';
const MEMBER_ACTION_PATH = '/api/ocupilot/screens/interop.workflowmembers/action';
/** The cells of the roles list: the name, the description, the capacity and the member count. */
const NAME_CELL = 0;
const DESCRIPTION_CELL = 1;
const CAPACITY_CELL = 2;
const MEMBERS_CELL = 3;
/** The cells of the members list that follow its first, the user: the full name, the rank, the title and the active flag. */
const RANK_CELL = 2;
const TITLE_CELL = 3;

/** Both lists key their rows by the first cell: the role's name, and the member's user. */
const { structural, rowOf, rowPresent, waitForCell, rowAction, dialogClosed, fill, openList, openPrimary } = interopListHelpers(config, NAME_CELL);

let browser = null;
let created = false;

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** The stored workflow role as `description|capacity`, `<absent>` when `USER` does not hold it. */
function storedRole(name) {
  return probe('WRTEXT', `##class(${FIXTURE}).RoleText("USER","${name}")`).value;
}

/** The stored membership as `rank|title`, `<absent>` when the user is no member of the role. */
function storedMember(role, user) {
  return probe('WMTEXT', `##class(${FIXTURE}).MemberText("USER","${role}","${user}")`).value;
}

/** Wait, up to ten probes, until `read` answers `<absent>` (`absent` true) or something else; answers the last reading. */
async function settled(read, absent) {
  let last = read();
  for (let tries = 0; (last === '<absent>') !== absent && tries < 10; tries += 1) {
    await new Promise((resolve) => setTimeout(resolve, 500));
    last = read();
  }
  return last;
}

/** Remove every probe workflow row and probe instance user this spec makes, whatever an earlier step left. */
function drop() {
  const cleared = probe('WRDROP', `##class(${FIXTURE}).DropProbes()`);
  assert.equal(cleared.value, '1', `the probes are removed: ${cleared.output}`);
}

/** The held workflow user `name`, with its instance user. */
function arrangeUser(name) {
  const made = probe('WRUSER', `$System.Status.IsOK(##class(${FIXTURE}).ProbeUser("${name}","Probe ${name}",1))`);
  assert.equal(made.value, '1', `the probe workflow user ${name} is arranged: ${made.output}`);
}

/** The held workflow role `name`, with `description` and `capacity`. */
function arrangeRole(name, description, capacity) {
  const made = probe('WRROLE', `$System.Status.IsOK(##class(${FIXTURE}).ProbeRole("${name}","USER","${description}","${capacity}"))`);
  assert.equal(made.value, '1', `the probe workflow role ${name} is arranged: ${made.output}`);
}

const roleField = (name) => `[data-interop-workflow-role-field="${name}"]`;
const memberField = (name) => `[data-interop-workflow-member-field="${name}"]`;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec writes probe workflow roles, workflow users and instance users, so it runs only in a throwaway; ${config.container} is not one`);
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

// Mutation (Rule 19): drop the roles descriptor's primary action, regenerate the mirror, rebuild and redeploy -> the command bar offers none and the
// New workflow role assertion goes red; make `childListFor` answer null for the list -> the name cell opens nothing and the members leg goes red.
test('Workflow roles lists a probe role under the published headers, opens its members, and both walks pass', async () => {
  drop();
  arrangeUser(HELD);
  arrangeRole(ROLE, 'Browser role', '40');
  const member = probe('WRMEMBER', `$System.Status.IsOK(##class(${FIXTURE}).ProbeMember("${ROLE}","${HELD}","USER",2,"Browser lead"))`);
  assert.equal(member.value, '1', `the probe member is arranged: ${member.output}`);
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  try {
    await openList(page);
    await rowPresent(page, ROLE);
    const headers = await page.$$eval('.ocu-data-table-header-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(
      headers.slice(0, 4),
      [STRINGS.tableColumnName, STRINGS.tableColumnDescription, STRINGS.promptGroupCapacity, STRINGS.roleEditorTabMembers],
      'the declared headers'
    );
    const row = await rowOf(page, ROLE);
    assert.deepEqual([row[NAME_CELL], row[DESCRIPTION_CELL], row[CAPACITY_CELL], row[MEMBERS_CELL]], [ROLE, 'Browser role', '40', '1'], 'the role reads its name, description, capacity and members');
    assert.equal(await page.$eval('.ocu-command-bar button.ocu-command-bar-primary', (node) => node.textContent.trim()), STRINGS.interopWorkflowRoleAddAction, 'the command bar offers New workflow role');
    assert.deepEqual(await structural(page, LIST_ROUTE), [], 'Workflow roles: no violation beyond the baseline\'s entries');

    await clickRowCentre(page, { text: ROLE, link: true });
    await page.waitForFunction((suffix) => new URL(window.location.href).pathname.includes(suffix), { timeout: config.navigationTimeoutMs }, `/${MEMBERS_ROUTE}/`);
    await waitForRows(page, config.navigationTimeoutMs);
    await rowPresent(page, HELD);
    const memberHeaders = await page.$$eval('.ocu-data-table-header-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(
      memberHeaders.slice(0, 5),
      [STRINGS.processColumnUser, STRINGS.userColumnFullName, STRINGS.interopWorkflowMemberColumnRank, STRINGS.interopPartnerFieldTitle, STRINGS.interopColumnActive],
      'the members\' declared headers'
    );
    const held = await rowOf(page, HELD);
    assert.deepEqual([held[RANK_CELL], held[TITLE_CELL]], ['2', 'Browser lead'], 'the member reads its rank and title');
    assert.equal(await page.$eval('.ocu-command-bar button.ocu-command-bar-primary', (node) => node.textContent.trim()), STRINGS.interopWorkflowMemberAddAction, 'the command bar offers Add member');
    assert.deepEqual(await structural(page, MEMBERS_ROUTE), [], 'Role members: no violation beyond the baseline\'s entries');
  } finally {
    await context.close();
    drop();
  }
});

// AC10. Mutation (Rule 19): make the member dialog send no rank, rebuild and redeploy -> the stored rank reads 3 and this goes red.
test('AC10: a person adds a role, adds a user to it at rank 2, removes the member and removes the role, typing its name', async () => {
  drop();
  arrangeUser(MEMBER_USER);
  // The list waits for a first row, so the namespace holds one role besides the one the walk adds.
  arrangeRole(OTHER_ROLE, 'Browser other', '5');
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const roleAdds = [];
  const memberAdds = [];
  const memberActions = [];
  const roleActions = [];
  page.on('request', (request) => {
    if (request.method() !== 'POST') return;
    const path = new URL(request.url()).pathname;
    const body = JSON.parse(request.postData() ?? '{}');
    if (path === ROLE_ADD_PATH) roleAdds.push(body);
    if (path === MEMBER_ADD_PATH) memberAdds.push(body);
    if (path === MEMBER_ACTION_PATH) memberActions.push(body);
    if (path === ROLE_ACTION_PATH) roleActions.push(body);
  });
  try {
    await openList(page);

    // The role is added through New workflow role.
    await openPrimary(page, roleField('Name'));
    const opened = await page.evaluate(() => ({
      title: document.querySelector('[role="dialog"] .ocu-dialog-title')?.textContent?.trim(),
      text: document.querySelector('[role="dialog"]').textContent,
    }));
    assert.equal(opened.title, STRINGS.interopWorkflowRoleAddAction, 'the dialog is titled with the published words');
    assert.ok(opened.text.includes(STRINGS.interopWorkflowRoleHelp), 'and says what a workflow role is');
    await fill(page, roleField('Name'), ROLE);
    await fill(page, roleField('Description'), 'Browser role');
    await fill(page, roleField('Capacity'), '40');
    await page.click('[data-interop-workflow-role-confirm]');
    await dialogClosed(page);
    await rowPresent(page, ROLE);
    assert.deepEqual(roleAdds.at(-1), { Name: ROLE, Description: 'Browser role', Capacity: 40 }, 'the Save carries the name, the description and the capacity as a number');
    assert.equal(storedRole(ROLE), 'Browser role|40', 'the role is stored with what was typed');
    assert.deepEqual(
      [(await rowOf(page, ROLE))[DESCRIPTION_CELL], (await rowOf(page, ROLE))[MEMBERS_CELL]],
      ['Browser role', '0'],
      'and the list shows it with no members'
    );

    // The role's name opens its members, where the user is added at rank 2. A reload drops the Changed marker the add left on the row, so its first cell reads the name alone.
    await page.reload();
    await openList(page);
    await rowPresent(page, ROLE);
    await clickRowCentre(page, { text: ROLE, link: true });
    await page.waitForFunction((suffix) => new URL(window.location.href).pathname.includes(suffix), { timeout: config.navigationTimeoutMs }, `/${MEMBERS_ROUTE}/`);
    await openPrimary(page, memberField('User'));
    await page.waitForFunction(
      (selector, name) => Array.from(document.querySelector(selector).options).some((option) => option.value === name),
      { timeout: config.navigationTimeoutMs },
      memberField('User'),
      MEMBER_USER
    );
    const dialog = await page.evaluate(() => ({
      title: document.querySelector('[role="dialog"] .ocu-dialog-title')?.textContent?.trim(),
      text: document.querySelector('[role="dialog"]').textContent,
    }));
    assert.equal(dialog.title, STRINGS.interopWorkflowMemberAddAction, 'the member dialog is titled with the published words');
    assert.ok(dialog.text.includes(STRINGS.interopWorkflowMemberHelp), 'and says what a rank is');
    await page.select(memberField('User'), MEMBER_USER);
    await page.select(memberField('Ranking'), '2');
    await page.click('[data-interop-workflow-member-confirm]');
    await dialogClosed(page);
    await rowPresent(page, MEMBER_USER);
    assert.deepEqual(memberAdds.at(-1), { Role: ROLE, User: MEMBER_USER, Ranking: 2 }, 'the Save carries the route\'s role, the chosen user and the rank as a number');
    assert.equal(await settled(() => storedMember(ROLE, MEMBER_USER), false), '2|', 'the membership is stored with rank 2 and no title');
    assert.equal((await rowOf(page, MEMBER_USER))[RANK_CELL], '2', 'and the members list shows its rank');

    // The roles list counts the member.
    await page.goBack();
    await openList(page);
    await waitForCell(page, ROLE, MEMBERS_CELL, '1');

    // The member is removed after a warning that asks for no name.
    await page.goForward();
    await waitForRows(page, config.navigationTimeoutMs);
    await rowPresent(page, MEMBER_USER);
    await rowAction(page, MEMBER_USER, STRINGS.actionRemove);
    await page.waitForSelector('app-warning-dialog [role="dialog"] .ocu-warning-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    const warning = await page.evaluate(() => ({
      consequence: document.querySelector('.ocu-warning-consequence').textContent.trim(),
      typedName: document.querySelector('.ocu-typed-name-field') !== null,
    }));
    assert.deepEqual(warning, { consequence: STRINGS.interopWorkflowMemberRemoveConsequence, typedName: false }, 'Remove states what removing a member does and asks for no name');
    const sent = memberActions.length;
    await page.click('[role="dialog"] .ocu-dialog-actions .ocu-button-primary');
    await dialogClosed(page);
    await rowPresent(page, MEMBER_USER, false);
    assert.equal(memberActions.length, sent + 1, 'one remove was sent');
    assert.deepEqual(memberActions.at(-1), { action: 'remove', id: `${ROLE}\u0001${MEMBER_USER}` }, 'with the row\'s composite key');
    assert.equal(await settled(() => storedMember(ROLE, MEMBER_USER), true), '<absent>', 'the membership is gone from the instance');

    // The role is removed after typing its name.
    await page.goBack();
    await openList(page);
    await waitForCell(page, ROLE, MEMBERS_CELL, '0');
    await rowAction(page, ROLE, STRINGS.actionRemove);
    await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    const removal = await page.evaluate(() => ({
      title: document.querySelector('[role="dialog"] .ocu-dialog-title').textContent.trim(),
      consequence: document.querySelector('.ocu-typed-name-consequence').textContent.trim(),
    }));
    assert.deepEqual(removal, { title: `${STRINGS.actionRemove} ${ROLE}`, consequence: STRINGS.interopWorkflowRoleRemoveConsequence }, 'Remove asks for the name and states what removing the role does');
    const roleSent = roleActions.length;
    await page.type('.ocu-typed-name-field', ROLE);
    await page.keyboard.press('Enter');
    await dialogClosed(page);
    await rowPresent(page, ROLE, false);
    assert.equal(roleActions.length, roleSent + 1, 'one role remove was sent');
    assert.deepEqual(roleActions.at(-1), { action: 'remove', id: ROLE }, 'with the row key once the name matched');
    assert.equal(await settled(() => storedRole(ROLE), true), '<absent>', 'the role is gone from the instance');
  } finally {
    await context.close();
    drop();
  }
});

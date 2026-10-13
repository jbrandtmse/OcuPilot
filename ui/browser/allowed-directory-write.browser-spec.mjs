/**
 * The Allowed directories screen's Add, Change and Remove in a real browser, against the throwaway instance (Story 18.46): with
 * the write's governance key at its shipped setting every action is drawn off with the instance's sentence and a click opens
 * nothing (C2); with the key enabled a person adds a directory to an unrestricted list, changes it, removes it, and removes the
 * last entry through the screen's dialogs and `POST /allowed-directories`, and the list re-reads each time (C1), the
 * unrestricted manager-directory row refuses Change and Remove with the fallback sentence (C3), and the emptied list's empty
 * state says no file or directory field can choose a location (C4). On a restricted list an Add words the plain consequence and
 * Cancel sends nothing, and an Add the route refuses puts the instance's sentence on the list's banner and changes nothing (C1).
 *
 * **It changes the instance's allow-list and governance policy**, so it runs on a throwaway only. It clears the purpose before
 * and after, makes and removes two probe directories under the manager directory, reads the key's setting before it runs and
 * puts the policy back after, and creates no security principal. A sign-in puts the policy back to the default, so the
 * enabled leg stores the key after it signs in and re-enters the screen, which reads the verdict again.
 *
 * Every step waits for the answer it acts on: the verdict's GET before the actions are read, clicked or counted, the rows
 * or the empty state after each write.
 *
 * Run: `node --test --test-concurrency=1 browser/allowed-directory-write.browser-spec.mjs` (after `npm run build`, the bundle
 * copied into the throwaway, and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { allowList, instanceValue, makeDirectory, removeDirectory } from './allow-list-spec.mjs';
import { ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { authHeader, signedInAt } from './panel-spec.mjs';
import { governanceRowVersion, resetGovernancePolicy, setGovernanceKey } from './preferences-reset.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { clearGovernancePolicy, escapeOs } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const LIST_URL = '/ocupilot/security/allowed-directories?ns=HSCUSTOM';
const OTHER_PATH = '/ocupilot/security/ssl?ns=HSCUSTOM';
const STATE_PATH = '/api/ocupilot/allowed-directories';
const READ_PATH = '/api/ocupilot/screens/security.alloweddirectories/read';
const GOVERNANCE_PATH = '/api/ocupilot/agent/governance';
const KEY = 'security.alloweddirectories.update';

let browser = null;
// Whether no policy was stored before this file ran: the resets save a default row, which the end clears.
let noStoredPolicy = false;
let manager = '';
let probeA = '';
let probeB = '';

before(async () => {
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec changes the instance's allow-list and policy, so it runs only in a throwaway; ${config.container} is not one`);
  noStoredPolicy = (await governanceRowVersion()) === 0;
  await resetGovernancePolicy();
  const read = await fetch(`${config.origin}${GOVERNANCE_PATH}`, { headers: { Authorization: authHeader(config) } });
  const row = (await read.json()).keys.find((entry) => entry.key === KEY);
  assert.equal(row?.setting, 'inherit', `the key reads inherit once the policy is put back to the default: ${JSON.stringify(row)}`);
  allowList(config, 'Clear()');
  manager = (await routeRows())[0].Directory;
  const root = instanceValue(config, '##class(%File).NormalizeDirectory($System.Util.ManagerDirectory())');
  probeA = `${root}ocuprobe1846a/`;
  probeB = `${root}ocuprobe1846b/`;
  makeDirectory(config, probeA);
  makeDirectory(config, probeB);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    if (/-ci$/.test(config.container)) {
      allowList(config, 'Clear()');
      for (const directory of [probeA, probeB]) if (directory !== '') removeDirectory(config, directory);
      await resetGovernancePolicy();
      if (noStoredPolicy) {
        clearGovernancePolicy(config.container);
        assert.equal(await governanceRowVersion(), 0, 'no governance policy is stored, as before this file ran');
      }
    }
  }
});

/** The rows the screen's own read answers, through the route the page reads. */
async function routeRows() {
  const answer = await fetch(`${config.origin}${READ_PATH}?maxRows=1000&ns=HSCUSTOM`, { headers: { Authorization: authHeader(config) } });
  assert.equal(answer.status, 200, `the read route answers (HTTP ${answer.status})`);
  return (await answer.json()).rows;
}

/** The verdict the instance answers now, over the route the screen reads it from. */
async function verdictNow() {
  const answer = await fetch(`${config.origin}${STATE_PATH}`, { headers: { Authorization: authHeader(config) } });
  assert.equal(answer.status, 200, `the verdict answers (HTTP ${answer.status})`);
  return answer.json();
}

/** What a page asked of the allow-list route: the verdicts whose answers it received whole, and the writes it sent. */
function watching() {
  const log = { verdicts: [], posts: [] };
  const attach = (page) => {
    page.on('requestfinished', (request) => {
      if (request.method() === 'GET' && new URL(request.url()).pathname === STATE_PATH) log.verdicts.push(request.response()?.status() ?? 0);
    });
    page.on('request', (request) => {
      if (request.method() === 'POST' && new URL(request.url()).pathname === STATE_PATH) log.posts.push(request.postData());
    });
  };
  return { log, attach };
}

/** Wait until the page has been answered `count` verdicts, then for the actions to be drawn from the last. */
async function verdictAnswered(page, log, count) {
  const deadline = Date.now() + config.navigationTimeoutMs;
  while (log.verdicts.length < count) {
    assert.ok(Date.now() < deadline, `the verdict was answered ${count} time(s); it was answered ${log.verdicts.length}`);
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  assert.equal(log.verdicts[count - 1], 200, 'and the last answer was 200');
  await frames(page);
}

/** Wait two animation frames, which is when a render a click or an answer caused has been drawn. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/** Leave the screen for another and come back, which reads the verdict again, and wait for its rows and its answer. */
async function reenter(page, log) {
  const answered = log.verdicts.length;
  await page.evaluate((path) => {
    history.pushState(null, '', path);
    dispatchEvent(new PopStateEvent('popstate', { state: null }));
  }, OTHER_PATH);
  await page.waitForFunction(() => location.pathname.endsWith('/security/ssl'), { timeout: config.navigationTimeoutMs });
  await page.goBack();
  await page.waitForFunction(() => location.pathname.endsWith('/security/allowed-directories'), { timeout: config.navigationTimeoutMs });
  await waitForRows(page, config.navigationTimeoutMs);
  await verdictAnswered(page, log, answered + 1);
}

/** The command bar's Add, Change and Remove as drawn: label, `aria-disabled` and the sentence they are described by. */
function bar(page) {
  return page.evaluate((labels) => {
    const describe = (button) => {
      const id = button.getAttribute('aria-describedby');
      return {
        label: button.textContent.trim(),
        disabled: button.getAttribute('aria-disabled'),
        reason: id === null ? '' : (document.getElementById(id)?.textContent.trim() ?? ''),
      };
    };
    return [...document.querySelectorAll('.ocu-command-bar-primary, .ocu-command-bar-action')]
      .filter((button) => labels.includes(button.textContent.trim()))
      .map(describe);
  }, [STRINGS.allowedDirectoryAddAction, STRINGS.allowedDirectoryChangeAction, STRINGS.actionRemove]);
}

/** Select the row for `directory` with a real pointer, and wait until the table and the command bar have taken the selection. */
async function select(page, directory) {
  await clickRowCentre(page, { text: directory, cell: 2 });
  await page.waitForFunction(
    (selector, wanted) =>
      [...document.querySelectorAll(selector)].some((row) => row.getAttribute('aria-selected') === 'true' && row.querySelector('[role="gridcell"]')?.textContent.trim() === wanted),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    directory
  );
  await page.waitForFunction(
    (unselected) => ![...document.querySelectorAll('.ocu-command-bar-action')].some((button) => document.getElementById(button.getAttribute('aria-describedby') ?? '')?.textContent.trim() === unselected),
    { timeout: config.navigationTimeoutMs },
    STRINGS.privilegeSelectRowFirst
  );
}

/** Click the command bar's control named `label` with a real pointer. */
async function press(page, label) {
  const handle = await page.evaluateHandle(
    (wanted) => [...document.querySelectorAll('.ocu-command-bar-primary, .ocu-command-bar-action')].find((button) => button.textContent.trim() === wanted) ?? null,
    label
  );
  const element = handle.asElement();
  assert.notEqual(element, null, `the command bar draws ${label}`);
  await element.click();
}

/** Wait until the table shows exactly `expected`, and require the instance's own read to say the same. */
async function rowsAre(page, expected, description) {
  await page.waitForFunction(
    (selector, wanted) =>
      JSON.stringify(
        [...document.querySelectorAll(selector)].map((row) => [...row.querySelectorAll('[role="gridcell"]')].slice(0, 2).map((cell) => cell.textContent.trim()))
      ) === wanted,
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    JSON.stringify(expected)
  );
  const held = (await routeRows()).map((row) => [row.Directory, row.Restricted ? STRINGS.tableStatusYes : STRINGS.tableStatusNo]);
  assert.deepEqual(held, expected, `${description}: the instance's own read says the same`);
}

/** Wait for the open dialog, and answer its title and the text of its consequence. */
async function openDialog(page) {
  await page.waitForSelector('[role="dialog"]', { timeout: config.navigationTimeoutMs });
  return page.evaluate(() => ({
    title: document.querySelector('.ocu-dialog-title')?.textContent.trim() ?? '',
    consequence: (document.querySelector('.ocu-warning-consequence') ?? document.querySelector('.ocu-typed-name-consequence'))?.textContent.trim() ?? '',
    field: document.querySelector('[data-slot="field"] label')?.textContent.trim() ?? '',
  }));
}

async function dialogClosed(page) {
  await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
}

/** Wait until the dialog button `selector` has been released (no longer `aria-disabled`) by what was typed, then press it. */
async function pressWhenReleased(page, selector) {
  await page.waitForFunction((target) => document.querySelector(target)?.getAttribute('aria-disabled') !== 'true', { timeout: config.navigationTimeoutMs }, selector);
  await page.click(selector);
  await dialogClosed(page);
}

/** Type `value` into the warning dialog's one field and press Proceed once the field has released it. */
async function proceedWith(page, value) {
  await page.type('[data-slot="field"] input', value);
  await pressWhenReleased(page, '.ocu-dialog-actions .ocu-button-primary');
}

/** Type `name` into the typed-name dialog's field and press the destructive button once the exact name has released it. */
async function removeWith(page, name) {
  await page.type('.ocu-typed-name-field', name);
  await pressWhenReleased(page, '.ocu-dialog-actions .ocu-button-destructive');
}

test('C2: with the key at its shipped setting the three actions are drawn off with the instance\u2019s sentence, and a click opens nothing', async () => {
  // Mutation (Rule 19): drop the `ScreenActions.register` reason argument in `allowed-directory-dialogs.ts`, rebuild and redeploy
  // -> the actions are drawn on and the aria-disabled step goes red; make `ScreenActions.run` ignore the reason -> the actions are
  // still drawn off, the click opens the Add dialog and the "opens nothing" step goes red.
  allowList(config, 'Clear()');
  const { log, attach } = watching();
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide, null, attach);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await verdictAnswered(page, log, 1);
    const verdict = await verdictNow();
    assert.deepEqual([verdict.enabled, verdict.code], [false, 'ALLOWLIST.OFF'], `the instance answers the key off: ${JSON.stringify(verdict)}`);
    assert.equal(verdict.reason, STRINGS.allowListRefusalOff, 'in the sentence the client publishes for the code');
    await select(page, manager);

    const drawn = await bar(page);
    assert.deepEqual(
      drawn.map((control) => control.label),
      [STRINGS.allowedDirectoryAddAction, STRINGS.allowedDirectoryChangeAction, STRINGS.actionRemove],
      'the primary action and the two row actions are drawn'
    );
    for (const control of drawn) {
      assert.equal(control.disabled, 'true', `${control.label} is aria-disabled`);
      assert.equal(control.reason, verdict.reason, `${control.label} is described by the instance's sentence, ahead of the fallback row's own`);
    }
    for (const label of [STRINGS.allowedDirectoryAddAction, STRINGS.allowedDirectoryChangeAction, STRINGS.actionRemove]) {
      await press(page, label);
      await frames(page);
      assert.equal(await page.$('[role="dialog"]'), null, `${label} opens nothing`);
    }
  } finally {
    await context.close();
  }
});

test('C1, C3, C4: with the key enabled a person adds, changes and removes entries through the dialogs, the fallback row refuses, and an emptied list says so', async () => {
  // Mutation (Rule 19): drop the `OWN_ROUTES` entry in `screen-action-handler.ts`, rebuild and redeploy -> the Add is sent to the
  // screen action route, answered 404, and the Add step goes red; set `emptyStateKey` back to `allowedDirectoriesEmpty` in
  // `AllowedDirectoryList.cls`, run the mirror, rebuild and redeploy -> the empty-state step goes red.
  allowList(config, 'Clear()');
  const { log, attach } = watching();
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide, null, attach);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await verdictAnswered(page, log, 1);
    await setGovernanceKey(KEY, 'enabled');
    await reenter(page, log);
    assert.equal((await verdictNow()).enabled, true, 'the instance answers the key enabled');

    // C3: the unrestricted list's one row is the manager directory, which cannot be changed or removed.
    await rowsAre(page, [[manager, STRINGS.tableStatusNo]], 'an unrestricted list shows the manager directory alone');
    await select(page, manager);
    const fallback = await bar(page);
    assert.deepEqual(fallback.find((control) => control.label === STRINGS.allowedDirectoryAddAction), { label: STRINGS.allowedDirectoryAddAction, disabled: null, reason: '' }, 'Add is drawn on');
    for (const label of [STRINGS.allowedDirectoryChangeAction, STRINGS.actionRemove]) {
      const control = fallback.find((entry) => entry.label === label);
      assert.equal(control?.disabled, 'true', `${label} is aria-disabled on the fallback row`);
      assert.equal(control?.reason, STRINGS.allowListRefusalFallback, `and names the fallback sentence`);
      await press(page, label);
      await frames(page);
      assert.equal(await page.$('[role="dialog"]'), null, `${label} opens nothing`);
    }

    // C1: Add A. The list was unrestricted, so the dialog says the add restricts it.
    await press(page, STRINGS.allowedDirectoryAddAction);
    const add = await openDialog(page);
    assert.deepEqual(add, { title: STRINGS.allowedDirectoryAddAction, consequence: STRINGS.allowedDirectoryAddRestricts, field: STRINGS.lockColumnDirectory });
    assert.deepEqual(log.posts, [], 'nothing is sent before the dialog is confirmed');
    await proceedWith(page, probeA);
    await rowsAre(page, [[manager, STRINGS.tableStatusYes], [probeA, STRINGS.tableStatusYes]], 'after the add the list is restricted to the manager directory and A');
    assert.deepEqual(log.posts.map((body) => JSON.parse(body)), [{ Action: 'add', Directory: probeA }], 'one add was sent');

    // Change A to B.
    await select(page, probeA);
    await press(page, STRINGS.allowedDirectoryChangeAction);
    const change = await openDialog(page);
    assert.deepEqual(change, {
      title: STRINGS.allowedDirectoryChangeAction,
      consequence: STRINGS.allowedDirectoryChangeConsequence.replace('<directory>', probeA),
      field: STRINGS.allowedDirectoryNewLabel,
    });
    await proceedWith(page, probeB);
    await rowsAre(page, [[manager, STRINGS.tableStatusYes], [probeB, STRINGS.tableStatusYes]], 'after the change the list holds B and not A');
    assert.deepEqual(JSON.parse(log.posts[1]), { Action: 'change', Directory: probeA, NewDirectory: probeB });

    // Remove B, typing its name.
    await select(page, probeB);
    await press(page, STRINGS.actionRemove);
    const remove = await openDialog(page);
    assert.equal(remove.consequence, STRINGS.allowedDirectoryRemoveConsequence);
    assert.equal(remove.title, `${STRINGS.actionRemove} ${probeB}`, 'the typed-name dialog names the directory');
    await page.type('.ocu-typed-name-field', `${probeB}x`);
    await frames(page);
    assert.equal(await page.$eval('.ocu-dialog-actions .ocu-button-destructive', (button) => button.getAttribute('aria-disabled')), 'true', 'a name that is not exact keeps the button unavailable');
    await page.$eval('.ocu-typed-name-field', (input) => {
      input.value = '';
      input.dispatchEvent(new Event('input'));
    });
    await removeWith(page, probeB);
    await rowsAre(page, [[manager, STRINGS.tableStatusYes]], 'after the remove the list holds the manager directory alone, now a stored entry');
    assert.deepEqual(JSON.parse(log.posts[2]), { Action: 'remove', Directory: probeB });

    // C4: the list is restricted now, so its manager row is an entry a person can remove; removing it empties the list.
    await select(page, manager);
    const entry = await bar(page);
    assert.equal(entry.find((control) => control.label === STRINGS.actionRemove)?.disabled, null, 'Remove is drawn on for a stored entry');
    await press(page, STRINGS.actionRemove);
    await openDialog(page);
    await removeWith(page, manager);
    await page.waitForSelector('.ocu-data-table-empty-title', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-data-table-empty-title', (element) => element.textContent.trim()), STRINGS.allowedDirectoriesEmptyNone, 'the empty state says no file or directory field can choose a location');
    assert.ok((await page.$eval('.ocu-data-table-empty-next', (element) => element.textContent)).includes(STRINGS.allowedDirectoriesAgentHint), 'and invites the agent');
    assert.equal((await page.$$(ROW_SELECTOR)).length, 0, 'with no row drawn');
    assert.deepEqual(await routeRows(), [], 'and the instance reads no root');
    assert.equal(await page.$eval('.ocu-data-table-empty-action', (button) => button.textContent.trim()), STRINGS.allowedDirectoryAddAction, 'while Add stays offered in the empty state');
    assert.equal(log.posts.length, 4, 'four writes were sent in all');
  } finally {
    await context.close();
  }
});

test('C1 on a restricted list: Add words the plain consequence and Cancel sends nothing, and a refused Add puts the instance\u2019s sentence on the banner and changes nothing', async () => {
  // Mutation (Rule 19): make `ScreenActionHandler.send` put no sentence on the store after a refused answer, rebuild and redeploy
  // -> the banner step goes red.
  const missing = probeA.replace('ocuprobe1846a/', 'ocuprobe1846none/');
  allowList(config, `SetUp(1, $ListBuild("${escapeOs(probeA)}"))`);
  const { log, attach } = watching();
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide, null, attach);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await verdictAnswered(page, log, 1);
    await setGovernanceKey(KEY, 'enabled');
    await reenter(page, log);
    await rowsAre(page, [[probeA, STRINGS.tableStatusYes]], 'a restricted list shows its one stored entry');

    await press(page, STRINGS.allowedDirectoryAddAction);
    assert.deepEqual(await openDialog(page), {
      title: STRINGS.allowedDirectoryAddAction,
      consequence: STRINGS.allowedDirectoryAddConsequence,
      field: STRINGS.lockColumnDirectory,
    });
    await page.click('.ocu-dialog-actions .ocu-button-secondary');
    await dialogClosed(page);
    await frames(page);
    assert.deepEqual(log.posts, [], 'Cancel sent nothing');

    // A directory that does not exist: the route refuses it, and the list's banner carries the instance's sentence.
    const answered = log.verdicts.length;
    await press(page, STRINGS.allowedDirectoryAddAction);
    await openDialog(page);
    await proceedWith(page, missing);
    await page.waitForFunction(
      (sentence) => [...document.querySelectorAll('p.ocu-list-page-banner[role="alert"] .ocu-banner-message')].some((message) => message.textContent.trim() === sentence),
      { timeout: config.navigationTimeoutMs },
      STRINGS.allowListRefusalNoDirectory
    );
    assert.deepEqual(log.posts.map((body) => JSON.parse(body)), [{ Action: 'add', Directory: missing }], 'one add was sent, and it is the refused one');
    await verdictAnswered(page, log, answered + 1);
    await rowsAre(page, [[probeA, STRINGS.tableStatusYes]], 'the refused add changed nothing: the list is as it was');
  } finally {
    await context.close();
  }
});

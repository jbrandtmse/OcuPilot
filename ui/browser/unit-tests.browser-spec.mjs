/**
 * System Explorer's Unit tests in a real browser and over the shipped routes, against the throwaway instance (Story 24.5).
 *
 * What it pins:
 *
 * 1. **AC4, off by default.** With the governance key `explorer.unittests.run` at its shipped `false`, a Run confirmed in the
 *    warning dialog shows the switched-off sentence and no run is added to `USER`'s record.
 * 2. **AC6.** Run opens the warning dialog with the consequence sentence, and Cancel adds no run.
 * 3. **AC1 and AC2.** With the key stored on, the class `OcuProbe245.Mixed` run through the dialog adds one run to the list with
 *    its counts, that run's methods list shows both methods and the failed one's assertion text, a method-level and a
 *    package-level run through the route answer their counts, and `USER`'s root global ends as it began.
 * 4. **The production test is refused**, with its sentence, in the dialog's own banner.
 *
 * **It runs real `%UnitTest` runs, in `USER`, of classes it saves itself** (`OcuProbe245`, `OcuProbe245P`), so it never runs
 * beside a `ci-runner` call. It removes the classes and every run it added, puts the result counter and the stored governance
 * policy back, and runs only in a throwaway.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1 browser/unit-tests.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { ROW_SELECTOR, clickRowCentre, viewCount, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { authHeader, signedInAt } from './panel-spec.mjs';
import { governanceRowVersion, resetGovernancePolicy, setGovernanceKey } from './preferences-reset.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { clearGovernancePolicy, markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();

const NAMESPACE = 'USER';
const ROUTE = 'system-explorer/unit-tests';
const KEY = 'explorer.unittests.run';
const ACTION_PATH = '/api/ocupilot/screens/explorer.unittests/action';
const MIXED = 'OcuProbe245.Mixed';
const FAILED_TEXT = 'the probe assertion that fails';

const TESTS_FIELD = '[data-ocu-devtool="tests"]';
const LEVEL_FIELD = '[data-ocu-devtool="level"]';
const RUN_BUTTON = '[data-ocu-devtool="run"]';
const REFUSAL = '[data-ocu-devtool="run-refusal"]';
const DIALOG = 'app-warning-dialog [role="dialog"]';

let browser = null;
// What the namespace held before this file ran: no stored policy, the newest run, and whether the result counter existed.
let noStoredPolicy = false;
let baseline = 0;
let hadCounter = false;
let counterWas = '';

/** One marker from an instance script, as its trimmed text. */
function iris(marker, lines) {
  const output = runIris(config.container, [...lines, `Write "OCU-${marker}-START:"_tValue_":OCU-${marker}-END",!`]);
  return markerValue(output, marker);
}

/** The newest run `USER` records, as its index, or 0. */
function newestRun() {
  return Number(iris('NEWEST', [`Set tValue=+$Order(^|"${NAMESPACE}"|UnitTest.Result(""),-1)`]));
}

/** `USER`'s unit-test root global as `<has a value>|<value>`. */
function rootState() {
  return iris('ROOT', [`Set tValue=($Data(^|"${NAMESPACE}"|UnitTestRoot)#2)_"|"_$Get(^|"${NAMESPACE}"|UnitTestRoot)`]);
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs unit tests, so it never runs inside the live container');
  assert.ok(!/^ocupilot-slot-/.test(config.container), 'nor inside a development instance');
  assert.match(config.container, /-ci$/, `this spec runs tests and changes the governance policy, so it runs only in a throwaway; ${config.container} is not one`);
  await assertThrowaway(config);
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  noStoredPolicy = (await governanceRowVersion()) === 0;
  await resetGovernancePolicy();
  hadCounter = iris('COUNTER', [`Set tValue=$Data(^|"${NAMESPACE}"|UnitTest.Result)#2`]) === '1';
  counterWas = hadCounter ? iris('COUNTERVALUE', [`Set tValue=$Get(^|"${NAMESPACE}"|UnitTest.Result)`]) : '';
  baseline = newestRun();
  const made = runIris(config.container, [
    `Do ##class(OcuPilot.Test.DevToolProbe).RemoveTests("${NAMESPACE}")`,
    `Set tMade=##class(OcuPilot.Test.DevToolProbe).MakeTests("${NAMESPACE}")`,
    'Write "OCU-QA-MAKE-START:"_$System.Status.IsOK(tMade)_":OCU-QA-MAKE-END",!',
  ]);
  assert.equal(markerValue(made, 'QA-MAKE'), '1', `the probe test classes are saved: ${made}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    if (/-ci$/.test(config.container)) {
      const added = newestRun();
      const removed = runIris(config.container, [
        `For tI=${baseline + 1}:1:${Math.max(added, baseline)} Do ##class(OcuPilot.Test.DevToolProbe).RemoveRun("${NAMESPACE}",tI)`,
        `Set tGone=##class(OcuPilot.Test.DevToolProbe).RemoveTests("${NAMESPACE}")`,
        hadCounter ? `Set ^|"${NAMESPACE}"|UnitTest.Result=${JSON.stringify(counterWas)}` : `Kill ^|"${NAMESPACE}"|UnitTest.Result`,
        'Write "OCU-QA-GONE-START:"_$System.Status.IsOK(tGone)_":OCU-QA-GONE-END",!',
      ]);
      assert.equal(markerValue(removed, 'QA-GONE'), '1', `the probe test classes and the runs are removed: ${removed}`);
      await resetGovernancePolicy();
      if (noStoredPolicy) {
        clearGovernancePolicy(config.container);
        assert.equal(await governanceRowVersion(), 0, 'no governance policy is stored, as before this file ran');
      }
    }
  }
});

/** Name the tests and their level in the Run form and press Run. */
async function pressRun(page, tests, level) {
  await page.click(TESTS_FIELD, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(TESTS_FIELD, tests);
  await page.select(LEVEL_FIELD, level);
  await page.click(RUN_BUTTON);
  await page.waitForSelector(DIALOG, { visible: true, timeout: config.navigationTimeoutMs });
}

/** The dialog's button whose text is `label`, clicked. */
async function pressDialog(page, label) {
  const clicked = await page.evaluate(
    (dialog, wanted) => {
      const button = Array.from(document.querySelectorAll(`${dialog} button`)).find((node) => node.textContent.trim() === wanted);
      if (button === undefined) return false;
      button.click();
      return true;
    },
    DIALOG,
    label
  );
  assert.ok(clicked, `the dialog has a ${label} button`);
}

/** POST a Run to the action route as the signed-in administrator; answer the status and the parsed body. */
async function postRun(tests, level) {
  const answer = await fetch(`${config.origin}${ACTION_PATH}?ns=${NAMESPACE}`, {
    method: 'POST',
    headers: { Authorization: authHeader(config), 'Content-Type': 'application/json' },
    body: JSON.stringify({ action: 'run', id: 'unittests', values: { tests, level } }),
  });
  const text = await answer.text();
  let body = null;
  try {
    body = JSON.parse(text);
  } catch {
    // A body that is not JSON stays null, and the assertion that reads it names the text.
  }
  return { status: answer.status, body, text };
}

// AC4 and AC6. Mutation (Rule 19): send the action from `onAskRun` without the dialog -> the Cancel leg goes red; ignore the
// `Gate.Decide` verdict in `ScreenAction.Run` -> the run is made and the off leg goes red.
test('AC4 and AC6: Run names its consequence first, Cancel adds no run, and with the key off a confirmed Run shows the switched-off sentence and adds none', async () => {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${ROUTE}?ns=${NAMESPACE}`, VIEWPORTS.wide);
  try {
    await waitForMapAnswered(page, config.navigationTimeoutMs);
    await page.waitForSelector(TESTS_FIELD, { timeout: config.navigationTimeoutMs });
    await resetGovernancePolicy();
    const start = newestRun();
    await pressRun(page, MIXED, 'class');
    assert.equal(await page.$eval(`${DIALOG} .ocu-warning-consequence`, (node) => node.textContent.trim()), STRINGS.explorerUnitTestsRunConsequence, 'the dialog names the consequence');
    assert.equal(await page.$eval(`${DIALOG} .ocu-dialog-title`, (node) => node.textContent.trim()), STRINGS.explorerUnitTestsRunTitle, 'under its title');
    await pressDialog(page, STRINGS.actionCancel);
    await page.waitForSelector(DIALOG, { hidden: true, timeout: config.navigationTimeoutMs });
    assert.equal(newestRun(), start, 'Cancel added no run');

    await pressRun(page, MIXED, 'class');
    await pressDialog(page, STRINGS.actionProceed);
    await page.waitForSelector(REFUSAL, { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval(REFUSAL, (node) => node.textContent.trim()), STRINGS.explorerUnitTestOffReason, 'the instance\'s own switched-off sentence');
    assert.equal(newestRun(), start, 'and no run was added');
  } finally {
    await context.close();
  }
});

// AC1 and AC2. Mutation (Rule 19): skip the root restore in `DevToolPort.RootEnd`, recompile the port -> the root assertion
// goes red; drop the `Status = 0` filter on the failure text in `DevToolPort.ReadMethods` -> the failure cell goes red.
test('AC1 and AC2: with the key on, Run adds the run with its counts, its methods show the failure, and the root global ends as it began', async () => {
  const rootBefore = rootState();
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${ROUTE}?ns=${NAMESPACE}`, VIEWPORTS.wide);
  try {
    await waitForMapAnswered(page, config.navigationTimeoutMs);
    await page.waitForSelector(TESTS_FIELD, { timeout: config.navigationTimeoutMs });
    await setGovernanceKey(KEY, 'enabled');
    const start = newestRun();
    const rowsBefore = (await page.$$(ROW_SELECTOR)).length;
    await pressRun(page, MIXED, 'class');
    await pressDialog(page, STRINGS.actionProceed);
    await page.waitForSelector(DIALOG, { hidden: true, timeout: config.navigationTimeoutMs });
    await waitForRows(page, config.navigationTimeoutMs);
    await page.waitForFunction((count, selector) => document.querySelectorAll(selector).length > count, { timeout: config.navigationTimeoutMs }, rowsBefore, ROW_SELECTOR);
    assert.equal(await page.$(REFUSAL), null, 'no refusal is shown');
    const run = newestRun();
    assert.equal(run, start + 1, 'one run was added');
    const cells = await page.$$eval(`${ROW_SELECTOR}:first-child [role="gridcell"]`, (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.equal(cells[0], String(run), 'the newest run is the first row');
    assert.equal(cells[3], '2', 'two methods');
    assert.equal(cells[4], '1', 'one passed');
    assert.equal(cells[5], '1', 'one failed');
    assert.equal(rootState(), rootBefore, "USER's root global ends as it began");

    await clickRowCentre(page, { index: 0, link: true });
    await page.waitForFunction((route) => window.location.pathname.includes(route), { timeout: config.navigationTimeoutMs }, `${ROUTE}/methods`);
    await page.waitForFunction(() => document.querySelector('[role="grid"]')?.getAttribute('aria-rowcount') === '3', { timeout: config.navigationTimeoutMs }).catch(() => {});
    await waitForRows(page, config.navigationTimeoutMs);
    assert.equal(await viewCount(page), 2, `the run's methods list shows both methods at ${await page.evaluate(() => window.location.pathname + window.location.search)}`);
    const methods = await page.$$eval(ROW_SELECTOR, (rows) => rows.map((row) => Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim())));
    const failed = methods.find((row) => row.includes('TestFails'));
    const passed = methods.find((row) => row.includes('TestPasses'));
    assert.ok(failed?.includes(STRINGS.explorerPromoteFailed) && failed.includes(FAILED_TEXT), `the failed method names its assertion: ${JSON.stringify(failed)}`);
    assert.ok(passed?.includes(STRINGS.explorerUnitTestsPassed) && !passed.includes(FAILED_TEXT), `the passed one carries none: ${JSON.stringify(passed)}`);
  } finally {
    await context.close();
  }
});

// AC1 over the route. Mutation (Rule 19): send the whole target as the class in `UnitTestRun.Run` -> the method leg goes red.
test('AC1: over the route, a method-level and a package-level Run answer their counts, and the root global is as it was', async () => {
  await setGovernanceKey(KEY, 'enabled');
  const rootBefore = rootState();
  const method = await postRun(`${MIXED}:TestPasses`, 'method');
  assert.equal(method.status, 200, method.text);
  assert.deepEqual([method.body.output.passed, method.body.output.failed], [1, 0], 'one method ran and passed');
  const pack = await postRun('OcuProbe245', 'package');
  assert.equal(pack.status, 200, pack.text);
  assert.deepEqual([pack.body.output.passed, pack.body.output.failed], [1, 1], 'the package ran both methods');
  assert.ok(pack.body.output.run > method.body.output.run, 'each run is a new one');
  assert.equal(rootState(), rootBefore, "USER's root global is as it was");
});

// The production test. Mutation (Rule 19): move the production check after the body in `DevToolPort.UnitTest` -> a run is added.
test('a production test is refused in the dialog with its sentence and no run is added', async () => {
  const before = newestRun();
  const { context, page } = await signedInAt(browser, config, `/ocupilot/${ROUTE}?ns=${NAMESPACE}`, VIEWPORTS.wide);
  try {
    await waitForMapAnswered(page, config.navigationTimeoutMs);
    await page.waitForSelector(TESTS_FIELD, { timeout: config.navigationTimeoutMs });
    await setGovernanceKey(KEY, 'enabled');
    await pressRun(page, 'OcuProbe245P.Prod', 'class');
    await pressDialog(page, STRINGS.actionProceed);
    await page.waitForSelector(REFUSAL, { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval(REFUSAL, (node) => node.textContent.trim()), STRINGS.explorerUnitTestProductionReason, 'the production sentence');
    assert.equal(newestRun(), before, 'and no run was added');
  } finally {
    await context.close();
  }
});

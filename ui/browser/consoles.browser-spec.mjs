/**
 * System Explorer's Command console and Class method console in a real browser and over the shipped routes, against the throwaway
 * instance (Story 24.6).
 *
 * What it pins:
 *
 * 1. **AC5 and AC7, off by default and confirmed.** With the governance key at its shipped `false`, a Run confirmed in the warning
 *    dialog shows the switched-off sentence of that console and nothing runs. Run opens the dialog with the console's own
 *    consequence, and Cancel sends nothing.
 * 2. **AC1.** With the key on, a command writes its output through the dialog, a command that raises shows the output it wrote
 *    and the error, and a command that opens a transaction is answered.
 * 3. **AC3.** A command that writes 40,000 characters shows at most 32,768, ending with the cut marker, with its note.
 * 4. **AC2.** A class method called with an argument and one passed by reference shows its return value, its output and the
 *    by-reference value; a return value past the ceiling shows its note; a method that raises shows its error.
 *
 * **It runs real commands and class methods, in `USER`, of a class it saves itself** (`OcuProbe246.Echo`). It removes the class
 * and puts the stored governance policy back, and runs only in a throwaway.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1 browser/consoles.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { signedInAt } from './panel-spec.mjs';
import { governanceRowVersion, resetGovernancePolicy, setGovernanceKey } from './preferences-reset.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { clearGovernancePolicy, markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();

const NAMESPACE = 'USER';
const COMMAND_ROUTE = 'system-explorer/command';
const CLASSMETHOD_ROUTE = 'system-explorer/class-method';
const COMMAND_KEY = 'explorer.command.run';
const CLASSMETHOD_KEY = 'explorer.classmethod.run';
const ECHO = 'OcuProbe246.Echo';
const CUT_MARKER = '[cut at 32768 characters]';

const COMMAND_FIELD = '[data-ocu-console="command"]';
const CLASS_FIELD = '[data-ocu-console="class"]';
const METHOD_FIELD = '[data-ocu-console="method"]';
const ARGS_FIELD = '[data-ocu-console="args"]';
const RUN_BUTTON = '[data-ocu-console="run"]';
const REFUSAL = '[data-ocu-console="refusal"]';
const OUTPUT = '[data-ocu-console="output"]';
const ERROR = '[data-ocu-console="error"]';
const NOTE = '[data-ocu-console="note"]';
const DIALOG = 'app-warning-dialog [role="dialog"]';

let browser = null;
let noStoredPolicy = false;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs code, so it never runs inside the live container');
  assert.ok(!/^ocupilot-slot-/.test(config.container), 'nor inside a development instance');
  assert.match(config.container, /-ci$/, `this spec runs code and changes the governance policy, so it runs only in a throwaway; ${config.container} is not one`);
  await assertThrowaway(config);
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  noStoredPolicy = (await governanceRowVersion()) === 0;
  await resetGovernancePolicy();
  const made = runIris(config.container, [
    `Do ##class(OcuPilot.Test.DevToolProbe).RemoveConsoleProbe("${NAMESPACE}")`,
    `Set tMade=##class(OcuPilot.Test.DevToolProbe).MakeConsoleProbe("${NAMESPACE}")`,
    'Write "OCU-QA-CMAKE-START:"_$System.Status.IsOK(tMade)_":OCU-QA-CMAKE-END",!',
  ]);
  assert.equal(markerValue(made, 'QA-CMAKE'), '1', `the console probe class is saved: ${made}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    if (/-ci$/.test(config.container)) {
      const removed = runIris(config.container, [
        `Set tGone=##class(OcuPilot.Test.DevToolProbe).RemoveConsoleProbe("${NAMESPACE}")`,
        'Write "OCU-QA-CGONE-START:"_$System.Status.IsOK(tGone)_":OCU-QA-CGONE-END",!',
      ]);
      await resetGovernancePolicy();
      if (noStoredPolicy) {
        clearGovernancePolicy(config.container);
        assert.equal(await governanceRowVersion(), 0, 'no governance policy is stored, as before this file ran');
      }
      assert.equal(markerValue(removed, 'QA-CGONE'), '1', `the console probe class is removed: ${removed}`);
    }
  }
});

/** Replace the content of `selector` with `text`. A long text is set at once, as a paste would. */
async function fill(page, selector, text) {
  await page.$eval(
    selector,
    (node, value) => {
      node.value = value;
      node.dispatchEvent(new Event('input', { bubbles: true }));
    },
    text
  );
}

/** Press Run and wait for the warning dialog. */
async function pressRun(page) {
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

/** The text of the first element `selector` names, or `null`. */
async function textOf(page, selector) {
  return page.evaluate((query) => document.querySelector(query)?.textContent ?? null, selector);
}

/** Confirm the open dialog, and wait for the action's own answer to be drawn: the answer or the refusal, with the page no longer busy. */
async function confirm(page) {
  await Promise.all([
    page.waitForResponse((response) => response.request().method() === 'POST' && new URL(response.url()).pathname.endsWith('/action'), { timeout: config.navigationTimeoutMs }),
    pressDialog(page, STRINGS.actionProceed),
  ]);
  await page.waitForSelector(DIALOG, { hidden: true, timeout: config.navigationTimeoutMs });
  await page.waitForFunction(
    (answer, refusal) => document.querySelector('section[aria-busy="false"]') !== null && (document.querySelector(answer) !== null || document.querySelector(refusal) !== null),
    { timeout: config.navigationTimeoutMs },
    '[data-ocu-console="answer"]',
    REFUSAL
  );
}

/** Fill the Command console and send the command through the dialog; wait for the answer or the refusal. */
async function runCommand(page, command) {
  await fill(page, COMMAND_FIELD, command);
  await pressRun(page);
  await confirm(page);
}

/** Fill the Class method console and send the call through the dialog; wait for the answer or the refusal. */
async function callMethod(page, className, method, args) {
  await fill(page, CLASS_FIELD, className);
  await fill(page, METHOD_FIELD, method);
  await fill(page, ARGS_FIELD, args);
  await pressRun(page);
  await confirm(page);
}

async function open(route) {
  const opened = await signedInAt(browser, config, `/ocupilot/${route}?ns=${NAMESPACE}`, VIEWPORTS.wide);
  await waitForMapAnswered(opened.page, config.navigationTimeoutMs);
  return opened;
}

// AC5 and AC7. Mutation (Rule 19): send the action from `onAsk` without the dialog -> the Cancel leg goes red; ignore the
// `Gate.Decide` verdict in `ScreenAction.Run` -> the run is made and the off legs go red.
test('AC5 and AC7: Run names its consequence first, Cancel sends nothing, and with the key off a confirmed Run shows the switched-off sentence', async () => {
  await resetGovernancePolicy();
  for (const [route, field, fillIn, title, consequence, off] of [
    [COMMAND_ROUTE, COMMAND_FIELD, 'Write "off"', STRINGS.explorerCommandRunTitle, STRINGS.explorerCommandRunConsequence, STRINGS.explorerCommandOffReason],
    [CLASSMETHOD_ROUTE, CLASS_FIELD, ECHO, STRINGS.explorerClassMethodRunTitle, STRINGS.explorerClassMethodRunConsequence, STRINGS.explorerClassMethodOffReason],
  ]) {
    const { context, page } = await open(route);
    try {
      await page.waitForSelector(field, { timeout: config.navigationTimeoutMs });
      if (route === COMMAND_ROUTE) {
        await fill(page, COMMAND_FIELD, fillIn);
      } else {
        await fill(page, CLASS_FIELD, fillIn);
        await fill(page, METHOD_FIELD, 'Echo');
      }
      await pressRun(page);
      assert.equal(await page.$eval(`${DIALOG} .ocu-warning-consequence`, (node) => node.textContent.trim()), consequence, `${route}: the dialog names the consequence`);
      assert.equal(await page.$eval(`${DIALOG} .ocu-dialog-title`, (node) => node.textContent.trim()), title, `${route}: under its title`);
      await pressDialog(page, STRINGS.actionCancel);
      await page.waitForSelector(DIALOG, { hidden: true, timeout: config.navigationTimeoutMs });
      assert.equal(await page.$('[data-ocu-console="answer"]'), null, `${route}: Cancel ran nothing`);
      assert.equal(await page.$(REFUSAL), null, `${route}: and refused nothing`);
      await pressRun(page);
      await pressDialog(page, STRINGS.actionProceed);
      await page.waitForSelector(REFUSAL, { visible: true, timeout: config.navigationTimeoutMs });
      assert.equal((await textOf(page, REFUSAL)).trim(), off, `${route}: the instance's own switched-off sentence`);
      assert.equal(await page.$('[data-ocu-console="answer"]'), null, `${route}: and nothing ran`);
    } finally {
      await context.close();
    }
  }
});

// AC1. Mutation (Rule 19): drop the `output` set in `ConsoleRun.OnCaptured` -> the output assertions go red; let the port skip its
// rollback -> not visible here, `ConsoleRoundTrip` pins it.
test('AC1: with the key on, a command shows its output through the dialog, the error it raised, and an open transaction is answered', async () => {
  const { context, page } = await open(COMMAND_ROUTE);
  try {
    await page.waitForSelector(COMMAND_FIELD, { timeout: config.navigationTimeoutMs });
    // Signing in puts the stored policy back to its defaults, so the key is stored once the page is open.
    await setGovernanceKey(COMMAND_KEY, 'enabled');
    await runCommand(page, 'Write "ok"');
    assert.equal((await textOf(page, OUTPUT)).trim(), 'ok', 'the output');
    assert.equal(await page.$(ERROR), null, 'with no error');
    assert.equal(await page.$(REFUSAL), null, 'and no refusal');

    await runCommand(page, 'Write "a" Set x=1/0');
    assert.equal((await textOf(page, OUTPUT)).trim(), 'a', 'the output written before the error');
    assert.match(await textOf(page, ERROR), /<DIVIDE>/, 'and the error that names <DIVIDE>');

    await runCommand(page, 'TStart  Set ^||ocu246=1 Write $TLevel');
    assert.equal((await textOf(page, OUTPUT)).trim(), '1', 'a command that opens a transaction is answered, the transaction open while it ran');
    await runCommand(page, 'Write $TLevel');
    assert.equal((await textOf(page, OUTPUT)).trim(), '0', 'and the next request begins with none');
  } finally {
    await context.close();
  }
});

// AC3. Mutation (Rule 19): ignore `outputBudget` in `ConsoleRun.OnCaptured` -> the length assertion goes red.
test('AC3: a command that writes 40,000 characters shows at most 32,768, ending with the cut marker, and its note', async () => {
  const { context, page } = await open(COMMAND_ROUTE);
  try {
    await page.waitForSelector(COMMAND_FIELD, { timeout: config.navigationTimeoutMs });
    // Signing in puts the stored policy back to its defaults, so the key is stored once the page is open.
    await setGovernanceKey(COMMAND_KEY, 'enabled');
    await runCommand(page, 'Write $Translate($Justify("", 40000), " ", "x")');
    const output = await textOf(page, OUTPUT);
    assert.ok(output.length <= 32768, `at most 32,768 characters: ${output.length}`);
    assert.ok(output.trimEnd().endsWith(CUT_MARKER), 'ending with the cut marker');
    assert.equal((await textOf(page, NOTE)).trim(), STRINGS.explorerConsoleOutputCut, 'with its note');
  } finally {
    await context.close();
  }
});

// AC2. Mutation (Rule 19): drop `byRefValues` from `ConsoleRun.ClassMethod` -> the by-reference assertion goes red.
test('AC2: a class method shows its return value, its output and its by-reference value, a cut return value and its own error', async () => {
  const { context, page } = await open(CLASSMETHOD_ROUTE);
  try {
    await page.waitForSelector(CLASS_FIELD, { timeout: config.navigationTimeoutMs });
    await setGovernanceKey(CLASSMETHOD_KEY, 'enabled');
    await callMethod(page, ECHO, 'Echo', '["hi", {"byRef": true, "value": "x"}]');
    assert.equal((await textOf(page, '[data-ocu-console="return-value"]')).trim(), '2', 'the return value');
    assert.equal((await textOf(page, OUTPUT)).trim(), 'hi', 'the output');
    assert.match(await textOf(page, '[data-ocu-console="by-ref"]'), /"1": "hi!"/, 'and the value set through the by-reference argument');
    assert.equal(await page.$(ERROR), null, 'with no error');

    await callMethod(page, ECHO, 'Big', '[]');
    assert.equal((await textOf(page, NOTE)).trim(), STRINGS.explorerConsoleReturnCut, 'a return value past the ceiling carries its note');
    assert.ok((await textOf(page, '[data-ocu-console="return-value"]')).length <= 32768, 'and is cut within the ceiling');

    await callMethod(page, ECHO, 'Fails', '[]');
    assert.match(await textOf(page, ERROR), /<DIVIDE>/, "a method that raises shows its error");
    assert.equal((await textOf(page, OUTPUT)).trim(), 'before', 'and the output it wrote before it');

    await callMethod(page, ECHO, 'Nope', '[]');
    assert.equal((await textOf(page, REFUSAL)).trim(), STRINGS.explorerClassMethodNotFoundReason, 'a method that is not there is refused with its sentence');
  } finally {
    await context.close();
  }
});

/**
 * The New Task wizard in a real browser, against the throwaway instance (Story 9.7).
 *
 * What it pins, each on rendered DOM, on the real URL or on the instance itself:
 *
 * 1. **Create weekly** (the Matrix's first row, AC7): the four steps filled from the schedule list's
 *    Create, and Create task lands on the new task's details; the schedule list shows it; the
 *    stored task reads back inside the container with its schedule, setting, priority, output file,
 *    suspend-on-error, reschedule after a restart and addresses.
 * 2. **Next on empty Basics** stays on Basics, its heading naming the refusal in text (AC1).
 * 3. **Back keeps values** (AC1).
 * 4. **The type step loads the chosen type's settings**, and the previous type's are gone (AC1).
 * 5. **A name taken** is refused on Basics at Next, and a name taken after Basics was passed is
 *    refused at Create task, which opens Basics with its marker (Integration).
 * 6. **The visual gate** at 1440x900 on each step.
 *
 * **It refuses the live container.** It creates tasks named `OcuP97*` only, and removes them through
 * `OcuPilot.Test.TaskProbe`, which deletes a task by id only after its exact name reads back with
 * that prefix, so a vendor task is never touched.
 *
 * Run: `npm run test:browser` (after `npm run build` and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, waitForRows } from './list-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const PROBE_CLASS = 'OcuPilot.Test.TaskProbe';
const LIST_URL = '/ocupilot/tasks/schedule?ns=HSCUSTOM';
const WIZARD_URL = '/ocupilot/tasks/schedule/edit?ns=HSCUSTOM';
const ROOT = 'app-task-wizard-page';

/** The tasks this spec creates; every one carries the probe prefix. */
const WEEKLY = 'OcuP97BrowserWeekly';
const RACED = 'OcuP97BrowserRaced';
const VENDOR = 'Purge Tasks';

const STEP_LABELS = [STRINGS.taskStepBasics, STRINGS.taskStepType, STRINGS.taskDetailsSchedule, STRINGS.taskStepOptions];

let browser = null;

const mark = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/** Run ObjectScript in `iris session` inside the throwaway, in HSCUSTOM, and read back the named markers. */
function irisSession(lines, names = []) {
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', 'HSCUSTOM'], {
    input: `${[...lines, 'Halt'].join('\n')}\n`,
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const values = {};
  for (const name of names) {
    const found = new RegExp(`OCU-${name}-START:(.*?):OCU-${name}-END`).exec(output);
    values[name] = found === null ? null : found[1];
  }
  return { values, output };
}

/** Remove every probe task by id after its exact name reads back; true when none survives. */
function removeProbes() {
  const { values, output } = irisSession([`Set tSC=##class(${PROBE_CLASS}).RemoveAll()`, mark('CLEAN', '$System.Status.IsOK(tSC)')], ['CLEAN']);
  return { clean: values.CLEAN === '1', output };
}

/** Probe task `name`'s id and its stored properties as JSON, or `gone`. */
function stored(name) {
  const { values } = irisSession(
    [`Set tId=##class(${PROBE_CLASS}).IdOf("${name}")`, `Set tStored=$Select(tId="":"",1:##class(${PROBE_CLASS}).Stored(tId))`, mark('ID', 'tId'), mark('TASK', '$Select($IsObject(tStored):tStored.%ToJSON(),1:"gone")')],
    ['ID', 'TASK']
  );
  return { id: values.ID, task: values.TASK === null || values.TASK === 'gone' ? null : JSON.parse(values.TASK) };
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates and deletes tasks, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  const { clean, output } = removeProbes();
  assert.ok(clean, `no probe task is left from an earlier run:\n${output}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  const { clean, output } = removeProbes();
  assert.ok(clean, `the probe tasks are removed:\n${output}`);
});

/** A fresh context signed in through the shell's own form, landed at `url`, with its task writes counted. */
async function signedInAt(url) {
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  const writes = [];
  page.on('request', (request) => {
    const path = new URL(request.url()).pathname;
    if (path === '/api/ocupilot/tasks' && request.method() === 'POST') writes.push({ path, body: request.postData() ?? '' });
  });
  await page.goto(`${config.origin}${url}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', config.username);
  await page.type('#ocu-signin-password', config.password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, url);
  return { context, page, writes };
}

/** Wait until the wizard has read its form and shows its first step. */
async function wizardReady(page) {
  await page.waitForSelector(`${ROOT} .ocu-form-step-head[aria-current="step"]`, { visible: true, timeout: config.navigationTimeoutMs });
  await page.waitForSelector('#ocu-task-Name', { visible: true, timeout: config.navigationTimeoutMs });
}

/** The label of the step on screen. */
function currentStep(page) {
  return page.$eval(`${ROOT} .ocu-form-step-head[aria-current="step"] .ocu-form-step-label`, (node) => node.textContent.trim());
}

async function atStep(page, label) {
  await page.waitForFunction(
    (root, wanted) => document.querySelector(`${root} .ocu-form-step-head[aria-current="step"] .ocu-form-step-label`)?.textContent.trim() === wanted,
    { timeout: config.navigationTimeoutMs },
    ROOT,
    label
  );
}

/** Each step head: its label, accessible name, marker and whether it can be opened. */
function stepState(page) {
  return page.$$eval(`${ROOT} .ocu-form-step-head`, (heads) =>
    heads.map((head) => ({
      label: head.querySelector('.ocu-form-step-label')?.textContent.trim() ?? '',
      name: head.getAttribute('aria-label'),
      invalid: head.classList.contains('ocu-form-step-invalid'),
      disabled: head.disabled,
    }))
  );
}

/** The form bar's primary button's text. */
function primaryText(page) {
  return page.$eval('.ocu-form-bar-actions .ocu-button-primary', (node) => node.textContent.trim());
}

async function primary(page) {
  await page.click('.ocu-form-bar-actions .ocu-button-primary');
}

/** Press Next and wait for `label` to be the step on screen. */
async function nextTo(page, label) {
  await primary(page);
  await atStep(page, label);
}

async function back(page) {
  await page.evaluate((text) => {
    Array.from(document.querySelectorAll('.ocu-form-bar-actions button')).find((button) => button.textContent.trim() === text).click();
  }, STRINGS.errorLogBack);
}

/** Replace text control `id`'s value by typing. */
async function fill(page, id, value) {
  await page.click(`#${id}`, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(`#${id}`, value);
}

/** Set a date or time control's value the way the browser's picker does, then let the page read it. */
async function setValue(page, id, value) {
  await page.$eval(
    `#${id}`,
    (node, wanted) => {
      node.value = wanted;
      node.dispatchEvent(new Event('input', { bubbles: true }));
      node.dispatchEvent(new Event('change', { bubbles: true }));
    },
    value
  );
}

async function check(page, id, on = true) {
  const checked = await page.$eval(`#${id}`, (node) => node.checked);
  if (checked !== on) await page.click(`#${id}`);
}

/** Fill Basics with `name` and move to the type step. */
async function passBasics(page, name) {
  await wizardReady(page);
  await fill(page, 'ocu-task-Name', name);
  await nextTo(page, STRINGS.taskStepType);
}

/** Choose `%SYS.Task.PurgeTaskHistory` keeping `keepDays`, and move to Schedule. */
async function passType(page, keepDays = '30') {
  await page.select('#ocu-task-TaskClass', '%SYS.Task.PurgeTaskHistory');
  await page.waitForSelector('#ocu-task-Settings-KeepDays', { visible: true, timeout: config.navigationTimeoutMs });
  await fill(page, 'ocu-task-Settings-KeepDays', keepDays);
  await nextTo(page, STRINGS.taskDetailsSchedule);
}

function textOf(page, id) {
  return page.evaluate((wanted) => document.getElementById(wanted)?.textContent.trim() ?? null, id);
}

test('Matrix "Create weekly", AC7: the four steps from the list\u2019s Create create the task, whose details open and whose stored values read back', async () => {
  const { context, page, writes } = await signedInAt(LIST_URL);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await (await page.waitForSelector('.ocu-command-bar button.ocu-button-primary', { visible: true, timeout: config.navigationTimeoutMs })).click();
    await page.waitForFunction(() => new URL(window.location.href).pathname.endsWith('/tasks/schedule/edit'), { timeout: config.navigationTimeoutMs });
    // The URL moves before the form read answers, and the stepper is drawn only once it has.
    await wizardReady(page);
    assert.deepEqual((await stepState(page)).map((step) => step.label), STEP_LABELS, 'a stepper of the four named steps');
    await passBasics(page, WEEKLY);
    await passType(page, '30');
    await page.select('#ocu-task-TimePeriod', 'Weekly');
    await page.waitForSelector('.ocu-task-days', { visible: true, timeout: config.navigationTimeoutMs });
    await fill(page, 'ocu-task-TimePeriodEvery', '1');
    await check(page, 'ocu-task-TimePeriodDay-2');
    await check(page, 'ocu-task-TimePeriodDay-4');
    await page.select('#ocu-task-DailyFrequency', 'Several');
    await page.waitForSelector('#ocu-task-DailyIncrement', { visible: true, timeout: config.navigationTimeoutMs });
    await page.select('#ocu-task-DailyFrequencyTime', 'Minutes');
    await fill(page, 'ocu-task-DailyIncrement', '30');
    await setValue(page, 'ocu-task-DailyStartTime', '01:00');
    await setValue(page, 'ocu-task-DailyEndTime', '05:00');
    await nextTo(page, STRINGS.taskStepOptions);
    assert.equal(await primaryText(page), STRINGS.taskCreate, 'the last step\u2019s primary reads "Create task"');
    await page.select('#ocu-task-Priority', 'Low');
    await check(page, 'ocu-task-OpenOutputFile');
    await fill(page, 'ocu-task-OutputFilename', 'ocup97browser.txt');
    await check(page, 'ocu-task-SuspendOnError');
    await check(page, 'ocu-task-RescheduleOnStart');
    await fill(page, 'ocu-task-EmailOnCompletion', 'ops@example.com');
    await fill(page, 'ocu-task-EmailOnError', 'ops@example.com, dev@example.com');
    await fill(page, 'ocu-task-EmailOnExpiration', 'dev@example.com');
    await primary(page);
    await page.waitForFunction(() => /\/tasks\/schedule\/details\/\d+$/.test(new URL(window.location.href).pathname), { timeout: config.navigationTimeoutMs });
    assert.equal(writes.length, 1, 'one create');
    const { id, task } = stored(WEEKLY);
    assert.ok(task !== null, 'the instance holds the task');
    assert.ok(new URL(page.url()).pathname.endsWith(`/tasks/schedule/details/${id}`), `the page is the new task's details: ${page.url()}`);
    await page.waitForFunction((name) => document.querySelector('app-task-details-page')?.textContent.includes(name), { timeout: config.navigationTimeoutMs }, WEEKLY);
    const scheduleShown = await page.evaluate(() => document.querySelector('app-task-details-page .ocu-details-schedule')?.textContent ?? '');
    for (const part of ['30', '01:00', '05:00']) {
      assert.ok(scheduleShown.includes(part), `the details screen shows the schedule the wizard set (${part}): ${scheduleShown}`);
    }
    assert.deepEqual(
      {
        type: [task.TaskClass, task.NameSpace, task['Settings.KeepDays']],
        schedule: [task.TimePeriod, task.TimePeriodEvery, task.TimePeriodDay, task.DailyFrequency, task.DailyFrequencyTime, task.DailyIncrement, task.DailyStartTime, task.DailyEndTime],
        options: [task.Priority, task.OpenOutputFile, task.OutputFilename, task.SuspendOnError, task.RescheduleOnStart],
        addresses: [task.EmailOnCompletion, task.EmailOnError, task.EmailOnExpiration],
      },
      {
        type: ['%SYS.Task.PurgeTaskHistory', '%SYS', '30'],
        schedule: ['1', '1', '24', '1', '0', '30', '3600', '18000'],
        options: ['1', '1', 'ocup97browser.txt', '1', '1'],
        addresses: ['ops@example.com', 'ops@example.com,dev@example.com', 'dev@example.com'],
      },
      'the stored task reads back with what the wizard set'
    );
  } finally {
    await context.close();
  }
  // The schedule list, in a context of its own: a reload of the tab would sign it out.
  const list = await signedInAt(LIST_URL);
  try {
    await waitForRows(list.page, config.navigationTimeoutMs);
    await list.page.type(FILTER_SELECTOR, WEEKLY);
    await list.page.waitForFunction(
      (selector, name) => Array.from(document.querySelectorAll(selector)).some((row) => row.textContent.includes(name)),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      WEEKLY
    );
  } finally {
    await list.context.close();
  }
});

test('AC1, Matrix "Next on empty Basics": Next stays on Basics, marked, its heading naming the refusal in text', async () => {
  const { context, page } = await signedInAt(WIZARD_URL);
  try {
    await wizardReady(page);
    await primary(page);
    await page.waitForSelector('#ocu-form-step-error-basics', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await currentStep(page), STRINGS.taskStepBasics, 'it stays on Basics');
    const [basics] = await stepState(page);
    assert.equal(basics.invalid, true, 'the step carries the marker');
    assert.match(basics.name, new RegExp(`^${STRINGS.taskStepBasics}, \\d+ errors?$`), 'and its accessible name counts the refusal');
    const line = await textOf(page, 'ocu-form-step-error-basics');
    const reason = await textOf(page, 'ocu-task-Name-reason');
    assert.ok(reason !== null && reason !== '', 'the refusal is drawn at the field');
    assert.ok(line.includes(reason), `the heading names it in text: ${line}`);
  } finally {
    await context.close();
  }
});

test('AC1, Matrix "Back keeps values" and "Type loads settings": Back keeps every value, and a type draws only its own settings', async () => {
  const { context, page } = await signedInAt(WIZARD_URL);
  try {
    await wizardReady(page);
    await fill(page, 'ocu-task-Name', 'OcuP97BrowserBack');
    await fill(page, 'ocu-task-Description', 'kept across steps');
    await nextTo(page, STRINGS.taskStepType);
    await page.select('#ocu-task-TaskClass', '%SYS.Task.IntegrityCheck');
    await page.waitForSelector('#ocu-task-Settings-Directory', { visible: true, timeout: config.navigationTimeoutMs });
    const manager = irisSession([mark('MGR', '$System.Util.ManagerDirectory()')], ['MGR']).values.MGR;
    assert.equal(await page.$eval('#ocu-task-Settings-Directory', (node) => node.value), manager, 'the type\u2019s settings appear at the type\u2019s own defaults');
    await page.select('#ocu-task-TaskClass', '%SYS.Task.PurgeTaskHistory');
    await page.waitForSelector('#ocu-task-Settings-KeepDays', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$('#ocu-task-Settings-Directory'), null, 'the previous type\u2019s settings are gone');
    await fill(page, 'ocu-task-Settings-KeepDays', '45');
    await back(page);
    await atStep(page, STRINGS.taskStepBasics);
    assert.equal(await page.$eval('#ocu-task-Name', (node) => node.value), 'OcuP97BrowserBack', 'Basics keeps the name');
    assert.equal(await page.$eval('#ocu-task-Description', (node) => node.value), 'kept across steps', 'and the description');
    await nextTo(page, STRINGS.taskStepType);
    assert.equal(await page.$eval('#ocu-task-TaskClass', (node) => node.value), '%SYS.Task.PurgeTaskHistory', 'the type is kept');
    assert.equal(await page.$eval('#ocu-task-Settings-KeepDays', (node) => node.value), '45', 'and its setting');
  } finally {
    await context.close();
  }
});

// Matrix "Name taken", Integration. Mutation (Rule 19): skip `tabToOpen` in the page's
// `afterRefusal` and redeploy -> the raced leg stays on Options and goes red.
test('Matrix "Name taken", Integration: a taken name is refused on Basics, and one taken after Basics opens Basics with its marker at Create task', async () => {
  const { context, page, writes } = await signedInAt(WIZARD_URL);
  try {
    await wizardReady(page);
    await fill(page, 'ocu-task-Name', VENDOR.toLowerCase());
    await primary(page);
    await page.waitForSelector('#ocu-task-Name-reason', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await currentStep(page), STRINGS.taskStepBasics, 'a vendor task\u2019s name in another case stays on Basics');
    const taken = irisSession([mark('REASON', '##class(OcuPilot.Api.Error).#REASONTASKNAMETAKEN')], ['REASON']).values.REASON;
    assert.equal(await textOf(page, 'ocu-task-Name-reason'), taken, 'refused on Name in the server\u2019s own sentence');
    await fill(page, 'ocu-task-Name', RACED);
    await nextTo(page, STRINGS.taskStepType);
    await passType(page);
    await nextTo(page, STRINGS.taskStepOptions);
    // Somebody takes the name after Basics was passed.
    const { values, output } = irisSession(
      [
        'New $Namespace Set $Namespace="%SYS"',
        `Set t=##class(%SYS.Task).%New(),t.Name="${RACED}",t.NameSpace="%SYS",t.TaskClass="%SYS.Task.PurgeTaskHistory",t.TimePeriod=5`,
        'Set tSC=t.%Save()',
        mark('RACED', '$System.Status.IsOK(tSC)'),
      ],
      ['RACED']
    );
    assert.equal(values.RACED, '1', `the name is taken behind the wizard's back:\n${output}`);
    await primary(page);
    await atStep(page, STRINGS.taskStepBasics);
    const [basics] = await stepState(page);
    assert.equal(basics.invalid, true, 'Basics opens with its marker');
    assert.ok((await textOf(page, 'ocu-form-step-error-basics')).length > 0, 'naming the refusal in text');
    await page.waitForFunction(() => document.activeElement?.id === 'ocu-task-Name', { timeout: config.navigationTimeoutMs });
    assert.equal(writes.length, 1, 'the one create was sent and refused');
    const { id } = stored(RACED);
    assert.ok(id !== null && id !== '', 'only the task made behind its back holds the name');
  } finally {
    await context.close();
    removeProbes();
  }
});

test('the visual gate at 1440x900: on every step each control is named and at least 24x24, nothing overflows, and the bar sits inside the content area', async () => {
  const { context, page } = await signedInAt(WIZARD_URL);
  try {
    await page.setViewport({ width: 1440, height: 900 });
    await passBasics(page, 'OcuP97BrowserVisual');
    await passType(page);
    await page.select('#ocu-task-TimePeriod', 'Weekly');
    await page.select('#ocu-task-DailyFrequency', 'Several');
    await page.select('#ocu-task-DailyFrequencyTime', 'Minutes');
    await fill(page, 'ocu-task-DailyIncrement', '30');
    await setValue(page, 'ocu-task-DailyEndTime', '05:00');
    await check(page, 'ocu-task-TimePeriodDay-2');
    await nextTo(page, STRINGS.taskStepOptions);
    await fill(page, 'ocu-task-RunAsUser', 'Admin');
    for (const label of STEP_LABELS) {
      await page.evaluate(
        (root, wanted) => Array.from(document.querySelectorAll(`${root} .ocu-form-step-head`)).find((head) => head.querySelector('.ocu-form-step-label')?.textContent.trim() === wanted).click(),
        ROOT,
        label
      );
      await atStep(page, label);
      const report = await page.evaluate((root) => {
        const nameOf = (node) => {
          const labelled = node.getAttribute('aria-labelledby');
          if (labelled) return labelled.split(' ').map((id) => document.getElementById(id)?.textContent.trim() ?? '').join(' ').trim();
          if (node.getAttribute('aria-label')) return node.getAttribute('aria-label').trim();
          if (node.labels && node.labels.length > 0) return Array.from(node.labels).map((item) => item.textContent.trim()).join(' ');
          return node.textContent.trim();
        };
        const host = document.querySelector(root);
        const controls = Array.from(host.querySelectorAll('input, select, textarea, button')).filter((node) => node.offsetParent !== null);
        const unnamed = controls.filter((node) => nameOf(node) === '').map((node) => node.outerHTML.slice(0, 120));
        const targetOf = (node) => (node.type === 'checkbox' && node.parentElement?.tagName === 'LABEL' ? node.parentElement : node);
        const small = controls
          .filter((node) => {
            const box = targetOf(node).getBoundingClientRect();
            const min = parseFloat(getComputedStyle(node).minWidth);
            return box.width < 24 || box.height < 24 || (Number.isFinite(min) && box.width + 0.5 < min);
          })
          .map((node) => node.outerHTML.slice(0, 120));
        const overflowing = Array.from(host.querySelectorAll('*'))
          .filter((node) => node.offsetParent !== null && node.parentElement !== null)
          .filter((node) => {
            const own = node.getBoundingClientRect();
            const parent = node.parentElement.getBoundingClientRect();
            if (getComputedStyle(node.parentElement).overflowX !== 'visible') return false;
            return own.width > 0 && own.right > parent.right + 1;
          })
          .map((node) => node.outerHTML.slice(0, 120));
        const content = document.querySelector('.ocu-content');
        const bar = document.querySelector('.ocu-form-bar');
        return {
          controls: controls.length,
          unnamed,
          small,
          overflowing,
          pageOverflow: document.documentElement.scrollWidth > document.documentElement.clientWidth,
          contentBottom: content === null ? null : content.getBoundingClientRect().bottom,
          barBottom: bar === null ? null : bar.getBoundingClientRect().bottom,
        };
      }, ROOT);
      assert.ok(report.controls > 3, `${label}: the gate looked at the wizard's controls: ${report.controls}`);
      assert.deepEqual(report.unnamed, [], `${label}: every control has an accessible name`);
      assert.deepEqual(report.small, [], `${label}: none is smaller than 24x24 or narrower than its declared minimum`);
      assert.deepEqual(report.overflowing, [], `${label}: nothing overflows its container`);
      assert.equal(report.pageOverflow, false, `${label}: and the page does not scroll sideways`);
      assert.ok(report.barBottom !== null && report.barBottom <= report.contentBottom + 1, `${label}: the bar sits inside the content area: ${JSON.stringify(report)}`);
    }
  } finally {
    await context.close();
  }
});

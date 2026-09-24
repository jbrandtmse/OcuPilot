/**
 * Edit task in a real browser, against the throwaway instance (Story 9.8).
 *
 * What it pins, each on rendered DOM, on the real URL or on the instance itself:
 *
 * 1. **Task details > Edit** opens Edit task at the form's id route, its four tabs named for the
 *    wizard's steps, the type and namespace read-only, and every value a wizard-created task holds
 *    drawn from the instance (AC1, DW-1624).
 * 2. **A two-field save** answers "Saved", sends the two fields, and every other field reads back
 *    inside the container as it was (Matrix "Two-field save", AC2).
 * 3. **A rename reaches Task details and Task schedule** without a manual refresh (Integration,
 *    AD-14).
 * 4. **A refused Save** opens the refused field's tab with its marker and focuses the field, and
 *    leaving with unsaved work asks first (AC1).
 * 5. **A task the instance no longer holds** reads "This task no longer exists." (Matrix "Absent").
 * 6. **The visual gate** at 1440x900 on each of the four tabs (DW-1337): the structural walk visits
 *    editors at their bare route only, so this is the id route's gate.
 *
 * **It refuses the live container.** It creates and edits tasks named `OcuP98*` only, and removes
 * them through `OcuPilot.Test.TaskEditProbe`, which deletes a task by id only after its exact name
 * reads back with that prefix, so a vendor task is never touched.
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
const PROBE_CLASS = 'OcuPilot.Test.TaskEditProbe';
const LIST_URL = '/ocupilot/tasks/schedule?ns=HSCUSTOM';
const ROOT = 'app-task-editor-page';

/** The tasks this spec creates; every one carries the probe prefix. */
const EDITED = 'OcuP98BrowserEdit';
const RENAMED = 'OcuP98BrowserRenamed';
const VENDOR = 'Purge Tasks';

const TAB_LABELS = [STRINGS.taskStepBasics, STRINGS.taskStepType, STRINGS.taskDetailsSchedule, STRINGS.taskStepOptions];
const TAB_KEYS = ['basics', 'type', 'schedule', 'options'];

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

/** Create probe task `name` with the wizard's AC7 values through the wizard's own Save; its id. */
function createProbe(name) {
  const { values, output } = irisSession(
    [`Set tSC=##class(${PROBE_CLASS}).Create(##class(${PROBE_CLASS}).Ac7("${name}"),.tId)`, mark('ID', '$Select($System.Status.IsOK(tSC):tId,1:"")')],
    ['ID']
  );
  assert.ok(values.ID !== null && /^\d+$/.test(values.ID), `the probe task ${name} is created:\n${output}`);
  return values.ID;
}

/** Task `id`'s stored properties as the instance holds them, or `null`. */
function stored(id) {
  const { values } = irisSession([`Set tStored=##class(${PROBE_CLASS}).Stored("${id}")`, mark('TASK', '$Select($IsObject(tStored):tStored.%ToJSON(),1:"gone")')], ['TASK']);
  return values.TASK === null || values.TASK === 'gone' ? null : JSON.parse(values.TASK);
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates, edits and deletes tasks, so it never runs inside the live container');
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

/** A fresh context signed in through the shell's own form, landed at `url`, with its task edits counted. */
async function signedInAt(url) {
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  const writes = [];
  page.on('request', (request) => {
    const path = new URL(request.url()).pathname;
    if (path.startsWith('/api/ocupilot/tasks/') && request.method() === 'PUT') writes.push({ path, body: request.postData() ?? '' });
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

function editUrl(id) {
  return `/ocupilot/tasks/schedule/edit/${id}?ns=HSCUSTOM`;
}

function detailsUrl(id) {
  return `/ocupilot/tasks/schedule/details/${id}?ns=HSCUSTOM`;
}

/** Wait until Edit task has read the task and drawn its tabs. */
async function editorReady(page, name) {
  await page.waitForSelector(`${ROOT} .ocu-form-tab`, { visible: true, timeout: config.navigationTimeoutMs });
  await page.waitForFunction((wanted) => document.getElementById('ocu-task-Name')?.value === wanted, { timeout: config.navigationTimeoutMs }, name);
}

/** Each tab: its label, accessible name, marker and whether it is on screen. */
function tabState(page) {
  return page.$$eval(`${ROOT} .ocu-form-tab`, (tabs) =>
    tabs.map((tab) => ({
      key: tab.getAttribute('data-tab'),
      label: tab.querySelector('.ocu-form-tab-label')?.textContent.trim() ?? '',
      name: tab.getAttribute('aria-label'),
      dot: tab.classList.contains('ocu-form-tab-invalid'),
      selected: !document.querySelector(`[data-tab-body="${tab.getAttribute('data-tab')}"]`)?.hasAttribute('hidden'),
    }))
  );
}

async function openTab(page, key) {
  await page.click(`${ROOT} .ocu-form-tab[data-tab="${key}"]`);
  await page.waitForFunction((wanted) => document.querySelector(`[data-tab-body="${wanted}"]`)?.hasAttribute('hidden') === false, { timeout: config.navigationTimeoutMs }, key);
  // The tab strip's indicator slides to the tab opened; nothing is measured mid-slide.
  await page.evaluate(() => Promise.all(document.getAnimations().map((animation) => animation.finished)));
}

async function save(page) {
  await page.click('.ocu-form-bar-actions .ocu-button-primary');
}

/** Wait for a Save to settle: "Saved" in the bar, or a refusal; the bar's text or the refusal's. */
async function saved(page) {
  await page.waitForFunction(
    (text) => document.querySelector('.ocu-form-bar-status')?.textContent.trim() === text || document.querySelector('.ocu-form-summary, .ocu-banner-warning') !== null,
    { timeout: config.navigationTimeoutMs },
    STRINGS.formSaved
  );
  return page.evaluate(() => document.querySelector('.ocu-form-bar-status')?.textContent.trim() || (document.querySelector('.ocu-form-summary, .ocu-banner-warning')?.textContent.trim() ?? ''));
}

/** Replace text control `id`'s value by typing. */
async function fill(page, id, value) {
  await page.click(`#${id}`, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(`#${id}`, value);
}

/** Set a number, date or time control's value the way the browser's own control does, then let the page read it. */
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

function valueOf(page, id) {
  return page.$eval(`#${id}`, (node) => (node.type === 'checkbox' ? node.checked : node.value));
}

test('AC1, DW-1624: Task details\u2019 Edit opens Edit task, four tabs drawing every value the task holds, its type and namespace read-only', async () => {
  const id = createProbe(EDITED);
  const { context, page } = await signedInAt(detailsUrl(id));
  try {
    await page.waitForFunction((name) => document.querySelector('app-task-details-page')?.textContent.includes(name), { timeout: config.navigationTimeoutMs }, EDITED);
    await page.evaluate((label) => Array.from(document.querySelectorAll('.ocu-details-link')).find((link) => link.textContent.trim() === label).click(), STRINGS.taskDetailsEdit);
    await page.waitForFunction((wanted) => new URL(window.location.href).pathname.endsWith(wanted), { timeout: config.navigationTimeoutMs }, `/tasks/schedule/edit/${id}`);
    await editorReady(page, EDITED);
    assert.deepEqual((await tabState(page)).map((tab) => tab.label), TAB_LABELS, 'four tabs named for the wizard\u2019s steps');
    for (const field of ['TaskClass', 'NameSpace']) {
      assert.equal(await page.$eval(`#ocu-task-${field}`, (node) => node.readOnly), true, `${field} is read-only`);
      assert.equal(await page.$eval(`#ocu-task-${field}-caption`, (node) => node.textContent.trim()), STRINGS.taskEditFixed, `${field} says why`);
    }
    const drawn = {};
    for (const field of ['Name', 'Description', 'NameSpace', 'Settings-KeepDays', 'TimePeriod', 'TimePeriodEvery', 'DailyFrequency', 'DailyIncrement', 'DailyStartTime', 'DailyEndTime', 'Priority', 'MirrorStatus', 'IsBatch', 'OpenOutputFile', 'OutputFilename', 'OutputFileIsBinary', 'EmailOutput', 'SuspendOnError', 'SuspendTerminated', 'RescheduleOnStart', 'EmailOnCompletion', 'EmailOnError', 'EmailOnExpiration']) {
      drawn[field] = await valueOf(page, `ocu-task-${field}`);
    }
    assert.deepEqual(
      drawn,
      {
        Name: EDITED,
        Description: 'OcuPilot edit probe',
        NameSpace: '%SYS',
        'Settings-KeepDays': '30',
        TimePeriod: 'Weekly',
        TimePeriodEvery: '1',
        DailyFrequency: 'Several',
        DailyIncrement: '30',
        DailyStartTime: '01:00',
        DailyEndTime: '05:00',
        Priority: 'Low',
        MirrorStatus: 'Any',
        IsBatch: true,
        OpenOutputFile: true,
        OutputFilename: 'ocup98edit.txt',
        OutputFileIsBinary: true,
        EmailOutput: true,
        SuspendOnError: true,
        SuspendTerminated: false,
        RescheduleOnStart: true,
        EmailOnCompletion: 'ops@example.com',
        EmailOnError: 'dev@example.com',
        EmailOnExpiration: 'late@example.com',
      },
      'every value the wizard-created task holds is drawn from the instance'
    );
    const days = await page.$$eval('.ocu-task-days input[type="checkbox"]', (boxes) => boxes.filter((box) => box.checked).map((box) => box.id));
    assert.deepEqual(days, ['ocu-task-TimePeriodDay-2', 'ocu-task-TimePeriodDay-4'], 'and its run days, Monday and Wednesday');
  } finally {
    await context.close();
  }
});

test('Matrix "Two-field save", AC2: Save answers "Saved", sends the two fields, and every other field reads back as it was', async () => {
  const id = createProbe('OcuP98BrowserTwo');
  const before = stored(id);
  assert.ok(before !== null, 'the probe reads back before the edit');
  const { context, page, writes } = await signedInAt(editUrl(id));
  try {
    await editorReady(page, 'OcuP98BrowserTwo');
    await fill(page, 'ocu-task-Description', 'two fields');
    await openTab(page, 'schedule');
    await setValue(page, 'ocu-task-DailyIncrement', '15');
    await save(page);
    assert.equal(await saved(page), STRINGS.formSaved, 'the Save is accepted');
    assert.equal(writes.length, 1, 'one Save');
    assert.deepEqual(JSON.parse(writes[0].body), { Description: 'two fields', DailyIncrement: '15' }, 'carrying the two fields alone');
    const after = stored(id);
    assert.ok(after !== null, 'the task reads back');
    assert.equal(`${after.Description}|${after.DailyIncrement}`, 'two fields|15', 'the two fields changed');
    for (const [key, value] of Object.entries(before)) {
      if (key === 'Description' || key === 'DailyIncrement') continue;
      assert.equal(after[key], value, `${key} reads back as it was`);
    }
  } finally {
    await context.close();
  }
});

// Integration. The `updated` publish itself is pinned by `task-wizard.store.spec.ts`: returning to
// either screen reads it again, so this leg stays green without the publish (measured) and pins what
// the person sees rather than which path brought it.
test('Integration, AD-14: a rename saved on Edit task shows on Task details and on Task schedule without a manual refresh', async () => {
  const id = createProbe('OcuP98BrowserRename');
  const { context, page } = await signedInAt(LIST_URL);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await page.type(FILTER_SELECTOR, 'OcuP98BrowserRe');
    await page.waitForFunction((selector, name) => Array.from(document.querySelectorAll(selector)).some((row) => row.textContent.includes(name)), { timeout: config.navigationTimeoutMs }, ROW_SELECTOR, 'OcuP98BrowserRename');
    await page.evaluate((name) => Array.from(document.querySelectorAll('[role="grid"] a')).find((link) => link.textContent.trim() === name).click(), 'OcuP98BrowserRename');
    await page.waitForFunction((wanted) => new URL(window.location.href).pathname.endsWith(wanted), { timeout: config.navigationTimeoutMs }, `/tasks/schedule/details/${id}`);
    await page.waitForFunction((name) => document.querySelector('app-task-details-page')?.textContent.includes(name), { timeout: config.navigationTimeoutMs }, 'OcuP98BrowserRename');
    await page.evaluate((label) => Array.from(document.querySelectorAll('.ocu-details-link')).find((link) => link.textContent.trim() === label).click(), STRINGS.taskDetailsEdit);
    await editorReady(page, 'OcuP98BrowserRename');
    await fill(page, 'ocu-task-Name', RENAMED);
    await save(page);
    assert.equal(await saved(page), STRINGS.formSaved, 'the rename is accepted');
    await page.goBack();
    await page.waitForFunction((name) => document.querySelector('app-task-details-page')?.textContent.includes(name), { timeout: config.navigationTimeoutMs }, RENAMED);
    await page.goBack();
    await page.waitForFunction((selector, name) => Array.from(document.querySelectorAll(selector)).some((row) => row.textContent.includes(name)), { timeout: config.navigationTimeoutMs }, ROW_SELECTOR, RENAMED);
    assert.equal(stored(id)?.Name, RENAMED, 'and the instance holds the new name');
  } finally {
    await context.close();
  }
});

// AC1. Mutation (Rule 19): skip `tabToOpen` in the editor's `afterRefusal` and redeploy -> the
// Options tab stays open and this goes red.
test('AC1: a refused Save opens the refused field\u2019s tab with its marker and focuses it; leaving with unsaved work asks first', async () => {
  const id = createProbe('OcuP98BrowserRefused');
  const { context, page, writes } = await signedInAt(editUrl(id));
  try {
    await editorReady(page, 'OcuP98BrowserRefused');
    await fill(page, 'ocu-task-Name', VENDOR.toLowerCase());
    await openTab(page, 'options');
    await save(page);
    await page.waitForSelector('.ocu-form-summary', { visible: true, timeout: config.navigationTimeoutMs });
    await page.waitForFunction(() => document.activeElement?.id === 'ocu-task-Name', { timeout: config.navigationTimeoutMs });
    const tabs = await tabState(page);
    assert.equal(tabs[0].selected, true, 'Basics opened');
    assert.equal(tabs[0].dot, true, 'with the destructive dot');
    assert.equal(tabs[0].name, `${STRINGS.taskStepBasics}, 1 error`, 'and its count in its accessible name');
    assert.equal(tabs[3].dot, false, 'Options carries none');
    const taken = irisSession([mark('REASON', '##class(OcuPilot.Api.Error).#REASONTASKNAMETAKEN')], ['REASON']).values.REASON;
    assert.equal(await page.$eval('#ocu-task-Name-reason', (node) => node.textContent.trim()), taken, 'refused on Name in the server\u2019s own sentence');
    assert.equal(stored(id)?.Name, 'OcuP98BrowserRefused', 'and nothing reached the instance');
    assert.ok(writes.length <= 1, 'at most the one refused Save');

    await page.click('.ocu-form-bar-actions .ocu-button-text');
    await page.waitForSelector('[role="dialog"] .ocu-dialog-title', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[role="dialog"] .ocu-dialog-title', (node) => node.textContent.trim()), STRINGS.formLeaveWithoutSaving);
    await (await page.$('[role="dialog"] .ocu-dialog-actions button')).click();
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    assert.ok(new URL(page.url()).pathname.endsWith(`/tasks/schedule/edit/${id}`), 'staying keeps the editor open');
    assert.equal(await valueOf(page, 'ocu-task-Name'), VENDOR.toLowerCase(), 'with the edit');
  } finally {
    await context.close();
  }
});

test('Matrix "Absent": a task the instance no longer holds reads "This task no longer exists."', async () => {
  const id = createProbe('OcuP98BrowserGone');
  irisSession([`Do ##class(${PROBE_CLASS}).Remove("${id}")`]);
  assert.equal(stored(id), null, 'the probe is gone');
  const { context, page } = await signedInAt(editUrl(id));
  try {
    await page.waitForFunction((text) => document.querySelector(`app-task-editor-page`)?.textContent.includes(text), { timeout: config.navigationTimeoutMs }, STRINGS.taskDetailsGone);
    assert.equal(await page.$(`${ROOT} .ocu-form-tab`), null, 'and draws no form');
  } finally {
    await context.close();
  }
});

test('the visual gate at 1440x900: on every tab each control is named and at least 24x24, nothing overflows, and the bar sits inside the content area', async () => {
  const id = createProbe('OcuP98BrowserVisual');
  const { context, page } = await signedInAt(editUrl(id));
  try {
    await page.setViewport({ width: 1440, height: 900 });
    await editorReady(page, 'OcuP98BrowserVisual');
    await openTab(page, 'options');
    await fill(page, 'ocu-task-RunAsUser', 'Admin');
    for (const key of TAB_KEYS) {
      await openTab(page, key);
      const report = await page.evaluate((root) => {
        const nameOf = (node) => {
          const labelled = node.getAttribute('aria-labelledby');
          if (labelled) return labelled.split(' ').map((item) => document.getElementById(item)?.textContent.trim() ?? '').join(' ').trim();
          if (node.getAttribute('aria-label')) return node.getAttribute('aria-label').trim();
          if (node.labels && node.labels.length > 0) return Array.from(node.labels).map((item) => item.textContent.trim()).join(' ');
          return node.textContent.trim();
        };
        const host = document.querySelector(root);
        const controls = Array.from(host.querySelectorAll('input, select, textarea, button')).filter((node) => node.offsetParent !== null);
        const unnamed = controls.filter((node) => nameOf(node) === '').map((node) => node.outerHTML.slice(0, 120));
        // A checkbox wrapped in its label is targeted through the label, so the label is what is measured.
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
      assert.ok(report.controls > 3, `${key}: the gate looked at the editor's controls: ${report.controls}`);
      assert.deepEqual(report.unnamed, [], `${key}: every control has an accessible name`);
      assert.deepEqual(report.small, [], `${key}: none is smaller than 24x24 or narrower than its declared minimum`);
      assert.deepEqual(report.overflowing, [], `${key}: nothing overflows its container`);
      assert.equal(report.pageOverflow, false, `${key}: and the page does not scroll sideways`);
      assert.ok(report.barBottom !== null && report.barBottom <= report.contentBottom + 1, `${key}: the bar sits inside the content area: ${JSON.stringify(report)}`);
    }
  } finally {
    await context.close();
  }
});

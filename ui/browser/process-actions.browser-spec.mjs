/**
 * Story 7.8 end to end in a real browser against the throwaway instance: Suspend, Resume and
 * Terminate on Processes, and the flagged Terminate on Process details, on probe processes of this
 * spec's own (`OcuPilot.Test.ProcessControl`'s untrapped probe, a `JOB` that waits).
 *
 * **It terminates processes.** It refuses outright to run outside a `-ci` throwaway, it starts each
 * probe it acts on, and it never acts on a daemon, the Task Manager, a Work Queue worker or an
 * OcuPilot process. Its `after` hook ends every probe it started and deletes any `<RESJOB>` entry
 * one left.
 *
 * **What only a browser can answer here:** that Suspend and Resume open no dialog and the row's
 * `State` re-reads in place (the Integration AC: `ListPage` consuming the `process` change event),
 * that Terminate's dialog names the pid and releases only on it while the list auto-refreshes
 * under it, and that Process details consumes the same event and reads the gone state.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test
 * browser/process-actions.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { escapeOs, markerValue, requireFreeSlot, runIris as sharedRunIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();

const LIST_URL = '/ocupilot/os-management/processes?ns=HSCUSTOM';
const ACTION_PATH = '/api/ocupilot/screens/osmgmt.processes/action';
const READ_PATH = '/api/ocupilot/screens/osmgmt.processes/read';
const FIXTURE = 'OcuPilot.Test.ProcessControl';

/** The declared `State` column's position. */
const STATE_CELL = 4;

/** The three drawn actions, in the order the list declares them; the flagged one is never drawn. */
const ACTIONS = [STRINGS.actionSuspend, STRINGS.actionResume, STRINGS.actionTerminate];

let browser = null;
const started = [];

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec terminates processes, so it never runs inside the live container');
  assert.match(
    config.container,
    /-ci$/,
    `this spec terminates processes on the instance, so it runs only in a throwaway; ${config.container} is not one`
  );
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (!/-ci$/.test(config.container)) return;
  // Every probe is stopped and cleaned before anything is asserted, so one probe's failure never
  // leaves the others running.
  const left = [];
  for (const { pid, namespace } of started) {
    const output = runIris([
      `Do ##class(${FIXTURE}).StopProbeProcess("${escapeOs(pid)}")`,
      `Do ##class(${FIXTURE}).DeleteResjob("${escapeOs(namespace)}","${escapeOs(pid)}")`,
      `Write "OCU-PAGONE-START:"_##class(${FIXTURE}).ProcessState("${escapeOs(pid)}")_"|"_##class(${FIXTURE}).ResjobCount("${escapeOs(namespace)}","${escapeOs(pid)}")_":OCU-PAGONE-END",!`,
    ]);
    if (markerValue(output, 'PAGONE') !== '|0') left.push(`probe ${pid}: ${output}`);
  }
  assert.deepEqual(left, [], 'every probe is gone and left no <RESJOB> entry');
});

function runIris(lines) {
  return sharedRunIris(config.container, lines);
}

/** Start a probe process of this spec's own, and answer its pid and namespace. */
function startProbe() {
  const output = runIris([
    `Set pid=##class(${FIXTURE}).StartUntrappedProbeProcess()`,
    `Write "OCU-PAPID-START:"_pid_"|"_##class(${FIXTURE}).NamespaceOf(pid)_":OCU-PAPID-END",!`,
  ]);
  const [pid, namespace] = (markerValue(output, 'PAPID') ?? '|').split('|');
  assert.notEqual(pid, '', `a probe process of this spec's own is running: ${output}`);
  started.push({ pid, namespace });
  assert.notEqual(namespace, '', `and its namespace reads, so a <RESJOB> count is taken from a real log: ${output}`);
  return { pid, namespace };
}

function processState(pid) {
  const output = runIris([`Write "OCU-PASTATE-START:"_##class(${FIXTURE}).ProcessState("${escapeOs(pid)}")_":OCU-PASTATE-END",!`]);
  return markerValue(output, 'PASTATE') ?? '';
}

function awaitGone(pid) {
  const output = runIris([`Write "OCU-PAGONE1-START:"_##class(${FIXTURE}).AwaitGone("${escapeOs(pid)}")_":OCU-PAGONE1-END",!`]);
  return markerValue(output, 'PAGONE1') === '1';
}

function resjob(namespace, pid, wait) {
  const method = wait ? 'AwaitResjob' : 'ResjobCount';
  const output = runIris([
    `Write "OCU-PARES-START:"_##class(${FIXTURE}).${method}("${escapeOs(namespace)}","${escapeOs(pid)}")_":OCU-PARES-END",!`,
  ]);
  return markerValue(output, 'PARES') ?? '';
}

function deleteResjob(namespace, pid) {
  const output = runIris([
    `Set sc=##class(${FIXTURE}).DeleteResjob("${escapeOs(namespace)}","${escapeOs(pid)}")`,
    `Write "OCU-PADEL-START:"_$System.Status.IsOK(sc)_"|"_##class(${FIXTURE}).ResjobCount("${escapeOs(namespace)}","${escapeOs(pid)}")_":OCU-PADEL-END",!`,
  ]);
  return markerValue(output, 'PADEL') ?? '';
}

/** A signed-in page at `url`, recording every POST to the action route and every list read. */
async function signedInRecording(url) {
  await requireFreeSlot(config);
  const { context, page } = await signedInAt(browser, config, url);
  const posts = [];
  const reads = [];
  page.on('request', (request) => {
    const path = new URL(request.url()).pathname;
    if (path === ACTION_PATH) posts.push({ method: request.method(), body: request.postData() ?? '' });
    if (path === READ_PATH) reads.push(request.url());
  });
  let dialogs = 0;
  page.on('dialog', async (dialog) => {
    dialogs += 1;
    await dialog.dismiss();
  });
  return { context, page, posts, reads, browserDialogs: () => dialogs };
}

/** The row whose Process ID cell reads `pid`, cell by cell, or `null` while it is not rendered. */
function rowFor(page, pid) {
  return page.evaluate(
    (selector, wanted) => {
      const row = Array.from(document.querySelectorAll(selector)).find(
        (candidate) => (candidate.querySelector('[role="gridcell"] .ocu-data-table-link, [role="gridcell"] .ocu-data-table-text')?.textContent ?? '').trim() === wanted
      );
      if (row === undefined) return null;
      return {
        cells: Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim()),
        selected: row.getAttribute('aria-selected') === 'true',
        changed: row.classList.contains('ocu-data-table-row-changed'),
      };
    },
    ROW_SELECTOR,
    pid
  );
}

/** Filter the list to `pid` and select its row. */
async function selectPid(page, pid) {
  await waitForRows(page, config.navigationTimeoutMs);
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, pid);
  await page.waitForFunction(
    (selector, wanted) =>
      Array.from(document.querySelectorAll(selector)).some(
        (row) => (row.querySelector('[role="gridcell"] .ocu-data-table-link, [role="gridcell"] .ocu-data-table-text')?.textContent ?? '').trim() === wanted
      ),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    pid
  );
  await clickRowCentre(page, { text: pid });
  await page.waitForFunction(
    (selector) => Array.from(document.querySelectorAll(selector)).some((row) => row.getAttribute('aria-selected') === 'true'),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR
  );
}

/** The command bar's actions, Refresh aside. */
function commandBar(page) {
  return page.$$eval('.ocu-command-bar-action', (buttons) =>
    buttons.filter((button) => !button.classList.contains('ocu-command-bar-refresh-action')).map((button) => button.textContent.trim())
  );
}

async function pressBar(page, label) {
  await page.evaluate((wanted) => {
    const buttons = Array.from(document.querySelectorAll('.ocu-command-bar-action'));
    buttons.find((button) => button.textContent.trim() === wanted).click();
  }, label);
}

async function openRowMenu(page) {
  await page.evaluate(() => {
    const row = Array.from(document.querySelectorAll('[role="grid"] .ocu-data-table-body [role="row"]')).find(
      (candidate) => candidate.getAttribute('aria-selected') === 'true'
    );
    row.querySelector('.ocu-data-table-trigger').click();
  });
  await page.waitForSelector('[role="menu"]', { timeout: config.navigationTimeoutMs });
  return page.$$eval('[role="menu"] [role="menuitem"]', (items) =>
    items.map((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() ?? '')
  );
}

async function chooseMenu(page, label) {
  await page.evaluate((wanted) => {
    const items = Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'));
    items.find((item) => item.textContent.trim().startsWith(wanted)).click();
  }, label);
}

/** Wait until the row for `pid` is marked changed and its State cell does, or does not, read suspended. */
async function waitForState(page, pid, suspended) {
  await page.waitForFunction(
    (selector, wanted, at, susp) => {
      const row = Array.from(document.querySelectorAll(selector)).find(
        (candidate) => (candidate.querySelector('[role="gridcell"] .ocu-data-table-link, [role="gridcell"] .ocu-data-table-text')?.textContent ?? '').trim() === wanted
      );
      if (row === undefined || !row.classList.contains('ocu-data-table-row-changed')) return false;
      const state = (row.querySelectorAll('[role="gridcell"]')[at]?.textContent ?? '').trim();
      return state !== '' && state.includes('SUSP') === susp;
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    pid,
    STATE_CELL,
    suspended
  );
}

function noDialog(page) {
  return page.evaluate(
    () => document.querySelector('app-typed-name-dialog, app-warning-dialog, [role="dialog"], [role="alertdialog"]') === null
  );
}

/** Wait until the list has issued a read after `count` and the status-bar stamp has moved off `stamp`. */
async function waitPastTick(page, reads, count, stamp) {
  const deadline = Date.now() + config.navigationTimeoutMs;
  while (reads.length <= count && Date.now() < deadline) await new Promise((resolve) => setTimeout(resolve, 250));
  assert.ok(reads.length > count, `an auto-refresh tick read the list: ${reads.length} against ${count}`);
  await page.waitForFunction(
    (was) => (document.querySelector('.ocu-status-bar-stamp')?.textContent?.trim() ?? '') !== was,
    { timeout: config.navigationTimeoutMs },
    stamp
  );
}

function stampOf(page) {
  return page.evaluate(() => document.querySelector('.ocu-status-bar-stamp')?.textContent?.trim() ?? '');
}

test('AC4, Integration AC: Suspend then Resume from the row menu open no dialog and re-read the State cell', async () => {
  // Mutation (Rule 19): set `ProcessSuspend.SCREENACTIONS` to "" and reload -> the route answers
  // 404 to Suspend and the State cell never reads suspended.
  const { pid } = startProbe();
  const { context, page, posts, browserDialogs } = await signedInRecording(LIST_URL);
  try {
    await selectPid(page, pid);
    assert.deepEqual(await commandBar(page), ACTIONS, 'the command bar offers Suspend, Resume and Terminate');
    assert.deepEqual(await openRowMenu(page), ACTIONS, 'and so does the row menu, destructive last');

    await chooseMenu(page, STRINGS.actionSuspend);
    await waitForState(page, pid, true);
    assert.equal(await noDialog(page), true, 'Suspend opens no dialog');
    assert.equal(browserDialogs(), 0, 'and no browser dialog either');
    assert.equal(posts.length, 1, `one request: ${JSON.stringify(posts)}`);
    assert.deepEqual(JSON.parse(posts[0].body), { action: 'suspend', id: pid });
    assert.ok(processState(pid).includes('SUSP'), 'the instance reads the probe suspended');
    assert.equal(await page.$eval(FILTER_SELECTOR, (field) => field.value), pid, 'the filter survived');
    assert.equal((await rowFor(page, pid)).selected, true, 'and so did the selection');

    await openRowMenu(page);
    await chooseMenu(page, STRINGS.actionResume);
    await waitForState(page, pid, false);
    assert.equal(await noDialog(page), true, 'Resume opens no dialog');
    assert.equal(posts.length, 2, `two requests: ${JSON.stringify(posts)}`);
    assert.deepEqual(JSON.parse(posts[1].body), { action: 'resume', id: pid });
    assert.ok(!processState(pid).includes('SUSP'), 'and the instance reads it running again');
  } finally {
    await context.close();
  }
});

test('AC1: Terminate from the command bar at 5 s names the pid, sends nothing on a mismatch, survives a tick, and the row leaves', async () => {
  // Mutation (Rule 19): drop `terminate` from `DESTRUCTIVE_ACTIONS`, rebuild and redeploy -> the
  // terminate is sent at once with no dialog and the dialog wait goes red.
  const { pid, namespace } = startProbe();
  const { context, page, posts, reads } = await signedInRecording(LIST_URL);
  try {
    await selectPid(page, pid);
    const chip = await page.$('.ocu-command-bar-refresh');
    assert.ok(chip !== null, 'the list carries the auto-refresh chip');
    await chip.click();
    await page.waitForFunction(
      () => document.querySelector('.ocu-command-bar-refresh').textContent.trim() === 'Auto-refresh: every 5 s',
      { timeout: config.navigationTimeoutMs }
    );

    await pressBar(page, STRINGS.actionTerminate);
    await page.waitForSelector('app-typed-name-dialog', { timeout: config.navigationTimeoutMs });
    const opened = await page.evaluate(() => ({
      title: document.querySelector('.ocu-dialog-title').textContent.trim(),
      consequence: document.querySelector('.ocu-typed-name-consequence').textContent.trim(),
      flag: document.querySelector('[data-slot="flag"]')?.textContent.trim() ?? null,
      checked: document.querySelector('[data-slot="flag"] input')?.checked ?? null,
      released: document.querySelector('.ocu-button-destructive').getAttribute('aria-disabled'),
    }));
    assert.equal(opened.title, `${STRINGS.actionTerminate} ${pid}`, 'the title names the pid');
    assert.equal(opened.consequence, STRINGS.processTerminateConsequence, 'the body states the consequence');
    assert.equal(opened.flag, STRINGS.processTerminateErrorFlag, 'the error-to-job flag is offered');
    assert.equal(opened.checked, false, 'unchecked');
    assert.equal(opened.released, 'true', 'and the button is aria-disabled until the pid is typed');

    // A mismatch sends nothing.
    await page.type('.ocu-typed-name-field', `${pid}0`);
    await page.evaluate(() => document.querySelector('.ocu-typed-name-field').blur());
    await page.waitForSelector('.ocu-typed-name-mismatch', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-typed-name-mismatch', (node) => node.textContent.trim()), STRINGS.formTypedNameMismatch);
    await page.focus('.ocu-typed-name-field');
    await page.keyboard.press('Enter');
    await page.click('.ocu-button-destructive');
    assert.equal(posts.length, 0, 'a mismatched pid sends nothing');

    // DW-1155's premise: a tick lands while the dialog is open, and the click after it is not lost.
    await waitPastTick(page, reads, reads.length, await stampOf(page));
    assert.ok(await page.$('app-typed-name-dialog'), 'the dialog is still open after the tick');

    await page.click('.ocu-typed-name-field', { clickCount: 3 });
    await page.keyboard.press('Backspace');
    await page.type('.ocu-typed-name-field', pid);
    await page.waitForFunction(
      () => document.querySelector('.ocu-button-destructive')?.getAttribute('aria-disabled') === null,
      { timeout: config.navigationTimeoutMs }
    );
    await page.click('.ocu-button-destructive');
    await page.waitForFunction(
      (selector, wanted) =>
        !Array.from(document.querySelectorAll(selector)).some(
          (row) => (row.querySelector('[role="gridcell"] .ocu-data-table-link, [role="gridcell"] .ocu-data-table-text')?.textContent ?? '').trim() === wanted
        ),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      pid
    );
    assert.equal(posts.length, 1, `exactly one request: ${JSON.stringify(posts)}`);
    assert.deepEqual(JSON.parse(posts[0].body), { action: 'terminate', id: pid }, 'the unchecked flag sends the plain terminate');
    assert.equal(awaitGone(pid), true, 'the instance no longer carries the process');
    assert.equal(resjob(namespace, pid, false), '0', 'and it logged no <RESJOB> entry');
  } finally {
    await context.close();
  }
});

test('AC1, Integration AC: the flagged Terminate from Process details ends the probe, reads the gone state, and logs one <RESJOB> entry', async () => {
  // Mutation (Rule 19): make `ProcessPort.TerminateWithError` call `Terminate(0)` -> the one-entry
  // assertion goes red.
  const { pid, namespace } = startProbe();
  const { context, page, posts } = await signedInRecording(`/ocupilot/os-management/processes/details/${encodeURIComponent(pid)}?ns=HSCUSTOM`);
  try {
    await page.waitForSelector('.ocu-details-fields', { timeout: config.navigationTimeoutMs });
    await page.waitForFunction((expected) => {
      const buttons = Array.from(document.querySelectorAll('.ocu-command-bar-action'))
        .filter((button) => !button.classList.contains('ocu-command-bar-refresh-action'))
        .map((button) => button.textContent.trim());
      return JSON.stringify(buttons) === JSON.stringify(expected);
    }, { timeout: config.navigationTimeoutMs }, ACTIONS);

    await pressBar(page, STRINGS.actionTerminate);
    await page.waitForSelector('app-typed-name-dialog [data-slot="flag"] input', { timeout: config.navigationTimeoutMs });
    assert.equal(
      await page.$eval('.ocu-dialog-title', (node) => node.textContent.trim()),
      `${STRINGS.actionTerminate} ${pid}`,
      'the title names the pid'
    );
    await page.click('app-typed-name-dialog [data-slot="flag"] input');
    assert.equal(await page.$eval('[data-slot="flag"] input', (box) => box.checked), true, 'the flag is checked');
    await page.type('.ocu-typed-name-field', pid);
    await page.waitForFunction(
      () => document.querySelector('.ocu-button-destructive')?.getAttribute('aria-disabled') === null,
      { timeout: config.navigationTimeoutMs }
    );
    await page.click('.ocu-button-destructive');
    await page.waitForFunction(
      (gone) => document.querySelector('.ocu-details-page')?.textContent.includes(gone) === true,
      { timeout: config.navigationTimeoutMs },
      STRINGS.processDetailsGone
    );
    assert.equal(posts.length, 1, `exactly one request, to the processes list's route: ${JSON.stringify(posts)}`);
    assert.deepEqual(JSON.parse(posts[0].body), { action: 'terminate-with-error', id: pid }, 'the checked flag sends the flagged terminate');
    assert.equal(awaitGone(pid), true, 'the instance no longer carries the process');
    assert.equal(resjob(namespace, pid, true), '1', `the process logged exactly one <RESJOB> entry in ${namespace}`);
    assert.equal(deleteResjob(namespace, pid), '1|0', 'which is deleted');
  } finally {
    await context.close();
  }
});

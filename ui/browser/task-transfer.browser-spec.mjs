/**
 * Story 16.4 in a real browser, against the throwaway instance: Task schedule's Export and Import
 * dialogs (AD-5, AD-21, AD-53).
 *
 * What it pins: Export on a probe task this spec made, through the dialog's server-path picker,
 * writes the task's file and the status line reads its done line; a second Export onto the same name
 * replaces the file, with the replace line shown; a name that is a directory reads PATH.EXISTS's
 * reason on the file field with the dialog kept open; once the task is deleted, the screen-level
 * Import of that file lists it again and its Task details show the same schedule; and both dialogs
 * pass the structural and contrast checks at 1280 light, 720 light and 1280 dark with no entry beyond
 * the baseline (DW-1337).
 *
 * **It writes tasks and files.** Every one is named `OcuP164*` or sits in the `OcuP164` directory
 * under the first allowed root (`OcuPilot.Test.TaskTransferFixture`), and `after` removes them all
 * whatever the tests answered, so it runs on a throwaway only.
 *
 * Run: `node --test --test-concurrency=1 browser/task-transfer.browser-spec.mjs` (after
 * `npm run build`, the bundle copied into the throwaway, and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { markerValue, requireFreeSlot, runIris as sharedRunIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const ROUTE = 'tasks/schedule';
const LIST_URL = `/ocupilot/${ROUTE}?ns=HSCUSTOM`;
const ACTION_PATH = '/api/ocupilot/screens/tasks.schedule/action';
const FIXTURE = 'OcuPilot.Test.TaskTransferFixture';
const TASK = 'OcuP164Browser';
const FILE = 'OcuP164/browser.xml';

let browser = null;
let taskId = '';
let root = '';

function runIris(lines) {
  return sharedRunIris(config.container, lines);
}

/** Make the probe task, every third day from the day after tomorrow, every 45 minutes from 01:00 to 02:00. */
function makeTask() {
  const output = runIris([
    'Set $NAMESPACE="%SYS" Set t=##class(%SYS.Task).%New()',
    `Set t.Name="${TASK}",t.NameSpace="%SYS",t.TaskClass="%SYS.Task.PurgeTaskHistory",t.TimePeriod=0,t.TimePeriodEvery=3,t.DailyFrequency=1,t.DailyFrequencyTime=0,t.DailyIncrement=45,t.DailyStartTime=3600,t.DailyEndTime=7200,t.StartDate=+$Horolog+2,t.RunAsUser="_SYSTEM",t.Description="OcuPilot Story 16.4 browser probe"`,
    'Set sc=t.%Save() Write "OCU-XFERID-START:"_$Select($System.Status.IsOK(sc):t.%Id(),1:"")_":OCU-XFERID-END",!',
  ]);
  return markerValue(output, 'XFERID') ?? '';
}

/** The probe task's id now, or `''`. */
function probeId() {
  const output = runIris([`Do ##class(${FIXTURE}).Probes(.ids) Write "OCU-XFERNOW-START:"_$Get(ids("${TASK}"))_":OCU-XFERNOW-END",!`]);
  return markerValue(output, 'XFERNOW') ?? '';
}

/** The probe file `name` under the probe directory: its task count, whether it names the probe task, and whether it holds the stale marker. */
function fileHolds(name) {
  const output = runIris([
    `Set text=##class(${FIXTURE}).FileText(##class(${FIXTURE}).ProbeDirectory()_"${name}")`,
    'Write "OCU-XFERFILE-START:"_($Length(text,"<Task>")-1)_"|"_(text["<Name>' + TASK + '</Name>")_"|"_(text["OcuP164 stale")_":OCU-XFERFILE-END",!',
  ]);
  const [tasks, named, stale] = (markerValue(output, 'XFERFILE') ?? '0|0|0').split('|');
  return { tasks: Number(tasks), named: named === '1', stale: stale === '1' };
}

/** The published reason one server code carries. */
function serverReason(parameter) {
  const output = runIris([`Write "OCU-XFERREASON-START:"_$Parameter("OcuPilot.Api.Error","${parameter}")_":OCU-XFERREASON-END",!`]);
  return markerValue(output, 'XFERREASON') ?? '';
}

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/**
 * The DW-1337 walk of the screen with a dialog open, at 1280 light, 720 light and 1280 dark,
 * answering every entry the baseline does not already hold, with the dialog's body held to scrolling
 * nothing sideways.
 */
async function structural(page) {
  const found = [];
  const passes = [
    { viewport: VIEWPORTS.wide, theme: 'light', checks: INVARIANTS },
    { viewport: VIEWPORTS.narrow, theme: 'light', checks: ['name', 'min-width', 'overflow'] },
    { viewport: VIEWPORTS.wide, theme: 'dark', checks: ['contrast'] },
  ];
  const minimums = componentMinimums();
  const surfaces = {};
  for (const { viewport, theme, checks } of passes) {
    await page.setViewport(viewport);
    await page.evaluate((dark) => document.documentElement.classList.toggle('ocu-theme-dark', dark), theme === 'dark');
    await frames(page);
    surfaces[theme] = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
    const { entries } = await detectScreen(page, { route: ROUTE, checks, viewport: viewport.width, theme, minimums });
    found.push(...entries);
    const body = await page.$eval('.ocu-dialog-body', (element) => ({ scroll: element.scrollWidth, client: element.clientWidth }));
    assert.ok(body.scroll <= body.client, `the dialog body does not scroll sideways at ${viewport.width}px ${theme}: ${JSON.stringify(body)}`);
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await frames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  return compare(collapse(found), readBaseline()?.entries ?? []).fresh.map((entry) => `${entry.key}: ${entry.measured}`);
}

/** Signed in at the list with its rows rendered, recording every request to the action route. */
async function atList() {
  await requireFreeSlot(config);
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const posts = [];
  page.on('request', (request) => {
    if (new URL(request.url()).pathname === ACTION_PATH) posts.push({ method: request.method(), body: request.postData() ?? '' });
  });
  await waitForRows(page, config.navigationTimeoutMs);
  return { context, page, posts };
}

/** Filter the list to the probe task and select its row. */
async function selectProbe(page) {
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, TASK);
  await page.waitForFunction(
    (selector, wanted) =>
      Array.from(document.querySelectorAll(selector)).some((row) => {
        const cell = row.querySelector('[role="gridcell"]');
        return ((cell?.querySelector('.ocu-data-table-link, .ocu-data-table-text') ?? cell)?.textContent ?? '').trim() === wanted;
      }),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    TASK
  );
  await clickRowCentre(page, { text: TASK });
  await page.waitForFunction(
    (selector) => Array.from(document.querySelectorAll(selector)).some((row) => row.getAttribute('aria-selected') === 'true'),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR
  );
}

/** Press the command-bar action labelled `label`, and wait for a dialog. */
async function openFromBar(page, label) {
  await page.evaluate((wanted) => {
    Array.from(document.querySelectorAll('.ocu-command-bar-action'))
      .find((button) => button.textContent.trim() === wanted)
      .click();
  }, label);
  await page.waitForSelector('[role="dialog"] select', { timeout: config.navigationTimeoutMs });
}

/** Choose the probe's root in the open dialog, type `name`, and press `confirm`. */
async function submitFile(page, name, confirm) {
  await page.select('[role="dialog"] select', root);
  await page.click('[role="dialog"] input.ocu-field-input', { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type('[role="dialog"] input.ocu-field-input', name);
  await page.click(confirm);
}

/** The status line above the list, once it reads `wanted`. */
async function waitForStatus(page, wanted) {
  await page.waitForFunction(
    (text) => document.querySelector('[data-task-transfer-status]')?.textContent.trim() === text,
    { timeout: config.navigationTimeoutMs },
    wanted
  );
}

/** The probe's schedule as its Task details page shows it: how often, and the time of day. */
async function detailsSchedule(id) {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/tasks/schedule/details/${encodeURIComponent(id)}?ns=HSCUSTOM`, VIEWPORTS.wide);
  try {
    await page.waitForSelector('.ocu-details-schedule .ocu-details-field-value', { timeout: config.navigationTimeoutMs });
    return await page.$$eval('.ocu-details-schedule .ocu-details-field-value', (nodes) => nodes.map((node) => node.textContent.trim()));
  } finally {
    await context.close();
  }
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec writes tasks and files, so it never runs inside the live container');
  assert.match(config.container, /-ci$/, `this spec writes tasks and files, so it runs only in a throwaway; ${config.container} is not one`);
  await assertThrowaway(config);
  runIris([`Do ##class(${FIXTURE}).RemoveProbes()`]);
  taskId = makeTask();
  assert.notEqual(taskId, '', 'the probe task is made');
  const output = runIris([`Write "OCU-XFERROOT-START:"_##class(${FIXTURE}).FirstRoot()_"|"_##class(${FIXTURE}).ProbeDirectory()_":OCU-XFERROOT-END",!`]);
  root = (markerValue(output, 'XFERROOT') ?? '').split('|')[0];
  assert.notEqual(root, '', 'the first allowed root reads');
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    const output = runIris([`Set sc=##class(${FIXTURE}).RemoveProbes() Write "OCU-XFERGONE-START:"_$System.Status.IsOK(sc)_"|"_##class(${FIXTURE}).Probes()_":OCU-XFERGONE-END",!`]);
    assert.equal(markerValue(output, 'XFERGONE'), '1|0', `every probe task and file is removed: ${output}`);
  } finally {
    if (browser !== null) await browser.close();
  }
});

// Mutation (Rule 19): the page's `sendFor` omits `path`, then rebuild and redeploy -> the route refuses
// the request and the export leg goes red.
test('Export writes the task, a second Export replaces the file, and a directory under the name is refused on the file field', async () => {
  const { context, page, posts } = await atList();
  try {
    await selectProbe(page);
    await openFromBar(page, STRINGS.taskExportAction);
    assert.equal(await page.$eval('.ocu-dialog-title', (title) => title.textContent.trim()), STRINGS.taskExportTitle.replace('<task>', TASK), 'the dialog names the task');
    assert.equal(await page.$eval('[data-task-export-replaces]', (line) => line.textContent.trim()), STRINGS.taskExportReplaces, 'and says a file at the name is replaced');
    await submitFile(page, FILE, '[data-task-export-confirm]');
    await waitForStatus(page, STRINGS.taskExportDone.replace('<task>', TASK).replace('<path>', `${root}${FILE}`));
    assert.equal(posts.length, 1, `one request: ${JSON.stringify(posts)}`);
    assert.deepEqual(JSON.parse(posts[0].body), { action: 'export', id: taskId, values: { root, path: FILE } }, 'the task, the root and the name');
    assert.deepEqual(fileHolds('browser.xml'), { tasks: 1, named: true, stale: false }, 'the file holds exactly the task');

    runIris([`Do ##class(${FIXTURE}).WriteFile(##class(${FIXTURE}).ProbeDirectory()_"browser.xml","OcuP164 stale")`]);
    await openFromBar(page, STRINGS.taskExportAction);
    await submitFile(page, FILE, '[data-task-export-confirm]');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    assert.deepEqual(fileHolds('browser.xml'), { tasks: 1, named: true, stale: false }, 'a second Export replaces the file');

    runIris([`Do ##class(%File).CreateDirectoryChain(##class(${FIXTURE}).ProbeDirectory()_"adir")`]);
    await openFromBar(page, STRINGS.taskExportAction);
    await submitFile(page, 'OcuP164/adir', '[data-task-export-confirm]');
    const reason = serverReason('REASONPATHEXISTS');
    await page.waitForFunction((text) => document.querySelector('[role="dialog"] .ocu-form-error')?.textContent.trim() === text, { timeout: config.navigationTimeoutMs }, reason);
    assert.equal(await page.$eval('[role="dialog"] input.ocu-field-input', (input) => input.getAttribute('aria-invalid')), 'true', 'on the file field, with the dialog kept open');
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): drop the page's registration of the screen-level Import, then rebuild and
// redeploy -> no surface offers Import and this goes red.
test('once the task is deleted, Import of its file lists it again with the same schedule on its Task details', async () => {
  const schedule = await detailsSchedule(taskId);
  assert.equal(schedule.length, 2, `the task's details show how often and when: ${JSON.stringify(schedule)}`);
  runIris([`Do ##class(${FIXTURE}).RemoveTask(${taskId})`]);
  assert.equal(probeId(), '', 'the task is deleted');
  const { context, page, posts } = await atList();
  try {
    await openFromBar(page, STRINGS.actionImport);
    assert.equal(await page.$eval('.ocu-dialog-title', (title) => title.textContent.trim()), STRINGS.taskImportTitle, 'the dialog is titled Import tasks');
    await submitFile(page, FILE, '[data-task-import-confirm]');
    await waitForStatus(page, STRINGS.taskImportDone.replace('<path>', `${root}${FILE}`));
    assert.deepEqual(JSON.parse(posts[0].body), { action: 'import', id: 'import', values: { root, path: FILE } }, 'the import target, the root and the name');
    await selectProbe(page);
  } finally {
    await context.close();
  }
  const newId = probeId();
  assert.ok(newId !== '' && newId !== taskId, `the task is listed again under a new id: ${newId}`);
  assert.deepEqual(await detailsSchedule(newId), schedule, 'and its Task details show the same schedule');
  taskId = newId;
});

test('both dialogs pass the structural walk in both themes', async () => {
  const { context, page } = await atList();
  try {
    await selectProbe(page);
    await openFromBar(page, STRINGS.taskExportAction);
    assert.deepEqual(await structural(page), [], 'with the export dialog open, no violation beyond the baseline\'s entries');
    await page.click('.ocu-dialog-actions .ocu-button-secondary');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await openFromBar(page, STRINGS.actionImport);
    assert.deepEqual(await structural(page), [], 'with the import dialog open, no violation beyond the baseline\'s entries');
  } finally {
    await context.close();
  }
});

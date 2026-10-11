/**
 * Story 20.23 in a real browser, against the throwaway instance: Interoperability's Queues, Queue messages and Jobs
 * screens and their row actions (AD-5, AD-8, AD-44, AD-51, AD-53, AD-62).
 *
 * What it pins: in `USER`, whose probe production this spec creates afresh for each test, starts and hangs on a message
 * with two more waiting, Queues' Abort all asks for the queue's name typed, states what it takes, and empties the queue
 * while the message the job holds stays; Queue messages lists the two waiting messages, and Abort on one asks for its id
 * typed and leaves it Aborted beside the other; Abort message on the hung job, which is not retrying, is refused with the
 * published sentence and changes nothing; and Stop job warns first, ends the job, puts its message back on the queue and
 * takes the job's row off Jobs; and an item's Queue and Jobs tabs draw the same actions, post them to Queue messages' and
 * Jobs' routes, and show the same dialogs and the published sentence of a refusal.
 *
 * **It compiles, starts and writes a probe production in `USER`** through `OcuPilot.Test.ProductionProbe`, so it runs on a
 * throwaway only; the `after` hook stops and removes the production, its classes and its messages, whatever the tests
 * answered.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/interop-queue-job-actions.browser-spec.mjs` (after `npm run build` and the
 * bundle copied into the throwaway).
 */

import { test, before, beforeEach, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const PROBE = 'OcuPilot.Test.ProductionProbe';
const READ = 'OcuPilot.Test.InteropHostRead';
const QUEUE_CLASS = 'OcuPilot.Test.InteropQueueActions';
const OPERATION = 'OcuPilotProbeOp';
const ABORTED = '7';
const QUEUES_URL = '/ocupilot/interoperability/queues?ns=USER';
const JOBS_URL = '/ocupilot/interoperability/jobs?ns=USER';
const PRODUCTIONS_URL = '/ocupilot/interoperability/productions?ns=USER';
const PRODUCTION = 'OcuPilotProbe.Interop.Production';
const ITEMS = 'interoperability/productions/items';
const SUSPENDED = '5';
const ACTION_PATH = /^\/api\/ocupilot\/screens\/([^/]+)\/action$/;
const NAME_TEXT = '.ocu-data-table-link, .ocu-data-table-text';

let browser = null;
let created = false;
/** The ids of the three messages the probe was armed with, oldest first: the first is the one the job holds. */
let armedIds = [];

/** Remove any probe, create one and arm it: its operation hung on a message with two more waiting. Each test starts from this. */
function armFresh() {
  const removed = probe('QJCLEAN', `$System.Status.IsOK(##class(${PROBE}).Remove())`);
  assert.equal(removed.value, '1', `an earlier probe is removed: ${removed.output}`);
  created = true;
  const made = probe('QJMADE', `$System.Status.IsOK(##class(${PROBE}).Create())`);
  assert.equal(made.value, '1', `the probe production is created: ${made.output}`);
  const output = runIris(config.container, [`Set sc=##class(${READ}).ArmProbe(.ids)`, 'Write "OCU-QJARM-START:"_$System.Status.IsOK(sc)_"|"_ids_":OCU-QJARM-END",!']);
  const armed = markerValue(output, 'QJARM') ?? '';
  assert.match(armed, /^1\|\d+,\d+,\d+$/, `the probe production runs with its operation hung on a message and two waiting: ${output}`);
  armedIds = armed.split('|')[1].split(',');
}

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** The messages waiting in the probe operation's queue. */
function queueCount() {
  return probe('QCOUNT', `##class(${READ}).QueueCount()`).value;
}

/** The stored status of message header `id`. */
function headerStatus(id) {
  return probe('HSTATUS', `##class(${QUEUE_CLASS}).HeaderStatus("${id}")`).value;
}

/** Record the body of every action the page posts, with the screen it went to. */
function captureActions(page) {
  const posts = [];
  page.on('request', (request) => {
    const match = ACTION_PATH.exec(new URL(request.url()).pathname);
    if (match !== null && request.method() === 'POST') posts.push({ screen: match[1], ...JSON.parse(request.postData() ?? '{}') });
  });
  return posts;
}

/** The screen has answered the navigation map and drawn its rows. */
async function answered(page) {
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  await waitForRows(page, config.navigationTimeoutMs);
}

/** Every body row's cells, each as its trimmed text. */
function allRows(page) {
  return page.evaluate(
    (rowSelector) => Array.from(document.querySelectorAll(rowSelector)).map((row) => Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim())),
    ROW_SELECTOR
  );
}

/** Wait until the table holds a row whose name cell reads `name`, then answer that row's cells. */
async function rowNamed(page, name) {
  await page.waitForFunction(
    (rowSelector, wanted, textSelector) =>
      Array.from(document.querySelectorAll(rowSelector)).some((row) => {
        const cell = row.querySelector('[role="gridcell"]');
        return ((cell?.querySelector(textSelector) ?? cell)?.textContent ?? '').trim() === wanted;
      }),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name,
    NAME_TEXT
  );
  const rows = await allRows(page);
  return rows.find((cells) => cells[0] === name);
}

/** Wait until the body's rows read exactly `names` in their name cells, in any order. */
function rowsAre(page, names) {
  return page.waitForFunction(
    (rowSelector, wanted) => {
      const found = Array.from(document.querySelectorAll(rowSelector)).map((row) => row.querySelector('[role="gridcell"]')?.textContent.trim() ?? '');
      return found.length === wanted.length && [...found].sort().join('|') === [...wanted].sort().join('|');
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    names
  );
}

/** Replace the filter's text with `text`, and wait for the one row it leaves when `text` is not empty. */
async function filterTo(page, text) {
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  if (text === '') return;
  await page.type(FILTER_SELECTOR, text);
  await page.waitForFunction(
    (rowSelector, filterSelector, wanted) =>
      document.querySelector(filterSelector).value === wanted &&
      document.querySelectorAll(rowSelector).length === 1 &&
      document.querySelector(rowSelector).textContent.includes(wanted),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    FILTER_SELECTOR,
    text
  );
}

/** Narrow the list to `text`, select its one row on its cell `cell`, open its menu and choose the entry labeled `label`. */
async function rowAction(page, text, label, cell) {
  await filterTo(page, text);
  await clickRowCentre(page, { index: 0, cell });
  await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
  await page.evaluate((wanted) => {
    Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'))
      .find((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted)
      .click();
  }, label);
}

/** Open the probe operation from the Productions list and Production items, then the item strip's tab on `route`, and wait for its rows. */
async function openItemTab(page, route) {
  await answered(page);
  await clickRowCentre(page, { text: PRODUCTION, link: true });
  await pathHolds(page, `/${ITEMS}/`);
  await answered(page);
  await rowNamed(page, OPERATION);
  await clickRowCentre(page, { text: OPERATION, link: true });
  await pathHolds(page, `/${ITEMS}/document/`);
  await answered(page);
  await (await page.waitForSelector(`button.ocu-detail-tab[data-route="${route}"]`, { visible: true, timeout: config.navigationTimeoutMs })).click();
  await pathHolds(page, `/${route}/`);
  await answered(page);
}

/** Select the body row at `index` on its cell `cell` and open its menu; answer the labels of the entries it offers, in order. */
async function openRowMenu(page, index, cell) {
  await clickRowCentre(page, { index, cell });
  await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
  return page.$$eval('[role="menu"] [role="menuitem"] .ocu-data-table-menu-label', (nodes) => nodes.map((node) => node.textContent.trim()));
}

/** Choose the entry labeled `label` in the open row menu. */
function chooseMenuEntry(page, label) {
  return page.evaluate((wanted) => {
    Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'))
      .find((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted)
      .click();
  }, label);
}

/** The open typed-name dialog's title and consequence. */
async function typedNameDialog(page) {
  await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
  return page.evaluate(() => ({
    title: document.querySelector('[role="dialog"] .ocu-dialog-title').textContent.trim(),
    consequence: document.querySelector('.ocu-typed-name-consequence').textContent.trim(),
  }));
}

/** Type `name` into the open typed-name dialog and confirm it. */
async function typeAndConfirm(page, name) {
  await page.type('.ocu-typed-name-field', name);
  await page.keyboard.press('Enter');
}

/** Wait until no dialog is open. */
function dialogClosed(page) {
  return page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
}

/** Wait until the path holds `suffix`. */
function pathHolds(page, suffix) {
  return page.waitForFunction((wanted) => new URL(window.location.href).pathname.includes(wanted), { timeout: config.navigationTimeoutMs }, suffix);
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec compiles and starts a probe production, so it runs only in a throwaway; ${config.container} is not one`);
  browser = await puppeteer.launch(launchOptions(config));
});

beforeEach(() => {
  armFresh();
});

after(async () => {
  try {
    if (created && /-ci$/.test(config.container)) {
      const removed = probe('QJGONE', `$System.Status.IsOK(##class(${PROBE}).Remove())_##class(${PROBE}).Gone()`);
      assert.equal(removed.value, '11', `the probe production is removed: ${removed.output}`);
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

// AC2, AC7. Mutation (Rule 19): drop 'abort' from DESTRUCTIVE_ACTIONS, rebuild and redeploy -> Abort all opens a warning and
// the typed-name wait goes red; drop the Queues entry from SCREEN_ACTION_DESCRIPTORS -> the row offers no menu and the
// action wait goes red.
test('AC2, AC7: Abort all asks for the queue\'s name typed, states what it takes, and empties the queue but for the held message', async () => {
  const { context, page } = await signedInAt(browser, config, QUEUES_URL, VIEWPORTS.wide);
  const posts = captureActions(page);
  try {
    await answered(page);
    const queue = await rowNamed(page, OPERATION);
    assert.equal(queue[1], '2', 'the queue holds the two waiting messages');
    await rowAction(page, OPERATION, STRINGS.interopQueuesAbortAllAction, 1);
    const dialog = await typedNameDialog(page);
    assert.deepEqual(
      dialog,
      { title: `${STRINGS.interopQueuesAbortAllAction} ${OPERATION}`, consequence: STRINGS.interopQueueAbortConsequence },
      'Abort all asks for the queue\'s name and states what it takes'
    );
    assert.deepEqual(posts, [], 'nothing is sent while the dialog is open');
    await typeAndConfirm(page, OPERATION);
    await dialogClosed(page);
    assert.deepEqual(posts, [{ screen: 'interop.queues', action: 'abort', id: OPERATION }], 'one abort, sent with the queue\'s name once it matched');
    await page.waitForFunction(
      (rowSelector, wanted) => Array.from(document.querySelectorAll(rowSelector)).some((row) => row.textContent.includes(wanted) && row.querySelectorAll('[role="gridcell"]')[1]?.textContent.trim() === '0'),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      OPERATION
    );
    assert.equal(queueCount(), '0', 'the queue holds no message');
    for (const id of armedIds.slice(1)) assert.equal(headerStatus(id), ABORTED, `message ${id} reads Aborted`);
    assert.notEqual(headerStatus(armedIds[0]), ABORTED, 'and the message the job holds does not');
  } finally {
    await context.close();
  }
});

// AC1, AC7. Mutation (Rule 19): drop the Queue messages entry from TYPED_NAME_ROWS, rebuild and redeploy -> the dialog asks for
// the joined row key and the title assertion goes red; make `ABORTMESSAGE` skip the vendor call -> the header does not
// read Aborted and the status leg goes red.
test('AC1, AC7: Abort on a queued message asks for its id typed, aborts only that message and lists the other', async () => {
  const ids = armedIds.slice(1);
  assert.equal(queueCount(), '2', 'the two armed messages wait in the queue');
  const { context, page } = await signedInAt(browser, config, QUEUES_URL, VIEWPORTS.wide);
  const posts = captureActions(page);
  try {
    await answered(page);
    const queue = await rowNamed(page, OPERATION);
    assert.equal(queue[1], '2', 'the queue holds the two waiting messages');
    await clickRowCentre(page, { text: OPERATION, link: true });
    await pathHolds(page, '/interoperability/queues/messages/');
    await answered(page);
    const listed = await allRows(page);
    assert.deepEqual(listed.map((cells) => cells[0]).sort(), [...ids].sort(), 'Queue messages lists the two messages');
    await rowAction(page, ids[0], STRINGS.actionAbort, 1);
    const dialog = await typedNameDialog(page);
    assert.deepEqual(dialog, { title: `${STRINGS.actionAbort} ${ids[0]}`, consequence: STRINGS.interopMessageAbortConsequence }, 'Abort asks for the message id and states what it takes');
    assert.deepEqual(posts, [], 'nothing is sent while the dialog is open');
    await typeAndConfirm(page, ids[0]);
    await dialogClosed(page);
    assert.deepEqual(posts, [{ screen: 'interop.queuemessages', action: 'abort', id: ids[0] }], 'one abort, sent with the message id once it matched');
    await filterTo(page, '');
    await rowsAre(page, [ids[1]]);
    assert.equal(headerStatus(ids[0]), ABORTED, 'the aborted message reads Aborted');
    assert.notEqual(headerStatus(ids[1]), ABORTED, 'the other does not');
    assert.equal(queueCount(), '1', 'and one message waits in the queue');
  } finally {
    await context.close();
  }
});

// AC3, AC7. Mutation (Rule 19): drop `NOTRETRYING` from `RuntimeRefusal`, recompile the tree -> the abort is answered 200
// and the banner never shows the sentence; drop the Jobs entry from TYPED_NAME_ROWS, rebuild and redeploy -> the dialog
// title assertion goes red.
test('AC3, AC7: Abort message on a job that is not retrying shows the published sentence and changes nothing', async () => {
  const { context, page } = await signedInAt(browser, config, JOBS_URL, VIEWPORTS.wide);
  const posts = captureActions(page);
  try {
    await answered(page);
    await filterTo(page, OPERATION);
    const [job] = await allRows(page);
    assert.match(job[0], /^\d+$/, `the operation's job is listed by its process id: ${JSON.stringify(job)}`);
    const waiting = queueCount();
    await rowAction(page, OPERATION, STRINGS.interopJobsAbortAction, 1);
    const dialog = await typedNameDialog(page);
    assert.deepEqual(dialog, { title: `${STRINGS.interopJobsAbortAction} ${job[0]}`, consequence: STRINGS.interopJobAbortConsequence }, 'Abort message asks for the process id and states what it does');
    await typeAndConfirm(page, job[0]);
    await dialogClosed(page);
    await page.waitForSelector('.ocu-list-page-banner .ocu-banner-message', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-list-page-banner .ocu-banner-message', (node) => node.textContent.trim()), STRINGS.interopRefusalJobNotRetrying, 'the refusal shows the published sentence');
    assert.deepEqual(posts, [{ screen: 'interop.jobs', action: 'abort', id: job[0] }], 'one abort was sent');
    assert.notEqual(headerStatus(armedIds[0]), ABORTED, 'and the message the job holds is not aborted');
    assert.equal(queueCount(), waiting, 'the queue is as it was');
  } finally {
    await context.close();
  }
});

// AC4, AC7. Mutation (Rule 19): drop the Jobs entry from WARNING_CONSEQUENCES, rebuild and redeploy -> Stop job is sent at once
// and the warning wait goes red; pass `0` as the force argument of `Stop` in `VendorJob`, recompile the tree -> the hung job
// does not stop, the dialog stays and the row stays.
test('AC4, AC7: Stop job warns first, ends the hung job, puts its message back and takes the job\'s row off Jobs', async () => {
  const { context, page } = await signedInAt(browser, config, JOBS_URL, VIEWPORTS.wide);
  const posts = captureActions(page);
  try {
    await answered(page);
    await filterTo(page, OPERATION);
    const [job] = await allRows(page);
    const waiting = Number(queueCount());
    await rowAction(page, OPERATION, STRINGS.interopJobsStopAction, 1);
    await page.waitForSelector('app-warning-dialog', { timeout: config.navigationTimeoutMs });
    const opened = await page.evaluate(() => {
      const surface = document.querySelector('[role="dialog"]');
      return {
        title: (surface.querySelector('.ocu-dialog-title')?.textContent ?? '').trim(),
        body: (surface.querySelector('.ocu-warning-consequence')?.textContent ?? '').trim(),
        destructive: surface.querySelector('.ocu-button-destructive') !== null,
      };
    });
    assert.deepEqual(opened, { title: STRINGS.interopJobsStopAction, body: STRINGS.interopJobStopConsequence, destructive: false }, 'the warning is titled with the verb, states the published sentence and is not destructive');
    assert.deepEqual(posts, [], 'nothing is sent while the dialog is open');
    await page.click('[role="dialog"] .ocu-dialog-actions .ocu-button-primary');
    await dialogClosed(page);
    assert.deepEqual(posts, [{ screen: 'interop.jobs', action: 'stop', id: job[0] }], 'one stop, sent past Proceed');
    await filterTo(page, '');
    await page.waitForFunction(
      (rowSelector, wanted) => !Array.from(document.querySelectorAll(rowSelector)).some((row) => row.querySelector('[role="gridcell"]')?.textContent.trim() === wanted),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      job[0]
    );
    assert.equal(queueCount(), String(waiting + 1), 'the job\'s message is back on the queue beside the ones waiting');
  } finally {
    await context.close();
  }
});

// AC1, AC7. Mutation (Rule 19): drop the Queue tab from ACTION_ADDRESS, rebuild and redeploy -> the tab posts to its own screen
// and the post assertion goes red; drop its entry from SCREEN_ACTION_DESCRIPTORS -> the row offers no menu and the menu wait goes red.
test('AC1, AC7: an item\'s Queue tab draws Abort on a queued message, asks for its id typed and posts to Queue messages\' route', async () => {
  const ids = armedIds.slice(1);
  const { context, page } = await signedInAt(browser, config, PRODUCTIONS_URL, VIEWPORTS.wide);
  const posts = captureActions(page);
  try {
    await openItemTab(page, `${ITEMS}/queue`);
    const listed = await allRows(page);
    assert.deepEqual(listed.map((cells) => cells[0]).sort(), [...ids].sort(), 'the Queue tab lists the two waiting messages');
    assert.deepEqual(await openRowMenu(page, 0, 1), [STRINGS.actionAbort], 'a Queue tab row offers its one action: Abort');
    await chooseMenuEntry(page, STRINGS.actionAbort);
    const dialog = await typedNameDialog(page);
    const target = await page.$eval('[role="dialog"] .ocu-dialog-title', (node, skip) => node.textContent.trim().slice(skip), STRINGS.actionAbort.length + 1);
    assert.ok(ids.includes(target), `the dialog names the selected message by its id: ${dialog.title}`);
    assert.deepEqual(dialog, { title: `${STRINGS.actionAbort} ${target}`, consequence: STRINGS.interopMessageAbortConsequence }, 'Abort asks for the message id and states what it takes');
    assert.deepEqual(posts, [], 'nothing is sent while the dialog is open');
    await typeAndConfirm(page, target);
    await dialogClosed(page);
    assert.deepEqual(posts, [{ screen: 'interop.queuemessages', action: 'abort', id: target }], 'one abort, posted to Queue messages\' route once the id matched');
    const other = ids.find((id) => id !== target);
    await rowsAre(page, [other]);
    assert.equal(headerStatus(target), ABORTED, 'the aborted message reads Aborted');
    assert.notEqual(headerStatus(other), ABORTED, 'the other does not');
    assert.equal(queueCount(), '1', 'and one message waits in the queue');
  } finally {
    await context.close();
  }
});

// AC3, AC7. Mutation (Rule 19): drop the Jobs tab from ACTION_ADDRESS, rebuild and redeploy -> the tab posts to its own screen and
// the post assertion goes red; drop the Jobs entry from WARNING_CONSEQUENCES -> Suspend message is sent at once and the warning wait
// goes red; drop `NOTRETRYING` from `RuntimeRefusal`, recompile the tree -> the suspend is answered 200 and the banner never shows.
test('AC3, AC7: an item\'s Jobs tab offers Abort message, Suspend message and Stop job; Suspend warns, posts to the Jobs route and shows the refusal of a job not retrying', async () => {
  const { context, page } = await signedInAt(browser, config, PRODUCTIONS_URL, VIEWPORTS.wide);
  const posts = captureActions(page);
  try {
    await openItemTab(page, `${ITEMS}/jobs`);
    const [job] = await allRows(page);
    assert.match(job[0], /^\d+$/, `the Jobs tab lists the operation's job by its process id: ${JSON.stringify(job)}`);
    const waiting = queueCount();
    assert.deepEqual(await openRowMenu(page, 0, 1), [STRINGS.interopJobsAbortAction, STRINGS.interopJobsSuspendAction, STRINGS.interopJobsStopAction], 'a Jobs tab row offers Abort message, Suspend message and Stop job');
    await chooseMenuEntry(page, STRINGS.interopJobsSuspendAction);
    await page.waitForSelector('app-warning-dialog', { timeout: config.navigationTimeoutMs });
    const opened = await page.evaluate(() => {
      const surface = document.querySelector('[role="dialog"]');
      return {
        title: (surface.querySelector('.ocu-dialog-title')?.textContent ?? '').trim(),
        body: (surface.querySelector('.ocu-warning-consequence')?.textContent ?? '').trim(),
        destructive: surface.querySelector('.ocu-button-destructive') !== null,
      };
    });
    assert.deepEqual(opened, { title: STRINGS.interopJobsSuspendAction, body: STRINGS.interopJobSuspendConsequence, destructive: false }, 'the warning is titled with the verb, states the published sentence and is not destructive');
    assert.deepEqual(posts, [], 'nothing is sent while the dialog is open');
    await page.click('[role="dialog"] .ocu-dialog-actions .ocu-button-primary');
    await dialogClosed(page);
    assert.deepEqual(posts, [{ screen: 'interop.jobs', action: 'suspend', id: job[0] }], 'one suspend, posted to Jobs\' route past Proceed');
    await page.waitForSelector('.ocu-list-page-banner .ocu-banner-message', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-list-page-banner .ocu-banner-message', (node) => node.textContent.trim()), STRINGS.interopRefusalJobNotRetrying, 'the refusal shows the published sentence');
    assert.notEqual(headerStatus(armedIds[0]), SUSPENDED, 'and the message the job holds is not suspended');
    assert.equal(queueCount(), waiting, 'the queue is as it was');
  } finally {
    await context.close();
  }
});

/**
 * Story 20.4 in a real browser, against the throwaway instance: a production item's tabs, Production monitor, Queues with
 * Queue messages, and Jobs (AD-5, AD-8, AD-24, AD-29, AD-36, AD-43, AD-44, AD-62).
 *
 * What it pins: in `USER`, whose probe production this spec creates, starts, hangs on a message and leaves two more
 * waiting, the operation's name cell on Production items opens its Status tab, whose strip reads Status, Settings, Queue,
 * Log, Messages and Jobs, and each tab shows its rows -- the item's status, its settings, the two waiting messages with
 * their headers, the line the operation logged, the three messages sent, and the operation's job with the message it is
 * working on; Production monitor lists the operation and its name cell opens the same Status tab, and its auto-refresh chip
 * starts off and, turned on, reads the screen again; Queues lists the operation's queue with its count and opens Queue
 * messages; Jobs lists the operation's job with a link to Process details; and every one of them passes the structural and
 * contrast checks at 1280 light, 720 light and 1280 dark, with no entry beyond the baseline (DW-1337).
 *
 * **It compiles, starts and writes a probe production in `USER`** through `OcuPilot.Test.ProductionProbe`, so it runs on a
 * throwaway only; the `after` hook stops and removes the production, its classes and its messages, whatever the tests
 * answered.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/interop-host-tabs.browser-spec.mjs` (after `npm run build` and the
 * bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const PROBE = 'OcuPilot.Test.ProductionProbe';
const READ = 'OcuPilot.Test.InteropHostRead';
const PRODUCTION = 'OcuPilotProbe.Interop.Production';
const OPERATION = 'OcuPilotProbeOp';
const SERVICE = 'OcuPilotProbeSvc';
const LOG_TEXT = 'OcuPilot probe message';
const ITEMS = 'interoperability/productions/items';
const GROUP = `${ITEMS}/document`;
const TABS = [
  { route: GROUP, label: STRINGS.taskHistoryColumnStatus },
  { route: `${ITEMS}/settings`, label: STRINGS.interopItemTabSettings },
  { route: `${ITEMS}/queue`, label: STRINGS.interopColumnQueue },
  { route: `${ITEMS}/log`, label: STRINGS.interopItemTabLog },
  { route: `${ITEMS}/messages`, label: STRINGS.interopItemTabMessages },
  { route: `${ITEMS}/jobs`, label: STRINGS.interopJobsLabel },
];
const PRODUCTIONS_URL = '/ocupilot/interoperability/productions?ns=USER';
const MONITOR_URL = '/ocupilot/interoperability/monitor?ns=USER';
const QUEUES_URL = '/ocupilot/interoperability/queues?ns=USER';
const JOBS_URL = '/ocupilot/interoperability/jobs?ns=USER';
const MONITOR_READ = '/api/ocupilot/screens/interop.monitor/read';
const NAME_TEXT = '.ocu-data-table-link, .ocu-data-table-text';
/** The walk's own emulation: the tab strip's label colour transitions, and a measurement taken mid-transition reads neither theme. */
const REDUCED_MOTION = [{ name: 'prefers-reduced-motion', value: 'reduce' }];

let browser = null;
let created = false;
/** The ids of the three messages the probe was sent, oldest first. */
let messageIds = [];

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/** The DW-1337 walk of `route` at 1280 light, 720 light and 1280 dark, answering every entry the baseline does not hold. */
async function structural(page, route) {
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
    const { entries } = await detectScreen(page, { route, checks, viewport: viewport.width, theme, minimums });
    found.push(...entries);
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await frames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  return compare(collapse(found), readBaseline()?.entries ?? []).fresh.map((entry) => `${entry.key}: ${entry.measured}`);
}

/** Every body row's cells, each as its trimmed text. */
function allRows(page) {
  return page.evaluate(
    (rowSelector) => Array.from(document.querySelectorAll(rowSelector)).map((row) => Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim())),
    ROW_SELECTOR
  );
}

/** The `href` of the link in the body row that holds a cell reading `text`, or `null` when that row carries none. */
function rowLink(page, text) {
  return page.evaluate(
    (rowSelector, wanted) => {
      const row = Array.from(document.querySelectorAll(rowSelector)).find((node) =>
        Array.from(node.querySelectorAll('[role="gridcell"]')).some((cell) => cell.textContent.trim() === wanted)
      );
      return row?.querySelector('.ocu-data-table-link')?.getAttribute('href') ?? null;
    },
    ROW_SELECTOR,
    text
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
  return page.evaluate(
    (rowSelector, wanted, textSelector) => {
      const row = Array.from(document.querySelectorAll(rowSelector)).find((node) => {
        const cell = node.querySelector('[role="gridcell"]');
        return ((cell?.querySelector(textSelector) ?? cell)?.textContent ?? '').trim() === wanted;
      });
      return Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim());
    },
    ROW_SELECTOR,
    name,
    NAME_TEXT
  );
}

/** Wait until the page's path holds `suffix`. */
function pathHolds(page, suffix) {
  return page.waitForFunction((wanted) => new URL(window.location.href).pathname.includes(wanted), { timeout: config.navigationTimeoutMs }, suffix);
}

/** The screen has answered the navigation map and drawn its rows. */
async function answered(page) {
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  await waitForRows(page, config.navigationTimeoutMs);
}

/** The labels of the item strip's tabs, in order. */
function stripLabels(page) {
  return page.$$eval('button.ocu-detail-tab .ocu-detail-tab-label', (labels) => labels.map((label) => label.textContent.trim()));
}

/** Open the probe operation from the Productions list's name cell and Production items' name cell: its Status tab. */
async function openOperation(page) {
  await answered(page);
  await clickRowCentre(page, { text: PRODUCTION, link: true });
  await pathHolds(page, `/${ITEMS}/`);
  await answered(page);
  await rowNamed(page, OPERATION);
  await clickRowCentre(page, { text: OPERATION, link: true });
  await pathHolds(page, `/${GROUP}/`);
  await answered(page);
}

/** Open the strip's tab on `route` and wait for its rows. */
async function openTab(page, route) {
  await (await page.waitForSelector(`button.ocu-detail-tab[data-route="${route}"]`, { visible: true, timeout: config.navigationTimeoutMs })).click();
  await pathHolds(page, `/${route}/`);
  await answered(page);
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec compiles and starts a probe production, so it runs only in a throwaway; ${config.container} is not one`);
  const removed = probe('IHCLEAN', `$System.Status.IsOK(##class(${PROBE}).Remove())`);
  assert.equal(removed.value, '1', `an earlier run's probe is removed: ${removed.output}`);
  const made = probe('IHMADE', `$System.Status.IsOK(##class(${PROBE}).Create())`);
  assert.equal(made.value, '1', `the probe production is created: ${made.output}`);
  created = true;
  const output = runIris(config.container, [`Set sc=##class(${READ}).ArmProbe(.ids)`, 'Write "OCU-IHARM-START:"_$System.Status.IsOK(sc)_"|"_ids_":OCU-IHARM-END",!']);
  const armed = markerValue(output, 'IHARM') ?? '';
  assert.match(armed, /^1\|\d+,\d+,\d+$/, `the probe production runs with its operation hung on a message and two waiting: ${output}`);
  messageIds = armed.split('|')[1].split(',');
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (created && /-ci$/.test(config.container)) {
      const removed = probe('IHGONE', `$System.Status.IsOK(##class(${PROBE}).Remove())_##class(${PROBE}).Gone()`);
      assert.equal(removed.value, '11', `the probe production is removed: ${removed.output}`);
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

// AC1, AC3, AC7. Mutation (Rule 19): drop `InteropItemQueueTab`'s `tab` -> the strip reads five tabs and the labels leg
// goes red; keep `<app-list-page />` in `InteropItemSettingListPage`, rebuild and redeploy -> the strip is missing on the
// Settings tab and the second leg goes red.
test('AC1, AC3, AC7: the operation opens on its Status tab, the strip reads the six tabs, and each tab shows its rows', async () => {
  const { context, page } = await signedInAt(browser, config, PRODUCTIONS_URL, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await openOperation(page);
    assert.deepEqual(await stripLabels(page), TABS.map((tab) => tab.label), 'the strip reads Status, Settings, Queue, Log, Messages and Jobs');
    const status = await rowNamed(page, OPERATION);
    assert.deepEqual(
      [status[0], status[1], status[2], status[3], status[4]],
      [OPERATION, 'OcuPilotProbe.Interop.Op', 'operation', STRINGS.tableStatusYes, 'OK'],
      'the Status tab reads the operation\'s configuration and its monitor status'
    );
    assert.deepEqual(await structural(page, GROUP), [], 'Status: no violation beyond the baseline\'s entries');

    await openTab(page, TABS[1].route);
    assert.deepEqual(await stripLabels(page), TABS.map((tab) => tab.label), 'the Settings tab carries the same strip');
    await rowNamed(page, 'InitSeconds');

    await openTab(page, TABS[2].route);
    const queued = await allRows(page);
    assert.equal(queued.length, 2, 'the Queue tab shows the two waiting messages');
    assert.deepEqual(queued.map((row) => row[0]).sort(), messageIds.slice(1).sort(), 'they are the second and third message');
    assert.ok(queued.every((row) => row.includes(SERVICE) && row.includes(OPERATION) && row.includes('Queued')), 'each with its header: source, target and status');
    assert.deepEqual(await structural(page, TABS[2].route), [], 'Queue: no violation beyond the baseline\'s entries');

    await openTab(page, TABS[3].route);
    const logged = await allRows(page);
    assert.ok(logged.some((row) => row.includes(LOG_TEXT)), `the Log tab shows the line the operation logged: ${JSON.stringify(logged)}`);
    assert.deepEqual(await structural(page, TABS[3].route), [], 'Log: no violation beyond the baseline\'s entries');

    await openTab(page, TABS[4].route);
    const messages = await allRows(page);
    for (const id of messageIds) assert.ok(messages.some((row) => row[0] === id), `the Messages tab shows message ${id}`);
    assert.deepEqual(await structural(page, TABS[4].route), [], 'Messages: no violation beyond the baseline\'s entries');

    await openTab(page, TABS[5].route);
    const jobs = await allRows(page);
    assert.equal(jobs.length, 1, 'the Jobs tab shows the operation\'s one job');
    assert.ok(jobs[0].includes(messageIds[0]), 'with the first message, which it is working on');
    assert.deepEqual(await structural(page, TABS[5].route), [], 'Jobs: no violation beyond the baseline\'s entries');
  } finally {
    await context.close();
  }
});

// AC2, AC7. Mutation (Rule 19): drop the monitor's `rowTarget` -> the name cell is text and the click leg goes red; drop
// `refreshes` from its descriptor -> no chip renders and the chip wait goes red; rebuild and redeploy first.
test('AC2, AC7: Production monitor lists the operation, its name cell opens the Status tab, and its refresh chip reads the screen again', async () => {
  const { context, page } = await signedInAt(browser, config, MONITOR_URL, VIEWPORTS.wide, REDUCED_MOTION);
  const reads = [];
  page.on('request', (request) => {
    if (new URL(request.url()).pathname === MONITOR_READ) reads.push(request.url());
  });
  try {
    await answered(page);
    const op = await rowNamed(page, OPERATION);
    const svc = await rowNamed(page, SERVICE);
    assert.equal(op[1], 'BusinessOperation', 'the operation reads its type');
    assert.equal(op[2], 'OK', 'and its status');
    assert.equal(op[6], '2', 'and the two messages waiting in its queue');
    assert.equal(svc[1], 'BusinessService', 'the service is listed beside it');
    const rows = await allRows(page);
    assert.deepEqual(rows.map((row) => row[0]).sort(), [OPERATION, SERVICE], 'and no host the vendor runs for itself');
    assert.deepEqual(await structural(page, 'interoperability/monitor'), [], 'Production monitor: no violation beyond the baseline\'s entries');

    await page.waitForSelector('.ocu-command-bar-refresh', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-command-bar-refresh', (button) => button.textContent.trim()), STRINGS.statusAutoRefreshOff, 'the chip starts off');
    const before = reads.length;
    await page.click('.ocu-command-bar-refresh');
    await page.waitForFunction(
      (wanted) => document.querySelector('.ocu-command-bar-refresh').textContent.trim() === wanted,
      { timeout: config.navigationTimeoutMs },
      STRINGS.statusAutoRefreshOn.replace('<n>', '5')
    );
    const deadline = Date.now() + 15000;
    while (reads.length <= before && Date.now() < deadline) await new Promise((resolve) => setTimeout(resolve, 250));
    assert.ok(reads.length > before, 'turned on, the chip reads the screen again');
    // Turn the chip off again, through the rates it offers, so no tick lands during the click below.
    for (let step = 0; step < 5; step += 1) {
      if ((await page.$eval('.ocu-command-bar-refresh', (button) => button.textContent.trim())) === STRINGS.statusAutoRefreshOff) break;
      await page.click('.ocu-command-bar-refresh');
      await frames(page);
    }

    await clickRowCentre(page, { text: OPERATION, link: true });
    await pathHolds(page, `/${GROUP}/`);
    await answered(page);
    assert.deepEqual(await stripLabels(page), TABS.map((tab) => tab.label), 'a monitor row opens the operation\'s Status tab, under the strip');
  } finally {
    await context.close();
  }
});

// AC3, AC4. Mutation (Rule 19): make `childListFor` answer null -> the queue's name cell opens nothing and this goes red.
test('AC3: Queues lists the operation\'s queue with its count and opens its messages', async () => {
  const { context, page } = await signedInAt(browser, config, QUEUES_URL, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await answered(page);
    const queue = await rowNamed(page, OPERATION);
    assert.equal(queue[1], '2', 'the queue holds two messages');
    assert.equal(queue[2], '1', 'and one job is working on one');
    assert.deepEqual(await structural(page, 'interoperability/queues'), [], 'Queues: no violation beyond the baseline\'s entries');
    assert.equal((await page.$$('.ocu-data-table-trigger')).length, 0, 'Queues offers no action: aborting is a later story\'s');
    await clickRowCentre(page, { text: OPERATION, link: true });
    await pathHolds(page, '/interoperability/queues/messages/');
    await answered(page);
    const entries = await allRows(page);
    assert.deepEqual(entries.map((row) => row[0]).sort(), messageIds.slice(1).sort(), 'Queue messages shows the two waiting messages');
    assert.ok(entries.every((row) => row.includes(SERVICE) && row.includes(OPERATION)), 'each with its header');
    assert.deepEqual(await structural(page, 'interoperability/queues/messages'), [], 'Queue messages: no violation beyond the baseline\'s entries');
    assert.equal((await page.$$('.ocu-data-table-trigger')).length, 0, 'and neither does Queue messages');
  } finally {
    await context.close();
  }
});

// AC3. Mutation (Rule 19): make `JobRow` mark only the operation's row dead -> its own row loses its link and the link leg
// goes red, though the vendor hosts' rows still link; make `rowTarget` null -> the same leg goes red.
test('AC3: Jobs lists the operation\'s job with the message it is working on, linked to Process details', async () => {
  const { context, page } = await signedInAt(browser, config, JOBS_URL, VIEWPORTS.wide, REDUCED_MOTION);
  try {
    await answered(page);
    const rows = await allRows(page);
    const job = rows.find((row) => row.includes(OPERATION));
    assert.ok(job !== undefined, `the operation's job is listed: ${JSON.stringify(rows)}`);
    assert.ok(job.includes(messageIds[0]), 'with the first message, which it is working on');
    assert.match((await rowLink(page, OPERATION)) ?? '', /\/os-management\/processes\/details\//, 'the operation\'s own row links to Process details');
    assert.ok(job.includes(STRINGS.tableStatusNo), 'alive: its Dead cell reads No');
    assert.deepEqual(await structural(page, 'interoperability/jobs'), [], 'Jobs: no violation beyond the baseline\'s entries');
  } finally {
    await context.close();
  }
});

/**
 * Story 16.6 in a real browser, against the throwaway instance: Processes' checked rows and their
 * Broadcast (AD-5, AD-53).
 *
 * What it pins: a daemon's checkbox is drawn `aria-disabled` with the published reason and a click
 * leaves it unchecked, with DOM focus on the grid; Space checks a terminal session this spec
 * started, and Broadcast opens "Broadcast to 1 process" over it; with the checkboxes drawn and the
 * dialog open the screen passes the structural and contrast checks at 1280 light, 720 light and
 * 1280 dark with no entry beyond the baseline (DW-1337); Send posts one request, the receiver's
 * terminal shows the message, and the dialog reads "Message sent." with focus on Close and the check
 * cleared.
 *
 * **It broadcasts only to a terminal session it starts itself** -- `iris session` over `docker exec`
 * without `-t`, running `OcuPilot.Test.ProcessBroadcastLive.Receiver` -- and terminates it in `after`,
 * whatever the tests answered, so it runs on a throwaway only.
 *
 * Run: `node --test --test-concurrency=1 browser/process-broadcast.browser-spec.mjs` (after
 * `npm run build`, the bundle copied into the throwaway, and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const ROUTE = 'os-management/processes';
const LIST_URL = `/ocupilot/${ROUTE}?ns=HSCUSTOM`;
const ACTION_PATH = '/api/ocupilot/screens/osmgmt.processes/action';
const RECEIVER = 'OcuPilot.Test.ProcessBroadcastLive';

/** The write daemon's routine: IRIS starts it before anything signs in, and it cannot receive a broadcast. */
const DAEMON_ROUTINE = 'WRTDMN';

let browser = null;

/** The receiver this spec started: its `docker exec` child, what its terminal has shown, and its pid. */
const receiver = { child: null, output: '', pid: '' };

/**
 * Start one terminal session that waits two minutes, and answer its pid once it has recorded it
 * under the tag this call gave it (`ProcessBroadcastLive.Receiver`).
 */
async function startReceiver() {
  const tag = Date.now();
  const child = spawn('docker', ['exec', config.container, 'iris', 'session', 'iris', '-U', 'HSCUSTOM', `##class(${RECEIVER}).Receiver(120,${tag})`], {
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  receiver.child = child;
  child.stdout.on('data', (chunk) => (receiver.output += chunk.toString('utf8')));
  child.stderr.on('data', (chunk) => (receiver.output += chunk.toString('utf8')));
  const deadline = Date.now() + 20000;
  while (Date.now() < deadline) {
    const output = runIris(config.container, [
      `Set pid=##class(${RECEIVER}).PidTagged(${tag})`,
      'Write "OCU-BCPID-START:"_pid_":OCU-BCPID-END",!',
    ]);
    const pid = markerValue(output, 'BCPID');
    if (pid !== null && pid !== '') {
      receiver.pid = pid;
      return receiver.pid;
    }
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error(`the receiver recorded no pid: ${receiver.output}`);
}

/** End the receiver on the instance and its `docker exec` child here, and forget its global node. */
function stopReceiver() {
  try {
    if (receiver.pid !== '') {
      const output = runIris(config.container, [
        `Set ok=$SYSTEM.Process.Terminate(${receiver.pid}) Kill ^OcuPilotTestBroadcast(${receiver.pid})`,
        'Write "OCU-BCSTOP-START:"_ok_":OCU-BCSTOP-END",!',
      ]);
      assert.notEqual(markerValue(output, 'BCSTOP'), null, `the receiver's end was asked for: ${output}`);
    }
  } finally {
    if (receiver.child !== null && receiver.child.exitCode === null) receiver.child.kill();
  }
}

/** The write daemon's pid, read through the endpoint the screen reads. */
function daemonPid() {
  const output = runIris(config.container, [
    'Kill q Set sc=##class(OcuPilot.Port.AdminPort).Invoke("Process","LIST",.q,"",.rows,.h,.f) Set pid=""',
    `Set it=rows.%GetIterator() While it.%GetNext(.i,.row) { If row.Routine="${DAEMON_ROUTINE}" { Set pid=row.Pid Quit } }`,
    'Write "OCU-BCDAEMON-START:"_pid_":OCU-BCDAEMON-END",!',
  ]);
  const pid = markerValue(output, 'BCDAEMON');
  assert.ok(pid !== null && pid !== '', `the throwaway lists a ${DAEMON_ROUTINE} row: ${output}`);
  return pid;
}

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/**
 * The DW-1337 walk of this screen at 1280 light, 720 light and 1280 dark, answering every entry the
 * baseline does not already hold; with `dialog`, the open dialog's body is also held to scrolling
 * nothing sideways, which the walk skips inside a scroll container.
 */
async function structural(page, dialog = false) {
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
    if (dialog) {
      const body = await page.$eval('.ocu-dialog-body', (element) => ({ scroll: element.scrollWidth, client: element.clientWidth }));
      assert.ok(body.scroll <= body.client, `the dialog body does not scroll sideways at ${viewport.width}px ${theme}: ${JSON.stringify(body)}`);
    }
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await frames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  return compare(collapse(found), readBaseline()?.entries ?? []).fresh.map((entry) => `${entry.key}: ${entry.measured}`);
}

/** Signed in at the list with its rows rendered, recording every request to the action route. */
async function atList() {
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const posts = [];
  page.on('request', (request) => {
    if (new URL(request.url()).pathname === ACTION_PATH) posts.push({ method: request.method(), body: request.postData() ?? '' });
  });
  await waitForRows(page, config.navigationTimeoutMs);
  return { context, page, posts };
}

/**
 * Filter the list by `pid` and wait for the row whose name reads it. The filter matches text, so
 * another pid that contains this one's digits may stay listed beside it; every read below finds the
 * row by its name cell's link or text, never by its position or the cell's whole text, which gains
 * the "Changed" tag after a send.
 */
async function filterTo(page, pid) {
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, pid);
  await page.waitForFunction(
    (rowSelector, wanted) =>
      Array.from(document.querySelectorAll(rowSelector)).some((row) => (row.querySelector('[role="gridcell"] .ocu-data-table-link, [role="gridcell"] .ocu-data-table-text')?.textContent ?? '').trim() === wanted),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    pid
  );
}

/** The rendered row whose name reads `pid`, as an element handle. */
function rowOf(page, pid) {
  return page.evaluateHandle(
    (rowSelector, wanted) =>
      Array.from(document.querySelectorAll(rowSelector)).find((row) => (row.querySelector('[role="gridcell"] .ocu-data-table-link, [role="gridcell"] .ocu-data-table-text')?.textContent ?? '').trim() === wanted) ?? null,
    ROW_SELECTOR,
    pid
  );
}

/** The row for `pid`'s checkbox, as the page draws it. */
async function checkbox(page, pid) {
  const row = await rowOf(page, pid);
  return row.evaluate((element) => {
    const box = element.querySelector('.ocu-data-table-check');
    return {
      checked: box.checked,
      disabled: box.getAttribute('aria-disabled'),
      reason: box.getAttribute('aria-description'),
      label: box.getAttribute('aria-label'),
    };
  });
}

/** The row for `pid`'s `aria-selected`, or `null`. */
async function rowSelected(page, pid) {
  return (await rowOf(page, pid)).evaluate((element) => element.getAttribute('aria-selected'));
}

/** Wait until the row for `pid` reads `value` under `key`: its checkbox's `checked`, or its `selected`. */
function waitForRow(page, pid, key, value) {
  return page.waitForFunction(
    (rowSelector, wantedPid, wantedKey, wantedValue) => {
      const row = Array.from(document.querySelectorAll(rowSelector)).find((candidate) => (candidate.querySelector('[role="gridcell"] .ocu-data-table-link, [role="gridcell"] .ocu-data-table-text')?.textContent ?? '').trim() === wantedPid);
      if (row === undefined) return false;
      const box = row.querySelector('.ocu-data-table-check');
      const drawn = { checked: box?.checked ?? null, selected: row.getAttribute('aria-selected') };
      return drawn[wantedKey] === wantedValue;
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    pid,
    key,
    value
  );
}

/** The command bar's Broadcast, as drawn. */
function broadcastButton(page, label) {
  return page.evaluate((wanted) => {
    const button = Array.from(document.querySelectorAll('.ocu-command-bar-action')).find((candidate) => candidate.textContent.trim() === wanted);
    return button === undefined ? null : { disabled: button.getAttribute('aria-disabled') };
  }, label);
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec starts a terminal session and broadcasts to it, so it never runs inside the live container');
  assert.match(config.container, /-ci$/, `this spec starts a terminal session and broadcasts to it, so it runs only in a throwaway; ${config.container} is not one`);
  await assertThrowaway(config);
  browser = await puppeteer.launch(launchOptions(config));
  await startReceiver();
});

after(async () => {
  try {
    stopReceiver();
  } finally {
    if (browser !== null) await browser.close();
  }
});

// Mutation (Rule 19): draw the checkbox without its `aria-disabled` for an ineligible row, then
// rebuild and redeploy -> the daemon leg goes red.
test('a daemon\'s checkbox is aria-disabled with the published reason, and a click leaves it unchecked and the grid focused', async () => {
  const { context, page, posts } = await atList();
  try {
    const pid = daemonPid();
    await filterTo(page, pid);
    const drawn = await checkbox(page, pid);
    assert.deepEqual(drawn, { checked: false, disabled: 'true', reason: STRINGS.processBroadcastIneligible, label: pid }, 'the daemon cannot be checked, and says why');
    const selected = await rowSelected(page, pid);
    const box = await (await rowOf(page, pid)).evaluateHandle((row) => row.querySelector('.ocu-data-table-check'));
    await box.click();
    await frames(page);
    assert.equal((await checkbox(page, pid)).checked, false, 'a click leaves it unchecked');
    assert.equal(await rowSelected(page, pid), selected, 'and leaves the selection where it was');
    assert.equal(await page.evaluate(() => document.activeElement?.getAttribute('role') ?? ''), 'grid', 'with DOM focus on the grid, not the checkbox');
    assert.deepEqual(await broadcastButton(page, STRINGS.processBroadcastAction), { disabled: 'true' }, 'and Broadcast still waits for a checked row');
    assert.equal(posts.length, 0, 'nothing was sent');
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): drop Space from the data table's grid keydown, then rebuild and redeploy -> the
// receiver is never checked and the Broadcast leg goes red.
test('Space checks the receiver, Broadcast opens over it and passes DW-1337, and Send reaches its terminal', async () => {
  const { context, page, posts } = await atList();
  try {
    await filterTo(page, receiver.pid);
    assert.deepEqual(await checkbox(page, receiver.pid), { checked: false, disabled: null, reason: null, label: receiver.pid }, 'the receiver can be checked');
    await clickRowCentre(page, { text: receiver.pid, cell: 1 });
    await waitForRow(page, receiver.pid, 'selected', 'true');
    await page.keyboard.press('Space');
    await waitForRow(page, receiver.pid, 'checked', true);
    assert.equal(await rowSelected(page, receiver.pid), 'true', 'the selection stays on the row');
    assert.deepEqual(await broadcastButton(page, STRINGS.processBroadcastAction), { disabled: null }, 'Broadcast is available over one checked row');

    await page.evaluate((wanted) => {
      Array.from(document.querySelectorAll('.ocu-command-bar-action')).find((button) => button.textContent.trim() === wanted).click();
    }, STRINGS.processBroadcastAction);
    await page.waitForSelector('app-broadcast-dialog [role="dialog"]', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-dialog-title', (title) => title.textContent.trim()), STRINGS.processBroadcastTitleOne, 'the dialog names one process');
    assert.equal(await page.evaluate(() => document.activeElement?.classList.contains('ocu-broadcast-message') ?? false), true, 'with focus in the Message field');

    assert.deepEqual(await structural(page, true), [], 'with the checkboxes drawn and the dialog open, no violation beyond the baseline\'s entries');

    const token = `OcuBcastBrowser${Date.now()}`;
    await page.type('.ocu-broadcast-message', `  ${token}  `);
    await page.click('.ocu-broadcast-send');
    await page.waitForFunction(() => document.querySelector('.ocu-broadcast-sent') !== null, { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('.ocu-broadcast-sent', (line) => line.textContent.trim()), STRINGS.processBroadcastSent, 'the dialog reads Message sent.');
    assert.equal(posts.length, 1, `one request: ${JSON.stringify(posts)}`);
    assert.deepEqual(JSON.parse(posts[0].body), { action: 'broadcast', id: receiver.pid, values: { Message: token } }, 'carrying the trimmed message to the checked pid');
    const deadline = Date.now() + 5000;
    while (!receiver.output.includes(`***${token}***`) && Date.now() < deadline) await new Promise((resolve) => setTimeout(resolve, 100));
    assert.equal(receiver.output.split(`***${token}***`).length - 1, 1, `the receiver's terminal shows the message once: ${JSON.stringify(receiver.output)}`);
    assert.equal(await page.$eval('.ocu-dialog-actions .ocu-button-secondary', (button) => button.textContent.trim()), STRINGS.auditDialogClose, 'and Close is the one action left');
    // Send is gone once sent, so focus moves to Close rather than falling to the page.
    await page.waitForFunction((wanted) => document.activeElement?.textContent?.trim() === wanted, { timeout: config.navigationTimeoutMs }, STRINGS.auditDialogClose);
    assert.equal((await checkbox(page, receiver.pid)).checked, false, 'and the sent check is cleared');
  } finally {
    await context.close();
  }
});

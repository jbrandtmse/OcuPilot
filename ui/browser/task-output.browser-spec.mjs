/**
 * Story 21.36 in a real browser against the throwaway instance: a task's output file, from Task
 * details' "Open output file" to the shared log viewer (AD-5, AD-21, AD-36).
 *
 * What it pins: Task details of an on-demand task that writes an output file shows the link and the
 * task's Output file name and Output directory; the link opens the viewer, which draws the file's
 * lines as text alone, oldest first, the file's last line at the foot, with no severity chip; a file
 * larger than the 64 KB window adds the sentence saying only the end is shown, and a small one adds
 * nothing; and once the file is gone the viewer draws the not-written-yet sentence in place of rows.
 *
 * **It creates and deletes a probe task and writes and removes its output file**, so it runs on a
 * throwaway only. The task is created through the wizard's own Save (`OcuPilot.Test.TaskEditProbe`),
 * on demand and never run, naming its output file only; the file is written into the throwaway's
 * manager directory by `docker exec`. The `after` hook removes the task and the file whatever the
 * tests answered. No vendor task is touched.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1
 * browser/task-output.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { signedInAt } from './panel-spec.mjs';
import { markerValue, requireFreeSlot, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();

const PROBE_CLASS = 'OcuPilot.Test.TaskEditProbe';
/** The probe task's name, which carries `TaskEditProbe`'s prefix. */
const TASK_NAME = 'OcuP98OutputBrowser';
const OUTPUT_FILE = 'ocup98outputbrowser.txt';

const OUTPUT_LINK = '[data-ocu-details="output"]';
const ROW_TEXT = '.ocu-log-row .ocu-log-cell-text';

let browser = null;
let taskId = '';
let managerDirectory = '';

/** Remove every probe task by id after its exact name reads back; true when none survives. */
function removeProbes() {
  const output = runIris(config.container, [`Set tSC=##class(${PROBE_CLASS}).RemoveAll()`, 'Write "OCU-CLEAN-START:"_$System.Status.IsOK(tSC)_":OCU-CLEAN-END",!']);
  return { clean: markerValue(output, 'CLEAN') === '1', output };
}

/** Create the probe task, on demand, naming `OUTPUT_FILE` as its output file; its id. */
function createProbe() {
  const args = `{"Name":"${TASK_NAME}","Description":"OcuPilot task output browser probe","NameSpace":"%SYS","TaskClass":"%SYS.Task.PurgeTaskHistory","Settings":{"KeepDays":"30"},"TimePeriod":"On Demand","OpenOutputFile":true,"OutputFilename":"${OUTPUT_FILE}"}`;
  const output = runIris(config.container, [
    `Set tSC=##class(${PROBE_CLASS}).Create(${args},.tId)`,
    'Write "OCU-ID-START:"_$Select($System.Status.IsOK(tSC):tId,1:"")_":OCU-ID-END",!',
    'Write "OCU-DIR-START:"_$System.Util.ManagerDirectory()_":OCU-DIR-END",!',
  ]);
  const id = markerValue(output, 'ID') ?? '';
  assert.match(id, /^\d+$/, `the probe task is created:\n${output}`);
  managerDirectory = markerValue(output, 'DIR') ?? '';
  assert.notEqual(managerDirectory, '', 'the manager directory reads back');
  return id;
}

/** Run `script` in the throwaway's shell. */
function sh(script) {
  const result = spawnSync('docker', ['exec', config.container, 'sh', '-c', script], { encoding: 'utf8', timeout: 120000 });
  assert.equal(result.status, 0, `${script} exits 0: ${result.stderr ?? ''}${result.error?.message ?? ''}`);
}

/** Write the probe file as `count` numbered lines, each padded to `width` bytes with its newline. */
function writeOutput(count, width) {
  const path = `${managerDirectory}${OUTPUT_FILE}`;
  sh(
    `i=1; : > '${path}'; while [ $i -le ${count} ]; do printf 'line %05d %s\\n' $i "$(head -c ${width - 12} /dev/zero | tr '\\0' .)"; i=$((i+1)); done >> '${path}'`
  );
}

function removeOutput() {
  if (managerDirectory === '') return;
  sh(`rm -f '${managerDirectory}${OUTPUT_FILE}'`);
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates a task and writes a file, so it never runs inside the live container');
  assert.match(config.container, /-ci$/, `this spec writes a task on the instance, so it runs only in a throwaway; ${config.container} is not one`);
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  const { clean, output } = removeProbes();
  assert.ok(clean, `no probe task is left from an earlier run:\n${output}`);
  browser = await puppeteer.launch(launchOptions(config));
  taskId = createProbe();
});

after(async () => {
  if (browser !== null) await browser.close();
  if (!/-ci$/.test(config.container)) return;
  removeOutput();
  const { clean, output } = removeProbes();
  assert.ok(clean, `the probe task is removed:\n${output}`);
});

/** A signed-in page at Task details of the probe task. */
async function signedInAtDetails() {
  await requireFreeSlot(config);
  return signedInAt(browser, config, `/ocupilot/tasks/schedule/details/${taskId}?ns=HSCUSTOM`);
}

/** The viewer's drawn lines, in the order they are drawn. */
function lines(page) {
  return page.$$eval(ROW_TEXT, (cells) => cells.map((cell) => (cell.textContent ?? '').trim()));
}

/** Open the viewer from Task details' link and wait for its answer: the rows, or a refusal. */
async function openViewer(page) {
  await page.waitForSelector(OUTPUT_LINK, { timeout: config.navigationTimeoutMs });
  await page.click(OUTPUT_LINK);
  await page.waitForFunction(
    () => document.querySelector('[data-ocu-log="viewport"], [data-ocu-log="refusal"], [data-ocu-log="empty"]') !== null,
    { timeout: config.navigationTimeoutMs }
  );
}

test('Task details shows the output file name and directory and the link that opens the viewer', async () => {
  writeOutput(3, 40);
  const { context, page } = await signedInAtDetails();
  try {
    await page.waitForSelector(OUTPUT_LINK, { timeout: config.navigationTimeoutMs });
    const link = await page.$eval(OUTPUT_LINK, (anchor) => ({ text: (anchor.textContent ?? '').trim(), href: anchor.getAttribute('href') ?? '' }));
    assert.equal(link.text, STRINGS.taskOutputOpen);
    assert.ok(link.href.includes(`/tasks/schedule/output/${taskId}`), `the link names this task: ${link.href}`);
    const fields = await page.$$eval('.ocu-details-field', (nodes) =>
      nodes.map((node) => [
        (node.querySelector('.ocu-details-field-label')?.textContent ?? '').trim(),
        (node.querySelector('.ocu-details-field-value')?.textContent ?? '').trim(),
      ])
    );
    const byLabel = new Map(fields);
    assert.equal(byLabel.get(STRINGS.taskOutputFilename), OUTPUT_FILE, 'Output file name shows the stored name');
    assert.equal(byLabel.get(STRINGS.taskOutputDirectory), managerDirectory, 'and Output directory the manager directory');
  } finally {
    await context.close();
  }
});

test('the viewer draws the file as text alone, oldest first, the last line at the foot, and no cut sentence for a small file', async () => {
  writeOutput(3, 40);
  const { context, page } = await signedInAtDetails();
  try {
    await openViewer(page);
    await page.waitForSelector(ROW_TEXT, { timeout: config.navigationTimeoutMs });
    const drawn = await lines(page);
    assert.equal(drawn.length, 3, `three lines: ${JSON.stringify(drawn)}`);
    assert.ok(drawn[0].startsWith('line 00001'), `the oldest line comes first: ${drawn[0]}`);
    assert.ok(drawn[2].startsWith('line 00003'), `and the last line is at the foot: ${drawn[2]}`);
    assert.equal(await page.$('.ocu-log-chip'), null, 'no severity chip is drawn');
    assert.equal(await page.$('[data-ocu-log="truncated"]'), null, 'and a small file says nothing about a cut');
  } finally {
    await context.close();
  }
});

test('a file larger than the window shows its end and says only the end is shown', async () => {
  writeOutput(1200, 80);
  const { context, page } = await signedInAtDetails();
  try {
    await openViewer(page);
    await page.waitForSelector('[data-ocu-log="truncated"]', { timeout: config.navigationTimeoutMs });
    assert.equal(
      (await page.$eval('[data-ocu-log="truncated"]', (node) => (node.textContent ?? '').trim())),
      STRINGS.taskOutputTruncated
    );
    const drawn = await lines(page);
    assert.ok(drawn.length > 100 && drawn.length < 1200, `the window holds the end of the file, not all of it: ${drawn.length} lines`);
    assert.ok(drawn[drawn.length - 1].startsWith('line 01200'), `the last line of the file is at the foot: ${drawn[drawn.length - 1]}`);
    assert.ok(!drawn[0].startsWith('line 00001'), 'and the first line of the file is not drawn');
  } finally {
    await context.close();
  }
});

test('once the file is gone the viewer draws the not-written-yet sentence in place of rows', async () => {
  removeOutput();
  const { context, page } = await signedInAtDetails();
  try {
    await openViewer(page);
    await page.waitForSelector('[data-ocu-log="refusal"]', { timeout: config.navigationTimeoutMs });
    assert.equal(
      (await page.$eval('[data-ocu-log="refusal"]', (node) => (node.textContent ?? '').trim())),
      STRINGS.taskOutputAbsent
    );
    assert.deepEqual(await lines(page), [], 'no row is drawn');
  } finally {
    await context.close();
  }
});

/**
 * Journal records and its record dialog in a real browser, against the throwaway instance (Story
 * 18.19).
 *
 * What it pins, each on rendered DOM:
 *
 * 1. **The arrival** (AC1): Journals, then the seeded file's details, then View records opens
 *    Journal records naming that file and listing its records.
 * 2. **The filter and Next records** (AC2): at ten rows, the probe filter from the seed's first
 *    record lists the first ten seeded records, and Next records the next ten, none repeated.
 * 3. **The dialog** (AC5): a seeded record's row opens the journal record dialog, which shows its
 *    values as text -- the markup value literally -- and closes on Escape with the criteria kept.
 * 4. **DW-1337** (AC7): the list and the dialog pass the structural walk at wide light, narrow light
 *    and wide dark.
 * 5. **A refused record** (AC5): a reloaded record route on an address that holds no record shows
 *    the route's own reason in the dialog.
 *
 * **It refuses the live and development containers.** It seeds the probe database
 * (`OcuPilot.Test.JournalProbe.SeedProbeDatabase`) over `docker exec` before its tests and removes
 * it, and the task rows its reads leave, after them; the records stay in the journal file.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1
 * browser/journal-records.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();

const PROBE = 'OcuPilot.Test.JournalProbe';

const RECORDS_ROUTE = 'os-management/journal-records';
const LIST_URL = '/ocupilot/os-management/journals?ns=HSCUSTOM';

/** The row cells' own text selector, a name cell being a link. */
const NAME_TEXT = '.ocu-data-table-link, .ocu-data-table-text';

let browser = null;

/** The seeded file, and its offset just before the seeded records. */
let seeded = null;

const mark = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/** Run `lines` in `HSCUSTOM` inside the throwaway and return the value each named marker carries. */
function iris(lines, names = []) {
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', 'HSCUSTOM'], {
    input: `${[...lines, 'Halt'].join('\n')}\n`,
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const values = {};
  for (const name of names) {
    const hit = new RegExp(`OCU-${name}-START:(.*?):OCU-${name}-END`).exec(output);
    values[name] = hit === null ? null : hit[1].trim();
  }
  return { values, output };
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec seeds a probe database, so it never runs inside the live container');
  assert.ok(!/^ocupilot-slot-/.test(config.container), 'nor inside a development instance');
  await assertThrowaway(config);
  const { values, output } = iris(
    [
      `Set sc=##class(${PROBE}).RemoveAll(.left)`,
      `Set sc=##class(${PROBE}).SeedProbeDatabase(1,.file,30,.offset)`,
      mark('SEEDED', '$Select($System.Status.IsOK(sc):"OK",1:$System.Status.GetErrorText(sc))'),
      mark('FILE', 'file'),
      mark('OFFSET', 'offset'),
    ],
    ['SEEDED', 'FILE', 'OFFSET']
  );
  assert.equal(values.SEEDED, 'OK', `the throwaway seeds the probe records:\n${output}`);
  seeded = { file: values.FILE, offset: values.OFFSET };
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    if (config.container !== LIVE_CONTAINER && seeded !== null) {
      const { values, output } = iris(
        [
          `Set sc1=##class(${PROBE}).RemoveProbeTaskRows(.rows)`,
          `Set sc2=##class(${PROBE}).RemoveAll(.left)`,
          mark('REMOVED', '$Select($System.Status.IsOK(sc1)&&$System.Status.IsOK(sc2):"OK",1:$System.Status.GetErrorText(sc1)_$System.Status.GetErrorText(sc2))'),
        ],
        ['REMOVED']
      );
      assert.equal(values.REMOVED, 'OK', `the probe database is removed:\n${output}`);
    }
  }
});

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/** Wait until no CSS transition is running, so a contrast read measures the theme it is in. */
function transitionsSettled(page) {
  return page.waitForFunction(
    () => document.getAnimations().every((animation) => !(animation instanceof CSSTransition) || animation.playState !== 'running'),
    { timeout: config.navigationTimeoutMs }
  );
}

/**
 * DW-1337 on `route`: 1280 light (every invariant), 720 light and 1280 dark, against the baseline;
 * with a dialog open, also the dialog body's own sideways overflow.
 */
async function assertStructure(page, route, dialog = false) {
  const entriesFound = [];
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
    await transitionsSettled(page);
    surfaces[theme] = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
    const { entries } = await detectScreen(page, { route, checks, viewport: viewport.width, theme, minimums });
    entriesFound.push(...entries);
    if (!dialog) continue;
    const body = await page.$eval('.ocu-dialog-body', (element) => ({ scroll: element.scrollWidth, client: element.clientWidth }));
    assert.ok(body.scroll <= body.client, `the dialog body does not scroll sideways at ${viewport.width}px ${theme}: ${JSON.stringify(body)}`);
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await frames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  const fresh = compare(collapse(entriesFound), readBaseline()?.entries ?? []).fresh;
  assert.deepEqual(fresh.map((entry) => `${entry.key}: ${entry.measured}`), [], `no structural or contrast violation on ${route}`);
}

/** Open Journal records the way a person does: Journals, the seeded file's details, View records. */
async function openRecords(page) {
  await waitForRows(page, config.navigationTimeoutMs);
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.type(FILTER_SELECTOR, seeded.file);
  await page.waitForFunction(
    (selector, wanted, textSelector) =>
      Array.from(document.querySelectorAll(selector)).some((row) => (row.querySelector(textSelector)?.textContent ?? '').trim() === wanted),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    seeded.file,
    NAME_TEXT
  );
  await clickRowCentre(page, { text: seeded.file, link: true });
  await page.waitForSelector('[data-journal="view-records"]', { visible: true, timeout: config.navigationTimeoutMs });
  await page.click('[data-journal="view-records"]');
  await page.waitForSelector('[data-journal-records="heading"]', { timeout: config.navigationTimeoutMs });
  await waitForRows(page, config.navigationTimeoutMs);
}

/** The rendered rows' text in the column whose field is `field`. */
function columnTexts(page, field) {
  return page.evaluate(
    (rowSelector, wanted) => {
      const headers = Array.from(document.querySelectorAll('.ocu-data-table-header-row [role="columnheader"]'));
      const index = headers.findIndex((header) => header.getAttribute('data-column') === wanted);
      return Array.from(document.querySelectorAll(rowSelector)).map((row) => (row.querySelectorAll('[role="gridcell"]')[index]?.textContent ?? '').trim());
    },
    ROW_SELECTOR,
    field
  );
}

/** Set a criteria field, by its param, to `value`. */
async function setCriterion(page, param, value) {
  const selector = `#ocu-journal-records-${param}`;
  await page.click(selector, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  if (value !== '') await page.type(selector, value);
}

/** Set the max-rows footer field. */
async function setMaxRows(page, cap) {
  await page.click('.ocu-data-table-max-rows', { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type('.ocu-data-table-max-rows', String(cap));
  await page.keyboard.press('Enter');
}

/** Press `selector` and wait for the table to show `first` as its first global node. */
async function pressAndWait(page, selector, first) {
  await page.click(selector);
  await page.waitForFunction(
    (rowSelector, wanted) => {
      const headers = Array.from(document.querySelectorAll('.ocu-data-table-header-row [role="columnheader"]'));
      const index = headers.findIndex((header) => header.getAttribute('data-column') === 'GlobalNode');
      const row = document.querySelector(rowSelector);
      return row !== null && (row.querySelectorAll('[role="gridcell"]')[index]?.textContent ?? '').trim() === wanted;
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    first
  );
}

// AC1. Mutation (Rule 19): drop the arrival from Journal file details' `onViewRecords`, rebuild and
// redeploy -> the page cold-opens through Journals' read and this goes red.
test('AC1, AC7: View records on a file\u2019s details opens Journal records naming that file', async () => {
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  try {
    const reads = [];
    page.on('request', (request) => {
      if (request.url().includes('/api/ocupilot/screens/')) reads.push(request.url());
    });
    await openRecords(page);
    const heading = await page.$eval('[data-journal-records="heading"]', (node) => node.textContent.trim());
    assert.equal(heading, STRINGS.journalRecordsHeading.replace('<file>', seeded.file), 'the page names the file it reads');
    const records = reads.filter((url) => url.includes('/screens/osmgmt.journalrecords/read'));
    assert.ok(records.length > 0 && new URL(records[0]).searchParams.get('file') === seeded.file, `its first read carries the file the arrival named: ${records[0]}`);
    const coldOpen = reads.filter((url) => new URL(url).pathname.endsWith('/screens/osmgmt.journals/read') && new URL(url).searchParams.get('maxRows') === '1');
    assert.deepEqual(coldOpen, [], 'and no cold-open read of Journals was needed');
    assert.ok(page.url().includes(`/ocupilot/${RECORDS_ROUTE}`), `the records route: ${page.url()}`);
    assert.ok((await columnTexts(page, 'Address')).length > 0, 'and lists its records');
    await assertStructure(page, RECORDS_ROUTE);
  } finally {
    await context.close();
  }
});

// AC2. Mutation (Rule 19): make `nextOffset` answer the highest address unchanged, rebuild and
// redeploy -> the next page starts on the tenth record again and goes red.
test('AC2: the probe filter lists the first ten seeded records, and Next records the next ten', async () => {
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  try {
    await openRecords(page);
    await setMaxRows(page, 10);
    await setCriterion(page, 'offset', seeded.offset);
    await setCriterion(page, 'value', 'OcuProbe185');
    await pressAndWait(page, '.ocu-criteria-controls button[type="submit"]', '^OcuProbe185(1)');
    const first = await columnTexts(page, 'GlobalNode');
    assert.deepEqual(first, Array.from({ length: 10 }, (_, index) => `^OcuProbe185(${index + 1})`), 'the first ten seeded records, in order');
    const firstAddresses = await columnTexts(page, 'Address');
    await pressAndWait(page, '[data-journal-records="next"]', '^OcuProbe185(11)');
    const second = await columnTexts(page, 'GlobalNode');
    assert.deepEqual(second, Array.from({ length: 10 }, (_, index) => `^OcuProbe185(${index + 11})`), 'Next records lists the next ten');
    const repeated = (await columnTexts(page, 'Address')).filter((address) => firstAddresses.includes(address));
    assert.deepEqual(repeated, [], 'none repeated');
  } finally {
    await context.close();
  }
});

// AC5. Mutation (Rule 19): render the dialog's values through `[innerHTML]`, rebuild and redeploy ->
// the markup value renders a <b> element and goes red.
test('AC5, AC7: a seeded record opens the dialog, which shows its values as text and closes on Escape', async () => {
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  try {
    await openRecords(page);
    await setCriterion(page, 'offset', seeded.offset);
    await setCriterion(page, 'value', 'OcuProbe185');
    await pressAndWait(page, '.ocu-criteria-controls button[type="submit"]', '^OcuProbe185(1)');
    const nodes = await columnTexts(page, 'GlobalNode');
    const addresses = await columnTexts(page, 'Address');
    const index = nodes.indexOf('^OcuProbe185(16)');
    assert.ok(index >= 0, `the markup record is listed: ${JSON.stringify(nodes)}`);
    await clickRowCentre(page, { index, link: true });
    await page.waitForSelector('[role="dialog"] pre[data-field="NewValue"]', { timeout: config.navigationTimeoutMs });
    const opened = await page.evaluate(() => {
      const dialog = document.querySelector('[role="dialog"]');
      const value = dialog.querySelector('pre[data-field="NewValue"]');
      return {
        title: dialog.querySelector('.ocu-dialog-title').textContent.trim(),
        value: value.textContent,
        markup: value.querySelector('b') !== null,
        reference: (dialog.querySelector('pre[data-field="GlobalReference"]')?.textContent ?? '').trim(),
        url: window.location.pathname,
      };
    });
    assert.equal(opened.title, STRINGS.journalRecordDialogTitle.replace('<offset>', addresses[index]), 'the dialog names the record');
    assert.equal(opened.value, '<b>x</b>', 'the markup value is shown as text');
    assert.equal(opened.markup, false, 'and renders no element');
    assert.ok(opened.reference.includes('OcuProbe185(16)'), `with its global reference: ${opened.reference}`);
    assert.ok(opened.url.startsWith(`/ocupilot/${RECORDS_ROUTE}/`), `on the id route: ${opened.url}`);
    await assertStructure(page, RECORDS_ROUTE, true);
    await page.keyboard.press('Escape');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    const kept = await page.$eval('#ocu-journal-records-value', (node) => node.value);
    assert.equal(kept, 'OcuProbe185', 'closing keeps the criteria');
  } finally {
    await context.close();
  }
});

// AC5. Mutation (Rule 19): make `loadRecord` set no refusal for a faulted read, rebuild and
// redeploy -> the dialog shows no reason and this goes red.
test('AC5: a reloaded record route on an address that holds no record shows the route\u2019s refusal in the dialog', async () => {
  const { values } = iris([mark('REASON', '##class(OcuPilot.Api.JournalError).#REASONRECORDUNREADABLE')], ['REASON']);
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  try {
    await openRecords(page);
    // Address 1 is in the journal file's header, before every record, so the vendor finds none. The
    // reload is a cold open: the page names the newest file through Journals' read, then the dialog
    // asks for address 1 there.
    const record = new URL(page.url());
    record.pathname = `${record.pathname}/1`;
    await page.goto(record.toString(), { waitUntil: 'networkidle2' });
    await page.waitForSelector('[data-journal-records="refusal"]', { timeout: config.navigationTimeoutMs });
    const reason = await page.$eval('[data-journal-records="refusal"]', (node) => node.textContent.trim());
    assert.equal(reason, values.REASON, 'the dialog states the route\u2019s JOURNAL.RECORD.UNREADABLE reason');
    await page.keyboard.press('Escape');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
  } finally {
    await context.close();
  }
});

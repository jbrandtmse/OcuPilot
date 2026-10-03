/**
 * Journals, Journal file details and the journal writes in a real browser, against the throwaway
 * instance (Story 18.5, Part A).
 *
 * What it pins, each on rendered DOM or on the instance itself:
 *
 * 1. **The list** (AC1, AC11): OS management's thirteenth and last side-bar entry reads "Journals",
 *    Logs lists no journal screen, and the list's first row is the file the instance writes now.
 * 2. **Switch file** (AC3): the command bar's screen-level Switch file warns naming that file, and
 *    once proceeded the list re-reads with a new newest file, the one the instance now writes, in
 *    the same directory and with the journal settings unchanged.
 * 3. **Switch directory** (AC4): on a stock throwaway, whose primary and alternate directories are
 *    the same, the switch is refused with `JOURNAL.SWITCHDIR.NOOTHER`'s sentence and nothing moves.
 * 4. **Check integrity** (AC5): a closed file's row action warns naming the file with the "Check every
 *    record" flag, and the status line reads "Integrity check finished." and the clean verdict.
 * 5. **Details** (AC2): the file's name opens Journal file details, which shows its summary and the
 *    databases its records cover.
 * 6. **DW-1337** (AC11): the list, the integrity warning and the details page pass the structural
 *    walk at wide light, narrow light and wide dark.
 *
 * **It refuses the live and development containers.** Its switches close the throwaway's journal
 * file, the first before any leg where the list names no closed file
 * (`OcuPilot.Test.JournalProbe.EnsureClosedFile`); the files they create are the instance's
 * transaction record and stay. It creates no probe
 * object, and asserts the journal settings and directory it found are the ones it leaves.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1
 * browser/journals.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const repoRoot = join(uiRoot, '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();

/** A published server sentence, read from its class rather than restated here. */
function serverSentence(file, parameter) {
  const source = readFileSync(join(repoRoot, 'src', 'OcuPilot', ...file.split('/')), 'utf8');
  const found = new RegExp(`Parameter ${parameter} = "([^"]+)";`).exec(source);
  assert.notEqual(found, null, `${file} declares ${parameter}`);
  return found[1];
}

const NOOTHER_REASON = serverSentence('Api/JournalError.cls', 'REASONSWITCHDIRNOOTHER');

const PROBE = 'OcuPilot.Test.JournalProbe';

const LIST_ROUTE = 'os-management/journals';
const DETAILS_ROUTE = 'os-management/journals/details';
const LIST_URL = `/ocupilot/${LIST_ROUTE}?ns=HSCUSTOM`;
const STATUS = '[data-journal="operation"]';

/** The row cells' own text selector, a name cell being a link. */
const NAME_TEXT = '.ocu-data-table-link, .ocu-data-table-text';

let browser = null;

/** The journal state the spec found, which it leaves as it found it. */
let found = null;

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

/** The journal state: the settings as JSON, the directory written now, and the newest and second listed files. */
function journalState() {
  const { values, output } = iris(
    [
      `Set rows=##class(${PROBE}).Listed()`,
      mark('SETTINGS', `##class(${PROBE}).JournalSettings().%ToJSON()`),
      mark('DIRECTORY', `##class(${PROBE}).CurrentDirectory()`),
      mark('NEWEST', `$Select($IsObject(rows)&&(rows.%Size()>0):rows.%Get(0).%Get("Name"),1:"")`),
      mark('CLOSED', `$Select($IsObject(rows)&&(rows.%Size()>1):rows.%Get(1).%Get("Name"),1:"")`),
    ],
    ['SETTINGS', 'DIRECTORY', 'NEWEST', 'CLOSED']
  );
  assert.ok(values.NEWEST !== null && values.NEWEST !== '', `the instance lists a journal file:\n${output}`);
  return { settings: JSON.parse(values.SETTINGS ?? '{}'), directory: values.DIRECTORY, newest: values.NEWEST, closed: values.CLOSED };
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec switches the journal, so it never runs inside the live container');
  assert.ok(!/^ocupilot-slot-/.test(config.container), 'nor inside a development instance');
  await assertThrowaway(config);
  const { values, output } = iris(
    [`Set sc=##class(${PROBE}).EnsureClosedFile(1)`, mark('ENSURED', '$Select($System.Status.IsOK(sc):"OK",1:$System.Status.GetErrorText(sc))')],
    ['ENSURED']
  );
  assert.equal(values.ENSURED, 'OK', `the throwaway lists a closed journal file, switched for one where none was:\n${output}`);
  found = journalState();
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    if (config.container !== LIVE_CONTAINER && found !== null) {
      const left = journalState();
      assert.deepEqual(left.settings, found.settings, 'the journal settings are the ones the spec found');
      assert.equal(left.directory, found.directory, 'and journaling writes in the directory it found');
    }
  }
});

/** The side bar as rendered: its area and its entry labels, opening it first. */
async function sideBarOf(page) {
  if ((await page.$('app-side-bar nav.ocu-side-bar')) === null) {
    await page.keyboard.down('Control');
    await page.keyboard.press('b');
    await page.keyboard.up('Control');
  }
  await page.waitForSelector('app-side-bar nav.ocu-side-bar', { timeout: config.navigationTimeoutMs });
  return page.evaluate(() => {
    const nav = document.querySelector('app-side-bar nav.ocu-side-bar');
    return {
      area: nav.querySelector('.ocu-side-bar-eyebrow').textContent.trim(),
      entries: Array.from(nav.querySelectorAll('.ocu-side-bar-item .ocu-side-bar-label')).map((label) => label.textContent.trim()),
    };
  });
}

/** The first rendered row's name cell text. */
function firstName(page) {
  return page.evaluate(
    (selector, textSelector) => {
      const cell = document.querySelector(selector)?.querySelector('[role="gridcell"]');
      return ((cell?.querySelector(textSelector) ?? cell)?.textContent ?? '').trim();
    },
    ROW_SELECTOR,
    NAME_TEXT
  );
}

/** Press the command bar's action `label` once it is offered and released. */
async function pressBar(page, label) {
  await page.waitForFunction(
    (wanted) => {
      const button = Array.from(document.querySelectorAll('.ocu-command-bar-action')).find((candidate) => candidate.textContent.trim() === wanted);
      return button !== undefined && !button.disabled && button.getAttribute('aria-disabled') !== 'true';
    },
    { timeout: config.navigationTimeoutMs },
    label
  );
  await page.evaluate((wanted) => {
    Array.from(document.querySelectorAll('.ocu-command-bar-action'))
      .find((button) => button.textContent.trim() === wanted)
      .click();
  }, label);
}

/** The open warning dialog as rendered: its title, consequence and flag. */
async function warningOf(page) {
  await page.waitForSelector('[role="dialog"] .ocu-warning-consequence', { visible: true, timeout: config.navigationTimeoutMs });
  return page.evaluate(() => {
    const dialog = document.querySelector('[role="dialog"]');
    return {
      title: dialog.querySelector('.ocu-dialog-title').textContent.trim(),
      consequence: dialog.querySelector('.ocu-warning-consequence').textContent.trim(),
      flag: (dialog.querySelector('[data-slot="flag"]')?.textContent ?? '').trim(),
    };
  });
}

/** Press the open dialog's Proceed and wait for the dialog to close. */
async function proceed(page) {
  await page.click('[role="dialog"] .ocu-button-primary');
  await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
}

/** Narrow the list to `name`, select its row and open its row menu. */
async function openRowMenu(page, name) {
  await waitForRows(page, config.navigationTimeoutMs);
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, name);
  await page.waitForFunction(
    (selector, wanted, textSelector) =>
      Array.from(document.querySelectorAll(selector)).some((row) => {
        const cell = row.querySelector('[role="gridcell"]');
        const text = cell.querySelector(textSelector);
        return (text === null ? cell : text).textContent.trim() === wanted;
      }),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name,
    NAME_TEXT
  );
  await clickRowCentre(page, { text: name, cell: 2 });
  await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
}

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

// AC1, AC11. Mutation (Rule 19): give JournalList `sideBarPosition` 0 and regenerate the mirror,
// rebuild and redeploy -> the side-bar assertion goes red.
test('AC1, AC11: Journals is the thirteenth OS management entry, Logs lists no journal screen, and the first row is the file the instance writes now', async () => {
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const bar = await sideBarOf(page);
    assert.equal(bar.area, STRINGS.navAreaOsManagement);
    assert.equal(bar.entries.length, 14, `fourteen entries: ${JSON.stringify(bar.entries)}`);
    assert.equal(bar.entries[12], STRINGS.journalListLabel, 'Journals is the thirteenth');
    // Story 18.18: Journal settings follows it.
    assert.equal(bar.entries[13], STRINGS.journalSettingsLabel, 'Journal settings is the fourteenth');
    const headers = await page.$$eval('.ocu-data-table-header-label', (labels) => labels.map((label) => label.textContent.trim()));
    assert.deepEqual(headers.slice(0, 5), [STRINGS.tableColumnName, STRINGS.journalColumnCreated, STRINGS.databaseColumnSize, STRINGS.journalColumnDataSize, STRINGS.agentSwitchesFieldReason]);
    assert.equal(await firstName(page), journalState().newest, 'the first row is the newest listed file');
    await assertStructure(page, LIST_ROUTE);
    await page.click(`.ocu-rail-item[aria-label="${STRINGS.navAreaLogs}"]`);
    await page.waitForFunction(
      (label) => document.querySelector('app-side-bar .ocu-side-bar-eyebrow')?.textContent?.trim() === label,
      { timeout: config.navigationTimeoutMs },
      STRINGS.navAreaLogs
    );
    const logs = await page.$$eval('.ocu-side-bar-item .ocu-side-bar-label', (items) => items.map((item) => item.textContent.trim()));
    assert.ok(!logs.includes(STRINGS.journalListLabel), `Logs lists no journal screen: ${JSON.stringify(logs)}`);
  } finally {
    await context.close();
  }
});

// AC3. Mutation (Rule 19): drop the `<file>` fill from the handler's warning, rebuild and redeploy ->
// the consequence assertion goes red on the bare placeholder.
test('AC3: Switch file warns naming the file the instance writes now, and the list re-reads with a new newest file in the same directory', async () => {
  const before = journalState();
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    assert.equal(await firstName(page), before.newest);
    await pressBar(page, STRINGS.journalSwitchFileAction);
    assert.deepEqual(await warningOf(page), {
      title: STRINGS.journalSwitchFileAction,
      consequence: STRINGS.journalSwitchFileConsequence.replace('<file>', () => before.newest),
      flag: '',
    });
    await proceed(page);
    await page.waitForFunction(
      (selector, textSelector, old) => {
        const cell = document.querySelector(selector)?.querySelector('[role="gridcell"]');
        const name = ((cell?.querySelector(textSelector) ?? cell)?.textContent ?? '').trim();
        return name !== '' && name !== old;
      },
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      NAME_TEXT,
      before.newest
    );
    const after = journalState();
    assert.notEqual(after.newest, before.newest, 'the instance writes a new file');
    assert.equal(await firstName(page), after.newest, 'which the list shows first');
    assert.equal(after.directory, before.directory, 'in the same directory');
    assert.deepEqual(after.settings, before.settings, 'and the journal settings are unchanged');
  } finally {
    await context.close();
  }
});

// AC4. Mutation (Rule 19): drop the NOOTHER refusal from `JournalPort`'s DIRSTATE read, reload ->
// the fresh read names no other directory, the tool refuses the switch with another reason, and the
// banner assertion goes red.
test('AC4: on one journal directory Switch directory is refused with the published sentence and nothing moves', async () => {
  const before = journalState();
  assert.equal(before.settings.CurrentDirectory, before.settings.AlternateDirectory, 'the throwaway has one journal directory');
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await pressBar(page, STRINGS.journalSwitchDirectoryAction);
    const dialog = await warningOf(page);
    assert.equal(dialog.consequence, STRINGS.journalSwitchDirectoryConsequence);
    await proceed(page);
    await page.waitForFunction(
      (wanted) => (document.querySelector('.ocu-list-page-banner[role="alert"] .ocu-banner-message')?.textContent ?? '').trim() === wanted,
      { timeout: config.navigationTimeoutMs },
      NOOTHER_REASON
    );
    const after = journalState();
    assert.equal(after.newest, before.newest, 'no switch happened');
    assert.deepEqual(after.settings, before.settings, 'and the settings are unchanged');
  } finally {
    await context.close();
  }
});

// AC5, AC11. Mutation (Rule 19): drop the verdict paragraph from journal-list.page.ts's template,
// rebuild and redeploy -> the verdict wait goes red.
test('AC5, AC11: Check integrity warns naming a closed file with its flag, and the status line reads finished and the clean verdict', async () => {
  const state = journalState();
  assert.ok(state.closed !== null && state.closed !== '', 'the instance lists a closed journal file');
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  try {
    await openRowMenu(page, state.closed);
    await page.evaluate((label) => {
      Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'))
        .find((item) => item.textContent.trim().startsWith(label))
        .click();
    }, STRINGS.databaseIntegrityLabel);
    assert.deepEqual(await warningOf(page), {
      title: STRINGS.databaseIntegrityLabel,
      consequence: STRINGS.journalIntegrityConsequence.replace('<file>', () => state.closed),
      flag: STRINGS.journalIntegrityEveryRecord,
    });
    assert.equal(await page.$eval('[role="dialog"] [data-slot="flag"] input', (input) => input.checked), false, 'the flag opens unchecked');
    await assertStructure(page, LIST_ROUTE, true);
    await proceed(page);
    await page.waitForFunction(
      (wanted) => (document.querySelector('[data-journal="verdict"]')?.textContent ?? '').trim() === wanted,
      { timeout: 90000 },
      STRINGS.journalIntegrityClean.replace('<file>', () => state.closed)
    );
    const status = await page.$eval(`${STATUS} p`, (node) => node.textContent.trim());
    assert.equal(status, STRINGS.databaseOperationFinished.replace('<operation>', () => STRINGS.databaseIntegrityCheck));
    assert.equal(await page.$('[data-journal="lines"]'), null, 'a clean check shows no lines');
  } finally {
    await context.close();
  }
});

// AC2, AC11. Mutation (Rule 19): drop JournalFileDetails from DESCRIPTOR_PAGES, rebuild and redeploy
// -> the summary wait goes red.
test('AC2, AC11: a file name opens Journal file details with its summary and its databases', async () => {
  const state = journalState();
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await page.click(FILTER_SELECTOR, { clickCount: 3 });
    await page.type(FILTER_SELECTOR, state.closed);
    await page.waitForFunction(
      (selector, wanted, textSelector) =>
        Array.from(document.querySelectorAll(selector)).some((row) => (row.querySelector(textSelector)?.textContent ?? '').trim() === wanted),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      state.closed,
      NAME_TEXT
    );
    await clickRowCentre(page, { text: state.closed, link: true });
    await page.waitForSelector('[data-journal="summary"]', { timeout: config.navigationTimeoutMs });
    const name = await page.$eval('.ocu-details-field[data-field="Name"] .ocu-details-field-value', (node) => node.textContent.trim());
    assert.equal(name, state.closed, 'the summary is the file the name named');
    await page.waitForSelector('[data-journal="databases"] tbody tr', { timeout: config.navigationTimeoutMs });
    const databases = await page.$$eval('[data-journal="databases"] tbody tr', (rows) => rows.length);
    assert.ok(databases > 0, 'the file covers at least one database');
    assert.ok(page.url().includes(`/${DETAILS_ROUTE}/`), `the details route: ${page.url()}`);
    await assertStructure(page, DETAILS_ROUTE);
  } finally {
    await context.close();
  }
});

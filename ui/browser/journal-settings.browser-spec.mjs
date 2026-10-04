/**
 * Journal settings in a real browser, against the throwaway instance (Story 18.18).
 *
 * What it pins, each on rendered DOM or on the instance itself:
 *
 * 1. **The form** (AC1, AC9): OS management's fourteenth side-bar entry reads "Journal
 *    settings", and the form shows the instance's thirteen settings, the archive target and the
 *    write image journal's two read-only with the shown-only hint.
 * 2. **A Save** (AC2): a changed file size is sent alone, the instance holds it and the form reads
 *    "Saved" with its read-back; the size found is then saved back.
 * 3. **A refused directory** (AC3): the primary's picker with the manager directory and an empty name
 *    is refused `PATH.MANAGERDIR` on its path field, and nothing changes.
 * 4. **DW-1337** (AC9): the form passes the structural walk at wide light, narrow light and wide
 *    dark.
 *
 * **It refuses the live and development containers.** Its Save starts a journal file on the
 * throwaway, which stays; it creates no probe object, and asserts the journal settings and directory
 * it found are the ones it leaves, putting them back through `OcuPilot.Test.JournalProbe` first when a
 * leg failed part-way.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1
 * browser/journal-settings.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { saveAndSettle, signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { sideBarLabels } from './side-bar-spec.mjs';

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

const MANAGERDIR_REASON = serverSentence('Api/Error.cls', 'REASONPATHMANAGERDIR');

const PROBE = 'OcuPilot.Test.JournalProbe';

const ROUTE = 'os-management/journal-settings';
const URL_AT = `/ocupilot/${ROUTE}?ns=HSCUSTOM`;
const SAVE_PATH = '/api/ocupilot/journal/settings';

/** The thirteen fields' control ids, each the form's own. */
const FIELD_IDS = [
  'CurrentDirectory',
  'AlternateDirectory',
  'FileSizeLimit',
  'JournalFilePrefix',
  'ArchiveName',
  'PurgeArchived',
  'DaysBeforePurge',
  'BackupsBeforePurge',
  'FreezeOnError',
  'JournalcspSession',
  'CompressFiles',
  'wijdir',
  'targwijsz',
].map((field) => `#ocu-journal-settings-${field}`);

let browser = null;

/** The journal state the spec found, which it leaves as it found it. */
let found = null;

/** The manager directory, the one allowed root of a stock instance. */
let managerDirectory = '';

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

/** The journal state: the settings as JSON and the directory written now. */
function journalState() {
  const { values, output } = iris(
    [mark('SETTINGS', `##class(${PROBE}).JournalSettings().%ToJSON()`), mark('DIRECTORY', `##class(${PROBE}).CurrentDirectory()`)],
    ['SETTINGS', 'DIRECTORY']
  );
  assert.ok(values.SETTINGS !== null && values.SETTINGS !== '{}', `the journal settings are read:\n${output}`);
  return { settings: JSON.parse(values.SETTINGS), directory: values.DIRECTORY };
}

/** Put the journal settings found back, through the probe the ObjectScript suites restore with. */
function restore() {
  const json = JSON.stringify(found.settings).replace(/"/g, '""');
  const { values, output } = iris(
    [`Set sc=##class(${PROBE}).RestoreJournal(##class(%DynamicObject).%FromJSON("${json}"))`, mark('RESTORED', '$Select($System.Status.IsOK(sc):"OK",1:$System.Status.GetErrorText(sc))')],
    ['RESTORED']
  );
  assert.equal(values.RESTORED, 'OK', `the journal settings found are restored:\n${output}`);
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec changes the journal settings, so it never runs inside the live container');
  assert.ok(!/^ocupilot-slot-/.test(config.container), 'nor inside a development instance');
  await assertThrowaway(config);
  found = journalState();
  const { values } = iris([mark('MGR', `##class(${PROBE}).Manager()`)], ['MGR']);
  managerDirectory = values.MGR ?? '';
  assert.ok(managerDirectory !== '', 'the manager directory is read');
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    if (config.container !== LIVE_CONTAINER && found !== null) {
      let left = journalState();
      if (JSON.stringify(left.settings) !== JSON.stringify(found.settings)) {
        restore();
        left = journalState();
      }
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

/** Wait until the form has drawn its fields. */
function formDrawn(page) {
  return page.waitForSelector('#ocu-journal-settings-FileSizeLimit', { visible: true, timeout: config.navigationTimeoutMs });
}

/** Replace the text of input `selector` with `value`. */
async function retype(page, selector, value) {
  await page.click(selector, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  if (value !== '') await page.type(selector, value);
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

/** DW-1337 on `route`: 1280 light (every invariant), 720 light and 1280 dark, against the baseline. */
async function assertStructure(page, route) {
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
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await frames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  const fresh = compare(collapse(entriesFound), readBaseline()?.entries ?? []).fresh;
  assert.deepEqual(fresh.map((entry) => `${entry.key}: ${entry.measured}`), [], `no structural or contrast violation on ${route}`);
}

// AC1, AC9. Mutation (Rule 19): give JournalSettings `sideBarPosition` 0 and regenerate the mirror,
// rebuild and redeploy -> the side-bar assertion goes red.
test('AC1, AC9: Journal settings is the fourteenth OS management entry and shows the thirteen settings, three read-only with the shown-only hint', async () => {
  const { context, page } = await signedInAt(browser, config, URL_AT, VIEWPORTS.wide);
  try {
    await formDrawn(page);
    const bar = await sideBarOf(page);
    assert.equal(bar.area, STRINGS.navAreaOsManagement);
    // Story 18.6: License key and License servers follow it; Story 18.20: ECP data servers follows them,
    // and Story 18.21: ECP settings and ECP application servers follow that.
    assert.deepEqual(bar.entries, sideBarLabels('os-management'), 'the OS management entries in their declared order');
    assert.equal(bar.entries[12], STRINGS.journalListLabel, 'Journals is the thirteenth');
    assert.equal(bar.entries[13], STRINGS.journalSettingsLabel, 'Journal settings is the fourteenth');
    for (const id of FIELD_IDS) assert.notEqual(await page.$(id), null, `${id} is drawn`);
    assert.equal(await page.$eval('#ocu-journal-settings-CurrentDirectory', (input) => input.value), found.settings.CurrentDirectory, 'the primary directory the instance holds');
    assert.equal(await page.$eval('#ocu-journal-settings-FileSizeLimit', (input) => input.value), found.settings.FileSizeLimit, 'and its file size');
    for (const id of ['#ocu-journal-settings-ArchiveName', '#ocu-journal-settings-wijdir', '#ocu-journal-settings-targwijsz']) {
      const shown = await page.$eval(id, (input) => ({ readOnly: input.readOnly, describedBy: input.getAttribute('aria-describedby') }));
      assert.deepEqual(shown, { readOnly: true, describedBy: 'ocu-journal-settings-shown-only' }, `${id} is read-only, described by the shown-only hint`);
    }
    assert.equal(await page.$eval('#ocu-journal-settings-shown-only', (hint) => hint.textContent.trim()), STRINGS.journalSettingsShownOnly);
  } finally {
    await context.close();
  }
});

// AC2. Mutation (Rule 19): send every text field in the store's `saveBody`, rebuild and redeploy ->
// the sent-body assertion goes red.
test('AC2: a changed file size is sent alone, held by the instance and read back, then saved back', async () => {
  const size = found.settings.FileSizeLimit === '1000' ? '1001' : '1000';
  const { context, page } = await signedInAt(browser, config, URL_AT, VIEWPORTS.wide);
  const puts = [];
  page.on('request', (request) => {
    if (request.method() === 'PUT' && new URL(request.url()).pathname === SAVE_PATH) puts.push(request.postData() ?? '');
  });
  try {
    await formDrawn(page);
    await retype(page, '#ocu-journal-settings-FileSizeLimit', size);
    await saveAndSettle(page, config);
    assert.deepEqual(puts.map((body) => JSON.parse(body)), [{ FileSizeLimit: Number(size) }], 'one Save, carrying the size alone');
    assert.equal(journalState().settings.FileSizeLimit, size, 'the instance holds it');
    const status = await page.$eval('.ocu-form-bar-status [role="status"]', (line) => line.textContent.trim());
    assert.ok(status.startsWith(STRINGS.formSaved), `the form reads Saved: ${status}`);
    assert.ok(status.includes(STRINGS.readBackMatches), `with the read-back: ${status}`);

    await page.waitForFunction((wanted) => document.querySelector('#ocu-journal-settings-FileSizeLimit')?.value === wanted, { timeout: config.navigationTimeoutMs }, size);
    await retype(page, '#ocu-journal-settings-FileSizeLimit', found.settings.FileSizeLimit);
    await saveAndSettle(page, config);
    assert.equal(journalState().settings.FileSizeLimit, found.settings.FileSizeLimit, 'and the size found is saved back');
  } finally {
    await context.close();
  }
});

// AC3. Mutation (Rule 19): make the store drop the picker's path violations, rebuild and redeploy ->
// the PATH.MANAGERDIR reason never renders under the picker and this goes red.
test('AC3: the primary directory picked as the manager directory itself is refused on its path field, and nothing changes', async () => {
  const { context, page } = await signedInAt(browser, config, URL_AT, VIEWPORTS.wide);
  try {
    await formDrawn(page);
    await page.click('[data-action="change-primary"]');
    const select = '#ocu-journal-settings-primary-root';
    await page.waitForSelector(select, { visible: true, timeout: config.navigationTimeoutMs });
    const roots = await page.$$eval(`${select} option`, (options) => options.map((option) => option.value));
    assert.ok(roots.includes(managerDirectory), `the picker offers the manager directory: ${JSON.stringify(roots)}`);
    if (roots.length > 1) await page.select(select, managerDirectory);
    await retype(page, '#ocu-journal-settings-primary-path', '');
    await page.click('.ocu-form-bar-actions .ocu-button-primary');
    await page.waitForFunction(
      (wanted) => document.querySelector('#ocu-journal-settings-primary-path-reason')?.textContent.trim() === wanted,
      { timeout: config.navigationTimeoutMs },
      MANAGERDIR_REASON
    );
    assert.equal(await page.$eval('#ocu-journal-settings-primary-path', (input) => input.getAttribute('aria-invalid')), 'true');
    assert.deepEqual(journalState().settings, found.settings, 'nothing changed');
  } finally {
    await context.close();
  }
});

// AC9, DW-1337. Mutation (Rule 19): give the shown-only hint a fixed width wider than the narrow
// viewport, rebuild and redeploy -> the overflow check goes red.
test('AC9, DW-1337: the form passes the structural walk in both themes', async () => {
  const { context, page } = await signedInAt(browser, config, URL_AT, VIEWPORTS.wide);
  try {
    await formDrawn(page);
    await assertStructure(page, ROUTE);
  } finally {
    await context.close();
  }
});

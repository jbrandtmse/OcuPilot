/**
 * Story 18.4's disk operations in a real browser, against the throwaway instance.
 *
 * What it pins, each on rendered DOM, on the request the page sent, or on the instance itself:
 *
 * 1. **Database details' five operations** (AC1): Defragment, Compact, Truncate, Dismount and Mount
 *    (read-only, then plain) are each confirmed in their warning dialog, send the body the matrix
 *    names, show the running line and then "<operation> finished.", and re-read the properties.
 * 2. **IRISSYS** (AC5): its Dismount dialog states the prohibited set's refusal when it opens; the leg
 *    only opens and cancels it.
 * 3. **Size and Add a volume** (AC3): a grown Size is sent as the `size` group and reads back; Add a
 *    volume is `aria-disabled` with its reason while the form is dirty, and once confirmed with an
 *    initial size the volume files list the new `IRIS-0001.VOL`.
 * 4. **The Check integrity flow and the Integrity log** (AC6, AC7): Databases' Check integrity opens
 *    the flow; one database with a global named, then two sent as their canonical set, each show the
 *    finished check's report; the log lists both checks newest first and shows the selected one's.
 * 5. **DW-1337** (AC12): the new screens, and the dialogs with a field or an advisory open, pass the
 *    structural walk at wide light, narrow light and wide dark.
 * 6. **An admin API compact** (AC10, DW-1821): one started through `DatabasePort` over `docker exec`,
 *    as another user, and paused, is listed on Database details for its directory and once on
 *    Background tasks.
 *
 * **It refuses the live and development containers.** It seeds `OCUPROBE184BO`, `OCUPROBE184BG` and
 * `OCUPROBE184BC` through OcuPilot's own create route, fills two of them with the probe global over
 * `docker exec`, and removes every one -- the background tasks and integrity checks over their
 * directories, each configuration, file, directory and `%DB_*` resource -- by exact name before and
 * after, including on failure, asserting none survives.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1
 * browser/database-operations.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { ROW_SELECTOR, waitForRows } from './list-spec.mjs';
import { authHeader, saveAndSettle, signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));
const { encodeEntityId } = await import(join(uiRoot, 'src', 'app', 'core', 'entity-id.ts'));

const config = browserConfig();

/** The database the details leg operates on, the one the editor leg grows, and the second one checked. */
const OPERATED = 'OCUPROBE184BO';
const GROWN = 'OCUPROBE184BG';
const CHECKED = 'OCUPROBE184BC';
const DATABASES = [OPERATED, GROWN, CHECKED];

/** The global the probe class fills a database with, and the one the flow names. */
const PROBE = 'OcuPilot.Test.DatabaseActionProbe';
const GLOBAL = 'OcuProbe184Fill';

/** The volume Add a volume creates in a database with no other new volume directory. */
const FIRST_VOLUME = 'IRIS-0001.VOL';

const DETAILS_ROUTE = 'os-management/databases/details';
const LIST_ROUTE = 'os-management/databases';
const FLOW_ROUTE = 'os-management/databases/integrity';
const LOG_ROUTE = 'os-management/databases/integrity-log';
const FORM_ROUTE = 'os-management/local-databases/edit';
const detailsUrl = (directory) => `/ocupilot/${DETAILS_ROUTE}/${encodeEntityId(directory)}?ns=HSCUSTOM`;
const LIST_URL = `/ocupilot/${LIST_ROUTE}?ns=HSCUSTOM`;
const FLOW_URL = `/ocupilot/${FLOW_ROUTE}?ns=HSCUSTOM`;
const LOG_URL = `/ocupilot/${LOG_ROUTE}?ns=HSCUSTOM`;
const EDIT_URL = `/ocupilot/${FORM_ROUTE}/${encodeEntityId(GROWN)}?ns=HSCUSTOM`;

const CREATE_PATH = '/api/ocupilot/database';
const DETAILS_ACTION_PATH = '/api/ocupilot/screens/osmgmt.databasedetails/action';
const LIST_ACTION_PATH = '/api/ocupilot/screens/osmgmt.databases/action';
const LOCAL_ACTION_PATH = '/api/ocupilot/screens/osmgmt.localdatabases/action';

/** The status lines the legs watch: Database details', the editor's volumes section's and the flow's. */
const DETAILS_STATUS = '[data-database="operation"]';
const VOLUME_STATUS = '[data-volume="operation"]';
const FLOW_STATUS = '[data-integrity="status"]';

let browser = null;

/** The instance's manager directory, read in `before`. */
let managerDirectory = '';

const mark = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/** Run `lines` in `namespace` inside the throwaway and return the value each named marker carries. */
function iris(namespace, lines, names = []) {
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', namespace], {
    input: `${[...lines, 'Halt'].join('\n')}\n`,
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const values = {};
  for (const name of names) {
    const found = new RegExp(`OCU-${name}-START:(.*?):OCU-${name}-END`).exec(output);
    values[name] = found === null ? null : found[1].trim();
  }
  return { values, output };
}

const irisSys = (lines, names) => iris('%SYS', lines, names);

/** A probe database's directory, as the create composes it under the manager directory. */
const directoryOf = (name) => `${managerDirectory}${name.toLowerCase()}/`;

/** The ObjectScript condition "no background task or integrity check names a probe directory of this spec". */
function tasksGone() {
  const probe = `${managerDirectory}ocuprobe184b`;
  return [
    `Set n=0,rs=##class(%ResultSet).%New("%SYS.BackgroundTask:DatabaseList") If $System.Status.IsOK(rs.Execute()) { While rs.Next() { If $ZConvert(rs.Get("Database"),"L")["${probe}" Set n=n+1 } }`,
    `Set rs=##class(%ResultSet).%New("SYS.BackgroundIntegrity:ListIntegrityTasks") If $System.Status.IsOK(rs.Execute()) { While rs.Next() { If $ZConvert($ListToString(rs.Get("DatabaseList")),"L")["${probe}" Set n=n+1 } }`,
  ];
}

/**
 * Remove every probe object by its exact name: the background tasks and integrity checks over the
 * probe directories (`DatabaseActionProbe.RemoveTasks`), then each configuration, each file
 * (dismounted first) and its directory tree, and each `%DB_*` resource. Test-only.
 */
function cleanup() {
  const tasks = iris('HSCUSTOM', [`Set sc=##class(${PROBE}).RemoveTasks()`, mark('TASKS', '$Select($System.Status.IsOK(sc):"ok",1:$System.Status.GetErrorText(sc))')], ['TASKS']);
  assert.equal(tasks.values.TASKS, 'ok', `the probe tasks and checks were removed:\n${tasks.output}`);
  const { values, output } = irisSys(
    [
      ...DATABASES.map((name) => `If ##class(Config.Databases).Exists("${name}") Do ##class(Config.Databases).Delete("${name}")`),
      ...DATABASES.map(directoryOf).map(
        (dir) => `If ##class(SYS.Database).%ExistsId("${dir}") Do ##class(SYS.Database).DismountDatabase("${dir}"),##class(SYS.Database).DeleteDatabase("${dir}")`
      ),
      ...DATABASES.map(directoryOf).map((dir) => `If ##class(%File).DirectoryExists("${dir}") Do ##class(%File).RemoveDirectoryTree("${dir}")`),
      ...DATABASES.map((name) => `If ##class(Security.Resources).Exists("%DB_${name}") Do ##class(Security.Resources).Delete("%DB_${name}")`),
      ...tasksGone(),
      mark(
        'CLEAN',
        [
          '(n=0)',
          ...DATABASES.map((name) => `('##class(Config.Databases).Exists("${name}"))`),
          ...DATABASES.map((name) => `('##class(Security.Resources).Exists("%DB_${name}"))`),
          ...DATABASES.map((name) => `('##class(%File).DirectoryExists("${directoryOf(name)}"))`),
        ].join('&&')
      ),
    ],
    ['CLEAN']
  );
  assert.equal(values.CLEAN, '1', `no probe database, directory, resource, background task or integrity check survives:\n${output}`);
}

/** Seed database `name` through OcuPilot's own create route, under the manager directory. */
async function seed(name) {
  const response = await fetch(`${config.origin}${CREATE_PATH}`, {
    method: 'POST',
    headers: { Authorization: authHeader(config), 'Content-Type': 'application/json' },
    body: JSON.stringify({ Name: name, root: managerDirectory, path: name.toLowerCase(), Size: 1, GlobalJournalState: true }),
  });
  assert.equal(response.status, 201, `${name} was seeded: ${await response.text()}`);
}

/** Write about `mb` megabytes of the probe global into `name` and remove its first half (test-only seeding). */
function fill(name, mb) {
  const { values, output } = iris('HSCUSTOM', [`Set sc=##class(${PROBE}).Fill("${name}",${mb})`, mark('FILL', '$System.Status.IsOK(sc)')], ['FILL']);
  assert.equal(values.FILL, '1', `${name} was filled:\n${output}`);
}

/** The file at `dir` as `SYS.Database` holds it: mounted, mounted read-only, and its size in MB. */
function fileAt(dir) {
  const { values, output } = irisSys(
    [`Set tDb=##class(SYS.Database).%OpenId("${dir}")`, mark('FILE', '$Select($IsObject(tDb):tDb.Mounted_"|"_tDb.ReadOnlyMounted_"|"_tDb.Size,1:"<absent>")')],
    ['FILE']
  );
  assert.ok(values.FILE !== null && values.FILE !== '<absent>', `the file at ${dir} was read:\n${output}`);
  const [mounted, readOnly, size] = values.FILE.split('|');
  return { mounted: mounted === '1', readOnly: readOnly === '1', size: Number(size) };
}

/** Whether `path` exists inside the throwaway. */
function fileExists(path) {
  return irisSys([mark('EXISTS', `##class(%File).Exists("${path}")`)], ['EXISTS']).values.EXISTS === '1';
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates, dismounts and deletes databases, so it never runs inside the live container');
  assert.ok(!/^ocupilot-slot-/.test(config.container), 'nor inside a development instance');
  await assertThrowaway(config);
  const { values, output } = irisSys([mark('MGR', '$System.Util.ManagerDirectory()')], ['MGR']);
  assert.ok(values.MGR, `the manager directory was read:\n${output}`);
  managerDirectory = values.MGR;
  cleanup();
  for (const name of DATABASES) await seed(name);
  fill(OPERATED, 8);
  fill(CHECKED, 1);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    if (config.container !== LIVE_CONTAINER && managerDirectory !== '') cleanup();
  }
});

/** Record the body of every POST the page sends to `path`. */
function recordPosts(page, path) {
  const bodies = [];
  page.on('request', (request) => {
    if (request.method() === 'POST' && new URL(request.url()).pathname === path) bodies.push(JSON.parse(request.postData() ?? '{}'));
  });
  return bodies;
}

/** The command bar's actions, Refresh and Check permission aside. */
function commandBar(page) {
  return page.$$eval('.ocu-command-bar-action', (buttons) =>
    buttons
      .filter((button) => !button.classList.contains('ocu-command-bar-refresh-action') && !button.classList.contains('ocu-command-bar-permission-check'))
      .map((button) => button.textContent.trim())
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

/** The open warning dialog as rendered: its title, consequence, advisory, flag, field and hint, and Proceed's state. */
function warningOf(page) {
  return page.evaluate(() => {
    const dialog = document.querySelector('[role="dialog"]');
    const proceed = dialog.querySelector('.ocu-button-primary');
    return {
      title: dialog.querySelector('.ocu-dialog-title').textContent.trim(),
      consequence: dialog.querySelector('.ocu-warning-consequence').textContent.trim(),
      advisory: (dialog.querySelector('[data-slot="advisory"] .ocu-banner-message')?.textContent ?? '').trim(),
      flag: (dialog.querySelector('[data-slot="flag"]')?.textContent ?? '').trim(),
      field: (dialog.querySelector('[data-slot="field"] .ocu-field-label')?.textContent ?? '').trim(),
      hint: (dialog.querySelector('[data-slot="field"] .ocu-field-caption')?.textContent ?? '').trim(),
      proceedDisabled: proceed.getAttribute('aria-disabled') === 'true',
    };
  });
}

/** Open the warning dialog of the command bar's action `label` and answer it as rendered. */
async function openWarning(page, label) {
  await pressBar(page, label);
  await page.waitForSelector('[role="dialog"] .ocu-warning-consequence', { visible: true, timeout: config.navigationTimeoutMs });
  return warningOf(page);
}

/** Type `value` into the open dialog's field, and wait for Proceed to answer it. */
async function typeField(page, value) {
  await page.type('[role="dialog"] [data-slot="field"] input', value);
  await page.waitForFunction(
    () => document.querySelector('[role="dialog"] .ocu-button-primary')?.getAttribute('aria-disabled') !== 'true',
    { timeout: config.navigationTimeoutMs }
  );
}

/** Press the open dialog's Proceed and wait for the dialog to close. */
async function proceed(page) {
  await page.click('[role="dialog"] .ocu-button-primary');
  await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
}

/** Escape the open dialog and wait for it to close. */
async function dismiss(page) {
  await page.keyboard.press('Escape');
  await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
}

/** Record every text the status line `selector` shows from now on, since a fast operation's running line lasts a moment. */
async function watchStatus(page, selector) {
  await page.waitForSelector(selector, { timeout: config.navigationTimeoutMs });
  await page.evaluate((wanted) => {
    const node = document.querySelector(wanted);
    const seen = [];
    window.__ocuStatus = seen;
    new MutationObserver(() => seen.push(node.textContent.trim())).observe(node, { childList: true, characterData: true, subtree: true });
  }, selector);
}

/** Wait until the watched status line reads "<operation> finished.", and answer every text it showed. */
async function finishedLine(page, selector, operation) {
  const finished = STRINGS.databaseOperationFinished.replace('<operation>', () => operation);
  await page.waitForFunction(
    (wanted, line) => (document.querySelector(wanted)?.textContent ?? '').trim() === line,
    { timeout: 180000 },
    selector,
    finished
  );
  const seen = await page.evaluate(() => window.__ocuStatus.splice(0));
  const running = runningLine(operation);
  assert.ok(seen.some((text) => running.test(text)), `${operation} showed its running line before it finished: ${JSON.stringify(seen)}`);
  assert.equal(seen.at(-1), finished);
}

/** The running line of `operation`, its time any `HH:MM:SS`. */
function runningLine(operation) {
  const escape = (text) => text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const [head, tail] = escape(STRINGS.databaseOperationRunning.replace('<operation>', () => operation)).split('<time>');
  return new RegExp(`^${head}\\d{2}:\\d{2}:\\d{2}${tail}$`);
}

/** The text of Database details' field labelled `label`. */
function fieldText(page, label) {
  return page.evaluate(
    (wanted) =>
      Array.from(document.querySelectorAll('.ocu-details-field'))
        .find((field) => field.querySelector('.ocu-details-field-label')?.textContent.trim() === wanted)
        ?.querySelector('.ocu-details-field-value')
        ?.textContent.trim() ?? null,
    label
  );
}

/** Wait until Database details' field `label` reads other than `was`, and answer what it reads. */
async function fieldChanges(page, label, was) {
  await page.waitForFunction(
    (wanted, before) => {
      const field = Array.from(document.querySelectorAll('.ocu-details-field')).find(
        (candidate) => candidate.querySelector('.ocu-details-field-label')?.textContent.trim() === wanted
      );
      const text = field?.querySelector('.ocu-details-field-value')?.textContent.trim() ?? null;
      return text !== null && text !== before;
    },
    { timeout: config.navigationTimeoutMs },
    label,
    was
  );
  return fieldText(page, label);
}

/** Wait until Database details' Size field shows `mb`, the size the instance holds. */
async function shownSize(page, mb) {
  await page.waitForFunction(
    (wanted, size) => {
      const field = Array.from(document.querySelectorAll('.ocu-details-field')).find(
        (candidate) => candidate.querySelector('.ocu-details-field-label')?.textContent.trim() === wanted
      );
      return Number((field?.querySelector('.ocu-details-field-value')?.textContent ?? '').replace(/[^0-9.]/g, '')) === size;
    },
    { timeout: config.navigationTimeoutMs },
    STRINGS.databaseColumnSize,
    mb
  );
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
    await transitionsSettled(page);
    surfaces[theme] = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
    const { entries } = await detectScreen(page, { route, checks, viewport: viewport.width, theme, minimums });
    found.push(...entries);
    if (!dialog) continue;
    const body = await page.$eval('.ocu-dialog-body', (element) => ({ scroll: element.scrollWidth, client: element.clientWidth }));
    assert.ok(body.scroll <= body.client, `the dialog body does not scroll sideways at ${viewport.width}px ${theme}: ${JSON.stringify(body)}`);
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await frames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  const fresh = compare(collapse(found), readBaseline()?.entries ?? []).fresh;
  assert.deepEqual(fresh.map((entry) => `${entry.key}: ${entry.measured}`), [], `no structural or contrast violation on ${route}`);
}

/** Press the form bar's primary and wait until the stepper's current step reads `label`. */
async function nextTo(page, label) {
  await page.click('.ocu-form-bar-actions .ocu-button-primary');
  await page.waitForFunction(
    (wanted) => document.querySelector('.ocu-form-step-head[aria-current="step"] .ocu-form-step-label')?.textContent.trim() === wanted,
    { timeout: config.navigationTimeoutMs },
    label
  );
}

/** Replace the text of input `selector` with `value`. */
async function retype(page, selector, value) {
  await page.click(selector, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  if (value !== '') await page.type(selector, value);
}

/** Check the flow's checklist row for each directory in `directories`, in that order. */
async function checkDatabases(page, directories) {
  await page.waitForSelector('[data-integrity="databases"] label[data-directory]', { visible: true, timeout: config.navigationTimeoutMs });
  for (const directory of directories) {
    const clicked = await page.evaluate((wanted) => {
      const row = Array.from(document.querySelectorAll('[data-integrity="databases"] label[data-directory]')).find(
        (label) => label.getAttribute('data-directory').toLowerCase() === wanted.toLowerCase()
      );
      if (row === undefined) return false;
      row.querySelector('input[type="checkbox"]').click();
      return true;
    }, directory);
    assert.ok(clicked, `the checklist offers ${directory}`);
  }
}

// AC1. Mutation (Rule 19): drop `compact` from `DatabaseDetails`' `rowActions`, recompile, regenerate
// the mirror, rebuild and redeploy -> the command bar assertion goes red.
test('AC1: Database details defragments, compacts, truncates, dismounts and mounts a probe database, each through its warning dialog, with its running line and its re-read properties', async () => {
  const dir = directoryOf(OPERATED);
  const { context, page } = await signedInAt(browser, config, detailsUrl(dir), VIEWPORTS.wide);
  const posts = recordPosts(page, DETAILS_ACTION_PATH);
  try {
    await page.waitForSelector('.ocu-details-field', { visible: true, timeout: config.navigationTimeoutMs });
    await page.waitForFunction(
      (wanted) => Array.from(document.querySelectorAll('.ocu-command-bar-action')).some((button) => button.textContent.trim() === wanted),
      { timeout: config.navigationTimeoutMs },
      STRINGS.databaseActionDefragment
    );
    assert.deepEqual(await commandBar(page), [
      STRINGS.databaseActionMount,
      STRINGS.databaseActionDismount,
      STRINGS.databaseActionTruncate,
      STRINGS.databaseActionCompact,
      STRINGS.databaseActionDefragment,
    ]);
    await watchStatus(page, DETAILS_STATUS);

    // Defragment: no value.
    assert.deepEqual(await openWarning(page, STRINGS.databaseActionDefragment), {
      title: STRINGS.databaseActionDefragment,
      consequence: STRINGS.databaseDefragmentConsequence,
      advisory: '',
      flag: '',
      field: '',
      hint: '',
      proceedDisabled: false,
    });
    await proceed(page);
    await finishedLine(page, DETAILS_STATUS, STRINGS.databaseActionDefragment);
    assert.deepEqual(posts.at(-1), { action: 'defragment', id: dir });

    // Compact: a target free space, Proceed held until it is a whole number.
    assert.deepEqual(await openWarning(page, STRINGS.databaseActionCompact), {
      title: STRINGS.databaseActionCompact,
      consequence: STRINGS.databaseCompactConsequence,
      advisory: '',
      flag: '',
      field: STRINGS.databaseTargetFreeLabel,
      hint: STRINGS.databaseTargetFreeHint,
      proceedDisabled: true,
    });
    await typeField(page, '0');
    assert.equal((await warningOf(page)).proceedDisabled, false, 'a whole number releases Proceed');
    await proceed(page);
    await finishedLine(page, DETAILS_STATUS, STRINGS.databaseActionCompact);
    assert.deepEqual(posts.at(-1), { action: 'compact', id: dir, values: { TargetFreeSpace: '0' } });

    // Truncate: a target size of 0 returns the unused space, and the page re-reads the new size.
    const sizeBefore = fileAt(dir).size;
    await shownSize(page, sizeBefore);
    assert.deepEqual(await openWarning(page, STRINGS.databaseActionTruncate), {
      title: STRINGS.databaseActionTruncate,
      consequence: STRINGS.databaseTruncateConsequence,
      advisory: '',
      flag: '',
      field: STRINGS.databaseTargetSizeLabel,
      hint: STRINGS.databaseTargetSizeHint,
      proceedDisabled: true,
    });
    await assertStructure(page, DETAILS_ROUTE, true);
    await typeField(page, '0');
    await proceed(page);
    await finishedLine(page, DETAILS_STATUS, STRINGS.databaseActionTruncate);
    assert.deepEqual(posts.at(-1), { action: 'truncate', id: dir, values: { TargetSize: '0' } });
    const sizeAfter = fileAt(dir).size;
    assert.ok(sizeAfter < sizeBefore, `the truncate returned unused space: ${sizeBefore} -> ${sizeAfter} MB`);
    await shownSize(page, sizeAfter);

    // Dismount, then mount read-only, dismount again and mount plain.
    const mountedShown = await fieldText(page, STRINGS.databaseColumnMounted);
    assert.deepEqual(await openWarning(page, STRINGS.databaseActionDismount), {
      title: STRINGS.databaseActionDismount,
      consequence: STRINGS.databaseDismountConsequence,
      advisory: '',
      flag: '',
      field: '',
      hint: '',
      proceedDisabled: false,
    });
    await proceed(page);
    await finishedLine(page, DETAILS_STATUS, STRINGS.databaseActionDismount);
    assert.deepEqual(posts.at(-1), { action: 'dismount', id: dir });
    assert.equal(fileAt(dir).mounted, false, 'the database is dismounted');
    const dismountedShown = await fieldChanges(page, STRINGS.databaseColumnMounted, mountedShown);

    assert.deepEqual(await openWarning(page, STRINGS.databaseActionMount), {
      title: STRINGS.databaseActionMount,
      consequence: STRINGS.databaseMountConsequence,
      advisory: '',
      flag: STRINGS.databaseMountReadOnly,
      field: '',
      hint: '',
      proceedDisabled: false,
    });
    assert.equal(await page.$eval('[role="dialog"] [data-slot="flag"] input', (input) => input.checked), false, 'read-only opens unchecked');
    await page.click('[role="dialog"] [data-slot="flag"] input');
    await proceed(page);
    await finishedLine(page, DETAILS_STATUS, STRINGS.databaseActionMount);
    assert.deepEqual(posts.at(-1), { action: 'mount', id: dir, values: { ReadOnly: 'true' } });
    assert.deepEqual([fileAt(dir).mounted, fileAt(dir).readOnly], [true, true], 'mounted read-only');
    assert.equal(await fieldChanges(page, STRINGS.databaseColumnMounted, dismountedShown), mountedShown);

    await openWarning(page, STRINGS.databaseActionDismount);
    await proceed(page);
    await finishedLine(page, DETAILS_STATUS, STRINGS.databaseActionDismount);
    assert.equal(await fieldChanges(page, STRINGS.databaseColumnMounted, mountedShown), dismountedShown);
    await openWarning(page, STRINGS.databaseActionMount);
    await proceed(page);
    await finishedLine(page, DETAILS_STATUS, STRINGS.databaseActionMount);
    assert.deepEqual(posts.at(-1), { action: 'mount', id: dir, values: { ReadOnly: 'false' } });
    assert.deepEqual([fileAt(dir).mounted, fileAt(dir).readOnly], [true, false], 'mounted read-write');
    assert.equal(await fieldChanges(page, STRINGS.databaseColumnMounted, dismountedShown), mountedShown);
    assert.equal(await page.$('[data-database="refusal"]'), null, 'no operation was refused');
    await assertStructure(page, DETAILS_ROUTE);
  } finally {
    await context.close();
  }
});

// AC5. Mutation (Rule 19): drop the dismount from `IMPACT_ACTIONS`, rebuild and redeploy -> the dialog
// opens with no advisory and this goes red.
test("AC5: Dismount on IRISSYS's directory opens with the prohibited set's refusal as its advisory, and passes DW-1337", async () => {
  const { values, output } = irisSys(
    [`Kill p Set tSC=##class(Config.Databases).Get("IRISSYS",.p)`, mark('DIR', '$Select($System.Status.IsOK(tSC):$Get(p("Directory")),1:"")')],
    ['DIR']
  );
  assert.ok(values.DIR, `IRISSYS's directory was read:\n${output}`);
  const { context, page } = await signedInAt(browser, config, detailsUrl(values.DIR), VIEWPORTS.wide);
  const posts = recordPosts(page, DETAILS_ACTION_PATH);
  try {
    await page.waitForSelector('.ocu-details-field', { visible: true, timeout: config.navigationTimeoutMs });
    await pressBar(page, STRINGS.databaseActionDismount);
    await page.waitForFunction(
      (wanted) => (document.querySelector('[role="dialog"] [data-slot="advisory"] .ocu-banner-message')?.textContent ?? '').trim() === wanted,
      { timeout: config.navigationTimeoutMs },
      STRINGS.databaseRefusalOcuPilot
    );
    const dialog = await warningOf(page);
    assert.deepEqual([dialog.title, dialog.consequence, dialog.proceedDisabled], [STRINGS.databaseActionDismount, STRINGS.databaseDismountConsequence, false]);
    await assertStructure(page, DETAILS_ROUTE, true);
    await dismiss(page);
    assert.deepEqual(posts, [], 'the leg sends nothing');
    assert.equal(fileAt(values.DIR).mounted, true, 'IRISSYS is still mounted');
  } finally {
    await context.close();
  }
});

// AC3. Mutation (Rule 19): send the unchanged file group beside a changed size in the editor store's
// `saveBody`, rebuild and redeploy -> the sent-body assertion goes red.
test('AC3: the editor grows Size on Save, holds Add a volume while the form is dirty, then adds a volume the volume files list', async () => {
  const dir = directoryOf(GROWN);
  const { context, page } = await signedInAt(browser, config, EDIT_URL, VIEWPORTS.wide);
  const puts = [];
  page.on('request', (request) => {
    if (request.method() === 'PUT' && new URL(request.url()).pathname === `${CREATE_PATH}/${encodeEntityId(GROWN)}`) puts.push(JSON.parse(request.postData() ?? '{}'));
  });
  const posts = recordPosts(page, LOCAL_ACTION_PATH);
  try {
    await page.waitForSelector('#ocu-database-edit-Size', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('#ocu-database-edit-Size', (input) => input.value), '1');
    await page.waitForFunction(() => document.querySelectorAll('[data-group="volumes"] tbody tr').length === 1, { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-action="add-volume"]', (button) => button.getAttribute('aria-disabled')), null, 'Add a volume is offered on a clean form');

    // A dirty form holds Add a volume, and says why.
    await retype(page, '#ocu-database-edit-Size', '3');
    await page.waitForFunction(() => document.querySelector('[data-action="add-volume"]')?.getAttribute('aria-disabled') === 'true', {
      timeout: config.navigationTimeoutMs,
    });
    const held = await page.$eval('[data-action="add-volume"]', (button) => ({
      disabled: button.getAttribute('aria-disabled'),
      reason: document.getElementById(button.getAttribute('aria-describedby') ?? '')?.textContent.trim() ?? '',
    }));
    assert.deepEqual(held, { disabled: 'true', reason: STRINGS.databaseExpandDirty });
    await page.click('[data-action="add-volume"]');
    await frames(page);
    assert.equal(await page.$('[role="dialog"]'), null, 'a held Add a volume opens nothing');

    // The Save sends the size group alone, and the size reads back.
    await saveAndSettle(page, config);
    assert.deepEqual(puts, [{ size: { Size: 3 } }], 'one Save, carrying only the size');
    assert.equal(fileAt(dir).size, 3, 'the file grew to 3 MB');
    await page.waitForFunction(() => document.querySelector('[data-action="add-volume"]')?.getAttribute('aria-disabled') === null, {
      timeout: config.navigationTimeoutMs,
    });
    assert.equal(await page.$eval('#ocu-database-edit-Size', (input) => input.value), '3');
    await assertStructure(page, FORM_ROUTE);

    // Add a volume: its warning asks for the initial size.
    await watchStatus(page, VOLUME_STATUS);
    await page.click('[data-action="add-volume"]');
    await page.waitForSelector('[role="dialog"] .ocu-warning-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    assert.deepEqual(await warningOf(page), {
      title: STRINGS.databaseExpandAction,
      consequence: STRINGS.databaseExpandConsequence,
      advisory: '',
      flag: '',
      field: STRINGS.databaseInitialSize,
      hint: STRINGS.databaseInitialSizeHint,
      proceedDisabled: true,
    });
    await assertStructure(page, FORM_ROUTE, true);
    await typeField(page, '1');
    await proceed(page);
    await finishedLine(page, VOLUME_STATUS, STRINGS.databaseExpandAction);
    assert.deepEqual(posts, [{ action: 'expand', id: GROWN, values: { InitialSize: '1' } }]);
    assert.ok(fileExists(`${dir}${FIRST_VOLUME}`), 'the volume file was created in the database directory');
    await page.waitForFunction(
      (name) => Array.from(document.querySelectorAll('[data-group="volumes"] tbody tr')).some((row) => row.textContent.includes(name)),
      { timeout: config.navigationTimeoutMs },
      FIRST_VOLUME
    );
    assert.equal(await page.$$eval('[data-group="volumes"] tbody tr', (rows) => rows.length), 2, 'the volume files list both files');
    assert.equal(await page.$('[data-volume="refusal"]'), null, 'nothing was refused');
  } finally {
    await context.close();
  }
});

// AC6. Mutation (Rule 19): send the checked directories in the order they were checked rather than
// canonical, rebuild and redeploy -> the two-database body assertion goes red.
test('AC6: Databases opens the Check integrity flow; one database with a global, then two as their canonical set, each show the finished report', async () => {
  const checked = directoryOf(CHECKED);
  const grown = directoryOf(GROWN);
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const posts = recordPosts(page, LIST_ACTION_PATH);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const primary = await page.waitForSelector('.ocu-command-bar button.ocu-button-primary', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await primary.evaluate((button) => button.textContent.trim()), STRINGS.databaseIntegrityLabel);
    await primary.click();
    await page.waitForFunction((route) => new URL(window.location.href).pathname.endsWith(`/${route}`), { timeout: config.navigationTimeoutMs }, FLOW_ROUTE);
    await page.waitForSelector('[data-integrity="databases"] label[data-directory]', { visible: true, timeout: config.navigationTimeoutMs });
    await assertStructure(page, FLOW_ROUTE);

    await checkDatabases(page, [checked]);
    await nextTo(page, STRINGS.processColumnGlobals);
    assert.equal(await page.$eval('[data-integrity="globals"] textarea', (field) => field.getAttribute('aria-disabled')), null, 'globals are offered for one database');
    await page.type('[data-integrity="globals"] textarea', GLOBAL);
    await nextTo(page, STRINGS.databaseIntegrityStepReport);
    assert.equal(await page.$eval('.ocu-form-bar-actions .ocu-button-primary', (button) => button.textContent.trim()), STRINGS.databaseIntegrityLabel);
    await assertStructure(page, FLOW_ROUTE);
    await watchStatus(page, FLOW_STATUS);
    await page.click('.ocu-form-bar-actions .ocu-button-primary');
    await finishedLine(page, FLOW_STATUS, STRINGS.databaseIntegrityLabel);
    assert.deepEqual(posts, [{ action: 'integrity', id: checked, values: { Globals: JSON.stringify([GLOBAL]) } }]);
    await page.waitForSelector('[data-integrity="report-lines"]', { visible: true, timeout: config.navigationTimeoutMs });
    const one = await page.$eval('[data-integrity="report-lines"]', (node) => node.textContent);
    assert.ok(one.startsWith('No Errors were found.'), `the report is the finished check's: ${one}`);
    assert.ok(one.includes(`Directory: ${checked}`) && !one.includes(`Directory: ${grown}`), `of the one database checked: ${one}`);
    assert.equal(await page.$eval('[data-integrity="open-log"]', (button) => button.textContent.trim()), STRINGS.databaseIntegrityOpenLog);
  } finally {
    await context.close();
  }

  const second = await signedInAt(browser, config, FLOW_URL, VIEWPORTS.wide);
  const twoPosts = recordPosts(second.page, LIST_ACTION_PATH);
  try {
    await checkDatabases(second.page, [grown, checked]);
    await nextTo(second.page, STRINGS.processColumnGlobals);
    const globals = await second.page.$eval('[data-integrity="globals"]', (group) => ({
      disabled: group.querySelector('textarea').getAttribute('aria-disabled'),
      caption: group.querySelector('.ocu-field-caption')?.textContent.trim() ?? '',
    }));
    assert.deepEqual(globals, { disabled: 'true', caption: STRINGS.databaseGlobalsOneDatabase });
    await nextTo(second.page, STRINGS.databaseIntegrityStepReport);
    await watchStatus(second.page, FLOW_STATUS);
    await second.page.click('.ocu-form-bar-actions .ocu-button-primary');
    await finishedLine(second.page, FLOW_STATUS, STRINGS.databaseIntegrityLabel);
    assert.deepEqual(twoPosts, [{ action: 'integrity', id: JSON.stringify([checked, grown]), values: { Globals: '[]' } }], 'the set is sent sorted');
    await second.page.waitForSelector('[data-integrity="report-lines"]', { visible: true, timeout: config.navigationTimeoutMs });
    const two = await second.page.$eval('[data-integrity="report-lines"]', (node) => node.textContent);
    assert.ok(two.includes(`Directory: ${checked}`) && two.includes(`Directory: ${grown}`), `the report covers both: ${two}`);
  } finally {
    await second.context.close();
  }
});

// AC7. Mutation (Rule 19): make `LogSourcePort` answer the oldest check first, recompile -> the options
// read oldest first and this goes red.
test('AC7: the Integrity log lists the two checks newest first and shows the selected check\u2019s report, and passes DW-1337', async () => {
  const checked = directoryOf(CHECKED);
  const grown = directoryOf(GROWN);
  const { context, page } = await signedInAt(browser, config, LOG_URL, VIEWPORTS.wide);
  try {
    await page.waitForSelector('[data-ocu-log="file"] option', { timeout: config.navigationTimeoutMs });
    await page.waitForSelector('.ocu-log-row', { visible: true, timeout: config.navigationTimeoutMs });
    const options = await page.$$eval('[data-ocu-log="file"] option', (list) => list.map((option) => ({ value: option.value, text: option.textContent.trim(), selected: option.selected })));
    assert.equal(options.length, 2, `the two checks this spec ran: ${JSON.stringify(options)}`);
    assert.ok(Number(options[0].value) > Number(options[1].value), `newest first: ${JSON.stringify(options)}`);
    for (const option of options) assert.match(option.text, /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} \u00b7 Done$/);
    assert.equal(options[0].selected, true, 'the newest is shown');
    const rowsOf = () => page.$$eval('.ocu-log-row .ocu-log-cell-text', (cells) => cells.map((cell) => cell.textContent.trim()));
    const newest = await rowsOf();
    assert.equal(newest[0], 'No Errors were found.');
    assert.ok(newest.includes(`Directory: ${checked}`) && newest.includes(`Directory: ${grown}`), `the two-database check: ${JSON.stringify(newest)}`);
    await assertStructure(page, LOG_ROUTE);

    await page.select('[data-ocu-log="file"]', options[1].value);
    await page.waitForFunction(
      (wanted) => {
        const texts = Array.from(document.querySelectorAll('.ocu-log-row .ocu-log-cell-text')).map((cell) => cell.textContent.trim());
        return texts.length > 0 && !texts.includes(wanted);
      },
      { timeout: config.navigationTimeoutMs },
      `Directory: ${grown}`
    );
    const older = await rowsOf();
    assert.ok(older.includes(`Directory: ${checked}`), `the one-database check: ${JSON.stringify(older)}`);
  } finally {
    await context.close();
  }
});

test('AC10: an admin API compact, paused, is listed on Database details for its directory and once on Background tasks', async () => {
  const operated = directoryOf(OPERATED);
  const seeded = iris(
    'HSCUSTOM',
    [`Set sc=##class(${PROBE}).PausedAdminCompact("${OPERATED}",.g,.t,200)`, mark('PAUSED', '$Select($System.Status.IsOK(sc):"ok",1:$System.Status.GetErrorText(sc))'), mark('GUID', 'g')],
    ['PAUSED', 'GUID']
  );
  try {
    assert.equal(seeded.values.PAUSED, 'ok', `a compact was started through DatabasePort and paused:\n${seeded.output}`);
    const details = await signedInAt(browser, config, detailsUrl(operated), VIEWPORTS.wide);
    try {
      await details.page.waitForSelector('.ocu-details-tasks-table tbody tr', { visible: true, timeout: config.navigationTimeoutMs });
      const rows = await details.page.$$eval('.ocu-details-tasks-table tbody tr', (list) => list.map((row) => Array.from(row.querySelectorAll('td')).map((cell) => cell.textContent.trim())));
      assert.equal(rows.length, 1, `Database details lists the one task running against its directory: ${JSON.stringify(rows)}`);
      assert.ok(rows[0].some((cell) => cell.toLowerCase() === 'paused'), `the paused compact: ${JSON.stringify(rows)}`);
    } finally {
      await details.context.close();
    }
    const list = await signedInAt(browser, config, '/ocupilot/tasks/background?ns=HSCUSTOM', VIEWPORTS.wide);
    try {
      await waitForRows(list.page, config.navigationTimeoutMs);
      const rows = await list.page.evaluate(
        (rowSelector) => Array.from(document.querySelectorAll(rowSelector)).map((row) => Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim())),
        ROW_SELECTOR
      );
      const listed = rows.filter((cells) => cells.includes('Database') && cells.some((cell) => cell.toLowerCase() === 'paused'));
      assert.equal(listed.length, 1, `Background tasks lists it once: ${JSON.stringify(rows)}`);
    } finally {
      await list.context.close();
    }
  } finally {
    // Ended through its own admin API row, as its owner, so its async task is read once and removed:
    // ending it through %SYS.BackgroundTask alone leaves that row Running.
    const guid = seeded.values.GUID ?? '';
    const cancel =
      guid === ''
        ? []
        : [
            `Kill q Set q("id")=##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("Admin API","${guid}")) Set sc=##class(OcuPilot.Port.BackgroundTaskPort).Invoke("BackgroundTask","CANCEL",.q,"",.r,.h,.f)`,
            `Set st=##class(OcuPilot.Test.DatabaseQueuedPort).Settle("${guid}")`,
          ];
    const removed = iris(
      'HSCUSTOM',
      [...cancel, `Set sc=##class(${PROBE}).RemoveTasks()`, mark('TASKS', '$Select($System.Status.IsOK(sc):"ok",1:$System.Status.GetErrorText(sc))'), mark('OWN', `##class(${PROBE}).OwnTaskCount()`)],
      ['TASKS', 'OWN']
    );
    assert.equal(removed.values.TASKS, 'ok', `the compact was ended and removed:\n${removed.output}`);
    assert.equal(removed.values.OWN, '0', `and no async task of it survives:\n${removed.output}`);
  }
});

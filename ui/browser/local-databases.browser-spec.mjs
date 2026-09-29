/**
 * Local databases, the create wizard, the properties editor and the delete in a real browser,
 * against the throwaway instance (Story 18.3).
 *
 * What it pins, each on rendered DOM, on the request the page sent, or on the instance itself:
 *
 * 1. **The list and the wizard** (AC1): OS management's ninth side-bar entry reads "Local
 *    databases"; the wizard refuses an empty subdirectory of the manager directory with
 *    `PATH.MANAGERDIR`, drawn under the picker's field before any vendor call (DW-1807's field
 *    mapping), then creates a probe database that reads mounted, journaled and guarded by its own
 *    `%DB_<NAME>`, and replaces the route with its editor.
 * 2. **The editor** (AC2): an expansion size, mount at startup, the new volume threshold and a new
 *    volume directory chosen through the picker round-trip in one Save that sends only the changed
 *    groups, and the volume files section lists the database's own file.
 * 3. **The delete** (AC3): the advisory names the probe namespace and the probe web application that
 *    use the database; the confirmed delete is refused `DATABASE.INUSE` with nothing removed; once
 *    they are gone, Delete with "Also delete the database file" checked sends `DeleteFile` as a value
 *    and leaves no configuration and no `IRIS.DAT`.
 * 4. **IRISSYS** (AC4): its Delete dialog states the kernel's refusal when it opens; the leg only
 *    opens and cancels it.
 * 5. **Background tasks** (AC8, DW-1080): Database details for the directory of a paused compact
 *    seeded through `OcuPilot.Test.BackgroundSeed` lists it with its status and start time, and
 *    passes the structural walk; a database with none says so.
 * 6. **DW-1337** (AC7): the list, the wizard's first and last steps, the editor and the Delete dialog
 *    pass the structural walk at wide light, narrow light and wide dark.
 *
 * **It refuses the live and development containers.** It seeds `OCUPROBE183BE` and `OCUPROBE183BD`
 * through OcuPilot's own create route, a probe namespace and a probe web application over the second
 * in `%SYS` (test-only), creates `OCUPROBE183BW` through the wizard, and removes every one of them --
 * configuration, file, directory and `%DB_*` resource -- by exact name before and after, including on
 * failure, asserting none survives. The AC8 leg seeds `BackgroundSeed`'s paused compact over
 * `docker exec -e OCUPILOT_ALLOW_PRINCIPALS=1` and removes it with that class's `Remove()`, in the
 * leg's own `finally` and again in `after` when the leg ran.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1
 * browser/local-databases.browser-spec.mjs`.
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
import { authHeader, saveAndSettle, signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const repoRoot = join(uiRoot, '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));
const { encodeEntityId } = await import(join(uiRoot, 'src', 'app', 'core', 'entity-id.ts'));

const config = browserConfig();

/** A published server sentence, read from its class rather than restated here. */
function serverSentence(file, parameter) {
  const source = readFileSync(join(repoRoot, 'src', 'OcuPilot', ...file.split('/')), 'utf8');
  const found = new RegExp(`Parameter ${parameter} = "([^"]+)";`).exec(source);
  assert.notEqual(found, null, `${file} declares ${parameter}`);
  return found[1];
}

const MANAGERDIR_REASON = serverSentence('Api/Error.cls', 'REASONPATHMANAGERDIR');
const INUSE_REASON = serverSentence('Api/DatabaseError.cls', 'REASONINUSE');

/** The database the wizard leg creates, the one the editor leg edits, and the one the delete leg removes. */
const WIZARD = 'OCUPROBE183BW';
const EDITED = 'OCUPROBE183BE';
const DELETED = 'OCUPROBE183BD';
const DATABASES = [WIZARD, EDITED, DELETED];

/** The probe namespace and web application that use `DELETED`, seeded in `%SYS` (test-only). */
const NAMESPACE = 'OCUPROBE183NS';
const APP = '/csp/ocuprobe183';
const MARKER = 'OcuPilot local databases browser spec probe (throwaway)';

/** The new volume directory the editor leg names, under the manager directory. */
const VOLUME_PATH = 'ocuprobe183be-vol';

/** A name the DW-1337 leg types into the wizard and never creates. */
const NEVER = 'OCUPROBE183BX';

const LIST_ROUTE = 'os-management/local-databases';
const FORM_ROUTE = 'os-management/local-databases/edit';
const LIST_URL = `/ocupilot/${LIST_ROUTE}?ns=HSCUSTOM`;
const WIZARD_URL = `/ocupilot/${FORM_ROUTE}?ns=HSCUSTOM`;
const EDIT_URL = `/ocupilot/${FORM_ROUTE}/${encodeEntityId(EDITED)}?ns=HSCUSTOM`;
const CREATE_PATH = '/api/ocupilot/database';
const ACTION_PATH = '/api/ocupilot/screens/osmgmt.localdatabases/action';

/** Database details, by the directory it opens for. */
const DETAILS_ROUTE = 'os-management/databases/details';
const detailsUrl = (directory) => `/ocupilot/${DETAILS_ROUTE}/${encodeEntityId(directory)}?ns=HSCUSTOM`;

/** The class that seeds and removes a paused portal compact (test-only, armed by `OCUPILOT_ALLOW_PRINCIPALS`). */
const SEED = 'OcuPilot.Test.BackgroundSeed';

/** Whether the AC8 leg seeded, so `after` removes the seed again whatever the leg answered. */
let seededCompact = false;

/** The row cells' own text selector, a name cell being a link. */
const NAME_TEXT = '.ocu-data-table-link, .ocu-data-table-text';

let browser = null;

/** The instance's manager directory, read in `before`. */
let managerDirectory = '';

const mark = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/** Run `lines` in `%SYS` inside the throwaway and return the value each named marker carries. */
function irisSys(lines, names = []) {
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', '%SYS'], {
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

/**
 * Run `lines` in `HSCUSTOM` inside the throwaway with `OCUPILOT_ALLOW_PRINCIPALS=1`, which arms
 * `BackgroundSeed`, and return the value the one marker `name` carries.
 */
function seedIris(lines, name) {
  const result = spawnSync(
    'docker',
    ['exec', '-i', '-e', 'OCUPILOT_ALLOW_PRINCIPALS=1', config.container, 'iris', 'session', 'iris', '-U', 'HSCUSTOM'],
    { input: `${[...lines, 'Halt'].join('\n')}\n`, encoding: 'utf8', timeout: 600000 }
  );
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const found = new RegExp(`OCU-${name}-START:(.*?):OCU-${name}-END`).exec(output);
  return { value: found === null ? null : found[1].trim(), output };
}

/** Remove `BackgroundSeed`'s database and every task over it, asserting the removal answered OK. */
function removeCompactSeed() {
  const removed = seedIris(
    [`Set sc=##class(${SEED}).Remove()`, mark('BGREMOVE', '$Select($System.Status.IsOK(sc):"ok",1:$System.Status.GetErrorText(sc))')],
    'BGREMOVE'
  );
  assert.equal(removed.value, 'ok', `the seeded compact and its database are removed:\n${removed.output}`);
}

/** A probe database's directory, as the create composes it under the manager directory. */
const directoryOf = (name) => `${managerDirectory}${name.toLowerCase()}/`;

/** Every probe directory, the editor leg's new volume directory among them. */
const probeDirectories = () => [...DATABASES.map(directoryOf), `${managerDirectory}${VOLUME_PATH}/`];

/**
 * Remove every probe object by its exact name: the application, the namespace, each configuration,
 * each file (dismounted first) and its directory tree, and each `%DB_*` resource. Test-only `%SYS`.
 */
function cleanupLines() {
  return [
    `If ##class(Security.Applications).Exists("${APP}") Do ##class(Security.Applications).Delete("${APP}")`,
    `If ##class(Config.Namespaces).Exists("${NAMESPACE}") Do ##class(Config.Namespaces).Delete("${NAMESPACE}")`,
    ...DATABASES.map((name) => `If ##class(Config.Databases).Exists("${name}") Do ##class(Config.Databases).Delete("${name}")`),
    ...probeDirectories().map(
      (dir) => `If ##class(SYS.Database).%ExistsId("${dir}") Do ##class(SYS.Database).DismountDatabase("${dir}"),##class(SYS.Database).DeleteDatabase("${dir}")`
    ),
    ...probeDirectories().map((dir) => `If ##class(%File).DirectoryExists("${dir}") Do ##class(%File).RemoveDirectoryTree("${dir}")`),
    ...DATABASES.map((name) => `If ##class(Security.Resources).Exists("%DB_${name}") Do ##class(Security.Resources).Delete("%DB_${name}")`),
  ];
}

/** Whether no probe object survives. */
function noneSurvives() {
  return [
    `('##class(Security.Applications).Exists("${APP}"))`,
    `('##class(Config.Namespaces).Exists("${NAMESPACE}"))`,
    ...DATABASES.map((name) => `('##class(Config.Databases).Exists("${name}"))`),
    ...DATABASES.map((name) => `('##class(Security.Resources).Exists("%DB_${name}"))`),
    ...probeDirectories().map((dir) => `('##class(%File).DirectoryExists("${dir}"))`),
  ].join('&&');
}

/** The instance's configuration of database `name` -- `{Directory, MountAtStartup}` -- or `null`. */
function configured(name) {
  const { values, output } = irisSys(
    [
      `Kill p Set tSC=##class(Config.Databases).Get("${name}",.p)`,
      mark('DB', '$Select($System.Status.IsOK(tSC):$Get(p("Directory"))_"|"_(+$Get(p("MountAtStartup"))),1:"<absent>")'),
    ],
    ['DB']
  );
  assert.notEqual(values.DB, null, `the configuration read answered:\n${output}`);
  if (values.DB === '<absent>') return null;
  const [Directory, MountAtStartup] = values.DB.split('|');
  return { Directory, MountAtStartup: MountAtStartup === '1' };
}

/** The file at `dir` as `SYS.Database` holds it, or `null` when no `IRIS.DAT` is there. */
function fileAt(dir) {
  const { values, output } = irisSys(
    [
      `Set tDb=##class(SYS.Database).%OpenId("${dir}")`,
      mark(
        'FILE',
        '$Select($IsObject(tDb):tDb.Mounted_"|"_tDb.ResourceName_"|"_tDb.ExpansionSize_"|"_tDb.NewVolumeThreshold_"|"_tDb.NewVolumeDirectory,1:"<absent>")'
      ),
      mark('DAT', `##class(%File).Exists("${dir}IRIS.DAT")`),
    ],
    ['FILE', 'DAT']
  );
  assert.notEqual(values.FILE, null, `the file read answered:\n${output}`);
  if (values.FILE === '<absent>' || values.DAT !== '1') return null;
  const [Mounted, ResourceName, ExpansionSize, NewVolumeThreshold, NewVolumeDirectory] = values.FILE.split('|');
  return { Mounted: Mounted === '1', ResourceName, ExpansionSize: Number(ExpansionSize), NewVolumeThreshold: Number(NewVolumeThreshold), NewVolumeDirectory };
}

/** Whether `%DB_<name>` exists. */
function resourceExists(name) {
  return irisSys([mark('RES', `##class(Security.Resources).Exists("%DB_${name}")`)], ['RES']).values.RES === '1';
}

/** OcuPilot's own form read of database `name`, as the editor reads it. */
async function formRead(name) {
  const response = await fetch(`${config.origin}${CREATE_PATH}/form?name=${encodeURIComponent(name)}`, { headers: { Authorization: authHeader(config) } });
  assert.equal(response.status, 200, `the form read of ${name} answered`);
  return response.json();
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

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates and deletes databases, namespaces and web applications, so it never runs inside the live container');
  assert.ok(!/^ocupilot-slot-/.test(config.container), 'nor inside a development instance');
  await assertThrowaway(config);
  const { values, output } = irisSys([mark('MGR', '$System.Util.ManagerDirectory()')], ['MGR']);
  assert.ok(values.MGR, `the manager directory was read:\n${output}`);
  managerDirectory = values.MGR;
  const cleaned = irisSys([...cleanupLines(), mark('CLEAN', noneSurvives())], ['CLEAN']);
  assert.equal(cleaned.values.CLEAN, '1', `no probe object is left from an earlier run:\n${cleaned.output}`);
  await seed(EDITED);
  await seed(DELETED);
  const seeded = irisSys(
    [
      `Kill p Set p("Globals")="${DELETED}",p("Routines")="${DELETED}"`,
      `Set tSC=##class(Config.Namespaces).Create("${NAMESPACE}",.p)`,
      `If $System.Status.IsOK(tSC) Kill a Set a("NameSpace")="${NAMESPACE}",a("Enabled")=1,a("AutheEnabled")=32,a("Description")="${MARKER}",tSC=##class(Security.Applications).Create("${APP}",.a)`,
      mark('MADE', '$System.Status.IsOK(tSC)'),
    ],
    ['MADE']
  );
  assert.equal(seeded.values.MADE, '1', `the probe namespace and its application were made:\n${seeded.output}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    if (config.container !== LIVE_CONTAINER && managerDirectory !== '') {
      try {
        if (seededCompact) removeCompactSeed();
      } finally {
        const { values, output } = irisSys([...cleanupLines(), mark('CLEAN', noneSurvives())], ['CLEAN']);
        assert.equal(values.CLEAN, '1', `no probe database, namespace, application, directory or resource survives:\n${output}`);
      }
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

/** The rendered row whose name cell reads `name`, as its first three cells' text, or `null`. */
function rowCells(page, name) {
  return page.evaluate(
    (selector, wanted, textSelector) => {
      const row = Array.from(document.querySelectorAll(selector)).find((candidate) => {
        const cell = candidate.querySelector('[role="gridcell"]');
        const text = cell?.querySelector(textSelector);
        return ((text ?? cell)?.textContent ?? '').trim() === wanted;
      });
      if (row === undefined) return null;
      return Array.from(row.querySelectorAll('[role="gridcell"]'))
        .slice(0, 3)
        .map((cell) => cell.textContent.trim());
    },
    ROW_SELECTOR,
    name,
    NAME_TEXT
  );
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

/** Open the Delete dialog on `name`'s row and answer its title, consequence, advisory and flag once they render. */
async function openDelete(page, name, expectedAdvisory) {
  await openRowMenu(page, name);
  await page.evaluate((label) => {
    Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'))
      .find((item) => item.textContent.trim().startsWith(label))
      .click();
  }, STRINGS.actionDelete);
  await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
  await page.waitForFunction(
    (wanted) => (document.querySelector('[role="dialog"] [data-slot="advisory"] .ocu-banner-message')?.textContent ?? '').trim() === wanted,
    { timeout: config.navigationTimeoutMs },
    expectedAdvisory
  );
  return page.evaluate(() => ({
    title: document.querySelector('[role="dialog"] .ocu-dialog-title').textContent.trim(),
    consequence: document.querySelector('.ocu-typed-name-consequence').textContent.trim(),
    advisory: (document.querySelector('[role="dialog"] [data-slot="advisory"] .ocu-banner-message')?.textContent ?? '').trim(),
    flag: (document.querySelector('[role="dialog"] [data-slot="flag"]')?.textContent ?? '').trim(),
    flagChecked: document.querySelector('[role="dialog"] [data-slot="flag"] input[type="checkbox"]')?.checked ?? null,
  }));
}

/** Escape the open dialog and wait for it to close. */
async function dismiss(page) {
  await page.keyboard.press('Escape');
  await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
}

/** Type the database's name into the open dialog, set its file option and confirm, then wait for the dialog to close. */
async function confirmDelete(page, name, deleteFile) {
  if (deleteFile) await page.click('[role="dialog"] [data-slot="flag"] input[type="checkbox"]');
  await page.type('.ocu-typed-name-field', name);
  await page.keyboard.press('Enter');
  await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: 90000 });
}

/** Up to three names joined by ", ", then " and <n> more", as the impact line lists them. */
function namesOf(names) {
  const shown = names.slice(0, 3).join(', ');
  const rest = names.length - 3;
  return rest > 0 ? `${shown}${STRINGS.readBackMore.replace('<n>', () => String(rest))}` : shown;
}

/** The advisory a database delete states for the namespaces and applications that use it. */
function impactLine(namespaces, apps) {
  const counted = (list, many, one, none) =>
    list.length === 0 ? none : (list.length === 1 ? one : many.replace('<n>', () => String(list.length))).replace('<names>', () => namesOf(list));
  const parts = [counted(namespaces, STRINGS.impactNamespacesUse, STRINGS.impactNamespacesUseOne, STRINGS.impactNamespacesUseNone)];
  if (namespaces.length > 0) parts.push(counted(apps, STRINGS.impactApplicationsInThem, STRINGS.impactApplicationsInThemOne, ''));
  return STRINGS.impactLine.replace('<parts>', () => parts.filter((phrase) => phrase !== '').join('; '));
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

/** Choose the manager directory on the picker whose ids begin `prefix`, where it offers more than one root. */
async function chooseManagerRoot(page, prefix) {
  const select = `#${prefix}-root`;
  await page.waitForSelector(select, { visible: true, timeout: config.navigationTimeoutMs });
  const roots = await page.$$eval(`${select} option`, (options) => options.map((option) => option.value));
  assert.ok(roots.includes(managerDirectory), `the picker offers the manager directory: ${JSON.stringify(roots)}`);
  if (roots.length > 1) await page.select(select, managerDirectory);
}

/** Replace the text of input `selector` with `value`. */
async function retype(page, selector, value) {
  await page.click(selector, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  if (value !== '') await page.type(selector, value);
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

// AC1. Mutation (Rule 19): make the wizard store drop `path` violations, rebuild and redeploy -> the
// PATH.MANAGERDIR reason never renders under the picker and this goes red.
test('AC1: Local databases is the ninth OS management entry; the wizard refuses the manager directory itself on the picker, then creates a mounted, journaled database guarded by its own resource', async () => {
  const user = configured('USER');
  assert.ok(user !== null, 'the instance configures USER');
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const writes = [];
  page.on('request', (request) => {
    const path = new URL(request.url()).pathname;
    if (request.method() !== 'GET' && path === CREATE_PATH) writes.push(request.postData() ?? '');
  });
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const bar = await sideBarOf(page);
    assert.equal(bar.area, STRINGS.navAreaOsManagement);
    assert.deepEqual(bar.entries.slice(0, 9), [
      STRINGS.processListLabel,
      STRINGS.lockListLabel,
      STRINGS.systemUsageLabel,
      STRINGS.databaseListLabel,
      STRINGS.deviceListLabel,
      STRINGS.namespaceListLabel,
      STRINGS.licenseUsageLabel,
      STRINGS.dashboardLabel,
      STRINGS.localDatabaseListLabel,
    ]);
    const headers = await page.$$eval('.ocu-data-table-header-label', (labels) => labels.map((label) => label.textContent.trim()));
    assert.deepEqual(headers.slice(0, 3), [STRINGS.tableColumnName, STRINGS.lockColumnDirectory, STRINGS.taskHistoryColumnStatus]);
    const userRow = await rowCells(page, 'USER');
    assert.ok(userRow !== null && userRow[1] === user.Directory && userRow[2] !== '', `USER's row shows its directory and a status: ${JSON.stringify(userRow)}`);

    // The wizard, from the list's Create.
    await (await page.waitForSelector('.ocu-command-bar button.ocu-button-primary', { visible: true, timeout: config.navigationTimeoutMs })).click();
    await page.waitForFunction((route) => new URL(window.location.href).pathname.endsWith(`/${route}`), { timeout: config.navigationTimeoutMs }, FORM_ROUTE);
    await page.waitForSelector('#ocu-database-Name', { visible: true, timeout: config.navigationTimeoutMs });
    await page.type('#ocu-database-Name', WIZARD);
    await page.waitForFunction((wanted) => document.querySelector('#ocu-database-location-path')?.value === wanted, { timeout: config.navigationTimeoutMs }, WIZARD.toLowerCase());
    await chooseManagerRoot(page, 'ocu-database-location');

    // PATH.MANAGERDIR: an empty subdirectory is the manager directory itself, refused on the picker's field.
    await retype(page, '#ocu-database-location-path', '');
    await page.click('.ocu-form-bar-actions .ocu-button-primary');
    await page.waitForFunction(
      (wanted) => document.querySelector('#ocu-database-location-path-reason')?.textContent.trim() === wanted,
      { timeout: config.navigationTimeoutMs },
      MANAGERDIR_REASON
    );
    assert.equal(await page.$eval('#ocu-database-location-path', (input) => input.getAttribute('aria-invalid')), 'true');
    assert.equal(configured(WIZARD), null, 'nothing was created');

    // The create: the name's own directory, the default size, journal and resource.
    await retype(page, '#ocu-database-location-path', WIZARD.toLowerCase());
    await nextTo(page, STRINGS.databaseWizardStepSize);
    await nextTo(page, STRINGS.webAppColumnResource);
    assert.equal(
      await page.$eval('#ocu-database-resource-new', (input) => input.closest('label').textContent.trim()),
      STRINGS.databaseResourceNew.replace('<name>', `%DB_${WIZARD}`)
    );
    await page.click('.ocu-form-bar-actions .ocu-button-primary');
    await page.waitForFunction((suffix) => new URL(window.location.href).pathname.endsWith(suffix), { timeout: 90000 }, `/${FORM_ROUTE}/${encodeEntityId(WIZARD)}`);
    assert.deepEqual(
      writes.map((body) => JSON.parse(body)),
      [{ Name: WIZARD, root: managerDirectory, path: WIZARD.toLowerCase(), Size: 1, GlobalJournalState: true }],
      'one create, sent with no resource name'
    );
    const held = configured(WIZARD);
    assert.equal(held?.Directory, directoryOf(WIZARD), 'the configuration names the directory under the manager directory');
    const file = fileAt(directoryOf(WIZARD));
    assert.ok(file !== null && file.Mounted, 'the file exists and is mounted');
    assert.equal(file.ResourceName, `%DB_${WIZARD}`, 'guarded by its own resource');
    assert.equal(resourceExists(WIZARD), true, 'which exists');
    assert.equal((await formRead(WIZARD)).file.GlobalJournalState, true, 'and journaled');

    // The editor it landed on names it; the list shows it.
    await page.waitForFunction((wanted) => document.querySelector('#ocu-database-edit-Name')?.value === wanted, { timeout: config.navigationTimeoutMs }, WIZARD);
    await page.click('.ocu-form-bar-actions .ocu-button-text');
    await page.waitForFunction((route) => new URL(window.location.href).pathname.endsWith(`/${route}`), { timeout: config.navigationTimeoutMs }, LIST_ROUTE);
    await waitForRows(page, config.navigationTimeoutMs);
    await page.waitForFunction(
      (selector, wanted) => Array.from(document.querySelectorAll(selector)).some((row) => row.textContent.includes(wanted)),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      WIZARD
    );
  } finally {
    await context.close();
  }
});

// AC2. Mutation (Rule 19): send every field in the editor store's `changedFile`, rebuild and redeploy
// -> the sent-body assertion goes red.
test('AC2: the editor round-trips an expansion size, mount at startup, the new volume threshold and a new volume directory, and lists the volume files', async () => {
  const before = configured(EDITED);
  assert.ok(before !== null, 'the edited database is seeded');
  const { context, page } = await signedInAt(browser, config, EDIT_URL, VIEWPORTS.wide);
  const puts = [];
  page.on('request', (request) => {
    if (request.method() === 'PUT' && new URL(request.url()).pathname === `${CREATE_PATH}/${encodeEntityId(EDITED)}`) puts.push(request.postData() ?? '');
  });
  try {
    await page.waitForSelector('#ocu-database-edit-ExpansionSize', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('#ocu-database-edit-Name', (input) => input.readOnly), true, 'the name is read-only');
    assert.equal(await page.$eval('#ocu-database-edit-Directory', (input) => input.value), directoryOf(EDITED));
    await page.waitForFunction(() => document.querySelectorAll('[data-group="volumes"] tbody tr').length > 0, { timeout: config.navigationTimeoutMs });
    const files = await page.$$eval('[data-group="volumes"] tbody tr', (rows) => rows.map((row) => row.textContent));
    assert.ok(files.some((text) => text.includes('IRIS.DAT')), `the volume files list the database's own file: ${JSON.stringify(files)}`);

    await retype(page, '#ocu-database-edit-ExpansionSize', '2');
    await page.click('#ocu-database-edit-MountAtStartup');
    await retype(page, '#ocu-database-edit-NewVolumeThreshold', '100');
    await page.click('[data-action="change-volume-directory"]');
    await chooseManagerRoot(page, 'ocu-database-volume');
    await retype(page, '#ocu-database-volume-path', VOLUME_PATH);
    await saveAndSettle(page, config);
    assert.deepEqual(
      puts.map((body) => JSON.parse(body)),
      [
        {
          configuration: { MountAtStartup: !before.MountAtStartup },
          file: { ExpansionSize: 2, NewVolumeThreshold: 100, volumeRoot: managerDirectory, volumePath: VOLUME_PATH },
        },
      ],
      'one Save, carrying only the changed groups and fields'
    );
    assert.equal(configured(EDITED)?.MountAtStartup, !before.MountAtStartup, 'the mounting group round-tripped');
    const file = fileAt(directoryOf(EDITED));
    assert.ok(file !== null, 'the file is still there');
    assert.deepEqual(
      [file.ExpansionSize, file.NewVolumeThreshold, file.NewVolumeDirectory],
      [2, 100, `${managerDirectory}${VOLUME_PATH}/`],
      'the file group round-tripped, the new volume directory resolved under the manager directory'
    );
  } finally {
    await context.close();
  }
});

// AC3. Mutation (Rule 19): make `confirmPending` swap the action instead of sending `DeleteFile`,
// rebuild and redeploy -> the request-body and file assertions go red.
test('AC3: Delete names the namespace and application using the database, is refused while they do, passes DW-1337, then with the file option removes the configuration and its file', async () => {
  const dir = directoryOf(DELETED);
  assert.ok(fileAt(dir) !== null, 'the deleted database is seeded');
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const writes = [];
  page.on('request', (request) => {
    if (request.method() === 'POST' && request.url().includes(ACTION_PATH)) writes.push(request.postData() ?? '');
  });
  try {
    const inUse = impactLine([NAMESPACE], [APP]);
    const dialog = await openDelete(page, DELETED, inUse);
    assert.deepEqual(dialog, {
      title: `${STRINGS.actionDelete} ${DELETED}`,
      consequence: STRINGS.localDatabaseDeleteConsequence,
      advisory: inUse,
      flag: STRINGS.localDatabaseDeleteFileOption,
      flagChecked: false,
    });
    await assertStructure(page, LIST_ROUTE, true);
    assert.deepEqual(writes, [], 'nothing is sent while the dialog is open');

    // In use: refused 409 DATABASE.INUSE, and nothing is removed.
    await confirmDelete(page, DELETED, true);
    await page.waitForFunction(
      (wanted) => (document.querySelector('.ocu-list-page-banner[role="alert"] .ocu-banner-message')?.textContent ?? '').trim() === wanted,
      { timeout: 90000 },
      INUSE_REASON
    );
    assert.deepEqual(writes.map((body) => JSON.parse(body)), [{ action: 'delete', id: DELETED, values: { DeleteFile: 'true' } }]);
    assert.notEqual(configured(DELETED), null, 'the configuration stays');
    assert.notEqual(fileAt(dir), null, 'and so does its file');

    // Once the namespace and its application are gone, the file goes with the configuration.
    const removed = irisSys(
      [
        `If ##class(Security.Applications).Exists("${APP}") Do ##class(Security.Applications).Delete("${APP}")`,
        `If ##class(Config.Namespaces).Exists("${NAMESPACE}") Do ##class(Config.Namespaces).Delete("${NAMESPACE}")`,
        mark('GONE', `('##class(Config.Namespaces).Exists("${NAMESPACE}"))&&('##class(Security.Applications).Exists("${APP}"))`),
      ],
      ['GONE']
    );
    assert.equal(removed.values.GONE, '1', `the probe namespace and application were removed:\n${removed.output}`);
    const unused = impactLine([], []);
    await openDelete(page, DELETED, unused);
    await confirmDelete(page, DELETED, true);
    await page.waitForFunction(
      (selector, name) => !Array.from(document.querySelectorAll(selector)).some((row) => row.textContent.includes(name)),
      { timeout: 90000 },
      ROW_SELECTOR,
      DELETED
    );
    assert.deepEqual(writes.map((body) => JSON.parse(body)).at(-1), { action: 'delete', id: DELETED, values: { DeleteFile: 'true' } });
    assert.equal(configured(DELETED), null, 'the configuration is gone');
    assert.equal(fileAt(dir), null, 'and its IRIS.DAT');
    assert.equal(irisSys([mark('DIR', `##class(%File).DirectoryExists("${dir}")`)], ['DIR']).values.DIR, '1', 'while its directory stays');
  } finally {
    await context.close();
  }
});

test("AC4: Delete on IRISSYS opens with the kernel's refusal as its advisory", async () => {
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const writes = [];
  page.on('request', (request) => {
    if (request.method() === 'POST' && request.url().includes(ACTION_PATH)) writes.push(request.postData() ?? '');
  });
  try {
    const dialog = await openDelete(page, 'IRISSYS', STRINGS.databaseRefusalOcuPilot);
    assert.equal(dialog.advisory, STRINGS.databaseRefusalOcuPilot);
    await dismiss(page);
    assert.deepEqual(writes, [], 'the leg sends nothing');
    assert.notEqual(configured('IRISSYS'), null, 'IRISSYS is still configured');
  } finally {
    await context.close();
  }
});

// AC8. Mutation (Rule 19), over a rebuilt and redeployed bundle: compare the directories with case in
// `comparableDirectory` -> the seeded compact, which the vendor names in upper case, is not listed and
// this goes red.
test('AC8 (DW-1080): Database details lists the paused compact running against its directory and passes DW-1337, and a database with none says so', async () => {
  seededCompact = true;
  try {
    const seeded = seedIris(
      [
        `Set sc=##class(${SEED}).PausedCompact(.job,.task)`,
        mark('BGSEED', `$Select($System.Status.IsOK(sc):"ok#"_##class(${SEED}).Directory(),1:$System.Status.GetErrorText(sc))`),
      ],
      'BGSEED'
    );
    assert.ok(seeded.value !== null && seeded.value.startsWith('ok#'), `a paused compact is seeded:\n${seeded.output}`);
    const directory = seeded.value.slice(3);
    const { context, page } = await signedInAt(browser, config, detailsUrl(directory), VIEWPORTS.wide);
    try {
      await page.waitForSelector('.ocu-details-tasks tbody tr', { visible: true, timeout: config.navigationTimeoutMs });
      const section = await page.$eval('.ocu-details-tasks', (element) => ({
        heading: element.querySelector('h2')?.textContent.trim() ?? '',
        headers: Array.from(element.querySelectorAll('th')).map((th) => th.textContent.trim()),
        rows: Array.from(element.querySelectorAll('tbody tr')).map((tr) => Array.from(tr.querySelectorAll('td')).map((td) => td.textContent.trim())),
      }));
      assert.equal(section.heading, STRINGS.backgroundTaskListLabel);
      assert.deepEqual(section.headers, [STRINGS.proposalEntityTask, STRINGS.taskHistoryColumnStatus, STRINGS.taskStartTime]);
      assert.equal(section.rows.length, 1, `the one task over this database: ${JSON.stringify(section.rows)}`);
      assert.deepEqual(section.rows[0].slice(0, 2), ['Compact DB Space', 'Paused'], 'the portal compact, paused');
      assert.match(section.rows[0][2], /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/, 'with the time it started');
      await assertStructure(page, DETAILS_ROUTE);
    } finally {
      await context.close();
    }
  } finally {
    removeCompactSeed();
    seededCompact = false;
  }
  const { context, page } = await signedInAt(browser, config, detailsUrl(directoryOf(EDITED)), VIEWPORTS.wide);
  try {
    await page.waitForFunction(
      (wanted) => (document.querySelector('.ocu-details-tasks-none')?.textContent ?? '').trim() === wanted,
      { timeout: config.navigationTimeoutMs },
      STRINGS.databaseTasksNone
    );
    assert.equal(await page.$('.ocu-details-tasks tbody tr'), null, 'and lists no task');
  } finally {
    await context.close();
  }
});

// AC7. Mutation (Rule 19), over a rebuilt and redeployed bundle: draw a wizard step label in
// `--ocu-surface` -> the contrast legs go red in both themes.
test('AC7 (DW-1337): the list, the wizard\u2019s first and last steps and the editor pass the structural walk at wide light, narrow light and wide dark', async () => {
  for (const [url, route, ready] of [
    [LIST_URL, LIST_ROUTE, ROW_SELECTOR],
    [EDIT_URL, FORM_ROUTE, '#ocu-database-edit-ExpansionSize'],
  ]) {
    const { context, page } = await signedInAt(browser, config, url, VIEWPORTS.wide);
    try {
      await page.waitForSelector(ready, { visible: true, timeout: config.navigationTimeoutMs });
      await assertStructure(page, route);
    } finally {
      await context.close();
    }
  }
  const { context, page } = await signedInAt(browser, config, WIZARD_URL, VIEWPORTS.wide);
  const writes = [];
  page.on('request', (request) => {
    if (request.method() !== 'GET' && new URL(request.url()).pathname === CREATE_PATH) writes.push(request.postData() ?? '');
  });
  try {
    await page.waitForSelector('#ocu-database-location-path', { visible: true, timeout: config.navigationTimeoutMs });
    await assertStructure(page, FORM_ROUTE);
    await page.type('#ocu-database-Name', NEVER);
    await chooseManagerRoot(page, 'ocu-database-location');
    await nextTo(page, STRINGS.databaseWizardStepSize);
    await nextTo(page, STRINGS.webAppColumnResource);
    await assertStructure(page, FORM_ROUTE);
    assert.deepEqual(writes, [], 'the walk creates nothing');
    assert.equal(configured(NEVER), null);
  } finally {
    await context.close();
  }
});

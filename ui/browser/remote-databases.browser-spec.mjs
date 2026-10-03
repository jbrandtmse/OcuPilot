/**
 * Remote databases, its form and its delete in a real browser, against the throwaway instance
 * (Story 18.16).
 *
 * What it pins, each on rendered DOM, on the request the page sent, or on the instance itself:
 *
 * 1. **The list** (AC1, AC8): OS management's twelfth and last side-bar entry reads "Remote
 *    databases", and the list shows the seeded remote configuration with its data server and
 *    directory.
 * 2. **The form** (AC5): from the list's Create, the Data server hint states the listing's bound
 *    before anything is chosen; choosing the probe data server sends the listing, and while it is in
 *    flight (held here by request interception) the select stays focusable and `aria-disabled` and
 *    the running line names the server and the time it was sent; the license refusal then renders on
 *    Data server within the bound plus 5 s, and Directory offers nothing. A Save is refused on its
 *    field and creates nothing.
 * 3. **The delete** (AC4): the typed-name dialog states the remote consequence and an advisory naming
 *    the probe namespace that maps globals to the database; the confirmed delete is refused
 *    `DATABASE.INUSE` with nothing removed; once the mapping is gone the delete sends no value and
 *    the row leaves the list.
 * 4. **DW-1337** (AC8): the list, the form with its refusal and the Delete dialog pass the structural
 *    walk at wide light, narrow light and wide dark.
 *
 * **It refuses the live and development containers.** It seeds the probe data server
 * `OCUPROBE1816SRV`, the remote configuration `OCUPROBE1816B` and, for the in-use leg, the probe
 * namespace's global mapping through `OcuPilot.Test.RemoteDatabaseProbe` (test-only `%SYS` seeding),
 * and removes every `OCUPROBE1816*` object with its `RemoveAll` before and after, asserting none
 * survives.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1
 * browser/remote-databases.browser-spec.mjs`.
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

const UNREACHABLE_REASON = serverSentence('Api/DatabaseError.cls', 'REASONSERVERUNREACHABLE');
const NONE_REASON = serverSentence('Api/DatabaseError.cls', 'REASONREMOTEDIRECTORYNONE');
const INUSE_REASON = serverSentence('Api/DatabaseError.cls', 'REASONINUSE');

/** The listing's bound, read from the port that enforces it. */
const LIST_SECONDS = Number(
  /^Parameter LISTSECONDS As INTEGER = (\d+);/m.exec(readFileSync(join(repoRoot, 'src', 'OcuPilot', 'Port', 'RemoteDatabasePort.cls'), 'utf8'))?.[1]
);

const PROBE = 'OcuPilot.Test.RemoteDatabaseProbe';

/** The probe data server, the seeded remote configuration, and the name the refused Save types. */
const SERVER = 'OCUPROBE1816SRV';
const REMOTE = 'OCUPROBE1816B';
const REMOTE_DIRECTORY = '/ocuprobe1816b/';
const NEVER = 'OCUPROBE1816C';
/** The probe namespace whose global mapping uses `REMOTE` in the in-use leg. */
const NAMESPACE = 'OCUPROBE1816N';

const LIST_ROUTE = 'os-management/remote-databases';
const FORM_ROUTE = 'os-management/remote-databases/edit';
const LIST_URL = `/ocupilot/${LIST_ROUTE}?ns=HSCUSTOM`;
const DIRECTORIES_PATH = '/api/ocupilot/remote-database/directories';
const CREATE_PATH = '/api/ocupilot/remote-database';
const ACTION_PATH = '/api/ocupilot/screens/osmgmt.remotedatabases/action';

/** The row cells' own text selector, a name cell being a link. */
const NAME_TEXT = '.ocu-data-table-link, .ocu-data-table-text';

let browser = null;

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
    const found = new RegExp(`OCU-${name}-START:(.*?):OCU-${name}-END`).exec(output);
    values[name] = found === null ? null : found[1].trim();
  }
  return { values, output };
}

/** Remove every probe object and assert none survives. */
function removeAll() {
  const { values, output } = iris([`Set sc=##class(${PROBE}).RemoveAll(.r)`, mark('LEFT', `##class(${PROBE}).Remaining()`)], ['LEFT']);
  assert.equal(values.LEFT, '0', `no OCUPROBE1816 object survives:\n${output}`);
}

/** Run one seeding call of the probe class, asserting it answered OK. */
function seed(call) {
  const { values, output } = iris([`Set sc=##class(${PROBE}).${call}`, mark('SEED', '$Select($System.Status.IsOK(sc):"ok",1:$System.Status.GetErrorText(sc))')], ['SEED']);
  assert.equal(values.SEED, 'ok', `${call} answered OK:\n${output}`);
}

/** Whether the instance holds the configuration `name`, read through the admin API. */
function holds(name) {
  const { values, output } = iris([mark('HOLDS', `##class(${PROBE}).Holds("${name}")`)], ['HOLDS']);
  assert.ok(values.HOLDS === '0' || values.HOLDS === '1', `the configuration read answered a holding or a 404:\n${output}`);
  return values.HOLDS === '1';
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates and deletes configurations, so it never runs inside the live container');
  assert.ok(!/^ocupilot-slot-/.test(config.container), 'nor inside a development instance');
  assert.ok(Number.isInteger(LIST_SECONDS) && LIST_SECONDS > 0, 'RemoteDatabasePort declares its bound');
  await assertThrowaway(config);
  removeAll();
  seed('SeedServer()');
  seed(`SeedRemote("${REMOTE}")`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    if (config.container !== LIVE_CONTAINER) removeAll();
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

/** Open the Delete dialog on `name`'s row and answer its title, consequence, advisory and flag once the advisory reads `expectedAdvisory`. */
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
    flag: document.querySelector('[role="dialog"] [data-slot="flag"]') !== null,
  }));
}

/** Type the configuration's name into the open dialog and confirm, then wait for the dialog to close. */
async function confirmDelete(page, name) {
  await page.type('.ocu-typed-name-field', name);
  await page.keyboard.press('Enter');
  await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: 90000 });
}

/** The advisory a remote database delete states for the namespaces that use it (none, or one). */
function impactLine(namespaces) {
  const part =
    namespaces.length === 0
      ? STRINGS.impactNamespacesUseNone
      : STRINGS.impactNamespacesUseOne.replace('<names>', () => namespaces.join(', '));
  return STRINGS.impactLine.replace('<parts>', () => part);
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

// AC1, AC8. Mutation (Rule 19): give RemoteDatabaseList `sideBarPosition` 0 and regenerate the
// mirror, rebuild and redeploy -> the side-bar assertion goes red.
test('AC1, AC8: Remote databases is the twelfth OS management entry and lists the seeded configuration with its data server', async () => {
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const bar = await sideBarOf(page);
    assert.equal(bar.area, STRINGS.navAreaOsManagement);
    assert.deepEqual(bar.entries, [
      STRINGS.processListLabel,
      STRINGS.lockListLabel,
      STRINGS.systemUsageLabel,
      STRINGS.databaseListLabel,
      STRINGS.databaseIntegrityLogLabel,
      STRINGS.deviceListLabel,
      STRINGS.namespaceListLabel,
      STRINGS.licenseUsageLabel,
      STRINGS.dashboardLabel,
      STRINGS.languageServersLabel,
      STRINGS.localDatabaseListLabel,
      STRINGS.remoteDatabaseListLabel,
      // Story 18.5: Journals follows, the thirteenth.
      STRINGS.journalListLabel,
      // Story 18.18: Journal settings, the fourteenth.
      STRINGS.journalSettingsLabel,
    ]);
    const headers = await page.$$eval('.ocu-data-table-header-label', (labels) => labels.map((label) => label.textContent.trim()));
    assert.deepEqual(headers.slice(0, 4), [STRINGS.tableColumnName, STRINGS.remoteDatabaseServer, STRINGS.lockColumnDirectory, STRINGS.taskHistoryColumnStatus]);
    assert.deepEqual(await rowCells(page, REMOTE), [REMOTE, SERVER, REMOTE_DIRECTORY], 'the row shows its data server and directory');
    await assertStructure(page, LIST_ROUTE);
  } finally {
    await context.close();
  }
});

// AC5. Mutation (Rule 19): drop the Data server hint from the form's template, rebuild and redeploy
// -> the hint assertion goes red before anything is chosen.
test('AC5: the form states the bound before a server is chosen, gates the select with the running line while the listing runs, then shows the license refusal on Data server; a Save is refused on its field', async () => {
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const held = [];
  const saves = [];
  await page.setRequestInterception(true);
  page.on('request', (request) => {
    if (new URL(request.url()).pathname === DIRECTORIES_PATH) {
      held.push(request);
      return;
    }
    void request.continue();
  });
  page.on('response', (response) => {
    const request = response.request();
    if (request.method() === 'POST' && new URL(request.url()).pathname === CREATE_PATH) saves.push(response.status());
  });
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await (await page.waitForSelector('.ocu-command-bar button.ocu-button-primary', { visible: true, timeout: config.navigationTimeoutMs })).click();
    await page.waitForFunction((route) => new URL(window.location.href).pathname.endsWith(`/${route}`), { timeout: config.navigationTimeoutMs }, FORM_ROUTE);
    await page.waitForSelector('#ocu-remote-database-Server', { visible: true, timeout: config.navigationTimeoutMs });

    // Before any choice: the hint states the bound and describes the select, and nothing is listed.
    const hint = STRINGS.remoteDatabaseListHint.replace('<n>', () => String(LIST_SECONDS));
    const before = await page.evaluate(() => {
      const select = document.querySelector('#ocu-remote-database-Server');
      const shown = document.querySelector('[data-listing="hint"]');
      return {
        hint: shown?.textContent.trim() ?? null,
        describedBy: (select.getAttribute('aria-describedby') ?? '').split(' '),
        hintId: shown?.id ?? null,
        servers: Array.from(select.options).map((option) => option.value),
      };
    });
    assert.equal(before.hint, hint, 'the hint states the bound before anything is chosen');
    assert.ok(before.hintId !== null && before.describedBy.includes(before.hintId), 'and describes the Data server select');
    assert.ok(before.servers.includes(SERVER), `the select offers the probe data server: ${JSON.stringify(before.servers)}`);
    assert.equal(held.length, 0, 'no listing is sent before a choice');

    // The choice sends the listing; while it is held, the select is gated and the running line shows.
    const chosenAt = Date.now();
    await page.select('#ocu-remote-database-Server', SERVER);
    const deadline = Date.now() + config.navigationTimeoutMs;
    while (held.length === 0 && Date.now() < deadline) await new Promise((resolve) => setTimeout(resolve, 50));
    assert.equal(held.length, 1, 'one listing was sent');
    assert.equal(new URL(held[0].url()).searchParams.get('server'), SERVER);
    const running = await page.evaluate(() => {
      const select = document.querySelector('#ocu-remote-database-Server');
      const status = document.querySelector('[data-listing="status"]');
      return {
        ariaDisabled: select.getAttribute('aria-disabled'),
        disabled: select.disabled,
        describedBy: (select.getAttribute('aria-describedby') ?? '').split(' '),
        statusRole: status?.getAttribute('role') ?? null,
        statusId: status?.id ?? null,
        line: status?.textContent.trim() ?? '',
      };
    });
    assert.equal(running.ariaDisabled, 'true', 'the select is aria-disabled while the listing runs');
    assert.equal(running.disabled, false, 'and stays focusable');
    assert.equal(running.statusRole, 'status');
    assert.ok(running.describedBy.includes(running.statusId), 'the running line is the select\'s reason');
    const prefix = STRINGS.remoteDatabaseListRunning.replace('<server>', () => SERVER).replace('<time>', () => '');
    assert.ok(running.line.startsWith(prefix) && /^\d{2}:\d{2}:\d{2}$/.test(running.line.slice(prefix.length)), `the running line names the server and the time: ${running.line}`);

    // Released, the instance answers the license refusal at once, on Data server, within the bound plus 5 s.
    const releasedAt = Date.now();
    await held[0].continue();
    await page.waitForFunction(
      (wanted) => (document.querySelector('#ocu-remote-database-Server-reason')?.textContent ?? '').trim() === wanted,
      { timeout: (LIST_SECONDS + 5) * 1000 },
      UNREACHABLE_REASON
    );
    assert.ok(Date.now() - chosenAt <= (LIST_SECONDS + 5) * 1000, 'the reason rendered within the bound plus 5 s');
    // At once: a listing attempted on this license would block about 11 s (Task 0), so 5 s tells the two apart.
    assert.ok(Date.now() - releasedAt < 5000, `the license refusal rendered at once, ${Date.now() - releasedAt} ms after the listing was released`);
    const refused = await page.evaluate(() => ({
      ariaDisabled: document.querySelector('#ocu-remote-database-Server').getAttribute('aria-disabled'),
      invalid: document.querySelector('#ocu-remote-database-Server').getAttribute('aria-invalid'),
      directories: Array.from(document.querySelectorAll('#ocu-remote-database-Directory option')).map((option) => option.value),
      line: document.querySelector('[data-listing="status"]').textContent.trim(),
    }));
    assert.deepEqual(refused, { ariaDisabled: null, invalid: 'true', directories: [''], line: '' }, 'the select is open again, marked invalid, and Directory offers nothing');
    await assertStructure(page, FORM_ROUTE);

    // A Save is refused on its field, and nothing is created.
    await page.type('#ocu-remote-database-Name', NEVER);
    await page.click('.ocu-form-bar-actions .ocu-button-primary');
    await page.waitForFunction(
      (wanted) => (document.querySelector('#ocu-remote-database-Directory-reason')?.textContent ?? '').trim() === wanted,
      { timeout: (LIST_SECONDS + 5) * 1000 },
      NONE_REASON
    );
    assert.deepEqual(saves, [422], 'one Save was sent and refused');
    assert.equal(await page.$eval('#ocu-remote-database-Directory', (select) => select.getAttribute('aria-invalid')), 'true');
    assert.equal(holds(NEVER), false, 'nothing was created');
  } finally {
    for (const request of held) {
      if (!request.isInterceptResolutionHandled()) await request.continue().catch(() => {});
    }
    await context.close();
  }
});

// AC4. Mutation (Rule 19): drop REMOTE_DATABASE_LIST from IMPACT_ACTIONS in screen-action-handler.ts,
// rebuild and redeploy -> the dialog opens with no advisory and the advisory wait goes red.
test('AC4: Delete names the namespace using the remote database, is refused while it does, passes DW-1337, then removes the configuration', async () => {
  seed(`SeedMapping("${REMOTE}")`);
  const { context, page } = await signedInAt(browser, config, LIST_URL, VIEWPORTS.wide);
  const writes = [];
  page.on('request', (request) => {
    if (request.method() === 'POST' && new URL(request.url()).pathname === ACTION_PATH) writes.push(request.postData() ?? '');
  });
  try {
    const inUse = impactLine([NAMESPACE]);
    const dialog = await openDelete(page, REMOTE, inUse);
    assert.deepEqual(dialog, {
      title: `${STRINGS.actionDelete} ${REMOTE}`,
      consequence: STRINGS.remoteDatabaseDeleteConsequence,
      advisory: inUse,
      flag: false,
    });
    await assertStructure(page, LIST_ROUTE, true);
    assert.deepEqual(writes, [], 'nothing is sent while the dialog is open');

    // In use: refused 409 DATABASE.INUSE, and nothing is removed.
    await confirmDelete(page, REMOTE);
    await page.waitForFunction(
      (wanted) => (document.querySelector('.ocu-list-page-banner[role="alert"] .ocu-banner-message')?.textContent ?? '').trim() === wanted,
      { timeout: 90000 },
      INUSE_REASON
    );
    assert.deepEqual(writes.map((body) => JSON.parse(body)), [{ action: 'delete', id: REMOTE }]);
    assert.equal(holds(REMOTE), true, 'the configuration stays');

    // Once the mapping is gone the delete removes the configuration, and the row leaves the list.
    seed('RemoveMapping()');
    await openDelete(page, REMOTE, impactLine([]));
    await confirmDelete(page, REMOTE);
    await page.waitForFunction(
      (selector, name) => !Array.from(document.querySelectorAll(selector)).some((row) => row.textContent.includes(name)),
      { timeout: 90000 },
      ROW_SELECTOR,
      REMOTE
    );
    assert.deepEqual(writes.map((body) => JSON.parse(body)).at(-1), { action: 'delete', id: REMOTE });
    assert.equal(holds(REMOTE), false, 'the configuration is gone');
  } finally {
    await context.close();
  }
});

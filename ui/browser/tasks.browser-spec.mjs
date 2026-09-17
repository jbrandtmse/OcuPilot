/**
 * The task schedule in a real browser, against the throwaway instance: the declared read, table and
 * filter end to end (AC1), the Task Manager suspended banner and its absence while it runs (AC2),
 * the demo fixture's row (AC3), one auto-refresh tick preserving the view (AC4), and the manual
 * Refresh action doing the same from a real click (AC-DW260, DW-307).
 *
 * **It suspends and resumes the throwaway's Task Manager, so it refuses the live container.** The
 * AC2 leg drives `%SYS.Task.SuspendSet` through the container's own session and resumes in a
 * `finally`, whatever the leg did; `after` resumes again and reads the state back, so a failure
 * mid-leg cannot leave the instance suspended. Nothing here touches the live instance's Task
 * Manager or any of its tasks.
 *
 * **It needs the demo fixture** (`OCUPILOT_DEMO=1`, AD-25), because `OcuPilotDemo nightly purge` is
 * the row AC3 is asserted on.
 *
 * AC5's denial -- a principal holding `%Admin_Task:USE` without `%DB_IRISSYS:READ` -- is proven over
 * HTTP by `OcuPilot.Test.WireSecurityRead`.
 *
 * **Story 6.5** adds On-demand tasks and Upcoming tasks: the side bar's three entries (AC1), the
 * On-demand table offering no action but Refresh (AC2), the Upcoming horizon's reads (AC3), and each
 * route's denied deep link (AC4). AC4 needs a principal holding install-database read and
 * `%Admin_Task:USE` alone, which `before` creates on the throwaway and `after` deletes.
 *
 * Run: `npm run test:browser` (after `npm run build` and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { parseMarkers, taskManagerStateFrom } from './iris-session.mjs';
import { ROW_SELECTOR, clickRowCentre, filterToSubset, viewCount, waitForRows } from './list-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const LIST_URL = '/ocupilot/tasks/schedule?ns=HSCUSTOM';
const READ_PATH = '/api/ocupilot/screens/tasks.schedule/read';
const DEMO_TASK = 'OcuPilotDemo nightly purge';
const ON_DEMAND_URL = '/ocupilot/tasks/on-demand?ns=HSCUSTOM';
const ON_DEMAND_READ_PATH = '/api/ocupilot/screens/tasks.ondemand/read';
const UPCOMING_URL = '/ocupilot/tasks/upcoming?ns=HSCUSTOM';
const UPCOMING_READ_PATH = '/api/ocupilot/screens/tasks.upcoming/read';
const HISTORY_URL = '/ocupilot/tasks/history?ns=HSCUSTOM';
const HISTORY_READ_PATH = '/api/ocupilot/screens/tasks.history/read';
const TASK_HISTORY_READ_PATH = '/api/ocupilot/screens/tasks.taskhistory/read';
const TASK_USER = 'OcuPilotTasksTaskOnly';
const TASK_ROLE = 'OcuPilotTasksTaskOnlyRole';
const TASK_PASSWORD = 'OcuPilotTasks1';
const SYSTEM_TASK = 'Switch Journal';

/** `%SYS.Task.TASKMGRStatus()`: 0 not running, 1 running, 2 suspended. */
const RUNNING = '1';
const SUSPENDED = '2';

let browser = null;

/**
 * Run ObjectScript lines in `iris session` inside the throwaway, starting in `%SYS`, and return the
 * value each named marker carries (`parseMarkers`, `iris-session.mjs`). Markers are split on their
 * source line, so the echoed source cannot supply one. The same helper shape `users.browser-spec.mjs`
 * uses.
 */
function irisSession(lines, names) {
  const input = `${[...lines, 'Halt'].join('\n')}\n`;
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', '%SYS'], {
    input,
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  return { values: parseMarkers(output, names), output };
}

const mark = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/**
 * Set the throwaway's Task Manager to suspended (1) or running (0) and read the state back.
 *
 * **`SuspendSet` does not settle before it returns**, so the state is polled rather than read once:
 * the vendor's own portal page hangs a second between `SuspendSet` and `TASKMGRStatus()`
 * (`%CSP.UI.Portal.TaskSchedule`). Reading it in the same breath is a race whose loser is a red leg
 * with no cause in its message. The loop gives it up to ten seconds; `taskManagerStateFrom`
 * (`iris-session.mjs`, pinned by `ui/tools/iris-session.test.mjs`) is what then names a refusal and
 * answers the state actually read, so a poll that never converged fails on the caller's own
 * comparison rather than silently.
 */
function setTaskManagerSuspended(suspended) {
  assert.notEqual(config.container, LIVE_CONTAINER, 'the live instance\'s Task Manager is never touched');
  const wanted = suspended ? 2 : 1;
  const { values, output } = irisSession(
    [
      `Set tSC=##class(%SYS.Task).SuspendSet(${suspended ? 1 : 0})`,
      mark('OK', '$System.Status.IsOK(tSC)'),
      `For tI=1:1:20 { Quit:##class(%SYS.Task).TASKMGRStatus()=${wanted}  Hang 0.5 }`,
      mark('STATE', '##class(%SYS.Task).TASKMGRStatus()'),
    ],
    ['OK', 'STATE']
  );
  return taskManagerStateFrom(values, suspended, output);
}

/** Delete the Story 6.5 principal and its role, whichever of them exists. */
const deletePrincipalLines = [
  `If ##class(Security.Users).Exists("${TASK_USER}") Do ##class(Security.Users).Delete("${TASK_USER}")`,
  `If ##class(Security.Roles).Exists("${TASK_ROLE}") Do ##class(Security.Roles).Delete("${TASK_ROLE}")`,
];

before(async () => {
  assert.notEqual(
    config.container,
    LIVE_CONTAINER,
    "this spec suspends and resumes the instance's Task Manager, so it never runs inside the live container"
  );
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  assert.equal(setTaskManagerSuspended(false), RUNNING, 'the Task Manager starts this run running');
  const { values, output } = irisSession(
    [
      ...deletePrincipalLines,
      'Set tNS=$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"):"HSCUSTOM",1:"USER")',
      'Set tRes=##class(SYS.Database).%OpenId(##class(Config.Databases).Open(##class(Config.Namespaces).Open(tNS).Routines).Directory).ResourceName',
      `Set tSC1=##class(Security.Roles).Create("${TASK_ROLE}","OcuPilot tasks browser spec probe (throwaway)",tRes_":R,%Admin_Task:U","")`,
      `Set tSC2=##class(Security.Users).Create("${TASK_USER}","${TASK_ROLE}","${TASK_PASSWORD}","OcuPilot tasks browser spec probe (throwaway)","","","",0,1,"")`,
      mark('CREATED', '$System.Status.IsOK(tSC1)&&$System.Status.IsOK(tSC2)'),
      mark('TASK', `$SYSTEM.Security.CheckUserPermission("${TASK_USER}","%Admin_Task","USE")`),
      mark('SYSREAD', `$SYSTEM.Security.CheckUserPermission("${TASK_USER}","%DB_IRISSYS","READ")`),
    ],
    ['CREATED', 'TASK', 'SYSREAD']
  );
  assert.equal(values.CREATED, '1', `the role and principal were created:\n${output}`);
  assert.equal(values.TASK, '1', 'the probe holds %Admin_Task:USE');
  assert.equal(values.SYSREAD, '0', 'and not %DB_IRISSYS:READ');
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  try {
    const { values, output } = irisSession(
      [
        ...deletePrincipalLines,
        mark('CLEAN', `('##class(Security.Users).Exists("${TASK_USER}"))&&('##class(Security.Roles).Exists("${TASK_ROLE}"))`),
      ],
      ['CLEAN']
    );
    assert.equal(values.CLEAN, '1', `the principal and its role are gone:\n${output}`);
  } finally {
    assert.equal(setTaskManagerSuspended(false), RUNNING, 'the Task Manager is left running whatever the legs did');
  }
});

/**
 * A fresh context signed in through the shell's own form at `url`, the list's deep link unless
 * named, reads counted and each read's answer body kept.
 */
async function signedInAtList(user, password, url = LIST_URL) {
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  const reads = [];
  const answers = [];
  page.on('request', (request) => {
    if (new URL(request.url()).pathname.startsWith('/api/ocupilot/screens/')) reads.push(request.url());
  });
  page.on('response', (response) => {
    if (!new URL(response.url()).pathname.startsWith('/api/ocupilot/screens/')) return;
    answers.push(
      response
        .json()
        .then((body) => ({ url: response.url(), body }))
        .catch(() => ({ url: response.url(), body: null }))
    );
  });
  await page.goto(`${config.origin}${url}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', user);
  await page.type('#ocu-signin-password', password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  // The first-login gate takes an administrator to the Definition form on an instance with no
  // enabled definition, whatever URL was asked for (Story 3.6). Back returns to this one.
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, url);
  return { context, page, reads, answers };
}

/** The rendered row whose name cell reads `name`, described cell by cell. */
function describeRow(page, name) {
  return page.evaluate((wanted, rowSelector) => {
    const style = (element) => (element === null ? null : getComputedStyle(element).fontFamily.replace(/["']/g, ''));
    const root = getComputedStyle(document.documentElement);
    const rows = Array.from(document.querySelectorAll(rowSelector));
    const row = rows.find((candidate) => candidate.querySelector('[role="gridcell"]').textContent.trim() === wanted);
    if (row === undefined) return null;
    const cells = Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => {
      const text = cell.querySelector('.ocu-data-table-link, .ocu-data-table-text');
      return {
        text: cell.textContent.trim(),
        family: style(text),
        link: cell.querySelector('.ocu-data-table-link') !== null,
      };
    });
    return {
      cells,
      code: root.getPropertyValue('--ocu-type-code-family').trim().replace(/["']/g, ''),
      body: root.getPropertyValue('--ocu-type-body-family').trim().replace(/["']/g, ''),
    };
  }, name, ROW_SELECTOR);
}

/**
 * The index of the rendered row whose Name cell reads `name`, or `-1`. Task history and History
 * (one task) both declare Name third (Boundaries' column order: LastStart, Completed, Name, ...),
 * unlike Task schedule and On-demand tasks, where it is first -- so `describeRow` and
 * `clickRowCentre`'s own `text` match (the row's *first* gridcell) cannot find a row by name on
 * either of Story 6.6's two screens, and every lookup on them goes through this instead.
 */
function findRowIndexByName(page, name) {
  return page.evaluate(
    (wanted, rowSelector) => {
      const rows = Array.from(document.querySelectorAll(rowSelector));
      return rows.findIndex((row) => row.querySelectorAll('[role="gridcell"]')[2]?.textContent.trim() === wanted);
    },
    name,
    ROW_SELECTOR
  );
}

/** The banner strip above the table, or `null` when none stands. */
function describeBanner(page) {
  return page.evaluate(() => {
    const strip = document.querySelector('app-list-page .ocu-banner');
    if (strip === null) return null;
    return {
      text: strip.querySelector('.ocu-banner-message')?.textContent?.trim() ?? '',
      classes: [...strip.classList].sort(),
      glyphHidden: strip.querySelector('.ocu-banner-glyph')?.getAttribute('aria-hidden') ?? null,
      dismiss: strip.querySelector('button') !== null,
    };
  });
}

test('AC1: the list reads once under the declared headers, renders its rows, and filters on the namespace and on the name', async () => {
  const { context, page, reads } = await signedInAtList(config.username, config.password);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const headers = await page.$$eval('.ocu-data-table-header-label', (labels) => labels.map((label) => label.textContent.trim()));
    assert.deepEqual(headers, [
      STRINGS.tableColumnName,
      STRINGS.headerNamespaceLabel,
      STRINGS.tableColumnType,
      STRINGS.taskColumnLastRun,
      STRINGS.taskColumnNextRun,
    ]);
    assert.deepEqual(headers, ['Name', 'Namespace', 'Type', 'Last run', 'Next run']);

    const total = await viewCount(page);
    assert.ok(total >= 2, `the instance lists at least two scheduled tasks: ${total}`);

    const system = await describeRow(page, SYSTEM_TASK);
    assert.ok(system !== null, `the ${SYSTEM_TASK} row is rendered`);
    assert.equal(system.cells[0].link, true, 'its name cell is a link');
    assert.equal(system.cells[0].family, system.code, 'in the code face');
    assert.equal(system.cells[1].text, '%SYS', 'the Namespace cell reads the task\'s own namespace');

    // A task the instance has never run carries no Last run and no Next run, and those cells read
    // the empty-cell word rather than rendering blank. Which rows those are is a property of the
    // container, so the rows are read from the view rather than named here.
    const times = await page.$$eval(ROW_SELECTOR, (rows) =>
      rows.map((row) => {
        const cells = Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim());
        return { name: cells[0], last: cells[3], next: cells[4] };
      })
    );
    for (const row of times) {
      assert.notEqual(row.last, '', `${row.name}: Last run renders a word, never an empty cell`);
      assert.notEqual(row.next, '', `${row.name}: Next run renders a word, never an empty cell`);
    }
    assert.ok(
      times.some((row) => row.last === STRINGS.tableEmptyValue || row.next === STRINGS.tableEmptyValue),
      `at least one rendered task has never run, so the empty-cell word is exercised: ${JSON.stringify(times)}`
    );

    // Two legs through two different declared filter fields -- Namespace, then Name -- each from
    // the whole list and each required to leave a proper, non-empty subset (DW-267).
    const leg = { total, timeoutMs: config.navigationTimeoutMs };
    const inSys = await filterToSubset(page, { ...leg, text: '%SYS', expectRow: SYSTEM_TASK });
    assert.ok(inSys < total, `the namespace filter narrows the list: ${inSys} of ${total}`);
    // Measured against the whole list, never against the namespace leg: the filter is a substring
    // match over every declared field, so the two legs have no ordering between them and one that
    // held would hold by accident of the corpus rather than by anything the screen promises.
    const byName = await filterToSubset(page, { ...leg, text: SYSTEM_TASK, expectRow: SYSTEM_TASK });
    assert.ok(byName < total, `and a name substring narrows the list too: ${byName} of ${total}`);

    assert.equal(reads.length, 1, `exactly one screen read was issued: ${JSON.stringify(reads)}`);
    assert.equal(new URL(reads[0]).pathname, READ_PATH);
  } finally {
    await context.close();
  }
});

test('AC2: a suspended Task Manager raises the warning strip above the table while the rows still list, and a running one raises none', async () => {
  const { context, page } = await signedInAtList(config.username, config.password);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    assert.equal(await describeBanner(page), null, 'no strip stands while the Task Manager is running');
    const running = await viewCount(page);
    assert.ok(running >= 2, `the running instance lists its tasks: ${running}`);

    assert.equal(setTaskManagerSuspended(true), SUSPENDED, 'the throwaway Task Manager is suspended');
    await page.reload({ waitUntil: 'networkidle2' });
    await waitForRows(page, config.navigationTimeoutMs);

    const banner = await describeBanner(page);
    assert.ok(banner !== null, 'the strip renders while the Task Manager is suspended');
    assert.equal(banner.text, STRINGS.taskManagerSuspendedBanner);
    assert.equal(
      banner.text,
      'The Task Manager is suspended \u2014 no scheduled task will run until it is resumed.',
      "and it is EXPERIENCE.md's own sentence, em dash included"
    );
    assert.ok(banner.classes.includes('ocu-banner-warning'), `it takes the warning variant: ${banner.classes.join(' ')}`);
    assert.equal(banner.glyphHidden, 'true', 'its glyph is decorative, so the strip reads as its sentence alone');
    assert.equal(banner.dismiss, false, 'and it carries no control: not dismissible, and no Resume (Epic 7 ships that)');
    assert.equal(await viewCount(page), running, 'and the rows still list, unchanged in number');

    // The strip is above the table, not inside it: the table's own frame starts below it.
    const order = await page.evaluate(() => {
      const strip = document.querySelector('app-list-page .ocu-banner');
      const table = document.querySelector('app-list-page app-data-table');
      if (strip === null || table === null) return null;
      return {
        before: (strip.compareDocumentPosition(table) & Node.DOCUMENT_POSITION_FOLLOWING) !== 0,
        above: strip.getBoundingClientRect().bottom <= table.getBoundingClientRect().top,
      };
    });
    assert.deepEqual(order, { before: true, above: true }, 'the strip precedes the table in the document and sits above it');

    assert.equal(setTaskManagerSuspended(false), RUNNING, 'the Task Manager is resumed');
    await page.reload({ waitUntil: 'networkidle2' });
    await waitForRows(page, config.navigationTimeoutMs);
    assert.equal(await describeBanner(page), null, 'and the strip is gone once the condition clears');
  } finally {
    // The resume runs whatever the leg did, but its own assertion must not replace the leg's
    // failure: a throw from here would be the only message left, and the real cause would be lost.
    // `after` resumes again and asserts there, where nothing is masked.
    try {
      setTaskManagerSuspended(false);
    } catch {
      /* reported by `after`, which resumes and asserts once more */
    }
    await context.close();
  }
});

test('AC3: the demo fixture\'s task appears among the scheduled tasks', async () => {
  const { context, page } = await signedInAtList(config.username, config.password);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await filterToSubset(page, {
      text: 'nightly purge',
      expectRow: DEMO_TASK,
      total: await viewCount(page),
      timeoutMs: config.navigationTimeoutMs,
    });
    const demo = await describeRow(page, DEMO_TASK);
    assert.ok(demo !== null, `the ${DEMO_TASK} row is rendered`);
    assert.equal(demo.cells[0].text, DEMO_TASK, "its name is the fixture's own, prefix included");
    assert.notEqual(demo.cells[1].text, '', 'and it carries a namespace');
  } finally {
    await context.close();
  }
});

test('Story 6.6 AC1: Task history renders its form first with no read, Search issues one read carrying search, and the demo task\'s failed run is present', async () => {
  const { context, page, reads } = await signedInAtList(config.username, config.password, HISTORY_URL);
  try {
    await page.waitForSelector('#ocu-task-history-search', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$('[role="grid"]'), null, 'no table before Search');
    assert.equal(await page.$('.ocu-data-table-skeleton'), null, 'no skeleton before Search');
    assert.deepEqual(reads, [], 'no read before Search');

    await page.type('#ocu-task-history-search', 'OcuPilotDemo');
    await page.click('.ocu-criteria-controls button[type="submit"]');
    await waitForRows(page, config.navigationTimeoutMs);

    assert.equal(reads.length, 1, `exactly one read was issued by Search: ${JSON.stringify(reads)}`);
    const url = new URL(reads[0]);
    assert.equal(url.pathname, HISTORY_READ_PATH);
    assert.equal(url.searchParams.get('search'), 'OcuPilotDemo', 'carrying search=OcuPilotDemo');

    const headers = await page.$$eval('.ocu-data-table-header-label', (labels) => labels.map((label) => label.textContent.trim()));
    assert.deepEqual(headers, [
      STRINGS.taskHistoryColumnStarted,
      STRINGS.taskHistoryColumnCompleted,
      STRINGS.tableColumnName,
      STRINGS.taskHistoryColumnStatus,
      STRINGS.taskHistoryColumnResult,
      STRINGS.processColumnUser,
      STRINGS.headerNamespaceLabel,
    ]);
    assert.deepEqual(headers, ['Started', 'Completed', 'Name', 'Status', 'Result', 'User', 'Namespace']);

    assert.ok(
      (await findRowIndexByName(page, DEMO_TASK)) >= 0,
      `the ${DEMO_TASK} row -- its failed install-time run -- is rendered`
    );

    await assertRefreshAlone(page);
  } finally {
    await context.close();
  }
});

test('Story 6.6 AC2/AC3: activating the demo task\'s name cell opens its own history, reading taskId once, every row naming it, with a dialog on the name cell', async () => {
  const { context, page, reads } = await signedInAtList(config.username, config.password, LIST_URL);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await clickRowCentre(page, { text: DEMO_TASK, link: true });
    await page.waitForFunction(
      () => /^\/ocupilot\/tasks\/schedule\/history\/[^/]+$/.test(window.location.pathname),
      { timeout: config.navigationTimeoutMs }
    );
    await waitForRows(page, config.navigationTimeoutMs);

    const historyReads = reads.filter((url) => new URL(url).pathname === TASK_HISTORY_READ_PATH);
    assert.equal(historyReads.length, 1, `exactly one tasks.taskhistory read: ${JSON.stringify(reads)}`);
    assert.notEqual(new URL(historyReads[0]).searchParams.get('taskId'), null, 'the read carries a taskId');

    const names = await page.$$eval(ROW_SELECTOR, (rows) =>
      rows.map((row) => row.querySelectorAll('[role="gridcell"]')[2]?.textContent.trim())
    );
    assert.ok(names.length > 0, 'at least one run is rendered');
    for (const name of names) assert.equal(name, DEMO_TASK, `every row names the demo task: ${JSON.stringify(names)}`);

    // The locator bar's screen segment is a link back to Task schedule, this screen's parent
    // (AC2, DW-142) -- labelled with History's own name, the same shape the Secrets list's own
    // segment takes over the Wallet list.
    const segment = await page.evaluate((label) => {
      const links = Array.from(document.querySelectorAll('app-locator-bar .ocu-locator-link'));
      const link = links.find((candidate) => candidate.textContent.trim() === label);
      return link === undefined ? null : link.textContent.trim();
    }, STRINGS.taskRunsLabel);
    assert.equal(segment, STRINGS.taskRunsLabel, "the locator bar's screen segment is a link, labelled History");
    await page.evaluate((label) => {
      const links = Array.from(document.querySelectorAll('app-locator-bar .ocu-locator-link'));
      links.find((candidate) => candidate.textContent.trim() === label).click();
    }, STRINGS.taskRunsLabel);
    await page.waitForFunction(() => window.location.pathname === '/ocupilot/tasks/schedule', { timeout: config.navigationTimeoutMs });
    assert.equal(new URL(page.url()).pathname, '/ocupilot/tasks/schedule', 'and it leads back to Task schedule');
  } finally {
    await context.close();
  }
});

test('Story 6.6 AC3: activating a row\'s name cell on Task history opens a dialog listing every read field, and closing it restores the searched rows without a new read', async () => {
  const { context, page, reads } = await signedInAtList(config.username, config.password, HISTORY_URL);
  try {
    await page.waitForSelector('#ocu-task-history-search', { timeout: config.navigationTimeoutMs });
    await page.type('#ocu-task-history-search', 'OcuPilotDemo');
    await page.click('.ocu-criteria-controls button[type="submit"]');
    await waitForRows(page, config.navigationTimeoutMs);
    const readsBefore = reads.length;

    const rowIndex = await findRowIndexByName(page, DEMO_TASK);
    assert.ok(rowIndex >= 0, `the ${DEMO_TASK} row is rendered`);
    await clickRowCentre(page, { index: rowIndex, link: true });
    await page.waitForSelector('[role="dialog"]', { timeout: config.navigationTimeoutMs });
    const dialogText = await page.$eval('[role="dialog"]', (dialog) => dialog.textContent);
    assert.ok(dialogText.includes(STRINGS.taskHistoryColumnResult), 'the dialog lists the Result field');
    assert.ok(dialogText.includes(STRINGS.processColumnUser), 'and the User field');
    assert.equal(reads.length, readsBefore, 'no second read for the dialog');

    await page.click('[role="dialog"] button');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    assert.notEqual(await page.$('[role="grid"]'), null, 'the table is still rendered once the dialog closes');
    assert.equal(reads.length, readsBefore, 'closing the dialog issues no new read either');
    assert.ok((await findRowIndexByName(page, DEMO_TASK)) >= 0, 'the searched rows are still rendered');
    await page.waitForFunction(() => window.location.pathname === '/ocupilot/tasks/history', { timeout: config.navigationTimeoutMs });
    assert.equal(new URL(page.url()).pathname, '/ocupilot/tasks/history', 'and the URL is back on the bare route');
  } finally {
    await context.close();
  }
});

test('Story 6.6 AC4: a principal holding install-database read and %Admin_Task:USE alone is refused Task history and per-task history by name and issues no read', async () => {
  for (const [url, label] of [
    [HISTORY_URL, STRINGS.taskHistoryLabel],
    ['/ocupilot/tasks/schedule/history/1?ns=HSCUSTOM', STRINGS.taskRunsLabel],
  ]) {
    const { context, page, reads } = await signedInAtList(TASK_USER, TASK_PASSWORD, url);
    try {
      await page.waitForSelector('app-screen-denied .ocu-screen-denied-title', { timeout: config.navigationTimeoutMs });
      const denied = await page.evaluate(() => ({
        title: document.querySelector('app-screen-denied .ocu-screen-denied-title').textContent.trim(),
        reason: document.querySelector('app-screen-denied .ocu-screen-denied-reason').textContent.trim(),
        grid: document.querySelector('[role="grid"]') !== null,
      }));
      assert.equal(denied.title, label, `${label}: the deep link renders the screen title`);
      assert.equal(denied.reason, `You need %DB_IRISSYS:READ to open ${label}.`, `${label}: naming the pair`);
      assert.equal(denied.grid, false, `${label}: and no table`);
      assert.deepEqual(reads, [], `${label}: no screen read was issued`);
    } finally {
      await context.close();
    }
  }
});

test('AC4: setting the auto-refresh chip re-reads the rows in place, keeping sort, filter, selection and scroll, with no skeleton', async () => {
  const { context, page, reads } = await signedInAtList(config.username, config.password);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const total = await viewCount(page);

    // A sort, a filter, a selection and a scroll offset. The sort is the descriptor's declared
    // default -- no screen ships a sort control yet -- and it is observed as the header's own
    // `aria-sort` plus the order the rows are in, both of which a tick that re-sorted would move.
    await filterToSubset(page, { text: '%SYS', expectRow: SYSTEM_TASK, total, timeoutMs: config.navigationTimeoutMs });
    // A real hit-tested pointer click at the cell's own centre (DW-273). The third cell carries no
    // link, so the click selects the row rather than opening one, and `clickRowCentre` fails first
    // if the point at that centre resolves outside the row.
    await clickRowCentre(page, { index: 0, cell: 3 });
    await page.waitForSelector('[role="row"][aria-selected="true"]', { timeout: config.navigationTimeoutMs });

    // **The window is shortened first, and that is what makes the scroll offset real.** Before
    // DW-273 the frame had no height at all: the viewport measured `clientHeight` 0 against a
    // `scrollHeight` of 1,620, so any `scrollTop` "took" and this assertion passed over a table
    // that was not scrolled because it was not laid out. With the frame sized correctly, this
    // instance's sixteen %SYS tasks fit inside a 900px window and there is nothing to scroll --
    // so the offset is made reachable rather than assumed, and the assertion below still refuses a
    // zero. The width is unchanged, so neither the side bar nor the command bar changes shape.
    await page.setViewport({ ...config.viewport, height: 420 });
    await page.waitForFunction(
      () => {
        const viewport = document.querySelector('cdk-virtual-scroll-viewport');
        return viewport !== null && viewport.scrollHeight > viewport.clientHeight && viewport.clientHeight > 0;
      },
      { timeout: config.navigationTimeoutMs }
    );
    await page.$eval('cdk-virtual-scroll-viewport', (viewport) => {
      viewport.scrollTop = 100;
      viewport.dispatchEvent(new Event('scroll'));
    });

    const before = await page.evaluate((rowSelector) => ({
      sorts: Array.from(document.querySelectorAll('[role="columnheader"]')).map((cell) => cell.getAttribute('aria-sort')),
      filter: document.querySelector('#ocu-command-bar-filter').value,
      selected: document.querySelector('.ocu-data-table-row-selected [role="gridcell"]')?.textContent?.trim() ?? null,
      scroll: document.querySelector('cdk-virtual-scroll-viewport').scrollTop,
      names: Array.from(document.querySelectorAll(rowSelector)).map((row) => row.querySelector('[role="gridcell"]').textContent.trim()),
      stamp: document.querySelector('.ocu-status-bar-stamp')?.textContent?.trim() ?? '',
      announced: (() => {
        const stamp = document.querySelector('.ocu-status-bar-stamp');
        for (let node = stamp; node !== null; node = node.parentElement) {
          if (node.hasAttribute('aria-live') || node.getAttribute('role') === 'status' || node.getAttribute('role') === 'alert') {
            return true;
          }
        }
        return false;
      })(),
    }), ROW_SELECTOR);
    assert.ok(before.scroll > 0, `the table scrolled, so the offset under test is a real one: ${before.scroll}`);
    // Read the same way `after` is, so a selection the tick dropped fails the comparison below
    // rather than throwing here -- and assert it stands, so the two are never null together.
    assert.notEqual(before.selected, null, 'a row is selected, so the selection under test is a real one');
    assert.equal(before.announced, false, 'the auto-refresh stamp is in no live region, so a tick is never announced');

    // The chip's first advance from off is the descriptor's lowest declared rate, 5 s.
    const chip = await page.$('.ocu-command-bar-refresh');
    assert.ok(chip !== null, 'the command bar carries the auto-refresh chip, which only a refreshing screen renders');
    const label = await page.$eval('.ocu-command-bar-refresh', (button) => button.textContent.trim());
    assert.equal(label, 'Auto-refresh: off', 'reading off before it is set');
    const readsBefore = reads.length;
    await chip.click();
    await page.waitForFunction(
      () => document.querySelector('.ocu-command-bar-refresh').textContent.trim() === 'Auto-refresh: every 5 s',
      { timeout: config.navigationTimeoutMs }
    );
    assert.equal(
      await page.$eval('.ocu-command-bar-refresh', (button) => button.textContent.trim()),
      'Auto-refresh: every 5 s',
      'and the first advance takes the lowest declared rate'
    );

    // The chip's rate is 5 s, so one tick lands well inside the navigation timeout. The reads are
    // counted in this process from the page's own request events, so the wait needs nothing of the
    // page: a tick that never fires times out here naming the counts.
    const deadline = Date.now() + config.navigationTimeoutMs;
    while (reads.length <= readsBefore && Date.now() < deadline) {
      await new Promise((resolve) => setTimeout(resolve, 250));
    }
    assert.ok(reads.length > readsBefore, `the tick issued a further read within the timeout: ${reads.length} against ${readsBefore}`);
    for (const url of reads) assert.equal(new URL(url).pathname, READ_PATH, 'and every read is the screen\'s own');

    // A read that has been *issued* is not a tick that has *landed*: the request event fires before
    // the answer arrives, and `applyTick` is what writes the rows and the stamp. The stamp is the
    // one thing the tick is allowed to move, so waiting for it to move is how the snapshot below
    // becomes a picture of the state after the tick rather than during it -- without which every
    // "survives the tick" assertion could be reading the state the tick had not yet touched.
    assert.notEqual(before.stamp, '', `the stamp stood before the tick: ${JSON.stringify(before.stamp)}`);
    await page.waitForFunction(
      (was) => (document.querySelector('.ocu-status-bar-stamp')?.textContent?.trim() ?? '') !== was,
      { timeout: config.navigationTimeoutMs },
      before.stamp
    );

    const after = await page.evaluate((rowSelector) => ({
      sorts: Array.from(document.querySelectorAll('[role="columnheader"]')).map((cell) => cell.getAttribute('aria-sort')),
      filter: document.querySelector('#ocu-command-bar-filter').value,
      selected: document.querySelector('.ocu-data-table-row-selected [role="gridcell"]')?.textContent?.trim() ?? null,
      scroll: document.querySelector('cdk-virtual-scroll-viewport').scrollTop,
      names: Array.from(document.querySelectorAll(rowSelector)).map((row) => row.querySelector('[role="gridcell"]').textContent.trim()),
      stamp: document.querySelector('.ocu-status-bar-stamp')?.textContent?.trim() ?? '',
      skeleton: document.querySelector('.ocu-data-table-skeleton') !== null,
      busy: document.querySelector('[aria-busy="true"]') !== null,
    }), ROW_SELECTOR);

    assert.deepEqual(after.sorts, before.sorts, 'the sort survives the tick');
    assert.equal(after.filter, before.filter, 'and the filter');
    assert.equal(after.selected, before.selected, 'and the selected row');
    assert.equal(after.scroll, before.scroll, 'and the scroll offset');
    assert.deepEqual(after.names, before.names, 'and the rows the view holds');
    assert.equal(after.skeleton, false, 'no skeleton is shown on a re-fetch');
    assert.equal(after.busy, false, 'and nothing is marked busy');

    // The one thing a silent refresh does change, re-read from the same snapshot every other
    // assertion above came from: the stamp the wait watched is still the moved one.
    assert.notEqual(after.stamp, before.stamp, `the tick moved the stamp: ${JSON.stringify(before.stamp)} -> ${JSON.stringify(after.stamp)}`);
  } finally {
    await context.close();
  }
});

/**
 * DW-260 / DW-307 -- the manual Refresh action, not the auto-refresh chip's tick, re-reads the
 * rows in place. AC4 above proves `readNow()` preserves sort, filter, selection and scroll when a
 * timer calls it; this proves the browser leg `.ocu-command-bar-refresh-action` and `onRefreshAction`
 * (`command-bar.ts:449-453`) actually reach the same call from a real click, which no spec exercised
 * before this pass.
 *
 * Mutation: replace `onRefreshAction`'s body with a no-op -> the "a further read within the
 * timeout" assertion goes red naming the same read counts AC4's tick assertion would.
 */
test('AC-DW260: clicking Refresh re-reads the rows in place, keeping sort, filter, selection and scroll, with no skeleton', async () => {
  const { context, page, reads } = await signedInAtList(config.username, config.password);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const total = await viewCount(page);

    // The same sort, filter, selection and scroll offset AC4 exercises, driven the same way.
    await filterToSubset(page, { text: '%SYS', expectRow: SYSTEM_TASK, total, timeoutMs: config.navigationTimeoutMs });
    await clickRowCentre(page, { index: 0, cell: 3 });
    await page.waitForSelector('[role="row"][aria-selected="true"]', { timeout: config.navigationTimeoutMs });

    await page.setViewport({ ...config.viewport, height: 420 });
    await page.waitForFunction(
      () => {
        const viewport = document.querySelector('cdk-virtual-scroll-viewport');
        return viewport !== null && viewport.scrollHeight > viewport.clientHeight && viewport.clientHeight > 0;
      },
      { timeout: config.navigationTimeoutMs }
    );
    await page.$eval('cdk-virtual-scroll-viewport', (viewport) => {
      viewport.scrollTop = 100;
      viewport.dispatchEvent(new Event('scroll'));
    });

    const before = await page.evaluate((rowSelector) => ({
      sorts: Array.from(document.querySelectorAll('[role="columnheader"]')).map((cell) => cell.getAttribute('aria-sort')),
      filter: document.querySelector('#ocu-command-bar-filter').value,
      selected: document.querySelector('.ocu-data-table-row-selected [role="gridcell"]')?.textContent?.trim() ?? null,
      scroll: document.querySelector('cdk-virtual-scroll-viewport').scrollTop,
      names: Array.from(document.querySelectorAll(rowSelector)).map((row) => row.querySelector('[role="gridcell"]').textContent.trim()),
      stamp: document.querySelector('.ocu-status-bar-stamp')?.textContent?.trim() ?? '',
    }), ROW_SELECTOR);
    assert.ok(before.scroll > 0, `the table scrolled, so the offset under test is a real one: ${before.scroll}`);
    assert.notEqual(before.selected, null, 'a row is selected, so the selection under test is a real one');
    assert.notEqual(before.stamp, '', `the stamp stood before Refresh: ${JSON.stringify(before.stamp)}`);

    const action = await page.$('.ocu-command-bar-refresh-action');
    assert.ok(action !== null, 'the command bar carries the manual Refresh action on a screen that reads (DW-260)');
    const readsBefore = reads.length;
    await action.click();

    const deadline = Date.now() + config.navigationTimeoutMs;
    while (reads.length <= readsBefore && Date.now() < deadline) {
      await new Promise((resolve) => setTimeout(resolve, 250));
    }
    assert.ok(reads.length > readsBefore, `Refresh issued a further read within the timeout: ${reads.length} against ${readsBefore}`);
    for (const url of reads.slice(readsBefore)) assert.equal(new URL(url).pathname, READ_PATH, "and it is the screen's own read");

    // A read *issued* is not one *landed*: wait for the stamp to move, the same signal AC4 uses,
    // before reading the "survives Refresh" snapshot below.
    await page.waitForFunction(
      (was) => (document.querySelector('.ocu-status-bar-stamp')?.textContent?.trim() ?? '') !== was,
      { timeout: config.navigationTimeoutMs },
      before.stamp
    );

    const after = await page.evaluate((rowSelector) => ({
      sorts: Array.from(document.querySelectorAll('[role="columnheader"]')).map((cell) => cell.getAttribute('aria-sort')),
      filter: document.querySelector('#ocu-command-bar-filter').value,
      selected: document.querySelector('.ocu-data-table-row-selected [role="gridcell"]')?.textContent?.trim() ?? null,
      scroll: document.querySelector('cdk-virtual-scroll-viewport').scrollTop,
      names: Array.from(document.querySelectorAll(rowSelector)).map((row) => row.querySelector('[role="gridcell"]').textContent.trim()),
      stamp: document.querySelector('.ocu-status-bar-stamp')?.textContent?.trim() ?? '',
      skeleton: document.querySelector('.ocu-data-table-skeleton') !== null,
      busy: document.querySelector('[aria-busy="true"]') !== null,
    }), ROW_SELECTOR);

    assert.deepEqual(after.sorts, before.sorts, 'the sort survives Refresh');
    assert.equal(after.filter, before.filter, 'and the filter');
    assert.equal(after.selected, before.selected, 'and the selected row');
    assert.equal(after.scroll, before.scroll, 'and the scroll offset');
    assert.deepEqual(after.names, before.names, 'and the rows the view holds');
    assert.equal(after.skeleton, false, 'no skeleton is shown on Refresh (EXPERIENCE.md "Refresh is silent")');
    assert.equal(after.busy, false, 'and nothing is marked busy');
    assert.notEqual(after.stamp, before.stamp, `Refresh moved the stamp: ${JSON.stringify(before.stamp)} -> ${JSON.stringify(after.stamp)}`);
  } finally {
    await context.close();
  }
});

/** The side bar as rendered: its entry labels and its current entry, opening it first. */
async function sideBarOf(page) {
  if ((await page.$('app-side-bar nav.ocu-side-bar')) === null) {
    await page.keyboard.down('Control');
    await page.keyboard.press('b');
    await page.keyboard.up('Control');
  }
  await page.waitForSelector('app-side-bar nav.ocu-side-bar', { timeout: config.navigationTimeoutMs });
  return page.evaluate(() => {
    const nav = document.querySelector('app-side-bar nav.ocu-side-bar');
    const current = nav.querySelector('.ocu-side-bar-item[aria-current="page"] .ocu-side-bar-label');
    return {
      entries: Array.from(nav.querySelectorAll('.ocu-side-bar-item .ocu-side-bar-label')).map((label) => label.textContent.trim()),
      current: current === null ? null : current.textContent.trim(),
    };
  });
}

/** Wait until a screen read whose URL satisfies `matches` has been issued, and answer its URL. */
async function readMatching(reads, matches) {
  const deadline = Date.now() + config.navigationTimeoutMs;
  while (Date.now() < deadline) {
    const found = reads.find((url) => matches(new URL(url)));
    if (found !== undefined) return new URL(found);
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  assert.fail(`no matching screen read within the timeout: ${JSON.stringify(reads)}`);
}

/** Assert no row, command bar or command box on the open screen offers an action but Refresh. */
async function assertRefreshAlone(page) {
  const offered = await page.evaluate(() => ({
    rowTriggers: document.querySelectorAll('.ocu-data-table-trigger').length,
    barActions: Array.from(document.querySelectorAll('.ocu-command-bar-action')).map((button) => ({
      refresh: button.classList.contains('ocu-command-bar-refresh-action'),
      label: button.textContent.trim(),
    })),
  }));
  assert.equal(offered.rowTriggers, 0, 'no row carries an action menu');
  assert.deepEqual(offered.barActions.map((action) => action.refresh), [true], `the command bar offers Refresh alone: ${JSON.stringify(offered.barActions)}`);

  await page.keyboard.down('Control');
  await page.keyboard.press('KeyK');
  await page.keyboard.up('Control');
  await page.waitForSelector('#ocu-command-box-list', { visible: true, timeout: config.navigationTimeoutMs });
  const boxActions = await page.$$eval('.ocu-command-box-group-actions [role="option"] .ocu-command-box-option-label', (nodes) =>
    nodes.map((node) => node.textContent.trim())
  );
  const refreshLabel = offered.barActions[0].label;
  assert.deepEqual(
    boxActions.filter((label) => label !== refreshLabel),
    [],
    `the command box offers no action but Refresh: ${JSON.stringify(boxActions)}`
  );
  await page.keyboard.press('Escape');
}

test('Story 6.5/6.6 AC1: the Tasks side bar reads Task schedule, On-demand tasks, Upcoming tasks, Task history, and each entry opens its screen', async () => {
  const { context, page } = await signedInAtList(config.username, config.password, ON_DEMAND_URL);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const wanted = [STRINGS.taskListLabel, STRINGS.taskOnDemandLabel, STRINGS.taskUpcomingLabel, STRINGS.taskHistoryLabel];
    const sideBar = await sideBarOf(page);
    assert.deepEqual(sideBar.entries, wanted, 'the four entries in their declared order');
    assert.deepEqual(sideBar.entries, ['Task schedule', 'On-demand tasks', 'Upcoming tasks', 'Task history']);
    const routes = ['/ocupilot/tasks/schedule', '/ocupilot/tasks/on-demand', '/ocupilot/tasks/upcoming', '/ocupilot/tasks/history'];
    for (let index = 0; index < wanted.length; index += 1) {
      await page.evaluate((label) => {
        const items = Array.from(document.querySelectorAll('app-side-bar .ocu-side-bar-item'));
        const item = items.find((candidate) => candidate.querySelector('.ocu-side-bar-label')?.textContent.trim() === label);
        item.click();
      }, wanted[index]);
      await page.waitForFunction((path) => location.pathname === path, { timeout: config.navigationTimeoutMs }, routes[index]);
      const opened = await sideBarOf(page);
      assert.equal(opened.current, wanted[index], `${wanted[index]} opens its own screen`);
    }
  } finally {
    await context.close();
  }
});

test('Story 6.5 AC2: On-demand tasks reads once under its headers, lists the demo task, and offers no action but Refresh', async () => {
  const { context, page, reads } = await signedInAtList(config.username, config.password, ON_DEMAND_URL);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const headers = await page.$$eval('.ocu-data-table-header-label', (labels) => labels.map((label) => label.textContent.trim()));
    assert.deepEqual(headers, [
      STRINGS.tableColumnName,
      STRINGS.headerNamespaceLabel,
      STRINGS.tableColumnType,
      STRINGS.tableColumnDescription,
      STRINGS.taskColumnLastRun,
    ]);
    assert.deepEqual(headers, ['Name', 'Namespace', 'Type', 'Description', 'Last run']);
    await filterToSubset(page, { text: 'nightly purge', expectRow: DEMO_TASK, total: await viewCount(page), timeoutMs: config.navigationTimeoutMs });
    assert.ok((await describeRow(page, DEMO_TASK)) !== null, `the ${DEMO_TASK} row is rendered`);
    assert.deepEqual(reads.map((url) => new URL(url).pathname), [ON_DEMAND_READ_PATH], 'exactly one tasks.ondemand read');
    await assertRefreshAlone(page);
  } finally {
    await context.close();
  }
});

test('Story 6.5 AC3: Upcoming tasks reads at 24 hours in ascending order, re-reads for the next hour, and reads to the end of a chosen date alone', async () => {
  const { context, page, reads, answers } = await signedInAtList(config.username, config.password, UPCOMING_URL);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    assert.equal(reads.length, 1, `one read on open: ${JSON.stringify(reads)}`);
    const opened = new URL(reads[0]);
    assert.equal(opened.pathname, UPCOMING_READ_PATH);
    assert.equal(opened.searchParams.get('hoursOffset'), '24', 'at 24 hours');
    assert.equal(opened.searchParams.has('toDatetime'), false, 'and no date');

    const [first] = await Promise.all(answers);
    assert.ok(Array.isArray(first.body?.rows), `the first read answers rows: ${JSON.stringify(first.body)}`);
    const datetimes = first.body.rows.map((row) => row.Datetime);
    const rendered = await page.$$eval(ROW_SELECTOR, (rows) => rows.map((row) => row.querySelector('[role="gridcell"]').textContent.trim()));
    assert.ok(rendered.length > 0, 'occurrences render');
    assert.deepEqual(rendered, [...rendered].sort(), `rows render in ascending Scheduled for: ${JSON.stringify(rendered)}`);
    assert.equal(rendered[0], [...datetimes].sort()[0], 'starting from the earliest occurrence the read answered');
    const atDay = await viewCount(page);

    await page.select('#ocu-upcoming-horizon', '1');
    const hour = await readMatching(reads, (url) => url.searchParams.get('hoursOffset') === '1');
    assert.equal(hour.searchParams.has('toDatetime'), false, 'the next hour sends no date');
    await page.waitForNetworkIdle({ timeout: config.navigationTimeoutMs });
    const hourAnswer = (await Promise.all(answers)).find((answer) => new URL(answer.url).searchParams.get('hoursOffset') === '1');
    assert.ok(Array.isArray(hourAnswer?.body?.rows), `the next hour's read answers rows: ${JSON.stringify(hourAnswer)}`);
    assert.notEqual(hourAnswer.body.rows.length, first.body.rows.length, 'the hour and day answers differ in size, so a table left at 24 hours is detectable');
    // An answer with no rows draws the empty state in place of the grid, which is a count of 0.
    const renderedCount = async () => ((await page.$('.ocu-data-table-empty')) !== null ? 0 : viewCount(page));
    await page
      .waitForFunction(
        (wanted) =>
          (wanted === 0 && document.querySelector('.ocu-data-table-empty') !== null) ||
          Number(document.querySelector('[role="grid"]')?.getAttribute('aria-rowcount')) - 1 === wanted,
        { timeout: config.navigationTimeoutMs },
        hourAnswer.body.rows.length
      )
      .catch(() => {});
    const atHour = await renderedCount();
    assert.equal(atHour, hourAnswer.body.rows.length, 'the table renders the next hour\'s answer');
    assert.ok(atHour <= atDay, `the next hour renders no more rows than 24 hours: ${atHour} against ${atDay}`);

    await page.select('#ocu-upcoming-horizon', 'date');
    const tomorrow = await page.evaluate(() => {
      const day = new Date();
      day.setDate(day.getDate() + 1);
      return `${day.getFullYear()}-${String(day.getMonth() + 1).padStart(2, '0')}-${String(day.getDate()).padStart(2, '0')}`;
    });
    await page.$eval(
      '#ocu-upcoming-date',
      (input, value) => {
        input.value = value;
        input.dispatchEvent(new Event('change', { bubbles: true }));
      },
      tomorrow
    );
    const dated = await readMatching(reads, (url) => url.searchParams.has('toDatetime'));
    assert.equal(dated.searchParams.get('toDatetime'), `${tomorrow} 23:59:59`, 'the end of tomorrow');
    assert.equal(dated.searchParams.has('hoursOffset'), false, 'and no hours');

    await assertRefreshAlone(page);
  } finally {
    await context.close();
  }
});

test('Story 6.5 AC4: a principal holding install-database read and %Admin_Task:USE alone is refused each deep link by name and issues no read', async () => {
  for (const [url, label] of [
    [ON_DEMAND_URL, STRINGS.taskOnDemandLabel],
    [UPCOMING_URL, STRINGS.taskUpcomingLabel],
  ]) {
    const { context, page, reads } = await signedInAtList(TASK_USER, TASK_PASSWORD, url);
    try {
      await page.waitForSelector('app-screen-denied .ocu-screen-denied-title', { timeout: config.navigationTimeoutMs });
      const denied = await page.evaluate(() => ({
        title: document.querySelector('app-screen-denied .ocu-screen-denied-title').textContent.trim(),
        reason: document.querySelector('app-screen-denied .ocu-screen-denied-reason').textContent.trim(),
        grid: document.querySelector('[role="grid"]') !== null,
      }));
      assert.equal(denied.title, label, `${label}: the deep link renders the screen title`);
      assert.equal(denied.reason, `You need %DB_IRISSYS:READ to open ${label}.`, `${label}: naming the pair`);
      assert.equal(denied.grid, false, `${label}: and no table`);
      assert.deepEqual(reads, [], `${label}: no screen read was issued`);
    } finally {
      await context.close();
    }
  }
});

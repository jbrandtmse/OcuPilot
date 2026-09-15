/**
 * The processes list in a real browser, against the throwaway instance: the declared read, table,
 * filter and max-rows cap end to end (AC1), the command bar's sort control and the choice surviving
 * a re-entry (AC2), one auto-refresh tick leaving sort, filter and selection alone (AC3), and the
 * column kinds a row paints with (AC4).
 *
 * **It changes nothing on the instance.** No principal, no task, no process: every leg signs in,
 * reads and looks. It never terminates, suspends, resumes or broadcasts to a process -- Epic 2 ships
 * no write path, and those controls are Stories 5.12, 7.8 and 16.6. The one `docker exec` here reads
 * the write daemon's pid through the same `Process` LIST the screen reads.
 *
 * AC5's denial -- a principal holding `%Admin_Operate:USE` and `%DB_IRISSYS:READ` but not
 * `%Admin_Manage:USE` -- is proven over HTTP by `OcuPilot.Test.WireSecurityRead`, which creates the
 * principals; this spec creates none.
 *
 * **Nothing here asserts that the row set survives a tick.** This is the first list whose rows
 * change with no write behind them: processes start and end, and a browser run drives CSP worker
 * and SQL query processes into and out of the very list it is reading. AC3 therefore asserts the
 * state slots and the status-bar stamp and deliberately not `after.names === before.names`, so a red
 * leg means "the tick reset a slot", never "a process ended". The selection is put on the write
 * daemon for the same reason: `WRTDMN` is started by IRIS at instance start and cannot exit while
 * the instance runs, so the selected row cannot legitimately vanish under `reconcile()`.
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
import { parseMarkers } from './iris-session.mjs';
import { ROW_SELECTOR, clearFilter, clickRowCentre, filterToSubset, viewCount, waitForRows } from './list-spec.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const LIST_URL = '/ocupilot/os-management/processes?ns=HSCUSTOM';
const READ_PATH = '/api/ocupilot/screens/osmgmt.processes/read';

/**
 * The write daemon's routine name. IRIS starts it before anything signs in and it runs for the
 * instance's life, so it is the one row this spec can name: its pid is read at `before` and its
 * `Username` and `Nspace` are empty, which is what makes the "(none)" cell observable.
 */
const DAEMON_ROUTINE = 'WRTDMN';

let browser = null;

/** The write daemon's pid on the throwaway, read once. It is the row every leg filters down to. */
let daemonPid = '';

/** The sort control's own parts, so a markup change is one edit. */
const SORT_TRIGGER = '.ocu-command-bar-sort-trigger';
const SORT_ITEM = '.ocu-command-bar-sort-item';

/** `Commands`' zero-based cell index in the seven declared columns -- the column AC2 sorts on. */
const COMMANDS_COLUMN = 5;

/**
 * Run ObjectScript lines in `iris session` inside the throwaway and return the value each named
 * marker carries (`parseMarkers`, `iris-session.mjs`). The same helper shape the users and tasks
 * specs use.
 */
function irisSession(lines, names) {
  const input = `${[...lines, 'Halt'].join('\n')}\n`;
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', 'HSCUSTOM'], {
    input,
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  return { values: parseMarkers(output, names), output };
}

/**
 * The write daemon's pid, read through the very endpoint the screen reads.
 *
 * Asking `AdminPort` rather than `%SYS.ProcessQuery` is deliberate: the pid this returns is the pid
 * that will be in the rendered list, so a leg that then cannot find it has found a real difference
 * rather than two sources disagreeing about which processes exist.
 */
function readDaemonPid() {
  const { values, output } = irisSession(
    [
      'Kill tQuery Set tSC=##class(OcuPilot.Port.AdminPort).Invoke("Process","LIST",.tQuery,"",.tRows,.tHttp,.tFault)',
      'Set tPid=""',
      `Set tIt=tRows.%GetIterator() While tIt.%GetNext(.tI,.tRow) { If tRow.Routine="${DAEMON_ROUTINE}" { Set tPid=tRow.Pid Quit } }`,
      'Write "OCU"_"-PID-START:"_tPid_":OCU"_"-PID-END",!',
    ],
    ['PID']
  );
  assert.ok(
    values.PID !== null && values.PID !== '',
    `the throwaway's Process LIST must carry a ${DAEMON_ROUTINE} row to read a pid from; transcript:\n${output}`
  );
  return values.PID;
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs docker commands, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  daemonPid = readDaemonPid();
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
});

/** A fresh context signed in through the shell's own form at the list's deep link, reads counted. */
async function signedInAtList(user, password) {
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  const reads = [];
  page.on('request', (request) => {
    if (new URL(request.url()).pathname.startsWith('/api/ocupilot/screens/')) reads.push(request.url());
  });
  await page.goto(`${config.origin}${LIST_URL}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', user);
  await page.type('#ocu-signin-password', password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  return { context, page, reads };
}

/** The rendered row whose Process ID cell reads `pid`, described cell by cell. */
function describeRow(page, pid) {
  return page.evaluate((wanted, rowSelector) => {
    const style = (element) => (element === null ? null : getComputedStyle(element));
    const root = getComputedStyle(document.documentElement);
    const rows = Array.from(document.querySelectorAll(rowSelector));
    const row = rows.find((candidate) => candidate.querySelector('[role="gridcell"]').textContent.trim() === wanted);
    if (row === undefined) return null;
    const cells = Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => {
      const text = cell.querySelector('.ocu-data-table-link, .ocu-data-table-text');
      const computed = style(text);
      // `font-variant-numeric` and `text-align` are the CELL's, set by
      // `.ocu-data-table-cell-numeric`; the face is the text span's.
      const cellStyle = getComputedStyle(cell);
      return {
        text: cell.textContent.trim(),
        family: computed === null ? null : computed.fontFamily.replace(/["']/g, ''),
        numericVariant: cellStyle.fontVariantNumeric,
        align: cellStyle.textAlign,
        link: cell.querySelector('.ocu-data-table-link') !== null,
        numericCell: cell.classList.contains('ocu-data-table-cell-numeric'),
        code: text !== null && text.classList.contains('ocu-data-table-code'),
        emptyValue: text !== null && text.classList.contains('ocu-data-table-empty-value'),
      };
    });
    return {
      cells,
      code: root.getPropertyValue('--ocu-type-code-family').trim().replace(/["']/g, ''),
      body: root.getPropertyValue('--ocu-type-body-family').trim().replace(/["']/g, ''),
    };
  }, pid, ROW_SELECTOR);
}

/**
 * The whole view's sort state: each header's `aria-sort`, its arrow, and the rendered rows' values
 * in one column.
 *
 * `column` is the zero-based cell index whose values are collected, so a leg can ask for the
 * column it just sorted on and check the order the rows actually came out in rather than trusting
 * `aria-sort` to stand for it. The values are read from the single rendered snapshot, so a process
 * starting or ending between two reads cannot make the comparison wrong.
 */
function describeSort(page, column = 0) {
  return page.evaluate((rowSelector, index) => ({
    sorts: Array.from(document.querySelectorAll('[role="columnheader"]')).map((cell) => cell.getAttribute('aria-sort')),
    arrows: Array.from(document.querySelectorAll('.ocu-data-table-sort-arrow')).map((span) => span.textContent.trim()),
    values: Array.from(document.querySelectorAll(rowSelector)).map((row) =>
      row.querySelectorAll('[role="gridcell"]')[index].textContent.trim()
    ),
  }), ROW_SELECTOR, column);
}

/**
 * Assert the rendered values run in `direction`, and that there were enough of them for the
 * question to mean anything. `Commands` is a `number` column, so the comparison is numeric --
 * which is the difference the shared view's compare makes and lexicographic order would not.
 */
function assertOrdered(values, direction, what) {
  assert.ok(values.length >= 2, `${what}: at least two rows are rendered to order, got ${values.length}`);
  const numbers = values.map((value) => Number(value));
  assert.ok(
    numbers.every((value) => Number.isFinite(value)),
    `${what}: every rendered value in the sorted column is a number: ${JSON.stringify(values)}`
  );
  for (let at = 1; at < numbers.length; at += 1) {
    const ordered = direction === 'asc' ? numbers[at - 1] <= numbers[at] : numbers[at - 1] >= numbers[at];
    assert.ok(ordered, `${what}: ${numbers[at - 1]} then ${numbers[at]} is not ${direction}ending: ${JSON.stringify(numbers)}`);
  }
}

/** Open the sort menu and choose the entry whose label is `label`. */
async function chooseSort(page, label) {
  await page.click(SORT_TRIGGER);
  await page.waitForSelector(SORT_ITEM, { timeout: config.navigationTimeoutMs });
  const chosen = await page.evaluate(
    (selector, wanted) => {
      const item = Array.from(document.querySelectorAll(selector)).find(
        (candidate) => candidate.textContent.trim() === wanted
      );
      if (item === undefined) {
        return Array.from(document.querySelectorAll(selector)).map((candidate) => candidate.textContent.trim());
      }
      item.click();
      return null;
    },
    SORT_ITEM,
    label
  );
  assert.equal(chosen, null, `the sort menu offers ${JSON.stringify(label)}; it offered ${JSON.stringify(chosen)}`);
  await page.waitForFunction((selector) => document.querySelector(selector) === null, {}, SORT_ITEM);
}

test('AC1: the list reads once under the declared headers, filters to a proper subset, and re-reads at a new max-rows cap', async () => {
  const { context, page, reads } = await signedInAtList(config.username, config.password);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const headers = await page.$$eval('.ocu-data-table-header-label', (labels) => labels.map((label) => label.textContent.trim()));
    assert.deepEqual(headers, [
      STRINGS.processColumnPid,
      STRINGS.processColumnUser,
      STRINGS.headerNamespaceLabel,
      STRINGS.processColumnRoutine,
      STRINGS.processColumnState,
      STRINGS.processColumnCommands,
      STRINGS.processColumnGlobals,
    ]);
    assert.deepEqual(headers, ['Process ID', 'User', 'Namespace', 'Routine', 'State', 'Commands', 'Globals']);

    // At least the cap: with fewer the "exactly five rows at maxRows=5" assertion below would
    // collapse into `min(5, total)` against a count read from an earlier fetch, which a process
    // starting or ending in between could make wrong.
    const total = await viewCount(page);
    assert.ok(total >= 5, `the instance lists at least the cap's worth of processes: ${total}`);

    assert.equal(reads.length, 1, `exactly one screen read was issued: ${JSON.stringify(reads)}`);
    assert.equal(new URL(reads[0]).pathname, READ_PATH);

    // Two legs through two different declared filter fields -- Routine, then the pid itself -- each
    // from the whole list and each required to leave a proper, non-empty subset (DW-267).
    const leg = { total, expectRow: daemonPid, timeoutMs: config.navigationTimeoutMs };
    const byRoutine = await filterToSubset(page, { ...leg, text: DAEMON_ROUTINE });
    assert.ok(byRoutine < total, `the routine filter narrows the list: ${byRoutine} of ${total}`);
    const byPid = await filterToSubset(page, { ...leg, text: daemonPid });
    assert.ok(byPid <= byRoutine, `and the pid narrows at least as far: ${byPid} of ${byRoutine}`);

    // The footer's cap is editable and the screen re-reads at it. The read is counted in this
    // process from the page's own request events, so the wait needs nothing of the page.
    //
    // The filter is emptied first, and the view is back to `total`, before the cap is touched:
    // `filterToSubset` leaves its text in the field, and a view the pid filter has already narrowed
    // to one row satisfies any "at most five" bound whatever the cap does.
    await clearFilter(page, total, config.navigationTimeoutMs);
    const readsBefore = reads.length;
    await page.click('.ocu-data-table-max-rows', { clickCount: 3 });
    await page.keyboard.press('Backspace');
    await page.type('.ocu-data-table-max-rows', '5');
    await page.keyboard.press('Enter');
    const deadline = Date.now() + config.navigationTimeoutMs;
    while (reads.length <= readsBefore && Date.now() < deadline) {
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
    assert.ok(reads.length > readsBefore, `committing the cap issued a further read: ${JSON.stringify(reads)}`);
    assert.equal(
      new URL(reads[reads.length - 1]).searchParams.get('maxRows'),
      '5',
      'at the cap the field now holds'
    );
    // Exactly the cap, not merely "no more than" it: the matrix row's claim is that the port
    // answers five rows for maxRows=5, and the leg above has established there are more than five
    // to choose from.
    await page.waitForFunction(
      () => {
        const grid = document.querySelector('[role="grid"]');
        return grid !== null && Number(grid.getAttribute('aria-rowcount')) - 1 === 5;
      },
      { timeout: config.navigationTimeoutMs }
    );
    assert.equal(await viewCount(page), 5, `the view holds exactly the cap, of ${total} processes`);
  } finally {
    await context.close();
  }
});

test('AC2: the command bar sorts the table by a chosen field, the header announces it, and the choice survives leaving and re-entering', async () => {
  const { context, page } = await signedInAtList(config.username, config.password);
  try {
    await waitForRows(page, config.navigationTimeoutMs);

    // The declared default is Pid ascending, and it is the header's own readout.
    const first = await describeSort(page);
    assert.deepEqual(
      first.sorts,
      ['ascending', null, null, null, null, null, null],
      'the declared default sorts on Process ID, and nothing else claims a sort'
    );
    assert.deepEqual(first.arrows.filter((arrow) => arrow !== ''), ['\u2191'], 'one up arrow, on that column');

    // A field other than the default, chosen through the control the story ships. Commands is a
    // `number` column, so this is also the first sort any screen has run on a numeric field.
    await chooseSort(page, STRINGS.processColumnCommands);
    await page.waitForFunction(
      () =>
        Array.from(document.querySelectorAll('[role="columnheader"]')).map((cell) => cell.getAttribute('aria-sort'))[5] ===
        'ascending',
      { timeout: config.navigationTimeoutMs }
    );
    const sorted = await describeSort(page, COMMANDS_COLUMN);
    assert.deepEqual(
      sorted.sorts,
      [null, null, null, null, null, 'ascending', null],
      'the chosen column carries aria-sort, and the previous one has let it go'
    );
    // And the rows are in that order, which is the half of AC2 `aria-sort` cannot stand for: a
    // header can announce a sort the view never applied.
    assertOrdered(sorted.values, 'asc', 'sorted by Commands ascending');

    // Leaving and re-entering the screen: the store is keyed by descriptor and outlives the route.
    await page.goto(`${config.origin}/ocupilot/tasks/schedule?ns=HSCUSTOM`, { waitUntil: 'networkidle2' });
    await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
    await page.goto(`${config.origin}${LIST_URL}`, { waitUntil: 'networkidle2' });
    await waitForRows(page, config.navigationTimeoutMs);
    assert.deepEqual(
      (await describeSort(page)).sorts,
      [null, null, null, null, null, 'ascending', null],
      'the chosen sort is still in force after the re-entry'
    );

    // And after a reload, which throws every store away and rebuilds it from `preferences` -- the
    // half of "persists per screen" that a live store could satisfy on its own.
    await page.reload({ waitUntil: 'networkidle2' });
    await waitForRows(page, config.navigationTimeoutMs);
    assert.deepEqual(
      (await describeSort(page)).sorts,
      [null, null, null, null, null, 'ascending', null],
      'and it is restored from the remembered view after a reload'
    );

    // The direction is the control's too, and it moves the same readout.
    await chooseSort(page, STRINGS.sortDirectionDescending);
    await page.waitForFunction(
      () =>
        Array.from(document.querySelectorAll('[role="columnheader"]')).map((cell) => cell.getAttribute('aria-sort'))[5] ===
        'descending',
      { timeout: config.navigationTimeoutMs }
    );
    const descending = await describeSort(page, COMMANDS_COLUMN);
    assert.deepEqual(descending.arrows.filter((arrow) => arrow !== ''), ['\u2193'], 'the arrow turns with it');
    assertOrdered(descending.values, 'desc', 'sorted by Commands descending');
  } finally {
    await context.close();
  }
});

test('AC3: an auto-refresh tick re-reads the rows in place, keeping a non-default sort, the filter and the selection, with no skeleton', async () => {
  const { context, page, reads } = await signedInAtList(config.username, config.password);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const total = await viewCount(page);

    // A non-default sort -- which is what this story's control makes possible, and what makes
    // "the sort survived the tick" falsifiable rather than a comparison of two defaults.
    await chooseSort(page, STRINGS.processColumnGlobals);
    await chooseSort(page, STRINGS.sortDirectionDescending);
    // A filter down to the write daemon, so the selected row cannot legitimately vanish.
    await filterToSubset(page, {
      text: DAEMON_ROUTINE,
      expectRow: daemonPid,
      total,
      timeoutMs: config.navigationTimeoutMs,
    });
    // A real hit-tested pointer click at the cell's own centre (DW-273). The fourth cell carries no
    // link, so the click selects the row rather than opening one, and `clickRowCentre` fails first
    // if the point at that centre resolves outside the row.
    await clickRowCentre(page, { index: 0, cell: 4 });
    await page.waitForSelector('[role="row"][aria-selected="true"]', { timeout: config.navigationTimeoutMs });

    const before = await page.evaluate(() => ({
      sorts: Array.from(document.querySelectorAll('[role="columnheader"]')).map((cell) => cell.getAttribute('aria-sort')),
      filter: document.querySelector('#ocu-command-bar-filter').value,
      selected: document.querySelector('.ocu-data-table-row-selected [role="gridcell"]')?.textContent?.trim() ?? null,
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
    }));
    assert.deepEqual(
      before.sorts,
      [null, null, null, null, null, null, 'descending'],
      'the sort under test is off the declared default in both field and direction'
    );
    assert.equal(before.filter, DAEMON_ROUTINE, 'and the filter under test is a real one');
    assert.equal(before.selected, daemonPid, 'and the selected row is the write daemon, which cannot exit');
    assert.equal(before.announced, false, 'the auto-refresh stamp is in no live region, so a tick is never announced');

    // The chip's first advance from off is the descriptor's lowest declared rate, 5 s.
    const chip = await page.$('.ocu-command-bar-refresh');
    assert.ok(chip !== null, 'the command bar carries the auto-refresh chip, which only a refreshing screen renders');
    assert.equal(
      await page.$eval('.ocu-command-bar-refresh', (button) => button.textContent.trim()),
      'Auto-refresh: off',
      'reading off before it is set'
    );
    const readsBefore = reads.length;
    await chip.click();
    await page.waitForFunction(
      () => document.querySelector('.ocu-command-bar-refresh').textContent.trim() === 'Auto-refresh: every 5 s',
      { timeout: config.navigationTimeoutMs }
    );

    const deadline = Date.now() + config.navigationTimeoutMs;
    while (reads.length <= readsBefore && Date.now() < deadline) {
      await new Promise((resolve) => setTimeout(resolve, 250));
    }
    assert.ok(reads.length > readsBefore, `the tick issued a further read within the timeout: ${reads.length} against ${readsBefore}`);
    for (const url of reads) assert.equal(new URL(url).pathname, READ_PATH, "and every read is the screen's own");

    // A read that has been *issued* is not a tick that has *landed*: the request event fires before
    // the answer arrives, and `applyTick` is what writes the rows and the stamp. Waiting for the
    // stamp -- the one thing the tick is allowed to move -- is what makes the snapshot below a
    // picture of the state after the tick rather than during it.
    assert.notEqual(before.stamp, '', `the stamp stood before the tick: ${JSON.stringify(before.stamp)}`);
    await page.waitForFunction(
      (was) => (document.querySelector('.ocu-status-bar-stamp')?.textContent?.trim() ?? '') !== was,
      { timeout: config.navigationTimeoutMs },
      before.stamp
    );

    const after = await page.evaluate(() => ({
      sorts: Array.from(document.querySelectorAll('[role="columnheader"]')).map((cell) => cell.getAttribute('aria-sort')),
      filter: document.querySelector('#ocu-command-bar-filter').value,
      selected: document.querySelector('.ocu-data-table-row-selected [role="gridcell"]')?.textContent?.trim() ?? null,
      stamp: document.querySelector('.ocu-status-bar-stamp')?.textContent?.trim() ?? '',
      skeleton: document.querySelector('.ocu-data-table-skeleton') !== null,
      busy: document.querySelector('[aria-busy="true"]') !== null,
    }));

    // Deliberately NOT the row set: processes start and end with no write behind them, and a
    // browser run drives worker processes into and out of this very list. See the header.
    assert.deepEqual(after.sorts, before.sorts, 'the sort survives the tick');
    assert.equal(after.filter, before.filter, 'and the filter');
    assert.equal(after.selected, before.selected, 'and the selected row');
    assert.equal(after.skeleton, false, 'no skeleton is shown on a re-fetch');
    assert.equal(after.busy, false, 'and nothing is marked busy');
    assert.notEqual(after.stamp, before.stamp, `the tick moved the stamp: ${JSON.stringify(before.stamp)} -> ${JSON.stringify(after.stamp)}`);
  } finally {
    await context.close();
  }
});

test('AC4: a row paints its Process ID and Routine in the code face, its two counters tabular and right-aligned, and never an empty cell', async () => {
  const { context, page } = await signedInAtList(config.username, config.password);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const total = await viewCount(page);
    await filterToSubset(page, {
      text: DAEMON_ROUTINE,
      expectRow: daemonPid,
      total,
      timeoutMs: config.navigationTimeoutMs,
    });

    const row = await describeRow(page, daemonPid);
    assert.ok(row !== null, `the ${daemonPid} row is rendered`);
    const [pid, user, nspace, routine, state, commands, globals] = row.cells;

    // `name`: the code face and the link Story 6.8's process details will answer.
    assert.equal(pid.text, daemonPid);
    assert.equal(pid.link, true, 'the Process ID cell is a link');
    assert.equal(pid.family, row.code, 'in the code face');

    // `identifier`: the code face, no link.
    assert.equal(routine.text, DAEMON_ROUTINE);
    assert.equal(routine.link, false, 'the Routine cell is not a link');
    assert.equal(routine.code, true, 'and carries the code class');
    assert.equal(routine.family, row.code, 'so it paints in the code face');

    // `number`: tabular and right-aligned, the first production use of the kind.
    for (const [name, cell] of [['Commands', commands], ['Globals', globals]]) {
      assert.equal(cell.numericCell, true, `the ${name} cell is numeric`);
      assert.equal(cell.align, 'right', `${name} is right-aligned`);
      assert.ok(
        cell.numericVariant.includes('tabular-nums'),
        `${name} is set in tabular figures: ${JSON.stringify(cell.numericVariant)}`
      );
    }

    // `text`: the body face, and the write daemon runs as no user in no namespace, so both cells
    // read the empty-value word rather than painting blank.
    assert.equal(state.family, row.body, 'the State cell is body type');
    for (const [name, cell] of [['User', user], ['Namespace', nspace]]) {
      assert.equal(cell.text, STRINGS.tableEmptyValue, `the write daemon's ${name} cell reads the empty-value word`);
      assert.equal(cell.emptyValue, true, `and carries the empty-value class, so it is styled as absent`);
      assert.equal(cell.family, row.body, 'in body type');
    }

    // No cell anywhere in the view renders blank, whatever the instance answered for it -- so the
    // filter comes off first, or the sweep would only ever see the one row it was narrowed to.
    await clearFilter(page, total, config.navigationTimeoutMs);
    const blanks = await page.$$eval(ROW_SELECTOR, (rows) =>
      rows.flatMap((element) =>
        Array.from(element.querySelectorAll('[role="gridcell"]'))
          .map((cell, index) => ({ index, text: cell.textContent.trim() }))
          .filter((cell) => cell.text === '')
      )
    );
    assert.deepEqual(blanks, [], `every rendered cell carries a word: ${JSON.stringify(blanks)}`);
  } finally {
    await context.close();
  }
});

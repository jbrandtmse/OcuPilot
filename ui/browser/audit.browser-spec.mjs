/**
 * The audit database viewer in a real browser, against the throwaway instance: the criteria form
 * that renders nothing until Search (AC1), the agent-marker filter that narrows to a proper subset
 * (AC2), the detail dialog a row opens (AC3), the screen's own empty sentence (AC4), the off-list
 * authentication refusal (AC7), and the one thousand-row NFR-1 measurement DW-258 asks for (AC6).
 * The "AC1 regression" leg re-drives the story's own HIGH review finding -- a stuck skeleton on
 * return to the screen -- through the shell's real SPA navigation rather than a stub.
 *
 * **It writes audit rows, and it may only ever do that here.** `before()` registers one event triple
 * under a Source of its own -- deliberately not OcuPilot's, so AC2's marker subset stays a *proper*
 * one -- and tops the population under it up to a thousand. Both are refused against the live
 * container by the `LIVE_CONTAINER` assertion the other `docker exec` specs carry, and there is no
 * teardown: audit rows cannot be deleted individually, so the cleanup is the throwaway's own
 * (`ci-throwaway.sh down` runs `docker compose down -v`). Saying so is the honest version; a purge
 * step that did nothing would be worse than none -- and it is why the seed tops up rather than
 * adds, so a second run against the same throwaway leaves the counts where the first did.
 *
 * AC5's denial -- a principal holding `%Admin_Secure:USE` and `%DB_IRISSYS:READ` but not
 * `%Admin_Operate:USE` -- is proven over HTTP by `OcuPilot.Test.WireSecurityRead`, which creates the
 * principals; this spec creates none.
 *
 * **A row is opened with a real hit-tested pointer click** (`clickRowCentre`, DW-273). It used to
 * be a synthetic `dispatchEvent`, because the routed outlet had collapsed the table frame to its
 * header's height and the footer painted over the rows -- which is exactly what a synthetic click
 * hid. Story 2.13 gave the outlet a height and the helper now measures the point before clicking it.
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
import { ROW_SELECTOR, clickRowCentre, viewCount, waitForRows } from './list-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const LIST_URL = '/ocupilot/logs/audit?ns=HSCUSTOM';
const READ_PATH = '/api/ocupilot/screens/logs.audit/read';

/** The marker filter's own Source: OcuPilot's, which the installer registers and emits under. */
const MARKER_SOURCE = 'OcuPilot';

/**
 * The seed's event triple. Its Source is **not** OcuPilot's, which is what keeps AC2's marker
 * subset proper: with a thousand rows under another Source, the marker filter has something to
 * narrow away from.
 */
const SEED_SOURCE = 'OcuPilotSeed';
const SEED_TYPE = 'Test';
const SEED_NAME = 'SeededRow';

/** The rows the seed writes. AC6 caps the search at this figure, so the population can fill it. */
const SEED_ROWS = 1000;

/**
 * The triple the marker population is topped up under -- OcuPilot's own Source, its own Type, and
 * a roster name the installer registers -- and how many rows it is brought to.
 *
 * **DW-1174 is about this population being large.** AC2 used to bound itself with the instance's
 * whole `OcuPilot`-source count, which is fine on a container whose only rows are the installer's
 * handful and hopeless on a long-lived one. The leg is rescoped to a `beginDateTime` window, and
 * the population is seeded here so the rescoping is exercised rather than asserted: with a
 * thousand rows under the marker's own Source, a whole-population bound is what times out.
 */
const MARKER_TYPE = 'Security';
const MARKER_BULK_NAME = 'ConfigChange';
const MARKER_BULK_ROWS = 1000;

/** The rows AC2 writes inside its own window: enough to be a proper non-empty subset of the pair. */
const WINDOW_MARKER_ROWS = 3;
const WINDOW_SEED_ROWS = 5;

/** NFR-1's budget, applied to the Search press rather than to navigation (see the spec's notes). */
const FIRST_ROW_BUDGET_MS = 2000;

/**
 * How long the AC6 leg waits for the first row, which is deliberately **longer** than the budget it
 * asserts: a wait that timed out at the budget would make the budget assertion unreachable, and a
 * breach would surface as a puppeteer selector timeout instead of the measured figure.
 */
const FIRST_ROW_WAIT_MS = FIRST_ROW_BUDGET_MS * 5;

/** The criteria form's own parts, so a markup change is one edit. */
const SEARCH_BUTTON = '.ocu-criteria-controls button[type="submit"]';
const MARKER_BOX = '[data-ocu-marker="filter"]';
const SOURCE_FIELD = '#ocu-audit-criterion-eventSources';
const AUTH_FIELD = '#ocu-audit-criterion-authentication';

let browser = null;

/**
 * Run ObjectScript lines in `iris session` inside the throwaway and return the value each named
 * marker carries (`parseMarkers`, `iris-session.mjs`). The same helper shape the users, tasks and
 * processes specs use.
 */
function irisSession(lines, names, namespace = 'HSCUSTOM') {
  const input = `${[...lines, 'Halt'].join('\n')}\n`;
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', namespace], {
    input,
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  return { values: parseMarkers(output, names), output };
}

/**
 * Register the seed's event triple and bring the population under it up to `SEED_ROWS`, then read
 * the count back.
 *
 * **It tops up rather than adds.** Audit rows cannot be deleted individually, so a `before()` that
 * emitted a thousand every time would leave four thousand after four runs against the same
 * throwaway and every count this spec compares would drift with the number of times it had been
 * run.
 *
 * The count is read back rather than assumed because `$System.Security.Audit` **silently returns 0
 * and drops the event** when the Source/Type/Name triple was not registered -- there is no error and
 * no log entry -- so a run that registered nothing would seed nothing and AC6 would measure eleven
 * rows while claiming a thousand.
 *
 * **DW-302: the count is polled until it stops rising, not read once.** `$System.Security.Audit`'s
 * write is not visible to an immediate `SELECT COUNT(*)` on a throwaway whose `${SEED_SOURCE}`
 * population starts at zero -- measured twice, both times on the first run after a throwaway
 * recreation: 1000 rows written (`WRITTEN` equalled `WANTED`), a same-session re-count read 822. A
 * container that already holds the rows only tops up a handful, so the same race is invisible
 * there, which is why a bare re-run always passed. The loop below re-runs the same `COUNT(*)` up
 * to twenty times, half a second apart, and stops once two consecutive reads agree and the total
 * has reached what was just written -- "settled", not "waited a fixed guess" -- so a slower flush
 * still passes and a genuine shortfall still fails, naming the count it actually settled on.
 */
function seedAuditRows() {
  const { values, output } = irisSession(
    [
      `If '##class(Security.Events).Exists("${SEED_SOURCE}","${SEED_TYPE}","${SEED_NAME}",.tE,.tES) { Do ##class(Security.Events).Create("${SEED_SOURCE}","${SEED_TYPE}","${SEED_NAME}","OcuPilot browser-spec seed",1,0) }`,
      `Set tRs=##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) FROM %SYS.Audit_List(,,?)","${SEED_SOURCE}")`,
      'Set tHeld=0 If tRs.%Next() { Set tHeld=tRs.%GetData(1) }',
      `Set tWanted=${SEED_ROWS}-tHeld Set:tWanted<0 tWanted=0`,
      `Set tWritten=0 For tI=1:1:tWanted { Set tOk=$System.Security.Audit("${SEED_SOURCE}","${SEED_TYPE}","${SEED_NAME}","seeded row "_tI,"row="_tI) Set:tOk tWritten=tWritten+1 }`,
      'Write "OCU"_"-WANTED-START:"_tWanted_":OCU"_"-WANTED-END",!',
      'Write "OCU"_"-WRITTEN-START:"_tWritten_":OCU"_"-WRITTEN-END",!',
      `Set tCount=-1 Set tPrev=-2 For tTry=1:1:20 { Set tRs2=##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) FROM %SYS.Audit_List(,,?)","${SEED_SOURCE}") Set tCount=-1 If tRs2.%Next() { Set tCount=tRs2.%GetData(1) } Quit:(tCount=tPrev)&&(tCount>=(tHeld+tWritten))  Set tPrev=tCount Hang 0.5 }`,
      'Write "OCU"_"-COUNT-START:"_tCount_":OCU"_"-COUNT-END",!',
    ],
    ['WANTED', 'WRITTEN', 'COUNT'],
    '%SYS'
  );
  assert.equal(
    values.WRITTEN,
    values.WANTED,
    `every row the top-up asked for must be written -- $System.Security.Audit drops an unregistered triple silently; transcript:\n${output}`
  );
  const seeded = Number(values.COUNT);
  assert.ok(
    Number.isFinite(seeded) && seeded >= SEED_ROWS,
    `the audit database must hold at least ${SEED_ROWS} ${SEED_SOURCE} rows after seeding, read ${values.COUNT}; transcript:\n${output}`
  );
  return seeded;
}

/**
 * How many rows the instance holds under `source`, read back through the vendor's own audit query.
 *
 * `%SYS.Audit` projects no ordinary table -- `%SYS_Audit.Audit` does not exist -- so the count comes
 * from the same class query the endpoint runs, called as a SQL table-valued function with its
 * `EventSources` argument. A count of `-1` therefore means the query itself did not run, which the
 * caller's own assertion names rather than reading as "no rows".
 */
function auditRowCount(source) {
  const { values, output } = irisSession(
    [
      `Set tRs=##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) FROM %SYS.Audit_List(,,?)","${source}")`,
      'Set tCount=-1 If tRs.%Next() { Set tCount=tRs.%GetData(1) }',
      'Write "OCU"_"-COUNT-START:"_tCount_":OCU"_"-COUNT-END",!',
    ],
    ['COUNT'],
    '%SYS'
  );
  const count = Number(values.COUNT);
  assert.ok(
    Number.isFinite(count) && count >= 0,
    `the audit row count for ${source} must read back, got ${values.COUNT}; transcript:\n${output}`
  );
  return count;
}

/** How many rows the instance holds under the marker's Source. */
function markerRowCount() {
  const count = auditRowCount(MARKER_SOURCE);
  assert.ok(
    count > 0,
    `the installer's own ${MARKER_SOURCE} audit rows must exist for the marker filter to find, read ${count}`
  );
  return count;
}

/**
 * Bring the population under the **marker's own** Source up to `MARKER_BULK_ROWS`, so the instance
 * this spec runs against is the long-lived one DW-1174 is about.
 *
 * It writes under a roster triple the installer already registered, so the rows are the same kind
 * of row the product writes; an unregistered triple would be dropped silently, which is what the
 * `WRITTEN` assertion catches.
 */
function seedMarkerBulk() {
  const { values, output } = irisSession(
    [
      `Set tRs=##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) FROM %SYS.Audit_List(,,?)","${MARKER_SOURCE}")`,
      'Set tHeld=0 If tRs.%Next() { Set tHeld=tRs.%GetData(1) }',
      `Set tWanted=${MARKER_BULK_ROWS}-tHeld Set:tWanted<0 tWanted=0`,
      `Set tWritten=0 For tI=1:1:tWanted { Set tOk=$System.Security.Audit("${MARKER_SOURCE}","${MARKER_TYPE}","${MARKER_BULK_NAME}","bulk marker row "_tI,"bulk="_tI) Set:tOk tWritten=tWritten+1 }`,
      'Write "OCU"_"-WANTED-START:"_tWanted_":OCU"_"-WANTED-END",!',
      'Write "OCU"_"-WRITTEN-START:"_tWritten_":OCU"_"-WRITTEN-END",!',
    ],
    ['WANTED', 'WRITTEN'],
    '%SYS'
  );
  assert.equal(
    values.WRITTEN,
    values.WANTED,
    `every bulk marker row must be written -- an unregistered triple is dropped silently; transcript:\n${output}`
  );
}

/**
 * The instance's own local clock, in the `YYYY-MM-DD HH:MM:SS` spelling the `beginDateTime`
 * criterion publishes (`STRINGS.auditCriteriaTimeHint`).
 *
 * Read from the **instance**, never from this process: the criterion is instance local time, and a
 * container in another zone would make a Node-side clock silently select the wrong window.
 */
function instanceStamp() {
  const { values, output } = irisSession(
    ['Write "OCU"_"-STAMP-START:"_$ZDateTime($Horolog,3)_":OCU"_"-STAMP-END",!'],
    ['STAMP'],
    '%SYS'
  );
  assert.match(
    values.STAMP ?? '',
    /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/,
    `the instance's own local clock must read back as the criterion spells it; transcript:\n${output}`
  );
  return values.STAMP;
}

/**
 * Write `markers` rows under the marker's own Source and `seeds` under the seed's, all inside the
 * window a `beginDateTime` taken a moment earlier opens.
 *
 * Every row is asserted written, because `$System.Security.Audit` drops an unregistered triple
 * with no error -- a seeding step that quietly wrote nothing would make the counts below read as a
 * filter that narrowed to zero.
 */
function seedWindowRows(markers, seeds) {
  const { values, output } = irisSession(
    [
      `Set tM=0 For tI=1:1:${markers} { Set tOk=$System.Security.Audit("${MARKER_SOURCE}","${MARKER_TYPE}","${MARKER_BULK_NAME}","window marker "_tI,"window="_tI) Set:tOk tM=tM+1 }`,
      `Set tS=0 For tI=1:1:${seeds} { Set tOk=$System.Security.Audit("${SEED_SOURCE}","${SEED_TYPE}","${SEED_NAME}","window seed "_tI,"window="_tI) Set:tOk tS=tS+1 }`,
      'Write "OCU"_"-MARKERS-START:"_tM_":OCU"_"-MARKERS-END",!',
      'Write "OCU"_"-SEEDS-START:"_tS_":OCU"_"-SEEDS-END",!',
    ],
    ['MARKERS', 'SEEDS'],
    '%SYS'
  );
  assert.equal(values.MARKERS, String(markers), `every window marker row is written; transcript:\n${output}`);
  assert.equal(values.SEEDS, String(seeds), `every window seed row is written; transcript:\n${output}`);
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec writes audit rows, so it never runs against the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  seedAuditRows();
  seedMarkerBulk();
  markerRowCount();
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
});

/** A fresh context signed in through the shell's own form at the screen's deep link, reads counted. */
async function signedInAtScreen() {
  // Story 15.5: the remembered screen and shell state lives on the instance now, keyed by the
  // one account every spec signs in as, so a fresh context is no longer a fresh slate on its
  // own -- see `preferences-reset.mjs`.
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  const reads = [];
  page.on('request', (request) => {
    if (new URL(request.url()).pathname.startsWith('/api/ocupilot/screens/')) reads.push(request.url());
  });
  await page.goto(`${config.origin}${LIST_URL}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', config.username);
  await page.type('#ocu-signin-password', config.password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  // The first-login gate takes an administrator to the Definition form on an instance with no
  // enabled definition, whatever URL was asked for (Story 3.6). Back returns to this one.
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, LIST_URL);
  await page.waitForSelector('.ocu-criteria-form', { timeout: config.navigationTimeoutMs });
  return { context, page, reads };
}

/** Type `value` into the criterion control `selector` names, replacing whatever it holds. */
async function typeCriterion(page, selector, value) {
  await page.click(selector, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  if (value !== '') await page.type(selector, value);
}

/**
 * Press Search and wait until the read it issued has landed -- either as rows or as the empty
 * state, both of which mean the answer rendered.
 */
async function search(page, reads) {
  const before = reads.length;
  await page.click(SEARCH_BUTTON);
  await page.waitForFunction(
    () => document.querySelector('[role="grid"] .ocu-data-table-body [role="row"]') !== null
      || document.querySelector('.ocu-data-table-empty') !== null,
    { timeout: config.navigationTimeoutMs }
  );
  assert.ok(reads.length > before, 'the Search press issued a read');
}

/**
 * Wait until the view's row count falls inside `[min, max]`, naming what was wanted and what was
 * there when it does not -- `waitForFunction`'s own timeout says neither.
 *
 * The bounds are numbers rather than a predicate on purpose: a closure serialized into the page
 * loses whatever it closed over, and `waitForFunction` would then evaluate a broken body until it
 * timed out -- which reads as "the count never converged" rather than as the bug it is.
 */
async function waitForCount(page, { min, max }, wanted) {
  try {
    await page.waitForFunction(
      (low, high) => {
        const grid = document.querySelector('[role="grid"]');
        if (grid === null) return false;
        const count = Number(grid.getAttribute('aria-rowcount')) - 1;
        return count >= low && count <= high;
      },
      { timeout: config.navigationTimeoutMs },
      min,
      max
    );
  } catch {
    throw new Error(`expected ${wanted}; the view held ${await viewCount(page)} row(s)`);
  }
}

/**
 * Wait until the Event source control's availability is `disabled`, naming what was wanted.
 *
 * The state is ARIA's, not the native attribute: a gated control keeps its place in the tab order
 * (EXPERIENCE.md Privilege Gating > Mechanism), so what makes it inert is `readonly` and both are
 * checked here.
 */
async function waitForDisabled(page, disabled, wanted) {
  try {
    await page.waitForFunction(
      (selector, want) => {
        const field = document.querySelector(selector);
        if (field === null) return false;
        return (field.getAttribute('aria-disabled') === 'true') === want && field.readOnly === want;
      },
      { timeout: config.navigationTimeoutMs },
      SOURCE_FIELD,
      disabled
    );
  } catch {
    const state = await page.$eval(SOURCE_FIELD, (field) => ({
      aria: field.getAttribute('aria-disabled'),
      readOnly: field.readOnly,
      disabled: field.disabled,
    }));
    throw new Error(`${wanted}; it read ${JSON.stringify(state)}`);
  }
  // Never the `disabled` attribute, in either state: the floor forbids it outright.
  assert.equal(
    await page.$eval(SOURCE_FIELD, (field) => field.disabled),
    false,
    'the Event source control is never natively disabled, so it keeps its place in the tab order'
  );
}

/** Set the max-rows footer field and wait for the re-read to land at that cap. */
async function setMaxRows(page, cap) {
  await page.click('.ocu-data-table-max-rows', { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type('.ocu-data-table-max-rows', String(cap));
  await page.keyboard.press('Enter');
}

test('AC1: the criteria form renders nine controls, reads nothing before Search, and lists rows under the declared headers after it', async () => {
  const { context, page, reads } = await signedInAtScreen();
  try {
    // Nothing before Search: no read, no table, no skeleton, no empty state (EXPERIENCE.md "criteria form first, skeleton").
    assert.deepEqual(reads, [], 'no screen read is issued before Search');
    assert.equal(await page.$('[role="grid"]'), null, 'and no table is rendered');
    assert.equal(await page.$('.ocu-data-table-skeleton'), null, 'and no skeleton');
    assert.equal(await page.$('.ocu-data-table-empty'), null, 'and no empty state');

    const labels = await page.$$eval('.ocu-criteria-label', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(labels, [
      STRINGS.auditCriteriaBegin,
      STRINGS.auditCriteriaEnd,
      STRINGS.auditColumnEventSource,
      STRINGS.auditColumnEventType,
      STRINGS.auditColumnEventName,
      STRINGS.processColumnUser,
      STRINGS.processColumnPid,
      STRINGS.headerNamespaceLabel,
      STRINGS.auditCriteriaAuthentication,
    ], 'one control per declared criterion, in declaration order');

    // Search with the seed's Source: the search runs on the SERVER, so every row comes back under
    // it -- which a client-side filter over the whole population could not produce.
    await typeCriterion(page, SOURCE_FIELD, SEED_SOURCE);
    await search(page, reads);
    await waitForRows(page, config.navigationTimeoutMs);

    assert.equal(reads.length, 1, `Search issues exactly one read: ${JSON.stringify(reads)}`);
    assert.ok(reads[0].includes(`${READ_PATH}?maxRows=`), `and it is the screen's declared read: ${reads[0]}`);
    assert.ok(reads[0].includes(`eventSources=${SEED_SOURCE}`), `carrying the declared criterion: ${reads[0]}`);

    const headers = await page.$$eval('.ocu-data-table-header-label', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(headers, [
      STRINGS.auditColumnTime,
      STRINGS.auditColumnEventSource,
      STRINGS.auditColumnEventType,
      STRINGS.auditColumnEventName,
      STRINGS.processColumnUser,
      STRINGS.processColumnPid,
      STRINGS.headerNamespaceLabel,
      STRINGS.tableColumnDescription,
    ], 'under the eight declared column headers');

    const sources = await page.$$eval(ROW_SELECTOR, (rows) =>
      rows.map((row) => row.querySelectorAll('[role="gridcell"]')[1].textContent.trim())
    );
    assert.ok(sources.length > 0, 'rows are rendered');
    assert.deepEqual([...new Set(sources)], [SEED_SOURCE], `every rendered row carries the criterion's Source: ${JSON.stringify([...new Set(sources)])}`);

    // The footer's max-rows field re-reads at the new cap, and the criteria travel with it.
    const cap = 5;
    await setMaxRows(page, cap);
    await page.waitForFunction(
      (wanted) => {
        const grid = document.querySelector('[role="grid"]');
        return grid !== null && Number(grid.getAttribute('aria-rowcount')) - 1 === wanted;
      },
      { timeout: config.navigationTimeoutMs },
      cap
    );
    assert.equal(await viewCount(page), cap, 'the view holds exactly the new cap');
    assert.equal(reads.length, 2, 'the cap change re-read');
    assert.ok(reads[1].includes(`maxRows=${cap}`), `at the new cap: ${reads[1]}`);
    assert.ok(reads[1].includes(`eventSources=${SEED_SOURCE}`), `still carrying the criteria: ${reads[1]}`);
  } finally {
    await context.close();
  }
});

test('AC1 regression: leaving the audit screen after a Search and returning re-reads automatically, with no skeleton left stuck', async () => {
  // Story 2.10's own HIGH finding: a full re-bind clears `hasLoaded`, and this archetype has
  // neither a timer nor a read on navigation, so without the patched `readNow()` in
  // `AuditPage`'s constructor the table would render a skeleton nothing ever resolves. The fix
  // was pinned only in jsdom over a stubbed API (`audit.page.spec.ts`'s "re-reads on a return to
  // the screen"); this is the browser leg the follow-up review named, against the real instance.
  const { context, page, reads } = await signedInAtScreen();
  try {
    await typeCriterion(page, SOURCE_FIELD, MARKER_SOURCE);
    await search(page, reads);
    await waitForRows(page, config.navigationTimeoutMs);
    const before = reads.length;

    // Leave the screen through the shell's own SPA navigation, not a full page load: Home is
    // the rail's one item that navigates on click (`rail.ts`'s `activate`), which destroys
    // `AuditPage` the same way any other screen's own navigation would -- unlike the dialog's
    // route, which re-binds the same descriptor and keeps `hasLoaded`.
    await page.click(`.ocu-rail-item[aria-label="${STRINGS.navAreaHome}"]`);
    await page.waitForSelector('.ocu-home', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$('.ocu-criteria-form'), null, 'the audit screen is gone');

    // Return the way a user would: a rail click alone does not navigate for a non-Home area
    // (`shell-state.ts`'s `activateArea`), it only opens that area's side bar, so the Logs
    // area's one built screen is picked from there.
    await page.click(`.ocu-rail-item[aria-label="${STRINGS.navAreaLogs}"]`);
    await page.waitForFunction(
      (label) => Array.from(document.querySelectorAll('.ocu-side-bar-label')).some((node) => node.textContent.trim() === label),
      { timeout: config.navigationTimeoutMs },
      STRINGS.auditListLabel
    );
    await page.evaluate((label) => {
      const item = Array.from(document.querySelectorAll('.ocu-side-bar-item')).find(
        (candidate) => candidate.querySelector('.ocu-side-bar-label').textContent.trim() === label
      );
      item.click();
    }, STRINGS.auditListLabel);
    await page.waitForFunction(() => window.location.pathname === '/ocupilot/logs/audit', {
      timeout: config.navigationTimeoutMs,
    });
    await page.waitForSelector('.ocu-criteria-form', { timeout: config.navigationTimeoutMs });

    // The fix under test: a re-bind whose read had already searched issues its own read, so the
    // return does not leave a skeleton nothing resolves.
    await page.waitForFunction(
      () => document.querySelector('[role="grid"] .ocu-data-table-body [role="row"]') !== null,
      { timeout: config.navigationTimeoutMs }
    );
    assert.equal(await page.$('.ocu-data-table-skeleton'), null, 'no skeleton is left stuck after the return');
    assert.ok(reads.length > before, 'the return issued its own read, rather than showing stale rows forever');
    assert.ok((await viewCount(page)) > 0, 'and the table lists the rows the automatic read found');
    assert.notEqual(await page.$('.ocu-criteria-form'), null, 'the criteria form is there too, ready for another Search');
  } finally {
    await context.close();
  }
});

/**
 * AC2, rescoped by DW-1174. The leg bounds its population with `beginDateTime` and asserts on the
 * rows that window holds, never on the instance's whole marker count. Its counts are exact, so
 * nothing else may write an OcuPilot- or seed-Source audit row during it, which holds because the
 * suite runs one spec at a time on a throwaway.
 *
 * **Why it had to change.** It read `markerRowCount()` and `seedRowsPresent()`, set the view's cap
 * to their sum, and waited for exactly that many rows. On a container whose only `OcuPilot` rows
 * are the installer's handful that is quick; on an instance carrying thousands -- which this one
 * now is, because `before()` seeds a thousand under the marker's own Source -- it asks the browser
 * to render the whole population twice and times out. The window is what makes the counts small,
 * exact and independent of whatever the instance already held.
 *
 * mutation: put the whole-population bound back -- `setMaxRows(markerRowCount() + seedRowsPresent())`
 * with a `waitForCount` at that figure, and no `beginDateTime` -- and the leg fails against the
 * seeded instance, which is the DW-1174 reproduction. Measured here: 32.7 s and red, the view
 * holding 1,228 of the 2,238 rows it demanded, against 1.4 s green with the window.
 */
test('AC2: inside its own window, the agent-marker filter narrows to a proper non-empty subset, overriding the Event source criterion', async () => {
  // The window opens before a single row of this leg's own population exists, and is read from
  // the instance because the criterion is instance local time.
  const since = instanceStamp();
  seedWindowRows(WINDOW_MARKER_ROWS, WINDOW_SEED_ROWS);
  const windowTotal = WINDOW_MARKER_ROWS + WINDOW_SEED_ROWS;

  const { context, page, reads } = await signedInAtScreen();
  try {
    // Both populations, bounded to this leg's own window. The vendor matches a comma list by
    // membership, which is the same rule the marker's override exists because of.
    await typeCriterion(page, '#ocu-audit-criterion-beginDateTime', since);
    await typeCriterion(page, SOURCE_FIELD, `${MARKER_SOURCE},${SEED_SOURCE}`);
    await search(page, reads);
    await waitForRows(page, config.navigationTimeoutMs);
    assert.ok(
      reads[reads.length - 1].includes('beginDateTime='),
      `the read carries the window bound: ${reads[reads.length - 1]}`
    );
    await waitForCount(page, { min: windowTotal, max: windowTotal }, `the ${windowTotal} rows this leg wrote`);
    const total = await viewCount(page);

    // A value in the Event source field, so the override has something to override.
    await typeCriterion(page, SOURCE_FIELD, SEED_SOURCE);
    await page.click(MARKER_BOX);
    await waitForDisabled(page, true, 'the Event source control goes unavailable while the marker is on');

    await search(page, reads);
    await waitForCount(page, { min: WINDOW_MARKER_ROWS, max: WINDOW_MARKER_ROWS }, `the ${WINDOW_MARKER_ROWS} marker rows of ${total}`);
    const kept = await viewCount(page);
    const marked = reads[reads.length - 1];
    assert.ok(marked.includes(`eventSources=${MARKER_SOURCE}`), `the read carries the marker's Source: ${marked}`);
    assert.ok(!marked.includes(SEED_SOURCE), `and not the value the field held, because the marker overrides rather than merges: ${marked}`);
    // The window bound is still the criterion the form holds; the marker overrides one field.
    assert.ok(marked.includes('beginDateTime='), `and still the window bound: ${marked}`);

    // Both directions. The subset is proper and non-empty, bounded from both sides, and its lower
    // bound is exact: the view holds precisely the marker rows this leg wrote.
    assert.ok(kept > 0, `the marker filter keeps OcuPilot's own rows: ${kept}`);
    assert.ok(kept < total, `and narrows the view: ${kept} of ${total}`);
    assert.equal(kept, WINDOW_MARKER_ROWS, 'keeping exactly the marker rows the window holds');

    const markedSources = await page.$$eval(ROW_SELECTOR, (rows) =>
      rows.map((row) => row.querySelectorAll('[role="gridcell"]')[1].textContent.trim())
    );
    assert.deepEqual([...new Set(markedSources)], [MARKER_SOURCE], 'and every rendered row is one of them');

    // Off again: the same search returns strictly more rows, and OcuPilot's own are among them --
    // never hidden (AD-46). Exact rather than "more": the unfiltered view is the window's two
    // populations added, which is only true if both are in it.
    await page.click(MARKER_BOX);
    await waitForDisabled(page, false, 'the control comes back when the marker is turned off');
    await typeCriterion(page, SOURCE_FIELD, `${MARKER_SOURCE},${SEED_SOURCE}`);
    await search(page, reads);
    await waitForCount(page, { min: total, max: total }, `the whole ${total}-row window again`);
    const reopened = await viewCount(page);
    assert.ok(reopened > kept, `the unfiltered view is strictly wider: ${reopened} against ${kept}`);
    assert.equal(reopened, kept + WINDOW_SEED_ROWS, "and is the window's two populations added, so OcuPilot's own rows are in it");

    // The instance holds far more marker rows than the window does, which is what says the bound
    // above is doing the narrowing rather than the instance being small (DW-1174).
    assert.ok(
      markerRowCount() > WINDOW_MARKER_ROWS * 10,
      `the instance carries a marker population this window is a small part of: ${markerRowCount()}`
    );
  } finally {
    await context.close();
  }
});

test('AC3: a row opens a read-only dialog that traps focus, closes on Escape and on Close, and leaves the shell chords inert', async () => {
  const { context, page, reads } = await signedInAtScreen();
  try {
    await typeCriterion(page, SOURCE_FIELD, MARKER_SOURCE);
    await search(page, reads);
    await waitForRows(page, config.navigationTimeoutMs);

    // A real hit-tested pointer click at the first row's link (DW-273), which is what a user does;
    // `clickRowCentre` refuses first if the point at its centre resolves outside the row.
    await clickRowCentre(page, { index: 0, link: true });
    await page.waitForSelector('[role="dialog"]', { timeout: config.navigationTimeoutMs });

    const opened = await page.evaluate(() => {
      const dialog = document.querySelector('[role="dialog"]');
      return {
        modal: dialog.getAttribute('aria-modal'),
        title: document.querySelector('.ocu-dialog-title').textContent.trim(),
        fields: Array.from(document.querySelectorAll('.ocu-dialog-field')).map((node) => node.textContent.trim()),
        payload: document.querySelector('.ocu-dialog-payload') !== null,
        description: document.querySelector('.ocu-dialog-value').textContent.trim(),
        action: document.querySelector('.ocu-dialog-actions button').textContent.trim(),
        // Read-only: the body carries no field the user could type into.
        inputs: dialog.querySelectorAll('input, select, textarea').length,
        url: window.location.pathname,
        focusedInDialog: dialog.contains(document.activeElement),
      };
    });
    assert.equal(opened.modal, 'true');
    assert.equal(opened.title, STRINGS.auditDialogTitle);
    assert.deepEqual(opened.fields, [STRINGS.tableColumnDescription, STRINGS.auditDialogEventData]);
    assert.equal(opened.payload, true, 'the JSON payload is rendered');
    assert.equal(opened.action, STRINGS.auditDialogClose);
    assert.equal(opened.inputs, 0, 'and the dialog is read-only');
    assert.ok(opened.url.startsWith('/ocupilot/logs/audit/'), `it opened on the id route: ${opened.url}`);
    assert.equal(opened.focusedInDialog, true, 'focus is inside the dialog');

    // The shell's chords are inert while it stands (EXPERIENCE.md "the dialogs listed in Information Architecture").
    await page.keyboard.down('Control');
    await page.keyboard.press('KeyK');
    await page.keyboard.press('KeyB');
    await page.keyboard.press('KeyI');
    await page.keyboard.up('Control');
    const afterChords = await page.evaluate(() => ({
      dialogs: document.querySelectorAll('[role="dialog"]').length,
      commandBoxOpen: document.querySelector('.ocu-command-box-panel') !== null,
      focusedInDialog: document.querySelector('[role="dialog"]').contains(document.activeElement),
    }));
    assert.equal(afterChords.dialogs, 1, 'the dialog still stands, and never stacks');
    assert.equal(afterChords.commandBoxOpen, false, 'Ctrl+K opened nothing');
    assert.equal(afterChords.focusedInDialog, true, 'and focus is still trapped inside it');

    // Tab from the last focusable element wraps to the first rather than leaving the surface.
    await page.evaluate(() => document.querySelector('.ocu-dialog-actions button').focus());
    await page.keyboard.press('Tab');
    assert.equal(
      await page.evaluate(() => document.querySelector('[role="dialog"]').contains(document.activeElement)),
      true,
      'Tab keeps focus inside the dialog'
    );

    // Escape closes it, and the route returns to the bare screen with focus back on the grid.
    await page.keyboard.press('Escape');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, {
      timeout: config.navigationTimeoutMs,
    });
    assert.equal(await page.evaluate(() => window.location.pathname), '/ocupilot/logs/audit', 'closing returns to the bare route');
    try {
      await page.waitForFunction(() => document.activeElement?.getAttribute('role') === 'grid', {
        timeout: config.navigationTimeoutMs,
      });
    } catch {
      const where = await page.evaluate(() => {
        const active = document.activeElement;
        return active === null ? 'nothing' : `${active.tagName}${active.className === '' ? '' : `.${active.className}`}`;
      });
      throw new Error(`focus returns to the opener, which is the grid; it was on ${where}`);
    }
    const rows = await page.evaluate(
      () => document.querySelectorAll('[role="grid"] .ocu-data-table-body [role="row"]').length
    );
    assert.ok(rows > 0, 'and the rows the search found are still on screen');

    // And again, through the Close action rather than Escape.
    await clickRowCentre(page, { index: 0, link: true });
    await page.waitForSelector('[role="dialog"]', { timeout: config.navigationTimeoutMs });
    await page.evaluate(() => document.querySelector('.ocu-dialog-actions button').click());
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, {
      timeout: config.navigationTimeoutMs,
    });
    assert.equal(await page.evaluate(() => window.location.pathname), '/ocupilot/logs/audit');
  } finally {
    await context.close();
  }
});

test('AC4: criteria that match nothing read the screen\'s own empty sentence, with no skeleton and no fault', async () => {
  const { context, page, reads } = await signedInAtScreen();
  try {
    await typeCriterion(page, SOURCE_FIELD, 'NoSuchAuditSourceExistsHere');
    await search(page, reads);
    await page.waitForSelector('.ocu-data-table-empty', { timeout: config.navigationTimeoutMs });
    const empty = await page.evaluate(() => ({
      text: document.querySelector('.ocu-data-table-empty').textContent.trim(),
      skeleton: document.querySelector('.ocu-data-table-skeleton') !== null,
      refusal: document.querySelector('.ocu-data-table-refusal') !== null,
      rows: document.querySelectorAll('[role="grid"] .ocu-data-table-body [role="row"]').length,
    }));
    assert.ok(empty.text.includes(STRINGS.auditListEmpty), `the screen's own sentence: ${JSON.stringify(empty.text)}`);
    assert.ok(!empty.text.includes(STRINGS.processListEmpty), 'not another list\'s');
    assert.equal(empty.skeleton, false, 'no skeleton');
    assert.equal(empty.refusal, false, 'and no fault state');
    assert.equal(empty.rows, 0);
  } finally {
    await context.close();
  }
});

test('AC6 (DW-258): with the throwaway seeded to a thousand rows, a 1,000-row Search renders its first row within two seconds', async () => {
  const { context, page, reads } = await signedInAtScreen();
  try {
    // The precondition first, and from the instance rather than from the view: a two-second pass
    // over eleven rows must not stand for a thousand. The default cap is already 1,000
    // (`DEFAULT_MAX_ROWS`), so the measurement is of the Search press itself and not of a re-read
    // after a cap change.
    const seeded = seedRowsPresent();
    assert.ok(seeded >= 1000, `the instance holds at least a thousand rows under ${SEED_SOURCE} to read: ${seeded}`);

    await typeCriterion(page, SOURCE_FIELD, SEED_SOURCE);

    const startedAt = Date.now();
    await page.click(SEARCH_BUTTON);
    await page.waitForSelector(`${ROW_SELECTOR}[aria-rowindex="2"]`, { timeout: FIRST_ROW_WAIT_MS });
    const elapsed = Date.now() - startedAt;

    // The two figures are spelled out rather than derived from `SEED_ROWS`: the AC names a
    // thousand rows and an `aria-rowcount` of 1,001, and an assertion that read the seed constant
    // would follow it down -- a run seeded to eleven rows would then pass while claiming a thousand,
    // which is the reading Rule 19 exists to stop.
    const rendered = await viewCount(page);
    assert.equal(rendered, 1000, `the view holds a thousand rows: ${rendered}`);
    const rowcount = await page.$eval('[role="grid"]', (grid) => Number(grid.getAttribute('aria-rowcount')));
    assert.equal(rowcount, 1001, 'aria-rowcount reaches 1,001, the thousand rows and their header');
    assert.ok(
      elapsed <= FIRST_ROW_BUDGET_MS,
      `the first data row is in the DOM within ${FIRST_ROW_BUDGET_MS} ms of the Search press: ${elapsed} ms`
    );
    assert.ok(reads.length >= 1, 'and the measurement is of a real read');
  } finally {
    await context.close();
  }
});

test('AC7: an authentication value outside the declared options is refused by name, and no LIST is queued', async () => {
  const { context, page, reads } = await signedInAtScreen();
  try {
    // The control itself offers only the declared vocabulary, so the screen cannot send one.
    const options = await page.$$eval(`${AUTH_FIELD} option`, (nodes) => nodes.map((node) => node.value));
    assert.equal(options[0], '', 'the first option is the unset one');
    assert.ok(options.includes('Password'), `the declared vocabulary is offered: ${JSON.stringify(options)}`);
    assert.ok(!options.includes('Bogus'), 'and nothing outside it');

    // The route is what the refusal has to hold, because a read tool and a hand-written URL both
    // reach it. Issued from the page so the session's own Bearer is attached.
    const refused = await page.evaluate(async (path) => {
      const response = await fetch(`${path}?maxRows=5&authentication=Bogus`, {
        headers: { Authorization: `Bearer ${JSON.parse(sessionStorage.getItem('ocupilot.token-pair') ?? '{}').accessToken ?? ''}` },
      });
      return { status: response.status, body: await response.text() };
    }, READ_PATH);
    assert.equal(refused.status, 400, `an off-list value is refused: ${refused.body}`);
    const envelope = JSON.parse(refused.body);
    assert.equal(envelope.code, 'READ.CRITERION', `on the criterion machine code: ${refused.body}`);
    assert.ok(envelope.reason.includes('authentication'), `naming the criterion: ${envelope.reason}`);

    // And a declared one is served, which is what makes the refusal a refusal rather than a screen
    // that answers 400 to everything.
    const served = await page.evaluate(async (path) => {
      const response = await fetch(`${path}?maxRows=5&authentication=Password`, {
        headers: { Authorization: `Bearer ${JSON.parse(sessionStorage.getItem('ocupilot.token-pair') ?? '{}').accessToken ?? ''}` },
      });
      return response.status;
    }, READ_PATH);
    assert.equal(served, 200, 'a declared value is served');
    // The two reads above are this leg's own `fetch` calls, not the screen's: Search was never
    // pressed, so no table was ever rendered.
    assert.deepEqual(
      reads.map((url) => new URL(url).searchParams.get('authentication')),
      ['Bogus', 'Password'],
      `only this leg's own two requests reached the route: ${JSON.stringify(reads)}`
    );
    assert.equal(await page.$('[role="grid"]'), null, 'and the screen itself rendered no table');
  } finally {
    await context.close();
  }
});

/** The seed's own rows, read back from the instance -- AC6's precondition. */
function seedRowsPresent() {
  return auditRowCount(SEED_SOURCE);
}

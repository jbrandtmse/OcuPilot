/**
 * The application error log in a real browser, against the throwaway instance: the full drill --
 * namespaces to dates to errors to one error's captured variable table (AC3) -- and the two things
 * jsdom cannot show, that each level is a rendered table and that the detail renders in place
 * rather than in a dialog (AC5).
 *
 * **Almost every test here writes nothing.** Every level but the last is a read; the instance
 * already holds errors, because the installer's own `SeedApplicationError` puts one in on every
 * start. The one class that writes an application error is `OcuPilot.Test.ErrorLogSeed`, and it
 * runs under its own arming variable; most tests here create no principal either -- AC6's denials
 * are `OcuPilot.Test.ErrorLogDenial`'s, over HTTP with real principals. The one exception is the
 * DW-307 truncation leg below, which seeds through that same guarded class and so refuses the live
 * container the way every other writing spec in this tree does.
 *
 * **Every drill step is a real hit-tested pointer click** on the row's own link (`clickRowCentre`,
 * DW-273). It used to be a synthetic `dispatchEvent`, because the routed outlet had collapsed the
 * table frame to its header's height and the footer painted over the rows -- which is exactly what
 * a synthetic click hid. Story 2.13 gave the outlet a height; the helper now measures the point it
 * is about to click and refuses when that point resolves outside the row.
 *
 * **The three scope-naming empty states are not asserted here, and could not be.** Each level's
 * empty state is reachable only when the level below it holds nothing, and the port refuses a
 * namespace or a date the instance's own enumerations do not carry -- so on an instance that
 * records errors at all, no level this drill can reach renders one. `error-log.page.spec.ts` drives
 * all three against a stub that answers zero rows, which is where the scope resolution is pinned.
 *
 * **The refusal notice is asserted here, against a genuine refusal.** `error-log.page.spec.ts`
 * drives it through a stubbed `ApiService`, and `OcuPilot.Test.ErrorLogDenial` measures the same
 * 403 over HTTP with real principals -- but neither shows the notice rendered by the shipped
 * bundle in a real browser, which is what `signedInAtScreenIntercepting` below reaches: the
 * outgoing request is rewritten in flight to a namespace no enumeration on this instance carries,
 * so the 404 that comes back is the live endpoint's own answer, not a mock.
 *
 * **The privilege-denial sentence (DW-323) is asserted here too, against a genuine
 * `AUTH.NOPRIVILEGE` envelope.** A principal denied one of `LogErrorList`'s own instance-level
 * pairs (`%Admin_Operate:USE`, `%DB_IRISSYS:READ`) is denied the same pair by the navigation map
 * and never gets past `screen-outlet.ts`'s own `allowed()` gate to reach this page at all -- so
 * that half of AD-8's 403 is unreachable by a real principal in a real browser, by construction.
 * What is reachable is the PER-NAMESPACE half (AD-48): `OcuPilot.Test.ErrorLogDenial`'s own
 * `SERVEDUSER` holds every instance pair, so it passes the navigation gate and the namespaces
 * level serves -- but it holds only READ, not WRITE, on a second seeded namespace, so drilling
 * into that one is refused 403 naming its own WRITE pair. Reusing `SERVEDUSER` (created and
 * deleted the same way `ErrorLogDenial` itself does, over the whole browser session rather than
 * one class run) ties this leg to the exact account
 * `TestOneNamespaceIsServedAndAnotherRefusedInOneSession` already pins over raw HTTP, so the two
 * halves DW-323 found pinned separately -- the server's envelope, the client's `detail` lift --
 * are now observed together from the one thing that renders them.
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
import { ROW_SELECTOR, clickRowCentre, viewCount } from './list-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));
const { formatDeniedAction } = await import(join(uiRoot, 'src', 'app', 'core', 'navigation.ts'));

const config = browserConfig();
const SCREEN_URL = '/ocupilot/logs/errors';

/** The drill's own parts, so a markup change is one edit. */
const BACK_BUTTON = '[data-ocu-drill="back"]';
const SCOPE_LINE = '[data-ocu-drill="scope"]';
const LEVEL_FRAME = '[data-ocu-level]';
const SECTION_FRAME = '[data-ocu-section]';
const REFUSAL_SELECTOR = '[data-ocu-drill="refusal"]';

/** A namespace no enumeration on this instance will ever answer with (mirrors the unit tier's
 * own `OcuPilot.Test.ErrorLog.UNKNOWNNAMESPACE`). */
const UNKNOWN_NAMESPACE = 'OCUPILOTNOSUCHNS';

/** `OcuPilot.Test.ErrorLogSeed.TARGETNAMESPACE` -- a normal namespace, never the install one, so
 * seeded entries are never confused with whatever install already put in HSCUSTOM. */
const SEED_NAMESPACE = 'USER';

/** `OcuPilot.Test.ErrorLogDenial.SERVEDUSER` -- reused by name (DW-323) so this leg drives the
 * exact principal the unit tier already pins over raw HTTP. */
const SERVED_USER = 'OcuPilotErrServed';

let browser = null;

const mark = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/**
 * Seed `count` application errors into `SEED_NAMESPACE` through the throwaway's own guarded
 * `OcuPilot.Test.ErrorLogSeed.SeedInto`, run inside the container the same way `tasks.browser-spec.mjs`
 * drives `%SYS.Task` -- `docker exec` into an `iris session`, markers parsed by the shared
 * `parseMarkers`. Started in `HSCUSTOM`, not `%SYS`: `SeedInto` is an `OcuPilot.*` class method,
 * which `%SYS` cannot resolve, and it switches to `SEED_NAMESPACE` itself to log the entry.
 *
 * Answers nothing about which date the entries landed on -- the caller diffs the dates level's own
 * rendered rows before and after, rather than this function predicting the vendor query's date
 * format, which is a second thing that could drift from what the client actually shows.
 */
function seedErrors(count) {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this leg seeds an application error through OcuPilot.Test.ErrorLogSeed and never runs against the live instance');
  const lines = [];
  for (let i = 0; i < count; i += 1) {
    lines.push(`Set tSC${i} = ##class(OcuPilot.Test.ErrorLogSeed).SeedInto("${SEED_NAMESPACE}", .tDay, .tNumber)`);
    lines.push(mark(`OK${i}`, `$System.Status.IsOK(tSC${i})`));
  }
  const input = `${lines.join('\n')}\nHalt\n`;
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', 'HSCUSTOM'], {
    input,
    encoding: 'utf8',
    timeout: 60000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const names = [...Array(count).keys()].map((i) => `OK${i}`);
  const values = parseMarkers(output, names);
  for (let i = 0; i < count; i += 1) {
    assert.equal(values[`OK${i}`], '1', `seed #${i} raised and logged its own deliberate error:\n${output}`);
  }
}

/**
 * Create `OcuPilot.Test.ErrorLogDenial`'s four throwaway principals by invoking its own
 * `OnBeforeAllTests` directly rather than through `%UnitTest.Manager` -- this leg needs the
 * accounts to survive across the whole browser session, not one class run. Answers
 * `SERVEDUSER`'s password and the per-namespace measurement `OnBeforeAllTests` already
 * establishes: the seeded namespace and date it holds only READ on, and the WRITE pair that
 * refuses it there.
 */
function createServedUserFixture() {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this leg creates real IRIS principals through OcuPilot.Test.ErrorLogDenial and never runs against the live instance');
  const input = `Set tCase = ##class(OcuPilot.Test.ErrorLogDenial).%New()
Set tSC = tCase.OnBeforeAllTests()
${mark('OK', '$System.Status.IsOK(tSC)')}
${mark('ERR', '$Select($System.Status.IsOK(tSC):"",1:$System.Status.GetErrorText(tSC))')}
${mark('PASSWORD', 'tCase.PreparedPassword')}
${mark('REFUSEDNS', 'tCase.PreparedRefusedNamespace')}
${mark('REFUSEDDATE', 'tCase.PreparedRefusedDate')}
${mark('REFUSEDRESOURCE', 'tCase.PreparedRefusedResource')}
Halt
`;
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', 'HSCUSTOM'], {
    input,
    encoding: 'utf8',
    timeout: 60000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const values = parseMarkers(output, ['OK', 'ERR', 'PASSWORD', 'REFUSEDNS', 'REFUSEDDATE', 'REFUSEDRESOURCE']);
  assert.equal(values.OK, '1', `OcuPilot.Test.ErrorLogDenial.OnBeforeAllTests succeeded: ${values.ERR}\n${output}`);
  return {
    password: values.PASSWORD,
    refusedNamespace: values.REFUSEDNS,
    refusedDate: values.REFUSEDDATE,
    failedPair: `${values.REFUSEDRESOURCE}:WRITE`,
  };
}

/**
 * Remove `OcuPilot.Test.ErrorLogDenial`'s four throwaway principals the same way the class tears
 * itself down. `OnAfterAllTests` needs no state from the `OnBeforeAllTests` call that created
 * them -- only the class's own constant account names -- so a fresh instance can run it.
 */
function destroyServedUserFixture() {
  const input = `Set tCase = ##class(OcuPilot.Test.ErrorLogDenial).%New()
Set tSC = tCase.OnAfterAllTests()
${mark('OK', '$System.Status.IsOK(tSC)')}
${mark('ERR', '$Select($System.Status.IsOK(tSC):"",1:$System.Status.GetErrorText(tSC))')}
Halt
`;
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', 'HSCUSTOM'], {
    input,
    encoding: 'utf8',
    timeout: 60000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const values = parseMarkers(output, ['OK', 'ERR']);
  assert.equal(values.OK, '1', `OcuPilot.Test.ErrorLogDenial.OnAfterAllTests left no throwaway objects behind: ${values.ERR}\n${output}`);
}

/** The dates level's own two rendered columns -- date and count -- read the way the client shows
 * them, never assumed from a vendor query's format. */
function dateCounts(page) {
  return page.$$eval(ROW_SELECTOR, (rows) =>
    rows.map((row) => {
      const cells = Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim());
      return { date: cells[0], count: cells[1] };
    })
  );
}

before(async () => {
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
});

/**
 * A fresh context signed in through the shell's own form at the screen's deep link, reads
 * counted. `username`/`password` default to the shell's own account; DW-323's leg passes a
 * throwaway principal's instead, so the same sign-in flow drives both.
 */
async function signedInAtScreen(username = config.username, password = config.password) {
  // Story 15.5: the remembered screen and shell state lives on the instance now, keyed by the
  // one account every spec signs in as, so a fresh context is no longer a fresh slate on its
  // own -- see `preferences-reset.mjs`.
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  const reads = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.pathname.startsWith('/api/ocupilot/logs/errors/')) reads.push(url.pathname + url.search);
  });
  await page.goto(`${config.origin}${SCREEN_URL}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', username);
  await page.type('#ocu-signin-password', password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  // The first-login gate takes an administrator to the Definition form on an instance with no
  // enabled definition, whatever URL was asked for (Story 3.6). Back returns to this one.
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, SCREEN_URL);
  await settled(page, 'namespaces');
  return { context, page, reads };
}

/**
 * A fresh context signed in the same way, with request interception armed so one outgoing read
 * can be redirected in flight to a namespace or date this instance's own enumeration never
 * carries -- a genuine refusal computed by the real endpoint, not a mocked response.
 *
 * `armRewrite(pathname, param, value)` is one-shot: the first request whose pathname matches is
 * rewritten and unarmed; every other request, including the ones the shell issues to render its
 * own chrome, passes through untouched. Puppeteer's own contract is what makes this real rather
 * than a stub -- `ContinueRequestOverrides.url` changes the URL the browser actually dispatches
 * ("this is not a redirect"), so the response the page's own `fetch()` resolves with is whatever
 * the live server computes for the rewritten query.
 */
async function signedInAtScreenIntercepting() {
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  let armed = null;
  await page.setRequestInterception(true);
  page.on('request', (request) => {
    if (armed !== null) {
      const url = new URL(request.url());
      if (url.pathname === armed.pathname) {
        url.searchParams.set(armed.param, armed.value);
        armed = null;
        request.continue({ url: url.toString() });
        return;
      }
    }
    request.continue();
  });
  await page.goto(`${config.origin}${SCREEN_URL}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', config.username);
  await page.type('#ocu-signin-password', config.password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  // The first-login gate takes an administrator to the Definition form on an instance with no
  // enabled definition, whatever URL was asked for (Story 3.6). Back returns to this one.
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, SCREEN_URL);
  await settled(page, 'namespaces');
  return {
    context,
    page,
    armRewrite(pathname, param, value) {
      armed = { pathname, param, value };
    },
  };
}

/**
 * Wait until the page is on `level` **and** that level's read has landed -- rows rendered, or the
 * empty state, or the detail's sections.
 *
 * The level attribute alone is not enough: it is on the frame the moment the store switches level,
 * which is before the request it issued has answered, so a test that waited on it would read an
 * empty grid and report the page as having no columns.
 */
async function settled(page, level) {
  await page.waitForFunction(
    (frame, rowSelector, sectionSelector, refusalSelector, wanted) => {
      const node = document.querySelector(frame);
      if (node === null || node.getAttribute('data-ocu-level') !== wanted) return false;
      if (wanted === 'detail') return document.querySelector(sectionSelector) !== null;
      return (
        document.querySelector(rowSelector) !== null ||
        document.querySelector('.ocu-data-table-empty') !== null ||
        document.querySelector(refusalSelector) !== null
      );
    },
    { timeout: config.navigationTimeoutMs },
    LEVEL_FRAME,
    ROW_SELECTOR,
    SECTION_FRAME,
    REFUSAL_SELECTOR,
    level
  );
}

/** The level the page says it is on, read from the frame's own attribute. */
function levelOf(page) {
  return page.evaluate((selector) => document.querySelector(selector)?.getAttribute('data-ocu-level') ?? '', LEVEL_FRAME);
}

/** The column headers the current level renders. */
function headersOf(page) {
  return page.$$eval('[role="grid"] [role="columnheader"]', (cells) =>
    cells.map((cell) => cell.textContent.trim())
  );
}

/** The first cell of every rendered row. */
function firstCells(page) {
  return page.$$eval(ROW_SELECTOR, (rows) =>
    rows.map((row) => row.querySelector('[role="gridcell"]')?.textContent?.trim() ?? '')
  );
}

/**
 * Open the row whose first cell reads `text` and wait until the page says it is on `nextLevel`.
 *
 * The click is a real hit-tested pointer click at the row link's own centre (`clickRowCentre`,
 * DW-273), so a drill level whose frame has collapsed fails here rather than drilling anyway; the
 * wait is on the level attribute rather than on a row appearing, so a level that answers zero rows
 * is still a drill this helper can complete.
 */
async function drillInto(page, text, nextLevel) {
  await clickRowCentre(page, { text, link: true });
  await settled(page, nextLevel);
}

test('AC3: the drill walks namespaces to dates to errors, each level a table with its own columns', async () => {
  const { context, page, reads } = await signedInAtScreen();
  try {
    assert.equal(await levelOf(page), 'namespaces', 'the screen opens on the namespaces level');
    assert.deepEqual(await headersOf(page), [STRINGS.headerNamespaceLabel], 'whose one column is the namespace');
    const namespaces = await firstCells(page);
    assert.ok(namespaces.length > 0, `the instance records errors for at least one namespace: ${JSON.stringify(namespaces)}`);
    assert.ok(
      (await viewCount(page)) === namespaces.length,
      'and the grid declares the row count it rendered'
    );
    // No Back from the first level: there is nowhere above it.
    assert.equal(await page.$(BACK_BUTTON), null, 'the first level offers no Back');

    await drillInto(page, namespaces[0], 'dates');
    assert.deepEqual(
      await headersOf(page),
      [STRINGS.errorLogColumnDate, STRINGS.errorLogColumnCount],
      'the dates level renders the date and its count'
    );
    assert.equal(
      await page.$eval(SCOPE_LINE, (node) => node.textContent.trim()),
      namespaces[0],
      'and the scope line names the namespace drilled to'
    );
    const dates = await firstCells(page);
    assert.ok(dates.length > 0, `that namespace records errors on at least one date: ${JSON.stringify(dates)}`);

    await drillInto(page, dates[0], 'list');
    assert.deepEqual(
      await headersOf(page),
      [
        STRINGS.errorLogColumnNumber,
        STRINGS.auditColumnTime,
        STRINGS.errorLogColumnText,
        STRINGS.processColumnRoutine,
        STRINGS.errorLogColumnLine,
        STRINGS.processColumnUser,
        STRINGS.processColumnPid,
      ],
      'the errors level renders the summary projection'
    );
    const errorRow = await page.$$eval(ROW_SELECTOR, (rows) =>
      Array.from(rows[0].querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim())
    );
    assert.ok(errorRow[0] !== '', 'each error shows its number');
    assert.ok(errorRow[1] !== '', 'and its time');
    assert.ok(errorRow[2] !== '', `and its error text: ${JSON.stringify(errorRow[2])}`);

    // Every call this screen made carried its own namespace parameter and no route scope.
    assert.ok(reads.length >= 3, `three levels were read: ${JSON.stringify(reads)}`);
    assert.ok(
      reads.every((path) => !path.includes('ns=')),
      `and none of them carried a route scope: ${JSON.stringify(reads)}`
    );
    assert.ok(
      reads.some((path) => path.startsWith('/api/ocupilot/logs/errors/list?namespace=')),
      `the errors level named its own namespace: ${JSON.stringify(reads)}`
    );
  } finally {
    await context.close();
  }
});

test('AC5: one error opens its captured variable table in place, and Back returns through every level', async () => {
  const { context, page } = await signedInAtScreen();
  try {
    const namespaces = await firstCells(page);
    await drillInto(page, namespaces[0], 'dates');
    const dates = await firstCells(page);
    await drillInto(page, dates[0], 'list');
    const errors = await firstCells(page);
    assert.ok(errors.length > 0, 'the date records at least one error');

    await drillInto(page, errors[0], 'detail');
    const sections = await page.$$eval(SECTION_FRAME, (frames) =>
      frames.map((frame) => frame.getAttribute('data-ocu-section'))
    );
    assert.deepEqual(
      sections,
      [STRINGS.errorLogDetailExpressions, STRINGS.errorLogDetailStack, STRINGS.errorLogDetailVariables],
      'the detail renders the three captured sections'
    );
    // In place, never in a dialog: Dialog is 440px fixed and single-action, which a variable table
    // of several hundred rows fits none of.
    assert.equal(await page.$('[role="dialog"]'), null, 'and renders no dialog');

    const variables = await page.$$eval(
      `${SECTION_FRAME} .ocu-data-table-body [role="row"]`,
      (rows) => rows.length
    );
    assert.ok(variables > 0, `with the captured rows on screen: ${variables}`);
    const hasRoles = await page.evaluate(
      (selector, wanted) => {
        const frame = Array.from(document.querySelectorAll(selector)).find(
          (candidate) => candidate.getAttribute('data-ocu-section') === wanted
        );
        return frame === undefined ? false : /\$ROLES|\$Roles/.test(frame.textContent);
      },
      SECTION_FRAME,
      STRINGS.errorLogDetailExpressions
    );
    assert.equal(hasRoles, true, 'including the identity the user reads on screen and the agent never does (AD-48)');

    // Back walks the drill up one level at a time, and the scope line shrinks with it.
    await page.click(BACK_BUTTON);
    await settled(page, 'list');
    await page.click(BACK_BUTTON);
    await settled(page, 'dates');
    await page.click(BACK_BUTTON);
    await settled(page, 'namespaces');
    assert.equal(await page.$(BACK_BUTTON), null, 'and the first level offers no Back again');
  } finally {
    await context.close();
  }
});

test('AC3, AC6: a refused level renders the named refusal, never a blank frame, and drops the rows it had', async () => {
  const { context, page, armRewrite } = await signedInAtScreenIntercepting();
  try {
    const namespaces = await firstCells(page);
    assert.ok(namespaces.length > 0, `the instance records errors for at least one namespace: ${JSON.stringify(namespaces)}`);

    // A served drill first, so there is something on screen for a refusal to have to drop.
    await drillInto(page, namespaces[0], 'dates');
    const datesBefore = await firstCells(page);
    assert.ok(datesBefore.length > 0, `that namespace records errors on at least one date: ${JSON.stringify(datesBefore)}`);
    assert.equal(await page.$(REFUSAL_SELECTOR), null, 'the served level shows no refusal');

    // Back to namespaces, then reopen the SAME namespace -- but this time the outgoing request's
    // own `namespace` parameter is rewritten in flight to one no NamespaceList on this instance
    // will ever answer with, so what comes back is a genuine LOG.NAMESPACE 404 from the same
    // endpoint every other test in this file reads, not a mocked one.
    await page.click(BACK_BUTTON);
    await settled(page, 'namespaces');
    armRewrite('/api/ocupilot/logs/errors/dates', 'namespace', UNKNOWN_NAMESPACE);
    // `response.url()` reports the request as the page issued it -- the real namespace, never the
    // rewrite -- because Puppeteer correlates the response back to the `HTTPRequest` object it
    // handed to `armRewrite`'s listener, not to the URL that actually went out over the wire. The
    // rewrite's effect is only observable in what comes back: this is the one and only `dates`
    // response this arming window produces, and its status is the live endpoint's real answer.
    let refusedStatus = null;
    const onResponse = (response) => {
      const url = new URL(response.url());
      if (url.pathname === '/api/ocupilot/logs/errors/dates') refusedStatus = response.status();
    };
    page.on('response', onResponse);
    await drillInto(page, namespaces[0], 'dates');
    page.off('response', onResponse);
    assert.equal(refusedStatus, 404, 'the rewritten request was genuinely refused by the real endpoint, not stubbed');

    // Mutation (Rule 19): render `STRINGS.connectivityRequestRefused` unconditionally at
    // `error-log.page.ts`'s refusal span -> this goes red against the real 404 from the live
    // endpoint, which is what makes this leg, and not the stubbed unit cases, the proof that the
    // shipped bundle branches on the envelope's code. Delete the `showRefusal` branch instead ->
    // the level frame still switches to `dates` but this element never appears, and the assertion
    // below times out instead of failing on a false value -- a blank frame, exactly as the risk
    // named it.
    assert.notEqual(await page.$(REFUSAL_SELECTOR), null, 'the refusal renders its own notice rather than a blank frame');
    assert.equal(
      await page.$eval(REFUSAL_SELECTOR, (node) => node.textContent.trim()),
      STRINGS.errorLogRefusedNamespace,
      'naming the refusal the envelope reported -- a namespace this log does not carry -- not the generic sentence every refused read used to show'
    );

    // Mutation (Rule 19): stop clearing `dateRows` in `ErrorLogDrill.openDates` -> the real dates
    // captured above as `datesBefore` render again here, under the very same scope line, and this
    // goes red.
    assert.deepEqual(
      await firstCells(page),
      [],
      `the dates this namespace served a moment ago do not render under the refusal: ${JSON.stringify(datesBefore)}`
    );
    assert.equal(
      await page.$eval(SCOPE_LINE, (node) => node.textContent.trim()),
      namespaces[0],
      'and the scope line still names the namespace the user drilled to, not an empty or a stale one'
    );
  } finally {
    await context.close();
  }
});

test('DW-323: a genuine AUTH.NOPRIVILEGE envelope renders the resolved privilege-denial sentence, naming the pair it carried', async () => {
  // The create is inside the try: `OnBeforeAllTests` builds its four principals one at a time, so
  // an error partway through leaves some of them on the container unless the teardown still runs.
  let fixture = null;
  try {
    fixture = createServedUserFixture();
    const { context, page } = await signedInAtScreen(SERVED_USER, fixture.password);
    try {
      // SERVEDUSER holds every instance-level pair, so it passed screen-outlet.ts's own
      // allowed() gate and this level served -- an instance-level denial would never have
      // reached this render at all (see the file header).
      const namespaces = await firstCells(page);
      assert.ok(
        namespaces.includes(fixture.refusedNamespace),
        `the seeded second namespace is listed, since SERVEDUSER holds READ on it: ${JSON.stringify(namespaces)}`
      );
      assert.equal(await page.$(REFUSAL_SELECTOR), null, 'the served namespaces level shows no refusal');

      await drillInto(page, fixture.refusedNamespace, 'dates');

      // Mutation (Rule 19, observed): disable refusalMessage's AUTH.NOPRIVILEGE arm
      // (error-log.page.ts) -> this assertion goes red, reading the generic
      // connectivityRequestRefused fragment ("request refused") instead of the resolved
      // sentence, while the LOG.NAMESPACE leg above stays green -- it never reaches this arm at
      // all. (Dropping only the non-empty `failedPair` check does NOT falsify this leg: the real
      // envelope here always carries a pair, so that guard is exercised by
      // error-log.page.spec.ts's no-pair case, not by this one.)
      assert.notEqual(await page.$(REFUSAL_SELECTOR), null, 'the refusal renders its own notice rather than a blank frame');
      assert.equal(
        await page.$eval(REFUSAL_SELECTOR, (node) => node.textContent.trim()),
        formatDeniedAction(STRINGS.privilegeDeniedAction, fixture.failedPair, STRINGS.errorLogRefusedAction),
        `the resolved privilegeDeniedAction sentence, naming the pair the real envelope carried (${fixture.failedPair}) -- not the generic connectivityRequestRefused fragment`
      );
    } finally {
      await context.close();
    }
  } finally {
    destroyServedUserFixture();
  }
});

/**
 * DW-293 / DW-307 -- a level cut at its row cap renders its own notice, over a genuine `truncated`
 * from the live port, not a stub. `error-log.page.spec.ts` drives `showLevelCapNotice` against a
 * fixture that says `truncated: true`; nothing before this pinned that the real endpoint's own
 * `maxRows` produces that flag or that the shipped bundle renders the notice from it.
 *
 * **Which date to drill into is read off the page, not assumed.** `SEED_NAMESPACE` accumulates
 * entries across every CI run that has ever exercised `OcuPilot.Test.ErrorLogSeed` or
 * `ErrorLogDenial` on this throwaway, over however many distinct days, so "today's date" and "the
 * date with the most rows" are both guesses. The dates level is read before seeding (when the
 * namespace is already listed) and after, and the target is whichever date's row count grew by at
 * least the two entries just seeded -- true regardless of what this instance already held.
 *
 * The outgoing `list` request for that date is then rewritten in flight (`armRewrite`, the same
 * technique the refusal leg above uses) to `maxRows=1`, so the live port genuinely cuts it and
 * answers `truncated: true` -- never a mocked response.
 *
 * Mutation (Rule 19): drop `truncated` from `LogSourcePort.ErrorRows`'s mapping (or, client-side,
 * delete the `showLevelCapNotice` branch from `error-log.page.ts`) -> this assertion goes red,
 * naming a level that was genuinely cut but rendered no notice.
 */
test('DW-293: a level cut at its row cap renders the cap notice, against a genuine truncation', async () => {
  const { context, page, armRewrite } = await signedInAtScreenIntercepting();
  try {
    let before = [];
    if ((await firstCells(page)).includes(SEED_NAMESPACE)) {
      await drillInto(page, SEED_NAMESPACE, 'dates');
      before = await dateCounts(page);
      await page.click(BACK_BUTTON);
      await settled(page, 'namespaces');
    }

    seedErrors(2);

    // The namespaces level was read once at sign-in, before the seed above landed -- a reload is
    // what makes the freshly seeded namespace and date visible here. Same origin, same session, so
    // the reload lands back on the signed-in shell rather than the sign-in form.
    await page.reload({ waitUntil: 'networkidle2' });
    await settled(page, 'namespaces');
    const namespacesAfter = await firstCells(page);
    assert.ok(
      namespacesAfter.includes(SEED_NAMESPACE),
      `the seeded namespace is listed after the reload: ${JSON.stringify(namespacesAfter)}`
    );

    await drillInto(page, SEED_NAMESPACE, 'dates');
    const after = await dateCounts(page);
    const grown = after.find((row) => {
      const prior = before.find((candidate) => candidate.date === row.date);
      return prior === undefined ? Number(row.count) >= 2 : Number(row.count) >= Number(prior.count) + 2;
    });
    assert.ok(
      grown !== undefined,
      `a date grew by (at least) the two errors just seeded: before ${JSON.stringify(before)} after ${JSON.stringify(after)}`
    );
    assert.equal(await page.$(REFUSAL_SELECTOR), null, 'the served dates level shows no refusal');
    assert.equal(await page.$('[data-ocu-drill="cap"]'), null, 'and no cap notice -- nothing here is cut yet');

    armRewrite('/api/ocupilot/logs/errors/list', 'maxRows', '1');
    await drillInto(page, grown.date, 'list');

    const rows = await firstCells(page);
    assert.equal(rows.length, 1, `the live port genuinely capped the list at one row: ${JSON.stringify(rows)}`);

    const notice = await page.$('[data-ocu-drill="cap"]');
    assert.notEqual(notice, null, 'the cut level renders its own cap notice rather than presenting as complete');
    assert.equal(
      await page.$eval('[data-ocu-drill="cap"]', (node) => node.textContent.trim()),
      STRINGS.errorLogLevelCapNotice,
      "naming the level-cap sentence, not the detail one and not the data table's reused max-rows sentence"
    );
  } finally {
    await context.close();
  }
});

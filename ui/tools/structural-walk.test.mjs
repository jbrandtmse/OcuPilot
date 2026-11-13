// Pins the structural walk (browser/structural-walk.mjs) without a browser: the fonts condition is a
// synchronous status read inside the settle loop; every walk page call is abandoned at the walk's
// deadline as a protocol timeout naming its pass and step; a pass whose call was abandoned is re-run
// once, with the report restored and one line naming it.
//
// Mutations (Rule 19):
// - restore `await document.fonts.ready` inside the settle evaluate -> the first test goes red, its
//   fake `fonts.ready` never resolving.
// - drop the `document.fonts.status === 'loaded'` term from the settle evaluate -> the first test
//   goes red on its lower bound: settle answered before the fonts reported loaded.
// - call `page.evaluate` or `page.waitForFunction` in the walk without `bounded(` -> the second test
//   goes red, naming the line.
// - drop `bounded(` from the settle evaluate, the `detectScreen` evaluate or the theme toggle's class
//   wait -> the matching hung-page case below goes red: its call is never abandoned, so the case runs
//   to its own 10 s timeout.
// - raise `WALKCALLDEADLINE` in `protocol-retry.mjs` above 60 s -> the hung-page cases go red on the
//   deadline they expect.
// - drop `bounded(` from detectScreen's `fieldNames(page)` call -> the field-names hung-page case red.
// - settle's label without `where` -> the settle-on-a-path case red; `goInApp` calling settle without
//   its path -> the goInApp case red.
// - drop the `report.retried.push(...)` from `passRetrier`'s reset, or its `failure` capture -> the
//   retried-pass case red.
// - rerun on the original browser (drop `current = await relaunch()`) -> the relaunch case red: the
//   rerun hangs twice and the pass fails.
// - drop the `await` on `reset()` in `retryOnce` -> the relaunch case red: the rerun starts before the
//   new browser is held.
// - drop the `error.retried` / message lines from `passRetrier`'s failure path -> the both-stall case
//   red.
// - open a pass's context through `browser` instead of `held` in `walk` -> the held-browser case red.
// - drop the `relaunch === null` return in `passRetrier`'s reset -> the no-relaunch case red.
// - drop the `withDeadline` around the stalled browser's `close()` -> the relaunch case red (its close
//   never resolves, so the rerun never starts).

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test, { afterEach, mock } from 'node:test';

import { CLOSEDEADLINE, WALKCALLDEADLINE, isProtocolTimeout, retryOnce } from '../browser/protocol-retry.mjs';

const { detectScreen, goInApp, passRetrier, reportLines, settle, toggleThemeThroughMenu } = await import(new URL('../browser/structural-walk.mjs', import.meta.url).href);

/** A fake page whose `evaluate(fn)` runs `fn` against the stubbed `document` installed by the test. */
function fakePage() {
  return { evaluate: async (fn, ...args) => fn(...args) };
}

test('settle answers true when fonts.ready never resolves but fonts.status turns loaded', { timeout: 30_000 }, async () => {
  const started = Date.now();
  const fonts = { ready: new Promise(() => {}), status: 'loading' };
  const timer = setTimeout(() => {
    fonts.status = 'loaded';
  }, 1000);
  const before = Object.getOwnPropertyDescriptor(globalThis, 'document');
  globalThis.document = { fonts, querySelector: () => null };
  try {
    const requests = { inflight: new Set(), last: Date.now() - 10_000 };
    let raceTimer;
    const settled = await Promise.race([
      settle(fakePage(), requests),
      new Promise((resolve) => {
        raceTimer = setTimeout(() => resolve('still waiting'), 5000);
      }),
    ]);
    clearTimeout(raceTimer);
    assert.equal(settled, true, 'settle answered rather than waiting on fonts.ready');
    const elapsed = Date.now() - started;
    assert.ok(elapsed >= 900, `and only once the fonts reported loaded (${elapsed} ms)`);
    assert.ok(elapsed < 5000, `and within 5 s (${elapsed} ms)`);
  } finally {
    clearTimeout(timer);
    if (before === undefined) delete globalThis.document;
    else Object.defineProperty(globalThis, 'document', before);
  }
});

test('every page call the walk issues goes through the per-call deadline', () => {
  const lines = readFileSync(new URL('../browser/structural-walk.mjs', import.meta.url), 'utf8').split('\n');
  const bare = [];
  let inFieldNames = false;
  lines.forEach((line, index) => {
    const declared = /^(?:export )?(?:async )?function (\w+)/.exec(line);
    // `fieldNames` runs under its caller's `bounded(` (detectScreen).
    if (declared !== null) inFieldNames = declared[1] === 'fieldNames';
    if (inFieldNames || !/\bpage\.(evaluate|evaluateHandle|waitForFunction|\$\$?eval|click|keyboard\.press)\(/.test(line) || /^\s*(\*|\/\/)/.test(line)) return;
    const context = lines.slice(Math.max(0, index - 3), index + 1).join('\n');
    if (!/\bbounded\(\s*$/m.test(context) && !/\bbounded\(.*\bpage\./.test(line)) bare.push(`line ${index + 1}: ${line.trim()}`);
  });
  assert.deepEqual(bare, [], 'no walk page call outside bounded()');
});

test("both of the walk's passes open their context on the browser the retrier holds", () => {
  const source = readFileSync(new URL('../browser/structural-walk.mjs', import.meta.url), 'utf8');
  const start = source.indexOf('export async function walk(');
  const end = source.indexOf('/** The walk\'s own report', start);
  assert.ok(start > 0 && end > start, 'the walk function is found');
  const body = source.slice(start, end);
  const opens = body.match(/signedInAt\(\s*(\w+)\s*,/g) ?? [];
  assert.equal(opens.length, 2, 'the walk opens two contexts, one per pass');
  assert.deepEqual(opens.map((call) => /signedInAt\(\s*(\w+)/.exec(call)[1]), ['held', 'held'], 'each through the browser its pass was handed, never the one `walk` started with');
});

// --- A walk call that never answers, run through the walk's own entry points ----------------------
//
// The deadline is the walk's real 60 s, advanced by mock timers rather than waited for. `hang` is a
// promise that never settles, the shape of a page call to a wedged tab.

// A case that fails while it holds the mock clock must not leave it to the next one.
afterEach(() => mock.timers.reset());

const hang = () => new Promise(() => {});
const flush = () => new Promise((resolve) => setImmediate(resolve));

/**
 * Start `call`, let it reach its hung page call, and answer how it ended: `'still waiting'` after the
 * deadline minus a millisecond has passed, then the rejection after the deadline itself.
 */
async function endOfHungCall(call) {
  mock.timers.enable({ apis: ['setTimeout'] });
  try {
    let outcome = 'still waiting';
    const running = call().then(
      () => {
        outcome = 'resolved';
      },
      (error) => {
        outcome = error;
      }
    );
    await flush();
    mock.timers.tick(WALKCALLDEADLINE - 1);
    await flush();
    assert.equal(outcome, 'still waiting', 'the call is not abandoned before the deadline');
    mock.timers.tick(1);
    await running;
    return outcome;
  } finally {
    mock.timers.reset();
  }
}

const quiet = () => ({ inflight: new Set(), last: Date.now() - 10_000, pass: '1280px light' });
const answersEverything = { click: async () => {}, waitForSelector: async () => {}, keyboard: { press: async () => {} } };

const hungCases = [
  ['settle', /1280px light: settle/, () => settle({ evaluate: hang }, quiet())],
  ['settle on a path', /1280px light: settle \/ocupilot\/tasks\/schedule timed out/, () => settle({ evaluate: hang }, quiet(), '/ocupilot/tasks/schedule')],
  [
    'detectScreen',
    /1280px light: detect tasks\/schedule/,
    () => detectScreen({ evaluate: hang }, { route: 'tasks/schedule', checks: ['name'], viewport: 1280, theme: 'light', minimums: [] }),
  ],
  [
    'detectScreen, at its field-name lookup',
    /1280px light: field names tasks\/schedule/,
    () =>
      detectScreen(
        { evaluate: async () => ({ violations: [], fields: [{ index: 0, element: 'input' }], unmeasurable: 0 }), createCDPSession: hang },
        { route: 'tasks/schedule', checks: ['name'], viewport: 1280, theme: 'light', minimums: [] }
      ),
  ],
  [
    "the theme toggle's wait for the new class",
    /1280px light: await theme class/,
    () => toggleThemeThroughMenu({ ...answersEverything, evaluate: async () => false, waitForFunction: hang }, quiet(), 30_000),
  ],
];

for (const [name, label, call] of hungCases) {
  test(`${name}, over a page call that never answers, is abandoned at the walk's deadline as a protocol timeout naming the step`, { timeout: 10_000 }, async () => {
    assert.equal(WALKCALLDEADLINE, 60_000, 'the deadline the walk uses');
    const error = await endOfHungCall(call);
    assert.ok(error instanceof Error, 'it rejected rather than resolving');
    assert.equal(isProtocolTimeout(error), true, 'in a shape retryOnce retries');
    assert.match(error.message, label, 'naming pass and step');
  });
}

test("goInApp names the path it moved to when the settle after it goes unanswered", { timeout: 10_000 }, async () => {
  mock.timers.enable({ apis: ['setTimeout', 'Date'] });
  try {
    let calls = 0;
    // The navigation's own evaluate answers; the settle evaluate after it never does.
    const page = { evaluate: async () => (++calls === 1 ? undefined : hang()), waitForFunction: async () => true };
    let outcome = 'still waiting';
    const running = goInApp(page, quiet(), '/ocupilot/tasks/schedule?ns=USER', 30_000).then(
      () => {
        outcome = 'resolved';
      },
      (error) => {
        outcome = error;
      }
    );
    await flush();
    mock.timers.tick(500);
    await flush();
    assert.equal(calls, 2, 'settle reached its evaluate once the page was quiet');
    mock.timers.tick(WALKCALLDEADLINE);
    await running;
    assert.ok(outcome instanceof Error && isProtocolTimeout(outcome), 'abandoned as a protocol timeout');
    assert.match(outcome.message, /1280px light: settle \/ocupilot\/tasks\/schedule\?ns=USER timed out/, 'naming the pass and the path');
  } finally {
    mock.timers.reset();
  }
});

test('a pass whose call hangs is re-run once and then completes, over a fake page', { timeout: 10_000 }, async () => {
  let attempts = 0;
  let resets = 0;
  const pass = () => {
    attempts += 1;
    // The first attempt's page hangs; the second answers.
    return settle({ evaluate: attempts === 1 ? hang : async () => true }, quiet());
  };
  mock.timers.enable({ apis: ['setTimeout'] });
  try {
    const finished = retryOnce(pass, () => {
      resets += 1;
    });
    await flush();
    mock.timers.tick(WALKCALLDEADLINE);
    assert.equal(await finished, true, 'the second attempt settled');
  } finally {
    mock.timers.reset();
  }
  assert.equal(attempts, 2, 'the pass ran twice');
  assert.equal(resets, 1, 'and was reset once between them');
});

/**
 * A launcher of fake browsers for `passRetrier`: browser 1's pages never answer `evaluate`, browser 2's
 * do. `close` on browser 1 never resolves when `stuckClose` is set. `stall` makes every browser hang.
 */
function fakeLauncher({ stuckClose = false, stall = false } = {}) {
  const launched = [];
  const launch = () => {
    const number = launched.length + 1;
    const browser = {
      number,
      closed: 0,
      page: { evaluate: number === 1 || stall ? hang : async () => true },
      close: () => {
        browser.closed += 1;
        return number === 1 && stuckClose ? hang() : Promise.resolve();
      },
    };
    launched.push(browser);
    return browser;
  };
  return { launched, launch };
}

const freshReport = () => ({ walked: new Set(), skipped: new Set(), unresolved: new Set(), unsettled: new Set(), unmeasurable: 0, retried: [] });

test('a pass whose browser stalls is rerun once on a newly launched browser, and the stalled one is closed', { timeout: 10_000 }, async () => {
  const report = freshReport();
  const entries = [];
  const launcher = fakeLauncher({ stuckClose: true });
  const first = launcher.launch();
  const withRetry = passRetrier(report, entries, first, async () => launcher.launch());
  const usedBy = [];
  mock.timers.enable({ apis: ['setTimeout'] });
  try {
    const finished = withRetry('720px light', async (found, browser) => {
      usedBy.push(browser.number);
      await settle(browser.page, { ...quiet(), pass: '720px light' }, '/ocupilot/tasks/schedule');
      found.push(`entry on browser ${browser.number}`);
    });
    await flush();
    mock.timers.tick(WALKCALLDEADLINE);
    await flush();
    assert.equal(first.closed, 1, 'the stalled browser was asked to close');
    assert.equal(launcher.launched.length, 1, 'and the rerun waits for it, or for the close deadline, before relaunching');
    mock.timers.tick(CLOSEDEADLINE);
    await finished;
  } finally {
    mock.timers.reset();
  }
  assert.deepEqual(usedBy, [1, 2], 'the pass ran on browser 1 and then on browser 2');
  assert.equal(launcher.launched.length, 2, 'one relaunch');
  assert.deepEqual(entries, ['entry on browser 2'], 'only the rerun on the new browser joins the walk');
  assert.equal(withRetry.held(), launcher.launched[1], 'the walk now holds the new browser');
  assert.equal(report.retried.length, 1, 'the report names the retried pass');
  assert.match(report.retried[0], /^720px light -- 720px light: settle \/ocupilot\/tasks\/schedule timed out/, 'and the call that was abandoned');
});

test('a pass whose rerun stalls too fails with the retried line on the error', { timeout: 10_000 }, async () => {
  const report = freshReport();
  const launcher = fakeLauncher({ stall: true });
  const withRetry = passRetrier(report, [], launcher.launch(), async () => launcher.launch());
  mock.timers.enable({ apis: ['setTimeout'] });
  let failure = null;
  try {
    const finished = withRetry('720px light', async (found, browser) => {
      await settle(browser.page, { ...quiet(), pass: '720px light' });
    }).catch((error) => {
      failure = error;
    });
    await flush();
    mock.timers.tick(WALKCALLDEADLINE);
    await flush();
    mock.timers.tick(WALKCALLDEADLINE);
    await finished;
  } finally {
    mock.timers.reset();
  }
  assert.equal(launcher.launched.length, 2, 'the rerun ran on a second browser');
  assert.ok(failure instanceof Error && isProtocolTimeout(failure), 'the pass failed on a protocol timeout');
  assert.equal(failure.retried?.length, 1, 'the error carries the retried line');
  assert.match(failure.retried[0], /^720px light -- 720px light: settle timed out/, 'naming the pass and the first call');
  assert.match(failure.message, /structural walk retried: 720px light -- /, 'and the message shows it');
});

test('without a relaunch a rerun keeps the browser it had', { timeout: 10_000 }, async () => {
  const report = freshReport();
  const only = { number: 1, page: { evaluate: hang } };
  const withRetry = passRetrier(report, [], only);
  let attempts = 0;
  const seen = [];
  mock.timers.enable({ apis: ['setTimeout'] });
  try {
    const finished = withRetry('720px light', async (found, browser) => {
      attempts += 1;
      seen.push(browser);
      if (attempts === 1) await settle(browser.page, quiet());
    });
    await flush();
    mock.timers.tick(WALKCALLDEADLINE);
    await finished;
  } finally {
    mock.timers.reset();
  }
  assert.deepEqual(seen, [only, only], 'both runs used the one browser');
});

test('a call that answers in time is untouched by the deadline', async () => {
  const found = { violations: [], fields: [], unmeasurable: 3 };
  const result = await detectScreen({ evaluate: async () => found }, { route: 'tasks/schedule', checks: ['contrast'], viewport: 1280, theme: 'dark', minimums: [] });
  assert.deepEqual(result, { entries: [], unmeasurable: 3 });
});

test('a pass retried after an abandoned call leaves the report as it was before the pass, plus one line naming the pass and the call', { timeout: 10_000 }, async () => {
  const report = { walked: new Set(['before']), skipped: new Set(), unresolved: new Set(), unsettled: new Set(), unmeasurable: 0, retried: [] };
  const entries = [];
  let attempts = 0;
  const withRetry = passRetrier(report, entries, null);
  mock.timers.enable({ apis: ['setTimeout'] });
  try {
    const finished = withRetry('720px light', async (found) => {
      attempts += 1;
      report.walked.add(`visit ${attempts}`);
      report.unmeasurable += 1;
      if (attempts === 1) await settle({ evaluate: hang }, { ...quiet(), pass: '720px light' }, '/ocupilot/tasks/schedule');
      found.push(`entry ${attempts}`);
    });
    await flush();
    mock.timers.tick(WALKCALLDEADLINE);
    await finished;
  } finally {
    mock.timers.reset();
  }
  assert.equal(attempts, 2, 'the pass ran twice');
  assert.deepEqual(entries, ['entry 2'], 'only the completed run joins the walk');
  assert.deepEqual([...report.walked], ['before', 'visit 2'], 'the first run\'s visits are put back');
  assert.equal(report.unmeasurable, 1, 'and its counts');
  assert.equal(report.retried.length, 1, 'one retried line');
  assert.match(report.retried[0], /^720px light -- 720px light: settle \/ocupilot\/tasks\/schedule timed out/, 'naming the pass and the abandoned call');
});

test("the walk's report names each retried pass", () => {
  const lines = reportLines({
    declared: 1,
    notBuilt: [],
    walked: new Set(),
    skipped: new Set(),
    unresolved: new Set(),
    unsettled: new Set(),
    unmeasurable: 0,
    retried: ['720px light -- 720px light: settle timed out.'],
  });
  assert.ok(lines.some((line) => line.includes('pass retried once') && line.includes('720px light -- 720px light: settle')), lines.join('\n'));
});

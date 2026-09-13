import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

/**
 * The one crossing `refresh.test.mjs` cannot exercise: every construction there hands
 * `RefreshService` a hand-rolled `{ retryWhenReachable(key, run) { parks.push(...) } }` stub, so
 * "a fault suspends and parks exactly one re-arm" is pinned against a recorder, never against
 * `ConnectivityService.drain()` actually calling the closure back. This file wires the REAL
 * `ApiService` and the REAL `ConnectivityService` -- the same classes `src/main.ts` constructs,
 * connected exactly as `onFault: (fault) => connectivity.note(fault)` connects them there --
 * behind a registered read that is itself a genuine `ApiService.requestJson` call, the shape
 * Story 2.3's screen read will have. Mirrors `fault-banner.wire.spec.ts` (Story 1.13) and
 * `fault.test.mjs`'s own `wired()` harness: a real service pair over an injected `fetch`,
 * asserted against the REAL `RefreshService`'s own state rather than a stand-in for either half.
 *
 * **Why this matters more than a stub can show.** The suspend/park/resume interaction is the
 * same family that produced three HIGHs in Story 1.13 and this story's own `NaN`-expiry defect
 * (`refresh.test.mjs`, "an expiry that is not a moment within AD-6 cannot become a re-arm loop"):
 * a recovery path that is only ever driven by hand never proves the real trigger actually fires
 * it. Here the trigger is `ConnectivityService`'s own backoff-armed probe, driven at its
 * `schedule` seam by hand (never a real clock), and the resume is `drain()` calling the closure
 * `RefreshService.suspend()` registered -- not a test calling `resume()` or replaying a recorded
 * park itself.
 *
 * No test here waits on a clock: cadence and backoff are each `delayMs` handed to their own
 * injected `schedule` seam, captured and fired by hand.
 *
 * Mutation (Rule 19): delete `this.connectivity.retryWhenReachable(REFRESH_PARK_KEY, () =>
 * this.resume())` from `RefreshService.suspend()` -> the real probe still arms and drains (that
 * machinery is Story 1.13's and untouched), but nothing is registered for it to run, so
 * `armedFor()` never leaves `'none'` and the timer is stranded forever. Demonstrated 2026-09-12.
 */

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);

const { RefreshService, REFRESH_PARK_KEY } = await import(corePath('refresh.ts'));
const { ChangeBus } = await import(corePath('change-bus.ts'));
const { ScreenStores } = await import(corePath('screen-store.ts'));
const { PreferenceStore } = await import(corePath('preferences.ts'));
const { ConnectivityService, PROBE_BACKOFF_BASE_MS } = await import(corePath('connectivity.ts'));
const { ApiService } = await import(corePath('api.ts'));
const { Session } = await import(corePath('session.ts'));
const { TokenStore } = await import(corePath('token-store.ts'));
const { classifyFault } = await import(corePath('fault.ts'));

const NOW_MS = 1_700_000_000_000;
const DESCRIPTOR = 'OcuPilot.Screen.Descriptor.Probe';
const READ_PATH = '/api/ocupilot/probe/rows';

function memoryStorage() {
  const map = new Map();
  return {
    getItem: (key) => (map.has(key) ? map.get(key) : null),
    setItem: (key, value) => map.set(key, value),
    removeItem: (key) => map.delete(key),
  };
}

function screen(extra = {}) {
  return {
    descriptor: DESCRIPTOR,
    route: 'os-management/processes',
    area: 'os-management',
    labelKey: 'navAreaOsManagement',
    sideBarPosition: 1,
    archetype: 'list',
    built: true,
    refreshes: true,
    refreshRates: [10],
    privileges: [],
    entityType: 'process',
    secondaryEntityTypes: [],
    scope: 'namespace',
    parentScope: '',
    id: { kind: 'single', parts: [] },
    context: { fields: [], secretFields: [] },
    primaryAction: { id: '', selfProtection: '' },
    rowActions: [],
    emptyStateKey: '',
    commandAliases: [],
    classicPage: '',
    classicLinkExemption: { exempt: false, reason: '' },
    toolIdentifier: 'probe',
    ...extra,
  };
}

/** Let every microtask queued by the real services run out, the same idiom `fault.test.mjs` uses. */
async function settle() {
  for (let i = 0; i < 8; i++) await new Promise((resolve) => setImmediate(resolve));
}

/**
 * The framework wired over the real `ApiService` and `ConnectivityService`, over an injected
 * `fetch` this test controls the outcome of. `mode` starts `'throw'` -- a transport fault, the
 * same `TypeError` `api.test.mjs` and `fault-banner.wire.spec.ts` model "the request never got
 * an answer" with -- and switches to `'ok'` for the instance answering again.
 *
 * The registered read is not a stand-in: it is a real `api.requestJson(READ_PATH)` call, wrapped
 * exactly the way a Story 2.3 screen read will wrap one -- a `JsonResult` translated into
 * `RefreshReadResult` by handing an error straight to `classifyFault` for a `fault`, and its body
 * for `ok`. That is what makes the fault this test observes on `RefreshService` the same object
 * `ConnectivityService.note()` was told about, not two faults built by two constructors that
 * happen to agree today.
 */
function wired() {
  let mode = 'throw';
  const httpCalls = [];
  const refreshScheduled = [];
  const connectivityScheduled = [];

  const fetchImpl = async (path) => {
    httpCalls.push(path);
    if (mode === 'throw') throw new TypeError('Failed to fetch');
    return { status: 200, text: async () => JSON.stringify({ rows: ['a', 'b'] }) };
  };

  const tokens = new TokenStore({ storage: memoryStorage(), navigationType: () => 'navigate' });
  const session = new Session({ fetch: fetchImpl, tokens, now: () => NOW_MS, schedule: () => {} });
  // Declared before `api` exists, exactly as `src/main.ts` declares it: the arrow is not called
  // until a probe is actually issued, long after both bindings below are initialised.
  const connectivity = new ConnectivityService({
    api: () => api,
    schedule: (run, delayMs) => connectivityScheduled.push({ run, delayMs }),
  });
  const api = new ApiService({
    fetch: fetchImpl,
    tokens,
    session,
    onFault: (fault) => connectivity.note(fault),
  });

  const read = async () => {
    const result = await api.requestJson(READ_PATH);
    if (result.kind === 'ok') {
      return { kind: 'ok', rows: result.body?.rows ?? [], truncated: false };
    }
    // The same classifier `ApiService.report` already ran, called again here exactly as a
    // Story 2.3 screen read will call it: `refresh.ts` itself imports no `ApiService` and
    // classifies nothing (`ui/tools/refresh.test.mjs`'s own source-scan pins that), so a real
    // consumer of the registered-read contract is the one place a `Fault` can be built from it.
    return { kind: 'fault', fault: classifyFault(result, READ_PATH) };
  };

  const bus = new ChangeBus({ now: () => new Date(NOW_MS) });
  const preferences = new PreferenceStore({ storage: memoryStorage() });
  const stores = new ScreenStores({ preferences });
  const refresh = new RefreshService({
    stores,
    connectivity,
    bus,
    namespace: () => 'HSCUSTOM',
    schedule: (run, delayMs) => refreshScheduled.push({ run, delayMs }),
    now: () => new Date(NOW_MS),
  });

  return {
    api,
    connectivity,
    refresh,
    stores,
    httpCalls,
    refreshScheduled,
    connectivityScheduled,
    read,
    setMode(next) {
      mode = next;
    },
    /** Fire the arm most recently handed to refresh's own seam, as a browser's timer would. */
    async fireRefresh() {
      refreshScheduled[refreshScheduled.length - 1].run();
      await settle();
    },
    /** Fire the arm most recently handed to connectivity's own probe backoff. */
    async fireProbe() {
      connectivityScheduled[connectivityScheduled.length - 1].run();
      await settle();
    },
  };
}

test(
  'suspend-then-resume completes against the REAL ConnectivityService: a transport fault ' +
    'reported through the real ApiService suspends the timer, the real probe backoff arms ' +
    'itself from that same fault, and draining it -- not a test calling resume() -- is what ' +
    'brings the tick back',
  async () => {
    const harness = wired();
    harness.refresh.bind(screen(), harness.read);
    harness.refresh.setRate(10);

    await harness.fireRefresh();

    assert.equal(harness.refresh.armedFor(), 'none', 'the fault suspended the timer');
    assert.equal(
      harness.connectivity.fault()?.kind,
      'unreachable',
      "the SAME classified fault reached the REAL connectivity service, not a copy of it"
    );
    assert.equal(
      harness.connectivityScheduled.length,
      1,
      'the real probe backoff armed itself from that one fault'
    );
    assert.equal(harness.connectivityScheduled[0].delayMs, PROBE_BACKOFF_BASE_MS);

    // Nothing the refresh seam still holds can revive it while suspended -- the framework
    // never probes and never re-arms itself (AD-43).
    assert.deepEqual(harness.refreshScheduled.slice(1), [], 'no second refresh arm was made');

    // The instance answers again. Firing the REAL probe's own backoff arm is what drains
    // `ConnectivityService`'s pending set, which is what calls the closure `suspend()`
    // registered under `REFRESH_PARK_KEY` -- never a test calling `resume()` directly.
    harness.setMode('ok');
    await harness.fireProbe();

    assert.equal(
      harness.refresh.armedFor(),
      'tick',
      'the real drain() is what resumed the timer, not a stub park array replayed by hand'
    );
    assert.equal(harness.connectivity.fault(), null, 'and the verdict itself cleared');

    await harness.fireRefresh();

    assert.deepEqual(harness.stores.for(DESCRIPTOR, [10]).data(), ['a', 'b']);
    assert.notEqual(harness.stores.for(DESCRIPTOR, [10]).lastUpdate(), null);
    assert.equal(harness.refresh.armedFor(), 'tick', 'and the cadence continues');
  }
);

// --- DW-167: a connection accepted and never answered aborts, and the chain continues ---------
//
// Every other reachability failure this suite models rejects: a refused connection, a dropped
// one, a DNS failure. `fetch` rejects, `requestJson` catches and returns `status: 0`,
// `ConnectivityService.note()` sees `unreachable` and arms the next probe. A host that completes
// the handshake and then says nothing produces no rejection at all -- the promise never settles,
// `runProbe`'s `await` never resumes, `probeArmed` was cleared before the call, and no further
// probe is ever scheduled. The banner sits on `checking` with no timer and no request
// outstanding, which is DW-119's own condition reached by a route no timer covered.
//
// Driven with a real `AbortController`: the injected `fetch` never resolves on its own and
// settles only when the signal it was handed fires, which is exactly what a half-open socket
// does to the browser's own `fetch`. Nothing here waits on a wall clock -- the abort timer is
// the one real `setTimeout` in the file, and it is set to a handful of milliseconds.
//
// Mutation (Rule 19): drop `timeoutMs: PROBE_TIMEOUT_MS` from `ConnectivityService.runProbe()`,
// or delete `ApiService.arm()`'s controller -> the probe never settles, `drain()` is never
// reached, and every assertion below times out rather than failing fast. Verified 2026-09-13.

const { PROBE_TIMEOUT_MS } = await import(corePath('connectivity.ts'));

/** A `fetch` that accepts the connection and answers only if its own signal aborts. */
function halfOpenFetch(calls) {
  return (path, init) =>
    new Promise((resolve, reject) => {
      calls.push({ path, signal: init?.signal ?? null });
      const signal = init?.signal;
      if (!signal) return; // never settles, which is the defect
      if (signal.aborted) {
        reject(new DOMException('The operation was aborted.', 'AbortError'));
        return;
      }
      signal.addEventListener('abort', () => {
        reject(new DOMException('The operation was aborted.', 'AbortError'));
      });
    });
}

test('DW-167: the probe carries an abort timeout, so a half-open connection does not stall it', async () => {
  const calls = [];
  const scheduled = [];
  const fetchImpl = halfOpenFetch(calls);

  const tokens = new TokenStore({ storage: memoryStorage(), navigationType: () => 'navigate' });
  const session = new Session({ fetch: fetchImpl, tokens, now: () => NOW_MS, schedule: () => {} });
  // The deadline is injected, small: it is enforced inside `fetch` by an `AbortSignal` rather
  // than by this service's own scheduler, so it is the one thing here a test cannot fire by
  // hand -- and waiting out the real ten seconds would put a wall clock in a file whose header
  // says it has none. The production value is asserted separately, below.
  const connectivity = new ConnectivityService({
    api: () => api,
    schedule: (run, delayMs) => scheduled.push({ run, delayMs }),
    probeTimeoutMs: 5,
  });
  const api = new ApiService({
    fetch: fetchImpl,
    tokens,
    session,
    onFault: (fault) => connectivity.note(fault),
  });

  // A parked re-read, so "the chain continues" is observable as the park actually running rather
  // than only as a second probe being scheduled.
  let drained = 0;
  connectivity.retryWhenReachable(READ_PATH, () => {
    drained += 1;
  });

  const probe = connectivity.retry();
  await settle();

  assert.equal(calls.length, 1, 'the probe reached the network exactly once');
  assert.ok(calls[0].signal, 'and carried an abort signal, which is what a half-open socket needs');
  assert.equal(
    calls[0].signal.aborted,
    false,
    'not already aborted: the timeout is a deadline, not an immediate cancellation'
  );

  // The abort fires on the real timer the service armed. Waiting for the signal itself rather
  // than for a duration keeps this independent of how long the deadline is.
  await new Promise((resolve) => {
    if (calls[0].signal.aborted) return resolve();
    calls[0].signal.addEventListener('abort', resolve);
  });
  await settle();

  assert.equal(calls[0].signal.aborted, true, 'the request was aborted at its deadline');
  const fault = connectivity.fault();
  assert.ok(fault, 'and the abort was classified as a fault rather than swallowed');
  assert.equal(fault.kind, 'unreachable', 'an aborted request is unreachable, the same as a refused one');
  assert.ok(scheduled.length >= 1, 'so the backoff chain re-armed rather than stalling');
  assert.equal(drained, 0, 'and nothing was drained: the instance never answered');

  void probe;
});

test('DW-167: the timeout is longer than the backoff cap, so a slow instance is not cut off', async () => {
  const { PROBE_BACKOFF_MAX_MS } = await import(corePath('connectivity.ts'));
  assert.ok(
    PROBE_TIMEOUT_MS > PROBE_BACKOFF_MAX_MS,
    `a probe deadline shorter than the backoff cap would abort answers the instance was about to give: ${PROBE_TIMEOUT_MS} vs ${PROBE_BACKOFF_MAX_MS}`
  );
});

test('DW-167: an ordinary read carries no deadline, so a slow answer is never cancelled', async () => {
  const calls = [];
  const fetchImpl = async (path, init) => {
    calls.push({ path, signal: init?.signal ?? null });
    return { status: 200, text: async () => '{}' };
  };
  const tokens = new TokenStore({ storage: memoryStorage(), navigationType: () => 'navigate' });
  const session = new Session({ fetch: fetchImpl, tokens, now: () => NOW_MS, schedule: () => {} });
  const api = new ApiService({ fetch: fetchImpl, tokens, session });

  await api.requestJson(READ_PATH);
  assert.equal(calls.length, 1);
  assert.equal(
    calls[0].signal,
    null,
    'a read a user is waiting on is better slow than cancelled -- only the probe sets a deadline'
  );
});

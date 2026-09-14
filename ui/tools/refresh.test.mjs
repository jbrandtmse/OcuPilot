import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { readdirSync, readFileSync, statSync } from 'node:fs';

// Pins the one auto-refresh framework (AD-43): one timer behind an injected seam, one persisted
// per-screen setting, one silent re-fetch through the screen's own registered read, and the
// proposal pause with its three-condition resume.
//
// **No test here waits on a clock.** Cadence and expiry are the `delayMs` handed to the injected
// `schedule` seam, driven by hand, exactly as `fault.test.mjs` drives the connectivity backoff;
// the tick's stamp and the expiry sweep read an injected `now`. Nothing starts a container.
//
// Mutations (Rule 19):
// - drop the generation guard inside the scheduled callback -> "a rate change orphans the
//   previous generation" goes red with two reads per interval.
// - have `applyTick` write selection or scroll as well -> "a tick replaces three slots and
//   nothing else" goes red, and a user's selection would vanish under them every ten seconds.
// - replace the three-condition `canArm()` with a `paused` boolean cleared by `proposal-closed`
//   -> "a proposal-closed does not resume a fault-suspended timer" goes red.
// - make the live-proposal set a boolean -> "two opens and one close stays paused" goes red.
// - re-arm after a fault instead of parking -> "a fault suspends and parks exactly one re-arm"
//   goes red with a non-zero arm count.
// - let `bind` accept a refreshing screen with no read -> the refusal row goes red, and the
//   framework would be issuing a read AD-36 says it does not have.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);
const { screenDeclaration } = await import(
  join(uiRoot, 'src', 'app', 'testing', 'screen-declaration.ts')
);

const {
  RefreshService,
  REFRESH_PARK_KEY,
  MISSING_READ_MESSAGE,
  formatAutoRefreshOn,
  formatLastUpdate,
} = await import(corePath('refresh.ts'));
const { ChangeBus } = await import(corePath('change-bus.ts'));
const { ScreenStores, DEFAULT_MAX_ROWS } = await import(corePath('screen-store.ts'));
const { PreferenceStore, SCREEN_REFRESH_RATES_KEY } = await import(corePath('preferences.ts'));
const { STRINGS } = await import(corePath('strings.ts'));

const NOW_MS = 1_700_000_000_000;
const DESCRIPTOR = 'OcuPilot.Screen.Descriptor.Probe';

const settle = () => new Promise((resolve) => setImmediate(resolve));

function memoryStorage() {
  const map = new Map();
  return {
    getItem: (key) => (map.has(key) ? map.get(key) : null),
    setItem: (key, value) => map.set(key, value),
    removeItem: (key) => map.delete(key),
    map,
  };
}

/** A screen declaration shaped the way the mirror shapes one. */
function screen(extra = {}) {
  return screenDeclaration({
    descriptor: DESCRIPTOR,
    route: 'os-management/processes',
    area: 'os-management',
    labelKey: 'navAreaOsManagement',
    refreshes: true,
    refreshRates: [10],
    entityType: 'process',
    scope: 'namespace',
    ...extra,
  });
}

/**
 * The framework wired the way `src/main.ts` wires it, with both seams in the test's hands and a
 * connectivity stub that records the one park a fault is allowed to make.
 */
function wired(options = {}) {
  const scheduled = [];
  const parks = [];
  const storage = options.storage ?? memoryStorage();
  let nowMs = options.nowMs ?? NOW_MS;

  const reads = [];
  let answer = options.answer ?? (() => ({ kind: 'ok', rows: ['a', 'b'], truncated: false }));
  const read = async (init) => {
    reads.push(init);
    return answer(reads.length);
  };

  const connectivity = {
    retryWhenReachable(key, run) {
      parks.push({ key, run });
    },
  };
  const bus = new ChangeBus({ now: () => new Date(nowMs) });
  const preferences = new PreferenceStore({ storage });
  const stores = new ScreenStores({ preferences });
  const refresh = new RefreshService({
    stores,
    connectivity,
    bus,
    namespace: options.namespace ?? (() => 'HSCUSTOM'),
    schedule: (run, delayMs) => scheduled.push({ run, delayMs }),
    now: () => new Date(nowMs),
  });

  return {
    refresh,
    bus,
    stores,
    preferences,
    storage,
    scheduled,
    parks,
    reads,
    read,
    setAnswer(next) {
      answer = next;
    },
    advanceNow(ms) {
      nowMs += ms;
    },
    nowMs: () => nowMs,
    /** Fire the arm most recently handed to the seam, as a browser's timer would. */
    async fire() {
      scheduled[scheduled.length - 1].run();
      await settle();
    },
  };
}

// --- Binding -------------------------------------------------------------------------------

test('binding a refreshing screen arms one tick at the declared rate, and the chip reads it', async () => {
  const harness = wired();
  harness.refresh.bind(screen(), harness.read);
  harness.refresh.setRate(10);

  const armed = harness.scheduled.filter((entry) => entry.delayMs === 10_000);
  assert.equal(armed.length, 1, 'one arm at the seam');
  assert.equal(armed[0].delayMs, 10_000, 'ten declared seconds, in milliseconds');
  assert.equal(harness.refresh.armedFor(), 'tick');
  assert.equal(harness.refresh.chipLabel(), 'Auto-refresh: every 10 s');
});

test('binding a non-refreshing screen arms nothing and draws no chip', () => {
  const harness = wired();
  harness.refresh.bind(screen({ refreshes: false, refreshRates: [] }));

  assert.deepEqual(harness.scheduled, [], 'nothing is armed');
  assert.equal(harness.refresh.armedFor(), 'none');
  assert.equal(harness.refresh.chipLabel(), '', 'and the bar has no chip to draw');
  assert.equal(harness.refresh.lastUpdate(), null, 'so the band has no stamp either');
});

test('AD-36: binding a refreshing screen that registered no read is refused, naming the descriptor', () => {
  const harness = wired();
  assert.throws(
    () => harness.refresh.bind(screen()),
    (error) => {
      assert.ok(error.message.startsWith(MISSING_READ_MESSAGE), 'the refusal says what is missing');
      assert.match(error.message, /OcuPilot\.Screen\.Descriptor\.Probe/, 'and which screen');
      return true;
    }
  );
  assert.deepEqual(harness.scheduled, [], 'and nothing was armed on the way out');
  assert.equal(harness.refresh.descriptor(), '', 'nor was anything bound');
});

test('the chip reads off until a rate is set, and off is what an unset screen persists as', () => {
  const harness = wired();
  harness.refresh.bind(screen(), harness.read);

  assert.equal(harness.refresh.rate(), 0);
  assert.equal(harness.refresh.chipLabel(), STRINGS.statusAutoRefreshOff);
  assert.equal(harness.refresh.armedFor(), 'none', 'off arms nothing');
});

// --- The tick ------------------------------------------------------------------------------

test('a tick replaces data, truncated and lastUpdate and nothing else', async () => {
  const harness = wired();
  harness.setAnswer(() => ({ kind: 'ok', rows: ['r1', 'r2'], truncated: true }));
  harness.refresh.bind(screen(), harness.read);

  const store = harness.stores.for(DESCRIPTOR, [10]);
  store.setSort('name');
  store.setFilter('csp');
  store.setSelection(['r1']);
  store.setScroll(240);
  store.setMaxRows(500);
  harness.refresh.setRate(10);

  const before = {
    sort: store.sort(),
    filter: store.filter(),
    selection: store.selection(),
    scroll: store.scroll(),
    maxRows: store.maxRows(),
    rate: store.rate(),
  };

  await harness.fire();

  assert.equal(harness.reads.length, 1, 'exactly one call to the registered read');
  assert.deepEqual(harness.reads[0], { maxRows: 500 }, 'carrying the store\'s own cap (AD-36)');
  assert.deepEqual(store.data(), ['r1', 'r2']);
  assert.equal(store.truncated(), true, 'and the truncation flag the read reported');
  assert.equal(store.lastUpdate()?.getTime(), NOW_MS);

  assert.deepEqual(
    {
      sort: store.sort(),
      filter: store.filter(),
      selection: store.selection(),
      scroll: store.scroll(),
      maxRows: store.maxRows(),
      rate: store.rate(),
    },
    before,
    'sort, filter, selection, scroll, max rows and the rate are identical before and after'
  );
});

test('the default cap is what an untouched screen reads with', async () => {
  const harness = wired();
  harness.refresh.bind(screen(), harness.read);
  harness.refresh.setRate(10);
  await harness.fire();
  assert.deepEqual(harness.reads[0], { maxRows: DEFAULT_MAX_ROWS }, 'no read is unbounded (AD-36)');
});

test('one arm at a time across bind, rate change and unbind', async () => {
  const harness = wired({ storage: memoryStorage() });
  harness.refresh.bind(screen({ refreshRates: [10, 30] }), harness.read);
  harness.refresh.setRate(10);
  assert.equal(harness.refresh.armedFor(), 'tick');

  harness.refresh.setRate(30);
  assert.equal(harness.refresh.armedFor(), 'tick', 'still exactly one');
  assert.equal(harness.scheduled[harness.scheduled.length - 1].delayMs, 30_000);

  harness.refresh.unbind();
  assert.equal(harness.refresh.armedFor(), 'none', 'and none after the screen is let go');

  // Every callback the seam still holds is now stale. Firing all of them issues no read and
  // arms nothing: the count is the falsifiable form of "exactly one pending arm".
  for (const entry of harness.scheduled) entry.run();
  await settle();
  assert.deepEqual(harness.reads, [], 'no orphaned generation ticks');
  assert.equal(harness.refresh.armedFor(), 'none');
});

test('a rate change orphans the previous generation, so the old cadence never ticks', async () => {
  const harness = wired();
  harness.refresh.bind(screen({ refreshRates: [10, 30] }), harness.read);
  harness.refresh.setRate(10);
  const orphan = harness.scheduled[harness.scheduled.length - 1];

  harness.refresh.setRate(30);
  orphan.run();
  await settle();

  assert.deepEqual(harness.reads, [], "the 10 s arm returns without reading and without re-arming");
  assert.equal(harness.refresh.armedFor(), 'tick', 'the 30 s arm is the one pending arm');

  await harness.fire();
  assert.equal(harness.reads.length, 1, 'and it is the one that ticks');
});

test('re-binding the same descriptor with a different read switches to the new read', async () => {
  // Stores are keyed by descriptor so a detail screen's several URLs share one, which is exactly
  // when the same descriptor is re-bound with a read that closes over a different entity id. A
  // guard on the descriptor alone would keep ticking the previous id's read into the store the
  // screen renders.
  const harness = wired();
  const calls = [];
  const readA = async () => {
    calls.push('A');
    return { kind: 'ok', rows: ['a'], truncated: false };
  };
  const readB = async () => {
    calls.push('B');
    return { kind: 'ok', rows: ['b'], truncated: false };
  };

  harness.refresh.bind(screen(), readA);
  harness.refresh.setRate(10);
  harness.refresh.bind(screen(), readB);
  await harness.fire();

  assert.deepEqual(calls, ['B'], 'the tick calls the read bound last, not the one bound first');
  assert.deepEqual(harness.stores.for(DESCRIPTOR, [10]).data(), ['b']);

  // And re-binding the identical pair is still the no-op it has to be: a component that binds on
  // every change detection must not re-arm the timer on every keystroke.
  const armsBefore = harness.scheduled.length;
  harness.refresh.bind(screen(), readB);
  assert.equal(harness.scheduled.length, armsBefore, 'an identical re-bind arms nothing new');
});

test('a read overtaken by a later one cannot write the store under a newer stamp', async () => {
  // Two reads are in flight whenever one outlives the interval a transition re-armed. Whichever
  // answers last would otherwise win, and `applyTick` stamps the moment it applies -- so the
  // older rows would land under the later `Last update`, a stamp claiming a freshness they have
  // not got.
  const harness = wired();
  const releases = [];
  let issued = 0;
  harness.setAnswer(() => {
    issued += 1;
    const which = issued;
    return new Promise((resolve) => {
      releases.push(() => resolve({ kind: 'ok', rows: ['read' + which], truncated: false }));
    });
  });
  harness.refresh.bind(screen(), harness.read);
  harness.refresh.setRate(10);

  harness.scheduled[harness.scheduled.length - 1].run(); // read #1 goes out
  await settle();
  // A transition mid-flight re-arms, and that arm fires while #1 is still out.
  openProposal(harness, 'p-1');
  closeProposal(harness, 'p-1');
  harness.scheduled[harness.scheduled.length - 1].run(); // read #2 goes out
  await settle();
  assert.equal(harness.reads.length, 2, 'two reads really are in flight');

  const store = harness.stores.for(DESCRIPTOR, [10]);
  harness.advanceNow(1000);
  releases[1](); // the newer read answers first
  await settle();
  assert.deepEqual(store.data(), ['read2']);
  const stampAfterNewest = store.lastUpdate()?.getTime();

  harness.advanceNow(1000);
  releases[0](); // the older read answers last, and must not win
  await settle();

  assert.deepEqual(store.data(), ['read2'], "the overtaken read's rows are dropped");
  assert.equal(store.lastUpdate()?.getTime(), stampAfterNewest, 'and so is its stamp');
});

test('a read that throws takes the failure path instead of dying as an unhandled rejection', async () => {
  // `RefreshRead` is a type, not an enforcement. A read that rejects left the timer stopped with
  // nothing parked and no trigger left -- the shape Story 1.13 met three times.
  const harness = wired();
  harness.setAnswer(() => {
    throw new Error('the screen read broke');
  });
  harness.refresh.bind(screen(), harness.read);
  harness.refresh.setRate(10);

  await harness.fire();

  assert.equal(harness.refresh.armedFor(), 'none', 'the timer suspended');
  assert.equal(harness.parks.length, 1, 'and parked the one re-arm, exactly as a Fault does');
  assert.equal(harness.parks[0].key, REFRESH_PARK_KEY);

  harness.setAnswer(() => ({ kind: 'ok', rows: ['back'], truncated: false }));
  harness.parks[0].run();
  assert.equal(harness.refresh.armedFor(), 'tick', 'and the park is what brings it back');
});

test('a fault kind the banner has no copy for suspends and parks like any other', async () => {
  // The matrix row says "any FaultKind", and `isBannerFault` covers two of six. This module does
  // not read the kind at all, which is what makes that true -- and what leaves the park as the
  // only trigger for the four kinds that arm no probe (`connectivity.ts`, AD-8).
  const harness = wired();
  harness.setAnswer(() => ({
    kind: 'fault',
    fault: { kind: 'refused', status: 403, code: 'AUTH.NOADMIN', path: '/api/ocupilot/probe' },
  }));
  harness.refresh.bind(screen(), harness.read);
  harness.refresh.setRate(10);

  await harness.fire();

  assert.equal(harness.refresh.armedFor(), 'none');
  assert.equal(harness.parks.length, 1, 'one park, whatever the kind');
  assert.equal(harness.reads.length, 1, 'and no retry of its own (AD-8)');
});

test('a tick re-arms at the same rate, so the cadence continues', async () => {
  const harness = wired();
  harness.refresh.bind(screen(), harness.read);
  harness.refresh.setRate(10);

  await harness.fire();
  assert.equal(harness.refresh.armedFor(), 'tick');
  assert.equal(harness.scheduled[harness.scheduled.length - 1].delayMs, 10_000);

  await harness.fire();
  assert.equal(harness.reads.length, 2, 'two intervals, two reads');
});

// --- The fault path -------------------------------------------------------------------------

test('a fault suspends and parks exactly one re-arm, and the park is the only trigger left', async () => {
  const harness = wired();
  harness.setAnswer(() => ({
    kind: 'fault',
    fault: { kind: 'unreachable', status: 0, code: null, path: '/api/ocupilot/probe' },
  }));
  harness.refresh.bind(screen(), harness.read);
  harness.refresh.setRate(10);

  await harness.fire();

  assert.equal(harness.refresh.armedFor(), 'none', 'the timer suspended rather than re-arming');
  assert.equal(harness.parks.length, 1, 'and parked exactly one re-arm');
  assert.equal(harness.parks[0].key, REFRESH_PARK_KEY, 'keyed, so repeats collapse');

  // Nothing the seam still holds can revive it: the framework never probes and never re-arms
  // itself, which is the whole of "no second probe, no second timer".
  const before = harness.scheduled.length;
  for (const entry of harness.scheduled) entry.run();
  await settle();
  assert.equal(harness.scheduled.length, before, 'no arm was added by a stale callback');
  assert.equal(harness.reads.length, 1, 'and no second read was issued');

  // The instance answers again: connectivity drains its pending set, which runs the park.
  harness.setAnswer(() => ({ kind: 'ok', rows: ['back'], truncated: false }));
  harness.parks[0].run();
  assert.equal(harness.refresh.armedFor(), 'tick', 'and only then does the timer come back');
  await harness.fire();
  assert.deepEqual(harness.stores.for(DESCRIPTOR, [10]).data(), ['back']);
});

test('a fault meeting a screen whose rate is off leaves the rate off when the park runs', async () => {
  const harness = wired();
  harness.setAnswer(() => ({
    kind: 'fault',
    fault: { kind: 'server-fault', status: 500, code: 'INTERNAL', path: '/api/ocupilot/probe' },
  }));
  harness.refresh.bind(screen(), harness.read);
  harness.refresh.setRate(10);
  await harness.fire();

  harness.refresh.setRate(0);
  harness.parks[0].run();

  assert.equal(harness.refresh.armedFor(), 'none', 'resume is a predicate over all three (AD-43)');
});

// --- The proposal pause ----------------------------------------------------------------------

function openProposal(harness, id, extra = {}) {
  harness.bus.publish({
    kind: 'proposal-open',
    type: 'process',
    scope: 'HSCUSTOM',
    id: '1234',
    proposalId: id,
    ...extra,
  });
}

function closeProposal(harness, id) {
  harness.bus.publish({
    kind: 'proposal-closed',
    type: 'process',
    scope: 'HSCUSTOM',
    id: '1234',
    proposalId: id,
  });
}

test('a proposal on the bound entity type pauses the timer and says so on the chip', () => {
  const harness = wired();
  harness.refresh.bind(screen(), harness.read);
  harness.refresh.setRate(10);

  openProposal(harness, 'p-1');

  assert.equal(harness.refresh.paused(), true);
  assert.equal(harness.refresh.chipLabel(), STRINGS.statusAutoRefreshPaused);
  assert.notEqual(harness.refresh.armedFor(), 'tick', 'zero pending tick arms while paused');
});

test('an event for another entity type or another scope is ignored', () => {
  const harness = wired();
  harness.refresh.bind(screen(), harness.read);
  harness.refresh.setRate(10);

  harness.bus.publish({
    kind: 'proposal-open',
    type: 'task',
    scope: 'HSCUSTOM',
    id: '1234',
    proposalId: 'other-type',
  });
  harness.bus.publish({
    kind: 'proposal-open',
    type: 'process',
    scope: 'USER',
    id: '1234',
    proposalId: 'other-scope',
  });

  assert.equal(harness.refresh.paused(), false);
  assert.equal(harness.refresh.armedFor(), 'tick', 'the timer never noticed');
});

test('the live-proposal set is not a boolean: two opens and one close stays paused', async () => {
  const harness = wired();
  harness.refresh.bind(screen(), harness.read);
  harness.refresh.setRate(10);

  openProposal(harness, 'p-1');
  openProposal(harness, 'p-2');
  closeProposal(harness, 'p-1');
  assert.equal(harness.refresh.paused(), true, 'one of two closed is still one live');

  closeProposal(harness, 'p-2');
  assert.equal(harness.refresh.paused(), false);
  assert.equal(harness.refresh.armedFor(), 'tick', 'and it re-arms once, not twice');

  await harness.fire();
  assert.equal(harness.reads.length, 1);
});

test('a close for an id never opened ends nothing', () => {
  const harness = wired();
  harness.refresh.bind(screen(), harness.read);
  harness.refresh.setRate(10);

  openProposal(harness, 'p-1');
  closeProposal(harness, 'p-never-opened');

  assert.equal(harness.refresh.paused(), true, 'the pause is held by the ids that opened it');
});

test('a close that never arrives does not strand the pause: the expiry is the arm', async () => {
  const harness = wired();
  harness.refresh.bind(screen(), harness.read);
  harness.refresh.setRate(10);

  openProposal(harness, 'p-1', { expiresAt: NOW_MS + 600_000 });
  assert.equal(harness.refresh.armedFor(), 'expiry', 'the one arm now serves the pause\'s deadline');
  assert.equal(
    harness.scheduled[harness.scheduled.length - 1].delayMs,
    600_000,
    'armed for exactly as long as the proposal has left (AD-6)'
  );

  // Driving the seam past the expiry drops the id and brings the tick arm back. No clock waits.
  harness.advanceNow(600_000);
  await harness.fire();

  assert.equal(harness.refresh.paused(), false, 'the unclosed proposal expired');
  assert.equal(harness.refresh.armedFor(), 'tick');
  assert.equal(harness.reads.length, 0, 'and the expiry itself issued no read');

  await harness.fire();
  assert.equal(harness.reads.length, 1);
});

test('an expiry sweep still requires no fault and a rate above zero to resume', async () => {
  const harness = wired();
  harness.setAnswer(() => ({
    kind: 'fault',
    fault: { kind: 'unreachable', status: 0, code: null, path: '/api/ocupilot/probe' },
  }));
  harness.refresh.bind(screen(), harness.read);
  harness.refresh.setRate(10);
  await harness.fire();
  assert.equal(harness.parks.length, 1, 'suspended by the fault');

  openProposal(harness, 'p-1', { expiresAt: NOW_MS + 1000 });
  harness.advanceNow(1000);
  // Nothing is armed while suspended, so the sweep rides on the next transition rather than on
  // an arm -- and it resumes nothing, because the fault is still in force.
  closeProposal(harness, 'p-1');

  assert.equal(harness.refresh.paused(), false);
  assert.equal(harness.refresh.armedFor(), 'none', 'a proposal-closed does not resume a fault');
  assert.equal(harness.reads.length, 1, 'and issues no read');
});

test('the pause survives a tick whose read was already in flight when the proposal landed', async () => {
  const harness = wired();
  let release = () => {};
  harness.setAnswer(
    () =>
      new Promise((resolve) => {
        release = () => resolve({ kind: 'ok', rows: ['late'], truncated: false });
      })
  );
  harness.refresh.bind(screen(), harness.read);
  harness.refresh.setRate(10);

  harness.scheduled[harness.scheduled.length - 1].run();
  await settle();
  assert.equal(harness.reads.length, 1, 'the read is out');

  openProposal(harness, 'p-1');
  release();
  await settle();

  // The data is good and is kept -- discarding it would throw away a read the user already paid
  // for -- but the arm belongs to the transition the proposal made, not to the landing read.
  assert.deepEqual(harness.stores.for(DESCRIPTOR, [10]).data(), ['late']);
  assert.equal(harness.refresh.paused(), true, 'the pause survives');
  assert.notEqual(harness.refresh.armedFor(), 'tick', 'and the landing read did not re-arm');
});

test('a proposal against a screen switched off reads off, not paused', async () => {
  // The pause is something happening to a timer, and an off screen has none. Reporting "paused"
  // there would also be the one pause nothing lifts: the expiry deadline is armed only while the
  // rate is above zero, so nothing would sweep the id.
  const harness = wired();
  harness.refresh.bind(screen(), harness.read);
  assert.equal(harness.refresh.rate(), 0, 'off is the default');

  openProposal(harness, 'p-1');

  assert.equal(harness.refresh.chipLabel(), STRINGS.statusAutoRefreshOff);
  assert.equal(harness.refresh.armedFor(), 'none', 'and an off screen arms nothing either way');

  // Turning it on while the proposal is still live is the state the paused literal is for, and
  // the deadline comes with it.
  harness.refresh.setRate(10);
  assert.equal(harness.refresh.chipLabel(), STRINGS.statusAutoRefreshPaused);
  assert.equal(harness.refresh.armedFor(), 'expiry');
});

test('an expiry that is not a moment within AD-6 cannot become a re-arm loop', async () => {
  // The subscriber arms for `expiresAt - now`, so a NaN expiry is a NaN delay: it fires at once
  // against a deadline the sweep can never pass, and re-arms forever without lifting the pause.
  const harness = wired();
  harness.refresh.bind(screen(), harness.read);
  harness.refresh.setRate(10);

  openProposal(harness, 'p-1', { expiresAt: Number.NaN });

  assert.equal(harness.refresh.armedFor(), 'expiry');
  const delay = harness.scheduled[harness.scheduled.length - 1].delayMs;
  assert.ok(Number.isFinite(delay), 'the delay is a number of milliseconds');
  assert.equal(delay, 600_000, 'AD-6 supplies the ten minutes the publisher did not');

  harness.advanceNow(600_000);
  await harness.fire();
  assert.equal(harness.refresh.paused(), false, 'and the sweep can reach it');
  assert.equal(harness.refresh.armedFor(), 'tick');
});

test('a namespace switch drops the bound screen\'s rows, its stamp and its live proposals', async () => {
  // AD-44: switching re-fetches rather than re-routes. The rows and the stamp are answers about
  // the namespace the shell has left; the rate is the user's setting for the screen and stays.
  const harness = wired();
  harness.refresh.bind(screen(), harness.read);
  harness.refresh.setRate(10);
  await harness.fire();
  const store = harness.stores.for(DESCRIPTOR, [10]);
  assert.deepEqual(store.data(), ['a', 'b']);
  assert.notEqual(store.lastUpdate(), null);

  // A proposal opened under the old namespace: its close will be published under that namespace
  // too, so it would no longer match the bound screen and the pause would hold until it expired.
  openProposal(harness, 'p-1');
  assert.equal(harness.refresh.paused(), true);

  harness.refresh.noteScopeChanged();

  assert.deepEqual(store.data(), [], 'the previous namespace\'s rows are gone');
  assert.equal(store.lastUpdate(), null, 'and so is the stamp that claimed they were current');
  assert.equal(store.truncated(), false);
  assert.equal(harness.refresh.paused(), false, 'the stale proposal went with them');
  assert.equal(harness.refresh.rate(), 10, 'the rate is the user\'s setting, not an answer');
  assert.equal(harness.refresh.armedFor(), 'tick', 'and the timer re-arms to read the new one');

  await harness.fire();
  assert.deepEqual(store.data(), ['a', 'b'], 'the re-fetch fills it again');
});

test('a read still out when the namespace switches cannot refill the store it cleared', async () => {
  // The switch clears the rows and the stamp (AD-44) and re-arms, but a read issued before it is
  // still out and its rows are about the namespace the shell has just left. Landing them in the
  // cleared store under a fresh `Last update` is the switch undone by the read it superseded --
  // the same stale-stamp class as the overtaken-read row above, with a transition rather than a
  // second read as the thing that superseded it.
  const harness = wired();
  const releases = [];
  harness.setAnswer(() => new Promise((resolve) => releases.push(resolve)));
  harness.refresh.bind(screen(), harness.read);
  harness.refresh.setRate(10);

  harness.scheduled[harness.scheduled.length - 1].run(); // the read goes out
  await settle();
  assert.equal(harness.reads.length, 1, 'one read really is in flight across the switch');

  harness.refresh.noteScopeChanged();
  const store = harness.stores.for(DESCRIPTOR, [10]);
  assert.deepEqual(store.data(), [], 'the switch cleared it');

  harness.advanceNow(1000);
  releases[0]({ kind: 'ok', rows: ['old-namespace'], truncated: true });
  await settle();

  assert.deepEqual(store.data(), [], "the superseded namespace's rows stay dropped");
  assert.equal(store.lastUpdate(), null, 'and no stamp claims they are current');
  assert.equal(store.truncated(), false);
  assert.equal(harness.refresh.armedFor(), 'tick', "the switch's own arm is the one pending arm");
});

test('a fault from a read the namespace switch superseded does not suspend the new namespace', async () => {
  // The namespace the shell has left may be the one that is gone: a 404 about it is not news
  // about the one it is on. Suspending on it parks a re-arm whose only trigger is some unrelated
  // call succeeding, with the new namespace perfectly reachable the whole time.
  const harness = wired();
  const releases = [];
  harness.setAnswer(() => new Promise((resolve) => releases.push(resolve)));
  harness.refresh.bind(screen(), harness.read);
  harness.refresh.setRate(10);

  harness.scheduled[harness.scheduled.length - 1].run();
  await settle();
  harness.refresh.noteScopeChanged();

  releases[0]({ kind: 'fault', fault: { kind: 'absent', path: '/api/ocupilot/v1/processes' } });
  await settle();

  assert.deepEqual(harness.parks, [], 'nothing is parked with connectivity');
  assert.equal(harness.refresh.armedFor(), 'tick', 'and the new namespace keeps its timer');
});

test('a namespace switch with nothing bound changes nothing', () => {
  const harness = wired();
  harness.refresh.noteScopeChanged();
  assert.deepEqual(harness.scheduled, [], 'and arms nothing on the way through');
});

// --- Persistence ----------------------------------------------------------------------------

test('the rate persists per screen, and returning to the screen restores it', () => {
  const storage = memoryStorage();
  const first = wired({ storage });
  first.refresh.bind(screen(), first.read);
  first.refresh.setRate(10);
  first.refresh.unbind();

  // A second tab -- a new service over the same browser storage -- finds the choice.
  const second = wired({ storage });
  second.refresh.bind(screen(), second.read);
  assert.equal(second.refresh.rate(), 10);
  assert.equal(second.refresh.armedFor(), 'tick', 'and arms at the remembered rate');
  assert.equal(second.scheduled[second.scheduled.length - 1].delayMs, 10_000);
});

test('a stored rate the descriptor no longer permits falls back to off, without throwing', () => {
  const storage = memoryStorage();
  storage.setItem(SCREEN_REFRESH_RATES_KEY, JSON.stringify({ [DESCRIPTOR]: 30 }));

  const harness = wired({ storage });
  harness.refresh.bind(screen({ refreshRates: [10] }), harness.read);

  assert.equal(harness.refresh.rate(), 0, 'off is the published default (EXPERIENCE.md :439)');
  assert.equal(harness.refresh.chipLabel(), STRINGS.statusAutoRefreshOff);
});

test('an unparseable preference blob falls back to off, without throwing', () => {
  const storage = memoryStorage();
  storage.setItem(SCREEN_REFRESH_RATES_KEY, '{not json at all');

  const harness = wired({ storage });
  harness.refresh.bind(screen(), harness.read);
  assert.equal(harness.refresh.rate(), 0);

  // And a well-formed blob of the wrong shape is the same answer for the same reason.
  const other = wired({ storage: (() => {
    const store = memoryStorage();
    store.setItem(SCREEN_REFRESH_RATES_KEY, JSON.stringify(['not', 'a', 'map']));
    return store;
  })() });
  other.refresh.bind(screen(), other.read);
  assert.equal(other.refresh.rate(), 0);
});

test('a rate the descriptor forbids is refused, changing neither the setting nor the timer', () => {
  const harness = wired();
  harness.refresh.bind(screen({ refreshRates: [10] }), harness.read);
  harness.refresh.setRate(10);
  const armsBefore = harness.scheduled.length;

  assert.equal(harness.refresh.setRate(7), false);
  assert.equal(harness.refresh.rate(), 10, 'the setting is unchanged');
  assert.equal(harness.scheduled.length, armsBefore, 'and nothing was re-armed');
});

test('the chip advances through off and the permitted rates, and back to off', () => {
  const harness = wired();
  harness.refresh.bind(screen({ refreshRates: [10, 30] }), harness.read);

  const seen = [harness.refresh.rate()];
  for (let step = 0; step < 3; step += 1) {
    harness.refresh.advanceRate();
    seen.push(harness.refresh.rate());
  }
  assert.deepEqual(seen, [0, 10, 30, 0], 'a cycle, not a menu (DW-126)');
});

// --- Sign-out --------------------------------------------------------------------------------

test('reset drops the bound screen, its stores and its timer', async () => {
  const harness = wired();
  harness.refresh.bind(screen(), harness.read);
  harness.refresh.setRate(10);
  await harness.fire();
  assert.notEqual(harness.stores.for(DESCRIPTOR, [10]).lastUpdate(), null);

  harness.refresh.reset();

  assert.equal(harness.refresh.descriptor(), '');
  assert.equal(harness.refresh.armedFor(), 'none');
  assert.equal(harness.refresh.lastUpdate(), null);
  assert.equal(
    harness.stores.for(DESCRIPTOR, [10]).lastUpdate(),
    null,
    "a second principal inherits none of the first's rows (AD-8)"
  );

  for (const entry of harness.scheduled) entry.run();
  await settle();
  assert.equal(harness.reads.length, 1, 'and no armed callback survives the sign-out');
});

test('the rate survives a sign-out, because it is a preference and not an answer', () => {
  const storage = memoryStorage();
  const harness = wired({ storage });
  harness.refresh.bind(screen(), harness.read);
  harness.refresh.setRate(10);
  harness.refresh.reset();

  harness.refresh.bind(screen(), harness.read);
  assert.equal(harness.refresh.rate(), 10, 'remembered per browser, like the side bar');
});

// --- The published copy -----------------------------------------------------------------------

// Mutation (Rule 19): return `STRINGS.statusAutoRefreshOn` from `chipLabel` without
// `formatAutoRefreshOn` -> the `chipLabel` assertions below go red with `<n>` in the label.
test('the chip fills the published <n> span with the rate the screen is set to', () => {
  assert.equal(formatAutoRefreshOn(STRINGS.statusAutoRefreshOn, 10), 'Auto-refresh: every 10 s');
  assert.equal(formatAutoRefreshOn(STRINGS.statusAutoRefreshOn, 30), 'Auto-refresh: every 30 s');

  const harness = wired();
  harness.refresh.bind(screen({ refreshRates: [10, 30] }), harness.read);
  harness.refresh.setRate(30);
  assert.equal(harness.refresh.chipLabel(), 'Auto-refresh: every 30 s');
  harness.refresh.setRate(10);
  assert.equal(harness.refresh.chipLabel(), 'Auto-refresh: every 10 s');
  assert.ok(!harness.refresh.chipLabel().includes('<n>'), 'the placeholder never reaches the chip');
});

test('the stamp fills the published span rather than composing a sentence', () => {
  const at = new Date(2026, 8, 12, 9, 5, 3);
  assert.equal(formatLastUpdate(STRINGS.statusLastUpdate, at), 'Last update 09:05:03');
  assert.equal(
    formatLastUpdate(STRINGS.statusLastUpdate, new Date(2026, 8, 12, 23, 59, 59)),
    'Last update 23:59:59'
  );
  assert.ok(
    !formatLastUpdate(STRINGS.statusLastUpdate, at).includes('hh:mm:ss'),
    'a resolved string never ships its span'
  );
});

// --- AD-43's "no screen implements refresh of its own" -----------------------------------------

test('no area screen carries a timer of its own', () => {
  // The falsifiable form of "one framework, not ten": a screen that armed its own timer would
  // satisfy every assertion above and still be a second timer. The pattern covers the four ways
  // an Angular screen would actually arm one -- `setTimeout`/`setInterval` and rxjs `interval()`
  // / `timer()` -- because a scan that names only the first two would read clean on the second
  // pair, and rxjs is the likelier of the two in a component. (Its population is one screen
  // today, which is DW-176; widening the predicate costs a line now and is the awkward edit
  // once Epic 2's ten refreshing screens exist.)
  const areas = join(uiRoot, 'src', 'app', 'areas');
  const offenders = [];
  const walk = (dir) => {
    for (const entry of readdirSync(dir)) {
      const full = join(dir, entry);
      if (statSync(full).isDirectory()) {
        walk(full);
        continue;
      }
      // Specs are exempt: settling a promise with `setTimeout(resolve, 0)` is this suite's own
      // idiom for a macrotask flush, and a spec is not a screen.
      if (!entry.endsWith('.ts') || entry.endsWith('.spec.ts')) continue;
      const text = readFileSync(full, 'utf8');
      if (/\b(?:set(?:Timeout|Interval)|interval|timer)\s*\(/.test(text)) offenders.push(entry);
    }
  };
  walk(areas);
  assert.deepEqual(offenders, [], `a screen with its own timer: ${offenders.join(', ')}`);
});

test('the framework reaches no API service: classification and probing are Story 1.13\'s', () => {
  // Comments are blanked first, the treatment `client-lint.mjs` and `api.test.mjs` both apply:
  // this module's own header names the thing it does not use in order to explain why, and failing
  // on the explanation would leave no way to write one.
  const code = readFileSync(corePath('refresh.ts'), 'utf8').replace(
    /\/\*[\s\S]*?\*\/|(?:^|(?<=[\s;{}(]))\/\/[^\n]*/g,
    (match) => match.replace(/[^\n]/g, ' ')
  );
  assert.ok(!/\bApiService\b/.test(code), 'refresh.ts names no ApiService (AD-43)');
  assert.ok(!/\bclassifyFault\b/.test(code), 'and classifies nothing: there is one taxonomy');
  assert.ok(!/\bfetch\s*\(/.test(code), 'nor does it issue a request of its own (AD-36)');
});

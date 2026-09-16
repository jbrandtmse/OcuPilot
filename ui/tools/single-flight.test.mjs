import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the join-versus-queue primitive (DW-4, DW-102, **DW-157**): join on an unchanged key,
// mark-dirty-and-re-run-once on a changed one, and fill the slot before the work starts.
//
// Nothing here touches a clock or a network. The "work" is a held promise the test releases by
// hand, which is what makes "while a flight is in progress" a state the assertions can sit in.
//
// Mutations (Rule 19):
// - drop the key comparison in `request()` so every second caller marks the flight dirty -> the
//   "a repeat joins" row goes red with two runs, and the self-reporting caller below loops.
// - drop the mark so every second caller joins -> the "a changed key re-runs once" row goes red,
//   which is DW-157 exactly: the map stays computed against the namespace the shell has left.
// - clear `marked` before the re-run is decided, or re-run per mark instead of once -> the
//   "N changes, one re-run" row goes red at 3 runs.
// - assign `current` after `run()` returns instead of before it -> the "a caller that reports
//   into the flight it is making" row goes red with an unbounded run count.

const corePath = (name) =>
  join(dirname(fileURLToPath(import.meta.url)), '..', 'src', 'app', 'core', name);

const { createSingleFlight } = await import(corePath('single-flight.ts'));

const settle = () => new Promise((resolve) => setImmediate(resolve));

/** A run that records the key it was issued against and stays open until released. */
function heldRun() {
  const keys = [];
  let release = () => {};
  const run = async (key) => {
    keys.push(key);
    await new Promise((resolve) => {
      release = resolve;
    });
  };
  return { keys, run, release: () => release() };
}

test('a repeat joins: one run however many callers while the key has not moved', async () => {
  const { keys, run, release } = heldRun();
  const flight = createSingleFlight(run, () => 'A');

  const first = flight.request();
  flight.request();
  flight.request();
  assert.equal(flight.running(), true);
  assert.equal(flight.key(), 'A');
  assert.equal(flight.dirty(), false, 'an unchanged key marks nothing');

  release();
  await first;
  await settle();

  assert.deepEqual(keys, ['A'], 'three callers, one run');
  assert.equal(flight.running(), false);
});

test('DW-157: a key that moves mid-flight re-runs once, against the latest key', async () => {
  const { keys, run, release } = heldRun();
  let key = 'A';
  const flight = createSingleFlight(run, () => key);

  const first = flight.request();
  key = 'B';
  flight.request();
  assert.equal(flight.dirty(), true, 'the moved key marked the flight');
  key = 'C';
  flight.request();

  release();
  await first;
  await settle();

  // Two runs, not three and not one: N changes during one flight are one re-run, and the re-run
  // carries the key as it is when it starts -- not the one that first moved.
  assert.deepEqual(keys, ['A', 'C']);
});

test('a repeat during the re-run joins it, so the chain ends rather than continuing', async () => {
  const keys = [];
  let key = 'A';
  let release = () => {};
  const flight = createSingleFlight(async (issued) => {
    keys.push(issued);
    await new Promise((resolve) => {
      release = resolve;
    });
  }, () => key);

  const first = flight.request();
  key = 'B';
  flight.request();
  release();
  await first;
  await settle();

  // The re-run is now in flight against 'B'. A caller that still wants 'B' joins it.
  flight.request();
  release();
  await settle();

  assert.deepEqual(keys, ['A', 'B'], 'nothing was queued behind the re-run');
});

test('a caller that reports into the flight it is making finds the slot filled', async () => {
  // `navigation.ts`'s DW-9 shape: the call being made reports a refusal about itself, from inside
  // `run`, before the first `await` has yielded. A slot filled only after `run` resolves would
  // make that recursive.
  const keys = [];
  let flight;
  flight = createSingleFlight(async (key) => {
    keys.push(key);
    flight.request();
    await settle();
  }, () => 'A');

  await flight.request();
  await settle();

  assert.deepEqual(keys, ['A'], 'a refusal arriving during the run arms no second one');
});

test('a rejected run settles the flight and retries nothing here', async () => {
  const keys = [];
  const flight = createSingleFlight(async (key) => {
    keys.push(key);
    throw new Error('the read failed');
  }, () => 'A');

  await flight.request();
  await settle();

  assert.deepEqual(keys, ['A'], 'failure is the caller\'s to park, not this module\'s to chase');
  assert.equal(flight.running(), false, 'and the slot is free for the next ask');

  await flight.request();
  assert.equal(keys.length, 2);
});

test('a rejected run still honours a mark, so a key that moved is not lost to a failure', async () => {
  const keys = [];
  let key = 'A';
  let fail = true;
  let release = () => {};
  const flight = createSingleFlight(async (issued) => {
    keys.push(issued);
    await new Promise((resolve) => {
      release = resolve;
    });
    if (fail) {
      fail = false;
      throw new Error('the read failed');
    }
  }, () => key);

  const first = flight.request();
  key = 'B';
  flight.request();
  release();
  await first;
  await settle();

  assert.deepEqual(keys, ['A', 'B'], 'the re-run happens whether or not the first run answered');
});

test('reset drops the flight and its mark, so a departed principal gets no re-run', async () => {
  const { keys, run, release } = heldRun();
  let key = 'A';
  const flight = createSingleFlight(run, () => key);

  const first = flight.request();
  key = 'B';
  flight.request();
  assert.equal(flight.dirty(), true);

  flight.reset();
  assert.equal(flight.running(), false);
  assert.equal(flight.key(), '', 'nothing is in flight as far as the next caller is concerned');
  assert.equal(flight.dirty(), false);

  release();
  await first;
  await settle();

  assert.deepEqual(keys, ['A'], 'the re-run a departed principal marked never happens (AD-8)');
});

test('a request after reset starts a fresh flight rather than joining the abandoned one', async () => {
  const { keys, run, release } = heldRun();
  let key = 'A';
  const flight = createSingleFlight(run, () => key);

  flight.request();
  flight.reset();
  key = 'B';
  const second = flight.request();

  release();
  await second;
  await settle();

  assert.deepEqual(keys, ['A', 'B']);
});

test('a run that throws instead of rejecting settles the flight rather than wedging the slot', async () => {
  // The slot is filled before `run` is called, deliberately -- so a `run` that throws before it
  // returns a promise throws past a gate nothing is left to settle. `running()` would then be
  // true forever and every later `request()` would return a promise that never resolves: the map
  // read silently dead for the life of the tab, with no rejection anywhere to say so.
  let throwFirst = true;
  const keys = [];
  const run = (key) => {
    keys.push(key);
    if (throwFirst) {
      throwFirst = false;
      throw new Error('a broken read');
    }
    return Promise.resolve();
  };
  const flight = createSingleFlight(run, () => 'A');

  await flight.request();
  await settle();

  assert.equal(flight.running(), false, 'the flight settled');
  assert.equal(flight.key(), '', 'and let go of the slot');

  await flight.request();
  await settle();
  assert.deepEqual(keys, ['A', 'A'], 'so the next caller runs rather than joining a dead gate');
});

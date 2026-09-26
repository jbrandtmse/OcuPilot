// Story 11.11, AD-11: the one-shot hand-off from an agent navigation to the screen it opens.
//
// Mutations (Rule 19): drop the `this.pending = null` from `take` -> "taken once" goes red; drop
// the route comparison from `take` -> "another route takes nothing" goes red; drop the listener
// loop from `set` -> "a page already mounted is told" goes red.

import assert from 'node:assert/strict';
import { test } from 'node:test';

import { ScreenArrivals } from '../src/app/core/screen-arrival.ts';

const ARRIVAL = { route: 'logs/audit', criterion: '', criteria: { eventSources: 'OcuPilot' } };

test('an arrival is taken once, by its own route, and another route takes nothing', () => {
  const arrivals = new ScreenArrivals();
  arrivals.set(ARRIVAL);
  assert.equal(arrivals.take('tasks/history'), null, 'another route takes nothing');
  assert.deepEqual(arrivals.take('logs/audit'), ARRIVAL, 'its own route takes it');
  assert.equal(arrivals.take('logs/audit'), null, 'and only once');
});

test('clear drops an arrival nobody took, and a later set replaces an earlier one', () => {
  const arrivals = new ScreenArrivals();
  arrivals.set(ARRIVAL);
  arrivals.clear();
  assert.equal(arrivals.take('logs/audit'), null, 'a refused navigation leaves nothing to take');
  arrivals.set(ARRIVAL);
  const next = { route: 'logs/audit', criterion: 'marker', criteria: {} };
  arrivals.set(next);
  assert.deepEqual(arrivals.take('logs/audit'), next, 'the newest arrival is the one taken');
});

test('the same-route case: a page already mounted is told, and takes the arrival before any new page can', () => {
  const arrivals = new ScreenArrivals();
  const taken = [];
  const stop = arrivals.subscribe(() => {
    const arrival = arrivals.take('logs/audit');
    if (arrival !== null) taken.push(arrival);
  });
  arrivals.set(ARRIVAL);
  assert.deepEqual(taken, [ARRIVAL], 'the mounted page took it on set');
  assert.equal(arrivals.take('logs/audit'), null, 'so a page created afterwards finds nothing, and reads once');
  stop();
  arrivals.set(ARRIVAL);
  assert.equal(taken.length, 1, 'an unsubscribed page is not told again');
});

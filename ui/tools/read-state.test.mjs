import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the states a screen-bound view draws while its read runs (AD-36, AD-43): `ReadState`, which `DataTable` and the detail tabs'
// body components decide them by (Story 20.30, DW-2434). The framework's answers are stand-ins the test drives; no clock is involved.
//
// Mutations (Rule 19):
// - drop the descriptor comparison from `boundHere` -> the "bound to another screen" leg goes red.
// - drop the `isBannerFault` test from `showRefusal` -> the connectivity-banner leg goes red.
// - make `showEmpty` ignore `fault` -> the fault leg goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { ReadState } = await import(join(uiRoot, 'src', 'app', 'core', 'read-state.ts'));

const DESCRIPTOR = 'OcuPilot.Screen.Descriptor.Probe';

/** A framework stand-in the test drives, a screen and a store holding `rows`. */
function harness({ bound = DESCRIPTOR, loaded = false, fault = null, rows = [] } = {}) {
  const source = { bound, loaded, fault };
  const wired = { descriptor: () => source.bound, hasLoaded: () => source.loaded, fault: () => source.fault };
  let touched = 0;
  const state = new ReadState(wired, () => ({ descriptor: DESCRIPTOR }), () => ({ data: () => rows }), () => (touched += 1));
  return { source, state, touches: () => touched };
}

const REFUSED = { kind: 'refused', status: 403, code: null, path: '/screens/x/read' };
const UNREACHABLE = { kind: 'unreachable', status: 0, code: null, path: '/screens/x/read' };

test('before the first answer a bound view shows the skeleton and reads busy', () => {
  const { state } = harness();
  assert.equal(state.boundHere, true);
  assert.equal(state.loaded, false);
  assert.equal(state.showSkeleton, true);
  assert.equal(state.busy, 'true');
  assert.equal(state.showRefusal, false);
  assert.equal(state.showEmpty, false);
});

test('a view the framework is bound to another screen for shows the skeleton, whatever the framework has loaded', () => {
  const { state } = harness({ bound: 'OcuPilot.Screen.Descriptor.Other', loaded: true, fault: REFUSED, rows: [] });
  assert.equal(state.boundHere, false);
  assert.equal(state.loaded, false);
  assert.equal(state.fault, null);
  assert.equal(state.showSkeleton, true);
  assert.equal(state.showEmpty, false);
});

test('a refusal the connectivity banner has no copy for draws a refusal in place of the skeleton, and a banner fault draws none', () => {
  const { source, state } = harness();
  source.fault = REFUSED;
  assert.equal(state.showRefusal, true);
  assert.equal(state.showSkeleton, false);
  assert.equal(state.busy, null);
  source.fault = UNREACHABLE;
  assert.equal(state.showRefusal, false);
  assert.equal(state.showSkeleton, true);
});

test('an answer with no row is empty, one with rows is not, and a fault is never an empty answer', () => {
  const none = harness({ loaded: true, rows: [] });
  assert.equal(none.state.loaded, true);
  assert.equal(none.state.showSkeleton, false);
  assert.equal(none.state.showEmpty, true);
  assert.equal(harness({ loaded: true, rows: [{}] }).state.showEmpty, false);
  none.source.fault = REFUSED;
  assert.equal(none.state.showEmpty, false);
});

test('every answer touches the caller\'s dependency first, so a template that asks depends on it', () => {
  const { state, touches } = harness({ loaded: true });
  const before = touches();
  void state.showEmpty;
  assert.ok(touches() > before);
});

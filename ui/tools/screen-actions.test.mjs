import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins `ScreenActions`' registry contract, which the command bar and the command box read
// through `has`, `run` and `subscribe`: a remover removes only its own registration, an empty id
// never has a handler, and listeners hear only changes that happened.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { ScreenActions } = await import(join(uiRoot, 'src', 'app', 'core', 'screen-actions.ts'));

const DESCRIPTOR = 'OcuPilot.Screen.Descriptor.Probe';

test('register, has, run and the remover', () => {
  const actions = new ScreenActions();
  let runs = 0;
  assert.equal(actions.has(DESCRIPTOR, 'create'), false);
  assert.equal(actions.run(DESCRIPTOR, 'create'), false, 'run reports that nothing ran');

  const remove = actions.register(DESCRIPTOR, 'create', () => (runs += 1));
  assert.equal(actions.has(DESCRIPTOR, 'create'), true);
  assert.equal(actions.has('OcuPilot.Screen.Descriptor.Other', 'create'), false, 'keyed by descriptor');
  assert.equal(actions.run(DESCRIPTOR, 'create'), true);
  assert.equal(runs, 1);

  remove();
  assert.equal(actions.has(DESCRIPTOR, 'create'), false);
  remove();
  assert.equal(actions.has(DESCRIPTOR, 'create'), false, 'a second call to the remover does nothing');
});

test('a stale remover leaves a newer registration in place, even of the same function', () => {
  const actions = new ScreenActions();
  let runs = 0;
  const handler = () => (runs += 1);

  const removeFirst = actions.register(DESCRIPTOR, 'create', handler);
  const removeSecond = actions.register(DESCRIPTOR, 'create', handler);
  removeFirst();
  assert.equal(actions.has(DESCRIPTOR, 'create'), true, 'the second registration survives the first remover');
  assert.equal(actions.run(DESCRIPTOR, 'create'), true);
  assert.equal(runs, 1);

  removeSecond();
  assert.equal(actions.has(DESCRIPTOR, 'create'), false);
});

test('an empty action id never has a handler', () => {
  const actions = new ScreenActions();
  let runs = 0;
  actions.register(DESCRIPTOR, '', () => (runs += 1));
  assert.equal(actions.has(DESCRIPTOR, ''), false);
  assert.equal(actions.run(DESCRIPTOR, ''), false);
  assert.equal(runs, 0);
});

test('listeners hear a registration and an effective removal, and nothing else', () => {
  const actions = new ScreenActions();
  let heard = 0;
  const stop = actions.subscribe(() => (heard += 1));

  const removeFirst = actions.register(DESCRIPTOR, 'create', () => {});
  assert.equal(heard, 1, 'a registration notifies');
  actions.register(DESCRIPTOR, 'create', () => {});
  assert.equal(heard, 2, 'a replacement notifies');
  removeFirst();
  assert.equal(heard, 2, 'a stale remover changes nothing, so it does not notify');

  stop();
  actions.register(DESCRIPTOR, 'edit', () => {});
  assert.equal(heard, 2, 'an unsubscribed listener hears nothing');
});

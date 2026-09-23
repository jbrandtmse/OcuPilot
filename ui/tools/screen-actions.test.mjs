import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins `ScreenActions`' registry contract, which the command bar and the command box read
// through `has`, `run` and `subscribe`: a remover removes only its own registration, an empty id
// never has a handler, and listeners hear only changes that happened.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { ScreenActions, actionLabel, REFRESH_ACTION_ID } = await import(
  join(uiRoot, 'src', 'app', 'core', 'screen-actions.ts')
);
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

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
  const removeSecond = actions.register(DESCRIPTOR, 'create', () => {});
  assert.equal(heard, 2, 'a replacement notifies');
  removeFirst();
  assert.equal(heard, 2, 'a stale remover changes nothing, so it does not notify');
  removeSecond();
  assert.equal(heard, 3, 'an effective removal notifies');

  stop();
  actions.register(DESCRIPTOR, 'edit', () => {});
  assert.equal(heard, 3, 'an unsubscribed listener hears nothing');
});

// --- DW-370: the label map is scoped by descriptor ---------------------------------------------
//
// One action id means different things on different screens: `create` is "Create" on the
// Definitions list and "Switch off a user" on Switches. A map keyed by the bare id can only ever
// draw one of them, and both the command bar and the command box read through this one function.
//
// Mutations (Rule 19):
// - resolve the shared map first -> the two-screens test goes red, Switches drawing "Create".
// - index the maps bare instead of through `Object.hasOwn` -> the prototype test goes red.

const SWITCHES = 'OcuPilot.Screen.Descriptor.AgentSwitches';
const DEFINITIONS = 'OcuPilot.Screen.Descriptor.AgentDefinitionList';

test('DW-370: one action id draws two labels on two screens', () => {
  assert.equal(actionLabel(SWITCHES, 'create'), STRINGS.agentSwitchesHoldAdd);
  assert.equal(actionLabel(DEFINITIONS, 'create'), STRINGS.actionCreate);
  assert.notEqual(actionLabel(SWITCHES, 'create'), actionLabel(DEFINITIONS, 'create'));
});

test("a screen's row action draws its own published words", () => {
  assert.equal(actionLabel(SWITCHES, 'delete'), STRINGS.agentSwitchesHoldRemove);
  // The same id on a screen that publishes nothing narrower falls back to the shared map, which
  // carries the plain verb; Switches' own entry means something else (it removes a hold, not an
  // entity), which is why the two differ.
  assert.equal(actionLabel(DEFINITIONS, 'delete'), STRINGS.actionDelete);
  assert.notEqual(actionLabel(SWITCHES, 'delete'), actionLabel(DEFINITIONS, 'delete'));
  // And an id neither map carries still renders as itself, which is where every declared action
  // starts.
  assert.equal(actionLabel(DEFINITIONS, 'broadcast'), 'broadcast');
  // Story 7.8: Terminate carries the published verb on the process screens.
  assert.equal(actionLabel('OcuPilot.Screen.Descriptor.ProcessList', 'terminate'), STRINGS.actionTerminate);
});

test('an action that means the same thing everywhere falls back to the shared map', () => {
  for (const descriptor of [SWITCHES, DEFINITIONS, '', 'OcuPilot.Screen.Descriptor.Unknown']) {
    assert.equal(actionLabel(descriptor, REFRESH_ACTION_ID), STRINGS.actionRefresh);
  }
  assert.equal(actionLabel(DEFINITIONS, 'enable'), STRINGS.agentDefinitionEnable);
});

test('an id with no entry anywhere renders as itself, and neither map answers for a prototype member', () => {
  assert.equal(actionLabel(SWITCHES, 'no-such-action'), 'no-such-action');
  for (const name of ['constructor', 'toString', 'hasOwnProperty']) {
    assert.equal(actionLabel(SWITCHES, name), name, `the action id ${name}`);
    assert.equal(actionLabel(name, 'create'), STRINGS.actionCreate, `the descriptor ${name}`);
  }
});

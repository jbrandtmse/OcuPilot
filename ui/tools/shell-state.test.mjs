import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the rail's and the side bar's shared rules, which are behaviour rather than markup and
// so live in a framework-free class `node --test` can execute (EXPERIENCE.md `:48`, `:51`,
// `:312`, `:314`):
//
// - a rail click opens an area's side bar WITHOUT navigating;
// - clicking the item whose list is already showing collapses it;
// - Home navigates and collapses, because it has no screen list;
// - the open/closed state is remembered per browser.
//
// Mutations (Rule 19):
// - make `activateArea` always return true -> the "opens without navigating" rows go red, and
//   every rail click would move the user off the screen they are on.
// - drop the `preferences.setSideBarOpen` call -> the persistence row goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);

const { ShellState, SIDE_BAR_OPEN_DEFAULT } = await import(corePath('shell-state.ts'));
const { PreferenceStore, SIDE_BAR_OPEN_KEY } = await import(corePath('preferences.ts'));

function memoryStorage(seed = {}) {
  const map = new Map(Object.entries(seed));
  return {
    map,
    getItem: (k) => (map.has(k) ? map.get(k) : null),
    setItem: (k, v) => map.set(k, v),
    removeItem: (k) => map.delete(k),
  };
}

function shellOver(storage) {
  return new ShellState({ preferences: new PreferenceStore({ storage }) });
}

test('a rail click opens an area without navigating, and the same click again collapses it', () => {
  const shell = shellOver(memoryStorage());
  assert.equal(shell.activateArea('logs', false), false, 'opening an area is not navigating to it');
  assert.equal(shell.visibleArea(), 'logs');
  assert.equal(shell.open(), true);

  assert.equal(shell.activateArea('logs', false), false);
  assert.equal(shell.open(), false, 'the active item collapses the side bar');

  assert.equal(shell.activateArea('tasks', false), false);
  assert.equal(shell.visibleArea(), 'tasks', 'a different item opens its own list');
  assert.equal(shell.open(), true);
});

test('Home navigates and collapses, because it has no screen list', () => {
  const shell = shellOver(memoryStorage());
  shell.activateArea('logs', false);
  assert.equal(shell.open(), true);

  assert.equal(shell.activateArea('home', true), true, 'the caller is told to navigate');
  assert.equal(shell.open(), false, 'and the side bar collapses in the same gesture');
  assert.equal(shell.visibleArea(), 'home');
});

test('the router sets the active area, and fills the side bar only when it is not showing another', () => {
  const shell = shellOver(memoryStorage());
  shell.setActiveArea('permissions');
  assert.equal(shell.activeArea(), 'permissions');
  assert.equal(shell.visibleArea(), 'permissions', 'a cold deep link fills the side bar');

  shell.activateArea('logs', false);
  shell.setActiveArea('security');
  assert.equal(shell.activeArea(), 'security', 'the active area follows the router');
  assert.equal(
    shell.visibleArea(),
    'logs',
    'while a deliberately opened list stays -- looking at one area while another is open is the point'
  );
});

test('Ctrl/Cmd+B toggles, and remembers the answer per browser', () => {
  const storage = memoryStorage();
  const first = shellOver(storage);
  assert.equal(first.open(), SIDE_BAR_OPEN_DEFAULT, 'nothing remembered yet');

  first.setActiveArea('tasks');
  first.toggleOpen();
  assert.equal(first.open(), !SIDE_BAR_OPEN_DEFAULT);
  assert.equal(storage.map.get(SIDE_BAR_OPEN_KEY), String(!SIDE_BAR_OPEN_DEFAULT));

  const reloaded = shellOver(storage);
  assert.equal(reloaded.open(), !SIDE_BAR_OPEN_DEFAULT, 'a new tab in the same browser remembers');
});

test("Home's collapse is not the user's preference, so it is never written through (DW-134)", () => {
  // Home has no screen list, so the bar goes away because there is nothing to show -- the
  // user never asked for it to be closed. Persisting that made the next area they opened
  // start collapsed, on a preference they had set to open and never changed.
  const storage = memoryStorage();
  const shell = shellOver(storage);
  shell.activateArea('logs', false);
  assert.equal(shell.open(), true);
  assert.equal(storage.map.get(SIDE_BAR_OPEN_KEY), 'true', 'opening an area is the user asking');

  assert.equal(shell.activateArea('home', true), true, 'the caller is told to navigate');
  assert.equal(shell.open(), false, 'and the bar collapses for Home');
  assert.equal(
    storage.map.get(SIDE_BAR_OPEN_KEY),
    'true',
    "the remembered preference still reads the user's own answer"
  );

  const reloaded = shellOver(storage);
  assert.equal(reloaded.open(), true, 'so a new tab in the same browser still opens the bar');
});

test('the toggle has an area to show even when nothing has been opened yet', () => {
  const shell = shellOver(memoryStorage({ [SIDE_BAR_OPEN_KEY]: 'false' }));
  shell.setActiveArea('logs');
  shell.toggleOpen();
  assert.equal(shell.open(), true);
  assert.equal(shell.visibleArea(), 'logs', 'Ctrl+B on a cold load shows the current area');
});

test('every state change notifies, so the rail and the side bar redraw together', () => {
  const shell = shellOver(memoryStorage());
  let notified = 0;
  const stop = shell.subscribe(() => {
    notified += 1;
  });
  shell.setActiveArea('logs');
  shell.activateArea('tasks', false);
  shell.toggleOpen();
  stop();
  shell.toggleOpen();
  assert.equal(notified, 3, 'three changes while subscribed, none after unsubscribing');
});

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the rail's and the side bar's shared rules, which are behaviour rather than markup and
// so live in a framework-free class `node --test` can execute (EXPERIENCE.md "The VS Code-shaped shell", "`{spacing.side-bar-width}` (240 px, fixed — no drag)",
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

test("a tile shows its area's list and never toggles it shut (Story 1.12)", () => {
  // A tile is not the rail item: the rail's click-to-collapse branch is about clicking the
  // item whose list is already showing, and activating a tile twice must leave the area open.
  const storage = memoryStorage();
  const shell = shellOver(storage);

  shell.showArea('logs');
  assert.equal(shell.visibleArea(), 'logs');
  assert.equal(shell.open(), true);
  assert.equal(storage.map.get(SIDE_BAR_OPEN_KEY), 'true', 'opening an area is the user asking');

  shell.showArea('logs');
  assert.equal(shell.open(), true, 'a second activation does not toggle it shut');
  assert.equal(shell.visibleArea(), 'logs');

  // The contentious case, pinned rather than left to the doc comment: a user who answered
  // "keep it closed" with Ctrl/Cmd+B and then clicks a tile has asked for the area, so the
  // answer is replaced -- the same thing activateArea's opening branch does from the rail.
  const stored = memoryStorage({ [SIDE_BAR_OPEN_KEY]: 'false' });
  const reopened = shellOver(stored);
  assert.equal(reopened.open(), false, 'starting from the remembered answer');
  reopened.showArea('logs');
  assert.equal(reopened.open(), true, 'the tile opens it anyway');
  assert.equal(stored.map.get(SIDE_BAR_OPEN_KEY), 'true', 'and replaces the answer it found');
});

test('a dismissal collapses the bar without writing the preference (DW-144)', () => {
  // Escape says "not this, now"; Ctrl/Cmd+B says "keep it closed". Routing both through
  // toggleOpen() made one Escape start every later area, and every later tab, collapsed.
  const storage = memoryStorage();
  const shell = shellOver(storage);
  shell.activateArea('logs', false);
  assert.equal(storage.map.get(SIDE_BAR_OPEN_KEY), 'true');

  shell.collapse();
  assert.equal(shell.open(), false, 'the bar goes away');
  assert.equal(storage.map.get(SIDE_BAR_OPEN_KEY), 'true', 'the remembered answer does not');

  assert.equal(shellOver(storage).open(), true, 'so a new tab in the same browser opens it');
});

test('collapsing an already-collapsed bar is a no-op, and notifies nobody', () => {
  const shell = shellOver(memoryStorage());
  shell.setActiveArea('logs');
  shell.toggleOpen();
  assert.equal(shell.open(), false);

  let notified = 0;
  const stop = shell.subscribe(() => {
    notified += 1;
  });
  shell.collapse();
  stop();
  assert.equal(notified, 0, 'nothing changed, so nothing redraws');
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

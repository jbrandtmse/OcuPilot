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
// - the open/closed state is remembered per user, on the instance (Story 15.5, AD-50).
//
// Mutations (Rule 19):
// - make `activateArea` always return true -> the "opens without navigating" rows go red, and
//   every rail click would move the user off the screen they are on.
// - drop the `account.setValue` call in `setOpen` -> the persistence rows go red.
// - make `adoptRemembered` run on every notification rather than once -> the row where a toggle
//   survives a later, unrelated write goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);

const { ShellState, SIDE_BAR_OPEN_DEFAULT } = await import(corePath('shell-state.ts'));
const { settledAccountPreferences, stubAccountPreferences, lastRemembered, SHELL_SIDE_BAR_OPEN } =
  await import(new URL('../src/app/testing/account-preferences.ts', import.meta.url).href);

/** An account store that has already answered, so a `ShellState` over it adopts what it holds. */
function settled(seed = {}) {
  return settledAccountPreferences({ shell: seed });
}

function shellOver(account) {
  return new ShellState({ account });
}

/** Let the writes this store issued settle, so a second `ShellState` over it sees them. */
async function flush() {
  await new Promise((resolve) => setTimeout(resolve, 0));
}

test('a rail click opens an area without navigating, and the same click again collapses it', () => {
  const shell = shellOver(stubAccountPreferences());
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
  const shell = shellOver(stubAccountPreferences());
  shell.activateArea('logs', false);
  assert.equal(shell.open(), true);

  assert.equal(shell.activateArea('home', true), true, 'the caller is told to navigate');
  assert.equal(shell.open(), false, 'and the side bar collapses in the same gesture');
  assert.equal(shell.visibleArea(), 'home');
});

test('the router sets the active area, and fills the side bar only when it is not showing another', () => {
  const shell = shellOver(stubAccountPreferences());
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

test('Ctrl/Cmd+B toggles, and remembers the answer per user on the instance', async () => {
  const account = await settled();
  const first = shellOver(account);
  assert.equal(first.open(), SIDE_BAR_OPEN_DEFAULT, 'nothing remembered yet');

  first.setActiveArea('tasks');
  first.toggleOpen();
  assert.equal(first.open(), !SIDE_BAR_OPEN_DEFAULT);
  assert.equal(lastRemembered(account.calls, SHELL_SIDE_BAR_OPEN), SIDE_BAR_OPEN_DEFAULT ? '0' : '1');

  await flush();
  const reloaded = shellOver(account);
  assert.equal(reloaded.open(), !SIDE_BAR_OPEN_DEFAULT, 'another tab -- and another machine -- remembers');
});

test("Home's collapse is not the user's preference, so it is never written through (DW-134)", async () => {
  // Home has no screen list, so the bar goes away because there is nothing to show -- the
  // user never asked for it to be closed. Persisting that made the next area they opened
  // start collapsed, on a preference they had set to open and never changed.
  const account = await settled();
  const shell = shellOver(account);
  shell.activateArea('logs', false);
  assert.equal(shell.open(), true);
  assert.equal(lastRemembered(account.calls, SHELL_SIDE_BAR_OPEN), '1', 'opening an area is the user asking');

  assert.equal(shell.activateArea('home', true), true, 'the caller is told to navigate');
  assert.equal(shell.open(), false, 'and the bar collapses for Home');
  assert.equal(
    lastRemembered(account.calls, SHELL_SIDE_BAR_OPEN),
    '1',
    "the remembered preference still reads the user's own answer"
  );

  await flush();
  const reloaded = shellOver(account);
  assert.equal(reloaded.open(), true, 'so another tab still opens the bar');
});

test("a tile shows its area's list and never toggles it shut (Story 1.12)", async () => {
  // A tile is not the rail item: the rail's click-to-collapse branch is about clicking the
  // item whose list is already showing, and activating a tile twice must leave the area open.
  const account = await settled();
  const shell = shellOver(account);

  shell.showArea('logs');
  assert.equal(shell.visibleArea(), 'logs');
  assert.equal(shell.open(), true);
  assert.equal(lastRemembered(account.calls, SHELL_SIDE_BAR_OPEN), '1', 'opening an area is the user asking');

  shell.showArea('logs');
  assert.equal(shell.open(), true, 'a second activation does not toggle it shut');
  assert.equal(shell.visibleArea(), 'logs');

  // The contentious case, pinned rather than left to the doc comment: a user who answered
  // "keep it closed" with Ctrl/Cmd+B and then clicks a tile has asked for the area, so the
  // answer is replaced -- the same thing activateArea's opening branch does from the rail.
  const stored = await settled({ [SHELL_SIDE_BAR_OPEN]: '0' });
  const reopened = shellOver(stored);
  assert.equal(reopened.open(), false, 'starting from the remembered answer');
  reopened.showArea('logs');
  assert.equal(reopened.open(), true, 'the tile opens it anyway');
  assert.equal(lastRemembered(stored.calls, SHELL_SIDE_BAR_OPEN), '1', 'and replaces the answer it found');
});

test('a dismissal collapses the bar without writing the preference (DW-144)', async () => {
  // Escape says "not this, now"; Ctrl/Cmd+B says "keep it closed". Routing both through
  // toggleOpen() made one Escape start every later area, and every later tab, collapsed.
  const account = await settled();
  const shell = shellOver(account);
  shell.activateArea('logs', false);
  assert.equal(lastRemembered(account.calls, SHELL_SIDE_BAR_OPEN), '1');

  shell.collapse();
  assert.equal(shell.open(), false, 'the bar goes away');
  assert.equal(lastRemembered(account.calls, SHELL_SIDE_BAR_OPEN), '1', 'the remembered answer does not');

  await flush();
  assert.equal(shellOver(account).open(), true, 'so another tab opens it');
});

test('collapsing an already-collapsed bar is a no-op, and notifies nobody', () => {
  const shell = shellOver(stubAccountPreferences());
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

test('the toggle has an area to show even when nothing has been opened yet', async () => {
  const shell = shellOver(await settled({ [SHELL_SIDE_BAR_OPEN]: '0' }));
  shell.setActiveArea('logs');
  shell.toggleOpen();
  assert.equal(shell.open(), true);
  assert.equal(shell.visibleArea(), 'logs', 'Ctrl+B on a cold load shows the current area');
});

test('every state change notifies, so the rail and the side bar redraw together', () => {
  const shell = shellOver(stubAccountPreferences());
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

// The agent-navigation arrival slot (Story 4.7, AC5). `locator-bar.spec.ts` pins the consumer;
// this pins the store's own contract, including the clearing `app.ts` calls on NavigationStart.
//
// Mutation (Rule 19): make `clearArrival` a no-op -> the third row below goes red, and an
// agent-navigation announcement would label that screen's heading on every later, user-initiated
// arrival at it.

test('an arrival is standing only for the route it names', () => {
  const shell = shellOver(stubAccountPreferences());
  assert.equal(shell.arrivalAnnouncement('permissions/users'), null, 'nothing is standing to begin with');
  shell.announceArrival('permissions/users', 'Users -- opened by the agent; Back returns');
  assert.equal(shell.arrivalAnnouncement('permissions/users'), 'Users -- opened by the agent; Back returns');
  assert.equal(shell.arrivalAnnouncement('tasks/schedule'), null, 'and never on another route');
});

test('a fresh arrival at the same route changes the token even when the text repeats', () => {
  const shell = shellOver(stubAccountPreferences());
  shell.announceArrival('permissions/users', 'same words');
  const first = shell.arrivalToken('permissions/users');
  shell.announceArrival('permissions/users', 'same words');
  assert.notEqual(shell.arrivalToken('permissions/users'), first, 'the reader can tell two arrivals apart');
  assert.equal(shell.arrivalToken('tasks/schedule'), null);
});

test('clearing the arrival drops it, so it never survives into the next navigation', () => {
  const shell = shellOver(stubAccountPreferences());
  shell.announceArrival('permissions/users', 'Users -- opened by the agent; Back returns');
  let notified = 0;
  const stop = shell.subscribe(() => {
    notified += 1;
  });
  shell.clearArrival();
  assert.equal(shell.arrivalAnnouncement('permissions/users'), null, 'no announcement is standing');
  assert.equal(shell.arrivalToken('permissions/users'), null, 'and no token either');
  assert.equal(notified, 1, 'the clear redraws the locator bar');
  shell.clearArrival();
  stop();
  assert.equal(notified, 1, 'clearing nothing changes nothing');
});

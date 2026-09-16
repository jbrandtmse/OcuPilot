// Pins the Escape order the shell's one handler asks for (DW-137, DW-109; EXPERIENCE.md
// `:533`). The stack is framework-free precisely so the order is decided somewhere
// `node --test` can execute it, rather than emerging from whichever component's key handler
// happens to see the event first.
//
// Mutations (Rule 19):
// - make `push` append unconditionally, dropping the de-duplication -> the "registering twice
//   is idempotent" row goes red, and one Escape would close a surface that is already closed.
// - make `closeTop` call the callback before removing the entry -> the "a callback that
//   forgets to unregister cannot wedge the stack" row goes red.
// - ignore the `'bottom'` position -> the side-bar ordering row goes red, and a bar opened
//   over an open command box would swallow the box's Escape.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { OverlayStack } = await import(join(uiRoot, 'src', 'app', 'core', 'overlay-stack.ts'));

test('an empty stack closes nothing and says so, which is what returns focus to content', () => {
  const stack = new OverlayStack();
  assert.equal(stack.top(), '');
  assert.equal(stack.closeTop(), false);
  assert.deepEqual(stack.ids(), []);
});

test('Escape closes the topmost member and leaves the one under it alone', () => {
  const closed = [];
  const stack = new OverlayStack();
  stack.push('side-bar', () => closed.push('side-bar'), 'bottom');
  stack.push('command-box', () => closed.push('command-box'));

  assert.equal(stack.top(), 'command-box');
  assert.equal(stack.closeTop(), true);
  assert.deepEqual(closed, ['command-box'], 'the box closes and the bar does not');
  assert.deepEqual(stack.ids(), ['side-bar'], 'and the bar is still registered');

  assert.equal(stack.closeTop(), true);
  assert.deepEqual(closed, ['command-box', 'side-bar'], 'a second Escape reaches the bar');
  assert.equal(stack.closeTop(), false, 'and a third has nothing left to close');
});

test('the side bar stays the bottom-most member however late it registers', () => {
  const stack = new OverlayStack();
  stack.push('command-box', () => {});
  stack.push('side-bar', () => {}, 'bottom');
  assert.deepEqual(stack.ids(), ['side-bar', 'command-box']);
  assert.equal(stack.top(), 'command-box', 'a bar opened later must not swallow the box Escape');
});

test('registering twice moves the entry rather than adding a second one', () => {
  let closes = 0;
  const stack = new OverlayStack();
  stack.push('account-menu', () => {
    closes += 1;
  });
  stack.push('account-menu', () => {
    closes += 1;
  });
  assert.deepEqual(stack.ids(), ['account-menu']);
  stack.closeTop();
  assert.equal(closes, 1, 'one registration, one close');
  assert.equal(stack.closeTop(), false, 'and no ghost entry left behind');
});

test('remove unregisters, and is a no-op for an id that is not there', () => {
  const stack = new OverlayStack();
  stack.push('account-menu', () => {});
  stack.remove('command-box');
  assert.deepEqual(stack.ids(), ['account-menu']);
  stack.remove('account-menu');
  assert.deepEqual(stack.ids(), []);
  stack.remove('account-menu');
  assert.deepEqual(stack.ids(), [], 'a close path may call remove unconditionally');
});

test('closeTop removes the entry BEFORE calling it, so a forgetful callback cannot wedge it', () => {
  const stack = new OverlayStack();
  let seenDuringClose = null;
  // A component whose close callback does not unregister -- the failure mode a stack that
  // removed afterwards would turn into an Escape key that stops working.
  stack.push('forgetful', () => {
    seenDuringClose = stack.ids().slice();
  });
  assert.equal(stack.closeTop(), true);
  assert.deepEqual(seenDuringClose, [], 'the entry is already gone while its callback runs');
  assert.equal(stack.closeTop(), false);
});

test('a close callback that re-registers is still gone after the call, not duplicated', () => {
  const stack = new OverlayStack();
  stack.push('side-bar', () => stack.remove('side-bar'), 'bottom');
  assert.equal(stack.closeTop(), true);
  assert.deepEqual(stack.ids(), []);
});

test('every change notifies, so a subscriber redraws with the stack', () => {
  const stack = new OverlayStack();
  let notices = 0;
  const stop = stack.subscribe(() => {
    notices += 1;
  });
  stack.push('a', () => {});
  stack.push('b', () => {});
  stack.closeTop();
  stack.remove('a');
  assert.equal(notices, 4);
  stop();
  stack.push('c', () => {});
  assert.equal(notices, 4, 'and unsubscribing stops it');
});

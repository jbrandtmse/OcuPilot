// Story 3.5: the open form's unsaved-changes state (`core/form-dirty.ts`) and the reader for a
// validation envelope's `detail.violations[]` (`core/violations.ts`). Both are framework-free, so
// the fastest suite in the project is what pins them.
//
// Mutations (Rule 19):
// - make `requestLeave()` resolve `true` unconditionally -> the decline leg goes red on the
//   resolved promise, which is the observable AC2 names;
// - let `answer(true)` leave the dirty flag standing -> the "an accept clears the flag" leg goes
//   red and the next form inherits a guard nobody armed;
// - drop the `field === '' || code === ''` guard in `violationsOf` -> the malformed-row leg goes
//   red, a refusal arriving on a control nothing can focus.

import { test } from 'node:test';
import assert from 'node:assert/strict';

import { FormDirty } from '../src/app/core/form-dirty.ts';
import { reasonForField, violationsOf } from '../src/app/core/violations.ts';

const refusal = (violations) => ({
  kind: 'error',
  status: 422,
  code: 'AGENT.VALIDATION',
  reason: 'The agent definition was refused',
  detail: { violations },
});

test('a clean form lets every navigation through, and raises nothing', async () => {
  const dirty = new FormDirty();
  assert.equal(dirty.dirty(), false);
  assert.equal(await dirty.requestLeave(), true);
  assert.equal(dirty.pending(), false, 'and no confirmation was raised for a form with no work in it');
});

test('AC2: a dirty form raises the confirmation, and a decline resolves the navigation false', async () => {
  const dirty = new FormDirty();
  dirty.setDirty(true);
  const asked = dirty.requestLeave();
  assert.equal(dirty.pending(), true, 'the confirmation is on screen while the question stands');
  dirty.answer(false);
  assert.equal(await asked, false, 'the guard answers false, which cancels the navigation');
  assert.equal(dirty.dirty(), true, 'and the work is still unsaved');
  assert.equal(dirty.pending(), false);
});

test('an accept resolves true and clears the flag, so the next form inherits no guard', async () => {
  const dirty = new FormDirty();
  dirty.setDirty(true);
  const asked = dirty.requestLeave();
  dirty.answer(true);
  assert.equal(await asked, true);
  assert.equal(dirty.dirty(), false);
  assert.equal(await dirty.requestLeave(), true, 'and the next navigation is not asked about');
});

test('a second question while one is pending is refused rather than answered by the first', async () => {
  const dirty = new FormDirty();
  dirty.setDirty(true);
  const first = dirty.requestLeave();
  assert.equal(await dirty.requestLeave(), false, 'no dialog stacks, so the second navigation is refused');
  dirty.answer(true);
  assert.equal(await first, true);
});

test('answer() is idempotent: a dialog that closes twice resolves one question once', async () => {
  const dirty = new FormDirty();
  dirty.setDirty(true);
  const asked = dirty.requestLeave();
  dirty.answer(false);
  dirty.answer(true);
  assert.equal(await asked, false, 'the first answer is the one that counts');
  assert.equal(dirty.dirty(), true, 'and the second did not clear the flag behind it');
});

test('reset() refuses any question still open rather than leaving navigateByUrl waiting', async () => {
  const dirty = new FormDirty();
  dirty.setDirty(true);
  const asked = dirty.requestLeave();
  dirty.reset();
  assert.equal(await asked, false, 'the safe direction: the navigation is refused, not allowed');
  assert.equal(dirty.dirty(), false);
  assert.equal(dirty.pending(), false);
});

test('subscribers are told when the flag or the question moves, and not on a no-op', () => {
  const dirty = new FormDirty();
  let notified = 0;
  const stop = dirty.subscribe(() => {
    notified += 1;
  });
  dirty.setDirty(true);
  dirty.setDirty(true);
  assert.equal(notified, 1, 'a keystroke on an already-dirty form re-renders nothing');
  void dirty.requestLeave();
  assert.equal(notified, 2);
  dirty.answer(false);
  assert.equal(notified, 3);
  stop();
  dirty.setDirty(false);
  assert.equal(notified, 3, 'and a released subscription hears nothing');
});

// --- the violation reader -----------------------------------------------------------------------

test('AD-39: a validation envelope yields one {field, code, reason} per violation, in order', () => {
  const read = violationsOf(
    refusal([
      { field: 'name', code: 'AGENT.NAME.REQUIRED', reason: 'Give the definition a name of 1 to 64 characters.' },
      { field: 'provider', code: 'AGENT.PROVIDER.UNKNOWN', reason: 'That provider is not one this instance offers. Choose one from the list.' },
    ])
  );
  assert.deepEqual(read.map((entry) => entry.field), ['name', 'provider']);
  assert.equal(read[0].code, 'AGENT.NAME.REQUIRED');
  assert.equal(reasonForField(read, 'provider'), 'That provider is not one this instance offers. Choose one from the list.');
  assert.equal(reasonForField(read, 'model'), '', 'a field with no refusal carries no sentence');
});

test('a row that names no field or no code is dropped rather than rendered on a control nothing can focus', () => {
  const read = violationsOf(
    refusal([
      null,
      'not an object',
      ['an', 'array'],
      { code: 'AGENT.NAME.REQUIRED' },
      { field: 'name' },
      { field: 'model', code: 'AGENT.MODEL.WHATEVER' },
    ])
  );
  assert.deepEqual(read, [{ field: 'model', code: 'AGENT.MODEL.WHATEVER', reason: '' }]);
});

test('an envelope with no violations, and every other result kind, read as no violations', () => {
  assert.deepEqual(violationsOf(refusal([])), []);
  assert.deepEqual(violationsOf({ kind: 'error', status: 500, code: 'INTERNAL', reason: 'x', detail: null }), []);
  assert.deepEqual(violationsOf({ kind: 'error', status: 422, code: 'X', reason: 'x', detail: { violations: 'no' } }), []);
  assert.deepEqual(violationsOf({ kind: 'ok', status: 200, body: {} }), []);
  assert.deepEqual(violationsOf({ kind: 'installing', status: 503, code: 'INSTALL.INSTALLING' }), []);
});

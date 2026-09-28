import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the client half of the read-back line (AD-58, Story 16.17): the wire shape is read only
// inside the instance's vocabulary, and each verdict renders as EXPERIENCE.md's Fixed strings row
// says -- names only, up to three and then " and <n> more", the written clause appended to a
// matches or differs line, and a form's "Saved" joined to its line. The client compares nothing.
// Needs nothing but the checkout.
//
// Mutations (Rule 19):
// - answer a verdict outside READ_BACK_VERDICTS in readBackOf() -> the vocabulary row goes red.
// - render '' for `notFound` in readBackLine() -> the per-verdict row goes red.

const corePath = (name) => join(dirname(fileURLToPath(import.meta.url)), '..', 'src', 'app', 'core', name);

const { READ_BACK_VERDICTS, readBackLine, readBackNames, readBackOf, savedLine, withReadBack } = await import(corePath('read-back.ts'));

const DOT = ' \u00b7 ';

test('a read-back is read only inside the instance vocabulary', () => {
  assert.deepEqual(readBackOf({ verdict: 'differs', fields: ['Description'], written: [] }), {
    verdict: 'differs',
    fields: ['Description'],
    written: [],
    reason: '',
  });
  assert.deepEqual(readBackOf({ verdict: 'unchecked', fields: [], written: [], reason: 'running' })?.reason, 'running');
  for (const bad of [
    null,
    undefined,
    'matches',
    [],
    {},
    { verdict: 'fine', fields: [], written: [] },
    { verdict: 'differs', fields: 'Description', written: [] },
    { verdict: 'differs', fields: [3], written: [] },
    { verdict: 'unchecked', fields: [], written: [] },
    { verdict: 'unchecked', fields: [], written: [], reason: 'later' },
  ]) {
    assert.equal(readBackOf(bad), null, `${JSON.stringify(bad)} is no read-back`);
  }
  assert.deepEqual([...READ_BACK_VERDICTS].sort(), ['differs', 'matches', 'notFound', 'nothingSent', 'present', 'unchecked', 'written']);
});

test('each verdict renders its own published line', () => {
  const line = (value) => readBackLine(readBackOf(value));
  assert.equal(line({ verdict: 'matches', fields: [], written: [] }), 'Read back: matches');
  assert.equal(line({ verdict: 'differs', fields: ['Description'], written: [] }), 'Read back: differs in Description');
  assert.equal(line({ verdict: 'notFound', fields: [], written: [] }), 'Read back: not found');
  assert.equal(line({ verdict: 'present', fields: [], written: [] }), 'Read back: still present');
  assert.equal(line({ verdict: 'written', fields: [], written: ['NewPassword'] }), 'Read back: NewPassword written, not read back');
  assert.equal(line({ verdict: 'nothingSent', fields: [], written: [] }), 'Read back: nothing sent to compare');
  assert.equal(line({ verdict: 'unchecked', fields: [], written: [], reason: 'running' }), 'Read back: not checked, the write is still running');
  assert.equal(line({ verdict: 'unchecked', fields: [], written: [], reason: 'unreadable' }), 'Read back: could not be read');
  assert.equal(readBackLine(null), '', 'no read-back renders nothing');
});

test('names are listed up to three, then " and <n> more", and a written clause is appended', () => {
  assert.equal(readBackNames(['A', 'B', 'C']), 'A, B, C');
  assert.equal(readBackNames(['A', 'B', 'C', 'D', 'E']), 'A, B, C and 2 more');
  assert.equal(
    readBackLine(readBackOf({ verdict: 'differs', fields: ['A', 'B', 'C', 'D'], written: ['Password'] })),
    `Read back: differs in A, B, C and 1 more${DOT}Password written, not read back`
  );
  assert.equal(readBackLine(readBackOf({ verdict: 'matches', fields: [], written: ['Secret'] })), `Read back: matches${DOT}Secret written, not read back`);
});

test('a form reads "Saved" with its line, and a row announcement gains the line', () => {
  const matches = readBackOf({ verdict: 'matches', fields: [], written: [] });
  assert.equal(savedLine(matches), `Saved${DOT}Read back: matches`);
  assert.equal(savedLine(null), 'Saved', 'a Save that answered none reads Saved alone');
  assert.equal(withReadBack('Updated: /csp/a updated', matches), `Updated: /csp/a updated${DOT}Read back: matches`);
  assert.equal(withReadBack('Updated: /csp/a updated', null), 'Updated: /csp/a updated');
});

// Pins the shape of the tags `browser/turnprobe-spec.mjs` issues: each starts with its caller's
// marker, and two processes (two module instances here) never issue the same name, so a late
// provider call recorded under an earlier run's tag cannot answer a later run's turn.
//
// Mutation (Rule 19): revert `nextTag` to `${prefix}${count}` -> the two instances issue the same
// first tag and both tests go red.

import assert from 'node:assert/strict';
import test from 'node:test';

const first = await import('../browser/turnprobe-spec.mjs?a');
const second = await import('../browser/turnprobe-spec.mjs?b');

test('two module instances issue different tags for the same marker and count', () => {
  const options = { container: 'unused', marker: 'OCUTAGS' };
  const a = first.nextTag(options);
  const b = second.nextTag(options);
  assert.notEqual(a, b, 'the first tag of two runs differs');
  assert.ok(a.startsWith('OCUTAGS') && b.startsWith('OCUTAGS'), 'and each starts with its marker');
});

test('tags within one instance are distinct and carry the run and a count', () => {
  const options = { container: 'unused', marker: 'OCUTAGS2' };
  const tags = [first.nextTag(options), first.nextTag(options), first.nextTag(options)];
  assert.equal(new Set(tags).size, 3, 'three tags, three names');
  for (const [index, tag] of tags.entries()) assert.match(tag, new RegExp(`^OCUTAGS2[0-9a-f]{8}n${index + 1}$`), tag);
});

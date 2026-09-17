import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins `core/detail-highlights.ts`'s `DetailHighlights` (Story 6.8): moved out of
// `areas/tasks/details.store.ts` (Story 6.7's `TaskDetailsHighlights`, same behavior) so the OS
// management slice's Process details page imports it without a cross-slice import onto
// `areas/tasks/`.
//
// Mutation (Rule 19): make `update` compare `row` with itself instead of the held `previousRow`
// -> the second update highlights nothing and the `['Description']` assertion goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { DetailHighlights } = await import(join(uiRoot, 'src', 'app', 'core', 'detail-highlights.ts'));

test('DetailHighlights: the first update highlights nothing, a later one highlights only the changed field, and reset forgets it', () => {
  const highlights = new DetailHighlights();
  const fields = ['Name', 'Description', 'Suspended'];
  const first = { Name: 'A', Description: 'first', Suspended: false };
  highlights.update(first, fields);
  assert.deepEqual([...highlights.changed()], [], 'nothing to compare against yet');

  const second = { Name: 'A', Description: 'second', Suspended: false };
  highlights.update(second, fields);
  assert.deepEqual([...highlights.changed()], ['Description'], 'only the field whose value changed');

  const third = { Name: 'A', Description: 'second', Suspended: false };
  highlights.update(third, fields);
  assert.deepEqual([...highlights.changed()], ['Description'], 'a tick that changes nothing keeps the highlight (EXPERIENCE.md "Highlight.")');

  highlights.reset();
  highlights.update({ Name: 'B', Description: 'brand new task', Suspended: true }, fields);
  assert.deepEqual([...highlights.changed()], [], 'a fresh entity after reset is not a change from the last one');
});

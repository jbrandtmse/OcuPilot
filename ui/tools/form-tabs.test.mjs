/**
 * `core/form-tabs.ts` (Story 9.1): which tab a refusal belongs on, how many each holds, and the
 * accessible name a tab carries while it holds some -- the pattern Epic 9's editors share.
 */

import assert from 'node:assert/strict';
import { test } from 'node:test';

import { tabAccessibleName, tabErrorCounts, tabToOpen } from '../src/app/core/form-tabs.ts';

const FIELD_TABS = { FullName: 'general', Comment: 'general', EmailAddress: 'general', Roles: 'roles' };
const ORDER = ['FullName', 'Comment', 'EmailAddress', 'Roles'];

function refused(...fields) {
  return fields.map((field) => ({ field, code: 'X', reason: `${field} is wrong` }));
}

// Mutation (Rule 19): count every refusal on the first tab -> the per-tab counts go red.
test('each tab counts the refusals on its own fields, and an unplaced field counts nowhere', () => {
  assert.deepEqual(tabErrorCounts(FIELD_TABS, refused('Comment', 'Roles', 'EmailAddress', 'Nowhere')), { general: 2, roles: 1 });
  assert.deepEqual(tabErrorCounts(FIELD_TABS, []), {});
});

// Mutation (Rule 19): answer the first refusal as it arrived instead of the first in field order ->
// the reordered case goes red.
test('the tab to open holds the first refused field in the form\'s own order', () => {
  assert.equal(tabToOpen(FIELD_TABS, ORDER, refused('Roles', 'Comment')), 'general', 'Comment precedes Roles in the form');
  assert.equal(tabToOpen(FIELD_TABS, ORDER, refused('Roles')), 'roles');
  assert.equal(tabToOpen(FIELD_TABS, ['Roles', 'FullName'], refused('FullName', 'Roles')), 'roles', 'the order is the caller\'s');
  assert.equal(tabToOpen(FIELD_TABS, ORDER, refused('Nowhere')), null, 'a refusal on no tab opens none');
  assert.equal(tabToOpen(FIELD_TABS, ORDER, []), null);
});

// Mutation (Rule 19): drop the singular branch -> "General, 1 errors" and this goes red.
test('a tab with refusals names their count, singular and plural, and one without is its label', () => {
  assert.equal(tabAccessibleName('General', 0), 'General');
  assert.equal(tabAccessibleName('General', 1), 'General, 1 error');
  assert.equal(tabAccessibleName('General', 3), 'General, 3 errors');
});

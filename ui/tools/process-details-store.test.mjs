import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins Process details' own state (`areas/os-management/process-details.store.ts`, Story 6.8):
// which declared columns render under which of the page's three group headings, and the word
// InTransaction reads as.
//
// Mutations (Rule 19):
// - drop 'CurrentLineAndRoutine' from EXECUTION_FIELDS -> the Execution-group assertion for it
//   goes red, reading 'general' instead.
// - read InTransaction as zero for a non-zero numeric string -> the "Yes" assertion goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const store = await import(join(uiRoot, 'src', 'app', 'areas', 'os-management', 'process-details.store.ts'));
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

test('groupFor: the Execution and Client application columns are named, everything else falls to General', () => {
  for (const field of ['State', 'InTransaction', 'Routine', 'CurrentLineAndRoutine', 'Location']) {
    assert.equal(store.groupFor(field), 'execution', `${field} is Execution`);
  }
  for (const field of ['ClientNodeName', 'ClientExecutableName', 'ClientIPAddress']) {
    assert.equal(store.groupFor(field), 'client', `${field} is Client application`);
  }
  for (const field of ['Pid', 'ParentPid', 'UserName', 'NameSpace', 'CPUTime', 'OpenDevices']) {
    assert.equal(store.groupFor(field), 'general', `${field} falls to General`);
  }
});

test('inTransactionText: "Yes" for a non-zero value, "No" for zero, empty or absent', () => {
  assert.equal(store.inTransactionText({ InTransaction: 1 }), STRINGS.tableStatusYes);
  assert.equal(store.inTransactionText({ InTransaction: '2' }), STRINGS.tableStatusYes);
  assert.equal(store.inTransactionText({ InTransaction: 0 }), STRINGS.tableStatusNo);
  assert.equal(store.inTransactionText({ InTransaction: '0' }), STRINGS.tableStatusNo);
  assert.equal(store.inTransactionText({ InTransaction: '' }), STRINGS.tableStatusNo);
  assert.equal(store.inTransactionText({}), STRINGS.tableStatusNo);
});

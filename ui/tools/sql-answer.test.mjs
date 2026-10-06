import { test } from 'node:test';
import assert from 'node:assert/strict';

import { answerOf, sqlOutcomeLines, statusLineFor } from '../src/app/core/sql-answer.ts';
import { STRINGS } from '../src/app/core/strings.ts';

// Story 19.11: the answer a confirmed SQL run's `output` carries is read by the proposal card through the
// same code the console reads its own answers with.

test('answerOf reads each outcome the run route answers, and null for any other shape', () => {
  assert.deepEqual(answerOf({ outcome: 'done', kind: 'dml', rowCount: 2 }), { outcome: 'done', kind: 'dml', rowCount: 2 });
  assert.equal(answerOf({ outcome: 'rows', columns: ['A'], rows: [['1']], truncated: false })?.outcome, 'rows');
  assert.equal(answerOf({ outcome: 'rows' }), null, 'rows without a row list is no answer');
  assert.equal(answerOf({ outcome: 'unheard-of' }), null);
  assert.equal(answerOf(null), null);
  assert.equal(answerOf('text'), null);
});

test('statusLineFor reads a DML count, a DDL done, an error and the empty console', () => {
  assert.equal(statusLineFor(answerOf({ outcome: 'done', kind: 'dml', rowCount: 3 })), STRINGS.explorerSqlRowsChanged.replace('<n>', '3'));
  assert.equal(statusLineFor(answerOf({ outcome: 'done', kind: 'ddl', rowCount: 0 })), STRINGS.explorerSqlDone);
  assert.equal(statusLineFor(answerOf({ outcome: 'error', sqlcode: -30, message: 'x' })), STRINGS.explorerSqlCode.replace('<code>', '-30'));
  assert.equal(statusLineFor(null), STRINGS.explorerSqlEmpty);
});

test('sqlOutcomeLines adds the instance message only under an error, and nothing for a non-answer', () => {
  // Mutation (Rule 19): push the message for every outcome -> the `done` leg goes red.
  assert.deepEqual(sqlOutcomeLines({ outcome: 'done', kind: 'ddl', message: 'ignored' }), [STRINGS.explorerSqlDone]);
  assert.deepEqual(sqlOutcomeLines({ outcome: 'error', sqlcode: -1, message: 'boom' }), [STRINGS.explorerSqlCode.replace('<code>', '-1'), 'boom']);
  assert.deepEqual(sqlOutcomeLines({ outcome: 'error', message: '' }), []);
  assert.deepEqual(sqlOutcomeLines(undefined), []);
});

// Mutation (Rule 19): `statusLineFor` dropping the `explorerSqlRowsChangedOne` branch -> the DML leg goes red.
test('statusLineFor reads a count of 1 in the singular and 0 and 2 in the plural (DW-2092)', () => {
  const rows = (count, truncated) => answerOf({ outcome: 'rows', columns: ['A'], rows: Array.from({ length: count }, () => ['1']), truncated });
  assert.equal(statusLineFor(rows(1, false)), '1 row');
  assert.equal(statusLineFor(rows(2, false)), '2 rows');
  assert.equal(statusLineFor(rows(0, false)), '0 rows');
  assert.equal(statusLineFor(rows(1, true)), '1 row is shown; the answer holds more.');
  assert.equal(statusLineFor(rows(2, true)), '2 rows are shown; the answer holds more.');
  const dml = (count) => statusLineFor(answerOf({ outcome: 'done', kind: 'dml', rowCount: count }));
  assert.equal(dml(1), '1 row changed');
  assert.equal(dml(2), '2 rows changed');
  assert.equal(dml(0), '0 rows changed');
  const takes = (count) => statusLineFor(answerOf({ outcome: 'parameters', count }));
  assert.equal(takes(1), 'This statement takes 1 value.');
  assert.equal(takes(2), 'This statement takes 2 values.');
});

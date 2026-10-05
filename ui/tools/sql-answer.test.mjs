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

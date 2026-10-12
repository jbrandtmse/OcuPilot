import { test } from 'node:test';
import assert from 'node:assert/strict';

import { testAnswerOf, testOutcomeLines, testStatusLine } from '../src/app/core/test-answer.ts';
import { outputLinesOf, outputErrorsOf } from '../src/app/core/turn.ts';
import { STRINGS } from '../src/app/core/strings.ts';

// Story 20.6: the answer a host test's `output` carries is read by the Test dialog and by the proposal card through the same code.

const done = { status: 'done', sessionId: '41', responseClass: 'Ens.StringResponse', lines: ['StringValue: echo:<b>x</b>'], errors: false };

test('testAnswerOf reads each of the three statuses, and null for any other shape', () => {
  // Mutation (Rule 19): accept any string status -> the unheard-of leg goes red.
  assert.deepEqual(testAnswerOf(done), { ...done });
  assert.equal(testAnswerOf({ status: 'waiting', sessionId: '7', lines: [] })?.status, 'waiting');
  assert.equal(testAnswerOf({ status: 'error', sessionId: '7', lines: ['boom'], errors: true })?.errors, true);
  assert.equal(testAnswerOf({ status: 'unheard-of', sessionId: '7', lines: [] }), null);
  assert.equal(testAnswerOf({ status: 'done', lines: [] }), null, 'no session is no test answer');
  assert.equal(testAnswerOf({ status: 'done', sessionId: '7' }), null, 'no lines is no test answer');
  assert.equal(testAnswerOf({ lines: ['a'], errors: false }), null, 'a compile output carries no status');
  assert.equal(testAnswerOf(null), null);
  assert.equal(testAnswerOf('text'), null);
  assert.equal(testAnswerOf([done]), null);
});

test('testStatusLine reads an answer, no response, a wait and a failure, each with its session', () => {
  assert.equal(testStatusLine(testAnswerOf(done)), STRINGS.interopTestDone.replace('<session>', '41').replace('<class>', 'Ens.StringResponse'));
  assert.equal(testStatusLine(testAnswerOf({ ...done, responseClass: '', lines: [] })), STRINGS.interopTestDoneNoResponse.replace('<session>', '41'));
  assert.equal(testStatusLine(testAnswerOf({ status: 'waiting', sessionId: '9', lines: [] })), STRINGS.interopTestWaiting.replace('<session>', '9'));
  assert.equal(testStatusLine(testAnswerOf({ status: 'error', sessionId: '3', lines: ['x'], errors: true })), STRINGS.interopTestFailed.replace('<session>', '3'));
});

test('testOutcomeLines is the status sentence then the lines, and nothing for a non-answer', () => {
  // Mutation (Rule 19): drop the status sentence -> the first leg goes red.
  assert.deepEqual(testOutcomeLines(done), [STRINGS.interopTestDone.replace('<session>', '41').replace('<class>', 'Ens.StringResponse'), 'StringValue: echo:<b>x</b>']);
  assert.deepEqual(testOutcomeLines({ status: 'waiting', sessionId: '9', lines: [] }), [STRINGS.interopTestWaiting.replace('<session>', '9')]);
  assert.deepEqual(testOutcomeLines({ lines: ['compile line'], errors: false }), []);
  assert.deepEqual(testOutcomeLines(undefined), []);
});

// Mutation (Rule 19): drop the test branch from `outputLinesOf` -> the first leg goes red (the card would show the response's lines with no sentence).
test('outputLinesOf reads a confirmed host test as its status sentence and lines, and leaves a compile and a SQL run as they were', () => {
  assert.deepEqual(outputLinesOf(done), [STRINGS.interopTestDone.replace('<session>', '41').replace('<class>', 'Ens.StringResponse'), 'StringValue: echo:<b>x</b>']);
  assert.deepEqual(outputLinesOf({ lines: ['one', 'two'], errors: true }), ['one', 'two']);
  assert.deepEqual(outputLinesOf({ kind: 'ddl', outcome: 'done', rowCount: 0 }), [STRINGS.explorerSqlDone]);
  assert.equal(outputErrorsOf({ status: 'error', sessionId: '3', lines: ['x'], errors: true }), true, 'a failed test marks the card');
  assert.equal(outputErrorsOf(done), false);
});

// A test answer carries no `outcome` member (AD-39's seventh exception): `outputLinesOf` reads one that does as a SQL run's answer, so the card would
// show the SQL status line in place of the test's. Mutation (Rule 19): make `OcuPilot.Screen.Tool.InteropItemTestSend.WriteOutput` add an `outcome`
// member -> InteropTestDescriptor's outcome leg goes red, and this shows what the card would have drawn.
test('an output that carries an outcome is read as a SQL answer, which is why a test answer carries none', () => {
  assert.deepEqual(outputLinesOf({ ...done, outcome: 'done', kind: 'ddl', rowCount: 0 }), [STRINGS.explorerSqlDone]);
});

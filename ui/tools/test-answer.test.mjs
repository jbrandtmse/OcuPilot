import { test } from 'node:test';
import assert from 'node:assert/strict';

import { testAnswerOf, testOutcomeLines, testStatusLine, transformAnswerOf, transformOutcomeLines, transformStatusLine } from '../src/app/core/test-answer.ts';
import { outputLinesOf, outputErrorsOf } from '../src/app/core/turn.ts';
import { STRINGS } from '../src/app/core/strings.ts';

// Story 20.6: the answer a host test's `output` carries is read by the Test dialog and by the proposal card through the same code.

const done = { status: 'done', sessionId: '41', responseClass: 'Ens.StringResponse', lines: ['StringValue: echo:<b>x</b>'], errors: false };

// Story 20.27: a data transformation test's answer.
const transformDone = { status: 'done', sourceClass: 'Ens.StringRequest', targetClass: 'Ens.StringResponse', lines: ['<StringResponse>', '  <StringValue>out:<b>x</b></StringValue>', '</StringResponse>'], console: [], errors: false };

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
});

// A test's `errors` flag is its own failure and not a compile's: the card's summary line reads `outputErrorsOf` as "Compiled" or "compile errors".
// Mutation (Rule 19): make `outputErrorsOf` read any `lines` plus `errors` output again -> the host and transformation legs go red.
test('outputErrorsOf answers null for a host test and a transformation test, and still reads a compile', () => {
  assert.equal(outputErrorsOf({ status: 'error', sessionId: '3', lines: ['x'], errors: true }), null, 'a failed host test is no compile error');
  assert.equal(outputErrorsOf(done), null, 'a host test that answered is no compile');
  assert.equal(outputErrorsOf(transformDone), null, 'a transformation test that ran is no compile');
  assert.equal(outputErrorsOf({ ...transformDone, status: 'transform', lines: ['boom'], errors: true }), null, 'a failed transformation is no compile error');
  assert.equal(outputErrorsOf({ lines: ['Compiling A'], errors: true }), true, 'a compile with errors still marks the card');
  assert.equal(outputErrorsOf({ lines: ['Compiling A'], errors: false }), false);
  assert.equal(outputErrorsOf({ lines: 'text', errors: true }), null, 'lines that are not an array are no compile');
  assert.equal(outputErrorsOf(null), null);
});

// A test answer carries no `outcome` member (AD-39's seventh exception): `outputLinesOf` reads one that does as a SQL run's answer, so the card would
// show the SQL status line in place of the test's. Mutation (Rule 19): make `OcuPilot.Screen.Tool.InteropItemTestSend.WriteOutput` add an `outcome`
// member -> InteropTestDescriptor's outcome leg goes red, and this shows what the card would have drawn.
test('an output that carries an outcome is read as a SQL answer, which is why a test answer carries none', () => {
  assert.deepEqual(outputLinesOf({ ...done, outcome: 'done', kind: 'ddl', rowCount: 0 }), [STRINGS.explorerSqlDone]);
});

// Story 20.27: a data transformation test answers its own status, classes, lines and console; the dialog and the proposal card read it through the same code.

test('transformAnswerOf reads each of the four statuses, and null for any other shape', () => {
  // Mutation (Rule 19): accept a non-array `lines` (read it as `[]`) -> the not-an-array legs go red.
  assert.deepEqual(transformAnswerOf(transformDone), { ...transformDone });
  for (const status of ['input', 'transform', 'output']) {
    assert.equal(transformAnswerOf({ ...transformDone, status, lines: ['why'], errors: true })?.status, status);
    assert.equal(transformAnswerOf({ ...transformDone, status, lines: ['why'], errors: true })?.errors, true);
  }
  assert.equal(transformAnswerOf({ ...transformDone, targetClass: undefined })?.targetClass, '', 'an absent target class reads as none');
  assert.equal(transformAnswerOf({ ...transformDone, lines: ['a', 7, 'b'] })?.lines.join(','), 'a,b', 'only strings are lines');
  assert.equal(transformAnswerOf({ ...transformDone, status: 'waiting' }), null, 'a host test status is no transformation status');
  assert.equal(transformAnswerOf({ ...transformDone, status: 'unheard-of' }), null);
  assert.equal(transformAnswerOf({ ...transformDone, sourceClass: undefined }), null, 'no source class is no transformation answer');
  assert.equal(transformAnswerOf({ ...transformDone, lines: 'text' }), null, 'lines that are not an array');
  assert.equal(transformAnswerOf({ ...transformDone, lines: undefined }), null, 'no lines');
  assert.equal(transformAnswerOf({ ...transformDone, console: 'text' }), null, 'a console that is not an array');
  assert.equal(transformAnswerOf({ ...transformDone, console: undefined }), null, 'no console');
  assert.equal(transformAnswerOf(done), null, 'a host test answer carries a session and no console');
  assert.equal(transformAnswerOf({ lines: ['a'], errors: false }), null, 'a compile output carries no status');
  assert.equal(transformAnswerOf(null), null);
  assert.equal(transformAnswerOf('text'), null);
  assert.equal(transformAnswerOf([transformDone]), null);
});

test('a host test answer and a transformation answer are never read as each other', () => {
  assert.equal(testAnswerOf(transformDone), null, 'a transformation answer carries no session');
  assert.equal(transformAnswerOf(done), null);
  assert.deepEqual(transformOutcomeLines(done), []);
  assert.deepEqual(testOutcomeLines(transformDone), []);
});

test('transformStatusLine reads each status as its published sentence', () => {
  assert.equal(transformStatusLine(transformAnswerOf(transformDone)), STRINGS.interopTransformDone);
  assert.equal(transformStatusLine(transformAnswerOf({ ...transformDone, status: 'input' })), STRINGS.interopTransformInputFailed);
  assert.equal(transformStatusLine(transformAnswerOf({ ...transformDone, status: 'transform' })), STRINGS.interopTransformFailed);
  assert.equal(transformStatusLine(transformAnswerOf({ ...transformDone, status: 'output' })), STRINGS.interopTransformOutputFailed);
});

test('transformOutcomeLines is the status sentence, the lines, then the console label and its lines when there are any', () => {
  // Mutation (Rule 19): drop the console label or the console lines -> the second leg goes red.
  assert.deepEqual(transformOutcomeLines(transformDone), [STRINGS.interopTransformDone, ...transformDone.lines]);
  assert.deepEqual(transformOutcomeLines({ ...transformDone, console: ['probe-device-line'] }), [
    STRINGS.interopTransformDone,
    ...transformDone.lines,
    STRINGS.interopTransformConsole,
    'probe-device-line',
  ]);
  assert.deepEqual(transformOutcomeLines({ ...transformDone, status: 'input', lines: ['no object'], errors: true }), [STRINGS.interopTransformInputFailed, 'no object']);
  assert.deepEqual(transformOutcomeLines({ lines: ['compile line'], errors: false }), []);
  assert.deepEqual(transformOutcomeLines(undefined), []);
});

// Mutation (Rule 19): drop the transformation branch from `outputLinesOf` -> the first leg goes red (the card would show the target's lines with no sentence).
test('outputLinesOf reads a confirmed transformation test as its status sentence, lines and console, and leaves the other outputs as they were', () => {
  assert.deepEqual(outputLinesOf(transformDone), [STRINGS.interopTransformDone, ...transformDone.lines]);
  assert.deepEqual(outputLinesOf(done), [STRINGS.interopTestDone.replace('<session>', '41').replace('<class>', 'Ens.StringResponse'), 'StringValue: echo:<b>x</b>']);
  assert.deepEqual(outputLinesOf({ lines: ['one', 'two'], errors: true }), ['one', 'two']);
});

// A transformation answer carries no `outcome` member either, for the reason a host test's carries none (AD-39's seventh exception).
test('an output that carries an outcome is read as a SQL answer, so a transformation answer carries none', () => {
  assert.deepEqual(outputLinesOf({ ...transformDone, outcome: 'done', kind: 'ddl', rowCount: 0 }), [STRINGS.explorerSqlDone]);
});

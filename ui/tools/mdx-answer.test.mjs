import { test } from 'node:test';
import assert from 'node:assert/strict';

import { mdxAnswerOf, mdxConfirmOf, mdxStatusLineFor } from '../src/app/core/mdx-answer.ts';
import { STRINGS } from '../src/app/core/strings.ts';

// Story 20.33: what an MDX run answers, as the MDX query page reads it -- the four outcomes of a run, the
// ask-first answer of a start, and the status line each reads as.
//
// Mutations (Rule 19):
// - `mdxConfirmOf` answering `null` for an empty `constructs` -> "a confirm with no constructs answers an
//   empty list" goes red, and `mdx-query.page.spec.ts`'s empty-constructs case with it.
// - `mdxStatusLineFor` reading the available counts from the shown ones -> the cells line leg goes red.
// - `mdxAnswerOf` answering a `rows` outcome with no row list as a listing -> the listing leg goes red.

const CELLS = {
  outcome: 'cells',
  cube: 'OcuPilotProbeVisits',
  columns: ['Visits', 'Cost'],
  rows: [
    { label: 'North', cells: ['3', '9'] },
    { label: 'South', cells: ['5', '15'] },
  ],
  rowsAvailable: 40,
  columnsAvailable: 2,
  truncated: true,
  seconds: 1,
};

test('mdxAnswerOf reads a cells answer: the cube, the column headers, each row with its label and cells, the available counts', () => {
  const answer = mdxAnswerOf(CELLS);
  assert.deepEqual(answer, {
    outcome: 'cells',
    cube: 'OcuPilotProbeVisits',
    columns: ['Visits', 'Cost'],
    rows: [
      { label: 'North', cells: ['3', '9'] },
      { label: 'South', cells: ['5', '15'] },
    ],
    rowsAvailable: 40,
    columnsAvailable: 2,
    truncated: true,
    seconds: 1,
  });
});

test('mdxAnswerOf reads a cells answer that omits what it need not carry: the available counts default to the shown ones, a row with no label reads empty', () => {
  const answer = mdxAnswerOf({ outcome: 'cells', columns: ['A'], rows: [{ cells: [1, 'x'] }, 'not a row'] });
  assert.deepEqual(answer, {
    outcome: 'cells',
    cube: '',
    columns: ['A'],
    rows: [
      { label: '', cells: ['1', 'x'] },
      { label: '', cells: [] },
    ],
    rowsAvailable: 2,
    columnsAvailable: 1,
    truncated: false,
    seconds: 0,
  });
  assert.equal(mdxAnswerOf({ outcome: 'cells', columns: ['A'] }), null, 'cells without a row list is no answer');
});

test('mdxAnswerOf reads a rows answer as a listing, through the SQL reader, and an error and a stopped run', () => {
  // Mutation (Rule 19): answer a `rows` outcome whose rows are no list as an empty listing -> the null leg goes red.
  assert.deepEqual(mdxAnswerOf({ outcome: 'rows', columns: ['Id', 'Name'], rows: [['1', 'a'], ['2', 'b']], truncated: true }), {
    outcome: 'rows',
    result: { columns: ['Id', 'Name'], rows: [['1', 'a'], ['2', 'b']], truncated: true },
  });
  assert.equal(mdxAnswerOf({ outcome: 'rows', columns: ['Id'] }), null, 'a listing without rows is no answer');
  assert.deepEqual(mdxAnswerOf({ outcome: 'error', message: 'Unknown term at start of query: SELEKT' }), { outcome: 'error', message: 'Unknown term at start of query: SELEKT' });
  assert.deepEqual(mdxAnswerOf({ outcome: 'error' }), { outcome: 'error', message: '' });
  assert.deepEqual(mdxAnswerOf({ outcome: 'stopped', seconds: 120 }), { outcome: 'stopped', seconds: 120 });
  assert.deepEqual(mdxAnswerOf({ outcome: 'stopped' }), { outcome: 'stopped', seconds: 0 });
});

test('mdxAnswerOf answers null for a confirm, an unknown outcome and anything that is no object', () => {
  assert.equal(mdxAnswerOf({ outcome: 'confirm', constructs: ['%SEARCH'] }), null, 'a confirm is no answer of a run');
  assert.equal(mdxAnswerOf({ outcome: 'unheard-of' }), null);
  assert.equal(mdxAnswerOf({}), null);
  assert.equal(mdxAnswerOf(null), null);
  assert.equal(mdxAnswerOf('text'), null);
  assert.equal(mdxAnswerOf(undefined), null);
});

test('mdxConfirmOf answers the constructs of a confirm, an empty list for a statement the instance could not read, and null for any other body', () => {
  // Mutation (Rule 19): answer `null` for an empty list -> the second leg goes red.
  assert.deepEqual(mdxConfirmOf({ outcome: 'confirm', constructs: ['%SEARCH', 'RETURN'], consequence: 'x' }), ['%SEARCH', 'RETURN']);
  assert.deepEqual(mdxConfirmOf({ outcome: 'confirm', constructs: [], consequence: 'x' }), [], 'an empty list is an answer, never null');
  assert.deepEqual(mdxConfirmOf({ outcome: 'confirm' }), [], 'a confirm that names nothing is still a confirm');
  assert.deepEqual(mdxConfirmOf({ outcome: 'confirm', constructs: [1, '%PARM'] }), ['1', '%PARM']);
  assert.equal(mdxConfirmOf({ outcome: 'cells', columns: [], rows: [] }), null);
  assert.equal(mdxConfirmOf({ id: 'x', status: 'running' }), null);
  assert.equal(mdxConfirmOf(null), null);
  assert.equal(mdxConfirmOf('confirm'), null);
});

test('mdxStatusLineFor reads the invitation before any answer, the shown and available counts of a grid, and a cut grid says so', () => {
  assert.equal(mdxStatusLineFor(null), STRINGS.analyticsMdxEmpty);
  const whole = mdxAnswerOf({ ...CELLS, rowsAvailable: 2, truncated: false });
  assert.equal(mdxStatusLineFor(whole), 'Rows: 2 of 2. Columns: 2 of 2.');
  assert.equal(mdxStatusLineFor(mdxAnswerOf(CELLS)), `Rows: 2 of 40. Columns: 2 of 2. ${STRINGS.analyticsMdxCut}`);
});

test("mdxStatusLineFor reads a listing's row count, the vendor's error as one line, and a stopped run in the singular at 1 second", () => {
  assert.equal(mdxStatusLineFor(mdxAnswerOf({ outcome: 'rows', columns: ['A'], rows: [['1']], truncated: false })), '1 row');
  assert.equal(mdxStatusLineFor(mdxAnswerOf({ outcome: 'rows', columns: ['A'], rows: [['1'], ['2']], truncated: true })), '2 rows are shown; the answer holds more.');
  assert.equal(mdxStatusLineFor(mdxAnswerOf({ outcome: 'error', message: 'm' })), STRINGS.analyticsMdxErrorLine);
  assert.equal(mdxStatusLineFor(mdxAnswerOf({ outcome: 'stopped', seconds: 2 })), 'Stopped after 2 seconds.');
  assert.equal(mdxStatusLineFor(mdxAnswerOf({ outcome: 'stopped', seconds: 1 })), STRINGS.explorerSqlStoppedOne);
});

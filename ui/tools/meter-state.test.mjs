import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins `core/meter-state.ts` (Story 6.9): the vendor-word rule and the percentage rule the meter
// component colors by.
//
// Mutations (Rule 19):
// - read an unrecognized word as 'normal' instead of 'warning' -> the "unknown word" case below
//   goes red.
// - change the percentage lower bound from `>= 85` to `> 85` -> the "85 is Warning" boundary case
//   goes red.
// - change the upper bound from `>= 95` to `> 95` -> the "95 is Troubled" boundary case goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { meterStateFromPercent, meterStateFromWord } = await import(
  join(uiRoot, 'src', 'app', 'core', 'meter-state.ts')
);

test('meterStateFromWord: Normal, Warning and Troubled map to their own severity, verbatim', () => {
  assert.deepEqual(meterStateFromWord('Normal'), { state: 'normal', word: 'Normal' });
  assert.deepEqual(meterStateFromWord('Warning'), { state: 'warning', word: 'Warning' });
  assert.deepEqual(meterStateFromWord('Troubled'), { state: 'error', word: 'Troubled' });
});

test('meterStateFromWord: an unrecognized word reads as warning, but is shown verbatim', () => {
  assert.deepEqual(meterStateFromWord('Degraded'), { state: 'warning', word: 'Degraded' });
  assert.deepEqual(meterStateFromWord(''), { state: 'warning', word: '' });
});

test('meterStateFromPercent: below 85 is Normal, at or above 85 is Warning, at or above 95 is Troubled', () => {
  assert.deepEqual(meterStateFromPercent(0), { state: 'normal', word: 'Normal' });
  assert.deepEqual(meterStateFromPercent(84.9), { state: 'normal', word: 'Normal' });
  assert.deepEqual(meterStateFromPercent(85), { state: 'warning', word: 'Warning' });
  assert.deepEqual(meterStateFromPercent(94.9), { state: 'warning', word: 'Warning' });
  assert.deepEqual(meterStateFromPercent(95), { state: 'error', word: 'Troubled' });
  assert.deepEqual(meterStateFromPercent(100), { state: 'error', word: 'Troubled' });
});

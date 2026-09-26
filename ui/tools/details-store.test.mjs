import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins Task details' own state (`areas/tasks/details.store.ts`, Story 6.7): the schedule-in-words
// vocabulary AD-3 has the client compose from GET's own display values. The field-level highlight
// a silent tick raises moved to `core/detail-highlights.ts` as `DetailHighlights` (Story 6.8),
// pinned by `ui/tools/detail-highlights.test.mjs` instead.
//
// Mutations (Rule 19):
// - drop the `every > 1` branch from `oftenText`'s `Daily` case -> the "Every {n} days" case goes
//   red, always reading "Every day".
// - read `TimePeriodDay` as one number instead of splitting it into digits -> the Weekly case goes
//   red, joining nothing.
// - swap `week` and `weekday` in `monthlySpecialParts` -> the Monthly Special case goes red,
//   naming the wrong ordinal and weekday.
// - drop the `suspended === true` check from `nextRunText` -> the suspended case goes red, reading
//   the stale `NextScheduled` text instead of the sentence.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const store = await import(join(uiRoot, 'src', 'app', 'areas', 'tasks', 'details.store.ts'));

/** A sound Daily/Once row, as the demo fixture answers it, with `overrides` applied. */
function row(overrides = {}) {
  return {
    TimePeriod: 'Daily',
    TimePeriodEvery: 1,
    TimePeriodDay: '',
    DailyFrequency: 'Once',
    DailyFrequencyTime: '',
    DailyIncrement: '',
    DailyStartTime: '03:00:00',
    DailyEndTime: '00:00:00',
    Suspended: false,
    NextScheduled: '2026-09-17 03:00:00',
    ...overrides,
  };
}

test('Daily: "Every day" for TimePeriodEvery 1, "Every {n} days" otherwise', () => {
  assert.equal(store.scheduleWords(row({ TimePeriodEvery: 1 })).often, 'Every day');
  assert.equal(store.scheduleWords(row({ TimePeriodEvery: 3 })).often, 'Every 3 days');
});

test('Weekly: the TimePeriodDay digits are joined weekday names, singular and plural', () => {
  const weekly = row({ TimePeriod: 'Weekly', TimePeriodEvery: 1, TimePeriodDay: '135' });
  assert.equal(store.scheduleWords(weekly).often, 'Every week on Sunday, Tuesday, Thursday');
  const everyTwo = row({ TimePeriod: 'Weekly', TimePeriodEvery: 2, TimePeriodDay: '26' });
  assert.equal(store.scheduleWords(everyTwo).often, 'Every 2 weeks on Monday, Friday');
});

test('Monthly: the day of month is read as one number, singular and plural', () => {
  const monthly = row({ TimePeriod: 'Monthly', TimePeriodEvery: 1, TimePeriodDay: '15' });
  assert.equal(store.scheduleWords(monthly).often, 'Every month on day 15');
  const everyTwo = row({ TimePeriod: 'Monthly', TimePeriodEvery: 2, TimePeriodDay: '15' });
  assert.equal(store.scheduleWords(everyTwo).often, 'Every 2 months on day 15');
});

test('Monthly Special: <week>^<weekday> resolves to its ordinal and weekday names, singular and plural', () => {
  const special = row({ TimePeriod: 'Monthly Special', TimePeriodEvery: 1, TimePeriodDay: '2^3' });
  assert.equal(store.scheduleWords(special).often, 'Every month on the second Tuesday');
  const everyTwo = row({ TimePeriod: 'Monthly Special', TimePeriodEvery: 2, TimePeriodDay: '5^7' });
  assert.equal(store.scheduleWords(everyTwo).often, 'Every 2 months on the fifth Saturday');
});

test('Run After and On Demand ignore TimePeriodEvery and TimePeriodDay entirely', () => {
  assert.equal(store.scheduleWords(row({ TimePeriod: 'Run After', TimePeriodEvery: 9 })).often, 'After another task completes');
  assert.equal(store.scheduleWords(row({ TimePeriod: 'On Demand', TimePeriodEvery: 9 })).often, 'On demand only');
});

test('an unrecognized TimePeriod renders the vendor text as it stands', () => {
  assert.equal(store.scheduleWords(row({ TimePeriod: 'Something New' })).often, 'Something New');
});

test('Once reads "Once at {DailyStartTime}"', () => {
  assert.equal(store.scheduleWords(row({ DailyFrequency: 'Once', DailyStartTime: '03:00:00' })).time, 'Once at 03:00:00');
});

test('Several/Minutes: singular at increment 1, plural otherwise, between DailyStartTime and DailyEndTime', () => {
  const once = row({ DailyFrequency: 'Several', DailyFrequencyTime: 'Minutes', DailyIncrement: 1, DailyStartTime: '01:00:00', DailyEndTime: '20:00:00' });
  assert.equal(store.scheduleWords(once).time, 'Every minute between 01:00:00 and 20:00:00');
  const fifteen = row({ DailyFrequency: 'Several', DailyFrequencyTime: 'Minutes', DailyIncrement: 15, DailyStartTime: '01:00:00', DailyEndTime: '20:00:00' });
  assert.equal(store.scheduleWords(fifteen).time, 'Every 15 minutes between 01:00:00 and 20:00:00');
});

test('Several/Hourly: singular at increment 1, plural otherwise', () => {
  const once = row({ DailyFrequency: 'Several', DailyFrequencyTime: 'Hourly', DailyIncrement: 1, DailyStartTime: '00:00:00', DailyEndTime: '23:00:00' });
  assert.equal(store.scheduleWords(once).time, 'Every hour between 00:00:00 and 23:00:00');
  const two = row({ DailyFrequency: 'Several', DailyFrequencyTime: 'Hourly', DailyIncrement: 2, DailyStartTime: '00:00:00', DailyEndTime: '23:00:00' });
  assert.equal(store.scheduleWords(two).time, 'Every 2 hours between 00:00:00 and 23:00:00');
});

test('an unrecognized DailyFrequency, or an unrecognized DailyFrequencyTime under Several, renders the vendor text as it stands', () => {
  assert.equal(store.scheduleWords(row({ DailyFrequency: 'Sometimes' })).time, 'Sometimes');
  assert.equal(
    store.scheduleWords(row({ DailyFrequency: 'Several', DailyFrequencyTime: 'Fortnightly', DailyIncrement: 1 })).time,
    'Fortnightly'
  );
});

test('nextRunText reads the suspended sentence when Suspended is true, and the raw NextScheduled otherwise', () => {
  assert.equal(store.nextRunText(row({ Suspended: true, NextScheduled: '2026-09-15 09:57:00' })), 'Not scheduled while suspended');
  assert.equal(store.nextRunText(row({ Suspended: false, NextScheduled: '2026-09-18 03:00:00' })), '2026-09-18 03:00:00');
});

// A Run After or On Demand task carries no next-run time while it is not suspended. This field is
// read directly rather than through cellView (details.page.ts's fieldViews), which is the only
// column on the page that would otherwise show a bare empty string instead of the shared
// empty-value marker every other field on this page falls back to.
test('nextRunText falls back to the shared empty-value marker for a not-suspended task with no NextScheduled', () => {
  assert.equal(store.nextRunText(row({ Suspended: false, NextScheduled: '' })), '(none)');
});


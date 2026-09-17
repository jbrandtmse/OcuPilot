import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the Upcoming tasks horizon (`areas/tasks/upcoming.store.ts`): exactly one of `hoursOffset`
// and `toDatetime`, the end of the chosen day, and no criteria for a missing or past date.
//
// Mutations (Rule 19):
// - `criteria` always sends `hoursOffset` -> "date mode sends toDatetime alone" goes red.
// - the past-date guard dropped -> "a date before today answers no criteria" goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const store = await import(join(uiRoot, 'src', 'app', 'areas', 'tasks', 'upcoming.store.ts'));
const { SCREENS } = await import(join(uiRoot, 'src', 'app', 'core', 'screens.generated.ts'));

const TODAY = '2026-09-16';

test('the horizon opens at 24 hours and sends hoursOffset alone', () => {
  const horizon = new store.UpcomingHorizon();
  assert.equal(horizon.mode(), 'hours');
  assert.deepEqual(horizon.criteria(TODAY), { hoursOffset: '24' });
});

test('an hour choice is one of the six the descriptor declares, and anything else changes nothing', () => {
  const upcoming = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.TaskUpcomingList');
  const hours = upcoming.read.criteria.fields.find((field) => field.param === store.HOURS_CRITERION);
  assert.deepEqual([...store.UPCOMING_HOURS], hours.options, 'the store lists the declared options in order');
  const horizon = new store.UpcomingHorizon();
  let notified = 0;
  horizon.subscribe(() => (notified += 1));
  horizon.chooseHours('1');
  assert.deepEqual(horizon.criteria(TODAY), { hoursOffset: '1' });
  horizon.chooseHours('5');
  assert.deepEqual(horizon.criteria(TODAY), { hoursOffset: '1' }, 'an undeclared count is ignored');
  assert.equal(notified, 1);
});

test('date mode sends toDatetime alone, at the end of the chosen day', () => {
  const horizon = new store.UpcomingHorizon();
  horizon.chooseDateMode();
  assert.equal(horizon.criteria(TODAY), null, 'no date yet reads nothing');
  horizon.chooseDate('2026-09-17');
  assert.deepEqual(horizon.criteria(TODAY), { toDatetime: '2026-09-17 23:59:59' });
  horizon.chooseDate(TODAY);
  assert.deepEqual(horizon.criteria(TODAY), { toDatetime: '2026-09-16 23:59:59' }, 'today itself is a horizon');
});

test('a date before today, or one not written YYYY-MM-DD, answers no criteria', () => {
  const horizon = new store.UpcomingHorizon();
  horizon.chooseDate('2026-09-15');
  assert.equal(horizon.criteria(TODAY), null);
  horizon.chooseDate('2026-9-20');
  assert.equal(horizon.criteria(TODAY), null);
  horizon.chooseHours('24');
  assert.deepEqual(horizon.criteria(TODAY), { hoursOffset: '24' }, 'returning to hours sends hours again');
});

test('localDateText writes the local calendar date', () => {
  assert.equal(store.localDateText(new Date(2026, 0, 5, 23, 59)), '2026-01-05');
});

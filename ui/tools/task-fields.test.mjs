/**
 * `areas/tasks/task-fields.ts` (Story 9.7): the task create's field model -- the order, the
 * field-to-step map, which fields each period and frequency read, and the complete body a create
 * sends. Story 9.8's Edit task reads the same model.
 */

import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  BASICS_STEP,
  EDIT_FIXED_FIELDS,
  FIELD_ORDER,
  OPTIONS_STEP,
  SCHEDULE_STEP,
  STEPS,
  TABS,
  TYPE_STEP,
  applies,
  changedBody,
  createBody,
  fieldOrder,
  fieldSteps,
  fieldTabs,
  fieldsOfStep,
  stepOfField,
  valuesFromTask,
} from '../src/app/areas/tasks/task-fields.ts';
import { tabErrorCounts, tabToOpen } from '../src/app/core/form-tabs.ts';

function values(text, flags = {}, settings = {}) {
  return { text, flags, settings };
}

const WEEKLY = values(
  {
    Name: 'OcuP97W',
    Description: '',
    NameSpace: '%SYS',
    TaskClass: '%SYS.Task.PurgeTaskHistory',
    TimePeriod: 'Weekly',
    TimePeriodEvery: '1',
    TimePeriodDay: '24',
    RunAfterGUID: 'ignored',
    DailyFrequency: 'Several',
    DailyFrequencyTime: 'Minutes',
    DailyIncrement: '30',
    DailyStartTime: '01:00',
    DailyEndTime: '05:00',
    StartDate: '2026-09-25',
    EndDate: '',
    ExpiresDays: '',
    ExpiresHours: '',
    ExpiresMinutes: '',
    RunAsUser: '',
    Priority: 'Low',
    MirrorStatus: 'Primary',
    OutputFilename: 'run.txt',
    EmailOnCompletion: 'ops@example.com, dev@example.com',
    EmailOnError: '',
    EmailOnExpiration: '',
  },
  { Expires: true, IsBatch: false, OpenOutputFile: true, OutputFileIsBinary: false, EmailOutput: true, SuspendOnError: true, SuspendTerminated: false, RescheduleOnStart: true },
  { KeepDays: '30' }
);

test('the model covers the thirty-four fields a create sets, and never the output directory', () => {
  assert.equal(FIELD_ORDER.length, 34);
  assert.equal(new Set(FIELD_ORDER).size, 34, 'each once');
  assert.ok(!FIELD_ORDER.includes('OutputDirectory'), 'no caller names a directory (AD-21)');
  assert.deepEqual(STEPS, [BASICS_STEP, TYPE_STEP, SCHEDULE_STEP, OPTIONS_STEP]);
  for (const field of FIELD_ORDER) assert.notEqual(stepOfField(field), null, `${field} is drawn on a step`);
});

// Mutation (Rule 19): move `TimePeriodDay` to the options step -> the schedule step's list goes red.
test('each step draws its own fields in the wizard order, and a setting is the type step\'s', () => {
  assert.deepEqual(fieldsOfStep(BASICS_STEP), ['Name', 'Description', 'NameSpace']);
  assert.deepEqual(fieldsOfStep(TYPE_STEP), ['TaskClass', 'Settings']);
  assert.equal(fieldsOfStep(SCHEDULE_STEP)[0], 'TimePeriod');
  assert.ok(fieldsOfStep(SCHEDULE_STEP).includes('TimePeriodDay'));
  assert.deepEqual(fieldsOfStep(OPTIONS_STEP).slice(0, 4), ['RunAsUser', 'Priority', 'IsBatch', 'MirrorStatus']);
  assert.equal(stepOfField('Settings.KeepDays'), TYPE_STEP);
  assert.equal(stepOfField('Nowhere'), null);
});

// Mutation (Rule 19): drop the `Settings.<name>` entries from `fieldSteps` -> the setting's count
// and the step to open go red.
test('a refused setting counts on the type step and opens it, the first refused field in order winning', () => {
  const steps = fieldSteps(['KeepDays']);
  const order = fieldOrder(['KeepDays']);
  const refused = [
    { field: 'StartDate', code: 'X', reason: 'x' },
    { field: 'Settings.KeepDays', code: 'Y', reason: 'y' },
  ];
  assert.deepEqual(tabErrorCounts(steps, refused), { [SCHEDULE_STEP]: 1, [TYPE_STEP]: 1 });
  assert.equal(tabToOpen(steps, order, refused), TYPE_STEP, 'the setting precedes the schedule');
  assert.equal(tabToOpen(steps, order, [{ field: 'Name', code: 'Z', reason: 'z' }]), BASICS_STEP);
});

// Mutation (Rule 19): let `TimePeriodDay` apply to Daily -> the Daily leg goes red.
test('each period reads its own fields, and Several alone reads the three Several fields', () => {
  const period = (name, frequency = 'Once') => values({ TimePeriod: name, DailyFrequency: frequency });
  assert.equal(applies('TimePeriodDay', period('Daily')), false, 'Daily reads no day');
  assert.equal(applies('TimePeriodDay', period('Weekly')), true);
  assert.equal(applies('TimePeriodEvery', period('Run After')), false);
  assert.equal(applies('RunAfterGUID', period('Run After')), true);
  assert.equal(applies('RunAfterGUID', period('Daily')), false);
  for (const field of ['DailyFrequency', 'StartDate', 'Expires', 'ExpiresMinutes']) {
    assert.equal(applies(field, period('On Demand')), false, `On Demand reads no ${field}`);
    assert.equal(applies(field, period('Monthly Special')), true, `Monthly Special reads ${field}`);
  }
  assert.equal(applies('DailyIncrement', period('Daily', 'Once')), false, 'Once reads no increment');
  assert.equal(applies('DailyIncrement', period('Daily', 'Several')), true);
  assert.equal(applies('DailyStartTime', period('Daily', 'Once')), true, 'Once reads its start time');
});

// Mutation (Rule 19): drop `OutputFileIsBinary` from `createBody` -> the flags leg goes red (AC7).
test('a create sends every field the period reads, typed as the server takes it', () => {
  const body = createBody(WEEKLY);
  assert.equal(body.RunAfterGUID, undefined, 'a Weekly body carries no task to run after');
  assert.deepEqual(body.Settings, { KeepDays: '30' }, 'the type\'s settings as an object');
  assert.deepEqual(body.EmailOnCompletion, ['ops@example.com', 'dev@example.com'], 'addresses as an array');
  assert.deepEqual(body.EmailOnError, []);
  assert.equal(body.OutputFileIsBinary, false, 'every flag travels, off ones included');
  assert.equal(body.OpenOutputFile, true);
  assert.equal(body.EmailOutput, true, 'the output file is emailed');
  assert.equal(body.SuspendOnError, true);
  assert.equal(body.RescheduleOnStart, true);
  assert.equal(body.Priority, 'Low');
  assert.equal(body.OutputFilename, 'run.txt');
  assert.equal(body.OutputDirectory, undefined, 'and never a directory');
  assert.equal(Object.keys(body).length, 33, 'thirty-four fields less the task to run after');
  const demand = createBody(values({ ...WEEKLY.text, TimePeriod: 'On Demand' }, WEEKLY.flags, {}));
  assert.equal(demand.Expires, undefined, 'an On Demand body sends no expiry');
  assert.equal(demand.TimePeriodEvery, undefined);
});

// Story 9.8: Edit task reads the same model.

/** A task's fresh read, as `GET /tasks/form?id=` answers it (the vendor's own spellings). */
const TASK_READ = {
  Id: 1597,
  Name: 'OcuP98Edit',
  Description: 'probe',
  NameSpace: '%SYS',
  TaskClass: '%SYS.Task.PurgeTaskHistory',
  TimePeriod: 'Weekly',
  TimePeriodEvery: '1',
  TimePeriodDay: '24',
  DailyFrequency: 'Several',
  DailyFrequencyTime: 'Minutes',
  DailyIncrement: 30,
  DailyStartTime: '01:00:00',
  DailyEndTime: '05:00:00',
  StartDate: '2026-09-25',
  Priority: 'Low',
  OutputFilename: 'ocup98edit.txt',
  OutputFileIsBinary: true,
  IsBatch: false,
  EmailOnCompletion: ['ops@example.com', 'dev@example.com'],
  EmailOnError: [],
  Settings: { KeepDays: '30' },
  Type: 'User',
};

test('Story 9.8: the edit\'s tabs are the wizard\'s steps, and its tab map is the step map', () => {
  assert.deepEqual(TABS, STEPS, 'the four tabs are the four steps, in order');
  assert.deepEqual(fieldTabs(['KeepDays']), fieldSteps(['KeepDays']), 'every field, a setting included, is on the tab of its step');
  assert.deepEqual(EDIT_FIXED_FIELDS, ['TaskClass', 'NameSpace'], 'the type and the namespace are the two fields an edit never changes');
});

test('Story 9.8: a task\'s read is held as the form holds it, a time as HH:MM', () => {
  // Mutation (Rule 19): drop `OutputFileIsBinary` from `valuesFromTask`'s flags -> the binary leg goes red.
  const held = valuesFromTask(TASK_READ);
  assert.equal(held.text.DailyStartTime, '01:00', 'HH:MM:SS is read as HH:MM');
  assert.equal(held.text.DailyEndTime, '05:00', 'for both times');
  assert.equal(held.text.DailyIncrement, '30', 'a number is held as text');
  assert.equal(held.text.EmailOnCompletion, 'ops@example.com, dev@example.com', 'an address list as comma-separated text');
  assert.equal(held.flags.OutputFileIsBinary, true, 'a flag as a flag');
  assert.equal(held.flags.IsBatch, false, 'an unset flag as false');
  assert.deepEqual(held.settings, { KeepDays: '30' }, 'the task\'s own settings as text');
  assert.deepEqual(valuesFromTask(null).settings, {}, 'and a record with none holds none');
});

test('Story 9.8: an edit sends the fields it changes, Settings whole, and never the type or namespace', () => {
  const opened = valuesFromTask(TASK_READ);
  assert.deepEqual(changedBody(opened, opened), {}, 'nothing changed sends nothing');
  const edited = {
    text: { ...opened.text, Description: 'edited', DailyIncrement: '15', TaskClass: '%SYS.Task.IntegrityCheck', NameSpace: 'USER', EmailOnCompletion: 'ops@example.com,  dev@example.com' },
    flags: { ...opened.flags, IsBatch: true },
    settings: opened.settings,
  };
  assert.deepEqual(
    changedBody(opened, edited),
    { Description: 'edited', DailyIncrement: '15', IsBatch: true },
    'the two texts and the flag, typed as a create types them; an address list spelled differently is unchanged; the fixed fields are never sent'
  );
  const settings = { ...opened, settings: { KeepDays: '45' } };
  assert.deepEqual(changedBody(opened, settings), { Settings: { KeepDays: '45' } }, 'a changed setting sends the settings whole');
  const addresses = { ...opened, text: { ...opened.text, EmailOnError: 'late@example.com' } };
  assert.deepEqual(changedBody(opened, addresses), { EmailOnError: ['late@example.com'] }, 'a changed address list is sent as the array');
});

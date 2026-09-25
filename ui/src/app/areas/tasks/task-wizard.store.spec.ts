import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { BASICS_STEP, OPTIONS_STEP, SCHEDULE_STEP, TYPE_STEP } from './task-fields';
import { TASKS_PATH, TASK_CHECK_PATH, TASK_FORM_PATH, TaskWizard } from './task-wizard.store';

/**
 * The New Task wizard's store (Story 9.7, AC1, AD-14, AD-39, AD-55): the form read, a type loading
 * its own settings, the namespace reading its own types, Next checking the values so far on the
 * server, Back keeping them, and the create publishing one `task` `created` event with the
 * instance's id. The bus and `FormDirty` are real; only the server's answers are stubbed.
 */

const DEFAULTS = {
  Name: '',
  Description: '',
  NameSpace: '%SYS',
  TaskClass: '',
  TimePeriod: 'Daily',
  TimePeriodEvery: '1',
  TimePeriodDay: '',
  RunAfterGUID: '',
  DailyFrequency: 'Once',
  DailyFrequencyTime: 'Minutes',
  DailyIncrement: '',
  DailyStartTime: '00:00:00',
  DailyEndTime: '',
  StartDate: '2026-09-25',
  EndDate: '',
  ExpiresDays: '',
  ExpiresHours: '',
  ExpiresMinutes: '',
  RunAsUser: '',
  Priority: 'Normal',
  MirrorStatus: 'Primary',
  OutputFilename: '',
  Expires: false,
  IsBatch: false,
  OpenOutputFile: false,
  OutputFileIsBinary: false,
  EmailOutput: false,
  SuspendOnError: false,
  SuspendTerminated: false,
  RescheduleOnStart: false,
  EmailOnCompletion: [],
  EmailOnError: [],
  EmailOnExpiration: [],
};

const TYPES = [
  {
    class: '%SYS.Task.IntegrityCheck',
    name: 'IntegrityCheck',
    settings: [
      { name: 'Directory', label: 'Directory', kind: 'string', required: false, default: '' },
      { name: 'KeepDays', label: 'KeepDays', kind: 'number', required: false, default: '7' },
    ],
    classicOnly: [],
  },
  {
    class: '%SYS.Task.PurgeTaskHistory',
    name: 'PurgeTaskHistory',
    settings: [{ name: 'KeepDays', label: 'KeepDays', kind: 'number', required: true, default: '7' }],
    classicOnly: [],
  },
];

const OTHER_TYPES = [{ class: 'User.OtherTask', name: 'OtherTask', settings: [], classicOnly: [] }];

const FORM = {
  requiredFields: ['Name', 'NameSpace', 'TaskClass', 'TimePeriod'],
  maxLengths: { Name: 50, Description: 100, OutputFilename: 104 },
  rules: [
    { field: 'Name', code: 'TASK.NAME.REQUIRED', reason: 'Give the task a name.' },
    { field: 'Description', code: 'TASK.DESCRIPTION.LENGTH', reason: 'A description is at most 100 characters.' },
  ],
  defaults: DEFAULTS,
  namespace: '%SYS',
  types: TYPES,
  runAfter: [{ guid: 'G-1', id: 7, name: 'Purge Tasks' }],
};

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: string;
}

async function settle(): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
}

function mount(options: { check?: (body: Record<string, unknown>) => unknown[]; create?: JsonResult<unknown> } = {}) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      calls.push({ path, method, body: init.body ?? '' });
      if (path === TASK_FORM_PATH) return { kind: 'ok', status: 200, body: FORM } as unknown as JsonResult<T>;
      if (path.startsWith(`${TASK_FORM_PATH}?`)) {
        const other = path.includes('HSCUSTOM');
        return { kind: 'ok', status: 200, body: { ...FORM, namespace: other ? 'HSCUSTOM' : '%SYS', types: other ? OTHER_TYPES : TYPES } } as unknown as JsonResult<T>;
      }
      if (path === TASK_CHECK_PATH) {
        const violations = options.check?.(JSON.parse(init.body ?? '{}') as Record<string, unknown>) ?? [];
        return { kind: 'ok', status: 200, body: { violations } } as unknown as JsonResult<T>;
      }
      return (options.create ?? { kind: 'ok', status: 201, body: { id: 1391, name: 'OcuP97W' } }) as JsonResult<T>;
    },
  };
  const bus = new ChangeBus();
  const events: ChangeEvent[] = [];
  bus.subscribe((event) => events.push(event));
  const formDirty = new FormDirty();
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: bus },
      { provide: FormDirty, useValue: formDirty },
    ],
  });
  return { store: TestBed.inject(TaskWizard), calls, events, formDirty };
}

function checks(calls: readonly Call[]): Call[] {
  return calls.filter((call) => call.path === TASK_CHECK_PATH);
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('TaskWizard', () => {
  it('opens on Basics from the form read: its defaults, the namespace, the types and the tasks to run after', async () => {
    const { store, calls } = mount();
    await store.open();
    expect(calls[0]).toEqual({ path: TASK_FORM_PATH, method: 'GET', body: '' });
    expect(store.loaded()).toBe(true);
    expect(store.step()).toBe(BASICS_STEP);
    expect(store.text('NameSpace')).toBe('%SYS');
    expect(store.text('TimePeriod')).toBe('Daily');
    expect(store.text('StartDate')).toBe('2026-09-25');
    expect(store.text('DailyStartTime')).toBe('00:00');
    expect(store.types().map((type) => type.className)).toEqual(['%SYS.Task.IntegrityCheck', '%SYS.Task.PurgeTaskHistory']);
    expect(store.runAfter()).toEqual([{ guid: 'G-1', id: 7, name: 'Purge Tasks' }]);
    expect(store.required('Name')).toBe(true);
    expect(store.maxLength('Name')).toBe(50);
    expect(store.reachable(TYPE_STEP)).toBe(false);
  });

  it('Matrix "Type loads settings": a type loads its settings at their defaults, and the previous type\'s are gone', async () => {
    const { store } = mount();
    await store.open();
    store.setText('TaskClass', '%SYS.Task.IntegrityCheck');
    expect(store.values().settings).toEqual({ Directory: '', KeepDays: '7' });
    store.setSetting('Directory', '/tmp/');
    store.setText('TaskClass', '%SYS.Task.PurgeTaskHistory');
    expect(store.values().settings).toEqual({ KeepDays: '7' });
    store.setSetting('Directory', '/tmp/');
    expect(store.values().settings, 'a setting the type does not declare is not held').toEqual({ KeepDays: '7' });
  });

  it('a namespace reads its own task types, and a type it does not compile is cleared', async () => {
    const { store, calls } = mount();
    await store.open();
    store.setText('TaskClass', '%SYS.Task.PurgeTaskHistory');
    store.setText('NameSpace', 'HSCUSTOM');
    await settle();
    expect(calls.some((call) => call.path === `${TASK_FORM_PATH}?namespace=HSCUSTOM`)).toBe(true);
    expect(store.types().map((type) => type.className)).toEqual(['User.OtherTask']);
    expect(store.text('TaskClass')).toBe('');
    expect(store.values().settings).toEqual({});
  });

  it('AC1, Matrix "Next on empty Basics": Next sends the values so far to the check and stays on a step it refuses', async () => {
    const { store, calls } = mount({
      check: (body) => (body['Name'] === '' ? [{ field: 'Name', code: 'TASK.NAME.REQUIRED', reason: 'Give the task a name.' }] : []),
    });
    await store.open();
    // Mutation (Rule 19): replace `next()`'s check call with an empty answer -> this and the
    // later-step leg go red.
    expect(await store.next()).toBe(false);
    expect(checks(calls)).toHaveLength(1);
    expect(JSON.parse(checks(calls)[0].body)).toMatchObject({ Name: '', NameSpace: '%SYS', TimePeriod: 'Daily' });
    expect(store.step()).toBe(BASICS_STEP);
    expect(store.violations()).toEqual([{ field: 'Name', code: 'TASK.NAME.REQUIRED', reason: 'Give the task a name.' }]);
    store.setText('Name', 'OcuP97W');
    expect(store.violations(), 'typing into a refused field clears its refusal').toEqual([]);
    expect(await store.next()).toBe(true);
    expect(store.step()).toBe(TYPE_STEP);
    expect(store.reachable(TYPE_STEP)).toBe(true);
  });

  it('Next ignores a refusal on a later step, which is that step\'s own to raise', async () => {
    const { store } = mount({ check: () => [{ field: 'TaskClass', code: 'TASK.TASKCLASS.REQUIRED', reason: 'Choose a task type.' }] });
    await store.open();
    store.setText('Name', 'OcuP97W');
    expect(await store.next()).toBe(true);
    expect(store.step()).toBe(TYPE_STEP);
    expect(await store.next()).toBe(false);
    expect(store.step()).toBe(TYPE_STEP);
    expect(store.violationFor('TaskClass')).toBe('Choose a task type.');
  });

  it('Matrix "Back keeps values": Back returns a step and every value is still there', async () => {
    const { store } = mount();
    await store.open();
    store.setText('Name', 'OcuP97W');
    store.setText('Description', 'kept');
    await store.next();
    store.setText('TaskClass', '%SYS.Task.PurgeTaskHistory');
    store.setSetting('KeepDays', '30');
    await store.next();
    expect(store.step()).toBe(SCHEDULE_STEP);
    store.back();
    expect(store.step()).toBe(TYPE_STEP);
    store.back();
    expect(store.step()).toBe(BASICS_STEP);
    expect(store.text('Name')).toBe('OcuP97W');
    expect(store.text('Description')).toBe('kept');
    expect(store.text('TaskClass')).toBe('%SYS.Task.PurgeTaskHistory');
    expect(store.setting('KeepDays')).toBe('30');
    store.goTo(SCHEDULE_STEP);
    expect(store.step(), 'a step already reached opens again').toBe(SCHEDULE_STEP);
    store.goTo(OPTIONS_STEP);
    expect(store.step(), 'and one not yet reached does not').toBe(SCHEDULE_STEP);
  });

  it('AD-14, AD-55: Create task sends the whole body, publishes one task created event with the instance\'s id, and leaves the form clean', async () => {
    const { store, calls, events, formDirty } = mount();
    await store.open();
    store.setText('Name', 'OcuP97W');
    store.setText('TaskClass', '%SYS.Task.PurgeTaskHistory');
    store.setSetting('KeepDays', '30');
    store.setText('TimePeriod', 'Weekly');
    store.setText('TimePeriodDay', '24');
    store.setFlag('OutputFileIsBinary', true);
    store.setText('EmailOnError', 'ops@example.com, dev@example.com');
    expect(formDirty.dirty()).toBe(true);
    expect(await store.create()).toBe(true);
    const create = calls.find((call) => call.path === TASKS_PATH);
    expect(create?.method).toBe('POST');
    const body = JSON.parse(create?.body ?? '{}') as Record<string, unknown>;
    expect(body).toMatchObject({ Name: 'OcuP97W', TaskClass: '%SYS.Task.PurgeTaskHistory', Settings: { KeepDays: '30' }, TimePeriod: 'Weekly', TimePeriodDay: '24', OutputFileIsBinary: true, EmailOnError: ['ops@example.com', 'dev@example.com'] });
    expect(body['OutputDirectory']).toBeUndefined();
    expect(store.createdId()).toBe('1391');
    expect(events).toHaveLength(1);
    expect(events[0]).toMatchObject({ kind: 'changed', type: 'task', scope: 'instance', id: '1391', action: 'created' });
    expect(formDirty.dirty()).toBe(false);
  });

  // Mutation (Rule 19): carry the held day into the new period in `dayFor` -> this goes red on 24.
  it('a period change starts the day over, so Weekly\'s days never become a day of the month', async () => {
    const { store } = mount();
    await store.open();
    store.setText('TimePeriod', 'Weekly');
    store.setText('TimePeriodDay', '24');
    store.setText('TimePeriod', 'Monthly');
    expect(store.text('TimePeriodDay')).toBe('1');
    store.setText('TimePeriodDay', '5');
    store.setText('TimePeriod', 'Weekly');
    expect(store.text('TimePeriodDay'), 'nor the 5th a Thursday').toBe('');
  });

  it('a refused create keeps every value, publishes nothing, and opens every step to the person', async () => {
    const refused: JsonResult<unknown> = {
      kind: 'error',
      status: 422,
      code: 'TASK.VALIDATION',
      reason: 'The task was refused.',
      detail: { violations: [{ field: 'Name', code: 'TASK.NAME.TAKEN', reason: 'This instance already has a task with that name. Choose a different one.' }] },
    } as unknown as JsonResult<unknown>;
    const { store, events } = mount({ create: refused });
    await store.open();
    store.setText('Name', 'Purge Tasks');
    expect(await store.create()).toBe(false);
    expect(store.text('Name')).toBe('Purge Tasks');
    expect(store.violationFor('Name')).toContain('already has a task');
    expect(events).toEqual([]);
    expect(store.reachable(OPTIONS_STEP)).toBe(true);
  });

  it('AD-10: the task runs as another account when RunAsUser names one other than the caller, compared without regard to case', async () => {
    const { store } = mount();
    await store.open();
    expect(store.runsAsOther('_SYSTEM')).toBe(false);
    store.setText('RunAsUser', '_system');
    expect(store.runsAsOther('_SYSTEM')).toBe(false);
    store.setText('RunAsUser', 'Admin');
    expect(store.runsAsOther('_SYSTEM')).toBe(true);
  });

  it('on blur, an empty required field is refused in the server\'s own sentence without a round trip', async () => {
    const { store, calls } = mount();
    await store.open();
    const before = calls.length;
    store.onBlur('Name');
    expect(store.violationFor('Name')).toBe('Give the task a name.');
    expect(calls.length).toBe(before);
  });

  it('reset forgets every value and the steps reached', async () => {
    const { store } = mount();
    await store.open();
    store.setText('Name', 'OcuP97W');
    await store.next();
    store.reset();
    expect(store.loaded()).toBe(false);
    expect(store.text('Name')).toBe('');
    expect(store.step()).toBe(BASICS_STEP);
    expect(store.reachable(TYPE_STEP)).toBe(false);
  });
});

/** A task's fresh read, as `GET /tasks/form?id=` answers it (Story 9.8). */
const TASK = {
  ...DEFAULTS,
  Id: 1597,
  Name: 'OcuP98Edit',
  Description: 'probe',
  TaskClass: '%SYS.Task.PurgeTaskHistory',
  TimePeriod: 'Weekly',
  TimePeriodDay: '24',
  DailyFrequency: 'Several',
  DailyIncrement: '30',
  DailyStartTime: '01:00:00',
  DailyEndTime: '05:00:00',
  RunAsUser: '_SYSTEM',
  Priority: 'Low',
  OutputFileIsBinary: true,
  EmailOnCompletion: ['ops@example.com'],
  Settings: { KeepDays: '30' },
  Type: 'User',
};

function mountEdit(options: { form?: JsonResult<unknown>; save?: JsonResult<unknown>; classicOnly?: boolean } = {}) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  let reads = 0;
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      calls.push({ path, method, body: init.body ?? '' });
      if (path.startsWith(`${TASK_FORM_PATH}?id=`)) {
        reads += 1;
        if (options.form !== undefined) return options.form as JsonResult<T>;
        const task = options.classicOnly === true ? { ...TASK, Settings: undefined } : { ...TASK, Description: reads > 1 ? 'read again' : 'probe' };
        return { kind: 'ok', status: 200, body: { ...FORM, types: TYPES, task, settingsClassicOnly: options.classicOnly === true } } as unknown as JsonResult<T>;
      }
      return (options.save ?? { kind: 'ok', status: 200, body: { id: 1597, name: 'OcuP98Edit' } }) as JsonResult<T>;
    },
  };
  const bus = new ChangeBus();
  const events: ChangeEvent[] = [];
  bus.subscribe((event) => events.push(event));
  const formDirty = new FormDirty();
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: bus },
      { provide: FormDirty, useValue: formDirty },
    ],
  });
  return { store: TestBed.inject(TaskWizard), calls, events, formDirty };
}

describe('TaskWizard, edit mode (Story 9.8)', () => {
  it('open(id) reads the task and holds its values, a time as HH:MM, with every tab reachable', async () => {
    const { store, calls } = mountEdit();
    await store.open('1597');
    expect(calls[0]).toEqual({ path: `${TASK_FORM_PATH}?id=1597`, method: 'GET', body: '' });
    expect(store.mode()).toBe('edit');
    expect(store.id()).toBe('1597');
    expect(store.text('Name')).toBe('OcuP98Edit');
    expect(store.text('DailyStartTime')).toBe('01:00');
    expect(store.flag('OutputFileIsBinary')).toBe(true);
    expect(store.text('EmailOnCompletion')).toBe('ops@example.com');
    expect(store.values().settings).toEqual({ KeepDays: '30' });
    expect(store.type()?.className).toBe('%SYS.Task.PurgeTaskHistory');
    expect(store.reachable(OPTIONS_STEP)).toBe(true);
    expect(store.changedBody()).toEqual({});
  });

  it('the type and the namespace are fixed on an edit, and a type holding a classic-only setting draws and takes no setting', async () => {
    const { store } = mountEdit({ classicOnly: true });
    await store.open('1597');
    expect(store.fixed('TaskClass') && store.fixed('NameSpace')).toBe(true);
    store.setText('TaskClass', '%SYS.Task.IntegrityCheck');
    store.setText('NameSpace', 'USER');
    expect(store.text('TaskClass')).toBe('%SYS.Task.PurgeTaskHistory');
    expect(store.text('NameSpace')).toBe('%SYS');
    expect(store.settingsClassicOnly()).toBe(true);
    store.setSetting('KeepDays', '45');
    expect(store.changedBody()).toEqual({});
  });

  it('Integration, AD-14: Save puts the changed fields only, shows Saved, publishes task updated with the id, and leaves the form clean', async () => {
    // Mutation (Rule 19): skip the `updated` publish in `TaskWizard.save` -> the event leg goes red.
    const { store, calls, events, formDirty } = mountEdit();
    await store.open('1597');
    store.setText('Description', 'edited');
    store.setText('DailyIncrement', '15');
    store.setSetting('KeepDays', '45');
    expect(formDirty.dirty()).toBe(true);
    expect(await store.save()).toBe(true);
    const put = calls.find((call) => call.method === 'PUT');
    expect(put?.path).toBe(`${TASKS_PATH}/1597`);
    expect(JSON.parse(put?.body ?? '{}')).toEqual({ Description: 'edited', DailyIncrement: '15', Settings: { KeepDays: '45' } });
    expect(store.saved()).toBe(true);
    expect(formDirty.dirty()).toBe(false);
    expect(events).toHaveLength(1);
    expect(events[0]).toMatchObject({ kind: 'changed', type: 'task', scope: 'instance', id: '1597', action: 'updated' });
    const before = calls.length;
    expect(await store.save()).toBe(true);
    expect(calls.length, 'a Save that changes nothing sends nothing').toBe(before);
  });

  it('a refused Save keeps every value and holds the refusal on its field', async () => {
    const refusal = { kind: 'error', status: 422, error: 'validation_failed', reason: 'The task was refused.', code: 'TASK.VALIDATION', detail: { violations: [{ field: 'StartDate', code: 'TASK.STARTDATE.PAST', reason: 'The first run must be later than now on this instance\'s clock.' }] } };
    const { store, events } = mountEdit({ save: refusal as unknown as JsonResult<unknown> });
    await store.open('1597');
    store.setText('DailyStartTime', '02:00');
    expect(await store.save()).toBe(false);
    expect(store.violationFor('StartDate')).toContain('later than now');
    expect(store.text('DailyStartTime')).toBe('02:00');
    expect(store.saved()).toBe(false);
    expect(events).toEqual([]);
  });

  it('Matrix "Absent": a task the instance no longer holds is absent', async () => {
    const gone = { kind: 'error', status: 404, error: 'not_found', reason: 'This task no longer exists.', code: 'TASK.ABSENT', detail: null };
    const { store } = mountEdit({ form: gone as unknown as JsonResult<unknown> });
    await store.open('1597');
    expect(store.loaded()).toBe(true);
    expect(store.absent()).toBe(true);
    expect(store.reason()).toBe('This task no longer exists.');
  });

  it('refresh re-reads the task while the form is clean, and leaves unsaved work alone', async () => {
    const { store, calls } = mountEdit();
    await store.open('1597');
    await store.refresh();
    expect(store.text('Description')).toBe('read again');
    store.setText('Description', 'mine');
    const before = calls.length;
    await store.refresh();
    expect(calls.length).toBe(before);
    expect(store.text('Description')).toBe('mine');
  });

  it('AD-10 on an edit: keeping the account the task runs as is not running as another; moving it is', async () => {
    const { store } = mountEdit();
    await store.open('1597');
    expect(store.runsAsOther('Least')).toBe(false);
    store.setText('RunAsUser', 'Admin');
    expect(store.runsAsOther('Least')).toBe(true);
    store.setText('RunAsUser', 'least');
    expect(store.runsAsOther('Least')).toBe(false);
  });
});

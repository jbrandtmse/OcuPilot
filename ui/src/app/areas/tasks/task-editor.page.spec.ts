import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { OverlayStack } from '../../core/overlay-stack';
import { ScopeService } from '../../core/scope';
import { Session } from '../../core/session';
import { STRINGS } from '../../core/strings';
import { TaskEditorPage } from './task-editor.page';
import { TASKS_PATH, TASK_FORM_PATH } from './task-wizard.store';

/**
 * Edit task over stubs of what an instance supplies -- the HTTP answers, the namespace list and the
 * signed-in user (Story 9.8). The real store, the real tabs, the real field group, the real
 * `FormDirty` and the real template run, so the assertions are about rendered DOM (AC1, AD-10,
 * DW-1624, Integration).
 */

const TASK = {
  Id: 1597,
  Name: 'OcuP98Edit',
  Description: 'probe',
  NameSpace: '%SYS',
  TaskClass: '%SYS.Task.PurgeTaskHistory',
  TimePeriod: 'Weekly',
  TimePeriodEvery: '1',
  TimePeriodDay: '24',
  RunAfterGUID: '',
  DailyFrequency: 'Several',
  DailyFrequencyTime: 'Minutes',
  DailyIncrement: '30',
  DailyStartTime: '01:00:00',
  DailyEndTime: '05:00:00',
  StartDate: '2026-09-25',
  EndDate: '',
  ExpiresDays: '',
  ExpiresHours: '',
  ExpiresMinutes: '',
  RunAsUser: '_SYSTEM',
  Priority: 'Low',
  MirrorStatus: 'Any',
  OutputDirectory: '/durable/iris/mgr/',
  OutputFilename: 'ocup98edit.txt',
  Expires: false,
  IsBatch: true,
  OpenOutputFile: true,
  OutputFileIsBinary: true,
  EmailOutput: true,
  SuspendOnError: true,
  SuspendTerminated: false,
  RescheduleOnStart: true,
  EmailOnCompletion: ['ops@example.com'],
  EmailOnError: ['dev@example.com'],
  EmailOnExpiration: ['late@example.com'],
  Settings: { KeepDays: '30' },
  Type: 'User',
};

const FORM = {
  requiredFields: ['Name', 'NameSpace', 'TaskClass', 'TimePeriod'],
  maxLengths: { Name: 50, Description: 100, OutputFilename: 104 },
  rules: [{ field: 'Name', code: 'TASK.NAME.REQUIRED', reason: 'Give the task a name.' }],
  defaults: {},
  namespace: '%SYS',
  types: [
    {
      class: '%SYS.Task.PurgeTaskHistory',
      name: 'PurgeTaskHistory',
      settings: [{ name: 'KeepDays', label: 'KeepDays', kind: 'number', required: true, default: '7' }],
      classicOnly: [],
    },
  ],
  runAfter: [],
  task: TASK,
  settingsClassicOnly: false,
};

const START_PAST = {
  kind: 'error',
  status: 422,
  code: 'TASK.VALIDATION',
  reason: 'The task was refused.',
  detail: { violations: [{ field: 'StartDate', code: 'TASK.STARTDATE.PAST', reason: 'The first run must be later than now on this instance\'s clock.' }] },
};

const GONE = { kind: 'error', status: 404, code: 'TASK.ABSENT', reason: 'This task no longer exists.', detail: null };

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(options: { readonly form?: unknown; readonly save?: JsonResult<unknown> } = {}) {
  TestBed.resetTestingModule();
  const calls: { path: string; method: string; body: string }[] = [];
  let reads = 0;
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      calls.push({ path, method, body: init.body ?? '' });
      if (path.startsWith(TASK_FORM_PATH)) {
        reads += 1;
        if (options.form !== undefined) return options.form as JsonResult<T>;
        const task = reads > 1 ? { ...TASK, Description: 'changed elsewhere' } : TASK;
        return { kind: 'ok', status: 200, body: { ...FORM, task } } as unknown as JsonResult<T>;
      }
      return (options.save ?? { kind: 'ok', status: 200, body: { id: 1597, name: 'OcuP98Edit' } }) as JsonResult<T>;
    },
  };
  const scope = { namespaces: () => [{ name: '%SYS' }, { name: 'HSCUSTOM' }] };
  const session = { userName: () => 'Least' };
  const bus = new ChangeBus();
  const formDirty = new FormDirty();
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: FormDirty, useValue: formDirty },
      { provide: ChangeBus, useValue: bus },
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: ScopeService, useValue: scope as unknown as ScopeService },
      { provide: Session, useValue: session as unknown as Session },
    ],
  });
  const router = TestBed.inject(Router);
  await router.navigateByUrl('/tasks/schedule/edit/1597?ns=HSCUSTOM');
  const fixture = TestBed.createComponent(TaskEditorPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, calls, bus, formDirty, host: fixture.nativeElement as HTMLElement };
}

function tabs(host: HTMLElement): HTMLButtonElement[] {
  return [...host.querySelectorAll('.ocu-form-tab')] as HTMLButtonElement[];
}

function selectedTab(host: HTMLElement): string {
  return host.querySelector('.ocu-form-tab.mdc-tab--active, .ocu-form-tab[aria-selected="true"]')?.getAttribute('data-tab') ?? '';
}

function control<T extends HTMLElement>(host: HTMLElement, field: string): T {
  return host.querySelector(`#ocu-task-${field}`) as T;
}

function type(host: HTMLElement, field: string, value: string): void {
  const input = control<HTMLInputElement | HTMLSelectElement>(host, field);
  input.value = value;
  input.dispatchEvent(new Event(input instanceof HTMLSelectElement ? 'change' : 'input'));
}

function save(host: HTMLElement): HTMLButtonElement {
  return host.querySelector('.ocu-form-bar .ocu-button-primary') as HTMLButtonElement;
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('TaskEditorPage', () => {
  it('AC1: four tabs named for the wizard\'s steps, each field holding the task\'s value, the type and namespace read-only', async () => {
    const { calls, host } = await mount();
    expect(calls[0]).toEqual({ path: `${TASK_FORM_PATH}?id=1597`, method: 'GET', body: '' });
    expect(tabs(host).map((tab) => tab.textContent?.trim())).toEqual([STRINGS.taskStepBasics, STRINGS.taskStepType, STRINGS.taskDetailsSchedule, STRINGS.taskStepOptions]);
    expect(control<HTMLInputElement>(host, 'Name').value).toBe('OcuP98Edit');
    for (const field of ['TaskClass', 'NameSpace']) {
      const fixed = control<HTMLInputElement>(host, field);
      expect(fixed.tagName, field).toBe('INPUT');
      expect(fixed.readOnly, field).toBe(true);
      expect(host.querySelector(`#ocu-task-${field}-caption`)?.textContent?.trim(), field).toBe(STRINGS.taskEditFixed);
      expect(fixed.getAttribute('aria-describedby'), field).toContain(`ocu-task-${field}-caption`);
    }
    expect(control<HTMLInputElement>(host, 'TaskClass').value).toBe('PurgeTaskHistory (%SYS.Task.PurgeTaskHistory)');
    expect(control<HTMLInputElement>(host, 'Settings-KeepDays').value).toBe('30');
    expect(control<HTMLInputElement>(host, 'DailyStartTime').value).toBe('01:00');
    const details = [...host.querySelectorAll('.ocu-details-link')].find((link) => link.textContent?.trim() === STRINGS.taskDetailsLabel);
    expect(details?.getAttribute('href')).toContain('/tasks/schedule/details/1597');
  });

  it('DW-1624: the options tab draws every value a wizard-created task holds, read from the instance', async () => {
    // Mutation (Rule 19): drop `OutputFileIsBinary` from `valuesFromTask` -> the binary leg goes red.
    const { host } = await mount();
    expect(control<HTMLSelectElement>(host, 'Priority').value).toBe('Low');
    expect(control<HTMLSelectElement>(host, 'MirrorStatus').value).toBe('Any');
    expect(control<HTMLInputElement>(host, 'OutputFilename').value).toBe('ocup98edit.txt');
    for (const field of ['IsBatch', 'OpenOutputFile', 'OutputFileIsBinary', 'EmailOutput', 'SuspendOnError', 'RescheduleOnStart']) {
      expect(control<HTMLInputElement>(host, field).checked, field).toBe(true);
    }
    expect(control<HTMLInputElement>(host, 'SuspendTerminated').checked).toBe(false);
    expect(control<HTMLInputElement>(host, 'EmailOnCompletion').value).toBe('ops@example.com');
    expect(control<HTMLInputElement>(host, 'EmailOnError').value).toBe('dev@example.com');
    expect(control<HTMLInputElement>(host, 'EmailOnExpiration').value).toBe('late@example.com');
  });

  it('Integration, AD-14: Save puts the changed fields only and shows "Saved"', async () => {
    const { fixture, calls, host } = await mount();
    type(host, 'Description', 'edited');
    type(host, 'DailyIncrement', '15');
    await settle(fixture);
    save(host).click();
    await settle(fixture);
    const put = calls.find((call) => call.method === 'PUT');
    expect(put?.path).toBe(`${TASKS_PATH}/1597`);
    expect(JSON.parse(put?.body ?? '{}')).toEqual({ Description: 'edited', DailyIncrement: '15' });
    expect(host.querySelector('.ocu-form-bar-status')?.textContent?.trim()).toBe(STRINGS.formSaved);
  });

  it('AC1: a refused Save opens the refused field\'s tab with its marker and ", N errors", focusing the summary then the field', async () => {
    const { fixture, host } = await mount({ save: START_PAST as unknown as JsonResult<unknown> });
    type(host, 'Description', 'edited');
    await settle(fixture);
    const focused: string[] = [];
    host.addEventListener('focusin', (event) => {
      const target = event.target as HTMLElement;
      focused.push(target.id || target.className);
    });
    save(host).click();
    await settle(fixture);
    // Mutation (Rule 19): skip `tabToOpen` in `afterRefusal` -> the tab stays Basics and this goes red.
    const schedule = tabs(host).find((tab) => tab.getAttribute('data-tab') === 'schedule') as HTMLButtonElement;
    expect(schedule.classList.contains('ocu-form-tab-invalid')).toBe(true);
    expect(schedule.getAttribute('aria-label')).toBe(`${STRINGS.taskDetailsSchedule}, 1 error`);
    expect(host.querySelector('[data-tab-body="schedule"]')?.hasAttribute('hidden')).toBe(false);
    expect(host.querySelector('[data-tab-body="basics"]')?.hasAttribute('hidden')).toBe(true);
    expect(focused[0]).toContain('ocu-form-summary');
    expect(document.activeElement?.id).toBe('ocu-task-StartDate');
  });

  it('AD-10: moving the task to another account states its effect; keeping the one it runs as does not', async () => {
    const { fixture, host } = await mount();
    expect(host.querySelector('#ocu-task-RunAsUser-effect')).toBeNull();
    type(host, 'RunAsUser', 'Admin');
    await settle(fixture);
    expect(host.querySelector('#ocu-task-RunAsUser-effect')?.textContent?.trim()).toBe(STRINGS.taskRunAsOtherEffect);
    type(host, 'RunAsUser', '_system');
    await settle(fixture);
    expect(host.querySelector('#ocu-task-RunAsUser-effect')).toBeNull();
  });

  it('the dirty guard: leaving with unsaved work asks "Leave without saving?"', async () => {
    const { fixture, formDirty, host } = await mount();
    type(host, 'Description', 'unsaved');
    await settle(fixture);
    expect(formDirty.dirty()).toBe(true);
    const leaving = formDirty.requestLeave();
    await settle(fixture);
    expect(document.body.textContent).toContain(STRINGS.formLeaveWithoutSaving);
    formDirty.answer(false);
    expect(await leaving).toBe(false);
  });

  it('Integration, AD-14: a change to this task from elsewhere re-reads it while the form is clean', async () => {
    const { fixture, bus, calls, host } = await mount();
    bus.publish({ kind: 'changed', type: 'task', scope: 'instance', id: '1597', action: 'updated' });
    await settle(fixture);
    expect(calls.filter((call) => call.path.startsWith(TASK_FORM_PATH))).toHaveLength(2);
    expect(control<HTMLInputElement>(host, 'Description').value).toBe('changed elsewhere');
    bus.publish({ kind: 'changed', type: 'task', scope: 'instance', id: '42', action: 'updated' });
    await settle(fixture);
    expect(calls.filter((call) => call.path.startsWith(TASK_FORM_PATH)), 'another task is not this one').toHaveLength(2);
  });

  it('Matrix "Absent": a task the instance no longer holds shows "This task no longer exists." and no form', async () => {
    const { host } = await mount({ form: GONE });
    expect(host.textContent).toContain(STRINGS.taskDetailsGone);
    expect(tabs(host)).toHaveLength(0);
    expect(save(host)).toBeNull();
  });
});

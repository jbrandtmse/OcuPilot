import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { OverlayStack } from '../../core/overlay-stack';
import { ScopeService } from '../../core/scope';
import { Session } from '../../core/session';
import { STRINGS } from '../../core/strings';
import { TaskWizardPage } from './task-wizard.page';
import { TASKS_PATH, TASK_CHECK_PATH, TASK_FORM_PATH } from './task-wizard.store';

/**
 * The New Task wizard over stubs of what an instance supplies -- the HTTP answers, the namespace
 * list and the signed-in user. The real store, the real stepper, the real `FormDirty` and the real
 * template run, so the assertions are about rendered DOM (AC1, AC7, AD-10, Integration).
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

const FORM = {
  requiredFields: ['Name', 'NameSpace', 'TaskClass', 'TimePeriod'],
  maxLengths: { Name: 50, Description: 100, OutputFilename: 104 },
  rules: [{ field: 'Name', code: 'TASK.NAME.REQUIRED', reason: 'Give the task a name.' }],
  defaults: DEFAULTS,
  namespace: '%SYS',
  types: [
    {
      class: '%SYS.Task.IntegrityCheck',
      name: 'IntegrityCheck',
      settings: [{ name: 'Directory', label: 'Directory', kind: 'string', required: false, default: '' }],
      classicOnly: [],
    },
    {
      class: '%SYS.Task.PurgeTaskHistory',
      name: 'PurgeTaskHistory',
      settings: [{ name: 'KeepDays', label: 'KeepDays', kind: 'number', required: true, default: '7' }],
      classicOnly: [],
    },
  ],
  runAfter: [{ guid: 'G-1', id: 7, name: 'Purge Tasks' }],
};

const NAME_TAKEN = {
  kind: 'error',
  status: 422,
  code: 'TASK.VALIDATION',
  reason: 'The task was refused.',
  detail: { violations: [{ field: 'Name', code: 'TASK.NAME.TAKEN', reason: 'This instance already has a task with that name. Choose a different one.' }] },
};

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(options: { readonly check?: unknown[]; readonly create?: JsonResult<unknown> } = {}) {
  TestBed.resetTestingModule();
  const calls: { path: string; method: string; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      calls.push({ path, method, body: init.body ?? '' });
      if (path.startsWith(TASK_FORM_PATH)) return { kind: 'ok', status: 200, body: FORM } as unknown as JsonResult<T>;
      if (path === TASK_CHECK_PATH) return { kind: 'ok', status: 200, body: { violations: options.check ?? [] } } as unknown as JsonResult<T>;
      return (options.create ?? { kind: 'ok', status: 201, body: { id: 1391, name: 'OcuP97W' } }) as JsonResult<T>;
    },
  };
  const scope = { namespaces: () => [{ name: '%SYS' }, { name: 'HSCUSTOM' }] };
  const session = { userName: () => '_SYSTEM' };
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: FormDirty, useValue: new FormDirty() },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: ScopeService, useValue: scope as unknown as ScopeService },
      { provide: Session, useValue: session as unknown as Session },
    ],
  });
  const router = TestBed.inject(Router);
  await router.navigateByUrl('/tasks/schedule/edit?ns=HSCUSTOM');
  const fixture = TestBed.createComponent(TaskWizardPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, calls, router, host: fixture.nativeElement as HTMLElement };
}

function heads(host: HTMLElement): HTMLButtonElement[] {
  return [...host.querySelectorAll('.ocu-form-step-head')] as HTMLButtonElement[];
}

function headLabels(host: HTMLElement): string[] {
  return heads(host).map((head) => head.querySelector('.ocu-form-step-label')?.textContent?.trim() ?? '');
}

function currentStep(host: HTMLElement): string {
  return host.querySelector('.ocu-form-step-head[aria-current="step"] .ocu-form-step-label')?.textContent?.trim() ?? '';
}

function primary(host: HTMLElement): HTMLButtonElement {
  return host.querySelector('.ocu-form-bar .ocu-button-primary') as HTMLButtonElement;
}

function button(host: HTMLElement, label: string): HTMLButtonElement | undefined {
  return ([...host.querySelectorAll('.ocu-form-bar button')] as HTMLButtonElement[]).find((entry) => entry.textContent?.trim() === label);
}

function type(host: HTMLElement, id: string, value: string): void {
  const control = host.querySelector(`#${id}`) as HTMLInputElement | HTMLSelectElement;
  control.value = value;
  control.dispatchEvent(new Event(control instanceof HTMLSelectElement ? 'change' : 'input'));
}

async function next(fixture: ComponentFixture<unknown>, host: HTMLElement): Promise<void> {
  primary(host).click();
  await settle(fixture);
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('TaskWizardPage', () => {
  it('AC1: a linear vertical stepper of the four named steps, Next leading to a last primary reading "Create task"', async () => {
    const { fixture, host } = await mount();
    expect(host.querySelector('ol.ocu-form-stepper')).not.toBeNull();
    expect(headLabels(host)).toEqual([STRINGS.taskStepBasics, STRINGS.taskStepType, STRINGS.taskDetailsSchedule, STRINGS.taskStepOptions]);
    expect(currentStep(host)).toBe(STRINGS.taskStepBasics);
    expect(heads(host).slice(1).every((head) => head.disabled)).toBe(true);
    expect(primary(host).textContent?.trim()).toBe(STRINGS.actionNext);
    expect(button(host, STRINGS.errorLogBack)).toBeUndefined();
    type(host, 'ocu-task-Name', 'OcuP97W');
    await next(fixture, host);
    expect(currentStep(host)).toBe(STRINGS.taskStepType);
    await next(fixture, host);
    await next(fixture, host);
    expect(currentStep(host)).toBe(STRINGS.taskStepOptions);
    expect(primary(host).textContent?.trim()).toBe(STRINGS.taskCreate);
    button(host, STRINGS.errorLogBack)?.click();
    await settle(fixture);
    expect(currentStep(host)).toBe(STRINGS.taskDetailsSchedule);
  });

  it('AC1, Matrix "Next on empty Basics": a refused Next stays, marks the step and names the refusal in its heading', async () => {
    const { fixture, host } = await mount({ check: [{ field: 'Name', code: 'TASK.NAME.REQUIRED', reason: 'Give the task a name.' }] });
    await next(fixture, host);
    expect(currentStep(host)).toBe(STRINGS.taskStepBasics);
    const basics = heads(host)[0];
    expect(basics.classList.contains('ocu-form-step-invalid')).toBe(true);
    expect(basics.getAttribute('aria-label')).toBe(`${STRINGS.taskStepBasics}, 1 error`);
    expect(host.querySelector('#ocu-form-step-error-basics')?.textContent).toContain('Give the task a name.');
    expect(host.querySelector('#ocu-task-Name-reason')?.textContent?.trim()).toBe('Give the task a name.');
  });

  it('Matrix "Type loads settings": the chosen type\'s settings are drawn with their defaults, and the previous type\'s are gone', async () => {
    const { fixture, host } = await mount();
    type(host, 'ocu-task-Name', 'OcuP97W');
    await next(fixture, host);
    type(host, 'ocu-task-TaskClass', '%SYS.Task.IntegrityCheck');
    await settle(fixture);
    expect(host.querySelector('#ocu-task-Settings-Directory')).not.toBeNull();
    type(host, 'ocu-task-TaskClass', '%SYS.Task.PurgeTaskHistory');
    await settle(fixture);
    expect(host.querySelector('#ocu-task-Settings-Directory')).toBeNull();
    expect((host.querySelector('#ocu-task-Settings-KeepDays') as HTMLInputElement).value).toBe('7');
  });

  it('the Schedule step draws only what the period reads: On Demand draws no frequency, date or expiry', async () => {
    const { fixture, host } = await mount();
    type(host, 'ocu-task-Name', 'OcuP97W');
    await next(fixture, host);
    await next(fixture, host);
    expect(host.querySelector('#ocu-task-StartDate')).not.toBeNull();
    expect(host.querySelector('#ocu-task-Expires')).not.toBeNull();
    type(host, 'ocu-task-TimePeriod', 'On Demand');
    await settle(fixture);
    for (const field of ['DailyFrequency', 'StartDate', 'Expires', 'ExpiresDays', 'TimePeriodEvery']) {
      expect(host.querySelector(`#ocu-task-${field}`), field).toBeNull();
    }
    type(host, 'ocu-task-TimePeriod', 'Weekly');
    await settle(fixture);
    expect(host.querySelectorAll('.ocu-task-days input[type="checkbox"]')).toHaveLength(7);
  });

  it('AD-10: RunAsUser naming another account states its effect under the field before Create', async () => {
    const { fixture, host } = await mount();
    type(host, 'ocu-task-Name', 'OcuP97W');
    await next(fixture, host);
    await next(fixture, host);
    await next(fixture, host);
    expect(host.querySelector('#ocu-task-RunAsUser-effect')).toBeNull();
    type(host, 'ocu-task-RunAsUser', 'Admin');
    await settle(fixture);
    expect(host.querySelector('#ocu-task-RunAsUser-effect')?.textContent?.trim()).toBe(STRINGS.taskRunAsOtherEffect);
    expect(host.querySelector('#ocu-task-RunAsUser')?.getAttribute('aria-describedby')).toContain('ocu-task-RunAsUser-effect');
    type(host, 'ocu-task-RunAsUser', '_system');
    await settle(fixture);
    expect(host.querySelector('#ocu-task-RunAsUser-effect')).toBeNull();
  });

  it('Integration: a refused Create on Basics opens Basics with its marker, focusing the summary then the field', async () => {
    const { fixture, host } = await mount({ create: NAME_TAKEN as unknown as JsonResult<unknown> });
    type(host, 'ocu-task-Name', 'Purge Tasks');
    await next(fixture, host);
    await next(fixture, host);
    await next(fixture, host);
    expect(currentStep(host)).toBe(STRINGS.taskStepOptions);
    const focused: string[] = [];
    host.addEventListener('focusin', (event) => {
      const target = event.target as HTMLElement;
      focused.push(target.id || target.className);
    });
    primary(host).click();
    await settle(fixture);
    // Mutation (Rule 19): skip `tabToOpen` in `afterRefusal` -> the step stays Options and this goes red.
    expect(currentStep(host)).toBe(STRINGS.taskStepBasics);
    expect(heads(host)[0].classList.contains('ocu-form-step-invalid')).toBe(true);
    expect(host.querySelector('#ocu-form-step-error-basics')?.textContent).toContain('already has a task');
    expect(focused[0]).toContain('ocu-form-summary');
    expect(document.activeElement?.id).toBe('ocu-task-Name');
  });

  it('AC7, AD-14: an accepted Create replaces the page with the new task\'s details', async () => {
    const { fixture, host, router, calls } = await mount();
    const navigate = vi.spyOn(router, 'navigateByUrl');
    type(host, 'ocu-task-Name', 'OcuP97W');
    await next(fixture, host);
    type(host, 'ocu-task-TaskClass', '%SYS.Task.PurgeTaskHistory');
    await next(fixture, host);
    await next(fixture, host);
    (host.querySelector('#ocu-task-OutputFileIsBinary') as HTMLInputElement).click();
    for (const field of ['Priority', 'MirrorStatus', 'RunAsUser', 'OutputFilename']) {
      expect(host.querySelectorAll(`#ocu-task-${field}`), `one control for ${field}`).toHaveLength(1);
    }
    expect((host.querySelector('#ocu-task-Priority') as HTMLElement).tagName).toBe('SELECT');
    type(host, 'ocu-task-Priority', 'Low');
    await settle(fixture);
    primary(host).click();
    await settle(fixture);
    const create = calls.find((call) => call.path === TASKS_PATH);
    expect(JSON.parse(create?.body ?? '{}')).toMatchObject({ Name: 'OcuP97W', Priority: 'Low', OutputFileIsBinary: true, Settings: { KeepDays: '7' } });
    expect(navigate).toHaveBeenCalledWith('/tasks/schedule/details/1391?ns=HSCUSTOM', { replaceUrl: true });
  });
});

import { Component, input } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { ScopeService } from '../../core/scope';
import { Session } from '../../core/session';
import { STRINGS } from '../../core/strings';
import { TaskFieldGroup } from './task-field-group';
import { TaskWizard } from './task-wizard.store';

/**
 * The one field template the New Task wizard's steps and Edit task's tabs both render (Stories 9.7
 * and 9.8): a step draws its own fields and no other step's, and on an edit a type holding a
 * classic-only setting draws no setting input, only the sentence naming its settings (AD-35).
 */

@Component({
  selector: 'app-task-field-group-host',
  imports: [TaskFieldGroup],
  template: `<app-task-field-group [step]="step()" />`,
})
class Host {
  readonly step = input.required<string>();
}

const TYPES = [
  {
    class: '%SYS.Task.DiagnosticReport',
    name: 'DiagnosticReport',
    settings: [{ name: 'SMTPUser', label: 'SMTPUser', kind: 'string', required: false, default: '' }],
    classicOnly: ['SMTPPass'],
  },
];

const TASK = { Id: 1600, Name: 'OcuP98Secret', NameSpace: '%SYS', TaskClass: '%SYS.Task.DiagnosticReport', TimePeriod: 'On Demand', RunAsUser: '_SYSTEM' };

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(step: string) {
  TestBed.resetTestingModule();
  const api = {
    requestJson: async <T,>(_path: string, _init: ApiRequestInit = {}): Promise<JsonResult<T>> =>
      ({ kind: 'ok', status: 200, body: { requiredFields: [], maxLengths: {}, rules: [], defaults: {}, namespace: '%SYS', types: TYPES, runAfter: [], task: TASK, settingsClassicOnly: true } }) as unknown as JsonResult<T>,
  };
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: FormDirty, useValue: new FormDirty() },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: ScopeService, useValue: { namespaces: () => [{ name: '%SYS' }] } as unknown as ScopeService },
      { provide: Session, useValue: { userName: () => '_SYSTEM' } as unknown as Session },
    ],
  });
  await TestBed.inject(TaskWizard).open('1600');
  const fixture = TestBed.createComponent(Host);
  fixture.componentRef.setInput('step', step);
  await settle(fixture);
  return { fixture, host: fixture.nativeElement as HTMLElement };
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('TaskFieldGroup', () => {
  it('draws its own step\'s fields and no other step\'s', async () => {
    const { host } = await mount('basics');
    expect(host.querySelector('#ocu-task-Name')).not.toBeNull();
    expect(host.querySelector('#ocu-task-TaskClass')).toBeNull();
    expect(host.querySelector('#ocu-task-RunAsUser')).toBeNull();
  });

  it('AD-35 on an edit: a type holding a classic-only setting draws no setting input, only the sentence naming them', async () => {
    // Mutation (Rule 19): drop `settingsClassicOnly` from `drawsSettings` -> the SMTPUser input
    // appears and this goes red.
    const { host } = await mount('type');
    expect((host.querySelector('#ocu-task-TaskClass') as HTMLInputElement).readOnly).toBe(true);
    expect(host.querySelector('#ocu-task-Settings-SMTPUser')).toBeNull();
    expect(host.textContent).toContain(STRINGS.taskSettingClassicOnly.replace('<settings>', 'SMTPPass'));
  });
});

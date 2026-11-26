import { Component, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { InteropWorkflowTaskDialog, type WorkflowTaskChange, type WorkflowTaskView } from './interop-workflow-task-dialog';

/**
 * The Assign task dialog (Story 24.17 Batch 4) on its own: its title and consequence, the user choices (Unassigned, the task's own assignee and the listed active users, each once), the
 * priority choices (1 to 5, with the task's own first where it lies outside them), the values Save emits -- only what differs from the task -- Save held while a send is in flight, a
 * refusal shown in it, and the dismissals. The page that opens it is `interop-workflow-task-list.page.spec.ts`'s.
 */

@Component({
  imports: [InteropWorkflowTaskDialog],
  template: `<app-interop-workflow-task-dialog
    [task]="task()"
    [refusal]="refusal()"
    [sending]="sending()"
    (confirmed)="confirmed.push($event)"
    (cancelled)="cancelled = cancelled + 1"
  />`,
})
class Host {
  readonly task = signal<WorkflowTaskView>({ id: '12', assignee: 'Probe', priority: '3', users: ['Admin', 'Probe', 'Other'] });

  readonly refusal = signal('');

  readonly sending = signal(false);

  readonly confirmed: WorkflowTaskChange[] = [];

  cancelled = 0;
}

const planted: HTMLElement[] = [];

function mount() {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({ providers: [{ provide: OverlayStack, useValue: new OverlayStack() }] });
  const fixture = TestBed.createComponent(Host);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, instance: fixture.componentInstance };
}

const field = (host: HTMLElement, name: string): HTMLSelectElement => host.querySelector(`[data-interop-workflow-task-field="${name}"]`) as HTMLSelectElement;

const confirmButton = (host: HTMLElement): HTMLButtonElement => host.querySelector('[data-interop-workflow-task-confirm]') as HTMLButtonElement;

function choose(host: HTMLElement, name: string, value: string): void {
  const control = field(host, name);
  control.value = value;
  control.dispatchEvent(new Event('change'));
}

const consequence = (host: HTMLElement): string => host.querySelector('[data-interop-workflow-task-consequence]')?.textContent?.trim() ?? '';

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Assign task dialog', () => {
  it('titles itself Assign task and labels its fields', () => {
    const { host } = mount();
    expect(STRINGS.interopWorkflowTaskAssignTitle).toBe('Assign task');
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe('Assign task');
    for (const caption of [STRINGS.processColumnUser, STRINGS.taskDetailsPriority, STRINGS.actionSave]) {
      expect(host.textContent).toContain(caption);
    }
  });

  // Mutation (Rule 19): list the users before Unassigned, or repeat the task's assignee among them -> this goes red.
  it('offers Unassigned first, then the task\'s assignee and the listed users once each, with the task\'s own assignee chosen', () => {
    const { host } = mount();
    const options = [...host.querySelectorAll('[data-interop-workflow-task-field="User"] option')] as HTMLOptionElement[];
    expect(options.map((option) => [option.value, option.textContent?.trim()])).toEqual([
      ['', STRINGS.interopAlertOwnerUnassigned],
      ['Probe', 'Probe'],
      ['Admin', 'Admin'],
      ['Other', 'Other'],
    ]);
    expect(field(host, 'User').value).toBe('Probe');
  });

  it('offers priorities 1 to 5 with the task\'s own chosen, and its own first where it lies outside them', () => {
    const { fixture, host, instance } = mount();
    const priorities = () => [...host.querySelectorAll('[data-interop-workflow-task-field="Priority"] option')].map((option) => (option as HTMLOptionElement).value);
    expect(priorities()).toEqual(['1', '2', '3', '4', '5']);
    expect(field(host, 'Priority').value).toBe('3');
    instance.task.set({ ...instance.task(), priority: '0' });
    fixture.detectChanges();
    expect(priorities()).toEqual(['0', '1', '2', '3', '4', '5']);
    expect(field(host, 'Priority').value).toBe('0');
  });

  // Mutation (Rule 19): emit both fields whatever the person changed -> the first assertion goes red.
  it('emits nothing but an empty change when nothing was changed, for the instance to refuse in its own words', () => {
    const { host, instance } = mount();
    confirmButton(host).click();
    expect(instance.confirmed).toEqual([{}]);
  });

  it('emits only the priority when only the priority was changed', () => {
    const { host, instance } = mount();
    choose(host, 'Priority', '1');
    confirmButton(host).click();
    expect(instance.confirmed).toEqual([{ Priority: '1' }]);
  });

  it('emits only the user when only the user was changed, and an empty user for Unassigned', () => {
    const { host, instance } = mount();
    choose(host, 'User', 'Admin');
    confirmButton(host).click();
    choose(host, 'User', '');
    confirmButton(host).click();
    expect(instance.confirmed).toEqual([{ User: 'Admin' }, { User: '' }]);
  });

  it('emits both when both were changed', () => {
    const { host, instance } = mount();
    choose(host, 'User', 'Other');
    choose(host, 'Priority', '5');
    confirmButton(host).click();
    expect(instance.confirmed).toEqual([{ User: 'Other', Priority: '5' }]);
  });

  // Mutation (Rule 19): state the assign sentence for Unassigned too -> the second assertion goes red.
  it('states the assign sentence for a user and the unassign sentence for Unassigned on a task that is assigned', () => {
    const { fixture, host } = mount();
    expect(consequence(host)).toBe(STRINGS.interopWorkflowTaskAssignConsequence);
    choose(host, 'User', '');
    fixture.detectChanges();
    expect(consequence(host)).toBe(STRINGS.interopWorkflowTaskUnassignConsequence);
    choose(host, 'User', 'Admin');
    fixture.detectChanges();
    expect(consequence(host)).toBe(STRINGS.interopWorkflowTaskAssignConsequence);
  });

  it('holds Save while a send is in flight and shows a refusal above it', () => {
    const { fixture, host, instance } = mount();
    instance.sending.set(true);
    instance.refusal.set(STRINGS.interopWorkflowTaskRefusalUnchanged);
    fixture.detectChanges();
    expect(confirmButton(host).getAttribute('aria-disabled')).toBe('true');
    confirmButton(host).click();
    expect(instance.confirmed).toEqual([]);
    expect(host.querySelector('[data-interop-workflow-task-refusal]')?.textContent?.trim()).toBe(STRINGS.interopWorkflowTaskRefusalUnchanged);
  });

  it('emits cancelled on Cancel', () => {
    const { host, instance } = mount();
    const cancel = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;
    cancel.click();
    expect(instance.cancelled).toBe(1);
  });
});

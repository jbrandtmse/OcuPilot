import { Component, signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { InteropWorkflowRoleDialog } from './interop-workflow-role-dialog';
import { InteropWorkflowRoleStore, type WorkflowRoleValues } from './interop-workflow-role.store';

/**
 * The New workflow role and Edit dialog (Story 24.17 Batch 3b): its published words in both modes, a button that stays unavailable until a name is
 * typed, the workflow role posted to the namespace it was given with its capacity as a number, an Edit that holds the name read-only and hands its
 * values to the page, and the server's two kinds of refusal drawn where each belongs.
 */

@Component({
  imports: [InteropWorkflowRoleDialog],
  template: `<app-interop-workflow-role-dialog
    [namespace]="namespace()"
    [workflowRole]="workflowRole()"
    (added)="added.push($event)"
    (submitted)="submitted.push($event)"
    (cancelled)="cancelled = cancelled + 1"
  />`,
})
class Host {
  readonly namespace = signal('USER');
  readonly workflowRole = signal<string | null>(null);
  readonly added: string[] = [];
  readonly submitted: WorkflowRoleValues[] = [];
  cancelled = 0;
}

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 3; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 2));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

interface MountOptions {
  readonly answer?: JsonResult<unknown>;
  readonly workflowRole?: string | null;
  readonly initial?: WorkflowRoleValues | null;
}

async function mount(options: MountOptions = {}) {
  TestBed.resetTestingModule();
  const sent: { path: string; scope: string | null | undefined; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      sent.push({ path, scope: init.scope, body: typeof init.body === 'string' ? init.body : '' });
      return (options.answer ?? { kind: 'ok', status: 201, body: {} }) as JsonResult<T>;
    },
  };
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  TestBed.inject(InteropWorkflowRoleStore).reset(options.initial ?? null);
  const fixture = TestBed.createComponent(Host);
  fixture.componentInstance.workflowRole.set(options.workflowRole ?? null);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  return { fixture, host: fixture.nativeElement as HTMLElement, sent };
}

function field(host: HTMLElement, name: string): HTMLInputElement | HTMLTextAreaElement {
  return host.querySelector(`[data-interop-workflow-role-field="${name}"]`) as HTMLInputElement | HTMLTextAreaElement;
}

function type(fixture: ComponentFixture<unknown>, host: HTMLElement, name: string, value: string): void {
  const input = field(host, name);
  input.value = value;
  input.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

function confirm(host: HTMLElement): HTMLButtonElement {
  return host.querySelector('[data-interop-workflow-role-confirm]') as HTMLButtonElement;
}

describe('the New workflow role and Edit dialog', () => {
  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
    TestBed.resetTestingModule();
  });

  it('as New workflow role, draws the name, the description and the capacity under their published words and needs a name', async () => {
    const { fixture, host, sent } = await mount();
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopWorkflowRoleAddAction);
    expect(host.querySelector('[data-interop-workflow-role-help]')?.textContent?.trim()).toBe(STRINGS.interopWorkflowRoleHelp);
    const labels = ['Name', 'Description', 'Capacity'].map((name) => host.querySelector(`label[for="${field(host, name).id}"]`)?.textContent?.trim());
    expect(labels).toEqual([STRINGS.tableColumnName, STRINGS.tableColumnDescription, STRINGS.promptGroupCapacity]);
    expect(field(host, 'Name').readOnly).toBe(false);
    expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    confirm(host).click();
    await settle(fixture);
    expect(sent).toEqual([]);
    type(fixture, host, 'Name', 'OcuP2417rA');
    expect(confirm(host).getAttribute('aria-disabled')).toBeNull();
  });

  it('as New workflow role, posts the typed fields, the capacity as a number, to the namespace given, and emits the name once the instance added it', async () => {
    const { fixture, host, sent } = await mount({ answer: { kind: 'ok', status: 201, body: { readBack: { verdict: 'matches' } } } });
    type(fixture, host, 'Name', 'OcuP2417rA');
    type(fixture, host, 'Description', 'Order approvals');
    type(fixture, host, 'Capacity', '40');
    confirm(host).click();
    await settle(fixture);
    expect(sent.map((call) => [call.path, call.scope])).toEqual([['/api/ocupilot/interop/workflow-roles', 'USER']]);
    expect(JSON.parse(sent[0].body)).toEqual({ Name: 'OcuP2417rA', Description: 'Order approvals', Capacity: 40 });
    expect((fixture.componentInstance as Host).added).toEqual(['OcuP2417rA']);
  });

  it('as Edit, titles the dialog by the role, holds the name read-only, and hands the values to the page without posting', async () => {
    // Mutation (Rule 19): leave the name editable in Edit -> the read-only assertions go red.
    const initial: WorkflowRoleValues = { name: 'OcuP2417rA', description: 'Orders', capacity: '40' };
    const { fixture, host, sent } = await mount({ workflowRole: 'OcuP2417rA', initial });
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopCredentialEditTitle.replace('<name>', 'OcuP2417rA'));
    const name = field(host, 'Name');
    expect(name.readOnly).toBe(true);
    expect(name.getAttribute('aria-readonly')).toBe('true');
    expect(name.value).toBe('OcuP2417rA');
    expect(field(host, 'Description').value).toBe('Orders');
    expect(field(host, 'Capacity').value).toBe('40');
    type(fixture, host, 'Description', 'Approvals');
    confirm(host).click();
    await settle(fixture);
    expect(sent).toEqual([]);
    expect((fixture.componentInstance as Host).submitted).toEqual([{ name: 'OcuP2417rA', description: 'Approvals', capacity: '40' }]);
    expect((fixture.componentInstance as Host).added).toEqual([]);
  });

  it('draws a refusal on a field under the field and names it by it, and emits nothing', async () => {
    const violation = { field: 'Capacity', code: 'INTEROP.WORKFLOW.ROLECAPACITY', reason: STRINGS.interopWorkflowRoleRefusalCapacity };
    const { fixture, host } = await mount({
      answer: { kind: 'error', status: 422, code: 'INTEROP.WORKFLOW.ROLECAPACITY', reason: STRINGS.interopWorkflowRoleRefusalCapacity, detail: { violations: [violation] } },
    });
    type(fixture, host, 'Name', 'OcuP2417rA');
    type(fixture, host, 'Capacity', '101');
    confirm(host).click();
    await settle(fixture);
    const input = field(host, 'Capacity');
    const error = host.querySelector('[data-interop-workflow-role-violation="Capacity"]') as HTMLElement;
    expect(error.textContent?.trim()).toBe(STRINGS.interopWorkflowRoleRefusalCapacity);
    expect(input.getAttribute('aria-invalid')).toBe('true');
    expect(input.getAttribute('aria-describedby')).toBe(error.id);
    expect(host.querySelector('[data-interop-workflow-role-reason]')).toBeNull();
    expect((fixture.componentInstance as Host).added).toEqual([]);
  });

  it('draws a refusal that names no field as the alert of the dialog', async () => {
    const { fixture, host } = await mount({
      answer: { kind: 'error', status: 409, code: 'INTEROP.WORKFLOW.ROLETAKEN', reason: STRINGS.interopWorkflowRoleRefusalTaken, detail: null },
    });
    type(fixture, host, 'Name', 'OcuP2417rA');
    confirm(host).click();
    await settle(fixture);
    const alert = host.querySelector('[data-interop-workflow-role-reason]') as HTMLElement;
    expect(alert.getAttribute('role')).toBe('alert');
    expect(alert.textContent?.trim()).toBe(STRINGS.interopWorkflowRoleRefusalTaken);
    expect((fixture.componentInstance as Host).added).toEqual([]);
  });

  it('emits cancelled for Cancel, sending nothing', async () => {
    const { fixture, host, sent } = await mount();
    const cancel = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;
    cancel.click();
    await settle(fixture);
    expect((fixture.componentInstance as Host).cancelled).toBe(1);
    expect(sent).toEqual([]);
  });
});

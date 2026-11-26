import { Component, signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { InteropWorkflowUserDialog } from './interop-workflow-user-dialog';
import { INTEROP_WORKFLOW_USER_CHOICES_PATH, InteropWorkflowUserStore, type WorkflowUserValues } from './interop-workflow-user.store';

/**
 * The New workflow user and Edit dialog (Story 24.17 Batch 3a): its published words in both modes, a Name chosen among the users of the instance the
 * namespace does not already hold, a button that stays unavailable until one is chosen, the workflow user posted to the namespace it was given with
 * its flag as a boolean, an Edit that holds the name read-only, says what an inactive user means and hands its values to the page, and the server's two
 * kinds of refusal drawn where each belongs.
 */

@Component({
  imports: [InteropWorkflowUserDialog],
  template: `<app-interop-workflow-user-dialog
    [namespace]="namespace()"
    [workflowUser]="workflowUser()"
    [held]="held()"
    [wasActive]="wasActive()"
    (added)="added.push($event)"
    (submitted)="submitted.push($event)"
    (cancelled)="cancelled = cancelled + 1"
  />`,
})
class Host {
  readonly namespace = signal('USER');
  readonly workflowUser = signal<string | null>(null);
  readonly held = signal<readonly string[]>([]);
  readonly wasActive = signal(false);
  readonly added: string[] = [];
  readonly submitted: WorkflowUserValues[] = [];
  cancelled = 0;
}

const planted: HTMLElement[] = [];

const CHOICES: JsonResult<unknown> = {
  kind: 'ok',
  status: 200,
  body: { rows: [{ Name: 'Admin' }, { Name: 'irisowner' }, { Name: 'OcuP2417wA' }, { Name: 'SuperUser' }] },
};

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 3; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 2));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

interface MountOptions {
  readonly answer?: JsonResult<unknown>;
  readonly choices?: JsonResult<unknown>;
  readonly workflowUser?: string | null;
  readonly initial?: WorkflowUserValues | null;
  readonly held?: readonly string[];
  readonly wasActive?: boolean;
}

async function mount(options: MountOptions = {}) {
  TestBed.resetTestingModule();
  const sent: { path: string; scope: string | null | undefined; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      sent.push({ path, scope: init.scope, body: typeof init.body === 'string' ? init.body : '' });
      return (path === INTEROP_WORKFLOW_USER_CHOICES_PATH ? (options.choices ?? CHOICES) : (options.answer ?? { kind: 'ok', status: 201, body: {} })) as JsonResult<T>;
    },
  };
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  TestBed.inject(InteropWorkflowUserStore).reset(options.initial ?? null);
  const fixture = TestBed.createComponent(Host);
  fixture.componentInstance.workflowUser.set(options.workflowUser ?? null);
  fixture.componentInstance.held.set(options.held ?? []);
  fixture.componentInstance.wasActive.set(options.wasActive ?? false);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  return { fixture, host: fixture.nativeElement as HTMLElement, sent };
}

function field(host: HTMLElement, name: string): HTMLInputElement | HTMLSelectElement {
  return host.querySelector(`[data-interop-workflow-user-field="${name}"]`) as HTMLInputElement | HTMLSelectElement;
}

function type(fixture: ComponentFixture<unknown>, host: HTMLElement, name: string, value: string): void {
  const input = field(host, name);
  input.value = value;
  input.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

function choose(fixture: ComponentFixture<unknown>, host: HTMLElement, value: string): void {
  const select = field(host, 'Name') as HTMLSelectElement;
  select.value = value;
  select.dispatchEvent(new Event('change'));
  fixture.detectChanges();
}

function confirm(host: HTMLElement): HTMLButtonElement {
  return host.querySelector('[data-interop-workflow-user-confirm]') as HTMLButtonElement;
}

function offered(host: HTMLElement): string[] {
  return [...(field(host, 'Name') as HTMLSelectElement).options].map((option) => option.value).filter((value) => value !== '');
}

describe('the New workflow user and Edit dialog', () => {
  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
    TestBed.resetTestingModule();
  });

  it('as New workflow user, draws the name as a choice, the full name and the flag under their published words, and needs a name', async () => {
    const { fixture, host, sent } = await mount();
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopWorkflowUserAddAction);
    expect(host.querySelector('[data-interop-workflow-user-help]')?.textContent?.trim()).toBe(STRINGS.interopWorkflowUserHelp);
    const labels = ['Name', 'FullName'].map((name) => host.querySelector(`label[for="${field(host, name).id}"]`)?.textContent?.trim());
    expect(labels).toEqual([STRINGS.tableColumnName, STRINGS.userColumnFullName]);
    expect(field(host, 'Name').tagName).toBe('SELECT');
    expect(host.querySelector(`label[for="${field(host, 'IsActive').id}"]`)).toBeNull();
    expect(field(host, 'IsActive').closest('label')?.textContent?.trim()).toBe(STRINGS.interopColumnActive);
    expect((field(host, 'IsActive') as HTMLInputElement).checked).toBe(true);
    expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    confirm(host).click();
    await settle(fixture);
    expect(sent.map((call) => call.path)).toEqual([INTEROP_WORKFLOW_USER_CHOICES_PATH]);
    choose(fixture, host, 'OcuP2417wA');
    expect(confirm(host).getAttribute('aria-disabled')).toBeNull();
  });

  it('offers the users of the instance the namespace does not already hold, a name held in another letter case counted as held', async () => {
    // Mutation (Rule 19): compare the names exactly rather than in any letter case -> `ADMIN` is still offered and this goes red.
    const { host, sent } = await mount({ held: ['ADMIN', 'SuperUser'] });
    expect(offered(host)).toEqual(['irisowner', 'OcuP2417wA']);
    expect(sent.map((call) => [call.path, call.scope])).toEqual([[INTEROP_WORKFLOW_USER_CHOICES_PATH, 'USER']]);
  });

  it('draws the sentence the instance gave when it would not list the users, and offers none', async () => {
    const { host } = await mount({ choices: { kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'You may not list the users.', detail: null } });
    expect(offered(host)).toEqual([]);
    const alert = host.querySelector('[data-interop-workflow-user-reason]') as HTMLElement;
    expect(alert.getAttribute('role')).toBe('alert');
    expect(alert.textContent?.trim()).toBe('You may not list the users.');
  });

  it('as New workflow user, posts the typed fields, the flag as a boolean, to the namespace given, and emits the name once the instance added it', async () => {
    const { fixture, host, sent } = await mount({ answer: { kind: 'ok', status: 201, body: { readBack: { verdict: 'matches' } } } });
    choose(fixture, host, 'OcuP2417wA');
    type(fixture, host, 'FullName', 'Ada Lovelace');
    const flag = field(host, 'IsActive') as HTMLInputElement;
    flag.checked = false;
    flag.dispatchEvent(new Event('change'));
    fixture.detectChanges();
    confirm(host).click();
    await settle(fixture);
    const posts = sent.filter((call) => call.path !== INTEROP_WORKFLOW_USER_CHOICES_PATH);
    expect(posts.map((call) => [call.path, call.scope])).toEqual([['/api/ocupilot/interop/workflow-users', 'USER']]);
    expect(JSON.parse(posts[0].body)).toEqual({ Name: 'OcuP2417wA', FullName: 'Ada Lovelace', IsActive: false });
    expect((fixture.componentInstance as Host).added).toEqual(['OcuP2417wA']);
    // An add states no deactivation sentence: a new user holds no task.
    expect(host.querySelector('[data-interop-workflow-user-inactive]')).toBeNull();
  });

  it('as Edit, titles the dialog by the user, holds the name read-only, reads no choices, and hands the values to the page without posting', async () => {
    // Mutation (Rule 19): make the name a choice in Edit -> the read-only assertions and the choices read go red.
    const initial: WorkflowUserValues = { name: 'OcuP2417wA', fullName: 'Ada', active: true };
    const { fixture, host, sent } = await mount({ workflowUser: 'OcuP2417wA', initial, wasActive: true });
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopCredentialEditTitle.replace('<name>', 'OcuP2417wA'));
    const name = field(host, 'Name') as HTMLInputElement;
    expect(name.tagName).toBe('INPUT');
    expect(name.readOnly).toBe(true);
    expect(name.getAttribute('aria-readonly')).toBe('true');
    expect(name.value).toBe('OcuP2417wA');
    expect((field(host, 'FullName') as HTMLInputElement).value).toBe('Ada');
    expect((field(host, 'IsActive') as HTMLInputElement).checked).toBe(true);
    type(fixture, host, 'FullName', 'Ada L');
    confirm(host).click();
    await settle(fixture);
    expect(sent).toEqual([]);
    const submitted = (fixture.componentInstance as Host).submitted;
    expect(submitted).toEqual([{ name: 'OcuP2417wA', fullName: 'Ada L', active: true }]);
    expect((fixture.componentInstance as Host).added).toEqual([]);
  });

  it('as Edit, says what an inactive user means once an active user is made inactive, and not before', async () => {
    // Mutation (Rule 19): show the sentence for a user who was inactive when the dialog opened -> the first assertion goes red.
    const inactive = await mount({ workflowUser: 'OcuP2417wA', initial: { name: 'OcuP2417wA', fullName: '', active: false }, wasActive: false });
    expect(inactive.host.querySelector('[data-interop-workflow-user-inactive]')).toBeNull();
    TestBed.resetTestingModule();
    for (const element of planted.splice(0)) element.remove();
    const { fixture, host } = await mount({ workflowUser: 'OcuP2417wA', initial: { name: 'OcuP2417wA', fullName: '', active: true }, wasActive: true });
    expect(host.querySelector('[data-interop-workflow-user-inactive]')).toBeNull();
    const flag = field(host, 'IsActive') as HTMLInputElement;
    flag.checked = false;
    flag.dispatchEvent(new Event('change'));
    await settle(fixture);
    expect(host.querySelector('[data-interop-workflow-user-inactive]')?.textContent?.trim()).toBe(STRINGS.interopWorkflowUserInactiveConsequence);
  });

  it('draws a refusal on a field under the field and names it by it, and emits nothing', async () => {
    const violation = { field: 'FullName', code: 'INTEROP.WORKFLOW.FULLNAME', reason: STRINGS.interopWorkflowUserRefusalFullName };
    const { fixture, host } = await mount({
      answer: { kind: 'error', status: 422, code: 'INTEROP.WORKFLOW.FULLNAME', reason: STRINGS.interopWorkflowUserRefusalFullName, detail: { violations: [violation] } },
    });
    choose(fixture, host, 'OcuP2417wA');
    type(fixture, host, 'FullName', 'x'.repeat(129));
    confirm(host).click();
    await settle(fixture);
    const input = field(host, 'FullName');
    const error = host.querySelector('[data-interop-workflow-user-violation="FullName"]') as HTMLElement;
    expect(error.textContent?.trim()).toBe(STRINGS.interopWorkflowUserRefusalFullName);
    expect(input.getAttribute('aria-invalid')).toBe('true');
    expect(input.getAttribute('aria-describedby')).toBe(error.id);
    expect(host.querySelector('[data-interop-workflow-user-reason]')).toBeNull();
    expect((fixture.componentInstance as Host).added).toEqual([]);
  });

  it('draws a refusal that names no field as the alert of the dialog', async () => {
    const { fixture, host } = await mount({
      answer: { kind: 'error', status: 409, code: 'INTEROP.WORKFLOW.SOURCECONTROL', reason: STRINGS.interopWorkflowUserRefusalSourceControl, detail: null },
    });
    choose(fixture, host, 'OcuP2417wA');
    confirm(host).click();
    await settle(fixture);
    const alert = host.querySelector('[data-interop-workflow-user-reason]') as HTMLElement;
    expect(alert.getAttribute('role')).toBe('alert');
    expect(alert.textContent?.trim()).toBe(STRINGS.interopWorkflowUserRefusalSourceControl);
    expect((fixture.componentInstance as Host).added).toEqual([]);
  });

  it('emits cancelled for Cancel, sending nothing', async () => {
    const { fixture, host, sent } = await mount();
    const cancel = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;
    cancel.click();
    await settle(fixture);
    expect((fixture.componentInstance as Host).cancelled).toBe(1);
    expect(sent.filter((call) => call.path !== INTEROP_WORKFLOW_USER_CHOICES_PATH)).toEqual([]);
  });
});

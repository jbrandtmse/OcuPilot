import { Component, signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { InteropWorkflowMemberDialog } from './interop-workflow-member-dialog';

/**
 * The Add member dialog (Story 24.17 Batch 3b): its published words, a User chosen among the workflow users the role does not already hold, a Rank
 * chosen from 1 to 5 that starts at 3, a button that stays unavailable until a user is chosen, the member posted to the namespace and the role it was
 * given with its rank as a number, the sentence an active user earns, and the server's two kinds of refusal drawn where each belongs.
 */

@Component({
  imports: [InteropWorkflowMemberDialog],
  template: `<app-interop-workflow-member-dialog
    [namespace]="namespace()"
    [role]="role()"
    [held]="held()"
    (added)="added.push($event)"
    (cancelled)="cancelled = cancelled + 1"
  />`,
})
class Host {
  readonly namespace = signal('USER');
  readonly role = signal('OcuP2417rA');
  readonly held = signal<readonly string[]>([]);
  readonly added: string[] = [];
  cancelled = 0;
}

const planted: HTMLElement[] = [];

const READ_PATH = '/api/ocupilot/screens/interop.workflowusers/read?maxRows=1000';

const USERS: JsonResult<unknown> = {
  kind: 'ok',
  status: 200,
  body: { rows: [{ Name: 'OcuP2417wA', IsActive: true }, { Name: 'OcuP2417wB', IsActive: false }, { Name: 'OcuP2417wC', IsActive: true }] },
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
  readonly users?: JsonResult<unknown>;
  readonly held?: readonly string[];
}

async function mount(options: MountOptions = {}) {
  TestBed.resetTestingModule();
  const sent: { path: string; scope: string | null | undefined; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      sent.push({ path, scope: init.scope, body: typeof init.body === 'string' ? init.body : '' });
      return (path === READ_PATH ? (options.users ?? USERS) : (options.answer ?? { kind: 'ok', status: 201, body: {} })) as JsonResult<T>;
    },
  };
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  const fixture = TestBed.createComponent(Host);
  fixture.componentInstance.held.set(options.held ?? []);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  return { fixture, host: fixture.nativeElement as HTMLElement, sent };
}

function field(host: HTMLElement, name: string): HTMLInputElement | HTMLSelectElement {
  return host.querySelector(`[data-interop-workflow-member-field="${name}"]`) as HTMLInputElement | HTMLSelectElement;
}

function choose(fixture: ComponentFixture<unknown>, host: HTMLElement, name: string, value: string): void {
  const select = field(host, name) as HTMLSelectElement;
  select.value = value;
  select.dispatchEvent(new Event('change'));
  fixture.detectChanges();
}

function typeTitle(fixture: ComponentFixture<unknown>, host: HTMLElement, value: string): void {
  const input = field(host, 'Title');
  input.value = value;
  input.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

function confirm(host: HTMLElement): HTMLButtonElement {
  return host.querySelector('[data-interop-workflow-member-confirm]') as HTMLButtonElement;
}

function options(host: HTMLElement, name: string): string[] {
  return [...(field(host, name) as HTMLSelectElement).options].map((option) => option.value).filter((value) => value !== '');
}

describe('the Add member dialog', () => {
  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
    TestBed.resetTestingModule();
  });

  it('draws the user and the rank as choices and the title as text under their published words, and needs a user', async () => {
    const { fixture, host, sent } = await mount();
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopWorkflowMemberAddAction);
    expect(host.querySelector('[data-interop-workflow-member-help]')?.textContent?.trim()).toBe(STRINGS.interopWorkflowMemberHelp);
    const labels = ['User', 'Ranking', 'Title'].map((name) => host.querySelector(`label[for="${field(host, name).id}"]`)?.textContent?.trim());
    expect(labels).toEqual([STRINGS.processColumnUser, STRINGS.interopWorkflowMemberColumnRank, STRINGS.interopPartnerFieldTitle]);
    expect(field(host, 'User').tagName).toBe('SELECT');
    expect(field(host, 'Ranking').tagName).toBe('SELECT');
    expect(field(host, 'Title').tagName).toBe('INPUT');
    expect(options(host, 'Ranking')).toEqual(['1', '2', '3', '4', '5']);
    expect((field(host, 'Ranking') as HTMLSelectElement).value).toBe('3');
    expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    confirm(host).click();
    await settle(fixture);
    expect(sent.map((call) => call.path)).toEqual([READ_PATH]);
    choose(fixture, host, 'User', 'OcuP2417wA');
    expect(confirm(host).getAttribute('aria-disabled')).toBeNull();
  });

  it("offers the workflow users of the namespace the role does not already hold, a name held in another letter case counted as held", async () => {
    // Mutation (Rule 19): pass no held names to the store -> the member is offered again and this goes red.
    const { host, sent } = await mount({ held: ['ocup2417wc'] });
    expect(options(host, 'User')).toEqual(['OcuP2417wA', 'OcuP2417wB']);
    expect(sent.map((call) => [call.path, call.scope])).toEqual([[READ_PATH, 'USER']]);
  });

  it('draws the sentence the instance gave when it would not list the users, and offers none', async () => {
    const { host } = await mount({ users: { kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'You may not list the users.', detail: null } });
    expect(options(host, 'User')).toEqual([]);
    const alert = host.querySelector('[data-interop-workflow-member-reason]') as HTMLElement;
    expect(alert.getAttribute('role')).toBe('alert');
    expect(alert.textContent?.trim()).toBe('You may not list the users.');
  });

  it('says what adding an active user does once one is chosen, and nothing for an inactive one', async () => {
    const { fixture, host } = await mount();
    expect(host.querySelector('[data-interop-workflow-member-active]')).toBeNull();
    choose(fixture, host, 'User', 'OcuP2417wA');
    expect(host.querySelector('[data-interop-workflow-member-active]')?.textContent?.trim()).toBe(STRINGS.interopWorkflowMemberAddConsequence);
    choose(fixture, host, 'User', 'OcuP2417wB');
    expect(host.querySelector('[data-interop-workflow-member-active]')).toBeNull();
  });

  it('posts the role, the chosen user, the rank as a number and the title to the namespace given, and emits the user once the instance added it', async () => {
    const { fixture, host, sent } = await mount({ answer: { kind: 'ok', status: 201, body: { readBack: { verdict: 'matches' } } } });
    choose(fixture, host, 'User', 'OcuP2417wA');
    choose(fixture, host, 'Ranking', '2');
    typeTitle(fixture, host, 'Lead');
    confirm(host).click();
    await settle(fixture);
    const posts = sent.filter((call) => call.path !== READ_PATH);
    expect(posts.map((call) => [call.path, call.scope])).toEqual([['/api/ocupilot/interop/workflow-members', 'USER']]);
    // Mutation (Rule 19): send no rank from the dialog -> this goes red.
    expect(JSON.parse(posts[0].body)).toEqual({ Role: 'OcuP2417rA', User: 'OcuP2417wA', Ranking: 2, Title: 'Lead' });
    expect((fixture.componentInstance as Host).added).toEqual(['OcuP2417wA']);
  });

  it('sends the default rank of 3 and no title when neither was changed', async () => {
    const { fixture, host, sent } = await mount();
    choose(fixture, host, 'User', 'OcuP2417wB');
    confirm(host).click();
    await settle(fixture);
    const posts = sent.filter((call) => call.path !== READ_PATH);
    expect(JSON.parse(posts[0].body)).toEqual({ Role: 'OcuP2417rA', User: 'OcuP2417wB', Ranking: 3 });
  });

  it('draws a refusal on a field under the field and names it by it, and emits nothing', async () => {
    const violation = { field: 'Title', code: 'INTEROP.WORKFLOW.MEMBERTITLE', reason: STRINGS.interopWorkflowMemberRefusalTitle };
    const { fixture, host } = await mount({
      answer: { kind: 'error', status: 422, code: 'INTEROP.WORKFLOW.MEMBERTITLE', reason: STRINGS.interopWorkflowMemberRefusalTitle, detail: { violations: [violation] } },
    });
    choose(fixture, host, 'User', 'OcuP2417wA');
    typeTitle(fixture, host, 'x'.repeat(129));
    confirm(host).click();
    await settle(fixture);
    const input = field(host, 'Title');
    const error = host.querySelector('[data-interop-workflow-member-violation="Title"]') as HTMLElement;
    expect(error.textContent?.trim()).toBe(STRINGS.interopWorkflowMemberRefusalTitle);
    expect(input.getAttribute('aria-invalid')).toBe('true');
    expect(input.getAttribute('aria-describedby')).toBe(error.id);
    expect(host.querySelector('[data-interop-workflow-member-reason]')).toBeNull();
    expect((fixture.componentInstance as Host).added).toEqual([]);
  });

  it('draws a refusal that names no field as the alert of the dialog', async () => {
    const { fixture, host } = await mount({
      answer: { kind: 'error', status: 409, code: 'INTEROP.WORKFLOW.SOURCECONTROL', reason: STRINGS.interopWorkflowUserRefusalSourceControl, detail: null },
    });
    choose(fixture, host, 'User', 'OcuP2417wA');
    confirm(host).click();
    await settle(fixture);
    const alert = host.querySelector('[data-interop-workflow-member-reason]') as HTMLElement;
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
    expect(sent.filter((call) => call.path !== READ_PATH)).toEqual([]);
  });
});

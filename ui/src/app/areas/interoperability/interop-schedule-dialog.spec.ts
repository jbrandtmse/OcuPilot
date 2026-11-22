import { Component, signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { InteropScheduleDialog } from './interop-schedule-dialog';
import { InteropScheduleStore, type ScheduleValues } from './interop-schedule.store';

/**
 * The New schedule spec and Edit dialog (Story 24.15): its published words in both modes, a button that stays unavailable until the name is typed,
 * the schedule spec posted to the namespace it was given with its flag as a boolean, an Edit that holds the name read-only and hands its values to
 * the page, and the server's two kinds of refusal drawn where each belongs.
 */

@Component({
  imports: [InteropScheduleDialog],
  template: `<app-interop-schedule-dialog
    [namespace]="namespace()"
    [schedule]="schedule()"
    (added)="added.push($event)"
    (submitted)="submitted.push($event)"
    (cancelled)="cancelled = cancelled + 1"
  />`,
})
class Host {
  readonly namespace = signal('USER');
  readonly schedule = signal<string | null>(null);
  readonly added: string[] = [];
  readonly submitted: ScheduleValues[] = [];
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

async function mount(answer: JsonResult<unknown>, schedule: string | null = null, initial: ScheduleValues | null = null) {
  TestBed.resetTestingModule();
  const sent: { path: string; scope: string | null | undefined; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      sent.push({ path, scope: init.scope, body: typeof init.body === 'string' ? init.body : '' });
      return answer as JsonResult<T>;
    },
  };
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  TestBed.inject(InteropScheduleStore).reset(initial);
  const fixture = TestBed.createComponent(Host);
  fixture.componentInstance.schedule.set(schedule);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await fixture.whenStable();
  return { fixture, host: fixture.nativeElement as HTMLElement, sent };
}

function field(host: HTMLElement, name: string): HTMLInputElement | HTMLTextAreaElement {
  return host.querySelector(`[data-interop-schedule-field="${name}"]`) as HTMLInputElement | HTMLTextAreaElement;
}

function type(fixture: ComponentFixture<unknown>, host: HTMLElement, name: string, value: string): void {
  const input = field(host, name);
  input.value = value;
  input.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

function confirm(host: HTMLElement): HTMLButtonElement {
  return host.querySelector('[data-interop-schedule-confirm]') as HTMLButtonElement;
}

describe('the New schedule spec and Edit dialog', () => {
  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
    TestBed.resetTestingModule();
  });

  it('as New schedule spec, draws the name, the schedule, the description and the flag under their published words, and needs a name', async () => {
    const { fixture, host, sent } = await mount({ kind: 'ok', status: 201, body: {} });
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopScheduleAddAction);
    expect(host.querySelector('[data-interop-schedule-help]')?.textContent?.trim()).toBe(STRINGS.interopScheduleHelp);
    const labels = ['Name', 'ScheduleSpec', 'Description'].map((name) => {
      const control = field(host, name);
      return host.querySelector(`label[for="${control.id}"]`)?.textContent?.trim();
    });
    expect(labels).toEqual([STRINGS.tableColumnName, STRINGS.taskDetailsSchedule, STRINGS.tableColumnDescription]);
    expect(field(host, 'Name').readOnly).toBe(false);
    expect(field(host, 'Description').tagName).toBe('TEXTAREA');
    const flag = field(host, 'Deployable') as HTMLInputElement;
    expect(flag.type).toBe('checkbox');
    expect(host.querySelector(`#${flag.getAttribute('aria-describedby')}`)?.textContent?.trim()).toBe(STRINGS.interopScheduleDeployableHelp);
    expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    confirm(host).click();
    await settle(fixture);
    expect(sent).toEqual([]);
    type(fixture, host, 'Name', 'OcuProbe2415SA');
    expect(confirm(host).getAttribute('aria-disabled')).toBeNull();
  });

  it('as New schedule spec, posts the typed fields, the flag as a boolean, to the namespace given, and emits the name once the instance added it', async () => {
    const { fixture, host, sent } = await mount({ kind: 'ok', status: 201, body: { readBack: { verdict: 'matches' } } });
    type(fixture, host, 'Name', 'OcuProbe2415SA');
    type(fixture, host, 'ScheduleSpec', 'START:*-*-*T08:00:00,STOP:*-*-*T17:00:00');
    type(fixture, host, 'Description', 'line one\nline two');
    const flag = field(host, 'Deployable') as HTMLInputElement;
    flag.checked = true;
    flag.dispatchEvent(new Event('change'));
    fixture.detectChanges();
    confirm(host).click();
    await settle(fixture);
    expect(sent.map((call) => [call.path, call.scope])).toEqual([['/api/ocupilot/interop/schedules', 'USER']]);
    const body = JSON.parse(sent[0].body) as Record<string, unknown>;
    expect(body['Name']).toBe('OcuProbe2415SA');
    expect(body['ScheduleSpec']).toBe('START:*-*-*T08:00:00,STOP:*-*-*T17:00:00');
    expect(body['Description']).toBe('line one\nline two');
    expect(body['Deployable']).toBe(true);
    expect((fixture.componentInstance as Host).added).toEqual(['OcuProbe2415SA']);
  });

  it('as Edit, titles the dialog by the schedule spec, holds the name read-only, and hands the values to the page without posting', async () => {
    // Mutation (Rule 19): make the name writable in Edit -> the read-only and `aria-readonly` assertions go red.
    const initial: ScheduleValues = { text: { Name: 'OcuProbe2415SA', ScheduleSpec: 'START:*-*-*T08:00:00', Description: 'd' }, deployable: true };
    const { fixture, host, sent } = await mount({ kind: 'ok', status: 200, body: {} }, 'OcuProbe2415SA', initial);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopCredentialEditTitle.replace('<name>', 'OcuProbe2415SA'));
    const name = field(host, 'Name') as HTMLInputElement;
    expect(name.readOnly).toBe(true);
    expect(name.getAttribute('aria-readonly')).toBe('true');
    expect(field(host, 'ScheduleSpec').value).toBe('START:*-*-*T08:00:00');
    expect((field(host, 'Deployable') as HTMLInputElement).checked).toBe(true);
    type(fixture, host, 'Name', 'Renamed');
    type(fixture, host, 'Description', '');
    confirm(host).click();
    await settle(fixture);
    expect(sent).toEqual([]);
    const submitted = (fixture.componentInstance as Host).submitted;
    expect(submitted).toHaveLength(1);
    expect(submitted[0].text['Name']).toBe('OcuProbe2415SA');
    expect(submitted[0].text['Description']).toBe('');
    expect(submitted[0].deployable).toBe(true);
    expect((fixture.componentInstance as Host).added).toEqual([]);
  });

  it('draws a refusal on a field under the field and names it by it, and emits nothing', async () => {
    const violation = { field: 'ScheduleSpec', code: 'INTEROP.SCHEDULE.SPEC', reason: STRINGS.interopScheduleRefusalSpec };
    const { fixture, host } = await mount({ kind: 'error', status: 422, code: 'INTEROP.SCHEDULE.SPEC', reason: STRINGS.interopScheduleRefusalSpec, detail: { violations: [violation] } });
    type(fixture, host, 'Name', 'OcuProbe2415SA');
    type(fixture, host, 'ScheduleSpec', 'FOO');
    confirm(host).click();
    await settle(fixture);
    const input = field(host, 'ScheduleSpec');
    const error = host.querySelector('[data-interop-schedule-violation="ScheduleSpec"]') as HTMLElement;
    expect(error.textContent?.trim()).toBe(STRINGS.interopScheduleRefusalSpec);
    expect(input.getAttribute('aria-invalid')).toBe('true');
    expect(input.getAttribute('aria-describedby')).toBe(error.id);
    expect(host.querySelector('[data-interop-schedule-reason]')).toBeNull();
    expect((fixture.componentInstance as Host).added).toEqual([]);
  });

  it('draws a refusal that names no field as the alert of the dialog', async () => {
    const { fixture, host } = await mount({ kind: 'error', status: 409, code: 'INTEROP.SCHEDULE.TAKEN', reason: STRINGS.interopScheduleRefusalTaken, detail: null });
    type(fixture, host, 'Name', 'OcuProbe2415SA');
    confirm(host).click();
    await settle(fixture);
    const alert = host.querySelector('[data-interop-schedule-reason]') as HTMLElement;
    expect(alert.getAttribute('role')).toBe('alert');
    expect(alert.textContent?.trim()).toBe(STRINGS.interopScheduleRefusalTaken);
    expect((fixture.componentInstance as Host).added).toEqual([]);
  });

  it('emits cancelled for Cancel, sending nothing', async () => {
    const { fixture, host, sent } = await mount({ kind: 'ok', status: 201, body: {} });
    const cancel = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;
    cancel.click();
    await settle(fixture);
    expect((fixture.componentInstance as Host).cancelled).toBe(1);
    expect(sent).toEqual([]);
  });
});

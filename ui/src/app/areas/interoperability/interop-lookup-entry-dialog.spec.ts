import { Component, signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { InteropLookupEntryDialog } from './interop-lookup-entry-dialog';

/**
 * The New table and Add entry dialog (Story 20.5): its published words in both modes, a button that stays unavailable
 * until the table (when it is new) and the key are typed, the entry posted to the namespace and table it was given, a
 * value that is a multi-line field and may be empty, and the server's two kinds of refusal drawn where each belongs.
 */

@Component({
  imports: [InteropLookupEntryDialog],
  template: `<app-interop-lookup-entry-dialog [namespace]="namespace()" [table]="table()" (added)="added.push($event)" (cancelled)="cancelled = cancelled + 1" />`,
})
class Host {
  readonly namespace = signal('USER');
  readonly table = signal<string | null>(null);
  readonly added: string[] = [];
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

async function mount(answer: JsonResult<unknown>, table: string | null = null) {
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
  const fixture = TestBed.createComponent(Host);
  fixture.componentInstance.table.set(table);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await fixture.whenStable();
  return { fixture, host: fixture.nativeElement as HTMLElement, sent };
}

function type(fixture: ComponentFixture<unknown>, host: HTMLElement, field: string, value: string): void {
  const input = host.querySelector(`[data-interop-lookup-${field}]`) as HTMLInputElement | HTMLTextAreaElement;
  input.value = value;
  input.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

function confirm(host: HTMLElement): HTMLButtonElement {
  return host.querySelector('[data-interop-lookup-confirm]') as HTMLButtonElement;
}

describe('the New table and Add entry dialog', () => {
  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
    TestBed.resetTestingModule();
  });

  it('as New table, asks for the table, the key and the value with the published words, says a table is created by its first entry, and needs a table and a key', async () => {
    const { fixture, host, sent } = await mount({ kind: 'ok', status: 201, body: {} });
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopLookupTableDialogTitle);
    expect(host.querySelector('[data-interop-lookup-new-table-help]')?.textContent?.trim()).toBe(STRINGS.interopLookupNewTableHelp);
    expect(host.querySelector('[data-interop-lookup-entry-help]')?.textContent?.trim()).toBe(STRINGS.interopLookupEntryHelp);
    const table = host.querySelector('input[data-interop-lookup-table]') as HTMLInputElement;
    expect(host.querySelector(`label[for="${table.id}"]`)?.textContent?.trim()).toBe(STRINGS.interopLookupFieldTable);
    expect(table.readOnly).toBe(false);
    const key = host.querySelector('input[data-interop-lookup-key]') as HTMLInputElement;
    expect(host.querySelector(`label[for="${key.id}"]`)?.textContent?.trim()).toBe(STRINGS.interopLookupColumnKey);
    const value = host.querySelector('textarea[data-interop-lookup-value]') as HTMLTextAreaElement;
    expect(host.querySelector(`label[for="${value.id}"]`)?.textContent?.trim()).toBe(STRINGS.errorLogColumnValue);
    expect(confirm(host).textContent?.trim()).toBe(STRINGS.interopLookupTableAddAction);
    expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    type(fixture, host, 'table', 'Probe.Table');
    expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    confirm(host).click();
    await settle(fixture);
    expect(sent).toEqual([]);
    type(fixture, host, 'key', 'ProbeKey');
    expect(confirm(host).getAttribute('aria-disabled')).toBeNull();
  });

  it('as New table, posts the typed table, key and value to the namespace given and emits the table once the instance added it', async () => {
    const { fixture, host, sent } = await mount({ kind: 'ok', status: 201, body: { readBack: { verdict: 'matches' } } });
    type(fixture, host, 'table', 'Probe.Table');
    type(fixture, host, 'key', 'ProbeKey');
    type(fixture, host, 'value', 'line one\nline two');
    confirm(host).click();
    await settle(fixture);
    expect(sent.map((call) => [call.path, call.scope, JSON.parse(call.body)])).toEqual([
      ['/api/ocupilot/interop/lookup-entries', 'USER', { Table: 'Probe.Table', Key: 'ProbeKey', Value: 'line one\nline two' }],
    ]);
    expect((fixture.componentInstance as Host).added).toEqual(['Probe.Table']);
  });

  it('as Add entry, shows the table fixed, asks only for the key and the value, and posts to that table', async () => {
    // Mutation (Rule 19): post the typed table in place of the one given -> the posted table is lost and this goes red.
    const { fixture, host, sent } = await mount({ kind: 'ok', status: 201, body: {} }, 'Route.Table');
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopLookupEntryDialogTitle);
    expect(host.querySelector('[data-interop-lookup-new-table-help]')).toBeNull();
    expect(host.querySelector('[data-interop-lookup-entry-help]')?.textContent?.trim()).toBe(STRINGS.interopLookupEntryHelp);
    const table = host.querySelector('input[data-interop-lookup-table]') as HTMLInputElement;
    expect(table.value).toBe('Route.Table');
    expect(table.readOnly).toBe(true);
    expect(table.getAttribute('aria-readonly')).toBe('true');
    expect(confirm(host).textContent?.trim()).toBe(STRINGS.interopLookupEntryAddAction);
    expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    type(fixture, host, 'key', 'ProbeKey');
    expect(confirm(host).getAttribute('aria-disabled')).toBeNull();
    confirm(host).click();
    await settle(fixture);
    expect(sent.map((call) => [call.scope, JSON.parse(call.body)])).toEqual([['USER', { Table: 'Route.Table', Key: 'ProbeKey', Value: '' }]]);
    expect((fixture.componentInstance as Host).added).toEqual(['Route.Table']);
  });

  it('as Add entry, keeps the button unavailable when the route names no table', async () => {
    const { fixture, host, sent } = await mount({ kind: 'ok', status: 201, body: {} }, '');
    type(fixture, host, 'key', 'ProbeKey');
    expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    confirm(host).click();
    await settle(fixture);
    expect(sent).toEqual([]);
  });

  it('keeps Enter in the value field a line break, and sends from a single-line field', async () => {
    // Mutation (Rule 19): bind `(keydown.enter)` on the value field -> a line break sends the entry and this goes red.
    const { fixture, host, sent } = await mount({ kind: 'ok', status: 201, body: {} }, 'Route.Table');
    type(fixture, host, 'key', 'ProbeKey');
    const value = host.querySelector('textarea[data-interop-lookup-value]') as HTMLTextAreaElement;
    const lineBreak = new KeyboardEvent('keydown', { key: 'Enter', bubbles: true, cancelable: true });
    value.dispatchEvent(lineBreak);
    await settle(fixture);
    expect(lineBreak.defaultPrevented).toBe(false);
    expect(sent).toEqual([]);
    (host.querySelector('input[data-interop-lookup-key]') as HTMLInputElement).dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true, cancelable: true }));
    await settle(fixture);
    expect(sent).toHaveLength(1);
  });

  it('describes each field only by elements it draws: by its refusal alone, and by nothing before it has one', async () => {
    const violation = { field: 'Value', code: 'INTEROP.LOOKUP.VALUE', reason: STRINGS.interopLookupRefusalValue };
    const { fixture, host } = await mount({ kind: 'error', status: 422, code: 'INTEROP.LOOKUP.VALUE', reason: STRINGS.interopLookupRefusalValue, detail: { violations: [violation] } }, 'Route.Table');
    const described = (): string[] =>
      [...host.querySelectorAll('[aria-describedby]')].flatMap((element) => (element.getAttribute('aria-describedby') ?? '').split(' ').filter((id) => id !== ''));
    expect(described()).toEqual([]);
    type(fixture, host, 'key', 'ProbeKey');
    confirm(host).click();
    await settle(fixture);
    const value = host.querySelector('textarea[data-interop-lookup-value]') as HTMLTextAreaElement;
    expect(value.getAttribute('aria-describedby')).toBe(host.querySelector('[data-interop-lookup-violation="Value"]')?.id);
    for (const id of described()) expect(document.getElementById(id), id).not.toBeNull();
  });

  it('draws a refusal on a field under the field and names it by it, and emits nothing', async () => {
    const violation = { field: 'Key', code: 'INTEROP.LOOKUP.KEY', reason: STRINGS.interopLookupRefusalKey };
    const { fixture, host } = await mount({ kind: 'error', status: 422, code: 'INTEROP.LOOKUP.KEY', reason: STRINGS.interopLookupRefusalKey, detail: { violations: [violation] } });
    type(fixture, host, 'table', 'Probe.Table');
    type(fixture, host, 'key', 'bad');
    confirm(host).click();
    await settle(fixture);
    const input = host.querySelector('input[data-interop-lookup-key]') as HTMLInputElement;
    const error = host.querySelector('[data-interop-lookup-violation="Key"]') as HTMLElement;
    expect(error.textContent?.trim()).toBe(STRINGS.interopLookupRefusalKey);
    expect(input.getAttribute('aria-invalid')).toBe('true');
    expect(input.getAttribute('aria-describedby')?.split(' ')).toContain(error.id);
    expect(host.querySelector('[data-interop-lookup-reason]')).toBeNull();
    expect((fixture.componentInstance as Host).added).toEqual([]);
  });

  it('draws a refusal on the table under the table field, as the new table\u2019s name', async () => {
    const violation = { field: 'Table', code: 'INTEROP.LOOKUP.TABLENAME', reason: STRINGS.interopLookupRefusalTableName };
    const { fixture, host } = await mount({ kind: 'error', status: 422, code: 'INTEROP.LOOKUP.TABLENAME', reason: STRINGS.interopLookupRefusalTableName, detail: { violations: [violation] } });
    type(fixture, host, 'table', 'Probe.Table');
    type(fixture, host, 'key', 'ProbeKey');
    confirm(host).click();
    await settle(fixture);
    expect(host.querySelector('[data-interop-lookup-violation="Table"]')?.textContent?.trim()).toBe(STRINGS.interopLookupRefusalTableName);
    expect(host.querySelector('input[data-interop-lookup-table]')?.getAttribute('aria-invalid')).toBe('true');
  });

  it('draws a refusal that names no field as the dialog\u2019s alert, and emits nothing', async () => {
    const { fixture, host } = await mount({ kind: 'error', status: 409, code: 'INTEROP.LOOKUP.TAKEN', reason: STRINGS.interopLookupRefusalTaken, detail: null }, 'Route.Table');
    type(fixture, host, 'key', 'ProbeKey');
    confirm(host).click();
    await settle(fixture);
    const alert = host.querySelector('[data-interop-lookup-reason]') as HTMLElement;
    expect(alert.getAttribute('role')).toBe('alert');
    expect(alert.textContent?.trim()).toBe(STRINGS.interopLookupRefusalTaken);
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

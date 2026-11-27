import { Component, signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { InteropHl7SchemaDialog } from './interop-hl7-schema-dialog';

/**
 * The New HL7 schema dialog (Story 24.18 Batch 1): its published words, a button that stays unavailable until a name is typed, a base chosen from the
 * schemas it is given plus none, the schema posted to the namespace it was given, and the server's two kinds of refusal drawn where each belongs.
 */

@Component({
  imports: [InteropHl7SchemaDialog],
  template: `<app-interop-hl7-schema-dialog [namespace]="namespace()" [bases]="bases()" (added)="added.push($event)" (cancelled)="cancelled = cancelled + 1" />`,
})
class Host {
  readonly namespace = signal('USER');
  readonly bases = signal<readonly string[]>(['2.3', '2.5.1']);
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

async function mount(answer: JsonResult<unknown> = { kind: 'ok', status: 201, body: {} }) {
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
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  return { fixture, host: fixture.nativeElement as HTMLElement, sent };
}

function field(host: HTMLElement, name: string): HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement {
  return host.querySelector(`[data-interop-hl7-schema-field="${name}"]`) as HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement;
}

function type(fixture: ComponentFixture<unknown>, host: HTMLElement, name: string, value: string): void {
  const input = field(host, name);
  input.value = value;
  input.dispatchEvent(new Event(name === 'Base' ? 'change' : 'input'));
  fixture.detectChanges();
}

function confirm(host: HTMLElement): HTMLButtonElement {
  return host.querySelector('[data-interop-hl7-schema-confirm]') as HTMLButtonElement;
}

describe('the New HL7 schema dialog', () => {
  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
    TestBed.resetTestingModule();
  });

  it('draws the name, the base and the description under their published words, offers none and the held schemas as the base, and needs a name', async () => {
    const { fixture, host, sent } = await mount();
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopHl7SchemaAddAction);
    expect(host.querySelector('[data-interop-hl7-schema-help]')?.textContent?.trim()).toBe(STRINGS.interopHl7Help);
    const labels = ['Name', 'Base', 'Description'].map((name) => host.querySelector(`label[for="${field(host, name).id}"]`)?.textContent?.trim());
    expect(labels).toEqual([STRINGS.tableColumnName, STRINGS.interopHl7ColumnBase, STRINGS.tableColumnDescription]);
    expect([...field(host, 'Base').querySelectorAll('option')].map((option) => option.textContent?.trim())).toEqual([STRINGS.sslVerifyPeerNone, '2.3', '2.5.1']);
    expect((field(host, 'Base') as HTMLSelectElement).value).toBe('');
    expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    confirm(host).click();
    await settle(fixture);
    expect(sent).toEqual([]);
    type(fixture, host, 'Name', 'OcuProbe2418b1');
    expect(confirm(host).getAttribute('aria-disabled')).toBeNull();
  });

  it('posts the typed fields to the namespace given and emits the name once the instance added it', async () => {
    // Mutation (Rule 19): drop `setBase` from the select's change handler -> the base is not sent and the body assertion goes red.
    const { fixture, host, sent } = await mount({ kind: 'ok', status: 201, body: { readBack: { verdict: 'matches' } } });
    type(fixture, host, 'Name', 'OcuProbe2418b1');
    type(fixture, host, 'Base', '2.5.1');
    type(fixture, host, 'Description', 'Probe schema');
    confirm(host).click();
    await settle(fixture);
    expect(sent.map((call) => [call.path, call.scope])).toEqual([['/api/ocupilot/interop/hl7-schemas', 'USER']]);
    expect(JSON.parse(sent[0].body)).toEqual({ Name: 'OcuProbe2418b1', Base: '2.5.1', Description: 'Probe schema' });
    expect((fixture.componentInstance as Host).added).toEqual(['OcuProbe2418b1']);
  });

  it('draws a refusal on a field under the field and names it by it, and emits nothing', async () => {
    const violation = { field: 'Base', code: 'INTEROP.HL7.BASE', reason: 'Choose a base schema this namespace holds, or none.' };
    const { fixture, host } = await mount({ kind: 'error', status: 422, code: 'INTEROP.HL7.BASE', reason: violation.reason, detail: { violations: [violation] } });
    type(fixture, host, 'Name', 'OcuProbe2418b1');
    type(fixture, host, 'Base', '2.3');
    confirm(host).click();
    await settle(fixture);
    const select = field(host, 'Base');
    const error = host.querySelector('[data-interop-hl7-schema-violation="Base"]') as HTMLElement;
    expect(error.textContent?.trim()).toBe(violation.reason);
    expect(select.getAttribute('aria-invalid')).toBe('true');
    expect(select.getAttribute('aria-describedby')).toBe(error.id);
    expect(host.querySelector('[data-interop-hl7-schema-reason]')).toBeNull();
    expect((fixture.componentInstance as Host).added).toEqual([]);
  });

  it('draws a refusal that names no field as the alert of the dialog', async () => {
    const reason = 'This namespace already has an HL7 schema with that name, in some letter case.';
    const { fixture, host } = await mount({ kind: 'error', status: 409, code: 'INTEROP.HL7.TAKEN', reason, detail: null });
    type(fixture, host, 'Name', 'OcuProbe2418b1');
    confirm(host).click();
    await settle(fixture);
    const alert = host.querySelector('[data-interop-hl7-schema-reason]') as HTMLElement;
    expect(alert.getAttribute('role')).toBe('alert');
    expect(alert.textContent?.trim()).toBe(reason);
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

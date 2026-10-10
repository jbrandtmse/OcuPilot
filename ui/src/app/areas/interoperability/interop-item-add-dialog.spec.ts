import { Component, signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { InteropItemAddDialog } from './interop-item-add-dialog';

/**
 * The Add item dialog (Story 20.3): its published words, an Add item that stays unavailable until the name and
 * the class are typed, the item posted to the production and namespace it was given, and the server's two kinds
 * of refusal drawn where each belongs.
 */

@Component({
  imports: [InteropItemAddDialog],
  template: `<app-interop-item-add-dialog [namespace]="namespace()" [production]="production()" (added)="added.push($event)" (cancelled)="cancelled = cancelled + 1" />`,
})
class Host {
  readonly namespace = signal('USER');
  readonly production = signal('Probe.Production');
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

async function mount(answer: JsonResult<unknown>) {
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
  await fixture.whenStable();
  return { fixture, host: fixture.nativeElement as HTMLElement, sent };
}

function type(fixture: ComponentFixture<unknown>, host: HTMLElement, field: string, value: string): void {
  const input = host.querySelector(`input[data-interop-item-add-${field}]`) as HTMLInputElement;
  input.value = value;
  input.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

function confirm(host: HTMLElement): HTMLButtonElement {
  return host.querySelector('[data-interop-item-add-confirm]') as HTMLButtonElement;
}

describe('the Add item dialog', () => {
  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
    TestBed.resetTestingModule();
  });

  it('is titled, labeled and hinted with the published words, states the pending update, and Add item needs a name and a class', async () => {
    const { fixture, host, sent } = await mount({ kind: 'ok', status: 201, body: {} });
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopItemAddTitle);
    expect(host.querySelector('[data-interop-item-add-pending]')?.textContent?.trim()).toBe(STRINGS.interopItemPendingConsequence);
    const name = host.querySelector('input[data-interop-item-add-name]') as HTMLInputElement;
    expect(host.querySelector(`label[for="${name.id}"]`)?.textContent?.trim()).toBe(STRINGS.tableColumnName);
    expect(host.querySelector(`#${name.getAttribute('aria-describedby')}`)?.textContent?.trim()).toBe(STRINGS.interopItemAddNameHint);
    const klass = host.querySelector('input[data-interop-item-add-class]') as HTMLInputElement;
    expect(host.querySelector(`label[for="${klass.id}"]`)?.textContent?.trim()).toBe(STRINGS.interopItemColumnClass);
    expect(host.querySelector(`#${klass.getAttribute('aria-describedby')}`)?.textContent?.trim()).toBe(STRINGS.interopItemAddClassHint);
    expect(confirm(host).textContent?.trim()).toBe(STRINGS.interopItemAddTitle);
    expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    type(fixture, host, 'name', 'ProbeNew');
    expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    confirm(host).click();
    await settle(fixture);
    expect(sent).toEqual([]);
    type(fixture, host, 'class', 'Probe.Op');
    expect(confirm(host).getAttribute('aria-disabled')).toBeNull();
  });

  it('posts the item to the production and namespace given and emits its name once the instance added it', async () => {
    const { fixture, host, sent } = await mount({ kind: 'ok', status: 201, body: { readBack: { verdict: 'matches' } } });
    type(fixture, host, 'name', 'ProbeNew');
    type(fixture, host, 'class', 'Probe.Op');
    type(fixture, host, 'pool', '3');
    confirm(host).click();
    await settle(fixture);
    expect(sent.map((call) => [call.path, call.scope, JSON.parse(call.body)])).toEqual([
      ['/api/ocupilot/interop/items', 'USER', { Production: 'Probe.Production', Name: 'ProbeNew', ClassName: 'Probe.Op', Enabled: false, PoolSize: 3 }],
    ]);
    expect((fixture.componentInstance as Host).added).toEqual(['ProbeNew']);
  });

  it('draws a refusal on a field under the field and names it by it, and emits nothing', async () => {
    const violation = { field: 'ClassName', code: 'INTEROP.ITEM.CLASS', reason: STRINGS.interopItemRefusalClass };
    const { fixture, host } = await mount({ kind: 'error', status: 422, code: 'INTEROP.ITEM.CLASS', reason: STRINGS.interopItemRefusalClass, detail: { violations: [violation] } });
    type(fixture, host, 'name', 'ProbeNew');
    type(fixture, host, 'class', 'No.Such.Class');
    confirm(host).click();
    await settle(fixture);
    const input = host.querySelector('input[data-interop-item-add-class]') as HTMLInputElement;
    const error = host.querySelector('[data-interop-item-add-violation="ClassName"]') as HTMLElement;
    expect(error.textContent?.trim()).toBe(STRINGS.interopItemRefusalClass);
    expect(input.getAttribute('aria-invalid')).toBe('true');
    expect(input.getAttribute('aria-describedby')?.split(' ')).toContain(error.id);
    expect(host.querySelector('[data-interop-item-add-reason]')).toBeNull();
    expect((fixture.componentInstance as Host).added).toEqual([]);
  });

  it('draws a refusal that names no field as the dialog\u2019s alert, and emits nothing', async () => {
    const { fixture, host } = await mount({ kind: 'error', status: 409, code: 'INTEROP.ITEM.TAKEN', reason: STRINGS.interopItemRefusalTaken, detail: null });
    type(fixture, host, 'name', 'ProbeOp');
    type(fixture, host, 'class', 'Probe.Op');
    confirm(host).click();
    await settle(fixture);
    const alert = host.querySelector('[data-interop-item-add-reason]') as HTMLElement;
    expect(alert.getAttribute('role')).toBe('alert');
    expect(alert.textContent?.trim()).toBe(STRINGS.interopItemRefusalTaken);
    expect((fixture.componentInstance as Host).added).toEqual([]);
  });
});

import { Component, signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { InteropItemCopyDialog } from './interop-item-copy-dialog';

/**
 * The Copy item dialog (Story 20.40): its published words, a Copy that stays unavailable until the name is typed, the
 * copy posted for the production, namespace and source it was given, and the server's two kinds of refusal drawn where
 * each belongs.
 */

@Component({
  imports: [InteropItemCopyDialog],
  template: `<app-interop-item-copy-dialog
    [namespace]="namespace()"
    [production]="production()"
    [source]="source()"
    (copied)="copied.push($event)"
    (cancelled)="cancelled = cancelled + 1"
  />`,
})
class Host {
  readonly namespace = signal('USER');
  readonly production = signal('Probe.Production');
  readonly source = signal('ProbeOp');
  readonly copied: string[] = [];
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

function typeName(fixture: ComponentFixture<unknown>, host: HTMLElement, value: string): void {
  const input = host.querySelector('input[data-interop-item-copy-name]') as HTMLInputElement;
  input.value = value;
  input.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

function confirm(host: HTMLElement): HTMLButtonElement {
  return host.querySelector('[data-interop-item-copy-confirm]') as HTMLButtonElement;
}

describe('the Copy item dialog', () => {
  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
    TestBed.resetTestingModule();
  });

  it('is titled, labeled and hinted with the published words, states the copy\u2019s consequence, and Copy needs a name', async () => {
    const { fixture, host, sent } = await mount({ kind: 'ok', status: 201, body: {} });
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopItemCopyTitle);
    expect(host.querySelector('[data-interop-item-copy-consequence]')?.textContent?.trim()).toBe(STRINGS.interopItemCopyConsequence);
    const name = host.querySelector('input[data-interop-item-copy-name]') as HTMLInputElement;
    expect(name.value).toBe('');
    expect(host.querySelector(`label[for="${name.id}"]`)?.textContent?.trim()).toBe(STRINGS.tableColumnName);
    expect(host.querySelector(`#${name.getAttribute('aria-describedby')}`)?.textContent?.trim()).toBe(STRINGS.interopItemAddNameHint);
    expect(confirm(host).textContent?.trim()).toBe(STRINGS.auditDatabaseCopyConfirm);
    expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    confirm(host).click();
    await settle(fixture);
    expect(sent).toEqual([]);
    typeName(fixture, host, 'ProbeCopy');
    expect(confirm(host).getAttribute('aria-disabled')).toBeNull();
  });

  it('posts the copy for the production, namespace and source given and emits the new name once the instance added it', async () => {
    const { fixture, host, sent } = await mount({ kind: 'ok', status: 201, body: { readBack: { verdict: 'matches' } } });
    typeName(fixture, host, 'ProbeCopy');
    confirm(host).click();
    await settle(fixture);
    expect(sent.map((call) => [call.path, call.scope, JSON.parse(call.body)])).toEqual([
      ['/api/ocupilot/interop/items/copy', 'USER', { Production: 'Probe.Production', Name: 'ProbeCopy', CopyFrom: 'ProbeOp' }],
    ]);
    expect((fixture.componentInstance as Host).copied).toEqual(['ProbeCopy']);
  });

  it('draws a refusal on the name under the field and names it by it, and emits nothing', async () => {
    const violation = { field: 'Name', code: 'INTEROP.ITEM.NAME', reason: STRINGS.interopItemRefusalName };
    const { fixture, host } = await mount({ kind: 'error', status: 422, code: 'INTEROP.ITEM.NAME', reason: STRINGS.interopItemRefusalName, detail: { violations: [violation] } });
    typeName(fixture, host, '-bad');
    confirm(host).click();
    await settle(fixture);
    const input = host.querySelector('input[data-interop-item-copy-name]') as HTMLInputElement;
    const error = host.querySelector('[data-interop-item-copy-violation="Name"]') as HTMLElement;
    expect(error.textContent?.trim()).toBe(STRINGS.interopItemRefusalName);
    expect(input.getAttribute('aria-invalid')).toBe('true');
    expect(input.getAttribute('aria-describedby')?.split(' ')).toContain(error.id);
    expect(host.querySelector('[data-interop-item-copy-reason]')).toBeNull();
    expect((fixture.componentInstance as Host).copied).toEqual([]);
  });

  it('draws a refusal that names no field as the dialog\u2019s alert, and emits nothing', async () => {
    const { fixture, host } = await mount({ kind: 'error', status: 409, code: 'INTEROP.ITEM.TAKEN', reason: STRINGS.interopItemRefusalTaken, detail: null });
    typeName(fixture, host, 'ProbeOp');
    confirm(host).click();
    await settle(fixture);
    const alert = host.querySelector('[data-interop-item-copy-reason]') as HTMLElement;
    expect(alert.getAttribute('role')).toBe('alert');
    expect(alert.textContent?.trim()).toBe(STRINGS.interopItemRefusalTaken);
    expect((fixture.componentInstance as Host).copied).toEqual([]);
  });
});

import { Component, signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { DocDbCreateDialog } from './docdb-create-dialog';

/**
 * The Create document database dialog (Story 19.17, AC4): its published words, a Create that stays
 * unavailable on a blank name, the name posted to the namespace it was given, and the server's two
 * kinds of refusal drawn where each belongs.
 */

@Component({
  imports: [DocDbCreateDialog],
  template: `<app-docdb-create-dialog [namespace]="namespace()" (created)="created.push($event)" (cancelled)="cancelled = cancelled + 1" />`,
})
class Host {
  readonly namespace = signal('USER');
  readonly created: string[] = [];
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

function type(fixture: ComponentFixture<unknown>, host: HTMLElement, value: string): void {
  const input = host.querySelector('input[data-docdb-create-name]') as HTMLInputElement;
  input.value = value;
  input.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

function confirm(host: HTMLElement): HTMLButtonElement {
  return host.querySelector('[data-docdb-create-confirm]') as HTMLButtonElement;
}

describe('the Create document database dialog', () => {
  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
    TestBed.resetTestingModule();
  });

  it('is titled, labeled and hinted with the published words, and Create is unavailable on a blank name', async () => {
    const { fixture, host, sent } = await mount({ kind: 'ok', status: 201, body: {} });
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.explorerDocDbCreateTitle);
    const input = host.querySelector('input[data-docdb-create-name]') as HTMLInputElement;
    expect(host.querySelector(`label[for="${input.id}"]`)?.textContent?.trim()).toBe(STRINGS.tableColumnName);
    const hint = host.querySelector(`#${input.getAttribute('aria-describedby')}`);
    expect(hint?.textContent?.trim()).toBe(STRINGS.explorerDocDbCreateHint);
    expect(confirm(host).textContent?.trim()).toBe(STRINGS.explorerDocDbCreateTitle);
    expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    type(fixture, host, '   ');
    confirm(host).click();
    await settle(fixture);
    expect(sent).toEqual([]);
  });

  it('AC4: Create posts the name to the namespace given and emits it once the instance created it', async () => {
    const { fixture, host, sent } = await mount({ kind: 'ok', status: 201, body: { name: 'OcuProbe1917A', readBack: { verdict: 'matches' } } });
    type(fixture, host, 'OcuProbe1917A');
    expect(confirm(host).getAttribute('aria-disabled')).toBeNull();
    confirm(host).click();
    await settle(fixture);
    expect(sent.map((call) => [call.path, call.scope, call.body])).toEqual([['/api/ocupilot/explorer/docdb', 'USER', '{"Name":"OcuProbe1917A"}']]);
    expect((fixture.componentInstance as Host).created).toEqual(['OcuProbe1917A']);
  });

  it('AC4: a refusal on Name is drawn under the field and named by it, and nothing is emitted', async () => {
    const violation = { field: 'Name', code: 'DOCDB.NAME.MAPPED', reason: STRINGS.explorerDocDbNameMapped };
    const { fixture, host } = await mount({ kind: 'error', status: 422, code: 'DOCDB.NAME.MAPPED', reason: STRINGS.explorerDocDbNameMapped, detail: { violations: [violation] } });
    type(fixture, host, 'Ens.OcuProbe1917A');
    confirm(host).click();
    await settle(fixture);
    const input = host.querySelector('input[data-docdb-create-name]') as HTMLInputElement;
    const error = host.querySelector('[data-docdb-create-violation]') as HTMLElement;
    expect(error.textContent?.trim()).toBe(STRINGS.explorerDocDbNameMapped);
    expect(input.getAttribute('aria-invalid')).toBe('true');
    expect(input.getAttribute('aria-describedby')?.split(' ')).toContain(error.id);
    expect(host.querySelector('[data-docdb-create-reason]')).toBeNull();
    expect((fixture.componentInstance as Host).created).toEqual([]);
  });

  it('a refusal that names no field is the dialog\u2019s alert, and nothing is emitted', async () => {
    const { fixture, host } = await mount({ kind: 'error', status: 409, code: 'DOCDB.SERVICE.DISABLED', reason: STRINGS.explorerDocDbServiceDisabled, detail: null });
    type(fixture, host, 'OcuProbe1917A');
    confirm(host).click();
    await settle(fixture);
    const alert = host.querySelector('[data-docdb-create-reason]') as HTMLElement;
    expect(alert.getAttribute('role')).toBe('alert');
    expect(alert.textContent?.trim()).toBe(STRINGS.explorerDocDbServiceDisabled);
    expect((fixture.componentInstance as Host).created).toEqual([]);
  });
});

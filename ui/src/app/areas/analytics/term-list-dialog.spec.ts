import { Component, signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { TermListDialog } from './term-list-dialog';

/**
 * Edit term list (Story 24.2): the dialog sends nothing until the header the instance holds has filled it, so a header read that fails or
 * has not answered never sends a blank header over the list; once filled, it sends every member it read, the hide-value flag included.
 */

@Component({
  imports: [TermListDialog],
  template: `<app-term-list-dialog [namespace]="'USER'" [target]="target()" (done)="done = done + 1" />`,
})
class Host {
  readonly target = signal<string | null>('Probe.List');
  done = 0;
}

interface Sent {
  readonly path: string;
  readonly method: string;
  readonly body: Record<string, unknown>;
}

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 2));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(header: JsonResult<unknown>) {
  TestBed.resetTestingModule();
  const sent: Sent[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      sent.push({ path, method, body: typeof init.body === 'string' ? (JSON.parse(init.body) as Record<string, unknown>) : {} });
      if (method === 'GET') return header as JsonResult<T>;
      return { kind: 'ok', status: 200, body: { action: 'updated', target: { type: 'term-list', scope: 'USER', id: 'Probe.List' } } } as JsonResult<T>;
    },
  };
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: ScreenStores, useValue: new ScreenStores({ account: stubAccountPreferences() }) },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: ScopeService, useValue: { namespace: () => 'USER' } as unknown as ScopeService },
    ],
  });
  const fixture = TestBed.createComponent(Host);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  return { fixture, host: fixture.nativeElement as HTMLElement, sent };
}

function confirm(host: HTMLElement): HTMLButtonElement {
  return host.querySelector('[data-term-list-confirm]') as HTMLButtonElement;
}

function writes(sent: readonly Sent[]): Sent[] {
  return sent.filter((entry) => entry.method === 'POST');
}

describe('Edit term list', () => {
  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
    TestBed.resetTestingModule();
  });

  it('sends nothing while the header read has failed, so a blank form never replaces the list', async () => {
    const { fixture, host, sent } = await mount({ kind: 'error', status: 404, code: 'PORT.NOTFOUND', reason: 'gone', detail: null } as JsonResult<unknown>);
    expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    confirm(host).click();
    await settle(fixture);
    expect(writes(sent)).toEqual([]);
  });

  it('once the header has filled it, sends every member it read, the hide-value flag included', async () => {
    const { fixture, host, sent } = await mount({
      kind: 'ok',
      status: 200,
      body: { Name: 'Probe.List', Caption: 'Cap', Description: 'Desc', Pattern: '*x', SubjectArea: 'Sales', Fields: ['Region'], HideValue: true },
    });
    expect(confirm(host).getAttribute('aria-disabled')).toBeNull();
    confirm(host).click();
    await settle(fixture);
    const posted = writes(sent);
    expect(posted.length).toBe(1);
    expect(posted[0].body['values']).toEqual({ Caption: 'Cap', Description: 'Desc', Pattern: '*x', SubjectArea: 'Sales', Fields: '["Region"]', HideValue: 'true' });
  });
});

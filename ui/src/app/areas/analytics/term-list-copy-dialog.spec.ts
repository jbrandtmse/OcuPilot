import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { STRINGS } from '../../core/strings';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { TermListCopyDialog } from './term-list-copy-dialog';

/**
 * Copy term list (Story 24.10): the dialog sends the row action `copy` on the source with the one value its tool declares, only once a name
 * is typed; an applied copy emits the name it gave, and a refusal is drawn as the server sent it -- a rule on the field, any other sentence above it.
 */

@Component({
  imports: [TermListCopyDialog],
  template: `<app-term-list-copy-dialog [namespace]="'USER'" [source]="'Probe.List'" (done)="done.push($event)" />`,
})
class Host {
  readonly done: string[] = [];
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

async function mount(answer: JsonResult<unknown>) {
  TestBed.resetTestingModule();
  const sent: Sent[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      sent.push({ path, method: init.method ?? 'GET', body: typeof init.body === 'string' ? (JSON.parse(init.body) as Record<string, unknown>) : {} });
      return answer as JsonResult<T>;
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

function type(fixture: ComponentFixture<unknown>, host: HTMLElement, text: string): void {
  const input = host.querySelector('[data-term-list-copy-name]') as HTMLInputElement;
  input.value = text;
  input.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

function confirm(host: HTMLElement): HTMLButtonElement {
  return host.querySelector('[data-term-list-copy-confirm]') as HTMLButtonElement;
}

describe('Copy term list', () => {
  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
    TestBed.resetTestingModule();
  });

  it('is titled by the source, sends nothing until a name is typed, then sends the copy action with the new name and emits it', async () => {
    // Mutation (Rule 19): send the copy action under another value name than `NewName` -> the sent-values assertion goes red.
    const { fixture, host, sent } = await mount({ kind: 'ok', status: 200, body: { action: 'created', target: { type: 'term-list', scope: 'USER', id: 'Probe.List' } } });
    expect(host.textContent).toContain(STRINGS.analyticsTermListCopyTitle.replace('<name>', 'Probe.List'));
    expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    confirm(host).click();
    await settle(fixture);
    expect(sent).toEqual([]);
    type(fixture, host, 'Probe.Copy');
    expect(confirm(host).getAttribute('aria-disabled')).toBeNull();
    confirm(host).click();
    await settle(fixture);
    const posted = sent.filter((entry) => entry.method === 'POST');
    expect(posted.length).toBe(1);
    expect(posted[0].body).toEqual({ action: 'copy', id: 'Probe.List', values: { NewName: 'Probe.Copy' } });
    expect((fixture.componentInstance as Host).done).toEqual(['Probe.Copy']);
  });

  it('draws a rule on the name under the field and any other sentence above it, and emits nothing', async () => {
    // Mutation (Rule 19): read the violation of field `Name` no more -> the rule leg goes red.
    const rule = await mount({
      kind: 'error',
      status: 422,
      code: 'ANALYTICS.TERMLIST.NAME',
      reason: STRINGS.analyticsRefusalTermListName,
      detail: { violations: [{ field: 'Name', code: 'ANALYTICS.TERMLIST.NAME', reason: STRINGS.analyticsRefusalTermListName }] },
    } as JsonResult<unknown>);
    type(rule.fixture, rule.host, 'x');
    confirm(rule.host).click();
    await settle(rule.fixture);
    expect(rule.host.querySelector('[data-term-list-copy-violation]')?.textContent).toContain(STRINGS.analyticsRefusalTermListName);
    expect((rule.fixture.componentInstance as Host).done).toEqual([]);
    const taken = await mount({ kind: 'error', status: 409, code: 'ANALYTICS.TERMLIST.TAKEN', reason: STRINGS.analyticsRefusalTermListTaken, detail: null } as JsonResult<unknown>);
    type(taken.fixture, taken.host, 'Probe.List');
    confirm(taken.host).click();
    await settle(taken.fixture);
    expect(taken.host.querySelector('[data-term-list-copy-reason]')?.textContent).toContain(STRINGS.analyticsRefusalTermListTaken);
    expect(taken.host.querySelector('[data-term-list-copy-violation]')).toBeNull();
  });
});

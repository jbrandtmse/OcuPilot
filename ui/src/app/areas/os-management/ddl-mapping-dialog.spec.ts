import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { DDL_MAPPING_ENTITY, DDL_MAPPING_PATH, DdlMappingDialog } from './ddl-mapping-dialog';

/**
 * The New mapping dialog (Story 21.13): its published words, a button that stays unavailable until both fields are typed, the name and the
 * datatype posted as typed to the Save route, the server's two kinds of refusal drawn where each belongs, and the one change event an accepted
 * create publishes.
 */

@Component({
  imports: [DdlMappingDialog],
  template: `<app-ddl-mapping-dialog (added)="added.push($event)" (cancelled)="cancelled = cancelled + 1" />`,
})
class Host {
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
  const sent: { path: string; scope: string | null | undefined; method: string; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      sent.push({ path, scope: init.scope, method: init.method ?? 'GET', body: typeof init.body === 'string' ? init.body : '' });
      return answer as JsonResult<T>;
    },
  };
  const bus = new ChangeBus();
  const events: ChangeEvent[] = [];
  bus.subscribe((event) => events.push(event));
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: bus },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  const fixture = TestBed.createComponent(Host);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await fixture.whenStable();
  return { fixture, host: fixture.nativeElement as HTMLElement, sent, events };
}

function field(host: HTMLElement, name: string): HTMLInputElement {
  return host.querySelector(`[data-ddl-mapping-field="${name}"]`) as HTMLInputElement;
}

function type(fixture: ComponentFixture<unknown>, host: HTMLElement, name: string, value: string): void {
  const input = field(host, name);
  input.value = value;
  input.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

function confirm(host: HTMLElement): HTMLButtonElement {
  return host.querySelector('[data-ddl-mapping-confirm]') as HTMLButtonElement;
}

describe('the New mapping dialog', () => {
  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
    TestBed.resetTestingModule();
  });

  it('draws its title, the datatype sentence and the two labelled fields, and needs both before it sends anything', async () => {
    const { fixture, host, sent } = await mount({ kind: 'ok', status: 201, body: {} });
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.ddlMappingDialogTitle);
    expect(host.querySelector('[data-ddl-mapping-help]')?.textContent?.trim()).toBe(STRINGS.configAcceptsDatatype);
    expect(host.querySelector(`label[for="${field(host, 'Name').id}"]`)?.textContent?.trim()).toBe(STRINGS.tableColumnName);
    expect(host.querySelector(`label[for="${field(host, 'Value').id}"]`)?.textContent?.trim()).toBe(STRINGS.ddlMappingColumnDatatype);
    expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    confirm(host).click();
    await settle(fixture);
    expect(sent).toEqual([]);
    type(fixture, host, 'Name', 'ZZOCU1');
    expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    type(fixture, host, 'Value', '%Library.String(MAXLEN=%1)');
    expect(confirm(host).getAttribute('aria-disabled')).toBeNull();
  });

  // Mutation (Rule 19): post to another path or trim the typed name -> the path or the body assertion goes red.
  it('posts the name and the datatype as typed to the Save route, publishes one created event for the mapping the server names and emits the name', async () => {
    const { fixture, host, sent, events } = await mount({ kind: 'ok', status: 201, body: { id: 'ZZOCU1', target: { type: DDL_MAPPING_ENTITY, scope: 'instance', id: 'ZZOCU1' }, readBack: { verdict: 'matches' } } });
    type(fixture, host, 'Name', ' ZZOCU1 ');
    type(fixture, host, 'Value', '%Library.String(MAXLEN=%1)');
    confirm(host).click();
    await settle(fixture);
    expect(sent.map((call) => [call.method, call.path, call.scope])).toEqual([['POST', DDL_MAPPING_PATH, undefined]]);
    expect(JSON.parse(sent[0].body)).toEqual({ Name: ' ZZOCU1 ', Value: '%Library.String(MAXLEN=%1)' });
    expect(events.map((event) => `${event.type}/${event.scope}/${event.id}/${event.action}`)).toEqual([`${DDL_MAPPING_ENTITY}/instance/ZZOCU1/created`]);
    expect((fixture.componentInstance as Host).added).toEqual([' ZZOCU1 ']);
  });

  it('draws a violation under the field it names, keeps what was typed, and publishes nothing', async () => {
    const reason = 'A name is 1 to 64 characters, with no =, comma, *, ^, control character, or space at either end.';
    const { fixture, host, events } = await mount({
      kind: 'error',
      status: 422,
      code: 'AGENT.VALIDATION',
      reason,
      detail: { violations: [{ field: 'Name', code: 'CONFIG.MAPPING.NAME', reason }] },
    } as JsonResult<unknown>);
    type(fixture, host, 'Name', 'ZZ*OCU');
    type(fixture, host, 'Value', '%Library.String');
    confirm(host).click();
    await settle(fixture);
    expect(host.querySelector('[data-ddl-mapping-violation="Name"]')?.textContent?.trim()).toBe(reason);
    expect(field(host, 'Name').getAttribute('aria-invalid')).toBe('true');
    expect(host.querySelector('[data-ddl-mapping-reason]')).toBeNull();
    expect(field(host, 'Name').value).toBe('ZZ*OCU');
    expect(events).toEqual([]);
    type(fixture, host, 'Name', 'ZZOCU1');
    expect(host.querySelector('[data-ddl-mapping-violation="Name"]')).toBeNull();
  });

  // Mutation (Rule 19): drop the envelope reason from `refuse` -> a held name shows nothing and this goes red.
  it('shows a name the instance already holds above the fields as the envelope\u2019s own sentence', async () => {
    const reason = STRINGS.configMappingTaken;
    const { fixture, host, events } = await mount({ kind: 'error', status: 409, code: 'CONFIG.MAPPING.TAKEN', reason, detail: null } as JsonResult<unknown>);
    type(fixture, host, 'Name', 'ZZOCU1');
    type(fixture, host, 'Value', '%Library.String');
    confirm(host).click();
    await settle(fixture);
    expect(host.querySelector('[data-ddl-mapping-reason]')?.textContent?.trim()).toBe(reason);
    expect(host.querySelector('[data-ddl-mapping-violation]')).toBeNull();
    expect(events).toEqual([]);
    expect((fixture.componentInstance as Host).added).toEqual([]);
  });

  it('emits cancelled on Cancel, sending nothing', async () => {
    const { fixture, host, sent } = await mount({ kind: 'ok', status: 201, body: {} });
    const cancel = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;
    cancel.click();
    await settle(fixture);
    expect((fixture.componentInstance as Host).cancelled).toBe(1);
    expect(sent).toEqual([]);
  });
});

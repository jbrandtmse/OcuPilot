import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { ListPage } from '../../shell/list-page';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { REST_API_CREATE_ACTION, REST_API_LIST, RestApiListPage } from './rest-api-list.page';

/**
 * The REST API explorer page (Story 18.34): the shared list page is replaced by an empty stand-in, so
 * only this page's own wiring runs -- the Create it registers beside the shell handler's Delete, and
 * the dialog that Create opens in the shell's namespace and closes once the instance built the service.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const planted: HTMLElement[] = [];

const TEXT = '{"swagger": "2.0", "info": {"title": "probe", "version": "1"}, "paths": {}}';

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 3; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 2));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

function mount() {
  TestBed.resetTestingModule();
  const sent: { path: string; scope: string | null | undefined; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      sent.push({ path, scope: init.scope, body: typeof init.body === 'string' ? init.body : '' });
      return { kind: 'ok', status: 201, body: { name: 'OcuProbe1832A', readBack: { verdict: 'matches' } } } as JsonResult<T>;
    },
  };
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: ScreenStores, useValue: new ScreenStores({ account: stubAccountPreferences() }) },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: ScopeService, useValue: { namespace: () => 'USER' } as unknown as ScopeService },
    ],
  });
  TestBed.overrideComponent(RestApiListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const fixture = TestBed.createComponent(RestApiListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, sent, actions: TestBed.inject(ScreenActions) };
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the REST API explorer page', () => {
  it('registers Create beside the handler\u2019s Delete, and Create opens the dialog in the shell\u2019s namespace and closes it once the service is built', async () => {
    // Mutation (Rule 19): drop this page's `actions.register` of `create` -> the first assertion goes red.
    const { fixture, host, actions, sent } = mount();
    expect(actions.has(REST_API_LIST, REST_API_CREATE_ACTION)).toBe(true);
    expect(actions.has(REST_API_LIST, 'delete')).toBe(true);
    expect(host.querySelector('app-rest-service-create-dialog')).toBeNull();
    actions.run(REST_API_LIST, REST_API_CREATE_ACTION);
    await settle(fixture);
    const name = host.querySelector('input[data-rest-service-create-name]') as HTMLInputElement;
    name.value = 'OcuProbe1832A';
    name.dispatchEvent(new Event('input'));
    const text = host.querySelector('textarea[data-rest-service-create-document]') as HTMLTextAreaElement;
    text.value = TEXT;
    text.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    (host.querySelector('[data-rest-service-create-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(sent.map((call) => [call.path, call.scope, JSON.parse(call.body)])).toEqual([['/api/ocupilot/rest-service', 'USER', { Name: 'OcuProbe1832A', Document: TEXT }]]);
    expect(host.querySelector('app-rest-service-create-dialog')).toBeNull();
  });

  it('opens one dialog however often Create is run, and Cancel closes it without posting', async () => {
    const { fixture, host, actions, sent } = mount();
    actions.run(REST_API_LIST, REST_API_CREATE_ACTION);
    actions.run(REST_API_LIST, REST_API_CREATE_ACTION);
    await settle(fixture);
    expect(host.querySelectorAll('app-rest-service-create-dialog').length).toBe(1);
    (host.querySelector('.ocu-dialog-actions .ocu-button-secondary') as HTMLButtonElement).click();
    await settle(fixture);
    expect(host.querySelector('app-rest-service-create-dialog')).toBeNull();
    expect(sent).toEqual([]);
  });
});

import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { INTEROP_LOOKUP_TABLE_ADD_ACTION, INTEROP_LOOKUP_TABLE_LIST, InteropLookupTableListPage } from './interop-lookup-table-list.page';

/**
 * The Lookup tables page (Story 20.5). The shared list page is replaced by an empty stand-in, so only this page's own
 * wiring runs: the one action it registers after the shell's handler, the New table dialog it opens, the entry that
 * dialog posts to the namespace the shell is scoped to, and the change event an accepted add publishes. The handler,
 * the stores and the bus are real; only the server's answers are stubbed.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const LIST = SCREENS.find((screen) => screen.descriptor === INTEROP_LOOKUP_TABLE_LIST)!;

const ROWS = [{ Name: 'Probe.Table', Modified: '2026-10-11 09:00:00' }];

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 2));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

interface Call {
  readonly path: string;
  readonly scope: string | null | undefined;
  readonly body: string;
}

function mount(answer: JsonResult<unknown> = { kind: 'ok', status: 201, body: {} }) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, scope: init.scope, body: init.body ?? '' });
      return answer as JsonResult<T>;
    },
  };
  const bus = new ChangeBus();
  const events: ChangeEvent[] = [];
  bus.subscribe((event) => events.push(event));
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: bus },
      { provide: ScreenStores, useValue: stores },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: ScopeService, useValue: { loaded: () => true, namespace: () => 'USER', subscribe: () => () => {} } as unknown as ScopeService },
    ],
  });
  TestBed.overrideComponent(InteropLookupTableListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(LIST.descriptor, LIST.refreshRates);
  store.applyTick(ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(InteropLookupTableListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, calls, events, actions: TestBed.inject(ScreenActions), handler: TestBed.inject(ScreenActionHandler) };
}

function type(fixture: ComponentFixture<unknown>, host: HTMLElement, field: string, value: string): void {
  const input = host.querySelector(`[data-interop-lookup-${field}]`) as HTMLInputElement | HTMLTextAreaElement;
  input.value = value;
  input.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Lookup tables page', () => {
  it('declares the list this page hosts, with New table as its primary action and Delete and the four transfer actions as its row actions', () => {
    expect(LIST.primaryAction?.id).toBe(INTEROP_LOOKUP_TABLE_ADD_ACTION);
    expect(LIST.rowActions.map((action) => action.id)).toEqual(['delete', 'export', 'export-browser', 'import', 'import-local']);
  });

  // Mutation (Rule 19): drop this page's `actions.register` of `add` -> the first assertion goes red.
  it('registers New table beside the handler\'s Delete, and opens the dialog in New table mode', async () => {
    const { fixture, host, actions, calls } = mount();
    expect(actions.has(INTEROP_LOOKUP_TABLE_LIST, INTEROP_LOOKUP_TABLE_ADD_ACTION)).toBe(true);
    expect(actions.has(INTEROP_LOOKUP_TABLE_LIST, 'delete')).toBe(true);
    expect(host.querySelector('app-interop-lookup-entry-dialog')).toBeNull();
    actions.run(INTEROP_LOOKUP_TABLE_LIST, INTEROP_LOOKUP_TABLE_ADD_ACTION);
    await settle(fixture);
    expect(calls).toHaveLength(0);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopLookupTableDialogTitle);
    expect((host.querySelector('input[data-interop-lookup-table]') as HTMLInputElement).readOnly).toBe(false);
  });

  it('posts the new table\'s first entry to the namespace the shell is scoped to, closes, and publishes the created event', async () => {
    const id = 'Probe.Table\u0001ProbeKey';
    const { fixture, host, actions, calls, events } = mount({ kind: 'ok', status: 201, body: { id, target: { type: 'lookup-entry', scope: 'USER', id } } });
    actions.run(INTEROP_LOOKUP_TABLE_LIST, INTEROP_LOOKUP_TABLE_ADD_ACTION);
    await settle(fixture);
    type(fixture, host, 'table', 'Probe.Table');
    type(fixture, host, 'key', 'ProbeKey');
    type(fixture, host, 'value', 'a value');
    (host.querySelector('[data-interop-lookup-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(calls.map((call) => [call.path, call.scope, JSON.parse(call.body)])).toEqual([
      ['/api/ocupilot/interop/lookup-entries', 'USER', { Table: 'Probe.Table', Key: 'ProbeKey', Value: 'a value' }],
    ]);
    expect(host.querySelector('app-interop-lookup-entry-dialog')).toBeNull();
    expect(events.map((event) => [event.type, event.id, event.action, event.tool])).toEqual([['lookup-entry', id, 'created', 'interop.lookupentries.add']]);
  });

  it('types the table\'s name before Delete, states that every entry goes, and sends the table\'s name as the id', async () => {
    // Mutation (Rule 19): drop the list's DESTRUCTIVE_CONSEQUENCES entry -> Delete registers no handler and the first assertion goes red.
    const deleted: JsonResult<unknown> = { kind: 'ok', status: 200, body: { action: 'deleted', target: { type: 'lookup-table', scope: 'USER', id: 'Probe.Table' } } };
    const { fixture, store, actions, handler, calls, events } = mount(deleted);
    expect(actions.has(INTEROP_LOOKUP_TABLE_LIST, 'delete')).toBe(true);
    store.setSelection(['Probe.Table']);
    actions.run(INTEROP_LOOKUP_TABLE_LIST, 'delete');
    await settle(fixture);
    expect(handler.pending()?.kind).toBe('typed-name');
    expect(handler.pending()?.name).toBe('Probe.Table');
    expect(handler.pending()?.consequence).toBe(STRINGS.interopLookupDeleteConsequence);
    expect(calls).toHaveLength(0);
    handler.confirmPending();
    await settle(fixture);
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${LIST.toolIdentifier}/action`);
    expect(JSON.parse(calls[0].body)).toEqual({ action: 'delete', id: 'Probe.Table' });
    expect(events.map((event) => `${event.action} ${event.type} ${event.id}`)).toEqual(['deleted lookup-table Probe.Table']);
  });

  it('opens no New table dialog over a Delete dialog', async () => {
    const { fixture, host, store, actions } = mount();
    store.setSelection(['Probe.Table']);
    actions.run(INTEROP_LOOKUP_TABLE_LIST, 'delete');
    await settle(fixture);
    actions.run(INTEROP_LOOKUP_TABLE_LIST, INTEROP_LOOKUP_TABLE_ADD_ACTION);
    await settle(fixture);
    expect(host.querySelector('app-interop-lookup-entry-dialog')).toBeNull();
  });

  // Mutation (Rule 19): drop `(cancelled)="onClose()"` from the page's template -> the dialog stays and this goes red.
  it('closes on Cancel, sending nothing and publishing nothing, and opens again afterwards', async () => {
    const { fixture, host, actions, calls, events } = mount();
    actions.run(INTEROP_LOOKUP_TABLE_LIST, INTEROP_LOOKUP_TABLE_ADD_ACTION);
    await settle(fixture);
    const cancel = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;
    cancel.click();
    await settle(fixture);
    expect(host.querySelector('app-interop-lookup-entry-dialog')).toBeNull();
    expect(calls).toHaveLength(0);
    expect(events).toEqual([]);
    actions.run(INTEROP_LOOKUP_TABLE_LIST, INTEROP_LOOKUP_TABLE_ADD_ACTION);
    await settle(fixture);
    expect(host.querySelector('app-interop-lookup-entry-dialog')).not.toBeNull();
  });
});

import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ListPage } from '../../shell/list-page';
import { COPY_MAPPINGS, NAMESPACE_LIST } from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { NamespaceListPage } from './namespace-list.page';

/**
 * The Namespaces list page's Copy mappings (Story 18.14, AC6). The shared list page is replaced by an
 * empty stand-in, so only this page's own wiring runs: the action it registers after the shell's
 * handler, the dialog over the rows the list's store holds, the one request the copy sends, and the
 * status line that follows it. The handler, the stores and the bus are real; only the server's
 * answers are stubbed.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const NAMESPACES = SCREENS.find((screen) => screen.descriptor === NAMESPACE_LIST)!;

const ROWS = [
  { Name: 'HSCUSTOM', Globals: 'HSCUSTOM', Routines: 'HSCUSTOM', TempGlobals: 'IRISTEMP' },
  { Name: 'OCUPROBE1814BA', Globals: 'USER', Routines: 'USER', TempGlobals: 'IRISTEMP' },
  { Name: 'OCUPROBE1814BB', Globals: 'USER', Routines: 'USER', TempGlobals: 'IRISTEMP' },
];

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
  readonly method: string;
  readonly body: string;
}

/** Mount the page; `answer` is what the copy's request resolves to, released by `release()`. */
function mount(answer: JsonResult<unknown>) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  let release: () => void = () => undefined;
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  });
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      await gate;
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
    ],
  });
  TestBed.overrideComponent(NamespaceListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(NAMESPACES.descriptor, NAMESPACES.refreshRates);
  store.applyTick(ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(NamespaceListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, calls, events, actions: TestBed.inject(ScreenActions), release: () => release() };
}

function line(host: HTMLElement): string {
  return host.querySelector('[data-copy-mappings-operation]')?.textContent?.trim() ?? '';
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Namespaces list page', () => {
  it('AC6: registers Copy mappings, whose dialog opens on the selected row and offers the rows the list read but that one', async () => {
    // Mutation (Rule 19): drop this page's `actions.register` of `copy-mappings` -> the first
    // assertion goes red, and no surface offers the action.
    const { fixture, host, store, actions, calls } = mount({ kind: 'ok', status: 200, body: {} });
    expect(actions.has(NAMESPACE_LIST, COPY_MAPPINGS)).toBe(true);
    expect(actions.has(NAMESPACE_LIST, 'delete')).toBe(true);
    actions.run(NAMESPACE_LIST, COPY_MAPPINGS);
    await settle(fixture);
    expect(host.querySelector('app-copy-mappings-dialog')).toBeNull();

    store.setSelection(['OCUPROBE1814BB']);
    actions.run(NAMESPACE_LIST, COPY_MAPPINGS);
    await settle(fixture);
    const select = host.querySelector('select[data-copy-mappings-source]') as HTMLSelectElement;
    expect(Array.from(select.options).map((option) => option.value)).toEqual(['HSCUSTOM', 'OCUPROBE1814BA']);
    expect(calls).toHaveLength(0);
    expect(line(host)).toBe('');
  });

  it('AC6: Copy sends one request naming the source, shows the running line while it is in flight, then the done line', async () => {
    const { fixture, host, store, actions, calls, events, release } = mount({
      kind: 'ok',
      status: 200,
      body: { action: 'updated', target: { type: 'namespace', scope: 'instance', id: 'OCUPROBE1814BB' } },
    });
    store.setSelection(['OCUPROBE1814BB']);
    actions.run(NAMESPACE_LIST, COPY_MAPPINGS);
    await settle(fixture);
    const select = host.querySelector('select[data-copy-mappings-source]') as HTMLSelectElement;
    select.value = 'OCUPROBE1814BA';
    select.dispatchEvent(new Event('change'));
    fixture.detectChanges();
    (host.querySelector('[data-copy-mappings-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(host.querySelector('app-copy-mappings-dialog')).toBeNull();
    const running = STRINGS.namespaceCopyMappingsRunning.split('<source>').join('OCUPROBE1814BA').split('<namespace>').join('OCUPROBE1814BB');
    expect(line(host).startsWith(running.split('<time>')[0])).toBe(true);
    expect(line(host)).toMatch(/\d{2}:\d{2}:\d{2}$/);

    release();
    await settle(fixture);
    expect(calls).toHaveLength(1);
    expect(calls[0].path).toBe(`/api/ocupilot/screens/${NAMESPACES.toolIdentifier}/action`);
    expect(calls[0].method).toBe('POST');
    expect(JSON.parse(calls[0].body)).toEqual({ action: COPY_MAPPINGS, id: 'OCUPROBE1814BB', values: { SourceNamespace: 'OCUPROBE1814BA' } });
    expect(line(host)).toBe(STRINGS.namespaceCopyMappingsDone.split('<source>').join('OCUPROBE1814BA').split('<namespace>').join('OCUPROBE1814BB'));
    expect(events.map(({ type, id, action }) => ({ type, id, action }))).toEqual([{ type: 'namespace', id: 'OCUPROBE1814BB', action: 'updated' }]);
  });

  it('AC6, AD-26: a copy the instance answers is still running reads as still running, never as done', async () => {
    // Mutation (Rule 19): drop the `continued()` branch from `onCopy` -> this reads the done line.
    const { fixture, host, store, actions, release } = mount({
      kind: 'ok',
      status: 200,
      body: { action: 'updated', target: { type: 'namespace', scope: 'instance', id: 'OCUPROBE1814BB' }, continues: true },
    });
    store.setSelection(['OCUPROBE1814BB']);
    actions.run(NAMESPACE_LIST, COPY_MAPPINGS);
    await settle(fixture);
    (host.querySelector('[data-copy-mappings-confirm]') as HTMLButtonElement).click();
    release();
    await settle(fixture);
    expect(line(host)).toBe(STRINGS.auditDatabaseStillRunning);
  });

  it('AD-39: a refused copy leaves no line and puts the envelope\u2019s sentence on the list', async () => {
    const reason = STRINGS.mappingRefusalOcuPilot;
    const { fixture, host, store, actions, release, events } = mount({ kind: 'error', status: 403, code: 'PROHIBITED.OCUPILOTMAPPING', reason, detail: null } as unknown as JsonResult<unknown>);
    store.setSelection(['HSCUSTOM']);
    actions.run(NAMESPACE_LIST, COPY_MAPPINGS);
    await settle(fixture);
    (host.querySelector('[data-copy-mappings-confirm]') as HTMLButtonElement).click();
    release();
    await settle(fixture);
    expect(line(host)).toBe('');
    expect(store.refusal()).toBe(reason);
    expect(events).toHaveLength(0);
  });

  it('Cancel closes the dialog and sends nothing, and leaving the page takes the action with it', async () => {
    const { fixture, host, store, actions, calls } = mount({ kind: 'ok', status: 200, body: {} });
    store.setSelection(['OCUPROBE1814BB']);
    actions.run(NAMESPACE_LIST, COPY_MAPPINGS);
    await settle(fixture);
    (host.querySelector('.ocu-dialog-actions .ocu-button-secondary') as HTMLButtonElement).click();
    await settle(fixture);
    expect(host.querySelector('app-copy-mappings-dialog')).toBeNull();
    expect(calls).toHaveLength(0);
    fixture.destroy();
    expect(actions.has(NAMESPACE_LIST, COPY_MAPPINGS)).toBe(false);
  });
});

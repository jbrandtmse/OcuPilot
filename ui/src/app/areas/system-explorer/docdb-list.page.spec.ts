import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import type { Fault } from '../../core/fault';
import { OverlayStack } from '../../core/overlay-stack';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { ScreenActions, actionLabel } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { STRINGS } from '../../core/strings';
import { ListPage } from '../../shell/list-page';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { DOCDB_CREATE_ACTION, DOCDB_LIST, DOCDB_SERVICE_DISABLED, DocDbListPage } from './docdb-list.page';

/**
 * The Document databases page (Story 19.17): the shared list page is replaced by an empty stand-in,
 * so only this page's own wiring runs -- the Create it registers beside the shell handler's Drop, the
 * dialog that Create opens in the shell's namespace, and the status strip it draws while the bound
 * read was refused because the DocDB service is disabled. The refresh service is a stub whose bound
 * descriptor and last fault each test sets.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

class StubRefresh {
  bound = '';

  last: Fault | null = null;

  private readonly listeners = new Set<() => void>();

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  descriptor(): string {
    return this.bound;
  }

  fault(): Fault | null {
    return this.last;
  }

  set(descriptor: string, code: string | null): void {
    this.bound = descriptor;
    this.last = code === null ? null : ({ kind: 'refused', status: 409, code, path: '/api/ocupilot/screens' } as unknown as Fault);
    for (const listener of [...this.listeners]) listener();
  }
}

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 3; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 2));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

function mount() {
  TestBed.resetTestingModule();
  const sent: { path: string; scope: string | null | undefined }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      sent.push({ path, scope: init.scope });
      return { kind: 'ok', status: 201, body: { name: 'OcuProbe1917A', readBack: { verdict: 'matches' } } } as JsonResult<T>;
    },
  };
  const refresh = new StubRefresh();
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: ScreenStores, useValue: new ScreenStores({ account: stubAccountPreferences() }) },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: RefreshService, useValue: refresh as unknown as RefreshService },
      { provide: ScopeService, useValue: { namespace: () => 'USER' } as unknown as ScopeService },
    ],
  });
  TestBed.overrideComponent(DocDbListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const fixture = TestBed.createComponent(DocDbListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, refresh, sent, actions: TestBed.inject(ScreenActions) };
}

function strip(host: HTMLElement): HTMLElement | null {
  return host.querySelector('[data-docdb-service-strip]');
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Document databases page', () => {
  it('AC4, AC5: registers Create beside the handler\u2019s Drop, and Create opens the dialog in the shell\u2019s namespace', async () => {
    // Mutation (Rule 19): drop this page's `actions.register` of `create` -> the first assertion goes red.
    const { fixture, host, actions, sent } = mount();
    expect(actions.has(DOCDB_LIST, DOCDB_CREATE_ACTION)).toBe(true);
    expect(actions.has(DOCDB_LIST, 'delete')).toBe(true);
    expect(actionLabel(DOCDB_LIST, 'delete')).toBe(STRINGS.explorerDocDbDropLabel);
    expect(host.querySelector('app-docdb-create-dialog')).toBeNull();
    actions.run(DOCDB_LIST, DOCDB_CREATE_ACTION);
    await settle(fixture);
    const input = host.querySelector('input[data-docdb-create-name]') as HTMLInputElement;
    input.value = 'OcuProbe1917A';
    input.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    (host.querySelector('[data-docdb-create-confirm]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(sent).toEqual([{ path: '/api/ocupilot/explorer/docdb', scope: 'USER' }]);
    expect(host.querySelector('app-docdb-create-dialog')).toBeNull();
  });

  it('AC2: states the published sentence while this screen\u2019s read was refused because the service is disabled, and only then', async () => {
    // Mutation (Rule 19): compare the fault code with any other -> the strip never draws and this goes red.
    const { fixture, host, refresh } = mount();
    expect(strip(host)).toBeNull();
    refresh.set(DOCDB_LIST, DOCDB_SERVICE_DISABLED);
    await settle(fixture);
    expect(strip(host)?.textContent?.trim()).toBe(STRINGS.explorerDocDbServiceDisabled);
    expect(strip(host)?.getAttribute('role')).toBe('status');
    refresh.set(DOCDB_LIST, 'PORT.ACCESSDENIED');
    await settle(fixture);
    expect(strip(host)).toBeNull();
    refresh.set('OcuPilot.Screen.Descriptor.ExplorerClassList', DOCDB_SERVICE_DISABLED);
    await settle(fixture);
    expect(strip(host)).toBeNull();
    refresh.set(DOCDB_LIST, null);
    await settle(fixture);
    expect(strip(host)).toBeNull();
  });
});

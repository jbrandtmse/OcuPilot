import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../core/api';
import { ChangeBus } from '../core/change-bus';
import type { ConnectivityService } from '../core/connectivity';
import { NavigationService } from '../core/navigation';
import { OverlayStack } from '../core/overlay-stack';
import { PreferenceStore } from '../core/preferences';
import { RefreshService } from '../core/refresh';
import { ScopeService } from '../core/scope';
import { ScreenActions } from '../core/screen-actions';
import { ScreenStores } from '../core/screen-store';
import type { ScreenDeclaration } from '../core/screens.generated';
import { tableDeclaration } from '../testing/table-declaration';
import { ListPage } from './list-page';

/**
 * The list page wired end to end over stubs of the two things an instance supplies -- the URL's
 * screen and the HTTP answer: the real `RefreshService`, `ScreenStores` and `createScreenRead` bind,
 * read, tick and re-read, and the real `DataTable` renders (AC6, AC8).
 */

function memoryStorage() {
  const map = new Map<string, string>();
  return {
    getItem: (key: string) => map.get(key) ?? null,
    setItem: (key: string, value: string) => {
      map.set(key, value);
    },
    removeItem: (key: string) => {
      map.delete(key);
    },
  };
}

const named = (...names: string[]) => names.map((name) => ({ Name: name, NameSpace: 'USER', Count: 1, Enabled: true, Note: 'n' }));

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 20));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

const planted: HTMLElement[] = [];

async function mount(declaration: ScreenDeclaration | null, initialRows: unknown[], scopeLoaded = true) {
  TestBed.resetTestingModule();
  let answerRows = initialRows;
  const paths: string[] = [];
  const api = {
    requestJson: async <T,>(path: string): Promise<JsonResult<T>> => {
      paths.push(path);
      return { kind: 'ok', status: 200, body: { fields: [], rows: answerRows, truncated: false } as T };
    },
  };
  const scheduled: (() => void)[] = [];
  const bus = new ChangeBus();
  const stores = new ScreenStores({ preferences: new PreferenceStore({ storage: memoryStorage() }) });
  const refresh = new RefreshService({
    stores,
    connectivity: { retryWhenReachable: () => {} } as unknown as ConnectivityService,
    bus,
    namespace: () => 'HSCUSTOM',
    schedule: (run) => scheduled.push(run),
  });
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: NavigationService, useValue: { screenForUrl: () => declaration } as unknown as NavigationService },
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: RefreshService, useValue: refresh },
      { provide: ScreenStores, useValue: stores },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: OverlayStack, useValue: new OverlayStack() },
      {
        provide: ScopeService,
        useValue: { loaded: () => scopeLoaded, namespace: () => 'HSCUSTOM', subscribe: () => () => {} } as unknown as ScopeService,
      },
    ],
  });
  await TestBed.inject(Router).navigateByUrl('/web-applications/probe?ns=HSCUSTOM');
  const fixture = TestBed.createComponent(ListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  return {
    fixture,
    refresh,
    stores,
    bus,
    paths,
    setRows: (next: unknown[]) => (answerRows = next),
    fireTick: async () => {
      scheduled[scheduled.length - 1]();
      await settle(fixture);
    },
    host: () => fixture.nativeElement as HTMLElement,
  };
}

const rowNames = (host: HTMLElement) =>
  Array.from(host.querySelectorAll('.ocu-data-table-body [role="row"]')).map((row) =>
    row.querySelector('.ocu-data-table-link')?.textContent?.trim()
  );

describe('the list page', () => {
  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
  });

  it('binds the declared read, reads it once through createScreenRead, and renders its rows', async () => {
    const declaration = tableDeclaration();
    const page = await mount(declaration, named('A', 'B'));
    expect(page.refresh.descriptor()).toBe(declaration.descriptor);
    expect(page.paths).toEqual(['/api/ocupilot/screens/stub/read?maxRows=1000']);
    expect(rowNames(page.host())).toEqual(['A', 'B']);
  });

  it('AC6: a tick updates the rows in place, keeps the active row by key, and the grid keeps DOM focus', async () => {
    const declaration = tableDeclaration({ refreshes: true, refreshRates: [10] });
    const page = await mount(declaration, named('A', 'B', 'C'));
    const grid = page.host().querySelector('[role="grid"]') as HTMLElement;
    grid.focus();
    grid.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown', bubbles: true }));
    grid.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown', bubbles: true }));
    await settle(page.fixture);
    const store = page.stores.for(declaration.descriptor, [10]);
    expect(store.active()).toBe('B');

    page.refresh.setRate(10);
    page.setRows(named('A0', 'A', 'B', 'C'));
    await page.fireTick();

    expect(page.paths.length).toBe(2);
    expect(rowNames(page.host())).toEqual(['A', 'A0', 'B', 'C']);
    expect(page.host().querySelector('[role="grid"]')).toBe(grid);
    expect(store.active()).toBe('B');
    expect(store.selection()).toEqual(['B']);
    const active = page.host().querySelector('.ocu-data-table-row-active') as HTMLElement;
    expect(active.querySelector('.ocu-data-table-link')?.textContent?.trim()).toBe('B');
    expect(grid.getAttribute('aria-activedescendant')).toBe(active.id);
    expect(document.activeElement).toBe(grid);
  });

  it('AC8: a changed event for the list entity type and scope issues one read and the row renders changed', async () => {
    const declaration = tableDeclaration();
    const page = await mount(declaration, named('A', 'B'));
    const before = page.paths.length;

    page.bus.publish({ kind: 'changed', type: 'web-application', scope: 'HSCUSTOM', id: 'B' });
    await settle(page.fixture);

    expect(page.paths.length).toBe(before + 1);
    const changed = page.host().querySelector('.ocu-data-table-row-changed') as HTMLElement;
    expect(changed.querySelector('.ocu-data-table-link')?.textContent?.trim()).toBe('B');
    expect(changed.querySelector('.ocu-data-table-changed-tag')).not.toBeNull();
  });

  it('before the namespace list arrives the page reads nothing, and the scope resolving reads once', async () => {
    // Mutation (Rule 19): read now whether or not the scope has loaded -> the first assertion goes red.
    const page = await mount(tableDeclaration(), named('A'), false);
    expect(page.paths).toEqual([]);
    expect(page.refresh.descriptor()).toBe(tableDeclaration().descriptor);

    page.refresh.noteScopeChanged();
    await settle(page.fixture);
    expect(page.paths).toEqual(['/api/ocupilot/screens/stub/read?maxRows=1000']);
    expect(rowNames(page.host())).toEqual(['A']);
  });

  it('destroying the page leaves a binding another screen has made since', async () => {
    // Mutation (Rule 19): unbind on destroy unconditionally -> the other screen loses its binding, red.
    const page = await mount(tableDeclaration(), named('A'));
    const other = tableDeclaration({ descriptor: 'OcuPilot.Screen.Descriptor.Other' });
    page.refresh.bind(other, async () => ({ kind: 'ok', rows: [], truncated: false }));
    page.fixture.destroy();
    expect(page.refresh.descriptor()).toBe(other.descriptor);
  });

  it('a list declaration with no read renders no table, and destroying the page lets go of the binding', async () => {
    const none = await mount(tableDeclaration({ read: null, table: null }), []);
    expect(none.host().querySelector('app-data-table')).toBeNull();
    expect(none.paths).toEqual([]);

    const bound = await mount(tableDeclaration(), named('A'));
    expect(bound.refresh.descriptor()).not.toBe('');
    bound.fixture.destroy();
    expect(bound.refresh.descriptor()).toBe('');
  });
});

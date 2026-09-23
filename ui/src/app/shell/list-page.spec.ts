import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../core/api';
import { ChangeBus } from '../core/change-bus';
import type { ConnectivityService } from '../core/connectivity';
import { NavigationService } from '../core/navigation';
import { OverlayStack } from '../core/overlay-stack';
import { RefreshService } from '../core/refresh';
import { ScopeService } from '../core/scope';
import { REFRESH_ACTION_ID, ScreenActions } from '../core/screen-actions';
import { ScreenStores } from '../core/screen-store';
import type { ScreenDeclaration } from '../core/screens.generated';
import { STRINGS } from '../core/strings';
import { tableDeclaration } from '../testing/table-declaration';
import { ListPage } from './list-page';
import { ScreenActionHandler } from './screen-action-handler';
import { stubAccountPreferences } from '../testing/account-preferences';

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

async function mount(
  declaration: ScreenDeclaration | null,
  initialRows: unknown[],
  scopeLoaded = true,
  url = '/web-applications/probe?ns=HSCUSTOM'
) {
  TestBed.resetTestingModule();
  let answerRows = initialRows;
  let answerBanner = '';
  let actionAnswer: unknown = {};
  const paths: string[] = [];
  const bodies: string[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: { body?: string } = {}): Promise<JsonResult<T>> => {
      paths.push(path);
      if (path.endsWith('/action')) bodies.push(init.body ?? '');
      // A row action's POST answers the verb and the triple (AD-14); every other path is a read.
      if (path.endsWith('/action')) return { kind: 'ok', status: 200, body: actionAnswer as T };
      return { kind: 'ok', status: 200, body: { fields: [], rows: answerRows, truncated: false, banner: answerBanner } as T };
    },
  };
  const scheduled: (() => void)[] = [];
  const bus = new ChangeBus();
  const stores = new ScreenStores({ account: stubAccountPreferences() });
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
      { provide: ChangeBus, useValue: bus },
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
  await TestBed.inject(Router).navigateByUrl(url);
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
    bodies,
    actions: TestBed.inject(ScreenActions),
    declaration,
    setRows: (next: unknown[]) => (answerRows = next),
    setBanner: (next: string) => (answerBanner = next),
    setActionAnswer: (next: unknown) => (actionAnswer = next),
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

  // Story 5.11, DW-1419: a list opened on its own route id selects that row on arrival. It is the
  // store's existing pending-selection path, so the agent's navigation and a change toast's
  // "Open in <screen>" reach it the same way, and the assertion is on `aria-selected` rather than
  // on the URL -- which is what DW-1419 names as the gap the two navigation specs left.
  //
  // Mutation (Rule 19): drop the `selectFromRoute` call in `ListPage`'s constructor -> the first
  // row below goes red while every URL assertion stays green; drop the one in its router
  // subscription -> the navigation half goes red, which is the path a change toast takes while
  // the list is already open.
  it('DW-1419: a list opened on its own route id selects that row, and an id naming none selects nothing', async () => {
    const declaration = tableDeclaration();
    const page = await mount(declaration, named('A', 'B', 'C'), true, '/web-applications/probe/B?ns=HSCUSTOM');

    const selected = Array.from(page.host().querySelectorAll('.ocu-data-table-body [role="row"]')).filter(
      (row) => row.getAttribute('aria-selected') === 'true'
    );
    expect(selected.length).toBe(1);
    expect(selected[0].querySelector('.ocu-data-table-link')?.textContent?.trim()).toBe('B');
    const store = page.stores.for(declaration.descriptor, declaration.refreshRates);
    expect(store.selection()).toEqual(['B']);

    // The second caller: a navigation that keeps this screen and names another row, which is what
    // a change toast's "Open in <screen>" does while the list is already open. Angular reuses the
    // component across that hop, so the constructor does not run again and only the router
    // subscription can move the selection.
    await TestBed.inject(Router).navigateByUrl('/web-applications/probe/C?ns=HSCUSTOM');
    await settle(page.fixture);
    const moved = Array.from(page.host().querySelectorAll('.ocu-data-table-body [role="row"]')).filter(
      (row) => row.getAttribute('aria-selected') === 'true'
    );
    expect(moved.length).toBe(1);
    expect(moved[0].querySelector('.ocu-data-table-link')?.textContent?.trim()).toBe('C');
    expect(store.selection()).toEqual(['C']);

    const absent = await mount(declaration, named('A', 'B', 'C'), true, '/web-applications/probe/Z?ns=HSCUSTOM');
    expect(rowNames(absent.host())).toEqual(['A', 'B', 'C']);
    expect(
      Array.from(absent.host().querySelectorAll('.ocu-data-table-body [role="row"]')).filter(
        (row) => row.getAttribute('aria-selected') === 'true'
      ).length
    ).toBe(0);
    expect(absent.host().querySelector('[role="alert"]')).toBeNull();
  });

  // Story 5.11 code review: the subscription above runs on every navigation that resolves to this
  // screen, not only on one that changes the id -- a namespace switch keeps the path and rewrites
  // only `?ns=`. Re-asserting the route's id there would replace a row the user had selected by
  // hand, on every list screen, which before this story had no such subscription at all.
  //
  // Mutation (Rule 19): drop the `id === previous` early return in `ListPage.selectFromRoute` ->
  // the first expectation below goes red, reading `['C']` for `['A']`; drop the
  // `clearPendingSelection` arm -> the second goes red, keeping C selected on the bare route.
  it('leaves a hand-made selection alone when a navigation keeps the route id, and clears it when the id goes away', async () => {
    const declaration = tableDeclaration();
    const page = await mount(declaration, named('A', 'B', 'C'), true, '/web-applications/probe/C?ns=HSCUSTOM');
    const store = page.stores.for(declaration.descriptor, declaration.refreshRates);
    expect(store.selection()).toEqual(['C']);

    store.setSelection(['A']);
    await settle(page.fixture);
    await TestBed.inject(Router).navigateByUrl('/web-applications/probe/C?ns=USER');
    await settle(page.fixture);
    expect(store.pendingSelection()).toBe('');
    expect(store.selection()).toEqual(['A']);

    await TestBed.inject(Router).navigateByUrl('/web-applications/probe?ns=USER');
    await settle(page.fixture);
    expect(store.pendingSelection()).toBe('');
  });

  it('AC8: a changed event for the list entity type and scope issues one read and the row renders changed', async () => {
    const declaration = tableDeclaration();
    const page = await mount(declaration, named('A', 'B'));
    const before = page.paths.length;

    page.bus.publish({ kind: 'changed', type: 'web-application', scope: 'HSCUSTOM', id: 'B', action: 'updated' });
    await settle(page.fixture);

    expect(page.paths.length).toBe(before + 1);
    const changed = page.host().querySelector('.ocu-data-table-row-changed') as HTMLElement;
    expect(changed.querySelector('.ocu-data-table-link')?.textContent?.trim()).toBe('B');
    expect(changed.querySelector('.ocu-data-table-changed-tag')).not.toBeNull();

    // Story 5.7: the change is announced once, politely, naming the row and what happened. The
    // refresh stamp and every silent tick stay unannounced, which is what keeps auto-refresh
    // silent (EXPERIENCE.md's accessibility floor).
    const announcement = page.host().querySelector('.ocu-data-table-announcement') as HTMLElement;
    expect(announcement.getAttribute('role')).toBe('status');
    expect(announcement.textContent?.trim()).toBe('Updated: B updated');
  });

  it('Story 5.7: a created row arrives highlighted and selected, and an updated one leaves the caret alone', async () => {
    // Mutation (Rule 19): drop `applyPendingSelection` from `DataTable.sync` -> the selection
    // assertion goes red while the highlight stays green, which is what separates "the row is
    // marked" from "the caret is on the row the user has not seen".
    const declaration = tableDeclaration();
    const page = await mount(declaration, named('A', 'B'));
    const store = page.stores.for(declaration.descriptor, []);
    store.setSelection(['A']);
    store.setActive('A');

    page.setRows(named('A', 'B', 'C'));
    page.bus.publish({ kind: 'changed', type: 'web-application', scope: 'HSCUSTOM', id: 'C', action: 'created' });
    await settle(page.fixture);

    expect(rowNames(page.host())).toEqual(['A', 'B', 'C']);
    expect(store.selection()).toEqual(['C']);
    expect(store.active()).toBe('C');
    const changed = page.host().querySelector('.ocu-data-table-row-changed') as HTMLElement;
    expect(changed.querySelector('.ocu-data-table-link')?.textContent?.trim()).toBe('C');

    // An update of another row marks it and moves nothing.
    page.bus.publish({ kind: 'changed', type: 'web-application', scope: 'HSCUSTOM', id: 'A', action: 'updated' });
    await settle(page.fixture);
    expect(store.selection()).toEqual(['C']);
  });

  it('Story 5.7: a deleted row leaves, and the selection it held clears', async () => {
    // The clear is `table-model.reconcile`'s, which this exercises through the real store and the
    // real table rather than by calling it -- a selected key absent from the new row set is what
    // a delete looks like from the view's side.
    const declaration = tableDeclaration();
    const page = await mount(declaration, named('A', 'B'));
    const store = page.stores.for(declaration.descriptor, []);
    store.setSelection(['B']);
    store.setActive('B');

    page.setRows(named('A'));
    page.bus.publish({ kind: 'changed', type: 'web-application', scope: 'HSCUSTOM', id: 'B', action: 'deleted' });
    await settle(page.fixture);

    expect(rowNames(page.host())).toEqual(['A']);
    expect(store.selection()).toEqual([]);
  });

  it('a confirmed delete leaves focus on the row that took its place; a cancel returns it to the opener', async () => {
    // The opener stands for a command-bar button, which outlives the row it acted on: focus must
    // not go back there once the write has removed the row. Through the real handler, dialog,
    // store and table -- only the transport is stubbed.
    //
    // Mutation (Rule 19): drop the `focusGrid()` call from `ListPage.onConfirmDestructive` -> the
    // dialog returns focus to the opener and the first `activeElement` assertion goes red.
    const declaration = tableDeclaration({
      descriptor: 'OcuPilot.Screen.Descriptor.WebAppList',
      rowActions: [{ id: 'delete', selfProtection: 'serves-ocupilot' }],
    });
    const page = await mount(declaration, named('A', 'B', 'C'));
    const store = page.stores.for(declaration.descriptor, declaration.refreshRates);
    const opener = document.createElement('button');
    document.body.appendChild(opener);
    planted.push(opener);
    const field = () => page.host().querySelector('.ocu-typed-name-field') as HTMLInputElement;
    const openDelete = async (key: string) => {
      store.setActive(key);
      store.setSelection([key]);
      opener.focus();
      expect(page.actions.run(declaration.descriptor, 'delete')).toBe(true);
      await settle(page.fixture);
      expect(page.host().querySelector('[role="dialog"]')).not.toBeNull();
    };

    await openDelete('B');
    field().value = 'B';
    field().dispatchEvent(new Event('input'));
    page.fixture.detectChanges();
    page.setRows(named('A', 'C'));
    page.setActionAnswer({ action: 'deleted', target: { type: 'web-application', scope: 'HSCUSTOM', id: 'B' } });
    (page.host().querySelector('.ocu-button-destructive') as HTMLButtonElement).click();
    await settle(page.fixture);

    expect(page.host().querySelector('[role="dialog"]')).toBeNull();
    expect(rowNames(page.host())).toEqual(['A', 'C']);
    const grid = page.host().querySelector('[role="grid"]') as HTMLElement;
    expect(document.activeElement).toBe(grid);
    expect(store.active()).toBe('C');
    const active = page.host().querySelector('.ocu-data-table-row-active') as HTMLElement;
    expect(active.querySelector('.ocu-data-table-link')?.textContent?.trim()).toBe('C');
    expect(grid.getAttribute('aria-activedescendant')).toBe(active.id);

    const posts = page.paths.filter((path) => path.endsWith('/action')).length;
    await openDelete('C');
    (page.host().querySelector('.ocu-dialog .ocu-button-secondary') as HTMLButtonElement).click();
    await settle(page.fixture);
    expect(page.host().querySelector('[role="dialog"]')).toBeNull();
    expect(document.activeElement).toBe(opener);
    expect(page.paths.filter((path) => path.endsWith('/action')).length).toBe(posts);
    expect(rowNames(page.host())).toEqual(['A', 'C']);
  });

  it('Story 7.2: set password opens its own dialog and sends the typed value once, untrimmed', async () => {
    // Through the real handler, dialog and page; only the transport is stubbed.
    // Mutation (Rule 19): render no set-password dialog for its pending kind -> the dialog
    // assertion goes red and nothing is sent.
    const declaration = tableDeclaration({
      descriptor: 'OcuPilot.Screen.Descriptor.UserList',
      rowActions: [{ id: 'set-password', selfProtection: '' }],
    });
    const page = await mount(declaration, named('probe'));
    const store = page.stores.for(declaration.descriptor, declaration.refreshRates);
    store.setSelection(['probe']);
    expect(page.actions.run(declaration.descriptor, 'set-password')).toBe(true);
    await settle(page.fixture);
    const field = page.host().querySelector('input[autocomplete="new-password"]') as HTMLInputElement;
    expect(field).not.toBeNull();
    expect(page.host().querySelector('.ocu-typed-name-field')).toBeNull();
    field.value = 'pw1 ';
    field.dispatchEvent(new Event('input'));
    page.fixture.detectChanges();
    page.setActionAnswer({ action: 'updated', target: { type: 'user', scope: 'instance', id: 'probe' } });
    (page.host().querySelector('.ocu-dialog .ocu-button-primary') as HTMLButtonElement).click();
    await settle(page.fixture);
    expect(page.host().querySelector('[role="dialog"]')).toBeNull();
    expect(page.bodies.map((body) => JSON.parse(body))).toEqual([
      { action: 'set-password', id: 'probe', values: { Password: 'pw1 ' } },
    ]);
  });

  it('Story 7.2: remove role opens the role dialog over the row\u2019s own roles', async () => {
    const declaration = tableDeclaration({
      descriptor: 'OcuPilot.Screen.Descriptor.UserList',
      rowActions: [{ id: 'remove-role', selfProtection: '' }],
    });
    const page = await mount(declaration, [{ ...named('probe')[0], Roles: ['%SQL'] }]);
    const store = page.stores.for(declaration.descriptor, declaration.refreshRates);
    store.setSelection(['probe']);
    expect(page.actions.run(declaration.descriptor, 'remove-role')).toBe(true);
    await settle(page.fixture);
    const select = page.host().querySelector('.ocu-dialog select') as HTMLSelectElement;
    expect([...select.options].map((option) => option.value)).toEqual(['', '%SQL']);
  });

  it('a typed-name confirm left open does not outlive the list it was opened on', async () => {
    // The handler is the app's, so without the page letting go of it a Back press with the dialog
    // open would carry the pending delete onto the next list page.
    //
    // Mutation (Rule 19): drop the `cancelPending()` call from `ListPage`'s destroy hook -> the
    // pending confirm survives the page and this goes red.
    const declaration = tableDeclaration({
      descriptor: 'OcuPilot.Screen.Descriptor.WebAppList',
      rowActions: [{ id: 'delete', selfProtection: 'serves-ocupilot' }],
    });
    const page = await mount(declaration, named('A', 'B'));
    const store = page.stores.for(declaration.descriptor, declaration.refreshRates);
    const handler = TestBed.inject(ScreenActionHandler);
    store.setSelection(['B']);
    expect(page.actions.run(declaration.descriptor, 'delete')).toBe(true);
    await settle(page.fixture);
    expect(handler.pending()?.target).toBe('B');

    page.fixture.destroy();
    expect(handler.pending()).toBeNull();
    expect(page.paths.filter((path) => path.endsWith('/action'))).toHaveLength(0);
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

  it('Story 2.8: the declared banner raises a warning strip above the table when the read answers its key, and a tick clears it', async () => {
    // Both halves have to hold. The declaration alone would render a strip on a screen whose
    // condition is not in force; the answered key alone would render whatever any read put in that
    // slot -- which is why a key the descriptor does not name raises nothing.
    //
    // Mutation (Rule 19): drop the `entry.messageKey === key` lookup from `ListPage.raisedCase`
    // -> the "a key this screen does not declare" assertion goes red.
    const banner = {
      source: { port: 'admin' as const, endpoint: 'Task.Manager', type: 'GET' as const },
      field: 'Status',
      cases: [
        { equals: 'Suspended', messageKey: 'taskManagerSuspendedBanner', severity: 'warning' as const },
      ],
    };
    const declaration = tableDeclaration({ banner, refreshes: true, refreshRates: [10] });
    const page = await mount(declaration, named('A'));
    const strip = () => page.host().querySelector('.ocu-banner') as HTMLElement | null;
    expect(strip()).toBeNull();

    page.setBanner('taskManagerSuspendedBanner');
    page.refresh.setRate(10);
    await page.fireTick();

    const shown = strip();
    expect(shown).not.toBeNull();
    expect(shown?.querySelector('.ocu-banner-message')?.textContent?.trim()).toBe(STRINGS.taskManagerSuspendedBanner);
    // The whole list, not just the severity: `.ocu-banner` is `display: block`, so the page class
    // is what lays the glyph beside the sentence (DESIGN.md `:1203`) and separates the strip from
    // the table. Dropping it changes nothing any single-class assertion can see.
    expect([...(shown?.classList ?? [])].sort()).toEqual(['ocu-banner', 'ocu-banner-warning', 'ocu-list-page-banner']);
    expect(shown?.getAttribute('role')).toBe('status');
    expect(shown?.querySelector('.ocu-banner-glyph')?.getAttribute('aria-hidden')).toBe('true');
    expect(shown?.querySelector('button')).toBeNull();
    expect(rowNames(page.host())).toEqual(['A']);
    const table = page.host().querySelector('app-data-table') as Node;
    const follows = (shown as HTMLElement).compareDocumentPosition(table) & Node.DOCUMENT_POSITION_FOLLOWING;
    expect(follows).toBeTruthy();

    page.setBanner('');
    await page.fireTick();
    expect(strip()).toBeNull();

    page.setBanner('auditingOffBanner');
    await page.fireTick();
    expect(strip()).toBeNull();
  });

  it('DW-270: a second declared case raises its own sentence at its own severity, off the same one read', async () => {
    // One banner, one port read, two (value -> sentence) cases. Before DW-270 a banner carried a
    // single `equals`/`messageKey`/`severity` triple, so the Task Manager's third state -- stopped,
    // which the vendor spells `Not running` -- raised nothing at all and the schedule rendered as
    // though it were in force.
    //
    // Mutation (Rule 19): make `ListPage.raisedCase` return `banner.cases[0]` instead of the case
    // whose `messageKey` the read answered -> the stopped sentence and the `restrained` class both
    // go red, while the suspended leg above stays green.
    const banner = {
      source: { port: 'admin' as const, endpoint: 'Task.Manager', type: 'GET' as const },
      field: 'Status',
      cases: [
        { equals: 'Suspended', messageKey: 'taskManagerSuspendedBanner', severity: 'warning' as const },
        { equals: 'Not running', messageKey: 'taskManagerStoppedBanner', severity: 'restrained' as const },
      ],
    };
    const page = await mount(tableDeclaration({ banner, refreshes: true, refreshRates: [10] }), named('A'));
    const strip = () => page.host().querySelector('.ocu-banner') as HTMLElement | null;
    page.refresh.setRate(10);

    page.setBanner('taskManagerStoppedBanner');
    await page.fireTick();
    expect(strip()?.querySelector('.ocu-banner-message')?.textContent?.trim()).toBe(STRINGS.taskManagerStoppedBanner);
    expect([...(strip()?.classList ?? [])].sort()).toEqual(['ocu-banner', 'ocu-banner-restrained', 'ocu-list-page-banner']);

    // And the first case is still reachable off the same declaration, at its own severity.
    page.setBanner('taskManagerSuspendedBanner');
    await page.fireTick();
    expect(strip()?.querySelector('.ocu-banner-message')?.textContent?.trim()).toBe(STRINGS.taskManagerSuspendedBanner);
    expect([...(strip()?.classList ?? [])].sort()).toEqual(['ocu-banner', 'ocu-banner-warning', 'ocu-list-page-banner']);

    // A value no case names raises nothing, which is what `Running` does on a healthy instance.
    page.setBanner('');
    await page.fireTick();
    expect(strip()).toBeNull();
  });

  it('Story 2.8: a screen that declares no banner renders no strip, whatever the read answers', async () => {
    const page = await mount(tableDeclaration({ refreshes: true, refreshRates: [10] }), named('A'));
    page.setBanner('taskManagerSuspendedBanner');
    page.refresh.setRate(10);
    await page.fireTick();
    expect(page.host().querySelector('.ocu-banner')).toBeNull();
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

  it('DW-260: Refresh re-reads through the transport and leaves sort, filter and selection where they were', async () => {
    // A manual Refresh is the framework's own silent re-read -- the same call the timer makes --
    // so what it must preserve is exactly what a tick preserves. Counted through the transport, so
    // "it re-read" is a request rather than a repaint.
    //
    // Mutation (Rule 19): drop the `actions.register` call from `ListPage`'s constructor -> the
    // registration and the read-count assertions both go red; make the handler call
    // `refresh.bind()` again instead of `readNow()` -> the filter and selection assertions go red,
    // because a re-bind clears the store.
    const page = await mount(tableDeclaration(), named('A', 'B', 'C'));
    const store = page.stores.for(page.declaration!.descriptor, page.declaration!.refreshRates);
    store.setFilter('B');
    store.setSelection(['B']);
    await settle(page.fixture);
    const readsBefore = page.paths.length;
    const sortBefore = store.sort();
    const directionBefore = store.direction();

    expect(page.actions.has(page.declaration!.descriptor, REFRESH_ACTION_ID)).toBe(true);
    expect(page.actions.run(page.declaration!.descriptor, REFRESH_ACTION_ID)).toBe(true);
    await settle(page.fixture);

    expect(page.paths.length).toBe(readsBefore + 1);
    expect(store.filter()).toBe('B');
    expect(store.selection()).toEqual(['B']);
    expect(store.sort()).toBe(sortBefore);
    expect(store.direction()).toBe(directionBefore);
    // Silent: no skeleton is drawn over a view that already has rows.
    expect(page.host().querySelector('.ocu-data-table-skeleton')).toBeNull();
    expect(rowNames(page.host())).toEqual(['B']);
  });

  it('Story 6.3: a parent-scoped list reads for the id its URL carries, and reads again when that id changes', async () => {
    // Mutation (Rule 19): bind `createScreenRead(this.api, screen)` without the criteria in
    // `ListPage` -> the first path assertion goes red, and on an instance the read answers 400.
    const base = tableDeclaration();
    const declaration = tableDeclaration({
      route: 'security/wallet/secrets',
      parentScope: 'security/wallet',
      read: {
        ...base.read!,
        criteria: { fields: [{ param: 'collection', labelKey: 'tableColumnName', kind: 'text', maxLength: 64 }] },
      },
    });
    const page = await mount(declaration, named('OcuPilotDemo.Sample'), true, '/security/wallet/secrets/OcuPilotDemo?ns=HSCUSTOM');
    expect(page.paths).toEqual(['/api/ocupilot/screens/stub/read?maxRows=1000&collection=OcuPilotDemo']);

    // What the user selected among the first collection's secrets names nothing in the next one.
    // Mutation: re-read with `readNow()` instead of `noteScopeChanged()` on the id change -> the
    // selection assertion goes red.
    const store = page.stores.for(declaration.descriptor, declaration.refreshRates);
    store.setSelection(['OcuPilotDemo.Sample']);
    await TestBed.inject(Router).navigateByUrl('/security/wallet/secrets/Other?ns=HSCUSTOM');
    await settle(page.fixture);
    expect(page.paths).toEqual([
      '/api/ocupilot/screens/stub/read?maxRows=1000&collection=OcuPilotDemo',
      '/api/ocupilot/screens/stub/read?maxRows=1000&collection=Other',
    ]);
    expect(store.selection()).toEqual([]);

    // A navigation that keeps the same id reads nothing more.
    await TestBed.inject(Router).navigateByUrl('/security/wallet/secrets/Other?ns=HSCUSTOM&x=1');
    await settle(page.fixture);
    expect(page.paths.length).toBe(2);
  });

  it('Story 6.3: a parent-scoped list opened for another parent holds none of the previous parent\'s rows or selection', async () => {
    // Mutation (Rule 19): drop the `clearAnswers()` a parent-scoped `ListPage` makes when it opens
    // -> the rows and selection assertions go red, still holding the first collection's.
    const base = tableDeclaration();
    const declaration = tableDeclaration({
      route: 'security/wallet/secrets',
      parentScope: 'security/wallet',
      read: {
        ...base.read!,
        criteria: { fields: [{ param: 'collection', labelKey: 'tableColumnName', kind: 'text', maxLength: 64 }] },
      },
    });
    const page = await mount(declaration, named('OcuPilotDemo.Sample'), true, '/security/wallet/secrets/OcuPilotDemo?ns=HSCUSTOM');
    const store = page.stores.for(declaration.descriptor, declaration.refreshRates);
    store.setSelection(['OcuPilotDemo.Sample']);
    expect(store.data().length).toBe(1);
    page.fixture.destroy();

    await TestBed.inject(Router).navigateByUrl('/security/wallet/secrets/Other?ns=HSCUSTOM');
    TestBed.createComponent(ListPage);
    // Read before the new page's read can answer, which is the window the old rows would show in.
    expect(store.data()).toEqual([]);
    expect(store.selection()).toEqual([]);
  });

  it('Story 6.3: a list with no parent sends no criterion from its URL id, whatever it declares', async () => {
    // Mutation (Rule 19): drop `screen.parentScope === '' ||` from `parentCriteria` -> the path
    // assertion goes red, carrying the URL id as the declared criterion.
    const base = tableDeclaration();
    const declaration = tableDeclaration({
      read: { ...base.read!, criteria: { fields: [{ param: 'collection', labelKey: 'tableColumnName', kind: 'text', maxLength: 64 }] } },
    });
    const page = await mount(declaration, named('A'), true, '/web-applications/probe/A?ns=HSCUSTOM');
    expect(page.paths).toEqual(['/api/ocupilot/screens/stub/read?maxRows=1000']);
  });

  it('DW-260: a list declaring no read registers no Refresh, which is how Home offers none', async () => {
    // The registration is in the branch that binds a read, so a declaration with none never
    // reaches it -- which is the same rule that keeps Home, whose descriptor declares no read at
    // all, from drawing a control that would have nothing to re-read.
    const none = await mount(tableDeclaration({ read: null, table: null }), []);
    expect(none.actions.has(none.declaration!.descriptor, REFRESH_ACTION_ID)).toBe(false);
  });
});

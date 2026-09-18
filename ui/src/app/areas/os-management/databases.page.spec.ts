import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { NavigationService, screenForUrl } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { PreferenceStore } from '../../core/preferences';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { STRINGS } from '../../core/strings';
import { ViewOptions } from '../../core/view-options';
import { DatabasesPage } from './databases.page';

/**
 * The Databases screen's registration with the command bar's View control (Story 6.11): the page
 * declares the two options, which route is current and what choosing one does through
 * `ViewOptions`; `command-bar.ts` -- not this page -- draws the menu, so that mechanism is
 * `command-bar.spec.ts`'s to pin. This file pins the registration itself: the right labels in the
 * right order, the right option checked for each route, and a choice that navigates (or does not)
 * exactly as AD-36 requires.
 *
 * The screen this page renders and its declared read are resolved through the real mirror
 * (`screenForUrl`), so the descriptor, its fields and its `toolIdentifier` are the ones the
 * instance validates -- the same shape `process-details.page.spec.ts` takes.
 *
 * Mutation (Rule 19): swap `GENERAL_ROUTE` and `FREE_SPACE_ROUTE` in `databases.page.ts` -> the
 * "current on the General route" and "navigates to Free space" assertions both go red, since the
 * registered binding's `current()` and its `choose()` target would disagree with the real
 * mirror's routes.
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

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 20));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

const planted: HTMLElement[] = [];

describe('the Databases page\u2019s View control', () => {
  let fixture: ComponentFixture<DatabasesPage>;
  let router: Router;
  let viewOptions: ViewOptions;

  const mount = async (url = '/os-management/databases?ns=HSCUSTOM') => {
    TestBed.resetTestingModule();
    const paths: string[] = [];
    const api = {
      requestJson: async <T,>(path: string): Promise<JsonResult<T>> => {
        paths.push(path);
        return { kind: 'ok', status: 200, body: { fields: [], rows: [], truncated: false, banner: '' } as T };
      },
    };
    const stores = new ScreenStores({ preferences: new PreferenceStore({ storage: memoryStorage() }) });
    viewOptions = new ViewOptions();
    TestBed.configureTestingModule({
      providers: [
        provideRouter([{ path: '**', children: [] }]),
        { provide: NavigationService, useValue: { screenForUrl } as unknown as NavigationService },
        { provide: ApiService, useValue: api as unknown as ApiService },
        { provide: RefreshService, useValue: new RefreshService({
            stores,
            connectivity: { retryWhenReachable: () => {} } as never,
            bus: { publish: () => {}, subscribe: () => () => {} } as never,
            namespace: () => 'HSCUSTOM',
            schedule: () => {},
          }) },
        { provide: ScreenStores, useValue: stores },
        { provide: ScreenActions, useValue: new ScreenActions() },
        { provide: OverlayStack, useValue: new OverlayStack() },
        { provide: ViewOptions, useValue: viewOptions },
        {
          provide: ScopeService,
          useValue: { loaded: () => true, namespace: () => 'HSCUSTOM', subscribe: () => () => {} } as unknown as ScopeService,
        },
      ],
    });
    router = TestBed.inject(Router);
    await router.navigateByUrl(url);
    fixture = TestBed.createComponent(DatabasesPage);
    document.body.appendChild(fixture.nativeElement);
    planted.push(fixture.nativeElement);
    fixture.detectChanges();
    await settle(fixture);
    return { paths };
  };

  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
  });

  it('registers two options, labelled "General" and "Free space", in that order', async () => {
    await mount('/os-management/databases?ns=HSCUSTOM');
    expect(viewOptions.has()).toBe(true);
    expect(viewOptions.options().map((option) => option.label)).toEqual([
      STRINGS.processDetailsGroupGeneral,
      STRINGS.databaseFreeSpaceLabel,
    ]);
  });

  it('reports the General route current on the General route', async () => {
    await mount('/os-management/databases?ns=HSCUSTOM');
    const [general] = viewOptions.options();
    expect(viewOptions.current()).toBe(general.route);
  });

  it('reports the Free-space route current on the Free-space route', async () => {
    await mount('/os-management/database-free-space?ns=HSCUSTOM');
    const [, freeSpace] = viewOptions.options();
    expect(viewOptions.current()).toBe(freeSpace.route);
  });

  it('choosing "Free space" from the General view navigates there, carrying the namespace', async () => {
    await mount('/os-management/databases?ns=HSCUSTOM');
    const [, freeSpace] = viewOptions.options();
    viewOptions.choose(freeSpace.route);
    await settle(fixture);
    expect(router.url).toBe('/os-management/database-free-space?ns=HSCUSTOM');
  });

  it('choosing the already-active option navigates nowhere', async () => {
    await mount('/os-management/databases?ns=HSCUSTOM');
    const [general] = viewOptions.options();
    const before = router.url;
    viewOptions.choose(general.route);
    await settle(fixture);
    expect(router.url).toBe(before);
  });

  it('unregisters its View options on destroy', async () => {
    await mount();
    expect(viewOptions.has()).toBe(true);
    fixture.destroy();
    expect(viewOptions.has()).toBe(false);
  });

  it('renders the shared list page on the General route', async () => {
    await mount();
    expect(fixture.nativeElement.querySelector('app-list-page')).not.toBeNull();
  });

  // --- The Free-space view's staged rendering (AC2, AC3, AC5, Story 6.11) -----------------------

  const GENERAL_ROW = { Directory: '/durable/iris/mgr/', Size: 70, MaxSize: 'Unlimited', Status: 'Mounted/RW', Resource: '%DB_IRISSYS' };
  const FIGURE_ROW = { Directory: '/durable/iris/mgr/', Size: 70, AvailableSpace: 3.1, DiskFree: '1.113TB', Mounted: true };

  /** Mounts the Free-space route with the General read answering immediately and the Free-space
   * read held open until `resolveFigures` is called, so the staged, pending state is observable. */
  async function mountFreeSpaceHeld() {
    TestBed.resetTestingModule();
    let resolveFigures: (() => void) | null = null;
    const held = new Promise<void>((resolve) => {
      resolveFigures = resolve;
    });
    let figuresFail = false;
    const api = {
      requestJson: async <T,>(path: string): Promise<JsonResult<T>> => {
        if (path.includes('osmgmt.databasefreespace')) {
          await held;
          if (figuresFail) return { kind: 'error', status: 503, code: 'PORT.TIMEOUT', reason: null, detail: null };
          return { kind: 'ok', status: 200, body: { fields: [], rows: [FIGURE_ROW], truncated: false, banner: '' } as T };
        }
        return { kind: 'ok', status: 200, body: { fields: [], rows: [GENERAL_ROW], truncated: false, banner: '' } as T };
      },
    };
    const stores = new ScreenStores({ preferences: new PreferenceStore({ storage: memoryStorage() }) });
    TestBed.configureTestingModule({
      providers: [
        provideRouter([{ path: '**', children: [] }]),
        { provide: NavigationService, useValue: { screenForUrl } as unknown as NavigationService },
        { provide: ApiService, useValue: api as unknown as ApiService },
        { provide: RefreshService, useValue: new RefreshService({
            stores,
            connectivity: { retryWhenReachable: () => {} } as never,
            bus: { publish: () => {}, subscribe: () => () => {} } as never,
            namespace: () => 'HSCUSTOM',
            schedule: () => {},
          }) },
        { provide: ScreenStores, useValue: stores },
        { provide: ScreenActions, useValue: new ScreenActions() },
        { provide: OverlayStack, useValue: new OverlayStack() },
        { provide: ViewOptions, useValue: new ViewOptions() },
        {
          provide: ScopeService,
          useValue: { loaded: () => true, namespace: () => 'HSCUSTOM', subscribe: () => () => {} } as unknown as ScopeService,
        },
      ],
    });
    router = TestBed.inject(Router);
    await router.navigateByUrl('/os-management/database-free-space?ns=HSCUSTOM');
    fixture = TestBed.createComponent(DatabasesPage);
    document.body.appendChild(fixture.nativeElement);
    planted.push(fixture.nativeElement);
    fixture.detectChanges();
    await settle(fixture);
    return {
      resolveFigures: () => {
        figuresFail = false;
        resolveFigures?.();
      },
      failFigures: () => {
        figuresFail = true;
        resolveFigures?.();
      },
      // Later calls no longer wait on `held`, so arming this and running the Refresh action is a
      // second, succeeding Free-space read through the same bound closure.
      succeedFigures: () => {
        figuresFail = false;
      },
      actions: TestBed.inject(ScreenActions),
    };
  }

  /** Mounts the Free-space route with the namespace scope unresolved, and hands back the switch
   * that resolves it and notifies its subscribers -- the cold deep-link ordering. */
  async function mountFreeSpaceColdScope() {
    TestBed.resetTestingModule();
    let scopeLoaded = false;
    const listeners = new Set<() => void>();
    const paths: string[] = [];
    const api = {
      requestJson: async <T,>(path: string): Promise<JsonResult<T>> => {
        paths.push(path);
        if (path.includes('osmgmt.databasefreespace')) {
          return { kind: 'ok', status: 200, body: { fields: [], rows: [FIGURE_ROW], truncated: false, banner: '' } as T };
        }
        return { kind: 'ok', status: 200, body: { fields: [], rows: [GENERAL_ROW], truncated: false, banner: '' } as T };
      },
    };
    const stores = new ScreenStores({ preferences: new PreferenceStore({ storage: memoryStorage() }) });
    TestBed.configureTestingModule({
      providers: [
        provideRouter([{ path: '**', children: [] }]),
        { provide: NavigationService, useValue: { screenForUrl } as unknown as NavigationService },
        { provide: ApiService, useValue: api as unknown as ApiService },
        { provide: RefreshService, useValue: new RefreshService({
            stores,
            connectivity: { retryWhenReachable: () => {} } as never,
            bus: { publish: () => {}, subscribe: () => () => {} } as never,
            namespace: () => (scopeLoaded ? 'HSCUSTOM' : ''),
            schedule: () => {},
          }) },
        { provide: ScreenStores, useValue: stores },
        { provide: ScreenActions, useValue: new ScreenActions() },
        { provide: OverlayStack, useValue: new OverlayStack() },
        { provide: ViewOptions, useValue: new ViewOptions() },
        {
          provide: ScopeService,
          useValue: {
            loaded: () => scopeLoaded,
            namespace: () => (scopeLoaded ? 'HSCUSTOM' : ''),
            subscribe: (listener: () => void) => {
              listeners.add(listener);
              return () => listeners.delete(listener);
            },
          } as unknown as ScopeService,
        },
      ],
    });
    router = TestBed.inject(Router);
    await router.navigateByUrl('/os-management/database-free-space?ns=HSCUSTOM');
    fixture = TestBed.createComponent(DatabasesPage);
    document.body.appendChild(fixture.nativeElement);
    planted.push(fixture.nativeElement);
    fixture.detectChanges();
    await settle(fixture);
    return {
      paths,
      resolveScope: () => {
        scopeLoaded = true;
        for (const listener of listeners) listener();
      },
    };
  }

  const skeletonCells = (): Element[] => Array.from(fixture.nativeElement.querySelectorAll('.ocu-data-table-cell-skeleton'));
  const rowEls = (): Element[] => Array.from(fixture.nativeElement.querySelectorAll('[role="row"][data-row-index]'));

  it('AC2: before the Free-space read resolves, the staged row is on screen with three skeleton cells', async () => {
    await mountFreeSpaceHeld();
    expect(rowEls().length).toBe(1);
    expect(fixture.nativeElement.textContent).toContain('/durable/iris/mgr/');
    // Three pending columns, one skeleton bar each, on the one staged row.
    expect(skeletonCells().length).toBe(3);
  });

  it('AC3: once the Free-space read resolves, all three figures land together and no skeleton remains', async () => {
    const { resolveFigures } = await mountFreeSpaceHeld();
    resolveFigures();
    await settle(fixture);
    expect(skeletonCells().length).toBe(0);
    expect(fixture.nativeElement.textContent).toContain('1.113TB');
  });

  it('AC5: a timeout on the Free-space read leaves the staged row and its skeleton cells, refusing the figures whole', async () => {
    // A 503 classifies as a connectivity-level fault (`isBannerFault`), which the shell's own
    // banner renders rather than this table's per-read refusal strip -- the same path every
    // other screen's async fault takes. What AC5 pins is here: no partial figure ever reaches a
    // cell, and the staged row is left exactly as it was.
    const { failFigures } = await mountFreeSpaceHeld();
    failFigures();
    await settle(fixture);
    expect(skeletonCells().length).toBe(3);
    expect(fixture.nativeElement.textContent).toContain('/durable/iris/mgr/');
    expect(fixture.nativeElement.textContent).not.toContain('1.113TB');
    const refresh = TestBed.inject(RefreshService);
    expect(refresh.fault()?.code).toBe('PORT.TIMEOUT');
  });

  it('AC5, recovery: a Free-space read that succeeds after a faulted one clears the skeletons rather than drawing them over the figures', async () => {
    // The recovery path from AC5's own refusal. `pendingFields` is read off the rendered row set,
    // so the skeletons clear when a read actually lands the figures -- a latched pending list
    // would keep drawing skeleton bars over values that have arrived, and `data-table.ts`
    // suppresses a pending cell's text entirely, so all three columns would read blank for the
    // life of the page.
    const { failFigures, succeedFigures, actions } = await mountFreeSpaceHeld();
    failFigures();
    await settle(fixture);
    expect(skeletonCells().length).toBe(3);

    succeedFigures();
    expect(actions.run('OcuPilot.Screen.Descriptor.DatabaseFreeSpace', REFRESH_ACTION_ID)).toBe(true);
    await settle(fixture);
    expect(skeletonCells().length).toBe(0);
    expect(fixture.nativeElement.textContent).toContain('1.113TB');
  });

  it('a cold load of the Free-space route stages once the namespace scope resolves', async () => {
    // The page is constructed before the namespace list arrives (`list-page.ts`), and
    // `RefreshService.noteScopeChanged()` re-reads only a screen that is already bound, so a page
    // that returned without binding would leave the table empty for its whole life.
    const { paths, resolveScope } = await mountFreeSpaceColdScope();
    expect(paths).toEqual([]);
    expect(rowEls().length).toBe(0);

    resolveScope();
    await settle(fixture);
    expect(paths.some((path) => path.includes('osmgmt.databases/read'))).toBe(true);
    expect(paths.some((path) => path.includes('osmgmt.databasefreespace/read'))).toBe(true);
    expect(rowEls().length).toBe(1);
    expect(skeletonCells().length).toBe(0);
    expect(fixture.nativeElement.textContent).toContain('1.113TB');
  });
});

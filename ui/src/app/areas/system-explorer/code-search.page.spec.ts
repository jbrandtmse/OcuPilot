import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import type { ConnectivityService } from '../../core/connectivity';
import { encodeEntityId } from '../../core/entity-id';
import { NavigationService } from '../../core/navigation';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenArrivals } from '../../core/screen-arrival';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS, type ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { CodeSearchPage } from './code-search.page';
import { hitLocation, hitsOf } from './code-search.store';

/**
 * System Explorer's Search over the shipped descriptor, with the real `RefreshService`,
 * `ScreenStores`, `ChangeBus` and `ScreenArrivals` and a stubbed HTTP answer (Story 19.4, AC1 and
 * AC2): nothing read before a search, the search's exact criteria, each match's document linked to
 * its own viewer and its line rendered as text, the cap notice, the empty state, an agent's arrival
 * run once, and a re-read when a class in the namespace changes.
 */

const SEARCH = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.ExplorerSearch') as ScreenDeclaration;

/** Text a renderer that bound markup would turn into an element. */
const HOSTILE = '<img src=x onerror="alert(1)"> needle';

const ROWS = [
  { Order: 1, Document: 'Demo.Probe.cls', Member: '', Line: 1, Attribute: 'Description', Text: 'needle in a description' },
  { Order: 2, Document: 'Demo.Probe.cls', Member: 'Run', Line: 4, Attribute: '', Text: HOSTILE },
  { Order: 3, Document: 'Demo.Probe.cls', Member: 'Marked', Line: null, Attribute: '', Text: 'needle in a parameter' },
  { Order: 4, Document: 'DemoProbe.mac', Member: '', Line: 3, Attribute: '', Text: 'needle in a routine' },
];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 20));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

const planted: HTMLElement[] = [];

async function mount(options: { rows?: readonly unknown[]; truncated?: boolean; arrivals?: ScreenArrivals; refusal?: { status: number; code: string; reason: string | null } } = {}) {
  TestBed.resetTestingModule();
  const paths: string[] = [];
  const bus = new ChangeBus();
  const api = {
    requestJson: async <T,>(path: string): Promise<JsonResult<T>> => {
      paths.push(path);
      if (options.refusal !== undefined) return { kind: 'error', status: options.refusal.status, code: options.refusal.code, reason: options.refusal.reason, detail: null };
      return { kind: 'ok', status: 200, body: { fields: [], rows: options.rows ?? ROWS, truncated: options.truncated ?? false, banner: '' } as T };
    },
  };
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  const refresh = new RefreshService({
    stores,
    connectivity: { retryWhenReachable: () => {} } as unknown as ConnectivityService,
    bus,
    namespace: () => 'HSCUSTOM',
    schedule: () => {},
  });
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: NavigationService, useValue: { screenForUrl: () => SEARCH } as unknown as NavigationService },
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: RefreshService, useValue: refresh },
      { provide: ScreenStores, useValue: stores },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: ChangeBus, useValue: bus },
      { provide: ScreenArrivals, useValue: options.arrivals ?? new ScreenArrivals() },
      {
        provide: ScopeService,
        useValue: { loaded: () => true, namespace: () => 'HSCUSTOM', subscribe: () => () => undefined } as unknown as ScopeService,
      },
    ],
  });
  await TestBed.inject(Router).navigateByUrl(`/${SEARCH.route}?ns=HSCUSTOM`);
  const fixture = TestBed.createComponent(CodeSearchPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  const host = fixture.nativeElement as HTMLElement;
  return {
    host,
    paths,
    bus,
    router: TestBed.inject(Router),
    search: async (text: string, scope = '', matchCase = false) => {
      const input = host.querySelector('[data-ocu-search="text"]') as HTMLInputElement;
      input.value = text;
      input.dispatchEvent(new Event('input'));
      if (scope !== '') {
        const select = host.querySelector('[data-ocu-search="scope"]') as HTMLSelectElement;
        select.value = scope;
        select.dispatchEvent(new Event('change'));
      }
      const box = host.querySelector('[data-ocu-search="case"]') as HTMLInputElement;
      box.checked = matchCase;
      box.dispatchEvent(new Event('change'));
      (host.querySelector('[data-ocu-search="submit"]') as HTMLButtonElement).click();
      await settle(fixture);
    },
    settle: () => settle(fixture),
  };
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
});

describe('System Explorer Search', () => {
  it('reads nothing until Search is pressed with text, and invites a search', async () => {
    const { host, paths, search } = await mount();
    expect(paths).toEqual([]);
    expect(host.querySelector('[data-ocu-search="empty"]')?.textContent?.trim()).toBe(STRINGS.explorerSearchInvite);
    await search('   ');
    expect(paths).toEqual([]);
  });

  it('sends the text, scope and case as typed, and lists each match with its document linked to its own viewer', async () => {
    const { host, paths, search } = await mount();
    await search('needle', 'routines', true);
    expect(paths).toEqual(['/api/ocupilot/screens/explorer.search/read?maxRows=1000&text=needle&scope=routines&case=yes']);
    const links = Array.from(host.querySelectorAll('[data-ocu-search="document"]')) as HTMLAnchorElement[];
    expect(links.map((link) => link.textContent?.trim())).toEqual(['Demo.Probe.cls', 'Demo.Probe.cls', 'Demo.Probe.cls', 'DemoProbe.mac']);
    // Mutation (Rule 19): send every hit to the class viewer in `viewerRouteFor` -> the routine's link goes red.
    expect(links[0].getAttribute('href')).toBe(`/system-explorer/classes/document/${encodeEntityId('Demo.Probe.cls')}?ns=HSCUSTOM`);
    expect(links[3].getAttribute('href')).toBe(`/system-explorer/routines/document/${encodeEntityId('DemoProbe.mac')}?ns=HSCUSTOM`);
    const locations = Array.from(host.querySelectorAll('[data-ocu-search="location"]')).map((cell) => cell.textContent?.trim());
    expect(locations).toEqual(['[Description]', 'Run+4', 'Marked', '3']);
    const match = host.querySelectorAll('[data-ocu-search="match"]')[1] as HTMLElement;
    expect(match.textContent).toBe(HOSTILE);
    expect(match.querySelector('img')).toBeNull();
    expect(host.querySelector('[data-ocu-search="status"]')?.textContent?.trim()).toBe('');
  });

  it('a hit opens its viewer in place', async () => {
    const { host, search, router, settle: wait } = await mount();
    await search('needle');
    (host.querySelectorAll('[data-ocu-search="document"]')[3] as HTMLAnchorElement).click();
    await wait();
    expect(router.url).toBe(`/system-explorer/routines/document/${encodeEntityId('DemoProbe.mac')}?ns=HSCUSTOM`);
  });

  it('says the list was cut when the read truncated it', async () => {
    const { host, search } = await mount({ truncated: true });
    await search('needle');
    expect(host.querySelector('[data-ocu-search="status"]')?.textContent?.trim()).toBe(STRINGS.tableRowCapNotice.replace('<n>', '1,000'));
  });

  it('says nothing matches when the search answers no row', async () => {
    const { host, search } = await mount({ rows: [] });
    await search('needle');
    expect(host.querySelector('[data-ocu-search="empty"]')?.textContent?.trim()).toBe(STRINGS.explorerSearchEmpty);
    expect(host.querySelector('[data-ocu-search="results"]')).toBeNull();
  });

  it("draws a refused search with the instance's reason, and no rows or empty state", async () => {
    const { host, search } = await mount({ refusal: { status: 400, code: 'PORT.VALIDATION', reason: STRINGS.explorerSearchTextReason } });
    await search('needle');
    expect(host.querySelector('[data-ocu-search="fault"] .ocu-data-table-refusal-message')?.textContent?.trim()).toBe(STRINGS.explorerSearchTextReason);
    expect(host.querySelector('[data-ocu-search="results"]')).toBeNull();
    expect(host.querySelector('[data-ocu-search="empty"]')).toBeNull();
  });

  it('falls back to the generic sentence for a refusal that carries no reason', async () => {
    const { host, search } = await mount({ refusal: { status: 403, code: 'AUTH.NOPRIVILEGE', reason: null } });
    await search('needle');
    expect(host.querySelector('[data-ocu-search="fault"] .ocu-data-table-refusal-message')?.textContent?.trim()).toBe(STRINGS.connectivityRequestRefused);
  });

  it("runs an agent's arrival once, with its criteria shown in the form", async () => {
    const arrivals = new ScreenArrivals();
    arrivals.set({ route: SEARCH.route, criterion: '', criteria: { text: 'TODO', scope: 'classes' } });
    const { host, paths } = await mount({ arrivals });
    expect(paths).toEqual(['/api/ocupilot/screens/explorer.search/read?maxRows=1000&text=TODO&scope=classes&case=no']);
    expect((host.querySelector('[data-ocu-search="text"]') as HTMLInputElement).value).toBe('TODO');
    expect((host.querySelector('[data-ocu-search="scope"]') as HTMLSelectElement).value).toBe('classes');
  });

  it('runs the last search again when a class in this namespace changes', async () => {
    const { paths, search, bus, settle: wait } = await mount();
    await search('needle');
    bus.publish({ kind: 'changed', type: 'class', scope: 'HSCUSTOM', id: 'Demo.Probe.cls', action: 'updated' });
    await wait();
    expect(paths).toHaveLength(2);
    expect(paths[1]).toBe(paths[0]);
  });
});

describe('hits and their location', () => {
  it('reads each row by its declared fields', () => {
    const hits = hitsOf(ROWS);
    expect(hits.map(hitLocation)).toEqual(['[Description]', 'Run+4', 'Marked', '3']);
    expect(hits[2].line).toBeNull();
  });
});

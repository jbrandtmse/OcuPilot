import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, Router, convertToParamMap, provideRouter } from '@angular/router';
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
import { MacroLookupPage } from './macro-lookup.page';

/**
 * System Explorer's Macros over the shipped descriptor, with the real `RefreshService`,
 * `ScreenStores` and `ScreenArrivals` and a stubbed HTTP answer (Story 19.4, AC5): the document
 * prefilled from `?document=`, nothing read until both fields hold text, the lookup's exact
 * criteria, the definition rendered as text with "Defined in" linking the include's viewer, the
 * sentence for a macro the context does not define, and an agent's arrival run once.
 */

const MACROS = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.ExplorerMacro') as ScreenDeclaration;

/** Text a renderer that bound markup would turn into an element. */
const HOSTILE = 'ProbeMacro <b>1</b>\n  + 2';

const ROW = { Macro: 'ProbeMacro', Document: 'ProbeInc.inc', Line: 7, Definition: HOSTILE };

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 20));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

const planted: HTMLElement[] = [];

async function mount(options: { rows?: readonly unknown[]; prefill?: string; arrivals?: ScreenArrivals } = {}) {
  TestBed.resetTestingModule();
  const paths: string[] = [];
  const api = {
    requestJson: async <T,>(path: string): Promise<JsonResult<T>> => {
      paths.push(path);
      return { kind: 'ok', status: 200, body: { fields: [], rows: options.rows ?? [ROW], truncated: false, banner: '' } as T };
    },
  };
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  const refresh = new RefreshService({
    stores,
    connectivity: { retryWhenReachable: () => {} } as unknown as ConnectivityService,
    bus: new ChangeBus(),
    namespace: () => 'USER',
    schedule: () => {},
  });
  const query = options.prefill === undefined ? {} : { document: options.prefill };
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: NavigationService, useValue: { screenForUrl: () => MACROS } as unknown as NavigationService },
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: RefreshService, useValue: refresh },
      { provide: ScreenStores, useValue: stores },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: ScreenArrivals, useValue: options.arrivals ?? new ScreenArrivals() },
      { provide: ActivatedRoute, useValue: { snapshot: { queryParamMap: convertToParamMap(query) } } as unknown as ActivatedRoute },
      {
        provide: ScopeService,
        useValue: { loaded: () => true, namespace: () => 'USER', subscribe: () => () => undefined } as unknown as ScopeService,
      },
    ],
  });
  await TestBed.inject(Router).navigateByUrl(`/${MACROS.route}?ns=USER`);
  const fixture = TestBed.createComponent(MacroLookupPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  const host = fixture.nativeElement as HTMLElement;
  const type = (field: string, value: string): void => {
    const input = host.querySelector(`[data-ocu-macro="${field}"]`) as HTMLInputElement;
    input.value = value;
    input.dispatchEvent(new Event('input'));
  };
  return {
    host,
    paths,
    lookUp: async (document: string | null, macro: string) => {
      if (document !== null) type('document', document);
      type('macro', macro);
      (host.querySelector('[data-ocu-macro="submit"]') as HTMLButtonElement).click();
      await settle(fixture);
    },
  };
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
});

describe('System Explorer Macros', () => {
  it('prefills the document from ?document= and reads nothing until both fields hold text', async () => {
    const { host, paths, lookUp } = await mount({ prefill: 'Demo.Probe.cls' });
    expect((host.querySelector('[data-ocu-macro="document"]') as HTMLInputElement).value).toBe('Demo.Probe.cls');
    expect(paths).toEqual([]);
    await lookUp(null, ' ');
    expect(paths).toEqual([]);
  });

  it('sends the document and the macro, shows the definition as text and links the include that defines it', async () => {
    const { host, paths, lookUp } = await mount({ prefill: 'Demo.Probe.cls' });
    await lookUp(null, '$$$ProbeMacro');
    expect(paths).toEqual(['/api/ocupilot/screens/explorer.macro/read?maxRows=1000&document=Demo.Probe.cls&macro=%24%24%24ProbeMacro']);
    const definition = host.querySelector('pre[data-ocu-macro="definition"]') as HTMLElement;
    expect(definition.getAttribute('tabindex')).toBe('0');
    expect(definition.textContent).toBe(HOSTILE);
    expect(definition.querySelector('b')).toBeNull();
    const link = host.querySelector('[data-ocu-macro="defined-in"]') as HTMLAnchorElement;
    expect(link.textContent?.trim()).toBe('Defined in ProbeInc.inc, line 7');
    expect(link.getAttribute('href')).toBe(`/system-explorer/routines/document/${encodeEntityId('ProbeInc.inc')}?ns=USER`);
  });

  it('says the macro is not defined where the document can see it when the lookup answers no row', async () => {
    const { host, lookUp } = await mount({ rows: [] });
    await lookUp('Demo.Probe.cls', 'Nothing');
    expect(host.querySelector('[data-ocu-macro="empty"]')?.textContent?.trim()).toBe(STRINGS.explorerMacroUndefined.replace('<macro>', 'Nothing').replace('<document>', 'Demo.Probe.cls'));
    expect(host.querySelector('[data-ocu-macro="result"]')).toBeNull();
  });

  it("runs an agent's arrival once, with its criteria shown in the form", async () => {
    const arrivals = new ScreenArrivals();
    arrivals.set({ route: MACROS.route, criterion: '', criteria: { document: 'Demo.Probe.cls', macro: 'OK' } });
    const { host, paths } = await mount({ arrivals });
    expect(paths).toEqual(['/api/ocupilot/screens/explorer.macro/read?maxRows=1000&document=Demo.Probe.cls&macro=OK']);
    expect((host.querySelector('[data-ocu-macro="macro"]') as HTMLInputElement).value).toBe('OK');
  });
});

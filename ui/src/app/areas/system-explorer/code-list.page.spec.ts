import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, Router, convertToParamMap, provideRouter } from '@angular/router';
import { BehaviorSubject } from 'rxjs';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import type { ConnectivityService } from '../../core/connectivity';
import { NavigationService } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenArrivals } from '../../core/screen-arrival';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS, type ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { CodeListPage } from './code-list.page';
import { CodeListSearch, isYesNo } from './code-list.store';

/**
 * System Explorer's Classes and Routines lists over the shipped descriptors, with the real
 * `RefreshService`, `ScreenStores`, `createScreenRead` and `DataTable` and a stubbed HTTP answer that
 * echoes the criteria the instance would apply (Story 19.1, AC1).
 */

const CLASSES = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.ExplorerClassList') as ScreenDeclaration;
const ROUTINES = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.ExplorerRoutineList') as ScreenDeclaration;

const row = (name: string) => ({ Name: name, Modified: '2026-10-01 10:00:00.000', Database: 'HSCUSTOM', Generated: false });

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 20));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

const planted: HTMLElement[] = [];

/** What the instance would echo for `path` under `screen`: each sent value, else the declared default. */
function echoFor(screen: ScreenDeclaration, path: string): Record<string, string> {
  const query = new URLSearchParams(path.split('?')[1] ?? '');
  const applied: Record<string, string> = {};
  for (const field of screen.read?.criteria?.fields ?? []) {
    applied[field.param] = query.get(field.param) ?? field.default ?? '';
  }
  return applied;
}

async function mount(
  screen: ScreenDeclaration,
  rows: unknown[] = [row('OcuPilot.Port.AtelierPort.cls')],
  arrivals: ScreenArrivals | null = null,
  echo: (path: string) => Record<string, string> = (path) => echoFor(screen, path)
) {
  TestBed.resetTestingModule();
  const paths: string[] = [];
  const api = {
    requestJson: async <T,>(path: string): Promise<JsonResult<T>> => {
      paths.push(path);
      return { kind: 'ok', status: 200, body: { fields: [], rows, truncated: false, banner: '', criteria: echo(path) } as T };
    },
  };
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  const refresh = new RefreshService({
    stores,
    connectivity: { retryWhenReachable: () => {} } as unknown as ConnectivityService,
    bus: new ChangeBus(),
    namespace: () => 'HSCUSTOM',
    schedule: () => {},
  });
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: NavigationService, useValue: { screenForUrl: () => screen } as unknown as NavigationService },
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: RefreshService, useValue: refresh },
      { provide: ScreenStores, useValue: stores },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: OverlayStack, useValue: new OverlayStack() },
      {
        provide: ScopeService,
        useValue: { loaded: () => true, namespace: () => 'HSCUSTOM', subscribe: () => () => {} } as unknown as ScopeService,
      },
      { provide: ActivatedRoute, useValue: { paramMap: new BehaviorSubject(convertToParamMap({})) } as unknown as ActivatedRoute },
      ...(arrivals === null ? [] : [{ provide: ScreenArrivals, useValue: arrivals }]),
    ],
  });
  await TestBed.inject(Router).navigateByUrl(`/${screen.route}?ns=HSCUSTOM`);
  const fixture = TestBed.createComponent(CodeListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  const host = fixture.nativeElement as HTMLElement;
  return {
    fixture,
    host,
    paths,
    refresh,
    field: (param: string) => host.querySelector(`input[data-ocu-criterion="${param}"]`) as HTMLInputElement,
    type: async (param: string, value: string) => {
      const input = host.querySelector(`input[data-ocu-criterion="${param}"]`) as HTMLInputElement;
      input.value = value;
      input.dispatchEvent(new Event('input', { bubbles: true }));
      await settle(fixture);
    },
    check: async (param: string, on: boolean) => {
      const box = host.querySelector(`input[type="checkbox"][data-ocu-criterion="${param}"]`) as HTMLInputElement;
      box.checked = on;
      box.dispatchEvent(new Event('change', { bubbles: true }));
      await settle(fixture);
    },
    search: async () => {
      (host.querySelector('.ocu-criteria-controls button[type="submit"]') as HTMLElement).click();
      await settle(fixture);
    },
  };
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
});

describe('System Explorer lists', () => {
  it('the Classes list opens on one default read, its form showing the declared defaults under their labels', async () => {
    const { host, paths, field } = await mount(CLASSES);
    expect(paths).toEqual(['/api/ocupilot/screens/explorer.classes/read?maxRows=1000']);
    expect(field('pattern').value).toBe('*');
    expect(host.querySelector(`label[for="${field('pattern').id}"]`)?.textContent?.trim()).toBe(STRINGS.explorerClassPatternLabel);
    expect(field('from').value).toBe('');
    expect(host.querySelector(`label[for="${field('from').id}"]`)?.textContent?.trim()).toBe(STRINGS.auditCriteriaBegin);
    expect(host.querySelector('.ocu-criteria-hint')?.textContent?.trim()).toBe(STRINGS.auditCriteriaTimeHint);
    const boxes = Array.from(host.querySelectorAll<HTMLInputElement>('input[type="checkbox"]'));
    expect(boxes.map((box) => [box.dataset['ocuCriterion'], box.checked])).toEqual([
      ['system', false],
      ['generated', false],
      ['mapped', true],
    ]);
    const markers = Array.from(host.querySelectorAll('.ocu-criteria-marker')).map((label) => label.textContent?.trim());
    expect(markers).toEqual([STRINGS.explorerSystemLabel, STRINGS.explorerGeneratedLabel, STRINGS.explorerMappedLabel]);
    expect(host.querySelector('[role="grid"]')).not.toBeNull();
  });

  it('the Routines list opens on *.mac with generated items checked', async () => {
    const { field, host } = await mount(ROUTINES, [row('HS.HC.Info.mac')]);
    expect(field('pattern').value).toBe('*.mac');
    expect(host.querySelector(`label[for="${field('pattern').id}"]`)?.textContent?.trim()).toBe(STRINGS.explorerRoutinePatternLabel);
    expect((host.querySelector('input[type="checkbox"][data-ocu-criterion="generated"]') as HTMLInputElement).checked).toBe(true);
  });

  it('Search sends every criterion as the form shows it, a checkbox as yes or no', async () => {
    const { paths, type, check, search } = await mount(CLASSES);
    await type('pattern', 'OcuPilot.*');
    await check('system', true);
    await check('mapped', false);
    await search();
    expect(paths).toHaveLength(2);
    expect(paths[1]).toBe(
      '/api/ocupilot/screens/explorer.classes/read?maxRows=1000&pattern=OcuPilot.*&system=yes&generated=no&mapped=no&from=&to='
    );
  });

  it('an agent arrival runs exactly its criteria, and the form fills the rest from the answer', async () => {
    const arrivals = new ScreenArrivals();
    arrivals.set({ route: CLASSES.route, criterion: '', criteria: { pattern: 'HS.*' } });
    // The instance answers a value the declaration does not default to, so the form can only show
    // it by reading the answer. Mutation (Rule 19): make `CodeListSearch.applyEcho` return at once -> red.
    const { paths, field, host } = await mount(CLASSES, [row('HS.HC.Info.cls')], arrivals, (path) => ({ ...echoFor(CLASSES, path), system: 'yes' }));
    expect(paths).toEqual(['/api/ocupilot/screens/explorer.classes/read?maxRows=1000&pattern=HS.*']);
    expect(field('pattern').value).toBe('HS.*');
    expect((host.querySelector('input[type="checkbox"][data-ocu-criterion="system"]') as HTMLInputElement).checked).toBe(true);
  });

  it('switching the namespace re-reads the search on screen (AC1)', async () => {
    // Mutation (Rule 19): drop the read from `RefreshService.noteScopeChanged` -> red.
    const { fixture, paths, type, search, refresh } = await mount(CLASSES);
    await type('pattern', 'OcuPilot.*');
    await search();
    refresh.noteScopeChanged();
    await settle(fixture);
    expect(paths).toHaveLength(3);
    expect(paths[2]).toBe(paths[1]);
  });

  it('the store opens on the declared defaults and sends nothing until the form is used', () => {
    const search = new CodeListSearch(CLASSES.read?.criteria?.fields ?? []);
    expect(search.criteria()).toEqual({});
    expect(search.value('pattern')).toBe('*');
    expect(search.checked('mapped')).toBe(true);
    search.setChecked('mapped', false);
    search.useForm();
    expect(search.criteria()).toEqual({ pattern: '*', system: 'no', generated: 'no', mapped: 'no', from: '', to: '' });
    expect((CLASSES.read?.criteria?.fields ?? []).filter(isYesNo).map((field) => field.param)).toEqual(['system', 'generated', 'mapped']);
  });
});

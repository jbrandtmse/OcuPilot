import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, Router, convertToParamMap, provideRouter } from '@angular/router';
import { BehaviorSubject } from 'rxjs';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import type { ConnectivityService } from '../../core/connectivity';
import { joinCompositeId } from '../../core/entity-id';
import { NavigationService } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { ScreenArrivals } from '../../core/screen-arrival';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS, type ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { HistoryPage } from './history.page';
import { stubAccountPreferences } from '../../testing/account-preferences';

/**
 * Task history, across every task, wired end to end over stubs of the URL's screen and the HTTP
 * answer, with the real `RefreshService`, `ScreenStores`, `createScreenRead`, `DataTable` and
 * `Dialog` (AC1, AC3, AC4) -- the same shape `audit.page.spec.ts` takes.
 *
 * **It renders the shipped descriptor**, read straight out of the mirror, so the criteria and the
 * fields the dialog lists are the ones the instance validates.
 *
 * Mutations (Rule 19), each applied and observed red here alone:
 * make the page skip its open read -> "opens on one default read" red; drop
 * the `userOnly` translation to `'1'` -> "the checkbox sends userOnly=1 only when checked" red;
 * make `heldFor` hand back a fresh `TaskHistorySearch` on every call -> "re-reads on a return to the
 * screen" red; drop a `FIELD_LABEL_KEYS` entry -> "opens the detail dialog ... under its own label"
 * red. `boundRead` bypassing `TaskHistorySearch.readFor` turns nothing here red, because these
 * dialog tests move `paramMap` on one instance rather than re-creating the page; the browser AC3
 * leg pins it ("no second read for the dialog").
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

const HISTORY = SCREENS.find(
  (screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.TaskHistoryList'
) as ScreenDeclaration;

/** One task-run history row, carrying every field the table and the dialog read. */
const row = (name: string, overrides: Record<string, unknown> = {}) => ({
  LastStart: '2026-09-16 03:00:00',
  Completed: '2026-09-16 03:00:05',
  Name: name,
  Status: 0,
  Result: 'Success',
  TaskId: 12,
  Namespace: 'HSCUSTOM',
  Routine: 'OcuPilot.Demo.Task',
  Pid: '4321',
  ErrDate: '',
  ErrNumber: '',
  Username: '_SYSTEM',
  LogDatetime: '2026-09-16 03:00:05',
  ...overrides,
});

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 20));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

const planted: HTMLElement[] = [];

/** The since the stub instance applies when a read omits it: its own now less 168 hours. */
const DEFAULT_SINCE = '2026-09-19 12:00:00';

/** The criteria an instance would echo for `path`: each sent value, since's default, else empty. */
function echoFor(path: string): Record<string, string> {
  const query = new URLSearchParams(path.split('?')[1] ?? '');
  const applied: Record<string, string> = {};
  for (const field of HISTORY.read?.criteria?.fields ?? []) {
    const sent = query.get(field.param);
    applied[field.param] = sent !== null ? sent : field.param === 'since' ? DEFAULT_SINCE : '';
  }
  return applied;
}

async function mount(initialRows: unknown[] = [row('OcuPilotDemoTask')], arrivals: ScreenArrivals | null = null) {
  TestBed.resetTestingModule();
  let answerRows = initialRows;
  const paths: string[] = [];
  const api = {
    requestJson: async <T,>(path: string): Promise<JsonResult<T>> => {
      paths.push(path);
      return {
        kind: 'ok',
        status: 200,
        body: { fields: [], rows: answerRows, truncated: false, banner: '', criteria: echoFor(path) } as T,
      };
    },
  };
  const scheduled: (() => void)[] = [];
  const params = new BehaviorSubject(convertToParamMap({}));
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  const refresh = new RefreshService({
    stores,
    connectivity: { retryWhenReachable: () => {} } as unknown as ConnectivityService,
    bus: new ChangeBus(),
    namespace: () => 'HSCUSTOM',
    schedule: (run) => scheduled.push(run),
  });
  TestBed.configureTestingModule({
    providers: [
      provideRouter([
        { path: 'tasks/history', children: [] },
        { path: 'tasks/history/:id', children: [] },
        { path: '**', children: [] },
      ]),
      { provide: NavigationService, useValue: { screenForUrl: () => HISTORY } as unknown as NavigationService },
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: RefreshService, useValue: refresh },
      { provide: ScreenStores, useValue: stores },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: OverlayStack, useValue: new OverlayStack() },
      {
        provide: ScopeService,
        useValue: { loaded: () => true, namespace: () => 'HSCUSTOM', subscribe: () => () => {} } as unknown as ScopeService,
      },
      { provide: ActivatedRoute, useValue: { paramMap: params } as unknown as ActivatedRoute },
      ...(arrivals === null ? [] : [{ provide: ScreenArrivals, useValue: arrivals }]),
    ],
  });
  const router = TestBed.inject(Router);
  await router.navigateByUrl('/tasks/history?ns=HSCUSTOM');
  const fixture = TestBed.createComponent(HistoryPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  const host = fixture.nativeElement as HTMLElement;
  return {
    fixture,
    host,
    paths,
    router,
    refresh,
    actions: TestBed.inject(ScreenActions),
    revisit: async () => {
      fixture.destroy();
      refresh.unbind();
      const next = TestBed.createComponent(HistoryPage);
      document.body.appendChild(next.nativeElement);
      planted.push(next.nativeElement);
      next.detectChanges();
      await settle(next);
      return { fixture: next, host: next.nativeElement as HTMLElement };
    },
    setRows: (next: unknown[]) => (answerRows = next),
    openId: async (id: string) => {
      params.next(convertToParamMap({ id }));
      await settle(fixture);
    },
    search: async () => {
      (host.querySelector('.ocu-criteria-controls button[type="submit"]') as HTMLElement).click();
      await settle(fixture);
    },
    typeSince: async (value: string) => {
      const field = host.querySelector('#ocu-task-history-since') as HTMLInputElement;
      field.value = value;
      field.dispatchEvent(new Event('input', { bubbles: true }));
      await settle(fixture);
    },
    typeSearch: async (value: string) => {
      const field = host.querySelector('#ocu-task-history-search') as HTMLInputElement;
      field.value = value;
      field.dispatchEvent(new Event('input', { bubbles: true }));
      await settle(fixture);
    },
    toggleUserOnly: async (on: boolean) => {
      const box = host.querySelector('[data-ocu-user-only="1"]') as HTMLInputElement;
      box.checked = on;
      box.dispatchEvent(new Event('change', { bubbles: true }));
      await settle(fixture);
    },
  };
}

const rowNames = (host: HTMLElement) =>
  Array.from(host.querySelectorAll('.ocu-data-table-body [role="row"]')).map((element) =>
    (element.querySelector('[role="gridcell"]:nth-child(3)') as HTMLElement | null)?.textContent?.trim() ?? ''
  );

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
});

describe('task history, across every task', () => {
  it('Story 11.11: opens on one default read, and shows the since the instance applied', async () => {
    const { host, paths } = await mount();
    expect(paths).toEqual(['/api/ocupilot/screens/tasks.history/read?maxRows=1000']);
    expect(host.querySelector('[role="grid"]')).not.toBeNull();
    expect(host.querySelector('.ocu-data-table-skeleton')).toBeNull();
    expect(rowNames(host)).toEqual(['OcuPilotDemoTask']);
    const label = host.querySelector('label[for="ocu-task-history-search"]');
    expect(label?.textContent?.trim()).toBe(STRINGS.taskHistorySearch);
    const sinceLabel = host.querySelector('label[for="ocu-task-history-since"]');
    expect(sinceLabel?.textContent?.trim()).toBe(STRINGS.taskHistorySince);
    expect((host.querySelector('#ocu-task-history-since') as HTMLInputElement).value).toBe(DEFAULT_SINCE);
    expect(host.querySelector('.ocu-criteria-hint')?.textContent?.trim()).toBe(STRINGS.auditCriteriaTimeHint);
    const box = host.querySelector('[data-ocu-user-only="1"]') as HTMLInputElement;
    expect(box.checked).toBe(false);
    expect(host.querySelector('.ocu-criteria-marker')?.textContent).toContain(STRINGS.taskHistoryUserOnly);
  });

  it('Search sends the form as shown in one read, and renders the answered rows', async () => {
    const { paths, search, typeSearch, typeSince, host } = await mount([row('OcuPilotDemoTask')]);
    await typeSearch('OcuPilotDemo');
    await typeSince('');
    await search();
    expect(paths).toHaveLength(2);
    expect(paths[1]).toContain('/screens/tasks.history/read?maxRows=1000');
    expect(paths[1]).toContain('&search=OcuPilotDemo');
    expect(paths[1]).toContain('&userOnly=&');
    expect(paths[1]).toMatch(/&since=$/);
    expect(host.querySelector('[role="grid"]')).not.toBeNull();
    expect(rowNames(host)).toEqual(['OcuPilotDemoTask']);
  });

  it('the checkbox sends userOnly=1 when checked, and an unset userOnly otherwise', async () => {
    const { paths, search, toggleUserOnly } = await mount([]);
    await toggleUserOnly(true);
    await search();
    expect(paths[1]).toContain('&userOnly=1');
    await toggleUserOnly(false);
    await search();
    expect(paths[2]).toContain('&userOnly=&');
  });

  it('Story 11.11: an agent arrival runs exactly its criteria as the one read', async () => {
    const arrivals = new ScreenArrivals();
    arrivals.set({ route: 'tasks/history', criterion: '', criteria: { search: 'OcuPilotProbeRunTask', since: '' } });
    const { host, paths } = await mount([row('OcuPilotProbeRunTask')], arrivals);
    expect(paths).toEqual(['/api/ocupilot/screens/tasks.history/read?maxRows=1000&search=OcuPilotProbeRunTask&since=']);
    expect((host.querySelector('#ocu-task-history-search') as HTMLInputElement).value).toBe('OcuPilotProbeRunTask');
    expect((host.querySelector('#ocu-task-history-since') as HTMLInputElement).value).toBe('');
    expect(rowNames(host)).toEqual(['OcuPilotProbeRunTask']);
  });

  it('Story 11.11: a return after an arrival re-runs the default when the person never searched', async () => {
    // Mutation (Rule 19): make `TaskHistorySearch.useDefault` keep the arrival's mode -> the return
    // re-sends the arrival's search, so this goes red.
    const arrivals = new ScreenArrivals();
    arrivals.set({ route: 'tasks/history', criterion: '', criteria: { search: 'OcuPilotProbeRunTask', since: '' } });
    const { paths, revisit } = await mount([row('OcuPilotProbeRunTask')], arrivals);
    expect(paths).toHaveLength(1);
    const again = await revisit();
    expect(paths).toEqual([
      '/api/ocupilot/screens/tasks.history/read?maxRows=1000&search=OcuPilotProbeRunTask&since=',
      '/api/ocupilot/screens/tasks.history/read?maxRows=1000',
    ]);
    expect((again.host.querySelector('#ocu-task-history-search') as HTMLInputElement).value).toBe('');
    expect((again.host.querySelector('#ocu-task-history-since') as HTMLInputElement).value).toBe(DEFAULT_SINCE);
  });

  it('opens the detail dialog listing every declared read field under its own label, with no second request, and renders none for a key no row carries', async () => {
    const failed = row('OcuPilotDemoTask', {
      Status: 1,
      Result: '<THROW> demo failure',
      ErrDate: '2026-09-16',
      ErrNumber: '5',
    });
    const { host, search, paths, openId } = await mount([failed]);
    await search();
    expect(rowNames(host)).toEqual(['OcuPilotDemoTask']);
    const before = paths.length;

    const link = host.querySelector('.ocu-data-table-body a') as HTMLAnchorElement;
    expect(link).not.toBeNull();
    expect(link.getAttribute('href')).toContain('/tasks/history/');

    await openId(joinCompositeId(['12', '2026-09-16 03:00:05', '1']));
    const dialog = host.querySelector('[role="dialog"]') as HTMLElement;
    expect(dialog).not.toBeNull();
    expect(dialog.textContent).toContain(STRINGS.taskHistoryLabel);
    expect(dialog.textContent).toContain('<THROW> demo failure');
    expect(dialog.textContent).toContain(STRINGS.errorLogColumnNumber);
    const labels = Array.from(dialog.querySelectorAll('.ocu-dialog-field')).map((field) => field.textContent?.trim() ?? '');
    expect(labels).toHaveLength(HISTORY.read?.fields.length ?? -1);
    expect(labels.filter((label) => label === '')).toEqual([]);
    // No second request: every field the dialog shows is already in the row the list read.
    expect(paths).toHaveLength(before);

    await openId('no-such-row');
    expect(host.querySelector('[role="dialog"]')).toBeNull();
  });

  it('closing the dialog restores the searched rows without a new read', async () => {
    const { host, search, paths, openId } = await mount([row('OcuPilotDemoTask')]);
    await search();
    expect(paths).toHaveLength(2);
    await openId(joinCompositeId(['12', '2026-09-16 03:00:05', '0']));
    expect(host.querySelector('[role="dialog"]')).not.toBeNull();
    await openId('');
    expect(host.querySelector('[role="dialog"]')).toBeNull();
    // The dialog round trip re-binds the same read, so bind() is a no-op and issues nothing.
    expect(paths).toHaveLength(2);
    expect(rowNames(host)).toEqual(['OcuPilotDemoTask']);
  });

  it('DW-260: Refresh is offered from the open read, and re-runs the search the screen last issued', async () => {
    const { paths, search, typeSearch, actions } = await mount([row('OcuPilotDemoTask')]);
    expect(actions.has(HISTORY.descriptor, REFRESH_ACTION_ID)).toBe(true);
    await typeSearch('OcuPilotDemo');
    await search();
    expect(paths).toHaveLength(2);
    actions.run(HISTORY.descriptor, REFRESH_ACTION_ID);
    await new Promise((resolve) => setTimeout(resolve, 20));
    expect(paths).toHaveLength(3);
    expect(paths[2]).toContain('&search=OcuPilotDemo');
  });

  it('a return re-runs the last Search, rather than rendering a skeleton nothing resolves', async () => {
    const { paths, search, typeSearch, revisit } = await mount([row('OcuPilotDemoTask')]);
    await typeSearch('OcuPilotDemo');
    await search();
    expect(paths).toHaveLength(2);
    const again = await revisit();
    expect(paths).toHaveLength(3);
    expect(paths[2]).toContain('&search=OcuPilotDemo');
    expect(again.host.querySelector('.ocu-data-table-skeleton')).toBeNull();
    expect(rowNames(again.host)).toEqual(['OcuPilotDemoTask']);
  });
});

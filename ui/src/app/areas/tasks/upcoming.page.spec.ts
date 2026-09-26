import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import type { ConnectivityService } from '../../core/connectivity';
import { NavigationService } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { UpcomingPage } from './upcoming.page';
import { localDateText } from './upcoming.store';
import { stubAccountPreferences } from '../../testing/account-preferences';

/**
 * The Upcoming tasks page over the generated declaration and a stub of the HTTP answers: the real
 * `RefreshService`, `ScreenStores`, `createScreenRead` and `DataTable` run, so the assertions are
 * about the request paths issued and the rendered DOM (AC3).
 */

const DESCRIPTOR = 'OcuPilot.Screen.Descriptor.TaskUpcomingList';

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

const ROWS = [
  { Id: 2, Name: 'Later', Namespace: '%SYS', Datetime: '2026-09-17 03:00:00', Suspended: false },
  { Id: 1, Name: 'Sooner', Namespace: '%SYS', Datetime: '2026-09-17 01:00:00', Suspended: true },
];

/** Mount the page; every answer after the first waits for `held`, when one is given. */
async function mount(held: Promise<void> | null = null) {
  TestBed.resetTestingModule();
  const declaration = SCREENS.find((screen) => screen.descriptor === DESCRIPTOR) ?? null;
  const paths: string[] = [];
  const api = {
    requestJson: async <T,>(path: string): Promise<JsonResult<T>> => {
      paths.push(path);
      if (held !== null && paths.length > 1) await held;
      return { kind: 'ok', status: 200, body: { fields: [], rows: ROWS, truncated: false, banner: '' } as T };
    },
  };
  const bus = new ChangeBus();
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
      { provide: NavigationService, useValue: { screenForUrl: () => declaration } as unknown as NavigationService },
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: RefreshService, useValue: refresh },
      { provide: ScreenStores, useValue: stores },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: OverlayStack, useValue: new OverlayStack() },
      {
        provide: ScopeService,
        useValue: { loaded: () => true, namespace: () => 'HSCUSTOM', subscribe: () => () => {} } as unknown as ScopeService,
      },
    ],
  });
  await TestBed.inject(Router).navigateByUrl('/tasks/upcoming?ns=HSCUSTOM');
  const fixture = TestBed.createComponent(UpcomingPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  return { fixture, paths, actions: TestBed.inject(ScreenActions), host: fixture.nativeElement as HTMLElement };
}

function select(host: HTMLElement): HTMLSelectElement {
  return host.querySelector('#ocu-upcoming-horizon') as HTMLSelectElement;
}

function renderedRows(host: HTMLElement): Element[] {
  return Array.from(host.querySelectorAll('.ocu-data-table-body [role="row"]'));
}

function dateInput(host: HTMLElement): HTMLInputElement {
  return host.querySelector('#ocu-upcoming-date') as HTMLInputElement;
}

function choose(element: HTMLSelectElement | HTMLInputElement, value: string): void {
  element.value = value;
  element.dispatchEvent(new Event('change'));
}

function dayFromToday(offset: number): string {
  const day = new Date();
  day.setDate(day.getDate() + offset);
  return localDateText(day);
}

afterEach(() => {
  for (const element of planted.splice(0)) element.remove();
});

describe('UpcomingPage', () => {
  it('AC3: reads once at 24 hours on open and renders the occurrences in ascending Scheduled for', async () => {
    const { paths, host } = await mount();
    expect(paths).toHaveLength(1);
    expect(paths[0]).toContain('/screens/tasks.upcoming/read?');
    expect(paths[0]).toContain('&hoursOffset=24');
    expect(paths[0]).not.toContain('toDatetime');
    expect(select(host).value).toBe('24');
    expect(dateInput(host).disabled).toBe(true);
    const labels = Array.from(select(host).options).map((option) => option.textContent?.trim());
    expect(labels).toEqual([
      STRINGS.taskUpcomingHours1,
      STRINGS.taskUpcomingHours4,
      STRINGS.taskUpcomingHours12,
      STRINGS.taskUpcomingHours24,
      STRINGS.taskUpcomingHours72,
      STRINGS.taskUpcomingHours168,
      STRINGS.taskUpcomingUntil,
    ]);
    const cells = Array.from(host.querySelectorAll('.ocu-data-table-body [role="row"]')).map(
      (row) => row.querySelector('[role="gridcell"]')?.textContent?.trim()
    );
    expect(cells).toEqual(['2026-09-17 01:00:00', '2026-09-17 03:00:00']);
  });

  it('AC3: choosing the next hour re-reads with hoursOffset=1', async () => {
    const { fixture, paths, host } = await mount();
    choose(select(host), '1');
    await settle(fixture);
    expect(paths).toHaveLength(2);
    expect(paths[1]).toContain('&hoursOffset=1');
    expect(paths[1]).not.toContain('toDatetime');
  });

  it('a horizon change clears the rows before the new answer lands', async () => {
    let release: () => void = () => {};
    const held = new Promise<void>((resolve) => {
      release = resolve;
    });
    const { fixture, paths, host } = await mount(held);
    expect(renderedRows(host)).toHaveLength(2);
    choose(select(host), '1');
    await settle(fixture);
    expect(paths).toHaveLength(2);
    expect(renderedRows(host)).toHaveLength(0);
    release();
    await settle(fixture);
    expect(renderedRows(host)).toHaveLength(2);
  });

  it('a page re-created over the same store, as a name link does, keeps the chosen horizon', async () => {
    const { fixture, paths, host } = await mount();
    choose(select(host), '168');
    await settle(fixture);
    fixture.destroy();
    const again = TestBed.createComponent(UpcomingPage);
    planted.push(again.nativeElement);
    again.detectChanges();
    await settle(again);
    expect(paths).toHaveLength(3);
    expect(paths[2]).toContain('&hoursOffset=168');
    expect(select(again.nativeElement as HTMLElement).value).toBe('168');
  });

  it('AC3: Until a date reads nothing until a date is chosen, then reads to the end of that day alone', async () => {
    const { fixture, paths, host } = await mount();
    choose(select(host), 'date');
    await settle(fixture);
    expect(paths).toHaveLength(1);
    expect(dateInput(host).disabled).toBe(false);
    expect(dateInput(host).min).toBe(localDateText(new Date()));

    const tomorrow = dayFromToday(1);
    choose(dateInput(host), tomorrow);
    await settle(fixture);
    expect(paths).toHaveLength(2);
    expect(paths[1]).toContain('&toDatetime=' + encodeURIComponent(`${tomorrow} 23:59:59`));
    expect(paths[1]).not.toContain('hoursOffset');
  });

  it('a date before today reads nothing', async () => {
    const { fixture, paths, host } = await mount();
    choose(select(host), 'date');
    choose(dateInput(host), dayFromToday(-1));
    await settle(fixture);
    expect(paths).toHaveLength(1);
  });

  it('offers Refresh and no other action (AD-10)', async () => {
    const { actions } = await mount();
    expect(actions.has(DESCRIPTOR, REFRESH_ACTION_ID)).toBe(true);
    const declaration = SCREENS.find((screen) => screen.descriptor === DESCRIPTOR);
    expect(declaration?.rowActions).toEqual([]);
    expect(declaration?.primaryAction.id).toBe('');
  });
});

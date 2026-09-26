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
import { STRINGS, stringFor } from '../../core/strings';
import { SystemUsagePage } from './system-usage.page';
import { stubAccountPreferences } from '../../testing/account-preferences';

/**
 * System usage (Story 6.9), wired end to end over a stub of the HTTP answer, with the real
 * `RefreshService`, `ScreenStores` and `createScreenRead` -- the same shape
 * `process-details.page.spec.ts` takes. It renders the shipped descriptor, read straight out of
 * the mirror, so the field list is the one the instance validates.
 *
 * Mutations (Rule 19): drop `Usage.BlockReads` from the row fixture below -> the AC1 counters
 * assertion goes red, reading "(none)" instead of the fixture's number. Change the warning
 * meter's fixture percentage from 90 to 80 -> the AC2 warning-coloring assertion goes red, since
 * 80 is below the 85 cut-off. Omit the refresh binding in `SystemUsagePage` -> AC3's tick
 * assertion goes red with no second read.
 */

const DESCRIPTOR = 'OcuPilot.Screen.Descriptor.SystemUsage';
const READ_PATH = '/api/ocupilot/screens/osmgmt.systemusage/read';

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

/** One System usage row, carrying every field the descriptor declares. */
function row(overrides: Record<string, unknown> = {}) {
  return {
    'Usage.AllGlobalReferences': 111111,
    'Usage.GlobalUpdateReferences': 22222,
    'Usage.RoutineCalls': 33333,
    'Usage.LogicalBlockRequests': 44444,
    'Usage.BlockReads': 55555,
    'Usage.BlockWrites': 66666,
    'Usage.JournalEntries': 7777,
    'Usage.JournalBlockWrites': 8888,
    'Usage.LastUpdate': '2026-09-17 10:30:00',
    'SharedMemory.SMHAllocated': 1000,
    'SharedMemory.SMHUsed': 400,
    'SharedMemory.SMHAvailable': 600,
    'Dashboard.Performance.GlobalRefsPerSecond': 42.5,
    'Dashboard.Performance.CacheEfficiency': 99.1,
    'Dashboard.SystemUsage.DatabaseSpace': 'Normal',
    'Dashboard.SystemUsage.JournalSpace': 'Normal',
    'Dashboard.SystemUsage.LockTable': 'Normal',
    'Dashboard.SystemUsage.WriteDaemon': 'Normal',
    ...overrides,
  };
}

async function mount(initialRows: unknown[] = [row()], url = '/os-management/system-usage?ns=HSCUSTOM', failFirst = false) {
  TestBed.resetTestingModule();
  const declaration = SCREENS.find((screen) => screen.descriptor === DESCRIPTOR) ?? null;
  let answerRows = initialRows;
  let failing = failFirst;
  const paths: string[] = [];
  const scheduled: (() => void)[] = [];
  const api = {
    requestJson: async <T,>(path: string): Promise<JsonResult<T>> => {
      paths.push(path);
      if (failing) return { kind: 'error', status: 500, code: 'SERVER.INTERNAL', reason: null, detail: null };
      return { kind: 'ok', status: 200, body: { fields: [], rows: answerRows, truncated: false, banner: '' } as T };
    },
  };
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
  await TestBed.inject(Router).navigateByUrl(url);
  const fixture = TestBed.createComponent(SystemUsagePage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  return {
    fixture,
    paths,
    setRows: (rows: unknown[]) => {
      answerRows = rows;
    },
    setFailing: (next: boolean) => {
      failing = next;
    },
    refresh,
    fireTick: async () => {
      scheduled[scheduled.length - 1]();
      await settle(fixture);
    },
    actions: TestBed.inject(ScreenActions),
    host: fixture.nativeElement as HTMLElement,
  };
}

function counterValue(host: HTMLElement, labelKey: string): string | null {
  const fields = Array.from(host.querySelectorAll('.ocu-details-field'));
  const target = fields.find(
    (field) => field.querySelector('.ocu-details-field-label')?.textContent?.trim() === stringFor(labelKey)
  );
  return target?.querySelector('.ocu-details-field-value')?.textContent?.trim() ?? null;
}

function meterByLabel(host: HTMLElement, label: string): HTMLElement | null {
  return (
    Array.from(host.querySelectorAll('app-meter')).find(
      (meter) => meter.querySelector('.ocu-meter-label')?.textContent?.trim() === label
    ) ?? null
  ) as HTMLElement | null;
}

afterEach(() => {
  for (const element of planted.splice(0)) element.remove();
});

describe('SystemUsagePage', () => {
  it('AC1: reads once, and renders the counters and the seven meters, with the chip offering 5/10/30/60 s', async () => {
    const { paths, host, refresh } = await mount();
    expect(paths).toHaveLength(1);
    expect(paths[0]).toContain(READ_PATH);
    expect(host.querySelector('.ocu-data-table-skeleton')).toBeNull();

    expect(counterValue(host, 'processDetailsGlobalReferences')).toBe('111111');
    expect(counterValue(host, 'systemUsageRoutineCalls')).toBe('33333');
    expect(counterValue(host, 'systemUsageBlockReads')).toBe('55555');
    expect(counterValue(host, 'systemUsageBlockWrites')).toBe('66666');
    expect(counterValue(host, 'systemUsageJournalEntries')).toBe('7777');
    expect(counterValue(host, 'systemUsageLastUpdate')).toBe('2026-09-17 10:30:00');

    expect(host.querySelectorAll('app-meter').length).toBe(7);
    const sharedMemory = meterByLabel(host, STRINGS.systemUsageSharedMemory);
    expect(sharedMemory).not.toBeNull();
    expect(sharedMemory?.querySelector('.ocu-meter-value')?.textContent?.trim()).toBe('40 %');

    expect(refresh.rates()).toEqual([5, 10, 30, 60]);
  });

  it('AC2: a meter before its first value shows a dash with a skeleton fill', async () => {
    const { host } = await mount([]);
    // Zero rows never actually happens for this descriptor (id.kind none, one row always), but
    // the pending rendering this exercises is the same one a slow first read shows in between the
    // bind and the answer landing -- covered here because the harness cannot pause a promise mid
    // flight and re-render.
    const daemon = meterByLabel(host, STRINGS.systemUsageWriteDaemon);
    expect(daemon).not.toBeNull();
    expect(daemon?.querySelector('.ocu-meter-value')?.textContent?.trim()).toBe('\u2014');
    expect(daemon?.querySelector('.ocu-meter-fill-skeleton')).not.toBeNull();
  });

  it('AC2: a warning or error state colors the fill and the value text and shows the word', async () => {
    const { host } = await mount([
      row({
        'SharedMemory.SMHUsed': 900,
        'Dashboard.SystemUsage.WriteDaemon': 'Troubled',
      }),
    ]);
    const sharedMemory = meterByLabel(host, STRINGS.systemUsageSharedMemory);
    expect(sharedMemory?.querySelector('.ocu-meter-fill')?.classList.contains('ocu-meter-fill-warning')).toBe(true);
    expect(sharedMemory?.querySelector('.ocu-meter-value')?.classList.contains('ocu-meter-value-warning')).toBe(true);
    expect(sharedMemory?.querySelector('.ocu-meter-word')?.textContent?.trim()).toBe('Warning');

    const daemon = meterByLabel(host, STRINGS.systemUsageWriteDaemon);
    expect(daemon?.querySelector('.ocu-meter-fill')?.classList.contains('ocu-meter-fill-error')).toBe(true);
    expect(daemon?.querySelector('.ocu-meter-word')?.classList.contains('ocu-meter-word-error')).toBe(true);
    expect(daemon?.querySelector('.ocu-meter-word')?.textContent?.trim()).toBe('Troubled');
    expect(daemon?.querySelector('.ocu-meter-value')).toBeNull();
  });

  it('AC3: with the chip at 5 s a timer tick re-reads silently, with no skeleton and no aria-live', async () => {
    const { paths, refresh, setRows, fireTick, host } = await mount();
    expect(refresh.setRate(5)).toBe(true);
    setRows([row({ 'Usage.AllGlobalReferences': 222222 })]);
    await fireTick();
    expect(paths).toHaveLength(2);
    expect(counterValue(host, 'processDetailsGlobalReferences')).toBe('222222');
    expect(host.querySelector('.ocu-data-table-skeleton')).toBeNull();
    expect(host.querySelector('[role="alert"]')).toBeNull();
    // "No announcement" (AC3): no element in this page ever carries `aria-live`, the same
    // guarantee `process-details.page.spec.ts` asserts for its own silent tick.
    expect(host.querySelector('[aria-live]')).toBeNull();
  });

  it('a read fault before any success leaves no skeleton and nothing busy, and every meter shows a dash with the tooltip', async () => {
    const { host } = await mount([row()], '/os-management/system-usage?ns=HSCUSTOM', true);
    expect(host.querySelector('.ocu-data-table-skeleton')).toBeNull();
    expect(host.querySelector('[aria-busy="true"]')).toBeNull();
    const daemon = meterByLabel(host, STRINGS.systemUsageWriteDaemon);
    expect(daemon?.querySelector('.ocu-meter-value')?.textContent?.trim()).toBe('\u2014');
    expect(daemon?.getAttribute('title')).toBe(STRINGS.connectivityRequestRefused);
  });

  it('a read fault after a success keeps every counter and the last word and color on each meter, dashes the number, and carries the tooltip', async () => {
    const { actions, fixture, host, setFailing } = await mount();
    expect(counterValue(host, 'processDetailsGlobalReferences')).toBe('111111');
    setFailing(true);
    expect(actions.run(DESCRIPTOR, REFRESH_ACTION_ID)).toBe(true);
    await settle(fixture);

    // The counters group is unaffected by a fault -- it renders straight from the store's data,
    // which a fault never overwrites.
    expect(counterValue(host, 'processDetailsGlobalReferences')).toBe('111111');

    const sharedMemory = meterByLabel(host, STRINGS.systemUsageSharedMemory);
    expect(sharedMemory?.getAttribute('title')).toBe(STRINGS.connectivityRequestRefused);
    // The number is dashed by the fault; the word (the qualitative signal) is kept.
    expect(sharedMemory?.querySelector('.ocu-meter-value')?.textContent?.trim()).toBe('\u2014');
    expect(sharedMemory?.querySelector('.ocu-meter-word')?.textContent?.trim()).toBe('Normal');
    expect(host.querySelector('.ocu-data-table-skeleton')).toBeNull();
  });

  it('offers Refresh and no other action', async () => {
    const { actions } = await mount();
    expect(actions.has(DESCRIPTOR, REFRESH_ACTION_ID)).toBe(true);
    const declaration = SCREENS.find((screen) => screen.descriptor === DESCRIPTOR);
    expect(declaration?.rowActions).toEqual([]);
    expect(declaration?.primaryAction.id).toBe('');
  });
});

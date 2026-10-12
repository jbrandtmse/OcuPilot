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
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { StatisticsPage } from './statistics.page';
import { stubAccountPreferences } from '../../testing/account-preferences';

/**
 * Global and routine statistics and ECP statistics (Story 18.36), wired end to end over a stub of the HTTP
 * answer, with the real `RefreshService`, `ScreenStores` and `createScreenRead` -- the shape
 * `system-usage.page.spec.ts` takes. It renders the shipped descriptors out of the mirror, so the fields and
 * their labels are the ones the instance validates.
 *
 * Mutations (Rule 19): list the fields as one flat group in `statistics.store.ts` -> the group and the
 * repeated-field cases go red. Drop the skeleton from the page -> the busy case goes red. Label a group through
 * the wrong key in `STATISTICS_GROUPS` -> the heading cases go red.
 */

const GLOBALS = 'OcuPilot.Screen.Descriptor.DashboardGlobals';
const ECP = 'OcuPilot.Screen.Descriptor.DashboardEcp';

/** The field-to-label table of each statistics screen, written out here rather than read from the descriptor. */
const LABELS: Readonly<Record<string, ReadonlyArray<readonly [string, string]>>> = {
  [GLOBALS]: [
    ['Statistics.Globals.RefLocal', STRINGS.statsGlobalReferencesLocal],
    ['Statistics.Globals.RefUpdateLocal', STRINGS.statsGlobalUpdatesLocal],
    ['Statistics.Globals.RefRemote', STRINGS.statsGlobalReferencesRemote],
    ['Statistics.Globals.RefUpdateRemote', STRINGS.statsGlobalUpdatesRemote],
    ['Statistics.Globals.RefPrivate', STRINGS.processDetailsPrivateGlobalReferences],
    ['Statistics.Globals.RefUpdatePrivate', STRINGS.statsGlobalUpdatesPrivate],
    ['Statistics.Globals.LogicalBlocks', STRINGS.systemUsageLogicalBlockRequests],
    ['Statistics.Globals.PhysBlockReads', STRINGS.systemUsageBlockReads],
    ['Statistics.Globals.PhysBlockWrites', STRINGS.systemUsageBlockWrites],
    ['Statistics.Globals.WIJWrites', STRINGS.statsWriteImageJournalWrites],
    ['Statistics.Globals.JrnEntries', STRINGS.systemUsageJournalEntries],
    ['Statistics.Globals.JrnBlocks', STRINGS.systemUsageJournalBlockWrites],
    ['Statistics.Routines.RtnCallsLocal', STRINGS.statsRoutineCallsLocal],
    ['Statistics.Routines.RtnFetchLocal', STRINGS.statsRoutineLoadsLocal],
    ['Statistics.Routines.RtnCallsRemote', STRINGS.statsRoutineCallsRemote],
    ['Statistics.Routines.RtnFetchRemote', STRINGS.statsRoutineLoadsRemote],
    ['Statistics.Routines.RtnCommands', STRINGS.statsRoutineCommands],
    ['Statistics.Routines.RtnNotCached', STRINGS.statsRoutinesNotCached],
  ],
  [ECP]: [
    ['Ecp.AppServer.MaxConn', STRINGS.licenseUsageMaxConnections],
    ['Ecp.AppServer.ActConn', STRINGS.statsEcpActiveConnections],
    ['Ecp.AppServer.GloRef', STRINGS.processDetailsGlobalReferences],
    ['Ecp.AppServer.ByteSent', STRINGS.statsEcpBytesSent],
    ['Ecp.AppServer.ByteRcvd', STRINGS.statsEcpBytesReceived],
    ['Ecp.AppServer.BlockAdd', STRINGS.statsEcpBlocksAdded],
    ['Ecp.AppServer.BlockBuffPurge', STRINGS.statsEcpBlocksPurgedForBuffers],
    ['Ecp.AppServer.BlockSvrPurge', STRINGS.statsEcpBlocksPurgedByDataServer],
    ['Ecp.AppServer.GloRefLocal', STRINGS.statsGlobalReferencesLocal],
    ['Ecp.AppServer.GloRefRemote', STRINGS.statsGlobalReferencesRemote],
    ['Ecp.AppServer.GloUpdateLocal', STRINGS.statsGlobalUpdatesLocal],
    ['Ecp.AppServer.GloUpdateRemote', STRINGS.statsGlobalUpdatesRemote],
    ['Ecp.AppServer.RoutineCallLocal', STRINGS.statsRoutineCallsLocal],
    ['Ecp.AppServer.RoutineCallRemote', STRINGS.statsRoutineCallsRemote],
    ['Ecp.AppServer.RoutineBuffLocal', STRINGS.statsRoutineLoadsLocal],
    ['Ecp.AppServer.RoutineBuffRemote', STRINGS.statsRoutineLoadsRemote],
    ['Ecp.DataServer.MaxConn', STRINGS.licenseUsageMaxConnections],
    ['Ecp.DataServer.ActConn', STRINGS.statsEcpActiveConnections],
    ['Ecp.DataServer.GloRef', STRINGS.processDetailsGlobalReferences],
    ['Ecp.DataServer.ByteSent', STRINGS.statsEcpBytesSent],
    ['Ecp.DataServer.ByteRcvd', STRINGS.statsEcpBytesReceived],
    ['Ecp.DataServer.GloUpdate', STRINGS.systemUsageGlobalUpdates],
    ['Ecp.DataServer.ReqRcvd', STRINGS.statsEcpRequestsReceived],
    ['Ecp.DataServer.ReqBuff', STRINGS.statsEcpRequestBuffers],
    ['Ecp.DataServer.BlockSent', STRINGS.statsEcpBlocksSent],
    ['Ecp.DataServer.LockGrant', STRINGS.statsEcpLocksGranted],
    ['Ecp.DataServer.LockFail', STRINGS.statsEcpLocksFailed],
    ['Ecp.DataServer.LockQueGrant', STRINGS.statsEcpQueuedLocksGranted],
    ['Ecp.DataServer.LockQueFail', STRINGS.statsEcpQueuedLocksFailed],
    ['Ecp.DataServer.SvrBlockPurge', STRINGS.statsEcpBlockPurgesRequested],
    ['Ecp.DataServer.RoutinePurge', STRINGS.statsEcpRoutinePurgesSent],
    ['Ecp.DataServer.BigKill', STRINGS.statsEcpBigKills],
    ['Ecp.DataServer.BigString', STRINGS.statsEcpBigStrings],
  ],
};

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 20));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

const planted: HTMLElement[] = [];

/** One row carrying every field `descriptor` declares, each a number of its own: its position plus ten. */
function rowFor(descriptor: string): Record<string, number> {
  const columns = SCREENS.find((screen) => screen.descriptor === descriptor)?.table?.columns ?? [];
  return Object.fromEntries(columns.map((column, index) => [column.field, index + 10]));
}

interface MountOptions {
  readonly rows?: unknown[];
  /** The first read answers a 500. */
  readonly failFirst?: boolean;
  /** The first read never answers. */
  readonly hold?: boolean;
}

async function mount(descriptor: string, options: MountOptions = {}) {
  TestBed.resetTestingModule();
  const declaration = SCREENS.find((screen) => screen.descriptor === descriptor) ?? null;
  let answerRows = options.rows ?? [rowFor(descriptor)];
  let failing = options.failFirst === true;
  const paths: string[] = [];
  const api = {
    requestJson: async <T,>(path: string): Promise<JsonResult<T>> => {
      paths.push(path);
      if (options.hold === true) return new Promise<JsonResult<T>>(() => {});
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
  await TestBed.inject(Router).navigateByUrl(`/${declaration?.route ?? ''}?ns=HSCUSTOM`);
  const fixture = TestBed.createComponent(StatisticsPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  return {
    fixture,
    paths,
    refresh,
    setFailing: (next: boolean) => {
      failing = next;
    },
    setRows: (rows: unknown[]) => {
      answerRows = rows;
    },
    host: fixture.nativeElement as HTMLElement,
  };
}

/** The group headings, in drawn order. */
function headings(host: HTMLElement): string[] {
  return Array.from(host.querySelectorAll('.ocu-details-group .ocu-details-heading')).map((heading) => heading.textContent?.trim() ?? '');
}

/** The label and value pairs of the group named `group`, in drawn order. */
function pairs(host: HTMLElement, group: string): string[][] {
  return Array.from(host.querySelectorAll(`[data-group="${group}"] .ocu-details-field`)).map((field) => [
    field.querySelector('.ocu-details-field-label')?.textContent?.trim() ?? '',
    field.querySelector('.ocu-details-field-value')?.textContent?.trim() ?? '',
  ]);
}

afterEach(() => {
  for (const element of planted.splice(0)) element.remove();
});

describe('StatisticsPage', () => {
  it('reads once and draws Global and routine statistics as a Globals group of twelve and a Routines group of six, in declared order', async () => {
    const { host, paths, refresh } = await mount(GLOBALS);
    expect(paths).toHaveLength(1);
    expect(paths[0]).toContain('/api/ocupilot/screens/osmgmt.globalstatistics/read');
    expect(headings(host)).toEqual([STRINGS.processColumnGlobals, STRINGS.explorerRoutineListLabel]);
    const globals = pairs(host, 'Globals');
    const routines = pairs(host, 'Routines');
    expect(globals).toHaveLength(12);
    expect(routines).toHaveLength(6);
    expect(globals[0]).toEqual([STRINGS.statsGlobalReferencesLocal, '10']);
    expect(globals[6]).toEqual([STRINGS.systemUsageLogicalBlockRequests, '16']);
    expect(globals[11]).toEqual([STRINGS.systemUsageJournalBlockWrites, '21']);
    expect(routines.map((pair) => pair[0])).toEqual([
      STRINGS.statsRoutineCallsLocal,
      STRINGS.statsRoutineLoadsLocal,
      STRINGS.statsRoutineCallsRemote,
      STRINGS.statsRoutineLoadsRemote,
      STRINGS.statsRoutineCommands,
      STRINGS.statsRoutinesNotCached,
    ]);
    expect(routines[0][1]).toBe('22');
    expect(host.querySelector('.ocu-data-table-skeleton')).toBeNull();
    expect(host.querySelector('.ocu-details-page')?.getAttribute('aria-busy')).toBe('false');
    expect(refresh.rates()).toEqual([]);
  });

  it('draws ECP statistics under Application server and Data server, a field both groups declare read in each', async () => {
    const { host } = await mount(ECP);
    expect(headings(host)).toEqual([STRINGS.statsGroupAppServer, STRINGS.remoteDatabaseServer]);
    expect(headings(host)).toEqual(['Application server', 'Data server']);
    const appServer = pairs(host, 'AppServer');
    const dataServer = pairs(host, 'DataServer');
    expect(appServer).toHaveLength(16);
    expect(dataServer).toHaveLength(17);
    // Maximum connections is the first field of both groups, and each reads its own value.
    expect(appServer[0]).toEqual([STRINGS.licenseUsageMaxConnections, '10']);
    expect(dataServer[0]).toEqual([STRINGS.licenseUsageMaxConnections, '26']);
    expect(dataServer[5]).toEqual([STRINGS.systemUsageGlobalUpdates, '31']);
    expect(host.querySelectorAll('.ocu-details-group')).toHaveLength(2);
  });

  it('draws every declared field under its own label and value, in declared order, with none blank', async () => {
    for (const descriptor of [GLOBALS, ECP]) {
      const { host } = await mount(descriptor);
      const drawn = Array.from(host.querySelectorAll('.ocu-details-field')).map((field) => [
        field.getAttribute('data-field') ?? '',
        field.querySelector('.ocu-details-field-label')?.textContent?.trim() ?? '',
        field.querySelector('.ocu-details-field-value')?.textContent?.trim() ?? '',
      ]);
      expect(drawn).toEqual(LABELS[descriptor].map(([field, label], index) => [field, label, String(index + 10)]));
      expect(drawn.every(([, label, value]) => label !== '' && value !== '')).toBe(true);
    }
  });

  it('is busy with a skeleton until the first answer lands, and draws no group meanwhile', async () => {
    const { host } = await mount(GLOBALS, { hold: true });
    expect(host.querySelector('.ocu-details-page')?.getAttribute('aria-busy')).toBe('true');
    expect(host.querySelector('.ocu-data-table-skeleton')).not.toBeNull();
    expect(host.querySelectorAll('.ocu-details-group')).toHaveLength(0);
  });

  it('shows the refusal with Retry when the first read fails, and reads again on Retry', async () => {
    const { host, paths, setFailing, fixture } = await mount(GLOBALS, { failFirst: true });
    expect(host.querySelector('.ocu-details-page')?.getAttribute('aria-busy')).toBe('false');
    expect(host.querySelector('.ocu-data-table-refusal-message')?.textContent?.trim()).toBe(STRINGS.connectivityRequestRefused);
    expect(host.querySelector('.ocu-data-table-skeleton')).toBeNull();
    expect(host.querySelectorAll('.ocu-details-group')).toHaveLength(0);
    setFailing(false);
    (host.querySelector('.ocu-data-table-refusal button') as HTMLButtonElement).click();
    await settle(fixture);
    expect(paths).toHaveLength(2);
    expect(host.querySelector('.ocu-data-table-refusal')).toBeNull();
    expect(host.querySelectorAll('.ocu-details-group')).toHaveLength(2);
  });

  it("keeps the last answer on screen through a later fault, and shows the screen's own empty text for no row", async () => {
    const { host, refresh, setFailing, fixture } = await mount(GLOBALS);
    setFailing(true);
    await refresh.readNow();
    await settle(fixture);
    expect(host.querySelectorAll('.ocu-details-group')).toHaveLength(2);
    expect(pairs(host, 'Globals')[0][1]).toBe('10');

    const empty = await mount(GLOBALS, { rows: [] });
    expect(empty.host.querySelector('[data-statistics="empty"]')?.textContent?.trim()).toBe(STRINGS.statisticsEmpty);
    expect(empty.host.querySelectorAll('.ocu-details-group')).toHaveLength(0);
  });
});

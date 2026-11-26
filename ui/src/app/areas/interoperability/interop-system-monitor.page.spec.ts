import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import type { ConnectivityService } from '../../core/connectivity';
import { NavigationService, UNGATED, type Verdict } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { InteropSystemMonitorPage } from './interop-system-monitor.page';

/**
 * System monitor (Story 24.17 Batch 5), wired end to end over a stub of the HTTP answer, with the real `RefreshService`, `ScreenStores` and `createScreenRead`, rendering the shipped descriptor out of
 * the mirror and answering each drill-down's own read for the three tables.
 *
 * Mutations (Rule 19): bind the Production monitor row's Productions running meter to `EnsJobs` -> the meters case goes red; apply a table's answer into the drill-down's own store -> the own-store case
 * goes red; drop the latest-read check in `loadTable` -> the latest-read case goes red; drop the destroyed check -> the destroyed case goes red; declare more than the one 60-second rate in `InteropSystemMonitor.cls` and regenerate the mirror -> the refresh case goes red.
 */

const DESCRIPTOR = 'OcuPilot.Screen.Descriptor.InteropSystemMonitor';
const READ_PATH = '/api/ocupilot/screens/interop.systemmonitor/read';
const PROCESSES_PATH = '/api/ocupilot/screens/interop.systemmonitorprocesses/read';
const QUEUES_PATH = '/api/ocupilot/screens/interop.systemmonitorqueues/read';
const TASKS_PATH = '/api/ocupilot/screens/interop.systemmonitortasks/read';

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 20));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

const planted: HTMLElement[] = [];

/** The dash a pending or empty meter shows, built from its code point so no non-ASCII byte enters a source file. */
const DASH = String.fromCharCode(0x2014);

/** One System monitor row, carrying every field the descriptor declares, each as the vendor's text. */
function row(overrides: Record<string, unknown> = {}) {
  return {
    EnsNamespace: 'All Namespaces',
    EnsProductionsRunning: '2',
    EnsProductionsTroubled: '1',
    EnsIncomingRequests: '12',
    EnsLastIncomingRequest: 'Today, 02:04:28PM',
    EnsOutgoingRequests: '9',
    EnsLastOutgoingRequest: '',
    Processes: '31',
    EnsJobs: '5',
    EnsVisitingJobs: '0',
    UpTime: '8d 18h 25m',
    LastBackup: 'Never',
    DatabaseSpace: 'Normal',
    DatabaseJournal: 'Warning',
    JournalSpace: 'Normal',
    JournalEntries: '3,269,289',
    LockTable: 'Normal',
    WriteDaemon: 'Normal',
    EnsActiveQueues: '4',
    SeriousAlerts: '16',
    EnsAlerts: '0',
    EnsErrors: '3',
    LicenseLimit: '8',
    LicenseUse: '13',
    LicenseUseHigh: '38',
    ...overrides,
  };
}

const PROCESS_ROWS = [{ Namespace: 'USER', Item: 'Ens.MonitorService', Pid: 18988, Commands: 4057 }];
const QUEUE_ROWS = [{ Namespace: 'USER', Queue: 'OcuPilotProbeOp', Messages: 7 }];
const TASK_ROWS = [{ Task: 'Purge journal', ScheduledFor: '13:01', Status: 'Scheduled' }];

interface MountOptions {
  readonly rows?: unknown[];
  readonly processes?: unknown[];
  readonly queues?: unknown[];
  readonly tasks?: unknown[];
  readonly hold?: boolean;
  /** A verdict per route, for the screens a case refuses; every other route is ungated. */
  readonly verdicts?: Readonly<Record<string, Verdict>>;
  /** The System monitor's own read answers a 500 from the first call. */
  readonly failFirst?: boolean;
  /** Most active queues' read answers a 500. */
  readonly queuesFail?: boolean;
  /** Most active queues' first read stays pending until `releaseFirstQueues` and then answers a row no later read does. */
  readonly holdFirstQueues?: boolean;
}

const STALE_QUEUE_ROWS = [{ Namespace: 'USER', Queue: 'StaleQueue', Messages: 99 }];

async function mount(options: MountOptions = {}) {
  TestBed.resetTestingModule();
  const declaration = SCREENS.find((screen) => screen.descriptor === DESCRIPTOR) ?? null;
  const paths: string[] = [];
  const scheduled: (() => void)[] = [];
  const answers: Record<string, unknown[]> = {
    [READ_PATH]: options.rows ?? [row()],
    [PROCESSES_PATH]: options.processes ?? PROCESS_ROWS,
    [QUEUES_PATH]: options.queues ?? QUEUE_ROWS,
    [TASKS_PATH]: options.tasks ?? TASK_ROWS,
  };
  let queuesHeld = false;
  let releaseFirstQueues: () => void = () => {};
  const api = {
    requestJson: async <T,>(path: string): Promise<JsonResult<T>> => {
      paths.push(path);
      if (options.hold === true) return new Promise<JsonResult<T>>(() => {});
      const base = path.split('?')[0];
      if (base === QUEUES_PATH && options.holdFirstQueues === true && !queuesHeld) {
        queuesHeld = true;
        return new Promise<JsonResult<T>>((resolve) => {
          releaseFirstQueues = () =>
            resolve({ kind: 'ok', status: 200, body: { fields: [], rows: STALE_QUEUE_ROWS, truncated: false, banner: '' } as T });
        });
      }
      if ((base === READ_PATH && options.failFirst === true) || (base === QUEUES_PATH && options.queuesFail === true)) {
        return { kind: 'error', status: 500, code: 'SERVER.INTERNAL', reason: null, detail: null };
      }
      return { kind: 'ok', status: 200, body: { fields: [], rows: answers[base] ?? [], truncated: false, banner: '' } as T };
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
      {
        provide: NavigationService,
        useValue: {
          screenForUrl: () => declaration,
          screenVerdict: (route: string) => options.verdicts?.[route] ?? UNGATED,
          subscribe: () => () => {},
        } as unknown as NavigationService,
      },
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
  await TestBed.inject(Router).navigateByUrl('/interoperability/system-monitor?ns=HSCUSTOM');
  const fixture = TestBed.createComponent(InteropSystemMonitorPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  return {
    fixture,
    paths,
    stores,
    host: fixture.nativeElement as HTMLElement,
    releaseFirstQueues: () => releaseFirstQueues(),
    /** One read now, as the command bar's Refresh asks for it (the tick the timer would fire reads the same). */
    fireTick: async () => {
      await refresh.readNow();
      await settle(fixture);
    },
  };
}

function meterByLabel(host: HTMLElement, label: string): HTMLElement | null {
  return (
    Array.from(host.querySelectorAll('app-meter')).find((meter) => meter.querySelector('.ocu-meter-label')?.textContent?.trim() === label) ?? null
  ) as HTMLElement | null;
}

function headings(host: HTMLElement): string[] {
  return Array.from(host.querySelectorAll('.ocu-dashboard-heading')).map((heading) => heading.textContent?.trim() ?? '');
}

afterEach(() => {
  for (const element of planted.splice(0)) element.remove();
});

describe('InteropSystemMonitorPage', () => {
  it('draws the eight group headings in the classic order, with twenty-five meters, and reads each source once', async () => {
    const { host, paths } = await mount();
    expect(headings(host)).toEqual([
      STRINGS.interopSystemMonitorGroupThroughput,
      STRINGS.interopSystemMonitorGroupJobs,
      STRINGS.interopSystemMonitorGroupTime,
      STRINGS.systemUsageLabel,
      STRINGS.interopSystemMonitorGroupQueues,
      STRINGS.dashboardGroupAlerts,
      STRINGS.dashboardGroupLicensing,
      STRINGS.dashboardGroupTasks,
    ]);
    expect(host.querySelectorAll('app-meter').length).toBe(25);
    for (const path of [READ_PATH, PROCESSES_PATH, QUEUES_PATH, TASKS_PATH]) {
      expect(paths.filter((item) => item.startsWith(path)), path).toHaveLength(1);
    }
  });

  it('draws the vendor text on each meter, its word on a status meter, and a dash for an empty value', async () => {
    const { host } = await mount();
    const running = meterByLabel(host, STRINGS.interopSystemMonitorMeterProductionsRunning);
    expect(running?.querySelector('.ocu-meter-value')?.textContent?.trim()).toBe('2');
    expect(running?.querySelector('.ocu-meter-word')).toBeNull();
    const entries = meterByLabel(host, STRINGS.systemUsageJournalEntries);
    expect(entries?.querySelector('.ocu-meter-value')?.textContent?.trim()).toBe('3,269,289');
    const journal = meterByLabel(host, STRINGS.dashboardDatabaseJournal);
    expect(journal?.querySelector('.ocu-meter-word')?.textContent?.trim()).toBe('Warning');
    expect(journal?.querySelector('.ocu-meter-fill')?.classList.contains('ocu-meter-fill-warning')).toBe(true);
    const space = meterByLabel(host, STRINGS.systemUsageDatabaseSpace);
    expect(space?.querySelector('.ocu-meter-word')?.textContent?.trim()).toBe('Normal');
    const lastOut = meterByLabel(host, STRINGS.interopSystemMonitorMeterLastOutgoing);
    expect(lastOut?.querySelector('.ocu-meter-value')?.textContent?.trim()).toBe(DASH);
  });

  it('draws each table from its drill-down: the group links to the screen and the rows show under its own labels', async () => {
    const { host } = await mount();
    const links = Array.from(host.querySelectorAll('a.ocu-details-link')).map((link) => link.getAttribute('data-drill-down'));
    expect(links).toEqual([
      'interoperability/system-monitor/processes',
      'interoperability/system-monitor/queues',
      'interoperability/system-monitor/tasks',
    ]);
    const tables = Array.from(host.querySelectorAll('table.ocu-dashboard-tasks-table'));
    expect(tables).toHaveLength(3);
    expect(Array.from(tables[0].querySelectorAll('th')).map((cell) => cell.textContent?.trim())).toEqual([
      STRINGS.headerNamespaceLabel,
      STRINGS.interopItemSettingsCriterionItem,
      STRINGS.processColumnPid,
      STRINGS.processColumnCommands,
    ]);
    expect(Array.from(tables[1].querySelectorAll('tbody td')).map((cell) => cell.textContent?.trim())).toEqual(['USER', 'OcuPilotProbeOp', '7']);
    expect(Array.from(tables[2].querySelectorAll('tbody td')).map((cell) => cell.textContent?.trim())).toEqual(['Purge journal', '13:01', 'Scheduled']);
  });

  it('shows each drill-down its empty text, and a refused table its refusal, without hiding the meters', async () => {
    const { host } = await mount({ queues: [], tasks: [], processes: [], queuesFail: true });
    const empty = Array.from(host.querySelectorAll('.ocu-dashboard-tasks-empty')).map((item) => item.textContent?.trim());
    expect(empty).toEqual([STRINGS.activeProcessesEmpty, STRINGS.interopSystemMonitorTasksEmpty]);
    expect(host.querySelectorAll('.ocu-dashboard-tasks-refused')).toHaveLength(1);
    expect(host.querySelectorAll('app-meter').length).toBe(25);
  });

  it('shows a dash with a skeleton on every meter before the first read lands', async () => {
    const { host } = await mount({ hold: true });
    const meters = Array.from(host.querySelectorAll('app-meter'));
    expect(meters).toHaveLength(25);
    for (const meter of meters) {
      // A status meter draws no value element before its answer; a value meter draws the dash.
      const readout = meter.querySelector('.ocu-meter-value');
      if (readout !== null) expect(readout.textContent?.trim()).toBe(DASH);
      expect(meter.querySelector('.ocu-meter-fill-skeleton, .ocu-meter-value-skeleton'), meter.querySelector('.ocu-meter-label')?.textContent ?? '').not.toBeNull();
    }
    expect(host.querySelectorAll('.ocu-dashboard-tasks .ocu-data-table-skeleton')).toHaveLength(3);
    expect(host.querySelector('.ocu-dashboard')?.getAttribute('aria-busy')).toBe('true');
  });

  it('gates a table whose drill-down the caller is refused: the reason shows and nothing is read for it', async () => {
    const refused: Verdict = { allowed: false, failedPair: '%DB_IRISSYS:READ' } as Verdict;
    const { host, paths } = await mount({ verdicts: { 'interoperability/system-monitor/queues': refused } });
    expect(host.querySelectorAll('.ocu-dashboard-tasks-gated')).toHaveLength(1);
    expect(paths.filter((path) => path.startsWith(QUEUES_PATH))).toHaveLength(0);
    const gated = host.querySelector('a.ocu-details-link-gated');
    expect(gated?.getAttribute('aria-disabled')).toBe('true');
    expect(gated?.getAttribute('href')).toBeNull();
  });

  it('reads the row and each table once more on a refresh tick, and keeps drawing them', async () => {
    const { host, paths, fireTick } = await mount();
    expect(meterByLabel(host, STRINGS.interopSystemMonitorMeterJobs)?.querySelector('.ocu-meter-value')?.textContent?.trim()).toBe('5');
    await fireTick();
    for (const path of [READ_PATH, PROCESSES_PATH, QUEUES_PATH, TASKS_PATH]) {
      expect(paths.filter((item) => item.startsWith(path)), path).toHaveLength(2);
    }
    expect(meterByLabel(host, STRINGS.interopSystemMonitorMeterJobs)?.querySelector('.ocu-meter-value')?.textContent?.trim()).toBe('5');
    expect(host.querySelectorAll('table.ocu-dashboard-tasks-table')).toHaveLength(3);
  });

  it('keeps each table\'s rows in the page\'s own store and leaves the drill-down screens\' stores empty', async () => {
    const { host, stores } = await mount();
    expect(Array.from(host.querySelectorAll('table.ocu-dashboard-tasks-table')[1].querySelectorAll('tbody td')).map((cell) => cell.textContent?.trim())).toEqual([
      'USER',
      'OcuPilotProbeOp',
      '7',
    ]);
    for (const suffix of ['Processes', 'Queues', 'Tasks']) {
      expect(stores.for(`${DESCRIPTOR}${suffix}`, []).data(), suffix).toHaveLength(0);
    }
  });

  it('draws the answer to the latest read of a table, and drops an earlier read that lands after it', async () => {
    const { host, fireTick, releaseFirstQueues, fixture } = await mount({ holdFirstQueues: true });
    await fireTick();
    const cells = () => Array.from(host.querySelectorAll('table.ocu-dashboard-tasks-table')[1].querySelectorAll('tbody td')).map((cell) => cell.textContent?.trim());
    expect(cells()).toEqual(['USER', 'OcuPilotProbeOp', '7']);
    releaseFirstQueues();
    await settle(fixture);
    expect(cells()).toEqual(['USER', 'OcuPilotProbeOp', '7']);
  });

  it('applies nothing for a table read that lands after the page is destroyed', async () => {
    const { fixture, stores, releaseFirstQueues } = await mount({ holdFirstQueues: true });
    fixture.destroy();
    releaseFirstQueues();
    await new Promise((resolve) => setTimeout(resolve, 50));
    expect(stores.for(`${DESCRIPTOR}#table-queues`, []).data()).toHaveLength(0);
  });

  it('declares the one 60-second refresh rate, the rate of the classic page itself', () => {
    const declaration = SCREENS.find((screen) => screen.descriptor === DESCRIPTOR);
    expect(declaration?.refreshes).toBe(true);
    expect(declaration?.refreshRates).toEqual([60]);
  });
});

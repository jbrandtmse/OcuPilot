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
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { DashboardPage } from './dashboard.page';
import { stubAccountPreferences } from '../../testing/account-preferences';

/**
 * Dashboard (Story 16.7), wired end to end over a stub of the HTTP answer, with the real
 * `RefreshService`, `ScreenStores` and `createScreenRead` -- the shape `system-usage.page.spec.ts`
 * takes. It renders the shipped descriptor out of the mirror, and answers Upcoming tasks' own read
 * for the Task manager group.
 *
 * Mutations (Rule 19): declare `refreshes: false` on `Dashboard.cls` and regenerate the mirror ->
 * the refresh case goes red, the chip offering no rate. Drop the skeleton input from the page's
 * meters -> the skeleton case goes red on the value meters. Clear the store at the start of a tick
 * -> the in-flight tick case goes red. Apply the tasks answer into Upcoming tasks' store -> the
 * AD-19 case goes red.
 */

const DESCRIPTOR = 'OcuPilot.Screen.Descriptor.Dashboard';
const READ_PATH = '/api/ocupilot/screens/osmgmt.dashboard/read';
const TASKS_PATH = '/api/ocupilot/screens/tasks.upcoming/read';

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 20));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

const planted: HTMLElement[] = [];

/** One Dashboard row, carrying every field the descriptor declares. */
function row(overrides: Record<string, unknown> = {}) {
  return {
    'Sensors.cpuUsage': 12,
    'Dashboard.Performance.GlobalRefsPerSecond': 219,
    'Dashboard.Performance.GlobalRefs': 64649129276,
    'Dashboard.Performance.GlobalSetKill': 4300249416,
    'Dashboard.Performance.RoutineRefs': 14225921180,
    'Dashboard.Performance.LogicalRequests': 18953306300,
    'Dashboard.Performance.DiskReads': 88675,
    'Dashboard.Performance.DiskWrites': 15858093,
    'Dashboard.Performance.CacheEfficiency': 4054.06,
    'Dashboard.ECP.ECPClients': 'Normal',
    'Dashboard.ECP.ECPClientTraffic': 0,
    'Dashboard.ECP.ECPServers': 'Normal',
    'Dashboard.ECP.ECPServerTraffic': 0,
    'Dashboard.ECP.ShadowConnections': 'Normal',
    'Dashboard.ECP.Shadows': 'Normal',
    'Dashboard.Status.UpTime': '8d 18h 25m',
    'Dashboard.Status.LastBackup': 'Never',
    'Dashboard.SystemUsage.DatabaseSpace': 'Normal',
    'Dashboard.SystemUsage.DatabaseJournal': 'Normal',
    'Dashboard.SystemUsage.JournalSpace': 'Normal',
    'Dashboard.SystemUsage.JournalEntries': 1392479607,
    'Dashboard.SystemUsage.LockTable': 'Normal',
    'Dashboard.SystemUsage.WriteDaemon': 'Normal',
    'Dashboard.SystemUsage.Processes': 5,
    'Dashboard.SystemUsage.CSPSessions': 0,
    'Dashboard.Alerts.SeriousAlerts': 3,
    'Dashboard.Alerts.ApplicationErrors': 0,
    'Dashboard.Licensing.LicenseLimit': 8,
    'Dashboard.Licensing.LicenseUse': 13,
    'Dashboard.Licensing.LicenseUseHigh': 38,
    ...overrides,
  };
}

const TASK_ROWS = [
  { Id: '1', Name: 'Purge journal', Namespace: '%SYS', Datetime: '2026-09-29 03:00:00', Suspended: false },
  { Id: '2', Name: 'Nightly backup', Namespace: '%SYS', Datetime: '2026-09-29 04:00:00', Suspended: true },
];

interface MountOptions {
  readonly rows?: unknown[];
  readonly tasks?: unknown[];
  readonly hold?: boolean;
  readonly tasksVerdict?: Verdict;
  /** A verdict per route, for the screens a case refuses; every other route is ungated. */
  readonly verdicts?: Readonly<Record<string, Verdict>>;
  /** The Dashboard's own read answers a 500 from the first call. */
  readonly failFirst?: boolean;
  /** Upcoming tasks' read answers a 500. */
  readonly tasksFail?: boolean;
  /** The first Upcoming tasks read is held until `releaseTasks()`. */
  readonly holdFirstTasks?: boolean;
}

/** A `ScreenActions` that also records every action a page registers. */
class RecordingActions extends ScreenActions {
  readonly registered: string[] = [];

  override register(descriptor: string, actionId: string, run: Parameters<ScreenActions['register']>[2]): () => void {
    this.registered.push(`${descriptor}:${actionId}`);
    return super.register(descriptor, actionId, run);
  }
}

async function mount(options: MountOptions = {}) {
  TestBed.resetTestingModule();
  const declaration = SCREENS.find((screen) => screen.descriptor === DESCRIPTOR) ?? null;
  let answerRows = options.rows ?? [row()];
  let failing = options.failFirst === true;
  let taskRows = options.tasks ?? TASK_ROWS;
  let holdRead = false;
  let holdTasks = options.holdFirstTasks === true;
  const heldReads: (() => void)[] = [];
  const heldTasks: (() => void)[] = [];
  const paths: string[] = [];
  const scheduled: (() => void)[] = [];
  const api = {
    requestJson: async <T,>(path: string): Promise<JsonResult<T>> => {
      paths.push(path);
      if (options.hold === true) return new Promise<JsonResult<T>>(() => {});
      const tasks = path.startsWith(TASKS_PATH);
      if (tasks ? options.tasksFail === true : failing) {
        return { kind: 'error', status: 500, code: 'SERVER.INTERNAL', reason: null, detail: null };
      }
      const rows = tasks ? taskRows : answerRows;
      const answer: JsonResult<T> = { kind: 'ok', status: 200, body: { fields: [], rows, truncated: false, banner: '' } as T };
      // A held read answers what it would have answered when it was sent, once released.
      if (tasks ? holdTasks : holdRead) {
        if (tasks) holdTasks = false;
        else holdRead = false;
        return new Promise<JsonResult<T>>((resolve) => (tasks ? heldTasks : heldReads).push(() => resolve(answer)));
      }
      return answer;
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
  const verdict = options.tasksVerdict ?? UNGATED;
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      {
        provide: NavigationService,
        useValue: {
          screenForUrl: () => declaration,
          screenVerdict: (route: string) => options.verdicts?.[route] ?? (route === 'tasks/upcoming' ? verdict : UNGATED),
          subscribe: () => () => {},
        } as unknown as NavigationService,
      },
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: RefreshService, useValue: refresh },
      { provide: ScreenStores, useValue: stores },
      { provide: ScreenActions, useValue: new RecordingActions() },
      { provide: OverlayStack, useValue: new OverlayStack() },
      {
        provide: ScopeService,
        useValue: { loaded: () => true, namespace: () => 'HSCUSTOM', subscribe: () => () => {} } as unknown as ScopeService,
      },
    ],
  });
  await TestBed.inject(Router).navigateByUrl('/os-management/dashboard?ns=HSCUSTOM');
  const fixture = TestBed.createComponent(DashboardPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  return {
    fixture,
    paths,
    refresh,
    setRows: (rows: unknown[]) => {
      answerRows = rows;
    },
    setFailing: (next: boolean) => {
      failing = next;
    },
    fireTick: async () => {
      scheduled[scheduled.length - 1]();
      await settle(fixture);
    },
    setTasks: (rows: unknown[]) => {
      taskRows = rows;
    },
    /** Hold the next Dashboard read until `releaseRead()`. */
    holdNextRead: () => {
      holdRead = true;
    },
    releaseRead: async () => {
      for (const release of heldReads.splice(0)) release();
      await settle(fixture);
    },
    /** Hold the next Upcoming tasks read until `releaseTasks()`. */
    holdNextTasks: () => {
      holdTasks = true;
    },
    releaseTasks: async () => {
      for (const release of heldTasks.splice(0)) release();
      if (fixture.componentRef.hostView.destroyed) await new Promise((resolve) => setTimeout(resolve, 60));
      else await settle(fixture);
    },
    stores,
    actions: TestBed.inject(ScreenActions) as RecordingActions,
    host: fixture.nativeElement as HTMLElement,
  };
}

function meterByLabel(host: HTMLElement, label: string): HTMLElement | null {
  return (
    Array.from(host.querySelectorAll('app-meter')).find(
      (meter) => meter.querySelector('.ocu-meter-label')?.textContent?.trim() === label
    ) ?? null
  ) as HTMLElement | null;
}

function headings(host: HTMLElement): string[] {
  return Array.from(host.querySelectorAll('.ocu-dashboard-heading')).map((heading) => heading.textContent?.trim() ?? '');
}

afterEach(() => {
  for (const element of planted.splice(0)) element.remove();
});

describe('DashboardPage', () => {
  it('draws the seven group headings in the classic order, with thirty meters', async () => {
    const { host, paths } = await mount();
    expect(headings(host)).toEqual([
      STRINGS.performanceHeading,
      STRINGS.dashboardGroupEcp,
      STRINGS.dashboardGroupStatus,
      STRINGS.systemUsageLabel,
      STRINGS.dashboardGroupAlerts,
      STRINGS.dashboardGroupLicensing,
      STRINGS.dashboardGroupTasks,
    ]);
    expect(host.querySelectorAll('app-meter').length).toBe(30);
    expect(paths.filter((path) => path.startsWith(READ_PATH))).toHaveLength(1);
  });

  it('draws each kind: a percent CPU meter with its word, a status word, and a value meter with no state', async () => {
    const { host } = await mount({ rows: [row({ 'Sensors.cpuUsage': 90 })] });
    const cpu = meterByLabel(host, STRINGS.dashboardCpu);
    expect(cpu?.querySelector('.ocu-meter-value')?.textContent?.trim()).toBe('90 %');
    expect(cpu?.querySelector('.ocu-meter-word')?.textContent?.trim()).toBe('Warning');
    expect(cpu?.querySelector('.ocu-meter-fill')?.classList.contains('ocu-meter-fill-warning')).toBe(true);

    const space = meterByLabel(host, STRINGS.systemUsageDatabaseSpace);
    expect(space?.querySelector('.ocu-meter-word')?.textContent?.trim()).toBe('Normal');
    expect(space?.querySelector('.ocu-meter-fill')?.classList.contains('ocu-meter-fill-normal')).toBe(true);

    const refs = meterByLabel(host, STRINGS.processDetailsGlobalReferences);
    expect(refs?.querySelector('.ocu-meter-value')?.textContent?.trim()).toBe('64,649,129,276');
    expect(refs?.querySelector('.ocu-meter-word')).toBeNull();
    expect(refs?.querySelector('.ocu-meter-track')).toBeNull();

    const uptime = meterByLabel(host, STRINGS.systemInfoUptime);
    expect(uptime?.querySelector('.ocu-meter-value')?.textContent?.trim()).toBe('8d 18h 25m');
    const traffic = meterByLabel(host, STRINGS.dashboardApplicationServerTraffic);
    expect(traffic?.querySelector('.ocu-meter-value')?.textContent?.trim()).toBe(`0.0 ${STRINGS.dashboardBytesPerSecond}`);
  });

  it('shows a dash with a skeleton on every meter before the first read lands', async () => {
    const { host } = await mount({ hold: true });
    const meters = Array.from(host.querySelectorAll('app-meter'));
    expect(meters).toHaveLength(30);
    for (const meter of meters) {
      expect(meter.querySelector('.ocu-meter-value')?.textContent?.trim()).toBe('\u2014');
      const skeleton = meter.querySelector('.ocu-meter-fill-skeleton, .ocu-meter-value-skeleton');
      expect(skeleton, meter.querySelector('.ocu-meter-label')?.textContent ?? '').not.toBeNull();
    }
    expect(host.querySelector('.ocu-dashboard-tasks .ocu-data-table-skeleton')).not.toBeNull();
    expect(host.querySelector('.ocu-dashboard')?.getAttribute('aria-busy')).toBe('true');
  });

  it('marks the Task manager group busy while its first read is out, after the meters have drawn', async () => {
    const { host, releaseTasks } = await mount({ holdFirstTasks: true });
    expect(meterByLabel(host, STRINGS.dashboardCpu)?.querySelector('.ocu-meter-value')?.textContent?.trim()).toBe('12 %');
    expect(host.querySelector('.ocu-dashboard')?.getAttribute('aria-busy')).toBe('false');
    expect(host.querySelector('.ocu-dashboard-tasks')?.getAttribute('aria-busy')).toBe('true');
    expect(host.querySelector('.ocu-dashboard-tasks .ocu-data-table-skeleton')).not.toBeNull();
    await releaseTasks();
    expect(host.querySelector('.ocu-dashboard-tasks')?.getAttribute('aria-busy')).toBe('false');
    expect(host.querySelectorAll('.ocu-dashboard-tasks-table tbody tr')).toHaveLength(2);
  });

  it("draws the Task manager group from Upcoming tasks' own read: five rows asked for, its At, Name and Suspended cells under its labels", async () => {
    const { host, paths } = await mount();
    const tasks = paths.filter((path) => path.startsWith(TASKS_PATH));
    expect(tasks).toHaveLength(1);
    expect(tasks[0]).toContain('maxRows=5');
    expect(tasks[0]).toContain('hoursOffset=24');
    const labels = Array.from(host.querySelectorAll('.ocu-dashboard-tasks-table th')).map((cell) => cell.textContent?.trim());
    expect(labels).toEqual([STRINGS.taskUpcomingColumnAt, STRINGS.tableColumnName, STRINGS.taskColumnSuspended]);
    const cells = Array.from(host.querySelectorAll('.ocu-dashboard-tasks-table tbody tr')).map((tableRow) =>
      Array.from(tableRow.querySelectorAll('td')).map((cell) => cell.textContent?.trim())
    );
    expect(cells).toEqual([
      ['2026-09-29 03:00:00', 'Purge journal', STRINGS.tableStatusNo],
      ['2026-09-29 04:00:00', 'Nightly backup', STRINGS.tableStatusYes],
    ]);
  });

  it("shows \"Requires <pair>\" and reads nothing for a caller without Upcoming tasks' pairs", async () => {
    const { host, paths } = await mount({ tasksVerdict: { allowed: false, failedPair: '%Admin_Task:USE' } });
    expect(host.querySelector('.ocu-dashboard-tasks-gated')?.textContent?.trim()).toBe('Requires %Admin_Task:USE');
    expect(paths.filter((path) => path.startsWith(TASKS_PATH))).toHaveLength(0);
    expect(host.querySelector('.ocu-dashboard-tasks-table')).toBeNull();
    // No fault stamp: the gated group is not a refused read, and the meters carry no fault.
    expect(host.querySelector('.ocu-dashboard-tasks-refused')).toBeNull();
    const cpu = meterByLabel(host, STRINGS.dashboardCpu);
    expect(cpu?.querySelector('.ocu-meter-value')?.textContent?.trim()).toBe('12 %');
    expect(cpu?.getAttribute('title')).toBeNull();
  });

  it("shows Upcoming tasks' own empty text when it answers no rows", async () => {
    const { host } = await mount({ tasks: [] });
    expect(host.querySelector('.ocu-dashboard-tasks-empty')?.textContent?.trim()).toBe(STRINGS.taskUpcomingEmpty);
    expect(host.querySelector('.ocu-dashboard-tasks-table')).toBeNull();
  });

  it('refreshes at 5, 10, 30 or 60 s, off until a rate is set; two ticks update the meters and the tasks silently, with no live region', async () => {
    const { host, paths, refresh, setRows, fireTick } = await mount();
    expect(refresh.rates()).toEqual([5, 10, 30, 60]);
    expect(refresh.rate()).toBe(0);
    expect(refresh.setRate(5)).toBe(true);
    setRows([row({ 'Sensors.cpuUsage': 97 })]);
    await fireTick();
    expect(paths.filter((path) => path.startsWith(READ_PATH))).toHaveLength(2);
    expect(paths.filter((path) => path.startsWith(TASKS_PATH))).toHaveLength(2);
    const cpu = meterByLabel(host, STRINGS.dashboardCpu);
    expect(cpu?.querySelector('.ocu-meter-value')?.textContent?.trim()).toBe('97 %');
    expect(cpu?.querySelector('.ocu-meter-word')?.textContent?.trim()).toBe('Troubled');

    setRows([row({ 'Sensors.cpuUsage': 40 })]);
    await fireTick();
    expect(paths.filter((path) => path.startsWith(READ_PATH))).toHaveLength(3);
    expect(paths.filter((path) => path.startsWith(TASKS_PATH))).toHaveLength(3);
    const cpuAgain = meterByLabel(host, STRINGS.dashboardCpu);
    expect(cpuAgain?.querySelector('.ocu-meter-value')?.textContent?.trim()).toBe('40 %');
    expect(cpuAgain?.querySelector('.ocu-meter-word')?.textContent?.trim()).toBe('Normal');
    expect(host.querySelector('.ocu-meter-fill-skeleton, .ocu-meter-value-skeleton')).toBeNull();
    expect(host.querySelector('[aria-live]')).toBeNull();
    expect(host.querySelector('[role="alert"]')).toBeNull();
  });

  it('a tick whose read is still out keeps every meter and the tasks on their last answer: no dash, no skeleton, nothing busy', async () => {
    const { host, refresh, setRows, fireTick, holdNextRead, releaseRead } = await mount();
    expect(refresh.setRate(5)).toBe(true);
    setRows([row({ 'Sensors.cpuUsage': 97 })]);
    holdNextRead();
    await fireTick();
    expect(meterByLabel(host, STRINGS.dashboardCpu)?.querySelector('.ocu-meter-value')?.textContent?.trim()).toBe('12 %');
    expect(meterByLabel(host, STRINGS.systemUsageDatabaseSpace)?.querySelector('.ocu-meter-word')?.textContent?.trim()).toBe('Normal');
    expect(meterByLabel(host, STRINGS.processDetailsGlobalReferences)?.querySelector('.ocu-meter-value')?.textContent?.trim()).toBe('64,649,129,276');
    expect(host.querySelector('.ocu-meter-fill-skeleton, .ocu-meter-value-skeleton, .ocu-data-table-skeleton')).toBeNull();
    expect(host.querySelector('[aria-busy="true"]')).toBeNull();
    expect(host.querySelectorAll('.ocu-dashboard-tasks-table tbody tr')).toHaveLength(2);
    await releaseRead();
    expect(meterByLabel(host, STRINGS.dashboardCpu)?.querySelector('.ocu-meter-value')?.textContent?.trim()).toBe('97 %');
  });

  it("keeps the Task manager rows in the Dashboard's own store: Upcoming tasks' store is never written (AD-19)", async () => {
    const { host, stores } = await mount();
    expect(host.querySelectorAll('.ocu-dashboard-tasks-table tbody tr')).toHaveLength(2);
    const upcoming = SCREENS.find((screen) => screen.route === 'tasks/upcoming') ?? null;
    expect(upcoming).not.toBeNull();
    if (upcoming === null) return;
    expect(stores.for(upcoming.descriptor, upcoming.refreshRates).data()).toHaveLength(0);
  });

  it("applies only the latest tasks read: an earlier tick's answer that lands late is dropped", async () => {
    const { host, refresh, setTasks, fireTick, holdNextTasks, releaseTasks } = await mount();
    const names = () =>
      Array.from(host.querySelectorAll('.ocu-dashboard-tasks-table tbody tr')).map((tableRow) => tableRow.querySelectorAll('td')[1]?.textContent?.trim());
    expect(refresh.setRate(5)).toBe(true);
    holdNextTasks();
    await fireTick();
    setTasks([TASK_ROWS[1]]);
    await fireTick();
    expect(names()).toEqual(['Nightly backup']);
    await releaseTasks();
    expect(names()).toEqual(['Nightly backup']);
  });

  it('applies no tasks answer that lands after the page is gone', async () => {
    const { actions, fixture, stores, setTasks, holdNextTasks, releaseTasks } = await mount();
    const tasksStore = stores.for(`${DESCRIPTOR}#tasks`, [], '');
    expect(tasksStore.data()).toHaveLength(2);
    setTasks([TASK_ROWS[1]]);
    holdNextTasks();
    expect(actions.run(DESCRIPTOR, REFRESH_ACTION_ID)).toBe(true);
    await settle(fixture);
    fixture.destroy();
    await releaseTasks();
    expect(tasksStore.data()).toHaveLength(2);
  });

  it('a read fault before any success leaves nothing busy, and every meter shows a dash with the tooltip', async () => {
    const { host } = await mount({ failFirst: true });
    expect(host.querySelector('[aria-busy="true"]')).toBeNull();
    expect(host.querySelector('.ocu-meter-fill-skeleton, .ocu-meter-value-skeleton')).toBeNull();
    for (const label of [STRINGS.dashboardCpu, STRINGS.systemUsageDatabaseSpace, STRINGS.processDetailsGlobalReferences]) {
      const meter = meterByLabel(host, label);
      expect(meter?.querySelector('.ocu-meter-value')?.textContent?.trim(), label).toBe('\u2014');
      expect(meter?.getAttribute('title'), label).toBe(STRINGS.connectivityRequestRefused);
    }
  });

  it('a read fault after a success keeps each word and color, dashes every number, and carries the tooltip', async () => {
    const { actions, fixture, host, setFailing } = await mount();
    expect(meterByLabel(host, STRINGS.processDetailsGlobalReferences)?.querySelector('.ocu-meter-value')?.textContent?.trim()).toBe('64,649,129,276');
    setFailing(true);
    expect(actions.run(DESCRIPTOR, REFRESH_ACTION_ID)).toBe(true);
    await settle(fixture);

    const cpu = meterByLabel(host, STRINGS.dashboardCpu);
    expect(cpu?.querySelector('.ocu-meter-value')?.textContent?.trim()).toBe('\u2014');
    expect(cpu?.querySelector('.ocu-meter-word')?.textContent?.trim()).toBe('Normal');
    expect(cpu?.getAttribute('title')).toBe(STRINGS.connectivityRequestRefused);
    const space = meterByLabel(host, STRINGS.systemUsageDatabaseSpace);
    expect(space?.querySelector('.ocu-meter-word')?.textContent?.trim()).toBe('Normal');
    expect(space?.querySelector('.ocu-meter-fill')?.classList.contains('ocu-meter-fill-normal')).toBe(true);
    expect(space?.getAttribute('title')).toBe(STRINGS.connectivityRequestRefused);
    const refs = meterByLabel(host, STRINGS.processDetailsGlobalReferences);
    expect(refs?.querySelector('.ocu-meter-value')?.textContent?.trim()).toBe('\u2014');
    expect(refs?.getAttribute('title')).toBe(STRINGS.connectivityRequestRefused);
    expect(host.querySelector('[aria-busy="true"]')).toBeNull();
  });

  it("says so when Upcoming tasks' read is refused, and the meters draw", async () => {
    const { host } = await mount({ tasksFail: true });
    expect(host.querySelector('.ocu-dashboard-tasks-refused')?.textContent?.trim()).toBe(STRINGS.connectivityRequestRefused);
    expect(host.querySelector('.ocu-dashboard-tasks-table')).toBeNull();
    expect(host.querySelector('.ocu-dashboard-tasks-empty')).toBeNull();
    const cpu = meterByLabel(host, STRINGS.dashboardCpu);
    expect(cpu?.querySelector('.ocu-meter-value')?.textContent?.trim()).toBe('12 %');
    expect(cpu?.getAttribute('title')).toBeNull();
  });

  it("offers each group's drill-downs under its heading: Performance's two, ECP's one and System usage's one, each at its route in this namespace", async () => {
    const { host } = await mount();
    const linksUnder = (heading: string): string[][] => {
      const group = Array.from(host.querySelectorAll('.ocu-dashboard-group')).find(
        (candidate) => candidate.querySelector('.ocu-dashboard-heading')?.textContent?.trim() === heading
      );
      return Array.from(group?.querySelectorAll('nav.ocu-details-links a.ocu-details-link') ?? []).map((link) => [
        link.textContent?.trim() ?? '',
        link.getAttribute('href') ?? '',
      ]);
    };
    const hrefs = (links: string[][]) => links.map((link) => link[1].replace(/^.*(?=\/os-management)/, ''));
    const performance = linksUnder(STRINGS.performanceHeading);
    expect(performance.map((link) => link[0])).toEqual([STRINGS.globalStatisticsLabel, STRINGS.resourceStatisticsLabel]);
    expect(hrefs(performance)).toEqual(['/os-management/global-statistics?ns=HSCUSTOM', '/os-management/resource-statistics?ns=HSCUSTOM']);
    const ecp = linksUnder(STRINGS.dashboardGroupEcp);
    expect(ecp.map((link) => link[0])).toEqual([STRINGS.ecpStatisticsLabel]);
    expect(hrefs(ecp)).toEqual(['/os-management/ecp-statistics?ns=HSCUSTOM']);
    const usage = linksUnder(STRINGS.systemUsageLabel);
    expect(usage.map((link) => link[0])).toEqual([STRINGS.activeProcessesLabel]);
    expect(hrefs(usage)).toEqual(['/os-management/active-processes?ns=HSCUSTOM']);
    for (const heading of [STRINGS.dashboardGroupStatus, STRINGS.dashboardGroupAlerts, STRINGS.dashboardGroupLicensing, STRINGS.dashboardGroupTasks]) {
      expect(linksUnder(heading), heading).toEqual([]);
    }
    expect(host.querySelectorAll('nav.ocu-details-links')).toHaveLength(3);
  });

  it('opens a drill-down in this namespace on a plain click, and leaves a modified click to the browser', async () => {
    const { host } = await mount();
    const router = TestBed.inject(Router);
    const link = host.querySelector('[data-drill-down="os-management/ecp-statistics"]') as HTMLAnchorElement;
    expect(link).not.toBeNull();
    // What the page left of each modified click, read after its handler and then cancelled, so jsdom does not navigate.
    for (const modifier of [{ ctrlKey: true }, { metaKey: true }, { shiftKey: true }, { altKey: true }, { button: 1 }]) {
      let leftToBrowser: boolean | null = null;
      const observe = (event: Event) => {
        leftToBrowser = !event.defaultPrevented;
        event.preventDefault();
      };
      document.addEventListener('click', observe, { once: true });
      link.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, ...modifier }));
      document.removeEventListener('click', observe);
      expect(leftToBrowser, JSON.stringify(modifier)).toBe(true);
    }
    expect(router.url).toBe('/os-management/dashboard?ns=HSCUSTOM');
    const plain = new MouseEvent('click', { bubbles: true, cancelable: true });
    link.dispatchEvent(plain);
    expect(plain.defaultPrevented).toBe(true);
    await new Promise((resolve) => setTimeout(resolve, 20));
    expect(router.url).toBe('/os-management/ecp-statistics?ns=HSCUSTOM');
  });

  it('Story 18.47, DW-2340: a drill-down to a screen the caller is refused is listed, gated with its reason, and goes nowhere', async () => {
    // Mutation (Rule 19): drop the verdict from `linksFor` -> the refused link draws live and every leg goes red.
    const refused = 'os-management/ecp-statistics';
    const { host } = await mount({ verdicts: { [refused]: { allowed: false, failedPair: '%Admin_Operate:USE' } } });
    const gated = host.querySelector(`[data-drill-down="${refused}"]`) as HTMLAnchorElement;
    expect(gated).not.toBeNull();
    expect(gated.hasAttribute('href')).toBe(false);
    expect(gated.getAttribute('tabindex')).toBe('0');
    expect(gated.getAttribute('aria-disabled')).toBe('true');
    const reason = gated.querySelector('.ocu-details-link-reason') as HTMLElement;
    expect(reason.textContent?.trim()).toBe('Requires %Admin_Operate:USE');
    expect(gated.getAttribute('aria-describedby')).toBe(reason.id);
    expect(gated.textContent?.trim()).toBe(`${STRINGS.ecpStatisticsLabel}Requires %Admin_Operate:USE`);
    const router = TestBed.inject(Router);
    const click = new MouseEvent('click', { bubbles: true, cancelable: true });
    gated.dispatchEvent(click);
    expect(click.defaultPrevented).toBe(true);
    await new Promise((resolve) => setTimeout(resolve, 20));
    expect(router.url).toBe('/os-management/dashboard?ns=HSCUSTOM');
    // The caller's other links stay live and carry none of it.
    const live = host.querySelector('[data-drill-down="os-management/global-statistics"]') as HTMLAnchorElement;
    expect(live.getAttribute('href')).toContain('/os-management/global-statistics');
    expect(live.hasAttribute('aria-disabled')).toBe(false);
    expect(live.hasAttribute('tabindex')).toBe(false);
    expect(live.querySelector('.ocu-details-link-reason')).toBeNull();
  });

  it('draws no link for a drill-down whose screen is not built', async () => {
    const target = SCREENS.find((screen) => screen.route === 'os-management/resource-statistics') ?? null;
    expect(target).not.toBeNull();
    if (target === null) return;
    const writable = target as { built: boolean };
    writable.built = false;
    try {
      const { host } = await mount();
      const routes = Array.from(host.querySelectorAll('a.ocu-details-link')).map((link) => link.getAttribute('data-drill-down'));
      expect(routes).toEqual(['os-management/global-statistics', 'os-management/ecp-statistics', 'os-management/active-processes']);
    } finally {
      writable.built = true;
    }
  });

  it('offers Refresh and no other action', async () => {
    const { actions } = await mount();
    expect(actions.has(DESCRIPTOR, REFRESH_ACTION_ID)).toBe(true);
    expect(actions.registered).toEqual([`${DESCRIPTOR}:${REFRESH_ACTION_ID}`]);
    const declaration = SCREENS.find((screen) => screen.descriptor === DESCRIPTOR);
    expect(declaration?.rowActions).toEqual([]);
    expect(declaration?.primaryAction.id).toBe('');
  });
});

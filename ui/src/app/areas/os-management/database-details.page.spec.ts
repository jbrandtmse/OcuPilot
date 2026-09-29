import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import type { ConnectivityService } from '../../core/connectivity';
import { NavigationService, UNGATED, screenForUrl, type Verdict } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { uncheckedLine } from '../../core/privileges';
import { ScreenStores } from '../../core/screen-store';
import { STRINGS } from '../../core/strings';
import { DatabaseDetailsPage } from './database-details.page';
import { stubAccountPreferences } from '../../testing/account-preferences';

/**
 * Database details (Story 6.11), wired end to end over a stub of the HTTP answer, with the real
 * `RefreshService`, `ScreenStores` and `createScreenRead` -- the same shape
 * `process-details.page.spec.ts` takes for Process details. Renders the shipped descriptors, read
 * straight out of the mirror, so the field list and the two screens' shared `dir` criterion are
 * the ones the instance validates.
 *
 * AC6 is this file's own: a faulted auto-refresh keeps the last values on screen and raises the
 * refresh strip, rather than blanking a screen that refreshes every few seconds.
 *
 * Mutation (Rule 19): clear the store on a fault in `database-details.page.ts` -> AC6's field
 * assertion goes red, reading empty instead of the last value.
 *
 * The Background tasks section (Story 18.3, AC8, DW-1080) reads the `tasks/background` screen's
 * own read and lists the rows whose `Database` is this page's directory.
 *
 * Mutation (Rule 19): compare the directories with case in `comparableDirectory` -> the listing
 * leg goes red, the vendor's upper-case directory no longer matching the route's.
 */

const DESCRIPTOR = 'OcuPilot.Screen.Descriptor.DatabaseDetails';

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

/** One Database details row, carrying every field the descriptor declares. */
function row(overrides: Record<string, unknown> = {}) {
  return {
    Directory: '/durable/iris/mgr/',
    MaxSize: 0,
    ExpansionSize: 0,
    NewVolumeThreshold: 0,
    NewVolumeDirectory: '/durable/iris/mgr/',
    ResourceName: '%DB_IRISSYS',
    NewGlobalIsKeep: false,
    NewGlobalCollation: 5,
    ClusterMountMode: false,
    ReadOnly: false,
    GlobalJournalState: true,
    Size: 70,
    AvailableSpace: 3.1,
    DiskFree: '1.113TB',
    Mounted: true,
    ...overrides,
  };
}

/** One Background tasks row as the `tasks/background` read answers it. */
function taskRow(overrides: Record<string, unknown> = {}) {
  return {
    Source: 'Management Portal',
    Id: '4242',
    Task: 'Compact DB Space',
    Namespace: '%SYS',
    Status: 'Paused',
    Details: 'MGR',
    ErrorCount: '0',
    StartTime: '2026-09-28 12:00:05',
    Database: '/DURABLE/IRIS/MGR/',
    ...overrides,
  };
}

/** How the Background tasks read answers: its rows and truncation, a refusal, or a failure. */
interface TasksAnswer {
  rows?: unknown[];
  truncated?: boolean;
  refusedPair?: string;
  failing?: boolean;
}

/** One volume-file row. */
function volumeRow(overrides: Record<string, unknown> = {}) {
  return {
    VolumeNumber: 0,
    VolumeDirectory: '/durable/iris/mgr/',
    File: 'IRIS.DAT',
    Size: 70,
    VolumeDirectoryTotalSize: 70,
    DiskFree: 1166836,
    ...overrides,
  };
}

async function mount(
  detailsRows: unknown[] = [row()],
  volumesRows: unknown[] = [volumeRow()],
  url = '/os-management/databases/details/%252Fdurable%252Firis%252Fmgr%252F?ns=HSCUSTOM',
  volumesRefused = false,
  tasks: TasksAnswer = { rows: [] },
  tasksVerdict: Verdict = UNGATED
) {
  TestBed.resetTestingModule();
  let answerRows = detailsRows;
  let volumeAnswerRows = volumesRows;
  let failing = false;
  let volumesFailing = false;
  let tasksAnswer = tasks;
  const paths: string[] = [];
  const scheduled: (() => void)[] = [];
  const api = {
    requestJson: async <T,>(path: string): Promise<JsonResult<T>> => {
      paths.push(path);
      if (path.includes('/tasks.background/')) {
        if (tasksAnswer.refusedPair !== undefined) {
          return { kind: 'error', status: 403, code: 'AUTH.FORBIDDEN', reason: null, detail: { failedPair: tasksAnswer.refusedPair } };
        }
        if (tasksAnswer.failing === true) return { kind: 'error', status: 500, code: 'SERVER.INTERNAL', reason: null, detail: null };
        return { kind: 'ok', status: 200, body: { fields: [], rows: tasksAnswer.rows ?? [], truncated: tasksAnswer.truncated === true, banner: '' } as T };
      }
      if (path.includes('osmgmt.databasevolumes')) {
        if (volumesFailing) return { kind: 'error', status: 403, code: 'AUTH.FORBIDDEN', reason: null, detail: null };
        return { kind: 'ok', status: 200, body: { fields: [], rows: volumeAnswerRows, truncated: false, banner: '' } as T };
      }
      if (failing) return { kind: 'error', status: 500, code: 'SERVER.INTERNAL', reason: null, detail: null };
      return { kind: 'ok', status: 200, body: { fields: [], rows: answerRows, truncated: false, banner: '' } as T };
    },
  };
  volumesFailing = volumesRefused;
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
        useValue: { screenForUrl, screenVerdict: (route: string) => (route === 'tasks/background' ? tasksVerdict : UNGATED) } as unknown as NavigationService,
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
  await TestBed.inject(Router).navigateByUrl(url);
  const fixture = TestBed.createComponent(DatabaseDetailsPage);
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
    setFailing: (value: boolean) => {
      failing = value;
    },
    setVolumesFailing: (value: boolean) => {
      volumesFailing = value;
    },
    setTasks: (value: TasksAnswer) => {
      tasksAnswer = value;
    },
    actions: TestBed.inject(ScreenActions),
  };
}

function fieldValue(host: HTMLElement, labelKey: string): string | undefined {
  const label = STRINGS[labelKey as keyof typeof STRINGS];
  const fields = Array.from(host.querySelectorAll('.ocu-details-field'));
  const field = fields.find((element) => element.querySelector('.ocu-details-field-label')?.textContent === label);
  return field?.querySelector('.ocu-details-field-value')?.textContent ?? undefined;
}

describe('Database details', () => {
  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
  });

  it('reads the route-id directory for both the properties and the volume files, seeding Directory', async () => {
    const { fixture, paths } = await mount();
    const host: HTMLElement = fixture.nativeElement;
    expect(fieldValue(host, 'lockColumnDirectory')).toBe('/durable/iris/mgr/');
    expect(paths.some((path) => path.includes('osmgmt.databasedetails') && path.includes('dir='))).toBe(true);
    expect(paths.some((path) => path.includes('osmgmt.databasevolumes') && path.includes('dir='))).toBe(true);
  });

  it('draws the one Available-space meter, never as a plain field', async () => {
    const { fixture } = await mount();
    const host: HTMLElement = fixture.nativeElement;
    expect(host.querySelector('app-meter')).not.toBeNull();
    expect(fieldValue(host, 'databaseColumnAvailable')).toBeUndefined();
  });

  it('renders the Volume files section from the sibling screen\u2019s own read', async () => {
    const { fixture } = await mount();
    const host: HTMLElement = fixture.nativeElement;
    expect(host.textContent).toContain(STRINGS.databaseVolumeListLabel);
    expect(host.querySelector('table[role="table"]')).not.toBeNull();
    expect(host.textContent).toContain('IRIS.DAT');
  });

  it('shows the declared empty state when a database has no volume files', async () => {
    const { fixture } = await mount([row()], []);
    const host: HTMLElement = fixture.nativeElement;
    expect(host.querySelector('table[role="table"]')).toBeNull();
    expect(host.textContent).toContain(STRINGS.databaseVolumeListEmpty);
  });

  it('AC6: a fault on a re-read shows the refusal with Retry and keeps the last values', async () => {
    const { fixture, actions, setFailing } = await mount();
    const host: HTMLElement = fixture.nativeElement;
    setFailing(true);
    expect(actions.run(DESCRIPTOR, REFRESH_ACTION_ID)).toBe(true);
    await settle(fixture);
    expect(host.querySelector('.ocu-data-table-refusal')?.textContent).toContain(STRINGS.connectivityRequestRefused);
    expect(host.querySelector('.ocu-data-table-refusal button')?.textContent?.trim()).toBe(STRINGS.actionRetry);
    expect(fieldValue(host, 'lockColumnDirectory')).toBe('/durable/iris/mgr/');
    expect(host.querySelector('.ocu-data-table-skeleton')).toBeNull();
  });

  it('a refused Volume files read says so with Retry, never a bare heading or a false empty state', async () => {
    // Database details declares `%Admin_Operate:USE` and the sibling volumes screen declares
    // `%Admin_Manage:USE`, so this screen's own designed least-privileged principal is refused the
    // volumes read on every load. Without this the section rendered its heading and nothing else.
    const { fixture } = await mount([row()], [volumeRow()], undefined, true);
    const host: HTMLElement = fixture.nativeElement;
    expect(host.textContent).toContain(STRINGS.databaseVolumeListLabel);
    const strips = Array.from(host.querySelectorAll('.ocu-data-table-refusal'));
    expect(strips.length).toBe(1);
    expect(strips[0].textContent).toContain(STRINGS.connectivityRequestRefused);
    expect(strips[0].querySelector('button')?.textContent?.trim()).toBe(STRINGS.actionRetry);
    expect(host.textContent).not.toContain(STRINGS.databaseVolumeListEmpty);
    expect(host.querySelector('table[role="table"]')).toBeNull();
  });

  it('a Volume files read that succeeds on Retry replaces the refusal with the rows', async () => {
    const { fixture, setVolumesFailing } = await mount([row()], [volumeRow()], undefined, true);
    const host: HTMLElement = fixture.nativeElement;
    setVolumesFailing(false);
    (host.querySelector('.ocu-data-table-refusal button') as HTMLButtonElement).click();
    await settle(fixture);
    expect(host.querySelector('.ocu-data-table-refusal')).toBeNull();
    expect(host.textContent).toContain('IRIS.DAT');
  });

  it('an unrecognized directory reads as zero rows and shows "This database no longer exists."', async () => {
    const { fixture } = await mount([]);
    const host: HTMLElement = fixture.nativeElement;
    expect(host.querySelector('.ocu-data-table-skeleton')).toBeNull();
    expect(host.textContent).toContain(STRINGS.databaseDetailsGone);
    expect(host.querySelector('[role="alert"]')).toBeNull();
  });

  describe('Background tasks (Story 18.3, AC8)', () => {
    function taskSection(host: HTMLElement): HTMLElement {
      return host.querySelector('.ocu-details-tasks') as HTMLElement;
    }

    function taskCells(host: HTMLElement): string[][] {
      return Array.from(taskSection(host).querySelectorAll('tbody tr')).map((tr) =>
        Array.from(tr.querySelectorAll('td')).map((td) => td.textContent?.trim() ?? '')
      );
    }

    it('lists the tasks running against this directory, ignoring case and a trailing separator', async () => {
      const rows = [
        taskRow(),
        taskRow({ Id: '4243', Task: 'Defragment', Status: 'Running', Database: '/DURABLE/IRIS/MGR' }),
        taskRow({ Id: '4244', Database: '/DURABLE/IRIS/MGR/USER/' }),
        taskRow({ Id: '4245', Source: 'Admin API', Database: '' }),
      ];
      const { fixture, paths } = await mount([row()], [volumeRow()], undefined, false, { rows });
      const host: HTMLElement = fixture.nativeElement;
      expect(taskSection(host).querySelector('h2')?.textContent).toBe(STRINGS.backgroundTaskListLabel);
      const headers = Array.from(taskSection(host).querySelectorAll('th')).map((th) => th.textContent);
      expect(headers).toEqual([STRINGS.proposalEntityTask, STRINGS.taskHistoryColumnStatus, STRINGS.taskStartTime]);
      const cells = taskCells(host);
      expect(cells.map((cell) => cell[0])).toEqual(['Compact DB Space', 'Defragment']);
      expect(cells[0][2]).toBe('2026-09-28 12:00:05');
      expect(taskSection(host).textContent).not.toContain(STRINGS.databaseTasksNone);
      expect(paths.filter((path) => path.includes('/tasks.background/read?maxRows=1000')).length).toBe(1);
    });

    it('says none is running when no task names this directory', async () => {
      const { fixture } = await mount([row()], [volumeRow()], undefined, false, { rows: [taskRow({ Database: '/DURABLE/IRIS/MGR/USER/' })] });
      const host: HTMLElement = fixture.nativeElement;
      expect(taskSection(host).querySelector('table')).toBeNull();
      expect(taskSection(host).textContent).toContain(STRINGS.databaseTasksNone);
    });

    it('a truncated answer says only the newest 1000 were checked', async () => {
      const { fixture } = await mount([row()], [volumeRow()], undefined, false, { rows: [taskRow()], truncated: true });
      const host: HTMLElement = fixture.nativeElement;
      expect(taskSection(host).textContent).toContain(STRINGS.databaseTasksTruncated.replace('<n>', '1000'));
      expect(taskCells(host).length).toBe(1);
    });

    it('a denied verdict shows the section unchecked, naming the pair, and sends no read', async () => {
      const { fixture, paths } = await mount([row()], [volumeRow()], undefined, false, { rows: [taskRow()] }, { allowed: false, failedPair: '%DB_IRISSYS:READ' });
      const host: HTMLElement = fixture.nativeElement;
      expect(taskSection(host).textContent).toContain(uncheckedLine('%DB_IRISSYS:READ'));
      expect(taskSection(host).querySelector('table')).toBeNull();
      expect(taskSection(host).textContent).not.toContain(STRINGS.databaseTasksNone);
      expect(paths.some((path) => path.includes('/tasks.background/'))).toBe(false);
    });

    it('a read answering 403 shows the section unchecked, naming the failed pair', async () => {
      const { fixture } = await mount([row()], [volumeRow()], undefined, false, { refusedPair: '%Admin_Operate:USE' });
      const host: HTMLElement = fixture.nativeElement;
      expect(taskSection(host).textContent).toContain(uncheckedLine('%Admin_Operate:USE'));
      expect(taskSection(host).textContent).not.toContain(STRINGS.databaseTasksNone);
    });

    it('a read answering 500 shows the refusal with Retry and no "none" line, and Retry reads the tasks again', async () => {
      const { fixture, paths, setTasks } = await mount([row()], [volumeRow()], undefined, false, { failing: true });
      const host: HTMLElement = fixture.nativeElement;
      const strip = taskSection(host).querySelector('.ocu-data-table-refusal');
      expect(strip?.textContent).toContain(STRINGS.connectivityRequestRefused);
      expect(strip?.querySelector('button')?.textContent?.trim()).toBe(STRINGS.actionRetry);
      expect(taskSection(host).textContent).not.toContain(STRINGS.databaseTasksNone);
      expect(taskSection(host).querySelector('table')).toBeNull();
      setTasks({ rows: [taskRow()] });
      (strip?.querySelector('button') as HTMLButtonElement).click();
      await settle(fixture);
      expect(paths.filter((path) => path.includes('/tasks.background/')).length).toBe(2);
      expect(taskSection(host).querySelector('.ocu-data-table-refusal')).toBeNull();
      expect(taskCells(host).map((cell) => cell[0])).toEqual(['Compact DB Space']);
    });

    it('Refresh reads the tasks again', async () => {
      const { fixture, paths, actions, setTasks } = await mount([row()], [volumeRow()], undefined, false, { rows: [] });
      const host: HTMLElement = fixture.nativeElement;
      expect(taskSection(host).textContent).toContain(STRINGS.databaseTasksNone);
      setTasks({ rows: [taskRow()] });
      expect(actions.run(DESCRIPTOR, REFRESH_ACTION_ID)).toBe(true);
      await settle(fixture);
      expect(paths.filter((path) => path.includes('/tasks.background/')).length).toBe(2);
      expect(taskCells(host).map((cell) => cell[0])).toEqual(['Compact DB Space']);
    });

    it('a different database re-reads the tasks and lists the ones for its own directory', async () => {
      const rows = [taskRow(), taskRow({ Id: '4246', Task: 'Defragment', Database: '/DURABLE/IRIS/MGR/USER/' })];
      const { fixture, paths } = await mount([row()], [volumeRow()], undefined, false, { rows });
      const host: HTMLElement = fixture.nativeElement;
      expect(taskCells(host).map((cell) => cell[0])).toEqual(['Compact DB Space']);
      await TestBed.inject(Router).navigateByUrl('/os-management/databases/details/%252Fdurable%252Firis%252Fmgr%252Fuser%252F?ns=HSCUSTOM');
      await settle(fixture);
      expect(paths.filter((path) => path.includes('/tasks.background/')).length).toBe(2);
      expect(taskCells(host).map((cell) => cell[0])).toEqual(['Defragment']);
    });
  });
});

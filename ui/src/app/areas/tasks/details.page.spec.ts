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
import { TaskDetailsPage } from './details.page';
import { stubAccountPreferences } from '../../testing/account-preferences';

/**
 * Task details (Story 6.7), wired end to end over a stub of the HTTP answer, with the real
 * `RefreshService`, `ScreenStores` and `createScreenRead` -- the same shape `upcoming.page.spec.ts`
 * takes. It renders the shipped descriptor, read straight out of the mirror, so the field list and
 * criterion are the ones the instance validates.
 *
 * Mutations (Rule 19): drop the `taskId` criterion from `parentCriteria`'s call in
 * `TaskDetailsPage` -> the first path assertion goes red, carrying no `taskId`. Skip the
 * `NextScheduled` override in `fieldViews` -> the suspended-Next-run assertion goes red, showing
 * the raw stale timestamp instead. Drop the `highlights.reset()` call on an id change -> the
 * changed-field assertion after a task switch goes red, marking every field changed instead of
 * none.
 */

const DESCRIPTOR = 'OcuPilot.Screen.Descriptor.TaskDetails';

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

/** One task-details row, carrying every field the descriptor declares. */
function row(overrides: Record<string, unknown> = {}) {
  return {
    Id: 1002,
    Name: 'OcuPilotDemo nightly purge',
    Description: 'OcuPilot demo fixture',
    NameSpace: 'HSCUSTOM',
    TaskClass: 'OcuPilot.Install.DemoTask',
    Priority: 'Normal',
    RunAsUser: 'irisowner',
    TimePeriod: 'Daily',
    TimePeriodEvery: 1,
    TimePeriodDay: '',
    DailyFrequency: 'Once',
    DailyFrequencyTime: '',
    DailyIncrement: '',
    DailyStartTime: '03:00:00',
    DailyEndTime: '00:00:00',
    StartDate: '2026-09-16',
    EndDate: '',
    Type: 'User',
    Suspended: true,
    Error: '<THROW>this task always fails by design',
    LastStarted: '2026-09-15 18:55:01',
    LastFinished: '2026-09-15 18:55:01',
    NextScheduled: '2026-09-15 18:54:53',
    ...overrides,
  };
}

async function mount(initialRows: unknown[] = [row()], url = '/tasks/schedule/details/1002?ns=HSCUSTOM') {
  TestBed.resetTestingModule();
  const declaration = SCREENS.find((screen) => screen.descriptor === DESCRIPTOR) ?? null;
  let answerRows = initialRows;
  let failing = false;
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
  const fixture = TestBed.createComponent(TaskDetailsPage);
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

function fieldValue(host: HTMLElement, labelKey: string): string | null {
  const fields = Array.from(host.querySelectorAll('.ocu-details-field'));
  const target = fields.find(
    (field) => field.querySelector('.ocu-details-field-label')?.textContent?.trim() === stringFor(labelKey)
  );
  return target?.querySelector('.ocu-details-field-value')?.textContent?.trim() ?? null;
}

function changedLabels(host: HTMLElement): string[] {
  return Array.from(host.querySelectorAll('.ocu-data-table-row-changed .ocu-details-field-label')).map(
    (label) => label.textContent?.trim() ?? ''
  );
}

afterEach(() => {
  for (const element of planted.splice(0)) element.remove();
});

describe('TaskDetailsPage', () => {
  it('reads the route id as taskId and renders the declared fields', async () => {
    const { paths, host } = await mount();
    expect(paths).toHaveLength(1);
    expect(paths[0]).toContain('/screens/tasks.taskdetails/read?');
    expect(paths[0]).toContain('&taskId=1002');
    expect(host.querySelector('.ocu-data-table-skeleton')).toBeNull();
    expect(fieldValue(host, 'tableColumnName')).toBe('OcuPilotDemo nightly purge');
    expect(fieldValue(host, 'headerNamespaceLabel')).toBe('HSCUSTOM');
    expect(fieldValue(host, 'taskColumnSuspended')).toBe(STRINGS.tableStatusYes);
    expect(fieldValue(host, 'taskDetailsLastError')).toBe('<THROW>this task always fails by design');
  });

  it('AD-37: Next run reads "Not scheduled while suspended" while Suspended is true', async () => {
    const { host } = await mount();
    expect(fieldValue(host, 'taskColumnNextRun')).toBe(STRINGS.taskDetailsNextSuspended);
  });

  it('the schedule words compose Daily/Once into How often and Time of day', async () => {
    const { host } = await mount();
    const heading = host.querySelector('.ocu-details-schedule');
    expect(heading?.textContent).toContain(STRINGS.taskDetailsHowOften);
    expect(heading?.textContent).toContain(STRINGS.taskScheduleEveryDay);
    expect(heading?.textContent).toContain(STRINGS.taskDetailsTimeOfDay);
    expect(heading?.textContent).toContain('Once at 03:00:00');
  });

  it('a silent tick highlights only the field whose value changed', async () => {
    const { fixture, setRows, actions, host } = await mount();
    expect(changedLabels(host)).toEqual([]);
    setRows([row({ Description: 'Changed on this tick' })]);
    expect(actions.run(DESCRIPTOR, REFRESH_ACTION_ID)).toBe(true);
    await settle(fixture);
    expect(fieldValue(host, 'tableColumnDescription')).toBe('Changed on this tick');
    expect(changedLabels(host)).toEqual([stringFor('tableColumnDescription')]);
    // Silent: no skeleton is redrawn over a view that already has values.
    expect(host.querySelector('.ocu-data-table-skeleton')).toBeNull();
  });

  it('AC3: with the chip at 5 s a timer tick re-reads silently and highlights the changed field', async () => {
    const { fixture, paths, refresh, setRows, fireTick, host } = await mount();
    expect(refresh.setRate(5)).toBe(true);
    setRows([row({ Description: 'Changed by the timer' })]);
    await fireTick();
    expect(paths).toHaveLength(2);
    expect(paths[1]).toContain('&taskId=1002');
    expect(fieldValue(host, 'tableColumnDescription')).toBe('Changed by the timer');
    expect(changedLabels(host)).toEqual([stringFor('tableColumnDescription')]);
    expect(host.querySelector('.ocu-data-table-skeleton')).toBeNull();
    expect(host.querySelector('[role="alert"]')).toBeNull();

    // A store notification that applies no new row (the chip moving) keeps the highlight.
    expect(refresh.setRate(10)).toBe(true);
    await settle(fixture);
    expect(changedLabels(host)).toEqual([stringFor('tableColumnDescription')]);
  });

  it('a fault on a re-read shows the refusal with Retry and keeps the last values', async () => {
    const { fixture, setFailing, actions, host } = await mount();
    setFailing(true);
    expect(actions.run(DESCRIPTOR, REFRESH_ACTION_ID)).toBe(true);
    await settle(fixture);
    expect(host.querySelector('.ocu-data-table-refusal')?.textContent).toContain(STRINGS.connectivityRequestRefused);
    expect(fieldValue(host, 'tableColumnName')).toBe('OcuPilotDemo nightly purge');
    expect(host.querySelector('.ocu-data-table-skeleton')).toBeNull();
  });

  it('a task switch shows the new task with no field marked changed', async () => {
    const { fixture, setRows, host } = await mount();
    setRows([row({ Id: 2001, Name: 'Second task', Description: 'Different task entirely' })]);
    await TestBed.inject(Router).navigateByUrl('/tasks/schedule/details/2001?ns=HSCUSTOM');
    await settle(fixture);
    expect(fieldValue(host, 'tableColumnName')).toBe('Second task');
    expect(changedLabels(host)).toEqual([]);
  });

  it('AD-37: a deleted or unknown task reads as zero rows and shows "This task no longer exists."', async () => {
    const { host } = await mount([]);
    expect(host.querySelector('.ocu-data-table-skeleton')).toBeNull();
    expect(host.textContent).toContain(STRINGS.taskDetailsGone);
  });

  it('the History link opens the per-task history for this task, and Edit task opens its editor (Story 9.8)', async () => {
    // Mutation (Rule 19): put TaskForm back in `CREATE_ONLY_FORMS` (`core/navigation.ts`) -> the
    // Edit leg goes red, the link gone.
    const { host } = await mount();
    const links = Array.from(host.querySelectorAll('.ocu-details-link'));
    const history = links.find((link) => link.textContent?.trim() === STRINGS.taskRunsLabel);
    expect(history).toBeDefined();
    expect(history?.getAttribute('href')).toContain('/tasks/schedule/history/1002');
    const edit = links.find((link) => link.textContent?.trim() === STRINGS.taskDetailsEdit);
    expect(edit).toBeDefined();
    expect(edit?.getAttribute('href')).toContain('/tasks/schedule/edit/1002');
  });

  it('offers Refresh and no other action (AD-10)', async () => {
    const { actions } = await mount();
    expect(actions.has(DESCRIPTOR, REFRESH_ACTION_ID)).toBe(true);
    const declaration = SCREENS.find((screen) => screen.descriptor === DESCRIPTOR);
    expect(declaration?.rowActions).toEqual([]);
    expect(declaration?.primaryAction.id).toBe('');
  });
});

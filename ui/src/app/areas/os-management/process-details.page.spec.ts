import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
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
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { ProcessDetailsPage } from './process-details.page';
import { stubAccountPreferences } from '../../testing/account-preferences';

/**
 * Process details (Story 6.8), wired end to end over a stub of the HTTP answer, with the real
 * `RefreshService`, `ScreenStores` and `createScreenRead` -- the same shape
 * `areas/tasks/details.page.spec.ts` takes for Task details. It renders the shipped descriptor,
 * read straight out of the mirror, so the field list and criterion are the ones the instance
 * validates.
 *
 * Mutations (Rule 19): pass `''` instead of `this.router.url` to `parentCriteria` in
 * `ProcessDetailsPage` -> the first path assertion goes red, carrying no `pid`. Drop
 * `CurrentLineAndRoutine` from `EXECUTION_FIELDS` in `process-details.store.ts` -> not this
 * file's own assertions, which never reference that field, but `ui/tools/process-details-store.test.mjs`'s
 * `groupFor` test, which goes red reading it as General instead of Execution. Read `InTransaction`
 * as zero for non-zero -> the transaction-word assertion goes red.
 */

const DESCRIPTOR = 'OcuPilot.Screen.Descriptor.ProcessDetails';

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

/** One process-details row, carrying every field the descriptor declares. */
function row(overrides: Record<string, unknown> = {}) {
  return {
    Pid: 4242,
    ParentPid: 1,
    UserName: '_SYSTEM',
    LoginRoles: '%All',
    EscalatedRoles: '',
    OSUserName: 'irisowner',
    NameSpace: 'HSCUSTOM',
    Priority: 8,
    StartTimeUTC: '2026-09-17 10:30:00',
    CPUTime: 1234,
    CommandsExecuted: 56,
    GlobalReferences: 789,
    PrivateGlobalReferences: 12,
    PrivateGlobalBlockCount: 3,
    MemoryAllocated: 65536,
    MemoryPeak: 32768,
    MemoryUsed: 16384,
    CurrentDevice: '|TCP|1972',
    OpenDevices: ['|TCP|1972', '|IPC|WRTDMN'],
    State: 'Run',
    InTransaction: 0,
    Routine: 'WRTDMN',
    CurrentLineAndRoutine: '',
    Location: '',
    ClientNodeName: '',
    ClientExecutableName: '',
    ClientIPAddress: '',
    ...overrides,
  };
}

async function mount(initialRows: unknown[] = [row()], url = '/os-management/processes/details/4242?ns=HSCUSTOM') {
  TestBed.resetTestingModule();
  const declaration = SCREENS.find((screen) => screen.descriptor === DESCRIPTOR) ?? null;
  let answerRows = initialRows;
  let failing = false;
  let actionAnswer: JsonResult<unknown> = { kind: 'ok', status: 200, body: {} };
  const paths: string[] = [];
  const posts: { path: string; body: string }[] = [];
  const scheduled: (() => void)[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      if (init.method === 'POST') {
        posts.push({ path, body: init.body ?? '' });
        return actionAnswer as JsonResult<T>;
      }
      paths.push(path);
      if (failing) return { kind: 'error', status: 500, code: 'SERVER.INTERNAL', reason: null, detail: null };
      return { kind: 'ok', status: 200, body: { fields: [], rows: answerRows, truncated: false, banner: '' } as T };
    },
  };
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  const bus = new ChangeBus();
  const refresh = new RefreshService({
    stores,
    connectivity: { retryWhenReachable: () => {} } as unknown as ConnectivityService,
    bus,
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
      { provide: ChangeBus, useValue: bus },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: OverlayStack, useValue: new OverlayStack() },
      {
        provide: ScopeService,
        useValue: { loaded: () => true, namespace: () => 'HSCUSTOM', subscribe: () => () => {} } as unknown as ScopeService,
      },
    ],
  });
  await TestBed.inject(Router).navigateByUrl(url);
  const fixture = TestBed.createComponent(ProcessDetailsPage);
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
    posts,
    setActionAnswer: (answer: JsonResult<unknown>) => {
      actionAnswer = answer;
    },
    store: stores.for(DESCRIPTOR, declaration?.refreshRates ?? []),
    handler: TestBed.inject(ScreenActionHandler),
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

function groupHeadingFor(host: HTMLElement, labelKey: string): string | null {
  const label = stringFor(labelKey);
  const groups = Array.from(host.querySelectorAll('.ocu-details-group'));
  for (const group of groups) {
    const fields = Array.from(group.querySelectorAll('.ocu-details-field'));
    if (fields.some((field) => field.querySelector('.ocu-details-field-label')?.textContent?.trim() === label)) {
      return group.querySelector('.ocu-details-heading')?.textContent?.trim() ?? null;
    }
  }
  return null;
}

function changedLabels(host: HTMLElement): string[] {
  return Array.from(host.querySelectorAll('.ocu-data-table-row-changed .ocu-details-field-label')).map(
    (label) => label.textContent?.trim() ?? ''
  );
}

afterEach(() => {
  for (const element of planted.splice(0)) element.remove();
});

describe('ProcessDetailsPage', () => {
  it('reads the route id as pid and renders the three groups', async () => {
    const { paths, host } = await mount();
    expect(paths).toHaveLength(1);
    expect(paths[0]).toContain('/screens/osmgmt.processdetails/read?');
    expect(paths[0]).toContain('&pid=4242');
    expect(host.querySelector('.ocu-data-table-skeleton')).toBeNull();
    expect(fieldValue(host, 'processColumnPid')).toBe('4242');
    expect(fieldValue(host, 'processColumnRoutine')).toBe('WRTDMN');
    expect(fieldValue(host, 'processDetailsOpenDevices')).toBe('|TCP|1972, |IPC|WRTDMN');
    expect(host.querySelectorAll('.ocu-details-heading').length).toBe(3);
  });

  it('AC1b: a cached SQL query routine and client fields render in their own groups', async () => {
    const { host } = await mount([
      row({ Routine: '%sqlcq.HSCUSTOM.cls1', ClientExecutableName: 'iris.exe', ClientIPAddress: '10.0.0.5' }),
    ]);
    expect(fieldValue(host, 'processColumnRoutine')).toBe('%sqlcq.HSCUSTOM.cls1');
    expect(groupHeadingFor(host, 'processColumnRoutine')).toBe(STRINGS.processDetailsGroupExecution);
    expect(fieldValue(host, 'processDetailsClientExecutable')).toBe('iris.exe');
    expect(fieldValue(host, 'processDetailsClientIpAddress')).toBe('10.0.0.5');
    expect(groupHeadingFor(host, 'processDetailsClientExecutable')).toBe(STRINGS.processDetailsGroupClientApplication);
  });

  it('InTransaction reads Yes for non-zero and No for zero', async () => {
    const { host, setRows, fixture, actions } = await mount([row({ InTransaction: 0 })]);
    expect(fieldValue(host, 'processDetailsInTransaction')).toBe(STRINGS.tableStatusNo);
    setRows([row({ InTransaction: 1 })]);
    expect(actions.run(DESCRIPTOR, REFRESH_ACTION_ID)).toBe(true);
    await settle(fixture);
    expect(fieldValue(host, 'processDetailsInTransaction')).toBe(STRINGS.tableStatusYes);
  });

  it('a silent re-read highlights only the field whose value changed', async () => {
    const { fixture, setRows, actions, host } = await mount();
    expect(changedLabels(host)).toEqual([]);
    setRows([row({ CommandsExecuted: 999 })]);
    expect(actions.run(DESCRIPTOR, REFRESH_ACTION_ID)).toBe(true);
    await settle(fixture);
    expect(fieldValue(host, 'processColumnCommands')).toBe('999');
    expect(changedLabels(host)).toEqual([stringFor('processColumnCommands')]);
    // Silent: no skeleton is redrawn over a view that already has values.
    expect(host.querySelector('.ocu-data-table-skeleton')).toBeNull();
  });

  it('AC3: with the chip at 5 s a timer tick re-reads silently and highlights the changed field', async () => {
    const { fixture, paths, refresh, setRows, fireTick, host } = await mount();
    expect(refresh.setRate(5)).toBe(true);
    setRows([row({ CommandsExecuted: 111 })]);
    await fireTick();
    expect(paths).toHaveLength(2);
    expect(paths[1]).toContain('&pid=4242');
    expect(fieldValue(host, 'processColumnCommands')).toBe('111');
    expect(changedLabels(host)).toEqual([stringFor('processColumnCommands')]);
    expect(host.querySelector('.ocu-data-table-skeleton')).toBeNull();
    expect(host.querySelector('[role="alert"]')).toBeNull();
    // "No announcement" (AC3): no element in this page ever carries `aria-live`, the same
    // guarantee `shell/status-bar.spec.ts` and `shell/command-bar.spec.ts` assert for their own
    // silent ticks.
    expect(host.querySelector('[aria-live]')).toBeNull();
  });

  it('a fault on a re-read shows the refusal with Retry and keeps the last values', async () => {
    const { setFailing, actions, fixture, host } = await mount();
    setFailing(true);
    expect(actions.run(DESCRIPTOR, REFRESH_ACTION_ID)).toBe(true);
    await settle(fixture);
    expect(host.querySelector('.ocu-data-table-refusal')?.textContent).toContain(STRINGS.connectivityRequestRefused);
    expect(host.querySelector('.ocu-data-table-refusal button')?.textContent?.trim()).toBe(STRINGS.actionRetry);
    expect(fieldValue(host, 'processColumnPid')).toBe('4242');
    expect(host.querySelector('.ocu-data-table-skeleton')).toBeNull();
  });

  it('AC4: an exited process reads as zero rows and shows "This process no longer exists."', async () => {
    const { host } = await mount([]);
    expect(host.querySelector('.ocu-data-table-skeleton')).toBeNull();
    expect(host.textContent).toContain(STRINGS.processDetailsGone);
    expect(host.querySelector('[role="alert"]')).toBeNull();
    expect(host.querySelector('.ocu-details-field')).toBeNull();
  });

  it('a process that exits while open, then answers again under its pid, shows no field marked changed', async () => {
    const { fixture, setRows, actions, host } = await mount();
    setRows([]);
    expect(actions.run(DESCRIPTOR, REFRESH_ACTION_ID)).toBe(true);
    await settle(fixture);
    expect(host.textContent).toContain(STRINGS.processDetailsGone);
    setRows([row({ Routine: 'OTHER', CommandsExecuted: 1 })]);
    expect(actions.run(DESCRIPTOR, REFRESH_ACTION_ID)).toBe(true);
    await settle(fixture);
    expect(fieldValue(host, 'processColumnRoutine')).toBe('OTHER');
    expect(changedLabels(host)).toEqual([]);
  });

  it('a pid switch shows the new process with no field marked changed', async () => {
    const { fixture, paths, setRows, host } = await mount();
    setRows([row({ Pid: 5151, Routine: 'DIFFERENT' })]);
    await TestBed.inject(Router).navigateByUrl('/os-management/processes/details/5151?ns=HSCUSTOM');
    await settle(fixture);
    expect(paths.at(-1)).toContain('&pid=5151');
    expect(fieldValue(host, 'processColumnPid')).toBe('5151');
    expect(changedLabels(host)).toEqual([]);
  });

  it('offers Refresh and the processes list\u2019s actions, and no name-cell link', async () => {
    const { actions, host } = await mount();
    expect(actions.has(DESCRIPTOR, REFRESH_ACTION_ID)).toBe(true);
    const declaration = SCREENS.find((screen) => screen.descriptor === DESCRIPTOR);
    expect(declaration?.rowActions.map((action) => action.id)).toEqual(['suspend', 'resume', 'terminate', 'terminate-with-error']);
    expect(declaration?.primaryAction.id).toBe('');
    for (const actionId of ['suspend', 'resume', 'terminate']) expect(actions.has(DESCRIPTOR, actionId)).toBe(true);
    expect(actions.has(DESCRIPTOR, 'terminate-with-error')).toBe(false);
    expect(host.querySelector('.ocu-details-field-value a')).toBeNull();
  });
});

describe('ProcessDetailsPage actions (Story 7.8)', () => {
  it('selects the pid it shows after each read, and nothing once the process has gone', async () => {
    // Mutation (Rule 19): drop `selectShown` from the store subscription -> the selection assertion
    // goes red, and the command bar offers the actions with "Select a row first".
    const { fixture, store, setRows, actions } = await mount();
    expect(store.selection()).toEqual(['4242']);
    setRows([]);
    expect(actions.run(DESCRIPTOR, REFRESH_ACTION_ID)).toBe(true);
    await settle(fixture);
    expect(store.selection()).toEqual([]);
  });

  it('renders Terminate\u2019s dialog, posts to the processes list, and reads the gone state after the deleted event', async () => {
    // Mutation (Rule 19): drop the dialog block from the page's template -> no dialog is found.
    const { fixture, host, posts, setActionAnswer, setRows, actions, handler } = await mount();
    setActionAnswer({ kind: 'ok', status: 200, body: { action: 'deleted', target: { type: 'process', scope: 'instance', id: '4242' } } });
    expect(actions.run(DESCRIPTOR, 'terminate')).toBe(true);
    await settle(fixture);
    const dialog = host.querySelector('app-typed-name-dialog') as HTMLElement | null;
    expect(dialog).not.toBeNull();
    expect(dialog?.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(`${STRINGS.actionTerminate} 4242`);
    expect(dialog?.querySelector('[data-slot="flag"]')?.textContent?.trim()).toBe(STRINGS.processTerminateErrorFlag);
    expect(posts).toEqual([]);

    const field = dialog?.querySelector('.ocu-typed-name-field') as HTMLInputElement;
    field.value = '4242';
    field.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    setRows([]);
    (dialog?.querySelector('.ocu-button-destructive') as HTMLButtonElement).click();
    await settle(fixture);
    expect(posts).toHaveLength(1);
    expect(posts[0].path).toBe('/api/ocupilot/screens/osmgmt.processes/action');
    expect(JSON.parse(posts[0].body)).toEqual({ action: 'terminate', id: '4242' });
    expect(handler.pending()).toBeNull();
    expect(host.querySelector('app-typed-name-dialog')).toBeNull();
    expect(host.textContent).toContain(STRINGS.processDetailsGone);
  });

  it('shows a refused action\u2019s own sentence as an alert', async () => {
    const { fixture, host, setActionAnswer, actions } = await mount();
    setActionAnswer({ kind: 'error', status: 403, code: 'PROHIBITED.SYSTEMPROCESS', reason: STRINGS.processRefusalSystem, detail: null } as unknown as JsonResult<unknown>);
    expect(actions.run(DESCRIPTOR, 'suspend')).toBe(true);
    await settle(fixture);
    const alert = host.querySelector('[role="alert"]');
    expect(alert?.textContent).toContain(STRINGS.processRefusalSystem);
  });

  it('cancels its own open dialog when it is destroyed', async () => {
    const { fixture, actions, handler } = await mount();
    expect(actions.run(DESCRIPTOR, 'terminate')).toBe(true);
    await settle(fixture);
    expect(handler.pending()?.descriptor).toBe(DESCRIPTOR);
    fixture.destroy();
    expect(handler.pending()).toBeNull();
  });
});

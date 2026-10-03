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
import { assembleScreenContext } from '../../core/screen-context';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS, type ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { JournalRecordsPage, nextOffset } from './journal-records.page';

/**
 * Journal records (Story 18.19), wired over stubs of the URL's screen and the HTTP answers, with the
 * real `RefreshService`, `ScreenStores`, `createScreenRead`, `DataTable` and `Dialog`, rendering the
 * shipped descriptor out of the mirror.
 *
 * Mutations (Rule 19), each applied and observed red here: make the bound read skip Journals' read
 * when no file is named -> "a cold open" red; make `nextOffset` answer the last address unchanged ->
 * "Next records" red; write the open record's value into a row's context field in the store ->
 * "screen context" red (a record kept only in the store's rows is narrowed out of the payload by the
 * eight declared context fields).
 */

const RECORDS = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.JournalRecordList') as ScreenDeclaration;

const FILE = '/durable/iris/mgr/journal/20261003.318';

const NEWEST = '/durable/iris/mgr/journal/20261003.320';

/** A record list row: the eight fields, never a value. */
const row = (address: number, node: string) => ({
  Address: address,
  TimeStamp: '2026-10-03 05:30:23',
  ProcessID: 764142,
  TypeName: 'SET',
  ExtTypeName: 'SET',
  InTransaction: false,
  GlobalNode: node,
  DatabaseName: '/durable/iris/mgr/ocuprobe185d/',
});

/** The record the detail route answers, values included. */
const RECORD = {
  TypeName: 'SET',
  ExtTypeName: 'SET',
  PrevAddress: 200,
  NextAddress: 400,
  TimeStamp: '2026-10-03 05:30:23',
  InTransaction: false,
  ProcessID: '764142',
  JobID: 764142,
  RemoteSystemID: 1073741824,
  ECPSystemID: 0,
  ClusterSequence: 0,
  Collation: 5,
  DatabaseName: '/durable/iris/mgr/ocuprobe185d/',
  GlobalNode: '^OcuProbe185(16)',
  GlobalReference: '^["^^/durable/iris/mgr/ocuprobe185d/"]OcuProbe185(16)',
  MirrorDatabaseName: '',
  NewValue: '<b>x</b>',
  NumberOfValues: 1,
  OldValue: 'OcuProbe185Value-16',
};

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 20));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

const planted: HTMLElement[] = [];

interface Options {
  readonly rows?: unknown[];
  readonly arrivals?: ScreenArrivals | null;
  readonly record?: JsonResult<unknown>;
  readonly listFault?: JsonResult<unknown>;
  readonly id?: string;
}

async function mount(options: Options = {}) {
  TestBed.resetTestingModule();
  const paths: string[] = [];
  const answerRows = options.rows ?? [row(100, '^OcuProbe185(1)'), row(300, '^OcuProbe185(3)'), row(200, '^OcuProbe185(2)')];
  const api = {
    requestJson: async <T,>(path: string): Promise<JsonResult<T>> => {
      paths.push(path);
      if (path.startsWith('/api/ocupilot/journal/record?')) {
        return (options.record ?? { kind: 'ok', status: 200, body: { record: RECORD } }) as JsonResult<T>;
      }
      if (options.listFault !== undefined && path.includes('/screens/osmgmt.journalrecords/read')) return options.listFault as JsonResult<T>;
      const list = path.includes('/screens/osmgmt.journals/read') ? [{ Name: NEWEST }] : answerRows;
      return { kind: 'ok', status: 200, body: { fields: [], rows: list, truncated: false, banner: '' } as T };
    },
  };
  const params = new BehaviorSubject(convertToParamMap(options.id === undefined ? {} : { id: options.id }));
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
      provideRouter([
        { path: 'os-management/journal-records', children: [] },
        { path: 'os-management/journal-records/:id', children: [] },
        { path: '**', children: [] },
      ]),
      { provide: NavigationService, useValue: { screenForUrl: () => RECORDS } as unknown as NavigationService },
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
      ...(options.arrivals === undefined || options.arrivals === null ? [] : [{ provide: ScreenArrivals, useValue: options.arrivals }]),
    ],
  });
  const router = TestBed.inject(Router);
  await router.navigateByUrl('/os-management/journal-records?ns=HSCUSTOM');
  const fixture = TestBed.createComponent(JournalRecordsPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  const host = fixture.nativeElement as HTMLElement;
  return {
    fixture,
    host,
    paths,
    store: stores.for(RECORDS.descriptor, RECORDS.refreshRates),
    openId: async (id: string) => {
      params.next(convertToParamMap({ id }));
      await settle(fixture);
    },
    choose: async (param: string, value: string) => {
      const control = host.querySelector(`#ocu-journal-records-${param}`) as HTMLInputElement | HTMLSelectElement;
      control.value = value;
      control.dispatchEvent(new Event(control.tagName === 'SELECT' ? 'change' : 'input', { bubbles: true }));
      await settle(fixture);
    },
    next: async () => {
      (host.querySelector('[data-journal-records="next"]') as HTMLElement).click();
      await settle(fixture);
    },
  };
}

const recordsPaths = (paths: readonly string[]) => paths.filter((path) => path.includes('/screens/osmgmt.journalrecords/read'));

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
});

describe('Journal records', () => {
  it('AC1: an arrival names the file, and the page reads it in one search and says so', async () => {
    const arrivals = new ScreenArrivals();
    arrivals.set({ route: RECORDS.route, criterion: '', criteria: { file: FILE } });
    const { host, paths } = await mount({ arrivals });
    expect(paths).toEqual([
      `/api/ocupilot/screens/osmgmt.journalrecords/read?maxRows=1000&file=${encodeURIComponent(FILE)}&offset=&order=0&column=GlobalNode&operator=%5B&value=`,
    ]);
    expect(host.querySelector('[data-journal-records="heading"]')?.textContent?.trim()).toBe(STRINGS.journalRecordsHeading.replace('<file>', FILE));
    expect(host.querySelectorAll('.ocu-data-table-body [role="row"]')).toHaveLength(3);
  });

  it('AC1: an arrival for another file, while the page is open, reads that file with the declared defaults', async () => {
    // Mutation (Rule 19): make `useArrival` keep the form's values for criteria the arrival omits ->
    // the second read still carries the earlier value and this goes red.
    const arrivals = new ScreenArrivals();
    arrivals.set({ route: RECORDS.route, criterion: '', criteria: { file: FILE } });
    const { fixture, paths, choose } = await mount({ arrivals });
    await choose('value', 'OcuProbe185');
    arrivals.set({ route: RECORDS.route, criterion: '', criteria: { file: NEWEST } });
    await settle(fixture);
    expect(recordsPaths(paths).at(-1)).toBe(
      `/api/ocupilot/screens/osmgmt.journalrecords/read?maxRows=1000&file=${encodeURIComponent(NEWEST)}&offset=&order=0&column=GlobalNode&operator=%5B&value=`
    );
  });

  it('AC1: a cold open first issues Journals\u2019 read for one row, then reads the newest file it names', async () => {
    const { host, paths } = await mount();
    expect(paths[0]).toBe('/api/ocupilot/screens/osmgmt.journals/read?maxRows=1');
    expect(recordsPaths(paths)).toHaveLength(1);
    expect(recordsPaths(paths)[0]).toContain(`&file=${encodeURIComponent(NEWEST)}&`);
    expect(host.querySelector('[data-journal-records="heading"]')?.textContent?.trim()).toBe(STRINGS.journalRecordsHeading.replace('<file>', NEWEST));
  });

  it('labels each choice\u2019s options in words, and draws no file field', async () => {
    const { host } = await mount();
    const labels = (param: string) =>
      Array.from(host.querySelectorAll(`#ocu-journal-records-${param} option`)).map((option) => option.textContent?.trim());
    expect(labels('order')).toEqual([STRINGS.journalRecordOldestFirst, STRINGS.journalRecordNewestFirst]);
    expect(labels('column')).toEqual([
      STRINGS.auditColumnTime,
      STRINGS.proposalEntityProcess,
      STRINGS.tableColumnType,
      STRINGS.journalRecordExtendedType,
      STRINGS.processDetailsInTransaction,
      STRINGS.journalRecordGlobalNode,
      STRINGS.systemInfoDatabase,
      STRINGS.journalRecordMirrorDatabase,
    ]);
    expect(labels('operator')).toEqual([
      STRINGS.journalRecordOpEquals,
      STRINGS.journalRecordOpNotEquals,
      STRINGS.journalRecordOpSortsAfter,
      STRINGS.journalRecordOpNotSortsAfter,
      STRINGS.journalRecordOpContains,
      STRINGS.journalRecordOpNotContains,
    ]);
    expect(host.querySelector('#ocu-journal-records-file')).toBeNull();
    expect((host.querySelector('#ocu-journal-records-column') as HTMLSelectElement).value).toBe('GlobalNode');
    expect((host.querySelector('#ocu-journal-records-operator') as HTMLSelectElement).value).toBe('[');
  });

  it('AC2: Next records continues after the page\u2019s highest address in file order, and before its lowest in reverse', async () => {
    const { paths, next, choose } = await mount();
    await next();
    expect(recordsPaths(paths).at(-1)).toContain('&offset=301&order=0&');
    await choose('order', '1');
    await choose('offset', '');
    await next();
    expect(recordsPaths(paths).at(-1)).toContain('&offset=99&order=1&');
    expect(nextOffset([row(5, 'a'), row(9, 'b'), row(7, 'c')], '0')).toBe('10');
    expect(nextOffset([row(5, 'a'), row(9, 'b'), row(7, 'c')], '1')).toBe('4');
    expect(nextOffset([], '0')).toBe('');
  });

  it('AC5: a row opens the dialog, which fetches the record and renders every value as text', async () => {
    const { host, paths, openId } = await mount();
    await openId('300');
    expect(paths.at(-1)).toBe(`/api/ocupilot/journal/record?file=${encodeURIComponent(NEWEST)}&address=300`);
    const dialog = host.querySelector('[role="dialog"]') as HTMLElement;
    expect(dialog).not.toBeNull();
    expect(dialog.textContent).toContain(STRINGS.journalRecordDialogTitle.replace('<offset>', '300'));
    const value = dialog.querySelector('pre[data-field="NewValue"]') as HTMLElement;
    expect(value.textContent).toBe('<b>x</b>');
    expect(value.querySelector('b')).toBeNull();
    expect(dialog.querySelector('pre[data-field="GlobalReference"]')?.textContent).toBe(RECORD.GlobalReference);
    expect(dialog.textContent).toContain(STRINGS.journalRecordOldValue);
    expect(dialog.textContent).toContain(STRINGS.journalRecordPrevious);
  });

  it('AC5: a reload on a record\u2019s route reads that record from the file the cold open names', async () => {
    // Mutation (Rule 19): make `loadRecord` read without waiting for a file -> the dialog asks for a
    // record of no file and this goes red.
    const { host, paths } = await mount({ id: '300' });
    const records = paths.filter((path) => path.startsWith('/api/ocupilot/journal/record?'));
    expect(records).toEqual([`/api/ocupilot/journal/record?file=${encodeURIComponent(NEWEST)}&address=300`]);
    expect(host.querySelector('pre[data-field="NewValue"]')?.textContent).toBe('<b>x</b>');
  });

  it('AC4: a refused record shows the refusal\u2019s reason', async () => {
    const reason = 'That record is not in this file, or its database is one you cannot read.';
    const { host, openId } = await mount({ record: { kind: 'error', status: 404, code: 'JOURNAL.RECORD.UNREADABLE', reason, detail: null } });
    await openId('300');
    expect(host.querySelector('[data-journal-records="refusal"]')?.textContent?.trim()).toBe(reason);
    expect(host.querySelector('pre[data-field="NewValue"]')).toBeNull();
  });

  it('a read past the async bound is the screen\u2019s PORT.TIMEOUT fault, with no row and no Next records', async () => {
    // Matrix row "Scan past the bound": the record list answers 503 PORT.TIMEOUT, a server fault the
    // shell's fault banner draws from the refresh's fault (the table draws no strip for a banner fault).
    const { host } = await mount({ listFault: { kind: 'error', status: 503, code: 'PORT.TIMEOUT', reason: null, detail: null } });
    expect(TestBed.inject(RefreshService).fault()?.code).toBe('PORT.TIMEOUT');
    expect(host.querySelectorAll('.ocu-data-table-body [role="row"]')).toHaveLength(0);
    expect(host.querySelector('[data-journal-records="next"]')).toBeNull();
  });

  it('closing the dialog keeps the criteria and reads nothing', async () => {
    const arrivals = new ScreenArrivals();
    arrivals.set({ route: RECORDS.route, criterion: '', criteria: { file: FILE } });
    const { host, paths, openId, choose } = await mount({ arrivals });
    await choose('value', 'OcuProbe185');
    await openId('300');
    const before = recordsPaths(paths).length;
    await openId('');
    expect(host.querySelector('[role="dialog"]')).toBeNull();
    expect(recordsPaths(paths)).toHaveLength(before);
    expect((host.querySelector('#ocu-journal-records-value') as HTMLInputElement).value).toBe('OcuProbe185');
    expect(host.querySelector('[data-journal-records="heading"]')?.textContent?.trim()).toBe(STRINGS.journalRecordsHeading.replace('<file>', FILE));
  });

  it('AC6: with the dialog open, neither the screen store nor the screen-context payload carries the record\u2019s values', async () => {
    const { store, openId } = await mount();
    await openId('300');
    const payload = assembleScreenContext({
      descriptor: RECORDS,
      rows: store.data(),
      filter: '',
      sort: '',
      direction: '',
      rowCap: 200,
      namespace: 'HSCUSTOM',
      entity: '300',
      share: true,
    });
    const text = JSON.stringify(payload);
    expect(store.data()).toHaveLength(3);
    expect(JSON.stringify(store.data())).not.toMatch(/NewValue|OldValue|GlobalReference|OcuProbe185Value-|<b>x<\/b>/);
    expect(text).toContain('^OcuProbe185(3)');
    expect(text).not.toContain('<b>x</b>');
    expect(text).not.toContain('OcuProbe185Value-');
    expect(text).not.toContain('GlobalReference');
  });
});

import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import type { ConnectivityService } from '../../core/connectivity';
import { NavigationService, UNGATED, screenForUrl } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { STRINGS } from '../../core/strings';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { JournalFileDetailsPage } from './journal-file-details.page';
import { JOURNAL_FILE_UNLISTED, isUnlisted } from './journal-file-details.store';

/**
 * Journal file details (Story 18.5, AC2), wired over a stub of the HTTP answer with the real
 * `RefreshService`, `ScreenStores` and `createScreenRead`, rendering the shipped descriptors out of
 * the mirror: the summary and the databases section read the one `file` criterion the route id
 * names, and a file the instance no longer lists reads as gone rather than refused.
 *
 * Mutation (Rule 19): drop the `isUnlisted` branch from `showGone` -> the unlisted leg goes red,
 * drawing the refusal strip instead.
 */

const FILE = '/durable/iris/mgr/journal/20261002.089';

const URL = '/os-management/journals/details/%252Fdurable%252Firis%252Fmgr%252Fjournal%252F20261002.089?ns=HSCUSTOM';

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 20));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

const planted: HTMLElement[] = [];

function summary(overrides: Record<string, unknown> = {}) {
  return {
    Name: FILE,
    CreationTime: '2026-10-02 15:00:00',
    FileCount: 89,
    MaxSize: 1073741824,
    FileGUID: '3C1A9B2E-0000-0000-0000-000000000089',
    FirstRecordAddress: 131088,
    LastRecordAddress: 262144,
    End: 270336,
    EncryptionKeyID: '',
    MinTransFileCount: 89,
    MinTransFileIndex: 0,
    ClusterStartTime: '',
    'PrevFile.File': '/durable/iris/mgr/journal/20261002.088',
    'NextFile.File': '/durable/iris/mgr/journal/20261002.090',
    ...overrides,
  };
}

interface Answers {
  details: JsonResult<unknown>;
  databases: JsonResult<unknown>;
}

function rows(list: unknown[]): JsonResult<unknown> {
  return { kind: 'ok', status: 200, body: { fields: [], rows: list, truncated: false, banner: '' } };
}

async function mount(answers: Answers) {
  TestBed.resetTestingModule();
  const paths: string[] = [];
  const api = {
    requestJson: async <T,>(path: string): Promise<JsonResult<T>> => {
      paths.push(path);
      return (path.includes('osmgmt.journalfiledatabases') ? answers.databases : answers.details) as JsonResult<T>;
    },
  };
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  const bus = new ChangeBus();
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
      { provide: NavigationService, useValue: { screenForUrl, screenVerdict: () => UNGATED } as unknown as NavigationService },
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: RefreshService, useValue: refresh },
      { provide: ScreenStores, useValue: stores },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: ChangeBus, useValue: bus },
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: ScopeService, useValue: { loaded: () => true, namespace: () => 'HSCUSTOM', subscribe: () => () => {} } as unknown as ScopeService },
    ],
  });
  await TestBed.inject(Router).navigateByUrl(URL);
  const fixture = TestBed.createComponent(JournalFileDetailsPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  return { host: fixture.nativeElement as HTMLElement, paths };
}

function fieldValue(host: HTMLElement, field: string): string | undefined {
  return host.querySelector(`.ocu-details-field[data-field="${field}"] .ocu-details-field-value`)?.textContent ?? undefined;
}

describe('Journal file details', () => {
  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
  });

  it('AC2: reads the route-id file for the summary and its databases', async () => {
    const { host, paths } = await mount({
      details: rows([summary()]),
      databases: rows([{ SFN: 0, DatabasePathOrAlias: '/durable/iris/mgr/' }, { SFN: 5, DatabasePathOrAlias: '/durable/iris/mgr/user/' }]),
    });
    const encoded = encodeURIComponent(FILE);
    expect(paths.some((path) => path.includes('osmgmt.journalfile/') && path.includes(`file=${encoded}`))).toBe(true);
    expect(paths.some((path) => path.includes('osmgmt.journalfiledatabases') && path.includes(`file=${encoded}`))).toBe(true);
    expect(fieldValue(host, 'Name')).toBe(FILE);
    expect(fieldValue(host, 'PrevFile.File')).toBe('/durable/iris/mgr/journal/20261002.088');
    expect(fieldValue(host, 'EncryptionKeyID')).toBe(STRINGS.journalDetailsNotEncrypted);
    const section = host.querySelector('[data-journal="databases"]') as HTMLElement;
    expect(section.querySelector('h2')?.textContent?.trim()).toBe(STRINGS.databaseListLabel);
    expect(Array.from(section.querySelectorAll('th')).map((cell) => cell.textContent?.trim())).toEqual([STRINGS.systemInfoDatabase, STRINGS.journalColumnSfn]);
    expect(section.querySelectorAll('tbody tr')).toHaveLength(2);
  });

  it('a file with no database records reads the databases empty state', async () => {
    const { host } = await mount({ details: rows([summary()]), databases: rows([]) });
    expect(host.textContent).toContain(STRINGS.journalFileDatabaseListEmpty);
  });

  it('AC2: a file the instance no longer lists reads as gone, never as a refusal', async () => {
    const unlisted: JsonResult<unknown> = { kind: 'error', status: 404, code: JOURNAL_FILE_UNLISTED, reason: 'no', detail: null };
    const { host } = await mount({ details: unlisted, databases: unlisted });
    expect(host.querySelector('[data-journal="gone"]')?.textContent?.trim()).toBe(STRINGS.journalFileDetailsGone);
    expect(host.querySelector('.ocu-data-table-refusal')).toBeNull();
    expect(host.querySelector('[data-journal="summary"]')).toBeNull();
  });

  it('any other refusal draws the refusal strip with Retry', async () => {
    const refused: JsonResult<unknown> = { kind: 'error', status: 500, code: 'SERVER.INTERNAL', reason: null, detail: null };
    const { host } = await mount({ details: refused, databases: refused });
    expect(host.querySelector('.ocu-data-table-refusal')?.textContent).toContain(STRINGS.connectivityRequestRefused);
    expect(host.querySelector('[data-journal="gone"]')).toBeNull();
  });

  it('isUnlisted answers only the journal guard\u2019s code', () => {
    expect(isUnlisted(null)).toBe(false);
    expect(isUnlisted({ kind: 'absent', status: 404, code: 'PORT.NOTFOUND', path: '' })).toBe(false);
    expect(isUnlisted({ kind: 'absent', status: 404, code: JOURNAL_FILE_UNLISTED, path: '' })).toBe(true);
  });
});

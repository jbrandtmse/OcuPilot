import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { JournalSettingsPage } from './journal-settings.page';
import { JOURNAL_SETTINGS_PATH } from './journal-settings.store';

/**
 * Journal settings over stubs of what an instance supplies -- the screen's declared read, the Save
 * and the allowed directories read. The real store, picker and template run, so the assertions are
 * about rendered DOM (Story 18.18, AC1, AC3, AC4, AC6, AD-21's sixth case).
 */

const ROOT = '/durable/iris/mgr/';

const DIRECTORY = `${ROOT}journal/`;

const ROW = {
  CurrentDirectory: DIRECTORY,
  AlternateDirectory: DIRECTORY,
  FileSizeLimit: 1024,
  JournalFilePrefix: '',
  ArchiveName: '',
  PurgeArchived: false,
  DaysBeforePurge: 2,
  BackupsBeforePurge: 2,
  FreezeOnError: false,
  JournalcspSession: false,
  CompressFiles: true,
  wijdir: '',
  targwijsz: 0,
};

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(options: { readonly row?: Record<string, unknown>; readonly save?: JsonResult<unknown> } = {}) {
  TestBed.resetTestingModule();
  const calls: { path: string; method: string; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      calls.push({ path, method, body: init.body ?? '' });
      if (path.includes('osmgmt.journalsettings/read?')) {
        return { kind: 'ok', status: 200, body: { rows: [options.row ?? ROW], truncated: false, banner: '' } } as unknown as JsonResult<T>;
      }
      if (path.includes('/read?')) {
        return { kind: 'ok', status: 200, body: { rows: [{ Directory: ROOT }], truncated: false, banner: '' } } as unknown as JsonResult<T>;
      }
      return (options.save ?? { kind: 'ok', status: 200, body: { readBack: { verdict: 'matches', fields: [], written: [] } } }) as JsonResult<T>;
    },
  };
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: FormDirty, useValue: new FormDirty() },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  await TestBed.inject(Router).navigateByUrl('/os-management/journal-settings?ns=USER');
  const fixture = TestBed.createComponent(JournalSettingsPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, calls, host: fixture.nativeElement as HTMLElement };
}

function save(host: HTMLElement): void {
  (host.querySelector('.ocu-form-bar-actions .ocu-button-primary') as HTMLButtonElement).click();
}

function input(host: HTMLElement, id: string): HTMLInputElement {
  return host.querySelector(`#${id}`) as HTMLInputElement;
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('JournalSettingsPage', () => {
  it('AC1: the thirteen fields, the directories and the three shown-only fields read-only with their hint', async () => {
    const { host } = await mount();
    expect(input(host, 'ocu-journal-settings-CurrentDirectory').readOnly).toBe(true);
    expect(input(host, 'ocu-journal-settings-CurrentDirectory').value).toBe(DIRECTORY);
    expect(input(host, 'ocu-journal-settings-AlternateDirectory').readOnly).toBe(true);
    expect(input(host, 'ocu-journal-settings-FileSizeLimit').value).toBe('1024');
    expect(input(host, 'ocu-journal-settings-JournalFilePrefix').value).toBe('');
    const archive = input(host, 'ocu-journal-settings-ArchiveName');
    expect([archive.readOnly, archive.value]).toEqual([true, STRINGS.tableEmptyValue]);
    const wij = input(host, 'ocu-journal-settings-wijdir');
    expect([wij.readOnly, wij.value]).toEqual([true, STRINGS.journalSettingsWijManager]);
    const size = input(host, 'ocu-journal-settings-targwijsz');
    expect([size.readOnly, size.value]).toEqual([true, STRINGS.oauthClientNotSet]);
    for (const shown of [archive, wij, size]) expect(shown.getAttribute('aria-describedby')).toBe('ocu-journal-settings-shown-only');
    expect(host.querySelector('#ocu-journal-settings-shown-only')?.textContent?.trim()).toBe(STRINGS.journalSettingsShownOnly);
    expect(input(host, 'ocu-journal-settings-CompressFiles').checked).toBe(true);
    expect(host.querySelector('[data-slot="directory-line"]')?.textContent?.trim()).toBe(STRINGS.journalSettingsDirectoryNewFile);
    expect(host.querySelector('app-server-path-picker')).toBeNull();
  });

  it('the purge rule\u2019s disabling: no archive target disables Purge archived, and while it is checked the counts take no input', async () => {
    const first = await mount();
    const purge = input(first.host, 'ocu-journal-settings-PurgeArchived');
    expect([purge.disabled, purge.checked]).toEqual([true, false]);
    expect(input(first.host, 'ocu-journal-settings-DaysBeforePurge').disabled).toBe(false);
    const archived = await mount({ row: { ...ROW, ArchiveName: 'ARCHIVE1', PurgeArchived: true } });
    expect(input(archived.host, 'ocu-journal-settings-ArchiveName').value).toBe('ARCHIVE1');
    expect(input(archived.host, 'ocu-journal-settings-PurgeArchived').disabled).toBe(false);
    expect(input(archived.host, 'ocu-journal-settings-DaysBeforePurge').disabled).toBe(true);
    expect(input(archived.host, 'ocu-journal-settings-BackupsBeforePurge').disabled).toBe(true);
    input(archived.host, 'ocu-journal-settings-PurgeArchived').click();
    await settle(archived.fixture);
    expect(input(archived.host, 'ocu-journal-settings-DaysBeforePurge').disabled).toBe(false);
  });

  it('AC6: checking Freeze on error states its consequence under the checkbox', async () => {
    const { fixture, host } = await mount();
    expect(host.querySelector('[data-slot="freeze-consequence"]')).toBeNull();
    input(host, 'ocu-journal-settings-FreezeOnError').click();
    await settle(fixture);
    expect(host.querySelector('[data-slot="freeze-consequence"]')?.textContent?.trim()).toBe(STRINGS.journalSettingsFreezeConsequence);
    expect(input(host, 'ocu-journal-settings-FreezeOnError').getAttribute('aria-describedby')).toBe('ocu-journal-settings-freeze-consequence');
  });

  it('AC2: Save sends only the changed fields, and the directories\u2019 arguments only while one is changed', async () => {
    const { fixture, host, calls } = await mount();
    const size = input(host, 'ocu-journal-settings-FileSizeLimit');
    size.value = '1000';
    size.dispatchEvent(new Event('input'));
    await settle(fixture);
    save(host);
    await settle(fixture);
    const write = calls.find((call) => call.method === 'PUT');
    expect(write?.path).toBe(JOURNAL_SETTINGS_PATH);
    expect(JSON.parse(write?.body ?? '{}')).toEqual({ FileSizeLimit: 1000 });
    expect(host.querySelector('.ocu-form-bar-status [role="status"]')?.textContent?.trim()).toBe(`${STRINGS.formSaved} \u00b7 ${STRINGS.readBackMatches}`);
  });

  it('AD-21: Change draws the picker, its preselected root is not a change, and a PATH refusal lands on the picker\u2019s field', async () => {
    const reason = 'The manager directory holds the instance\u2019s own files.';
    const { fixture, host, calls } = await mount({
      save: {
        kind: 'error',
        status: 422,
        code: 'JOURNAL.VALIDATION',
        reason: 'The journal settings were refused.',
        detail: { violations: [{ field: 'primaryPath', code: 'PATH.MANAGERDIR', reason }] },
      },
    });
    (host.querySelector('[data-action="change-primary"]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(host.querySelector('app-server-path-picker')).not.toBeNull();
    expect((host.querySelector('#ocu-journal-settings-primary-root') as HTMLSelectElement).value).toBe(ROOT);
    expect(TestBed.inject(FormDirty).dirty()).toBe(false);
    save(host);
    await settle(fixture);
    expect(JSON.parse(calls.find((call) => call.method === 'PUT')?.body ?? '{}')).toEqual({ primaryRoot: ROOT, primaryPath: '' });
    expect(host.querySelector('#ocu-journal-settings-primary-path-reason')?.textContent?.trim()).toBe(reason);
    expect((host.querySelector('#ocu-journal-settings-primary-path') as HTMLInputElement).getAttribute('aria-invalid')).toBe('true');
    expect(host.querySelector('.ocu-form-summary')).not.toBeNull();
  });

  it('a violation on a field is drawn on that field and in the summary', async () => {
    const reason = 'Enter a whole number of megabytes from 0 to 4079.';
    const { fixture, host } = await mount({
      save: {
        kind: 'error',
        status: 422,
        code: 'JOURNAL.VALIDATION',
        reason: 'The journal settings were refused.',
        detail: { violations: [{ field: 'FileSizeLimit', code: 'JOURNAL.FILESIZE.SHAPE', reason }] },
      },
    });
    const size = input(host, 'ocu-journal-settings-FileSizeLimit');
    size.value = '5000';
    size.dispatchEvent(new Event('input'));
    await settle(fixture);
    save(host);
    await settle(fixture);
    expect(host.querySelector('#ocu-journal-settings-FileSizeLimit-reason')?.textContent?.trim()).toBe(reason);
    expect(input(host, 'ocu-journal-settings-FileSizeLimit').getAttribute('aria-invalid')).toBe('true');
    expect(host.querySelector('.ocu-form-summary-list')?.textContent?.trim()).toBe(reason);
  });

  it('AD-8: a Save refused for a missing pair names the pair and the form\u2019s action', async () => {
    const { fixture, host } = await mount({
      save: { kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'Forbidden', detail: { failedPair: '%Admin_Operate:USE' } },
    });
    input(host, 'ocu-journal-settings-CompressFiles').click();
    await settle(fixture);
    save(host);
    await settle(fixture);
    expect(host.querySelector('.ocu-banner-warning')?.textContent?.trim()).toBe('You need %Admin_Operate:USE to change the journal settings.');
  });

  it('the leave guard: an unsaved change marks the form dirty, and Cancel reads the settings again, clean', async () => {
    const { fixture, host, calls } = await mount();
    input(host, 'ocu-journal-settings-JournalcspSession').click();
    await settle(fixture);
    expect(TestBed.inject(FormDirty).dirty()).toBe(true);
    (host.querySelector('.ocu-form-bar-actions .ocu-button-text') as HTMLButtonElement).click();
    await settle(fixture);
    expect(TestBed.inject(FormDirty).dirty()).toBe(false);
    expect(input(host, 'ocu-journal-settings-JournalcspSession').checked).toBe(false);
    expect(calls.filter((call) => call.path.includes('osmgmt.journalsettings/read?')).length).toBe(2);
  });
});

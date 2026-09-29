import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { OverlayStack } from '../../core/overlay-stack';
import { uncheckedLine } from '../../core/privileges';
import { STRINGS } from '../../core/strings';
import { DatabaseEditorPage } from './database-editor.page';
import { DATABASE_FORM_PATH, DATABASE_PATH } from './database-wizard.store';

/**
 * The local database editor over stubs of what an instance supplies -- the form read, the Save, the
 * allowed directories read and the volume files read. The real store, picker and template run, so
 * the assertions are about rendered DOM (AC2, AD-5, AD-21's sixth case).
 */

const ROOT = '/durable/iris/mgr/';

const DIRECTORY = `${ROOT}ocuprobe183a/`;

const FORM = {
  requiredFields: ['Name', 'root'],
  rules: [],
  resources: ['%DB_OCUPROBE183A', '%DB_USER'],
  Name: 'OCUPROBE183A',
  configuration: { Server: '', Directory: DIRECTORY, StreamLocation: '', ClusterMountMode: false, MountAtStartup: true, MountRequired: false },
  file: {
    MaxSize: 0,
    ExpansionSize: 0,
    NewVolumeThreshold: 0,
    NewVolumeDirectory: DIRECTORY,
    ResourceName: '%DB_OCUPROBE183A',
    NewGlobalIsKeep: false,
    NewGlobalCollation: 'IRIS standard',
    ClusterMountMode: false,
    ReadOnly: false,
    GlobalJournalState: true,
    Directory: DIRECTORY,
  },
};

const VOLUME_ROW = { VolumeNumber: 0, VolumeDirectory: DIRECTORY, File: 'IRIS.DAT', Size: 1, VolumeDirectoryTotalSize: 1, DiskFree: 10 };

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(options: { readonly form?: unknown; readonly save?: JsonResult<unknown> } = {}) {
  TestBed.resetTestingModule();
  const calls: { path: string; method: string; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      calls.push({ path, method, body: init.body ?? '' });
      if (path.startsWith(DATABASE_FORM_PATH)) return { kind: 'ok', status: 200, body: options.form ?? FORM } as unknown as JsonResult<T>;
      if (path.includes('osmgmt.databasevolumes/read?')) {
        return { kind: 'ok', status: 200, body: { rows: [VOLUME_ROW], truncated: false, banner: '' } } as unknown as JsonResult<T>;
      }
      if (path.includes('/read?')) {
        return { kind: 'ok', status: 200, body: { rows: [{ Directory: ROOT }], truncated: false, banner: '' } } as unknown as JsonResult<T>;
      }
      return (options.save ?? { kind: 'ok', status: 200, body: { name: 'OCUPROBE183A', file: {} } }) as JsonResult<T>;
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
  await TestBed.inject(Router).navigateByUrl('/os-management/local-databases/edit/OCUPROBE183A?ns=USER');
  const fixture = TestBed.createComponent(DatabaseEditorPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, calls, host: fixture.nativeElement as HTMLElement };
}

function save(host: HTMLElement): void {
  (host.querySelector('.ocu-form-bar-actions .ocu-button-primary') as HTMLButtonElement).click();
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('DatabaseEditorPage', () => {
  it('AC2: the name and directory read-only, then General, Mounting and Volume files, with the volume files read', async () => {
    const { host, calls } = await mount();
    expect(calls[0].path).toBe(`${DATABASE_FORM_PATH}?name=OCUPROBE183A`);
    expect((host.querySelector('#ocu-database-edit-Name') as HTMLInputElement).readOnly).toBe(true);
    expect((host.querySelector('#ocu-database-edit-Directory') as HTMLInputElement).value).toBe(DIRECTORY);
    expect([...host.querySelectorAll('h2.ocu-details-heading')].map((heading) => heading.textContent?.trim())).toEqual([
      STRINGS.processDetailsGroupGeneral,
      STRINGS.databaseGroupMounting,
      STRINGS.databaseVolumeListLabel,
    ]);
    expect((host.querySelector('#ocu-database-edit-ResourceName') as HTMLElement).tagName).toBe('SELECT');
    expect((host.querySelector('#ocu-database-edit-MountAtStartup') as HTMLInputElement).checked).toBe(true);
    const volumes = host.querySelectorAll('[data-group="volumes"] tbody tr');
    expect(volumes).toHaveLength(1);
    expect(volumes[0].textContent).toContain('IRIS.DAT');
  });

  it('AC2: Save sends only the changed groups, each with its changed fields', async () => {
    const { fixture, host, calls } = await mount();
    const size = host.querySelector('#ocu-database-edit-ExpansionSize') as HTMLInputElement;
    size.value = '8';
    size.dispatchEvent(new Event('input'));
    (host.querySelector('#ocu-database-edit-MountRequired') as HTMLInputElement).click();
    await settle(fixture);
    save(host);
    await settle(fixture);
    const write = calls.find((call) => call.method === 'PUT');
    expect(write?.path).toBe(`${DATABASE_PATH}/OCUPROBE183A`);
    expect(JSON.parse(write?.body ?? '{}')).toEqual({ configuration: { MountRequired: true }, file: { ExpansionSize: 8 } });
    expect(host.querySelector('.ocu-form-bar-status [role="status"]')?.textContent?.trim()).toBe(STRINGS.formSaved);
  });

  it('AD-21: Change reveals the picker, and a PATH refusal on the new volume directory lands on the picker\u2019s field', async () => {
    const reason = 'Choose a subdirectory of the allowed directory, not the directory itself.';
    const { fixture, host, calls } = await mount({
      save: {
        kind: 'error',
        status: 422,
        code: 'DATABASE.VALIDATION',
        reason: 'The database was refused.',
        detail: { violations: [{ field: 'volumePath', code: 'PATH.MANAGERDIR', reason }] },
      },
    });
    expect(host.querySelector('app-server-path-picker')).toBeNull();
    expect(TestBed.inject(FormDirty).dirty()).toBe(false);
    (host.querySelector('[data-action="change-volume-directory"]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(host.querySelector('app-server-path-picker')).not.toBeNull();
    expect((host.querySelector('#ocu-database-volume-root') as HTMLSelectElement).value).toBe(ROOT);
    // After an explicit Change, the picker's preselection is an edit: the form reads dirty.
    expect(TestBed.inject(FormDirty).dirty()).toBe(true);
    save(host);
    await settle(fixture);
    expect(JSON.parse(calls.find((call) => call.method === 'PUT')?.body ?? '{}')).toEqual({ file: { volumeRoot: ROOT, volumePath: '' } });
    expect(host.querySelector('#ocu-database-volume-path-reason')?.textContent?.trim()).toBe(reason);
    expect((host.querySelector('#ocu-database-volume-path') as HTMLInputElement).getAttribute('aria-invalid')).toBe('true');
  });

  it('Cancel beside the picker keeps the current volume directory: the picker closes and a Save sends none', async () => {
    const { fixture, host, calls } = await mount();
    (host.querySelector('[data-action="change-volume-directory"]') as HTMLButtonElement).click();
    await settle(fixture);
    expect((host.querySelector('#ocu-database-volume-root') as HTMLSelectElement).value).toBe(ROOT);
    (host.querySelector('[data-action="keep-volume-directory"]') as HTMLButtonElement).click();
    await settle(fixture);
    expect(host.querySelector('app-server-path-picker')).toBeNull();
    expect(host.querySelector('[data-action="change-volume-directory"]')).not.toBeNull();
    save(host);
    await settle(fixture);
    expect(calls.filter((call) => call.method === 'PUT')).toEqual([]);
  });

  it('a caller who may not list the resources sees the resource read-only, naming the pair', async () => {
    const { host } = await mount({ form: { ...FORM, resources: undefined, resourcesRefused: '%Admin_Secure:USE' } });
    const resource = host.querySelector('#ocu-database-edit-ResourceName') as HTMLInputElement;
    expect(resource.tagName).toBe('INPUT');
    expect(resource.readOnly).toBe(true);
    expect(resource.value).toBe('%DB_OCUPROBE183A');
    expect(host.querySelector('[data-slot="resources-refused"]')?.textContent?.trim()).toBe(uncheckedLine('%Admin_Secure:USE'));
  });

  it('AD-8: a Save refused for a missing pair names the pair and the editor\u2019s action', async () => {
    const { fixture, host } = await mount({
      save: { kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'Forbidden', detail: { failedPair: '%Admin_Operate:USE' } },
    });
    (host.querySelector('#ocu-database-edit-MountRequired') as HTMLInputElement).click();
    await settle(fixture);
    save(host);
    await settle(fixture);
    expect(host.querySelector('.ocu-banner-warning')?.textContent?.trim()).toBe('You need %Admin_Operate:USE to change this database.');
  });
});

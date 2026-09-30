import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { OverlayStack } from '../../core/overlay-stack';
import { uncheckedLine } from '../../core/privileges';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { STRINGS } from '../../core/strings';
import { stubAccountPreferences } from '../../testing/account-preferences';
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
  let actionAnswer: JsonResult<unknown> | null = null;
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
      if (path.endsWith('/action') && actionAnswer !== null) return actionAnswer as JsonResult<T>;
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
      // Story 18.4: Add a volume runs through the shell's handler, which registers every declared action.
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: ScreenStores, useValue: new ScreenStores({ account: stubAccountPreferences() }) },
    ],
  });
  await TestBed.inject(Router).navigateByUrl('/os-management/local-databases/edit/OCUPROBE183A?ns=USER');
  const fixture = TestBed.createComponent(DatabaseEditorPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  const setAction = (value: JsonResult<unknown>): void => {
    actionAnswer = value;
  };
  return { fixture, calls, host: fixture.nativeElement as HTMLElement, setAction };
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

  it('Story 18.4: Size (MB) is drawn from the form read\u2019s size and sent as its own group, and absent without one', async () => {
    // Mutation (Rule 19): send Size inside the file group -> the body assertion goes red.
    const without = await mount();
    expect(without.host.querySelector('[data-field="size"]')).toBeNull();
    const { fixture, host, calls } = await mount({ form: { ...FORM, size: { Size: 1 } } });
    const size = host.querySelector('#ocu-database-edit-Size') as HTMLInputElement;
    expect(host.querySelector('label[for="ocu-database-edit-Size"]')?.textContent?.trim()).toBe(STRINGS.databaseSizeField);
    expect(size.value).toBe('1');
    size.value = '3';
    size.dispatchEvent(new Event('input'));
    await settle(fixture);
    save(host);
    await settle(fixture);
    const write = calls.find((call) => call.method === 'PUT');
    expect(JSON.parse(write?.body ?? '{}')).toEqual({ size: { Size: 3 } });
  });

  it('Story 18.4: Add a volume waits for a clean form, then warns with its initial size and sends expand', async () => {
    // Mutation (Rule 19): release Add a volume while the form is dirty -> the first click sends and this goes red.
    const { fixture, host, calls } = await mount();
    const add = () => host.querySelector('[data-action="add-volume"]') as HTMLButtonElement;
    expect(add().textContent?.trim()).toBe(STRINGS.databaseExpandAction);
    expect(add().getAttribute('aria-disabled')).toBeNull();
    const expansion = host.querySelector('#ocu-database-edit-ExpansionSize') as HTMLInputElement;
    expansion.value = '8';
    expansion.dispatchEvent(new Event('input'));
    await settle(fixture);
    expect(add().getAttribute('aria-disabled')).toBe('true');
    const reason = host.querySelector('[data-volume="dirty"]') as HTMLElement;
    expect(reason.textContent?.trim()).toBe(STRINGS.databaseExpandDirty);
    expect(add().getAttribute('aria-describedby')).toBe(reason.id);
    add().click();
    await settle(fixture);
    expect(host.querySelector('[role="dialog"]')).toBeNull();
    expansion.value = '0';
    expansion.dispatchEvent(new Event('input'));
    await settle(fixture);
    save(host);
    await settle(fixture);
    expect(add().getAttribute('aria-disabled')).toBeNull();
    const volumeReads = calls.filter((call) => call.path.includes('osmgmt.databasevolumes/read?')).length;
    add().click();
    await settle(fixture);
    const dialog = host.querySelector('[role="dialog"]') as HTMLElement;
    expect(dialog.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.databaseExpandAction);
    expect(dialog.textContent).toContain(STRINGS.databaseExpandConsequence);
    const field = dialog.querySelector('[data-slot="field"] input') as HTMLInputElement;
    expect(dialog.querySelector('[data-slot="field"] label')?.textContent?.trim()).toBe(STRINGS.databaseInitialSize);
    // Mutation (Rule 19): drop the expand's `hintKey` -> the hint and Proceed's reason go red.
    const hint = dialog.querySelector('[data-slot="field"] .ocu-field-caption') as HTMLElement;
    expect(hint.textContent?.trim()).toBe(STRINGS.databaseInitialSizeHint);
    const proceed = dialog.querySelector('.ocu-dialog-actions .ocu-button-primary') as HTMLButtonElement;
    expect([proceed.getAttribute('aria-disabled'), proceed.getAttribute('aria-describedby')]).toEqual(['true', hint.id]);
    field.value = '5';
    field.dispatchEvent(new Event('input'));
    await settle(fixture);
    (dialog.querySelector('.ocu-dialog-actions .ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    const action = calls.find((call) => call.path.endsWith('/osmgmt.localdatabases/action'));
    expect(JSON.parse(action?.body ?? '{}')).toEqual({ action: 'expand', id: 'OCUPROBE183A', values: { InitialSize: '5' } });
    expect(calls.filter((call) => call.path.includes('osmgmt.databasevolumes/read?')).length).toBe(volumeReads + 1);
    expect(host.querySelector('[data-volume="operation"]')?.textContent?.trim()).toBe(
      STRINGS.databaseOperationFinished.replace('<operation>', STRINGS.databaseExpandAction)
    );
  });

  it('Story 18.4: Add a volume that continues reads the still-running sentence, and a 409 its sentence', async () => {
    // Mutation (Rule 19): `operationLine` answers '' for `continues` -> the still-running line goes red;
    // `onAddVolume` drops its `setRefusal` -> the refusal goes red.
    const { fixture, host, setAction } = await mount();
    const addVolume = async (): Promise<void> => {
      (host.querySelector('[data-action="add-volume"]') as HTMLButtonElement).click();
      await settle(fixture);
      const field = host.querySelector('[role="dialog"] [data-slot="field"] input') as HTMLInputElement;
      field.value = '5';
      field.dispatchEvent(new Event('input'));
      await settle(fixture);
      (host.querySelector('[role="dialog"] .ocu-dialog-actions .ocu-button-primary') as HTMLButtonElement).click();
      await settle(fixture);
    };
    setAction({ kind: 'ok', status: 200, body: { action: 'updated', continues: true } });
    await addVolume();
    expect(host.querySelector('[data-volume="operation"]')?.textContent?.trim()).toBe(STRINGS.auditDatabaseStillRunning);
    const reason = 'This database is dismounted. Mount it first.';
    setAction({ kind: 'error', status: 409, code: 'DATABASE.DISMOUNTED', reason, detail: null });
    await addVolume();
    expect(host.querySelector('[data-volume="refusal"]')?.textContent?.trim()).toBe(reason);
    expect(host.querySelector('[data-volume="operation"]')?.textContent?.trim()).toBe('');
  });

  it('Story 18.4: a Save whose size grow continues reads the still-running sentence until the next edit', async () => {
    // Mutation (Rule 19): `savedText` ignores the store's `continues` -> the still-running line goes red.
    const { fixture, host } = await mount({
      form: { ...FORM, size: { Size: 1 } },
      save: { kind: 'ok', status: 200, body: { name: 'OCUPROBE183A', size: {}, continues: true } },
    });
    const status = () => host.querySelector('.ocu-form-bar-status [role="status"]')?.textContent?.trim();
    const size = host.querySelector('#ocu-database-edit-Size') as HTMLInputElement;
    size.value = '3';
    size.dispatchEvent(new Event('input'));
    await settle(fixture);
    save(host);
    await settle(fixture);
    expect(status()).toBe(STRINGS.auditDatabaseStillRunning);
    const expansion = host.querySelector('#ocu-database-edit-ExpansionSize') as HTMLInputElement;
    expansion.value = '8';
    expansion.dispatchEvent(new Event('input'));
    await settle(fixture);
    expect(status()).toBeUndefined();
  });
});

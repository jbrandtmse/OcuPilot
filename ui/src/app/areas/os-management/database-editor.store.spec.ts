import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { DatabaseEditor } from './database-editor.store';
import { DATABASE_FORM_PATH, DATABASE_PATH } from './database-wizard.store';

/**
 * The local database editor's store (AC2, AD-4, AD-14, AD-39, AD-55): the fresh read split into its
 * two groups, a Save sending only the changed groups with only their changed fields, the new volume
 * directory as a root and a path, and the Volume files read through `DatabaseVolumeList`'s declared
 * read with its `dir` criterion. The bus is real and only the server's answers are stubbed.
 */

const DIRECTORY = '/durable/iris/mgr/ocuprobe183a/';

const FORM = {
  requiredFields: ['Name', 'root'],
  rules: [],
  resources: ['%DB_OCUPROBE183A', '%DB_USER'],
  Name: 'OCUPROBE183A',
  configuration: { Server: '', Directory: DIRECTORY, StreamLocation: '', ClusterMountMode: false, MountAtStartup: false, MountRequired: false },
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

const VOLUMES = { rows: [{ VolumeNumber: 0, VolumeDirectory: DIRECTORY, File: 'IRIS.DAT', Size: 1, VolumeDirectoryTotalSize: 1, DiskFree: 10 }], truncated: false, banner: '' };

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: string;
}

function mount(save: readonly JsonResult<unknown>[] = [{ kind: 'ok', status: 200, body: { name: 'OCUPROBE183A', file: {} } }], form: JsonResult<unknown> = { kind: 'ok', status: 200, body: FORM }) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const saves = [...save];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      calls.push({ path, method, body: init.body ?? '' });
      if (path.startsWith(DATABASE_FORM_PATH)) return form as JsonResult<T>;
      if (path.includes('/read?')) return { kind: 'ok', status: 200, body: VOLUMES } as unknown as JsonResult<T>;
      return (saves.shift() ?? { kind: 'ok', status: 200, body: { name: 'OCUPROBE183A' } }) as JsonResult<T>;
    },
  };
  const bus = new ChangeBus();
  const events: ChangeEvent[] = [];
  bus.subscribe((event) => events.push(event));
  const formDirty = new FormDirty();
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: bus },
      { provide: FormDirty, useValue: formDirty },
    ],
  });
  return { store: TestBed.inject(DatabaseEditor), calls, events, formDirty };
}

function writes(calls: readonly Call[]): Call[] {
  return calls.filter((call) => call.method !== 'GET');
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the local database editor store', () => {
  it('AC2, AD-5: opens over the fresh read of both groups, then reads the volume files with the database\u2019s directory', async () => {
    const { store, calls } = mount();
    await store.open('ocuprobe183a');
    expect(calls[0].path).toBe(`${DATABASE_FORM_PATH}?name=ocuprobe183a`);
    expect(calls[1].path).toBe(`/api/ocupilot/screens/osmgmt.databasevolumes/read?maxRows=200&dir=${encodeURIComponent(DIRECTORY)}`);
    expect([store.name(), store.directory(), store.newVolumeDirectory()]).toEqual(['OCUPROBE183A', DIRECTORY, DIRECTORY]);
    expect([store.text('MaxSize'), store.text('ResourceName'), store.flag('GlobalJournalState'), store.flag('MountRequired')]).toEqual(['0', '%DB_OCUPROBE183A', true, false]);
    expect(store.volumeRows()).toHaveLength(1);
    expect(store.canSave()).toBe(true);
  });

  it('AC2, AD-4: a Save puts only the changed groups, each with its changed fields, then publishes updated and re-reads', async () => {
    const { store, calls, events } = mount([
      { kind: 'ok', status: 200, body: { name: 'OCUPROBE183A', configuration: {}, file: {} } },
    ]);
    await store.open('OCUPROBE183A');
    store.setText('ExpansionSize', '10');
    store.setFlag('MountRequired', true);
    store.setText('NewVolumeThreshold', 'abc');
    expect(await store.save()).toBe(true);
    const [write] = writes(calls);
    expect(write.path).toBe(`${DATABASE_PATH}/OCUPROBE183A`);
    expect(write.method).toBe('PUT');
    expect(JSON.parse(write.body)).toEqual({ configuration: { MountRequired: true }, file: { ExpansionSize: 10, NewVolumeThreshold: 'abc' } });
    expect(events.map(({ type, id, action }) => ({ type, id, action }))).toEqual([{ type: 'database-configuration', id: 'OCUPROBE183A', action: 'updated' }]);
    expect(calls.filter((call) => call.path.startsWith(DATABASE_FORM_PATH))).toHaveLength(2);
    expect(store.saved()).toBe(true);
  });

  it('a Save that changed only the file sends no configuration group, and one that changed nothing writes nothing', async () => {
    const { store, calls } = mount();
    await store.open('OCUPROBE183A');
    expect(await store.save()).toBe(true);
    expect(writes(calls)).toEqual([]);
    store.setFlag('ReadOnly', true);
    expect(await store.save()).toBe(true);
    expect(JSON.parse(writes(calls)[0].body)).toEqual({ file: { ReadOnly: true } });
  });

  it('AD-21: a new volume directory is sent as the picker\u2019s root and path, and a path refusal lands on its field', async () => {
    const reason = 'Choose a subdirectory of the allowed directory, not the directory itself.';
    const { store, calls } = mount([
      {
        kind: 'error',
        status: 422,
        code: 'DATABASE.VALIDATION',
        reason: 'The database was refused.',
        detail: { violations: [{ field: 'volumePath', code: 'PATH.MANAGERDIR', reason }] },
      },
    ]);
    await store.open('OCUPROBE183A');
    store.setVolumeLocation('/durable/iris/mgr/', '');
    expect(store.changingVolumeDirectory()).toBe(false);
    store.changeVolumeDirectory();
    store.setVolumeLocation('/durable/iris/mgr/', '');
    expect(await store.save()).toBe(false);
    expect(JSON.parse(writes(calls)[0].body)).toEqual({ file: { volumeRoot: '/durable/iris/mgr/', volumePath: '' } });
    expect(store.violationFor('volumePath')).toBe(reason);
  });

  it('Cancel after Change sends no new volume directory: the preselected root is dropped and the form reads clean', async () => {
    const { store, calls, formDirty } = mount();
    await store.open('OCUPROBE183A');
    store.changeVolumeDirectory();
    store.setVolumeLocation('/durable/iris/mgr/', '');
    expect(formDirty.dirty()).toBe(true);
    store.keepVolumeDirectory();
    expect([store.changingVolumeDirectory(), store.volumeRoot(), store.volumePath(), formDirty.dirty()]).toEqual([false, '', '', false]);
    store.setText('ExpansionSize', '4');
    expect(await store.save()).toBe(true);
    expect(JSON.parse(writes(calls)[0].body)).toEqual({ file: { ExpansionSize: 4 } });
  });

  it('AD-58: a Save of both groups shows the read-back that does not hold what it sent', async () => {
    const { store } = mount([
      {
        kind: 'ok',
        status: 200,
        body: {
          name: 'OCUPROBE183A',
          configuration: { readBack: { verdict: 'differs', fields: ['MountRequired'], written: [] } },
          file: { readBack: { verdict: 'matches', fields: [], written: [] } },
        },
      },
    ]);
    await store.open('OCUPROBE183A');
    store.setFlag('MountRequired', true);
    store.setText('ExpansionSize', '4');
    expect(await store.save()).toBe(true);
    expect(store.readBack()?.verdict).toBe('differs');
  });

  it('a refusal after the mounting group applied keeps it from being sent again, and publishes the change it made', async () => {
    const reason = 'No resource on this instance has that name.';
    const { store, calls, events } = mount([
      {
        kind: 'error',
        status: 422,
        code: 'DATABASE.VALIDATION',
        reason: 'The database was refused.',
        detail: { violations: [{ field: 'ResourceName', code: 'DATABASE.RESOURCE.ABSENT', reason }], applied: ['configuration'] },
      },
    ]);
    await store.open('OCUPROBE183A');
    store.setFlag('MountAtStartup', true);
    store.setText('ResourceName', '%DB_USER');
    expect(await store.save()).toBe(false);
    expect([store.refusalCode(), store.violationFor('ResourceName')]).toEqual(['DATABASE.VALIDATION', reason]);
    expect(events.map(({ action }) => action)).toEqual(['updated']);
    await store.save();
    expect(JSON.parse(writes(calls)[1].body)).toEqual({ file: { ResourceName: '%DB_USER' } });
  });

  it('an edit of a database the instance does not hold blocks Save', async () => {
    const { store } = mount([], {
      kind: 'error',
      status: 404,
      code: 'DATABASE.NAME.ABSENT',
      reason: 'This instance has no database with that name.',
      detail: null,
    });
    await store.open('NOSUCHDB');
    expect(store.absent()).toBe(true);
    expect(store.canSave()).toBe(false);
    expect(store.reason()).toBe('This instance has no database with that name.');
  });

  it('Story 18.4: the size is its own group, and a grow refused after the file group applied does not send the file group again', async () => {
    // Mutation (Rule 19): keep `absorbApplied` to the configuration group alone -> the second Save
    // sends the file group again and this goes red.
    const reason = 'Enter a whole number of megabytes larger than the current size and no larger than the maximum size.';
    const { store, calls, events } = mount(
      [
        {
          kind: 'error',
          status: 422,
          code: 'DATABASE.VALIDATION',
          reason: 'The database was refused.',
          detail: { violations: [{ field: 'Size', code: 'DATABASE.GROWSIZE.SHAPE', reason }], applied: ['file'] },
        },
      ],
      { kind: 'ok', status: 200, body: { ...FORM, size: { Size: 5 } } }
    );
    await store.open('OCUPROBE183A');
    expect(store.sizeHeld()).toBe(true);
    expect(store.text('Size')).toBe('5');
    store.setText('Size', '4');
    store.setText('ExpansionSize', '8');
    expect(await store.save()).toBe(false);
    expect(JSON.parse(writes(calls)[0].body)).toEqual({ file: { ExpansionSize: 8 }, size: { Size: 4 } });
    expect(store.violationFor('Size')).toBe(reason);
    expect(events.map(({ action }) => action)).toEqual(['updated']);
    store.setText('Size', '9');
    await store.save();
    expect(JSON.parse(writes(calls)[1].body)).toEqual({ size: { Size: 9 } });
  });
});

import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { JOURNAL_SETTINGS_PATH, JournalSettingsForm } from './journal-settings.store';

/**
 * Journal settings' store (Story 18.18, AD-4, AD-14, AD-36, AD-39, AD-55): the screen's own declared
 * read, a Save sending only the changed fields and a directory's two arguments only while it is
 * changed, the purge rule as the form draws it, and violations on their fields. The bus is real and
 * only the server's answers are stubbed.
 */

const DIRECTORY = '/durable/iris/mgr/journal/';

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

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: string;
}

function mount(row: Record<string, unknown> = ROW, save: JsonResult<unknown> = { kind: 'ok', status: 200, body: { readBack: { verdict: 'matches', fields: [], written: [] } } }) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      calls.push({ path, method, body: init.body ?? '' });
      if (path.includes('/read?')) return { kind: 'ok', status: 200, body: { rows: [row], truncated: false, banner: '' } } as unknown as JsonResult<T>;
      return save as JsonResult<T>;
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
  return { store: TestBed.inject(JournalSettingsForm), calls, events, formDirty };
}

function writes(calls: readonly Call[]): Call[] {
  return calls.filter((call) => call.method !== 'GET');
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the journal settings store', () => {
  it('AC1, AD-36: opens over the screen\u2019s own declared read, every field held', async () => {
    const { store, calls } = mount();
    await store.open();
    expect(calls[0].path).toBe('/api/ocupilot/screens/osmgmt.journalsettings/read?maxRows=1');
    expect([store.directory('primary'), store.directory('alternate'), store.text('FileSizeLimit'), store.text('DaysBeforePurge')]).toEqual([DIRECTORY, DIRECTORY, '1024', '2']);
    expect([store.flag('CompressFiles'), store.flag('FreezeOnError'), store.shown('ArchiveName'), store.shown('targwijsz')]).toEqual([true, false, '', '0']);
    expect(store.editable()).toBe(true);
  });

  it('AC2, AD-4: Save sends the changed fields alone, as numbers where they read as one, and publishes the update', async () => {
    const { store, calls, events, formDirty } = mount();
    await store.open();
    store.setText('FileSizeLimit', '1000');
    store.setFlag('FreezeOnError', true);
    expect(formDirty.dirty()).toBe(true);
    expect(await store.save()).toBe(true);
    const write = writes(calls)[0];
    expect([write.method, write.path]).toEqual(['PUT', JOURNAL_SETTINGS_PATH]);
    expect(JSON.parse(write.body)).toEqual({ FileSizeLimit: 1000, FreezeOnError: true });
    expect(events.map((event) => `${event.type}|${event.scope}|${event.id}|${event.action}`)).toEqual(['journal-settings|instance|SYSTEM|updated']);
    expect(store.saved()).toBe(true);
    expect(store.readBack()?.verdict).toBe('matches');
    expect(formDirty.dirty()).toBe(false);
  });

  it('AD-21: a directory\u2019s root and name are sent only while it is changed, and a preselected root is not a change', async () => {
    const { store, calls, formDirty } = mount();
    await store.open();
    store.setDirectoryLocation('alternate', '/durable/iris/mgr/', 'x', false);
    expect(store.root('alternate')).toBe('');
    store.changeDirectory('alternate');
    store.setDirectoryLocation('alternate', '/durable/iris/mgr/', '', true);
    expect(formDirty.dirty()).toBe(false);
    store.setDirectoryLocation('alternate', '/durable/iris/mgr/', 'journal2', false);
    expect(formDirty.dirty()).toBe(true);
    await store.save();
    expect(JSON.parse(writes(calls)[0].body)).toEqual({ alternateRoot: '/durable/iris/mgr/', alternatePath: 'journal2' });
  });

  it('AD-21: a name typed before any root is chosen is sent, so the Save refuses it on the root rather than reading saved', async () => {
    const { store, calls } = mount();
    await store.open();
    store.changeDirectory('primary');
    store.setDirectoryLocation('primary', '', 'journal2', false);
    await store.save();
    expect(JSON.parse(writes(calls)[0]?.body ?? '{}')).toEqual({ primaryRoot: '', primaryPath: 'journal2' });
  });

  it('AD-58: a Save that sends nothing after an accepted one shows no read-back of the earlier write', async () => {
    const { store, calls } = mount();
    await store.open();
    store.setText('FileSizeLimit', '1000');
    await store.save();
    expect(store.readBack()?.verdict).toBe('matches');
    expect(await store.save()).toBe(true);
    expect([writes(calls).length, store.saved(), store.readBack()]).toEqual([1, true, null]);
  });

  it('Cancel beside a picker sends nothing for that directory, and the form is clean again', async () => {
    const { store, calls, formDirty } = mount();
    await store.open();
    store.changeDirectory('primary');
    store.setDirectoryLocation('primary', '/durable/iris/mgr/', 'journal2', false);
    store.keepDirectory('primary');
    expect([store.changing('primary'), store.root('primary'), formDirty.dirty()]).toEqual([false, '', false]);
    await store.save();
    expect(writes(calls)).toEqual([]);
  });

  it('the purge rule as drawn: no archive target leaves Purge archived unchecked and taking no input, and while it is checked the counts take none', async () => {
    const { store } = mount({ ...ROW, PurgeArchived: true });
    await store.open();
    expect([store.flag('PurgeArchived'), store.purgeArchivedEditable()]).toEqual([false, false]);
    store.setFlag('PurgeArchived', true);
    expect(store.flag('PurgeArchived')).toBe(false);
    const archived = mount({ ...ROW, ArchiveName: 'ARCHIVE1', PurgeArchived: true });
    await archived.store.open();
    expect([archived.store.flag('PurgeArchived'), archived.store.purgeArchivedEditable(), archived.store.purgeCountsEditable()]).toEqual([true, true, false]);
    archived.store.setText('DaysBeforePurge', '5');
    expect(archived.store.text('DaysBeforePurge')).toBe('2');
    archived.store.setFlag('PurgeArchived', false);
    archived.store.setText('DaysBeforePurge', '5');
    expect(archived.store.text('DaysBeforePurge')).toBe('5');
  });

  it('AD-39: a refused Save lands each violation on its field, and nothing is published', async () => {
    const { store, events } = mount(ROW, {
      kind: 'error',
      status: 422,
      code: 'JOURNAL.VALIDATION',
      reason: 'The journal settings were refused.',
      detail: { violations: [{ field: 'FileSizeLimit', code: 'JOURNAL.FILESIZE.SHAPE', reason: 'Enter a whole number of megabytes from 0 to 4079.' }] },
    });
    await store.open();
    store.setText('FileSizeLimit', '5000');
    expect(await store.save()).toBe(false);
    expect(store.violationFor('FileSizeLimit')).toBe('Enter a whole number of megabytes from 0 to 4079.');
    expect(store.reason()).toBe('');
    expect(events).toEqual([]);
    store.setText('FileSizeLimit', '4000');
    expect(store.violationFor('FileSizeLimit')).toBe('');
  });

  it('a read that answers no settings offers Retry and takes no input', async () => {
    const { store } = mount(null as unknown as Record<string, unknown>);
    await store.open();
    expect([store.loaded(), store.fault(), store.editable(), store.canSave()]).toEqual([true, true, false, false]);
  });
});

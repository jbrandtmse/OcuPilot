import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { entityRefKey } from '../../core/entity-ref';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { SCREENS } from '../../core/screens.generated';
import {
  NAME_TAKEN_CODE,
  RESOURCES_FORM_PATH,
  RESOURCES_NAME_PATH,
  RESOURCES_PATH,
  ResourceEditor,
  admittedLetters,
} from './resource-editor.store';

/**
 * The resource editor's store (AD-4, AD-14, AD-39, AD-55).
 *
 * It pins what no browser leg can falsify: the change event a Save publishes, a create turning into
 * an edit of the new resource, an edit sending only the fields it changed, the server's letter rule
 * applied as data, the dirty flag, and a server refusal landing on the field it names. The bus is
 * real and only the server's answers are stubbed.
 */

/** What `GET /resources/form` answers, narrowed to what these tests read. */
const RULES = {
  requiredFields: ['Name'],
  maxLengths: { Name: 64, Description: 256 },
  rules: [{ field: 'Name', code: 'RESOURCE.NAME.REQUIRED', reason: 'Give the resource a name.' }],
  letterRules: {
    letters: 'RWU',
    prefixes: [
      { prefix: '%DB_', letters: 'RW' },
      { prefix: '%Admin_', letters: 'U' },
    ],
  },
};

const EDITED = { name: 'ProbeResource', Description: 'old', PublicPermission: 'W', privileged: false };

const TAKEN_SENTENCE = 'This instance already has a resource with that name. Choose a different one.';

async function settle(): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
}

function mount(
  saveAnswer: JsonResult<unknown> = { kind: 'ok', status: 201, body: { name: 'ProbeResource' } },
  nameAnswer: JsonResult<unknown> = { kind: 'ok', status: 200, body: { name: 'ProbeResource', taken: false, reason: '', privileged: false } }
) {
  TestBed.resetTestingModule();
  const calls: { path: string; method: string; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      if (path === RESOURCES_FORM_PATH) return { kind: 'ok', status: 200, body: RULES } as unknown as JsonResult<T>;
      if (path.startsWith(`${RESOURCES_FORM_PATH}?`)) {
        return { kind: 'ok', status: 200, body: { ...RULES, resource: EDITED } } as unknown as JsonResult<T>;
      }
      if (path.startsWith(RESOURCES_NAME_PATH)) return nameAnswer as JsonResult<T>;
      return saveAnswer as JsonResult<T>;
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
  return { store: TestBed.inject(ResourceEditor), calls, events, formDirty };
}

function lastWrite(calls: { path: string; method: string; body: string }[]) {
  const write = calls.filter((call) => call.method !== 'GET').at(-1);
  expect(write).toBeDefined();
  return { path: write!.path, method: write!.method, body: JSON.parse(write!.body) as Record<string, unknown> };
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the resource editor store', () => {
  it('AC4, AD-14: a create publishes one created event, and the editor becomes an edit of the new resource', async () => {
    const { store, calls, events, formDirty } = mount();
    await store.openCreate();
    store.setName('ProbeResource');
    store.setDescription('probe');
    store.setLetter('U', true);
    store.setLetter('R', true);
    expect(formDirty.dirty()).toBe(true);
    expect(await store.save()).toBe(true);
    await settle();

    expect(lastWrite(calls)).toEqual({
      path: RESOURCES_PATH,
      method: 'POST',
      body: { Name: 'ProbeResource', Description: 'probe', PublicPermission: 'RU' },
    });
    // Mutation (Rule 19): drop the `publish` call from `save()` -> this goes red, and an open
    // Resources list never re-fetches the resource the editor just created.
    expect(events).toEqual([
      {
        kind: 'changed',
        type: 'resource',
        scope: 'instance',
        id: 'ProbeResource',
        key: entityRefKey('resource', 'instance', 'ProbeResource'),
        action: 'created',
        proposalId: '',
        expiresAt: 0,
      },
    ]);
    // The type is the Resources list's own declared entity type, which is what that list listens for.
    expect(SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.ResourceList')?.entityType).toBe('resource');
    expect(store.mode()).toBe('edit');
    expect(store.editedName()).toBe('ProbeResource');
    expect(store.saved()).toBe(true);
    expect(formDirty.dirty()).toBe(false);
    // Mutation (Rule 19): stop recording the created id in `save()` -> the page has no route to
    // replace to, and this goes red.
    expect(store.takeCreatedId()).toBe('ProbeResource');
    expect(store.takeCreatedId()).toBe('');
  });

  it('AC3, AD-4: an edit sends only the field it changed, so a field changed elsewhere is kept, and publishes updated', async () => {
    const { store, calls, events } = mount({ kind: 'ok', status: 200, body: { name: 'ProbeResource' } });
    await store.openEdit('ProbeResource');
    expect(store.description()).toBe('old');
    expect(store.letters()).toBe('W');
    store.setDescription('new');
    expect(await store.save()).toBe(true);
    await settle();
    // Mutation (Rule 19): send every field from `changedFields()` -> the body carries
    // PublicPermission and this goes red.
    expect(lastWrite(calls)).toEqual({
      path: `${RESOURCES_PATH}/${encodeEntityId('ProbeResource')}`,
      method: 'PUT',
      body: { Description: 'new' },
    });
    expect(events.map((event) => event.action)).toEqual(['updated']);
    expect(store.mode()).toBe('edit');
  });

  it('Story 16.17: an edit keeps the instance\u2019s read-back for its Saved line and carries it on the change', async () => {
    // Mutation (Rule 19): drop `readBack` from the change `save()` publishes -> this goes red, and
    // the marked row under the dialog says nothing about what the instance now holds (AD-58).
    const readBack = { verdict: 'differs', fields: ['PublicPermission'], written: [] };
    const { store, events } = mount({ kind: 'ok', status: 200, body: { name: 'ProbeResource', readBack } });
    await store.openEdit('ProbeResource');
    store.setDescription('new');
    expect(await store.save()).toBe(true);
    await settle();
    expect(store.readBack()).toEqual({ ...readBack, reason: '' });
    expect(events).toHaveLength(1);
    expect(events[0].readBack).toEqual({ ...readBack, reason: '' });
  });

  it('applies the server letter rule to the name on screen, and a rename drops a letter the new name refuses', async () => {
    const { store } = mount();
    await store.openCreate();
    store.setName('Plain');
    expect(store.admitted()).toBe('RWU');
    store.setLetter('U', true);
    store.setName('%db_probe');
    expect(store.admitted()).toBe('RW');
    expect(store.letters()).toBe('');
    expect(admittedLetters({ letters: 'RWU', prefixes: [{ prefix: '%Admin_', letters: 'U' }] }, '%ADMIN_probe')).toBe('U');
  });

  it('AC6: the consequence is stated while a letter is checked on a name the server marked privileged', async () => {
    const { store } = mount(undefined, { kind: 'ok', status: 200, body: { name: '%Admin_Probe', taken: false, reason: '', privileged: true } });
    await store.openCreate();
    store.setName('%Admin_Probe');
    await store.onNameBlur();
    expect(store.privileged()).toBe(true);
    expect(store.showsPrivilegedEffect()).toBe(false);
    store.setLetter('U', true);
    expect(store.showsPrivilegedEffect()).toBe(true);
  });

  it('AC6: no consequence is stated on a name the server did not mark privileged, a letter checked', async () => {
    const { store } = mount();
    await store.openCreate();
    store.setName('ProbeResource');
    await store.onNameBlur();
    store.setLetter('R', true);
    // Mutation (Rule 19): `showsPrivilegedEffect()` answers `letters !== ''` alone -> this goes red.
    expect(store.privileged()).toBe(false);
    expect(store.showsPrivilegedEffect()).toBe(false);
  });

  it('AC5: a Save the vendor did not apply reports the refusal, never saved, and publishes nothing', async () => {
    const notApplied = {
      kind: 'error',
      status: 500,
      code: 'PORT.NOTAPPLIED',
      reason: 'The instance answered the change as made, but it was not.',
      detail: null,
    } as unknown as JsonResult<unknown>;
    const { store, events, formDirty } = mount(notApplied);
    await store.openEdit('ProbeResource');
    store.setDescription('new');
    expect(await store.save()).toBe(false);
    await settle();
    expect(store.saved()).toBe(false);
    expect(store.reason()).toBe('The instance answered the change as made, but it was not.');
    expect(events).toEqual([]);
    expect(formDirty.dirty()).toBe(true);
  });

  it('AD-39: a taken name is marked on blur, and a server refusal lands on the field it names', async () => {
    const refusal: JsonResult<unknown> = {
      kind: 'error',
      status: 422,
      code: 'RESOURCE.VALIDATION',
      reason: 'The resource was refused.',
      detail: { violations: [{ field: 'Description', code: 'RESOURCE.DESCRIPTION.LENGTH', reason: 'A resource description is at most 256 characters.' }] },
    } as unknown as JsonResult<unknown>;
    const { store } = mount(refusal, { kind: 'ok', status: 200, body: { name: 'ProbeResource', taken: true, reason: TAKEN_SENTENCE, privileged: false } });
    await store.openCreate();
    store.setName('ProbeResource');
    await store.onNameBlur();
    expect(store.violations()).toEqual([{ field: 'Name', code: NAME_TAKEN_CODE, reason: TAKEN_SENTENCE }]);
    expect(await store.save()).toBe(false);
    expect(store.violationFor('Description')).toBe('A resource description is at most 256 characters.');
    expect(store.mode()).toBe('create');
    store.setDescription('short');
    expect(store.violationFor('Description')).toBe('');
  });

  it('AC7: a close with a held change asks first, and staying keeps the edits', async () => {
    const { store, formDirty } = mount();
    await store.openCreate();
    store.setName('ProbeResource');
    const first = store.requestClose();
    expect(formDirty.pending()).toBe(true);
    formDirty.answer(false);
    expect(await first).toBe(false);
    expect(store.mode()).toBe('create');
    expect(store.name()).toBe('ProbeResource');
    const second = store.requestClose();
    formDirty.answer(true);
    expect(await second).toBe(true);
    expect(store.mode()).toBe('closed');
  });

  it('an edit whose read failed takes no input and sends nothing, so a held permission is never overwritten blind', async () => {
    TestBed.resetTestingModule();
    const calls: string[] = [];
    const api = {
      requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
        calls.push(`${init.method ?? 'GET'} ${path}`);
        return { kind: 'error', status: 503, code: 'PORT.UNAVAILABLE', reason: 'The instance did not answer.', detail: null } as JsonResult<T>;
      },
    };
    TestBed.configureTestingModule({
      providers: [
        { provide: ApiService, useValue: api as unknown as ApiService },
        { provide: FormDirty, useValue: new FormDirty() },
      ],
    });
    const store = TestBed.inject(ResourceEditor);
    await store.openEdit('ProbeResource');
    // Mutation (Rule 19): make `canSave()` ignore the held read -> this goes red.
    expect(store.canSave()).toBe(false);
    store.setLetter('R', true);
    store.setDescription('typed');
    expect(store.letters()).toBe('');
    expect(await store.save()).toBe(false);
    expect(calls.filter((call) => !call.startsWith('GET'))).toEqual([]);
  });

  it('an edit saved with nothing changed writes nothing and publishes nothing', async () => {
    const { store, calls, events } = mount({ kind: 'ok', status: 200, body: { name: 'ProbeResource' } });
    await store.openEdit('ProbeResource');
    // Mutation (Rule 19): drop the unchanged-edit early return from `save()` -> a PUT {} is sent.
    expect(await store.save()).toBe(true);
    expect(calls.filter((call) => call.method !== 'GET')).toEqual([]);
    expect(events).toEqual([]);
    expect(store.saved()).toBe(true);
  });

  it('AD-39: an empty name shows the server required-name sentence on blur', async () => {
    const { store, calls } = mount();
    await store.openCreate();
    store.setName('x');
    store.setName('');
    await store.onNameBlur();
    // Mutation (Rule 19): drop `markEmptyName()` from `onNameBlur()` -> this goes red.
    expect(store.violationFor('Name')).toBe('Give the resource a name.');
    expect(calls.some((call) => call.path.startsWith(RESOURCES_NAME_PATH))).toBe(false);
  });

  it('an edit of a resource the instance does not hold blocks its Save', async () => {
    TestBed.resetTestingModule();
    const api = {
      requestJson: async <T,>(): Promise<JsonResult<T>> =>
        ({ kind: 'error', status: 404, code: 'RESOURCE.NAME.ABSENT', reason: 'This instance has no resource with that name.', detail: null }) as JsonResult<T>,
    };
    TestBed.configureTestingModule({
      providers: [
        { provide: ApiService, useValue: api as unknown as ApiService },
        { provide: FormDirty, useValue: new FormDirty() },
      ],
    });
    const store = TestBed.inject(ResourceEditor);
    await store.openEdit('Gone');
    expect(store.absent()).toBe(true);
    expect(store.reason()).toBe('This instance has no resource with that name.');
    expect(await store.save()).toBe(false);
  });
});

import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { DEVICE_FORM_PATH, DEVICE_NAME_PATH, DEVICE_PATH, DeviceForm, NAME_TAKEN_CODE, wireValue } from './device-form.store';

/**
 * The device editor's store (AC2, AD-4, AD-14, AD-39, AD-55).
 *
 * It pins what no browser leg can falsify: the change event a Save publishes, the create's one body
 * with the alias and prompt as integers, the classic page's defaults on a create, an edit sending
 * only the fields it changed after its fresh read, and a server refusal landing on the field it
 * names. The bus is real and only the server's answers are stubbed.
 */

const RULES = {
  requiredFields: ['Name', 'PhysicalDevice', 'Type', 'SubType'],
  maxLengths: { Name: 64, PhysicalDevice: 128 },
  rules: [
    { field: 'Name', code: 'DEVICE.NAME.REQUIRED', reason: 'Give the device a name.' },
    { field: 'PhysicalDevice', code: 'DEVICE.PHYSICALDEVICE.REQUIRED', reason: 'Give the physical device name.' },
  ],
  typeValues: ['TRM', 'SPL', 'MT', 'BT', 'IPC', 'OTH'],
  subTypes: ['C-VT220', 'P-DEC'],
};

const DEVICE = {
  Name: 'ProbeDevice',
  PhysicalDevice: '/tmp/probe.txt',
  Type: 'OTH',
  SubType: 'P-DEC',
  OpenParameters: '',
  Description: 'before',
  Alias: 9955,
  AlternateDevice: '',
  Prompt: 2,
};

const TAKEN_SENTENCE = 'This instance already has a device with that name. Choose a different one.';

async function settle(): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
}

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: string;
}

function mount(saveAnswer: JsonResult<unknown> = { kind: 'ok', status: 201, body: { name: 'ProbeDevice' } }) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      if (path === DEVICE_FORM_PATH) return { kind: 'ok', status: 200, body: RULES } as unknown as JsonResult<T>;
      if (path.startsWith(`${DEVICE_FORM_PATH}?`)) {
        return { kind: 'ok', status: 200, body: { ...RULES, device: DEVICE } } as unknown as JsonResult<T>;
      }
      if (path.startsWith(DEVICE_NAME_PATH)) {
        return { kind: 'ok', status: 200, body: { taken: true, reason: TAKEN_SENTENCE } } as unknown as JsonResult<T>;
      }
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
  return { store: TestBed.inject(DeviceForm), calls, events, formDirty };
}

/** The five fields a change event carries about the write, the bus's own bookkeeping aside. */
function shape(event: ChangeEvent): Record<string, unknown> {
  const { kind, type, scope, id, action } = event as unknown as Record<string, unknown>;
  return { kind, type, scope, id, action };
}

function writes(calls: readonly Call[]): Call[] {
  return calls.filter((call) => call.method !== 'GET');
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the device editor store', () => {
  it('a create starts at the classic page defaults: type OTH, subtype P-DEC, the device prompt shown', async () => {
    const { store } = mount();
    await store.open('');
    expect(store.mode()).toBe('create');
    expect([store.value('Type'), store.value('SubType'), store.value('Prompt')]).toEqual(['OTH', 'P-DEC', '']);
    expect(store.typeValues()).toEqual(['TRM', 'SPL', 'MT', 'BT', 'IPC', 'OTH']);
    expect(store.canSave()).toBe(true);
  });

  it('AC2, AD-14: a create posts one body with the alias and prompt as integers and publishes one created event', async () => {
    const { store, calls, events, formDirty } = mount();
    await store.open('');
    store.setValue('Name', 'ProbeDevice');
    store.setValue('PhysicalDevice', '/tmp/probe.txt');
    store.setValue('Description', 'probe');
    store.setValue('Alias', '9988');
    store.setValue('Prompt', '1');
    expect(formDirty.dirty()).toBe(true);
    expect(await store.save()).toBe(true);
    await settle();

    const [write] = writes(calls);
    expect(write?.path).toBe(DEVICE_PATH);
    expect(write?.method).toBe('POST');
    expect(JSON.parse(write?.body ?? '{}')).toEqual({
      Name: 'ProbeDevice',
      PhysicalDevice: '/tmp/probe.txt',
      Type: 'OTH',
      SubType: 'P-DEC',
      OpenParameters: '',
      Description: 'probe',
      Alias: 9988,
      AlternateDevice: '',
      Prompt: 1,
    });
    // Mutation (Rule 19): drop `this.publish(...)` from `save()` -> no event and this goes red.
    expect(events.map(shape)).toEqual([{ kind: 'changed', type: 'device', scope: 'instance', id: 'ProbeDevice', action: 'created' }]);
    expect(store.createdId()).toBe('ProbeDevice');
    expect(store.saved()).toBe(true);
    expect(formDirty.dirty()).toBe(false);
  });

  it('AD-4: an edit opens over the fresh read and puts only the fields it changed, then publishes updated', async () => {
    const { store, calls, events } = mount({ kind: 'ok', status: 200, body: { name: 'ProbeDevice' } });
    await store.open('ProbeDevice');
    expect(store.mode()).toBe('edit');
    expect(store.value('Alias')).toBe('9955');
    expect(store.value('Prompt')).toBe('2');
    store.setValue('Name', 'Renamed');
    expect(store.value('Name')).toBe('ProbeDevice');
    store.setValue('Description', 'after');
    store.setValue('Alias', '');
    expect(await store.save()).toBe(true);
    const [write] = writes(calls);
    expect(write?.path).toBe(`${DEVICE_PATH}/${encodeEntityId('ProbeDevice')}`);
    expect(write?.method).toBe('PUT');
    expect(JSON.parse(write?.body ?? '{}')).toEqual({ Description: 'after', Alias: '' });
    expect(events.map(shape)).toEqual([{ kind: 'changed', type: 'device', scope: 'instance', id: 'ProbeDevice', action: 'updated' }]);
  });

  it('AD-4: an edit that changed nothing writes nothing', async () => {
    const { store, calls, events } = mount();
    await store.open('ProbeDevice');
    store.setValue('Description', 'changed');
    store.setValue('Description', 'before');
    expect(await store.save()).toBe(true);
    expect(writes(calls)).toEqual([]);
    expect(events).toEqual([]);
  });

  it('AD-39: a refused Save lands each violation on its field and keeps what was entered', async () => {
    const { store, events } = mount({
      kind: 'error',
      status: 422,
      code: 'DEVICE.VALIDATION',
      reason: 'The device was refused.',
      detail: { violations: [{ field: 'Description', code: 'DEVICE.DESCRIPTION.SHAPE', reason: 'A description has no ^ and no control character.' }] },
    } as unknown as JsonResult<unknown>);
    await store.open('');
    store.setValue('Name', 'ProbeDevice');
    store.setValue('PhysicalDevice', '/tmp/probe.txt');
    store.setValue('Description', 'a^b');
    expect(await store.save()).toBe(false);
    expect(store.violationFor('Description')).toBe('A description has no ^ and no control character.');
    expect(store.value('Description')).toBe('a^b');
    expect(events).toEqual([]);
  });

  it('a name the instance holds is marked taken on blur, with the server sentence', async () => {
    const { store } = mount();
    await store.open('');
    store.setValue('Name', 'ProbeDevice');
    await store.onBlur('Name');
    expect(store.violations()).toEqual([{ field: 'Name', code: NAME_TAKEN_CODE, reason: TAKEN_SENTENCE }]);
  });

  it('a create lands on the new device\'s edit with the saved confirmation', async () => {
    const { store } = mount();
    await store.open('');
    store.setValue('Name', 'ProbeDevice');
    store.setValue('PhysicalDevice', '/tmp/probe.txt');
    expect(await store.save()).toBe(true);
    store.retainAcrossRouteReplacement();
    await store.open(store.createdId());
    // Mutation (Rule 19): drop `if (arriving) this.savedValue = true` from `open()` -> `saved()` reads
    // false and this goes red.
    expect([store.mode(), store.saved(), store.retaining(), store.value('Name')]).toEqual(['edit', true, false, 'ProbeDevice']);
  });

  it('value shapes: the alias and prompt travel as integers or an empty string, other fields as typed', () => {
    expect(wireValue('Alias', '210')).toBe(210);
    expect(wireValue('Alias', '')).toBe('');
    expect(wireValue('Alias', '1.5')).toBe('1.5');
    // Mutation (Rule 19): admit a leading zero in `wireValue`'s pattern -> '007' travels as 7 and this goes red.
    expect(wireValue('Alias', '007')).toBe('007');
    expect(wireValue('Prompt', '2')).toBe(2);
    expect(wireValue('Description', '12')).toBe('12');
  });
});

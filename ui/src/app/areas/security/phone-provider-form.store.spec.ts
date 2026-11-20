import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { PHONE_PROVIDER_FORM_PATH, PHONE_PROVIDER_PATH, PhoneProviderForm } from './phone-provider-form.store';

/**
 * The mobile phone provider editor's store (Story 21.10, AD-4, AD-14, AD-39, AD-55): the form read, a create sending the two fields, an
 * edit sending the changed gateway alone and never the name, and violations on their fields. The bus is real and only the server's
 * answers are stubbed.
 */

const PROBE = 'OcuPhoneProbeA';

function row(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return { Name: PROBE, SMSGateway: 'sms.ocuphoneprobe.invalid', ...overrides };
}

const EMPTY_ROW = { Name: '', SMSGateway: '' };

const ACCEPTED: JsonResult<unknown> = { kind: 'ok', status: 200, body: { id: PROBE, readBack: { verdict: 'matches', fields: [], written: [] } } };

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: string;
}

function mount(options: { form?: Record<string, unknown>; formResult?: JsonResult<unknown>; save?: JsonResult<unknown> } = {}) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      calls.push({ path, method, body: init.body ?? '' });
      if (path.startsWith(PHONE_PROVIDER_FORM_PATH)) return (options.formResult ?? { kind: 'ok', status: 200, body: { row: options.form ?? row() } }) as JsonResult<T>;
      return (options.save ?? ACCEPTED) as JsonResult<T>;
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
  return { store: TestBed.inject(PhoneProviderForm), calls, events, formDirty };
}

function writes(calls: readonly Call[]): Call[] {
  return calls.filter((call) => call.method !== 'GET');
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the mobile phone provider store', () => {
  it('B1: a create opens over the form read with both fields empty and editable', async () => {
    const { store, calls } = mount({ form: EMPTY_ROW });
    await store.open('');
    expect(calls.map((call) => call.path)).toEqual([PHONE_PROVIDER_FORM_PATH]);
    expect([store.mode(), store.editable(), store.value('Name'), store.value('SMSGateway')]).toEqual(['create', true, '', '']);
  });

  it('B1: an edit holds the row, and the name takes no input', async () => {
    const { store, calls } = mount();
    await store.open(PROBE);
    expect(calls.some((call) => call.path === `${PHONE_PROVIDER_FORM_PATH}?id=${encodeURIComponent(PROBE)}`)).toBe(true);
    expect([store.mode(), store.id(), store.value('SMSGateway')]).toEqual(['edit', PROBE, 'sms.ocuphoneprobe.invalid']);
    store.setValue('Name', 'Other');
    expect(store.value('Name')).toBe(PROBE);
  });

  it('B2, AD-4: an edit sends the changed gateway alone and publishes the update naming its tool', async () => {
    const { store, calls, events, formDirty } = mount();
    await store.open(PROBE);
    store.setValue('SMSGateway', 'moved.ocuphoneprobe.invalid');
    expect(formDirty.dirty()).toBe(true);
    expect(await store.save()).toBe(true);
    const write = writes(calls)[0];
    expect([write.method, write.path]).toEqual(['PUT', `${PHONE_PROVIDER_PATH}/${encodeEntityId(PROBE)}`]);
    expect(JSON.parse(write.body)).toEqual({ SMSGateway: 'moved.ocuphoneprobe.invalid' });
    expect(events.map((event) => `${event.type}|${event.scope}|${event.id}|${event.action}|${event.tool}`)).toEqual([`phone-provider|instance|${PROBE}|updated|security.phoneproviders.update`]);
    expect([store.saved(), formDirty.dirty()]).toEqual([true, false]);
  });

  it('B2: a create posts the two fields exactly as typed and publishes the creation', async () => {
    const { store, calls, events } = mount({ form: EMPTY_ROW });
    await store.open('');
    store.setValue('Name', PROBE);
    store.setValue('SMSGateway', 'sms.ocuphoneprobe.invalid');
    expect(await store.save()).toBe(true);
    const write = writes(calls)[0];
    expect([write.method, write.path]).toEqual(['POST', PHONE_PROVIDER_PATH]);
    expect(JSON.parse(write.body)).toEqual({ Name: PROBE, SMSGateway: 'sms.ocuphoneprobe.invalid' });
    expect(events.map((event) => `${event.id}|${event.action}|${event.tool}`)).toEqual([`${PROBE}|created|security.phoneproviders.create`]);
    expect(store.createdId()).toBe(PROBE);
  });

  it('AD-39: a refused Save puts the violations of the server on their fields and keeps what was entered; editing the field drops its violation', async () => {
    const refused: JsonResult<unknown> = {
      kind: 'error',
      status: 422,
      code: 'PHONEPROVIDER.VALIDATION',
      reason: 'The provider was refused.',
      detail: { violations: [{ field: 'Name', code: 'PHONEPROVIDER.TAKEN', reason: 'A mobile phone provider with that name already exists.' }] },
    };
    const { store, events } = mount({ form: EMPTY_ROW, save: refused });
    await store.open('');
    store.setValue('Name', PROBE);
    expect(await store.save()).toBe(false);
    expect([store.violationFor('Name'), store.value('Name'), events.length, store.saved()]).toEqual(['A mobile phone provider with that name already exists.', PROBE, 0, false]);
    store.setValue('Name', 'OcuPhoneProbeB');
    expect(store.violationFor('Name')).toBe('');
  });

  it('AD-4: an edit that changed nothing writes nothing, and a provider the instance does not hold blocks Save', async () => {
    const { store, calls } = mount();
    await store.open(PROBE);
    expect(await store.save()).toBe(true);
    expect(writes(calls)).toEqual([]);
    const absent = mount({ formResult: { kind: 'error', status: 404, code: 'PORT.NOTFOUND', reason: 'That item is no longer present on this instance', detail: null } });
    await absent.store.open(PROBE);
    expect([absent.store.absent(), absent.store.canSave()]).toEqual([true, false]);
  });

  it('B2: a privilege denial keeps its code and the pair it names', async () => {
    const denied: JsonResult<unknown> = { kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'denied', detail: { failedPair: '%Admin_Secure:USE' } };
    const { store } = mount({ save: denied });
    await store.open(PROBE);
    store.setValue('SMSGateway', 'other.ocuphoneprobe.invalid');
    expect(await store.save()).toBe(false);
    expect([store.refusalCode(), store.refusalPair()]).toEqual(['AUTH.NOPRIVILEGE', '%Admin_Secure:USE']);
  });
});

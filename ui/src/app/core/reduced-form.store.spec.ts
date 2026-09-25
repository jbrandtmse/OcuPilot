import { describe, expect, it } from 'vitest';

import { LDAP_FORM } from '../areas/security/ldap-form';
import { SERVICE_FORM } from '../areas/permissions/service-form';
import type { ApiRequestInit, JsonResult } from './api';
import type { ChangeEventInput } from './change-bus';
import { FormDirty } from './form-dirty';
import { type ReducedFormDeclaration, ReducedFormStore } from './reduced-form.store';
import { STRINGS } from './strings';

/**
 * The reduced forms' store over a scripted API (Story 9.9): its read, its absent and bare states,
 * the Save body (only what changed, a flag as its whole number), "Saved", the change event it
 * publishes (AD-14), a refusal kept on its field, the dirty flag, and the serving-service rules.
 */

const SERVICE = { AutheEnabled: 48, ClientSystems: ['10.0.0.9|%All'], Description: 'Controls the Call-In Interface', Enabled: false };

const LDAP = {
  Description: 'probe',
  LDAPFlags: 8,
  LDAPHostNames: ['h1.invalid'],
  LDAPSearchUsername: 'CN=x',
  LDAPBaseDN: 'DC=x',
  LDAPUniqueDNIdentifier: 'sAMAccountName',
};

interface Call {
  readonly path: string;
  readonly init: ApiRequestInit;
}

function harness(declaration: ReducedFormDeclaration, read: unknown, save: JsonResult<unknown> = { kind: 'ok', status: 200, body: { name: 'x' } }) {
  const calls: Call[] = [];
  const published: ChangeEventInput[] = [];
  const formDirty = new FormDirty();
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, init });
      if ((init.method ?? 'GET') === 'PUT') return save as JsonResult<T>;
      return read as JsonResult<T>;
    },
  };
  const store = new ReducedFormStore(declaration, { api, bus: { publish: (input) => (published.push(input), true) }, formDirty });
  return { store, calls, published, formDirty };
}

const ok = (body: unknown): JsonResult<unknown> => ({ kind: 'ok', status: 200, body });

describe('the reduced form store', () => {
  it('reads the entity its route names and holds its declared fields', async () => {
    const { store, calls } = harness(SERVICE_FORM, ok({ service: SERVICE, servesOcuPilot: false }));
    await store.open('%Service_CallIn');
    expect(calls[0].path).toBe('/api/ocupilot/services/form?name=%25Service_CallIn');
    expect(store.held()).toBe(true);
    expect(store.toggled(SERVICE_FORM.fields[0])).toBe(false);
    expect(store.entries('ClientSystems')).toEqual(['10.0.0.9|%All']);
    expect(store.servesOcuPilot()).toBe(false);
  });

  it('the bare route reads nothing, and a 404 is absent', async () => {
    const bare = harness(SERVICE_FORM, ok({}));
    await bare.store.open('');
    expect(bare.store.bare()).toBe(true);
    expect(bare.calls).toHaveLength(0);
    const gone = harness(LDAP_FORM, { kind: 'error', status: 404, code: 'LDAP.ABSENT', reason: STRINGS.ldapGone, detail: null });
    await gone.store.open('ocup99.invalid');
    expect(gone.store.absent()).toBe(true);
    expect(gone.store.held()).toBe(false);
    expect(gone.store.canSave()).toBe(false);
  });

  it('Integration, AD-4, AD-14: a Save sends only what changed, shows Saved, marks the form clean and publishes updated', async () => {
    // Mutation (Rule 19): skip the `updated` publish in `save()` -> the published assertion goes red.
    const { store, calls, published, formDirty } = harness(SERVICE_FORM, ok({ service: SERVICE, servesOcuPilot: false }));
    await store.open('%Service_CallIn');
    expect(store.addEntry(SERVICE_FORM.fields[1], ' 10.0.0.1 ')).toBe(true);
    expect(formDirty.dirty()).toBe(true);
    expect(store.changedBody()).toEqual({ ClientSystems: ['10.0.0.9|%All', '10.0.0.1'] });
    expect(await store.save()).toBe(true);
    const put = calls[calls.length - 1];
    expect(put.path).toBe('/api/ocupilot/services/%2525Service_CallIn');
    expect(put.init.method).toBe('PUT');
    expect(JSON.parse(put.init.body ?? '')).toEqual({ ClientSystems: ['10.0.0.9|%All', '10.0.0.1'] });
    expect(store.saved()).toBe(true);
    expect(formDirty.dirty()).toBe(false);
    expect(published).toEqual([{ kind: 'changed', type: 'service', scope: 'instance', id: '%Service_CallIn', action: 'updated' }]);
  });

  it('a Save that changes nothing sends nothing', async () => {
    const { store, calls } = harness(SERVICE_FORM, ok({ service: SERVICE, servesOcuPilot: false }));
    await store.open('%Service_CallIn');
    expect(await store.save()).toBe(true);
    expect(calls).toHaveLength(1);
  });

  it('LDAP enabled sets bit 64 on the flags the form opened and keeps every other bit', async () => {
    const { store } = harness(LDAP_FORM, ok({ ldap: LDAP }));
    await store.open('ocup99.invalid');
    const enabled = LDAP_FORM.fields[1];
    expect(store.toggled(enabled)).toBe(false);
    store.setToggle(enabled, true);
    expect(store.changedBody()).toEqual({ LDAPFlags: 72 });
    store.setToggle(enabled, false);
    expect(store.changedBody()).toEqual({});
  });

  it('a | in the service address field is refused on the field before anything is sent', async () => {
    const { store } = harness(SERVICE_FORM, ok({ service: SERVICE, servesOcuPilot: false }));
    await store.open('%Service_CallIn');
    expect(store.addEntry(SERVICE_FORM.fields[1], '10.0.0.2|%All')).toBe(false);
    expect(store.violationFor('ClientSystems')).toBe(STRINGS.serviceAddressNoRoles);
    expect(store.changedBody()).toEqual({});
  });

  it('a refused Save keeps what was entered and routes the server sentence to its field', async () => {
    const refusal: JsonResult<unknown> = {
      kind: 'error',
      status: 422,
      code: 'SERVICE.VALIDATION',
      reason: 'The service change was refused.',
      detail: { violations: [{ field: 'ClientSystems', code: 'SERVICE.ADDRESS.SHAPE', reason: 'An allowed connection is one address, with no spaces or semicolons.' }] },
    };
    const { store, published } = harness(SERVICE_FORM, ok({ service: SERVICE, servesOcuPilot: false }), refusal);
    await store.open('%Service_CallIn');
    store.addEntry(SERVICE_FORM.fields[1], 'a;b');
    expect(await store.save()).toBe(false);
    expect(store.violationFor('ClientSystems')).toBe('An allowed connection is one address, with no spaces or semicolons.');
    expect(store.entries('ClientSystems')).toContain('a;b');
    expect(published).toEqual([]);
    expect(store.saved()).toBe(false);
  });

  it('AC5: on the service OcuPilot is served through, Enabled is protected and an address change carries the consequence', async () => {
    const { store } = harness(SERVICE_FORM, ok({ service: { ...SERVICE, Enabled: true, ClientSystems: [] }, servesOcuPilot: true }));
    await store.open('%Service_WebGateway');
    const [enabled, clients] = SERVICE_FORM.fields;
    expect(store.protectedField(enabled)).toBe(true);
    store.setToggle(enabled, false);
    expect(store.changedBody()).toEqual({});
    expect(store.consequence(clients)).toBe('');
    store.addEntry(clients, '10.0.0.1');
    expect(store.consequence(clients)).toBe(STRINGS.serviceEffectServesOcuPilot);
  });
});

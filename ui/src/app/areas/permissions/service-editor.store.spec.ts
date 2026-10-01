import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { STRINGS } from '../../core/strings';
import { ServiceEditor } from './service-editor.store';

/**
 * The service editor's store over a scripted form read and Save (Story 16.13): the groups a service
 * has, the mask the method boxes are bits of, an entry kept in the instance's own spelling until the
 * form changes it, the three effect lines, the `|` refusal, and the Save's body, "Saved" and change
 * event.
 */

/** `%Service_CacheDirect` as the form read answers it: methods and addresses, no roles. */
function cacheDirect(overrides: Record<string, unknown> = {}) {
  return {
    service: { Name: '%Service_CacheDirect', AutheEnabled: 2080, ClientSystems: [], Description: 'Controls Cache Direct', Enabled: false },
    servesOcuPilot: false,
    authenticationMethods: [
      { bit: 64, label: 'Unauthenticated' },
      { bit: 32, label: 'Password' },
      { bit: 128, label: 'Kerberos' },
    ],
    clientSystems: true,
    clientRoles: false,
    connections: [],
    roles: [],
    ...overrides,
  };
}

/** `%Service_ECP` as the form read answers it: addresses with roles, no methods. */
function ecp(entries: readonly { entry: string; address: string; roles: string[] }[] = []) {
  return {
    service: { Name: '%Service_ECP', AutheEnabled: 1024, ClientSystems: entries.map((item) => item.entry), Description: 'Controls ECP', Enabled: false },
    servesOcuPilot: false,
    authenticationMethods: [],
    clientSystems: true,
    clientRoles: true,
    connections: entries,
    roles: [
      { name: '%All', privileged: true },
      { name: '%Manager', privileged: false },
      { name: '%Operator', privileged: false },
    ],
  };
}

function mount(read: unknown, save: JsonResult<unknown> = { kind: 'ok', status: 200, body: { name: 'x' } }) {
  TestBed.resetTestingModule();
  const calls: { path: string; method: string; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      calls.push({ path, method, body: init.body ?? '' });
      if (method === 'PUT') return save as JsonResult<T>;
      return (read === null ? { kind: 'error', status: 404, code: 'SERVICE.ABSENT', reason: STRINGS.serviceGone, detail: null } : { kind: 'ok', status: 200, body: read }) as JsonResult<T>;
    },
  };
  const formDirty = new FormDirty();
  const bus = new ChangeBus();
  const events: ChangeEvent[] = [];
  bus.subscribe((event) => events.push(event));
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: FormDirty, useValue: formDirty },
      { provide: ChangeBus, useValue: bus },
    ],
  });
  return { store: TestBed.inject(ServiceEditor), calls, events, formDirty };
}

afterEach(() => TestBed.resetTestingModule());

describe('the service editor store (Story 16.13)', () => {
  it('AC1: reads the service its route names with the groups it has', async () => {
    const { store, calls } = mount(cacheDirect());
    await store.open('%Service_CacheDirect');
    expect(calls[0].path).toBe('/api/ocupilot/services/form?name=%25Service_CacheDirect');
    expect(store.held()).toBe(true);
    expect(store.methods().map((method) => method.bit)).toEqual([64, 32, 128]);
    expect(store.hasMethodsTab()).toBe(true);
    expect(store.hasConnectionsTab()).toBe(true);
    expect(store.clientRoles()).toBe(false);
    const roles = mount(ecp());
    await roles.store.open('%Service_ECP');
    expect(roles.store.hasMethodsTab()).toBe(false);
    expect(roles.store.clientRoles()).toBe(true);
  });

  it('AC4: a method box sets or clears its bit over the mask read, keeping a bit the form does not offer', async () => {
    // Mutation (Rule 19): make `setAuthe` replace the mask with the offered bits alone -> the 2048
    // this service holds is dropped and this goes red.
    const { store } = mount(cacheDirect());
    await store.open('%Service_CacheDirect');
    expect(store.autheChecked(32)).toBe(true);
    expect(store.autheChecked(64)).toBe(false);
    store.setAuthe(64, true);
    expect(store.changedFields()).toEqual({ AutheEnabled: 2144 });
    expect(store.methodsEffect()).toBe(STRINGS.serviceEffectUnauthenticated);
    store.setAuthe(64, false);
    expect(store.changedFields()).toEqual({});
    expect(store.methodsEffect()).toBe('');
    store.setAuthe(32, false);
    expect(store.changedFields()).toEqual({ AutheEnabled: 2048 });
  });

  it('AC2, Integration: an added address is sent as the whole list, and an accepted Save shows Saved and publishes updated', async () => {
    const readBack = { verdict: 'matches', fields: [], written: [] };
    const { store, calls, events, formDirty } = mount(cacheDirect(), { kind: 'ok', status: 200, body: { name: '%Service_CacheDirect', readBack } });
    await store.open('%Service_CacheDirect');
    expect(store.addAddress(' 10.0.0.1 ')).toBe(true);
    expect(store.addAddress('10.0.0.1')).toBe(false);
    expect(formDirty.dirty()).toBe(true);
    expect(await store.save()).toBe(true);
    const put = calls[calls.length - 1];
    expect(put.method).toBe('PUT');
    expect(put.path).toBe('/api/ocupilot/services/%2525Service_CacheDirect');
    expect(JSON.parse(put.body)).toEqual({ ClientSystems: ['10.0.0.1'] });
    expect(store.saved()).toBe(true);
    expect(formDirty.dirty()).toBe(false);
    expect(events.map((event) => `${event.kind} ${event.type} ${event.scope} ${event.id} ${event.action}`)).toEqual([
      'changed service instance %Service_CacheDirect updated',
    ]);
    expect(events[0].readBack).toEqual({ ...readBack, reason: '' });
    store.removeConnection(0);
    expect(store.changedFields()).toEqual({ ClientSystems: [] });
  });

  it('a | in the address field is refused on the field before anything is sent', async () => {
    const { store } = mount(cacheDirect());
    await store.open('%Service_CacheDirect');
    expect(store.addAddress('10.0.0.2|%All')).toBe(false);
    expect(store.violationFor('ClientSystems')).toBe(STRINGS.serviceAddressNoRoles);
    expect(store.changedFields()).toEqual({});
  });

  it('an address with roles in the instance\u2019s own address:role spelling is refused too, and an IPv6 address is not', async () => {
    // Mutation (Rule 19): refuse only a `|` in `addAddress` -> `10.0.0.3:%All` is added and this goes red.
    const { store } = mount(ecp());
    await store.open('%Service_ECP');
    expect(store.addAddress('10.0.0.3:%All')).toBe(false);
    expect(store.violationFor('ClientSystems')).toBe(STRINGS.serviceAddressNoRoles);
    expect(store.changedFields()).toEqual({});
    expect(store.addAddress('fe80::1')).toBe(true);
    expect(store.changedFields()).toEqual({ ClientSystems: ['fe80::1'] });
  });

  it('an address already listed with roles is not added again as a bare entry', async () => {
    // Mutation (Rule 19): compare the typed address with each whole entry in `addAddress` -> `10.0.0.6` is added beside `10.0.0.6:%Manager` and this goes red.
    const { store } = mount(ecp([{ entry: '10.0.0.6:%Manager', address: '10.0.0.6', roles: ['%Manager'] }]));
    await store.open('%Service_ECP');
    expect(store.addAddress('10.0.0.6')).toBe(false);
    expect(store.changedFields()).toEqual({});
  });

  it('a service that checks no address draws its connections tab only while it holds an entry, and takes no new one', async () => {
    // Mutation (Rule 19): make `hasConnectionsTab` answer `clientSystems` alone -> the held-entry leg goes red.
    const callIn = (entries: readonly string[]) =>
      cacheDirect({
        service: { Name: '%Service_CallIn', AutheEnabled: 48, ClientSystems: entries, Description: 'Controls CallIn', Enabled: false },
        clientSystems: false,
        connections: entries.map((entry) => ({ entry, address: entry, roles: [] })),
      });
    const empty = mount(callIn([]));
    await empty.store.open('%Service_CallIn');
    expect(empty.store.hasConnectionsTab()).toBe(false);
    const held = mount(callIn(['10.0.0.4']));
    await held.store.open('%Service_CallIn');
    expect(held.store.hasConnectionsTab()).toBe(true);
    expect(held.store.addAddress('10.0.0.5')).toBe(false);
    held.store.removeConnection(0);
    expect(held.store.changedFields()).toEqual({ ClientSystems: [] });
  });

  it('AC3: an entry is sent in the instance\u2019s own spelling until its roles change, then composed', async () => {
    const { store } = mount(
      ecp([
        { entry: '10.0.0.6:%Manager', address: '10.0.0.6', roles: ['%Manager'] },
        { entry: '10.0.0.5', address: '10.0.0.5', roles: [] },
      ])
    );
    await store.open('%Service_ECP');
    store.setRoles(0, ['%manager']);
    expect(store.changedFields()).toEqual({});
    store.setRoles(1, ['%Operator']);
    expect(store.changedFields()).toEqual({ ClientSystems: ['10.0.0.6:%Manager', '10.0.0.5|%Operator'] });
    expect(store.connections()[1]).toEqual({ entry: '10.0.0.5|%Operator', address: '10.0.0.5', roles: ['%Operator'] });
    expect(store.privilegeEffect()).toBe('');
    store.setRoles(1, ['%Operator', '%All']);
    expect(store.privilegeEffect()).toBe(STRINGS.privilegedGrantEffect);
    store.setRoles(1, []);
    expect(store.changedFields()).toEqual({});
  });

  it('AC5: on the service OcuPilot is served through, Enabled is protected and a changed list or mask carries the served-through line', async () => {
    const { store } = mount(
      cacheDirect({
        service: { Name: '%Service_WebGateway', AutheEnabled: 32, ClientSystems: [], Description: 'Controls Web Gateway sessions', Enabled: true },
        servesOcuPilot: true,
      })
    );
    await store.open('%Service_WebGateway');
    expect(store.enabledProtected()).toBe(true);
    store.setEnabled(false);
    expect(store.changedFields()).toEqual({});
    expect(store.connectionsEffect()).toBe('');
    store.addAddress('10.0.0.1');
    expect(store.connectionsEffect()).toBe(STRINGS.serviceEffectServesOcuPilot);
    store.setAuthe(64, true);
    expect(store.methodsEffect()).toBe(STRINGS.serviceEffectServesOcuPilot);
  });

  it('a refused Save keeps what was entered and routes the server sentence to its field; a 404 turns the form absent', async () => {
    const refusal: JsonResult<unknown> = {
      kind: 'error',
      status: 422,
      code: 'SERVICE.VALIDATION',
      reason: 'The service change was refused.',
      detail: { violations: [{ field: 'ClientSystems', code: 'SERVICE.ADDRESS.INVALID', reason: 'Use an IP address.' }] },
    };
    const { store, events } = mount(cacheDirect(), refusal);
    await store.open('%Service_CacheDirect');
    store.addAddress('999.1.1.1');
    expect(await store.save()).toBe(false);
    expect(store.violationFor('ClientSystems')).toBe('Use an IP address.');
    expect(store.connections().map((connection) => connection.entry)).toEqual(['999.1.1.1']);
    expect(store.saved()).toBe(false);
    expect(events).toEqual([]);
    const gone = mount(cacheDirect(), { kind: 'error', status: 404, code: 'SERVICE.ABSENT', reason: STRINGS.serviceGone, detail: null });
    await gone.store.open('%Service_CacheDirect');
    gone.store.setEnabled(true);
    expect(await gone.store.save()).toBe(false);
    expect(gone.store.absent()).toBe(true);
  });

  it('the bare route reads nothing, and an absent name is absent', async () => {
    const bare = mount(cacheDirect());
    await bare.store.open('');
    expect(bare.store.bare()).toBe(true);
    expect(bare.calls).toHaveLength(0);
    const gone = mount(null);
    await gone.store.open('OcuPilotNoSuchService99');
    expect(gone.store.absent()).toBe(true);
    expect(gone.store.held()).toBe(false);
    expect(gone.store.canSave()).toBe(false);
  });
});

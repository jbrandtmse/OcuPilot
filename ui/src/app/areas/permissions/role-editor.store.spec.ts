import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { RoleEditor } from './role-editor.store';

/** The role editor's store over a stubbed form read (Story 9.3). */

function role(overrides: Record<string, unknown> = {}) {
  return {
    Name: 'Probe',
    Description: 'probe',
    EscalationOnly: false,
    GrantedRoles: ['%Developer'],
    Resources: [{ Name: '%DB_USER', Permissions: 'RW' }],
    ...overrides,
  };
}

function mount(answers: Record<string, unknown>[], members: Record<string, unknown>[] = []) {
  TestBed.resetTestingModule();
  const queue = [...answers];
  const puts: string[] = [];
  const api = {
    requestJson: async <T,>(_path?: string, init: { method?: string; body?: string } = {}): Promise<JsonResult<T>> => {
      if (init.method === 'PUT') {
        puts.push(init.body ?? '');
        return { kind: 'ok', status: 200, body: {} } as JsonResult<T>;
      }
      const body = {
        requiredFields: [],
        maxLengths: { Description: 256 },
        rules: [],
        roles: [
          { name: 'Probe', privileged: true },
          { name: '%Developer', privileged: false },
        ],
        resources: [{ name: '%DB_USER', permissions: 'RW', privileged: false }],
        role: queue.shift() ?? role(),
        members,
        holders: 1,
      };
      return { kind: 'ok', status: 200, body } as JsonResult<T>;
    },
  };
  const bus = new ChangeBus();
  const events: ChangeEvent[] = [];
  bus.subscribe((event) => events.push(event));
  const formDirty = new FormDirty();
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: FormDirty, useValue: formDirty },
      { provide: ChangeBus, useValue: bus },
    ],
  });
  return { store: TestBed.inject(RoleEditor), formDirty, puts, events };
}

afterEach(() => TestBed.resetTestingModule());

describe('the role editor store (Story 9.3)', () => {
  it('reads the role, its grants, granted roles and members, and marks it privileged by the server', async () => {
    const { store } = mount([role()], [{ Name: 'Dana', Type: 'User' }, { Name: 'Outer', Type: 'Role' }]);
    await store.open('Probe');
    expect(store.description()).toBe('probe');
    expect(store.grants()).toEqual([{ name: '%DB_USER', permissions: 'RW' }]);
    expect(store.grantedRoles()).toEqual(['%Developer']);
    expect(store.members()).toEqual([
      { name: 'Dana', type: 'User' },
      { name: 'Outer', type: 'Role' },
    ]);
    expect(store.privileged()).toBe(true);
  });

  it('saves only the description and the escalation flag, and only where they changed', async () => {
    // Mutation (Rule 19): send the grants with every Save -> the body assertion goes red.
    const { store, puts, events } = mount([role()]);
    await store.open('Probe');
    expect(store.changedFields()).toEqual({});
    store.setEscalationOnly(true);
    expect(store.changedFields()).toEqual({ EscalationOnly: true });
    expect(await store.save()).toBe(true);
    expect(JSON.parse(puts[0])).toEqual({ EscalationOnly: true });
    expect(events).toHaveLength(1);
    expect(events[0]).toMatchObject({ kind: 'changed', type: 'role', scope: 'instance', id: 'Probe', action: 'updated' });
  });

  it('reads a role the instance does not hold as absent, with the server\u2019s sentence and nothing editable', async () => {
    // Mutation (Rule 19): drop the 404 branch from `absorb` -> the absent assertion goes red.
    const { store } = mount([]);
    const api = TestBed.inject(ApiService) as unknown as { requestJson: () => Promise<JsonResult<unknown>> };
    api.requestJson = async () =>
      ({ kind: 'error', status: 404, code: 'ROLE.NAME.ABSENT', reason: 'This instance has no role with that name.', detail: null }) as JsonResult<unknown>;
    await store.open('Gone');
    expect(store.absent()).toBe(true);
    expect(store.reason()).toBe('This instance has no role with that name.');
    expect(store.editable()).toBe(false);
    expect(store.canSave()).toBe(false);
  });

  it('re-reads only the grants and members while the form holds unsaved work', async () => {
    // Mutation (Rule 19): absorb every field on a dirty refresh -> the kept-description assertion goes red.
    const { store, formDirty } = mount([role(), role({ Description: 'moved', Resources: [] })]);
    await store.open('Probe');
    store.setDescription('typed');
    expect(formDirty.dirty()).toBe(true);
    await store.refresh();
    expect(store.description()).toBe('typed');
    expect(store.grants()).toEqual([]);
  });
});

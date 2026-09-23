import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { entityRefKey } from '../../core/entity-ref';
import { FormDirty } from '../../core/form-dirty';
import { SCREENS } from '../../core/screens.generated';
import {
  NAME_TAKEN_CODE,
  ROLES_FORM_PATH,
  ROLES_NAME_PATH,
  ROLES_PATH,
  RoleCreateForm,
} from './role-create-form.store';

/**
 * The create-a-role form's store (AD-14, AD-39, AD-55).
 *
 * It pins what no browser leg can falsify: the change event a Save publishes, the body's grants in
 * the vendor's own shape, the grant dialog's result applied and removed, the fail-closed reading of
 * the bootstrap's marks, and a server refusal landing on the field it names. The bus is real and
 * only the server's answers are stubbed.
 */

/** What `GET /roles/form` answers, narrowed to what these tests read. */
const RULES = {
  requiredFields: ['Name'],
  maxLengths: { Name: 64, Description: 256 },
  rules: [{ field: 'Name', code: 'ROLE.NAME.REQUIRED', reason: 'Give the role a name.' }],
  roles: [
    { name: '%Developer', privileged: false },
    { name: '%Manager', privileged: true },
    { name: 'ProbeUnmarked' },
  ],
  resources: [
    { name: '%DB_USER', permissions: 'RW', privileged: false, privilegedPermissions: '' },
    { name: '%Admin_Secure', permissions: 'U', privileged: true, privilegedPermissions: 'U' },
    { name: 'ProbeUnmarked', permissions: 'RWU' },
  ],
  privilegeReason: 'OcuPilot does not grant %All or an administrative privilege.',
};

const TAKEN_SENTENCE = 'This instance already has a role with that name.';

async function settle(): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
}

function mount(
  createAnswer: JsonResult<unknown> = { kind: 'ok', status: 201, body: { name: 'ProbeRole', role: {} } },
  nameAnswer: JsonResult<unknown> = { kind: 'ok', status: 200, body: { name: 'ProbeRole', available: true, reason: '' } }
) {
  TestBed.resetTestingModule();
  const calls: { path: string; method: string; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      if (path === ROLES_FORM_PATH) {
        return { kind: 'ok', status: 200, body: RULES } as unknown as JsonResult<T>;
      }
      if (path.startsWith(ROLES_NAME_PATH)) return nameAnswer as JsonResult<T>;
      return createAnswer as JsonResult<T>;
    },
  };
  const bus = new ChangeBus();
  const events: ChangeEvent[] = [];
  bus.subscribe((event) => events.push(event));
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: bus },
      { provide: FormDirty, useValue: new FormDirty() },
    ],
  });
  return { store: TestBed.inject(RoleCreateForm), calls, events };
}

function postedBody(calls: { path: string; method: string; body: string }[]): Record<string, unknown> {
  const post = calls.filter((call) => call.method === 'POST').at(-1);
  expect(post).toBeDefined();
  expect(post!.path).toBe(ROLES_PATH);
  return JSON.parse(post!.body) as Record<string, unknown>;
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the create-a-role form store', () => {
  it('AC5, AD-14: a Save publishes one created event carrying the scoped triple', async () => {
    const { store, events } = mount();
    await store.open();
    store.setValue('Name', 'ProbeRole');
    expect(await store.save()).toBe(true);
    await settle();

    // Mutation (Rule 19): drop the `publishCreated()` call from `save()` -> this goes red, and an
    // open Roles list never re-fetches the role the form just created.
    expect(events).toEqual([
      {
        kind: 'changed',
        type: 'role',
        scope: 'instance',
        id: 'ProbeRole',
        key: entityRefKey('role', 'instance', 'ProbeRole'),
        action: 'created',
        proposalId: '',
        expiresAt: 0,
      },
    ]);
    // The type is the Roles list's own declared entity type, which is what that list listens for.
    expect(SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.RoleList')?.entityType).toBe('role');
    expect(store.saved()).toBe(true);
    expect(store.createdId()).toBe('ProbeRole');
  });

  it('AD-54: the body carries the name, the description, each grant as {Name, Permissions} and the ticked roles', async () => {
    const { store, calls } = mount();
    await store.open();
    store.setValue('Name', 'ProbeRole');
    store.setValue('Description', 'probe');
    store.applyGrant('%DB_USER', 'WR');
    store.applyGrant('ProbeUnmarked', 'u');
    store.applyGrant('%db_user', 'R');
    store.setRole('%Developer', true);
    store.setRole('%Manager', true);
    expect(await store.save()).toBe(true);
    expect(postedBody(calls)).toEqual({
      Name: 'ProbeRole',
      Description: 'probe',
      Resources: [
        { Name: '%DB_USER', Permissions: 'R' },
        { Name: 'ProbeUnmarked', Permissions: 'U' },
      ],
      GrantedRoles: ['%Developer'],
    });
  });

  it('AC2: a grant applied with no letter is removed, and the form is dirty after every change', async () => {
    const { store } = mount();
    await store.open();
    expect(store.dirty()).toBe(false);
    store.applyGrant('%DB_USER', 'RW');
    expect(store.dirty()).toBe(true);
    expect(store.grants()).toEqual([{ name: '%DB_USER', permissions: 'RW' }]);
    store.applyGrant('%DB_USER', '');
    expect(store.grants()).toEqual([]);
  });

  it('AC4, AD-39: the bootstrap marks read fail-closed, and a server refusal lands on the field it names', async () => {
    const refusal: JsonResult<unknown> = {
      kind: 'error',
      status: 422,
      code: 'ROLE.VALIDATION',
      reason: 'The role was refused.',
      detail: {
        violations: [{ field: 'Resources', code: 'PROHIBITED.PRIVILEGEGRANT', reason: RULES.privilegeReason }],
      },
    } as unknown as JsonResult<unknown>;
    const { store } = mount(refusal);
    await store.open();
    expect(store.rules().roles.find((role) => role.name === 'ProbeUnmarked')?.privileged).toBe(true);
    expect(store.resource('ProbeUnmarked')?.privileged).toBe(true);
    expect(store.resource('%db_user')?.privileged).toBe(false);
    expect(store.rules().privilegeReason).toBe(RULES.privilegeReason);
    store.setValue('Name', 'ProbeRole');
    store.applyGrant('%DB_USER', 'RW');
    expect(await store.save()).toBe(false);
    expect(store.violationFor('Resources')).toBe(RULES.privilegeReason);
    expect(store.reason()).toBe('');
    // Editing the grants drops the refusal on that field.
    store.applyGrant('%DB_USER', 'R');
    expect(store.violationFor('Resources')).toBe('');
  });

  it('the name look-up marks a taken name with the server sentence', async () => {
    const { store } = mount(undefined, {
      kind: 'ok',
      status: 200,
      body: { name: 'ProbeRole', available: false, reason: TAKEN_SENTENCE },
    });
    await store.open();
    store.setValue('Name', 'ProbeRole');
    await store.onBlur('Name');
    expect(store.violations()).toEqual([{ field: 'Name', code: NAME_TAKEN_CODE, reason: TAKEN_SENTENCE }]);
  });
});

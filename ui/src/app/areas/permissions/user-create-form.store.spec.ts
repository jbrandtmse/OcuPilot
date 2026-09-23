import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { entityRefKey } from '../../core/entity-ref';
import { FormDirty } from '../../core/form-dirty';
import {
  NAME_TAKEN_CODE,
  USERS_FORM_PATH,
  USERS_NAME_PATH,
  USERS_PATH,
  USER_ENTITY,
  USER_SCOPE,
  UserCreateForm,
} from './user-create-form.store';

/**
 * The create-a-user form's store (AD-14, AD-35, AD-39, AD-55).
 *
 * It pins what no browser leg can falsify: the change event a Save publishes (the form replaces
 * its own route, and the list the browser then opens re-reads on arrival either way), that the
 * password leaves the store on an accepted Save, on `reset()` and before the route replacement,
 * that a server refusal lands on the Roles field, and that a privileged role is sent and flagged for
 * its consequence rather than withheld. The bus is real and only the server's answers are stubbed.
 */

/** What `GET /users/form` answers, narrowed to what these tests read. */
const RULES = {
  requiredFields: ['Name', 'Password'],
  maxLengths: { Name: 160, FullName: 2048, NameSpace: 64, Routine: 64 },
  rules: [
    { field: 'Password', code: 'USER.PASSWORD.REQUIRED', reason: 'Enter a password.' },
    { field: 'Name', code: 'USER.NAME.REQUIRED', reason: 'Enter a name.' },
  ],
  roles: [
    { name: '%Developer', privileged: false },
    { name: '%All', privileged: true },
    { name: '%SQL', privileged: false },
  ],
};

const UNKNOWN_ROLE_SENTENCE = 'One of those roles does not exist on this instance.';

const TAKEN_SENTENCE = 'This instance already has a user with that name.';

async function settle(): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
}

function mount(
  createAnswer: JsonResult<unknown> = { kind: 'ok', status: 201, body: { name: 'probeuser', user: {} } },
  nameAnswer: JsonResult<unknown> = { kind: 'ok', status: 200, body: { name: 'probeuser', available: true, reason: '' } }
) {
  TestBed.resetTestingModule();
  const calls: { path: string; method: string; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      if (path === USERS_FORM_PATH) {
        return { kind: 'ok', status: 200, body: RULES } as unknown as JsonResult<T>;
      }
      if (path.startsWith(USERS_NAME_PATH)) return nameAnswer as JsonResult<T>;
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
  return { store: TestBed.inject(UserCreateForm), calls, events };
}

function postedBody(calls: { path: string; method: string; body: string }[]): Record<string, unknown> {
  const post = calls.filter((call) => call.method === 'POST').at(-1);
  expect(post).toBeDefined();
  expect(post!.path).toBe(USERS_PATH);
  return JSON.parse(post!.body) as Record<string, unknown>;
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the create-a-user form store', () => {
  it('AC4, AD-14: a Save publishes one created event carrying the scoped triple', async () => {
    const { store, events } = mount();
    await store.open();
    store.setValue('Name', 'probeuser');
    store.setPassword('probe-secret-1');
    expect(await store.save()).toBe(true);
    await settle();

    // Mutation (Rule 19): drop the `ChangeBus.publish` call from `save()` -> this goes red, and an
    // open Users list never re-fetches the account the form just created.
    expect(events).toEqual([
      {
        kind: 'changed',
        type: USER_ENTITY,
        scope: USER_SCOPE,
        id: 'probeuser',
        key: entityRefKey(USER_ENTITY, USER_SCOPE, 'probeuser'),
        action: 'created',
        proposalId: '',
        expiresAt: 0,
      },
    ]);
    expect(store.saved()).toBe(true);
    expect(store.createdId()).toBe('probeuser');
  });

  it('AD-54: the body carries every create field, the password and the ticked roles in the order offered', async () => {
    const { store, calls } = mount();
    await store.open();
    store.setValue('Name', 'probeuser');
    store.setValue('FullName', 'Probe User');
    store.setPassword('probe-secret-1');
    store.setValue('ExpirationDate', '2027-01-31');
    store.setValue('NameSpace', 'HSCUSTOM');
    store.setValue('Routine', 'START^PROBE');
    store.setRole('%SQL', true);
    store.setRole('%Developer', true);
    await store.save();

    expect(postedBody(calls)).toEqual({
      Name: 'probeuser',
      Password: 'probe-secret-1',
      FullName: 'Probe User',
      ExpirationDate: '2027-01-31',
      NameSpace: 'HSCUSTOM',
      Routine: 'START^PROBE',
      Roles: ['%Developer', '%SQL'],
    });
  });

  it('AD-35: the password leaves the store on an accepted Save, on reset and before the route replacement', async () => {
    const { store } = mount();
    await store.open();
    store.setValue('Name', 'probeuser');
    store.setPassword('probe-secret-1');
    await store.save();
    // Mutation (Rule 19): drop the clear from `save()` -> this goes red, and the field would be
    // drawn with the sent password in it after the save.
    expect(store.password()).toBe('');

    store.setPassword('typed-after-save');
    store.retainAcrossRouteReplacement();
    expect(store.password(), 'the retained buffer carries no password across the navigation').toBe('');
    expect(store.value('Name'), 'but the rest of what was saved stays on screen').toBe('probeuser');

    store.setPassword('typed-again');
    store.reset();
    expect(store.password()).toBe('');
  });

  it('a refused Save keeps what was typed, the password included, so the user corrects one field', async () => {
    const { store } = mount({
      kind: 'error',
      status: 422,
      error: 'validation_failed',
      reason: 'The user was refused.',
      code: 'USER.VALIDATION',
      detail: {
        violations: [{ field: 'NameSpace', code: 'USER.NAMESPACE.UNKNOWN', reason: 'Choose a namespace that exists.' }],
      },
    } as unknown as JsonResult<unknown>);
    await store.open();
    store.setValue('Name', 'probeuser');
    store.setValue('NameSpace', 'NOPE');
    store.setPassword('probe-secret-1');
    expect(await store.save()).toBe(false);
    expect(store.violationFor('NameSpace')).toBe('Choose a namespace that exists.');
    expect(store.password()).toBe('probe-secret-1');
    expect(store.saved()).toBe(false);
  });

  it('AC3: a role refusal from the server lands on the Roles field with the server sentence', async () => {
    const { store, events } = mount({
      kind: 'error',
      status: 422,
      error: 'validation_failed',
      reason: 'The user was refused.',
      code: 'USER.VALIDATION',
      detail: {
        violations: [
          { field: 'Roles', code: 'USER.ROLES.UNKNOWN', reason: UNKNOWN_ROLE_SENTENCE },
        ],
      },
    } as unknown as JsonResult<unknown>);
    await store.open();
    store.setValue('Name', 'probeuser');
    store.setPassword('probe-secret-1');
    store.setRole('%Developer', true);
    expect(await store.save()).toBe(false);

    expect(store.violationFor('Roles')).toBe(UNKNOWN_ROLE_SENTENCE);
    expect(store.violations()[0]?.field).toBe('Roles');
    expect(store.reason(), 'a field violation is not an envelope banner').toBe('');
    expect(events).toEqual([]);
    // Ticking a role clears the refusal it stood over.
    store.setRole('%SQL', true);
    expect(store.violationFor('Roles')).toBe('');
  });

  it('AC3, AD-10: a privileged role is sent and flags its consequence while it is ticked', async () => {
    // Mutation (Rule 19): restore the early return for a privileged role in `setRole` -> the
    // ticked and posted assertions go red.
    const { store, calls } = mount();
    await store.open();
    expect(store.rules().roles.find((role) => role.name === '%All')?.privileged).toBe(true);
    store.setValue('Name', 'probeuser');
    store.setPassword('probe-secret-1');
    store.setRole('%Developer', true);
    expect(store.privilegedChecked()).toBe(false);
    store.setRole('%All', true);
    expect(store.roleChecked('%All')).toBe(true);
    expect(store.privilegedChecked()).toBe(true);
    await store.save();
    expect(postedBody(calls)['Roles']).toEqual(['%Developer', '%All']);
  });

  it('the blur look-up marks a taken name with the server sentence, and leaves the field unmarked when it could not be made', async () => {
    const taken = mount(undefined, {
      kind: 'ok',
      status: 200,
      body: { name: 'probeuser', available: false, reason: TAKEN_SENTENCE },
    } as unknown as JsonResult<unknown>);
    await taken.store.open();
    taken.store.setValue('Name', 'probeuser');
    await taken.store.onBlur('Name');
    expect(taken.store.violationFor('Name')).toBe(TAKEN_SENTENCE);
    expect(taken.store.violations()[0]?.code).toBe(NAME_TAKEN_CODE);
    expect(taken.calls.some((call) => call.path === `${USERS_NAME_PATH}?name=probeuser`)).toBe(true);

    const refused = mount(undefined, {
      kind: 'error',
      status: 500,
      error: 'server_error',
      reason: 'An internal error occurred',
      code: 'INTERNAL',
      detail: null,
    } as unknown as JsonResult<unknown>);
    await refused.store.open();
    refused.store.setValue('Name', 'probeuser');
    await refused.store.onBlur('Name');
    expect(refused.store.violations()).toEqual([]);
  });

  it('blurring an empty password renders the sentence the bootstrap read published for it', async () => {
    const { store } = mount();
    await store.open();
    await store.onBlur('Password');
    expect(store.violationFor('Password')).toBe('Enter a password.');
    store.setPassword('x');
    expect(store.violationFor('Password')).toBe('');
  });
});

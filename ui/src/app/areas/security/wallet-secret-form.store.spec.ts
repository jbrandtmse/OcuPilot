import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { entityRefKey } from '../../core/entity-ref';
import { FormDirty } from '../../core/form-dirty';
import { SCREENS } from '../../core/screens.generated';
import {
  NAME_TAKEN_CODE,
  WALLET_SECRET_FORM_PATH,
  WALLET_SECRET_NAME_PATH,
  WALLET_SECRET_PATH,
  WalletSecretForm,
  splitHosts,
} from './wallet-secret-form.store';

/**
 * The wallet secret form's store (AC1, AC2, AC7, AD-4, AD-14, AD-35, AD-39, AD-55).
 *
 * It pins what no browser leg can falsify: the change event a Save publishes, the create's one body,
 * the value held apart and emptied by an accepted Save, by `reset()` and across the route
 * replacement, an edit sending only the settings it changed and a value only when one was entered,
 * a secret of another type never saved, and a server refusal landing on the field it names. The bus
 * is real and only the server's answers are stubbed.
 */

const RULES = {
  requiredFields: ['Name', 'Secret'],
  maxLengths: { Name: 128, Secret: 32768 },
  rules: [
    { field: 'Name', code: 'WALLET.NAME.REQUIRED', reason: 'Give the secret a name.' },
    { field: 'Secret', code: 'WALLET.SECRET.REQUIRED', reason: 'Enter the value to store.' },
    { field: 'Name', code: 'WALLET.COLLECTION.ABSENT', reason: 'This instance has no wallet collection with that name.' },
  ],
};

const SECRET = {
  Name: 'Probe.Kv',
  Collection: 'Probe',
  Type: '%Wallet.KeyValue',
  Usage: 5,
  RequireTLS: false,
  AllowedHosts: ['h'],
  editable: true,
};

const SYMMETRIC = { Name: 'Probe.Sym', Collection: 'Probe', Type: '%Wallet.SymmetricKey', editable: false };

const VALUE = 'placeholder value';

const TAKEN_SENTENCE = 'This collection already has a secret with that name. Choose a different one.';

async function settle(): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
}

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: string;
}

function mount(
  saveAnswer: JsonResult<unknown> = { kind: 'ok', status: 201, body: { name: 'Probe.New' } },
  editRead: JsonResult<unknown> = { kind: 'ok', status: 200, body: { ...RULES, secret: SECRET } },
  nameAnswer: JsonResult<unknown> = { kind: 'ok', status: 200, body: { taken: true, reason: TAKEN_SENTENCE } }
) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      if (path.startsWith(`${WALLET_SECRET_FORM_PATH}?name=`)) return editRead as JsonResult<T>;
      if (path.startsWith(WALLET_SECRET_FORM_PATH)) {
        return { kind: 'ok', status: 200, body: { ...RULES, collection: 'Probe' } } as unknown as JsonResult<T>;
      }
      if (path.startsWith(WALLET_SECRET_NAME_PATH)) return nameAnswer as JsonResult<T>;
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
  return { store: TestBed.inject(WalletSecretForm), calls, events, formDirty };
}

function writes(calls: readonly Call[]): Call[] {
  return calls.filter((call) => call.method !== 'GET');
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the wallet secret form store', () => {
  it('AC7, AD-14: a create posts one body with every use allowed and TLS on by default, publishes one created event, and empties the value', async () => {
    const { store, calls, events, formDirty } = mount();
    await store.open('', 'Probe');
    expect(store.mode()).toBe('create');
    expect(store.collection()).toBe('Probe');
    expect([store.usage(), store.requireTls()]).toEqual([15, true]);
    store.setValue('Name', 'New');
    store.setSecret(VALUE);
    store.setUsageBit(8, false);
    store.setValue('AllowedHosts', 'a.example, b.example,');
    expect(formDirty.dirty()).toBe(true);
    expect(await store.save()).toBe(true);
    await settle();

    const [write] = writes(calls);
    expect(write?.path).toBe(WALLET_SECRET_PATH);
    expect(write?.method).toBe('POST');
    expect(JSON.parse(write!.body)).toEqual({
      Name: 'Probe.New',
      Secret: VALUE,
      Usage: 7,
      RequireTLS: true,
      AllowedHosts: ['a.example', 'b.example'],
    });
    // Mutation (Rule 19): drop the `publish` call from `save()` -> this goes red, and an open Secrets
    // list never re-fetches the secret the form stored (AC7).
    expect(events).toEqual([
      {
        kind: 'changed',
        type: 'wallet-secret',
        scope: 'instance',
        id: 'Probe.New',
        key: entityRefKey('wallet-secret', 'instance', 'Probe.New'),
        action: 'created',
        proposalId: '',
        expiresAt: 0,
      },
    ]);
    // The type is the Secrets list's own declared entity type, which is what that list listens for.
    expect(SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.WalletSecretList')?.entityType).toBe(
      'wallet-secret'
    );
    // AC1: the masked field is empty after the Save, and the form says a value is stored.
    expect(store.secretText()).toBe('');
    expect(store.stored()).toBe(true);
    expect(store.createdId()).toBe('Probe.New');
    expect(store.saved()).toBe(true);
    expect(formDirty.dirty()).toBe(false);
  });

  it('AD-35: a refused create keeps what was entered for correction, and remembers no value as the refused one', async () => {
    const refusal: JsonResult<unknown> = {
      kind: 'error',
      status: 422,
      code: 'WALLET.VALIDATION',
      reason: 'The secret was refused.',
      detail: { violations: [{ field: 'AllowedHosts', code: 'WALLET.ALLOWEDHOSTS.SHAPE', reason: 'Bad host.' }] },
    };
    const { store, events } = mount(refusal);
    await store.open('', 'Probe');
    store.setValue('Name', 'New');
    store.setSecret(VALUE);
    store.setValue('AllowedHosts', 'a b');
    expect(await store.save()).toBe(false);
    expect(store.violationFor('AllowedHosts')).toBe('Bad host.');
    expect(store.secretText()).toBe(VALUE);
    expect(store.stored()).toBe(false);
    expect(events).toEqual([]);

    // Leaving the form forgets the value, so a return to it never finds it pre-filled.
    store.reset();
    expect(store.secretText()).toBe('');
  });

  it('AC1: the route replacement carries the form across, less its value', async () => {
    const { store } = mount();
    await store.open('', 'Probe');
    store.setValue('Name', 'New');
    store.setSecret(VALUE);
    store.retainAcrossRouteReplacement();
    expect(store.retaining()).toBe(true);
    expect(store.secretText()).toBe('');
  });

  it('AC1: a create lands on the new secret\'s edit with the saved confirmation, a stored caption and no value', async () => {
    const { store } = mount(undefined, { kind: 'ok', status: 200, body: { ...RULES, secret: { ...SECRET, Name: 'Probe.New' } } });
    await store.open('', 'Probe');
    store.setValue('Name', 'New');
    store.setSecret(VALUE);
    expect(await store.save()).toBe(true);
    store.retainAcrossRouteReplacement();
    await store.open(store.createdId());
    // Mutation (Rule 19): drop `if (arriving) this.savedValue = true` from `open()` -> `saved()` reads
    // false and this goes red.
    expect([store.mode(), store.saved(), store.retaining(), store.secretText(), store.stored()]).toEqual([
      'edit',
      true,
      false,
      '',
      true,
    ]);
  });

  it('AD-39: a create opened without a collection says why it cannot save, in the server\'s sentence', async () => {
    const { store } = mount();
    await store.open('');
    expect(store.absent()).toBe(true);
    expect(store.reason()).toBe('This instance has no wallet collection with that name.');
    expect(store.canSave()).toBe(false);
  });

  it('AD-4: an edit sends only the setting it changed, no value unless one was entered, and publishes updated', async () => {
    const { store, calls, events } = mount({ kind: 'ok', status: 200, body: { name: 'Probe.Kv' } });
    await store.open('Probe.Kv');
    expect(store.mode()).toBe('edit');
    expect([store.collection(), store.value('Name'), store.usage(), store.requireTls(), store.value('AllowedHosts')]).toEqual([
      'Probe',
      'Kv',
      5,
      false,
      'h',
    ]);
    expect(store.stored()).toBe(true);
    expect(store.secretText()).toBe('');
    // The name is not an edit's to change.
    store.setValue('Name', 'Other');
    expect(store.value('Name')).toBe('Kv');

    store.setUsageBit(2, true);
    expect(await store.save()).toBe(true);
    const [write] = writes(calls);
    expect(write?.path).toBe(`${WALLET_SECRET_PATH}/${encodeEntityId('Probe.Kv')}`);
    expect(write?.method).toBe('PUT');
    expect(JSON.parse(write!.body)).toEqual({ Usage: 7 });
    expect(events.map((event) => `${event.type}:${event.id}:${event.action}`)).toEqual(['wallet-secret:Probe.Kv:updated']);

    store.setSecret('a new value');
    expect(await store.save()).toBe(true);
    expect(JSON.parse(writes(calls)[1]!.body)).toEqual({ Secret: 'a new value' });
    expect(store.secretText()).toBe('');
  });

  it('AD-4: an edit saved with nothing changed writes and publishes nothing', async () => {
    const { store, calls, events } = mount();
    await store.open('Probe.Kv');
    store.setValue('AllowedHosts', 'h, ');
    expect(await store.save()).toBe(true);
    expect(writes(calls)).toEqual([]);
    expect(events).toEqual([]);
  });

  it('a secret of another type opens read-only and cannot save; an absent one cannot save either', async () => {
    const other = mount(undefined, { kind: 'ok', status: 200, body: { ...RULES, secret: SYMMETRIC } });
    await other.store.open('Probe.Sym');
    expect(other.store.readOnly()).toBe(true);
    expect(other.store.secret().type).toBe('%Wallet.SymmetricKey');
    other.store.setUsageBit(1, false);
    other.store.setSecret(VALUE);
    expect(other.store.secretText()).toBe('');
    expect(other.store.canSave()).toBe(false);
    expect(await other.store.save()).toBe(false);
    expect(writes(other.calls)).toEqual([]);

    const absent = mount(undefined, { kind: 'error', status: 404, code: 'WALLET.NAME.ABSENT', reason: 'No such secret.', detail: null });
    await absent.store.open('Probe.Gone');
    expect(absent.store.absent()).toBe(true);
    expect(absent.store.canSave()).toBe(false);
  });

  it('AD-39: a taken name is marked on blur with the server\'s own sentence, and an empty required field with its rule', async () => {
    const { store, calls } = mount();
    await store.open('', 'Probe');
    await store.onBlur('Secret');
    expect(store.violationFor('Secret')).toBe('Enter the value to store.');
    store.setValue('Name', 'Taken');
    await store.onBlur('Name');
    expect(calls.some((call) => call.path === `${WALLET_SECRET_NAME_PATH}?name=${encodeURIComponent('Probe.Taken')}`)).toBe(true);
    expect(store.violations().find((entry) => entry.field === 'Name')).toEqual({
      field: 'Name',
      code: NAME_TAKEN_CODE,
      reason: TAKEN_SENTENCE,
    });
  });

  it('AD-39: a name the blur look-up refuses on a rule is marked with the server\'s sentence', async () => {
    const shape = { field: 'Name', code: 'WALLET.NAME.SHAPE', reason: 'A secret\'s name uses only letters, digits, dots, hyphens and underscores.' };
    const { store } = mount(undefined, undefined, {
      kind: 'error',
      status: 422,
      code: 'WALLET.VALIDATION',
      reason: 'The secret was refused.',
      detail: { violations: [shape] },
    });
    await store.open('', 'Probe');
    store.setValue('Name', 'has space');
    await store.onBlur('Name');
    expect(store.violations().filter((entry) => entry.field === 'Name')).toEqual([shape]);
  });

  it('the hosts are typed comma-separated and sent as an array, each entry trimmed and empties dropped', () => {
    expect(splitHosts(' a ,, b,')).toEqual(['a', 'b']);
    expect(splitHosts('')).toEqual([]);
  });
});

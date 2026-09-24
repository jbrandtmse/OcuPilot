import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { entityRefKey } from '../../core/entity-ref';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { SCREENS } from '../../core/screens.generated';
import { ALIAS_TAKEN_CODE, X509_FORM_PATH, X509_NAME_PATH, X509_PATH, X509Form, splitList } from './x509-form.store';

/**
 * The X.509 credential form's store (AC2, AC3, AC4, AD-4, AD-14, AD-35, AD-39, AD-55).
 *
 * It pins what no browser leg can falsify: the change event a Save publishes, the import's one body,
 * the three secrets held apart and emptied by an accepted Save, by `reset()` and across the route
 * replacement, an edit sending only the lists it changed after its fresh read, and a server refusal
 * landing on the field it names. The bus is real and only the server's answers are stubbed. The PEM
 * text below is a placeholder the stubbed server never parses.
 */

const RULES = {
  requiredFields: ['Alias', 'Certificate'],
  maxLengths: { Alias: 150, PrivateKeyPassword: 128 },
  rules: [
    { field: 'Alias', code: 'X509.ALIAS.REQUIRED', reason: 'Give the credential an alias.' },
    { field: 'Certificate', code: 'X509.CERTIFICATE.REQUIRED', reason: 'Paste or load the certificate.' },
  ],
};

const CREDENTIAL = {
  Alias: 'ProbeCredential',
  OwnerList: ['alice'],
  PeerNames: ['peer.example'],
  CAFile: '/x.cer',
  SubjectDN: 'CN=Probe',
  IssuerDN: 'CN=Probe CA',
  SerialNumber: '4F1A09C2',
  ValidityNotBefore: '2026-01-01 00:00:00',
  ValidityNotAfter: '2126-01-01 00:00:00',
  HasPrivateKey: true,
};

const CERT = '-----BEGIN CERTIFICATE-----\nplaceholder\n-----END CERTIFICATE-----';

const KEY = 'placeholder key text';

const PASSWORD = 'placeholder password';

const TAKEN_SENTENCE = 'This instance already holds an X.509 credential with that alias.';

async function settle(): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
}

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: string;
}

function mount(
  saveAnswer: JsonResult<unknown> = { kind: 'ok', status: 201, body: { alias: 'ProbeCredential' } },
  editRead: JsonResult<unknown> = { kind: 'ok', status: 200, body: { ...RULES, credential: CREDENTIAL } }
) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      if (path === X509_FORM_PATH) return { kind: 'ok', status: 200, body: RULES } as unknown as JsonResult<T>;
      if (path.startsWith(`${X509_FORM_PATH}?`)) return editRead as JsonResult<T>;
      if (path.startsWith(X509_NAME_PATH)) {
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
  return { store: TestBed.inject(X509Form), calls, events, formDirty };
}

function writes(calls: readonly Call[]): Call[] {
  return calls.filter((call) => call.method !== 'GET');
}

function fillImport(store: X509Form): void {
  store.setValue('Alias', 'ProbeCredential');
  store.setCertificate(CERT);
  store.setPrivateKey(KEY);
  store.setPassword(PASSWORD);
  store.setValue('OwnerList', 'alice, bob,');
  store.setValue('PeerNames', 'peer.example');
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the X.509 credential form store', () => {
  it('AC2, AD-14: an import posts one body, publishes one created event, and empties every secret', async () => {
    const { store, calls, events, formDirty } = mount();
    await store.open('');
    expect(store.mode()).toBe('create');
    fillImport(store);
    expect(formDirty.dirty()).toBe(true);
    expect(await store.save()).toBe(true);
    await settle();

    const [write] = writes(calls);
    expect(write?.path).toBe(X509_PATH);
    expect(write?.method).toBe('POST');
    expect(JSON.parse(write!.body)).toEqual({
      Alias: 'ProbeCredential',
      Certificate: CERT,
      PrivateKey: KEY,
      PrivateKeyPassword: PASSWORD,
      OwnerList: ['alice', 'bob'],
      PeerNames: ['peer.example'],
    });
    // Mutation (Rule 19): drop the `publish` call from `save()` -> this goes red, and an open X.509
    // list never re-fetches the credential the form imported (AC2).
    expect(events).toEqual([
      {
        kind: 'changed',
        type: 'x509-credential',
        scope: 'instance',
        id: 'ProbeCredential',
        key: entityRefKey('x509-credential', 'instance', 'ProbeCredential'),
        action: 'created',
        proposalId: '',
        expiresAt: 0,
      },
    ]);
    // The type is the X.509 list's own declared entity type, which is what that list listens for.
    expect(SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.X509CredentialList')?.entityType).toBe(
      'x509-credential'
    );
    // AC3: the masked fields are empty after the Save.
    expect([store.certificate(), store.privateKey(), store.password()]).toEqual(['', '', '']);
    expect(store.createdId()).toBe('ProbeCredential');
    expect(store.saved()).toBe(true);
    expect(formDirty.dirty()).toBe(false);
  });

  it('AD-35: a refused import keeps what was entered for correction, and remembers no secret as the refused value', async () => {
    const refusal: JsonResult<unknown> = {
      kind: 'error',
      status: 422,
      code: 'X509.VALIDATION',
      reason: 'The credential was refused',
      detail: { violations: [{ field: 'PrivateKey', code: 'X509.PRIVATEKEY.MISMATCH', reason: 'The key does not match.' }] },
    };
    const { store, events } = mount(refusal);
    await store.open('');
    fillImport(store);
    expect(await store.save()).toBe(false);
    expect(store.violationFor('PrivateKey')).toBe('The key does not match.');
    expect(store.privateKey()).toBe(KEY);
    expect(events).toEqual([]);

    // Leaving the form forgets the secrets, so a return to it never finds them pre-filled.
    store.reset();
    expect([store.certificate(), store.privateKey(), store.password()]).toEqual(['', '', '']);
  });

  it('AC3: the route replacement carries the form across, less its secrets', async () => {
    const { store } = mount();
    await store.open('');
    fillImport(store);
    store.retainAcrossRouteReplacement();
    expect(store.retaining()).toBe(true);
    expect([store.certificate(), store.privateKey(), store.password()]).toEqual(['', '', '']);
  });

  it('AC4, AD-4: an edit sends only the list it changed after its fresh read, and publishes updated', async () => {
    const { store, calls, events } = mount({ kind: 'ok', status: 200, body: { alias: 'ProbeCredential' } });
    await store.open('ProbeCredential');
    expect(store.mode()).toBe('edit');
    expect(store.value('OwnerList')).toBe('alice');
    expect(store.credential().caFile).toBe('/x.cer');
    expect(store.credential().hasPrivateKey).toBe(true);
    // Story 12.1: the certificate's subject, issuer and serial number are mapped from the form read,
    // each from its own field (the fixture's two DNs differ).
    expect(store.credential().subject).toBe('CN=Probe');
    expect(store.credential().issuer).toBe('CN=Probe CA');
    expect(store.credential().serialNumber).toBe('4F1A09C2');
    // An edit takes no secret: the setters refuse it.
    store.setCertificate(CERT);
    store.setPrivateKey(KEY);
    store.setPassword(PASSWORD);
    expect([store.certificate(), store.privateKey(), store.password()]).toEqual(['', '', '']);

    store.setValue('OwnerList', 'alice, carol');
    expect(await store.save()).toBe(true);
    const [write] = writes(calls);
    expect(write?.path).toBe(`${X509_PATH}/${encodeEntityId('ProbeCredential')}`);
    expect(write?.method).toBe('PUT');
    expect(JSON.parse(write!.body)).toEqual({ OwnerList: ['alice', 'carol'] });
    expect(events.map((event) => `${event.type}:${event.id}:${event.action}`)).toEqual(['x509-credential:ProbeCredential:updated']);
  });

  it('AD-4: an edit saved with nothing changed writes and publishes nothing', async () => {
    const { store, calls, events } = mount();
    await store.open('ProbeCredential');
    store.setValue('PeerNames', 'peer.example, ');
    expect(await store.save()).toBe(true);
    expect(writes(calls)).toEqual([]);
    expect(events).toEqual([]);
  });

  it('an edit of an alias the instance does not hold cannot save, and neither can one whose read failed', async () => {
    const absent = mount(undefined, { kind: 'error', status: 404, code: 'X509.ALIAS.ABSENT', reason: 'No such credential.', detail: null });
    await absent.store.open('Gone');
    expect(absent.store.absent()).toBe(true);
    expect(absent.store.canSave()).toBe(false);
    expect(await absent.store.save()).toBe(false);
    expect(writes(absent.calls)).toEqual([]);

    const failed = mount(undefined, { kind: 'error', status: 500, code: 'PORT.FAILED', reason: 'The read failed.', detail: null });
    await failed.store.open('ProbeCredential');
    expect(failed.store.editable()).toBe(false);
    failed.store.setValue('OwnerList', 'mallory');
    expect(failed.store.value('OwnerList')).toBe('');
    expect(failed.store.canSave()).toBe(false);
  });

  it('AD-39: a taken alias is marked on blur with the server\'s own sentence, and an empty required field with its rule', async () => {
    const { store } = mount();
    await store.open('');
    await store.onBlur('Certificate');
    expect(store.violationFor('Certificate')).toBe('Paste or load the certificate.');
    store.setValue('Alias', 'Taken');
    await store.onBlur('Alias');
    expect(store.violations().find((entry) => entry.field === 'Alias')).toEqual({
      field: 'Alias',
      code: ALIAS_TAKEN_CODE,
      reason: TAKEN_SENTENCE,
    });
  });

  it('a list is typed comma-separated and sent as an array, each entry trimmed and empties dropped', () => {
    expect(splitList(' a ,, b,')).toEqual(['a', 'b']);
    expect(splitList('')).toEqual([]);
  });
});

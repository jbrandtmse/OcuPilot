import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { NAME_TAKEN_CODE, OS_STORE, SSL_FORM_PATH, SSL_NAME_PATH, SSL_PATH, SslForm, listEntries } from './ssl-form.store';

/**
 * The SSL/TLS configuration form's store (AC2, AC3, AC4, AC5, AD-4, AD-14, AD-35, AD-39, AD-55).
 *
 * It pins what no browser leg can falsify: a create sending the complete set from the form read's
 * defaults, an edit sending only what changed, the password held apart and emptied by an accepted
 * Save and by `reset()`, OcuPilot's own configuration refusing input to its four installer-owned
 * fields, one change event per Save, and Test connection's lines kept as the instance answered
 * them. The bus is real and only the server's answers are stubbed.
 */

const DEFAULTS = {
  Description: '',
  Enabled: true,
  Type: 0,
  VerifyPeer: 0,
  VerifyDepth: 9,
  CAFile: '',
  TLSMinVersion: 16,
  TLSMaxVersion: 32,
  DiffieHellmanBits: 0,
  OCSP: 0,
  OCSPTimeout: 2,
  CipherList: ['ALL', '!aNULL'],
  Ciphersuites: ['TLS_AES_256_GCM_SHA384'],
};

const RULES = {
  requiredFields: ['Name', 'Type', 'VerifyPeer', 'Enabled'],
  maxLengths: { Name: 64, Description: 256, PrivateKeyPassword: 255, Host: 255 },
  rules: [{ field: 'Name', code: 'SSL.NAME.REQUIRED', reason: 'Give the configuration a name.' }],
  defaults: DEFAULTS,
};

const CONFIGURATION = {
  ...DEFAULTS,
  Description: 'probe',
  VerifyPeer: 1,
  CAFile: OS_STORE,
  AuthorizeCN: false,
  CAPath: '',
  CertificateFile: '/probe/cert.pem',
  PrivateKeyFile: '/probe/key.pem',
  PrivateKeyType: 2,
  OCSPIssuerCert: '',
  OCSPResponseFile: '',
  OCSPURL: '',
};

const PASSWORD = 'placeholder password';

async function settle(): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) await new Promise((resolve) => setTimeout(resolve, 2));
}

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: string;
}

function mount(
  options: {
    save?: JsonResult<unknown>;
    edit?: JsonResult<unknown>;
    ocupilot?: boolean;
    test?: JsonResult<unknown>;
  } = {}
) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const edit: JsonResult<unknown> = options.edit ?? {
    kind: 'ok',
    status: 200,
    body: { ...RULES, name: 'ProbeSsl', configuration: CONFIGURATION, ocupilot: options.ocupilot ?? false },
  };
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      if (path === SSL_FORM_PATH) return { kind: 'ok', status: 200, body: RULES } as unknown as JsonResult<T>;
      if (path.startsWith(`${SSL_FORM_PATH}?`)) return edit as JsonResult<T>;
      if (path.startsWith(SSL_NAME_PATH)) {
        return { kind: 'ok', status: 200, body: { taken: true, reason: 'taken sentence' } } as unknown as JsonResult<T>;
      }
      if (path.endsWith('/test')) {
        return (options.test ?? { kind: 'ok', status: 200, body: { passed: false, lines: ['ERROR 988: wrong version number'] } }) as JsonResult<T>;
      }
      return (options.save ?? { kind: 'ok', status: 201, body: { name: 'ProbeSsl' } }) as JsonResult<T>;
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
  return { store: TestBed.inject(SslForm), calls, events, formDirty };
}

/** Answer every later form read with the configuration moved by another caller. */
function moveTheConfiguration(): void {
  const api = TestBed.inject(ApiService) as unknown as { requestJson: () => Promise<JsonResult<unknown>> };
  const moved = { ...CONFIGURATION, Description: 'moved', CertificateFile: '/probe/moved.pem' };
  api.requestJson = async () => ({ kind: 'ok', status: 200, body: { ...RULES, name: 'ProbeSsl', configuration: moved, ocupilot: false } }) as JsonResult<unknown>;
}

function writes(calls: readonly Call[]): Call[] {
  return calls.filter((call) => call.method !== 'GET');
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the SSL/TLS configuration form store', () => {
  it('AC5, AD-54: a create posts the name and the complete set from the defaults, and publishes one created event', async () => {
    // Mutation (Rule 19): drop a setting from `createBody` -> the key-set assertion goes red.
    const { store, calls, events } = mount();
    await store.open('');
    expect(store.mode()).toBe('create');
    expect(store.text('TLSMinVersion')).toBe('16');
    expect(store.text('CipherList')).toBe('ALL\n!aNULL');
    store.setName('ProbeSsl');
    store.setText('VerifyPeer', '1');
    store.setText('CAFile', OS_STORE);
    expect(await store.save()).toBe(true);
    await settle();

    const [write] = writes(calls);
    expect(write?.path).toBe(SSL_PATH);
    expect(write?.method).toBe('POST');
    const body = JSON.parse(write?.body ?? '{}') as Record<string, unknown>;
    expect(Object.keys(body).sort()).toEqual(['Name', ...Object.keys(DEFAULTS)].sort());
    expect(body['Name']).toBe('ProbeSsl');
    expect(body['VerifyPeer']).toBe(1);
    expect(body['CAFile']).toBe(OS_STORE);
    expect(body['Enabled']).toBe(true);
    expect(body['OCSP']).toBe(0);
    expect(body['CipherList']).toEqual(['ALL', '!aNULL']);
    expect(body).not.toHaveProperty('PrivateKeyPassword');
    expect(store.createdId()).toBe('ProbeSsl');
    expect(store.saved()).toBe(true);
    expect(events.filter((event) => event.kind === 'changed')).toHaveLength(1);
    expect(events[0]).toMatchObject({ type: 'ssl-configuration', scope: 'instance', id: 'ProbeSsl', action: 'created' });
  });

  it('AD-4: an edit puts only the settings changed since its read, and one updated event', async () => {
    // Mutation (Rule 19): send the whole buffer from `changedFields` -> the two-key assertion goes red.
    const { store, calls, events } = mount({ save: { kind: 'ok', status: 200, body: { name: 'ProbeSsl' } } });
    await store.open('ProbeSsl');
    expect(store.mode()).toBe('edit');
    expect(store.text('Description')).toBe('probe');
    store.setText('Description', 'changed');
    store.setText('TLSMinVersion', '8');
    expect(await store.save()).toBe(true);
    await settle();
    const [write] = writes(calls);
    expect(write?.path).toBe(`${SSL_PATH}/${encodeEntityId('ProbeSsl')}`);
    expect(write?.method).toBe('PUT');
    expect(JSON.parse(write?.body ?? '{}')).toEqual({ Description: 'changed', TLSMinVersion: 8 });
    expect(events.filter((event) => event.kind === 'changed')).toEqual([
      expect.objectContaining({ type: 'ssl-configuration', id: 'ProbeSsl', action: 'updated' }),
    ]);
  });

  it('an edit that changed nothing writes nothing and reads Saved', async () => {
    const { store, calls } = mount();
    await store.open('ProbeSsl');
    expect(await store.save()).toBe(true);
    expect(writes(calls)).toHaveLength(0);
    expect(store.saved()).toBe(true);
  });

  it('AC2, AD-35: the password is sent only when entered, never pre-filled, and emptied by an accepted Save and by reset', async () => {
    // Mutation (Rule 19): keep `passwordValue` after an accepted Save -> the emptied assertion goes red.
    const { store, calls } = mount({ save: { kind: 'ok', status: 200, body: { name: 'ProbeSsl' } } });
    await store.open('ProbeSsl');
    expect(store.password()).toBe('');
    store.setPassword(PASSWORD);
    expect(await store.save()).toBe(true);
    const [write] = writes(calls);
    expect(JSON.parse(write?.body ?? '{}')).toEqual({ PrivateKeyPassword: PASSWORD });
    expect(store.password()).toBe('');
    store.setPassword(PASSWORD);
    store.reset();
    expect(store.password()).toBe('');
  });

  it('a refused Save keeps the password and lands each violation on its field', async () => {
    const { store } = mount({
      save: {
        kind: 'error',
        status: 422,
        code: 'SSL.VALIDATION',
        reason: 'refused',
        detail: { violations: [{ field: 'PrivateKeyPassword', code: 'SSL.PRIVATEKEYPASSWORD.WRONG', reason: 'wrong' }] },
      },
    });
    await store.open('ProbeSsl');
    store.setPassword(PASSWORD);
    expect(await store.save()).toBe(false);
    expect(store.violationFor('PrivateKeyPassword')).toBe('wrong');
    expect(store.password()).toBe(PASSWORD);
    expect(store.reason()).toBe('');
  });

  it("AC3, AD-10: OcuPilot's own configuration refuses input to its four installer-owned fields and keeps the rest", async () => {
    // Mutation (Rule 19): answer false from `lockedField` -> the refused-input assertions go red.
    const { store } = mount({ ocupilot: true });
    await store.open('ProbeSsl');
    expect(store.ocupilot()).toBe(true);
    // Each value differs from the one held, so a refused input is the lock and not `setText`'s no-op.
    for (const [field, value] of [
      ['Type', '1'],
      ['VerifyPeer', '0'],
      ['CAFile', ''],
    ]) {
      expect(store.lockedField(field)).toBe(true);
      const before = store.text(field);
      expect(before).not.toBe(value);
      store.setText(field, value);
      expect(store.text(field)).toBe(before);
    }
    store.setFlag('Enabled', false);
    expect(store.flag('Enabled')).toBe(true);
    store.setText('Description', 'allowed');
    expect(store.text('Description')).toBe('allowed');
  });

  it('a form read for a configuration the instance does not hold marks it absent and blocks Save', async () => {
    const { store } = mount({
      edit: { kind: 'error', status: 404, code: 'SSL.NAME.ABSENT', reason: 'This instance has no SSL/TLS configuration with that name.', detail: null },
    });
    await store.open('Gone');
    expect(store.absent()).toBe(true);
    expect(store.canSave()).toBe(false);
    expect(store.reason()).toBe('This instance has no SSL/TLS configuration with that name.');
  });

  it("AC4, AD-39: Test connection posts the host and a numeric port and keeps the instance's own lines", async () => {
    // Mutation (Rule 19): drop `lines` from `test` -> the lines assertion goes red.
    const { store, calls } = mount();
    await store.open('ProbeSsl');
    store.setHost('localhost');
    store.setPort('52773');
    await store.test();
    const test = calls.find((call) => call.path.endsWith('/test'));
    expect(test?.path).toBe(`${SSL_PATH}/${encodeEntityId('ProbeSsl')}/test`);
    expect(JSON.parse(test?.body ?? '{}')).toEqual({ Host: 'localhost', Port: 52773 });
    expect(store.testResult()).toEqual({ passed: false, lines: ['ERROR 988: wrong version number'] });
  });

  it('a refused Test lands its violations on the host and port, apart from the Save summary', async () => {
    const { store } = mount({
      test: {
        kind: 'error',
        status: 422,
        code: 'SSL.VALIDATION',
        reason: 'refused',
        detail: { violations: [{ field: 'Port', code: 'SSL.TEST.PORT', reason: 'port sentence' }] },
      },
    });
    await store.open('ProbeSsl');
    await store.test();
    expect(store.testViolationFor('Port')).toBe('port sentence');
    expect(store.violations()).toEqual([]);
    expect(store.testResult()).toBeNull();
  });

  it('the name look-up on blur marks a taken name with the server sentence', async () => {
    const { store } = mount();
    await store.open('');
    store.setName('Taken');
    await store.onBlur('Name');
    expect(store.violations()).toEqual([{ field: 'Name', code: NAME_TAKEN_CODE, reason: 'taken sentence' }]);
  });

  it('AD-14: a refresh of a clean form re-reads the configuration in place', async () => {
    // Mutation (Rule 19): absorb a refresh's read with `replaceBuffer` false -> the moved-description assertion goes red.
    const { store, formDirty } = mount();
    await store.open('ProbeSsl');
    moveTheConfiguration();
    await store.refresh();
    expect(store.text('Description')).toBe('moved');
    expect(store.shown('CertificateFile')).toBe('/probe/moved.pem');
    expect(formDirty.dirty()).toBe(false);
  });

  it('AD-14: a refresh of a dirty form keeps what was typed and takes the read-only fields from the new read', async () => {
    // Mutation (Rule 19): absorb a refresh's read with `replaceBuffer` true -> the kept-description assertion goes red.
    const { store, formDirty } = mount();
    await store.open('ProbeSsl');
    store.setText('Description', 'typed');
    moveTheConfiguration();
    await store.refresh();
    expect(store.text('Description')).toBe('typed');
    expect(store.shown('CertificateFile')).toBe('/probe/moved.pem');
    expect(formDirty.dirty()).toBe(true);
  });

  it('listEntries reads one entry per line, trimmed, empty lines dropped', () => {
    expect(listEntries(' ALL \n\n!aNULL\n')).toEqual(['ALL', '!aNULL']);
  });
});

import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import {
  ENCRYPTION_STARTUP_ENTITY,
  ENCRYPTION_STARTUP_FORM_PATH,
  ENCRYPTION_STARTUP_PATH,
  EncryptionStartupForm,
  MODE_FIELD,
  STARTUP_INTERACTIVE_CODE,
} from './encryption-startup.store';

/**
 * Encryption startup settings' store (Story 18.23, AD-4, AD-10, AD-14, AD-35, AD-36, AD-55): the screen's own
 * declared read beside Database encryption's and the form read; a Save sending only the changed settings and
 * a new Unattended key file's location, administrator and password; the choices the server would refuse,
 * Decision 8's in both orders; and the server's Interactive refusal on the start mode. The bus is real and
 * only the server's answers are stubbed.
 */

const STOCK = {
  DBEncStartMode: 'Unattended',
  DBEncJournal: false,
  DBEncIRISSecurity: false,
  DBEncIRISTemp: false,
  AuditEncrypt: false,
  DBEncStartKMIPServer: '',
  DBEncStartKeyFile: '/k/start.key',
  DBEncDefaultKeyID: 'K1',
  DBEncJournalKeyID: 'K1',
};

const ACCEPTED: JsonResult<unknown> = { kind: 'ok', status: 200, body: { readBack: { verdict: 'matches', fields: [], written: [] } } };

interface Call {
  readonly path: string;
  readonly method: string;
  readonly body: string;
}

function mount(options: { row?: Record<string, unknown>; kmip?: readonly string[]; encrypted?: readonly string[]; keys?: readonly unknown[]; save?: JsonResult<unknown> } = {}) {
  TestBed.resetTestingModule();
  const calls: Call[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      calls.push({ path, method, body: init.body ?? '' });
      if (path.startsWith('/api/ocupilot/screens/security.encryptionstartup/read')) {
        return { kind: 'ok', status: 200, body: { rows: [{ ...STOCK, ...(options.row ?? {}) }], truncated: false } } as unknown as JsonResult<T>;
      }
      if (path.startsWith('/api/ocupilot/screens/security.databaseencryption/read')) {
        return { kind: 'ok', status: 200, body: { rows: options.keys ?? [{ Id: 'K1', KeyLen: 256, IsDefault: true }, { Id: 'K2', KeyLen: 256, IsDefault: false }], truncated: false } } as unknown as JsonResult<T>;
      }
      if (path === ENCRYPTION_STARTUP_FORM_PATH) {
        return { kind: 'ok', status: 200, body: { kmipServers: options.kmip ?? [], encryptedDatabases: options.encrypted ?? [] } } as unknown as JsonResult<T>;
      }
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
  return { store: TestBed.inject(EncryptionStartupForm), calls, events, formDirty };
}

function puts(calls: readonly Call[]): readonly unknown[] {
  return calls.filter((call) => call.method === 'PUT').map((call) => JSON.parse(call.body));
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the encryption startup settings store', () => {
  it("C1, AD-36: opens over the screen's own declared read, Database encryption's read and the form read", async () => {
    const { store, calls } = mount({ kmip: ['kms1'] });
    await store.open();
    expect(calls.map((call) => call.path).sort()).toEqual([
      '/api/ocupilot/encryption-startup/form',
      '/api/ocupilot/screens/security.databaseencryption/read?maxRows=300',
      '/api/ocupilot/screens/security.encryptionstartup/read?maxRows=1',
    ]);
    expect([store.mode(), store.storedKeyFile(), store.defaultKey(), store.journalKey()]).toEqual(['Unattended', '/k/start.key', 'K1', 'K1']);
    expect(store.kmipServers()).toEqual(['kms1']);
    expect(store.activeKeys()).toEqual(['K1', 'K2']);
    expect(store.saveBody()).toEqual({});
  });

  it('C3: a Save sends only what changed, a key id only when it moved, and publishes one change event', async () => {
    const { store, calls, events, formDirty } = mount();
    await store.open();
    store.setFlag('DBEncJournal', true);
    store.setJournalKey('K2');
    expect(formDirty.dirty()).toBe(true);
    expect(await store.save()).toBe(true);
    // Mutation (Rule 19): send both key ids from `saveBody` whatever changed -> this goes red.
    expect(puts(calls)).toEqual([{ DBEncJournal: true, DBEncJournalKeyID: 'K2' }]);
    expect(events.filter((event) => event.kind === 'changed').map((event) => (event.kind === 'changed' ? `${event.type}:${event.action}` : ''))).toEqual([`${ENCRYPTION_STARTUP_ENTITY}:updated`]);
    expect(formDirty.dirty()).toBe(false);
  });

  it('a Save that changes nothing sends nothing and reads saved', async () => {
    const { store, calls } = mount();
    await store.open();
    expect(await store.save()).toBe(true);
    expect(puts(calls)).toEqual([]);
    expect(store.saved()).toBe(true);
  });

  it('AD-35: a new Unattended key file sends its location, administrator and the password handed to save, and the store keeps no password', async () => {
    const { store, calls } = mount({ row: { DBEncStartMode: 'None', DBEncStartKeyFile: '' } });
    await store.open();
    store.setMode('Unattended');
    store.setLocation('/probe/root/', '');
    expect(store.newKeyFile()).toBe(false);
    store.setLocation('/probe/root/', 'keys/start.key');
    store.setAdminName('probeuser');
    expect(store.newKeyFile()).toBe(true);
    expect(store.saveBody()).toEqual({ DBEncStartMode: 'Unattended', root: '/probe/root/', path: 'keys/start.key', AdminName: 'probeuser' });
    await store.save('OCUPROBESTARTSTOREMARKER');
    expect(puts(calls)).toEqual([{ DBEncStartMode: 'Unattended', root: '/probe/root/', path: 'keys/start.key', AdminName: 'probeuser', AdminPassword: 'OCUPROBESTARTSTOREMARKER' }]);
    // Every field the store holds after the Save, its collaborators aside; the read-back it keeps shows the
    // scan reads real state. Mutation (Rule 19): keep the password in a store field in `save` -> this goes red.
    const held = Object.entries(store as unknown as Record<string, unknown>)
      .filter(([key]) => !['injector', 'formDirty', 'listeners'].includes(key))
      .map(([, value]) => JSON.stringify(value) ?? '')
      .join('|');
    expect(held).toContain('matches');
    expect(held).not.toContain('OCUPROBESTARTSTOREMARKER');
  });

  for (const flag of ['AuditEncrypt', 'DBEncIRISSecurity', 'DBEncIRISTemp'] as const) {
    it(`Decision 8: ${flag} encrypted refuses Interactive, and Interactive refuses ${flag}`, async () => {
      const { store } = mount({ row: { [flag]: true } });
      await store.open();
      expect(store.modeRefusal('Interactive')).toBe('interactive');
      store.setMode('Interactive');
      expect(store.mode()).toBe('Unattended');
      const second = mount({ row: { DBEncStartMode: 'Interactive' } });
      await second.store.open();
      expect(second.store.flagRefusal(flag)).toBe('interactive');
      second.store.setFlag(flag, true);
      expect(second.store.flag(flag)).toBe(false);
    });
  }

  it('turning an encryption setting off is never refused, and Interactive is offered only once the instance holds none that requires a start', async () => {
    const { store } = mount({ row: { AuditEncrypt: true } });
    await store.open();
    expect(store.flagRefusal('AuditEncrypt')).toBe('');
    store.setFlag('AuditEncrypt', false);
    expect(store.auditChanged()).toBe(true);
    // Mutation (Rule 19): judge Interactive on the form's flags alone in `modeRefusal` -> this goes red.
    expect(store.modeRefusal('Interactive')).toBe('interactive');
    const off = mount({ row: { AuditEncrypt: false } });
    await off.store.open();
    expect(off.store.modeRefusal('Interactive')).toBe('');
    const under = mount({ row: { DBEncStartMode: 'Interactive', AuditEncrypt: true } });
    await under.store.open();
    under.store.setFlag('AuditEncrypt', false);
    expect(under.store.flag('AuditEncrypt')).toBe(false);
  });

  it('AD-10: a database still encrypted on disk refuses Interactive with every setting off, and none encrypted offers it', async () => {
    const { store } = mount({ encrypted: ['IRISAUDIT'] });
    await store.open();
    expect(store.encryptedDatabases()).toEqual(['IRISAUDIT']);
    // Mutation (Rule 19): drop the on-disk check from `modeRefusal` -> Interactive is offered and this goes red.
    expect(store.modeRefusal('Interactive')).toBe('interactive');
    store.setMode('Interactive');
    expect(store.mode()).toBe('Unattended');
    expect(store.modeRefusal('None')).toBe('');
    const clear = mount({ encrypted: [] });
    await clear.store.open();
    expect(clear.store.modeRefusal('Interactive')).toBe('');
    store.reset();
    expect(store.encryptedDatabases()).toEqual([]);
  });

  it('refuses KMIP with no server configured, a setting under None, and every key with none active', async () => {
    const none = mount({ row: { DBEncStartMode: 'None' }, keys: [] });
    await none.store.open();
    expect(none.store.modeRefusal('KMIP')).toBe('kmip');
    expect(none.store.flagRefusal('DBEncJournal')).toBe('needs-start');
    expect(none.store.keyRefusal()).toBe('no-keys');
    const nokey = mount({ keys: [] });
    await nokey.store.open();
    expect(nokey.store.flagRefusal('DBEncIRISTemp')).toBe('no-key');
  });

  it("AD-10: the server's Interactive refusal is drawn on the start mode, with no envelope line", async () => {
    const sentence = 'SERVER-INTERACTIVE-SENTENCE';
    const { store } = mount({ save: { kind: 'error', status: 403, code: STARTUP_INTERACTIVE_CODE, reason: sentence, detail: null } });
    await store.open();
    store.setMode('Interactive');
    expect(await store.save()).toBe(false);
    // Mutation (Rule 19): drop the Interactive mapping from `save` -> the sentence is the envelope's and this goes red.
    expect(store.violationFor(MODE_FIELD)).toBe(sentence);
    expect(store.reason()).toBe('');
    expect(store.mode()).toBe('Interactive');
  });

  it('a refused Save keeps what was entered and names the refusal; the Save path is PUT /encryption-startup', async () => {
    const { store, calls } = mount({ save: { kind: 'error', status: 409, code: 'ENCRYPTION.STARTUP.REQUIRED', reason: 'REQUIRED-SENTENCE', detail: null } });
    await store.open();
    store.setMode('None');
    expect(await store.save()).toBe(false);
    expect(calls.find((call) => call.method === 'PUT')?.path).toBe(ENCRYPTION_STARTUP_PATH);
    expect(store.reason()).toBe('REQUIRED-SENTENCE');
    expect(store.mode()).toBe('None');
  });
});

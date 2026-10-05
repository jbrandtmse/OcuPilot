import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeEvent } from '../../core/change-bus';
import { joinCompositeId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { STRINGS } from '../../core/strings';
import { ENCRYPTION_KEY_FILE_PATH, EncryptionKeyFileForm } from './encryption-key-file-form.store';

/**
 * The encryption key file create form's store (Story 18.7) over a stub of the Save: the body it posts,
 * the password it is handed and never keeps, the change event an accepted Save publishes and a refusal
 * kept on its field.
 */

function mount(answer: () => JsonResult<unknown>) {
  TestBed.resetTestingModule();
  const sent: { path: string; body: unknown }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init?: ApiRequestInit): Promise<JsonResult<T>> => {
      sent.push({ path, body: typeof init?.body === 'string' ? JSON.parse(init.body) : null });
      return answer() as JsonResult<T>;
    },
  };
  const bus = new ChangeBus();
  const events: ChangeEvent[] = [];
  bus.subscribe((event) => events.push(event));
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: FormDirty, useValue: new FormDirty() },
      { provide: ChangeBus, useValue: bus },
    ],
  });
  return { store: TestBed.inject(EncryptionKeyFileForm), sent, events };
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('EncryptionKeyFileForm', () => {
  it('posts the location, the administrator, the password it is handed, the key length and the description', async () => {
    const { store, sent, events } = mount(() => ({ kind: 'ok', status: 201, body: { keyId: 'NEWKEY1', readBack: { verdict: 'written' } } }));
    store.open('ADMINUSER');
    expect(store.value('AdminName')).toBe('ADMINUSER');
    expect(store.value('KeyLen')).toBe('256');
    store.setValue('root', '/probe/root/');
    store.setValue('path', 'keys/new.key');
    store.setValue('Description', 'probe key');
    expect(await store.save('a-probe-password')).toBe(true);
    expect(sent).toEqual([
      {
        path: ENCRYPTION_KEY_FILE_PATH,
        body: { root: '/probe/root/', path: 'keys/new.key', AdminName: 'ADMINUSER', AdminPassword: 'a-probe-password', KeyLen: 256, Description: 'probe key' },
      },
    ]);
    expect(store.saved()).toBe(true);
    expect(store.keyId()).toBe('NEWKEY1');
    // The password is the page's: nothing the store answers carries it.
    expect(JSON.stringify(['root', 'path', 'AdminName', 'KeyLen', 'Description', 'AdminPassword'].map((field) => store.value(field)))).not.toContain('a-probe-password');
    expect(events.map((event) => [event.kind, event.type, event.id, event.action])).toEqual([
      ['changed', 'encryption-key-file', joinCompositeId(['/probe/root/', 'keys/new.key']), 'created'],
    ]);
  });

  it('keeps a refusal on its field and what was entered, and a change clears that field', async () => {
    const violation = { field: 'AdminPassword', code: 'ENCRYPTION.KEYFILE.PASSWORD', reason: STRINGS.encryptionKeyFilePasswordRule };
    const { store, events } = mount(() => ({ kind: 'error', status: 422, code: 'ENCRYPTION.KEYFILE.VALIDATION', reason: 'refused', detail: { violations: [violation] } }));
    store.open('ADMINUSER');
    store.setValue('path', 'keys/new.key');
    expect(await store.save('ab')).toBe(false);
    expect(store.violationFor('AdminPassword')).toBe(STRINGS.encryptionKeyFilePasswordRule);
    expect(store.value('path')).toBe('keys/new.key');
    expect(events).toEqual([]);
    store.clearViolation('AdminPassword');
    expect(store.violationFor('AdminPassword')).toBe('');
  });

  it('holds the picker preselection without marking the form dirty', () => {
    const { store } = mount(() => ({ kind: 'ok', status: 201, body: {} }));
    store.open('ADMINUSER');
    store.setValue('root', '/only/root/', true);
    expect(store.value('root')).toBe('/only/root/');
    // Mutation (Rule 19): drop the `preselected` guard from `setValue` -> this goes red.
    expect(store.dirty()).toBe(false);
    store.setValue('Description', 'touched');
    expect(store.dirty()).toBe(true);
    store.reset();
    expect(store.value('Description')).toBe('');
    expect(store.dirty()).toBe(false);
  });
});

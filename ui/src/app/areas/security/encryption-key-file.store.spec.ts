import { describe, expect, it } from 'vitest';

import type { JsonResult } from '../../core/api';
import { joinCompositeId } from '../../core/entity-id';
import { STRINGS } from '../../core/strings';
import { EncryptionKeyFileStore } from './encryption-key-file.store';

/**
 * The Encryption key files page's store (Story 18.7) over a stub of the two declared reads: both are
 * issued with the key file's root and path, a refusal is kept on the picker field it names, and only
 * the newest open settles.
 */

function api(answer: (path: string) => JsonResult<unknown> | Promise<JsonResult<unknown>>) {
  const paths: string[] = [];
  return {
    paths,
    requestJson: async <T,>(path: string): Promise<JsonResult<T>> => {
      paths.push(path);
      return (await answer(path)) as JsonResult<T>;
    },
  };
}

const ADMINS = { kind: 'ok', status: 200, body: { rows: [{ Name: 'OCUPROBEADMIN' }, { Name: 'OCUPROBESPARE' }], truncated: false } } as const;
const KEYS = { kind: 'ok', status: 200, body: { rows: [{ Id: 'A1B2', KeyLen: 256, Description: 'probe' }], truncated: false } } as const;

describe('EncryptionKeyFileStore', () => {
  it('opens a key file through both declared reads, with root and path as criteria', async () => {
    const store = new EncryptionKeyFileStore();
    const stub = api((path) => (path.includes('encryptionkeyfileadmins') ? ADMINS : KEYS));
    store.setLocation('/probe/root/', 'keys/probe.key');
    await store.open(stub);
    // Mutation (Rule 19): drop the criteria from `read` -> the two paths lose root and path and this goes red.
    expect(stub.paths).toEqual([
      '/api/ocupilot/screens/security.encryptionkeyfileadmins/read?maxRows=100&root=%2Fprobe%2Froot%2F&path=keys%2Fprobe.key',
      '/api/ocupilot/screens/security.encryptionkeyfile/read?maxRows=100&root=%2Fprobe%2Froot%2F&path=keys%2Fprobe.key',
    ]);
    expect(store.status()).toBe('ready');
    expect(store.administrators()).toEqual(['OCUPROBEADMIN', 'OCUPROBESPARE']);
    expect(store.keys()).toEqual([{ Id: 'A1B2', KeyLen: 256, Description: 'probe' }]);
    expect(store.keyFileId()).toBe(joinCompositeId(['/probe/root/', 'keys/probe.key']));
  });

  it("keeps a refusal on the picker field it names, and the envelope's sentence otherwise", async () => {
    const store = new EncryptionKeyFileStore();
    const onPath = { field: 'path', code: 'ENCRYPTION.KEYFILE.UNREADABLE', reason: STRINGS.encryptionKeyFileUnreadable };
    store.setLocation('/probe/root/', 'notes.txt');
    await store.open(api(() => ({ kind: 'error', status: 422, code: 'ENCRYPTION.KEYFILE.VALIDATION', reason: 'refused', detail: { violations: [onPath] } })));
    expect(store.status()).toBe('refused');
    expect(store.pathReason()).toBe(STRINGS.encryptionKeyFileUnreadable);
    expect(store.reason()).toBe('');
    expect(store.opened()).toBeNull();
    store.setLocation('/probe/root/', 'other.key');
    expect(store.pathReason()).toBe('');
    await store.open(api(() => ({ kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'You need %Admin_FileSystemAccess:USE.', detail: null })));
    expect(store.reason()).toBe('You need %Admin_FileSystemAccess:USE.');
  });

  it('settles only the newest open, and reset forgets the location and the rows', async () => {
    const store = new EncryptionKeyFileStore();
    let release: (() => void) | null = null;
    const slow = api(
      (path) =>
        new Promise<JsonResult<unknown>>((resolve) => {
          release = () => resolve(path.includes('encryptionkeyfileadmins') ? ADMINS : KEYS);
        })
    );
    store.setLocation('/probe/root/', 'old.key');
    const first = store.open(slow);
    store.setLocation('/probe/root/', 'new.key');
    await store.open(api((path) => (path.includes('encryptionkeyfileadmins') ? { kind: 'ok', status: 200, body: { rows: [{ Name: 'NEWADMIN' }] } } : KEYS)));
    (release as (() => void) | null)?.();
    await first;
    expect(store.administrators()).toEqual(['NEWADMIN']);
    expect(store.opened()?.path).toBe('new.key');
    store.reset();
    expect(store.path()).toBe('');
    expect(store.administrators()).toEqual([]);
    expect(store.opened()).toBeNull();
  });
});

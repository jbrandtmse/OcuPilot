import { describe, expect, it } from 'vitest';

import type { JsonResult } from '../../core/api';
import { DATA_ELEMENT_ENCRYPTION, DATABASE_ENCRYPTION, EncryptionKeysStore } from './encryption-keys.store';

/**
 * Database encryption's and Data element encryption's store (Story 18.22) over a stub of the two
 * declared reads: each screen reads its own list, keeps its own rows and its refusal's sentence, and only
 * its newest read settles.
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

const DATABASE_KEYS = { kind: 'ok', status: 200, body: { rows: [{ Id: 'K1', KeyLen: 256, IsDefault: true }, { Id: 'K2', KeyLen: 128, IsDefault: false }], truncated: false } } as const;
const ELEMENT_KEYS = { kind: 'ok', status: 200, body: { rows: [{ Id: 'M1' }], truncated: false } } as const;

describe('EncryptionKeysStore', () => {
  it("reads each screen's own declared read and keeps its rows apart", async () => {
    const store = new EncryptionKeysStore();
    const stub = api((path) => (path.includes('security.databaseencryption') ? DATABASE_KEYS : ELEMENT_KEYS));
    await store.read(stub, DATABASE_ENCRYPTION);
    await store.read(stub, DATA_ELEMENT_ENCRYPTION);
    // Mutation (Rule 19): read every screen through Database encryption's read -> the second path and this go red.
    expect(stub.paths).toEqual([
      '/api/ocupilot/screens/security.databaseencryption/read?maxRows=300',
      '/api/ocupilot/screens/security.dataelementencryption/read?maxRows=300',
    ]);
    expect(store.status(DATABASE_ENCRYPTION)).toBe('ready');
    expect(store.rows(DATABASE_ENCRYPTION)).toEqual([
      { Id: 'K1', KeyLen: 256, IsDefault: true },
      { Id: 'K2', KeyLen: 128, IsDefault: false },
    ]);
    expect(store.rows(DATA_ELEMENT_ENCRYPTION)).toEqual([{ Id: 'M1', KeyLen: '', IsDefault: false }]);
  });

  it("keeps a refused read's sentence, and reset forgets every screen's rows", async () => {
    const store = new EncryptionKeysStore();
    await store.read(api(() => DATABASE_KEYS), DATABASE_ENCRYPTION);
    await store.read(api(() => ({ kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'You need %Admin_Secure:USE.', detail: null })), DATA_ELEMENT_ENCRYPTION);
    expect(store.status(DATA_ELEMENT_ENCRYPTION)).toBe('refused');
    expect(store.reason(DATA_ELEMENT_ENCRYPTION)).toBe('You need %Admin_Secure:USE.');
    expect(store.rows(DATABASE_ENCRYPTION).length).toBe(2);
    store.reset();
    expect(store.rows(DATABASE_ENCRYPTION)).toEqual([]);
    expect(store.status(DATABASE_ENCRYPTION)).toBe('idle');
  });

  it('settles only the newest read of a screen', async () => {
    const store = new EncryptionKeysStore();
    let release: (() => void) | null = null;
    const slow = api(
      () =>
        new Promise<JsonResult<unknown>>((resolve) => {
          release = () => resolve(DATABASE_KEYS);
        })
    );
    const first = store.read(slow, DATABASE_ENCRYPTION);
    await store.read(api(() => ({ kind: 'ok', status: 200, body: { rows: [] } })), DATABASE_ENCRYPTION);
    (release as (() => void) | null)?.();
    await first;
    expect(store.rows(DATABASE_ENCRYPTION)).toEqual([]);
  });
});

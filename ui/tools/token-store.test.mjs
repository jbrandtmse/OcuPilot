import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the per-tab half of AD-28 and AD-47, and DW-6 in particular: a duplicated tab must
// not inherit its parent's session.
//
// The module under test is framework-free TypeScript in ui/src/app/core, imported here
// directly -- Node strips the types. That is the whole reason the auth logic lives there:
// without it this story's client half would have no executed test host at all (DW-93 is
// Story 1.9's).
//
// Mutations (Rule 19):
// - make the constructor adopt a stored pair unconditionally (drop the navigation-kind
//   test) -> "a duplicated tab discards the pair it inherited" goes red.
// - make it discard unconditionally -> the two continuation rows go red.
// - stamp the nonce before the discard rather than after -> "a discarding load stamps a
//   fresh nonce" still passes, so the nonce assertions deliberately compare values rather
//   than merely asserting one exists.

const corePath = (name) =>
  join(dirname(fileURLToPath(import.meta.url)), '..', 'src', 'app', 'core', name);

const {
  TokenStore,
  PAIR_STORAGE_KEY,
  NONCE_STORAGE_KEY,
  readSessionStorage,
  defaultNonce,
  readNavigationKind,
} = await import(corePath('token-store.ts'));

const PAIR = {
  accessToken: 'access-1',
  refreshToken: 'refresh-1',
  sub: 'ann',
  iat: 1000,
  exp: 1060,
};

/** A `sessionStorage` stand-in that records every write, so the test can see them all. */
function fakeStorage(seed = {}) {
  const map = new Map(Object.entries(seed));
  const writes = [];
  return {
    map,
    writes,
    getItem(key) {
      return map.has(key) ? map.get(key) : null;
    },
    setItem(key, value) {
      map.set(key, value);
      writes.push({ key, value });
    },
    removeItem(key) {
      map.delete(key);
      writes.push({ key, value: null });
    },
  };
}

function seededWithPair(nonce = 'nonce-from-the-parent-tab') {
  return fakeStorage({
    [PAIR_STORAGE_KEY]: JSON.stringify(PAIR),
    [NONCE_STORAGE_KEY]: nonce,
  });
}

let nonceCounter = 0;
const freshNonce = () => `fresh-nonce-${++nonceCounter}`;

test('a reload continues the same tab: the stored pair is adopted and the nonce is unchanged', () => {
  const storage = seededWithPair('nonce-A');
  const store = new TokenStore({ storage, navigationType: () => 'reload', newNonce: freshNonce });

  assert.equal(store.adopted(), true);
  assert.deepEqual(store.read(), PAIR);
  assert.equal(store.nonce(), 'nonce-A', 'a continuing load keeps the tab identity it already had');
  assert.deepEqual(storage.writes, [], 'and writes nothing at all');
});

test('a back/forward navigation also continues the same tab', () => {
  const storage = seededWithPair('nonce-B');
  const store = new TokenStore({
    storage,
    navigationType: () => 'back_forward',
    newNonce: freshNonce,
  });

  assert.equal(store.adopted(), true);
  assert.equal(store.accessToken(), 'access-1');
  assert.equal(store.nonce(), 'nonce-B');
});

test('DW-6: a duplicated tab discards the pair it inherited and stamps a fresh nonce', () => {
  // Duplicating a tab copies sessionStorage wholesale and reports navigation type
  // "navigate" -- the same value a fresh open reports, and the reason the copied pair
  // cannot be trusted.
  const storage = seededWithPair('nonce-from-the-parent-tab');
  const store = new TokenStore({
    storage,
    navigationType: () => 'navigate',
    newNonce: () => 'nonce-of-the-duplicate',
  });

  assert.equal(store.adopted(), false, 'the duplicate holds no pair, so the caller must re-probe');
  assert.equal(store.read(), null);
  assert.equal(storage.map.has(PAIR_STORAGE_KEY), false, 'the copied pair is gone from storage');
  assert.equal(store.nonce(), 'nonce-of-the-duplicate');
  assert.notEqual(store.nonce(), 'nonce-from-the-parent-tab', 'the tab identity is its own');
  assert.equal(storage.map.get(NONCE_STORAGE_KEY), 'nonce-of-the-duplicate');
});

test('a first load with nothing stored stamps a nonce and holds no pair', () => {
  const storage = fakeStorage();
  const store = new TokenStore({
    storage,
    navigationType: () => 'navigate',
    newNonce: () => 'nonce-first',
  });

  assert.equal(store.adopted(), false);
  assert.equal(store.read(), null);
  assert.equal(store.accessToken(), '');
  assert.equal(store.nonce(), 'nonce-first');
});

test('a stored pair with no nonce beside it is not adopted -- the pair alone is not a tab identity', () => {
  const storage = fakeStorage({ [PAIR_STORAGE_KEY]: JSON.stringify(PAIR) });
  const store = new TokenStore({
    storage,
    navigationType: () => 'reload',
    newNonce: () => 'nonce-repaired',
  });

  assert.equal(store.adopted(), false);
  assert.equal(store.read(), null);
  assert.equal(store.nonce(), 'nonce-repaired');
});

test('write, read and clear round-trip, and nothing is written outside the two namespaced keys', () => {
  const storage = fakeStorage();
  const store = new TokenStore({
    storage,
    navigationType: () => 'navigate',
    newNonce: () => 'nonce-rt',
  });

  store.write(PAIR);
  assert.deepEqual(store.read(), PAIR);
  assert.equal(store.accessToken(), 'access-1');
  assert.equal(store.adopted(), true);

  store.clear();
  assert.equal(store.read(), null);
  assert.equal(store.adopted(), false);

  const keys = new Set(storage.writes.map((w) => w.key));
  assert.deepEqual(
    [...keys].sort(),
    [NONCE_STORAGE_KEY, PAIR_STORAGE_KEY].sort(),
    'the store touches exactly its own two keys'
  );
});

test('a corrupt stored value reads as no pair rather than throwing', () => {
  const storage = fakeStorage({
    [PAIR_STORAGE_KEY]: 'not json at all',
    [NONCE_STORAGE_KEY]: 'nonce-C',
  });
  const store = new TokenStore({ storage, navigationType: () => 'reload', newNonce: freshNonce });

  assert.equal(store.read(), null);
  assert.equal(store.adopted(), false, 'a value that is not a pair is not a pair');
});

test('a pair missing a token is rejected, so a half-written value cannot authorize anything', () => {
  const storage = fakeStorage({
    [PAIR_STORAGE_KEY]: JSON.stringify({ accessToken: 'a', sub: 'ann' }),
    [NONCE_STORAGE_KEY]: 'nonce-D',
  });
  const store = new TokenStore({ storage, navigationType: () => 'reload', newNonce: freshNonce });

  assert.equal(store.read(), null);
});

test('storage that throws on every access never throws out of the store', () => {
  const hostile = {
    getItem() {
      throw new Error('site data is blocked');
    },
    setItem() {
      throw new Error('site data is blocked');
    },
    removeItem() {
      throw new Error('site data is blocked');
    },
  };

  const store = new TokenStore({
    storage: hostile,
    navigationType: () => 'reload',
    newNonce: () => 'nonce-hostile',
  });

  assert.equal(store.read(), null);
  assert.equal(store.accessToken(), '');
  assert.doesNotThrow(() => store.write(PAIR));
  assert.doesNotThrow(() => store.clear());
});

// --- readSessionStorage and defaultNonce (QA): the two module-scope reads main.ts makes ---
//
// Neither had an executed test host before this pass. Both are called at module scope in
// main.ts, before Angular paints anything, which is exactly why two of the story's three HIGH
// review patches live here: a throwing property read or a throwing crypto call aborts the
// bootstrap outright. These exercise the real global (Node's own `sessionStorage`-shaped
// absence and its real `crypto.randomUUID`), not a caller-supplied fake standing in for one --
// the closest a `node --test` host gets to the browser condition each patch was written for.
//
// Mutations (Rule 19, QA):
// - readSessionStorage: drop the try/catch (`return sessionStorage;` unconditionally) -> the
//   "does not throw" case still passes, but the "falls back" test's assert.doesNotThrow fails,
//   because the hostile getter's throw now propagates.
// - defaultNonce: drop the `typeof webCrypto.randomUUID === 'function'` guard and call it
//   unconditionally -> the fallback test's assert.doesNotThrow fails (TypeError: not a function).

test('readSessionStorage returns the real sessionStorage when the property read succeeds', () => {
  const fakeSessionStorage = { getItem() {}, setItem() {}, removeItem() {} };
  const original = Object.getOwnPropertyDescriptor(globalThis, 'sessionStorage');
  Object.defineProperty(globalThis, 'sessionStorage', { configurable: true, value: fakeSessionStorage });
  try {
    assert.equal(readSessionStorage(), fakeSessionStorage, 'the real object is returned, not a copy');
  } finally {
    if (original) Object.defineProperty(globalThis, 'sessionStorage', original);
    else delete globalThis.sessionStorage;
  }
});

test('readSessionStorage falls back to a working in-memory store when the property read throws', () => {
  // This is the exact failure main.ts's module-scope call must survive: a browser with site
  // data blocked throws on the PROPERTY ACCESS itself, before any getItem/setItem call, which
  // is why the guard has to be around the read and not around each method.
  const original = Object.getOwnPropertyDescriptor(globalThis, 'sessionStorage');
  Object.defineProperty(globalThis, 'sessionStorage', {
    configurable: true,
    get() {
      throw new Error('site data is blocked');
    },
  });
  try {
    let storage;
    assert.doesNotThrow(() => {
      storage = readSessionStorage();
    }, 'the throw must not reach main.ts at module scope');
    storage.setItem('k', 'v');
    assert.equal(storage.getItem('k'), 'v');
    storage.removeItem('k');
    assert.equal(storage.getItem('k'), null, 'the fallback is a real, working store, not a stub');
  } finally {
    if (original) Object.defineProperty(globalThis, 'sessionStorage', original);
    else delete globalThis.sessionStorage;
  }
});

test('defaultNonce uses the real crypto.randomUUID() when it exists', () => {
  // Node exposes the real Web Crypto global, so this calls the actual production branch,
  // not a mock standing in for it.
  const nonce = defaultNonce();
  assert.match(
    nonce,
    /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i,
    'a real v4 UUID from the platform, not the non-crypto fallback shape'
  );
});

test('defaultNonce falls back to a non-crypto id, without throwing, when randomUUID is unavailable', () => {
  // The named failure (token-store.ts's own doc comment): on a non-secure-context origin,
  // `crypto.randomUUID` is undefined, and calling it throws before the shell ever renders.
  // An object with no randomUUID method reproduces that shape exactly.
  const original = Object.getOwnPropertyDescriptor(globalThis, 'crypto');
  Object.defineProperty(globalThis, 'crypto', { configurable: true, value: {} });
  try {
    let nonce;
    assert.doesNotThrow(() => {
      nonce = defaultNonce();
    }, 'a missing randomUUID must not throw out of the nonce generator');
    assert.match(nonce, /^ocu-[0-9a-z]+-[0-9a-z]+$/, 'the documented non-crypto fallback shape');
  } finally {
    if (original) Object.defineProperty(globalThis, 'crypto', original);
    else delete globalThis.crypto;
  }
});

// --- readNavigationKind: the reader DW-6's whole decision rests on ------------------------
//
// The third module-scope browser read main.ts makes, and the one the QA pass left without a
// host. Every other test in this file INJECTS a navigationType, so the real reader was never
// executed: replacing its body with `return 'reload';` type-checks, builds clean, leaves the
// whole suite green -- and makes every duplicated tab adopt its parent's pair, which is
// precisely the defect the nonce and the navigation check exist to prevent.
//
// Node's Performance timeline has no navigation entry, so the empty-timeline branch runs
// here against the real global rather than a stand-in for it.
//
// Mutation (Rule 19): replace readNavigationKind's body with `return 'reload';` -> "an empty
// Performance timeline reads as unknown..." goes red.

test('an empty Performance timeline reads as unknown, which is a discarding kind', () => {
  assert.equal(performance.getEntriesByType('navigation').length, 0, 'Node reports no entry');
  assert.equal(readNavigationKind(), 'unknown');

  // And `unknown` has to fall on the discard side: a reader that cannot tell must not let a
  // copied pair through.
  const storage = { getItem: () => null, setItem() {}, removeItem() {} };
  storage.getItem = (key) => (key === PAIR_STORAGE_KEY ? JSON.stringify(PAIR) : 'nonce-old');
  const store = new TokenStore({
    storage,
    navigationType: readNavigationKind,
    newNonce: () => 'nonce-fresh',
  });
  assert.equal(store.adopted(), false, 'an unknown navigation kind never adopts');
});

test('readNavigationKind reports the entry type the timeline carries', () => {
  const original = performance.getEntriesByType;
  performance.getEntriesByType = (kind) =>
    kind === 'navigation' ? [{ type: 'back_forward' }] : original.call(performance, kind);
  try {
    assert.equal(readNavigationKind(), 'back_forward', 'the real type, not a hardcoded kind');
  } finally {
    performance.getEntriesByType = original;
  }
});

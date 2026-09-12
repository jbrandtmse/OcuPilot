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

const { TokenStore, PAIR_STORAGE_KEY, NONCE_STORAGE_KEY } = await import(corePath('token-store.ts'));

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

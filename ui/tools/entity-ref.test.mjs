import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the client half of AD-13's triple: that a key round-trips every id the URL codec's own
// corpus carries, that one name in two namespaces is two entities, and that the type comes from
// the kernel's mirrored vocabulary rather than from a second list here.
//
// The corpus below holds the same values `ui/tools/entity-id.test.mjs` and
// `OcuPilot.Test.EntityId.Corpus` carry, so the URL codec and the key grammar are exercised over
// one set of awkward ids. It is spelled here rather than imported: that file is a test, and
// importing it would run its suite. Every non-ASCII row is an escape, never a literal byte.
//
// Mutations (Rule 19):
// - build the key from `encodeEntityId` -> the "verbatim, not through the URL codec" assertion
//   goes red for every row carrying a space, a slash, a percent sign or a non-ASCII character.
// - set REF_SEPARATOR to COMPOSITE_SEPARATOR -> the composite-id test goes red, because the
//   composite's first part is read as the key's whole id.
// - drop the type check from `parseEntityRefKey` -> the "refused on the way back too" assertion
//   goes red while the builder's stays green.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);

const {
  INSTANCE_SCOPE,
  REF_SEPARATOR,
  entityRefKey,
  parseEntityRefKey,
  isKnownEntityType,
  scopeFor,
} = await import(corePath('entity-ref.ts'));
const { COMPOSITE_SEPARATOR, joinCompositeId, splitCompositeId, encodeEntityId } = await import(
  corePath('entity-id.ts')
);
const { ENTITY_TYPES } = await import(corePath('screens.generated.ts'));

/**
 * AD-13's corpus, all seventeen ids `OcuPilot.Test.EntityId.Corpus()` carries: a leading
 * underscore, a slash, a space, a percent sign, a non-ASCII character, DW-97's three dot rows and
 * DW-130's sub-delimiters. `a~b` is here although `entity-id.test.mjs` excludes it -- that file
 * excludes it because the two *URL* codecs disagree on `~`, and a reference key runs through
 * neither, so a tilde is an ordinary id byte to this grammar.
 */
const CORPUS = [
  '_SYSTEM',
  'a/b',
  'a b',
  '100%',
  'caf\u00E9',
  'x?y',
  '#frag',
  '/csp/myapp',
  'a..b',
  '..leading',
  'trailing.',
  'a!b',
  'a~b',
  'a*b',
  "a'b",
  'a(b)',
  'a-b',
];

const TYPE = 'task';

test('the vocabulary is the kernel mirror, not a second list', () => {
  assert.ok(ENTITY_TYPES.includes(TYPE));
  assert.equal(isKnownEntityType(TYPE), true);
  assert.equal(isKnownEntityType('not-an-entity-type'), false);
  assert.equal(isKnownEntityType(''), false, 'a screen with no entity type has no reference either');
});

test('every corpus id round-trips through a reference key, verbatim', () => {
  for (const id of CORPUS) {
    const key = entityRefKey(TYPE, 'USER', id);
    assert.ok(key !== null, `row ${JSON.stringify(id)} builds a key`);
    assert.ok(key.includes(id), `row ${JSON.stringify(id)} reaches the key verbatim, not through the URL codec`);
    assert.deepEqual(parseEntityRefKey(key), { type: TYPE, scope: 'USER', id });
  }
});

test('a reference key is not a URL segment: the two codecs are separate', () => {
  // `encodeEntityId` encodes twice because the web server consumes one decoding in transit, so
  // its output has no inverse on its own. A key built from it would have none either.
  const id = 'a b';
  assert.notEqual(encodeEntityId(id), id);
  assert.ok(entityRefKey(TYPE, 'USER', id).includes(id));
});

test('one name in two namespaces is two entities', () => {
  const name = 'Nightly purge';
  const inUser = entityRefKey(TYPE, 'USER', name);
  const inCustom = entityRefKey(TYPE, 'HSCUSTOM', name);
  assert.notEqual(inUser, inCustom);
  assert.deepEqual(parseEntityRefKey(inUser), { type: TYPE, scope: 'USER', id: name });
  assert.deepEqual(parseEntityRefKey(inCustom), { type: TYPE, scope: 'HSCUSTOM', id: name });
});

test('a composite id passes through a key unharmed and still splits on its own separator', () => {
  assert.equal(
    REF_SEPARATOR.charCodeAt(0),
    COMPOSITE_SEPARATOR.charCodeAt(0) + 1,
    'the reference separator is one code point above the composite one'
  );

  const joined = joinCompositeId(['HSCUSTOM', '/csp/myapp']);
  const key = entityRefKey('web-application', INSTANCE_SCOPE, joined);
  const parsed = parseEntityRefKey(key);
  assert.equal(parsed.id, joined, 'the composite id comes back whole');
  assert.deepEqual(splitCompositeId(parsed.id), ['HSCUSTOM', '/csp/myapp']);
});

test('an unknown type, an empty scope and an empty id are all refused, both ways', () => {
  assert.equal(entityRefKey('not-an-entity-type', 'USER', 'x'), null);
  assert.equal(entityRefKey(TYPE, '', 'x'), null, "'instance' is the literal for an object with no namespace");
  assert.equal(entityRefKey(TYPE, 'USER', ''), null, 'a reference names something');

  const handBuilt = ['not-an-entity-type', 'USER', 'x'].join(REF_SEPARATOR);
  assert.equal(parseEntityRefKey(handBuilt), null, 'refused on the way back too');
  assert.equal(parseEntityRefKey([TYPE, 'USER'].join(REF_SEPARATOR)), null, 'and a key with two parts is not one');
  assert.equal(parseEntityRefKey(''), null);
});

test('the scope half resolves from the declared scope, and a third spelling resolves to nothing', () => {
  assert.equal(scopeFor('namespace', 'USER'), 'USER');
  assert.equal(scopeFor(INSTANCE_SCOPE, 'USER'), INSTANCE_SCOPE, 'a configuration object does not move with the route');
  assert.equal(scopeFor('cluster', 'USER'), '', 'a value the server registry refuses resolves to no scope at all');
});

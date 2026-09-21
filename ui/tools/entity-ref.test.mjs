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
// It also pins DW-1364: that the client's key builder folds a web-application id the way
// `OcuPilot.Kernel.EntityRef.Key` does, and that the rule it folds by is MIRRORED from the kernel
// rather than written a second time here -- which is what the roster pin at the end is for.
//
// Mutations (Rule 19):
// - build the key from `encodeEntityId` -> the "verbatim, not through the URL codec" assertion
//   goes red for every row carrying a space, a slash, a percent sign or a non-ASCII character.
// - set REF_SEPARATOR to COMPOSITE_SEPARATOR -> the composite-id test goes red, because the
//   composite's first part is read as the key's whole id.
// - drop the type check from `parseEntityRefKey` -> the "refused on the way back too" assertion
//   goes red while the builder's stays green.
// - make `normalizeEntityId` answer its `id` verbatim -> the cross-language equality goes red on
//   all three non-canonical spellings while every no-rule row stays green.
// - add a rule name to `ID_RULES` in `entity-ref.ts` that `IMPLEMENTED_ID_RULES` does not hold ->
//   the roster pin goes red in one direction, and the generator could then mirror a rule the
//   build never checked.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);

const {
  IMPLEMENTED_ID_RULE_NAMES,
  INSTANCE_SCOPE,
  REF_SEPARATOR,
  entityRefKey,
  normalizeEntityId,
  parseEntityRefKey,
  isKnownEntityType,
  scopeFor,
} = await import(corePath('entity-ref.ts'));
const { IMPLEMENTED_ID_RULES } = await import(join(uiRoot, 'tools', 'screen-mirror.mjs'));
const { ENTITY_ID_RULES } = await import(corePath('screens.generated.ts'));
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

test('every corpus id round-trips through a reference key, verbatim, for a type with no id rule', () => {
  assert.equal(ENTITY_ID_RULES[TYPE], undefined, 'the corpus type declares no rule, so its ids are its own');
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

  // A type with no id rule, as `OcuPilot.Test.EntityRef.TestACompositeIdPassesThroughAKeyUnharmed`
  // uses: a rule answers on the whole id, so a composite of a ruled type has every part folded by
  // it, and this row is about the separators rather than about the spelling.
  const joined = joinCompositeId(['HSCUSTOM', '/csp/myapp']);
  const key = entityRefKey(TYPE, INSTANCE_SCOPE, joined);
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

// DW-1364. The defect was that this builder joined its three parts verbatim while
// `OcuPilot.Kernel.EntityRef.Key` folded a web-application id per entity type, so the first
// server-built id to travel would have keyed a highlight onto nothing.
test('DW-1364: three spellings of one web application build the one key the instance builds', () => {
  // The expected value is spelled out rather than built from `entityRefKey` itself: an expected
  // read out of the subject asserts nothing. It is the same string
  // `OcuPilot.Test.EntityRef.TestAWebApplicationIdReachesAKeyInOneSpelling` pins on the instance.
  const expected = ['web-application', INSTANCE_SCOPE, '/csp/ocupilotprobespelling'].join(REF_SEPARATOR);
  for (const spelling of [
    '/csp/ocupilotprobespelling',
    '/CSP/OcuPilotProbeSpelling',
    '/csp/ocupilotprobespelling/',
    '/CSP/OCUPILOTPROBESPELLING///',
  ]) {
    assert.equal(
      entityRefKey('web-application', INSTANCE_SCOPE, spelling),
      expected,
      `${JSON.stringify(spelling)} builds the canonical key`
    );
  }

  // The rule goes exactly this far, and no further: it is the instance's own resolution, probed,
  // not a general tidy-up of paths.
  assert.equal(normalizeEntityId('web-application', '/API/OcuPilot/'), '/api/ocupilot');
  assert.equal(normalizeEntityId('web-application', 'api/ocupilot'), 'api/ocupilot');
  assert.equal(normalizeEntityId(TYPE, '/API/OcuPilot/'), '/API/OcuPilot/', 'a type with no rule is untouched');

  // An id that normalizes to nothing is refused as an empty id rather than keyed with none, which
  // is what "normalize before the validity gate" buys.
  assert.equal(entityRefKey('web-application', INSTANCE_SCOPE, '/'), null);
});

test('the id rules are mirrored from the kernel, and every declared rule has an implementation here', () => {
  // Both directions. One direction alone would let the generator mirror a rule this module does
  // not implement (a silent identity function on the client), or let this module grow a rule the
  // generator never checks a declaration against.
  assert.deepEqual(
    [...IMPLEMENTED_ID_RULE_NAMES].sort(),
    [...IMPLEMENTED_ID_RULES].sort(),
    "the generator's roster and entity-ref.ts's implementations are one list"
  );
  for (const [type, rule] of Object.entries(ENTITY_ID_RULES)) {
    assert.ok(isKnownEntityType(type), `the mirrored table keys on a declared entity type: ${type}`);
    assert.ok(
      IMPLEMENTED_ID_RULE_NAMES.includes(rule),
      `the mirrored rule ${rule} for ${type} has an implementation`
    );
  }
});

test('the scope half resolves from the declared scope, and a third spelling resolves to nothing', () => {
  assert.equal(scopeFor('namespace', 'USER'), 'USER');
  assert.equal(scopeFor(INSTANCE_SCOPE, 'USER'), INSTANCE_SCOPE, 'a configuration object does not move with the route');
  assert.equal(scopeFor('cluster', 'USER'), '', 'a value the server registry refuses resolves to no scope at all');
});

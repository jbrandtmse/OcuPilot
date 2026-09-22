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
const { ENTITY_ID_RULES, ENTITY_SINGLETON_ID } = await import(corePath('screens.generated.ts'));
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

// The corpus below round-trips verbatim, so the type it runs under must be one the kernel
// declares no id rule for. `task` held this place until Story 5.11 gave it the `integer` rule.
const TYPE = 'role';

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

// Story 5.9's `user:foldcase`. The roster test below asserts the rule name has *an*
// implementation; it cannot tell a fold from an identity function, and the only other check on
// this half is `ui/browser/users-write.browser-spec.mjs`'s AC6 leg, which needs a rebuilt bundle
// and runs in the `instance` job. Without this row, replacing the fold with `(id) => id` leaves
// the whole `gates` job green — DW-1364's defect shape, re-openable for the new type.
test('AD-13: three spellings of one account build the one key the instance builds', () => {
  // Spelled out rather than read back out of the subject, the way the DW-1364 row above is, and
  // the same string `OcuPilot.Test.UserUpdate.TestTheUserRuleFoldsCaseTheWayTheInstanceResolvesIt`
  // pins on the instance.
  const expected = ['user', INSTANCE_SCOPE, 'ocupilotprobeusermixedcase'].join(REF_SEPARATOR);
  for (const spelling of ['OcuPilotProbeUserMixedCase', 'ocupilotprobeusermixedcase', 'OCUPILOTPROBEUSERMIXEDCASE']) {
    assert.equal(
      entityRefKey('user', INSTANCE_SCOPE, spelling),
      expected,
      `${JSON.stringify(spelling)} builds the canonical key`
    );
  }

  // The rule goes exactly this far: an account name has no path grammar, so a trailing slash or
  // space is part of the name and is not stripped — which is what the server rule does too.
  assert.equal(normalizeEntityId('user', '_SYSTEM'), '_system');
  assert.equal(normalizeEntityId('user', '_System/'), '_system/', 'no trailing slash is stripped for an account');
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
  assert.ok(!(TYPE in ENTITY_ID_RULES), `the corpus type ${TYPE} has no rule, which is what makes the round-trip above verbatim`);
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

// Story 5.10, AD-13: a configuration object with exactly one instance has no name to fold, so the
// `singleton` rule answers the mirrored constant for every spelling -- and the client answers the
// same constant the kernel does, because both read `RULESINGLETONID` rather than a literal of their
// own (DW-1403's defect class).
//
// Mutation (Rule 19): implement `singleton` as `(id) => id` in `entity-ref.ts` -> every row below
// goes red; emit a literal in `screen-mirror.mjs` instead of the parsed parameter -> the key
// assertion goes red the moment the kernel's parameter moves.
test('AD-13: the singleton rule answers one id for every spelling, from the mirrored constant', () => {
  const type = 'auditing-configuration';
  assert.equal(ENTITY_ID_RULES[type], 'singleton', 'the mirrored table declares the rule');
  assert.equal(typeof ENTITY_SINGLETON_ID, 'string');
  assert.notEqual(ENTITY_SINGLETON_ID, '', 'and the mirrored constant is a real id');
  for (const spelling of [ENTITY_SINGLETON_ID, 'system', 'System', 'anything at all', '']) {
    assert.equal(normalizeEntityId(type, spelling), ENTITY_SINGLETON_ID, `'${spelling}' folds to it`);
  }
  assert.equal(
    entityRefKey(type, 'instance', 'system'),
    entityRefKey(type, 'instance', ENTITY_SINGLETON_ID),
    'so two spellings build one key'
  );
  // The rule is per type: an id of another type is untouched by it.
  assert.equal(normalizeEntityId('role', 'Nightly Purge'), 'Nightly Purge');
});

// Story 5.11, AD-13: a task is addressed by the vendor's own integer id, which the model supplies
// as a string, so `007`, `+7` and ` 7 ` are spellings of one target. The client answers what
// `OcuPilot.Kernel.EntityRef.PlainInteger` answers, on the string rather than through arithmetic,
// because a key builder cannot depend on two languages agreeing about numeric precision.
//
// Mutation (Rule 19): implement `integer` as `(id) => id` in `entity-ref.ts` -> every folding row
// below goes red; drop the verbatim arm -> the non-integer rows go red.
test('AD-13: the integer rule folds a task id to its plain decimal spelling, and leaves anything else', () => {
  const type = 'task';
  assert.equal(ENTITY_ID_RULES[type], 'integer', 'the mirrored table declares the rule');
  for (const spelling of ['7', '007', '+7', ' 7 ', '\t7', '0000007']) {
    assert.equal(normalizeEntityId(type, spelling), '7', `'${spelling}' folds to 7`);
  }
  assert.equal(normalizeEntityId(type, '-0'), '0', 'a negative zero is zero');
  assert.equal(normalizeEntityId(type, '-007'), '-7', 'and a negative id keeps its sign');
  assert.equal(normalizeEntityId(type, '0'), '0');
  for (const verbatim of ['7.0', 'abc', '', '7a', '1 2', '0x7']) {
    assert.equal(normalizeEntityId(type, verbatim), verbatim, `'${verbatim}' is not an integer and is answered verbatim`);
  }
  assert.equal(
    entityRefKey(type, 'instance', '007'),
    entityRefKey(type, 'instance', '7'),
    'so two spellings of one task build one key'
  );
});

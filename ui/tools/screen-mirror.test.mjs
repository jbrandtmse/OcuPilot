import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  MIRROR_PATH,
  buildMirror,
  entityTypesIn,
  extractClassName,
  extractXData,
  generate,
  parseEntityTypes,
  readCheckedInMirror,
  readSources,
} from './screen-mirror.mjs';
import { loadStrings } from './strings.mjs';

// The drift check AD-3's "a checked-in artifact, never runtime reflection" needs: the mirror in
// `ui/src/app/core/screens.generated.ts` must be exactly what the XData declarations in
// `src/OcuPilot/Screen/` produce. One source, two readers -- the ObjectScript registry through
// `%Dictionary.XDataDefinition`, this off disk -- and this is what keeps them one.
//
// Mutations (Rule 19):
// - edit any value in a descriptor's XData without regenerating -> the drift test goes red.
// - hand-edit screens.generated.ts -> the same test goes red, which is what "DO NOT EDIT"
//   means mechanically rather than as a comment.

test('the checked-in mirror is exactly what the descriptor declarations produce', () => {
  assert.equal(
    readCheckedInMirror(),
    generate(),
    `${MIRROR_PATH} is stale -- run node tools/screen-mirror.mjs`
  );
});

test('the mirror carries the kernel vocabulary, the areas and every descriptor', () => {
  const { entityTypes, areas, screens } = readSources();
  assert.ok(entityTypes.length >= 20, `expected the closed vocabulary, read ${entityTypes.length}`);
  assert.equal(areas.length, 8);
  assert.ok(screens.length >= 1, 'at least Home is declared');
  for (const screen of screens) {
    assert.ok(screen.className.startsWith('OcuPilot.Screen.Descriptor.'), screen.file);
    assert.notEqual(screen.className, 'OcuPilot.Screen.Descriptor.Base', 'the base declares no screen');
  }
});

test('every declared area and label key the mirror carries resolves against the string source', () => {
  const strings = loadStrings();
  const { areas, screens } = readSources();
  const areaKeys = new Set(areas.map((area) => area.key));
  for (const area of areas) {
    assert.ok(area.labelKey in strings, `area ${area.key} names a string key that does not exist`);
  }
  for (const screen of screens) {
    assert.ok(areaKeys.has(screen.declaration.area), `${screen.file} names an undeclared area`);
    assert.ok(
      screen.declaration.labelKey in strings,
      `${screen.file} names a string key that does not exist`
    );
  }
});

test('AD-14: the generator refuses an entity type the kernel enum does not hold, naming both', () => {
  const sources = readSources();
  const hostile = {
    ...sources,
    screens: [
      {
        file: 'Hostile.cls',
        className: 'OcuPilot.Screen.Descriptor.Hostile',
        declaration: { entityType: 'not-an-entity-type', secondaryEntityTypes: [] },
      },
    ],
  };
  assert.throws(
    () => buildMirror(hostile),
    (error) => {
      assert.match(error.message, /Hostile\.cls/, 'the refusal names the file');
      assert.match(error.message, /not-an-entity-type/, 'and the value');
      return true;
    }
  );

  // ...and a secondary type is checked the same way, which a primary-only check would miss.
  assert.throws(
    () =>
      buildMirror({
        ...sources,
        screens: [
          {
            file: 'Secondary.cls',
            className: 'OcuPilot.Screen.Descriptor.Secondary',
            declaration: { entityType: 'user', secondaryEntityTypes: ['also-not-one'] },
          },
        ],
      }),
    /also-not-one/
  );
});

test('entityTypesIn reads the primary first, then the secondaries, and drops the empties', () => {
  assert.deepEqual(entityTypesIn({ entityType: 'user', secondaryEntityTypes: ['role', ''] }), [
    'user',
    'role',
  ]);
  assert.deepEqual(entityTypesIn({ entityType: '', secondaryEntityTypes: [] }), [], 'Home names none');
  assert.deepEqual(entityTypesIn({}), [], 'a declaration missing both fields names none');
});

test('the XData reader finds a named block and only that block', () => {
  const source = [
    '/// A doc comment mentioning XData Declaration, which is prose.',
    'Class Some.Thing Extends Other',
    '{',
    '',
    'XData Other',
    '{',
    '{"not": "this one"}',
    '}',
    '',
    'XData Declaration',
    '{',
    '{"route": "a/b"}',
    '}',
    '',
    '}',
  ].join('\n');

  assert.equal(extractClassName(source), 'Some.Thing');
  assert.equal(JSON.parse(extractXData(source, 'Declaration')).route, 'a/b');
  assert.equal(JSON.parse(extractXData(source, 'Other')).not, 'this one');
  assert.equal(extractXData(source, 'Missing'), null);
});

test('the vocabulary parser reads the kernel parameter, and reports a source that has none', () => {
  assert.deepEqual(parseEntityTypes('Parameter TYPES = "a,b, c";'), ['a', 'b', 'c']);
  assert.equal(parseEntityTypes('Parameter OTHER = "a";'), null, 'a missing parameter is not an empty vocabulary');
});

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import {
  MIRROR_PATH,
  buildMirror,
  entityTypesIn,
  extractClassName,
  extractXData,
  generate,
  malformedPair,
  parseEntityTypes,
  parseScopeWords,
  readCheckedInMirror,
  readSources,
} from './screen-mirror.mjs';
import { loadStrings, publishedRefreshRates } from './strings.mjs';

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

// DW-158: the declared `scope` half of a screen descriptor previously failed the build only on
// the instance, through OcuPilot.Screen.Registry.Validate -- neither this generator nor
// scripts/check-objectscript.py read it. Both now do, reading the vocabulary from
// OcuPilot.Kernel.Scope's own two Parameter values rather than a literal pair, the same way the
// entity-type rule above reads EntityType.cls.
//
// Mutation (Rule 19): drop the `scope` check from buildMirror (or from
// scripts/check-objectscript.py's check_screen_scope) -> the matching case below stops throwing
// and this test goes red; demonstrated and reverted for this pass.
test('AD-13: the generator refuses a scope neither of the kernel two values, naming both', () => {
  const sources = readSources();
  assert.deepEqual(
    new Set(sources.scopeWords),
    new Set(['instance', 'namespace']),
    'the two values Kernel.Scope declares'
  );

  assert.throws(
    () =>
      buildMirror({
        ...sources,
        screens: [
          {
            file: 'Hostile.cls',
            className: 'OcuPilot.Screen.Descriptor.Hostile',
            declaration: { scope: 'cluster' },
          },
        ],
      }),
    (error) => {
      assert.match(error.message, /Hostile\.cls/, 'the refusal names the file');
      assert.match(error.message, /"cluster"/, 'and the value');
      return true;
    }
  );

  // A screen that declares no scope at all (a fixture built for something else, such as the
  // privilege-pair test below) is not refused for a value it never made.
  assert.doesNotThrow(() =>
    buildMirror({
      ...sources,
      screens: [
        {
          file: 'NoScope.cls',
          className: 'OcuPilot.Screen.Descriptor.NoScope',
          declaration: {},
        },
      ],
    })
  );
});

// AD-43 / DW-126: a screen's permitted refresh rates are only usable if the command bar can name
// them, and the only copy that names one is the Fixed-strings row in `ui/src/app/core/strings.ts`.
// Release 1 publishes exactly one. Refusing an unpublished rate here is what turns the missing
// copy into a build failure rather than a comment, and it is what makes publishing the copy later
// the whole of the change.
//
// Mutation (Rule 19): drop the rate check from `buildMirror` -> the matching case below stops
// throwing and this test goes red, while the real tree stays green either way -- which is why the
// refusal needs a fixture rather than the shipped roster as its subject.
test('AD-43: the generator refuses a declared rate the string table publishes no chip literal for', () => {
  const sources = readSources();
  assert.deepEqual(sources.publishedRates, [10], 'Release 1 publishes one rate (DW-126)');

  assert.throws(
    () =>
      buildMirror({
        ...sources,
        screens: [
          {
            file: 'Hostile.cls',
            className: 'OcuPilot.Screen.Descriptor.Hostile',
            declaration: { refreshes: true, refreshRates: [10, 30] },
          },
        ],
      }),
    (error) => {
      assert.match(error.message, /Hostile\.cls/, 'the refusal names the file');
      assert.match(error.message, /refresh rate 30/, 'and the value');
      assert.match(error.message, /strings\.ts/, 'and where the copy would have to be published');
      assert.match(error.message, /Auto-refresh: every 30 s/, 'and the literal that is missing');
      return true;
    }
  );

  // The published rate passes, and a screen that declares none is not refused for a value it
  // never made -- the same treatment `scope` gets above.
  assert.doesNotThrow(() =>
    buildMirror({
      ...sources,
      screens: [
        {
          file: 'Fine.cls',
          className: 'OcuPilot.Screen.Descriptor.Fine',
          declaration: { refreshes: true, refreshRates: [10] },
        },
        {
          file: 'None.cls',
          className: 'OcuPilot.Screen.Descriptor.None',
          declaration: {},
        },
      ],
    })
  );
});

// AD-43's other half: the pair itself. `OcuPilot.Screen.Registry.RefreshProblem` refuses these on
// the instance, which makes the container's start hook exit 1 (AD-38); refusing them here fails a
// developer's build instead, the way the entity-type and scope refusals above already do.
//
// Mutation (Rule 19): delete the `refreshProblem` call from `buildMirror` -> every `assert.throws`
// below stops throwing and this test goes red, while the shipped roster stays green either way --
// which is why the refusal needs fixtures rather than the roster as its subject.
test('AD-43: the generator refuses a malformed refresh pair, not only an unpublished rate', () => {
  const sources = readSources();
  const build = (declaration) =>
    buildMirror({
      ...sources,
      screens: [{ file: 'Hostile.cls', className: 'OcuPilot.Screen.Descriptor.Hostile', declaration }],
    });

  const refused = [
    [{ refreshes: false, refreshRates: [10] }, /does not refresh permits none/],
    [{ refreshRates: [10] }, /does not refresh permits none/],
    [{ refreshes: true, refreshRates: [] }, /refreshRates is empty/],
    [{ refreshes: true, refreshRates: [0] }, /whole number of seconds above zero/],
    [{ refreshes: true, refreshRates: [-10] }, /whole number of seconds above zero/],
    [{ refreshes: true, refreshRates: [1.5] }, /whole number of seconds above zero/],
    [{ refreshes: true, refreshRates: ['10'] }, /whole number of seconds above zero/],
    [{ refreshes: true, refreshRates: [10, 10] }, /does not ascend/],
    [{ refreshes: true, refreshRates: [10, 5] }, /does not ascend/],
    // `%GetIterator` over a `%DynamicObject` yields its values, so an object declaration reads as
    // a sound rate list on the instance unless something refuses the shape first.
    [{ refreshes: true, refreshRates: { a: 10 } }, /not a list of rates/],
    [{ refreshes: true, refreshRates: 10 }, /not a list of rates/],
  ];
  for (const [declaration, message] of refused) {
    assert.throws(
      () => build(declaration),
      (error) => {
        assert.match(error.message, /Hostile\.cls/, 'the refusal names the file');
        assert.match(error.message, message, `for ${JSON.stringify(declaration)}`);
        return true;
      },
      `expected ${JSON.stringify(declaration)} to be refused`
    );
  }

  // Sound, and stays sound: one rate, an ascending published list, and the pair omitted entirely
  // by a descriptor written before the fields existed.
  assert.doesNotThrow(() => build({ refreshes: true, refreshRates: [10] }));
  assert.doesNotThrow(() => build({ refreshes: false, refreshRates: [] }));
  assert.doesNotThrow(() => build({}));
});

test('the shipped descriptors declare only rates the table publishes, and Home declares none', () => {
  const { screens, publishedRates } = readSources();
  const published = new Set(publishedRates);
  for (const screen of screens) {
    for (const rate of screen.declaration.refreshRates ?? []) {
      assert.ok(published.has(rate), `${screen.file} declares an unpublished rate ${rate}`);
    }
    if (screen.declaration.refreshes !== true) {
      assert.deepEqual(
        screen.declaration.refreshRates ?? [],
        [],
        `${screen.file} permits a rate while declaring it does not refresh`
      );
    }
  }
});

test('the two readers of the chip literal agree on which rates are published', () => {
  // `screen-mirror.mjs` reads the table through `strings.mjs` because nothing in this tree
  // executes TypeScript; the client reads its own `STRINGS` through the same pattern spelled in
  // `core/refresh.ts`. Two readers of one source, the arrangement `parseScopeWords` already has
  // with `OcuPilot.Kernel.Scope` -- and this is what keeps them from drifting apart.
  const clientSource = readFileSync(
    join(dirname(fileURLToPath(import.meta.url)), '..', 'src', 'app', 'core', 'refresh.ts'),
    'utf8'
  );
  const clientPattern = /AUTO_REFRESH_ON_RE\s*=\s*(\/\^Auto-refresh: every \(\\d\+\) s\$\/)/.exec(
    clientSource
  );
  assert.notEqual(clientPattern, null, 'core/refresh.ts spells the same pattern this tool does');
  assert.deepEqual(publishedRefreshRates(loadStrings()), [10]);
});

test('parseScopeWords reads both kernel parameters, and reports a source missing either', () => {
  assert.deepEqual(
    parseScopeWords('Parameter SCOPEINSTANCE = "instance";\n\nParameter SCOPENAMESPACE = "namespace";'),
    ['instance', 'namespace']
  );
  assert.equal(
    parseScopeWords('Parameter SCOPEINSTANCE = "instance";'),
    null,
    'missing SCOPENAMESPACE is not an empty vocabulary'
  );
  assert.equal(parseScopeWords('Parameter OTHER = "x";'), null, 'neither parameter present');
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

test('DW-129: a same-line XData Declaration block is not read -- pinned, not fixed', () => {
  // Every descriptor in the tree today puts the opening brace on the line AFTER the `XData`
  // declaration (the UDL convention `extractXData`'s three-state walk assumes). A descriptor
  // written with the opening and closing brace on the declaration line itself is a shape no
  // descriptor uses today, and this reader does not recognize it: `readSources()` would throw
  // "carries no 'XData Declaration' block" for a descriptor written this way, treating a real
  // declaration as absent rather than parsing it.
  //
  // scripts/check-objectscript.py's iter_named_xdata_blocks has the matching disagreement, in
  // the opposite direction -- it silently skips the same shape instead of erroring, so a bad
  // entity type inside one currently passes that gate too (pinned in
  // scripts/test_check_objectscript.py's TestDW129SingleLineXDataDisagreement). Neither reader
  // is fixed here (deferred, medium, filed at Story 1.9's review); this only pins today's
  // behavior so a change to either side is visible.
  //
  // Mutation (Rule 19): teach extractXData to also read a same-line block (return the text
  // between the first "{" and the last "}" when the declaration line is already balanced) ->
  // this assertion goes red, which is the intended signal that the pin needs updating because
  // the reader has actually been fixed.
  const source = [
    'Class OcuPilot.Screen.Descriptor.Inline Extends OcuPilot.Screen.Descriptor.Base',
    '{',
    '',
    'XData Declaration { "entityType": "user" }',
    '',
    '}',
  ].join('\n');

  assert.equal(extractXData(source, 'Declaration'), null, 'the same-line form is not recognized');
});

test('the vocabulary parser reads the kernel parameter, and reports a source that has none', () => {
  assert.deepEqual(parseEntityTypes('Parameter TYPES = "a,b, c";'), ['a', 'b', 'c']);
  assert.equal(parseEntityTypes('Parameter OTHER = "a";'), null, 'a missing parameter is not an empty vocabulary');
});

// A declared privilege pair missing either half is dropped by both readers rather than carried
// (OcuPilot.Screen.Area.PairsFrom), so a declaration that misspells `permission` collapses to
// an empty set -- which AD-8 holds is satisfied by everyone. The declaration reads as a gate and
// produces none. Refusing it here is what keeps such a declaration off a running instance:
// Registry.Validate refuses it for a descriptor but nothing on the serving path calls Validate,
// and no rule anywhere read `XData Areas` at all.
//
// Mutation (Rule 19): make `malformedPair` return null unconditionally, or drop either throw
// from `buildMirror` -> the matching case below goes red (the throw is no longer raised), while
// the real tree stays green either way because its declarations are sound -- which is exactly
// why the refusal needs a fixture rather than the shipped roster as its subject.
test('the build refuses a privilege pair missing a half, in an area and in a descriptor', () => {
  assert.equal(malformedPair([{ resource: '%Admin_Secure', permission: 'USE' }]), null);
  assert.equal(malformedPair([]), null, 'an empty set is a declaration that never gates, not a fault');
  assert.equal(malformedPair(undefined), null, 'an absent key is an empty set');
  assert.equal(malformedPair([{ resource: '%Admin_Secure', permissions: 'USE' }]), '#1', 'the misspelling this exists for');
  assert.equal(malformedPair([{ permission: 'USE' }]), '#1', 'no resource');
  assert.equal(malformedPair([{ resource: '%Admin_Secure', permission: '' }]), '#1', 'an empty permission');
  assert.equal(malformedPair([{ resource: 'a', permission: 'USE' }, 'not-an-object']), '#2', 'and the position is named');

  const sound = { entityTypes: ['user'], areas: [], screens: [] };

  assert.throws(
    () =>
      buildMirror({
        ...sound,
        areas: [{ key: 'permissions', privileges: [{ resource: '%Admin_Secure', permissions: 'USE' }] }],
      }),
    /area "permissions" declares privilege pair #1/,
    'an area whose pair is dropped would ship an ungated rail item'
  );

  assert.throws(
    () =>
      buildMirror({
        ...sound,
        screens: [
          {
            file: 'Fixture.cls',
            className: 'OcuPilot.Screen.Descriptor.Fixture',
            declaration: { privileges: [{ resource: '%Admin_Secure' }] },
          },
        ],
      }),
    /Fixture\.cls: declares privilege pair #1/,
    'and a descriptor whose pair is dropped would ship an ungated screen'
  );

  const { areas, screens } = readSources();
  assert.doesNotThrow(() => buildMirror({ entityTypes: parseEntityTypes('Parameter TYPES = "user";'), areas, screens: [] }));
  for (const screen of screens) assert.equal(malformedPair(screen.declaration.privileges), null, screen.file);
  for (const area of areas) assert.equal(malformedPair(area.privileges), null, area.key);
});

// AD-44, Story 1.15: `archetype` was free text every reader ignored, so "only a detail view may
// declare a classic link-out" had no predicate to evaluate -- a typo answered "not a detail
// view" and passed. The vocabulary is closed in `OcuPilot.Screen.Archetype` and refused here,
// the third of the three places a declared value fails the build (the others being
// `ui/tools/classic-links.mjs` and `OcuPilot.Screen.Registry.Validate` on the instance).
//
// Mutation (Rule 19): drop the archetype check from `buildMirror` -> the matching case below
// stops throwing and this test goes red, while the real tree stays green either way.
test('AD-44: the generator refuses an archetype outside the closed vocabulary, naming both', () => {
  const sources = readSources();
  assert.ok(sources.archetypes.length >= 16, 'the vocabulary reached readSources');

  assert.throws(
    () =>
      buildMirror({
        ...sources,
        screens: [
          {
            file: 'Hostile.cls',
            className: 'OcuPilot.Screen.Descriptor.Hostile',
            declaration: { archetype: 'lst' },
          },
        ],
      }),
    (error) => {
      assert.match(error.message, /Hostile\.cls/, 'the refusal names the file');
      assert.match(error.message, /"lst"/, 'and the value');
      assert.match(error.message, /Archetype\.cls/, 'and where the vocabulary is declared');
      return true;
    }
  );

  // A declared value passes, and a fixture that declares none is not refused for a value it
  // never made -- the same treatment `scope` and `refreshRates` get above.
  assert.doesNotThrow(() =>
    buildMirror({
      ...sources,
      screens: [
        {
          file: 'Fine.cls',
          className: 'OcuPilot.Screen.Descriptor.Fine',
          declaration: { archetype: 'form-page (tabs)' },
        },
        { file: 'None.cls', className: 'OcuPilot.Screen.Descriptor.None', declaration: {} },
      ],
    })
  );
});

// The card reads its target and its action label off the mirror, so both sub-fields have to
// cross the generator -- and a descriptor written before they existed has to keep emitting a
// complete `ClassicLinkExemption` rather than failing as an unreadable `tsc` error, which is
// the same defaulting the refresh pair carries for the same reason.
//
// Mutation (Rule 19): delete `label` from the emitted exemption (or from the interface) -> the
// carry-through assertion goes red and `ng build`'s type check fails on the emitted literal.
test('AD-44: classicLinkExemption carries its label and href through the generator', () => {
  const sources = readSources();

  const emitted = buildMirror({
    ...sources,
    screens: [
      {
        file: 'Exempt.cls',
        className: 'OcuPilot.Screen.Descriptor.Exempt',
        declaration: {
          archetype: 'detail',
          classicPage: 'OcuPilotTestClassicPage',
          classicLinkExemption: {
            exempt: true,
            reason: 'a detail view with no rebuilt equivalent yet',
            label: 'OcuPilot test classic page',
            href: '/csp/sys/OcuPilotTestClassicPage.csp',
          },
        },
      },
    ],
  });
  assert.match(emitted, /"label": "OcuPilot test classic page"/, 'the action label crosses');
  assert.match(emitted, /"href": "\/csp\/sys\/OcuPilotTestClassicPage\.csp"/, 'and the target');
  assert.match(emitted, /readonly href: string;/, 'and the interface declares it');

  // A declaration written before the two fields existed emits them anyway, empty.
  const defaulted = buildMirror({
    ...sources,
    screens: [
      {
        file: 'Old.cls',
        className: 'OcuPilot.Screen.Descriptor.Old',
        declaration: { archetype: 'home', classicLinkExemption: { exempt: false, reason: '' } },
      },
    ],
  });
  assert.match(defaulted, /"exempt": false,\n\s*"reason": "",\n\s*"label": "",\n\s*"href": ""/);

  // And the emitted mirror carries all four fields for every shipped screen, so the client's
  // `ClassicLinkExemption` is never partially present at runtime either. Asserted over
  // `buildMirror`'s own output rather than over `sources.screens`, which are the parsed source
  // declarations -- reading those would check what the descriptors happen to declare today and
  // would stay green with the defaulting deleted.
  const shipped = JSON.parse(
    buildMirror(sources).match(/export const SCREENS: readonly ScreenDeclaration\[\] = (\[[\s\S]*?\n\]);/)[1]
  );
  assert.ok(shipped.length >= 1, 'the shipped mirror carries at least Home');
  for (const screen of shipped) {
    for (const field of ['exempt', 'reason', 'label', 'href']) {
      assert.ok(
        field in screen.classicLinkExemption,
        `${screen.descriptor} emits classicLinkExemption.${field}`
      );
    }
  }
  assert.match(readCheckedInMirror(), /"label": ""/, 'the checked-in mirror carries the defaulted parts');
});

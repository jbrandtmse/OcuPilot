import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import {
  BANNER_SEVERITIES,
  DECLARATION_KEYS,
  entityLabelProblem,
  MIRROR_PATH,
  bannerProblem,
  declarationProblem,
  braceDelta,
  buildMirror,
  confirmChannelProblem,
  declaredNames,
  parseDeclaredNameKinds,
  IMPLEMENTED_DECLARED_NAME_KINDS,
  criteriaProblem,
  entityTypesIn,
  ENTITY_REF_SOURCE,
  extractClassName,
  extractXData,
  generate,
  malformedPair,
  parentScopeResolutionProblem,
  IMPLEMENTED_ID_RULES,
  parseEntityTypes,
  parseIdRuleNames,
  parseIdRules,
  parseRefSeparator,
  parseScopeWords,
  readCheckedInMirror,
  declaredStringKeys,
  readProblem,
  readSources,
  ROW_TARGET_KEYS,
  rowTargetProblem,
  rowTargetResolutionProblem,
  sideBarPositionProblem,
  tabGroupProblem,
  tabProblem,
} from './screen-mirror.mjs';
import { loadStrings } from './strings.mjs';
import { CREDENTIAL_RE } from './field-lists.mjs';

const toolsDir = dirname(fileURLToPath(import.meta.url));

/** The `XData <name>` body of a `.cls` under `src/OcuPilot/`, parsed. */
function testCorpus(file, name) {
  const body = extractXData(readFileSync(join(toolsDir, '..', '..', 'src', 'OcuPilot', ...file), 'utf8'), name);
  assert.ok(body !== null, `${file.join('/')} carries an 'XData ${name}' block`);
  return JSON.parse(body);
}

// The drift check AD-3's "a checked-in artifact, never runtime reflection" needs: the mirror in
// `ui/src/app/core/screens.generated.ts` must be exactly what the XData declarations in
// `src/OcuPilot/Screen/` produce. One source, two readers -- the ObjectScript registry through
// `%Dictionary.XDataDefinition`, this off disk -- and this is what keeps them one.
//
// Mutations (Rule 19):
// - edit any value in a descriptor's XData without regenerating -> the drift test goes red.
// - hand-edit screens.generated.ts -> the same test goes red, which is what "DO NOT EDIT"
//   means mechanically rather than as a comment.

// Story 1.17's own Always-constraint: every gate CI runs reports the size of what it looked at.
// `screen-mirror: up to date.` named no population, so a run over a descriptor directory that
// resolved to nothing printed the line a passing run prints.
//
// Mutation (Rule 19): drop the census from `--check`'s success line -> this goes red.
test('the mirror check reports the size of what it mirrored, not only that it matched', () => {
  const run = spawnSync(process.execPath, [join(toolsDir, 'screen-mirror.mjs'), '--check'], {
    encoding: 'utf8',
    cwd: join(toolsDir, '..'),
  });
  assert.equal(run.status, 0, `expected a clean --check, got: ${run.stdout}${run.stderr}`);
  assert.match(run.stdout, /descriptor\(s\)/, 'the success line names the descriptor count it read');
  assert.match(run.stdout, /[1-9]\d* descriptor\(s\)/, 'and that count is non-zero, so a scan over nothing is distinguishable');
});

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
    for (const key of declaredStringKeys(screen.declaration)) {
      assert.ok(key in strings, `${screen.file} names the string key '${key}', which does not exist`);
    }
  }
});

// The roster declares no table before Story 2.5, so the check above has a fixture of its own: every
// label, empty-state, next and agent key a table declaration names is one the check reads -- and,
// since Story 2.8, the banner's `messageKey` too. A key the enumerator does not read is a key the
// check above cannot resolve, and `stringFor` answers `''` for an unknown one, so the only symptom
// of a typo would be a banner that never appears.
//
// Mutations (Rule 19): drop the column labels from `declaredStringKeys` -> the listing below goes
// red; drop the banner's case keys from it -> the listing goes red on its last two members and the
// unresolved-key assertion loses them. Reading only the first case reddens it too, which is what
// keeps a second case's key (DW-270) from being a key nothing resolves. Drop a column's `emptyKey`
// from it -> the listing goes red, missing `notAnEmptyCellKey`. Drop the tab's `labelKey` from it ->
// the listing goes red, missing `notATabStringKey`.
test('every string key a table or banner declaration names is one the key check reads', () => {
  const declaration = JSON.parse(
    '{"labelKey": "navAreaWebApplications", "emptyStateKey": "commandBoxNoMatch",' +
      ' "table": {"columns": [{"field": "Name", "labelKey": "fieldUserName", "kind": "name"},' +
      ' {"field": "Enabled", "labelKey": "notAStringKey", "kind": "status", "emptyKey": "notAnEmptyCellKey"}],' +
      ' "emptyNextKey": "classicLinkCardCaption", "emptyAgentKey": ""},' +
      ' "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"},' +
      ' "field": "Status", "cases": [' +
      ' {"equals": "Suspended", "messageKey": "notABannerStringKey", "severity": "warning"},' +
      ' {"equals": "Not running", "messageKey": "notASecondBannerStringKey", "severity": "warning"}' +
      ' ]},' +
      ' "tab": {"group": "security/oauth", "position": 2, "labelKey": "notATabStringKey"}}'
  );
  const keys = declaredStringKeys(declaration);
  assert.deepEqual(keys, [
    'navAreaWebApplications',
    'commandBoxNoMatch',
    'fieldUserName',
    'notAStringKey',
    'notAnEmptyCellKey',
    'classicLinkCardCaption',
    'notABannerStringKey',
    'notASecondBannerStringKey',
    'notATabStringKey',
  ]);
  const strings = loadStrings();
  assert.deepEqual(
    keys.filter((key) => !(key in strings)),
    ['notAStringKey', 'notAnEmptyCellKey', 'notABannerStringKey', 'notASecondBannerStringKey', 'notATabStringKey'],
    'and a key the string source lacks is found, both banner cases\' among them'
  );
});

// AD-13 as amended by DW-1359, and DW-1364 itself: the kernel declares its per-type id rules as
// data and this generator mirrors them, so the client's key builder folds what the instance folds.
// A declaration the client cannot honour must fail the BUILD -- mirroring it as a rule name
// nothing implements is exactly the silent divergence the amendment exists to close.
//
// Mutation (Rule 19): return the pairs unchecked from `checkedIdRules` -> all four refusals below
// go red, and a rule named in `IDRULES` would reach `screens.generated.ts` with no implementation.
// Mutation (Rule 19): trim the halves in `parseIdRules` again -> the whitespace row goes red,
// because a spaced pair would mirror cleanly while `IdRuleFor`'s `$Piece` matched no type.
test('AD-13: the id-rule table is read from the kernel and is what the mirror emits', () => {
  const text = readFileSync(ENTITY_REF_SOURCE, 'utf8');
  const rules = parseIdRules(text);
  assert.deepEqual(rules, [
    ['web-application', 'foldcase-striptrailingslash'],
    ['user', 'foldcase'],
    ['auditing-configuration', 'singleton'],
    ['task', 'integer'],
    ['process', 'integer'],
    ['application-error', 'foldcase'],
  ]);
  assert.deepEqual(parseIdRuleNames(text), ['foldcase-striptrailingslash', 'foldcase', 'singleton', 'integer']);
  // `null`, never `[]`, when the parameter is missing: an absent table and a table that declares
  // nothing are different facts, and only one of them is a source to build from.
  assert.equal(parseIdRules('Class X { }'), null);
  assert.equal(parseIdRuleNames('Class X { }'), null);
  assert.match(generate(), /export const ENTITY_ID_RULES/, 'and the emission carries it');
});

test('DW-1403: the reference separator is read from the kernel and emitted, never copied', () => {
  // `entity-ref.ts` held the joining character as a hand-copied escape beside
  // `Parameter REFSEPARATOR = 2` with nothing comparing the two. It is now mirrored like the
  // entity-type enum and the id-rule table, so there is one source (AD-5).
  //
  // Mutation (Rule 19): drop `refSeparator` from `readSources`' return -> `buildMirror` refuses
  // it and this row goes red; emit a literal 2 instead of the parsed value -> the declared-code
  // assertion below goes red once the kernel's own parameter moves.
  const text = readFileSync(ENTITY_REF_SOURCE, 'utf8');
  const declared = parseRefSeparator(text);
  assert.equal(typeof declared, 'number');
  assert.ok(declared > 0, 'a code point, not a flag');
  assert.equal(parseRefSeparator('Class X { }'), null, 'reported, never read as a default');
  assert.equal(parseRefSeparator('Parameter REFSEPARATOR = "two";'), null, 'and never read as text');
  assert.match(
    generate(),
    new RegExp(`export const ENTITY_REF_SEPARATOR_CODE = ${declared};`),
    'the emission carries the kernel\'s own value'
  );
  assert.throws(
    () => buildMirror({ ...readSources(), refSeparator: 0 }),
    /REFSEPARATOR must be a whole number above zero/,
    'and a separator no key could be built from fails the build'
  );
});

test('AD-13: IDRULES is read exactly as `IdRuleFor` reads it, so a stray space fails the build', () => {
  // `OcuPilot.Kernel.EntityRef.IdRuleFor` splits with `$Piece` and compares verbatim, so the
  // natural spelling of a second pair -- a space after the comma -- names a type the kernel
  // matches nothing for. A trimming reader here would mirror the rule anyway and the client would
  // fold an id the instance leaves alone: DW-1364 in mirror image, with the build green.
  const spaced = 'Parameter IDRULES = "web-application:foldcase-striptrailingslash, task:foldcase-striptrailingslash";';
  assert.deepEqual(parseIdRules(spaced), [
    ['web-application', 'foldcase-striptrailingslash'],
    [' task', 'foldcase-striptrailingslash'],
  ]);
  assert.throws(
    () => buildMirror({ ...readSources(), idRules: parseIdRules(spaced), idRuleNames: ['foldcase-striptrailingslash'] }),
    /entity type " task"/,
    'and the build names the stray space rather than mirroring past it'
  );

  // The rule half stops at the second colon, as `$Piece(pair, ":", 2)` does.
  assert.deepEqual(parseIdRules('Parameter IDRULES = "task:a:b";'), [['task', 'a']]);
});

test('AD-13: the generator refuses an id rule no reader can apply, naming the rule and the file', () => {
  const sources = readSources();
  const refusals = [
    {
      idRules: [['not-an-entity-type', 'foldcase-striptrailingslash']],
      idRuleNames: ['foldcase-striptrailingslash'],
      pattern: /not-an-entity-type/,
      why: 'a rule for a type outside the kernel enum',
    },
    {
      idRules: [['task', 'trim-whitespace']],
      idRuleNames: ['foldcase-striptrailingslash'],
      pattern: /IDRULENAMES does not declare/,
      why: 'a rule the kernel itself does not declare',
    },
    {
      idRules: [['task', 'trim-whitespace']],
      idRuleNames: ['foldcase-striptrailingslash', 'trim-whitespace'],
      pattern: /cannot implement on the client/,
      why: 'a rule this generator has no client implementation for',
    },
    {
      idRules: [
        ['web-application', 'foldcase-striptrailingslash'],
        ['web-application', 'foldcase-striptrailingslash'],
      ],
      idRuleNames: ['foldcase-striptrailingslash'],
      pattern: /declares two rules for entity type/,
      why: 'two pairs for one type, which the kernel resolves to the first and this to the last',
    },
  ];
  for (const { idRules, idRuleNames, pattern, why } of refusals) {
    assert.throws(
      () => buildMirror({ ...sources, idRules, idRuleNames }),
      (error) => {
        assert.match(error.message, /EntityRef\.cls/, `${why}: the refusal names the file`);
        assert.match(error.message, pattern, `${why}: and says what is wrong`);
        return true;
      },
      why
    );
  }

  // The roster the third refusal is judged against is the one `entity-ref.ts` is pinned equal to
  // by `ui/tools/entity-ref.test.mjs`, so neither side can grow a rule alone.
  assert.deepEqual(IMPLEMENTED_ID_RULES, ['foldcase-striptrailingslash', 'foldcase', 'singleton', 'integer']);
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

// AD-43 / DW-126: the chip substitutes its rate into the one published `Auto-refresh: every <n> s`
// string, so any sound ascending rate list is a rate list the command bar can name.
//
// Mutation (Rule 19): restore a refusal of any rate other than 10 in `buildMirror` -> the
// `[10, 30]` case below throws and this test goes red.
test('AD-43: the generator accepts any sound rate list, because the chip substitutes the rate', () => {
  const sources = readSources();
  const mirror = buildMirror({
    ...sources,
    screens: [
      {
        file: 'Fine.cls',
        className: 'OcuPilot.Screen.Descriptor.Fine',
        declaration: { refreshes: true, refreshRates: [10, 30] },
      },
      {
        file: 'None.cls',
        className: 'OcuPilot.Screen.Descriptor.None',
        declaration: {},
      },
    ],
  });
  assert.match(mirror, /"refreshRates": \[\s*10,\s*30\s*\]/, 'both rates reach the mirror');
});

// AD-43's other half: the pair itself. `OcuPilot.Screen.Registry.RefreshProblem` refuses these on
// the instance, which makes the container's start hook exit 1 (AD-38); refusing them here fails a
// developer's build instead, the way the entity-type and scope refusals above already do.
//
// Mutation (Rule 19): delete the `refreshProblem` call from `buildMirror` -> every `assert.throws`
// below stops throwing and this test goes red, while the shipped roster stays green either way --
// which is why the refusal needs fixtures rather than the roster as its subject.
test('AD-43: the generator refuses a malformed refresh pair', () => {
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

  // Sound, and stays sound: one rate, an ascending list, and the pair omitted entirely
  // by a descriptor written before the fields existed.
  assert.doesNotThrow(() => build({ refreshes: true, refreshRates: [10] }));
  assert.doesNotThrow(() => build({ refreshes: false, refreshRates: [] }));
  assert.doesNotThrow(() => build({}));
});

// AD-36: a declared read is refused here in the shapes `OcuPilot.Screen.Registry.ReadProblem`
// refuses on the instance, naming the file and the class. The sound declaration is JSON text, the
// form an XData declaration takes.
//
// Mutation (Rule 19): delete the `readProblem` call from `buildMirror` -> every refusal below stops
// throwing and this test goes red, while the shipped roster, which declares no read, stays green.
test('AD-36: the generator refuses a read outside the declared grammar, naming the file and the class', () => {
  const sources = readSources();
  const sound = () =>
    JSON.parse(
      '{"toolIdentifier": "webapp.canned", "context": {"fields": ["Name"], "secretFields": ["Secret"]},' +
        ' "id": {"kind": "single", "parts": []}, "primaryAction": {"id": "", "selfProtection": ""}, "rowActions": [],' +
        ' "emptyStateKey": "commandBoxNoMatch",' +
        ' "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],' +
        ' "read": {"source": {"port": "admin", "endpoint": "WebApp.App", "type": "LIST"},' +
        ' "fields": ["Name", "NameSpace", "Enabled", "Secret"], "filter": ["Name", "NameSpace"],' +
        ' "sort": {"fields": ["Name", "NameSpace"], "default": "Name", "direction": "asc"}, "paging": "cap"},' +
        ' "table": {"columns": [{"field": "Name", "labelKey": "fieldUserName", "kind": "name"},' +
        ' {"field": "NameSpace", "labelKey": "headerNamespaceLabel", "kind": "identifier"},' +
        ' {"field": "Enabled", "labelKey": "serverFlagLive", "kind": "status"}],' +
        ' "emptyNextKey": "classicLinkCardCaption", "emptyAgentKey": ""}}'
    );
  const build = (declaration) =>
    buildMirror({
      ...sources,
      screens: [{ file: 'Hostile.cls', className: 'OcuPilot.Screen.Descriptor.Hostile', declaration }],
    });

  assert.equal(readProblem(sound()), null, 'the sound read passes');
  assert.equal(readProblem({}), null, 'an absent read is a screen with no read');
  assert.equal(readProblem({ read: null }), null, 'and so is a null one');
  assert.equal(readProblem({ read: null, table: null }), null, 'with a null table');
  assert.match(build(sound()), /"paging": "cap"/, 'a sound read reaches the mirror');
  assert.match(build(sound()), /"emptyNextKey": "classicLinkCardCaption"/, 'and its table with it');

  const refused = [
    [(d) => d.read.filter.push('Missing'), /read\.filter names 'Missing'/],
    [(d) => d.read.sort.fields.push('Secret'), /read\.sort\.fields names the secret field 'Secret'/],
    [(d) => d.read.filter.push('Secret'), /read\.filter names the secret field 'Secret'/],
    [(d) => (d.read.paging = 'cursor'), /'cursor' is refused/],
    [(d) => (d.read.paging = 'pages'), /read\.paging 'pages' is not 'cap'/],
    [(d) => Object.assign(d, JSON.parse('{"toolIdentifier": "security.nosuch.detail"}')), /security\.nosuch\.detail/],
    [(d) => (d.read.fields = []), /read\.fields is empty/],
    [(d) => d.read.fields.push('Name'), /names 'Name' twice/],
    [(d) => (d.read.sort.default = 'Enabled'), /read\.sort\.default 'Enabled'/],
    [(d) => (d.read.sort.direction = 'up'), /direction 'up'/],
    [(d) => (d.read.source.port = 'metrics'), /port 'metrics'/],
    [(d) => (d.read.source.type = 'POST'), /type 'POST' is not 'LIST', 'GET', 'UPCOMING', 'HISTORY' or 'VOLUMELIST'/],
    [(d) => (d.context.secretFields = ['Other']), /context\.secretFields names 'Other'/],
    [(d) => (d.read.secretFields = ['Secret']), /read declares the unknown key 'secretFields'/],
    [(d) => (d.read.source.maxRows = 5), /read\.source declares the unknown key 'maxRows'/],
    [(d) => (d.read.sort.dir = 'asc'), /read\.sort declares the unknown key 'dir'/],
    [
      (d) => {
        d.context.secretfields = d.context.secretFields;
        delete d.context.secretFields;
      },
      /context declares the unknown key 'secretfields'/,
    ],
    [(d) => delete d.context.secretFields, /context\.secretFields is not an array/],
    [(d) => delete d.context, /context is not an object/],
    [(d) => (d.context.maxLength = { Nope: 5 }), /context\.maxLength names 'Nope'/],
    [(d) => (d.context.maxLength = { NameSpace: 5 }), /context\.maxLength names 'NameSpace'/],
    [(d) => (d.context.maxLength = { Name: 1001 }), /context\.maxLength\.Name is not a whole number/],
    [(d) => (d.context.maxLength = { Name: '5' }), /context\.maxLength\.Name is not a whole number/],
    [(d) => (d.context.maxLength = 5), /context\.maxLength is not an object/],
  ];
  for (const [mutate, message] of refused) {
    const declaration = sound();
    mutate(declaration);
    assert.throws(
      () => build(declaration),
      (error) => {
        assert.match(error.message, /Hostile\.cls/, 'the refusal names the file');
        assert.match(error.message, /OcuPilot\.Screen\.Descriptor\.Hostile/, 'and the class');
        assert.match(error.message, message);
        return true;
      },
      `expected ${message} to be refused`
    );
  }

  // context.maxLength is optional: absent, or explicitly null (as a descriptor's own JSON
  // round-trip can produce for an unset key), both pass; declared in range, it also passes.
  const withNull = sound();
  withNull.context.maxLength = null;
  assert.equal(readProblem(withNull), null, 'an explicit null maxLength passes, the same as absent');
  const withRange = sound();
  withRange.context.maxLength = { Name: 500 };
  assert.equal(readProblem(withRange), null, 'a maxLength in range passes');
});

// AD-36, Story 2.6 AC5: every case in `OcuPilot.Test.RowGetCorpus`, read off disk from the XData
// block `OcuPilot.Test.ReadTool` reads through the class dictionary, gets its exact sentence or `null`
// from `readProblem`; the users list passes, and the mirror emits its detail call.
test('readProblem returns every rowGet sentence OcuPilot.Test.RowGetCorpus declares, and the users list emits its rowGet', () => {
  const corpus = testCorpus(['Test', 'RowGetCorpus.cls'], 'Cases');
  assert.ok(corpus.cases.length > 0, `the corpus carries cases (read ${corpus.cases.length})`);
  for (const testCase of corpus.cases) {
    const declaration = structuredClone(corpus.declaration);
    declaration.read.source.rowGet = structuredClone(testCase.rowGet);
    assert.equal(readProblem(declaration), testCase.expected, testCase.name);
  }

  const users = readSources().screens.find((screen) => screen.className === 'OcuPilot.Screen.Descriptor.UserList');
  assert.ok(users !== undefined, 'the users list is declared');
  assert.equal(readProblem(users.declaration), null, 'and its read passes');
  const emittedScreens = JSON.parse(generate().split('export const SCREENS: readonly ScreenDeclaration[] = ')[1].replace(/;\s*$/, ''));
  const emitted = emittedScreens.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.UserList');
  assert.deepEqual(emitted.read.source.rowGet, {
    key: 'Name',
    param: 'name',
    fields: ['Roles', 'ExpirationDate'],
    derived: [{ field: 'Expired', rule: 'beforeToday', from: 'ExpirationDate' }],
  });

  // Story 6.3: the X.509 list's detail call declares CERTINFO, and the mirror carries it.
  const x509 = emittedScreens.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.X509CredentialList');
  assert.deepEqual(x509.read.source.rowGet, {
    key: 'Alias',
    param: 'alias',
    type: 'CERTINFO',
    fields: ['SubjectDN', 'IssuerDN', 'ValidityNotBefore', 'ValidityNotAfter'],
    derived: [],
  });
});

// Story 6.4, AD-36: every case in `OcuPilot.Test.ReadSourceCorpus`, read off disk from the XData block
// `OcuPilot.Test.ReadTool` reads through the class dictionary, gets its exact sentence or `null` from
// `readProblem`: a source's LIST, GET or UPCOMING type, its per-parent list and its fixed query
// (Story 6.5).
//
// Mutation (Rule 19): drop the `forEach` rowGet refusal from `forEachProblem` -> the "a parent list
// beside a detail call" case goes red.
//
// Story 6.9: a parts case may also override `fields`, `filter`, `sort`, `table` and `context`
// together, because the shared OAuth declaration's own fields cannot start with a declared
// `parts.as` -- see `OcuPilot.Test.ReadSourceCorpus.DeclarationFor`.
test('readProblem returns every source-type, forEach, query and parts sentence OcuPilot.Test.ReadSourceCorpus declares', () => {
  const corpus = testCorpus(['Test', 'ReadSourceCorpus.cls'], 'Cases');
  assert.ok(corpus.cases.length > 0, `the corpus carries cases (read ${corpus.cases.length})`);
  let refusals = 0;
  for (const testCase of corpus.cases) {
    const declaration = structuredClone(corpus.declaration);
    declaration.read.source = structuredClone(testCase.source);
    if (testCase.criteria !== undefined) declaration.read.criteria = structuredClone(testCase.criteria);
    if (testCase.parentScope !== undefined) declaration.parentScope = testCase.parentScope;
    if (testCase.fields !== undefined) declaration.read.fields = structuredClone(testCase.fields);
    if (testCase.filter !== undefined) declaration.read.filter = structuredClone(testCase.filter);
    if (testCase.sort !== undefined) declaration.read.sort = structuredClone(testCase.sort);
    if (testCase.table !== undefined) declaration.table = structuredClone(testCase.table);
    if (testCase.context !== undefined) declaration.context = structuredClone(testCase.context);
    assert.equal(readProblem(declaration), testCase.expected, testCase.name);
    if (testCase.expected !== null) refusals += 1;
  }
  assert.ok(refusals > 0, 'the corpus carries at least one refusing case');
});

// Story 6.4, AD-5: every case in `OcuPilot.Test.TabCorpus` gets its exact sentence or `null` from
// `tabProblem`, and every roster there from `tabGroupProblem`; and both refusals reach the generator.
//
// Mutation (Rule 19): drop the side-bar arm from `tabProblem` -> the two later-tab side-bar cases go
// red. Drop the `tabGroupProblem` call from `buildMirror` -> the roster-refusal assertion goes red.
test('tabProblem and tabGroupProblem return every sentence OcuPilot.Test.TabCorpus declares', () => {
  const corpus = testCorpus(['Test', 'TabCorpus.cls'], 'Cases');
  assert.ok(corpus.cases.length > 0 && corpus.rosters.length > 0, 'the corpus carries cases and rosters');
  let refusals = 0;
  for (const testCase of corpus.cases) {
    assert.equal(tabProblem(testCase.declaration), testCase.expected, testCase.name);
    if (testCase.expected !== null) refusals += 1;
  }
  for (const roster of corpus.rosters) {
    const screens = roster.screens.map((entry) => ({ className: entry.descriptor, declaration: entry.declaration }));
    assert.equal(tabGroupProblem(screens), roster.expected, roster.name);
    if (roster.expected !== null) refusals += 1;
  }
  assert.ok(refusals > 0, 'the corpus carries at least one refusing case');

  const sources = readSources();
  for (const screen of sources.screens) {
    assert.equal(tabProblem(screen.declaration), null, `${screen.className}'s tab passes`);
  }
  assert.equal(tabGroupProblem(sources.screens), null, 'and the shipped tab groups fit together');

  const oauth = sources.screens.find((screen) => screen.declaration.route === 'security/oauth');
  assert.ok(oauth !== undefined, 'the OAuth 2.0 screen is declared');
  const hostile = structuredClone(oauth.declaration);
  hostile.tab = { ...hostile.tab, position: 0 };
  assert.throws(
    () => buildMirror({ ...sources, screens: [{ file: 'Hostile.cls', className: 'OcuPilot.Screen.Descriptor.Hostile', declaration: hostile }] }),
    /Hostile\.cls \(OcuPilot\.Screen\.Descriptor\.Hostile\): tab\.position '0' is not a whole number of at least 1/
  );
  const gap = sources.screens.map((screen) =>
    screen.declaration.route === 'security/oauth/server'
      ? { ...screen, declaration: { ...screen.declaration, tab: { ...screen.declaration.tab, position: 6 } } }
      : screen
  );
  assert.throws(() => buildMirror({ ...sources, screens: gap }), /tab\.group 'security\/oauth' declares positions 1,2,3,5,6/);

  const emitted = JSON.parse(generate().split('export const SCREENS: readonly ScreenDeclaration[] = ')[1].replace(/;\s*$/, ''));
  const members = emitted
    .filter((screen) => screen.tab !== null)
    .sort((a, b) => a.tab.position - b.tab.position)
    .map((screen) => [screen.route, screen.tab.group, screen.tab.position, screen.sideBarPosition]);
  assert.deepEqual(members, [
    ['security/oauth', 'security/oauth', 1, 5],
    ['security/oauth/clients', 'security/oauth', 2, 0],
    ['security/oauth/resource-servers', 'security/oauth', 3, 0],
    ['security/oauth/server', 'security/oauth', 4, 0],
    ['security/oauth/server-clients', 'security/oauth', 5, 0],
  ]);
  assert.ok(emitted.every((screen) => 'tab' in screen), 'every screen emits tab, null when it is no tab');
});

/** The corpus declaration with `testCase`'s own `rowTarget`, `archetype` or `table`, mirroring `OcuPilot.Test.RowTargetCorpus.DeclarationFor`. */
function rowTargetDeclarationFor(corpus, testCase) {
  const declaration = structuredClone(corpus.declaration);
  if ('rowTarget' in testCase) declaration.rowTarget = structuredClone(testCase.rowTarget);
  if (testCase.archetype !== undefined) declaration.archetype = testCase.archetype;
  if ('table' in testCase) declaration.table = testCase.table;
  return declaration;
}

// AD-5, Story 6.10: every case in `OcuPilot.Test.RowTargetCorpus`'s `Cases` half gets its exact
// sentence, or none, from `rowTargetProblem`, and every roster in its `Rosters` half from
// `rowTargetResolutionProblem`; and both refusals reach the generator.
//
// Mutation (Rule 19): drop the "screen's own route" arm from `rowTargetProblem` -> the
// self-route case goes red. Drop the `rowTargetResolutionProblem` call from `buildMirror` -> the
// roster-refusal assertion goes red.
test('rowTargetProblem and rowTargetResolutionProblem return every sentence OcuPilot.Test.RowTargetCorpus declares', () => {
  const corpus = testCorpus(['Test', 'RowTargetCorpus.cls'], 'Cases');
  assert.ok(corpus.cases.length > 0, 'the corpus carries cases');
  let caseRefusals = 0;
  for (const testCase of corpus.cases) {
    const declaration = rowTargetDeclarationFor(corpus, testCase);
    assert.equal(rowTargetProblem(declaration), testCase.expected, testCase.name);
    if (testCase.expected !== null) caseRefusals += 1;
  }
  assert.ok(caseRefusals > 0, 'the Cases half carries at least one refusing case');

  // The corpus's own sound rowTarget carries exactly the declared nested vocabulary, so
  // ROW_TARGET_KEYS cannot gain, lose or rename a key on one side of the two engines without a
  // case going red -- the same tie this file holds for DECLARATION_KEYS.
  assert.deepEqual(
    Object.keys(corpus.declaration.rowTarget).sort(),
    [...ROW_TARGET_KEYS].sort(),
    "the corpus's sound rowTarget carries exactly the declared rowTarget vocabulary"
  );

  const rosters = testCorpus(['Test', 'RowTargetCorpus.cls'], 'Rosters');
  assert.ok(rosters.rosters.length > 0, 'the corpus carries rosters');
  let rosterRefusals = 0;
  for (const roster of rosters.rosters) {
    const screens = roster.screens.map((entry) => ({ className: entry.descriptor, declaration: entry.declaration }));
    assert.equal(rowTargetResolutionProblem(screens), roster.expected, roster.name);
    if (roster.expected !== null) rosterRefusals += 1;
  }
  assert.ok(rosterRefusals > 0, 'the Rosters half carries at least one refusing roster');

  const sources = readSources();
  for (const screen of sources.screens) {
    assert.equal(rowTargetProblem(screen.declaration), null, `${screen.className}'s rowTarget passes`);
  }
  assert.equal(rowTargetResolutionProblem(sources.screens), null, 'and the shipped rowTargets resolve');

  const locks = sources.screens.find((screen) => screen.declaration.route === 'os-management/locks');
  assert.ok(locks !== undefined, 'the Locks list is declared');
  const withLocks = (declaration) =>
    sources.screens.map((screen) => (screen.className === locks.className ? { ...screen, declaration } : screen));
  const hostile = structuredClone(locks.declaration);
  hostile.rowTarget = { ...hostile.rowTarget, field: 'Bogus' };
  assert.throws(
    () => buildMirror({ ...sources, screens: withLocks(hostile) }),
    /rowTarget\.field 'Bogus' is not one of read\.fields/
  );

  // And the roster-wide rule's own call site, which the shape refusal above reaches past: the
  // I/O matrix's own scenario, a mistyped target route. `rowTargetProblem` calls this sound --
  // the route is a non-empty string that is not this screen's own and the field is declared --
  // so only `rowTargetResolutionProblem` can refuse it.
  const unresolved = structuredClone(locks.declaration);
  unresolved.rowTarget = { ...unresolved.rowTarget, route: 'os-management/process/details' };
  assert.equal(rowTargetProblem(unresolved), null, 'a mistyped target route is a sound shape');
  assert.throws(
    () => buildMirror({ ...sources, screens: withLocks(unresolved) }),
    /rowTarget\.route 'os-management\/process\/details' names no declared screen \(AD-5\)/
  );

  const emitted = JSON.parse(generate().split('export const SCREENS: readonly ScreenDeclaration[] = ')[1].replace(/;\s*$/, ''));
  const emittedLocks = emitted.find((screen) => screen.route === 'os-management/locks');
  assert.deepEqual(emittedLocks.rowTarget, { route: 'os-management/processes/details', field: 'Pid' });
  assert.ok(emitted.every((screen) => 'rowTarget' in screen), 'every screen emits rowTarget, null when it declares none');
});

// Story 6.6 (DW-1020): `parentScopeResolutionProblem` refuses a built descriptor's `parentScope`
// that names no built descriptor with that route and an id, over the four ways that can happen --
// the route is not declared at all, it is declared but not built, it is declared and built but
// carries `id.kind` `none`, and it names the checked descriptor's own route -- and passes a roster
// of only sound declarations. The sentences are byte for byte
// `OcuPilot.Screen.Registry.ParentScopeResolutionProblem`'s own, exercised there by
// `OcuPilot.Test.ParentScopeNotFoundRegistry`, `ParentScopeNotBuiltRegistry`,
// `ParentScopeNoIdRegistry` and `ParentScopeSelfRegistry` over the equivalent fixture routes and
// parentScope values.
//
// Mutation (Rule 19): make `parentScopeResolutionProblem` return `null` unconditionally -> every
// refusing case below goes red.
test('parentScopeResolutionProblem refuses a parentScope that does not resolve, and passes a sound roster', () => {
  const notFound = [{ className: 'OcuPilot.Test.ParentScope.NotFound.Child', declaration: { built: true, route: 'parent-scope/not-found/child', parentScope: 'parent-scope/not-found/nonexistent', id: { kind: 'single' } } }];
  assert.equal(
    parentScopeResolutionProblem(notFound),
    "OcuPilot.Test.ParentScope.NotFound.Child: parentScope 'parent-scope/not-found/nonexistent' names no built descriptor with that route and an id (DW-1020)",
    'a parentScope naming a route nothing declares is refused'
  );

  const notBuilt = [
    { className: 'OcuPilot.Test.ParentScope.NotBuilt.Parent', declaration: { built: false, route: 'parent-scope/not-built/parent', parentScope: '', id: { kind: 'single' } } },
    { className: 'OcuPilot.Test.ParentScope.NotBuilt.Child', declaration: { built: true, route: 'parent-scope/not-built/child', parentScope: 'parent-scope/not-built/parent', id: { kind: 'single' } } },
  ];
  assert.equal(
    parentScopeResolutionProblem(notBuilt),
    "OcuPilot.Test.ParentScope.NotBuilt.Child: parentScope 'parent-scope/not-built/parent' names no built descriptor with that route and an id (DW-1020)",
    'a parentScope naming a route that is declared but not built is refused'
  );

  const noId = [
    { className: 'OcuPilot.Test.ParentScope.NoId.Parent', declaration: { built: true, route: 'parent-scope/no-id/parent', parentScope: '', id: { kind: 'none' } } },
    { className: 'OcuPilot.Test.ParentScope.NoId.Child', declaration: { built: true, route: 'parent-scope/no-id/child', parentScope: 'parent-scope/no-id/parent', id: { kind: 'single' } } },
  ];
  assert.equal(
    parentScopeResolutionProblem(noId),
    "OcuPilot.Test.ParentScope.NoId.Child: parentScope 'parent-scope/no-id/parent' names no built descriptor with that route and an id (DW-1020)",
    'a parentScope naming a built route with id.kind none is refused'
  );
  const emptyKind = [{ ...noId[0], declaration: { ...noId[0].declaration, id: { kind: '' } } }, noId[1]];
  assert.equal(
    parentScopeResolutionProblem(emptyKind),
    "OcuPilot.Test.ParentScope.NoId.Child: parentScope 'parent-scope/no-id/parent' names no built descriptor with that route and an id (DW-1020)",
    "and so is one whose id.kind is empty, as the server's twin reads an empty kind"
  );

  const self = [{ className: 'OcuPilot.Test.ParentScope.Self.Child', declaration: { built: true, route: 'parent-scope/self/child', parentScope: 'parent-scope/self/child', id: { kind: 'single' } } }];
  assert.equal(
    parentScopeResolutionProblem(self),
    "OcuPilot.Test.ParentScope.Self.Child: parentScope 'parent-scope/self/child' names no built descriptor with that route and an id (DW-1020)",
    'a parentScope naming its own route cannot resolve against itself'
  );

  const sound = [
    { className: 'OcuPilot.Test.ParentScope.Sound.Parent', declaration: { built: true, route: 'parent-scope/sound/parent', parentScope: '', id: { kind: 'single' } } },
    { className: 'OcuPilot.Test.ParentScope.Sound.Child', declaration: { built: true, route: 'parent-scope/sound/child', parentScope: 'parent-scope/sound/parent', id: { kind: 'single' } } },
    { className: 'OcuPilot.Test.ParentScope.Sound.NoParent', declaration: { built: true, route: 'parent-scope/sound/no-parent', parentScope: '', id: { kind: 'single' } } },
  ];
  assert.equal(parentScopeResolutionProblem(sound), null, 'a roster of resolving and empty parentScope declarations passes');

  const sources = readSources();
  assert.equal(parentScopeResolutionProblem(sources.screens), null, 'and the shipped roster resolves too');
});

// DW-264, Story 2.7 AC5: every case in `OcuPilot.Test.AdminPairCorpus`, read off disk from the
// XData block `OcuPilot.Test.ReadTool` reads through the class dictionary, gets its exact sentence
// or `null` from `readProblem`; and the three shipped admin-port lists pass.
//
// Mutation (Rule 19): make the `source.port === 'admin'` arm of `readProblem` unreachable -> every
// refusing case below goes red, while the shipped roster stays green either way.
test('readProblem returns every admin-privilege sentence OcuPilot.Test.AdminPairCorpus declares', () => {
  const corpus = testCorpus(['Test', 'AdminPairCorpus.cls'], 'Cases');
  assert.ok(corpus.cases.length > 0, `the corpus carries cases (read ${corpus.cases.length})`);
  let refusals = 0;
  for (const testCase of corpus.cases) {
    const declaration = structuredClone(corpus.declaration);
    declaration.privileges = structuredClone(testCase.privileges);
    if (typeof testCase.port === 'string') declaration.read.source.port = testCase.port;
    if (testCase.rowGet !== null && typeof testCase.rowGet === 'object') declaration.read.source.rowGet = structuredClone(testCase.rowGet);
    if (testCase.readless) {
      declaration.read = null;
      declaration.table = null;
    }
    assert.equal(readProblem(declaration), testCase.expected, testCase.name);
    if (testCase.expected !== null) refusals += 1;
  }
  assert.ok(refusals > 0, 'the corpus carries at least one refusing case');

  // Shapes the corpus cannot express, because its cases add and drop keys on an object.
  // Both engines answer the same sentence, which is what the two-engine rule requires.
  assert.equal(declarationProblem([]), 'the declaration is not an object', 'an array is not a declaration');
  assert.equal(declarationProblem(''), 'the declaration is not an object', 'and neither is a string');

  const { screens } = readSources();
  for (const name of ['AuditList', 'ProcessList', 'SslConfigList', 'TaskScheduleList', 'UserList', 'WebAppList', 'RestApiList', 'OpenApiViewer', 'RoleList', 'ResourceList', 'ServiceList', 'X509CredentialList', 'LdapConfigList', 'WalletCollectionList', 'WalletSecretList', 'OAuthServerDescriptionTab', 'OAuthClientTab', 'OAuthResourceServerTab', 'OAuthServerTab', 'OAuthServerClientTab', 'TaskOnDemandList', 'TaskUpcomingList']) {
    const screen = screens.find((candidate) => candidate.className === `OcuPilot.Screen.Descriptor.${name}`);
    assert.ok(screen !== undefined, `${name} is declared`);
    assert.equal(readProblem(screen.declaration), null, `${name}'s read passes`);
  }
  // Story 6.5: the two source shapes the mirror carries -- the vendor's fixed onDemand and the
  // UPCOMING request type.
  const onDemand = screens.find((candidate) => candidate.className === 'OcuPilot.Screen.Descriptor.TaskOnDemandList');
  assert.deepEqual(onDemand.declaration.read.source, { port: 'admin', endpoint: 'Task.CRUD', type: 'LIST', query: { onDemand: '1' } });
  const upcoming = screens.find((candidate) => candidate.className === 'OcuPilot.Screen.Descriptor.TaskUpcomingList');
  assert.equal(upcoming.declaration.read.source.type, 'UPCOMING');
  // Story 2.12: a descriptor that declares NO read is a supported shape, and the generator has to
  // emit it rather than refuse it -- the declared-read pipeline is admin-port-only by two
  // independent hard-codings, so the application error log could not use it whatever port it
  // named. Asserted here beside the six that do declare one, so "no read passes" is a claim about
  // the rule rather than about a descriptor nobody looked at.
  const readless = screens.find(
    (candidate) => candidate.className === 'OcuPilot.Screen.Descriptor.LogErrorList'
  );
  assert.ok(readless !== undefined, 'LogErrorList is declared');
  assert.equal(readless.declaration.read, undefined, 'and declares no read at all');
  assert.equal(readless.declaration.table, undefined, 'and no table either');
  assert.equal(readProblem(readless.declaration), null, 'which the read grammar admits');
});

// Story 6.2: every case in `OcuPilot.Test.ColumnCorpus`, read off disk from the XData block
// `OcuPilot.Test.ReadTool` reads through the class dictionary, gets its exact sentence or `null` from
// `readProblem`; the Services list's declared `emptyKey` passes and reaches the mirror; and a refused
// one reaches the generator naming the file and the class.
//
// Mutation (Rule 19): drop the `emptyKey` arm from `tableProblem` -> the corpus run goes red on its
// first refusing value case, "an empty emptyKey is refused".
test('readProblem returns every column emptyKey sentence OcuPilot.Test.ColumnCorpus declares', () => {
  const corpus = testCorpus(['Test', 'ColumnCorpus.cls'], 'Cases');
  assert.ok(corpus.cases.length > 0, `the corpus carries cases (read ${corpus.cases.length})`);
  let refusals = 0;
  for (const testCase of corpus.cases) {
    const declaration = structuredClone(corpus.declaration);
    declaration.table.columns[1] = structuredClone(testCase.column);
    assert.equal(readProblem(declaration), testCase.expected, testCase.name);
    if (testCase.expected !== null) refusals += 1;
  }
  assert.ok(refusals > 0, 'the corpus carries at least one refusing case');

  const sources = readSources();
  const services = sources.screens.find((screen) => screen.className === 'OcuPilot.Screen.Descriptor.ServiceList');
  assert.ok(services !== undefined, 'ServiceList is declared');
  const allowed = services.declaration.table.columns.find((column) => column.field === 'AllowedConnections');
  assert.equal(allowed.emptyKey, 'serviceAllowedUnrestricted', 'its Allowed IP addresses column declares the Unrestricted key');
  const emitted = JSON.parse(
    readCheckedInMirror().match(/export const SCREENS: readonly ScreenDeclaration\[\] = (\[[\s\S]*?\n\]);/)[1]
  ).find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.ServiceList');
  assert.equal(
    emitted.table.columns.find((column) => column.field === 'AllowedConnections').emptyKey,
    'serviceAllowedUnrestricted',
    'and the checked-in mirror carries it'
  );

  const hostile = structuredClone(services.declaration);
  hostile.table.columns.find((column) => column.field === 'AllowedConnections').emptyKey = '';
  assert.throws(
    () => buildMirror({ ...sources, screens: [{ file: 'Hostile.cls', className: 'OcuPilot.Screen.Descriptor.Hostile', declaration: hostile }] }),
    (error) => {
      assert.match(error.message, /Hostile\.cls/, 'the refusal names the file');
      assert.match(error.message, /OcuPilot\.Screen\.Descriptor\.Hostile/, 'and the class');
      assert.match(error.message, /entry #4 emptyKey is not a non-empty string key/);
      return true;
    }
  );
});

// AD-21, Story 2.10: every case in `OcuPilot.Test.CriteriaCorpus`, read off disk from the XData
// block `OcuPilot.Test.ReadTool` reads through the class dictionary, gets its exact sentence or
// `null` from `criteriaProblem`; every shipped descriptor passes; and the one that declares a
// criteria block emits it.
//
// Mutation (Rule 19): delete the `criteriaProblem` call from `buildMirror` -> the "reaches the
// generator" assertion at the end goes red while the corpus run stays green, which is what
// distinguishes the rule from its wiring. Drop `options` from the corpus declaration's own choice
// field -> the missing-options case goes red in both engines.
test('criteriaProblem returns every sentence OcuPilot.Test.CriteriaCorpus declares, and the audit list emits its criteria', () => {
  const corpus = testCorpus(['Test', 'CriteriaCorpus.cls'], 'Cases');
  assert.ok(corpus.cases.length > 0, `the corpus carries cases (read ${corpus.cases.length})`);
  let refusals = 0;
  for (const testCase of corpus.cases) {
    const declaration = structuredClone(corpus.declaration);
    declaration.read.criteria = structuredClone(testCase.criteria);
    if (typeof testCase.refreshes === 'boolean') declaration.refreshes = testCase.refreshes;
    if (typeof testCase.port === 'string') declaration.read.source.port = testCase.port;
    if (typeof testCase.parentScope === 'string') declaration.parentScope = testCase.parentScope;
    assert.equal(criteriaProblem(declaration), testCase.expected, testCase.name);
    if (testCase.expected !== null) refusals += 1;
  }
  assert.ok(refusals > 0, 'the corpus carries at least one refusing case');

  const { screens } = readSources();
  for (const screen of screens) {
    assert.equal(criteriaProblem(screen.declaration), null, `${screen.className}'s criteria pass`);
  }

  const emittedScreens = JSON.parse(
    generate().split('export const SCREENS: readonly ScreenDeclaration[] = ')[1].replace(/;\s*$/, '')
  );
  const audit = emittedScreens.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.AuditList');
  assert.ok(audit !== undefined, 'the audit database list is declared');
  assert.deepEqual(
    audit.read.criteria.fields.map((field) => field.param),
    [
      'beginDateTime',
      'endDateTime',
      'eventSources',
      'eventTypes',
      'events',
      'usernames',
      'pids',
      'namespaces',
      'authentication',
    ],
    'the eight criteria FR-61 names, over nine parameters, in declaration order'
  );
  assert.deepEqual(audit.read.criteria.marker, {
    param: 'eventSources',
    value: 'OcuPilot',
    labelKey: 'auditMarkerFilterLabel',
  });
  // The marker names a criterion the form carries, which is what makes it an override rather than
  // a tenth parameter -- the rule `criteriaProblem` refuses a marker outside the fields for.
  assert.ok(
    audit.read.criteria.fields.some((field) => field.param === audit.read.criteria.marker.param),
    'and it overrides one of them'
  );
  // Every other shipped screen declares none but the OpenAPI document viewer, whose one criterion
  // names the application its document is read for; Process details, whose one criterion is
  // Story 6.8's route-id pid; Task details, Task history (all) and Task history (one task), whose
  // criteria are Story 6.7's and 6.6's; Upcoming tasks, whose two criteria are the horizon; the
  // Secrets list, whose one criterion is its parent collection, filled from the route id
  // (Story 6.3); and Story 6.11's two -- Database details and Database volumes, whose one
  // criterion each is the parent Databases route's directory.
  const withCriteria = emittedScreens.filter((screen) => (screen.read?.criteria ?? null) !== null);
  assert.deepEqual(
    withCriteria.map((screen) => screen.descriptor),
    [
      'OcuPilot.Screen.Descriptor.AuditList',
      'OcuPilot.Screen.Descriptor.DatabaseDetails',
      'OcuPilot.Screen.Descriptor.DatabaseVolumeList',
      'OcuPilot.Screen.Descriptor.OpenApiViewer',
      'OcuPilot.Screen.Descriptor.ProcessDetails',
      'OcuPilot.Screen.Descriptor.TaskDetails',
      'OcuPilot.Screen.Descriptor.TaskHistoryList',
      'OcuPilot.Screen.Descriptor.TaskRunList',
      'OcuPilot.Screen.Descriptor.TaskUpcomingList',
      'OcuPilot.Screen.Descriptor.WalletSecretList',
    ]
  );
  const secrets = emittedScreens.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.WalletSecretList');
  assert.equal(secrets.parentScope, 'security/wallet', 'the Secrets list declares its parent');
  assert.deepEqual(secrets.read.criteria.fields.map((field) => field.param), ['collection'], 'and exactly one criterion');

  // The refusal reaches the generator, naming the file and the class, as every other one does.
  // `descriptor` is dropped first: it is a key the emission adds, not one a declaration carries,
  // and the top-level key check DW-271 added would otherwise refuse this clone before the criteria
  // rule ran.
  const hostile = structuredClone(audit);
  delete hostile.descriptor;
  hostile.read.criteria.fields[8] = { ...hostile.read.criteria.fields[8], options: [] };
  assert.throws(
    () =>
      buildMirror({
        ...readSources(),
        screens: [{ file: 'Hostile.cls', className: 'OcuPilot.Screen.Descriptor.Hostile', declaration: hostile }],
      }),
    /Hostile\.cls \(OcuPilot\.Screen\.Descriptor\.Hostile\): read\.criteria\.fields entry #9 options is empty/
  );
});

// Story 2.8: every case in `OcuPilot.Test.BannerCorpus`, read off disk from the XData block
// `OcuPilot.Test.ReadTool` reads through the class dictionary, gets its exact sentence or `null`
// from `bannerProblem`; the task schedule list's own banner passes and reaches the mirror; and
// every other shipped descriptor, none of which declares one, passes too.
//
// Mutation (Rule 19): delete the `bannerProblem` call from `buildMirror` -> the "reaches the
// generator" assertion goes red while the corpus run stays green, which is what distinguishes the
// rule from its wiring.
test('bannerProblem returns every sentence OcuPilot.Test.BannerCorpus declares, and the task schedule list emits its banner', () => {
  const corpus = testCorpus(['Test', 'BannerCorpus.cls'], 'Cases');
  assert.ok(corpus.cases.length > 0, `the corpus carries cases (read ${corpus.cases.length})`);
  let refusals = 0;
  for (const testCase of corpus.cases) {
    const declaration = structuredClone(corpus.declaration);
    declaration.banner = structuredClone(testCase.banner);
    if (testCase.readless) {
      declaration.read = null;
      declaration.table = null;
    }
    assert.equal(bannerProblem(declaration), testCase.expected, testCase.name);
    if (testCase.expected !== null) refusals += 1;
  }
  assert.ok(refusals > 0, 'the corpus carries at least one refusing case');

  const { screens } = readSources();
  for (const screen of screens) {
    assert.equal(bannerProblem(screen.declaration), null, `${screen.className}'s banner passes`);
  }

  const emittedScreens = JSON.parse(
    generate().split('export const SCREENS: readonly ScreenDeclaration[] = ')[1].replace(/;\s*$/, '')
  );
  const tasks = emittedScreens.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.TaskScheduleList');
  assert.ok(tasks !== undefined, 'the task schedule list is declared');
  assert.deepEqual(tasks.banner, {
    source: { port: 'admin', endpoint: 'Task.Manager', type: 'GET' },
    field: 'Status',
    // Two cases over one field and one read (DW-270): the Task Manager is suspended, or it is
    // stopped -- `Not running` is the vendor's own word for status 0 -- and `Running` raises none.
    cases: [
      { equals: 'Suspended', messageKey: 'taskManagerSuspendedBanner', severity: 'warning' },
      { equals: 'Not running', messageKey: 'taskManagerStoppedBanner', severity: 'warning' },
    ],
  });
  for (const screen of emittedScreens) {
    if (screen.descriptor === 'OcuPilot.Screen.Descriptor.TaskScheduleList') continue;
    assert.equal(screen.banner, null, `${screen.descriptor} emits no banner`);
  }

  // The refusal reaches the generator, naming the file and the class, as every other one does.
  // `descriptor` is dropped first: it is a key the emission adds, not one a declaration carries,
  // and the top-level key check DW-271 added would otherwise refuse this clone before the banner
  // rule ran.
  const hostile = structuredClone(tasks);
  delete hostile.descriptor;
  hostile.banner = { ...hostile.banner, cases: [{ ...hostile.banner.cases[0], severity: 'error' }] };
  assert.throws(
    () =>
      buildMirror({
        ...readSources(),
        screens: [{ file: 'Hostile.cls', className: 'OcuPilot.Screen.Descriptor.Hostile', declaration: hostile }],
      }),
    /Hostile\.cls \(OcuPilot\.Screen\.Descriptor\.Hostile\): banner\.cases entry #1 severity 'error' is not one of/
  );
});

// Story 2.8: both engines justify the closed severity set as "what the client can actually draw",
// and `ListPage.bannerClass` composes `ocu-banner-${severity}` blind -- so a member with no rule
// behind it ships an unstyled strip with every gate green. This is the assertion that makes the
// justification falsifiable: the set and the stylesheet are held equal in both directions.
//
// Mutations (Rule 19): add a fourth member to `BANNER_SEVERITIES` -> the missing-rule assertion
// goes red; delete `.ocu-banner-restrained` from `_components.scss` -> it goes red too, and
// removing a member instead while leaving its rule reddens the converse assertion.
test('every declared banner severity has a .ocu-banner- rule in the stylesheet, and every such rule is a declared severity', () => {
  const components = readFileSync(join(toolsDir, '..', 'src', 'styles', '_components.scss'), 'utf8');
  // A severity variant is a `.ocu-banner-<name>` rule that paints the strip. `.ocu-banner-glyph`
  // and `.ocu-banner-message` share the prefix but are the strip's parts, not variants of it, and
  // neither sets a background -- which is exactly what a severity is for.
  const styled = new Set(
    [...components.matchAll(/^\.ocu-banner-([a-z]+)\s*\{([^}]*)\}/gm)]
      .filter((match) => match[2].includes('background:'))
      .map((match) => match[1])
  );
  assert.ok(styled.size > 0, 'the stylesheet carries banner variants at all');
  assert.deepEqual(
    BANNER_SEVERITIES.filter((severity) => !styled.has(severity)),
    [],
    `every declared severity has a rule; the stylesheet carries ${[...styled].sort().join(', ')}`
  );
  assert.deepEqual(
    [...styled].filter((variant) => !BANNER_SEVERITIES.includes(variant)).sort(),
    [],
    'and no variant is styled that a declaration may not name'
  );
});

// AD-35, Story 2.7 AC3: no shipped read ever names a field the project's own credential vocabulary
// matches, whatever its endpoint. `context.secretFields` is the schema-driven redaction and this is
// the name-pattern backstop over every place a field name reaches a caller (Conventions,
// Secrets) -- it can only add a refusal, never remove one. `CREDENTIAL_RE` is suffix-anchored, so
// it is a backstop over that vocabulary and not a list of every key-material name: of the six AC3
// enumerates it matches `PrivateKeyPassword` alone, and `OcuPilot.Test.Descriptor` pins all six by
// name for this screen's declaration.
//
// `context.fields` is covered alongside AC3's four read surfaces because it is a field name the
// agent context carries (AD-24) and nothing constrains it to `read.fields`; `context.secretFields`
// is not, because naming key material there is what it is for.
//
// Mutation (Rule 19): rename a production column field to `ApiKey` -> this goes red naming the
// descriptor and the field.
test('AD-35: no production descriptor names a read, filter, sort, column or context field matching the credential pattern', () => {
  const { screens } = readSources();
  const offenders = [];
  let checked = 0;
  for (const screen of screens) {
    const { read, table, context } = screen.declaration;
    if (read === undefined || read === null) continue;
    checked += 1;
    const named = [
      ...(read.fields ?? []).map((field) => ['read.fields', field]),
      ...(read.filter ?? []).map((field) => ['read.filter', field]),
      ...(read.sort?.fields ?? []).map((field) => ['read.sort.fields', field]),
      ...(table?.columns ?? []).map((column) => ['table.columns', column.field]),
      ...(context?.fields ?? []).map((field) => ['context.fields', field]),
    ];
    for (const [where, field] of named) {
      if (typeof field === 'string' && CREDENTIAL_RE.test(field)) offenders.push(`${screen.file} ${where}: ${field}`);
    }
  }
  assert.ok(checked > 0, `at least one shipped descriptor declares a read: ${checked}`);
  assert.deepEqual(offenders, [], `credential-shaped field names on a read surface: ${JSON.stringify(offenders)}`);
  assert.ok(CREDENTIAL_RE.test('PrivateKeyPassword'), 'the pattern matches a password-suffixed field name');
  assert.equal(CREDENTIAL_RE.test('Description'), false, 'and not an ordinary column');
});

// AD-5: the table a read renders in, refused here in the shapes `OcuPilot.Screen.Registry.TableProblem`
// refuses on the instance, one refusal per grammar matrix row and the neighbouring shapes.
//
// Mutation (Rule 19): drop the exactly-one-name check from `tableProblem` -> the two-name-columns
// and no-name-column rows below stop throwing and this test goes red.
test('AD-5: the generator refuses a table outside the declared grammar, naming the file and the class', () => {
  const sources = readSources();
  const sound = () =>
    JSON.parse(
      '{"toolIdentifier": "webapp.canned", "context": {"fields": ["Name"], "secretFields": []},' +
        ' "id": {"kind": "single", "parts": []}, "primaryAction": {"id": "", "selfProtection": ""}, "rowActions": [],' +
        ' "emptyStateKey": "commandBoxNoMatch",' +
        ' "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],' +
        ' "read": {"source": {"port": "admin", "endpoint": "WebApp.App", "type": "LIST"},' +
        ' "fields": ["Name", "NameSpace", "Enabled"], "filter": ["Name"],' +
        ' "sort": {"fields": ["Name"], "default": "Name", "direction": "asc"}, "paging": "cap"},' +
        ' "table": {"columns": [{"field": "Name", "labelKey": "fieldUserName", "kind": "name"},' +
        ' {"field": "NameSpace", "labelKey": "headerNamespaceLabel", "kind": "identifier"},' +
        ' {"field": "Enabled", "labelKey": "serverFlagLive", "kind": "status"}],' +
        ' "emptyNextKey": "classicLinkCardCaption", "emptyAgentKey": ""}}'
    );
  const build = (declaration) =>
    buildMirror({
      ...sources,
      screens: [{ file: 'Hostile.cls', className: 'OcuPilot.Screen.Descriptor.Hostile', declaration }],
    });

  assert.equal(readProblem(sound()), null, 'the sound table passes');
  const writeCapable = sound();
  writeCapable.primaryAction.id = 'create';
  writeCapable.table.emptyNextKey = '';
  writeCapable.table.emptyAgentKey = 'classicLinkCardCaption';
  assert.equal(readProblem(writeCapable), null, 'and so does the agent key on a write-capable declaration');
  const composite = sound();
  composite.id = { kind: 'composite', parts: ['NameSpace', 'Name'] };
  assert.equal(readProblem(composite), null, 'and a composite id over declared fields');

  const refused = [
    [(d) => delete d.table, /table is not an object/],
    [(d) => (d.table.columns[0].field = 'Missing'), /field 'Missing' is not one of read\.fields/],
    [(d) => (d.table.columns[1].kind = 'name'), /declares 2 name column\(s\)/],
    [(d) => (d.table.columns[0].kind = 'identifier'), /declares 0 name column\(s\)/],
    [(d) => (d.table.columns[2].kind = 'boolean'), /kind 'boolean'/],
    [(d) => d.table.columns.push({ field: 'Name', labelKey: 'fieldUserName', kind: 'text' }), /names the field 'Name' twice/],
    [(d) => (d.context.secretFields = ['Enabled']), /entry #3 field 'Enabled' is a secret field/],
    [(d) => (d.table.columns[0].labelKey = ''), /labelKey is empty/],
    [(d) => (d.table.columns = []), /table\.columns is empty/],
    [(d) => (d.table.columns[0].width = 3), /entry #1 declares the unknown key 'width'/],
    [(d) => (d.table.sort = 'Name'), /table declares the unknown key 'sort'/],
    [(d) => (d.rowActions = [{ id: 'disable', selfProtection: '' }]), /emptyNextKey is declared on a write-capable descriptor/],
    [(d) => (d.table.emptyAgentKey = 'classicLinkCardCaption'), /emptyAgentKey is declared on a descriptor with no primary or row action/],
    [(d) => (d.table.emptyNextKey = ''), /emptyNextKey is empty/],
    [(d) => ((d.primaryAction.id = 'create'), (d.table.emptyNextKey = '')), /emptyAgentKey is empty on a write-capable descriptor/],
    [(d) => (d.id = { kind: 'composite', parts: ['NameSpace', 'Path'] }), /id\.parts names 'Path'/],
    [(d) => (d.emptyStateKey = ''), /emptyStateKey is empty/],
    [(d) => (d.read = null), /table is declared while read is not/],
  ];
  for (const [mutate, message] of refused) {
    const declaration = sound();
    mutate(declaration);
    assert.throws(
      () => build(declaration),
      (error) => {
        assert.match(error.message, /Hostile\.cls/, 'the refusal names the file');
        assert.match(error.message, /OcuPilot\.Screen\.Descriptor\.Hostile/, 'and the class');
        assert.match(error.message, message);
        return true;
      },
      `expected ${message} to be refused`
    );
  }
});

test('the mirror emits table as null for a screen that declares none', () => {
  const shipped = JSON.parse(
    readCheckedInMirror().match(/export const SCREENS: readonly ScreenDeclaration\[\] = (\[[\s\S]*?\n\]);/)[1]
  );
  const readless = shipped.filter((screen) => screen.read === null);
  assert.ok(readless.length > 0, 'the shipped mirror carries a screen that declares no read');
  for (const screen of readless) assert.equal(screen.table, null, `${screen.descriptor} declares no table`);
  for (const screen of shipped.filter((candidate) => candidate.read !== null)) {
    assert.notEqual(screen.table, null, `${screen.descriptor} declares a read, so it declares its table`);
  }
  assert.match(readCheckedInMirror(), /readonly table: TableDeclaration \| null;/, 'and the interface declares it');
});

// A screen read resolves its descriptor by `toolIdentifier`, so two descriptors declaring one are
// refused here as `OcuPilot.Screen.Registry.Validate` refuses them, naming both classes.
test('AD-5: the generator refuses a toolIdentifier two descriptors declare, naming both classes', () => {
  const sources = readSources();
  const twin = (name) => ({
    file: `${name}.cls`,
    className: `OcuPilot.Screen.Descriptor.${name}`,
    declaration: JSON.parse(
      '{"toolIdentifier": "webapp.twin", "context": {"fields": ["Name"], "secretFields": []},' +
        ' "emptyStateKey": "commandBoxNoMatch",' +
        ' "privileges": [{"resource": "%DB_IRISSYS", "permission": "READ"}],' +
        ' "read": {"source": {"port": "admin", "endpoint": "WebApp.App", "type": "LIST"},' +
        ' "fields": ["Name"], "filter": ["Name"],' +
        ' "sort": {"fields": ["Name"], "default": "Name", "direction": "asc"}, "paging": "cap"},' +
        ' "table": {"columns": [{"field": "Name", "labelKey": "fieldUserName", "kind": "name"}],' +
        ' "emptyNextKey": "classicLinkCardCaption", "emptyAgentKey": ""}}'
    ),
  });
  assert.doesNotThrow(() => buildMirror({ ...sources, screens: [twin('One')] }), 'one declaration of the identifier is sound');
  assert.throws(
    () => buildMirror({ ...sources, screens: [twin('One'), twin('Two')] }),
    (error) => {
      assert.match(error.message, /OcuPilot\.Screen\.Descriptor\.One/, 'the refusal names the first class');
      assert.match(error.message, /OcuPilot\.Screen\.Descriptor\.Two/, 'and the second');
      assert.match(error.message, /toolIdentifier 'webapp\.twin'/);
      return true;
    }
  );
});

test('the mirror emits read as null for a screen that declares none', () => {
  const shipped = JSON.parse(
    readCheckedInMirror().match(/export const SCREENS: readonly ScreenDeclaration\[\] = (\[[\s\S]*?\n\]);/)[1]
  );
  for (const screen of shipped) {
    assert.ok('read' in screen, `${screen.descriptor} emits read`);
  }
  assert.equal(shipped.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.Home').read, null);
  assert.match(readCheckedInMirror(), /readonly read: ReadDeclaration \| null;/, 'and the interface declares it');
});

test('a shipped descriptor that does not refresh permits no rate', () => {
  const { screens } = readSources();
  for (const screen of screens) {
    if (screen.declaration.refreshes !== true) {
      assert.deepEqual(
        screen.declaration.refreshRates ?? [],
        [],
        `${screen.file} permits a rate while declaring it does not refresh`
      );
    }
  }
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

/** A temporary descriptor directory holding one `.cls` per entry, removed after `run`. */
function withDescriptorDir(files, run) {
  const dir = mkdtempSync(join(tmpdir(), 'ocupilot-screen-mirror-'));
  try {
    for (const [name, text] of Object.entries(files)) writeFileSync(join(dir, name), text);
    return run(dir);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

/** A descriptor source whose `XData Declaration` body is `bodyLines`, in the two-line UDL form. */
function descriptorSource(className, bodyLines) {
  return [
    `Class OcuPilot.Screen.Descriptor.${className} Extends OcuPilot.Screen.Descriptor.Base`,
    '{',
    '',
    'XData Declaration',
    '{',
    ...bodyLines,
    '}',
    '',
    '}',
  ].join('\n');
}

test('a brace inside a JSON string does not end the block: readSources reads the whole declaration', () => {
  const screens = withDescriptorDir(
    {
      'Braced.cls': descriptorSource('Braced', [
        '{',
        '"reason": "a } brace",',
        '"route": "braced/after"',
        '}',
      ]),
    },
    (dir) => readSources({ descriptorDir: dir }).screens
  );

  assert.equal(screens.length, 1);
  assert.equal(screens[0].declaration.reason, 'a } brace', 'the string is carried verbatim');
  assert.equal(screens[0].declaration.route, 'braced/after', 'and the key after it is read');
});

test('braceDelta counts braces outside strings only, honours escapes, and resets at the line end', () => {
  assert.equal(braceDelta('{'), 1);
  assert.equal(braceDelta('},'), -1);
  assert.equal(braceDelta('"reason": "a } brace",'), 0, 'a brace inside a string is not counted');
  assert.equal(braceDelta('"a \\" quote { brace",'), 0, 'an escaped quote does not end the string');
  assert.equal(braceDelta('"nested": {"k": "}"},'), 0, 'braces outside the strings on the same line still count');

  // A stray quote in an XML block leaves the string open to the end of its own line only, so
  // the closing brace on the next line still ends the block.
  const xml = ['XData Notes', '{', '<note text="stray quote>', '}', ''].join('\n');
  assert.equal(extractXData(xml, 'Notes'), '<note text="stray quote>');
});

test('a descriptor whose Declaration is valid UDL but invalid JSON makes readSources throw naming the file', () => {
  let parserMessage = '';
  try {
    JSON.parse('{not valid json}');
  } catch (error) {
    parserMessage = error.message;
  }

  withDescriptorDir(
    { 'Bad.cls': descriptorSource('Bad', ['{not valid json}']) },
    (dir) => {
      assert.throws(
        () => readSources({ descriptorDir: dir }),
        (error) => {
          assert.match(error.message, /Bad\.cls/, 'the throw names the descriptor file');
          assert.match(error.message, /XData Declaration/, 'and the block');
          assert.ok(error.message.includes(parserMessage), `and carries the parser's own message: ${error.message}`);
          return true;
        }
      );
    }
  );
});

test('an Area.cls whose XData Areas is valid UDL but invalid JSON makes readSources throw naming the file', () => {
  let parserMessage = '';
  try {
    JSON.parse('{"areas": [,]}');
  } catch (error) {
    parserMessage = error.message;
  }

  withDescriptorDir(
    { 'Area.cls': ['Class OcuPilot.Screen.Area', '{', '', 'XData Areas', '{', '{"areas": [,]}', '}', '', '}'].join('\n') },
    (dir) => {
      const areaSource = join(dir, 'Area.cls');
      assert.throws(
        () => readSources({ areaSource }),
        (error) => {
          assert.ok(error.message.includes(areaSource), `the throw names the area source it read: ${error.message}`);
          assert.match(error.message, /XData Areas/, 'and the block');
          assert.ok(parserMessage !== '' && error.message.includes(parserMessage), "and carries the parser's own message");
          return true;
        }
      );
    }
  );
});

test('BuiltArchetypeKey holds the archetypes of built screens only, and is never when none is built', () => {
  const sources = readSources();
  const union = (mirror) => {
    const match = /export type BuiltArchetypeKey =\s*([^;]*);/.exec(mirror);
    assert.ok(match, 'the mirror declares BuiltArchetypeKey');
    return match[1].trim();
  };

  const mixed = buildMirror({
    ...sources,
    screens: [
      // `sideBarPosition` is declared on the built one because Story 3.5 made it required of a
      // built screen: 0 is the sentinel for routable-but-unlisted, and an absent key already read
      // as 0 through `Base.SideBarPosition`'s own `+`, so a forgotten key would have unlisted a
      // screen silently. The unbuilt fixture is exempt, which is the rule's other half.
      { file: 'Built.cls', className: 'OcuPilot.Screen.Descriptor.Built', declaration: { archetype: 'detail', built: true, sideBarPosition: 1 } },
      { file: 'Unbuilt.cls', className: 'OcuPilot.Screen.Descriptor.Unbuilt', declaration: { archetype: 'list', built: false } },
    ],
  });
  assert.equal(union(mixed), "| 'detail'", 'the built archetype, and not the unbuilt one');

  const none = buildMirror({
    ...sources,
    screens: [
      { file: 'Unbuilt.cls', className: 'OcuPilot.Screen.Descriptor.Unbuilt', declaration: { archetype: 'list', built: false } },
    ],
  });
  assert.equal(union(none), 'never');

  assert.match(union(readCheckedInMirror()), /'home'/, 'the shipped mirror requires a page for Home');
});

// Story 3.5: `sideBarPosition` 0 is the sentinel for routable-but-unlisted, and `Base.cls`'s own
// `+..Field(...)` already answers 0 for an absent key -- so a forgotten key would unlist a screen
// with nothing red anywhere. The refusals are asserted as values, because a rule that refuses
// nothing looks exactly like no rule.
//
// Mutation (Rule 19): make `sideBarPositionProblem` return `null` unconditionally -> every
// refusal assertion here goes red, and so does the mirror leg below it.
test('a built screen must declare sideBarPosition as a whole number of at least 0, and 0 is the sentinel', () => {
  assert.match(sideBarPositionProblem({ built: true }), /not declared as a number/);
  assert.match(sideBarPositionProblem({ built: true, sideBarPosition: '1' }), /not declared as a number/);
  assert.match(sideBarPositionProblem({ built: true, sideBarPosition: -1 }), /whole number of at least 0/);
  assert.match(sideBarPositionProblem({ built: true, sideBarPosition: 1.5 }), /whole number of at least 0/);
  assert.equal(sideBarPositionProblem({ built: true, sideBarPosition: 0 }), null, '0 is routable but not listed');
  assert.equal(sideBarPositionProblem({ built: true, sideBarPosition: 4 }), null);
  // Nothing lists an unbuilt screen and nothing routes it, so its position says nothing yet --
  // the rule's other half, and the reason it cannot simply require the key of every declaration.
  assert.equal(sideBarPositionProblem({ built: false }), null, 'an unbuilt screen is exempt');

  // ...and the generator refuses such a descriptor rather than emitting a silently unlisted one.
  const sources = readSources();
  assert.throws(
    () =>
      buildMirror({
        ...sources,
        screens: [
          { file: 'Built.cls', className: 'OcuPilot.Screen.Descriptor.Built', declaration: { archetype: 'detail', built: true } },
        ],
      }),
    /sideBarPosition/,
    'the mirror refuses a built screen with no declared position'
  );
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

  // `refSeparator` is what a real source set carries; a synthetic one declares it too, or the
  // generator refuses it before it reaches the refusal under test.
  const sound = { entityTypes: ['user'], refSeparator: 2, singletonId: 'SYSTEM', areas: [], screens: [] };

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
  assert.doesNotThrow(() =>
    buildMirror({ entityTypes: parseEntityTypes('Parameter TYPES = "user";'), refSeparator: 2, singletonId: 'SYSTEM', areas, screens: [] })
  );
  for (const screen of screens) assert.equal(malformedPair(screen.declaration.privileges), null, screen.file);
  for (const area of areas) assert.equal(malformedPair(area.privileges), null, area.key);
});

// AD-44, Story 1.15: `archetype` was free text every reader ignored, so "only a detail view may
// declare a classic link-out" had no predicate to evaluate -- a typo answered "not a detail
// view" and passed. The vocabulary is closed in `OcuPilot.Screen.Archetype` and refused here,
// the second of the two places a declared value fails the build, the other being
// `ui/tools/classic-links.mjs`. `OcuPilot.Screen.Registry.ClassicLinkProblem` makes the same
// refusal on the instance, but it is reached only through `Validate`, which nothing on the
// serving path calls (`Registry.cls:27-31`), so it fails no build.
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
  // never made -- the same treatment `scope` gets above. NOT the same treatment `refreshRates`
  // gets: that one is defaulted at emission, and `archetype` is not, because no candidate value
  // is anything but a classification the descriptor did not make. What that costs is recorded
  // at the check in `screen-mirror.mjs`: a real descriptor declaring no archetype emits an
  // entry missing its non-optional field and fails `tsc` rather than at a named refusal, and
  // `ui/tools/classic-links.mjs` is what names it in all three gates.
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

// --- The gates (Story 1.17, DW-184) -------------------------------------------------------
//
// A checker wired into no gate blocks nothing. `screen-mirror.mjs --check` was named in
// `prebuild` and `prestart` and NOT in the pre-commit hook -- the one dispatch of the four that
// the hook did not run -- so a descriptor committed without its regenerated mirror passed the
// commit and failed the next build, at a moment and in a place unrelated to the change.
//
// The shape is `classic-links.test.mjs`'s, deliberately: named is not the same as able to
// block, and the two defects are indistinguishable from the outside. A dispatch that drops
// `|| STATUS=1`, or a script chain that swallows the failure, still runs the check, still
// prints its refusal, and still lets the commit or the build through.
//
// Mutations (Rule 19): remove the `screen-mirror.mjs --check` dispatch from
// `.githooks/pre-commit` -> the hook assertions go red. Drop its `|| STATUS=1` -> the
// STATUS assertion alone goes red while every other one stays green. Append `|| true` to its
// `prebuild` segment -> the swallow assertion goes red.

const MIRROR_REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

test('the mirror drift check is named in prebuild, in prestart and in the pre-commit hook (DW-184)', () => {
  const scripts = JSON.parse(readFileSync(join(dirname(fileURLToPath(import.meta.url)), '..', 'package.json'), 'utf8')).scripts;
  assert.match(scripts.prebuild, /node tools\/screen-mirror\.mjs --check/, 'prebuild runs it before ng build');
  assert.match(scripts.prestart, /node tools\/screen-mirror\.mjs --check/, 'prestart runs it before ng serve');

  const hook = readFileSync(join(MIRROR_REPO_ROOT, '.githooks', 'pre-commit'), 'utf8');
  assert.match(hook, /node tools\/screen-mirror\.mjs --check/, 'the pre-commit hook runs it');

  // Inside the existing ObjectScript/ui trigger, beside the other three checkers -- the scopes
  // must agree, so the check runs on exactly the commits that can change a descriptor or its
  // mirror.
  const trigger = hook.slice(hook.indexOf('if [ -n "$OS_TRIGGER" ]'));
  const block = trigger.slice(0, trigger.indexOf('\nfi\n'));
  assert.match(
    block,
    /node tools\/screen-mirror\.mjs --check/,
    'and does so inside the OS_TRIGGER block, not on a trigger of its own'
  );
  assert.match(
    block,
    /node tools\/screen-mirror\.mjs --check\)?\s*\|\|\s*STATUS=1/,
    "the hook's dispatch feeds a refusal into STATUS, which is what the hook exits with"
  );

  for (const [name, chain] of [
    ['prebuild', scripts.prebuild],
    ['prestart', scripts.prestart],
  ]) {
    const segments = chain.split('&&').map((segment) => segment.trim());
    assert.ok(
      segments.includes('node tools/screen-mirror.mjs --check'),
      `${name} runs the check as a link of its own`
    );
    assert.doesNotMatch(
      chain,
      /screen-mirror\.mjs --check[^&]*\|\|/,
      `${name} does not swallow the check's exit code`
    );
  }
});

test('the hook explains a mirror failure among the others (DW-184)', () => {
  const hook = readFileSync(join(MIRROR_REPO_ROOT, '.githooks', 'pre-commit'), 'utf8');
  assert.match(hook, /Screen mirror:/, 'the failure message names this checker and how to fix it');
  assert.match(hook, /node tools\/screen-mirror\.mjs`/, 'and gives the regenerate command');
});

// DW-271: every case in `OcuPilot.Test.DeclarationCorpus`, read off disk from the XData block
// `OcuPilot.Test.ReadTool` reads through the class dictionary, gets its exact sentence or `null`
// from `declarationProblem`; every shipped descriptor passes; and the refusal reaches the
// generator, which is where a misspelt key used to be spread into the mirror verbatim.
//
// Mutation (Rule 19): delete the `declarationProblem` call from `buildMirror` -> the "reaches the
// generator" assertion goes red while the corpus run stays green, which is what distinguishes the
// rule from its wiring.
test('declarationProblem returns every sentence OcuPilot.Test.DeclarationCorpus declares, and a misspelt top-level key never reaches the mirror', () => {
  const corpus = testCorpus(['Test', 'DeclarationCorpus.cls'], 'Cases');
  assert.ok(corpus.cases.length > 0, `the corpus carries cases (read ${corpus.cases.length})`);
  let refusals = 0;
  for (const testCase of corpus.cases) {
    const declaration = structuredClone(corpus.declaration);
    if (testCase.dropKey !== '') delete declaration[testCase.dropKey];
    if (testCase.addKey !== '') declaration[testCase.addKey] = 'a value no accessor reads';
    assert.equal(declarationProblem(declaration), testCase.expected, testCase.name);
    if (testCase.expected !== null) refusals += 1;
  }
  assert.ok(refusals > 0, 'the corpus carries at least one refusing case');

  // The corpus's own sound declaration exercises all twenty-seven keys, so the vocabulary cannot
  // drift by one without a case going red.
  assert.deepEqual(
    Object.keys(corpus.declaration).sort(),
    [...DECLARATION_KEYS].sort(),
    'the corpus declaration carries exactly the declared vocabulary'
  );

  const { screens } = readSources();
  for (const screen of screens) {
    assert.equal(declarationProblem(screen.declaration), null, `${screen.className}'s top-level keys pass`);
  }

  // The refusal reaches the generator, naming the file and the class, as every other one does --
  // which is what a misspelt key used to skip on its way into the mirror's unconstrained spread.
  const hostile = structuredClone(corpus.declaration);
  hostile.banners = hostile.banner;
  delete hostile.banner;
  assert.throws(
    () =>
      buildMirror({
        ...readSources(),
        screens: [{ file: 'Hostile.cls', className: 'OcuPilot.Screen.Descriptor.Hostile', declaration: hostile }],
      }),
    /Hostile\.cls \(OcuPilot\.Screen\.Descriptor\.Hostile\): the declaration declares the unknown key 'banners'/
  );
});

// DW-1121, AD-3, AD-6: the confirm channel is the descriptor's declaration, and this engine
// returns the same sentences `OcuPilot.Screen.Registry.ConfirmChannelProblem` returns -- the pair
// `OcuPilot.Test.Descriptor` holds on the instance side.
//
// Mutation (Rule 19): delete the `confirmChannelProblem` call from `buildMirror` -> the hostile
// declaration below is mirrored verbatim and the last assertion goes red.
test('confirmChannelProblem returns the instance-side sentences, and every shipped descriptor passes', () => {
  const { screens, toolFields } = readSources();
  for (const screen of screens) {
    assert.equal(
      confirmChannelProblem(screen.declaration, toolFields),
      null,
      `${screen.className}'s confirm channel passes`
    );
  }

  const webApp = screens.find((screen) => screen.className === 'OcuPilot.Screen.Descriptor.WebAppList');
  assert.ok(webApp !== undefined, 'the web applications list is among them');
  const of = (overrides) => ({ ...webApp.declaration, ...overrides });

  assert.equal(
    confirmChannelProblem(of({ secretArguments: 'not an array' }), toolFields),
    'secretArguments is not an array of strings'
  );
  assert.equal(
    confirmChannelProblem(of({ secretArguments: ['a', 'a'] }), toolFields),
    "secretArguments names 'a' twice"
  );
  assert.equal(
    confirmChannelProblem(of({ fingerprintExcludes: ['NoSuchField'] }), toolFields),
    "fingerprintExcludes names 'NoSuchField', which is neither a field of this screen's write tool nor one its read declares (AD-6)"
  );
  assert.equal(
    confirmChannelProblem(of({ fingerprintExcludes: ['Timeout'] }), toolFields),
    null,
    'an exclusion naming a field of that tool is sound'
  );
  assert.equal(
    confirmChannelProblem(of({ fingerprintExcludes: [webApp.declaration.read.fields[0]] }), toolFields),
    null,
    'and so is one naming a field the screen\'s own read declares'
  );

  // DW-1206's refusing direction: both keys are checked against one set, so an entry naming
  // nothing is refused rather than left to be read as a whitelist by two consumers.
  assert.equal(
    confirmChannelProblem(of({ secretArguments: ['Pasword'] }), toolFields),
    "secretArguments names 'Pasword', which is neither a settable field of this screen's write " +
      'tool nor one its read declares (AD-6)'
  );
  assert.equal(
    confirmChannelProblem(of({ secretArguments: ['Timeout'] }), toolFields),
    null,
    'while one naming a settable field of that tool is sound'
  );
  assert.equal(
    confirmChannelProblem(of({ secretArguments: [webApp.declaration.read.fields[0]] }), toolFields),
    null,
    "and so is one naming a field the screen's own read declares"
  );
  // 'Timeout' above is a string field, so it cannot tell the membership check's 'settable' set
  // apart from the credential heuristic's string-only one; 'AutoCompile' is a boolean field of
  // the same tool and is sound here too.
  assert.equal(
    confirmChannelProblem(of({ secretArguments: ['AutoCompile'] }), toolFields),
    null,
    'and so is a non-string settable field'
  );
  // The two spellings the one set carries: the schema drops a declared secret by the []-stripped
  // name, while an exclusion of an array reaches the fingerprint as <path>[].
  assert.equal(
    confirmChannelProblem(of({ secretArguments: ['CorsAllowlist'] }), toolFields),
    null,
    'a secret named in the spelling the schema honours is sound'
  );
  assert.equal(
    confirmChannelProblem(of({ fingerprintExcludes: ['CorsAllowlist[]'] }), toolFields),
    null,
    'and an exclusion named in the spelling the fingerprint honours is sound'
  );
  // The tightening direction: any row of the entry was accepted before, a secret-classified
  // subtree included.
  assert.equal(
    confirmChannelProblem(of({ fingerprintExcludes: ['MatchRoles[].MatchRole'] }), toolFields),
    "fingerprintExcludes names 'MatchRoles[].MatchRole', which is neither a field of this " +
      "screen's write tool nor one its read declares (AD-6)"
  );

  const withCriterion = of({
    read: {
      ...webApp.declaration.read,
      criteria: {
        fields: [{ param: 'apiKey', labelKey: 'tableColumnName', kind: 'text', maxLength: 64 }],
      },
    },
  });
  // The loosening direction, and the flag half the builder missed: a criterion is one of the names
  // the read declares, so its parameter is a nameable exclusion.
  assert.equal(
    confirmChannelProblem({ ...withCriterion, secretArguments: ['apiKey'], fingerprintExcludes: ['apiKey'] }, toolFields),
    null,
    "a typed criterion's parameter is a nameable exclusion"
  );
  const withFlag = of({
    read: {
      ...webApp.declaration.read,
      criteria: { fields: [], marker: { param: 'eventSources', value: 'OcuPilot', labelKey: 'auditMarkerFilterLabel' } },
    },
    fingerprintExcludes: ['eventSources'],
  });
  assert.equal(
    confirmChannelProblem(withFlag, toolFields),
    null,
    "and so is a flag criterion's, which DeclaredCriterionParams missed before DW-1206"
  );
  assert.equal(
    confirmChannelProblem(withCriterion, toolFields),
    "read.criteria names 'apiKey', whose name matches the credential pattern and which " +
      'secretArguments does not declare (AD-3)'
  );
  assert.equal(
    confirmChannelProblem({ ...withCriterion, secretArguments: ['apiKey'] }, toolFields),
    null,
    'declaring it is what admits it'
  );

  // The generator refuses to emit it at all, which is the assertion that makes this rule part of
  // the build rather than a function nothing calls.
  assert.throws(
    () =>
      buildMirror({
        ...readSources(),
        screens: [{ file: 'Hostile.cls', className: 'OcuPilot.Screen.Descriptor.Hostile', declaration: withCriterion }],
      }),
    /read\.criteria names 'apiKey'/
  );
});

// DW-1206's own cause was two sibling declarations validated against different sets, so the roster
// of projections this generator builds is held against the kernel's own `DECLAREDNAMEKINDS` -- the
// shape `checkedIdRules` uses for id rules, and for the same reason: a mirror validating a
// confirm-channel key against a set the instance does not build would refuse a sound declaration at
// `prebuild`, or admit one the instance refuses at install.
//
// Mutation (Rule 19): drop a name from `IMPLEMENTED_DECLARED_NAME_KINDS`, or from the kernel's
// `Parameter DECLAREDNAMEKINDS` -> the throw below fires on the real sources and the first
// assertion goes red.
test('DW-1206: the projection roster is the kernel\'s, and a mismatch fails the build', () => {
  const sources = readSources();
  assert.deepEqual(
    [...sources.declaredNameKinds].sort(),
    [...IMPLEMENTED_DECLARED_NAME_KINDS].sort(),
    'the kernel declares exactly the projections this generator builds'
  );
  assert.equal(parseDeclaredNameKinds('Class X { }'), null, 'reported, never read as an empty set');
  assert.throws(
    () => buildMirror({ ...sources, declaredNameKinds: ['settable', 'read'] }),
    (error) => {
      assert.match(error.message, /Screen\/Registry\.cls/, 'the refusal names the source class');
      assert.match(error.message, /DECLAREDNAMEKINDS/, 'and the parameter');
      return true;
    },
    'a roster the two sides do not share fails the build'
  );
});

// The one builder, asserted as one: both confirm-channel keys read `declaredNames`' projections, so
// the set cannot be built twice and drift.
test('DW-1206: declaredNames answers one union in the two spellings its consumers honour', () => {
  const { screens, toolFields } = readSources();
  const webApp = screens.find((screen) => screen.className === 'OcuPilot.Screen.Descriptor.WebAppList');
  const names = declaredNames(webApp.declaration, toolFields);
  assert.ok(names.settable.includes('CorsAllowlist'), 'the []-stripped spelling the schema honours');
  assert.ok(names.path.includes('CorsAllowlist[]'), 'and the written spelling the fingerprint honours');
  assert.ok(!names.settable.includes('CorsAllowlist[]'), 'never the other way round');
  assert.ok(!names.path.includes('MatchRoles[].MatchRole'), 'a row the tool cannot set is in neither');
  assert.ok(names.read.includes('Name'), "the read's own declared fields are in the union");
  assert.deepEqual(names.criteria, [], 'the web applications list declares no criterion');
  assert.ok(names.credential.includes('Timeout'), 'and the credential half is the string-placeholder rows');
});

// The entity-label rule's two engines (AD-5, AD-14). `OcuPilot.Test.Descriptor` holds the same
// four shapes to the same four sentences on the instance side; a sentence reworded on one side
// only goes red there.
//
// Mutation (Rule 19): delete the `entityLabelProblem` call from `buildMirror` -> the last
// assertion goes red, and a noun declared for no entity type would mirror verbatim.
test('entityLabelProblem returns the instance-side sentences, and every shipped descriptor passes', () => {
  const { screens, entityTypes, scopeWords, archetypes, areas, toolFields } = readSources();
  for (const screen of screens) {
    assert.equal(
      entityLabelProblem(screen.declaration),
      null,
      `${screen.className}'s entity label passes`
    );
  }

  const webApp = screens.find((screen) => screen.className === 'OcuPilot.Screen.Descriptor.WebAppList');
  assert.ok(webApp !== undefined, 'the web applications list is among them');
  assert.equal(webApp.declaration.entityLabelKey, 'proposalEntityWebApplication', 'and declares one');
  const of = (overrides) => ({ ...webApp.declaration, ...overrides });

  const absent = { ...webApp.declaration };
  delete absent.entityLabelKey;
  assert.equal(entityLabelProblem(absent), null, 'an absent key is sound: the screen publishes no noun');
  assert.equal(entityLabelProblem(of({ entityLabelKey: '' })), null, 'and so is an empty one');
  assert.equal(entityLabelProblem(of({ entityLabelKey: 7 })), 'entityLabelKey is not a string key');
  assert.equal(
    entityLabelProblem(of({ entityType: '' })),
    "entityLabelKey names the singular noun for this screen's entity type, and none is declared"
  );

  // The refusal reaches the generator, naming the file and the class.
  const hostile = of({ entityType: '' });
  assert.throws(
    () =>
      buildMirror({
        entityTypes,
        refSeparator: 2,
        singletonId: 'SYSTEM',
        scopeWords,
        archetypes,
        areas,
        toolFields,
        screens: [{ ...webApp, declaration: hostile }],
      }),
    /entityLabelKey names the singular noun/
  );
});

// AD-3, AD-6: a `secretArguments` name also qualifies when it is a top-level `secret` literal row
// of the screen's write tools -- a derived credential, or an authored wrapper field such as
// `Security.User`'s POST `Password` (Story 8.2). The widening is additive, so both directions are
// pinned: a top-level secret row passes, and every name that qualified before still qualifies
// while an unknown name, a nested secret path and an array element are still refused.
//
// Mutation (Rule 19): drop the `secretRows` clause from `confirmChannelProblem` -> the Users list
// and the synthetic secret row below are refused; make `secretRowNames` admit nested paths -> the
// `MatchRoles[].MatchRole` assertion goes red.
test('a secretArguments entry may name a top-level secret row, and nothing that qualified stops qualifying', async () => {
  const { secretRowNames } = await import('./screen-mirror.mjs');
  const { screens, toolFields } = readSources();
  const users = screens.find((screen) => screen.className === 'OcuPilot.Screen.Descriptor.UserList');
  assert.ok(users !== undefined, 'the users list is among the descriptors');
  assert.deepEqual(users.declaration.secretArguments, ['Password'], 'it declares the authored Password');
  assert.ok(secretRowNames('permissions.users', toolFields).includes('Password'), "the create tool's authored row is a top-level secret");
  assert.equal(confirmChannelProblem(users.declaration, toolFields), null, 'the declaration passes');
  assert.equal(
    confirmChannelProblem({ ...users.declaration, secretArguments: ['Pasword'] }, toolFields),
    "secretArguments names 'Pasword', which is neither a settable field of this screen's write " +
      'tool nor one its read declares (AD-6)',
    'a name no source carries is still refused'
  );

  const webApp = screens.find((screen) => screen.className === 'OcuPilot.Screen.Descriptor.WebAppList');
  const synthetic = {
    'webapp.list.probe': {
      fieldList: 'WebApp.App',
      fields: [
        { path: 'ProbeSecret', shape: 'literal', templateType: 'string', class: 'secret', authored: true },
        { path: 'ProbeNested.Key', shape: 'literal', templateType: 'string', itemType: '', class: 'secret' },
        { path: 'ProbeList[]', shape: 'literal', templateType: 'string', itemType: '', class: 'secret' },
        { path: 'ProbeOpaque', shape: 'literal', templateType: 'string', itemType: '', class: 'opaque' },
      ],
    },
  };
  const widened = { ...toolFields, ...synthetic };
  const of = (secretArguments) => ({ ...webApp.declaration, secretArguments });
  assert.equal(confirmChannelProblem(of(['ProbeSecret']), widened), null, 'a top-level secret row qualifies');
  assert.equal(confirmChannelProblem(of(['ProbeSecret']), toolFields), confirmChannelProblem(of(['ProbeSecret']), {}), 'and only while the row exists');
  assert.notEqual(confirmChannelProblem(of(['ProbeSecret']), toolFields), null, 'absent the row it is refused');
  for (const name of ['ProbeNested.Key', 'ProbeNested', 'ProbeList', 'ProbeList[]', 'ProbeOpaque']) {
    assert.notEqual(confirmChannelProblem(of([name]), widened), null, `${name} does not qualify`);
  }
  for (const name of ['Timeout', 'AutoCompile', 'CorsAllowlist', webApp.declaration.read.fields[0]]) {
    assert.equal(confirmChannelProblem(of([name]), widened), null, `${name} still qualifies`);
  }
  assert.notEqual(
    confirmChannelProblem(of(['MatchRoles[].MatchRole']), widened),
    null,
    'a nested secret path of the shipped list is not admitted'
  );
});

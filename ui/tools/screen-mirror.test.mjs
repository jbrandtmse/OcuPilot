import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import {
  BANNER_SEVERITIES,
  MIRROR_PATH,
  bannerProblem,
  braceDelta,
  buildMirror,
  criteriaProblem,
  entityTypesIn,
  extractClassName,
  extractXData,
  generate,
  malformedPair,
  parseEntityTypes,
  parseScopeWords,
  readCheckedInMirror,
  declaredStringKeys,
  readProblem,
  readSources,
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
// red; drop the banner's `messageKey` from it -> the listing goes red on its last member and the
// unresolved-key assertion loses the banner key.
test('every string key a table or banner declaration names is one the key check reads', () => {
  const declaration = JSON.parse(
    '{"labelKey": "navAreaWebApplications", "emptyStateKey": "commandBoxNoMatch",' +
      ' "table": {"columns": [{"field": "Name", "labelKey": "fieldUserName", "kind": "name"},' +
      ' {"field": "Enabled", "labelKey": "notAStringKey", "kind": "status"}],' +
      ' "emptyNextKey": "classicLinkCardCaption", "emptyAgentKey": ""},' +
      ' "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"},' +
      ' "field": "Status", "equals": "Suspended", "messageKey": "notABannerStringKey",' +
      ' "severity": "warning"}}'
  );
  const keys = declaredStringKeys(declaration);
  assert.deepEqual(keys, [
    'navAreaWebApplications',
    'commandBoxNoMatch',
    'fieldUserName',
    'notAStringKey',
    'classicLinkCardCaption',
    'notABannerStringKey',
  ]);
  const strings = loadStrings();
  assert.deepEqual(
    keys.filter((key) => !(key in strings)),
    ['notAStringKey', 'notABannerStringKey'],
    'and a key the string source lacks is found, the banner\'s among them'
  );
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
    [(d) => (d.read.source.port = 'monitor'), /port 'monitor'/],
    [(d) => (d.read.source.type = 'GET'), /type 'GET'/],
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
    if (testCase.readless) {
      declaration.read = null;
      declaration.table = null;
    }
    assert.equal(readProblem(declaration), testCase.expected, testCase.name);
    if (testCase.expected !== null) refusals += 1;
  }
  assert.ok(refusals > 0, 'the corpus carries at least one refusing case');

  const { screens } = readSources();
  for (const name of ['AuditList', 'ProcessList', 'SslConfigList', 'TaskScheduleList', 'UserList', 'WebAppList']) {
    const screen = screens.find((candidate) => candidate.className === `OcuPilot.Screen.Descriptor.${name}`);
    assert.ok(screen !== undefined, `${name} is declared`);
    assert.equal(readProblem(screen.declaration), null, `${name}'s read passes`);
  }
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
  // Every other shipped screen declares none: the criteria block is this one screen's, because it
  // is the one Release 1 list whose API searches on the server.
  const withCriteria = emittedScreens.filter((screen) => (screen.read?.criteria ?? null) !== null);
  assert.deepEqual(
    withCriteria.map((screen) => screen.descriptor),
    ['OcuPilot.Screen.Descriptor.AuditList']
  );

  // The refusal reaches the generator, naming the file and the class, as every other one does.
  const hostile = structuredClone(audit);
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
    equals: 'Suspended',
    messageKey: 'taskManagerSuspendedBanner',
    severity: 'warning',
  });
  for (const screen of emittedScreens) {
    if (screen.descriptor === 'OcuPilot.Screen.Descriptor.TaskScheduleList') continue;
    assert.equal(screen.banner, null, `${screen.descriptor} emits no banner`);
  }

  // The refusal reaches the generator, naming the file and the class, as every other one does.
  const hostile = structuredClone(tasks);
  hostile.banner = { ...hostile.banner, severity: 'error' };
  assert.throws(
    () =>
      buildMirror({
        ...readSources(),
        screens: [{ file: 'Hostile.cls', className: 'OcuPilot.Screen.Descriptor.Hostile', declaration: hostile }],
      }),
    /Hostile\.cls \(OcuPilot\.Screen\.Descriptor\.Hostile\): banner\.severity 'error' is not one of/
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
      { file: 'Built.cls', className: 'OcuPilot.Screen.Descriptor.Built', declaration: { archetype: 'detail', built: true } },
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

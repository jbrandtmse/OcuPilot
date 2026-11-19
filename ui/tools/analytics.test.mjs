/**
 * Story 20.11's Analytics sentence and Story 20.33's MDX sentences, held to the instance's own source (AD-29, AD-39, AD-65).
 *
 * `OcuPilot.Api.AnalyticsError`'s sentences are each one published string on three surfaces: the server sends it, the client's strings
 * table holds it, and EXPERIENCE.md's Fixed strings publish it. The port also declares the pair sets its screens' descriptors repeat, the
 * endpoint list the mirror generator reads, and the consequence the MDX query's confirmation names.
 */

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

const PORT = join(REPO_ROOT, 'src', 'OcuPilot', 'Port', 'AnalyticsPort.cls');

const ERROR = join(REPO_ROOT, 'src', 'OcuPilot', 'Api', 'AnalyticsError.cls');

/** The product classes that run an MDX statement: the port, the MDX kind, the run and the row reader they share, and the agent's read. */
const MDX_CODE = [
  PORT,
  join(REPO_ROOT, 'src', 'OcuPilot', 'Area', 'Analytics', 'MdxQuery.cls'),
  join(REPO_ROOT, 'src', 'OcuPilot', 'Kernel', 'Shell', 'BackgroundRun.cls'),
  join(REPO_ROOT, 'src', 'OcuPilot', 'Kernel', 'RowFetch.cls'),
  join(REPO_ROOT, 'src', 'OcuPilot', 'Screen', 'Tool', 'AnalyticsMdxRead.cls'),
];

const STRINGS_SOURCE = join(REPO_ROOT, 'ui', 'src', 'app', 'core', 'strings.ts');

const EXPERIENCE = join(REPO_ROOT, '_bmad-output', 'planning-artifacts', 'ux-designs', 'ux-OcuPilot-2026-09-08', 'EXPERIENCE.md');

/** Every `<parameter>` sentence `AnalyticsError` declares, and the `strings.ts` key it is pinned equal to. */
const SENTENCES = [['REASONNAMESPACE', 'analyticsRefusalNamespace']];

/** The eight sentences of MDX query's refusals (Story 20.33), each pinned to its `strings.ts` key. */
const MDX_SENTENCES = [
  ['REASONMDXINPUT', 'analyticsRefusalMdxInput'],
  ['REASONMDXKIND', 'analyticsRefusalMdxKind'],
  ['REASONMDXAXES', 'analyticsRefusalMdxAxes'],
  ['REASONMDXREADONLY', 'analyticsRefusalMdxReadonly'],
  ['REASONMDXBUSY', 'analyticsRefusalMdxBusy'],
  ['REASONMDXFULL', 'analyticsRefusalMdxFull'],
  ['REASONMDXNOTFOUND', 'analyticsRefusalMdxNotFound'],
  ['REASONMDXLOST', 'analyticsRefusalMdxLost'],
];

/** The value `key` holds in `strings.ts`, which may sit on the line after its key. */
function stringValue(key) {
  const source = readFileSync(STRINGS_SOURCE, 'utf8');
  const match = new RegExp(`\\b${key}:\\s*\\n?\\s*'((?:[^'\\\\]|\\\\.)*)'`).exec(source);
  assert.notEqual(match, null, `strings.ts carries ${key}`);
  return match[1].replace(/\\'/g, "'").replace(/\\\\/g, '\\');
}

/** The sentence `parameter` holds in `AnalyticsError.cls`. */
function serverSentence(parameter) {
  const match = new RegExp(`Parameter ${parameter} = "([^"]+)";`).exec(readFileSync(ERROR, 'utf8'));
  assert.notEqual(match, null, `AnalyticsError.cls declares ${parameter}`);
  return match[1];
}

test('Story 20.11: the Analytics refusal is one sentence on both surfaces, published in Fixed strings', () => {
  // Mutation (Rule 19): change one word of REASONNAMESPACE in AnalyticsError.cls -> this goes red naming both.
  const experience = readFileSync(EXPERIENCE, 'utf8');
  for (const [parameter, key] of SENTENCES) {
    const server = serverSentence(parameter);
    assert.equal(server, stringValue(key), `${parameter} and ${key} are one published sentence`);
    assert.ok(experience.includes(`"${server}"`), `${parameter}'s sentence is published in EXPERIENCE.md's Fixed strings`);
    assert.ok(!server.toLowerCase().includes('agent'), `${parameter} names no caller: ${server}`);
  }
});

test('Story 20.11: the port declares its three pair sets and the endpoints the mirror reads', () => {
  // Mutation (Rule 19): drop %DeepSee_PortalEdit:USE from TERMLISTPAIRS in AnalyticsPort.cls -> this goes red.
  const port = readFileSync(PORT, 'utf8');
  const parameter = (name) => {
    const match = new RegExp(`^Parameter ${name} = "([^"]*)";`, 'm').exec(port);
    assert.notEqual(match, null, `AnalyticsPort.cls declares ${name}`);
    return match[1];
  };
  assert.equal(parameter('PORTALPAIRS'), '%DeepSee_Portal:USE');
  assert.equal(parameter('TERMLISTPAIRS'), '%DeepSee_Portal:USE,%DeepSee_PortalEdit:USE');
  assert.equal(parameter('FOLDERPAIRS'), '%DeepSee_Portal:USE,%Development:USE');
  assert.equal(parameter('LISTINGGROUPPAIRS'), '%DeepSee_Portal:USE,%DeepSee_ListingGroup:USE');
  assert.equal(parameter('LISTINGGROUPSQLPAIRS'), '%DeepSee_ListingGroupSQL:USE');
  assert.equal(parameter('QUALITYMEASUREPAIRS'), '%DeepSee_Portal:USE,%DeepSee_PortalEdit:USE');
  assert.equal(parameter('SETTINGSPAIRS'), '%DeepSee_Portal:USE,%Development:USE');
  assert.equal(
    parameter('ENDPOINTS'),
    'Cubes,Measures,Dimensions,Relationships,TermLists,TermListEntries,FolderItems,CubeManager,ListingGroups,ListingGroupListings,QualityMeasures,QualityMeasureElements,QualityMeasureMetas,Settings,Worklists,RuntimeVariables,UserIcons'
  );
  assert.equal(parameter('MANAGERPAIRS'), '%DeepSee_Portal:USE,%DeepSee_Admin:USE');
  assert.equal(parameter('TYPESTATE'), 'STATE');
  assert.equal(parameter('TYPELIST'), 'LIST');
});

test('Story 20.33: each MDX refusal is one sentence on both surfaces, published in Fixed strings', () => {
  // Mutation (Rule 19): change one word of REASONMDXAXES in AnalyticsError.cls (or of analyticsRefusalMdxAxes in strings.ts) -> this goes
  // red naming both.
  const experience = readFileSync(EXPERIENCE, 'utf8');
  for (const [parameter, key] of MDX_SENTENCES) {
    const server = serverSentence(parameter);
    assert.equal(server, stringValue(key), `${parameter} and ${key} are one published sentence`);
    assert.ok(experience.includes(`"${server}"`), `${parameter}'s sentence is published in EXPERIENCE.md's Fixed strings`);
    assert.ok(!server.toLowerCase().includes('agent'), `${parameter} names no caller: ${server}`);
  }
});

test("Story 20.35: the agent's MDX refusal is one sentence on the server, the strings table and Fixed strings", () => {
  // Mutation (Rule 19): change one word of REASONMDXSQL in AnalyticsError.cls (or of analyticsMdxSqlReason in strings.ts) -> this goes red
  // naming both. It is the one sentence that names the agent, so it is not in MDX_SENTENCES.
  const server = serverSentence('REASONMDXSQL');
  assert.equal(server, stringValue('analyticsMdxSqlReason'), 'REASONMDXSQL and analyticsMdxSqlReason are one published sentence');
  assert.ok(readFileSync(EXPERIENCE, 'utf8').includes(`"${server}"`), "REASONMDXSQL's sentence is published in EXPERIENCE.md's Fixed strings");
  assert.match(server, /agent/, 'and it says whose read refuses');
  const code = /^Parameter MDXSQL = "([^"]+)";/m.exec(readFileSync(ERROR, 'utf8'));
  assert.notEqual(code, null, 'AnalyticsError.cls declares MDXSQL');
  assert.equal(code[1], 'ANALYTICS.MDX.SQL', 'the code is the one the card and the model are sent');
});

test("Story 20.33: the confirmation's consequence is one sentence on the port, the strings table and Fixed strings", () => {
  // Mutation (Rule 19): change one word of MDXCONSEQUENCE in AnalyticsPort.cls (or of analyticsMdxConfirmConsequence in strings.ts) -> this
  // goes red naming both.
  const match = /^Parameter MDXCONSEQUENCE = "([^"]+)";/m.exec(readFileSync(PORT, 'utf8'));
  assert.notEqual(match, null, 'AnalyticsPort.cls declares MDXCONSEQUENCE');
  const consequence = match[1];
  assert.equal(consequence, stringValue('analyticsMdxConfirmConsequence'), 'MDXCONSEQUENCE and analyticsMdxConfirmConsequence are one published sentence');
  assert.ok(readFileSync(EXPERIENCE, 'utf8').includes(`"${consequence}"`), "MDXCONSEQUENCE's sentence is published in EXPERIENCE.md's Fixed strings");
});

/**
 * The ObjectScript of `source` that runs: a `///` doc line and a `;` comment are dropped, and, unless `keepStrings`, a string literal is
 * blanked, so a global named in a quoted argument is not a reference.
 */
function codeOf(source, keepStrings) {
  return source
    .split('\n')
    .filter((line) => !line.trimStart().startsWith('///'))
    .map((line) => {
      let out = '';
      let quoted = false;
      for (let at = 0; at < line.length; at += 1) {
        const char = line[at];
        if (char === '"') {
          if (quoted && line[at + 1] === '"') {
            out += keepStrings ? '""' : '';
            at += 1;
            continue;
          }
          quoted = !quoted;
          out += keepStrings ? char : '';
          if (!keepStrings && !quoted) out += '""';
          continue;
        }
        if (char === ';' && !quoted) break;
        if (!quoted || keepStrings) out += char;
      }
      return out;
    })
    .join('\n');
}

/** A direct reference to the vendor's cache, in any of the global's forms: plain, `^|"ns"|` or `^["ns"]` extended, its quoted namespace blanked. */
const CACHE_REFERENCE = /\^(?:\|[^|]*\||\[[^\]]*\])?DeepSee\.Cache/i;

test('Story 20.33 (QA): the scanner keeps code, drops doc lines and comments, and blanks strings when asked', () => {
  const source = '/// Terminate( in a doc line\nSet x = ##class(A).Terminate(1) ; Terminate( in a comment\nSet y = "^DeepSee.Cache; ""q"" x" _ z\n';
  assert.equal(codeOf(source, true), 'Set x = ##class(A).Terminate(1) \nSet y = "^DeepSee.Cache; ""q"" x" _ z\n');
  assert.equal(codeOf(source, false), 'Set x = ##class(A).Terminate(1) \nSet y = "" _ z\n');
  // Mutation (Rule 19): drop the bracket form from `CACHE_REFERENCE` -> the `^["USER"]` leg goes red.
  for (const reference of ['Set x = ^DeepSee.Cache.Results(1)', 'Set x = ^|"USER"|DeepSee.Cache.Results(1)', 'Set x = ^["USER"]DeepSee.Cache.Results(1)']) {
    assert.ok(CACHE_REFERENCE.test(codeOf(reference, false)), `the cache rule finds ${reference}`);
  }
  assert.ok(!CACHE_REFERENCE.test(codeOf('Set x = "^DeepSee.Cache.Results"', false)), 'and not a quoted name');
});

test('Story 20.33 (QA): the code that runs an MDX statement names nothing the story\'s Never list forbids', () => {
  // Mutation (Rule 19): add `Set tX = $System.Process.Terminate(1)`, a read of `^DeepSee.Cache.Results`, a `%Api.DeepSee` call or, in the port, a
  // `%GetMemberTree` call to one of these classes -> this goes red naming the file and the word; a mention in a `///` doc line is not code.
  const rules = [
    { word: /\/api\/deepsee|%Api\.DeepSee|%DeepSee\.REST/i, keepStrings: true, what: 'call of the vendor REST API' },
    { word: /\bTerminate\s*\(/i, keepStrings: true, what: 'process terminate' },
    { word: CACHE_REFERENCE, keepStrings: false, what: "direct read or write of the vendor's cache" },
  ];
  const portOnly = { word: /%GetMemberTree|%GetDimensionMembers|%GetFavoritesForUser/i, keepStrings: true, what: "call AD-65's Never list names" };
  for (const file of MDX_CODE) {
    const source = readFileSync(file, 'utf8');
    for (const { word, keepStrings, what } of file === PORT ? [...rules, portOnly] : rules) {
      assert.ok(!word.test(codeOf(source, keepStrings)), `${file} holds no ${what}`);
    }
  }
});

/** The five refusals of the cube manager's updates (Story 20.34), each pinned to its `strings.ts` key. */
const CUBE_SENTENCES = [
  ['REASONCUBEBUSY', 'analyticsRefusalCubeBusy'],
  ['REASONCUBENODSTIME', 'analyticsRefusalCubeNoDstime'],
  ['REASONCUBENOTBUILT', 'analyticsRefusalCubeNotBuilt'],
  ['REASONCUBEREADONLY', 'analyticsRefusalCubeReadonly'],
  ['REASONCUBEFAILED', 'analyticsRefusalCubeFailed'],
];

const BUILD_TOOL = join(REPO_ROOT, 'src', 'OcuPilot', 'Screen', 'Tool', 'AnalyticsCubeBuild.cls');

const SYNCHRONIZE_TOOL = join(REPO_ROOT, 'src', 'OcuPilot', 'Screen', 'Tool', 'AnalyticsCubeSynchronize.cls');

const ACTION_TOOL = join(REPO_ROOT, 'src', 'OcuPilot', 'Screen', 'Tool', 'AnalyticsAction.cls');

/** The value `parameter` holds in the class at `file`. */
function classParameter(file, parameter) {
  const match = new RegExp(`^Parameter ${parameter}(?: As \\w+)? = "([^"]*)";`, 'm').exec(readFileSync(file, 'utf8'));
  assert.notEqual(match, null, `${file} declares ${parameter}`);
  return match[1];
}

test('Story 20.34: each cube refusal is one sentence on both surfaces, published in Fixed strings', () => {
  // Mutation (Rule 19): change one word of REASONCUBENOTBUILT in AnalyticsError.cls (or of analyticsRefusalCubeNotBuilt in strings.ts) -> this
  // goes red naming both.
  const experience = readFileSync(EXPERIENCE, 'utf8');
  for (const [parameter, key] of CUBE_SENTENCES) {
    const server = serverSentence(parameter);
    assert.equal(server, stringValue(key), `${parameter} and ${key} are one published sentence`);
    assert.ok(experience.includes(`"${server}"`), `${parameter}'s sentence is published in EXPERIENCE.md's Fixed strings`);
    assert.ok(!server.toLowerCase().includes('agent'), `${parameter} names no caller: ${server}`);
  }
});

test("Story 20.34: the two afterwords and consequence codes are one published sentence each on the tool, the strings table and Fixed strings", () => {
  // Mutation (Rule 19): change AFTERWORD in AnalyticsCubeBuild.cls to "Rebuilt" -> this goes red naming the tool and the key.
  const experience = readFileSync(EXPERIENCE, 'utf8');
  const proposalView = readFileSync(join(REPO_ROOT, 'ui', 'src', 'app', 'core', 'proposal-view.ts'), 'utf8');
  for (const [file, afterKey, code, constant, consequenceKey] of [
    [BUILD_TOOL, 'analyticsCubeBuildAfterword', 'ANALYTICS.CUBE.BUILD', 'CONSEQUENCE_ANALYTICSCUBEBUILD', 'analyticsCubeBuildConsequence'],
    [SYNCHRONIZE_TOOL, 'analyticsCubeSynchronizeAfterword', 'ANALYTICS.CUBE.SYNCHRONIZE', 'CONSEQUENCE_ANALYTICSCUBESYNCHRONIZE', 'analyticsCubeSynchronizeConsequence'],
  ]) {
    const afterword = classParameter(file, 'AFTERWORD');
    assert.equal(afterword, stringValue(afterKey), `${file}: AFTERWORD and ${afterKey} are one published word`);
    assert.ok(experience.includes(`"${afterword}"`), `${afterword} is published in EXPERIENCE.md's Fixed strings`);
    assert.equal(classParameter(file, 'CONSEQUENCECODE'), code, `${file} names the consequence code`);
    assert.ok(proposalView.includes(`${constant} = '${code}'`), `proposal-view.ts holds ${code}`);
    assert.ok(experience.includes(`"${stringValue(consequenceKey)}"`), `${consequenceKey} is published in EXPERIENCE.md's Fixed strings`);
  }
  // The card rows the tool labels are strings the client already publishes, or the Cube manager's own.
  const labels = readFileSync(ACTION_TOOL, 'utf8');
  assert.ok(labels.includes('"Cube", "Facts", "Last build", "Last update", "Dependent cubes"'), 'the card rows are the five the story names');
});

test('Story 20.34: the three output lines are published in Fixed strings and built by the port from the same templates', () => {
  // Mutation (Rule 19): respell "Facts updated in" in AnalyticsPort.SyncLines -> this goes red naming the template.
  const experience = readFileSync(EXPERIENCE, 'utf8');
  const port = readFileSync(PORT, 'utf8');
  for (const [template, prefix] of [
    ['Facts in <cube>: <n>', '"Facts in " _ tName _ ": "'],
    ['Build errors in <cube>: <n>', '"Build errors in " _ tName _ ": "'],
    ['Facts updated in <cube>: <n>', '"Facts updated in " _ tName _ ": "'],
  ]) {
    assert.ok(experience.includes(`"${template}"`), `${template} is published in EXPERIENCE.md`);
    assert.ok(port.includes(prefix), `the port builds ${template} from ${prefix}`);
    assert.equal(Object.values(loadStringsValues()).includes(template), false, `${template} is server-only: it is never a strings.ts value`);
  }
});

/** Every value `strings.ts` holds, read once. */
function loadStringsValues() {
  const values = {};
  for (const match of readFileSync(STRINGS_SOURCE, 'utf8').matchAll(/\b(\w+):\s*\n?\s*'((?:[^'\\]|\\.)*)'/g)) values[match[1]] = match[2];
  return values;
}

test("Story 20.34: the code that builds and synchronizes names nothing the story's Never list forbids", () => {
  // Mutation (Rule 19): add a `Job` of the build, a `%KillCube` call or a read of `^OBJ.DSTIME` to AnalyticsPort.PerformCube, or a `/api/deepsee`
  // call to either tool -> this goes red naming the file and the word; a mention in a `///` doc line or in a string is not code.
  const rules = [
    { word: /\/api\/deepsee|%Api\.DeepSee|%DeepSee\.REST/i, keepStrings: true, what: 'call of the vendor REST API' },
    { word: /%KillCube|%FixBuildErrors|%SetAgentCount|%escalateToBuild|%SetAgent/i, keepStrings: false, what: 'vendor method the story forbids' },
    { word: /\bJOB\b/i, keepStrings: false, what: 'background job' },
    { word: /\^OBJ\.DSTIME|\^IRIS\.Temp\.DeepSee/i, keepStrings: true, what: 'read or write of the vendor\'s tracking nodes' },
  ];
  for (const file of [PORT, BUILD_TOOL, SYNCHRONIZE_TOOL, ACTION_TOOL]) {
    const source = readFileSync(file, 'utf8');
    for (const { word, keepStrings, what } of rules) {
      assert.ok(!word.test(codeOf(source, keepStrings)), `${file} holds no ${what}`);
    }
  }
  // The two vendor calls are exactly the ones the story names.
  const code = codeOf(readFileSync(PORT, 'utf8'), true);
  assert.ok(code.includes('%BuildCube(pCube, 1, 0, 0, 0, 0, .tStats)'), 'the build call is %BuildCube(cube, 1, 0, 0, 0, 0, .stats)');
  // Story 24.13: the call passes the vendor's own defaults for its read-committed, reference-check and async arguments to reach its statistics argument.
  assert.ok(code.includes('%SynchronizeCube(pCube, 0, .tFacts, 1, 1, 0, .tStats)'), 'the synchronize call is %SynchronizeCube(cube, 0, .facts, 1, 1, 0, .stats)');
  const calls = codeOf(readFileSync(PORT, 'utf8'), false);
  assert.equal((calls.match(/##class\(%DeepSee\.Utils\)\.%BuildCube\(/g) ?? []).length, 1, 'and %BuildCube is called once outside a string');
  // Mutation (Rule 19): add `Set tX = $Get(^DeepSee.Fact(1))` to AnalyticsPort or to a tool -> this goes red; the one vendor-global
  // reference the Never list allows is the "SYNC" lock probe, taken and released.
  const vendorGlobal = /\^(?:\|[^|]*\||\[[^\]]*\])?DeepSee\./i;
  const referencing = (file) => codeOf(readFileSync(file, 'utf8'), false).split('\n').filter((line) => vendorGlobal.test(line)).map((line) => line.trim());
  assert.deepEqual(
    referencing(PORT),
    [
      // Story 24.13 (AD-65), strings blanked: the analytics settings read by name, the page's own nodes and each worklist option, which the General and Worklists tabs read and never write.
      'Set tStored = $Data(^DeepSee.UserPortalSettings(tNodeOne)) # 2',
      'Set tValue = $Get(^DeepSee.UserPortalSettings(tNodeOne), $List(tSetting, 4))',
      'Set tStored = $Data(^DeepSee.UserPortalSettings(tNodeOne, tNodeTwo)) # 2',
      'Set tValue = $Get(^DeepSee.UserPortalSettings(tNodeOne, tNodeTwo), $List(tSetting, 4))',
      `Set pData(pData) = $ListBuild(tPage, tPanel, $ClassMethod(tClass, ""), tClass, ''$Data(^DeepSee.UserPortalSettings("", tPage, tPanel, tAt)), ''(+$Get(^DeepSee.UserPortalSettings(""))))`,
      'Lock +^DeepSee.Build(tIndex, ""):0 Else  Quit 1',
      'Lock -^DeepSee.Build(tIndex, "")',
      // Story 24.2 (AD-65), strings blanked: the term list editor's fit probe in a process-private global that nothing writes, its hide-value
      // read, and its two named nodes, the hide-value flag and an entry's removal with the modified stamp.
      'Set tProbe = $Data(^||DeepSee.TermList(tList))',
      'Set tProbe = $Data(^||DeepSee.TermList(tList, "", pKey, $ZConvert(pField, "")))',
      'Set pData("") = \'\'$Get(^DeepSee.TermList($ZConvert(pName, ""), ""))',
      'Set ^DeepSee.TermList(tId, "") = 1',
      'Kill ^DeepSee.TermList(tId, "")',
      'Kill ^DeepSee.TermList(tId, "", pKey)',
      'Set ^DeepSee.TermList(tId, "") = $ZDateTime($Horolog, 3)',
      // Story 24.11 (AD-65), strings blanked: the listing group write's reads of the registry the vendor's compile checks before it refuses, the cube registry's
      // listing-group switch and each target cube's own and registered listings, which the pre-checks read and never write.
      'If $Data(tSaved($ZConvert(tModel.name, ""))) || $Data(^DeepSee.ListingGroups("", $ZConvert(tModel.name, ""))) || ##class(%Dictionary.ClassDefinition).%ExistsId($Select(pOp = "": pBody.%Get(""), 1: pNewClass)) Set pCode = ""',
      `If '##class(%DeepSee.Utils).%CubeExists(tCube) || $Get(^DeepSee.Cubes("", $ZConvert(tCube, ""), ""), 0) {`,
      `If $Data(^DeepSee.Cubes("", tCubeU, "", tName)) || ($Data(^DeepSee.ListingGroups("", tCubeU, "", tName, "")) && ($Get(^DeepSee.ListingGroups("", tCubeU, "", tName, "")) '= $ZConvert(tModel.name, ""))) {`,
      // Story 24.13 Batch 2 (AD-65), strings blanked: the General form composed in the target namespace from each node as it stands (the one method that calls the page's save), and the
      // Worklists options read before the page's own call that turns them off removes them, which the same method sets again through the page's own call.
      'Set tValue = $Get(^DeepSee.UserPortalSettings($List(tEntry, 2)), $List(tEntry, 4))',
      'Set tValue = $Get(^DeepSee.UserPortalSettings($List(tEntry, 2), $List(tEntry, 3)), $List(tEntry, 4))',
      'Set tPage = $Order(^DeepSee.UserPortalSettings("", tPage))',
      'Set tPanel = $Order(^DeepSee.UserPortalSettings("", tPage, tPanel))',
      'Set tNumber = $Order(^DeepSee.UserPortalSettings("", tPage, tPanel, tNumber), 1, tClass)',
    ],
    'the port names a vendor global only in the lock probe, in the term list editor\'s named nodes, in the listing group write\'s pre-checks and in the analytics settings\' reads by name'
  );
  for (const file of [BUILD_TOOL, SYNCHRONIZE_TOOL, ACTION_TOOL]) assert.deepEqual(referencing(file), [], `${file} names no vendor global`);
});

/** The refusals of the term list editor (Story 24.2), each pinned to its `strings.ts` key. */
const TERM_LIST_SENTENCES = [
  ['REASONTERMLISTTAKEN', 'analyticsRefusalTermListTaken'],
  ['REASONTERMLISTENTRYTAKEN', 'analyticsRefusalTermListEntryTaken'],
  ['REASONTERMLISTABSENT', 'analyticsRefusalTermListAbsent'],
  ['REASONTERMLISTNAME', 'analyticsRefusalTermListName'],
  ['REASONTERMLISTKEY', 'analyticsRefusalTermListKey'],
  ['REASONTERMLISTFIELD', 'analyticsRefusalTermListField'],
  ['REASONTERMLISTNOFIELD', 'analyticsRefusalTermListNoField'],
  ['REASONTERMLISTFIELDINUSE', 'analyticsRefusalTermListFieldInUse'],
  ['REASONTERMLISTVALUE', 'analyticsRefusalTermListValue'],
  ['REASONTERMLISTREADONLY', 'analyticsRefusalTermListReadonly'],
  ['REASONTERMLISTNOTJOURNALED', 'analyticsRefusalTermListNotJournaled'],
  // Story 24.10: the term list transfers' three refusals.
  ['REASONTERMLISTTOOLARGE', 'analyticsRefusalTermListTooLarge'],
  ['REASONTERMLISTIMPORTSHAPE', 'analyticsRefusalTermListImportShape'],
  ['REASONTERMLISTIMPORTCHANGED', 'analyticsRefusalTermListImportChanged'],
];

const TERM_LIST_TOOLS = ['AnalyticsTermListAdd', 'AnalyticsTermListUpdate', 'AnalyticsTermListDelete', 'AnalyticsTermListEntryAdd', 'AnalyticsTermListEntrySet', 'AnalyticsTermListEntryRemove', 'AnalyticsTermListExport', 'AnalyticsTermListImport', 'AnalyticsTermListCopy'].map((name) => join(REPO_ROOT, 'src', 'OcuPilot', 'Screen', 'Tool', `${name}.cls`));

test('Story 24.2: each term list refusal is one sentence on both surfaces, published in Fixed strings', () => {
  // Mutation (Rule 19): change one word of REASONTERMLISTFIELDINUSE in AnalyticsError.cls (or of analyticsRefusalTermListFieldInUse in strings.ts) -> this
  // goes red naming both.
  const experience = readFileSync(EXPERIENCE, 'utf8');
  for (const [parameter, key] of TERM_LIST_SENTENCES) {
    const server = serverSentence(parameter);
    assert.equal(server, stringValue(key), `${parameter} and ${key} are one published sentence`);
    assert.ok(experience.includes(`"${server}"`), `${parameter}'s sentence is published in EXPERIENCE.md's Fixed strings`);
    assert.ok(!server.toLowerCase().includes('agent'), `${parameter} names no caller: ${server}`);
  }
});

test("Story 24.2: the delete's and the remove's consequence codes name one published sentence each, on the tool, proposal-view.ts and Fixed strings", () => {
  // Mutation (Rule 19): change CONSEQUENCECODE in AnalyticsTermListDelete.cls to ANALYTICS.TERMLIST.REMOVE -> this goes red naming the tool.
  const experience = readFileSync(EXPERIENCE, 'utf8');
  const proposalView = readFileSync(join(REPO_ROOT, 'ui', 'src', 'app', 'core', 'proposal-view.ts'), 'utf8');
  for (const [file, code, constant, consequenceKey] of [
    [TERM_LIST_TOOLS[2], 'ANALYTICS.TERMLIST.DELETE', 'CONSEQUENCE_ANALYTICSTERMLISTDELETE', 'analyticsTermListDeleteConsequence'],
    [TERM_LIST_TOOLS[5], 'ANALYTICS.TERMLIST.REMOVE', 'CONSEQUENCE_ANALYTICSTERMLISTREMOVE', 'analyticsTermListRemoveConsequence'],
  ]) {
    assert.equal(classParameter(file, 'CONSEQUENCECODE'), code, `${file} names the consequence code`);
    assert.ok(proposalView.includes(`${constant} = '${code}'`), `proposal-view.ts holds ${code}`);
    assert.ok(experience.includes(`"${stringValue(consequenceKey)}"`), `${consequenceKey} is published in EXPERIENCE.md's Fixed strings`);
  }
});

test('Story 24.2: the six tools declare write, the analytics port and the classic Term List Manager, and the port calls only the vendor calls the stories name', () => {
  // Mutation (Rule 19): call %ImportCSV from AnalyticsPort.cls -> this goes red naming the call. Story 24.10 adds the three transfer tools, and the
  // port's %ExportCSV (to a resolved file or inside an output capture) and %ParseCSVRecord; the vendor's %ImportCSV stays out, because it deletes
  // and recreates a held list and reads lines by the stream's own terminator.
  for (const file of TERM_LIST_TOOLS) {
    const source = readFileSync(file, 'utf8');
    assert.ok(source.includes('Extends OcuPilot.Screen.Tool.AnalyticsTermList'), `${file} extends the term list tool base`);
  }
  const base = readFileSync(join(REPO_ROOT, 'src', 'OcuPilot', 'Screen', 'Tool', 'AnalyticsTermListAction.cls'), 'utf8');
  assert.ok(base.includes('Parameter CLASSICPAGES = "%DeepSee.UI.TermListManager";'), 'the base declares the classic Term List Manager');
  const code = codeOf(readFileSync(PORT, 'utf8'), false);
  for (const call of ['%CreateTermList(', '%FromObj(', '%SetValue(', '%DeleteTermList(', '%ToObj(']) {
    assert.ok(code.includes(`##class(%DeepSee.TermList).${call}`) || code.includes(`.${call}`), `the port calls ${call}`);
  }
  for (const never of [/%ImportCSV/, /%GetTermListNameFromStream/, /%DeepSee\.REST/, /%Api\.DeepSee/, /\/api\/deepsee/i]) {
    assert.ok(!never.test(code), `the port never names ${never}`);
  }
  const vendorCalls = [...code.matchAll(/##class\(%DeepSee\.TermList\)\.(%\w+)\(/g)].map((match) => match[1]);
  assert.deepEqual([...new Set(vendorCalls)].sort(), ['%CreateTermList', '%DeleteTermList', '%ExportCSV', '%FromObj', '%GetTermLists', '%ParseCSVRecord', '%SetValue', '%ToObj'], 'and only those TermList calls');
});

/** The folder manager's refusals (Story 24.10), each pinned to its `strings.ts` key; the too-large and changed sentences are the term lists' own. */
const FOLDER_ITEM_SENTENCES = [
  ['REASONFOLDERITEMTAKEN', 'analyticsRefusalFolderItemTaken'],
  ['REASONFOLDERITEMABSENT', 'analyticsRefusalFolderItemAbsent'],
  ['REASONFOLDERITEMLOCKED', 'analyticsRefusalFolderItemLocked'],
  ['REASONFOLDERITEMREADONLY', 'analyticsRefusalFolderItemReadonly'],
  ['REASONFOLDERITEMNOTJOURNALED', 'analyticsRefusalFolderItemNotJournaled'],
  ['REASONFOLDERITEMIMPORTSHAPE', 'analyticsRefusalFolderItemImportShape'],
  ['REASONFOLDERITEMTOOLARGE', 'analyticsRefusalTermListTooLarge'],
  ['REASONFOLDERITEMIMPORTCHANGED', 'analyticsRefusalTermListImportChanged'],
];

const FOLDER_ITEM_TOOLS = ['AnalyticsFolderItemExport', 'AnalyticsFolderItemImport', 'AnalyticsFolderItemDelete'].map((name) => join(REPO_ROOT, 'src', 'OcuPilot', 'Screen', 'Tool', `${name}.cls`));

test('Story 24.10: each folder item refusal is one sentence on both surfaces, published in Fixed strings', () => {
  // Mutation (Rule 19): change one word of REASONFOLDERITEMLOCKED in AnalyticsError.cls (or of analyticsRefusalFolderItemLocked in strings.ts) -> this goes red
  // naming both.
  const experience = readFileSync(EXPERIENCE, 'utf8');
  for (const [parameter, key] of FOLDER_ITEM_SENTENCES) {
    const server = serverSentence(parameter);
    assert.equal(server, stringValue(key), `${parameter} and ${key} are one published sentence`);
    assert.ok(experience.includes(`"${server}"`), `${parameter}'s sentence is published in EXPERIENCE.md's Fixed strings`);
    assert.ok(!server.toLowerCase().includes('agent'), `${parameter} names no caller: ${server}`);
  }
});

test("Story 24.10: the folder item delete's consequence code names one published sentence, on the tool, proposal-view.ts and Fixed strings", () => {
  // Mutation (Rule 19): change CONSEQUENCECODE in AnalyticsFolderItemDelete.cls to ANALYTICS.TERMLIST.DELETE -> this goes red naming the tool.
  const experience = readFileSync(EXPERIENCE, 'utf8');
  const proposalView = readFileSync(join(REPO_ROOT, 'ui', 'src', 'app', 'core', 'proposal-view.ts'), 'utf8');
  assert.equal(classParameter(FOLDER_ITEM_TOOLS[2], 'CONSEQUENCECODE'), 'ANALYTICS.FOLDERITEM.DELETE', 'the delete tool names the consequence code');
  assert.ok(proposalView.includes("CONSEQUENCE_ANALYTICSFOLDERITEMDELETE = 'ANALYTICS.FOLDERITEM.DELETE'"), 'proposal-view.ts holds the code');
  assert.ok(experience.includes(`"${stringValue('analyticsFolderItemDeleteConsequence')}"`), 'the consequence is published in EXPERIENCE.md\'s Fixed strings');
});

test('Story 24.11: the port reads listing groups through the two measured pure reads only, and writes none', () => {
  // Mutation (Rule 19): call %RegisterRecentItem, %SaveToClass or %DeleteListingGroup from AnalyticsPort.cls -> this goes red naming the call.
  const code = codeOf(readFileSync(PORT, 'utf8'), false);
  const vendorCalls = [...code.matchAll(/##class\(%DeepSee\.ListingGroup\)\.(%\w+)\(/g)].map((match) => match[1]);
  assert.deepEqual([...new Set(vendorCalls)].sort(), ['%GetListingGroups', '%GetModel'], 'and only those ListingGroup calls');
  for (const never of [/%SaveToClass/, /%DeleteListingGroup/, /%RegisterRecentItem/, /%DeepSee\.ListingGroupDefinition/]) {
    assert.ok(!never.test(code), `the port never names ${never}`);
  }
});

/** The refusals of the listing group writes (Story 24.11, Batch 2), each pinned to its `strings.ts` key. */
const LISTING_GROUP_SENTENCES = [
  ['REASONLISTINGGROUPTAKEN', 'analyticsRefusalListingGroupTaken'],
  ['REASONLISTINGGROUPCLASS', 'analyticsRefusalListingGroupClass'],
  ['REASONLISTINGGROUPCUBE', 'analyticsRefusalListingGroupCube'],
  ['REASONLISTINGGROUPLISTINGTAKEN', 'analyticsRefusalListingGroupListingTaken'],
  ['REASONLISTINGGROUPAMBIGUOUS', 'analyticsRefusalListingGroupAmbiguous'],
  ['REASONLISTINGGROUPCOMPILE', 'analyticsRefusalListingGroupCompile'],
  ['REASONLISTINGGROUPABSENT', 'analyticsRefusalListingGroupAbsent'],
  ['REASONLISTINGGROUPREADONLY', 'analyticsRefusalListingGroupReadonly'],
];

const LISTING_GROUP_TOOLS = [
  'AnalyticsListingGroupAdd',
  'AnalyticsListingGroupUpdate',
  'AnalyticsListingGroupCopy',
  'AnalyticsListingGroupDelete',
  'AnalyticsListingAdd',
  'AnalyticsListingSet',
  'AnalyticsListingRemove',
].map((name) => join(REPO_ROOT, 'src', 'OcuPilot', 'Screen', 'Tool', `${name}.cls`));

test('Story 24.11 Batch 2: each listing group refusal and consequence is published once, and the port saves, compiles and deletes through the source code port', () => {
  // Mutation (Rule 19): change one word of REASONLISTINGGROUPCOMPILE in AnalyticsError.cls (or of analyticsRefusalListingGroupCompile in strings.ts) -> this goes red naming the pair;
  // swap the SQL and SAVE returns in proposal-view.ts's `consequenceSentence` -> this goes red naming the constant;
  // call %SaveToClass, %DeleteListingGroup or $System.OBJ.Delete from AnalyticsPort.cls -> the second half goes red naming the call.
  const errors = readFileSync(join(REPO_ROOT, 'src', 'OcuPilot', 'Api', 'AnalyticsError.cls'), 'utf8');
  const values = Object.fromEntries(Object.entries(loadStringsValues()).map(([key, value]) => [key, value.replace(/\\'/g, "'")]));
  const experience = readFileSync(EXPERIENCE, 'utf8');
  for (const [parameter, key] of LISTING_GROUP_SENTENCES) {
    const declared = errors.match(new RegExp(`Parameter ${parameter} = "([^"]*)";`))?.[1];
    assert.ok(declared !== undefined, `${parameter} is declared`);
    assert.equal(declared, values[key], `${parameter} equals strings.ts ${key}`);
    assert.ok(experience.includes(`"${values[key]}"`), `${key} is published in EXPERIENCE.md's Fixed strings`);
  }
  const proposalView = readFileSync(join(REPO_ROOT, 'ui', 'src', 'app', 'core', 'proposal-view.ts'), 'utf8');
  for (const [code, key] of [
    ['ANALYTICS.LISTINGGROUP.DELETE', 'analyticsListingGroupDeleteConsequence'],
    ['ANALYTICS.LISTINGGROUP.REMOVE', 'analyticsListingRemoveConsequence'],
    ['ANALYTICS.LISTINGGROUP.SQL', 'analyticsListingSqlConsequence'],
    ['ANALYTICS.LISTINGGROUP.SAVE', 'analyticsListingGroupSaveConsequence'],
  ]) {
    const constant = `CONSEQUENCE_ANALYTICSLISTINGGROUP${code.split('.').pop()}`;
    assert.ok(proposalView.includes(`${constant} = '${code}'`), `proposal-view.ts holds ${code}`);
    assert.ok(proposalView.includes(`if (code === ${constant}) return STRINGS.${key};`), `${constant} maps to ${key}`);
    assert.ok(experience.includes(`"${values[key]}"`), `${key} is published in EXPERIENCE.md's Fixed strings`);
  }
  assert.equal(classParameter(LISTING_GROUP_TOOLS[3], 'CONSEQUENCECODE'), 'ANALYTICS.LISTINGGROUP.DELETE', 'the group delete names its consequence code');
  assert.equal(classParameter(LISTING_GROUP_TOOLS[6], 'CONSEQUENCECODE'), 'ANALYTICS.LISTINGGROUP.REMOVE', 'the listing remove names its consequence code');
  for (const file of LISTING_GROUP_TOOLS) {
    const text = readFileSync(file, 'utf8');
    assert.ok(/Extends OcuPilot\.Screen\.Tool\.Analytics(?:ListingGroup|Listing)Action/.test(text), `${file} extends a listing group tool base`);
  }
  const base = readFileSync(join(REPO_ROOT, 'src', 'OcuPilot', 'Screen', 'Tool', 'AnalyticsListingGroupAction.cls'), 'utf8');
  assert.ok(base.includes('Parameter CLASSICPAGES = "%DeepSee.UI.ListingGroupManager";'), 'the base declares the classic Listing Group Manager');
  assert.ok(base.includes('Extends OcuPilot.Screen.Tool.AnalyticsAction'), 'and extends the analytics write base, whose port is the analytics port');
  const code = codeOf(readFileSync(PORT, 'utf8'), false);
  const vendorCalls = [...code.matchAll(/##class\(%DeepSee\.ListingGroup\)\.(%\w+)\(/g)].map((match) => match[1]);
  assert.deepEqual([...new Set(vendorCalls)].sort(), ['%GetListingGroups', '%GetModel'], 'the port still calls only the two measured ListingGroup reads');
  for (const never of [/%SaveToClass/, /%DeleteListingGroup/, /%RegisterRecentItem/, /\$System\.OBJ\.(?!IsUpToDate\()/i, /%Api\.Atelier/]) {
    assert.ok(!never.test(code), `the port never names ${never}`);
  }
  assert.ok(code.includes('##class(OcuPilot.Kernel.SourceDocument).Save('), 'the write saves through the shared source document helper');
});

test('Story 24.12: the port reads quality measures through the three measured pure reads and IsUpToDate only, and writes none', () => {
  // Mutation (Rule 19): call %SaveQMsrDefinition from AnalyticsPort.cls -> this goes red naming the call.
  const code = codeOf(readFileSync(PORT, 'utf8'), false);
  const vendorCalls = [...code.matchAll(/##class\(%DeepSee\.QualityMeasure\.Utils\)\.(%\w+)\(/g)].map((match) => match[1]);
  assert.deepEqual([...new Set(vendorCalls)].sort(), ['%GetModel', '%GetQualityMeasureClass', '%GetQualityMeasureList'], 'and only those Utils calls');
  const objCalls = [...code.matchAll(/\$System\.OBJ\.(\w+)\(/gi)].map((match) => match[1]);
  assert.deepEqual([...new Set(objCalls)], ['IsUpToDate'], 'and the one $System.OBJ call');
  for (const never of [/%SaveQMsrDefinition/, /DeleteQMeasure/, /LastQMSR/, /\$classmethod\([^)]*%GetModel/i, /##class\(%SYSTEM\.OBJ\)/i]) {
    assert.ok(!never.test(code), `the port never names ${never}`);
  }
});

/** The refusals of the quality measure writes (Story 24.12, Batch 2), each pinned to its `strings.ts` key; the class sentence is the listing groups'. */
const QUALITY_MEASURE_SENTENCES = [
  ['REASONQUALITYMEASURETAKEN', 'analyticsRefusalQualityMeasureTaken'],
  ['REASONQUALITYMEASUREAMBIGUOUS', 'analyticsRefusalQualityMeasureAmbiguous'],
  ['REASONQUALITYMEASURECOMPILE', 'analyticsRefusalQualityMeasureCompile'],
  ['REASONQUALITYMEASUREABSENT', 'analyticsRefusalQualityMeasureAbsent'],
  ['REASONQUALITYMEASUREREADONLY', 'analyticsRefusalQualityMeasureReadonly'],
  ['REASONQUALITYMEASUREEXPRESSION', 'analyticsRefusalQualityMeasureExpression'],
  ['REASONQUALITYMEASURELINKED', 'analyticsRefusalQualityMeasureLinked'],
  ['REASONQUALITYMEASURECLASS', 'analyticsRefusalListingGroupClass'],
  ['REASONQUALITYMEASUREELEMENTTAKEN', 'analyticsRefusalQualityMeasureElementTaken'],
  ['REASONQUALITYMEASUREMETATAKEN', 'analyticsRefusalQualityMeasureMetaTaken'],
  ['REASONQUALITYMEASUREPARTABSENT', 'analyticsRefusalQualityMeasurePartAbsent'],
  ['REASONQUALITYMEASURELINKEDPARTS', 'analyticsRefusalQualityMeasureLinkedParts'],
];

const QUALITY_MEASURE_TOOLS = ['AnalyticsQualityMeasureAdd', 'AnalyticsQualityMeasureUpdate', 'AnalyticsQualityMeasureCopy', 'AnalyticsQualityMeasureDelete'].map((name) =>
  join(REPO_ROOT, 'src', 'OcuPilot', 'Screen', 'Tool', `${name}.cls`)
);

const SETTING_SENTENCES = [
  ['REASONSETTINGREADONLY', 'analyticsRefusalSettingReadOnly'],
  ['REASONSETTINGSECRET', 'analyticsRefusalSettingSecret'],
  ['REASONSETTINGSAVE', 'analyticsSettingSaveConsequence'],
  ['REASONWORKLISTNOTCUSTOMIZED', 'analyticsRefusalWorklistNotCustomized'],
  ['REASONWORKLISTABSENT', 'analyticsRefusalWorklistAbsent'],
];

test('Story 24.13 Batch 2: each settings refusal and the save consequence is published once and mapped for the card', () => {
  // Mutation (Rule 19): change one word of REASONWORKLISTNOTCUSTOMIZED in AnalyticsError.cls (or of analyticsRefusalWorklistNotCustomized in strings.ts) -> this goes red naming the pair;
  // drop the `ANALYTICS.SETTING.SAVE` branch from proposal-view.ts's `consequenceSentence` -> the second half goes red naming the constant.
  const errors = readFileSync(join(REPO_ROOT, 'src', 'OcuPilot', 'Api', 'AnalyticsError.cls'), 'utf8');
  const values = Object.fromEntries(Object.entries(loadStringsValues()).map(([key, value]) => [key, value.replace(/\\'/g, "'")]));
  const experience = readFileSync(EXPERIENCE, 'utf8');
  for (const [parameter, key] of SETTING_SENTENCES) {
    const declared = errors.match(new RegExp(`Parameter ${parameter} = "([^"]*)";`))?.[1];
    assert.ok(declared !== undefined, `${parameter} is declared`);
    assert.equal(declared, values[key], `${parameter} equals strings.ts ${key}`);
    assert.ok(experience.includes(`"${values[key]}"`), `${key} is published in EXPERIENCE.md's Fixed strings`);
  }
  const proposalView = readFileSync(join(REPO_ROOT, 'ui', 'src', 'app', 'core', 'proposal-view.ts'), 'utf8');
  assert.ok(proposalView.includes("CONSEQUENCE_ANALYTICSSETTINGSAVE = 'ANALYTICS.SETTING.SAVE'"), 'proposal-view.ts holds ANALYTICS.SETTING.SAVE');
  assert.ok(proposalView.includes('if (code === CONSEQUENCE_ANALYTICSSETTINGSAVE) return STRINGS.analyticsSettingSaveConsequence;'), 'and maps it to the sentence');
  for (const name of ['AnalyticsSettingSet', 'AnalyticsSettingKey']) {
    assert.equal(classParameter(join(REPO_ROOT, 'src', 'OcuPilot', 'Screen', 'Tool', `${name}.cls`), 'CONSEQUENCECODE'), 'ANALYTICS.SETTING.SAVE', `${name} names its consequence code`);
  }
});

test('Story 24.13: the port reads the analytics settings through the measured pure reads and by name, runs no expression and writes a setting only through the page\'s own setters', () => {
  // Mutation (Rule 19): call ##class(%DeepSee.UserPortal.Utils).%GetUserSetting from AnalyticsPort.cls, or set a node of ^DeepSee.UserPortalSettings -> this goes red naming the call.
  const code = codeOf(readFileSync(PORT, 'utf8'), false);
  const portalCalls = [...code.matchAll(/##class\(%DeepSee\.UserPortal\.Utils\)\.(%\w+)\(/g)].map((match) => match[1]);
  assert.deepEqual([...new Set(portalCalls)].sort(), ['%GetChartSeriesSchemes', '%GetColorSchemes', '%GetUserIconList', '%GetUserSettingsList'], 'the port calls only the two measured list reads of the user portal and the two scheme lists the General tab offers');
  // Story 24.13 Batch 2 (AD-65): the classic page's three setters are named in their seams only, each seam a method of its own that runs in the target namespace.
  const seamBody = (name) => code.match(new RegExp(`ClassMethod ${name}\\([^\\n]*\\n\\{\\n[\\s\\S]*?\\n\\}\\n`))?.[0] ?? '';
  const seams = { SettingsSaveHere: /SaveToServer\(/, SettingCustomHere: /SetCustom\(|SetOption\(/, VendorWorklistOption: /SetOption\(/ };
  let outside = code;
  for (const [name, setter] of Object.entries(seams)) {
    const body = seamBody(name);
    assert.ok(setter.test(body), `${name} calls the page's own setter`);
    outside = outside.replace(body, '');
  }
  for (const never of [/%GetUserSetting\(/, /%SetUserSetting/, /%SetUserIcon/, /%RemoveUser/, /%ClearUser/, /SaveToServer/, /SetOption\(/, /SetCustom\(/, /%DeepSee\.UI\.Settings/]) {
    assert.ok(!never.test(outside), `the port names ${never} in no method but its seam`);
  }
  assert.ok(!/\b(Set|Kill|Merge|Lock)\s+[+-]?\^DeepSee\.(UserPortalSettings|User\.)|\$(Increment|Order)\(\^DeepSee\.User[^\n]*\)\s*=/i.test(code), 'and no line of the port sets, kills, merges into or locks one of the three settings globals');
  assert.ok(!/\bXECUTE\b|\bX\s+"|\$XECUTE/i.test(code), 'and the port executes no stored expression');
});

test('Story 24.12 Batch 2: each quality measure refusal and consequence is published once, and the port writes only through the source code port and the model', () => {
  // Mutation (Rule 19): change one word of REASONQUALITYMEASURELINKED in AnalyticsError.cls (or of analyticsRefusalQualityMeasureLinked in strings.ts) -> this goes red naming the pair;
  // swap the delete and save returns in proposal-view.ts's `consequenceSentence` -> this goes red naming the constant;
  // call %SaveQMsrDefinition, DeleteQMeasure or $System.OBJ.Delete from AnalyticsPort.cls -> the second half goes red naming the call.
  const errors = readFileSync(join(REPO_ROOT, 'src', 'OcuPilot', 'Api', 'AnalyticsError.cls'), 'utf8');
  const values = Object.fromEntries(Object.entries(loadStringsValues()).map(([key, value]) => [key, value.replace(/\\'/g, "'")]));
  const experience = readFileSync(EXPERIENCE, 'utf8');
  for (const [parameter, key] of QUALITY_MEASURE_SENTENCES) {
    const declared = errors.match(new RegExp(`Parameter ${parameter} = "([^"]*)";`))?.[1];
    assert.ok(declared !== undefined, `${parameter} is declared`);
    assert.equal(declared, values[key], `${parameter} equals strings.ts ${key}`);
    assert.ok(experience.includes(`"${values[key]}"`), `${key} is published in EXPERIENCE.md's Fixed strings`);
  }
  const proposalView = readFileSync(join(REPO_ROOT, 'ui', 'src', 'app', 'core', 'proposal-view.ts'), 'utf8');
  for (const [code, key] of [
    ['ANALYTICS.QUALITYMEASURE.DELETE', 'analyticsQualityMeasureDeleteConsequence'],
    ['ANALYTICS.QUALITYMEASURE.REMOVE', 'analyticsQualityMeasureRemoveConsequence'],
    ['ANALYTICS.QUALITYMEASURE.SAVE', 'analyticsQualityMeasureSaveConsequence'],
  ]) {
    const constant = `CONSEQUENCE_ANALYTICSQUALITYMEASURE${code.split('.').pop()}`;
    assert.ok(proposalView.includes(`${constant} = '${code}'`), `proposal-view.ts holds ${code}`);
    assert.ok(proposalView.includes(`if (code === ${constant}) return STRINGS.${key};`), `${constant} maps to ${key}`);
    assert.ok(experience.includes(`"${values[key]}"`), `${key} is published in EXPERIENCE.md's Fixed strings`);
  }
  assert.equal(classParameter(QUALITY_MEASURE_TOOLS[3], 'CONSEQUENCECODE'), 'ANALYTICS.QUALITYMEASURE.DELETE', 'the delete names its consequence code');
  for (const name of ['AnalyticsQualityMeasureElementRemove', 'AnalyticsQualityMeasureMetaRemove']) {
    assert.equal(classParameter(join(REPO_ROOT, 'src', 'OcuPilot', 'Screen', 'Tool', `${name}.cls`), 'CONSEQUENCECODE'), 'ANALYTICS.QUALITYMEASURE.REMOVE', `${name} names its consequence code`);
  }
  for (const file of QUALITY_MEASURE_TOOLS) {
    assert.ok(readFileSync(file, 'utf8').includes('Extends OcuPilot.Screen.Tool.AnalyticsQualityMeasureAction'), `${file} extends the quality measure tool base`);
  }
  const base = readFileSync(join(REPO_ROOT, 'src', 'OcuPilot', 'Screen', 'Tool', 'AnalyticsQualityMeasureAction.cls'), 'utf8');
  assert.ok(base.includes('Parameter CLASSICPAGES = "%DeepSee.UI.QualityMeasures";'), 'the base declares the classic Quality Measures Manager');
  const code = codeOf(readFileSync(PORT, 'utf8'), false);
  for (const never of [/%SaveQMsrDefinition/, /DeleteQMeasure/, /LastQMSR/, /\$System\.OBJ\.(?!IsUpToDate\()/i, /%Api\.Atelier/]) {
    assert.ok(!never.test(code), `the port never names ${never}`);
  }
  assert.ok(code.includes('##class(OcuPilot.Kernel.QualityMeasureText).ClassText('), 'a new measure is composed by the shared class text helper');
  assert.ok(code.includes('##class(OcuPilot.Kernel.SourceDocument).Save('), 'and saved through the shared source document helper');
  assert.equal([...code.matchAll(/\.%Validate\(\)/g)].length, 1, 'the model validates itself once, the one added pure call');
});

test('Story 24.10: the three folder manager tools declare write, the analytics port and the classic Folder Manager, and the port loads and compiles nothing', () => {
  // Mutation (Rule 19): call $System.OBJ.Load or an XML reader of a file, stream or URL from AnalyticsPort.cls, or pass a replace flag to %Import -> this goes red naming the call.
  for (const file of FOLDER_ITEM_TOOLS) {
    assert.ok(readFileSync(file, 'utf8').includes('Extends OcuPilot.Screen.Tool.AnalyticsFolderItem'), `${file} extends the folder item tool base`);
  }
  const base = readFileSync(join(REPO_ROOT, 'src', 'OcuPilot', 'Screen', 'Tool', 'AnalyticsFolderItemAction.cls'), 'utf8');
  assert.ok(base.includes('Parameter CLASSICPAGES = "%DeepSee.UI.FolderManager";'), 'the base declares the classic Folder Manager');
  assert.ok(base.includes('Extends OcuPilot.Screen.Tool.AnalyticsAction'), 'and extends the analytics write base, whose port is the analytics port');
  const code = codeOf(readFileSync(PORT, 'utf8'), false);
  for (const never of [/\$System\.OBJ\.(?!IsUpToDate\()/i, /%Compiler/, /%DeepSee\.UserLibrary\.Utils\)\.%ImportContainer/, /%ProcessContainer/, /%KillFolders/]) {
    assert.ok(!never.test(code), `the port never names ${never}`);
  }
  // Story 24.12: an XML reader reads only text the port composed, which it checks before saving it (never a file, stream or URL).
  assert.equal([...code.matchAll(/\.OpenString\(/g)].length, [...code.matchAll(/##class\(%XML\.Reader\)/g)].length, 'every XML reader the port makes opens a string');
  const vendorCalls = [...code.matchAll(/##class\(%DeepSee\.UserLibrary\.Utils\)\.(%\w+)\(/g)].map((match) => match[1]);
  assert.deepEqual([...new Set(vendorCalls)].sort(), ['%DeleteFolderItem', '%Export', '%FolderItemExists', '%GetFavoriteList', '%GetFolderItemClasses', '%GetFolderItemList', '%Import'], 'and only those Utils calls');
  const imports = [...code.matchAll(/\.%Import\(([^)]*)\)/g)].map((match) => match[1]);
  assert.deepEqual(imports, ['tBytes, 0, 0, 0, "", .tLoaded'], 'the one vendor import replaces nothing and kills nothing');
});

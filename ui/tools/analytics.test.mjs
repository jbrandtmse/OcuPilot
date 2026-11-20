/**
 * Story 20.11's Analytics sentence and Story 20.33's MDX sentences, held to the instance's own source (AD-29, AD-39, AD-65).
 *
 * `OcuPilot.Api.AnalyticsError`'s sentences are each one published string on three surfaces: the server sends it, the client's strings
 * table holds it, and EXPERIENCE.md's Fixed strings publish it. The port also declares the pair sets its screens' descriptors repeat, the
 * endpoint list the mirror generator reads, and the consequence the MDX query's confirmation names.
 */

import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { test } from 'node:test';
import { dirname, join, relative, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

const PORT = join(REPO_ROOT, 'src', 'OcuPilot', 'Port', 'AnalyticsPort.cls');

const ERROR = join(REPO_ROOT, 'src', 'OcuPilot', 'Api', 'AnalyticsError.cls');

/** The product classes that run an MDX statement: the port, the MDX kind, the run and the row reader they share, and the agent's read. */
const MDX_CODE = [
  PORT,
  join(REPO_ROOT, 'src', 'OcuPilot', 'Area', 'Analytics', 'MdxQuery.cls'),
  join(REPO_ROOT, 'src', 'OcuPilot', 'Area', 'Analytics', 'PivotRun.cls'),
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
    'Cubes,Measures,Dimensions,Relationships,TermLists,TermListEntries,FolderItems,CubeManager,ListingGroups,ListingGroupListings,QualityMeasures,QualityMeasureElements,QualityMeasureMetas,Settings,Worklists,RuntimeVariables,UserIcons,FolderItemDefinition,DashboardWidgets,PmmlModels,PmmlModel'
  );
  assert.equal(parameter('PMMLPAIRS'), '%DeepSee_Portal:USE,%Development:USE');
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

/** Every ObjectScript source under `src/OcuPilot` outside `Test/`, as paths relative to `src/OcuPilot` with `/` separators. */
function productSources(directory = join(REPO_ROOT, 'src', 'OcuPilot')) {
  const found = [];
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    const name = relative(join(REPO_ROOT, 'src', 'OcuPilot'), path).split(sep).join('/');
    if (entry.isDirectory()) {
      if (name !== 'Test') found.push(...productSources(path));
    } else if (/\.(cls|mac|inc)$/.test(entry.name)) {
      found.push(name);
    }
  }
  return found;
}

test('Story 24.14 Batch 2b: product code calls Terminate( only in the process port and, once, in the PMML test supervisor to end the child it spawned', () => {
  // Mutation (Rule 19): add a `Terminate(` to AnalyticsPort.cls, or a second one to PmmlTest.cls, or one to PmmlTest.CancelJob -> this goes red naming the file, the count or the method.
  const hits = new Map();
  for (const name of productSources()) {
    const count = [...codeOf(readFileSync(join(REPO_ROOT, 'src', 'OcuPilot', ...name.split('/')), 'utf8'), false).matchAll(/\bTerminate\s*\(/gi)].length;
    if (count > 0) hits.set(name, count);
  }
  assert.deepEqual([...hits.keys()].sort(), ['Area/Analytics/PmmlTest.cls', 'Port/ProcessPort.cls'], 'the two classes that end a process');
  assert.equal(hits.get('Area/Analytics/PmmlTest.cls'), 1, 'the PMML test run ends a process in one place');
  const pmml = codeOf(readFileSync(join(REPO_ROOT, 'src', 'OcuPilot', 'Area', 'Analytics', 'PmmlTest.cls'), 'utf8'), false);
  assert.ok(pmml.includes('$SYSTEM.Process.Terminate(pChild)'), 'and it is the supervisor\'s child, the process it spawned');
  assert.ok(pmml.includes('SpawnChild(pKey, pUser, pNamespace, pRequest, pClass, .tChild)') && pmml.includes('Reap(pKey, tChild,'), 'whose process id is the one SpawnChild answered, never one read from storage');
  const cancelAt = pmml.indexOf('ClassMethod CancelJob(');
  const cancelBody = pmml.slice(cancelAt, pmml.indexOf('\n}\n', cancelAt));
  assert.ok(cancelAt >= 0 && cancelBody.length > 0, 'the cancel hook is found');
  assert.ok(!/terminate/i.test(cancelBody), 'and the cancel ends no process: it signals the supervisor');
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
      // Story 24.13 Batch 3 (AD-65), strings blanked: the fit probe of a run-time variable's or an icon's name, in a process-private global that nothing writes.
      'Set tProbe = $Data(^||DeepSee.User.Icons(pName))',
      'Set tProbe = $Data(^||DeepSee.User.Settings(pName, ""))',
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
  ['REASONPIVOTCUBE', 'analyticsRefusalPivotCube'],
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
  // Story 24.13 Batch 3: the four setters of the user portal's run-time variables and icons are named in their own seams below, beside the two list reads and the two scheme lists.
  assert.deepEqual(
    [...new Set(portalCalls)].sort(),
    ['%GetChartSeriesSchemes', '%GetColorSchemes', '%GetUserIconList', '%GetUserSettingsList', '%RemoveUserIcon', '%RemoveUserSetting', '%SetUserIcon', '%SetUserSetting'],
    'the port calls only the two measured list reads of the user portal, the two scheme lists the General tab offers and the four setters the Batch 3 seams hold'
  );
  // Story 24.13 Batch 2 (AD-65): the classic page's three setters are named in their seams only, each seam a method of its own that runs in the target namespace.
  const seamBody = (name) => code.match(new RegExp(`ClassMethod ${name}\\([^\\n]*\\n\\{\\n[\\s\\S]*?\\n\\}\\n`))?.[0] ?? '';
  const seams = {
    SettingsSaveHere: /SaveToServer\(/,
    SettingCustomHere: /SetCustom\(|SetOption\(/,
    VendorWorklistOption: /SetOption\(/,
    VendorRuntimeVariableSet: /\.%SetUserSetting\(/,
    VendorRuntimeVariableRemove: /\.%RemoveUserSetting\(/,
    VendorUserIconSet: /\.%SetUserIcon\(/,
    VendorUserIconRemove: /\.%RemoveUserIcon\(/,
  };
  let outside = code;
  for (const [name, setter] of Object.entries(seams)) {
    const body = seamBody(name);
    assert.ok(setter.test(body), `${name} calls the page's own setter`);
    outside = outside.replace(body, '');
  }
  for (const never of [/%GetUserSetting\(/, /%SetUserSetting/, /%SetUserIcon/, /%RemoveUser/, /%ClearUser/, /ApplySettingToServer|ApplyIconToServer/, /SaveToServer/, /SetOption\(/, /SetCustom\(/, /%DeepSee\.UI\.Settings/]) {
    assert.ok(!never.test(outside), `the port names ${never} in no method but its seam`);
  }
  // Story 24.13 Batch 3: the one call that touches a stored expression is the syntax check, on the line the vendor executes, in the helper that holds it and nowhere else.
  assert.equal((code.match(/##class\(%Library\.Routine\)\.CheckSyntax\(/g) ?? []).length, 1, 'the expression is checked with %Library.Routine.CheckSyntax, once');
  assert.ok(/ClassMethod VariableExpressionHolds\([^\n]*\n\{\n[\s\S]*?CheckSyntax\([\s\S]*?\n\}\n/.test(code), 'and in VariableExpressionHolds');
  assert.ok(!/\b(Set|Kill|Merge|Lock)\s+[+-]?\^DeepSee\.(UserPortalSettings|User\.)|\$(Increment|Order)\(\^DeepSee\.User[^\n]*\)\s*=/i.test(code), 'and no line of the port sets, kills, merges into or locks one of the three settings globals');
  assert.ok(!/\bXECUTE\b|\bX\s+"|\$XECUTE/i.test(code), 'and the port executes no stored expression');
});

/** The refusals and consequences of the run-time variable and icon writes (Story 24.13, Batch 3), each pinned to its `strings.ts` key. */
const SETTING_ENTRY_SENTENCES = [
  ['REASONVARIABLETAKEN', 'analyticsRefusalVariableTaken'],
  ['REASONICONTAKEN', 'analyticsRefusalIconTaken'],
  ['REASONVARIABLEABSENT', 'analyticsRefusalVariableAbsent'],
  ['REASONICONABSENT', 'analyticsRefusalIconAbsent'],
  ['REASONSETTINGNAME', 'analyticsRefusalSettingName'],
  ['REASONSETTINGTEXT', 'analyticsRefusalSettingText'],
  ['REASONVARIABLEEXPRESSION', 'analyticsRefusalVariableExpression'],
  ['REASONVARIABLECODE', 'analyticsVariableCodeConsequence'],
  ['REASONVARIABLEREMOVE', 'analyticsVariableRemoveConsequence'],
  ['REASONICONREMOVE', 'analyticsIconRemoveConsequence'],
];

/** Each Batch 3 tool, whether it is destructive, and the consequence code it names (`''` for none). */
const SETTING_ENTRY_TOOLS = [
  ['AnalyticsRuntimeVariableAdd', 'analytics.runtimevariables.add', false, 'ANALYTICS.VARIABLE.CODE'],
  ['AnalyticsRuntimeVariableSet', 'analytics.runtimevariables.set', false, 'ANALYTICS.VARIABLE.CODE'],
  ['AnalyticsRuntimeVariableRemove', 'analytics.runtimevariables.remove', true, 'ANALYTICS.VARIABLE.REMOVE'],
  ['AnalyticsUserIconAdd', 'analytics.usericons.add', false, ''],
  ['AnalyticsUserIconSet', 'analytics.usericons.set', false, ''],
  ['AnalyticsUserIconRemove', 'analytics.usericons.remove', true, 'ANALYTICS.ICON.REMOVE'],
];

test('Story 24.13 Batch 3: each run-time variable and icon refusal and consequence is published once, the six tools declare their writes and keys, and the expression is checked, never run', () => {
  // Mutation (Rule 19): change one word of REASONVARIABLEEXPRESSION in AnalyticsError.cls (or of analyticsRefusalVariableExpression in strings.ts) -> this goes red naming the pair;
  // drop the `ANALYTICS.VARIABLE.CODE` branch from proposal-view.ts's `consequenceSentence` -> the consequence leg goes red naming the constant;
  // flip `analytics.usericons.remove` to `true` in Baseline.cls -> the key leg goes red naming the tool.
  const errors = readFileSync(ERROR, 'utf8');
  const values = Object.fromEntries(Object.entries(loadStringsValues()).map(([key, value]) => [key, value.replace(/\\'/g, "'")]));
  const experience = readFileSync(EXPERIENCE, 'utf8');
  for (const [parameter, key] of SETTING_ENTRY_SENTENCES) {
    const declared = errors.match(new RegExp(`Parameter ${parameter} = "([^"]*)";`))?.[1];
    assert.ok(declared !== undefined, `${parameter} is declared`);
    assert.equal(declared, values[key], `${parameter} equals strings.ts ${key}`);
    assert.ok(experience.includes(`"${values[key]}"`), `${key} is published in EXPERIENCE.md's Fixed strings`);
    assert.ok(!declared.toLowerCase().includes('agent'), `${parameter} names no caller`);
  }
  for (const [key, text] of [
    ['analyticsRuntimeVariableAddAction', 'Add run-time variable'],
    ['analyticsRuntimeVariableChangeAction', 'Change run-time variable'],
    ['analyticsRuntimeVariableRemoveAction', 'Remove run-time variable'],
    ['analyticsUserIconAddAction', 'Add icon'],
    ['analyticsUserIconChangeAction', 'Change icon'],
    ['analyticsUserIconRemoveAction', 'Remove icon'],
    ['analyticsRuntimeVariablesEmptyAgent', 'add a run-time variable'],
    ['analyticsUserIconsEmptyAgent', 'add a user-defined icon'],
  ]) {
    assert.equal(values[key], text, `${key} is the ruled sentence`);
    assert.ok(experience.includes(`"${text}"`), `${key} is published in EXPERIENCE.md's Fixed strings`);
  }
  const proposalView = readFileSync(join(REPO_ROOT, 'ui', 'src', 'app', 'core', 'proposal-view.ts'), 'utf8');
  for (const [code, constant, key] of [
    ['ANALYTICS.VARIABLE.CODE', 'CONSEQUENCE_ANALYTICSVARIABLECODE', 'analyticsVariableCodeConsequence'],
    ['ANALYTICS.VARIABLE.REMOVE', 'CONSEQUENCE_ANALYTICSVARIABLEREMOVE', 'analyticsVariableRemoveConsequence'],
    ['ANALYTICS.ICON.REMOVE', 'CONSEQUENCE_ANALYTICSICONREMOVE', 'analyticsIconRemoveConsequence'],
  ]) {
    assert.ok(proposalView.includes(`${constant} = '${code}'`), `proposal-view.ts holds ${code}`);
    assert.ok(proposalView.includes(`if (code === ${constant}) return STRINGS.${key};`), `${constant} maps to ${key}`);
  }
  const baseline = readFileSync(join(REPO_ROOT, 'src', 'OcuPilot', 'Kernel', 'Governance', 'Baseline.cls'), 'utf8');
  const toolDir = join(REPO_ROOT, 'src', 'OcuPilot', 'Screen', 'Tool');
  for (const [name, tool, destructive, consequence] of SETTING_ENTRY_TOOLS) {
    const file = join(toolDir, `${name}.cls`);
    assert.equal(classParameter(file, 'TOOLNAME'), tool, `${name} names its tool`);
    assert.equal(classParameter(file, 'DESCRIPTION').length > 0, true, `${name} describes itself`);
    assert.ok(new RegExp(`"${tool.replace(/\./g, '\\.')}": ${destructive ? 'false' : 'true'},`).test(baseline), `${tool} ships ${destructive ? 'off' : 'on'} in the baseline`);
    const hierarchy = [file, join(toolDir, `${name.replace(/(Add|Set|Remove)$/, 'Action')}.cls`), join(toolDir, 'AnalyticsSettingEntryAction.cls')].map((path) => readFileSync(path, 'utf8')).join('\n');
    assert.equal(/Parameter DESTRUCTIVE As BOOLEAN = 1;/.test(readFileSync(file, 'utf8')), destructive, `${name} is destructive only as a removal`);
    const optional = (path) => new RegExp('^Parameter CONSEQUENCECODE(?: As \\w+)? = "([^"]*)";', 'm').exec(readFileSync(path, 'utf8'))?.[1] ?? '';
    const named = optional(file) || optional(join(toolDir, `${name.replace(/(Add|Set|Remove)$/, 'Action')}.cls`));
    assert.equal(named, consequence, `${name} names its consequence code`);
    assert.ok(hierarchy.includes('Parameter CLASSICPAGES = "%DeepSee.UI.Settings";'), `${name} declares the classic Settings page`);
  }
  const entryBase = readFileSync(join(toolDir, 'AnalyticsSettingEntryAction.cls'), 'utf8');
  assert.ok(entryBase.includes('Extends OcuPilot.Screen.Tool.AnalyticsAction'), 'the shared base extends the analytics write base, whose port is the analytics port');
  for (const global of ['^DeepSee.User.Settings', '^DeepSee.User.Icons']) {
    assert.ok(readFileSync(join(toolDir, 'AnalyticsRuntimeVariableAction.cls'), 'utf8').includes(`"${global}"`) || readFileSync(join(toolDir, 'AnalyticsUserIconAction.cls'), 'utf8').includes(`"${global}"`), `a base names ${global} as its destination`);
  }
  // The expression is text on every surface: the port runs none, and no tool or save names a call that would.
  for (const file of ['AnalyticsSettingEntryAction.cls', 'AnalyticsRuntimeVariableAdd.cls', 'AnalyticsRuntimeVariableSet.cls']) {
    assert.ok(!/%GetUserSetting\(|\bXECUTE\b|\$XECUTE/i.test(codeOf(readFileSync(join(toolDir, file), 'utf8'), false)), `${file} runs no expression`);
  }
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
  assert.deepEqual([...new Set(vendorCalls)].sort(), ['%DeleteFolderItem', '%Export', '%FolderItemExists', '%GetFavoriteList', '%GetFolderItemClasses', '%GetFolderItemList', '%Import', '%OpenFolderItem'], 'and only those Utils calls');
  const imports = [...code.matchAll(/\.%Import\(([^)]*)\)/g)].map((match) => match[1]);
  assert.deepEqual(imports, ['tBytes, 0, 0, 0, "", .tLoaded'], 'the one vendor import replaces nothing and kills nothing');
});

test('Story 24.14: a saved pivot is composed only by the one seam, and the viewer and its run name none of the calls its Never list forbids', () => {
  // Mutation (Rule 19): call %GetBaseMDX from ReadFolderItem or any method of AnalyticsPort.cls but VendorPivotMdx, or %RegisterRecentItem, %CreateResultSet or
  // %ExecuteMDX from the port, PivotRun.cls or AnalyticsMdxRead.cls -> this goes red naming the call.
  const code = codeOf(readFileSync(PORT, 'utf8'), false);
  assert.equal([...code.matchAll(/%GetBaseMDX\(/g)].length, 1, '%GetBaseMDX is called once in the port');
  const seam = /ClassMethod VendorPivotMdx\([\s\S]*?\n\}\n/.exec(code);
  assert.notEqual(seam, null, 'the port declares VendorPivotMdx');
  assert.ok(seam[0].includes('%GetBaseMDX('), 'and the one call sits in that seam');
  for (const file of [PORT, join(REPO_ROOT, 'src', 'OcuPilot', 'Area', 'Analytics', 'PivotRun.cls'), join(REPO_ROOT, 'src', 'OcuPilot', 'Screen', 'Tool', 'AnalyticsMdxRead.cls')]) {
    const source = codeOf(readFileSync(file, 'utf8'), false);
    for (const never of [/%RegisterRecentItem/, /%CreateResultSet/, /%DrawKPITable/, /%OnLoadKPI/, /%ExecuteMDX/, /%ExecuteSQL/, /%GetKPIValueArray/, /%DeepSee\.UserPortal\.DashboardViewer/, /\blastAccessed\b/, /\btimeModified\s*=/]) {
      assert.ok(!never.test(source), `${file} never names ${never}`);
    }
  }
  assert.ok(!/%GetBaseMDX/.test(codeOf(readFileSync(join(REPO_ROOT, 'src', 'OcuPilot', 'Screen', 'Tool', 'AnalyticsMdxRead.cls'), 'utf8'), false)), 'the agent\'s tool composes through the port');
  const strings = readFileSync(STRINGS_SOURCE, 'utf8');
  const experience = readFileSync(EXPERIENCE, 'utf8');
  for (const key of ['agentDefinitionFormLabel', 'analyticsTabWidgets', 'analyticsColumnDataSource', 'analyticsFolderItemDefinitionEmpty', 'analyticsDashboardWidgetsEmpty']) {
    assert.ok(strings.includes(`${key}:`), `strings.ts holds ${key}`);
    assert.ok(experience.includes(`"${stringValue(key)}"`), `${key} is published in EXPERIENCE.md's Fixed strings`);
  }
});

const PMML_SENTENCES = [
  ['REASONPMMLINPUT', 'analyticsRefusalPmmlInput'],
  ['REASONPMMLABSENT', 'analyticsPmmlModelGone'],
  ['REASONPMMLQUERYONLY', 'analyticsRefusalPmmlQueryOnly'],
  ['REASONPMMLCUBE', 'analyticsRefusalPmmlCube'],
  ['REASONPMMLBUSY', 'analyticsRefusalPmmlBusy'],
  ['REASONPMMLFULL', 'analyticsRefusalPmmlFull'],
  ['REASONPMMLNOTFOUND', 'analyticsRefusalPmmlNotFound'],
  ['REASONPMMLLOST', 'analyticsRefusalPmmlLost'],
];

test('Story 24.14 Batch 2: each PMML refusal is one sentence on both surfaces, and the tester names none of the vendor calls its Never list forbids', () => {
  // Mutation (Rule 19): change one word of REASONPMMLBUSY in AnalyticsError.cls (or of analyticsRefusalPmmlBusy in strings.ts) -> the first half goes red naming the pair; call %DropAllResults,
  // CreateFromFile, %ExecuteModel or %GetModelInstance from AnalyticsPort.cls or PmmlTest.cls, or the vendor's run outside PmmlVendor -> the second half goes red naming the call.
  const errors = readFileSync(join(REPO_ROOT, 'src', 'OcuPilot', 'Api', 'AnalyticsError.cls'), 'utf8');
  const values = Object.fromEntries(Object.entries(loadStringsValues()).map(([key, value]) => [key, value.replace(/\\'/g, "'")]));
  const experience = readFileSync(EXPERIENCE, 'utf8');
  for (const [parameter, key] of PMML_SENTENCES) {
    const declared = errors.match(new RegExp(`Parameter ${parameter} = "([^"]*)";`))?.[1];
    assert.ok(declared !== undefined, `${parameter} is declared`);
    assert.equal(declared, values[key], `${parameter} equals strings.ts ${key}`);
    assert.ok(experience.includes(`"${values[key]}"`), `${key} is published in EXPERIENCE.md's Fixed strings`);
  }
  const code = codeOf(readFileSync(PORT, 'utf8'), false);
  const area = codeOf(readFileSync(join(REPO_ROOT, 'src', 'OcuPilot', 'Area', 'Analytics', 'PmmlTest.cls'), 'utf8'), false);
  for (const source of [code, area]) {
    for (const never of [/CreateFromFile/, /CreateFromStream/, /CreateFromString/, /%OnSubmit/, /ExportToCubeDefinition/, /%DropAllResults/, /%DropResults/, /%GetModelInstance/, /%ExecuteModel/]) {
      assert.ok(!never.test(source), `neither the port nor PmmlTest names ${never}`);
    }
  }
  const seam = /ClassMethod PmmlVendor\([\s\S]*?\n\}\n/.exec(code);
  assert.notEqual(seam, null, 'the port declares PmmlVendor');
  for (const call of ['%RunModel(', '%RunModelFromPMMLRows(', '%RunModelFromSQL(']) {
    assert.equal(code.split(call).length - 1, 1, `${call} is called once in the port`);
    assert.ok(seam[0].includes(call), `and the one call sits in PmmlVendor`);
  }
  assert.ok(!/%RunModel/.test(area), 'PmmlTest runs nothing itself');
  const drops = [...code.matchAll(/DELETE FROM %DeepSee_PMML_Utils\.TempResult/g)].length;
  assert.equal(drops, 1, 'the one drop of the vendor\'s result rows is an embedded DELETE in PmmlDrop');
});

/** The refusals of the PMML definition create (Story 24.14, Batch 3), each pinned to its `strings.ts` key; the class sentence is the listing groups'. */
const PMML_CREATE_SENTENCES = [
  ['REASONPMMLCLASS', 'analyticsRefusalListingGroupClass'],
  ['REASONPMMLTAKEN', 'analyticsRefusalPmmlTaken'],
  ['REASONPMMLTEXT', 'analyticsRefusalPmmlText'],
  ['REASONPMMLCOMPILE', 'analyticsRefusalPmmlCompile'],
  ['REASONPMMLREADONLY', 'analyticsRefusalPmmlReadonly'],
];

test('Story 24.14 Batch 3: each PMML create refusal and its consequence is one sentence on both surfaces, the text guard refuses a brace, and the create saves only through the source code port', () => {
  // Mutation (Rule 19): change one word of REASONPMMLCOMPILE in AnalyticsError.cls (or of analyticsRefusalPmmlCompile in strings.ts) -> the first half goes red naming the pair; drop the `}` test from
  // PmmlTextRefused in AnalyticsPort.cls -> the guard assertion goes red; call a CreateFrom* utility from AnalyticsPort.cls -> the vendor-call assertion goes red naming it.
  const errors = readFileSync(join(REPO_ROOT, 'src', 'OcuPilot', 'Api', 'AnalyticsError.cls'), 'utf8');
  const values = Object.fromEntries(Object.entries(loadStringsValues()).map(([key, value]) => [key, value.replace(/\\'/g, "'")]));
  const experience = readFileSync(EXPERIENCE, 'utf8');
  for (const [parameter, key] of PMML_CREATE_SENTENCES) {
    const declared = errors.match(new RegExp(`Parameter ${parameter} = "([^"]*)";`))?.[1];
    assert.ok(declared !== undefined, `${parameter} is declared`);
    assert.equal(declared, values[key], `${parameter} equals strings.ts ${key}`);
    assert.ok(experience.includes(`"${values[key]}"`), `${key} is published in EXPERIENCE.md's Fixed strings`);
  }
  assert.equal(
    values.analyticsRefusalPmmlText,
    'Paste one PMML document of at most 3,000,000 characters, with no document type declaration and no } character.',
    'the text sentence is the ruled one'
  );
  const proposalView = readFileSync(join(REPO_ROOT, 'ui', 'src', 'app', 'core', 'proposal-view.ts'), 'utf8');
  assert.ok(proposalView.includes("CONSEQUENCE_ANALYTICSPMMLSAVE = 'ANALYTICS.PMML.SAVE'"), 'proposal-view.ts holds the create\'s consequence code');
  assert.ok(proposalView.includes('if (code === CONSEQUENCE_ANALYTICSPMMLSAVE) return STRINGS.analyticsPmmlSaveConsequence;'), 'and maps it to its sentence');
  assert.ok(experience.includes(`"${values.analyticsPmmlSaveConsequence}"`), 'the consequence is published in EXPERIENCE.md\'s Fixed strings');
  const tool = join(REPO_ROOT, 'src', 'OcuPilot', 'Screen', 'Tool', 'AnalyticsPmmlModelAdd.cls');
  assert.equal(classParameter(tool, 'CONSEQUENCECODE'), 'ANALYTICS.PMML.SAVE', 'the create names its consequence code');
  assert.equal(classParameter(tool, 'DESTINATIONGLOBAL'), '^oddDEF', 'and the database that holds class definitions');
  assert.ok(readFileSync(tool, 'utf8').includes('Extends OcuPilot.Screen.Tool.AnalyticsListingGroupAction'), 'the create extends the class-write tool base');
  const code = codeOf(readFileSync(PORT, 'utf8'), false);
  for (const never of [/CreateFromFile/, /CreateFromStream/, /CreateFromString/, /%OnSubmit/, /%Dictionary\.ClassDefinition\)\.%Save/]) {
    assert.ok(!never.test(code), `the port never names ${never}`);
  }
  const guard = /ClassMethod PmmlTextRefused\([\s\S]*?\n\}\n/.exec(readFileSync(PORT, 'utf8'));
  assert.notEqual(guard, null, 'the port declares PmmlTextRefused');
  for (const needle of ['pText [ "}"', '"<!DOCTYPE"', '"<!ENTITY"', '#MAXIMPORTCHARACTERS']) {
    assert.ok(guard[0].includes(needle), `the text guard holds ${needle}`);
  }
});

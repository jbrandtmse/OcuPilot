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

/** The product classes that run an MDX statement: the port, the MDX kind, and the run and the row reader they share. */
const MDX_CODE = [
  PORT,
  join(REPO_ROOT, 'src', 'OcuPilot', 'Area', 'Analytics', 'MdxQuery.cls'),
  join(REPO_ROOT, 'src', 'OcuPilot', 'Kernel', 'Shell', 'BackgroundRun.cls'),
  join(REPO_ROOT, 'src', 'OcuPilot', 'Kernel', 'RowFetch.cls'),
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
  assert.equal(parameter('ENDPOINTS'), 'Cubes,Measures,Dimensions,Relationships,TermLists,TermListEntries,FolderItems');
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

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import {
  CLASSIFICATION_SOURCE,
  FIELD_LISTS_SOURCE,
  TOOL_FIELDS_PATH,
  checkLists,
  classifiableRows,
  classify,
  generate,
  generateFrom,
  isCredential,
  lastSegment,
  readSources,
} from './field-lists.mjs';
import { extractXData } from './screen-mirror.mjs';

// Pins Story 2.2's build-side acceptance criteria (AC3, AC4) over ui/tools/field-lists.mjs: every
// row of the spec's I/O matrix except "Instance moved" (OcuPilot.Test.DerivedFields pins that on an
// instance), with planted entries passed to the exported functions over the committed field
// lists; the committed ToolFields.cls equals the generator's output; and the committed lists carry
// the three template credentials as string literals. Needs nothing but the checkout.

const here = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(here, '..', '..');
const { lists, entries: committedEntries } = readSources();

/** The emitted field at `path` for `tool`, or undefined. */
function fieldOf(result, tool, path) {
  return result.tools[tool]?.fields.find((field) => field.path === path);
}

/** Every problem naming `tool`, joined, for a readable assertion message. */
function problemsFor(result, tool) {
  return result.problems.filter((problem) => problem.startsWith(`${tool}:`));
}

// --- The matrix ----------------------------------------------------------------------------

// Mutation (Rule 19): set DEFAULT_CLASS to 'ordinary' in field-lists.mjs -> this goes red.
test('an unclassified path is emitted secret, with no error', () => {
  const entries = {
    'webapp.applications.edit': { fieldList: 'WebApp.App', classification: { Enabled: 'ordinary' } },
    'permissions.users.edit': { fieldList: 'Security.User', classification: { Roles: 'opaque' } },
  };
  const result = classify(lists, entries);
  assert.deepEqual(result.problems, [], 'an entry that omits a path is not a refusal');
  assert.equal(fieldOf(result, 'webapp.applications.edit', 'Timeout')?.class, 'secret', 'the omitted Timeout is secret');
  assert.equal(fieldOf(result, 'webapp.applications.edit', 'Enabled')?.class, 'ordinary', 'and the named Enabled keeps its class');
  assert.equal(fieldOf(result, 'permissions.users.edit', 'Roles')?.class, 'opaque', 'and a member-less array may be opaque');
  const text = generateFrom({ lists, entries }).text;
  assert.notEqual(text, null, 'and the generator emits');
  assert.match(text, /\{"path":"Timeout","shape":"literal","templateType":"string","itemType":"","class":"secret"\}/, 'ToolFields carries Timeout as secret');
  const emitted = JSON.parse(extractXData(text, 'Tools'));
  assert.deepEqual(Object.keys(emitted), ['permissions.users.edit', 'webapp.applications.edit'], 'the emitted block parses, one tool per entry');
  assert.equal(emitted['webapp.applications.edit'].fields.find((field) => field.path === 'Timeout')?.class, 'secret', 'and reads back Timeout as secret');
});

// Mutation (Rule 19): delete the isCredential refusal in classify() -> this, the class-derived
// credential case and the --check credential process case go red.
test('a template credential classified ordinary is refused naming the tool and the path', () => {
  const entries = {
    'security.encryption.edit': {
      fieldList: 'Security.Encryption.Settings',
      classification: { AdminPassword: 'ordinary' },
    },
  };
  const generated = generateFrom({ lists, entries });
  assert.equal(generated.text, null, 'the generator emits nothing');
  const named = generated.problems.filter((problem) => /^security\.encryption\.edit: path AdminPassword .*credential/.test(problem));
  assert.equal(named.length, 1, `one refusal names the tool and the path: ${generated.problems.join('; ')}`);
});

test('a boolean whose name looks like a credential is emitted as classified', () => {
  const entries = { 'permissions.users.edit': { fieldList: 'Security.User', classification: { ChangePassword: 'ordinary' } } };
  const result = classify(lists, entries);
  assert.deepEqual(result.problems, [], 'ChangePassword is a boolean, not a credential');
  assert.equal(fieldOf(result, 'permissions.users.edit', 'ChangePassword')?.class, 'ordinary');
});

test('a class-derived credential classified ordinary is refused', () => {
  const entries = {
    'security.walletsecrets.edit': { fieldList: 'Wallet.Secret:%Wallet.RSA', classification: { Password: 'ordinary' } },
  };
  const generated = generateFrom({ lists, entries });
  assert.equal(generated.text, null, 'the generator emits nothing');
  assert.match(generated.problems.join('\n'), /^security\.walletsecrets\.edit: path Password .*must be secret$/m);
});

// Mutation (Rule 19): drop the "is not in list" refusal in classify() -> this goes red.
test('a hand-typed path or field list is refused naming it', () => {
  const path = generateFrom({
    lists,
    entries: { 'webapp.applications.edit': { fieldList: 'WebApp.App', classification: { NotAVendorField: 'ordinary' } } },
  });
  assert.equal(path.text, null, 'a hand-typed path emits nothing');
  assert.match(path.problems.join('\n'), /webapp\.applications\.edit: path NotAVendorField is not in list WebApp\.App/);

  const list = generateFrom({
    lists,
    entries: { 'webapp.applications.edit': { fieldList: 'WebApp.Handwritten', classification: {} } },
  });
  assert.equal(list.text, null, 'a hand-typed field list emits nothing');
  assert.match(list.problems.join('\n'), /webapp\.applications\.edit: fieldList "WebApp\.Handwritten" is not a list/);
});

test('every vocabulary violation is refused and emits nothing', () => {
  const cases = [
    ['a class outside the three', 'webapp.applications.edit', { fieldList: 'WebApp.App', classification: { Timeout: 'public' } }, /Timeout is classified "public"/],
    ['opaque on a literal', 'webapp.applications.edit', { fieldList: 'WebApp.App', classification: { Timeout: 'opaque' } }, /Timeout is a literal and cannot be opaque/],
    ['ordinary on a member-less array', 'permissions.users.edit', { fieldList: 'Security.User', classification: { Roles: 'ordinary' } }, /Roles is a member-less array and cannot be ordinary/],
    ['ordinary on a member-less object', 'system.languageservers.edit', { fieldList: 'LanguageServer', classification: { Custom: 'ordinary' } }, /Custom is a member-less object and cannot be ordinary/],
    ['a path with rows below it', 'webapp.applications.edit', { fieldList: 'WebApp.App', classification: { MatchRoles: 'secret' } }, /MatchRoles is not classifiable/],
    ['a key outside the grammar', 'webapp.applications.edit', { fieldList: 'WebApp.App', classification: {}, schema: {} }, /key "schema" is outside the entry grammar/],
    ['a tool name with capitals', 'WebApp.Applications.Edit', { fieldList: 'WebApp.App', classification: {} }, /tool name is not <area>\.<screen>\.<verb>/],
    ['a tool name with two parts', 'webapp.edit', { fieldList: 'WebApp.App', classification: {} }, /tool name is not/],
  ];
  for (const [why, tool, entry, message] of cases) {
    const generated = generateFrom({ lists, entries: { [tool]: entry } });
    assert.equal(generated.text, null, `${why}: nothing is emitted`);
    assert.match(problemsFor(generated, tool).join('\n'), message, `${why}: the refusal names it`);
  }
  // Mutation (Rule 19): drop the reserved-content refusal in classify() -> the content assertion goes red.
  for (const [reserved, content] of [['required', ['NotAVendorField']], ['enum', { Timeout: [1] }], ['description', 'hand-typed']]) {
    const empty = { fieldList: 'WebApp.App', classification: {}, [reserved]: Array.isArray(content) ? [] : typeof content === 'string' ? '' : {} };
    assert.deepEqual(classify(lists, { 'webapp.applications.edit': empty }).problems, [], `${reserved} is a reserved key, not a refusal`);
    const filled = generateFrom({ lists, entries: { 'webapp.applications.edit': { ...empty, [reserved]: content } } });
    assert.equal(filled.text, null, `${reserved} with content emits nothing`);
    assert.match(filled.problems.join('\n'), new RegExp(`key "${reserved}" is reserved and carries no content yet`), `${reserved} with content is refused`);
  }
});

/** A copy of the generator and its three inputs in a temporary repository, run as a process. */
function runInTree({ entries, toolFields }, check) {
  const root = mkdtempSync(join(tmpdir(), 'ocupilot-field-lists-'));
  try {
    const tools = join(root, 'ui', 'tools');
    const toolDir = join(root, 'src', 'OcuPilot', 'Screen', 'Tool');
    mkdirSync(tools, { recursive: true });
    mkdirSync(toolDir, { recursive: true });
    for (const name of ['field-lists.mjs', 'screen-mirror.mjs', 'credential-pattern.mjs']) copyFileSync(join(here, name), join(tools, name));
    copyFileSync(FIELD_LISTS_SOURCE, join(toolDir, 'FieldLists.cls'));
    const classification = readFileSync(CLASSIFICATION_SOURCE, 'utf8').replace(
      /XData Entries\n\{\n[\s\S]*?\n\}\n\n\}/,
      `XData Entries\n{\n${JSON.stringify(entries, null, 2)}\n}\n\n}`
    );
    writeFileSync(join(toolDir, 'Classification.cls'), classification);
    writeFileSync(join(toolDir, 'ToolFields.cls'), toolFields ?? readFileSync(TOOL_FIELDS_PATH, 'utf8'));
    // realpathSync: the run-me guard compares import.meta.url, which Node reports resolved.
    const script = realpathSync(join(tools, 'field-lists.mjs'));
    const run = spawnSync(process.execPath, [script, '--check'], { cwd: tools, encoding: 'utf8' });
    return check(run, readFileSync(join(toolDir, 'ToolFields.cls'), 'utf8'));
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

test('run as a process, --check exits 1 on a credential refusal, naming the tool and path', () => {
  const entries = { 'security.encryption.edit': { fieldList: 'Security.Encryption.Settings', classification: { AdminPassword: 'ordinary' } } };
  runInTree({ entries }, (run) => {
    assert.equal(run.status, 1, `${run.stdout}${run.stderr}`);
    assert.match(run.stderr, /field-lists: security\.encryption\.edit: path AdminPassword /);
    assert.match(run.stderr, /nothing emitted/);
  });
});

test('run as a process, --check exits 1 when the committed ToolFields.cls has drifted', () => {
  // The committed entries, not an empty set: the drift the check exists to catch is between the
  // two committed inputs and the committed output, so the tree this runs over has to be the
  // committed one with only the output replaced.
  runInTree(
    {
      entries: committedEntries,
      toolFields: 'Class OcuPilot.Screen.Tool.ToolFields Extends %RegisteredObject\n{\n}\n',
    },
    (run) => {
      assert.equal(run.status, 1, `${run.stdout}${run.stderr}`);
      assert.match(run.stderr, /ToolFields\.cls is stale/);
    }
  );
  runInTree({ entries: committedEntries }, (run) => {
    assert.equal(run.status, 0, `an undrifted tree passes: ${run.stdout}${run.stderr}`);
    assert.match(run.stdout, /^field-lists: up to date; classified \d+ list\(s\), \d+ row\(s\), \d+ classification entry\(ies\)\.$/m);
  });
});

// --- The committed files -------------------------------------------------------------------

test('the committed ToolFields.cls equals what the committed inputs generate', () => {
  const generated = generate();
  assert.deepEqual(generated.problems, [], 'the committed entries and lists are accepted');
  assert.equal(readFileSync(TOOL_FIELDS_PATH, 'utf8'), generated.text, 'run node tools/field-lists.mjs');
});

test('the committed lists are well formed and carry the three template credentials as string literals', () => {
  assert.deepEqual(checkLists(lists), [], 'FieldLists.cls is well formed');
  for (const [list, path] of [
    ['Security.Encryption.Settings', 'AdminPassword'],
    ['Security.X509Credential', 'PrivateKeyPassword'],
    ['Security.SSLConfig', 'PrivateKeyPassword'],
  ]) {
    const row = lists[list]?.rows.find((candidate) => candidate.path === path);
    assert.equal(row?.shape, 'literal', `${list} ${path} is a literal`);
    assert.equal(row?.templateType, 'string', `${list} ${path} is a string`);
    assert.ok(isCredential(row), `${list} ${path} is a credential by name`);
  }
});

test('a malformed list is refused', () => {
  const orphan = {
    'WebApp.App': { endpoint: 'WebApp.App', source: 'template', method: 'RequestBodySchema', class: '', type: '', envelope: '', rows: [
      { path: 'MatchRoles[].MatchRole', shape: 'literal', templateType: 'string', itemType: '' },
    ] },
  };
  assert.match(checkLists(orphan).join('\n'), /MatchRoles\[\]\.MatchRole has no object row MatchRoles\[\] above it/);
  const shapeless = { 'WebApp.App': { endpoint: 'WebApp.App', source: 'template', method: 'RequestBodySchema', class: '', type: '', envelope: '', rows: [{ path: 'X', templateType: 'string', itemType: '' }] } };
  assert.deepEqual(checkLists(shapeless), ['FieldLists.cls: list WebApp.App has a row that is not exactly path, shape, templateType, itemType strings'], 'a row without a shape is refused, and nothing else is');
  assert.notDeepEqual(checkLists({}), [], 'an empty block is refused, not read as nothing to classify');
});

test('a path is classifiable only when no row extends it, and a credential is a string literal by last segment', () => {
  const rows = lists['Security.Role'].rows;
  assert.deepEqual(
    classifiableRows(rows).map((row) => row.path),
    ['Description', 'GrantedRoles[]', 'EscalationOnly', 'Resources[].Name', 'Resources[].Permissions']
  );
  assert.equal(lastSegment('Resources[].Name'), 'Name');
  assert.equal(lastSegment('CipherList[]'), 'CipherList');
  assert.equal(isCredential({ path: 'ChangePassword', shape: 'literal', templateType: 'boolean', itemType: '' }), false);
  assert.equal(isCredential({ path: 'RefreshToken', shape: 'literal', templateType: 'number', itemType: '' }), false);
  assert.equal(isCredential({ path: 'Settings.ApiKey', shape: 'literal', templateType: 'string', itemType: '' }), true);
});

// Mutation (Rule 19): drop `secret64` or `^key$` from CREDENTIAL_RE -> this goes red.
test('every ending of the credential pattern matches a string literal, and a name merely holding "key" does not', () => {
  const literal = (path) => ({ path, shape: 'literal', templateType: 'string', itemType: '' });
  for (const path of ['AdminPassword', 'UserPasswd', 'DbPwd', 'ClientSecret', 'Secret64', 'Settings.ApiKey', 'PrivateKey', 'ReturnRefreshToken', 'Key', 'key']) {
    assert.equal(isCredential(literal(path)), true, `${path} is a credential by name`);
  }
  for (const path of ['PrimaryKeyField', 'KeyType', 'KeyDirectory', 'PrivateKeyType', 'Keys', 'Secret64Hint']) {
    assert.equal(isCredential(literal(path)), false, `${path} is not`);
  }
  for (const [tool, fieldList, path] of [
    ['security.walletsecrets.edit', 'Wallet.Secret:%Wallet.KeyValue', 'Secret64'],
    ['licensing.keys.edit', 'License.Key', 'Key'],
    ['security.walletsecrets.edit', 'Wallet.Secret:%Wallet.RSA', 'PrivateKey'],
  ]) {
    const generated = generateFrom({ lists, entries: { [tool]: { fieldList, classification: { [path]: 'ordinary' } } } });
    assert.equal(generated.text, null, `${fieldList} ${path} classified ordinary emits nothing`);
    assert.match(generated.problems.join('\n'), new RegExp(`^${tool.replace(/\./g, '\\.')}: path ${path} .*must be secret$`, 'm'));
  }
});

// --- The gates -----------------------------------------------------------------------------

// Mutation (Rule 19): remove the field-lists dispatch from .githooks/pre-commit -> this goes red.
test('the check is named in prebuild, in prestart and in the pre-commit hook, and can block', () => {
  const scripts = JSON.parse(readFileSync(join(here, '..', 'package.json'), 'utf8')).scripts;
  for (const [name, chain] of [
    ['prebuild', scripts.prebuild],
    ['prestart', scripts.prestart],
  ]) {
    const segments = chain.split('&&').map((segment) => segment.trim());
    assert.ok(segments.includes('node tools/field-lists.mjs --check'), `${name} runs the check as a link of its own`);
    assert.doesNotMatch(chain, /field-lists\.mjs --check[^&]*\|\|/, `${name} does not swallow its exit code`);
  }
  const hook = readFileSync(join(REPO_ROOT, '.githooks', 'pre-commit'), 'utf8');
  const trigger = hook.slice(hook.indexOf('if [ -n "$OS_TRIGGER" ]'));
  const block = trigger.slice(0, trigger.indexOf('\nfi\n'));
  assert.match(block, /node tools\/field-lists\.mjs --check\)?\s*\|\|\s*STATUS=1/, 'the hook dispatches it inside OS_TRIGGER and feeds STATUS');
  assert.match(hook, /Field lists:/, 'and explains its failure');
});

// Story 8.2, AD-3: an entry may author a wrapper field the endpoint's template does not carry, as
// `secret` and nothing else, and it is emitted as its own secret literal row marked `authored`.
//
// Mutation (Rule 19): drop the `fields.push(...)` of an authored row in classify() -> the emitted
// row assertions go red; accept any class for an authored name -> the 'ordinary' refusal goes red.
test('an authored wrapper field is emitted secret and marked, and every other shape is refused', () => {
  const entry = (authored) => ({
    'permissions.users.create': { fieldList: 'Security.User', classification: { Roles: 'opaque', EscalationRoles: 'opaque' }, authored },
  });
  const accepted = classify(lists, entry({ Password: 'secret' }));
  assert.deepEqual(accepted.problems, [], 'an authored secret is accepted');
  assert.deepEqual(
    fieldOf(accepted, 'permissions.users.create', 'Password'),
    { path: 'Password', shape: 'literal', templateType: 'string', class: 'secret', authored: true },
    'and emitted as a secret literal row marked authored'
  );
  const text = generateFrom({ lists, entries: entry({ Password: 'secret' }) }).text;
  assert.match(text, /\{"path":"Password","shape":"literal","templateType":"string","class":"secret","authored":true\}/, 'ToolFields carries it');

  const refusals = [
    [{ Password: 'ordinary' }, /authored name Password is classified "ordinary"/],
    [{ Password: 'opaque' }, /authored name Password is classified "opaque"/],
    [{ FullName: 'secret' }, /authored name FullName collides with a derived path/],
    [{ Roles: 'secret' }, /authored name Roles collides with a derived path/],
    [{ 'User.Password': 'secret' }, /authored name "User.Password" is not one top-level field name/],
    [{ 'Pass[]': 'secret' }, /authored name "Pass\[\]" is not one top-level field name/],
  ];
  for (const [authored, pattern] of refusals) {
    const refused = generateFrom({ lists, entries: entry(authored) });
    assert.equal(refused.text, null, `${JSON.stringify(authored)} emits nothing`);
    assert.ok(refused.problems.some((problem) => pattern.test(problem)), `${JSON.stringify(authored)} is refused: ${refused.problems.join('; ')}`);
  }
  const notAnObject = generateFrom({ lists, entries: entry(['Password']) });
  assert.ok(notAnObject.problems.some((problem) => /authored is not a JSON object/.test(problem)), 'an authored list that is not an object is refused');

  // The committed entry is the one the Users list's create tool carries.
  assert.deepEqual(committedEntries['permissions.users.create']?.authored, { Password: 'secret' }, 'the committed create entry authors Password');
});

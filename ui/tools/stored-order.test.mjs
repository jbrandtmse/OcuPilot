import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  compareStoredOrder,
  hasCommit,
  isShallow,
  newestReleaseRef,
  parseClass,
  sourcesAtRef,
  sourcesInTree,
  storedModel,
  STORED_ORDER_ALLOW,
} from './stored-order.mjs';

/**
 * Pins `stored-order.mjs`: a stored class's own properties keep their declaration order against
 * the newest release branch.
 *
 * Fixture legs run everywhere. The git legs read `origin/release/*`, which a full clone holds;
 * CI's `gates` job fetches each release branch at its tip, so the working tree against the newest
 * release runs there too, while the leg that needs the history between two commits skips in a
 * shallow clone.
 *
 * Mutations (Rule 19): compare the member lists as sets instead of as a prefix -> the insert leg,
 * the allow-list leg (a reorder) and the SqlRun leg go red; drop the Calculated filter from
 * `parseClass` -> the Calculated legs go red; drop the Transient filter -> the Transient leg goes
 * red; treat a many-side relationship as stored -> the relationship leg goes red.
 */

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

/** A class source with the given extends clause and body lines. */
function cls(name, extendsClause, body = [], header = '') {
  const extendsText = extendsClause === '' ? '' : ` Extends ${extendsClause}`;
  return [`Class ${name}${extendsText}${header}`, '{', '', ...body.flatMap((line) => [line, '']), '}', ''].join('\n');
}

/** One property line. */
const prop = (name, keywords = '') => `Property ${name} As %String${keywords === '' ? '' : ` [ ${keywords} ]`};`;

/** A baseline model and a current model from two lists of sources. */
const model = (...sources) => storedModel(sources);

const BASE = cls('App.Base', '%Persistent', [prop('RowVersion')], ' [ Abstract ]');

test('an appended property passes', () => {
  const baseline = model(BASE, cls('App.A', 'App.Base', [prop('One'), prop('Two')]));
  const current = model(BASE, cls('App.A', 'App.Base', [prop('One'), prop('Two'), prop('Three')]));
  assert.deepEqual(compareStoredOrder(baseline, current), []);
});

test('an insert fails, naming the class and the slot', () => {
  const baseline = model(BASE, cls('App.A', 'App.Base', [prop('One'), prop('Two'), prop('Three')]));
  const current = model(BASE, cls('App.A', 'App.Base', [prop('One'), prop('Two'), prop('Kind'), prop('Three')]));
  const problems = compareStoredOrder(baseline, current);
  assert.equal(problems.length, 1);
  assert.equal(problems[0].class, 'App.A');
  assert.equal(problems[0].slot, 3);
  assert.match(problems[0].message, /App\.A: slot 3 held Three at the baseline and now holds Kind/);
});

test('a rename fails, naming the class and the slot', () => {
  const baseline = model(cls('App.A', '%Persistent', [prop('One'), prop('Two')]));
  const current = model(cls('App.A', '%Persistent', [prop('One'), prop('Second')]));
  const problems = compareStoredOrder(baseline, current);
  assert.deepEqual(problems.map((p) => [p.class, p.slot]), [['App.A', 2]]);
  assert.match(problems[0].message, /Two at the baseline and now holds Second/);
});

test('a removal fails, naming the class and the slot', () => {
  const baseline = model(cls('App.A', '%Persistent', [prop('One'), prop('Two'), prop('Three')]));
  const current = model(cls('App.A', '%Persistent', [prop('One'), prop('Three')]));
  const problems = compareStoredOrder(baseline, current);
  assert.deepEqual(problems.map((p) => [p.class, p.slot]), [['App.A', 2]]);
});

test('a removal at the end fails and names the missing slot', () => {
  const baseline = model(cls('App.A', '%Persistent', [prop('One'), prop('Two')]));
  const current = model(cls('App.A', '%Persistent', [prop('One')]));
  const problems = compareStoredOrder(baseline, current);
  assert.deepEqual(problems.map((p) => [p.class, p.slot]), [['App.A', 2]]);
  assert.match(problems[0].message, /now holds \(nothing\)/);
});

test('a removed class fails', () => {
  const baseline = model(cls('App.A', '%Persistent', [prop('One')]));
  const problems = compareStoredOrder(baseline, model());
  assert.deepEqual(problems.map((p) => [p.class, p.kind]), [['App.A', 'removed']]);
});

test('a changed primary superclass fails', () => {
  const baseline = model(BASE, cls('App.A', 'App.Base', [prop('One')]));
  const current = model(BASE, cls('App.A', '%Persistent', [prop('One')]));
  const problems = compareStoredOrder(baseline, current);
  assert.deepEqual(problems.map((p) => [p.class, p.kind]), [['App.A', 'superclass']]);
  assert.match(problems[0].message, /from App\.Base to %Persistent/);
});

test('a class absent at the baseline passes', () => {
  const baseline = model(cls('App.A', '%Persistent', [prop('One')]));
  const current = model(cls('App.A', '%Persistent', [prop('One')]), cls('App.New', '%Persistent', [prop('X'), prop('Y')]));
  assert.deepEqual(compareStoredOrder(baseline, current), []);
});

test('Calculated and Transient members are ignored, in either list', () => {
  const baseline = model(cls('App.A', '%Persistent', [prop('One'), prop('Two')]));
  const current = model(
    cls('App.A', '%Persistent', [prop('Shown', 'Calculated, SqlComputeCode = {Set {*} = 1}, SqlComputed'), prop('One'), prop('Scratch', 'Transient'), prop('Two')])
  );
  assert.deepEqual(compareStoredOrder(baseline, current), []);
  // A baseline that held one is as if it did not: removing it is not a removal.
  const heldOne = model(cls('App.A', '%Persistent', [prop('One'), prop('Shown', 'Calculated'), prop('Two')]));
  assert.deepEqual(compareStoredOrder(heldOne, model(cls('App.A', '%Persistent', [prop('One'), prop('Two')]))), []);
});

test('a Calculated member is not counted', () => {
  assert.deepEqual(parseClass(cls('App.A', '%Persistent', [prop('One'), prop('Two', 'Calculated')])).members, ['One']);
});

test('a Transient member is not counted', () => {
  assert.deepEqual(parseClass(cls('App.A', '%Persistent', [prop('One'), prop('Two', 'Transient')])).members, ['One']);
});

test('a MultiDimensional member is not counted, and a keyword switched off still is', () => {
  const parsed = parseClass(
    cls('App.A', '%Persistent', [prop('One'), 'Property Grid [ MultiDimensional ];', prop('Kept', 'Transient = 0')])
  );
  assert.deepEqual(parsed.members, ['One', 'Kept']);
});

test('relationships: one and parent sides are stored, many and children sides are not', () => {
  const parsed = parseClass(
    cls('App.A', '%Persistent', [
      'Relationship Owner As App.B [ Cardinality = one, Inverse = Items ];',
      'Relationship Items As App.C [ Cardinality = many, Inverse = Owner ];',
      'Relationship Parent As App.D [ Cardinality = parent, Inverse = Kids ];',
      'Relationship Kids As App.E [ Cardinality = children, Inverse = Parent ];',
    ])
  );
  assert.deepEqual(parsed.members, ['Owner', 'Parent']);
});

test('a declaration split across lines, or quoting a semicolon, is read whole', () => {
  const text = [
    'Class App.A Extends %Persistent',
    '{',
    '',
    '/// Property Quoted As %String;',
    'Property Spread As %String(MAXLEN = 8)',
    '    [ InitialExpression = "a;b",',
    '      Calculated ];',
    '',
    'Property Real As %String;',
    '',
    'Method Body()',
    '{',
    '    Property Indented As %String',
    '}',
    '',
    '}',
  ].join('\n');
  assert.deepEqual(parseClass(text).members, ['Real']);
});

test('scope: a class with a Storage section, or without a persistent ancestor, is not checked', () => {
  const stored = [
    'Class App.S Extends %Persistent',
    '{',
    'Property A As %String;',
    'Storage Default',
    '{',
    '}',
    '}',
  ].join('\n');
  assert.deepEqual(model(stored, cls('App.Plain', '%RegisteredObject', [prop('A')]), cls('App.Base', '%Persistent', [prop('R')])), {
    'App.Base': { primary: '%Persistent', members: ['R'] },
  });
});

test('scope: persistence follows the in-tree Extends chain, and Ens.Request and Ens.Response count', () => {
  const classes = model(
    cls('App.Base', '%Persistent'),
    cls('App.Mid', 'App.Base'),
    cls('App.Leaf', '(App.Mid, %Populate)', [prop('A')]),
    cls('App.Req', 'Ens.Request', [prop('B')]),
    cls('App.Res', 'Ens.Response', [prop('C')]),
    cls('App.Out', 'Elsewhere.Thing', [prop('D')])
  );
  assert.deepEqual(Object.keys(classes).sort(), ['App.Base', 'App.Leaf', 'App.Mid', 'App.Req', 'App.Res']);
  assert.equal(classes['App.Leaf'].primary, 'App.Mid');
});

test('an allow-list entry exempts its class, and the list ships empty', () => {
  const baseline = model(cls('App.A', '%Persistent', [prop('One'), prop('Two')]));
  const current = model(cls('App.A', '%Persistent', [prop('Two'), prop('One')]));
  assert.equal(compareStoredOrder(baseline, current).length, 1);
  assert.deepEqual(compareStoredOrder(baseline, current, { 'App.A': 'a reason' }), []);
  assert.deepEqual(Object.keys(STORED_ORDER_ALLOW), [], 'the tool ships no exception');
});

// --- Git legs: local, and in CI wherever the release branches are fetched --------------------

/** Skip reason when the clone cannot run a git leg, and a failure when a full clone lacks one. */
function gitLegReady(t, refs, cwd = ROOT) {
  const shallow = isShallow(cwd);
  const missing = refs.filter((ref) => ref === null || !hasCommit(cwd, ref));
  if (missing.length === 0) return true;
  if (shallow) {
    t.skip(`shallow clone: needs ${refs.join(', ')} in the clone`);
    return false;
  }
  assert.fail(
    `a full clone must hold ${refs.join(', ')}; missing ${missing.join(', ')} ` +
      `(git fetch origin '+refs/heads/release/*:refs/remotes/origin/release/*')`
  );
  return false;
}

test('HEAD against the newest release branch reports nothing', (t) => {
  const baselineRef = newestReleaseRef(ROOT);
  if (!gitLegReady(t, [baselineRef])) return;
  const baseline = storedModel(sourcesAtRef(ROOT, baselineRef));
  const current = storedModel(sourcesInTree(ROOT));
  assert.ok(Object.keys(baseline).length >= 21, `${baselineRef} holds its stored classes`);
  assert.ok(Object.keys(current).length >= 21, 'the working tree holds its stored classes');
  const problems = compareStoredOrder(baseline, current);
  assert.deepEqual(problems.map((problem) => problem.message), [], `against ${baselineRef}`);
});

test('release/1.0.12 against the tree of Story 20.33 reports SqlRun, whose Kind sat at slot 4', (t) => {
  // The defect the manual upgrade check alone caught: Kind declared above four existing
  // properties. Red-first for this checker.
  const NEWER = 'dd2d53f22';
  if (!gitLegReady(t, ['refs/remotes/origin/release/1.0.12', NEWER])) return;
  const problems = compareStoredOrder(
    storedModel(sourcesAtRef(ROOT, 'refs/remotes/origin/release/1.0.12')),
    storedModel(sourcesAtRef(ROOT, NEWER))
  );
  const sqlRun = problems.filter((problem) => problem.class === 'OcuPilot.Kernel.State.SqlRun');
  assert.equal(sqlRun.length, 1, `SqlRun is reported once: ${problems.map((p) => p.message).join(' | ')}`);
  assert.equal(sqlRun[0].slot, 4);
  assert.match(sqlRun[0].message, /now holds Kind/);
});

// --- The git readers, against a repository these tests build ---------------------------------

/**
 * Run git in `cwd` with an identity of its own, so no global configuration is read or needed. Every
 * inherited `GIT_*` variable is dropped, so a run under a git hook (which sets `GIT_DIR` or
 * `GIT_INDEX_FILE`) still writes only the scratch repository.
 */
function gitIn(cwd, ...args) {
  const env = Object.fromEntries(Object.entries(process.env).filter(([key]) => !key.startsWith('GIT_')));
  return execFileSync('git', ['-c', 'user.name=t', '-c', 'user.email=t@example.invalid', '-c', 'commit.gpgsign=false', ...args], {
    cwd,
    encoding: 'utf8',
    env: { ...env, GIT_CONFIG_GLOBAL: '/dev/null', GIT_CONFIG_SYSTEM: '/dev/null' },
  }).trim();
}

/** A scratch repository holding one commit of `files` (path to text), removed after `body`. */
function withRepo(files, body) {
  const dir = mkdtempSync(join(tmpdir(), 'ocupilot-stored-order-'));
  try {
    gitIn(dir, 'init', '--quiet');
    for (const [path, text] of Object.entries(files)) {
      mkdirSync(dirname(join(dir, path)), { recursive: true });
      writeFileSync(join(dir, path), text);
    }
    gitIn(dir, 'add', '.');
    gitIn(dir, 'commit', '--quiet', '-m', 'fixture');
    return body(dir);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test('newestReleaseRef orders by version number, not by text, and ignores refs that are not a plain version', () => {
  // Mutation (Rule 19): sort the refs as text -> 1.0.9 outranks 1.0.14 and 1.9.5 outranks 1.10.0, red.
  withRepo({ 'README.txt': 'x\n' }, (dir) => {
    assert.equal(newestReleaseRef(dir), null, 'no release ref, no baseline');
    const head = gitIn(dir, 'rev-parse', 'HEAD');
    for (const name of ['1.0.9', '1.0.14', '1.0.2', '1.9.5', '1.10.0', '1.10.0-rc1', 'next']) {
      gitIn(dir, 'update-ref', `refs/remotes/origin/release/${name}`, head);
    }
    gitIn(dir, 'update-ref', 'refs/heads/release/9.9.9', head);
    assert.equal(newestReleaseRef(dir), 'refs/remotes/origin/release/1.10.0');
  });
  withRepo({ 'README.txt': 'x\n' }, (dir) => {
    const head = gitIn(dir, 'rev-parse', 'HEAD');
    for (const name of ['1.0.9', '1.0.14', '1.0.2']) gitIn(dir, 'update-ref', `refs/remotes/origin/release/${name}`, head);
    assert.equal(newestReleaseRef(dir), 'refs/remotes/origin/release/1.0.14');
  });
});

test('sourcesAtRef reads the committed class sources under src/OcuPilot, byte for byte', () => {
  // The working tree is edited after the commit, so a reader that looked at the disk is red.
  //
  // Mutation (Rule 19): read the tree instead of the ref, drop the `.cls` filter, or measure a
  // blob in characters instead of bytes -> red.
  const accented = cls('App.Accent', '%Persistent', ['/// caf\u00e9 \u2014 \u65e5\u672c', prop('One')]);
  const files = {
    'src/OcuPilot/App/Accent.cls': accented,
    'src/OcuPilot/App/Deep/B.cls': cls('App.Deep.B', '%Persistent', [prop('Two')]),
    'src/OcuPilot/App/Notes.md': 'not a class\n',
    'elsewhere/C.cls': cls('Else.C', '%Persistent', [prop('Three')]),
  };
  withRepo(files, (dir) => {
    writeFileSync(join(dir, 'src/OcuPilot/App/Accent.cls'), 'edited after the commit\n');
    const texts = sourcesAtRef(dir, 'HEAD');
    assert.equal(texts.length, 2, 'only the two .cls files under src/OcuPilot');
    assert.ok(texts.includes(accented), 'a multi-byte source round-trips unchanged');
    assert.deepEqual(Object.keys(storedModel(texts)).sort(), ['App.Accent', 'App.Deep.B']);
  });
  withRepo({ 'README.txt': 'x\n' }, (dir) => assert.deepEqual(sourcesAtRef(dir, 'HEAD'), [], 'a ref with no sources reads as none'));
});

test('a git leg skips in a shallow clone, fails in a full clone, and runs where the ref exists', () => {
  // Mutation (Rule 19): skip in a full clone too (drop the `assert.fail`) -> the full-clone case
  // is red; fail in a shallow clone too -> the shallow case is red.
  const skips = [];
  const recorder = { skip: (reason) => skips.push(reason) };
  withRepo({ 'README.txt': 'x\n' }, (full) => {
    assert.equal(isShallow(full), false);
    assert.equal(gitLegReady(recorder, ['HEAD'], full), true, 'a ref the clone holds runs the leg');
    assert.equal(skips.length, 0);
    assert.throws(() => gitLegReady(recorder, ['refs/remotes/origin/release/9.9.9'], full), /a full clone must hold/);
    assert.throws(() => gitLegReady(recorder, [null], full), /a full clone must hold/, 'no baseline at all fails in a full clone');
    assert.equal(skips.length, 0, 'a full clone never skips');
    const shallowDir = mkdtempSync(join(tmpdir(), 'ocupilot-stored-order-shallow-'));
    try {
      gitIn(full, 'commit', '--quiet', '--allow-empty', '-m', 'second');
      gitIn(shallowDir, 'clone', '--quiet', '--depth=1', `file://${full}`, 'clone');
      const shallow = join(shallowDir, 'clone');
      assert.equal(isShallow(shallow), true);
      assert.equal(gitLegReady(recorder, [null], shallow), false, 'a shallow clone with no baseline skips');
      assert.equal(gitLegReady(recorder, ['refs/remotes/origin/release/9.9.9'], shallow), false);
      assert.equal(skips.length, 2);
      assert.match(skips[0], /^shallow clone: needs /);
    } finally {
      rmSync(shallowDir, { recursive: true, force: true });
    }
  });
});

import assert from 'node:assert/strict';
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
function gitLegReady(t, ...refs) {
  const shallow = isShallow(ROOT);
  const missing = refs.filter((ref) => ref === null || !hasCommit(ROOT, ref));
  if (missing.length === 0) return true;
  const reason = `needs ${refs.join(', ')} in the clone`;
  if (shallow) {
    t.skip(`shallow clone: ${reason}`);
    return false;
  }
  assert.fail(`a full clone must hold ${reason}; missing ${missing.join(', ')}`);
  return false;
}

test('HEAD against the newest release branch reports nothing', (t) => {
  const baselineRef = newestReleaseRef(ROOT);
  if (!gitLegReady(t, baselineRef)) return;
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
  if (!gitLegReady(t, 'refs/remotes/origin/release/1.0.12', NEWER)) return;
  const problems = compareStoredOrder(
    storedModel(sourcesAtRef(ROOT, 'refs/remotes/origin/release/1.0.12')),
    storedModel(sourcesAtRef(ROOT, NEWER))
  );
  const sqlRun = problems.filter((problem) => problem.class === 'OcuPilot.Kernel.State.SqlRun');
  assert.equal(sqlRun.length, 1, `SqlRun is reported once: ${problems.map((p) => p.message).join(' | ')}`);
  assert.equal(sqlRun[0].slot, 4);
  assert.match(sqlRun[0].message, /now holds Kind/);
});

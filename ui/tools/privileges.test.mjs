import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the client half of Story 16.3 (FR-74, AD-8): the Effective privileges answer and the
// permission check's answer are read only inside their wire shapes, and each renders its sentence
// from EXPERIENCE.md's Fixed strings -- a yes names the granting role and, where it differs, the
// account's own role in " (through <role>)"; a public permission says so; a no says so; the %All
// statement names its role; an unread section says why. The client computes nothing. Needs nothing
// but the checkout.
//
// Mutations (Rule 19):
// - drop the through suffix in checkSentence() -> the through case goes red.
// - answer the yes sentence for a public permission -> the public case goes red.

const corePath = (name) => join(dirname(fileURLToPath(import.meta.url)), '..', 'src', 'app', 'core', name);

const { checkAnswerOf, checkSentence, effectiveAllLine, effectiveOf, throughSuffix, uncheckedLine } = await import(corePath('privileges.ts'));
const { STRINGS } = await import(corePath('strings.ts'));

const section = (rows, unchecked = '') => ({ rows, unchecked });

const effective = {
  user: 'U',
  all: false,
  allVia: '',
  roles: section([{ name: 'A', through: '' }, { name: 'B', through: 'A' }]),
  resources: section([{ name: '%DB_USER', R: 'B' }, { name: 'Pub', R: '' }]),
  applications: section([{ name: '/csp/app', resource: 'Res' }]),
  databases: section([{ directory: '/db/user/', resource: '%DB_USER', permissions: 'R' }]),
  services: section([], '%Admin_Manage:USE'),
};

const answer = (overrides = {}) => ({
  kind: 'user',
  name: 'U',
  resource: '%DB_USER',
  permission: 'READ',
  held: true,
  all: false,
  public: false,
  grantedBy: 'B',
  through: 'A',
  ...overrides,
});

test('the Effective privileges answer is read only inside its shape', () => {
  assert.deepEqual(effectiveOf(effective), effective);
  for (const bad of [
    null,
    [],
    'U',
    { ...effective, all: 'no' },
    { ...effective, user: 7 },
    { ...effective, roles: undefined },
    { ...effective, roles: section('none') },
    { ...effective, roles: { rows: [] } },
    { ...effective, roles: section([{ name: '', through: '' }]) },
    { ...effective, roles: section([{ name: 'A' }]) },
    { ...effective, resources: section([{ name: 'X', R: 1 }]) },
    { ...effective, resources: section([{ R: 'B' }]) },
    { ...effective, applications: section([{ name: '/csp/app' }]) },
    { ...effective, databases: section([{ directory: '/d/', resource: 'R', permissions: 'W' }]) },
    { ...effective, services: section([{ name: 3 }]) },
  ]) {
    assert.equal(effectiveOf(bad), null, JSON.stringify(bad));
  }
});

test('the check answer is read only inside its shape', () => {
  assert.deepEqual(checkAnswerOf(answer()), answer());
  for (const bad of [
    null,
    [],
    answer({ kind: 'group' }),
    answer({ permission: 'ALL' }),
    answer({ held: 'yes' }),
    answer({ all: 1 }),
    answer({ public: null }),
    answer({ grantedBy: undefined }),
    answer({ through: 0 }),
    answer({ name: 7 }),
  ]) {
    assert.equal(checkAnswerOf(bad), null, JSON.stringify(bad));
  }
});

test('a yes names the granting role, and the account role it is reached through where that differs', () => {
  assert.equal(checkSentence(answer()), 'Yes. U holds %DB_USER:READ, granted by B (through A).');
  assert.equal(checkSentence(answer({ through: '' })), 'Yes. U holds %DB_USER:READ, granted by B.');
  assert.equal(checkSentence(answer({ kind: 'role', name: 'A', through: '' })), 'Yes. A holds %DB_USER:READ, granted by B.');
  assert.equal(checkSentence(answer({ all: true, grantedBy: '%All', through: 'R', name: 'V', permission: 'WRITE' })), 'Yes. V holds %DB_USER:WRITE, granted by %All (through R).');
  assert.equal(throughSuffix('A'), STRINGS.userEffectiveThrough.replace('<role>', 'A'));
});

test('a public permission and a no each say so', () => {
  assert.equal(checkSentence(answer({ resource: '%DB_IRISTEMP', permission: 'WRITE', public: true, grantedBy: '', through: '' })), 'Yes. Every account holds %DB_IRISTEMP:WRITE publicly.');
  assert.equal(checkSentence(answer({ resource: '%Admin_Secure', permission: 'USE', held: false, grantedBy: '', through: '' })), 'No. U does not hold %Admin_Secure:USE.');
});

test('the %All statement and an unread section name their role and reason', () => {
  assert.equal(effectiveAllLine('R'), 'Holds every privilege: R is or grants %All.');
  assert.equal(uncheckedLine('%Admin_Manage:USE'), 'Not checked (requires %Admin_Manage:USE)');
  assert.equal(uncheckedLine('truncated'), 'Not checked (too many to check)');
});

test('an instance-supplied name holding a replacement pattern is shown as written', () => {
  assert.equal(checkSentence(answer({ name: '$&x', grantedBy: '$1', through: '$<role>' })), 'Yes. $&x holds %DB_USER:READ, granted by $1 (through $<role>).');
  assert.equal(checkSentence(answer({ name: 'x<pair>', grantedBy: '<name>' })), 'Yes. x<pair> holds %DB_USER:READ, granted by <name> (through A).');
  assert.equal(checkSentence(answer({ name: '<role>', held: false })), 'No. <role> does not hold %DB_USER:READ.');
  assert.equal(effectiveAllLine('$&'), 'Holds every privilege: $& is or grants %All.');
});

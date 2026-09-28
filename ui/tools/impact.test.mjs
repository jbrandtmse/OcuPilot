import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the client half of the impact line (AD-8, Story 16.19): the wire shape is read only inside
// the instance's vocabulary, each part renders as EXPERIENCE.md's Fixed strings row says -- up to
// three names and then " and <n> more", an unchecked part named as unchecked with the pair it
// requires and never as "no ...", a refusal rendered as its own sentence -- and the proposal row
// carries it to the card view. The client computes nothing. Needs nothing but the checkout.
//
// Mutations (Rule 19):
// - render the none phrase for an unchecked part in impactLine() -> the unchecked row goes red.
// - drop `impact` from parseProposal()'s result -> the wire row goes red.

const corePath = (name) => join(dirname(fileURLToPath(import.meta.url)), '..', 'src', 'app', 'core', name);

const { IMPACT_PARTS, impactLine, impactOf } = await import(corePath('impact.ts'));
const { parseProposals } = await import(corePath('turn.ts'));
const { toCardView } = await import(corePath('proposal-view.ts'));
const { STRINGS } = await import(corePath('strings.ts'));

const part = (name, count, names = [], unchecked = '') => ({ part: name, count, names, unchecked });

test('an impact is read only inside the instance vocabulary', () => {
  const good = { kind: 'role-delete', refused: null, parts: [part('holders', 1, ['Ann']), part('grantingApplications', 0)] };
  assert.deepEqual(impactOf(good), good);
  assert.deepEqual(impactOf({ ...good, refused: { code: 'PROHIBITED.X', reason: 'No.' }, parts: [] })?.refused, { code: 'PROHIBITED.X', reason: 'No.' });
  for (const bad of [
    null,
    [],
    'role-delete',
    { ...good, kind: 'web-delete' },
    { ...good, parts: 'none' },
    { ...good, parts: [part('loses', 0)] },
    { ...good, parts: [part('holders', -1)] },
    { ...good, parts: [part('holders', 1.5)] },
    { ...good, parts: [part('holders', 1, [7])] },
    { ...good, parts: [{ part: 'holders', count: 1, names: [] }] },
    { ...good, refused: { code: 'PROHIBITED.X', reason: '' } },
    { ...good, refused: 'no' },
  ]) {
    assert.equal(impactOf(bad), null, JSON.stringify(bad));
  }
  assert.deepEqual(IMPACT_PARTS['resource-delete'], ['grantingRoles', 'guardedApplications', 'guardedDatabases']);
});

test('each part renders its count and first three names, joined into one line', () => {
  const roleDelete = impactOf({
    kind: 'role-delete',
    refused: null,
    parts: [part('holders', 5, ['Ann', 'Bo', 'Cy']), part('grantingApplications', 1, ['/csp/p'])],
  });
  assert.equal(impactLine(roleDelete, 'R'), 'Impact: 5 users hold it: Ann, Bo, Cy and 2 more; 1 web application grants it: /csp/p.');
  const none = impactOf({ kind: 'role-delete', refused: null, parts: [part('holders', 0), part('grantingApplications', 2, ['/a', '/b'])] });
  assert.equal(impactLine(none, 'R'), 'Impact: no user holds it; 2 web applications grant it: /a, /b.');
  const resource = impactOf({
    kind: 'resource-delete',
    refused: null,
    parts: [part('grantingRoles', 2, ['A', 'B']), part('guardedApplications', 1, ['/csp/q']), part('guardedDatabases', 1, ['/data/user/'])],
  });
  assert.equal(
    impactLine(resource, 'X'),
    'Impact: 2 roles grant it: A, B; it guards 1 web application: /csp/q; it guards 1 database: /data/user/.'
  );
  const quiet = impactOf({
    kind: 'resource-delete',
    refused: null,
    parts: [part('grantingRoles', 1, ['A']), part('guardedApplications', 0), part('guardedDatabases', 0)],
  });
  assert.equal(impactLine(quiet, 'X'), 'Impact: 1 role grants it: A; it guards no web application; it guards no database.');
});

test('an unchecked part is said to be unchecked, naming the pair or the cap, never as none', () => {
  const unread = impactOf({
    kind: 'resource-delete',
    refused: null,
    parts: [part('grantingRoles', 0, [], 'truncated'), part('guardedApplications', 0), part('guardedDatabases', 0, [], '%Admin_Manage:USE')],
  });
  const line = impactLine(unread, 'X');
  assert.equal(
    line,
    'Impact: which roles grant it was not checked (too many to check); it guards no web application; which databases it guards was not checked (requires %Admin_Manage:USE).'
  );
  assert.ok(!line.includes(STRINGS.impactGuardedDatabasesNone), 'an unread databases part never says it guards none');
  const holders = impactOf({ kind: 'role-delete', refused: null, parts: [part('holders', 0, [], '%Admin_Secure:USE'), part('grantingApplications', 0, [], '%Admin_Secure:USE')] });
  assert.equal(
    impactLine(holders, 'R'),
    'Impact: who holds it was not checked (requires %Admin_Secure:USE); which web applications grant it was not checked (requires %Admin_Secure:USE).'
  );
});

test('a role removal names what the account loses, or that it loses nothing, about the subject', () => {
  const loses = impactOf({ kind: 'role-removal', refused: null, parts: [part('loses', 2, ['%All', '%DB_USER:RW'])] });
  assert.equal(impactLine(loses, 'Dana'), 'Impact: Dana loses %All, %DB_USER:RW.');
  const nothing = impactOf({ kind: 'role-removal', refused: null, parts: [part('loses', 0)] });
  assert.equal(impactLine(nothing, 'Dana'), 'Impact: Dana loses nothing their other roles do not still grant.');
  const unread = impactOf({ kind: 'role-removal', refused: null, parts: [part('loses', 0, [], '%Admin_Secure:USE')] });
  assert.equal(impactLine(unread, 'Dana'), 'Impact: what Dana loses was not checked (requires %Admin_Secure:USE).');
});

test('a name is shown as written, even one holding a replacement pattern or a placeholder', () => {
  // Mutation (Rule 19): insert the names with a plain string replacement in phraseOf() -> this goes red.
  const loses = impactOf({ kind: 'role-removal', refused: null, parts: [part('loses', 1, ['R$&D:RW'])] });
  assert.equal(impactLine(loses, 'a$`<names>'), 'Impact: a$`<names> loses R$&D:RW.');
  const holders = impactOf({ kind: 'role-delete', refused: null, parts: [part('holders', 1, ["x$'y"]), part('grantingApplications', 0)] });
  assert.equal(impactLine(holders, 'R'), "Impact: 1 user holds it: x$'y; no web application grants it.");
});

test('a refused removal renders the prohibited set\u2019s sentence and no impact, and none renders nothing', () => {
  const refused = impactOf({ kind: 'role-delete', refused: { code: 'PROHIBITED.OCUPILOTROLE', reason: 'This role belongs to OcuPilot.' }, parts: [] });
  assert.equal(impactLine(refused, 'R'), 'This role belongs to OcuPilot.');
  assert.equal(impactLine(null, 'R'), '');
});

test('Story 18.2: a namespace delete names the applications deleted with it and the databases that stay', () => {
  // Mutation (Rule 19): drop the empty-phrase filter from impactLine() -> the none and unchecked
  // legs read a dangling "; " and go red; render the databases part's count-0 phrase as the
  // applications' -> the same legs go red.
  assert.deepEqual(IMPACT_PARTS['namespace-delete'], ['boundApplications', 'databases']);
  const read = (parts, refused = null) => impactOf({ kind: 'namespace-delete', refused, parts });
  assert.notEqual(read([part('boundApplications', 0), part('databases', 1, ['USER'])]), null, 'the kind and both parts are in the vocabulary');
  assert.equal(read([part('holders', 0)]), null, 'a part the kind does not carry is not');
  assert.equal(
    impactLine(read([part('boundApplications', 2, ['/csp/a', '/csp/b']), part('databases', 2, ['IRISTEMP', 'USER'])]), 'NS'),
    'Impact: 2 web applications run in it and are deleted with it: /csp/a, /csp/b; it uses 2 databases, which stay: IRISTEMP, USER.'
  );
  assert.equal(
    impactLine(read([part('boundApplications', 1, ['/csp/a']), part('databases', 1, ['USER'])]), 'NS'),
    'Impact: 1 web application runs in it and is deleted with it: /csp/a; it uses 1 database, which stays: USER.'
  );
  assert.equal(
    impactLine(read([part('boundApplications', 0), part('databases', 0)]), 'NS'),
    'Impact: no web application runs in it.',
    'a databases part counted 0 renders nothing, and leaves no empty segment'
  );
  assert.equal(
    impactLine(read([part('boundApplications', 0, [], '%Admin_Secure:USE'), part('databases', 0, [], '%Admin_Manage:USE')]), 'NS'),
    'Impact: which web applications run in it was not checked (requires %Admin_Secure:USE).',
    'an unchecked applications part is said to be unchecked, and an unchecked databases part renders nothing'
  );
  assert.equal(impactLine(read([part('databases', 0)]), 'NS'), '', 'a line whose every part renders nothing is no line');
  assert.equal(impactLine(read([part('databases', 0, [], 'truncated')]), 'NS'), '');
  const reason = STRINGS.namespaceRefusalOcuPilot;
  assert.equal(impactLine(read([], { code: 'PROHIBITED.OCUPILOTNAMESPACE', reason }), 'HSCUSTOM'), reason, 'a refused delete states the refusal');
});

test('the proposal row carries the impact to the card view, and a row without one carries null', () => {
  const row = (impact) => ({
    proposalId: 'p1',
    target: { type: 'role', scope: 'instance', id: 'probe' },
    expiresAt: '2026-09-19T10:00:00Z',
    tool: 'permissions.roles.delete',
    changed: [],
    unchangedCount: 0,
    rationale: '',
    expectedImpact: '',
    reverse: '',
    state: 'live',
    auditWarning: false,
    impact,
  });
  const impact = { kind: 'role-delete', refused: null, parts: [part('holders', 0), part('grantingApplications', 0)] };
  const [parsed] = parseProposals([row(impact)]);
  assert.deepEqual(parsed.impact, impact);
  assert.deepEqual(toCardView(parsed, 'Role').impact, impact);
  const [bare] = parseProposals([row(null)]);
  assert.equal(bare.impact, null);
  assert.equal(toCardView(bare, 'Role').impact, null);
});

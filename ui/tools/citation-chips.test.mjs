import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the framework-free half of a citation chip (Story 11.4, AD-11, AD-13, AD-37): which wire
// entries the client accepts, the one URL builder a chip and the agent's navigation share, and the
// presence rule a click reads off the arriving screen's own rows.
//
// Mutations (Rule 19):
// - `entityUrl` appends the id without `encodeEntityId` -> "entityUrl encodes the id once as one
//   segment" goes red.
// - `citationPresence` answers `unknown` for a read with no match -> "a row the read no longer
//   returns is absent" goes red.
// - `parseCitations` keeps an entry whose route no built screen declares -> "parseCitations keeps
//   only routes the registry builds" goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);

const { parseCitations, acceptsEntityId, citationPresence, citationScreen, formatCitationAbsent } = await import(
  corePath('citations.ts')
);
const { entityUrl } = await import(corePath('navigation.ts'));
const { encodeEntityId } = await import(corePath('entity-id.ts'));
const { SCREENS } = await import(corePath('screens.generated.ts'));
const { STRINGS } = await import(corePath('strings.ts'));

const USERS = { type: 'user', scope: 'instance', id: '_SYSTEM', route: 'permissions/users', label: '_SYSTEM' };

test('parseCitations keeps only routes the registry builds, on screens that open one row', () => {
  const parent = SCREENS.find((screen) => screen.built && screen.parentScope !== '');
  const twoParts = SCREENS.find((screen) => screen.built && screen.id.kind === 'composite' && screen.id.parts.length > 1);
  assert.ok(parent && twoParts, 'the registry declares both kinds this test refuses');
  const parsed = parseCitations([
    USERS,
    { ...USERS, route: 'permissions/nosuch' },
    { ...USERS, route: parent.route },
    { ...USERS, route: twoParts.route },
    { ...USERS, label: '' },
    { ...USERS, id: 7 },
    'text',
    null,
  ]);
  assert.deepEqual(parsed, [USERS]);
  assert.deepEqual(parseCitations(undefined), [], 'a missing member reads as none');
  assert.deepEqual(parseCitations({}), [], 'and so does anything that is not an array');
});

test('acceptsEntityId: single, or composite with exactly one part', () => {
  assert.equal(acceptsEntityId({ id: { kind: 'single', parts: [] } }), true);
  assert.equal(acceptsEntityId({ id: { kind: 'composite', parts: ['Id'] } }), true);
  assert.equal(acceptsEntityId({ id: { kind: 'composite', parts: ['a', 'b'] } }), false);
  assert.equal(acceptsEntityId({ id: { kind: 'none', parts: [] } }), false);
});

test('entityUrl encodes the id once as one segment and keeps the current namespace for an instance scope', () => {
  assert.equal(entityUrl('permissions/users', '_SYSTEM', 'instance', '/home?ns=HSCUSTOM'), '/permissions/users/_SYSTEM?ns=HSCUSTOM');
  assert.equal(
    entityUrl('webapps/list', '/csp/user', '', '/home?ns=USER&x=1'),
    `/webapps/list/${encodeEntityId('/csp/user')}?ns=USER`
  );
  assert.equal(entityUrl('permissions/users', '', 'instance', '/home'), '/permissions/users', 'no id, no segment');
});

test('entityUrl names a namespace scope in place of the current one', () => {
  assert.equal(entityUrl('webapps/rest', 'x', 'USER', '/home?ns=HSCUSTOM'), '/webapps/rest/x?ns=USER');
});

test('a row the read still returns is present, exactly or in its canonical spelling', () => {
  const screen = citationScreen('permissions/users');
  assert.ok(screen);
  assert.equal(citationPresence([{ Name: 'Admin' }, { Name: '_SYSTEM' }], false, screen, '_SYSTEM'), 'present');
  assert.equal(citationPresence([{ Name: '_system' }], false, screen, '_SYSTEM'), 'present', 'a user name folds case');
});

test('a row the read no longer returns is absent, and unknown when the read was truncated', () => {
  const screen = citationScreen('permissions/users');
  assert.equal(citationPresence([{ Name: 'Admin' }], false, screen, 'OcuPilotCiteGone'), 'absent');
  assert.equal(citationPresence([{ Name: 'Admin' }], true, screen, 'OcuPilotCiteGone'), 'unknown');
});

test('the absent sentence names the cited label in the published string', () => {
  assert.equal(
    formatCitationAbsent('OcuPilotCiteGone'),
    STRINGS.citationAbsent.split('<name>').join('OcuPilotCiteGone')
  );
  assert.equal(formatCitationAbsent('x').startsWith('x is no longer present'), true);
});

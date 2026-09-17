import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the one function that builds both a turn's `context` and the chip's row count
// (`assembleScreenContext`, `contextRowsSent`), and the paste-warning backstop
// (`looksLikeSecret`), Story 4.11.
//
// Mutations (Rule 19):
// - drop the `share` guard from `assembleScreenContext` -> the sharing-off case goes red.
// - drop the secret-fields guard from `computeView` -> the secret-screen case goes red, and a
//   `view` (with no rows key at all server-side) would be posted for a secret-typed screen.
// - slice AFTER narrowing rather than before -> the cap-below-view case's `rowsAvailable` goes red.
// - return `false` for a `sk-` prefix -> the prefix cases redden; return `true` for
//   `%Api.Mgmnt.v2` -> the non-trigger cases redden.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);
const { screenDeclaration } = await import(join(uiRoot, 'src', 'app', 'testing', 'screen-declaration.ts'));

const { assembleScreenContext, contextRowsSent, contextViewDeclared, looksLikeSecret } = await import(
  corePath('screen-context.ts')
);

const READ = {
  source: { port: 'admin', endpoint: 'WebApp.App', type: 'LIST' },
  fields: ['Name', 'NameSpace', 'Enabled'],
  filter: ['Name'],
  sort: { fields: ['Name'], default: 'Name', direction: 'asc' },
  paging: 'cap',
};

function screen(overrides = {}) {
  return screenDeclaration({
    route: 'permissions/users',
    read: READ,
    context: { fields: ['Name', 'Enabled'], secretFields: [] },
    ...overrides,
  });
}

function rows(...names) {
  return names.map((name, index) => ({ Name: name, Enabled: index % 2 === 0, NameSpace: 'HSCUSTOM' }));
}

function baseInputs(overrides = {}) {
  return {
    descriptor: screen(),
    namespace: 'HSCUSTOM',
    entity: '',
    share: true,
    rows: rows('c', 'a', 'b'),
    filter: '',
    sort: '',
    direction: '',
    rowCap: 200,
    ...overrides,
  };
}

// --- assembleScreenContext -----------------------------------------------------------------

test('a fully resolved screen posts route, namespace and a view narrowed to the declared fields', () => {
  const payload = assembleScreenContext(baseInputs());
  assert.equal(payload.route, 'permissions/users');
  assert.equal(payload.namespace, 'HSCUSTOM');
  assert.equal('entity' in payload, false, 'no entity on a list screen');
  assert.equal(payload.view.rowsAvailable, 3);
  assert.deepEqual(payload.view.rows, [
    { Name: 'a', Enabled: false },
    { Name: 'b', Enabled: true },
    { Name: 'c', Enabled: true },
  ]);
  // `NameSpace` is not a declared context field and must not leak into the payload.
  for (const row of payload.view.rows) assert.equal('NameSpace' in row, false);
});

test('entity is included only when non-empty', () => {
  assert.equal('entity' in assembleScreenContext(baseInputs({ entity: '' })), false);
  assert.equal(assembleScreenContext(baseInputs({ entity: 'admin' })).entity, 'admin');
});

test('sharing off posts no context at all', () => {
  assert.equal(assembleScreenContext(baseInputs({ share: false })), null);
});

test('no resolved descriptor posts no context at all', () => {
  assert.equal(assembleScreenContext(baseInputs({ descriptor: null })), null);
});

test('a descriptor whose route is the empty string (Home) posts no context at all -- the server refuses an empty route outright', () => {
  assert.equal(assembleScreenContext(baseInputs({ descriptor: screen({ route: '' }) })), null);
});

test('an unresolved namespace posts no context at all', () => {
  assert.equal(assembleScreenContext(baseInputs({ namespace: '' })), null);
});

test('a screen with no declared read posts route and namespace but no view', () => {
  const payload = assembleScreenContext(baseInputs({ descriptor: screen({ read: null, context: { fields: [], secretFields: [] } }) }));
  assert.equal('view' in payload, false);
});

test('a screen whose context declares no fields posts no view', () => {
  const payload = assembleScreenContext(baseInputs({ descriptor: screen({ context: { fields: [], secretFields: [] } }) }));
  assert.equal('view' in payload, false);
});

test('a screen declaring any secret field posts identity only, no view', () => {
  const secretScreen = screen({ read: null, context: { fields: [], secretFields: ['apiKey'] } });
  const payload = assembleScreenContext(baseInputs({ descriptor: secretScreen, rows: [] }));
  assert.equal(payload.route, 'permissions/users');
  assert.equal('view' in payload, false);
});

test('the row cap slices after the full filtered-and-sorted view, so rowsAvailable is the pre-cap count', () => {
  const payload = assembleScreenContext(baseInputs({ rowCap: 1 }));
  assert.equal(payload.view.rows.length, 1);
  assert.deepEqual(payload.view.rows, [{ Name: 'a', Enabled: false }]);
  assert.equal(payload.view.rowsAvailable, 3, 'the full post-filter count, not the capped one');
});

test('a filter narrows both the sent rows and rowsAvailable', () => {
  const payload = assembleScreenContext(baseInputs({ filter: 'a' }));
  assert.equal(payload.view.rowsAvailable, 1);
  assert.deepEqual(payload.view.rows, [{ Name: 'a', Enabled: false }]);
});

test('sort, direction and filter are carried through verbatim as the caller supplied them', () => {
  const payload = assembleScreenContext(baseInputs({ sort: 'Name', direction: 'desc', filter: 'a' }));
  assert.equal(payload.view.sort, 'Name');
  assert.equal(payload.view.direction, 'desc');
  assert.equal(payload.view.filter, 'a');
});

// --- contextViewDeclared ---------------------------------------------------------------------

test('contextViewDeclared agrees with assembleScreenContext about whether a view would post', () => {
  assert.equal(contextViewDeclared(screen()), true);
  assert.equal(contextViewDeclared(null), false);
  assert.equal(contextViewDeclared(screen({ read: null })), false);
  assert.equal(contextViewDeclared(screen({ context: { fields: [], secretFields: [] } })), false);
  assert.equal(contextViewDeclared(screen({ context: { fields: ['Name'], secretFields: ['apiKey'] } })), false);
});

// --- contextRowsSent -------------------------------------------------------------------------

test('contextRowsSent agrees with the payload it would produce', () => {
  const inputs = baseInputs({ rowCap: 2 });
  assert.equal(contextRowsSent(inputs), assembleScreenContext(inputs).view.rows.length);
  assert.equal(contextRowsSent(inputs), 2);
});

test('contextRowsSent is 0 exactly when the row segment would be omitted', () => {
  assert.equal(contextRowsSent(baseInputs({ descriptor: screen({ read: null }) })), 0);
  assert.equal(contextRowsSent(baseInputs({ descriptor: screen({ context: { fields: [], secretFields: [] } }) })), 0);
  assert.equal(
    contextRowsSent(baseInputs({ descriptor: screen({ context: { fields: ['Name'], secretFields: ['apiKey'] } }) })),
    0
  );
});

// --- looksLikeSecret -------------------------------------------------------------------------

test('a known key prefix always triggers, however short the rest of the draft', () => {
  for (const prefix of ['sk-ant-api03-x', '-----BEGIN PRIVATE KEY-----', 'AKIAABCDEF', 'ghp_x', 'xoxb-1', 'AIzaSyX']) {
    assert.equal(looksLikeSecret(prefix), true, prefix);
    assert.equal(looksLikeSecret('  ' + prefix + '  '), true, `trimmed: ${prefix}`);
  }
});

test('a long, mixed-class, unbroken token triggers even with no known prefix', () => {
  assert.equal(looksLikeSecret('correct horse battery staple ' + 'aB3' + 'xyzxyzxyzxyzxyzxyzxyzxyz'), true);
});

test('a token under 24 characters never triggers on entropy alone', () => {
  assert.equal(looksLikeSecret('aB3xyzxyzxyzxyzxyzxyz'), false);
});

test('a token using fewer than three character classes never triggers', () => {
  assert.equal(looksLikeSecret('abcdefghijklmnopqrstuvwx'), false, 'lower case only');
  assert.equal(looksLikeSecret('abcdefghijklmnopqrstuvwxABCDEF'), false, 'two classes');
});

test('a token holding an excluded character never triggers, whatever its other substrings', () => {
  assert.equal(looksLikeSecret('https://localhost:52774/csp/sys/UtilHome.csp'), false);
  assert.equal(looksLikeSecret('%Api.Mgmnt.v2'), false);
  assert.equal(looksLikeSecret('^OcuPilotTurnSlot("_SYSTEM")'), false);
});

test('an empty or whitespace-only draft never triggers', () => {
  assert.equal(looksLikeSecret(''), false);
  assert.equal(looksLikeSecret('   '), false);
});

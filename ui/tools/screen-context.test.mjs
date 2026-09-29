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
// - keep requiring a declared read in `computeView` -> the no-read case goes red (Story 11.9).
// - restore the `route === ''` exclusion in `assembleScreenContext` -> the Home case goes red
//   (Story 11.1).
// - return `false` for a `sk-` prefix -> the prefix cases redden; return `true` for
//   `%Api.Mgmnt.v2` -> the non-trigger cases redden.
// - `assembleEntryContext` sends a view of the one entry, as Story 11.2 shipped it -> the
//   page's-rows and focus cases redden (DW-1838).
// - `assembleEntryContext` always sends `focus` -> the selected cases redden; always `selected` 0
//   -> the outside-the-cap and filtered-out cases redden; index the rows before the filter and
//   sort -> the sent-view case reddens; send `focus` for index 0 -> the first-row case reddens.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);
const { screenDeclaration } = await import(join(uiRoot, 'src', 'app', 'testing', 'screen-declaration.ts'));

const { assembleEntryContext, assembleScreenContext, contextRowsSent, contextViewDeclared, looksLikeSecret } = await import(
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

test('Home, whose route is the empty string, posts its route and namespace and no view', () => {
  const home = screen({ route: '', read: null, context: { fields: [], secretFields: [] } });
  assert.deepEqual(assembleScreenContext(baseInputs({ descriptor: home, rows: [] })), { route: '', namespace: 'HSCUSTOM' });
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
  assert.equal(contextViewDeclared(screen({ read: null })), true, 'declared fields send a view with no read');
  assert.equal(contextViewDeclared(screen({ read: null, context: { fields: [], secretFields: [] } })), false);
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
  assert.equal(contextRowsSent(baseInputs({ descriptor: screen({ read: null, context: { fields: [], secretFields: [] } }) })), 0);
  assert.equal(contextRowsSent(baseInputs({ descriptor: screen({ context: { fields: [], secretFields: [] } }) })), 0);
  assert.equal(
    contextRowsSent(baseInputs({ descriptor: screen({ context: { fields: ['Name'], secretFields: ['apiKey'] } }) })),
    0
  );
});

// --- a screen with no declared read (Story 11.9) --------------------------------------------

const ERROR_FIELDS = ['errorNumber', 'time', 'errorText', 'routine', 'line'];

function errorScreen() {
  return screen({ route: 'logs/errors', read: null, context: { fields: ERROR_FIELDS, secretFields: [] } });
}

function errorRows(...numbers) {
  return numbers.map((errorNumber) => ({
    errorNumber,
    time: `17:0${errorNumber}:38`,
    errorText: '<DIVIDE>x^y',
    routine: 'y',
    line: ' s x=1/0',
    username: 'Dana',
    process: '4711',
  }));
}

test('a screen with no declared read sends the rows it was given, in order, narrowed and capped', () => {
  const inputs = baseInputs({
    descriptor: errorScreen(),
    rows: errorRows(3, 1, 2),
    filter: '17:02:38',
    sort: 'time',
    direction: 'desc',
    rowCap: 2,
  });
  const payload = assembleScreenContext(inputs);
  assert.equal(payload.route, 'logs/errors');
  assert.deepEqual(
    payload.view.rows.map((row) => row.errorNumber),
    [3, 1],
    'the supplied order, cut at the row cap -- a time sort in either direction, or the filter matching row 2 alone, would differ'
  );
  for (const row of payload.view.rows) {
    assert.deepEqual(Object.keys(row), ERROR_FIELDS, 'the declared summary fields alone');
    assert.equal('username' in row, false, 'the user name never goes');
    assert.equal('process' in row, false, 'nor the process');
  }
  assert.equal(payload.view.rowsAvailable, 3, 'rowsAvailable is the supplied count');
  assert.equal(payload.view.sort, '');
  assert.equal(payload.view.direction, '');
  assert.equal(payload.view.filter, '');
});

test('the chip agrees with a no-read screen: its row segment shows, counting what the payload sends', () => {
  const inputs = baseInputs({ descriptor: errorScreen(), rows: errorRows(1, 2, 3), rowCap: 2 });
  assert.equal(contextViewDeclared(errorScreen()), true);
  assert.equal(contextRowsSent(inputs), assembleScreenContext(inputs).view.rows.length);
  assert.equal(contextRowsSent(inputs), 2);
  assert.equal(contextRowsSent(baseInputs({ descriptor: errorScreen(), rows: [] })), 0, 'a level with no rows sends none');
});

test('a form page (no read, no context fields) posts identity only: no view, no rows, no row segment', () => {
  const form = screen({ route: 'os-management/devices/edit', read: null, context: { fields: [], secretFields: [] } });
  const inputs = baseInputs({ descriptor: form, rows: [{ Name: 'typed', Description: 'unsaved' }] });
  const payload = assembleScreenContext(inputs);
  assert.deepEqual(payload, { route: 'os-management/devices/edit', namespace: 'HSCUSTOM' });
  assert.equal(contextViewDeclared(form), false);
  assert.equal(contextRowsSent(inputs), 0);
});

// --- assembleEntryContext (Story 11.2, DW-1838) ------------------------------------------------

const SCOPED_ERROR_FIELDS = ['namespace', 'date', ...ERROR_FIELDS];

function scopedErrorScreen() {
  return screen({ route: 'logs/errors', read: null, context: { fields: SCOPED_ERROR_FIELDS, secretFields: [] } });
}

/** The error list's rows as the page publishes them: each with the drilled namespace and date. */
function scopedErrorRows(...numbers) {
  return errorRows(...numbers).map((row) => ({ namespace: 'USER', date: '09/25/2026', ...row, stack: 'captured', variables: 'captured' }));
}

function entryInputs(overrides = {}) {
  const rows = scopedErrorRows(1, 2, 3);
  return { ...baseInputs({ descriptor: scopedErrorScreen(), rows }), row: rows[1], ...overrides };
}

test("an entry posts exactly its screen's own context, with selected pointing at the entry among the page's rows", () => {
  const inputs = entryInputs();
  const payload = assembleEntryContext(inputs);
  const { selected, ...view } = payload.view;
  assert.deepEqual({ ...payload, view }, assembleScreenContext(inputs), "the screen's own route, namespace, rows, cap, sort and filter");
  assert.equal(payload.view.rows.length, 3, "every row on the page, not the entry alone");
  assert.equal(payload.view.rowsAvailable, 3);
  assert.equal(selected, 1, "the entry's index in the rows sent");
  assert.equal(payload.view.rows[selected].errorNumber, 2);
  assert.equal('focus' in payload.view, false, 'one marker, never both');
});

test('selected indexes the sent view after the filter and sort, not the rows as given, the first row being 0', () => {
  const given = rows('d', 'ca', 'b', 'cb');
  const inputs = baseInputs({ rows: given, filter: 'c', sort: 'Name', direction: 'desc' });
  const payload = assembleEntryContext({ ...inputs, row: given[1] });
  assert.deepEqual(payload.view.rows.map((row) => row.Name), ['cb', 'ca']);
  assert.equal(payload.view.selected, 1, "the filter leaves 'd' out and 'ca' sorts after 'cb'");
  assert.equal(assembleEntryContext({ ...inputs, row: given[3] }).view.selected, 0, 'the first row sent is 0');
});

test("an entry outside the cap arrives as the focus row, narrowed, with the page's rows still sent", () => {
  const inputs = entryInputs({ rowCap: 2, row: scopedErrorRows(1, 2, 3)[2] });
  const payload = assembleEntryContext(inputs);
  assert.equal(payload.view.rows.length, 2, "the page's rows up to the cap");
  assert.equal(payload.view.rowsAvailable, 3);
  assert.equal('selected' in payload.view, false, 'one marker, never both');
  assert.deepEqual(Object.keys(payload.view.focus), SCOPED_ERROR_FIELDS, 'the declared fields alone');
  assert.equal(payload.view.focus.errorNumber, 3);
  assert.equal(payload.view.focus.namespace, 'USER', 'the drilled namespace travels with the entry');
  for (const dropped of ['username', 'process', 'stack', 'variables']) assert.equal(dropped in payload.view.focus, false, dropped);
});

test('an entry the filter leaves out, or one the page holds no row for, arrives as the focus row', () => {
  const given = rows('c', 'a', 'b');
  const filtered = assembleEntryContext({ ...baseInputs({ rows: given, filter: 'b' }), row: given[0] });
  assert.deepEqual(filtered.view.rows, [{ Name: 'b', Enabled: true }]);
  assert.deepEqual(filtered.view.focus, { Name: 'c', Enabled: true });
  const absent = assembleEntryContext({ ...baseInputs({ rows: [] }), row: { Name: 'z', Enabled: true, NameSpace: 'USER' } });
  assert.deepEqual(absent.view.rows, []);
  assert.deepEqual(absent.view.focus, { Name: 'z', Enabled: true });
});

test('a row equal to the entry in every declared field is the entry, whatever else it holds', () => {
  const given = rows('c', 'a', 'b');
  const payload = assembleEntryContext({ ...baseInputs({ rows: given }), row: { Name: 'b', Enabled: true, NameSpace: 'elsewhere' } });
  assert.equal(payload.view.selected, 1);
  const differs = assembleEntryContext({ ...baseInputs({ rows: given }), row: { Name: 'b', Enabled: false } });
  assert.equal('selected' in differs.view, false, 'one declared field differing is another entry');
});

test('an ordinary turn carries neither marker', () => {
  const payload = assembleScreenContext(entryInputs());
  assert.equal('selected' in payload.view, false);
  assert.equal('focus' in payload.view, false);
});

test('an entry sends nothing with sharing off, no descriptor, no namespace, or a screen with no view', () => {
  assert.equal(assembleEntryContext(entryInputs({ share: false })), null, 'sharing off');
  assert.equal(assembleEntryContext(entryInputs({ descriptor: null })), null, 'no descriptor');
  assert.equal(assembleEntryContext(entryInputs({ namespace: '' })), null, 'no namespace');
  assert.equal(
    assembleEntryContext(entryInputs({ descriptor: screen({ context: { fields: ['Name'], secretFields: ['Password'] } }) })),
    null,
    'a screen declaring secret fields'
  );
  assert.equal(
    assembleEntryContext(entryInputs({ descriptor: screen({ context: { fields: [], secretFields: [] } }) })),
    null,
    'a screen declaring no context fields'
  );
});

test('an entry that is not an object arrives as an empty focus row rather than the value', () => {
  const payload = assembleEntryContext(entryInputs({ row: 'raw text' }));
  assert.deepEqual(payload.view.focus, {});
  assert.equal(payload.view.rows.length, 3);
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

// --- Story 16.18: Home's performance row -----------------------------------------------------
//
// Mutation (Rule 19): empty Home's `context.fields` in its descriptor and regenerate the mirror ->
// the first case goes red with no view.

const { SCREENS } = await import(corePath('screens.generated.ts'));
const SHIPPED_HOME = SCREENS.find((entry) => entry.descriptor === 'OcuPilot.Screen.Descriptor.Home');
const PERFORMANCE = {
  cacheEfficiency: 8745.8,
  globalReferencesPerSecond: 47089,
  globalUpdatesPerSecond: 1203,
  diskReadsPerSecond: 12,
  diskWritesPerSecond: 34,
};

test('Story 16.18 AC4: Home posts its one store row, the five performance values, as its view', () => {
  const payload = assembleScreenContext(baseInputs({ descriptor: SHIPPED_HOME, rows: [PERFORMANCE] }));
  assert.equal(payload.route, '');
  assert.deepEqual(payload.view?.rows, [PERFORMANCE]);
  assert.equal(payload.view?.rowsAvailable, 1);
  assert.equal(contextRowsSent(baseInputs({ descriptor: SHIPPED_HOME, rows: [PERFORMANCE] })), 1);
});

test('Story 16.18 AC4: with the row absent Home posts a view of no rows', () => {
  const payload = assembleScreenContext(baseInputs({ descriptor: SHIPPED_HOME, rows: [] }));
  assert.deepEqual(payload.view?.rows, []);
});

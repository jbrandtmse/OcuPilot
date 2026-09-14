import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the data table's pure rules (`core/table-model.ts`): row keys, cells, the footer copy, the
// max-rows parse, keyboard movement, the reconcile after the view changes, and the empty state.
// One case per I/O-matrix row the model decides.
//
// Mutations (Rule 19):
// - `reconcile` keeps the active index instead of the key -> "an active key still in the view stays
//   active wherever it moved" goes red.
// - `parseMaxRows` accepts 0 -> "DW-17 bad cap" goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const core = (name) => join(uiRoot, 'src', 'app', 'core', name);

const model = await import(core('table-model.ts'));
const { STRINGS } = await import(core('strings.ts'));
const { COMPOSITE_SEPARATOR } = await import(core('entity-id.ts'));
const { screenDeclaration } = await import(join(uiRoot, 'src', 'app', 'testing', 'screen-declaration.ts'));

const TABLE = {
  columns: [
    { field: 'Name', labelKey: 'fieldUserName', kind: 'name' },
    { field: 'NameSpace', labelKey: 'headerNamespaceLabel', kind: 'identifier' },
  ],
  emptyNextKey: 'classicLinkCardCaption',
  emptyAgentKey: '',
};

test('a row key is the name column text, or the composite parts joined by the shared separator', () => {
  const single = screenDeclaration({ table: TABLE });
  assert.equal(model.rowKey({ Name: '/csp/app', NameSpace: 'USER' }, single), '/csp/app');
  assert.equal(model.rowKey({ Name: 7 }, single), '7', 'a number key is its JSON text');

  const composite = screenDeclaration({ table: TABLE, id: { kind: 'composite', parts: ['NameSpace', 'Name'] } });
  assert.equal(model.rowKey({ Name: '/csp/app', NameSpace: 'USER' }, composite), `USER${COMPOSITE_SEPARATOR}/csp/app`);
});

test('cells: (none) for null, absent and empty; name and identifier in code; the status disc and word', () => {
  for (const value of [null, undefined, '']) {
    const cell = model.cellView(value, 'text');
    assert.equal(cell.text, STRINGS.tableEmptyValue);
    assert.equal(cell.empty, true);
  }
  assert.deepEqual(model.cellView('/csp/app', 'name'), { text: '/csp/app', empty: false, disc: null, code: true, link: true, numeric: false });
  assert.equal(model.cellView('%DB_USER', 'identifier').code, true);
  assert.equal(model.cellView('%DB_USER', 'identifier').link, false);
  assert.equal(model.cellView(12, 'number').numeric, true);
  assert.equal(model.cellView(12, 'number').text, '12');
  assert.deepEqual(model.cellView(true, 'status'), { text: STRINGS.tableStatusYes, empty: false, disc: 'success', code: false, link: false, numeric: false });
  assert.equal(model.cellView(false, 'status').disc, 'outline');
  assert.equal(model.cellView(false, 'status').text, STRINGS.tableStatusNo);
  const notBoolean = model.cellView('Running', 'status');
  assert.equal(notBoolean.disc, null, 'a non-boolean status value has no disc');
  assert.equal(notBoolean.text, 'Running');
  assert.equal(model.cellView('Plain', 'text').code, false);
});

test('At the cap: the footer reads "500 rows" and the notice names the cap; DW-141: "2 rows"', () => {
  assert.equal(model.formatRowCount(STRINGS.tableRowCount, 500), '500 rows');
  assert.equal(model.formatRowCount(STRINGS.tableRowCount, 1000), '1,000 rows');
  assert.equal(model.formatRowCount(STRINGS.tableRowCount, 2), '2 rows');
  assert.equal(model.formatRowCount(STRINGS.tableRowCount, 0), '0 rows');
  assert.equal(
    model.formatCapNotice(STRINGS.tableRowCapNotice, 500),
    'Showing the first 500 rows. Narrow the filter or raise the max rows.'
  );
  assert.equal(model.groupDigits(1234567), '1,234,567');
});

test('DW-17 bad cap: 0, -5, 2.5, abc and "" are refused; Cap raised: 5000 is a cap', () => {
  for (const text of ['0', '-5', '2.5', 'abc', '', '   ', '1e3', '9007199254740993']) {
    assert.equal(model.parseMaxRows(text), null, `refused: ${JSON.stringify(text)}`);
  }
  assert.equal(model.parseMaxRows('5000'), 5000);
  assert.equal(model.parseMaxRows(' 1 '), 1);
});

test('moving the active row: arrows step, Home and End jump, pages step by the page, and the ends clamp', () => {
  assert.equal(model.moveActive(-1, 'ArrowDown', 10, 4), 0, 'from no active row the first move lands on the first');
  assert.equal(model.moveActive(-1, 'End', 10, 4), 9);
  assert.equal(model.moveActive(3, 'ArrowDown', 10, 4), 4);
  assert.equal(model.moveActive(3, 'ArrowUp', 10, 4), 2);
  assert.equal(model.moveActive(0, 'ArrowUp', 10, 4), 0);
  assert.equal(model.moveActive(9, 'ArrowDown', 10, 4), 9);
  assert.equal(model.moveActive(3, 'PageDown', 10, 4), 7);
  assert.equal(model.moveActive(8, 'PageDown', 10, 4), 9);
  assert.equal(model.moveActive(2, 'PageUp', 10, 4), 0);
  assert.equal(model.moveActive(5, 'Home', 10, 4), 0);
  assert.equal(model.moveActive(5, 'PageDown', 10, 0), 6, 'a page of no rows still steps');
  assert.equal(model.moveActive(0, 'ArrowDown', 0, 4), -1, 'no rows, no active row');
  assert.equal(model.isMoveKey('PageDown'), true);
  assert.equal(model.isMoveKey('Enter'), false);
});

test('DW-18 re-fetch: B active and selected of A,B,C; the tick answers A,C -> C active, no selection', () => {
  const result = model.reconcile({
    previousKeys: ['A', 'B', 'C'],
    nextKeys: ['A', 'C'],
    active: 'B',
    selected: 'B',
    gridFocused: true,
    emptyStateShown: false,
  });
  assert.deepEqual(result, { active: 'C', selected: '', focus: 'none' });
});

test('an active key still in the view stays active wherever it moved', () => {
  const result = model.reconcile({
    previousKeys: ['A', 'B', 'C'],
    nextKeys: ['N', 'A', 'B', 'C'],
    active: 'B',
    selected: 'B',
    gridFocused: true,
    emptyStateShown: false,
  });
  assert.deepEqual(result, { active: 'B', selected: 'B', focus: 'none' });
});

test('DW-18 last row: C active of A,B,C; a filter removes C -> B active', () => {
  const result = model.reconcile({
    previousKeys: ['A', 'B', 'C'],
    nextKeys: ['A', 'B'],
    active: 'C',
    selected: '',
    gridFocused: false,
    emptyStateShown: false,
  });
  assert.deepEqual(result, { active: 'B', selected: '', focus: 'none' });
});

test('Emptied: a focused grid whose re-fetch answers zero rows sends focus to the empty state', () => {
  const result = model.reconcile({
    previousKeys: ['A'],
    nextKeys: [],
    active: 'A',
    selected: 'A',
    gridFocused: true,
    emptyStateShown: true,
  });
  assert.deepEqual(result, { active: '', selected: '', focus: 'empty' });
});

test('Filtered to zero: a focused grid with no row matching the filter sends focus to the filter field', () => {
  const result = model.reconcile({
    previousKeys: ['A'],
    nextKeys: [],
    active: 'A',
    selected: '',
    gridFocused: true,
    emptyStateShown: false,
  });
  assert.deepEqual(result, { active: '', selected: '', focus: 'filter' });
  assert.equal(
    model.reconcile({ previousKeys: ['A'], nextKeys: [], active: 'A', selected: '', gridFocused: false, emptyStateShown: false }).focus,
    'none',
    'an unfocused grid moves nobody'
  );
});

test('write-capable means a primary action or a row action, and picks the empty state second line', () => {
  const lookup = (key) => ({ webEmpty: 'No web applications in <NAMESPACE>.', webNext: 'Create one from the classic portal.', webAgent: 'create a web application' })[key] ?? '';
  const readOnly = screenDeclaration({ emptyStateKey: 'webEmpty', table: { ...TABLE, emptyNextKey: 'webNext' } });
  assert.equal(model.isWriteCapable(readOnly), false);
  assert.deepEqual(model.emptyStateView(readOnly, 'HSCUSTOM', lookup), {
    title: 'No web applications in HSCUSTOM.',
    next: 'Create one from the classic portal.',
  });

  const writeCapable = screenDeclaration({
    emptyStateKey: 'webEmpty',
    rowActions: [{ id: 'disable', selfProtection: '' }],
    table: { ...TABLE, emptyNextKey: '', emptyAgentKey: 'webAgent' },
  });
  assert.equal(model.isWriteCapable(writeCapable), true);
  assert.deepEqual(model.emptyStateView(writeCapable, 'USER', lookup), {
    title: 'No web applications in USER.',
    next: 'Or ask the agent: create a web application.',
  });
  assert.equal(model.isWriteCapable(screenDeclaration({ primaryAction: { id: 'create', selfProtection: '' } })), true);
});

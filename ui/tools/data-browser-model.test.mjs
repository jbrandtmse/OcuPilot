import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins Data browser's pure rules (`core/data-browser-model.ts`, Story 19.7): the tri-state sort, the
// grid's cell moves over the header row, offset paging, how a cell reads, a column's track, which
// kinds take a filter, and the status lines; and the token rule over its styles -- every custom
// property the `ocu-data-browser` rules read is one of OcuPilot's own, and the harvest's `--ite-*`
// palette appears nowhere under `ui/src`. Story 19.8 adds the editors' parsers, the BIT toggle, a
// row's key and the staged changes; Story 19.16 adds go to row, a page's CSV cells, the tab cap and
// the shortcut table's matchers, run on plain event objects.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const core = (name) => join(uiRoot, 'src', 'app', 'core', name);

const model = await import(core('data-browser-model.ts'));
const { STRINGS } = await import(core('strings.ts'));
const csv = await import(core('csv.ts'));

// Mutation (Rule 19): `nextSort` answering ascending after descending -> the third step goes red.
test('a header cycles a new column ascending, then descending, then none', () => {
  let sort = model.nextSort(null, 'Num');
  assert.deepEqual(sort, { column: 'Num', direction: 'asc' });
  sort = model.nextSort(sort, 'Num');
  assert.deepEqual(sort, { column: 'Num', direction: 'desc' });
  sort = model.nextSort(sort, 'Num');
  assert.equal(sort, null);
  assert.deepEqual(model.nextSort({ column: 'Num', direction: 'desc' }, 'Name'), { column: 'Name', direction: 'asc' }, 'another column starts ascending');
});

test('cell moves: arrows without wrap over the header row, Home and End, Ctrl/Cmd+Home and End, PageUp and PageDown', () => {
  const move = (row, column, key, control = false) => model.moveCell({ row, column }, key, control, 30, 4, 10);
  assert.deepEqual(move(-1, 0, 'ArrowUp'), { row: -1, column: 0 }, 'the header row is the top');
  assert.deepEqual(move(-1, 2, 'ArrowDown'), { row: 0, column: 2 });
  assert.deepEqual(move(0, 2, 'ArrowUp'), { row: -1, column: 2 }, 'up from the first row reaches the header');
  assert.deepEqual(move(29, 3, 'ArrowDown'), { row: 29, column: 3 }, 'no wrap past the last row');
  assert.deepEqual(move(5, 0, 'ArrowLeft'), { row: 5, column: 0 }, 'no wrap past the first column');
  assert.deepEqual(move(5, 3, 'ArrowRight'), { row: 5, column: 3 }, 'no wrap past the last column');
  assert.deepEqual(move(5, 2, 'Home'), { row: 5, column: 0 });
  assert.deepEqual(move(5, 1, 'End'), { row: 5, column: 3 });
  assert.deepEqual(move(5, 2, 'Home', true), { row: -1, column: 0 }, 'Ctrl/Cmd+Home: the first cell, in the header row');
  assert.deepEqual(move(5, 1, 'End', true), { row: 29, column: 3 }, 'Ctrl/Cmd+End: the last cell');
  assert.deepEqual(move(5, 1, 'PageDown'), { row: 15, column: 1 });
  assert.deepEqual(move(25, 1, 'PageDown'), { row: 29, column: 1 });
  assert.deepEqual(move(5, 1, 'PageUp'), { row: -1, column: 1 });
  assert.equal(move(5, 1, 'PageDown', true), null, 'Ctrl/Cmd+PageDown is a page change, not a move');
  assert.equal(move(5, 1, 'Enter'), null);
  assert.equal(model.moveCell({ row: -1, column: 0 }, 'ArrowDown', false, 0, 4, 10)?.row, -1, 'with no row the header stays');
  assert.equal(model.pageKey('PageDown', true), 'next');
  assert.equal(model.pageKey('PageUp', true), 'previous');
  assert.equal(model.pageKey('PageDown', false), null);
});

test('offset paging: previous one page back, next past the rows kept, last only while the total is known, go to page 1 to N', () => {
  assert.equal(model.previousOffset(150, 100), 50);
  assert.equal(model.previousOffset(40, 100), 0);
  assert.equal(model.nextOffset(100, 37), 137, 'a page cut short skips nothing');
  assert.equal(model.lastOffset(260, 100), 200);
  assert.equal(model.lastOffset(200, 100), 100);
  assert.equal(model.lastOffset(0, 100), 0);
  assert.equal(model.lastOffset(null, 100), null);
  assert.equal(model.pageCount(260, 50), 6);
  assert.equal(model.pageCount(0, 50), 1);
  assert.equal(model.pageCount(null, 50), null);
  assert.equal(model.pageOf(100, 50), 3);
  assert.equal(model.goToPageOffset('3', 50, 260), 100);
  assert.equal(model.goToPageOffset(' 6 ', 50, 260), 250);
  assert.equal(model.goToPageOffset('7', 50, 260), null, 'past the page count');
  assert.equal(model.goToPageOffset('0', 50, 260), null);
  assert.equal(model.goToPageOffset('2.5', 50, 260), null);
  assert.equal(model.goToPageOffset('40', 50, null), 1950, 'any page while the total is unknown');
  assert.equal(model.goToPageOffset('9999999', 500, null), null, 'never past the route\'s furthest offset');
  assert.deepEqual(model.PAGE_SIZES, [50, 100, 250, 500]);
  assert.equal(model.DEFAULT_PAGE_SIZE, 100);
});

test('a cell reads NULL apart from an empty value, BIT as the yes and no words, and a number right-aligned', () => {
  assert.deepEqual(model.cellView('text', null), { text: STRINGS.explorerSqlDataNull, isNull: true, numeric: false });
  assert.deepEqual(model.cellView('text', ''), { text: '', isNull: false, numeric: false });
  assert.deepEqual(model.cellView('boolean', '1'), { text: STRINGS.tableStatusYes, isNull: false, numeric: false });
  assert.deepEqual(model.cellView('boolean', '0'), { text: STRINGS.tableStatusNo, isNull: false, numeric: false });
  assert.deepEqual(model.cellView('number', '12.5'), { text: '12.5', isNull: false, numeric: true });
  assert.equal(model.cellView('date', '2026-10-01').text, '2026-10-01', 'the ODBC form as answered');
  assert.equal(model.cellView('binary', '0x00FF').text, '0x00FF');
  assert.equal(model.isFilterable('stream'), false);
  assert.equal(model.isFilterable('binary'), false);
  for (const kind of ['number', 'boolean', 'date', 'time', 'timestamp', 'text']) assert.equal(model.isFilterable(kind), true, kind);
  assert.equal(model.columnTrack('number'), 'minmax(112px, 1fr)');
  assert.equal(model.columnTrack('stream'), 'minmax(240px, 1fr)');
});

test('the status lines: Rows a\u2013b of n, Rows a\u2013b, an empty page, the sort announcements and the page range', () => {
  assert.equal(model.rowsLine(0, 40, 40, false), 'Rows 1\u201340 of 40');
  assert.equal(model.rowsLine(1000, 500, 2500, false), 'Rows 1,001\u20131,500 of 2,500');
  assert.equal(model.rowsLine(100, 37, null, false), 'Rows 101\u2013137');
  assert.equal(model.rowsLine(0, 0, 0, false), STRINGS.explorerSqlDataNoRows);
  assert.equal(model.rowsLine(0, 0, 0, true), STRINGS.explorerSqlDataNoMatch);
  assert.equal(model.sortLine({ column: 'Num', direction: 'asc' }), 'Sorted by Num, ascending.');
  assert.equal(model.sortLine({ column: 'Num', direction: 'desc' }), 'Sorted by Num, descending.');
  assert.equal(model.sortLine(null), 'Sort cleared.');
  assert.equal(model.pageRangeLine(6), 'Enter a page from 1 to 6.');
});

/** Every file under `dir` whose name ends in one of `suffixes`. */
function filesUnder(dir, suffixes) {
  const found = [];
  for (const name of readdirSync(dir)) {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) found.push(...filesUnder(path, suffixes));
    else if (suffixes.some((suffix) => name.endsWith(suffix))) found.push(path);
  }
  return found;
}

// AC10. Mutation (Rule 19): add `color: var(--ite-fg);` to an `ocu-data-browser` rule in
// `_components.scss` -> both legs go red.
test('the data browser draws only OcuPilot tokens, and the harvest\'s --ite-* palette appears nowhere under ui/src', () => {
  const styles = readFileSync(join(uiRoot, 'src', 'styles', '_components.scss'), 'utf8');
  const rules = [...styles.matchAll(/(^\.ocu-data-browser[^{]*\{[^}]*\})/gm)].map((match) => match[1]);
  assert.ok(rules.length >= 20, `the data browser's rules are found: ${rules.length}`);
  const properties = rules.flatMap((rule) => [...rule.matchAll(/var\((--[a-z0-9-]+)/g)].map((match) => match[1]));
  assert.ok(properties.length > 0, 'and they read custom properties');
  assert.deepEqual(properties.filter((name) => !name.startsWith('--ocu-')), [], 'every custom property they read is --ocu-*');
  const offenders = filesUnder(join(uiRoot, 'src'), ['.ts', '.scss', '.css', '.html']).filter((path) => readFileSync(path, 'utf8').includes('--ite-'));
  assert.deepEqual(offenders, [], 'no file under ui/src names an --ite-* property');
});

// --- Story 19.8: the editors' parsers, the BIT toggle, a row's key and the staged changes ---------

const column = (kind, type, extra = {}) => ({ name: 'C', type, kind, nullable: true, key: false, ...extra });

// AC1. Mutation (Rule 19): send an integer through `Number()` in `parseCellInput` -> 2^53+1 reads
// 9007199254740992 and this goes red.
test('a number is staged exactly as typed: digits for a whole number, a decimal, an exponent only for DOUBLE', () => {
  const integer = column('number', 'bigint');
  assert.deepEqual(model.parseCellInput(integer, '9007199254740993'), { value: '9007199254740993' }, '2^53+1 kept as typed');
  assert.deepEqual(model.parseCellInput(integer, ' -42 '), { value: '-42' }, 'read trimmed, with its sign');
  for (const text of ['4.5', '1e3', '1,000', 'x', '+']) assert.deepEqual(model.parseCellInput(integer, text), { problem: STRINGS.explorerSqlDataHintInteger }, text);
  const numeric = column('number', 'numeric');
  assert.deepEqual(model.parseCellInput(numeric, '12345678901234567890.123456789'), { value: '12345678901234567890.123456789' });
  assert.deepEqual(model.parseCellInput(numeric, '.5'), { value: '.5' });
  assert.deepEqual(model.parseCellInput(numeric, '1e3'), { problem: STRINGS.explorerSqlDataHintNumber }, 'NUMERIC takes no exponent');
  assert.deepEqual(model.parseCellInput(numeric, '1,000.5'), { problem: STRINGS.explorerSqlDataHintNumber }, 'no comma stripping');
  assert.deepEqual(model.parseCellInput(column('number', 'double'), '-1.5E-7'), { value: '-1.5E-7' });
  assert.deepEqual(model.parseCellInput(column('number', 'double'), '1e'), { problem: STRINGS.explorerSqlDataHintNumber });
});

test('a date, a time and a timestamp are staged in the ODBC form, the day held to its month and the fraction kept', () => {
  const date = column('date', 'date');
  assert.deepEqual(model.parseCellInput(date, '2026-10-4'), { value: '2026-10-04' });
  assert.deepEqual(model.parseCellInput(date, '4-10-2026'), { value: '2026-10-04' }, 'D-M-YYYY');
  assert.deepEqual(model.parseCellInput(date, '10/4/2026'), { value: '2026-10-04' }, 'M/D/YYYY');
  assert.deepEqual(model.parseCellInput(date, '25/10/2026'), { value: '2026-10-25' }, 'D/M/YYYY when the first number is over 12');
  assert.deepEqual(model.parseCellInput(date, '2024-02-29'), { value: '2024-02-29' }, 'a leap day');
  for (const text of ['2026-02-31', '2025-02-29', '2026-13-01', '13/13/2026', 'Oct 4 2026', 'tomorrow']) assert.deepEqual(model.parseCellInput(date, text), { problem: STRINGS.explorerSqlDataHintDate }, `${text}: no new Date() fallback`);
  const time = column('time', 'time');
  assert.deepEqual(model.parseCellInput(time, '9:05'), { value: '09:05:00' });
  assert.deepEqual(model.parseCellInput(time, '14:30:00.125'), { value: '14:30:00.125' }, 'the fraction kept');
  assert.deepEqual(model.parseCellInput(time, '2:30 PM'), { value: '14:30:00' });
  assert.deepEqual(model.parseCellInput(time, '12:00:01 am'), { value: '00:00:01' });
  for (const text of ['24:00', '13:00 PM', '9:60', '9']) assert.deepEqual(model.parseCellInput(time, text), { problem: STRINGS.explorerSqlDataHintTime }, text);
  const stamp = column('timestamp', 'timestamp');
  assert.deepEqual(model.parseCellInput(stamp, '2026-10-04 14:30:00.123456'), { value: '2026-10-04 14:30:00.123456' }, 'the fraction kept');
  assert.deepEqual(model.parseCellInput(stamp, '2026-10-04T9:05'), { value: '2026-10-04 09:05:00' });
  assert.deepEqual(model.parseCellInput(stamp, '10/4/2026 2:30 PM'), { value: '2026-10-04 14:30:00' });
  assert.deepEqual(model.parseCellInput(stamp, '2026-10-04'), { value: '2026-10-04 00:00:00' }, 'a date alone is midnight');
  assert.deepEqual(model.parseCellInput(stamp, '2026-02-31 10:00'), { problem: STRINGS.explorerSqlDataHintTimestamp });
});

test('text is staged as typed; an empty entry of another kind is NULL where the column takes it; BIT toggles NULL, 1, 0', () => {
  assert.deepEqual(model.parseCellInput(column('text', 'varchar'), '  spaced  '), { value: '  spaced  ' });
  assert.deepEqual(model.parseCellInput(column('text', 'varchar'), ''), { value: '' }, 'an empty string, not NULL');
  assert.deepEqual(model.parseCellInput(column('date', 'date'), ' '), { value: null });
  assert.deepEqual(model.parseCellInput(column('date', 'date', { nullable: false }), ''), { problem: STRINGS.explorerSqlDataNotNull });
  assert.deepEqual(model.parseCellInput(column('boolean', 'bit'), STRINGS.tableStatusYes), { value: '1' });
  assert.equal(model.nextBoolean(null, true), '1');
  assert.equal(model.nextBoolean('1', true), '0');
  assert.equal(model.nextBoolean('0', true), null, 'back to NULL where the column takes it');
  assert.equal(model.nextBoolean('0', false), '1', 'else to 1');
});

test('a row key is its key columns in order; a save may change and set what is not a key, identity, generated, stream or binary column', () => {
  assert.equal(model.rowKey(['B', 'A'], { A: '1', B: 'x', C: 'z' }), '["x","1"]');
  assert.equal(model.rowKey(['A'], { A: null }), '[null]');
  const kinds = [column('text', 'varchar', { key: true }), column('text', 'varchar'), column('number', 'integer', { identity: true }), column('text', 'varchar', { generated: true }), column('stream', 'longvarchar'), column('binary', 'varbinary')];
  assert.deepEqual(kinds.map((entry) => `${model.editable(entry) ? 1 : 0}${model.insertable(entry) ? 1 : 0}`), ['01', '11', '00', '00', '00', '00']);
  assert.equal(model.isCut([[1, 7], [2, 9]], 2, 9), true);
  assert.equal(model.isCut([[1, 7]], 7, 1), false);
});

const COLUMNS = [
  { name: 'Code', type: 'varchar', kind: 'text', nullable: false, key: true },
  { name: 'Name', type: 'varchar', kind: 'text', nullable: true, key: false },
  { name: 'Seq', type: 'integer', kind: 'number', nullable: false, key: false, identity: true },
  { name: 'Memo', type: 'longvarchar', kind: 'stream', nullable: true, key: false },
];

function pageOf(...codes) {
  return codes.map((code) => [code, `name-${code}`, '7', 'memo']);
}

// AC6. Mutation (Rule 19): key `overlay` by the row's place on the page instead of its key -> the
// staged value follows position and this goes red.
test('a staged value shows on the row with the same key after the page moves, sorts or filters', () => {
  const staged = new model.StagedChanges();
  const first = pageOf('a', 'b', 'c');
  const rows = staged.overlay(['Code'], COLUMNS, first);
  assert.ok(staged.stage(rows[1].key, { Code: 'b' }, 'Name', 'name-b', 'renamed'));
  assert.equal(staged.count(), 1);
  const moved = staged.overlay(['Code'], COLUMNS, pageOf('z', 'y', 'b'));
  assert.deepEqual(moved.map((row) => row.cells[1]), ['name-z', 'name-y', 'renamed'], 'shown on b wherever it sits');
  assert.deepEqual(moved[2].staged, [false, true, false, false]);
  assert.deepEqual(moved[1].staged, [false, false, false, false], 'and on no row at the place b was read from');
  assert.ok(staged.stage(rows[1].key, { Code: 'b' }, 'Name', 'name-b', 'name-b'), 'committing the value read');
  assert.equal(staged.count(), 0, 'unstages the cell');
});

// AC3. Mutation (Rule 19): copy key columns in `duplicate` -> the copy carries Code and this goes red.
test('a duplicate copies the row but its key, identity, generated, stream, binary and cut cells; a new row is removed, a read one marked', () => {
  const staged = new model.StagedChanges();
  const id = staged.duplicate(COLUMNS, { Code: 'a', Name: 'name-a', Seq: '7', Memo: 'memo' }, (name) => name === 'Name');
  assert.deepEqual(staged.newRows(), [{ id, values: {}, outcome: null }], 'the cut Name is left out too');
  const second = staged.duplicate(COLUMNS, { Code: 'a', Name: 'name-a', Seq: '7', Memo: 'memo' }, () => false);
  assert.deepEqual(staged.newRows()[0], { id: second, values: { Name: 'name-a' }, outcome: null }, 'the newest first, its key left empty');
  staged.removeNew(id);
  assert.equal(staged.newRows().length, 1);
  assert.ok(staged.toggleDelete('["b"]', { Code: 'b' }));
  assert.equal(staged.isDeleted('["b"]'), true);
  assert.ok(staged.toggleDelete('["b"]', { Code: 'b' }));
  assert.equal(staged.isDeleted('["b"]'), false, 'Restore unmarks it');
});

test('the 101st staged row is refused, while a row already staged still takes more', () => {
  const staged = new model.StagedChanges();
  for (let at = 0; at < 100; at += 1) assert.ok(staged.stage(`["${at}"]`, { Code: String(at) }, 'Name', 'old', 'new'));
  assert.equal(staged.count(), model.MAX_STAGED_ROWS);
  assert.equal(staged.stage('["x"]', { Code: 'x' }, 'Name', 'old', 'new'), false, 'a 101st update');
  assert.equal(staged.addRow(), null, 'a 101st new row');
  assert.equal(staged.toggleDelete('["y"]', { Code: 'y' }), false, 'a 101st delete');
  assert.ok(staged.stage('["5"]', { Code: '5' }, 'Code', '5', 'k'), 'a staged row takes another column');
  assert.ok(staged.toggleDelete('["5"]', { Code: '5' }), 'and a delete');
  assert.equal(staged.discard(), 100);
  assert.equal(staged.count(), 0);
});

// AC5. Mutation (Rule 19): `applyResults` removes a failed insert -> the typed row goes and this goes
// red.
test('a failed insert stays staged with what was typed and its outcome until it is edited; kept outcomes go only when a save is applied', () => {
  const staged = new model.StagedChanges();
  staged.stage('["a"]', { Code: 'a' }, 'Name', 'name-a', 'A');
  const id = staged.addRow({ Code: 'a', Name: 'dup' });
  assert.ok(id !== null);
  staged.toWire();
  const { saved, failed } = staged.applyResults(
    [
      { index: 0, outcome: 'saved' },
      { index: 1, outcome: 'error', sqlcode: -119, message: 'dup' },
    ],
    ['Code']
  );
  assert.deepEqual([saved, failed], [1, 1]);
  assert.equal(staged.count(), 1, 'the failed insert is still staged');
  assert.deepEqual(staged.newRows(), [{ id, values: { Code: 'a', Name: 'dup' }, outcome: { outcome: 'error', sqlcode: -119, message: 'dup' } }]);
  assert.deepEqual(staged.toWire(), [{ op: 'insert', values: { Code: 'a', Name: 'dup' } }], 'and sent again with the next save');
  assert.equal(staged.overlay(['Code'], COLUMNS, pageOf('a'))[0].outcome?.outcome, 'saved', 'composing that save keeps the last outcomes');
  staged.setNew(id, 'Code', 'b');
  assert.equal(staged.newRows()[0].outcome, null, 'editing the row drops its reason');
  const stopped = staged.applyResults([{ index: 0, outcome: 'stopped', seconds: 2 }], ['Code']);
  assert.deepEqual([stopped.saved, stopped.failed], [0, 1]);
  assert.deepEqual(staged.newRows()[0].outcome, { outcome: 'stopped', sqlcode: null, message: '', seconds: 2 }, 'a stopped insert keeps its bound');
  assert.equal(staged.overlay(['Code'], COLUMNS, pageOf('a'))[0].outcome, null, 'and applying a save replaces the last outcomes');
});

// AC6. Mutation (Rule 19): `overlay` shows each outcome on the page row at its place among the
// outcomes instead of by key -> the outcome lands on the wrong row once the page moved and this goes red.
test('a save sends deletes, updates, then inserts with values; its answer applies by key after the page moved', () => {
  const staged = new model.StagedChanges();
  staged.stage('["a"]', { Code: 'a' }, 'Name', 'name-a', 'A');
  staged.stage('["b"]', { Code: 'b' }, 'Name', null, 'B');
  staged.toggleDelete('["c"]', { Code: 'c' });
  const empty = staged.addRow();
  const fresh = staged.addRow({ Code: 'n', Name: 'new' });
  assert.ok(empty !== null && fresh !== null);
  const wire = staged.toWire();
  assert.deepEqual(wire, [
    { op: 'delete', key: { Code: 'c' } },
    { op: 'update', key: { Code: 'a' }, original: { Name: 'name-a' }, values: { Name: 'A' } },
    { op: 'update', key: { Code: 'b' }, original: { Name: null }, values: { Name: 'B' } },
    { op: 'insert', values: { Code: 'n', Name: 'new' } },
  ]);
  const { saved, failed } = staged.applyResults(
    [
      { index: 0, outcome: 'gone' },
      { index: 1, outcome: 'saved' },
      { index: 2, outcome: 'changed' },
      { index: 3, outcome: 'saved' },
    ],
    ['Code']
  );
  assert.deepEqual([saved, failed], [2, 2]);
  assert.equal(staged.count(), 1, 'only the empty new row stays');
  const rows = staged.overlay(['Code'], COLUMNS, pageOf('n', 'c', 'b', 'a'));
  assert.deepEqual(
    rows.map((row) => `${row.cells[1]}|${row.outcome?.outcome ?? ''}|${row.deleted}`),
    ['name-n|saved|false', 'name-c|gone|false', 'name-b|changed|false', 'name-a|saved|false'],
    'each outcome on its own row, a failed update and delete rolled back to the values read'
  );
});

// --- Story 19.16: go to row, a page's CSV cells, the tab cap and the shortcuts -------------------

// AC5. Mutation (Rule 19): `goToRow` reads offset `n * size` -> row 237 reads offset 23,700 and this
// goes red.
test('go to row: row n is read at floor((n - 1) / size) * size, from 1 to the total, or to the furthest row the route reads while it is unknown', () => {
  assert.deepEqual(model.goToRow('237', 100, 340), { offset: 200, index: 36 });
  assert.deepEqual(model.goToRow(' 1 ', 100, 340), { offset: 0, index: 0 });
  assert.deepEqual(model.goToRow('100', 100, 340), { offset: 0, index: 99 });
  assert.deepEqual(model.goToRow('340', 100, 340), { offset: 300, index: 39 });
  assert.deepEqual(model.goToRow('101', 50, 340), { offset: 100, index: 0 });
  for (const text of ['0', '341', '1e3', '', ' ', '2.5', '-1', '+5', '1234567890', 'x']) assert.equal(model.goToRow(text, 100, 340), null, JSON.stringify(text));
  assert.deepEqual(model.goToRow('5000', 100, null), { offset: 4900, index: 99 }, 'any row while the total is unknown');
  assert.equal(model.goToRow('1', 100, 0), null, 'a total of 0 holds no row');
  assert.equal(model.rowRangeMax(340, 100), 340);
  assert.equal(model.rowRangeMax(null, 100), 100_000_000, 'the furthest page the route reads ends at its last row');
  assert.equal(model.rowRangeMax(150_000_000, 500), 100_000_000, 'never past the furthest page, total or not');
  for (const size of model.PAGE_SIZES) assert.ok(model.rowRangeMax(null, size) <= model.MAX_OFFSET + size, `size ${size}`);
  const furthest = model.goToRow('100000000', 100, null);
  assert.deepEqual(furthest, { offset: 99_999_900, index: 99 });
  assert.ok(furthest.offset <= model.MAX_OFFSET, 'the offset stays within the route');
  assert.equal(model.goToRow('100000001', 100, null), null);
  assert.equal(model.MAX_TABS, 8);
});

// AC1. Mutation (Rule 19): `pageCsvRows` writes NULL as the grid's "NULL" word -> this goes red.
test('a page writes as the grid shows it: NULL empty, BIT as the yes and no words, binary and a cut cell as answered, and csvText guards a formula', () => {
  const columns = [{ kind: 'text' }, { kind: 'boolean' }, { kind: 'number' }, { kind: 'stream' }, { kind: 'binary' }, { kind: 'date' }];
  const rows = [
    ['=1+1', '1', '12.5', 'cut text\u2026', '0x00FF', '2026-10-04'],
    [null, '0', null, '', null, null],
  ];
  const cells = model.pageCsvRows(columns, rows);
  assert.deepEqual(cells, [
    ['=1+1', STRINGS.tableStatusYes, '12.5', 'cut text\u2026', '0x00FF', '2026-10-04'],
    ['', STRINGS.tableStatusNo, '', '', '', ''],
  ]);
  assert.equal(
    csv.csvText(['Name', 'Flag', 'Num', 'Memo', 'Bin', 'Born'], cells),
    `\ufeffName,Flag,Num,Memo,Bin,Born\r\n'=1+1,${STRINGS.tableStatusYes},12.5,cut text\u2026,0x00FF,2026-10-04\r\n,${STRINGS.tableStatusNo},,,,\r\n`
  );
});

// DW-2061 (Story 19.9 AC5). Mutation (Rule 19): `pageCsvText` drops its kind check -> the text column's
// `-12.5` is written bare and this goes red.
test("a page's CSV writes a number column's cell bare only when the whole of it is a number; every other cell keeps the guard", () => {
  assert.equal(model.CSV_NUMBER.source, '^-?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:[eE][-+]?[0-9]+)?$', 'the ruled pattern');
  const columns = [
    { name: 'Num', kind: 'number' },
    { name: 'Text', kind: 'text' },
  ];
  const line = (num, text) => model.pageCsvText(columns, [[num, text]]).split('\r\n')[1];
  for (const bare of ['-12.5', '1e-3', '-.5', '.5', '1200', '0', '12.', '-1E+10']) assert.equal(line(bare, 'x'), `${bare},x`, `${bare} is written bare`);
  assert.equal(line('-1+1', 'x'), "'-1+1,x");
  assert.equal(line('-', 'x'), "'-,x");
  assert.equal(line('.', 'x'), '.,x', 'a lone . carries no guard character to add');
  assert.equal(line('+5', 'x'), "'+5,x");
  assert.equal(line('1,200', 'x'), '"1,200",x', 'a grouped number is quoted, not bare');
  assert.equal(line('x', '-12.5'), "x,'-12.5", 'a text column keeps the guard on a number');
  assert.equal(line('x', '=1+1'), "x,'=1+1");
  assert.equal(line(null, null), ',', 'NULL is empty');
  assert.equal(line('', 'x'), ',x');
});

// DW-2061. Mutation (Rule 19): `pageCsvText` ends its lines LF alone -> this goes red.
test("a page's CSV with no bare cell is csvText's file: the byte-order mark, CRLF, quoting and the guarded header", () => {
  const columns = [
    { name: '=Odd', kind: 'text' },
    { name: 'Num', kind: 'number' },
    { name: 'Flag', kind: 'boolean' },
  ];
  const rows = [
    ['a,b', '-1+1', '1'],
    ['say "hi"', null, '0'],
    ['line\nbreak', '+5', null],
  ];
  const text = model.pageCsvText(columns, rows);
  assert.equal(text, csv.csvText(columns.map((column) => column.name), model.pageCsvRows(columns, rows)));
  assert.ok(text.startsWith(`\ufeff'=Odd,Num,Flag\r\n`));
  assert.equal(csv.CSV_BOM, '\ufeff');
});

/** A key event as the matchers read it. */
const ev = (key, extra = {}) => ({ key, code: '', ctrlKey: false, metaKey: false, altKey: false, shiftKey: false, ...extra });

const PLACES = ['grid', 'tab', 'text', 'editor'];

/** Each action's chords, macOS's Option+Shift characters among them, the places it acts in, and the keys the help dialog names for them. */
const CHORDS = {
  help: { keys: 'Ctrl/Cmd+/', events: [ev('/', { ctrlKey: true }), ev('/', { metaKey: true }), ev('/', { ctrlKey: true, shiftKey: true })], places: ['grid', 'tab', 'text'] },
  save: { keys: 'Ctrl/Cmd+S', events: [ev('s', { ctrlKey: true }), ev('S', { metaKey: true })], places: ['grid', 'tab', 'text', 'editor'] },
  goToRow: { keys: 'Ctrl/Cmd+G', events: [ev('g', { ctrlKey: true }), ev('G', { metaKey: true })], places: ['grid', 'tab', 'text'] },
  export: { keys: 'Ctrl/Cmd+E', events: [ev('e', { ctrlKey: true }), ev('E', { metaKey: true })], places: ['grid', 'tab', 'text'] },
  addRow: { keys: 'Alt/Option+Shift+N', events: [ev('N', { altKey: true, shiftKey: true, code: 'KeyN' }), ev('\u02dc', { altKey: true, shiftKey: true, code: 'KeyN' }), ev('N', { altKey: true, shiftKey: true, code: 'KeyL' })], places: ['grid', 'tab'] },
  duplicateRow: { keys: 'Alt/Option+Shift+D', events: [ev('D', { altKey: true, shiftKey: true, code: 'KeyD' }), ev('\u00ce', { altKey: true, shiftKey: true, code: 'KeyD' })], places: ['grid', 'tab'] },
  deleteRow: { keys: 'Alt/Option+Shift+Delete or Backspace', events: [ev('Delete', { altKey: true, shiftKey: true }), ev('Backspace', { altKey: true, shiftKey: true })], places: ['grid', 'tab'] },
  page: { keys: 'Alt/Option+PageDown or PageUp', events: [ev('PageDown', { altKey: true }), ev('PageUp', { altKey: true })], places: ['grid', 'tab'] },
  tab: { keys: 'Alt/Option+Shift+PageDown or PageUp', events: [ev('PageDown', { altKey: true, shiftKey: true }), ev('PageUp', { altKey: true, shiftKey: true })], places: ['grid', 'tab'] },
  closeTab: { keys: 'Alt/Option+Shift+W, or Delete on a tab', events: [ev('W', { altKey: true, shiftKey: true, code: 'KeyW' }), ev('\u201e', { altKey: true, shiftKey: true, code: 'KeyW' })], places: ['grid', 'tab'] },
};

test('every shortcut row matches its chords in each place it acts and nowhere else; Delete closes only a focused tab', () => {
  assert.deepEqual(model.DATA_BROWSER_SHORTCUTS.map((row) => row.action).sort(), Object.keys(CHORDS).sort());
  for (const [action, { events, places }] of Object.entries(CHORDS)) {
    for (const event of events) {
      for (const place of PLACES) {
        assert.equal(model.shortcutFor(event, place), places.includes(place) ? action : null, `${action}: ${JSON.stringify(event)} in ${place}`);
      }
    }
  }
  assert.equal(model.shortcutFor(ev('Delete'), 'tab'), 'closeTab', 'Delete on a focused tab closes it');
  for (const place of ['grid', 'text', 'editor']) assert.equal(model.shortcutFor(ev('Delete'), place), null, `Delete stays the grid's own in ${place}`);
  assert.equal(model.shortcutStep(ev('PageDown', { altKey: true })), 1);
  assert.equal(model.shortcutStep(ev('PageUp', { altKey: true, shiftKey: true })), -1);
});

// AC3. Mutation (Rule 19): `shortcutFor` drops the Alt-in-text exclusion -> each Alt/Option row acts in
// a text field and this goes red.
test('an Alt/Option chord does nothing in a text field, where it types its character, and with an editor open only Save acts', () => {
  const optionRows = Object.entries(CHORDS).filter(([, { events }]) => events.every((event) => event.altKey));
  assert.equal(optionRows.length, 6, 'the Alt/Option family');
  for (const [action, { events }] of optionRows) {
    for (const event of events) assert.equal(model.shortcutFor(event, 'text'), null, `${action} in a text field`);
  }
  for (const [action, { events }] of Object.entries(CHORDS)) {
    for (const event of events) assert.equal(model.shortcutFor(event, 'editor'), action === 'save' ? 'save' : null, `${action} with an editor open`);
  }
});

// AC3. Mutation (Rule 19): `optionShiftLetter` matches the physical key whatever the key reads ->
// Dvorak's KeyN, which Chrome reads as Alt+Shift+B, adds a row and this goes red.
test("no row matches a chord the browser reserves, a zoom or reload chord, the shell's Ctrl/Cmd+K, I or B, Chrome's Alt+Shift A, B, R or T, or a single character", () => {
  const never = [ev('F5'), ev('F5', { shiftKey: true })];
  for (const control of [{ ctrlKey: true }, { metaKey: true }]) {
    for (const key of ['n', 'w', 't', 'r', 'k', 'i', 'b', '=', '-', '0', '+', 'F4', 'Tab', 'PageDown', 'PageUp']) never.push(ev(key, control));
    for (const key of ['N', 'T', 'W', 'K', 'I', 'B', 'Tab', 'PageDown', 'PageUp']) never.push(ev(key, { ...control, shiftKey: true }));
  }
  for (const letter of ['A', 'B', 'R', 'T']) {
    never.push(ev(letter, { altKey: true, shiftKey: true, code: `Key${letter}` }));
    // Another layout's letter on a physical key a row names: Dvorak's KeyN types B.
    for (const physical of ['N', 'D', 'W']) never.push(ev(letter, { altKey: true, shiftKey: true, code: `Key${physical}` }));
  }
  for (let code = 0x20; code < 0x7f; code += 1) {
    const character = String.fromCharCode(code);
    never.push(ev(character), ev(character, { shiftKey: true }));
  }
  for (const event of never) {
    for (const place of PLACES) assert.equal(model.shortcutFor(event, place), null, `${JSON.stringify(event)} in ${place}`);
  }
  assert.ok(never.length > 200, `the chords checked: ${never.length}`);
});

test('each action appears in exactly one row, with a label and keys the string source holds', () => {
  const actions = model.DATA_BROWSER_SHORTCUTS.map((row) => row.action);
  assert.equal(actions.length, 10);
  assert.equal(new Set(actions).size, actions.length);
  for (const row of model.DATA_BROWSER_SHORTCUTS) {
    assert.ok(typeof STRINGS[row.labelKey] === 'string' && STRINGS[row.labelKey] !== '', `${row.action}'s label`);
    assert.ok(typeof STRINGS[row.keysKey] === 'string' && STRINGS[row.keysKey] !== '', `${row.action}'s keys`);
    assert.equal(STRINGS[row.keysKey], CHORDS[row.action].keys, `${row.action}'s keys name the chords its matcher binds`);
  }
});

// Mutation (Rule 19): the shared chooser always taking the plural template -> every singular leg goes red.
test('the count sentences read singular at exactly 1 and plural at 0 and 2 (DW-2092)', () => {
  assert.equal(model.waitingText(1), '1 change waiting to be saved.');
  assert.equal(model.waitingText(0), '0 changes waiting to be saved.');
  assert.equal(model.waitingText(2), '2 changes waiting to be saved.');
  assert.equal(model.discardedText(1), '1 change discarded.');
  assert.equal(model.discardedText(0), '0 changes discarded.');
  assert.equal(model.discardedText(2), '2 changes discarded.');
  assert.equal(model.savedSummaryText(1, 1, 0), 'Saved 1 of 1 change; 0 rolled back.');
  assert.equal(model.savedSummaryText(0, 1, 1), 'Saved 0 of 1 change; 1 rolled back.');
  assert.equal(model.savedSummaryText(2, 2, 0), 'Saved 2 of 2 changes; 0 rolled back.');
  assert.equal(model.savedSummaryText(0, 0, 0), 'Saved 0 of 0 changes; 0 rolled back.');
  assert.equal(model.saveConsequenceText({ update: 1, insert: 1, delete: 1 }, 'T'), '1 row changes, 1 is added and 1 is deleted in T, and this cannot be undone from OcuPilot.');
  assert.equal(model.saveConsequenceText({ update: 2, insert: 0, delete: 0 }, 'T'), '2 rows change, 0 are added and 0 are deleted in T, and this cannot be undone from OcuPilot.');
  assert.equal(model.saveConsequenceText({ update: 0, insert: 2, delete: 1 }, 'T'), '0 rows change, 2 are added and 1 is deleted in T, and this cannot be undone from OcuPilot.');
  assert.equal(model.saveConsequenceText({ update: 1, insert: 0, delete: 2 }, 'T'), '1 row changes, 0 are added and 2 are deleted in T, and this cannot be undone from OcuPilot.');
});

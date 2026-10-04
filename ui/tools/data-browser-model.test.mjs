import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins Data browser's pure rules (`core/data-browser-model.ts`, Story 19.7): the tri-state sort, the
// grid's cell moves over the header row, offset paging, how a cell reads, a column's track, which
// kinds take a filter, and the status lines; and the token rule over its styles -- every custom
// property the `ocu-data-browser` rules read is one of OcuPilot's own, and the harvest's `--ite-*`
// palette appears nowhere under `ui/src`.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const core = (name) => join(uiRoot, 'src', 'app', 'core', name);

const model = await import(core('data-browser-model.ts'));
const { STRINGS } = await import(core('strings.ts'));

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

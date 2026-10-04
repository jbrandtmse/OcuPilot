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

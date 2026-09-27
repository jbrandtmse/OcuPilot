import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the CSV encoder the data table saves its view through (`core/csv.ts`, Story 16.23): the
// formula guard, RFC 4180 quoting, the file's BOM and line ends, the declared-columns-only rows,
// the empty and pending cells, and the file name. One case per I/O-matrix row the encoder decides;
// the browser-only rows are `browser/csv-download.browser-spec.mjs`'s.

// A zone away from UTC, so the file name's local-time fields differ from the UTC ones (CI runs in UTC).
process.env.TZ = 'America/Los_Angeles';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const core = (name) => join(uiRoot, 'src', 'app', 'core', name);

const csv = await import(core('csv.ts'));
const { STRINGS, stringFor } = await import(core('strings.ts'));

const COLUMNS = [
  { field: 'Name', labelKey: 'fieldUserName', kind: 'name' },
  { field: 'Enabled', labelKey: 'serverFlagLive', kind: 'status' },
  { field: 'Note', labelKey: 'statusSegmentServer', kind: 'text' },
];

/** A minimal RFC 4180 reader: records of fields, quoted fields unquoted, CRLF between records. */
function parse(text) {
  const records = [];
  let record = [];
  let field = '';
  let quoted = false;
  for (let at = 0; at < text.length; at += 1) {
    const ch = text[at];
    if (quoted) {
      if (ch === '"' && text[at + 1] === '"') {
        field += '"';
        at += 1;
      } else if (ch === '"') quoted = false;
      else field += ch;
    } else if (ch === '"') quoted = true;
    else if (ch === ',') {
      record.push(field);
      field = '';
    } else if (ch === '\r' && text[at + 1] === '\n') {
      record.push(field);
      records.push(record);
      record = [];
      field = '';
      at += 1;
    } else field += ch;
  }
  return records;
}

test('the formula guard prefixes = + - @ tab and CR with an apostrophe, and leaves an inner = alone', () => {
  assert.equal(csv.csvField('=1+1'), "'=1+1");
  assert.equal(csv.csvField('+x'), "'+x");
  assert.equal(csv.csvField('-5'), "'-5");
  assert.equal(csv.csvField('@a'), "'@a");
  assert.equal(csv.csvField('\tx'), "'\tx");
  assert.equal(csv.csvField('\rx'), `"'\rx"`, 'a guarded CR is still quoted');
  assert.equal(csv.csvField('a=b'), 'a=b');
});

test('RFC 4180 quoting: a comma, a quote or a line break is quoted, with inner quotes doubled', () => {
  assert.equal(csv.csvField('a,b'), '"a,b"');
  assert.equal(csv.csvField('say "hi"'), '"say ""hi"""');
  assert.equal(csv.csvField('l1\nl2'), '"l1\nl2"');
  assert.equal(csv.csvField('plain'), 'plain');
  assert.equal(csv.csvField(''), '');
});

test('a quoted field round-trips through an RFC 4180 read', () => {
  const cells = ['a,b', 'say "hi"', 'l1\nl2', 'l1\r\nl2', '=1+1'];
  const text = csv.csvText(['h1', 'h2', 'h3', 'h4', 'h5'], [cells]);
  const [header, row] = parse(text.slice(1));
  assert.deepEqual(header, ['h1', 'h2', 'h3', 'h4', 'h5']);
  assert.deepEqual(row, ['a,b', 'say "hi"', 'l1\nl2', 'l1\r\nl2', "'=1+1"]);
});

test('the file starts with the BOM and ends every line with CRLF; zero rows is the header alone', () => {
  assert.equal(csv.CSV_BOM, '\ufeff');
  assert.equal(csv.csvText(['Name', 'Note'], [['a', 'b']]), '\ufeffName,Note\r\na,b\r\n');
  assert.equal(csv.csvText(['Name', 'Note'], []), '\ufeffName,Note\r\n', 'header row only');
});

test('only the declared columns are written, in column order: a withheld field never reaches the file', () => {
  const rows = [{ Password: 'secret', Note: 'n', Enabled: true, Name: '/csp/a', Extra: 'extra-value' }];
  const cells = csv.tableCsvRows(rows, COLUMNS, stringFor);
  assert.deepEqual(cells, [['/csp/a', STRINGS.tableStatusYes, 'n']]);
  const text = csv.csvText(['a', 'b', 'c'], cells);
  assert.ok(!text.includes('secret') && !text.includes('extra-value'), 'no undeclared field is written');
});

test('a cell is what the table displays: "(none)" written empty, an emptyKey word, a pending column empty', () => {
  const columns = [...COLUMNS, { field: 'Mode', labelKey: 'fieldUserName', kind: 'text', emptyKey: 'tableStatusNo' }];
  const rows = [
    { Name: '', Enabled: false, Note: null, Mode: '' },
    { Name: 'b', Enabled: true, Note: 'kept', Mode: 'x' },
  ];
  assert.deepEqual(csv.tableCsvRows(rows, columns, stringFor), [
    ['', STRINGS.tableStatusNo, '', STRINGS.tableStatusNo],
    ['b', STRINGS.tableStatusYes, 'kept', 'x'],
  ]);
  assert.deepEqual(csv.tableCsvRows(rows, columns, stringFor, ['Note']), [
    ['', STRINGS.tableStatusNo, '', STRINGS.tableStatusNo],
    ['b', STRINGS.tableStatusYes, '', 'x'],
  ], 'a column still pending is written empty on every row');
});

test('the name is the label slug plus the local date and time; a label with no ASCII letters is "table"', () => {
  const at = new Date(2026, 8, 7, 5, 4, 3);
  assert.notEqual(at.getTimezoneOffset(), 0, 'the test runs away from UTC, so a UTC name would differ');
  assert.equal(csv.csvFileName('Web applications', at), 'web-applications-20260907-050403.csv');
  assert.equal(csv.csvFileName('  SQL -- Tables / Views!  ', at), 'sql-tables-views-20260907-050403.csv');
  assert.equal(csv.csvFileName('', at), 'table-20260907-050403.csv');
  assert.equal(csv.csvFileName('\u00e9\u00e8 \u2014 ?', at), 'table-20260907-050403.csv');
});

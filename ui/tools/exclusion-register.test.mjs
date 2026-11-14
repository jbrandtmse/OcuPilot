import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins `docs/exclusion-register.md` to the two planning documents it restates:
//
// - the feature catalog: the register's IDs are exactly the rows whose Tier column reads P4;
// - the stage extract: the register's groups hold exactly the members of the extract's Stage 5
//   groups, under the wording the epics give those groups (matched by position, since the extract
//   and the epics list the groups in the same order).
//
// Both sides of every equality are read from the documents; no row-set ID or count is typed here. Nothing
// calls an instance, so the test needs only the checkout. A document that parses to nothing fails
// naming itself, never as a pass over an empty set.

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const PLANNING = join(REPO_ROOT, '_bmad-output', 'planning-artifacts');
const REGISTER_PATH = join(REPO_ROOT, 'docs', 'exclusion-register.md');
const CATALOG_PATH = join(
  PLANNING,
  'research',
  'technical-ocupilot-portal-feature-landscape-2026-09-08',
  'feature-catalog.md'
);
const EXTRACT_PATH = join(PLANNING, 'prds', 'prd-OcuPilot-2026-09-08', 'extract-stages.md');
const EPICS_PATH = join(PLANNING, 'epics.md');

const ROW_RE = /^\| [A-Z]{2}-\d+ \|/;
const EM_DASH = '\u2014';
const GROUP_LINE_RE = new RegExp(`^\\*\\*(.+)\\*\\* ${EM_DASH} (\\d+) rows?$`);
const ISO_DATE_RE = /\b\d{4}-\d{2}-\d{2}\b/;
const REGISTER_COLUMNS = ['ID', 'Feature', 'Reason', 'Gate kind', 'Gate', 'How to tell it has cleared'];

/** The trimmed cells of one Markdown table line; `\|` stays inside its cell. */
function cellsOf(line) {
  return line
    .trim()
    .replace(/^\|/, '')
    .replace(/\|$/, '')
    .split(/(?<!\\)\|/)
    .map((cell) => cell.trim());
}

function linesOf(path) {
  return readFileSync(path, 'utf8').split('\n');
}

/** Every catalog row as `{ id, tier }`, reading the Tier column by the name its header gives it. */
function parseCatalog() {
  const rows = [];
  let tierIndex = -1;
  let width = 0;
  let sawTierColumn = false;
  for (const line of linesOf(CATALOG_PATH)) {
    if (line.startsWith('| ID |')) {
      const header = cellsOf(line);
      tierIndex = header.indexOf('Tier');
      width = header.length;
      sawTierColumn = sawTierColumn || tierIndex >= 0;
      continue;
    }
    if (!ROW_RE.test(line)) continue;
    const cells = cellsOf(line);
    assert.ok(tierIndex >= 0, `${CATALOG_PATH}: row ${cells[0]} has no header with a Tier column above it`);
    assert.equal(cells.length, width, `${CATALOG_PATH}: row ${cells[0]} has ${cells.length} cells, its header ${width}`);
    rows.push({ id: cells[0], tier: cells[tierIndex] });
  }
  assert.ok(sawTierColumn, `${CATALOG_PATH}: no table header names a Tier column`);
  return rows;
}

/** The extract's Stage 5 groups as `{ name, declared, ids }`, in document order. */
function parseExtractGroups() {
  const lines = linesOf(EXTRACT_PATH);
  const start = lines.findIndex((line) => line.startsWith('### Stage 5'));
  assert.ok(start >= 0, `${EXTRACT_PATH}: no '### Stage 5' heading`);
  const groups = [];
  for (let i = start + 1; i < lines.length && !lines[i].startsWith('### '); i += 1) {
    const heading = GROUP_LINE_RE.exec(lines[i]);
    if (heading !== null) {
      groups.push({ name: heading[1], declared: Number(heading[2]), ids: [] });
    } else if (groups.length > 0 && ROW_RE.test(lines[i])) {
      groups[groups.length - 1].ids.push(cellsOf(lines[i])[0]);
    }
  }
  return groups;
}

/** The group wording Story 22.1's first acceptance criterion gives, in order, without its leading 'and '. */
function parseEpicsGroupWording() {
  const lines = linesOf(EPICS_PATH);
  const story = lines.findIndex((line) => line.startsWith('### Story 22.1:'));
  assert.ok(story >= 0, `${EPICS_PATH}: no '### Story 22.1:' heading`);
  const marker = 'grouped as the catalog groups them:';
  for (let i = story + 1; i < lines.length && !lines[i].startsWith('### '); i += 1) {
    const at = lines[i].indexOf(marker);
    if (at < 0) continue;
    return lines[i]
      .slice(at + marker.length)
      .replace(/\.\s*$/, '')
      .split(';')
      .map((phrase) => phrase.trim().replace(/^and /, ''));
  }
  throw new Error(`${EPICS_PATH}: Story 22.1 no longer says '${marker}'`);
}

/** The register's gate-kind vocabulary and its groups as `{ heading, rows }`, in document order. */
function parseRegister() {
  const lines = linesOf(REGISTER_PATH);
  const kindsAt = lines.indexOf('## Gate kinds');
  const registerAt = lines.indexOf('## The register');
  assert.ok(kindsAt >= 0, `${REGISTER_PATH}: no '## Gate kinds' heading`);
  assert.ok(registerAt > kindsAt, `${REGISTER_PATH}: no '## The register' heading after '## Gate kinds'`);

  const kinds = new Set();
  for (const line of lines.slice(kindsAt + 1, registerAt)) {
    const cell = line.startsWith('|') ? cellsOf(line)[0] : '';
    const match = /^`([a-z-]+)`$/.exec(cell);
    if (match !== null) kinds.add(match[1]);
  }

  const groups = [];
  for (const line of lines.slice(registerAt + 1)) {
    if (line.startsWith('### ')) {
      groups.push({ heading: line.slice(4).trim(), rows: [] });
    } else if (line.startsWith('| ID |')) {
      assert.deepEqual(cellsOf(line), REGISTER_COLUMNS, `${REGISTER_PATH}: a group table header is not ${REGISTER_COLUMNS.join(' | ')}`);
    } else if (ROW_RE.test(line)) {
      assert.ok(groups.length > 0, `${REGISTER_PATH}: a row appears before the first '###' group heading`);
      const cells = cellsOf(line);
      assert.equal(cells.length, REGISTER_COLUMNS.length, `${REGISTER_PATH}: row ${cells[0]} has ${cells.length} cells`);
      const [id, feature, reason, kind, gate, tell] = cells;
      groups[groups.length - 1].rows.push({ id, feature, reason, kind: kind.replace(/^`|`$/g, ''), gate, tell });
    }
  }
  return { kinds, groups };
}

function sorted(values) {
  return [...values].sort();
}

function registerRows(register) {
  return register.groups.flatMap((group) => group.rows);
}

test('the parsers read something from every document', () => {
  const catalog = parseCatalog();
  assert.ok(catalog.some((row) => row.tier === 'P4'), `${CATALOG_PATH}: no row has tier P4`);
  const extract = parseExtractGroups();
  assert.ok(extract.length > 0, `${EXTRACT_PATH}: Stage 5 yields no groups`);
  for (const group of extract) {
    assert.ok(group.ids.length > 0, `${EXTRACT_PATH}: group '${group.name}' yields no rows`);
  }
  const wording = parseEpicsGroupWording();
  assert.ok(wording.length > 0, `${EPICS_PATH}: Story 22.1 yields no groups`);
  const register = parseRegister();
  assert.ok(register.kinds.size > 0, `${REGISTER_PATH}: the Gate kinds table yields no kinds`);
  assert.ok(register.groups.length > 0, `${REGISTER_PATH}: no group headings under '## The register'`);
  assert.ok(registerRows(register).length > 0, `${REGISTER_PATH}: no rows`);
});

test('the extract declares the row counts it lists', () => {
  for (const group of parseExtractGroups()) {
    assert.equal(group.ids.length, group.declared, `${EXTRACT_PATH}: group '${group.name}' says ${group.declared} rows and lists ${group.ids.length}`);
  }
});

test('the register holds exactly the catalog P4 rows, each once', () => {
  const p4 = parseCatalog().filter((row) => row.tier === 'P4').map((row) => row.id);
  assert.ok(p4.length > 0, `${CATALOG_PATH}: no row has tier P4`);
  const registerIds = registerRows(parseRegister()).map((row) => row.id);

  const duplicated = sorted(new Set(registerIds.filter((id, at) => registerIds.indexOf(id) !== at)));
  assert.deepEqual(duplicated, [], `${REGISTER_PATH}: listed more than once: ${duplicated.join(', ')}`);

  const missing = sorted(p4.filter((id) => !registerIds.includes(id)));
  const extra = sorted(registerIds.filter((id) => !p4.includes(id)));
  assert.deepEqual(
    { missing, extra },
    { missing: [], extra: [] },
    `${REGISTER_PATH}: missing P4 rows [${missing.join(', ')}]; rows that are not P4 [${extra.join(', ')}]`
  );
});

test("the extract's Stage 5 rows are the catalog's P4 rows", () => {
  const extractIds = parseExtractGroups().flatMap((group) => group.ids);
  const p4 = parseCatalog().filter((row) => row.tier === 'P4').map((row) => row.id);
  assert.deepEqual(sorted(extractIds), sorted(p4), `${EXTRACT_PATH}: Stage 5 rows differ from the catalog's P4 rows`);
});

test('each register group holds exactly the extract group of the same position, under the epics wording', () => {
  const extract = parseExtractGroups();
  const wording = parseEpicsGroupWording();
  const register = parseRegister();
  assert.equal(wording.length, extract.length, `${EPICS_PATH} gives ${wording.length} groups, the extract ${extract.length}`);
  assert.equal(register.groups.length, extract.length, `${REGISTER_PATH} has ${register.groups.length} groups, the extract ${extract.length}`);
  extract.forEach((group, at) => {
    const heading = register.groups[at].heading;
    assert.equal(
      heading.toLowerCase(),
      wording[at].toLowerCase(),
      `${REGISTER_PATH}: group ${at + 1} is headed '${heading}', the epics word it '${wording[at]}'`
    );
    const actual = sorted(register.groups[at].rows.map((row) => row.id));
    const expected = sorted(group.ids);
    assert.deepEqual(
      actual,
      expected,
      `extract group '${group.name}' differs from register group '${heading}': extract-only [${expected.filter((id) => !actual.includes(id)).join(', ')}], register-only [${actual.filter((id) => !expected.includes(id)).join(', ')}]`
    );
  });
});

test('every row carries a reason, a gate and a way to tell it has cleared', () => {
  const problems = [];
  for (const row of registerRows(parseRegister())) {
    for (const field of ['feature', 'reason', 'gate', 'tell']) {
      if (row[field] === '') problems.push(`${row.id}: empty ${field}`);
    }
  }
  assert.deepEqual(problems, [], `${REGISTER_PATH}: ${problems.join('; ')}`);
});

test('every row names a gate kind from the Gate kinds table', () => {
  const register = parseRegister();
  const problems = registerRows(register)
    .filter((row) => !register.kinds.has(row.kind))
    .map((row) => `${row.id}: '${row.kind}'`);
  assert.deepEqual(problems, [], `${REGISTER_PATH}: kind not in the Gate kinds table (${[...register.kinds].join(', ')}): ${problems.join('; ')}`);
});

test('a license, edition or platform gate names a runnable check, and what slot B read on which day', () => {
  const problems = [];
  const checked = new Set();
  for (const row of registerRows(parseRegister())) {
    if (!['license', 'edition', 'platform'].includes(row.kind)) continue;
    checked.add(row.kind);
    if (!/`[^`]+` (returns|is)\b/.test(row.tell)) problems.push(`${row.id}: no backticked check followed by what it returns`);
    if (!/evaluates it/i.test(row.tell)) problems.push(`${row.id}: does not say where the vendor evaluates it`);
    if (!/slot B read \S+/i.test(row.tell)) problems.push(`${row.id}: does not say what slot B read`);
    if (!ISO_DATE_RE.test(row.tell)) problems.push(`${row.id}: no observation date`);
  }
  assert.deepEqual(problems, [], `${REGISTER_PATH}: ${problems.join('; ')}`);
  // Floor: a kind that no row carries any more would otherwise pass this test over an empty set.
  assert.deepEqual(sorted(checked), ['edition', 'license', 'platform'], `${REGISTER_PATH}: no row carries one of the kinds this test checks; read [${sorted(checked).join(', ')}]`);
});

test('a deprecation gate names the deprecated feature and the owner decision that clears it', () => {
  const deprecated = registerRows(parseRegister()).filter((row) => row.kind === 'deprecation');
  assert.ok(deprecated.length > 0, `${REGISTER_PATH}: no row carries the deprecation kind, so this test would check nothing`);
  const problems = deprecated
    .filter((row) => !(/deprecated feature is \S/i.test(row.gate) && /owner decision/i.test(`${row.gate} ${row.tell}`)))
    .map((row) => `${row.id}: does not name the deprecated feature and the owner decision`);
  assert.deepEqual(problems, [], `${REGISTER_PATH}: ${problems.join('; ')}`);
});

test('a judgment gate says what evidence clears it', () => {
  const judged = registerRows(parseRegister()).filter((row) => ['demand', 'vendor-page', 'dependency', 'not-applicable'].includes(row.kind));
  const problems = [];
  const kinds = new Set();
  for (const row of judged) {
    kinds.add(row.kind);
    if (row.kind === 'demand') {
      if (!row.tell.includes(`A request names ${row.id}`)) problems.push(`${row.id}: does not say a request naming the row clears it`);
    } else if (!/\.$/.test(row.tell) || row.tell.split(/\s+/).length < 5) {
      problems.push(`${row.id}: does not say in a sentence what evidence clears it`);
    }
  }
  assert.deepEqual(problems, [], `${REGISTER_PATH}: ${problems.join('; ')}`);
  // Floor: a kind that no row carries any more would otherwise pass this test over an empty set.
  assert.deepEqual(sorted(kinds), ['demand', 'dependency', 'not-applicable', 'vendor-page'], `${REGISTER_PATH}: no row carries one of the judgment kinds; read [${sorted(kinds).join(', ')}]`);
});

test('AN-23 says the three analytics links ship and that rebuilding stays excluded', () => {
  const row = registerRows(parseRegister()).find((candidate) => candidate.id === 'AN-23');
  assert.ok(row, `${REGISTER_PATH}: no AN-23 row`);
  assert.match(row.reason, /Architect, Analyzer and User Portal links ship/, `${REGISTER_PATH}: AN-23 does not say the three links ship`);
  assert.match(row.reason, /Story 20\.32/, `${REGISTER_PATH}: AN-23 does not name the story that delivered the links`);
  assert.match(row.reason, /Rebuilding them stays excluded/, `${REGISTER_PATH}: AN-23 does not say rebuilding stays excluded`);
});

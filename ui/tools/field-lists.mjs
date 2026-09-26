#!/usr/bin/env node
/**
 * Joins the derived write-payload field lists with the reviewed per-tool classification entries
 * and generates `src/OcuPilot/Screen/Tool/ToolFields.cls` (AD-3, AD-5).
 *
 * **Two committed inputs, one committed output.** `FieldLists.cls` (`XData Lists`) is generated
 * on an instance by `scripts/field-lists.sh`; `Classification.cls` (`XData Entries`) is written
 * by hand and reviewed. Classification is a pure function of the two, so it runs here, in
 * `prebuild` and in CI's `gates` job, with no instance.
 *
 * **It fails closed and emits nothing on any refusal.** A classifiable row (one no other row's
 * path extends) that its entry does not name is `secret`. An entry is refused when it names a
 * list or path the derived lists lack, uses a key outside the entry grammar, gives a reserved key
 * (`required`, `enum`, `description`) any content, a class outside
 * `ordinary`/`secret`/`opaque`, `opaque` on a literal, `ordinary` on a member-less object or
 * array, or a tool name that is not `<area>.<screen>.<verb>`. A string literal whose last path
 * segment matches the credential pattern (Conventions, Secrets) classified anything but `secret`
 * is refused; a boolean or number never is.
 *
 * **An entry may author a wrapper field** (`authored`, AD-3): a top-level name the endpoint's
 * request wrapper carries and its template does not -- `Security.User`'s POST `Password` -- mapped
 * to `secret`, the only class accepted. It is emitted as its own `secret` literal row marked
 * `authored: true`. A name that is not one top-level segment, or that collides with a derived
 * path, is refused.
 *
 * **An entry may declare how the read-back compares a field** (`compare`, AD-3, AD-58): a
 * top-level row of its list mapped to one mode of a closed vocabulary (`COMPARE_MODES`). Every
 * field row under that name is emitted with the mode. A member of an `unordered` array's elements
 * (`Top[].Member`, a literal row) may carry a text mode of its own (`TEXT_MODES`), emitted on that
 * row alone. It refuses an unknown mode, a path that is neither of those, a mode on a `secret`
 * path, `unordered` on a non-array, `members` on a non-object, and a text mode on a row that is
 * not a literal.
 *
 * Usage: `node tools/field-lists.mjs` writes `ToolFields.cls`; `--check` reports and exits 1 on
 * a refusal or when the committed file differs from what would be written.
 */

import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, join } from 'node:path';

import { extractXData } from './screen-mirror.mjs';
import { CREDENTIAL_EXACT_NAMES, CREDENTIAL_EXCEPTIONS, CREDENTIAL_RE, CREDENTIAL_SUFFIXES, isCredentialName, lastSegment } from './credential-pattern.mjs';

// Re-exported so the pattern has one home (`credential-pattern.mjs`) while
// `credential-lists.test.mjs` keeps reading it here, beside the classifier it governs.
export { CREDENTIAL_EXACT_NAMES, CREDENTIAL_EXCEPTIONS, CREDENTIAL_RE, CREDENTIAL_SUFFIXES, lastSegment };

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const TOOL_DIR = join(REPO_ROOT, 'src', 'OcuPilot', 'Screen', 'Tool');

export const FIELD_LISTS_SOURCE = join(TOOL_DIR, 'FieldLists.cls');
export const CLASSIFICATION_SOURCE = join(TOOL_DIR, 'Classification.cls');
export const TOOL_FIELDS_PATH = join(TOOL_DIR, 'ToolFields.cls');

/** The three classifications a derived field may carry. */
export const CLASSES = ['ordinary', 'secret', 'opaque'];

/** What a classifiable row with no entry is emitted as. */
export const DEFAULT_CLASS = 'secret';

/** The keys an entry may carry. */
export const ENTRY_KEYS = ['fieldList', 'classification', 'authored', 'compare', 'required', 'enum', 'description'];

/** The closed vocabulary of read-back comparison modes an entry's `compare` may declare (AD-58). */
export const COMPARE_MODES = ['unordered', 'unslashed', 'words', 'letters', 'members', 'written'];

/** The modes that compare one text value, the only ones an element member may declare. */
export const TEXT_MODES = ['unslashed', 'words', 'letters'];

/** A top-level row's path: one segment, no member and no element. */
const TOP_LEVEL_RE = /^[A-Za-z0-9_%]+$/;

/** An element member's path: `Top[].Member`, one member of one array's elements. */
const ELEMENT_MEMBER_RE = /^([A-Za-z0-9_%]+)\[\]\.([A-Za-z0-9_%]+)$/;

/** The top-level name a field-row path sits under: `Resources[].Name` answers `Resources`. */
export function topName(path) {
  return path.split('.')[0].split('[')[0];
}

/** The one class an authored wrapper field may carry. */
export const AUTHORED_CLASS = 'secret';

/** An authored field's name: one top-level segment, no member and no element. */
const AUTHORED_NAME_RE = /^[A-Za-z][A-Za-z0-9]*$/;

/** The keys reserved for the semantic half of a schema; until that half is defined, only empty. */
export const RESERVED_KEYS = ['required', 'enum', 'description'];

function isEmptyValue(value) {
  if (Array.isArray(value)) return value.length === 0;
  if (value !== null && typeof value === 'object') return Object.keys(value).length === 0;
  return value === '';
}

/** `<area>.<screen>.<verb>`, lower case, dots only (Conventions, Tool naming). */
export const TOOL_NAME_RE = /^[a-z][a-z0-9]*\.[a-z][a-z0-9]*\.[a-z][a-z0-9]*$/;

const SHAPES = ['literal', 'object', 'array'];
const SOURCES = ['template', 'class', 'none'];
const LITERAL_TYPES = ['string', 'number', 'boolean', 'null'];
const LIST_KEYS = ['endpoint', 'source', 'method', 'class', 'type', 'envelope', 'rows'];
const ROW_KEYS = ['path', 'shape', 'templateType', 'itemType'];

/**
 * The two keys a class-derived metadata row may add (Story 12.5): the member's `kind`, and a
 * `VALUELIST` member's allowed `values`. Only a `class` list carries them, and `values` only beside
 * a `kind`.
 */
const ROW_KIND_KEYS = ['kind', 'values'];

/** The kinds a metadata member may carry. */
export const MEMBER_KINDS = ['uri', 'text', 'list', 'integer', 'flag', 'json'];
const PATH_RE = /^[A-Za-z0-9_%]+(\[\])*(\.[A-Za-z0-9_%]+(\[\])*)*$/;

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function sameKeys(value, keys) {
  const present = Object.keys(value).sort();
  const wanted = [...keys].sort();
  return present.length === wanted.length && present.every((key, index) => key === wanted[index]);
}

/** The JSON body of `XData <name>` in `text`, parsed; throws naming `path` when absent or invalid. */
export function parseBlock(text, name, path) {
  const body = extractXData(text, name);
  if (body === null) throw new Error(`${path}: carries no 'XData ${name}' block`);
  try {
    return JSON.parse(body);
  } catch (error) {
    throw new Error(`${path}: 'XData ${name}' is not valid JSON -- ${error.message}`);
  }
}

/** Both committed inputs, parsed. */
export function readSources() {
  return {
    lists: parseBlock(readFileSync(FIELD_LISTS_SOURCE, 'utf8'), 'Lists', FIELD_LISTS_SOURCE),
    entries: parseBlock(readFileSync(CLASSIFICATION_SOURCE, 'utf8'), 'Entries', CLASSIFICATION_SOURCE),
  };
}

/** Whether `other` extends `path`: a member (`path.x`) or element (`path[]`) below it. */
function extends_(other, path) {
  return other.startsWith(`${path}.`) || other.startsWith(`${path}[]`);
}

/** The rows of `rows` no other row's path extends, in row order. */
export function classifiableRows(rows) {
  return rows.filter((row) => !rows.some((other) => other !== row && extends_(other.path, row.path)));
}

/** Whether a derived row is a credential by name: a string literal whose last segment matches. */
export function isCredential(row) {
  return row.shape === 'literal' && row.templateType === 'string' && isCredentialName(row.path);
}

/** Every well-formedness problem in the derived lists, as strings naming the list and path. */
export function checkLists(lists) {
  const problems = [];
  if (!isObject(lists)) return ['FieldLists.cls: XData Lists is not a JSON object'];
  if (Object.keys(lists).length === 0) return ['FieldLists.cls: XData Lists holds no list'];
  for (const [key, list] of Object.entries(lists)) {
    if (!isObject(list) || !sameKeys(list, LIST_KEYS)) {
      problems.push(`FieldLists.cls: list ${key} does not carry exactly ${LIST_KEYS.join(', ')}`);
      continue;
    }
    const scalars = LIST_KEYS.filter((name) => name !== 'rows');
    if (scalars.some((name) => typeof list[name] !== 'string') || !Array.isArray(list.rows)) {
      problems.push(`FieldLists.cls: list ${key} has a field of the wrong type`);
      continue;
    }
    if (!SOURCES.includes(list.source)) {
      problems.push(`FieldLists.cls: list ${key} has source "${list.source}"`);
      continue;
    }
    const expectedKey = list.source === 'class' ? `${list.endpoint}:${list.class}` : list.endpoint;
    if (list.endpoint === '' || key !== expectedKey) {
      problems.push(`FieldLists.cls: list ${key} should be keyed ${expectedKey}`);
    }
    if (list.source === 'template' && (list.method === '' || list.class !== '')) {
      problems.push(`FieldLists.cls: template list ${key} names no method, or names a class`);
    }
    if (list.source === 'class' && (list.class === '' || list.method !== '')) {
      problems.push(`FieldLists.cls: class-derived list ${key} names no class, or names a method`);
    }
    if (list.source === 'none' && (list.rows.length > 0 || list.method !== '' || list.class !== '')) {
      problems.push(`FieldLists.cls: list ${key} needs no template and carries rows, a method or a class`);
    }
    const shapes = new Map();
    for (const row of list.rows) {
      const base = isObject(row) ? Object.fromEntries(Object.entries(row).filter(([name]) => !ROW_KIND_KEYS.includes(name))) : row;
      if (!isObject(row) || !sameKeys(base, ROW_KEYS) || ROW_KEYS.some((name) => typeof row[name] !== 'string')) {
        problems.push(`FieldLists.cls: list ${key} has a row that is not exactly ${ROW_KEYS.join(', ')} strings`);
        continue;
      }
      if ('kind' in row || 'values' in row) {
        const kindOk = list.source === 'class' && MEMBER_KINDS.includes(row.kind);
        const valuesOk =
          !('values' in row) ||
          (Array.isArray(row.values) && row.values.length > 0 && row.values.every((value) => typeof value === 'string' && value !== ''));
        if (!kindOk || !valuesOk) {
          problems.push(`FieldLists.cls: list ${key} path ${row.path} carries a kind or values a class-derived member cannot`);
        }
      }
      if (!PATH_RE.test(row.path)) problems.push(`FieldLists.cls: list ${key} path "${row.path}" is not a path`);
      if (shapes.has(row.path)) problems.push(`FieldLists.cls: list ${key} path ${row.path} appears twice`);
      if (!SHAPES.includes(row.shape)) problems.push(`FieldLists.cls: list ${key} path ${row.path} has shape "${row.shape}"`);
      const typeOk =
        row.shape === 'literal' ? LITERAL_TYPES.includes(row.templateType) && row.itemType === '' : row.templateType === row.shape;
      const itemOk =
        row.shape !== 'array' || row.itemType === '' || [...LITERAL_TYPES, 'object', 'array'].includes(row.itemType);
      if (!typeOk || !itemOk) {
        problems.push(`FieldLists.cls: list ${key} path ${row.path} has types "${row.templateType}"/"${row.itemType}" for shape ${row.shape}`);
      }
      shapes.set(row.path, row.shape);
    }
    for (const row of list.rows) {
      if (!isObject(row) || typeof row.path !== 'string') continue;
      let parent = null;
      let wanted = null;
      if (row.path.endsWith('[]')) {
        parent = row.path.slice(0, -2);
        wanted = 'array';
      } else if (row.path.includes('.')) {
        parent = row.path.slice(0, row.path.lastIndexOf('.'));
        wanted = 'object';
      }
      if (parent !== null && shapes.get(parent) !== wanted) {
        problems.push(`FieldLists.cls: list ${key} path ${row.path} has no ${wanted} row ${parent} above it`);
      }
    }
  }
  return problems;
}

/**
 * Classify every entry against the derived lists. Returns `{tools, problems}`: `tools` maps each
 * accepted tool name to `{fieldList, fields}`, `fields` being its classifiable rows each with a
 * `class`; `problems` names the tool and path of every refusal.
 */
export function classify(lists, entries) {
  const problems = [];
  const tools = {};
  if (!isObject(entries)) return { tools, problems: ['Classification.cls: XData Entries is not a JSON object'] };
  for (const [tool, entry] of Object.entries(entries)) {
    const before = problems.length;
    const refuse = (message) => problems.push(`${tool}: ${message}`);
    if (!TOOL_NAME_RE.test(tool)) refuse('the tool name is not <area>.<screen>.<verb> in lower case');
    if (!isObject(entry)) {
      refuse('the entry is not a JSON object');
      continue;
    }
    for (const key of Object.keys(entry)) {
      if (!ENTRY_KEYS.includes(key)) refuse(`key "${key}" is outside the entry grammar (${ENTRY_KEYS.join(', ')})`);
      else if (RESERVED_KEYS.includes(key) && !isEmptyValue(entry[key])) refuse(`key "${key}" is reserved and carries no content yet`);
    }
    const list = typeof entry.fieldList === 'string' && isObject(lists) ? lists[entry.fieldList] : undefined;
    if (typeof entry.fieldList !== 'string' || !isObject(list) || !Array.isArray(list.rows)) {
      refuse(`fieldList ${JSON.stringify(entry.fieldList)} is not a list FieldLists.cls carries`);
      continue;
    }
    if (!isObject(entry.classification)) {
      refuse('classification is not a JSON object of path to class');
      continue;
    }
    const rows = list.rows;
    const classifiable = classifiableRows(rows);
    for (const [path, value] of Object.entries(entry.classification)) {
      const row = rows.find((candidate) => candidate.path === path);
      if (row === undefined) {
        refuse(`path ${path} is not in list ${entry.fieldList}`);
        continue;
      }
      if (!classifiable.includes(row)) {
        refuse(`path ${path} is not classifiable; a row below it in list ${entry.fieldList} is`);
        continue;
      }
      if (!CLASSES.includes(value)) {
        refuse(`path ${path} is classified ${JSON.stringify(value)}, not one of ${CLASSES.join(', ')}`);
        continue;
      }
      if (value === 'opaque' && row.shape === 'literal') refuse(`path ${path} is a literal and cannot be opaque`);
      if (value === 'ordinary' && row.shape !== 'literal') {
        refuse(`path ${path} is a member-less ${row.shape} and cannot be ordinary`);
      }
    }
    const fields = classifiable.map((row) => {
      const assigned = entry.classification[row.path];
      const value = CLASSES.includes(assigned) ? assigned : DEFAULT_CLASS;
      if (isCredential(row) && value !== 'secret') {
        refuse(`path ${row.path} is a string whose name matches the credential pattern and is classified ${value}; it must be secret`);
      }
      return { ...row, class: value };
    });
    if (entry.authored !== undefined) {
      if (!isObject(entry.authored)) {
        refuse('authored is not a JSON object of name to class');
      } else {
        for (const [name, value] of Object.entries(entry.authored)) {
          if (!AUTHORED_NAME_RE.test(name)) {
            refuse(`authored name ${JSON.stringify(name)} is not one top-level field name`);
            continue;
          }
          if (rows.some((row) => row.path === name || extends_(row.path, name))) {
            refuse(`authored name ${name} collides with a derived path of list ${entry.fieldList}`);
            continue;
          }
          if (value !== AUTHORED_CLASS) {
            refuse(`authored name ${name} is classified ${JSON.stringify(value)}; an authored field may only be ${AUTHORED_CLASS}`);
            continue;
          }
          fields.push({ path: name, shape: 'literal', templateType: 'string', class: AUTHORED_CLASS, authored: true });
        }
      }
    }
    if (entry.compare !== undefined) {
      if (!isObject(entry.compare)) {
        refuse('compare is not a JSON object of path to mode');
      } else {
        for (const [path, mode] of Object.entries(entry.compare)) {
          if (!COMPARE_MODES.includes(mode)) {
            refuse(`compare mode ${JSON.stringify(mode)} on ${path} is not one of ${COMPARE_MODES.join(', ')}`);
            continue;
          }
          const element = ELEMENT_MEMBER_RE.exec(path);
          if (element !== null) {
            const member = fields.find((field) => field.path === path);
            if (member === undefined || member.shape !== 'literal') {
              refuse(`compare path ${path} is not a literal element-member row of list ${entry.fieldList}`);
            } else if (member.class === 'secret') {
              refuse(`compare path ${path} is secret, and a secret is never read back`);
            } else if (!TEXT_MODES.includes(mode)) {
              refuse(`compare path ${path} is an element member and may only be ${TEXT_MODES.join(', ')}`);
            } else if (entry.compare[element[1]] !== 'unordered') {
              refuse(`compare path ${path} is an element member of ${element[1]}, which is not declared unordered`);
            }
            continue;
          }
          const row = TOP_LEVEL_RE.test(path) ? rows.find((candidate) => candidate.path === path) : undefined;
          if (row === undefined) {
            refuse(`compare path ${path} is not a top-level row of list ${entry.fieldList}`);
            continue;
          }
          if (fields.some((field) => topName(field.path) === path && field.class === 'secret')) {
            refuse(`compare path ${path} is secret, and a secret is never read back`);
            continue;
          }
          if (mode === 'unordered' && row.shape !== 'array') refuse(`compare path ${path} is a ${row.shape} and cannot be unordered`);
          if (mode === 'members' && row.shape !== 'object') refuse(`compare path ${path} is a ${row.shape} and cannot be members`);
          if (TEXT_MODES.includes(mode) && row.shape !== 'literal') refuse(`compare path ${path} is a ${row.shape} and cannot be ${mode}`);
        }
        if (problems.length === before) {
          for (const field of fields) {
            const mode = entry.compare[field.path] ?? entry.compare[topName(field.path)];
            if (mode !== undefined && field.authored !== true) field.compare = mode;
          }
        }
      }
    }
    if (problems.length === before) tools[tool] = { fieldList: entry.fieldList, fields };
  }
  return { tools, problems };
}

const HEADER = `/// <p>GENERATED FILE -- DO NOT EDIT. Every write tool's classified input fields (AD-3): each
/// classifiable row of the field list its reviewed entry names, with its class. Written by
/// <file>ui/tools/field-lists.mjs</file> from <class>OcuPilot.Screen.Tool.FieldLists</class> and
/// <class>OcuPilot.Screen.Tool.Classification</class>; edit the entry and regenerate.</p>
/// <p>Regenerate: <code>cd ui &amp;&amp; node tools/field-lists.mjs</code>. Drift check: the same
/// command with <code>--check</code>, which <code>prebuild</code> runs.</p>
`;

/** The source of `ToolFields.cls` for `tools`, keyed and ordered by tool name. */
export function buildToolFields(tools) {
  const names = Object.keys(tools).sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));
  const entries = names.map((name) => {
    const { fieldList, fields } = tools[name];
    const rows = fields.map((field) =>
      JSON.stringify(
        field.authored === true
          ? {
              path: field.path,
              shape: field.shape,
              templateType: field.templateType,
              class: field.class,
              authored: true,
            }
          : {
              path: field.path,
              shape: field.shape,
              templateType: field.templateType,
              itemType: field.itemType,
              class: field.class,
              ...(field.compare === undefined ? {} : { compare: field.compare }),
            }
      )
    );
    const head = `${JSON.stringify(name)}: {"fieldList":${JSON.stringify(fieldList)},"fields":[`;
    return rows.length === 0 ? `${head}]}` : `${head}\n  ${rows.join(',\n  ')}\n]}`;
  });
  const body = entries.length === 0 ? '' : `${entries.join(',\n')}\n`;
  return `${HEADER}Class OcuPilot.Screen.Tool.ToolFields Extends %RegisteredObject
{

XData Tools
{
{
${body}}
}

}
`;
}

/** `{text, problems, census}` for the given inputs: `text` is `null` whenever `problems` is non-empty. */
export function generateFrom({ lists, entries }) {
  const problems = checkLists(lists);
  const { tools, problems: refusals } = classify(lists, entries);
  problems.push(...refusals);
  const listCount = isObject(lists) ? Object.keys(lists).length : 0;
  const rowCount = isObject(lists)
    ? Object.values(lists).reduce((sum, list) => sum + (Array.isArray(list?.rows) ? list.rows.length : 0), 0)
    : 0;
  const entryCount = isObject(entries) ? Object.keys(entries).length : 0;
  const census = `${listCount} list(s), ${rowCount} row(s), ${entryCount} classification entry(ies)`;
  return { text: problems.length === 0 ? buildToolFields(tools) : null, problems, census };
}

/** What this repository's committed inputs produce right now. */
export function generate() {
  return generateFrom(readSources());
}

function main() {
  const args = process.argv.slice(2);
  const unknown = args.filter((arg) => arg !== '--check');
  if (unknown.length > 0) {
    console.error(`field-lists: unknown argument ${unknown[0]}`);
    process.exitCode = 2;
    return;
  }
  let result;
  try {
    result = generate();
  } catch (error) {
    console.error(`field-lists: ${error.message}`);
    process.exitCode = 1;
    return;
  }
  if (result.problems.length > 0) {
    for (const problem of result.problems) console.error(`field-lists: ${problem}`);
    console.error(`field-lists: ${result.problems.length} refusal(s) over ${result.census}; nothing emitted`);
    process.exitCode = 1;
    return;
  }
  if (args.includes('--check')) {
    if (readFileSync(TOOL_FIELDS_PATH, 'utf8') !== result.text) {
      console.error('field-lists: src/OcuPilot/Screen/Tool/ToolFields.cls is stale -- run node tools/field-lists.mjs');
      process.exitCode = 1;
      return;
    }
    console.log(`field-lists: up to date; classified ${result.census}.`);
    return;
  }
  writeFileSync(TOOL_FIELDS_PATH, result.text);
  console.log(`field-lists: wrote src/OcuPilot/Screen/Tool/ToolFields.cls from ${result.census}`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main();
}

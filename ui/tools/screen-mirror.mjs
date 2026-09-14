#!/usr/bin/env node
/**
 * Generates `ui/src/app/core/screens.generated.ts` -- the client's mirror of every screen
 * descriptor and of the area vocabulary (AD-5).
 *
 * **One source, two readers.** The server reads each `XData` block through
 * `%Dictionary.XDataDefinition`; this reads the same blocks off disk. The mirror is therefore
 * derived from the declaration rather than transcribed beside it, and
 * `ui/tools/screen-mirror.test.mjs` fails when the checked-in file and this generator's output
 * disagree. "Generated" means a checked-in artifact, never runtime reflection and never a
 * second hand-written source (AD-3's rule applied to AD-5).
 *
 * **It runs on the repository, not in the container**, which has no source mount -- so a class
 * method could not write the file even if one wanted to.
 *
 * **It refuses an entity type the kernel enum does not hold** (AD-14), naming the file and the
 * value, which is the second of the three places that value fails the build:
 * `scripts/check-objectscript.py` refuses it in the tree, this refuses to emit it, and
 * `OcuPilot.Screen.Registry.Validate` refuses it on the instance. A declared `scope` outside
 * `OcuPilot.Kernel.Scope`'s two values (AD-13) fails the build the same three ways.
 *
 * **It refuses a read or a table outside the declared grammar** (AD-36, `readProblem`), naming the
 * file and the class, as `OcuPilot.Screen.Registry.ReadProblem` refuses it on the instance.
 *
 * **It refuses an archetype outside `OcuPilot.Screen.Archetype`'s closed vocabulary** (AD-44),
 * which is what gives "only a detail view may declare a classic link-out" a predicate to
 * evaluate: without a closed vocabulary a typo answers "not a detail view" and passes. The
 * link-out rule itself is `ui/tools/classic-links.mjs`'s and
 * `OcuPilot.Screen.Registry.ClassicLinkProblem`'s; this only refuses to emit a key the
 * vocabulary does not hold, and emits the vocabulary as the `ArchetypeKey` union. The archetypes
 * of `built: true` screens are emitted as `BuiltArchetypeKey`, which `ui/src/app/shell/
 * screen-outlet.ts` requires a page for, so a built screen with no page fails `ng build`.
 *
 * Usage: `node tools/screen-mirror.mjs` writes the mirror; `--check` only reports drift.
 */

import { readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, join } from 'node:path';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

export const AREA_SOURCE = join(REPO_ROOT, 'src', 'OcuPilot', 'Screen', 'Area.cls');
export const ARCHETYPE_SOURCE = join(REPO_ROOT, 'src', 'OcuPilot', 'Screen', 'Archetype.cls');
export const DESCRIPTOR_DIR = join(REPO_ROOT, 'src', 'OcuPilot', 'Screen', 'Descriptor');
export const ENTITY_TYPE_SOURCE = join(REPO_ROOT, 'src', 'OcuPilot', 'Kernel', 'EntityType.cls');
export const SCOPE_SOURCE = join(REPO_ROOT, 'src', 'OcuPilot', 'Kernel', 'Scope.cls');
export const MIRROR_PATH = join(REPO_ROOT, 'ui', 'src', 'app', 'core', 'screens.generated.ts');

/** The abstract base lives in the descriptor package and declares no screen. */
const BASE_FILE = 'Base.cls';

const CLASS_RE = /^Class\s+([A-Za-z0-9_.%]+)/m;
const XDATA_RE = /^XData\s+([A-Za-z0-9_%]+)/;
const TYPES_PARAM_RE = /^Parameter\s+TYPES\s*=\s*"([^"]*)"\s*;/m;
const SCOPE_PARAM_RE = /^Parameter\s+(SCOPEINSTANCE|SCOPENAMESPACE)\s*=\s*"([^"]*)"\s*;/gm;

/**
 * How far `line` moves brace depth: `{` counts +1 and `}` counts -1, but only outside a
 * double-quoted span. A backslash inside a span skips the next character, and span state resets
 * at the end of the line.
 *
 * `brace_delta` in `scripts/check-objectscript.py` applies the same rule to the same blocks, so
 * the two readers agree on where a block ends. JSON strings cannot span lines, so the reset
 * cannot miss a JSON brace; a stray quote in an XML block cannot hide a closing brace that sits
 * on a line of its own.
 */
export function braceDelta(line) {
  let delta = 0;
  let inString = false;
  for (let index = 0; index < line.length; index += 1) {
    const ch = line[index];
    if (inString) {
      if (ch === '\\') index += 1;
      else if (ch === '"') inString = false;
      continue;
    }
    if (ch === '"') inString = true;
    else if (ch === '{') delta += 1;
    else if (ch === '}') delta -= 1;
  }
  return delta;
}

/**
 * The body of the named `XData` block, or `null`.
 *
 * The UDL convention this tree follows puts the opening brace on the line after the `XData`
 * declaration and the closing brace on a line of its own, which is what the three-state walk
 * below assumes -- the same assumption `scripts/check-objectscript.py` makes about the same
 * blocks, with the same `braceDelta` rule, so the two readers cannot disagree about where a
 * block starts and ends.
 */
export function extractXData(text, name) {
  let state = null;
  let depth = 0;
  let body = [];

  for (const raw of text.split('\n')) {
    if (state === null) {
      const match = XDATA_RE.exec(raw.trim());
      if (match && match[1] === name) state = 'awaiting-open';
      continue;
    }
    if (state === 'awaiting-open') {
      if (!raw.includes('{')) continue;
      depth = braceDelta(raw);
      if (depth > 0) {
        state = 'inside';
        body = [];
      } else {
        state = null;
      }
      continue;
    }
    depth += braceDelta(raw);
    if (depth <= 0) return body.join('\n');
    body.push(raw);
  }
  return null;
}

/** The declared class name of a `.cls` source. */
export function extractClassName(text) {
  const match = CLASS_RE.exec(text);
  return match === null ? null : match[1];
}

/** The closed entity-type vocabulary, from the kernel's own `TYPES` parameter. */
export function parseEntityTypes(text) {
  const match = TYPES_PARAM_RE.exec(text);
  if (match === null) return null;
  return match[1]
    .split(',')
    .map((value) => value.trim())
    .filter((value) => value !== '');
}

/**
 * The two words a descriptor's `scope` may spell -- `OcuPilot.Kernel.Scope`'s own
 * `SCOPEINSTANCE` and `SCOPENAMESPACE` parameter values, read rather than duplicated as a
 * literal pair here, so this reader and `OcuPilot.Screen.Registry.Validate` (which reads the
 * same two class parameters directly) cannot drift apart on what the two spellings are. `null`
 * when either parameter is missing, the same "reported, not read as empty or admitting
 * everything" discipline `parseEntityTypes` follows for `EntityType.cls`.
 */
export function parseScopeWords(text) {
  const found = {};
  for (const match of text.matchAll(SCOPE_PARAM_RE)) {
    found[match[1]] = match[2];
  }
  if (found.SCOPEINSTANCE === undefined || found.SCOPENAMESPACE === undefined) return null;
  return [found.SCOPEINSTANCE, found.SCOPENAMESPACE];
}

/**
 * The closed archetype vocabulary, from `OcuPilot.Screen.Archetype`'s own `XData Archetypes`
 * block: `[{key, linkOut}, ...]` in declaration order, or `null` when the block is missing,
 * unparseable, or not the shape it declares.
 *
 * `null` rather than `[]`, and every caller reports it rather than carrying on: an empty
 * vocabulary would make every declared archetype unknown and an absent check would make every
 * declared archetype fine, and neither is a negative result. The same discipline
 * `parseEntityTypes` and `parseScopeWords` follow for their own sources.
 */
export function parseArchetypes(text) {
  const body = extractXData(text, 'Archetypes');
  if (body === null) return null;
  let parsed;
  try {
    parsed = JSON.parse(body);
  } catch {
    return null;
  }
  if (parsed === null || typeof parsed !== 'object' || !Array.isArray(parsed.archetypes)) return null;
  const archetypes = [];
  for (const entry of parsed.archetypes) {
    if (entry === null || typeof entry !== 'object') return null;
    if (typeof entry.key !== 'string' || entry.key === '') return null;
    if (typeof entry.linkOut !== 'string' || entry.linkOut === '') return null;
    archetypes.push({ key: entry.key, linkOut: entry.linkOut });
  }
  return archetypes.length === 0 ? null : archetypes;
}

/** Every entity type a declaration names: the primary first, then the secondaries. */
export function entityTypesIn(declaration) {
  const named = [];
  if (typeof declaration.entityType === 'string' && declaration.entityType !== '') {
    named.push(declaration.entityType);
  }
  for (const value of declaration.secondaryEntityTypes ?? []) {
    if (typeof value === 'string' && value !== '') named.push(value);
  }
  return named;
}

/**
 * `JSON.parse(body)`, or a throw naming `path` and the parser's own message. A block that is
 * valid UDL but invalid JSON is found by `extractXData`, so the parse is where it fails, and a
 * bare `SyntaxError` names no file.
 */
function parseXDataJson(body, path, name) {
  try {
    return JSON.parse(body);
  } catch (error) {
    throw new Error(`${path}: 'XData ${name}' is not valid JSON -- ${error.message}`);
  }
}

/**
 * Reads the three sources and returns the parsed declarations, in a deterministic order:
 * areas by rail position, screens by descriptor class name. A generator whose output depends
 * on directory order would fail its own drift check on another machine.
 *
 * `descriptorDir` and `areaSource` default to the repository's own descriptor package and
 * `Area.cls`; a caller checking a synthetic tree passes its own. A descriptor or area block that
 * does not parse throws naming its `.cls` path.
 */
export function readSources({ descriptorDir = DESCRIPTOR_DIR, areaSource = AREA_SOURCE } = {}) {
  const entityTypes = parseEntityTypes(readFileSync(ENTITY_TYPE_SOURCE, 'utf8'));
  if (entityTypes === null) {
    throw new Error(`${ENTITY_TYPE_SOURCE} declares no 'Parameter TYPES'`);
  }

  const scopeWords = parseScopeWords(readFileSync(SCOPE_SOURCE, 'utf8'));
  if (scopeWords === null) {
    throw new Error(`${SCOPE_SOURCE} declares no 'Parameter SCOPEINSTANCE'/'SCOPENAMESPACE' pair`);
  }

  const archetypes = parseArchetypes(readFileSync(ARCHETYPE_SOURCE, 'utf8'));
  if (archetypes === null) {
    throw new Error(`${ARCHETYPE_SOURCE} carries no readable 'XData Archetypes' block`);
  }

  const areaText = readFileSync(areaSource, 'utf8');
  const areaBody = extractXData(areaText, 'Areas');
  if (areaBody === null) throw new Error(`${areaSource} carries no 'XData Areas' block`);
  const areas = parseXDataJson(areaBody, areaSource, 'Areas')
    .areas.slice()
    .sort((a, b) => a.railPosition - b.railPosition);

  const screens = [];
  for (const entry of readdirSync(descriptorDir).sort()) {
    if (!entry.endsWith('.cls') || entry === BASE_FILE) continue;
    const path = join(descriptorDir, entry);
    const text = readFileSync(path, 'utf8');
    const className = extractClassName(text);
    const body = extractXData(text, 'Declaration');
    if (body === null) throw new Error(`${path} carries no 'XData Declaration' block`);
    screens.push({ file: entry, className, declaration: parseXDataJson(body, path, 'Declaration') });
  }
  screens.sort((a, b) => (a.className < b.className ? -1 : a.className > b.className ? 1 : 0));

  return { entityTypes, scopeWords, archetypes, areas, screens };
}

/**
 * The 1-based position of the first entry in `privileges` missing a resource or a permission,
 * as `#n`, or `null` when every entry carries both. An entry that is not an object counts as
 * malformed too.
 */
export function malformedPair(privileges) {
  if (!Array.isArray(privileges)) return null;
  for (let index = 0; index < privileges.length; index += 1) {
    const pair = privileges[index];
    const bad =
      pair === null ||
      typeof pair !== 'object' ||
      typeof pair.resource !== 'string' ||
      pair.resource === '' ||
      typeof pair.permission !== 'string' ||
      pair.permission === '';
    if (bad) return `#${index + 1}`;
  }
  return null;
}

/**
 * The mirror's TypeScript source. Throws, naming the file and the value, when a declaration
 * uses an entity type outside `entityTypes`, a `scope` outside `scopeWords` (AD-13) -- the
 * refusal AD-14's mechanism asks the build for -- or when a declared privilege pair is missing
 * a half.
 *
 * **Why a malformed pair is a build refusal and not a runtime concern.** Both readers of a
 * `privileges` array drop an entry missing either half rather than carrying it
 * (`OcuPilot.Screen.Area.PairsFrom`), so a declaration that misspells `permission` as
 * `permissions` collapses to an empty set -- and an empty set is satisfied by every caller
 * (AD-8). The declaration reads as a gate and produces none. `OcuPilot.Screen.Registry.Validate`
 * refuses it for a descriptor, but nothing on the serving path calls `Validate`, and no rule
 * anywhere read `XData Areas` at all: `check-objectscript.py`'s entity-type rule reads
 * `XData Declaration` only. Refusing it here means the bad declaration never reaches a running
 * instance, which is where Epic 1's gating actually lives -- every area's screen list is empty
 * until Epic 2, so the area sets are the whole gate.
 *
 * `scope` is checked only when a screen declares one (a non-empty string): a fixture built to
 * exercise the privilege-pair refusal above declares no `scope` at all, and treating an absent
 * field as a refusal would fail a declaration for a value it never made.
 */
/**
 * What is wrong with a declared refresh pair, or `null` when nothing is (AD-43).
 *
 * The five rules `OcuPilot.Screen.Registry.RefreshProblem` applies on the instance, applied here
 * so a malformed declaration fails a developer's build rather than a container's start. The
 * install refusal makes the start hook exit 1 (AD-38); this is the gate before that one, and the
 * entity-type and scope refusals above already work the same way.
 *
 * **This is the stricter of the two, deliberately, on the one rule JSON can express and
 * ObjectScript cannot.** `"10"` and `10` are one value in ObjectScript -- `$IsValidNum("10")` is
 * 1 -- so `RefreshProblem` accepts a JSON *string* rate (verified live 2026-09-13), while
 * `Number.isInteger` here refuses it. The gate that refuses is the one that runs before anything
 * renders, so the direction is safe; do not "reconcile" it by loosening this one.
 *
 * An omitted pair is sound: a descriptor written before the fields existed declares neither and
 * reads as a screen the framework binds nothing for.
 */
export function refreshProblem(declaration) {
  const { refreshes, refreshRates } = declaration;
  if (refreshRates !== undefined && !Array.isArray(refreshRates)) {
    return `refreshRates is ${JSON.stringify(refreshRates)}, which is not a list of rates (AD-43)`;
  }
  const rates = refreshRates ?? [];
  if (refreshes !== true) {
    if (rates.length === 0) return null;
    return (
      `refreshRates declares ${rates.length} rate(s) while refreshes is not true; a screen ` +
      `that does not refresh permits none (AD-43)`
    );
  }
  if (rates.length === 0) {
    return 'refreshes is true but refreshRates is empty; a refreshing screen declares the rates its chip may set (AD-43)';
  }
  let previous = 0;
  for (const rate of rates) {
    if (!Number.isInteger(rate) || rate <= 0) {
      return `refreshRates entry ${JSON.stringify(rate)} is not a whole number of seconds above zero (AD-43)`;
    }
    if (rate <= previous) {
      return `refreshRates entry ${rate} does not ascend from ${previous}; the chip advances through them in order (AD-43)`;
    }
    previous = rate;
  }
  return null;
}

/** The tool-identifier shape a read-declaring descriptor carries (Conventions, Tool naming). */
export const READ_TOOL_IDENTIFIER_RE = /^[a-z][a-z0-9]*\.[a-z][a-z0-9]*$/;

const ENDPOINT_RE = /^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*$/;

/** A refusal naming the first key of `object` outside `allowed`, or `null`. */
function unknownKeyProblem(where, object, allowed) {
  const unknown = Object.keys(object).find((key) => !allowed.includes(key));
  return unknown === undefined ? null : `${where} declares the unknown key '${unknown}'`;
}

/**
 * What is wrong with `list` as an array of unique field names, each in `allowed` when given, or
 * `null`.
 */
function nameListProblem(where, list, allowed) {
  if (!Array.isArray(list)) return `${where} is not an array of field names`;
  const seen = new Set();
  for (let index = 0; index < list.length; index += 1) {
    const name = list[index];
    if (typeof name !== 'string' || name === '') return `${where} entry #${index + 1} is not a field name`;
    if (seen.has(name)) return `${where} names '${name}' twice`;
    if (allowed !== undefined && !allowed.includes(name)) return `${where} names '${name}', which is not one of read.fields`;
    seen.add(name);
  }
  return null;
}

/**
 * What is wrong with a declaration's `read`, or `null` when nothing is (AD-36).
 *
 * The rules `OcuPilot.Screen.Registry.ReadProblem` applies on the instance: an absent or `null`
 * read is a screen with no read; otherwise `source` is `{port: "admin", endpoint, type: "LIST"}`,
 * `fields` is non-empty and unique, `filter`, `sort.fields` and `context.secretFields` name only
 * declared fields, no secret field is filterable or sortable, `sort.default` is a sort field,
 * `sort.direction` is `asc` or `desc`, `paging` is `cap` (no admin LIST accepts a cursor), and the
 * `toolIdentifier` is `<area>.<screen>` in lower case. `read`, `read.source`, `read.sort` and
 * `context` carry only their declared keys, and `context.secretFields` is declared, so a misspelt
 * key is refused rather than read as no secret field. `read.source.rowGet` is `rowGetProblem`'s. A
 * read declares its table (`tableProblem`), and a table with no read is refused.
 */
export function readProblem(declaration) {
  const { read } = declaration;
  if (read === undefined || read === null) {
    const { table } = declaration;
    if (table !== undefined && table !== null) {
      return "table is declared while read is not, and a table renders a declared read's rows (AD-36)";
    }
    return null;
  }
  if (typeof read !== 'object' || Array.isArray(read)) return 'read is not an object (AD-36)';
  const readKeysFault = unknownKeyProblem('read', read, ['source', 'fields', 'filter', 'sort', 'paging']);
  if (readKeysFault !== null) return readKeysFault;
  const source = read.source;
  if (source === null || typeof source !== 'object' || Array.isArray(source)) {
    return 'read.source is not an object naming its port, endpoint and type (AD-36)';
  }
  const sourceKeysFault = unknownKeyProblem('read.source', source, ['port', 'endpoint', 'type', 'rowGet']);
  if (sourceKeysFault !== null) return sourceKeysFault;
  if (source.port !== 'admin') return `read.source.port '${source.port}' is not 'admin', the one port a Release 1 read names (AD-2)`;
  if (typeof source.endpoint !== 'string' || !ENDPOINT_RE.test(source.endpoint)) {
    return `read.source.endpoint '${source.endpoint}' is not a package-relative endpoint name`;
  }
  if (source.type !== 'LIST') return `read.source.type '${source.type}' is not 'LIST'`;

  const fieldsFault = nameListProblem('read.fields', read.fields);
  if (fieldsFault !== null) return fieldsFault;
  if (read.fields.length === 0) return 'read.fields is empty, and a read projects at least one field';
  const rowGetFault = rowGetProblem(source, read.fields);
  if (rowGetFault !== null) return rowGetFault;

  const { context } = declaration;
  if (context === null || typeof context !== 'object' || Array.isArray(context)) {
    return 'context is not an object, and a screen that declares a read declares its secret fields (AD-24)';
  }
  const contextFault =
    unknownKeyProblem('context', context, ['fields', 'secretFields']) ??
    nameListProblem('context.secretFields', context.secretFields, read.fields);
  if (contextFault !== null) return contextFault;
  const secrets = context.secretFields;
  const overlap = (where, names) => {
    const secret = names.find((name) => secrets.includes(name));
    return secret === undefined
      ? null
      : `${where} names the secret field '${secret}', and a filter or sort over a secret field would let a tool probe its value (AD-24)`;
  };

  const filterFault = nameListProblem('read.filter', read.filter, read.fields) ?? overlap('read.filter', read.filter);
  if (filterFault !== null) return filterFault;

  const sort = read.sort;
  if (sort === null || typeof sort !== 'object' || Array.isArray(sort)) {
    return 'read.sort is not an object declaring its fields, default and direction';
  }
  const sortKeysFault = unknownKeyProblem('read.sort', sort, ['fields', 'default', 'direction']);
  if (sortKeysFault !== null) return sortKeysFault;
  const sortFault = nameListProblem('read.sort.fields', sort.fields, read.fields) ?? overlap('read.sort.fields', sort.fields);
  if (sortFault !== null) return sortFault;
  if (typeof sort.default !== 'string' || !sort.fields.includes(sort.default)) {
    return `read.sort.default '${sort.default}' is not one of read.sort.fields`;
  }
  if (sort.direction !== 'asc' && sort.direction !== 'desc') {
    return `read.sort.direction '${sort.direction}' is neither 'asc' nor 'desc'`;
  }
  if (read.paging === 'cursor') {
    return "read.paging 'cursor' is refused on an admin source, which accepts no cursor; declare 'cap' (AD-36)";
  }
  if (read.paging !== 'cap') return `read.paging '${read.paging}' is not 'cap'`;
  if (typeof declaration.toolIdentifier !== 'string' || !READ_TOOL_IDENTIFIER_RE.test(declaration.toolIdentifier)) {
    return (
      `toolIdentifier '${declaration.toolIdentifier}' declares a read and is not <area>.<screen> in ` +
      'lower case, so its read tool could not be named <area>.<screen>.read'
    );
  }
  return tableProblem(declaration, read.fields, secrets);
}

/** The rules a `read.source.rowGet` derived field may name (AD-36). */
export const ROW_GET_RULES = ['beforeToday'];

const PARAM_RE = /^[A-Za-z][A-Za-z0-9]*$/;

/** Whether `value` is a JSON object: not `null` and not an array. */
function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

/**
 * What is wrong with `source.rowGet`, or `null` (AD-36). `fields` is the read's declared fields.
 *
 * An absent or `null` `rowGet` declares no detail call. Otherwise it is an object carrying only
 * `key` (one of `fields`), `param` (a query parameter name), `fields` (a non-empty array of unique
 * names from `fields`, without `key`) and `derived`, an array of objects carrying only `field` (one
 * of `fields`, neither `key` nor a detail field, and not repeated), `rule` (one of `ROW_GET_RULES`)
 * and `from` (one of the detail fields). `OcuPilot.Screen.Registry.RowGetProblem` returns the same
 * sentence for every case in `OcuPilot.Test.RowGetCorpus`.
 */
export function rowGetProblem(source, fields) {
  const where = 'read.source.rowGet';
  const { rowGet } = source;
  if (rowGet === undefined || rowGet === null) return null;
  if (!isObject(rowGet)) return `${where} is not an object declaring its key, param, fields and derived (AD-36)`;
  const keysFault = unknownKeyProblem(where, rowGet, ['key', 'param', 'fields', 'derived']);
  if (keysFault !== null) return keysFault;

  if (typeof rowGet.key !== 'string') return `${where}.key is not a string`;
  if (!fields.includes(rowGet.key)) return `${where}.key '${rowGet.key}' is not one of read.fields`;
  if (typeof rowGet.param !== 'string') return `${where}.param is not a string`;
  if (!PARAM_RE.test(rowGet.param)) return `${where}.param '${rowGet.param}' is not a query parameter name`;

  const detailFault = nameListProblem(`${where}.fields`, rowGet.fields, fields);
  if (detailFault !== null) return detailFault;
  const detail = rowGet.fields;
  if (detail.length === 0) return `${where}.fields is empty, and a detail call merges at least one field (AD-36)`;
  if (detail.includes(rowGet.key)) {
    return `${where}.fields names the key field '${rowGet.key}', which the list row already carries`;
  }

  if (!Array.isArray(rowGet.derived)) return `${where}.derived is not an array of derived fields`;
  const seen = [];
  for (let index = 0; index < rowGet.derived.length; index += 1) {
    const entry = rowGet.derived[index];
    const at = `${where}.derived entry #${index + 1}`;
    if (!isObject(entry)) return `${at} is not an object declaring its field, rule and from`;
    const entryKeysFault = unknownKeyProblem(at, entry, ['field', 'rule', 'from']);
    if (entryKeysFault !== null) return entryKeysFault;
    if (typeof entry.field !== 'string') return `${at} field is not a string`;
    if (!fields.includes(entry.field)) return `${at} field '${entry.field}' is not one of read.fields`;
    if (entry.field === rowGet.key) return `${at} field '${entry.field}' is the key field`;
    if (detail.includes(entry.field)) {
      return `${at} field '${entry.field}' is also a detail field, whose value the detail call supplies`;
    }
    if (seen.includes(entry.field)) return `${at} names the field '${entry.field}' twice`;
    seen.push(entry.field);
    if (typeof entry.rule !== 'string') return `${at} rule is not a string`;
    if (!ROW_GET_RULES.includes(entry.rule)) return `${at} rule '${entry.rule}' is not one of ${ROW_GET_RULES.join(',')}`;
    if (typeof entry.from !== 'string') return `${at} from is not a string`;
    if (!detail.includes(entry.from)) return `${at} from '${entry.from}' is not one of read.source.rowGet.fields`;
  }
  return null;
}

/** The kinds a table column may declare (AD-5). */
export const TABLE_COLUMN_KINDS = ['name', 'identifier', 'text', 'number', 'status'];

/** Whether a declaration declares a primary action or at least one row action. */
export function isWriteCapable(declaration) {
  const primary = declaration.primaryAction;
  if (primary !== null && typeof primary === 'object' && typeof primary.id === 'string' && primary.id !== '') return true;
  const rows = Array.isArray(declaration.rowActions) ? declaration.rowActions : [];
  return rows.some((action) => action !== null && typeof action === 'object' && typeof action.id === 'string' && action.id !== '');
}

/**
 * What is wrong with a read-declaring declaration's `table`, or `null`. The rules
 * `OcuPilot.Screen.Registry.TableProblem` applies: `table` carries only `columns`, `emptyNextKey`
 * and `emptyAgentKey`; `columns` is non-empty, each column carries only `field` (one of `fields`,
 * none of `secrets`, unique), a non-empty `labelKey` and a kind from `TABLE_COLUMN_KINDS`, and
 * exactly one is `name`;
 * `emptyStateKey` is non-empty; a composite id names only parts in `fields`; and a write-capable
 * declaration names `emptyAgentKey` with `emptyNextKey` empty, any other the reverse.
 */
export function tableProblem(declaration, fields, secrets) {
  const { table } = declaration;
  if (table === null || typeof table !== 'object' || Array.isArray(table)) {
    return "table is not an object, and a declaration with a read declares its table's columns and empty-state keys (AD-5)";
  }
  const keysFault = unknownKeyProblem('table', table, ['columns', 'emptyNextKey', 'emptyAgentKey']);
  if (keysFault !== null) return keysFault;
  if (!Array.isArray(table.columns)) return 'table.columns is not an array of columns';
  if (table.columns.length === 0) return 'table.columns is empty, and a table shows at least one column';

  const seen = new Set();
  let names = 0;
  for (let index = 0; index < table.columns.length; index += 1) {
    const column = table.columns[index];
    const where = `table.columns entry #${index + 1}`;
    if (column === null || typeof column !== 'object' || Array.isArray(column)) {
      return `${where} is not an object declaring its field, labelKey and kind`;
    }
    const columnKeysFault = unknownKeyProblem(where, column, ['field', 'labelKey', 'kind']);
    if (columnKeysFault !== null) return columnKeysFault;
    if (typeof column.field !== 'string' || !fields.includes(column.field)) {
      return `${where} field '${column.field}' is not one of read.fields`;
    }
    if (secrets.includes(column.field)) {
      return `${where} field '${column.field}' is a secret field, and a secret is never returned to a screen (Conventions, Secrets)`;
    }
    if (seen.has(column.field)) return `${where} names the field '${column.field}' twice`;
    seen.add(column.field);
    if (typeof column.labelKey !== 'string' || column.labelKey === '') {
      return `${where} labelKey is empty, and a column header names a string key`;
    }
    if (typeof column.kind !== 'string' || !TABLE_COLUMN_KINDS.includes(column.kind)) {
      return `${where} kind '${column.kind}' is not one of ${TABLE_COLUMN_KINDS.join(',')}`;
    }
    if (column.kind === 'name') names += 1;
  }
  if (names !== 1) {
    return `table.columns declares ${names} name column(s), and exactly one column is the row's name`;
  }

  if (typeof declaration.emptyStateKey !== 'string' || declaration.emptyStateKey === '') {
    return 'emptyStateKey is empty, and a declaration with a read names its empty-state sentence';
  }

  const { id } = declaration;
  if (id !== null && typeof id === 'object' && id.kind === 'composite' && Array.isArray(id.parts)) {
    const outside = id.parts.find((part) => !fields.includes(part));
    if (outside !== undefined) {
      return `id.parts names '${outside}', which is not one of read.fields, so a row's key could not be read from it`;
    }
  }

  for (const key of ['emptyNextKey', 'emptyAgentKey']) {
    if (typeof table[key] !== 'string') return `table.${key} is not a string key`;
  }
  if (isWriteCapable(declaration)) {
    if (table.emptyNextKey !== '') {
      return 'table.emptyNextKey is declared on a write-capable descriptor, whose empty state invites the agent instead';
    }
    if (table.emptyAgentKey === '') {
      return 'table.emptyAgentKey is empty on a write-capable descriptor, whose empty state invites the agent';
    }
  } else {
    if (table.emptyAgentKey !== '') {
      return 'table.emptyAgentKey is declared on a descriptor with no primary or row action, which has no write to invite';
    }
    if (table.emptyNextKey === '') {
      return 'table.emptyNextKey is empty, and a read-only empty state says what to do next';
    }
  }
  return null;
}

/**
 * Every client string key a declaration names: its `labelKey`, its `emptyStateKey`, and its
 * table's column labels and two empty-state keys. Empty keys are not listed.
 */
export function declaredStringKeys(declaration) {
  const keys = [declaration.labelKey, declaration.emptyStateKey];
  const { table } = declaration;
  if (table !== null && typeof table === 'object') {
    for (const column of Array.isArray(table.columns) ? table.columns : []) keys.push(column?.labelKey);
    keys.push(table.emptyNextKey, table.emptyAgentKey);
  }
  return keys.filter((key) => typeof key === 'string' && key !== '');
}

export function buildMirror({ entityTypes, scopeWords, archetypes, areas, screens }) {
  const known = new Set(entityTypes);
  const knownScopes = new Set(scopeWords ?? []);
  const archetypeKeys = (archetypes ?? []).map((archetype) => archetype.key);
  const knownArchetypes = new Set(archetypeKeys);
  for (const area of areas) {
    const bad = malformedPair(area.privileges);
    if (bad !== null) {
      throw new Error(
        `${AREA_SOURCE}: area "${area.key}" declares privilege pair ${bad} with no resource or ` +
          `no permission; a dropped pair ships an ungated area (AD-8)`
      );
    }
  }
  const identifierOwners = new Map();
  for (const screen of screens) {
    const { toolIdentifier } = screen.declaration;
    if (typeof toolIdentifier === 'string' && toolIdentifier !== '') {
      if (identifierOwners.has(toolIdentifier)) {
        throw new Error(
          `src/OcuPilot/Screen/Descriptor/${screen.file} (${screen.className}): toolIdentifier ` +
            `'${toolIdentifier}' is already declared by ${identifierOwners.get(toolIdentifier)}, and a ` +
            'screen and its tools are resolved by it (AD-5)'
        );
      }
      identifierOwners.set(toolIdentifier, screen.className);
    }
    const bad = malformedPair(screen.declaration.privileges);
    if (bad !== null) {
      throw new Error(
        `src/OcuPilot/Screen/Descriptor/${screen.file}: declares privilege pair ${bad} with no ` +
          `resource or no permission; a dropped pair ships an ungated screen (AD-8)`
      );
    }
    for (const named of entityTypesIn(screen.declaration)) {
      if (!known.has(named)) {
        throw new Error(
          `src/OcuPilot/Screen/Descriptor/${screen.file}: entity type "${named}" is not in ` +
            `src/OcuPilot/Kernel/EntityType.cls; add it there or use a declared value (AD-14)`
        );
      }
    }
    const { scope } = screen.declaration;
    if (typeof scope === 'string' && scope !== '' && !knownScopes.has(scope)) {
      throw new Error(
        `src/OcuPilot/Screen/Descriptor/${screen.file}: scope "${scope}" is not one of ` +
          `src/OcuPilot/Kernel/Scope.cls's declared values; add it there or use a declared ` +
          `value (AD-13)`
      );
    }
    // `''` is refused rather than waved through. It is not a declared key, so emitting it into
    // a field typed `ArchetypeKey` would fail as an unreadable `tsc` error on generated code --
    // the failure the defaulting below exists to prevent -- and it is what
    // `OcuPilot.Screen.Registry.ClassicLinkProblem` refuses on the instance, so waving it
    // through here would put the build and the instance out of step.
    //
    // An archetype key that is absent altogether is left alone, which is this generator's
    // convention for a partially declared fixture (`scope` is treated the same way, and the
    // AD-13 test below pins it) -- but unlike `refreshes`, `refreshRates` and
    // `classicLinkExemption` it is NOT defaulted at emission below, because no candidate value
    // is anything but a classification the descriptor did not make. So a real descriptor
    // declaring no archetype emits a `SCREENS` entry missing its non-optional
    // `archetype: ArchetypeKey` and fails `tsc` rather than at a named refusal. That gap is
    // bounded rather than closed here: `ui/tools/classic-links.mjs` reads the same declarations
    // and refuses an absent key by name (`archetype "" is not one ...`) in `prebuild`,
    // `prestart` and the pre-commit hook, so every gate names it; only a bare
    // `node tools/screen-mirror.mjs` reaches the `tsc` error first.
    const { archetype } = screen.declaration;
    if (typeof archetype === 'string' && !knownArchetypes.has(archetype)) {
      throw new Error(
        `src/OcuPilot/Screen/Descriptor/${screen.file}: archetype "${archetype}" is not in ` +
          `src/OcuPilot/Screen/Archetype.cls; add it there or use a declared value (AD-44)`
      );
    }
    const refreshFault = refreshProblem(screen.declaration);
    if (refreshFault !== null) {
      throw new Error(`src/OcuPilot/Screen/Descriptor/${screen.file}: ${refreshFault}`);
    }
    const readFault = readProblem(screen.declaration);
    if (readFault !== null) {
      throw new Error(`src/OcuPilot/Screen/Descriptor/${screen.file} (${screen.className}): ${readFault}`);
    }
  }

  // `refreshes` / `refreshRates` are defaulted rather than spread verbatim, because `refreshProblem`
  // calls an omitted pair sound and `Base.Refreshes()` answers 0 for one: without these the mirror
  // would pass its own refusal gate and then emit a `SCREENS` missing two non-optional fields, so
  // the descriptor would fail as an unreadable `tsc` error rather than at the named refusal.
  const emitted = screens.map((screen) => ({
    descriptor: screen.className,
    ...screen.declaration,
    // Defaulted after the spread -- which overwrites the value and keeps the declared position,
    // so a descriptor that declares them emits byte-identically. `refreshProblem` calls an
    // omitted pair sound and `Base.Refreshes()` answers 0 for one; without these the mirror would
    // pass its own refusal gate and then emit a `SCREENS` missing two non-optional fields, so the
    // descriptor would fail as an unreadable `tsc` error rather than at the named refusal.
    refreshes: screen.declaration.refreshes ?? false,
    refreshRates: screen.declaration.refreshRates ?? [],
    // Defaulted the same way and for the same reason: Story 1.15 added `label` and `href` to
    // `classicLinkExemption`, and a descriptor written before they existed declares neither.
    // Spread first so a declaration that carries them emits byte-identically in its own order.
    classicLinkExemption: {
      ...(screen.declaration.classicLinkExemption ?? {}),
      exempt: screen.declaration.classicLinkExemption?.exempt ?? false,
      reason: screen.declaration.classicLinkExemption?.reason ?? '',
      label: screen.declaration.classicLinkExemption?.label ?? '',
      href: screen.declaration.classicLinkExemption?.href ?? '',
    },
    // Defaulted for the reason the refresh pair is: a screen with no read declares none, and the
    // mirror's field is not optional.
    read: screen.declaration.read ?? null,
    table: screen.declaration.table ?? null,
  }));

  const builtArchetypeKeys = archetypeKeys.filter((key) =>
    screens.some((screen) => screen.declaration.built === true && screen.declaration.archetype === key)
  );

  return `${HEADER}
export type EntityTypeKey = ${entityTypes.map((value) => `'${value}'`).join(' | ')};

/**
 * The closed archetype vocabulary, mirrored from OcuPilot.Screen.Archetype. A screen's
 * archetype decides whether it may link out to the classic portal (AD-44); the classification
 * itself is the build check's and the registry's, not the client's.
 */
export type ArchetypeKey =
  ${archetypeKeys.length === 0 ? 'never' : archetypeKeys.map((value) => `| '${value}'`).join('\n  ')};

/**
 * The archetypes of every built screen, in vocabulary order. The client's archetype-to-page map
 * requires a page for each of these, so a built screen whose archetype has none fails the type
 * check (AD-5).
 */
export type BuiltArchetypeKey =
  ${builtArchetypeKeys.length === 0 ? 'never' : builtArchetypeKeys.map((value) => `| '${value}'`).join('\n  ')};

export interface PrivilegePair {
  readonly resource: string;
  readonly permission: string;
}

export interface AreaDeclaration {
  readonly key: string;
  readonly railPosition: number;
  readonly labelKey: string;
  readonly navigates: boolean;
  readonly pinBottom: boolean;
  readonly privileges: readonly PrivilegePair[];
}

export interface IdAccessor {
  readonly kind: 'none' | 'single' | 'composite';
  readonly parts: readonly string[];
}

export interface ContextDeclaration {
  readonly fields: readonly string[];
  readonly secretFields: readonly string[];
}

export interface ActionDeclaration {
  readonly id: string;
  readonly selfProtection: string;
}

export interface ClassicLinkExemption {
  readonly exempt: boolean;
  readonly reason: string;
  /** The classic page's own name, which labels the card's action. \`''\` unless \`exempt\`. */
  readonly label: string;
  /**
   * Where the card's action goes: a root-relative, same-origin path (AD-47), declared and
   * never derived from \`classicPage\`, which is a class name (AD-44). \`''\` unless \`exempt\`.
   */
  readonly href: string;
}

/** A field a detail call derives on the instance from one of its detail fields (AD-36). */
export interface ReadDerived {
  readonly field: string;
  readonly rule: 'beforeToday';
  readonly from: string;
}

/**
 * The one per-row detail call a read may name (AD-36): the endpoint's GET, issued on the instance
 * for each row that survives the cap with \`param\` set to the row's \`key\`, merging \`fields\`
 * and setting \`derived\`.
 */
export interface ReadRowGet {
  readonly key: string;
  readonly param: string;
  readonly fields: readonly string[];
  readonly derived: readonly ReadDerived[];
}

/** Where a read's rows come from: one admin API LIST (AD-2, AD-36), and optionally its detail call. */
export interface ReadSource {
  readonly port: 'admin';
  readonly endpoint: string;
  readonly type: 'LIST';
  readonly rowGet?: ReadRowGet | null;
}

/** The fields a read sorts on, its default sort field and direction. */
export interface ReadSort {
  readonly fields: readonly string[];
  readonly default: string;
  readonly direction: 'asc' | 'desc';
}

/** A screen's one declared read (AD-36): the screen's list and its read tool both resolve through it. */
export interface ReadDeclaration {
  readonly source: ReadSource;
  readonly fields: readonly string[];
  readonly filter: readonly string[];
  readonly sort: ReadSort;
  readonly paging: 'cap';
}

/** How a table column renders its field (AD-5). */
export type TableColumnKind = 'name' | 'identifier' | 'text' | 'number' | 'status';

/** One table column: the read field it shows, its header's string key and its kind. */
export interface TableColumn {
  readonly field: string;
  readonly labelKey: string;
  readonly kind: TableColumnKind;
}

/**
 * The table a read's rows render in: its columns and the string keys of the empty state's second
 * line, of which exactly one is non-empty.
 */
export interface TableDeclaration {
  readonly columns: readonly TableColumn[];
  readonly emptyNextKey: string;
  readonly emptyAgentKey: string;
}

export interface ScreenDeclaration {
  readonly descriptor: string;
  readonly route: string;
  readonly area: string;
  readonly labelKey: string;
  readonly sideBarPosition: number;
  readonly archetype: ArchetypeKey;
  readonly built: boolean;
  /** Whether the shared auto-refresh framework binds this screen (AD-43). */
  readonly refreshes: boolean;
  /** The rates, in whole seconds ascending, the chip may set. Empty unless \`refreshes\`. */
  readonly refreshRates: readonly number[];
  readonly privileges: readonly PrivilegePair[];
  readonly entityType: string;
  readonly secondaryEntityTypes: readonly string[];
  readonly scope: string;
  readonly parentScope: string;
  readonly id: IdAccessor;
  readonly context: ContextDeclaration;
  readonly primaryAction: ActionDeclaration;
  readonly rowActions: readonly ActionDeclaration[];
  readonly emptyStateKey: string;
  readonly commandAliases: readonly string[];
  readonly classicPage: string;
  readonly classicLinkExemption: ClassicLinkExemption;
  /** The screen's one declared read, or \`null\` for a screen with none (AD-36). */
  readonly read: ReadDeclaration | null;
  /** The table the read renders in, or \`null\` exactly when \`read\` is. */
  readonly table: TableDeclaration | null;
  readonly toolIdentifier: string;
}

/** The closed entity-type vocabulary, mirrored from OcuPilot.Kernel.EntityType. */
export const ENTITY_TYPES: readonly EntityTypeKey[] = ${JSON.stringify(entityTypes, null, 2)};

/** The eight areas, in rail order. */
export const AREAS: readonly AreaDeclaration[] = ${JSON.stringify(areas, null, 2)};

/** Every declared screen, by descriptor class name. */
export const SCREENS: readonly ScreenDeclaration[] = ${JSON.stringify(emitted, null, 2)};
`;
}

const HEADER = `/*
 * GENERATED FILE -- DO NOT EDIT.
 *
 * The client mirror of OcuPilot's screen descriptors and area vocabulary (AD-5). Every value
 * here is derived from the XData declarations in src/OcuPilot/Screen/ by
 * ui/tools/screen-mirror.mjs; edit the descriptor and regenerate.
 *
 * Regenerate: node tools/screen-mirror.mjs
 * Drift check: ui/tools/screen-mirror.test.mjs, which fails when this file and the
 * declarations disagree.
 */
`;

/** The mirror this repository's sources produce right now. */
export function generate() {
  return buildMirror(readSources());
}

/** The mirror checked in at `MIRROR_PATH`. */
export function readCheckedInMirror() {
  return readFileSync(MIRROR_PATH, 'utf8');
}

/**
 * What this run actually read, as a one-line census.
 *
 * Every gate CI runs reports the size of what it looked at, so "found nothing wrong" and
 * "looked at nothing" are distinguishable (Story 1.17's own Always-constraint). `up to date.`
 * said neither, and a descriptor directory that resolved to nothing would have printed it.
 */
function census() {
  const sources = readSources();
  return (
    `${sources.screens.length} descriptor(s), ${sources.areas.length} area(s), ` +
    `${sources.entityTypes.length} entity type(s), ${sources.archetypes.length} archetype(s)`
  );
}

function main() {
  const expected = generate();
  const size = census();
  if (process.argv.includes('--check')) {
    if (readCheckedInMirror() !== expected) {
      console.error('screen-mirror: the checked-in mirror is stale -- run node tools/screen-mirror.mjs');
      process.exit(1);
      return;
    }
    console.log(`screen-mirror: up to date; mirrored ${size}.`);
    return;
  }
  writeFileSync(MIRROR_PATH, expected);
  console.log(`screen-mirror: wrote ${MIRROR_PATH} from ${size}`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main();
}

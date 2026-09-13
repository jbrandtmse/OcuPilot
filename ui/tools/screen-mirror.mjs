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
 * **It refuses a refresh rate the string table publishes no chip literal for** (AD-43, DW-126).
 * A rate is only usable if the command bar can name it, and the only copy that names one is
 * `ui/src/app/core/strings.ts`'s Fixed-strings row; a screen declaring `30` with no
 * `Auto-refresh: every 30 s` in the table would leave the chip either blank or carrying invented
 * text. Making it a build failure is what keeps the missing copy an escalation rather than a
 * paragraph nobody reads -- and it is why publishing the copy later makes those rates legal with
 * no change here.
 *
 * Usage: `node tools/screen-mirror.mjs` writes the mirror; `--check` only reports drift.
 */

import { readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, join } from 'node:path';

import { STRINGS_TS_PATH, loadStrings, publishedRefreshRates } from './strings.mjs';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

export const AREA_SOURCE = join(REPO_ROOT, 'src', 'OcuPilot', 'Screen', 'Area.cls');
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

function occurrences(text, character) {
  let count = 0;
  for (const ch of text) if (ch === character) count += 1;
  return count;
}

/**
 * The body of the named `XData` block, or `null`.
 *
 * The UDL convention this tree follows puts the opening brace on the line after the `XData`
 * declaration and the closing brace on a line of its own, which is what the three-state walk
 * below assumes -- the same assumption `scripts/check-objectscript.py` makes about the same
 * blocks, so the two readers cannot disagree about where a block starts and ends.
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
      depth = occurrences(raw, '{') - occurrences(raw, '}');
      if (depth > 0) {
        state = 'inside';
        body = [];
      } else {
        state = null;
      }
      continue;
    }
    depth += occurrences(raw, '{') - occurrences(raw, '}');
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
 * Reads the three sources and returns the parsed declarations, in a deterministic order:
 * areas by rail position, screens by descriptor class name. A generator whose output depends
 * on directory order would fail its own drift check on another machine.
 */
export function readSources() {
  const entityTypes = parseEntityTypes(readFileSync(ENTITY_TYPE_SOURCE, 'utf8'));
  if (entityTypes === null) {
    throw new Error(`${ENTITY_TYPE_SOURCE} declares no 'Parameter TYPES'`);
  }

  const scopeWords = parseScopeWords(readFileSync(SCOPE_SOURCE, 'utf8'));
  if (scopeWords === null) {
    throw new Error(`${SCOPE_SOURCE} declares no 'Parameter SCOPEINSTANCE'/'SCOPENAMESPACE' pair`);
  }

  const areaText = readFileSync(AREA_SOURCE, 'utf8');
  const areaBody = extractXData(areaText, 'Areas');
  if (areaBody === null) throw new Error(`${AREA_SOURCE} carries no 'XData Areas' block`);
  const areas = JSON.parse(areaBody).areas.slice().sort((a, b) => a.railPosition - b.railPosition);

  const screens = [];
  for (const entry of readdirSync(DESCRIPTOR_DIR).sort()) {
    if (!entry.endsWith('.cls') || entry === BASE_FILE) continue;
    const path = join(DESCRIPTOR_DIR, entry);
    const text = readFileSync(path, 'utf8');
    const className = extractClassName(text);
    const body = extractXData(text, 'Declaration');
    if (body === null) throw new Error(`${path} carries no 'XData Declaration' block`);
    screens.push({ file: entry, className, declaration: JSON.parse(body) });
  }
  screens.sort((a, b) => (a.className < b.className ? -1 : a.className > b.className ? 1 : 0));

  const publishedRates = publishedRefreshRates(loadStrings());

  return { entityTypes, scopeWords, publishedRates, areas, screens };
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

export function buildMirror({ entityTypes, scopeWords, publishedRates, areas, screens }) {
  const known = new Set(entityTypes);
  const knownScopes = new Set(scopeWords ?? []);
  const knownRates = new Set(publishedRates ?? []);
  for (const area of areas) {
    const bad = malformedPair(area.privileges);
    if (bad !== null) {
      throw new Error(
        `${AREA_SOURCE}: area "${area.key}" declares privilege pair ${bad} with no resource or ` +
          `no permission; a dropped pair ships an ungated area (AD-8)`
      );
    }
  }
  for (const screen of screens) {
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
    const refreshFault = refreshProblem(screen.declaration);
    if (refreshFault !== null) {
      throw new Error(`src/OcuPilot/Screen/Descriptor/${screen.file}: ${refreshFault}`);
    }
    for (const rate of screen.declaration.refreshRates ?? []) {
      if (knownRates.has(rate)) continue;
      throw new Error(
        `src/OcuPilot/Screen/Descriptor/${screen.file}: refresh rate ${JSON.stringify(rate)} has ` +
          `no chip literal in ${STRINGS_TS_PATH}; the command bar would have to invent one ` +
          `(AD-43, DW-126). Publish "Auto-refresh: every ${rate} s" there first.`
      );
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
  }));

  return `${HEADER}
export type EntityTypeKey = ${entityTypes.map((value) => `'${value}'`).join(' | ')};

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
}

export interface ScreenDeclaration {
  readonly descriptor: string;
  readonly route: string;
  readonly area: string;
  readonly labelKey: string;
  readonly sideBarPosition: number;
  readonly archetype: string;
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

function main() {
  const expected = generate();
  if (process.argv.includes('--check')) {
    if (readCheckedInMirror() !== expected) {
      console.error('screen-mirror: the checked-in mirror is stale -- run node tools/screen-mirror.mjs');
      process.exit(1);
      return;
    }
    console.log('screen-mirror: up to date.');
    return;
  }
  writeFileSync(MIRROR_PATH, expected);
  console.log(`screen-mirror: wrote ${MIRROR_PATH}`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main();
}

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
 * file and the class, as `OcuPilot.Screen.Registry.ReadProblem` refuses it on the instance, a
 * `banner` outside its own grammar the same way (`bannerProblem`), and a `read.criteria` block
 * outside the server-search grammar the same way again (`criteriaProblem`, AD-21).
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

import { isCredentialName } from './credential-pattern.mjs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, join } from 'node:path';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

export const AREA_SOURCE = join(REPO_ROOT, 'src', 'OcuPilot', 'Screen', 'Area.cls');
export const ARCHETYPE_SOURCE = join(REPO_ROOT, 'src', 'OcuPilot', 'Screen', 'Archetype.cls');
export const DESCRIPTOR_DIR = join(REPO_ROOT, 'src', 'OcuPilot', 'Screen', 'Descriptor');
export const ENTITY_TYPE_SOURCE = join(REPO_ROOT, 'src', 'OcuPilot', 'Kernel', 'EntityType.cls');
export const ENTITY_REF_SOURCE = join(REPO_ROOT, 'src', 'OcuPilot', 'Kernel', 'EntityRef.cls');
export const SCOPE_SOURCE = join(REPO_ROOT, 'src', 'OcuPilot', 'Kernel', 'Scope.cls');
export const MIRROR_PATH = join(REPO_ROOT, 'ui', 'src', 'app', 'core', 'screens.generated.ts');
export const TOOL_FIELDS_SOURCE = join(REPO_ROOT, 'src', 'OcuPilot', 'Screen', 'Tool', 'ToolFields.cls');
export const SCREEN_REGISTRY_SOURCE = join(REPO_ROOT, 'src', 'OcuPilot', 'Screen', 'Registry.cls');

/** The abstract base lives in the descriptor package and declares no screen. */
const BASE_FILE = 'Base.cls';

const CLASS_RE = /^Class\s+([A-Za-z0-9_.%]+)/m;
const XDATA_RE = /^XData\s+([A-Za-z0-9_%]+)/;
const TYPES_PARAM_RE = /^Parameter\s+TYPES\s*=\s*"([^"]*)"\s*;/m;
const IDRULES_PARAM_RE = /^Parameter\s+IDRULES\s*=\s*"([^"]*)"\s*;/m;
const REFSEPARATOR_PARAM_RE = /^Parameter\s+REFSEPARATOR\s*=\s*(\d+)\s*;/m;
const IDRULENAMES_PARAM_RE = /^Parameter\s+IDRULENAMES\s*=\s*"([^"]*)"\s*;/m;
const SINGLETONID_PARAM_RE = /^Parameter\s+RULESINGLETONID\s*=\s*"([^"]*)"\s*;/m;
const DECLAREDNAMEKINDS_PARAM_RE = /^Parameter\s+DECLAREDNAMEKINDS\s*=\s*"([^"]*)"\s*;/m;
const SELFPROTECTIONRULES_PARAM_RE = /^Parameter\s+SELFPROTECTIONRULES\s*=\s*"([^"]*)"\s*;/m;
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
 * The rule names this generator knows a client implementation exists for -- the roster
 * `ui/src/app/core/entity-ref.ts` is pinned equal to by `ui/tools/entity-ref.test.mjs`, in both
 * directions.
 *
 * It is the reason a kernel rule cannot reach the client as a silent identity function: a rule
 * declared in `OcuPilot.Kernel.EntityRef.IDRULES` and absent here fails `npm run build` at
 * `prebuild`, naming the rule, rather than being mirrored into a key builder that does nothing
 * with it (AD-5, AD-13 as amended by DW-1359).
 */
export const IMPLEMENTED_ID_RULES = ['foldcase-striptrailingslash', 'foldcase', 'singleton', 'integer'];

/**
 * The per-type canonical id rules, from the kernel's own `IDRULES` parameter: `[[type, rule],
 * ...]` in declaration order, or `null` when the parameter is missing -- the same "reported, not
 * read as empty" discipline `parseEntityTypes` follows, because an absent table and a table that
 * declares nothing are different facts and only one of them is a source this generator can trust.
 *
 * A pair with no colon, or with an empty half, is kept as it was written so `buildMirror` can
 * refuse it by name rather than silently dropping it.
 *
 * **Nothing here is trimmed, deliberately.** `OcuPilot.Kernel.EntityRef.IdRuleFor` splits the
 * same string with `$Piece` and compares the halves verbatim, so a pair written the natural way
 * -- `"web-application:r, task:r"` -- names the type `" task"` to the kernel and matches no type
 * at all, while a trimming reader here would mirror `task` and make the client fold an id the
 * instance leaves alone: DW-1364 in mirror image, with the build green. Reading it exactly as the
 * kernel does sends the stray space to `buildMirror`, which refuses the unknown type by name.
 * `$Piece(pair, ":", 2)` also stops at the second colon, which is why the rule half does too.
 */
export function parseIdRules(text) {
  const match = IDRULES_PARAM_RE.exec(text);
  if (match === null) return null;
  return match[1]
    .split(',')
    .filter((pair) => pair.trim() !== '')
    .map((pair) => {
      const pieces = pair.split(':');
      return pieces.length < 2 ? [pair, ''] : [pieces[0], pieces[1]];
    });
}

/**
 * The code point joining the three parts of a reference key, from the kernel's own
 * `REFSEPARATOR` parameter; `null` when the parameter is missing or is not a whole number.
 *
 * **It is mirrored for the reason the id-rule table is** (AD-5): `entity-ref.ts` held the
 * character as a hand-copied `'\u0002'` literal beside `Parameter REFSEPARATOR = 2`, with
 * nothing comparing the two, so moving one of them shipped two key builders that agree on every
 * part of a key except the joins -- DW-1364's defect class with no gate at all (DW-1403).
 */
export function parseRefSeparator(text) {
  const match = REFSEPARATOR_PARAM_RE.exec(text);
  if (match === null) return null;
  const code = Number(match[1]);
  return Number.isSafeInteger(code) && code > 0 ? code : null;
}

/**
 * The kernel's own closed rule vocabulary, from its `IDRULENAMES` parameter; `null` when absent.
 * Untrimmed for `parseIdRules`' reason: the two parameters are one declaration, and a name that
 * reads differently on the two sides of it is a declaration error the build should name.
 */
export function parseIdRuleNames(text) {
  const match = IDRULENAMES_PARAM_RE.exec(text);
  if (match === null) return null;
  return match[1].split(',').filter((value) => value.trim() !== '');
}

/**
 * The one id a `singleton` type's reference carries -- `OcuPilot.Kernel.EntityRef`'s own
 * `RULESINGLETONID` parameter; `null` when the parameter is missing or empty.
 *
 * **Mirrored for the reason `REFSEPARATOR` is** (AD-5, DW-1403): the `singleton` rule answers a
 * constant, so a hand-copied literal in `entity-ref.ts` beside this parameter would be two key
 * builders that agree on every part of a key except the id. `null` rather than a default, so an
 * absent parameter is reported by `buildMirror` rather than shipping an empty canonical id.
 */
export function parseSingletonId(text) {
  const match = SINGLETONID_PARAM_RE.exec(text);
  if (match === null || match[1] === '') return null;
  return match[1];
}

/**
 * The self-protection rules a declared action may name -- `OcuPilot.Screen.Registry`'s own
 * `SELFPROTECTIONRULES` parameter; `null` when the parameter is missing.
 *
 * Read rather than copied, for `parseDeclaredNameKinds`' reason (AD-5, AD-53): the rule is
 * mirrored to the client, which draws a refused row action from it, so a value the instance would
 * refuse must be refused here too. `null` rather than `[]`, because an absent declaration and a
 * declaration of nothing are different facts.
 */
export function parseSelfProtectionRules(text) {
  const match = SELFPROTECTIONRULES_PARAM_RE.exec(text);
  if (match === null) return null;
  return match[1]
    .split(',')
    .map((value) => value.trim())
    .filter((value) => value !== '');
}

/**
 * What is wrong with `declaration`'s declared actions, or `null` -- the same rules
 * `OcuPilot.Screen.Registry.ActionProblem` applies: the primary action and every row action carry
 * only `id` and `selfProtection`, a row action's id is non-empty and unique, and a non-empty
 * `selfProtection` names one of `rules`.
 *
 * The vocabulary is the instance's own, passed in rather than held here, so the two validators
 * cannot disagree about what a rule is (AD-5, AD-53).
 */
export function actionProblem(declaration, rules) {
  // An absent key is left alone, this generator's convention for a partially declared fixture
  // (`scope` and `archetype` are treated the same way). `declarationProblem` above has already
  // refused a misspelt one, and `OcuPilot.Screen.Registry.ActionProblem` is lenient identically.
  if (declaration.primaryAction !== undefined) {
    const primaryFault = oneActionProblem(declaration.primaryAction, 'primaryAction', rules);
    if (primaryFault !== null) return primaryFault;
  }
  const rows = declaration.rowActions;
  if (rows === undefined) return null;
  if (!Array.isArray(rows)) return 'rowActions is not an array of declared actions';
  const seen = new Set();
  for (let index = 0; index < rows.length; index += 1) {
    const where = `rowActions entry #${index + 1}`;
    const fault = oneActionProblem(rows[index], where, rules);
    if (fault !== null) return fault;
    const { id } = rows[index];
    if (id === '') return `${where} declares an empty id, and an action with no id is a control nothing can run`;
    if (seen.has(id)) return `rowActions names the action '${id}' twice`;
    seen.add(id);
  }
  return null;
}

/** What is wrong with one declared action, or `null`. Read for `actionProblem` alone. */
function oneActionProblem(action, where, rules) {
  if (action === null || typeof action !== 'object' || Array.isArray(action)) {
    return `${where} is not an object declaring its id and self-protection rule`;
  }
  const keysFault = unknownKeyProblem(where, action, ['id', 'selfProtection']);
  if (keysFault !== null) return keysFault;
  if (typeof action.id !== 'string') return `${where} id is not a string`;
  if (typeof action.selfProtection !== 'string') return `${where} selfProtection is not a string`;
  if (action.selfProtection === '') return null;
  if (!rules.includes(action.selfProtection)) {
    return (
      `${where} selfProtection '${action.selfProtection}' is not one of ${rules.join(',')}, ` +
      'and a rule neither the instance nor the client understands explains nothing (AD-5, AD-53)'
    );
  }
  return null;
}

/**
 * The self-protection rules `ui/src/app/core/self-protection.ts` can actually evaluate, for the
 * roster check against `OcuPilot.Screen.Registry`'s own `SELFPROTECTIONRULES`.
 *
 * A rule the instance declares and the client cannot draw would ship as a row action offered with
 * no explanation, which is the divergence `checkedDeclaredNameKinds` exists to prevent for its own
 * vocabulary (AD-5, AD-53).
 */
export const IMPLEMENTED_SELF_PROTECTION_RULES = ['serves-ocupilot', 'protected-account'];

/**
 * The projection names this module's `declaredNames` fills, for the roster check against
 * `OcuPilot.Screen.Registry`'s own `DECLAREDNAMEKINDS`.
 *
 * It is the reason the mirror cannot validate a confirm-channel key against a set the instance
 * does not build, or miss one it does: `checkedDeclaredNameKinds` throws naming the source class
 * on either difference, the way `checkedIdRules` throws on an id rule this generator cannot apply
 * (AD-5, AD-6).
 */
export const IMPLEMENTED_DECLARED_NAME_KINDS = [
  'settable',
  'path',
  'criteria',
  'read',
  'credential',
  'toolRead',
];

/**
 * The projections `OcuPilot.Screen.Registry.DeclaredNames` declares it fills, from that class's
 * own `DECLAREDNAMEKINDS` parameter; `null` when the parameter is missing.
 *
 * `null` rather than `[]`, the discipline `parseEntityTypes` follows: an absent declaration and a
 * declaration of nothing are different facts, and only one of them is a source to trust.
 */
export function parseDeclaredNameKinds(text) {
  const match = DECLAREDNAMEKINDS_PARAM_RE.exec(text);
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

  const entityRefText = readFileSync(ENTITY_REF_SOURCE, 'utf8');
  const idRules = parseIdRules(entityRefText);
  if (idRules === null) {
    throw new Error(`${ENTITY_REF_SOURCE} declares no 'Parameter IDRULES'`);
  }
  const idRuleNames = parseIdRuleNames(entityRefText);
  if (idRuleNames === null) {
    throw new Error(`${ENTITY_REF_SOURCE} declares no 'Parameter IDRULENAMES'`);
  }
  const refSeparator = parseRefSeparator(entityRefText);
  if (refSeparator === null) {
    throw new Error(`${ENTITY_REF_SOURCE} declares no whole-number 'Parameter REFSEPARATOR'`);
  }
  const singletonId = parseSingletonId(entityRefText);
  if (singletonId === null) {
    throw new Error(`${ENTITY_REF_SOURCE} declares no non-empty 'Parameter RULESINGLETONID'`);
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

  const screenRegistryText = readFileSync(SCREEN_REGISTRY_SOURCE, 'utf8');
  const declaredNameKinds = parseDeclaredNameKinds(screenRegistryText);
  if (declaredNameKinds === null) {
    throw new Error(`${SCREEN_REGISTRY_SOURCE} declares no 'Parameter DECLAREDNAMEKINDS'`);
  }
  const selfProtectionRules = parseSelfProtectionRules(screenRegistryText);
  if (selfProtectionRules === null) {
    throw new Error(`${SCREEN_REGISTRY_SOURCE} declares no 'Parameter SELFPROTECTIONRULES'`);
  }

  const toolFieldsText = readFileSync(TOOL_FIELDS_SOURCE, 'utf8');
  const toolFieldsBody = extractXData(toolFieldsText, 'Tools');
  if (toolFieldsBody === null) throw new Error(`${TOOL_FIELDS_SOURCE} carries no 'XData Tools' block`);
  const toolFields = parseXDataJson(toolFieldsBody, TOOL_FIELDS_SOURCE, 'Tools');

  return { entityTypes, idRules, idRuleNames, refSeparator, singletonId, declaredNameKinds, selfProtectionRules, scopeWords, archetypes, areas, screens, toolFields };
}

/**
 * What is wrong with `declaration`'s `entityLabelKey`, or `null` (AD-5, AD-14) -- the same
 * sentences `OcuPilot.Screen.Registry.EntityLabelProblem` returns.
 *
 * The key is optional and names the client string key holding the singular noun for this screen's
 * primary entity type: what a proposal card's title reads where the wire carries only the type's
 * slug and `labelKey` is the plural screen label. Declared empty, or absent, publishes no noun. A
 * noun declared where no `entityType` is names a label for nothing, and is refused.
 */
export function entityLabelProblem(declaration) {
  if (!isObject(declaration)) return null;
  if (!('entityLabelKey' in declaration)) return null;
  if (typeof declaration.entityLabelKey !== 'string') return 'entityLabelKey is not a string key';
  if (declaration.entityLabelKey === '') return null;
  if (typeof declaration.entityType !== 'string' || declaration.entityType === '') {
    return "entityLabelKey names the singular noun for this screen's entity type, and none is declared";
  }
  return null;
}

/**
 * What is wrong with `declaration`'s `secretArguments` and `fingerprintExcludes`, or `null`
 * (AD-3, AD-6) -- the same sentences `OcuPilot.Screen.Registry.ConfirmChannelProblem` returns.
 *
 * Both are optional arrays of non-empty, unique strings. Every `fingerprintExcludes` path names a
 * field of this screen's write tool, or a field its own read declares (`read.fields`, the
 * `rowGet` detail fields and the derived field names), so an exclusion cannot quietly cover
 * nothing while a side-effect field the write tool does not settle can still be declared. And a
 * declared criterion, or a settable string field of that tool, whose name matches the credential
 * pattern and is absent from `secretArguments` is refused (DW-1121): it is a secret the confirm
 * channel would otherwise carry in clear.
 *
 * A `secretArguments` name also qualifies when it is a top-level `secret` literal row of one of
 * the screen's write tools (`secretRowNames`) -- a derived credential such as X.509's
 * `PrivateKeyPassword`, or an authored wrapper field such as `Security.User`'s POST `Password`.
 * That is additive: every name the two sources above admit is still admitted.
 *
 * `toolFields` is the generated `ToolFields.cls` block; a caller that supplies none (every fixture
 * in `screen-mirror.test.mjs`) is read as "this screen owns no write tool", which is what a
 * descriptor with no entry means anyway.
 */
export function confirmChannelProblem(declaration, toolFields = {}) {
  const secrets = stringListProblem(declaration, 'secretArguments');
  if (typeof secrets === 'string') return secrets;
  const excludes = stringListProblem(declaration, 'fingerprintExcludes');
  if (typeof excludes === 'string') return excludes;

  const names = declaredNames(declaration, toolFields);
  for (const path of excludes) {
    if (!names.path.includes(path) && !names.read.includes(path)) {
      return `fingerprintExcludes names '${path}', which is neither a field of this screen's write tool nor one its read declares (AD-6)`;
    }
  }
  const secretRows = secretRowNames(declaration.toolIdentifier, toolFields);
  for (const name of secrets) {
    if (!names.settable.includes(name) && !names.read.includes(name) && !secretRows.includes(name)) {
      return `secretArguments names '${name}', which is neither a settable field of this screen's write tool nor one its read declares (AD-6)`;
    }
  }
  const criterionFault = credentialNameProblem(names.criteria, secrets, 'read.criteria');
  if (criterionFault !== null) return criterionFault;
  return credentialNameProblem(names.credential, secrets, "the write tool's settable fields");
}

/**
 * The one set of names a declaration's two confirm-channel keys are validated against (DW-1206) --
 * `OcuPilot.Screen.Registry.DeclaredNames`' five projections, built once from the write tool's
 * classified rows and the declaration's own read.
 *
 * `settable` is the `[]`-stripped spelling `OcuPilot.Screen.Tool.Write.FieldRows` drops a declared
 * secret by, so `secretArguments` is checked in it; `path` is the spelling written in the field
 * list, `[]` included, which is the spelling `OcuPilot.Kernel.Proposal.Fingerprint.Canonical`
 * matches an exclusion by, so `fingerprintExcludes` is checked in that. One traversal answers both,
 * because their consumers honour different spellings and a single spelling would admit the entry
 * one of them ignores -- the defect this builder exists to close.
 *
 * `criteria` is the typed criterion parameters plus the flag criteria; `read` is `read.fields`, the
 * `rowGet` detail fields, the derived names and `criteria`; `credential` is `path` narrowed to a
 * string placeholder, which is the credential-name rule's own qualification.
 *
 * The roster of projection names is the kernel's (`DECLAREDNAMEKINDS`), held equal to
 * `IMPLEMENTED_DECLARED_NAME_KINDS` by `checkedDeclaredNameKinds` in `buildMirror`.
 */
export function declaredNames(declaration, toolFields = {}) {
  const rows = toolFieldRows(declaration.toolIdentifier, toolFields);
  const settable = [];
  const path = [];
  const credential = [];
  for (const [rowPath, row] of Object.entries(rows)) {
    if (row.credential) credential.push(rowPath);
    if (!row.settable) continue;
    if (!path.includes(rowPath)) path.push(rowPath);
    if (row.name !== '' && !settable.includes(row.name)) settable.push(row.name);
  }
  const criteria = declaredCriterionParams(declaration);
  const read = declaredReadFields(declaration);
  for (const name of criteria) {
    if (!read.includes(name)) read.push(name);
  }
  // `toolRead` is a write tool's own `READANSWERS`, and this generator reads descriptors rather
  // than tool classes -- so the projection is empty here. It is filled by the kernel's own caller,
  // `OcuPilot.Screen.Registry.FingerprintSubjectProblem`, which holds the tool class; this
  // generator validates the descriptor's two confirm-channel keys, and neither of those may name a
  // field only a tool's read answers. It appears here so the roster the two sides fill is one set
  // rather than two (DW-1475).
  const toolRead = [];
  return { settable, path, criteria, read, credential, toolRead };
}

/**
 * The projection roster, refused by name when this generator and the kernel do not fill the same
 * set (AD-5, AD-6) -- the shape `checkedIdRules` uses, and for the same reason: a mirror validating
 * a confirm-channel key against a set the instance does not build would refuse a sound declaration
 * at `prebuild`, or admit one the instance refuses at install.
 */
function checkedDeclaredNameKinds(kinds) {
  const declared = [...kinds].sort().join(',');
  const implemented = [...IMPLEMENTED_DECLARED_NAME_KINDS].sort().join(',');
  if (declared !== implemented) {
    throw new Error(
      `src/OcuPilot/Screen/Registry.cls: DECLAREDNAMEKINDS declares "${kinds.join(',')}" while ` +
        `ui/tools/screen-mirror.mjs builds "${IMPLEMENTED_DECLARED_NAME_KINDS.join(',')}"; the two ` +
        `confirm-channel validators would be checked against different sets, which is DW-1206's ` +
        `own cause (AD-6, AD-5)`
    );
  }
  return kinds;
}

/**
 * The self-protection roster, refused by name when the instance declares a rule this client cannot
 * draw, or cannot draw one it declares (AD-5, AD-53) -- the shape `checkedDeclaredNameKinds` uses,
 * and for the same reason: a rule only one side knows ships as a row action offered with no
 * explanation, or as a declaration the instance refuses at install.
 */
function checkedSelfProtectionRules(rules) {
  const declared = [...rules].sort().join(',');
  const implemented = [...IMPLEMENTED_SELF_PROTECTION_RULES].sort().join(',');
  if (declared !== implemented) {
    throw new Error(
      `src/OcuPilot/Screen/Registry.cls: SELFPROTECTIONRULES declares "${rules.join(',')}" while ` +
        `ui/src/app/core/self-protection.ts draws "${IMPLEMENTED_SELF_PROTECTION_RULES.join(',')}"; ` +
        `a rule only one side knows explains nothing on the row it refuses (AD-5, AD-53)`
    );
  }
  return rules;
}

/**
 * The field names `declaration`'s read declares: `read.fields`, `read.source.rowGet.fields` and
 * the `field` of each `read.source.rowGet.derived` entry.
 *
 * Read for `confirmChannelProblem` alone, and read leniently: a malformed read contributes no
 * names rather than a second refusal, because `readProblem` has already refused it.
 */
function declaredReadFields(declaration) {
  const names = [];
  const push = (value) => {
    if (!Array.isArray(value)) return;
    for (const entry of value) {
      if (typeof entry !== 'string' || entry === '') continue;
      if (!names.includes(entry)) names.push(entry);
    }
  };
  const read = declaration.read;
  if (read === undefined || read === null || typeof read !== 'object') return names;
  push(read.fields);
  const source = read.source;
  if (source === undefined || source === null || typeof source !== 'object') return names;
  const rowGet = source.rowGet;
  if (rowGet === undefined || rowGet === null || typeof rowGet !== 'object') return names;
  push(rowGet.fields);
  if (!Array.isArray(rowGet.derived)) return names;
  for (const entry of rowGet.derived) {
    if (entry === null || typeof entry !== 'object') continue;
    if (typeof entry.field !== 'string' || entry.field === '') continue;
    if (!names.includes(entry.field)) names.push(entry.field);
  }
  return names;
}

/** `declaration[key]` as an array of non-empty unique strings, or a refusal sentence. */
function stringListProblem(declaration, key) {
  const value = declaration[key];
  if (value === undefined || value === null) return [];
  if (!Array.isArray(value)) return `${key} is not an array of strings`;
  const seen = [];
  for (const entry of value) {
    if (typeof entry !== 'string' || entry === '') return `${key} holds an entry that is not a non-empty string`;
    if (seen.includes(entry)) return `${key} names '${entry}' twice`;
    seen.push(entry);
  }
  return seen;
}

/**
 * The criterion names `declaration`'s read declares: the `param` of each `criteria.fields` entry,
 * whose value a person types, and each **flag** criterion -- a member of `criteria` other than
 * `fields` declaring both a `param` and a `value`, which is the descriptor's own value and is what
 * `OcuPilot.Screen.Descriptor.Base.FlagCriteria` enumerates. De-duplicated, because a flag may send
 * its value under the same vendor parameter a typed criterion uses.
 */
function declaredCriterionParams(declaration) {
  const read = declaration.read;
  if (!isObject(read) || !isObject(read.criteria)) return [];
  const params = [];
  const push = (value) => {
    if (typeof value !== 'string' || value === '' || params.includes(value)) return;
    params.push(value);
  };
  for (const field of Array.isArray(read.criteria.fields) ? read.criteria.fields : []) {
    if (!isObject(field)) continue;
    push(field.param);
  }
  for (const [name, flag] of Object.entries(read.criteria)) {
    if (name === 'fields' || !isObject(flag)) continue;
    if (flag.value === undefined) continue;
    push(flag.param);
  }
  return params;
}

/**
 * The classified rows of the write tool `identifier` owns, as `{path: isSettableStringLiteral}`.
 * A tool name's first two segments are its screen's `toolIdentifier`.
 */
function toolFieldRows(identifier, toolFields) {
  const rows = {};
  if (typeof identifier !== 'string' || identifier === '' || !isObject(toolFields)) return rows;
  for (const [name, entry] of Object.entries(toolFields)) {
    if (name.split('.').slice(0, 2).join('.') !== identifier) continue;
    if (!isObject(entry) || !Array.isArray(entry.fields)) continue;
    for (const field of entry.fields) {
      if (!isObject(field) || typeof field.path !== 'string') continue;
      const literal = field.class === 'ordinary' && field.shape === 'literal';
      let stripped = field.path.endsWith('[]') ? field.path.slice(0, -2) : field.path;
      if (field.path.includes('.') || stripped.includes('[')) stripped = '';
      rows[field.path] = {
        settable: literal && stripped !== '',
        name: stripped,
        credential: literal && field.templateType === 'string',
      };
    }
  }
  return rows;
}

/**
 * The top-level `secret` literal rows of the write tools `identifier` owns, by name -- the third
 * source a `secretArguments` entry may name (`OcuPilot.Screen.Registry.SecretRowNames`). A nested
 * path, an array element and a row of any other class contribute nothing.
 */
export function secretRowNames(identifier, toolFields) {
  const names = [];
  if (typeof identifier !== 'string' || identifier === '' || !isObject(toolFields)) return names;
  for (const [name, entry] of Object.entries(toolFields)) {
    if (name.split('.').slice(0, 2).join('.') !== identifier) continue;
    if (!isObject(entry) || !Array.isArray(entry.fields)) continue;
    for (const field of entry.fields) {
      if (!isObject(field) || typeof field.path !== 'string') continue;
      if (field.class !== 'secret' || field.shape !== 'literal') continue;
      if (field.path.includes('.') || field.path.includes('[')) continue;
      if (!names.includes(field.path)) names.push(field.path);
    }
  }
  return names;
}

/** The first name matching the credential pattern that `secrets` does not declare, as a refusal. */
function credentialNameProblem(names, secrets, where) {
  for (const name of names) {
    if (!isCredentialName(name)) continue;
    if (secrets.includes(name)) continue;
    return (
      `${where} names '${name}', whose name matches the credential pattern and which ` +
      'secretArguments does not declare (AD-3)'
    );
  }
  return null;
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

/**
 * The four read sources, mirrored from `OcuPilot.Screen.Read`'s own parameters: `admin` is an
 * instance endpoint reached through the admin port, `state` is OcuPilot's own protected state
 * resolved against a kernel store's guarded list (AD-9), `mgmnt` is the management API reached
 * through its own port, and `logsource` is one instance log file's bounded tail read through
 * `OcuPilot.Port.LogSourcePort`, its `endpoint` a source key from that port's fixed enum (AD-21).
 * Each changes where the rows come from and nothing else -- the same fields, filter, sort, paging
 * and row cap.
 */
export const SOURCE_ADMIN = 'admin';
export const SOURCE_STATE = 'state';
export const SOURCE_MGMNT = 'mgmnt';
export const SOURCE_LOGSOURCE = 'logsource';
export const READ_SOURCE_PORTS = [SOURCE_ADMIN, SOURCE_STATE, SOURCE_MGMNT, SOURCE_LOGSOURCE];

/** The package a `state` source's `endpoint` names a store inside, trailing dot included. */
export const STATE_PACKAGE = 'OcuPilot.Kernel.State.';

/** A refusal naming the first key of `object` outside `allowed`, or `null`. */
function unknownKeyProblem(where, object, allowed) {
  const unknown = Object.keys(object).find((key) => !allowed.includes(key));
  return unknown === undefined ? null : `${where} declares the unknown key '${unknown}'`;
}

/**
 * The keys a screen declaration may carry at its top level -- the whole vocabulary, byte for byte
 * `OcuPilot.Screen.Registry`'s own `DECLARATIONKEYS` (AD-5).
 */
export const DECLARATION_KEYS = [
  'route',
  'area',
  'labelKey',
  'sideBarPosition',
  'archetype',
  'built',
  'refreshes',
  'refreshRates',
  'privileges',
  'entityType',
  'entityLabelKey',
  'secondaryEntityTypes',
  'scope',
  'parentScope',
  'id',
  'context',
  'secretArguments',
  'fingerprintExcludes',
  'primaryAction',
  'rowActions',
  'emptyStateKey',
  'commandAliases',
  'classicPage',
  'classicLinkExemption',
  'read',
  'table',
  'banner',
  'tab',
  'toolIdentifier',
  'rowTarget',
];

/**
 * What is wrong with `declaration`'s own top-level keys, or `null` (DW-271).
 *
 * **This is the only rule a misspelt top-level key can trip, in either engine.** Every other rule
 * reads a key by name, and the emission below is an unconstrained spread -- so `banners` validated,
 * mirrored verbatim into `screens.generated.ts`, and shipped a screen whose strip never raises.
 * Unknown-key only, never presence: five keys are optional, and two ObjectScript fixtures build
 * twenty-key declarations to drive other refusals.
 */
export function declarationProblem(declaration) {
  if (declaration === null || typeof declaration !== 'object' || Array.isArray(declaration)) {
    return 'the declaration is not an object';
  }
  return unknownKeyProblem('the declaration', declaration, DECLARATION_KEYS);
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
 * What is wrong with `context`'s `maxLength` map, or `null` (AD-24, Story 4.4). Optional; when
 * declared it is an object whose every key is one of `fields` and whose every value is a whole
 * number from 1 to 1,000 -- the same bound the kernel cutter enforces by default, so a declared
 * value can only lower it, never raise it. `OcuPilot.Screen.Registry.ContextMaxLengthProblem`
 * refuses the same shapes on the instance.
 */
function contextMaxLengthProblem(context, fields) {
  if (context.maxLength === undefined || context.maxLength === null) return null;
  const { maxLength } = context;
  if (maxLength === null || typeof maxLength !== 'object' || Array.isArray(maxLength)) {
    return 'context.maxLength is not an object';
  }
  for (const [key, value] of Object.entries(maxLength)) {
    if (!fields.includes(key)) return `context.maxLength names '${key}', which is not in context.fields`;
    if (typeof value !== 'number' || !Number.isInteger(value) || value < 1 || value > 1000) {
      return `context.maxLength.${key} is not a whole number from 1 to 1,000`;
    }
  }
  return null;
}

/**
 * What is wrong with a **built** declaration's `sideBarPosition`, or `null` when nothing is: it
 * must be declared, a number, a whole number, and at least 0.
 *
 * **0 means routable but not listed** (Story 3.5). `OcuPilot.Screen.Descriptor.Base` reads the key
 * as `+..Field(...)`, so an absent one already answers 0 -- which, once 0 is a sentinel, silently
 * unlists any descriptor that forgets to declare it. Refusing an undeclared key is what makes the
 * sentinel a decision rather than an accident. An unbuilt screen is exempt: nothing lists it and
 * nothing routes it, so its position says nothing yet.
 *
 * `OcuPilot.Screen.Registry.SideBarPositionProblem` refuses the same shapes on the instance.
 */
export function sideBarPositionProblem(declaration) {
  if (declaration.built !== true) return null;
  const value = declaration.sideBarPosition;
  if (typeof value !== 'number') {
    return (
      'sideBarPosition is not declared as a number, and an absent key would silently unlist a ' +
      'built screen (AD-5)'
    );
  }
  if (!Number.isInteger(value) || value < 0) {
    return (
      `sideBarPosition '${value}' is not a whole number of at least 0, where 0 means routable ` +
      'but not listed'
    );
  }
  return null;
}

/**
 * What is wrong with a declaration's `read`, or `null` when nothing is (AD-36).
 *
 * The rules `OcuPilot.Screen.Registry.ReadProblem` applies on the instance: an absent or `null`
 * read is a screen with no read; otherwise `source` is `{port, endpoint, type}`, `type` one of
 * `READ_SOURCE_TYPES`. `GET`, `UPCOMING`, `HISTORY` and `VOLUMELIST` are admin only and declare no
 * `forEach`; `UPCOMING`, `HISTORY` and `VOLUMELIST` also declare no `rowGet`, and so does `GET` unless `parentScope` names
 * the route its one route-id criterion is fetched under, in which case it may pair one `rowGet`
 * keyed by that criterion's own param (Story 6.7). An optional `query` fixes parameters
 * (`sourceQueryProblem`). The source is one of three kinds:
 * `admin`, an instance endpoint reached through the port, with a dotted
 * endpoint name and an optional `rowGet` (`rowGetProblem`); `mgmnt`, the management API reached
 * through its own port, which declares no `rowGet`; or `state`, one of OcuPilot's own kernel stores
 * named without a package, which declares neither a `rowGet` nor `criteria`.
 * `fields` is non-empty and unique, `filter`, `sort.fields` and `context.secretFields` name only
 * declared fields, no secret field is filterable or sortable, `sort.default` is a sort field,
 * `sort.direction` is `asc` or `desc`, `paging` is `cap` (no LIST accepts a cursor), and the
 * `toolIdentifier` is `<area>.<screen>` in lower case. `read`, `read.source`, `read.sort` and
 * `context` carry only their declared keys, and `context.secretFields` is declared, so a misspelt
 * key is refused rather than read as no secret field. A read declares its table (`tableProblem`)
 * unless it is a `form-page` that declares none (`rendersNoTable`), and a table with no read is
 * refused. Last of all, a read on the `admin` port whose `privileges`
 * omit `%DB_IRISSYS:READ` is refused, because the port runs every endpoint in `%SYS` -- a `state`
 * read runs in the install namespace and needs no such pair, so the rule is on the source kind
 * rather than on every read; `OcuPilot.Test.AdminPairCorpus` is the corpus both engines run.
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
  const readKeysFault = unknownKeyProblem('read', read, ['source', 'fields', 'filter', 'sort', 'paging', 'criteria']);
  if (readKeysFault !== null) return readKeysFault;
  const source = read.source;
  if (source === null || typeof source !== 'object' || Array.isArray(source)) {
    return 'read.source is not an object naming its port, endpoint and type (AD-36)';
  }
  const sourceKeysFault = unknownKeyProblem('read.source', source, ['port', 'endpoint', 'type', 'rowGet', 'forEach', 'query', 'parts']);
  if (sourceKeysFault !== null) return sourceKeysFault;
  if (!READ_SOURCE_PORTS.includes(source.port)) {
    return (
      `read.source.port '${shown(source.port)}' is not one of '${SOURCE_ADMIN}', '${SOURCE_STATE}', ` +
      `'${SOURCE_MGMNT}' or '${SOURCE_LOGSOURCE}', the four sources a declared read names (AD-36)`
    );
  }
  if (typeof source.endpoint !== 'string' || !ENDPOINT_RE.test(source.endpoint)) {
    return `read.source.endpoint '${source.endpoint}' is not a package-relative endpoint name`;
  }
  if (source.port === SOURCE_STATE && source.endpoint.includes('.')) {
    return (
      `read.source.endpoint '${source.endpoint}' names a package, and a state source names a ` +
      `store inside ${STATE_PACKAGE} by its own name alone (AD-9)`
    );
  }
  if (typeof source.type !== 'string' || !READ_SOURCE_TYPES.includes(source.type)) {
    return `read.source.type '${shown(source.type)}' is not 'LIST', 'GET', 'UPCOMING', 'HISTORY' or 'VOLUMELIST'`;
  }
  // A GET source reads one named object of an admin endpoint as the read's one row (AD-36), so it
  // lists no parents. It may take its one criterion from the route id, and pair a rowGet keyed by
  // that criterion's own param, only when parentScope names the route it is fetched under (Story
  // 6.7); every other GET refuses both, having no row list to issue a detail call for and no
  // server search of its own.
  if (source.type === 'GET') {
    if (source.port !== SOURCE_ADMIN) {
      return `read.source.type 'GET' is declared on a '${source.port}' source, and a single-object read issues an admin endpoint's GET (AD-36)`;
    }
    if (isObject(source.forEach)) {
      return 'read.source.forEach is declared on a GET source, which reads one object and lists no parents (AD-36)';
    }
    const getParented = typeof declaration.parentScope === 'string' && declaration.parentScope !== '';
    if (isObject(read.criteria) && !getParented) {
      return "read.criteria is declared on a GET source with no parentScope, and a single-object read takes its one criterion from the route id only when parent-scoped (AD-36, Story 6.7)";
    }
    if (!isObject(read.criteria) && isObject(source.rowGet)) {
      return "read.source.rowGet is declared on a GET source with no read.criteria, and a single-object read issues a detail call only alongside its one parent-scoped route-id criterion (AD-36, Story 6.7)";
    }
  }
  // An UPCOMING source lists an admin endpoint's scheduled occurrences (AD-36): a row is an
  // occurrence rather than an object, so there is no detail call to issue and no parent to list.
  if (source.type === 'UPCOMING') {
    if (source.port !== SOURCE_ADMIN) {
      return `read.source.type 'UPCOMING' is declared on a '${source.port}' source, and a list-shaped request type other than LIST issues an admin endpoint (AD-36)`;
    }
    if (isObject(source.rowGet)) {
      return 'read.source.rowGet is declared on an UPCOMING source, whose rows are occurrences with no detail call to issue (AD-36)';
    }
    if (isObject(source.forEach)) {
      return 'read.source.forEach is declared on an UPCOMING source, which lists no parents (AD-36)';
    }
  }
  // A HISTORY source lists an admin endpoint's task-run history (AD-36), Task.CRUD's own request
  // type: a row is a run rather than an object, so there is no detail call to issue and no parent
  // to list -- the same rules UPCOMING takes, for the same reason.
  if (source.type === 'HISTORY') {
    if (source.port !== SOURCE_ADMIN) {
      return `read.source.type 'HISTORY' is declared on a '${source.port}' source, and a list-shaped request type other than LIST issues an admin endpoint (AD-36)`;
    }
    if (isObject(source.rowGet)) {
      return 'read.source.rowGet is declared on a HISTORY source, whose rows are task runs with no detail call to issue (AD-36)';
    }
    if (isObject(source.forEach)) {
      return 'read.source.forEach is declared on a HISTORY source, which lists no parents (AD-36)';
    }
  }
  // A VOLUMELIST source lists an admin endpoint's volume files (AD-36, Story 6.11):
  // Database.SysCRUD's own request type, worded like the HISTORY arm above for the same reason --
  // a row is a volume file rather than an object, so there is no detail call to issue and no parent
  // to list.
  if (source.type === 'VOLUMELIST') {
    if (source.port !== SOURCE_ADMIN) {
      return `read.source.type 'VOLUMELIST' is declared on a '${source.port}' source, and a list-shaped request type other than LIST issues an admin endpoint (AD-36)`;
    }
    if (isObject(source.rowGet)) {
      return 'read.source.rowGet is declared on a VOLUMELIST source, whose rows are volume files with no detail call to issue (AD-36)';
    }
    if (isObject(source.forEach)) {
      return 'read.source.forEach is declared on a VOLUMELIST source, which lists no parents (AD-36)';
    }
  }
  const queryFault = sourceQueryProblem(read, source);
  if (queryFault !== null) return queryFault;
  // A mgmnt source answers whole rows from the management API, which offers no per-row detail call
  // to issue.
  if (source.port === SOURCE_MGMNT && isObject(source.rowGet)) {
    return (
      'read.source.rowGet is declared on a mgmnt source, which reads whole rows from the management ' +
      'API and has no per-row detail call (AD-36)'
    );
  }
  // A logsource source answers whole rows parsed from one log file's tail, which has no per-row
  // detail call to issue: a log line is not an entity the instance can be asked for.
  if (source.port === SOURCE_LOGSOURCE && isObject(source.rowGet)) {
    return (
      'read.source.rowGet is declared on a logsource source, which reads whole rows from a log ' +
      "file's bounded tail and has no per-row detail call (AD-36)"
    );
  }
  // A state source's rows are OcuPilot's own, read whole: there is no detail endpoint to issue per
  // row and no vendor query to search on the server, so declaring either is refused where it is
  // declared rather than ignored at read time (AD-36).
  if (source.port === SOURCE_STATE) {
    if (isObject(source.rowGet)) {
      return (
        'read.source.rowGet is declared on a state source, which reads whole rows from a kernel ' +
        'store and has no per-row detail call (AD-36)'
      );
    }
    if (isObject(read.criteria)) {
      return (
        'read.criteria is declared on a state source, whose rows are filtered and sorted in one ' +
        'view rule rather than searched on a vendor query (AD-21, AD-36)'
      );
    }
  }

  const fieldsFault = nameListProblem('read.fields', read.fields);
  if (fieldsFault !== null) return fieldsFault;
  if (read.fields.length === 0) return 'read.fields is empty, and a read projects at least one field';
  // Story 6.7: a parent-scoped GET's rowGet.key names the read's one route-id criterion rather
  // than a read.fields entry. The allowed set is that one param exactly when the criteria block is
  // sound enough to name it; a malformed block leaves this empty, and rowGetProblem falls back to
  // checking key against read.fields, which still refuses -- criteriaProblem is what names the
  // malformed block itself.
  let rowGetKeyAllowed = [];
  if (source.type === 'GET' && isObject(read.criteria) && Array.isArray(read.criteria.fields) && read.criteria.fields.length === 1) {
    const first = read.criteria.fields[0];
    if (isObject(first) && typeof first.param === 'string') rowGetKeyAllowed = [first.param];
  }
  const rowGetFault = rowGetProblem(source, read.fields, rowGetKeyAllowed);
  if (rowGetFault !== null) return rowGetFault;
  const forEachFault = forEachProblem(read, source, read.fields);
  if (forEachFault !== null) return forEachFault;
  // AD-36 (Story 6.9): a single-object GET may also declare up to three parts, each answering one
  // object merged into the read's one row as <as>.<member> fields.
  const partsFault = partsProblem(read, source, read.fields);
  if (partsFault !== null) return partsFault;

  const { context } = declaration;
  if (context === null || typeof context !== 'object' || Array.isArray(context)) {
    return 'context is not an object, and a screen that declares a read declares its secret fields (AD-24)';
  }
  const contextFault =
    unknownKeyProblem('context', context, ['fields', 'secretFields', 'maxLength']) ??
    nameListProblem('context.secretFields', context.secretFields, read.fields) ??
    contextMaxLengthProblem(context, Array.isArray(context.fields) ? context.fields : []);
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
    return "read.paging 'cursor' is refused: neither declared source kind accepts a cursor; declare 'cap' (AD-36)";
  }
  if (read.paging !== 'cap') return `read.paging '${read.paging}' is not 'cap'`;
  if (typeof declaration.toolIdentifier !== 'string' || !READ_TOOL_IDENTIFIER_RE.test(declaration.toolIdentifier)) {
    return (
      `toolIdentifier '${declaration.toolIdentifier}' declares a read and is not <area>.<screen> in ` +
      'lower case, so its read tool could not be named <area>.<screen>.read'
    );
  }
  const tableFault = rendersNoTable(declaration) ? null : tableProblem(declaration, read.fields, secrets);
  if (tableFault !== null) return tableFault;

  // The last arm, so no earlier refusal changes which sentence a declaration gets.
  // `OcuPilot.Port.AdminPort.RunSequence` sets `$NAMESPACE` to `%SYS` for every request type with
  // no predicate on the endpoint, and IRIS requires READ on a namespace's default globals
  // database -- IRISSYS, resource `%DB_IRISSYS` -- to make it current. Without the pair the vendor
  // endpoint fails inside `%SYS` and the port answers 500 where the gate would have named the
  // missing privilege (AD-2, AD-8). A logsource read is outside the rule: it reads a file off disk
  // and never enters `%SYS`.
  if (source.port === SOURCE_ADMIN && !declaresSystemRead(declaration.privileges)) {
    return (
      "read.source.port 'admin' requires the declared privileges to include %DB_IRISSYS:READ, " +
      'because the port runs every endpoint in %SYS (AD-2, AD-8)'
    );
  }
  return null;
}

/** Whether `privileges` declares the `%DB_IRISSYS` / `READ` pair. */
function declaresSystemRead(privileges) {
  if (!Array.isArray(privileges)) return false;
  return privileges.some(
    (pair) => isObject(pair) && pair.resource === '%DB_IRISSYS' && pair.permission === 'READ'
  );
}

/**
 * The severities a declared banner may take: the three `ui/src/styles/_components.scss` gives a
 * `.ocu-banner-*` variant (DESIGN.md `:1203`). A severity outside them would render an unstyled
 * strip, so the set is what the client can actually draw rather than the document's whole variant
 * list.
 */
export const BANNER_SEVERITIES = ['info', 'warning', 'restrained'];

/**
 * A declared value as the refusal sentences spell it: the value itself, and `''` for an absent or
 * `null` one. `%Get` answers `""` for both on the instance, so this is what keeps the two engines'
 * sentences byte-identical over the shapes `OcuPilot.Test.BannerCorpus` carries.
 */
function shown(value) {
  return value === undefined || value === null ? '' : String(value);
}

/**
 * What is wrong with a declaration's `banner`, or `null` when nothing is.
 *
 * The rules `OcuPilot.Screen.Registry.BannerProblem` applies on the instance: an absent or `null`
 * banner is a screen with no banner; otherwise it is an object carrying only `source`, `field` and
 * `cases`; `source` carries only `port` (`admin`), `endpoint` (a package-relative name) and `type`
 * (`GET`); `field` is a non-empty string; `cases` is a non-empty array of objects carrying only
 * `equals`, `messageKey` and `severity`, each `equals` and `messageKey` a non-empty string, each
 * `equals` declared once, each `severity` one of `BANNER_SEVERITIES`; and, last of all, a banner
 * declared while `read` is not is refused, because a banner is chrome on a declared read's screen
 * and rides in that read's own response. `OcuPilot.Test.BannerCorpus` is the corpus both engines
 * run.
 *
 * **One read, many cases** (DW-270): a field with a closed set of values usually has more than one
 * state worth a strip, and a second banner would have meant a second port call per read.
 */
export function bannerProblem(declaration) {
  const { banner } = declaration;
  if (banner === undefined || banner === null) return null;
  if (!isObject(banner)) return 'banner is not an object naming its source, field and cases';
  const keysFault = unknownKeyProblem('banner', banner, ['source', 'field', 'cases']);
  if (keysFault !== null) return keysFault;

  const source = banner.source;
  if (!isObject(source)) return 'banner.source is not an object naming its port, endpoint and type';
  const sourceKeysFault = unknownKeyProblem('banner.source', source, ['port', 'endpoint', 'type']);
  if (sourceKeysFault !== null) return sourceKeysFault;
  if (source.port !== 'admin') {
    return `banner.source.port '${shown(source.port)}' is not 'admin', the one port a Release 1 read names (AD-2)`;
  }
  if (typeof source.endpoint !== 'string' || !ENDPOINT_RE.test(source.endpoint)) {
    return `banner.source.endpoint '${shown(source.endpoint)}' is not a package-relative endpoint name`;
  }
  if (source.type !== 'GET') return `banner.source.type '${shown(source.type)}' is not 'GET'`;

  if (typeof banner.field !== 'string' || banner.field === '') {
    return 'banner.field is empty, and a banner compares one named field to the values its cases name';
  }

  const casesFault = bannerCasesProblem(banner);
  if (casesFault !== null) return casesFault;

  const { read } = declaration;
  if (read === undefined || read === null) return "a banner is chrome on a declared read's screen (AD-36)";
  return null;
}

/** What is wrong with a banner's `cases`, or `null` (DW-270). */
function bannerCasesProblem(banner) {
  if (!Array.isArray(banner.cases)) return 'banner.cases is not an array of banner cases';
  if (banner.cases.length === 0) {
    return 'banner.cases is empty, and a declared banner raises at least one sentence';
  }
  const seen = new Set();
  for (let index = 0; index < banner.cases.length; index += 1) {
    const entry = banner.cases[index];
    const where = `banner.cases entry #${index + 1}`;
    if (!isObject(entry)) return `${where} is not an object declaring its equals, messageKey and severity`;
    const entryKeysFault = unknownKeyProblem(where, entry, ['equals', 'messageKey', 'severity']);
    if (entryKeysFault !== null) return entryKeysFault;
    for (const key of ['equals', 'messageKey']) {
      if (typeof entry[key] !== 'string' || entry[key] === '') {
        return (
          `${where} ${key} is empty, and a case names the one value it raises on and the string ` +
          'key it raises'
        );
      }
    }
    if (seen.has(entry.equals)) return `${where} names the value '${entry.equals}' twice`;
    seen.add(entry.equals);
    if (typeof entry.severity !== 'string' || !BANNER_SEVERITIES.includes(entry.severity)) {
      return `${where} severity '${shown(entry.severity)}' is not one of ${BANNER_SEVERITIES.join(',')}`;
    }
  }
  return null;
}

/** The kinds a declared server-search criterion may take (AD-21). */
export const CRITERION_KINDS = ['text', 'datetime', 'choice'];

/**
 * The names a read's own two callers already send, which no criterion may claim: the row cap the
 * executor sends itself, the read tool's three arguments (a criterion of one of those names would
 * replace that schema property, losing `sort`'s declared enum), and the scope key `api.ts` appends
 * to every request. Compared case-folded, because the vendor upper-cases query keys.
 */
export const CRITERIA_RESERVED_PARAMS = ['maxRows', 'filter', 'sort', 'direction', 'ns'];

/**
 * What is wrong with a declaration's `read.criteria`, or `null` when nothing is (AD-21).
 *
 * The rules `OcuPilot.Screen.Registry.CriteriaProblem` applies on the instance: a read with no
 * `criteria` declares none; otherwise `criteria` is an object carrying only `fields` and `marker`,
 * on an `admin` or `mgmnt` source; `fields` is a non-empty array of objects carrying only `param` (a query
 * parameter name, unique and never one of `CRITERIA_RESERVED_PARAMS`), a non-empty `labelKey` and a `kind` from
 * `CRITERION_KINDS`, plus `options` -- a non-empty array of unique non-empty strings -- exactly
 * when `kind` is `choice`; `marker`, when declared, carries only `param` (one of the declared
 * criteria), a non-empty `value` and a non-empty `labelKey`; a declaration with a non-empty
 * `parentScope` and a read declares exactly one criterion (AD-5), which may auto-refresh in place
 * since it takes its one value from the route rather than from a search the user ran (Story 6.7);
 * any other criteria-bearing declaration does not declare `refreshes` (AD-43). `OcuPilot.Test.CriteriaCorpus` is the corpus both engines
 * run.
 *
 * The roster is the allow-list a route and a read tool are both filtered through, which is why a
 * misdeclaration is a build refusal rather than a render-time surprise: a dropped entry is a
 * parameter the screen silently stops sending.
 */
export function criteriaProblem(declaration) {
  const { read } = declaration;
  if (!isObject(read)) return null;
  const parented = typeof declaration.parentScope === 'string' && declaration.parentScope !== '';
  const { criteria } = read;
  if (criteria === undefined || criteria === null) return parented ? parentCriteriaProblem(declaration) : null;
  if (!isObject(criteria)) return 'read.criteria is not an object declaring its fields and marker (AD-21)';
  const keysFault = unknownKeyProblem('read.criteria', criteria, ['fields', 'marker']);
  if (keysFault !== null) return keysFault;

  const port = isObject(read.source) ? read.source.port : undefined;
  if (port !== SOURCE_ADMIN && port !== SOURCE_MGMNT) {
    return `read.criteria is declared on a '${shown(port)}' source, and server criteria travel on the admin and mgmnt ports alone (AD-21)`;
  }

  const params = [];
  const fieldsFault = criteriaFieldsProblem(criteria, params);
  if (fieldsFault !== null) return fieldsFault;
  const vendorParamFault = criteriaVendorParamProblem(criteria);
  if (vendorParamFault !== null) return vendorParamFault;
  const markerFault = criteriaMarkerProblem(criteria, params);
  if (markerFault !== null) return markerFault;
  if (parented && params.length !== 1) return parentCriteriaProblem(declaration);

  // The last arm, so no earlier refusal changes which sentence a declaration gets. A
  // parent-scoped screen's only criterion is the route id rather than a server search -- already
  // confirmed above, since `parented` reaching here means exactly one criterion -- so it may
  // refresh in place (Story 6.7).
  if (declaration.refreshes === true && !parented) {
    return (
      'refreshes is declared with read.criteria, and a screen that searches on the server renders ' +
      'nothing until Search and does not auto-refresh (AD-43)'
    );
  }
  return null;
}

/**
 * The one sentence a parent-scoped read that does not declare exactly one criterion is refused with
 * (AD-5): the client fills that criterion from the route id, so none leaves the read unscoped and a
 * second has no value to take. `OcuPilot.Screen.Registry.ParentCriteriaProblem` returns the same.
 */
function parentCriteriaProblem(declaration) {
  return (
    `parentScope '${declaration.parentScope}' is declared with a read, and a parent-scoped read ` +
    'declares exactly one read.criteria field, which its route id fills (AD-5)'
  );
}

/** What is wrong with `criteria.fields`, or `null`. Declared parameter names are pushed onto `params`. */
function criteriaFieldsProblem(criteria, params) {
  if (!Array.isArray(criteria.fields)) return 'read.criteria.fields is not an array of criterion declarations';
  if (criteria.fields.length === 0) {
    return 'read.criteria.fields is empty, and a declared criteria block carries at least one criterion (AD-21)';
  }
  const seen = new Set();
  for (let index = 0; index < criteria.fields.length; index += 1) {
    const field = criteria.fields[index];
    const where = `read.criteria.fields entry #${index + 1}`;
    if (!isObject(field)) return `${where} is not an object declaring its param, labelKey and kind`;
    const allowed =
      field.kind === 'choice'
        ? ['param', 'labelKey', 'kind', 'maxLength', 'vendorParam', 'options']
        : ['param', 'labelKey', 'kind', 'maxLength', 'vendorParam'];
    const fieldKeysFault = unknownKeyProblem(where, field, allowed);
    if (fieldKeysFault !== null) return fieldKeysFault;

    if (typeof field.param !== 'string' || !PARAM_RE.test(field.param)) {
      return `${where} param '${shown(field.param)}' is not a query parameter name`;
    }
    const folded = field.param.toLowerCase();
    if (CRITERIA_RESERVED_PARAMS.some((name) => name.toLowerCase() === folded)) {
      return `${where} param '${field.param}' collides with a name the read's own callers already send`;
    }
    if (seen.has(folded)) return `${where} names the param '${field.param}' twice`;
    seen.add(folded);
    params.push(field.param);

    // Story 6.6: a criterion may send its value to the vendor under a declared name of its own,
    // because the vendor's own name is reserved for the read's two callers. Only shape and the two
    // names every read's own machinery sends are checked here; a collision with another field's
    // param or vendorParam is checked once every field is known (criteriaVendorParamProblem).
    if (field.vendorParam !== undefined) {
      if (typeof field.vendorParam !== 'string' || !PARAM_RE.test(field.vendorParam)) {
        return `${where} vendorParam '${shown(field.vendorParam)}' is not a query parameter name`;
      }
      const vendorFolded = field.vendorParam.toLowerCase();
      if (vendorFolded === 'maxrows' || vendorFolded === 'ns') {
        return `${where} vendorParam '${field.vendorParam}' collides with a name the read's own callers already send`;
      }
    }

    if (typeof field.labelKey !== 'string' || field.labelKey === '') {
      return `${where} labelKey is empty, and a criterion's control names a string key`;
    }
    if (typeof field.kind !== 'string' || !CRITERION_KINDS.includes(field.kind)) {
      return `${where} kind '${shown(field.kind)}' is not one of ${CRITERION_KINDS.join(',')}`;
    }
    const maxLengthFault = criteriaMaxLengthProblem(field, where);
    if (maxLengthFault !== null) return maxLengthFault;
    if (field.kind !== 'choice') continue;
    const optionsFault = criteriaOptionsProblem(field, where);
    if (optionsFault !== null) return optionsFault;
  }
  return null;
}

/**
 * What is wrong with a criterion's `maxLength`, or `null`: a whole number above zero, declared on
 * every criterion whatever its kind (DW-279).
 *
 * Required rather than optional, for the reason
 * `OcuPilot.Screen.Registry.CriteriaMaxLengthProblem` records: the vendor property is what bounds
 * the value in the end, and a criterion declaring no bound is one no refusal could be written for,
 * so the over-long value would fault inside the port instead of being refused by name.
 */
function criteriaMaxLengthProblem(field, where) {
  if (field.maxLength === undefined) {
    return `${where} declares no maxLength, and every criterion declares the length its vendor property accepts (AD-21)`;
  }
  const value = field.maxLength;
  if (typeof value !== 'number' || !Number.isInteger(value) || value <= 0) {
    return `${where} maxLength '${shown(value)}' is not a whole number above zero`;
  }
  return null;
}

/** What is wrong with a `choice` criterion's `options`, or `null`. */
function criteriaOptionsProblem(field, where) {
  if (!Array.isArray(field.options)) {
    return `${where} kind 'choice' declares no options, and a choice criterion is validated against a declared enum (AD-21)`;
  }
  if (field.options.length === 0) {
    return `${where} options is empty, and a choice criterion is validated against a declared enum (AD-21)`;
  }
  const seen = new Set();
  for (let index = 0; index < field.options.length; index += 1) {
    const option = field.options[index];
    if (typeof option !== 'string' || option === '') {
      return `${where} options entry #${index + 1} is not a non-empty value`;
    }
    if (seen.has(option)) return `${where} options names '${option}' twice`;
    seen.add(option);
  }
  return null;
}

/**
 * What is wrong with `criteria`'s declared `vendorParam`s taken together, or `null` (Story 6.6).
 * Each field's own shape is already sound (`criteriaFieldsProblem`); this is the one check that
 * needs every field's name known first -- a `vendorParam` may not equal, case-folded, another
 * field's `param` or `vendorParam`, because both values reach the same vendor query and a
 * collision would let one field's value silently overwrite another's.
 * `OcuPilot.Screen.Registry.CriteriaVendorParamProblem` returns the same sentence.
 */
function criteriaVendorParamProblem(criteria) {
  const fields = criteria.fields;
  if (!Array.isArray(fields)) return null;
  for (let outer = 0; outer < fields.length; outer += 1) {
    const outerField = fields[outer];
    if (!isObject(outerField) || typeof outerField.vendorParam !== 'string' || outerField.vendorParam === '') {
      continue;
    }
    const vendorFolded = outerField.vendorParam.toLowerCase();
    for (let inner = 0; inner < fields.length; inner += 1) {
      if (inner === outer) continue;
      const innerField = fields[inner];
      if (!isObject(innerField)) continue;
      const sameParam =
        typeof innerField.param === 'string' && innerField.param !== '' && innerField.param.toLowerCase() === vendorFolded;
      const sameVendorParam =
        typeof innerField.vendorParam === 'string' &&
        innerField.vendorParam !== '' &&
        innerField.vendorParam.toLowerCase() === vendorFolded;
      if (sameParam || sameVendorParam) {
        return (
          `read.criteria.fields entry #${outer + 1} vendorParam '${outerField.vendorParam}' collides with ` +
          "another field's param or vendorParam"
        );
      }
    }
  }
  return null;
}

/** What is wrong with `criteria.marker`, or `null`. `params` is the declared parameter names. */
function criteriaMarkerProblem(criteria, params) {
  const { marker } = criteria;
  if (marker === undefined || marker === null) return null;
  if (!isObject(marker)) return 'read.criteria.marker is not an object declaring its param, value and labelKey';
  const keysFault = unknownKeyProblem('read.criteria.marker', marker, ['param', 'value', 'labelKey']);
  if (keysFault !== null) return keysFault;
  if (typeof marker.param !== 'string' || !params.includes(marker.param)) {
    return (
      `read.criteria.marker.param '${shown(marker.param)}' is not one of read.criteria.fields, and the ` +
      'marker overrides a declared criterion rather than adding one'
    );
  }
  if (typeof marker.value !== 'string' || marker.value === '') {
    return 'read.criteria.marker.value is empty, and the marker filter sends one declared value';
  }
  if (typeof marker.labelKey !== 'string' || marker.labelKey === '') {
    return 'read.criteria.marker.labelKey is empty, and the marker filter names a string key';
  }
  return null;
}

/**
 * The request types a `read.source` may issue (AD-36), byte for byte `OcuPilot.Screen.Registry`'s own
 * `READSOURCETYPES`: `LIST`, a list of rows; `GET`, one object read as the read's one row;
 * `UPCOMING`, an admin endpoint's list of scheduled occurrences, issued as a list is;
 * `HISTORY`, `Task.CRUD`'s task-run history, issued the same way (Story 6.6); and `VOLUMELIST`,
 * `Database.SysCRUD`'s volume-file list, issued the same way again (Story 6.11).
 */
export const READ_SOURCE_TYPES = ['LIST', 'GET', 'UPCOMING', 'HISTORY', 'VOLUMELIST'];

/** The longest value a `read.source.query` entry may fix, `OcuPilot.Screen.Registry`'s `SOURCEQUERYMAXLENGTH`. */
export const SOURCE_QUERY_MAX_LENGTH = 50;

/**
 * What is wrong with `source.query`, or `null` (AD-36). `read` is the declared read, whose `criteria`
 * the keys are compared to.
 *
 * An absent or `null` `query` fixes no parameter. Otherwise it is a non-empty object on an `admin`
 * source; each key is a query parameter name that equals, case-folded, neither a
 * `CRITERIA_RESERVED_PARAMS` name nor a declared `read.criteria` field's `param` or `vendorParam`;
 * and each value is a non-empty string of at most `SOURCE_QUERY_MAX_LENGTH` characters.
 * `OcuPilot.Screen.Read.Execute` sends every
 * entry on the read's `LIST`, `UPCOMING` or `HISTORY` call, on a single-object `GET` and on each per-parent child
 * list, never on a per-parent read's parent list or a `rowGet` detail call, so no caller can change or
 * remove one.
 * `OcuPilot.Screen.Registry.SourceQueryProblem` returns the same sentence for every case in
 * `OcuPilot.Test.ReadSourceCorpus`.
 */
export function sourceQueryProblem(read, source) {
  const where = 'read.source.query';
  const { query } = source;
  if (query === undefined || query === null) return null;
  if (!isObject(query)) return `${where} is not an object of fixed query parameters (AD-36)`;
  if (source.port !== SOURCE_ADMIN) {
    return `${where} is declared on a '${shown(source.port)}' source, and fixed query parameters travel on admin endpoints (AD-36)`;
  }
  const keys = Object.keys(query);
  if (keys.length === 0) return `${where} is empty, and a declared query fixes at least one parameter (AD-36)`;
  const criteriaParams = [];
  if (isObject(read.criteria) && Array.isArray(read.criteria.fields)) {
    for (const field of read.criteria.fields) {
      if (!isObject(field)) continue;
      if (typeof field.param === 'string') criteriaParams.push(field.param.toLowerCase());
      if (typeof field.vendorParam === 'string') criteriaParams.push(field.vendorParam.toLowerCase());
    }
  }
  for (const key of keys) {
    if (!PARAM_RE.test(key)) return `${where} key '${key}' is not a query parameter name`;
    const folded = key.toLowerCase();
    if (CRITERIA_RESERVED_PARAMS.some((name) => name.toLowerCase() === folded)) {
      return `${where} key '${key}' collides with a name the read's own callers already send`;
    }
    if (criteriaParams.includes(folded)) {
      return `${where} key '${key}' is also a read.criteria param, and no caller can change a fixed parameter (AD-36)`;
    }
    const value = query[key];
    if (typeof value !== 'string' || value === '' || value.length > SOURCE_QUERY_MAX_LENGTH) {
      return `${where} '${key}' is not a non-empty string of at most ${SOURCE_QUERY_MAX_LENGTH} characters`;
    }
  }
  return null;
}

/**
 * What is wrong with `source.forEach`, or `null` (AD-36). `read` is the declared read and `fields`
 * its declared fields.
 *
 * An absent or `null` `forEach` lists no parents. Otherwise it is an object carrying only `endpoint`
 * (the parent endpoint), `key` (the parent row field each child list is read for), `param` (the query
 * parameter that key's text is sent as, equal, case-folded, to no `source.query` key) and `fields`, an array of objects carrying only `field` (one of
 * `fields`, not repeated) and `from` (the parent row field copied into it), declared on an `admin`
 * `LIST` source with no `rowGet` and no `criteria`. `OcuPilot.Screen.Registry.ForEachProblem` returns
 * the same sentence for every case in `OcuPilot.Test.ReadSourceCorpus`.
 */
export function forEachProblem(read, source, fields) {
  const where = 'read.source.forEach';
  const { forEach } = source;
  if (forEach === undefined || forEach === null) return null;
  if (!isObject(forEach)) return `${where} is not an object declaring its endpoint, key, param and fields (AD-36)`;
  const keysFault = unknownKeyProblem(where, forEach, ['endpoint', 'key', 'param', 'fields']);
  if (keysFault !== null) return keysFault;
  if (source.port !== SOURCE_ADMIN) {
    return `${where} is declared on a '${shown(source.port)}' source, and a per-parent list issues admin endpoints (AD-36)`;
  }
  if (isObject(source.rowGet)) {
    return `${where} is declared with read.source.rowGet, and a per-parent list copies its parent's fields rather than a detail call's (AD-36)`;
  }
  if (isObject(read.criteria)) {
    return `${where} is declared with read.criteria, and a per-parent list sets its one parameter from each parent (AD-36)`;
  }
  if (typeof forEach.endpoint !== 'string' || !ENDPOINT_RE.test(forEach.endpoint)) {
    return `${where}.endpoint '${shown(forEach.endpoint)}' is not a package-relative endpoint name`;
  }
  if (typeof forEach.key !== 'string' || forEach.key === '') {
    return `${where}.key is empty, and a per-parent list reads each parent's key by name`;
  }
  if (typeof forEach.param !== 'string' || !PARAM_RE.test(forEach.param)) {
    return `${where}.param '${shown(forEach.param)}' is not a query parameter name`;
  }
  if (isObject(source.query) && Object.keys(source.query).some((key) => key.toLowerCase() === forEach.param.toLowerCase())) {
    return `${where}.param '${forEach.param}' is also a read.source.query key, which each child list would overwrite (AD-36)`;
  }
  if (!Array.isArray(forEach.fields)) return `${where}.fields is not an array of parent fields`;
  const seen = [];
  for (let index = 0; index < forEach.fields.length; index += 1) {
    const entry = forEach.fields[index];
    const at = `${where}.fields entry #${index + 1}`;
    if (!isObject(entry)) return `${at} is not an object declaring its field and from`;
    const entryKeysFault = unknownKeyProblem(at, entry, ['field', 'from']);
    if (entryKeysFault !== null) return entryKeysFault;
    if (typeof entry.field !== 'string' || !fields.includes(entry.field)) {
      return `${at} field '${shown(entry.field)}' is not one of read.fields`;
    }
    if (seen.includes(entry.field)) return `${at} names the field '${entry.field}' twice`;
    seen.push(entry.field);
    if (typeof entry.from !== 'string' || entry.from === '') {
      return `${at} from is empty, and a parent field is copied from a named key of the parent`;
    }
  }
  return null;
}

/** The shape a declared part's `type` takes, byte for byte `OcuPilot.Screen.Registry`'s `PARTTYPEPATTERN`. */
export const PART_TYPE_RE = /^[A-Z]+$/;

/** The shape a declared part's `as` takes, byte for byte `OcuPilot.Screen.Registry`'s `PARTASPATTERN`. */
export const PART_AS_RE = /^[A-Z][A-Za-z0-9]*$/;

/** The most parts a single-object `GET` may declare, `OcuPilot.Screen.Registry`'s `MAXPARTS`. */
export const MAX_PARTS = 3;

/**
 * What is wrong with `source.parts`, or `null` (AD-36, Story 6.9). `read` is the declared read and
 * `fields` its declared fields.
 *
 * An absent or `null` `parts` declares none. Otherwise it is a non-empty array of 1 to `MAX_PARTS`
 * objects carrying only `type` (`PART_TYPE_RE`) and `as` (`PART_AS_RE`, unique across the block),
 * declared on a single-object `GET` source with no `criteria` or `query` -- either would name the
 * read's one criterion or a fixed parameter, and a parts read's row is assembled from the parts
 * alone. A `GET` source already guarantees an `admin` port and already refuses `rowGet` and
 * `forEach` outright unless a parent-scoped route-id `criteria` is also declared, in which case
 * this function's own criteria check fires first, so neither needs its own arm here. Every
 * declared field then starts with one of the
 * block's `as` values, followed by one or two further dot-separated segments, since
 * `OcuPilot.Screen.Read.CopyAs` composes a part field's `<as>.<member>` with the existing
 * `<object>.<member>` projection to at most two members deep. `OcuPilot.Screen.Registry.PartsProblem`
 * returns the same sentence for every case in `OcuPilot.Test.ReadSourceCorpus`.
 */
export function partsProblem(read, source, fields) {
  const where = 'read.source.parts';
  const { parts } = source;
  if (parts === undefined || parts === null) return null;
  if (!Array.isArray(parts)) return `${where} is not an array of {type, as} parts (AD-36)`;
  if (source.type !== 'GET') {
    return `${where} is declared on a '${shown(source.type)}' source, and parts merge into a single-object GET's one row (AD-36)`;
  }
  // A GET source's own rules already guarantee the port is admin by this point, and already
  // refuse rowGet and forEach outright on a GET source unless a parent-scoped route-id criterion
  // is also declared -- in which case the criteria check just below fires first. So parts and
  // rowGet or forEach cannot reach here together; only criteria and query can.
  if (isObject(read.criteria)) {
    return `${where} is declared with read.criteria, and a parts read takes no criterion (AD-36)`;
  }
  if (isObject(source.query)) {
    return `${where} is declared with read.source.query, and a parts read fixes no query parameter (AD-36)`;
  }
  if (parts.length < 1 || parts.length > MAX_PARTS) {
    return `${where} declares ${parts.length} part(s), and a parts read names 1 to ${MAX_PARTS}`;
  }
  const seenAs = [];
  for (let index = 0; index < parts.length; index += 1) {
    const part = parts[index];
    const at = `${where} entry #${index + 1}`;
    if (!isObject(part)) return `${at} is not an object declaring its type and as`;
    const keysFault = unknownKeyProblem(at, part, ['type', 'as']);
    if (keysFault !== null) return keysFault;
    if (typeof part.type !== 'string' || !PART_TYPE_RE.test(part.type)) {
      return `${at} type '${shown(part.type)}' is not upper-case letters`;
    }
    if (typeof part.as !== 'string' || !PART_AS_RE.test(part.as)) {
      return `${at} as '${shown(part.as)}' is not an upper camel-case identifier`;
    }
    if (seenAs.includes(part.as)) {
      return `${at} names the as '${part.as}' twice, and every part's as is unique`;
    }
    seenAs.push(part.as);
  }
  for (const field of fields) {
    const matched = seenAs.some((as) => new RegExp(`^${as}\\.[A-Za-z][A-Za-z0-9]*(\\.[A-Za-z][A-Za-z0-9]*)?$`).test(field));
    if (!matched) {
      return `read.fields '${field}' does not start with a declared parts.as followed by one or two segments (AD-36)`;
    }
  }
  return null;
}

/** The shape a `tab.group` route takes, byte for byte `OcuPilot.Screen.Registry`'s `TABGROUPPATTERN`. */
export const TAB_GROUP_RE = /^[a-z0-9-]+(\/[a-z0-9-]+)*$/;

/**
 * What is wrong with a declaration's `tab`, or `null` when nothing is (AD-5). A tabbed screen is one
 * descriptor per tab, grouped by this declaration.
 *
 * An absent or `null` `tab` is a screen that is no tab. Otherwise it is an object carrying only `group`
 * (a route), `position` (a whole number of at least 1) and `labelKey` (a non-empty string key);
 * position 1 is declared exactly by the member whose `route` is the group; and a member at position 2
 * or higher declares `sideBarPosition` 0. `OcuPilot.Screen.Registry.TabProblem` returns the same
 * sentence for every case in `OcuPilot.Test.TabCorpus`.
 */
export function tabProblem(declaration) {
  const { tab } = declaration;
  if (tab === undefined || tab === null) return null;
  if (!isObject(tab)) return 'tab is not an object declaring its group, position and labelKey (AD-5)';
  const keysFault = unknownKeyProblem('tab', tab, ['group', 'position', 'labelKey']);
  if (keysFault !== null) return keysFault;
  if (typeof tab.group !== 'string' || !TAB_GROUP_RE.test(tab.group)) {
    return `tab.group '${shown(tab.group)}' is not a route`;
  }
  if (typeof tab.position !== 'number' || !Number.isInteger(tab.position) || tab.position < 1) {
    return `tab.position '${shown(tab.position)}' is not a whole number of at least 1`;
  }
  if (typeof tab.labelKey !== 'string' || tab.labelKey === '') {
    return 'tab.labelKey is empty, and a tab names the string key its label reads';
  }
  const route = shown(declaration.route);
  if (tab.position === 1 && route !== tab.group) {
    return `tab.position 1 is the group's own route, and route '${route}' is not tab.group '${tab.group}' (AD-5)`;
  }
  if (tab.position !== 1 && route === tab.group) {
    return `tab.group '${tab.group}' is this screen's own route, which only tab.position 1 may declare (AD-5)`;
  }
  if (tab.position > 1 && declaration.sideBarPosition !== 0) {
    return `tab.position ${tab.position} is a tab under its group's first, and such a tab declares sideBarPosition 0 (AD-5)`;
  }
  return null;
}

/**
 * What is wrong with how a roster's tab groups fit together, or `null` (AD-5). `screens` is
 * `[{className, declaration}]` in roster order, and the answer names the offending class.
 *
 * Groups are checked in the order their first member appears. Each names a built member at its route
 * that declares the group; every member shares that member's `area` and `archetype`; and the members'
 * positions, sorted, run 1 to their count with no gap or repeat.
 * `OcuPilot.Screen.Registry.TabGroupProblem` returns the same sentence for every roster case in
 * `OcuPilot.Test.TabCorpus`.
 */
export function tabGroupProblem(screens) {
  const groups = new Map();
  for (const screen of screens) {
    const tab = screen?.declaration?.tab;
    if (!isObject(tab) || typeof tab.group !== 'string') continue;
    if (!groups.has(tab.group)) groups.set(tab.group, []);
    groups.get(tab.group).push(screen);
  }
  for (const [group, members] of groups) {
    let head = null;
    for (const member of members) {
      if (member.declaration.route === group && member.declaration.built === true) head = member;
    }
    if (head === null) {
      return `${members[0].className}: tab.group '${group}' names no built member at that route, and a tab group opens at its first tab (AD-5)`;
    }
    const { area, archetype } = head.declaration;
    for (const member of members) {
      if (member.declaration.area === area && member.declaration.archetype === archetype) continue;
      return (
        `${member.className}: tab.group '${group}' is declared in area '${shown(member.declaration.area)}' with archetype ` +
        `'${shown(member.declaration.archetype)}', and a tab group's members share the area and archetype of '${group}' (AD-5)`
      );
    }
    const positions = members.map((member) => member.declaration.tab.position).sort((a, b) => a - b);
    if (positions.some((position, index) => position !== index + 1)) {
      return (
        `${head.className}: tab.group '${group}' declares positions ${positions.join(',')}, and a tab group's ` +
        `positions run 1 to ${members.length} with no gap or repeat (AD-5)`
      );
    }
  }
  return null;
}

/**
 * What is wrong with how a roster's `parentScope` declarations resolve, or `null` (DW-1020, AD-5).
 * `screens` is `[{className, declaration}]` in roster order.
 *
 * A built descriptor's non-empty `parentScope` must name the route of some other **built**
 * descriptor whose own `id.kind` is not `none` -- a route with nothing to identify resolves no
 * entity for the child's id to name. The entry being checked is excluded from its own candidate
 * search, so a descriptor cannot resolve its `parentScope` against itself by declaring one equal
 * to its own `route`. An unbuilt descriptor's `parentScope` is not checked: it routes nothing yet,
 * so a stale reference in a declaration still being drafted is not this rule's problem.
 * `OcuPilot.Screen.Registry.ParentScopeResolutionProblem` returns the same sentence.
 */
export function parentScopeResolutionProblem(screens) {
  for (let outer = 0; outer < screens.length; outer += 1) {
    const screen = screens[outer];
    const declaration = screen.declaration;
    if (declaration.built !== true) continue;
    const parentScope = declaration.parentScope;
    if (typeof parentScope !== 'string' || parentScope === '') continue;
    let found = false;
    for (let inner = 0; inner < screens.length; inner += 1) {
      if (inner === outer) continue;
      const candidateDeclaration = screens[inner].declaration;
      if (candidateDeclaration.route !== parentScope || candidateDeclaration.built !== true) continue;
      const idKind = isObject(candidateDeclaration.id) ? candidateDeclaration.id.kind : undefined;
      if (idKind !== undefined && idKind !== null && idKind !== '' && idKind !== 'none') {
        found = true;
        break;
      }
    }
    if (!found) {
      return `${screen.className}: parentScope '${parentScope}' names no built descriptor with that route and an id (DW-1020)`;
    }
  }
  return null;
}

/** The keys a declared `rowTarget` may carry (AD-5, Story 6.10). */
export const ROW_TARGET_KEYS = ['route', 'field'];

/**
 * What is wrong with `declaration`'s declared `rowTarget`, or `null` when nothing is, including
 * when none is declared (AD-5, Story 6.10). A row target is a list's single cross-screen row
 * link: the field its name cell encodes and the route that link opens, resolved ahead of the
 * paired-surface chain in `data-table.ts` -- because a list keyed by something other than the
 * linked entity (the Locks list's removal id, say) would otherwise link its own id route, which
 * names the wrong thing.
 *
 * Declarable only on a `list` archetype that also declares a `table`, since exactly one column's
 * `kind` is `name` and a row target replaces what that column would otherwise link to. Its
 * `route` is a non-empty string other than the declaring screen's own route, and its `field` is a
 * non-empty string that is one of `read.fields`. Whether the named route resolves is
 * `rowTargetResolutionProblem`'s question. `OcuPilot.Screen.Registry.RowTargetProblem` returns
 * the same sentence for every case in `OcuPilot.Test.RowTargetCorpus`.
 */
export function rowTargetProblem(declaration) {
  const { rowTarget } = declaration;
  if (rowTarget === undefined || rowTarget === null) return null;
  if (!isObject(rowTarget)) return 'rowTarget is not an object naming its route and field (AD-5)';
  const keysFault = unknownKeyProblem('rowTarget', rowTarget, ROW_TARGET_KEYS);
  if (keysFault !== null) return keysFault;
  if (declaration.archetype !== 'list') {
    return `rowTarget is declared on a '${shown(declaration.archetype)}' archetype, and a row target is a list's own row link (AD-5)`;
  }
  if (!isObject(declaration.table)) {
    return "rowTarget is declared without a table, and a row target replaces the table's name column's own link (AD-5)";
  }
  if (typeof rowTarget.route !== 'string' || rowTarget.route === '') {
    return 'rowTarget.route is empty, and a row target names the route it opens';
  }
  if (rowTarget.route === declaration.route) {
    return `rowTarget.route '${rowTarget.route}' is this screen's own route, and a row already reaches it through its own id (AD-5)`;
  }
  if (typeof rowTarget.field !== 'string' || rowTarget.field === '') {
    return 'rowTarget.field is empty, and a row target names the field its link encodes';
  }
  const fields = Array.isArray(declaration.read?.fields) ? declaration.read.fields : [];
  if (!fields.includes(rowTarget.field)) {
    return `rowTarget.field '${rowTarget.field}' is not one of read.fields`;
  }
  return null;
}

/**
 * Whether some other built entry in `screens` already pairs `route`'s own surface -- an editor or
 * document viewer at `<route>/edit` or `<route>/document`, or a detail screen or child list whose
 * `parentScope` is `route` -- the four surfaces `editorScreenFor`, `documentScreenFor`,
 * `detailScreenFor` and `childListFor` pair a list with, named by route and `parentScope` alone.
 * Deliberately broader than those four, which each also require the candidate to be unlisted and
 * id-keyed: this rule counts a built candidate at either route, so it refuses a declaration the
 * client would have left unpaired rather than admitting one it would pair. A row's name cell links
 * to one place, so a screen that already has one of these declares no `rowTarget` as well.
 */
function rowTargetPairsOwnSurface(route, screens) {
  for (const screen of screens) {
    const candidate = screen.declaration;
    if (candidate.built !== true) continue;
    if (candidate.route === `${route}/edit` || candidate.route === `${route}/document`) return true;
    if (route !== '' && candidate.parentScope === route) return true;
  }
  return false;
}

/**
 * What is wrong with how `screens`' declared `rowTarget`s resolve, or `null` (AD-5, Story 6.10).
 * `screens` is `[{className, declaration}]` in roster order.
 *
 * A declared `rowTarget.route` must name some other entry's `route`, that entry must be `built`,
 * its `id.kind` must not be `none`, and the declaring screen must not already pair its own
 * surface (`rowTargetPairsOwnSurface`) -- a row's name cell links to one place.
 * `OcuPilot.Screen.Registry.RowTargetResolutionProblem` returns the same sentence for every
 * roster case in `OcuPilot.Test.RowTargetCorpus`.
 */
export function rowTargetResolutionProblem(screens) {
  for (let outer = 0; outer < screens.length; outer += 1) {
    const screen = screens[outer];
    const declaration = screen.declaration;
    if (!isObject(declaration.rowTarget)) continue;
    const { route } = declaration.rowTarget;
    const ownRoute = declaration.route;
    let candidate = null;
    for (let inner = 0; inner < screens.length; inner += 1) {
      if (inner === outer) continue;
      const candidateDeclaration = screens[inner].declaration;
      if (candidateDeclaration.route === route) candidate = candidateDeclaration;
    }
    if (candidate === null) {
      return `${screen.className}: rowTarget.route '${route}' names no declared screen (AD-5)`;
    }
    if (candidate.built !== true) {
      return `${screen.className}: rowTarget.route '${route}' names a screen that is not built (AD-5)`;
    }
    const idKind = isObject(candidate.id) ? candidate.id.kind : undefined;
    if (idKind === undefined || idKind === null || idKind === '' || idKind === 'none') {
      return `${screen.className}: rowTarget.route '${route}' names a screen with no id, and a row target's field decodes into that screen's own id (AD-5)`;
    }
    if (rowTargetPairsOwnSurface(ownRoute, screens)) {
      return `${screen.className}: rowTarget is declared on a screen that already pairs its own surface, and a row's name cell links to one place (AD-5)`;
    }
  }
  return null;
}

/** The rules a `read.source.rowGet` derived field may name (AD-36). */
export const ROW_GET_RULES = ['beforeToday'];

/**
 * The request types a `read.source.rowGet` may issue (AD-36), byte for byte
 * `OcuPilot.Screen.Registry`'s own `ROWGETTYPES`: `GET`, the default; `INFO`, where the list's own
 * row is wrong; and `CERTINFO`, where only that type carries the fields.
 */
export const ROW_GET_TYPES = ['GET', 'INFO', 'CERTINFO'];

const PARAM_RE = /^[A-Za-z][A-Za-z0-9]*$/;

/** Whether `value` is a JSON object: not `null` and not an array. */
function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

/**
 * What is wrong with `source.rowGet`, or `null` (AD-36). `fields` is the read's declared fields.
 * `keyAllowed` is non-empty only for a parent-scoped GET's route-id criterion (Story 6.7): when it
 * is, `key` must equal that one param instead of naming one of `fields`, because the GET's own
 * answer carries no such property for a per-row detail call to key off.
 *
 * An absent or `null` `rowGet` declares no detail call. Otherwise it is an object carrying only
 * `key` (one of `fields`, or `keyAllowed` where that is non-empty), `param` (a query parameter
 * name), an optional `type` (one of
 * `ROW_GET_TYPES`, spelled exactly; absent means `GET`), `fields` (a non-empty array of unique
 * names from `fields`, without `key`) and `derived`, an array of objects carrying only `field` (one
 * of `fields`, neither `key` nor a detail field, and not repeated), `rule` (one of `ROW_GET_RULES`)
 * and `from` (one of the detail fields). `OcuPilot.Screen.Registry.RowGetProblem` returns the same
 * sentence for every case in `OcuPilot.Test.RowGetCorpus`.
 */
export function rowGetProblem(source, fields, keyAllowed = []) {
  const where = 'read.source.rowGet';
  const { rowGet } = source;
  if (rowGet === undefined || rowGet === null) return null;
  if (!isObject(rowGet)) return `${where} is not an object declaring its key, param, fields and derived (AD-36)`;
  const keysFault = unknownKeyProblem(where, rowGet, ['key', 'param', 'type', 'fields', 'derived']);
  if (keysFault !== null) return keysFault;

  if (typeof rowGet.key !== 'string') return `${where}.key is not a string`;
  if (keyAllowed.length > 0) {
    if (!keyAllowed.includes(rowGet.key)) {
      return `${where}.key '${rowGet.key}' must equal the read's one route-id criterion param (AD-36, Story 6.7)`;
    }
  } else if (!fields.includes(rowGet.key)) {
    return `${where}.key '${rowGet.key}' is not one of read.fields`;
  }
  if (typeof rowGet.param !== 'string') return `${where}.param is not a string`;
  if (!PARAM_RE.test(rowGet.param)) return `${where}.param '${rowGet.param}' is not a query parameter name`;
  if (Object.hasOwn(rowGet, 'type') && (typeof rowGet.type !== 'string' || !ROW_GET_TYPES.includes(rowGet.type))) {
    return `${where}.type '${shown(rowGet.type)}' is not one of ${ROW_GET_TYPES.join(',')}, the detail types a per-row call issues (AD-36)`;
  }

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

/**
 * Whether a declaration is a `form-page` over a single-object `GET` read that declares no `table`
 * and no `composite` id (`OcuPilot.Screen.Registry.RendersNoTable`). A form renders that one
 * object as fields and actions, never as a grid, so it names no column header and no empty-state
 * sentence a user could never see. Such a declaration is exempt from `tableProblem`; a form over a
 * list-shaped read, one with a composite id, and one that declares a table are still held to it.
 */
export function rendersNoTable(declaration) {
  return (
    declaration.archetype === 'form-page' &&
    (declaration.table === undefined || declaration.table === null) &&
    declaration.id?.kind !== 'composite' &&
    declaration.read?.source?.type === 'GET'
  );
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
 * none of `secrets`, unique), a non-empty `labelKey`, a kind from `TABLE_COLUMN_KINDS` and an
 * optional non-empty `emptyKey` (the string key an empty cell in that column reads instead of
 * "(none)"), and exactly one is `name`;
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
    const columnKeysFault = unknownKeyProblem(where, column, ['field', 'labelKey', 'kind', 'emptyKey']);
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
    if (Object.hasOwn(column, 'emptyKey') && (typeof column.emptyKey !== 'string' || column.emptyKey === '')) {
      return `${where} emptyKey is not a non-empty string key, and an empty cell in that column reads the string it names`;
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
 * Every client string key a declaration names: its `labelKey`, its `emptyStateKey`, its
 * `entityLabelKey`, its table's
 * column labels, column empty-cell keys and two empty-state keys, and its banner's `messageKey`.
 * Empty keys are not listed.
 *
 * The banner's key belongs here for the reason the others do: `stringFor` answers `''` for a key
 * the source lacks, so a mistyped one is caught here -- where the file and the key can both be
 * named -- rather than at render time, where a banner would simply never appear.
 */
export function declaredStringKeys(declaration) {
  const keys = [declaration.labelKey, declaration.emptyStateKey, declaration.entityLabelKey];
  const { table, banner, tab } = declaration;
  if (table !== null && typeof table === 'object') {
    for (const column of Array.isArray(table.columns) ? table.columns : []) keys.push(column?.labelKey, column?.emptyKey);
    keys.push(table.emptyNextKey, table.emptyAgentKey);
  }
  if (banner !== null && typeof banner === 'object') {
    for (const entry of Array.isArray(banner.cases) ? banner.cases : []) keys.push(entry?.messageKey);
  }
  if (tab !== null && typeof tab === 'object') keys.push(tab.labelKey);
  return keys.filter((key) => typeof key === 'string' && key !== '');
}

/**
 * The declared `type -> rule` map, refused by name when a pair names something no reader can
 * apply (AD-13 as amended by DW-1359, AD-5).
 *
 * Three refusals, all of which would otherwise ship as a silent identity function on the client
 * while the kernel folded the same id -- which is exactly the divergence DW-1364 was:
 *
 * - a type outside `OcuPilot.Kernel.EntityType.TYPES`, so the pair names no entity at all;
 * - a rule outside the kernel's own `IDRULENAMES`, so the kernel itself cannot apply it;
 * - a rule outside `IMPLEMENTED_ID_RULES`, so `ui/src/app/core/entity-ref.ts` cannot;
 * - two pairs for one type, which the kernel resolves to the first and this generator to the last.
 *
 * It is the same shape the unknown-entity-type refusal below uses, and for the same reason: a
 * build failure is the only thing that stops a kernel rule reaching the client as a no-op.
 */
function checkedIdRules(idRules, idRuleNames, knownTypes) {
  const declaredRules = new Set(idRuleNames);
  const implemented = new Set(IMPLEMENTED_ID_RULES);
  const emitted = {};
  for (const [type, rule] of idRules) {
    if (!knownTypes.has(type)) {
      throw new Error(
        `src/OcuPilot/Kernel/EntityRef.cls: IDRULES declares a rule for entity type "${type}", ` +
          `which is not in src/OcuPilot/Kernel/EntityType.cls; add it there or use a declared ` +
          `value (AD-13, AD-14)`
      );
    }
    if (!declaredRules.has(rule)) {
      throw new Error(
        `src/OcuPilot/Kernel/EntityRef.cls: IDRULES names id rule "${rule}" for "${type}", which ` +
          `IDRULENAMES does not declare; the kernel itself would canonicalize that type to ` +
          `itself (AD-13)`
      );
    }
    if (!implemented.has(rule)) {
      throw new Error(
        `src/OcuPilot/Kernel/EntityRef.cls: IDRULES names id rule "${rule}" for "${type}", which ` +
          `ui/tools/screen-mirror.mjs cannot implement on the client (it knows ` +
          `${IMPLEMENTED_ID_RULES.join(', ')}); implement it in ui/src/app/core/entity-ref.ts and ` +
          `add it to IMPLEMENTED_ID_RULES, or the two key builders disagree (AD-13, AD-5)`
      );
    }
    if (Object.prototype.hasOwnProperty.call(emitted, type)) {
      throw new Error(
        `src/OcuPilot/Kernel/EntityRef.cls: IDRULES declares two rules for entity type "${type}" ` +
          `("${emitted[type]}" and "${rule}"); OcuPilot.Kernel.EntityRef.IdRuleFor stops at the ` +
          `first pair and this generator would emit the last, so the two key builders disagree ` +
          `(AD-13, AD-5)`
      );
    }
    emitted[type] = rule;
  }
  return emitted;
}

export function buildMirror({
  entityTypes,
  idRules = [],
  idRuleNames = [],
  refSeparator,
  singletonId,
  declaredNameKinds = IMPLEMENTED_DECLARED_NAME_KINDS,
  selfProtectionRules = IMPLEMENTED_SELF_PROTECTION_RULES,
  scopeWords,
  archetypes,
  areas,
  screens,
  toolFields = {},
}) {
  const known = new Set(entityTypes);
  const entityIdRules = checkedIdRules(idRules, idRuleNames, known);
  if (!Number.isSafeInteger(refSeparator) || refSeparator <= 0) {
    throw new Error(
      `src/OcuPilot/Kernel/EntityRef.cls: REFSEPARATOR must be a whole number above zero, the ` +
        `code point the key's three parts are joined with; ui/src/app/core/entity-ref.ts builds ` +
        `the same key and would join them with something else (AD-13, AD-5)`
    );
  }
  if (typeof singletonId !== 'string' || singletonId === '') {
    throw new Error(
      `src/OcuPilot/Kernel/EntityRef.cls: RULESINGLETONID must be a non-empty string, the one id ` +
        `every 'singleton' type's reference carries; ui/src/app/core/entity-ref.ts canonicalizes ` +
        `to the same value and would answer something else (AD-13, AD-5)`
    );
  }
  checkedDeclaredNameKinds(declaredNameKinds);
  checkedSelfProtectionRules(selfProtectionRules);
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
    // DW-271, and first: every check below reads a key by name, so an unknown one is invisible to
    // all of them and reaches the emission's spread verbatim.
    const declarationFault = declarationProblem(screen.declaration);
    if (declarationFault !== null) {
      throw new Error(`src/OcuPilot/Screen/Descriptor/${screen.file} (${screen.className}): ${declarationFault}`);
    }
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
    const positionFault = sideBarPositionProblem(screen.declaration);
    if (positionFault !== null) {
      throw new Error(`src/OcuPilot/Screen/Descriptor/${screen.file} (${screen.className}): ${positionFault}`);
    }
    const refreshFault = refreshProblem(screen.declaration);
    if (refreshFault !== null) {
      throw new Error(`src/OcuPilot/Screen/Descriptor/${screen.file}: ${refreshFault}`);
    }
    const readFault = readProblem(screen.declaration);
    if (readFault !== null) {
      throw new Error(`src/OcuPilot/Screen/Descriptor/${screen.file} (${screen.className}): ${readFault}`);
    }
    const criteriaFault = criteriaProblem(screen.declaration);
    if (criteriaFault !== null) {
      throw new Error(`src/OcuPilot/Screen/Descriptor/${screen.file} (${screen.className}): ${criteriaFault}`);
    }
    const confirmFault = confirmChannelProblem(screen.declaration, toolFields);
    if (confirmFault !== null) {
      throw new Error(`src/OcuPilot/Screen/Descriptor/${screen.file} (${screen.className}): ${confirmFault}`);
    }
    const entityLabelFault = entityLabelProblem(screen.declaration);
    if (entityLabelFault !== null) {
      throw new Error(`src/OcuPilot/Screen/Descriptor/${screen.file} (${screen.className}): ${entityLabelFault}`);
    }
    const bannerFault = bannerProblem(screen.declaration);
    if (bannerFault !== null) {
      throw new Error(`src/OcuPilot/Screen/Descriptor/${screen.file} (${screen.className}): ${bannerFault}`);
    }
    const tabFault = tabProblem(screen.declaration);
    if (tabFault !== null) {
      throw new Error(`src/OcuPilot/Screen/Descriptor/${screen.file} (${screen.className}): ${tabFault}`);
    }
    const rowTargetFault = rowTargetProblem(screen.declaration);
    if (rowTargetFault !== null) {
      throw new Error(`src/OcuPilot/Screen/Descriptor/${screen.file} (${screen.className}): ${rowTargetFault}`);
    }
    // AD-5, AD-53: the self-protection rule the client draws a refused row action from, refused
    // here against the instance's own closed vocabulary so a rule neither side understands fails
    // the build rather than rendering as a word in a row menu.
    const actionFault = actionProblem(screen.declaration, selfProtectionRules);
    if (actionFault !== null) {
      throw new Error(`src/OcuPilot/Screen/Descriptor/${screen.file} (${screen.className}): ${actionFault}`);
    }
  }
  const tabGroupFault = tabGroupProblem(screens);
  if (tabGroupFault !== null) throw new Error(`src/OcuPilot/Screen/Descriptor: ${tabGroupFault}`);
  // DW-1020: a sub-resource screen's route id names an entity of its parent's primary entity type
  // (AD-5), resolved through parentScope, so the parent it names has to exist, be built and carry
  // an id for that resolution to answer anything.
  const parentScopeFault = parentScopeResolutionProblem(screens);
  if (parentScopeFault !== null) throw new Error(`src/OcuPilot/Screen/Descriptor: ${parentScopeFault}`);
  // AD-5, Story 6.10: a declared rowTarget's route has to resolve to a built, id-keyed screen that
  // does not already pair its own surface, which only the whole roster can say.
  const rowTargetResolutionFault = rowTargetResolutionProblem(screens);
  if (rowTargetResolutionFault !== null) throw new Error(`src/OcuPilot/Screen/Descriptor: ${rowTargetResolutionFault}`);

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
    banner: screen.declaration.banner ?? null,
    tab: screen.declaration.tab ?? null,
    rowTarget: screen.declaration.rowTarget ?? null,
    // Defaulted for the reason `read` is: both keys are optional (AD-3, AD-6), every descriptor
    // written before them declares neither, and the mirror's two fields are not optional.
    secretArguments: screen.declaration.secretArguments ?? [],
    fingerprintExcludes: screen.declaration.fingerprintExcludes ?? [],
    // Defaulted for the same reason, and for the same kind of key: optional on the ObjectScript
    // side (AD-5, AD-14), absent from every descriptor written before this story, and not optional
    // on the mirror's own interface.
    entityLabelKey: screen.declaration.entityLabelKey ?? '',
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
  /** Per-field length overrides (Story 4.4, AD-24), each a whole number from 1 to 1,000. Absent
   * for a screen that declares none. */
  readonly maxLength?: Readonly<Record<string, number>>;
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
  /**
   * The row link a complete exemption may declare (AD-44, AD-47): each row's name cell opens \`href\`
   * with these params appended from that row, in a new tab. Absent on a screen that links no row.
   */
  readonly rowLink?: ClassicRowLink | null;
}

/** One query parameter a row link appends: its name and the read field whose text it carries. */
export interface ClassicRowLinkParam {
  readonly name: string;
  readonly field: string;
}

/** A row link: the params appended, in order, to the exemption's \`href\` for one row. */
export interface ClassicRowLink {
  readonly params: readonly ClassicRowLinkParam[];
}

/** A field a detail call derives on the instance from one of its detail fields (AD-36). */
export interface ReadDerived {
  readonly field: string;
  readonly rule: 'beforeToday';
  readonly from: string;
}

/**
 * The one per-row detail call a read may name (AD-36): the endpoint's declared detail type, issued
 * on the instance for each row that survives the cap with \`param\` set to the row's \`key\`,
 * merging \`fields\` and setting \`derived\`.
 */
export interface ReadRowGet {
  readonly key: string;
  readonly param: string;
  /** The detail type issued per row; absent means \`GET\`. */
  readonly type?: ${ROW_GET_TYPES.map((value) => `'${value}'`).join(' | ')};
  readonly fields: readonly string[];
  readonly derived: readonly ReadDerived[];
}

/**
 * One \`{type, as}\` part a single-object \`GET\` may declare (AD-36, Story 6.9): \`type\` is the
 * vendor's own upper-case request type, possibly one the endpoint names without its usual \`TYPE\`
 * prefix, and \`as\` is the object key its answer is merged under.
 */
export interface ReadSourcePart {
  readonly type: string;
  readonly as: string;
}

/**
 * Where a read's rows come from (AD-36): one admin API LIST (AD-2) with an optional per-row detail
 * call, one of OcuPilot's own kernel stores read whole (AD-9), the management API's port, or one
 * instance log file's bounded tail. A \`state\` source names the store by its own name, declares no
 * \`rowGet\` and no \`criteria\`, and is bounded by the same row cap; a \`mgmnt\` or
 * \`logsource\` source declares no \`rowGet\`.
 */
export interface ReadSource {
  readonly port: ${READ_SOURCE_PORTS.map((value) => `'${value}'`).join(' | ')};
  readonly endpoint: string;
  /**
   * \`LIST\` reads rows; \`GET\` reads one object as the one row, and a 404 reads as none;
   * \`UPCOMING\` reads an admin endpoint's scheduled occurrences as rows; \`HISTORY\` reads its task-run history;
   * \`VOLUMELIST\` reads a database's own volume files as rows.
   */
  readonly type: ${READ_SOURCE_TYPES.map((value) => `'${value}'`).join(' | ')};
  readonly rowGet?: ReadRowGet | null;
  /** The parent list a per-parent read issues its source once per parent for, bounded by the cap. */
  readonly forEach?: ReadForEach | null;
  /**
   * Up to three \`{type, as}\` parts a single-object \`GET\` merges into the read's one row as
   * \`<as>.<member>\` fields (AD-36, Story 6.9).
   */
  readonly parts?: readonly ReadSourcePart[] | null;
  /** Query parameters sent on the read's own list, UPCOMING, HISTORY or GET call and each per-parent child list (never a parent list or a rowGet call), which no caller can change or remove. */
  readonly query?: Readonly<Record<string, string>> | null;
}

/** One parent field a per-parent read copies into each of that parent's rows. */
export interface ReadForEachField {
  readonly field: string;
  readonly from: string;
}

/**
 * A per-parent read (AD-36): \`endpoint\` is listed first, bounded by the cap plus one, and the read's
 * own source is listed once per parent with \`param\` set to that parent's \`key\`, each row taking
 * \`fields\` from its parent.
 */
export interface ReadForEach {
  readonly endpoint: string;
  readonly key: string;
  readonly param: string;
  readonly fields: readonly ReadForEachField[];
}

/** The fields a read sorts on, its default sort field and direction. */
export interface ReadSort {
  readonly fields: readonly string[];
  readonly default: string;
  readonly direction: 'asc' | 'desc';
}

/** How a declared server-search criterion is entered (AD-21). */
export type CriterionKind = ${CRITERION_KINDS.map((value) => `'${value}'`).join(' | ')};

/**
 * One server-search criterion: the query parameter the read sends it as, the string key its
 * control is labelled with, and how it is entered. A \`choice\` criterion carries the closed
 * \`options\` its value is validated against on the instance before the port is called - the read
 * executor refuses anything outside them, so an unrecognized value can never widen the search.
 */
export interface ReadCriterion {
  readonly param: string;
  readonly labelKey: string;
  readonly kind: CriterionKind;
  /**
   * The longest value the criterion's own vendor property accepts, declared on every criterion
   * whatever its kind (DW-279). A longer value is refused 400 \`READ.CRITERION\` naming the
   * parameter and this bound, before any port is called -- where an unbounded one faulted inside
   * the port and named nothing.
   */
  readonly maxLength: number;
  /**
   * The query parameter name the value is sent to the vendor under, instead of \`param\`, where the
   * vendor's own name is reserved for the read's own arguments (Story 6.6). Absent means the value
   * is sent as \`param\` itself; the caller, the refusal text and the read tool's schema all keep
   * using \`param\` regardless.
   */
  readonly vendorParam?: string;
  readonly options?: readonly string[];
}

/**
 * The agent-marker affordance: one declared criterion set to one declared value (AD-15, AD-46).
 *
 * It **overrides** the criterion \`param\` names rather than merging with it. Both name the same
 * query parameter and the vendor treats a comma list as membership, so appending would widen the
 * result instead of narrowing it.
 */
export interface ReadCriteriaMarker {
  readonly param: string;
  readonly value: string;
  readonly labelKey: string;
}

/**
 * The server-search parameters a declared read carries (AD-21), for the one Release 1 list whose
 * API searches on the server. The roster is the allow-list: the route reads a query parameter only
 * where this names it, and the read tool publishes one property per criterion, so screen and tool
 * send the same search (AD-36).
 */
export interface ReadCriteria {
  readonly fields: readonly ReadCriterion[];
  readonly marker?: ReadCriteriaMarker | null;
}

/** A screen's one declared read (AD-36): the screen's list and its read tool both resolve through it. */
export interface ReadDeclaration {
  readonly source: ReadSource;
  readonly fields: readonly string[];
  readonly filter: readonly string[];
  readonly sort: ReadSort;
  readonly paging: 'cap';
  /** The server-search criteria this read carries, absent for a read bounded by the cap alone. */
  readonly criteria?: ReadCriteria | null;
}

/** Where a banner's value comes from: one admin API GET (AD-2). */
export interface BannerSource {
  readonly port: 'admin';
  readonly endpoint: string;
  readonly type: 'GET';
}

/** The \`.ocu-banner-*\` variants a declared banner may take (DESIGN.md \`:1203\`). */
export type BannerSeverity = ${BANNER_SEVERITIES.map((value) => `'${value}'`).join(' | ')};

/** One value a banner's field may take, and the sentence it raises (DW-270). */
export interface BannerCase {
  readonly equals: string;
  readonly messageKey: string;
  readonly severity: BannerSeverity;
}

/**
 * A screen's declared banner: one port read over one \`field\`, and the cases that field's value
 * may match -- the first whose \`equals\` it equals raises that case's \`messageKey\`.
 *
 * **One read, many cases.** A field with a closed set of values usually has more than one state
 * worth a strip: the Task Manager answers \`Running\`, \`Suspended\` and \`Not running\`, and a
 * single-case banner left the stopped one silent (DW-270). Adding a second banner would have meant
 * a second port call per read, so the cases share one.
 *
 * It is evaluated on the instance inside the screen's own read (\`OcuPilot.Screen.Read\`) and
 * arrives as that read's \`banner\` key, so an auto-refresh tick re-evaluates it and the strip is
 * gone the moment the condition clears. A fault in it suppresses the strip and never fails the
 * list.
 */
export interface BannerDeclaration {
  readonly source: BannerSource;
  readonly field: string;
  readonly cases: readonly BannerCase[];
}

/** How a table column renders its field (AD-5). */
export type TableColumnKind = 'name' | 'identifier' | 'text' | 'number' | 'status';

/**
 * One table column: the read field it shows, its header's string key and its kind, and optionally
 * the string key an empty cell in it reads instead of "(none)".
 */
export interface TableColumn {
  readonly field: string;
  readonly labelKey: string;
  readonly kind: TableColumnKind;
  readonly emptyKey?: string;
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
  /** The string key of the singular noun for \`entityType\`, or \`''\` (AD-5, AD-14). */
  readonly entityLabelKey: string;
  readonly secondaryEntityTypes: readonly string[];
  readonly scope: string;
  readonly parentScope: string;
  readonly id: IdAccessor;
  readonly context: ContextDeclaration;
  /** The top-level argument names this screen's write tools take as secret (AD-3, AD-6). */
  readonly secretArguments: readonly string[];
  /** The payload paths a proposal's fingerprint leaves out (AD-6); the default is everything else. */
  readonly fingerprintExcludes: readonly string[];
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
  /** The strip the read's own answer raises above the table, or \`null\` for a screen with none. */
  readonly banner: BannerDeclaration | null;
  /** The tab group this screen is one tab of, or \`null\` for a screen that is no tab (AD-5). */
  readonly tab: TabDeclaration | null;
  readonly toolIdentifier: string;
  /** This list's one declared cross-screen row target, or \`null\` for a screen with none (AD-5, Story 6.10). */
  readonly rowTarget: ScreenRowTarget | null;
}

/**
 * One tab of a tabbed screen (AD-5): the route of the group's first tab, this tab's position in the
 * strip, and the string key its label reads.
 */
export interface TabDeclaration {
  readonly group: string;
  readonly position: number;
  readonly labelKey: string;
}

/**
 * A list's single declared cross-screen row target (AD-5, Story 6.10): the route its name cell
 * opens and the row field, read with \`fieldOf\` and encoded with \`encodeEntityId\`, that route's
 * id is drawn from -- resolved ahead of the paired-surface chain in \`shell/data-table.ts\`.
 */
export interface ScreenRowTarget {
  readonly route: string;
  readonly field: string;
}

/** The closed entity-type vocabulary, mirrored from OcuPilot.Kernel.EntityType. */
export const ENTITY_TYPES: readonly EntityTypeKey[] = ${JSON.stringify(entityTypes, null, 2)};

/**
 * The code point joining the three parts of a reference key, mirrored from
 * OcuPilot.Kernel.EntityRef's REFSEPARATOR (AD-13). \`entity-ref.ts\` builds its separator from
 * this rather than from a literal of its own, so the two key builders cannot join one entity's
 * parts with different characters (DW-1403).
 */
export const ENTITY_REF_SEPARATOR_CODE = ${refSeparator};

/**
 * The per-entity-type canonical id rules, mirrored from OcuPilot.Kernel.EntityRef's IDRULES
 * table (AD-13). Only the types that declare one appear; every other type canonicalizes to
 * itself. \`entity-ref.ts\` holds the implementation of each rule name, pinned equal to
 * \`screen-mirror.mjs\`'s own roster, so a rule the client cannot apply fails the build rather
 * than mirroring as a no-op.
 */
export const ENTITY_ID_RULES: Readonly<Partial<Record<EntityTypeKey, string>>> = ${JSON.stringify(
    entityIdRules,
    null,
    2
  )};

/**
 * The one id every \`singleton\`-ruled entity type's reference carries, mirrored from
 * OcuPilot.Kernel.EntityRef's RULESINGLETONID (AD-13). \`entity-ref.ts\` builds that rule from this
 * rather than from a literal of its own, for the reason the separator above is mirrored.
 */
export const ENTITY_SINGLETON_ID = ${JSON.stringify(singletonId)};

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

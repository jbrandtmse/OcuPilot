/**
 * Holds the declaration order of a stored class's properties against a release.
 *
 * A `%Persistent` class of OcuPilot's own carries no Storage section in source, so each compile
 * numbers its data slots by declaration order. A property inserted above others, renamed or
 * removed makes rows written by the earlier release read the wrong values (Conventions, "New
 * properties on a stored class").
 *
 * **Scope.** Every `src/OcuPilot/**\/*.cls` that is persistent by its in-tree Extends chain (to
 * `%Persistent`, `Ens.Request` or `Ens.Response`) and has no Storage section.
 *
 * **Stored members.** The `Property` and `Relationship` declarations of the class itself, in
 * declaration order, less those that hold no data slot: Calculated, Transient and
 * MultiDimensional properties, and the many- and children-side of a relationship.
 *
 * **Rule.** A class's stored members at the baseline are a prefix of its current list. A class
 * the baseline holds and the current tree does not, or whose primary superclass changed, fails; a
 * class absent at the baseline passes.
 *
 * `compareStoredOrder` is pure. `sourcesAtRef`, `sourcesInTree` and `newestReleaseRef` read git
 * and the working tree and feed `storedModel`.
 */

import { execFileSync } from 'node:child_process';
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

/** Classes whose order is exempt from the rule, one entry per class with its reason. Empty. */
export const STORED_ORDER_ALLOW = Object.freeze({});

const PERSISTENT_ROOTS = new Set(['%Persistent', '%Library.Persistent', 'Ens.Request', 'Ens.Response']);
const NO_SLOT_KEYWORDS = new Set(['calculated', 'transient', 'multidimensional']);

/**
 * Text from `from` up to the first `;` outside quotes, brackets, parentheses and braces.
 * Quote characters are kept so a keyword value carrying `;` does not end the declaration early.
 */
function declarationAt(text, from) {
  let depth = 0;
  let quoted = false;
  for (let i = from; i < text.length; i += 1) {
    const ch = text[i];
    if (quoted) {
      if (ch === '"') quoted = false;
    } else if (ch === '"') quoted = true;
    else if (ch === '[' || ch === '(' || ch === '{') depth += 1;
    else if (ch === ']' || ch === ')' || ch === '}') depth -= 1;
    else if (ch === ';' && depth <= 0) return text.slice(from, i);
  }
  return text.slice(from);
}

/** Split `text` at commas that sit outside quotes, brackets, parentheses and braces. */
function topLevelCommas(text) {
  const parts = [];
  let depth = 0;
  let quoted = false;
  let start = 0;
  for (let i = 0; i < text.length; i += 1) {
    const ch = text[i];
    if (quoted) {
      if (ch === '"') quoted = false;
    } else if (ch === '"') quoted = true;
    else if (ch === '[' || ch === '(' || ch === '{') depth += 1;
    else if (ch === ']' || ch === ')' || ch === '}') depth -= 1;
    else if (ch === ',' && depth === 0) {
      parts.push(text.slice(start, i));
      start = i + 1;
    }
  }
  parts.push(text.slice(start));
  return parts;
}

/** The keywords of a declaration's trailing `[ ... ]`, as a Map of lower-case name to value. */
function keywordsOf(declaration) {
  const open = declaration.indexOf('[');
  const close = declaration.lastIndexOf(']');
  const keywords = new Map();
  if (open === -1 || close < open) return keywords;
  for (const part of topLevelCommas(declaration.slice(open + 1, close))) {
    const at = part.indexOf('=');
    const name = (at === -1 ? part : part.slice(0, at)).trim().toLowerCase();
    if (name !== '') keywords.set(name, at === -1 ? '' : part.slice(at + 1).trim().toLowerCase());
  }
  return keywords;
}

/** True for a keyword that is present and not switched off (`Calculated = 0`). */
function isOn(keywords, name) {
  if (!keywords.has(name)) return false;
  const value = keywords.get(name);
  return value !== '0' && value !== 'false';
}

/**
 * One class's source as `{ name, supers, hasStorage, members }`, or `null` when the text holds
 * no class header. `supers` is the Extends list in order; `members` the stored members' names.
 */
export function parseClass(text) {
  // Doc comments and line comments first: a `///` line may quote a declaration.
  const code = text.replace(/^[ \t]*\/\/.*$/gm, '');
  const header = /^Class\s+([%\w.]+)(?:\s+Extends\s+(?:\(([^)]*)\)|([^\s[{]+)))?/m.exec(code);
  if (header === null) return null;
  const supers = (header[2] ?? header[3] ?? '')
    .split(',')
    .map((name) => name.trim())
    .filter((name) => name !== '');
  const members = [];
  for (const match of code.matchAll(/^(Property|Relationship)\s+([%\w]+)/gm)) {
    const keywords = keywordsOf(declarationAt(code, match.index));
    if ([...NO_SLOT_KEYWORDS].some((name) => isOn(keywords, name))) continue;
    if (match[1] === 'Relationship') {
      const cardinality = keywords.get('cardinality') ?? '';
      if (cardinality === 'many' || cardinality === 'children') continue;
    }
    members.push(match[2]);
  }
  return { name: header[1], supers, hasStorage: /^Storage\s+\w+/m.test(code), members };
}

/**
 * The in-scope classes of a set of sources, as `{ [className]: { primary, members } }`.
 * `sources` is an iterable of `.cls` texts.
 */
export function storedModel(sources) {
  const classes = new Map();
  for (const text of sources) {
    const parsed = parseClass(text);
    if (parsed !== null) classes.set(parsed.name, parsed);
  }
  const persistent = new Map();
  const isPersistent = (name, seen = new Set()) => {
    if (PERSISTENT_ROOTS.has(name)) return true;
    if (persistent.has(name)) return persistent.get(name);
    const found = classes.get(name);
    if (found === undefined || seen.has(name)) return false;
    seen.add(name);
    const answer = found.supers.some((parent) => isPersistent(parent, seen));
    persistent.set(name, answer);
    return answer;
  };
  const model = {};
  for (const [name, found] of classes) {
    if (found.hasStorage || !isPersistent(name)) continue;
    model[name] = { primary: found.supers[0] ?? '', members: found.members };
  }
  return model;
}

/**
 * The problems that make `current` unsafe over rows `baseline` wrote, as
 * `{ class, kind, slot, message }`. An empty list means the order holds.
 */
export function compareStoredOrder(baseline, current, allow = STORED_ORDER_ALLOW) {
  const problems = [];
  for (const name of Object.keys(baseline).sort()) {
    if (Object.hasOwn(allow, name)) continue;
    const before = baseline[name];
    const after = current[name];
    if (after === undefined) {
      problems.push({
        class: name,
        kind: 'removed',
        slot: 0,
        message: `${name}: stored at the baseline, and no longer a stored class without a Storage section (removed, renamed or no longer persistent)`,
      });
      continue;
    }
    if (after.primary !== before.primary) {
      problems.push({
        class: name,
        kind: 'superclass',
        slot: 0,
        message: `${name}: primary superclass changed from ${before.primary} to ${after.primary}`,
      });
      continue;
    }
    for (let i = 0; i < before.members.length; i += 1) {
      if (after.members[i] === before.members[i]) continue;
      problems.push({
        class: name,
        kind: 'order',
        slot: i + 1,
        message: `${name}: slot ${i + 1} held ${before.members[i]} at the baseline and now holds ${after.members[i] ?? '(nothing)'}; declare new properties after every existing one`,
      });
      break;
    }
  }
  return problems;
}

function git(cwd, args, options = {}) {
  return execFileSync('git', args, { cwd, encoding: 'utf8', maxBuffer: 256 * 1024 * 1024, ...options });
}

/** True in a shallow clone, which holds no history to read an older release from. */
export function isShallow(cwd) {
  return git(cwd, ['rev-parse', '--is-shallow-repository']).trim() === 'true';
}

/** True when `ref` names a commit this clone holds. */
export function hasCommit(cwd, ref) {
  try {
    git(cwd, ['rev-parse', '--verify', '--quiet', `${ref}^{commit}`], { stdio: 'pipe' });
    return true;
  } catch {
    return false;
  }
}

/** The highest `refs/remotes/origin/release/<major>.<minor>.<patch>` by version, or `null`. */
export function newestReleaseRef(cwd) {
  const refs = git(cwd, ['for-each-ref', '--format=%(refname)', 'refs/remotes/origin/release/'])
    .split('\n')
    .map((ref) => ({ ref, parts: /^refs\/remotes\/origin\/release\/(\d+)\.(\d+)\.(\d+)$/.exec(ref) }))
    .filter((entry) => entry.parts !== null)
    .map((entry) => ({ ref: entry.ref, version: entry.parts.slice(1).map(Number) }));
  if (refs.length === 0) return null;
  refs.sort((a, b) => a.version[0] - b.version[0] || a.version[1] - b.version[1] || a.version[2] - b.version[2]);
  return refs[refs.length - 1].ref;
}

/** The `.cls` texts under `src/OcuPilot` at a commit, read in one `git cat-file --batch`. */
export function sourcesAtRef(cwd, ref) {
  const listing = git(cwd, ['ls-tree', '-r', ref, '--', 'src/OcuPilot'])
    .split('\n')
    .filter((line) => line.endsWith('.cls'))
    .map((line) => /^\d+ blob ([0-9a-f]+)\t/.exec(line)?.[1])
    .filter((id) => id !== undefined);
  if (listing.length === 0) return [];
  const out = execFileSync('git', ['cat-file', '--batch'], {
    cwd,
    input: `${listing.join('\n')}\n`,
    maxBuffer: 512 * 1024 * 1024,
  });
  const texts = [];
  let at = 0;
  while (at < out.length) {
    const lineEnd = out.indexOf(0x0a, at);
    const [, type, size] = out.subarray(at, lineEnd).toString('utf8').split(' ');
    if (type !== 'blob') throw new Error(`git cat-file answered ${out.subarray(at, lineEnd).toString('utf8')}`);
    const start = lineEnd + 1;
    texts.push(out.subarray(start, start + Number(size)).toString('utf8'));
    at = start + Number(size) + 1;
  }
  return texts;
}

/** The `.cls` texts under `src/OcuPilot` in the working tree. */
export function sourcesInTree(root) {
  const texts = [];
  const walk = (dir) => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const path = join(dir, entry.name);
      if (entry.isDirectory()) walk(path);
      else if (entry.name.endsWith('.cls')) texts.push(readFileSync(path, 'utf8'));
    }
  };
  walk(join(root, 'src', 'OcuPilot'));
  return texts;
}

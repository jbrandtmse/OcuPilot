#!/usr/bin/env node
/**
 * The browser-context reset check (Story 15.5, AD-50): every spec under `ui/browser/` that reaches
 * a browser context must first forget the signing-in account's remembered state, or declare in its
 * own file why it does not.
 *
 * **Why a checker and not a convention.** Until Story 15.5 the six remembered things lived in
 * `localStorage`, so a fresh `BrowserContext` started every scenario on the published defaults by
 * construction. They live on the instance now, keyed by the one account every spec signs in as, so
 * context isolation no longer resets them and one test's filter becomes the next test's starting
 * state. `preferences-reset.mjs` restores the old slate, but a call at 30+ sites across 38 files is
 * correct only while every future spec remembers it -- and a spec that forgets does not fail
 * loudly, it makes some *other* spec flake. This turns "someone keeps two things in step" into a
 * build gate, the way `classic-links.mjs` does for AD-44.
 *
 * **"Reaches" means through the import graph, not only in the file's own text.** A spec that takes
 * its page from a shared helper writes neither `createBrowserContext(` nor `resetRememberedState(`
 * of its own, so a checker keyed on those two spellings scores it zero contexts and waves it
 * through with nothing pinned. This resolves the local `./*.mjs` graph over `ui/browser/` and
 * charges a spec for every context it creates **or reaches** through an imported binding, an alias
 * of one, or a file-local wrapper around one; the reset is charged the same way, so a helper that
 * creates a context without resetting refuses every spec that calls it.
 *
 * **The residual failure modes, named rather than discovered later.** Three are about what the
 * graph can see: the leaf predicate is still a spelling (`createBrowserContext(` /
 * `browser.newPage(`), so a helper that reached a page some third way would reopen the hole one
 * layer down; the graph is scoped to `ui/browser/`, so a helper moved to `ui/tools/` or
 * `browser.config.mjs` leaves it; and the graph says a helper *calls* the reset, not that the call
 * is unconditional. Three more are about the scanner itself, which is lexical rather than a
 * parser: `stripComments` has no regex-literal state, so a `/` or a quote inside a regex literal
 * can mis-read the rest of a line or desynchronise quote tracking; `localImports` matches only
 * single-quoted specifiers; and `functionUnits` matches braces and parentheses without regard for
 * string literals, so a `}` or a `)` inside one truncates a unit's body. The scanner three can miss
 * a call either way -- a comment left unstripped is counted, a line wrongly read as a comment is
 * not -- so neither direction is safe by construction; the shipped tree's own run is what catches
 * an over-count, and `browser-reset.test.mjs`'s floor on the number of helper-sourced specs the
 * graph resolved is what turns "the graph went empty" from a clean report into a red test.
 *
 * **The exemption is declared in the spec, never listed here.** A spec that is *about* this state
 * surviving does its own clearing; it says so with a `preferences-reset-exempt:` marker plus a
 * reason on the same line. A list inside this file would be a second place to keep in step, which
 * is the failure this check exists to remove.
 *
 * **It reports on every run, clean or not.** A checker that exits 0 silently cannot be told apart
 * from one that looked at nothing -- so every run prints the number of spec files scanned, how many
 * reach a context, how many of those reach it only through a helper, how many reset, and one line
 * per honored exemption with its reason.
 *
 * It follows `classic-links.mjs`'s shape: pure predicates, a thin `main()` doing the impure work,
 * and the `pathToFileURL` direct-invocation guard. Wired into `prebuild` and `prestart`
 * (`ui/package.json`).
 *
 * Usage: `node tools/browser-reset.mjs`. Exit 1 on any refusal, 0 otherwise.
 */

import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';

/** The directory the browser specs live in, relative to `ui/`. */
export const BROWSER_DIR = 'browser';

/** The call that opens a context and therefore no longer starts from a clean slate. */
export const CONTEXT_CALL = 'createBrowserContext(';

/**
 * The other way a spec reaches a signed-in page: the browser's own default context.
 *
 * It starts from a clean slate even less than a fresh context does -- the default context is
 * shared with every other page in the run -- so a spec written this way is exactly the one that
 * must reset, and counting only `CONTEXT_CALL` would wave it through with no reset at all.
 * `context.newPage(` is not this: it follows a `createBrowserContext(` that is already counted.
 */
export const DEFAULT_CONTEXT_CALL = 'browser.newPage(';

/** The helper call that restores the slate the context no longer provides. */
export const RESET_CALL = 'resetRememberedState(';

/**
 * The import that makes a **direct** `RESET_CALL` resolve.
 *
 * Counting the call without checking the import passes a spec that throws
 * `ReferenceError: resetRememberedState is not defined` on its first test -- which is what an
 * integrate-forward produces when one side adds the call and the other side's import loses a
 * merge (2026-09-21: two specs shipped that way and only CI caught them, because this checker
 * and `npm test` both pass on a file the browser tier cannot load). It is required only of a file
 * that spells the call itself; a spec whose reset is reached through a helper imports the helper.
 */
export const RESET_IMPORT = "from './preferences-reset.mjs'";

/** The marker a spec uses to declare it clears the state itself. A reason must follow it. */
export const EXEMPT_MARKER = 'preferences-reset-exempt:';

/**
 * `source` with block and line comments blanked, so a spelling discussed in a doc comment is not
 * read as a call. Quoted text is preserved, and so is a `//` inside a string such as an https URL.
 *
 * `declaredExemption` reads the raw source instead: the exemption marker lives in a comment by
 * design.
 */
export function stripComments(source) {
  let out = '';
  let i = 0;
  let quote = '';
  while (i < source.length) {
    const ch = source[i];
    if (quote !== '') {
      out += ch;
      if (ch === '\\') {
        out += source[i + 1] ?? '';
        i += 2;
        continue;
      }
      if (ch === quote) quote = '';
      i += 1;
      continue;
    }
    if (ch === '"' || ch === "'" || ch === '`') {
      quote = ch;
      out += ch;
      i += 1;
      continue;
    }
    if (ch === '/' && source[i + 1] === '/') {
      while (i < source.length && source[i] !== '\n') i += 1;
      continue;
    }
    if (ch === '/' && source[i + 1] === '*') {
      const end = source.indexOf('*/', i + 2);
      const stop = end === -1 ? source.length : end + 2;
      for (let k = i; k < stop; k += 1) if (source[k] === '\n') out += '\n';
      i = stop;
      continue;
    }
    out += ch;
    i += 1;
  }
  return out;
}

/**
 * The exemption a file declares, or `null` when it declares none.
 *
 * Answers `{ reason }` only when a reason follows the marker on the same line; a bare marker
 * answers `{ reason: '' }` so the caller can refuse it rather than read it as an exemption.
 */
export function declaredExemption(source) {
  for (const line of source.split('\n')) {
    const at = line.indexOf(EXEMPT_MARKER);
    if (at === -1) continue;
    return { reason: line.slice(at + EXEMPT_MARKER.length).trim() };
  }
  return null;
}

/** How many times `needle` occurs in `source`. */
export function occurrences(source, needle) {
  let count = 0;
  let at = source.indexOf(needle);
  while (at !== -1) {
    count += 1;
    at = source.indexOf(needle, at + needle.length);
  }
  return count;
}

/** `code` with every `function NAME(` header reduced to `function(`, so a declaration is not a call. */
function withoutDeclarationHeaders(code) {
  return code.replace(/(?:\basync\s+)?\bfunction\s+[A-Za-z0-9_$]+\s*\(/g, 'function(');
}

/** How many times `name` is called in `code` -- an identifier followed by `(`, never a member access. */
export function callSites(code, name) {
  const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const matches = withoutDeclarationHeaders(code).match(
    new RegExp(`(?<![A-Za-z0-9_$.])${escaped}\\s*\\(`, 'g')
  );
  return matches === null ? 0 : matches.length;
}

/**
 * Every binding this module imports from a sibling `./*.mjs`, as
 * `[{ module, bindings: [{ exported, local }] }]`. A default or namespace import is not resolved:
 * nothing in `ui/browser/` uses one, and guessing at one would be a silent miss rather than a gap.
 */
export function localImports(code) {
  const found = [];
  const pattern = /import\s*\{([^}]*)\}\s*from\s*'(\.\/[^']+\.mjs)'/g;
  let match = pattern.exec(code);
  while (match !== null) {
    const bindings = match[1]
      .split(',')
      .map((piece) => piece.trim())
      .filter((piece) => piece !== '')
      .map((piece) => {
        const parts = piece.split(/\s+as\s+/);
        return { exported: parts[0].trim(), local: (parts[1] ?? parts[0]).trim() };
      });
    found.push({ module: match[2].replace(/^\.\//, ''), bindings });
    match = pattern.exec(code);
  }
  return found;
}

/** The leaf spellings in `code`: contexts opened and resets called, with declarations discounted. */
function leafMarkers(code) {
  const text = withoutDeclarationHeaders(code);
  return {
    contexts: occurrences(text, CONTEXT_CALL) + occurrences(text, DEFAULT_CONTEXT_CALL),
    resets: occurrences(text, RESET_CALL),
  };
}

/** The index of the `)` closing the parameter list that opens at `openParen`, or `-1`. */
function parameterListEnd(code, openParen) {
  let depth = 0;
  for (let i = openParen; i < code.length; i += 1) {
    if (code[i] === '(') depth += 1;
    else if (code[i] === ')') {
      depth -= 1;
      if (depth === 0) return i;
    }
  }
  return -1;
}

/**
 * The top-level function units in `code`, as `[{ name, body }]`. Arrow consts count.
 *
 * A `function NAME(` match ends at the parameter list's own `(`, and a destructured or defaulted
 * parameter puts a `{` inside that list -- so the body brace is the first one after the list
 * CLOSES, never the first one after the name. Taking the first `{` made the "body" of
 * `async function listWithLiveCard({ withRefresh = false } = {})` its parameter pattern, which
 * scans to nothing: an exported helper written that way resolves to `{creates:false}` and every
 * spec importing it is charged zero contexts and waved through.
 */
function functionUnits(code) {
  const units = [];
  const pattern = /(?:export\s+)?(?:async\s+)?function\s+([A-Za-z0-9_$]+)\s*\(|(?:export\s+)?const\s+([A-Za-z0-9_$]+)\s*=\s*(?:async\s*)?\([^)]*\)\s*=>\s*\{/g;
  let match = pattern.exec(code);
  while (match !== null) {
    const name = match[1] ?? match[2];
    let open;
    if (match[1] === undefined) {
      // The arrow-const alternative already consumed its own body brace.
      open = code.indexOf('{', match.index + match[0].length - 1);
    } else {
      const close = parameterListEnd(code, match.index + match[0].length - 1);
      open = close === -1 ? -1 : code.indexOf('{', close);
    }
    if (open !== -1) {
      let depth = 0;
      let end = -1;
      for (let i = open; i < code.length; i += 1) {
        if (code[i] === '{') depth += 1;
        else if (code[i] === '}') {
          depth -= 1;
          if (depth === 0) {
            end = i;
            break;
          }
        }
      }
      if (end !== -1) units.push({ name, body: code.slice(open, end + 1) });
    }
    match = pattern.exec(code);
  }
  return units;
}

/** `{ creates, resets }` with each side true when either side is. */
function union(a, b) {
  return { creates: a.creates || b.creates, resets: a.resets || b.resets };
}

/**
 * What each module's exported bindings reach, as `Map<module, Map<exportName, {creates, resets}>>`.
 *
 * `sources` is `Map<fileName, rawSource>`. Resolution is a fixpoint, so a helper that reaches a
 * context through another helper is charged like one that opens it directly.
 */
export function buildGraph(sources) {
  const parsed = new Map();
  for (const [name, raw] of sources) {
    const code = stripComments(raw);
    parsed.set(name, { code, units: functionUnits(code), imports: localImports(code) });
  }

  const graph = new Map();
  for (const name of parsed.keys()) graph.set(name, new Map());

  for (let round = 0; round < parsed.size + 2; round += 1) {
    let moved = false;
    for (const [name, file] of parsed) {
      // What an imported binding reaches, under this module's local spelling of it.
      const reaching = new Map();
      for (const entry of file.imports) {
        const exports = graph.get(entry.module);
        if (exports === undefined) continue;
        for (const binding of entry.bindings) {
          const reach = exports.get(binding.exported);
          if (reach !== undefined && (reach.creates || reach.resets)) reaching.set(binding.local, reach);
        }
      }
      for (const unit of file.units) {
        let reach = leafMarkers(unit.body);
        let flags = { creates: reach.contexts > 0, resets: reach.resets > 0 };
        for (const [local, inner] of reaching) {
          if (callSites(unit.body, local) > 0) flags = union(flags, inner);
        }
        // A local function that reaches something is itself a binding this module can call.
        if (flags.creates || flags.resets) reaching.set(unit.name, flags);
        const held = graph.get(name).get(unit.name);
        if (held === undefined || held.creates !== flags.creates || held.resets !== flags.resets) {
          graph.get(name).set(unit.name, flags);
          moved = true;
        }
      }
    }
    if (!moved) break;
  }
  return graph;
}

/**
 * What one file is charged: `{ contexts, resets, direct, viaHelper }`.
 *
 * Its own leaf spellings are counted where they stand, and every call of a binding that reaches a
 * context or a reset adds one of each the binding reaches. A file-local wrapper around such a
 * binding is charged at **its** call sites instead, so wrapping a helper neither hides a context
 * nor counts it twice.
 */
export function chargeFor(name, source, graph = null) {
  const code = stripComments(source);
  const direct = leafMarkers(code);
  if (graph === null) return { contexts: direct.contexts, resets: direct.resets, direct, viaHelper: 0 };

  const reaching = new Map();
  for (const entry of localImports(code)) {
    const exports = graph.get(entry.module);
    if (exports === undefined) continue;
    for (const binding of entry.bindings) {
      const reach = exports.get(binding.exported);
      if (reach !== undefined && (reach.creates || reach.resets)) reaching.set(binding.local, reach);
    }
  }
  // Promote file-local wrappers, and blank their bodies so the inner call is not charged as well.
  let counting = code;
  for (let round = 0; round < 8; round += 1) {
    let moved = false;
    for (const unit of functionUnits(counting)) {
      if (reaching.has(unit.name)) continue;
      let flags = { creates: false, resets: false };
      for (const [local, inner] of reaching) {
        if (callSites(unit.body, local) > 0) flags = union(flags, inner);
      }
      if (!flags.creates && !flags.resets) continue;
      reaching.set(unit.name, flags);
      counting = counting.split(unit.body).join('{}');
      moved = true;
    }
    if (!moved) break;
  }

  let contexts = leafMarkers(counting).contexts;
  let resets = leafMarkers(counting).resets;
  let viaHelper = 0;
  for (const [local, reach] of reaching) {
    const sites = callSites(counting, local);
    if (sites === 0) continue;
    if (reach.creates) {
      contexts += sites;
      viaHelper += sites;
    }
    if (reach.resets) resets += sites;
  }
  return { contexts, resets, direct, viaHelper };
}

/**
 * What is wrong with one spec file, or `null` when nothing is.
 *
 * A file that reaches no context is never a problem, whatever else it does -- and "reaches" is the
 * graph's answer, not the file's own spelling, which is what makes that early answer honest.
 *
 * **The count is per context, not per file.** A file that resets once and then opens a second
 * context later is the regression this check exists to stop -- the most likely one, because it is
 * a test added to a spec that already passes -- so one reset is required for each context reached
 * rather than one for the file.
 *
 * `graph` is `buildGraph`'s answer. Omitted, only the file's own spellings are counted.
 */
export function resetProblem(name, source, graph = null) {
  const charge = chargeFor(name, source, graph);
  if (charge.contexts === 0) return null;
  const exemption = declaredExemption(source);
  if (exemption !== null) {
    if (exemption.reason === '') {
      return `${name} declares ${EXEMPT_MARKER} with no reason after it`;
    }
    if (charge.resets > 0) {
      return `${name} both declares ${EXEMPT_MARKER} and calls ${RESET_CALL} -- one or the other`;
    }
    return null;
  }
  if (charge.direct.resets > 0 && !stripComments(source).includes(RESET_IMPORT)) {
    return `${name} calls ${RESET_CALL} but does not import it (${RESET_IMPORT}), so it throws ReferenceError on its first test -- the call and the import have to travel together`;
  }
  if (charge.resets < charge.contexts) {
    return `${name} reaches ${charge.contexts} browser context(s) but reaches ${RESET_CALL} ${charge.resets} time(s); preferences live on the instance since Story 15.5, so a fresh context no longer resets them. Call it wherever a context is created, or declare ${EXEMPT_MARKER} <reason> if this spec clears the state itself`;
  }
  return null;
}

/** Every `.mjs` file directly under the browser directory, sorted. */
export function specFileNames(dir) {
  return readdirSync(dir)
    .filter((name) => name.endsWith('.mjs'))
    .sort();
}

/** `Map<fileName, rawSource>` for every `.mjs` directly under `dir`. */
export function readSources(dir) {
  const sources = new Map();
  for (const name of specFileNames(dir)) sources.set(name, readFileSync(join(dir, name), 'utf8'));
  return sources;
}

/**
 * One pass over a directory: `{ names, problems, exemptions, withContext, withReset, viaHelper }`.
 *
 * `viaHelper` is the number of files whose context comes wholly or partly from an imported
 * binding. A tree where that is zero has either no shared helper or a graph that stopped
 * resolving, and the two are indistinguishable from the report alone -- which is why
 * `browser-reset.test.mjs` holds a floor under it against the shipped tree.
 */
export function inspect(dir) {
  const sources = readSources(dir);
  const graph = buildGraph(sources);
  const problems = [];
  const exemptions = [];
  let withContext = 0;
  let withReset = 0;
  let viaHelper = 0;

  for (const [name, source] of sources) {
    const charge = chargeFor(name, source, graph);
    if (charge.contexts > 0) {
      withContext += 1;
      if (charge.resets > 0) withReset += 1;
      if (charge.viaHelper > 0) viaHelper += 1;
    }
    const problem = resetProblem(name, source, graph);
    if (problem !== null) {
      problems.push(problem);
      continue;
    }
    const exemption = declaredExemption(source);
    if (exemption !== null && charge.contexts > 0) exemptions.push(`${name}: ${exemption.reason}`);
  }
  return { names: [...sources.keys()], problems, exemptions, withContext, withReset, viaHelper };
}

function main() {
  const dir = join(process.cwd(), BROWSER_DIR);
  const report = inspect(dir);

  console.log(`browser-reset: scanned ${report.names.length} file(s) in ui/${BROWSER_DIR}`);
  console.log(
    `browser-reset: ${report.withContext} reach a browser context (${report.viaHelper} through an imported helper) -- ${report.withReset} reach ${RESET_CALL}, ${report.exemptions.length} declare an exemption`
  );
  for (const honored of report.exemptions) console.log(`browser-reset: honored exemption -- ${honored}`);

  if (report.problems.length > 0) {
    for (const problem of report.problems) console.error(`browser-reset: ${problem}`);
    console.error(`browser-reset: ${report.problems.length} refusal(s).`);
    process.exit(1);
  }
  console.log('browser-reset: clean.');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main();
}

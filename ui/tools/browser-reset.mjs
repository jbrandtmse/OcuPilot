#!/usr/bin/env node
/**
 * The browser-context reset check (Story 15.5, AD-50): every spec under `ui/browser/` that
 * creates a browser context must first forget the signing-in account's remembered state, or
 * declare in its own file why it does not.
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
 * **The exemption is declared in the spec, never listed here.** A spec that is *about* this state
 * surviving does its own clearing; it says so with a `preferences-reset-exempt:` marker plus a
 * reason on the same line. A list inside this file would be a second place to keep in step, which
 * is the failure this check exists to remove.
 *
 * **It reports on every run, clean or not.** A checker that exits 0 silently cannot be told apart
 * from one that looked at nothing -- so every run prints the number of spec files scanned, how many
 * create a context, how many reset, and one line per honored exemption with its reason.
 *
 * It follows `classic-links.mjs`'s shape: pure predicates, a thin `main()` doing the impure work,
 * and the `pathToFileURL` direct-invocation guard. Wired into `prebuild` and `prestart`
 * (`ui/package.json`).
 *
 * Usage: `node tools/browser-reset.mjs`. Exit 1 on any refusal, 0 otherwise.
 */

import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

/** The directory the browser specs live in, relative to `ui/`. */
export const BROWSER_DIR = 'browser';

/** The call that opens a context and therefore no longer starts from a clean slate. */
export const CONTEXT_CALL = 'createBrowserContext(';

/** The helper call that restores the slate the context no longer provides. */
export const RESET_CALL = 'resetRememberedState(';

/** The marker a spec uses to declare it clears the state itself. A reason must follow it. */
export const EXEMPT_MARKER = 'preferences-reset-exempt:';

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

/**
 * What is wrong with one spec file, or `null` when nothing is.
 *
 * A file that opens no context is never a problem, whatever else it does.
 */
export function resetProblem(name, source) {
  if (!source.includes(CONTEXT_CALL)) return null;
  const exemption = declaredExemption(source);
  if (exemption !== null) {
    if (exemption.reason === '') {
      return `${name} declares ${EXEMPT_MARKER} with no reason after it`;
    }
    if (source.includes(RESET_CALL)) {
      return `${name} both declares ${EXEMPT_MARKER} and calls ${RESET_CALL} -- one or the other`;
    }
    return null;
  }
  if (!source.includes(RESET_CALL)) {
    return `${name} opens a browser context but never calls ${RESET_CALL}; preferences live on the instance since Story 15.5, so a fresh context no longer resets them. Call it where the context is created, or declare ${EXEMPT_MARKER} <reason> if this spec clears the state itself`;
  }
  return null;
}

/** Every `.mjs` file directly under the browser directory, sorted. */
export function specFileNames(dir) {
  return readdirSync(dir)
    .filter((name) => name.endsWith('.mjs'))
    .sort();
}

function main() {
  const dir = join(process.cwd(), BROWSER_DIR);
  const names = specFileNames(dir);
  const problems = [];
  const exemptions = [];
  let withContext = 0;
  let withReset = 0;

  for (const name of names) {
    const source = readFileSync(join(dir, name), 'utf8');

    // Both tallies count only files that open a context, so they reconcile with each other:
    // `preferences-reset.mjs` matches RESET_CALL on its own definition and opens nothing.
    if (!source.includes(CONTEXT_CALL)) continue;
    withContext += 1;
    if (source.includes(RESET_CALL)) withReset += 1;

    const problem = resetProblem(name, source);
    if (problem !== null) {
      problems.push(problem);
      continue;
    }
    const exemption = declaredExemption(source);
    if (exemption !== null) exemptions.push(`${name}: ${exemption.reason}`);
  }

  console.log(`browser-reset: scanned ${names.length} file(s) in ui/${BROWSER_DIR}`);
  console.log(`browser-reset: ${withContext} open a browser context -- ${withReset} call ${RESET_CALL}, ${exemptions.length} declare an exemption`);
  for (const honored of exemptions) console.log(`browser-reset: honored exemption -- ${honored}`);

  if (problems.length > 0) {
    for (const problem of problems) console.error(`browser-reset: ${problem}`);
    console.error(`browser-reset: ${problems.length} refusal(s).`);
    process.exit(1);
  }
  console.log('browser-reset: clean.');
}

if (process.argv[1] !== undefined && import.meta.url === pathToFileURL(fileURLToPath(import.meta.url)).href && process.argv[1].endsWith('browser-reset.mjs')) {
  main();
}

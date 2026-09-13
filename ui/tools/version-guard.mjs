#!/usr/bin/env node
/**
 * Pure version guard for the pinned stack (Story 1.1).
 *
 * `checkVersions` is a pure predicate over version strings — no filesystem or process
 * access — so the not-ok cases (a Node 20 install, a floated TypeScript 5.9 or 7.x) can
 * be asserted without actually installing an unsupported toolchain; see
 * `version-guard.test.mjs`. The CLI entry point below is the only part that touches
 * `process.versions` or `node_modules`, and it is what `prebuild` / `pretest` invoke so
 * an unsupported toolchain fails with a clear message before any compilation starts.
 */

import { readFileSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, join } from 'node:path';

// engines.node in package.json — keep the two in sync.
export const NODE_RANGE_LABEL = '^22.22.3 || ^24.15.0 || ^26.0.0';
const NODE_CARETS = ['22.22.3', '24.15.0', '26.0.0'];

// @angular/build (Angular 22) requires exactly this band; TS 5.9 and earlier are a v22
// breaking change, and TS 7 (current stable) is refused by @angular/compiler-cli.
export const TYPESCRIPT_RANGE_LABEL = '>=6.0.0 <6.1.0';
const TYPESCRIPT_MIN = [6, 0, 0];
const TYPESCRIPT_MAX = [6, 1, 0];

/** Parse a "X.Y.Z..." version string into a 3-element numeric tuple. */
function parseVersion(version) {
  const m = /^v?(\d+)\.(\d+)\.(\d+)/.exec(String(version));
  if (!m) {
    throw new Error(`Cannot parse version string: ${version}`);
  }
  return [Number(m[1]), Number(m[2]), Number(m[3])];
}

/** -1, 0 or 1 as a < b, a === b, a > b, comparing tuples component-wise. */
function compare(a, b) {
  for (let i = 0; i < 3; i++) {
    if (a[i] !== b[i]) {
      return a[i] < b[i] ? -1 : 1;
    }
  }
  return 0;
}

/** Whether `version` satisfies the caret range `^base` (>=base, <next-major). */
function satisfiesCaret(version, base) {
  const v = parseVersion(version);
  const min = parseVersion(base);
  const max = [min[0] + 1, 0, 0];
  return compare(v, min) >= 0 && compare(v, max) < 0;
}

function isSupportedNode(version) {
  return NODE_CARETS.some((base) => satisfiesCaret(version, base));
}

function isSupportedTypeScript(version) {
  const v = parseVersion(version);
  return compare(v, TYPESCRIPT_MIN) >= 0 && compare(v, TYPESCRIPT_MAX) < 0;
}

/**
 * Pure predicate: `{node, typescript}` version strings in, `{ok, errors}` out. Each
 * not-ok case names the range it violated, so a caller never has to re-derive the
 * message from the version alone.
 */
export function checkVersions({ node, typescript }) {
  const errors = [];
  // The number of constraints this call evaluated, reported by `main()` so a guard that checked
  // nothing and a guard that found nothing wrong print different lines (Story 1.17).
  let checked = 0;
  checked += 1;
  if (!isSupportedNode(node)) {
    errors.push(
      `Node ${node} is not supported. OcuPilot requires Node ${NODE_RANGE_LABEL} (Node 20 and earlier are not supported by Angular 22).`
    );
  }
  checked += 1;
  if (!isSupportedTypeScript(typescript)) {
    errors.push(
      `TypeScript ${typescript} is not supported. OcuPilot requires TypeScript ${TYPESCRIPT_RANGE_LABEL} exactly (5.9 and earlier are a v22 breaking change; 7.x is refused by @angular/compiler-cli).`
    );
  }
  return { ok: errors.length === 0, errors, checked };
}

/** Read the installed `typescript` package's own version from its package.json. */
function resolveInstalledTypeScriptVersion() {
  const here = dirname(fileURLToPath(import.meta.url));
  const pkgPath = join(here, '..', 'node_modules', 'typescript', 'package.json');
  const pkg = JSON.parse(readFileSync(pkgPath, 'utf8'));
  return pkg.version;
}

function main() {
  let typescriptVersion;
  try {
    typescriptVersion = resolveInstalledTypeScriptVersion();
  } catch (err) {
    console.error(
      `version-guard: could not resolve the installed typescript version (${err.message}). Run npm ci first.`
    );
    process.exit(1);
    return;
  }

  const result = checkVersions({ node: process.versions.node, typescript: typescriptVersion });
  if (!result.ok) {
    console.error('version-guard: unsupported toolchain \u2014');
    for (const message of result.errors) {
      console.error(`  - ${message}`);
    }
    process.exit(1);
    return;
  }
  // The size of what this looked at, like every other gate CI runs: the two toolchain
  // constraints it checked and the versions it checked them against. "are both supported" named
  // no population, so a guard that had checked nothing printed the same line as one that passed.
  console.log(
    `version-guard: checked ${result.checked} constraint(s); Node ${process.versions.node} ` +
      `and TypeScript ${typescriptVersion} are both supported.`
  );
}

// Only run the CLI when invoked directly (e.g. `node tools/version-guard.mjs`), not
// when imported by the test suite.
//
// pathToFileURL, not a `file://` template literal: `import.meta.url` is percent-encoded
// but `process.argv[1]` is not, so on any checkout path containing a space (or a
// non-ASCII character, or on Windows) the string comparison silently returns false,
// `main()` never runs, and `prebuild`/`pretest` exit 0 having checked nothing. A guard
// that fails open is worse than no guard, since the build then starts on an unsupported
// toolchain with no error to notice.
if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  main();
}

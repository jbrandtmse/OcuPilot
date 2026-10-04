// Ship the licence notices inside the served root (DW-217).
//
// `ng build` extracts `dist/ocupilot-ui/3rdpartylicenses.txt` beside `browser/`, one directory
// above what `module.xml`'s FileCopy and the container start path install. This copies it into
// `browser/`, so the installed shell serves it at `/ocupilot/3rdpartylicenses.txt`, and appends
// every notice under `ui/licenses/` -- code ported into this tree rather than installed from npm,
// which the build's extractor cannot see (Story 19.7) -- in name order, each closed by the
// extractor's own separator line. Run as the `postbuild` script; exits 1 when the extracted file is
// absent or empty, because a build that ships minified third-party code without its notices is not a
// finished build.
//
// Usage: node tools/licenses.mjs [--dist <dir>]   (default: ui/dist/ocupilot-ui)

import { copyFileSync, appendFileSync, existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

export const LICENSES_FILE = '3rdpartylicenses.txt';

/** Where the notices of ported code live: `ui/licenses/`, one `.txt` per harvested project. */
export const NOTICES_DIR = join(dirname(fileURLToPath(import.meta.url)), '..', 'licenses');

/** The line the build's extractor closes each package's entry with. */
export const SEPARATOR = '-'.repeat(80);

/**
 * The text appended after the extracted notices: each `.txt` of `noticesDir`, in name order, its
 * trailing whitespace trimmed, then a blank line and `SEPARATOR`. Empty when the directory holds
 * none.
 */
export function harvestedNotices(noticesDir = NOTICES_DIR) {
  if (!existsSync(noticesDir)) return '';
  return readdirSync(noticesDir)
    .filter((name) => name.endsWith('.txt'))
    .sort()
    .map((name) => `${readFileSync(join(noticesDir, name), 'utf8').trimEnd()}\n\n${SEPARATOR}\n`)
    .join('');
}

/**
 * Copy `<dist>/3rdpartylicenses.txt` into `<dist>/browser/` and append `harvestedNotices`, or throw
 * naming what is missing.
 */
export function shipLicenses(distDir, noticesDir = NOTICES_DIR) {
  const source = join(distDir, LICENSES_FILE);
  const browserDir = join(distDir, 'browser');
  if (!existsSync(source) || statSync(source).size === 0) {
    throw new Error(`${source} is absent or empty; the build extracted no licence notices to ship`);
  }
  if (!existsSync(browserDir)) {
    throw new Error(`${browserDir} does not exist; there is no served root to ship the notices into`);
  }
  const target = join(browserDir, LICENSES_FILE);
  copyFileSync(source, target);
  const harvested = harvestedNotices(noticesDir);
  if (harvested !== '') appendFileSync(target, harvested, 'utf8');
  return target;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const at = process.argv.indexOf('--dist');
  const distDir =
    at > 0 ? process.argv[at + 1] : join(dirname(fileURLToPath(import.meta.url)), '..', 'dist', 'ocupilot-ui');
  try {
    const target = shipLicenses(distDir);
    console.log(`licenses: copied ${LICENSES_FILE} into ${dirname(target)}, with the notices of ported code`);
  } catch (err) {
    console.error(`licenses: ${err.message}`);
    process.exit(1);
  }
}

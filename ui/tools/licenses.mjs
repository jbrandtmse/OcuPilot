// Ship the npm licence notices inside the served root (DW-217).
//
// `ng build` extracts `dist/ocupilot-ui/3rdpartylicenses.txt` beside `browser/`, one directory
// above what `module.xml`'s FileCopy and the container start path install. This copies it into
// `browser/`, so the installed shell serves it at `/ocupilot/3rdpartylicenses.txt`. Run as the
// `postbuild` script; exits 1 when the extracted file is absent or empty, because a build that
// ships minified third-party code without its notices is not a finished build.
//
// Usage: node tools/licenses.mjs [--dist <dir>]   (default: ui/dist/ocupilot-ui)

import { copyFileSync, existsSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

export const LICENSES_FILE = '3rdpartylicenses.txt';

/** Copy `<dist>/3rdpartylicenses.txt` into `<dist>/browser/`, or throw naming what is missing. */
export function shipLicenses(distDir) {
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
  return target;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const at = process.argv.indexOf('--dist');
  const distDir =
    at > 0 ? process.argv[at + 1] : join(dirname(fileURLToPath(import.meta.url)), '..', 'dist', 'ocupilot-ui');
  try {
    const target = shipLicenses(distDir);
    console.log(`licenses: copied ${LICENSES_FILE} into ${dirname(target)}`);
  } catch (err) {
    console.error(`licenses: ${err.message}`);
    process.exit(1);
  }
}

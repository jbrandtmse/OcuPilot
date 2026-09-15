// Helpers for tests that execute this repository's shell scripts (DW-229).
//
// A script under test reaches `docker`, `iris`, `curl` or `sleep` through PATH, so a test puts a
// directory of stubs first on PATH and reads back what the stubs recorded. Every stub is a
// `#!/bin/sh` file; each takes whatever it needs from the environment, never from an
// interpolated literal, so a temporary directory holding `$` or a backtick cannot redirect it.

import { chmodSync, existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

/** Write an executable `#!/bin/sh` stub named `name` into `binDir` from its body lines. */
export function writeStub(binDir, name, lines) {
  mkdirSync(binDir, { recursive: true });
  const path = join(binDir, name);
  writeFileSync(path, ['#!/bin/sh', ...lines, ''].join('\n'));
  chmodSync(path, 0o755);
  return path;
}

/** `env` with `binDir` first on PATH, plus any extra variables. */
export function stubEnv(binDir, extra = {}, env = process.env) {
  return { ...env, PATH: `${binDir}:${env.PATH ?? ''}`, ...extra };
}

/**
 * The shell a script's shebang declares: `'sh'`, `'bash'`, or `null` for anything else.
 * Accepts `#!/bin/sh`, `#!/usr/bin/sh`, `#!/bin/bash`, `#!/usr/bin/bash` and `#!/usr/bin/env bash`.
 */
export function declaredShell(text) {
  const first = text.split('\n', 1)[0];
  const match = /^#!\s*(?:\/usr\/bin\/env\s+|\/usr\/bin\/|\/bin\/)(sh|bash)\s*$/.exec(first);
  return match === null ? null : match[1];
}

/** The absolute shells a `sh` or `bash` script is executed under here: its own, plus dash for `sh`. */
export function shellsFor(shell) {
  if (shell === 'bash') return ['bash'];
  return ['/bin/sh', '/bin/dash'].filter((path) => existsSync(path));
}

/** The lines a capture file holds, or `[]` when nothing was captured. */
export function captured(path) {
  return existsSync(path) ? readFileSync(path, 'utf8').split('\n').filter((line) => line !== '') : [];
}

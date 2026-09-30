import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Every tracked shell script checks out with LF line endings whatever the host's `core.autocrlf`: `git
// check-attr eol` answers `lf` for each tracked `*.sh` and each file under `.githooks/`, and `git
// ls-files --eol` shows LF, or no line ending at all, in its stored copy and in this checkout. Every
// tracked file whose first line is a `sh` or `bash` shebang is among them. Compose runs
// `durable-init.sh`, `container-start.sh` and `container-health.sh` with `sh`, and one checked out with
// CRLF stops at its first command, so a Windows clone could not start the container.
//
// Needs `git` and a Git checkout. The host's global and system attributes files are switched off; a
// repository-local `info/attributes` still applies.
//
// Mutation (Rule 19): delete the `*.sh` line from `.gitattributes` -> the checkout test goes red
// naming every script.

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

/** The pathspecs `.gitattributes` checks out with LF: every `*.sh`, and the Git hooks, which carry no suffix. */
const SCRIPT_PATHSPECS = ['*.sh', '.githooks/'];

/** Run git at the repository root; a failed run fails the test rather than reading as an empty answer. */
function git(args, input) {
  const result = spawnSync('git', ['-c', 'core.attributesFile=/dev/null', ...args], {
    cwd: REPO_ROOT,
    encoding: 'utf8',
    input,
    env: { ...process.env, GIT_ATTR_NOSYSTEM: '1' },
  });
  assert.equal(result.error, undefined, `git could not be run: ${result.error?.message}`);
  assert.equal(result.status, 0, `git ${args.join(' ')} exited ${result.status}: ${result.stderr.trim()}`);
  return result.stdout;
}

/** The tracked files `SCRIPT_PATHSPECS` selects, as paths from the repository root. */
function trackedScripts() {
  return git(['ls-files', '-z', '--', ...SCRIPT_PATHSPECS]).split('\0').filter(Boolean).sort();
}

/** The tracked files whose first line is a `sh` or `bash` shebang, whatever their name. */
function shebangScripts() {
  return git(['grep', '-lzI', '-e', '^#!', '--', '.'])
    .split('\0')
    .filter(Boolean)
    .filter((path) => /^#!.*\b(ba)?sh\b/.test(readFileSync(join(REPO_ROOT, path), 'utf8').split('\n', 1)[0]))
    .sort();
}

/** `git check-attr eol` for each path: a map from path to `lf`, `crlf`, `unspecified` or `unset`. */
function eolOf(paths) {
  const fields = git(['check-attr', '-z', '--stdin', 'eol'], paths.map((path) => `${path}\0`).join('')).split('\0');
  const eol = new Map();
  for (let i = 0; i + 2 < fields.length; i += 3) eol.set(fields[i], fields[i + 2]);
  return eol;
}

/** `git ls-files --eol` for each tracked script: a map from path to its stored (`i/`) and checked-out (`w/`) line endings. */
function storedEol() {
  const eol = new Map();
  for (const record of git(['ls-files', '-z', '--eol', '--', ...SCRIPT_PATHSPECS]).split('\0').filter(Boolean)) {
    const tab = record.indexOf('\t');
    const [index, worktree] = record.slice(0, tab).trim().split(/\s+/);
    eol.set(record.slice(tab + 1), { index: index.replace(/^i\//, ''), worktree: worktree.replace(/^w\//, '') });
  }
  return eol;
}

/** A copy is safe with LF line endings or with none at all, as an empty file or a line with no newline reads. */
const noCrlf = (value) => value === 'lf' || value === 'none';

test('the population is every tracked shell script', () => {
  const scripts = trackedScripts();
  assert.ok(scripts.length >= 10, `found ${scripts.length} tracked shell script(s): ${scripts.join(', ')}`);
  assert.ok(scripts.includes('scripts/durable-init.sh'), 'durable-init.sh, the first script compose runs, is in it');
  const outside = shebangScripts().filter((path) => !scripts.includes(path));
  assert.deepEqual(outside, [], `these shell scripts are neither *.sh nor under .githooks/:\n${outside.join('\n')}`);
});

test('every tracked shell script checks out with LF line endings', () => {
  const scripts = trackedScripts();
  const eol = eolOf(scripts);
  const stored = storedEol();
  assert.deepEqual([...eol.keys()].sort(), scripts, 'git check-attr answered for every script');
  assert.deepEqual([...stored.keys()].sort(), scripts, 'git ls-files --eol answered for every script');
  const notLf = scripts
    .filter((path) => eol.get(path) !== 'lf' || !noCrlf(stored.get(path).index) || !noCrlf(stored.get(path).worktree))
    .map((path) => `${path} (eol: ${eol.get(path)}, stored: ${stored.get(path).index}, checkout: ${stored.get(path).worktree})`);
  assert.deepEqual(notLf, [], `these scripts would not check out with LF:\n${notLf.join('\n')}`);
});

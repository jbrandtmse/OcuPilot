import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Every tracked `*.sh` checks out with LF line endings whatever the host's `core.autocrlf`: `git
// check-attr eol` answers `lf` for each file `git ls-files '*.sh'` lists, and `git ls-files --eol`
// shows LF in its stored copy and in this checkout. These scripts run inside Linux containers, and
// one checked out with CRLF stops at its first line, so a Windows clone could not start the container.
//
// Needs `git` and a Git checkout. The host's global and system attributes files are switched off; a
// repository-local `info/attributes` still applies.
//
// Mutation (Rule 19): delete the `*.sh` line from `.gitattributes` -> the checkout test goes red
// naming every script.

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

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

/** The tracked `*.sh` files, as paths from the repository root. */
function trackedScripts() {
  return git(['ls-files', '-z', '--', '*.sh']).split('\0').filter(Boolean).sort();
}

/** `git check-attr eol` for each path: a map from path to `lf`, `crlf`, `unspecified` or `unset`. */
function eolOf(paths) {
  const fields = git(['check-attr', '-z', '--stdin', 'eol'], paths.map((path) => `${path}\0`).join('')).split('\0');
  const eol = new Map();
  for (let i = 0; i + 2 < fields.length; i += 3) eol.set(fields[i], fields[i + 2]);
  return eol;
}

/** `git ls-files --eol` for each tracked `*.sh`: a map from path to its stored (`i/`) and checked-out (`w/`) line endings. */
function storedEol() {
  const eol = new Map();
  for (const record of git(['ls-files', '-z', '--eol', '--', '*.sh']).split('\0').filter(Boolean)) {
    const tab = record.indexOf('\t');
    const [index, worktree] = record.slice(0, tab).trim().split(/\s+/);
    eol.set(record.slice(tab + 1), { index: index.replace(/^i\//, ''), worktree: worktree.replace(/^w\//, '') });
  }
  return eol;
}

test('the population is every tracked *.sh', () => {
  const scripts = trackedScripts();
  assert.ok(scripts.length >= 10, `found ${scripts.length} tracked shell script(s): ${scripts.join(', ')}`);
  assert.ok(scripts.includes('scripts/durable-init.sh'), 'durable-init.sh, the first script compose runs, is in it');
});

test('every tracked *.sh checks out with LF line endings', () => {
  const scripts = trackedScripts();
  const eol = eolOf(scripts);
  const stored = storedEol();
  assert.deepEqual([...eol.keys()].sort(), scripts, 'git check-attr answered for every script');
  assert.deepEqual([...stored.keys()].sort(), scripts, 'git ls-files --eol answered for every script');
  const notLf = scripts
    .filter((path) => eol.get(path) !== 'lf' || stored.get(path).index !== 'lf' || stored.get(path).worktree !== 'lf')
    .map((path) => `${path} (eol: ${eol.get(path)}, stored: ${stored.get(path).index}, checkout: ${stored.get(path).worktree})`);
  assert.deepEqual(notLf, [], `these scripts would not check out with LF:\n${notLf.join('\n')}`);
});

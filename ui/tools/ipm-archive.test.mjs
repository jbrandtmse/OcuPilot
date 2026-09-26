import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import { captured, stubEnv, writeStub } from './stub-bin.mjs';

/**
 * `scripts/ci-ipm-archive.sh`, the archive builder and its local-installation check (Story 13.3).
 *
 * **What this file is for.** The strongest reading of the story's third criterion -- that nothing
 * reached a package registry -- is a negative over an open set, and the honest way to hold it is
 * to make the contact impossible rather than to assert its absence. So the script runs both of its
 * containers with `--network none`, and what is pinned here is the mechanism: the flag on both
 * `docker run` lines, the closed set of IPM verbs the script issues, the absence of any credential
 * or upload token, and each refusal that stops the script before a container exists.
 *
 * **What it cannot do, said plainly.** "No package registry was contacted at the network level" is
 * not falsified here, because falsifying it would mean making the call. Every assertion below is
 * host-side text or a refusal executed with a stub `docker` on PATH, so nothing in this file
 * creates a container or opens a socket.
 *
 * Mutations (Rule 19): delete `--network none` from either `docker run` line -> the isolation
 * assertion goes red naming that container. Add a fourth IPM verb -> the allow-list equality goes
 * red from one side; remove one -> from the other. Name a credential or an upload token anywhere
 * in the script -> the absence assertions go red. Drop a refusal -> its executed test goes red
 * with exit 0 where 2 was expected.
 */

const here = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(here, '..', '..');
const SCRIPT_PATH = join(REPO_ROOT, 'scripts', 'ci-ipm-archive.sh');
const source = readFileSync(SCRIPT_PATH, 'utf8');

/** The script with its comment lines removed, for assertions about what it DOES. */
function withoutShellComments(text) {
  return text
    .split('\n')
    .filter((line) => !/^\s*#/.test(line))
    .join('\n');
}

const code = withoutShellComments(source);

/** Every `docker run` command line in the script, in order. */
export function dockerRunLines(text) {
  return text.split('\n').filter((line) => /^\s*docker run\b/.test(line));
}

/**
 * Every IPM verb the script issues, in order, read from its `Shell("` occurrences.
 *
 * Derived rather than declared: a verb added to the script in a form this does not see would be a
 * verb nothing holds to the allow-list, which is the hole the equality below exists to close.
 */
export function ipmVerbs(text) {
  return [...text.matchAll(/Shell\("([a-z-]+)/g)].map((match) => match[1]);
}

/**
 * The only IPM verbs this story's script may issue.
 *
 * `load` brings a module in from a directory or a local archive, `package` writes the archive, and
 * `list` reports what an instance carries. All three are local: none of them reads or resolves
 * anything from a package repository, and the script asserts on both instances that
 * `%IPM_Repo.Definition` holds no row for one to resolve against.
 */
export const ALLOWED_IPM_VERBS = ['load', 'package', 'list'];

/**
 * IPM verbs and modifiers that reach a package registry, refused inside any command the script
 * forms.
 *
 * Checked over the `Shell("...")` command strings rather than over the whole file, because that is
 * where an IPM command is formed and because two of these tokens have ordinary meanings elsewhere
 * in the script: `install` names this script's own second container and its `--install-name` flag,
 * and `-community` is part of the pinned image reference `irishealth-community:2026.2`. Of those
 * two, `-community` is additionally checked by shape over the whole file below; `install` is held
 * only here, which is sufficient because every IPM command the script forms is a literal -- the
 * test below holds that, so there is no command string this scan cannot see.
 */
export const REGISTRY_TOKENS = ['publish', 'install', 'uninstall', 'repo', 'enable', 'search', '-community'];

/** Every `Shell("...")` command string the script forms, with its shell variables left as written. */
export function ipmCommands(text) {
  return [...text.matchAll(/Shell\("([^"]*)"/g)].map((match) => match[1]);
}

// --- The containers have no network ----------------------------------------------------------

test('both containers the script creates run with no network at all', () => {
  const runs = dockerRunLines(code);
  assert.equal(runs.length, 2, `the script starts exactly two containers; it starts ${runs.length}: ${JSON.stringify(runs)}`);
  for (const line of runs) {
    assert.match(
      line,
      /--network none/,
      `a container is started without --network none, so "it could not reach a package registry" would be a promise rather than a mechanism: ${line.trim()}`
    );
  }
  // The build container is the one that packages; the second one loads the archive it produced.
  assert.match(runs[0], /\$BUILD_NAME/, 'the first is the packaging container');
  assert.match(runs[1], /\$INSTALL_NAME/, 'the second is the container the archive is loaded on');
});

test('neither container maps a port, and neither mounts anything writable', () => {
  for (const line of dockerRunLines(code)) {
    assert.ok(!/\s-p\s/.test(line), `a container maps a port: ${line.trim()}`);
    assert.ok(!/\d+:\d+(?!\S)/.test(line.replace(/:ro\b/g, '')), `a container carries a port mapping: ${line.trim()}`);
    for (const mount of line.matchAll(/-v\s+"?[^"\s]+"?/g)) {
      assert.match(mount[0], /:ro$|:ro"$/, `a mount is writable, and the staged tree is this repository's: ${mount[0]}`);
    }
  }
  // `--publish` is the long spelling of the same thing, and is foreclosed by the whole-file ban on
  // the string below rather than by a second pattern here.
});

// --- The IPM verbs are a closed set ------------------------------------------------------------

test('the IPM verbs the script issues equal the allow-list, in both directions', () => {
  const verbs = ipmVerbs(code);
  assert.ok(verbs.length >= 3, `the script issues ${verbs.length} IPM command(s); a check over none would pass having checked nothing`);
  assert.deepEqual(
    [...new Set(verbs)].sort(),
    [...ALLOWED_IPM_VERBS].sort(),
    `the script's IPM verbs and this file's allow-list have diverged.\nissued: ${JSON.stringify(verbs)}\nallowed: ${JSON.stringify(ALLOWED_IPM_VERBS)}`
  );
});

test('no IPM command the script forms names a verb or modifier that reaches a package registry', () => {
  const commands = ipmCommands(code);
  assert.ok(commands.length >= 3, `the script forms ${commands.length} IPM command(s)`);
  for (const command of commands) {
    for (const token of REGISTRY_TOKENS) {
      assert.ok(
        !command.includes(token),
        `the IPM command ${JSON.stringify(command)} carries ${JSON.stringify(token)}, which reaches a package registry`
      );
    }
  }
});

test('every IPM command is a literal, so the scans above can see all of them', () => {
  // `ipmVerbs` and `ipmCommands` read `Shell("...")` occurrences. A command built from a variable
  // -- `Shell(tCommand,1,0)` -- would match neither, and would be a verb the allow-list equality
  // never sees. So the number of `Shell(` calls must equal the number of literal ones.
  const calls = [...code.matchAll(/\bShell\(/g)].length;
  assert.ok(calls >= 3, `the script issues ${calls} Shell call(s)`);
  assert.equal(
    ipmCommands(code).length,
    calls,
    'an IPM command is built from a variable, so the allow-list and the registry-token scan cannot see it'
  );
  // Being a literal is not enough: `ipmVerbs` reads `/Shell\("([a-z-]+)/`, so a command whose
  // first character is a `$` or a capital yields NO verb at all and passes the allow-list equality
  // by contributing nothing to either side. The verb itself must therefore be written out, in the
  // spelling IPM's grammar uses, at the front of every command.
  for (const command of ipmCommands(code)) {
    assert.match(
      command,
      new RegExp(`^(${ALLOWED_IPM_VERBS.join('|')})(\\s|$)`),
      `the IPM command ${JSON.stringify(command)} does not begin with a spelled-out allow-listed verb, so the allow-list equality above cannot see which verb it runs`
    );
  }
});

test('containers are created only by the two docker run lines the network check reads', () => {
  // `dockerRunLines` matches lines beginning `docker run`. A container started any other way
  // would carry no `--network none` and nothing here would notice, so the other ways are banned
  // outright rather than matched.
  for (const [what, pattern] of [
    ['docker create', /docker\s+create\b/],
    ['docker start', /docker\s+start\b/],
    ['docker compose', /docker[\s-]+compose\b/],
    ['a --mount or --volume form the -v reader does not see', /--mount\b|--volume\b/],
    ['a docker run continued onto another line', /docker run[^\n]*\\\n/],
    // `--network none` is read off the creation line, so a network attached afterwards would
    // leave every assertion above green over a container that had one.
    ['a network attached after the container was created', /docker\s+network\b/],
  ]) {
    assert.doesNotMatch(code, pattern, `the script creates a container with ${what}, which the --network none assertion above cannot read`);
  }
});

test('the script reads the repository table and never writes to it', () => {
  const statements = [...code.matchAll(/%IPM_Repo\.Definition/g)];
  assert.ok(statements.length >= 1, 'the script asserts on the repository table; an assertion that is absent proves nothing');
  for (const match of code.matchAll(/"([^"]*%IPM_Repo\.Definition[^"]*)"/g)) {
    assert.match(match[1], /^SELECT COUNT\(\*\) FROM %IPM_Repo\.Definition$/, `the only statement over the repository table counts its rows: ${match[1]}`);
  }
  assert.match(code, /REPOSITORIES" != "0"/, 'and zero rows is required rather than reported');
});

// --- The absences ------------------------------------------------------------------------------

test('the script names no credential, no token and nothing that uploads (stealth policy)', () => {
  // Over the RAW file, comments included: a comment that named a token would be a reader's
  // instruction to add one. Seven of these are `ui/tools/ci.test.mjs`'s stealth patterns, applied
  // here because a forbidden token in the script CI runs is as publishing as one in the workflow --
  // with `publish` widened from `npm publish` to the bare word, so `--publish` and `zpm publish`
  // are foreclosed too. The eighth, a credential or token variable, is this script's own: it is
  // the thing a registry upload would need and the workflow has no equivalent.
  for (const [what, pattern] of [
    ['an upload verb', /publish/i],
    ['a secret reference', /secrets\./],
    ['a container push', /docker\s+push/],
    ['a registry login', /docker\/login-action|registry-url/],
    ['a GitHub release', /softprops\/action-gh-release|actions\/create-release|gh\s+release/],
    ['an Open Exchange step', /open\s*exchange|openexchange/i],
    ['a package upload action', /JS-DevTools\/npm-publish|pypa\/gh-action-pypi-publish/],
    ['a credential or token variable', /\$\{?\w*(TOKEN|SECRET|APIKEY|API_KEY|CREDENTIAL)\w*\}?/i],
  ]) {
    assert.doesNotMatch(source, pattern, `the script carries ${what}; nothing here reaches a package registry (Story 13.3 is held by the owner)`);
  }
});

test('every "-community" in the script is part of the pinned image reference', () => {
  // `-community` is the IPM modifier that turns on the community package registry, and it is also
  // half of `intersystems/irishealth-community:2026.2`. Checked by shape so the ban is real rather
  // than dropped for being inconvenient. The bare edition name ("a fresh Community instance")
  // carries no leading hyphen and is not the modifier.
  const hyphenated = [...source.matchAll(/[\w-]*-community\b/gi)];
  assert.ok(hyphenated.length >= 1, 'the pinned image reference is in the file; a check over no occurrence would pass having checked nothing');
  for (const match of hyphenated) {
    assert.match(
      match[0],
      /^(irishealth-community|iris-community)$/,
      `${JSON.stringify(match[0])} is not part of a pinned image reference; -community turns on the community package registry`
    );
  }
});

test('the smoke status is read from the command itself rather than through a pipeline', () => {
  const smokeLines = code.split('\n').filter((line) => line.includes('smoke.sh'));
  assert.equal(smokeLines.length, 1, `the script runs smoke.sh once; it names it on ${smokeLines.length} line(s)`);
  const [line] = smokeLines;
  // `||` is the capture below, not a pipeline; anything left after removing it would be one.
  assert.ok(!line.replace(/\|\|/g, '').includes('|'), `a pipeline reports its LAST stage's status, not smoke.sh's: ${line.trim()}`);
  assert.match(line, /\|\|\s*SMOKE_STATUS=\$\?/, 'the status is captured from the command');
  assert.match(code, /"\$SMOKE_STATUS" -ne 0/, 'and a non-zero status fails the script');
  assert.match(code, /EXECUTED:-0\}" -lt 1/, 'and zero executed checks is a failure, never a pass');
});

test('the manifest drift check runs before anything is staged, and drift stops the script', () => {
  const checkAt = code.indexOf('tools/ipm-manifest.mjs --check');
  const stageAt = code.indexOf('cp -R "$REPO_ROOT/src/."');
  const runAt = code.indexOf('docker run');
  assert.ok(checkAt > 0, 'the script holds module.xml equal to the roster before it builds anything from it');
  assert.ok(stageAt > checkAt, 'before the staging copy');
  assert.ok(runAt > checkAt, 'and before any container starts');
  // Running the checker proves nothing if its status is read and then ignored.
  assert.match(code, /"\$MANIFEST_STATUS" -ne 0/, 'and a non-zero status from the checker stops the script');
});

// --- The refusals, executed with a stub `docker` on PATH ----------------------------------------

/** Run the script with a stub `docker` first on PATH, and report what the stub was asked to do. */
function runRefused(args, { root = REPO_ROOT, env = {} } = {}) {
  const dir = mkdtempSync(join(tmpdir(), 'ocupilot-ipm-archive-'));
  try {
    const bin = join(dir, 'bin');
    const capture = join(dir, 'docker-argv.txt');
    mkdirSync(bin);
    writeStub(bin, 'docker', ['printf \'%s\\n\' "$*" >> "$OCUPILOT_DOCKER_CAPTURE"', 'exit 0']);
    for (const name of ['rm', 'cp']) {
      writeStub(bin, name, [`printf '${name} %s\\n' "$*" >> "$OCUPILOT_DESTRUCTIVE_CAPTURE"`, 'exit 0']);
    }
    const destructive = join(dir, 'destructive-argv.txt');
    const result = spawnSync('sh', [join(root, 'scripts', 'ci-ipm-archive.sh'), ...args], {
      cwd: root,
      encoding: 'utf8',
      env: stubEnv(bin, { OCUPILOT_DOCKER_CAPTURE: capture, OCUPILOT_DESTRUCTIVE_CAPTURE: destructive, ...env }),
    });
    return {
      ...result,
      output: `${result.stdout}${result.stderr}`,
      docker: captured(capture),
      destructive: captured(destructive),
    };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

const PINNED_IMAGE = 'intersystems/irishealth-community:2026.2';

/**
 * That no container was created, whatever else the refusal did.
 *
 * A refusal raised after the EXIT trap is installed still runs `cleanup`, which removes this
 * script's own two containers by name. That is the trap doing its job, so it is allowed by name
 * and nothing else is.
 */
function assertNothingRemovedOrCopied(refused) {
  assert.deepEqual(
    refused.destructive,
    [],
    `a refusal reached rm or cp; every refusal here must land before the script removes its scratch directory: ${JSON.stringify(refused.destructive)}`
  );
}

function assertNoContainerStarted(docker) {
  for (const call of docker) {
    assert.match(
      call,
      /^rm -f ocupilot-ipm-(build|install)$/,
      `the refusal asked docker for something other than the EXIT trap removing this script's own containers: ${call}`
    );
  }
}

test('a container name that belongs to somebody else is refused before any container is touched', () => {
  // The live instance, the three owner-managed slot dev instances and the three per-slot
  // throwaways. This matters more here than in ci-throwaway.sh: the EXIT trap removes BOTH of the
  // names it was given, so a refusal that arrived late would remove a running instance.
  for (const name of [
    'ocupilot',
    'ocupilot-slot-a',
    'ocupilot-slot-b',
    'ocupilot-slot-c',
    'ocupilot-ci',
    'ocupilot-b-ci',
    'ocupilot-c-ci',
  ]) {
    for (const flag of ['--build-name', '--install-name']) {
      const refused = runRefused([flag, name, '--image', PINNED_IMAGE]);
      assert.equal(refused.status, 2, `${flag} ${name} was not refused: ${refused.output}`);
      assert.ok(refused.output.includes(name), `the refusal names the container: ${refused.output}`);
      assert.deepEqual(refused.docker, [], `nothing was asked of docker: ${JSON.stringify(refused.docker)}`);
      assertNothingRemovedOrCopied(refused);
    }
  }
});

test('the two container names must differ, because the install target must be a fresh instance', () => {
  const refused = runRefused(['--build-name', 'ocupilot-x', '--install-name', 'ocupilot-x', '--image', PINNED_IMAGE]);
  assert.equal(refused.status, 2, `one name for both containers was not refused: ${refused.output}`);
  assert.match(refused.output, /SECOND, fresh instance/, refused.output);
  assert.deepEqual(refused.docker, []);
  assertNothingRemovedOrCopied(refused);
});

test('a floating image tag, or none, is refused (AD-27)', () => {
  for (const image of [
    'intersystems/irishealth-community:latest-cd',
    'intersystems/irishealth-community:latest-em',
    'intersystems/irishealth-community:latest',
    'intersystems/irishealth-community',
    'registry.example.com:5000/irishealth',
  ]) {
    const refused = runRefused(['--image', image]);
    assert.equal(refused.status, 2, `${image} was not refused: ${refused.output}`);
    assert.ok(refused.output.includes(image), `the refusal names the image: ${refused.output}`);
    assert.deepEqual(refused.docker, []);
    assertNothingRemovedOrCopied(refused);
  }
  const missing = runRefused([]);
  assert.equal(missing.status, 2, `a missing --image was not refused: ${missing.output}`);
  assert.match(missing.output, /--image is required/);
});

test('a --dir outside a scratch root is refused, because the script removes it recursively', () => {
  for (const dir of ['/', '/tmp', '/Users/someone/work', 'relative/path', '/tmp/../Users/someone', '/tmpnotinside']) {
    const refused = runRefused(['--image', PINNED_IMAGE, '--dir', dir]);
    assert.equal(refused.status, 2, `${dir} was not refused: ${refused.output}`);
    assert.ok(refused.output.includes(dir), `the refusal names the directory: ${refused.output}`);
    assert.deepEqual(refused.docker, []);
    assertNothingRemovedOrCopied(refused);
  }
});

test('a degenerate TMPDIR does not widen the scratch-root guard to every absolute path', () => {
  // The guard's $TMPDIR arm is `"$SCRATCH_TMPDIR"/?*`. A TMPDIR that is nothing but slashes strips
  // to the empty string, and the arm becomes `/?*` -- which every absolute path matches, so the
  // directory the script is about to `rm -rf` would no longer have to be a scratch directory.
  for (const value of ['/', '//']) {
    const refused = runRefused(['--image', PINNED_IMAGE, '--dir', '/Users/someone/work'], {
      env: { TMPDIR: value },
    });
    assert.equal(
      refused.status,
      2,
      `TMPDIR=${value} let a non-scratch --dir through the guard on a directory the script removes recursively: ${refused.output}`
    );
    assert.deepEqual(refused.docker, []);
    assertNothingRemovedOrCopied(refused);
  }

  // The other degenerate shape: a TMPDIR that is not absolute makes the arm relative too, so a
  // relative --dir under it passes and is then removed relative to wherever the script was run --
  // which, for the invocations in this tree, is the repository root.
  for (const value of ['work', './work']) {
    const refused = runRefused(['--image', PINNED_IMAGE, '--dir', 'work/ocupilot-ipm'], {
      env: { TMPDIR: value },
    });
    assert.equal(
      refused.status,
      2,
      `TMPDIR=${value} let a relative --dir through the guard on a directory the script removes recursively: ${refused.output}`
    );
    assert.deepEqual(refused.docker, []);
    assertNothingRemovedOrCopied(refused);
  }
});

test('an unbuilt client bundle is refused, naming the directory and the command that builds it', () => {
  // Driven from a scratch repository root rather than this one, where the bundle is normally
  // present: the script derives its root from its own path, so a copy of it in a tree that has a
  // manifest checker and no bundle reaches exactly the refusal under test.
  const dir = mkdtempSync(join(tmpdir(), 'ocupilot-ipm-noroot-'));
  try {
    mkdirSync(join(dir, 'scripts'), { recursive: true });
    mkdirSync(join(dir, 'ui', 'tools'), { recursive: true });
    writeFileSync(join(dir, 'scripts', 'ci-ipm-archive.sh'), source);
    writeFileSync(join(dir, 'ui', 'tools', 'ipm-manifest.mjs'), '// a manifest that has not drifted\n');

    const refused = runRefused(['--image', PINNED_IMAGE], { root: dir });
    assert.equal(refused.status, 2, `an absent bundle was not refused: ${refused.output}`);
    assert.match(refused.output, /ui\/dist\/ocupilot-ui\/browser/, `the refusal names the directory: ${refused.output}`);
    assert.match(refused.output, /cd ui && npm run build/, `and the command that produces it: ${refused.output}`);
    assertNoContainerStarted(refused.docker);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('an unknown argument is refused rather than ignored', () => {
  const refused = runRefused(['--image', PINNED_IMAGE, '--upload']);
  assert.equal(refused.status, 2, refused.output);
  assert.match(refused.output, /unknown argument --upload/);
  assert.deepEqual(refused.docker, []);
});

test('an empty --build-name or --install-name is refused, not silently taken', () => {
  // `refuse_taken_name` has an explicit `""` arm distinct from the six protected-name arms, and it
  // is reachable: `--build-name ''` sets BUILD_NAME to the empty string via ordinary shell
  // assignment, the same as any other value.
  for (const flag of ['--build-name', '--install-name']) {
    const refused = runRefused(['--image', PINNED_IMAGE, flag, '']);
    assert.equal(refused.status, 2, `${flag} '' was not refused: ${refused.output}`);
    assert.match(refused.output, /cannot be empty/, `the refusal names the empty value: ${refused.output}`);
    assert.deepEqual(refused.docker, [], `nothing was asked of docker: ${JSON.stringify(refused.docker)}`);
    assertNothingRemovedOrCopied(refused);
  }
});

// --- The class-count equality's own half (AC1's residual risk) ---------------------------------

/**
 * The exact `find` invocation the script uses to compute `STAGED_CLASSES` (the count the archive's
 * own class count is compared against). Extracted rather than duplicated, so a change to the
 * pattern in the script is what this test sees.
 */
export function stagedClassesCommand(text) {
  const line = text.split('\n').find((l) => l.includes('STAGED_CLASSES=$('));
  assert.ok(line, 'STAGED_CLASSES=$(...) was not found in the script');
  const match = line.match(/STAGED_CLASSES=\$\((.*)\)$/);
  assert.ok(match, `could not extract the find command from: ${line}`);
  return match[1];
}

test('the staged-class count excludes OcuPilot/Test/ and counts only .cls files', () => {
  // The spec's Verification section names an unclosed residual risk: the archive-vs-staged class
  // count equality (ci-ipm-archive.sh:280) assumes IPM's exporter emits exactly the non-test .cls
  // set, which is IPM's own behavior and not this script's -- not falsifiable here without running
  // a real archive. What IS this script's own behavior, and was not previously pinned, is the other
  // side of that equality: the `find` command that decides what counts as "staged" in the first
  // place. This runs that exact command against a fixture tree, host-side, no container involved.
  const dir = mkdtempSync(join(tmpdir(), 'ocupilot-staged-classes-'));
  try {
    const ocupilot = join(dir, 'OcuPilot');
    mkdirSync(join(ocupilot, 'Sub'), { recursive: true });
    mkdirSync(join(ocupilot, 'Test', 'Sub'), { recursive: true });
    writeFileSync(join(ocupilot, 'A.cls'), '');
    writeFileSync(join(ocupilot, 'Sub', 'B.cls'), '');
    writeFileSync(join(ocupilot, 'C.mac'), ''); // not a .cls: must not be counted
    writeFileSync(join(ocupilot, 'Test', 'D.cls'), ''); // under Test/: must be excluded
    writeFileSync(join(ocupilot, 'Test', 'Sub', 'E.cls'), ''); // nested under Test/: must be excluded

    const command = stagedClassesCommand(code).replace('"$DIR/module/src/OcuPilot"', JSON.stringify(ocupilot));
    const result = spawnSync('sh', ['-c', command], { encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr);
    assert.equal(
      result.stdout.trim(),
      '2',
      `expected exactly A.cls and Sub/B.cls (2): stdout=${JSON.stringify(result.stdout)} stderr=${JSON.stringify(result.stderr)}`
    );
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

// --- The member comparison does not depend on which tar listed the archive ----------------------

/**
 * The script's archive-contents block, from the line that builds `MEMBERS` to the line that
 * reports what the archive carries. Sliced out of the script rather than restated, so the
 * comparisons this runs are the comparisons that run in CI. `fail()` is the caller's, supplied by
 * the prelude below, so what the block does with a verdict is pinned here and what `fail()` itself
 * prints is not.
 */
export function archiveContentsBlock(text) {
  const lines = text.split('\n');
  const start = lines.findIndex((line) => line.startsWith('RAW_MEMBERS=$(tar tzf'));
  const end = lines.findIndex((line) => line.includes('and no OcuPilot/Test/ member"'));
  assert.ok(start >= 0, 'RAW_MEMBERS=$(tar tzf ...) was not found in the script');
  assert.ok(end > start, 'the archive-contents summary line was not found after MEMBERS');
  return lines.slice(start, end + 1).join('\n');
}

test('the archive-contents comparison accepts a member list with doubled slashes at the joins', () => {
  // IPM stores `ui/dist/ocupilot-ui/browser//index.html` and `src//cls`, because the declared
  // <FileCopy> name already ends in a slash and IPM joins another. A listing may or may not show
  // that doubling, and the comparison must not care: the same archive must read the same way.
  // Run the script's own block against a staged fixture with a stub `tar`, once per listing shape.
  const block = archiveContentsBlock(source);
  const dir = mkdtempSync(join(tmpdir(), 'ocupilot-members-'));
  try {
    const bundle = 'ui/dist/ocupilot-ui/browser';
    mkdirSync(join(dir, 'module', 'src', 'OcuPilot', 'Sub'), { recursive: true });
    mkdirSync(join(dir, 'module', 'src', 'OcuPilot', 'Test'), { recursive: true });
    mkdirSync(join(dir, 'module', bundle, 'media'), { recursive: true });
    writeFileSync(join(dir, 'module', 'src', 'OcuPilot', 'A.cls'), '');
    writeFileSync(join(dir, 'module', 'src', 'OcuPilot', 'Sub', 'B.cls'), '');
    writeFileSync(join(dir, 'module', 'src', 'OcuPilot', 'Test', 'D.cls'), '');
    writeFileSync(join(dir, 'module', bundle, 'index.html'), '');
    writeFileSync(join(dir, 'module', bundle, 'media', 'Inter-OFL.txt'), '');

    const doubled = [
      'module.xml',
      'src//cls/',
      'src/cls/OcuPilot/A.cls',
      'src/cls/OcuPilot/Sub/B.cls',
      `${bundle}//index.html`,
      `${bundle}/media//Inter-OFL.txt`,
    ];
    const collapsed = doubled.map((member) => member.replace(/\/{2,}/g, '/'));

    const bin = join(dir, 'bin');
    const membersFile = join(dir, 'members.txt');
    writeStub(bin, 'tar', ['cat "$OCUPILOT_TAR_MEMBERS"']);
    const prelude = [
      'set -e',
      `DIR=${JSON.stringify(dir)}`,
      `BUNDLE=${JSON.stringify(bundle)}`,
      'ARCHIVE=/dev/null',
      'ARTIFACT_NAME=ocupilot.tgz',
      'fail() { echo "FAIL $1: $2"; exit 1; }',
    ].join('\n');

    for (const [label, members] of [['doubled', doubled], ['collapsed', collapsed]]) {
      writeFileSync(membersFile, `${members.join('\n')}\n`);
      const result = spawnSync('sh', ['-c', `${prelude}\n${block}`], {
        encoding: 'utf8',
        env: stubEnv(bin, { OCUPILOT_TAR_MEMBERS: membersFile }),
      });
      assert.equal(
        result.status,
        0,
        `the ${label} member list was rejected, so the comparison depends on how the archive was listed: ${result.stdout}${result.stderr}`
      );
      assert.match(
        result.stdout,
        /all 2 staged OcuPilot class\(es\), all 2 staged bundle file\(s\)/,
        `the ${label} member list did not match the staged tree: ${result.stdout}`
      );
    }

    // The other direction, so the normalization cannot be widened into something that accepts
    // anything: a member that is genuinely absent must still be named and still exit non-zero.
    // This is the branch that failed on the Linux runner, and nothing else executes it.
    writeFileSync(membersFile, `${doubled.filter((member) => !member.endsWith('index.html')).join('\n')}\n`);
    const rejected = spawnSync('sh', ['-c', `${prelude}\n${block}`], {
      encoding: 'utf8',
      env: stubEnv(bin, { OCUPILOT_TAR_MEMBERS: membersFile }),
    });
    assert.equal(
      rejected.status,
      1,
      `an archive genuinely missing a staged bundle file was accepted: ${rejected.stdout}${rejected.stderr}`
    );
    assert.match(
      rejected.stdout,
      /is missing 1 staged bundle file\(s\)[^\n]*index\.html/,
      `the failure did not name the missing member: ${rejected.stdout}${rejected.stderr}`
    );
    // The diagnostic under that failure is the only place the shape IPM actually stored is ever
    // visible -- the container the archive came from is gone by the time anyone reads the CI log,
    // and it is what let DW-1334 be diagnosed at all. It must dump the listing as tar gave it, not
    // the collapsed one the comparisons read.
    assert.match(
      rejected.stdout,
      /exactly as tar listed them:[\s\S]*browser\/media\/\/Inter-OFL\.txt/,
      `the diagnostic dumped a slash-collapsed listing, so the next failure cannot show what IPM stored: ${rejected.stdout}`
    );

    // A member under OcuPilot/Test/ must still be excluded when the join is doubled. This is the
    // one arm where a missed doubling is a false GREEN rather than a false red: the exclusion is
    // an unanchored `grep 'OcuPilot/Test/'`, which `OcuPilot//Test//x` does not match, so without
    // the normalization a Scope="test" member would ship unnoticed. The member here is not a .cls,
    // so the arm is exercised alone -- a doubled-join .cls under Test is caught twice over, by
    // this arm and by the class equality, whose staged side excludes OcuPilot/Test/.
    writeFileSync(membersFile, `${[...doubled, 'src//cls/OcuPilot//Test//fixture.xml'].join('\n')}\n`);
    const shippedTest = spawnSync('sh', ['-c', `${prelude}\n${block}`], {
      encoding: 'utf8',
      env: stubEnv(bin, { OCUPILOT_TAR_MEMBERS: membersFile }),
    });
    assert.equal(
      shippedTest.status,
      1,
      `an archive carrying a doubled-join OcuPilot/Test/ member was accepted: ${shippedTest.stdout}${shippedTest.stderr}`
    );
    assert.match(
      shippedTest.stdout,
      /carries a member under OcuPilot\/Test\//,
      `the failure did not name the Scope="test" member: ${shippedTest.stdout}${shippedTest.stderr}`
    );
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

// --- The manifest comparison's floor is what the roster declares ---------------------------------

/**
 * The script's manifest-comparison block, from extracting the archive's `module.xml` to the line
 * that reports the comparison passed. Sliced out of the script, as `archiveContentsBlock` is.
 */
export function manifestComparisonBlock(text) {
  const lines = text.split('\n');
  const start = lines.findIndex((line) => line.startsWith('tar xzf "$ARCHIVE" -C "$DIR/extract" module.xml'));
  const end = lines.findIndex((line) => line.includes("the archive's manifest declares the same"));
  assert.ok(start >= 0, 'the manifest extraction was not found in the script');
  assert.ok(end > start, 'the manifest comparison summary line was not found after it');
  return lines.slice(start, end + 1).join('\n');
}

// Mutation (Rule 19): restore the literal `-lt 11` -> the manifest with an extra attribute-less
// <Dependency> reads 11 declarations against a floor of 11 and passes, so the first leg goes red.
test('a manifest declaring more than the comparison reads fails, naming both numbers', () => {
  const block = manifestComparisonBlock(source);
  const dir = mkdtempSync(join(tmpdir(), 'ocupilot-manifest-floor-'));
  try {
    mkdirSync(join(dir, 'extract'), { recursive: true });
    const roster = join(dir, 'roster');
    mkdirSync(roster, { recursive: true });
    const shipped = readFileSync(join(REPO_ROOT, 'module.xml'), 'utf8');
    const bin = join(dir, 'bin');
    writeStub(bin, 'tar', ['cp "$OCUPILOT_TAR_MANIFEST" "$4/module.xml"']);
    const prelude = [
      'set -e',
      `DIR=${JSON.stringify(dir)}`,
      `REPO_ROOT=${JSON.stringify(roster)}`,
      'ARCHIVE=/dev/null',
      'ARTIFACT_NAME=ocupilot.tgz',
      'fail() { echo "FAIL $1: $2"; exit 1; }',
    ].join('\n');
    const run = (manifest) => {
      writeFileSync(join(roster, 'module.xml'), manifest);
      return spawnSync('sh', ['-c', `${prelude}\n${block}`], {
        encoding: 'utf8',
        env: stubEnv(bin, { OCUPILOT_TAR_MANIFEST: join(roster, 'module.xml') }),
      });
    };

    const extra = shipped.replace('</Module>', '  <Dependency><Name>probe-module</Name><Version>1.0.0</Version></Dependency>\n    </Module>');
    assert.notEqual(extra, shipped, 'the fixture manifest gained a <Dependency>');
    const short = run(extra);
    assert.equal(short.status, 1, `a declaration the comparison cannot read was accepted: ${short.stdout}${short.stderr}`);
    assert.match(short.stdout, /read only 11 declaration\(s\)[^\n]*fewer than the 12 it declares/, `the failure names both numbers: ${short.stdout}`);

    const same = run(shipped);
    assert.equal(same.status, 0, `the shipped manifest compares clean against itself: ${same.stdout}${same.stderr}`);
    assert.match(same.stdout, /declares the same 11 item\(s\)/, same.stdout);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

// --- The trap covers an interrupt, not only a clean exit ----------------------------------------

test('SIGTERM mid-run still removes both containers by name, via the same trap as EXIT', async () => {
  // The trap covers INT and TERM as well as EXIT specifically because an uncaught interrupt would
  // otherwise leave two IRIS containers running under names a later run removes without asking
  // (Review Triage Log, blind-hunter). That fix was never demonstrated red/green; this drives the
  // script from a minimal fixture root -- the same idiom as the unbuilt-bundle refusal test below,
  // with a stub `ipm-manifest.mjs` that exits 0 and a tiny bundle so staging is real but small and
  // fast under load -- with a stubbed docker that never reports the build container ready, so the
  // script is still inside wait_for_session's readiness loop, with one real docker run behind it,
  // when the signal arrives.
  const dir = mkdtempSync(join(tmpdir(), 'ocupilot-ipm-sigterm-'));
  try {
    mkdirSync(join(dir, 'scripts'), { recursive: true });
    mkdirSync(join(dir, 'ui', 'tools'), { recursive: true });
    mkdirSync(join(dir, 'src', 'OcuPilot'), { recursive: true });
    mkdirSync(join(dir, 'ui', 'dist', 'ocupilot-ui', 'browser'), { recursive: true });
    writeFileSync(join(dir, 'scripts', 'ci-ipm-archive.sh'), source);
    writeFileSync(join(dir, 'ui', 'tools', 'ipm-manifest.mjs'), '// a manifest that has not drifted\n');
    writeFileSync(join(dir, 'module.xml'), '<Export><Document/></Export>\n');
    writeFileSync(join(dir, 'src', 'OcuPilot', 'Placeholder.cls'), '');
    writeFileSync(join(dir, 'ui', 'dist', 'ocupilot-ui', 'browser', 'index.html'), '<html></html>\n');

    const bin = join(dir, 'bin');
    const capture = join(dir, 'docker-argv.txt');
    writeFileSync(capture, '');
    writeStub(bin, 'docker', [
      'printf \'%s\\n\' "$*" >> "$OCUPILOT_DOCKER_CAPTURE"',
      'case "$1" in',
      '  exec) exit 1 ;;', // never ready, so wait_for_session is still looping when TERM arrives
      '  *) exit 0 ;;',
      'esac',
    ]);
    const scratch = join(dir, 'scratch');
    const child = spawn(
      'sh',
      [join(dir, 'scripts', 'ci-ipm-archive.sh'), '--image', PINNED_IMAGE, '--dir', scratch],
      { cwd: dir, env: stubEnv(bin, { OCUPILOT_DOCKER_CAPTURE: capture }) }
    );

    const deadline = Date.now() + 15000;
    while (Date.now() < deadline && !captured(capture).some((line) => line.startsWith('run '))) {
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
    assert.ok(
      captured(capture).some((line) => line.startsWith('run ')),
      `docker run was never issued before the deadline: ${captured(capture).join('\n')}`
    );

    const exited = new Promise((resolve) => child.on('exit', (exitCode) => resolve(exitCode)));
    child.kill('SIGTERM');
    const exitCode = await Promise.race([
      exited,
      new Promise((_, reject) => setTimeout(() => reject(new Error('the script did not exit within 10s of SIGTERM')), 10000)),
    ]);
    assert.equal(exitCode, 130, 'the TERM trap exits 130');

    const lines = captured(capture);
    // More than once: the script removes a stale build container by name before `docker run`, so a
    // single occurrence is that pre-run removal and says nothing about whether the trap fired.
    // The floor rather than a count, because the TERM trap's own `exit` re-enters the EXIT trap.
    assert.ok(
      lines.filter((line) => line === 'rm -f ocupilot-ipm-build').length >= 2,
      `the build container was removed fewer than twice, so the trap did not add its own removal to the pre-run one: ${lines.join('\n')}`
    );
    assert.ok(
      lines.includes('rm -f ocupilot-ipm-install'),
      `cleanup did not remove the install container, though it was never started -- the trap removes both by name regardless: ${lines.join('\n')}`
    );
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

// --- _SYSTEM is unexpired by name, in the right place -------------------------------------------

test('_SYSTEM is unexpired by name, in %SYS, strictly after the archive install and before smoke.sh', () => {
  assert.match(
    code,
    /UnExpireUserPasswords\("_SYSTEM"\)/,
    'the call must name _SYSTEM literally, the same discipline the container start hook follows'
  );
  assert.doesNotMatch(code, /UnExpireUserPasswords\("\*"\)/, 'the all-users form must never appear');

  assert.match(
    code,
    /docker exec -i "\$INSTALL_NAME" iris session iris -U %SYS[\s\S]*?UnExpireUserPasswords/,
    'UnExpireUserPasswords must run inside a session opened with -U %SYS, not HSCUSTOM'
  );

  const installAt = code.indexOf('Shell("load /opt/ocupilot-archive/');
  const unexpireAt = code.indexOf('UnExpireUserPasswords');
  const smokeAt = code.indexOf('smoke.sh');
  assert.ok(installAt > 0 && unexpireAt > 0 && smokeAt > 0, 'all three steps must be present in the script');
  assert.ok(
    unexpireAt > installAt,
    'the account is unexpired strictly after the archive is installed, never before -- AD-17 requires the IPM install itself to leave it alone'
  );
  assert.ok(smokeAt > unexpireAt, 'and strictly before smoke.sh runs, or every HTTP check would read 401');
});

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import {
  classifyRun,
  nonConsecutiveRuns,
  overlappingRuns,
  parseListMarker,
  parseRunMarker,
  testClassesOnDisk,
} from './ci-runner.mjs';

/**
 * The CI workflow, asserted as text (Story 1.17).
 *
 * **Why text.** There is no YAML parser in this toolchain and this story adds none;
 * `compose.test.mjs` established the precedent for asserting a YAML gate this way, and its own
 * review found the limit -- four hook mutations passed its text pins. So the assertions here are
 * over structure-bearing strings and over ABSENCES (`continue-on-error`, `|| true`, `secrets.`,
 * a publish action), which a text pin catches reliably, plus one equality that a text pin
 * catches in both directions: every gate this file declares appears as a `run:` command in the
 * workflow, and every gate-shaped `run:` in the workflow is declared here.
 *
 * **What it cannot do, stated plainly.** No GitHub Actions run exists: this story may not push,
 * so the workflow's first real run is the owner's. The falsifiability substitute is three
 * things, none of which needs a push -- the equality below, every gate command having been run
 * locally and recorded in the story's `## Verification`, and each gate reporting non-zero counts
 * so a run over an empty population is itself a failure.
 *
 * Mutations (Rule 19): delete any `run:` line from `.github/workflows/ci.yml` -> the
 * declared-gate equality goes red naming it. Add a step that runs something this file does not
 * declare -> the same equality goes red from the other side. Add `continue-on-error: true` to
 * any step, append `|| true` to any command, or reference `secrets.` anywhere -> the matching
 * absence assertion goes red.
 */

const here = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(here, '..', '..');
const WORKFLOW_PATH = join(REPO_ROOT, '.github', 'workflows', 'ci.yml');
const workflowSource = readFileSync(WORKFLOW_PATH, 'utf8');

/**
 * The workflow with its comments removed.
 *
 * Every assertion below reads this rather than the raw file, and the reason is the header
 * comment in `ci.yml` itself: it explains what the workflow must not carry, naming
 * `continue-on-error`, `secrets.` and `npm publish` in prose. An absence check over the raw text
 * matches its own explanation and fails on a file that is correct -- and the fix cannot be to
 * delete the explanation, which is the only place a reader learns why those absences matter.
 *
 * A `#` never appears inside a value in this file (no URL, no expression and no command carries
 * one), so a line-oriented strip is exact here rather than approximate. The same simplification
 * `client-lint.mjs` makes for its own comment blanking, for the same reason.
 */
export function withoutComments(text) {
  return text
    .split('\n')
    .map((line) => {
      const at = line.indexOf('#');
      return at === -1 ? line : line.slice(0, at).trimEnd();
    })
    .join('\n');
}

const workflow = withoutComments(workflowSource);

/**
 * Every gate CI runs, declared here and nowhere else.
 *
 * This list and the workflow's `run:` commands are held equal in both directions. A floor --
 * "the workflow runs at least these" -- would let a step be added that nothing here describes,
 * which is how a publish step would arrive.
 */
export const DECLARED_GATES = [
  // gates
  'npm ci',
  'npm run build',
  'npm test',
  'uv run scripts/check-objectscript.py',
  'uv run scripts/test_check_objectscript.py',
  'bash scripts/lint-docs.sh',
  // instance -- `npm ci` and `npm run build` run again here, in a job with its own checkout,
  // and are listed again: one entry per occurrence, so deleting either one is red.
  'npm ci',
  'npm run build',
  'npx puppeteer browsers install chrome',
  'bash scripts/ci-throwaway.sh up',
  'bash scripts/wait-readiness.sh --url http://localhost:52776/api/ocupilot/readiness/',
  'node tools/ci-runner.mjs --container ocupilot-ci',
  'bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS',
  'npm run test:browser',
  'bash scripts/ci-throwaway.sh down',
  // images
  'bash scripts/ci-image-compile.sh --image ${{ matrix.image }}',
];

/**
 * Every `run:` command in the workflow, in order, with duplicates KEPT.
 *
 * De-duplicating would quietly weaken the equality this file's whole claim rests on: `npm ci`
 * and `npm run build` each appear in two jobs, so against a de-duplicated set, deleting one of
 * the two occurrences left both directions green and "a gate deleted from either side is red"
 * was false for exactly those commands. The declared list below therefore carries a command
 * once per occurrence.
 */
export function runCommands(text) {
  return [...text.matchAll(/^\s*run:\s*(.+?)\s*$/gm)].map((match) => match[1]);
}

/**
 * Every `uses:` action in the workflow.
 *
 * The `run:` equality alone leaves a hole the stated rationale names: "a step nothing describes
 * is how a publish step arrives" -- and a release action arrives as `uses:`, not as `run:`,
 * so the seven publish patterns below would be the only thing standing in its way. These are
 * held to a closed allowlist for the same reason the commands are.
 */
export function usesActions(text) {
  return [...text.matchAll(/^\s*(?:-\s*)?uses:\s*(\S+)\s*$/gm)].map((match) => match[1]);
}

/** The actions the workflow may use. A closed list, edited deliberately. */
export const DECLARED_USES = [
  'actions/checkout@v4',
  'actions/setup-node@v4',
  'astral-sh/setup-uv@v5',
];

/** The `jobs:` keys the workflow declares. */
export function jobNames(text) {
  const jobsAt = text.indexOf('\njobs:');
  if (jobsAt === -1) return [];
  return [...text.slice(jobsAt).matchAll(/^ {2}([a-z][a-z0-9-]*):$/gm)].map((match) => match[1]);
}

// --- The equality, in both directions -------------------------------------------------------

test('the declared gates and the workflow run: commands are the same multiset', () => {
  // Sorted and compared whole, occurrence for occurrence. `includes()` in either direction
  // would miss a DUPLICATED command losing one of its occurrences, which is exactly the hole a
  // de-duplicated set left: `npm ci` and `npm run build` each run in two jobs.
  const commands = runCommands(workflow);
  assert.deepEqual(
    [...commands].sort(),
    [...DECLARED_GATES].sort(),
    `the workflow's run: commands and this file's declared gates have diverged.\nworkflow: ${JSON.stringify(commands, null, 2)}\ndeclared: ${JSON.stringify(DECLARED_GATES, null, 2)}`
  );
});

test('every declared gate appears as a run: command in the workflow', () => {
  const commands = runCommands(workflow);
  for (const gate of DECLARED_GATES) {
    assert.ok(
      commands.includes(gate),
      `the workflow no longer runs the declared gate ${JSON.stringify(gate)}; it runs: ${JSON.stringify(commands, null, 2)}`
    );
  }
});

test('every run: command in the workflow is a declared gate', () => {
  const commands = runCommands(workflow);
  for (const command of commands) {
    assert.ok(
      DECLARED_GATES.includes(command),
      `the workflow runs ${JSON.stringify(command)}, which this file does not declare -- a step nothing describes is how a publish step arrives`
    );
  }
  assert.equal(
    commands.length,
    DECLARED_GATES.length,
    'the two lists are the same size, so neither can carry an entry the other does not'
  );
});

test('every uses: action in the workflow is on the closed allowlist', () => {
  // A release or publish action arrives as `uses:`, never as `run:`, so the run-command
  // equality above would not see it and only the named publish patterns would stand in its way.
  const actions = usesActions(workflow);
  assert.ok(actions.length >= 3, `the workflow uses actions: ${JSON.stringify(actions)}`);
  for (const action of actions) {
    assert.ok(
      DECLARED_USES.includes(action),
      `the workflow uses ${JSON.stringify(action)}, which this file does not declare -- an action nothing describes is the other way a publish step arrives`
    );
  }
});

test('every file a gate command names actually exists', () => {
  // A gate that runs a script nobody wrote fails the job on its first real run, at a moment
  // nobody chose. The paths are the ones that look like paths, resolved from the repository root
  // for a `scripts/` one and from `ui/` for the rest, which is where their steps run.
  const pattern = /(?:scripts|tools|browser)\/[A-Za-z0-9._-]+/g;
  let checked = 0;
  for (const gate of DECLARED_GATES) {
    for (const match of gate.matchAll(pattern)) {
      const relative = match[0];
      const candidates = [join(REPO_ROOT, relative), join(REPO_ROOT, 'ui', relative)];
      assert.ok(
        candidates.some((path) => existsSync(path)),
        `the gate ${JSON.stringify(gate)} names ${relative}, which exists at neither ${candidates.join(' nor ')}`
      );
      checked += 1;
    }
  }
  assert.ok(checked >= 6, `the check looked at ${checked} path(s); a run over none would pass having checked nothing`);
});

// --- The absences ---------------------------------------------------------------------------

test('nothing in the workflow publishes, releases or pushes to a registry (stealth policy)', () => {
  for (const [what, pattern] of [
    ['a secret reference', /secrets\./],
    ['npm publish', /npm\s+publish/],
    ['a container push', /docker\s+push/],
    ['a registry login', /docker\/login-action|registry-url/],
    ['a GitHub release', /softprops\/action-gh-release|actions\/create-release|gh\s+release/],
    ['an Open Exchange step', /open\s*exchange|openexchange/i],
    ['a package publish action', /JS-DevTools\/npm-publish|pypa\/gh-action-pypi-publish/],
  ]) {
    assert.doesNotMatch(
      workflow,
      pattern,
      `the workflow carries ${what}; nothing in CI publishes before the owner's release (stealth policy)`
    );
  }
});

test('no step can fail without failing the job', () => {
  assert.doesNotMatch(workflow, /continue-on-error/, 'a step that continues on error is a report, not a gate');
  assert.doesNotMatch(workflow, /\|\|\s*true/, 'a command whose failure is swallowed gates nothing');
  assert.doesNotMatch(workflow, /set \+e/, 'a shell that ignores failures gates nothing');
  // `if: always()` is legitimate on exactly one step -- the teardown, which must run whatever
  // happened before it -- and is a defect anywhere else, because a gate that runs regardless is
  // a gate whose own failure does not stop the ones after it.
  const always = [...workflow.matchAll(/^\s*if:\s*always\(\)\s*$/gm)];
  assert.equal(always.length, 1, `expected exactly one always() step (the teardown), found ${always.length}`);
  const teardownAt = workflow.indexOf('tear the throwaway down');
  assert.ok(teardownAt > 0, 'the teardown step is named');
  assert.ok(always[0].index > teardownAt, 'and always() belongs to it');
});

// --- The triggers, the permissions and the shape ---------------------------------------------

test('the workflow runs on push, on pull request and on demand, with read-only permissions', () => {
  assert.match(workflow, /^on:$/m, 'the workflow declares its triggers');
  assert.match(workflow, /^ {2}push:$/m, 'on push');
  assert.match(workflow, /^ {2}pull_request:$/m, 'on pull request');
  assert.match(workflow, /^ {2}workflow_dispatch:$/m, 'and on demand');
  assert.match(workflow, /^permissions:\n {2}contents: read$/m, 'with read-only permissions and nothing else');
  assert.doesNotMatch(workflow, /permissions:\n(?: {2}\w+: (?:write|write-all)\n)/, 'no write permission is granted');
});

test('a superseded run is cancelled rather than queued behind the one that replaced it', () => {
  assert.match(workflow, /^concurrency:$/m);
  assert.match(workflow, /cancel-in-progress: true/, 'a superseded run is cancelled');
  assert.match(workflow, /group: ci-/, 'grouped per workflow and ref');
});

test('the three jobs are declared, and the instance job waits on readiness before any suite', () => {
  assert.deepEqual(jobNames(workflow), ['gates', 'instance', 'images']);

  const waitAt = workflow.indexOf('scripts/wait-readiness.sh');
  const runnerAt = workflow.indexOf('tools/ci-runner.mjs');
  const smokeAt = workflow.indexOf('scripts/smoke.sh');
  const browserAt = workflow.indexOf('npm run test:browser');
  assert.ok(waitAt > 0, 'the instance job waits for readiness');
  assert.ok(runnerAt > waitAt, 'before the ObjectScript suite');
  assert.ok(smokeAt > waitAt, 'before the smoke script');
  assert.ok(browserAt > waitAt, 'and before the browser spec');

  const upAt = workflow.indexOf('ci-throwaway.sh up');
  assert.ok(upAt > 0 && upAt < waitAt, 'the throwaway comes up first');
});

test('the images job covers both stock Community editions at the pinned version (NFR-13)', () => {
  assert.match(workflow, /intersystems\/irishealth-community:2026\.2/, 'IRIS for Health Community');
  assert.match(workflow, /intersystems\/iris-community:2026\.2/, 'and plain IRIS Community');
  assert.ok(!workflow.includes('latest-cd'), 'and neither is a floating tag (AD-27)');
  assert.match(workflow, /fail-fast: false/, 'so one edition failing still reports the other');
});

test('the node version CI pins satisfies the engines range the workspace declares', () => {
  const packageJson = JSON.parse(readFileSync(join(here, '..', 'package.json'), 'utf8'));
  const declared = packageJson.engines.node;
  const pinned = /node-version:\s*(\S+)/.exec(workflow);
  assert.ok(pinned, 'the workflow pins a node version');
  const [major, minor, patch] = pinned[1].split('.').map(Number);
  assert.ok(
    declared.includes(`^${major}.`),
    `CI pins Node ${pinned[1]} and the workspace declares ${declared}; a pin outside the range fails at npm ci with engine-strict`
  );
  const floor = new RegExp(`\\^${major}\\.(\\d+)\\.(\\d+)`).exec(declared);
  assert.ok(floor, `the engines range names a ^${major} band`);
  assert.ok(
    minor > Number(floor[1]) || (minor === Number(floor[1]) && patch >= Number(floor[2])),
    `CI pins Node ${pinned[1]}, below the ${declared} floor`
  );
});

// --- The serialized runner (DW-54) -----------------------------------------------------------
//
// The runner's own wiring is above (the workflow calls it, once, in the instance job); these are
// its decisions, driven directly over shapes a real run cannot be made to produce on purpose.
//
// Mutations (Rule 19): make `overlappingRuns` compare each run only against the one before it ->
// the three-way case goes red. Make `classifyRun` treat a missing marker, an unlanded run or a
// zero-method run as a pass -> the matching case goes red, and CI would then report green for a
// suite it learned nothing about.

test('DW-54: two runs that overlap in wall-clock time are reported', () => {
  const overlaps = overlappingRuns([
    { name: 'A', startedAt: 0, finishedAt: 100 },
    { name: 'B', startedAt: 50, finishedAt: 150 },
  ]);
  assert.deepEqual(overlaps, ['A and B']);
});

test('DW-54: runs that merely touch are serial, not overlapping', () => {
  const overlaps = overlappingRuns([
    { name: 'A', startedAt: 0, finishedAt: 100 },
    { name: 'B', startedAt: 100, finishedAt: 200 },
    { name: 'C', startedAt: 200, finishedAt: 300 },
  ]);
  assert.deepEqual(overlaps, [], 'one class finishing as the next starts is the serialization working');
});

test('DW-54: every overlapping pair is reported, not only the neighbouring one', () => {
  // The 2026-09-11 incident started eighteen at once. A comparison against the previous run
  // alone would have named one pair of the many.
  const overlaps = overlappingRuns([
    { name: 'A', startedAt: 0, finishedAt: 300 },
    { name: 'B', startedAt: 10, finishedAt: 310 },
    { name: 'C', startedAt: 20, finishedAt: 320 },
  ]);
  assert.deepEqual(overlaps.sort(), ['A and B', 'A and C', 'B and C']);
});

test('DW-54: a run that reported nothing, was refused, did not land, or asserted nothing is a failure', () => {
  const ok = { runIndex: 7, total: 3, failed: 0, landed: true, runOk: true };
  assert.equal(classifyRun('X', null).outcome, 'no-marker');
  assert.match(classifyRun('X', null).problem, /never a pass/);

  assert.equal(classifyRun('X', { ...ok, runOk: false }).outcome, 'refused');
  assert.match(classifyRun('X', { ...ok, runOk: false }).problem, /never a pass/);

  assert.equal(classifyRun('X', { ...ok, landed: false }).outcome, 'not-landed');
  assert.match(classifyRun('X', { ...ok, landed: false }).problem, /belongs to an earlier class/);

  assert.equal(classifyRun('X', { ...ok, total: 0 }).outcome, 'empty');
  assert.match(classifyRun('X', { ...ok, total: 0 }).problem, /never a pass/);

  assert.equal(classifyRun('X', { ...ok, failed: 1 }).outcome, 'failed');
  assert.equal(classifyRun('X', ok).outcome, 'passed');
  assert.equal(classifyRun('X', ok).problem, null);
});

test('DW-54: a run index allocated by another process is reported', () => {
  // The check that can actually fail while the runner's loop is synchronous. Mutation (Rule 19):
  // delete the nonConsecutiveRuns call from ci-runner's main() -> a concurrent writer against
  // the shared instance goes unreported and every result in the job is quietly suspect.
  assert.deepEqual(
    nonConsecutiveRuns([
      { name: 'A', runIndex: 10 },
      { name: 'B', runIndex: 11 },
      { name: 'C', runIndex: 12 },
    ]),
    [],
    'consecutive indices are one job running alone'
  );
  const gaps = nonConsecutiveRuns([
    { name: 'A', runIndex: 10 },
    { name: 'B', runIndex: 14 },
  ]);
  assert.equal(gaps.length, 1);
  assert.match(gaps[0], /run 10.*run 14/, 'and the gap names both sides');
  assert.deepEqual(
    nonConsecutiveRuns([{ name: 'A', runIndex: null }, { name: 'B', runIndex: 3 }]),
    [],
    'a class that reported no index is handled by classifyRun, not counted as a foreign run here'
  );
});

test('the runner reads the counts, the landed flag and the run status out of the session marker', () => {
  const parsed = parseRunMarker('noise\nOCUPILOT-RUN-START:1042:19:2:1:1:OCUPILOT-RUN-END\nmore noise');
  assert.deepEqual(parsed, { runIndex: 1042, total: 19, failed: 2, landed: true, runOk: true });
  assert.equal(
    parseRunMarker('OCUPILOT-RUN-START:1042:19:2:1:0:OCUPILOT-RUN-END').runOk,
    false,
    'a refused run is carried in the marker rather than inferred from the counts'
  );
  assert.equal(parseRunMarker('nothing here'), null, 'a session that reported nothing parses as nothing, not as a pass');
  assert.equal(
    parseRunMarker('OCUPILOT-RUN-START:1042:19:2:1:OCUPILOT-RUN-END'),
    null,
    'the old five-field marker is not silently accepted as a pass with an undefined status'
  );
});

test('the runner knows how many test classes the checkout carries, so a narrowed discovery is red', () => {
  // "More than zero" was the only floor on discovery. Mutation (Rule 19): narrow
  // ci-unit-test.sh's listing query (its old `c.Super [ 'TestCase'` missed any class reaching
  // TestCase through a project base) -> the instance offers fewer classes than the checkout
  // carries and the job goes red naming them, instead of passing over a subset.
  const onDisk = testClassesOnDisk(REPO_ROOT);
  assert.ok(onDisk.length > 20, `the checkout carries ${onDisk.length} test classes`);
  assert.ok(onDisk.includes('OcuPilot.Test.Wire'), 'including a class that declares Test* methods');
  assert.ok(
    !onDisk.includes('OcuPilot.Test.Http'),
    'and excluding the over-the-wire helper, which extends TestCase but declares no test method'
  );
  assert.ok(
    !onDisk.includes('OcuPilot.Test.InstallerProbe'),
    'and excluding the installer probe, which is a fixture rather than a suite'
  );
});

test('the runner reads the class list out of its own marker, and an empty list stays empty', () => {
  assert.deepEqual(parseListMarker('OCUPILOT-LIST-START:A.B,A.C:OCUPILOT-LIST-END'), ['A.B', 'A.C']);
  assert.deepEqual(parseListMarker('OCUPILOT-LIST-START::OCUPILOT-LIST-END'), []);
  assert.equal(parseListMarker('no marker'), null, 'no marker is not an empty list');
});

test('the session primitive the runner drives exists and refuses a name it cannot trust', () => {
  const script = readFileSync(join(REPO_ROOT, 'scripts', 'ci-unit-test.sh'), 'utf8');
  assert.match(script, /--norecursive|\/norecursive/, 'the run is not recursive, or the manager walks nothing and prints All PASSED');
  assert.match(script, /is not a class name/, 'a class name that is not one is refused rather than interpolated');
  assert.match(script, /RunTest\(":\$CLASSNAME"/, 'the suite half of the test spec is empty, so no directory has to exist for it');
});

// --- The shell scripts CI's red and green actually depend on ---------------------------------
//
// `ci.test.mjs` held that these files EXIST and are invoked. What each one does with a failure
// -- which is the whole of CI's verdict -- was pinned nowhere, in the shape `ci-unit-test.sh`
// already had above. A script whose failure branch is inverted or deleted produces a green run
// over a broken instance, and no assertion in this repository would notice.

test('wait-readiness.sh fails fast on a failed install and exits 0 only on installed', () => {
  // Mutations (Rule 19): delete the `"state":"failed"` branch -> CI waits out its whole budget
  // and reports a timeout instead of the failure; change that branch's `exit 1` to `exit 0`, or
  // widen the installed case -> CI reports a green wait over an uninstalled instance and runs
  // every suite against it.
  const script = readFileSync(join(REPO_ROOT, 'scripts', 'wait-readiness.sh'), 'utf8');
  const code = script
    .split('\n')
    .filter((line) => !/^\s*#/.test(line))
    .join('\n');

  assert.match(code, /\*'"state":"installed"'\*\)/, 'exit 0 is reached only through the installed state');
  const installedArm = code.slice(code.indexOf('*\'"state":"installed"\'*)'));
  assert.match(installedArm.slice(0, installedArm.indexOf(';;')), /exit 0/, 'and that arm is the one that exits 0');

  for (const state of ['failed', 'upgraderequired']) {
    const at = code.indexOf(`*'"state":"${state}"'*)`);
    assert.ok(at > 0, `wait-readiness.sh branches on the ${state} state rather than waiting it out`);
    const arm = code.slice(at, code.indexOf(';;', at));
    assert.match(arm, /exit 1/, `and fails the job on ${state}`);
  }

  const exitZeros = [...code.matchAll(/^\s*exit 0\s*$/gm)];
  assert.equal(exitZeros.length, 1, `exactly one exit 0, the installed one; found ${exitZeros.length}`);
});

test('smoke.sh maps a FAIL verdict and a missing verdict to a non-zero exit', () => {
  // Mutation (Rule 19): make the no-marker arm exit 0 -> a smoke run that never completed reads
  // as a pass, which is the vacuous gate this story exists to remove.
  const script = readFileSync(join(REPO_ROOT, 'scripts', 'smoke.sh'), 'utf8');
  const verdict = script.slice(script.indexOf('case "$VERDICT" in'));
  const body = verdict.slice(0, verdict.indexOf('\nesac'));
  assert.match(body, /PASS\)\s*\n\s*exit 0/, 'PASS is the only exit 0');
  assert.match(body, /FAIL\)[\s\S]*?exit 1/, 'FAIL exits non-zero');
  assert.match(body, /\*\)[\s\S]*?no verdict marker[\s\S]*?exit 1/, 'and a run that reported no verdict at all exits non-zero too');
  assert.equal((body.match(/exit 0/g) ?? []).length, 1, 'exactly one exit 0 in the verdict mapping');
});

test('the throwaway and the image probe refuse to touch the live container', () => {
  // The highest-consequence lines in either script: the ones that keep CI off the owner's
  // instance. Mutation (Rule 19): delete any refusal below -> this goes red.
  const throwaway = readFileSync(join(REPO_ROOT, 'scripts', 'ci-throwaway.sh'), 'utf8');
  assert.match(throwaway, /"\$WEB_PORT" = "52774"/, 'the throwaway refuses the live web port');
  assert.match(throwaway, /"\$SUPER_PORT" = "1973"/, 'and the live SuperServer port');
  assert.match(throwaway, /"\$PROJECT" = "ocupilot"/, 'and the live project name');
  assert.ok(
    !/docker compose\s+(-f\s+)?(?!.*\$COMPOSE_FILE)/.test(throwaway.replace(/^\s*#.*$/gm, '')),
    'every docker compose invocation names the generated compose file'
  );
  for (const invocation of throwaway.replace(/^\s*#.*$/gm, '').match(/docker compose[^\n]*/g) ?? []) {
    assert.match(invocation, /-f "\$COMPOSE_FILE"/, `"${invocation.trim()}" must name the generated file, never this repository's compose file`);
  }

  const image = readFileSync(join(REPO_ROOT, 'scripts', 'ci-image-compile.sh'), 'utf8');
  assert.match(image, /"\$NAME" = "ocupilot"/, 'the image probe refuses the live container name');
  assert.match(image, /latest-cd/, 'and a floating tag (AD-27)');
  assert.ok(
    !/-p\s|--publish|ports:/.test(image.replace(/^\s*#.*$/gm, '')),
    'and publishes no port at all, so nothing can mistake it for an instance'
  );
});

test('the throwaway start path is the one docker-compose.yml ships', () => {
  // ci-throwaway.sh's own header says "`ui/tools/compose.test.mjs` pins what they are" -- and it
  // pins what docker-compose.yml says, not what the throwaway writes. Nothing compared the two,
  // so CI's only real-instance job could validate a start path the repository no longer ships.
  //
  // Mutation (Rule 19): change the healthcheck interval, the restart policy or the command in
  // either file alone -> this goes red naming the key.
  const throwaway = readFileSync(join(REPO_ROOT, 'scripts', 'ci-throwaway.sh'), 'utf8');
  const compose = readFileSync(join(REPO_ROOT, 'docker-compose.yml'), 'utf8');
  for (const [key, pattern] of [
    ['restart policy', /restart:\s*(\S+)/],
    ['start hook command', /command:\s*(\[.*\])/],
    ['healthcheck test', /test:\s*(\[.*\])/],
    ['healthcheck interval', /interval:\s*(\S+)/],
    ['healthcheck retries', /retries:\s*(\S+)/],
  ]) {
    const fromCompose = pattern.exec(compose);
    const fromThrowaway = pattern.exec(throwaway);
    assert.ok(fromCompose, `docker-compose.yml declares a ${key}`);
    assert.ok(fromThrowaway, `the throwaway declares a ${key}`);
    assert.equal(
      fromThrowaway[1],
      fromCompose[1],
      `the throwaway's ${key} has drifted from docker-compose.yml's`
    );
  }
});

test('the throwaway mounts the committed manifest, so the XML parse runs rather than skipping', () => {
  // OcuPilot.Test.Manifest reads /opt/ocupilot/module.xml and skips when nothing mounted one.
  // Neither this repository's compose file nor the first version of ci-throwaway.sh mounted it,
  // so that assertion skipped on every instance there is -- a test that cannot fail, which is
  // the vacuous pass this whole story exists to remove. It is pinned here rather than left to
  // the class, because the class cannot tell a skip from an absence of anything to read.
  //
  // Mutation (Rule 19): drop the module.xml line from ci-throwaway.sh's volumes -> this goes
  // red, and OcuPilot.Test.Manifest silently returns to skipping its only document-level check.
  const throwaway = readFileSync(join(REPO_ROOT, 'scripts', 'ci-throwaway.sh'), 'utf8');
  assert.match(
    throwaway,
    /\$DIR\/module\.xml:\/opt\/ocupilot\/module\.xml:ro/,
    'the throwaway mounts the committed manifest where OcuPilot.Test.Manifest reads it'
  );
  assert.match(
    throwaway,
    /cp "\$REPO_ROOT\/module\.xml" "\$DIR\/module\.xml"/,
    'and copies it into the scratch directory first, like every other file it mounts'
  );

  const manifestTest = readFileSync(join(REPO_ROOT, 'src', 'OcuPilot', 'Test', 'Manifest.cls'), 'utf8');
  assert.match(
    manifestTest,
    /\/opt\/ocupilot\/module\.xml/,
    'and the class still reads that path, so the mount is the path it needs'
  );
});

test('discovery lists classes the framework would run, not every TestCase subclass', () => {
  // `OcuPilot.Test.Http` is the suite's over-the-wire CLIENT: it extends `%UnitTest.TestCase` for
  // its assertion macros and declares no test method at all. Listed, it runs nothing, and the
  // runner's own "a class that asserted nothing is a failure" rule -- the rule that matters --
  // then fails the whole job over a helper. Observed on a throwaway before the EXISTS clause.
  //
  // Mutation (Rule 19): drop the EXISTS clause from `scripts/ci-unit-test.sh`'s listing query ->
  // the helper is discovered again and the instance job goes red over a class with nothing in it.
  const script = readFileSync(join(REPO_ROOT, 'scripts', 'ci-unit-test.sh'), 'utf8');
  assert.match(
    script,
    /EXISTS \(SELECT 1 FROM %Dictionary\.CompiledMethod m WHERE m\.parent = c\.Name AND m\.Name %STARTSWITH 'Test'\)/,
    'the listing requires at least one Test* method, so a helper is never discovered'
  );
  assert.match(script, /c\.Abstract = 0/, 'and an abstract base is never discovered either');

  // The helper the clause exists for is still on disk, and still a TestCase subclass: if it ever
  // stops being either, this rule is about nothing and should be revisited rather than kept.
  const helper = readFileSync(join(REPO_ROOT, 'src', 'OcuPilot', 'Test', 'Http.cls'), 'utf8');
  assert.match(helper, /Extends %UnitTest\.TestCase/, 'OcuPilot.Test.Http is still the shape this rule is for');
  assert.doesNotMatch(helper, /^(?:Class)?Method Test/m, 'and still declares no test method');
});

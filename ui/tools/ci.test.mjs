import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import {
  chmodSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  rmSync,
  statSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { basename, dirname, join } from 'node:path';

import {
  classifyFailureDetail,
  classifyLeftovers,
  classifyRun,
  describeFailures,
  leftoverIsOwn,
  nonConsecutiveRuns,
  overlappingRuns,
  parseFailuresMarker,
  parseListMarker,
  parseProbeAppsMarker,
  parseRunMarker,
  testClassesOnDisk,
} from './ci-runner.mjs';
import { NODE_RANGE_LABEL } from './version-guard.mjs';
import { declaredShell, stubEnv, writeStub } from './stub-bin.mjs';

/**
 * The CI workflow, asserted as text (Story 1.17).
 *
 * **Except the two that execute `scripts/smoke.sh`.** A text pin could not see the credential
 * guard's defect -- `*"$(printf '\n')"*` reads as a newline test and is `*""*` -- so those two
 * spawn the script under every available shell with a stub `iris` on `PATH`. Everything else
 * below is text.
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
  'sh scripts/ci-durable-ownership.sh --image intersystems/irishealth-community:2026.2',
  'npm ci',
  'npm run build',
  'npx puppeteer browsers install chrome',
  'sh scripts/ci-throwaway.sh up',
  'sh scripts/wait-readiness.sh --url http://localhost:52776/api/ocupilot/readiness/',
  'node tools/ci-runner.mjs --container ocupilot-ci',
  'sh scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS',
  'npm run test:browser',
  'sh scripts/ci-throwaway.sh logs',
  'sh scripts/ci-throwaway.sh down',
  // images
  'sh scripts/ci-image-compile.sh --image ${{ matrix.image }}',
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

/**
 * The actions the workflow may use, each pinned to the full commit SHA its tag resolved to when it
 * was pinned (`gh api repos/<owner>/<repo>/commits/<tag> --jq .sha`, 2026-09-13; DW-218). A closed
 * list, edited deliberately: moving a pin is a new lookup and a reviewed change here. Each is the
 * lowest major whose `action.yml` declares `using: node24` (DW-238): checkout v5 (= v5.1.0),
 * setup-node v5 (= v5.0.0), setup-uv v7 (= v7.6.0).
 */
export const PINNED_ACTIONS = [
  { action: 'actions/checkout', sha: 'fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09', tag: 'v5' },
  { action: 'actions/setup-node', sha: 'a0853c24544627f65ddf259abe73b1d18a591444', tag: 'v5' },
  { action: 'astral-sh/setup-uv', sha: '37802adc94f370d6bfd71619e3f0bf239e1f3b78', tag: 'v7' },
];

export const DECLARED_USES = PINNED_ACTIONS.map(({ action, sha }) => `${action}@${sha}`);

/** The runner image every job runs on (DW-218). */
export const RUNNER_IMAGE = 'ubuntu-24.04';

/** The uv release `setup-uv` installs, and the Python `.python-version` pins (DW-215). */
export const UV_VERSION = '0.12.9';
export const PYTHON_VERSION = '3.12.14';

/** The markdownlint-cli2 release both markdown call sites run (DW-215). */
export const MARKDOWNLINT_VERSION = '0.23.2';

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

// --- The pins (DW-215, DW-218) ----------------------------------------------------------------

// Mutation (Rule 19): write any `uses:` back as `@v4` -> this goes red naming the action.
test('every uses: action is pinned to a full commit SHA, with its tag in a trailing comment', () => {
  const lines = [...workflowSource.matchAll(/^\s*(?:-\s*)?uses:\s*(\S+?)(?:\s+#\s*(\S+))?\s*$/gm)];
  assert.ok(lines.length >= 3, `the workflow uses ${lines.length} action(s)`);
  for (const [, ref, tag] of lines) {
    const [action, pinned] = ref.split('@');
    assert.match(pinned ?? '', /^[0-9a-f]{40}$/, `${ref} floats: every action is pinned to a full commit SHA`);
    const declared = PINNED_ACTIONS.find((entry) => entry.action === action);
    assert.ok(declared, `${action} is not a declared action`);
    assert.equal(pinned, declared.sha, `${action} is pinned to ${pinned}, not the reviewed ${declared.sha}`);
    assert.equal(tag, declared.tag, `${action}'s trailing comment names the tag its SHA was resolved from`);
  }
});

// Mutation (Rule 19): set any job back to `runs-on: ubuntu-latest` -> this goes red.
test('every job runs on the pinned runner image, never a floating label', () => {
  const runners = [...workflow.matchAll(/^\s*runs-on:\s*(\S+)\s*$/gm)].map((match) => match[1]);
  assert.equal(runners.length, jobNames(workflow).length, 'one runs-on per job');
  for (const runner of runners) {
    assert.equal(runner, RUNNER_IMAGE, `a job runs on ${runner}; every job runs on ${RUNNER_IMAGE}`);
  }
});

// Mutation (Rule 19): drop `version:` from the setup-uv step, or change `.python-version` -> red.
test('uv is pinned in CI and Python is pinned for every uv run', () => {
  const gates = jobSlice(workflow, 'gates');
  const step = /uses:\s*astral-sh\/setup-uv@\S+\s*\n\s*with:\s*\n\s*version:\s*"([^"]*)"/.exec(gates);
  assert.ok(step, 'the setup-uv step declares the uv version it installs');
  assert.equal(step[1], UV_VERSION, `setup-uv installs uv ${step[1]}, not ${UV_VERSION}`);
  const pythonVersion = readFileSync(join(REPO_ROOT, '.python-version'), 'utf8').trim();
  assert.equal(pythonVersion, PYTHON_VERSION, `.python-version pins ${pythonVersion}, not ${PYTHON_VERSION}`);
});

// Mutation (Rule 19): drop `@0.23.2` from either call site -> this goes red naming the file.
test('both markdownlint call sites run the same pinned markdownlint-cli2', () => {
  for (const file of ['scripts/lint-docs.sh', '.githooks/pre-commit']) {
    const code = withoutShellComments(readFileSync(join(REPO_ROOT, file), 'utf8'));
    const calls = [...code.matchAll(/npx\b[^\n]*?\bmarkdownlint-cli2(@\S+)?/g)];
    assert.ok(calls.length >= 1, `${file} runs markdownlint-cli2`);
    for (const [call, version] of calls) {
      assert.equal(version, `@${MARKDOWNLINT_VERSION}`, `${file} runs \`${call}\`, not markdownlint-cli2@${MARKDOWNLINT_VERSION}`);
    }
  }
});

// --- The shells (DW-229) ----------------------------------------------------------------------

// Mutation (Rule 19): run any `#!/bin/sh` script with `bash` in ci.yml -> this goes red naming it.
test('every script the workflow runs is invoked with the shell its shebang declares', () => {
  let checked = 0;
  for (const command of runCommands(workflow)) {
    const named = /(?:^|\s)(scripts\/[A-Za-z0-9._-]+\.sh)\b/.exec(command);
    if (named === null) continue;
    const shell = declaredShell(readFileSync(join(REPO_ROOT, named[1]), 'utf8'));
    assert.ok(shell, `${named[1]} declares a shell`);
    assert.ok(command.startsWith(`${shell} ${named[1]}`), `\`${command}\` runs ${named[1]}, which declares ${shell}`);
    checked += 1;
  }
  assert.ok(checked >= 8, `the check looked at ${checked} script invocation(s)`);
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

test('a failing instance job captures the throwaway before the teardown removes it (DW-232)', () => {
  // Run 34773637146's instance job failed at `container ocupilot-ci is unhealthy`, five seconds
  // after start -- before the first health check could run, so the container had exited rather
  // than failed a probe. That one line was the whole of the failing step's output; the cause
  // (`ERROR #5001: Cannot create target: /durable/iris/`, six of them) reached the job only in
  // the teardown's own `logs | tail -n 80`, under the step that then removed everything.
  //
  // Mutation (Rule 19): delete the capture step, or move it below the teardown, or narrow its
  // condition to `failure()` -> this goes red.
  const instance = jobSlice(workflow, 'instance');
  const captureAt = instance.indexOf('capture the throwaway on failure');
  const teardownAt = instance.indexOf('tear the throwaway down');
  assert.ok(captureAt > 0, 'the instance job captures the throwaway on the failure path');
  assert.ok(captureAt < teardownAt, 'before the teardown, which removes the container it would read');

  // Scoped to the instance job, and to a condition that covers cancellation. `timeout-minutes`
  // CANCELS a job rather than failing it, and so does this workflow's `cancel-in-progress`, so
  // `failure()` alone is false for a hung bring-up -- the case with the most to capture -- while
  // the `always()` teardown still removes the container. Counting conditions across the whole
  // file would also mean the images job could never grow a capture of its own.
  const failure = [...instance.matchAll(/^\s*if:\s*\$\{\{\s*failure\(\)\s*\|\|\s*cancelled\(\)\s*\}\}\s*$/gm)];
  assert.equal(failure.length, 1, `expected exactly one failure()||cancelled() step in the instance job (the capture), found ${failure.length}`);
  assert.ok(failure[0].index > captureAt && failure[0].index < teardownAt, 'and the condition belongs to it');

  const logsGate = DECLARED_GATES.find((gate) => gate.endsWith('ci-throwaway.sh logs'));
  assert.ok(logsGate, 'the capture is a declared gate like every other step');

  // What it captures: the state of the containers and the whole log, not a tail of one service.
  const throwaway = withoutShellComments(readFileSync(join(REPO_ROOT, 'scripts', 'ci-throwaway.sh'), 'utf8'));
  const logsArm = /^ {4}logs\)([\s\S]*?)^ {8};;/m.exec(throwaway);
  assert.ok(logsArm, 'ci-throwaway.sh answers a `logs` action');
  assert.match(logsArm[1], /docker compose -f "\$COMPOSE_FILE" ps -a/, 'it reports every container, exited ones included');
  assert.match(logsArm[1], /docker compose -f "\$COMPOSE_FILE" logs --no-color/, 'and the log itself');
  assert.ok(!/tail -n/.test(logsArm[1]), 'whole, not a tail: the evidence of a late failure is not in the last 80 lines');
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
  // Scoped to the images job: the gates job carries a `fail-fast: false` of its own now, and an
  // unscoped match would read that one and report this job as configured when it is not.
  assert.match(jobSlice(workflow, 'images'), /fail-fast: false/, 'so one edition failing still reports the other');
});

/**
 * A shell script with its whole-line `#` comments removed.
 *
 * Every text pin over `ci-throwaway.sh` below reads code, not prose. Without this a comment that
 * quotes what it explains -- `restart: on-failure:3`, `tail -n 80` -- is read by the pin as the
 * thing itself: one such comment made the drift pin report a policy change that had not happened,
 * and the inverse is worse, since a comment can satisfy a pin whose code was deleted. Only
 * full-line comments are dropped, so a `#` inside a parameter expansion or a string survives.
 */
export function withoutShellComments(source) {
  return source
    .split('\n')
    .filter((line) => !/^\s*#/.test(line))
    .join('\n');
}

/** The body of one job, from its key to the next job's (or the end of the file). */
export function jobSlice(text, name) {
  const names = jobNames(text);
  const at = text.indexOf(`\n  ${name}:`);
  if (at === -1) return '';
  const next = names.slice(names.indexOf(name) + 1).map((other) => text.indexOf(`\n  ${other}:`, at));
  const end = next.find((index) => index > at);
  return text.slice(at, end === undefined ? undefined : end);
}

/** The Node versions the gates job's matrix runs. */
export function gatesNodeMatrix(text) {
  const list = /^ {8}node:\n((?: {10}- \S+\n)+)/m.exec(jobSlice(text, 'gates'));
  if (list === null) return [];
  return [...list[1].matchAll(/-\s*['"]?([^'"\s]+)['"]?/g)].map((match) => match[1]);
}

/** Every caret band a `engines.node` range declares, as its floor version. */
export function declaredNodeBands(range) {
  return [...range.matchAll(/\^(\d+\.\d+\.\d+)/g)].map((match) => match[1]);
}

test('the gates job runs on the floor of every Node band the workspace declares (DW-231)', () => {
  // The pin for DW-231, and the only one of this file's assertions that generalises past the
  // shape of that defect. `node --test tools/` was a command that worked on one Node and not
  // another, and CI ran exactly one Node -- so "the gates pass" meant "the gates pass on
  // 22.22.3", while `engines` claimed three bands. A band the project declares and never runs
  // is a claim with no gate behind it, whatever the next such difference turns out to be.
  //
  // Equality in both directions, like the gate list above: the floors `engines.node` declares
  // and the legs the matrix runs are the same set.
  //
  // Mutation (Rule 19): drop `- '24.15.0'` from the matrix -> red naming 24.15.0. Add a leg for
  // a band `engines` does not declare -> red naming it.
  const packageJson = JSON.parse(readFileSync(join(here, '..', 'package.json'), 'utf8'));
  const declared = packageJson.engines.node;
  const bands = declaredNodeBands(declared);
  assert.ok(bands.length >= 2, `the workspace declares ${declared}; this assertion reads ${bands.length} band(s)`);

  const matrix = gatesNodeMatrix(workflow);
  assert.deepEqual(
    [...matrix].sort(),
    [...bands].sort(),
    `the gates job runs Node ${JSON.stringify(matrix)} and the workspace declares ${declared}. Every declared band is supported or it is not; a band with no leg here is a claim CI never tests, and a leg for a band engines does not declare fails npm ci under ui/.npmrc's engine-strict.`
  );

  const gates = jobSlice(workflow, 'gates');
  assert.match(gates, /node-version: \$\{\{ matrix\.node \}\}/, 'and the legs are what setup-node installs');
  assert.match(gates, /fail-fast: false/, 'so one band failing still reports the others');

  // The third copy of the same list. `version-guard.mjs` carries its own band declaration under
  // the comment "engines.node in package.json -- keep the two in sync", and it is the refusal a
  // developer actually meets, since `prebuild` and `pretest` invoke it. Without this the
  // two-way equality above is satisfiable while the guard disagrees: drop a band from BOTH
  // `engines.node` and the matrix and every assertion here stays green, while version-guard goes
  // on telling a developer on that Node that their toolchain is supported and `npm ci` refuses it
  // under ui/.npmrc's engine-strict. mutation (Rule 19): change one band in NODE_RANGE_LABEL -> red.
  assert.equal(
    NODE_RANGE_LABEL,
    declared,
    "version-guard.mjs's declared range and package.json's engines.node have drifted; version-guard is the refusal prebuild and pretest actually run"
  );
});

test('the instance job pins a Node the engines range admits', () => {
  // The instance job is not a matrix -- it builds the bundle a container installs, once -- so it
  // carries a literal, and the literal has to be inside the declared range like any other.
  const packageJson = JSON.parse(readFileSync(join(here, '..', 'package.json'), 'utf8'));
  const declared = packageJson.engines.node;
  const pinned = /node-version:\s*(\S+)/.exec(jobSlice(workflow, 'instance'));
  assert.ok(pinned, 'the instance job pins a node version');
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

// --- The test command the gates job runs (DW-231) ---------------------------------------------
//
// `npm test` is a declared gate above, and the gates job runs it on the Node version the workflow
// pins -- 22.22.3, which is also the floor `engines` declares. `node --test tools/` scans that
// directory on the Node 26 a developer runs locally and LOADS it as a module on 22: run
// 34773637146's gates job died at `Error: Cannot find module
// '/home/runner/work/OcuPilot/OcuPilot/ui/tools'` (MODULE_NOT_FOUND) and reported `# fail 1` over
// a suite of 584 that never ran. No gate in this repository could see it -- every one of them
// reads the script as text, and the text is the same on both versions.
//
// So both assertions below are about the ARGUMENTS rather than the string. The first resolves
// them against the working tree: each must name real files, never a directory, and together they
// must cover every test file on disk. That one is red on any Node, the developer's included. The
// second EXECUTES the declared form against a fixture under the interpreter running this test,
// which is 22.22.3 in the gates job -- red exactly where the defect lives, and the assertion that
// would have caught it.

/**
 * The positional arguments a package script hands `node --test`, up to `&&` or end of line.
 *
 * Flags are dropped rather than treated as paths: `node --test --test-reporter=tap tools/*.test.mjs`
 * is a legal form, and reading `--test-reporter=tap` as a path would fail the caller's assertions
 * for a change that is correct. Surrounding quotes are stripped for the same reason -- Node's own
 * documentation recommends quoting a glob so that Node expands it rather than the shell.
 */
export function nodeTestArguments(script) {
  const match = /node\s+--test\s+(.+?)(?:\s*&&|\s*$)/.exec(script);
  if (match === null) return [];
  return match[1]
    .trim()
    .split(/\s+/)
    .filter((token) => !token.startsWith('-'))
    .map((token) => token.replace(/^['"]|['"]$/g, ''));
}

/**
 * `dir/*.suffix`, or a plain path, expanded against a root -- no glob library, because the only
 * forms these scripts use are those two and `sh` is what expands them for npm.
 */
export function expandArgument(root, argument) {
  const at = argument.lastIndexOf('/');
  const dir = at === -1 ? '' : argument.slice(0, at);
  const leaf = argument.slice(at + 1);
  const base = join(root, dir);
  if (!existsSync(base)) return [];
  if (leaf === '') return [base];
  if (!leaf.includes('*')) {
    const path = join(base, leaf);
    return existsSync(path) ? [path] : [];
  }
  const pattern = new RegExp(
    `^${leaf.split('*').map((part) => part.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('[^/]*')}$`
  );
  return readdirSync(base)
    .filter((name) => pattern.test(name))
    .sort()
    .map((name) => join(base, name));
}

test('every test command names files, never a directory (DW-231)', () => {
  const uiRoot = join(here, '..');
  const packageJson = JSON.parse(readFileSync(join(uiRoot, 'package.json'), 'utf8'));
  let checked = 0;
  for (const name of ['test', 'test:tools', 'test:browser']) {
    const script = packageJson.scripts[name];
    assert.ok(script, `the workspace declares a "${name}" script`);
    const args = nodeTestArguments(script);
    assert.ok(args.length >= 1, `"${name}" hands node --test at least one path: ${JSON.stringify(script)}`);
    for (const argument of args) {
      const matches = expandArgument(uiRoot, argument);
      assert.ok(
        matches.length > 0,
        `"${name}" hands node --test ${argument}, which matches nothing under ui/ -- a run over no file exits 0 having tested nothing`
      );
      for (const path of matches) {
        assert.ok(
          statSync(path).isFile(),
          `"${name}" hands node --test ${argument}, which resolves to the DIRECTORY ${path}. Node 22.22.3 -- the version ci.yml pins and the floor engines declares -- loads a directory argument as a module rather than scanning it (MODULE_NOT_FOUND, run 34773637146). Name the files: tools/*.test.mjs.`
        );
        checked += 1;
      }
    }
  }
  assert.ok(checked >= 30, `the check resolved ${checked} path(s); a run over none would pass having looked at nothing`);
});

/**
 * Every file under `root` that Node's test runner would treat as a test file.
 *
 * Node's default patterns, from its own documentation: `*.test.{cjs,mjs,js}`, `*-test.…`,
 * `*_test.…`, `test-*.…`, `test.…`, and anything under a `test/` directory. Recursive, because
 * the directory form this file exists to replace WAS recursive: `node --test tools/` on a Node
 * that scans directories discovered all of these, and `tools/*.test.mjs` discovers one shape in
 * one directory. Deriving the population from Node's rules rather than from the command's own
 * suffix is what stops this from comparing a set with itself.
 */
export function nodeTestFilesUnder(root, prefix = '') {
  const named = /^(?:.+\.test|.+-test|.+_test|test-.+|test)\.(?:cjs|mjs|js)$/;
  const found = [];
  for (const entry of readdirSync(root, { withFileTypes: true })) {
    const relative = prefix === '' ? entry.name : `${prefix}/${entry.name}`;
    if (entry.isDirectory()) {
      found.push(...nodeTestFilesUnder(join(root, entry.name), relative));
    } else if (named.test(entry.name) || prefix.split('/').includes('test')) {
      found.push(relative);
    }
  }
  return found;
}

test('the tools suite CI runs covers every test file on disk (DW-231)', () => {
  // The other way a file-naming form fails: a glob whose suffix matches less than the tree
  // carries runs a subset and exits 0, which reads exactly like a green suite. Comparing the
  // glob's expansion against `readdirSync(...).endsWith('.test.mjs')` would compare one
  // population with itself -- both sides encode the same suffix, in the same one directory -- so
  // the population comes from Node's own discovery rules instead. A suite added at
  // tools/sub/x.test.mjs or named x-test.mjs is one the command would silently not run, and is
  // red here.
  const uiRoot = join(here, '..');
  const packageJson = JSON.parse(readFileSync(join(uiRoot, 'package.json'), 'utf8'));
  const args = nodeTestArguments(packageJson.scripts['test:tools']);
  const expanded = args.flatMap((argument) => expandArgument(uiRoot, argument)).map((path) => basename(path));
  const onDisk = nodeTestFilesUnder(join(uiRoot, 'tools'));
  assert.ok(onDisk.length >= 25, `tools/ carries ${onDisk.length} test file(s)`);
  assert.deepEqual(
    [...expanded].sort(),
    [...onDisk].sort(),
    `the test:tools command runs ${expanded.length} file(s) and Node would discover ${onDisk.length} under tools/. A file in neither set is one the command does not run and no gate reports.`
  );
  assert.deepEqual(
    nodeTestArguments(packageJson.scripts.test),
    args,
    '`npm test` runs the same suite as `npm run test:tools` before handing over to the component runner'
  );
});

test('the declared test-command form runs under this interpreter (DW-231)', () => {
  // Executed, not read. Each declared form is rebuilt over a two-file fixture and run through
  // `sh` -- the shell npm itself uses, so the glob is expanded exactly as it is in a real run --
  // with the same interpreter that is running this test. On the gates job that interpreter is
  // Node 22.22.3, and the directory form this replaced fails there and only there.
  const uiRoot = join(here, '..');
  const packageJson = JSON.parse(readFileSync(join(uiRoot, 'package.json'), 'utf8'));
  for (const name of ['test:tools', 'test:browser']) {
    const [argument] = nodeTestArguments(packageJson.scripts[name]);
    const leaf = argument.slice(argument.lastIndexOf('/') + 1);
    const fixture = mkdtempSync(join(tmpdir(), 'ocupilot-test-form-'));
    try {
      for (const stem of ['alpha', 'beta']) {
        const file = leaf.includes('*') ? leaf.replace('*', stem) : `${stem}.test.mjs`;
        writeFileSync(join(fixture, file), "import { test } from 'node:test';\ntest('fixture', () => {});\n");
      }
      // TAP, so the counts are the same string on every Node; and NODE_TEST_CONTEXT dropped,
      // because this runner sets it for the file it spawned and an inherited one makes the
      // grandchild report to a parent that is not listening.
      const env = { ...process.env };
      delete env.NODE_TEST_CONTEXT;
      // The directory is quoted and the leaf is not: the leaf is the glob, and quoting it would
      // stop `sh` expanding the very thing under test. `mkdtempSync` can hand back a TMPDIR with
      // a space in it, which unquoted would split into two arguments.
      const mapped = leaf === '' ? `"${fixture}"/` : `"${fixture}"/${leaf}`;
      const run = spawnSync('sh', ['-c', `"${process.execPath}" --test --test-reporter=tap ${mapped}`], {
        encoding: 'utf8',
        env,
      });
      assert.equal(
        run.status,
        0,
        `"${name}" hands node --test ${argument}; the same form over a fixture exits ${run.status} on ${process.version}:\n${run.stdout}${run.stderr}`
      );
      assert.match(
        run.stdout,
        /^# pass 2$/m,
        `"${name}" ran something other than the two fixture files on ${process.version}:\n${run.stdout}`
      );
    } finally {
      rmSync(fixture, { recursive: true, force: true });
    }
  }
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

// --- Why a class failed, and what it left behind (DW-242, DW-243) -----------------------------
//
// The runner prints each failed method with its failed assertions and what it raised, and fails a
// class after which any probe web application is still on the instance -- the class that leaked
// it, not the later class that trips over it. The stub `docker` below runs the real runner over
// the real session script; the ObjectScript half runs only on a throwaway.
//
// Mutations (Rule 19): drop the describeFailures loop from ci-runner's main() -> the executed
// failing run prints no method or message and goes red. Drop the classifyLeftovers push -> the
// executed leaking run exits 0 and goes red. Drop the classifyFailureDetail push -> the missing and
// raising-teardown runs exit 0, and the disagreeing and causeless runs lose their message; all go
// red. Make classifyLeftovers treat nothing as inherited -> the inherited run blames the class and
// goes red. Label an unchecked answer LEAKED, or print the session tail only for a failed verdict ->
// the unchecked run goes red.

const FAILURE_DETAIL = [
  {
    class: 'OcuPilot.Test.GrantReadBack',
    method: 'TestAGrantThatDidNotTakeFailsTheInstall',
    action: '',
    error: 'There are failed TestAsserts',
    asserts: [
      {
        action: 'AssertEquals',
        description: 'precondition: no probe web application exists before the install (found: /api/probeocupilot/readiness)',
        location: 'TestAGrantThatDidNotTakeFailsTheInstall+8^OcuPilot.Test.GrantReadBack.cls',
      },
    ],
  },
  {
    class: 'OcuPilot.Test.GrantReadBack',
    method: 'TestEveryDerivedTableReadsBackAsHeld',
    action: 'OnBeforeOneTest',
    error: ' ERROR #5001: install refused\r\n+  at EnsureSqlPrivileges',
    asserts: [],
  },
];

/**
 * The session output a class run prints: the leftover answer before the run (when `before` is
 * given), the run marker, the failure marker (unless `fails` is `null`), the leftover marker
 * (unless `probeApps` is `null`), then any `tail` lines.
 */
function sessionOutput({ failed, fails, probeApps, before = null, tail = [] }) {
  return [
    'HSCUSTOM>',
    ...(before === null ? [] : [`OCUPILOT-PROBEAPPS-BEFORE-START:${before}:OCUPILOT-PROBEAPPS-BEFORE-END`]),
    `OCUPILOT-RUN-START:44:3:${failed}:1:1:OCUPILOT-RUN-END`,
    ...(fails === null ? [] : [`OCUPILOT-FAILS-START:${JSON.stringify(fails)}:OCUPILOT-FAILS-END`]),
    ...(probeApps === null ? [] : [`OCUPILOT-PROBEAPPS-START:${probeApps}:OCUPILOT-PROBEAPPS-END`]),
    ...tail,
  ].join('\n');
}

/** Run the real runner over the real session script, with a stub `docker` printing `output`. */
function runRunnerOver(output) {
  const dir = mkdtempSync(join(tmpdir(), 'ocupilot-runner-'));
  try {
    const bin = join(dir, 'bin');
    writeStub(bin, 'docker', ['cat > /dev/null', 'printf \'%s\\n\' "$OCUPILOT_STUB_SESSION"']);
    return spawnSync(
      process.execPath,
      [join(here, 'ci-runner.mjs'), '--container', 'stub', '--class', 'OcuPilot.Test.GrantReadBack'],
      { encoding: 'utf8', env: stubEnv(bin, { OCUPILOT_STUB_SESSION: output }) }
    );
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test('DW-243: the runner reads each failed method, its assertion messages and what it raised out of the session', () => {
  const output = sessionOutput({ failed: 2, fails: FAILURE_DETAIL, probeApps: '' });
  assert.deepEqual(parseFailuresMarker(output), FAILURE_DETAIL);
  assert.deepEqual(parseFailuresMarker('OCUPILOT-FAILS-START:[]:OCUPILOT-FAILS-END'), [], 'a run with no failure reads as none');
  assert.equal(parseFailuresMarker('no marker'), null, 'no marker is not "no failures"');
  assert.equal(parseFailuresMarker('OCUPILOT-FAILS-START:[{:OCUPILOT-FAILS-END'), null, 'an unreadable marker is not "no failures"');

  assert.deepEqual(describeFailures(FAILURE_DETAIL), [
    'failed: OcuPilot.Test.GrantReadBack.TestAGrantThatDidNotTakeFailsTheInstall',
    '  AssertEquals: precondition: no probe web application exists before the install (found: /api/probeocupilot/readiness) [TestAGrantThatDidNotTakeFailsTheInstall+8^OcuPilot.Test.GrantReadBack.cls]',
    'failed: OcuPilot.Test.GrantReadBack.TestEveryDerivedTableReadsBackAsHeld',
    '  OnBeforeOneTest raised:  ERROR #5001: install refused +  at EnsureSqlPrivileges',
  ]);
  assert.deepEqual(
    describeFailures([{ class: 'A.B', method: '', action: 'OnAfterAllTests', error: 'ERROR #1', asserts: [] }]),
    ['failed: A.B (class level)', '  OnAfterAllTests raised: ERROR #1'],
    'a class whose own teardown raised is named as the class'
  );
});

test('DW-243: a failing class prints the failed method and its assertion message (executed)', () => {
  const result = runRunnerOver(sessionOutput({ failed: 1, fails: FAILURE_DETAIL.slice(0, 1), probeApps: '' }));
  assert.equal(result.status, 1, result.stdout + result.stderr);
  assert.match(result.stdout, /FAILED\s+OcuPilot\.Test\.GrantReadBack -- 3 test\(s\), 1 failed, run 44/);
  assert.match(result.stdout, /\n {6}failed: OcuPilot\.Test\.GrantReadBack\.TestAGrantThatDidNotTakeFailsTheInstall\n/);
  assert.match(
    result.stdout,
    /\n {8}AssertEquals: precondition: no probe web application exists before the install \(found: \/api\/probeocupilot\/readiness\) \[TestAGrantThatDidNotTakeFailsTheInstall\+8\^OcuPilot\.Test\.GrantReadBack\.cls\]\n/
  );
  assert.match(
    result.stderr,
    /GrantReadBack: 1 of 3 test\(s\) failed \(run 44\): OcuPilot\.Test\.GrantReadBack\.TestAGrantThatDidNotTakeFailsTheInstall/,
    'and the closing problem list names the method'
  );
});

test('DW-242: a probe web application that survives a class fails that class, and an unknown answer fails it too', () => {
  assert.deepEqual(parseProbeAppsMarker('OCUPILOT-PROBEAPPS-START::OCUPILOT-PROBEAPPS-END'), { paths: [], error: null });
  assert.deepEqual(parseProbeAppsMarker('OCUPILOT-PROBEAPPS-START:/probeocupilot /api/probeocupilot:OCUPILOT-PROBEAPPS-END'), {
    paths: ['/probeocupilot', '/api/probeocupilot'],
    error: null,
  });
  assert.equal(classifyLeftovers('X', { paths: [], error: null }), null);
  assert.match(classifyLeftovers('X', { paths: ['/probeocupilot'], error: null }), /^X: probe web application\(s\) survived the class's teardown -- \/probeocupilot/);
  assert.match(classifyLeftovers('X', null), /never a pass/, 'no marker is not "nothing survived"');
  assert.match(
    classifyLeftovers('X', parseProbeAppsMarker('OCUPILOT-PROBEAPPS-START:error: <PROTECT>:OCUPILOT-PROBEAPPS-END')),
    /could not check.*<PROTECT>.*never a pass/,
    'a failed check is not "nothing survived"'
  );

  const clean = runRunnerOver(sessionOutput({ failed: 0, fails: [], probeApps: '' }));
  assert.equal(clean.status, 0, `the same passing class with nothing left behind is green: ${clean.stdout}${clean.stderr}`);

  const leaked = runRunnerOver(sessionOutput({ failed: 0, fails: [], probeApps: '/api/probeocupilot/readiness', before: '' }));
  assert.equal(leaked.status, 1, 'a passing class that left a probe application is red');
  assert.match(leaked.stdout, /LEAKED\s+OcuPilot\.Test\.GrantReadBack/);
  assert.match(leaked.stderr, /OcuPilot\.Test\.GrantReadBack: probe web application\(s\) survived the class's teardown -- \/api\/probeocupilot\/readiness/);
  assert.match(leaked.stdout, /1 with probe leftovers/, 'and the summary line counts it');
});

test('DW-242: a leftover already present before the class ran is still red, and is blamed on an earlier class', () => {
  const before = { paths: ['/api/probeocupilot/readiness'], error: null };
  const after = { paths: ['/probeocupilot', '/api/probeocupilot/readiness'], error: null };
  const problem = classifyLeftovers('X', after, before);
  assert.match(problem, /survived the class's teardown -- \/probeocupilot\. /, 'the path the class added is its own leak');
  assert.match(problem, /already present before the class ran are still present -- \/api\/probeocupilot\/readiness; an earlier class or run left them/);
  assert.doesNotMatch(problem, /teardown -- [^.]*readiness/, 'the inherited path is not blamed on this class');
  assert.equal(leftoverIsOwn(after, before), true);
  assert.equal(leftoverIsOwn({ paths: ['/api/probeocupilot/readiness'], error: null }, before), false);

  const inherited = runRunnerOver(
    sessionOutput({ failed: 0, fails: [], probeApps: '/api/probeocupilot/readiness', before: '/api/probeocupilot/readiness' })
  );
  assert.equal(inherited.status, 1, 'an inherited leftover still fails the run');
  assert.match(inherited.stdout, /INHERITED\s+OcuPilot\.Test\.GrantReadBack/);
  assert.doesNotMatch(inherited.stdout + inherited.stderr, /survived the class's teardown/, 'and never tells this class to fix its teardown');
});

test('DW-243: failure detail that is missing, disagrees with the count, or names a raising teardown fails the class (executed)', () => {
  const landed = { runIndex: 44, total: 3, failed: 1, landed: true };
  assert.deepEqual(classifyFailureDetail('X', landed, FAILURE_DETAIL.slice(0, 1)), []);
  assert.deepEqual(classifyFailureDetail('X', { ...landed, landed: false }, null), [], 'a run that did not land is classifyRun\'s problem');

  const missing = runRunnerOver(sessionOutput({ failed: 0, fails: null, probeApps: '' }));
  assert.equal(missing.status, 1, 'no failure marker on a passing class is red');
  assert.match(missing.stderr, /printed no readable failure detail/);

  const disagrees = runRunnerOver(sessionOutput({ failed: 1, fails: [], probeApps: '' }));
  assert.equal(disagrees.status, 1);
  assert.match(disagrees.stderr, /names 0 failed method\(s\) but run 44 recorded 1/);

  const teardown = [{ class: 'OcuPilot.Test.GrantReadBack', method: '', action: 'OnAfterAllTests', error: ' ERROR #5001: uninstall refused', asserts: [] }];
  const raised = runRunnerOver(sessionOutput({ failed: 0, fails: teardown, probeApps: '' }));
  assert.equal(raised.status, 1, 'a class whose own teardown raised is red although every method passed');
  assert.match(raised.stdout, /FAILED\s+OcuPilot\.Test\.GrantReadBack/);
  assert.match(raised.stdout, /OnAfterAllTests raised: {2}ERROR #5001: uninstall refused/);
  assert.match(raised.stderr, /the class recorded a class-level error \(OnAfterAllTests\)/);

  // The framework writes a failed method with no action only when a failed assertion sits under it.
  const causeless = [{ ...FAILURE_DETAIL[0], asserts: [] }];
  assert.equal(classifyFailureDetail('X', landed, causeless).length, 1);
  const noCause = runRunnerOver(sessionOutput({ failed: 1, fails: causeless, probeApps: '' }));
  assert.equal(noCause.status, 1);
  assert.match(
    noCause.stderr,
    /names OcuPilot\.Test\.GrantReadBack\.TestAGrantThatDidNotTakeFailsTheInstall with no failed assertion and nothing raised, so the detail walk did not read its assertions/
  );
});

test('DW-242: an unchecked leftover answer is labelled UNCHECKED, not LEAKED, and prints the session tail (executed)', () => {
  assert.equal(leftoverIsOwn(null, null), false, 'no answer blames nobody');
  const unchecked = runRunnerOver(
    sessionOutput({ failed: 0, fails: [], probeApps: null, before: '', tail: ['<CLASS DOES NOT EXIST> *OcuPilot.Test.ProbeApps'] })
  );
  assert.equal(unchecked.status, 1, 'a class whose leftover answer is missing is red');
  assert.match(unchecked.stdout, /UNCHECKED\s+OcuPilot\.Test\.GrantReadBack/);
  assert.doesNotMatch(unchecked.stdout, /LEAKED/);
  assert.match(unchecked.stdout, /\n {6}\| <CLASS DOES NOT EXIST> \*OcuPilot\.Test\.ProbeApps/, 'the session tail names why');
  assert.match(unchecked.stdout, /0 with probe leftovers/, 'and nothing is counted as left behind');
  assert.match(unchecked.stderr, /did not report which probe web applications survived the class/);
});

test('DW-242, DW-243: the session reads failures from its own run index and reports leftovers before and after every class', () => {
  // Wiring beside the executed tests above: the stub cannot run ObjectScript.
  const script = readFileSync(join(REPO_ROOT, 'scripts', 'ci-unit-test.sh'), 'utf8');
  assert.match(script, /If tLanded Set tSuite = "" For {2}Set tSuite = \\\$Order\(\^UnitTest\.Result\(tRun, tSuite\)\)/, 'failures are read only when this run landed, at its own index');
  assert.doesNotMatch(script, /MAX\(/, 'never a MAX over result ids');
  assert.match(script, /"FAILS-START:"_tFails\.%ToJSON\(\)/);
  const before = script.indexOf('"PROBEAPPS-BEFORE-START:"_##class(OcuPilot.Test.ProbeApps).Existing()');
  const run = script.indexOf('##class(%UnitTest.Manager).RunTest(');
  const after = script.indexOf('"PROBEAPPS-START:"_##class(OcuPilot.Test.ProbeApps).Existing()');
  assert.ok(before !== -1 && run !== -1 && after !== -1 && before < run && run < after, 'the leftover answer is taken before RunTest and again after it');
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

  for (const state of ['failed', 'upgraderequired', 'unreadable']) {
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

test('smoke.sh admits an ordinary credential pair, escapes a quote in either field, and refuses a line break in either', () => {
  // This one EXECUTES the script instead of reading it, because the defect it pins was invisible
  // to a text assertion: `*"$(printf '\n')"*` reads as a newline test and is `*""*`, since command
  // substitution strips trailing newlines -- so every invocation exited 2 before any check ran,
  // here and at the workflow step that passes `--user _SYSTEM --password SYS`.
  //
  // A stub `iris` on PATH captures the session input, so three things are observable at once:
  // that an admitted pair reaches the session, that a refused one never does, and what
  // `escape_literal` put in the ObjectScript literal. `--demo` and `--namespace` are passed so
  // nothing reads `/proc/1/environ`, and no container is named, so RUNNER stays empty and the
  // stub is the whole instance. The stub takes its capture path from the environment rather than
  // from an interpolated literal, so a TMPDIR holding `$` or a backtick cannot redirect it.
  //
  // Every shell on the box is exercised, not only `/bin/sh`: `/bin/sh` is bash on macOS and dash
  // on a Linux runner, and the guard has to hold under both. (CI reaches these lines through
  // `npm test`; the workflow's own smoke step invokes the script with `sh`, its declared shell.)
  //
  // Mutations (Rule 19): restore `*"$(printf '\n')"*` as the pattern, or empty `SMOKE_NL` by
  // dropping the `x` from `printf '\nx'` -> the admitted cases go red at exit 2. Delete either
  // sentinel's arm -> that character's refusal rows go red. Narrow the `case` subject to
  // `"$SMOKE_PASSWORD"` -> the user-position refusals go red. Drop `escape_literal` from
  // `USER_LITERAL`, or its `s/"/""/g` -> the matching quoted row goes red.
  const dir = mkdtempSync(join(tmpdir(), 'ocupilot-smoke-credentials-'));
  try {
    const capture = join(dir, 'session-input.txt');
    const stub = join(dir, 'iris');
    writeFileSync(stub, '#!/bin/sh\ncat > "$OCUPILOT_SMOKE_CAPTURE"\nexit 0\n');
    chmodSync(stub, 0o755);

    const shells = ['/bin/sh', '/bin/dash', '/bin/bash'].filter((shell) => existsSync(shell));
    assert.ok(shells.includes('/bin/sh'), 'at least /bin/sh is available to run the script under');

    const runSmoke = (shell, user, password) =>
      spawnSync(
        shell,
        [
          join(REPO_ROOT, 'scripts', 'smoke.sh'),
          '--demo', '0',
          '--namespace', 'HSCUSTOM',
          '--user', user,
          '--password', password,
        ],
        {
          cwd: REPO_ROOT,
          encoding: 'utf8',
          env: {
            ...process.env,
            PATH: `${dir}:${process.env.PATH ?? ''}`,
            OCUPILOT_SMOKE_CAPTURE: capture,
          },
        }
      );

    for (const shell of shells) {
      const ordinary = runSmoke(shell, '_SYSTEM', 'SYS');
      assert.notEqual(ordinary.status, 2, `${shell}: an ordinary credential pair is a caller error in no way: ${ordinary.stdout}${ordinary.stderr}`);
      assert.doesNotMatch(`${ordinary.stdout}${ordinary.stderr}`, /may not contain a newline/, `${shell}: and is never refused as line-break-bearing`);
      assert.ok(existsSync(capture), `${shell}: an ordinary pair reaches the iris session`);
      assert.match(
        readFileSync(capture, 'utf8'),
        /OcuPilot\.Install\.Smoke\)\.Run\("_SYSTEM", "SYS",/,
        `${shell}: carrying both credentials into the Run() call`
      );
      rmSync(capture);

      // Refused, in EITHER field, for both characters `iris session` ends a piped line on.
      for (const [label, user, password] of [
        ['a newline in the password', '_SYSTEM', 'S\nYS'],
        ['a newline in the user', '_SYS\nWrite 99', 'SYS'],
        ['a carriage return in the password', '_SYSTEM', 'S\rYS'],
        ['a carriage return in the user', '_SYS\rWrite 99', 'SYS'],
      ]) {
        const refused = runSmoke(shell, user, password);
        assert.equal(refused.status, 2, `${shell}: ${label} is refused as a caller error: ${refused.stdout}${refused.stderr}`);
        assert.match(`${refused.stdout}${refused.stderr}`, /credentials may not contain a newline or a carriage return/, `${shell}: ${label}, naming why`);
        assert.ok(!existsSync(capture), `${shell}: ${label}, so no session runs and the text after the break cannot execute as a command of its own`);
      }

      // The sibling guard, on the same harness: a quote is escaped rather than refused, in either
      // field, so the ObjectScript literal still closes where the here-doc means it to.
      for (const [user, password, literal] of [
        ['_SYSTEM', 'S"Y"S', '"_SYSTEM", "S""Y""S"'],
        ['S"Y"S', 'SYS', '"S""Y""S", "SYS"'],
      ]) {
        const quoted = runSmoke(shell, user, password);
        assert.notEqual(quoted.status, 2, `${shell}: a quote in a credential is escaped, not refused: ${quoted.stdout}${quoted.stderr}`);
        assert.ok(existsSync(capture), `${shell}: and the session runs`);
        assert.ok(
          readFileSync(capture, 'utf8').includes(`.Run(${literal},`),
          `${shell}: with each quote doubled, which is how ObjectScript escapes one inside a literal`
        );
        rmSync(capture);
      }
    }
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('smoke.sh answers every caller error with exit 2, and --help still prints its whole header', () => {
  // The four refusal arms below were in exactly the state that produced the credential-guard
  // defect this story reworked: an arm no test executed. Mutation (Rule 19): change any arm's
  // `exit 2` to `exit 1`, or delete the arm -> that row goes red.
  const scriptPath = join(REPO_ROOT, 'scripts', 'smoke.sh');
  const run = (argv) => spawnSync('/bin/sh', [scriptPath, ...argv], { cwd: REPO_ROOT, encoding: 'utf8' });

  for (const [why, argv] of [
    ['an unknown argument', ['--bogus']],
    ['--container together with --compose-file', ['--container', 'a', '--compose-file', 'b']],
    ['--demo with a value that is neither 0 nor 1', ['--demo', '2']],
    ['--user with no --password', ['--user', '_SYSTEM']],
  ]) {
    const refused = run(argv);
    assert.equal(refused.status, 2, `${why} is a caller error, not an instance failure: ${refused.stdout}${refused.stderr}`);
    assert.match(`${refused.stdout}${refused.stderr}`, /^smoke: \S/m, `${why}, said in the script's own voice`);
  }

  // `--help` prints a hard-coded line range (`sed -n '2,38p'`), so the header and the range drift
  // apart in silence -- this story's own rework added six lines and stayed correct only because
  // they landed below the range. Mutation: add a line to the header block -> red.
  const lines = readFileSync(scriptPath, 'utf8').split('\n');
  const firstCode = lines.findIndex((line, index) => index > 0 && !line.startsWith('#'));
  assert.equal(lines[firstCode], 'set -e', 'the header runs from line 2 to the line before `set -e`');
  const help = run(['--help']);
  assert.equal(help.status, 0, 'asking for help is not an error');
  assert.equal(
    help.stdout.trimEnd(),
    lines.slice(1, firstCode).join('\n').trimEnd(),
    '--help prints the whole comment header and nothing below it'
  );
});

test('the throwaway and the image probe refuse to touch the live container', () => {
  // The highest-consequence lines in either script: the ones that keep CI off the owner's
  // instance. Mutation (Rule 19): delete any refusal below -> this goes red.
  const throwaway = withoutShellComments(readFileSync(join(REPO_ROOT, 'scripts', 'ci-throwaway.sh'), 'utf8'));
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

test('the throwaway prepares a durable directory IRIS can write, and leaves none behind (DW-232)', () => {
  // EXECUTED, with a stub `docker` on PATH, for the reason the smoke tests above are: the defect
  // this pins was invisible to every text assertion in this file. `mkdir -p "$DIR/data"` leaves a
  // 0755 directory owned by the invoking user, and a bind mount keeps that ownership inside the
  // container on Linux -- where IRIS runs as uid 51773 and cannot create /durable/iris in it. Run
  // 34773637146's instance job died there: `ERROR #5001: Cannot create target: /durable/iris/`,
  // three times, then `Instance is not running`, five seconds after start. Docker Desktop maps
  // bind-mount ownership to the caller, so the same script has always worked on macOS, and the
  // text was identical on both.
  //
  // Probed on this build against the pinned image, in a named volume (real Linux semantics, not
  // Docker Desktop's mapping): uid 51773 into a 0755 directory owned by uid 1001 ->
  // `mkdir: cannot create directory '/scratch/data/iris': Permission denied`; the same directory
  // at 0777 -> created. And afterwards uid 1001 could not remove what 51773 had written --
  // `rm: cannot remove '.../messages.log': Permission denied`, exit 1 -- which is the second half
  // below: a teardown that cannot remove its own scratch directory fails the job at `if: always()`.
  //
  // Since DW-234 the directory is no longer opened to everyone: the generated compose file carries
  // the same one-shot `durable-init` service docker-compose.yml does, which makes it writable by
  // uid 51773 before `iris` starts, so on a Linux runner this bring-up proves that service end to
  // end. What durable-init.sh does is executed by `scripts/ci-durable-ownership.sh`.
  //
  // Mutations (Rule 19): put `chmod 777 "$DIR/data"` back -> the mode assertion goes red. Drop the
  // generated durable-init service or iris's depends_on on it -> the compose assertions go red.
  // Delete `scrub_data`'s container fallback, or its call in the `down` arm -> the second half goes
  // red with the tree still on disk.
  const dir = mkdtempSync(join(tmpdir(), 'ocupilot-throwaway-'));
  try {
    const bin = join(dir, 'bin');
    const scratch = join(dir, 'scratch');
    const capture = join(dir, 'docker-argv.txt');
    mkdirSync(bin);
    // The stub records every invocation, and performs the one the script depends on for its own
    // next line: the scrub removes the tree as root, so `rm -rf "$DIR"` after it can succeed.
    writeStub(bin, 'docker', [
      'printf \'%s\\n\' "$*" >> "$OCUPILOT_DOCKER_CAPTURE"',
      'for arg in "$@"; do',
      '  case "$arg" in',
      '    *:/scratch) target="${arg%:/scratch}"; chmod -R u+rwx "$target/data" 2>/dev/null; rm -rf "$target/data" ;;',
      '  esac',
      'done',
      'exit 0',
    ]);
    const run = (...args) =>
      spawnSync('sh', [join(REPO_ROOT, 'scripts', 'ci-throwaway.sh'), ...args], {
        cwd: REPO_ROOT,
        encoding: 'utf8',
        env: stubEnv(bin, { OCUPILOT_DOCKER_CAPTURE: capture }),
      });

    const up = run('up', '--dir', scratch);
    assert.equal(up.status, 0, `up failed: ${up.stdout}${up.stderr}`);
    const mode = statSync(join(scratch, 'data')).mode & 0o777;
    assert.notEqual(mode & 0o002, 0o002, `the durable directory came up ${mode.toString(8)}: never world-writable; durable-init makes it IRIS's`);
    const composeFile = readFileSync(join(scratch, 'compose.yml'), 'utf8');
    assert.match(composeFile, new RegExp(`${scratch}/data:/durable`), 'and it is the directory mounted at /durable');
    assert.match(
      composeFile,
      /\n {2}durable-init:\n(?: {4}.*\n)*? {6}- \S+\/data:\/durable\n/,
      'the generated durable-init service mounts that same directory'
    );
    assert.match(
      composeFile,
      /depends_on:\n {6}durable-init:\n {8}condition: service_completed_successfully/,
      'and iris starts only once it has exited 0'
    );
    assert.match(readFileSync(capture, 'utf8'), /compose -f \S+ up -d --wait/, 'the bring-up waits on the health check');

    // Now the tree IRIS leaves: files this user can read and a directory it cannot write, which
    // is what uid 51773's work looks like from the runner's side.
    mkdirSync(join(scratch, 'data', 'iris', 'mgr'), { recursive: true });
    writeFileSync(join(scratch, 'data', 'iris', 'mgr', 'messages.log'), 'IRIS was here\n');
    chmodSync(join(scratch, 'data', 'iris', 'mgr'), 0o555);

    const down = run('down', '--dir', scratch);
    assert.equal(down.status, 0, `down failed: ${down.stdout}${down.stderr}`);
    assert.match(readFileSync(capture, 'utf8'), /compose -f \S+ down -v/, 'the teardown removes the container and its volumes');
    assert.ok(!existsSync(scratch), 'and the scratch directory is gone, whoever owned what was in it');

    const argv = readFileSync(capture, 'utf8');
    const source = withoutShellComments(readFileSync(join(REPO_ROOT, 'scripts', 'ci-throwaway.sh'), 'utf8'));
    assert.match(
      source,
      /--entrypoint sh -v "\$DIR:\/scratch"/,
      'a tree the invoking user cannot unlink is removed through the image, with the entrypoint overridden so nothing starts an instance'
    );
    // And that it RAN, wherever the removal above could actually be made to fail. Root can unlink
    // anything, so a suite run as root reaches the plain removal and this stays the text pin.
    if ((process.getuid?.() ?? 0) !== 0) {
      assert.match(
        argv,
        /run --rm --user 0:0 --entrypoint sh -v \S+:\/scratch \S+ -c rm -rf \/scratch\/data/,
        'and it is what removed the tree here, which is the only way a runner removes what IRIS wrote'
      );
    }
    assert.ok(!/-p |--publish|:1972|:52773/.test(argv), 'and nothing this script runs outside compose publishes a port');
  } finally {
    // Whatever the assertions did, leave nothing: the 0555 directory above is unremovable until
    // it is writable again.
    if (existsSync(join(dir, 'scratch', 'data', 'iris', 'mgr'))) {
      chmodSync(join(dir, 'scratch', 'data', 'iris', 'mgr'), 0o755);
    }
    rmSync(dir, { recursive: true, force: true });
  }
});

test('the failure-path capture reads the containers and says so when there are none (DW-232)', () => {
  // Executed for the same reason: an `if: failure()` step is reached only on a path no local run
  // takes, so a `logs` action that exited non-zero over a bring-up that never got as far as
  // writing a compose file would replace the failure being diagnosed with one of its own.
  const dir = mkdtempSync(join(tmpdir(), 'ocupilot-throwaway-logs-'));
  try {
    const bin = join(dir, 'bin');
    const scratch = join(dir, 'scratch');
    const capture = join(dir, 'docker-argv.txt');
    mkdirSync(bin);
    mkdirSync(scratch);
    writeStub(bin, 'docker', ['printf \'%s\\n\' "$*" >> "$OCUPILOT_DOCKER_CAPTURE"', 'exit 0']);
    const run = () =>
      spawnSync('sh', [join(REPO_ROOT, 'scripts', 'ci-throwaway.sh'), 'logs', '--dir', scratch], {
        cwd: REPO_ROOT,
        encoding: 'utf8',
        env: stubEnv(bin, { OCUPILOT_DOCKER_CAPTURE: capture }),
      });

    const nothing = run();
    assert.equal(nothing.status, 0, 'a capture over a throwaway that was never written is not a second failure');
    assert.match(nothing.stdout, /nothing was brought up/, 'and says which of the two it is');
    assert.ok(!existsSync(capture), 'without asking docker about a container nobody created');

    writeFileSync(join(scratch, 'compose.yml'), 'name: ocupilot-ci\n');
    const captured = run();
    assert.equal(captured.status, 0, `the capture failed: ${captured.stdout}${captured.stderr}`);
    const argv = readFileSync(capture, 'utf8');
    assert.match(argv, /compose -f \S+ ps -a/, 'a container that exited is still reported');
    assert.match(argv, /compose -f \S+ logs --no-color --timestamps/, 'and its whole log is printed');
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("the throwaway's port and name are one fact, not five declarations of one", () => {
  // 52776 was written independently in five places -- ci-throwaway.sh's WEB_PORT default, the
  // wait-readiness gate string, the browser job's `env:`, browser.config.mjs's DEFAULT_ORIGIN
  // and this file's DECLARED_GATES -- and nothing held any two of them equal. `runCommands()`
  // reads only `run:` lines, so the `env:` one was pinned by nothing at all. Changing the
  // throwaway's default leaves `npm test` green and breaks a job whose first run is the owner's.
  //
  // Mutation (Rule 19): change WEB_PORT in ci-throwaway.sh, or the port in either the
  // wait-readiness gate, the `env:` line or browser.config.mjs -> this goes red naming the pair.
  const throwaway = withoutShellComments(readFileSync(join(REPO_ROOT, 'scripts', 'ci-throwaway.sh'), 'utf8'));
  const browserConfig = readFileSync(join(REPO_ROOT, 'ui', 'browser.config.mjs'), 'utf8');

  const webPort = /^WEB_PORT="(\d+)"/m.exec(throwaway);
  assert.ok(webPort, 'ci-throwaway.sh declares a WEB_PORT default');
  const port = webPort[1];

  const waitGate = DECLARED_GATES.find((gate) => gate.startsWith('sh scripts/wait-readiness.sh'));
  assert.ok(waitGate, 'a wait-readiness gate is declared');
  assert.match(waitGate, new RegExp(`localhost:${port}/`), `the readiness gate waits on the throwaway's own port ${port}`);

  const browserOrigin = /OCUPILOT_BROWSER_ORIGIN:\s*(\S+)/.exec(workflow);
  assert.ok(browserOrigin, "the browser step sets OCUPILOT_BROWSER_ORIGIN -- the one setting runCommands() cannot see");
  assert.equal(browserOrigin[1], `http://localhost:${port}`, "the browser step drives the throwaway's own port");

  const defaultOrigin = /DEFAULT_ORIGIN = '([^']+)'/.exec(browserConfig);
  assert.ok(defaultOrigin, 'browser.config.mjs declares a DEFAULT_ORIGIN');
  assert.equal(defaultOrigin[1], `http://localhost:${port}`, "the harness's default origin is the throwaway's own port");
  assert.ok(!/52774|:1973/.test(defaultOrigin[1]), 'and never the live container');

  const project = /^PROJECT="([^"]+)"/m.exec(throwaway);
  assert.ok(project, 'ci-throwaway.sh declares a PROJECT default');
  for (const gate of DECLARED_GATES) {
    const named = /--container (\S+)/.exec(gate);
    if (named === null) continue;
    assert.equal(
      named[1],
      project[1],
      `"${gate}" names a container the throwaway does not create (it creates ${project[1]})`
    );
  }
});

test("ci-image-compile.sh's verdict arms are the ones the images job's claim rests on", () => {
  // The only criterion whose whole claim is "plain IRIS Community is not broken", and its
  // verdict logic was read by no test: inverting the admin arm, dropping the zero-class floor
  // or shifting a `cut` field left every gate in the repository green.
  //
  // Mutation (Rule 19): invert `[ "$ADMIN_V2" != "1" ]`, delete the `-lt 1` floor, or change
  // the compile arm's `!= "OK"` -> this goes red naming the arm.
  const image = readFileSync(join(REPO_ROOT, 'scripts', 'ci-image-compile.sh'), 'utf8');
  const code = image.replace(/^\s*#.*$/gm, '');
  assert.match(code, /"\$OUTCOME" != "OK"[\s\S]{0,400}?exit 1/, 'a failed compile exits non-zero');
  assert.match(code, /"\$\{COUNT:-0\}" -lt 1[\s\S]{0,400}?exit 1/, 'and a compile that produced no class is a failure, never a pass');
  assert.match(code, /"\$ADMIN_PRESENT" != "1" \] \|\| \[ "\$ADMIN_V2" != "1"[\s\S]{0,400}?exit 1/, 'and an edition whose admin API does not report v2 exits non-zero');
  // The version is READ, not inferred from a class name existing: an earlier form tested
  // %Dictionary.CompiledClass.%ExistsId("%Api.Admin.Dispatch.v2") while the header, the workflow
  // and README all said the API "answers v2".
  assert.match(
    code,
    /HighestDispatchVersion\(##class\(OcuPilot\.Port\.AdminPort\)\.AdminApiClass\(\)\)/,
    "the version comes from AdminPort's own read of the routing class AdminPort names, not from a class name"
  );
  assert.ok(
    !/%ExistsId\("%Api\.Admin\.Dispatch/.test(code),
    'and no class-existence test stands in for it'
  );
});

test("the pre-commit hook runs the ObjectScript checker when only a CI shell script is staged", () => {
  // check-objectscript.py's admin-API containment rule reads scripts/*.sh, so a commit staging
  // only such a script must still fire the checker's trigger.
  //
  // Mutation (Rule 19): drop 'scripts/*.sh' from OS_TRIGGER -> this goes red.
  const hook = readFileSync(join(REPO_ROOT, '.githooks', 'pre-commit'), 'utf8');
  const trigger = hook.slice(hook.indexOf('OS_TRIGGER=$('));
  const pathspecEnd = trigger.indexOf(')\n');
  assert.ok(pathspecEnd > 0, 'the OS_TRIGGER pathspec is terminated');
  assert.match(trigger.slice(0, pathspecEnd), /'scripts\/\*\.sh'/, "the checker's trigger fires on a staged CI shell script");
  const block = trigger.slice(trigger.indexOf('if [ -n "$OS_TRIGGER" ]'));
  const blockEnd = block.indexOf('\nfi\n');
  assert.ok(blockEnd > 0, 'the OS_TRIGGER block is closed');
  assert.match(
    block.slice(0, blockEnd),
    /^\s*uv run scripts\/check-objectscript\.py/m,
    'and that trigger is the one that runs the checker'
  );
});

test('the throwaway start path is the one docker-compose.yml ships', () => {
  // ci-throwaway.sh's own header says "`ui/tools/compose.test.mjs` pins what they are" -- and it
  // pins what docker-compose.yml says, not what the throwaway writes. Nothing compared the two,
  // so CI's only real-instance job could validate a start path the repository no longer ships.
  //
  // Mutation (Rule 19): change the healthcheck interval, the restart policy, the command, the
  // depends_on condition or any durable-init key in either file alone -> this goes red naming it.
  const throwaway = withoutShellComments(readFileSync(join(REPO_ROOT, 'scripts', 'ci-throwaway.sh'), 'utf8'));
  const compose = readFileSync(join(REPO_ROOT, 'docker-compose.yml'), 'utf8');
  const service = (text, name) => {
    const at = text.search(new RegExp(`^ {2}${name}:\\s*$`, 'm'));
    if (at === -1) return '';
    const rest = text.slice(at + 1);
    const next = rest.search(/^(?: {2}(?:#|[A-Za-z])|EOF$)/m);
    return next === -1 ? text.slice(at) : text.slice(at, at + 1 + next);
  };
  for (const [key, name, pattern] of [
    ['restart policy', 'iris', /restart:\s*(\S+)/],
    ['start hook command', 'iris', /command:\s*(\[.*\])/],
    ['healthcheck test', 'iris', /test:\s*(\[.*\])/],
    ['healthcheck interval', 'iris', /interval:\s*(\S+)/],
    ['healthcheck retries', 'iris', /retries:\s*(\S+)/],
    ['depends_on condition', 'iris', /depends_on:\s*\n\s*(durable-init:\s*\n\s*condition:\s*\S+)/],
    ['durable-init user', 'durable-init', /user:\s*(\S+)/],
    ['durable-init entrypoint', 'durable-init', /entrypoint:\s*(\[.*\])/],
    ['durable-init restart', 'durable-init', /restart:\s*(\S+)/],
    ['durable-init scripts mount', 'durable-init', /-\s*\S+(\/scripts:\/opt\/ocupilot\/scripts:ro)/],
  ]) {
    const fromCompose = pattern.exec(service(compose, name));
    const fromThrowaway = pattern.exec(service(throwaway, name));
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
  const throwaway = withoutShellComments(readFileSync(join(REPO_ROOT, 'scripts', 'ci-throwaway.sh'), 'utf8'));
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

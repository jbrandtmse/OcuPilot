import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
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
  'cat /proc/sys/net/ipv4/ip_local_port_range',
  'sh scripts/ci-throwaway.sh up',
  'sh scripts/wait-readiness.sh --url http://localhost:52776/api/ocupilot/readiness/',
  'node tools/admin-spec.mjs --origin http://localhost:52776',
  'sudo sysctl -w net.ipv4.ip_local_reserved_ports=52776,52780,52781',
  'node tools/ci-runner.mjs --container ocupilot-ci',
  'sh scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS',
  'npm run test:browser',
  'sh scripts/ci-throwaway.sh logs',
  'sh scripts/ci-throwaway.sh down',
  // browser -- the same script fully parameterised onto a second throwaway, so the two suites
  // that dominated the old instance job run side by side instead of end to end.
  'npm ci',
  'npm run build',
  'cat /proc/sys/net/ipv4/ip_local_port_range',
  'sudo sysctl -w net.ipv4.ip_local_reserved_ports=52776,52780,52781',
  'sh scripts/ci-throwaway.sh up --dir /tmp/ocupilot-browser-ci --project ocupilot-browser-ci --web 52780 --super 1979',
  'sh scripts/wait-readiness.sh --url http://localhost:52780/api/ocupilot/readiness/',
  'sh scripts/ci-throwaway.sh logs --dir /tmp/ocupilot-browser-ci',
  'sh scripts/ci-throwaway.sh down --dir /tmp/ocupilot-browser-ci --project ocupilot-browser-ci',
  // images -- compiled portless first, then installed on a throwaway of the same edition, which
  // takes a third port pair so it never collides with the other two jobs' throwaways.
  'sh scripts/ci-image-compile.sh --image ${{ matrix.image }}',
  'npm ci',
  'npm run build',
  'sudo sysctl -w net.ipv4.ip_local_reserved_ports=52776,52780,52781',
  'sh scripts/ci-throwaway.sh up --dir /tmp/ocupilot-images-ci --project ocupilot-images-ci --web 52781 --super 1980 --image ${{ matrix.image }}',
  'sh scripts/wait-readiness.sh --url http://localhost:52781/api/ocupilot/readiness/',
  'node tools/admin-spec.mjs --origin http://localhost:52781',
  'sh scripts/smoke.sh --container ocupilot-images-ci --user _SYSTEM --password SYS',
  'sh scripts/ci-throwaway.sh logs --dir /tmp/ocupilot-images-ci',
  'sh scripts/ci-throwaway.sh down --dir /tmp/ocupilot-images-ci --project ocupilot-images-ci --image ${{ matrix.image }}',
  // package -- `npm ci` and `npm run build` run a THIRD time here, in a job with its own
  // checkout, because the IPM manifest copies the built bundle into the archive.
  'npm ci',
  'npm run build',
  'sh scripts/ci-ipm-archive.sh --image intersystems/irishealth-community:2026.2',
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

test('nothing in the workflow or the archive builder publishes, releases or pushes to a registry (stealth policy)', () => {
  // The same seven patterns are applied to `scripts/ci-ipm-archive.sh` as well as to the workflow:
  // that script builds the distributable archive, so a forbidden token inside it would publish
  // exactly as effectively as one in a step that calls it. Comment lines are kept on the script
  // side -- a comment naming an upload token is a reader's instruction to add one.
  // `ui/tools/ipm-archive.test.mjs` runs a STRICTER version of this scan over the same script --
  // the bare word `publish` rather than `npm publish`, plus a credential-variable pattern. This
  // one is the floor the workflow and the script share; that one is the script's own.
  const archive = readFileSync(join(REPO_ROOT, 'scripts', 'ci-ipm-archive.sh'), 'utf8');
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
    assert.doesNotMatch(
      archive,
      pattern,
      `scripts/ci-ipm-archive.sh carries ${what}; the archive builder never uploads what it builds (Story 13.3)`
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
  const teardowns = [...workflow.matchAll(/tear the throwaway down/g)];
  assert.ok(teardowns.length > 0, 'the teardown step is named');
  assert.equal(
    always.length,
    teardowns.length,
    `expected one always() step per teardown (${teardowns.length}), found ${always.length}`
  );
  // Each always() belongs to the teardown it follows, and to no other step: pairwise, in order.
  teardowns.forEach((teardown, i) => {
    assert.ok(always[i].index > teardown.index, `always() #${i + 1} belongs to its own teardown`);
    const next = teardowns[i + 1];
    if (next) assert.ok(always[i].index < next.index, `always() #${i + 1} does not belong to the next job's teardown`);
  });
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
  // Every throwaway-owning job, not just the first: the browser job was split out of instance on
  // 2026-09-22 and the images job gained its own throwaway in Story 8.9, and each inherits the same
  // hazard, so asserting only `instance` would let a newer job lose its capture silently -- which
  // is the exact shape of the defect this test was written for.
  for (const jobName of ['instance', 'browser', 'images']) {
  const instance = jobSlice(workflow, jobName);
  const captureAt = instance.indexOf('capture the throwaway on failure');
  const teardownAt = instance.indexOf('tear the throwaway down');
  assert.ok(captureAt > 0, `the ${jobName} job captures the throwaway on the failure path`);
  assert.ok(captureAt < teardownAt, 'before the teardown, which removes the container it would read');

  // Scoped to the instance job, and to a condition that covers cancellation. `timeout-minutes`
  // CANCELS a job rather than failing it, and so does this workflow's `cancel-in-progress`, so
  // `failure()` alone is false for a hung bring-up -- the case with the most to capture -- while
  // the `always()` teardown still removes the container. Counting conditions across the whole
  // file would also mean the images job could never grow a capture of its own.
  const failure = [...instance.matchAll(/^\s*if:\s*\$\{\{\s*failure\(\)\s*\|\|\s*cancelled\(\)\s*\}\}\s*$/gm)];
  assert.equal(failure.length, 1, `expected exactly one failure()||cancelled() step in the ${jobName} job (the capture), found ${failure.length}`);
  assert.ok(failure[0].index > captureAt && failure[0].index < teardownAt, 'and the condition belongs to it');
  }

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

test('the five jobs are declared, and the instance job waits on readiness before any suite', () => {
  // An equality, not a superset: a job nothing here names is how a step nothing here describes
  // arrives, which is the same reason the run-command list is held equal in both directions.
  assert.deepEqual(jobNames(workflow), ['gates', 'instance', 'browser', 'images', 'package']);

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

  // Both new steps are placed for their position, and the DECLARED_GATES equality above compares
  // SORTED multisets -- so without these two assertions either could be moved with every gate
  // green. DW-439's criterion is that the range is logged "whether or not the bind succeeded",
  // which is only true while the probe runs BEFORE the bring-up that may fail; and the admin-spec
  // step is placed to fail in seconds rather than forty minutes into the suites.
  const rangeAt = workflow.indexOf('cat /proc/sys/net/ipv4/ip_local_port_range');
  assert.ok(rangeAt > 0 && rangeAt < upAt, 'the ephemeral-range probe runs before the bind that may fail (DW-439)');
  const adminSpecAt = workflow.indexOf('tools/admin-spec.mjs --origin');
  assert.ok(adminSpecAt > waitAt, 'the admin API drift gate runs after readiness');
  assert.ok(adminSpecAt < runnerAt, 'and before the long suites, so a vendor drift fails in seconds (AD-27)');
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

test('every job that pins a literal Node pins one the engines range admits', () => {
  // `instance` and `package` are not matrices -- each builds the bundle a container installs,
  // once -- so each carries a literal, and a literal has to be inside the declared range like any
  // other. Both are named here rather than only `instance`: a second job pinning a literal that
  // this test did not read would keep a stale pin when the floor moves, and `engine-strict` would
  // report it as an npm failure in a job no gate had ever looked at.
  const packageJson = JSON.parse(readFileSync(join(here, '..', 'package.json'), 'utf8'));
  const declared = packageJson.engines.node;
  const literalPinners = ['instance', 'browser', 'images', 'package'];
  for (const job of literalPinners) {
    const pinned = /node-version:\s*(\S+)/.exec(jobSlice(workflow, job));
    assert.ok(pinned, `the ${job} job pins a node version`);
    assert.doesNotMatch(pinned[1], /\$\{\{/, `the ${job} job pins a literal, not a matrix expression`);
    const [major, minor, patch] = pinned[1].split('.').map(Number);
    assert.ok(
      declared.includes(`^${major}.`),
      `the ${job} job pins Node ${pinned[1]} and the workspace declares ${declared}; a pin outside the range fails at npm ci with engine-strict`
    );
    const floor = new RegExp(`\\^${major}\\.(\\d+)\\.(\\d+)`).exec(declared);
    assert.ok(floor, `the engines range names a ^${major} band`);
    assert.ok(
      minor > Number(floor[1]) || (minor === Number(floor[1]) && patch >= Number(floor[2])),
      `the ${job} job pins Node ${pinned[1]}, below the ${declared} floor`
    );
  }
  // And the list above is held equal to the jobs that actually carry one, so a third such job
  // cannot be added without being covered here.
  const withLiteralPin = jobNames(workflow).filter((job) => {
    const pin = /node-version:\s*(\S+)/.exec(jobSlice(workflow, job));
    return pin !== null && !pin[1].includes('${{');
  });
  assert.deepEqual(
    withLiteralPin.sort(),
    [...literalPinners].sort(),
    'a job pins a literal Node version that this test does not check against engines.node'
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
  assert.match(throwaway, /ocupilot-slot-\*\)/, 'and every slot dev-instance project name');
  assert.match(throwaway, /"\$WEB_PORT" = "52775"/, "and slot B's web port");
  assert.match(throwaway, /"\$WEB_PORT" = "52778"/, "and slot C's web port");
  assert.match(throwaway, /"\$SUPER_PORT" = "1974"/, "and slot B's SuperServer port");
  assert.match(throwaway, /docker compose ls -a --format json[^\n]*Name/, 'and it asks Compose whether the project name is already taken');
  assert.match(throwaway, /ConfigFiles[^\n]*\$COMPOSE_FILE/, 'recognizing its own earlier run only by this config file');
  // `docker compose ls` is the one verb that takes no file: it is the read-only listing the
  // name-clash guard asks, and it can touch nothing. Every other invocation still names the file.
  const composeInvocations = (throwaway.replace(/^\s*#.*$/gm, '').match(/docker compose[^\n]*/g) ?? [])
    .filter((invocation) => !/^docker compose ls\b/.test(invocation.trim()));
  assert.ok(
    !/docker compose\s+(?!ls\b)(-f\s+)?(?!.*\$COMPOSE_FILE)/.test(throwaway.replace(/^\s*#.*$/gm, '')),
    'every docker compose invocation names the generated compose file'
  );
  for (const invocation of composeInvocations) {
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

test("the throwaway's port and name are one fact, not six declarations of one", () => {
  // 52776 was written independently in five places -- ci-throwaway.sh's WEB_PORT default, the
  // wait-readiness gate string, the browser job's `env:`, browser.config.mjs's DEFAULT_ORIGIN
  // and this file's DECLARED_GATES -- and nothing held any two of them equal. `runCommands()`
  // reads only `run:` lines, so the `env:` one was pinned by nothing at all. Changing the
  // throwaway's default leaves `npm test` green and breaks a job whose first run is the owner's.
  // The admin-spec drift gate's `--origin` is the sixth.
  //
  // Mutation (Rule 19): change WEB_PORT in ci-throwaway.sh, or the port in either the
  // wait-readiness gate, the admin-spec gate, the `env:` line or browser.config.mjs -> this goes
  // red naming the pair.
  const throwaway = withoutShellComments(readFileSync(join(REPO_ROOT, 'scripts', 'ci-throwaway.sh'), 'utf8'));
  const browserConfig = readFileSync(join(REPO_ROOT, 'ui', 'browser.config.mjs'), 'utf8');

  const webPort = /^WEB_PORT="(\d+)"/m.exec(throwaway);
  assert.ok(webPort, 'ci-throwaway.sh declares a WEB_PORT default');
  const port = webPort[1];

  const waitGate = DECLARED_GATES.find((gate) => gate.startsWith('sh scripts/wait-readiness.sh'));
  assert.ok(waitGate, 'a wait-readiness gate is declared');
  assert.match(waitGate, new RegExp(`localhost:${port}/`), `the readiness gate waits on the throwaway's own port ${port}`);

  const adminSpecGate = DECLARED_GATES.find((gate) => gate.startsWith('node tools/admin-spec.mjs'));
  assert.ok(adminSpecGate, 'an admin-spec drift gate is declared');
  assert.match(
    adminSpecGate,
    new RegExp(`--origin http://localhost:${port}$`),
    `the admin-spec gate reads the throwaway's own port ${port}`
  );

  // Since 2026-09-22 there are TWO throwaways: the instance job keeps ci-throwaway.sh's default
  // pair, and the browser job passes its own on the command line so the two suites can run side
  // by side. That does not weaken this test's claim -- it doubles it. The browser job's port and
  // container are still one fact each, declared once on the `up` line and read back everywhere
  // else, and the `env:` pair is still the part `runCommands()` cannot see.
  const browserUp = DECLARED_GATES.find((gate) => gate.startsWith('sh scripts/ci-throwaway.sh up --dir'));
  assert.ok(browserUp, 'the browser job declares its own throwaway');
  const browserPort = /--web (\d+)/.exec(browserUp);
  const browserProject = /--project (\S+)/.exec(browserUp);
  assert.ok(browserPort && browserProject, 'that throwaway names its own port and project');
  assert.notEqual(browserPort[1], port, 'and it is a different port from the instance throwaway, or the two jobs collide');

  const browserWait = DECLARED_GATES.find((gate) => gate.startsWith('sh scripts/wait-readiness.sh') && gate.includes(browserPort[1]));
  assert.ok(browserWait, `the browser job waits on its own port ${browserPort[1]}`);

  const browserOrigin = /OCUPILOT_BROWSER_ORIGIN:\s*(\S+)/.exec(workflow);
  assert.ok(browserOrigin, "the browser step sets OCUPILOT_BROWSER_ORIGIN -- the one setting runCommands() cannot see");
  assert.equal(browserOrigin[1], `http://localhost:${browserPort[1]}`, "the browser step drives its own throwaway's port");

  // Both variables or neither: browser.config.mjs carries its own container default, so a step
  // that overrides only the origin execs into the OTHER throwaway's container (2026-09-16).
  const browserContainer = /OCUPILOT_BROWSER_CONTAINER:\s*(\S+)/.exec(workflow);
  assert.ok(browserContainer, 'the browser step sets OCUPILOT_BROWSER_CONTAINER beside the origin');
  assert.equal(browserContainer[1], browserProject[1], "and it names its own throwaway, whose container_name follows --project");

  // The reservation covers both ports, or DW-439 simply moves to the new one.
  const reserve = DECLARED_GATES.find((gate) => gate.startsWith('sudo sysctl -w net.ipv4.ip_local_reserved_ports='));
  assert.ok(reserve, 'the throwaway host ports are reserved against the ephemeral range (DW-439)');
  for (const reserved of [port, browserPort[1]]) {
    assert.match(reserve, new RegExp(`(=|,)${reserved}(,|$)`), `the reservation covers ${reserved}`);
  }

  const defaultOrigin = /DEFAULT_ORIGIN = '([^']+)'/.exec(browserConfig);
  assert.ok(defaultOrigin, 'browser.config.mjs declares a DEFAULT_ORIGIN');
  assert.equal(defaultOrigin[1], `http://localhost:${port}`, "the harness's default origin is the throwaway's own port");
  assert.ok(!/52774|:1973/.test(defaultOrigin[1]), 'and never the live container');

  const project = /^PROJECT="([^"]+)"/m.exec(throwaway);
  assert.ok(project, 'ci-throwaway.sh declares a PROJECT default');

  // The images job's throwaway (Story 8.9) is the third, and its facts are held the same way: its
  // port is declared once on its `up` line and read back by the reservation, the readiness wait and
  // the admin-spec origin; its project is the container smoke names and the project the teardown
  // removes; and it installs the edition the matrix names, which is the point of the leg.
  //
  // Mutation (Rule 19): delete the images job's admin-spec step -> this goes red.
  const images = jobSlice(workflow, 'images');
  const imagesRuns = runCommands(images);
  const imagesUp = imagesRuns.find((command) => command.startsWith('sh scripts/ci-throwaway.sh up'));
  assert.ok(imagesUp, 'the images job brings up a throwaway of its own');
  const imagesPort = /--web (\d+)/.exec(imagesUp);
  const imagesProject = /--project (\S+)/.exec(imagesUp);
  assert.ok(imagesPort && imagesProject, 'that throwaway names its own port and project');
  assert.ok(![port, browserPort[1]].includes(imagesPort[1]), 'on a port neither other throwaway uses');
  assert.notEqual(imagesProject[1], project[1], 'under a project the instance throwaway does not use');
  assert.notEqual(imagesProject[1], browserProject[1], 'nor the browser throwaway');
  assert.match(imagesUp, / --image \$\{\{ matrix\.image \}\}$/, 'installing the edition this leg of the matrix names');
  assert.match(reserve, new RegExp(`(=|,)${imagesPort[1]}(,|$)`), `the reservation covers ${imagesPort[1]}`);
  for (const job of ['instance', 'browser', 'images']) {
    const reserved = runCommands(jobSlice(workflow, job)).find((command) => command.startsWith('sudo sysctl -w net.ipv4.ip_local_reserved_ports='));
    assert.equal(reserved, reserve, `the ${job} job reserves the same three ports as every other job`);
  }
  assert.ok(
    imagesRuns.includes(`sh scripts/wait-readiness.sh --url http://localhost:${imagesPort[1]}/api/ocupilot/readiness/`),
    `the images job waits on its own port ${imagesPort[1]}`
  );
  assert.ok(
    imagesRuns.includes(`node tools/admin-spec.mjs --origin http://localhost:${imagesPort[1]}`),
    `the images job drift-checks /api/admin on its own port ${imagesPort[1]} (AC3)`
  );
  const imagesSmoke = imagesRuns.find((command) => command.startsWith('sh scripts/smoke.sh'));
  assert.ok(imagesSmoke, 'the images job smokes the installed edition');
  assert.equal(/--container (\S+)/.exec(imagesSmoke)?.[1], imagesProject[1], "smoke names the images throwaway's container, which follows --project");
  assert.doesNotMatch(imagesSmoke, /--namespace/, "and names no namespace: the fallback to the one the install resolved is what is under test (AC1)");
  const imagesDown = imagesRuns.find((command) => command.startsWith('sh scripts/ci-throwaway.sh down'));
  assert.ok(imagesDown, 'the images job tears its throwaway down');
  assert.equal(/--project (\S+)/.exec(imagesDown)?.[1], imagesProject[1], 'the teardown removes the project the bring-up created');
  const imagesDir = /--dir (\S+)/.exec(imagesUp)?.[1];
  assert.ok(imagesDir, 'the bring-up names its own directory');
  for (const command of [imagesDown, imagesRuns.find((run) => run.startsWith('sh scripts/ci-throwaway.sh logs'))]) {
    assert.equal(/--dir (\S+)/.exec(command ?? '')?.[1], imagesDir, `"${command}" names the directory the bring-up wrote`);
  }

  for (const gate of DECLARED_GATES) {
    const named = /--container (\S+)/.exec(gate);
    if (named === null) continue;
    // Each `--container` names the throwaway its own job created: the images job's smoke names
    // that job's project, held above, and every other one names the default.
    if (gate === imagesSmoke) continue;
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
  // depends_on condition, the demo opt-in flag or any durable-init key in either file alone ->
  // this goes red naming it.
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
    // Story 5.8: the `instance` job's smoke run now executes two checks that exist only where the
    // demo fixture does (`agentwrite`, `auditmarker`), so the flag that creates `/csp/myapp` is
    // load-bearing for the gate and not only for the walkthrough. It was pinned by nothing --
    // this comparison reads the service blocks and skipped the `environment:` block entirely --
    // so dropping it from the throwaway would have turned two executed checks into two skips with
    // every other gate green.
    ['demo opt-in flag', 'iris', /OCUPILOT_DEMO:\s*(\S+)/],
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

// --- The arming rosters (DW-1276) ------------------------------------------------------------

/**
 * The arming variables `ci-throwaway.sh` sets, each with the classes its comment block declares.
 *
 * A block declares its classes on `# classes:` lines, in `OcuPilot.Test.*` short form, so the
 * roster is read from a shape rather than from English prose -- half the test package's class
 * names are also ordinary words (`State`, `Version`, `Token`, `Static`, `Wire`), and a prose scan
 * would read every one of them as a citation.
 */
export function declaredArmingRosters(source) {
  const rosters = [];
  let pending = [];
  for (const line of source.split('\n')) {
    const named = /^\s*#\s*classes:\s*(.+?)\s*$/.exec(line);
    if (named !== null) {
      pending.push(...named[1].split(',').map((name) => name.trim()).filter((name) => name !== ''));
      continue;
    }
    const setting = /^\s*(OCUPILOT_ALLOW_[A-Z_]+):\s*"1"\s*$/.exec(line);
    if (setting !== null) {
      rosters.push({ variable: setting[1], classes: [...new Set(pending)].sort() });
      pending = [];
      continue;
    }
    if (/^\s*#/.test(line)) continue;
    pending = [];
  }
  return rosters;
}

/**
 * Every `.cls` under a directory, as `{shortName, code}` with comments removed -- `///` class
 * documentation and `;` in-method comments alike. Stripping only the first would leave the
 * derivation's own stated property ("a mention in a comment is not an arming declaration") true
 * of one comment form and false of the other, which is the substring trap under a new spelling.
 */
function testClassSources(root, prefix = '') {
  const classes = [];
  for (const entry of readdirSync(root, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
    const full = join(root, entry.name);
    if (entry.isDirectory()) {
      classes.push(...testClassSources(full, `${prefix}${entry.name}.`));
      continue;
    }
    if (!entry.name.endsWith('.cls')) continue;
    const code = readFileSync(full, 'utf8')
      .split('\n')
      .filter((line) => !line.trimStart().startsWith('///') && !line.trimStart().startsWith(';'))
      .join('\n');
    classes.push({ shortName: `${prefix}${entry.name.slice(0, -4)}`, code });
  }
  return classes;
}

/** The variables this roster is about. Both sides of the equality are filtered through it. */
export const ARMING_VARIABLE_RE = /^OCUPILOT_ALLOW_[A-Z_]+$/;

/**
 * Which classes under `src/OcuPilot/Test/` STRUCTURALLY declare each arming variable: any
 * `Parameter` whose VALUE is an arming variable, or an inline `$System.Util.GetEnviron` read of
 * one. Doc comments are removed first.
 *
 * The variable comes from the value, never from an allowlist of parameter names: a class armed
 * through a spelling no list anticipated would otherwise be absent from this side, and the roster
 * comment would then be required not to name it while the class stayed armed -- the same
 * substring-versus-structure trap one level up. A variable that is not an arming variable is not
 * a member either, so both sides describe one population.
 *
 * Structural, never a substring scan over the file. `Test/SwitchesWire.cls` names
 * `OCUPILOT_ALLOW_PRINCIPALS` in a doc comment and is not armed by it, so `grep -l` counts 23
 * where the population is 22 -- the counted-by-substring pitfall this repository records.
 */
export function armedClasses(testRoot) {
  const armed = new Map();
  const add = (variable, shortName) => {
    if (!ARMING_VARIABLE_RE.test(variable)) return;
    if (!armed.has(variable)) armed.set(variable, new Set());
    armed.get(variable).add(shortName);
  };
  for (const { shortName, code } of testClassSources(testRoot)) {
    for (const m of code.matchAll(/Parameter\s+[A-Za-z][A-Za-z0-9]*\s*=\s*"([^"]+)"/g)) {
      add(m[1], shortName);
    }
    for (const m of code.matchAll(/\$System\.Util\.GetEnviron\("([^"]+)"\)/gi)) {
      add(m[1], shortName);
    }
  }
  return armed;
}

test("DW-1276: each arming roster names exactly the classes that declare that variable", () => {
  // The rosters had drifted in every direction at once: PRINCIPALS carried two overlapping lists
  // with no joining sentence and named 13 of 22, PRODUCTION_INSTALL said "twelve" and omitted
  // two, AUDIT_EVENTS named one of two, ERROR_SEED one of six and TEST_PROVIDER three of ten. A
  // comment nothing holds equal is a comment that stops being true the first time a class moves.
  //
  // Mutation (Rule 19): remove UninstallSurvival from the OCUPILOT_ALLOW_AUDIT_EVENTS block ->
  // red naming it. Add SwitchesWire to the PRINCIPALS block -> red naming it, because it mentions
  // the variable in a doc comment and is not armed by it.
  const source = readFileSync(join(REPO_ROOT, 'scripts', 'ci-throwaway.sh'), 'utf8');
  const declared = declaredArmingRosters(source);
  const derived = armedClasses(join(REPO_ROOT, 'src', 'OcuPilot', 'Test'));

  assert.deepEqual(
    declared.map((roster) => roster.variable).sort(),
    [...derived.keys()].sort(),
    'the variables the throwaway arms and the variables the suite declares are the same set'
  );
  assert.ok(declared.length >= 7, `expected at least seven arming variables, found ${declared.length}`);

  for (const { variable, classes } of declared) {
    const structural = [...(derived.get(variable) ?? [])].sort();
    assert.ok(structural.length > 0, `${variable} is declared by at least one class`);
    assert.deepEqual(
      classes,
      structural,
      `${variable}'s roster comment in ci-throwaway.sh and the classes that declare it have diverged.\n` +
        `comment: ${JSON.stringify(classes)}\nsource:  ${JSON.stringify(structural)}`
    );
  }
});

test('DW-1276: a doc-comment mention is not an arming declaration', () => {
  // The structural derivation's one load-bearing property, asserted on the file that has the
  // property: `Test/SwitchesWire.cls` names OCUPILOT_ALLOW_PRINCIPALS in a `///` comment.
  const path = join(REPO_ROOT, 'src', 'OcuPilot', 'Test', 'SwitchesWire.cls');
  const raw = readFileSync(path, 'utf8');
  assert.ok(raw.includes('OCUPILOT_ALLOW_PRINCIPALS'), 'the file mentions the variable');
  const derived = armedClasses(join(REPO_ROOT, 'src', 'OcuPilot', 'Test'));
  assert.ok(
    !derived.get('OCUPILOT_ALLOW_PRINCIPALS').has('SwitchesWire'),
    'and is not counted as arming it, which a grep -l would'
  );
});

test('DW-1276: neither comment form is an arming declaration', () => {
  // The property is asserted on the tree for `///` by the test above. ObjectScript has a second
  // comment form -- `;` inside a method body -- and the derivation stripped only the first, so
  // the stated property held for one spelling and not the other. No file carries such a comment
  // today, which is exactly why it needs pinning here rather than being noticed later.
  //
  // Mutation (Rule 19): drop the `;` clause from testClassSources' filter -> this goes red.
  const root = mkdtempSync(join(tmpdir(), 'ocupilot-arming-comments-'));
  try {
    writeFileSync(
      join(root, 'CommentOnly.cls'),
      [
        'Class OcuPilot.Test.CommentOnly Extends %UnitTest.TestCase',
        '{',
        'Method TestSomething()',
        '{',
        '    ; OCUPILOT_ALLOW_PRINCIPALS is what SwitchesWire would arm on; this class does not.',
        '    ; $System.Util.GetEnviron("OCUPILOT_ALLOW_PRINCIPALS") is not called here.',
        '    Quit',
        '}',
        '}',
      ].join('\n')
    );
    writeFileSync(
      join(root, 'ReallyArmed.cls'),
      [
        'Class OcuPilot.Test.ReallyArmed Extends %UnitTest.TestCase',
        '{',
        'Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";',
        '}',
      ].join('\n')
    );
    const derived = armedClasses(root);
    assert.deepEqual([...(derived.get('OCUPILOT_ALLOW_PRINCIPALS') ?? [])].sort(), ['ReallyArmed']);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

// --- The bounded bind retry (DW-439) ---------------------------------------------------------

/** Run `ci-throwaway.sh up` against a stub docker that fails `up` a given number of times. */
function runThrowawayUp({ fails, message, retrySeconds = '0' }) {
  const dir = mkdtempSync(join(tmpdir(), 'ocupilot-throwaway-bind-'));
  const bin = join(dir, 'bin');
  const scratch = join(dir, 'scratch');
  const capture = join(dir, 'docker-argv.txt');
  const counter = join(dir, 'up-count.txt');
  mkdirSync(bin);
  writeStub(bin, 'docker', [
    'printf \'%s\\n\' "$*" >> "$OCUPILOT_DOCKER_CAPTURE"',
    'case "$*" in',
    '  *"up -d --wait"*)',
    '    n=$(cat "$OCUPILOT_UP_COUNT" 2>/dev/null || echo 0)',
    '    n=$((n + 1))',
    '    printf \'%s\' "$n" > "$OCUPILOT_UP_COUNT"',
    '    if [ "$n" -le "$OCUPILOT_UP_FAILS" ]; then',
    '      printf \'%s\\n\' "$OCUPILOT_UP_MESSAGE" >&2',
    '      exit 1',
    '    fi',
    '    ;;',
    'esac',
    'for arg in "$@"; do',
    '  case "$arg" in',
    '    *:/scratch) target="${arg%:/scratch}"; chmod -R u+rwx "$target/data" 2>/dev/null; rm -rf "$target/data" ;;',
    '  esac',
    'done',
    'exit 0',
  ]);
  try {
    const run = spawnSync('sh', [join(REPO_ROOT, 'scripts', 'ci-throwaway.sh'), 'up', '--dir', scratch], {
      cwd: REPO_ROOT,
      encoding: 'utf8',
      env: stubEnv(bin, {
        OCUPILOT_DOCKER_CAPTURE: capture,
        OCUPILOT_UP_COUNT: counter,
        OCUPILOT_UP_FAILS: String(fails),
        OCUPILOT_UP_MESSAGE: message,
        // The retry's growing wait. Callers that only care about the retry count or the final
        // status pass the default '0' to keep the run fast; the backoff test below overrides it
        // to observe the wait actually elapsing.
        OCUPILOT_BIND_RETRY_SECONDS: retrySeconds,
      }),
    });
    const argv = existsSync(capture) ? readFileSync(capture, 'utf8') : '';
    return {
      status: run.status,
      output: `${run.stdout}${run.stderr}`,
      ups: (argv.match(/up -d --wait/g) ?? []).length,
      downs: (argv.match(/down -v/g) ?? []).length,
    };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

const BIND_MESSAGE =
  'Error response from daemon: driver failed programming external connectivity on endpoint ocupilot-ci: Bind for 0.0.0.0:52776 failed: port is already allocated';

test('DW-439: a bring-up that failed on a host-port bind is retried, and succeeds', () => {
  // 52776 sits inside the range a Linux runner allocates outbound source ports from (the kernel
  // default is 32768-60999); 1975 is an order of magnitude below that floor, so only the web port
  // is at risk from an ephemeral allocation, and the superserver port only from another listener.
  // Either way a transient occupant kills the instance job before a test runs. Moving the ports is
  // not the fix -- CLAUDE.md, _bmad/custom/parallel.yaml and every parallel runner's spawn prompt
  // carry them -- so the bind is retried, and only the bind.
  //
  // Mutation (Rule 19): delete the retry loop -> this goes red at the first failure.
  const run = runThrowawayUp({ fails: 2, message: BIND_MESSAGE });
  assert.equal(run.status, 0, `expected the third attempt to succeed: ${run.output}`);
  assert.equal(run.ups, 3, 'three bring-up attempts');
  assert.equal(run.downs, 2, 'with this project\'s containers removed between them');
});

test('DW-439: a bind that never clears exits naming the port and the measured ephemeral range', () => {
  // Mutation (Rule 19): make the loop unbounded -> this never returns; drop the port or the
  // range from the exhaustion message -> the matching assertion goes red.
  const run = runThrowawayUp({ fails: 99, message: BIND_MESSAGE });
  assert.notEqual(run.status, 0, 'an exhausted retry is a failure');
  assert.equal(run.ups, 3, 'bounded at three attempts, so a deterministic bind cannot loop');
  assert.match(run.output, /52776/, 'the message names the port');
  assert.match(run.output, /ephemeral port range/, 'and the range this runner allocates from');
});

test('DW-439: the retry waits between attempts, and the wait is overridable', () => {
  // Three cycles back to back would ask for the port again well inside the seconds a transient
  // occupant holds it for, so the retry as written would have survived only an occupant that
  // cleared within the teardown's own duration.
  //
  // Mutation (Rule 19): delete the sleep, or the OCUPILOT_BIND_RETRY_SECONDS default -> red.
  const source = withoutShellComments(readFileSync(join(REPO_ROOT, 'scripts', 'ci-throwaway.sh'), 'utf8'));
  assert.match(source, /BIND_RETRY_SECONDS="\$\{OCUPILOT_BIND_RETRY_SECONDS:-[1-9]\d*\}"/, 'a non-zero default, overridable by the environment');
  assert.match(source, /sleep \$\(\(BIND_RETRY_SECONDS \* ATTEMPT\)\)/, 'and the wait grows with the attempt');
});

test('DW-439: the bring-up is streamed, and its exit code read back beside the text', () => {
  // A captured bring-up printed nothing until it finished, so a `--wait` that hung until the job
  // was cancelled showed an empty log -- the situation this retry exists for. POSIX sh has no
  // PIPESTATUS, so the code goes to a file inside the pipeline.
  //
  // Mutation (Rule 19): put `UP_OUTPUT=$(docker compose ... up -d --wait 2>&1)` back -> red.
  const source = withoutShellComments(readFileSync(join(REPO_ROOT, 'scripts', 'ci-throwaway.sh'), 'utf8'));
  assert.match(source, /\{ docker compose -f "\$COMPOSE_FILE" up -d --wait 2>&1; echo "\$\?" > "\$UP_RC_FILE"; \} \| tee "\$UP_OUTPUT_FILE"/);
  assert.doesNotMatch(source, /UP_OUTPUT=\$\(docker compose/, 'the bring-up is never captured instead of streamed');
});

test('DW-439: a failure that is not a host-port bind exits at once, unretried', () => {
  // The half that keeps the retry from turning one clear error into three and then a misleading
  // one about a port.
  //
  // Mutation (Rule 19): delete the bind-message guard so it retries on any failure -> this goes
  // red with three attempts instead of one.
  const run = runThrowawayUp({ fails: 99, message: 'Error response from daemon: pull access denied for intersystems/irishealth-community' });
  assert.notEqual(run.status, 0, 'still a failure');
  assert.equal(run.ups, 1, 'and only one attempt was made');
  assert.equal(run.downs, 0, 'with nothing torn down in between');
  assert.match(run.output, /not a host-port bind/, 'saying which of the two it is');
});

test('DW-439: the retry actually waits, and the second wait outlasts the first', () => {
  // The two tests above pin the SHAPE of the backoff by reading the source text -- a non-zero,
  // overridable default and a `sleep` keyed to `ATTEMPT`. Neither one runs the script and watches
  // a clock, so a change that keeps both regexes matching but breaks the growth (a stray
  // `ATTEMPT=1` reset between attempts, or a `$((BIND_RETRY_SECONDS))` that drops the
  // multiplication) would still pass them. This drives the real retry with `OCUPILOT_BIND_RETRY_SECONDS`
  // set to a real, small, non-zero value and asserts on the wall-clock elapsed, which is what
  // downstream users actually experience.
  //
  // Mutation (Rule 19): replace `sleep $((BIND_RETRY_SECONDS * ATTEMPT))` with a constant
  // `sleep $BIND_RETRY_SECONDS` -> the elapsed floor below (which needs the SECOND wait to be
  // longer than the first, i.e. growth) goes red while the two source-text tests above stay green.
  const start = Date.now();
  const run = runThrowawayUp({ fails: 2, message: BIND_MESSAGE, retrySeconds: '1' });
  const elapsedMs = Date.now() - start;
  assert.equal(run.status, 0, `expected the third attempt to succeed: ${run.output}`);
  assert.equal(run.ups, 3, 'three bring-up attempts');
  // Attempt 1's wait is BIND_RETRY_SECONDS*1 = 1s, attempt 2's is BIND_RETRY_SECONDS*2 = 2s: the
  // two real sleeps sum to at least 3s. A flat (non-growing) 1s-per-attempt backoff would total
  // only ~2s, so this floor distinguishes growth from a fixed wait as well as from no wait at all.
  assert.ok(elapsedMs >= 2900, `expected at least ~3s of growing backoff (1s + 2s), took ${elapsedMs}ms`);
});

test('DW-439: the bring-up streams output as it happens, never only at exit', () => {
  // The regex test above pins the exit-code-to-file-plus-`tee` SHAPE in the source. It cannot
  // observe whether output actually arrives while the command is still running, which is the one
  // property DW-439 is about: a `--wait` that hangs until the job is cancelled must still have
  // shown something on screen. This drives the real script asynchronously against a stub that
  // prints a marker and then sleeps, and asserts the marker reaches this process's stdout well
  // before the stub's sleep (and so the whole command) completes.
  //
  // Mutation (Rule 19): revert to `UP_OUTPUT=$(docker compose ... up -d --wait 2>&1)` (a captured,
  // unstreamed form) -> the marker is buffered until the child exits, so it arrives only after the
  // full sleep, and the "well before" assertion below goes red while the regex test stays green
  // only if the reverted line still happened to match a stale pattern -- here it is read from
  // observed timing, not text, so it cannot pass by accident.
  const dir = mkdtempSync(join(tmpdir(), 'ocupilot-throwaway-stream-'));
  const bin = join(dir, 'bin');
  const scratch = join(dir, 'scratch');
  const SLEEP_MS = 2000;
  const MARKER = 'OCUPILOT_STREAM_MARKER';
  mkdirSync(bin);
  writeStub(bin, 'docker', [
    'case "$*" in',
    `  *"up -d --wait"*)`,
    `    printf '%s\\n' '${MARKER}'`,
    `    sleep ${SLEEP_MS / 1000}`,
    '    exit 0',
    '    ;;',
    'esac',
    'exit 0',
  ]);
  return new Promise((resolve, reject) => {
    const start = Date.now();
    let markerAtMs = null;
    const child = spawn('sh', [join(REPO_ROOT, 'scripts', 'ci-throwaway.sh'), 'up', '--dir', scratch], {
      cwd: REPO_ROOT,
      env: stubEnv(bin, { OCUPILOT_BIND_RETRY_SECONDS: '0' }),
    });
    child.stdout.on('data', (chunk) => {
      if (markerAtMs === null && chunk.toString().includes(MARKER)) markerAtMs = Date.now() - start;
    });
    child.on('error', reject);
    child.on('close', (code) => {
      const closeAtMs = Date.now() - start;
      try {
        rmSync(dir, { recursive: true, force: true });
        assert.equal(code, 0, 'the bring-up itself still succeeds');
        assert.ok(markerAtMs !== null, 'the marker line reached this process\'s stdout at all');
        // Measured against the child's OWN exit, not against an absolute budget from `spawn`.
        // Node's spawn, `sh` startup, the compose-file write and `rm_durable` all sit between
        // `start` and the stub's first line, and on a loaded three-band matrix that overhead is
        // unbounded -- a fixed budget would read "output was not streamed" when the runner was
        // merely busy. The overhead shifts marker and close together, so their DISTANCE is the
        // streamed-versus-captured property: streamed, the marker leads the close by the stub's
        // whole sleep; captured, both arrive together.
        assert.ok(
          closeAtMs - markerAtMs > SLEEP_MS / 2,
          `expected the marker at least ${SLEEP_MS / 2}ms before the bring-up finished (streamed); ` +
            `observed the marker at ${markerAtMs}ms and the close at ${closeAtMs}ms (captured would put them together)`
        );
        resolve();
      } catch (err) {
        reject(err);
      }
    });
  });
});

// --- The named failing checks (DW-1079) ------------------------------------------------------

/** Run `smoke.sh` against a stub `iris` that prints `report` between the script's own markers. */
function runSmokeOverReport(report, verdict = 'FAIL') {
  const dir = mkdtempSync(join(tmpdir(), 'ocupilot-smoke-report-'));
  try {
    const stub = join(dir, 'iris');
    // Inline, and with RUNNER empty, the shape the two credential-guard tests above use: the stub
    // is the whole instance, and nothing reads /proc/1/environ.
    writeFileSync(
      stub,
      [
        '#!/bin/sh',
        'cat > /dev/null',
        'printf \'%s\\n\' "OCUPILOT-SMOKE-REPORT-START:"',
        'printf \'%s\\n\' "$OCUPILOT_SMOKE_REPORT"',
        'printf \'%s\\n\' "OCUPILOT-SMOKE-VERDICT-START:$OCUPILOT_SMOKE_VERDICT:OCUPILOT-SMOKE-VERDICT-END"',
        'exit 0',
        '',
      ].join('\n')
    );
    chmodSync(stub, 0o755);
    const run = spawnSync(
      '/bin/sh',
      [join(REPO_ROOT, 'scripts', 'smoke.sh'), '--demo', '0', '--namespace', 'HSCUSTOM'],
      {
        cwd: REPO_ROOT,
        encoding: 'utf8',
        env: {
          ...process.env,
          PATH: `${dir}:${process.env.PATH ?? ''}`,
          OCUPILOT_SMOKE_REPORT: report,
          OCUPILOT_SMOKE_VERDICT: verdict,
        },
      }
    );
    return { status: run.status, output: `${run.stdout}${run.stderr}` };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

/** One report row in the form OcuPilot.Install.Smoke renders: two spaces, the outcome padded to nine, the name. */
function reportRow(outcome, name, reason = '') {
  return `  ${`${outcome}         `.slice(0, 9)}${name}${reason === '' ? '' : ` -- ${reason}`}`;
}

test('DW-1079: a failing smoke run names every failing check on one quotable line', () => {
  // The line said only "the failing check is named above", which in a CI log is an
  // unattributable red -- and the class-side line names only the first of several. Mutation
  // (Rule 19): drop the name from the quotable line, or narrow the awk to the first row -> this
  // goes red on the missing name.
  const report = [
    'ocupilot-smoke: docker exec ocupilot-ci',
    reportRow('pass', 'readiness'),
    reportRow('fail', 'wallet', 'the demo wallet collection is absent on a demo-enabled instance'),
    reportRow('skipped', 'signin'),
    reportRow('fail', 'demofixture', 'the demo agent definition is absent'),
    'ocupilot-smoke: executed=3 passed=1 failed=2 pending=0 skipped=1',
    'ocupilot-smoke: FAILED -- 2 check(s) failed; the first is named above',
  ].join('\n');
  const run = runSmokeOverReport(report);
  assert.equal(run.status, 1, `a failing smoke run exits non-zero: ${run.output}`);
  assert.match(run.output, /^smoke: FAILED check\(s\): wallet, demofixture$/m, run.output);
  assert.doesNotMatch(run.output, /^smoke: FAILED check\(s\):[^\n]*readiness/m, 'and names no check that passed');
  assert.doesNotMatch(run.output, /^smoke: FAILED check\(s\):[^\n]*signin/m, 'nor one that was skipped');
});

test('DW-1079: a failure the row parser cannot name is reported as missing, not passed over', () => {
  // The criterion is that the line names EVERY failing check. `Smoke.Render` fails closed on an
  // outcome outside the four it writes -- it counts the row as a failure -- and such a row
  // carries that outcome in $1, so the awk cannot see it. Without holding the named count equal
  // to the class's own `failed=`, a line naming one of two failures reads exactly like a
  // complete one.
  //
  // Mutation (Rule 19): delete the COUNTED/NAMED comparison from smoke.sh -> this goes red while
  // the two-failure case above stays green.
  const report = [
    'ocupilot-smoke: docker exec ocupilot-ci',
    reportRow('fail', 'wallet', 'the demo wallet collection is absent'),
    reportRow('faild', 'mistyped', 'an outcome outside the four the class writes'),
    'ocupilot-smoke: executed=2 passed=0 failed=2 pending=0 skipped=0',
    'ocupilot-smoke: FAILED -- 2 check(s) failed; the first is named above',
  ].join('\n');
  const run = runSmokeOverReport(report);
  assert.equal(run.status, 1, run.output);
  assert.match(run.output, /^smoke: FAILED check\(s\): wallet$/m, run.output);
  assert.match(run.output, /^smoke: the report counted 2 failure\(s\) and 1 could be named/m, run.output);
});

test('DW-1079: a report whose failures are all named says nothing about a shortfall', () => {
  const report = [
    'ocupilot-smoke: docker exec ocupilot-ci',
    reportRow('fail', 'wallet'),
    'ocupilot-smoke: executed=1 passed=0 failed=1 pending=0 skipped=0',
    'ocupilot-smoke: FAILED -- 1 check(s) failed; the first is named above',
  ].join('\n');
  const run = runSmokeOverReport(report);
  assert.match(run.output, /^smoke: FAILED check\(s\): wallet$/m, run.output);
  assert.doesNotMatch(run.output, /could be named/, 'the complete case stays one line');
});

test('DW-1079: a FAIL verdict with no parseable row still says the run did not pass', () => {
  const run = runSmokeOverReport(['ocupilot-smoke: docker exec ocupilot-ci', 'ocupilot-smoke: executed=0'].join('\n'));
  assert.equal(run.status, 1);
  assert.match(run.output, /smoke: the instance did not pass/, 'the fallback sentence, rather than an empty list');
});

// --- The install namespace smoke falls back to (Story 8.9) -----------------------------------

/**
 * Run `smoke.sh` against a stub `iris` that plays the instance's namespace answer.
 *
 * A session opened in `%SYS` is the namespace probe: the stub answers it with
 * `OCUPILOT_STUB_NS_FLAGS` (`<HSCUSTOM exists>,<USER exists>`). Any other session is the report
 * run, answered with a passing verdict. Every session's `-U` argument is recorded in order, so a
 * leg reads which sessions ran and in which namespace. `OCUPILOT_NAMESPACE` is removed from the
 * environment unless the leg supplies it, since with no container named the script reads it from
 * this process's own environment.
 */
function runSmokeResolving(flags, argv, extraEnv = {}) {
  const dir = mkdtempSync(join(tmpdir(), 'ocupilot-smoke-namespace-'));
  try {
    const sessions = join(dir, 'sessions.txt');
    const stub = join(dir, 'iris');
    writeFileSync(
      stub,
      [
        '#!/bin/sh',
        'printf \'%s\\n\' "$4" >> "$OCUPILOT_STUB_SESSIONS"',
        'cat > /dev/null',
        'if [ "$4" = "%SYS" ]; then',
        '  printf \'%s\\n\' "OCUPILOT-SMOKE-NS-START:$OCUPILOT_STUB_NS_FLAGS:OCUPILOT-SMOKE-NS-END"',
        '  exit 0',
        'fi',
        'printf \'%s\\n\' "OCUPILOT-SMOKE-REPORT-START:"',
        'printf \'%s\\n\' "  pass     readiness"',
        'printf \'%s\\n\' "OCUPILOT-SMOKE-VERDICT-START:PASS:OCUPILOT-SMOKE-VERDICT-END"',
        'exit 0',
        '',
      ].join('\n')
    );
    chmodSync(stub, 0o755);
    const env = { ...process.env };
    delete env.OCUPILOT_NAMESPACE;
    const run = spawnSync('/bin/sh', [join(REPO_ROOT, 'scripts', 'smoke.sh'), '--demo', '0', ...argv], {
      cwd: REPO_ROOT,
      encoding: 'utf8',
      env: {
        ...env,
        ...extraEnv,
        PATH: `${dir}:${process.env.PATH ?? ''}`,
        OCUPILOT_STUB_SESSIONS: sessions,
        OCUPILOT_STUB_NS_FLAGS: flags,
      },
    });
    const opened = existsSync(sessions) ? readFileSync(sessions, 'utf8').split('\n').filter((line) => line !== '') : [];
    return { status: run.status, output: `${run.stdout}${run.stderr}`, sessions: opened };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test('Story 8.9 AC1: with no --namespace, smoke runs in USER on an instance that has USER and no HSCUSTOM', () => {
  // The defect the plain-Community probe found: the fallback was a literal HSCUSTOM, so on the
  // stock plain image smoke opened a session in a namespace that does not exist and answered
  // "Access Denied" with no verdict.
  //
  // Mutation (Rule 19): restore `NAMESPACE="HSCUSTOM"` as the fallback -> this goes red on the
  // report session's namespace.
  const run = runSmokeResolving('0,1', []);
  assert.equal(run.status, 0, run.output);
  assert.deepEqual(run.sessions, ['%SYS', 'USER'], 'the namespace is asked in %SYS, then the report runs in USER');

  const both = runSmokeResolving('1,1', []);
  assert.equal(both.status, 0, both.output);
  assert.deepEqual(both.sessions, ['%SYS', 'HSCUSTOM'], 'and HSCUSTOM wins where it exists, as the install resolves it');
});

test('Story 8.9: an instance with neither HSCUSTOM nor USER is refused by name, and no report session opens', () => {
  const run = runSmokeResolving('0,0', []);
  assert.equal(run.status, 1, run.output);
  assert.match(run.output, /HSCUSTOM/, 'the refusal names HSCUSTOM');
  assert.match(run.output, /USER/, 'and USER');
  assert.deepEqual(run.sessions, ['%SYS'], 'and only the probe session ran');

  const silent = runSmokeResolving('', []);
  assert.equal(silent.status, 1, `an instance that gave no answer is not a pass: ${silent.output}`);
  assert.deepEqual(silent.sessions, ['%SYS'], 'and no report session opens over a guess');
});

test('Story 8.9: --namespace and OCUPILOT_NAMESPACE still name the namespace, with no probe', () => {
  const named = runSmokeResolving('0,1', ['--namespace', 'HSCUSTOM']);
  assert.equal(named.status, 0, named.output);
  assert.deepEqual(named.sessions, ['HSCUSTOM'], 'the named namespace, unchanged from before');

  const fromEnv = runSmokeResolving('0,1', [], { OCUPILOT_NAMESPACE: 'OCUPILOT' });
  assert.equal(fromEnv.status, 0, fromEnv.output);
  assert.deepEqual(fromEnv.sessions, ['OCUPILOT'], 'and the environment override, unchanged from before');
});

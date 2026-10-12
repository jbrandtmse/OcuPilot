import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import { captured, shellsFor, stubEnv, writeStub } from './stub-bin.mjs';

// What scripts/container-start.sh does with each outcome its namespace-resolution session reports
// (Story 18.13, AD-17), executed: the script runs under `sh` and dash with a stub `iris` that
// answers the first session with the outcome under test and records every session it is asked for.
// A refusal exits 1 after that one session and names the namespaces involved, so nothing was
// compiled; an OK carries on to the sessions that follow. The session's own ObjectScript is
// executed against real namespaces by OcuPilot.Test.ContainerStartNamespace.
//
// Needs /bin/sh (and /bin/dash when present); no container, no network.

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const START = join(REPO_ROOT, 'scripts', 'container-start.sh');

/** Run the start script with `outcome` as the first session's answer; the sessions it asked for. */
function runStart(shell, outcome) {
  const dir = mkdtempSync(join(tmpdir(), 'ocupilot-start-outcome-'));
  try {
    const bin = join(dir, 'bin');
    const log = join(dir, 'iris-sessions.log');
    writeStub(bin, 'iris', [
      'echo "$*" >> "$OCUPILOT_TEST_IRIS_LOG"',
      'cat > /dev/null',
      'if [ "$(wc -l < "$OCUPILOT_TEST_IRIS_LOG")" -eq 1 ]; then',
      '  printf "OCUPILOT-NS-START:%s:OCUPILOT-NS-END\\n" "$OCUPILOT_TEST_NS_OUTCOME"',
      '  printf "OCUPILOT-MARK-START:NOCLASS:OCUPILOT-MARK-END\\n"',
      'fi',
      'exit 0',
    ]);
    const run = spawnSync(shell, [START], {
      cwd: REPO_ROOT,
      encoding: 'utf8',
      env: stubEnv(bin, { OCUPILOT_TEST_IRIS_LOG: log, OCUPILOT_TEST_NS_OUTCOME: outcome }),
    });
    return { status: run.status, out: `${run.stdout}${run.stderr}`, sessions: captured(log) };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

// Mutations (Rule 19): delete the `OTHER:*)` branch from the script's `case` -> the first
// assertion goes red; make the branch `exit 0` -> the status assertion goes red; remove its `exit`
// -> the session count goes red, since the start carries on to the load.
test('a second install namespace stops the start after the resolution session, naming both (Story 18.13)', () => {
  for (const shell of shellsFor('sh')) {
    const run = runStart(shell, 'OTHER:HSCUSTOM:USER');
    assert.equal(run.status, 1, `${shell}: the start fails\n${run.out}`);
    assert.match(run.out, /OcuPilot is already installed in the namespace HSCUSTOM/, `${shell}: naming the namespace that holds the install\n${run.out}`);
    assert.match(run.out, /refusing before anything is compiled into USER/, `${shell}: and the one this start resolved\n${run.out}`);
    assert.equal(run.sessions.length, 1, `${shell}: after the resolution session alone, so nothing was loaded or compiled`);
  }
});

// Mutations (Rule 19): make the SYSTEM or MISSING branch fall through to the `*)` arm -> its
// message assertion goes red; remove its `exit 1` -> the session count goes red.
test('a system or missing namespace stops the start after the resolution session (DW-195)', () => {
  const cases = [
    ['SYSTEM:%SYS', /names %SYS, which is a namespace OcuPilot refuses to install into/],
    ['MISSING:NOSUCH', /names the namespace NOSUCH, which does not exist on this instance/],
  ];
  for (const shell of shellsFor('sh')) {
    for (const [outcome, message] of cases) {
      const run = runStart(shell, outcome);
      assert.equal(run.status, 1, `${shell}: ${outcome} fails the start\n${run.out}`);
      assert.match(run.out, message, `${shell}: ${outcome} says why\n${run.out}`);
      assert.equal(run.sessions.length, 1, `${shell}: ${outcome} stops after the resolution session`);
    }
  }
});

// Mutations (Rule 19): make the OK branch exit -> the session count goes red; stop it setting
// INSTALL_NS -> the resolved-namespace assertion goes red.
test('a usable install namespace is resolved and the start goes on to its next session', () => {
  for (const shell of shellsFor('sh')) {
    const run = runStart(shell, 'OK:HSCUSTOM');
    assert.match(run.out, /install namespace resolved to HSCUSTOM/, `${shell}: the namespace is resolved\n${run.out}`);
    assert.ok(run.sessions.length >= 2, `${shell}: and the start asked for a further session, got ${run.sessions.length}`);
  }
});

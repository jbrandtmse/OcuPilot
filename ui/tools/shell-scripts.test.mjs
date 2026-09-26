import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import { captured, declaredShell, shellsFor, stubEnv, writeStub } from './stub-bin.mjs';

// Every shell script this repository runs (DW-229): that each declares `sh` or `bash`, parses under
// that shell (and under dash too for `sh`, which is what `/bin/sh` is on a Linux runner), and that
// three scripts CI's verdict rests on behave as their headers say when executed -- with stub
// `curl`, `sleep`, `docker` and `iris` on PATH, never a network or a container.
//
// Needs `/bin/sh` and `bash`; runs the executing pins under `/bin/dash` as well when it exists.

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

const SCRIPT_FILES = [
  ...readdirSync(join(REPO_ROOT, 'scripts'))
    .filter((name) => name.endsWith('.sh'))
    .map((name) => join('scripts', name)),
  ...readdirSync(join(REPO_ROOT, '.githooks')).map((name) => join('.githooks', name)),
].sort();

function withScratch(prefix, body) {
  const dir = mkdtempSync(join(tmpdir(), prefix));
  try {
    return body(dir);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test('the population is every scripts/*.sh and every .githooks file', () => {
  assert.ok(SCRIPT_FILES.length >= 10, `found ${SCRIPT_FILES.length} shell script(s): ${SCRIPT_FILES.join(', ')}`);
  assert.ok(SCRIPT_FILES.includes(join('.githooks', 'pre-commit')), 'the pre-commit hook is in it');
  assert.ok(SCRIPT_FILES.includes(join('scripts', 'durable-init.sh')), 'and durable-init.sh');
});

test('every shell script declares sh or bash', () => {
  const undeclared = SCRIPT_FILES.filter(
    (file) => declaredShell(readFileSync(join(REPO_ROOT, file), 'utf8')) === null
  );
  assert.deepEqual(undeclared, [], `scripts with no #!/bin/sh or bash shebang: ${undeclared.join(', ')}`);
});

// Mutation (Rule 19): delete a `fi` from any script -> this goes red naming the file and the shell.
test('every shell script parses under its declared shell, and a sh script under dash too', () => {
  const broken = [];
  for (const file of SCRIPT_FILES) {
    const shell = declaredShell(readFileSync(join(REPO_ROOT, file), 'utf8'));
    if (shell === null) continue;
    for (const interpreter of shellsFor(shell)) {
      const parsed = spawnSync(interpreter, ['-n', join(REPO_ROOT, file)], { encoding: 'utf8' });
      if (parsed.status !== 0) broken.push(`${file} under ${interpreter}: ${parsed.stderr.trim()}`);
    }
  }
  assert.deepEqual(broken, [], `scripts that fail -n:\n${broken.join('\n')}`);
});

test('declaredShell reads the shebang forms the repository uses and nothing else', () => {
  assert.equal(declaredShell('#!/bin/sh\n'), 'sh');
  assert.equal(declaredShell('#!/usr/bin/env bash\n'), 'bash');
  assert.equal(declaredShell('#!/bin/bash\n'), 'bash');
  assert.equal(declaredShell('#!/usr/bin/env zsh\n'), null);
  assert.equal(declaredShell('# no shebang\n'), null);
});

// --- wait-readiness.sh ------------------------------------------------------------------------

const WAIT = join(REPO_ROOT, 'scripts', 'wait-readiness.sh');

/** Run wait-readiness.sh with a stub curl answering `body` (or failing when body is null). */
function runWait(dir, shell, args, body) {
  const bin = join(dir, 'bin');
  const calls = join(dir, 'curl-calls.txt');
  writeStub(bin, 'curl', [
    'printf "%s\\n" "$*" >> "$OCUPILOT_TEST_CURL_CALLS"',
    '[ -n "${OCUPILOT_TEST_BODY+x}" ] || exit 22',
    'printf "%s" "$OCUPILOT_TEST_BODY"',
  ]);
  writeStub(bin, 'sleep', ['exit 0']);
  rmSync(calls, { force: true });
  const extra = { OCUPILOT_TEST_CURL_CALLS: calls };
  const env = stubEnv(bin, extra);
  if (body === null) delete env.OCUPILOT_TEST_BODY;
  else env.OCUPILOT_TEST_BODY = body;
  const result = spawnSync(shell, [WAIT, ...args], { encoding: 'utf8', env });
  return { ...result, polls: captured(calls).length, out: `${result.stdout}${result.stderr}` };
}

// Mutations (Rule 19): delete the `"state":"unreadable"` arm -> the unreadable row polls until the
// timeout and goes red on its poll count; change the installed arm's `exit 0` -> the first row
// goes red.
test('wait-readiness.sh exits on the first poll for every settled state, under sh and dash', () => {
  for (const shell of shellsFor('sh')) {
    withScratch('ocupilot-wait-', (dir) => {
      const url = ['--url', 'http://localhost:52776/api/ocupilot/readiness/', '--interval', '1', '--timeout', '30'];

      const installed = runWait(dir, shell, url, '{"installed":true,"version":"1","state":"installed"}');
      assert.equal(installed.status, 0, `${shell}: installed exits 0: ${installed.out}`);
      assert.equal(installed.polls, 1, `${shell}: on the first poll`);

      for (const [state, says] of [
        ['failed', /FAILED install/],
        ['upgraderequired', /OLDER schema version/],
        ['unreadable', /install state UNREADABLE/],
      ]) {
        const settled = runWait(dir, shell, url, `{"installed":false,"version":"","state":"${state}"}`);
        assert.equal(settled.status, 1, `${shell}: ${state} exits 1: ${settled.out}`);
        assert.equal(settled.polls, 1, `${shell}: ${state} exits on the first poll, not at the timeout`);
        assert.match(settled.out, says, `${shell}: and names the state`);
      }
    });
  }
});

test('wait-readiness.sh keeps polling an unfinished install, and gives up at its timeout', () => {
  for (const shell of shellsFor('sh')) {
    withScratch('ocupilot-wait-', (dir) => {
      const args = ['--url', 'http://localhost:52776/api/ocupilot/readiness/', '--interval', '1', '--timeout', '3'];
      const installing = runWait(dir, shell, args, '{"installed":false,"version":"","state":"installing"}');
      assert.equal(installing.status, 1, `${shell}: an install that never finishes fails the wait: ${installing.out}`);
      assert.equal(installing.polls, 3, `${shell}: after one poll per interval up to the timeout`);
      assert.match(installing.out, /gave up after 3s/, `${shell}: naming the timeout`);

      const silent = runWait(dir, shell, args, null);
      assert.equal(silent.status, 1, `${shell}: an endpoint that never answers fails the wait too: ${silent.out}`);
      assert.equal(silent.polls, 3, `${shell}: after polling it for the whole budget`);
    });
  }
});

test('wait-readiness.sh answers every caller error with exit 2 and never polls', () => {
  for (const shell of shellsFor('sh')) {
    withScratch('ocupilot-wait-', (dir) => {
      for (const [why, args] of [
        ['no --url', []],
        ['an unknown argument', ['--bogus']],
        ['a zero interval', ['--url', 'http://x/', '--interval', '0']],
        ['a non-numeric timeout', ['--url', 'http://x/', '--timeout', 'soon']],
      ]) {
        const refused = runWait(dir, shell, args, '{"state":"installed"}');
        assert.equal(refused.status, 2, `${shell}: ${why} exits 2: ${refused.out}`);
        assert.equal(refused.polls, 0, `${shell}: ${why} polls nothing`);
      }
    });
  }
});

// --- ci-image-compile.sh ----------------------------------------------------------------------

const IMAGE_COMPILE = join(REPO_ROOT, 'scripts', 'ci-image-compile.sh');

/**
 * Run ci-image-compile.sh over a stub docker whose `exec` answers the script's two sessions: the
 * namespace probe and the compile-and-version probe, reporting the admin API version given.
 */
function runImageCompile(dir, shell, { version, outcome = 'OK', count = '120' }) {
  const bin = join(dir, 'bin');
  writeStub(bin, 'docker', [
    'case "$1" in',
    '  exec)',
    '    input=$(cat)',
    '    case "$input" in',
    '      *NS-START*) printf "OCUPILOT-NS-START:HSCUSTOM:OCUPILOT-NS-END\\n" ;;',
    '      *COMPILE-START*)',
    '        printf "OCUPILOT-COMPILE-START:%s:%s::OCUPILOT-COMPILE-END\\n" "$OCUPILOT_TEST_OUTCOME" "$OCUPILOT_TEST_COUNT"',
    '        v2=0; [ "$OCUPILOT_TEST_VERSION" = "2" ] && v2=1',
    '        printf "OCUPILOT-ADMIN-START:1:%s:%s:OCUPILOT-ADMIN-END\\n" "$v2" "$OCUPILOT_TEST_VERSION" ;;',
    '    esac ;;',
    'esac',
    'exit 0',
  ]);
  writeStub(bin, 'sleep', ['exit 0']);
  const result = spawnSync(shell, [IMAGE_COMPILE, '--image', 'intersystems/iris-community:2026.2'], {
    encoding: 'utf8',
    env: stubEnv(bin, {
      OCUPILOT_TEST_VERSION: String(version),
      OCUPILOT_TEST_OUTCOME: outcome,
      OCUPILOT_TEST_COUNT: count,
    }),
  });
  return { ...result, out: `${result.stdout}${result.stderr}` };
}

// Mutation (Rule 19): invert `[ "$ADMIN_V2" != "1" ]` in ci-image-compile.sh -> the version rows
// go red in both directions.
test('ci-image-compile.sh passes only a clean compile on an edition whose admin API reports v2', () => {
  for (const shell of shellsFor('sh')) {
    withScratch('ocupilot-image-', (dir) => {
      const green = runImageCompile(dir, shell, { version: 2 });
      assert.equal(green.status, 0, `${shell}: version 2 exits 0: ${green.out}`);
      assert.match(green.out, /is green/, `${shell}: and says so`);

      for (const version of [1, 3, 0]) {
        const other = runImageCompile(dir, shell, { version });
        assert.equal(other.status, 1, `${shell}: version ${version} exits 1: ${other.out}`);
      }
      const failed = runImageCompile(dir, shell, { version: 2, outcome: 'FAILED' });
      assert.equal(failed.status, 1, `${shell}: a failed compile exits 1 whatever the version: ${failed.out}`);
      const empty = runImageCompile(dir, shell, { version: 2, count: '0' });
      assert.equal(empty.status, 1, `${shell}: a compile over no class exits 1: ${empty.out}`);
    });
  }
});

// --- container-health.sh ----------------------------------------------------------------------

const HEALTH = join(REPO_ROOT, 'scripts', 'container-health.sh');

/**
 * Run container-health.sh with its start marker and the two /proc files it reads pointed into a
 * scratch directory, and a stub `iris` answering the gate status given (or failing).
 */
function runHealth(dir, shell, { marker, gate = 'installed', irisFails = false, bootId = 'boot-1', noStatus = false }) {
  const bin = join(dir, 'bin');
  writeStub(bin, 'iris', [
    'cat > /dev/null',
    '[ "$OCUPILOT_TEST_IRIS_FAILS" = "1" ] && exit 1',
    '[ "$OCUPILOT_TEST_NO_STATUS" = "1" ] && { echo "HSCUSTOM>"; exit 0; }',
    'printf "OCUPILOT-STATUS-START:%s:OCUPILOT-STATUS-END\\n" "$OCUPILOT_TEST_GATE"',
  ]);
  const bootFile = join(dir, 'boot_id');
  const statFile = join(dir, 'stat');
  const markerFile = join(dir, 'start-ok');
  rmSync(bootFile, { force: true });
  if (bootId !== null) writeFileSync(bootFile, `${bootId}\n`);
  // Field 20 once "pid (comm) " is stripped is PID 1's start time.
  const fields = Array.from({ length: 30 }, (_, i) => (i === 19 ? '424242' : String(i)));
  writeFileSync(statFile, `1 (tini) ${fields.join(' ')}\n`);
  rmSync(markerFile, { force: true });
  if (marker !== null) writeFileSync(markerFile, marker);
  const result = spawnSync(shell, [HEALTH], {
    encoding: 'utf8',
    env: stubEnv(bin, {
      OCUPILOT_START_MARKER_FILE: markerFile,
      OCUPILOT_BOOT_ID_FILE: bootFile,
      OCUPILOT_PID1_STAT_FILE: statFile,
      OCUPILOT_NAMESPACE: 'HSCUSTOM',
      OCUPILOT_TEST_GATE: gate,
      OCUPILOT_TEST_IRIS_FAILS: irisFails ? '1' : '0',
      OCUPILOT_TEST_NO_STATUS: noStatus ? '1' : '0',
    }),
  });
  return { ...result, out: `${result.stdout}${result.stderr}` };
}

// Mutations (Rule 19): drop the marker comparison from container-health.sh -> the "no marker" and
// "earlier start" rows exit 0 and go red; widen `!= "installed"` -> the unreadable row goes red.
test('container-health.sh is healthy only for this start, and only while the gate reads installed', () => {
  const key = 'boot-1:424242';
  for (const shell of shellsFor('sh')) {
    withScratch('ocupilot-health-', (dir) => {
      const healthy = runHealth(dir, shell, { marker: key });
      assert.equal(healthy.status, 0, `${shell}: this start's marker and an installed gate are healthy: ${healthy.out}`);

      const noMarker = runHealth(dir, shell, { marker: null });
      assert.equal(noMarker.status, 1, `${shell}: no start marker is unhealthy`);
      assert.match(noMarker.out, /has not recorded success yet/, `${shell}: and says why`);

      const earlier = runHealth(dir, shell, { marker: 'boot-0:111' });
      assert.equal(earlier.status, 1, `${shell}: an earlier start's marker is unhealthy`);

      const unidentified = runHealth(dir, shell, { marker: key, bootId: null });
      assert.equal(unidentified.status, 1, `${shell}: a start that cannot be identified is unhealthy`);
      assert.match(unidentified.out, /could not be identified/, `${shell}: and says why`);

      for (const gate of ['installing', 'failed', 'upgraderequired', 'unreadable']) {
        const refused = runHealth(dir, shell, { marker: key, gate });
        assert.equal(refused.status, 1, `${shell}: gate ${gate} is unhealthy: ${refused.out}`);
        assert.match(refused.out, new RegExp(`gate status is '${gate}'`), `${shell}: naming ${gate}`);
      }

      const sessionFailed = runHealth(dir, shell, { marker: key, irisFails: true });
      assert.equal(sessionFailed.status, 1, `${shell}: a failed iris session is unhealthy`);
      assert.match(sessionFailed.out, /iris session failed/, `${shell}: and says so`);

      const noStatus = runHealth(dir, shell, { marker: key, noStatus: true });
      assert.equal(noStatus.status, 1, `${shell}: a session that wrote no status marker is unhealthy`);
      assert.match(noStatus.out, /no gate status marker/, `${shell}: and says so`);
    });
  }
});

// --- field-lists.sh ---------------------------------------------------------------------------

const FIELD_LISTS = join(REPO_ROOT, 'scripts', 'field-lists.sh');

/**
 * Run field-lists.sh against a stub docker whose session answers `mode`: `ok` (a status marker and
 * a complete class source), `failed` (an error status), `multiline` (an error status whose text
 * spans two lines, as several errors in one status print), or `cut` (an OK status and a source
 * with no end marker, as a session killed part-way prints).
 */
function runFieldLists(dir, shell, mode) {
  const bin = join(dir, 'bin');
  writeStub(bin, 'docker', [
    'cat > /dev/null',
    'printf "\\nHSCUSTOM>\\n"',
    'case "$OCUPILOT_TEST_MODE" in',
    '  failed) printf "OCUPILOT-FIELDS-STATUS-START:FAILED ERROR #5001: probe:OCUPILOT-FIELDS-STATUS-END\\n" ;;',
    '  multiline) printf "OCUPILOT-FIELDS-STATUS-START:FAILED ERROR #5001: one\\r\\nERROR #5001: two:OCUPILOT-FIELDS-STATUS-END\\r\\n" ;;',
    '  *) printf "OCUPILOT-FIELDS-STATUS-START:OK:OCUPILOT-FIELDS-STATUS-END\\n"',
    '     printf "OCUPILOT-FIELDS-SOURCE-START\\nClass OcuPilot.Screen.Tool.FieldLists Extends %%RegisteredObject\\n{\\n}\\n"',
    '     [ "$OCUPILOT_TEST_MODE" = "cut" ] || printf "OCUPILOT-FIELDS-SOURCE-END\\n" ;;',
    'esac',
    'exit 0',
  ]);
  const output = join(dir, 'FieldLists.cls');
  writeFileSync(output, 'previous\n');
  const result = spawnSync(shell, [FIELD_LISTS, '--container', 'stub', '--output', output], {
    encoding: 'utf8',
    env: stubEnv(bin, { OCUPILOT_TEST_MODE: mode }),
  });
  return { ...result, out: `${result.stdout}${result.stderr}`, written: readFileSync(output, 'utf8') };
}

// Mutation (Rule 19): delete the SOURCE-END guard in field-lists.sh -> the `cut` row writes a
// truncated class and goes red.
test('field-lists.sh writes the class only from a complete, successful derivation', () => {
  for (const shell of shellsFor('sh')) {
    withScratch('ocupilot-field-lists-', (dir) => {
      const ok = runFieldLists(dir, shell, 'ok');
      assert.equal(ok.status, 0, `${shell}: a complete derivation exits 0: ${ok.out}`);
      assert.equal(ok.written, 'Class OcuPilot.Screen.Tool.FieldLists Extends %RegisteredObject\n{\n}\n', `${shell}: and writes exactly the source between the markers`);

      const failed = runFieldLists(dir, shell, 'failed');
      assert.equal(failed.status, 1, `${shell}: a failed status exits 1: ${failed.out}`);
      assert.equal(failed.written, 'previous\n', `${shell}: and leaves the file untouched`);
      assert.match(failed.out, /ERROR #5001: probe/, `${shell}: naming the error`);

      // Mutation (Rule 19): translate only \r, not \n, before the status grep -> this goes red.
      const multiline = runFieldLists(dir, shell, 'multiline');
      assert.equal(multiline.status, 1, `${shell}: a multi-line error status exits 1: ${multiline.out}`);
      assert.match(multiline.out, /the derivation failed; .* is unchanged/, `${shell}: and is read as a failed derivation`);
      assert.match(multiline.out, /ERROR #5001: one +ERROR #5001: two/, `${shell}: naming both errors`);
      assert.equal(multiline.written, 'previous\n', `${shell}: and leaves the file untouched`);

      const cut = runFieldLists(dir, shell, 'cut');
      assert.equal(cut.status, 1, `${shell}: a source with no end marker exits 1: ${cut.out}`);
      assert.equal(cut.written, 'previous\n', `${shell}: and leaves the file untouched`);

      const refused = spawnSync(shell, [FIELD_LISTS], { encoding: 'utf8' });
      assert.equal(refused.status, 2, `${shell}: no --container is a caller error`);
    });
  }
});

// --- _bmad/scripts/ledger.sh ------------------------------------------------------------------

const LEDGER = join(REPO_ROOT, '_bmad', 'scripts', 'ledger.sh');

// Mutation (Rule 19): delete `NOTE="${NOTE#note=}"` from ledger.sh's `new` -> the trailer reads
// `note=note=human=...` and the first assertion goes red.
test('ledger.sh new writes a caller-supplied note= prefix once, against a temporary ledger', () => {
  withScratch('ocupilot-ledger-', (dir) => {
    const file = join(dir, 'deferred-work.md');
    const run = (note) =>
      spawnSync('bash', [LEDGER, file, 'new', 'a summary', 'a source', 'low', 'low', 'in-story', 'an evidence line', 'open', 'burndown', 'a-stage', note], {
        encoding: 'utf8',
        env: { ...process.env, LEDGER_ID_COUNTER: '' },
      });
    const prefixed = run('note=human=decided at the gate');
    assert.equal(prefixed.status, 0, `new exits 0: ${prefixed.stdout}${prefixed.stderr}`);
    const bare = run('plain note');
    assert.equal(bare.status, 0, `new exits 0: ${bare.stdout}${bare.stderr}`);
    const trailers = readFileSync(file, 'utf8').split('\n').filter((line) => / status=open owner=burndown by=a-stage /.test(line));
    assert.equal(trailers.length, 2, `two entries were written: ${trailers.join(' | ')}`);
    assert.match(trailers[0], / note=human=decided at the gate$/, 'the leading note= is written once');
    assert.doesNotMatch(trailers[0], /note=note=/, 'never twice');
    assert.match(trailers[1], / note=plain note$/, 'a note without the prefix is written as given');
  });
});

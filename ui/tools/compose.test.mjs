import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync, existsSync, mkdtempSync, rmSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import { ROSTER_SOURCE, readRoster } from './ipm-manifest.mjs';
import { stubEnv, writeStub } from './stub-bin.mjs';

// docker-compose.yml is YAML, not JSON (unlike angular.json's own precedent in this
// folder), so these are text-level assertions rather than a parsed-structure walk --
// the same shape check-objectscript.py already uses for its own line-oriented checks,
// and sufficient for what this story's AC1/AC2/AC3 actually pin: an explicit tag, no
// floating tag anywhere, the demo flag, the start-hook wiring and the health check.
//
// Mutations (Rule 19):
// - revert the image line to `intersystems/irishealth-community:latest-cd` -> the
//   "pinned tag" test and the "no floating tag" test both go red.
// - pin `:2026.2-linux-arm64` instead -> the "pinned tag" test goes red; delete the
//   recorded digest -> the digest test goes red (code review round 3).
// - remove the `StartPath` invocation from scripts/container-start.sh, leaving the hook
//   running and calling nothing -> this file cannot observe that (a throwaway-container
//   run is what does, per the spec's own AC2 mutation); this suite only pins that the
//   compose file actually wires the hook and health check up, not that they succeed.
// - make scripts/container-start.sh ignore StartPath's result and always exit 0 -> same
//   caveat; the exit-code mapping is pinned by the throwaway-container run, not here.
// - restore `restart: unless-stopped` -> the restart-policy test goes red (DW-66). What the
//   policy does to a failing container is observed on a throwaway container, not here.
// - drop the start-marker check from scripts/container-health.sh, or move the marker write in
//   scripts/container-start.sh out of the STARTPATH-OK branch -> the start-scoped health test
//   goes red (DW-72, rework iteration 8). What it does on a restart is observed on a throwaway.
// - move the MarkInstalling call below LoadDir in scripts/container-start.sh -> the
//   mark-before-recompile test goes red (DW-72).
// - write a session marker unsplit (`Write "OCUPILOT-RESULT-START:",...`), leave the end marker
//   whole, or write the marker line as several Write arguments -> the split-marker test goes red
//   (Fix Pack F-2, rework iteration 8; tightened in its step-04 review).
// - edit start_key() in only one of the two scripts (the /proc/1/stat field, say) -> the
//   same-key test goes red; drop the `exit 1` from the health check's marker comparison -> the
//   marker-mismatch test goes red; add a second start-marker write -> the start-scoped health
//   test goes red; rename the method the hook checks for without the one it calls -> the
//   mark-guard test goes red (DW-72, step-04 review of rework iteration 8).
// - (QA) swap the LoadDir and StartPath lines in container-start.sh's load-and-start session ->
//   the DW-195 ordering test goes red; add a literal "IsSystemNamespace" (or a copy of
//   Installer.cls's SYSTEMNAMESPACES list) anywhere in container-start.sh, simulating a fix ->
//   the same test's "no system-namespace check of its own" assertion goes red, which is the
//   point: this pin is of the current, deferred shape, and must be revisited (not just deleted)
//   the day someone actually closes DW-195.
// - write the start marker anywhere outside the STARTPATH-OK branch, in any spelling
//   (`touch "$START_MARKER"`, `printf ... > "$START_MARKER"`) -> the marker-use test goes red;
//   compare the marker with `=` instead of `!=` -> the marker-mismatch test goes red; add an
//   `exit` to any outcome of the pre-recompile mark -> the mark-never-fails test goes red; cut
//   another /proc/1/stat field in both start_key() copies -> the start-time test goes red
//   (code review round 4: each of these passed the pins above).
const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const composePath = join(repoRoot, 'docker-compose.yml');
const raw = readFileSync(composePath, 'utf8');

test('the image is pinned to an explicit 2026.2 tag', () => {
  // Anchored to the end of the line (code review round 3): `\b` also accepted
  // `2026.2-linux-arm64`, the single-architecture tag the spec's Code Map rules out.
  assert.match(raw, /^\s*image:\s*intersystems\/irishealth-community:2026\.2\s*$/m, 'expected the explicit, multi-arch 2026.2 tag and nothing after it');
});

test('the tested manifest digest is recorded beside the pinned tag (AC1)', () => {
  assert.match(raw, /sha256:462de1fb3597272fde0e03afad006af1b18b59c90f1c1fb5566c79b027a7af0a/, 'expected the tested 2026.2 manifest digest recorded in the compose file');
});

test('the literal floating tag latest-cd appears nowhere in the file', () => {
  assert.ok(!raw.includes('latest-cd'), 'found the floating latest-cd tag -- AD-27 requires an explicit, non-floating tag');
});

test('the demo opt-in flag is set to the literal string "1"', () => {
  assert.match(raw, /OCUPILOT_DEMO:\s*"1"/, 'expected OCUPILOT_DEMO: "1" (AD-25 -- this repository\'s own compose file opts in)');
});

test('the source and scripts trees are mounted read-only', () => {
  assert.match(raw, /-\s*\.\/src:\/opt\/ocupilot\/src:ro\b/, 'expected a read-only ./src mount');
  assert.match(raw, /-\s*\.\/scripts:\/opt\/ocupilot\/scripts:ro\b/, 'expected a read-only ./scripts mount');
});

// Story 1.5. The mount is `./ui`, not `./ui/dist`: ui/tools/build-output.test.mjs deletes
// ui/dist on every `npm test`, and a bind mount pinned to a directory the host removes
// breaks for the life of the container.
//
// Mutations (Rule 19): change the mount to `./ui/dist:...` or drop it -> the mount test goes
// red; drop the bundle argument from the StartPath call in scripts/container-start.sh, or
// point the hook's BUNDLE_DIR somewhere other than the mount -> the bundle-argument test goes
// red. That the shell then actually serves that bundle is observed on a throwaway container.
test('the built client bundle reaches the container through a read-only ui mount', () => {
  assert.match(raw, /-\s*\.\/ui:\/opt\/ocupilot\/ui:ro\b/, 'expected a read-only ./ui mount');
  assert.ok(
    !/-\s*\.\/ui\/dist[:/]/.test(raw),
    'the mount must be ./ui, not ./ui/dist -- the client test suite deletes ui/dist on every run'
  );
});

test('the durable data mount is unchanged', () => {
  assert.match(serviceBlock(raw, 'iris'), /-\s*\.\/iris-data:\/durable\b/, 'expected the existing durable-storage bind mount to survive untouched');
});

// DW-234. What durable-init DOES is executed by scripts/ci-durable-ownership.sh on a Linux volume
// and by CI's throwaway bring-up; this pins the wiring that makes it run, as root, before iris.
//
// Mutation (Rule 19): drop iris's `depends_on`, or its `service_completed_successfully`
// condition -> this goes red, and iris could start before the durable root is writable.
test('a one-shot durable-init service makes the durable root writable before iris starts (DW-234)', () => {
  const init = serviceBlock(raw, 'durable-init');
  assert.ok(init, 'docker-compose.yml declares a durable-init service');
  assert.match(init, /^\s*image:\s*intersystems\/irishealth-community:2026\.2\s*$/m, 'in the same pinned image');
  assert.match(init, /^\s*user:\s*"0:0"\s*$/m, 'as root');
  assert.match(init, /^\s*entrypoint:\s*\["sh",\s*"\/opt\/ocupilot\/scripts\/durable-init\.sh"\]\s*$/m, 'running scripts/durable-init.sh instead of IRIS');
  assert.match(init, /^\s*restart:\s*"no"\s*$/m, 'once, never restarted');
  assert.match(init, /-\s*\.\/iris-data:\/durable\b/, 'over the same durable mount iris uses');
  assert.match(init, /-\s*\.\/scripts:\/opt\/ocupilot\/scripts:ro\b/, 'with the scripts it runs mounted read-only');
  assert.ok(!/^\s*ports:/m.test(init), 'publishing no port');
  assert.ok(existsSync(join(repoRoot, 'scripts', 'durable-init.sh')), 'scripts/durable-init.sh exists');

  const iris = serviceBlock(raw, 'iris');
  assert.match(
    iris,
    /depends_on:\s*\n\s*durable-init:\s*\n\s*condition:\s*service_completed_successfully\b/,
    'iris starts only once durable-init has exited 0'
  );
});

// DW-197. OcuPilot.Test.Manifest reads /opt/ocupilot/module.xml and logs a skip when nothing
// mounted one, so the mount is what makes its only document-level assertion run at all. The
// throwaway's copy is pinned in ci.test.mjs; this one was pinned by nothing, and deleting it
// returns the class to skipping silently on any container from this file that also sets
// OCUPILOT_LOAD_TESTS, the only start that compiles it.
//
// Mutation (Rule 19): drop the module.xml volume from docker-compose.yml -> this goes red.
test('the committed manifest is mounted where OcuPilot.Test.Manifest reads it (DW-197)', () => {
  assert.match(
    raw,
    /-\s*\.\/module\.xml:\/opt\/ocupilot\/module\.xml:ro/,
    'expected ./module.xml mounted read-only at /opt/ocupilot/module.xml'
  );
});

test('the --after start hook is wired to container-start.sh', () => {
  assert.match(raw, /command:\s*\["--after",\s*"sh \/opt\/ocupilot\/scripts\/container-start\.sh"\]/, 'expected the --after hook to run scripts/container-start.sh');
});

test('the healthcheck runs container-health.sh, not curl (the image ships none)', () => {
  assert.match(raw, /healthcheck:/, 'expected a healthcheck block');
  assert.match(raw, /test:\s*\["CMD",\s*"sh",\s*"\/opt\/ocupilot\/scripts\/container-health\.sh"\]/, 'expected the healthcheck to invoke container-health.sh');
  assert.ok(!/healthcheck:[\s\S]*?\bcurl\b/.test(raw), 'the image has no curl (verified live) -- a curl-based healthcheck would never pass');
});

test('the published ports are unchanged (52774:52773 web, 1973:1972 SuperServer)', () => {
  assert.match(raw, /"1973:1972"/, 'expected the SuperServer port mapping to be unchanged');
  assert.match(raw, /"52774:52773"/, 'expected the web port mapping to be unchanged -- ocupilot.code-workspace and .vscode/settings.json both track it (Test/Http.cls no longer does: GetTestPort reads the instance\'s own configured port)');
});

// DW-66 (the owner's decision, Story 1.4 rework iteration 6): a failed install makes the start
// hook exit non-zero and the container exit 1, so the restart policy decides what happens next.
// `unless-stopped` (and `always`) restart it forever, re-running a deterministic failure in a
// loop; `on-failure:N` retries N times and then leaves it stopped. Anchored to the `restart:` key
// itself, so the comment above that key in the compose file -- which names the old policy -- is
// not what this reads.
/** One top-level service's block of docker-compose.yml, from its key to the next service. */
function serviceBlock(text, name) {
  const at = text.search(new RegExp(`^  ${name}:\\s*$`, 'm'));
  if (at === -1) return '';
  const rest = text.slice(at + 1);
  const next = rest.search(/^ {2}(?:#|[A-Za-z])/m);
  return next === -1 ? text.slice(at) : text.slice(at, at + 1 + next);
}

test('the restart policy retries a failed start a bounded number of times, then stops', () => {
  // A trailing YAML comment (`restart: on-failure:3  # why`) is not part of the value. Scoped to
  // the iris service: durable-init is a one-shot with its own `restart: "no"`.
  const iris = serviceBlock(raw, 'iris');
  assert.ok(iris, 'docker-compose.yml declares the iris service');
  const keys = [...iris.matchAll(/^\s*restart:\s*(.*?)\s*$/gm)].map((m) => m[1].replace(/\s+#.*$/, '').replace(/^["']|["']$/g, ''));
  assert.equal(keys.length, 1, `expected exactly one restart: key on iris, found ${keys.length}`);
  const m = /^on-failure:(\d+)$/.exec(keys[0]);
  assert.ok(m, `expected restart: on-failure:<max-retries>, found "${keys[0]}" -- unless-stopped or always would re-run a failing install forever`);
  const retries = Number(m[1]);
  assert.ok(retries >= 1 && retries <= 10, `expected a small positive retry limit, found ${retries}`);
  assert.ok(!/^\s*restart_policy:/m.test(raw), 'a deploy.restart_policy block would override the restart key -- none is expected');
});

test('the two hook scripts this compose file names actually exist', () => {
  assert.ok(existsSync(join(repoRoot, 'scripts', 'container-start.sh')), 'scripts/container-start.sh must exist');
  assert.ok(existsSync(join(repoRoot, 'scripts', 'container-health.sh')), 'scripts/container-health.sh must exist');
});

// DW-72 (AD-38 as amended 2026-09-11). These read the scripts' text, like the tests above read
// the compose file's: they pin that the mechanism is wired, not what it does on a restart,
// which only a throwaway container can show (the spec's ## Verification records those runs).
const startHook = readFileSync(join(repoRoot, 'scripts', 'container-start.sh'), 'utf8');
const healthHook = readFileSync(join(repoRoot, 'scripts', 'container-health.sh'), 'utf8');

test('the health check is scoped to this container start (DW-72)', () => {
  const marker = '/tmp/ocupilot-start-ok';
  assert.ok(healthHook.includes(`START_MARKER="\${OCUPILOT_START_MARKER_FILE:-${marker}}"`), 'container-health.sh must read the start marker, defaulting to the path the start hook writes');
  const check = healthHook.indexOf('"$(cat "$START_MARKER"');
  const session = healthHook.indexOf('STATUS_RAW=$(iris session');
  assert.ok(check > 0 && check < session, 'container-health.sh must compare the start marker with this start\'s key before it asks IRIS anything');
  assert.ok(startHook.includes(`START_MARKER="${marker}"`), 'container-start.sh must write the same start marker');
  const okBranch = startHook.indexOf('STARTPATH-OK*)');
  const write = startHook.indexOf('> "$START_MARKER.$$"');
  const nextBranch = startHook.indexOf('LOAD-FAILED*)');
  assert.ok(okBranch > 0 && write > okBranch && write < nextBranch, 'container-start.sh must write the start marker only in its STARTPATH-OK branch');
  assert.equal(startHook.split('> "$START_MARKER.$$"').length - 1, 1, 'container-start.sh must write the start marker in exactly one place');
});

test('both hook scripts compute the same start key (DW-72)', () => {
  const body = (text) => (text.match(/\nstart_key\(\) \{\n([\s\S]*?)\n\}\n/) || [])[1];
  const fromStart = body(startHook);
  const fromHealth = body(healthHook);
  assert.ok(fromStart, 'container-start.sh must define start_key()');
  assert.ok(fromHealth, 'container-health.sh must define start_key()');
  assert.equal(fromHealth, fromStart, 'the health check must compute the key exactly as the start hook writes it, or no start is ever reported healthy');
});

test('the health check fails until the start marker carries this start\'s key (DW-72)', () => {
  const found = healthHook.match(/\n(if \[ ! -r "\$START_MARKER" \][^\n]*)\n([\s\S]*?)\nfi\n/);
  assert.ok(found, 'container-health.sh must compare the start marker with this start\'s key');
  assert.match(found[1], /^if \[ ! -r "\$START_MARKER" \] \|\| \[ "\$\(cat "\$START_MARKER" 2>\/dev\/null\)" != "\$KEY" \]; then$/, 'the check must fail when the marker is missing or does not carry this start\'s key');
  assert.match(found[2], /^\s*exit 1\s*$/m, 'a missing or mismatched start marker must fail the health check');
});

test('the start hook uses the start marker only to clear it, or in its STARTPATH-OK branch (DW-72)', () => {
  // Every other use is a write in some spelling, and a write outside that branch could let a
  // start whose install never succeeded read healthy (code review round 4).
  const okBranch = startHook.indexOf('STARTPATH-OK*)');
  const nextBranch = startHook.indexOf('LOAD-FAILED*)');
  assert.ok(okBranch > 0 && nextBranch > okBranch, 'container-start.sh must keep its STARTPATH-OK branch before its LOAD-FAILED branch');
  const allowedOutside = new Set(['START_MARKER="/tmp/ocupilot-start-ok"', 'rm -f "$START_MARKER" 2>/dev/null || true']);
  const stray = [];
  let at = 0;
  for (const line of startHook.split('\n')) {
    const start = at;
    at += line.length + 1;
    if (!line.includes('START_MARKER') || /^\s*#/.test(line) || allowedOutside.has(line)) continue;
    if (start > okBranch && start < nextBranch) continue;
    stray.push(line.trim());
  }
  assert.deepEqual(stray, [], 'container-start.sh must write the start marker nowhere but its STARTPATH-OK branch');
});

test('no outcome of the pre-recompile mark fails the start (DW-72)', () => {
  const block = (startHook.match(/\ncase "\$MARK" in\n([\s\S]*?)\nesac\n/) || [])[1];
  assert.ok(block, 'container-start.sh must branch on the mark\'s outcome');
  assert.ok(!/\bexit\b/.test(block), 'a mark that is skipped, refused or fails must never end the start (AD-38 as amended, DW-72)');
});

// Verified by controlled probe on the pinned image (Story 1.5): /iris-main treats ANY stderr
// output from its `--after` command as a failure and shuts the instance down, even when the
// command exits 0. So a `>&2` on a "carrying on" path -- a failed mark (DW-72), an unreadable
// /proc/1/environ, an absent client bundle (AC11) -- stops the container instead, which is the
// opposite of what each of those paths promises. The exit code alone fails a start; the same
// probe with `exit 1` and no stderr shut the instance down.
//
// Mutation (Rule 19): put a `>&2` back on any message in scripts/container-start.sh, or drop
// a `2>&1` from either `iris session` -> this goes red. What it does to a container is
// observed on a throwaway, not here.
test('the start hook never writes to stderr, its children included (Story 1.5)', () => {
  const lines = startHook.split('\n');
  const stray = lines
    .filter((l) => !/^\s*#/.test(l))
    .filter((l) => l.includes('>&2') && !l.includes('2>&1') && !l.includes('2>/dev/null'))
    .map((l) => l.trim());
  assert.deepEqual(stray, [], 'container-start.sh must write every message to stdout -- /iris-main reads stderr from its --after command as a failed start');

  // A message of the hook's own is only half of it: `iris session` is a child process whose
  // stderr is inherited straight through to /iris-main unless it is captured.
  // Indented too: the roster session sits inside the product-start branch.
  const sessions = lines.filter((l) => /^\s*\w+=\$\(iris session/.test(l));
  assert.ok(sessions.length >= 3, 'expected the hook to capture all three iris sessions');
  for (const line of sessions) {
    assert.ok(
      line.includes('2>&1'),
      `every iris session must capture its own stderr, found: ${line.trim()}`
    );
  }
});

test('the start key reads PID 1\'s start time (DW-72)', () => {
  // The same-key test above compares the two copies with each other only; this pins the field.
  // Once "pid (comm) " is stripped, field 20 is /proc/1/stat's field 22, the start time: a field
  // that never changes between container starts would let an earlier start's marker pass, and
  // one that changes all the time would never let any start read healthy.
  const body = (startHook.match(/\nstart_key\(\) \{\n([\s\S]*?)\n\}\n/) || [])[1];
  assert.ok(body, 'container-start.sh must define start_key()');
  assert.match(body, /tStarted=\$\(sed -e 's\/\^\.\*\) \/\/' "\$\{OCUPILOT_PID1_STAT_FILE:-\/proc\/1\/stat\}" 2>\/dev\/null \| cut -d' ' -f20 \|\| true\)/, 'start_key() must cut field 20 of /proc/1/stat once "pid (comm) " is stripped');
  assert.match(body, /tBoot=\$\(cat "\$\{OCUPILOT_BOOT_ID_FILE:-\/proc\/sys\/kernel\/random\/boot_id\}" 2>\/dev\/null \|\| true\)/, 'start_key() must read the kernel\'s boot id');
});

test('the start hook checks for the very method it calls before the recompile (DW-72)', () => {
  const guarded = (startHook.match(/%Dictionary\.CompiledMethod\)\.%ExistsId\("OcuPilot\.Install\.Installer\|\|(\w+)"\)/) || [])[1];
  const called = (startHook.match(/##class\(OcuPilot\.Install\.Installer\)\.(\w+)\("", \.tMarkOutcome\)/) || [])[1];
  assert.ok(guarded, 'container-start.sh must check that the compiled installer has the mark method');
  assert.equal(called, guarded, 'the method the hook checks for must be the one it calls, or every start skips the mark as NOMETHOD');
});

test('the start hook hands StartPath the bundle directory on the ui mount (Story 1.5)', () => {
  const mount = '/opt/ocupilot/ui';
  const bundleDir = (startHook.match(/\nBUNDLE_DIR="([^"]*)"\n/) || [])[1];
  assert.ok(bundleDir, 'container-start.sh must define BUNDLE_DIR');
  assert.ok(
    bundleDir.startsWith(`${mount}/`),
    `BUNDLE_DIR must sit under the ${mount} mount the compose file declares, found "${bundleDir}"`
  );
  assert.match(
    startHook,
    /##class\(OcuPilot\.Install\.Installer\)\.StartPath\(\$DEMO_ARG,\s*"\$BUNDLE_ARG"\)/,
    'the hook must pass the resolved bundle directory to StartPath as its second argument'
  );
  // The container path always names the directory, present or not, so install is the single
  // place that decides what an absent bundle means (a warn, and a start that carries on --
  // AC11). An empty argument means "no source was named at all", which is the MCP/IPM case.
  assert.match(
    startHook,
    /\nBUNDLE_ARG="\$BUNDLE_DIR"\n/,
    'the hook must hand install the bundle directory whether or not it holds a build'
  );
  assert.ok(
    !/BUNDLE_ARG=""/.test(startHook),
    'the hook must not substitute an empty source for an absent bundle -- that is the "no source named" case, which install reports differently'
  );
});

test('the start hook marks the version row before it recompiles (DW-72)', () => {
  const mark = startHook.indexOf('MarkInstalling("", .tMarkOutcome)');
  const load = startHook.indexOf('$System.OBJ.LoadDir(');
  assert.ok(mark > 0, 'container-start.sh must call Installer.MarkInstalling');
  assert.ok(load > 0 && mark < load, 'the mark must come before the recompile');
});

test('every session marker is split on its source line (Fix Pack F-2)', () => {
  // A failing line is echoed back with its error; a literal marker in that echo was once
  // taken for the result. So no line piped into `iris session` may carry a whole marker, and
  // every marker line is one Write of one expression, split at both markers: a line written as
  // several Write arguments writes its start marker before a failing argument, and its echo
  // then supplies the rest.
  for (const [name, text] of [['container-start.sh', startHook], ['container-health.sh', healthHook]]) {
    assert.ok(!/Write\s+"OCUPILOT-[A-Z]+-START:/.test(text), `${name} writes a session marker unsplit`);
    const bodies = [...text.matchAll(/<<'?EOF'?\n([\s\S]*?)\nEOF\n/g)].map((m) => m[1]);
    assert.ok(bodies.length > 0, `${name}: expected the ObjectScript it pipes into iris session`);
    const lines = bodies.join('\n').split('\n');
    assert.deepEqual(lines.filter((l) => /OCUPILOT-[A-Z]+-(START|END)/.test(l)), [], `${name}: a session line carries a whole marker`);
    const markerLines = lines.filter((l) => l.includes('"OCUPILOT-"_"'));
    assert.ok(markerLines.length > 0, `${name} must write its session marker split, as one expression`);
    for (const l of markerLines) {
      assert.match(l, /^Write "OCUPILOT-"_"([A-Z]+)-START:"_.+_":OCUPILOT-"_"\1-END",!$/, `${name}: a marker line must be one Write of one expression, split at both markers: ${l}`);
    }
  }
});

// --- The install-namespace override (Story 1.16, DW-12) --------------------------------------
//
// The shell half of DW-12: OcuPilot.Install.Installer can refuse an instance carrying neither
// candidate namespace, but only the start hook can honor OCUPILOT_NAMESPACE and only the start
// hook can fail a container start naming the namespace that does not exist. No %UnitTest class
// inside IRIS can observe a shell script, so it is pinned here.
//
// Mutation (Rule 19): make the MISSING branch fall back to the default instead of exiting, or
// drop the override from container-health.sh -> the matching assertion goes red.
test('the start hook honors OCUPILOT_NAMESPACE and fails naming a namespace that does not exist (DW-12)', () => {
  assert.match(
    startHook,
    /OCUPILOT_NAMESPACE/,
    'container-start.sh must read the install-namespace override'
  );
  assert.match(
    startHook,
    /export OCUPILOT_NAMESPACE/,
    'and export it, so the iris session it spawns can read it back'
  );
  assert.match(
    startHook,
    /grep '\^OCUPILOT_NAMESPACE=' \| cut -d= -f2-/,
    'read from PID 1\'s own environment, like OCUPILOT_DEMO -- the --after shell sees a narrowed one'
  );

  const block = startHook.slice(startHook.indexOf('case "$NS_RESULT" in'));
  const body = block.slice(0, block.indexOf('\nesac\n'));
  assert.ok(body, 'container-start.sh must branch on the resolved namespace outcome');

  const missing = body.slice(body.indexOf('MISSING:*)'), body.indexOf('NONE)'));
  assert.match(missing, /exit 1/, 'an override naming a namespace that does not exist fails the start');
  assert.match(missing, /does not exist/, 'and says so');
  assert.match(missing, /refusing rather than falling back/, 'with no silent fallback to a default');
  assert.doesNotMatch(missing, /INSTALL_NS=/, 'and never resolves an install namespace of its own');

  const noneStart = body.indexOf('NONE)');
  // Bounded at its own `;;`, not run to the end of the case block: the `*)` fallback that
  // follows also carries `exit 1`, so an unbounded slice would stay green through a NONE
  // branch that lost its refusal -- the mutation this block names would not be red.
  const none = body.slice(noneStart, body.indexOf(';;', noneStart));
  assert.ok(none && !none.includes('*)'), 'the NONE branch is read on its own, not with the fallback');
  assert.match(none, /exit 1/, 'an instance carrying neither candidate namespace fails the start too');
  assert.match(none, /HSCUSTOM/, 'naming both candidates');
  assert.match(none, /USER/);
  assert.match(none, /OCUPILOT_NAMESPACE/, 'and the override that would fix it');

  // Only the OK branch may set the namespace the load-and-start session then logs into.
  const assignments = startHook.split('\n').filter((l) => /^\s*INSTALL_NS=/.test(l) && !/^\s*#/.test(l));
  assert.deepEqual(
    assignments.map((l) => l.trim()),
    ['INSTALL_NS=""', 'INSTALL_NS="${NS_RESULT#OK:}"'],
    'INSTALL_NS is initialised empty and set from the OK branch alone'
  );
});

test('both hook scripts resolve the install namespace the same way (DW-12)', () => {
  // The two scripts run in the same container against the same instance: a health probe that
  // read the gate in a different namespace from the one install was run in would leave a
  // correctly installed container permanently unhealthy, and the restart policy would then
  // stop it. Asserted as the same three-line resolution in both files.
  for (const [name, text] of [['container-start.sh', startHook], ['container-health.sh', healthHook]]) {
    // The shell half first. Asserting only the ObjectScript lines leaves the two lines that
    // feed them -- the PID 1 read and the export -- unpinned on container-health.sh, where
    // dropping them makes a correctly installed container never report healthy.
    assert.match(text, /grep '\^OCUPILOT_NAMESPACE=' \| cut -d= -f2-/, `${name} reads the override from PID 1's own environment`);
    assert.match(text, /export OCUPILOT_NAMESPACE/, `${name} exports it so its iris session inherits it`);
    assert.match(text, /Set tOverride=\$System\.Util\.GetEnviron\("OCUPILOT_NAMESPACE"\)/, `${name} reads the override inside IRIS`);
    assert.match(text, /Set tHasHSCUSTOM=##class\(%SYS\.Namespace\)\.Exists\("HSCUSTOM"\)/, `${name} probes HSCUSTOM`);
    assert.match(text, /Set tHasUSER=##class\(%SYS\.Namespace\)\.Exists\("USER"\)/, `${name} probes USER`);
    assert.match(text, /Set tDefault=\$Select\(tHasHSCUSTOM:"HSCUSTOM",tHasUSER:"USER",1:""\)/, `${name} falls back in the same order and to the same empty answer`);
    assert.match(text, /Set tNS=\$Case\(tOverride,"":tDefault,:tOverride\)/, `${name} prefers the override over the default`);
  }

  // The one place the two deliberately differ, and it was unpinned: a health check normally
  // inherits the container's declared environment, so container-health.sh falls back to PID 1
  // only when it did not. Removing the guard restores the unconditional assignment, where an
  // unreadable /proc/1/environ blanks a value that was already correct and the probe then
  // reads the gate in the wrong namespace -- a correctly installed container that never
  // reports healthy, which the restart policy then stops.
  assert.match(
    healthHook,
    /if \[ -z "\$\{OCUPILOT_NAMESPACE:-\}" \]/,
    'container-health.sh reads PID 1 only when it did not inherit the override itself'
  );

  // A third declaration of the same rule lives in ObjectScript, and nothing held it to these
  // two: container-start.sh must resolve the namespace before any OcuPilot class is compiled,
  // so the candidate order is necessarily restated in shell -- but a candidate added or
  // reordered in ResolveNamespace() would leave both scripts silently disagreeing with the
  // installer, and the scripts' NONE branch would then fail a start the installer accepts.
  const installer = readFileSync(join(repoRoot, 'src', 'OcuPilot', 'Install', 'Installer.cls'), 'utf8');
  const resolver = installer.slice(installer.indexOf('ClassMethod ResolveNamespace()'));
  const candidates = [...resolver.slice(0, resolver.indexOf('\n}')).matchAll(/NamespaceExists\("([A-Z]+)"\)/g)].map((m) => m[1]);
  assert.deepEqual(
    candidates,
    ['HSCUSTOM', 'USER'],
    "ResolveNamespace()'s candidates, in order, are the ones both shell scripts restate"
  );
});

// --- DW-195 (closed, Story 1.17): a system namespace is refused before anything compiles -----
//
// container-start.sh's namespace-resolution session used to check only that OCUPILOT_NAMESPACE
// named an EXISTING namespace. The refusal lived solely in
// OcuPilot.Install.Installer.GuardInstallNamespace, reached only once StartPath runs -- in the
// load-and-start session that follows, whose own $System.OBJ.LoadDir has by then already
// compiled the whole src/OcuPilot/ tree into whatever namespace was resolved first,
// unconditionally. An override naming an existing system namespace (%SYS.Namespace.Exists("%SYS")
// answers true on every instance) reached the compile before anything could refuse it.
//
// Mutations (Rule 19): delete the SYSTEM branch from container-start.sh's `case "$NS_RESULT"`,
// or drop the `tIsSystem` computation from the resolution session -> the corresponding assertion
// below goes red. Move the refusal into the load-and-start session instead -> the ordering
// assertion goes red. What such an override does to a real container is observed on a
// throwaway, not here.
test('a system-namespace override is refused in the resolution session, before LoadDir (DW-195)', () => {
  const load = startHook.indexOf('$System.OBJ.LoadDir(');
  const start = startHook.indexOf('StartPath($DEMO_ARG');
  assert.ok(load > 0, 'container-start.sh must call $System.OBJ.LoadDir to compile src/OcuPilot/');
  assert.ok(start > load, 'LoadDir still runs before StartPath, which is why the refusal cannot wait for it');

  // The refusal is computed in the FIRST session, whose marker is written before LoadDir exists
  // in the script at all.
  const refusal = startHook.indexOf('Set tIsSystem=');
  assert.ok(refusal > 0, 'the resolution session must decide whether the resolved namespace is one OcuPilot refuses');
  assert.ok(refusal < load, 'and it must do so before the compile, not after it');

  // A "%"-prefixed name is refused whatever the list says, which is what makes the fallback
  // safe on a first start where no compiled installer exists to read the list from.
  assert.match(
    startHook,
    /\$Extract\(tUpper\)="%":1/,
    'a %-prefixed namespace is refused directly, so %SYS is refused even with no compiled installer to ask'
  );

  const block = startHook.slice(startHook.indexOf('case "$NS_RESULT" in'));
  const body = block.slice(0, block.indexOf('\nesac\n'));
  const systemStart = body.indexOf('SYSTEM:*)');
  assert.ok(systemStart > 0, 'container-start.sh must branch on the system-namespace outcome');
  const branch = body.slice(systemStart, body.indexOf(';;', systemStart));
  assert.match(branch, /exit 1/, 'and fail the start');
  assert.match(branch, /before anything is compiled into it/, 'saying that nothing was compiled into it');
});

test('the start hook\'s refusal list is held equal to the installer\'s (DW-195)', () => {
  // The list is a literal in the shell, and it has to be: the resolution session runs in %SYS
  // and decides the namespace before switching into it, while OcuPilot's code is mapped only
  // into the install namespace — so asking the installer for its own parameter from there
  // answers nothing on every start. A literal is a second declaration, and this is what keeps
  // it from drifting.
  //
  // Mutation (Rule 19): add a name to Installer.SYSTEMNAMESPACES without adding it to
  // container-start.sh (or the reverse) -> this goes red naming both spellings.
  const installer = readFileSync(join(repoRoot, 'src', 'OcuPilot', 'Install', 'Installer.cls'), 'utf8');
  const declared = /Parameter SYSTEMNAMESPACES As %String = "([^"]*)"/.exec(installer);
  assert.ok(declared, 'Installer.cls declares SYSTEMNAMESPACES');
  const literal = /Set tRefusedList="([^"]*)"/.exec(startHook);
  assert.ok(literal, 'container-start.sh carries the refusal list');
  assert.equal(
    literal[1],
    declared[1],
    'the hook\'s list is the installer\'s own, so a name added to either is added to both'
  );

  // And the dead form does not come back: a `$Parameter` read from this session answers nothing,
  // so a branch built on it would silently never be taken.
  assert.ok(
    !startHook.includes('$Parameter("OcuPilot.Install.Installer","SYSTEMNAMESPACES")'),
    'the hook does not pretend to read the parameter from a session that cannot see it'
  );
});

// --- Readiness and the health check read the same gate ladder (Story 1.17, AD-45) -------------
//
// AD-45 calls the smoke path "also the health check", and the two must not be able to disagree
// about whether this instance is installed. They cannot, because both resolve through
// OcuPilot.Install.Installer.GateStatus -- the health check through `iris session`, readiness
// through a delegating class method. OcuPilot.Test.Readiness pins the ObjectScript half; this
// pins the shell half, which no %UnitTest class can read.
//
// The health check is deliberately not rewritten to call the endpoint: the pinned image ships no
// HTTP client at all (verified, Story 1.4), which is why the probe shells `iris session`.
//
// Mutation (Rule 19): give OcuPilot.Api.Readiness a gate ladder of its own, or make
// container-health.sh read the version row directly -> the matching assertion goes red.
test('container-health.sh and the readiness endpoint read the same gate ladder (AD-45)', () => {
  assert.match(
    healthHook,
    /##class\(OcuPilot\.Install\.Installer\)\.GateStatus\(\)/,
    'the health check asks the installer for the gate status'
  );
  // Asserted over the ObjectScript the probe actually pipes into `iris session`, not over the
  // whole file: the header comment legitimately explains why no HTTP client is used, and a rule
  // that read prose would forbid the explanation.
  const piped = [...healthHook.matchAll(/<<'?EOF'?\n([\s\S]*?)\nEOF\n/g)].map((m) => m[1]).join('\n');
  assert.ok(piped.length > 0, 'the health check pipes ObjectScript into iris session');
  assert.ok(
    !/curl|wget|HttpRequest/i.test(healthHook.split('\n').filter((l) => !/^\s*#/.test(l)).join('\n')),
    'and issues no HTTP request of its own: the pinned image ships no HTTP client'
  );

  const readiness = readFileSync(join(repoRoot, 'src', 'OcuPilot', 'Api', 'Readiness.cls'), 'utf8');
  assert.match(
    readiness,
    /##class\(OcuPilot\.Install\.Installer\)\.GateStatus\(\)/,
    'and the readiness endpoint asks the same method'
  );
});

// --- The client bundle's directory is the roster's, not a second spelling -------------------
//
// Story 1.16's intent says the roster is the sole declaration of the bundle source and that
// every consumer reads it -- but container-start.sh resolves BUNDLE_DIR before any OcuPilot
// class is compiled, so it necessarily restates the path in shell. Nothing held the two
// together: ipm-manifest.test.mjs pins the roster against angular.json's outputPath, so a
// build-output move takes the roster, the manifest and that test with it and leaves this
// script naming a directory that no longer exists. An absent bundle is a warn and never a
// failed start (this file's own contract for a clone whose client was never built), so the
// container would come up healthy and /ocupilot would answer 503 with no gate red anywhere.
test("container-start.sh's BUNDLE_DIR is the bundle source the roster declares", () => {
  const roster = readRoster(readFileSync(ROSTER_SOURCE, 'utf8'));
  assert.ok(roster, 'the shipped roster parses');

  const declared = roster.bundle.source.replace(/\/$/, '');
  const match = /^BUNDLE_DIR="([^"]+)"/m.exec(startHook);
  assert.ok(match, 'container-start.sh declares BUNDLE_DIR');
  assert.equal(
    match[1],
    `/opt/ocupilot/${declared}`,
    "the start hook's bundle directory is the roster's bundle.source under the container's source mount"
  );
});

// --- DW-48: a product start compiles no test class (AD-17) ------------------------------------
//
// The start hook compiles the roster's test-scope package only when PID 1's environment carries
// OCUPILOT_LOAD_TESTS=1. scripts/ci-throwaway.sh sets it for the suite; this repository's compose
// file does not, so a container started from it compiles no OcuPilot.Test class. These pin the
// wiring as text, and the throwaway's environment by running its `up` against a stub docker; what
// a product start actually compiled is counted by CI's images job (`ci-throwaway.sh product-check`).

/** The roster's test-scope `.PKG` resources, each as the folder under the sources root it names. */
function rosterTestFolders() {
  const roster = readRoster(readFileSync(ROSTER_SOURCE, 'utf8'));
  assert.ok(roster, 'the shipped roster parses');
  return roster.resources
    .filter((resource) => resource.scope === 'test')
    .map((resource) => ({ name: resource.name, folder: resource.name.replace(/\.PKG$/, '').split('.').join('/') }));
}

/** The start hook's lines that are code, not `#` comments. */
const startHookCode = startHook
  .split('\n')
  .filter((line) => !/^\s*#/.test(line))
  .join('\n');

// Mutation (Rule 19): set `OCUPILOT_LOAD_TESTS: "1"` in docker-compose.yml's environment -> red.
test('docker-compose.yml leaves OCUPILOT_LOAD_TESTS unset, so its start compiles no test class (DW-48)', () => {
  const settings = raw
    .split('\n')
    .filter((line) => !/^\s*#/.test(line))
    .filter((line) => line.includes('OCUPILOT_LOAD_TESTS'));
  assert.deepEqual(settings, [], 'the repository\'s compose file sets no OCUPILOT_LOAD_TESTS, in any form');
});

// Mutations (Rule 19): load "$SRC_DIR" again in the load-and-start session -> red at the LoadDir
// assertion. Compare the flag with `!=` -> red at the branch assertion. Name the test folder in the
// hook (`TEST_DIRS="OcuPilot/Test"`) -> red at the no-literal assertion. Drop `exit 1` from the
// roster outcome's FAILED arm -> red at the failure assertions.
test('the start hook leaves the roster\'s test-scope folder out of a start without OCUPILOT_LOAD_TESTS=1 (DW-48)', () => {
  // The flag, read from PID 1's own environment like OCUPILOT_DEMO and OCUPILOT_NAMESPACE.
  assert.match(
    startHookCode,
    /\nLOAD_TESTS_FLAG=\$\(tr '\\0' '\\n' < \/proc\/1\/environ 2>\/dev\/null \| grep '\^OCUPILOT_LOAD_TESTS=' \| cut -d= -f2-\)\n/,
    'the hook reads OCUPILOT_LOAD_TESTS from /proc/1/environ'
  );

  // The tree is the whole source unless the product branch replaces it, and only the literal "1"
  // keeps the whole tree.
  const defaultAt = startHookCode.indexOf('\nLOAD_DIR="$SRC_DIR"\n');
  const branchAt = startHookCode.indexOf('\nif [ "$LOAD_TESTS_FLAG" = "1" ]; then\n');
  assert.ok(defaultAt > 0, 'LOAD_DIR starts as the whole source tree');
  assert.ok(branchAt > defaultAt, 'and the branch after it keeps that tree only for a flag of exactly "1"');
  const branch = startHookCode.slice(branchAt, startHookCode.indexOf('\nfi\n', startHookCode.indexOf('\n    fi\n', branchAt)));
  const elseAt = branch.indexOf('\nelse\n');
  assert.ok(elseAt > 0, 'the flag check has a product branch');
  assert.ok(!branch.slice(0, elseAt).includes('LOAD_DIR='), 'a start with the flag at 1 keeps the whole tree');
  const product = branch.slice(elseAt);
  assert.match(product, /\n {8}LOAD_DIR="\$PRODUCT_SRC"\n/, 'a product start loads the copy instead');

  // The folders come from the roster, asked in the install namespace, through its own Get().
  assert.match(product, /SCOPE_RAW=\$\(iris session iris -U "\$INSTALL_NS" 2>&1 <<EOF\n/, 'the roster is asked in the install namespace, stderr captured');
  assert.match(product, /\$System\.OBJ\.Load\("\$SRC_DIR\/OcuPilot\/Install\/Roster\.cls", "ck-d"\)/, 'after compiling the roster this start ships');
  assert.match(product, /##class\(OcuPilot\.Install\.Roster\)\.Get\(\.tRoster\)/, 'through the roster\'s own reader');
  assert.match(product, /tRes\.scope = "test"/, 'keeping its test-scope resources');
  assert.match(product, /\$Translate\(\\\$Piece\(tRes\.name, "\.PKG", 1\), "\.", "\/"\)/, 'each package named as its folder');
  assert.match(product, /cp -R "\$SRC_DIR" "\$PRODUCT_SRC"/, 'the tree is copied');
  assert.match(product, /for TEST_DIR in \$TEST_DIRS; do/, 'and every folder the roster names');
  assert.match(product, /rm -rf "\$PRODUCT_SRC\/\$TEST_DIR" 2>&1/, 'is removed from the copy, stderr captured');

  // A roster that cannot be read, or that names no folder the tree carries, fails the start.
  // The session's verdict answers FAILED for an unread roster or a missing resources array
  // before its default OK arm, so an unreadable roster never reads as "no test package".
  const verdict = product.split('\n').find((line) => line.includes('"SCOPE-START:"'));
  assert.ok(verdict, 'the roster session writes one verdict line');
  assert.equal(verdict.split('"FAILED:').length - 1, 2, 'an unread roster and a missing resources array each answer FAILED');
  const okArm = verdict.indexOf('1: "OK:" _ tDirs)');
  assert.ok(okArm > verdict.lastIndexOf('"FAILED:'), 'and OK is the default arm, after both');
  const outcome = product.slice(product.indexOf('case "$SCOPE" in'), product.indexOf('\n    esac\n'));
  for (const arm of ['FAILED:*)', '*)']) {
    const at = outcome.indexOf(`\n        ${arm}\n`);
    assert.ok(at > 0, `the roster outcome has a ${arm} arm`);
    assert.match(outcome.slice(at, outcome.indexOf(';;', at)), /exit 1/, `and ${arm} fails the start`);
  }
  assert.match(product, /if \[ ! -d "\$PRODUCT_SRC\/\$TEST_DIR" \]; then\n[^\n]*\n\s*exit 1\n/, 'a folder the tree does not carry fails the start');

  // The load-and-start session compiles LOAD_DIR, never the source tree directly.
  assert.match(startHookCode, /\$System\.OBJ\.LoadDir\("\$LOAD_DIR", "ck", \.tErrors, 1\)/, 'LoadDir compiles the tree chosen above');
  assert.ok(!/LoadDir\("\$SRC_DIR"/.test(startHookCode), 'and no LoadDir names the whole source tree');
  assert.ok(startHookCode.indexOf('$System.OBJ.LoadDir(') > branchAt, 'and it runs after the choice');

  // A load error on either tree still fails the start: a LoadDir that does not answer OK is
  // reported LOAD-FAILED, and that arm exits 1.
  assert.match(
    startHookCode,
    /LoadDir\("\$LOAD_DIR", "ck", \.tErrors, 1\)\nSet tLoadOK = \\\$System\.Status\.IsOK\(tSC\)\n/,
    'the load\'s own status decides tLoadOK'
  );
  assert.match(startHookCode, /\nSet tOutcome = \\\$Select\(tLoadOK: [^\n]*, 1: "LOAD-FAILED:" _ tLoadErr\)\n/, 'a failed load is reported LOAD-FAILED');
  const loadFailed = startHookCode.indexOf('\n    LOAD-FAILED*)\n');
  assert.ok(loadFailed > 0, 'the start\'s result has a LOAD-FAILED arm');
  assert.match(startHookCode.slice(loadFailed, startHookCode.indexOf(';;', loadFailed)), /\n\s*exit 1\n/, 'and it fails the start');

  // The roster is the one source: the hook's code names none of its test-scope packages.
  const folders = rosterTestFolders();
  assert.ok(folders.length > 0, 'the roster declares a test-scope package');
  for (const { name, folder } of folders) {
    const pkg = name.replace(/\.PKG$/, '');
    assert.ok(!startHookCode.includes(folder), `the hook's code never names ${folder}; it reads it from the roster`);
    assert.ok(!startHookCode.includes(pkg), `nor ${pkg}`);
  }
});

// Mutation (Rule 19): rename a test-scope resource in the roster to a package with no folder
// (`OcuPilot.Tests.PKG`) -> red, which is the start the hook would then refuse.
test('every test-scope package the roster declares is a folder of the source tree (DW-48)', () => {
  const sourcesRoot = join(repoRoot, readRoster(readFileSync(ROSTER_SOURCE, 'utf8')).module.sourcesRoot);
  for (const { name, folder } of rosterTestFolders()) {
    assert.match(name, /\.PKG$/, `${name} is a package resource, the only kind the hook maps to a folder`);
    const at = join(sourcesRoot, folder);
    assert.ok(existsSync(at) && statSync(at).isDirectory(), `${name} names ${folder}, a folder under the sources root`);
  }
});

/**
 * The compose file `ci-throwaway.sh up` writes, run against a stub docker that answers every call
 * with success and removes nothing but what the script's own scrub asks for.
 */
function throwawayComposeFile(...args) {
  const dir = mkdtempSync(join(tmpdir(), 'ocupilot-load-tests-'));
  try {
    const bin = join(dir, 'bin');
    const scratch = join(dir, 'scratch');
    writeStub(bin, 'docker', ['exit 0']);
    const run = spawnSync('sh', [join(repoRoot, 'scripts', 'ci-throwaway.sh'), 'up', '--dir', scratch, ...args], {
      cwd: repoRoot,
      encoding: 'utf8',
      env: stubEnv(bin),
    });
    assert.equal(run.status, 0, `ci-throwaway.sh up ${args.join(' ')} failed: ${run.stdout}${run.stderr}`);
    return readFileSync(join(scratch, 'compose.yml'), 'utf8').split(scratch).join('<scratch>');
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

// Mutations (Rule 19): empty LOAD_TESTS_ENV's default in ci-throwaway.sh -> red at the first
// assertion. Make `--product` leave it set -> red at the second.
test('ci-throwaway.sh sets OCUPILOT_LOAD_TESTS to "1", and `--product` leaves only that out (DW-48)', () => {
  const suite = throwawayComposeFile();
  const iris = serviceBlock(suite, 'iris');
  assert.match(iris, /^ {6}OCUPILOT_LOAD_TESTS: "1"$/m, 'the suite\'s throwaway compiles the test package');

  const product = throwawayComposeFile('--product');
  assert.ok(!product.includes('OCUPILOT_LOAD_TESTS'), 'a --product throwaway carries no OCUPILOT_LOAD_TESTS');
  assert.equal(
    product,
    suite.replace(/^ {6}OCUPILOT_LOAD_TESTS: "1"$/m, '      '),
    'and differs from the suite\'s in that one line and nothing else'
  );
});

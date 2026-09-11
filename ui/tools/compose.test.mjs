import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// docker-compose.yml is YAML, not JSON (unlike angular.json's own precedent in this
// folder), so these are text-level assertions rather than a parsed-structure walk --
// the same shape check-objectscript.py already uses for its own line-oriented checks,
// and sufficient for what this story's AC1/AC2/AC3 actually pin: an explicit tag, no
// floating tag anywhere, the demo flag, the start-hook wiring and the health check.
//
// Mutations (Rule 19):
// - revert the image line to `intersystems/irishealth-community:latest-cd` -> the
//   "pinned tag" test and the "no floating tag" test both go red.
// - remove the `StartPath` invocation from scripts/container-start.sh, leaving the hook
//   running and calling nothing -> this file cannot observe that (a throwaway-container
//   run is what does, per the spec's own AC2 mutation); this suite only pins that the
//   compose file actually wires the hook and health check up, not that they succeed.
// - make scripts/container-start.sh ignore StartPath's result and always exit 0 -> same
//   caveat; the exit-code mapping is pinned by the throwaway-container run, not here.
// - restore `restart: unless-stopped` -> the restart-policy test goes red (DW-66). What the
//   policy does to a failing container is observed on a throwaway container, not here.
const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const composePath = join(repoRoot, 'docker-compose.yml');
const raw = readFileSync(composePath, 'utf8');

test('the image is pinned to an explicit 2026.2 tag', () => {
  assert.match(raw, /image:\s*intersystems\/irishealth-community:2026\.2\b/, 'expected an explicit 2026.2 tag');
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

test('the durable data mount is unchanged', () => {
  assert.match(raw, /-\s*\.\/iris-data:\/durable\b/, 'expected the existing durable-storage bind mount to survive untouched');
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
  assert.match(raw, /"52774:52773"/, 'expected the web port mapping to be unchanged -- ocupilot.code-workspace, .vscode/settings.json and Test/Http.cls all track it');
});

// DW-66 (the owner's decision, Story 1.4 rework iteration 6): a failed install makes the start
// hook exit non-zero and the container exit 1, so the restart policy decides what happens next.
// `unless-stopped` (and `always`) restart it forever, re-running a deterministic failure in a
// loop; `on-failure:N` retries N times and then leaves it stopped. Anchored to the `restart:` key
// itself, so the comment above that key in the compose file -- which names the old policy -- is
// not what this reads.
test('the restart policy retries a failed start a bounded number of times, then stops', () => {
  // A trailing YAML comment (`restart: on-failure:3  # why`) is not part of the value.
  const keys = [...raw.matchAll(/^\s*restart:\s*(.*?)\s*$/gm)].map((m) => m[1].replace(/\s+#.*$/, '').replace(/^["']|["']$/g, ''));
  assert.equal(keys.length, 1, `expected exactly one restart: key, found ${keys.length}`);
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

/**
 * What `tools/browser-reset.mjs` pins: a spec that opens a browser context either forgets the
 * signing-in account's remembered state first, or says in its own file why it does not.
 *
 * The check exists because Story 15.5 moved the six remembered things onto the instance (AD-50),
 * so a fresh `BrowserContext` no longer resets them and one spec's filter becomes another's
 * starting state. Needs nothing from the environment: every case here is a string.
 *
 * Mutations (Rule 19), each applied, observed red and reverted:
 * - drop the `resets < contexts` arm from `resetProblem` -> "a spec that opens a context and
 *   never resets is refused" goes red.
 * - make `declaredExemption` answer the marker's line without trimming -> "a bare marker is
 *   refused, because a reason must follow it" goes red.
 * - drop the `contexts === 0` guard -> "a file that opens no context is never a problem" goes red.
 * - compare `resets` and `contexts` with `> 0` instead of `>=` -> "two contexts and one reset is
 *   refused" goes red.
 * - drop `process.exit(1)` from `main()` -> "the script exits non-zero on a refusal" goes red.
 * - remove the checker from `prebuild`, from `prestart`, or from the pre-commit hook -> "the check
 *   is named in prebuild, in prestart and in the pre-commit hook, and can block" goes red.
 * - add a `preferences-reset-exempt:` marker to a third spec -> "exactly these specs are exempt"
 *   goes red.
 * - drop `DEFAULT_CONTEXT_CALL` from `resetProblem`'s `contexts` sum -> "a spec that takes the
 *   browser's default context is counted too" goes red.
 */

import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  BROWSER_DIR,
  CONTEXT_CALL,
  DEFAULT_CONTEXT_CALL,
  EXEMPT_MARKER,
  RESET_CALL,
  declaredExemption,
  occurrences,
  resetProblem,
  specFileNames,
} from './browser-reset.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(here, '..', '..');
const SCRIPT = join(here, 'browser-reset.mjs');

/**
 * The specs that clear this state themselves instead of calling the helper. Named here so a third
 * one is a red test rather than one more honored-exemption line nobody reads: opting a spec out is
 * the cheapest way to quiet this check, and it is the one thing the check cannot notice.
 */
const EXEMPT_SPECS = [
  'preferences-integration.browser-spec.mjs',
  'ui-state-survives-sign-out.browser-spec.mjs',
];

const OPENS = `const context = await browser.${CONTEXT_CALL});`;
const RESETS = `await ${RESET_CALL});`;

test('a spec that opens a context and resets first is accepted', () => {
  assert.equal(resetProblem('ok.browser-spec.mjs', `${RESETS}\n${OPENS}`), null);
});

test('a spec that opens a context and never resets is refused, naming the call', () => {
  const problem = resetProblem('forgot.browser-spec.mjs', OPENS);
  assert.notEqual(problem, null);
  assert.match(problem, /forgot\.browser-spec\.mjs/);
  assert.match(problem, /resetRememberedState/);
});

test('two contexts and one reset is refused -- the count is per context, not per file', () => {
  const problem = resetProblem('half.browser-spec.mjs', `${RESETS}\n${OPENS}\n${OPENS}`);
  assert.notEqual(problem, null, 'a context added to an already-passing spec is the regression to catch');
  assert.match(problem, /opens 2 browser context\(s\) but calls .* 1 time\(s\)/);
  assert.equal(resetProblem('whole.browser-spec.mjs', `${RESETS}\n${OPENS}\n${RESETS}\n${OPENS}`), null);
});

test('a spec that takes the browser\'s default context is counted too', () => {
  // Mutation (Rule 19): drop `DEFAULT_CONTEXT_CALL` from `resetProblem`'s `contexts` sum -> this
  // goes red, and a spec written with `browser.newPage()` passes the gate with no reset at all
  // while sharing the account's remembered rows with every other page in the run.
  const opensDefault = `const page = await ${DEFAULT_CONTEXT_CALL});`;
  const problem = resetProblem('default.browser-spec.mjs', opensDefault);
  assert.notEqual(problem, null, 'the default context is the least isolated one there is');
  assert.match(problem, /opens 1 browser context\(s\) but calls .* 0 time\(s\)/);
  assert.equal(resetProblem('default-ok.browser-spec.mjs', `${RESETS}\n${opensDefault}`), null);
  const mixed = resetProblem('mixed.browser-spec.mjs', `${RESETS}\n${OPENS}\n${opensDefault}`);
  assert.notEqual(mixed, null, 'one reset does not cover a fresh context and the default one');
  assert.match(mixed, /opens 2 browser context\(s\) but calls .* 1 time\(s\)/);
});

test('occurrences counts every hit, including adjacent ones', () => {
  assert.equal(occurrences('', CONTEXT_CALL), 0);
  assert.equal(occurrences(`${CONTEXT_CALL}${CONTEXT_CALL}`, CONTEXT_CALL), 2);
  assert.equal(occurrences(`a ${CONTEXT_CALL} b ${CONTEXT_CALL} c`, CONTEXT_CALL), 2);
});

test('a file that opens no context is never a problem, whatever else it contains', () => {
  assert.equal(resetProblem('helper.mjs', 'export function unrelated() {}'), null);
  assert.equal(resetProblem('reset.mjs', `export async function ${RESET_CALL}) {}`), null);
});

test('a declared exemption with a reason is accepted in place of the reset', () => {
  const source = ` * ${EXEMPT_MARKER} it is about the state surviving, so it clears its own rows.\n${OPENS}`;
  assert.equal(resetProblem('exempt.browser-spec.mjs', source), null);
  assert.equal(
    declaredExemption(source).reason,
    'it is about the state surviving, so it clears its own rows.'
  );
});

test('a bare marker is refused, because a reason must follow it on the same line', () => {
  const problem = resetProblem('bare.browser-spec.mjs', ` * ${EXEMPT_MARKER}\n${OPENS}`);
  assert.notEqual(problem, null);
  assert.match(problem, /no reason/);
});

test('declaring an exemption AND calling the reset is refused -- one or the other', () => {
  const source = ` * ${EXEMPT_MARKER} a reason.\n${RESETS}\n${OPENS}`;
  const problem = resetProblem('both.browser-spec.mjs', source);
  assert.notEqual(problem, null);
  assert.match(problem, /one or the other/);
});

test('a file declaring no exemption answers null rather than an empty reason', () => {
  assert.equal(declaredExemption('nothing here'), null);
});

test('the real browser directory passes its own check, and is not empty', () => {
  const dir = join(here, '..', BROWSER_DIR);
  const names = specFileNames(dir);
  assert.ok(names.length > 0, 'the browser directory has spec files -- a zero scan is not a pass');

  let opened = 0;
  for (const name of names) {
    const source = readFileSync(join(dir, name), 'utf8');
    if (source.includes(CONTEXT_CALL)) opened += 1;
    assert.equal(resetProblem(name, source), null, `${name} satisfies the reset check`);
  }
  assert.ok(opened > 0, 'at least one spec opens a browser context -- otherwise this pins nothing');
});

test('exactly these specs are exempt -- an opt-out is a red test, not a log line', () => {
  const dir = join(here, '..', BROWSER_DIR);
  const exempt = specFileNames(dir).filter(
    (name) => declaredExemption(readFileSync(join(dir, name), 'utf8')) !== null
  );
  assert.deepEqual(exempt, EXEMPT_SPECS);
});

// --- The script, and the gates it is wired into ---------------------------------------------

/** Run the checker with `cwd` at a throwaway tree holding exactly `files` under `browser/`. */
function runOver(files) {
  const root = mkdtempSync(join(tmpdir(), 'browser-reset-'));
  try {
    mkdirSync(join(root, BROWSER_DIR));
    for (const [name, source] of Object.entries(files)) {
      writeFileSync(join(root, BROWSER_DIR, name), source, 'utf8');
    }
    return spawnSync(process.execPath, [SCRIPT], { cwd: root, encoding: 'utf8' });
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

// The block that prints the refusals and exits non-zero is what every gate below depends on, and
// nothing above executes it: a reporting-only checker is indistinguishable from a blocking one
// until a commit slips through, which this project has already shipped once (ipm-manifest).
test('the script exits non-zero on a refusal, names the file, and reports what it scanned', () => {
  const run = runOver({ 'forgot.browser-spec.mjs': OPENS });
  assert.equal(run.status, 1, 'a refusal blocks');
  assert.match(run.stderr, /forgot\.browser-spec\.mjs/);
  assert.match(run.stdout, /scanned 1 file\(s\)/, 'and still says what it looked at');
});

test('the script exits zero on a clean tree and reports the exemptions it honored', () => {
  const run = runOver({
    'ok.browser-spec.mjs': `${RESETS}\n${OPENS}`,
    'exempt.browser-spec.mjs': ` * ${EXEMPT_MARKER} it is about the state surviving.\n${OPENS}`,
  });
  assert.equal(run.status, 0, `a clean tree passes: ${run.stderr}`);
  assert.match(run.stdout, /honored exemption -- exempt\.browser-spec\.mjs: it is about the state surviving\./);
  assert.match(run.stdout, /browser-reset: clean\./);
});

// Mutation (Rule 19): remove the browser-reset dispatch from .githooks/pre-commit -> this goes red.
test('the check is named in prebuild, in prestart and in the pre-commit hook, and can block', () => {
  const scripts = JSON.parse(readFileSync(join(here, '..', 'package.json'), 'utf8')).scripts;
  for (const [name, chain] of [
    ['prebuild', scripts.prebuild],
    ['prestart', scripts.prestart],
  ]) {
    const segments = chain.split('&&').map((segment) => segment.trim());
    assert.ok(segments.includes('node tools/browser-reset.mjs'), `${name} runs the check as a link of its own`);
    assert.doesNotMatch(chain, /browser-reset\.mjs[^&]*\|\|/, `${name} does not swallow its exit code`);
  }
  const hook = readFileSync(join(REPO_ROOT, '.githooks', 'pre-commit'), 'utf8');
  const trigger = hook.slice(hook.indexOf('if [ -n "$OS_TRIGGER" ]'));
  const block = trigger.slice(0, trigger.indexOf('\nfi\n'));
  assert.match(block, /node tools\/browser-reset\.mjs\)?\s*\|\|\s*STATUS=1/, 'the hook dispatches it inside OS_TRIGGER and feeds STATUS');
});

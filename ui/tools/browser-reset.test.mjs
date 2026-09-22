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
 * - drop the `RESET_IMPORT` arm from `resetProblem` -> "a spec that calls the reset but does not
 *   import it is refused" goes red. Demonstrated against the tree as well as the fixtures:
 *   deleting the import line from `browser/context-chip.browser-spec.mjs` made the CLI report
 *   1 refusal naming that file, and reverting it read clean again.
 * - delete the reset call from `browser/panel-spec.mjs` -> "the real browser directory passes its
 *   own check" and "the shipped tree resolves its helper-sourced specs" go red, and the CLI reports
 *   13 refusals: the 12 helper-sourced specs and the helper itself. Under the spelling-keyed
 *   checker it refused none, which is the under-detection DW-1448 names.
 * - restore `inspect()`'s `if (!source.includes(CONTEXT_CALL)) continue;` -> "the CLI refuses a spec
 *   written only with browser.newPage(", "the CLI refuses a helper-sourced spec whose helper does
 *   not reset" and "the shipped tree resolves its helper-sourced specs" go red: the file is skipped
 *   before `resetProblem` sees it, so both arms were unreachable from the gate `prebuild` runs.
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
  buildGraph,
  chargeFor,
  declaredExemption,
  inspect,
  occurrences,
  readSources,
  resetProblem,
  RESET_IMPORT,
  specFileNames,
} from './browser-reset.mjs';

/**
 * How many specs in the shipped tree take their context from an imported helper.
 *
 * A floor, not an equality: specs join and leave. Its job is that "the graph resolved nothing" --
 * an import shape it stopped recognising, a helper moved out of `ui/browser/` -- reads as a red
 * test rather than as a clean report, because a checker that resolves no edges is exactly as quiet
 * as one with nothing to resolve. 12 take their page from `panel-spec.mjs`'s `signedInAt` today.
 */
const HELPER_SOURCED_FLOOR = 12;

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
const RESET_ONLY = `await ${RESET_CALL});`;
// A real spec that resets also imports; the call alone is the `RESET_IMPORT` refusal below.
const RESETS = `import { resetRememberedState } ${RESET_IMPORT};\n${RESET_ONLY}`;

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
  assert.match(problem, /reaches 2 browser context\(s\) but reaches .* 1 time\(s\)/);
  assert.equal(resetProblem('whole.browser-spec.mjs', `${RESETS}\n${OPENS}\n${RESETS}\n${OPENS}`), null);
});

test('a spec that calls the reset but does not import it is refused, naming the import', () => {
  // The defect this arm exists for, from the 2026-09-21 Epic 15 integrate-forward: one side added
  // the call, the other side's import lost the merge, and the spec threw
  // `ReferenceError: resetRememberedState is not defined` on its first test. Both this checker and
  // `npm test` passed on it -- only the browser tier loads the file, so only CI saw it.
  const problem = resetProblem('unimported.browser-spec.mjs', `${RESET_ONLY}\n${OPENS}`);
  assert.notEqual(problem, null, 'counting the call without the import passes a file that cannot load');
  assert.match(problem, /unimported\.browser-spec\.mjs/);
  assert.match(problem, /does not import it/);
  assert.equal(resetProblem('imported.browser-spec.mjs', `${RESETS}\n${OPENS}`), null);
});

test('a spec that takes the browser\'s default context is counted too', () => {
  // Mutation (Rule 19): drop `DEFAULT_CONTEXT_CALL` from `resetProblem`'s `contexts` sum -> this
  // goes red, and a spec written with `browser.newPage()` passes the gate with no reset at all
  // while sharing the account's remembered rows with every other page in the run.
  const opensDefault = `const page = await ${DEFAULT_CONTEXT_CALL});`;
  const problem = resetProblem('default.browser-spec.mjs', opensDefault);
  assert.notEqual(problem, null, 'the default context is the least isolated one there is');
  assert.match(problem, /reaches 1 browser context\(s\) but reaches .* 0 time\(s\)/);
  assert.equal(resetProblem('default-ok.browser-spec.mjs', `${RESETS}\n${opensDefault}`), null);
  const mixed = resetProblem('mixed.browser-spec.mjs', `${RESETS}\n${OPENS}\n${opensDefault}`);
  assert.notEqual(mixed, null, 'one reset does not cover a fresh context and the default one');
  assert.match(mixed, /reaches 2 browser context\(s\) but reaches .* 1 time\(s\)/);
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
  const report = inspect(dir);
  assert.ok(report.names.length > 0, 'the browser directory has spec files -- a zero scan is not a pass');
  assert.deepEqual(report.problems, [], 'the shipped tree satisfies the reset check');
  assert.ok(report.withContext > 0, 'at least one spec reaches a browser context -- otherwise this pins nothing');
});

test('the shipped tree resolves its helper-sourced specs -- an empty graph is red, not clean', () => {
  const report = inspect(join(here, '..', BROWSER_DIR));
  assert.ok(
    report.viaHelper >= HELPER_SOURCED_FLOOR,
    `the graph resolved ${report.viaHelper} helper-sourced spec(s), under the floor of ${HELPER_SOURCED_FLOOR}; ` +
      'a checker that resolves no edges reports clean on a tree it has stopped reading'
  );
  const dir = join(here, '..', BROWSER_DIR);
  const graph = buildGraph(readSources(dir));
  const charge = chargeFor(
    'suggested-view.browser-spec.mjs',
    readFileSync(join(dir, 'suggested-view.browser-spec.mjs'), 'utf8'),
    graph
  );
  assert.equal(charge.direct.contexts, 0, 'it spells no context call of its own');
  assert.ok(charge.contexts > 0, 'and is still charged for the contexts its helper opens, through its own wrapper');
  assert.ok(charge.resets >= charge.contexts, 'which its helper also resets');
});

test('exactly these specs are exempt -- an opt-out is a red test, not a log line', () => {
  const dir = join(here, '..', BROWSER_DIR);
  const exempt = specFileNames(dir).filter(
    (name) => declaredExemption(readFileSync(join(dir, name), 'utf8')) !== null
  );
  assert.deepEqual(exempt, EXEMPT_SPECS);
});

/**
 * A two-file tree: `helper.mjs` exporting `signedInAt`, and a spec taking its page from it. The
 * helper's body decides whether the spec is refused, which is the whole of DW-1448.
 */
function helperTree(helperResets) {
  const reset = helperResets ? `  await ${RESET_CALL});\n` : '';
  return {
    'helper.mjs': `import { resetRememberedState } ${RESET_IMPORT};\n`
      + `export async function signedInAt(browser) {\n${reset}  const context = await browser.${CONTEXT_CALL});\n  return context;\n}\n`,
    'sourced.browser-spec.mjs': `import { signedInAt } from './helper.mjs';\n`
      + `test('one', async () => { await signedInAt(browser); });\n`,
  };
}

test('a spec whose helper does not reset is refused, though it spells no context call itself', () => {
  const files = helperTree(false);
  const graph = buildGraph(new Map(Object.entries(files)));
  const problem = resetProblem('sourced.browser-spec.mjs', files['sourced.browser-spec.mjs'], graph);
  assert.notEqual(problem, null, 'the spelling-keyed checker scored this spec zero contexts and waved it through');
  assert.match(problem, /sourced\.browser-spec\.mjs/);
  assert.match(problem, /reaches 1 browser context/);
});

test('a spec whose helper does reset is accepted, and needs no import of its own', () => {
  const files = helperTree(true);
  const graph = buildGraph(new Map(Object.entries(files)));
  assert.equal(resetProblem('sourced.browser-spec.mjs', files['sourced.browser-spec.mjs'], graph), null);
  assert.equal(resetProblem('helper.mjs', files['helper.mjs'], graph), null, 'and so is the helper itself');
});

test('an aliased import and a file-local wrapper are charged like a direct call', () => {
  const files = helperTree(false);
  files['wrapped.browser-spec.mjs'] =
    `import { signedInAt as shared } from './helper.mjs';\n`
    + `async function openAt(url) { return shared(browser, url); }\n`
    + `test('a', async () => { await openAt('/a'); });\n`
    + `test('b', async () => { await openAt('/b'); });\n`;
  const graph = buildGraph(new Map(Object.entries(files)));
  const charge = chargeFor('wrapped.browser-spec.mjs', files['wrapped.browser-spec.mjs'], graph);
  assert.equal(charge.contexts, 2, 'both wrapper call sites are charged, and the inner call is not charged twice');
  assert.notEqual(
    resetProblem('wrapped.browser-spec.mjs', files['wrapped.browser-spec.mjs'], graph),
    null,
    'an alias behind a wrapper is the shape that hid 12 specs from the old checker'
  );
});

test('a spelling inside a doc comment is not a call', () => {
  const commented = `/** Opens with browser.${CONTEXT_CALL}) somewhere else. */\nexport const NOTHING = 1;\n`;
  assert.equal(chargeFor('doc.mjs', commented, null).contexts, 0);
  assert.equal(chargeFor('url.mjs', `const u = 'https://example.test/x';\n`, null).contexts, 0);
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

// Mutation (Rule 19): restore `main()`'s `if (!source.includes(CONTEXT_CALL)) continue;` -> this
// goes red. That line skipped the file before `resetProblem` ever saw it, so the default-context
// arm was reachable only from a unit test and never from `prebuild`'s own run (DW-1448).
test('the CLI refuses a spec written only with browser.newPage(, not only resetProblem does', () => {
  const run = runOver({ 'default.browser-spec.mjs': `const page = await ${DEFAULT_CONTEXT_CALL});` });
  assert.equal(run.status, 1, 'the least isolated context there is, reached from the gate that runs');
  assert.match(run.stderr, /default\.browser-spec\.mjs/);
});

test('the CLI refuses a helper-sourced spec whose helper does not reset, and accepts one whose helper does', () => {
  const refused = runOver(helperTree(false));
  assert.equal(refused.status, 1, 'the graph is resolved by the CLI, not only by the unit test');
  assert.match(refused.stderr, /sourced\.browser-spec\.mjs/);
  const accepted = runOver(helperTree(true));
  assert.equal(accepted.status, 0, `a helper that resets clears its callers: ${accepted.stderr}`);
  assert.match(accepted.stdout, /through an imported helper/);
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

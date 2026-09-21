/**
 * What `tools/browser-reset.mjs` pins: a spec that opens a browser context either forgets the
 * signing-in account's remembered state first, or says in its own file why it does not.
 *
 * The check exists because Story 15.5 moved the six remembered things onto the instance (AD-50),
 * so a fresh `BrowserContext` no longer resets them and one spec's filter becomes another's
 * starting state. Needs nothing from the environment: every case here is a string.
 *
 * Mutations (Rule 19), each applied, observed red and reverted:
 * - drop the `!source.includes(RESET_CALL)` arm from `resetProblem` -> "a spec that opens a
 *   context and never resets is refused" goes red.
 * - make `declaredExemption` answer the marker's line without trimming -> "a bare marker is
 *   refused, because a reason must follow it" goes red.
 * - drop the `source.includes(CONTEXT_CALL)` guard -> "a file that opens no context is never a
 *   problem" goes red.
 */

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import test from 'node:test';

import {
  BROWSER_DIR,
  CONTEXT_CALL,
  EXEMPT_MARKER,
  RESET_CALL,
  declaredExemption,
  resetProblem,
  specFileNames,
} from './browser-reset.mjs';

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
  const dir = join(process.cwd(), BROWSER_DIR);
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

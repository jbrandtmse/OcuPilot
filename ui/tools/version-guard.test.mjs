import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { checkVersions, NODE_RANGE_LABEL, TYPESCRIPT_RANGE_LABEL } from './version-guard.mjs';

const packageJsonPath = join(dirname(fileURLToPath(import.meta.url)), '..', 'package.json');
const packageJson = JSON.parse(readFileSync(packageJsonPath, 'utf8'));

const npmrcPath = join(dirname(fileURLToPath(import.meta.url)), '..', '.npmrc');
const npmrc = readFileSync(npmrcPath, 'utf8');

// Pins the Task item's own stated purpose: engine-strict makes `npm ci`/`npm install`
// fail outright on an unsupported Node version rather than only warn, and save-exact
// stops a later `npm i` from re-floating the exact typescript pin asserted above.
// Neither behavior is exercised elsewhere -- the assertions above call `checkVersions`
// directly and never read `.npmrc` -- so a regression here (e.g. someone "cleaning up"
// the file to `engine-strict=false`) would otherwise go unnoticed until an actual
// install on the wrong Node version silently succeeded.
// Story 1.17's own Always-constraint: every gate CI runs reports the size of what it looked at,
// so "found nothing wrong" and "looked at nothing" are distinguishable. `checkVersions` was one
// of two prebuild gates that reported neither, and a guard that had evaluated no constraint
// printed the same line as one that passed.
//
// Mutation (Rule 19): stop incrementing `checked`, or drop it from the result -> this goes red.
test('the guard reports how many constraints it evaluated, not only that it passed', () => {
  const ok = checkVersions({ node: '22.22.3', typescript: '6.0.3' });
  assert.equal(ok.checked, 2, 'both the Node and the TypeScript constraint were evaluated');
  const bad = checkVersions({ node: '20.19.5', typescript: '5.9.2' });
  assert.equal(bad.checked, 2, 'and a failing run reports the same population it looked at');
  assert.ok(bad.checked > 0, 'a run that evaluated nothing is distinguishable from one that passed');
});

test('.npmrc sets engine-strict=true, so npm ci fails outright on an unsupported Node version', () => {
  assert.ok(/^engine-strict=true$/m.test(npmrc), `expected "engine-strict=true" in ${npmrcPath}, got: ${JSON.stringify(npmrc)}`);
});

test('.npmrc sets save-exact=true, so a later npm install cannot re-float the typescript pin', () => {
  assert.ok(/^save-exact=true$/m.test(npmrc), `expected "save-exact=true" in ${npmrcPath}, got: ${JSON.stringify(npmrc)}`);
});

test('typescript in package.json is pinned exactly \u2014 no caret, no tilde', () => {
  const declared = packageJson.devDependencies.typescript;
  assert.ok(
    /^\d+\.\d+\.\d+$/.test(declared),
    `expected an exact "X.Y.Z" version for typescript, got ${JSON.stringify(declared)} \u2014 ` +
      'a floated range would let a later npm install re-float the pin `.npmrc`\'s ' +
      'save-exact only guards new installs, not an already-written range'
  );
});

test('the declared typescript version itself satisfies the supported range', () => {
  const declared = packageJson.devDependencies.typescript;
  const result = checkVersions({ node: '26.8.1', typescript: declared });
  assert.equal(result.ok, true, `package.json's pinned typescript ${declared} must itself be within ${TYPESCRIPT_RANGE_LABEL}`);
});

test('Node 20.19.5 is not ok and names the required range', () => {
  const result = checkVersions({ node: '20.19.5', typescript: '6.0.3' });
  assert.equal(result.ok, false);
  assert.ok(
    result.errors.some((e) => e.includes(NODE_RANGE_LABEL)),
    `expected an error naming ${NODE_RANGE_LABEL}, got: ${JSON.stringify(result.errors)}`
  );
});

test('TypeScript 5.9.2 is not ok and names the required range', () => {
  const result = checkVersions({ node: '26.8.1', typescript: '5.9.2' });
  assert.equal(result.ok, false);
  assert.ok(
    result.errors.some((e) => e.includes(TYPESCRIPT_RANGE_LABEL)),
    `expected an error naming ${TYPESCRIPT_RANGE_LABEL}, got: ${JSON.stringify(result.errors)}`
  );
});

test('TypeScript 7.0.1 is not ok and names the required range', () => {
  const result = checkVersions({ node: '26.8.1', typescript: '7.0.1' });
  assert.equal(result.ok, false);
  assert.ok(
    result.errors.some((e) => e.includes(TYPESCRIPT_RANGE_LABEL)),
    `expected an error naming ${TYPESCRIPT_RANGE_LABEL}, got: ${JSON.stringify(result.errors)}`
  );
});

test('Node 26.8.1 and TypeScript 6.0.3 together are ok', () => {
  const result = checkVersions({ node: '26.8.1', typescript: '6.0.3' });
  // The whole shape, deliberately: a field added to the result is a field this gate now reports
  // and nothing else reads, so it should have to be stated here. `checked` is the population
  // count Story 1.17 added.
  assert.deepEqual(result, { ok: true, errors: [], checked: 2 });
});

test('the three supported Node caret bands are each accepted at their floor', () => {
  for (const floor of ['22.22.3', '24.15.0', '26.0.0']) {
    const result = checkVersions({ node: floor, typescript: '6.0.3' });
    assert.equal(result.ok, true, `expected Node ${floor} to be accepted`);
  }
});

test('a Node version just below each caret floor is rejected', () => {
  assert.equal(checkVersions({ node: '22.22.2', typescript: '6.0.3' }).ok, false);
  assert.equal(checkVersions({ node: '24.14.9', typescript: '6.0.3' }).ok, false);
  assert.equal(checkVersions({ node: '25.9.9', typescript: '6.0.3' }).ok, false);
});

test('TypeScript 6.1.0 (the next minor) is rejected \u2014 the pin is exact to the 6.0.x band', () => {
  assert.equal(checkVersions({ node: '26.8.1', typescript: '6.1.0' }).ok, false);
});

test('both a bad Node and a bad TypeScript version are reported together', () => {
  const result = checkVersions({ node: '20.19.5', typescript: '7.0.1' });
  assert.equal(result.ok, false);
  assert.equal(result.errors.length, 2);
});

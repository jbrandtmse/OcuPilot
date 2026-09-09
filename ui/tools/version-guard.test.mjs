import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { checkVersions, NODE_RANGE_LABEL, TYPESCRIPT_RANGE_LABEL } from './version-guard.mjs';

const packageJsonPath = join(dirname(fileURLToPath(import.meta.url)), '..', 'package.json');
const packageJson = JSON.parse(readFileSync(packageJsonPath, 'utf8'));

test('typescript in package.json is pinned exactly — no caret, no tilde', () => {
  const declared = packageJson.devDependencies.typescript;
  assert.ok(
    /^\d+\.\d+\.\d+$/.test(declared),
    `expected an exact "X.Y.Z" version for typescript, got ${JSON.stringify(declared)} — ` +
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
  assert.deepEqual(result, { ok: true, errors: [] });
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

test('TypeScript 6.1.0 (the next minor) is rejected — the pin is exact to the 6.0.x band', () => {
  assert.equal(checkVersions({ node: '26.8.1', typescript: '6.1.0' }).ok, false);
});

test('both a bad Node and a bad TypeScript version are reported together', () => {
  const result = checkVersions({ node: '20.19.5', typescript: '7.0.1' });
  assert.equal(result.ok, false);
  assert.equal(result.errors.length, 2);
});

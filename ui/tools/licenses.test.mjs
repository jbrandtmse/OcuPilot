import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import { NOTICES_DIR, SEPARATOR, harvestedNotices, shipLicenses } from './licenses.mjs';

// Pins the licence step for ported code (Story 19.7): `shipLicenses` copies the build's extracted
// notices into the served root and appends every `ui/licenses/*.txt`, in name order, each closed by
// the extractor's separator; iris-table-editor's notice carries its MIT copyright line and full text;
// and ATTRIBUTIONS.md names the project, its copyright line and its notice file.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const repoRoot = join(uiRoot, '..');

const COPYRIGHT = 'Copyright (c) 2026 InterSystems Community';

/** A dist directory holding an extracted notices file and a served root, and a notices directory. */
function fixture() {
  const root = mkdtempSync(join(tmpdir(), 'ocupilot-licenses-'));
  const dist = join(root, 'dist');
  const notices = join(root, 'licenses');
  mkdirSync(join(dist, 'browser'), { recursive: true });
  mkdirSync(notices);
  writeFileSync(join(dist, '3rdpartylicenses.txt'), `\n${SEPARATOR}\nPackage: example\nLicense: "MIT"\n\nText.\n\n${SEPARATOR}\n`);
  return { root, dist, notices };
}

// Mutation (Rule 19): drop the append from `shipLicenses` -> the served copy lacks the notices and
// this goes red.
test('the served notices are the extracted file followed by each ported project\'s notice, in name order', () => {
  const { root, dist, notices } = fixture();
  try {
    writeFileSync(join(notices, 'b-project.txt'), 'Package: b\nLicense: "MIT"\n\nB text.\n\n\n');
    writeFileSync(join(notices, 'a-project.txt'), 'Package: a\nLicense: "MIT"\n\nA text.\n');
    writeFileSync(join(notices, 'ignored.md'), 'not a notice');
    const target = shipLicenses(dist, notices);
    const extracted = readFileSync(join(dist, '3rdpartylicenses.txt'), 'utf8');
    assert.equal(
      readFileSync(target, 'utf8'),
      `${extracted}Package: a\nLicense: "MIT"\n\nA text.\n\n${SEPARATOR}\nPackage: b\nLicense: "MIT"\n\nB text.\n\n${SEPARATOR}\n`
    );
    assert.equal(harvestedNotices(join(root, 'absent')), '', 'no notices directory appends nothing');
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('an absent or empty extracted file still fails the step', () => {
  const { root, dist, notices } = fixture();
  try {
    writeFileSync(join(dist, '3rdpartylicenses.txt'), '');
    assert.throws(() => shipLicenses(dist, notices), /absent or empty/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("iris-table-editor's notice carries its MIT copyright line and full text, and ATTRIBUTIONS.md names it", () => {
  const notice = readFileSync(join(NOTICES_DIR, 'iris-table-editor.txt'), 'utf8');
  const license = notice.slice(notice.indexOf('MIT License'));
  assert.ok(notice.startsWith('Package: iris-table-editor\nLicense: "MIT"\n'), 'headed as the extractor heads a package');
  assert.ok(license.includes(COPYRIGHT), 'its copyright line');
  assert.ok(license.includes('Permission is hereby granted, free of charge'), 'the grant');
  assert.ok(license.includes('THE SOFTWARE IS PROVIDED "AS IS"'), 'and the disclaimer');
  const attributions = readFileSync(join(repoRoot, 'ATTRIBUTIONS.md'), 'utf8');
  const row = attributions.split('\n').find((line) => line.startsWith('| iris-table-editor v0.2.3'));
  assert.ok(row !== undefined, 'ATTRIBUTIONS.md has a Harvested code row for iris-table-editor');
  assert.ok(row.includes(COPYRIGHT) && row.includes('MIT') && row.includes('ui/licenses/iris-table-editor.txt'), row);
  assert.ok(attributions.includes(license.trim().split('\n').slice(0, 3).join('\n')), 'and carries the license text');
});

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import { CREDENTIAL_EXACT_NAMES, CREDENTIAL_SUFFIXES } from './field-lists.mjs';

// DW-399: the client's build-time credential classifier (`field-lists.mjs`'s `CREDENTIAL_RE`,
// built from the two exported arrays this file checks) and the server's log-line backstop
// (`OcuPilot.Kernel.Audit.Log`'s `CREDENTIALSUFFIXES` and `CREDENTIALEXACTNAMES` parameters) name
// the same secret-shaped fields. Nothing calls the instance here -- both lists are read straight
// off the checked-in source, so this test needs nothing but the checkout, and it fails naming the
// difference the moment either side is edited without the other.

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const LOG_CLASS_PATH = join(REPO_ROOT, 'src', 'OcuPilot', 'Kernel', 'Audit', 'Log.cls');

/** The comma-separated string value of `Parameter <name> = "...";` in `text`, split on commas. */
function parameterList(text, name) {
  const re = new RegExp(`Parameter ${name}\\s*=\\s*"([^"]*)"\\s*;`);
  const match = re.exec(text);
  if (match === null) {
    throw new Error(`${LOG_CLASS_PATH}: no Parameter ${name} found`);
  }
  return match[1]
    .split(',')
    .map((entry) => entry.trim())
    .filter((entry) => entry !== '');
}

function sameMembers(actual, expected) {
  const actualSorted = [...actual].sort();
  const expectedSorted = [...expected].sort();
  assert.deepEqual(actualSorted, expectedSorted);
}

test('the client credential suffixes equal Log.cls CREDENTIALSUFFIXES', () => {
  const text = readFileSync(LOG_CLASS_PATH, 'utf8');
  const serverSuffixes = parameterList(text, 'CREDENTIALSUFFIXES');
  sameMembers(CREDENTIAL_SUFFIXES, serverSuffixes);
});

test('the client exact credential names equal Log.cls CREDENTIALEXACTNAMES', () => {
  const text = readFileSync(LOG_CLASS_PATH, 'utf8');
  const serverExactNames = parameterList(text, 'CREDENTIALEXACTNAMES');
  sameMembers(CREDENTIAL_EXACT_NAMES, serverExactNames);
});

/**
 * Story 9.10's refusal sentences are one published sentence each (AD-39, AD-53's idiom): every
 * `AUDITEVENT.*` violation code `OcuPilot.Api.Error.AuditEventViolationCodes` lists carries a
 * `REASONAUDITEVENT*` parameter in `src/OcuPilot/Api/Error.cls`, and that sentence is a key's value in
 * `strings.ts` and a literal of EXPERIENCE.md's Fixed strings table. Neither file is readable from the
 * other at run time, so the comparison lives here, where both are on disk.
 *
 * The 422 envelope's own `REASONAUDITEVENTVALIDATION` is not a violation code: it stands for a list
 * of refusals, and a form renders the violations rather than it.
 *
 * Mutation (Rule 19): change one word of `REASONAUDITEVENTTAKEN` -> the first test goes red naming both.
 */

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

const ERROR = join(REPO_ROOT, 'src', 'OcuPilot', 'Api', 'Error.cls');

const STRINGS_SOURCE = join(REPO_ROOT, 'ui', 'src', 'app', 'core', 'strings.ts');

const EXPERIENCE = join(REPO_ROOT, '_bmad-output', 'planning-artifacts', 'ux-designs', 'ux-OcuPilot-2026-09-08', 'EXPERIENCE.md');

/** Each violation code's parameter name in `Error.cls`, against the `strings.ts` key publishing its sentence. */
const PAIRS = [
  ['AUDITEVENTPARTREQUIRED', 'auditEventRefusalPartRequired'],
  ['AUDITEVENTPARTLENGTH', 'auditEventRefusalPartLength'],
  ['AUDITEVENTPARTSLASH', 'auditEventRefusalPartSlash'],
  ['AUDITEVENTPARTRESERVED', 'auditEventRefusalPartReserved'],
  ['AUDITEVENTDESCRIPTIONLENGTH', 'auditEventRefusalDescriptionLength'],
  ['AUDITEVENTEVENTNAMESHAPE', 'auditEventRefusalEventNameShape'],
  ['AUDITEVENTSYSTEM', 'auditEventRefusalSystem'],
  ['AUDITEVENTUSER', 'auditEventRefusalUser'],
  ['AUDITEVENTTAKEN', 'auditEventRefusalTaken'],
  ['AUDITEVENTABSENT', 'auditEventRefusalAbsent'],
];

const errorSource = readFileSync(ERROR, 'utf8');

/** The value `Parameter name` holds in `Error.cls`. */
function serverValue(name) {
  const match = new RegExp(`^Parameter ${name} = "([^"]*)";$`, 'm').exec(errorSource);
  assert.notEqual(match, null, `Error.cls declares ${name}`);
  return match[1].replace(/""/g, '"');
}

/** The value `key` holds in `strings.ts`, which may sit on the line after its key. */
function stringValue(key) {
  const source = readFileSync(STRINGS_SOURCE, 'utf8');
  const match = new RegExp(`\\b${key}:\\s*\\n?\\s*'((?:[^'\\\\]|\\\\.)*)'`).exec(source);
  assert.notEqual(match, null, `strings.ts carries ${key}`);
  return match[1].replace(/\\'/g, "'").replace(/\\\\/g, '\\');
}

test('Story 9.10: each AUDITEVENT reason is its strings.ts value and a Fixed-strings literal, byte for byte', () => {
  const experience = readFileSync(EXPERIENCE, 'utf8');
  for (const [parameter, key] of PAIRS) {
    const server = serverValue(`REASON${parameter}`);
    assert.equal(server, stringValue(key), `REASON${parameter} and ${key} are one sentence`);
    assert.ok(experience.includes(`"${server}"`), `EXPERIENCE.md's Fixed strings publish ${JSON.stringify(server)}`);
    assert.ok(!server.toLowerCase().includes('agent'), `REASON${parameter} names no caller`);
  }
});

test('Story 9.10: the pairs above are exactly the codes AuditEventViolationCodes lists', () => {
  const body = /ClassMethod AuditEventViolationCodes\(\) As %List\s*\{\s*Quit \$ListBuild\(([^)]*)\)/.exec(errorSource);
  assert.notEqual(body, null, 'Error.cls declares AuditEventViolationCodes');
  const listed = [...body[1].matchAll(/\.\.#([A-Z]+)/g)].map((match) => match[1]).sort();
  assert.deepEqual(listed, PAIRS.map(([parameter]) => parameter).sort());
});

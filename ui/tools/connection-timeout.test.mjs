/**
 * Story 10.5's two Test connection timeout reasons are one published sentence each (AD-39, AD-53's
 * idiom): the server's `REASONTESTTIMEOUT` and `REASONTESTTIMEOUTLOCAL` in
 * `src/OcuPilot/Kernel/Provider/Base.cls`, and the client's `agentDefinitionTestTimeout` and
 * `agentDefinitionTestTimeoutLocal` in `strings.ts`, which `strings.test.mjs` holds to EXPERIENCE.md's
 * Fixed strings table. Neither file is readable from the other at run time, so the comparison lives
 * here, where both are on disk.
 *
 * Mutation (Rule 19): change one word of `REASONTESTTIMEOUT` -> the first test goes red naming both.
 */

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

const BASE = join(REPO_ROOT, 'src', 'OcuPilot', 'Kernel', 'Provider', 'Base.cls');

const STRINGS_SOURCE = join(REPO_ROOT, 'ui', 'src', 'app', 'core', 'strings.ts');

/** The value `Parameter name` holds in `Base.cls`. */
function serverReason(name) {
  const match = new RegExp(`^Parameter ${name} = "([^"]*)";$`, 'm').exec(readFileSync(BASE, 'utf8'));
  assert.notEqual(match, null, `Base.cls declares ${name}`);
  return match[1];
}

/** The value `key` holds in `strings.ts`, which may sit on the line after its key. */
function stringValue(key) {
  const source = readFileSync(STRINGS_SOURCE, 'utf8');
  const match = new RegExp(`\\b${key}:\\s*\\n?\\s*'((?:[^'\\\\]|\\\\.)*)'`).exec(source);
  assert.notEqual(match, null, `strings.ts carries ${key}`);
  return match[1].replace(/\\'/g, "'").replace(/\\\\/g, '\\');
}

test('Story 10.5: the non-local timeout reason is the published sentence, byte for byte', () => {
  const server = serverReason('REASONTESTTIMEOUT');
  assert.equal(server, stringValue('agentDefinitionTestTimeout'), "the server's reason and the client's copy are one sentence");
  assert.ok(server.includes('<n>'), `it carries the seconds placeholder: ${server}`);
  assert.ok(server.includes('<provider>'), `and the provider placeholder: ${server}`);
});

test('Story 10.5: the local timeout reason is the published sentence, byte for byte', () => {
  const server = serverReason('REASONTESTTIMEOUTLOCAL');
  assert.equal(server, stringValue('agentDefinitionTestTimeoutLocal'), "the server's reason and the client's copy are one sentence");
  assert.ok(server.includes('<n>'), `it carries the seconds placeholder: ${server}`);
  assert.ok(!server.includes('<provider>'), `and names no provider: ${server}`);
});

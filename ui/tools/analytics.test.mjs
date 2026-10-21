/**
 * Story 20.11's Analytics sentence, held to the instance's own source (AD-29, AD-39, AD-65).
 *
 * `OcuPilot.Api.AnalyticsError`'s sentence is one published string on three surfaces: the server sends it, the client's strings table
 * holds it, and EXPERIENCE.md's Fixed strings publish it. The port also declares the pair sets its screens' descriptors repeat, and the
 * endpoint list the mirror generator reads.
 */

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

const PORT = join(REPO_ROOT, 'src', 'OcuPilot', 'Port', 'AnalyticsPort.cls');

const ERROR = join(REPO_ROOT, 'src', 'OcuPilot', 'Api', 'AnalyticsError.cls');

const STRINGS_SOURCE = join(REPO_ROOT, 'ui', 'src', 'app', 'core', 'strings.ts');

const EXPERIENCE = join(REPO_ROOT, '_bmad-output', 'planning-artifacts', 'ux-designs', 'ux-OcuPilot-2026-09-08', 'EXPERIENCE.md');

/** Every `<parameter>` sentence `AnalyticsError` declares, and the `strings.ts` key it is pinned equal to. */
const SENTENCES = [['REASONNAMESPACE', 'analyticsRefusalNamespace']];

/** The value `key` holds in `strings.ts`, which may sit on the line after its key. */
function stringValue(key) {
  const source = readFileSync(STRINGS_SOURCE, 'utf8');
  const match = new RegExp(`\\b${key}:\\s*\\n?\\s*'((?:[^'\\\\]|\\\\.)*)'`).exec(source);
  assert.notEqual(match, null, `strings.ts carries ${key}`);
  return match[1].replace(/\\'/g, "'").replace(/\\\\/g, '\\');
}

/** The sentence `parameter` holds in `AnalyticsError.cls`. */
function serverSentence(parameter) {
  const match = new RegExp(`Parameter ${parameter} = "([^"]+)";`).exec(readFileSync(ERROR, 'utf8'));
  assert.notEqual(match, null, `AnalyticsError.cls declares ${parameter}`);
  return match[1];
}

test('Story 20.11: the Analytics refusal is one sentence on both surfaces, published in Fixed strings', () => {
  // Mutation (Rule 19): change one word of REASONNAMESPACE in AnalyticsError.cls -> this goes red naming both.
  const experience = readFileSync(EXPERIENCE, 'utf8');
  for (const [parameter, key] of SENTENCES) {
    const server = serverSentence(parameter);
    assert.equal(server, stringValue(key), `${parameter} and ${key} are one published sentence`);
    assert.ok(experience.includes(`"${server}"`), `${parameter}'s sentence is published in EXPERIENCE.md's Fixed strings`);
    assert.ok(!server.toLowerCase().includes('agent'), `${parameter} names no caller: ${server}`);
  }
});

test('Story 20.11: the port declares its three pair sets and the endpoints the mirror reads', () => {
  // Mutation (Rule 19): drop %DeepSee_PortalEdit:USE from TERMLISTPAIRS in AnalyticsPort.cls -> this goes red.
  const port = readFileSync(PORT, 'utf8');
  const parameter = (name) => {
    const match = new RegExp(`^Parameter ${name} = "([^"]*)";`, 'm').exec(port);
    assert.notEqual(match, null, `AnalyticsPort.cls declares ${name}`);
    return match[1];
  };
  assert.equal(parameter('PORTALPAIRS'), '%DeepSee_Portal:USE');
  assert.equal(parameter('TERMLISTPAIRS'), '%DeepSee_Portal:USE,%DeepSee_PortalEdit:USE');
  assert.equal(parameter('FOLDERPAIRS'), '%DeepSee_Portal:USE,%Development:USE');
  assert.equal(parameter('ENDPOINTS'), 'Cubes,Measures,Dimensions,Relationships,TermLists,TermListEntries,FolderItems');
  assert.equal(parameter('TYPELIST'), 'LIST');
});

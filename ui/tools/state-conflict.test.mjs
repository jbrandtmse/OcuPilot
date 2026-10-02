/**
 * The Switches page and the agent definition form answer their 409 fixtures with a
 * `CONFLICT_ENVELOPE_REASON` constant that transcribes `REASONSTATECONFLICT` from
 * `src/OcuPilot/Api/Error.cls`, and assert that their screen never renders it. This holds each
 * transcription equal to the server's value, as `compose.test.mjs` holds a port, so the fixtures
 * carry the reason the server sends.
 *
 * Mutation (Rule 19): change one word of `REASONSTATECONFLICT` -> red naming both spec files.
 */

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

const SPECS = ['ui/src/app/areas/agent/switches.page.spec.ts', 'ui/src/app/areas/agent/definition-form.page.spec.ts'];

/** The value `Parameter name` holds in `Error.cls`. */
function serverValue(name) {
  const source = readFileSync(join(REPO_ROOT, 'src', 'OcuPilot', 'Api', 'Error.cls'), 'utf8');
  const match = new RegExp(`^Parameter ${name} = "([^"]*)";$`, 'm').exec(source);
  assert.notEqual(match, null, `Error.cls declares ${name}`);
  return match[1].replace(/""/g, '"');
}

test('each component spec transcribes the STATE.CONFLICT reason exactly as the server writes it', () => {
  const server = serverValue('REASONSTATECONFLICT');
  const drifted = [];
  for (const spec of SPECS) {
    const match = /const CONFLICT_ENVELOPE_REASON =\s*'((?:[^'\\]|\\.)*)';/.exec(readFileSync(join(REPO_ROOT, spec), 'utf8'));
    assert.notEqual(match, null, `${spec} declares CONFLICT_ENVELOPE_REASON`);
    if (match[1].replace(/\\'/g, "'") !== server) drifted.push(spec);
  }
  assert.deepEqual(drifted, [], `CONFLICT_ENVELOPE_REASON differs from Error.cls REASONSTATECONFLICT in ${drifted.join(' and ')}`);
});

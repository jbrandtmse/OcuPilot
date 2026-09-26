import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the client's spelling of OcuPilot's own marker event (Story 7.11) against the two server
// declarations it is built from: `Kernel/State/Base.cls`'s audit Source and Type and
// `Kernel/Audit/Event.cls`'s `EVENTAGENTWRITE`, read from the files. The User events list's
// marker-row warning and delete advisory key on it, so a drifted literal would silently drop both.
//
// Mutation (Rule 19): respell `AGENT_WRITE_EVENT` in `core/agent-status.ts` -> this test goes red.

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const { AGENT_WRITE_EVENT } = await import(join(repoRoot, 'ui', 'src', 'app', 'core', 'agent-status.ts'));

/** The string value `Parameter <name>` declares in `source`, or `null` when it declares none. */
function parameter(source, name) {
  const match = source.match(new RegExp(`^Parameter ${name}(?: As [%\\w.]+)? = "([^"]*)";`, 'm'));
  return match === null ? null : match[1];
}

test('the marker event the client names is the one the server registers', () => {
  const base = readFileSync(join(repoRoot, 'src', 'OcuPilot', 'Kernel', 'State', 'Base.cls'), 'utf8');
  const event = readFileSync(join(repoRoot, 'src', 'OcuPilot', 'Kernel', 'Audit', 'Event.cls'), 'utf8');
  const source = parameter(base, 'AUDITSOURCE');
  const type = parameter(base, 'AUDITTYPE');
  const name = parameter(event, 'EVENTAGENTWRITE');
  for (const [label, value] of [['AUDITSOURCE', source], ['AUDITTYPE', type], ['EVENTAGENTWRITE', name]]) {
    assert.ok(value !== null && value !== '', `${label} is declared as a non-empty string`);
  }
  assert.equal(AGENT_WRITE_EVENT, `${source}/${type}/${name}`, 'Source/Type/Name, as the User events list reports it');
});

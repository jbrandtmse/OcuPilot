/**
 * The authorization server editor pre-ticks the customization roles of a new configuration, and the
 * server reads a create's stored roles from `Defaults()` (Story 18.29, DW-1662). A principal holding
 * only the tab's two pairs creates with the pre-ticked roles only if the three lists are one list:
 * the client's `NEW_HELD.roles`, the rules' `Defaults()` and the roles the wire test posts. This holds
 * them equal, as `state-conflict.test.mjs` holds a reason, so a role added to one and not the others
 * reddens here rather than as a 422 on a user's first Save.
 *
 * Mutation (Rule 19): add a role to `Defaults()` in `OAuthAuthorizationServerRules.cls` -> red naming
 * the server; the same on `NEW_HELD.roles` or in the wire test's `TestALeastPrivilegedPrincipalCreatesWithTheDefaultRoles`
 * -> red naming that file.
 */

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

const STORE = 'ui/src/app/areas/security/oauth-server-form.store.ts';
const RULES = 'src/OcuPilot/Area/Security/OAuthAuthorizationServerRules.cls';
const WIRE = 'src/OcuPilot/Test/OAuthAuthorizationServerWire.cls';

function read(path) {
  return readFileSync(join(REPO_ROOT, path), 'utf8');
}

/** The names in the quoted list `text` holds, in order. */
function names(text) {
  return [...text.matchAll(/["']([^"']+)["']/g)].map((match) => match[1]);
}

/** The list the single match of `pattern` captures in `source`. */
function listOf(source, pattern, label) {
  const matches = [...source.matchAll(pattern)];
  assert.equal(matches.length, 1, `${label} is declared exactly once`);
  return names(matches[0][1]);
}

test("the client's pre-ticked roles, the server's create defaults and the wire test's posted roles are one list", () => {
  const client = listOf(read(STORE), /^ {2}roles: \[([^\]]*)\],$/gm, `${STORE} NEW_HELD.roles`);
  const server = listOf(read(RULES), /"CustomizationRoles": \[([^\]]*)\]/g, `${RULES} Defaults()`);
  const wire = listOf(
    read(WIRE),
    /TestALeastPrivilegedPrincipalCreatesWithTheDefaultRoles\(\)[\s\S]*?"CustomizationRoles": \[([^\]]*)\]/g,
    `${WIRE} TestALeastPrivilegedPrincipalCreatesWithTheDefaultRoles`
  );
  assert.ok(client.length > 0, 'the client pre-ticks at least one role');
  assert.deepEqual(server, client, `${RULES} Defaults() differs from the roles ${STORE} pre-ticks`);
  assert.deepEqual(wire, client, `${WIRE} posts roles that differ from the ones ${STORE} pre-ticks`);
});

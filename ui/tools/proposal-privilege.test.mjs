import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the proposal card's privilege line (Story 11.8, AD-8): `privilegeLine` fills the two
// published sentences from the instance's own `privilege`, `toCardView` carries it, and neither
// sentence claims the pairs are sufficient (AD-29).
//
// Mutations (Rule 19):
// - drop `privilege` from `toCardView`'s result -> "toCardView carries the privilege line" goes red.
// - add "sufficient" to either sentence -> "both sentences begin Requires ..." goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);

const { privilegeLine, toCardView } = await import(corePath('proposal-view.ts'));
const { parseProposals } = await import(corePath('turn.ts'));
const { STRINGS } = await import(corePath('strings.ts'));

function parsedProposal(privilege) {
  const [parsed] = parseProposals([
    {
      proposalId: 'p1',
      target: { type: 'web-application', scope: 'instance', id: '/csp/myapp' },
      expiresAt: '2026-09-19T10:00:00Z',
      tool: 'webapp.list.update',
      changed: [{ field: 'Enabled', before: 'false', after: 'true' }],
      unchangedCount: 2,
      rationale: 'because',
      expectedImpact: 'it serves',
      reverse: 'set it back',
      state: 'live',
      auditWarning: false,
      privilege,
    },
  ]);
  assert.ok(parsed, 'the fixture parses');
  return parsed;
}

test('privilegeLine names every required pair and says the user holds them', () => {
  assert.deepEqual(privilegeLine({ requires: ['%Admin_Secure:USE', '%DB_IRISSYS:READ'], missing: '' }), {
    text: 'Requires %Admin_Secure:USE, %DB_IRISSYS:READ, which you hold.',
    missing: false,
  });
});

test('privilegeLine warns and names the first pair the user does not hold', () => {
  assert.deepEqual(privilegeLine({ requires: ['%Admin_Secure:USE', '%DB_IRISSYS:READ'], missing: '%Admin_Secure:USE' }), {
    text: 'Requires %Admin_Secure:USE, %DB_IRISSYS:READ. You don\'t hold %Admin_Secure:USE.',
    missing: true,
  });
});

test('privilegeLine answers null for no privilege and for an empty requires', () => {
  assert.equal(privilegeLine(null), null);
  assert.equal(privilegeLine(undefined), null);
  assert.equal(privilegeLine({ requires: [], missing: '' }), null);
});

test('toCardView carries the privilege line from the wire, and null when the wire has none', () => {
  const held = toCardView(parsedProposal({ requires: ['%Admin_Secure:USE'], missing: '' }), 'x');
  assert.deepEqual(held.privilege, { text: 'Requires %Admin_Secure:USE, which you hold.', missing: false });
  const missing = toCardView(parsedProposal({ requires: ['%Admin_Secure:USE'], missing: '%Admin_Secure:USE' }), 'x');
  assert.equal(missing.privilege.missing, true);
  assert.equal(toCardView(parsedProposal(null), 'x').privilege, null);
});

test('both sentences begin Requires and neither says sufficient', () => {
  for (const sentence of [STRINGS.privilegeProposalHeld, STRINGS.privilegeProposalMissing]) {
    assert.ok(sentence.startsWith('Requires '), `"${sentence}" begins "Requires "`);
    assert.doesNotMatch(sentence, /sufficient/i);
  }
});

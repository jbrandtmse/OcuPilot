import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { readFileSync } from 'node:fs';

// Pins the proposal card's framework-free half (Story 5.2): the map from a wire proposal onto the
// view model, the countdown's formatter and its two boundaries, the phase vocabulary and the
// status line each terminal phase reads.
//
// **No test here waits on a clock.** Every countdown function takes the moment as a number, which
// is the whole reason the clock is a parameter (AD-19).
//
// Mutations (Rule 19):
// - move `countdownPhase`'s warning boundary off 60 s -> the 1:00 boundary test goes red alone.
// - make `countdownRemaining` treat an `expiresAt` of 0 as a deadline already past -> the
//   unknown-expiry test goes red, on a live card shown expired.
// - drop the mask from `toCardView`'s declared-secret row -> the masking test goes red, and the
//   secret would reach the diff in clear.
// - have `restoredProposals` pass the wire `state` through -> the still-live restore test goes
//   red, and a restored card would render live with Confirm available.
// - have `restoredProposals` overwrite every state, not only `live` -> the DW-1225 test goes red,
//   and a confirmed write would read as expired after a reload.
// - drop the `closedReason` arm from `phaseForState` -> the reason table goes red, and every
//   cancel would read as the user's own.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);

const {
  COUNTDOWN_PLACEHOLDER,
  COUNTDOWN_WARNING_MS,
  CONFIRMED_TIME_PLACEHOLDER,
  MASKED_VALUE,
  RESIDUE_COUNT_PLACEHOLDER,
  USER_NAME_PLACEHOLDER,
  countdownPhase,
  countdownRemaining,
  formatCountdown,
  formatCountdownCaption,
  formatRemovalResidue,
  formatUserName,
  isTerminalPhase,
  offersRepropose,
  phaseForState,
  statusLineFor,
  toCardView,
} = await import(corePath('proposal-view.ts'));
const { PROPOSAL_EXPIRED_STATE, PROPOSAL_LIVE_STATE, parseProposals, restoredProposals } =
  await import(corePath('turn.ts'));
const { STRINGS } = await import(corePath('strings.ts'));

const PROPOSE_CLS = join(uiRoot, '..', 'src', 'OcuPilot', 'Kernel', 'State', 'Propose.cls');
const DISCLOSURE_CLS = join(uiRoot, '..', 'src', 'OcuPilot', 'Kernel', 'Proposal', 'Disclosure.cls');
const TOOLFIELDS_CLS = join(uiRoot, '..', 'src', 'OcuPilot', 'Screen', 'Tool', 'ToolFields.cls');

/** `ToolFields.cls`'s generated `Tools` block, parsed. */
function toolFields() {
  const lines = readFileSync(TOOLFIELDS_CLS, 'utf8').split('\n');
  const start = lines.indexOf('XData Tools') + 2;
  let depth = 0;
  const body = [];
  for (const line of lines.slice(start)) {
    body.push(line);
    depth += (line.match(/\{/g) ?? []).length - (line.match(/\}/g) ?? []).length;
    if (depth === 0) break;
  }
  return JSON.parse(body.join('\n'));
}

/** One wire proposal, in the shape `OcuPilot.Kernel.State.Propose.WireRow` writes. */
function wireProposal(overrides = {}) {
  return {
    proposalId: 'p1',
    target: { type: 'web-application', scope: 'instance', id: '/csp/myapp' },
    expiresAt: '2026-09-19T10:00:00Z',
    tool: 'webapp.list.update',
    changed: [
      { field: 'Enabled', before: 'false', after: 'true' },
      { field: 'Password', before: 'old', after: 'new' },
    ],
    unchangedCount: 38,
    rationale: 'because',
    expectedImpact: 'it serves',
    reverse: 'set it back',
    state: PROPOSAL_LIVE_STATE,
    auditWarning: false,
    ...overrides,
  };
}

function parsedProposal(overrides = {}) {
  const [parsed] = parseProposals([wireProposal(overrides)]);
  assert.ok(parsed, 'the fixture parses');
  return parsed;
}

// --- The mapper ---------------------------------------------------------------------------------

test('toCardView takes the noun from the screen and everything else from the proposal', () => {
  const view = toCardView(parsedProposal(), STRINGS.proposalEntityWebApplication);
  assert.equal(view.entityType, STRINGS.proposalEntityWebApplication);
  assert.equal(view.name, '/csp/myapp');
  assert.equal(view.proposalId, 'p1');
  assert.equal(view.unchangedCount, 38);
  assert.equal(view.rationale, 'because');
  assert.equal(view.expectedImpact, 'it serves');
  assert.equal(view.reverse, 'set it back');
  assert.equal(view.auditWarning, false);
  assert.equal(view.expiresAt, Date.parse('2026-09-19T10:00:00Z'));
  assert.deepEqual(view.changed, [
    { field: 'Enabled', before: 'false', after: 'true', removed: false },
    { field: 'Password', before: 'old', after: 'new', removed: false },
  ]);
});

test('a removal row travels off the wire, and a row with an after-state is not one (DW-1228)', () => {
  // AD-48's delete proposal: the target's identifying field, its value, and no after-state. The
  // flag is the instance's, like every other value here -- the card reads it to choose the drawn
  // and spoken forms EXPERIENCE.md's diff-row rule publishes.
  //
  // Mutation (Rule 19): drop `removed` from `parseProposalDiff` -> every row parses as not
  // removed and this goes red.
  const view = toCardView(
    parsedProposal({
      changed: [
        { field: '09/11/2026', before: '123', after: '', removed: true },
        { field: 'Enabled', before: 'false', after: 'true' },
      ],
    }),
    'Application error'
  );
  assert.deepEqual(view.changed, [
    { field: '09/11/2026', before: '123', after: '', removed: true },
    { field: 'Enabled', before: 'false', after: 'true', removed: false },
  ]);
});

test('the residue sentence resolves its own count and keeps both of its facts (AD-48)', () => {
  const resolved = formatRemovalResidue(STRINGS.proposalResidue, 211);
  assert.ok(resolved.includes('211'), 'the count the card lists');
  assert.ok(!resolved.includes(RESIDUE_COUNT_PLACEHOLDER), 'and the placeholder is gone');
  assert.equal(
    formatRemovalResidue(STRINGS.proposalResidue, 0),
    STRINGS.proposalResidue.split(RESIDUE_COUNT_PLACEHOLDER).join('0'),
    'the substitution is the published literal with its slot filled, never a rewrite'
  );
});

test("a field the screen declares secret reads the mask on both sides, and nothing else does", () => {
  const view = toCardView(parsedProposal(), STRINGS.proposalEntityWebApplication, ['Password']);
  assert.deepEqual(view.changed[0], { field: 'Enabled', before: 'false', after: 'true', removed: false });
  assert.deepEqual(view.changed[1], {
    field: 'Password',
    before: MASKED_VALUE,
    after: MASKED_VALUE,
    removed: false,
  });
  assert.equal(MASKED_VALUE.length, 8, 'eight bullets, as the document publishes it');
  assert.deepEqual([...view.maskedFields], ['Password'], 'and the declared names reach the card');
});

test('the audit warning travels off the wire rather than being decided here', () => {
  assert.equal(toCardView(parsedProposal({ auditWarning: true }), 'x').auditWarning, true);
  assert.equal(toCardView(parsedProposal({ auditWarning: false }), 'x').auditWarning, false);
});

// AC1 (Story 5.10): the declaration is the write tool's own and reaches the card on the wire, so no
// list of destructive tool names exists in this client to fall out of step with the tool set.
//
// Mutation (Rule 19): drop `destructive` from `toCardView`'s result, or from `parseProposal` ->
// these go red.
test('the destructive declaration travels off the wire, like the audit warning', () => {
  assert.equal(toCardView(parsedProposal({ destructive: true }), 'x').destructive, true);
  assert.equal(toCardView(parsedProposal({ destructive: false }), 'x').destructive, false);
  assert.equal(toCardView(parsedProposal(), 'x').destructive, false, 'a wire row that omits it is not destructive');
});

// DW-1227: a screen declares the secrets of every write its tool can make, and one proposal sends
// one body. A name the payload does not carry reaches nothing, so asking the user to fill it would
// leave Confirm `aria-disabled` for ever.
//
// Mutation (Rule 19): pass `secretArguments` straight through as `maskedFields` again -> the second
// assertion goes red.
test("maskedFields is the declared set narrowed to this proposal's own payload", () => {
  const carried = toCardView(parsedProposal(), 'x', ['Password']);
  assert.deepEqual([...carried.maskedFields], ['Password'], 'a declared secret the payload carries is asked for');
  const absent = toCardView(parsedProposal(), 'x', ['PrivateKeyPassword']);
  assert.deepEqual([...absent.maskedFields], [], 'and one it does not is not');
  const unchangedOnly = toCardView(
    parsedProposal({ changed: [{ field: 'Enabled', before: 'false', after: 'true' }], unchanged: [{ field: 'Password', value: MASKED_VALUE }] }),
    'x',
    ['Password']
  );
  assert.deepEqual(
    [...unchangedOnly.maskedFields],
    ['Password'],
    'the unchanged half counts too: a secret is never a changed row, because the mint refuses it as an argument'
  );
});

test('a delete proposal carries no reversal, so the card has no Reverse line to draw', () => {
  const view = toCardView(parsedProposal({ reverse: '' }), 'x');
  assert.equal(view.reverse, '');
});

// --- The countdown ------------------------------------------------------------------------------

test('formatCountdown reads m:ss, floored to the second, and never negative', () => {
  assert.equal(formatCountdown(600_000), '10:00');
  assert.equal(formatCountdown(599_000), '9:59');
  assert.equal(formatCountdown(599_999), '9:59');
  assert.equal(formatCountdown(60_000), '1:00');
  assert.equal(formatCountdown(9_000), '0:09');
  assert.equal(formatCountdown(0), '0:00');
  assert.equal(formatCountdown(-5_000), '0:00', 'a deadline already past reads zero, not a minus');
});

test('countdownPhase turns to warning AT 1:00 and holds it to 0:00', () => {
  assert.equal(COUNTDOWN_WARNING_MS, 60_000, 'the boundary is one minute');
  assert.equal(countdownPhase(60_001), 'normal');
  assert.equal(countdownPhase(60_000), 'warning', 'inclusive: the caption turns AT one minute');
  assert.equal(countdownPhase(1), 'warning');
  assert.equal(countdownPhase(0), 'expired');
  assert.equal(countdownPhase(-1), 'expired');
});

test('an expiresAt of 0 is unknown, never expired: the card stays live until the poll closes it', () => {
  const now = Date.parse('2026-09-19T09:50:00Z');
  assert.equal(countdownRemaining(0, now), null);
  assert.equal(countdownRemaining(Number.NaN, now), null);
  assert.equal(countdownRemaining(Date.parse('2026-09-19T10:00:00Z'), now), 600_000);
  // And the unreadable wire timestamp `core/turn.ts` records as 0 is exactly that case.
  assert.equal(parsedProposal({ expiresAt: 'not a moment' }).expiresAt, 0);
});

test('the countdown caption substitutes the published m:ss rather than replacing the string', () => {
  assert.ok(STRINGS.proposalCountdownLabel.includes(COUNTDOWN_PLACEHOLDER));
  assert.equal(formatCountdownCaption(STRINGS.proposalCountdownLabel, '9:59'), 'Expires in 9:59');
});

// --- The phases ---------------------------------------------------------------------------------

test('the seven terminal phases each read their published status line, and live reads none', () => {
  assert.equal(statusLineFor('live', '_SYSTEM', '10:00:00'), '');
  assert.equal(statusLineFor('confirming', '_SYSTEM', '10:00:00'), '');
  assert.equal(
    statusLineFor('confirmed', '_SYSTEM', '10:00:00'),
    STRINGS.proposalStatusConfirmedBy.split(USER_NAME_PLACEHOLDER)
      .join('_SYSTEM')
      .split(CONFIRMED_TIME_PLACEHOLDER)
      .join('10:00:00')
  );
  assert.equal(statusLineFor('canceled-by-you', '', ''), STRINGS.proposalStatusCanceledByYou);
  assert.equal(statusLineFor('canceled-by-message', '', ''), STRINGS.proposalStatusCanceledByMessage);
  assert.equal(statusLineFor('canceled-sibling', '', ''), STRINGS.proposalStatusCanceledSibling);
  assert.equal(statusLineFor('expired', '', ''), STRINGS.proposalStatusExpired);
  assert.equal(statusLineFor('switched-off', '', ''), STRINGS.proposalStatusAgentSwitchedOff);
  // EXPERIENCE.md publishes one fixed string for the fingerprint refusal and DESIGN.md says the
  // warning banner's fixed string is EXPERIENCE.md's -- so the status line IS the banner's text,
  // and no second piece of copy exists for it.
  assert.equal(statusLineFor('target-changed', '', ''), STRINGS.proposalTargetChanged);
});

test('every phase but live and confirming is terminal, and two of them offer Re-propose', () => {
  for (const phase of ['live', 'confirming']) assert.equal(isTerminalPhase(phase), false, phase);
  for (const phase of [
    'confirmed',
    'canceled-by-you',
    'canceled-by-message',
    'canceled-sibling',
    'target-changed',
    'expired',
    'switched-off',
  ]) {
    assert.equal(isTerminalPhase(phase), true, phase);
  }
  // The expiry limit's accommodation (WCAG 2.2.1) and the fingerprint refusal's are the same act:
  // ask again, and the instance reads the target fresh and diffs it fresh.
  assert.equal(offersRepropose('expired'), true);
  assert.equal(offersRepropose('target-changed'), true);
  assert.equal(offersRepropose('canceled-by-you'), false);
  assert.equal(offersRepropose('confirmed'), false);
  assert.equal(offersRepropose('live'), false);
});

test('a canceled row reads its phase from the reason the instance recorded with it', () => {
  const propose = readFileSync(PROPOSE_CLS, 'utf8');
  const reasonOf = (name) => {
    const match = new RegExp(`Parameter ${name} = "([^"]+)";`).exec(propose);
    assert.ok(match, `${PROPOSE_CLS} declares Parameter ${name}`);
    return match[1];
  };
  const canceled = (/Parameter STATECANCELED = "([^"]+)";/.exec(propose) ?? [])[1];
  assert.ok(canceled, 'the store declares its canceled state');
  assert.equal(phaseForState(canceled, reasonOf('REASONYOU')), 'canceled-by-you');
  assert.equal(phaseForState(canceled, reasonOf('REASONMESSAGE')), 'canceled-by-message');
  assert.equal(phaseForState(canceled, reasonOf('REASONSIBLING')), 'canceled-sibling');
  assert.equal(phaseForState(canceled, reasonOf('REASONTARGETCHANGED')), 'target-changed');
  // A reason this client has never heard of claims least about why, rather than inventing one.
  assert.equal(phaseForState(canceled, 'something new'), 'canceled-by-you');
  assert.equal(phaseForState(canceled), 'canceled-by-you');
});

test("phaseForState reads the store's own vocabulary, and an unknown state reads as expired", () => {
  const propose = readFileSync(PROPOSE_CLS, 'utf8');
  const stateOf = (name) => {
    const match = new RegExp(`Parameter ${name} = "([^"]+)";`).exec(propose);
    assert.ok(match, `${PROPOSE_CLS} declares Parameter ${name}`);
    return match[1];
  };
  assert.equal(phaseForState(stateOf('STATELIVE')), 'live');
  assert.equal(phaseForState(stateOf('STATECONFIRMED')), 'confirmed');
  assert.equal(phaseForState(stateOf('STATECANCELED')), 'canceled-by-you');
  assert.equal(phaseForState(stateOf('STATEEXPIRED')), 'expired');
  assert.equal(phaseForState('something this client has never heard of'), 'expired');
  assert.equal(PROPOSAL_EXPIRED_STATE, stateOf('STATEEXPIRED'), 'the client mirrors the same word');
});

test("the instance's own mask is the mask this module publishes", () => {
  // DW-1223 moved the masking of an unchanged value onto the instance, so the value never travels
  // rather than travelling and being hidden -- and the client kept `MASKED_VALUE` for the diff
  // row's declared secrets. Two constants for one published string is a drift nothing else would
  // catch: a card would then show eight bullets on one row and six on another, and neither tier
  // would be wrong on its own.
  const disclosure = readFileSync(DISCLOSURE_CLS, 'utf8');
  const parameterOf = (name) => {
    const match = new RegExp(`Parameter ${name} As %Integer = (\\d+);`).exec(disclosure);
    assert.ok(match, `${DISCLOSURE_CLS} declares Parameter ${name}`);
    return Number(match[1]);
  };
  assert.equal(
    String.fromCodePoint(parameterOf('MASKCODEPOINT')).repeat(parameterOf('MASKWIDTH')),
    MASKED_VALUE,
    "the instance's Disclosure.Mask() and this module's MASKED_VALUE are the same published string"
  );
});

test("toCardView passes the instance's unchanged rows through, authoring no value of its own", () => {
  // DW-1223. Mutation (Rule 19): drop the `unchanged` line from `toCardView` -> this goes red, and
  // the disclosure would render as a `<p>` with nothing behind its own count.
  const unchanged = [
    { field: 'Description', value: 'a demo fixture' },
    { field: 'MatchRoles', value: MASKED_VALUE },
  ];
  const view = toCardView(parsedProposal({ unchanged }), 'Web application', ['Password']);
  assert.deepEqual(view.unchanged, unchanged);
  // The secret masking on the diff is the client's; the masking under the disclosure is the
  // instance's, and this module does not apply a second one.
  assert.deepEqual(view.changed[1], {
    field: 'Password',
    before: MASKED_VALUE,
    after: MASKED_VALUE,
    removed: false,
  });
});

test('a wire row with no unchanged array parses to no rows rather than to undefined', () => {
  const [parsed] = parseProposals([wireProposal()]);
  assert.deepEqual(parsed.unchanged, []);
  const [withRows] = parseProposals([
    wireProposal({ unchanged: [{ field: 'Timeout', value: '900' }, 'not an object', { field: 'Path' }] }),
  ]);
  assert.deepEqual(withRows.unchanged, [
    { field: 'Timeout', value: '900' },
    { field: 'Path', value: '' },
  ]);
});

test('no generated field list makes a container disclosable while classifying a member secret', () => {
  // The one fail-OPEN shape `Kernel/Proposal/Disclosure.OrdinaryPaths` has. It admits a top-level
  // property by a row whose path is the name itself or the name with `[]`, and skips every dotted
  // path -- so a row for `MatchRoles[]` classified `ordinary`+`literal` would put the whole
  // subtree through `Mint.Display`, which `%ToJSON()`s it, while the rows that classify
  // `MatchRoles[].MatchRole` as `secret` would have no say. Nothing would be red: `MatchRoles` is
  // the only such subtree `webapp.list.update` has, and the disclosure test asserts it masked
  // because today no container row exists at all.
  //
  // Asserted rather than assumed, because the block is GENERATED (AD-3) and the generator's leaf
  // shape is what makes this unreachable -- a property of Story 2.2's derivation, which this file
  // does not own. A generator that started emitting container rows would land the leak here
  // instead of on a card.
  //
  // Mutation (Rule 19): add {"path":"MatchRoles[]","shape":"literal","class":"ordinary"} to
  // `webapp.list.update` -> this goes red naming it.
  const tools = toolFields();
  const names = Object.keys(tools);
  assert.ok(names.length > 0, 'the generated block declares at least one tool, so this sweep reads something');
  const offenders = [];
  for (const [tool, entry] of Object.entries(tools)) {
    const fields = entry.fields ?? [];
    assert.ok(fields.length > 0, `${tool} declares fields`);
    const paths = new Set(fields.map((field) => field.path));
    for (const field of fields) {
      const base = field.path.endsWith('[]') ? field.path.slice(0, -2) : field.path;
      if (base.includes('.') || base.includes('[')) continue;
      if (field.class !== 'ordinary' || field.shape !== 'literal') continue;
      const deeper = [...paths].filter(
        (path) => path !== field.path && (path.startsWith(`${base}.`) || path.startsWith(`${base}[].`))
      );
      if (deeper.length > 0) offenders.push(`${tool}: ${field.path} is disclosable and also carries ${deeper.join(', ')}`);
    }
  }
  assert.deepEqual(offenders, [], 'no disclosable top-level row has member rows under it');
});

// --- The restore path (DW-1213) -----------------------------------------------------------------

test('a still-live restored proposal is shown expired, with Re-propose', () => {
  const [restored] = restoredProposals([wireProposal()]);
  assert.equal(restored.state, PROPOSAL_EXPIRED_STATE);
  assert.equal(phaseForState(restored.state), 'expired');
  assert.equal(offersRepropose(phaseForState(restored.state)), true, 'with Re-propose offered');
  // Everything else about it is still the wire's own: the card is restrained, not emptied.
  assert.equal(restored.proposalId, 'p1');
  assert.equal(restored.changed.length, 2);
  assert.equal(restored.unchangedCount, 38);
});

test('a restored row the instance already closed keeps the state it closed in (DW-1225)', () => {
  const rows = restoredProposals([
    wireProposal({ proposalId: 'p-confirmed', state: 'confirmed', confirmedAt: '2026-09-19T10:00:00Z' }),
    wireProposal({ proposalId: 'p-sibling', state: 'canceled', closedReason: 'sibling' }),
    wireProposal({ proposalId: 'p-changed', state: 'canceled', closedReason: 'target-changed' }),
  ]);
  assert.equal(rows[0].state, 'confirmed');
  assert.equal(phaseForState(rows[0].state, rows[0].closedReason), 'confirmed');
  assert.equal(rows[0].confirmedAt, '2026-09-19T10:00:00Z', 'the moment of the write survives the reload');
  assert.equal(phaseForState(rows[1].state, rows[1].closedReason), 'canceled-sibling');
  assert.equal(phaseForState(rows[2].state, rows[2].closedReason), 'target-changed');
  assert.equal(offersRepropose(phaseForState(rows[2].state, rows[2].closedReason)), true);
  // Only the still-live one is overwritten, which is the whole of the product decision.
  assert.equal(restoredProposals([wireProposal()])[0].state, PROPOSAL_EXPIRED_STATE);
});

test('a restored turn with no proposals key reads as no cards rather than as a failure', () => {
  assert.deepEqual(restoredProposals(undefined), []);
  assert.deepEqual(restoredProposals('not an array'), []);
  assert.deepEqual(restoredProposals([]), []);
});

test('formatUserName resolves the published placeholder and leaves the rest of the sentence', () => {
  assert.equal(
    formatUserName(STRINGS.proposalFooterRunsAs, '_SYSTEM'),
    'Runs as _SYSTEM, with your privileges.'
  );
  assert.ok(STRINGS.proposalFooterRunsAs.includes(USER_NAME_PLACEHOLDER));
});

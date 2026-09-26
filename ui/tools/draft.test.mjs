import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the copy-out draft's client half (Story 14.1, AD-59): the route is absolute and sits beside
// confirm and cancel; the answer parses all-or-nothing; a refusal carries the envelope's own words;
// and the turn store records a taken draft as the row's closed state -- closing the AD-43 pause and
// publishing no change -- while holding no copy of the script.
//
// Mutations (Rule 19):
// - drop the `text === ''` refusal in `parseDraft` -> "a script with any unreadable step is no
//   script" goes red.
// - record the refusal in `draftProposal`'s success branch instead of clearing it -> "a taken
//   draft closes the row" goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);

const { DRAFT_PROPOSAL_PATH, proposalDraftPath, parseDraft, requestDraft } = await import(corePath('draft.ts'));
const { TurnStore, PROPOSAL_PATH, CONVERSATION_PATH, TURN_PATH, turnProgressPath, proposalCancelPath } = await import(
  corePath('turn.ts')
);
const { phaseForState } = await import(corePath('proposal-view.ts'));

function ok(body, status = 200) {
  return { kind: 'ok', status, body };
}

function err(status, code, reason = 'refused', detail = null) {
  return { kind: 'error', status, code, reason, detail };
}

/** Per-path response queues, and every call recorded (path, method, body). */
function fakeApi(responses = {}) {
  const calls = [];
  return {
    calls,
    requestJson: async (path, init = {}) => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body });
      const list = responses[path] ?? [];
      return list.length === 0 ? ok({}) : list.shift();
    },
  };
}

function memoryStorage(initial = {}) {
  const map = new Map(Object.entries(initial));
  return {
    getItem: (key) => (map.has(key) ? map.get(key) : null),
    setItem: (key, value) => map.set(key, value),
    removeItem: (key) => map.delete(key),
  };
}

function recordingBus() {
  const events = [];
  return { events, publish: (event) => events.push(event), subscribe: () => () => {} };
}

const NOW_MS = Date.parse('2026-09-19T10:00:00Z');

function wireProposal(overrides = {}) {
  return {
    proposalId: 'p1',
    target: { type: 'web-application', scope: 'instance', id: '/csp/myapp' },
    expiresAt: '2026-09-19T10:05:00Z',
    tool: 'webapp.list.update',
    changed: [{ field: 'Enabled', before: 'true', after: 'false' }],
    unchangedCount: 2,
    rationale: 'because',
    expectedImpact: 'it stops serving',
    reverse: 'enable it again',
    state: 'live',
    closedReason: '',
    confirmedAt: '',
    auditWarning: false,
    ...overrides,
  };
}

/** The 200 body the instance answers a taken draft with. */
function takenBody(overrides = {}) {
  return {
    proposalId: 'p1',
    state: 'canceled',
    closedReason: 'draft',
    confirmedAt: '',
    draft: {
      steps: [
        {
          kind: 'rest',
          text: "curl -u '_SYSTEM' -X PUT '<origin>/api/admin/v2/webapp?Name=%2Fcsp%2Fmyapp' -d '{\"Enabled\":false}'",
        },
        { kind: 'objectscript', text: 'Set sc=##class(Security.Users).Modify("<Name>",.p)' },
      ],
      placeholders: ['Password'],
    },
    ...overrides,
  };
}

const settle = () => new Promise((resolve) => setImmediate(resolve));

/**
 * A store that sent one turn whose poll carried one live proposal, `p1`, with the bus's
 * `proposal-open` for it already published and then forgotten -- so what is left to observe is the
 * close a draft makes. `draftResponses` answers the draft route, in order.
 */
async function storeWithLiveProposal(draftResponses) {
  const bus = recordingBus();
  const api = fakeApi({
    [CONVERSATION_PATH]: [ok({ conversationId: 'c1' }, 201)],
    [TURN_PATH]: [ok({ turnId: 'turn-1' }, 202)],
    [turnProgressPath('turn-1')]: [
      ok({ state: 'completed', steps: [], stepsDropped: 0, reply: 'done', error: null, proposals: [wireProposal()] }),
    ],
    [proposalDraftPath('p1')]: draftResponses,
  });
  const scheduled = [];
  const turn = new TurnStore({
    api,
    storage: memoryStorage(),
    navigationType: () => 'navigate',
    schedule: (run) => scheduled.push(run),
    now: () => NOW_MS,
    bus,
  });
  await turn.send('do it');
  await settle();
  scheduled.shift()?.();
  await settle();
  assert.deepEqual(bus.events.map((event) => event.kind), ['proposal-open'], 'the fixture proposal is live');
  assert.equal(turn.entries()[0].proposals[0].state, 'live');
  bus.events.length = 0;
  return { turn, api, bus };
}

// --- The route (AD-20) --------------------------------------------------------------------------

test('the draft route is absolute and sits beside confirm and cancel on the same root', () => {
  assert.equal(DRAFT_PROPOSAL_PATH, PROPOSAL_PATH, "the draft route's root is core/turn.ts's own");
  assert.equal(proposalDraftPath('p1'), '/api/ocupilot/proposal/p1/draft');
  assert.equal(proposalDraftPath('p1'), proposalCancelPath('p1').replace(/\/cancel$/, '/draft'));
  assert.equal(proposalDraftPath('a/b c'), '/api/ocupilot/proposal/a%2Fb%20c/draft', 'the id is one path segment');
});

// --- The answer ---------------------------------------------------------------------------------

test('a taken draft parses to its steps in order and its placeholder names', () => {
  const draft = parseDraft(takenBody().draft);
  assert.equal(draft.steps.length, 2);
  assert.deepEqual(
    draft.steps.map((step) => step.kind),
    ['rest', 'objectscript']
  );
  assert.equal(draft.steps[1].text, 'Set sc=##class(Security.Users).Modify("<Name>",.p)', 'the text is carried verbatim');
  assert.deepEqual(draft.placeholders, ['Password']);
});

test('a script with any unreadable step is no script, rather than a script with a step missing', () => {
  const good = { kind: 'rest', text: 'curl' };
  assert.equal(parseDraft({ steps: [good, { kind: 'rest', text: '' }], placeholders: [] }), null);
  assert.equal(parseDraft({ steps: [good, { kind: 'rest' }], placeholders: [] }), null);
  assert.equal(parseDraft({ steps: [good, { kind: 7, text: 'x' }], placeholders: [] }), null);
  assert.equal(parseDraft({ steps: [good, 'curl'], placeholders: [] }), null);
  assert.equal(parseDraft({ steps: [], placeholders: [] }), null, 'no steps is no script');
  assert.equal(parseDraft({ placeholders: [] }), null);
  assert.equal(parseDraft(null), null);
  assert.equal(parseDraft([good]), null, 'an array is not a draft object');
  // The placeholder list describes the script; a stray entry in it does not make the script unsafe.
  assert.deepEqual(parseDraft({ steps: [good], placeholders: ['Password', 3, null] }).placeholders, ['Password']);
  assert.deepEqual(parseDraft({ steps: [good] }).placeholders, []);
});

test('requestDraft posts the route with no body, and answers the row the instance closed', async () => {
  const api = fakeApi({ [proposalDraftPath('p1')]: [ok(takenBody())] });
  const outcome = await requestDraft(api, 'p1');
  assert.deepEqual(api.calls, [{ path: '/api/ocupilot/proposal/p1/draft', method: 'POST', body: undefined }]);
  assert.equal(outcome.ok, true);
  assert.equal(outcome.state, 'canceled');
  assert.equal(outcome.closedReason, 'draft');
  assert.equal(outcome.draft.steps.length, 2);
  assert.equal(phaseForState(outcome.state, outcome.closedReason), 'canceled-by-draft');
});

test('a 200 whose draft is unreadable still answers the closed row, with no script', async () => {
  const api = fakeApi({ [proposalDraftPath('p1')]: [ok(takenBody({ draft: { steps: [] } }))] });
  const outcome = await requestDraft(api, 'p1');
  assert.equal(outcome.ok, true);
  assert.equal(outcome.state, 'canceled');
  assert.equal(outcome.draft, null);
});

test("a refusal carries the envelope's own status, code and reason, and no script", async () => {
  const api = fakeApi({
    [proposalDraftPath('p1')]: [
      err(403, 'PROHIBITED.OCUPILOTAPP', 'OcuPilot does not change its own application.'),
      err(409, 'PROPOSAL.NODRAFT', 'This write has no script form.'),
      err(404, 'PROPOSAL.UNKNOWN', 'No such proposal.', { state: 'expired', closedReason: '' }),
    ],
  });
  const prohibited = await requestDraft(api, 'p1');
  assert.equal(prohibited.ok, false);
  assert.equal(prohibited.status, 403);
  assert.equal(prohibited.code, 'PROHIBITED.OCUPILOTAPP');
  assert.equal(prohibited.reason, 'OcuPilot does not change its own application.');
  assert.equal(prohibited.state, '', 'a refusal that left the row live names no state');
  assert.equal(prohibited.draft, null);

  const noDraft = await requestDraft(api, 'p1');
  assert.equal(noDraft.status, 409);
  assert.equal(noDraft.code, 'PROPOSAL.NODRAFT');

  const unknown = await requestDraft(api, 'p1');
  assert.equal(unknown.status, 404);
  assert.equal(unknown.state, 'expired', "a refusal's detail names the row's own state where it has one");
});

test('no envelope, or an empty id, answers nothing known and sends nothing for the empty id', async () => {
  const api = fakeApi({ [proposalDraftPath('p1')]: [{ kind: 'installing', status: 503, code: 'INSTALL.RUNNING' }] });
  const installing = await requestDraft(api, 'p1');
  assert.equal(installing.ok, false);
  assert.equal(installing.status, 0);
  const none = await requestDraft(api, '');
  assert.equal(none.status, 0);
  assert.equal(api.calls.length, 1, 'the empty id posted nothing');
});

// --- The turn store -----------------------------------------------------------------------------

test('a taken draft closes the row as canceled/draft, lifts the pause, and publishes no change', async () => {
  const { turn, api, bus } = await storeWithLiveProposal([ok(takenBody())]);
  const outcome = await turn.draftProposal('p1');
  assert.equal(outcome.ok, true);
  const row = turn.entries()[0].proposals[0];
  assert.equal(row.state, 'canceled');
  assert.equal(row.closedReason, 'draft');
  assert.equal(phaseForState(row.state, row.closedReason), 'canceled-by-draft');
  assert.equal(turn.proposalRefusal('p1'), null);
  assert.deepEqual(
    bus.events.map((event) => event.kind),
    ['proposal-closed'],
    'the AD-43 pause lifts, and nothing is published as changed: the draft sent nothing'
  );
  assert.deepEqual(
    api.calls.filter((call) => call.path.startsWith(PROPOSAL_PATH)).map((call) => call.path),
    [proposalDraftPath('p1')],
    'the one proposal request is the draft: no confirm, no cancel'
  );
  // The script is the caller's to hold for the session; the store keeps no copy of it.
  assert.ok(!JSON.stringify(turn.entries()).includes('curl'), 'no step text is held by the store');
});

test('a refusal that left the row live keeps it live and records the reason for the card', async () => {
  const { turn, bus } = await storeWithLiveProposal([
    err(403, 'PROHIBITED.OCUPILOTAPP', 'OcuPilot does not change its own application.'),
    ok(takenBody()),
  ]);
  const refused = await turn.draftProposal('p1');
  assert.equal(refused.ok, false);
  assert.equal(turn.entries()[0].proposals[0].state, 'live');
  assert.deepEqual(turn.proposalRefusal('p1'), {
    status: 403,
    code: 'PROHIBITED.OCUPILOTAPP',
    reason: 'OcuPilot does not change its own application.',
  });
  assert.deepEqual(bus.events, [], 'a live row closes nothing');

  // A later draft the instance takes clears the refusal it no longer applies to.
  await turn.draftProposal('p1');
  assert.equal(turn.proposalRefusal('p1'), null);
  assert.equal(turn.entries()[0].proposals[0].closedReason, 'draft');
});

test('a request that never reached the instance records nothing', async () => {
  const { turn, bus } = await storeWithLiveProposal([{ kind: 'installing', status: 503, code: 'INSTALL.RUNNING' }]);
  const outcome = await turn.draftProposal('p1');
  assert.equal(outcome.status, 0);
  assert.equal(turn.entries()[0].proposals[0].state, 'live');
  assert.equal(turn.proposalRefusal('p1'), null);
  assert.deepEqual(bus.events, []);
});

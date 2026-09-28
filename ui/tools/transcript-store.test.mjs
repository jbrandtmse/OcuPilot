// Story 14.4: the transcript page's framework-free store (areas/agent/transcript.store.ts) -- the
// path it reads, how it parses a stored turn, what a withheld answer renders, and its phases.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const store = await import(join(uiRoot, 'src', 'app', 'areas', 'agent', 'transcript.store.ts'));
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const ok = (body) => ({ kind: 'ok', status: 200, body });

const answer = (overrides = {}) => ({
  conversationId: 'abc123',
  user: 'alice',
  own: true,
  released: true,
  failedPair: '',
  turns: [
    {
      seq: 1,
      appendedAt: '2026-09-27T10:00:00Z',
      message: 'What runs tonight?',
      state: 'completed',
      reply: 'Two tasks.',
      error: null,
      steps: [{ seq: 1, kind: 'tool', name: 'tasks.schedule.read', status: 'ok', summary: '', text: '' }],
      context: { route: 'tasks/schedule', view: { rows: [] } },
    },
    {
      seq: 2,
      appendedAt: '2026-09-27T10:05:00Z',
      message: 'And after that?',
      state: 'failed',
      reply: null,
      error: { seq: 0, code: 'TURN.UNAVAILABLE', reason: 'The turn could not run.' },
      steps: [],
      context: null,
    },
  ],
  ...overrides,
});

test('the transcript path is absolute and carries the id in one encoded segment (AD-13, AD-20)', () => {
  assert.equal(store.transcriptPath('abc123'), '/api/ocupilot/transcripts/abc123');
  assert.equal(store.transcriptPath('a/b').split('/').length, 5, 'a slash in the id stays inside one segment');
});

// Mutation (Rule 19): make parseContext answer null for every payload -> the route and text
// assertions go red.
test('a stored turn parses into its message, reply, steps and screen context as text', () => {
  const view = store.parseTranscript(answer());
  assert.equal(view.turns.length, 2);
  const [first, second] = view.turns;
  assert.equal(first.message, 'What runs tonight?');
  assert.equal(first.reply, 'Two tasks.');
  assert.equal(first.steps.length, 1);
  assert.equal(first.steps[0].name, 'tasks.schedule.read');
  assert.equal(first.context.route, 'tasks/schedule');
  assert.deepEqual(JSON.parse(first.context.text), { route: 'tasks/schedule', view: { rows: [] } });
  assert.equal(second.reply, null);
  assert.equal(second.errorReason, 'The turn could not run.');
  assert.equal(second.context, null, 'a turn that carried no context has none');
});

test('a withheld answer names the pair in the published request-refused sentence, and a released one names nothing', () => {
  const withheld = store.parseTranscript(answer({ own: false, released: false, failedPair: '%Admin_Secure:USE' }));
  assert.equal(
    store.withheldSentence(withheld),
    STRINGS.privilegeDeniedAction.replace('<resource>', '%Admin_Secure:USE').replace('<action>', STRINGS.transcriptRefusedAction)
  );
  assert.equal(
    store.withheldSentence(withheld),
    "You need %Admin_Secure:USE to see this transcript's tool results and screen context."
  );
  assert.equal(store.withheldSentence(store.parseTranscript(answer())), '');
  assert.equal(store.withheldSentence(store.parseTranscript(answer({ released: false, failedPair: '' }))), '');
});

test('the store reads once per open, answers ready, gone on 404 and refused otherwise, and notifies each change', async () => {
  const paths = [];
  let result = ok(answer());
  const transcript = new store.TranscriptStore(async (path) => {
    paths.push(path);
    return result;
  });
  let notified = 0;
  const stop = transcript.subscribe(() => {
    notified += 1;
  });
  assert.equal(transcript.phase(), 'loading');
  await transcript.open('abc123');
  assert.deepEqual(paths, ['/api/ocupilot/transcripts/abc123']);
  assert.equal(transcript.phase(), 'ready');
  assert.equal(transcript.view().user, 'alice');
  assert.ok(notified >= 2, 'loading and ready are both announced');

  result = { kind: 'error', status: 404, code: 'TURN.CONVERSATION.NOTFOUND', reason: 'gone', detail: null };
  await transcript.open('other');
  assert.equal(transcript.phase(), 'gone');
  assert.equal(transcript.view(), null);

  result = { kind: 'error', status: 503, code: 'LEDGER.UNAVAILABLE', reason: 'down', detail: null };
  await transcript.open('abc123');
  assert.equal(transcript.phase(), 'refused');

  await transcript.open('');
  assert.equal(transcript.phase(), 'gone', 'a route with no id names nothing to read');
  assert.equal(paths.length, 3, 'and no request is made for it');
  stop();
});

test('a superseded read does not overwrite the later one', async () => {
  const resolvers = [];
  const transcript = new store.TranscriptStore(
    (path) =>
      new Promise((resolve) => {
        resolvers.push({ path, resolve });
      })
  );
  const first = transcript.open('first');
  const second = transcript.open('second');
  resolvers[1].resolve(ok(answer({ conversationId: 'second' })));
  await second;
  resolvers[0].resolve(ok(answer({ conversationId: 'first' })));
  await first;
  assert.equal(transcript.view().conversationId, 'second');
});

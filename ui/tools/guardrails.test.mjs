// Pins the framework-free half of Story 16.22's Guardrails page: the store's newest-read and
// sign-out guards and its fail-closed read, the narrowing of an answer, and the helpers that turn
// the answer into lines -- the Confirm groups, the two switch lines and the limits line.
//
// Mutations (Rule 19):
// - `readOnlyLine` answers the off line whatever `enforcedReadOnly` reads -> "the read-only line
//   follows enforcedReadOnly" goes red.
// - `limitsLine` prints a constant 200 for `<rows>` -> "the limits line groups each number" goes red.
// - `reset()` bumps neither `generation` nor `request` -> "a read in flight across reset() never
//   lands" goes red.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const core = (name) => join(uiRoot, 'src', 'app', 'core', name);

const { Guardrails, GUARDRAILS_PATH, narrowGuardrails, confirmGroups, killSwitchLine, readOnlyLine, limitsLine } =
  await import(core('guardrails.ts'));
const { STRINGS } = await import(core('strings.ts'));

function body(overrides = {}) {
  return {
    prohibited: [
      { code: 'PROBE.FIRST', reason: 'first' },
      { code: 'PROBE.SECOND', reason: 'second' },
    ],
    switches: { killSwitch: false, killSwitchAudience: '', enforcedReadOnly: false },
    confirmTools: [{ name: 'a.b.c', descriptor: 'D1' }],
    secrets: [{ tool: 'a.b.c', fields: ['Password'] }],
    limits: { contextRowCap: 200, totalMaxLength: 65536, fieldMaxLength: 1000 },
    ...overrides,
  };
}

/** A transport answering `answers` in order, each `{body}` or `{error: true}`, or a pending promise. */
function stubApi(answers) {
  const calls = [];
  return {
    calls,
    requestJson: (path) => {
      calls.push(path);
      const next = answers.shift();
      if (next instanceof Promise) return next;
      if (next === undefined || next.error) return Promise.resolve({ kind: 'error', status: 500, code: null, reason: null, detail: null });
      return Promise.resolve({ kind: 'ok', status: 200, body: next.body });
    },
  };
}

test('the store reads its one path and narrows the answer', async () => {
  const api = stubApi([{ body: body() }]);
  const store = new Guardrails({ api });
  await store.load();
  assert.deepEqual(api.calls, [GUARDRAILS_PATH]);
  assert.equal(GUARDRAILS_PATH, '/api/ocupilot/ui/guardrails');
  assert.deepEqual(store.data().prohibited.map((row) => row.code), ['PROBE.FIRST', 'PROBE.SECOND'], 'the rows in the answer\'s order');
  assert.equal(store.failed(), false);
  assert.equal(store.loading(), false);
});

test('a failed read fails closed: no answer is held, and failed() is raised', async () => {
  const store = new Guardrails({ api: stubApi([{ body: body() }, { error: true }]) });
  await store.load();
  assert.ok(store.data());
  await store.load();
  assert.equal(store.data(), null, 'the earlier answer is dropped');
  assert.equal(store.failed(), true);
});

test('a malformed answer counts as a failed read', async () => {
  for (const bad of [
    null,
    [],
    body({ prohibited: [{ code: 1, reason: 'x' }] }),
    body({ switches: { killSwitch: 'false', killSwitchAudience: '', enforcedReadOnly: false } }),
    body({ confirmTools: [{ name: 'x' }] }),
    body({ secrets: [{ tool: 'x', fields: [1] }] }),
    body({ limits: { contextRowCap: '200', totalMaxLength: 1, fieldMaxLength: 1 } }),
    body({ limits: undefined }),
  ]) {
    assert.equal(narrowGuardrails(bad), null, JSON.stringify(bad));
    const store = new Guardrails({ api: stubApi([{ body: bad }]) });
    await store.load();
    assert.equal(store.failed(), true, `failed on ${JSON.stringify(bad)}`);
  }
});

test('only the newest read settles, and reset() drops an answer for a departed principal', async () => {
  let release;
  const late = new Promise((resolve) => {
    release = resolve;
  });
  const store = new Guardrails({ api: stubApi([late, { body: body({ prohibited: [] }) }]) });
  const first = store.load();
  await store.load();
  release({ kind: 'ok', status: 200, body: body() });
  await first;
  assert.equal(store.data().prohibited.length, 0, 'the late first answer did not land');

  store.reset();
  assert.equal(store.data(), null);
  assert.equal(store.failed(), false);
});

test('a read in flight across reset() never lands', async () => {
  let release;
  const pending = new Promise((resolve) => {
    release = resolve;
  });
  const store = new Guardrails({ api: stubApi([pending]) });
  const inFlight = store.load();
  assert.equal(store.loading(), true, 'the read is in flight');
  store.reset();
  release({ kind: 'ok', status: 200, body: body() });
  await inFlight;
  assert.equal(store.data(), null, 'the departed principal\'s answer did not land');
  assert.equal(store.failed(), false);
  assert.equal(store.loading(), false);
});

test('confirmGroups groups by descriptor in first-appearance order and puts unnamed tools last', () => {
  const labels = { D1: 'Users', D2: 'Roles' };
  const groups = confirmGroups(
    [
      { name: 'z.one', descriptor: 'D2' },
      { name: 'a.orphan', descriptor: 'DX' },
      { name: 'b.one', descriptor: 'D1' },
      { name: 'z.two', descriptor: 'D2' },
      { name: 'c.none', descriptor: '' },
    ],
    (descriptor) => labels[descriptor] ?? null
  );
  assert.deepEqual(
    groups.map((group) => [group.label, group.tools]),
    [
      ['Roles', ['z.one', 'z.two']],
      ['Users', ['b.one']],
      [null, ['a.orphan', 'c.none']],
    ]
  );
});

test('the kill-switch line reads off, on for everyone or on for you', () => {
  assert.equal(killSwitchLine({ killSwitch: false, killSwitchAudience: '', enforcedReadOnly: false }), STRINGS.agentGuardrailsKillSwitchOff);
  assert.equal(killSwitchLine({ killSwitch: true, killSwitchAudience: 'everyone', enforcedReadOnly: false }), STRINGS.agentGuardrailsKillSwitchEveryone);
  assert.equal(killSwitchLine({ killSwitch: true, killSwitchAudience: 'you', enforcedReadOnly: false }), STRINGS.agentGuardrailsKillSwitchYou);
});

test('the read-only line follows enforcedReadOnly', () => {
  assert.equal(readOnlyLine({ killSwitch: false, killSwitchAudience: '', enforcedReadOnly: true }), STRINGS.agentGuardrailsReadOnlyOn);
  assert.equal(readOnlyLine({ killSwitch: false, killSwitchAudience: '', enforcedReadOnly: false }), STRINGS.agentGuardrailsReadOnlyOff);
});

test('the limits line groups each number en-US', () => {
  const line = limitsLine({ contextRowCap: 150, totalMaxLength: 65536, fieldMaxLength: 1000 });
  assert.equal(
    line,
    STRINGS.agentGuardrailsContextLimits.replace('<rows>', '150').replace('<total>', '65,536').replace('<field>', '1,000')
  );
  assert.ok(!line.includes('<'), 'no placeholder survives');
});

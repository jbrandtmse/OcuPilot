import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the embedded editor screens' own state (`areas/interoperability/interop-editor.store.ts`,
// Story 20.7): which phase the owning list's one read puts a document in, what it sends and in which
// namespace, what a denied verdict sends, what a refresh that does not open the document leaves, how a
// class past the rows the read returns reads, and that a late answer is dropped. The page that draws
// each phase is held by `interop-editor.page.spec.ts`, the frame by `interop-editor-frame.spec.ts`.
//
// Mutations (Rule 19):
// - drop the generation check after the read -> the stale-answer row goes red (the older read's
//   answer overwrites the newer one's).
// - read `Coded` as always false -> the coded row goes red (a class written as code opens a frame).
// - drop the verdict check before the read -> the denied-verdict row goes red (a request is sent).
// - match the row by case-insensitive name -> the exact-name row goes red.
// - answer `open` with the id rather than the id less its extension -> the open rows go red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { InteropEditorState, EDITOR_READ_ROWS } = await import(
  join(uiRoot, 'src', 'app', 'areas', 'interoperability', 'interop-editor.store.ts')
);
const { screenReadPath } = await import(join(uiRoot, 'src', 'app', 'core', 'screen-read.ts'));
const { SCREENS } = await import(join(uiRoot, 'src', 'app', 'core', 'screens.generated.ts'));

const LISTS = {
  rules: SCREENS.find((screen) => screen.route === 'interoperability/rules'),
  processes: SCREENS.find((screen) => screen.route === 'interoperability/processes'),
  transforms: SCREENS.find((screen) => screen.route === 'interoperability/transforms'),
};

const ALLOWED = { allowed: true, failedPair: '' };

/** A `requestJson` double that answers in order, recording every call. */
function apiAnswering(...answers) {
  const calls = [];
  return {
    calls,
    requestJson: (path, init = {}) => {
      calls.push({ path, scope: init.scope });
      const next = answers.shift();
      return Promise.resolve(typeof next === 'function' ? next() : next);
    },
  };
}

/** A `requestJson` double whose answers are released by hand, in any order. */
function apiHeld() {
  const calls = [];
  const releases = [];
  return {
    calls,
    releases,
    requestJson: (path, init = {}) => {
      calls.push({ path, scope: init.scope });
      return new Promise((resolve) => releases.push(resolve));
    },
  };
}

const ok = (rows) => ({ kind: 'ok', status: 200, body: { rows, truncated: false } });
const refusal = (status, detail = null) => ({ kind: 'error', status, code: null, reason: null, detail });

function stateFor(list, api, verdict = () => ALLOWED) {
  return new InteropEditorState({ api, list, verdict });
}

test('a row the list answers opens: the document is the name less its extension, the read is the list\'s own at the route\'s ceiling, in the namespace it was opened in', async () => {
  for (const [key, row] of [
    ['processes', { Name: 'Demo.Probe.Process.cls', Modified: '2026-10-12 06:12:39', Coded: false }],
    ['transforms', { Name: 'Demo.Probe.Transform.cls', Modified: '2026-10-12 06:12:39', Coded: false }],
    ['rules', { Name: 'Demo.Probe.Rule.cls', Modified: '2026-10-12 06:12:39' }],
  ]) {
    const api = apiAnswering(ok([{ Name: 'Other.Thing.cls', Coded: false }, row]));
    const state = stateFor(LISTS[key], api);
    await state.open(row.Name, 'HSCUSTOM');
    assert.equal(state.phase(), 'open', `${key} opens`);
    assert.equal(state.document(), row.Name.slice(0, -'.cls'.length), `${key}: the document has no extension`);
    assert.equal(state.namespace(), 'HSCUSTOM');
    assert.equal(state.revision(), 1);
    assert.equal(state.busy(), false);
    assert.deepEqual(api.calls, [{ path: screenReadPath(LISTS[key], EDITOR_READ_ROWS), scope: 'HSCUSTOM' }], `${key}: one request, the list's own`);
  }
  assert.equal(EDITOR_READ_ROWS, 1000, 'the read route\'s ceiling');
});

test('a row marked Coded is coded: no document, no frame to draw', async () => {
  for (const key of ['processes', 'transforms']) {
    const api = apiAnswering(ok([{ Name: 'EnsLib.HL7.MsgRouter.RoutingEngine.cls', Modified: '', Coded: true }]));
    const state = stateFor(LISTS[key], api);
    await state.open('EnsLib.HL7.MsgRouter.RoutingEngine.cls', 'HSCUSTOM');
    assert.equal(state.phase(), 'coded', key);
    assert.equal(state.document(), '');
    assert.equal(state.revision(), 0, 'no frame was drawn');
  }
});

test('an id the read does not answer is gone: deleted, another namespace, or beyond the cap; the match is exact', async () => {
  const rows = [{ Name: 'Demo.Probe.Rule.cls', Modified: '' }];
  for (const id of ['Demo.Probe.Absent.cls', 'demo.probe.rule.cls', 'Demo.Probe.Rule']) {
    const api = apiAnswering(ok(rows));
    const state = stateFor(LISTS.rules, api);
    await state.open(id, 'HSCUSTOM');
    assert.equal(state.phase(), 'gone', id);
    assert.equal(state.document(), '');
  }
});

test('an id with no document name sends nothing and is gone', async () => {
  for (const id of ['', '.cls', 'Demo.Thing']) {
    const api = apiAnswering(ok([]));
    const state = stateFor(LISTS.processes, api);
    await state.open(id, 'HSCUSTOM');
    assert.equal(state.phase(), 'gone', JSON.stringify(id));
    assert.deepEqual(api.calls, [], 'no request for an id that cannot name a class');
  }
});

test('a denied verdict is refused with its pair and sends nothing; a 403 names the pair it carries', async () => {
  const denied = apiAnswering(ok([{ Name: 'Demo.Thing.cls', Coded: false }]));
  const refused = stateFor(LISTS.processes, denied, (route) => {
    assert.equal(route, 'interoperability/processes', 'the verdict asked for is the list\'s');
    return { allowed: false, failedPair: '%Ens_Code:READ' };
  });
  await refused.open('Demo.Thing.cls', 'HSCUSTOM');
  assert.equal(refused.phase(), 'refused');
  assert.equal(refused.failedPair(), '%Ens_Code:READ');
  assert.deepEqual(denied.calls, [], 'a denied verdict sends no request');

  const wire = apiAnswering(refusal(403, { failedPair: '%Ens_Portal:USE' }));
  const forbidden = stateFor(LISTS.transforms, wire);
  await forbidden.open('Demo.Thing.cls', 'HSCUSTOM');
  assert.equal(forbidden.phase(), 'refused');
  assert.equal(forbidden.failedPair(), '%Ens_Portal:USE');
  assert.equal(wire.calls.length, 1);
});

test('any other answer is a fault, a 403 with no pair included', async () => {
  const answers = [
    refusal(403),
    refusal(403, { failedPair: '' }),
    refusal(500),
    refusal(0),
    { kind: 'installing', status: 503, code: 'INSTALL.RUNNING' },
    { kind: 'ok', status: 200, body: null },
    { kind: 'ok', status: 200, body: { rows: 'x' } },
    { kind: 'ok', status: 200, body: {} },
  ];
  for (const answer of answers) {
    const state = stateFor(LISTS.rules, apiAnswering(answer));
    await state.open('Demo.Thing.cls', 'HSCUSTOM');
    assert.equal(state.phase(), 'fault', JSON.stringify(answer));
    assert.equal(state.busy(), false);
    assert.equal(state.failedPair(), '');
  }
});

test('a late answer for an older open is dropped; the newer one stands', async () => {
  const api = apiHeld();
  const state = stateFor(LISTS.processes, api);
  const first = state.open('Demo.One.cls', 'HSCUSTOM');
  assert.equal(state.phase(), 'loading');
  const second = state.open('Demo.Two.cls', 'HSCUSTOM');
  assert.equal(api.calls.length, 2);
  api.releases[1](ok([{ Name: 'Demo.Two.cls', Coded: false }]));
  await second;
  assert.equal(state.phase(), 'open');
  assert.equal(state.document(), 'Demo.Two');
  api.releases[0](ok([{ Name: 'Demo.One.cls', Coded: false }]));
  await first;
  assert.equal(state.document(), 'Demo.Two', 'the older answer did not overwrite the newer');
  assert.equal(state.revision(), 1, 'and drew no second frame');
});

test('a namespace move opens again there: the frame goes at once, and the read is issued in the new namespace', async () => {
  const api = apiHeld();
  const state = stateFor(LISTS.transforms, api);
  const first = state.open('Demo.Thing.cls', 'HSCUSTOM');
  api.releases[0](ok([{ Name: 'Demo.Thing.cls', Coded: false }]));
  await first;
  assert.equal(state.phase(), 'open');
  const moved = state.open('Demo.Thing.cls', 'USER');
  assert.equal(state.phase(), 'loading', 'nothing of the old namespace stays');
  assert.equal(state.document(), '');
  assert.equal(state.namespace(), 'USER');
  api.releases[1](ok([]));
  await moved;
  assert.equal(state.phase(), 'gone', 'the document is not in the new namespace');
  assert.deepEqual(
    api.calls.map((call) => call.scope),
    ['HSCUSTOM', 'USER']
  );
});

test('refresh reads the same document in the same namespace again, and an answer that opens it is a new revision', async () => {
  const row = { Name: 'Demo.Thing.cls', Coded: false };
  const api = apiAnswering(ok([row]), ok([row]), ok([]));
  const state = stateFor(LISTS.processes, api);
  await state.refresh();
  assert.deepEqual(api.calls, [], 'a refresh before any open has nothing to read');
  await state.open('Demo.Thing.cls', 'USER');
  assert.equal(state.revision(), 1);
  const pending = state.refresh();
  assert.equal(state.busy(), true, 'a refresh in flight is busy');
  assert.equal(state.phase(), 'open', 'and the screen keeps its frame until the answer');
  await pending;
  assert.equal(state.phase(), 'open');
  assert.equal(state.revision(), 2, 'a new frame');
  assert.equal(state.document(), 'Demo.Thing');
  assert.deepEqual(
    api.calls.map((call) => call.scope),
    ['USER', 'USER']
  );
  await state.refresh();
  assert.equal(state.phase(), 'gone', 'a refresh that no longer finds the document says so');
  assert.equal(state.revision(), 2);
});

test('a refresh that does not open the document takes the drawn frame away, whatever the answer, and the next refresh that opens it is a new revision', async () => {
  // Mutation (Rule 19): a refresh swallows an answer that does not open the document and leaves the screen open -> every row goes red.
  const row = { Name: 'Demo.Thing.cls', Coded: false };
  const cases = [
    ['a fault', refusal(500), 'fault', ''],
    ['a refusal that names its pair', refusal(403, { failedPair: '%Ens_Code:READ' }), 'refused', '%Ens_Code:READ'],
    ['a list without the document', ok([]), 'gone', ''],
    ['the document now written as a class', ok([{ ...row, Coded: true }]), 'coded', ''],
  ];
  for (const [label, answer, phase, pair] of cases) {
    const api = apiAnswering(ok([row]), answer, ok([row]));
    const state = stateFor(LISTS.transforms, api);
    await state.open(row.Name, 'HSCUSTOM');
    assert.equal(state.phase(), 'open', label);
    assert.equal(state.revision(), 1);
    await state.refresh();
    assert.equal(state.phase(), phase, `${label}: the screen says so`);
    assert.equal(state.document(), '', `${label}: no document, so no frame is drawn at the old address`);
    assert.equal(state.failedPair(), pair, label);
    assert.equal(state.revision(), 1, `${label}: no new frame`);
    assert.equal(state.busy(), false);
    await state.refresh();
    assert.equal(state.phase(), 'open', `${label}: the next refresh opens it`);
    assert.equal(state.document(), 'Demo.Thing');
    assert.equal(state.revision(), 2, `${label}: as a new frame`);
    assert.equal(api.calls.length, 3, `${label}: one request per read`);
  }
});

test('a refresh whose verdict has turned denied sends nothing and is refused with its pair', async () => {
  // Mutation (Rule 19): the verdict is checked only on the first read -> this goes red (a request is sent).
  const row = { Name: 'Demo.Thing.cls', Coded: false };
  const api = apiAnswering(ok([row]), ok([row]));
  let verdict = ALLOWED;
  const state = stateFor(LISTS.processes, api, () => verdict);
  await state.open(row.Name, 'HSCUSTOM');
  assert.equal(state.phase(), 'open');
  verdict = { allowed: false, failedPair: '%Ens_Code:READ' };
  await state.refresh();
  assert.equal(state.phase(), 'refused');
  assert.equal(state.failedPair(), '%Ens_Code:READ');
  assert.equal(state.document(), '');
  assert.equal(api.calls.length, 1, 'only the first read was sent');
});

test('a class past the rows the read returns is gone, not a fault, however the read reports it; the last row it does return still opens', async () => {
  // Mutation (Rule 19): an answer marked truncated that lacks the row is a fault -> the first row goes red.
  // Mutation (Rule 19): the store looks only at the first 999 rows -> the second row goes red.
  const rows = Array.from({ length: EDITOR_READ_ROWS }, (_, index) => ({ Name: `Demo.Row${String(index).padStart(4, '0')}.cls`, Coded: false }));
  const capped = { kind: 'ok', status: 200, body: { rows, truncated: true } };
  const beyond = apiAnswering(capped);
  const absent = stateFor(LISTS.transforms, beyond);
  await absent.open('Demo.Row9999.cls', 'HSCUSTOM');
  assert.equal(absent.phase(), 'gone', 'a class the capped read does not carry reads as gone');
  assert.equal(absent.document(), '');
  assert.equal(absent.revision(), 0, 'and no frame is drawn');
  assert.equal(beyond.calls.length, 1, 'with no second read to look further');

  const last = stateFor(LISTS.transforms, apiAnswering(capped));
  await last.open(rows[EDITOR_READ_ROWS - 1].Name, 'HSCUSTOM');
  assert.equal(last.phase(), 'open', 'the last row the read returns opens');
  assert.equal(last.document(), 'Demo.Row0999');
});

test('subscribers hear every change, and reset drops an answer still in flight and every listener', async () => {
  const api = apiHeld();
  const state = stateFor(LISTS.rules, api);
  let heard = 0;
  const stop = state.subscribe(() => {
    heard += 1;
  });
  let kept = 0;
  state.subscribe(() => {
    kept += 1;
  });
  const opening = state.open('Demo.Thing.cls', 'HSCUSTOM');
  assert.ok(heard >= 1, 'the open is announced');
  api.releases[0](ok([{ Name: 'Demo.Thing.cls' }]));
  await opening;
  assert.equal(state.phase(), 'open');
  const settled = heard;
  stop();
  const refreshing = state.refresh();
  state.reset();
  const keptAtReset = kept;
  api.releases[1](ok([]));
  await refreshing;
  assert.equal(state.phase(), 'open', 'an answer after reset is dropped');
  assert.equal(heard, settled, 'and a stopped listener hears nothing');
  // Mutation (Rule 19): `reset` keeps its listeners -> the still-subscribed listener hears the next open, and this goes red.
  const reopening = state.open('Demo.Thing.cls', 'HSCUSTOM');
  api.releases[2](ok([{ Name: 'Demo.Thing.cls' }]));
  await reopening;
  assert.equal(kept, keptAtReset, 'and a listener never stopped hears nothing once reset has dropped it');
});

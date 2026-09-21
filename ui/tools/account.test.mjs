import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins Story 15.1's client decode of `POST /api/ocupilot/account/password`: the request the
// dialog sends, and every row of the story's I/O matrix as an outcome.
//
// The three-way split is the whole contract -- close and announce, stay open on the field the
// instance named, or report a fault -- so each row here asserts which arm it lands in, and the
// rejected rows assert the field, the code and the server's own sentence reaching the caller
// unchanged (AD-39).
//
// Mutations (Rule 19):
// - decide `rejected` from the envelope's own `code` rather than from `violationsOf` -> the
//   body-refusal row goes red (its 422 carries no violations and would become an empty refusal).
// - drop the `violations.length > 0` guard -> the malformed-violations row goes red.
// - send the two members under any other names -> the request row goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);

const { changePassword, CHANGE_PASSWORD_PATH, CURRENT_PASSWORD_FIELD, NEW_PASSWORD_FIELD } =
  await import(corePath('account.ts'));

const CURRENT = 'theOldOne9Z';
const NEXT = 'theNewOne9Z';

/** One answer, and a record of the call that asked for it. */
function stubApi(answer) {
  const calls = [];
  return {
    calls,
    requestJson: async (path, init = {}) => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body });
      return answer;
    },
  };
}

const OK = { kind: 'ok', status: 200, body: {} };

function refusal(status, code, detail = null, reason = 'refused') {
  return { kind: 'error', status, code, reason, detail };
}

function violation(field, code, reason) {
  return { field, code, reason };
}

test('the request is a POST to the one absolute path, carrying exactly the two members and no user name', async () => {
  const api = stubApi(OK);
  await changePassword(api, CURRENT, NEXT);
  assert.equal(api.calls.length, 1);
  assert.equal(api.calls[0].path, CHANGE_PASSWORD_PATH);
  assert.equal(CHANGE_PASSWORD_PATH, '/api/ocupilot/account/password');
  assert.equal(api.calls[0].method, 'POST');
  const sent = JSON.parse(api.calls[0].body);
  assert.deepEqual(Object.keys(sent).sort(), [CURRENT_PASSWORD_FIELD, NEW_PASSWORD_FIELD].sort());
  assert.equal(sent[CURRENT_PASSWORD_FIELD], CURRENT);
  assert.equal(sent[NEW_PASSWORD_FIELD], NEXT);
  // No user name, under any spelling: the instance changes $Username and the route accepts none.
  assert.equal(api.calls[0].body.includes('userName'), false);
  assert.equal(api.calls[0].path.includes(CURRENT), false);
  assert.equal(api.calls[0].path.includes(NEXT), false);
});

test('matrix "Happy path": a 200 is `ok` and carries nothing else', async () => {
  const outcome = await changePassword(stubApi(OK), CURRENT, NEXT);
  assert.deepEqual(outcome, { kind: 'ok' });
});

test('matrix "Wrong current password": a 422 violation on currentPassword is `rejected`, with the server\'s own sentence', async () => {
  const api = stubApi(
    refusal(422, 'ACCOUNT.VALIDATION', {
      violations: [
        violation(
          'currentPassword',
          'ACCOUNT.PASSWORD.CURRENT',
          'That is not the current password for this account. Enter it again.'
        ),
      ],
    })
  );
  const outcome = await changePassword(api, CURRENT, NEXT);
  assert.equal(outcome.kind, 'rejected');
  assert.equal(outcome.violations.length, 1);
  assert.equal(outcome.violations[0].field, CURRENT_PASSWORD_FIELD);
  assert.equal(outcome.violations[0].code, 'ACCOUNT.PASSWORD.CURRENT');
  assert.equal(
    outcome.violations[0].reason,
    'That is not the current password for this account. Enter it again.'
  );
});

test('matrix "Policy rejection": the violation lands on newPassword and the instance\'s own text reaches the caller unchanged', async () => {
  // The words an unmodified 2026.2 instance answers for a password under its PasswordPattern.
  const instanceText = 'Password does not match length or pattern requirements';
  const api = stubApi(
    refusal(422, 'ACCOUNT.VALIDATION', {
      violations: [violation('newPassword', 'ACCOUNT.PASSWORD.POLICY', instanceText)],
    })
  );
  const outcome = await changePassword(api, CURRENT, NEXT);
  assert.equal(outcome.kind, 'rejected');
  assert.equal(outcome.violations[0].field, NEW_PASSWORD_FIELD);
  assert.equal(outcome.violations[0].code, 'ACCOUNT.PASSWORD.POLICY');
  assert.equal(outcome.violations[0].reason, instanceText);
});

test('a refusal naming both fields keeps both, in the order the instance sent them', async () => {
  const api = stubApi(
    refusal(422, 'ACCOUNT.VALIDATION', {
      violations: [
        violation('currentPassword', 'ACCOUNT.PASSWORD.CURRENT', 'first'),
        violation('newPassword', 'ACCOUNT.PASSWORD.POLICY', 'second'),
      ],
    })
  );
  const outcome = await changePassword(api, CURRENT, NEXT);
  assert.equal(outcome.kind, 'rejected');
  assert.deepEqual(
    outcome.violations.map((entry) => entry.field),
    ['currentPassword', 'newPassword']
  );
});

test('matrix "Malformed body": a 422 with no violations is an `error`, never an empty refusal', async () => {
  const api = stubApi(refusal(422, 'ACCOUNT.PASSWORD.BODY'));
  const outcome = await changePassword(api, CURRENT, NEXT);
  assert.equal(outcome.kind, 'error');
  assert.equal(outcome.fault.kind, 'rejected');
  assert.equal(outcome.fault.status, 422);
  assert.equal(outcome.fault.code, 'ACCOUNT.PASSWORD.BODY');
  assert.equal(outcome.fault.path, CHANGE_PASSWORD_PATH);
});

test('a 422 whose violations are unreadable is an `error` too -- a dialog with no reason on it is the failure this avoids', async () => {
  for (const detail of [
    { violations: 'not an array' },
    { violations: [] },
    { violations: [{ code: 'ACCOUNT.PASSWORD.POLICY' }] },
    { violations: [{ field: 'newPassword' }] },
    {},
  ]) {
    const outcome = await changePassword(stubApi(refusal(422, 'ACCOUNT.VALIDATION', detail)), CURRENT, NEXT);
    assert.equal(outcome.kind, 'error', `detail ${JSON.stringify(detail)}`);
  }
});

test("the error arm carries the envelope's own reason, so the dialog never publishes refusal copy", async () => {
  // AD-39: the server writes every refusal sentence once. A body refusal names no field, so it
  // lands on the error arm -- and its sentence has to travel with the fault or it is unrenderable.
  const sentence = 'The body must carry exactly two members, the strings currentPassword and newPassword.';
  const outcome = await changePassword(
    stubApi(refusal(422, 'ACCOUNT.PASSWORD.BODY', null, sentence)),
    CURRENT,
    NEXT
  );
  assert.equal(outcome.kind, 'error');
  assert.equal(outcome.reason, sentence);

  // A transport failure carries no envelope, so there is no sentence to pass on.
  const down = await changePassword(
    stubApi({ kind: 'error', status: 0, code: null, reason: null, detail: null }),
    CURRENT,
    NEXT
  );
  assert.equal(down.kind, 'error');
  assert.equal(down.reason, null);
  assert.equal(down.fault.kind, 'unreachable');
});

test('matrix "Any other failure": a 500 is an `error` carrying the server-fault verdict', async () => {
  const outcome = await changePassword(stubApi(refusal(500, 'INTERNAL')), CURRENT, NEXT);
  assert.equal(outcome.kind, 'error');
  assert.equal(outcome.fault.kind, 'server-fault');
  assert.equal(outcome.fault.status, 500);
});

test('the other four non-200 outcomes each take the taxonomy\'s own verdict', async () => {
  const rows = [
    [{ kind: 'error', status: 0, code: null, reason: null, detail: null }, 'unreachable'],
    [refusal(403, 'AUTH.NOPRIVILEGE'), 'refused'],
    [refusal(404, 'ROUTE.NOTFOUND'), 'absent'],
    [{ kind: 'installing', status: 503, code: 'INSTALL.INSTALLING' }, 'not-installed'],
  ];
  for (const [answer, expected] of rows) {
    const outcome = await changePassword(stubApi(answer), CURRENT, NEXT);
    assert.equal(outcome.kind, 'error', JSON.stringify(answer));
    assert.equal(outcome.fault.kind, expected, JSON.stringify(answer));
  }
});

test('no outcome carries either password value back to the caller', async () => {
  const answers = [
    OK,
    refusal(422, 'ACCOUNT.VALIDATION', {
      violations: [violation('newPassword', 'ACCOUNT.PASSWORD.POLICY', 'too short')],
    }),
    refusal(422, 'ACCOUNT.PASSWORD.BODY'),
    refusal(500, 'INTERNAL'),
  ];
  for (const answer of answers) {
    const outcome = await changePassword(stubApi(answer), CURRENT, NEXT);
    const serialized = JSON.stringify(outcome);
    assert.equal(serialized.includes(CURRENT), false, serialized);
    assert.equal(serialized.includes(NEXT), false, serialized);
  }
});

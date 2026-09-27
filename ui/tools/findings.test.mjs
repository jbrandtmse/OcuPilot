// Pins the framework-free half of Story 16.21's Findings panel: the store's newest-read and
// sign-out guards and its hold on a failure, the narrowing of an answer, and `findingLines` --
// each group's findings phrased from the published strings, "Not checked" for every check that
// was not read, and "Nothing to report." only when every check of the group was read.
//
// Mutations (Rule 19):
// - print "Nothing to report." for a group whatever its checks read (drop `allChecked &&` in
//   `findingLines`) -> "a group holding an unread check never says nothing to report" goes red.
// - drop the `request !== this.request` guard in `Findings.load` -> the late-answer row goes red.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const core = (name) => join(uiRoot, 'src', 'app', 'core', name);

const { Findings, FINDINGS_PATH, FINDING_CHECKS, findingLines, findingsOf } = await import(core('findings.ts'));
const { STRINGS } = await import(core('strings.ts'));

const SECURITY = ['webapp-open', 'monitor-open', 'all-holder', 'certificate', 'auditing-off'];

/** Every check `checked`, less any `overrides` names. */
function checks(overrides = {}) {
  return FINDING_CHECKS.map((check) => ({ check, group: SECURITY.includes(check) ? 'security' : 'operations', status: 'checked', ...(overrides[check] ?? {}) }));
}

function finding(check, fields = {}) {
  return { check, group: SECURITY.includes(check) ? 'security' : 'operations', name: '', id: '', route: 'r', scope: 'instance', fix: 'link', ...fields };
}

function lines(body) {
  const answer = findingsOf(body);
  assert.ok(answer, 'the body narrows to an answer');
  return findingLines(answer);
}

const texts = (group) => group.lines.map((line) => line.text);

test('a clean answer reads "Nothing to report." in both groups, Security first', () => {
  const groups = lines({ checks: checks(), findings: [] });
  assert.deepEqual(groups.map((group) => group.heading), [STRINGS.findingsSecurity, STRINGS.findingsOperations]);
  assert.deepEqual(groups.map(texts), [[STRINGS.findingsNothing], [STRINGS.findingsNothing]]);
});

test('a group holding an unread check never says nothing to report, and each unread check says why', () => {
  const groups = lines({
    checks: checks({
      'all-holder': { status: 'unchecked', pair: '%Admin_Secure:USE' },
      certificate: { status: 'truncated' },
      'task-error': { status: 'failed' },
    }),
    findings: [],
  });
  assert.deepEqual(texts(groups[0]), [
    'Not checked: accounts holding %All (requires %Admin_Secure:USE)',
    'Not checked: X.509 certificates (too many to check)',
  ]);
  assert.deepEqual(texts(groups[1]), ['Not checked: suspended tasks (could not be read)']);
  assert.ok(groups.every((group) => group.lines.every((line) => line.kind !== 'clean')));
});

test('a check the answer does not list is not clean either', () => {
  const groups = lines({ checks: checks().filter((row) => row.check !== 'database-full'), findings: [] });
  assert.deepEqual(texts(groups[1]), []);
  assert.deepEqual(texts(groups[0]), [STRINGS.findingsNothing]);
});

test('each finding is its published sentence, why and what to do, the name as given', () => {
  const groups = lines({
    checks: checks(),
    findings: [
      finding('webapp-open', { name: '/csp/<b>x</b>', id: '/csp/<b>x</b>', fix: 'agent' }),
      finding('monitor-open', { name: '/api/monitor', fix: 'agent' }),
      finding('all-holder', { name: '_SYSTEM', fix: 'refused', refused: { code: 'PROHIBITED.SYSTEMACCOUNT', reason: 'A sentence.' } }),
      finding('certificate', { name: 'old', detail: '2026-01-02', expired: true }),
      finding('certificate', { name: 'soon', id: 'soon', detail: '2026-10-20', expired: false }),
      finding('auditing-off', { fix: 'agent' }),
      finding('database-dismounted', { name: '/db/' }),
      finding('database-full', { name: '/big/', detail: '91' }),
      finding('task-manager', { detail: 'taskManagerStoppedBanner' }),
      finding('task-error', { name: 'nightly', id: '1002', fix: 'agent' }),
    ],
  });
  assert.deepEqual(texts(groups[0]), [
    '/csp/<b>x</b> can be reached without signing in and holds a database or administrative role.',
    'The monitoring API, /api/monitor, answers without signing in.',
    '_SYSTEM holds %All.',
    'The certificate old expired on 2026-01-02.',
    'The certificate soon expires on 2026-10-20.',
    STRINGS.auditingStatusOff,
  ]);
  assert.deepEqual(texts(groups[1]), [
    'The database /db/ is dismounted.',
    'The database /big/ is at 91% of its maximum size.',
    STRINGS.taskManagerStoppedBanner,
    'The task nightly was suspended after an error.',
  ]);
  const manager = groups[1].lines[2];
  assert.equal(manager.why, '', 'the banner sentence carries its own why');
  assert.equal(manager.todo, STRINGS.findingTaskManagerStoppedDo);
  assert.equal(groups[0].lines[0].why, STRINGS.findingWebappOpenWhy);
  assert.equal(groups[0].lines[0].todo, STRINGS.findingWebappOpenDo);
  assert.equal(groups[0].lines[2].finding.refused.reason, 'A sentence.');
});

test('the narrowing drops what it cannot trust', () => {
  const answer = findingsOf({
    checks: [{ check: 'nope', status: 'checked' }, { check: 'certificate', status: 'odd' }, { check: 'auditing-off', status: 'checked' }],
    findings: [
      finding('nope'),
      finding('auditing-off', { fix: 'maybe' }),
      finding('all-holder', { fix: 'refused' }),
      finding('task-manager', { detail: 'someOtherKey' }),
      finding('auditing-off', { fix: 'agent', refused: { code: 'X', reason: 'Y' } }),
    ],
  });
  assert.deepEqual(answer.checks, [{ check: 'auditing-off', status: 'checked', pair: '' }]);
  assert.equal(answer.findings.length, 2, 'an unknown check, an unknown fix and a refusal without its sentence are dropped');
  assert.equal(answer.findings[1].refused, null, 'a refusal rides only on a refused finding');
  assert.equal(findingLines(answer)[1].lines.length, 0, 'a task-manager finding naming no banner is not phrased');
  assert.equal(findingsOf({ checks: {} }), null);
  assert.equal(findingsOf(null), null);
});

function ok(body) {
  return { kind: 'ok', status: 200, body };
}

/** A stub API each of whose calls is settled by hand. */
function deferredApi() {
  const pending = [];
  return {
    pending,
    requestJson(path, init = {}) {
      return new Promise((resolve) => pending.push({ path, init, resolve }));
    },
  };
}

test('the store reads its path with the shell scope, keeps a failure from blanking an answer, and settles only the newest read', async () => {
  const api = deferredApi();
  const store = new Findings({ api });
  let notified = 0;
  store.subscribe(() => (notified += 1));

  const first = store.load();
  assert.equal(api.pending[0].path, FINDINGS_PATH);
  assert.equal(api.pending[0].init.scope, undefined, 'no scope override: the shell namespace rides along');
  api.pending[0].resolve(ok({ checks: checks(), findings: [] }));
  await first;
  assert.equal(store.answered(), true);

  const older = store.load();
  const newer = store.load();
  api.pending[2].resolve(ok({ checks: checks(), findings: [finding('auditing-off', { fix: 'agent' })] }));
  await newer;
  api.pending[1].resolve(ok({ checks: checks(), findings: [] }));
  await older;
  assert.equal(store.data().findings.length, 1, 'a late answer does not overwrite a newer one');

  const failing = store.load();
  api.pending[3].resolve({ kind: 'error', status: 0, code: null, reason: null, detail: null });
  await failing;
  assert.equal(store.failed(), true);
  assert.equal(store.data().findings.length, 1, 'a failed read leaves the previous answer standing');
  assert.ok(notified >= 3);
});

test('reset drops the answer, and an answer for a departed principal never lands', async () => {
  const api = deferredApi();
  const store = new Findings({ api });
  const loading = store.load();
  store.reset();
  api.pending[0].resolve(ok({ checks: checks(), findings: [] }));
  await loading;
  assert.equal(store.answered(), false);
  assert.equal(store.data(), null);
});

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

// Pins the client half of Story 18.16's bound and impact against the classes that declare them: the
// proposal card's bound is `RemoteDatabasePort`'s `LISTSECONDS`, its code is the create and update
// tools' `CONSEQUENCE`, and its sentence names the proposal's own data server; the remote delete's
// impact kind is `Impact.cls`'s. Needs nothing but the checkout.
//
// Mutations (Rule 19):
// - change `REMOTE_DATABASE_LIST_SECONDS` in proposal-view.ts -> the bound row goes red.
// - make `remoteListSentence` read the changed row's `before` -> the sentence row goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const repoRoot = join(uiRoot, '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);
const classSource = (...parts) => readFileSync(join(repoRoot, 'src', 'OcuPilot', ...parts), 'utf8');

const { CONSEQUENCE_REMOTELIST, REMOTE_DATABASE_LIST_SECONDS, consequenceSentence, remoteListSentence } = await import(
  corePath('proposal-view.ts')
);
const { IMPACT_PARTS } = await import(corePath('impact.ts'));
const { STRINGS } = await import(corePath('strings.ts'));

test("the card's bound is RemoteDatabasePort's LISTSECONDS", () => {
  const declared = /^Parameter LISTSECONDS As INTEGER = (\d+);/m.exec(classSource('Port', 'RemoteDatabasePort.cls'));
  assert.ok(declared, 'RemoteDatabasePort.cls declares LISTSECONDS');
  assert.equal(REMOTE_DATABASE_LIST_SECONDS, Number(declared[1]));
});

test("the card's code is the create and update tools' own CONSEQUENCE, which consequenceSentence leaves to remoteListSentence", () => {
  for (const tool of ['RemoteDatabaseCreate.cls', 'RemoteDatabaseUpdate.cls']) {
    const declared = /^Parameter CONSEQUENCE = "([^"]+)";/m.exec(classSource('Screen', 'Tool', tool));
    assert.ok(declared, `${tool} declares CONSEQUENCE`);
    assert.equal(CONSEQUENCE_REMOTELIST, declared[1], tool);
  }
  assert.equal(consequenceSentence(CONSEQUENCE_REMOTELIST), '', 'the generic consequence line stays empty for it, so the card states it once');
});

test('the sentence names the data server the proposal sends and the bound, and nothing for another code', () => {
  const filled = (server) =>
    STRINGS.remoteDatabaseListConsequence.replace('<server>', () => server).replace('<n>', () => String(REMOTE_DATABASE_LIST_SECONDS));
  const create = { consequence: CONSEQUENCE_REMOTELIST, changed: [{ field: 'Server', before: '', after: 'DATASRV' }], unchanged: [] };
  assert.equal(remoteListSentence(create), filled('DATASRV'), "a create's server is its changed row's after value");
  const moved = { consequence: CONSEQUENCE_REMOTELIST, changed: [{ field: 'Server', before: 'OLDSRV', after: 'NEWSRV' }], unchanged: [] };
  assert.equal(remoteListSentence(moved), filled('NEWSRV'), "a re-point to another server names the server it lists");
  const kept = {
    consequence: CONSEQUENCE_REMOTELIST,
    changed: [{ field: 'Directory', before: '/a/', after: '/b/' }],
    unchanged: [{ field: 'Server', value: 'KEPTSRV' }],
  };
  assert.equal(remoteListSentence(kept), filled('KEPTSRV'), "a re-point on the same server names it from the unchanged half");
  assert.equal(remoteListSentence({ ...create, changed: [{ field: 'Server', before: '', after: '$&<n>' }] }), filled('$&<n>'), 'a name is shown as written');
  assert.equal(remoteListSentence({ ...create, consequence: 'WEBAPP.UNAUTHENTICATED' }), '');
  assert.equal(remoteListSentence({ ...create, consequence: undefined }), '');
});

test("the remote delete's impact kind is Impact.cls's, with its two parts", () => {
  const declared = /^Parameter KINDREMOTEDATABASEDELETE = "([^"]+)";/m.exec(classSource('Kernel', 'Proposal', 'Impact.cls'));
  assert.ok(declared, 'Impact.cls declares KINDREMOTEDATABASEDELETE');
  assert.deepEqual(IMPACT_PARTS[declared[1]], ['namespaces', 'applications']);
});

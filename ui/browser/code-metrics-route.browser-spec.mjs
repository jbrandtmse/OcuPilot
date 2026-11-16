/**
 * System Explorer's Code metrics and Document hashes over the shipped read route, against the throwaway instance (Story 24.1,
 * QA): `GET /api/ocupilot/screens/<tool>/read`, the route the story's matrix names, with the shipped port, the shipped gate and
 * the shipped document cap, none of the in-process seams `OcuPilot.Test.DevToolRead` uses.
 *
 * What it adds to that class and to `code-metrics.browser-spec.mjs`, each over HTTP:
 *
 * 1. **AC1.** The matrix rows the browser spec does not draw: the probe package's one metrics row and its three hash rows, the
 *    routines and the include file, the generated routines under `yes` and `no`, a pattern that matches nothing, and a cap below
 *    the count. The hashes are compared with a SHA-256 this file computes from the lines the instance's own Atelier document API
 *    serves, a reader the port never calls, and the lines counted with the lines that API serves.
 * 2. **AC3.** Every refusal row as the route answers it: the wide pattern, each bad shape, the shipped cap of 1,000 documents (a
 *    real pattern over the namespace's classes, with the count and the cap in `detail`), and an unknown namespace. A refusal
 *    carries no rows.
 * 3. **The gate with real principals.** A `%Developer` principal reads both screens; an administrator who holds every other floor
 *    resource but not `%Development:USE` is refused with `AUTH.NOPRIVILEGE` naming that pair. The in-process class reaches the
 *    gate through a seam only, so this is the one place the shipped `GATECLASS` is read.
 *
 * **It changes the instance only inside its own names.** `OcuPilot.Test.DevToolProbe` saves the `OcuProbe241` documents in `USER`
 * and removes them, and `OcuPilot.Test.DeveloperFloorFixture` creates two principals and removes them; both run over `docker
 * exec` on a throwaway, and the principals are armed by `OCUPILOT_ALLOW_PRINCIPALS`, which only `scripts/ci-throwaway.sh` sets.
 * It opens no browser, so it reaches no browser context and needs no remembered-state reset.
 *
 * Run, from `ui/`: `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1
 * browser/code-metrics-route.browser-spec.mjs`. It reads the deployed instance's classes, not the bundle, so no build is needed.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createHash, randomBytes } from 'node:crypto';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig } from '../browser.config.mjs';
import { authHeader } from './panel-spec.mjs';
import { assertThrowaway } from './structural-walk.mjs';
import { escapeOs, markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();

const NAMESPACE = 'USER';
const PACKAGE = 'OcuProbe241';
const CLASSES = ['Alpha', 'Beta', 'Gamma'].map((name) => `${PACKAGE}.${name}.cls`);
const ROUTES = { metrics: 'explorer.codemetrics', hashes: 'explorer.documenthashes' };
const READ_PATH = (tool) => `/api/ocupilot/screens/${tool}/read`;
const ATELIER_DOC = (ns, name) => `/api/atelier/v1/${ns}/doc/${encodeURIComponent(name)}`;

const METRIC_FIELDS = ['Documents', 'Lines', 'Code', 'CodePercent', 'SourceCode', 'TestCode', 'Comments', 'CommentPercent', 'Blank', 'BlankPercent'];

/** The pair the gate names for a caller without the development privilege, and the cap the shipped port holds. */
const DEVELOPMENT_PAIR = '%Development:USE';
const SHIPPED_CAP = 1000;

const passwords = { developer: `OcuPilotQa${randomBytes(12).toString('hex')}Aa9`, administrator: `OcuPilotQa${randomBytes(12).toString('hex')}Bb8` };
const users = { developer: '', administrator: '' };

/** The Basic header for a principal this spec created. */
const basic = (user, password) => `Basic ${Buffer.from(`${user}:${password}`).toString('base64')}`;

/** Read a screen's route as `authorization` (the signed-in administrator by default); answer the status and the parsed body. */
async function read(tool, params, authorization = authHeader(config)) {
  const query = new URLSearchParams({ ns: NAMESPACE, ...params });
  const answer = await fetch(`${config.origin}${READ_PATH(tool)}?${query}`, { headers: { Authorization: authorization } });
  const text = await answer.text();
  let body = null;
  try {
    body = JSON.parse(text);
  } catch {
    // A body that is not JSON stays null, and the assertion that reads it names the text.
  }
  return { status: answer.status, body, text };
}

/** The lines the instance's Atelier document API serves for `name` in `ns`. */
async function atelierLines(ns, name) {
  const answer = await fetch(`${config.origin}${ATELIER_DOC(ns, name)}`, { headers: { Authorization: authHeader(config) } });
  assert.equal(answer.status, 200, `${name} is served by the document API`);
  const { result } = await answer.json();
  return result.content;
}

/** SHA-256 in upper-case hex over each line followed by a line feed, as the hash screen writes it. */
const hashOf = (lines) => createHash('sha256').update(lines.map((line) => `${line}\n`).join('')).digest('hex').toUpperCase();

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec saves documents and creates principals, so it never runs inside the live container');
  assert.ok(!/^ocupilot-slot-/.test(config.container), 'nor inside a development instance');
  await assertThrowaway(config);
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);

  const output = runIris(config.container, [
    `Do ##class(OcuPilot.Test.DevToolProbe).Remove("${NAMESPACE}")`,
    `Set tProbe=##class(OcuPilot.Test.DevToolProbe).Make("${NAMESPACE}")`,
    'Write "OCU-QA-PROBE-START:"_$System.Status.IsOK(tProbe)_":OCU-QA-PROBE-END",!',
    `Set tSC=##class(OcuPilot.Test.DeveloperFloorFixture).EnsurePrincipal("${escapeOs(passwords.developer)}","",.tDev)`,
    'Write "OCU-QA-DEV-START:"_$System.Status.IsOK(tSC)_"|"_$Get(tDev)_":OCU-QA-DEV-END",!',
    `Set tSC=##class(OcuPilot.Test.DeveloperFloorFixture).EnsurePrincipal("${escapeOs(passwords.administrator)}","administrator",.tAdm)`,
    'Write "OCU-QA-ADM-START:"_$System.Status.IsOK(tSC)_"|"_$Get(tAdm)_":OCU-QA-ADM-END",!',
  ]);
  assert.equal(markerValue(output, 'QA-PROBE'), '1', `the probe documents are saved: ${output}`);
  const [devOk, dev] = (markerValue(output, 'QA-DEV') ?? '').split('|');
  const [admOk, adm] = (markerValue(output, 'QA-ADM') ?? '').split('|');
  assert.equal(devOk, '1', `the developer principal was created: ${output}`);
  assert.equal(admOk, '1', `the administrator principal was created: ${output}`);
  users.developer = dev;
  users.administrator = adm;

  // Read from the instance, so the refusal below is a principal that really lacks the pair and the read above is one that holds it.
  const held = runIris(config.container, [
    `Write "OCU-QA-HELD-START:"_$SYSTEM.Security.CheckUserPermission("${escapeOs(dev)}","%Development","USE")_"|"_$SYSTEM.Security.CheckUserPermission("${escapeOs(adm)}","%Development","USE")_":OCU-QA-HELD-END",!`,
  ]);
  assert.equal(markerValue(held, 'QA-HELD'), '1|0', `the developer holds ${DEVELOPMENT_PAIR} and the administrator does not: ${held}`);
});

after(async () => {
  // `before` refused the live container; nothing was created there, and nothing is removed.
  if (config.container === LIVE_CONTAINER) return;
  const removed = runIris(config.container, [
    'Write "OCU-QA-LEFT-START:"_##class(OcuPilot.Test.DeveloperFloorFixture).RemovePrincipals()_":OCU-QA-LEFT-END",!',
    `Write "OCU-QA-GONE-START:"_$System.Status.IsOK(##class(OcuPilot.Test.DevToolProbe).Remove("${NAMESPACE}"))_":OCU-QA-GONE-END",!`,
  ]);
  assert.equal(markerValue(removed, 'QA-LEFT'), '', `the principals and their roles are gone: ${removed}`);
  assert.equal(markerValue(removed, 'QA-GONE'), '1', `the probe documents are removed: ${removed}`);
});

// AC1. Mutation (Rule 19): make `Kernel.Utils.DocumentLines` drop a class's last line, recompile on the throwaway -> the Lines and
// the hash comparisons go red.
test('AC1: over the route, the probe package answers one metrics row and one hash per class, equal to what the document API serves', async () => {
  const lines = {};
  for (const name of CLASSES) lines[name] = await atelierLines(NAMESPACE, name);

  const metrics = await read(ROUTES.metrics, { spec: `${PACKAGE}.*.cls` });
  assert.equal(metrics.status, 200, metrics.text);
  assert.deepEqual(metrics.body.fields, METRIC_FIELDS, 'the ten fields, in order');
  assert.equal(metrics.body.truncated, false, 'not truncated');
  assert.equal(metrics.body.rows.length, 1, 'one row');
  const [row] = metrics.body.rows;
  assert.equal(row.Documents, 3, 'three documents');
  assert.equal(row.Lines, CLASSES.reduce((sum, name) => sum + lines[name].length, 0), 'Lines is the count of lines the document API serves');
  assert.equal(row.Code + row.Comments + row.Blank, row.Lines, 'every line is code, a comment or blank');
  assert.equal(row.SourceCode + row.TestCode, row.Code, 'code is source or test');
  assert.ok(row.TestCode > 0 && row.SourceCode > 0 && row.Comments > 0 && row.Blank > 0, `the probe holds every kind of line: ${JSON.stringify(row)}`);
  assert.equal(row.CodePercent, Math.round((row.Code / row.Lines) * 1000) / 10, 'Code % is Code over Lines, to one decimal');

  const hashes = await read(ROUTES.hashes, { spec: `${PACKAGE}.*.cls` });
  assert.equal(hashes.status, 200, hashes.text);
  assert.deepEqual(hashes.body.fields, ['Document', 'Hash', 'Modified']);
  assert.deepEqual(hashes.body.rows.map((entry) => entry.Document), CLASSES, 'one row for each probe class');
  assert.equal(hashes.body.truncated, false, 'not truncated');
  for (const entry of hashes.body.rows) {
    assert.equal(entry.Hash, hashOf(lines[entry.Document]), `${entry.Document}: SHA-256 of the lines the document API serves`);
    assert.match(entry.Modified, /^\d{4}-\d\d-\d\d [\d:.]+$/, `${entry.Document}: a modified time`);
  }
  assert.equal(new Set(hashes.body.rows.map((entry) => entry.Hash)).size, 3, 'three different documents, three different hashes');
});

test('AC1: over the route, routines and the include file, generated routines, no match and a cap below the count', async () => {
  const routines = `${PACKAGE}*.mac,${PACKAGE}*.inc`;
  const hashes = await read(ROUTES.hashes, { spec: routines });
  assert.equal(hashes.status, 200, hashes.text);
  assert.deepEqual(hashes.body.rows.map((entry) => entry.Document), [`${PACKAGE}Inc.inc`, `${PACKAGE}Mac.mac`], 'one row for each routine and include file');
  for (const entry of hashes.body.rows) assert.equal(entry.Hash, hashOf(await atelierLines(NAMESPACE, entry.Document)), `${entry.Document}: SHA-256 of the lines the document API serves`);
  const metrics = await read(ROUTES.metrics, { spec: routines });
  assert.equal(metrics.body.rows[0].Documents, 2, 'Code metrics counts both');
  assert.ok(metrics.body.rows[0].Lines > 0, 'and their lines');

  const generated = `${PACKAGE}.*.int`;
  const withGenerated = await read(ROUTES.hashes, { spec: generated, generated: 'yes' });
  assert.deepEqual(withGenerated.body.rows.map((entry) => entry.Document), [`${PACKAGE}.Beta.1.int`, `${PACKAGE}.Gamma.1.int`], "generated yes lists the compiled probes' generated routines");
  for (const entry of withGenerated.body.rows) assert.equal(entry.Hash, hashOf(await atelierLines(NAMESPACE, entry.Document)), `${entry.Document}: SHA-256 of the lines the document API serves`);
  const without = await read(ROUTES.hashes, { spec: generated, generated: 'no' });
  assert.equal(without.status, 200, without.text);
  assert.deepEqual(without.body.rows, [], 'generated no lists none');
  const byDefault = await read(ROUTES.hashes, { spec: generated });
  assert.deepEqual(byDefault.body.rows, [], 'and so does leaving the choice out');
  assert.equal(byDefault.body.criteria.generated, 'no', 'whose answer names the default it applied');

  const absent = `${PACKAGE}Absent.*.cls`;
  const noHashes = await read(ROUTES.hashes, { spec: absent });
  assert.deepEqual([noHashes.status, noHashes.body.rows, noHashes.body.truncated], [200, [], false], 'a pattern that matches nothing is no hash rows, not truncated');
  const noMetrics = await read(ROUTES.metrics, { spec: absent });
  assert.equal(noMetrics.body.rows.length, 1, 'and one metrics row');
  assert.equal(noMetrics.body.rows[0].Documents, 0, 'of no documents');

  const cut = await read(ROUTES.hashes, { spec: `${PACKAGE}.*.cls`, maxRows: '2' });
  assert.equal(cut.body.rows.length, 2, "a cap below the count answers the cap's rows");
  assert.equal(cut.body.truncated, true, 'and says it was cut');
  const whole = await read(ROUTES.hashes, { spec: `${PACKAGE}.*.cls`, maxRows: '3' });
  assert.deepEqual([whole.body.rows.length, whole.body.truncated], [3, false], 'a cap at the count answers every row and is not truncated');
});

// AC3. Mutation (Rule 19): raise `DevToolPort.MAXDOCUMENTS` to 100000 and recompile the port -> the refusal's cap and the shipped-cap
// leg go red (a `%*.cls` pattern is then read, not refused).
test('AC3: over the route, every refusal row answers its status and code, and no rows', async () => {
  const refused = async (tool, params, status, code, label) => {
    const answer = await read(tool, params);
    assert.equal(answer.status, status, `${label}: HTTP status (${answer.text})`);
    assert.equal(answer.body?.code, code, `${label}: code`);
    assert.equal(answer.body?.rows, undefined, `${label}: and no rows`);
    return answer.body;
  };

  for (const tool of Object.values(ROUTES)) {
    for (const spec of ['*', `${PACKAGE}.*.cls, *`]) {
      const body = await refused(tool, { spec }, 400, 'EXPLORER.SPEC.WIDE', `${tool} ${spec}`);
      assert.match(body.reason, /^Name a package or a pattern/, `${tool} ${spec}: the written reason`);
    }
    const shapes = ['a/b', 'a\\b', 'a..b', 'a b.cls', `a${String.fromCharCode(7)}b`, 'a,,b.cls', 'a.cls,', ',a.cls', `${PACKAGE}.*.cls;x`];
    for (const spec of shapes) {
      const body = await refused(tool, { spec }, 400, 'PORT.VALIDATION', `${tool} ${JSON.stringify(spec)}`);
      assert.match(body.reason, /^Name documents with letters, digits/, `${tool} ${JSON.stringify(spec)}: the shape reason`);
    }
    // The screen's own criterion check answers these two before the port's (which the in-process class pins as PORT.VALIDATION).
    const long = await refused(tool, { spec: 'a'.repeat(257) }, 400, 'READ.CRITERION', `${tool}: 257 characters`);
    assert.match(long.reason, /256 characters/, `${tool}: names the spec's length`);
    await refused(tool, { spec: `${PACKAGE}.*.cls`, generated: 'abc' }, 400, 'READ.CRITERION', `${tool}: generated abc`);

    const many = await refused(tool, { spec: '%*.cls' }, 400, 'EXPLORER.SPEC.TOOMANY', `${tool}: the namespace's classes`);
    assert.equal(many.detail.max, SHIPPED_CAP, `${tool}: the shipped cap`);
    assert.ok(many.detail.count > SHIPPED_CAP, `${tool}: over it: ${many.detail.count}`);
    assert.ok(many.reason.includes('1,000 documents'), `${tool}: the reason names the cap: ${many.reason}`);

    // The route's own scope check answers before the port does, so the code here is the route's (inference: the same as every
    // other screen's); the status and the absence of rows are what the matrix row asks.
    const unknown = await refused(tool, { spec: `${PACKAGE}.*.cls`, ns: 'NOSUCH241' }, 400, 'NS.UNKNOWN', `${tool}: an unknown namespace`);
    assert.ok(unknown.reason.length > 0, `${tool}: with a reason`);
  }

  const reread = await read(ROUTES.hashes, { spec: `${PACKAGE}.*.cls` });
  assert.equal(reread.body.rows.length, 3, 'a read after the refusals still answers its three rows');
});

// The gate. Mutation (Rule 19): set `DevToolPort.GATECLASS` to a class whose `EvaluateRequired` answers 1 and recompile the port ->
// the administrator is answered rows and the refusal leg goes red.
test('Gate: a %Developer principal reads both screens, and an administrator without %Development:USE is refused naming that pair', async () => {
  const developer = basic(users.developer, passwords.developer);
  const administrator = basic(users.administrator, passwords.administrator);

  const named = await atelierLines('HSCUSTOM', '%Library.Persistent.cls');
  const developerHashes = await read(ROUTES.hashes, { spec: '%Library.Persistent.cls', ns: 'HSCUSTOM' }, developer);
  assert.equal(developerHashes.status, 200, developerHashes.text);
  assert.equal(developerHashes.body.rows.length, 1, 'one row');
  assert.equal(developerHashes.body.rows[0].Hash, hashOf(named), 'the SHA-256 of the class the principal asked about');
  const developerMetrics = await read(ROUTES.metrics, { spec: '%Library.Persistent.cls', ns: 'HSCUSTOM' }, developer);
  assert.equal(developerMetrics.status, 200, developerMetrics.text);
  assert.equal(developerMetrics.body.rows[0].Lines, named.length, 'Lines is the count the document API serves');
  const inUser = await read(ROUTES.hashes, { spec: '%Library.Persistent.cls' }, developer);
  assert.equal(inUser.status, 200, `in ${NAMESPACE} as well: ${inUser.text}`);

  for (const tool of Object.values(ROUTES)) {
    const denied = await read(tool, { spec: '%Library.Persistent.cls', ns: 'HSCUSTOM' }, administrator);
    assert.equal(denied.status, 403, `${tool}: HTTP status (${denied.text})`);
    assert.equal(denied.body.code, 'AUTH.NOPRIVILEGE', `${tool}: code`);
    assert.equal(denied.body.detail.failedPair, DEVELOPMENT_PAIR, `${tool}: naming the pair`);
    assert.equal(denied.body.rows, undefined, `${tool}: and no rows`);
  }
});

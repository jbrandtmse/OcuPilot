// The admin-spec differ and the canonical form of the table it reads (Story 13.2, AC4).
//
// Runs in `gates`, with no instance: the pure differ is driven over fixtures, and the checked-in
// table is asserted to be in the form `--derive` produces rather than one a hand edit could reach.
// The half that needs an instance is the `--origin` step in the `instance` job.
//
// The `--origin` gate's own failure path is driven here too, against a local `http.createServer`
// standing in for the instance -- the stub-driven shape `ci.test.mjs` uses for the shell scripts.
// Without it `compare()` could `return 0` on a drift with the whole suite green.
//
// Mutations (Rule 19): remove one "/v2/..." key from `spec/admin-v2-paths.json` -> the 185-key
// and canonical-form cases go red naming the hand-edit. Add a fabricated entry to
// KNOWN_DIFFERENCES -> the declared-versus-observed case goes red naming the entry that matches
// nothing. Count the path-level `parameters` key as a verb -> the verb-count case goes red.
// Change `compare()`'s drift `return 1` to `return 0` -> the four `--origin` drift cases go red.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { createServer } from 'node:http';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import {
  diffAdminSpec,
  EXPECTED_PATHS,
  EXPECTED_VERBS,
  HTTP_VERBS,
  KNOWN_DIFFERENCES,
  instanceSpecUrl,
  serializeTable,
  tableProblems,
  upstreamMismatch,
  upstreamUrl,
  UPSTREAM,
  v2PathTable,
  verbCount,
  TABLE_PATH,
} from './admin-spec.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const tableText = readFileSync(TABLE_PATH, 'utf8');
const table = JSON.parse(tableText);

const DECLARED_UPSTREAM_ONLY = '/v2/security/oauth2/revoke';
const DECLARED_INSTANCE_ONLY = '/v2/security/oauth2/server/revoke';

/** A two-path table plus whatever the caller adds, standing in for the vendored side. */
function baseTable(extra = {}) {
  return { '/v2/namespace': ['get', 'post'], '/v2/lock': ['delete', 'get'], ...extra };
}

// --- The pure differ ---------------------------------------------------------------------------

test('two identical tables with the declared difference on neither side report no drift at all', () => {
  const result = diffAdminSpec({ vendored: baseTable(), instance: baseTable(), knownDifferences: [] });
  assert.deepEqual(result.added, []);
  assert.deepEqual(result.removed, []);
  assert.deepEqual(result.methodDifferences, []);
  assert.deepEqual(result.staleDifferences, []);
  assert.equal(result.counts.common, 2);
});

test('a path the instance gained is reported as added and undeclared', () => {
  const result = diffAdminSpec({
    vendored: baseTable(),
    instance: baseTable({ '/v2/brand-new': ['get'] }),
    knownDifferences: [],
  });
  assert.deepEqual(result.added, ['/v2/brand-new']);
  assert.deepEqual(result.undeclaredAdded, ['/v2/brand-new']);
  assert.deepEqual(result.removed, []);
});

test('a path the instance lost is reported as removed and undeclared', () => {
  const instance = baseTable();
  delete instance['/v2/lock'];
  const result = diffAdminSpec({ vendored: baseTable(), instance, knownDifferences: [] });
  assert.deepEqual(result.removed, ['/v2/lock']);
  assert.deepEqual(result.undeclaredRemoved, ['/v2/lock']);
  assert.deepEqual(result.added, []);
});

test('a common path whose method set changed is reported with both sets', () => {
  const result = diffAdminSpec({
    vendored: baseTable(),
    instance: baseTable({ '/v2/namespace': ['get'] }),
    knownDifferences: [],
  });
  assert.deepEqual(result.methodDifferences, [{ path: '/v2/namespace', vendored: 'get,post', instance: 'get' }]);
  assert.deepEqual(result.added, []);
  assert.deepEqual(result.removed, []);
});

test('a declared known difference that IS observed is not a failure', () => {
  const vendored = baseTable({ [DECLARED_UPSTREAM_ONLY]: ['post'] });
  const instance = baseTable({ [DECLARED_INSTANCE_ONLY]: ['post'] });
  const result = diffAdminSpec({ vendored, instance });
  assert.deepEqual(result.removed, [DECLARED_UPSTREAM_ONLY]);
  assert.deepEqual(result.added, [DECLARED_INSTANCE_ONLY]);
  assert.deepEqual(result.undeclaredRemoved, [], 'the declared side accounts for it');
  assert.deepEqual(result.undeclaredAdded, []);
  assert.deepEqual(result.staleDifferences, []);
});

test('a declared known difference that is NOT observed fails, naming the stale entry', () => {
  // Both spellings present on both sides: the declared difference describes something that is no
  // longer true, and an entry nobody notices is how a gate quietly stops checking.
  const both = baseTable({ [DECLARED_UPSTREAM_ONLY]: ['post'], [DECLARED_INSTANCE_ONLY]: ['post'] });
  const result = diffAdminSpec({ vendored: both, instance: both });
  assert.equal(result.staleDifferences.length, 1);
  assert.equal(result.staleDifferences[0].upstreamOnly, DECLARED_UPSTREAM_ONLY);
});

test('exactly one known difference is declared, and both its sides are /v2/ paths', () => {
  assert.equal(KNOWN_DIFFERENCES.length, 1, 'one reviewed entry, not a growing allowlist');
  for (const entry of KNOWN_DIFFERENCES) {
    assert.match(entry.upstreamOnly, /^\/v2\//);
    assert.match(entry.instanceOnly, /^\/v2\//);
    assert.ok(entry.why.length > 20, 'each entry says why it is expected');
  }
});

// --- Reading a document ------------------------------------------------------------------------

test('the path table is derived from .paths without assuming a document version', () => {
  // Upstream is OpenAPI 3.0.0 and the instance's generated spec is Swagger 2.0; the two carry the
  // same `paths` shape and different version keys, so nothing here reads a version at all.
  const paths = { '/v2/a': { get: {}, post: {} }, '/v1/b': { get: {} } };
  assert.deepEqual(v2PathTable({ openapi: '3.0.0', paths }), { '/v2/a': ['get', 'post'] });
  assert.deepEqual(v2PathTable({ swagger: '2.0', paths }), { '/v2/a': ['get', 'post'] });
});

test('the path-level parameters key is not counted as an HTTP verb', () => {
  // Reading it as one produced a fictitious 75-difference reading between the two documents.
  assert.ok(!HTTP_VERBS.includes('parameters'));
  const derived = v2PathTable({ paths: { '/v2/a': { parameters: [], PUT: {} } } });
  assert.deepEqual(derived, { '/v2/a': ['put'] }, 'the verb is kept, lower-cased; the key is not');
});

test('a path item carrying no verb at all yields no row', () => {
  assert.deepEqual(v2PathTable({ paths: { '/v2/a': { parameters: [] }, '/v2/b': { get: {} } } }), { '/v2/b': ['get'] });
});

test('a document with no paths object is an error, never an empty table', () => {
  // A failed read scored as "no paths" is a failed lookup read as a negative result, which would
  // make every instance path look added.
  assert.throws(() => v2PathTable({ openapi: '3.0.0' }), /no `paths` object/);
  assert.throws(() => v2PathTable(null), /no `paths` object/);
});

// --- The checked-in table ----------------------------------------------------------------------

test('the vendored table is in canonical derived form and carries the counts it was derived at', () => {
  assert.deepEqual(
    tableProblems(tableText, { expectedPaths: EXPECTED_PATHS, expectedVerbs: EXPECTED_VERBS }),
    [],
    'the table is what `--derive` produces, byte for byte'
  );
  assert.equal(Object.keys(table.paths).length, EXPECTED_PATHS);
  assert.equal(verbCount(table.paths), EXPECTED_VERBS);
  assert.equal(serializeTable(table), tableText, 're-serializing it reproduces the file exactly');
});

test('every key is a /v2/ path and every value a sorted, non-empty, lower-case verb list', () => {
  let rows = 0;
  for (const [path, verbs] of Object.entries(table.paths)) {
    assert.match(path, /^\/v2\//, `${path} is a v2 path`);
    assert.ok(Array.isArray(verbs) && verbs.length > 0, `${path} carries at least one verb`);
    assert.deepEqual(verbs, [...verbs].sort(), `${path}'s verbs are sorted`);
    for (const verb of verbs) assert.ok(HTTP_VERBS.includes(verb), `${path} names the HTTP verb ${verb}`);
    rows += 1;
  }
  assert.equal(rows, EXPECTED_PATHS, `the check looked at ${rows} row(s)`);
});

test('the source block names the upstream commit, the blob and the retrieval date', () => {
  assert.equal(table.source.repository, UPSTREAM.repository);
  assert.equal(table.source.branch, 'master', 'the upstream default branch is master, not main');
  assert.match(table.source.commit, /^[0-9a-f]{40}$/);
  assert.equal(table.source.commit, UPSTREAM.commit);
  assert.equal(table.source.path, 'mainspec_v2.json');
  assert.match(table.source.sha256, /^[0-9a-f]{64}$/);
  assert.equal(table.source.bytes, UPSTREAM.bytes);
  assert.match(table.source.retrieved, /^\d{4}-\d{2}-\d{2}$/);
  assert.match(table.source.note, /not vendored/, 'and says the document itself is deliberately absent');
});

test('the declared known difference is one of the vendored paths, so it cannot be a typo', () => {
  assert.ok(DECLARED_UPSTREAM_ONLY in table.paths, 'the upstream spelling is in the table');
  assert.ok(!(DECLARED_INSTANCE_ONLY in table.paths), 'and the instance spelling is not');
});

test('a hand-edited table is refused before any diff runs', () => {
  const hacked = JSON.parse(tableText);
  delete hacked.paths[Object.keys(hacked.paths)[0]];
  const problems = tableProblems(`${JSON.stringify(hacked, null, 2)}\n`, {
    expectedPaths: EXPECTED_PATHS,
    expectedVerbs: EXPECTED_VERBS,
  });
  assert.ok(problems.some((problem) => problem.includes('184')), `expected a count problem, got ${JSON.stringify(problems)}`);

  const unsorted = JSON.parse(tableText);
  unsorted.paths['/v2/hand-edited'] = ['post', 'get'];
  const unsortedProblems = tableProblems(`${JSON.stringify(unsorted, null, 2)}\n`, {});
  assert.ok(unsortedProblems.some((problem) => problem.includes('not lower-case and sorted')));

  const wrongCommit = JSON.parse(tableText);
  wrongCommit.source.commit = '0'.repeat(40);
  assert.ok(tableProblems(serializeTable(wrongCommit), {}).some((problem) => problem.includes('pinned to')));
});

// --- The two URLs ------------------------------------------------------------------------------

test('the upstream URL is pinned to the commit, never to a branch', () => {
  assert.equal(
    upstreamUrl(),
    `https://raw.githubusercontent.com/${UPSTREAM.repository}/${UPSTREAM.commit}/${UPSTREAM.path}`
  );
  assert.ok(!upstreamUrl().includes('/master/'), 'a branch URL would move under the pin');
});

test('the instance spec URL is the v1 form the admin API answers, with %25SYS escaped once', () => {
  assert.equal(instanceSpecUrl('http://localhost:52776'), 'http://localhost:52776/api/mgmnt/v1/%25SYS/spec/api/admin');
  assert.equal(instanceSpecUrl('http://localhost:52776/'), 'http://localhost:52776/api/mgmnt/v1/%25SYS/spec/api/admin');
});

test('this file reads the table from the repository root, not from a copy beside the tools', () => {
  assert.equal(TABLE_PATH, join(here, '..', '..', 'spec', 'admin-v2-paths.json'));
});

// --- The CLI, against a local stand-in for the instance -----------------------------------------
//
// Every case below runs `admin-spec.mjs --origin` as a child process against a server this file
// starts, so `compare()`, `main()` and the process exit code are all executed. The vendored side
// is the checked-in table itself; only the served document varies.

const CLI = join(here, 'admin-spec.mjs');

/** The instance's generated spec as a Swagger 2.0 document: the vendored table, plus `mutate`. */
function servedDocument(mutate = () => {}) {
  const paths = {};
  for (const [path, verbs] of Object.entries(table.paths)) {
    paths[path] = Object.fromEntries(verbs.map((verb) => [verb, {}]));
  }
  // The one declared known difference, as the instance actually spells it.
  delete paths[DECLARED_UPSTREAM_ONLY];
  paths[DECLARED_INSTANCE_ONLY] = { post: {} };
  mutate(paths);
  return { swagger: '2.0', paths };
}

/** Run the CLI against a server answering `respond`, and return its exit code and output. */
async function runOrigin(respond, args = ['--origin']) {
  const server = createServer(respond);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const origin = `http://127.0.0.1:${server.address().port}`;
  try {
    return await new Promise((resolve, reject) => {
      const child = spawn(process.execPath, [CLI, ...args, origin], { stdio: ['ignore', 'pipe', 'pipe'] });
      let output = '';
      child.stdout.on('data', (chunk) => { output += chunk; });
      child.stderr.on('data', (chunk) => { output += chunk; });
      child.on('error', reject);
      child.on('close', (code) => resolve({ code, output }));
    });
  } finally {
    server.close();
  }
}

/** Run the CLI against a served document, with no argument after `--origin` when `args` says so. */
function runAgainst(document, args) {
  return runOrigin((request, response) => {
    response.writeHead(200, { 'content-type': 'application/json' });
    response.end(JSON.stringify(document));
  }, args);
}

test('--origin exits 0 against an instance that matches the vendored table', async () => {
  const run = await runAgainst(servedDocument());
  assert.equal(run.code, 0, run.output);
  assert.match(run.output, /admin-spec: clean\./);
});

test('--origin exits non-zero naming a path the instance gained and nothing declares', async () => {
  const run = await runAgainst(servedDocument((paths) => { paths['/v2/undeclared/addition'] = { get: {} }; }));
  assert.notEqual(run.code, 0, run.output);
  assert.match(run.output, /\/v2\/undeclared\/addition is on the instance and not in the vendored table/);
  assert.match(run.output, new RegExp(UPSTREAM.commit), 'and the commit the drift is measured against');
});

test('--origin exits non-zero naming a path the instance lost and nothing declares', async () => {
  const gone = Object.keys(table.paths).find((path) => path !== DECLARED_UPSTREAM_ONLY);
  const run = await runAgainst(servedDocument((paths) => { delete paths[gone]; }));
  assert.notEqual(run.code, 0, run.output);
  assert.ok(run.output.includes(`${gone} is in the vendored table and not on the instance`), run.output);
});

test('--origin exits non-zero naming a common path whose method set moved', async () => {
  const moved = Object.keys(table.paths).find((path) => table.paths[path].length > 1);
  const run = await runAgainst(servedDocument((paths) => { paths[moved] = { get: {} }; }));
  assert.notEqual(run.code, 0, run.output);
  assert.ok(run.output.includes(`${moved} answers [get] on the instance`), run.output);
});

test('--origin exits non-zero naming a declared known difference the instance no longer shows', async () => {
  // Both spellings served: the declared entry describes something that stopped being true, and an
  // entry nobody notices is how a gate quietly stops checking.
  const run = await runAgainst(servedDocument((paths) => { paths[DECLARED_UPSTREAM_ONLY] = { post: {} }; }));
  assert.notEqual(run.code, 0, run.output);
  assert.match(run.output, /is no longer observed, so the entry is stale/);
  assert.ok(run.output.includes(DECLARED_UPSTREAM_ONLY), run.output);
});

test('a non-200 from the instance is the tool\'s own error line, not a rejection stack', async () => {
  const run = await runOrigin((request, response) => {
    response.writeHead(503);
    response.end('unavailable');
  });
  assert.notEqual(run.code, 0, run.output);
  assert.match(run.output, /^admin-spec: .*answered HTTP 503/m);
  assert.doesNotMatch(run.output, /UnhandledPromiseRejection|at async/, 'and no stack');
});

test('a flag whose value is missing is the usage line and exit 2, never an undefined argument', async () => {
  const runFlag = (args) =>
    new Promise((resolve, reject) => {
      const child = spawn(process.execPath, [CLI, ...args], { stdio: ['ignore', 'pipe', 'pipe'] });
      let output = '';
      child.stdout.on('data', (chunk) => { output += chunk; });
      child.stderr.on('data', (chunk) => { output += chunk; });
      child.on('error', reject);
      child.on('close', (code) => resolve({ code, output }));
    });

  for (const args of [['--origin'], ['--origin', '--derive'], ['--derive', '--from'], ['--derive'], []]) {
    const run = await runFlag(args);
    assert.equal(run.code, 2, `${JSON.stringify(args)}: ${run.output}`);
    assert.match(run.output, /usage: node tools\/admin-spec\.mjs/, JSON.stringify(args));
  }
});

// --- What the licensing paragraph in ATTRIBUTIONS.md asserts -------------------------------------

test('no <FileCopy> in module.xml names spec/ or the vendored table', () => {
  // ATTRIBUTIONS.md states in prose that the table reaches neither the built bundle nor the IPM
  // archive. This is what keeps a future <FileCopy> from falsifying that sentence silently.
  const manifest = readFileSync(join(here, '..', '..', 'module.xml'), 'utf8');
  const copies = [...manifest.matchAll(/<FileCopy\b[^>]*>/g)].map((match) => match[0]);
  assert.ok(copies.length > 0, 'the manifest declares at least one FileCopy, so this read is not vacuous');
  for (const copy of copies) {
    assert.doesNotMatch(copy, /spec\//, `${copy} would put the vendored table into the IPM archive`);
    assert.doesNotMatch(copy, /admin-v2-paths/, copy);
  }
});

test('no <Resource> in module.xml names a top-level directory either', () => {
  // The SECOND half of the same sentence in ATTRIBUTIONS.md -- "and no roster package names a
  // top-level directory". The FileCopy read above leaves it unheld, so the prose was broader
  // than its guard. Every resource is a `.PKG` class package; a directory resource is what would
  // sweep `spec/` in.
  const manifest = readFileSync(join(here, '..', '..', 'module.xml'), 'utf8');
  const resources = [...manifest.matchAll(/<Resource\b[^>]*\bName="([^"]+)"[^>]*>/g)].map((match) => match[1]);
  assert.ok(resources.length > 0, 'the manifest declares at least one Resource, so this read is not vacuous');
  for (const name of resources) {
    assert.match(name, /\.PKG$/, `${name} is not a class package, so it may carry files the prose says are absent`);
    assert.doesNotMatch(name, /spec/i, name);
  }
});

// --- The pin's own integrity ---------------------------------------------------------------------

test('--derive refuses a document that is not the pinned one, rather than stamping it with the pin', async () => {
  // The table records the upstream commit, blob, byte count and digest, and ATTRIBUTIONS.md
  // cites the same commit. Nothing downstream can re-check that, because the document is
  // deliberately not vendored -- so the read is the only place it can be checked. Without this
  // the integrity fields are decorative: any local file at all derives a table asserting it came
  // from f764aea.
  //
  // Mutation (Rule 19): delete the `upstreamMismatch` call from `derive()` -> this goes red, and
  // the committed table is rewritten from the wrong document.
  const dir = mkdtempSync(join(tmpdir(), 'ocupilot-admin-spec-derive-'));
  try {
    const wrong = join(dir, 'not-the-pin.json');
    writeFileSync(wrong, JSON.stringify({ openapi: '3.0.0', paths: { '/v2/x': { get: {} } } }));
    const before = readFileSync(TABLE_PATH, 'utf8');
    const run = spawnSync(process.execPath, [CLI, '--derive', '--from', wrong], { encoding: 'utf8' });
    assert.equal(run.status, 1, `${run.stdout}${run.stderr}`);
    assert.match(run.stderr, /is not intersystems-community\/sysadmin-api-specification@/);
    assert.match(run.stderr, /byte\(s\); the pin was taken at 1004473/);
    assert.equal(readFileSync(TABLE_PATH, 'utf8'), before, 'and the committed table is untouched');
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('upstreamMismatch names the digest when the length happens to match', () => {
  const pinned = { bytes: 4, sha256: createHash('sha256').update('good').digest('hex') };
  assert.equal(upstreamMismatch(Buffer.from('good'), pinned), '');
  assert.match(upstreamMismatch(Buffer.from('bad!'), pinned), /hashes to [0-9a-f]{64}; the pin was taken at/);
  assert.match(upstreamMismatch(Buffer.from('longer'), pinned), /is 6 byte\(s\); the pin was taken at 4/);
});

test('a declared known difference whose two spellings answer different verbs is a drift, not an excuse', async () => {
  // The declared entry pairs two spellings of ONE endpoint, so neither spelling is a common path
  // and neither reaches the method-set comparison. That left the single path the gate excuses as
  // the only one whose methods it never compared.
  //
  // Mutation (Rule 19): delete the `knownMethodDifferences` loop from `diffAdminSpec` -> this
  // goes red while every other --origin case stays green.
  const run = await runAgainst(servedDocument((paths) => { paths[DECLARED_INSTANCE_ONLY] = { post: {}, get: {} }; }));
  assert.notEqual(run.code, 0, run.output);
  assert.match(run.output, /is excused as one endpoint under two spellings/);
  assert.ok(run.output.includes(DECLARED_INSTANCE_ONLY), run.output);
});

test('the CLI asks the instance for its generated admin spec, with credentials', async () => {
  // The unit test above pins what `instanceSpecUrl` composes; nothing pinned that `compare()`
  // requests it, or that the Basic header the throwaway needs is sent at all.
  let seen = null;
  const run = await runOrigin((request, response) => {
    seen = { url: request.url, authorization: request.headers.authorization };
    response.writeHead(200, { 'content-type': 'application/json' });
    response.end(JSON.stringify(servedDocument()));
  });
  assert.equal(run.code, 0, run.output);
  assert.equal(seen.url, '/api/mgmnt/v1/%25SYS/spec/api/admin');
  assert.equal(seen.authorization, `Basic ${Buffer.from('_SYSTEM:SYS').toString('base64')}`);
});

test('tableProblems names a malformed row, not only a miscount (AC4)', () => {
  // AC4 asks the gate to exit "naming the malformed row". The count, sort-order and commit
  // branches were driven; the shape branches were not, so the clause the criterion names was the
  // untested half.
  const good = JSON.parse(readFileSync(TABLE_PATH, 'utf8'));
  const withPaths = (paths) => serializeTable({ source: good.source, paths });

  assert.equal(tableProblems('{not json').length, 1);
  assert.match(tableProblems('{not json')[0], /^the table is not JSON: /);
  assert.deepEqual(tableProblems('[]'), ['the table carries no `paths` object']);
  assert.ok(
    tableProblems(JSON.stringify({ paths: {} })).includes(
      'the table carries no `source` block, so a drift could not name what it drifted from'
    ),
    'a table with no source block is named as such'
  );
  assert.ok(
    tableProblems(withPaths({ '/v1/legacy': ['get'] })).some((problem) => problem === '/v1/legacy is not a /v2/ path'),
    'a key outside the v2 surface is named'
  );
  assert.ok(
    tableProblems(withPaths({ '/v2/x': [] })).some((problem) => problem === '/v2/x carries no verb list'),
    'an empty verb list is named'
  );
  assert.ok(
    tableProblems(withPaths({ '/v2/x': ['parameters'] })).some((problem) => problem.includes('which is not an HTTP verb')),
    'and the path-level `parameters` key, the one that produced the fictitious 75-difference reading, is not a verb'
  );
  const missingField = { ...good.source };
  delete missingField.sha256;
  assert.ok(
    tableProblems(serializeTable({ source: missingField, paths: good.paths })).includes('the source block names no sha256'),
    'each absent source field is named on its own'
  );
});

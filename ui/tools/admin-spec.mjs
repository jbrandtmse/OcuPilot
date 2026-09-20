// The vendor admin API drift gate (Story 13.2, AD-27).
//
// `/api/admin` v2 is experimental until IRIS 2027.1, and OcuPilot's whole port rests on it. This
// holds the instance's own generated spec equal to the upstream specification AT A NAMED COMMIT,
// so a version that moves the ground fails here with a source to point at rather than reaching a
// user.
//
// **What is vendored is the derived path-and-method table, never the document.** The upstream
// repository declares no license and this repository is public, so copying `mainspec_v2.json` in
// would be a redistribution nobody has granted. `spec/admin-v2-paths.json` is a set of facts
// about an API -- which paths exist and which HTTP verbs each answers -- produced by `--derive`
// below and regenerable from the commit-pinned document at any time.
//
// **CI never fetches from GitHub.** `--origin` reads the checked-in table and the throwaway's own
// generated spec, so the gate has no network dependency on a third party and cannot go red
// because a remote moved. `--derive --fetch` is run by a human when the pin is moved.
//
// **Verbs only.** The path-level `parameters` key is not an HTTP method; counting it as one
// produced a fictitious 75-difference reading. The two documents are also different versions --
// upstream is OpenAPI 3.0.0, the instance's generated spec is Swagger 2.0 -- so `.paths` is read
// without assuming either.

import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(here, '..', '..');

/** Where `spec/admin-v2-paths.json` lives, relative to the repository root. */
export const TABLE_PATH = join(REPO_ROOT, 'spec', 'admin-v2-paths.json');

/** The eight HTTP methods an OpenAPI or Swagger path item may carry. Everything else is a key. */
export const HTTP_VERBS = ['get', 'put', 'post', 'delete', 'options', 'head', 'patch', 'trace'];

/** The prefix this gate is about: the admin API's v2 surface. */
export const V2_PREFIX = '/v2/';

/**
 * The upstream document the table was derived from, pinned to the commit that last touched it.
 * Moving the pin is a new fetch, a new `--derive`, and a reviewed change to this block.
 */
export const UPSTREAM = {
  repository: 'intersystems-community/sysadmin-api-specification',
  branch: 'master',
  commit: 'f764aea427e5c0b1dd08a4c18a0457e0ff7b3b34',
  path: 'mainspec_v2.json',
  blob: '373e8627e755c0cb89fee855fb70514f48376d60',
  bytes: 1004473,
  sha256: '1ab154c7c5d9b25e6b227944a44a120c670686f876c2e14abfb9ee5898596650',
  retrieved: '2026-09-19',
  note: 'The specification document itself is deliberately not vendored: the upstream repository declares no license and this repository is public. What is checked in is this derived path-and-method table, regenerable with `node ui/tools/admin-spec.mjs --derive --fetch`.',
};

/** The commit-pinned raw URL `--derive --fetch` reads. */
export function upstreamUrl(upstream = UPSTREAM) {
  return `https://raw.githubusercontent.com/${upstream.repository}/${upstream.commit}/${upstream.path}`;
}

/** The instance's own generated spec for `/api/admin`, from an origin root. */
export function instanceSpecUrl(origin) {
  return `${origin.replace(/\/+$/, '')}/api/mgmnt/v1/%25SYS/spec/api/admin`;
}

/**
 * The reviewed differences between the two sides, held equal in BOTH directions: an undeclared
 * difference fails, and a declared difference that is not observed fails naming the stale entry.
 *
 * Measured 2026-09-19 against a 2026.2 instance: 185 v2 paths each side, 184 common, and the HTTP
 * method set identical on every one of those 184.
 */
export const KNOWN_DIFFERENCES = [
  {
    upstreamOnly: '/v2/security/oauth2/revoke',
    instanceOnly: '/v2/security/oauth2/server/revoke',
    why: 'The same endpoint under two spellings. The instance wins: it is what the port calls, and it is the same class of spec-versus-instance disagreement recorded for the OAuth client ServerDefinition field.',
  },
];

/**
 * The `/v2/*` path-and-method table of an OpenAPI 3 or Swagger 2 document: `{path: [verb, ...]}`,
 * verbs lower-cased and sorted. A path item carrying no verb at all is kept out, because a table
 * entry with an empty method list is a path nothing answers.
 */
export function v2PathTable(document) {
  if (document === null || typeof document !== 'object' || typeof document.paths !== 'object' || document.paths === null) {
    throw new Error('the document carries no `paths` object, so no path table can be derived from it');
  }
  const table = {};
  for (const path of Object.keys(document.paths).sort()) {
    if (!path.startsWith(V2_PREFIX)) continue;
    const item = document.paths[path];
    if (item === null || typeof item !== 'object') continue;
    const verbs = Object.keys(item)
      .map((key) => key.toLowerCase())
      .filter((key) => HTTP_VERBS.includes(key))
      .sort();
    if (verbs.length === 0) continue;
    table[path] = verbs;
  }
  return table;
}

/** The canonical text of the vendored table: sorted paths, sorted verbs, two-space indent, one trailing newline. */
export function serializeTable({ source, paths }) {
  const ordered = {};
  for (const path of Object.keys(paths).sort()) {
    ordered[path] = [...paths[path]].map((verb) => verb.toLowerCase()).sort();
  }
  return `${JSON.stringify({ source, paths: ordered }, null, 2)}\n`;
}

/** The number of verb entries a table carries in total. */
export function verbCount(table) {
  return Object.values(table).reduce((total, verbs) => total + verbs.length, 0);
}

/**
 * Pure. The differences between two `/v2/*` path tables, with the declared ones separated out.
 *
 * `added` are paths the instance carries and the vendored table does not; `removed` the reverse;
 * `methodDifferences` one entry per common path whose verb sets disagree. `undeclaredAdded`,
 * `undeclaredRemoved` and `staleDifferences` are what a caller fails on: every difference that no
 * `knownDifferences` entry accounts for, and every declared entry that nothing observed.
 */
export function diffAdminSpec({ vendored, instance, knownDifferences = KNOWN_DIFFERENCES }) {
  const vendoredPaths = Object.keys(vendored).sort();
  const instancePaths = Object.keys(instance).sort();
  const added = instancePaths.filter((path) => !(path in vendored));
  const removed = vendoredPaths.filter((path) => !(path in instance));
  const common = vendoredPaths.filter((path) => path in instance);

  const methodDifferences = [];
  for (const path of common) {
    const ours = [...vendored[path]].sort().join(',');
    const theirs = [...instance[path]].sort().join(',');
    if (ours !== theirs) methodDifferences.push({ path, vendored: ours, instance: theirs });
  }

  const declaredAdded = new Set(knownDifferences.map((entry) => entry.instanceOnly).filter(Boolean));
  const declaredRemoved = new Set(knownDifferences.map((entry) => entry.upstreamOnly).filter(Boolean));
  const staleDifferences = knownDifferences.filter(
    (entry) =>
      (entry.instanceOnly !== undefined && !added.includes(entry.instanceOnly)) ||
      (entry.upstreamOnly !== undefined && !removed.includes(entry.upstreamOnly))
  );

  // A declared difference pairs two spellings of ONE endpoint, so neither spelling is a common
  // path and neither reaches `methodDifferences` above. Without this the method set of the one
  // path the gate excuses is the only one it never compares -- a rename that also re-methoded
  // the endpoint would pass, which is the drift this gate exists for.
  const knownMethodDifferences = [];
  for (const entry of knownDifferences) {
    if (entry.upstreamOnly === undefined || entry.instanceOnly === undefined) continue;
    const ours = vendored[entry.upstreamOnly];
    const theirs = instance[entry.instanceOnly];
    if (ours === undefined || theirs === undefined) continue;
    const oursText = [...ours].sort().join(',');
    const theirsText = [...theirs].sort().join(',');
    if (oursText !== theirsText) {
      knownMethodDifferences.push({
        upstreamOnly: entry.upstreamOnly,
        instanceOnly: entry.instanceOnly,
        vendored: oursText,
        instance: theirsText,
      });
    }
  }

  return {
    added,
    removed,
    common,
    methodDifferences,
    knownMethodDifferences,
    undeclaredAdded: added.filter((path) => !declaredAdded.has(path)),
    undeclaredRemoved: removed.filter((path) => !declaredRemoved.has(path)),
    staleDifferences,
    counts: { vendored: vendoredPaths.length, instance: instancePaths.length, common: common.length },
  };
}

/**
 * Every reason the checked-in table is not in canonical derived form, as sentences: a shape that
 * is not `{source, paths}`, a key that is not a `/v2/` path, a value that is not a non-empty
 * lower-cased sorted list of HTTP verbs, a path or verb count other than the one the pin was
 * derived at, text that is not the canonical serialization of its own content, or a
 * `source.commit` other than this tool's pin.
 *
 * A count-preserving canonical edit is NOT detectable here: moving a verb from one path's list to
 * another re-serializes identically and leaves both counts unchanged. Settling that needs the
 * upstream document, which is deliberately not vendored -- `--derive` from the pinned commit is
 * what re-establishes the table.
 */
export function tableProblems(text, { expectedPaths, expectedVerbs, upstream = UPSTREAM } = {}) {
  const problems = [];
  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch (error) {
    return [`the table is not JSON: ${error.message}`];
  }
  if (parsed === null || typeof parsed !== 'object' || typeof parsed.paths !== 'object' || parsed.paths === null) {
    return ['the table carries no `paths` object'];
  }
  if (parsed.source === null || typeof parsed.source !== 'object') {
    problems.push('the table carries no `source` block, so a drift could not name what it drifted from');
  } else {
    for (const field of ['repository', 'branch', 'commit', 'path', 'blob', 'bytes', 'sha256', 'retrieved', 'note']) {
      if (parsed.source[field] === undefined) problems.push(`the source block names no ${field}`);
    }
    if (parsed.source.commit !== upstream.commit) {
      problems.push(`the source block records commit ${parsed.source.commit}, and this tool is pinned to ${upstream.commit}`);
    }
  }
  for (const [path, verbs] of Object.entries(parsed.paths)) {
    if (!path.startsWith(V2_PREFIX)) problems.push(`${path} is not a /v2/ path`);
    if (!Array.isArray(verbs) || verbs.length === 0) {
      problems.push(`${path} carries no verb list`);
      continue;
    }
    for (const verb of verbs) {
      if (!HTTP_VERBS.includes(verb)) problems.push(`${path} names ${JSON.stringify(verb)}, which is not an HTTP verb`);
    }
    const sorted = [...verbs].map((verb) => String(verb).toLowerCase()).sort();
    if (sorted.join(',') !== verbs.join(',')) problems.push(`${path}'s verbs are not lower-case and sorted`);
  }
  if (serializeTable(parsed) !== text) {
    problems.push('the table is not byte-identical to its own canonical serialization, so it was edited by hand rather than derived');
  }
  if (expectedPaths !== undefined && Object.keys(parsed.paths).length !== expectedPaths) {
    problems.push(
      `the table carries ${Object.keys(parsed.paths).length} /v2/ path(s); the pin was derived at ${expectedPaths}. ` +
        'A re-derivation at a new commit moves this count: update EXPECTED_PATHS in ui/tools/admin-spec.mjs rather than editing the table'
    );
  }
  if (expectedVerbs !== undefined && verbCount(parsed.paths) !== expectedVerbs) {
    problems.push(
      `the table carries ${verbCount(parsed.paths)} verb entr(ies); the pin was derived at ${expectedVerbs}. ` +
        'A re-derivation at a new commit moves this count: update EXPECTED_VERBS in ui/tools/admin-spec.mjs rather than editing the table'
    );
  }
  return problems;
}

/** The counts the checked-in table was derived at, asserted by `--origin` and by the suite. */
export const EXPECTED_PATHS = 185;
export const EXPECTED_VERBS = 271;

// --- The impure half: fetching, reading and the CLI ------------------------------------------

/**
 * The seconds a fetch may take before it is abandoned. The gate is placed ahead of the long
 * suites so a drift fails in seconds; without a deadline an instance that accepts the connection
 * and never answers would hold the step open to the job's own cap instead.
 */
export const FETCH_TIMEOUT_MS = 30000;

async function fetchText(url, { username, password } = {}) {
  const headers = {};
  if (username) headers.Authorization = `Basic ${Buffer.from(`${username}:${password ?? ''}`).toString('base64')}`;
  const response = await fetch(url, { headers, signal: AbortSignal.timeout(FETCH_TIMEOUT_MS) });
  if (!response.ok) throw new Error(`${url} answered HTTP ${response.status}`);
  return Buffer.from(await response.arrayBuffer());
}

async function fetchJson(url, credentials) {
  return JSON.parse((await fetchText(url, credentials)).toString('utf8'));
}

/**
 * Why `bytes` is not the document the pin names, or `""` when it is.
 *
 * The table stamps every row it writes with `UPSTREAM`'s commit, blob, byte count and digest, and
 * `ATTRIBUTIONS.md` cites the same commit. Nothing downstream can re-check that -- the document
 * is deliberately not vendored -- so the one moment it CAN be checked is here, as the bytes are
 * read. Without this the integrity fields are decorative: any document at all derives a table
 * asserting it came from `f764aea`.
 */
export function upstreamMismatch(bytes, upstream = UPSTREAM) {
  if (bytes.length !== upstream.bytes) {
    return `the document is ${bytes.length} byte(s); the pin was taken at ${upstream.bytes}`;
  }
  const digest = createHash('sha256').update(bytes).digest('hex');
  if (digest !== upstream.sha256) {
    return `the document hashes to ${digest}; the pin was taken at ${upstream.sha256}`;
  }
  return '';
}

/** `from` reads a local copy; otherwise `--fetch` was given and the pinned commit is fetched. */
async function derive({ from }) {
  const source = from === '' ? upstreamUrl() : from;
  const bytes = from === '' ? await fetchText(upstreamUrl()) : readFileSync(from);
  const mismatch = upstreamMismatch(bytes);
  if (mismatch !== '') {
    console.error(
      `admin-spec: ${source} is not ${UPSTREAM.repository}@${UPSTREAM.commit} (${UPSTREAM.path}) -- ${mismatch}.\n` +
        '  Deriving from it would stamp the table with a commit it did not come from. Move the pin in UPSTREAM deliberately, or fetch the pinned commit.'
    );
    return 1;
  }
  const document = JSON.parse(bytes.toString('utf8'));
  const paths = v2PathTable(document);
  const text = serializeTable({ source: UPSTREAM, paths });
  writeFileSync(TABLE_PATH, text);
  console.log(
    `admin-spec: derived ${Object.keys(paths).length} /v2/ path(s) carrying ${verbCount(paths)} verb entr(ies) from ${source} into ${TABLE_PATH}`
  );
  return 0;
}

async function compare(origin, { username, password }) {
  const text = readFileSync(TABLE_PATH, 'utf8');
  const problems = tableProblems(text, { expectedPaths: EXPECTED_PATHS, expectedVerbs: EXPECTED_VERBS });
  if (problems.length > 0) {
    console.error(`admin-spec: the vendored table is not in canonical derived form (${UPSTREAM.repository}@${UPSTREAM.commit}) --`);
    for (const problem of problems) console.error(`  ${problem}`);
    return 1;
  }
  const vendored = JSON.parse(text).paths;
  const instance = v2PathTable(await fetchJson(instanceSpecUrl(origin), { username, password }));
  const result = diffAdminSpec({ vendored, instance });

  console.log(
    `admin-spec: ${result.counts.vendored} vendored /v2/ path(s), ${result.counts.instance} on the instance, ${result.counts.common} common, ` +
      `${result.methodDifferences.length} method-set difference(s), ${KNOWN_DIFFERENCES.length} declared known difference(s)`
  );

  const failures = [];
  for (const path of result.undeclaredRemoved) {
    failures.push(`${path} is in the vendored table and not on the instance`);
  }
  for (const path of result.undeclaredAdded) {
    failures.push(`${path} is on the instance and not in the vendored table`);
  }
  for (const { path, vendored: ours, instance: theirs } of result.methodDifferences) {
    failures.push(`${path} answers [${theirs}] on the instance and [${ours}] in the vendored table`);
  }
  for (const { upstreamOnly, instanceOnly, vendored: ours, instance: theirs } of result.knownMethodDifferences) {
    failures.push(
      `the declared known difference ${JSON.stringify(upstreamOnly)} against ${JSON.stringify(instanceOnly)} is excused as one endpoint under two spellings, ` +
        `but the instance answers [${theirs}] there and the vendored table [${ours}]`
    );
  }
  for (const entry of result.staleDifferences) {
    failures.push(
      `the declared known difference ${JSON.stringify(entry.upstreamOnly)} against ${JSON.stringify(entry.instanceOnly)} is no longer observed, so the entry is stale`
    );
  }
  if (failures.length > 0) {
    console.error(
      `admin-spec: the instance's generated spec has drifted from ${UPSTREAM.repository}@${UPSTREAM.commit} (${UPSTREAM.path}, retrieved ${UPSTREAM.retrieved}) --`
    );
    for (const failure of failures) console.error(`  ${failure}`);
    return 1;
  }
  console.log('admin-spec: clean.');
  return 0;
}

export const USAGE = 'admin-spec: usage: node tools/admin-spec.mjs --origin <url> | --derive [--fetch | --from <file>]';

/**
 * The CLI. Exit 0 clean, 1 drift or error, 2 a usage error.
 *
 * A flag that takes a value is refused when the next token is missing or is itself a flag, so a
 * dropped argument is the usage line rather than `undefined` reaching `readFileSync` or
 * `.replace`. `--derive` with neither `--from` nor `--fetch` is a usage error too: fetching is
 * the human step, and CI must never reach a third party by default.
 */
async function main(argv) {
  const at = (flag) => argv.indexOf(flag);
  const usage = () => {
    console.error(USAGE);
    return 2;
  };
  const valueAfter = (index) => {
    const value = argv[index + 1];
    return value === undefined || value.startsWith('--') ? '' : value;
  };
  if (at('--derive') > 0) {
    const fromAt = at('--from');
    const from = fromAt > 0 ? valueAfter(fromAt) : '';
    if (fromAt > 0 && from === '') return usage();
    if (from === '' && at('--fetch') <= 0) return usage();
    return derive({ from });
  }
  const originAt = at('--origin');
  if (originAt > 0) {
    const origin = valueAfter(originAt);
    if (origin === '') return usage();
    return compare(origin, {
      username: process.env.OCUPILOT_ADMIN_SPEC_USER ?? '_SYSTEM',
      password: process.env.OCUPILOT_ADMIN_SPEC_PASSWORD ?? 'SYS',
    });
  }
  return usage();
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main(process.argv)
    .then((code) => {
      process.exitCode = code;
    })
    .catch((error) => {
      // A non-200 from the instance, an unreadable table and a JSON parse failure all arrive
      // here; the tool's own error line is what the job reads, not a rejection stack.
      console.error(`admin-spec: ${error.message}`);
      process.exitCode = 1;
    });
}

/**
 * The `turnprobe` wire helpers, shared (Story 4.5's own fixture; extracted for Story 4.7,
 * **DW-1086**). `turn.browser-spec.mjs`, `reply.browser-spec.mjs` and `context-chip.browser-spec.mjs`
 * each defined the same ten functions locally, with a per-file marker prefix (`OCUTURN-`,
 * `OCUREPLY-`, `OCUCHIP-`) beside `iris-session.mjs`'s own `OCU-<name>-START` convention -- a
 * second convention this file retires. Every marker here follows `iris-session.mjs`'s literal
 * shape; the caller's own `marker` string names the operation rather than the file, so a failure
 * message still says which call failed without inventing a second template to do it.
 *
 * **Options object, not positional file state.** Each helper takes `{container, marker}` plus its
 * own arguments, rather than closing over module-level `config`/`preparedId` the way the three
 * local copies did -- there is exactly one copy of this file per test process (`node --test`
 * gives each `*.browser-spec.mjs` file its own process), but three *callers* of it, and a shared
 * copy that still reached into file-local state would just move the duplication here instead of
 * removing it.
 *
 * **`scriptReply` asserts `OcuPilot.Test.TurnProvider.Script`'s own `%Status`.** The three local
 * copies wrote the literal `"ok"` into the marker and asserted `markerValue(...)` was truthy --
 * an `assert.ok('ok')` that cannot fail regardless of whether `Script` itself succeeded. `Script`
 * now returns a genuine `%Status` (refusing an unarmed, empty tag), and this threads it through
 * the marker and asserts `IsOK` -- the falsification a caller passing `''` for `tag` reddens.
 *
 * **Named outside the `*.browser-spec.mjs` glob**, the way `list-spec.mjs` is: `npm run
 * test:browser` runs `node --test browser/*.browser-spec.mjs`, and this file has no `test()` of
 * its own for that runner to collect -- it would otherwise fail at `before`/`after` with nothing
 * registered.
 *
 * **`armProbeDefinition`/`disarmProbeDefinition`** own the arm-then-disarm order in one place:
 * remove any definition a crashed prior run left (`EnsureDefinition` inserts, it does not
 * upsert), record the default marker to restore, arm a fresh default definition tagged for this
 * file's first probe tag, and -- on the way out -- remove it and restore the recorded default.
 * Before this, each file's own `before`/`after` paired these calls by hand; the cleanup hazard
 * (`switches.browser-spec.mjs` reads the panel assuming nothing is configured) now exists once.
 */

import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';

/**
 * `{container, marker}`: `container` is the throwaway container name (`browserConfig().container`);
 * `marker` names this call for a failure message and for the wire marker `runIris` writes and
 * reads back, on `iris-session.mjs`'s own `OCU-<name>-START` shape.
 * @typedef {{container: string, marker: string}} ProbeOptions
 */

/** Doubles `"` for an ObjectScript string literal. */
export function escapeOs(value) {
  return String(value).replace(/"/g, '""');
}

/** Run ObjectScript lines inside `container`, in the install namespace, and answer stdout+stderr. */
export function runIris(container, lines) {
  const script = [
    'Set $NAMESPACE=$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"):"HSCUSTOM",1:"USER")',
    ...lines,
    'Halt',
  ].join('\n');
  const result = spawnSync('docker', ['exec', '-i', container, 'iris', 'session', 'iris', '-U', '%SYS'], {
    input: `${script}\n`,
    encoding: 'utf8',
    timeout: 600000,
  });
  return `${result.stdout ?? ''}${result.stderr ?? ''}`;
}

/** Point a marker-wrapped one-liner's answer out of `runIris`'s combined output. */
export function markerValue(output, marker) {
  const re = new RegExp(`OCU-${marker}-START:(.*?):OCU-${marker}-END`);
  return re.exec(output)?.[1] ?? null;
}

const tagCounters = new Map();

/** One `turnprobe` tag per test, so a stale script from an earlier test cannot answer a later one.
 * Counted per `options.marker`, so two files (two processes, two module instances in practice)
 * never share a counter, and two distinctly-named callers within one file do not collide either. */
export function nextTag(options) {
  const prefix = options.marker;
  const count = (tagCounters.get(prefix) ?? 0) + 1;
  tagCounters.set(prefix, count);
  return `${prefix}${count}`;
}

/**
 * The id currently carrying the default marker, or `''`. Read through the marker convention
 * because `runIris` answers the whole IRIS session transcript: a bare `Write` yields the banner
 * and the prompts too, and that multi-line value embedded in the next script's string literal
 * breaks the script instead of failing loudly (DW-1075).
 */
export function markedDefault(options) {
  const name = `${options.marker}-PRIOR`;
  const output = runIris(options.container, [
    `Write "OCU-${name}-START:"_##class(OcuPilot.Test.TurnWireFixture).MarkedDefault()_":OCU-${name}-END",!`,
  ]);
  const value = markerValue(output, name);
  assert.notEqual(value, null, `MarkedDefault answered: ${output}`);
  return value;
}

/**
 * Remove every probe definition and restore `prior` as the default marker, asserting that none
 * survived. A leftover enabled, default-marked definition is instance-wide state that changes
 * what later specs see -- `switches.browser-spec.mjs` reads the panel's read-only line on the
 * stated assumption that nothing is configured -- and a cleanup whose status nobody reads is how
 * that reaches them.
 */
export function removeDefinition(options, prior) {
  const name = `${options.marker}-RM`;
  const output = runIris(options.container, [
    `Set sc=##class(OcuPilot.Test.TurnWireFixture).RemoveDefinition("${escapeOs(prior)}")`,
    `Write "OCU-${name}-START:"_$System.Status.IsOK(sc)_":OCU-${name}-END",!`,
  ]);
  assert.equal(markerValue(output, name), '1', `RemoveDefinition succeeded: ${output}`);
}

/** Create (or repoint) the default `turnprobe` definition for `tag`, and answer its id. */
export function ensureDefinition(options, tag) {
  const name = `${options.marker}-DEF`;
  const output = runIris(options.container, [
    `Set sc=##class(OcuPilot.Test.TurnWireFixture).EnsureDefinition("${escapeOs(tag)}",.id)`,
    `Write "OCU-${name}-START:"_$System.Status.IsOK(sc)_"|"_id_":OCU-${name}-END",!`,
  ]);
  const value = markerValue(output, name);
  assert.ok(value, `EnsureDefinition answered: ${output}`);
  const [ok, id] = value.split('|');
  assert.equal(ok, '1', `EnsureDefinition succeeded: ${output}`);
  return id;
}

/** Point `definitionId`'s current definition at a fresh tag, so this test's scripts cannot answer
 * another's turn. */
export function setTag(options, definitionId, tag) {
  const name = `${options.marker}-TAG`;
  const output = runIris(options.container, [
    `Set sc=##class(OcuPilot.Test.TurnWireFixture).SetTag("${escapeOs(definitionId)}","${escapeOs(tag)}")`,
    `Write "OCU-${name}-START:"_$System.Status.IsOK(sc)_":OCU-${name}-END",!`,
  ]);
  assert.equal(markerValue(output, name), '1', `SetTag succeeded: ${output}`);
}

/**
 * Script one scripted reply for `tag`: `hangSeconds` before answering, then `bodyExpr`
 * (ObjectScript) with HTTP `httpStatus` and the `Retry-After` header `retryAfter`. Asserts
 * `OcuPilot.Test.TurnProvider.Script`'s own `%Status`, threaded through the marker -- an unarmed
 * (empty) `tag` refuses, and this is where that would surface.
 *
 * The last two default to the 200 this adapter used to answer unconditionally, so every caller
 * written before Story 4.8 is unchanged. `httpStatus` 0 is the seam's own "no HTTP answer at all"
 * and reaches the turn as a transport timeout.
 */
export function scriptReply(options, tag, hangSeconds, bodyExpr, httpStatus = 200, retryAfter = '') {
  const name = `${options.marker}-SCRIPT`;
  const output = runIris(options.container, [
    `Set sc=##class(OcuPilot.Test.TurnProvider).Script("${escapeOs(tag)}",${hangSeconds},${bodyExpr},${httpStatus},"${escapeOs(retryAfter)}")`,
    `Write "OCU-${name}-START:"_$System.Status.IsOK(sc)_":OCU-${name}-END",!`,
  ]);
  assert.equal(markerValue(output, name), '1', `Script succeeded: ${output}`);
}

/** Forget `tag`'s script and recorded calls. */
export function forgetTag(options, tag) {
  runIris(options.container, [`Do ##class(OcuPilot.Test.TurnProvider).Forget("${escapeOs(tag)}")`]);
}

/**
 * Arm a fresh default `turnprobe` definition for this file's run: clear anything a crashed prior
 * run left (`EnsureDefinition` inserts, never upserts), record the default marker to restore, and
 * create the definition tagged with a first probe tag. Answers `{prior, preparedId}`; the caller
 * passes `prior` back to `disarmProbeDefinition` at teardown.
 */
export function armProbeDefinition(options) {
  removeDefinition(options, '');
  const prior = markedDefault(options);
  const preparedId = ensureDefinition(options, nextTag(options));
  return { prior, preparedId };
}

/** The teardown half of `armProbeDefinition`: remove the probe definition and restore `prior`. */
export function disarmProbeDefinition(options, prior) {
  removeDefinition(options, prior);
}

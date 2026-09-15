import assert from 'node:assert/strict';

/**
 * Reading `iris session` transcripts captured by `OCU-<name>-START:...:OCU-<name>-END` markers --
 * `tasks.browser-spec.mjs`'s `mark()` writes them, and its `irisSession()` shells out to
 * `docker exec` and hands the combined stdout/stderr here.
 *
 * Split out into its own module (no `docker`, no `page`) so both the parsing and the decision the
 * caller takes on it can be pinned without a live instance: a `SuspendSet` the instance refuses,
 * and a poll that exhausts its budget without ever reading the state it asked for, are the two
 * paths no AC2 run has exercised (Story 2.8 follow-up).
 *
 * A marker missing from the transcript parses as `null`, never a silent default -- the caller's
 * own assertion is what must catch a missing or unexpected value, not this function absorbing it.
 */
export function parseMarkers(output, names) {
  const values = {};
  for (const name of names) {
    const match = new RegExp(`OCU-${name}-START:(.*?):OCU-${name}-END`).exec(output);
    values[name] = match === null ? null : match[1];
  }
  return values;
}

/**
 * The Task Manager state a `SuspendSet` run left behind, read from its parsed markers.
 *
 * It throws when `OK` is not `"1"`, so a refusal names the call that was refused rather than
 * surfacing ten seconds later as a banner assertion with no cause in its message. Otherwise it
 * answers `STATE` -- whatever the bounded poll last read, never what the caller asked for -- so a
 * poll that never converged fails on the caller's own comparison against the state it wanted.
 */
export function taskManagerStateFrom(values, suspended, output = '') {
  assert.equal(values.OK, '1', `SuspendSet(${suspended ? 1 : 0}) succeeded:\n${output}`);
  return values.STATE;
}

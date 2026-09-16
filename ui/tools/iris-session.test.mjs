import { test } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

/**
 * Story 2.8 QA follow-up. `tasks.browser-spec.mjs`'s `setTaskManagerSuspended` sends `SuspendSet`
 * and a bounded ten-second poll for `TASKMGRStatus()` to the throwaway in one `iris session` call,
 * then reads the transcript back through `parseMarkers` and decides on it through
 * `taskManagerStateFrom` (`ui/browser/iris-session.mjs`). Every AC2 run so far has `SuspendSet`
 * succeed and the poll converge before its budget runs out, so two paths were unexercised by any
 * test: `SuspendSet` genuinely refused, and a poll that exhausts its budget without the state ever
 * matching what was asked for. Both are driven here through the production functions, against
 * transcripts shaped exactly as a real `iris session` run would leave them.
 *
 * Mutations (Rule 19): change `parseMarkers`'s missing-marker default from `null` to `''` -> the
 * "a marker the transcript never wrote" test goes red. Drop `taskManagerStateFrom`'s
 * `assert.equal(values.OK, '1', ...)` -> the refusal test goes red. Answer the wanted state rather
 * than `values.STATE` -> the unconverged-poll test goes red.
 */

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { parseMarkers, taskManagerStateFrom } = await import(join(uiRoot, 'browser', 'iris-session.mjs'));

/** `%SYS.Task.TASKMGRStatus()`, as `tasks.browser-spec.mjs` names them. */
const RUNNING = '1';
const SUSPENDED = '2';

/** A transcript with both markers written, as a converged run leaves behind. */
const transcript = (ok, state) => `USER>OCU-OK-START:${ok}:OCU-OK-END\nUSER>OCU-STATE-START:${state}:OCU-STATE-END\n`;

test('parseMarkers reads a converged run: SuspendSet succeeded and the poll reached the wanted state', () => {
  const values = parseMarkers(transcript('1', '2'), ['OK', 'STATE']);
  assert.deepEqual(values, { OK: '1', STATE: '2' });
  assert.equal(taskManagerStateFrom(values, true), SUSPENDED, 'so the caller is answered the state it asked for');
});

test('a marker the transcript never wrote parses as null, never a silent default', () => {
  const values = parseMarkers('USER>OCU-OK-START:1:OCU-OK-END\n', ['OK', 'STATE']);
  assert.equal(values.OK, '1');
  assert.equal(values.STATE, null, 'STATE was never written, so it is null rather than an empty string');
  assert.equal(taskManagerStateFrom(values, true), null, 'and null is what the caller compares, never a state it might accept');
});

test('a genuinely refused SuspendSet throws in the helper, naming the call rather than the banner', () => {
  // SuspendSet's `tSC` and the poll's `TASKMGRStatus()` are separate top-level statements sent in
  // the same session, so the poll still runs its full budget even when SuspendSet itself failed --
  // the throwaway's own state is simply left wherever it already was, here still "1" (running).
  const values = parseMarkers(transcript('0', '1'), ['OK', 'STATE']);
  assert.throws(
    () => taskManagerStateFrom(values, true, 'the transcript'),
    /SuspendSet\(1\) succeeded/,
    'the refusal names itself here, not ten seconds later as a banner assertion with no cause'
  );
});

test('a poll that exhausts its budget answers the state it last read, which is not the one the caller asked for', () => {
  // SuspendSet succeeded (OK is "1"), but the twenty 0.5s tries never saw TASKMGRStatus() answer
  // "2" (suspended), so the loop falls through and the STATE mark reads whatever it last was: "1".
  const values = parseMarkers(transcript('1', RUNNING), ['OK', 'STATE']);
  const answered = taskManagerStateFrom(values, true, '');
  assert.equal(answered, RUNNING, 'the helper answers what the instance said, never what it was asked for');
  assert.notEqual(answered, SUSPENDED, "so AC2's own assert.equal(setTaskManagerSuspended(true), SUSPENDED, ...) is what catches it");
});

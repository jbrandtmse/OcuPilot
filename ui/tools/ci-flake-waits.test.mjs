// Pins the browser specs' shared turn and slot waits, with no browser and no instance: `waitForSlotFree` and `scriptStreamReply` (browser/turnprobe-spec.mjs) against a fake
// `docker` first on PATH, `waitForReplies` (browser/panel-spec.mjs) against a fake page and document,
// and two source-order checks for the pieces only a running instance would otherwise exercise.
//
// Mutations (Rule 19):
// - make `waitForSlotFree` answer its first read without polling -> the polling case goes red.
// - drop its deadline test -> the bounded case goes red (the test times out).
// - make it answer '' -> the bounded case goes red.
// - rename `scriptStreamReply`'s marker -> both stream cases go red; drop its assert -> the error case
//   goes red.
// - drop the Send-label clause from `waitForReplies` -> the Stop case goes red.
// - send `maxRows` 20 on JournalRecords' second page, or drop the line -> the cap case goes red.
// - call `requireFreeSlot` before context-chip's second Send, or drop the `waitForSlotFree` call -> the
//   order case goes red.

import assert from 'node:assert/strict';
import { chmodSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

const { scriptStreamReply, waitForSlotFree } = await import(new URL('../browser/turnprobe-spec.mjs', import.meta.url).href);
const { waitForReplies } = await import(new URL('../browser/panel-spec.mjs', import.meta.url).href);

const config = { container: 'fake-container', username: 'alice', navigationTimeoutMs: 1234 };

/**
 * Put a fake `docker` first on PATH for test `t`. It saves the script it is fed on stdin to `last.txt`,
 * counts its calls in `count`, and prints line N of `replies` for call N (the last line repeats).
 * `restore` is also registered as `t`'s after hook, so it runs when the test times out.
 */
function fakeDocker(t, lines) {
  const dir = mkdtempSync(join(tmpdir(), 'ocu-fake-docker-'));
  writeFileSync(join(dir, 'replies'), `${lines.join('\n')}\n`);
  writeFileSync(
    join(dir, 'docker'),
    [
      '#!/bin/sh',
      `dir='${dir}'`,
      'cat > "$dir/last.txt"',
      'n=$(cat "$dir/count" 2>/dev/null || echo 0)',
      'n=$((n+1))',
      'echo $n > "$dir/count"',
      'line=$(sed -n "${n}p" "$dir/replies")',
      '[ "$n" -gt "$(wc -l < "$dir/replies")" ] && line=$(tail -n 1 "$dir/replies")',
      'printf "%s\\n" "$line"',
      '',
    ].join('\n')
  );
  chmodSync(join(dir, 'docker'), 0o755);
  const path = process.env.PATH;
  process.env.PATH = `${dir}:${path}`;
  const restore = () => {
    process.env.PATH = path;
    rmSync(dir, { recursive: true, force: true });
  };
  t.after(restore);
  return {
    calls: () => Number(readFileSync(join(dir, 'count'), 'utf8')),
    lastScript: () => readFileSync(join(dir, 'last.txt'), 'utf8'),
    restore,
  };
}

const slot = (owner) => `OCU-SLOT-START:${owner}:OCU-SLOT-END`;

test('waitForSlotFree answers at once when no process holds the slot', async (t) => {
  const docker = fakeDocker(t, [slot('')]);
  try {
    assert.equal(await waitForSlotFree(config, 5000), '');
    assert.equal(docker.calls(), 1, 'one read');
    assert.match(docker.lastScript(), /SlotOwner\("alice"\)/, 'it asks for this user\'s slot');
  } finally {
    docker.restore();
  }
});

test('waitForSlotFree keeps polling while a process holds the slot and answers "" once it is freed', { timeout: 20_000 }, async (t) => {
  const docker = fakeDocker(t, [slot('4711'), slot('4711'), slot('')]);
  try {
    assert.equal(await waitForSlotFree(config, 10_000), '', 'freed');
    assert.equal(docker.calls(), 3, 'read until the holder was gone');
  } finally {
    docker.restore();
  }
});

test('waitForSlotFree gives up at its deadline and answers the holder it last saw', { timeout: 10_000 }, async (t) => {
  const docker = fakeDocker(t, [slot('77')]);
  try {
    assert.equal(await waitForSlotFree(config, 1500), '77', 'the holder, not an empty answer');
    assert.ok(docker.calls() >= 2 && docker.calls() <= 5, `polled a few times, not forever: ${docker.calls()}`);
  } finally {
    docker.restore();
  }
});

test('scriptStreamReply scripts one streamed reply through ScriptStream and asserts its status', (t) => {
  const docker = fakeDocker(t, ['OCU-CHIP-STREAM-START:1:OCU-CHIP-STREAM-END']);
  try {
    scriptStreamReply({ container: 'fake-container', marker: 'CHIP' }, 'tag"x', 0, '##class(A.B).TextReply("first")', 3);
    assert.ok(
      docker.lastScript().includes('Set sc=##class(OcuPilot.Test.TurnProvider).ScriptStream("tag""x",0,##class(A.B).TextReply("first"),3)'),
      `tag escaped, hang, body and mid-hang in ScriptStream's order: ${docker.lastScript()}`
    );
  } finally {
    docker.restore();
  }
});

test('scriptStreamReply fails when ScriptStream answers an error or nothing at all', (t) => {
  for (const reply of ['OCU-CHIP-STREAM-START:0:OCU-CHIP-STREAM-END', 'no marker here']) {
    const docker = fakeDocker(t, [reply]);
    try {
      assert.throws(
        () => scriptStreamReply({ container: 'fake-container', marker: 'CHIP' }, 'tag', 0, '"x"', 3),
        /ScriptStream succeeded/,
        reply
      );
    } finally {
      docker.restore();
    }
  }
});

/** Run `waitForReplies` against a document with `replies` finished replies and `send` on its Send button. */
async function waitWith({ replies, send }) {
  let seen;
  let satisfied;
  const page = {
    waitForFunction: async (predicate, options, ...args) => {
      seen = options;
      satisfied = predicate(...args);
    },
  };
  globalThis.document = {
    querySelectorAll: (selector) => (selector === 'app-reply' ? new Array(replies).fill({}) : []),
    querySelector: (selector) => (selector === '.ocu-panel-send' ? { textContent: ` ${send} ` } : null),
  };
  try {
    await waitForReplies(page, 2, config, 'Send');
    return { result: satisfied, seen };
  } finally {
    delete globalThis.document;
  }
}

test('waitForReplies is satisfied by the reply count with Send reading Send', async () => {
  const { result, seen } = await waitWith({ replies: 2, send: 'Send' });
  assert.equal(result, true);
  assert.equal(seen.timeout, 1234, 'bounded by the config\'s navigation timeout');
});

test('waitForReplies is not satisfied while Send reads Stop, or while a reply is missing', async () => {
  assert.equal((await waitWith({ replies: 2, send: 'Stop' })).result, false, 'both replies drawn, turn still running');
  assert.equal((await waitWith({ replies: 1, send: 'Send' })).result, false, 'turn ended, second reply not drawn');
});

test('the journal tool test\'s second page asks for the context cap, not the first page\'s twenty rows', () => {
  const source = readFileSync(new URL('../../src/OcuPilot/Test/JournalRecords.cls', import.meta.url), 'utf8');
  const start = source.indexOf('Method TestTheToolInReverseOrderKeepsTheNewestRowsUnderTheContextCap()');
  assert.ok(start !== -1, 'the test method exists');
  const body = source.slice(start, source.indexOf('\n}\n', start));
  const views = [...body.matchAll(/Read\)\.View\(\.\.#SCREEN, tArgs, (\d+),/g)];
  assert.equal(views.length, 2, 'two View calls: the first page and the next');
  const between = body.slice(views[0].index + views[0][0].length, views[1].index);
  const cap = Number(views[1][1]);
  const sent = [...between.matchAll(/tArgs\.%Set\("maxRows", (\d+), "number"\)/g)].map((match) => Number(match[1]));
  assert.deepEqual(sent, [cap], `the second page sends maxRows ${cap}, the cap, before its View call`);
  assert.equal(Number(/"maxRows": (\d+)\}/.exec(body)?.[1]), 20, 'the first page still reads twenty, so the cap is what truncates it');
});

test('context-chip\'s second Send waits for the turn slot and never abandons turns', () => {
  const source = readFileSync(new URL('../browser/context-chip.browser-spec.mjs', import.meta.url), 'utf8');
  const start = source.indexOf("test('Fresh at Send:");
  assert.ok(start !== -1, 'the test exists');
  const body = source.slice(start, source.indexOf('\ntest(', start + 1));
  const firstWait = body.indexOf('await waitForReplies(page, 1, config, STRINGS.actionSend)');
  const slotWait = body.indexOf('await waitForSlotFree(config)');
  const secondSend = body.indexOf("typeAndSend(page, 'second turn");
  const secondReply = body.indexOf("'the second turn to draw \"second\"");
  assert.ok(firstWait !== -1 && slotWait !== -1 && secondSend !== -1 && secondReply !== -1, 'all four steps are present');
  assert.ok(firstWait < slotWait && slotWait < secondSend && secondSend < secondReply, 'wait for turn 1, free slot, second Send, second reply');
  assert.ok(!body.includes('requireFreeSlot'), 'it never abandons a running turn');
  assert.match(body, /scriptStream\(tag, textReply\('first'\), [1-9]\d*\)/, 'turn 1 is streamed with a mid-turn pause, so its text is drawn while it runs');
});

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins `core/message-export.ts` (Story 24.16 Batch 3): the bytes an export answers base64-encoded, the status and failure lines a card shows beside them, and the
// name a browser saves them as.
//
// Mutations (Rule 19):
// - decode the file as text instead of bytes -> "bytes above 127 survive the round trip" goes red.
// - count a failure line as exported -> "the counts read the lines" goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);

const { decodeBase64, exportCardLines, exportedCount, exportFailuresOf, exportFileName, exportFileOf, exportSavedLine } = await import(corePath('message-export.ts'));
const { STRINGS } = await import(corePath('strings.ts'));

test('a namespace names the file, each character a file name cannot hold made an underscore', () => {
  assert.equal(exportFileName('USER'), 'USER-messages.txt');
  assert.equal(exportFileName('A/B:C'), 'A_B_C-messages.txt');
  assert.equal(exportFileName(''), 'messages.txt');
});

test('bytes above 127 survive the base64 round trip, and text that is not base64 reads as no file', () => {
  const bytes = Uint8Array.from([0x4d, 0xc3, 0xa9, 0x0d, 0x0a, 0xff, 0x00]);
  const encoded = Buffer.from(bytes).toString('base64');
  assert.deepEqual([...decodeBase64(encoded)], [...bytes]);
  assert.deepEqual([...exportFileOf({ file: encoded, lines: [] })], [...bytes]);
  assert.equal(decodeBase64('not base64 ***'), null);
  assert.equal(exportFileOf({ lines: ['12: exported'] }), null, 'an answer with no file carries none');
  assert.equal(exportFileOf({ file: '' }), null, 'and an empty one carries none');
  assert.equal(exportFileOf(null), null);
});

test('the status line counts the messages saved, in the singular for one', () => {
  assert.equal(exportSavedLine(1, 'USER-messages.txt'), 'Saved 1 message as USER-messages.txt.');
  assert.equal(exportSavedLine(2, 'USER-messages.txt'), 'Saved 2 messages as USER-messages.txt.');
  assert.equal(exportSavedLine(0, 'f.txt'), 'Saved 0 messages as f.txt.');
});

test('the counts read the lines, and the card shows the status line and then each failure', () => {
  const failure = `13: ${STRINGS.interopExportOutcomeNotExported}: the vendor said no`;
  const output = { lines: [`12: ${STRINGS.interopExportOutcomeExported}`, failure, `14: ${STRINGS.interopExportOutcomeExported}`], file: 'YWJj' };
  assert.equal(exportedCount(output), 2);
  assert.deepEqual(exportFailuresOf(output), [failure]);
  assert.deepEqual(exportCardLines(output, 'USER-messages.txt'), ['Saved 2 messages as USER-messages.txt.', failure]);
  assert.equal(exportCardLines({ lines: [failure] }, 'USER-messages.txt'), null, 'an answer with no file is left to the generic lines');
});

/**
 * The Messages export's file as the client reads it from an answer (Story 24.16 Batch 3, AD-39's fifth exception): the bytes the instance sent
 * base64-encoded in the answer's `output.file`, the outcome line of each message beside it, the name the browser saves it as, and the status line
 * that says what was saved. The one reader for both callers: the person's dialog and the confirming browser's proposal card.
 *
 * Framework-free, like the rest of `core/`, so `node --test` executes it.
 */

import { pickCount } from './count-phrase.ts';
import { STRINGS } from './strings.ts';

/** The media type the saved file carries; its character set is the one the person chose, so no `charset` parameter is claimed. */
export const EXPORT_FILE_TYPE = 'text/plain';

/** The count placeholder and the file placeholder of the status line sentences. */
const COUNT_PLACEHOLDER = '<n>';
const FILE_PLACEHOLDER = '<file>';

/** The file an export to this browser is saved as: `<namespace>-messages.txt`, each character a file name cannot hold made `_`. */
export function exportFileName(namespace: string): string {
  const safe = Array.from(namespace, (character) => (character.charCodeAt(0) < 32 || '\\/:*?"<>|'.includes(character) ? '_' : character)).join('');
  return `${safe === '' ? 'messages' : `${safe}-messages`}.txt`;
}

/** The bytes of the standard base64 `text`, or `null` when it is not valid base64. */
export function decodeBase64(text: string): Uint8Array<ArrayBuffer> | null {
  try {
    const binary = atob(text);
    const bytes = new Uint8Array(new ArrayBuffer(binary.length));
    for (let at = 0; at < binary.length; at += 1) bytes[at] = binary.charCodeAt(at);
    return bytes;
  } catch {
    return null;
  }
}

/** The outcome lines `output` carries, or `[]`. */
function outcomeLines(output: unknown): readonly string[] {
  if (output === null || typeof output !== 'object') return [];
  const lines = (output as Record<string, unknown>)['lines'];
  return Array.isArray(lines) ? lines.filter((line): line is string => typeof line === 'string') : [];
}

/** The file an export answered in its `output`, as bytes, or `null` when it carried none or a malformed one. */
export function exportFileOf(output: unknown): Uint8Array<ArrayBuffer> | null {
  if (output === null || typeof output !== 'object') return null;
  const file = (output as Record<string, unknown>)['file'];
  return typeof file === 'string' && file !== '' ? decodeBase64(file) : null;
}

/** Whether `line` is the outcome line of a message that was not exported: `<id>: not exported: <text>`. */
function isFailure(line: string): boolean {
  return line.includes(`: ${STRINGS.interopExportOutcomeNotExported}`);
}

/** How many messages the lines say were exported. */
export function exportedCount(output: unknown): number {
  return outcomeLines(output).filter((line) => line.endsWith(`: ${STRINGS.interopExportOutcomeExported}`)).length;
}

/** The failure lines of an export's `output`: the messages not exported, each with the instance's text. */
export function exportFailuresOf(output: unknown): readonly string[] {
  return outcomeLines(output).filter(isFailure);
}

/** The status line for `count` messages saved as `file`: "Saved 1 message as <file>." at one, "Saved <n> messages as <file>." otherwise. */
export function exportSavedLine(count: number, file: string): string {
  const template = pickCount(count, STRINGS.interopMessageExportSavedOne, STRINGS.interopMessageExportSaved);
  return template.split(COUNT_PLACEHOLDER).join(String(count)).split(FILE_PLACEHOLDER).join(file);
}

/**
 * What the proposal card shows of a confirmed export that carried a file: the status line, then the failure lines. `null` for an answer that
 * carried no file, so the card shows the lines the instance answered as they are (an export whose every message failed has only failures).
 */
export function exportCardLines(output: unknown, file: string): readonly string[] | null {
  if (exportFileOf(output) === null) return null;
  return [exportSavedLine(exportedCount(output), file), ...exportFailuresOf(output)];
}

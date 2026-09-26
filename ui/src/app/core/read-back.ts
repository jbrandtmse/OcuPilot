/**
 * The read-back line of a confirmed write (AD-58, Story 16.17).
 *
 * **The client compares nothing.** The instance re-reads the target after the write and answers
 * `readBack {verdict, fields, written, reason?}` beside the write's own answer; this module reads
 * that shape off the wire and renders it as EXPERIENCE.md's Fixed strings row says. A value outside
 * the vocabulary reads as no read-back at all (`null`), never as a verdict the instance did not
 * give.
 */

import { STRINGS } from './strings.ts';

export type ReadBackVerdict = 'matches' | 'differs' | 'notFound' | 'present' | 'written' | 'nothingSent' | 'unchecked';

/** The verdicts, so a wire value is checked against one list. */
export const READ_BACK_VERDICTS: readonly ReadBackVerdict[] = [
  'matches',
  'differs',
  'notFound',
  'present',
  'written',
  'nothingSent',
  'unchecked',
];

/** Why a read-back is `unchecked`: the write is still running, or the re-read failed. */
export type ReadBackReason = '' | 'running' | 'unreadable';

/** One read-back, names only: no value the write sent or the instance holds is ever here. */
export interface ReadBack {
  readonly verdict: ReadBackVerdict;
  /** The field names that read back differently. */
  readonly fields: readonly string[];
  /** The secret names the write sent, which are never read back. */
  readonly written: readonly string[];
  readonly reason: ReadBackReason;
}

/** How many names a line lists before it says " and <n> more". */
export const READ_BACK_NAMES_SHOWN = 3;

/** The separator a clause or a line is appended with. */
export const READ_BACK_SEPARATOR = ' \u00b7 ';

function namesOf(value: unknown): string[] | null {
  if (value === undefined || value === null) return [];
  if (!Array.isArray(value)) return null;
  if (!value.every((name): name is string => typeof name === 'string' && name !== '')) return null;
  return [...value];
}

/**
 * `value` as a read-back, or `null` for anything outside the vocabulary: a verdict the instance
 * does not answer, a name list that is not a list of names, or a reason other than the two.
 */
export function readBackOf(value: unknown): ReadBack | null {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) return null;
  const record = value as Record<string, unknown>;
  const verdict = record['verdict'];
  if (typeof verdict !== 'string' || !(READ_BACK_VERDICTS as readonly string[]).includes(verdict)) return null;
  const fields = namesOf(record['fields']);
  const written = namesOf(record['written']);
  if (fields === null || written === null) return null;
  const reasonValue = record['reason'];
  let reason: ReadBackReason = '';
  if (reasonValue !== undefined && reasonValue !== null && reasonValue !== '') {
    if (reasonValue !== 'running' && reasonValue !== 'unreadable') return null;
    reason = reasonValue;
  }
  if (verdict === 'unchecked' && reason === '') return null;
  return { verdict: verdict as ReadBackVerdict, fields, written, reason };
}

/** Up to three names joined by ", ", then " and <n> more". */
export function readBackNames(names: readonly string[]): string {
  const shown = names.slice(0, READ_BACK_NAMES_SHOWN).join(', ');
  const rest = names.length - READ_BACK_NAMES_SHOWN;
  return rest > 0 ? `${shown}${STRINGS.readBackMore.replace('<n>', String(rest))}` : shown;
}

/** The line one read-back renders as, or `''` for none. */
export function readBackLine(readBack: ReadBack | null): string {
  if (readBack === null) return '';
  const withWritten = (line: string): string =>
    readBack.written.length === 0
      ? line
      : `${line}${READ_BACK_SEPARATOR}${STRINGS.readBackWrittenClause.replace('<fields>', readBackNames(readBack.written))}`;
  switch (readBack.verdict) {
    case 'matches':
      return withWritten(STRINGS.readBackMatches);
    case 'differs':
      return withWritten(STRINGS.readBackDiffers.replace('<fields>', readBackNames(readBack.fields)));
    case 'notFound':
      return STRINGS.readBackNotFound;
    case 'present':
      return STRINGS.readBackPresent;
    case 'written':
      return STRINGS.readBackWritten.replace('<fields>', readBackNames(readBack.written));
    case 'nothingSent':
      return STRINGS.readBackNothingSent;
    case 'unchecked':
      return readBack.reason === 'running' ? STRINGS.readBackRunning : STRINGS.readBackUnreadable;
    default:
      return '';
  }
}

/** A form's "Saved" status with its read-back line -- "Saved", the separator, the line -- or "Saved" alone. */
export function savedLine(readBack: ReadBack | null): string {
  const line = readBackLine(readBack);
  return line === '' ? STRINGS.formSaved : `${STRINGS.formSaved}${READ_BACK_SEPARATOR}${line}`;
}

/** A row's polite announcement with its read-back line appended, or unchanged when there is none. */
export function withReadBack(announcement: string, readBack: ReadBack | null): string {
  const line = readBackLine(readBack);
  return line === '' ? announcement : `${announcement}${READ_BACK_SEPARATOR}${line}`;
}

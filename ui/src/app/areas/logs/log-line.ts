import { STRINGS } from '../../core/strings';

/**
 * One grammar serves both instance log files. `alerts.log` and `messages.log` are written by the
 * same `$zu(9)` path, so a head line reads
 * `MM/DD/YY-HH:MM:SS:mmm (pid) severity [Category] text` in both, and a line that does not match it
 * is a continuation of the entry above rather than an entry of its own.
 *
 * `OcuPilot.Port.LogSourcePort`'s `HEADFORM` carries the same grammar on the server, where a
 * declared read projects the same window into rows; both are pinned against the same shapes.
 */
const HEAD_RE =
  /^(\d{2})\/(\d{2})\/(\d{2})-(\d{2}):(\d{2}):(\d{2}):(\d{3}) \((\d+)\) (-?\d+) (?:\[([^\]]*)\] )?([\s\S]*)$/;

/** One rendered log entry. */
export interface LogLine {
  /**
   * The stamp as `YYYY-MM-DDTHH:MM:SS.mmm` in the instance's own local time, with no zone suffix,
   * or `''` for a line that carries none. The file writes local time, and nothing here converts it,
   * so no `Z` is appended to a value that is not UTC.
   */
  readonly stamp: string;
  /** The process that wrote the entry, or `''` for a line carrying no head. */
  readonly pid: string;
  /** The vendor's own severity number as text, or `''` for a line that carries none. */
  readonly severity: string;
  /** The bracketed category, or `''`. */
  readonly category: string;
  /** The entry's text, continuation lines included. */
  readonly text: string;
  /** The entry as it was read, which is what the Raw view shows. */
  readonly raw: string;
  /** Whether the entry opened with a head line. A window can open mid-continuation. */
  readonly head: boolean;
}

/** The vendor's severity scale (`irissys/%sySystem.inc`), which has five words, not four. */
const SEVERITY_WORDS: Readonly<Record<string, string>> = {
  '-2': STRINGS.logSeverityDebug,
  '-1': STRINGS.logSeverityDebug,
  '0': STRINGS.logSeverityInfo,
  '1': STRINGS.logSeverityWarning,
  '2': STRINGS.logSeveritySevere,
  '3': STRINGS.logSeverityFatal,
};

/** The five chips, in the scale's own order. Two debug levels share one chip. */
export const SEVERITY_CHIPS: readonly { readonly key: string; readonly word: string; readonly levels: readonly string[] }[] = [
  { key: 'debug', word: STRINGS.logSeverityDebug, levels: ['-2', '-1'] },
  { key: 'info', word: STRINGS.logSeverityInfo, levels: ['0'] },
  { key: 'warning', word: STRINGS.logSeverityWarning, levels: ['1'] },
  { key: 'severe', word: STRINGS.logSeveritySevere, levels: ['2'] },
  { key: 'fatal', word: STRINGS.logSeverityFatal, levels: ['3'] },
];

/**
 * The word a severity renders with. A level the vendor's scale does not name reads as the number
 * itself, so it is never dropped and never rendered as colour alone; an entry carrying no severity
 * at all -- a window that opens mid-continuation -- reads as the table's own empty-cell word rather
 * than as an empty chip.
 */
export function severityWord(severity: string): string {
  if (severity === '') return STRINGS.tableEmptyValue;
  return SEVERITY_WORDS[severity] ?? severity;
}

/** The chip key a severity belongs to, or `''` for a level outside the scale. */
export function severityChipKey(severity: string): string {
  const chip = SEVERITY_CHIPS.find((entry) => entry.levels.includes(severity));
  return chip === undefined ? '' : chip.key;
}

/**
 * A two-digit file year as four digits. The file writes `YY`; IRIS's own pivot puts 70 and above in
 * the twentieth century, and this follows it rather than inventing one.
 */
function fullYear(yy: string): string {
  const value = Number(yy);
  return String(value < 70 ? 2000 + value : 1900 + value);
}

/** The file's `MM/DD/YY-HH:MM:SS:mmm` as the comparable stamp above. */
function fileStamp(match: RegExpMatchArray): string {
  return (
    fullYear(match[3]) + '-' + match[1] + '-' + match[2] + 'T' + match[4] + ':' + match[5] + ':' + match[6] + '.' + match[7]
  );
}

/**
 * The lines of one tail window as entries, oldest first.
 *
 * A line matching the head grammar opens an entry; any other line is appended to the entry above it,
 * and a window that opens mid-continuation yields a leading entry with `head` false and no stamp --
 * which is what stops such a window from being given a cursor it cannot support.
 */
export function parseFileLines(lines: readonly string[]): readonly LogLine[] {
  const entries: LogLine[] = [];
  for (const line of lines) {
    const match = HEAD_RE.exec(line);
    if (match === null) {
      const previous = entries[entries.length - 1];
      if (previous === undefined) {
        entries.push({
          stamp: '',
          pid: '',
          severity: '',
          category: '',
          text: line,
          raw: line,
          head: false,
        });
        continue;
      }
      entries[entries.length - 1] = {
        ...previous,
        text: previous.text + '\n' + line,
        raw: previous.raw + '\n' + line,
      };
      continue;
    }
    entries.push({
      stamp: fileStamp(match),
      pid: match[8],
      severity: match[9],
      category: match[10] ?? '',
      text: match[11],
      raw: line,
      head: true,
    });
  }
  return entries;
}

/** Whether `entry` carries `needle`, matched without case. Used by the sticky search. */
export function matchesSearch(entry: LogLine, needle: string): boolean {
  if (needle === '') return false;
  const lowered = needle.toLowerCase();
  return (
    entry.text.toLowerCase().includes(lowered) ||
    entry.stamp.toLowerCase().includes(lowered) ||
    entry.pid.includes(lowered) ||
    entry.category.toLowerCase().includes(lowered)
  );
}

/** One row's text split into the spans a search highlights: the odd spans are the matches. */
export function highlightSpans(text: string, needle: string): readonly { readonly text: string; readonly match: boolean }[] {
  if (needle === '') return [{ text, match: false }];
  const spans: { text: string; match: boolean }[] = [];
  const lowered = text.toLowerCase();
  const target = needle.toLowerCase();
  let at = 0;
  for (;;) {
    const found = lowered.indexOf(target, at);
    if (found < 0) break;
    if (found > at) spans.push({ text: text.slice(at, found), match: false });
    spans.push({ text: text.slice(found, found + needle.length), match: true });
    at = found + needle.length;
  }
  if (at < text.length) spans.push({ text: text.slice(at), match: false });
  return spans.length === 0 ? [{ text, match: false }] : spans;
}

/** The polite count the search announces, with both slots resolved. */
export function matchCountText(position: number, total: number): string {
  return STRINGS.logViewerMatchCount.replace('<n>', String(position)).replace('<N>', String(total));
}

import { STRINGS } from '../../core/strings';

/**
 * One grammar serves both instance log files. `alerts.log` and `messages.log` are written by the
 * same `$zu(9)` path, so a head line reads
 * `MM/DD/YY-HH:MM:SS:mmm (pid) severity [Category] text` in both, and a line that does not match it
 * is a continuation of the entry above rather than an entry of its own.
 */
const HEAD_RE =
  /^(\d{2})\/(\d{2})\/(\d{2})-(\d{2}):(\d{2}):(\d{2}):(\d{3}) \((\d+)\) (-?\d+) (?:\[([^\]]*)\] )?([\s\S]*)$/;

/** Where a rendered row came from, which is what decides a collision (the file always wins). */
export type LogLineSource = 'file' | 'monitor';

/** One rendered log entry. */
export interface LogLine {
  /**
   * The stamp as `YYYY-MM-DDTHH:MM:SS.mmm` in the instance's own local time, with no zone suffix,
   * or `''` for a line that carries none.
   *
   * **No `Z`.** The file writes local time and the monitoring API appends a `Z` to the same local
   * value without converting it, so the suffix is false on one side and absent on the other.
   * Dropping it is what lets the two be compared at all.
   */
  readonly stamp: string;
  /** The process that wrote the entry, or `''` -- the monitoring API does not report it. */
  readonly pid: string;
  /** The vendor's own severity number as text, or `''` for a line that carries none. */
  readonly severity: string;
  /** The bracketed category, or `''` -- the monitoring API drops it. */
  readonly category: string;
  /** The entry's text, continuation lines included. */
  readonly text: string;
  /** The entry as it was read, which is what the Raw view shows. */
  readonly raw: string;
  readonly source: LogLineSource;
  /** Whether the entry opened with a head line. A window can open mid-continuation. */
  readonly head: boolean;
  /**
   * The cursor the monitoring API matches this entry by -- `MM/DD/YY-HH:MM:SS:mmm (pid)`, the head
   * line's own prefix, byte for byte. `''` for an entry with no head line and for every monitor
   * entry, neither of which the vendor can match.
   */
  readonly tag: string;
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
 * at all -- a window that opens mid-continuation, or a monitoring row missing the key -- reads as
 * the table's own empty-cell word rather than as an empty chip.
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
 * The monitoring API's `YYYY-MM-DDTHH:MM:SS.mmmZ` as the comparable stamp above.
 *
 * The `Z` is dropped rather than converted: the value behind it is the file's own local time, which
 * nothing shifted on the way out.
 */
export function normalizeApiStamp(time: string): string {
  return time.endsWith('Z') ? time.slice(0, -1) : time;
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
          source: 'file',
          head: false,
          tag: '',
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
      source: 'file',
      head: true,
      tag:
        match[1] + '/' + match[2] + '/' + match[3] + '-' + match[4] + ':' + match[5] + ':' + match[6] + ':' + match[7] +
        ' (' + match[8] + ')',
    });
  }
  return entries;
}

/** One monitoring-API row as an entry. It carries no pid, no category and no cursor of its own. */
export function parseMonitorRow(row: unknown): LogLine {
  const record = row === null || typeof row !== 'object' ? {} : (row as Record<string, unknown>);
  const time = typeof record['time'] === 'string' ? record['time'] : '';
  const severity = typeof record['severity'] === 'string' ? record['severity'] : '';
  const text = typeof record['text'] === 'string' ? record['text'] : '';
  return {
    stamp: normalizeApiStamp(time),
    pid: '',
    severity,
    category: '',
    text,
    raw: text,
    source: 'monitor',
    head: true,
    tag: '',
  };
}

/**
 * The cursor to ask the monitoring API for entries after: the **earliest** head line of the tail
 * window, so the two windows coincide and no entry can fall between them. `''` for a window with no
 * head line at all, which makes no monitoring call.
 */
export function tagForWindow(entries: readonly LogLine[]): string {
  const first = entries.find((entry) => entry.tag !== '');
  return first === undefined ? '' : first.tag;
}

/**
 * The cursor a **subsequent** page asks the monitoring API from: the **newest** head line the viewer
 * holds. Everything older than it is already rendered from the file, which is the half that wins
 * every collision, so re-asking from the first window's start would re-fetch the whole session and
 * grow the answer until the port's size bound refuses it. `''` when no entry carries a cursor.
 */
export function tagForNewest(entries: readonly LogLine[]): string {
  for (let at = entries.length - 1; at >= 0; at -= 1) {
    const entry = entries[at];
    if (entry !== undefined && entry.tag !== '') return entry.tag;
  }
  return '';
}

/**
 * The de-duplication key: the stamp, the severity and the entry's **first** line -- never the pid,
 * which one side lacks, and never the continuation lines, which the monitoring API drops. Matching
 * on the whole text would leave every multi-line entry present in both halves rendering twice.
 */
function mergeKey(entry: LogLine): string {
  const head = entry.text.split('\n', 1)[0] ?? '';
  return entry.stamp + '\u0000' + entry.severity + '\u0000' + head;
}

/**
 * The two halves as one list, oldest first.
 *
 * **The file wins every collision.** Its reading carries the pid and the category, and its stamp is
 * the one the instance actually wrote; the monitoring API's is the same entry with those dropped. So
 * a monitor entry whose `(stamp, severity, text)` a file entry already carries is discarded, and
 * two identical file lines from different processes are never de-duplicated against each other.
 *
 * Ordering is by stamp, with file order breaking ties -- a stable sort over file entries first, so
 * an entry the monitoring API reported between two file reads lands beside the ones it belongs with
 * rather than at the end.
 */
export function mergeLogLines(
  fileEntries: readonly LogLine[],
  monitorEntries: readonly LogLine[]
): readonly LogLine[] {
  const seen = new Set(fileEntries.map(mergeKey));
  const merged = [...fileEntries];
  for (const entry of monitorEntries) {
    const key = mergeKey(entry);
    if (seen.has(key)) continue;
    seen.add(key);
    merged.push(entry);
  }
  return merged
    .map((entry, index) => ({ entry, index }))
    .sort((left, right) => {
      if (left.entry.stamp !== right.entry.stamp) return left.entry.stamp < right.entry.stamp ? -1 : 1;
      return left.index - right.index;
    })
    .map((held) => held.entry);
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

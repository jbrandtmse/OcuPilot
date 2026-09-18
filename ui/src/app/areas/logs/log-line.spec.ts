import { describe, expect, it } from 'vitest';

import { STRINGS } from '../../core/strings';
import {
  SEVERITY_CHIPS,
  highlightSpans,
  matchCountText,
  matchesSearch,
  mergeLogLines,
  normalizeApiStamp,
  parseFileLines,
  parseMonitorRow,
  severityChipKey,
  severityWord,
  tagForWindow,
} from './log-line';

/**
 * The log grammar and the merge rule, over the file's own lines and the monitoring API's own rows
 * (Story 6.13 AC4).
 *
 * The sample lines are real alerts.log lines from the slot B instance, cut to their shape: the head
 * grammar `MM/DD/YY-HH:MM:SS:mmm (pid) severity [Category] text`, and the API's reading of the same
 * entries, which drops the pid and the category, quotes the severity and appends a `Z` to a local
 * stamp nothing converted.
 *
 * Mutations (Rule 19), each observed red here alone: make the de-duplication keep the monitor row
 * instead of the file's -> the pid-present assertion goes red; drop the pid from the merge key
 * (it is deliberately not in it) -> the two-pids leg goes red, because two identical lines from
 * different processes would collapse into one.
 */

const FILE_LINES = [
  '09/18/26-07:33:42:173 (423284) 2 [OcuPilot.Log] [OcuPilot] a severe entry',
  '09/18/26-07:33:56:057 (892) 0 [Utility.Event] an informational entry',
];

describe('parseFileLines', () => {
  it('reads the head grammar into its five parts', () => {
    const [first] = parseFileLines(FILE_LINES);
    expect(first.stamp).toBe('2026-09-18T07:33:42.173');
    expect(first.pid).toBe('423284');
    expect(first.severity).toBe('2');
    expect(first.category).toBe('OcuPilot.Log');
    expect(first.text).toBe('[OcuPilot] a severe entry');
    expect(first.head).toBe(true);
    expect(first.tag).toBe('09/18/26-07:33:42:173 (423284)');
  });

  it('reads a line with no bracketed category, which the grammar makes optional', () => {
    const [entry] = parseFileLines(['09/18/26-07:33:42:173 (1) 1 a warning with no category']);
    expect(entry.category).toBe('');
    expect(entry.text).toBe('a warning with no category');
    expect(entry.severity).toBe('1');
  });

  it('appends a continuation line to the entry above it rather than opening a new one', () => {
    const entries = parseFileLines([FILE_LINES[0], '    continued on a second line', FILE_LINES[1]]);
    expect(entries).toHaveLength(2);
    expect(entries[0].text).toBe('[OcuPilot] a severe entry\n    continued on a second line');
    expect(entries[0].raw).toContain('continued on a second line');
  });

  it('opens a window that starts mid-continuation with a head-less entry carrying no cursor', () => {
    const entries = parseFileLines(['    a fragment of the line above the window', FILE_LINES[0]]);
    expect(entries[0].head).toBe(false);
    expect(entries[0].stamp).toBe('');
    expect(entries[0].tag).toBe('');
    // AC's "no header line in the tail window": the cursor comes from the earliest HEAD line, and
    // a window with none makes no monitoring call at all.
    expect(tagForWindow([entries[0]])).toBe('');
    expect(tagForWindow(entries)).toBe(FILE_LINES[0].slice(0, 30));
  });

  it("takes the cursor from the window's earliest head line, so the two windows coincide", () => {
    expect(tagForWindow(parseFileLines(FILE_LINES))).toBe('09/18/26-07:33:42:173 (423284)');
  });
});

describe('normalizeApiStamp', () => {
  it("drops the API's false Z rather than converting it, because the value behind it is local", () => {
    expect(normalizeApiStamp('2026-09-18T07:33:42.173Z')).toBe('2026-09-18T07:33:42.173');
    expect(normalizeApiStamp('2026-09-18T07:33:42.173')).toBe('2026-09-18T07:33:42.173');
  });
});

describe('severityWord', () => {
  it('renders the five words the vendor scale names, with both debug levels on one', () => {
    expect(severityWord('-2')).toBe(STRINGS.logSeverityDebug);
    expect(severityWord('-1')).toBe(STRINGS.logSeverityDebug);
    expect(severityWord('0')).toBe(STRINGS.logSeverityInfo);
    expect(severityWord('1')).toBe(STRINGS.logSeverityWarning);
    expect(severityWord('2')).toBe(STRINGS.logSeveritySevere);
    expect(severityWord('3')).toBe(STRINGS.logSeverityFatal);
  });

  it('renders a level outside the scale as the number itself, never dropping it', () => {
    expect(severityWord('9')).toBe('9');
    expect(severityChipKey('9')).toBe('');
  });

  it('renders an entry carrying no severity as the empty-cell word, not as an empty chip', () => {
    // A window that opens mid-continuation, and a monitoring row missing the key, both reach here.
    expect(severityWord('')).toBe(STRINGS.tableEmptyValue);
    expect(severityWord(parseFileLines(['    a fragment'])[0].severity)).toBe(STRINGS.tableEmptyValue);
  });

  it('declares the five chips in the scale order', () => {
    expect(SEVERITY_CHIPS.map((chip) => chip.key)).toEqual(['debug', 'info', 'warning', 'severe', 'fatal']);
    expect(SEVERITY_CHIPS[0].levels).toEqual(['-2', '-1']);
  });
});

describe('mergeLogLines', () => {
  it('AC4: the file wins a collision, so the merged row keeps its pid and unmangled stamp', () => {
    const fileEntries = parseFileLines(FILE_LINES);
    const monitorEntries = [
      parseMonitorRow({ time: '2026-09-18T07:33:42.173Z', severity: '2', text: '[OcuPilot] a severe entry' }),
      parseMonitorRow({ time: '2026-09-18T07:34:10.000Z', severity: '1', text: 'written between the two calls' }),
    ];

    const merged = mergeLogLines(fileEntries, monitorEntries);
    expect(merged).toHaveLength(3);
    const collided = merged.filter((entry) => entry.text === '[OcuPilot] a severe entry');
    expect(collided).toHaveLength(1);
    expect(collided[0].source).toBe('file');
    expect(collided[0].pid).toBe('423284');
    expect(collided[0].category).toBe('OcuPilot.Log');
  });

  it('AC4: a monitor-only entry survives the merge, carrying no pid of its own', () => {
    const merged = mergeLogLines(parseFileLines(FILE_LINES), [
      parseMonitorRow({ time: '2026-09-18T07:34:10.000Z', severity: '1', text: 'written between the two calls' }),
    ]);
    const only = merged.find((entry) => entry.text === 'written between the two calls')!;
    expect(only.source).toBe('monitor');
    expect(only.pid).toBe('');
  });

  it('AC4: orders by normalized stamp, with file order breaking ties', () => {
    const merged = mergeLogLines(parseFileLines(FILE_LINES), [
      parseMonitorRow({ time: '2026-09-18T07:33:50.000Z', severity: '0', text: 'between the two' }),
    ]);
    expect(merged.map((entry) => entry.text)).toEqual([
      '[OcuPilot] a severe entry',
      'between the two',
      'an informational entry',
    ]);
  });

  it('AC4: two identical file lines from different processes are never de-duplicated against each other', () => {
    const merged = mergeLogLines(
      parseFileLines([
        '09/18/26-07:33:42:173 (1) 1 the same sentence',
        '09/18/26-07:33:42:173 (2) 1 the same sentence',
      ]),
      []
    );
    expect(merged).toHaveLength(2);
    expect(merged.map((entry) => entry.pid)).toEqual(['1', '2']);
  });

  it("AC4: a multi-line entry present in both halves renders once, as the file's", () => {
    // The file folds continuation lines into `text`; the monitoring API drops them. Keying the
    // de-duplication on the whole text would make every such entry render twice.
    const fileEntries = parseFileLines([
      '09/18/26-07:33:42:173 (423284) 2 [OcuPilot.Log] a severe entry',
      '    and its continuation line',
    ]);
    const merged = mergeLogLines(fileEntries, [
      parseMonitorRow({ time: '2026-09-18T07:33:42.173Z', severity: '2', text: 'a severe entry' }),
    ]);
    expect(merged).toHaveLength(1);
    expect(merged[0].source).toBe('file');
    expect(merged[0].pid).toBe('423284');
    expect(merged[0].text).toContain('and its continuation line');
  });

  it('AC4: no line the union of the two windows carries goes missing', () => {
    const fileEntries = parseFileLines(FILE_LINES);
    const monitorEntries = [
      parseMonitorRow({ time: '2026-09-18T07:33:42.173Z', severity: '2', text: '[OcuPilot] a severe entry' }),
      parseMonitorRow({ time: '2026-09-18T07:34:10.000Z', severity: '1', text: 'one' }),
      parseMonitorRow({ time: '2026-09-18T07:34:11.000Z', severity: '1', text: 'two' }),
    ];
    const merged = mergeLogLines(fileEntries, monitorEntries);
    const texts = new Set(merged.map((entry) => entry.text));
    for (const entry of [...fileEntries, ...monitorEntries]) expect(texts.has(entry.text)).toBe(true);
  });
});

describe('the sticky search helpers', () => {
  it('matches without case across the text, stamp, pid and category', () => {
    const [entry] = parseFileLines(FILE_LINES);
    expect(matchesSearch(entry, 'SEVERE')).toBe(true);
    expect(matchesSearch(entry, '423284')).toBe(true);
    expect(matchesSearch(entry, 'ocupilot.log')).toBe(true);
    expect(matchesSearch(entry, 'nothing here')).toBe(false);
    expect(matchesSearch(entry, '')).toBe(false);
  });

  it('splits a line into the spans a highlight renders', () => {
    expect(highlightSpans('one two one', 'one')).toEqual([
      { text: 'one', match: true },
      { text: ' two ', match: false },
      { text: 'one', match: true },
    ]);
    expect(highlightSpans('unmatched', '')).toEqual([{ text: 'unmatched', match: false }]);
  });

  it("resolves the polite count's two slots", () => {
    expect(matchCountText(2, 7)).toBe('2 of 7');
  });
});

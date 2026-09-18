import { describe, expect, it } from 'vitest';

import { STRINGS } from '../../core/strings';
import {
  SEVERITY_CHIPS,
  highlightSpans,
  matchCountText,
  matchesSearch,
  parseFileLines,
  severityChipKey,
  severityWord,
} from './log-line';

/**
 * The log grammar, over the file's own lines (Story 6.13 AC4).
 *
 * The sample lines are real alerts.log lines from the slot B instance, cut to their shape: the head
 * grammar `MM/DD/YY-HH:MM:SS:mmm (pid) severity [Category] text`, which both instance log files are
 * written in.
 *
 * Mutation (Rule 19), observed red here alone: make a non-matching line open its own entry instead
 * of folding into the entry above it -> the continuation assertion goes red.
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

  it('opens a window that starts mid-continuation with a head-less entry, keeping its bytes', () => {
    const entries = parseFileLines(['    a fragment of the line above the window', FILE_LINES[0]]);
    expect(entries).toHaveLength(2);
    expect(entries[0].head).toBe(false);
    expect(entries[0].stamp).toBe('');
    expect(entries[0].severity).toBe('');
    expect(entries[0].text).toBe('    a fragment of the line above the window');
  });

  it('keeps two identical lines from different processes apart, because the pid is part of neither', () => {
    const entries = parseFileLines([
      '09/18/26-07:33:42:173 (1) 1 the same sentence',
      '09/18/26-07:33:42:173 (2) 1 the same sentence',
    ]);
    expect(entries).toHaveLength(2);
    expect(entries.map((entry) => entry.pid)).toEqual(['1', '2']);
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
    // A window that opens mid-continuation reaches here.
    expect(severityWord('')).toBe(STRINGS.tableEmptyValue);
    expect(severityWord(parseFileLines(['    a fragment'])[0].severity)).toBe(STRINGS.tableEmptyValue);
  });

  it('declares the five chips in the scale order', () => {
    expect(SEVERITY_CHIPS.map((chip) => chip.key)).toEqual(['debug', 'info', 'warning', 'severe', 'fatal']);
    expect(SEVERITY_CHIPS[0].levels).toEqual(['-2', '-1']);
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

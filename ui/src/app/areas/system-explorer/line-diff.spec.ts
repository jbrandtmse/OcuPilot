import { describe, expect, it } from 'vitest';

import { changeCounts, hunks, lineDiff, type DiffLine } from './line-diff';

/**
 * The line diff Compare draws (Story 19.4, AC4): identical texts, an insertion, a deletion, a
 * replacement, the shared head and tail kept as unchanged lines, `null` past the edit bound, and the
 * hunks that collapse unchanged runs around three lines of context.
 */

/** A script as `kind:left:right:text` lines, so a case reads as the diff it is. */
function spelled(script: readonly DiffLine[] | null): string[] | null {
  if (script === null) return null;
  return script.map((line) => `${line.kind}:${line.left ?? ''}:${line.right ?? ''}:${line.text}`);
}

describe('lineDiff', () => {
  it('answers every line unchanged for identical texts', () => {
    expect(spelled(lineDiff(['a', 'b'], ['a', 'b']))).toEqual(['same:1:1:a', 'same:2:2:b']);
    expect(lineDiff([], [])).toEqual([]);
  });

  it('marks an inserted line added, numbered on the right', () => {
    expect(spelled(lineDiff(['a', 'c'], ['a', 'b', 'c']))).toEqual(['same:1:1:a', 'added::2:b', 'same:2:3:c']);
  });

  it('marks a deleted line removed, numbered on the left', () => {
    expect(spelled(lineDiff(['a', 'b', 'c'], ['a', 'c']))).toEqual(['same:1:1:a', 'removed:2::b', 'same:3:2:c']);
  });

  it('marks a replaced line removed, then added', () => {
    expect(spelled(lineDiff(['a', 'b', 'c'], ['a', 'x', 'c']))).toEqual(['same:1:1:a', 'removed:2::b', 'added::2:x', 'same:3:3:c']);
  });

  it('answers each side wholly removed or added when the other is empty', () => {
    expect(spelled(lineDiff(['a', 'b'], []))).toEqual(['removed:1::a', 'removed:2::b']);
    expect(spelled(lineDiff([], ['a']))).toEqual(['added::1:a']);
  });

  it('keeps the shared head and tail as unchanged lines, pairing the last line with the last', () => {
    // Without the tail trim, the middle's diff pairs the left's last line with the right's second
    // and adds the third; trimmed, the shared last line pairs with the right's last.
    // Mutation (Rule 19): stop trimming the common tail in `lineDiff` -> this goes red.
    expect(spelled(lineDiff(['p', 'a'], ['q', 'a', 'a']))).toEqual(['removed:1::p', 'added::1:q', 'added::2:a', 'same:2:3:a']);
    // The head is kept the same way: the shared first lines come first, unchanged.
    expect(spelled(lineDiff(['h', 'h', 'x'], ['h', 'h', 'y']))).toEqual(['same:1:1:h', 'same:2:2:h', 'removed:3::x', 'added::3:y']);
  });

  it('answers null past the edit bound, and a script at it', () => {
    const left = Array.from({ length: 6 }, (_, index) => `l${index}`);
    const right = Array.from({ length: 6 }, (_, index) => `r${index}`);
    expect(lineDiff(left, right, 11)).toBeNull();
    const script = lineDiff(left, right, 12);
    expect(script).not.toBeNull();
    expect(changeCounts(script ?? [])).toEqual({ removed: 6, added: 6 });
  });

  it('answers null for more than 1,000 changes by default', () => {
    const left = Array.from({ length: 600 }, (_, index) => `left ${index}`);
    const right = Array.from({ length: 600 }, (_, index) => `right ${index}`);
    expect(lineDiff(left, right)).toBeNull();
  });
});

describe('hunks', () => {
  const lines = (count: number, prefix: string): string[] => Array.from({ length: count }, (_, index) => `${prefix}${index}`);

  it('collapses an unchanged run beyond three lines of context on each side of a change', () => {
    const left = [...lines(10, 'a'), 'old', ...lines(10, 'b')];
    const right = [...lines(10, 'a'), 'new', ...lines(10, 'b')];
    const segments = hunks(lineDiff(left, right) ?? []);
    expect(segments.map((segment) => (segment.kind === 'collapsed' ? `collapsed ${segment.count}` : `lines ${segment.lines.map((line) => line.text).join(',')}`))).toEqual([
      'collapsed 7',
      'lines a7,a8,a9,old,new,b0,b1,b2',
      'collapsed 7',
    ]);
  });

  it('keeps a run between two changes whole when it is within twice the context', () => {
    const left = ['x', ...lines(6, 'm'), 'y'];
    const right = ['X', ...lines(6, 'm'), 'Y'];
    const segments = hunks(lineDiff(left, right) ?? []);
    expect(segments).toHaveLength(1);
    expect(segments[0].kind).toBe('lines');
  });

  it('collapses a script with no change to one run', () => {
    expect(hunks(lineDiff(['a', 'b'], ['a', 'b']) ?? [])).toEqual([{ kind: 'collapsed', count: 2 }]);
  });
});

import { TestBed } from '@angular/core/testing';
import { describe, expect, it } from 'vitest';

import { STRINGS } from '../core/strings';
import { TextDiff, hunkCounts, hunkLines, hunkScript } from './text-diff';

/**
 * Pins `app-text-diff` and its pure helpers (Story 20.21): a changed-lines hunk's sides split into
 * lines, the counts the summary line reads, the fallback past the line diff's edit bound, and the
 * drawn markup -- numbers offset to the document line, three lines of context, and an unchanged run
 * collapsed to its count. Needs nothing from the environment.
 *
 * Mutation (Rule 19): offset numbers by `line` instead of `line - 1` -> the numbering test goes red.
 */

const BEFORE = 'a\nb\nc\nd\ne\nf\ng\nh\n';
const AFTER = 'a\nb\nc\nd\ne\nF\ng\nh\n';

function mount(before: string, after: string, line: number, label: string): HTMLElement {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({});
  const fixture = TestBed.createComponent(TextDiff);
  fixture.componentRef.setInput('before', before);
  fixture.componentRef.setInput('after', after);
  fixture.componentRef.setInput('line', line);
  fixture.componentRef.setInput('label', label);
  fixture.detectChanges();
  return fixture.nativeElement as HTMLElement;
}

describe('hunkLines', () => {
  it('splits LF pieces and drops the empty piece a final LF leaves', () => {
    expect(hunkLines('a\nb\n')).toEqual(['a', 'b']);
    expect(hunkLines('a\n\nb')).toEqual(['a', '', 'b']);
    expect(hunkLines('')).toEqual([]);
  });
});

describe('hunkCounts', () => {
  it('counts the lines a change removes and adds', () => {
    expect(hunkCounts(BEFORE, AFTER)).toEqual({ removed: 1, added: 1 });
    expect(hunkCounts('', 'x\ny\n')).toEqual({ removed: 0, added: 2 });
  });

  it('counts every line whole when the line diff is too long to compute', () => {
    const before = Array.from({ length: 1100 }, (_, index) => `old ${index}`).join('\n');
    const after = Array.from({ length: 1100 }, (_, index) => `new ${index}`).join('\n');
    expect(hunkScript(before, after)).toHaveLength(2200);
    expect(hunkCounts(before, after)).toEqual({ removed: 1100, added: 1100 });
  });
});

describe('app-text-diff markup', () => {
  it('labels its region and numbers the change at its document line', () => {
    const host = mount(BEFORE, AFTER, 10, 'Demo.cls');
    const region = host.querySelector('[role="region"]');
    expect(region?.getAttribute('aria-label')).toBe('Demo.cls');
    const removed = host.querySelector('[data-ocu-diff="removed"]');
    const added = host.querySelector('[data-ocu-diff="added"]');
    expect(removed?.querySelector('.ocu-line-diff-number')?.textContent).toBe('15');
    expect(removed?.querySelector('.ocu-line-diff-text')?.textContent).toBe('f');
    expect(added?.querySelector('.ocu-line-diff-number')?.textContent).toBe('15');
    expect(added?.querySelector('.ocu-line-diff-text')?.textContent).toBe('F');
    expect(added?.querySelector('.ocu-diff-direction')?.textContent).toBe(STRINGS.explorerDiffAdded);
  });

  it('keeps three lines of context and collapses the longer unchanged run to its count', () => {
    const host = mount(BEFORE, AFTER, 1, 'Demo.cls');
    expect(host.querySelector('[data-ocu-diff="collapsed"]')?.textContent).toBe('2 unchanged lines');
    expect(host.querySelectorAll('[data-ocu-diff="same"]')).toHaveLength(5);
  });
});

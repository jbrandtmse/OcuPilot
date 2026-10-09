import { TestBed } from '@angular/core/testing';
import { describe, expect, it } from 'vitest';

import { TextDiff } from './text-diff';

/**
 * The rows `app-text-diff` draws for the hunks a card can carry (Story 20.21), read as the sequence of
 * `kind:number` a person sees: a pure insertion and a pure deletion, an empty hunk, the hunk line clamped
 * to the first, numbers that stay in document terms past a collapsed run between two distant changes, the
 * fallback past the line diff's edit bound (every removal, then every addition), and text drawn as text.
 * Needs nothing from the environment.
 *
 * Mutation (Rule 19): number the lines after a collapsed run from the run's end instead of their own
 * `left` -> the distant-changes test goes red.
 */

function mount(before: string, after: string, line: number): HTMLElement {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({});
  const fixture = TestBed.createComponent(TextDiff);
  fixture.componentRef.setInput('before', before);
  fixture.componentRef.setInput('after', after);
  fixture.componentRef.setInput('line', line);
  fixture.componentRef.setInput('label', 'Probe.cls');
  fixture.detectChanges();
  return fixture.nativeElement as HTMLElement;
}

/** The drawn sequence: `kind:number` per line, and the caption of a collapsed run. */
function sequence(host: HTMLElement): string[] {
  return Array.from(host.querySelectorAll('[data-ocu-diff]')).map((node) => {
    const kind = node.getAttribute('data-ocu-diff') ?? '';
    if (kind === 'collapsed') return `collapsed:${node.textContent?.trim() ?? ''}`;
    return `${kind}:${node.querySelector('.ocu-line-diff-number')?.textContent ?? ''}`;
  });
}

function lines(count: number, changed: readonly number[] = []): string {
  return (
    Array.from({ length: count }, (_, index) => (changed.includes(index + 1) ? `L${index + 1}` : `l${index + 1}`)).join('\n') + '\n'
  );
}

describe('app-text-diff rows', () => {
  it('draws a pure insertion as added lines numbered from the hunk line', () => {
    expect(sequence(mount('', 'x\ny\n', 8))).toEqual(['added:8', 'added:9']);
  });

  it('draws a pure deletion as removed lines numbered from the hunk line', () => {
    expect(sequence(mount('x\ny\n', '', 8))).toEqual(['removed:8', 'removed:9']);
  });

  it('draws nothing for a hunk with neither side', () => {
    const host = mount('', '', 1);
    expect(sequence(host)).toEqual([]);
    expect(host.querySelector('[role="region"]')).not.toBeNull();
  });

  it('numbers from the first line when the hunk line is below one, and from its whole part when fractional', () => {
    expect(sequence(mount('', 'x\n', 0))).toEqual(['added:1']);
    expect(sequence(mount('', 'x\n', -4))).toEqual(['added:1']);
    expect(sequence(mount('', 'x\n', 2.7))).toEqual(['added:2']);
  });

  it('keeps document numbers across a collapsed run between two distant changes', () => {
    const host = mount(lines(30), lines(30, [3, 28]), 100);
    expect(sequence(host)).toEqual([
      'same:100',
      'same:101',
      'removed:102',
      'added:102',
      'same:103',
      'same:104',
      'same:105',
      'collapsed:18 unchanged lines',
      'same:124',
      'same:125',
      'same:126',
      'removed:127',
      'added:127',
      'same:128',
      'same:129',
    ]);
  });

  it('draws every removal and then every addition when the change is past the line diff bound', () => {
    const before = Array.from({ length: 1100 }, (_, index) => `old ${index}`).join('\n') + '\n';
    const after = Array.from({ length: 1100 }, (_, index) => `new ${index}`).join('\n') + '\n';
    const drawn = sequence(mount(before, after, 1));
    expect(drawn).toHaveLength(2200);
    expect(drawn.slice(0, 1100).every((entry) => entry.startsWith('removed:'))).toBe(true);
    expect(drawn.slice(1100).every((entry) => entry.startsWith('added:'))).toBe(true);
    expect(drawn[0]).toBe('removed:1');
    expect(drawn[1100]).toBe('added:1');
    expect(drawn[2199]).toBe('added:1100');
  });

  it('draws a hunk as text, never as markup', () => {
    const host = mount('<img src=x onerror=alert(1)>\n', '<b>bold</b>\n', 1);
    expect(host.querySelector('img')).toBeNull();
    expect(host.querySelector('b')).toBeNull();
    const texts = Array.from(host.querySelectorAll('.ocu-line-diff-text')).map((node) => node.textContent);
    expect(texts).toEqual(['<img src=x onerror=alert(1)>', '<b>bold</b>']);
  });
});

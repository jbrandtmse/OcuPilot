import { ComponentFixture, TestBed } from '@angular/core/testing';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { afterEach, describe, expect, it } from 'vitest';

import { Meter } from './meter';

/**
 * The shared meter (Story 6.9): the two shapes (`state` null is a value meter, non-null is a
 * track meter), the pending, loaded and failed renderings, and AC2's "never animates" rule.
 *
 * Mutations (Rule 19): drop the `isTrack` guard around `.ocu-meter-track` -> a value meter grows a
 * track, and the "no track, no word" test goes red. Read `pending` off `value() === null` alone,
 * with no `word()` check -> the loaded status-meter test goes red, showing a skeleton over its own
 * word. Drop the `failed` branch from `displayValue` -> the "kept value dashed by a fault" test
 * goes red, showing the numeric value instead of a dash.
 */

const planted: HTMLElement[] = [];

function mount(inputs: Record<string, unknown>): { fixture: ComponentFixture<Meter>; host: HTMLElement } {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({ imports: [Meter] });
  const fixture = TestBed.createComponent(Meter);
  for (const [key, value] of Object.entries(inputs)) fixture.componentRef.setInput(key, value);
  fixture.detectChanges();
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  return { fixture, host: fixture.nativeElement as HTMLElement };
}

afterEach(() => {
  for (const element of planted.splice(0)) element.remove();
});

describe('Meter', () => {
  it('a value meter (state null) draws no track and no word, just the label and value', () => {
    const { host } = mount({ label: 'Global references per second', value: 123, unit: '', state: null, word: null });
    expect(host.querySelector('.ocu-meter-label')?.textContent?.trim()).toBe('Global references per second');
    expect(host.querySelector('.ocu-meter-value')?.textContent?.trim()).toBe('123');
    expect(host.querySelector('.ocu-meter-track')).toBeNull();
    expect(host.querySelector('.ocu-meter-word')).toBeNull();
  });

  it('a value meter appends its unit when one is declared', () => {
    const { host } = mount({ label: 'Cache efficiency', value: 98, unit: '%', state: null });
    expect(host.querySelector('.ocu-meter-value')?.textContent?.trim()).toBe('98 %');
  });

  it('pending (a track meter with neither a value nor a word, and no fault): a dash and a skeleton fill, no color', () => {
    const { host } = mount({ label: 'Database space', value: null, state: 'normal', word: null, error: null });
    expect(host.querySelector('.ocu-meter-value')?.textContent?.trim()).toBe('\u2014');
    expect(host.querySelector('.ocu-meter-fill-skeleton')).not.toBeNull();
    expect(host.querySelector('.ocu-meter-fill')).toBeNull();
    expect(host.querySelector('.ocu-meter-word')).toBeNull();
    expect(host.getAttribute('title')).toBeNull();
  });

  it('a loaded percentage meter (Shared memory) colors the fill and the value, and shows the word', () => {
    const { host } = mount({
      label: 'Shared memory',
      value: 900,
      unit: '',
      percent: 90,
      state: 'warning',
      word: 'Warning',
    });
    const fill = host.querySelector('.ocu-meter-fill') as HTMLElement | null;
    expect(fill).not.toBeNull();
    expect(fill?.classList.contains('ocu-meter-fill-warning')).toBe(true);
    expect(fill?.style.width).toBe('90%');
    expect(host.querySelector('.ocu-meter-fill-skeleton')).toBeNull();
    const value = host.querySelector('.ocu-meter-value');
    expect(value?.textContent?.trim()).toBe('900');
    expect(value?.classList.contains('ocu-meter-value-warning')).toBe(true);
    const word = host.querySelector('.ocu-meter-word');
    expect(word?.textContent?.trim()).toBe('Warning');
    expect(word?.classList.contains('ocu-meter-word-warning')).toBe(true);
  });

  it('a loaded status meter (no numeric value, percent null) fills fully and shows the word as its only readout', () => {
    const { host } = mount({ label: 'Write daemon', value: null, percent: null, state: 'normal', word: 'Normal' });
    const fill = host.querySelector('.ocu-meter-fill') as HTMLElement | null;
    expect(fill).not.toBeNull();
    expect(fill?.classList.contains('ocu-meter-fill-normal')).toBe(true);
    expect(fill?.style.width).toBe('100%');
    expect(host.querySelector('.ocu-meter-value')).toBeNull();
    expect(host.querySelector('.ocu-meter-word')?.textContent?.trim()).toBe('Normal');
  });

  it('a fault after a success dashes the number but keeps the last color, word and puts the reason in a tooltip', () => {
    const { host } = mount({
      label: 'Shared memory',
      value: 900,
      percent: 90,
      state: 'warning',
      word: 'Warning',
      error: 'the instance refused the request',
    });
    expect(host.querySelector('.ocu-meter-value')?.textContent?.trim()).toBe('\u2014');
    const fill = host.querySelector('.ocu-meter-fill');
    expect(fill?.classList.contains('ocu-meter-fill-warning')).toBe(true);
    expect(host.querySelector('.ocu-meter-word')?.textContent?.trim()).toBe('Warning');
    expect(host.getAttribute('title')).toBe('the instance refused the request');
    // Not read as visible body text -- a tooltip only.
    expect(host.textContent).not.toContain('the instance refused the request');
  });

  it('a fault before any success shows a dash with the tooltip and no colored or skeleton fill', () => {
    const { host } = mount({ label: 'Database space', value: null, state: 'normal', word: null, error: 'refused' });
    expect(host.querySelector('.ocu-meter-value')?.textContent?.trim()).toBe('\u2014');
    expect(host.querySelector('.ocu-meter-fill')).toBeNull();
    expect(host.querySelector('.ocu-meter-fill-skeleton')).toBeNull();
    expect(host.querySelector('.ocu-meter-word')).toBeNull();
    expect(host.getAttribute('title')).toBe('refused');
  });

  it('the fill percent is bounded to 0..100', () => {
    const over = mount({ label: 'x', value: 1, percent: 150, state: 'normal', word: 'Normal' });
    expect((over.host.querySelector('.ocu-meter-fill') as HTMLElement).style.width).toBe('100%');
    const under = mount({ label: 'x', value: 1, percent: -10, state: 'normal', word: 'Normal' });
    expect((under.host.querySelector('.ocu-meter-fill') as HTMLElement).style.width).toBe('0%');
  });
});

/**
 * AC2: the fill never transitions or animates. jsdom's `getComputedStyle` resolves no external
 * stylesheet -- `_components.scss` is compiled by the Angular build, not loaded into this harness
 * -- so it would report the browser's own initial values (`0s` / `none`) whatever this rule said,
 * which is not a test of anything. The static assertion below reads the authored rule itself, the
 * same way `ui/tools/design-tokens.test.mjs` and `ui/tools/screen-mirror.test.mjs` read source
 * files directly rather than a compiled artifact.
 */
describe('the meter fill never animates (AC2)', () => {
  it('.ocu-meter-fill sets transition and animation to none, explicitly', () => {
    const componentsPath = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'styles', '_components.scss');
    const source = readFileSync(componentsPath, 'utf8');
    const match = /\.ocu-meter-fill\s*\{([^}]*)\}/.exec(source);
    expect(match, `.ocu-meter-fill is declared in ${componentsPath}`).not.toBeNull();
    const body = match?.[1] ?? '';
    expect(body).toMatch(/transition:\s*none/);
    expect(body).toMatch(/animation:\s*none/);
  });
});

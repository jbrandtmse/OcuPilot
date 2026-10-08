import { ComponentFixture, TestBed } from '@angular/core/testing';
import { beforeEach, describe, expect, it } from 'vitest';

import { LongBlocks } from '../core/long-blocks';
import { STRINGS } from '../core/strings';
import { LongBlock } from './long-block';

/**
 * What the long-block wrapper does (Story 20.17, AC1-AC3): a block estimated above eight lines
 * is clamped and carries the control; a shorter one carries neither; the control and focus open
 * it; and what a person opened is remembered by key in the shared store, never for an empty key.
 *
 * jsdom computes no layout, so nothing here asserts geometry: the clamp is a class.
 */
describe('the long-block wrapper', () => {
  const mount = (
    key: string,
    lines: number,
    store?: LongBlocks
  ): ComponentFixture<LongBlock> => {
    if (store !== undefined) TestBed.overrideProvider(LongBlocks, { useValue: store });
    const fixture = TestBed.createComponent(LongBlock);
    fixture.componentRef.setInput('key', key);
    fixture.componentRef.setInput('lines', lines);
    fixture.detectChanges();
    return fixture;
  };

  const button = (fixture: ComponentFixture<LongBlock>): HTMLButtonElement | null =>
    fixture.nativeElement.querySelector('.ocu-long-block-toggle');

  const wrapper = (fixture: ComponentFixture<LongBlock>): HTMLElement =>
    fixture.nativeElement.querySelector('.ocu-long-block');

  const region = (fixture: ComponentFixture<LongBlock>): HTMLElement =>
    fixture.nativeElement.querySelector('.ocu-long-block-region');

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [LongBlock],
      providers: [{ provide: LongBlocks, useValue: new LongBlocks() }],
    });
  });

  it('a block of eight lines renders no control and no clamp class', () => {
    const fixture = mount('c:t0:reply', 8);

    expect(button(fixture)).toBeNull();
    expect(wrapper(fixture).classList.contains('ocu-long-block-collapsed')).toBe(false);
  });

  it('a block of nine lines is clamped, with the control labelled and wired to the region', () => {
    const fixture = mount('c:t0:reply', 9);
    const toggle = button(fixture);

    expect(wrapper(fixture).classList.contains('ocu-long-block-collapsed')).toBe(true);
    expect(toggle?.type).toBe('button');
    expect(toggle?.textContent?.trim()).toBe(STRINGS.longBlockShowMore);
    expect(toggle?.getAttribute('aria-expanded')).toBe('false');
    expect(toggle?.getAttribute('aria-controls')).toBe(region(fixture).id);
    expect(region(fixture).id).toBe('ocu-long-block-c_t0_reply');
  });

  it('the control opens and closes the block', () => {
    const fixture = mount('c:t0:reply', 12);

    button(fixture)?.click();
    fixture.detectChanges();
    expect(wrapper(fixture).classList.contains('ocu-long-block-collapsed')).toBe(false);
    expect(button(fixture)?.textContent?.trim()).toBe(STRINGS.longBlockShowLess);
    expect(button(fixture)?.getAttribute('aria-expanded')).toBe('true');

    button(fixture)?.click();
    fixture.detectChanges();
    expect(wrapper(fixture).classList.contains('ocu-long-block-collapsed')).toBe(true);
    expect(button(fixture)?.getAttribute('aria-expanded')).toBe('false');
  });

  // Mutation (Rule 19): remove the `(focusin)` handler -> this goes red.
  it('focus moving into a collapsed region opens it', () => {
    const fixture = mount('c:t0:reply', 12);

    region(fixture).dispatchEvent(new FocusEvent('focusin', { bubbles: true }));
    fixture.detectChanges();

    expect(wrapper(fixture).classList.contains('ocu-long-block-collapsed')).toBe(false);
    expect(button(fixture)?.getAttribute('aria-expanded')).toBe('true');
  });

  it('an opened block stays open when the block is created again over the same store', () => {
    const store = new LongBlocks();
    const first = mount('c:t0:reply', 12, store);
    button(first)?.click();
    first.detectChanges();
    first.destroy();

    const second = TestBed.createComponent(LongBlock);
    second.componentRef.setInput('key', 'c:t0:reply');
    second.componentRef.setInput('lines', 12);
    second.detectChanges();

    expect(button(second)?.getAttribute('aria-expanded')).toBe('true');
  });

  it('a store that forgets its session closes the block', () => {
    const store = new LongBlocks();
    const fixture = mount('c:t0:reply', 12, store);
    button(fixture)?.click();
    fixture.detectChanges();

    store.endSession();
    fixture.detectChanges();

    expect(button(fixture)?.getAttribute('aria-expanded')).toBe('false');
  });

  it('an empty key keeps its state in the component and stores nothing', () => {
    const store = new LongBlocks();
    const fixture = mount('', 12, store);

    button(fixture)?.click();
    fixture.detectChanges();

    expect(button(fixture)?.getAttribute('aria-expanded')).toBe('true');
    expect(store.isOpen('')).toBe(false);
  });
});

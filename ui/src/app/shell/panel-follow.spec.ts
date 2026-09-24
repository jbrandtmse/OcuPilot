import { describe, expect, it } from 'vitest';

import { TranscriptFollow, atNewest, type ScrollBox } from './panel-follow';

/**
 * The follow rule over a fake transcript: the at-newest predicate at its tolerance, a user's scroll
 * away and back, the panel's own smooth scroll passing through intermediate positions, and the jump.
 * jsdom computes no layout, so the geometry is set by hand and each scroll event is `onScroll`.
 */

/** A 1000 px transcript in a 200 px viewport, standing at its newest entry. */
function box(): ScrollBox & { scrollHeight: number } {
  return { scrollHeight: 1000, clientHeight: 200, scrollTop: 800 };
}

/** Move `b` to `top` and deliver the scroll event, as the browser would. */
function scrollTo(follow: TranscriptFollow, b: ScrollBox, top: number): boolean {
  b.scrollTop = top;
  return follow.onScroll(b);
}

describe('the transcript follow rule', () => {
  it('a user scroll to 4 px from the bottom still follows, and to 5 px does not', () => {
    const follow = new TranscriptFollow();
    const b = box();
    follow.settle(b);
    scrollTo(follow, b, 796);
    expect(atNewest(b)).toBe(true);
    expect(follow.following).toBe(true);

    const other = new TranscriptFollow();
    const c = box();
    other.settle(c);
    expect(scrollTo(other, c, 795)).toBe(true);
    expect(atNewest(c)).toBe(false);
    expect(other.following).toBe(false);
  });

  it('a user scroll away stops following, growth then moves nothing, and a scroll back resumes it', () => {
    const follow = new TranscriptFollow();
    const b = box();
    follow.settle(b);
    scrollTo(follow, b, 400);
    expect(follow.following).toBe(false);

    b.scrollHeight = 1400;
    expect(follow.settle(b)).toBe(false);
    expect(b.scrollTop).toBe(400);

    scrollTo(follow, b, 900);
    expect(follow.following).toBe(false);
    expect(scrollTo(follow, b, 1200)).toBe(true);
    expect(follow.following).toBe(true);
  });

  it('while following, growth scrolls to the newest entry once, and a smooth scroll on its way there keeps following on', () => {
    const follow = new TranscriptFollow();
    const b = box();
    follow.settle(b);
    b.scrollHeight = 1600;
    expect(follow.settle(b)).toBe(true);
    expect(b.scrollTop).toBe(1400);

    // A smooth scroll: the element reports the positions it passes through, each below the last
    // reported one's target but above the one before it.
    for (const top of [850, 1000, 1200, 1390]) {
      b.scrollTop = top;
      follow.onScroll(b);
      expect(follow.following).toBe(true);
      expect(follow.settle(b)).toBe(false);
    }
    scrollTo(follow, b, 1400);
    expect(follow.following).toBe(true);
  });

  it('the jump follows again from a scrolled-up transcript and scrolls to the newest entry', () => {
    const follow = new TranscriptFollow();
    const b = box();
    follow.settle(b);
    scrollTo(follow, b, 100);
    expect(follow.following).toBe(false);

    follow.follow(b);
    expect(follow.following).toBe(true);
    expect(b.scrollTop).toBe(800);
    expect(atNewest(b)).toBe(true);
  });

  it('a transcript that fits its viewport is at its newest entry', () => {
    const follow = new TranscriptFollow();
    const b: ScrollBox = { scrollHeight: 150, clientHeight: 200, scrollTop: 0 };
    expect(atNewest(b)).toBe(true);
    expect(follow.settle(b)).toBe(false);
    expect(scrollTo(follow, b, 0)).toBe(false);
    expect(follow.following).toBe(true);
  });

  it('a transcript restored on reload opens at its newest entry: the first render that overflows scrolls there', () => {
    // Mutation (Rule 19): have the first `settle` only record `lastNewest` without scrolling -> this
    // goes red, and a reloaded transcript opens at its oldest entry.
    const follow = new TranscriptFollow();
    const b: ScrollBox = { scrollHeight: 1000, clientHeight: 200, scrollTop: 0 };
    expect(follow.settle(b)).toBe(true);
    expect(b.scrollTop).toBe(800);
    expect(atNewest(b)).toBe(true);
  });

  it('an arrival while 4 px from the bottom scrolls to the newest entry', () => {
    const follow = new TranscriptFollow();
    const b = box();
    follow.settle(b);
    scrollTo(follow, b, 796);
    b.scrollHeight = 1300;
    expect(follow.settle(b)).toBe(true);
    expect(b.scrollTop).toBe(1100);
  });
});

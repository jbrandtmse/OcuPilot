import { describe, expect, it } from 'vitest';

import { activeRealTimers, awaitRealTimersIdle } from './real-timers';

/**
 * Pins the two helpers `log-viewer.spec.ts` and `home.page.spec.ts` share. Each test arms and clears
 * its own timers and compares against a count it took itself, so it needs nothing another test or
 * spec file leaves behind.
 */
describe('real-timers', () => {
  it('activeRealTimers counts a pending real timer, and stops counting it once cleared', () => {
    const before = activeRealTimers();
    const pending = setTimeout(() => undefined, 60_000);
    expect(activeRealTimers()).toBe(before + 1);
    clearTimeout(pending);
    expect(activeRealTimers()).toBe(before);
  });

  it('awaitRealTimersIdle lets a due real timer fire before it returns', async () => {
    let fired = false;
    setTimeout(() => {
      fired = true;
    }, 60);
    await awaitRealTimersIdle();
    expect(fired).toBe(true);
  });

  it('awaitRealTimersIdle is bounded: a timer that never goes idle holds it for its polls and no longer', async () => {
    // The interval is the only timer this test arms, and it ends itself after about 6 s, so a
    // regression to an unbounded wait fails the elapsed bound below instead of hanging the worker.
    let ticks = 0;
    const foreign = setInterval(() => {
      ticks += 1;
      if (ticks >= 1200) clearInterval(foreign);
    }, 5);
    try {
      const started = Date.now();
      await awaitRealTimersIdle();
      const elapsed = Date.now() - started;
      const atReturn = activeRealTimers();
      clearInterval(foreign);
      expect(activeRealTimers(), 'the interval was still pending, so the wait returned on its bound').toBe(atReturn - 1);
      expect(elapsed, 'it polled 50 times at 20 ms before giving up').toBeGreaterThanOrEqual(900);
      expect(elapsed, 'and then gave up').toBeLessThan(4000);
    } finally {
      clearInterval(foreign);
    }
  }, 15_000);
});

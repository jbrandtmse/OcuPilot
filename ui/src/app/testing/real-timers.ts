/**
 * Real-timer accounting for a spec that fakes the clock and counts the timers a page arms.
 *
 * Angular's vitest runner shares one worker across spec files, so a real timer an earlier test
 * left pending can fire while a later test holds the fake clock, and arm a timer on it. Counting
 * `vi.getTimerCount()` then reports the earlier test's timer as the page's own. A spec that counts
 * waits here for the real loop to empty before it calls `vi.useFakeTimers()`, and then advances
 * the fake clock synchronously, which never yields to the real loop.
 */

/** The `Timeout` handles the real event loop still holds, from Node's own accounting. */
export function activeRealTimers(): number {
  const resources = (process as unknown as { getActiveResourcesInfo(): string[] }).getActiveResourcesInfo();
  return resources.filter((resource) => resource === 'Timeout').length;
}

/**
 * Wait until no real `Timeout` is active, or for 50 polls of 20 ms, whichever comes first. The
 * wait is bounded and asserts nothing: a timer still pending afterwards is the environment's
 * business, and the caller reports how many remain (`activeRealTimers()`) beside its own count.
 */
export async function awaitRealTimersIdle(): Promise<void> {
  for (let attempt = 0; attempt < 50 && activeRealTimers() > 0; attempt += 1) {
    await new Promise((resolve) => setTimeout(resolve, 20));
  }
}

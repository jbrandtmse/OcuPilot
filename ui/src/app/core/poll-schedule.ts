/**
 * When a progress poll's next request is sent: after `delayMs`, on the browser's own timer.
 *
 * A store that follows a job running on the instance -- a background SQL run (Story 19.15), as the
 * turn store follows its turn (AD-7, AD-33) -- takes this as its default schedule, and a spec replaces
 * it to drive the poll by hand. It is not auto-refresh (AD-43): it re-reads no declared read, and its
 * caller stops scheduling once the job has ended.
 */
export function schedulePoll(run: () => void, delayMs: number): void {
  setTimeout(run, delayMs);
}

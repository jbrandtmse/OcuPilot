/**
 * When a progress poll's next request is sent: after `delayMs`, on the browser's own timer.
 *
 * SQL query's background run (Story 19.15) takes this as its default schedule while it follows its job
 * on the instance, and a spec replaces it to drive the poll by hand; the turn store keeps its own
 * schedule seam. It is not auto-refresh (AD-43): it re-reads no declared read, and its caller stops
 * scheduling once the job has ended.
 */
export function schedulePoll(run: () => void, delayMs: number): void {
  setTimeout(run, delayMs);
}

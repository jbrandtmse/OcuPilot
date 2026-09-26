/**
 * The one-shot hand-off between an agent navigation and the screen it arrives at (Story 11.11,
 * AD-11).
 *
 * The navigator sets an arrival -- the route, the flag criterion and the criteria values the
 * instance validated on the directive -- before it moves the browser. The arriving page takes it
 * once, in place of its own default read, and runs exactly that search. A page that is already
 * mounted on the route is told through `subscribe`, and takes it the same way. Nothing here puts a
 * criterion in a URL: the values ride this holder and reach the read only as its own criteria
 * (AD-21).
 *
 * Framework-free, like the rest of `core/` (AD-19).
 */

/** What an agent navigation hands the screen it arrives at. */
export interface ScreenArrival {
  /** The route the directive named, as the descriptor declares it. */
  readonly route: string;
  /** A flag criterion the screen declares, or `''` (Story 5.8). */
  readonly criterion: string;
  /** Criteria values keyed by the screen's declared criteria (AD-11). An omitted key takes its default. */
  readonly criteria: Readonly<Record<string, string>>;
}

export class ScreenArrivals {
  private pending: ScreenArrival | null = null;

  private readonly listeners = new Set<() => void>();

  /** Hold `arrival` for the page at its route, replacing any arrival nobody took, and tell every subscriber. */
  set(arrival: ScreenArrival): void {
    this.pending = arrival;
    for (const listener of [...this.listeners]) listener();
  }

  /** The arrival held for `route`, cleared as it is returned, or `null`. One take per arrival. */
  take(route: string): ScreenArrival | null {
    const held = this.pending;
    if (held === null || held.route !== route) return null;
    this.pending = null;
    return held;
  }

  /** Drop the held arrival: the navigation it was for did not happen. */
  clear(): void {
    this.pending = null;
  }

  /** Called on every `set`, so a page already mounted on the route can take its arrival. */
  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }
}

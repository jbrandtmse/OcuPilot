/**
 * The one answer to join-versus-queue (**DW-4**, **DW-102**, **DW-157**).
 *
 * A read that is already running is the right answer for a second caller who wants the *same*
 * thing, and the wrong answer for one whose input has moved. Every site in this client that got
 * it wrong got it wrong the same way -- `join` unconditionally -- and every local patch that
 * tried to fix it by queueing got it wrong the other way: a naive queue re-runs on *every*
 * request, so a refusal reported by the very call in flight (`navigation.ts`'s DW-9 stub) queues
 * another one, which is refused, which queues another.
 *
 * Keying the decision on the **input** settles both at once. An unchanged key joins, so a repeat
 * and a self-reported refusal cost one read; a changed key marks the flight dirty and re-runs
 * **once** after it settles, against whatever the key is by then -- so N changes mid-flight still
 * yield one re-run, and that re-run carries the latest input rather than the one that first moved.
 *
 * **The slot is filled before `run` is called**, never after it resolves. `run` executes
 * synchronously up to its first `await`, and anything it reaches in that window -- a refusal the
 * call reports about itself -- must find the slot filled, or it starts a second flight
 * recursively. `navigation.ts` carried that rule as a comment before this module existed; it is
 * the reason `start()` below assigns `current` before it calls `run`.
 *
 * **Failure is the caller's.** A rejected `run` settles the flight and nothing is retried here:
 * the reader that failed parks its own one re-read with `ConnectivityService`, which is what
 * keeps one recovery path rather than two chasing each other.
 *
 * Framework-free, like the rest of `core/`, so `ui/tools/single-flight.test.mjs` executes it
 * under `node --test`.
 */

export interface SingleFlight {
  /**
   * Run, or join the run already going. Resolves when the flight this call joined settles --
   * not when a re-run it provoked does, which is what keeps `await load()` meaning what it
   * meant before this module existed.
   */
  request(): Promise<void>;
  /** Whether a run is going. */
  running(): boolean;
  /** The key the running flight was issued against, or `''` when nothing is running. */
  key(): string;
  /** Whether a changed key has marked the running flight for one re-run. */
  dirty(): boolean;
  /**
   * Forget the flight and any dirty mark. The running `run` is not cancelled -- nothing here can
   * cancel a fetch -- but it no longer owns the slot and its re-run is dropped, which is what
   * `reset()` on a service means: the answer belonged to a principal who has left (AD-8).
   */
  reset(): void;
}

/**
 * `run` is the work, handed the key it was issued against; `keyOf` reads the current input.
 *
 * The key is a string so equality is value equality: a caller whose input is a tuple joins it
 * into one, rather than this module guessing how to compare two objects.
 */
export function createSingleFlight(
  run: (key: string) => Promise<void>,
  keyOf: () => string
): SingleFlight {
  let current: Promise<void> | null = null;
  let currentKey = '';
  let marked = false;

  const start = (): Promise<void> => {
    const key = keyOf();
    let settle: () => void = () => {};
    const gate = new Promise<void>((resolve) => {
      settle = resolve;
    });
    current = gate;
    currentKey = key;
    void run(key)
      .catch(() => undefined)
      .finally(() => {
        // `reset()` may have taken the slot already; a flight that no longer owns it settles its
        // own waiters and nothing else -- in particular it does not re-run for a principal who
        // has left the tab.
        if (current !== gate) {
          settle();
          return;
        }
        current = null;
        currentKey = '';
        const rerun = marked;
        marked = false;
        settle();
        if (rerun) void start();
      });
    return gate;
  };

  return {
    request(): Promise<void> {
      const running = current;
      if (running === null) return start();
      // The input moved under the flight: one re-run, however many times it moves again before
      // this one settles, and issued against whatever `keyOf()` reads by then.
      if (keyOf() !== currentKey) marked = true;
      return running;
    },
    running(): boolean {
      return current !== null;
    },
    key(): string {
      return current === null ? '' : currentKey;
    },
    dirty(): boolean {
      return marked;
    },
    reset(): void {
      current = null;
      currentKey = '';
      marked = false;
    },
  };
}

/**
 * The handlers that run a screen's declared actions (AD-5, AD-19).
 *
 * A descriptor declares its actions; the screen that can carry one out registers a handler for
 * it here, keyed by the descriptor's class name and the action's declared id. The command bar
 * and the command box offer a primary action only while `has` answers `true`, and both surfaces
 * run it through `run`, so neither draws a control nothing can act on.
 *
 * Framework-free, like the rest of `core/`: a plain subscribable that components mirror into a
 * signal.
 */

/** What runs one declared action. */
export type ScreenActionRun = () => void;

export class ScreenActions {
  private readonly handlers = new Map<string, Map<string, { readonly run: ScreenActionRun }>>();

  private readonly listeners = new Set<() => void>();

  /**
   * Register `run` for `actionId` on `descriptor`, replacing any handler already there, and
   * return the function that removes it. The remover removes only the registration it made, so
   * a stale remover called after a re-registration leaves the newer one in place, even when both
   * registered the same function.
   */
  register(descriptor: string, actionId: string, run: ScreenActionRun): () => void {
    let forDescriptor = this.handlers.get(descriptor);
    if (forDescriptor === undefined) {
      forDescriptor = new Map();
      this.handlers.set(descriptor, forDescriptor);
    }
    const registration = { run };
    forDescriptor.set(actionId, registration);
    this.notify();

    return () => {
      const current = this.handlers.get(descriptor);
      if (current?.get(actionId) !== registration) return;
      current.delete(actionId);
      if (current.size === 0) this.handlers.delete(descriptor);
      this.notify();
    };
  }

  /** Whether a handler is registered for `actionId` on `descriptor`. An empty id never has one. */
  has(descriptor: string, actionId: string): boolean {
    if (actionId === '') return false;
    return this.handlers.get(descriptor)?.has(actionId) ?? false;
  }

  /** Run the registered handler once, and report whether there was one. */
  run(descriptor: string, actionId: string): boolean {
    if (actionId === '') return false;
    const registration = this.handlers.get(descriptor)?.get(actionId);
    if (registration === undefined) return false;
    registration.run();
    return true;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  private notify(): void {
    for (const listener of this.listeners) listener();
  }
}

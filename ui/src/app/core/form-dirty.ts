/**
 * The open form's unsaved-changes state, and the one place the answer to "leave without saving?"
 * is asked and given (AD-11 rule 3, AD-19).
 *
 * **One flag and one question, because there is one form open at a time.** A `form-page` route
 * marks itself dirty as the operator types and clean on a save; the route guard on every
 * `form-page` route asks `requestLeave()` before letting a navigation through; the form renders
 * the confirmation and answers it. Nothing else in the client holds an "are you sure" of its own.
 *
 * **Why this is a store rather than a component field.** Every programmatic navigation in this
 * client is `Router.navigateByUrl`, and Angular runs the departing route's `CanDeactivateFn`
 * inside that call -- so one guard answers for every caller: the rail, the side bar, the locator
 * bar, the command box, the header, the fault banner, the data table, Home, the audit page, and
 * the agent's own navigation tool when it lands, because it will call the same method. The guard
 * runs in an injection context with no component to reach, and the answer has to outlive the
 * component's own change detection, so the flag lives here (AD-19: screen state is a store).
 *
 * **A refusal is an ordinary answer, not an error.** `requestLeave()` resolves `false` when the
 * operator declines, `navigateByUrl`'s own promise resolves `false`, and the route does not
 * change. An agent navigation that waits on that promise hears the refusal as a tool result and
 * withdraws its announcement (AD-11 rule 3).
 *
 * Framework-free, like the rest of `core/`: a plain subscribable that components mirror into a
 * signal, executable under `node --test`.
 */

/** What a form registers so the guard can ask it. */
export type LeavePrompt = () => Promise<boolean>;

export class FormDirty {
  private dirtyValue = false;

  private pendingValue = false;

  private resolvePending: ((leave: boolean) => void) | null = null;

  private readonly listeners = new Set<() => void>();

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** Whether the open form holds a change the instance has not been told about. */
  dirty(): boolean {
    return this.dirtyValue;
  }

  /** Whether the confirmation is on screen, waiting for an answer. */
  pending(): boolean {
    return this.pendingValue;
  }

  /**
   * Mark the open form dirty or clean. Idempotent, so a keystroke on an already-dirty form
   * notifies nobody and a component mirroring this does not re-render per character.
   */
  setDirty(dirty: boolean): void {
    if (this.dirtyValue === dirty) return;
    this.dirtyValue = dirty;
    this.notify();
  }

  /**
   * The guard's question: may this navigation proceed?
   *
   * A clean form resolves `true` at once and shows nothing -- the confirmation is for unsaved
   * work, and a dialog on every navigation would be a dialog nobody reads. A dirty form raises
   * the confirmation and resolves when `answer()` is called.
   *
   * **A second question while one is pending resolves `false` rather than replacing it.** Two
   * confirmations for one form is a stack, which this product does not have (EXPERIENCE.md's
   * "Dialogs never stack"), and the second navigation is refused rather than silently answered by
   * the first one's button.
   */
  requestLeave(): Promise<boolean> {
    if (!this.dirtyValue) return Promise.resolve(true);
    if (this.pendingValue) return Promise.resolve(false);
    this.pendingValue = true;
    this.notify();
    return new Promise<boolean>((resolve) => {
      this.resolvePending = resolve;
    });
  }

  /**
   * The operator's answer. Accepting clears the dirty flag, because the work is being abandoned
   * and the next form to open must not inherit it; declining leaves it exactly where it was.
   *
   * Idempotent: a dialog that emits its close on both the button and the scrim must not resolve
   * one question twice.
   */
  answer(leave: boolean): void {
    if (!this.pendingValue) return;
    this.pendingValue = false;
    const resolve = this.resolvePending;
    this.resolvePending = null;
    if (leave) this.dirtyValue = false;
    this.notify();
    resolve?.(leave);
  }

  /**
   * Forget everything, and refuse any question still open.
   *
   * Called when a form is destroyed and from the sign-out teardown: a dirty flag left standing
   * would make the next route refuse to leave a form nobody is editing, and a promise left
   * unresolved would hang the `navigateByUrl` that is waiting on it. The pending question is
   * answered `false`, which is the safe direction -- the navigation is refused rather than a route
   * changing under a principal who has just gone.
   */
  reset(): void {
    const resolve = this.resolvePending;
    this.resolvePending = null;
    this.dirtyValue = false;
    this.pendingValue = false;
    this.notify();
    resolve?.(false);
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

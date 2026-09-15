/**
 * The one authority over Escape (EXPERIENCE.md "panel, command-box, side-bar": "close the topmost overlay, else
 * return focus to the screen").
 *
 * Every dismissible surface in the shell -- the command box, the account menu, the side bar,
 * and Epic 5's panel -- registers here while it is open and unregisters when it closes. A
 * single Escape handler asks this stack to close the topmost member, so the order is decided
 * in one framework-free place rather than by whichever component's key handler happens to
 * see the event first.
 *
 * **Why it is not a one-line side-bar edit (DW-137).** Escape has to reach the side bar when
 * nothing is over it, and must not reach it when something is. Two independent handlers
 * cannot express that: each only knows about itself, so an Escape with a menu open would
 * close the menu *and* collapse the bar. A stack is the smallest thing that gets both rows of
 * the matrix right.
 *
 * **The side bar is the bottom-most member**, structurally rather than by luck: it pushes at
 * `'bottom'`, so a bar that opens while the command box is already open still sits under it.
 *
 * `closeTop()` removes the entry *before* calling its close callback, so a callback that
 * forgets to unregister cannot wedge the stack, and an unregister that arrives afterwards is
 * a no-op.
 *
 * Framework-free, like the rest of `core/`, so `node --test` executes it.
 */

/** Where a member enters the stack. Everything but the side bar pushes at the top. */
export type OverlayPosition = 'top' | 'bottom';

interface OverlayEntry {
  readonly id: string;
  readonly close: () => void;
}

export class OverlayStack {
  private entries: OverlayEntry[] = [];

  private readonly listeners = new Set<() => void>();

  /**
   * Register `id`, or move an already-registered id to `position`. Registering twice is
   * idempotent rather than an error: a component re-registering after a re-render must not
   * leave a second entry only Escape can find.
   */
  push(id: string, close: () => void, position: OverlayPosition = 'top'): void {
    this.entries = this.entries.filter((entry) => entry.id !== id);
    const entry: OverlayEntry = { id, close };
    if (position === 'bottom') this.entries.unshift(entry);
    else this.entries.push(entry);
    this.notify();
  }

  /** Unregister `id`. Unknown ids are ignored, so a close path may call this unconditionally. */
  remove(id: string): void {
    const before = this.entries.length;
    this.entries = this.entries.filter((entry) => entry.id !== id);
    if (this.entries.length !== before) this.notify();
  }

  /** The topmost member's id, or `''` when nothing is open. */
  top(): string {
    const last = this.entries[this.entries.length - 1];
    return last === undefined ? '' : last.id;
  }

  /** Every registered id, bottom first. Exposed so a test can assert the order itself. */
  ids(): readonly string[] {
    return this.entries.map((entry) => entry.id);
  }

  /**
   * Close the topmost member and report whether there was one. `false` is what tells the
   * Escape handler that nothing was open and focus belongs back in the content area.
   */
  closeTop(): boolean {
    const entry = this.entries[this.entries.length - 1];
    if (entry === undefined) return false;
    this.entries = this.entries.slice(0, -1);
    this.notify();
    entry.close();
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

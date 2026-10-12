/**
 * Long blocks in the agent panel (Story 20.17): the estimate that decides whether a block starts
 * collapsed, the id of its region, and the framework-free store that remembers which blocks a
 * person opened (AD-19).
 */

/** A block estimated at more lines than this starts collapsed. */
export const LONG_BLOCK_LINES = 8;

/** The width, in characters, one estimated line holds. */
export const LONG_BLOCK_WIDTH = 80;

/**
 * The estimated line count of `text`: each `\n`-separated line counts `max(1, ceil(length / 80))`.
 * Derived from the content alone, because the test environment computes no layout.
 */
export function estimateLines(text: string): number {
  let total = 0;
  for (const line of text.split('\n')) {
    total += Math.max(1, Math.ceil(line.length / LONG_BLOCK_WIDTH));
  }
  return total;
}

/** Whether an estimated line count is long enough to collapse. */
export function isLong(lines: number): boolean {
  return lines > LONG_BLOCK_LINES;
}

/** The region id for a block key: the key with every character outside `[A-Za-z0-9_-]` turned into `_`. */
export function blockId(key: string): string {
  return `ocu-long-block-${key.replace(/[^A-Za-z0-9_-]/g, '_')}`;
}

/**
 * The blocks a person has opened, by key, for as long as the conversation lasts. An empty key is
 * never stored: a block without a stable key keeps its state in its component.
 */
export class LongBlocks {
  private readonly open = new Set<string>();
  private readonly listeners = new Set<() => void>();

  isOpen(key: string): boolean {
    return key !== '' && this.open.has(key);
  }

  setOpen(key: string, open: boolean): void {
    if (key === '' || this.open.has(key) === open) return;
    if (open) this.open.add(key);
    else this.open.delete(key);
    this.notify();
  }

  /** Registers `listener` for every change; the returned function releases it. */
  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** Forgets every opened block (sign-out). */
  endSession(): void {
    if (this.open.size === 0) return;
    this.open.clear();
    this.notify();
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

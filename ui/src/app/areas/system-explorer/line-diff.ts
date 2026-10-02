/**
 * A line diff of two texts (Story 19.4's Compare), computed in the browser by the project's own
 * code: no diff library.
 *
 * **Framework-free.** It imports nothing, so `line-diff.spec.ts` drives it directly.
 *
 * `lineDiff` trims the lines both texts share at the head and the tail, then runs Myers' O(ND)
 * algorithm on the middle, keeping the trace of each step so the edit script can be walked back.
 * The trace holds at most about D squared integers, so `maxEdits` bounds both the time and the
 * memory: past it the answer is `null` and nothing is drawn.
 */

/** What one line of the edit script is. */
export type DiffKind = 'same' | 'removed' | 'added';

/** One line of the edit script: its kind, its 1-based number on each side it is on, and its text. */
export interface DiffLine {
  readonly kind: DiffKind;
  readonly left?: number;
  readonly right?: number;
  readonly text: string;
}

/** A run of the script `hunks` keeps, or a run of unchanged lines it collapses to a count. */
export type DiffSegment =
  | { readonly kind: 'lines'; readonly lines: readonly DiffLine[] }
  | { readonly kind: 'collapsed'; readonly count: number };

/** The most edits `lineDiff` computes by default. */
export const MAX_EDITS = 1000;

/** The unchanged lines `hunks` keeps beside each change by default. */
export const CONTEXT_LINES = 3;

function same(leftIndex: number, rightIndex: number, text: string): DiffLine {
  return { kind: 'same', left: leftIndex + 1, right: rightIndex + 1, text };
}

/**
 * The edit script turning `left` into `right`, line by line, in order: each line of `left` once as
 * `same` or `removed`, and each line of `right` once as `same` or `added`, a removal before the
 * addition that replaces it. `null` when the two differ by more than `maxEdits` added and removed
 * lines.
 */
export function lineDiff(left: readonly string[], right: readonly string[], maxEdits: number = MAX_EDITS): DiffLine[] | null {
  let head = 0;
  while (head < left.length && head < right.length && left[head] === right[head]) head += 1;
  let tail = 0;
  while (
    tail < left.length - head &&
    tail < right.length - head &&
    left[left.length - 1 - tail] === right[right.length - 1 - tail]
  ) {
    tail += 1;
  }
  const middle = myers(left.slice(head, left.length - tail), right.slice(head, right.length - tail), maxEdits);
  if (middle === null) return null;
  const script: DiffLine[] = [];
  for (let index = 0; index < head; index += 1) script.push(same(index, index, left[index]));
  for (const line of middle) {
    script.push({
      kind: line.kind,
      ...(line.left === undefined ? {} : { left: line.left + head }),
      ...(line.right === undefined ? {} : { right: line.right + head }),
      text: line.text,
    });
  }
  for (let index = tail; index > 0; index -= 1) {
    script.push(same(left.length - index, right.length - index, left[left.length - index]));
  }
  return script;
}

/**
 * Myers' greedy algorithm over `a` and `b`, answering the script with line numbers counted within
 * them, or `null` past `maxEdits`. Each step's furthest-reaching x per diagonal is kept, over the
 * diagonals that step can read, so the walk back from the end can find each step's predecessor.
 */
function myers(a: readonly string[], b: readonly string[], maxEdits: number): DiffLine[] | null {
  const n = a.length;
  const m = b.length;
  if (n === 0 && m === 0) return [];
  const limit = Math.min(n + m, Math.max(0, Math.floor(maxEdits)));
  const offset = limit + 1;
  const v = new Int32Array(2 * limit + 3);
  const trace: Int32Array[] = [];
  for (let d = 0; d <= limit; d += 1) {
    trace.push(v.slice(offset - d - 1, offset + d + 2));
    for (let k = -d; k <= d; k += 2) {
      let x = k === -d || (k !== d && v[offset + k - 1] < v[offset + k + 1]) ? v[offset + k + 1] : v[offset + k - 1] + 1;
      let y = x - k;
      while (x < n && y < m && a[x] === b[y]) {
        x += 1;
        y += 1;
      }
      v[offset + k] = x;
      if (x >= n && y >= m) return walkBack(trace, a, b);
    }
  }
  return null;
}

/** The script `trace` leads to, walked back from the end of `a` and `b`. */
function walkBack(trace: readonly Int32Array[], a: readonly string[], b: readonly string[]): DiffLine[] {
  const reversed: DiffLine[] = [];
  let x = a.length;
  let y = b.length;
  for (let d = trace.length - 1; d >= 0; d -= 1) {
    const step = trace[d];
    // `step` holds diagonals -d-1 to d+1.
    const at = (k: number): number => step[k + d + 1];
    const k = x - y;
    const previousK = k === -d || (k !== d && at(k - 1) < at(k + 1)) ? k + 1 : k - 1;
    const previousX = at(previousK);
    const previousY = previousX - previousK;
    while (x > previousX && y > previousY) {
      x -= 1;
      y -= 1;
      reversed.push(same(x, y, a[x]));
    }
    if (d > 0) {
      if (x === previousX) {
        y -= 1;
        reversed.push({ kind: 'added', right: y + 1, text: b[y] });
      } else {
        x -= 1;
        reversed.push({ kind: 'removed', left: x + 1, text: a[x] });
      }
    }
  }
  return reversed.reverse();
}

/**
 * `script` with every run of unchanged lines longer than the context it needs collapsed to a count:
 * a run between two changes keeps `context` lines after the first and before the second, the run
 * before the first change keeps its last `context`, and the run after the last change its first
 * `context`. A script with no change is one collapsed run.
 */
export function hunks(script: readonly DiffLine[], context: number = CONTEXT_LINES): DiffSegment[] {
  const segments: DiffSegment[] = [];
  let lines: DiffLine[] = [];
  const flush = (): void => {
    if (lines.length > 0) segments.push({ kind: 'lines', lines });
    lines = [];
  };
  let index = 0;
  while (index < script.length) {
    if (script[index].kind !== 'same') {
      lines.push(script[index]);
      index += 1;
      continue;
    }
    let end = index;
    while (end < script.length && script[end].kind === 'same') end += 1;
    const run = script.slice(index, end);
    const first = index === 0;
    const last = end === script.length;
    const keepBefore = first ? 0 : context;
    const keepAfter = last ? 0 : context;
    if (run.length <= keepBefore + keepAfter) {
      lines.push(...run);
    } else {
      lines.push(...run.slice(0, keepBefore));
      flush();
      segments.push({ kind: 'collapsed', count: run.length - keepBefore - keepAfter });
      lines.push(...run.slice(run.length - keepAfter));
    }
    index = end;
  }
  flush();
  return segments;
}

/** How many lines `script` removes and adds. */
export function changeCounts(script: readonly DiffLine[]): { readonly removed: number; readonly added: number } {
  let removed = 0;
  let added = 0;
  for (const line of script) {
    if (line.kind === 'removed') removed += 1;
    if (line.kind === 'added') added += 1;
  }
  return { removed, added };
}

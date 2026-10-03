/**
 * System Explorer's Compare state (AD-19, Story 19.4): each side's namespace and document, and what
 * the last compare answered -- a diff, the two documents identical, too many changes to draw, or a
 * side the instance refused.
 *
 * **Framework-free.** It imports nothing from Angular. The page hands `compare` the one read a side
 * needs; that read is the class or routine viewer's declared read (`createSourceRead`), issued in
 * the side's own namespace, so each side passes that viewer's gate there. The diff is this browser's
 * (`line-diff.ts`); the instance computes none.
 */

import type { ChangeEvent } from '../../core/change-bus';
import { MAX_EDITS, changeCounts, hunks, lineDiff, type DiffSegment } from './line-diff';

/** Which of the two documents. */
export type CompareSideKey = 'left' | 'right';

/** One side: the namespace it is read in and the document's name. */
export interface CompareSide {
  readonly namespace: string;
  readonly name: string;
}

/** What one side's read answered: the document's text, or the instance's refusal and its reason. */
export type SideAnswer = { readonly kind: 'text'; readonly text: string } | { readonly kind: 'refused'; readonly reason: string };

/** What the last compare answered. */
export type CompareOutcome =
  | { readonly kind: 'idle' }
  | { readonly kind: 'running' }
  | { readonly kind: 'refused'; readonly side: CompareSideKey; readonly name: string; readonly reason: string }
  | { readonly kind: 'identical' }
  | { readonly kind: 'too-large' }
  | { readonly kind: 'diff'; readonly segments: readonly DiffSegment[]; readonly removed: number; readonly added: number };

/** The Compare screen's route, and the query parameter a link to it prefills the first document from. */
export const COMPARE_ROUTE = 'system-explorer/compare';

export const LEFT_QUERY = 'left';

/** The entity type document `name` is: a class for `.cls`, a routine otherwise (AD-14). */
export function documentKind(name: string): 'class' | 'routine' {
  return name.trim().toLowerCase().endsWith('.cls') ? 'class' : 'routine';
}

export class CodeCompareState {
  private sides: Record<CompareSideKey, CompareSide> = { left: { namespace: '', name: '' }, right: { namespace: '', name: '' } };

  private outcomeValue: CompareOutcome = { kind: 'idle' };

  /** The sides the last compare read, so a change event can be matched to them. */
  private compared: Record<CompareSideKey, CompareSide> | null = null;

  /** Bumped per compare, so an answer a later compare overtook writes nothing. */
  private generation = 0;

  private readonly listeners = new Set<() => void>();

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  side(key: CompareSideKey): CompareSide {
    return this.sides[key];
  }

  /** Set a side's namespace where it has none yet: the screen's own, once the scope resolves. */
  defaultNamespace(namespace: string): void {
    let changed = false;
    for (const key of ['left', 'right'] as const) {
      if (this.sides[key].namespace !== '') continue;
      this.sides[key] = { ...this.sides[key], namespace };
      changed = true;
    }
    if (changed) this.notify();
  }

  setNamespace(key: CompareSideKey, namespace: string): void {
    this.sides[key] = { ...this.sides[key], namespace };
    this.notify();
  }

  setName(key: CompareSideKey, name: string): void {
    this.sides[key] = { ...this.sides[key], name };
    this.notify();
  }

  outcome(): CompareOutcome {
    return this.outcomeValue;
  }

  /** Whether both sides name a namespace and a document, so Compare can send. */
  ready(): boolean {
    return (['left', 'right'] as const).every((key) => this.sides[key].namespace !== '' && this.sides[key].name.trim() !== '');
  }

  /**
   * Read both sides through `read`, then diff them: a refused side answers that side's reason and
   * draws nothing; otherwise the two are identical, too far apart to draw, or a diff in hunks.
   * Answers false, reading nothing, while a side is incomplete.
   */
  async compare(read: (side: CompareSide) => Promise<SideAnswer>): Promise<boolean> {
    if (!this.ready()) return false;
    return this.run({ left: { ...this.sides.left, name: this.sides.left.name.trim() }, right: { ...this.sides.right, name: this.sides.right.name.trim() } }, read);
  }

  /**
   * Read the last compare's sides again, leaving the form as the person has it and the last answer
   * drawn until the new one lands (AD-14).
   */
  async recompare(read: (side: CompareSide) => Promise<SideAnswer>): Promise<boolean> {
    if (this.compared === null) return false;
    return this.run({ left: { ...this.compared.left }, right: { ...this.compared.right } }, read, true);
  }

  private async run(sides: Record<CompareSideKey, CompareSide>, read: (side: CompareSide) => Promise<SideAnswer>, inPlace = false): Promise<boolean> {
    const generation = (this.generation += 1);
    this.compared = sides;
    if (!inPlace) {
      this.outcomeValue = { kind: 'running' };
      this.notify();
    }
    const [left, right] = await Promise.all([read(sides.left), read(sides.right)]);
    if (generation !== this.generation) return true;
    if (left.kind === 'refused') {
      this.settle({ kind: 'refused', side: 'left', name: sides.left.name, reason: left.reason });
      return true;
    }
    if (right.kind === 'refused') {
      this.settle({ kind: 'refused', side: 'right', name: sides.right.name, reason: right.reason });
      return true;
    }
    this.settle(compareTexts(left.text, right.text));
    return true;
  }

  /**
   * Whether `event` is a change to a document the last compare read (AD-14): its namespace and type,
   * and a name its id carries, alone or in a comma-separated set (AD-13).
   */
  names(event: ChangeEvent): boolean {
    if (event.kind !== 'changed' || this.compared === null) return false;
    const ids = event.id.split(',');
    return (['left', 'right'] as const).some((key) => {
      const side = this.compared?.[key];
      return side !== undefined && event.scope === side.namespace && event.type === documentKind(side.name) && ids.includes(side.name);
    });
  }

  private settle(outcome: CompareOutcome): void {
    this.outcomeValue = outcome;
    this.notify();
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

/** The outcome of comparing two texts, line by line. */
export function compareTexts(left: string, right: string): CompareOutcome {
  if (left === right) return { kind: 'identical' };
  const script = lineDiff(left.split('\n'), right.split('\n'), MAX_EDITS);
  if (script === null) return { kind: 'too-large' };
  const counts = changeCounts(script);
  return { kind: 'diff', segments: hunks(script), removed: counts.removed, added: counts.added };
}

/**
 * The one client-side bus (AD-14, AD-43), built before there is a publisher.
 *
 * Three events travel on it, all routed on the same AD-13 triple `(entity type, scope, id)`:
 *
 * - `changed` -- a confirmed write, or a screen editor's own Save, landed on that entity. A
 *   screen showing the type **re-fetches in place and never patches its own rows** (AD-14).
 * - `proposal-open` -- a proposal against that entity is live, and carries the moment it expires
 *   (AD-6). A screen showing the type pauses its auto-refresh so the diff under review cannot
 *   move (AD-43).
 * - `proposal-closed` -- that proposal was confirmed, cancelled, expired, cancelled as a
 *   sibling (AD-34) or died with its turn (AD-40). Every one of those is the same event here,
 *   because the pause resumes on all five.
 *
 * **Nothing publishes yet.** Epic 2's writes publish `changed`; Epic 5's proposal lifecycle
 * publishes the other two. The bus ships now because the pause AD-43 describes has nothing to
 * ride on otherwise, and because a channel invented per publisher is how two slices end up
 * naming one entity two ways.
 *
 * **The triple is validated, never re-derived.** `entityRefKey` already owns what a reference is
 * -- a type from the kernel's closed enum, a non-empty scope and id -- so an event that is not
 * one is dropped here rather than reaching a subscriber that would have to check again.
 *
 * Framework-free, like the rest of `core/`, so `ui/tools/change-bus.test.mjs` executes it under
 * `node --test`.
 */

import { entityRefKey } from './entity-ref.ts';

export type ChangeEventKind = 'changed' | 'proposal-open' | 'proposal-closed';

/** AD-6's server-side constant, mirrored for the one case below where nothing else can supply it. */
export const PROPOSAL_EXPIRY_MS = 10 * 60 * 1000;

/** One event, already routed: the triple, the kind, and what the proposal kinds add. */
export interface ChangeEvent {
  readonly kind: ChangeEventKind;
  readonly type: string;
  readonly scope: string;
  readonly id: string;
  /** The reference key of the triple, so a subscriber matches on a value rather than three. */
  readonly key: string;
  /** The proposal this is about; `''` for `changed`. */
  readonly proposalId: string;
  /**
   * When the proposal stops being live, in epoch milliseconds; `0` for `changed` and for
   * `proposal-closed`.
   */
  readonly expiresAt: number;
}

/** What a publisher supplies. Everything the bus can work out for itself is optional. */
export interface ChangeEventInput {
  readonly kind: ChangeEventKind;
  readonly type: string;
  readonly scope: string;
  readonly id: string;
  readonly proposalId?: string;
  readonly expiresAt?: number;
}

export interface ChangeBusOptions {
  /** Injected so a test drives expiry without waiting on a clock. Defaults to `Date`. */
  readonly now?: () => Date;
}

export class ChangeBus {
  private readonly now: () => Date;
  private readonly listeners = new Set<(event: ChangeEvent) => void>();

  constructor(options: ChangeBusOptions = {}) {
    this.now = options.now ?? (() => new Date());
  }

  subscribe(listener: (event: ChangeEvent) => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /**
   * Publish one event, and report whether it was one.
   *
   * **A `proposal-open` with no `expiresAt` is given AD-6's ten minutes rather than none.** A
   * proposal that never expires is a pause that never lifts, which is precisely the shape Story
   * 1.13 kept producing -- a recovery path whose only trigger was the event that had already
   * happened. A publisher that knows the server's own expiry sends it and this default never
   * applies; one that does not still cannot strand a screen.
   *
   * **A `proposal-closed` with no id closes nothing.** The pause is held by a *set* of proposal
   * ids (two opens and one close stays paused), so an anonymous close cannot say which one it
   * ends and is refused rather than guessed at.
   *
   * **An expiry that is not a moment within AD-6's ten minutes is replaced by one that is.** The
   * subscriber arms a timer for `expiresAt - now`, so a `NaN` or an out-of-range value becomes a
   * delay that fires immediately against a deadline the sweep can never pass -- a re-arm loop
   * that never lifts the pause and never stops running. Clamping is not defensive tidying: ten
   * minutes is the value AD-6 gives a proposal, so no honest publisher sends more.
   */
  publish(input: ChangeEventInput): boolean {
    const key = entityRefKey(input.type, input.scope, input.id);
    if (key === null) return false;
    const proposalId = input.proposalId ?? '';
    if (input.kind !== 'changed' && proposalId === '') return false;
    const expiresAt = input.kind === 'proposal-open' ? this.expiryFor(input.expiresAt) : 0;
    const event: ChangeEvent = {
      kind: input.kind,
      type: input.type,
      scope: input.scope,
      id: input.id,
      key,
      proposalId,
      expiresAt,
    };
    // A copy, so a subscriber that unsubscribes from inside its own handler -- a screen being
    // torn down by the very re-fetch it was told about -- does not mutate the set being walked.
    for (const listener of [...this.listeners]) listener(event);
    return true;
  }

  /** The supplied expiry if it is a real moment no later than AD-6 allows; otherwise AD-6's own. */
  private expiryFor(supplied: number | undefined): number {
    const ceiling = this.now().getTime() + PROPOSAL_EXPIRY_MS;
    if (supplied === undefined || !Number.isFinite(supplied)) return ceiling;
    return Math.min(supplied, ceiling);
  }
}

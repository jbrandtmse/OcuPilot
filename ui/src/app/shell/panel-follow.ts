/**
 * Whether the panel's transcript follows the conversation (Story 11.10, EXPERIENCE.md panel Body).
 *
 * The transcript is **at its newest entry** when `scrollHeight - scrollTop - clientHeight` is at most
 * `FOLLOW_TOLERANCE_PX`, which absorbs sub-pixel rounding at browser zoom. While following, a render
 * that grows the transcript scrolls it to the newest entry; an accepted send, New conversation and
 * Jump to latest turn following on and scroll there.
 *
 * **Only a scroll the user makes away from the newest entry turns following off.** While the panel's
 * own scroll is in flight it only moves the position toward the newest entry, so a scroll event that
 * did not move the position up -- a smooth scroll's intermediate positions among them -- leaves
 * following on. Once no own scroll is in flight, any scroll event that does not end at the newest
 * entry is the user's. Content growing under a scrolled-up transcript fires no scroll event and
 * moves nothing. A wheel turned up while the own scroll is in flight stops it (`onWheelUp`).
 *
 * The panel's own scroll sets `scrollTop` and passes no `behavior`: whether it animates is the
 * transcript's CSS `scroll-behavior`, which reduced motion sets to `auto`.
 *
 * No Angular dependency, so `panel-follow.spec.ts` drives it over a fake element.
 */

/** How far from the bottom, in CSS px, still counts as at the newest entry. */
export const FOLLOW_TOLERANCE_PX = 4;

/** The three geometry members the follow rule reads, and the one it writes. */
export interface ScrollBox {
  scrollTop: number;
  readonly scrollHeight: number;
  readonly clientHeight: number;
}

/** Whether `box` is at its newest entry. */
export function atNewest(box: ScrollBox): boolean {
  return box.scrollHeight - box.scrollTop - box.clientHeight <= FOLLOW_TOLERANCE_PX;
}

/** The `scrollTop` of `box`'s newest entry. */
function newestTop(box: ScrollBox): number {
  return Math.max(0, box.scrollHeight - box.clientHeight);
}

export class TranscriptFollow {
  private followingNow = true;

  /** The `scrollTop` the last scroll event reported, or the panel's own scroll started from. */
  private lastTop = 0;

  /** Whether the panel's own scroll is on its way to the newest entry and has not reached it. */
  private inFlight = false;

  /** The newest entry's `scrollTop` at the last render, so a render can tell the transcript grew. */
  private lastNewest = 0;

  /** Whether the transcript follows the conversation. */
  get following(): boolean {
    return this.followingNow;
  }

  /**
   * A scroll event on the transcript. Answers whether `following` changed, so the caller re-renders
   * only when the control's visibility does.
   */
  onScroll(box: ScrollBox): boolean {
    const top = box.scrollTop;
    const previous = this.lastTop;
    this.lastTop = top;
    const before = this.followingNow;
    if (atNewest(box)) {
      this.followingNow = true;
      this.inFlight = false;
    } else if (!this.inFlight || top < previous) {
      this.followingNow = false;
      this.inFlight = false;
    }
    return before !== this.followingNow;
  }

  /**
   * The user turns the wheel up over the transcript. A browser can carry the panel's own smooth
   * scroll on over the wheel, to the newest entry, so while it is in flight it is stopped where it
   * stands, and following turns off unless that is the newest entry. Answers whether `following`
   * changed.
   */
  onWheelUp(box: ScrollBox): boolean {
    if (!this.inFlight) return false;
    this.inFlight = false;
    const top = box.scrollTop;
    this.lastTop = top;
    box.scrollTop = top;
    if (atNewest(box)) return false;
    this.followingNow = false;
    return true;
  }

  /**
   * After a render: while following, when the transcript grew and is not at its newest entry,
   * scroll there. Answers whether it scrolled.
   */
  settle(box: ScrollBox): boolean {
    const newest = newestTop(box);
    const grew = newest > this.lastNewest;
    this.lastNewest = newest;
    if (!this.followingNow || !grew || atNewest(box)) return false;
    this.toNewest(box);
    return true;
  }

  /** Turn following on and scroll to the newest entry: an accepted send, New conversation, Jump to latest. */
  follow(box: ScrollBox | null): void {
    this.followingNow = true;
    if (box === null) return;
    this.lastNewest = newestTop(box);
    this.toNewest(box);
  }

  private toNewest(box: ScrollBox): void {
    this.lastTop = box.scrollTop;
    this.inFlight = true;
    box.scrollTop = newestTop(box);
  }
}

import { Injectable, inject } from '@angular/core';
import { Router } from '@angular/router';

import { type Citation, citationPresence, citationScreen, type CitationPresence } from '../core/citations';
import { entityUrl, screenForUrl } from '../core/navigation';
import { ScreenStores } from '../core/screen-store';

/**
 * Opens the row a citation chip names (Story 11.4, AD-11 rule 3, AD-37).
 *
 * **One navigation.** The URL is `entityUrl`'s, the navigation tool's own builder, for a route
 * `citationScreen` accepts, and the move is `Router.navigateByUrl` -- so the unsaved-changes
 * guard answers a chip exactly as it answers any other click, and a declined move does nothing.
 * The arriving list selects the row from its own route id (AD-14). A click is the user's own, so
 * nothing announces it.
 *
 * **Presence is the arriving screen's own read.** Once the move resolves, this waits for that
 * screen's store to hold a read made after the move began (or the one it already holds, when the
 * user was on that screen) and asks `citationPresence`. An absent row is recorded against the
 * citation, which the panel shows as "no longer present" under that turn's reply; a present row
 * clears it, and an unknown answer changes nothing. Each `open` releases the check an earlier one
 * left waiting.
 */
@Injectable({ providedIn: 'root' })
export class CitationNavigator {
  private readonly router = inject(Router);
  private readonly stores = inject(ScreenStores);

  private readonly listeners = new Set<() => void>();

  /** The citations whose row was found absent on their last open. */
  private readonly absentSet = new WeakSet<Citation>();

  /** Releases the presence check the latest `open` left waiting, if any. */
  private release: () => void = () => {};

  /** Bumped by each `open`, so a move that resolves after a newer one began settles nothing. */
  private generation = 0;

  /** Whether `citation`'s row was absent when it was last opened. */
  isAbsent(citation: Citation): boolean {
    return this.absentSet.has(citation);
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** Open `citation`'s row, then record whether it is still there. */
  async open(citation: Citation): Promise<void> {
    this.release();
    this.release = () => {};
    const generation = ++this.generation;
    const screen = citationScreen(citation.route);
    if (screen === null) return;
    const store = this.stores.for(screen.descriptor, screen.refreshRates);
    const alreadyHere = screenForUrl(this.router.url)?.descriptor === screen.descriptor;
    const before = store.lastUpdate();
    const url = entityUrl(citation.route, citation.id, citation.scope, this.router.url);
    const navigated = await this.router.navigateByUrl(url).catch(() => false);
    // A click on the row already open is a navigation the router ignores; the user is there all
    // the same, so the presence rule still runs. A declined move leaves the URL where it was.
    if (generation !== this.generation || (navigated !== true && this.router.url !== url)) return;
    const decide = (): boolean => {
      const at = store.lastUpdate();
      if (at === null || (!alreadyHere && at === before)) return false;
      this.settle(citation, citationPresence(store.data(), store.truncated(), screen, citation.id));
      return true;
    };
    if (decide()) return;
    const stop = store.subscribe(() => {
      if (!decide()) return;
      stop();
      this.release = () => {};
    });
    this.release = stop;
  }

  private settle(citation: Citation, presence: CitationPresence): void {
    if (presence === 'unknown') return;
    const wasAbsent = this.absentSet.has(citation);
    if (presence === 'absent') this.absentSet.add(citation);
    else this.absentSet.delete(citation);
    if (wasAbsent === (presence === 'absent')) return;
    for (const listener of [...this.listeners]) listener();
  }
}

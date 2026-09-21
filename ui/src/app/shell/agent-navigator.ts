import { DestroyRef, Injectable, inject } from '@angular/core';
import { Router } from '@angular/router';

import { AuditSearch } from '../areas/logs/audit.store';
import { encodeEntityId } from '../core/entity-id';
import { formatNavigationHeading, screenForRoute, withQuery } from '../core/navigation';
import type { ScreenDeclaration } from '../core/screens.generated';
import { ShellState } from '../core/shell-state';
import { STRINGS, stringFor } from '../core/strings';
import { NAV_REFUSED_UNSAVED_CODE, TurnStore, type TurnNavigation } from '../core/turn';

/**
 * How long the announcement stays alone in the transcript before the browser moves (Story 4.7,
 * AC4: "renders the announcement first and navigates only after `NAVIGATIONDELAYMS`"). Exported
 * so a mutation that deletes it, and a component spec that drives the delay with fake timers,
 * both have a name to act on.
 */
export const NAVIGATIONDELAYMS = 1000;

/**
 * Acts on the server's navigation directive (Story 4.7, AD-11 rule 3). The agent's tool call has
 * already been announced and committed to the transcript by the time anything here runs --
 * `TurnStore.navigation()` exposes a directive only once it is paired with its own `announce`
 * step -- so this owns exactly the browser's half: hold for `NAVIGATIONDELAYMS` after the poll
 * that delivered the directive, move, and answer.
 *
 * **Constructed for its own sake**, in `app.ts`, the way `DefinitionActions` is: nothing else in
 * the tree would ever instantiate it, and it has to live for the tab, not for one component's
 * lifetime, since the panel that renders the announcement is not the thing that has to act on it.
 *
 * **Never `replaceUrl`, never `skipLocationChange`, no undo control of its own.** This calls
 * `Router.navigateByUrl` -- the one method `app.routes.ts`'s own comment says every programmatic
 * navigation in this client already uses -- so the unsaved-changes guard on every `form-page`
 * route (`leaveFormGuard`) answers this navigation exactly as it answers a click on the rail or
 * the locator bar, and Back remains this product's one published undo.
 *
 * **The outcome is the promise's own answer, not a guess about why it resolved that way.**
 * `navigateByUrl` resolves `true` on an ordinary navigation and `false` exactly when a
 * `CanDeactivateFn` declined it -- the only guard on these routes, a dirty form's decline -- so
 * `true` is reported `opened` and `false` is reported `refused` with `NAV_REFUSED_UNSAVED_CODE`,
 * the one code this client is ever the author of on this route (`Api/Turn.cls`'s closed
 * vocabulary refuses any other).
 */
@Injectable({ providedIn: 'root' })
export class AgentNavigator {
  private readonly turn = inject(TurnStore);
  private readonly router = inject(Router);
  private readonly shell = inject(ShellState);
  private readonly audit = inject(AuditSearch);

  /**
   * The directive `seq` already scheduled or acted on for the turn currently in flight, or `0`
   * between turns. `TurnStore` notifies roughly once a second while a turn runs, and a directive
   * stays pending on the server for the whole announce-then-move-then-settle sequence, so several
   * notifications land while one directive is still open -- comparing against this is what keeps
   * them from scheduling a second navigation for it.
   *
   * **Reset to `0` whenever no directive is pending**, not only at construction: `Step.Seq`
   * restarts at 1 for every new turn (`OcuPilot.Kernel.State.Step`'s `TurnSeqIdx` is unique per
   * `TurnKey`, not globally), so a later turn's own navigation can legitimately land on the same
   * numeric `seq` an earlier, already-acted-on turn used. Without the reset, that recurrence would
   * read as `directive.seq === this.activeSeq` and the second navigation would never be scheduled
   * at all -- silently, for the full `NAVWAITSECONDS` server-side wait.
   */
  private activeSeq = 0;

  constructor() {
    const stop = this.turn.subscribe(() => this.check());
    inject(DestroyRef).onDestroy(stop);
  }

  private check(): void {
    const directive = this.turn.navigation();
    if (directive === null) {
      this.activeSeq = 0;
      return;
    }
    if (directive.seq === this.activeSeq) return;
    this.activeSeq = directive.seq;
    setTimeout(() => void this.act(directive), NAVIGATIONDELAYMS);
  }

  /**
   * Move, then answer. `directive.entityId` is appended as one more path segment, encoded the
   * same way the data table's own name-cell link encodes it (AD-13, `encodeEntityId`), so the
   * agent's URL and a click's URL are byte-identical for the same row.
   *
   * **The directive is re-read first.** `NAVIGATIONDELAYMS` elapses between `check()` scheduling
   * this and this running, and a stop, a sign-out or a new turn inside that window ends the
   * directive: the browser must not move for a turn that has already finished with it.
   */
  private async act(directive: TurnNavigation): Promise<void> {
    const standing = this.turn.navigation();
    if (standing === null || standing.seq !== directive.seq) return;
    const target =
      directive.route + (directive.entityId === '' ? '' : '/' + encodeEntityId(directive.entityId));
    const navigated = await this.router.navigateByUrl(withQuery(target, this.router.url)).catch(() => false);
    if (navigated) {
      const screen = screenForRoute(directive.route);
      const title = screen === null ? '' : stringFor(screen.labelKey);
      this.applyCriterion(directive, screen);
      this.shell.announceArrival(
        directive.route,
        formatNavigationHeading(STRINGS.agentNavigationHeadingAnnouncement, title)
      );
      await this.turn.settleNavigation('opened');
    } else {
      await this.turn.settleNavigation('refused', NAV_REFUSED_UNSAVED_CODE);
    }
  }

  /**
   * Apply the directive's criterion on the screen that has just been arrived at (Story 5.8,
   * AD-21), through that screen's own store seam, and run its declared read.
   *
   * **The criterion is a name, and the value is the descriptor's.** The instance refused anything
   * but a flag the target declares before this navigation was ever announced
   * (`NAV.CRITERIONUNKNOWN`), and the store resolves the value from the declaration -- so no
   * caller value reaches a read and `withQuery` stays `ns`-only, which is what keeps a criterion
   * off the URL entirely.
   *
   * **Applied after the move, never before.** The arriving screen is the one whose filter this is;
   * applying it to a screen the browser has not reached would filter a screen nobody asked about,
   * and a guard that then declined the move would leave that filter standing.
   *
   * **The store is the shell's one reach into an area, and deliberately so.** The alternative is a
   * registry every area store registers itself with, which cannot work here: the store that would
   * register is constructed by the page, and the page does not exist until after this navigation.
   * The stores are root-provided for exactly that reason (`AuditSearch`'s own header).
   */
  private applyCriterion(directive: TurnNavigation, screen: ScreenDeclaration | null): void {
    if (directive.criterion === '' || screen === null) return;
    this.audit.openWith(screen, directive.criterion);
  }
}

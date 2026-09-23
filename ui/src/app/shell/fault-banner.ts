import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  computed,
  inject,
  signal,
} from '@angular/core';
import { Router } from '@angular/router';

import { ConnectivityService } from '../core/connectivity';
import { isBannerFault, type Fault } from '../core/fault';
import { NavigationService, firstAllowedScreen, withQuery } from '../core/navigation';
import { ShellState } from '../core/shell-state';
import { STRINGS } from '../core/strings';

/**
 * The `commandAliases` value that names the file this control opens. The descriptor declaring it is
 * the screen, so the shell matches on what the screen says about itself rather than on a route
 * string typed here (AD-5).
 */
const MESSAGES_LOG_ALIAS = 'messages.log';

/**
 * How long, in milliseconds, the strip stays mounted after its fault clears (DW-1155, DW-1189). A
 * fault raised again inside the hold reuses the same strip and controls, with their content
 * updated in place, so a click on Retry or Open messages.log is never lost to a remount and the
 * strip does not flicker while a drained park re-raises.
 */
export const FAULT_CLEAR_HOLD_MS = 1500;

/**
 * The shell's one connectivity banner: a full-width `role="alert"` strip at the top of the
 * shell, carrying the unreachable sentence or the generic server-fault sentence with the
 * controls EXPERIENCE.md publishes beside each ("connectivity probe", "Generic internal").
 *
 * **It is mounted outside both of `app.ts`'s gates, and that is the whole reason it is a
 * component of its own.** The frame -- and with it the status bar -- renders only for a
 * signed-in tab on a verified instance, which is exactly the two states this story is about:
 * the sign-in card, where a submit met an unreachable instance, and the `checking` limbo, where
 * the identity read failed. A banner inside either gate would be absent in both.
 *
 * **Two of the six fault kinds render here, and the other four deliberately do not.** A 403 is
 * an inline refusal beside working data, an install in flight is the signing-in presentation,
 * a 404 has no Epic 1 surface, and a 401 is the sign-in card -- EXPERIENCE.md publishes no
 * banner sentence for any of them, and inventing one is what DW-126 is about.
 *
 * **Open messages.log is gated in place while nothing serves it.** The control is part of the
 * published server-fault copy, so it renders; the screen it opens is Epic 6's, so until a built
 * screen over `log-entry` exists -- and until this user's own `screenVerdict` allows it -- the
 * control is listed, focusable and `aria-disabled="true"`, the same refusal the side bar makes
 * in place. The destination is resolved from the descriptor mirror's own declaration of which
 * file a screen shows (AD-5, AD-14), never from a route string typed here.
 *
 * **`role="alert"` is on the strip, not on the page.** The element is created when the fault
 * appears and removed once it has stayed clear for `FAULT_CLEAR_HOLD_MS`, so the alert fires on
 * the transition rather than re-announcing on every change-detection pass. Inside the hold the strip
 * keeps showing the fault it last showed.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group.
 */
@Component({
  selector: 'app-fault-banner',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `@if (visible) {
    <div class="ocu-fault-banner" role="alert" [attr.data-fault]="kind">
      <p class="ocu-fault-banner-message">{{ message }}</p>
      <span class="ocu-fault-banner-actions">
        <button type="button" class="ocu-button-text" (click)="retry()">
          {{ STRINGS.actionRetry }}
        </button>
        @if (serverFault) {
          <button
            type="button"
            class="ocu-button-text"
            [attr.aria-disabled]="logAriaDisabled"
            (click)="openMessagesLog()"
          >
            {{ STRINGS.actionOpenMessagesLog }}
          </button>
        }
      </span>
    </div>
  }`,
})
export class FaultBanner {
  private readonly connectivity = inject(ConnectivityService);
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);
  private readonly shell = inject(ShellState);

  protected readonly STRINGS = STRINGS;

  /** Mirrors the framework-free connectivity service into the reactive graph (AD-19). */
  private readonly generation = signal(0);

  /**
   * The banner fault the strip shows: the current one, or -- for `FAULT_CLEAR_HOLD_MS` after it
   * clears -- the one it last showed, and `null` once the hold has run out with nothing raised.
   */
  private readonly shown = signal<Fault | null>(null);

  private holdTimer: ReturnType<typeof setTimeout> | null = null;

  private readonly fault = computed(() => this.shown());

  /**
   * The screen that shows `messages.log`, when one is built and this user may open it.
   *
   * Matched on the descriptor's own `messages.log` alias, not merely on `log-entry`: several
   * screens share that entity type, and the first of them is the alerts.log viewer -- so a filter
   * by entity type alone sent the control labelled "Open messages.log" to the wrong file
   * (**DW-148**). The alias is what the descriptor says about which file it shows, which keeps the
   * destination declared rather than typed here (AD-5). While no built screen shows `messages.log`
   * this is `null` and the control is gated -- the published contract rendering correctly, not a
   * missing destination.
   */
  private readonly logScreen = computed(() => {
    this.generation();
    const candidates = this.navigation
      .builtScreens()
      .filter(
        (screen) =>
          screen.entityType === 'log-entry' && screen.commandAliases.includes(MESSAGES_LOG_ALIAS)
      );
    return firstAllowedScreen(candidates, (route) => this.navigation.screenVerdict(route));
  });

  constructor() {
    this.follow();
    const stopConnectivity = this.connectivity.subscribe(() => {
      this.follow();
      this.bump();
    });
    const stopNavigation = this.navigation.subscribe(() => this.bump());
    inject(DestroyRef).onDestroy(() => {
      stopConnectivity();
      stopNavigation();
      this.clearHold();
    });
  }

  protected get visible(): boolean {
    return this.fault() !== null;
  }

  /**
   * Which fault the strip is drawing, published on the element as `data-fault`.
   *
   * Both kinds render the same error pair today and **no stylesheet rule reads this yet** --
   * the variants DESIGN.md `:1201` names are the lead's browser gate (DW-139), not something
   * jsdom can settle. It is emitted now because the sentence is the signal a user reads and
   * this is what a rule, a browser smoke or a later variant hooks on to without re-deriving the
   * kind from the copy.
   */
  protected get kind(): string {
    return this.fault()?.kind ?? '';
  }

  protected get serverFault(): boolean {
    return this.fault()?.kind === 'server-fault';
  }

  protected get message(): string {
    return this.serverFault
      ? STRINGS.connectivityServerFault
      : STRINGS.connectivityBannerUnreachable;
  }

  protected get logAriaDisabled(): string | null {
    return this.logScreen() === null ? 'true' : null;
  }

  /**
   * Probe now rather than waiting out the backoff. Every reader whose read failed is handed its
   * one re-read by the same response that clears this banner, so Retry and "the probe finally
   * answered" are one recovery rather than two that could disagree.
   */
  protected retry(): void {
    this.connectivity.retry();
  }

  /**
   * Open the messages.log screen, carrying the namespace (AD-44). Refused here while no built
   * screen serves it: `aria-disabled` carries no behaviour of its own, so the refusal has to be
   * in the handler -- the shape `side-bar.ts` and `locator-bar.ts` use for the same idea.
   *
   * The Logs side bar is shown on the screen before the navigation, through `ShellState.showArea`
   * and for `locator-bar.ts`'s reason: `ScreenOutlet`'s `setActiveArea` leaves a closed bar
   * closed, so a user who arrived from the banner would land on the log with no idea where in the
   * shell it sits (**DW-148**).
   */
  protected openMessagesLog(): void {
    const screen = this.logScreen();
    if (screen === null) return;
    this.shell.showArea(screen.area);
    void this.router.navigateByUrl(withQuery(screen.route, this.router.url));
  }

  private bump(): void {
    this.generation.set(this.generation() + 1);
  }

  /**
   * Take the connectivity service's current fault. A banner fault is shown at once and ends any
   * hold; anything else starts the hold, unless one is already running, and the strip unmounts
   * when it ends.
   */
  private follow(): void {
    const current = this.connectivity.fault();
    if (isBannerFault(current)) {
      this.clearHold();
      this.shown.set(current);
      return;
    }
    if (this.shown() === null || this.holdTimer !== null) return;
    this.holdTimer = setTimeout(() => {
      this.holdTimer = null;
      this.shown.set(null);
      this.bump();
    }, FAULT_CLEAR_HOLD_MS);
  }

  private clearHold(): void {
    if (this.holdTimer === null) return;
    clearTimeout(this.holdTimer);
    this.holdTimer = null;
  }
}

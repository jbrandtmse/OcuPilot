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
import { isBannerFault } from '../core/fault';
import { NavigationService, firstAllowedScreen, withQuery } from '../core/navigation';
import { STRINGS } from '../core/strings';

/**
 * The shell's one connectivity banner: a full-width `role="alert"` strip at the top of the
 * shell, carrying the unreachable sentence or the generic server-fault sentence with the
 * controls EXPERIENCE.md publishes beside each (`:436`, `:438`).
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
 * in place. The destination is resolved from the descriptor mirror's own entity vocabulary
 * (AD-5, AD-14), never from a route string typed here.
 *
 * **`role="alert"` is on the strip, not on the page.** The element is created when the fault
 * appears and removed when it clears, so the alert fires on the transition rather than
 * re-announcing on every change-detection pass.
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

  protected readonly STRINGS = STRINGS;

  /** Mirrors the framework-free connectivity service into the reactive graph (AD-19). */
  private readonly generation = signal(0);

  private readonly fault = computed(() => {
    this.generation();
    return this.connectivity.fault();
  });

  /**
   * The screen that shows `messages.log`, when one is built and this user may open it.
   *
   * Found by entity type rather than by route: the descriptor is the single source of what a
   * screen is (AD-5), and a route string typed here would be a second one to drift. While no
   * built screen shows `messages.log` this is `null` and the control is gated -- which is the
   * published contract rendering correctly, not a missing destination.
   */
  private readonly logScreen = computed(() => {
    this.generation();
    const candidates = this.navigation
      .builtScreens()
      .filter((screen) => screen.entityType === 'log-entry');
    return firstAllowedScreen(candidates, (route) => this.navigation.screenVerdict(route));
  });

  constructor() {
    const stopConnectivity = this.connectivity.subscribe(() => this.bump());
    const stopNavigation = this.navigation.subscribe(() => this.bump());
    inject(DestroyRef).onDestroy(() => {
      stopConnectivity();
      stopNavigation();
    });
  }

  protected get visible(): boolean {
    return isBannerFault(this.fault());
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
   */
  protected openMessagesLog(): void {
    const screen = this.logScreen();
    if (screen === null) return;
    void this.router.navigateByUrl(withQuery(screen.route, this.router.url));
  }

  private bump(): void {
    this.generation.set(this.generation() + 1);
  }
}

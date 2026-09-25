import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  ElementRef,
  afterNextRender,
  computed,
  inject,
  signal,
  viewChild,
} from '@angular/core';

import { InstanceService, formatVersionMismatch } from '../core/instance';
import { Session, isInstallStateUnreadable } from '../core/session';
import { STRINGS } from '../core/strings';

/** The classic portal's home page (AD-44), the way out of both notices. */
const CLASSIC_PORTAL_HREF = '/csp/sys/UtilHome.csp';

/**
 * The blocking notice the shell renders instead of a screen when the instance is not one
 * OcuPilot can drive (EXPERIENCE.md "Version mismatch", DESIGN.md `:1066`).
 *
 * **One composition, three variants, and none dresses as another.** A version mismatch
 * names the version the instance reported and offers the classic portal; a caller holding
 * no administrative resource is told exactly that; an install state the gate cannot read
 * (DW-96) says waiting will not help and offers one Retry, with no backoff behind it.
 * Presenting any as another is the failure EXPERIENCE.md "No administrative privileges" names outright. `app.ts`
 * renders the third from the session state, ahead of the signed-in gate.
 *
 * **Sign out belongs to the section, and the section renders for every non-ready state.**
 * The account menu is the header's, which renders only once the instance is `ready` -- so
 * this notice is the only exit a held user has. `app.ts` renders
 * it for every instance state but `ready`, which is three states, not two: a `checking`
 * that never settles (`InstanceService.runVerify`'s final branch, reached by any failure
 * the shell cannot explain) has neither variant's sentence to show. Gating the whole
 * composition on "a variant has something to say" therefore stranded that tab signed in on
 * an empty page, the same AD-28 break the `version-mismatch` fix closed one state over
 * (AD-28: signing out is the instance, and a user must always be able to). The variants'
 * sentences stay conditional; the exit does not.
 *
 * **An `empty-state`, not a banner** -- DESIGN.md `:1066` says so, and the precedence rule
 * both UX documents now carry makes DESIGN.md the authority on treatment; EXPERIENCE.md's
 * "(error)" is the colour treatment (DESIGN.md `:1201`) on the empty state, not a second
 * component stacked above it. No icon glyph: DESIGN.md's
 * `empty-state` names an interim Material Symbols glyph, and nothing here may reach an
 * external host for one (NFR-10, AD-47), so the icon arrives with Story 1.10's chrome --
 * the same call `sign-in.ts` made for the reveal toggle.
 *
 * **Every string comes from `STRINGS`.** The mismatch sentence's `<n>` is substituted in
 * TypeScript, never spelled in the template.
 *
 * Every control-flow condition is a paren-free member reference, for the reason
 * `sign-in.ts` records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one
 * parenthesised group, so a call expression in the condition leaves a stray `)` that the
 * literal-text-node rule reports and `npm run build` fails on.
 */
@Component({
  selector: 'app-instance-notice',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<section #surface class="ocu-empty-state" role="alert" tabindex="-1">
      @if (mismatch) {
        <h1 class="ocu-empty-state-notice">{{ mismatchMessage() }}</h1>
        <a
          class="ocu-button-secondary"
          [href]="classicPortalHref"
          target="_blank"
          rel="noreferrer"
        >
          <span>{{ STRINGS.classicLinkCardTitle }}</span>
          <span class="ocu-external-glyph" aria-hidden="true">{{ externalGlyph }}</span>
        </a>
      }
      @if (noPrivileges) {
        <h1 class="ocu-empty-state-notice">{{ STRINGS.authNoAdminPrivileges }}</h1>
      }
      @if (unreadable) {
        <h1 class="ocu-empty-state-notice">{{ STRINGS.authInstallStateUnreadable }}</h1>
        <button type="button" class="ocu-button-secondary" (click)="chooseRetry()">
          {{ STRINGS.actionRetry }}
        </button>
      }
      <button type="button" class="ocu-button-text" (click)="chooseSignOut()">
        {{ STRINGS.actionSignOut }}
      </button>
    </section>`,
})
export class InstanceNotice {
  private readonly instance = inject(InstanceService);
  private readonly session = inject(Session);

  protected readonly STRINGS = STRINGS;

  protected readonly classicPortalHref = CLASSIC_PORTAL_HREF;

  /**
   * The north-east arrow DESIGN.md's external-link action carries, written as its escape so
   * no non-ASCII byte enters a source file (Rule 14). `aria-hidden`, so the link's
   * accessible name is its one string.
   */
  protected readonly externalGlyph = '\u2197';

  /** Mirrors the framework-free instance service into the reactive graph. */
  private readonly instanceStatus = signal(this.instance.status());

  private readonly reportedVersion = signal(this.instance.adminApiVersion());

  /** Mirrors the framework-free session into the reactive graph. */
  private readonly sessionState = signal(this.session.state());

  /**
   * EXPERIENCE.md "Version mismatch"'s sentence with the reported version in place of its `<n>`. Built
   * here rather than in the template: a template that concatenated a number onto a literal
   * would be copy typed into a component, which is what the string source exists to stop.
   */
  protected readonly mismatchMessage = computed(() =>
    formatVersionMismatch(STRINGS.authAdminApiVersionMismatch, this.reportedVersion())
  );

  private readonly surface = viewChild.required<ElementRef<HTMLElement>>('surface');

  constructor() {
    // EXPERIENCE.md "**Focus order.** skip link". This notice does not carry a message within a surface -- it
    // *is* the surface, replacing every screen, and the control the user last touched went
    // with it. `role="alert"` announces the sentence; the focus move is what keeps the
    // keyboard somewhere real, and it lands on the section rather than the heading because
    // an unsettled `checking` renders neither variant's sentence and so has no heading to
    // receive it. `afterNextRender` rather than an effect: the element must exist.
    afterNextRender(() => this.surface().nativeElement.focus());

    const stop = this.instance.subscribe(() => {
      this.instanceStatus.set(this.instance.status());
      this.reportedVersion.set(this.instance.adminApiVersion());
    });
    const stopSession = this.session.subscribe(() => this.sessionState.set(this.session.state()));
    inject(DestroyRef).onDestroy(() => {
      stop();
      stopSession();
    });
  }

  protected get unreadable(): boolean {
    return isInstallStateUnreadable(this.sessionState());
  }

  protected get mismatch(): boolean {
    return !this.unreadable && this.instanceStatus() === 'version-mismatch';
  }

  protected get noPrivileges(): boolean {
    return !this.unreadable && this.instanceStatus() === 'no-privileges';
  }

  /** Re-check the unreadable install state once (DW-96); no timer is armed. */
  protected chooseRetry(): void {
    this.session.retryInstallState();
  }

  /**
   * The same `Session.signOut()` the account menu reaches. Its local half runs
   * synchronously (DW-5), so the tab is already signed out by the time this returns.
   */
  protected chooseSignOut(): void {
    void this.session.signOut();
  }
}

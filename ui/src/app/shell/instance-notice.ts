import { ChangeDetectionStrategy, Component, DestroyRef, computed, inject, signal } from '@angular/core';

import { InstanceService, formatVersionMismatch } from '../core/instance';
import { Session } from '../core/session';
import { STRINGS } from '../core/strings';

/** The classic portal's home page (AD-44), the way out of both notices. */
const CLASSIC_PORTAL_HREF = '/csp/sys/UtilHome.csp';

/**
 * The blocking notice the shell renders instead of a screen when the instance is not one
 * OcuPilot can drive (EXPERIENCE.md `:427-428`, DESIGN.md `:1066`).
 *
 * **One composition, two variants, and neither dresses as the other.** A version mismatch
 * names the version the instance reported and offers the classic portal; a caller holding
 * no administrative resource is told exactly that and offered Sign out. Presenting either
 * as the other is the failure EXPERIENCE.md `:428` names outright.
 *
 * **An `empty-state`, not a banner** -- DESIGN.md `:1066` says so, and is the authority on
 * appearance; EXPERIENCE.md's "(error)" is the colour treatment (DESIGN.md `:1201`) on the
 * empty state, not a second component stacked above it. No icon glyph: DESIGN.md's
 * `empty-state` names an interim Material Symbols glyph, and nothing here may reach an
 * external host for one (NFR-10, AD-47), so the icon arrives with Story 1.10's chrome --
 * the same call `sign-in.ts` made for the reveal toggle.
 *
 * **No new string beyond the mismatch sentence.** `authNoAdminPrivileges`,
 * `actionSignOut` and `classicLinkCardTitle` already exist; the sentence's `<n>` is
 * substituted in TypeScript, never spelled in the template.
 *
 * Every control-flow condition is a paren-free member reference, for the reason
 * `sign-in.ts` records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one
 * parenthesised group, so a call expression in the condition leaves a stray `)` that the
 * literal-text-node rule reports and `npm run build` fails on.
 */
@Component({
  selector: 'app-instance-notice',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `@if (hasNotice) {
      <section class="ocu-empty-state">
        @if (mismatch) {
          <p class="ocu-empty-state-notice">{{ mismatchMessage() }}</p>
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
          <p class="ocu-empty-state-notice">{{ STRINGS.authNoAdminPrivileges }}</p>
          <button type="button" class="ocu-button-text" (click)="chooseSignOut()">
            {{ STRINGS.actionSignOut }}
          </button>
        }
      </section>
    }`,
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

  /**
   * EXPERIENCE.md `:427`'s sentence with the reported version in place of its `<n>`. Built
   * here rather than in the template: a template that concatenated a number onto a literal
   * would be copy typed into a component, which is what the string source exists to stop.
   */
  protected readonly mismatchMessage = computed(() =>
    formatVersionMismatch(STRINGS.authAdminApiVersionMismatch, this.reportedVersion())
  );

  constructor() {
    const stop = this.instance.subscribe(() => {
      this.instanceStatus.set(this.instance.status());
      this.reportedVersion.set(this.instance.adminApiVersion());
    });
    inject(DestroyRef).onDestroy(stop);
  }

  /**
   * Whether either variant has something to say. An unsettled check has neither, and an
   * `empty-state` with nothing in it is still a box the shell draws -- so the component
   * renders no element at all rather than an empty one. The outlet is withheld either way;
   * that gate is `app.ts`'s and does not read this.
   */
  protected get hasNotice(): boolean {
    return this.mismatch || this.noPrivileges;
  }

  protected get mismatch(): boolean {
    return this.instanceStatus() === 'version-mismatch';
  }

  protected get noPrivileges(): boolean {
    return this.instanceStatus() === 'no-privileges';
  }

  /**
   * The same `Session.signOut()` the account menu reaches. Its local half runs
   * synchronously (DW-5), so the tab is already signed out by the time this returns.
   */
  protected chooseSignOut(): void {
    void this.session.signOut();
  }
}

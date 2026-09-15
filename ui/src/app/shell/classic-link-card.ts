import { ChangeDetectionStrategy, Component, input } from '@angular/core';

import type { ScreenDeclaration } from '../core/screens.generated';
import { STRINGS } from '../core/strings';

/**
 * The "More in the classic portal" card a reduced form ends with (FR-9, AD-44; DESIGN.md
 * `:662-671` and `:1096-1098`, EXPERIENCE.md "end of every reduced").
 *
 * **It renders from the descriptor, and only from the descriptor.** A screen carries an
 * outbound classic link exactly when its `classicLinkExemption` is honored -- `exempt` with a
 * declared label and href. `ui/tools/classic-links.mjs` has already refused every other shape
 * by the time a declaration reaches the mirror, because it runs in `prebuild` and in the
 * pre-commit hook; `OcuPilot.Screen.Registry.ClassicLinkProblem` makes the same refusal on the
 * instance, but nothing on the serving path calls `Validate` yet, so the build check is the
 * one that stands between a bad declaration and this component. Over a descriptor with no
 * honored exemption this renders nothing at all: no card, no anchor, so a list screen cannot
 * grow one.
 *
 * **The target is declared, never derived.** `classicPage` is a class name -- the AD-8
 * privilege-union key -- and no code path anywhere turns one into a URL, because the portal
 * publishes no inverse of its own URL-to-class normalisation and the
 * `/csp/sys/{exp,mgr,op,sec}` sub-application a page is served under is not a function of its
 * class name. The href is the descriptor's own, refused at build time unless it is a
 * root-relative same-origin path (AD-47).
 *
 * **The action's label is the classic page's name, which is descriptor data, not shell copy.**
 * The two literals here are the published title and caption (EXPERIENCE.md's Fixed strings
 * rows `:304` and `:305`); the caption tells the user the classic portal may ask them to sign
 * in again (OQ15).
 *
 * **The label is bounded.** A declared page name has no length limit, so the pill is capped to
 * the card and the label ends in an ellipsis inside it, with the glyph kept whole.
 *
 * **No `window.open` and no popup.** The anchor is the only new-tab surface, and it carries the
 * house pattern `instance-notice.ts` `:51-60` already ships: `target="_blank"`,
 * `rel="noreferrer"`, and the external glyph beside the label.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group, so
 * a call expression in the condition leaves a stray `)` that the literal-text-node rule reports
 * and `npm run build` fails on.
 */
@Component({
  selector: 'app-classic-link-card',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `@if (present) {
    <section class="ocu-classic-link-card">
      <p class="ocu-classic-link-card-title">{{ STRINGS.classicLinkCardTitle }}</p>
      <p class="ocu-classic-link-card-caption">{{ STRINGS.classicLinkCardCaption }}</p>
      <a
        class="ocu-button-secondary ocu-classic-link-card-action"
        [href]="href"
        target="_blank"
        rel="noreferrer"
      >
        <span class="ocu-classic-link-card-label">{{ label }}</span>
        <span class="ocu-external-glyph" aria-hidden="true">{{ externalGlyph }}</span>
      </a>
    </section>
  }`,
})
export class ClassicLinkCard {
  /** The descriptor this card ends the screen of, read from the generated mirror (AD-5). */
  readonly screen = input<ScreenDeclaration | null>(null);

  protected readonly STRINGS = STRINGS;

  /**
   * The north-east arrow DESIGN.md's external-link action carries, written as its escape so no
   * non-ASCII byte enters a source file (Rule 14). `aria-hidden`, so the link's accessible name
   * is the page name beside it.
   */
  protected readonly externalGlyph = '\u2197';

  /**
   * Whether this descriptor declares an exemption the card can actually render: the flag plus
   * both parts. The flag alone is not enough -- a card with no target is a dead control, and
   * one with no label would have to invent its own.
   */
  protected get present(): boolean {
    const declared = this.screen();
    if (declared === null) return false;
    const exemption = declared.classicLinkExemption;
    return exemption.exempt && exemption.href !== '' && exemption.label !== '';
  }

  protected get href(): string {
    return this.screen()?.classicLinkExemption.href ?? '';
  }

  protected get label(): string {
    return this.screen()?.classicLinkExemption.label ?? '';
  }
}

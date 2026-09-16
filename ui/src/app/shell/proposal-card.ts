import { ChangeDetectionStrategy, Component, input } from '@angular/core';

import { STRINGS } from '../core/strings';
import {
  type ProposalCardView,
  type ProposalDiffRow,
  formatProposalTitle,
  formatUnchangedCaption,
} from './example-proposal';

/**
 * The proposal card: the one thing in the transcript that asks for a decision, written once here
 * for the static example this story ships and the live cards Story 5.2 mints.
 *
 * **It owns no interactive node of any kind.** Everything about a live card that is live-only is a
 * projected slot -- `[card-countdown]` and `[card-footer]` -- which the static example leaves
 * empty, so the example has no countdown and no buttons *by construction* rather than by a
 * disabled flag. Nothing here renders a control, a link, a field or anything with a `tabindex`,
 * and `proposal-card.spec.ts` queries the whole subtree for the full focusable selector to say so.
 *
 * **The one anatomy element that is interactive in a live card ships here as text.** The
 * unchanged-fields disclosure is a `<button aria-expanded>` once there is something to disclose;
 * until then it is its published caption with an `aria-hidden` chevron, and Story 5.2 turns that
 * same element into the button when it adds the rows behind it. The card therefore ships with no
 * unexercised branch.
 *
 * **Direction is carried by words, never by colour alone** (Accessibility Floor, *Color never
 * alone*): each changed row reads "<field>: was <before>, now <after>", with "was" and "now"
 * visually hidden and the arrow `aria-hidden`, so the spoken form and the drawn form say the same
 * thing.
 *
 * Everything drawn comes from the view model, which is data (`example-proposal.ts`); the card's
 * chrome is published copy. Every control-flow condition is paren-free, for the reason
 * `sign-in.ts` records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised
 * group, so a call expression inside one leaves a stray bracket it reports as copy.
 */
@Component({
  selector: 'app-proposal-card',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<article class="ocu-proposal-card">
    <div class="ocu-proposal-card-header">
      <span class="ocu-proposal-card-title">{{ title }}</span>
      <ng-content select="[card-countdown]" />
    </div>

    <div class="ocu-proposal-card-diff">
      @for (row of changedRows; track row.field) {
        <p class="ocu-diff-row">
          <span class="ocu-diff-field">{{ row.field }}</span>
          <span class="ocu-diff-before">
            <span class="ocu-diff-direction">{{ STRINGS.proposalDiffWas }}</span>
            <span class="ocu-diff-value">{{ row.before }}</span>
          </span>
          <span class="ocu-diff-arrow" aria-hidden="true">{{ arrowGlyph }}</span>
          <span class="ocu-diff-after">
            <span class="ocu-diff-direction">{{ STRINGS.proposalDiffNow }}</span>
            <span class="ocu-diff-value">{{ row.after }}</span>
          </span>
        </p>
      }
      <p class="ocu-proposal-card-unchanged">
        <span class="ocu-proposal-card-chevron" aria-hidden="true">{{ chevronGlyph }}</span>
        <span>{{ unchangedCaption }}</span>
      </p>
    </div>

    <div class="ocu-proposal-card-agent">
      <span class="ocu-proposal-card-agent-heading">{{ STRINGS.proposalRationaleHeading }}</span>
      <span class="ocu-proposal-card-agent-text">{{ rationale }}</span>
    </div>
    <div class="ocu-proposal-card-agent">
      <span class="ocu-proposal-card-agent-heading">{{ STRINGS.proposalExpectedImpactHeading }}</span>
      <span class="ocu-proposal-card-agent-text">{{ expectedImpact }}</span>
    </div>

    @if (hasReverse) {
      <p class="ocu-proposal-card-reverse">
        <span class="ocu-proposal-card-reverse-label">{{ STRINGS.proposalReverseLabel }}</span>
        <span>{{ reverse }}</span>
      </p>
    }

    <ng-content select="[card-footer]" />
  </article>`,
})
export class ProposalCard {
  /** The card's whole content. Required: a card with nothing to propose is not a state. */
  readonly view = input.required<ProposalCardView>();

  protected readonly STRINGS = STRINGS;

  /** The arrow between the two diff values, hidden from assistive tech (the words carry it). */
  protected readonly arrowGlyph = '\u2192';

  /** The disclosure's chevron. `aria-hidden`, like every other glyph in the product. */
  protected readonly chevronGlyph = '\u203a';

  protected get title(): string {
    const view = this.view();
    return formatProposalTitle(STRINGS.proposalCardTitle, view.entityType, view.name);
  }

  protected get changedRows(): readonly ProposalDiffRow[] {
    return this.view().changed;
  }

  protected get unchangedCaption(): string {
    return formatUnchangedCaption(
      STRINGS.proposalUnchangedFieldsDisclosure,
      this.view().unchangedCount
    );
  }

  protected get rationale(): string {
    return this.view().rationale;
  }

  protected get expectedImpact(): string {
    return this.view().expectedImpact;
  }

  protected get reverse(): string {
    return this.view().reverse;
  }

  /** A delete has no reversal, and the line is absent rather than empty when there is none. */
  protected get hasReverse(): boolean {
    return this.reverse !== '';
  }
}

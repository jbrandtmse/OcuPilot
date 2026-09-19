import {
  ChangeDetectionStrategy,
  Component,
  ElementRef,
  effect,
  input,
  output,
  signal,
  viewChild,
} from '@angular/core';

import {
  type ProposalPhase,
  countdownPhase,
  countdownRemaining,
  formatCountdown,
  formatCountdownCaption,
  formatUserName,
  isTerminalPhase,
  offersRepropose,
  statusLineFor,
} from '../core/proposal-view';
import { STRINGS } from '../core/strings';
import {
  type ProposalCardView,
  type ProposalDiffRow,
  formatProposalTitle,
  formatUnchangedCaption,
} from './example-proposal';

/**
 * The proposal card: the one thing in the transcript that asks for a decision.
 *
 * **Its live half is driven by three inputs and nothing else.** `view` is what the instance
 * computed (`core/proposal-view.ts`'s mapper); `phase` is where the card is in the lifecycle, or
 * `null` for the static example, which is not a proposal; `nowMs` is the moment, supplied by the
 * panel's one ticker, so the countdown is a pure function of its inputs and no assertion about it
 * waits on a wall clock (AD-19).
 *
 * **With `phase` null the card owns no interactive node of any kind.** No countdown, no footer, no
 * masked field, and the unchanged-fields disclosure is its published caption rather than a button
 * -- a `<button aria-expanded>` appears exactly when the view carries rows to disclose. So the
 * configuration-empty example has nothing focusable by construction rather than by a disabled
 * flag, and `proposal-card.spec.ts` queries the whole subtree for the full focusable selector to
 * say so.
 *
 * **A terminal transition replaces the buttons with a status line that takes focus**, and the
 * outgoing buttons are `aria-disabled` across it rather than removed while one of them holds
 * focus: they stay in the DOM until the status line has actually been focused, and are dropped on
 * the macrotask after that. A card that arrives terminal -- a restored one -- renders no buttons at
 * all, because it never had any to take focus from.
 *
 * **Direction is carried by words, never by colour alone** (Accessibility Floor, *Color never
 * alone*): each changed row reads "<field>: was <before>, now <after>", with "was" and "now"
 * visually hidden and the arrow `aria-hidden`, so the spoken form and the drawn form say the same
 * thing. The countdown is announced once, at 1:00, into a polite region of its own -- the caption
 * itself is never a live region, so it does not announce per second.
 *
 * Everything drawn comes from the view model, which is data; the card's chrome is published copy.
 * Every control-flow condition is paren-free, for the reason `sign-in.ts` records:
 * `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group, so a call
 * expression inside one leaves a stray bracket it reports as copy.
 */
@Component({
  selector: 'app-proposal-card',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<article class="ocu-proposal-card" [class.ocu-proposal-card-restrained]="restrained">
    <div class="ocu-proposal-card-header">
      <span class="ocu-proposal-card-title">{{ title }}</span>
      <ng-content select="[card-countdown]" />
      @if (countdownVisible) {
        <span
          class="ocu-proposal-card-countdown"
          [class.ocu-proposal-card-countdown-warning]="countdownWarning"
          [attr.title]="STRINGS.proposalCountdownTooltip"
          >{{ countdownCaption }}</span
        >
      }
      @if (announceRegion) {
        <span class="ocu-visually-hidden ocu-proposal-card-announcement" role="status">{{
          announcement
        }}</span>
      }
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
      @if (disclosable) {
        <button
          type="button"
          class="ocu-proposal-card-unchanged ocu-proposal-card-disclosure"
          [attr.aria-expanded]="unchangedExpandedAttr"
          (click)="toggleUnchanged()"
        >
          <span class="ocu-proposal-card-chevron" aria-hidden="true">{{ chevronGlyph }}</span>
          <span>{{ unchangedCaption }}</span>
        </button>
        @if (unchangedExpanded) {
          <div class="ocu-proposal-card-unchanged-rows">
            @for (row of unchangedRows; track row.field) {
              <p class="ocu-diff-row ocu-diff-row-unchanged">
                <span class="ocu-diff-field">{{ row.field }}</span>
                <span class="ocu-diff-value">{{ row.after }}</span>
              </p>
            }
          </div>
        }
      } @else {
        <p class="ocu-proposal-card-unchanged">
          <span class="ocu-proposal-card-chevron" aria-hidden="true">{{ chevronGlyph }}</span>
          <span>{{ unchangedCaption }}</span>
        </p>
      }
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

    @if (secretsVisible) {
      <div class="ocu-proposal-card-secrets">
        @for (field of maskedFields; track field) {
          <label class="ocu-field-label" [attr.for]="secretId(field)">{{ field }}</label>
          <input
            class="ocu-field-input ocu-proposal-card-secret"
            type="password"
            autocomplete="off"
            aria-required="true"
            [id]="secretId(field)"
            [value]="secretValue(field)"
            (input)="onSecret(field, $event)"
          />
        }
      </div>
    }

    @if (auditWarningVisible) {
      <p class="ocu-banner ocu-banner-warning ocu-proposal-card-warning" role="status">
        <span class="ocu-banner-glyph" aria-hidden="true">{{ bannerGlyph }}</span>
        <span class="ocu-banner-message">{{ STRINGS.proposalAuditWarning }}</span>
      </p>
    }

    <ng-content select="[card-footer]" />

    @if (footerVisible) {
      <div class="ocu-proposal-card-footer">
        @if (statusVisible) {
          <p
            #status
            class="ocu-proposal-card-status"
            tabindex="-1"
            role="status"
            [class.ocu-proposal-card-status-confirmed]="confirmed"
          >
            {{ statusLine }}
          </p>
        }
        @if (buttonsVisible) {
          <p class="ocu-proposal-card-runs-as">{{ runsAsCaption }}</p>
          <button
            type="button"
            class="ocu-button-primary ocu-proposal-card-confirm"
            [attr.aria-disabled]="confirmAriaDisabled"
            (click)="onConfirm()"
          >
            {{ STRINGS.actionConfirm }}
          </button>
          <button
            type="button"
            class="ocu-button-text ocu-proposal-card-cancel"
            [attr.aria-disabled]="cancelAriaDisabled"
            (click)="onCancel()"
          >
            {{ STRINGS.actionCancel }}
          </button>
        }
        @if (guardVisible) {
          <p class="ocu-proposal-card-guard">{{ STRINGS.proposalFooterConfirmHint }}</p>
        }
        @if (reproposeVisible) {
          <button
            type="button"
            class="ocu-button-secondary ocu-proposal-card-repropose"
            (click)="onRepropose()"
          >
            {{ STRINGS.actionRepropose }}
          </button>
        }
      </div>
    }
  </article>`,
})
export class ProposalCard {
  /** The card's whole content. Required: a card with nothing to propose is not a state. */
  readonly view = input.required<ProposalCardView>();

  /**
   * Where this card is in the lifecycle, or `null` for the static example. `live` is the only
   * value that draws a footer with buttons; the panel supplies the client-side transitions and
   * Story 5.3 makes the confirmed, canceled and target-changed lines authoritative.
   */
  readonly phase = input<ProposalPhase | null>(null);

  /** The moment, in epoch milliseconds, from the panel's one ticker. */
  readonly nowMs = input<number>(0);

  /** The account the write would run as, for the footer's caption and the confirmed line. */
  readonly userName = input<string>('');

  /** The moment a confirmed write landed, as `hh:mm:ss` (Story 5.3 supplies it). */
  readonly confirmedAt = input<string>('');

  /** Confirm was pressed. The request itself is Story 5.3's; this is the seam it fills. */
  readonly confirm = output<string>();

  /** Cancel was pressed. Its transition is client-side (the panel's). */
  readonly cancel = output<string>();

  /** Re-propose was pressed: the accommodation for the expiry limit (WCAG 2.2.1). */
  readonly repropose = output<string>();

  protected readonly STRINGS = STRINGS;

  /** The arrow between the two diff values, hidden from assistive tech (the words carry it). */
  protected readonly arrowGlyph = '\u2192';

  /** The disclosure's chevron. `aria-hidden`, like every other glyph in the product. */
  protected readonly chevronGlyph = '\u203a';

  /** The in-card warning's glyph, `aria-hidden` so the strip reads as its sentence alone. */
  protected readonly bannerGlyph = '\u2139';

  private readonly statusEl = viewChild<ElementRef<HTMLElement>>('status');

  /** `null` until the user clicks; then the manual override this card keeps for its whole life. */
  private readonly manualExpanded = signal<boolean | null>(null);

  /** What each masked field holds so far, by field name. Never read by anything but Confirm's gate. */
  private readonly secrets = signal<ReadonlyMap<string, string>>(new Map());

  /** The one-shot countdown announcement, `''` until 1:00 is crossed on a live card. */
  private readonly announcementText = signal('');

  /** Whether the outgoing buttons have been dropped, which happens after the status line has focus. */
  private readonly buttonsRetired = signal(false);

  /** Whether this card has ever been non-terminal, so a transition can be told from an arrival. */
  private everLive = false;

  /** The phase the status line was last focused for, so focus moves once per transition. */
  private focusedFor: ProposalPhase | null = null;

  constructor() {
    effect(() => {
      const phase = this.livePhase;
      if (phase === null) return;
      if (!isTerminalPhase(phase)) {
        this.everLive = true;
        // A card can come back from a terminal phase -- the kill switch going off again is the
        // reachable route -- and its next terminal transition owes the user the same hand-off as
        // its first. Without this reset the buttons would be dropped in the very pass that
        // inserts the status line, with one of them still holding focus, and both halves of AC6
        // would fail on every transition after the first.
        this.buttonsRetired.set(false);
        this.focusedFor = null;
        // A live card announces the last minute exactly once: the caption is not a live region,
        // so this is the only thing that speaks, and it speaks on the tick that crosses 1:00.
        if (this.countdownReading === 'warning' && this.announcementText() === '') {
          this.announcementText.set(STRINGS.proposalCountdownAnnouncement);
        }
        return;
      }
      const element = this.statusEl();
      if (element === undefined) return;
      if (this.focusedFor === phase) return;
      this.focusedFor = phase;
      // The last-minute announcement belongs to a live card. Left in place it would hold
      // "One minute left to confirm" in the polite region under a status line reading Expired.
      this.announcementText.set('');
      // Focus moves **only when a button of this card held it**: the status line is the destination
      // for a control that is going away, and a transition the user did not press -- a typed
      // message canceling three cards, the kill switch going on -- must not pull focus out of the
      // composer they are typing in.
      if (this.heldFocus(element.nativeElement)) element.nativeElement.focus();
      // The outgoing buttons were `aria-disabled` across the transition rather than removed while
      // one of them could hold focus; the destination has had its chance now, so they may go.
      setTimeout(() => this.buttonsRetired.set(true), 0);
    });
  }

  /** Whether the active element is inside this card, which is what makes it focus's own owner. */
  private heldFocus(status: HTMLElement): boolean {
    const card = status.closest('.ocu-proposal-card');
    const active = status.ownerDocument.activeElement;
    return card !== null && active !== null && card.contains(active);
  }

  protected get title(): string {
    const view = this.view();
    return formatProposalTitle(STRINGS.proposalCardTitle, view.entityType, view.name);
  }

  protected get changedRows(): readonly ProposalDiffRow[] {
    return this.view().changed;
  }

  protected get unchangedRows(): readonly ProposalDiffRow[] {
    return this.view().unchanged ?? [];
  }

  /** The disclosure is a button exactly when there is something behind it (see the class header). */
  protected get disclosable(): boolean {
    return this.unchangedRows.length > 0;
  }

  protected get unchangedExpanded(): boolean {
    return this.manualExpanded() === true;
  }

  protected get unchangedExpandedAttr(): string {
    return this.unchangedExpanded ? 'true' : 'false';
  }

  protected toggleUnchanged(): void {
    this.manualExpanded.set(!this.unchangedExpanded);
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

  protected get maskedFields(): readonly string[] {
    return this.view().maskedFields ?? [];
  }

  /** The masked fields are the user's own input at confirmation, so the example never shows them. */
  protected get secretsVisible(): boolean {
    return this.live && this.maskedFields.length > 0;
  }

  protected secretId(field: string): string {
    return 'ocu-proposal-secret-' + (this.view().proposalId ?? '') + '-' + field;
  }

  protected secretValue(field: string): string {
    return this.secrets().get(field) ?? '';
  }

  protected onSecret(field: string, event: Event): void {
    const next = new Map(this.secrets());
    next.set(field, (event.target as HTMLInputElement).value);
    this.secrets.set(next);
  }

  /** Whether every declared masked field has been filled, which is what Confirm waits for. */
  private get secretsFilled(): boolean {
    return this.maskedFields.every((field) => this.secretValue(field) !== '');
  }

  protected get auditWarningVisible(): boolean {
    return this.phase() !== null && this.view().auditWarning === true;
  }

  /** The phase as the card resolves it, or `null` for the static example. */
  private get livePhase(): ProposalPhase | null {
    const declared = this.phase();
    if (declared === null) return null;
    if (declared !== 'live') return declared;
    return this.countdownReading === 'expired' ? 'expired' : declared;
  }

  /** How the countdown reads right now: `'normal'` while the expiry is unknown. */
  private get countdownReading(): 'normal' | 'warning' | 'expired' {
    const remaining = this.remainingMs;
    return remaining === null ? 'normal' : countdownPhase(remaining);
  }

  private get remainingMs(): number | null {
    return countdownRemaining(this.view().expiresAt ?? 0, this.nowMs());
  }

  protected get live(): boolean {
    return this.livePhase === 'live' || this.livePhase === 'confirming';
  }

  protected get restrained(): boolean {
    const phase = this.livePhase;
    return phase !== null && isTerminalPhase(phase);
  }

  protected get confirmed(): boolean {
    return this.livePhase === 'confirmed';
  }

  /** The countdown shows on a live card whose expiry the instance actually sent (`0` is unknown). */
  protected get countdownVisible(): boolean {
    return this.live && this.remainingMs !== null;
  }

  protected get countdownWarning(): boolean {
    return this.countdownReading === 'warning';
  }

  protected get countdownCaption(): string {
    const remaining = this.remainingMs;
    return formatCountdownCaption(
      STRINGS.proposalCountdownLabel,
      remaining === null ? '' : formatCountdown(remaining)
    );
  }

  protected get announceRegion(): boolean {
    return this.phase() !== null;
  }

  protected get announcement(): string {
    return this.announcementText();
  }

  protected get footerVisible(): boolean {
    return this.phase() !== null;
  }

  protected get statusVisible(): boolean {
    return this.restrained;
  }

  protected get statusLine(): string {
    const phase = this.livePhase;
    return phase === null ? '' : statusLineFor(phase, this.userName(), this.confirmedAt());
  }

  /**
   * Confirm and Cancel show while the card is live, and across a terminal transition they stay in
   * the DOM `aria-disabled` until the status line has taken focus (see the class header).
   */
  protected get buttonsVisible(): boolean {
    if (this.live) return true;
    return this.everLive && !this.buttonsRetired();
  }

  protected get confirmAriaDisabled(): string | null {
    if (!this.live) return 'true';
    return this.secretsFilled ? null : 'true';
  }

  protected get cancelAriaDisabled(): string | null {
    return this.live ? null : 'true';
  }

  /** The guard caption is a live card's own: it says what sending a message would do to it. */
  protected get guardVisible(): boolean {
    return this.live;
  }

  protected get runsAsCaption(): string {
    return formatUserName(STRINGS.proposalFooterRunsAs, this.userName());
  }

  protected get reproposeVisible(): boolean {
    const phase = this.livePhase;
    return phase !== null && offersRepropose(phase);
  }

  protected onConfirm(): void {
    if (this.confirmAriaDisabled !== null) return;
    this.confirm.emit(this.view().proposalId ?? '');
  }

  protected onCancel(): void {
    if (this.cancelAriaDisabled !== null) return;
    this.cancel.emit(this.view().proposalId ?? '');
  }

  protected onRepropose(): void {
    this.repropose.emit(this.view().proposalId ?? '');
  }
}

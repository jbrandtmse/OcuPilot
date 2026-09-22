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
  type ProposalUnchangedRow,
  formatProposalTitle,
  formatUnchangedCaption,
} from './example-proposal';

/**
 * One Confirm press: the proposal's id and the values typed into its masked fields.
 *
 * The values are the card's own and reach the confirm body through this one channel (AD-6's
 * closed channel, AD-35); nothing stores them and nothing else reads them.
 */
export interface ProposalConfirmRequest {
  readonly proposalId: string;
  readonly secrets: Record<string, string>;
}

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
 * **A refusal the instance left live is drawn, not swallowed** (DW-1348). A prohibited or
 * restrained Confirm leaves the row `live` on purpose, so the card keeps its buttons and gains the
 * envelope's own written `reason` in a warning banner above the footer -- the server's words, never
 * a second client-authored copy (AD-39), and no new phase, because a phase is a terminal state and
 * this is not one.
 *
 * Everything drawn comes from the view model, which is data; the card's chrome is published copy.
 * Every control-flow condition is paren-free, for the reason `sign-in.ts` records:
 * `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group, so a call
 * expression inside one leaves a stray bracket it reports as copy.
 */
@Component({
  selector: 'app-proposal-card',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<article
    class="ocu-proposal-card"
    [class.ocu-proposal-card-destructive]="destructive"
    [class.ocu-proposal-card-restrained]="restrained"
  >
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
            <span class="ocu-diff-value">{{ shown(row.before) }}</span>
          </span>
          <span class="ocu-diff-arrow" aria-hidden="true">{{ arrowGlyph }}</span>
          <span class="ocu-diff-after">
            <span class="ocu-diff-direction">{{ STRINGS.proposalDiffNow }}</span>
            <span class="ocu-diff-value">{{ shown(row.after) }}</span>
          </span>
        </p>
      }
      @if (discloses) {
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
                <span class="ocu-diff-value">{{ shown(row.value) }}</span>
                <span class="ocu-diff-direction">{{ STRINGS.proposalDiffUnchanged }}</span>
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
        @if (confirmReasonId !== null) {
          <p class="ocu-proposal-card-secrets-reason" [id]="secretsReasonId">
            {{ STRINGS.proposalSecretsRequired }}
          </p>
        }
      </div>
    }

    @if (auditWarningVisible) {
      <p class="ocu-banner ocu-banner-warning ocu-proposal-card-warning" role="status">
        <span class="ocu-banner-glyph" aria-hidden="true">{{ bannerGlyph }}</span>
        <span class="ocu-banner-message">{{ STRINGS.proposalAuditWarning }}</span>
      </p>
    }

    @if (refusalVisible) {
      <p
        class="ocu-banner ocu-banner-warning ocu-proposal-card-warning"
        role="alert"
        data-slot="refusal"
      >
        <span class="ocu-banner-glyph" aria-hidden="true">{{ bannerGlyph }}</span>
        <span class="ocu-banner-message">{{ refusalReason }}</span>
      </p>
    }

    <ng-content select="[card-footer]" />

    @if (footerVisible) {
      <div class="ocu-proposal-card-footer">
        @if (statusVisible) {
          @if (targetChanged) {
            <p
              #status
              class="ocu-banner ocu-banner-warning ocu-proposal-card-status ocu-proposal-card-status-target-changed"
              tabindex="-1"
              [attr.role]="statusRole"
            >
              <span class="ocu-banner-glyph" aria-hidden="true">{{ bannerGlyph }}</span>
              <span class="ocu-banner-message">{{ statusLine }}</span>
            </p>
          } @else {
            <p
              #status
              class="ocu-proposal-card-status"
              tabindex="-1"
              [attr.role]="statusRole"
              [class.ocu-proposal-card-status-confirmed]="confirmed"
            >
              {{ statusLine }}
            </p>
          }
        }
        @if (buttonsVisible) {
          <p class="ocu-proposal-card-runs-as">{{ runsAsCaption }}</p>
          <button
            type="button"
            class="ocu-proposal-card-confirm"
            [class.ocu-button-primary]="!destructive"
            [class.ocu-button-destructive]="destructive"
            [class.ocu-proposal-card-confirm-busy]="confirming"
            [attr.aria-disabled]="confirmAriaDisabled"
            [attr.aria-describedby]="confirmReasonId"
            (click)="onConfirm()"
          >
            @if (confirming) {
              <span class="ocu-proposal-card-confirm-spinner" aria-hidden="true"></span>
            }
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
            [attr.aria-disabled]="reproposeAriaDisabled"
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
   * Where this card is in the lifecycle, or `null` for the static example. `live` and `confirming`
   * draw a footer with buttons; every terminal value draws the status line the instance's own
   * state resolved to.
   */
  readonly phase = input<ProposalPhase | null>(null);

  /** The moment, in epoch milliseconds, from the panel's one ticker. */
  readonly nowMs = input<number>(0);

  /** The account the write would run as, for the footer's caption and the confirmed line. */
  readonly userName = input<string>('');

  /** The moment a confirmed write landed, as `hh:mm:ss`, from the instance's own stamp. */
  readonly confirmedAt = input<string>('');

  /**
   * Confirm was pressed: the proposal's id and the values typed into its masked fields (AD-6,
   * AD-35).
   *
   * The values travel with the press rather than being read out of this component, because the
   * card is the only thing that ever holds them: they are never in an input, never in the store
   * and never in the view model. The panel posts them as the confirm body and keeps no copy.
   */
  readonly confirm = output<ProposalConfirmRequest>();

  /** Cancel was pressed. The panel makes the request, and the instance closes the row. */
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

  /**
   * Whether the transition this card is showing was one a control of this card held focus for.
   *
   * It decides the status line's `role`. The transcript is a `role="log"`, so a text change inside
   * it is announced by construction; adding `role="status"` on a line that also takes focus makes
   * the same sentence announce twice. So the line is a status region only when focus did NOT move
   * to it -- a typed message closing three cards, the kill switch going on -- and is a plain
   * paragraph when it did (DW-1229).
   */
  private readonly tookFocus = signal(false);

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
        this.tookFocus.set(false);
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
      const held = this.heldFocus(element.nativeElement);
      this.tookFocus.set(held);
      if (held) element.nativeElement.focus();
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

  protected get unchangedRows(): readonly ProposalUnchangedRow[] {
    return this.view().unchanged ?? [];
  }

  /**
   * `value` as the card shows it: the published empty-value word where the instance sent nothing
   * (EXPERIENCE.md's diff-row rule, "empty values read"), else the value itself.
   *
   * One function for both halves of a changed row and for an unchanged row, because the rule is
   * the row's and not the half's -- UJ-3's own diff reads `Resource: (none) -> %Development`, and
   * a field the payload sends empty reads the same word under the disclosure.
   */
  protected shown(value: string): string {
    return value === '' ? STRINGS.tableEmptyValue : value;
  }

  /**
   * Whether the card carries an unchanged-fields line at all.
   *
   * A write that sends no body has no unchanged fields to disclose (AD-51), and its proposal
   * carries `unchangedCount` 0 -- "0 unchanged fields" under an action's one state row is a line
   * that says nothing about anything the confirm will do.
   */
  protected get discloses(): boolean {
    return this.view().unchangedCount > 0;
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

  /**
   * Whether the tool declared this write destructive, which turns the card's left-edge bar and its
   * Confirm to the destructive treatment (DESIGN.md `:1176`, `:1243`).
   *
   * **The styling ships without the typed-name field.** `button-destructive` is published as
   * appearing only once a typed name matches, and that field is Story 14.7's: shipping it here
   * would leave Confirm permanently `aria-disabled`, since nothing yet compares what was typed.
   * The declaration on the wire is what 14.7 then reads, from one place.
   */
  protected get destructive(): boolean {
    return this.view().destructive === true;
  }

  /**
   * The published reason's own id, which Confirm names while a masked field is still empty.
   *
   * The paragraph it identifies is rendered on the same condition, `confirmReasonId`: the sentence
   * is an instruction for a field that is still empty, so leaving it up once every field is filled
   * would leave a caption telling the reader to do what they have just done.
   */
  protected get secretsReasonId(): string {
    return 'ocu-proposal-secrets-reason-' + (this.view().proposalId ?? '');
  }

  /**
   * The id of whatever reason Confirm currently has, or `null` when it has none (DW-1232).
   *
   * A control that refuses and says nothing is the gap: `aria-disabled` states that the press will
   * not work and the published sentence states why, so the reason is announced rather than left to
   * the reader to infer from an unfilled field they may not have found.
   */
  protected get confirmReasonId(): string | null {
    return this.secretsVisible && !this.secretsFilled ? this.secretsReasonId : null;
  }

  /** The envelope's own written reason for a decision the instance refused (DW-1348). */
  protected get refusalReason(): string {
    return this.view().refusalReason ?? '';
  }

  /**
   * Whether that reason shows. On a live card and nothing else: a refusal that CLOSED the row
   * leaves its own terminal status line, and drawing both would say two things about one press.
   * Confirm and Cancel stay offered beside it, because a prohibited or restrained refusal is about
   * this write and not about this proposal's validity -- the condition can clear (AD-10).
   */
  protected get refusalVisible(): boolean {
    return this.refusalReason !== '' && this.live;
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

  /** The fingerprint refusal, which draws its status line inside the warning banner. */
  protected get targetChanged(): boolean {
    return this.livePhase === 'target-changed';
  }

  /** Whether the confirm request is in flight, which is what the button's progress reads. */
  protected get confirming(): boolean {
    return this.livePhase === 'confirming';
  }

  /** `status` only for a transition this card did not take focus for (see `tookFocus`). */
  protected get statusRole(): string | null {
    return this.tookFocus() ? null : 'status';
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
    // In flight it stays in the tab order and keeps focus, and refuses a second press -- the
    // `aria-disabled` discipline every gated control in this product keeps.
    if (this.confirming) return 'true';
    return this.secretsFilled ? null : 'true';
  }

  /**
   * Re-propose takes the same discipline as the other two: `aria-disabled` rather than the
   * `disabled` attribute, so it stays in the tab order and its reason is announced. It has no
   * in-flight state of its own -- the turn it starts locks the composer -- so on a rendered button
   * the attribute is always absent; the binding exists so the three controls read the same way.
   */
  protected get reproposeAriaDisabled(): string | null {
    return this.reproposeVisible ? null : 'true';
  }

  protected get cancelAriaDisabled(): string | null {
    if (!this.live) return 'true';
    // Refused while a Confirm is out, for the same reason Confirm itself is: the decision has
    // already been made and may already have been written. A Cancel accepted here would draw
    // "Canceled by you" over a proposal the instance confirmed.
    if (this.confirming) return 'true';
    return null;
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
    const secrets: Record<string, string> = {};
    for (const field of this.maskedFields) secrets[field] = this.secretValue(field);
    this.confirm.emit({ proposalId: this.view().proposalId ?? '', secrets });
  }

  protected onCancel(): void {
    if (this.cancelAriaDisabled !== null) return;
    this.cancel.emit(this.view().proposalId ?? '');
  }

  protected onRepropose(): void {
    if (this.reproposeAriaDisabled !== null) return;
    this.repropose.emit(this.view().proposalId ?? '');
  }
}

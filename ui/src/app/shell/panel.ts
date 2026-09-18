import { ChangeDetectionStrategy, Component, DestroyRef, ElementRef, inject, signal, viewChild } from '@angular/core';
import { Router } from '@angular/router';

import { AgentContext } from '../core/agent-context';
import { AgentStatus, DEFINITIONS_ROUTE, formatKillSwitch } from '../core/agent-status';
import { decodeEntityId } from '../core/entity-id';
import {
  NavigationService,
  formatNavigationAnnouncement,
  screenForRoute,
  screenForUrl,
  withQuery,
} from '../core/navigation';
import { PanelState } from '../core/panel-layout';
import { ScopeService, onScopeChange } from '../core/scope';
import { assembleScreenContext, looksLikeSecret, type ScreenContextPayload } from '../core/screen-context';
import { ScreenStores } from '../core/screen-store';
import { STRINGS, stringFor } from '../core/strings';
import { TurnStore, type TurnStep, turnErrorBanner } from '../core/turn';
import { isApplePlatform } from './command-box';
import { ContextChip } from './context-chip';
import { EXAMPLE_PROPOSAL } from './example-proposal';
import { PanelResizeHandle } from './panel-resize-handle';
import { ProposalCard } from './proposal-card';
import { Reply } from './reply';
import { ToolCallCard } from './tool-call-card';

/** The composer's control id: its label, both `aria-describedby` wires and the Ctrl/Cmd+I target. */
export const COMPOSER_ID = 'ocu-panel-composer';

/** The id of whichever gate sentence the panel is showing, which is also the controls' reason. */
const REASON_ID = 'ocu-panel-reason';

/** The kill-switch banner's own id, which is the controls' reason while the agent is switched off. */
const KILL_SWITCH_ID = 'ocu-panel-kill-switch';

/** The enforced-read-only banner's own id. */
const READ_ONLY_ID = 'ocu-panel-read-only';

/** The composer's and Send's reason while a turn runs (Story 4.5). */
const BUSY_REASON_ID = 'ocu-panel-busy-reason';

/** New conversation's reason while a turn runs (Story 4.5). */
const NEW_CONVERSATION_REASON_ID = 'ocu-panel-new-conversation-reason';

/** One turn's rendered view, precomputed once per read so the template does no substitution. */
interface PanelTurnView {
  readonly message: string;
  readonly steps: readonly TurnStep[];
  readonly reply: string | null;
  readonly errorBanner: string | null;
}

/**
 * The agent co-pilot panel, docked right of every signed-in route (EXPERIENCE.md panel).
 *
 * **Anatomy, top to bottom.** The resize handle on the left edge (absent in full screen); the
 * header with the avatar, "Agent co-pilot", **New conversation** and the full-screen toggle
 * (Story 4.5 fills the first of those two icon buttons); the banner slots in EXPERIENCE.md's
 * fixed order -- kill switch, enforced read-only, "not being marked" (Epic 5); administrator
 * reminder, lock (Story 4.5); the context chip, filled in by Story 4.11; the transcript, a
 * polite `role="log"` named "Conversation" that scrolls by itself; and the footer with the
 * read-only line, the inline paste warning (Story 4.11), the composer and Send. There is no
 * close control.
 *
 * **Every fact is read, none remembered here.** Whether a definition is enabled and the restraint
 * verdict come from `AgentStatus`; whether this caller may configure one is the navigation map's
 * verdict for `agent/definitions` (AD-8); the draft, the width and full screen are `PanelState`'s;
 * the transcript, whether a turn is running and the lock banner are `TurnStore`'s (Story 4.5). The
 * gate sentences render only once the map has loaded and the status has answered, so no audience
 * is guessed at: `loaded()`, not `answered()`, because a failed map read leaves every verdict
 * allowed.
 *
 * **The composer** is editable while a definition is enabled and the kill switch is off, and its
 * text is `PanelState`'s draft, so a route change keeps it. Read-only changes only the footer line
 * (DESIGN.md panel Read-only row). Otherwise it is `readonly` beside `aria-disabled`, described by
 * the sentence that says why, and never natively disabled. **A turn running is not one of those
 * reasons** -- the composer stays focusable and editable while busy, described instead by "A turn
 * is in progress"; Send becomes Stop and keeps focus (same element, only its label and handler
 * change).
 *
 * **Send / Enter / Stop, in one place.** `onSendOrStop` is Stop while a turn runs, else Send;
 * `onComposerKeydown` gives Enter (without Shift) the same Send behavior and lets Shift+Enter
 * insert a newline as a textarea always does. Both funnel into `TurnStore.send`, which is the one
 * place that decides sent vs. locally-locked vs. refused by the instance (409) -- this component
 * never guesses which.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group.
 */
@Component({
  selector: 'app-panel',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ProposalCard, PanelResizeHandle, ToolCallCard, ContextChip, Reply],
  template: `<aside class="ocu-panel" [class.ocu-panel-full-screen]="fullScreen" [attr.aria-label]="panelName">
    @if (docked) {
      <app-panel-resize-handle />
    }
    <div class="ocu-panel-header">
      <span class="ocu-panel-avatar" aria-hidden="true"></span>
      <h2 class="ocu-panel-title">{{ panelName }}</h2>
      <button
        type="button"
        class="ocu-panel-icon-button ocu-panel-new-conversation"
        [attr.aria-label]="STRINGS.actionNewConversation"
        [attr.aria-disabled]="newConversationAriaDisabled"
        [attr.aria-describedby]="newConversationDescribedBy"
        (click)="onNewConversation()"
      >
        <span class="ocu-panel-icon-glyph" aria-hidden="true">{{ newConversationGlyph }}</span>
      </button>
      <button
        type="button"
        class="ocu-panel-icon-button ocu-panel-full-screen-toggle"
        [attr.aria-label]="STRINGS.agentPanelFullScreen"
        [attr.aria-expanded]="fullScreenExpanded"
        (click)="toggleFullScreen()"
      >
        <span class="ocu-panel-icon-glyph" aria-hidden="true">{{ fullScreenGlyph }}</span>
      </button>
      @if (busy) {
        <span [id]="newConversationReasonId" class="ocu-visually-hidden">{{
          STRINGS.agentNewConversationLockedReason
        }}</span>
      }
    </div>

    <div class="ocu-panel-body">
      <div class="ocu-panel-banners">
        @if (killSwitch) {
          <p class="ocu-banner ocu-banner-restrained ocu-panel-banner" role="alert" [id]="killSwitchId">
            <span class="ocu-banner-glyph" aria-hidden="true">{{ bannerGlyph }}</span>
            <span class="ocu-banner-message">{{ killSwitchMessage }}</span>
          </p>
        }
        @if (enforcedReadOnly) {
          <p class="ocu-banner ocu-banner-restrained ocu-panel-banner" role="alert" [id]="readOnlyId">
            <span class="ocu-banner-glyph" aria-hidden="true">{{ bannerGlyph }}</span>
            <span class="ocu-banner-message">{{ STRINGS.agentReadOnlyEnforcedBanner }}</span>
          </p>
        }
        <div class="ocu-panel-banner-slot" data-slot="not-marked"></div>
        @if (reminder) {
          <p class="ocu-banner ocu-banner-info ocu-panel-banner" [id]="reasonId">
            <span class="ocu-banner-glyph" aria-hidden="true">{{ bannerGlyph }}</span>
            <span class="ocu-banner-message">{{ STRINGS.agentGateReminderBanner }}</span>
            <a class="ocu-button-text ocu-panel-banner-link" [href]="definitionsHref" (click)="openDefinitions($event)">{{
              STRINGS.agentDefinitionListLabel
            }}</a>
          </p>
        }
        <div class="ocu-panel-banner-slot" data-slot="lock">
          @if (locked) {
            <p class="ocu-banner ocu-banner-info ocu-panel-banner" role="status" [id]="lockBannerId">
              <span class="ocu-banner-glyph" aria-hidden="true">{{ bannerGlyph }}</span>
              <span class="ocu-banner-message">{{ STRINGS.agentTurnLockBanner }}</span>
            </p>
          }
        </div>
      </div>

      <div class="ocu-panel-chip-slot">
        @if (contextChipVisible) {
          <app-context-chip [killSwitch]="killSwitch" />
        }
      </div>

      <div class="ocu-panel-transcript" role="log" aria-live="polite" tabindex="0" [attr.aria-label]="STRINGS.agentConversationLabel">
        @if (unconfigured) {
          @if (emptySentence) {
            <p class="ocu-panel-empty" [id]="reasonId">{{ STRINGS.agentGateEmptyState }}</p>
          }
          <div class="ocu-panel-example">
            <p class="ocu-proposal-card-band">{{ STRINGS.proposalExampleCardTitle }}</p>
            <app-proposal-card [view]="example" />
          </div>

          <ul class="ocu-panel-trust">
            <li>{{ STRINGS.agentTrustReads }}</li>
            <li>{{ STRINGS.agentTrustProposes }}</li>
            <li>{{ STRINGS.agentTrustAudited }}</li>
          </ul>
        } @else {
          @for (turn of turns; track $index) {
            <div class="ocu-panel-turn">
              <p class="ocu-panel-message-user">{{ turn.message }}</p>
              @for (step of turn.steps; track step.seq) {
                @if (step.kind === 'announce') {
                  @if (step.status !== 'error') {
                    <div class="ocu-panel-message-agent">
                      <span class="ocu-panel-message-avatar" aria-hidden="true"></span>
                      <p class="ocu-panel-message-agent-text">{{ announceText(step) }}</p>
                    </div>
                  }
                } @else {
                  <app-tool-call-card [step]="step" />
                }
              }
              @if (turn.reply !== null) {
                <div class="ocu-panel-message-agent">
                  <span class="ocu-panel-message-avatar" aria-hidden="true"></span>
                  <app-reply class="ocu-panel-message-agent-text" [text]="turn.reply" />
                </div>
              }
              @if (turn.errorBanner !== null) {
                <div class="ocu-panel-message-agent">
                  <span class="ocu-panel-message-avatar" aria-hidden="true"></span>
                  <p class="ocu-panel-error-banner" role="alert">{{ turn.errorBanner }}</p>
                </div>
              }
            </div>
          }
        }
      </div>
    </div>

    <div class="ocu-panel-footer">
      <p class="ocu-panel-read-only" [class.ocu-panel-read-only-on]="readOnlyOn">{{ readOnlyLine }}</p>
      <div class="ocu-panel-warning-slot">
        @if (secretWarningVisible) {
          <p class="ocu-banner ocu-banner-warning ocu-panel-warning" role="status">
            <span class="ocu-banner-glyph" aria-hidden="true">{{ bannerGlyph }}</span>
            <span class="ocu-banner-message">{{ STRINGS.agentPanelSecretWarning }}</span>
            <button type="button" class="ocu-button-text ocu-panel-warning-send" (click)="onSendAnyway()">{{
              STRINGS.agentPanelSecretWarningSend
            }}</button>
            <button type="button" class="ocu-button-text ocu-panel-warning-edit" (click)="onEditDraft()">{{
              STRINGS.agentPanelSecretWarningEdit
            }}</button>
          </p>
        }
      </div>
      <label class="ocu-field-label" [attr.for]="composerId">{{ STRINGS.agentComposerLabel }}</label>
      <div class="ocu-panel-composer-row">
        <textarea
          #composer
          class="ocu-panel-composer"
          rows="1"
          [class.ocu-panel-composer-unavailable]="composerUnavailable"
          [id]="composerId"
          [value]="draft"
          [attr.aria-disabled]="composerAriaDisabled"
          [attr.readonly]="composerReadonly"
          [attr.aria-describedby]="describedBy"
          (input)="onDraft($event)"
          (keydown)="onComposerKeydown($event)"
        ></textarea>
        <button
          type="button"
          class="ocu-button-primary ocu-panel-send"
          [attr.aria-disabled]="sendAriaDisabled"
          [attr.aria-describedby]="describedBy"
          (click)="onSendOrStop()"
        >
          {{ sendLabel }}
        </button>
      </div>
      @if (busy) {
        <span [id]="busyReasonId" class="ocu-visually-hidden">{{ STRINGS.agentComposerLockedReason }}</span>
      }
      <p class="ocu-panel-caption">{{ caption }}</p>
    </div>
  </aside>`,
})
export class Panel {
  private readonly navigation = inject(NavigationService);
  private readonly agentStatus = inject(AgentStatus);
  private readonly agentContext = inject(AgentContext);
  private readonly panel = inject(PanelState);
  private readonly turn = inject(TurnStore);
  private readonly router = inject(Router);
  private readonly scope = inject(ScopeService);
  private readonly screenStores = inject(ScreenStores);

  private readonly composerEl = viewChild<ElementRef<HTMLTextAreaElement>>('composer');

  protected readonly STRINGS = STRINGS;

  /** The panel's landmark name and title: the area's own, which is what the Landmarks line names it. */
  protected readonly panelName = STRINGS.navAreaAgent;

  protected readonly composerId = COMPOSER_ID;

  protected readonly reasonId = REASON_ID;

  protected readonly killSwitchId = KILL_SWITCH_ID;

  protected readonly readOnlyId = READ_ONLY_ID;

  protected readonly busyReasonId = BUSY_REASON_ID;

  protected readonly newConversationReasonId = NEW_CONVERSATION_REASON_ID;

  /** The lock banner's own id (Story 4.5). Nothing currently points to it with `aria-describedby`;
   * `role="status"` is what makes it self-announcing. */
  protected readonly lockBannerId = 'ocu-panel-lock';

  /** The banner's glyph, `aria-hidden` so the strip reads as its sentence alone. */
  protected readonly bannerGlyph = '\u2139';

  /** New conversation's glyph, `aria-hidden`; its name is the button's own `aria-label`. */
  protected readonly newConversationGlyph = '\u2795';

  /** The caption, with the chord spelled the way the platform spells it. */
  protected readonly caption = isApplePlatform() ? STRINGS.agentComposerCaptionMac : STRINGS.agentComposerCaption;

  /** UJ-3's card, as data (`example-proposal.ts`). Never a timer, a button or a focus stop. */
  protected readonly example = EXAMPLE_PROPOSAL;

  /** Bumped by every source, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  /** Whether the inline paste warning is showing (Story 4.11): a view-only signal, like
   * `tool-call-card.ts`'s `manualExpanded`. */
  private readonly secretWarningVisibleSignal = signal(false);

  /** The text a "Send anyway" click last acknowledged, or `null`. Cleared on a sent turn and
   * whenever this tab's conversation resets (`syncSecretRecord`) -- never recorded by Edit, so an
   * unchanged text is warned about again (Boundaries & Constraints). */
  private readonly acknowledgedSecretText = signal<string | null>(null);

  /**
   * `turn.conversationId()` as of the last `turn.subscribe` notification, so `syncSecretRecord`
   * can tell a genuine reset (`endSession()` dropping a held conversation) apart from a failed
   * send that never had one -- both leave `conversationId() === null`, but only the reset case
   * transitions away from a conversation this tab actually held.
   */
  private lastConversationId: string | null = null;

  constructor() {
    this.lastConversationId = this.turn.conversationId();
    const stops = [
      this.navigation.subscribe(() => this.bump()),
      this.agentStatus.subscribe(() => this.bump()),
      this.agentContext.subscribe(() => this.bump()),
      this.panel.subscribe(() => this.bump()),
      this.turn.subscribe(() => {
        this.syncSecretRecord();
        this.bump();
      }),
      onScopeChange(this.scope, () => this.bump()),
    ];
    const routed = this.router.events.subscribe(() => this.bump());
    inject(DestroyRef).onDestroy(() => {
      for (const stop of stops) stop();
      routed.unsubscribe();
    });
  }

  /** Both facts in, so a gate sentence may name its audience. */
  private get answered(): boolean {
    this.generation();
    return this.navigation.loaded() && this.agentStatus.answered();
  }

  /** Whether the instance holds no enabled definition, which is what the example card is about. */
  protected get unconfigured(): boolean {
    return this.answered && !this.agentStatus.configured();
  }

  /** Whether this caller may enable a definition, and therefore which sentence they are shown. */
  private get administrator(): boolean {
    this.generation();
    return this.navigation.screenVerdict(DEFINITIONS_ROUTE).allowed;
  }

  /** The administrator reminder banner (EXPERIENCE.md's fourth banner slot). */
  protected get reminder(): boolean {
    return this.unconfigured && this.administrator;
  }

  /** The configuration-empty sentence, for a caller who cannot configure a definition. */
  protected get emptySentence(): boolean {
    return this.unconfigured && !this.administrator;
  }

  /** Whether the agent is switched off for this caller (FR-20). */
  protected get killSwitch(): boolean {
    return this.answered && this.agentStatus.restraint().killSwitch;
  }

  /**
   * The published kill-switch banner with its two slots resolved from the verdict: the audience
   * word out of the placeholder itself, and the operator's own reason verbatim.
   */
  protected get killSwitchMessage(): string {
    this.generation();
    const restraint = this.agentStatus.restraint();
    return formatKillSwitch(
      STRINGS.agentKillSwitchBanner,
      restraint.killSwitchAudience,
      restraint.killSwitchReason
    );
  }

  /** Whether read-only is enforced on the instance, which is the one read-only source with a banner. */
  protected get enforcedReadOnly(): boolean {
    return this.answered && this.agentStatus.restraint().enforcedReadOnly;
  }

  /**
   * The footer line, from the key the server's verdict chose and never composed here -- so the
   * line cannot say two things at once when two read-only sources are in force.
   */
  protected get readOnlyLine(): string {
    this.generation();
    return stringFor(this.agentStatus.restraint().footerKey);
  }

  /** Whether a read-only state applies, which turns the footer line restrained. */
  protected get readOnlyOn(): boolean {
    this.generation();
    return this.agentStatus.restraint().footerKey !== 'statusReadOnlyOff';
  }

  /** The composer takes text only while a definition is enabled and the kill switch is off. */
  protected get composerUnavailable(): boolean {
    if (!this.answered) return true;
    return !this.agentStatus.configured() || this.agentStatus.restraint().killSwitch;
  }

  protected get composerAriaDisabled(): string | null {
    return this.composerUnavailable || this.busy ? 'true' : null;
  }

  protected get composerReadonly(): string | null {
    return this.composerUnavailable ? '' : null;
  }

  /**
   * What describes the composer and Send: the topmost reason showing, in EXPERIENCE.md's own
   * order, because that is the one that says why they cannot act. A turn running is the fourth
   * (Story 4.5) -- it never wins over the kill switch or the configuration gate, both of which
   * also make the control unavailable, which busy alone does not. Nothing while nothing is showing.
   */
  protected get describedBy(): string | null {
    if (this.killSwitch) return KILL_SWITCH_ID;
    if (this.unconfigured) return REASON_ID;
    if (this.busy) return BUSY_REASON_ID;
    return null;
  }

  protected get draft(): string {
    this.generation();
    return this.panel.draft();
  }

  /** Whether this tab has a turn running (Story 4.5). */
  protected get busy(): boolean {
    this.generation();
    return this.turn.busy();
  }

  /** Whether the lock banner shows (Story 4.5): this tab's own busy state, or a refused attempt. */
  protected get locked(): boolean {
    this.generation();
    return this.turn.locked();
  }

  protected get sendLabel(): string {
    return this.busy ? STRINGS.actionStop : STRINGS.actionSend;
  }

  /**
   * Send is unavailable for the same reasons the composer is, plus an empty draft while idle --
   * never while busy, when it is Stop and must stay reachable.
   */
  protected get sendAriaDisabled(): string | null {
    if (this.busy) return null;
    if (this.composerUnavailable) return 'true';
    return this.draft.trim() === '' ? 'true' : null;
  }

  protected get newConversationAriaDisabled(): string | null {
    return this.busy || this.composerUnavailable ? 'true' : null;
  }

  protected get newConversationDescribedBy(): string | null {
    return this.busy ? NEW_CONVERSATION_REASON_ID : null;
  }

  /** The transcript's turns, oldest first, with the live one last while a turn runs (Story 4.5). */
  protected get turns(): readonly PanelTurnView[] {
    this.generation();
    return this.turn.entries().map((entry) => {
      const errorBanner = turnErrorBanner(entry, STRINGS.agentTurnStoppedBanner);
      return {
        message: entry.message,
        // Tool steps, the agent's own navigation announcements (Story 4.7), and a stop caught
        // before a model call, which is the only record of that stop.
        steps: entry.steps.filter(
          (step) => step.kind === 'tool' || step.kind === 'announce' || step.status === 'stopped'
        ),
        // A turn ending in an error renders the banner and no reply block (Story 4.6 I/O matrix).
        // The live turn view nulls a non-completed turn's reply server-side, but the restored view
        // emits whatever the row stored, and the job records the loop's reply alongside a `failed`
        // state -- so the pair does reach the client on a reload. The two template blocks are
        // independent, so the exclusion is decided here rather than in a template condition.
        reply: errorBanner === null ? entry.reply : null,
        errorBanner,
      };
    });
  }

  /**
   * An `announce` step's own rendered text (Story 4.7, AD-11 rule 3, AD-33): the target screen's
   * title from `step.target`'s route and, when one was selected, `step.text`'s entity id -- both
   * model-supplied and therefore rendered as `textContent` only, never through `app-reply`'s
   * markdown-shaped renderer.
   */
  protected announceText(step: Pick<TurnStep, 'target' | 'text'>): string {
    const screen = screenForRoute(step.target);
    const title = screen === null ? '' : stringFor(screen.labelKey);
    return formatNavigationAnnouncement(
      STRINGS.agentNavigationAnnouncement,
      STRINGS.agentNavigationAnnouncementNoEntity,
      title,
      step.text
    );
  }

  protected get fullScreen(): boolean {
    this.generation();
    return this.panel.fullScreen();
  }

  protected get fullScreenExpanded(): string {
    return this.fullScreen ? 'true' : 'false';
  }

  /** The toggle's glyph flips with its state (DESIGN.md panel Full screen row). */
  protected get fullScreenGlyph(): string {
    return this.fullScreen ? '\u2922' : '\u2921';
  }

  /** The resize handle is on the docked edge; full screen has no docked edge. */
  protected get docked(): boolean {
    return !this.fullScreen;
  }

  /** The Definitions list, resolved from the screen registry with the current query (AD-5, AD-44). */
  protected get definitionsHref(): string {
    // Relative, so it resolves under the document's base href; the router takes the rooted form.
    return this.definitionsUrl.replace(/^\//, '');
  }

  protected openDefinitions(event: MouseEvent): void {
    if (event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    const url = this.definitionsUrl;
    if (url !== '') void this.router.navigateByUrl(url);
  }

  private get definitionsUrl(): string {
    this.generation();
    const screen = screenForRoute(DEFINITIONS_ROUTE);
    return screen === null ? '' : withQuery(screen.route, this.router.url);
  }

  /**
   * The chip slot's own gate (Boundaries & Constraints "Absent chip"): an enabled definition, an
   * answered `AgentContext`, a resolved namespace, and a URL that resolves to a built descriptor.
   * The third avoids a 422 `TURN.CONTEXT.INVALID` the chip would otherwise advertise sending; the
   * fourth is `assembleScreenContext`'s own "no descriptor resolved" omission -- `app.routes.ts`
   * ends in a `**` route that keeps this panel mounted, and with no screen the chip's
   * `<Screen>, <NAMESPACE>` would read as a sentence with no screen in it.
   */
  protected get contextChipVisible(): boolean {
    this.generation();
    return (
      this.agentStatus.configured() &&
      this.agentContext.answered() &&
      this.scope.namespace() !== '' &&
      screenForUrl(this.router.url) !== null
    );
  }

  protected get secretWarningVisible(): boolean {
    return this.secretWarningVisibleSignal();
  }

  /**
   * "Send anyway": record this exact draft as acknowledged, hide the warning, then run the
   * ordinary send path again -- which now passes its own check because the text matches.
   */
  protected onSendAnyway(): void {
    this.acknowledgedSecretText.set(this.panel.draft());
    this.secretWarningVisibleSignal.set(false);
    void this.sendCurrentDraft();
  }

  /** "Edit": hide the warning and return focus to the composer. Nothing is recorded, so an
   * unchanged text is warned about again on the next Send (Boundaries & Constraints). */
  protected onEditDraft(): void {
    this.secretWarningVisibleSignal.set(false);
    this.composerEl()?.nativeElement.focus();
  }

  protected onDraft(event: Event): void {
    if (this.composerUnavailable) return;
    this.panel.setDraft((event.target as HTMLTextAreaElement).value);
  }

  /**
   * Enter (without Shift) sends, exactly like clicking Send; Shift+Enter is left alone, so the
   * textarea inserts a newline the way it always does. Nothing while the composer is unavailable
   * -- there is no gate sentence to answer by sending.
   */
  protected onComposerKeydown(event: KeyboardEvent): void {
    // An Enter that commits an IME composition is not a send.
    if (event.key !== 'Enter' || event.shiftKey || event.isComposing) return;
    event.preventDefault();
    if (this.composerUnavailable) return;
    void this.sendCurrentDraft();
  }

  /** Stop while a turn runs; otherwise Send -- the one control, the one branch (Story 4.5). */
  protected onSendOrStop(): void {
    if (this.busy) {
      void this.turn.stop();
      return;
    }
    void this.sendCurrentDraft();
  }

  /**
   * `TurnStore.send` decides sent, locally-locked or refused; this only clears the draft on
   * `'sent'` -- a locked or refused attempt leaves it exactly where the user left it (Boundaries
   * & Constraints).
   *
   * **The paste warning gates this, not `onSendOrStop`.** A draft that looks like a secret and
   * has not been acknowledged by this tab's last "Send anyway" raises the warning and returns
   * without sending, keeping the draft and moving no focus (Story 4.11). Screen context is
   * assembled fresh here, at the moment the send actually goes out, never earlier.
   */
  private async sendCurrentDraft(): Promise<void> {
    if (this.composerUnavailable) return;
    const text = this.panel.draft();
    if (text.trim() === '') return;
    if (looksLikeSecret(text) && text !== this.acknowledgedSecretText()) {
      this.secretWarningVisibleSignal.set(true);
      return;
    }
    this.secretWarningVisibleSignal.set(false);
    const outcome = await this.turn.send(text, this.assembleContext());
    if (outcome === 'sent') {
      this.panel.setDraft('');
      this.acknowledgedSecretText.set(null);
    }
  }

  /**
   * The `context` this send carries (Story 4.11, AD-24, AD-42): the screen the user is on right
   * now, read fresh from the router, `ScopeService` and that screen's own `ScreenStore` -- never
   * a value cached from an earlier render.
   */
  private assembleContext(): ScreenContextPayload | null {
    const screen = screenForUrl(this.router.url);
    const store = screen === null ? null : this.screenStores.for(screen.descriptor, screen.refreshRates);
    return assembleScreenContext({
      descriptor: screen,
      namespace: this.scope.namespace(),
      entity: this.currentEntityId(),
      share: this.agentContext.share(),
      rows: store === null ? [] : store.data(),
      filter: store === null ? '' : store.filter(),
      sort: store === null ? '' : store.sort(),
      direction: store === null ? '' : store.direction(),
      rowCap: this.agentContext.contextRowCap(),
    });
  }

  /** The selected entity's id, decoded once (AD-13), the same way `locator-bar.ts` reads it. */
  private currentEntityId(): string {
    let route = this.router.routerState.root;
    while (route.firstChild !== null) route = route.firstChild;
    const raw = route.snapshot.paramMap.get('id');
    return raw === null ? '' : decodeEntityId(raw);
  }

  /**
   * Forget the acknowledged text only on a genuine reset -- `endSession()` dropping a
   * conversation this tab actually held. A failed send (a conversation-creation failure, or a
   * non-404 refusal of `POST /turn`) can leave the same "no conversation, no entries, not busy"
   * shape without ever having reset anything, so the trigger is the *transition* away from a
   * previously-held conversation id, not the shape alone -- otherwise a transient failure would
   * silently forget an acknowledgment and warn again on an identical retry (Boundaries &
   * Constraints: "The record clears on a sent turn and on `endSession()`").
   */
  private syncSecretRecord(): void {
    const current = this.turn.conversationId();
    const wasReset = this.lastConversationId !== null && current === null && this.turn.entries().length === 0 && !this.turn.busy();
    this.lastConversationId = current;
    if (wasReset) {
      this.acknowledgedSecretText.set(null);
      this.secretWarningVisibleSignal.set(false);
    }
  }

  /** A fresh conversation is an explicit reset, so the acknowledgment does not carry into it --
   * `newConversation()` settles a *new* non-null id, which `syncSecretRecord()` cannot read as one. */
  protected onNewConversation(): void {
    if (this.busy || this.composerUnavailable) return;
    this.acknowledgedSecretText.set(null);
    this.secretWarningVisibleSignal.set(false);
    void this.turn.newConversation();
  }

  protected toggleFullScreen(): void {
    this.panel.toggleFullScreen();
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }
}

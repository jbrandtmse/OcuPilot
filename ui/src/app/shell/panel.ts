import { ChangeDetectionStrategy, Component, DestroyRef, ElementRef, inject, signal, viewChild } from '@angular/core';
import { Router } from '@angular/router';

import { AgentContext } from '../core/agent-context';
import {
  AgentStatus,
  DEFINITIONS_ROUTE,
  readOnlyApplies,
  readOnlyFooterLine,
  restraintSentence,
} from '../core/agent-status';
import { decodeEntityId } from '../core/entity-id';
import { classifyFault } from '../core/fault';
import {
  HOME_AREA_KEY,
  NavigationService,
  formatNavigationAnnouncement,
  formatRequires,
  screenForDescriptor,
  screenForEntityType,
  screenForRoute,
  screenForUrl,
  withQuery,
} from '../core/navigation';
import { PanelState } from '../core/panel-layout';
import {
  type ProposalCardView,
  type ProposalPhase,
  countdownPhase,
  countdownRemaining,
  isTerminalPhase,
  phaseForState,
  toCardView,
} from '../core/proposal-view';
import { ScopeService, onScopeChange } from '../core/scope';
import { assembleScreenContext, looksLikeSecret, type ScreenContextPayload } from '../core/screen-context';
import { ScreenStores } from '../core/screen-store';
import { Session } from '../core/session';
import { ShellState } from '../core/shell-state';
import { STRINGS, stringFor } from '../core/strings';
import { SuggestedView, type SuggestedLine } from '../core/suggested-view';
import { TURN_PATH, TurnStore, type TurnProposal, type TurnStep, turnErrorBanner } from '../core/turn';
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

/**
 * One suggested-view row's rendered view, precomputed once per read so the template does no
 * substitution: the text either side of the count, the `Open` anchor's `href`, and the
 * Privilege-Gating attributes its own screen verdict decides (AD-8).
 */
interface SuggestedRowView {
  readonly key: string;
  readonly text: string;
  readonly label: string;
  readonly tail: string;
  readonly counted: boolean;
  readonly count: number;
  readonly href: string;
  readonly url: string;
  readonly gated: boolean;
  readonly openAriaDisabled: string | null;
  readonly openDescribedBy: string | null;
  readonly reasonId: string;
  readonly reason: string;
}

/**
 * One proposal card's rendered view: the mapped content, where it is in the lifecycle, and the id
 * `@for` tracks it by -- so a card keeps its own masked-field input and disclosure state across a
 * poll that re-reads the turn.
 */
interface PanelProposalView {
  readonly proposalId: string;
  readonly view: ProposalCardView;
  readonly phase: ProposalPhase;
}

/** One turn's rendered view, precomputed once per read so the template does no substitution. */
interface PanelTurnView {
  readonly message: string;
  readonly steps: readonly TurnStep[];
  readonly proposals: readonly PanelProposalView[];
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
 * reminder, lock (Story 4.5) -- then the refused-Send banner (Story 4.8), which EXPERIENCE.md's
 * list does not carry: it is placed last in the strip because it is about the press the user just
 * made, not about the state the panel is in; the context chip, filled in by Story 4.11;
 * the transcript, a
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
 * never guesses which. A refusal that is not a 409 raises its own banner carrying the instance's
 * own reason (Story 4.8), and the draft stays where the user left it either way.
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
        @if (sendErrorText !== null) {
          <p class="ocu-banner ocu-banner-warning ocu-panel-banner" role="alert" data-slot="send-error">
            <span class="ocu-banner-glyph" aria-hidden="true">{{ bannerGlyph }}</span>
            <span class="ocu-banner-message">{{ sendErrorText }}</span>
          </p>
        }
      </div>

      <div class="ocu-panel-chip-slot">
        @if (contextChipVisible) {
          <app-context-chip [killSwitch]="killSwitch" />
        }
      </div>

      <section class="ocu-suggested" [attr.aria-labelledby]="suggestedVisible ? suggestedLabelId : null">
        @if (suggestedVisible) {
          <p class="ocu-suggested-eyebrow" [id]="suggestedLabelId">{{ STRINGS.homeSuggestedView }}</p>
          <ul class="ocu-suggested-lines" role="list">
            @for (row of suggestedRows; track row.key) {
              <li class="ocu-suggested-line">
                <button
                  type="button"
                  class="ocu-suggested-prompt"
                  (click)="onSuggestion(row.text)"
                >{{ row.label }}@if (row.counted) {<code class="ocu-suggested-count">{{ row.count }}</code>}{{ row.tail }}</button>
                <span class="ocu-suggested-open-slot">
                  <a
                    class="ocu-button-text ocu-suggested-open"
                    [href]="row.href"
                    [attr.aria-disabled]="row.openAriaDisabled"
                    [attr.aria-describedby]="row.openDescribedBy"
                    (click)="onSuggestionOpen($event, row)"
                    >{{ STRINGS.homeSuggestedOpen }}<span aria-hidden="true">{{ openGlyph }}</span></a
                  >
                  @if (row.gated) {
                    <span class="ocu-suggested-reason" role="tooltip" [id]="row.reasonId">{{
                      row.reason
                    }}</span>
                  }
                </span>
              </li>
            }
            @for (prompt of suggestedPrompts; track prompt) {
              <li class="ocu-suggested-line">
                <button type="button" class="ocu-suggested-starter" (click)="onSuggestion(prompt)">
                  <span>{{ prompt }}</span>
                  <span class="ocu-suggested-send-glyph" aria-hidden="true">{{ sendGlyph }}</span>
                </button>
              </li>
            }
          </ul>
        }
      </section>

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
          @if (greetingVisible) {
            <p class="ocu-panel-greeting">{{ STRINGS.agentIdleGreeting }}</p>
            <ul class="ocu-suggested-lines" role="list">
              @for (prompt of starterPrompts; track prompt) {
                <li class="ocu-suggested-line">
                  <button type="button" class="ocu-suggested-starter" (click)="onSuggestion(prompt)">
                    <span>{{ prompt }}</span>
                    <span class="ocu-suggested-send-glyph" aria-hidden="true">{{ sendGlyph }}</span>
                  </button>
                </li>
              }
            </ul>
            <p class="ocu-panel-selection-hint">{{ STRINGS.agentIdleSelectionHint }}</p>
          }
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
              @for (proposal of turn.proposals; track proposal.proposalId) {
                <app-proposal-card
                  [view]="proposal.view"
                  [phase]="proposal.phase"
                  [nowMs]="nowMs"
                  [userName]="userName"
                  (cancel)="onCardCancel($event)"
                />
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
          class="ocu-panel-send"
          [class.ocu-button-primary]="!sendSecondary"
          [class.ocu-button-secondary]="sendSecondary"
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
  private readonly session = inject(Session);
  private readonly screenStores = inject(ScreenStores);
  private readonly shell = inject(ShellState);
  private readonly suggested = inject(SuggestedView);

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

  /** The suggested view's own labelling id: the eyebrow names the section. */
  protected readonly suggestedLabelId = 'ocu-suggested-label';

  /** The `Open` control's decorative chevron (DESIGN.md `:1137` "Open \u203A"), `aria-hidden`. */
  protected readonly openGlyph = '\u203A';

  /** A starter prompt row's send glyph (DESIGN.md `:1137`), `aria-hidden`. */
  protected readonly sendGlyph = '\u27A4';

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

  /** The namespace the block was last read for on this visit to Home, or `null` (`syncSuggested`). */
  private suggestedLoadedFor: string | null = null;

  /**
   * The moment every live card's countdown reads, from the panel's one ticker.
   *
   * One timer for the whole transcript rather than one per card, and armed only while a card is
   * live (`syncTicker`): the cards are pure functions of this number (AD-19), which is also what
   * lets `proposal-card.spec.ts` drive 1:00 and 0:00 by hand.
   */
  private readonly nowSignal = signal(Date.now());

  private ticker: ReturnType<typeof setInterval> | null = null;

  /**
   * The terminal phase this panel has decided for a proposal, by id -- the client-side half of the
   * lifecycle (EXPERIENCE.md's cancel step): Cancel, a typed message and New conversation. Story
   * 5.3 makes the confirmed, canceled and target-changed lines the instance's own; until then the
   * wire's `state` is `live` on every row and this map is what moves a card off it.
   */
  private readonly cardPhases = signal<ReadonlyMap<string, ProposalPhase>>(new Map());

  constructor() {
    this.lastConversationId = this.turn.conversationId();
    const stops = [
      this.navigation.subscribe(() => {
        this.bump();
        // The map is the other half of `answered`, and it can settle last: `App` issues the map,
        // the namespace list and the status read concurrently. Every store in the block's gate
        // therefore re-asks here, or a visit whose map answered last would render no block at all.
        this.syncSuggested();
      }),
      this.agentStatus.subscribe(() => {
        this.bump();
        // The block's own precondition is an enabled definition, and this is where that answer
        // arrives -- so this is where the block becomes eligible to read.
        this.syncSuggested();
      }),
      this.agentContext.subscribe(() => this.bump()),
      this.panel.subscribe(() => this.bump()),
      this.turn.subscribe(() => {
        this.syncSecretRecord();
        this.bump();
      }),
      onScopeChange(this.scope, () => {
        this.bump();
        // AD-44: a namespace switch re-fetches rather than re-routes, so the application-errors
        // line's read re-issues for the new namespace and its text re-resolves.
        this.syncSuggested();
      }),
      this.suggested.subscribe(() => this.bump()),
      this.shell.subscribe(() => {
        this.bump();
        this.syncSuggested();
      }),
    ];
    this.syncSuggested();
    const routed = this.router.events.subscribe(() => this.bump());
    inject(DestroyRef).onDestroy(() => {
      for (const stop of stops) stop();
      routed.unsubscribe();
      if (this.ticker !== null) clearInterval(this.ticker);
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
   * The published kill-switch banner with its two slots resolved from the verdict, from the one
   * selector Home's agent-status line reads as well. Rendered only while `killSwitch` is true, so
   * the selector's kill-switch arm is the one this gets.
   */
  protected get killSwitchMessage(): string {
    this.generation();
    return restraintSentence(this.agentStatus.restraint());
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
    return readOnlyFooterLine(this.agentStatus.restraint());
  }

  /** Whether a read-only state applies, which turns the footer line restrained. */
  protected get readOnlyOn(): boolean {
    this.generation();
    return readOnlyApplies(this.agentStatus.restraint());
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

  /**
   * The refused-Send banner's sentence, or `null` when the last Send was not refused (Story 4.8,
   * DW-1054). A 409 is the lock banner's and never reaches here.
   *
   * It is the envelope's own written `reason` wherever the instance sent one -- the server writes
   * every refusal sentence once (AD-39) and the client publishes none of that copy. Only an answer
   * carrying no envelope at all (a status 0, a body that is not one) falls back, to the
   * connectivity sentence the shell already shows for that class of failure, chosen by
   * `classifyFault` so the two surfaces cannot disagree about which failure it was.
   */
  protected get sendErrorText(): string | null {
    this.generation();
    const refusal = this.turn.sendError();
    if (refusal === null) return null;
    if (refusal.reason !== null && refusal.reason !== '') return refusal.reason;
    const fault = classifyFault(
      { kind: 'error', status: refusal.status, code: refusal.code, reason: null, detail: null },
      TURN_PATH
    );
    return fault?.kind === 'unreachable' ? STRINGS.connectivityBannerUnreachable : STRINGS.connectivityServerFault;
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
      const errorBanner = turnErrorBanner(
        entry,
        STRINGS.agentTurnStoppedBanner,
        STRINGS.agentTurnStoppedNoStepBanner
      );
      const proposals = entry.proposals.map((proposal) => this.proposalView(proposal));
      return {
        message: entry.message,
        // Tool steps, the agent's own navigation announcements (Story 4.7), and a stop caught
        // before a model call, which is the only record of that stop.
        steps: entry.steps.filter(
          (step) => step.kind === 'tool' || step.kind === 'announce' || step.status === 'stopped'
        ),
        // One card per wire proposal, in wire order, each with its own Confirm and Cancel. There
        // is no batch control anywhere in this panel: one decision at a time (SM-C2).
        proposals,
        // A turn ending in an error renders the banner and no reply block (Story 4.6 I/O matrix).
        // The live turn view nulls a non-completed turn's reply server-side, but the restored view
        // emits whatever the row stored, and the job records the loop's reply alongside a `failed`
        // state -- so the pair does reach the client on a reload. The two template blocks are
        // independent, so the exclusion is decided here rather than in a template condition.
        reply: errorBanner === null ? this.replyWithConfirmSentence(entry.reply, proposals) : null,
        errorBanner,
      };
    });
  }

  /**
   * One proposal's card view: the mapped content, and the phase this panel resolves for it.
   *
   * The singular entity noun and the declared secret argument names are the target screen's own
   * (AD-5, AD-14), resolved through the generated mirror by the reference triple's entity type and
   * passed to the mapper as data -- which is what keeps the mapper testable before any descriptor
   * declares a secret argument.
   */
  private proposalView(proposal: TurnProposal): PanelProposalView {
    const screen = screenForEntityType(proposal.target.type);
    return {
      proposalId: proposal.proposalId,
      view: toCardView(
        proposal,
        screen === null ? '' : stringFor(screen.entityLabelKey),
        screen === null ? [] : screen.secretArguments
      ),
      phase: this.phaseFor(proposal),
    };
  }

  /**
   * Where one card is: this panel's own decision where it has made one, else the wire's state --
   * and `switched-off` over a live card while the agent is off, because a card that cannot be
   * confirmed must not offer Confirm (EXPERIENCE.md's kill-switch step).
   */
  private phaseFor(proposal: TurnProposal): ProposalPhase {
    const decided = this.cardPhases().get(proposal.proposalId);
    if (decided !== undefined) return decided;
    const phase = phaseForState(proposal.state);
    if (phase !== 'live') return phase;
    // The clock is read through the same two `core/proposal-view.ts` functions the card itself
    // reads (`ProposalCard.livePhase`), because the two must not be able to disagree: a card that
    // draws itself `Expired` while this panel still counts it live would leave Send secondary with
    // no Confirm anywhere in the view, keep the ticker armed, and let a later typed message
    // relabel an expired card and take its Re-propose away.
    const remaining = countdownRemaining(proposal.expiresAt, this.nowSignal());
    if (remaining !== null && countdownPhase(remaining) === 'expired') return 'expired';
    return this.killSwitch ? 'switched-off' : phase;
  }

  /**
   * `reply` with the published confirm sentence at its end when this turn minted a card that is
   * still live, else `reply` unchanged.
   *
   * It is appended rather than expected of the model: the sentence is the panel's own published
   * copy, so a turn whose reply arrived without it still points the user at Confirm instead of
   * inviting the "yes" that cancels the card.
   */
  private replyWithConfirmSentence(
    reply: string | null,
    proposals: readonly PanelProposalView[]
  ): string | null {
    if (reply === null) return null;
    if (!proposals.some((proposal) => !isTerminalPhase(proposal.phase))) return reply;
    if (reply.trimEnd().endsWith(STRINGS.proposalConfirmSentence)) return reply;
    return reply + '\n\n' + STRINGS.proposalConfirmSentence;
  }

  /** The moment the cards read, from the panel's one ticker. */
  protected get nowMs(): number {
    return this.nowSignal();
  }

  /** The account a confirmed write would run as, for the footer's caption and the confirmed line. */
  protected get userName(): string {
    this.generation();
    return this.session.userName();
  }

  /**
   * Whether any card in the transcript is still live, which is what drops Send to secondary so
   * Confirm is the only filled button in the view (DESIGN.md `:1184` Live row), and what arms the
   * countdown's ticker.
   */
  protected get sendSecondary(): boolean {
    this.generation();
    return this.liveCards.length > 0;
  }

  /** Every proposal in the transcript that is not terminal, by id. */
  private get liveCards(): readonly string[] {
    const live: string[] = [];
    for (const entry of this.turn.entries()) {
      for (const proposal of entry.proposals) {
        if (!isTerminalPhase(this.phaseFor(proposal))) live.push(proposal.proposalId);
      }
    }
    return live;
  }

  /**
   * Record `phase` for every card that is still live. The one place a client-side transition is
   * made, so "a typed message cancels every live card", "New conversation cancels every live card"
   * and "Stop cancels nothing" are one mechanism with three callers rather than three.
   */
  private cancelLiveCards(phase: ProposalPhase): void {
    const live = this.liveCards;
    if (live.length === 0) return;
    const next = new Map(this.cardPhases());
    for (const id of live) next.set(id, phase);
    this.cardPhases.set(next);
    this.bump();
  }

  /** Cancel was pressed on one card: its own transition, and no other card's. */
  protected onCardCancel(proposalId: string): void {
    if (proposalId === '') return;
    const next = new Map(this.cardPhases());
    next.set(proposalId, 'canceled-by-you');
    this.cardPhases.set(next);
    this.bump();
  }

  /** Arm the one-second ticker while a card is live, and disarm it when none is. */
  private syncTicker(): void {
    const wanted = this.liveCards.length > 0;
    if (wanted && this.ticker === null) {
      // Seeded at the arming, not only on the first tick: `nowSignal` holds whatever the last tick
      // before the previous disarm left, so a panel that has been idle would draw a brand-new
      // card's countdown from that stale moment -- `Expires in 70:00` on a ten-minute proposal --
      // until a second later.
      this.nowSignal.set(Date.now());
      this.ticker = setInterval(() => {
        this.nowSignal.set(Date.now());
        // Re-asked on the tick, because the tick is the only thing that can retire the last live
        // card: a countdown running out raises no event, so without this the interval would run
        // for the panel's whole life.
        this.syncTicker();
      }, 1000);
    } else if (!wanted && this.ticker !== null) {
      clearInterval(this.ticker);
      this.ticker = null;
    }
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

  /** Whether the router is on Home, which is the only area the suggested view renders on. */
  private get onHome(): boolean {
    this.generation();
    return this.shell.activeArea() === HOME_AREA_KEY;
  }

  /**
   * The suggested view's own gate (AC1's precondition): Home, an answered status with an enabled
   * definition, and every declared source answered or settled to absent. The block renders nothing
   * until all of it holds -- never a partial block, never a flash of prompts.
   */
  protected get suggestedVisible(): boolean {
    this.generation();
    return this.onHome && this.answered && this.agentStatus.configured() && this.suggested.answered();
  }

  /**
   * The counted rows, or -- when every counted line resolved to zero -- only the uncounted ones,
   * which is what keeps the agent-status line present under the starter prompts (AC6).
   */
  protected get suggestedRows(): readonly SuggestedRowView[] {
    this.generation();
    const prompts = this.suggested.showPrompts();
    return this.suggested
      .lines()
      .filter((line) => !prompts || !line.counted)
      .map((line) => this.suggestedRow(line));
  }

  /**
   * The three published prompts while every counted line reads zero, else nothing -- and nothing
   * while the greeting is already offering them, so exactly one prompt set is ever on screen.
   * EXPERIENCE.md reads Home's panel as showing "its suggested view or, when nothing needs
   * attention, three starter prompts"; it publishes the greeting "over the screen's three starter
   * prompts, and beneath them the hint"; and its UJ-2 walkthrough describes the fresh-container
   * state -- the one where both would otherwise fire -- as "the suggested view offering the three
   * starter prompts", singular. The greeting keeps them because only its order is published; the
   * block keeps its agent-status line either way (AC2).
   */
  protected get suggestedPrompts(): readonly string[] {
    this.generation();
    if (this.transcriptEmpty) return [];
    return this.suggested.showPrompts() ? this.suggested.starterPrompts() : [];
  }

  /** The three published prompts, for the empty-transcript greeting, which never counts anything. */
  protected get starterPrompts(): readonly string[] {
    return this.suggested.starterPrompts();
  }

  /**
   * Whether the conversation has been restored and holds no turn. `restored()` is what keeps the
   * greeting from flashing before the transcript loads.
   */
  protected get transcriptEmpty(): boolean {
    this.generation();
    return this.turn.restored() && this.turn.entries().length === 0;
  }

  /**
   * Whether the greeting block renders. EXPERIENCE.md's panel state table triggers "Idle, no
   * messages yet" on "definition enabled, transcript empty", so the status has to have answered
   * AND report a definition: the transcript's `@else` branch is reached whenever the panel is not
   * known-unconfigured, which includes the window before the status answers at all.
   */
  protected get greetingVisible(): boolean {
    this.generation();
    return this.answered && this.agentStatus.configured() && this.transcriptEmpty;
  }

  /**
   * One line's rendered row. The `Open` control's target is resolved from the line's declared
   * descriptor (AD-5), and its own screen verdict decides the Privilege-Gating attributes: listed,
   * focusable, `aria-disabled` and described by the pair that failed -- never removed, never
   * natively `disabled` (AD-8).
   */
  private suggestedRow(line: SuggestedLine): SuggestedRowView {
    const screen = screenForDescriptor(line.descriptor);
    const url = screen === null ? '' : withQuery(screen.route, this.router.url);
    const verdict = screen === null ? null : this.navigation.screenVerdict(screen.route);
    const gated = verdict !== null && !verdict.allowed;
    const reasonId = `ocu-suggested-reason-${line.key}`;
    return {
      key: line.key,
      text: line.text,
      label: line.label,
      tail: line.tail,
      counted: line.counted,
      count: line.count,
      // Relative, so it resolves under the document's base href; the router takes the rooted form.
      href: url.replace(/^\//, ''),
      url,
      gated,
      openAriaDisabled: gated ? 'true' : null,
      openDescribedBy: gated ? reasonId : null,
      reasonId,
      reason: formatRequires(
        STRINGS.privilegeRequiresResource,
        verdict === null ? '' : verdict.failedPair
      ),
    };
  }

  /**
   * A line's text or a starter prompt was activated: it becomes the draft and the composer takes
   * focus. It never starts a turn -- the user reads what they are about to ask and presses Send.
   *
   * Nothing while the composer is unavailable, as every other write into the draft does
   * (`onDraft`, `onComposerKeydown`): with the kill switch on the block still renders -- its
   * agent-status line is that state's own sentence -- and the composer is `readonly`, so a draft
   * placed there is text the user cannot send.
   */
  protected onSuggestion(text: string): void {
    if (this.composerUnavailable) return;
    this.panel.setDraft(text);
    this.composerEl()?.nativeElement.focus();
  }

  /**
   * A line's `Open` was activated: the router navigates to that line's screen. A modified click on
   * a reachable target is left to the browser; a gated anchor is refused first, whatever the
   * modifiers, because `aria-disabled` carries no behavior of its own and a Ctrl- or Cmd-click
   * that fell through to the modifier bail would open the refused screen in a new tab.
   */
  protected onSuggestionOpen(event: MouseEvent, row: SuggestedRowView): void {
    if (row.gated || row.url === '') {
      event.preventDefault();
      return;
    }
    if (event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    void this.router.navigateByUrl(row.url);
  }

  /**
   * Read the block's sources once the block could render, and forget them on leaving Home, so the
   * next visit reads fresh rather than rendering an answer about a screen the user has left.
   *
   * **The namespace is the key**, which is what bounds this to one call per line per Home visit per
   * namespace (AD-24): every store this reads answers a round trip after the panel is built, so
   * this runs on each of their notifications, and without a key it would read on all of them. A
   * namespace switch is a different question and reads once (AD-44). Home is not in AD-43's
   * refresh roster, so there is no timer.
   *
   * It withholds the read until the block's own preconditions hold -- Home, an answered status
   * with an enabled definition, and a resolved namespace -- rather than reading and discarding:
   * an unscoped read is one the endpoint answers 404, and a read nothing will render is a request
   * for nothing.
   */
  private syncSuggested(): void {
    const onHome = this.shell.activeArea() === HOME_AREA_KEY;
    if (!onHome) {
      if (this.suggestedLoadedFor !== null) {
        this.suggestedLoadedFor = null;
        this.suggested.reset();
      }
      return;
    }
    const namespace = this.scope.namespace();
    if (namespace === '' || !this.answered || !this.agentStatus.configured()) return;
    if (this.suggestedLoadedFor === namespace) return;
    const previous = this.suggestedLoadedFor;
    this.suggestedLoadedFor = namespace;
    // A switch away from a namespace already read is a different question, so the previous
    // namespace's answers are dropped before the new read: without this the block keeps rendering
    // "Application errors in <previous>: ..." for the length of the re-read, which is the partial
    // state the block's own gate exists to prevent. The first read of a visit has nothing to drop.
    if (previous !== null) this.suggested.reset();
    void this.suggested.load();
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

  /**
   * Stop while a turn runs; otherwise Send -- the one control, the one branch (Story 4.5).
   *
   * **Stop cancels no card.** A stop is not a new turn, so a proposal already posted in that turn
   * stays live and confirmable (EXPERIENCE.md's Stopped-by-you row): the cancel is `Send`'s and
   * `New conversation`'s, and this branch deliberately does neither.
   */
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
    // EXPERIENCE.md's cancel step: sending a message cancels every live proposal, which is what
    // the card's own guard caption warns about. Recorded before the request goes out, so a user
    // who types "yes" from habit never sees a card that still offers Confirm.
    this.cancelLiveCards('canceled-by-message');
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
    // "New conversation cancels every live proposal exactly as a new turn would" -- and, unlike a
    // new turn, it also clears the transcript, so the cards go with it.
    this.cancelLiveCards('canceled-by-you');
    void this.turn.newConversation();
  }

  protected toggleFullScreen(): void {
    this.panel.toggleFullScreen();
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
    this.syncTicker();
  }
}

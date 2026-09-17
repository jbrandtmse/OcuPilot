import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { AgentStatus, DEFINITIONS_ROUTE, formatKillSwitch } from '../core/agent-status';
import { NavigationService, screenForRoute, withQuery } from '../core/navigation';
import { PanelState } from '../core/panel-layout';
import { STRINGS, stringFor } from '../core/strings';
import { isApplePlatform } from './command-box';
import { EXAMPLE_PROPOSAL } from './example-proposal';
import { PanelResizeHandle } from './panel-resize-handle';
import { ProposalCard } from './proposal-card';

/** The composer's control id: its label, both `aria-describedby` wires and the Ctrl/Cmd+I target. */
export const COMPOSER_ID = 'ocu-panel-composer';

/** The id of whichever gate sentence the panel is showing, which is also the controls' reason. */
const REASON_ID = 'ocu-panel-reason';

/** The kill-switch banner's own id, which is the controls' reason while the agent is switched off. */
const KILL_SWITCH_ID = 'ocu-panel-kill-switch';

/** The enforced-read-only banner's own id. */
const READ_ONLY_ID = 'ocu-panel-read-only';

/**
 * The agent co-pilot panel, docked right of every signed-in route (EXPERIENCE.md panel).
 *
 * **Anatomy, top to bottom.** The resize handle on the left edge (absent in full screen); the
 * header with the avatar, "Agent co-pilot" and the full-screen toggle; the banner slots in
 * EXPERIENCE.md's fixed order -- kill switch, enforced read-only, "not being marked" (Epic 5),
 * administrator reminder, lock (Story 4.5); the context-chip slot (Story 4.4); the transcript, a
 * polite `role="log"` named "Conversation" that scrolls by itself; and the footer with the read-only
 * line, the composer, Send and the caption. There is no close control.
 *
 * **Every fact is read, none remembered here.** Whether a definition is enabled and the restraint
 * verdict come from `AgentStatus`; whether this caller may configure one is the navigation map's
 * verdict for `agent/definitions` (AD-8); the draft, the width and full screen are `PanelState`'s.
 * The gate sentences render only once the map has loaded and the status has answered, so no
 * audience is guessed at: `loaded()`, not `answered()`, because a failed map read leaves every
 * verdict allowed.
 *
 * **The composer** is editable while a definition is enabled and nothing restrains the agent, and
 * its text is `PanelState`'s draft, so a route change keeps it. Otherwise it is `readonly` beside
 * `aria-disabled`, described by the sentence that says why, and never natively disabled. Send stays
 * `aria-disabled` until turns exist (Story 4.5).
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group.
 */
@Component({
  selector: 'app-panel',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ProposalCard, PanelResizeHandle],
  template: `<aside class="ocu-panel" [class.ocu-panel-full-screen]="fullScreen" [attr.aria-label]="panelName">
    @if (docked) {
      <app-panel-resize-handle />
    }
    <div class="ocu-panel-header">
      <span class="ocu-panel-avatar" aria-hidden="true"></span>
      <h2 class="ocu-panel-title">{{ panelName }}</h2>
      <button
        type="button"
        class="ocu-panel-icon-button ocu-panel-full-screen-toggle"
        [attr.aria-label]="STRINGS.agentPanelFullScreen"
        [attr.aria-expanded]="fullScreenExpanded"
        (click)="toggleFullScreen()"
      >
        <span class="ocu-panel-icon-glyph" aria-hidden="true">{{ fullScreenGlyph }}</span>
      </button>
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
        <div class="ocu-panel-banner-slot" data-slot="lock"></div>
      </div>

      <div class="ocu-panel-chip-slot"></div>

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
        }
      </div>
    </div>

    <div class="ocu-panel-footer">
      <p class="ocu-panel-read-only">{{ readOnlyLine }}</p>
      <label class="ocu-field-label" [attr.for]="composerId">{{ STRINGS.agentComposerLabel }}</label>
      <div class="ocu-panel-composer-row">
        <textarea
          class="ocu-panel-composer"
          rows="1"
          [class.ocu-panel-composer-unavailable]="composerUnavailable"
          [id]="composerId"
          [value]="draft"
          [attr.aria-disabled]="composerAriaDisabled"
          [attr.readonly]="composerReadonly"
          [attr.aria-describedby]="describedBy"
          (input)="onDraft($event)"
        ></textarea>
        <button
          type="button"
          class="ocu-button-primary ocu-panel-send"
          aria-disabled="true"
          [attr.aria-describedby]="describedBy"
        >
          {{ STRINGS.actionSend }}
        </button>
      </div>
      <p class="ocu-panel-caption">{{ caption }}</p>
    </div>
  </aside>`,
})
export class Panel {
  private readonly navigation = inject(NavigationService);
  private readonly agentStatus = inject(AgentStatus);
  private readonly panel = inject(PanelState);
  private readonly router = inject(Router);

  protected readonly STRINGS = STRINGS;

  /** The panel's landmark name and title: the area's own, which is what the Landmarks line names it. */
  protected readonly panelName = STRINGS.navAreaAgent;

  protected readonly composerId = COMPOSER_ID;

  protected readonly reasonId = REASON_ID;

  protected readonly killSwitchId = KILL_SWITCH_ID;

  protected readonly readOnlyId = READ_ONLY_ID;

  /** The banner's glyph, `aria-hidden` so the strip reads as its sentence alone. */
  protected readonly bannerGlyph = '\u2139';

  /** The caption, with the chord spelled the way the platform spells it. */
  protected readonly caption = isApplePlatform() ? STRINGS.agentComposerCaptionMac : STRINGS.agentComposerCaption;

  /** UJ-3's card, as data (`example-proposal.ts`). Never a timer, a button or a focus stop. */
  protected readonly example = EXAMPLE_PROPOSAL;

  /** Bumped by every source, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  constructor() {
    const stops = [
      this.navigation.subscribe(() => this.bump()),
      this.agentStatus.subscribe(() => this.bump()),
      this.panel.subscribe(() => this.bump()),
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

  /** The composer takes text only while a definition is enabled and nothing restrains the agent. */
  protected get composerUnavailable(): boolean {
    if (!this.answered) return true;
    return !this.agentStatus.configured() || this.agentStatus.restrained();
  }

  protected get composerAriaDisabled(): string | null {
    return this.composerUnavailable ? 'true' : null;
  }

  protected get composerReadonly(): string | null {
    return this.composerUnavailable ? '' : null;
  }

  /**
   * What describes the composer and Send: the topmost reason showing, in EXPERIENCE.md's own
   * order, because that is the one that says why they cannot act. Nothing while nothing is showing.
   */
  protected get describedBy(): string | null {
    if (this.killSwitch) return KILL_SWITCH_ID;
    if (this.enforcedReadOnly) return READ_ONLY_ID;
    if (this.unconfigured) return REASON_ID;
    return null;
  }

  protected get draft(): string {
    this.generation();
    return this.panel.draft();
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

  protected onDraft(event: Event): void {
    if (this.composerUnavailable) return;
    this.panel.setDraft((event.target as HTMLTextAreaElement).value);
  }

  protected toggleFullScreen(): void {
    this.panel.toggleFullScreen();
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }
}

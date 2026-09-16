import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { AgentStatus, DEFINITIONS_ROUTE, formatKillSwitch } from '../core/agent-status';
import { NavigationService } from '../core/navigation';
import { STRINGS, stringFor } from '../core/strings';
import { EXAMPLE_PROPOSAL } from './example-proposal';
import { ProposalCard } from './proposal-card';

/** The composer's control id, so its label and both `aria-describedby` wires resolve. */
const COMPOSER_ID = 'ocu-panel-composer';

/** The id of whichever sentence the panel is showing, which is also the controls' reason. */
const REASON_ID = 'ocu-panel-reason';

/** The kill-switch banner's own id, which is the controls' reason while the agent is switched off. */
const KILL_SWITCH_ID = 'ocu-panel-kill-switch';

/** The enforced-read-only banner's own id. */
const READ_ONLY_ID = 'ocu-panel-read-only';

/**
 * The agent co-pilot panel, in the one state Release 1 reaches before a definition exists: the
 * configuration-empty state and the administrator reminder (FR-28).
 *
 * **Two facts, both re-read and neither remembered.** Whether any definition is enabled comes from
 * `AgentStatus`, which reads the ungated selection list; whether this caller may fix that comes
 * from the navigation map's verdict for `agent/definitions`, recomputed on the instance per call
 * (AD-8). The panel mints no second privilege source and caches neither answer.
 *
 * **It renders nothing until both have answered.** Before the map arrives every verdict defaults
 * to *allowed* (`navigation.ts`'s `UNGATED`), which would show an administrator's reminder banner
 * to somebody who cannot act on it, and an unanswered definitions read would show an empty state
 * over a configured instance. Neither is a state this panel guesses at.
 *
 * **The map signal is `loaded()`, not `answered()`.** `answered()` is true once a read *completes*,
 * "with a map or with a failure" -- a failed read leaves every verdict `UNGATED`, which is the
 * right answer for gating (the server is the gate, AD-8: fail open rather than lock a holder out)
 * and the wrong one here. This panel is not gating anything; it is choosing which of two published
 * sentences a person reads, and failing open there tells a non-administrator that configuring the
 * agent is their job. A map that never arrived is parked and re-read, so the cost is a panel that
 * appears a moment later rather than one that addresses the wrong reader.
 *
 * **Its only exit is a definition being enabled.** There is no dismiss control, no "don't show
 * this again", nothing stored: `Enable` on the Definitions list publishes `changed` on the bus,
 * `AgentStatus` re-reads, and the banner, the example card and the rail's dot all clear together.
 *
 * **Three facts now, not two** (Story 3.7). The restraint verdict joins them, read from the same
 * service on the same three triggers, so the panel issues no call of its own for it: the kill
 * switch and enforced read-only each raise their published banner, and the footer's read-only line
 * renders the one key the verdict chose. The client composes no sentence of its own -- the audience
 * and the reason are the verdict's, resolved into the published banner's own slots.
 *
 * **Banner order is EXPERIENCE.md's**: kill switch, then enforced read-only, then the
 * administrator reminder or the configuration-empty sentence. The composer and Send are described
 * by whichever is showing, topmost first, because that is the one that says why they cannot act.
 *
 * **This is not Story 4.3's panel.** No resize handle, no full-screen toggle, no transcript, no
 * context chip, no New conversation and no header controls: those arrive with the panel that is
 * unconditional. What is here is the banners, the empty state, the static example card and the
 * footer's read-only line and two gated controls -- focusable, `aria-disabled` and described by
 * the sentence the panel is showing, never carrying the `disabled` attribute (EXPERIENCE.md's
 * Privilege Gating mechanism). The composer is `readonly` beside its `aria-disabled`, which is the
 * pairing this product's own gated input already uses (`definition-form.page.ts`'s retention
 * field): `aria-disabled` alone announces a control as inert and then lets the reader type a whole
 * message into it.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group.
 */
@Component({
  selector: 'app-panel',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ProposalCard],
  template: `@if (shown) {
    <aside class="ocu-panel" [attr.aria-label]="panelName">
      <div class="ocu-panel-body">
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
        @if (unconfigured) {
          @if (administrator) {
            <p class="ocu-banner ocu-banner-info ocu-panel-banner" [id]="reasonId">
              <span class="ocu-banner-glyph" aria-hidden="true">{{ bannerGlyph }}</span>
              <span class="ocu-banner-message">{{ STRINGS.agentGateReminderBanner }}</span>
            </p>
          } @else {
            <p class="ocu-panel-empty" [id]="reasonId">{{ STRINGS.agentGateEmptyState }}</p>
          }
        }

        @if (unconfigured) {
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

      <div class="ocu-panel-footer">
        <p class="ocu-panel-read-only">{{ readOnlyLine }}</p>
        <label class="ocu-field-label" [attr.for]="composerId">{{ STRINGS.agentComposerLabel }}</label>
        <div class="ocu-panel-composer-row">
          <textarea
            class="ocu-panel-composer"
            rows="2"
            aria-disabled="true"
            readonly
            [id]="composerId"
            [attr.aria-describedby]="describedBy"
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
        <p class="ocu-panel-caption">{{ STRINGS.agentComposerCaption }}</p>
      </div>
    </aside>
  }`,
})
export class Panel {
  private readonly navigation = inject(NavigationService);
  private readonly agentStatus = inject(AgentStatus);

  protected readonly STRINGS = STRINGS;

  /** The panel's landmark name: the area's own, which is what the Landmarks line names it. */
  protected readonly panelName = STRINGS.navAreaAgent;

  protected readonly composerId = COMPOSER_ID;

  protected readonly reasonId = REASON_ID;

  protected readonly killSwitchId = KILL_SWITCH_ID;

  protected readonly readOnlyId = READ_ONLY_ID;

  /** The banner's glyph, `aria-hidden` so the strip reads as its sentence alone. */
  protected readonly bannerGlyph = '\u2139';

  /** UJ-3's card, as data (`example-proposal.ts`). Never a timer, a button or a focus stop. */
  protected readonly example = EXAMPLE_PROPOSAL;

  /** Bumped by both sources, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  constructor() {
    const stopNavigation = this.navigation.subscribe(() => this.bump());
    const stopStatus = this.agentStatus.subscribe(() => this.bump());
    inject(DestroyRef).onDestroy(() => {
      stopNavigation();
      stopStatus();
    });
  }

  /**
   * Whether the panel draws anything at all: both facts in, and the agent either unconfigured or
   * restrained.
   *
   * A configured, unrestrained instance still gets nothing here -- the transcript and its chrome
   * are Story 4.3's -- and the host element collapses rather than reserving 400px of a screen it
   * has nothing to say about (`app-panel:empty` in the stylesheet). The footer's read-only line is
   * "always shown" inside the panel, which is what it means while the panel itself is conditional.
   */
  protected get shown(): boolean {
    this.generation();
    if (!this.navigation.loaded() || !this.agentStatus.answered()) return false;
    return !this.agentStatus.configured() || this.agentStatus.restrained();
  }

  /** Whether the instance holds no enabled definition, which is what the empty state is about. */
  protected get unconfigured(): boolean {
    this.generation();
    return !this.agentStatus.configured();
  }

  /** Whether this caller may enable a definition, and therefore which sentence they are shown. */
  protected get administrator(): boolean {
    this.generation();
    return this.navigation.screenVerdict(DEFINITIONS_ROUTE).allowed;
  }

  /** Whether the agent is switched off for this caller (FR-20). */
  protected get killSwitch(): boolean {
    this.generation();
    return this.agentStatus.restraint().killSwitch;
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
    this.generation();
    return this.agentStatus.restraint().enforcedReadOnly;
  }

  /**
   * The string key the footer line renders, chosen by the server's verdict and never composed
   * here -- so the line cannot say two things at once when two read-only sources are in force.
   */
  protected get readOnlyKey(): string {
    this.generation();
    return this.agentStatus.restraint().footerKey;
  }

  /** That key's published sentence. */
  protected get readOnlyLine(): string {
    return stringFor(this.readOnlyKey);
  }

  /**
   * What describes the composer and Send: the topmost banner showing, in EXPERIENCE.md's own
   * order, because that is the one that says why they cannot act.
   */
  protected get describedBy(): string {
    if (this.killSwitch) return KILL_SWITCH_ID;
    if (this.enforcedReadOnly) return READ_ONLY_ID;
    return REASON_ID;
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }
}

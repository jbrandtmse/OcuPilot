import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { AgentStatus, DEFINITIONS_ROUTE } from '../core/agent-status';
import { NavigationService } from '../core/navigation';
import { STRINGS } from '../core/strings';
import { EXAMPLE_PROPOSAL } from './example-proposal';
import { ProposalCard } from './proposal-card';

/** The composer's control id, so its label and both `aria-describedby` wires resolve. */
const COMPOSER_ID = 'ocu-panel-composer';

/** The id of whichever sentence the panel is showing, which is also the controls' reason. */
const REASON_ID = 'ocu-panel-reason';

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
 * **This is not Story 4.3's panel.** No resize handle, no full-screen toggle, no transcript, no
 * context chip, no New conversation and no header controls: those arrive with the panel that is
 * unconditional. What is here is the empty state, the static example card and the footer's two
 * gated controls -- focusable, `aria-disabled` and described by the same sentence the panel is
 * showing, never carrying the `disabled` attribute (EXPERIENCE.md's Privilege Gating mechanism).
 * The composer is `readonly` beside its `aria-disabled`, which is the pairing this product's own
 * gated input already uses (`definition-form.page.ts`'s retention field): `aria-disabled` alone
 * announces a control as inert and then lets the reader type a whole message into it.
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
        @if (administrator) {
          <p class="ocu-banner ocu-banner-info ocu-panel-banner" [id]="reasonId">
            <span class="ocu-banner-glyph" aria-hidden="true">{{ bannerGlyph }}</span>
            <span class="ocu-banner-message">{{ STRINGS.agentGateReminderBanner }}</span>
          </p>
        } @else {
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
      </div>

      <div class="ocu-panel-footer">
        <label class="ocu-field-label" [attr.for]="composerId">{{ STRINGS.agentComposerLabel }}</label>
        <div class="ocu-panel-composer-row">
          <textarea
            class="ocu-panel-composer"
            rows="2"
            aria-disabled="true"
            readonly
            [id]="composerId"
            [attr.aria-describedby]="reasonId"
          ></textarea>
          <button
            type="button"
            class="ocu-button-primary ocu-panel-send"
            aria-disabled="true"
            [attr.aria-describedby]="reasonId"
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
   * Whether the panel draws anything at all: both facts in, and the agent unconfigured.
   *
   * A configured instance gets nothing here -- the transcript and its chrome are Story 4.3's --
   * and the host element collapses rather than reserving 400px of a screen it has nothing to say
   * about (`app-panel:empty` in the stylesheet).
   */
  protected get shown(): boolean {
    this.generation();
    return (
      this.navigation.loaded() && this.agentStatus.answered() && !this.agentStatus.configured()
    );
  }

  /** Whether this caller may enable a definition, and therefore which sentence they are shown. */
  protected get administrator(): boolean {
    this.generation();
    return this.navigation.screenVerdict(DEFINITIONS_ROUTE).allowed;
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }
}

import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import {
  FIELDS_SEPARATOR,
  Guardrails,
  TOOL_FIELDS_SEPARATOR,
  confirmGroups,
  killSwitchLine,
  limitsLine,
  readOnlyLine,
  turnsLine,
  type GuardrailsAnswer,
  type ProhibitedRow,
} from '../../core/guardrails';
import { isBannerFault, type Fault } from '../../core/fault';
import { screenForDescriptor } from '../../core/navigation';
import { STRINGS, stringFor } from '../../core/strings';
import { FaultBanner } from '../../shell/fault-banner';

/** One Confirm group, resolved for drawing. */
interface ConfirmGroupView {
  readonly key: string;
  readonly hasLabel: boolean;
  readonly label: string;
  readonly headingId: string;
  readonly tools: readonly string[];
}

/** One tool of the secret list, resolved for drawing. */
interface SecretView {
  readonly tool: string;
  readonly fields: string;
}

/** A descriptor's side-bar label, through the mirror and the strings lookup the side bar uses. */
function screenLabel(descriptor: string): string | null {
  const screen = screenForDescriptor(descriptor);
  if (screen === null) return null;
  const label = stringFor(screen.labelKey);
  return label === '' ? null : label;
}

/**
 * The Guardrails screen (Story 16.22): what the agent refuses outright, the switches in force for
 * the caller, the tools that always need a Confirm, what never reaches the agent, and the
 * limits: the screen-context caps and the turns an hour.
 *
 * **It renders the instance's answer and decides nothing** (AD-10, AD-30). Every refusal sentence,
 * code, tool name and field name comes from `GET /ui/guardrails` and is rendered as text (AD-11);
 * the only published copy here is the page's own labels. A read that fails draws no section: a
 * connectivity-banner fault is the shell's banner's to say once, and any other is drawn in place by
 * `FaultBanner` with Retry, which reads again.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-guardrails-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [FaultBanner],
  template: `<section class="ocu-form-page ocu-guardrails" [attr.aria-busy]="busy">
    <p class="ocu-guardrails-intro">{{ STRINGS.agentGuardrailsIntro }}</p>
    @if (inPlaceFault) {
      <app-fault-banner [fault]="inPlaceFault" (retried)="retry()" />
    }
    @if (answered) {
      <section class="ocu-guardrails-section" aria-labelledby="ocu-guardrails-refused">
        <h2 class="ocu-guardrails-heading" id="ocu-guardrails-refused">{{ STRINGS.agentGuardrailsRefusedHeading }}</h2>
        <p class="ocu-guardrails-note">{{ STRINGS.agentGuardrailsRefusedNote }}</p>
        <ul class="ocu-guardrails-list ocu-guardrails-refused">
          @for (row of prohibited; track row.code) {
            <li class="ocu-guardrails-item">
              <span class="ocu-guardrails-reason">{{ row.reason }}</span>
              <code class="ocu-guardrails-code">{{ row.code }}</code>
            </li>
          }
        </ul>
      </section>

      <section class="ocu-guardrails-section" aria-labelledby="ocu-guardrails-switches">
        <h2 class="ocu-guardrails-heading" id="ocu-guardrails-switches">{{ STRINGS.agentSwitchesLabel }}</h2>
        <p class="ocu-guardrails-line ocu-guardrails-kill-switch">{{ killSwitch }}</p>
        <p class="ocu-guardrails-line ocu-guardrails-read-only">{{ readOnly }}</p>
        <p class="ocu-guardrails-note">{{ STRINGS.agentGuardrailsSwitchesNote }}</p>
      </section>

      <section class="ocu-guardrails-section" aria-labelledby="ocu-guardrails-confirm">
        <h2 class="ocu-guardrails-heading" id="ocu-guardrails-confirm">{{ STRINGS.agentGuardrailsConfirmHeading }}</h2>
        <p class="ocu-guardrails-note">{{ STRINGS.agentGuardrailsConfirmNote }}</p>
        @for (group of groups; track group.key) {
          <div class="ocu-guardrails-group">
            @if (group.hasLabel) {
              <h3 class="ocu-guardrails-group-heading" [id]="group.headingId">{{ group.label }}</h3>
            }
            <ul class="ocu-guardrails-list ocu-guardrails-tools">
              @for (tool of group.tools; track tool) {
                <li class="ocu-guardrails-item"><code class="ocu-guardrails-code">{{ tool }}</code></li>
              }
            </ul>
          </div>
        }
      </section>

      <section class="ocu-guardrails-section" aria-labelledby="ocu-guardrails-never">
        <h2 class="ocu-guardrails-heading" id="ocu-guardrails-never">{{ STRINGS.agentGuardrailsNeverHeading }}</h2>
        <p class="ocu-guardrails-line">{{ STRINGS.agentGuardrailsNeverSecrets }}</p>
        <p class="ocu-guardrails-line">{{ STRINGS.agentGuardrailsNeverErrorVariables }}</p>
        <p class="ocu-guardrails-note">{{ STRINGS.agentGuardrailsNeverDeclared }}</p>
        <ul class="ocu-guardrails-list ocu-guardrails-secrets">
          @for (secret of secrets; track secret.tool) {
            <li class="ocu-guardrails-item">
              <code class="ocu-guardrails-code">{{ secret.tool }}</code>{{ separator }}<code class="ocu-guardrails-code">{{ secret.fields }}</code>
            </li>
          }
        </ul>
      </section>

      <section class="ocu-guardrails-section" aria-labelledby="ocu-guardrails-context">
        <h2 class="ocu-guardrails-heading" id="ocu-guardrails-context">{{ STRINGS.agentGuardrailsLimitsHeading }}</h2>
        <p class="ocu-guardrails-line ocu-guardrails-limits">{{ limits }}</p>
        <p class="ocu-guardrails-line ocu-guardrails-turns">{{ turns }}</p>
      </section>
    }
  </section>`,
})
export class GuardrailsPage {
  private readonly store = inject(Guardrails);

  protected readonly STRINGS = STRINGS;

  protected readonly separator = TOOL_FIELDS_SEPARATOR;

  /** The store mirrored into a signal, so the template re-reads it under `OnPush`. */
  private readonly answer = signal<GuardrailsAnswer | null>(null);

  private readonly faultFlag = signal<Fault | null>(null);

  private readonly loadingFlag = signal(false);

  constructor() {
    const mirror = (): void => {
      this.answer.set(this.store.data());
      this.faultFlag.set(this.store.fault());
      this.loadingFlag.set(this.store.loading());
    };
    const stop = this.store.subscribe(mirror);
    mirror();
    void this.store.load();
    inject(DestroyRef).onDestroy(stop);
  }

  protected get busy(): boolean {
    return this.loadingFlag();
  }

  /**
   * The fault drawn in place: a failed read with something other than a connectivity-banner fault.
   * A banner fault is the shell's banner's to say, so the page adds no alert of its own.
   */
  protected get inPlaceFault(): Fault | null {
    const fault = this.faultFlag();
    return isBannerFault(fault) ? null : fault;
  }

  /** Retry on the in-place banner: read the guardrails again. */
  protected retry(): void {
    void this.store.load();
  }

  protected get answered(): boolean {
    return this.answer() !== null && this.faultFlag() === null;
  }

  protected get prohibited(): readonly ProhibitedRow[] {
    return this.answer()?.prohibited ?? [];
  }

  protected get killSwitch(): string {
    const answer = this.answer();
    return answer === null ? '' : killSwitchLine(answer.switches);
  }

  protected get readOnly(): string {
    const answer = this.answer();
    return answer === null ? '' : readOnlyLine(answer.switches);
  }

  protected get groups(): readonly ConfirmGroupView[] {
    const answer = this.answer();
    if (answer === null) return [];
    return confirmGroups(answer.confirmTools, screenLabel).map((group, index) => ({
      key: group.key,
      hasLabel: group.label !== null,
      label: group.label ?? '',
      headingId: `ocu-guardrails-group-${index}`,
      tools: group.tools,
    }));
  }

  protected get secrets(): readonly SecretView[] {
    return (this.answer()?.secrets ?? []).map((secret) => ({ tool: secret.tool, fields: secret.fields.join(FIELDS_SEPARATOR) }));
  }

  protected get limits(): string {
    const answer = this.answer();
    return answer === null ? '' : limitsLine(answer.limits);
  }

  protected get turns(): string {
    const answer = this.answer();
    return answer === null ? '' : turnsLine(answer.limits);
  }
}

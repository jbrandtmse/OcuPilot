import { ChangeDetectionStrategy, Component, DestroyRef, inject, input, signal } from '@angular/core';

import { AgentStatus } from '../core/agent-status';
import { STRINGS } from '../core/strings';

/**
 * The per-user "Read-only for me" switch beside the panel's footer line (Story 14.5, the Fixed
 * strings row of the panel footer status line).
 *
 * **It stores a choice and decides nothing.** A press sends `PUT /agent/restraint` through
 * `AgentStatus.setReadOnlyForYou`, and the switch, the footer line and every write the agent
 * attempts all follow the verdict the instance answers (AD-30). The component holds no state of
 * its own: `AgentStatus` is mirrored into a signal (AD-19), so what is drawn is what the instance
 * last said.
 *
 * **Checked while read-only is on for you or enforced.** Under enforced read-only the switch reads
 * on, is `aria-disabled`, and a press changes nothing and sends nothing; the footer line it points
 * at says why. It is `aria-disabled` rather than `disabled`, so it keeps its tab stop and its
 * description.
 *
 * **Drawn only once the status read has answered**, so it never shows off over a choice that is
 * on.
 */
@Component({
  selector: 'app-read-only-toggle',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `@if (answered) {
    <label class="ocu-read-only-toggle">
      <span class="ocu-visually-hidden">{{ STRINGS.agentReadOnlyForYouLabel }}</span>
      <input
        type="checkbox"
        role="switch"
        class="ocu-read-only-switch"
        [attr.aria-label]="STRINGS.agentReadOnlyForYouLabel"
        [attr.aria-describedby]="describedBy()"
        [attr.aria-disabled]="enforced ? 'true' : null"
        [checked]="checked"
        (click)="onClick($event)"
        (change)="onChange($event)"
      />
    </label>
  }`,
})
export class ReadOnlyToggle {
  private readonly agentStatus = inject(AgentStatus);

  protected readonly STRINGS = STRINGS;

  /** The id of the footer line this switch is described by. */
  readonly describedBy = input<string>('');

  /** Bumped on every `AgentStatus` notification, so the template re-reads it under `OnPush`. */
  private readonly generation = signal(0);

  constructor() {
    const stop = this.agentStatus.subscribe(() => this.generation.update((value) => value + 1));
    inject(DestroyRef).onDestroy(stop);
  }

  protected get answered(): boolean {
    this.generation();
    return this.agentStatus.answered();
  }

  protected get enforced(): boolean {
    this.generation();
    return this.agentStatus.restraint().enforcedReadOnly;
  }

  protected get checked(): boolean {
    this.generation();
    const restraint = this.agentStatus.restraint();
    return restraint.readOnlyForYou || restraint.enforcedReadOnly;
  }

  /**
   * Under enforced read-only a press is cancelled before the box toggles, so no `change` fires and
   * nothing is sent. Space reaches the box as a click too.
   */
  protected onClick(event: Event): void {
    if (this.enforced) event.preventDefault();
  }

  protected async onChange(event: Event): Promise<void> {
    const target = event.target as HTMLInputElement;
    await this.agentStatus.setReadOnlyForYou(target.checked);
    // The box shows what the instance answered, which a refused write leaves where it was.
    target.checked = this.checked;
  }
}

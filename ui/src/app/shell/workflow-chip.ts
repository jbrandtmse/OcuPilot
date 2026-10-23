import { ChangeDetectionStrategy, Component, input, output } from '@angular/core';

import { STRINGS } from '../core/strings';

/**
 * The guided-workflow chip (Story 20.12, AD-66, `panel.ts`'s footer): the visible sign that the
 * next send is a workflow turn, with the two controls that act on the workflow itself.
 *
 * It draws the label, the text of the prompt that started the workflow, **Continue** and **End
 * workflow**, and decides nothing else. Whether the workflow is active, whether Continue may be
 * pressed and the sentence that says why not are the caller's (`panel.ts` reads them from
 * `TurnStore` and the live cards): this component is handed `continueDisabled` and the id of the
 * element that names the reason, and holds Continue `aria-disabled`, never hidden or natively
 * disabled, so it keeps its tab stop and its reason (EXPERIENCE.md's Privilege Gating).
 *
 * **Neither control decides a proposal.** Continue only asks the caller to send the workflow's next
 * turn; it never confirms, cancels or closes a proposal, and a press while it is disabled emits
 * nothing.
 */
@Component({
  selector: 'app-workflow-chip',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<div class="ocu-workflow-chip" data-ocu-workflow-chip>
    <p class="ocu-workflow-chip-text">
      <span class="ocu-workflow-chip-label">{{ STRINGS.agentWorkflowLabel }}</span>
      <span class="ocu-workflow-chip-name">{{ text() }}</span>
    </p>
    <div class="ocu-workflow-chip-actions">
      <button
        type="button"
        class="ocu-button-text ocu-workflow-chip-action ocu-workflow-chip-continue"
        [attr.aria-disabled]="continueDisabled() ? 'true' : null"
        [attr.aria-describedby]="continueDisabled() ? reasonId() : null"
        (click)="onContinue()"
      >
        {{ STRINGS.agentWorkflowContinue }}
      </button>
      <button type="button" class="ocu-button-text ocu-workflow-chip-action ocu-workflow-chip-end" (click)="end.emit()">
        {{ STRINGS.agentWorkflowEnd }}
      </button>
    </div>
  </div>`,
})
export class WorkflowChip {
  protected readonly STRINGS = STRINGS;

  /** The text of the suggested prompt that started the workflow. */
  readonly text = input<string>('');

  /** Whether Continue is held `aria-disabled`: a turn runs, or a proposal card is live. */
  readonly continueDisabled = input<boolean>(false);

  /** The id of the element that names why Continue is disabled, or `null` when none shows. */
  readonly reasonId = input<string | null>(null);

  /** Continue was pressed while enabled: send the workflow's next turn. */
  readonly continue = output<void>();

  /** End workflow was pressed. */
  readonly end = output<void>();

  protected onContinue(): void {
    if (this.continueDisabled()) return;
    this.continue.emit();
  }
}

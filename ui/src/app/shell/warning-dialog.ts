import { ChangeDetectionStrategy, Component, input, output } from '@angular/core';

import { STRINGS } from '../core/strings';
import { Dialog } from './dialog';

/**
 * The warning before a non-delete write (EXPERIENCE.md `confirm-dialog`): the title is the verb,
 * the body is the consequence sentence the caller passes (a Fixed strings row), and the confirming
 * action is Proceed as a `button-primary` -- a warning, never a destructive treatment.
 *
 * Cancel is `dialog.ts`'s own dismissing action and takes initial focus, since the surface holds no
 * field. Escape, Cancel and the scrim all emit `cancelled`; the focus trap and the return to the
 * opener are `dialog.ts`'s, unchanged.
 */
@Component({
  selector: 'app-warning-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="verb()" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    <p class="ocu-warning-consequence">{{ consequence() }}</p>
    <button dialogAction type="button" class="ocu-button-primary" (click)="confirmed.emit()">
      {{ STRINGS.actionProceed }}
    </button>
  </app-dialog>`,
})
export class WarningDialog {
  /** The verb this dialog confirms, already published copy ("Turn auditing off"). */
  readonly verb = input.required<string>();

  /** The consequence sentence, a Fixed strings row the caller resolves. */
  readonly consequence = input.required<string>();

  /** Emitted once, when Proceed is pressed. */
  readonly confirmed = output<void>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;
}

import { ChangeDetectionStrategy, Component, computed, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';

/** How many status dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/** The three statuses, each the value the change status tool declares for `Status`. */
export type EcpStatusChoice = 'notconnected' | 'disabled' | 'normal';

/**
 * Each choice and the status text the instance's data server list answers for it on this build: the
 * dialog compares the current status against these exactly, as the instance's own same-status check
 * does. A status matching none (a connection in progress, failed or in trouble) offers all three.
 */
export const ECP_STATUS_LABELS: Readonly<Record<EcpStatusChoice, string>> = {
  notconnected: 'Not Connected',
  disabled: 'Disabled',
  normal: 'Normal',
};

/** One choice as the fieldset draws it. */
interface ChoiceModel {
  readonly choice: EcpStatusChoice;
  readonly id: string;
  readonly label: string;
  /** Why the choice cannot be made -- its current status, or a license without ECP -- or `''`. */
  readonly reason: string;
  readonly reasonId: string;
  readonly refused: boolean;
  readonly checked: boolean;
  readonly ariaDisabled: string | null;
  readonly describedBy: string | null;
}

/** `template` with `<placeholder>` replaced by `value`, shown as written. */
function fill(template: string, placeholder: string, value: string): string {
  return template.split(`<${placeholder}>`).join(value);
}

/**
 * Change status (Story 18.20): ECP data servers' row entry, titled "Change the status of <name>",
 * with the data server's current status under the title as the instance reported it.
 *
 * **Three choices.** The fieldset offers Not connected, Disabled and Normal, none chosen until the
 * person chooses. The current one is drawn `aria-disabled` with "This is its current status.", and
 * Normal is drawn `aria-disabled` with the license sentence while the instance's license does not
 * include ECP (`licensed` false). A refused choice stays in the Tab order, its reason beside it and
 * in its `aria-describedby`, and neither a click nor an arrow key selects it. Whether the instance
 * accepts a choice is its own answer, which the page passes back as `refusal`.
 *
 * **It is destructive with no typed name**, because nothing is removed: the chosen choice's
 * consequence sentence shows, and Change status is `button-destructive`, `aria-disabled` until a
 * choice is made and while a send is in flight.
 */
@Component({
  selector: 'app-ecp-data-server-status-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="heading()" [closeLabel]="STRINGS.actionCancel" (closed)="onClosed()">
    <p class="ocu-ecp-status-current">{{ currentLine() }}</p>
    <fieldset class="ocu-field ocu-form-authe ocu-ecp-status-choices">
      <legend class="ocu-field-label">{{ STRINGS.taskHistoryColumnStatus }}</legend>
      @for (model of choiceModels; track model.choice) {
        <label class="ocu-field-checkbox ocu-ecp-status-choice" [attr.data-status]="model.choice">
          <input
            type="radio"
            [name]="groupName"
            [id]="model.id"
            [checked]="model.checked"
            [attr.aria-disabled]="model.ariaDisabled"
            [attr.aria-describedby]="model.describedBy"
            (click)="onChoiceClick($event, model)"
            (change)="onChoiceChange(model)"
          />
          <span class="ocu-ecp-status-choice-label">{{ model.label }}</span>
        </label>
        @if (model.refused) {
          <p class="ocu-field-caption ocu-ecp-status-choice-reason" [id]="model.reasonId">{{ model.reason }}</p>
        }
      }
    </fieldset>
    @if (hasConsequence) {
      <p class="ocu-typed-name-consequence ocu-ecp-status-consequence">{{ consequenceText }}</p>
    }
    @if (refusalVisible) {
      <p class="ocu-ecp-status-refusal" role="alert">{{ refusalText }}</p>
    }
    <button
      dialogAction
      type="button"
      class="ocu-button-destructive ocu-ecp-status-submit"
      [attr.aria-disabled]="submitDisabled"
      (click)="submit()"
    >
      {{ STRINGS.ecpDataServerChangeStatus }}
    </button>
  </app-dialog>`,
})
export class EcpDataServerStatusDialog {
  /** The data server's name, which titles the dialog. */
  readonly name = input.required<string>();

  /** The data server's status as the instance reported it, e.g. "Not Connected". */
  readonly status = input<string>('');

  /** Whether the instance's license includes ECP; Normal is refused while it does not. */
  readonly licensed = input<boolean>(false);

  /** A send is in flight. */
  readonly sending = input<boolean>(false);

  /** The instance's refusal sentence, or `''`. */
  readonly refusal = input<string>('');

  /** Emitted once per Change status, with the chosen status. */
  readonly submitted = output<EcpStatusChoice>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly instance = ++dialogCount;

  protected readonly groupName = `ocu-ecp-status-${this.instance}`;

  /** The chosen status, or `null` until the person chooses one that can be made. */
  protected readonly selected = signal<EcpStatusChoice | null>(null);

  private closed = false;

  protected readonly heading = computed(() => fill(STRINGS.ecpDataServerStatusTitle, 'name', this.name()));

  protected readonly currentLine = computed(() => {
    const status = this.status();
    return fill(STRINGS.ecpDataServerCurrentStatus, 'status', status === '' ? STRINGS.tableEmptyValue : status);
  });

  /** The three choices, a refused one carrying its reason. */
  protected readonly choices = computed<readonly ChoiceModel[]>(() => {
    const status = this.status();
    const licensed = this.licensed();
    const selected = this.selected();
    const base = `ocu-ecp-status-${this.instance}`;
    const entries: readonly (readonly [EcpStatusChoice, string])[] = [
      ['notconnected', STRINGS.ecpDataServerNotConnected],
      ['disabled', STRINGS.agentGovernanceDisabled],
      ['normal', STRINGS.taskPriorityNormal],
    ];
    return entries.map(([choice, label]) => {
      const current = status === ECP_STATUS_LABELS[choice];
      let reason = '';
      if (current) reason = STRINGS.ecpDataServerCurrentReason;
      else if (choice === 'normal' && !licensed) reason = STRINGS.ecpLicenseRefusal;
      const reasonId = `${base}-${choice}-reason`;
      const refused = reason !== '';
      return {
        choice,
        id: `${base}-${choice}`,
        label,
        reason,
        reasonId,
        refused,
        checked: selected === choice,
        ariaDisabled: refused ? 'true' : null,
        describedBy: refused ? reasonId : null,
      };
    });
  });

  protected get choiceModels(): readonly ChoiceModel[] {
    return this.choices();
  }

  /** The chosen status's consequence: the disconnect sentence, the connect sentence, or `''` before a choice. */
  protected get consequenceText(): string {
    const selected = this.selected();
    if (selected === null) return '';
    return selected === 'normal' ? STRINGS.ecpDataServerConnectConsequence : STRINGS.ecpDataServerDisconnectConsequence;
  }

  protected get hasConsequence(): boolean {
    return this.consequenceText !== '';
  }

  protected get refusalVisible(): boolean {
    return this.refusal() !== '';
  }

  protected get refusalText(): string {
    return this.refusal();
  }

  /** The chosen status, where it is still one that can be made. */
  private chosen(): EcpStatusChoice | null {
    const selected = this.selected();
    if (selected === null) return null;
    return this.choices().some((model) => model.choice === selected && !model.refused) ? selected : null;
  }

  protected get submitDisabled(): string | null {
    return this.chosen() !== null && !this.sending() ? null : 'true';
  }

  /**
   * A refused choice is never selected: its click -- which an arrow key in the group also fires -- is
   * cancelled, and the group's checked state is put back to the chosen status once the click has
   * settled, whichever element the cancelled activation left checked.
   */
  protected onChoiceClick(event: Event, model: ChoiceModel): void {
    if (!model.refused) return;
    event.preventDefault();
    const group = (event.target as HTMLElement).closest('fieldset');
    const selected = this.selected();
    queueMicrotask(() => {
      for (const radio of Array.from(group?.querySelectorAll<HTMLInputElement>('input[type="radio"]') ?? [])) {
        radio.checked = radio.closest('[data-status]')?.getAttribute('data-status') === selected;
      }
    });
  }

  protected onChoiceChange(model: ChoiceModel): void {
    if (model.refused) return;
    this.selected.set(model.choice);
  }

  /** Hand the chosen status on once one that can be made is chosen and no send is in flight. */
  protected submit(): void {
    if (this.sending()) return;
    const chosen = this.chosen();
    if (chosen === null) return;
    this.submitted.emit(chosen);
  }

  protected onClosed(): void {
    if (this.closed) return;
    this.closed = true;
    this.cancelled.emit();
  }
}

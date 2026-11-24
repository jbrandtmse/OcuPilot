import { ChangeDetectionStrategy, Component, computed, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';

/** What the review of an Update alert answered: the alert's owner, open state and escalation level, the owners it may be given to, and who is signed in. */
export interface ManagedAlertView {
  readonly id: string;
  readonly owner: string;
  readonly open: boolean;
  readonly level: number;
  readonly owners: readonly string[];
  readonly caller: string;
}

/**
 * The values of one Update alert, each sent only when it differs from what the alert holds, as the screen action takes them: the owner (empty for unassigned), the open
 * state as `0` or `1`, the level and the minutes as whole-number text, and the reason when one was typed.
 */
export interface ManagedAlertChange {
  readonly [value: string]: string;
}

/** How many Update alert dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/**
 * Update alert (Story 24.17 Batch 1, EXPERIENCE.md `confirm-dialog`, `button-primary`): the alert's owner, open state and escalation level as the review read them, a
 * field for when its next action is due, the reason, the consequence sentence, and a primary Update beside Cancel.
 *
 * It is not `InteropArchiveDialog` with fields added: that dialog types a name to confirm a destructive run and takes no value, and what the two share is the
 * `aria-disabled` button and the refusal line.
 *
 * **The owner choices** are Unassigned, the signed-in user and the owners the review listed, with the alert's own owner kept among them so the list shows what it holds. **The
 * escalation choices** are the alert's level, one more and, above 0, one less. **Update sends only what changed**: an owner, an open state or a level equal to the
 * alert's own is left out, and the minutes only when the field holds something; the reason is sent whenever it holds something, and the instance judges every value again and
 * refuses a missing reason in its own words (AD-56).
 *
 * **`aria-disabled`, never `disabled`**, for the reason `typed-name-dialog.ts` records: Update keeps its place in the Tab order and its click is refused here while a send is
 * in flight. Cancel, Escape and the scrim emit `cancelled`. A refusal the page passes stays in the dialog.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-interop-managed-alert-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="STRINGS.interopManagedAlertUpdateAction" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    <p class="ocu-banner" data-interop-alert-consequence>{{ STRINGS.interopManagedAlertUpdateConsequence }}</p>
    <div class="ocu-form-fields">
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="ownerId">{{ STRINGS.explorerSqlColumnOwner }}</label>
        <div class="ocu-field-control">
          <select class="ocu-field-input" data-interop-alert-field="Owner" [id]="ownerId" (change)="onOwner($event)">
            @for (choice of ownerChoices; track choice.value) {
              <option [value]="choice.value" [selected]="choice.value === ownerChosen()">{{ choice.label }}</option>
            }
          </select>
        </div>
      </div>
      <div class="ocu-field">
        <label class="ocu-field-checkbox">
          <input type="checkbox" data-interop-alert-field="Open" [id]="openId" [checked]="openChosen()" (change)="onOpen($event)" />
          <span>{{ STRINGS.homeSuggestedOpen }}</span>
        </label>
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="levelId">{{ STRINGS.interopAlertColumnLevel }}</label>
        <div class="ocu-field-control">
          <select class="ocu-field-input" data-interop-alert-field="EscalationLevel" [id]="levelId" (change)="onLevel($event)">
            @for (level of levelChoices; track level) {
              <option [value]="level" [selected]="level === levelChosen()">{{ level }}</option>
            }
          </select>
        </div>
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="minutesId">{{ STRINGS.interopAlertFieldNextMinutes }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            inputmode="numeric"
            autocomplete="off"
            spellcheck="false"
            data-interop-alert-field="NextActionMinutes"
            [id]="minutesId"
            [value]="minutes()"
            (input)="onMinutes($event)"
          />
        </div>
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="reasonId">{{ STRINGS.agentSwitchesFieldReason }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            maxlength="500"
            autocomplete="off"
            data-interop-alert-field="Reason"
            aria-required="true"
            [id]="reasonId"
            [value]="reason()"
            (input)="onReason($event)"
            (keydown.enter)="onEnter($event)"
          />
        </div>
      </div>
    </div>
    @if (hasRefusal) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-interop-alert-refusal>{{ refusal() }}</p>
    }
    <button dialogAction type="button" class="ocu-button-primary" data-interop-alert-confirm [attr.aria-disabled]="confirmDisabled" (click)="onConfirm()">
      {{ STRINGS.actionUpdate }}
    </button>
  </app-dialog>`,
})
export class InteropManagedAlertDialog {
  /** What the review answered. */
  readonly alert = input.required<ManagedAlertView>();

  /** A refusal the instance gave that the dialog shows. */
  readonly refusal = input<string>('');

  /** Whether a send is in flight, which holds Update. */
  readonly sending = input<boolean>(false);

  /** Emitted once per Update taken, with the values that differ and the reason. */
  readonly confirmed = output<ManagedAlertChange>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly instance = ++dialogCount;

  protected readonly ownerId = `ocu-interop-alert-owner-${this.instance}`;

  protected readonly openId = `ocu-interop-alert-open-${this.instance}`;

  protected readonly levelId = `ocu-interop-alert-level-${this.instance}`;

  protected readonly minutesId = `ocu-interop-alert-minutes-${this.instance}`;

  protected readonly reasonId = `ocu-interop-alert-reason-${this.instance}`;

  private readonly ownerPicked = signal<string | null>(null);

  private readonly openPicked = signal<boolean | null>(null);

  private readonly levelPicked = signal<string | null>(null);

  protected readonly minutes = signal('');

  protected readonly reason = signal('');

  protected readonly ownerChosen = computed(() => this.ownerPicked() ?? this.alert().owner);

  protected readonly openChosen = computed(() => this.openPicked() ?? this.alert().open);

  protected readonly levelChosen = computed(() => this.levelPicked() ?? String(this.alert().level));

  /** Unassigned, the signed-in user, the alert's own owner and the listed owners, each once, in that order. */
  protected get ownerChoices(): readonly { readonly value: string; readonly label: string }[] {
    const view = this.alert();
    const seen = new Set<string>(['']);
    const choices: { value: string; label: string }[] = [{ value: '', label: STRINGS.interopAlertOwnerUnassigned }];
    for (const name of [view.caller, view.owner, ...view.owners]) {
      if (name === '' || seen.has(name)) continue;
      seen.add(name);
      choices.push({ value: name, label: name });
    }
    return choices;
  }

  /** The alert's level, one more and, above 0, one less, as text. */
  protected get levelChoices(): readonly string[] {
    const level = this.alert().level;
    return level > 0 ? [String(level), String(level + 1), String(level - 1)] : [String(level), String(level + 1)];
  }

  protected get hasRefusal(): boolean {
    return this.refusal() !== '';
  }

  protected get confirmDisabled(): string | null {
    return this.sending() ? 'true' : null;
  }

  protected onOwner(event: Event): void {
    this.ownerPicked.set((event.target as HTMLSelectElement).value);
  }

  protected onOpen(event: Event): void {
    this.openPicked.set((event.target as HTMLInputElement).checked);
  }

  protected onLevel(event: Event): void {
    this.levelPicked.set((event.target as HTMLSelectElement).value);
  }

  protected onMinutes(event: Event): void {
    this.minutes.set((event.target as HTMLInputElement).value);
  }

  protected onReason(event: Event): void {
    this.reason.set((event.target as HTMLInputElement).value);
  }

  protected onEnter(event: Event): void {
    event.preventDefault();
    this.onConfirm();
  }

  /** Emit the values that differ from the alert's own and the reason; nothing while a send is in flight. */
  protected onConfirm(): void {
    if (this.sending()) return;
    const view = this.alert();
    const change: Record<string, string> = {};
    if (this.ownerChosen() !== view.owner) change['Owner'] = this.ownerChosen();
    if (this.openChosen() !== view.open) change['Open'] = this.openChosen() ? '1' : '0';
    if (this.levelChosen() !== String(view.level)) change['EscalationLevel'] = this.levelChosen();
    const minutes = this.minutes().trim();
    if (minutes !== '') change['NextActionMinutes'] = minutes;
    if (this.reason() !== '') change['Reason'] = this.reason();
    this.confirmed.emit(change);
  }
}

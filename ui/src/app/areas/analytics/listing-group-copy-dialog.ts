import { ChangeDetectionStrategy, Component, DestroyRef, inject, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { reasonForField, type Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { LISTING_GROUP_LIST } from './listing-group-dialog';

/** The row action the Copy dialog sends through the shell's handler, with the three values its tool declares. */
export const LISTING_GROUP_COPY_ACTION = 'copy';

/** How many copy dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/** One field the dialog draws, by the value the tool declares it under. */
interface Drawn {
  readonly value: 'NewName' | 'NewClass' | 'NewCubes';
  readonly label: string;
  readonly required: boolean;
}

/**
 * Listing groups' Copy (Story 24.11): the classic Save As, as a new listing group under a name and a class the person types, with the
 * source's listings and, when typed, other target cubes. Its primary button sends the row action `copy` on the source through the shell's
 * handler, which publishes the change event that re-reads the list (AD-14).
 *
 * **Every sentence it shows is the server's** (AD-39): a violation on a field is drawn under it, any other refusal above the fields. A name
 * or class already held is refused by the server; nothing is overwritten.
 */
@Component({
  selector: 'app-listing-group-copy-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="STRINGS.auditDatabaseCopyConfirm" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    @if (reasonText) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-listing-group-copy-reason>{{ reasonText }}</p>
    }
    <div class="ocu-form-fields">
      @for (field of drawn; track field.value) {
        <div class="ocu-field">
          <label class="ocu-field-label" [class.ocu-field-label-required]="field.required" [attr.for]="fieldId(field.value)">{{ field.label }}</label>
          <div class="ocu-field-control">
            <input
              class="ocu-field-input"
              type="text"
              autocomplete="off"
              spellcheck="false"
              [attr.data-listing-group-copy-field]="field.value"
              [id]="fieldId(field.value)"
              [value]="valueOf(field.value)"
              [attr.aria-invalid]="violationOf(field.value) ? 'true' : null"
              (input)="onText(field.value, $event)"
              (keydown.enter)="onEnter($event)"
            />
          </div>
          @if (fieldViolation[field.value]) {
            <p class="ocu-form-error" [attr.data-listing-group-copy-violation]="field.value">{{ fieldViolation[field.value] }}</p>
          }
        </div>
      }
    </div>
    <button dialogAction type="button" class="ocu-button-primary" data-listing-group-copy-confirm [attr.aria-disabled]="confirmDisabled" (click)="onConfirm()">
      {{ STRINGS.auditDatabaseCopyConfirm }}
    </button>
  </app-dialog>`,
})
export class ListingGroupCopyDialog {
  /** The name of the listing group this dialog copies. */
  readonly source = input.required<string>();

  /** The namespace the copy is made in, which the send is pinned to. */
  readonly namespace = input.required<string>();

  /** Emitted once, after the instance applied the copy. */
  readonly done = output<void>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly handler = inject(ScreenActionHandler);

  private readonly id = ++dialogCount;

  protected readonly drawn: readonly Drawn[] = [
    { value: 'NewName', label: STRINGS.analyticsListingGroupNewNameLabel, required: true },
    { value: 'NewClass', label: STRINGS.analyticsListingGroupNewClassLabel, required: true },
    { value: 'NewCubes', label: STRINGS.analyticsColumnTargetCubes, required: false },
  ];

  private readonly typed = signal<Readonly<Record<string, string>>>({});

  private readonly reason = signal('');

  private readonly violations = signal<readonly Violation[]>([]);

  private readonly busy = signal(false);

  private closed = false;

  constructor() {
    inject(DestroyRef).onDestroy(() => {
      this.closed = true;
    });
  }

  protected fieldId(value: string): string {
    return `ocu-listing-group-copy-${value}-${this.id}`;
  }

  protected valueOf(value: string): string {
    return this.typed()[value] ?? '';
  }

  protected violationOf(value: string): string {
    // The port judges the new name by the name rule, which reports it on the field `NewName`.
    return reasonForField(this.violations(), value);
  }

  protected get reasonText(): string {
    return this.reason();
  }

  /** The refusal each drawn field carries, by value, for the template. */
  protected get fieldViolation(): Readonly<Record<string, string>> {
    const out: Record<string, string> = {};
    for (const field of this.drawn) out[field.value] = this.violationOf(field.value);
    return out;
  }

  protected get confirmDisabled(): string | null {
    return this.busy() || this.valueOf('NewName').trim() === '' || this.valueOf('NewClass').trim() === '' ? 'true' : null;
  }

  protected onText(value: string, event: Event): void {
    const text = (event.target as HTMLInputElement).value;
    this.typed.update((current) => ({ ...current, [value]: text }));
    this.violations.set([]);
    this.reason.set('');
  }

  protected onEnter(event: Event): void {
    event.preventDefault();
    void this.onConfirm();
  }

  protected async onConfirm(): Promise<void> {
    if (this.confirmDisabled !== null) return;
    this.busy.set(true);
    this.reason.set('');
    this.violations.set([]);
    const values: Record<string, string> = { NewName: this.valueOf('NewName'), NewClass: this.valueOf('NewClass') };
    if (this.valueOf('NewCubes').trim() !== '') values['NewCubes'] = this.valueOf('NewCubes');
    const applied = await this.handler.sendFor(LISTING_GROUP_LIST, LISTING_GROUP_COPY_ACTION, this.source(), values, { setRefusal: () => undefined }, this.namespace());
    const refused = this.handler.lastRefusal();
    if (!applied && !this.closed) {
      this.violations.set(refused?.violations ?? []);
      this.reason.set((refused?.violations.length ?? 0) === 0 ? (refused?.reason ?? '') : '');
    }
    this.busy.set(false);
    if (applied && !this.closed) this.done.emit();
  }
}

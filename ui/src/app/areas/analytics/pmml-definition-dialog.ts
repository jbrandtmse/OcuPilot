import { ChangeDetectionStrategy, Component, DestroyRef, ElementRef, inject, input, output, signal, viewChild } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { reasonForField, type Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { PmmlModelStore } from './pmml-model.store';

/** How many New PMML definition dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/**
 * PMML models' New PMML definition (Story 24.14 Batch 3): a class field and a PMML text area, with Load from file beside it, and a primary action that posts through
 * `PmmlModelStore` to `namespace`. The text is pasted or read from a `.xml` or `.pmml` file in the browser, and only its text reaches the field.
 *
 * **Every sentence it shows is the server's** (AD-39): a violation on a field is drawn under it, any other refusal (a held class, a text the instance will not take, a refused
 * compile) above the fields. An accepted create emits `done`; Cancel, Escape and the scrim emit `cancelled`. The action is `aria-disabled` while either field is blank or a
 * create is in flight.
 */
@Component({
  selector: 'app-pmml-definition-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="STRINGS.analyticsPmmlNewAction" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    @if (reasonText) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-pmml-definition-reason>{{ reasonText }}</p>
    }
    <div class="ocu-form-fields">
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="classId">{{ STRINGS.explorerClassDocumentLabel }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            spellcheck="false"
            aria-required="true"
            data-pmml-definition-class
            [id]="classId"
            [value]="className"
            [attr.aria-invalid]="classViolation ? 'true' : null"
            (input)="onClass($event)"
            (keydown.enter)="onEnter($event)"
          />
        </div>
        @if (classViolation) {
          <p class="ocu-form-error" data-pmml-definition-class-violation>{{ classViolation }}</p>
        }
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="textId">{{ STRINGS.analyticsPmmlTextLabel }}</label>
        <div class="ocu-field-control">
          <textarea
            class="ocu-field-input ocu-field-textarea ocu-x509-pem"
            rows="10"
            autocomplete="off"
            spellcheck="false"
            aria-required="true"
            data-pmml-definition-text
            [id]="textId"
            [value]="text"
            [attr.aria-invalid]="textViolation ? 'true' : null"
            (input)="onText($event)"
          ></textarea>
        </div>
        <input #pmmlFile class="ocu-x509-file" type="file" accept=".xml,.pmml" tabindex="-1" aria-hidden="true" data-pmml-definition-file (change)="onFile($event)" />
        <button type="button" class="ocu-button-text" data-pmml-definition-load (click)="pickFile()">{{ STRINGS.x509LoadFromFile }}</button>
        @if (textViolation) {
          <p class="ocu-form-error" data-pmml-definition-text-violation>{{ textViolation }}</p>
        }
      </div>
    </div>
    <button dialogAction type="button" class="ocu-button-primary" data-pmml-definition-confirm [attr.aria-disabled]="confirmDisabled" (click)="onConfirm()">
      {{ STRINGS.analyticsPmmlNewAction }}
    </button>
  </app-dialog>`,
})
export class PmmlDefinitionDialog {
  /** The namespace the class is made in: the one the list reads. */
  readonly namespace = input.required<string>();

  /** Emitted once, after the instance applied the write. */
  readonly done = output<void>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly store = inject(PmmlModelStore);

  private readonly id = ++dialogCount;

  protected readonly classId = `ocu-pmml-definition-class-${this.id}`;

  protected readonly textId = `ocu-pmml-definition-text-${this.id}`;

  private readonly pmmlFile = viewChild<ElementRef<HTMLInputElement>>('pmmlFile');

  private readonly values = signal<{ readonly Class: string; readonly PMML: string }>({ Class: '', PMML: '' });

  private readonly reason = signal('');

  private readonly violations = signal<readonly Violation[]>([]);

  private readonly busy = signal(false);

  private closed = false;

  constructor() {
    inject(DestroyRef).onDestroy(() => {
      this.closed = true;
    });
  }

  protected get className(): string {
    return this.values().Class;
  }

  protected get text(): string {
    return this.values().PMML;
  }

  protected get reasonText(): string {
    return this.reason();
  }

  protected get classViolation(): string {
    return reasonForField(this.violations(), 'Class');
  }

  protected get textViolation(): string {
    return reasonForField(this.violations(), 'PMML');
  }

  protected get confirmDisabled(): string | null {
    return this.busy() || this.values().Class.trim() === '' || this.values().PMML.trim() === '' ? 'true' : null;
  }

  protected onClass(event: Event): void {
    const typed = (event.target as HTMLInputElement).value;
    this.values.update((current) => ({ ...current, Class: typed }));
    this.clearRefusal();
  }

  protected onText(event: Event): void {
    const typed = (event.target as HTMLTextAreaElement).value;
    this.values.update((current) => ({ ...current, PMML: typed }));
    this.clearRefusal();
  }

  protected onEnter(event: Event): void {
    event.preventDefault();
    void this.onConfirm();
  }

  /** Open the browser's own file picker. Nothing leaves the browser but the text. */
  protected pickFile(): void {
    this.pmmlFile()?.nativeElement.click();
  }

  /** Read the picked file as text into the PMML field, and clear the picker so the same file can be picked again. */
  protected onFile(event: Event): void {
    const target = event.target;
    if (!(target instanceof HTMLInputElement)) return;
    const file = target.files?.[0];
    target.value = '';
    if (file === undefined) return;
    const reader = new FileReader();
    reader.onload = () => {
      if (this.closed) return;
      const loaded = typeof reader.result === 'string' ? reader.result : '';
      this.values.update((current) => ({ ...current, PMML: loaded }));
      this.clearRefusal();
    };
    reader.readAsText(file);
  }

  private clearRefusal(): void {
    this.violations.set([]);
    this.reason.set('');
  }

  protected async onConfirm(): Promise<void> {
    if (this.confirmDisabled !== null) return;
    this.busy.set(true);
    this.clearRefusal();
    const typed = this.values();
    const outcome = await this.store.createDefinition(this.namespace(), { Class: typed.Class.trim(), PMML: typed.PMML });
    if (!outcome.accepted && !this.closed) {
      this.violations.set(outcome.violations);
      this.reason.set(outcome.violations.length === 0 ? outcome.reason : '');
    }
    this.busy.set(false);
    if (outcome.accepted && !this.closed) this.done.emit();
  }
}

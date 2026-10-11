import { ChangeDetectionStrategy, Component, DestroyRef, ElementRef, inject, input, output, signal, viewChild } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';
import { RestServiceCreateStore } from './rest-service-create.store';

/** How many create dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/**
 * Create REST service (Story 18.34): a package field and an OpenAPI 2.0 document field, each with its
 * hint, and a primary Create that posts through `RestServiceCreateStore` to `namespace`.
 *
 * The document is pasted into its field or loaded from a file with Load from file; the file is read
 * in the browser and only its text reaches the field. A refusal on a field is drawn under it and
 * named by it (`aria-invalid`, `aria-describedby`); any other refusal, such as a busy target or the
 * instance's own code, is drawn above the fields as an alert. Both are the server's sentences. An
 * accepted create emits `created` with the package; Cancel, Escape and the scrim emit `cancelled`.
 * Create is `aria-disabled` while either field is blank or a create is in flight.
 */
@Component({
  selector: 'app-rest-service-create-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="STRINGS.restServiceCreateTitle" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    @if (reason) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-rest-service-create-reason>{{ reason }}</p>
    }
    <div class="ocu-form-fields">
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="nameId">{{ STRINGS.tableColumnName }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            spellcheck="false"
            aria-required="true"
            data-rest-service-create-name
            [id]="nameId"
            [value]="name"
            [attr.aria-invalid]="nameViolation ? 'true' : null"
            [attr.aria-describedby]="nameDescribedBy"
            (input)="onNameInput($event)"
          />
        </div>
        <p class="ocu-field-caption" [id]="nameHintId">{{ STRINGS.restServiceNameHint }}</p>
        @if (nameViolation) {
          <p class="ocu-form-error" data-rest-service-create-name-violation [id]="nameReasonId">{{ nameViolation }}</p>
        }
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="documentId">{{ STRINGS.restServiceDocumentLabel }}</label>
        <div class="ocu-field-control">
          <textarea
            class="ocu-field-input ocu-field-textarea ocu-x509-pem"
            rows="10"
            autocomplete="off"
            spellcheck="false"
            aria-required="true"
            data-rest-service-create-document
            [id]="documentId"
            [value]="documentText"
            [attr.aria-invalid]="documentViolation ? 'true' : null"
            [attr.aria-describedby]="documentDescribedBy"
            (input)="onDocumentInput($event)"
          ></textarea>
        </div>
        <p class="ocu-field-caption" [id]="documentHintId">{{ STRINGS.restServiceDocumentHint }}</p>
        <input #documentFile class="ocu-x509-file" type="file" accept=".json" tabindex="-1" aria-hidden="true" data-rest-service-create-file (change)="onFile($event)" />
        <button type="button" class="ocu-button-text" data-rest-service-create-load (click)="pickFile()">{{ STRINGS.x509LoadFromFile }}</button>
        @if (documentViolation) {
          <p class="ocu-form-error" data-rest-service-create-document-violation [id]="documentReasonId">{{ documentViolation }}</p>
        }
      </div>
    </div>
    <button
      dialogAction
      type="button"
      class="ocu-button-primary"
      data-rest-service-create-confirm
      [attr.aria-disabled]="confirmDisabled"
      (click)="onConfirm()"
    >
      {{ STRINGS.restServiceCreateTitle }}
    </button>
  </app-dialog>`,
})
export class RestServiceCreateDialog {
  /** The namespace the service is built in: the one the list reads. */
  readonly namespace = input.required<string>();

  /** Emitted once, after the instance built the service, with its package. */
  readonly created = output<string>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly store = inject(RestServiceCreateStore);

  private readonly id = ++dialogCount;

  protected readonly nameId = `ocu-rest-service-create-name-${this.id}`;

  protected readonly nameHintId = `${this.nameId}-hint`;

  protected readonly nameReasonId = `${this.nameId}-reason`;

  protected readonly documentId = `ocu-rest-service-create-document-${this.id}`;

  protected readonly documentHintId = `${this.documentId}-hint`;

  protected readonly documentReasonId = `${this.documentId}-reason`;

  private readonly documentFile = viewChild<ElementRef<HTMLInputElement>>('documentFile');

  /** Bumped by the store, so the template re-reads it under `OnPush`. */
  private readonly generation = signal(0);

  /** Set when the dialog is destroyed, so a file read that finishes later writes nothing. */
  private gone = false;

  constructor() {
    this.store.reset();
    const stop = this.store.subscribe(() => this.generation.update((value) => value + 1));
    inject(DestroyRef).onDestroy(() => {
      this.gone = true;
      stop();
      this.store.reset();
    });
  }

  protected get name(): string {
    this.generation();
    return this.store.name();
  }

  protected get documentText(): string {
    this.generation();
    return this.store.documentText();
  }

  protected get nameViolation(): string {
    this.generation();
    return this.store.nameViolation();
  }

  protected get documentViolation(): string {
    this.generation();
    return this.store.documentViolation();
  }

  protected get reason(): string {
    this.generation();
    return this.store.reason();
  }

  protected get nameDescribedBy(): string {
    return this.nameViolation === '' ? this.nameHintId : `${this.nameHintId} ${this.nameReasonId}`;
  }

  protected get documentDescribedBy(): string {
    return this.documentViolation === '' ? this.documentHintId : `${this.documentHintId} ${this.documentReasonId}`;
  }

  protected get confirmDisabled(): string | null {
    this.generation();
    return this.store.busy() || this.store.name().trim() === '' || this.store.documentText().trim() === '' ? 'true' : null;
  }

  protected onNameInput(event: Event): void {
    this.store.setName((event.target as HTMLInputElement).value);
  }

  protected onDocumentInput(event: Event): void {
    this.store.setDocumentText((event.target as HTMLTextAreaElement).value);
  }

  /** Open the browser's own file picker. Nothing leaves the browser but the text. */
  protected pickFile(): void {
    this.documentFile()?.nativeElement.click();
  }

  /** Read the picked file as text into the document field, and clear the picker so the same file can be picked again. */
  protected onFile(event: Event): void {
    const target = event.target;
    if (!(target instanceof HTMLInputElement)) return;
    const file = target.files?.[0];
    target.value = '';
    if (file === undefined) return;
    const reader = new FileReader();
    reader.onload = () => {
      if (this.gone) return;
      this.store.setDocumentText(typeof reader.result === 'string' ? reader.result : '');
    };
    reader.readAsText(file);
  }

  protected async onConfirm(): Promise<void> {
    if (this.confirmDisabled !== null) return;
    const name = this.store.name();
    if (await this.store.create(this.namespace())) this.created.emit(name);
  }
}

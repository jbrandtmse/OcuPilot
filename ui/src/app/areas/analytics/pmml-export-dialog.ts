import { ChangeDetectionStrategy, Component, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { reasonForField, type Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import type { PmmlExportNames } from './pmml-test.store';

/** How many Export to cube dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/**
 * The Test screen's Export to cube (Story 24.14 Batch 4): the source the screen has chosen, shown as text, four fields that start at the classic's names (the result class, the cube, the cube class and,
 * optionally, a class the result rows link to), the consequence, and a primary action that emits the four names as typed. The page sends them through the shell's action path and keeps the dialog open
 * while it does.
 *
 * **Every sentence it shows is the server's** (AD-39) except the consequence, which is published once: a violation on a field is drawn under it, any other refusal (a held name, a test that did not finish,
 * a refused compile) above the fields. Cancel, Escape and the scrim emit `cancelled`. The action is `aria-disabled` while a name is blank or an export is in flight.
 */
@Component({
  selector: 'app-pmml-export-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="STRINGS.analyticsPmmlExportAction" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    @if (hasRefusal) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-pmml-export-reason>{{ refusal() }}</p>
    }
    <p data-pmml-export-consequence>{{ STRINGS.analyticsPmmlExportConsequence }}</p>
    <div class="ocu-form-fields">
      <div class="ocu-field">
        <span class="ocu-field-label" [attr.id]="sourceLabelId">{{ STRINGS.analyticsColumnDataSource }}</span>
        <p data-pmml-export-source [attr.aria-labelledby]="sourceLabelId">{{ source() }}</p>
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="resultId">{{ STRINGS.analyticsPmmlResultClassLabel }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            spellcheck="false"
            aria-required="true"
            data-pmml-export-result
            [id]="resultId"
            [value]="names().resultClass"
            [attr.aria-invalid]="resultViolation ? 'true' : null"
            (input)="onField('resultClass', $event)"
            (keydown.enter)="onEnter($event)"
          />
        </div>
        @if (resultViolation) {
          <p class="ocu-form-error" data-pmml-export-result-violation>{{ resultViolation }}</p>
        }
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="cubeId">{{ STRINGS.analyticsPmmlCubeNameLabel }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            spellcheck="false"
            aria-required="true"
            data-pmml-export-cube
            [id]="cubeId"
            [value]="names().cube"
            [attr.aria-invalid]="cubeViolation ? 'true' : null"
            (input)="onField('cube', $event)"
            (keydown.enter)="onEnter($event)"
          />
        </div>
        @if (cubeViolation) {
          <p class="ocu-form-error" data-pmml-export-cube-violation>{{ cubeViolation }}</p>
        }
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="cubeClassId">{{ STRINGS.analyticsPmmlCubeClassLabel }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            spellcheck="false"
            aria-required="true"
            data-pmml-export-cube-class
            [id]="cubeClassId"
            [value]="names().cubeClass"
            [attr.aria-invalid]="cubeClassViolation ? 'true' : null"
            (input)="onField('cubeClass', $event)"
            (keydown.enter)="onEnter($event)"
          />
        </div>
        @if (cubeClassViolation) {
          <p class="ocu-form-error" data-pmml-export-cube-class-violation>{{ cubeClassViolation }}</p>
        }
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="sourceClassId">{{ STRINGS.analyticsPmmlSourceClassLabel }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            spellcheck="false"
            data-pmml-export-source-class
            [id]="sourceClassId"
            [value]="names().sourceClass"
            [attr.aria-invalid]="sourceClassViolation ? 'true' : null"
            (input)="onField('sourceClass', $event)"
            (keydown.enter)="onEnter($event)"
          />
        </div>
        @if (sourceClassViolation) {
          <p class="ocu-form-error" data-pmml-export-source-class-violation>{{ sourceClassViolation }}</p>
        }
      </div>
    </div>
    <button dialogAction type="button" class="ocu-button-primary" data-pmml-export-confirm [attr.aria-disabled]="confirmDisabled" (click)="onConfirm()">
      {{ STRINGS.analyticsPmmlExportAction }}
    </button>
  </app-dialog>`,
})
export class PmmlExportDialog {
  /** The source the screen has chosen, as text. */
  readonly source = input.required<string>();

  /** The names the fields start at. */
  readonly defaults = input.required<PmmlExportNames>();

  /** Whether an export is in flight. */
  readonly sending = input<boolean>(false);

  /** The refusal that is not about one field, or `''`. */
  readonly refusal = input<string>('');

  /** The refusals the instance named a field for. */
  readonly violations = input<readonly Violation[]>([]);

  /** Emitted with the four names as typed. */
  readonly submitted = output<PmmlExportNames>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly id = ++dialogCount;

  protected readonly sourceLabelId = `ocu-pmml-export-source-label-${this.id}`;

  protected readonly resultId = `ocu-pmml-export-result-${this.id}`;

  protected readonly cubeId = `ocu-pmml-export-cube-${this.id}`;

  protected readonly cubeClassId = `ocu-pmml-export-cube-class-${this.id}`;

  protected readonly sourceClassId = `ocu-pmml-export-source-class-${this.id}`;

  /** What the person has typed over the defaults, `null` for a field left at its default. */
  private readonly typed = signal<Partial<PmmlExportNames>>({});

  /** The four names now: each typed value, else its default. */
  protected readonly names = (): PmmlExportNames => {
    const typed = this.typed();
    const defaults = this.defaults();
    return {
      resultClass: typed.resultClass ?? defaults.resultClass,
      cubeClass: typed.cubeClass ?? defaults.cubeClass,
      cube: typed.cube ?? defaults.cube,
      sourceClass: typed.sourceClass ?? defaults.sourceClass,
    };
  };

  protected get hasRefusal(): boolean {
    return this.refusal() !== '';
  }

  protected get resultViolation(): string {
    return reasonForField(this.violations(), 'ResultClass');
  }

  protected get cubeViolation(): string {
    return reasonForField(this.violations(), 'Cube');
  }

  protected get cubeClassViolation(): string {
    return reasonForField(this.violations(), 'CubeClass');
  }

  protected get sourceClassViolation(): string {
    return reasonForField(this.violations(), 'SourceClass');
  }

  protected get confirmDisabled(): string | null {
    const names = this.names();
    return this.sending() || names.resultClass.trim() === '' || names.cubeClass.trim() === '' || names.cube.trim() === '' ? 'true' : null;
  }

  protected onField(field: keyof PmmlExportNames, event: Event): void {
    const value = (event.target as HTMLInputElement).value;
    this.typed.update((current) => ({ ...current, [field]: value }));
  }

  protected onEnter(event: Event): void {
    event.preventDefault();
    this.onConfirm();
  }

  protected onConfirm(): void {
    if (this.confirmDisabled !== null) return;
    this.submitted.emit(this.names());
  }
}

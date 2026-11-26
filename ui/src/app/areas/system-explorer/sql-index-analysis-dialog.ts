import { ChangeDetectionStrategy, Component, computed, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';

/** How many dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/** The choices Proceed hands on, each as the tool declares it. `report` is a report code and is `''` for a gathering. */
export interface IndexAnalysisChoices {
  readonly report: string;
  readonly skipSystem: boolean;
  readonly skipInserts: boolean;
  readonly skipIdKeys: boolean;
}

/** The five reports, each by the code the instance takes. */
const REPORTS: readonly { readonly code: string; readonly label: string }[] = [
  { code: 'IU', label: STRINGS.sqlIndexAnalysisReportIU },
  { code: 'TS', label: STRINGS.sqlIndexAnalysisReportTS },
  { code: 'TI', label: STRINGS.sqlIndexAnalysisReportTI },
  { code: 'JI', label: STRINGS.sqlIndexAnalysisReportJI },
  { code: 'OI', label: STRINGS.sqlIndexAnalysisReportOI },
];

/**
 * SQL index analyzer's Gather statements and Run report dialogs (Story 21.27): the title is the action's name, the body is the consequence the action
 * states, and the fields are the choices the action declares, each box on as the classic page starts. A gathering asks for the two skip boxes, and its
 * consequence adds the sentence about the wait when system classes and routines are included. A run asks for the report and the three boxes.
 *
 * Nothing is validated here: the instance judges every value and a refusal it sends is passed back as `refusal`, which stays in the dialog. Proceed is
 * `aria-disabled` while a send is in flight.
 */
@Component({
  selector: 'app-sql-index-analysis-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="heading()" [closeLabel]="STRINGS.actionCancel" (closed)="onClosed()">
    <p class="ocu-warning-consequence" data-slot="consequence">{{ consequence() }}</p>
    @if (isRun) {
      <div class="ocu-field" data-slot="report">
        <label class="ocu-field-label" [for]="reportId">{{ STRINGS.databaseIntegrityStepReport }}</label>
        <div class="ocu-field-control">
          <select class="ocu-field-input" [id]="reportId" (change)="onReport($event)">
            @for (option of reports; track option.code) {
              <option [value]="option.code" [selected]="option.code === report()">{{ option.label }}</option>
            }
          </select>
        </div>
      </div>
    }
    <label class="ocu-criteria-marker" data-slot="skip-system">
      <input type="checkbox" [checked]="skipSystem()" (change)="onSkipSystem($event)" />
      {{ STRINGS.sqlIndexAnalysisSkipSystemLabel }}
    </label>
    <label class="ocu-criteria-marker" data-slot="skip-inserts">
      <input type="checkbox" [checked]="skipInserts()" (change)="onSkipInserts($event)" />
      {{ STRINGS.sqlIndexAnalysisSkipInsertsLabel }}
    </label>
    @if (isRun) {
      <label class="ocu-criteria-marker" data-slot="skip-idkeys">
        <input type="checkbox" [checked]="skipIdKeys()" (change)="onSkipIdKeys($event)" />
        {{ STRINGS.sqlIndexAnalysisSkipIdKeysLabel }}
      </label>
    }
    @if (hasRefusal) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-slot="refusal">{{ refusal() }}</p>
    }
    <button dialogAction type="button" class="ocu-button-primary" data-slot="proceed" [attr.aria-disabled]="proceedDisabled" (click)="submit()">
      {{ STRINGS.actionProceed }}
    </button>
  </app-dialog>`,
})
export class SqlIndexAnalysisDialog {
  /** `'gather'` or `'run'`: which action this dialog confirms. */
  readonly mode = input.required<'gather' | 'run'>();

  /** A send is in flight. */
  readonly sending = input<boolean>(false);

  /** The instance's refusal sentence, or `''`. */
  readonly refusal = input<string>('');

  /** Emitted once per Proceed, with the choices made. */
  readonly submitted = output<IndexAnalysisChoices>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  protected readonly reports = REPORTS;

  protected readonly reportId = `ocu-index-analysis-report-${++dialogCount}`;

  protected readonly report = signal('IU');

  protected readonly skipSystem = signal(true);

  protected readonly skipInserts = signal(true);

  protected readonly skipIdKeys = signal(true);

  protected readonly heading = computed(() => (this.mode() === 'run' ? STRINGS.sqlIndexAnalysisRunAction : STRINGS.sqlIndexAnalysisGatherAction));

  /** The sentence the action states: a gathering that includes system classes and routines says it outlasts the page's wait. */
  protected readonly consequence = computed(() => {
    if (this.mode() === 'run') return STRINGS.sqlIndexAnalysisRunConsequence;
    return this.skipSystem() ? STRINGS.sqlIndexAnalysisGatherConsequence : STRINGS.sqlIndexAnalysisGatherSystemConsequence;
  });

  private closed = false;

  protected get isRun(): boolean {
    return this.mode() === 'run';
  }

  protected get hasRefusal(): boolean {
    return this.refusal() !== '';
  }

  protected get proceedDisabled(): string | null {
    return this.sending() ? 'true' : null;
  }

  protected onReport(event: Event): void {
    this.report.set((event.target as HTMLSelectElement).value);
  }

  protected onSkipSystem(event: Event): void {
    this.skipSystem.set((event.target as HTMLInputElement).checked);
  }

  protected onSkipInserts(event: Event): void {
    this.skipInserts.set((event.target as HTMLInputElement).checked);
  }

  protected onSkipIdKeys(event: Event): void {
    this.skipIdKeys.set((event.target as HTMLInputElement).checked);
  }

  /** Hand the choices on once, while no send is in flight. */
  protected submit(): void {
    if (this.sending()) return;
    this.submitted.emit({
      report: this.isRun ? this.report() : '',
      skipSystem: this.skipSystem(),
      skipInserts: this.skipInserts(),
      skipIdKeys: this.skipIdKeys(),
    });
  }

  protected onClosed(): void {
    if (this.closed) return;
    this.closed = true;
    this.cancelled.emit();
  }
}

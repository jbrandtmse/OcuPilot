import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { FormDirty } from '../../core/form-dirty';
import { withQuery } from '../../core/navigation';
import { STRINGS } from '../../core/strings';
import { tabErrorCounts } from '../../core/form-tabs';
import { Dialog } from '../../shell/dialog';
import { FormStepBody, FormStepper, type FormStepView } from '../../shell/form-stepper';
import { operationLine } from './database-operation';
import {
  DATABASE_LIST_ROUTE,
  DATABASES_FIELD,
  DATABASES_STEP,
  DatabaseIntegrityFlow,
  GLOBALS_FIELD,
  GLOBALS_STEP,
  INTEGRITY_LOG_ROUTE,
  INTEGRITY_STEPS,
  REPORT_STEP,
} from './database-integrity.store';

/** Which step each refusable field belongs to, which the stepper counts refusals by. */
const FIELD_STEPS: Readonly<Record<string, string>> = {
  [DATABASES_FIELD]: DATABASES_STEP,
  [GLOBALS_FIELD]: GLOBALS_STEP,
};

/** The step titles, in order: the Databases list's title, "Globals" and "Report". */
const STEP_LABELS: Readonly<Record<string, string>> = {
  [DATABASES_STEP]: STRINGS.databaseListLabel,
  [GLOBALS_STEP]: STRINGS.processColumnGlobals,
  [REPORT_STEP]: STRINGS.databaseIntegrityStepReport,
};

/** One database of the checklist, resolved for drawing. */
interface DatabaseView {
  readonly directory: string;
  readonly status: string;
  readonly id: string;
  readonly checked: boolean;
}

/**
 * The Check integrity flow (Story 18.4, AC6): a `form-page` on `os-management/databases/integrity`,
 * opened from the Databases list's Check integrity.
 *
 * **Three steps on `app-form-stepper`.** Databases is a checklist of the Databases list's declared
 * read -- each database's directory and status, with Check all -- of which at least one is checked.
 * Globals names the globals to check, one per line, only while one database is checked; with more,
 * the field is unavailable and says why. Next asks the instance to check both (`POST
 * /database/check`), and a refusal is drawn on its field and counted on its step. Report's primary is
 * Check integrity.
 *
 * **Report.** While the check runs, the running line; once it finishes, the check's report from the
 * Integrity log's declared read, its start time above its lines on the code surface; a check still
 * running past the port's wait reads the still-running sentence. Either way the flow offers Open the
 * integrity log. A refusal is the envelope's own sentence.
 *
 * **Leaving.** The page opens clean; an edit arms the unsaved-changes guard and the sent check
 * disarms it.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-database-integrity-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog, FormStepper, FormStepBody],
  template: `<section class="ocu-form-page">
    @if (hasReason) {
      <p class="ocu-banner ocu-banner-warning" role="alert">{{ reason }}</p>
    }
    @if (showFault) {
      <div class="ocu-data-table-refusal" role="alert">
        <span class="ocu-data-table-refusal-message">{{ STRINGS.connectivityRequestRefused }}</span>
        <button type="button" class="ocu-button-text" (click)="onRetry()">{{ STRINGS.actionRetry }}</button>
      </div>
    }

    @if (loadedFlag) {
    <app-form-stepper [steps]="steps" [selected]="stepKey" (selectedChange)="goTo($event)">
      <ng-template ocuFormStep="databases">
        <fieldset class="ocu-field ocu-form-fields" data-integrity="databases" [attr.aria-describedby]="databasesDescribedBy">
          <legend class="ocu-field-label">{{ STRINGS.databaseListLabel }}</legend>
          <label class="ocu-field-checkbox">
            <input type="checkbox" [id]="checkAllId" [checked]="allChecked" (change)="onCheckAll()" />
            <span>{{ STRINGS.tableCheckAll }}</span>
          </label>
          @for (view of databaseViews; track view.directory) {
            <label class="ocu-field-checkbox" [attr.data-directory]="view.directory">
              <input type="checkbox" [id]="view.id" [checked]="view.checked" (change)="onCheck(view.directory, $event)" />
              <span>{{ view.directory }}</span>
              <span class="ocu-field-caption">{{ view.status }}</span>
            </label>
          }
          @if (databasesInvalid) {
            <p class="ocu-form-error" [id]="databasesReasonId">{{ databasesReason }}</p>
          }
        </fieldset>
      </ng-template>

      <ng-template ocuFormStep="globals">
        <div class="ocu-form-fields" data-integrity="globals">
          <div class="ocu-field">
            <label class="ocu-field-label" [attr.for]="globalsId">{{ STRINGS.databaseIntegrityGlobalsOnly }}</label>
            <textarea
              class="ocu-field-input ocu-field-textarea"
              rows="4"
              spellcheck="false"
              [id]="globalsId"
              [value]="globalsValue"
              [attr.aria-disabled]="globalsDisabled"
              [readOnly]="globalsLocked"
              [attr.aria-invalid]="globalsInvalid"
              [attr.aria-describedby]="globalsDescribedBy"
              (input)="onGlobals($event)"
            ></textarea>
            <p class="ocu-field-caption" [id]="globalsHintId">{{ globalsCaption }}</p>
            @if (globalsInvalid) {
              <p class="ocu-form-error" [id]="globalsReasonId">{{ globalsReason }}</p>
            }
          </div>
        </div>
      </ng-template>

      <ng-template ocuFormStep="report">
        <div class="ocu-form-fields" data-integrity="report">
          <p class="ocu-namespace-copy-status" role="status" data-integrity="status">{{ statusLine }}</p>
          @if (hasReport) {
            <p class="ocu-field-caption" data-integrity="report-time">{{ reportTime }}</p>
            <pre class="ocu-log-raw" data-integrity="report-lines">{{ reportText }}</pre>
          }
          @if (showOpenLog) {
            <div class="ocu-form-actions">
              <button type="button" class="ocu-button-text" data-integrity="open-log" (click)="onOpenLog()">
                {{ STRINGS.databaseIntegrityOpenLog }}
              </button>
            </div>
          }
        </div>
      </ng-template>
    </app-form-stepper>

    <div class="ocu-form-bar">
      <div class="ocu-form-bar-status"></div>
      <div class="ocu-form-bar-actions">
        <button type="button" class="ocu-button-text" (click)="cancel()">{{ STRINGS.actionCancel }}</button>
        @if (canGoBack) {
          <button type="button" class="ocu-button-secondary" (click)="onBack()">{{ STRINGS.errorLogBack }}</button>
        }
        @if (lastStep) {
          <button type="button" class="ocu-button-primary" [attr.aria-disabled]="checkBlocked" (click)="onCheckIntegrity()">
            {{ STRINGS.databaseIntegrityLabel }}
          </button>
        } @else {
          <button type="button" class="ocu-button-primary" [attr.aria-disabled]="busy" (click)="onNext()">{{ STRINGS.actionNext }}</button>
        }
      </div>
    </div>
    }

    @if (leavePending) {
      <app-dialog [heading]="STRINGS.formLeaveWithoutSaving" [closeLabel]="STRINGS.actionCancel" (closed)="answerLeave(false)">
        <button dialogAction type="button" class="ocu-button-primary" (click)="answerLeave(true)">
          {{ STRINGS.actionConfirm }}
        </button>
      </app-dialog>
    }
  </section>`,
})
export class DatabaseIntegrityPage {
  private readonly store = inject(DatabaseIntegrityFlow);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);

  protected readonly STRINGS = STRINGS;

  protected readonly checkAllId = 'ocu-integrity-check-all';

  protected readonly globalsId = 'ocu-integrity-globals';

  protected readonly globalsHintId = 'ocu-integrity-globals-hint';

  protected readonly globalsReasonId = 'ocu-integrity-globals-reason';

  protected readonly databasesReasonId = 'ocu-integrity-databases-reason';

  /** Bumped by the stores, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  constructor() {
    const stopStore = this.store.subscribe(() => this.bump());
    const stopDirty = this.formDirty.subscribe(() => this.bump());
    void this.store.open();
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopDirty();
      this.store.reset();
    });
  }

  // --- reads -----------------------------------------------------------------------------------

  protected get loadedFlag(): boolean {
    this.generation();
    return this.store.loaded() && !this.store.fault();
  }

  protected get showFault(): boolean {
    this.generation();
    return this.store.loaded() && this.store.fault();
  }

  protected get reason(): string {
    this.generation();
    return this.store.reason();
  }

  protected get hasReason(): boolean {
    return this.reason !== '';
  }

  protected get stepKey(): string {
    this.generation();
    return this.store.step();
  }

  protected get steps(): readonly FormStepView[] {
    this.generation();
    const violations = this.store.violations();
    const counts = tabErrorCounts(FIELD_STEPS, violations);
    return INTEGRITY_STEPS.map((key) => ({
      key,
      label: STEP_LABELS[key],
      count: counts[key] ?? 0,
      firstReason: violations.find((entry) => FIELD_STEPS[entry.field] === key)?.reason ?? '',
      reachable: this.store.reachable(key),
    }));
  }

  protected get databaseViews(): readonly DatabaseView[] {
    this.generation();
    return this.store.databases().map((row, index) => ({
      directory: row.directory,
      status: row.status,
      id: `ocu-integrity-database-${index}`,
      checked: this.store.checked(row.directory),
    }));
  }

  protected get allChecked(): boolean {
    this.generation();
    return this.store.allChecked();
  }

  protected get databasesReason(): string {
    this.generation();
    return this.store.violationFor(DATABASES_FIELD);
  }

  protected get databasesInvalid(): boolean {
    return this.databasesReason !== '';
  }

  protected get databasesDescribedBy(): string | null {
    return this.databasesInvalid ? this.databasesReasonId : null;
  }

  protected get globalsValue(): string {
    this.generation();
    return this.store.globals();
  }

  /** Unavailable, and saying why, while more than one database is checked. */
  protected get globalsDisabled(): 'true' | null {
    this.generation();
    return this.store.globalsEnabled() ? null : 'true';
  }

  protected get globalsLocked(): boolean {
    return this.globalsDisabled !== null;
  }

  protected get globalsCaption(): string {
    return this.globalsLocked ? STRINGS.databaseGlobalsOneDatabase : STRINGS.databaseGlobalsHint;
  }

  protected get globalsReason(): string {
    this.generation();
    return this.store.violationFor(GLOBALS_FIELD);
  }

  protected get globalsInvalid(): 'true' | null {
    return this.globalsReason === '' ? null : 'true';
  }

  protected get globalsDescribedBy(): string {
    return this.globalsInvalid === null ? this.globalsHintId : `${this.globalsHintId} ${this.globalsReasonId}`;
  }

  protected get busy(): 'true' | null {
    this.generation();
    return this.store.checking() ? 'true' : null;
  }

  protected get lastStep(): boolean {
    return this.stepKey === REPORT_STEP;
  }

  protected get canGoBack(): boolean {
    return this.stepKey !== DATABASES_STEP;
  }

  /** Check integrity waits while a request is in flight, and once the check has been sent. */
  protected get checkBlocked(): 'true' | null {
    this.generation();
    return this.store.checking() || this.store.outcome() !== 'none' ? 'true' : null;
  }

  /** The running line, the finished line, or the still-running sentence; `''` before the check. */
  protected get statusLine(): string {
    this.generation();
    const outcome = this.store.outcome();
    if (outcome === 'running') return operationLine(STRINGS.databaseIntegrityLabel, 'running', this.store.since());
    if (outcome === 'finished') return operationLine(STRINGS.databaseIntegrityLabel, 'finished', null);
    if (outcome === 'continues') return STRINGS.auditDatabaseStillRunning;
    return '';
  }

  protected get hasReport(): boolean {
    this.generation();
    return this.store.reportLines().length > 0;
  }

  protected get reportTime(): string {
    this.generation();
    return this.store.reportTime().slice(0, 19).replace('T', ' ');
  }

  protected get reportText(): string {
    this.generation();
    return this.store.reportLines().join('\n');
  }

  protected get showOpenLog(): boolean {
    this.generation();
    const outcome = this.store.outcome();
    return outcome === 'finished' || outcome === 'continues';
  }

  protected get leavePending(): boolean {
    this.generation();
    return this.formDirty.pending();
  }

  // --- intents ---------------------------------------------------------------------------------

  protected onCheck(directory: string, event: Event): void {
    this.store.setChecked(directory, (event.target as HTMLInputElement).checked);
  }

  protected onCheckAll(): void {
    this.store.toggleAll();
  }

  protected onGlobals(event: Event): void {
    if (this.globalsLocked) return;
    this.store.setGlobals((event.target as HTMLTextAreaElement).value);
  }

  protected goTo(key: string): void {
    this.store.goTo(key);
  }

  protected onBack(): void {
    this.store.back();
  }

  protected onNext(): void {
    if (this.busy !== null) return;
    void this.store.next();
  }

  protected onCheckIntegrity(): void {
    if (this.checkBlocked !== null) return;
    void this.store.check();
  }

  protected onRetry(): void {
    void this.store.open();
  }

  protected onOpenLog(): void {
    void this.router.navigateByUrl(withQuery(INTEGRITY_LOG_ROUTE, this.router.url));
  }

  protected cancel(): void {
    void this.router.navigateByUrl(withQuery(DATABASE_LIST_ROUTE, this.router.url));
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  // --- internals -------------------------------------------------------------------------------

  private bump(): void {
    this.generation.update((value) => value + 1);
  }
}

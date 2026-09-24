import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  ElementRef,
  Injector,
  afterNextRender,
  inject,
  signal,
  viewChild,
} from '@angular/core';
import { Router } from '@angular/router';

import { encodeEntityId } from '../../core/entity-id';
import { tabErrorCounts, tabToOpen } from '../../core/form-tabs';
import { FormDirty } from '../../core/form-dirty';
import { detailScreenFor, screenForRoute, withQuery } from '../../core/navigation';
import { STRINGS } from '../../core/strings';
import type { Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { FormStepBody, FormStepper, type FormStepView } from '../../shell/form-stepper';
import { BASICS_STEP, OPTIONS_STEP, SCHEDULE_STEP, TYPE_STEP, fieldOrder, fieldSteps } from './task-fields';
import { TaskFieldGroup, taskControlId } from './task-field-group';
import { TaskWizard } from './task-wizard.store';

/** The list this wizard is reached from, which Cancel returns to. */
export const TASK_LIST_ROUTE = 'tasks/schedule';

/**
 * The New Task wizard (Story 9.7, FR-52, AD-55): a four-step `form-page` on `tasks/schedule/edit`,
 * reached from the Task schedule's Create.
 *
 * **It is a linear vertical stepper** (`app-form-stepper`): Basics, Task type and settings,
 * Schedule, and Options and notifications. Next checks the values so far on the server and opens
 * the next step only when the current one earns no violation; Back keeps every value; the last
 * step's primary reads "Create task"; Cancel returns to Task schedule. A step in error carries the
 * destructive marker and names its first refusal in text.
 *
 * **A refused Create opens the step holding the first refused field**, focuses the error summary and
 * then that field. An accepted one replaces this route with the new task's details and publishes one
 * `task` `created` change event (the store's).
 *
 * **The Schedule step draws only what the chosen period and frequency read** (`task-fields.ts`), and
 * **Run as another account states its effect** under the field before Create (AD-10).
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-task-wizard-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog, FormStepper, FormStepBody, TaskFieldGroup],
  template: `<section class="ocu-form-page">
    @if (hasSummary) {
      <div #summary class="ocu-banner ocu-form-summary" role="alert" tabindex="-1">
        <ul class="ocu-form-summary-list">
          @for (entry of violations; track $index) {
            <li>
              <button type="button" class="ocu-button-text" (click)="focusField(entry.field)">
                {{ entry.reason }}
              </button>
            </li>
          }
        </ul>
      </div>
    }
    @if (hasReason) {
      <p class="ocu-banner ocu-banner-warning" role="alert">{{ reason }}</p>
    }

    @if (loadedFlag) {
    <p class="ocu-form-legend">{{ STRINGS.formRequiredFieldsLegend }}</p>
    <app-form-stepper [steps]="steps" [selected]="stepKey" (selectedChange)="goTo($event)">
      <ng-template ocuFormStep="basics">
        <app-task-field-group step="basics" />
      </ng-template>

      <ng-template ocuFormStep="type">
        <app-task-field-group step="type" />
      </ng-template>

      <ng-template ocuFormStep="schedule">
        <app-task-field-group step="schedule" />
      </ng-template>

      <ng-template ocuFormStep="options">
        <app-task-field-group step="options" />
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
          <button type="button" class="ocu-button-primary" [attr.aria-disabled]="busy" (click)="onCreate()">{{ STRINGS.taskCreate }}</button>
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
export class TaskWizardPage {
  private readonly store = inject(TaskWizard);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly injector = inject(Injector);

  protected readonly STRINGS = STRINGS;

  /** Bumped by the stores, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  /** Whether the summary has been focused for the refusal now on screen. */
  private focusedSummary = false;

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
    return this.store.loaded();
  }

  protected get stepKey(): string {
    this.generation();
    return this.store.step();
  }

  protected get steps(): readonly FormStepView[] {
    this.generation();
    const settingNames = this.store.type()?.settings.map((setting) => setting.name) ?? [];
    const map = fieldSteps(settingNames);
    const violations = this.store.violations();
    const counts = tabErrorCounts(map, violations);
    const firstOf = (step: string): string => {
      const order = fieldOrder(settingNames);
      const rank = (field: string): number => (order.includes(field) ? order.indexOf(field) : order.length);
      const mine = violations.filter((entry) => map[entry.field] === step);
      if (mine.length === 0) return '';
      return mine.reduce((best, entry) => (rank(entry.field) < rank(best.field) ? entry : best)).reason;
    };
    const view = (key: string, label: string): FormStepView => ({ key, label, count: counts[key] ?? 0, firstReason: firstOf(key), reachable: this.store.reachable(key) });
    return [
      view(BASICS_STEP, STRINGS.taskStepBasics),
      view(TYPE_STEP, STRINGS.taskStepType),
      view(SCHEDULE_STEP, STRINGS.taskDetailsSchedule),
      view(OPTIONS_STEP, STRINGS.taskStepOptions),
    ];
  }

  protected get violations(): readonly Violation[] {
    this.generation();
    return this.store.violations();
  }

  protected get hasSummary(): boolean {
    return this.violations.length > 0;
  }

  protected get reason(): string {
    this.generation();
    return this.store.reason();
  }

  protected get hasReason(): boolean {
    return this.reason !== '';
  }

  protected get busy(): boolean {
    this.generation();
    return this.store.busy();
  }

  protected get lastStep(): boolean {
    this.generation();
    return this.store.isLastStep();
  }

  protected get canGoBack(): boolean {
    this.generation();
    return !this.store.isFirstStep();
  }

  protected get leavePending(): boolean {
    this.generation();
    return this.formDirty.pending();
  }

  // --- intents ---------------------------------------------------------------------------------

  protected goTo(step: string): void {
    this.store.goTo(step);
  }

  protected async onNext(): Promise<void> {
    if (this.store.busy()) return;
    const advanced = await this.store.next();
    if (!advanced) this.afterRefusal();
  }

  protected onBack(): void {
    this.store.back();
  }

  protected async onCreate(): Promise<void> {
    if (this.store.busy()) return;
    const created = await this.store.create();
    if (!created) {
      this.afterRefusal();
      return;
    }
    // The page is replaced by the new task's details, so the address bar names the entity and Back
    // goes to the list.
    const id = this.store.createdId();
    if (id !== '') void this.router.navigateByUrl(this.detailsUrl(id), { replaceUrl: true });
  }

  /** Open the step that holds `field`, then focus it. */
  protected focusField(field: string): void {
    const step = this.stepFor(field);
    if (step !== null && step !== this.store.step()) {
      this.store.showStep(step);
      afterNextRender(() => this.focusControl(field), { injector: this.injector });
      return;
    }
    this.focusControl(field);
  }

  protected cancel(): void {
    void this.router.navigateByUrl(withQuery(TASK_LIST_ROUTE, this.router.url));
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  // --- internals -------------------------------------------------------------------------------

  private bump(): void {
    this.generation.update((value) => value + 1);
  }

  private settingNames(): readonly string[] {
    return this.store.type()?.settings.map((setting) => setting.name) ?? [];
  }

  private stepFor(field: string): string | null {
    const map = fieldSteps(this.settingNames());
    return Object.hasOwn(map, field) ? map[field] : null;
  }

  /**
   * After a refused Next or Create: the step that holds the first refused field opens, the error
   * summary takes focus, then that field, in the order EXPERIENCE.md's `form-page` rule states.
   */
  private afterRefusal(): void {
    const names = this.settingNames();
    const open = tabToOpen(fieldSteps(names), fieldOrder(names), this.store.violations());
    if (open !== null) this.store.showStep(open);
    if (this.store.violations()[0] === undefined) return;
    this.focusedSummary = false;
    afterNextRender(() => this.focusRefusal(), { injector: this.injector });
  }

  private focusRefusal(): void {
    if (this.focusedSummary) return;
    const violations = this.store.violations();
    if (violations[0] === undefined) return;
    this.focusedSummary = true;
    this.summary()?.nativeElement.focus();
    const order = fieldOrder(this.settingNames());
    const rank = (field: string): number => (order.includes(field) ? order.indexOf(field) : order.length);
    const first = violations.reduce((best, entry) => (rank(entry.field) < rank(best.field) ? entry : best));
    this.focusControl(first.field);
  }

  private focusControl(field: string): void {
    document.getElementById(taskControlId(field))?.focus();
  }

  /** The new task's details URL. The id is `encodeEntityId`'s, never `encodeURIComponent`'s (AD-13). */
  private detailsUrl(id: string): string {
    const list = screenForRoute(TASK_LIST_ROUTE);
    const details = list === null ? null : detailScreenFor(list);
    const route = details === null ? `${TASK_LIST_ROUTE}/details` : details.route;
    return withQuery(`${route}/${encodeEntityId(id)}`, this.router.url);
  }
}

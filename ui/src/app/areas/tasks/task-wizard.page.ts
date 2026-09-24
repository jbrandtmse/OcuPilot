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
import { ScopeService } from '../../core/scope';
import { Session } from '../../core/session';
import { STRINGS } from '../../core/strings';
import type { Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { FormStepBody, FormStepper, type FormStepView } from '../../shell/form-stepper';
import { scheduleWords } from './details.store';
import {
  BASICS_STEP,
  FLAG_FIELDS,
  FREQUENCIES,
  FREQUENCY_TIMES,
  MIRROR_STATUSES,
  OPTIONS_STEP,
  PERIODS,
  PRIORITIES,
  SCHEDULE_STEP,
  SETTING_PREFIX,
  TYPE_STEP,
  applies,
  fieldOrder,
  fieldSteps,
} from './task-fields';
import { type TaskSetting, TaskWizard } from './task-wizard.store';

/** The list this wizard is reached from, which Cancel returns to. */
export const TASK_LIST_ROUTE = 'tasks/schedule';

/** The placeholder the classic-only sentence leaves for the settings' names. */
const SETTINGS_PLACEHOLDER = '<settings>';

/** One option of a select: the value the wire carries and the word the person reads. */
interface Choice {
  readonly value: string;
  readonly label: string;
}

/** One field, resolved for drawing. */
interface FieldView {
  readonly field: string;
  readonly id: string;
  readonly label: string;
  readonly value: string;
  readonly checked: boolean;
  readonly options: readonly Choice[];
  readonly required: boolean;
  readonly reason: string;
  readonly invalid: boolean;
  readonly describedBy: string | null;
  readonly shown: boolean;
  /** Drawn as a checkbox. */
  readonly flag: boolean;
  /** Drawn as the period's own day control. */
  readonly day: boolean;
  /** Drawn as a plain input or select. */
  readonly plain: boolean;
  readonly caption: string;
}

/** One setting of the chosen type, resolved for drawing. */
interface SettingView extends FieldView {
  readonly kind: string;
}

/** One weekday box of a Weekly schedule. */
interface DayView {
  readonly digit: string;
  readonly id: string;
  readonly label: string;
  readonly checked: boolean;
}

const WEEKDAYS: readonly string[] = [
  STRINGS.weekdaySunday,
  STRINGS.weekdayMonday,
  STRINGS.weekdayTuesday,
  STRINGS.weekdayWednesday,
  STRINGS.weekdayThursday,
  STRINGS.weekdayFriday,
  STRINGS.weekdaySaturday,
];

const WEEKS: readonly string[] = [STRINGS.ordinalFirst, STRINGS.ordinalSecond, STRINGS.ordinalThird, STRINGS.ordinalFourth, STRINGS.ordinalLast];

const PERIOD_LABELS: readonly string[] = [
  STRINGS.taskPeriodDaily,
  STRINGS.taskPeriodWeekly,
  STRINGS.taskPeriodMonthly,
  STRINGS.taskPeriodMonthlySpecial,
  STRINGS.taskScheduleRunAfter,
  STRINGS.taskScheduleOnDemand,
];

function choices(values: readonly string[], labels: readonly string[]): readonly Choice[] {
  return values.map((value, index) => ({ value, label: labels[index] ?? value }));
}

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
  imports: [Dialog, FormStepper, FormStepBody],
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
        <div class="ocu-form-fields">
          @for (view of basicsFields; track view.field) {
            <div class="ocu-field">
              <label class="ocu-field-label" [class.ocu-field-label-required]="view.required" [attr.for]="view.id">{{ view.label }}</label>
              <div class="ocu-field-control">
                @if (view.options.length) {
                  <select
                    class="ocu-field-input"
                    [id]="view.id"
                    [attr.aria-required]="view.required"
                    [attr.aria-invalid]="view.invalid"
                    [attr.aria-describedby]="view.describedBy"
                    (change)="onText(view.field, $event)"
                  >
                    @for (option of view.options; track option.value) {
                      <option [value]="option.value" [selected]="option.value === view.value">{{ option.label }}</option>
                    }
                  </select>
                } @else {
                  <input
                    class="ocu-field-input"
                    type="text"
                    autocomplete="off"
                    [id]="view.id"
                    [value]="view.value"
                    [attr.aria-required]="view.required"
                    [attr.maxlength]="maxLength(view.field)"
                    [attr.aria-invalid]="view.invalid"
                    [attr.aria-describedby]="view.describedBy"
                    (input)="onText(view.field, $event)"
                    (blur)="onBlur(view.field)"
                  />
                }
              </div>
              @if (view.invalid) {
                <p class="ocu-form-error" [id]="view.id + '-reason'">{{ view.reason }}</p>
              }
            </div>
          }
        </div>
      </ng-template>

      <ng-template ocuFormStep="type">
        <div class="ocu-form-fields">
          <div class="ocu-field">
            <label class="ocu-field-label ocu-field-label-required" [attr.for]="typeField.id">{{ typeField.label }}</label>
            <div class="ocu-field-control">
              <select
                class="ocu-field-input"
                [id]="typeField.id"
                aria-required="true"
                [attr.aria-invalid]="typeField.invalid"
                [attr.aria-describedby]="typeField.describedBy"
                (change)="onText('TaskClass', $event)"
              >
                @for (option of typeField.options; track option.value) {
                  <option [value]="option.value" [selected]="option.value === typeField.value">{{ option.label }}</option>
                }
              </select>
            </div>
            @if (typeField.invalid) {
              <p class="ocu-form-error" [id]="typeField.id + '-reason'">{{ typeField.reason }}</p>
            }
          </div>
          @if (hasType) {
            @for (view of settingViews; track view.field) {
              <div class="ocu-field">
                @if (view.flag) {
                  <label class="ocu-field-checkbox">
                    <input
                      type="checkbox"
                      [id]="view.id"
                      [checked]="view.checked"
                      [attr.aria-invalid]="view.invalid"
                      [attr.aria-describedby]="view.describedBy"
                      (change)="onSettingFlag(view.field, $event)"
                    />
                    <span>{{ view.label }}</span>
                  </label>
                } @else {
                  <label class="ocu-field-label" [class.ocu-field-label-required]="view.required" [attr.for]="view.id">{{ view.label }}</label>
                  <div class="ocu-field-control">
                    @if (view.options.length) {
                      <select
                        class="ocu-field-input"
                        [id]="view.id"
                        [attr.aria-required]="view.required"
                        [attr.aria-invalid]="view.invalid"
                        [attr.aria-describedby]="view.describedBy"
                        (change)="onSetting(view.field, $event)"
                      >
                        @for (option of view.options; track option.value) {
                          <option [value]="option.value" [selected]="option.value === view.value">{{ option.label }}</option>
                        }
                      </select>
                    } @else {
                      <input
                        class="ocu-field-input"
                        [type]="view.kind === 'number' ? 'number' : 'text'"
                        autocomplete="off"
                        [id]="view.id"
                        [value]="view.value"
                        [attr.aria-required]="view.required"
                        [attr.aria-invalid]="view.invalid"
                        [attr.aria-describedby]="view.describedBy"
                        (input)="onSetting(view.field, $event)"
                      />
                    }
                  </div>
                }
                @if (view.invalid) {
                  <p class="ocu-form-error" [id]="view.id + '-reason'">{{ view.reason }}</p>
                }
              </div>
            }
            @if (hasNoSettings) {
              <p class="ocu-field-caption">{{ STRINGS.taskNoSettings }}</p>
            }
            @if (hasClassicOnly) {
              <p class="ocu-field-caption">{{ classicOnlyLine }}</p>
            }
          }
        </div>
      </ng-template>

      <ng-template ocuFormStep="schedule">
        <div class="ocu-form-fields">
          @for (view of scheduleFields; track view.field) {
            @if (view.shown) {
              @if (view.day) {
                @if (weekly) {
                  <fieldset class="ocu-field ocu-task-days" [attr.aria-describedby]="view.describedBy">
                    <legend class="ocu-field-label ocu-field-label-required">{{ STRINGS.taskRunDays }}</legend>
                    @for (day of dayViews; track day.digit) {
                      <label class="ocu-field-checkbox">
                        <input type="checkbox" [id]="day.id" [checked]="day.checked" (change)="onDay(day.digit, $event)" />
                        <span>{{ day.label }}</span>
                      </label>
                    }
                  </fieldset>
                }
                @if (monthly) {
                  <div class="ocu-field">
                    <label class="ocu-field-label ocu-field-label-required" [attr.for]="view.id">{{ STRINGS.taskDayOfMonth }}</label>
                    <div class="ocu-field-control">
                      <input
                        class="ocu-field-input"
                        type="number"
                        min="1"
                        max="31"
                        [id]="view.id"
                        [value]="view.value"
                        aria-required="true"
                        [attr.aria-invalid]="view.invalid"
                        [attr.aria-describedby]="dayCaptionDescribedBy"
                        (input)="onText('TimePeriodDay', $event)"
                      />
                    </div>
                    <p class="ocu-field-caption" [id]="view.id + '-caption'">{{ STRINGS.taskDayOfMonthCaption }}</p>
                  </div>
                }
                @if (monthlySpecial) {
                  <div class="ocu-field">
                    <label class="ocu-field-label ocu-field-label-required" [attr.for]="view.id">{{ STRINGS.taskWeekOfMonth }}</label>
                    <div class="ocu-field-control">
                      <select class="ocu-field-input" [id]="view.id" aria-required="true" [attr.aria-invalid]="view.invalid" [attr.aria-describedby]="view.describedBy" (change)="onWeek($event)">
                        @for (option of weekChoices; track option.value) {
                          <option [value]="option.value" [selected]="option.value === specialWeek">{{ option.label }}</option>
                        }
                      </select>
                    </div>
                  </div>
                  <div class="ocu-field">
                    <label class="ocu-field-label ocu-field-label-required" [attr.for]="weekdayId">{{ STRINGS.taskDayOfWeek }}</label>
                    <div class="ocu-field-control">
                      <select class="ocu-field-input" [id]="weekdayId" aria-required="true" [attr.aria-invalid]="view.invalid" [attr.aria-describedby]="view.describedBy" (change)="onWeekday($event)">
                        @for (option of weekdayChoices; track option.value) {
                          <option [value]="option.value" [selected]="option.value === specialWeekday">{{ option.label }}</option>
                        }
                      </select>
                    </div>
                  </div>
                }
                @if (view.invalid) {
                  <p class="ocu-form-error" [id]="view.id + '-reason'">{{ view.reason }}</p>
                }
              }
              @if (view.flag) {
                <div class="ocu-field">
                  <label class="ocu-field-checkbox">
                    <input type="checkbox" [id]="view.id" [checked]="view.checked" (change)="onFlag(view.field, $event)" />
                    <span>{{ view.label }}</span>
                  </label>
                </div>
              }
              @if (view.plain) {
                <div class="ocu-field">
                  <label class="ocu-field-label" [class.ocu-field-label-required]="view.required" [attr.for]="view.id">{{ view.label }}</label>
                  <div class="ocu-field-control">
                    @if (view.options.length) {
                      <select
                        class="ocu-field-input"
                        [id]="view.id"
                        [attr.aria-required]="view.required"
                        [attr.aria-invalid]="view.invalid"
                        [attr.aria-describedby]="view.describedBy"
                        (change)="onText(view.field, $event)"
                      >
                        @for (option of view.options; track option.value) {
                          <option [value]="option.value" [selected]="option.value === view.value">{{ option.label }}</option>
                        }
                      </select>
                    } @else {
                      <input
                        class="ocu-field-input"
                        [type]="inputType(view.field)"
                        autocomplete="off"
                        [id]="view.id"
                        [value]="view.value"
                        [attr.aria-required]="view.required"
                        [attr.aria-invalid]="view.invalid"
                        [attr.aria-describedby]="view.describedBy"
                        (input)="onText(view.field, $event)"
                      />
                    }
                  </div>
                  @if (view.invalid) {
                    <p class="ocu-form-error" [id]="view.id + '-reason'">{{ view.reason }}</p>
                  }
                </div>
              }
            }
          }
          <p class="ocu-field-caption" role="status">{{ scheduleSummary }}</p>
        </div>
      </ng-template>

      <ng-template ocuFormStep="options">
        <div class="ocu-form-fields">
          @for (view of optionFields; track view.field) {
            <div class="ocu-field">
              @if (view.flag) {
                <label class="ocu-field-checkbox">
                  <input type="checkbox" [id]="view.id" [checked]="view.checked" [attr.aria-describedby]="view.describedBy" (change)="onFlag(view.field, $event)" />
                  <span>{{ view.label }}</span>
                </label>
              } @else {
                <label class="ocu-field-label" [attr.for]="view.id">{{ view.label }}</label>
                <div class="ocu-field-control">
                  @if (view.options.length) {
                    <select class="ocu-field-input" [id]="view.id" [attr.aria-invalid]="view.invalid" [attr.aria-describedby]="view.describedBy" (change)="onText(view.field, $event)">
                      @for (option of view.options; track option.value) {
                        <option [value]="option.value" [selected]="option.value === view.value">{{ option.label }}</option>
                      }
                    </select>
                  } @else {
                    <input
                      class="ocu-field-input"
                      type="text"
                      autocomplete="off"
                      [id]="view.id"
                      [value]="view.value"
                      [attr.maxlength]="maxLength(view.field)"
                      [attr.aria-invalid]="view.invalid"
                      [attr.aria-describedby]="view.describedBy"
                      (input)="onText(view.field, $event)"
                      (blur)="onBlur(view.field)"
                    />
                  }
                </div>
              }
              @if (view.caption) {
                <p class="ocu-field-caption" [id]="view.id + '-caption'">{{ view.caption }}</p>
              }
              @if (view.field === 'RunAsUser') {
                @if (runsAsOther) {
                  <p class="ocu-field-caption ocu-field-effect" [id]="view.id + '-effect'">{{ STRINGS.taskRunAsOtherEffect }}</p>
                }
              }
              @if (view.invalid) {
                <p class="ocu-form-error" [id]="view.id + '-reason'">{{ view.reason }}</p>
              }
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
  private readonly scope = inject(ScopeService);
  private readonly session = inject(Session);
  private readonly router = inject(Router);
  private readonly injector = inject(Injector);

  protected readonly STRINGS = STRINGS;

  protected readonly weekdayId = 'ocu-task-TimePeriodDay-weekday';

  protected readonly weekChoices: readonly Choice[] = WEEKS.map((label, index) => ({ value: String(index + 1), label }));

  protected readonly weekdayChoices: readonly Choice[] = WEEKDAYS.map((label, index) => ({ value: String(index + 1), label }));

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

  protected get basicsFields(): readonly FieldView[] {
    this.generation();
    const namespaces = this.scope.namespaces().map((entry) => ({ value: entry.name, label: entry.name }));
    const held = this.store.text('NameSpace');
    const options = namespaces.some((option) => option.value === held) || held === '' ? namespaces : [{ value: held, label: held }, ...namespaces];
    return [
      this.view('Name', STRINGS.tableColumnName),
      this.view('Description', STRINGS.tableColumnDescription),
      this.view('NameSpace', STRINGS.headerNamespaceLabel, options),
    ];
  }

  protected get typeField(): FieldView {
    this.generation();
    const options: Choice[] = [{ value: '', label: STRINGS.taskChooseType }];
    for (const type of this.store.types()) options.push({ value: type.className, label: `${type.name} (${type.className})` });
    return this.view('TaskClass', STRINGS.taskFieldTaskClass, options);
  }

  protected get hasType(): boolean {
    this.generation();
    return this.store.type() !== null;
  }

  protected get settingViews(): readonly SettingView[] {
    this.generation();
    const type = this.store.type();
    if (type === null) return [];
    return type.settings.map((setting) => this.settingView(setting));
  }

  protected get hasNoSettings(): boolean {
    this.generation();
    const type = this.store.type();
    return type !== null && type.settings.length === 0 && type.classicOnly.length === 0;
  }

  protected get hasClassicOnly(): boolean {
    this.generation();
    return (this.store.type()?.classicOnly.length ?? 0) > 0;
  }

  protected get classicOnlyLine(): string {
    this.generation();
    return STRINGS.taskSettingClassicOnly.split(SETTINGS_PLACEHOLDER).join((this.store.type()?.classicOnly ?? []).join(', '));
  }

  protected get weekly(): boolean {
    this.generation();
    return this.store.text('TimePeriod') === PERIODS[1];
  }

  protected get monthly(): boolean {
    this.generation();
    return this.store.text('TimePeriod') === PERIODS[2];
  }

  protected get monthlySpecial(): boolean {
    this.generation();
    return this.store.text('TimePeriod') === PERIODS[3];
  }

  protected get specialWeek(): string {
    this.generation();
    return this.store.text('TimePeriodDay').split('^')[0] ?? '1';
  }

  protected get specialWeekday(): string {
    this.generation();
    return this.store.text('TimePeriodDay').split('^')[1] ?? '1';
  }

  protected get dayViews(): readonly DayView[] {
    this.generation();
    const held = this.store.text('TimePeriodDay');
    return WEEKDAYS.map((label, index) => {
      const digit = String(index + 1);
      return { digit, id: index === 0 ? this.controlId('TimePeriodDay') : `${this.controlId('TimePeriodDay')}-${digit}`, label, checked: held.includes(digit) };
    });
  }

  protected get dayCaptionDescribedBy(): string {
    const id = this.controlId('TimePeriodDay');
    return this.store.violationFor('TimePeriodDay') !== '' ? `${id}-caption ${id}-reason` : `${id}-caption`;
  }

  protected get scheduleFields(): readonly FieldView[] {
    this.generation();
    const period = this.store.text('TimePeriod');
    const everyLabel = period === PERIODS[1] ? STRINGS.taskEveryWeeks : period === PERIODS[0] ? STRINGS.taskEveryDays : STRINGS.taskEveryMonths;
    const runAfter: Choice[] = [{ value: '', label: STRINGS.tableEmptyValue }];
    for (const task of this.store.runAfter()) runAfter.push({ value: task.guid, label: `${task.name} (${task.id})` });
    return [
      this.view('TimePeriod', STRINGS.taskDetailsHowOften, choices(PERIODS, PERIOD_LABELS)),
      this.view('TimePeriodEvery', everyLabel),
      this.view('TimePeriodDay', STRINGS.taskRunDays),
      this.view('RunAfterGUID', STRINGS.taskRunAfterField, runAfter),
      this.view('DailyFrequency', STRINGS.taskRunsPerDay, choices(FREQUENCIES, [STRINGS.taskFrequencyOnce, STRINGS.taskFrequencySeveral])),
      this.view('DailyFrequencyTime', STRINGS.taskIntervalUnit, choices(['', ...FREQUENCY_TIMES], [STRINGS.tableEmptyValue, STRINGS.taskUnitMinutes, STRINGS.taskUnitHours])),
      this.view('DailyIncrement', STRINGS.taskInterval),
      this.view('DailyStartTime', STRINGS.taskStartTime),
      this.view('DailyEndTime', STRINGS.taskEndTime),
      this.view('StartDate', STRINGS.taskStartDate),
      this.view('EndDate', STRINGS.taskEndDate),
      this.view('Expires', STRINGS.taskExpires),
      this.view('ExpiresDays', STRINGS.taskUnitDays),
      this.view('ExpiresHours', STRINGS.taskUnitHours),
      this.view('ExpiresMinutes', STRINGS.taskUnitMinutes),
    ];
  }

  /** The schedule as the details page words it, from the values so far. */
  protected get scheduleSummary(): string {
    this.generation();
    const words = scheduleWords(this.store.values().text);
    return applies('DailyFrequency', this.store.values()) ? `${words.often} \u00b7 ${words.time}` : words.often;
  }

  protected get optionFields(): readonly FieldView[] {
    this.generation();
    return [
      this.view('RunAsUser', STRINGS.taskDetailsRunAs),
      this.view('Priority', STRINGS.taskDetailsPriority, choices(PRIORITIES, [STRINGS.taskPriorityNormal, STRINGS.taskPriorityLow, STRINGS.taskPriorityHigh])),
      this.view('IsBatch', STRINGS.taskIsBatch),
      this.view('MirrorStatus', STRINGS.taskMirrorStatus, choices(MIRROR_STATUSES, [STRINGS.taskMirrorPrimary, STRINGS.taskMirrorNonPrimary, STRINGS.auditCriteriaAnyOption])),
      this.view('OpenOutputFile', STRINGS.taskOpenOutputFile),
      this.view('OutputFilename', STRINGS.taskOutputFilename),
      this.view('OutputFileIsBinary', STRINGS.taskOutputFileIsBinary),
      this.view('EmailOutput', STRINGS.taskEmailOutput),
      this.view('SuspendOnError', STRINGS.taskSuspendOnError),
      this.view('SuspendTerminated', STRINGS.taskSuspendTerminated),
      this.view('RescheduleOnStart', STRINGS.taskRescheduleOnStart),
      this.view('EmailOnCompletion', STRINGS.taskEmailOnCompletion),
      this.view('EmailOnError', STRINGS.taskEmailOnError),
      this.view('EmailOnExpiration', STRINGS.taskEmailOnExpiration),
    ];
  }

  protected get runsAsOther(): boolean {
    this.generation();
    return this.store.runsAsOther(this.session.userName());
  }

  /** The caption under an options field, or `''`. */
  private captionOf(field: string): string {
    if (field === 'RunAsUser') return STRINGS.taskRunAsCaption;
    if (field === 'OutputFilename') return STRINGS.taskOutputFileCaption;
    if (field === 'EmailOnCompletion') return STRINGS.taskEmailCaption;
    return '';
  }

  /** The input type a schedule field takes. */
  protected inputType(field: string): string {
    if (field === 'DailyStartTime' || field === 'DailyEndTime') return 'time';
    if (field === 'StartDate' || field === 'EndDate') return 'date';
    return 'number';
  }

  /** The length the instance stores for `field`, or `null` where it declares none. */
  protected maxLength(field: string): number | null {
    this.generation();
    const bound = this.store.maxLength(field);
    return bound > 0 ? bound : null;
  }

  // --- intents ---------------------------------------------------------------------------------

  protected goTo(step: string): void {
    this.store.goTo(step);
  }

  protected onText(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement || target instanceof HTMLSelectElement) this.store.setText(field, target.value);
  }

  protected onFlag(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setFlag(field, target.checked);
  }

  protected onSetting(name: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement || target instanceof HTMLSelectElement) this.store.setSetting(name, target.value);
  }

  protected onSettingFlag(name: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setSetting(name, target.checked ? '1' : '0');
  }

  protected onDay(digit: string, event: Event): void {
    const target = event.target;
    if (!(target instanceof HTMLInputElement)) return;
    const held = new Set(this.store.text('TimePeriodDay').split('').filter((entry) => /[1-7]/.test(entry)));
    if (target.checked) held.add(digit);
    else held.delete(digit);
    this.store.setText('TimePeriodDay', [...held].sort().join(''));
  }

  protected onWeek(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLSelectElement) this.store.setText('TimePeriodDay', `${target.value}^${this.specialWeekday}`);
  }

  protected onWeekday(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLSelectElement) this.store.setText('TimePeriodDay', `${this.specialWeek}^${target.value}`);
  }

  protected onBlur(field: string): void {
    this.store.onBlur(field);
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
    document.getElementById(this.controlId(field))?.focus();
  }

  private view(field: string, label: string, options: readonly Choice[] = []): FieldView {
    const id = this.controlId(field);
    const reason = this.store.violationFor(field);
    const invalid = reason !== '';
    const described = [
      this.captionOf(field) !== '' ? `${id}-caption` : '',
      field === 'RunAsUser' && this.store.runsAsOther(this.session.userName()) ? `${id}-effect` : '',
      invalid ? `${id}-reason` : '',
    ].filter((entry) => entry !== '');
    const value = this.store.text(field);
    return {
      field,
      id,
      label,
      value,
      checked: this.store.flag(field),
      options: options.length === 0 || options.some((option) => option.value === value) ? options : [{ value, label: value }, ...options],
      required: this.store.required(field),
      reason,
      invalid,
      describedBy: described.length === 0 ? null : described.join(' '),
      shown: applies(field, this.store.values()),
      flag: FLAG_FIELDS.includes(field),
      day: field === 'TimePeriodDay',
      plain: !FLAG_FIELDS.includes(field) && field !== 'TimePeriodDay',
      caption: this.captionOf(field),
    };
  }

  private settingView(setting: TaskSetting): SettingView {
    const field = `${SETTING_PREFIX}${setting.name}`;
    const id = this.controlId(field);
    const reason = this.store.violationFor(field);
    const invalid = reason !== '';
    const value = this.store.setting(setting.name);
    const options: Choice[] = setting.options.map((option) => ({ value: option.value, label: option.label }));
    return {
      field: setting.name,
      id,
      label: setting.label,
      value,
      checked: value === '1' || value === 'true',
      // A held value no option names -- a type's empty default -- is drawn as its own first option,
      // as `view` does, so the select shows what will be sent.
      options: options.length === 0 || options.some((option) => option.value === value) ? options : [{ value, label: value }, ...options],
      required: setting.required,
      reason,
      invalid,
      describedBy: invalid ? `${id}-reason` : null,
      shown: true,
      flag: setting.kind === 'boolean',
      day: false,
      plain: setting.kind !== 'boolean',
      caption: '',
      kind: setting.kind,
    };
  }

  private controlId(field: string): string {
    return `ocu-task-${field.replace('.', '-')}`;
  }

  /** The new task's details URL. The id is `encodeEntityId`'s, never `encodeURIComponent`'s (AD-13). */
  private detailsUrl(id: string): string {
    const list = screenForRoute(TASK_LIST_ROUTE);
    const details = list === null ? null : detailScreenFor(list);
    const route = details === null ? `${TASK_LIST_ROUTE}/details` : details.route;
    return withQuery(`${route}/${encodeEntityId(id)}`, this.router.url);
  }
}

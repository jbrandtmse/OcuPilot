import { ChangeDetectionStrategy, Component, DestroyRef, inject, input, signal } from '@angular/core';

import { FormDirty } from '../../core/form-dirty';
import { ScopeService } from '../../core/scope';
import { Session } from '../../core/session';
import { STRINGS } from '../../core/strings';
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
} from './task-fields';
import { type TaskSetting, TaskWizard } from './task-wizard.store';

/** The placeholder the classic-only sentence leaves for the settings' names. */
const SETTINGS_PLACEHOLDER = '<settings>';

/** The id a task field's control carries, on the wizard's steps and on Edit task's tabs alike. */
export function taskControlId(field: string): string {
  return `ocu-task-${field.replace('.', '-')}`;
}

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
  /** Drawn read-only: a task's type and namespace on Edit task. */
  readonly fixed: boolean;
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
 * One step's fields of a scheduled task (Stories 9.7 and 9.8): the one field template the New Task
 * wizard's stepper and Edit task's tabs both render, over `task-fields.ts`'s model and the
 * `TaskWizard` store, so no field template exists twice.
 *
 * **`step` picks the group**: Basics, Task type and settings, Schedule, or Options and
 * notifications. The Schedule group draws only what the chosen period and frequency read, and Run
 * as another account states its effect under the field (AD-10).
 *
 * **On Edit task** a task's type and namespace are drawn read-only with the published reason, and a
 * type holding a classic-only setting draws no setting at all, only the sentence naming them
 * (AD-35).
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-task-field-group',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `@if (isBasics) {
        <div class="ocu-form-fields">
          @for (view of basicsFields; track view.field) {
            <div class="ocu-field">
              <label class="ocu-field-label" [class.ocu-field-label-required]="view.required" [attr.for]="view.id">{{ view.label }}</label>
              <div class="ocu-field-control">
                @if (view.fixed) {
                  <input
                    class="ocu-field-input"
                    type="text"
                    readonly
                    [id]="view.id"
                    [value]="view.value"
                    [attr.aria-describedby]="view.describedBy"
                  />
                } @else {
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
                }
              </div>
              @if (view.caption) {
                <p class="ocu-field-caption" [id]="view.id + '-caption'">{{ view.caption }}</p>
              }
              @if (view.invalid) {
                <p class="ocu-form-error" [id]="view.id + '-reason'">{{ view.reason }}</p>
              }
            </div>
          }
        </div>
    }
    @if (isType) {
        <div class="ocu-form-fields">
          <div class="ocu-field">
            <label class="ocu-field-label" [class.ocu-field-label-required]="typeField.required" [attr.for]="typeField.id">{{ typeField.label }}</label>
            <div class="ocu-field-control">
              @if (typeField.fixed) {
                <input
                  class="ocu-field-input"
                  type="text"
                  readonly
                  [id]="typeField.id"
                  [value]="typeFixedValue"
                  [attr.aria-describedby]="typeField.describedBy"
                />
              } @else {
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
              }
            </div>
            @if (typeField.caption) {
              <p class="ocu-field-caption" [id]="typeField.id + '-caption'">{{ typeField.caption }}</p>
            }
            @if (typeField.invalid) {
              <p class="ocu-form-error" [id]="typeField.id + '-reason'">{{ typeField.reason }}</p>
            }
          </div>
          @if (drawsSettings) {
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
          }
          @if (hasClassicOnly) {
            <p class="ocu-field-caption">{{ classicOnlyLine }}</p>
          }
        </div>
    }
    @if (isSchedule) {
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
    }
    @if (isOptions) {
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
    }`,
})
export class TaskFieldGroup {
  private readonly store = inject(TaskWizard);
  private readonly formDirty = inject(FormDirty);
  private readonly scope = inject(ScopeService);
  private readonly session = inject(Session);

  /** The step key of the group drawn. */
  readonly step = input.required<string>();

  protected readonly STRINGS = STRINGS;

  protected readonly weekdayId = `${taskControlId('TimePeriodDay')}-weekday`;

  protected readonly weekChoices: readonly Choice[] = WEEKS.map((label, index) => ({ value: String(index + 1), label }));

  protected readonly weekdayChoices: readonly Choice[] = WEEKDAYS.map((label, index) => ({ value: String(index + 1), label }));

  /** Bumped by the stores, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  constructor() {
    const stopStore = this.store.subscribe(() => this.bump());
    const stopDirty = this.formDirty.subscribe(() => this.bump());
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopDirty();
    });
  }

  // --- reads -----------------------------------------------------------------------------------

  protected get isBasics(): boolean {
    return this.step() === BASICS_STEP;
  }

  protected get isType(): boolean {
    return this.step() === TYPE_STEP;
  }

  protected get isSchedule(): boolean {
    return this.step() === SCHEDULE_STEP;
  }

  protected get isOptions(): boolean {
    return this.step() === OPTIONS_STEP;
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

  /** A fixed type as the read-only field shows it: its name and class, or its class alone. */
  protected get typeFixedValue(): string {
    this.generation();
    const type = this.store.type();
    const className = this.store.text('TaskClass');
    return type === null ? className : `${type.name} (${type.className})`;
  }

  protected get hasType(): boolean {
    this.generation();
    return this.store.type() !== null;
  }

  /** Whether the chosen type's settings are drawn: a type is known and none is classic-only on an edit. */
  protected get drawsSettings(): boolean {
    this.generation();
    return this.store.type() !== null && !this.store.settingsClassicOnly();
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
    return (this.store.type()?.classicOnly.length ?? 0) > 0 || this.store.settingsClassicOnly();
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
      return { digit, id: index === 0 ? taskControlId('TimePeriodDay') : `${taskControlId('TimePeriodDay')}-${digit}`, label, checked: held.includes(digit) };
    });
  }

  protected get dayCaptionDescribedBy(): string {
    const id = taskControlId('TimePeriodDay');
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

  /** The caption under a field, or `''`. */
  private captionOf(field: string): string {
    if (this.store.fixed(field)) return STRINGS.taskEditFixed;
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

  // --- internals -------------------------------------------------------------------------------

  private bump(): void {
    this.generation.update((value) => value + 1);
  }

  private view(field: string, label: string, options: readonly Choice[] = []): FieldView {
    const id = taskControlId(field);
    const reason = this.store.violationFor(field);
    const invalid = reason !== '';
    const caption = this.captionOf(field);
    const fixed = this.store.fixed(field);
    const described = [
      caption !== '' ? `${id}-caption` : '',
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
      required: this.store.required(field) && !fixed,
      reason,
      invalid,
      describedBy: described.length === 0 ? null : described.join(' '),
      shown: applies(field, this.store.values()),
      flag: FLAG_FIELDS.includes(field),
      day: field === 'TimePeriodDay',
      plain: !FLAG_FIELDS.includes(field) && field !== 'TimePeriodDay',
      fixed,
      caption,
    };
  }

  private settingView(setting: TaskSetting): SettingView {
    const field = `${SETTING_PREFIX}${setting.name}`;
    const id = taskControlId(field);
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
      fixed: false,
      caption: '',
      kind: setting.kind,
    };
  }
}

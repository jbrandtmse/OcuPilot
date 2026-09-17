/**
 * Task details' own state (AD-19): the schedule-in-words vocabulary, composed on the client from
 * GET's own display values rather than taken from the vendor's `%SYS.Task` `DisplayRunCalc` /
 * `DisplayIntervalCalc` (Design Notes), and the field-level change highlight a silent auto-refresh
 * tick raises.
 *
 * Framework-free, like the rest of `core/` and `areas/tasks/history.store.ts`, so
 * `ui/tools/details-store.test.mjs` executes the vocabulary under `node --test` without an Angular
 * test bed. `details.page.ts` holds one `TaskDetailsHighlights` per page instance.
 */

import { fieldOf } from '../../core/table-model.ts';
import { textOf } from '../../core/screen-read.ts';
import { STRINGS } from '../../core/strings.ts';

/** One row's How-often and Time-of-day lines. */
export interface ScheduleWords {
  readonly often: string;
  readonly time: string;
}

/** Sunday through Saturday, in the order a Weekly `TimePeriodDay` digit 1-7 names them. */
const WEEKDAY_NAMES: readonly string[] = [
  STRINGS.weekdaySunday,
  STRINGS.weekdayMonday,
  STRINGS.weekdayTuesday,
  STRINGS.weekdayWednesday,
  STRINGS.weekdayThursday,
  STRINGS.weekdayFriday,
  STRINGS.weekdaySaturday,
];

/** First through fifth, in the order a Monthly Special `TimePeriodDay` week digit 1-5 names them. */
const ORDINAL_NAMES: readonly string[] = [
  STRINGS.ordinalFirst,
  STRINGS.ordinalSecond,
  STRINGS.ordinalThird,
  STRINGS.ordinalFourth,
  STRINGS.ordinalFifth,
];

/** `template` with each `{key}` span replaced by its value. */
function format(template: string, values: Readonly<Record<string, string>>): string {
  let text = template;
  for (const key of Object.keys(values)) {
    text = text.split(`{${key}}`).join(values[key]);
  }
  return text;
}

/** `row`'s `field` as the view rule's text (`''` for an absent or empty value). */
function textField(row: unknown, field: string): string {
  return textOf(fieldOf(row, field));
}

/** `row`'s `field` as a number, `0` for anything that is not one. */
function numberField(row: unknown, field: string): number {
  const value = Number(textField(row, field));
  return Number.isFinite(value) ? value : 0;
}

/** `digit` (`'1'`-`'7'`) as its weekday name, or `digit` itself when it names none. */
function weekdayName(digit: string): string {
  const index = Number(digit) - 1;
  return index >= 0 && index < WEEKDAY_NAMES.length ? WEEKDAY_NAMES[index] : digit;
}

/** `digit` (`'1'`-`'5'`) as its ordinal name, or `digit` itself when it names none. */
function ordinalName(digit: string): string {
  const index = Number(digit) - 1;
  return index >= 0 && index < ORDINAL_NAMES.length ? ORDINAL_NAMES[index] : digit;
}

/** A Weekly `TimePeriodDay`'s digits, each resolved to its weekday name, joined by `, `. */
function weekdayListText(days: string): string {
  return [...days].map(weekdayName).join(', ');
}

/** A Monthly Special `TimePeriodDay` (`<week>^<weekday>`), resolved to its two names. */
function monthlySpecialParts(value: string): { readonly ordinal: string; readonly weekday: string } {
  const [week, weekday] = value.split('^');
  return { ordinal: ordinalName(week ?? ''), weekday: weekdayName(weekday ?? '') };
}

/**
 * The How-often line: `TimePeriod`'s vocabulary (AD-3) resolved against `TimePeriodEvery` and
 * `TimePeriodDay`. An unrecognized `TimePeriod` renders the vendor's own text as it stands.
 */
function oftenText(row: unknown): string {
  const timePeriod = textField(row, 'TimePeriod');
  const every = numberField(row, 'TimePeriodEvery');
  switch (timePeriod) {
    case 'Daily':
      return every > 1 ? format(STRINGS.taskScheduleEveryNDays, { n: String(every) }) : STRINGS.taskScheduleEveryDay;
    case 'Weekly': {
      const days = weekdayListText(textField(row, 'TimePeriodDay'));
      const template = every > 1 ? STRINGS.taskScheduleWeeklyEveryN : STRINGS.taskScheduleWeekly;
      return format(template, { n: String(every), days });
    }
    case 'Monthly': {
      const day = textField(row, 'TimePeriodDay');
      const template = every > 1 ? STRINGS.taskScheduleMonthlyDayEveryN : STRINGS.taskScheduleMonthlyDay;
      return format(template, { n: String(every), d: day });
    }
    case 'Monthly Special': {
      const { ordinal, weekday } = monthlySpecialParts(textField(row, 'TimePeriodDay'));
      const template = every > 1 ? STRINGS.taskScheduleMonthlySpecialEveryN : STRINGS.taskScheduleMonthlySpecial;
      return format(template, { n: String(every), ordinal, weekday });
    }
    case 'Run After':
      return STRINGS.taskScheduleRunAfter;
    case 'On Demand':
      return STRINGS.taskScheduleOnDemand;
    default:
      return timePeriod;
  }
}

/**
 * The Time-of-day line: `DailyFrequency`'s vocabulary (AD-3) resolved against
 * `DailyFrequencyTime`, `DailyIncrement`, `DailyStartTime` and `DailyEndTime`. An unrecognized
 * `DailyFrequency` or `DailyFrequencyTime` renders the vendor's own text as it stands.
 */
function timeText(row: unknown): string {
  const frequency = textField(row, 'DailyFrequency');
  if (frequency === 'Once') {
    return format(STRINGS.taskScheduleOnceAt, { time: textField(row, 'DailyStartTime') });
  }
  if (frequency !== 'Several') return frequency;
  const kind = textField(row, 'DailyFrequencyTime');
  const every = numberField(row, 'DailyIncrement');
  const start = textField(row, 'DailyStartTime');
  const end = textField(row, 'DailyEndTime');
  if (kind === 'Minutes') {
    const template = every > 1 ? STRINGS.taskScheduleEveryNMinutes : STRINGS.taskScheduleEveryMinute;
    return format(template, { n: String(every), start, end });
  }
  if (kind === 'Hourly') {
    const template = every > 1 ? STRINGS.taskScheduleEveryNHours : STRINGS.taskScheduleEveryHour;
    return format(template, { n: String(every), start, end });
  }
  return kind;
}

/** `row`'s Schedule group, both lines. */
export function scheduleWords(row: unknown): ScheduleWords {
  return { often: oftenText(row), time: timeText(row) };
}

/**
 * The Next run cell's text: "Not scheduled while suspended" while the task is suspended, because
 * `NextScheduled` is then a stale past time the vendor never clears (inference); otherwise the raw
 * `NextScheduled` value.
 */
export function nextRunText(row: unknown): string {
  const suspended = fieldOf(row, 'Suspended');
  if (suspended === true) return STRINGS.taskDetailsNextSuspended;
  const text = textField(row, 'NextScheduled');
  // A Run After or On Demand task carries no next-run time even while it is not suspended, and
  // this field is read directly rather than through `cellView` (details.page.ts's `fieldViews`),
  // so it must apply `cellView`'s own empty-value fallback itself.
  return text === '' ? STRINGS.tableEmptyValue : text;
}

/**
 * Which of `fields` differ, as text, between `previous` and `current`. Held by
 * `TaskDetailsHighlights` rather than called bare, so a page can tell "first load" (nothing to
 * compare against) from "nothing changed" (compared and equal).
 */
function changedFields(previous: unknown, current: unknown, fields: readonly string[]): ReadonlySet<string> {
  const changed = new Set<string>();
  for (const field of fields) {
    if (textOf(fieldOf(previous, field)) !== textOf(fieldOf(current, field))) changed.add(field);
  }
  return changed;
}

/**
 * The field-level highlight a silent auto-refresh tick raises (EXPERIENCE.md "Highlight."),
 * applied to Task details' field list rather than to a table row. A highlight holds across ticks
 * that change nothing and is replaced by the next tick that changes a field; `reset()` clears it.
 */
export class TaskDetailsHighlights {
  private previousRow: unknown = null;

  private highlightedFields: ReadonlySet<string> = new Set();

  /**
   * Compare `row` with the last one, over `fields`. The first call after `reset()` (or ever)
   * highlights nothing -- there is no earlier value to have changed from, which is what keeps a
   * first load or a fresh id from reading as every field having just changed. A call that finds
   * no change keeps the fields already highlighted.
   */
  update(row: unknown, fields: readonly string[]): void {
    if (this.previousRow !== null) {
      const changed = changedFields(this.previousRow, row, fields);
      if (changed.size > 0) this.highlightedFields = changed;
    }
    this.previousRow = row;
  }

  /** The fields the last change-bearing `update` found changed. */
  changed(): ReadonlySet<string> {
    return this.highlightedFields;
  }

  /** Forget the last row, so the next `update` highlights nothing -- a new task is not a change. */
  reset(): void {
    this.previousRow = null;
    this.highlightedFields = new Set();
  }
}

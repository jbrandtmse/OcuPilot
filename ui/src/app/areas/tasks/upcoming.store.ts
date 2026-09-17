/**
 * The Upcoming tasks horizon (AD-19): whether the screen reads a number of hours ahead or up to a
 * date, which of the six hour choices is chosen, and which date.
 *
 * **Framework-free and provided by the page.** It imports nothing from Angular, so it runs under
 * `node --test`, and the page holds it for its own life.
 *
 * **It answers the read's criteria, never both.** The vendor answers 24 hours when neither is sent
 * and honours the hours when both are, so `criteria` sends exactly one: `hoursOffset` in hours
 * mode, and `toDatetime` at the end of the chosen day in date mode. A date mode with no date, a date
 * that is not `YYYY-MM-DD`, or a date before today answers `null`, which the page reads as "read
 * nothing".
 */

import type { ScreenReadCriteria } from '../../core/screen-read';

/** The hour choices, in the order the control lists them: the descriptor's `hoursOffset` options. */
export const UPCOMING_HOURS: readonly string[] = ['1', '4', '12', '24', '72', '168'];

/** The hour choice the screen opens at. */
export const UPCOMING_DEFAULT_HOURS = '24';

/** The criterion the hours travel as. */
export const HOURS_CRITERION = 'hoursOffset';

/** The criterion the date travels as. */
export const DATE_CRITERION = 'toDatetime';

/** The time a chosen date is read up to: the end of that day. */
export const END_OF_DAY = '23:59:59';

/** Whether the horizon counts hours or runs to a date. */
export type HorizonMode = 'hours' | 'date';

const DATE_FORM = /^\d{4}-\d{2}-\d{2}$/;

/** `now`'s local calendar date as `YYYY-MM-DD`, the form a date input's value takes. */
export function localDateText(now: Date): string {
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const day = String(now.getDate()).padStart(2, '0');
  return `${now.getFullYear()}-${month}-${day}`;
}

export class UpcomingHorizon {
  private modeValue: HorizonMode = 'hours';

  private hoursValue = UPCOMING_DEFAULT_HOURS;

  private dateValue = '';

  private readonly listeners = new Set<() => void>();

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  mode(): HorizonMode {
    return this.modeValue;
  }

  hours(): string {
    return this.hoursValue;
  }

  date(): string {
    return this.dateValue;
  }

  /** Count `hours` ahead. A value outside `UPCOMING_HOURS` changes nothing. */
  chooseHours(hours: string): void {
    if (!UPCOMING_HOURS.includes(hours)) return;
    this.modeValue = 'hours';
    this.hoursValue = hours;
    this.notify();
  }

  /** Run to a date, keeping whatever date was last chosen. */
  chooseDateMode(): void {
    this.modeValue = 'date';
    this.notify();
  }

  /** Run to `date`, a `YYYY-MM-DD` value or `''`. */
  chooseDate(date: string): void {
    this.modeValue = 'date';
    this.dateValue = date;
    this.notify();
  }

  /**
   * The read's criteria for the horizon as it stands, with `today` the local date as
   * `YYYY-MM-DD`, or `null` when the horizon names nothing to read.
   */
  criteria(today: string): ScreenReadCriteria | null {
    if (this.modeValue === 'hours') return { [HOURS_CRITERION]: this.hoursValue };
    if (!DATE_FORM.test(this.dateValue) || this.dateValue < today) return null;
    return { [DATE_CRITERION]: `${this.dateValue} ${END_OF_DAY}` };
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

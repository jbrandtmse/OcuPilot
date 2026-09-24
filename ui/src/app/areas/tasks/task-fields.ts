/**
 * The scheduled task's field model (Story 9.7, FR-52): the fields a create sets, in the wizard's
 * order; which step each is drawn on; which the chosen period and frequency read; and the body a
 * create sends. Story 9.8's Edit task reads the same model, the step map as its tab map.
 *
 * **The vocabulary is `%SYS.TaskSuper`'s** (AD-3): `TimePeriod` fixes how `TimePeriodEvery` and
 * `TimePeriodDay` are read, and `DailyFrequency` governs the quadruple `DailyFrequencyTime`,
 * `DailyIncrement`, `DailyStartTime` and `DailyEndTime`. Every rule is the server's
 * (`OcuPilot.Area.Task.TaskRules`); this file decides nothing about validity.
 *
 * Framework-free, like `core/` (AD-19), so `ui/tools/task-fields.test.mjs` drives it under
 * `node --test`.
 */

/** The four steps, in order. */
export const BASICS_STEP = 'basics';
export const TYPE_STEP = 'type';
export const SCHEDULE_STEP = 'schedule';
export const OPTIONS_STEP = 'options';

export const STEPS: readonly string[] = [BASICS_STEP, TYPE_STEP, SCHEDULE_STEP, OPTIONS_STEP];

/** The field the chosen type's own settings travel under, and the prefix a setting's refusal carries. */
export const SETTINGS_FIELD = 'Settings';
export const SETTING_PREFIX = 'Settings.';

/** `TimePeriod`'s values, logical 0 to 5 in order. */
export const PERIODS: readonly string[] = ['Daily', 'Weekly', 'Monthly', 'Monthly Special', 'Run After', 'On Demand'];
export const FREQUENCIES: readonly string[] = ['Once', 'Several'];
export const FREQUENCY_TIMES: readonly string[] = ['Minutes', 'Hourly'];
export const PRIORITIES: readonly string[] = ['Normal', 'Low', 'High'];
export const MIRROR_STATUSES: readonly string[] = ['Primary', 'Non-Primary', 'Any'];

/** The boolean fields. */
export const FLAG_FIELDS: readonly string[] = [
  'Expires',
  'IsBatch',
  'OpenOutputFile',
  'OutputFileIsBinary',
  'EmailOutput',
  'SuspendOnError',
  'SuspendTerminated',
  'RescheduleOnStart',
];

/** The address-list fields, each held as comma-separated text and sent as an array. */
export const EMAIL_FIELDS: readonly string[] = ['EmailOnCompletion', 'EmailOnError', 'EmailOnExpiration'];

/** The fields read only for periods 0 to 3 (Daily to Monthly Special). */
export const SCHEDULED_FIELDS: readonly string[] = [
  'DailyFrequency',
  'DailyFrequencyTime',
  'DailyIncrement',
  'DailyStartTime',
  'DailyEndTime',
  'StartDate',
  'EndDate',
  'Expires',
  'ExpiresDays',
  'ExpiresHours',
  'ExpiresMinutes',
];

/** The fields read only when `DailyFrequency` is Several. */
export const SEVERAL_FIELDS: readonly string[] = ['DailyFrequencyTime', 'DailyIncrement', 'DailyEndTime'];

/** Every field a create sets, in the wizard's order, which is also the order a refusal's step is chosen by. */
export const FIELD_ORDER: readonly string[] = [
  'Name',
  'Description',
  'NameSpace',
  'TaskClass',
  SETTINGS_FIELD,
  'TimePeriod',
  'TimePeriodEvery',
  'TimePeriodDay',
  'RunAfterGUID',
  'DailyFrequency',
  'DailyFrequencyTime',
  'DailyIncrement',
  'DailyStartTime',
  'DailyEndTime',
  'StartDate',
  'EndDate',
  'Expires',
  'ExpiresDays',
  'ExpiresHours',
  'ExpiresMinutes',
  'RunAsUser',
  'Priority',
  'IsBatch',
  'MirrorStatus',
  'OpenOutputFile',
  'OutputFilename',
  'OutputFileIsBinary',
  'EmailOutput',
  'SuspendOnError',
  'SuspendTerminated',
  'RescheduleOnStart',
  'EmailOnCompletion',
  'EmailOnError',
  'EmailOnExpiration',
];

const STEP_OF: Readonly<Record<string, string>> = {
  Name: BASICS_STEP,
  Description: BASICS_STEP,
  NameSpace: BASICS_STEP,
  TaskClass: TYPE_STEP,
  [SETTINGS_FIELD]: TYPE_STEP,
  TimePeriod: SCHEDULE_STEP,
  TimePeriodEvery: SCHEDULE_STEP,
  TimePeriodDay: SCHEDULE_STEP,
  RunAfterGUID: SCHEDULE_STEP,
  DailyFrequency: SCHEDULE_STEP,
  DailyFrequencyTime: SCHEDULE_STEP,
  DailyIncrement: SCHEDULE_STEP,
  DailyStartTime: SCHEDULE_STEP,
  DailyEndTime: SCHEDULE_STEP,
  StartDate: SCHEDULE_STEP,
  EndDate: SCHEDULE_STEP,
  Expires: SCHEDULE_STEP,
  ExpiresDays: SCHEDULE_STEP,
  ExpiresHours: SCHEDULE_STEP,
  ExpiresMinutes: SCHEDULE_STEP,
  RunAsUser: OPTIONS_STEP,
  Priority: OPTIONS_STEP,
  IsBatch: OPTIONS_STEP,
  MirrorStatus: OPTIONS_STEP,
  OpenOutputFile: OPTIONS_STEP,
  OutputFilename: OPTIONS_STEP,
  OutputFileIsBinary: OPTIONS_STEP,
  EmailOutput: OPTIONS_STEP,
  SuspendOnError: OPTIONS_STEP,
  SuspendTerminated: OPTIONS_STEP,
  RescheduleOnStart: OPTIONS_STEP,
  EmailOnCompletion: OPTIONS_STEP,
  EmailOnError: OPTIONS_STEP,
  EmailOnExpiration: OPTIONS_STEP,
};

/** The step `field` is drawn on, a setting's (`Settings.<name>`) included, or `null` for none. */
export function stepOfField(field: string): string | null {
  if (field.startsWith(SETTING_PREFIX)) return TYPE_STEP;
  return Object.hasOwn(STEP_OF, field) ? STEP_OF[field] : null;
}

/**
 * The field-to-step map `core/form-tabs.ts` reads, with one `Settings.<name>` entry per setting of
 * the chosen type, so a refused setting counts on the type step and opens it.
 */
export function fieldSteps(settingNames: readonly string[]): Readonly<Record<string, string>> {
  const map: Record<string, string> = { ...STEP_OF };
  for (const name of settingNames) map[`${SETTING_PREFIX}${name}`] = TYPE_STEP;
  return map;
}

/** The field order `tabToOpen` reads, with the settings in their own order after the type. */
export function fieldOrder(settingNames: readonly string[]): readonly string[] {
  const at = FIELD_ORDER.indexOf(SETTINGS_FIELD);
  return [...FIELD_ORDER.slice(0, at + 1), ...settingNames.map((name) => `${SETTING_PREFIX}${name}`), ...FIELD_ORDER.slice(at + 1)];
}

/** What the wizard holds: text for every kind but the flags, and the chosen type's settings as text. */
export interface TaskValues {
  readonly text: Readonly<Record<string, string>>;
  readonly flags: Readonly<Record<string, boolean>>;
  readonly settings: Readonly<Record<string, string>>;
}

/** `period`'s logical value, 0 to 5, or -1 for none of them. */
export function periodIndex(period: string): number {
  return PERIODS.indexOf(period);
}

/**
 * Whether the chosen period and frequency read `field`: the frequency, date and expiry fields for
 * periods 0 to 3 alone, `RunAfterGUID` for Run After alone, `TimePeriodEvery` for 0 to 3,
 * `TimePeriodDay` for 1 to 3, and the three Several fields only with Several. Every other field
 * always applies.
 */
export function applies(field: string, values: TaskValues): boolean {
  const period = periodIndex(values.text['TimePeriod'] ?? '');
  if (field === 'RunAfterGUID') return period === 4;
  if (field === 'TimePeriodEvery') return period >= 0 && period <= 3;
  if (field === 'TimePeriodDay') return period >= 1 && period <= 3;
  if (SCHEDULED_FIELDS.includes(field)) {
    if (period < 0 || period > 3) return false;
    if (SEVERAL_FIELDS.includes(field)) return (values.text['DailyFrequency'] ?? '') === 'Several';
  }
  return true;
}

/** An address list's text as the array the server takes: each entry trimmed, empty ones dropped. */
export function addressList(text: string): string[] {
  return text
    .split(',')
    .map((entry) => entry.trim())
    .filter((entry) => entry !== '');
}

/**
 * A create's body: every field the chosen period and frequency read, in the wizard's order -- a flag
 * as a boolean, an address list as an array, the type's settings as an object of text, and every
 * other field as its text. A field the period does not read is left out, and the server sends the
 * vendor's own value for it. No output directory ever travels (AD-21).
 */
export function createBody(values: TaskValues): Record<string, unknown> {
  const body: Record<string, unknown> = {};
  for (const field of FIELD_ORDER) {
    if (!applies(field, values)) continue;
    if (field === SETTINGS_FIELD) {
      body[field] = { ...values.settings };
      continue;
    }
    if (FLAG_FIELDS.includes(field)) {
      body[field] = values.flags[field] ?? false;
      continue;
    }
    if (EMAIL_FIELDS.includes(field)) {
      body[field] = addressList(values.text[field] ?? '');
      continue;
    }
    body[field] = values.text[field] ?? '';
  }
  return body;
}

/** The fields one step draws, in the wizard's order: `FIELD_ORDER` narrowed to `step`. */
export function fieldsOfStep(step: string): readonly string[] {
  return FIELD_ORDER.filter((field) => STEP_OF[field] === step);
}

/**
 * The Dashboard's own state (Story 16.7): the classic System Dashboard's seven groups in order,
 * each meter's field, label, kind, unit and readout format, and how the one read row becomes each
 * meter's `MeterView`.
 *
 * Framework-free, like `system-usage.store.ts`, so `ui/tools/dashboard-store.test.mjs` executes it
 * under `node --test`. The fault-keeps-last-value rule needs no code here, for the reason
 * `system-usage.store.ts` gives: a fault never writes the store, so the row passed in is the last
 * successful one.
 *
 * **Three kinds, System usage's own.** A `status` meter shows the vendor's own word
 * (`meterStateFromWord`: Normal is success, Warning warning, Troubled error, and any other word is
 * warning, shown as that word). A `percent` meter's field already carries a percentage -- the
 * sensors' CPU and the dashboard's license use -- read against DESIGN.md's cut-offs
 * (`meterStateFromPercent`: 85 for warning, 95 for error). A `value` meter carries no state and no
 * state color: no threshold the instance does not give is invented, so no value meter reads
 * "Normal".
 */

import { meterStateFromPercent, meterStateFromWord, type MeterSeverity } from '../../core/meter-state.ts';
import { STRINGS, stringFor } from '../../core/strings.ts';
import { fieldOf, groupDigits } from '../../core/table-model.ts';

/** The severity a track meter carries before its first answer -- never shown as a color. */
const PENDING_STATE: MeterSeverity = 'normal';

/** The three meter kinds (Story 6.9's reading of the one meter criterion). */
export type DashboardMeterKind = 'status' | 'percent' | 'value';

/**
 * How a value meter's readout is written: `whole`, a whole number with its digits grouped (counts
 * and rates); `decimal`, one decimal (cache efficiency and traffic); `text`, the vendor's own
 * string (uptime, last backup).
 */
export type DashboardFormat = 'whole' | 'decimal' | 'text';

/** One meter's declaration. */
export interface DashboardMeter {
  /** The read field the meter reads -- for a percent meter, the percentage itself. */
  readonly field: string;
  readonly labelKey: string;
  readonly kind: DashboardMeterKind;
  /** The unit shown after the readout, `''` for none; a percent meter's is the `%` literal. */
  readonly unit: string;
  /** A value meter's readout format; unused by the other two kinds. */
  readonly format: DashboardFormat;
}

/** One group: its heading's key and its meters in order. The Task manager group carries none. */
export interface DashboardGroup {
  readonly key: string;
  readonly headingKey: string;
  readonly meters: readonly DashboardMeter[];
}

/** The key of the one group drawn from Upcoming tasks' own read rather than from meters. */
export const TASK_MANAGER_GROUP = 'tasks';

/** The percent unit, the `%` literal `system-usage.store.ts` uses. */
const PERCENT = '%';

const status = (field: string, labelKey: string): DashboardMeter => ({ field, labelKey, kind: 'status', unit: '', format: 'text' });
const percent = (field: string, labelKey: string): DashboardMeter => ({ field, labelKey, kind: 'percent', unit: PERCENT, format: 'decimal' });
const value = (field: string, labelKey: string, format: DashboardFormat, unit = ''): DashboardMeter => ({
  field,
  labelKey,
  kind: 'value',
  unit,
  format,
});

/** The seven groups, in the classic page's order, with each group's meters in its order. */
export const DASHBOARD_GROUPS: readonly DashboardGroup[] = [
  {
    key: 'performance',
    headingKey: 'performanceHeading',
    meters: [
      percent('Sensors.cpuUsage', 'dashboardCpu'),
      value('Dashboard.Performance.GlobalRefsPerSecond', 'systemUsageGlobalRefsPerSecond', 'whole', STRINGS.performanceRateUnit),
      value('Dashboard.Performance.GlobalRefs', 'processDetailsGlobalReferences', 'whole'),
      value('Dashboard.Performance.GlobalSetKill', 'systemUsageGlobalUpdates', 'whole'),
      value('Dashboard.Performance.RoutineRefs', 'dashboardRoutineReferences', 'whole'),
      value('Dashboard.Performance.LogicalRequests', 'systemUsageLogicalBlockRequests', 'whole'),
      value('Dashboard.Performance.DiskReads', 'performanceDiskReads', 'whole'),
      value('Dashboard.Performance.DiskWrites', 'performanceDiskWrites', 'whole'),
      value('Dashboard.Performance.CacheEfficiency', 'systemUsageCacheEfficiency', 'decimal', STRINGS.performanceCacheUnit),
    ],
  },
  {
    key: 'ecp',
    headingKey: 'dashboardGroupEcp',
    meters: [
      status('Dashboard.ECP.ECPClients', 'dashboardApplicationServers'),
      value('Dashboard.ECP.ECPClientTraffic', 'dashboardApplicationServerTraffic', 'decimal', STRINGS.dashboardBytesPerSecond),
      status('Dashboard.ECP.ECPServers', 'dashboardDataServers'),
      value('Dashboard.ECP.ECPServerTraffic', 'dashboardDataServerTraffic', 'decimal', STRINGS.dashboardBytesPerSecond),
      status('Dashboard.ECP.ShadowConnections', 'dashboardShadowSource'),
      status('Dashboard.ECP.Shadows', 'dashboardShadowServer'),
    ],
  },
  {
    key: 'status',
    headingKey: 'dashboardGroupStatus',
    meters: [value('Dashboard.Status.UpTime', 'systemInfoUptime', 'text'), value('Dashboard.Status.LastBackup', 'dashboardLastBackup', 'text')],
  },
  {
    key: 'usage',
    headingKey: 'systemUsageLabel',
    meters: [
      status('Dashboard.SystemUsage.DatabaseSpace', 'systemUsageDatabaseSpace'),
      status('Dashboard.SystemUsage.DatabaseJournal', 'dashboardDatabaseJournal'),
      status('Dashboard.SystemUsage.JournalSpace', 'systemUsageJournalSpace'),
      value('Dashboard.SystemUsage.JournalEntries', 'systemUsageJournalEntries', 'whole'),
      status('Dashboard.SystemUsage.LockTable', 'systemUsageLockTable'),
      status('Dashboard.SystemUsage.WriteDaemon', 'systemUsageWriteDaemon'),
      value('Dashboard.SystemUsage.Processes', 'processListLabel', 'whole'),
      value('Dashboard.SystemUsage.CSPSessions', 'webSessionListLabel', 'whole'),
    ],
  },
  {
    key: 'alerts',
    headingKey: 'dashboardGroupAlerts',
    meters: [
      value('Dashboard.Alerts.SeriousAlerts', 'dashboardSeriousAlerts', 'whole'),
      value('Dashboard.Alerts.ApplicationErrors', 'errorLogListLabel', 'whole'),
    ],
  },
  {
    key: 'licensing',
    headingKey: 'dashboardGroupLicensing',
    meters: [
      value('Dashboard.Licensing.LicenseLimit', 'dashboardLicenseLimit', 'whole', STRINGS.dashboardLicenseUnitsUnit),
      percent('Dashboard.Licensing.LicenseUse', 'dashboardLicenseUse'),
      percent('Dashboard.Licensing.LicenseUseHigh', 'dashboardLicenseUseHigh'),
    ],
  },
  { key: TASK_MANAGER_GROUP, headingKey: 'dashboardGroupTasks', meters: [] },
];

/** One meter's resolved props, bound straight onto `app-meter`. */
export interface DashboardMeterView {
  readonly field: string;
  readonly label: string;
  readonly value: number | null;
  /** The formatted readout, or `null` while nothing has arrived. */
  readonly text: string | null;
  readonly unit: string;
  readonly percent: number | null;
  readonly state: MeterSeverity | null;
  readonly word: string | null;
  readonly error: string | null;
}

/** A readout for `raw` in `format`, or `null` when the row carries nothing that format can write. */
export function formatReadout(raw: unknown, format: DashboardFormat): string | null {
  if (format === 'text') {
    if (typeof raw === 'string') return raw;
    return typeof raw === 'number' ? String(raw) : null;
  }
  if (typeof raw !== 'number' || !Number.isFinite(raw)) return null;
  const sign = raw < 0 ? '-' : '';
  const magnitude = Math.abs(raw);
  if (format === 'whole') return sign + groupDigits(Math.round(magnitude));
  const [whole, fraction] = (Math.round(magnitude * 10) / 10).toFixed(1).split('.');
  return `${sign}${groupDigits(Number(whole))}.${fraction}`;
}

/** One meter's resolved view from `meter`, the last-good `row` (or `undefined`), and the page's current fault text. */
export function dashboardMeterView(meter: DashboardMeter, row: unknown, faultText: string | null): DashboardMeterView {
  const raw = fieldOf(row, meter.field);
  const base = { field: meter.field, label: stringFor(meter.labelKey), unit: meter.unit, error: faultText };
  if (meter.kind === 'value') {
    return { ...base, value: null, text: formatReadout(raw, meter.format), percent: null, state: null, word: null };
  }
  if (meter.kind === 'percent') {
    const reading = typeof raw === 'number' && Number.isFinite(raw) ? raw : null;
    const known = reading === null ? null : meterStateFromPercent(reading);
    return {
      ...base,
      value: reading,
      text: null,
      percent: reading,
      state: known?.state ?? PENDING_STATE,
      word: known?.word ?? null,
    };
  }
  // 'status'
  const word = typeof raw === 'string' && raw !== '' ? raw : null;
  const known = word === null ? null : meterStateFromWord(word);
  return { ...base, value: null, text: null, percent: null, state: known?.state ?? PENDING_STATE, word: known?.word ?? null };
}

/** Every field `DASHBOARD_GROUPS` reads, in group and meter order. */
export function dashboardFields(): readonly string[] {
  return DASHBOARD_GROUPS.flatMap((group) => group.meters.map((meter) => meter.field));
}

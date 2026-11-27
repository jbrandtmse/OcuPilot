/**
 * The Interoperability System monitor's own state (Story 24.17 Batch 5): the classic Interoperability System Monitor's groups in order, each meter's field, label and kind, the three tables
 * the page draws from the drill-downs' own declared reads, and how the one read row becomes each meter's `MeterView`.
 *
 * Framework-free, like `dashboard.store.ts`, so `ui/tools/interop-system-monitor-store.test.mjs` executes it under `node --test`. The fault-keeps-last-value rule needs no code here: a fault never
 * writes the store, so the row passed in is the last successful one.
 *
 * **Two kinds.** A `status` meter shows the vendor's own word (`meterStateFromWord`: Normal is success, Warning warning, Troubled error, any other word warning, shown as that word). A `value` meter
 * shows the vendor's text as it came, with no state and no state color: every field of the row is the vendor's text, so no number is parsed out of it and no threshold the instance does not give
 * is invented.
 */

import { meterStateFromWord, type MeterSeverity } from '../../core/meter-state.ts';
import { stringFor } from '../../core/strings.ts';
import { fieldOf } from '../../core/table-model.ts';

/** The severity a track meter carries before its first answer -- never shown as a color. */
const PENDING_STATE: MeterSeverity = 'normal';

/** The readout of a value the vendor leaves empty: an em dash, written as its escape so no non-ASCII byte enters a source file. */
const EMPTY_READOUT = String.fromCharCode(0x2014);

/** The two meter kinds. */
export type MonitorMeterKind = 'status' | 'value';

/** One meter's declaration. */
export interface MonitorMeter {
  readonly field: string;
  readonly labelKey: string;
  readonly kind: MonitorMeterKind;
}

/** One table the page draws under a group from a drill-down's own read: the drill-down's route and the fields it draws, in order. */
export interface MonitorTable {
  readonly key: string;
  readonly route: string;
  readonly fields: readonly string[];
}

/** One group: its heading's key, its meters in order, and the table drawn under it, if any. */
export interface MonitorGroup {
  readonly key: string;
  readonly headingKey: string;
  readonly meters: readonly MonitorMeter[];
  readonly table?: MonitorTable;
}

/** Most active processes, drawn under Production jobs. */
export const PROCESSES_TABLE: MonitorTable = {
  key: 'processes',
  route: 'interoperability/system-monitor/processes',
  fields: ['Namespace', 'Item', 'Pid', 'Commands'],
};

/** Most active queues, drawn under Production queues. */
export const QUEUES_TABLE: MonitorTable = {
  key: 'queues',
  route: 'interoperability/system-monitor/queues',
  fields: ['Namespace', 'Queue', 'Messages'],
};

/** Upcoming tasks, drawn under Task manager. */
export const TASKS_TABLE: MonitorTable = {
  key: 'tasks',
  route: 'interoperability/system-monitor/tasks',
  fields: ['Task', 'ScheduledFor', 'Status'],
};

const status = (field: string, labelKey: string): MonitorMeter => ({ field, labelKey, kind: 'status' });
const value = (field: string, labelKey: string): MonitorMeter => ({ field, labelKey, kind: 'value' });

/** The groups, in the classic page's order. */
export const MONITOR_GROUPS: readonly MonitorGroup[] = [
  {
    key: 'throughput',
    headingKey: 'interopSystemMonitorGroupThroughput',
    meters: [
      value('EnsNamespace', 'interopSystemMonitorMeterScopes'),
      value('EnsProductionsRunning', 'interopSystemMonitorMeterProductionsRunning'),
      value('EnsProductionsTroubled', 'interopSystemMonitorMeterProductionsTroubled'),
      value('EnsIncomingRequests', 'interopSystemMonitorMeterIncoming'),
      value('EnsLastIncomingRequest', 'interopSystemMonitorMeterLastIncoming'),
      value('EnsOutgoingRequests', 'interopSystemMonitorMeterOutgoing'),
      value('EnsLastOutgoingRequest', 'interopSystemMonitorMeterLastOutgoing'),
    ],
  },
  {
    key: 'jobs',
    headingKey: 'interopSystemMonitorGroupJobs',
    meters: [value('EnsJobs', 'interopSystemMonitorMeterJobs'), value('EnsVisitingJobs', 'interopSystemMonitorMeterVisitingJobs')],
    table: PROCESSES_TABLE,
  },
  {
    key: 'time',
    headingKey: 'interopSystemMonitorGroupTime',
    meters: [value('UpTime', 'systemInfoUptime'), value('LastBackup', 'dashboardLastBackup')],
  },
  {
    key: 'usage',
    headingKey: 'systemUsageLabel',
    meters: [
      value('Processes', 'processListLabel'),
      status('DatabaseSpace', 'systemUsageDatabaseSpace'),
      status('DatabaseJournal', 'dashboardDatabaseJournal'),
      status('JournalSpace', 'systemUsageJournalSpace'),
      value('JournalEntries', 'systemUsageJournalEntries'),
      status('LockTable', 'systemUsageLockTable'),
      status('WriteDaemon', 'systemUsageWriteDaemon'),
    ],
  },
  {
    key: 'queues',
    headingKey: 'interopSystemMonitorGroupQueues',
    meters: [value('EnsActiveQueues', 'interopSystemMonitorMeterActiveQueues')],
    table: QUEUES_TABLE,
  },
  {
    key: 'alerts',
    headingKey: 'dashboardGroupAlerts',
    meters: [
      value('SeriousAlerts', 'dashboardSeriousAlerts'),
      value('EnsAlerts', 'interopSystemMonitorMeterAlerts'),
      value('EnsErrors', 'interopSystemMonitorMeterErrors'),
    ],
  },
  {
    key: 'licensing',
    headingKey: 'dashboardGroupLicensing',
    meters: [
      value('LicenseLimit', 'dashboardLicenseLimit'),
      value('LicenseUse', 'dashboardLicenseUse'),
      value('LicenseUseHigh', 'dashboardLicenseUseHigh'),
    ],
  },
  { key: 'tasks', headingKey: 'dashboardGroupTasks', meters: [], table: TASKS_TABLE },
];

/** One meter's resolved props, bound straight onto `app-meter`. */
export interface MonitorMeterView {
  readonly field: string;
  readonly label: string;
  readonly value: number | null;
  /** The vendor's text, or `null` while nothing has arrived. */
  readonly text: string | null;
  readonly unit: string;
  readonly percent: number | null;
  readonly state: MeterSeverity | null;
  readonly word: string | null;
  readonly error: string | null;
}

/** One meter's resolved view from `meter`, the last-good `row` (or `undefined`), and the page's current fault text. */
export function monitorMeterView(meter: MonitorMeter, row: unknown, faultText: string | null): MonitorMeterView {
  const raw = fieldOf(row, meter.field);
  const text = typeof raw === 'string' ? raw : typeof raw === 'number' ? String(raw) : null;
  const base = { field: meter.field, label: stringFor(meter.labelKey), unit: '', value: null, percent: null, error: faultText };
  if (meter.kind === 'value') {
    // The vendor leaves a last-message time empty while there is none: the readout is the dash a pending meter shows, written as its escape (Rule 14).
    return { ...base, text: text === '' ? EMPTY_READOUT : text, state: null, word: null };
  }
  const word = text !== null && text !== '' ? text : null;
  const known = word === null ? null : meterStateFromWord(word);
  return { ...base, text: null, state: known?.state ?? PENDING_STATE, word: known?.word ?? null };
}

/** Every field `MONITOR_GROUPS` reads from the one row, in group and meter order. */
export function monitorFields(): readonly string[] {
  return MONITOR_GROUPS.flatMap((group) => group.meters.map((meter) => meter.field));
}

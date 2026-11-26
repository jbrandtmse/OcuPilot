import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the System monitor's own state (`areas/interoperability/interop-system-monitor.store.ts`, Story 24.17 Batch 5): the groups and their
// meters in the classic page's order, each field one the descriptor reads and each meter read once, the three tables each naming a built
// drill-down and fields that drill-down declares, and the two meter kinds' resolved views -- a value meter carrying the vendor's text and no
// state, an empty value as the dash, a status meter carrying the vendor's word and its state, an unknown word shown as warning.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const store = await import(join(uiRoot, 'src', 'app', 'areas', 'interoperability', 'interop-system-monitor.store.ts'));
const { SCREENS } = await import(join(uiRoot, 'src', 'app', 'core', 'screens.generated.ts'));
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const DESCRIPTOR = 'OcuPilot.Screen.Descriptor.InteropSystemMonitor';

/** The meter a group declares at `field`. */
function meterAt(field) {
  for (const group of store.MONITOR_GROUPS) {
    const meter = group.meters.find((candidate) => candidate.field === field);
    if (meter !== undefined) return meter;
  }
  throw new Error(`no meter reads ${field}`);
}

test('the eight groups are the classic page\'s, in its order, with the Task manager group last and meterless', () => {
  assert.deepEqual(
    store.MONITOR_GROUPS.map((group) => [group.key, STRINGS[group.headingKey]]),
    [
      ['throughput', 'Production throughput'],
      ['jobs', 'Production jobs'],
      ['time', 'System time'],
      ['usage', 'System usage'],
      ['queues', 'Production queues'],
      ['alerts', 'Errors and alerts'],
      ['licensing', 'Licensing'],
      ['tasks', 'Task manager'],
    ]
  );
  assert.equal(store.MONITOR_GROUPS.at(-1).meters.length, 0);
});

test('every field the descriptor reads is drawn once, and every meter reads one the descriptor declares', () => {
  const declared = SCREENS.find((screen) => screen.descriptor === DESCRIPTOR);
  assert.ok(declared, 'the screen is in the mirror');
  assert.deepEqual([...store.monitorFields()].sort(), [...declared.read.fields].sort());
  assert.equal(store.monitorFields().length, 25);
  for (const group of store.MONITOR_GROUPS) {
    for (const meter of group.meters) assert.ok(STRINGS[meter.labelKey], `${meter.field}: its label is a published string`);
  }
});

test('each meter shows the label and kind the spec places it under, group by group', () => {
  const placed = [
    ['throughput', 'EnsNamespace', 'value', 'Namespaces running productions'],
    ['throughput', 'EnsProductionsRunning', 'value', 'Productions running'],
    ['throughput', 'EnsProductionsTroubled', 'value', 'Productions suspended or troubled'],
    ['throughput', 'EnsIncomingRequests', 'value', 'Incoming messages in the last 30 seconds'],
    ['throughput', 'EnsLastIncomingRequest', 'value', 'Last incoming message'],
    ['throughput', 'EnsOutgoingRequests', 'value', 'Outgoing messages in the last 30 seconds'],
    ['throughput', 'EnsLastOutgoingRequest', 'value', 'Last outgoing message'],
    ['jobs', 'EnsJobs', 'value', 'Active production jobs'],
    ['jobs', 'EnsVisitingJobs', 'value', 'Visiting production jobs'],
    ['time', 'UpTime', 'value', 'Uptime'],
    ['time', 'LastBackup', 'value', 'Last backup'],
    ['usage', 'Processes', 'value', 'Processes'],
    ['usage', 'DatabaseSpace', 'status', 'Database space'],
    ['usage', 'DatabaseJournal', 'status', 'Database journal'],
    ['usage', 'JournalSpace', 'status', 'Journal space'],
    ['usage', 'JournalEntries', 'value', 'Journal entries'],
    ['usage', 'LockTable', 'status', 'Lock table'],
    ['usage', 'WriteDaemon', 'status', 'Write daemon'],
    ['queues', 'EnsActiveQueues', 'value', 'Active queues'],
    ['alerts', 'SeriousAlerts', 'value', 'Serious alerts'],
    ['alerts', 'EnsAlerts', 'value', 'Production alerts'],
    ['alerts', 'EnsErrors', 'value', 'Production errors'],
    ['licensing', 'LicenseLimit', 'value', 'License limit'],
    ['licensing', 'LicenseUse', 'value', 'Current license use'],
    ['licensing', 'LicenseUseHigh', 'value', 'Highest license use'],
  ];
  const drawn = store.MONITOR_GROUPS.flatMap((group) => group.meters.map((meter) => [group.key, meter.field, meter.kind, STRINGS[meter.labelKey]]));
  assert.deepEqual(drawn, placed);
});

test('each table names a built drill-down and fields that drill-down declares', () => {
  for (const group of store.MONITOR_GROUPS.filter((item) => item.table !== undefined)) {
    const screen = SCREENS.find((candidate) => candidate.route === group.table.route);
    assert.ok(screen, `${group.table.route} is in the mirror`);
    assert.equal(screen.built, true, `${group.table.route} is built`);
    assert.deepEqual(group.table.fields, screen.table.columns.map((column) => column.field), `${group.table.route}: the page draws the columns the screen declares`);
  }
});

test('a value meter carries the vendor\'s text and no state; an empty value is the dash', () => {
  const view = store.monitorMeterView(meterAt('EnsJobs'), { EnsJobs: '5' }, null);
  assert.equal(view.text, '5');
  assert.equal(view.state, null);
  assert.equal(view.word, null);
  assert.equal(store.monitorMeterView(meterAt('EnsLastIncomingRequest'), { EnsLastIncomingRequest: '' }, null).text, String.fromCharCode(0x2014));
  assert.equal(store.monitorMeterView(meterAt('JournalEntries'), { JournalEntries: '3,269,289' }, null).text, '3,269,289');
});

test('a status meter carries the vendor\'s word and its state; an unknown word reads as warning, shown as that word', () => {
  const known = store.monitorMeterView(meterAt('LockTable'), { LockTable: 'Normal' }, null);
  assert.deepEqual([known.word, known.state, known.text], ['Normal', 'normal', null]);
  const troubled = store.monitorMeterView(meterAt('LockTable'), { LockTable: 'Troubled' }, null);
  assert.deepEqual([troubled.word, troubled.state], ['Troubled', 'error']);
  const unknown = store.monitorMeterView(meterAt('LockTable'), { LockTable: 'Odd' }, null);
  assert.deepEqual([unknown.word, unknown.state], ['Odd', 'warning']);
});

test('before any answer a meter has no text and no word, and a fault travels as its error', () => {
  for (const field of ['EnsJobs', 'LockTable']) {
    const view = store.monitorMeterView(meterAt(field), undefined, 'refused');
    assert.deepEqual([view.text, view.word, view.error], [null, null, 'refused'], field);
  }
});

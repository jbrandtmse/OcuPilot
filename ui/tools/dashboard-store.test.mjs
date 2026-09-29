import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the Dashboard's own state (`areas/os-management/dashboard.store.ts`, Story 16.7): the seven
// groups and their meters in the classic page's order, each field one the descriptor reads, the
// three meter kinds' resolved views -- a value meter carrying no state, the percent cut-offs at 84,
// 85 and 95, an unknown status word shown as warning with the vendor's own word -- and the
// readout formats.
//
// Mutations (Rule 19):
// - give `Dashboard.Performance.GlobalRefs` the status kind -> "a value meter carries no state"
//   goes red.
// - move the percent warning cut-off from 85 to 86 in `meter-state.ts` -> the cut-off case goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const store = await import(join(uiRoot, 'src', 'app', 'areas', 'os-management', 'dashboard.store.ts'));
const { SCREENS } = await import(join(uiRoot, 'src', 'app', 'core', 'screens.generated.ts'));
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const DESCRIPTOR = 'OcuPilot.Screen.Descriptor.Dashboard';

/** The meter a group declares at `field`. */
function meterAt(field) {
  for (const group of store.DASHBOARD_GROUPS) {
    const meter = group.meters.find((candidate) => candidate.field === field);
    if (meter !== undefined) return meter;
  }
  throw new Error(`no meter reads ${field}`);
}

test('the seven groups are the classic page\'s, in its order, with the Task manager group last and meterless', () => {
  assert.deepEqual(
    store.DASHBOARD_GROUPS.map((group) => [group.key, STRINGS[group.headingKey]]),
    [
      ['performance', 'Performance'],
      ['ecp', 'ECP and shadowing'],
      ['status', 'System status'],
      ['usage', 'System usage'],
      ['alerts', 'Errors and alerts'],
      ['licensing', 'Licensing'],
      [store.TASK_MANAGER_GROUP, 'Task manager'],
    ]
  );
  assert.deepEqual(store.DASHBOARD_GROUPS.at(-1).meters, [], 'the Task manager group draws Upcoming tasks\' rows, not meters');
});

test('the meters read the descriptor\'s thirty fields, in the declared order, each with a label the string source holds', () => {
  const declaration = SCREENS.find((screen) => screen.descriptor === DESCRIPTOR);
  assert.ok(declaration !== undefined, 'the Dashboard is declared');
  assert.deepEqual(store.dashboardFields(), declaration.read.fields, 'the meters read exactly the declared fields, in order');
  assert.deepEqual(
    store.DASHBOARD_GROUPS.map((group) => group.meters.length),
    [9, 6, 2, 8, 2, 3, 0],
    'nine performance, six ECP and shadowing, two status, eight usage, two alerts and three licensing meters'
  );
  for (const group of store.DASHBOARD_GROUPS) {
    for (const meter of group.meters) {
      assert.ok(typeof STRINGS[meter.labelKey] === 'string' && STRINGS[meter.labelKey] !== '', `${meter.field}'s label key resolves`);
    }
  }
  assert.deepEqual(
    store.DASHBOARD_GROUPS.flatMap((group) => group.meters.filter((meter) => meter.kind === 'percent').map((meter) => meter.field)),
    ['Sensors.cpuUsage', 'Dashboard.Licensing.LicenseUse', 'Dashboard.Licensing.LicenseUseHigh'],
    'CPU and the two license-use meters are the percent meters'
  );
  assert.deepEqual(
    store.DASHBOARD_GROUPS.flatMap((group) => group.meters.filter((meter) => meter.kind === 'status').map((meter) => meter.field)),
    [
      'Dashboard.ECP.ECPClients',
      'Dashboard.ECP.ECPServers',
      'Dashboard.ECP.ShadowConnections',
      'Dashboard.ECP.Shadows',
      'Dashboard.SystemUsage.DatabaseSpace',
      'Dashboard.SystemUsage.DatabaseJournal',
      'Dashboard.SystemUsage.JournalSpace',
      'Dashboard.SystemUsage.LockTable',
      'Dashboard.SystemUsage.WriteDaemon',
    ],
    'the nine members the vendor answers with a word are the status meters'
  );
});

test('a value meter carries no state, no word and no percentage, only its formatted readout and unit', () => {
  const row = {
    'Dashboard.Performance.GlobalRefs': 64649129276,
    'Dashboard.Performance.CacheEfficiency': 4054.06,
    'Dashboard.Performance.GlobalRefsPerSecond': 219.4,
    'Dashboard.ECP.ECPClientTraffic': 0,
    'Dashboard.Status.UpTime': '8d 18h 25m',
    'Dashboard.Licensing.LicenseLimit': 8,
  };
  const refs = store.dashboardMeterView(meterAt('Dashboard.Performance.GlobalRefs'), row, null);
  assert.equal(refs.state, null, 'no state');
  assert.equal(refs.word, null, 'no word');
  assert.equal(refs.percent, null, 'no percentage');
  assert.equal(refs.text, '64,649,129,276', 'a whole number with its digits grouped');
  assert.equal(store.dashboardMeterView(meterAt('Dashboard.Performance.GlobalRefsPerSecond'), row, null).text, '219', 'a rate is a whole number');
  assert.equal(store.dashboardMeterView(meterAt('Dashboard.Performance.GlobalRefsPerSecond'), row, null).unit, STRINGS.performanceRateUnit);
  const cache = store.dashboardMeterView(meterAt('Dashboard.Performance.CacheEfficiency'), row, null);
  assert.equal(cache.text, '4,054.1', 'cache efficiency shows one decimal');
  assert.equal(cache.unit, STRINGS.performanceCacheUnit);
  const traffic = store.dashboardMeterView(meterAt('Dashboard.ECP.ECPClientTraffic'), row, null);
  assert.equal(traffic.text, '0.0', 'traffic shows one decimal, and an idle link reads 0.0 rather than a state');
  assert.equal(traffic.unit, STRINGS.dashboardBytesPerSecond);
  assert.equal(traffic.state, null);
  assert.equal(store.dashboardMeterView(meterAt('Dashboard.Status.UpTime'), row, null).text, '8d 18h 25m', 'the vendor\'s own uptime string');
  const limit = store.dashboardMeterView(meterAt('Dashboard.Licensing.LicenseLimit'), row, null);
  assert.equal(limit.text, '8');
  assert.equal(limit.unit, STRINGS.dashboardLicenseUnitsUnit);
  for (const group of store.DASHBOARD_GROUPS) {
    for (const meter of group.meters.filter((candidate) => candidate.kind === 'value')) {
      assert.equal(store.dashboardMeterView(meter, row, null).state, null, `${meter.field} carries no state`);
    }
  }
});

test('the percent cut-offs are DESIGN.md\'s: 84 is Normal, 85 Warning, 95 Troubled -- word and severity', () => {
  const cpu = meterAt('Sensors.cpuUsage');
  const at = (value) => store.dashboardMeterView(cpu, { 'Sensors.cpuUsage': value }, null);
  assert.deepEqual([at(84).state, at(84).word], ['normal', 'Normal']);
  assert.deepEqual([at(85).state, at(85).word], ['warning', 'Warning']);
  assert.deepEqual([at(95).state, at(95).word], ['error', 'Troubled']);
  assert.equal(at(85).unit, '%', 'a percent meter\'s unit is the % literal');
  assert.equal(at(85).value, 85, 'its value is the percentage the field carries');
  assert.equal(at(85).percent, 85, 'and so is its fill');
  const license = store.dashboardMeterView(meterAt('Dashboard.Licensing.LicenseUse'), { 'Dashboard.Licensing.LicenseUse': 13 }, null);
  assert.deepEqual([license.state, license.word, license.percent], ['normal', 'Normal', 13], 'license use is read as the percentage the dashboard answers');
});

test('a status meter shows the vendor\'s word, and an unknown word as warning with that word', () => {
  const space = meterAt('Dashboard.SystemUsage.DatabaseSpace');
  const read = (word) => store.dashboardMeterView(space, { 'Dashboard.SystemUsage.DatabaseSpace': word }, null);
  assert.deepEqual([read('Normal').state, read('Normal').word], ['normal', 'Normal']);
  assert.deepEqual([read('Warning').state, read('Warning').word], ['warning', 'Warning']);
  assert.deepEqual([read('Troubled').state, read('Troubled').word], ['error', 'Troubled']);
  assert.deepEqual([read('Degraded').state, read('Degraded').word], ['warning', 'Degraded'], 'an unknown word draws attention, in the vendor\'s own word');
});

test('before any read every meter is pending -- no value, no readout, no word -- and a fault rides as the tooltip text', () => {
  for (const group of store.DASHBOARD_GROUPS) {
    for (const meter of group.meters) {
      const view = store.dashboardMeterView(meter, undefined, null);
      assert.equal(view.value, null, `${meter.field}: no value`);
      assert.equal(view.text, null, `${meter.field}: no readout`);
      assert.equal(view.word, null, `${meter.field}: no word`);
      assert.equal(view.error, null, `${meter.field}: no error`);
      assert.equal(view.state === null, meter.kind === 'value', `${meter.field}: a track meter keeps a placeholder state, a value meter none`);
    }
  }
  const faulted = store.dashboardMeterView(meterAt('Sensors.cpuUsage'), { 'Sensors.cpuUsage': 3 }, 'request refused');
  assert.equal(faulted.error, 'request refused', 'the fault text rides as the tooltip');
  assert.equal(faulted.value, 3, 'and the last value is kept, for app-meter to dash');
});

test('formatReadout writes grouped whole numbers, one-decimal numbers and vendor text, and nothing for a mismatch', () => {
  assert.equal(store.formatReadout(1234567.6, 'whole'), '1,234,568');
  assert.equal(store.formatReadout(0, 'whole'), '0');
  assert.equal(store.formatReadout(-1234, 'whole'), '-1,234');
  assert.equal(store.formatReadout(1234.56, 'decimal'), '1,234.6');
  assert.equal(store.formatReadout(0.04, 'decimal'), '0.0');
  assert.equal(store.formatReadout('Never', 'text'), 'Never');
  assert.equal(store.formatReadout('8', 'whole'), null, 'a string is not a count');
  assert.equal(store.formatReadout(null, 'decimal'), null);
  assert.equal(store.formatReadout(undefined, 'text'), null);
});

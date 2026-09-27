/**
 * The secondary-log fixture (Story 16.8): one entry carrying `SECONDARY_MARKER` in each of the six
 * stores, seeded and removed through `OcuPilot.Test.LogSecondarySeed`, which holds the recipes
 * once for this spec and `OcuPilot.Test.LogSecondaryWire`. Named without the `.browser-spec`
 * suffix, so `npm run test:browser` does not collect it. Refuses anything but a `-ci` throwaway.
 */

import assert from 'node:assert/strict';

import { LIVE_CONTAINER } from '../browser.config.mjs';
import { escapeOs, markerValue, runIris } from './turnprobe-spec.mjs';

/** The text every seeded entry carries. */
export const SECONDARY_MARKER = 'OcuPilotSecondarySpec';

/** The six sources, their routes and the severity chip their seeded entry carries. */
export const SECONDARY_SOURCES = [
  { key: 'systemmonitor', chip: 'info', scoped: false },
  { key: 'taskerrors', chip: 'severe', scoped: true },
  { key: 'xdbc', chip: 'severe', scoped: true },
  { key: 'sqldiagnostics', chip: 'severe', scoped: true },
  { key: 'eventlog', chip: 'severe', scoped: true },
  { key: 'analytics', chip: 'info', scoped: true },
];

function refuseLive(container) {
  assert.notEqual(container, LIVE_CONTAINER, 'the secondary-log fixture writes the instance\u2019s own log stores, so it never runs against the live container');
  assert.match(container, /-ci$/, `the secondary-log fixture runs only in a throwaway; ${container} is not one`);
}

/** Seed one entry carrying `SECONDARY_MARKER` into each of the six stores. */
export function seedSecondaryLogs(container) {
  refuseLive(container);
  const output = runIris(container, [
    `Set sc=##class(OcuPilot.Test.LogSecondarySeed).Seed("${escapeOs(SECONDARY_MARKER)}")`,
    `Write "OCU-SECSEED-START:"_$Select($System.Status.IsOK(sc):"ok",1:$Translate($System.Status.GetErrorText(sc),":"," "))_":OCU-SECSEED-END",!`,
  ]);
  assert.equal(markerValue(output, 'SECSEED'), 'ok', `the six stores were seeded: ${output}`);
}

/** Append one System Monitor line carrying `text`, as the monitor itself writes one. */
export function appendMonitorLine(container, text) {
  refuseLive(container);
  const output = runIris(container, [
    `Set $NAMESPACE="%SYS" Set sc=##class(%SYS.Monitor.SampleSubscriber).%New().LogMsg("${escapeOs(text)}")`,
    `Write "OCU-SECMON-START:"_$Select(sc:"ok",1:"failed")_":OCU-SECMON-END",!`,
  ]);
  assert.equal(markerValue(output, 'SECMON'), 'ok', `the System Monitor line was written: ${output}`);
}

/** Remove what was seeded, and assert no store still holds the marker. */
export function removeSecondaryLogs(container) {
  refuseLive(container);
  const output = runIris(container, [
    `Set sc=##class(OcuPilot.Test.LogSecondarySeed).Remove()`,
    `Write "OCU-SECLEFT-START:"_$Select($System.Status.IsOK(sc):"none",1:$Translate($System.Status.GetErrorText(sc),":"," "))_"|"_##class(OcuPilot.Test.LogSecondarySeed).Left("${escapeOs(SECONDARY_MARKER)}")_":OCU-SECLEFT-END",!`,
  ]);
  assert.equal(markerValue(output, 'SECLEFT'), 'none|', `every seeded entry was removed: ${output}`);
}

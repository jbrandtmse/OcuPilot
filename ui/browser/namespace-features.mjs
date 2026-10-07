import { spawnSync } from 'node:child_process';

import { parseMarkers } from './iris-session.mjs';

/**
 * The features each namespace on the instance reports, read from the instance rather than assumed
 * (Story 20.1): `{ NAME: { interoperability: boolean, analytics: boolean } }` for every namespace
 * `Config.Namespaces:List` returns. The vendor's own checks answer, not OcuPilot's wrapper, so a spec that
 * picks a namespace by what it reports stays independent of the code it is about, and never
 * hard-codes a name. `GET /api/ocupilot/navigation?ns=` reports the same answers as each area's
 * `applies`.
 *
 * `container` is the throwaway; the read changes nothing.
 */
export function readNamespaceFeatures(container) {
  const lines = [
    'Set tRS=##class(%ResultSet).%New("Config.Namespaces:List") Do tRS.Execute() Set tNames=""',
    'While tRS.Next() { Set tNames=tNames_$ListBuild(tRS.Get("Namespace")) }',
    'Set $NAMESPACE=$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"):"HSCUSTOM",1:"USER") Set tOut=""',
    `For i=1:1:$ListLength(tNames) { Set n=$List(tNames,i) Set tOut=tOut_n_"="_''##class(%Library.EnsembleMgr).IsEnsembleNamespace(n)_''##class(%DeepSee.Utils).%IsDeepSeeEnabled(n)_";" }`,
    'Write "OCU"_"-FEATURES-START:"_tOut_":OCU"_"-FEATURES-END",!',
    'Halt',
  ];
  const result = spawnSync('docker', ['exec', '-i', container, 'iris', 'session', 'iris', '-U', '%SYS'], {
    input: `${lines.join('\n')}\n`,
    encoding: 'utf8',
    timeout: 120000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const { FEATURES: raw } = parseMarkers(output, ['FEATURES']);
  if (raw === null) throw new Error(`the namespace features could not be read: ${output}`);
  const byName = {};
  for (const entry of raw.split(';').filter((value) => value !== '')) {
    const [name, flags] = entry.split('=');
    byName[name] = { interoperability: flags[0] === '1', analytics: flags[1] === '1' };
  }
  return byName;
}

/** The namespace names whose features equal `wanted` exactly, in the order the instance lists them. */
export function namespacesWith(byName, wanted) {
  return Object.keys(byName).filter(
    (name) => byName[name].interoperability === wanted.interoperability && byName[name].analytics === wanted.analytics
  );
}

/** Whether `area` applies in a namespace that reports `reported`. */
export function areaApplies(area, reported) {
  return area.appliesWhen === undefined || reported[area.appliesWhen] === true;
}

/**
 * Wait until the shell's navigation map has answered for the namespace it is scoped to. The rail
 * sets `data-map-answered="true"` on its nav element then, and a category that declares
 * `appliesWhen` is not drawn before it (fail closed), so a count or an index taken earlier reads a
 * roster that is still short. `networkidle2` does not wait for it.
 *
 * The attribute names no namespace. After an in-shell switch, call this only once the rail has
 * re-rendered for the new namespace (a roster wait, for example); before that render it can still
 * read the previous namespace's `true`.
 */
export async function waitForMapAnswered(page, timeoutMs) {
  await page.waitForSelector('app-rail .ocu-rail[data-map-answered="true"]', { timeout: timeoutMs });
}

/** The areas of `areas` that apply in a namespace reporting `reported`, in rail order. */
export function appliedAreas(areas, reported) {
  return areas.filter((area) => areaApplies(area, reported)).sort((a, b) => a.railPosition - b.railPosition);
}

/** The areas Home draws a tile for: every applying area but Home itself and the pinned Agent co-pilot. */
export function tileAreasOf(applied) {
  return applied.filter((area) => !area.navigates && !area.pinBottom);
}

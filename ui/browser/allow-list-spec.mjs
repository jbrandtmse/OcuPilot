/**
 * Helpers for the browser specs that arrange the instance's directory allow-list (Stories 18.1 and 18.46):
 * `OcuPilot.Test.PathPortFixture`'s calls and a computed instance value, run inside the throwaway over `docker exec`, and
 * the probe directories a spec makes and removes under the manager directory.
 *
 * Named `allow-list-spec.mjs` rather than `*.browser-spec.mjs`, so `npm run test:browser`'s fixed glob does not run it as a
 * suite of its own while `ui/tools/client-lint.mjs`'s `browser/` walk still lints it. Every call refuses a container that
 * is not a throwaway, because each one changes the allow-list or the file system.
 */

import assert from 'node:assert/strict';

import { escapeOs, markerValue, runIris } from './turnprobe-spec.mjs';

const FIXTURE = 'OcuPilot.Test.PathPortFixture';

function requireThrowaway(config) {
  assert.match(config.container, /-ci$/, `this changes the instance's allow-list or file system, so it runs only in a throwaway; ${config.container} is not one`);
}

/** Run one allow-list helper inside the throwaway and require it to answer OK. */
export function allowList(config, call) {
  requireThrowaway(config);
  const output = runIris(config.container, [`Set sc=##class(${FIXTURE}).${call} Write "OCU-PATHSC-START:",$Select($System.Status.IsOK(sc):"ok",1:$System.Status.GetErrorText(sc)),":OCU-PATHSC-END",!`]);
  assert.equal(markerValue(output, 'PATHSC'), 'ok', `${call} answered: ${output}`);
}

/** One value the instance computes, read through a marker. */
export function instanceValue(config, expression) {
  const output = runIris(config.container, [`Write "OCU-PATHVAL-START:",${expression},":OCU-PATHVAL-END",!`]);
  const value = markerValue(output, 'PATHVAL');
  assert.ok(value, `${expression} answered: ${output}`);
  return value;
}

/** Make `directory` and require that it exists afterwards. */
export function makeDirectory(config, directory) {
  requireThrowaway(config);
  const output = runIris(config.container, [`Do ##class(%File).CreateDirectoryChain("${escapeOs(directory)}") Write "OCU-PATHDIR-START:",##class(%File).DirectoryExists("${escapeOs(directory)}"),":OCU-PATHDIR-END",!`]);
  assert.equal(markerValue(output, 'PATHDIR'), '1', `${directory} exists: ${output}`);
}

/** Remove `directory`, which a spec made, and require that it is gone. */
export function removeDirectory(config, directory) {
  requireThrowaway(config);
  const output = runIris(config.container, [`Do ##class(%File).RemoveDirectory("${escapeOs(directory)}") Write "OCU-PATHDIR-START:",##class(%File).DirectoryExists("${escapeOs(directory)}"),":OCU-PATHDIR-END",!`]);
  assert.equal(markerValue(output, 'PATHDIR'), '0', `${directory} is removed: ${output}`);
}

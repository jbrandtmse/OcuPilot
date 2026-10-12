import { test } from 'node:test';
import assert from 'node:assert/strict';
import { classifyLeftovers } from './ci-runner.mjs';

// Pins how the runner words the compile probe's leftovers, which ProbeApps.Existing() reports as
// `kind:name` tokens beside the probe web applications (Story 20.28, DW-2362).
//
// Mutation (Rule 19): word every added token as a web application again -> this goes red.
test('a surviving compile probe object is named as one, with the removal that clears it', () => {
  const problem = classifyLeftovers('X', { paths: ['/probeocupilot', 'namespace:OCUPROBE2028N', 'directory:ocuprobe2028d'], error: null }, { paths: [], error: null });
  assert.match(problem, /probe web application\(s\) survived the class's teardown -- \/probeocupilot\. Remove them with OcuPilot\.Test\.ProbeApps\.Remove\(\)/);
  assert.match(problem, /compile probe object\(s\) survived the class's teardown -- namespace:OCUPROBE2028N, directory:ocuprobe2028d\. Remove them with OcuPilot\.Test\.CompileWithoutInteropProbe\.RemoveAll\(\)/);
  assert.doesNotMatch(problem, /application\(s\) survived[^.]*OCUPROBE2028N/, 'a probe object is not called a web application');
});

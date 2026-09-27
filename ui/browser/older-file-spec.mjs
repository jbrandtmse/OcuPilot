/**
 * The older-messages-file fixture two browser specs share (Story 16.20): one rotated-looking file
 * written into the throwaway's manager directory and removed again. Named without the
 * `.browser-spec` suffix, so `npm run test:browser` does not collect it.
 *
 * The file carries three head-format lines at three severities, each naming `OLDER_MARKER`, so a
 * row, a search and a chip filter can all tell it from `messages.log`. Its name is one the
 * rotation pattern admits and no instance writes. Refuses anything but a `-ci` throwaway.
 */

import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';

import { LIVE_CONTAINER } from '../browser.config.mjs';

/** The seeded file's name. */
export const OLDER_FILE = 'messages.old_20000101_4243';

/** The text every seeded line carries. */
export const OLDER_MARKER = 'OcuPilotOlderFileSpec';

/** The seeded lines, oldest first: informational, warning, severe. */
export const OLDER_LINES = [
  `01/02/00-10:00:01:000 (4243) 0 [OcuPilot.OlderFileSpec] ${OLDER_MARKER} informational line`,
  `01/02/00-10:00:02:000 (4243) 1 [OcuPilot.OlderFileSpec] ${OLDER_MARKER} warning line`,
  `01/02/00-10:00:03:000 (4243) 2 [OcuPilot.OlderFileSpec] ${OLDER_MARKER} severe line`,
];

/** Where the manager directory is inside the throwaway image. */
const MANAGER_DIRECTORY = '/durable/iris/mgr/';

function refuseLive(container) {
  assert.notEqual(container, LIVE_CONTAINER, 'the older-file fixture writes into a manager directory, so it never runs against the live container');
  assert.match(container, /-ci$/, `the older-file fixture runs only in a throwaway; ${container} is not one`);
}

function exec(container, script) {
  return spawnSync('docker', ['exec', '-i', container, 'sh', '-c', script], { encoding: 'utf8', timeout: 60000 });
}

/** Write the fixture file into `container`'s manager directory, replacing any earlier copy. */
export function seedOlderFile(container) {
  refuseLive(container);
  const written = spawnSync('docker', ['exec', '-i', container, 'sh', '-c', `cat > ${MANAGER_DIRECTORY}${OLDER_FILE}`], {
    input: OLDER_LINES.join('\n') + '\n',
    encoding: 'utf8',
    timeout: 60000,
  });
  assert.equal(written.status, 0, `the older file was written: ${written.stderr ?? ''}`);
}

/** Remove the fixture file, and assert it is gone. */
export function removeOlderFile(container) {
  refuseLive(container);
  exec(container, `rm -f ${MANAGER_DIRECTORY}${OLDER_FILE}`);
  const left = exec(container, `test -e ${MANAGER_DIRECTORY}${OLDER_FILE} && echo present || echo absent`);
  assert.equal((left.stdout ?? '').trim(), 'absent', 'the older file was removed');
}

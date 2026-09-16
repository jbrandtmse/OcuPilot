/**
 * DW-217's server half: the npm licence notices reach a REAL running instance byte-equal to what
 * a real `npm run build` just produced.
 *
 * **What the other two tiers cannot prove between them.** `build-output.test.mjs` proves the
 * CLIENT half: `npm run build`'s own `postbuild` step copies `3rdpartylicenses.txt` into
 * `browser/`. `OcuPilot.Test.Static.TestLicenceNoticesAreServedAsPlainText` proves the SERVER
 * half: `StaticHandler` answers a `.txt` file as `text/plain`. Neither proves the two are wired
 * together -- the first never starts an instance, and the second serves a synthetic fixture
 * standing in for the file, never the real build's bytes (`src/OcuPilot/Test/Static.cls:31`).
 * The chain in between -- the container start path copying the real build's output to the
 * served root, on a real install -- had run only by hand, over a manual `curl`, on a throwaway.
 * This is that check, committed: it runs after a real `npm run build` (CI's `instance` job already
 * orders the two that way) and against a real installed throwaway, and reads the real build's
 * bytes off disk rather than trusting a second synthetic fixture. The throwaway installs through
 * the container start path, not IPM, so `module.xml`'s `<FileCopy>` stays pinned as text by
 * `ipm-manifest.test.mjs`.
 *
 * Mutation (Rule 19): overwrite the served file inside the instance -> the byte-equality assertion
 * goes red, naming the mismatch.
 *
 * Run: `npm run test:browser` (after `npm run build` and `sh scripts/ci-throwaway.sh up`).
 */

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import { LICENCE_PATH, browserConfig } from '../browser.config.mjs';

const config = browserConfig();
const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const builtLicencePath = join(uiRoot, 'dist', 'ocupilot-ui', 'browser', '3rdpartylicenses.txt');

test('DW-217: the running instance serves the licence notices as text/plain, byte-equal to the real build output', async () => {
  let built;
  try {
    built = readFileSync(builtLicencePath);
  } catch {
    assert.fail(
      `expected ${builtLicencePath} to exist -- run npm run build before npm run test:browser`
    );
  }
  assert.ok(built.length > 0, 'the real build produced a non-empty licence file to compare against');

  const response = await fetch(`${config.origin}${LICENCE_PATH}`);
  assert.equal(
    response.status,
    200,
    `expected 200 from ${config.origin}${LICENCE_PATH}, got ${response.status}`
  );

  const contentType = response.headers.get('content-type') ?? '';
  assert.match(
    contentType,
    /^text\/plain\b/,
    `expected a text/plain content type, got ${JSON.stringify(contentType)}`
  );

  const served = Buffer.from(await response.arrayBuffer());
  assert.ok(
    served.equals(built),
    'expected the served licence file to be byte-equal to the file this run\'s npm build just produced, ' +
      'not a stale copy from an earlier install and not the synthetic fixture Static.cls tests against'
  );
});

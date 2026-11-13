/**
 * The request body has one reader. `OcuPilot.Kernel.Utils.ReadRequestBody` parses the body and refuses a
 * value the instance cannot hold (`OversizedMember`); a route that read `%request.Content` or
 * `%request.GetMimeData` itself would iterate its own copy of the caller's data and answer 500 on a
 * number past the largest the instance holds, or on a string past its string limit.
 *
 * This test fails when either read appears in ObjectScript source outside `Kernel/Utils.cls`, test
 * classes excepted (they stand in for `%request`). It also fails when a class under `Area/` or
 * `Kernel/` calls `ReadRequestBody` without taking its field output, or takes it in a file that never
 * renders `RenderBodyRefusal`, so an oversized value is refused on its field rather than as a bad body.
 *
 * Mutations (Rule 19): add `Set tStream = %request.Content` to any class under `src/OcuPilot/Area` -> the
 * scan test goes red naming that file and line; change one Area caller back to
 * `ReadRequestBody(.tBody, .tStage)` -> the adoption test goes red naming that file and line.
 */

import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { dirname, join, relative, sep } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

const SOURCE_ROOT = join(REPO_ROOT, 'src', 'OcuPilot');

/** The one file allowed to read the request's body, as a path from `SOURCE_ROOT` with `/` separators. */
const READER = 'Kernel/Utils.cls';

/** The test classes' folder, as a path from `SOURCE_ROOT`. */
const TEST_FOLDER = 'Test';

/** The two reads of a request's body. */
const BODY_READS = /%request\.Content\b|GetMimeData\s*\(/;

/** The folders whose handlers answer a bad body, as paths from `SOURCE_ROOT`. */
const HANDLER_FOLDERS = ['Area/', 'Kernel/'];

/**
 * The callers that answer an unusable body with their own domain refusal (`RenderInput`), not the
 * field refusal, as paths from `SOURCE_ROOT`.
 */
const OWN_REFUSAL = new Set(['Area/Explorer/SqlConsole.cls', 'Area/Explorer/SqlData.cls', 'Area/Analytics/MdxQuery.cls']);

/** A call of the reader with all three arguments: the body, the stage and the field. */
const CALL_WITH_FIELD = /ReadRequestBody\(\.\w+, \.\w+, \.\w+\)/;

/** The ObjectScript files under `directory`, as paths from `SOURCE_ROOT` with `/` separators. */
function objectScriptFiles(directory) {
  const found = [];
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) {
      found.push(...objectScriptFiles(path));
    } else if (/\.(cls|inc|mac)$/.test(entry.name)) {
      found.push(relative(SOURCE_ROOT, path).split(sep).join('/'));
    }
  }
  return found;
}

/** The `path:line` of each line of `text` that reads a request's body. */
function bodyReads(path, text) {
  return text
    .split('\n')
    .map((line, index) => (BODY_READS.test(line) ? `${path}:${index + 1}` : ''))
    .filter(Boolean);
}

test('the scan names a line that reads the request body, and passes one that does not', () => {
  assert.deepEqual(bodyReads('Area/X.cls', '    Set tStream = %request.Content\n'), ['Area/X.cls:1']);
  assert.deepEqual(bodyReads('Area/X.cls', 'Do x\n    Set t = %request.GetMimeData("BODY")\n'), ['Area/X.cls:2']);
  assert.deepEqual(bodyReads('Area/X.cls', '    Set tSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tBody, .tStage, .tField)\n'), []);
});

test('only Kernel/Utils.cls reads the request body outside the test classes', () => {
  const files = objectScriptFiles(SOURCE_ROOT);
  assert.ok(files.length > 100, `the scan found the source tree (${files.length} files)`);
  assert.ok(files.includes(READER), `${READER} is in the scan`);
  const offenders = files
    .filter((path) => path !== READER && !path.startsWith(`${TEST_FOLDER}/`))
    .flatMap((path) => bodyReads(path, readFileSync(join(SOURCE_ROOT, path), 'utf8')));
  assert.deepEqual(offenders, [], 'read the body through OcuPilot.Kernel.Utils.ReadRequestBody, which refuses a value the instance cannot hold');
});

/** The `path:line` of each call of the reader in `text` that does not take the field output. */
function callsWithoutField(path, text) {
  return text
    .split('\n')
    .map((line, index) =>
      /ReadRequestBody\(/.test(line) && !/^\s*(\/\/\/|ClassMethod)/.test(line) && !CALL_WITH_FIELD.test(line) ? `${path}:${index + 1}` : '',
    )
    .filter(Boolean);
}

test('the adoption scan names a call that leaves the field out, and passes one that takes it', () => {
  assert.deepEqual(callsWithoutField('Area/X.cls', '    Set t = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tBody, .tStage)\n'), ['Area/X.cls:1']);
  assert.deepEqual(callsWithoutField('Area/X.cls', '    Set t = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.pBody, .tStage, .pField)\n'), []);
  assert.deepEqual(callsWithoutField('Area/X.cls', '/// <method>ReadRequestBody(.a, .b)</method>\n'), []);
});

test('every Area and Kernel caller of the reader takes the field and renders the field refusal', () => {
  const files = objectScriptFiles(SOURCE_ROOT).filter(
    (path) => path !== READER && HANDLER_FOLDERS.some((folder) => path.startsWith(folder)),
  );
  const missingField = [];
  const missingRender = [];
  let callers = 0;
  for (const path of files) {
    const text = readFileSync(join(SOURCE_ROOT, path), 'utf8');
    if (!/ReadRequestBody\(/.test(text)) continue;
    callers += 1;
    if (OWN_REFUSAL.has(path)) continue;
    missingField.push(...callsWithoutField(path, text));
    if (!/RenderBodyRefusal\(/.test(text)) missingRender.push(path);
  }
  assert.ok(callers > 20, `the scan found the callers (${callers})`);
  assert.deepEqual(missingField, [], 'pass the reader a third argument, the field it names');
  assert.deepEqual(missingRender, [], 'answer the field with OcuPilot.Api.Error.RenderBodyRefusal');
});

test('the reader still reads both sources, so the scan is aimed at a live pattern', () => {
  const reads = bodyReads(READER, readFileSync(join(SOURCE_ROOT, READER), 'utf8'));
  assert.ok(reads.length >= 2, `${READER} reads the body (${reads.join(', ')})`);
});

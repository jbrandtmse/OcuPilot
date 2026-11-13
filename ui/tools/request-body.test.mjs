/**
 * The request body has one reader. `OcuPilot.Kernel.Utils.ReadRequestBody` parses the body and refuses a
 * value the instance cannot hold (`OversizedMember`); a route that read `%request.Content`,
 * `%request.MimeData` or `%request.GetMimeData` itself would iterate its own copy of the caller's data and
 * answer 500 on a number past the largest the instance holds, or on a string past its string limit.
 *
 * This test fails when any of those reads appears in ObjectScript source outside `Kernel/Utils.cls`, test
 * classes excepted (they stand in for `%request`). It also fails, naming the file and line, at any site
 * under `Area/` or `Kernel/` that calls `ReadRequestBody` or a `Body()` wrapper without taking the field
 * output, or that takes it and does not hand that field to `RenderBodyRefusal` or `BadBody` on the lines
 * that answer the refusal, so an oversized value is refused on its field rather than as a bad body.
 *
 * Mutations (Rule 19): add `Set tStream = %request.Content` to any class under `src/OcuPilot/Area` -> the
 * scan test goes red naming that file and line; put one `If '..Body(` branch back to the `AGENT.BADBODY`
 * render, or call `..Body(.tBody)`, or `..BadBody()` -> the adoption test goes red naming that line.
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

/** The reads of a request's body. */
const BODY_READS = /%request\.(?:Content|MimeData)\b|(?:Get|Next)MimeData\s*\(/;

/** The folders whose handlers answer a bad body, as paths from `SOURCE_ROOT`. */
const HANDLER_FOLDERS = ['Area/', 'Kernel/'];

/**
 * The callers that answer an unusable body with their own domain refusal (`RenderInput`), not the
 * field refusal, as paths from `SOURCE_ROOT`.
 */
const OWN_REFUSAL = new Set(['Area/Explorer/SqlConsole.cls', 'Area/Explorer/SqlData.cls', 'Area/Analytics/MdxQuery.cls']);

/** A call of the reader; group 1 is the field output, when it is taken. */
const READER_CALL = /ReadRequestBody\(\.\w+, \.\w+(?:, \.(\w+))?\)/;

/** A call of a `Body()` wrapper; group 1 is the field output, when it is taken. */
const WRAPPER_CALL = /\.\.Body\(\.\w+(?:, \.(\w+))?\)/;

/** How many lines after a call its refusal must be rendered on. */
const REFUSAL_WINDOW = 4;

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
  assert.deepEqual(bodyReads('Area/X.cls', '    Set t = %request.MimeData("BODY", 1)\n'), ['Area/X.cls:1']);
  assert.deepEqual(bodyReads('Area/X.cls', '    Set k = %request.NextMimeData(k)\n'), ['Area/X.cls:1']);
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

/**
 * The `path:line why` of each body-reading site in `text` that does not refuse on the field: a call of
 * the reader or of a `Body()` wrapper that leaves the field out, or one whose next `REFUSAL_WINDOW` lines
 * do not hand that field to `RenderBodyRefusal` or `BadBody`. A reader call inside a `Body()` wrapper is
 * answered at the wrapper's call sites, so it needs the field only.
 */
function siteProblems(path, text) {
  const lines = text.split('\n');
  const problems = [];
  let method = '';
  lines.forEach((line, index) => {
    const declared = /^(?:Class)?Method (\w+)\(/.exec(line);
    if (declared) {
      method = declared[1];
      return;
    }
    if (/^\s*\/\/\//.test(line)) return;
    const where = `${path}:${index + 1}`;
    let call = null;
    let answeredHere = true;
    if (/ReadRequestBody\(/.test(line)) {
      call = READER_CALL.exec(line);
      answeredHere = method !== 'Body';
    } else if (/\.\.Body\(/.test(line)) {
      call = WRAPPER_CALL.exec(line);
    } else {
      return;
    }
    if (call === null || call[1] === undefined) {
      problems.push(`${where} takes no field output`);
      return;
    }
    if (!answeredHere) return;
    const refusal = new RegExp(`(?:RenderBodyRefusal|\\.\\.BadBody)\\(${call[1]}\\)`);
    if (!lines.slice(index + 1, index + 1 + REFUSAL_WINDOW).some((next) => refusal.test(next))) {
      problems.push(`${where} does not refuse on ${call[1]}`);
    }
  });
  return problems;
}

test('the adoption scan names a site that drops the field, and passes one that refuses on it', () => {
  const reader = '    Set t = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tBody, .tStage';
  const refusal = '        Set tSC = ##class(OcuPilot.Api.Error).RenderBodyRefusal(tBodyField)\n';
  const old = '        Set tSC = ##class(OcuPilot.Api.Error).Render(400, x, y, z)\n';
  assert.deepEqual(siteProblems('Area/X.cls', `${reader})\n`), ['Area/X.cls:1 takes no field output']);
  assert.deepEqual(siteProblems('Area/X.cls', `${reader}, .tBodyField)\n    If $$$ISERR(tReadSC) {\n${refusal}`), []);
  assert.deepEqual(siteProblems('Area/X.cls', `${reader}, .tBodyField)\n    If $$$ISERR(tReadSC) {\n${old}`), ['Area/X.cls:1 does not refuse on tBodyField']);
  assert.deepEqual(siteProblems('Area/X.cls', `ClassMethod Body(Output pBody, Output pField) As %Boolean\n{\n${reader}, .pField)\n`), []);
  assert.deepEqual(siteProblems('Area/X.cls', `    If '..Body(.tBody) {\n${refusal}`), ['Area/X.cls:1 takes no field output']);
  assert.deepEqual(siteProblems('Area/X.cls', `    If '..Body(.tBody, .tBodyField) {\n${old}`), ['Area/X.cls:1 does not refuse on tBodyField']);
  assert.deepEqual(siteProblems('Area/X.cls', `    If '..Body(.tBody, .tBodyField) {\n        Set tSC = ..BadBody()\n`), ['Area/X.cls:1 does not refuse on tBodyField']);
  assert.deepEqual(siteProblems('Area/X.cls', `    If '..Body(.tBody, .tBodyField) {\n        Set tSC = ..BadBody(tBodyField)\n`), []);
  assert.deepEqual(siteProblems('Area/X.cls', '/// <method>ReadRequestBody(.a, .b)</method> and <method>..Body(.a)</method>\n'), []);
});

test('every Area and Kernel site that reads the body refuses on the field it names', () => {
  const files = objectScriptFiles(SOURCE_ROOT).filter(
    (path) => path !== READER && HANDLER_FOLDERS.some((folder) => path.startsWith(folder)),
  );
  const problems = [];
  const missingRender = [];
  let callers = 0;
  let sites = 0;
  for (const path of files) {
    const text = readFileSync(join(SOURCE_ROOT, path), 'utf8');
    if (!/ReadRequestBody\(/.test(text)) continue;
    callers += 1;
    if (OWN_REFUSAL.has(path)) continue;
    sites += text.split('\n').filter((line) => /ReadRequestBody\(|\.\.Body\(/.test(line) && !/^\s*(\/\/\/|(?:Class)?Method )/.test(line)).length;
    problems.push(...siteProblems(path, text));
    if (!/RenderBodyRefusal\(/.test(text)) missingRender.push(path);
  }
  assert.ok(callers > 20, `the scan found the callers (${callers})`);
  assert.ok(sites > callers, `the scan found the call sites (${sites})`);
  assert.deepEqual(problems, [], 'take the field output and answer it with OcuPilot.Api.Error.RenderBodyRefusal (or BadBody)');
  assert.deepEqual(missingRender, [], 'answer the field with OcuPilot.Api.Error.RenderBodyRefusal');
});

test('the reader still reads both sources, so the scan is aimed at a live pattern', () => {
  const reads = bodyReads(READER, readFileSync(join(SOURCE_ROOT, READER), 'utf8'));
  assert.ok(reads.length >= 2, `${READER} reads the body (${reads.join(', ')})`);
});

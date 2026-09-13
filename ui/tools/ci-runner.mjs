#!/usr/bin/env node
/**
 * The serialized ObjectScript test runner CI's instance job calls (Story 1.17, DW-54).
 *
 * **One test class at a time, and the next starts only once the last has landed.** The suite's
 * classes share one instance and one set of fixtures: several install and uninstall the same
 * probe profile, database, applications and version rows. On 2026-09-11 eighteen classes were
 * started together; runs 539-556 overlapped over thirty seconds, a probe `Uninstall` in one
 * class raced a probe `Install` in another, and the probe database's directory was left deleted
 * but still mounted -- `SYS.Database` reading `Mounted` 1 with no directory, no `IRIS.DAT` and
 * no configuration entry, which neither a dismount nor a delete could clear. Seven classes
 * could not run on the development instance until a human restarted it.
 *
 * **A returned call is not a landed run**, which is why "await the call" is not the rule on its
 * own. A client-side timeout returns while the run keeps going server-side. Each class is
 * therefore confirmed against the instance's own result global -- the run index, its method
 * count and its failure count -- before the next one starts, and a class that reported nothing,
 * did not land, or ran zero methods is a failure rather than a silent pass.
 *
 * **What actually enforces the serialization, and what only checks it.** This process drives
 * `spawnSync`, so its own runs cannot overlap by construction — `overlappingRuns` over this
 * runner's wall-clock brackets is a property of the loop, not a discovery about it, and it is
 * kept as a cheap regression guard for the day the loop stops being synchronous. The check that
 * can actually fail is the one over the instance's own result indices: `%UnitTest.Manager`
 * allocates a new index per run, so if ANOTHER process ran tests against the same instance
 * while this job was going, the indices this job saw will not be consecutive. That is the real
 * hazard DW-54 names — the suite's classes share one instance and one set of fixtures — and it
 * is a hazard this process cannot create on its own.
 *
 * **Why the session itself is a shell script.** `scripts/ci-unit-test.sh` is the primitive that
 * reaches the instance; this file is the serializer. Every other `iris session` in this
 * repository is a shell script under `scripts/` for the same reason, and the split keeps the
 * vendor's unit-test root global -- which `scripts/check-objectscript.py` carries on its
 * inherited rename-checklist token list -- out of the tree that checker scans, rather than
 * smuggled past the guard by assembling the name at runtime.
 *
 * Usage:
 *   node tools/ci-runner.mjs --container <name> [--namespace NS] [--package OcuPilot.Test]
 *   node tools/ci-runner.mjs --container <name> --class OcuPilot.Test.Wire --class ...
 *
 * Exit 0 only when at least one class ran, every class landed and asserted something, none
 * overlapped, and no test failed.
 */

import { spawnSync } from 'node:child_process';
import { readdirSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

/** The primitive this runner drives, once per class. */
export const SESSION_SCRIPT = join(REPO_ROOT, 'scripts', 'ci-unit-test.sh');

/** The package whose classes are run when no explicit `--class` is given. */
export const DEFAULT_PACKAGE = 'OcuPilot.Test';

/** The install namespace, unless `--namespace` names another. */
export const DEFAULT_NAMESPACE = 'HSCUSTOM';

/**
 * The run indices that are not consecutive with the one before them (DW-54).
 *
 * `%UnitTest.Manager` allocates one result index per run, so a job that ran N classes back to
 * back sees N consecutive indices. A gap means some OTHER process allocated one in between —
 * another agent, another terminal, a second CI job against the same instance — which is exactly
 * the concurrent-writer hazard DW-54 exists for, and the only form of it this runner can detect.
 * Pure, so `ci.test.mjs` can drive it over sequences a real run cannot be made to produce.
 */
export function nonConsecutiveRuns(runs) {
  const gaps = [];
  for (let i = 1; i < runs.length; i += 1) {
    const previous = runs[i - 1];
    const current = runs[i];
    if (previous.runIndex === null || current.runIndex === null) continue;
    if (current.runIndex !== previous.runIndex + 1) {
      gaps.push(`${previous.name} (run ${previous.runIndex}) then ${current.name} (run ${current.runIndex})`);
    }
  }
  return gaps;
}

/**
 * Whether any two runs in `runs` overlap in wall-clock time (DW-54).
 *
 * Pure, and exported so `ci.test.mjs` can drive it over sequences this runner cannot be made to
 * produce on purpose. Each run is `{name, startedAt, finishedAt}` in milliseconds. Every pair is
 * compared rather than each run against the one before it: a bug that started three at once is
 * as much an overlap as one that started two, and only a pairwise comparison reports all of it.
 *
 * Touching is not overlapping. One class's run finishing at the same millisecond the next one
 * starts is the serialization working, not failing, so the comparison is strict on both sides.
 */
export function overlappingRuns(runs) {
  const overlaps = [];
  for (let i = 0; i < runs.length; i += 1) {
    for (let j = i + 1; j < runs.length; j += 1) {
      const a = runs[i];
      const b = runs[j];
      if (a.startedAt < b.finishedAt && b.startedAt < a.finishedAt) {
        overlaps.push(`${a.name} and ${b.name}`);
      }
    }
  }
  return overlaps;
}

/**
 * The marker a completed run writes, parsed into its five fields, or `null` when the session
 * produced none -- which is not the same as a failed run and is reported as its own outcome.
 */
export function parseRunMarker(text) {
  const match = /OCUPILOT-RUN-START:(\d*):(\d+):(\d+):(\d):(\d):OCUPILOT-RUN-END/.exec(
    String(text).replace(/[\r\n]+/g, ' ')
  );
  if (match === null) return null;
  return {
    runIndex: match[1] === '' ? null : Number(match[1]),
    total: Number(match[2]),
    failed: Number(match[3]),
    landed: match[4] === '1',
    runOk: match[5] === '1',
  };
}

/** The class names a `--list` session reported, or `null` when it produced no marker. */
export function parseListMarker(text) {
  const match = /OCUPILOT-LIST-START:(.*):OCUPILOT-LIST-END/.exec(
    String(text).replace(/[\r\n]+/g, ' ')
  );
  if (match === null) return null;
  return match[1].split(',').filter((name) => name !== '');
}

/**
 * What one class's run means: `{outcome, problem}`. Pure, so every branch is assertable without
 * an instance.
 *
 * Four failing outcomes, deliberately distinct. "No marker" and "did not land" are not failures
 * of the tests; they are failures to learn anything about them, and a runner that folded either
 * into "passed" would be the vacuous gate this story exists to remove. "Ran zero methods" is the
 * same defect one layer along: a class that asserts nothing cannot have found anything wrong.
 */
export function classifyRun(className, marker) {
  if (marker === null) {
    return {
      outcome: 'no-marker',
      problem: `${className}: the session reported no result marker, so nothing is known about the run -- which is a failure, never a pass`,
    };
  }
  if (marker.runOk === false) {
    return {
      outcome: 'refused',
      problem: `${className}: the test manager refused the run, so nothing was executed -- which is a failure, never a pass`,
    };
  }
  if (!marker.landed) {
    return {
      outcome: 'not-landed',
      problem: `${className}: this run recorded no new result in the instance's result global, so nothing confirms IT finished -- the highest index there belongs to an earlier class`,
    };
  }
  if (marker.total === 0) {
    return {
      outcome: 'empty',
      problem: `${className}: ran 0 test methods; a class that asserts nothing is a failure, never a pass`,
    };
  }
  if (marker.failed > 0) {
    return {
      outcome: 'failed',
      problem: `${className}: ${marker.failed} of ${marker.total} test(s) failed (run ${marker.runIndex})`,
    };
  }
  return { outcome: 'passed', problem: null };
}

/**
 * The test classes the CHECKOUT carries: every `.cls` under `src/OcuPilot/Test/` whose own
 * `Extends` clause names a `TestCase` and which declares at least one `Test*` method.
 *
 * **It is a FLOOR, not the same population.** The discovery query reads `PrimarySuper`, which is
 * the whole chain, while this reads the direct `Extends` clause only — so a class reaching
 * `TestCase` through a project base class is offered by the instance and invisible here. That
 * direction is safe by construction: `main()` only reports classes on disk the instance did NOT
 * offer, so a wider instance list passes and a narrowed one is caught, which is the failure this
 * exists for. Widen the matcher the day such a base class appears.
 *
 * **Why a second source.** "More than zero classes" was the only floor on discovery, so a query
 * that silently narrowed — a wrong superclass column, a renamed package, a failed compile of
 * half the tree — produced a green job over a handful of classes and nothing said so. A gate
 * that reports the size of what it looked at has to compare that size with something; this is
 * the something. Exported so `ci.test.mjs` can drive it.
 */
export function testClassesOnDisk(repoRoot = REPO_ROOT, pkg = DEFAULT_PACKAGE) {
  const dir = join(repoRoot, 'src', 'OcuPilot', 'Test');
  const names = [];
  const walk = (current, prefix) => {
    for (const entry of readdirSync(current, { withFileTypes: true })) {
      const full = join(current, entry.name);
      if (entry.isDirectory()) {
        walk(full, `${prefix}${entry.name}.`);
        continue;
      }
      if (!entry.name.endsWith('.cls')) continue;
      const text = readFileSync(full, 'utf8');
      if (!/Extends\s+[^\n{]*TestCase/.test(text)) continue;
      if (!/^(?:Class)?Method\s+Test/m.test(text)) continue;
      if (/^Class\s+\S+\s+Extends[^\n]*\[\s*Abstract/m.test(text)) continue;
      names.push(`${prefix}${entry.name.slice(0, -'.cls'.length)}`);
    }
  };
  walk(dir, `${pkg}.`);
  return names.sort();
}

/** The argument vector that runs one class through the session primitive. */
export function runArgs({ container, namespace, className }) {
  return [SESSION_SCRIPT, '--container', container, '--namespace', namespace, '--class', className];
}

/** The argument vector that lists the classes there are to run. */
export function listArgs({ container, namespace, pkg }) {
  return [SESSION_SCRIPT, '--container', container, '--namespace', namespace, '--list', '--package', pkg];
}

export function parseArgs(argv) {
  const options = {
    container: '',
    namespace: DEFAULT_NAMESPACE,
    pkg: DEFAULT_PACKAGE,
    classes: [],
  };
  for (let i = 0; i < argv.length; i += 1) {
    const flag = argv[i];
    const value = argv[i + 1];
    // A trailing flag with no value assigned `undefined`, which passed the required-argument
    // check below and reached `spawnSync` as a TypeError instead of a usage refusal.
    if (value === undefined) throw new Error(`ci-runner: ${flag} needs a value`);
    if (flag === '--container') { options.container = value; i += 1; continue; }
    if (flag === '--namespace') { options.namespace = value; i += 1; continue; }
    if (flag === '--package') { options.pkg = value; i += 1; continue; }
    if (flag === '--class') { options.classes.push(value); i += 1; continue; }
    throw new Error(`ci-runner: unknown argument ${flag}`);
  }
  if (options.container === '') throw new Error('ci-runner: --container is required');
  return options;
}

function shell(args) {
  return spawnSync('sh', args, { encoding: 'utf8' });
}

function main() {
  let options;
  try {
    options = parseArgs(process.argv.slice(2));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 2;
    return;
  }

  let classes = options.classes;
  if (classes.length === 0) {
    const listed = shell(listArgs(options));
    const parsed = parseListMarker(`${listed.stdout ?? ''}\n${listed.stderr ?? ''}`);
    if (parsed === null) {
      console.error(`ci-runner: could not list the test classes in ${options.pkg}`);
      console.error(String(listed.stdout ?? '').split('\n').slice(-20).join('\n'));
      process.exitCode = 1;
      return;
    }
    classes = parsed;
  }

  // A run over no class at all is a failure, not a pass: a gate that reports "nothing wrong"
  // when it looked at nothing is the failure mode this whole story exists to remove.
  if (classes.length === 0) {
    console.error(`ci-runner: found no test class under ${options.pkg}; a run over no class is a failure, never a pass`);
    process.exitCode = 1;
    return;
  }

  // ...and a run over SOME of them is the same failure, quieter. The checkout says which classes
  // exist; discovery says which the instance found. A class on disk that the instance did not
  // offer means the tree did not compile, or the query no longer selects it.
  if (options.classes.length === 0) {
    const onDisk = testClassesOnDisk(REPO_ROOT, options.pkg);
    const discovered = new Set(classes);
    const missing = onDisk.filter((name) => !discovered.has(name));
    console.log(`ci-runner: the checkout carries ${onDisk.length} test class(es); the instance offered ${classes.length}`);
    if (missing.length > 0) {
      console.error(
        `ci-runner: the instance did not offer ${missing.length} test class(es) the checkout carries -- ${missing.join(', ')}. A suite that ran a subset is a failure, never a pass`
      );
      process.exitCode = 1;
      return;
    }
  }

  console.log(`ci-runner: running ${classes.length} test class(es), one at a time (DW-54)`);
  const runs = [];
  const problems = [];
  let total = 0;
  let failed = 0;

  for (const className of classes) {
    const startedAt = Date.now();
    const result = shell(runArgs({ ...options, className }));
    const finishedAt = Date.now();
    runs.push({ name: className, startedAt, finishedAt });

    const marker = parseRunMarker(`${result.stdout ?? ''}\n${result.stderr ?? ''}`);
    runs[runs.length - 1].runIndex = marker === null ? null : marker.runIndex;
    const verdict = classifyRun(className, marker);
    if (verdict.problem !== null) problems.push(verdict.problem);
    if (marker !== null && marker.landed) {
      total += marker.total;
      failed += marker.failed;
    }
    const label = verdict.outcome === 'passed' ? 'ok' : verdict.outcome.toUpperCase();
    const counts = marker === null ? '' : ` -- ${marker.total} test(s), ${marker.failed} failed, run ${marker.runIndex}`;
    console.log(`  ${label.padEnd(11)}${className}${counts}`);
    if (verdict.outcome !== 'passed') {
      console.log(
        String(result.stdout ?? '')
          .split('\n')
          .slice(-15)
          .map((line) => `      | ${line}`)
          .join('\n')
      );
    }
  }

  // DW-54. Two checks, and only the second can fail while the loop is synchronous: the first
  // guards the loop's own shape, the second detects a writer that is not this process.
  const overlaps = overlappingRuns(runs);
  for (const overlap of overlaps) {
    problems.push(
      `${overlap} overlapped in wall-clock time -- the suite's classes share one instance and one set of fixtures (DW-54)`
    );
  }
  const gaps = nonConsecutiveRuns(runs);
  for (const gap of gaps) {
    problems.push(
      `another process recorded a test run against this instance between ${gap} -- the suite's classes share one instance and one set of fixtures, so a concurrent run makes every result here suspect (DW-54)`
    );
  }

  console.log(
    `ci-runner: ${classes.length} class(es), ${total} test(s), ${failed} failed, ${overlaps.length} overlap(s), ${gaps.length} foreign run(s)`
  );
  if (problems.length > 0) {
    console.error('ci-runner: found problems --');
    for (const problem of problems) console.error(`  ${problem}`);
    process.exitCode = 1;
    return;
  }
  console.log('ci-runner: green.');
}

if (process.argv[1] && process.argv[1].endsWith('ci-runner.mjs')) {
  main();
}

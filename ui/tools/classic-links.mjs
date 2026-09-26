#!/usr/bin/env node
/**
 * The classic link-out check (FR-9, AD-44): a list archetype never links out, a detail view
 * may and only where its descriptor declares `classicLinkExemption` with a reason, and **every
 * exemption honored is reported** so the count is visible rather than silent.
 *
 * It follows `client-lint.mjs`'s shape -- pure predicates, a thin `main()` doing the impure
 * work, the `pathToFileURL` direct-invocation guard -- and is wired into `prebuild`,
 * `prestart` (`ui/package.json`) and `.githooks/pre-commit`, so a malformed exemption fails the
 * build and the commit rather than reaching a rendered card.
 *
 * **It reports on every run, clean or not.** A checker that exits 0 silently cannot be told
 * apart from a checker that looked at nothing, which is the failure the acceptance criterion
 * names. Every run prints the scanned descriptor count, the per-link-out-class tally, one line
 * per descriptor declaring an honored exemption, and the stable count line
 * `classic-links: N exemption(s) honored (SM-C1)` -- durable and greppable, since SM-C1 is
 * expanded in no planning artifact and there is no register to write into. N counts exemptions,
 * not declarations: descriptors declaring the same reason declare one exemption (AD-44), and a
 * classified run prints how many descriptors declare them beside it.
 *
 * **The population is asserted three ways, and only one of them is a second look at the same
 * directory.** (1) Descriptors are read through `screen-mirror.mjs`'s `readSources()` over the
 * same `descriptorDir` this check reports on, and it throws naming the `.cls` file rather than
 * skipping one it cannot parse, so a shortfall cannot be silent. (2) `src/OcuPilot/` is scanned
 * for classes in the descriptor *package* that live outside `DESCRIPTOR_DIR`, keyed the way
 * `Registry.Descriptors` is keyed rather than the way this file walk is -- the only one of the
 * three that can see a descriptor the directory walk cannot. (3) The classified count and the
 * `.cls` count are compared for equality; both come from the same directory with the same
 * filter unless a caller injects `screens`, so that one catches an injected population that
 * never came from `descriptorDir`, and a `BASE_FILE` drift between this module and the
 * generator -- not a descriptor missing from the tree.
 *
 * **An unreadable vocabulary is reported, never read as an empty set.** `parseArchetypes`
 * answers `null` rather than `[]` for that reason, and this refuses on `null`
 * (`scripts/check-objectscript.py` `:663-668` states the rule).
 *
 * Usage: `node tools/classic-links.mjs`. Exit 1 on any refusal, 0 otherwise.
 */

import { readdirSync, readFileSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, isAbsolute, join, relative, resolve } from 'node:path';

import {
  ARCHETYPE_SOURCE,
  DESCRIPTOR_DIR,
  parseArchetypes,
  readSources,
} from './screen-mirror.mjs';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

/** Every project ObjectScript source lives here, so this is the scan root for (2) above. */
export const SOURCE_ROOT = join(REPO_ROOT, 'src', 'OcuPilot');

/** The abstract base lives in the descriptor package and declares no screen. */
export const BASE_FILE = 'Base.cls';

/** A class declared in the descriptor package, matched the way the registry matches it. */
const DESCRIPTOR_CLASS_RE = /^Class\s+OcuPilot\.Screen\.Descriptor\.[A-Za-z0-9.]/m;

/** The link-out class that may declare an exemption. The other two never may (AD-44). */
export const LINK_OUT_DETAIL = 'detail';

/**
 * A root-relative same-origin path: one leading `/`, then only the characters a URL path,
 * query and fragment are spelled with. A scheme's `://`, a backslash and any whitespace are
 * outside the class, so `https://elsewhere/x` and `/\evil` are refused by it; `//host/x` and
 * `../x` are refused by the two explicit checks in `hrefProblem`.
 */
const ROOT_RELATIVE_RE = /^\/[A-Za-z0-9._~%!$&'()*+,;=:@/?#-]*$/;

/**
 * What is wrong with an exemption's declared href, or `null` when nothing is. A descriptor is
 * not an egress primitive (AD-47): the target is a path on this instance or it is not a value.
 */
export function hrefProblem(href) {
  if (typeof href !== 'string' || href === '') {
    return 'declares exempt with no href, and no URL is ever derived from classicPage (AD-44)';
  }
  if (href.startsWith('//')) {
    return `href "${href}" is protocol-relative, which names another origin (AD-47)`;
  }
  if (href.includes('..')) {
    return `href "${href}" traverses, and a descriptor is not an egress primitive (AD-47)`;
  }
  if (!ROOT_RELATIVE_RE.test(href)) {
    return `href "${href}" is not a root-relative same-origin path (AD-47)`;
  }
  return null;
}

/**
 * What is wrong with one descriptor's archetype and classic link-out declaration, or `null`
 * when nothing is.
 *
 * `OcuPilot.Screen.Registry.ClassicLinkProblem` returns the same sentence for every case in
 * `OcuPilot.Test.ClassicLinkCorpus`, so a malformed declaration fails a developer's build with the
 * words the instance would use. `linkOutFor` is the vocabulary as a lookup; an archetype it does
 * not hold is refused outright, so a mis-classification fails closed. A declared
 * `classicLinkExemption.exempt` that is not a JSON boolean is refused, and an absent one reads as
 * false.
 */
export function classicLinkProblem(declaration, linkOutFor) {
  const archetype = declaration.archetype ?? '';
  const declared = declaration.classicLinkExemption;
  const exemption = declared !== null && typeof declared === 'object' && !Array.isArray(declared) ? declared : {};
  const reason = exemption.reason ?? '';
  const label = exemption.label ?? '';
  const href = exemption.href ?? '';
  const classicPage = declaration.classicPage ?? '';

  if (!linkOutFor.has(archetype)) {
    return `archetype "${archetype}" is not one OcuPilot.Screen.Archetype declares (AD-44)`;
  }
  if ('exempt' in exemption && typeof exemption.exempt !== 'boolean') {
    return 'classicLinkExemption.exempt is not a JSON boolean; declare true or false (AD-44)';
  }
  const exempt = exemption.exempt === true;
  const hasRowLink = exemption.rowLink !== undefined && exemption.rowLink !== null;
  if (!exempt) {
    if (href !== '') {
      return 'classicLinkExemption declares an href while exempt is false; link parts without an exemption are a half-made declaration';
    }
    if (label !== '') {
      return 'classicLinkExemption declares a label while exempt is false; link parts without an exemption are a half-made declaration';
    }
    if (hasRowLink) {
      return 'classicLinkExemption declares a rowLink while exempt is false; link parts without an exemption are a half-made declaration';
    }
    return null;
  }
  if (linkOutFor.get(archetype) !== LINK_OUT_DETAIL) {
    return `archetype "${archetype}" declares a classicLinkExemption, and only a detail archetype may (AD-44)`;
  }
  if (reason === '') {
    return 'classicLinkExemption declares exempt with no reason, and the check reports the reason of every exemption it honors (AD-44)';
  }
  if (classicPage === '') {
    return 'classicLinkExemption declares exempt while classicPage is empty; a screen with no classic equivalent has nothing to link out to';
  }
  if (label === '') {
    return "classicLinkExemption declares exempt with no label, and the card's action names the classic page it opens";
  }
  const bad = hrefProblem(href);
  if (bad !== null) return `classicLinkExemption ${bad}`;
  return hasRowLink ? rowLinkProblem(declaration, exemption) : null;
}

/** Whether `value` is a JSON object: not `null` and not an array. */
function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

/** A declared value as the refusal sentences spell it: `''` for an absent or `null` one. */
function shown(value) {
  return value === undefined || value === null ? '' : String(value);
}

/**
 * What is wrong with a complete exemption's declared `rowLink`, or `null` (AD-44, AD-47).
 *
 * A row link turns each row's name cell into the exemption's `href` with the declared params appended
 * from that row, so it is declared only on a screen with a read. It is an object carrying only
 * `params`, an array of objects carrying only `name` (a query parameter name, declared once) and
 * `field` (one of `read.fields`, never one of `context.secretFields`).
 * `OcuPilot.Screen.Registry.RowLinkProblem` returns the same sentence for every case in
 * `OcuPilot.Test.ClassicLinkCorpus`.
 */
export function rowLinkProblem(declaration, exemption) {
  const where = 'classicLinkExemption.rowLink';
  if (!isObject(declaration.read)) {
    return `${where} is declared on a screen with no read, and a row link reads its values from the read's rows (AD-44)`;
  }
  const { rowLink } = exemption;
  if (!isObject(rowLink)) return `${where} is not an object declaring its params (AD-44)`;
  const unknown = Object.keys(rowLink).find((key) => key !== 'params');
  if (unknown !== undefined) return `${where} declares the unknown key '${unknown}'`;
  if (!Array.isArray(rowLink.params)) return `${where}.params is not an array of row link params`;
  const fields = Array.isArray(declaration.read.fields) ? declaration.read.fields : [];
  const secrets =
    isObject(declaration.context) && Array.isArray(declaration.context.secretFields)
      ? declaration.context.secretFields
      : [];
  const seen = [];
  for (let index = 0; index < rowLink.params.length; index += 1) {
    const param = rowLink.params[index];
    const at = `${where}.params entry #${index + 1}`;
    if (!isObject(param)) return `${at} is not an object declaring its name and field`;
    const extra = Object.keys(param).find((key) => key !== 'name' && key !== 'field');
    if (extra !== undefined) return `${at} declares the unknown key '${extra}'`;
    if (typeof param.name !== 'string' || !/^[A-Za-z][A-Za-z0-9]*$/.test(param.name)) {
      return `${at} name '${shown(param.name)}' is not a query parameter name`;
    }
    if (seen.includes(param.name)) return `${at} names the param '${param.name}' twice`;
    seen.push(param.name);
    if (typeof param.field !== 'string' || !fields.includes(param.field)) {
      return `${at} field '${shown(param.field)}' is not one of read.fields`;
    }
    if (secrets.includes(param.field)) {
      return `${at} field '${param.field}' is a secret field, and a secret never leaves the instance in a link (AD-35)`;
    }
  }
  return null;
}

/** The `.cls` files under `dir` that declare a screen -- everything but the abstract base. */
export function descriptorFileNames(dir) {
  return readdirSync(dir)
    .filter((entry) => entry.endsWith('.cls') && entry !== BASE_FILE)
    .sort();
}

/**
 * The sub-directories of `dir`, which this check refuses rather than walks.
 *
 * `OcuPilot.Screen.Registry.Descriptors` selects on `Name %STARTSWITH
 * 'OcuPilot.Screen.Descriptor.'`, so the instance enumerates a descriptor in a sub-package;
 * this reader and `readSources()` both list one directory level. A descriptor under
 * `Descriptor/Security/` would therefore be invisible to both population sources at once --
 * they would agree, and the shortfall refusal below would not fire. A check that agrees with
 * itself about a tree neither half looked at is the vacuous pass this whole module exists to
 * make impossible, so an unexpected directory is a refusal and not a walk: flattening it here
 * without the generator and the registry agreeing would put the three readers back out of step.
 */
export function descriptorSubdirectories(dir) {
  return readdirSync(dir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();
}

/**
 * Every `.cls` under `sourceRoot` that declares a class in the descriptor package but does not
 * live in `dir` -- the second population source, and the only one keyed the way the instance
 * is keyed.
 *
 * `OcuPilot.Screen.Registry.Descriptors` selects on the **class name**
 * (`Name %STARTSWITH 'OcuPilot.Screen.Descriptor.'`); `readSources()`, `descriptorFileNames()`
 * and `descriptorSubdirectories()` all select on the **file path**, and nothing ties the two
 * together. `scripts/check-objectscript.py`'s `check_package_placement` asserts only that a
 * class sits under one of the seven fixed packages, which `OcuPilot.Screen.Descriptor.Ssl`
 * declared in `src/OcuPilot/Screen/Ssl.cls` satisfies -- so that file is enumerated by the
 * instance and invisible to all three path-keyed readers at once. They would agree about a
 * tree none of them looked at, and the equality below would not fire: the vacuous pass this
 * module exists to make impossible. A misplaced descriptor is therefore a refusal, not a walk
 * -- flattening it here without the generator and the registry agreeing would put the three
 * readers back out of step.
 */
export function misplacedDescriptorClasses(sourceRoot, dir) {
  const home = resolve(dir);
  const found = [];
  const walk = (current) => {
    for (const entry of readdirSync(current, { withFileTypes: true })) {
      const full = join(current, entry.name);
      if (entry.isDirectory()) {
        walk(full);
        continue;
      }
      if (!entry.isFile() || !entry.name.endsWith('.cls')) continue;
      if (resolve(current) === home) continue;
      if (DESCRIPTOR_CLASS_RE.test(readFileSync(full, 'utf8'))) found.push(shortPath(full));
    }
  };
  walk(sourceRoot);
  return found.sort();
}

/**
 * One report line per early refusal, so a run that cannot classify anything still says what it
 * looked at and still emits the stable count line. A refusing run that printed nothing would be
 * indistinguishable from a run that looked at nothing, which is the defect the acceptance
 * criterion names -- and the criterion says "on every run, clean or not", not "on every run
 * that got as far as a population".
 *
 * The scanned count is printed in the same stable, greppable shape the classified path uses,
 * so a consumer reading `scanned N` off the output gets a number on every run rather than on
 * the runs that got far enough -- the criterion asks for the count, not for a sentence that
 * implies it.
 */
function refusedBeforeClassifying(report, what) {
  report.push('classic-links: scanned 0 descriptor(s)');
  report.push(`classic-links: refused before classifying any descriptor -- ${what}`);
  report.push('classic-links: 0 exemption(s) honored (SM-C1)');
}

/**
 * Runs the check and returns `{ok, report, problems, scanned, fileCount, honored, tally}`.
 *
 * `report` is what `main()` prints on every run, clean or not; `problems` is empty exactly
 * when `ok`. The sources are injectable so the whole matrix can be exercised over a synthetic
 * descriptor tree, and default to the real ones -- which is what a bare
 * `node tools/classic-links.mjs` checks. `sourceRoot` follows `descriptorDir`: the real run
 * scans all of `src/OcuPilot/` for misplaced descriptor classes, while a synthetic tree scans
 * itself, since scanning the repository against a temporary directory would call every real
 * descriptor misplaced.
 */
export function checkClassicLinks({
  descriptorDir = DESCRIPTOR_DIR,
  sourceRoot = descriptorDir === DESCRIPTOR_DIR ? SOURCE_ROOT : descriptorDir,
  archetypeSource = ARCHETYPE_SOURCE,
  screens,
} = {}) {
  const report = [];
  const problems = [];

  let vocabulary = null;
  try {
    vocabulary = parseArchetypes(readFileSync(archetypeSource, 'utf8'));
  } catch {
    vocabulary = null;
  }
  if (vocabulary === null) {
    // Reported, never treated as "no archetypes, therefore nothing to check": an empty set
    // would make every declared archetype unknown and an absent check would make every
    // declared archetype fine, and neither is a negative result.
    problems.push(
      `${shortPath(archetypeSource)}: the closed archetype vocabulary could not be read; ` +
        `an unreadable vocabulary is a refusal, never an empty set (AD-44)`
    );
    refusedBeforeClassifying(report, `the vocabulary at ${shortPath(archetypeSource)} is unreadable`);
    return { ok: false, report, problems, scanned: 0, fileCount: 0, honored: [], tally: new Map() };
  }
  const linkOutFor = new Map(vocabulary.map((archetype) => [archetype.key, archetype.linkOut]));

  let fileCount = 0;
  try {
    const nested = descriptorSubdirectories(descriptorDir);
    if (nested.length > 0) {
      problems.push(
        `${shortPath(descriptorDir)}: holds sub-director${nested.length === 1 ? 'y' : 'ies'} ` +
          `${nested.join(', ')}, which this check does not walk while the registry's ` +
          `%STARTSWITH query does; a descriptor there would be invisible to both population ` +
          `sources at once`
      );
      refusedBeforeClassifying(report, `${shortPath(descriptorDir)} holds a sub-directory`);
      return { ok: false, report, problems, scanned: 0, fileCount: 0, honored: [], tally: new Map() };
    }
    const misplaced = misplacedDescriptorClasses(sourceRoot, descriptorDir);
    if (misplaced.length > 0) {
      problems.push(
        `${misplaced.join(', ')}: declares a class in the OcuPilot.Screen.Descriptor package ` +
          `outside ${shortPath(descriptorDir)}. The registry enumerates it by class name and ` +
          `every reader here finds descriptors by path, so it would be invisible to all of ` +
          `them at once while the instance validates it (AD-5)`
      );
      refusedBeforeClassifying(report, `a descriptor class is declared outside ${shortPath(descriptorDir)}`);
      return { ok: false, report, problems, scanned: 0, fileCount: 0, honored: [], tally: new Map() };
    }
    fileCount = descriptorFileNames(descriptorDir).length;
  } catch (error) {
    problems.push(`${shortPath(descriptorDir)}: the descriptor directory could not be read -- ${error.message}`);
    refusedBeforeClassifying(report, `${shortPath(descriptorDir)} is unreadable`);
    return { ok: false, report, problems, scanned: 0, fileCount: 0, honored: [], tally: new Map() };
  }

  // `readSources()` throws naming the file rather than returning a shorter population, which
  // is the behaviour the second population assertion below relies on. Turning the throw into a
  // named refusal keeps the exit a clean 1 with a message rather than a stack trace.
  let population;
  try {
    population = screens ?? readSources({ descriptorDir }).screens;
  } catch (error) {
    problems.push(`the descriptor population could not be read -- ${error.message}`);
    refusedBeforeClassifying(report, `the population could not be read -- ${error.message}`);
    return { ok: false, report, problems, scanned: 0, fileCount, honored: [], tally: new Map() };
  }

  const tally = new Map();
  for (const archetype of vocabulary) {
    if (!tally.has(archetype.linkOut)) tally.set(archetype.linkOut, 0);
  }
  const honored = [];

  for (const screen of population) {
    const declaration = screen.declaration ?? {};
    const problem = classicLinkProblem(declaration, linkOutFor);
    if (problem !== null) {
      problems.push(`${screen.file}: ${problem}`);
      continue;
    }
    const linkOut = linkOutFor.get(declaration.archetype ?? '');
    tally.set(linkOut, (tally.get(linkOut) ?? 0) + 1);
    if (declaration.classicLinkExemption?.exempt === true) {
      honored.push({
        file: screen.file,
        archetype: declaration.archetype,
        reason: declaration.classicLinkExemption.reason,
        label: declaration.classicLinkExemption.label,
        href: declaration.classicLinkExemption.href,
      });
    }
  }

  const scanned = population.length;
  report.push(
    `classic-links: scanned ${scanned} descriptor(s) in ${shortPath(descriptorDir)}, ` +
      `against ${fileCount} .cls file(s) there less ${BASE_FILE}`
  );
  report.push(
    `classic-links: link-out class tally -- ` +
      [...tally.keys()].sort().map((key) => `${key} ${tally.get(key)}`).join(', ')
  );
  for (const entry of honored) {
    report.push(
      `classic-links: honored exemption -- ${entry.file} (archetype "${entry.archetype}"): ` +
        `${entry.reason}; label "${entry.label}"; href ${entry.href}`
    );
  }
  report.push(`classic-links: ${new Set(honored.map((entry) => entry.reason)).size} exemption(s) honored (SM-C1)`);
  report.push(`classic-links: ${honored.length} descriptor(s) declare them (AD-44)`);

  // The second assertion of the population, and it is an equality rather than a floor.
  // `readSources()` throws on a descriptor it cannot parse rather than skipping it, so fewer
  // means a `.cls` the reader never returned at all -- a check that classified less than the
  // tree has passed by looking at less than the tree. More is the same fault read from the
  // other end: the two sources are counting different directories, which is what an injected
  // `screens` from somewhere other than `descriptorDir` does, and a report naming a directory
  // the population never came from is worse than no report.
  if (scanned !== fileCount) {
    problems.push(
      `${shortPath(descriptorDir)}: classified ${scanned} descriptor(s) but the directory holds ` +
        `${fileCount} .cls file(s) less ${BASE_FILE}; the two population sources must agree, ` +
        `or the check is not looking at the tree it names`
    );
  }

  return { ok: problems.length === 0, report, problems, scanned, fileCount, honored, tally };
}

/**
 * A repository-relative path, so the report reads the same whether the check was run from
 * `ui/` or from the repository root. A path outside the repository -- a synthetic tree in a
 * temporary directory -- is reported as itself rather than as a run of `..` segments.
 */
function shortPath(target) {
  const fromRepoRoot = relative(REPO_ROOT, target).split('\\').join('/');
  if (fromRepoRoot === '' || fromRepoRoot.startsWith('..') || isAbsolute(fromRepoRoot)) return target;
  return fromRepoRoot;
}

function main() {
  const result = checkClassicLinks();
  for (const line of result.report) {
    console.log(line);
  }
  if (!result.ok) {
    console.error('classic-links: found violations --');
    for (const problem of result.problems) {
      console.error(`  ${problem}`);
    }
    console.error(`\nclassic-links: ${result.problems.length} violation(s)`);
    // `process.exitCode` rather than `process.exit(1)`: the report above is the point of this
    // check, and `process.exit` tears the process down without draining writes that are still
    // queued when stdout is a pipe -- which is what it is under the pre-commit hook and under
    // npm. A refusal that printed nothing is the failure mode this module is built around.
    process.exitCode = 1;
    return;
  }
  console.log('classic-links: clean.');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main();
}

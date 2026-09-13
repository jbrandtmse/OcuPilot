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
 * per honored exemption, and the stable count line
 * `classic-links: N exemption(s) honored (SM-C1)` -- durable and greppable, since SM-C1 is
 * expanded in no planning artifact and there is no register to write into.
 *
 * **The population is asserted twice.** Descriptors are read through `screen-mirror.mjs`'s
 * `readSources()`, which throws naming the file rather than skipping one it cannot parse; and
 * the `.cls` files under `DESCRIPTOR_DIR` are counted independently. A classified set smaller
 * than the file count is a refusal: the check cannot pass by looking at less than the tree.
 *
 * **An unreadable vocabulary is reported, never read as an empty set.** `parseArchetypes`
 * answers `null` rather than `[]` for that reason, and this refuses on `null`
 * (`scripts/check-objectscript.py` `:663-668` states the rule).
 *
 * Usage: `node tools/classic-links.mjs`. Exit 1 on any refusal, 0 otherwise.
 */

import { readdirSync, readFileSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { dirname, isAbsolute, join, relative } from 'node:path';

import {
  ARCHETYPE_SOURCE,
  DESCRIPTOR_DIR,
  parseArchetypes,
  readSources,
} from './screen-mirror.mjs';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

/** The abstract base lives in the descriptor package and declares no screen. */
export const BASE_FILE = 'Base.cls';

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
 * The same eight refusals `OcuPilot.Screen.Registry.ClassicLinkProblem` makes on the instance,
 * made here so a malformed declaration fails a developer's build rather than a container's
 * start. `linkOutFor` is the vocabulary as a lookup; an archetype it does not hold is refused
 * outright, so a mis-classification fails closed.
 */
export function classicLinkProblem(declaration, linkOutFor) {
  const archetype = declaration.archetype ?? '';
  const exemption = declaration.classicLinkExemption ?? {};
  const exempt = exemption.exempt === true;
  const reason = exemption.reason ?? '';
  const label = exemption.label ?? '';
  const href = exemption.href ?? '';
  const classicPage = declaration.classicPage ?? '';

  if (!linkOutFor.has(archetype)) {
    return `archetype "${archetype}" is not in src/OcuPilot/Screen/Archetype.cls (AD-44)`;
  }
  if (!exempt) {
    if (href !== '') {
      return 'classicLinkExemption declares an href while exempt is false; link parts without an exemption are a half-made declaration';
    }
    if (label !== '') {
      return 'classicLinkExemption declares a label while exempt is false; link parts without an exemption are a half-made declaration';
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
  return bad === null ? null : `classicLinkExemption ${bad}`;
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
 * One report line per early refusal, so a run that cannot classify anything still says what it
 * looked at and still emits the stable count line. A refusing run that printed nothing would be
 * indistinguishable from a run that looked at nothing, which is the defect the acceptance
 * criterion names -- and the criterion says "on every run, clean or not", not "on every run
 * that got as far as a population".
 */
function refusedBeforeClassifying(report, what) {
  report.push(`classic-links: refused before classifying any descriptor -- ${what}`);
  report.push('classic-links: 0 exemption(s) honored (SM-C1)');
}

/**
 * Runs the check and returns `{ok, report, problems, scanned, fileCount, honored, tally}`.
 *
 * `report` is what `main()` prints on every run, clean or not; `problems` is empty exactly
 * when `ok`. The three sources are injectable so the whole matrix can be exercised over a
 * synthetic descriptor tree, and default to the real ones -- which is what a bare
 * `node tools/classic-links.mjs` checks.
 */
export function checkClassicLinks({ descriptorDir = DESCRIPTOR_DIR, archetypeSource = ARCHETYPE_SOURCE, screens } = {}) {
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
    population = screens ?? readSources().screens;
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
  report.push(`classic-links: ${honored.length} exemption(s) honored (SM-C1)`);

  // The second assertion of the population, and it is an equality rather than a floor.
  // `readSources()` throws on a descriptor it cannot parse rather than skipping it, so fewer
  // means a `.cls` the reader never returned at all -- a check that classified less than the
  // tree has passed by looking at less than the tree. More is the same fault read from the
  // other end: the two sources are counting different directories, which is what an injected
  // `descriptorDir` with no `screens` beside it does, and a report naming a directory the
  // population never came from is worse than no report.
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
    process.exit(1);
    return;
  }
  console.log('classic-links: clean.');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main();
}

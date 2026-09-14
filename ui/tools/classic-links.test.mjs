import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import { ARCHETYPE_SOURCE, DESCRIPTOR_DIR, extractXData, parseArchetypes } from './screen-mirror.mjs';
import {
  BASE_FILE,
  SOURCE_ROOT,
  checkClassicLinks,
  classicLinkProblem,
  descriptorFileNames,
  misplacedDescriptorClasses,
} from './classic-links.mjs';

/**
 * The classic link-out check (FR-9, AD-44). Every row of the story's I/O matrix above the card
 * rows is here, over a synthetic descriptor tree so a refusal is demonstrated on a declaration
 * the shipped roster does not carry -- plus the real tree, which is the one population the
 * production invocation actually reads.
 *
 * Each pinning test's demonstrated mutation is recorded once, in the story spec's
 * `## Verification` section, and not repeated here.
 */

const here = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(here, '..', '..');
const CORPUS_SOURCE = join(REPO_ROOT, 'src', 'OcuPilot', 'Test', 'ClassicLinkCorpus.cls');

const VOCABULARY = new Map(
  parseArchetypes(readFileSync(ARCHETYPE_SOURCE, 'utf8')).map((a) => [a.key, a.linkOut])
);

/** A minimal declaration, so each case below states only the fields it is about. */
function declaration(overrides = {}) {
  return {
    archetype: 'detail',
    classicPage: 'OcuPilotTestClassicPage',
    classicLinkExemption: { exempt: false, reason: '', label: '', href: '' },
    ...overrides,
  };
}

/** An honored exemption: the flag, the reason, the page name and a same-origin path. */
function honoredExemption(overrides = {}) {
  return {
    exempt: true,
    reason: 'a detail view with no rebuilt equivalent yet',
    label: 'OcuPilot test classic page',
    href: '/csp/sys/OcuPilotTestClassicPage.csp',
    ...overrides,
  };
}

/**
 * A synthetic descriptor tree: one `.cls` file per named declaration, plus the abstract base
 * the reader skips. Returns the directory and the `screens` shape `readSources()` produces, so
 * the two population sources can be made to agree -- or, deliberately, to disagree.
 */
function syntheticTree(declarations) {
  const dir = mkdtempSync(join(tmpdir(), 'ocupilot-classic-links-'));
  writeFileSync(join(dir, BASE_FILE), 'Class OcuPilot.Screen.Descriptor.Base Extends %RegisteredObject\n{\n}\n');
  const screens = [];
  for (const [file, declared] of Object.entries(declarations)) {
    writeFileSync(join(dir, file), `Class OcuPilot.Screen.Descriptor.${file.replace('.cls', '')}\n{\n}\n`);
    screens.push({ file, className: `OcuPilot.Screen.Descriptor.${file.replace('.cls', '')}`, declaration: declared });
  }
  return { dir, screens };
}

function withTree(declarations, run) {
  const { dir, screens } = syntheticTree(declarations);
  try {
    return run({ dir, screens });
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

// --- The vocabulary itself ---------------------------------------------------------------

test('the archetype vocabulary is closed, classified, and holds every key EXPERIENCE.md publishes', () => {
  const archetypes = parseArchetypes(readFileSync(ARCHETYPE_SOURCE, 'utf8'));
  assert.ok(archetypes, 'the vocabulary parses');

  // The twelve state-matrix rows (EXPERIENCE.md `:507-521`), with the form row's three keys
  // counted separately, plus the two its prose names beside the table. Pinned as a literal set:
  // comparing the parsed keys with themselves would restate the parser and could not fail.
  assert.deepEqual(
    archetypes.map((a) => a.key).sort(),
    [
      'detail',
      'dialog',
      'drill-down',
      'external',
      'form-page',
      'form-page (tabs)',
      'home',
      'list',
      'list (server criteria)',
      'list (two views)',
      'log-viewer',
      'meters',
      'panel',
      'shell',
      'viewer (OpenAPI)',
      'wizard',
    ],
    'sixteen keys: the twelve matrix rows (the form row holding three) plus shell and external'
  );

  // Only `detail` may link out, and the default for everything else is refusal -- which is what
  // makes a mis-classification fail closed.
  const mayLinkOut = archetypes.filter((a) => a.linkOut === 'detail').map((a) => a.key).sort();
  assert.deepEqual(mayLinkOut, ['detail', 'form-page', 'form-page (tabs)', 'wizard']);
  assert.deepEqual(
    new Set(archetypes.map((a) => a.linkOut)),
    new Set(['list', 'detail', 'none']),
    'three link-out classes and no fourth'
  );
});

test('an unreadable vocabulary is reported, not an empty set', () => {
  // `scripts/check-objectscript.py` `:663-668` states the rule: an empty set would make every
  // declared archetype unknown and an absent check would make every declared archetype fine,
  // and neither is a negative result.
  assert.equal(parseArchetypes('Class OcuPilot.Screen.Archetype\n{\n}\n'), null, 'a missing block');
  assert.equal(parseArchetypes('XData Archetypes\n{\n{not json}\n}\n'), null, 'an unparseable block');
  assert.equal(parseArchetypes('XData Archetypes\n{\n{"archetypes":[]}\n}\n'), null, 'an empty array');
  assert.equal(
    parseArchetypes('XData Archetypes\n{\n{"archetypes":[{"key":"list"}]}\n}\n'),
    null,
    'an entry with no link-out class'
  );

  const result = withTree({ 'Home.cls': declaration({ archetype: 'home' }) }, ({ dir, screens }) =>
    checkClassicLinks({ descriptorDir: dir, archetypeSource: join(dir, 'NoSuchFile.cls'), screens })
  );
  assert.equal(result.ok, false, 'the check refuses rather than passing over nothing');
  assert.match(result.problems.join('\n'), /archetype vocabulary could not be read/);
  assert.match(result.problems.join('\n'), /NoSuchFile\.cls/, 'and names the file');
});

// --- The refusals, as values: the corpus both engines run -----------------------------------

// AD-44, DW-186: every case in `OcuPilot.Test.ClassicLinkCorpus`, read off disk from the same XData
// block `OcuPilot.Test.Descriptor` reads through the class dictionary, gets its exact sentence or
// `null` from `classicLinkProblem`.
test('classicLinkProblem returns every sentence OcuPilot.Test.ClassicLinkCorpus declares', () => {
  const body = extractXData(readFileSync(CORPUS_SOURCE, 'utf8'), 'Cases');
  assert.ok(body !== null, 'the corpus block is found');
  const { cases } = JSON.parse(body);
  assert.ok(cases.length > 0, `the corpus carries cases (read ${cases.length})`);
  const exempted = new Set();
  const plain = new Set();
  for (const testCase of cases) {
    assert.equal(classicLinkProblem(testCase.declaration, VOCABULARY), testCase.expected, testCase.name);
    const { archetype, classicPage } = testCase.declaration;
    const exemption = testCase.declaration.classicLinkExemption;
    if (
      exemption?.exempt === true &&
      exemption.reason !== '' &&
      exemption.label !== '' &&
      exemption.href === '/csp/sys/OcuPilotTestClassicPage.csp' &&
      classicPage !== ''
    ) {
      exempted.add(archetype);
    }
    if (exemption?.exempt === false && exemption.label === '' && exemption.href === '' && testCase.expected === null) {
      plain.add(archetype);
    }
  }
  for (const key of VOCABULARY.keys()) {
    assert.ok(exempted.has(key), `the corpus holds a complete exemption for archetype ${key}`);
    assert.ok(plain.has(key), `and a sound declaration with no exemption for archetype ${key}`);
  }
});

// --- The report, and the population --------------------------------------------------------

test('a clean run names the scanned count, the per-class tally and the honored count', () => {
  const result = withTree(
    {
      'Home.cls': declaration({ archetype: 'home' }),
      'Users.cls': declaration({ archetype: 'list' }),
    },
    ({ dir, screens }) => checkClassicLinks({ descriptorDir: dir, screens })
  );

  assert.equal(result.ok, true, 'a sound roster passes');
  assert.equal(result.problems.length, 0);

  const printed = result.report.join('\n');
  assert.match(printed, /scanned 2 descriptor\(s\)/, 'the scanned count is printed on a clean run');
  assert.match(printed, /against 2 \.cls file\(s\)/, 'and the independent file count beside it');
  assert.match(printed, /link-out class tally -- detail 0, list 1, none 1/, 'and the per-class tally');
  // The stable, greppable line SM-C1 is met by: printed even when the count is zero, which is
  // the whole point -- a check that looked at nothing is otherwise indistinguishable from a
  // check that found nothing wrong.
  assert.match(printed, /^classic-links: 0 exemption\(s\) honored \(SM-C1\)$/m);
});

test('an honored exemption is reported by name, archetype, reason, label and href', () => {
  const exemption = honoredExemption();
  const result = withTree(
    {
      'Home.cls': declaration({ archetype: 'home' }),
      'OAuth.cls': declaration({ archetype: 'form-page (tabs)', classicLinkExemption: exemption }),
    },
    ({ dir, screens }) => checkClassicLinks({ descriptorDir: dir, screens })
  );

  assert.equal(result.ok, true, 'the exemption is honored, not refused');
  assert.equal(result.honored.length, 1);

  const printed = result.report.join('\n');
  assert.match(printed, /honored exemption -- OAuth\.cls/, 'the report names the descriptor');
  assert.match(printed, /archetype "form-page \(tabs\)"/, 'and its archetype');
  assert.match(printed, new RegExp(exemption.reason.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')), 'and the reason');
  assert.match(printed, /label "OcuPilot test classic page"/, 'and the label');
  assert.match(printed, /href \/csp\/sys\/OcuPilotTestClassicPage\.csp/, 'and the href');
  assert.match(printed, /^classic-links: 1 exemption\(s\) honored \(SM-C1\)$/m, 'and counts it');
});

test('a descriptor the reader did not return is a refusal, not a shorter population', () => {
  // A shortfall means the check classified less than the directory holds. On the production
  // path the two counts come from one `readdirSync` with one filter and so cannot differ; what
  // this guard catches is a caller who injected a population from somewhere else, and a
  // `BASE_FILE` drift between this module and the generator. The two assertions that close the
  // production hole are elsewhere: `readSources()` throws naming a file it cannot parse rather
  // than skipping it, and the name-keyed scan two tests below.
  const result = withTree(
    {
      'Home.cls': declaration({ archetype: 'home' }),
      'Missing.cls': declaration({ archetype: 'list' }),
    },
    ({ dir, screens }) => checkClassicLinks({ descriptorDir: dir, screens: screens.slice(0, 1) })
  );

  assert.equal(result.ok, false);
  assert.match(result.problems.join('\n'), /classified 1 descriptor\(s\) but the directory holds 2/);
  // The report still prints, so the run says what it looked at even as it refuses.
  assert.match(result.report.join('\n'), /scanned 1 descriptor\(s\)/);
});

test('a population larger than the tree is a refusal too -- the two sources must agree', () => {
  // The mismatch read from the other end: an injected population that did not come from
  // `descriptorDir` is classified, then reported as a count against a directory it never came
  // from. A floor would let that pass; an equality does not.
  const result = withTree({ 'Home.cls': declaration({ archetype: 'home' }) }, ({ dir, screens }) =>
    checkClassicLinks({
      descriptorDir: dir,
      screens: [...screens, { file: 'Ghost.cls', declaration: declaration({ archetype: 'list' }) }],
    })
  );

  assert.equal(result.ok, false, 'two classified against one on disk is a refusal');
  assert.match(result.problems.join('\n'), /classified 2 descriptor\(s\) but the directory holds 1/);
  assert.match(result.problems.join('\n'), /the two population sources must agree/);
});

test('an empty descriptor directory (besides the base) is a clean run of zero, not a refusal', () => {
  // A tree that declares no screen at all still has to be distinguishable from a check that
  // never looked: the two population sources agree at zero, so this is sound, and the report
  // still names the zero rather than staying silent about it.
  const result = withTree({}, ({ dir, screens }) => checkClassicLinks({ descriptorDir: dir, screens }));

  assert.equal(result.ok, true, 'zero descriptors is not itself a fault');
  assert.equal(result.scanned, 0);
  assert.equal(result.fileCount, 0);
  assert.equal(result.honored.length, 0);
  const printed = result.report.join('\n');
  assert.match(printed, /scanned 0 descriptor\(s\)/, 'the zero count is printed, not omitted');
  assert.match(printed, /against 0 \.cls file\(s\)/);
  assert.match(printed, /^classic-links: 0 exemption\(s\) honored \(SM-C1\)$/m);
});

test('a descriptor sub-directory is refused, not silently skipped by both sources at once', () => {
  // `OcuPilot.Screen.Registry.Descriptors` selects on `Name %STARTSWITH
  // 'OcuPilot.Screen.Descriptor.'`, so the instance enumerates a descriptor in a sub-package
  // while this reader and `readSources()` list one directory level. Both population sources
  // would miss it together -- they would agree, the shortfall refusal would not fire, and a
  // nested list screen would link out unchecked. That is the vacuous pass in its purest form,
  // so an unexpected directory refuses rather than being walked.
  const result = withTree({ 'Home.cls': declaration({ archetype: 'home' }) }, ({ dir, screens }) => {
    mkdirSync(join(dir, 'Security'));
    writeFileSync(
      join(dir, 'Security', 'Ssl.cls'),
      'Class OcuPilot.Screen.Descriptor.Security.Ssl\n{\n}\n'
    );
    return checkClassicLinks({ descriptorDir: dir, screens });
  });

  assert.equal(result.ok, false);
  assert.match(result.problems.join('\n'), /sub-director/, 'the refusal says what it found');
  assert.match(result.problems.join('\n'), /Security/, 'and names it');
  assert.match(result.problems.join('\n'), /%STARTSWITH/, 'and why the instance would see it');
});

test('a descriptor class declared outside the descriptor directory is refused -- the case the equality guard cannot see', () => {
  // The sub-directory refusal above closes one spelling of the hole; this is the general one.
  // `Registry.Descriptors` keys on the CLASS NAME, every reader here keys on the FILE PATH, and
  // `scripts/check-objectscript.py`'s `check_package_placement` asserts only that a class sits
  // under one of the seven fixed packages -- which `OcuPilot.Screen.Descriptor.Stray` declared
  // in `Screen/Stray.cls` satisfies. `readSources()`, `descriptorFileNames()` and
  // `descriptorSubdirectories()` all miss it together, so the two counts agree at 1 and 1 and
  // the equality guard never fires. Only a name-keyed scan sees it, which is why the second
  // population source is that scan and not a second `readdirSync` of the same directory.
  const root = mkdtempSync(join(tmpdir(), 'ocupilot-classic-links-root-'));
  const dir = join(root, 'Screen', 'Descriptor');
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, BASE_FILE), 'Class OcuPilot.Screen.Descriptor.Base\n{\n}\n');
  writeFileSync(join(dir, 'Home.cls'), 'Class OcuPilot.Screen.Descriptor.Home\n{\n}\n');
  const screens = [
    {
      file: 'Home.cls',
      className: 'OcuPilot.Screen.Descriptor.Home',
      declaration: declaration({ archetype: 'home' }),
    },
  ];

  try {
    // Without the stray file the same tree is clean: the refusal is about the misplaced class,
    // not about the shape of the injected tree.
    const clean = checkClassicLinks({ descriptorDir: dir, sourceRoot: root, screens });
    assert.equal(clean.ok, true, `the tree is sound before the stray lands: ${clean.problems.join('; ')}`);
    assert.equal(clean.scanned, 1);
    assert.equal(clean.fileCount, 1, 'and the two counts agree, which is why they cannot catch what follows');

    writeFileSync(
      join(root, 'Screen', 'Stray.cls'),
      'Class OcuPilot.Screen.Descriptor.Stray Extends OcuPilot.Screen.Descriptor.Base\n{\n}\n'
    );
    const result = checkClassicLinks({ descriptorDir: dir, sourceRoot: root, screens });

    assert.equal(result.ok, false, 'a descriptor the path-keyed readers cannot see is a refusal');
    assert.match(result.problems.join('\n'), /Stray\.cls/, 'the refusal names the file');
    assert.match(
      result.problems.join('\n'),
      /OcuPilot\.Screen\.Descriptor package/,
      'and says what is wrong with where it is'
    );
    assert.match(result.report.join('\n'), /refused before classifying any descriptor/);
    assert.match(result.report.join('\n'), /^classic-links: scanned 0 descriptor\(s\)$/m);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test('the real scan root holds no descriptor class outside the descriptor directory', () => {
  // The production invocation of the scan above, over the shipped tree rather than a synthetic
  // one -- so the guard is exercised where it actually runs, not only where it is injected.
  assert.deepEqual(misplacedDescriptorClasses(SOURCE_ROOT, DESCRIPTOR_DIR), []);
});

test('every refusal that returns early still reports, including the count line', () => {
  // "On every run, clean or not" is the acceptance criterion's wording, and a refusing run that
  // printed only its violation would be indistinguishable from a run that looked at nothing --
  // which is the very thing the criterion exists to make distinguishable.
  const earlyRefusals = [
    [
      'an unreadable vocabulary',
      ({ dir, screens }) =>
        checkClassicLinks({ descriptorDir: dir, archetypeSource: join(dir, 'NoSuchFile.cls'), screens }),
    ],
    [
      'an unreadable descriptor directory',
      () => checkClassicLinks({ descriptorDir: join(tmpdir(), 'ocupilot-no-such-directory') }),
    ],
  ];

  for (const [what, run] of earlyRefusals) {
    const result = withTree({ 'Home.cls': declaration({ archetype: 'home' }) }, run);
    assert.equal(result.ok, false, `${what} is a refusal`);
    const printed = result.report.join('\n');
    assert.match(printed, /refused before classifying any descriptor/, `${what} still reports`);
    assert.match(printed, /^classic-links: 0 exemption\(s\) honored \(SM-C1\)$/m, `${what} still counts`);
  }
});

test('a refused descriptor names its file, and the run still exits with a violation', () => {
  const result = withTree(
    { 'Users.cls': declaration({ archetype: 'list', classicLinkExemption: honoredExemption() }) },
    ({ dir, screens }) => checkClassicLinks({ descriptorDir: dir, screens })
  );

  assert.equal(result.ok, false);
  assert.match(result.problems.join('\n'), /^Users\.cls: /m, 'the refusal names the descriptor file');
  assert.match(result.problems.join('\n'), /only a detail archetype may/);
  assert.equal(result.honored.length, 0, 'and a refused declaration is never counted as honored');
});

test('a descriptor whose Declaration is not valid JSON is a refusal naming its .cls file', () => {
  // No `screens` is injected, so the check reads the population out of the directory it was
  // given -- the path the gates take.
  const dir = mkdtempSync(join(tmpdir(), 'ocupilot-classic-links-json-'));
  try {
    writeFileSync(join(dir, BASE_FILE), 'Class OcuPilot.Screen.Descriptor.Base\n{\n}\n');
    writeFileSync(
      join(dir, 'Malformed.cls'),
      'Class OcuPilot.Screen.Descriptor.Malformed Extends OcuPilot.Screen.Descriptor.Base\n' +
        '{\n\nXData Declaration\n{\n{"archetype": "home",}\n}\n\n}\n'
    );
    const result = checkClassicLinks({ descriptorDir: dir });

    assert.equal(result.ok, false, 'an unparseable descriptor is a refusal, not a shorter population');
    assert.match(result.problems.join('\n'), /Malformed\.cls/, 'the refusal names the file');
    assert.match(result.problems.join('\n'), /not valid JSON/, 'and says what is wrong with it');
    let parserMessage = '';
    try {
      JSON.parse('{"archetype": "home",}');
    } catch (error) {
      parserMessage = error.message;
    }
    assert.ok(parserMessage !== '' && result.problems.join('\n').includes(parserMessage), "and carries the parser's own message");
    assert.match(result.report.join('\n'), /^classic-links: 0 exemption\(s\) honored \(SM-C1\)$/m);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

// --- The real tree ---------------------------------------------------------------------------

test('the shipped descriptor roster passes, and its population matches the tree on disk', () => {
  const result = checkClassicLinks();

  assert.equal(result.ok, true, `the shipped roster is sound: ${result.problems.join('; ')}`);
  assert.equal(
    result.scanned,
    descriptorFileNames(DESCRIPTOR_DIR).length,
    'every .cls under the descriptor directory but the base was classified'
  );
  assert.ok(result.scanned >= 1, 'at least Home is declared');
  assert.equal(result.honored.length, 0, 'Release 1 has no honored exemption yet -- 6.4 lands the first');
  assert.match(result.report.join('\n'), /exemption\(s\) honored \(SM-C1\)/);
});

// --- The gates ---------------------------------------------------------------------------------

test('the check is named in prebuild, in prestart and in the pre-commit hook', () => {
  // A checker wired into no gate is the defect this assertion exists to prevent: it would
  // pass every run a developer happened to make and block nothing.
  const scripts = JSON.parse(readFileSync(join(here, '..', 'package.json'), 'utf8')).scripts;
  assert.match(scripts.prebuild, /node tools\/classic-links\.mjs/, 'prebuild runs it before ng build');
  assert.match(scripts.prestart, /node tools\/classic-links\.mjs/, 'prestart runs it before ng serve');

  const hook = readFileSync(join(REPO_ROOT, '.githooks', 'pre-commit'), 'utf8');
  assert.match(hook, /node tools\/classic-links\.mjs/, 'the pre-commit hook runs it');
  // Inside the existing ObjectScript/ui trigger, beside the client lint -- the two scopes must
  // agree, so the check runs on exactly the commits that can change a descriptor.
  const trigger = hook.slice(hook.indexOf('if [ -n "$OS_TRIGGER" ]'));
  const block = trigger.slice(0, trigger.indexOf('\nfi\n'));
  assert.match(
    block,
    /node tools\/classic-links\.mjs/,
    'and does so inside the OS_TRIGGER block, not on a trigger of its own'
  );

  // Named is not the same as able to block, and the two defects are indistinguishable from the
  // outside: a dispatch that drops `|| STATUS=1`, or a script chain that swallows the failure,
  // still runs the check, still prints its refusal, and still lets the commit or the build
  // through. Every assertion above would stay green through either edit.
  assert.match(
    block,
    /node tools\/classic-links\.mjs\)?\s*\|\|\s*STATUS=1/,
    "the hook's dispatch feeds a refusal into STATUS, which is what the hook exits with"
  );
  for (const [name, chain] of [
    ['prebuild', scripts.prebuild],
    ['prestart', scripts.prestart],
  ]) {
    assert.doesNotMatch(
      chain,
      /classic-links\.mjs[^&]*\|\|/,
      `${name} does not swallow the check's exit code`
    );
    // The chain is `&&`-joined end to end, so a non-zero exit from any link stops it and
    // nothing downstream runs. Asserted as a property of every segment rather than as "the
    // check is last": Story 1.16 appends `ipm-manifest.mjs --check` after this one, and a
    // positional assertion would have to be rewritten by every later gate rather than staying
    // true of all of them.
    const segments = chain.split('&&').map((segment) => segment.trim());
    assert.ok(
      segments.includes('node tools/classic-links.mjs'),
      `${name} runs the check as a link of its own`
    );
    for (const segment of segments) {
      assert.doesNotMatch(
        segment,
        // `&` is in the class too: the split is on `&&`, so a lone `&` can only be a
        // backgrounding operator, which detaches the check and discards its exit code.
        /[|;&]/,
        `${name} joins its checks with && alone, so a refusal stops the chain: found "${segment}"`
      );
    }
  }
});

test('run as a process over the shipped tree, the check exits 0 and prints its report', () => {
  // Every assertion above reads `checkClassicLinks()`'s return value; `main()` -- the only
  // caller of console.log and process.exit, and the thing every gate actually invokes -- is
  // executed by none of them. The I/O matrix states its expectations as exit codes and printed
  // output, so one test speaks that surface.
  const run = spawnSync(process.execPath, [join(here, 'classic-links.mjs')], {
    cwd: join(here, '..'),
    encoding: 'utf8',
  });

  assert.equal(run.status, 0, `the shipped tree is clean: ${run.stdout}${run.stderr}`);
  assert.match(run.stdout, /^classic-links: scanned \d+ descriptor\(s\)/m, 'it names its population');
  assert.match(run.stdout, /^classic-links: link-out class tally -- /m, 'and the per-class tally');
  assert.match(run.stdout, /^classic-links: \d+ exemption\(s\) honored \(SM-C1\)$/m, 'and the count line');
  assert.equal(run.stderr, '', 'a clean run writes nothing to stderr');
});

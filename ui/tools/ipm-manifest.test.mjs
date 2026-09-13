import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import {
  MANIFEST_PATH,
  ROSTER_SOURCE,
  SOURCE_ROOT,
  applicationShapeProblem,
  buildManifest,
  bundleTemplateProblem,
  checkManifest,
  commentProblem,
  declaredClasses,
  packageDirectories,
  readRoster,
  rosterShapeProblem,
} from './ipm-manifest.mjs';

/**
 * The IPM manifest drift check (Story 1.16, AD-17, AD-3). Every row of the story's I/O matrix
 * that is not the live IPM install is here: both drift directions over a synthetic tree, every
 * refusal, the gate wiring, and the shipped tree, which is the one population the production
 * invocation actually reads.
 *
 * Each pinning test's demonstrated mutation is recorded once, in the story spec's
 * `## Verification` section, and not repeated here.
 */

const here = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(here, '..', '..');

/** A minimal, structurally complete roster, so each case below states only what it is about. */
function sampleRoster(overrides = {}) {
  return {
    module: {
      name: 'fixture',
      version: '1.2.3',
      description: 'A fixture module.',
      packaging: 'module',
      sourcesRoot: 'src',
    },
    systemRequirements: { version: '>=2026.2', ipmVersion: '>=0.10.0' },
    packages: ['Api', 'Install'],
    resources: [
      { name: 'OcuPilot.PKG', filenameExtension: 'cls' },
      { name: 'OcuPilot.Test.PKG', scope: 'test', filenameExtension: 'cls' },
    ],
    bundle: {
      source: 'ui/dist/ocupilot-ui/browser/',
      destinationApplication: '/ocupilot',
      destinationTemplate: '${dataDir}csp/ocupilot/',
    },
    applications: [
      {
        key: 'shell',
        path: '/ocupilot',
        description: 'Fixture shell',
        manifest: { AutheEnabled: 64, DispatchClass: 'OcuPilot.Api.StaticHandler', Enabled: 1 },
        installer: ['MatchRoles', 'NameSpace', 'Path'],
      },
    ],
    invoke: {
      class: 'OcuPilot.Install.Installer',
      method: 'Install',
      phase: 'Activate',
      when: 'After',
    },
    ...overrides,
  };
}

/** A `Roster.cls` source carrying `body` as its `XData Manifest` block. */
function rosterSource(body) {
  return `Class OcuPilot.Install.Roster Extends %RegisteredObject\n{\n\nXData Manifest\n{\n${body}\n}\n\n}\n`;
}

/**
 * A synthetic repository: `src/OcuPilot/<package>/` folders, one class per folder, the roster
 * that declares them, and the manifest that roster generates. Returns the paths
 * `checkManifest` takes, so each case can then drift exactly one of them.
 */
function syntheticTree({ roster = sampleRoster(), manifest, classes } = {}) {
  const root = mkdtempSync(join(tmpdir(), 'ocupilot-ipm-manifest-'));
  const srcRoot = join(root, 'src');
  const sourceRoot = join(srcRoot, 'OcuPilot');
  for (const name of roster.packages) {
    mkdirSync(join(sourceRoot, name), { recursive: true });
  }
  const files = classes ?? roster.packages.map((name) => [`${name}/Thing.cls`, `OcuPilot.${name}.Thing`]);
  for (const [relative, className] of files) {
    mkdirSync(dirname(join(sourceRoot, relative)), { recursive: true });
    writeFileSync(join(sourceRoot, relative), `Class ${className} Extends %RegisteredObject\n{\n}\n`);
  }
  const rosterPath = join(sourceRoot, 'Install', 'Roster.cls');
  mkdirSync(dirname(rosterPath), { recursive: true });
  writeFileSync(rosterPath, rosterSource(JSON.stringify(roster, null, 2)));
  const manifestPath = join(root, 'module.xml');
  writeFileSync(manifestPath, manifest ?? buildManifest(roster));
  return { root, srcRoot, sourceRoot, rosterSource: rosterPath, manifestPath };
}

function withTree(options, run) {
  const tree = syntheticTree(options);
  try {
    return run(tree);
  } finally {
    rmSync(tree.root, { recursive: true, force: true });
  }
}

/** `checkManifest` over a synthetic tree, with the paths already wired. */
function checkTree(tree) {
  return checkManifest({
    rosterSource: tree.rosterSource,
    srcRoot: tree.srcRoot,
    manifestPath: tree.manifestPath,
  });
}

// --- Drift, in both directions ---------------------------------------------------------

test('a manifest generated from the roster it sits beside is clean', () => {
  const result = withTree({}, checkTree);
  assert.equal(result.ok, true, `a freshly generated manifest is current: ${result.problems.join('; ')}`);
  assert.equal(result.problems.length, 0);
});

test('a roster edited without regenerating is a refusal naming the drifted element', () => {
  // The stale-manifest direction: the roster moves, the manifest does not.
  const result = withTree(
    { manifest: buildManifest(sampleRoster()) },
    (tree) => {
      const moved = sampleRoster();
      moved.applications[0].manifest.AutheEnabled = 32;
      writeFileSync(tree.rosterSource, rosterSource(JSON.stringify(moved, null, 2)));
      return checkTree(tree);
    }
  );

  assert.equal(result.ok, false, 'a stale manifest is a refusal');
  const printed = result.problems.join('\n');
  assert.match(printed, /<WebApplication> drifted/, 'the refusal names the element that drifted');
  assert.match(printed, /AutheEnabled="32"/, 'and what the roster now generates');
  assert.match(printed, /AutheEnabled="64"/, 'and what the manifest still carries');
  assert.match(printed, /node tools\/ipm-manifest\.mjs/, 'and the regenerate command');
});

test('a manifest edited by hand is the same refusal -- the comparison is symmetric, not a floor', () => {
  // The other direction, and the one a floor would let through: the manifest gains a
  // declaration the roster never made. `<WebApplication>` is exactly the case that matters --
  // a hand-added application is a second declaration of what OcuPilot installs.
  const result = withTree({}, (tree) => {
    const generated = readFileSync(tree.manifestPath, 'utf8');
    writeFileSync(
      tree.manifestPath,
      generated.replace(
        '      <Invoke ',
        '      <WebApplication Name="/smuggled" AutheEnabled="64"\n      />\n      <Invoke '
      )
    );
    return checkTree(tree);
  });

  assert.equal(result.ok, false, 'a manifest carrying more than the roster declares is a refusal');
  assert.match(result.problems.join('\n'), /drifted from src\/OcuPilot\/Install\/Roster\.cls/);
  assert.match(result.problems.join('\n'), /smuggled/, 'the refusal quotes the smuggled declaration');
});

test('a manifest shorter than the roster generates is a refusal too', () => {
  const result = withTree({}, (tree) => {
    const generated = readFileSync(tree.manifestPath, 'utf8');
    writeFileSync(
      tree.manifestPath,
      generated
        .split('\n')
        .filter((line) => !line.includes('<Resource Name="OcuPilot.Test.PKG"'))
        .join('\n')
    );
    return checkTree(tree);
  });

  assert.equal(result.ok, false);
  assert.match(result.problems.join('\n'), /drifted/);
});

test('an absent manifest is a refusal naming the file and the regenerate command', () => {
  const result = withTree({}, (tree) => {
    rmSync(tree.manifestPath);
    return checkTree(tree);
  });

  assert.equal(result.ok, false);
  assert.match(result.problems.join('\n'), /module\.xml/);
  assert.match(result.problems.join('\n'), /node tools\/ipm-manifest\.mjs/);
});

// --- The roster is never read as empty --------------------------------------------------

test('an unreadable roster is reported, not read as an empty roster', () => {
  // `scripts/check-objectscript.py`'s `read_fixed_packages` states the rule. Here it is load-bearing twice
  // over: an empty roster would generate a manifest declaring no application, no package and
  // no resource -- and that manifest would then compare equal to itself on every later run.
  assert.equal(readRoster('Class OcuPilot.Install.Roster\n{\n}\n'), null, 'a missing block');
  assert.equal(readRoster(rosterSource('{not json}')), null, 'an unparseable block');
  assert.equal(readRoster(rosterSource('{}')), null, 'an empty object');
  assert.equal(readRoster(rosterSource('[]')), null, 'an array rather than an object');

  const missing = withTree({}, (tree) => {
    rmSync(tree.rosterSource);
    return checkTree(tree);
  });
  assert.equal(missing.ok, false, 'the check refuses rather than passing over nothing');
  assert.match(missing.problems.join('\n'), /never an empty roster/);
  assert.match(missing.problems.join('\n'), /Roster\.cls/, 'and names the file');
  assert.match(missing.report.join('\n'), /refused before comparing anything/);
  assert.match(missing.report.join('\n'), /^ipm-manifest: compared 0 package\(s\)/m);
});

test('a structurally incomplete roster is refused, naming what is missing', () => {
  const cases = [
    [{ module: undefined }, /carries no "module" object/],
    [{ packages: [] }, /no non-empty "packages" array/],
    [{ resources: [] }, /no non-empty "resources" array/],
    [{ applications: [] }, /no non-empty "applications" array/],
    [{ invoke: undefined }, /carries no "invoke" object/],
    [{ bundle: undefined }, /carries no "bundle" object/],
  ];
  for (const [override, pattern] of cases) {
    const roster = sampleRoster();
    if (override.module === undefined && 'module' in override) delete roster.module;
    if (override.invoke === undefined && 'invoke' in override) delete roster.invoke;
    if (override.bundle === undefined && 'bundle' in override) delete roster.bundle;
    for (const [key, value] of Object.entries(override)) {
      if (value !== undefined) roster[key] = value;
    }
    const problem = rosterShapeProblem(roster);
    assert.ok(problem, `${JSON.stringify(override)} is refused`);
    assert.match(problem, pattern);
  }
});

test('a manifest that declares a privilege property is refused (AD-10, AD-21)', () => {
  // The manifest is a distribution artifact and may not widen what a request can do. Both
  // spellings of the mistake are refused: naming the property, and smuggling `%All` into any
  // other value.
  for (const property of ['MatchRoles', 'Roles', 'AddedRoles']) {
    const application = sampleRoster().applications[0];
    application.manifest[property] = ':%All';
    const problem = applicationShapeProblem(application);
    assert.ok(problem, `${property} in the manifest is refused`);
    assert.match(problem, /AD-10/);
  }

  const widened = sampleRoster().applications[0];
  widened.manifest.Resource = '%All';
  assert.match(applicationShapeProblem(widened), /widens privilege/);

  // And the omission that would leave a matching-role set nobody asserts.
  const unnamed = sampleRoster().applications[0];
  unnamed.installer = ['NameSpace', 'Path'];
  assert.match(applicationShapeProblem(unnamed), /must name "MatchRoles" as instance-derived/);
});

test('a property declared on both halves of the split is refused', () => {
  const application = sampleRoster().applications[0];
  application.manifest.NameSpace = 'HSCUSTOM';
  assert.match(applicationShapeProblem(application), /both in its manifest and as instance-derived/);
});

// --- The tree the roster names ----------------------------------------------------------

test('a package folder the roster does not declare is a refusal naming the directory', () => {
  const result = withTree({}, (tree) => {
    mkdirSync(join(tree.sourceRoot, 'Screen'));
    return checkTree(tree);
  });

  assert.equal(result.ok, false);
  assert.match(result.problems.join('\n'), /Screen/, 'the refusal names the directory');
  assert.match(result.problems.join('\n'), /the roster does not declare/);
});

test('a package folder the roster declares but the tree does not hold is a refusal too', () => {
  // The equality read from the other end: a folder removed without the roster. A floor would
  // let this pass, and the shipped module would name a package that resolves to nothing.
  const result = withTree({}, (tree) => {
    rmSync(join(tree.sourceRoot, 'Api'), { recursive: true, force: true });
    return checkTree(tree);
  });

  assert.equal(result.ok, false);
  assert.match(result.problems.join('\n'), /declares the package folder "Api"/);
  assert.match(result.problems.join('\n'), /must agree/);
});

test('a roster whose sourcesRoot is not the tree this check walks is refused', () => {
  // <SourcesRoot> is generated from the roster; the tree the shipped classes are read from is
  // this checker's own SRC_ROOT. Two spellings of one directory: a roster that moved would
  // ship a module resolving under "source" while every gate kept reporting clean over "src".
  const moved = sampleRoster();
  moved.module.sourcesRoot = 'source';
  const result = withTree({ roster: moved }, checkTree);

  assert.equal(result.ok, false, 'a sources root the check does not walk is a refusal');
  assert.ok(
    result.problems.some((problem) => /declares sourcesRoot "source"/.test(problem)),
    `it names the sources root it read: ${result.problems.join('; ')}`
  );
  assert.ok(
    result.report.some((line) => /refused before comparing anything/.test(line)),
    'and says it compared nothing rather than reporting counts over the wrong tree'
  );
});

test('a roster that ships no resource for the package this check enforces is refused', () => {
  // The other half of the same shape: every .cls under the tree must declare a class in the
  // OcuPilot package because <Resource Name="OcuPilot.PKG"/> is what ships it. A roster whose
  // resource list no longer names that package leaves the rule enforced and nothing shipping.
  const moved = sampleRoster();
  moved.resources = [{ name: 'Other.PKG', filenameExtension: 'cls' }];
  const result = withTree({ roster: moved }, checkTree);

  assert.equal(result.ok, false, 'a roster that ships some other package is a refusal');
  assert.ok(
    result.problems.some((problem) => /declares no resource named "OcuPilot\.PKG"/.test(problem)),
    `it names the resource it required: ${result.problems.join('; ')}`
  );
});

test('a source tree holding no class at all is a refusal, never a clean run', () => {
  // The one population with no non-empty requirement of its own. Every other rule in the
  // checker is an equality between two sets; this one is a loop that asserts once per class,
  // so a scan that found none passes it by finding nothing to object to. npm test asserted
  // counts.classes >= 1 over the shipped tree -- the gates never did.
  //
  // The production invocation cannot reach the empty scan today, because the roster is itself
  // a .cls inside the tree being scanned. That is an incidental invariant, not a declared one:
  // this makes it declared, and the case drives it by scanning a directory the roster is not
  // in, which is the only way to construct the shape at all.
  const result = withTree({}, (tree) => {
    const bare = join(tree.root, 'no-classes-here');
    mkdirSync(bare, { recursive: true });
    return checkManifest({
      rosterSource: tree.rosterSource,
      srcRoot: tree.srcRoot,
      sourceRoot: bare,
      manifestPath: tree.manifestPath,
    });
  });

  assert.equal(result.ok, false, 'an empty class population is a refusal');
  assert.ok(
    result.problems.some((problem) => /holds no \.cls at all/.test(problem)),
    `it says it looked at no class: ${result.problems.join('; ')}`
  );
});

test('an application path that is not absolute is refused, as the installer refuses it', () => {
  // The generator and OcuPilot.Install.Installer.RosterNames read the same roster; only the
  // installer used to hold this rule, so a roster with "ocupilot" for "/ocupilot" passed
  // prebuild, prestart and the hook and failed at the install the manifest exists for.
  const moved = sampleRoster();
  moved.applications[0].path = 'ocupilot';
  moved.bundle.destinationApplication = 'ocupilot';

  assert.match(rosterShapeProblem(moved), /declares the path "ocupilot", which is not absolute/);
});

test('a bundle destination naming no declared application is refused', () => {
  // bundle.destinationApplication and applications[].path were two spellings of "/ocupilot":
  // renaming the shell application moved one and left the bundle copying into a directory the
  // handler no longer serves from. The roster declares the path once, under "applications".
  const moved = sampleRoster();
  moved.bundle.destinationApplication = '/ocupilot-renamed';

  assert.match(
    rosterShapeProblem(moved),
    /bundle\.destinationApplication "\/ocupilot-renamed" names no application the roster declares/
  );
  assert.equal(rosterShapeProblem(sampleRoster()), null, 'the shape the shipped roster carries is accepted');
});

test('a .cls declaring a class outside the shipped package is refused, naming file and class', () => {
  const result = withTree(
    {
      classes: [
        ['Api/Thing.cls', 'OcuPilot.Api.Thing'],
        ['Install/Stray.cls', 'Elsewhere.Install.Stray'],
      ],
    },
    checkTree
  );

  assert.equal(result.ok, false);
  const printed = result.problems.join('\n');
  assert.match(printed, /Stray\.cls/, 'the refusal names the file');
  assert.match(printed, /"Elsewhere\.Install\.Stray"/, 'and the class');
  assert.match(printed, /OcuPilot\.PKG/, 'and why it would not ship');
});

test('a .cls with no readable class declaration is a refusal, never a skip', () => {
  const result = withTree({}, (tree) => {
    writeFileSync(join(tree.sourceRoot, 'Api', 'Broken.cls'), '/// only a comment\n');
    return checkTree(tree);
  });

  assert.equal(result.ok, false);
  assert.match(result.problems.join('\n'), /Broken\.cls/);
  assert.match(result.problems.join('\n'), /never a skip/);
});

test('src/cls/ is a refusal -- IPM resolves the package somewhere else the moment it exists', () => {
  // The silent one: with `src/cls/` on disk, IPM's document processor resolves
  // `<Resource Name="OcuPilot.PKG"/>` under `src/cls/` instead of `src/`, with no edit to
  // module.xml and no error anywhere. Nothing else in this repository would notice.
  const result = withTree({}, (tree) => {
    mkdirSync(join(tree.srcRoot, 'cls'));
    return checkTree(tree);
  });

  assert.equal(result.ok, false);
  assert.match(result.problems.join('\n'), /src[/\\]cls/, 'the refusal names the directory');
  assert.match(result.problems.join('\n'), /SourcesRoot/);
  assert.match(result.report.join('\n'), /refused before comparing anything/);
});

// --- What the generated manifest says ----------------------------------------------------

test('the generated <Invoke> carries no <Arg>, so pUnexpire keeps its default (DW-92)', () => {
  // The manifest half of the assertion; `OcuPilot.Test.UnexpireScope` pins the same fact
  // against the committed file and against what Install() actually does with the argument.
  const generated = buildManifest(sampleRoster());
  assert.match(generated, /<Invoke Class="OcuPilot\.Install\.Installer" Method="Install" Phase="Activate" When="After"\/>/);
  assert.doesNotMatch(generated, /<Arg/, 'no <Arg> child of any kind');

  // Phase is stated because its default is Configure, which is not in the activate chain: a
  // bare <Invoke> would be accepted by IPM and never run.
  assert.match(generated, /Phase="Activate"/);
});

test('the generated manifest names no CSPApplication and no Health requirement', () => {
  const generated = buildManifest(sampleRoster());
  assert.doesNotMatch(generated, /<CSPApplication/, 'the deprecated element is never emitted');
  assert.doesNotMatch(generated, /Health=/, '<SystemRequirements Health="0"> would refuse IRIS for Health');
  assert.match(generated, /IPMVersion="&gt;=0\.10\.0"/, 'NFR-13 measurable as an IPM version expression');
});

test('the bundle destination resolves under the writable data directory, never the install one', () => {
  // `${cspdir}` is deliberately refused: it resolves under the install directory, which
  // src/OcuPilot/Api/StaticHandler.cls records as not writable on the pinned image, so a
  // bundle copied there would fail or be unreadable.
  assert.equal(bundleTemplateProblem('${dataDir}csp/ocupilot/'), null);
  assert.equal(bundleTemplateProblem('{$dataDir}csp/ocupilot/'), null, 'IPM accepts either placeholder spelling');
  assert.match(bundleTemplateProblem('${cspdir}ocupilot/'), /not writable/);
  assert.match(bundleTemplateProblem('/durable/iris/csp/ocupilot/'), /right on one instance only/);
  assert.match(bundleTemplateProblem('${dataDir}csp/ocupilot'), /does not end in "\/"/);
  assert.match(bundleTemplateProblem(''), /is missing or empty/);

  const generated = buildManifest(sampleRoster());
  assert.match(generated, /<FileCopy Name="ui\/dist\/ocupilot-ui\/browser\/" Target="\$\{dataDir\}csp\/ocupilot\/"\/>/);
  assert.doesNotMatch(generated, /cspdir/i);
  // Defer is left off on purpose: the copy then runs at the start of the Activate phase,
  // strictly before the When="After" <Invoke>, so the bundle is in place before Install runs.
  assert.doesNotMatch(generated, /Defer=/);
  // The #{...} form is not used, and that is a finding rather than a preference: <FileCopy>'s
  // InstallDirectory is Required and validated in the Validate phase, which runs before
  // Compile -- so an expression calling the class this very module installs evaluates to ""
  // and fails the whole module. Observed on a throwaway container.
  assert.doesNotMatch(generated, /#\{/, 'no arbitrary-ObjectScript expression reaches the manifest');
});

test('the generated manifest is XML IPM\'s strict parser accepts', () => {
  // Found by a live `zpm load` against a throwaway container, not by inspection: the header
  // comment used `--` as a dash, XML forbids that sequence inside a comment, and IPM's SAX
  // reader refused the whole manifest with "'--' sequence is illegal in comment" and a line
  // offset that named nothing about OcuPilot. Every other test in this file passed.
  assert.ok(commentProblem('a -- b'), 'a dash pair inside a comment is refused');
  assert.ok(commentProblem('ends on a dash -'), 'a trailing dash would close the comment early');
  assert.equal(commentProblem('plain prose, and an em dash is spelled out'), null);

  const generated = buildManifest(sampleRoster());
  const comments = [...generated.matchAll(/<!--([\s\S]*?)-->/g)].map((m) => m[1]);
  assert.ok(comments.length > 0, 'the manifest carries its generated-file banner');
  for (const body of comments) {
    assert.equal(commentProblem(body), null, `comment body is legal XML: ${body}`);
  }

  // And the committed file, which is what IPM actually reads.
  const committed = readFileSync(MANIFEST_PATH, 'utf8');
  for (const body of [...committed.matchAll(/<!--([\s\S]*?)-->/g)].map((m) => m[1])) {
    assert.equal(commentProblem(body), null, 'the committed manifest carries no illegal comment');
  }
});

test('every package resource narrows IPM\'s import wildcard, or the roster is refused', () => {
  // Found by a live `zpm load`, not by inspection: a .PKG resource is loaded with
  // $System.OBJ.ImportDir(<sources root>, "*" _ FilenameExtension, ...) recursively, and IPM's
  // default for that property is empty. The wildcard is then "*", the walk reaches
  // src/OcuPilot/Area/.gitkeep -- the placeholder that keeps an empty package folder in version
  // control -- and the whole load fails with "not a supported type", naming a file and no
  // module. Every other test in this file passed on the manifest that did that.
  const roster = sampleRoster();
  delete roster.resources[0].filenameExtension;
  const problem = rosterShapeProblem(roster);
  assert.ok(problem, 'a package resource with no filenameExtension is refused');
  assert.match(problem, /imports every file under the sources root/);

  const generated = buildManifest(sampleRoster());
  assert.match(generated, /<Resource Name="OcuPilot\.PKG" FilenameExtension="cls"\/>/);
  assert.match(generated, /<Resource Name="OcuPilot\.Test\.PKG" FilenameExtension="cls" Scope="test"\/>/);

  const committed = readFileSync(MANIFEST_PATH, 'utf8');
  for (const [, name] of committed.matchAll(/<Resource Name="([^"]+\.PKG)"/g)) {
    assert.match(
      committed,
      new RegExp(`<Resource Name="${name.replace(/\./g, '\\.')}" FilenameExtension="`),
      `the committed ${name} narrows the import wildcard`
    );
  }
});

test('generation is deterministic -- the same roster produces the same bytes', () => {
  // A generator whose attribute order followed object insertion order would fail its own
  // drift check on another machine, or after an unrelated roster reordering.
  const first = buildManifest(sampleRoster());
  const reordered = sampleRoster();
  reordered.applications[0].manifest = {
    Enabled: 1,
    DispatchClass: 'OcuPilot.Api.StaticHandler',
    AutheEnabled: 64,
  };
  assert.equal(buildManifest(reordered), first, 'attribute order does not follow declaration order');
});

// --- The shipped tree ---------------------------------------------------------------------

test('the committed module.xml is current, and its counts match the shipped tree', () => {
  const result = checkManifest();

  assert.equal(result.ok, true, `the committed manifest is current: ${result.problems.join('; ')}`);
  assert.equal(result.counts.packages, packageDirectories(SOURCE_ROOT).length);
  assert.equal(result.counts.classes, declaredClasses(SOURCE_ROOT).length);
  assert.ok(result.counts.classes >= 1, 'the tree holds at least one class');
  assert.equal(result.counts.applications, 2, 'Epic 1 declares the shell and the API');
  assert.match(result.report.join('\n'), /^ipm-manifest: compared \d+ package\(s\)/m);
});

test('the shipped roster and the committed manifest agree about the two applications', () => {
  const roster = readRoster(readFileSync(ROSTER_SOURCE, 'utf8'));
  assert.ok(roster, 'the shipped roster parses');
  assert.deepEqual(
    roster.applications.map((application) => application.path).sort(),
    ['/api/ocupilot', '/ocupilot']
  );

  const manifest = readFileSync(MANIFEST_PATH, 'utf8');
  assert.match(manifest, /<WebApplication Name="\/ocupilot"/);
  assert.match(manifest, /<WebApplication Name="\/api\/ocupilot"/);
  assert.doesNotMatch(manifest, /<Arg/, 'the committed <Invoke> takes no argument (DW-92)');
  assert.doesNotMatch(manifest, /MatchRoles/, 'the committed manifest widens no matching role (AD-10)');
  assert.doesNotMatch(manifest, /%All/, 'and grants no %All');
  assert.match(manifest, /<Resource Name="OcuPilot\.Test\.PKG"[^>]* Scope="test"\/>/, 'test classes are out of scope for a shipped install');
});

// --- The gates -----------------------------------------------------------------------------

test('the check is named in prebuild, in prestart and in the pre-commit hook', () => {
  // A checker wired into no gate is the defect this assertion exists to prevent: it would
  // pass every run a developer happened to make and block nothing.
  const scripts = JSON.parse(readFileSync(join(here, '..', 'package.json'), 'utf8')).scripts;
  assert.match(scripts.prebuild, /node tools\/ipm-manifest\.mjs --check/, 'prebuild runs it before ng build');
  assert.match(scripts.prestart, /node tools\/ipm-manifest\.mjs --check/, 'prestart runs it before ng serve');

  const hook = readFileSync(join(REPO_ROOT, '.githooks', 'pre-commit'), 'utf8');
  assert.match(hook, /node tools\/ipm-manifest\.mjs --check/, 'the pre-commit hook runs it');

  // Inside the existing ObjectScript/ui trigger, which must also fire on the generated
  // artifact itself -- otherwise a commit that edits only module.xml never runs the check.
  const trigger = hook.slice(hook.indexOf('OS_TRIGGER=$('));
  const pathspec = trigger.slice(0, trigger.indexOf(')\n'));
  assert.match(pathspec, /'module\.xml'/, "the hook's trigger fires on the generated manifest too");
  // ACMR, not ACMRD, was the pre-existing filter, and the drift direction this check added --
  // a package folder the roster declares but the tree no longer holds -- is only ever reached
  // by a commit that DELETES files. Without this assertion the filter can be reverted and
  // every case in this file stays green.
  assert.match(
    pathspec,
    /--diff-filter=ACMRD\b/,
    'and includes deletions, or a commit that only removes a package folder fires no trigger at all'
  );

  const block = hook.slice(hook.indexOf('if [ -n "$OS_TRIGGER" ]'));
  const body = block.slice(0, block.indexOf('\nfi\n'));
  assert.match(
    body,
    /node tools\/ipm-manifest\.mjs --check/,
    'and dispatches inside the OS_TRIGGER block, not on a trigger of its own'
  );

  // Named is not the same as able to block, and the two defects are indistinguishable from
  // the outside: a dispatch that drops `|| STATUS=1`, or a script chain that swallows the
  // failure, still runs the check, still prints its refusal, and still lets the commit or the
  // build through. Every assertion above would stay green through either edit.
  assert.match(
    body,
    /node tools\/ipm-manifest\.mjs --check\)?\s*\|\|\s*STATUS=1/,
    "the hook's dispatch feeds a refusal into STATUS, which is what the hook exits with"
  );
  for (const [name, chain] of [
    ['prebuild', scripts.prebuild],
    ['prestart', scripts.prestart],
  ]) {
    assert.doesNotMatch(
      chain,
      /ipm-manifest\.mjs[^&]*\|\|/,
      `${name} does not swallow the check's exit code`
    );
    const segments = chain.split('&&').map((segment) => segment.trim());
    assert.ok(
      segments.includes('node tools/ipm-manifest.mjs --check'),
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

  // The hook's failure help must say what to do, and the answer is never "edit module.xml".
  assert.match(hook, /IPM manifest:/, 'the hook explains this failure among the others');
  assert.match(hook, /Edit the roster, never\n\s*#?\s*the manifest/, 'and says which file to edit');
});

test('run as a process over the shipped tree, --check exits 0 and prints its report', () => {
  // Every assertion above reads `checkManifest()`'s return value; `main()` -- the only caller
  // of console.log and process.exitCode, and the thing every gate actually invokes -- is
  // executed by none of them. The I/O matrix states its expectations as exit codes and
  // printed output, so one test speaks that surface.
  const run = spawnSync(process.execPath, [join(here, 'ipm-manifest.mjs'), '--check'], {
    cwd: join(here, '..'),
    encoding: 'utf8',
  });

  assert.equal(run.status, 0, `the committed manifest is current: ${run.stdout}${run.stderr}`);
  assert.match(run.stdout, /^ipm-manifest: compared \d+ package\(s\), \d+ application\(s\), \d+ resource\(s\), \d+ class\(es\)$/m);
  assert.match(run.stdout, /^ipm-manifest: roster declares module \S+ \S+/m, 'it names the module it read');
  assert.match(run.stdout, /^ipm-manifest: application \/ocupilot -- /m, 'and each application it compared');
  assert.match(run.stdout, /^ipm-manifest: up to date\.$/m);
  assert.equal(run.stderr, '', 'a clean run writes nothing to stderr');
});

test('run as a process with no argument, the generator rewrites the committed manifest byte for byte', () => {
  // The write half of the duality, which `--check` alone cannot exercise: a generator whose
  // write path and check path disagreed would pass every check and produce a file no check
  // accepts.
  //
  // This is the one case that writes a tracked file, so it puts the original bytes back in a
  // finally. On a current tree the rewrite is byte-identical and the restore is a no-op; on a
  // tree whose roster has moved it is not, and a test run must not repair -- or damage -- a
  // committed file behind the developer editing it.
  const before = readFileSync(MANIFEST_PATH, 'utf8');
  let run;
  let after;
  try {
    run = spawnSync(process.execPath, [join(here, 'ipm-manifest.mjs')], {
      cwd: join(here, '..'),
      encoding: 'utf8',
    });
    after = readFileSync(MANIFEST_PATH, 'utf8');
  } finally {
    writeFileSync(MANIFEST_PATH, before);
  }

  assert.equal(run.status, 0, `${run.stdout}${run.stderr}`);
  assert.match(run.stdout, /^ipm-manifest: wrote module\.xml$/m);
  assert.equal(after, before, 'the write path produces exactly the bytes the check path accepts');
  assert.equal(run.stderr, '', 'a clean run writes nothing to stderr');
});

test('run as a process over a drifted tree, --check exits 1 and prints the violations', () => {
  // The arm every gate actually depends on. The three spawned cases around this one end in
  // main()'s two success arms and in the unknown-argument arm, which returns before
  // checkManifest is ever called -- so the block that prints the violations and sets
  // process.exitCode was executed by nothing, and deleting that one line left prebuild,
  // prestart and the pre-commit hook all passing over a drifted manifest with nothing red.
  //
  // The generator resolves the repository root from its own file location, so a drifted tree
  // is driven by putting a copy of it in one. No tracked file is read or written here.
  withTree({ manifest: '<Export generator="Cache" version="25"/>\n' }, (tree) => {
    const tools = join(tree.root, 'ui', 'tools');
    mkdirSync(tools, { recursive: true });
    for (const name of ['ipm-manifest.mjs', 'screen-mirror.mjs', 'strings.mjs']) {
      copyFileSync(join(here, name), join(tools, name));
    }

    // realpathSync, not the temp path as handed out: the module's own run-me guard compares
    // import.meta.url -- which Node reports resolved -- with argv[1], and on a platform whose
    // temp directory is a symlink the two differ and main() silently never runs.
    const script = realpathSync(join(tools, 'ipm-manifest.mjs'));
    const run = spawnSync(process.execPath, [script, '--check'], { cwd: tools, encoding: 'utf8' });

    assert.equal(run.status, 1, `a drifted manifest is a non-zero exit: ${run.stdout}${run.stderr}`);
    assert.match(run.stderr, /ipm-manifest: found violations --/, 'and says so on stderr');
    assert.match(run.stderr, /module\.xml/, 'naming the file that drifted');
    assert.match(run.stderr, /ipm-manifest: \d+ violation\(s\)/, 'and how many');
    assert.match(
      run.stdout,
      /^ipm-manifest: compared \d+ package\(s\), \d+ application\(s\), \d+ resource\(s\), \d+ class\(es\)$/m,
      'while still reporting what it looked at -- a refusal that reported nothing is the failure this line exists to rule out'
    );
    assert.doesNotMatch(run.stdout, /up to date/, 'and never claims the manifest is current');
  });
});

test('an unrecognized argument is refused rather than silently rewriting the manifest', () => {
  // `--check` is the only flag, and the default is the write path, so a typo'd gate flag used
  // to regenerate a committed file and exit 0 where the caller asked for a drift report.
  const before = readFileSync(MANIFEST_PATH, 'utf8');
  const run = spawnSync(process.execPath, [join(here, 'ipm-manifest.mjs'), '--chek'], {
    cwd: join(here, '..'),
    encoding: 'utf8',
  });

  assert.equal(run.status, 1, 'an unknown flag is a refusal');
  assert.match(run.stderr, /unknown argument --chek/, 'and names the argument it did not understand');
  assert.equal(readFileSync(MANIFEST_PATH, 'utf8'), before, 'and writes nothing');
});

test('the roster\'s bundle source is the directory the Angular build actually writes', () => {
  // A third, differently-keyed population: `bundle.source` is the one manifest field that
  // points at the build output, and the drift check cannot see it -- it regenerates from the
  // roster, so an edit moves both sides of that equality together. angular.json is where the
  // path is really decided.
  const roster = readRoster(readFileSync(ROSTER_SOURCE, 'utf8'));
  assert.ok(roster, 'the shipped roster parses');

  const angular = JSON.parse(readFileSync(join(here, '..', 'angular.json'), 'utf8'));
  const outputPath = angular.projects['ocupilot-ui'].architect.build.options.outputPath;
  assert.ok(outputPath, 'angular.json declares an outputPath');

  assert.equal(
    roster.bundle.source,
    `ui/${outputPath}/browser/`,
    'the <FileCopy> source is angular.json\'s outputPath plus the browser directory'
  );
});

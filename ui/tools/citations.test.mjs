// The gate over every EXPERIENCE.md citation in source that is not `strings.ts`'s own
// key/value-resolved form (DW-272).
//
// **What was wrong.** 120 prose citations in `ui/src/**/*.ts` named a line number, and 111 of them
// were stale: every Fixed-strings row a story inserted moved every citation below it, and only
// `strings.ts`'s gated comments were ever repaired -- because they are the only ones anything
// checked. A wrong line number is worse than none: it sends the next reader to an unrelated row,
// silently, and the rows most often inserted are exactly the ones a citation is most likely to be
// about. Sixty of the 120 carried an adjacent quotation, and two of those sixty landed on the line
// they cited.
//
// **Why an anchor rather than a repaired number.** Widening `strings.test.mjs`'s resolver to prose
// cannot assert what it asserts there: a prose citation has no key/value pair to resolve by, so
// the only line-based check available is "the cited line is non-blank", which 101 of the 111 stale
// citations would still have passed. Dropping the numbers leaves nothing to check at all. A quoted
// phrase from the cited line is a claim that resolves, and it is immune to the insertion that
// caused the rot -- which is exactly what AC-E asks of it.
//
// Mutations (Rule 19):
// - change one word inside one cited phrase in EXPERIENCE.md -> the first test goes red naming the
//   file, the line and the phrase.
// - insert a Fixed strings row above a cited line -> everything stays green, which is the point.
// - cite the document by a colon and a line number anywhere outside `strings.ts`'s gated form ->
//   the third test goes red naming that file and line. (This file cannot write that example out,
//   because it walks itself.)
//
// **What these tests do NOT reach**, stated so the next reader does not over-trust them. A
// continuation reference that names no document, such as a sentence that says `EXPERIENCE.md
// "phrase"` and then refers to `` `:582` `` further on: those carry no document name to key off,
// and a bare `` `:NNN` `` pattern would fire on every DESIGN.md and epics.md citation in the tree.
// A line number written without a colon (`EXPERIENCE.md line 590`) for the same reason. And a
// quotation that wraps to the next source line, since both patterns are line-oriented. Several
// such continuations remain in `ui/src/app/shell/`; they are ledgered, not gated.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, relative } from 'node:path';

const toolsDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(toolsDir, '..', '..');
const experiencePath = join(
  repoRoot,
  '_bmad-output',
  'planning-artifacts',
  'ux-designs',
  'ux-OcuPilot-2026-09-08',
  'EXPERIENCE.md'
);

const experience = readFileSync(experiencePath, 'utf8');

/**
 * The trees a citation may appear in. `src/OcuPilot/` is here as well as `ui/`: the ObjectScript
 * descriptors and their tests cite the same document, and a gate that covered only the client
 * would leave the other half of the tree rotting exactly as before.
 */
const ROOTS = [
  { dir: join(repoRoot, 'ui', 'src'), suffixes: ['.ts', '.scss'] },
  { dir: join(repoRoot, 'ui', 'tools'), suffixes: ['.mjs'] },
  { dir: join(repoRoot, 'ui', 'browser'), suffixes: ['.mjs'] },
  { dir: join(repoRoot, 'src', 'OcuPilot'), suffixes: ['.cls', '.mac', '.inc'] },
  { dir: join(repoRoot, 'scripts'), suffixes: ['.py', '.sh'] },
];

/** The one place a bare `EXPERIENCE.md:<n>` is still correct: see the header. */
const GATED_FILE = join(repoRoot, 'ui', 'src', 'app', 'core', 'strings.ts');

/** `strings.ts`'s own gated form, which `strings.test.mjs` resolves by value rather than by line. */
const GATED_LINE = /^\s*\/\*\* EXPERIENCE\.md:\d+ \*\/\s*$/;

/**
 * An anchored citation: the document's name, then one or more quoted phrases from it.
 *
 * The quotes do not have to abut the name. `EXPERIENCE.md's Session table ("Cold start, silent
 * probe in flight")` is the same claim, and an adjacency-only pattern silently left six such
 * citations -- two of them converted by this story -- resolved by nothing at all. The window is
 * the same shape `BARE` uses: at most 40 characters, crossing neither another document's name nor
 * a quote of its own, so a quoted literal that has nothing to do with this document cannot be
 * dragged in.
 */
const ANCHORED = /EXPERIENCE\.md(?:<\/file>)?(?:'s)?(?:(?!\.md)[^"\n]){0,40}?((?:\s*"[^"\n]+",?)+)/g;

/**
 * A citation that still names a line number.
 *
 * The number does not have to abut the document's name: `EXPERIENCE.md's Session table
 * (`:490-499`)` is the same claim with the same rot, and an adjacency-only pattern let two of
 * those through this gate's first pass. So the window is widened to 40 characters, tempered so it
 * cannot cross another document's name -- without that, an anchored citation followed on the same
 * line by `DESIGN.md:1039` would be reported as a bare EXPERIENCE.md citation.
 */
const BARE = /EXPERIENCE\.md(?:<\/file>)?(?:'s)?(?:(?!\.md)[^\n]){0,40}?`?:\d+/;

function walk(dir) {
  const found = [];
  for (const entry of readdirSync(dir)) {
    if (entry === 'node_modules' || entry === 'dist') continue;
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) found.push(...walk(full));
    else found.push(full);
  }
  return found;
}

/** Every source file a citation may live in, with its text. */
function sources() {
  const files = [];
  for (const root of ROOTS) {
    let entries;
    try {
      entries = walk(root.dir);
    } catch {
      continue;
    }
    for (const full of entries) {
      if (!root.suffixes.some((suffix) => full.endsWith(suffix))) continue;
      files.push({ path: full, rel: relative(repoRoot, full), text: readFileSync(full, 'utf8') });
    }
  }
  return files;
}

const FILES = sources();

test('the citation gate reads a non-empty population, so a scan over nothing is not a pass', () => {
  assert.ok(FILES.length > 100, `expected the source trees to be walked, found ${FILES.length} file(s)`);
  const anchored = FILES.reduce(
    (count, file) => count + [...file.text.matchAll(ANCHORED)].length,
    0
  );
  assert.ok(anchored > 100, `expected the anchored citations to be found, matched ${anchored}`);
});

test('every anchored EXPERIENCE.md citation quotes a phrase that is in EXPERIENCE.md exactly once', () => {
  const wrong = [];
  for (const file of FILES) {
    const lines = file.text.split('\n');
    for (let index = 0; index < lines.length; index += 1) {
      for (const match of lines[index].matchAll(ANCHORED)) {
        for (const phrase of match[1].matchAll(/"([^"\n]+)"/g)) {
          const text = phrase[1];
          const hits = experience.split(text).length - 1;
          if (hits === 1) continue;
          wrong.push(
            `${file.rel}:${index + 1}: the cited phrase ${JSON.stringify(text)} occurs ` +
              `${hits} time(s) in EXPERIENCE.md, not once`
          );
        }
      }
    }
  }
  assert.deepEqual(
    wrong,
    [],
    `citations that no longer resolve:\n${wrong.join('\n')}\n\n` +
      'Re-anchor each to a phrase the document still carries -- never to a line number.'
  );
});

test("no source outside strings.ts's gated form cites EXPERIENCE.md by line number", () => {
  const bare = [];
  for (const file of FILES) {
    const lines = file.text.split('\n');
    for (let index = 0; index < lines.length; index += 1) {
      const line = lines[index];
      if (!BARE.test(line)) continue;
      if (file.path === GATED_FILE && GATED_LINE.test(line)) continue;
      bare.push(`${file.rel}:${index + 1}: ${line.trim()}`);
    }
  }
  assert.deepEqual(
    bare,
    [],
    `line-number citations outside strings.ts's gated form:\n${bare.join('\n')}\n\n` +
      'A number is a claim that rots when a row is inserted above it; quote a phrase instead.'
  );
});

test("strings.ts's own gated citations are still the only line-numbered ones, and there are many", () => {
  // The converse of the test above: the 201 comments `strings.test.mjs` resolves by value are
  // deliberately left as they are, and this says so as a number rather than as a comment -- so
  // converting them by accident, or dropping the gate that resolves them, is visible here.
  const gated = readFileSync(GATED_FILE, 'utf8')
    .split('\n')
    .filter((line) => GATED_LINE.test(line)).length;
  assert.ok(gated > 150, `expected strings.ts to keep its gated citations, counted ${gated}`);
});

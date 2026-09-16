#!/usr/bin/env python3
"""Three prose checks markdownlint cannot make, for OcuPilot's authored documents.

1. Given/When/Then clauses written as plain paragraph lines. CommonMark fuses
   consecutive plain lines into one paragraph, so acceptance criteria written
   that way render as a run-on blob. This repo once shipped 2,587 such lines
   fused into 26 paragraphs, the worst a single 1,323-word one. Written as list
   items (`- **Given** ...`) they render correctly, so that is what this
   enforces.

2. British spellings. Three of the 61 found in epics.md contradicted the
   document's own canonical UI strings -- prose said "cancelled" beside the
   button label "Canceled".

3. Implementation-spec structure: the template's headings present and in
   order, and backticks and fences balanced. A spec is an authored deliverable
   a reviewer reads and a later story mines, and an unclosed fence hides
   everything after it.

Checks 1 and 2 ignore fenced code blocks, inline code spans, and link targets.

Usage:
    uv run scripts/check-prose.py [PATH ...]
    uv run scripts/check-prose.py --list      # print the document set

With no arguments it checks the same document set as .markdownlint-cli2.jsonc.
Exits 1 if anything is found.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# Same scope as .markdownlint-cli2.jsonc -- keep the two in step.
DEFAULT_GLOBS = (
    "*.md",
    "docs/**/*.md",
    ".claude/rules/*.md",
    "_bmad-output/planning-artifacts/epics.md",
    "_bmad-output/planning-artifacts/prds/**/prd.md",
    "_bmad-output/planning-artifacts/prds/**/addendum.md",
    "_bmad-output/planning-artifacts/architecture/**/ARCHITECTURE-SPINE.md",
    "_bmad-output/planning-artifacts/architecture/**/C4.md",
    "_bmad-output/planning-artifacts/ux-designs/**/DESIGN.md",
    "_bmad-output/planning-artifacts/ux-designs/**/EXPERIENCE.md",
    "_bmad-output/specs/**/SPEC.md",
    # The implementation specs. They are authored deliverables that reviewers read and later
    # stories mine, and they were absent from this set by omission rather than by decision
    # (DW-384): every one of them shipped unlinted while the documents they are derived from
    # were checked on every commit.
    "_bmad-output/implementation-artifacts/spec-*.md",
)

# Vendor trees and installed kits: not ours to reformat. Matched against the
# repo-relative path, so a root glob cannot drag them in.
IGNORE_PREFIXES = (
    "_bmad/",
    ".claude/skills/",
    ".claude/commands/",
    "irislib/",
    "irissys/",
    "irisui/",
    "irisdocs/",
    "node_modules/",
)
IGNORE_FILES = ("epic-cycle-workflow-creation.md",)

# British -> US. Explicit pairs only: a blanket "-ise" rule would flag "precise",
# "otherwise", "enterprise" and a hundred other legitimate words.
BRITISH = {
    "cancelled": "canceled",
    "cancelling": "canceling",
    "licence": "license",
    "defence": "defense",
    "centre": "center",
    "colour": "color",
    "behaviour": "behavior",
    "favourite": "favorite",
    "labelled": "labeled",
    "labelling": "labeling",
    "modelled": "modeled",
    "travelled": "traveled",
    "fulfil": "fulfill",
    "enrol": "enroll",
    "catalogue": "catalog",
    "grey": "gray",
    "analyse": "analyze",
    "analysed": "analyzed",
    "authorise": "authorize",
    "categorise": "categorize",
    "customise": "customize",
    "initialise": "initialize",
    "maximise": "maximize",
    "minimise": "minimize",
    "normalise": "normalize",
    "optimise": "optimize",
    "organisation": "organization",
    "prioritise": "prioritize",
    "realise": "realize",
    "recognise": "recognize",
    "serialise": "serialize",
    "standardise": "standardize",
    "summarise": "summarize",
    "synchronisation": "synchronization",
    "synchronise": "synchronize",
    "utilise": "utilize",
    "visualise": "visualize",
}
BRITISH_RE = re.compile(
    r"\b(" + "|".join(sorted(BRITISH, key=len, reverse=True)) + r")\b", re.IGNORECASE
)

# The headings an implementation spec carries, in the order the template lays them out. A spec
# missing one, or carrying them out of order, is a spec a reader cannot navigate and a later story
# cannot mine -- and the template's own budget lines are keyed to these names.
#
# `## Auto Run Result` is deliberately absent: a spec that has not been run yet does not have one,
# and requiring it would fail every spec at the moment it is written. The headings below are the
# ones present from the first draft onward.
SPEC_HEADINGS = (
    "## Intent",
    "## Boundaries & Constraints",
    "## I/O & Edge-Case Matrix",
    "## Code Map",
    "## Tasks & Acceptance",
    "## Design Notes",
    "## Verification",
)

SPEC_NAME_RE = re.compile(r"^spec-.*\.md$")

GWT_BOLD = re.compile(r"^\s*\*\*(Given|When|Then|And)\*\*")
GWT_PLAIN = re.compile(r"^\s*(Given|When|Then)\s")
LIST_ITEM = re.compile(r"^\s*([-*+]|\d+[.)])\s")
HEADING = re.compile(r"^\s*#{1,6}\s")
FENCE = re.compile(r"^\s*(```|~~~)")

INLINE_CODE = re.compile(r"`[^`]*`")
LINK_TARGET = re.compile(r"\]\([^)]*\)")
URL = re.compile(r"https?://\S+")


def strip_code(line: str) -> str:
    """Blank out spans where a British-looking word is legitimate."""
    line = INLINE_CODE.sub(" ", line)
    line = LINK_TARGET.sub(" ", line)
    return URL.sub(" ", line)


BACKTICK_RUN = re.compile(r"`+")


def unpaired_backticks(path: Path, block: list[tuple[int, str]]) -> list[str]:
    """Every backtick run in `block` that opens no code span, as one problem per run.

    `block` is the (line number, text) pairs of one paragraph. Runs are paired the way CommonMark
    pairs them: a run of N backticks closes at the next run of exactly N, and anything between --
    including shorter runs -- is the span's content.
    """
    runs: list[tuple[int, int]] = []
    for line_no, raw in block:
        for m in BACKTICK_RUN.finditer(raw):
            runs.append((line_no, len(m.group(0))))
    problems: list[str] = []
    i = 0
    while i < len(runs):
        closer = next((j for j in range(i + 1, len(runs)) if runs[j][1] == runs[i][1]), None)
        if closer is None:
            problems.append(
                f"{path}:{runs[i][0]}: a run of {runs[i][1]} backtick(s) here closes nothing in "
                f"this block -- it renders as a literal backtick, and the next code span's opener "
                f"pairs with the one before it instead, so the prose between them renders as code"
            )
            i += 1
            continue
        i = closer + 1
    return problems


def check_spec_structure(path: Path, lines: list[str]) -> list[str]:
    """An implementation spec's required headings are present and in order, and its backticks and
    fences balance.

    Both halves are about a document a reader and a later story have to navigate. A missing or
    reordered heading breaks the template's own contract; an unbalanced fence swallows everything
    after it into a code block, and an odd number of inline backticks turns the rest of a
    paragraph into a code span -- neither of which renders as anything a reviewer would file a
    finding against, because the text simply is not there any more.
    """
    problems: list[str] = []

    # Headings, in order. Compared as a subsequence over the document's own `##` lines, so a spec
    # that adds a heading of its own between two required ones is fine and one that drops or
    # reorders a required one is not.
    seen = []
    scanning_fence = False
    for raw in lines:
        if FENCE.match(raw):
            scanning_fence = not scanning_fence
            continue
        # A `## ` line inside a fenced block is an example, not a heading: a spec that shows the
        # template's own headings in a code block would otherwise satisfy the order check without
        # carrying any of them.
        if not scanning_fence and raw.startswith("## "):
            seen.append(raw.strip())
    at = 0
    for heading in SPEC_HEADINGS:
        try:
            at = seen.index(heading, at) + 1
        except ValueError:
            problems.append(
                f"{path}: required heading {heading!r} is missing, or appears before a heading "
                f"the template puts earlier; the order is {', '.join(SPEC_HEADINGS)}"
            )
            # Keep scanning from where we were: one displaced heading should not cascade into a
            # complaint about every heading after it.

    # Fences, and unpaired backtick runs outside them.
    #
    # **Paired the way CommonMark pairs them, over a block rather than a line.** A code span opens
    # with a run of N backticks and closes at the next run of exactly N, wherever that falls --
    # across a line break, and over any shorter run in between. So a per-line count reports every
    # wrapped span as a defect, and a naive total reports every ``literal ` backtick`` as one.
    #
    # What is left over after that pairing is a run that opens nothing. CommonMark renders it as a
    # literal backtick, which is not a crash and is exactly why it survives review: what it
    # actually does is pair the *next* intended opener with the one before it, so the prose between
    # two code spans renders as code and the reader never sees it.
    in_fence = False
    fence_opened_at = 0
    block: list[tuple[int, str]] = []
    for i, raw in enumerate(lines):
        if FENCE.match(raw):
            # A fence ends the paragraph block, exactly as a blank line does. Without this flush
            # the prose before a fence and the prose after it share one block, so a stray backtick
            # on each side pairs with the other and both go unreported -- the pairing this check
            # exists to find, cancelled by the fence between them.
            problems.extend(unpaired_backticks(path, block))
            block = []
            in_fence = not in_fence
            if in_fence:
                fence_opened_at = i + 1
            continue
        if in_fence:
            continue
        if raw.strip() == "":
            problems.extend(unpaired_backticks(path, block))
            block = []
            continue
        block.append((i + 1, raw))
    problems.extend(unpaired_backticks(path, block))
    if in_fence:
        problems.append(
            f"{path}:{fence_opened_at}: this code fence is never closed, so everything after it "
            f"renders as code"
        )
    return problems


def check(path: Path) -> list[str]:
    problems: list[str] = []
    lines = path.read_text(encoding="utf-8").splitlines()

    if SPEC_NAME_RE.match(path.name):
        problems.extend(check_spec_structure(path, lines))

    in_fence = False
    for i, raw in enumerate(lines):
        if FENCE.match(raw):
            in_fence = not in_fence
            continue
        if in_fence or HEADING.match(raw):
            continue

        # 1. Fusing Given/When/Then clauses.
        if not LIST_ITEM.match(raw):
            nxt = lines[i + 1] if i + 1 < len(lines) else ""
            prv = lines[i - 1] if i else ""
            adjacent = bool(nxt.strip()) or bool(prv.strip())
            fusing = GWT_BOLD.match(raw) or (
                GWT_PLAIN.match(raw)
                and (GWT_PLAIN.match(nxt) or GWT_BOLD.match(nxt))
            )
            if fusing and adjacent:
                problems.append(
                    f"{path}:{i + 1}: Given/When/Then clause is a plain line, not a "
                    f"list item -- CommonMark will fuse it into the neighbouring "
                    f"paragraph. Write it as `- {raw.strip()[:40]}...`"
                )

        # 2. British spellings.
        for m in BRITISH_RE.finditer(strip_code(raw)):
            found = m.group(1)
            problems.append(
                f"{path}:{i + 1}: British spelling {found!r} -- "
                f"use {BRITISH[found.lower()]!r}"
            )

    return problems


def resolve(argv: list[str]) -> list[Path]:
    root = Path(__file__).resolve().parent.parent
    if argv:
        return [Path(a) for a in argv if Path(a).suffix == ".md" and Path(a).is_file()]
    seen: dict[Path, None] = {}
    for pattern in DEFAULT_GLOBS:
        for p in sorted(root.glob(pattern)):
            if not p.is_file():
                continue
            rel = p.relative_to(root).as_posix()
            if rel in IGNORE_FILES or rel.startswith(IGNORE_PREFIXES):
                continue
            seen[p] = None
    return list(seen)


def main() -> int:
    argv = sys.argv[1:]
    if argv and argv[0] == "--list":
        # scripts/lint-docs.sh uses this so the document set is defined once.
        for p in resolve([]):
            print(p)
        return 0

    paths = resolve(argv)
    if not paths:
        print("check-prose: no markdown files to check")
        return 0

    problems: list[str] = []
    for p in paths:
        problems.extend(check(p))

    for line in problems:
        print(line)
    print(
        f"\ncheck-prose: {len(problems)} problem(s) in {len(paths)} file(s)",
        file=sys.stderr,
    )
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())

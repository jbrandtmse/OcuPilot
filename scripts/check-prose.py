#!/usr/bin/env python3
"""Two prose checks markdownlint cannot make, for OcuPilot's authored documents.

1. Given/When/Then clauses written as plain paragraph lines. CommonMark fuses
   consecutive plain lines into one paragraph, so acceptance criteria written
   that way render as a run-on blob. This repo once shipped 2,587 such lines
   fused into 26 paragraphs, the worst a single 1,323-word one. Written as list
   items (`- **Given** ...`) they render correctly, so that is what this
   enforces.

2. British spellings. Three of the 61 found in epics.md contradicted the
   document's own canonical UI strings -- prose said "cancelled" beside the
   button label "Canceled".

Both checks ignore fenced code blocks, inline code spans, and link targets.

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


def check(path: Path) -> list[str]:
    problems: list[str] = []
    lines = path.read_text(encoding="utf-8").splitlines()

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

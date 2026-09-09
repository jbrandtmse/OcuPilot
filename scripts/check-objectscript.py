#!/usr/bin/env python3
"""Mechanical gate over `src/OcuPilot/**` and `ui/**`, turning four ACs that read as
prose into one checker.

1. **Rename-checklist tokens.** None of the sibling repositories' own names, paths,
   roles, globals or environment variables may appear anywhere in this tree — see the
   "Rename checklist" table in
   `_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/harvest/HARVEST-PLAN.md`.
   Includes any `IRIS_*` environment variable and the vendor's `%Atelier` package (a
   forbidden-token guard standing in for a coupling `OcuPilot.Kernel.Utils` never had to
   drop — see that story's Design Notes).

2. **Naming.** No `%` or `_` in a declared class or property name; no `_` in a declared
   class parameter or method name (`.claude/rules/objectscript-basics.md` — the `%` ban is
   deliberately narrower than "_": methods and class parameters both keep it clear so a
   standard IRIS framework callback like `%OnNew` or `%OnValidateObject` — required,
   verbatim, by the framework's own dispatch, and already discussed as a pattern this
   project's test classes may need in `.claude/rules/objectscript-testing.md` — is never
   flagged as a naming violation); a class name, package dots included, no longer than 29
   characters (the storage-global hashing bound); every declared method parameter starts
   with `p`.

3. **Write discipline (AD-12).** A bare `Write` command may appear only in
   `OcuPilot/Api/Response.cls` and `OcuPilot/Api/Error.cls` — the tree's one response
   writer and one error writer. A `Write` reached through a dotted method call
   (`%response.Write(...)`, `stream.Write(...)`) is not this command and is not flagged;
   only the bare command is.

4. **Package placement.** Every class under `src/OcuPilot/` lives in one of the seven
   fixed package folders the spine fixes (`Api`, `Kernel`, `Screen`, `Area`, `Port`,
   `Install`, `Test`) — the class's own declared package, not just its file's directory.

This checker is deliberately line-oriented rather than a full UDL parser: it is exact
enough to catch the violations above and cheap enough to run on every commit and every
CI build. `.githooks/pre-commit` runs it on staged `.cls`/`.mac`/`.inc`/`ui` files;
`bash scripts/lint-docs.sh` and this script together are the two mechanical document/code
gates this repository has.

Usage:
    uv run scripts/check-objectscript.py

Exits 1 if anything is found; exits 0 (silently, besides the trailing summary line) when
the tree is clean.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCAN_ROOTS = (ROOT / "src" / "OcuPilot", ROOT / "ui")

# Build artifacts and VCS internals: never walked, regardless of whether they exist yet.
PRUNE_DIRS = {"node_modules", "dist", ".angular", ".git"}

# The only two classes AD-12 permits to Write to the response device.
WRITE_ALLOWED = {
    "src/OcuPilot/Api/Response.cls",
    "src/OcuPilot/Api/Error.cls",
}

MAX_CLASS_NAME_LENGTH = 29

# The seven fixed ObjectScript package folders the spine fixes (AC: "every project class
# lives under src/OcuPilot/ in one of the seven fixed package folders").
FIXED_PACKAGES = {"Api", "Kernel", "Screen", "Area", "Port", "Install", "Test"}

# --- Rename-checklist tokens (HARVEST-PLAN.md's "Rename checklist" table) ------------

FORBIDDEN_LITERALS = (
    "IRISCouch",
    "SessionAgent",
    "ExecuteMCPv2",
    "/iris-couch/",
    "^IRISCouchTest",
    "^UnitTestRoot",
    "sa-static",
    "/api/executemcp/v2",
    "iris_",
    "%Atelier",
)
ENV_VAR_RE = re.compile(r"\bIRIS_[A-Z0-9_]*\b")

# --- ObjectScript declaration shapes --------------------------------------------------

CLASS_RE = re.compile(r"^Class\s+([A-Za-z0-9_.%]+)", re.MULTILINE)
PROPERTY_RE = re.compile(r"^Property\s+([A-Za-z0-9_%]+)\b", re.MULTILINE)
PARAMETER_RE = re.compile(r"^Parameter\s+([A-Za-z0-9_%]+)\b", re.MULTILINE)
METHOD_RE = re.compile(r"^(?:Class)?Method\s+([A-Za-z0-9_%]+)\s*\(([^)]*)\)", re.MULTILINE)
PARAM_PREFIX_RE = re.compile(r"^(?:Output|ByRef)\s+")
PARAM_NAME_RE = re.compile(r"^([A-Za-z0-9_%]+)")

# A bare Write command: not preceded by "." (a method call) or another word character.
WRITE_RE = re.compile(r"(?<![.\w])Write\b")
XDATA_START_RE = re.compile(r"^\s*XData\s+\S+")


def line_of(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def iter_source_files():
    for root in SCAN_ROOTS:
        if not root.exists():
            continue
        for p in sorted(root.rglob("*")):
            if not p.is_file():
                continue
            if any(part in PRUNE_DIRS for part in p.relative_to(ROOT).parts):
                continue
            yield p


def iter_objectscript_files():
    for p in iter_source_files():
        if p.suffix in (".cls", ".mac", ".inc"):
            yield p


def read_text(path: Path) -> str | None:
    try:
        return path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        return None


def check_rename_tokens(problems: list[str]) -> None:
    for p in iter_source_files():
        text = read_text(p)
        if text is None:
            continue
        rel = p.relative_to(ROOT).as_posix()
        for token in FORBIDDEN_LITERALS:
            if token not in text:
                continue
            for i, line in enumerate(text.splitlines(), start=1):
                if token in line:
                    problems.append(f"{rel}:{i}: forbidden rename-checklist token {token!r}")
        for m in ENV_VAR_RE.finditer(text):
            problems.append(
                f"{rel}:{line_of(text, m.start())}: forbidden IRIS_* environment variable reference {m.group(0)!r}"
            )


def extract_param_names(paramlist: str) -> list[str]:
    names = []
    for raw in paramlist.split(","):
        tok = PARAM_PREFIX_RE.sub("", raw.strip())
        m = PARAM_NAME_RE.match(tok)
        if m:
            names.append(m.group(1))
    return names


def check_naming(problems: list[str]) -> None:
    for p in iter_objectscript_files():
        text = read_text(p)
        if text is None:
            continue
        rel = p.relative_to(ROOT).as_posix()

        for m in CLASS_RE.finditer(text):
            name = m.group(1)
            ln = line_of(text, m.start())
            for part in name.split("."):
                if "%" in part or "_" in part:
                    problems.append(f"{rel}:{ln}: class name component {part!r} contains % or _ (in {name})")
            if len(name) > MAX_CLASS_NAME_LENGTH:
                problems.append(
                    f"{rel}:{ln}: class name {name!r} is {len(name)} characters, "
                    f"over the {MAX_CLASS_NAME_LENGTH}-character limit"
                )

        for m in PROPERTY_RE.finditer(text):
            name = m.group(1)
            if "%" in name or "_" in name:
                problems.append(f"{rel}:{line_of(text, m.start())}: property name {name!r} contains % or _")

        for m in PARAMETER_RE.finditer(text):
            name = m.group(1)
            # Only "_" is banned here (not "%") — matching objectscript-basics.md, which
            # bans "_" in class parameter names but never extends the "%" ban past class
            # and property names.
            if "_" in name:
                problems.append(f"{rel}:{line_of(text, m.start())}: class parameter name {name!r} contains _")

        for m in METHOD_RE.finditer(text):
            name, paramlist = m.group(1), m.group(2)
            ln = line_of(text, m.start())
            # Only "_" is banned here (not "%") — a standard IRIS framework callback
            # (%OnNew, %OnValidateObject, %OnDelete, ...) is a legitimate, framework-
            # required method name and must never be flagged.
            if "_" in name:
                problems.append(f"{rel}:{ln}: method name {name!r} contains _")
            for pname in extract_param_names(paramlist):
                if not pname.startswith("p"):
                    problems.append(f"{rel}:{ln}: method {name!r} parameter {pname!r} does not start with p")


def check_package_placement(problems: list[str]) -> None:
    for p in iter_objectscript_files():
        if p.suffix != ".cls":
            continue
        rel = p.relative_to(ROOT).as_posix()
        if not rel.startswith("src/OcuPilot/"):
            continue
        text = read_text(p)
        if text is None:
            continue
        for m in CLASS_RE.finditer(text):
            name = m.group(1)
            ln = line_of(text, m.start())
            parts = name.split(".")
            if len(parts) < 3 or parts[0] != "OcuPilot" or parts[1] not in FIXED_PACKAGES:
                problems.append(
                    f"{rel}:{ln}: class {name!r} is not under one of the seven fixed "
                    f"OcuPilot package folders ({', '.join(sorted(FIXED_PACKAGES))})"
                )


def check_write_discipline(problems: list[str]) -> None:
    # XData tracking is a 3-state machine, not a flag, because the UDL convention (used
    # throughout this tree) puts the opening "{" on the line AFTER the "XData Name [...]"
    # declaration line, not on it — computing brace depth only from the declaration line
    # itself (as an earlier version of this function did) always saw a depth of 0 there
    # and so never actually recognized any XData body as one.
    AWAITING_OPEN, INSIDE = "awaiting_open", "inside"

    for p in iter_objectscript_files():
        if p.suffix != ".cls":
            continue
        rel = p.relative_to(ROOT).as_posix()
        if rel in WRITE_ALLOWED:
            continue
        text = read_text(p)
        if text is None:
            continue

        xdata_state = None
        xdata_depth = 0
        in_block_comment = False
        for i, raw in enumerate(text.splitlines(), start=1):
            if in_block_comment:
                if "*/" in raw:
                    in_block_comment = False
                continue
            stripped = raw.strip()
            if stripped.startswith("/*") and "*/" not in raw:
                in_block_comment = True
                continue

            if xdata_state == AWAITING_OPEN:
                if "{" in raw:
                    xdata_depth = raw.count("{") - raw.count("}")
                    xdata_state = INSIDE if xdata_depth > 0 else None
                continue

            if xdata_state == INSIDE:
                xdata_depth += raw.count("{") - raw.count("}")
                if xdata_depth <= 0:
                    xdata_state = None
                continue

            if XDATA_START_RE.match(raw):
                if "{" in raw:
                    xdata_depth = raw.count("{") - raw.count("}")
                    xdata_state = INSIDE if xdata_depth > 0 else None
                else:
                    xdata_state = AWAITING_OPEN
                continue

            if stripped.startswith("///") or stripped.startswith(";"):
                continue
            if WRITE_RE.search(raw):
                problems.append(f"{rel}:{i}: bare Write statement outside Api/Response.cls and Api/Error.cls")


def main() -> int:
    problems: list[str] = []
    check_rename_tokens(problems)
    check_naming(problems)
    check_write_discipline(problems)
    check_package_placement(problems)

    for line in problems:
        print(line)
    print(f"\ncheck-objectscript: {len(problems)} problem(s)", file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())

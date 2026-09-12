#!/usr/bin/env python3
"""Mechanical gate over `src/OcuPilot/**` and `ui/**`, turning eight ACs that read as
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
   flagged as a naming violation); **a class that gets a data global** — one that extends
   `%Persistent`, directly or through another class in this tree — has a name, package dots
   included, no longer than 29 characters (the storage-global hashing bound); every declared
   method parameter starts with `p`.

   The cap binds storage classes and nothing else. It exists to protect the natural
   `^<Class>D` global a `%Persistent` class is given, and a class with no storage has no such
   global: screen descriptors, ports, handlers, fixtures and test classes are not capped
   (Consistency Conventions, scoped 2026-09-12 — `OcuPilot.Screen.Descriptor.` alone spends
   27 of the 29). Superclasses are read from the `Extends` clause and followed transitively
   through this tree's own classes; a class extending a **vendor** persistent class this
   scanner never reads is not recognized, which is this line-oriented checker's scope rather
   than a claim about every storage class.

3. **Write discipline (AD-12).** A bare `Write` command may appear only in
   `OcuPilot/Api/Response.cls` and `OcuPilot/Api/Error.cls` — the tree's one response
   writer and one error writer. A `Write` reached through a dotted method call
   (`%response.Write(...)`, `stream.Write(...)`) is not this command and is not flagged;
   only the bare command is.

4. **Package placement.** Every class under `src/OcuPilot/` lives in one of the seven
   fixed package folders the spine fixes (`Api`, `Kernel`, `Screen`, `Area`, `Port`,
   `Install`, `Test`) — the class's own declared package, not just its file's directory.

5. **Product vocabulary (Story 1.2).** `co-pilot` is rejected everywhere in this tree
   unless immediately preceded by the word `agent` (either case) — "the feature is
   always the agent co-pilot" (`EXPERIENCE.md:623`).

6. **Escalation containment (AD-9, Story 1.3, AC6).** `New $ROLES` and
   `$SYSTEM.Security.AddRoles` may appear only in `OcuPilot/Kernel/State/Base.cls` and
   `OcuPilot/Test/State.cls` — the tree's one escalation point and the one test class
   that impersonates a denied user to prove it. Every other file is refused the moment
   either token appears in it, mechanically enforcing AD-9's "the storage classes, and
   only the storage classes" rather than leaving it to review.

7. **No spawn, no re-entry from `Kernel/State/` (AD-9's two ordering rules, Story 1.3,
   AC6).** A file under `OcuPilot/Kernel/State/` may contain no `JOB` command (nothing
   is spawned from inside an escalated frame, since a job inherits `$ROLES` at the
   moment of the spawn and a `New $ROLES` in the parent never reaches it) and no
   reference to `OcuPilot.Api`, `OcuPilot.Port`, `OcuPilot.Screen` or `OcuPilot.Area`
   (nothing re-enters from inside an escalated frame).

8. **Entity types (AD-14, Story 1.9).** Every entity type named in a screen descriptor's
   `XData Declaration` block exists in `src/OcuPilot/Kernel/EntityType.cls`'s closed `TYPES`
   parameter — the "build fails on a value not in it" mechanism, in the tree rather than only
   on the instance. The rule reads XData bodies, which `iter_code_lines` deliberately skips,
   so it uses `iter_non_comment_lines`. A missing or unreadable `EntityType.cls` is reported,
   never treated as an empty vocabulary that admits everything.

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

# The class declaration, with the `Extends` clause the cap in check_naming needs to tell a
# storage class from every other kind. Both spellings IRIS accepts are captured: one
# superclass bare, or several inside parentheses. Everything after it (the `[ Abstract ]`
# keyword list) is left alone.
CLASS_RE = re.compile(
    r"^Class\s+([A-Za-z0-9_.%]+)(?:\s+Extends\s+(\([^)]*\)|[A-Za-z0-9_.%]+))?",
    re.MULTILINE,
)

# The roots that give a class a data global. `%Persistent` is `%Library.Persistent`; both
# spellings compile.
PERSISTENT_ROOTS = {"%Persistent", "%Library.Persistent"}
PROPERTY_RE = re.compile(r"^Property\s+([A-Za-z0-9_%]+)\b", re.MULTILINE)
PARAMETER_RE = re.compile(r"^Parameter\s+([A-Za-z0-9_%]+)\b", re.MULTILINE)
METHOD_RE = re.compile(r"^(?:Class)?Method\s+([A-Za-z0-9_%]+)\s*\(([^)]*)\)", re.MULTILINE)
PARAM_PREFIX_RE = re.compile(r"^(?:Output|ByRef)\s+")
PARAM_NAME_RE = re.compile(r"^([A-Za-z0-9_%]+)")

# A bare Write command: not preceded by "." (a method call) or another word character.
WRITE_RE = re.compile(r"(?<![.\w])Write\b")
XDATA_START_RE = re.compile(r"^\s*XData\s+\S+")

# Framework callbacks whose parameter names the framework's own dispatch fixes — the
# "p" prefix is not available for them. `%OnNew(initvalue)` is the one this project
# actually needs: `.claude/rules/objectscript-testing.md` requires that exact signature
# on any %UnitTest.TestCase subclass that initializes state.
FRAMEWORK_CALLBACKS = frozenset(
    {
        "%OnNew",
        "%OnClose",
        "%OnOpen",
        "%OnDelete",
        "%OnBeforeSave",
        "%OnAfterSave",
        "%OnValidateObject",
        "%OnAddToSaveSet",
        "%OnConstructClone",
        "OnBeforeAllTests",
        "OnAfterAllTests",
        "OnBeforeOneTest",
        "OnAfterOneTest",
    }
)


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


def parse_superclasses(clause: str | None) -> list[str]:
    """The superclass names in an `Extends` clause, bare or parenthesised."""
    if not clause:
        return []
    clause = clause.strip()
    if clause.startswith("(") and clause.endswith(")"):
        clause = clause[1:-1]
    return [part.strip() for part in clause.split(",") if part.strip()]


def build_superclass_graph() -> dict[str, list[str]]:
    """Every class declared in this tree, mapped to its declared superclasses."""
    graph: dict[str, list[str]] = {}
    for p in iter_objectscript_files():
        text = read_text(p)
        if text is None:
            continue
        for m in CLASS_RE.finditer(text):
            graph[m.group(1)] = parse_superclasses(m.group(2))
    return graph


def gets_data_global(name: str, graph: dict[str, list[str]]) -> bool:
    """Whether `name` extends `%Persistent`, directly or through this tree's own classes.

    Only classes this scanner has read are followed; a superclass it has never seen is a
    vendor class and is taken at its name (so `%Persistent` counts and nothing else does).
    The walk carries its own visited set, so a cycle in a malformed tree terminates.
    """
    seen: set[str] = set()
    pending = [name]
    while pending:
        current = pending.pop()
        if current in seen:
            continue
        seen.add(current)
        for parent in graph.get(current, []):
            if parent in PERSISTENT_ROOTS:
                return True
            pending.append(parent)
    return False


def check_naming(problems: list[str]) -> None:
    graph = build_superclass_graph()
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
            if len(name) > MAX_CLASS_NAME_LENGTH and gets_data_global(name, graph):
                problems.append(
                    f"{rel}:{ln}: %Persistent class name {name!r} is {len(name)} characters, "
                    f"over the {MAX_CLASS_NAME_LENGTH}-character storage-global limit"
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
            # A framework callback's parameter names are fixed by the framework's own
            # dispatch, so the "p" prefix cannot apply to them. Exempting the method
            # name alone (above) was not enough: `%OnNew(initvalue)` — the exact
            # signature `.claude/rules/objectscript-testing.md` requires on every
            # %UnitTest.TestCase subclass that needs setup state — still failed here on
            # `initvalue`, so the pattern the "%" narrowing was meant to unblock stayed
            # blocked one rule later.
            if name in FRAMEWORK_CALLBACKS:
                continue
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


def iter_code_lines(text: str):
    """Yield (line_number, raw_line) for the lines that count as code: comments
    (`///` doc comments, `;` line comments, `/* ... */` block comments) and XData
    bodies are skipped.

    XData tracking is a 3-state machine, not a flag, because the UDL convention (used
    throughout this tree) puts the opening "{" on the line AFTER the "XData Name [...]"
    declaration line, not on it — computing brace depth only from the declaration line
    itself (as an earlier version of this function did) always saw a depth of 0 there
    and so never actually recognized any XData body as one. Shared by every rule below
    that must not fire on a comment or an XData block (write discipline, escalation
    containment, state-package isolation) so the three rules cannot drift apart on what
    counts as "code".
    """
    AWAITING_OPEN, INSIDE = "awaiting_open", "inside"
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
        yield i, raw


def check_write_discipline(problems: list[str]) -> None:
    # Scans .cls, .mac and .inc alike. Restricting this to .cls (as an earlier version
    # did) left AD-12's one-writer rule silently unenforced for every project routine
    # and include file, which the docstring's stated scope does not exempt. XData
    # tracking is simply a no-op for a routine, which has no XData blocks.
    for p in iter_objectscript_files():
        rel = p.relative_to(ROOT).as_posix()
        if rel in WRITE_ALLOWED:
            continue
        text = read_text(p)
        if text is None:
            continue
        for i, raw in iter_code_lines(text):
            if WRITE_RE.search(raw):
                problems.append(f"{rel}:{i}: bare Write statement outside Api/Response.cls and Api/Error.cls")


# --- Escalation containment (AD-9, Story 1.3, AC6) ------------------------------------

# The tree's one escalation point and the one test class that impersonates a denied
# user to prove it (see that story's Design Notes and Boundaries & Constraints).
ESCALATION_ALLOWED = {
    "src/OcuPilot/Kernel/State/Base.cls",
    "src/OcuPilot/Test/State.cls",
}

# Matches "New $ROLES" and "$SYSTEM.Security.AddRoles" in the spellings IRIS itself
# accepts. Both alternatives are deliberately wider than the two literal tokens AC6's
# text names, because a gate that a one-character respelling walks past is the failure
# mode Story 1.1's DW-32 recorded ("authoring an unvalidated gate is itself the failure
# mode"), not a gate:
#   - "N $ROLES" — every ObjectScript command abbreviates to its first letter, and NEW is
#     no exception; the earlier `\bnew\s+` form matched only the spelled-out word.
#   - "##class(%SYSTEM.Security).AddRoles(...)" — $SYSTEM.Security *is* %SYSTEM.Security,
#     so this is the same call by its other, equally ordinary name. The earlier form
#     required a literal "$system.security.addroles" and the ")" between the class and
#     the method defeated it.
# Commands, special variables and class names are case-insensitive here, hence IGNORECASE.
ESCALATION_RE = re.compile(
    r"\bn(?:ew)?\s+\$roles\b"
    r"|[$%]system\.security\)?\.addroles",
    re.IGNORECASE,
)

# The seven fixed OcuPilot package folders that must never contain a storage class that
# escalates outside the two files above; kept as its own constant so this rule cannot
# silently drift from FIXED_PACKAGES if that set ever grows.
STATE_PACKAGE_PREFIX = "src/OcuPilot/Kernel/State/"

# A bare JOB command — same not-a-dotted-call shape as WRITE_RE.
JOB_RE = re.compile(r"(?<![.\w])job\b", re.IGNORECASE)

# AD-9's second ordering rule: nothing under Kernel/State/ may reference a package that
# could re-enter a tool, the AdminPort, the ProviderPort, or any code that could.
REENTRY_TOKENS = ("OcuPilot.Api", "OcuPilot.Port", "OcuPilot.Screen", "OcuPilot.Area")


# --- Admin API containment (AD-27, Story 1.8) ----------------------------------------

# AD-27 gives the instance's own administration API exactly one point of contact, so a
# vendor change has a blast radius of one file. The port names the vendor classes only
# through its own parameters; everything else reaches them through the port -- the endpoint
# inventory through AdminPort.EndpointPackage(), the probe fixture through the dynamic
# dispatch the port already uses. Enforced rather than asserted, because the constraint is
# the kind a later story quietly relaxes while growing the invocation sequence (Epic 2).
ADMIN_API_ALLOWED = {
    "src/OcuPilot/Port/AdminPort.cls",
}

# Matches the vendor package in the spellings ObjectScript itself accepts: as a class name
# (##class(%Api.Admin...)), as a string parameter value, and as a $ClassMethod target. Doc
# comments are not scanned -- prose may still name the API to explain why only one class
# depends on it.
ADMIN_API_RE = re.compile(r"%Api\.Admin", re.IGNORECASE)

# Only comment forms are stripped for this rule, NOT XData bodies -- unlike every other
# rule sharing iter_code_lines. A route table is exactly where a dependency on the vendor
# API hides (`<Map Forward="%Api.Admin.Dispatch.v2"/>` in a fixture UrlMap is a second file
# depending on it), and AD-27 caps the blast radius at one file however the name is spelled.
# The tree's own fixture UrlMaps forward to OcuPilot classes and the inventory XData stores
# package-relative names, so nothing here fires today.
COMMENT_PREFIXES = ("///", ";")


def iter_non_comment_lines(text: str):
    """Yield (line_number, raw_line) for every line that is not a comment. XData bodies
    are included, which is what separates this from iter_code_lines."""
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
        if stripped.startswith(COMMENT_PREFIXES) or stripped.startswith("//"):
            continue
        yield i, raw


def check_admin_api_containment(problems: list[str]) -> None:
    for p in iter_objectscript_files():
        rel = p.relative_to(ROOT).as_posix()
        if rel in ADMIN_API_ALLOWED:
            continue
        text = read_text(p)
        if text is None:
            continue
        for i, raw in iter_non_comment_lines(text):
            if ADMIN_API_RE.search(raw):
                problems.append(
                    f"{rel}:{i}: '%Api.Admin' may be named only in "
                    f"{' or '.join(sorted(ADMIN_API_ALLOWED))} (AD-27); reach it through "
                    f"OcuPilot.Port.AdminPort instead"
                )


def check_escalation_containment(problems: list[str]) -> None:
    for p in iter_objectscript_files():
        rel = p.relative_to(ROOT).as_posix()
        text = read_text(p)
        if text is None:
            continue
        for i, raw in iter_code_lines(text):
            if ESCALATION_RE.search(raw) and rel not in ESCALATION_ALLOWED:
                problems.append(
                    f"{rel}:{i}: 'New $ROLES' / '$SYSTEM.Security.AddRoles' may appear only in "
                    f"{' or '.join(sorted(ESCALATION_ALLOWED))} (AD-9, AC6)"
                )


def check_state_package_isolation(problems: list[str]) -> None:
    for p in iter_objectscript_files():
        rel = p.relative_to(ROOT).as_posix()
        if not rel.startswith(STATE_PACKAGE_PREFIX):
            continue
        text = read_text(p)
        if text is None:
            continue
        for i, raw in iter_code_lines(text):
            if JOB_RE.search(raw):
                problems.append(
                    f"{rel}:{i}: 'JOB' command under Kernel/State/ -- nothing may be spawned "
                    f"from inside an escalated frame (AD-9)"
                )
            for token in REENTRY_TOKENS:
                if token in raw:
                    problems.append(
                        f"{rel}:{i}: reference to {token!r} under Kernel/State/ -- a storage "
                        f"method must never re-enter a tool, a port, a screen or an area (AD-9)"
                    )


# "co-pilot" alone is rejected everywhere in this tree (EXPERIENCE.md:623,
# "Rejected -- naming: 'co-pilot' alone (Microsoft Copilot confusion); the
# feature is always the agent co-pilot"); the one exception is a preceding
# "agent " (either case), so "agent co-pilot" and "Agent co-pilot" both pass.
# Story 1.2's own AC ("Product vocabulary") scopes this check to
# src/OcuPilot/** and ui/** -- the same two SCAN_ROOTS every other check here
# already walks.
#
# Deliberately not a single lookbehind regex: Python's `re` lookbehind is
# fixed-width, so `(?<!agent )` can only ever test for exactly one literal
# space before "co-pilot" -- it wrongly passes "reagent co-pilot" (matches
# "agent " as a substring of "reagent") and wrongly fails "agent  co-pilot" or
# an "agent"/"co-pilot" split across a line-wrapped comment (neither is
# exactly "agent" + one space). Extracting the whole word immediately before
# the match and comparing it to "agent" handles both: a variable amount of
# whitespace (including a newline) between the two words is fine, and a
# compound word merely ending in "...agent" is not mistaken for it.
CO_PILOT_RE = re.compile(r"co-pilot", re.IGNORECASE)
PRECEDING_WORD_RE = re.compile(r"(\w+)\s*\Z")


def check_product_vocabulary(problems: list[str]) -> None:
    for p in iter_source_files():
        text = read_text(p)
        if text is None:
            continue
        rel = p.relative_to(ROOT).as_posix()
        for m in CO_PILOT_RE.finditer(text):
            preceding_word_match = PRECEDING_WORD_RE.search(text[: m.start()])
            preceding_word = preceding_word_match.group(1) if preceding_word_match else ""
            if preceding_word.lower() == "agent":
                continue
            problems.append(
                f"{rel}:{line_of(text, m.start())}: {m.group(0)!r} must be preceded by "
                f"\"agent \" -- 'co-pilot' alone is rejected product vocabulary"
            )


# --- Entity types (AD-14, Story 1.9) --------------------------------------------------
#
# A screen descriptor names its entity types in its `XData Declaration` block, and the
# vocabulary they must come from is the closed `TYPES` parameter of the kernel's own
# EntityType class. Enforced here as well as by the registry on the instance and by the
# client mirror generator, because "the build fails on a value not in it" (AD-14) has to be
# true of the build, not only of a running instance.

ENTITY_TYPE_SOURCE = "src/OcuPilot/Kernel/EntityType.cls"
ENTITY_TYPE_PARAM_RE = re.compile(r'^Parameter\s+TYPES\s*=\s*"([^"]*)"\s*;', re.MULTILINE)

DECLARATION_XDATA_NAME = "Declaration"
XDATA_NAMED_RE = re.compile(r"^\s*XData\s+([A-Za-z0-9_%]+)")
PRIMARY_ENTITY_TYPE_RE = re.compile(r'"entityType"\s*:\s*"([^"]*)"')
SECONDARY_ENTITY_TYPES_RE = re.compile(r'"secondaryEntityTypes"\s*:\s*\[([^\]]*)\]')
QUOTED_VALUE_RE = re.compile(r'"([^"]*)"')


def iter_named_xdata_blocks(text: str, name: str):
    """Yield (line_number, body_text) for every `XData <name>` block in `text`.

    The same 3-state machine `iter_code_lines` uses — the UDL convention puts the opening
    brace on the line AFTER the declaration — but over `iter_non_comment_lines`, so the body
    is what this yields rather than what it skips.
    """
    AWAITING_OPEN, INSIDE = "awaiting_open", "inside"
    state = None
    depth = 0
    start_line = 0
    body: list[str] = []
    for i, raw in iter_non_comment_lines(text):
        if state == AWAITING_OPEN:
            if "{" in raw:
                depth = raw.count("{") - raw.count("}")
                if depth > 0:
                    state, start_line, body = INSIDE, i + 1, []
                else:
                    state = None
            continue

        if state == INSIDE:
            depth += raw.count("{") - raw.count("}")
            if depth <= 0:
                state = None
                yield start_line, "\n".join(body)
                continue
            body.append(raw)
            continue

        m = XDATA_NAMED_RE.match(raw)
        if m and m.group(1) == name:
            if "{" in raw:
                depth = raw.count("{") - raw.count("}")
                if depth > 0:
                    state, start_line, body = INSIDE, i, []
            else:
                state = AWAITING_OPEN


def declared_entity_types(body: str) -> list[str]:
    """Every entity type a descriptor declaration names: the primary, then the secondaries."""
    values = [m.group(1) for m in PRIMARY_ENTITY_TYPE_RE.finditer(body)]
    for m in SECONDARY_ENTITY_TYPES_RE.finditer(body):
        values.extend(QUOTED_VALUE_RE.findall(m.group(1)))
    return [v for v in values if v]


def read_entity_type_vocabulary(problems: list[str]) -> set[str] | None:
    """The closed vocabulary, or None with a problem recorded.

    A vocabulary that cannot be read is reported rather than treated as empty: an empty set
    would make every declared type unknown, and an absent check would make every declared type
    fine. Neither is a negative result.
    """
    text = read_text(ROOT / ENTITY_TYPE_SOURCE)
    if text is None:
        problems.append(f"{ENTITY_TYPE_SOURCE}: the closed entity-type vocabulary could not be read")
        return None
    m = ENTITY_TYPE_PARAM_RE.search(text)
    if not m:
        problems.append(f"{ENTITY_TYPE_SOURCE}: no 'Parameter TYPES = \"...\";' declaration found")
        return None
    return {value.strip() for value in m.group(1).split(",") if value.strip()}


def check_entity_types(problems: list[str]) -> None:
    known = read_entity_type_vocabulary(problems)
    if known is None:
        return
    for p in iter_objectscript_files():
        if p.suffix != ".cls":
            continue
        rel = p.relative_to(ROOT).as_posix()
        if not rel.startswith("src/OcuPilot/"):
            continue
        text = read_text(p)
        if text is None:
            continue
        for line, body in iter_named_xdata_blocks(text, DECLARATION_XDATA_NAME):
            for value in declared_entity_types(body):
                if value not in known:
                    problems.append(
                        f"{rel}:{line}: entity type {value!r} is not in {ENTITY_TYPE_SOURCE}'s "
                        f"closed TYPES vocabulary (AD-14); add it there or use a declared value"
                    )


def main() -> int:
    problems: list[str] = []
    check_rename_tokens(problems)
    check_naming(problems)
    check_write_discipline(problems)
    check_package_placement(problems)
    check_product_vocabulary(problems)
    check_escalation_containment(problems)
    check_admin_api_containment(problems)
    check_state_package_isolation(problems)
    check_entity_types(problems)

    for line in problems:
        print(line)
    print(f"\ncheck-objectscript: {len(problems)} problem(s)", file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())

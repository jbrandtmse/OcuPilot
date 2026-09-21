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

4. **Package placement.** Every class under `src/OcuPilot/` lives in one of the fixed
   package folders `src/OcuPilot/Install/Roster.cls`'s `XData Manifest` block declares —
   the class's own declared package, not just its file's directory. The set is read from
   that roster rather than restated here: `module.xml` and `OcuPilot.Install.Installer`
   read the same block, and a fourth copy of the list is a fourth thing that can drift.
   A roster that cannot be read is reported, never treated as an empty set that would
   refuse every class, nor as an absent check that would admit every class.

5. **Product vocabulary (Story 1.2).** `co-pilot` is rejected everywhere in this tree
   unless immediately preceded by the word `agent` (either case) — "the feature is
   always the agent co-pilot" (EXPERIENCE.md "**Rejected — the field's agent").

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

9. **Screen scope (AD-13, Story 1.11).** A screen descriptor's declared `scope` is one of
   `src/OcuPilot/Kernel/Scope.cls`'s two `SCOPEINSTANCE`/`SCOPENAMESPACE` parameter values —
   the same build-time half of the AD-14 mechanism, for the value `OcuPilot.Screen.Registry.Validate`
   otherwise refuses only on the instance. Same XData-reading approach and the same
   missing-source discipline as rule 8.

10. **Test-class property names (Story 1.17).** No property whose name begins with `Test` on
    a `%UnitTest.TestCase` subclass. The compiler generates `<PropName>DisplayToLogical`,
    `<PropName>Normalize`, `<PropName>IsValid` and `<PropName>LogicalToDisplay` for every
    property, and the framework's method-discovery loop matches every one of them as a test
    method — phantom failures, or an inflated count, with nothing saying why. The rule was
    written down in `.claude/rules/objectscript-testing.md` and enforced by nothing.

11. **No embedded Python in a shipped class (AD-18, Story 1.17).** A `[ Language = python ]`
    method does not compile on an IRIS instance without embedded Python configured, so the
    install that loads it fails there. Host the Python as a standalone `.py` distributed as a
    package resource and call into it.

12. **Every routed handler has an over-the-wire test (Story 1.17).** For every `Call=` target
    in a shipped dispatch class's `XData UrlMap`, some class under `src/OcuPilot/Test/` names
    the route and carries all four markers of an over-the-wire assertion: a request through
    `OcuPilot.Test.Http`, a status assertion, a content-type assertion and a body-shape
    assertion. A literal route is keyed by its own URL, and a `:param` segment is part of that
    literal (DW-364), so `/agent/definitions/:id` keys on itself rather than falling back; a
    pattern route (`/(.*)`), which no literal can identify, is keyed by its dispatch class's
    name. A literal route is covered only by a class that names its whole URL, bounded so a
    longer path does not count (`/turn` is not named by `/turn/abandon`), **and** names its
    method as a literal (`"POST"`), so two methods on one path are two obligations (DW-400).
    Line-oriented, so it cannot tell which method inside a class made which assertion — what it
    catches, which is the defect it exists for, is a route no wire test names at all.

13. **No literal non-ASCII byte in a string literal (Story 1.17, DW-43, Rule 14).** Under
    `src/OcuPilot/`, non-ASCII in a string literal is written `$Char(<code point>)`, so the
    shipped string and whatever pins it are the same bytes whatever an editor, a terminal or a
    patch tool does to the file. Comments are exempt: Rule 14 binds source code and exempts
    prose and comments. `ui/tools/client-lint.mjs` carries the client half of the same rule.

14. **Every tool declares its kind (AD-22, Story 2.3).** A concrete class whose `Extends` chain in
    this tree reaches `OcuPilot.Screen.Tool.Base`, and whose nearest `Parameter KIND` -- its own,
    else the first one found walking its superclasses in declared order -- is neither `read` nor
    `write`, is refused naming its file and line. `OcuPilot.Screen.Tool.Registry.KindProblem`
    refuses the same value on the instance.

15. **REST route ordering (Conventions, Story 2.3).** Over every `XData UrlMap`, in file
    order: a route whose Url, read as `%CSP.REST` reads it (a `:param` segment is `([^/]+)`, every
    other segment is taken verbatim, and the match is whole), matches a later route's Url under
    the same `Method` is refused, since the later route can never be reached -- a catch-all before
    its guard, a `:param` before its literal sibling; and, whatever the `Method`, a route that
    follows a shorter route whose Url matches its leading segments is refused (N-segment routes
    before (N-1)-segment routes). A route with no `Method` matches every method, and a
    comma-separated `Method` matches each verb it lists.

16. **Admin API containment (AD-27, Story 1.8).** `%Api.Admin`, in any spelling ObjectScript
    itself accepts, may appear only in `OcuPilot/Port/AdminPort.cls` -- every other `.cls`/`.mac`/
    `.inc` file, and every shell script under `scripts/`, is refused the moment it appears in code
    (comments excluded), so a vendor dependency the port does not already route through has a
    blast radius of exactly one file.

17. **Destructive test guard (DW-289, Story 2.13).** A `%UnitTest.TestCase` under `Test/` that
    creates or deletes an IRIS user, creates a role, or moves the console log -- directly, or
    through the suite's own throwaway-account helpers on `OcuPilot.Test.Version` -- is refused
    unless its `OnBeforeAllTests` refuses first on `$System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1`,
    so an unarmed instance never has `ci-runner.mjs --container <name>` create the principal at
    all. Reaches principals and the console log only; instance mutation through
    `OcuPilot.Install.Installer` (a probe database, a namespace mapping, a web application) is
    outside it.

18. **Restraint-code containment (AD-30, AD-40, Story 3.7).** A restraint code -- the
    `AGENT.READONLY.*` and `AGENT.KILLSWITCH.*` vocabulary, any of its tails
    (`KILLSWITCH.GLOBAL`, `READONLY.ENFORCED`, ...), its `Api.Error` parameters with or without
    `#`, and the two class methods that resolve it -- may be named only by `Kernel/Restraint.cls`,
    which selects one, `Api/Error.cls`, which declares them, and a test class, which asserts them.
    Every other caller consumes the verdict `Kernel.Restraint.Verdict` answers. **It bans a second
    producer of a restraint code, which is narrower than "one enforcement point"**: a caller that
    read the two state classes and decided for itself would name no code and pass. Reading
    `Kernel/State/Switch.cls` or `Hold.cls` is not restricted -- `Api/Switches.cls` does it
    legitimately -- so the rule cannot be tightened to those class names either. It reads
    ObjectScript source, skipping comments and XData bodies, and the client's `.ts` and `.html`
    under `ui/src` whole, `.spec.ts` and `ui/src/app/testing/` excepted (DW-393, DW-394).

19. **The turn job's reach (AD-7, AD-9, Story 4.1).** A file under `OcuPilot/Kernel/Agent/` names
    no `OcuPilot.Port.*` class but `OcuPilot.Port.ProviderPort`, no `OcuPilot.Area.*` class, no
    `OcuPilot.Screen.*` class but `OcuPilot.Screen.Tool.Registry`, and no `OcuPilot.Api.*` class
    but the vocabulary class `OcuPilot.Api.Error`; and a `JOB` command -- outside a string literal
    -- appears in shipped code only in `OcuPilot/Kernel/Agent/Job.cls`. Test classes under `Test/`
    may spawn their own helpers.

20. **Tool dispatch (AD-1, AD-22, Story 4.2).** Outside `Test/`, `InvokeTool` is named only in
    `Screen/Tool/Registry.cls`, which defines it, and `Kernel/Agent/Dispatch.cls`, its one caller;
    `%Net.HttpRequest` and an `/api/` literal appear nowhere under `Screen/Tool/`, under
    `Kernel/Shell/` (the shell reads and their tools), under `Kernel/Governance/` or in
    `Kernel/Agent/Dispatch.cls`; a file under `Kernel/Shell/` or `Screen/Tool/` names no
    `OcuPilot.Api.*` class but the vocabulary class `OcuPilot.Api.Error`, because the handlers
    depend on the shell reads and the tools and never the reverse; and `BeginCapture` or
    `%SYS.Capture` appears only in `Port/AdminPort.cls` and `Port/MgmntPort.cls`, because a
    port's own capture refuses to open inside one that already holds output.

21. **Literal state SQL (AD-21, Story 4.2).** Under `Kernel/State/`, outside `Base.cls`, which
    defines the helpers, the SQL argument of every `Guarded*Where*` or `GuardedExecute*` call is a
    string literal. It reads direct method calls (`..`, `).` or `tStore.`), not a name passed to
    `$ClassMethod`.

This checker is deliberately line-oriented rather than a full UDL parser: it is exact
enough to catch the violations above and cheap enough to run on every commit and every
CI build. `.githooks/pre-commit` runs it on staged `.cls`/`.mac`/`.inc`/`ui` files,
`.github/workflows/ci.yml` runs it on every change, and `bash scripts/lint-docs.sh` and this
script together are the two mechanical document/code gates this repository has. Every run
prints the file count it scanned, so "found nothing wrong" and "looked at nothing" are
distinguishable.

Usage:
    uv run scripts/check-objectscript.py

Exits 1 if anything is found; exits 0 (silently, besides the trailing summary line) when
the tree is clean.
"""

from __future__ import annotations

import json
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

# The one declaration of the fixed ObjectScript package folders, and of everything else
# module.xml is generated from. Read by read_fixed_packages() below, by
# ui/tools/ipm-manifest.mjs and by OcuPilot.Install.Roster itself.
ROSTER_SOURCE = "src/OcuPilot/Install/Roster.cls"
ROSTER_XDATA_NAME = "Manifest"

# The package every shipped class is declared in, which is what
# <Resource Name="OcuPilot.PKG"/> ships.
SHIPPED_PACKAGE = "OcuPilot"

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


def read_fixed_packages(problems: list[str]) -> set[str] | None:
    """The fixed package folders the roster declares, or None with a problem recorded.

    A roster that cannot be read is reported rather than treated as empty: an empty set
    would refuse every class in the tree, and an absent check would admit every class.
    Neither is a negative result. The same block generates `module.xml`
    (`ui/tools/ipm-manifest.mjs`) and is read on the instance by `OcuPilot.Install.Roster`,
    so this rule and the shipped manifest cannot name different package sets.
    """
    text = read_text(ROOT / ROSTER_SOURCE)
    if text is None:
        problems.append(f"{ROSTER_SOURCE}: the fixed package roster could not be read")
        return None
    blocks = list(iter_named_xdata_blocks(text, ROSTER_XDATA_NAME))
    if not blocks:
        problems.append(f"{ROSTER_SOURCE}: no 'XData {ROSTER_XDATA_NAME}' block found")
        return None
    try:
        roster = json.loads(blocks[0][1])
    except json.JSONDecodeError as exc:
        problems.append(
            f"{ROSTER_SOURCE}: the 'XData {ROSTER_XDATA_NAME}' block is not parseable JSON ({exc})"
        )
        return None
    packages = roster.get("packages") if isinstance(roster, dict) else None
    if (
        not isinstance(packages, list)
        or not packages
        or not all(isinstance(name, str) and name for name in packages)
    ):
        problems.append(
            f"{ROSTER_SOURCE}: the roster declares no non-empty 'packages' array of folder names"
        )
        return None
    return set(packages)


def check_package_placement(problems: list[str]) -> None:
    fixed_packages = read_fixed_packages(problems)
    if fixed_packages is None:
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
        for m in CLASS_RE.finditer(text):
            name = m.group(1)
            ln = line_of(text, m.start())
            parts = name.split(".")
            if len(parts) < 3 or parts[0] != SHIPPED_PACKAGE or parts[1] not in fixed_packages:
                problems.append(
                    f"{rel}:{ln}: class {name!r} is not under one of the fixed "
                    f"{SHIPPED_PACKAGE} package folders ({', '.join(sorted(fixed_packages))}) "
                    f"{ROSTER_SOURCE} declares"
                )


def brace_delta(line: str) -> int:
    """How far `line` moves brace depth: "{" counts +1 and "}" counts -1, but only outside a
    double-quoted span. A backslash inside a span skips the next character, and span state
    resets at the end of the line.

    `braceDelta` in `ui/tools/screen-mirror.mjs` applies the same rule to the same blocks, so
    the two readers agree on where a block ends. JSON strings cannot span lines, so the reset
    cannot miss a JSON brace; a stray quote in an XML block cannot hide a closing brace that
    sits on a line of its own.
    """
    delta = 0
    in_string = False
    skip = False
    for ch in line:
        if in_string:
            if skip:
                skip = False
            elif ch == "\\":
                skip = True
            elif ch == '"':
                in_string = False
            continue
        if ch == '"':
            in_string = True
        elif ch == "{":
            delta += 1
        elif ch == "}":
            delta -= 1
    return delta


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
                xdata_depth = brace_delta(raw)
                xdata_state = INSIDE if xdata_depth > 0 else None
            continue

        if xdata_state == INSIDE:
            xdata_depth += brace_delta(raw)
            if xdata_depth <= 0:
                xdata_state = None
            continue

        if XDATA_START_RE.match(raw):
            if "{" in raw:
                xdata_depth = brace_delta(raw)
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

# The one OcuPilot package folder that must never contain a storage class escalating outside
# the two files above; kept as its own constant so this rule cannot silently drift from the
# roster's package set if that ever grows.
STATE_PACKAGE_PREFIX = "src/OcuPilot/Kernel/State/"

# A bare JOB command — same not-a-dotted-call shape as WRITE_RE, and not the `$JOB` special
# variable.
JOB_RE = re.compile(r"(?<![.\w$])job\b", re.IGNORECASE)

# AD-9's second ordering rule: nothing under Kernel/State/ may reference a package that
# could re-enter a tool, the AdminPort, the ProviderPort, or any code that could.
REENTRY_TOKENS = ("OcuPilot.Api", "OcuPilot.Port", "OcuPilot.Screen", "OcuPilot.Area", "OcuPilot.Kernel.Agent")


# --- Admin API containment (AD-27, Story 1.8) ----------------------------------------

# AD-27 gives the instance's own administration API exactly one point of contact, so a
# vendor change has a blast radius of one file. The port names the vendor classes only
# through its own parameters; everything else reaches them through the port -- the endpoint
# inventory through AdminPort.EndpointPackage(), the probe fixture through the dynamic
# dispatch the port already uses. Enforced rather than asserted, because the constraint is
# the kind a later story quietly relaxes while growing the invocation sequence (Epic 2).
# CI's shell scripts under scripts/ are read as well: the ObjectScript they run inside an
# instance is code, and only their `#` comment lines are exempt.
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


def iter_shell_code_lines(text: str):
    """Yield (line_number, raw_line) for every shell line that is not a `#` comment. ObjectScript
    embedded in a heredoc is code on those lines, which is what this rule reads."""
    for i, raw in enumerate(text.splitlines(), start=1):
        if raw.strip().startswith("#"):
            continue
        yield i, raw


def iter_shell_scripts():
    """The shell scripts under ROOT/scripts/, which carry ObjectScript that CI runs inside an
    instance (`scripts/ci-image-compile.sh` among them)."""
    scripts = ROOT / "scripts"
    if not scripts.is_dir():
        return
    yield from sorted(p for p in scripts.glob("*.sh") if p.is_file())


def check_admin_api_containment(problems: list[str]) -> None:
    def refuse(rel: str, i: int) -> None:
        problems.append(
            f"{rel}:{i}: '%Api.Admin' may be named only in "
            f"{' or '.join(sorted(ADMIN_API_ALLOWED))} (AD-27); reach it through "
            f"OcuPilot.Port.AdminPort instead"
        )

    for p in iter_objectscript_files():
        rel = p.relative_to(ROOT).as_posix()
        if rel in ADMIN_API_ALLOWED:
            continue
        text = read_text(p)
        if text is None:
            continue
        for i, raw in iter_non_comment_lines(text):
            if ADMIN_API_RE.search(raw):
                refuse(rel, i)

    for p in iter_shell_scripts():
        rel = p.relative_to(ROOT).as_posix()
        text = read_text(p)
        if text is None:
            continue
        for i, raw in iter_shell_code_lines(text):
            if ADMIN_API_RE.search(raw):
                refuse(rel, i)


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


# --- Restraint containment (AD-30, AD-40, Story 3.7) ----------------------------------

# AD-30 gives read-only and the kill switch exactly one enforcement point:
# OcuPilot.Kernel.Restraint answers "may this write happen, and why not", and every caller
# consumes that verdict rather than deriving one. The write tools, the turn loop and the confirm
# transition arrive in Epic 4 and 5, so a source-level rule is what keeps a second producer from
# being added there. Api/Error.cls declares the codes, Kernel/Restraint.cls is the one place that
# selects one, and a test class may assert either.
#
# What this rule enforces is ONE PRODUCER OF A RESTRAINT CODE, which is narrower than "one
# enforcement point": a caller that read Kernel/State/Switch.cls and Hold.cls and decided for
# itself would name no code and pass. Those stores cannot be restricted by class name either --
# Api/Switches.cls reads both of them legitimately. A code's tail is matched on its own, so a code
# assembled by joining its tail to the `AGENT.` prefix is still seen (DW-393); a split inside the tail
# is not, and is held by review. The client's TypeScript and
# templates are read whole (DW-394). ObjectScript comments and XData bodies are skipped. The wider
# property is held by review.
RESTRAINT_CODE_RE = re.compile(
    r"AGENT\.(READONLY|KILLSWITCH)\b"
    r"|KILLSWITCH\.(GLOBAL|USER)\b|READONLY\.(ENFORCED|DEFINITION)\b"
    r"|AGENT(READONLY|KILLSWITCH)"
    r"|ReasonForRestraint|RestraintCodes",
)

# The client tree the rule also reads, and the suffixes it reads there.
RESTRAINT_CLIENT_ROOT = "ui/src/"
RESTRAINT_CLIENT_SUFFIXES = (".ts", ".html")
RESTRAINT_CLIENT_EXCLUDED_SUFFIX = ".spec.ts"
# The specs' builders and harness; client-lint.mjs refuses a shipped file importing from here.
RESTRAINT_CLIENT_EXCLUDED_ROOT = "ui/src/app/testing/"

RESTRAINT_ALLOWED = frozenset(
    {
        "src/OcuPilot/Kernel/Restraint.cls",
        "src/OcuPilot/Api/Error.cls",
    }
)

# Test classes assert the vocabulary and the verdict, which is the point of having one.
RESTRAINT_TEST_PREFIX = "src/OcuPilot/Test/"


def check_restraint_containment(problems: list[str]) -> None:
    def refuse(rel: str, i: int) -> None:
        problems.append(
            f"{rel}:{i}: a restraint code is produced outside "
            f"{' or '.join(sorted(RESTRAINT_ALLOWED))} (AD-30, AD-40) -- ask "
            f"OcuPilot.Kernel.Restraint.Verdict and render the verdict it answers, "
            f"never a second derivation of one"
        )

    for p in iter_source_files():
        rel = p.relative_to(ROOT).as_posix()
        if rel in RESTRAINT_ALLOWED or rel.startswith(RESTRAINT_TEST_PREFIX):
            continue
        if p.suffix in (".cls", ".mac", ".inc"):
            is_client = False
        elif (
            rel.startswith(RESTRAINT_CLIENT_ROOT)
            and rel.endswith(RESTRAINT_CLIENT_SUFFIXES)
            and not rel.endswith(RESTRAINT_CLIENT_EXCLUDED_SUFFIX)
            and not rel.startswith(RESTRAINT_CLIENT_EXCLUDED_ROOT)
        ):
            is_client = True
        else:
            continue
        text = read_text(p)
        if text is None:
            continue
        rows = enumerate(text.splitlines(), start=1) if is_client else iter_code_lines(text)
        for i, raw in rows:
            if RESTRAINT_CODE_RE.search(raw):
                refuse(rel, i)


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


# --- The turn job's reach (AD-7, AD-9, Story 4.1) --------------------------------------
#
# A turn job runs for minutes as the user, outside any request. What it may reach is the provider
# port and OcuPilot's own state, and nothing that acts on the instance: no other port, no slice, no
# screen, and no handler -- `OcuPilot.Api.Error` is the vocabulary, not a handler. And the one
# spawn in shipped code is the job's own, so a second `JOB` cannot quietly start a process from a
# frame nobody checked for escalation. Test classes spawn their own helpers and are outside it.

AGENT_PACKAGE_PREFIX = "src/OcuPilot/Kernel/Agent/"
JOB_ALLOWED = frozenset({"src/OcuPilot/Kernel/Agent/Job.cls"})
AGENT_REACH_RE = re.compile(
    r"OcuPilot\.Port\.(?!ProviderPort\b)\w+(?:\.\w+)*"
    r"|OcuPilot\.Area\.\w+(?:\.\w+)*"
    r"|OcuPilot\.Screen\.(?!Tool\.Registry(?![\w.]))\w+(?:\.\w+)*"
    r"|OcuPilot\.Api\.(?!Error\b)\w+(?:\.\w+)*"
)


def check_agent_job_reach(problems: list[str]) -> None:
    for p in iter_objectscript_files():
        rel = p.relative_to(ROOT).as_posix()
        if not rel.startswith("src/OcuPilot/") or rel.startswith(TEST_PACKAGE_PREFIX):
            continue
        text = read_text(p)
        if text is None:
            continue
        for i, raw in iter_code_lines(text):
            if rel.startswith(AGENT_PACKAGE_PREFIX):
                found = AGENT_REACH_RE.search(raw)
                if found is not None:
                    problems.append(
                        f"{rel}:{i}: {found.group(0)!r} is named under Kernel/Agent/ -- the turn "
                        f"job reaches the provider through OcuPilot.Port.ProviderPort, its tools "
                        f"through OcuPilot.Screen.Tool.Registry, and nothing else outside the "
                        f"kernel (AD-7, AD-9)"
                    )
            if rel not in JOB_ALLOWED and JOB_RE.search(STRING_LITERAL_RE.sub('""', raw)):
                problems.append(
                    f"{rel}:{i}: 'JOB' command outside {', '.join(sorted(JOB_ALLOWED))} -- the turn "
                    f"job is the one spawn in shipped code (AD-9)"
                )


# --- Tool dispatch (AD-1, AD-22, Story 4.2) ----------------------------------------------
#
# A tool runs in the job's process and calls the management surface directly, so nothing on the
# dispatch path issues an HTTP request; the one call into a tool has one caller, which is what
# makes the gate point a single point; and an output capture opened around a tool call would make
# the port's own capture refuse, so captures stay inside the port.

INVOKE_TOOL_RE = re.compile(r"\bInvokeTool\b")
INVOKE_TOOL_ALLOWED = frozenset(
    {
        "src/OcuPilot/Screen/Tool/Registry.cls",
        "src/OcuPilot/Kernel/Agent/Dispatch.cls",
    }
)
TOOL_HTTP_RE = re.compile(r"%Net\.HttpRequest|/api/", re.IGNORECASE)
TOOL_HTTP_PREFIXES = ("src/OcuPilot/Screen/Tool/", "src/OcuPilot/Kernel/Shell/", "src/OcuPilot/Kernel/Governance/")
TOOL_HTTP_FILES = frozenset({"src/OcuPilot/Kernel/Agent/Dispatch.cls"})
API_REACH_PREFIXES = ("src/OcuPilot/Kernel/Shell/", "src/OcuPilot/Screen/Tool/")
SHELL_API_REACH_RE = re.compile(r"OcuPilot\.Api\.(?!Error\b)\w+(?:\.\w+)*")
CAPTURE_RE = re.compile(r"BeginCapture|%SYS\.Capture", re.IGNORECASE)
# The port classes that may open an output capture. Story 4.2 wrote this rule when AdminPort was
# the only port that captured; Epic 6's MgmntPort captures the same way, and the merge of the two
# epics is where the second name arrives. The rule still refuses a capture anywhere else, which is
# what keeps one from opening inside another (DW-1173 asks whether these two can nest).
CAPTURE_ALLOWED = frozenset({"src/OcuPilot/Port/AdminPort.cls", "src/OcuPilot/Port/MgmntPort.cls"})


def check_tool_dispatch(problems: list[str]) -> None:
    for p in iter_objectscript_files():
        rel = p.relative_to(ROOT).as_posix()
        if not rel.startswith("src/OcuPilot/") or rel.startswith(TEST_PACKAGE_PREFIX):
            continue
        text = read_text(p)
        if text is None:
            continue
        http_scope = rel in TOOL_HTTP_FILES or rel.startswith(TOOL_HTTP_PREFIXES)
        for i, raw in iter_code_lines(text):
            if rel not in INVOKE_TOOL_ALLOWED and INVOKE_TOOL_RE.search(raw):
                problems.append(
                    f"{rel}:{i}: 'InvokeTool' is named outside "
                    f"{' and '.join(sorted(INVOKE_TOOL_ALLOWED))} -- a tool is called only through "
                    f"OcuPilot.Kernel.Agent.Dispatch, after its gate point (AD-22)"
                )
            if http_scope and TOOL_HTTP_RE.search(raw):
                problems.append(
                    f"{rel}:{i}: an HTTP request or an '/api/' path on the tool dispatch path -- a "
                    f"tool runs in process and calls the management surface directly (AD-1)"
                )
            if rel.startswith(API_REACH_PREFIXES):
                found = SHELL_API_REACH_RE.search(raw)
                if found is not None:
                    problems.append(
                        f"{rel}:{i}: {found.group(0)!r} is named under Kernel/Shell/ or Screen/Tool/ "
                        f"-- a handler calls the shell reads and the tools, never the reverse, and "
                        f"OcuPilot.Api.Error is the only API class either names (dependency direction)"
                    )
            if rel not in CAPTURE_ALLOWED and CAPTURE_RE.search(raw):
                problems.append(
                    f"{rel}:{i}: an output capture outside {', '.join(sorted(CAPTURE_ALLOWED))} -- "
                    f"the port's own capture refuses to open inside one that holds output"
                )


# --- Literal state SQL (AD-21, Story 4.2) -------------------------------------------------
#
# Every statement a kernel store runs is text the store wrote, with a `?` for every value. The
# guarded helpers in Base.cls take the text as an argument, so a call site passing a variable is
# the one place a caller value could reach the text; the rule holds every call site to a literal.

STATE_SQL_CALL_RE = re.compile(r"\.(Guarded\w*Where\w*|GuardedExecute\w*)\(")
# The SQL argument is one whole string literal (a doubled quote is an escaped quote) followed by the
# next argument or the call's close -- so a literal joined to a caller value is refused too.
STATE_SQL_LITERAL_ARG_RE = re.compile(r'\s*"(?:[^"]|"")*"\s*[,)]')
STATE_SQL_BASE = "src/OcuPilot/Kernel/State/Base.cls"


def check_state_sql_literal(problems: list[str]) -> None:
    for p in iter_objectscript_files():
        rel = p.relative_to(ROOT).as_posix()
        if not rel.startswith(STATE_PACKAGE_PREFIX) or rel == STATE_SQL_BASE:
            continue
        text = read_text(p)
        if text is None:
            continue
        for i, raw in iter_code_lines(text):
            for m in STATE_SQL_CALL_RE.finditer(raw):
                if not STATE_SQL_LITERAL_ARG_RE.match(raw, m.end()):
                    problems.append(
                        f"{rel}:{i}: {m.group(1)} is called with SQL text that is not a string "
                        f"literal -- a store's statement is its own literal, with every value bound "
                        f"as a parameter (AD-21)"
                    )


# "co-pilot" alone is rejected everywhere in this tree (EXPERIENCE.md "**Rejected — the field's agent",
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
                depth = brace_delta(raw)
                if depth > 0:
                    state, start_line, body = INSIDE, i + 1, []
                else:
                    state = None
            continue

        if state == INSIDE:
            depth += brace_delta(raw)
            if depth <= 0:
                state = None
                yield start_line, "\n".join(body)
                continue
            body.append(raw)
            continue

        m = XDATA_NAMED_RE.match(raw)
        if m and m.group(1) == name:
            if "{" in raw:
                depth = brace_delta(raw)
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


# --- Scope (AD-13, Story 1.11) ---------------------------------------------------------
#
# A screen descriptor's `XData Declaration` block also names a `scope`, and the vocabulary it
# must come from is `OcuPilot.Kernel.Scope`'s own two Parameter values -- not a literal pair
# copied here, so this reader and `OcuPilot.Screen.Registry.Validate` (which reads the same two
# class parameters directly) cannot drift apart on what the two spellings are. Read from
# `Kernel/Scope.cls` rather than hardcoded for the same reason `check_entity_types` reads
# `EntityType.cls` instead of listing types itself. Descriptors that declare `scope` by
# overriding `DeclarationJson` in a class method rather than in an `XData Declaration` block
# (the malformed-scope fixture among them) are outside this reader's scope, the same documented
# limitation `check_entity_types` has for the same reason.

SCOPE_SOURCE = "src/OcuPilot/Kernel/Scope.cls"
SCOPE_PARAM_RE = re.compile(r'^Parameter\s+(SCOPEINSTANCE|SCOPENAMESPACE)\s*=\s*"([^"]*)"\s*;', re.MULTILINE)
SCOPE_FIELD_RE = re.compile(r'"scope"\s*:\s*"([^"]*)"')


def read_screen_scope_vocabulary(problems: list[str]) -> set[str] | None:
    """The two words a descriptor's `scope` may spell, read from `OcuPilot.Kernel.Scope`'s own
    `SCOPEINSTANCE` and `SCOPENAMESPACE` parameters. A vocabulary that cannot be read in full is
    reported rather than treated as empty (which would refuse every declared scope) or partial
    (which would silently admit whichever word failed to parse) -- the same discipline
    `read_entity_type_vocabulary` follows for `EntityType.cls`.
    """
    text = read_text(ROOT / SCOPE_SOURCE)
    if text is None:
        problems.append(f"{SCOPE_SOURCE}: the scope vocabulary could not be read")
        return None
    found = {m.group(1): m.group(2) for m in SCOPE_PARAM_RE.finditer(text)}
    missing = {"SCOPEINSTANCE", "SCOPENAMESPACE"} - found.keys()
    if missing:
        problems.append(f"{SCOPE_SOURCE}: missing Parameter {' and '.join(sorted(missing))}")
        return None
    return set(found.values())


def check_screen_scope(problems: list[str]) -> None:
    known = read_screen_scope_vocabulary(problems)
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
            found = list(SCOPE_FIELD_RE.finditer(body))
            if not found:
                # An omitted `scope` is refused too, and for the same reason a third spelling is.
                # `OcuPilot.Screen.Registry.Validate` compares the declared value against both
                # words with no exemption for `""`, so a declaration that names no scope fails on
                # the instance -- while a misspelled one now fails here. Refusing only the second
                # leaves the build-versus-runtime split this rule exists to close, for the more
                # likely authoring mistake of the two.
                problems.append(
                    f"{rel}:{line}: the declaration names no 'scope' (AD-13); declare one of "
                    f"{SCOPE_SOURCE}'s values ({', '.join(sorted(known))}) -- "
                    f"OcuPilot.Screen.Registry.Validate refuses an empty scope on the instance"
                )
                continue
            for m in found:
                value = m.group(1)
                if value not in known:
                    problems.append(
                        f"{rel}:{line}: scope {value!r} is neither of {SCOPE_SOURCE}'s declared "
                        f"values ({', '.join(sorted(known))}) (AD-13); add it there or use a "
                        f"declared value"
                    )


# --- Test-class property names (Story 1.17, `.claude/rules/objectscript-testing.md`) --------
#
# `%UnitTest.TestCase`'s method-discovery loop matches every method whose name starts with
# "Test", and the compiler auto-generates `<PropName>DisplayToLogical`, `<PropName>Normalize`
# and friends for every property. So a property named `TestNsPrepared` produces four methods
# the framework runs as tests, with no test body: they surface as phantom failures or as an
# inflated count, and nothing in the run says why. The rule was written down in
# `.claude/rules/objectscript-testing.md` and enforced by nothing.

TEST_CASE_ROOTS = {"%UnitTest.TestCase", "%Library.UnitTest.TestCase"}


def is_test_case(name: str, graph: dict[str, list[str]]) -> bool:
    """Whether `name` extends `%UnitTest.TestCase`, directly or through this tree's classes.

    The same transitive walk `gets_data_global` does, and with the same documented scope: a
    superclass this scanner never reads is taken at its name.
    """
    seen: set[str] = set()
    pending = [name]
    while pending:
        current = pending.pop()
        if current in seen:
            continue
        seen.add(current)
        for parent in graph.get(current, []):
            if parent in TEST_CASE_ROOTS:
                return True
            pending.append(parent)
    return False


def check_test_class_properties(problems: list[str]) -> None:
    graph = build_superclass_graph()
    for p in iter_objectscript_files():
        if p.suffix != ".cls":
            continue
        text = read_text(p)
        if text is None:
            continue
        rel = p.relative_to(ROOT).as_posix()
        declared = [m.group(1) for m in CLASS_RE.finditer(text)]
        if not any(is_test_case(name, graph) for name in declared):
            continue
        for m in PROPERTY_RE.finditer(text):
            name = m.group(1)
            if not name.startswith("Test"):
                continue
            problems.append(
                f"{rel}:{line_of(text, m.start())}: property {name!r} on a %UnitTest.TestCase "
                f"subclass begins with 'Test', so the compiler's generated "
                f"{name}DisplayToLogical / {name}Normalize / {name}IsValid / "
                f"{name}LogicalToDisplay are all matched as test methods; use a prefix that "
                f"does not begin with 'Test' (Prepared*, Setup*, Cached*, Stored*, Initial*)"
            )


# --- A destructive test class is armed by an environment variable (DW-289) --------------------
#
# `node ui/tools/ci-runner.mjs --container <name>` takes any container's name, and the class list
# it runs comes from a query over every compiled `%UnitTest.TestCase` subclass under
# `OcuPilot.Test` -- so a class that creates an IRIS user, or rotates the instance's own
# messages.log, runs on whatever instance the runner was pointed at. Six such classes were held
# off a live instance by nothing but a doc comment, and one of them deletes a pre-existing account
# of the same name before creating its own.
#
# The barrier is `OnBeforeAllTests` returning an error status unless an arming environment
# variable reads 1: `%UnitTest.Manager` raises it BEFORE it enumerates the class's `Test*`
# methods, so an unarmed instance runs none of them and nothing is created. The rule reads the
# barrier, not the mention of it: the refusing comparison `'= 1` and a `Quit $$$ERROR` must both
# stand on non-comment lines inside that method, because an inverted comparison, a branch that
# returns `$$$OK`, and a comment quoting the guard all leave the class running on a live instance.
#
# **Six edits fix six classes; this rule fixes the population.** It reads the APIs the tree
# actually calls, not a list of everything IRIS could do: creating or deleting a user or a role,
# registering, modifying or deleting an audit event, moving the console log, modifying the
# instance-wide system security settings, and running the production install.
#
# `Security.System.Modify` joined the list with Story 5.10, whose test class turns the instance's
# own auditing off: that is the widest effect any class here has, because while it is off nothing on
# the instance is audited at all -- not only OcuPilot's own events.
#
# **A stated limit, not an oversight.** The same story made auditing reachable without naming that
# API, through the shipped confirm path: `security.auditing.update` is an ordinary write tool, so a
# class that mints and confirms one of its proposals turns auditing off having named no watched
# call. This rule reads one file at a time and cannot see through a confirm, and the tool's class
# name is no proxy for it -- several classes read that class's parameters without ever issuing a
# write. So the confirm route is outside the population, and a class that takes it carries its own
# `OnBeforeAllTests` refusal by its author's decision rather than by this gate
# (`OcuPilot.Test.ProhibitedRoute` is the first). The restore helper is outside it too, because it
# only ever turns auditing back on.
#
# Deleting a role was outside the rule until DW-396, on the ground that it is the tail of an
# install probe rather than a principal this suite brought into being. It is inside it now: the
# classes that do it are the same classes that run the install, so the exemption was protecting
# nothing and was one more thing for a reader to check.
#
# **The suite's own principal helpers count too.** A class that reaches `Security.Users` through
# `OcuPilot.Test.Version`'s throwaway-account helpers creates exactly the same account on exactly
# the same instance, and a rule that read only direct calls would let its guard be deleted with
# the checker green -- which is what `Test/UnexpireScope.cls` does, and it names no security class
# at all. Listed by name rather than followed transitively: a call graph over the whole Test tree
# is a different checker, and every helper this suite actually has is here.
#
# **A production install is the widest effect of all, and it was the one the pattern missed**
# (DW-396, DW-402). `##class(OcuPilot.Install.Installer).Install("")` creates a database, a
# resource, a role, three web applications and the audit registrations, and unexpires `_SYSTEM`.
# `Test/AuditRecord.cls` runs one and names no security class at all, so a rule that read only
# `Security.*` calls could not see it. The literal `""` is the production profile; a probe-profile
# install (`Install("probe")`) creates the parallel `Probe*` objects a test owns and is outside
# this rule, which is why the pattern anchors on the empty argument rather than on the method.
#
# **And the suite reaches that install through a helper as well.**
# `OcuPilot.Test.InstallerProbe` extends `OcuPilot.Install.Installer` and overrides the demo-fixture
# call site, the unexpire step and the logging -- not `StartPath`, which runs the real production
# install underneath. `Test/DemoOptIn.cls` drives it and names no installer class of its own.
# Fourteen classes under `Test/` extend the installer or that probe, so listing the helpers by name
# is what a later one would be added outside of: `Install` and `StartPath` are matched on ANY
# `OcuPilot.Test.*` class as well as on the installer itself. `Install()` with no argument is
# matched too -- `pProfile` defaults to `""`, so the bare call is the production install under
# another spelling, and anchoring only on the literal `""` read it as a probe install.
#
# A probe database, a namespace mapping and a web application created under the probe profile stay
# outside the rule: they are the test's own objects, and the guard exists for effects on the
# instance an operator cares about.

DESTRUCTIVE_TEST_RE = re.compile(
    r"##class\(\s*Security\.Users\s*\)\s*\.\s*(?:Create|Delete)\b"
    r"|##class\(\s*Security\.Roles\s*\)\s*\.\s*(?:Create|Delete)\b"
    r"|##class\(\s*Security\.Events\s*\)\s*\.\s*(?:Create|Delete|Modify)\b"
    r"|##class\(\s*Config\.Startup\s*\)\s*\.\s*MoveConsoleLog\b"
    r"|##class\(\s*Security\.System\s*\)\s*\.\s*Modify\b"
    r"|##class\(\s*(?:OcuPilot\.Install\.Installer|OcuPilot\.Test\.\w+)\s*\)"
    r"\s*\.\s*Install\(\s*(?:\"\"\s*)?[,)]"
    r"|##class\(\s*(?:OcuPilot\.Install\.Installer|OcuPilot\.Test\.\w+)\s*\)"
    r"\s*\.\s*StartPath\b"
    r"|##class\(\s*OcuPilot\.Test\.Version\s*\)\s*\.\s*(?:CreateThrowawayExpiredAccount|DeleteThrowawayAccount)\b"
    r"|##class\(\s*OcuPilot\.Test\.TurnWireFixture\s*\)\s*\.\s*"
    r"(?:EnsurePrincipal|DeletePrincipal|RemovePrincipals|SetRoleResources|RemoveSecondRole)\b"
)

ARMING_GUARD_RE = re.compile(r"\$System\.Util\.GetEnviron\(\s*\.\.#ARMINGVARIABLE\s*\)\s*'=\s*1")

ARMING_REFUSAL_RE = re.compile(r"Quit\s+\$\$\$ERROR\s*\(")

ON_BEFORE_ALL_TESTS_RE = re.compile(r"^Method\s+OnBeforeAllTests\s*\(", re.MULTILINE)


def method_body(text: str, start: int) -> str:
    """The braced body that follows the method signature starting at `start`, or `''`.

    Counted rather than matched to the next `}` at column 0: a method body holds braces of its
    own, and a rule that stopped at the first one would read a guard out of the wrong method.
    """
    open_at = text.find("{", start)
    if open_at < 0:
        return ""
    depth = 0
    for i in range(open_at, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return text[open_at : i + 1]
    return ""


def guarded_before_all_tests(text: str) -> bool:
    """Whether `OnBeforeAllTests` actually refuses on the arming variable.

    Naming the variable is not the test. A comparison written the right way round but the wrong
    way (`= 1`), or one whose branch returns `$$$OK`, reads as armed on a live instance and runs
    the class anyway -- the exact outcome the rule exists to stop, with the checker green. So the
    refusing comparison and a `Quit $$$ERROR` must both appear in that method's own body, on lines
    that are not comments: a `;` line quoting the guard is prose, not a barrier.
    """
    signature = ON_BEFORE_ALL_TESTS_RE.search(text)
    if signature is None:
        return False
    open_at = text.find("{", signature.start())
    body = method_body(text, signature.start())
    if open_at < 0 or body == "":
        return False
    first = line_of(text, open_at)
    last = first + body.count("\n")
    code = [raw for i, raw in iter_non_comment_lines(text) if first <= i <= last]
    return any(ARMING_GUARD_RE.search(raw) for raw in code) and any(
        ARMING_REFUSAL_RE.search(raw) for raw in code
    )


def check_destructive_test_guard(problems: list[str]) -> None:
    graph = build_superclass_graph()
    for p in iter_objectscript_files():
        if p.suffix != ".cls":
            continue
        rel = p.relative_to(ROOT).as_posix()
        if "/Test/" not in rel:
            continue
        text = read_text(p)
        if text is None:
            continue
        declared = [m.group(1) for m in CLASS_RE.finditer(text)]
        if not any(is_test_case(name, graph) for name in declared):
            continue
        hit = None
        for i, raw in iter_non_comment_lines(text):
            found = DESTRUCTIVE_TEST_RE.search(raw)
            if found is not None:
                hit = (i, found.group(0))
                break
        if hit is None:
            continue
        if guarded_before_all_tests(text):
            continue
        line, call = hit
        problems.append(
            f"{rel}:{line}: a %UnitTest.TestCase calling {call} mutates this instance's own "
            f"principals or logs, and OnBeforeAllTests does not refuse on "
            f"$System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 with a Quit $$$ERROR -- so "
            f"`ci-runner.mjs --container <name>` runs it against whatever instance it was pointed "
            f"at (DW-289); add the guard OcuPilot.Test.LogSourceDenial carries and arm it in "
            f"scripts/ci-throwaway.sh"
        )


# --- Embedded Python in a shipped class (AD-18, `.claude/rules/objectscript-basics.md`) -----
#
# A `[ Language = python ]` method in a shipped class is a latent install failure on any IRIS
# instance without embedded Python configured -- the class does not compile, so the install that
# loads it fails, on an instance nobody chose to test against. Where Python is genuinely needed
# it is hosted as a standalone `.py` distributed as a package resource and called into.

LANGUAGE_PYTHON_RE = re.compile(r"\[\s*[^\]]*\bLanguage\s*=\s*python\b[^\]]*\]", re.IGNORECASE)


def check_embedded_python(problems: list[str]) -> None:
    for p in iter_objectscript_files():
        text = read_text(p)
        if text is None:
            continue
        rel = p.relative_to(ROOT).as_posix()
        for i, raw in iter_code_lines(text):
            if LANGUAGE_PYTHON_RE.search(raw):
                problems.append(
                    f"{rel}:{i}: '[ Language = python ]' in a shipped class -- a class carrying "
                    f"one does not compile on an instance without embedded Python configured, so "
                    f"the install that loads it fails there. Host the Python as a standalone .py "
                    f"distributed as a package resource and call into it"
                )


# --- Every routed handler has an over-the-wire test (Consistency Conventions, AD-12) --------
#
# "Every handler gets an HTTP integration test asserting status, content type and body shape"
# was a convention in a document and an assertion nobody could run. A route added with no wire
# test is invisible: the unit suite stays green, the route answers whatever the framework
# decides, and the first caller finds out.
#
# Scope, stated plainly: this is a line-oriented checker, so what it can require is that SOME
# test class under src/OcuPilot/Test/ names the route and carries all four markers of an
# over-the-wire assertion. It cannot tell which method inside that class made which assertion,
# so a class covering three routes satisfies the rule for all three with one content-type
# assertion. What it does catch, which is the defect it exists for, is a route no wire test
# names at all.

# Attribute order is not fixed by XML, so both spellings are matched. The single-order form
# this replaced skipped `<Route Method="GET" Call="X" Url="/y"/>` silently -- a route the rule
# exists to notice, passing because of where its attributes happened to sit.
ROUTE_RE = re.compile(
    r"<Route\s+(?=[^>]*\bUrl\s*=\s*\"(?P<url>[^\"]*)\")(?=[^>]*\bCall\s*=\s*\"(?P<call>[^\"]*)\")[^>]*>",
    re.IGNORECASE,
)
URLMAP_XDATA_NAME = "UrlMap"

# A path this checker can look for literally: it starts with "/" and carries at least one
# character that is not a regex metacharacter. `/(.*)` and `/` do not qualify, and for those the
# dispatch class's own name is the key instead.
#
# `:` is admitted (DW-364). `%CSP.REST` writes a route parameter as `:name`, which is an ordinary
# character in the declared path and one a test can name verbatim -- and without it every route
# carrying a parameter fell back to the dispatch class, so ONE class naming
# `OcuPilot.Api.Router` covered all eight of them at once and the rule could not tell two apart.
# The rule exists to notice a route no wire test names; a key shared by eight routes cannot.
LITERAL_ROUTE_RE = re.compile(r"^/[A-Za-z0-9][A-Za-z0-9._/:-]*$")

WIRE_MARKERS = (
    ("an over-the-wire request", re.compile(r"\b(?:AbsoluteRequest|MakeRequest|RawRequest)\(")),
    ("a status assertion", re.compile(r"AssertEquals\(\s*tStatus")),
    ("a content-type assertion", re.compile(r"CONTENT-TYPE|ContentType")),
    ("a body-shape assertion", re.compile(r"%FromJSON")),
)

TEST_PACKAGE_PREFIX = "src/OcuPilot/Test/"


def wire_test_sources() -> dict[str, str]:
    """Every test class's CODE, keyed by repository-relative path.

    Comments are stripped, deliberately. The rule asks whether a route is named by a test
    that makes an over-the-wire assertion; over the whole file text a `///` line mentioning
    the path or the dispatch class satisfied it, so the gate a route's own doc comment could
    pass was reporting on prose. `iter_code_lines` is the same comment definition every other
    rule in this file uses.
    """
    sources: dict[str, str] = {}
    for p in iter_objectscript_files():
        rel = p.relative_to(ROOT).as_posix()
        if not rel.startswith(TEST_PACKAGE_PREFIX):
            continue
        text = read_text(p)
        if text is not None:
            sources[rel] = "\n".join(raw for _, raw in iter_code_lines(text))
    return sources


ROUTE_METHOD_RE = re.compile(r"\bMethod\s*=\s*\"([^\"]*)\"", re.IGNORECASE)


def route_methods(element: str) -> list[str]:
    """The verbs a `<Route>` element's `Method` attribute lists, upper-cased; empty when it has
    none."""
    found = ROUTE_METHOD_RE.search(element)
    if found is None:
        return []
    return [verb.strip().upper() for verb in found.group(1).split(",") if verb.strip()]


def route_name_matcher(url: str, methods: list[str]):
    """A predicate over a test class's code: whether it names the literal route `url` -- the whole
    URL, bounded at both ends so a longer route does not name a shorter one, whether it extends the
    shorter one's tail (`/turn/abandon`) or its head (`/logs/errors/namespaces`); the API base
    `/api/ocupilot` may precede it -- and every verb in `methods` as a string literal (DW-400)."""
    url_re = re.compile(
        r"(?:(?<=/api/ocupilot)|(?<![A-Za-z0-9._/:-]))" + re.escape(url) + r"(?![A-Za-z0-9._/:-])"
    )
    verb_res = [re.compile(r'"' + re.escape(verb) + r'"', re.IGNORECASE) for verb in methods]

    def names(source: str) -> bool:
        return url_re.search(source) is not None and all(v.search(source) for v in verb_res)

    return names


def check_handler_wire_tests(problems: list[str]) -> None:
    sources = wire_test_sources()
    for p in iter_objectscript_files():
        if p.suffix != ".cls":
            continue
        rel = p.relative_to(ROOT).as_posix()
        if not rel.startswith("src/OcuPilot/") or rel.startswith(TEST_PACKAGE_PREFIX):
            continue
        text = read_text(p)
        if text is None:
            continue
        class_names = [m.group(1) for m in CLASS_RE.finditer(text)]
        if not class_names:
            continue
        dispatch_class = class_names[0]
        for line, body in iter_named_xdata_blocks(text, URLMAP_XDATA_NAME):
            for m in ROUTE_RE.finditer(body):
                url, call = m.group(1), m.group(2)
                literal = LITERAL_ROUTE_RE.match(url) is not None
                key = url if literal else dispatch_class
                if literal:
                    names_key = route_name_matcher(url, route_methods(m.group(0)))
                else:
                    names_key = lambda source, key=key: key in source
                covered = [
                    name
                    for name, source in sources.items()
                    if names_key(source) and all(pattern.search(source) for _, pattern in WIRE_MARKERS)
                ]
                if covered:
                    continue
                named = [name for name, source in sources.items() if names_key(source)]
                if named:
                    missing = [
                        label
                        for name in named
                        for label, pattern in WIRE_MARKERS
                        if not pattern.search(sources[name])
                    ]
                    why = (
                        f"the class(es) naming it ({', '.join(sorted(named))}) carry none of: "
                        + ", ".join(sorted(set(missing)))
                    )
                else:
                    why = f"no class under {TEST_PACKAGE_PREFIX} names {key!r} at all"
                problems.append(
                    f"{rel}:{line}: the route Url={url!r} Call={call!r} has no over-the-wire test "
                    f"asserting status, content type and body shape -- {why}"
                )


# --- Literal non-ASCII bytes in a string literal (DW-43, Rule 14) ---------------------------
#
# Non-ASCII is authored as an escape sequence, never as a literal byte, so the shipped string
# and whatever pins it are the same bytes whatever an editor, a terminal or a patch tool does to
# the file. In ObjectScript the escape is `$Char(<code point>)` concatenated into the string.
#
# Comments are exempt, deliberately: Rule 14 binds source code and exempts prose and comments,
# and this tree's doc comments carry a couple of hundred em dashes whose rewriting would be a
# large unreviewable diff enforcing nothing the rule asks for.

NON_ASCII_RE = re.compile(r"[^\x00-\x7f]")
STRING_LITERAL_RE = re.compile(r'"(?:[^"]|"")*"')


def iter_xdata_bodies(text: str):
    """Yield (first_body_line_number, body_text) for EVERY `XData <name>` block in `text`.

    `iter_named_xdata_blocks` answers for one name; this answers for all of them, because the
    rule below has to be about the whole of a file rather than about the blocks somebody
    remembered to list.
    """
    for name in sorted({m.group(1) for m in (XDATA_NAMED_RE.match(raw) for _, raw in iter_non_comment_lines(text)) if m}):
        yield from iter_named_xdata_blocks(text, name)


def check_non_ascii_literals(problems: list[str]) -> None:
    for p in iter_objectscript_files():
        text = read_text(p)
        if text is None:
            continue
        rel = p.relative_to(ROOT).as_posix()
        if not rel.startswith("src/OcuPilot/"):
            continue
        for i, raw in iter_code_lines(text):
            for literal in STRING_LITERAL_RE.finditer(raw):
                for m in NON_ASCII_RE.finditer(literal.group(0)):
                    code_point = ord(m.group(0))
                    problems.append(
                        f"{rel}:{i}: literal non-ASCII character U+{code_point:04X} in a string "
                        f"literal -- write it as $Char({code_point}) (Rule 14; comments are exempt)"
                    )
        # XData bodies, which `iter_code_lines` skips by design and which are the tree's OTHER
        # string source: the roster's application descriptions are XData strings asserted onto
        # Security.Applications and emitted verbatim into module.xml, and a screen descriptor's
        # declaration is XData too. A rule that named comments as its only exemption and silently
        # exempted these as well would be a rule about the wrong half of the file.
        for line, body in iter_xdata_bodies(text):
            for offset, raw in enumerate(body.splitlines()):
                for literal in STRING_LITERAL_RE.finditer(raw):
                    for m in NON_ASCII_RE.finditer(literal.group(0)):
                        code_point = ord(m.group(0))
                        problems.append(
                            f"{rel}:{line + offset}: literal non-ASCII character "
                            f"U+{code_point:04X} in an XData string -- write it as an escape "
                            f"the block's own format defines (Rule 14; comments are exempt)"
                        )


# --- Every tool declares its kind (AD-22) ------------------------------------------------------
#
# "A tool declaring neither read nor write fails the build." The kind a tool carries at runtime is
# `$Parameter(class, "KIND")`, which an abstract superclass can supply, so the rule follows the
# `Extends` chain the same way `gets_data_global` does and reads the nearest declaration.

TOOL_BASE_CLASS = "OcuPilot.Screen.Tool.Base"
TOOL_KINDS = {"read", "write"}
CLASS_KEYWORDS_RE = re.compile(
    r"^Class\s+([A-Za-z0-9_.%]+)(?:\s+Extends\s+(?:\([^)]*\)|[A-Za-z0-9_.%]+))?\s*(\[[^\]]*\])?",
    re.MULTILINE,
)
ABSTRACT_KEYWORD_RE = re.compile(r"(?:^|[\[,])\s*Abstract\b(?!\s*=\s*0)", re.IGNORECASE)
KIND_PARAM_RE = re.compile(
    r'^Parameter\s+KIND(?:\s+As\s+[A-Za-z0-9_.%]+)?(?:\s*\[[^\]]*\])?\s*=\s*"([^"]*)"', re.MULTILINE
)


def read_tool_classes() -> dict[str, dict]:
    """Every class declared in this tree: its file, line, superclasses, abstractness and the
    `KIND` it declares itself (or None)."""
    classes: dict[str, dict] = {}
    for p in iter_objectscript_files():
        if p.suffix != ".cls":
            continue
        text = read_text(p)
        if text is None:
            continue
        rel = p.relative_to(ROOT).as_posix()
        for m in CLASS_RE.finditer(text):
            name = m.group(1)
            keywords = CLASS_KEYWORDS_RE.match(text, m.start())
            keyword_list = keywords.group(2) if keywords and keywords.group(2) else ""
            kind = KIND_PARAM_RE.search(text)
            classes[name] = {
                "rel": rel,
                "line": line_of(text, m.start()),
                "supers": parse_superclasses(m.group(2)),
                "abstract": bool(ABSTRACT_KEYWORD_RE.search(keyword_list)),
                "kind": kind.group(1) if kind else None,
            }
    return classes


def reaches_tool_base(name: str, classes: dict[str, dict]) -> bool:
    seen: set[str] = set()
    pending = [name]
    while pending:
        current = pending.pop()
        if current in seen:
            continue
        seen.add(current)
        for parent in classes.get(current, {}).get("supers", []):
            if parent == TOOL_BASE_CLASS:
                return True
            pending.append(parent)
    return False


def nearest_kind(name: str, classes: dict[str, dict]) -> str | None:
    """The `KIND` `name` declares, else the first one found depth-first through its superclasses
    in declared order -- the order IRIS resolves an inherited parameter in."""
    seen: set[str] = set()

    def walk(current: str) -> str | None:
        if current in seen or current not in classes:
            return None
        seen.add(current)
        if classes[current]["kind"] is not None:
            return classes[current]["kind"]
        for parent in classes[current]["supers"]:
            found = walk(parent)
            if found is not None:
                return found
        return None

    return walk(name)


def check_tool_kind(problems: list[str]) -> None:
    classes = read_tool_classes()
    for name, info in sorted(classes.items()):
        if info["abstract"] or name == TOOL_BASE_CLASS or not reaches_tool_base(name, classes):
            continue
        kind = nearest_kind(name, classes)
        if kind in TOOL_KINDS:
            continue
        problems.append(
            f"{info['rel']}:{info['line']}: concrete tool class {name!r} declares no kind of 'read' "
            f"or 'write' (nearest KIND is {kind!r}); every tool declares its kind at definition "
            f"time (AD-22)"
        )


# --- REST route ordering (Conventions) -------------------------------------------------------
#
# `%CSP.REST` tries routes in file order and dispatches to the first whose pattern and method both
# match. Its pattern is `GetRegexForUrl`'s: a `:param` segment becomes `([^/]+)`, any other segment
# is used verbatim, and `%Regex.Matcher.Match` requires the whole URL. So an earlier route that
# matches a later one's Url under the same method makes the later one unreachable, and the
# Conventions' N-before-(N-1) invariant is checked on segment prefixes whatever the method.

ROUTE_ELEMENT_RE = re.compile(r"<Route\b[^>]*>", re.IGNORECASE)
ROUTE_ATTR_RE = re.compile(r"""\b(Url|Method)\s*=\s*(?:"([^"]*)"|'([^']*)')""", re.IGNORECASE)


def vendor_route_regex(url: str) -> str:
    """The pattern `%CSP.REST.GetRegexForUrl` builds for `url`."""
    return "/".join("([^/]+)" if piece.startswith(":") else piece for piece in url.split("/"))


def route_matches(pattern_url: str, candidate: str) -> bool | None:
    """Whether `pattern_url`, read as the vendor reads it, matches the whole of `candidate`; None
    when the pattern is not a readable regular expression."""
    try:
        return re.fullmatch(vendor_route_regex(pattern_url), candidate) is not None
    except re.error:
        return None


def check_route_ordering(problems: list[str]) -> None:
    for p in iter_objectscript_files():
        if p.suffix != ".cls":
            continue
        text = read_text(p)
        if text is None:
            continue
        rel = p.relative_to(ROOT).as_posix()
        for start, body in iter_named_xdata_blocks(text, URLMAP_XDATA_NAME):
            routes = []
            for element in ROUTE_ELEMENT_RE.finditer(body):
                attrs = {k.lower(): dq or sq for k, dq, sq in ROUTE_ATTR_RE.findall(element.group(0))}
                if "url" not in attrs:
                    continue
                method = attrs.get("method")
                methods = {m.strip().upper() for m in method.split(",") if m.strip()} if method else None
                routes.append((start + body.count("\n", 0, element.start()), attrs["url"], methods))
            for i, (line_i, url_i, method_i) in enumerate(routes):
                pieces_i = url_i.split("/")
                for line_j, url_j, method_j in routes[i + 1 :]:
                    same_method = method_i is None or method_j is None or bool(method_i & method_j)
                    if same_method:
                        matched = route_matches(url_i, url_j)
                        if matched is None:
                            problems.append(
                                f"{rel}:{line_i}: route Url={url_i!r} cannot be read as the pattern "
                                f"%CSP.REST builds from it"
                            )
                            break
                        if matched:
                            problems.append(
                                f"{rel}:{line_j}: route Url={url_j!r} Method={','.join(sorted(method_j)) if method_j else '(any)'} "
                                f"is unreachable: the earlier route Url={url_i!r} at line {line_i} "
                                f"matches it first (a catch-all before its guard, or a :param before "
                                f"its literal sibling)"
                            )
                            continue
                    pieces_j = url_j.split("/")
                    if len(pieces_i) < len(pieces_j):
                        leading = "/".join(pieces_j[: len(pieces_i)])
                        if route_matches(url_i, leading):
                            problems.append(
                                f"{rel}:{line_j}: route Url={url_j!r} ({len(pieces_j) - 1} segment(s)) "
                                f"follows the shorter route Url={url_i!r} at line {line_i} that "
                                f"matches its leading segments; N-segment routes go before "
                                f"(N-1)-segment routes"
                            )


CHECKS = (
    check_rename_tokens,
    check_naming,
    check_write_discipline,
    check_package_placement,
    check_product_vocabulary,
    check_escalation_containment,
    check_admin_api_containment,
    check_restraint_containment,
    check_state_package_isolation,
    check_entity_types,
    check_screen_scope,
    check_test_class_properties,
    check_destructive_test_guard,
    check_embedded_python,
    check_handler_wire_tests,
    check_non_ascii_literals,
    check_tool_kind,
    check_route_ordering,
    check_agent_job_reach,
    check_tool_dispatch,
    check_state_sql_literal,
)


def main() -> int:
    problems: list[str] = []
    for check in CHECKS:
        check(problems)

    for line in problems:
        print(line)
    # The scanned count is printed on every run, clean or not, so "found nothing wrong" and
    # "looked at nothing" are distinguishable -- the property every gate CI runs states about
    # itself. A run over an empty tree reports 0 files and 0 problems, which reads as the
    # non-result it is.
    # Both numbers are derived, not written down: a hard-coded rule count is one more thing that
    # can disagree with the code, and the ObjectScript file count is the population the rules
    # actually read (iter_source_files counts every file under the roots, including the .ts and
    # .scss only a couple of rules look at).
    scanned = sum(1 for _ in iter_objectscript_files())
    print(
        f"\ncheck-objectscript: scanned {scanned} ObjectScript file(s) over {len(CHECKS)} rule(s); "
        f"{len(problems)} problem(s)",
        file=sys.stderr,
    )
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())

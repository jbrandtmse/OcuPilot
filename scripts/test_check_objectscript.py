#!/usr/bin/env python3
"""Fixture-driven harness for scripts/check-objectscript.py (DW-131).

Both rules Story 1.9 added or rescoped -- the storage-class-only name cap and the
closed-entity-type gate -- were previously pinned only by hand-applied mutations recorded once
in a spec's `## Verification` section, a check that does not repeat on the next change to either
rule. This harness drives the checker's own functions against synthetic fixture trees under a
temporary directory, so both directions of each rule are asserted by the suite instead of by a
reviewer's memory.

It also pins DW-129's half of the story: `iter_named_xdata_blocks` silently skips a same-line
`XData Declaration { ... }` block, so a descriptor written that way is invisible to the
entity-type gate rather than refused or accepted. `ui/tools/screen-mirror.test.mjs` pins the
client reader's half of the same disagreement.

Run: uv run scripts/test_check_objectscript.py
"""

from __future__ import annotations

import importlib.util
import json
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT_PATH = Path(__file__).resolve().parent / "check-objectscript.py"


def _load_module():
    """Load check-objectscript.py by path -- its name is not a valid Python identifier, so a
    plain `import` cannot reach it."""
    spec = importlib.util.spec_from_file_location("ocupilot_check_objectscript", SCRIPT_PATH)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


co = _load_module()


class FixtureTreeCase(unittest.TestCase):
    """Points the checker's module-level ROOT/SCAN_ROOTS at a scratch directory for one test,
    then restores them. Both are process-global state in the imported module, so a leaked ROOT
    would make one test's fixtures visible to the next test's checks."""

    def setUp(self) -> None:
        self._orig_root = co.ROOT
        self._orig_scan_roots = co.SCAN_ROOTS
        self._tmp = tempfile.TemporaryDirectory()
        self.tree = Path(self._tmp.name)
        co.ROOT = self.tree
        co.SCAN_ROOTS = (self.tree / "src" / "OcuPilot", self.tree / "ui")

    def tearDown(self) -> None:
        co.ROOT = self._orig_root
        co.SCAN_ROOTS = self._orig_scan_roots
        self._tmp.cleanup()

    def write(self, rel: str, content: str) -> Path:
        path = self.tree / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        return path

    def write_entity_type(self, types: str = "user,role,widget") -> None:
        self.write(
            "src/OcuPilot/Kernel/EntityType.cls",
            'Class OcuPilot.Kernel.EntityType Extends %RegisteredObject\n'
            '{\n\nParameter TYPES = "' + types + '";\n\n}\n',
        )

    def write_roster(self, packages: str = '["Api", "Install", "Kernel"]') -> None:
        """The roster the package-placement rule reads its fixed folder set out of.

        `packages` is inserted verbatim so a test can hand it something that is not a
        non-empty array of names.
        """
        self.write(
            "src/OcuPilot/Install/Roster.cls",
            "Class OcuPilot.Install.Roster Extends %RegisteredObject\n"
            "{\n\n"
            "XData Manifest\n"
            "{\n"
            '{"packages": ' + packages + "}\n"
            "}\n\n"
            "}\n",
        )

    def write_scope_class(self, instance: str = "instance", namespace: str = "namespace") -> None:
        self.write(
            "src/OcuPilot/Kernel/Scope.cls",
            'Class OcuPilot.Kernel.Scope Extends %RegisteredObject\n'
            '{\n\n'
            'Parameter SCOPEINSTANCE = "' + instance + '";\n\n'
            'Parameter SCOPENAMESPACE = "' + namespace + '";\n\n'
            '}\n',
        )


class TestNamingCapScopedToStorageClasses(FixtureTreeCase):
    """The rescoped `MAX_CLASS_NAME_LENGTH` cap (Consistency Conventions, 2026-09-12): binds a
    class that gets a data global -- extends `%Persistent`, directly or transitively through
    this tree's own classes -- and nothing else."""

    # 50 characters, comfortably over the 29-character limit either way.
    LONG_NAME = "OcuPilot.Test.AVeryLongClassNameThatExceeds29Chars"

    def test_a_long_persistent_class_is_refused(self):
        self.write(
            "src/OcuPilot/Test/Fixture1.cls",
            f"Class {self.LONG_NAME} Extends %Persistent\n{{\n\n}}\n",
        )
        problems: list[str] = []
        co.check_naming(problems)
        self.assertTrue(
            any("storage-global limit" in p and self.LONG_NAME in p for p in problems),
            f"expected the long %Persistent class name refused, got {problems}",
        )

    def test_a_long_non_persistent_class_passes(self):
        self.write(
            "src/OcuPilot/Screen/Descriptor/Fixture2.cls",
            f"Class {self.LONG_NAME} Extends %RegisteredObject\n{{\n\n}}\n",
        )
        problems: list[str] = []
        co.check_naming(problems)
        self.assertEqual(problems, [], "a class with no storage global is never capped")

    def test_a_long_class_reaching_persistent_through_a_project_superclass_is_refused(self):
        self.write(
            "src/OcuPilot/Test/Base.cls",
            "Class OcuPilot.Test.LongCapBase Extends %Persistent\n{\n\n}\n",
        )
        self.write(
            "src/OcuPilot/Test/Fixture3.cls",
            f"Class {self.LONG_NAME} Extends OcuPilot.Test.LongCapBase\n{{\n\n}}\n",
        )
        problems: list[str] = []
        co.check_naming(problems)
        self.assertTrue(
            any(self.LONG_NAME in p for p in problems),
            "a class reaching %Persistent through this tree's own classes is still capped",
        )

    def test_a_long_class_extending_an_unread_vendor_persistent_class_is_not_recognized(self):
        # Documented scope limitation: a superclass this line-oriented scanner never reads (a
        # vendor class, declared nowhere in the tree it walks) is not followed.
        self.write(
            "src/OcuPilot/Test/Fixture4.cls",
            f"Class {self.LONG_NAME} Extends Vendor.Unread.PersistentBase\n{{\n\n}}\n",
        )
        problems: list[str] = []
        co.check_naming(problems)
        self.assertEqual(
            problems,
            [],
            "a vendor superclass this scanner never reads is out of its documented scope",
        )


class TestPackagePlacementReadsTheRoster(FixtureTreeCase):
    """Story 1.16: the fixed package folder set is `src/OcuPilot/Install/Roster.cls`'s, the same
    block `module.xml` is generated from, rather than a literal restated in the checker. A
    roster that cannot be read is reported, never read as an empty set (which would refuse
    every class) nor as an absent check (which would admit every class)."""

    def test_a_class_in_a_declared_package_is_accepted(self):
        self.write_roster()
        self.write(
            "src/OcuPilot/Api/Router.cls",
            "Class OcuPilot.Api.Router Extends %CSP.REST\n{\n\n}\n",
        )
        problems: list[str] = []
        co.check_package_placement(problems)
        self.assertEqual(problems, [])

    def test_a_class_in_a_folder_the_roster_does_not_declare_is_refused(self):
        # "Screen" is a real folder in the shipped tree and deliberately absent from this
        # fixture's roster: the rule must follow the roster, not a set of its own.
        self.write_roster()
        self.write(
            "src/OcuPilot/Screen/Registry.cls",
            "Class OcuPilot.Screen.Registry Extends %RegisteredObject\n{\n\n}\n",
        )
        problems: list[str] = []
        co.check_package_placement(problems)
        self.assertTrue(
            any("OcuPilot.Screen.Registry" in p for p in problems),
            f"expected the undeclared package refused, got {problems}",
        )

    def test_adding_the_folder_to_the_roster_is_the_only_edit_needed(self):
        # The other direction of the same fact: the same file passes once the roster declares
        # its folder, so the rule is reading the roster rather than agreeing with it by
        # coincidence.
        self.write_roster(packages='["Api", "Install", "Kernel", "Screen"]')
        self.write(
            "src/OcuPilot/Screen/Registry.cls",
            "Class OcuPilot.Screen.Registry Extends %RegisteredObject\n{\n\n}\n",
        )
        problems: list[str] = []
        co.check_package_placement(problems)
        self.assertEqual(problems, [])

    def test_a_class_outside_the_shipped_package_is_refused(self):
        self.write_roster()
        self.write(
            "src/OcuPilot/Api/Stray.cls",
            "Class Elsewhere.Api.Stray Extends %RegisteredObject\n{\n\n}\n",
        )
        problems: list[str] = []
        co.check_package_placement(problems)
        self.assertTrue(
            any("Elsewhere.Api.Stray" in p for p in problems),
            f"expected the non-OcuPilot class refused, got {problems}",
        )

    def test_a_missing_roster_is_reported_not_read_as_empty_or_admitting_everything(self):
        # No Roster.cls written at all.
        self.write(
            "src/OcuPilot/Api/Router.cls",
            "Class OcuPilot.Api.Router Extends %CSP.REST\n{\n\n}\n",
        )
        problems: list[str] = []
        co.check_package_placement(problems)
        self.assertEqual(len(problems), 1, f"expected exactly the roster refusal, got {problems}")
        self.assertIn("could not be read", problems[0])
        self.assertIn("Roster.cls", problems[0])

    def test_an_unparseable_roster_is_reported(self):
        self.write(
            "src/OcuPilot/Install/Roster.cls",
            "Class OcuPilot.Install.Roster Extends %RegisteredObject\n"
            "{\n\nXData Manifest\n{\n{not json}\n}\n\n}\n",
        )
        problems: list[str] = []
        co.check_package_placement(problems)
        self.assertTrue(
            any("not parseable JSON" in p for p in problems),
            f"expected the unparseable roster reported, got {problems}",
        )

    def test_a_roster_with_no_packages_array_is_reported_rather_than_read_as_an_empty_set(self):
        self.write_roster(packages="[]")
        self.write(
            "src/OcuPilot/Api/Router.cls",
            "Class OcuPilot.Api.Router Extends %CSP.REST\n{\n\n}\n",
        )
        problems: list[str] = []
        co.check_package_placement(problems)
        self.assertEqual(len(problems), 1, f"expected exactly the roster refusal, got {problems}")
        self.assertIn("no non-empty 'packages' array", problems[0])


class TestShippedRoster(unittest.TestCase):
    """The production reading of the rule, over the real tree rather than a fixture -- so the
    guard is exercised where it actually runs, not only where it is injected. Deliberately not
    a `FixtureTreeCase`: that class points `ROOT` at a scratch directory, which is the opposite
    of what this one needs."""

    def test_the_roster_declares_exactly_the_package_folders_on_disk(self):
        problems: list[str] = []
        packages = co.read_fixed_packages(problems)
        self.assertEqual(problems, [], "the shipped roster reads cleanly")
        self.assertIsNotNone(packages)
        on_disk = {p.name for p in (co.ROOT / "src" / "OcuPilot").iterdir() if p.is_dir()}
        self.assertEqual(packages, on_disk)


class TestEntityTypeRule(FixtureTreeCase):
    """AD-14: every entity type a descriptor's `XData Declaration` names must exist in
    `Kernel/EntityType.cls`'s closed `TYPES` parameter -- the "build fails on a value not in
    it" mechanism, in the tree rather than only on the instance."""

    def test_a_known_entity_type_is_accepted(self):
        self.write_entity_type()
        self.write(
            "src/OcuPilot/Screen/Descriptor/Good.cls",
            'Class OcuPilot.Screen.Descriptor.Good Extends OcuPilot.Screen.Descriptor.Base\n'
            '{\n\nXData Declaration\n{\n{"entityType": "user"}\n}\n\n}\n',
        )
        problems: list[str] = []
        co.check_entity_types(problems)
        self.assertEqual(problems, [])

    def test_an_unknown_primary_entity_type_is_refused_naming_the_file_and_the_value(self):
        self.write_entity_type()
        self.write(
            "src/OcuPilot/Screen/Descriptor/Bad.cls",
            'Class OcuPilot.Screen.Descriptor.Bad Extends OcuPilot.Screen.Descriptor.Base\n'
            '{\n\nXData Declaration\n{\n{"entityType": "not-a-real-entity-type"}\n}\n\n}\n',
        )
        problems: list[str] = []
        co.check_entity_types(problems)
        self.assertTrue(
            any("Bad.cls" in p and "not-a-real-entity-type" in p for p in problems),
            f"expected the unknown value refused by name and file, got {problems}",
        )

    def test_an_unknown_secondary_entity_type_is_refused_too(self):
        self.write_entity_type()
        self.write(
            "src/OcuPilot/Screen/Descriptor/Bad2.cls",
            'Class OcuPilot.Screen.Descriptor.Bad2 Extends OcuPilot.Screen.Descriptor.Base\n'
            '{\n\nXData Declaration\n{\n'
            '{"entityType": "user", "secondaryEntityTypes": ["role", "not-one"]}\n'
            '}\n\n}\n',
        )
        problems: list[str] = []
        co.check_entity_types(problems)
        self.assertTrue(
            any("not-one" in p for p in problems),
            "a primary-only check would miss a bad secondary type",
        )

    def test_an_unreadable_vocabulary_is_reported_not_read_as_empty_or_admitting_everything(self):
        # No EntityType.cls written at all -- the vocabulary source is missing.
        self.write(
            "src/OcuPilot/Screen/Descriptor/Good.cls",
            'Class OcuPilot.Screen.Descriptor.Good Extends OcuPilot.Screen.Descriptor.Base\n'
            '{\n\nXData Declaration\n{\n{"entityType": "user"}\n}\n\n}\n',
        )
        problems: list[str] = []
        co.check_entity_types(problems)
        self.assertTrue(
            any("could not be read" in p for p in problems),
            "a missing vocabulary source must be reported, never read as an empty or "
            "admitting set",
        )


class TestScreenScopeRule(FixtureTreeCase):
    """AD-13 (Story 1.11, DW-158): a descriptor's declared `scope` must be one of
    `Kernel/Scope.cls`'s own two parameter values -- the same build-time gate as the entity-type
    rule, for the value that was previously refused only by `Screen.Registry.Validate` on the
    instance."""

    def test_a_declared_instance_scope_is_accepted(self):
        self.write_scope_class()
        self.write(
            "src/OcuPilot/Screen/Descriptor/Good.cls",
            'Class OcuPilot.Screen.Descriptor.Good Extends OcuPilot.Screen.Descriptor.Base\n'
            '{\n\nXData Declaration\n{\n{"scope": "instance"}\n}\n\n}\n',
        )
        problems: list[str] = []
        co.check_screen_scope(problems)
        self.assertEqual(problems, [])

    def test_a_declared_namespace_scope_is_accepted(self):
        self.write_scope_class()
        self.write(
            "src/OcuPilot/Screen/Descriptor/Good2.cls",
            'Class OcuPilot.Screen.Descriptor.Good2 Extends OcuPilot.Screen.Descriptor.Base\n'
            '{\n\nXData Declaration\n{\n{"scope": "namespace"}\n}\n\n}\n',
        )
        problems: list[str] = []
        co.check_screen_scope(problems)
        self.assertEqual(problems, [])

    def test_a_third_spelling_is_refused_naming_the_file_and_the_value(self):
        self.write_scope_class()
        self.write(
            "src/OcuPilot/Screen/Descriptor/Bad.cls",
            'Class OcuPilot.Screen.Descriptor.Bad Extends OcuPilot.Screen.Descriptor.Base\n'
            '{\n\nXData Declaration\n{\n{"scope": "cluster"}\n}\n\n}\n',
        )
        problems: list[str] = []
        co.check_screen_scope(problems)
        self.assertTrue(
            any("Bad.cls" in p and "cluster" in p for p in problems),
            f"expected the unknown scope refused by name and file, got {problems}",
        )

    def test_a_declaration_naming_no_scope_is_refused(self):
        # `Screen.Registry.Validate` compares the declared value against both words with no
        # exemption for `""`, so a descriptor that omits `scope` fails on the instance. Refusing
        # only a misspelled value here would leave the omitted case failing at runtime and
        # passing the build -- the split DW-158 exists to close, for the likelier mistake.
        self.write_scope_class()
        self.write(
            "src/OcuPilot/Screen/Descriptor/Silent.cls",
            'Class OcuPilot.Screen.Descriptor.Silent Extends OcuPilot.Screen.Descriptor.Base\n'
            '{\n\nXData Declaration\n{\n{"route": "/silent"}\n}\n\n}\n',
        )
        problems: list[str] = []
        co.check_screen_scope(problems)
        self.assertTrue(
            any("Silent.cls" in p and "names no 'scope'" in p for p in problems),
            f"expected the omitted scope refused by file, got {problems}",
        )

    def test_an_unreadable_vocabulary_is_reported_not_read_as_empty_or_admitting_everything(self):
        # No Scope.cls written at all -- the vocabulary source is missing.
        self.write(
            "src/OcuPilot/Screen/Descriptor/Good.cls",
            'Class OcuPilot.Screen.Descriptor.Good Extends OcuPilot.Screen.Descriptor.Base\n'
            '{\n\nXData Declaration\n{\n{"scope": "instance"}\n}\n\n}\n',
        )
        problems: list[str] = []
        co.check_screen_scope(problems)
        self.assertTrue(
            any("could not be read" in p for p in problems),
            "a missing vocabulary source must be reported, never read as an empty or "
            "admitting set",
        )

    def test_a_scope_declared_by_overriding_declarationjson_is_outside_this_readers_scope(self):
        # OcuPilot.Test.Scope.Bad's own pattern: `scope` set in a DeclarationJson class method
        # body, never in an XData Declaration block -- invisible to this reader, the same
        # documented limitation the entity-type rule has for the same shape of fixture.
        self.write_scope_class()
        self.write(
            "src/OcuPilot/Test/Scope/Bad.cls",
            'Class OcuPilot.Test.Scope.Bad Extends OcuPilot.Screen.Descriptor.Base\n'
            '{\n\nParameter BADSCOPE = "cluster";\n\n'
            'ClassMethod DeclarationJson(Output pObject As %DynamicObject) As %Status\n'
            '{\n    Set pObject = {}\n    Do pObject.%Set("scope", ..#BADSCOPE)\n    Quit $$$OK\n}\n\n}\n',
        )
        problems: list[str] = []
        co.check_screen_scope(problems)
        self.assertEqual(
            problems,
            [],
            "a scope set programmatically rather than declared in XData is outside this "
            "line-oriented reader's scope, same as the entity-type rule's fixture exemption",
        )


class TestDW129SingleLineXDataDisagreement(FixtureTreeCase):
    """DW-129 -- pinned, not fixed here. `iter_named_xdata_blocks` silently skips a same-line
    `XData Declaration { ... }` block (opening and closing brace on the declaration line
    itself), so a descriptor written that way is never checked against the entity-type
    vocabulary at all: not flagged, not refused, simply invisible to the gate. Every descriptor
    in the tree today uses the two-line UDL convention, so this is a silent bypass of the AD-14
    build gate for a form no descriptor currently uses -- not a live defect.
    `ui/tools/screen-mirror.test.mjs` pins the client reader's half of the same disagreement.
    """

    def test_a_same_line_declaration_block_yields_no_block_at_all(self):
        source = (
            'Class OcuPilot.Screen.Descriptor.Inline Extends OcuPilot.Screen.Descriptor.Base\n'
            '{\n\nXData Declaration { "entityType": "user" }\n\n}\n'
        )
        blocks = list(co.iter_named_xdata_blocks(source, "Declaration"))
        self.assertEqual(blocks, [], "the same-line form yields no block at all")

    def test_a_bad_entity_type_written_in_the_same_line_form_passes_the_checker(self):
        self.write_entity_type()
        self.write(
            "src/OcuPilot/Screen/Descriptor/Inline.cls",
            'Class OcuPilot.Screen.Descriptor.Inline Extends OcuPilot.Screen.Descriptor.Base\n'
            '{\n\nXData Declaration { "entityType": "not-a-real-entity-type" }\n\n}\n',
        )
        problems: list[str] = []
        co.check_entity_types(problems)
        self.assertEqual(
            problems,
            [],
            "known limitation (DW-129): the same-line form bypasses the gate silently -- if "
            "this ever finds a problem, the reader has been fixed and this pin is stale",
        )


class TestStringAwareBraceRule(FixtureTreeCase):
    """`brace_delta` counts a brace only outside a double-quoted span, so a brace inside a JSON
    or XML string neither ends an XData block early nor keeps it open. Both brace walks use it:
    `iter_named_xdata_blocks` (the entity-type and scope rules) and `iter_code_lines` (the write
    discipline, escalation and state-isolation rules)."""

    def test_brace_delta_ignores_braces_inside_strings_and_honours_escapes(self):
        self.assertEqual(co.brace_delta("{"), 1)
        self.assertEqual(co.brace_delta('"reason": "a } brace",'), 0)
        self.assertEqual(co.brace_delta('"a \\" quote { brace",'), 0)
        self.assertEqual(co.brace_delta('{"k": "}"}, {'), 1)

    def test_brace_delta_agrees_with_the_client_mirror_brace_delta(self):
        """The same lines through `braceDelta` in `ui/tools/screen-mirror.mjs`, run by Node: the
        two readers must end every block on the same line. Needs `node` on PATH."""
        lines = [
            "{",
            "},",
            "",
            '"reason": "a } brace",',
            '"a \\" quote { brace",',
            '"nested": {"k": "}"},',
            '{"k": "}"}, {',
            '"ends in a backslash \\\\", {',
            '<note text="stray quote {>',
            '<route Url="/:id" Dispatch="C:\\">{',
            "Write stays inside the block }",
        ]
        mirror = SCRIPT_PATH.resolve().parent.parent / "ui" / "tools" / "screen-mirror.mjs"
        script = (
            f"import {{ braceDelta }} from {json.dumps(mirror.as_uri())};"
            "let input = '';"
            "for await (const chunk of process.stdin) input += chunk;"
            "process.stdout.write(JSON.stringify(JSON.parse(input).map(braceDelta)));"
        )
        result = subprocess.run(
            ["node", "--input-type=module", "-e", script],
            input=json.dumps(lines),
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, f"node could not run braceDelta: {result.stderr}")
        self.assertEqual(json.loads(result.stdout), [co.brace_delta(line) for line in lines])

    def test_an_unknown_entity_type_after_a_braced_string_is_still_refused(self):
        self.write_entity_type()
        self.write(
            "src/OcuPilot/Screen/Descriptor/Braced.cls",
            'Class OcuPilot.Screen.Descriptor.Braced Extends OcuPilot.Screen.Descriptor.Base\n'
            '{\n\nXData Declaration\n{\n'
            '{"reason": "a } brace",\n'
            '"entityType": "not-a-real-entity-type"}\n'
            '}\n\n}\n',
        )
        problems: list[str] = []
        co.check_entity_types(problems)
        self.assertTrue(
            any("Braced.cls" in p and "not-a-real-entity-type" in p for p in problems),
            f"expected the value after the braced string to be read and refused, got {problems}",
        )

    def test_a_write_token_after_a_braced_string_inside_xdata_is_not_flagged(self):
        self.write(
            "src/OcuPilot/Kernel/Probe.cls",
            "Class OcuPilot.Kernel.Probe Extends %RegisteredObject\n"
            "{\n\n"
            "XData Notes\n"
            "{\n"
            '<notes reason="a } brace">\n'
            "<note>Write stays inside the block</note>\n"
            "</notes>\n"
            "}\n\n"
            "}\n",
        )
        problems: list[str] = []
        co.check_write_discipline(problems)
        self.assertEqual(problems, [], "a line inside the XData body is not code")




class TestTestClassPropertyNames(FixtureTreeCase):
    """Story 1.17: no property whose name begins with `Test` on a `%UnitTest.TestCase` subclass.

    The compiler generates `<PropName>DisplayToLogical`, `<PropName>Normalize`,
    `<PropName>IsValid` and `<PropName>LogicalToDisplay` for every property, and the framework's
    method-discovery loop matches every one of them as a test method. The rule was written down
    in `.claude/rules/objectscript-testing.md` and enforced by nothing.
    """

    def test_a_test_prefixed_property_on_a_test_case_is_refused(self):
        self.write(
            "src/OcuPilot/Test/Probe.cls",
            "Class OcuPilot.Test.Probe Extends %UnitTest.TestCase\n"
            "{\n\nProperty TestNsPrepared As %Boolean;\n\n}\n",
        )
        problems: list[str] = []
        co.check_test_class_properties(problems)
        self.assertTrue(
            any("TestNsPrepared" in p and "DisplayToLogical" in p for p in problems),
            f"expected the Test-prefixed property refused with the generated names, got {problems}",
        )

    def test_a_differently_prefixed_property_passes(self):
        self.write(
            "src/OcuPilot/Test/Probe.cls",
            "Class OcuPilot.Test.Probe Extends %UnitTest.TestCase\n"
            "{\n\nProperty PreparedTestNs As %Boolean;\n\n}\n",
        )
        problems: list[str] = []
        co.check_test_class_properties(problems)
        self.assertEqual(problems, [], "a prefix that does not begin with Test is the fix")

    def test_a_test_prefixed_property_on_an_ordinary_class_passes(self):
        # The rule is about the framework's discovery loop, which only runs over TestCase
        # subclasses. A shipped class may legitimately carry a property named TestMode.
        self.write(
            "src/OcuPilot/Kernel/Probe.cls",
            "Class OcuPilot.Kernel.Probe Extends %RegisteredObject\n"
            "{\n\nProperty TestMode As %Boolean;\n\n}\n",
        )
        problems: list[str] = []
        co.check_test_class_properties(problems)
        self.assertEqual(problems, [])

    def test_a_class_reaching_testcase_through_a_project_superclass_is_refused_too(self):
        self.write(
            "src/OcuPilot/Test/Base.cls",
            "Class OcuPilot.Test.ProbeBase Extends %UnitTest.TestCase\n{\n\n}\n",
        )
        self.write(
            "src/OcuPilot/Test/Probe.cls",
            "Class OcuPilot.Test.Probe Extends OcuPilot.Test.ProbeBase\n"
            "{\n\nProperty TestNsPrepared As %Boolean;\n\n}\n",
        )
        problems: list[str] = []
        co.check_test_class_properties(problems)
        self.assertTrue(any("TestNsPrepared" in p for p in problems))


class TestEmbeddedPythonRule(FixtureTreeCase):
    """AD-18: a `[ Language = python ]` method does not compile on an instance without embedded
    Python configured, so the install that loads it fails there."""

    def test_an_embedded_python_method_is_refused(self):
        self.write(
            "src/OcuPilot/Kernel/Probe.cls",
            "Class OcuPilot.Kernel.Probe Extends %RegisteredObject\n"
            "{\n\nClassMethod Run() As %Status [ Language = python ]\n{\n    return 1\n}\n\n}\n",
        )
        problems: list[str] = []
        co.check_embedded_python(problems)
        self.assertTrue(
            any("Language = python" in p for p in problems),
            f"expected the embedded-Python method refused, got {problems}",
        )

    def test_the_spelling_is_matched_whatever_the_keyword_order_and_case(self):
        for keywords in ("[ Language = python, Final ]", "[ Final, Language=Python ]"):
            with self.subTest(keywords=keywords):
                self.write(
                    "src/OcuPilot/Kernel/Probe.cls",
                    "Class OcuPilot.Kernel.Probe Extends %RegisteredObject\n"
                    f"{{\n\nClassMethod Run() As %Status {keywords}\n{{\n    return 1\n}}\n\n}}\n",
                )
                problems: list[str] = []
                co.check_embedded_python(problems)
                self.assertTrue(problems, f"{keywords} must be refused too")

    def test_a_comment_naming_the_keyword_is_exempt(self):
        # The rule's own explanation has to be writable somewhere, and a doc comment is where
        # this tree writes one.
        self.write(
            "src/OcuPilot/Kernel/Probe.cls",
            "/// <p>No method here is [ Language = python ]: see AD-18.</p>\n"
            "Class OcuPilot.Kernel.Probe Extends %RegisteredObject\n{\n\n}\n",
        )
        problems: list[str] = []
        co.check_embedded_python(problems)
        self.assertEqual(problems, [])


class TestHandlerWireTestRule(FixtureTreeCase):
    """Consistency Conventions: "every handler gets an HTTP integration test asserting status,
    content type and body shape" -- a rule in a document until Story 1.17, and a route added with
    no wire test was invisible to every gate."""

    WIRE_BODY = (
        "Class OcuPilot.Test.Wire Extends %UnitTest.TestCase\n"
        "{\n\nMethod TestRoute()\n{\n"
        '    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/instance", "", "", .tStatus, .tBody, .tHeaders)\n'
        "    Do $$$AssertEquals(tStatus, 200, \"answers\")\n"
        '    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as json")\n'
        "    Set tObj = ##class(%DynamicObject).%FromJSON(tBody)\n"
        "}\n\n}\n"
    )

    def write_router(self, url: str = "/instance", call: str = "Instance") -> None:
        self.write(
            "src/OcuPilot/Api/Router.cls",
            "Class OcuPilot.Api.Router Extends %CSP.REST\n"
            "{\n\nXData UrlMap\n{\n<Routes>\n"
            f'  <Route Url="{url}" Method="GET" Call="{call}"/>\n'
            "</Routes>\n}\n\n}\n",
        )

    def test_a_route_with_a_complete_wire_test_passes(self):
        self.write_router()
        self.write("src/OcuPilot/Test/Wire.cls", self.WIRE_BODY)
        problems: list[str] = []
        co.check_handler_wire_tests(problems)
        self.assertEqual(problems, [], f"expected the covered route accepted, got {problems}")

    def test_a_route_no_test_names_at_all_is_refused(self):
        self.write_router(url="/uncovered", call="Uncovered")
        self.write("src/OcuPilot/Test/Wire.cls", self.WIRE_BODY)
        problems: list[str] = []
        co.check_handler_wire_tests(problems)
        self.assertTrue(
            any("/uncovered" in p and "names" in p for p in problems),
            f"expected the uncovered route refused, got {problems}",
        )

    def test_a_route_named_by_a_test_that_asserts_no_content_type_is_refused(self):
        # The defect this catches is the one the shipped suite actually had: three routes named
        # by a wire test that asserted status and body shape and never the content type.
        self.write_router()
        self.write(
            "src/OcuPilot/Test/Wire.cls",
            self.WIRE_BODY.replace(
                '    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as json")\n',
                "",
            ),
        )
        problems: list[str] = []
        co.check_handler_wire_tests(problems)
        self.assertTrue(
            any("content-type assertion" in p for p in problems),
            f"expected the missing content-type assertion named, got {problems}",
        )

    def test_a_pattern_route_is_keyed_by_its_dispatch_class(self):
        # `/(.*)` identifies nothing as a literal, so the key is the class's own name -- which is
        # how OcuPilot.Api.StaticHandler's catch-all is covered.
        self.write(
            "src/OcuPilot/Api/StaticHandler.cls",
            "Class OcuPilot.Api.StaticHandler Extends %CSP.REST\n"
            '{\n\nXData UrlMap\n{\n<Routes>\n  <Route Url="/(.*)" Method="GET" Call="Serve"/>\n</Routes>\n}\n\n}\n',
        )
        problems: list[str] = []
        co.check_handler_wire_tests(problems)
        self.assertTrue(
            any("OcuPilot.Api.StaticHandler" in p for p in problems),
            f"expected the pattern route keyed by its class, got {problems}",
        )

        self.write(
            "src/OcuPilot/Test/Static.cls",
            self.WIRE_BODY.replace(
                "Class OcuPilot.Test.Wire", "Class OcuPilot.Test.Static"
            ).replace(
                "Method TestRoute()",
                'Method TestRoute()\n{\n    Set tHandler = "OcuPilot.Api.StaticHandler"\n}\n\nMethod TestRouteTwo()',
            ),
        )
        problems2: list[str] = []
        co.check_handler_wire_tests(problems2)
        self.assertEqual(problems2, [], f"expected the named pattern route accepted, got {problems2}")

    def test_a_param_route_is_keyed_by_its_own_declared_path(self):
        # DW-364: `:id` is an ordinary character sequence in the declared path, so a route
        # carrying a parameter keys on itself. Before this, every such route fell back to the
        # dispatch class, and one test class naming `OcuPilot.Api.Router` covered all of them --
        # including a route no test had ever driven.
        self.write(
            "src/OcuPilot/Api/Router.cls",
            "Class OcuPilot.Api.Router Extends %CSP.REST\n"
            "{\n\nXData UrlMap\n{\n<Routes>\n"
            '  <Route Url="/widgets/:id/detail" Method="GET" Call="WidgetDetail"/>\n'
            '  <Route Url="/widgets/:id" Method="GET" Call="WidgetRead"/>\n'
            "</Routes>\n}\n\n}\n",
        )
        # A wire test that names the dispatch class and one of the two routes. The other must
        # still be refused, which is exactly what the class-name key could not express.
        self.write(
            "src/OcuPilot/Test/Wire.cls",
            self.WIRE_BODY.replace(
                "Method TestRoute()",
                'Method TestRoute()\n{\n'
                '    Set tRouter = "OcuPilot.Api.Router"\n'
                '    Set tCovered = "/widgets/:id"\n'
                "}\n\nMethod TestRouteTwo()",
            ),
        )
        problems: list[str] = []
        co.check_handler_wire_tests(problems)
        self.assertTrue(
            any("/widgets/:id/detail" in p for p in problems),
            f"expected the unnamed :param route refused, got {problems}",
        )
        self.assertFalse(
            any("'/widgets/:id'" in p for p in problems),
            f"expected the named :param route accepted, got {problems}",
        )

    def write_turn_router(self) -> None:
        self.write(
            "src/OcuPilot/Api/Router.cls",
            "Class OcuPilot.Api.Router Extends %CSP.REST\n"
            "{\n\nXData UrlMap\n{\n<Routes>\n"
            '  <Route Url="/turn/:id/progress" Method="GET" Call="TurnProgress"/>\n'
            '  <Route Url="/turn/abandon" Method="POST" Call="TurnAbandon"/>\n'
            '  <Route Url="/turn" Method="POST" Call="TurnStart"/>\n'
            "</Routes>\n}\n\n}\n",
        )

    def test_a_shorter_route_is_not_covered_by_a_test_naming_only_longer_ones(self):
        # DW-400: substring keying let `/turn/abandon` or `/turn/:id/progress` stand in for
        # `/turn`, so the route that starts a turn could ship with no wire test of its own.
        self.write_turn_router()
        self.write(
            "src/OcuPilot/Test/Wire.cls",
            self.WIRE_BODY.replace(
                "Method TestRoute()",
                'Method TestRoute()\n{\n'
                '    Set tA = "POST /turn/abandon"\n'
                '    Set tB = "GET /turn/:id/progress"\n'
                '    Set tVerbs = "POST"\n'
                "}\n\nMethod TestRouteTwo()",
            ),
        )
        problems: list[str] = []
        co.check_handler_wire_tests(problems)
        self.assertTrue(
            any("Url='/turn' " in p for p in problems),
            f"expected /turn refused when only longer routes are named, got {problems}",
        )
        self.assertFalse(
            any("'/turn/abandon'" in p or "'/turn/:id/progress'" in p for p in problems),
            f"expected the two named routes accepted, got {problems}",
        )

    def test_a_second_method_on_one_url_is_its_own_obligation(self):
        # DW-400's other half: GET and POST on one path were one key, so a GET test covered a POST
        # route no test had ever sent.
        self.write(
            "src/OcuPilot/Api/Router.cls",
            "Class OcuPilot.Api.Router Extends %CSP.REST\n"
            "{\n\nXData UrlMap\n{\n<Routes>\n"
            '  <Route Url="/widgets" Method="GET" Call="WidgetList"/>\n'
            '  <Route Url="/widgets" Method="POST" Call="WidgetCreate"/>\n'
            "</Routes>\n}\n\n}\n",
        )
        self.write(
            "src/OcuPilot/Test/Wire.cls",
            self.WIRE_BODY.replace('"/instance"', '"/widgets"'),
        )
        problems: list[str] = []
        co.check_handler_wire_tests(problems)
        self.assertTrue(
            any("Call='WidgetCreate'" in p for p in problems),
            f"expected the POST route refused with only a GET test, got {problems}",
        )
        self.assertFalse(
            any("Call='WidgetList'" in p for p in problems),
            f"expected the GET route accepted, got {problems}",
        )

    def test_a_route_at_the_tail_of_a_longer_route_is_not_covered_by_it(self):
        # DW-400, the other direction: a URL bounded only at its end let `/logs/errors/namespaces`
        # stand in for `/namespaces`. The API base in front of a route still names it.
        self.write(
            "src/OcuPilot/Api/Router.cls",
            "Class OcuPilot.Api.Router Extends %CSP.REST\n"
            "{\n\nXData UrlMap\n{\n<Routes>\n"
            '  <Route Url="/logs/errors/namespaces" Method="GET" Call="LogErrorNamespaces"/>\n'
            '  <Route Url="/namespaces" Method="GET" Call="Namespaces"/>\n'
            "</Routes>\n}\n\n}\n",
        )
        self.write(
            "src/OcuPilot/Test/Wire.cls",
            self.WIRE_BODY.replace('"/instance"', '"/api/ocupilot/logs/errors/namespaces"'),
        )
        problems: list[str] = []
        co.check_handler_wire_tests(problems)
        self.assertTrue(
            any("Call='Namespaces'" in p for p in problems),
            f"expected /namespaces refused when only the longer route is named, got {problems}",
        )
        self.assertFalse(
            any("Call='LogErrorNamespaces'" in p for p in problems),
            f"expected the route named behind the API base accepted, got {problems}",
        )

    def test_a_doc_comment_naming_the_class_does_not_satisfy_the_rule(self):
        # The rule asks whether a test NAMES the route in code. Over the whole file text a `///`
        # line mentioning the dispatch class satisfied it, so a route's own doc comment could
        # pass the gate written to notice that route had no test.
        self.write(
            "src/OcuPilot/Api/StaticHandler.cls",
            "Class OcuPilot.Api.StaticHandler Extends %CSP.REST\n"
            '{\n\nXData UrlMap\n{\n<Routes>\n  <Route Url="/(.*)" Method="GET" Call="Serve"/>\n</Routes>\n}\n\n}\n',
        )
        self.write(
            "src/OcuPilot/Test/Static.cls",
            self.WIRE_BODY.replace(
                "Class OcuPilot.Test.Wire", "Class OcuPilot.Test.Static"
            ).replace("Method TestRoute()", "/// OcuPilot.Api.StaticHandler\nMethod TestRoute()"),
        )
        problems: list[str] = []
        co.check_handler_wire_tests(problems)
        self.assertTrue(
            any("OcuPilot.Api.StaticHandler" in p for p in problems),
            f"expected a comment-only mention to be refused, got {problems}",
        )

    def test_a_literal_non_ascii_byte_in_an_xdata_string_is_refused(self):
        # XData is the tree's other string source: the roster's application descriptions are
        # asserted onto Security.Applications and emitted verbatim into module.xml, and
        # iter_code_lines skips XData bodies by design -- so the rule read only half the file.
        self.write(
            "src/OcuPilot/Install/Roster.cls",
            "Class OcuPilot.Install.Roster Extends %RegisteredObject\n"
            "{\n\nXData Manifest\n{\n{\n"
            '  "description": "an em dash \u2014 inside XData"\n'
            "}\n}\n\n}\n",
        )
        problems: list[str] = []
        co.check_non_ascii_literals(problems)
        self.assertTrue(
            any("U+2014" in p and "XData" in p for p in problems),
            f"expected the XData em dash refused, got {problems}",
        )

    def test_a_route_whose_call_precedes_its_url_is_still_read(self):
        # XML fixes no attribute order. The single-order pattern this replaced skipped this
        # spelling silently -- a route the rule exists to notice, passing because of where its
        # attributes happened to sit.
        self.write(
            "src/OcuPilot/Api/Reversed.cls",
            "Class OcuPilot.Api.Reversed Extends %CSP.REST\n"
            '{\n\nXData UrlMap\n{\n<Routes>\n  <Route Method="GET" Call="Thing" Url="/thing"/>\n</Routes>\n}\n\n}\n',
        )
        problems: list[str] = []
        co.check_handler_wire_tests(problems)
        self.assertTrue(
            any("/thing" in p for p in problems),
            f"expected the reversed-attribute route to be read, got {problems}",
        )

    def test_a_test_class_own_urlmap_is_not_a_shipped_handler(self):
        # Fixture route tables under src/OcuPilot/Test/ are the suite's own, not handlers the
        # product serves, and requiring a wire test for each would be a rule about fixtures.
        self.write(
            "src/OcuPilot/Test/RouterFixture.cls",
            "Class OcuPilot.Test.RouterFixture Extends %CSP.REST\n"
            '{\n\nXData UrlMap\n{\n<Routes>\n  <Route Url="/fixture" Method="GET" Call="Fixture"/>\n</Routes>\n}\n\n}\n',
        )
        problems: list[str] = []
        co.check_handler_wire_tests(problems)
        self.assertEqual(problems, [])


class TestAgentJobReachRule(FixtureTreeCase):
    """Story 4.1: the turn job reaches the provider port and OcuPilot's own state and nothing that
    acts on the instance, and the one spawn in shipped code is the job's own."""

    LOOP = "src/OcuPilot/Kernel/Agent/Loop.cls"

    def write_loop(self, line: str) -> None:
        self.write(
            self.LOOP,
            "Class OcuPilot.Kernel.Agent.Loop Extends %RegisteredObject\n"
            "{\n\nClassMethod Run()\n{\n    " + line + "\n}\n\n}\n",
        )

    def test_another_port_named_under_kernel_agent_is_refused(self):
        self.write_loop('Set tPort = "OcuPilot.Port.AdminPort"')
        problems: list[str] = []
        co.check_agent_job_reach(problems)
        self.assertTrue(
            any("OcuPilot.Port.AdminPort" in p and "Kernel/Agent/" in p for p in problems),
            f"expected the admin port refused, got {problems}",
        )

    def test_a_handler_a_screen_and_a_slice_are_refused(self):
        for name in ("OcuPilot.Api.Definitions", "OcuPilot.Screen.Registry", "OcuPilot.Area.Task.List"):
            with self.subTest(name=name):
                self.write_loop(f"Do ##class({name}).Go()")
                problems: list[str] = []
                co.check_agent_job_reach(problems)
                self.assertTrue(any(name in p for p in problems), f"expected {name} refused, got {problems}")

    def test_the_provider_port_and_the_vocabulary_class_pass(self):
        self.write_loop(
            'Do $ClassMethod("OcuPilot.Port.ProviderPort", "Invoke") '
            "Set tCode = ##class(OcuPilot.Api.Error).#TURNSTOPPED"
        )
        problems: list[str] = []
        co.check_agent_job_reach(problems)
        self.assertEqual(problems, [], f"expected the port and the vocabulary accepted, got {problems}")

    def test_the_tool_registry_passes_and_every_other_screen_class_is_refused(self):
        # Story 4.2: the dispatcher reaches the tools through the registry and nothing else of the
        # screen layer.
        self.write_loop('Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ResolveWire(tName, .tTool)')
        problems: list[str] = []
        co.check_agent_job_reach(problems)
        self.assertEqual(problems, [], f"expected the registry admitted, got {problems}")
        for name in ("OcuPilot.Screen.Tool.Read", "OcuPilot.Screen.Tool.RegistryProbe", "OcuPilot.Screen.Tool.Registry.Inner", "OcuPilot.Screen.Gate"):
            with self.subTest(name=name):
                self.write_loop(f'Set tClass = "{name}"')
                problems = []
                co.check_agent_job_reach(problems)
                self.assertTrue(any(name in p for p in problems), f"expected {name} refused, got {problems}")

    def test_a_job_outside_the_job_class_is_refused_and_inside_it_passes(self):
        spawn = "Job ##class(OcuPilot.Kernel.Agent.Job).Run(1)::5"
        self.write(
            "src/OcuPilot/Api/Turn.cls",
            "Class OcuPilot.Api.Turn Extends %RegisteredObject\n{\n\nClassMethod Go()\n{\n    "
            + spawn
            + "\n}\n\n}\n",
        )
        self.write(
            "src/OcuPilot/Kernel/Agent/Job.cls",
            "Class OcuPilot.Kernel.Agent.Job Extends %RegisteredObject\n{\n\nClassMethod Start()\n{\n    "
            + spawn
            + "\n}\n\n}\n",
        )
        problems: list[str] = []
        co.check_agent_job_reach(problems)
        self.assertTrue(any("Api/Turn.cls" in p and "'JOB'" in p for p in problems), f"got {problems}")
        self.assertFalse(any(p.startswith("src/OcuPilot/Kernel/Agent/Job.cls") for p in problems), f"got {problems}")

    def test_a_state_class_naming_the_agent_package_is_refused(self):
        # Rule 7: the loop reaches the provider port, so a storage method naming it could re-enter
        # a provider call from inside an escalated frame (AD-9).
        self.write(
            "src/OcuPilot/Kernel/State/Probe.cls",
            "Class OcuPilot.Kernel.State.Probe Extends %RegisteredObject\n{\n\nClassMethod Go()\n{\n"
            '    Do ##class(OcuPilot.Kernel.Agent.Loop).Run()\n}\n\n}\n',
        )
        problems: list[str] = []
        co.check_state_package_isolation(problems)
        self.assertTrue(
            any("State/Probe.cls" in p and "OcuPilot.Kernel.Agent" in p for p in problems),
            f"expected the agent package refused under Kernel/State/, got {problems}",
        )

    def test_a_test_helper_the_job_variable_and_a_string_pass(self):
        self.write(
            "src/OcuPilot/Test/Helper.cls",
            "Class OcuPilot.Test.Helper Extends %RegisteredObject\n{\n\nClassMethod Go()\n{\n"
            "    Job ##class(OcuPilot.Test.Helper).Other()::5\n}\n\n}\n",
        )
        self.write_loop('Set tPid = $Job  Set tText = "the job could not be started"')
        problems: list[str] = []
        co.check_agent_job_reach(problems)
        self.assertEqual(problems, [], f"expected all three accepted, got {problems}")


class TestNonAsciiStringLiteralRule(FixtureTreeCase):
    """DW-43, Rule 14: non-ASCII is authored as `$Char(<code point>)`, never as a literal byte,
    so the shipped string and whatever pins it are the same bytes. Comments are exempt, which is
    Rule 14's own carve-out and what keeps this from being a quarter of a thousand-line diff over
    doc-comment em dashes."""

    # Written as an escape, not a literal byte -- the discipline the rule enforces.
    EM_DASH = "\u2014"

    def test_a_literal_non_ascii_byte_in_a_string_literal_is_refused(self):
        self.write(
            "src/OcuPilot/Kernel/Probe.cls",
            "Class OcuPilot.Kernel.Probe Extends %RegisteredObject\n"
            "{\n\nClassMethod Run() As %String\n{\n"
            f'    Quit "a {self.EM_DASH} b"\n'
            "}\n\n}\n",
        )
        problems: list[str] = []
        co.check_non_ascii_literals(problems)
        self.assertTrue(
            any("U+2014" in p and "$Char(8212)" in p for p in problems),
            f"expected the literal refused with its escape named, got {problems}",
        )

    def test_the_same_character_built_with_char_passes(self):
        self.write(
            "src/OcuPilot/Kernel/Probe.cls",
            "Class OcuPilot.Kernel.Probe Extends %RegisteredObject\n"
            "{\n\nClassMethod Run() As %String\n{\n"
            '    Quit "a " _ $Char(8212) _ " b"\n'
            "}\n\n}\n",
        )
        problems: list[str] = []
        co.check_non_ascii_literals(problems)
        self.assertEqual(problems, [], "the escape is the authored form")

    def test_a_non_ascii_character_in_a_comment_is_exempt(self):
        for line in (
            f"/// <p>a {self.EM_DASH} b</p>",
            f"    ; a {self.EM_DASH} b",
        ):
            with self.subTest(line=line):
                self.write(
                    "src/OcuPilot/Kernel/Probe.cls",
                    f"{line}\nClass OcuPilot.Kernel.Probe Extends %RegisteredObject\n{{\n\n}}\n",
                )
                problems: list[str] = []
                co.check_non_ascii_literals(problems)
                self.assertEqual(problems, [], "Rule 14 exempts comments")

    def test_a_non_ascii_character_outside_a_string_literal_is_out_of_scope(self):
        # The rule's subject is string literals: what is shipped and what is pinned. A stray byte
        # elsewhere in a line is a compile problem, not a string-fidelity one, and this
        # line-oriented reader does not claim it.
        self.write(
            "src/OcuPilot/Kernel/Probe.cls",
            "Class OcuPilot.Kernel.Probe Extends %RegisteredObject\n"
            "{\n\nClassMethod Run() As %String\n{\n"
            f"    Set tX = 1 {self.EM_DASH}\n"
            "}\n\n}\n",
        )
        problems: list[str] = []
        co.check_non_ascii_literals(problems)
        self.assertEqual(problems, [])


class TestAdminApiContainment(FixtureTreeCase):
    """AD-27's containment rule: `%Api.Admin` is named in code by `Port/AdminPort.cls` alone,
    whether in a class body, an XData body, or ObjectScript embedded in a CI shell script."""

    PORT = "src/OcuPilot/Port/AdminPort.cls"

    def containment_problems(self, via_checks: bool = False) -> list[str]:
        problems: list[str] = []
        if via_checks:
            for check in co.CHECKS:
                check(problems)
        else:
            co.check_admin_api_containment(problems)
        return [p for p in problems if "'%Api.Admin'" in p]

    def test_a_planted_reference_in_a_test_class_is_refused_through_the_checker_run(self):
        self.write(
            "src/OcuPilot/Test/Planted.cls",
            "Class OcuPilot.Test.Planted Extends %RegisteredObject\n"
            "{\n\nClassMethod Run() As %String\n{\n"
            '    Quit ##class(%Api.Admin.Endpoints.WebApp.App).%New(1, 2)\n'
            "}\n\n}\n",
        )
        problems = self.containment_problems(via_checks=True)
        self.assertTrue(
            any(p.startswith("src/OcuPilot/Test/Planted.cls:6:") for p in problems),
            f"expected the planted class refused at its line, got {problems}",
        )

    def test_a_planted_reference_in_an_xdata_body_is_refused(self):
        self.write(
            "src/OcuPilot/Test/PlantedMap.cls",
            "Class OcuPilot.Test.PlantedMap Extends %CSP.REST\n"
            "{\n\nXData UrlMap\n{\n<Routes>\n"
            '<Map Prefix="/v2" Forward="%Api.Admin.Dispatch.v2"/>\n'
            "</Routes>\n}\n\n}\n",
        )
        problems = self.containment_problems()
        self.assertTrue(
            any(p.startswith("src/OcuPilot/Test/PlantedMap.cls:7:") for p in problems),
            f"expected the XData forward refused, got {problems}",
        )

    def test_a_planted_reference_on_a_shell_code_line_is_refused(self):
        self.write(
            "scripts/x.sh",
            "#!/bin/sh\n"
            "docker exec -i probe iris session iris <<'EOF'\n"
            'Set tApp = ##class(%Dictionary.CompiledClass).%ExistsId("%Api.Admin")\n'
            "EOF\n",
        )
        problems = self.containment_problems()
        self.assertTrue(
            any(p.startswith("scripts/x.sh:3:") for p in problems),
            f"expected the shell script's code line refused, got {problems}",
        )

    def test_a_doc_comment_a_shell_comment_and_the_port_itself_pass(self):
        self.write(
            "src/OcuPilot/Test/Prose.cls",
            "/// <p>Explains why only the port names %Api.Admin.</p>\n"
            "Class OcuPilot.Test.Prose Extends %RegisteredObject\n{\n\n}\n",
        )
        self.write(
            "scripts/x.sh",
            "#!/bin/sh\n"
            "# The probe reads %Api.Admin's UrlMap through the port.\n"
            "echo done\n",
        )
        self.write(
            self.PORT,
            "Class OcuPilot.Port.AdminPort Extends %RegisteredObject\n"
            '{\n\nParameter ADMINAPICLASS = "%Api.Admin";\n\n}\n',
        )
        self.assertEqual(self.containment_problems(), [])


class TestRestraintContainment(FixtureTreeCase):
    """AD-30's one enforcement point: a restraint code is produced by
    `Kernel/Restraint.cls` alone, declared by `Api/Error.cls`, and asserted by a test class."""

    def containment_problems(self, via_checks: bool = False) -> list[str]:
        problems: list[str] = []
        if via_checks:
            for check in co.CHECKS:
                check(problems)
        else:
            co.check_restraint_containment(problems)
        return [p for p in problems if "a restraint code is produced outside" in p]

    def test_a_second_producer_in_a_slice_is_refused_through_the_checker_run(self):
        self.write(
            "src/OcuPilot/Screen/Tool/Write.cls",
            "Class OcuPilot.Screen.Tool.Write Extends %RegisteredObject\n"
            "{\n\nClassMethod Run() As %String\n{\n"
            '    If ..ReadOnly() Quit "AGENT.READONLY.ENFORCED"\n'
            "    Quit \"\"\n}\n\n}\n",
        )
        problems = self.containment_problems(via_checks=True)
        self.assertTrue(
            any(p.startswith("src/OcuPilot/Screen/Tool/Write.cls:6:") for p in problems),
            f"expected the second producer refused at its line, got {problems}",
        )

    def test_a_parameter_reference_from_a_handler_is_refused(self):
        self.write(
            "src/OcuPilot/Api/Turn.cls",
            "Class OcuPilot.Api.Turn Extends %RegisteredObject\n"
            "{\n\nClassMethod Run() As %String\n{\n"
            "    Quit ##class(OcuPilot.Api.Error).#AGENTKILLSWITCHGLOBAL\n"
            "}\n\n}\n",
        )
        problems = self.containment_problems()
        self.assertTrue(
            any(p.startswith("src/OcuPilot/Api/Turn.cls:6:") for p in problems),
            f"expected the parameter reference refused, got {problems}",
        )

    def test_the_two_allowed_files_a_test_class_and_a_doc_comment_pass(self):
        self.write(
            "src/OcuPilot/Kernel/Restraint.cls",
            "Class OcuPilot.Kernel.Restraint Extends %RegisteredObject\n"
            "{\n\nClassMethod Verdict() As %String\n{\n"
            "    Quit ##class(OcuPilot.Api.Error).#AGENTREADONLYENFORCED\n"
            "}\n\n}\n",
        )
        self.write(
            "src/OcuPilot/Api/Error.cls",
            "Class OcuPilot.Api.Error Extends %RegisteredObject\n"
            '{\n\nParameter AGENTREADONLYENFORCED = "AGENT.READONLY.ENFORCED";\n\n}\n',
        )
        self.write(
            "src/OcuPilot/Test/Restraint.cls",
            "Class OcuPilot.Test.Restraint Extends %UnitTest.TestCase\n"
            "{\n\nMethod TestIt()\n{\n"
            '    Do $$$AssertEquals(tCode, "AGENT.KILLSWITCH.USER", "the per-user code")\n'
            "}\n\n}\n",
        )
        self.write(
            "src/OcuPilot/Screen/Tool/Base.cls",
            "/// <p>A write tool asks OcuPilot.Kernel.Restraint rather than deriving\n"
            "/// AGENT.READONLY.ENFORCED itself.</p>\n"
            "Class OcuPilot.Screen.Tool.Base Extends %RegisteredObject\n{\n\n}\n",
        )
        self.assertEqual(self.containment_problems(), [])


class TestRestraintContainmentReach(FixtureTreeCase):
    """DW-393 and DW-394: a code's tail and a parameter named without `#` are both a code, and the
    client's TypeScript and templates are read as well as ObjectScript."""

    def containment_problems(self) -> list[str]:
        problems: list[str] = []
        co.check_restraint_containment(problems)
        return [p for p in problems if "a restraint code is produced outside" in p]

    def test_a_code_assembled_across_a_concatenation_is_refused(self):
        self.write(
            "src/OcuPilot/Kernel/Agent/Probe.cls",
            "Class OcuPilot.Kernel.Agent.Probe Extends %RegisteredObject\n"
            "{\n\nClassMethod Run() As %String\n{\n"
            '    Set tPrefix = "AGENT"\n'
            '    Quit tPrefix _ ".KILLSWITCH.GLOBAL"\n'
            "}\n\n}\n",
        )
        problems = self.containment_problems()
        self.assertTrue(
            any(p.startswith("src/OcuPilot/Kernel/Agent/Probe.cls:7:") for p in problems),
            f"expected the assembled code refused at its tail, got {problems}",
        )

    def test_a_parameter_named_without_its_hash_is_refused(self):
        self.write(
            "src/OcuPilot/Kernel/Agent/Probe.cls",
            "Class OcuPilot.Kernel.Agent.Probe Extends %RegisteredObject\n"
            "{\n\nClassMethod Run() As %String\n{\n"
            '    Quit $Parameter("OcuPilot.Api.Error", "AGENTREADONLYENFORCED")\n'
            "}\n\n}\n",
        )
        problems = self.containment_problems()
        self.assertTrue(
            any(p.startswith("src/OcuPilot/Kernel/Agent/Probe.cls:6:") for p in problems),
            f"expected the bare parameter name refused, got {problems}",
        )

    def test_a_client_naming_a_code_is_refused_and_a_spec_is_not(self):
        self.write("ui/src/app/shell/panel/refusal.ts", "export const BLOCKED = 'AGENT.READONLY.ENFORCED';\n")
        self.write("ui/src/app/shell/panel/refusal.html", "<p *ngIf=\"code === 'KILLSWITCH.USER'\">off</p>\n")
        self.write("ui/src/app/shell/panel/refusal.spec.ts", "expect(code).toBe('AGENT.KILLSWITCH.GLOBAL');\n")
        self.write("ui/tools/refusal.mjs", "const code = 'AGENT.KILLSWITCH.GLOBAL';\n")
        problems = self.containment_problems()
        self.assertTrue(any(p.startswith("ui/src/app/shell/panel/refusal.ts:1:") for p in problems), f"got {problems}")
        self.assertTrue(any(p.startswith("ui/src/app/shell/panel/refusal.html:1:") for p in problems), f"got {problems}")
        self.assertFalse(any("refusal.spec.ts" in p for p in problems), f"a spec asserts codes, got {problems}")
        self.assertFalse(any("ui/tools/" in p for p in problems), f"outside ui/src, got {problems}")

    def test_a_testing_helper_names_a_code_and_passes(self):
        self.write("ui/src/app/testing/agent-status.ts", "export const KILLED = { code: 'AGENT.KILLSWITCH.GLOBAL' };\n")
        self.assertEqual(self.containment_problems(), [], "a spec builder under ui/src/app/testing/ is test code")

    def test_a_family_named_without_its_trailing_dot_is_refused(self):
        self.write("ui/src/app/shell/panel/refusal.ts", "export const off = (code: string) => code.startsWith('AGENT.KILLSWITCH');\n")
        self.write(
            "src/OcuPilot/Kernel/Agent/Probe.cls",
            "Class OcuPilot.Kernel.Agent.Probe Extends %RegisteredObject\n"
            "{\n\nClassMethod Run(pCode As %String) As %Boolean\n{\n"
            '    Quit $Piece(pCode, ".", 1, 2) = "AGENT.READONLY"\n'
            "}\n\n}\n",
        )
        problems = self.containment_problems()
        self.assertTrue(any(p.startswith("ui/src/app/shell/panel/refusal.ts:1:") for p in problems), f"got {problems}")
        self.assertTrue(any(p.startswith("src/OcuPilot/Kernel/Agent/Probe.cls:6:") for p in problems), f"got {problems}")

    def test_every_declared_restraint_code_is_seen_by_its_tail(self):
        # The tail alternatives are written out by hand; this holds them to the codes Api/Error.cls
        # declares, so a new restraint code cannot slip past the tail match.
        text = (SCRIPT_PATH.parent.parent / "src/OcuPilot/Api/Error.cls").read_text(encoding="utf-8")
        codes = re.findall(r'^Parameter AGENT(?:READONLY|KILLSWITCH)\w* = "AGENT\.((?:READONLY|KILLSWITCH)\.\w+)";', text, re.M)
        self.assertGreaterEqual(len(codes), 4, f"expected the declared restraint codes, got {codes}")
        for tail in codes:
            with self.subTest(tail=tail):
                self.assertIsNotNone(co.RESTRAINT_CODE_RE.search(f'Quit tPrefix _ ".{tail}"'), f"the tail {tail} is not matched on its own")

    def test_an_unrelated_readonly_word_passes(self):
        self.write(
            "src/OcuPilot/Kernel/Agent/Probe.cls",
            "Class OcuPilot.Kernel.Agent.Probe Extends %RegisteredObject\n"
            "{\n\nClassMethod Run() As %String\n{\n"
            "    Quit ##class(OcuPilot.Api.Error).#TURNABANDONEDREADONLY _ ..#DEFAULTKILLSWITCH\n"
            "}\n\n}\n",
        )
        self.write("ui/src/app/core/strings.ts", "export const statusReadOnlyEnforced = 'Read-only';\n")
        self.assertEqual(self.containment_problems(), [])


class TestToolDispatchRule(FixtureTreeCase):
    """Story 4.2: one caller of `InvokeTool`, no HTTP on the dispatch path, no handler named by a
    shell read or a tool, and no output capture outside the admin port."""

    def cls(self, rel: str, name: str, line: str) -> None:
        self.write(rel, f"Class {name} Extends %RegisteredObject\n{{\n\nClassMethod Go()\n{{\n    {line}\n}}\n\n}}\n")

    def problems(self) -> list[str]:
        problems: list[str] = []
        co.check_tool_dispatch(problems)
        return problems

    def test_invoke_tool_outside_the_registry_and_the_dispatcher_is_refused(self):
        call = "Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {}, 200, .r, .h, .f)"
        self.cls("src/OcuPilot/Kernel/Agent/Loop.cls", "OcuPilot.Kernel.Agent.Loop", call)
        self.cls("src/OcuPilot/Kernel/Agent/Dispatch.cls", "OcuPilot.Kernel.Agent.Dispatch", call)
        self.cls("src/OcuPilot/Screen/Tool/Registry.cls", "OcuPilot.Screen.Tool.Registry", "Quit ..InvokeTool(tTool)")
        self.cls("src/OcuPilot/Test/ToolDispatch.cls", "OcuPilot.Test.ToolDispatch", call)
        problems = self.problems()
        self.assertTrue(any(p.startswith("src/OcuPilot/Kernel/Agent/Loop.cls:6:") and "InvokeTool" in p for p in problems), f"got {problems}")
        self.assertEqual([p for p in problems if not p.startswith("src/OcuPilot/Kernel/Agent/Loop.cls:")], [], f"got {problems}")

    def test_an_http_request_or_api_path_on_the_dispatch_path_is_refused(self):
        self.cls("src/OcuPilot/Screen/Tool/Read.cls", "OcuPilot.Screen.Tool.Read", "Set tRequest = ##class(%Net.HttpRequest).%New()")
        self.cls("src/OcuPilot/Kernel/Shell/InstanceRead.cls", "OcuPilot.Kernel.Shell.InstanceRead", 'Set tPath = "/api/ocupilot/instance"')
        self.cls("src/OcuPilot/Kernel/Governance/Gate.cls", "OcuPilot.Kernel.Governance.Gate", 'Set tPath = "/api/ocupilot/turn"')
        self.cls("src/OcuPilot/Kernel/Agent/Dispatch.cls", "OcuPilot.Kernel.Agent.Dispatch", 'Set tPath = "/API/admin"')
        self.cls("src/OcuPilot/Api/Turn.cls", "OcuPilot.Api.Turn", 'Set tPath = "/api/ocupilot/turn"')
        problems = self.problems()
        for rel in ("Screen/Tool/Read.cls", "Kernel/Shell/InstanceRead.cls", "Kernel/Governance/Gate.cls", "Kernel/Agent/Dispatch.cls"):
            with self.subTest(rel=rel):
                self.assertTrue(any(p.startswith("src/OcuPilot/" + rel + ":6:") and "HTTP" in p for p in problems), f"got {problems}")
        self.assertFalse(any(p.startswith("src/OcuPilot/Api/Turn.cls") for p in problems), f"a handler is outside the rule, got {problems}")

    def test_a_shell_read_naming_a_handler_is_refused(self):
        self.cls("src/OcuPilot/Kernel/Shell/InstanceRead.cls", "OcuPilot.Kernel.Shell.InstanceRead", "Quit ##class(OcuPilot.Api.Instance).Payload(.pObject)")
        self.cls("src/OcuPilot/Kernel/Shell/Instance.cls", "OcuPilot.Kernel.Shell.Instance", 'Do ##class(OcuPilot.Api.Error).LogError("adminport", "detail", {})')
        self.write(
            "src/OcuPilot/Kernel/Shell/Navigation.cls",
            "/// <p><class>OcuPilot.Api.Navigation</class> answers this map.</p>\n"
            "Class OcuPilot.Kernel.Shell.Navigation Extends %RegisteredObject\n{\n\n}\n",
        )
        self.cls("src/OcuPilot/Kernel/Shell/NamespacesRead.cls", "OcuPilot.Kernel.Shell.NamespacesRead", 'Do ##class(OcuPilot.Api.ErrorLog).Write("detail")')
        self.cls("src/OcuPilot/Screen/Tool/ErrorRead.cls", "OcuPilot.Screen.Tool.ErrorRead", "Quit ##class(OcuPilot.Api.Namespaces).Payload(.pObject)")
        self.cls("src/OcuPilot/Api/Instance.cls", "OcuPilot.Api.Instance", "Quit ##class(OcuPilot.Api.Response).Success({})")
        problems = self.problems()
        refused = ("Kernel/Shell/InstanceRead.cls", "Kernel/Shell/NamespacesRead.cls", "Screen/Tool/ErrorRead.cls")
        for rel, name in zip(refused, ("OcuPilot.Api.Instance", "OcuPilot.Api.ErrorLog", "OcuPilot.Api.Namespaces")):
            with self.subTest(rel=rel):
                self.assertTrue(any(p.startswith("src/OcuPilot/" + rel + ":6:") and name in p for p in problems), f"got {problems}")
        self.assertEqual([p for p in problems if not p.startswith(tuple("src/OcuPilot/" + r + ":" for r in refused))], [], f"the vocabulary class, a doc comment and a handler pass, got {problems}")

    def test_a_capture_outside_the_admin_port_is_refused(self):
        self.cls("src/OcuPilot/Kernel/Agent/Dispatch.cls", "OcuPilot.Kernel.Agent.Dispatch", "Set tSC = $$BeginCapture^%SYS.Capture(.tCookie)")
        self.cls("src/OcuPilot/Port/AdminPort.cls", "OcuPilot.Port.AdminPort", 'Set tSC = $ClassMethod(..#CAPTURECLASS, "BeginCaptureOutput", .tCookie)')
        self.cls("src/OcuPilot/Test/AdminPortFault.cls", "OcuPilot.Test.AdminPortFault", "Set tSC = $$BeginCapture^%SYS.Capture(.tCookie)")
        problems = self.problems()
        self.assertTrue(any(p.startswith("src/OcuPilot/Kernel/Agent/Dispatch.cls:6:") and "capture" in p for p in problems), f"got {problems}")
        self.assertEqual([p for p in problems if not p.startswith("src/OcuPilot/Kernel/Agent/Dispatch.cls:")], [], f"got {problems}")

    def test_a_doc_comment_naming_them_passes(self):
        self.write(
            "src/OcuPilot/Kernel/Agent/Loop.cls",
            "/// <p>Tools are reached through InvokeTool, never /api/, never %Net.HttpRequest or %SYS.Capture.</p>\n"
            "Class OcuPilot.Kernel.Agent.Loop Extends %RegisteredObject\n{\n\n}\n",
        )
        self.assertEqual(self.problems(), [])


class TestStateSqlLiteralRule(FixtureTreeCase):
    """Story 4.2 (AD-21): a kernel store's SQL is a literal at every guarded-helper call site."""

    def store(self, rel: str, name: str, line: str) -> None:
        self.write(rel, f"Class {name} Extends OcuPilot.Kernel.State.Base\n{{\n\nClassMethod Go()\n{{\n    {line}\n}}\n\n}}\n")

    def problems(self) -> list[str]:
        problems: list[str] = []
        co.check_state_sql_literal(problems)
        return problems

    def test_a_variable_sql_argument_is_refused(self):
        for helper in ("GuardedIdsWhere", "GuardedOpenOneWhereTwoParam", "GuardedExecuteOneParam", "GuardedIdsWhereNoParam"):
            with self.subTest(helper=helper):
                self.store("src/OcuPilot/Kernel/State/Probe.cls", "OcuPilot.Kernel.State.Probe", f"Set tSC = ..{helper}(tSql, pName, .tIds)")
                problems = self.problems()
                self.assertTrue(any(p.startswith("src/OcuPilot/Kernel/State/Probe.cls:6:") and helper in p for p in problems), f"got {problems}")

    def test_a_call_through_a_store_variable_is_refused(self):
        self.store("src/OcuPilot/Kernel/State/Probe.cls", "OcuPilot.Kernel.State.Probe", "Set tSC = tStore.GuardedIdsWhere(tSql, pName, .tIds)")
        self.assertTrue(any("Probe.cls:6:" in p for p in self.problems()), "a call through a store variable is read as well")

    def test_a_concatenated_sql_argument_is_refused(self):
        self.store("src/OcuPilot/Kernel/State/Probe.cls", "OcuPilot.Kernel.State.Probe", 'Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedIdsWhere(tFragment _ " ORDER BY ID", pName, .tIds)')
        self.assertTrue(any("Probe.cls:6:" in p for p in self.problems()), "a call through ##class is read as well")

    def test_a_literal_joined_to_a_caller_value_is_refused(self):
        for line in (
            'Set tSC = ..GuardedIdsWhere("SELECT ID FROM T WHERE " _ tWhere, pName, .tIds)',
            'Quit ..GuardedExecuteOneParam("DELETE FROM T WHERE Name = \'" _ pName _ "\'")',
        ):
            with self.subTest(line=line):
                self.store("src/OcuPilot/Kernel/State/Probe.cls", "OcuPilot.Kernel.State.Probe", line)
                self.assertTrue(any("Probe.cls:6:" in p for p in self.problems()), f"expected {line!r} refused")

    def test_a_literal_the_base_class_and_a_declaration_pass(self):
        self.store("src/OcuPilot/Kernel/State/Probe.cls", "OcuPilot.Kernel.State.Probe", 'Set tSC = ..GuardedIdsWhere("SELECT TOP ? ID FROM OcuPilot_Kernel_State.T WHERE Flag = \'1\' AND Note = ""a_b"" ORDER BY ID", +pMaxRows, .tIds) Quit ..GuardedExecuteNoParam("DELETE FROM T")')
        self.write(
            "src/OcuPilot/Kernel/State/Base.cls",
            "Class OcuPilot.Kernel.State.Base Extends %Persistent\n{\n\n"
            "ClassMethod GuardedIdsWhere(pSql As %String, pParam As %String, Output pIds) As %Status\n{\n"
            "    Set tRS = ..Run(pSql)\n    Quit ..GuardedExecuteNoParam(pSql)\n}\n\n}\n",
        )
        self.write("src/OcuPilot/Api/Probe.cls", "Class OcuPilot.Api.Probe Extends %RegisteredObject\n{\n\nClassMethod Go()\n{\n    Do ..GuardedIdsWhere(tSql)\n}\n\n}\n")
        self.assertEqual(self.problems(), [])


class TestToolKindRule(FixtureTreeCase):
    """AD-22: a concrete tool class whose nearest `KIND` is neither `read` nor `write` fails the
    build, and an inherited kind counts."""

    BASE = (
        "Class OcuPilot.Screen.Tool.Base Extends %RegisteredObject [ Abstract ]\n"
        '{\n\nParameter KIND = "";\n\n}\n'
    )

    def write_base(self) -> None:
        self.write("src/OcuPilot/Screen/Tool/Base.cls", self.BASE)

    def kind_problems(self) -> list[str]:
        problems: list[str] = []
        co.check_tool_kind(problems)
        return problems

    def test_a_concrete_tool_declaring_no_kind_is_refused_naming_the_class(self):
        self.write_base()
        self.write(
            "src/OcuPilot/Test/KindLess.cls",
            "Class OcuPilot.Test.KindLess Extends OcuPilot.Screen.Tool.Base\n"
            '{\n\nParameter TOOLNAME = "test.kindless.read";\n\n}\n',
        )
        problems = self.kind_problems()
        self.assertTrue(
            any(p.startswith("src/OcuPilot/Test/KindLess.cls:1:") and "OcuPilot.Test.KindLess" in p for p in problems),
            f"expected the kind-less tool refused at its class line, got {problems}",
        )

    def test_a_kind_outside_read_and_write_is_refused(self):
        self.write_base()
        self.write(
            "src/OcuPilot/Test/Reads.cls",
            "Class OcuPilot.Test.Reads Extends OcuPilot.Screen.Tool.Base\n"
            '{\n\nParameter KIND = "reads";\n\n}\n',
        )
        self.assertTrue(any("'reads'" in p for p in self.kind_problems()))

    def test_an_inherited_kind_passes(self):
        self.write_base()
        self.write(
            "src/OcuPilot/Test/Middle.cls",
            "Class OcuPilot.Test.Middle Extends OcuPilot.Screen.Tool.Base [ Abstract ]\n"
            '{\n\nParameter KIND = "write";\n\n}\n',
        )
        self.write(
            "src/OcuPilot/Test/Leaf.cls",
            "Class OcuPilot.Test.Leaf Extends OcuPilot.Test.Middle\n"
            '{\n\nParameter TOOLNAME = "test.leaf.write";\n\n}\n',
        )
        self.assertEqual(self.kind_problems(), [])

    def test_a_kind_declared_with_a_type_and_keywords_is_read(self):
        self.write_base()
        self.write(
            "src/OcuPilot/Test/Keyworded.cls",
            "Class OcuPilot.Test.Keyworded Extends OcuPilot.Screen.Tool.Base\n"
            '{\n\nParameter KIND As %String [ Final ] = "read";\n\n}\n',
        )
        self.assertEqual(self.kind_problems(), [])

    def test_a_class_declared_not_abstract_is_concrete(self):
        self.write_base()
        self.write(
            "src/OcuPilot/Test/NotAbstract.cls",
            "Class OcuPilot.Test.NotAbstract Extends OcuPilot.Screen.Tool.Base [ Not Abstract ]\n{\n\n}\n",
        )
        self.assertTrue(
            any("OcuPilot.Test.NotAbstract" in p for p in self.kind_problems()),
            "a kind-less class declared Not Abstract is refused as a concrete tool",
        )

    def test_an_abstract_tool_and_a_class_outside_the_tool_tree_pass(self):
        self.write_base()
        self.write(
            "src/OcuPilot/Test/AbstractTool.cls",
            "Class OcuPilot.Test.AbstractTool Extends OcuPilot.Screen.Tool.Base [ Abstract ]\n{\n\n}\n",
        )
        self.write(
            "src/OcuPilot/Kernel/Other.cls",
            "Class OcuPilot.Kernel.Other Extends %RegisteredObject\n{\n\n}\n",
        )
        self.assertEqual(self.kind_problems(), [])


class TestRouteOrderingRule(FixtureTreeCase):
    """Conventions, REST route ordering: each invariant, planted, is named; the shipped
    orderings pass."""

    def write_map(self, routes: list[str]) -> None:
        self.write(
            "src/OcuPilot/Api/Planted.cls",
            "Class OcuPilot.Api.Planted Extends %CSP.REST\n"
            "{\n\nXData UrlMap\n{\n<Routes>\n"
            + "".join(f"  {route}\n" for route in routes)
            + "</Routes>\n}\n\n}\n",
        )

    def ordering_problems(self) -> list[str]:
        problems: list[str] = []
        co.check_route_ordering(problems)
        return problems

    def test_a_catch_all_before_its_guard_is_refused(self):
        self.write_map([
            '<Route Url="/:resource" Method="POST" Call="Create"/>',
            '<Route Url="/guarded" Method="POST" Call="Guard"/>',
        ])
        problems = self.ordering_problems()
        self.assertTrue(
            any("/guarded" in p and "/:resource" in p and "unreachable" in p for p in problems),
            f"expected the guard named unreachable, got {problems}",
        )

    def test_a_param_before_its_literal_sibling_is_refused(self):
        self.write_map([
            '<Route Url="/items/:id" Method="GET" Call="Item"/>',
            '<Route Url="/items/current" Method="GET" Call="Current"/>',
        ])
        problems = self.ordering_problems()
        self.assertTrue(
            any(p.startswith("src/OcuPilot/Api/Planted.cls:8:") and "/items/current" in p for p in problems),
            f"expected the literal sibling named at its line, got {problems}",
        )

    def test_a_route_with_no_method_collides_with_every_method(self):
        self.write_map([
            '<Route Url="/items/:id" Call="Item"/>',
            '<Route Url="/items/current" Method="DELETE" Call="Current"/>',
        ])
        self.assertTrue(any("unreachable" in p for p in self.ordering_problems()))

    def test_a_verb_shared_by_a_comma_separated_method_collides(self):
        self.write_map([
            '<Route Url="/items/:id" Method="GET,POST" Call="Item"/>',
            '<Route Url="/items/current" Method="PUT, post" Call="Current"/>',
        ])
        self.assertTrue(any("/items/current" in p and "unreachable" in p for p in self.ordering_problems()))

    def test_disjoint_comma_separated_methods_pass(self):
        self.write_map([
            '<Route Url="/items/:id" Method="GET,POST" Call="Item"/>',
            '<Route Url="/items/current" Method="PUT,DELETE" Call="Current"/>',
        ])
        self.assertEqual(self.ordering_problems(), [])

    def test_a_route_spanning_lines_is_read_at_its_opening_line(self):
        self.write_map([
            '<Route Url="/items/:id" Method="GET" Call="Item"/>',
            '<Route\n    Url="/items/current"\n    Method="GET" Call="Current"/>',
        ])
        problems = self.ordering_problems()
        self.assertTrue(
            any(p.startswith("src/OcuPilot/Api/Planted.cls:8:") and "/items/current" in p for p in problems),
            f"expected the multi-line route named at its opening line, got {problems}",
        )

    def test_single_quoted_attributes_are_read(self):
        self.write_map([
            "<Route Url='/items/:id' Method='GET' Call='Item'/>",
            "<Route Url='/items/current' Method='GET' Call='Current'/>",
        ])
        self.assertTrue(any("/items/current" in p and "unreachable" in p for p in self.ordering_problems()))

    def test_different_methods_on_one_url_pass(self):
        self.write_map([
            '<Route Url="/:resource" Method="GET" Call="Read"/>',
            '<Route Url="/guarded" Method="POST" Call="Guard"/>',
            '<Route Url="/(.*)" Method="HEAD" Call="Serve"/>',
        ])
        self.assertEqual(self.ordering_problems(), [])

    def test_a_shorter_route_before_a_longer_one_it_prefixes_is_refused_whatever_the_method(self):
        self.write_map([
            '<Route Url="/docs/:id" Method="GET" Call="Doc"/>',
            '<Route Url="/docs/:id/history" Method="POST" Call="History"/>',
        ])
        problems = self.ordering_problems()
        self.assertTrue(
            any("/docs/:id/history" in p and "shorter route" in p for p in problems),
            f"expected the N-segment route named, got {problems}",
        )

    def test_the_longer_route_first_passes(self):
        self.write_map([
            '<Route Url="/screens/:screen/read" Method="GET" Call="Read"/>',
            '<Route Url="/items/current" Method="GET" Call="Current"/>',
            '<Route Url="/items/:id" Method="GET" Call="Item"/>',
            '<Route Url="/docs/:id/history" Method="GET" Call="History"/>',
            '<Route Url="/docs/:id" Method="GET" Call="Doc"/>',
            '<Route Url="/instance" Method="GET" Call="Instance"/>',
        ])
        self.assertEqual(self.ordering_problems(), [])


class TestShippedTreeRouteOrderingAndToolKinds(unittest.TestCase):
    """Both Story 2.3 rules over the real tree, whose UrlMaps include RouterFixture's collision
    pairs and whose tool fixtures include an inherited kind."""

    def test_the_shipped_tree_passes_both_rules(self):
        for check in (co.check_route_ordering, co.check_tool_kind):
            with self.subTest(check=check.__name__):
                problems: list[str] = []
                check(problems)
                self.assertEqual(problems, [], f"{check.__name__} over the shipped tree")

    def test_the_inherited_kind_fixture_is_reached_as_a_write_tool(self):
        classes = co.read_tool_classes()
        leaf = "OcuPilot.Test.Read.Tool.Leaf"
        self.assertIn(leaf, classes)
        self.assertFalse(classes[leaf]["abstract"], "Leaf is concrete")
        self.assertTrue(co.reaches_tool_base(leaf, classes), "Leaf reaches the tool base")
        self.assertEqual(co.nearest_kind(leaf, classes), "write", "with the kind Middle declares")

    def test_the_router_fixture_is_actually_read(self):
        text = co.read_text(co.ROOT / "src" / "OcuPilot" / "Test" / "RouterFixture.cls")
        self.assertIsNotNone(text)
        bodies = list(co.iter_named_xdata_blocks(text, co.URLMAP_XDATA_NAME))
        self.assertEqual(len(bodies), 1)
        self.assertGreater(len(co.ROUTE_ELEMENT_RE.findall(bodies[0][1])), 10)


class TestShippedTreeAdminApiContainment(unittest.TestCase):
    """The containment rule over the real tree: clean, over a population that includes both the
    ObjectScript sources and the CI shell scripts."""

    def test_the_shipped_tree_names_the_vendor_api_only_in_the_port(self):
        self.assertGreater(sum(1 for _ in co.iter_objectscript_files()), 100)
        self.assertGreater(sum(1 for _ in co.iter_shell_scripts()), 0)
        problems: list[str] = []
        co.check_admin_api_containment(problems)
        self.assertEqual(problems, [], "check_admin_api_containment over the shipped tree")


class TestShippedTreeIsCleanUnderTheNewRules(unittest.TestCase):
    """The production reading of all four rules, over the real tree rather than a fixture -- so
    each guard is exercised where it actually runs, not only where it is injected."""

    def test_the_production_scan_covers_a_real_population(self):
        """A clean run over nothing is not a clean run.

        Every other case here is a `FixtureTreeCase`, whose setUp replaces `SCAN_ROOTS` with a
        temp tree -- so none of them exercises the real roots. Drop `src/OcuPilot` from
        `SCAN_ROOTS`, or prune it, and every rule reports `[]` over zero files while the checker
        exits 0 in CI printing "scanned 0 file(s)". This is the assertion the sibling gate
        already makes (`ui/tools/client-lint.test.mjs`: `result.scanned > 0`).
        """
        scanned = sum(1 for _ in co.iter_objectscript_files())
        self.assertGreater(
            scanned,
            100,
            "the production scan must cover the shipped tree, not an empty set of roots",
        )

    def test_the_shipped_tree_passes_every_rule_this_story_added(self):
        for check in (
            co.check_test_class_properties,
            co.check_destructive_test_guard,
            co.check_embedded_python,
            co.check_handler_wire_tests,
            co.check_non_ascii_literals,
            co.check_tool_kind,
            co.check_route_ordering,
            co.check_agent_job_reach,
            co.check_restraint_containment,
            co.check_tool_dispatch,
            co.check_state_sql_literal,
        ):
            with self.subTest(check=check.__name__):
                problems: list[str] = []
                check(problems)
                self.assertEqual(problems, [], f"{check.__name__} over the shipped tree")


class TestDestructiveTestGuardRule(FixtureTreeCase):
    """DW-289: a `%UnitTest.TestCase` under `Test/` that creates an IRIS principal or moves the
    console log must refuse in `OnBeforeAllTests` unless an arming environment variable says so.

    Six classes were held off a live instance by nothing but a doc comment; `ci-runner.mjs
    --container <name>` takes any container's name, and `%UnitTest.Manager` raises this status
    before it enumerates a single `Test*` method.
    """

    GUARDED_BODY = (
        "Method OnBeforeAllTests() As %Status\n"
        "{\n"
        "    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {\n"
        '        Quit $$$ERROR($$$GeneralError, "armed only on a throwaway")\n'
        "    }\n"
        "    Quit $$$OK\n"
        "}\n"
    )

    def write_test_class(self, name: str, body: str, before_all: str = "") -> None:
        self.write(
            f"src/OcuPilot/Test/{name}.cls",
            f"Class OcuPilot.Test.{name} Extends %UnitTest.TestCase\n"
            "{\n\n"
            'Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";\n\n'
            f"{before_all}\n"
            "Method TestSomething()\n"
            "{\n"
            f"{body}\n"
            "}\n\n"
            "}\n",
        )

    def test_an_unguarded_class_creating_a_user_is_refused_naming_the_call(self):
        self.write_test_class("Unguarded", '    Set tSC = ##class(Security.Users).Create("Probe")')
        problems: list[str] = []
        co.check_destructive_test_guard(problems)
        self.assertTrue(
            any("Unguarded.cls" in p and "Security.Users" in p for p in problems),
            f"expected the unguarded class refused by name, got {problems}",
        )

    def test_the_same_class_with_the_guard_passes(self):
        self.write_test_class(
            "Guarded",
            '    Set tSC = ##class(Security.Users).Create("Probe")',
            self.GUARDED_BODY,
        )
        problems: list[str] = []
        co.check_destructive_test_guard(problems)
        self.assertEqual(problems, [])

    def test_a_guard_that_does_not_refuse_does_not_count(self):
        """The rule reads the barrier, not the mention of it. Each body below names the arming
        variable inside `OnBeforeAllTests` and still runs the class on a live instance: the
        comparison inverted, the branch empty, the branch returning `$$$OK`, and the guard quoted
        in a `;` comment. A rule that searched for the call alone passed all four."""
        bodies = {
            "inverted": (
                "Method OnBeforeAllTests() As %Status\n"
                "{\n"
                "    If $System.Util.GetEnviron(..#ARMINGVARIABLE) = 1 {\n"
                '        Quit $$$ERROR($$$GeneralError, "armed only on a throwaway")\n'
                "    }\n"
                "    Quit $$$OK\n"
                "}\n"
            ),
            "empty branch": (
                "Method OnBeforeAllTests() As %Status\n"
                "{\n"
                "    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 { }\n"
                "    Quit $$$OK\n"
                "}\n"
            ),
            "branch returns OK": (
                "Method OnBeforeAllTests() As %Status\n"
                "{\n"
                "    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 { Quit $$$OK }\n"
                "    Quit $$$OK\n"
                "}\n"
            ),
            "quoted in a comment": (
                "Method OnBeforeAllTests() As %Status\n"
                "{\n"
                "    ; guarded by $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 -- Quit $$$ERROR\n"
                "    Quit $$$OK\n"
                "}\n"
            ),
        }
        for name, before_all in bodies.items():
            with self.subTest(guard=name):
                self.write_test_class(
                    "Sham",
                    '    Set tSC = ##class(Security.Users).Create("Probe")',
                    before_all,
                )
                problems: list[str] = []
                co.check_destructive_test_guard(problems)
                self.assertTrue(
                    any("Sham.cls" in p for p in problems),
                    f"expected the {name} guard to count for nothing, got {problems}",
                )

    def test_a_guard_in_some_other_method_does_not_count(self):
        """The guard has to be in `OnBeforeAllTests`. `%UnitTest.Manager` raises only that
        method's status before enumerating tests; a refusal from `OnBeforeOneTest` runs after the
        roster is built, and one from a helper runs after whatever called it."""
        self.write_test_class(
            "Elsewhere",
            '    Set tSC = ##class(Security.Users).Create("Probe")',
            "Method OnBeforeOneTest() As %Status\n"
            "{\n"
            "    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 { Quit $$$ERROR($$$GeneralError, \"no\") }\n"
            "    Quit $$$OK\n"
            "}\n",
        )
        problems: list[str] = []
        co.check_destructive_test_guard(problems)
        self.assertTrue(
            any("Elsewhere.cls" in p for p in problems),
            f"expected a guard outside OnBeforeAllTests to count for nothing, got {problems}",
        )

    def test_a_role_creation_and_a_console_log_move_are_in_the_population_too(self):
        for name, call in (
            ("RoleMaker", '    Set tSC = ##class(Security.Roles).Create("ProbeRole")'),
            ("LogRotator", "    Do ##class(Config.Startup).MoveConsoleLog(tPath, tMax)"),
        ):
            with self.subTest(name=name):
                self.write_test_class(name, call)
                problems: list[str] = []
                co.check_destructive_test_guard(problems)
                self.assertTrue(
                    any(f"{name}.cls" in p for p in problems),
                    f"expected {name} refused, got {problems}",
                )

    def test_a_principal_created_through_the_suites_own_helper_is_in_the_population(self):
        """`Test/UnexpireScope.cls` names no security class at all -- it creates and deletes its
        throwaway account through `OcuPilot.Test.Version`'s helpers. A rule that read only direct
        calls would let that class's guard be deleted with the checker green."""
        self.write_test_class(
            "ViaHelper",
            '    Do ##class(OcuPilot.Test.Version).CreateThrowawayExpiredAccount("Probe")',
        )
        problems: list[str] = []
        co.check_destructive_test_guard(problems)
        self.assertTrue(
            any("ViaHelper.cls" in p and "OcuPilot.Test.Version" in p for p in problems),
            f"expected the helper call to count, got {problems}",
        )

    def test_the_same_helper_call_with_the_guard_passes(self):
        self.write_test_class(
            "ViaHelperGuarded",
            '    Do ##class(OcuPilot.Test.Version).DeleteThrowawayAccount("Probe")',
            self.GUARDED_BODY,
        )
        problems: list[str] = []
        co.check_destructive_test_guard(problems)
        self.assertEqual(problems, [])

    def test_the_turn_principal_helpers_are_in_the_population(self):
        """`Test/TurnWire.cls` and `Test/TurnLong.cls` create, revoke and delete their principals
        through `OcuPilot.Test.TurnWireFixture`, naming no security class of their own."""
        for helper in ("EnsurePrincipal", "DeletePrincipal", "RemovePrincipals", "SetRoleResources", "RemoveSecondRole"):
            with self.subTest(helper=helper):
                self.write_test_class(
                    "ViaTurnFixture", f'    Do ##class(OcuPilot.Test.TurnWireFixture).{helper}("Probe")'
                )
                problems: list[str] = []
                co.check_destructive_test_guard(problems)
                self.assertTrue(
                    any("ViaTurnFixture.cls" in p and helper in p for p in problems),
                    f"expected {helper} to count, got {problems}",
                )

    def test_deleting_a_role_is_in_the_population(self):
        """Outside the rule until DW-396, on the ground that it is the tail of an install probe.
        The classes that delete a role are the same ones that run the install, so the exemption
        protected nothing."""
        self.write_test_class("RoleRemover", '    Do ##class(Security.Roles).Delete("ProbeRole")')
        problems: list[str] = []
        co.check_destructive_test_guard(problems)
        self.assertTrue(
            any("RoleRemover.cls" in p for p in problems),
            f"expected the role delete refused, got {problems}",
        )

    def test_a_production_install_is_in_the_population_naming_the_call(self):
        """DW-402: `Test/AuditRecord.cls` runs a production install and names no security class at
        all, so a rule reading only `Security.*` could not see the widest effect in the tree."""
        self.write_test_class(
            "Installing", '    Set tSC = ##class(OcuPilot.Install.Installer).Install("")'
        )
        problems: list[str] = []
        co.check_destructive_test_guard(problems)
        self.assertTrue(
            any("Installing.cls" in p and 'Install("")' in p for p in problems),
            f"expected the production install refused by name, got {problems}",
        )

    def test_the_same_production_install_with_the_guard_passes(self):
        self.write_test_class(
            "InstallingGuarded",
            '    Set tSC = ##class(OcuPilot.Install.Installer).Install("")',
            self.GUARDED_BODY,
        )
        problems: list[str] = []
        co.check_destructive_test_guard(problems)
        self.assertEqual(problems, [])

    def test_the_install_reached_through_the_suites_own_probe_is_in_the_population(self):
        """`OcuPilot.Test.InstallerProbe` extends the installer and does not override `StartPath`,
        so a class driving it runs the real production install while naming no installer class --
        which is how `Test/DemoOptIn.cls` stayed outside the widened pattern."""
        self.write_test_class(
            "ProbeStarting", '    Set tSC = ##class(OcuPilot.Test.InstallerProbe).StartPath(0)'
        )
        problems: list[str] = []
        co.check_destructive_test_guard(problems)
        self.assertTrue(
            any("ProbeStarting.cls" in p for p in problems),
            f"expected the helper route to the production install refused, got {problems}",
        )

    def test_the_zero_argument_install_is_the_production_install_too(self):
        """`Install` declares `pProfile As %String = ""`, so a bare `Install()` is the production
        install under another spelling. A pattern anchored on the literal `""` read it as nothing
        at all, which is the same blind spot DW-402 filed about the method name."""
        self.write_test_class(
            "BareInstalling", "    Set tSC = ##class(OcuPilot.Install.Installer).Install()"
        )
        problems: list[str] = []
        co.check_destructive_test_guard(problems)
        self.assertTrue(
            any("BareInstalling.cls" in p for p in problems),
            f"expected the zero-argument production install refused, got {problems}",
        )

    def test_any_test_helper_reaching_the_install_is_in_the_population(self):
        """Fourteen classes under `Test/` extend the installer or `InstallerProbe` and inherit
        `StartPath` and `Install` unchanged. Listing the helpers by name is precisely what the next
        one is added outside of, so both methods are matched on any `OcuPilot.Test.*` class."""
        for name, call in (
            ("MigrateStarting", "    Do ##class(OcuPilot.Test.MigrateFault).StartPath(1)"),
            ("NamespaceStarting", "    Do ##class(OcuPilot.Test.NamespaceProbe).StartPath(1)"),
            ("ProbeBareInstalling", '    Set tSC = ##class(OcuPilot.Test.InstallerProbe).Install("")'),
        ):
            with self.subTest(name=name):
                self.write_test_class(name, call)
                problems: list[str] = []
                co.check_destructive_test_guard(problems)
                self.assertTrue(
                    any(f"{name}.cls" in p for p in problems),
                    f"expected {name} refused by the widened pattern, got {problems}",
                )

    def test_a_probe_profile_install_through_a_helper_is_still_outside_the_rule(self):
        """The widening is by class family, not by method: a probe-profile install through the
        same helper still creates only the objects the test owns."""
        self.write_test_class(
            "HelperProbeInstalling",
            '    Set tSC = ##class(OcuPilot.Test.InstallerProbe).Install("probe", 1)',
        )
        problems: list[str] = []
        co.check_destructive_test_guard(problems)
        self.assertEqual(problems, [])

    def test_a_probe_profile_install_is_outside_the_rule(self):
        """The rule anchors on the empty profile argument, not on the method. A probe install
        creates the parallel `Probe*` objects a test owns, which is what the suite is for."""
        self.write_test_class(
            "ProbeInstalling", '    Set tSC = ##class(OcuPilot.Install.Installer).Install("probe")'
        )
        problems: list[str] = []
        co.check_destructive_test_guard(problems)
        self.assertEqual(problems, [])

    def test_an_audit_event_registration_is_in_the_population(self):
        """An unregistered triple drops every row written under it, with no error and no log line,
        so a class that deletes or disables one silently stops auditing whatever instance it ran
        on."""
        for name, call in (
            ("EventMaker", '    Set tSC = ##class(Security.Events).Create("S", "T", "N")'),
            ("EventRemover", '    Set tSC = ##class(Security.Events).Delete("S", "T", "N")'),
            ("EventChanger", '    Set tSC = ##class(Security.Events).Modify("S", "T", "N", .tP)'),
        ):
            with self.subTest(name=name):
                self.write_test_class(name, call)
                problems: list[str] = []
                co.check_destructive_test_guard(problems)
                self.assertTrue(
                    any(f"{name}.cls" in p for p in problems),
                    f"expected {name} refused, got {problems}",
                )

    def test_a_class_that_is_not_a_test_case_is_outside_the_rule(self):
        """`Test/ProbeApps.cls` is a helper, not a suite: the runner never lists it, so it runs
        only where a guarded class called it."""
        self.write(
            "src/OcuPilot/Test/Helper.cls",
            "Class OcuPilot.Test.Helper Extends %RegisteredObject\n"
            "{\n\n"
            "ClassMethod Make() As %Status\n"
            "{\n"
            '    Quit ##class(Security.Users).Create("Probe")\n'
            "}\n\n"
            "}\n",
        )
        problems: list[str] = []
        co.check_destructive_test_guard(problems)
        self.assertEqual(problems, [])

    def test_the_call_named_in_a_comment_is_not_a_call(self):
        """The rule reads code lines only, so a doc comment describing the API it guards against
        does not make the class that carries it destructive."""
        self.write_test_class(
            "DocsOnly",
            "    Do $$$AssertTrue(1, \"nothing destructive here\")",
            "/// Explains why it never calls ##class(Security.Users).Create.\n"
            "Method OnBeforeOneTest() As %Status\n{\n    Quit $$$OK\n}\n",
        )
        problems: list[str] = []
        co.check_destructive_test_guard(problems)
        self.assertEqual(problems, [])


class TestDestructiveTestGuardRealClass(unittest.TestCase):
    """DW-303: every case above runs `co.check_destructive_test_guard` against a `FixtureTreeCase`
    scratch directory, and `TestShippedTreeIsCleanUnderTheNewRules` runs it over the real tree but
    only ever asserts `problems == []` -- a rule whose `DESTRUCTIVE_TEST_RE` matched nothing real
    would report exactly the same empty list as one that worked. Pin it against a real, shipped,
    already-guarded class, over the real `SCAN_ROOTS` (this class does not touch `co.ROOT`), so a
    change that made the regex stop matching real code would be visible here even though the
    shipped tree stays green either way.

    `OcuPilot.Test.LogSourceDenial` is the class DW-289's own incident named: it creates and
    deletes two users and two roles in `EnsurePrincipal`, and carries the
    `$System.Util.GetEnviron(..#ARMINGVARIABLE)` guard in `OnBeforeAllTests` this rule looks for.
    """

    REAL_GUARDED_CLASS = co.ROOT / "src" / "OcuPilot" / "Test" / "LogSourceDenial.cls"

    def test_a_real_shipped_class_actually_matches_the_destructive_call_pattern(self):
        text = co.read_text(self.REAL_GUARDED_CLASS)
        self.assertIsNotNone(text, f"expected {self.REAL_GUARDED_CLASS} to exist and be readable")
        self.assertRegex(
            text,
            co.DESTRUCTIVE_TEST_RE,
            "LogSourceDenial.cls no longer calls an API this rule watches for -- pick another "
            "real guarded class so this pin keeps demonstrating a true positive, not a vacuous one",
        )

    def test_that_real_class_is_reported_clean_because_it_carries_the_real_guard(self):
        problems: list[str] = []
        co.check_destructive_test_guard(problems)
        self.assertFalse(
            any("Test/LogSourceDenial.cls" in p for p in problems),
            f"expected the real, already-guarded class to pass, got {problems}",
        )


if __name__ == "__main__":
    unittest.main()

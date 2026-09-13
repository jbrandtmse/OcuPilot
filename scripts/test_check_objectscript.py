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


if __name__ == "__main__":
    unittest.main()

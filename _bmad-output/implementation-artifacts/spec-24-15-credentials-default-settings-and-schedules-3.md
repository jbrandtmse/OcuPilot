---
title: 'Story 24.15: Credentials, default settings and schedules (Batch 1b: a confirmed write acts in its proposal''s namespace)'
type: 'bugfix'
created: '2026-11-21'
status: 'done'
baseline_revision: '63062b501be5db1c7f1e67ea15c1e64a916562f3'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-15-credentials-default-settings-and-schedules.md'
warnings: ['oversized']
deferred:
  - summary: >-
      No test mints the three creates with a mint-supplied namespace (explorer.classes.create, explorer.routines.create, webapp.restapis.create) and confirms them from another namespace.
    evidence: |-
      ConfirmNamespaceRoster supplies Namespace in those creates' arguments itself (MINTARGUMENT), as ExplorerCreateMint and RestServiceCreateMint do; ExplorerCreateFlow confirms in the minting namespace only. A mint-level cross-namespace confirm test would settle it.
    location: >-
      src/OcuPilot/Test/ConfirmNamespaceRoster.cls
    severity: low
---

<intent-contract>

## Intent

**Problem:** Three `InteropPort` write tools store a proposal without the namespace they read in: `interop.businesspartners.remove`, `interop.lookupentries.remove` and `interop.lookuptables.delete`. Each declares a `FINGERPRINTSUBJECT` without `Namespace`, and the mint narrows the stored payload to that subject. A confirm sent from another namespace (`?ns=HSCUSTOM`) then re-reads, writes and reads back there. When that namespace holds an identical row, the confirm deletes it instead of the reviewed one (DW-2827). Commit `fc4a22869` fixed the same defect for `interop.defaultsettings.remove`.

**Approach:** Apply the `fc4a22869` fix to each tool: add `Namespace` to its `FINGERPRINTSUBJECT`. The stored payload then keeps the namespace, and `InteropAction.PortQuery` sends it at the confirm's re-read, write and read-back, and in the copy-out draft. Add one HTTP test leg per tool.

## Boundaries & Constraints

**Always:** The namespace travels in the stored payload and is sent by `InteropAction.PortQuery` (AD-52, AD-62). The card's rows stay `REMOVALROWS`, so no person sees a change. Every test passes on its first run on a fresh throwaway, in either order. It removes every probe row it makes in `USER` and `HSCUSTOM`, deletes its ledger rows and restores the governance policy.

**Never:** No change to the kernel (`Kernel/Proposal/*`), to another port's tools, to `interop.defaultsettings.remove`, to `src/OcuPilot/Api/Error.cls` or to `Kernel/Proposal/Prohibited.cls`. No new refusal or user-facing string. No edit to the Batch 2 spec (`-2.md`).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Partner remove, confirmed from another namespace | Partner `OcuProbe226Ns` is identical in `USER` and `HSCUSTOM`; the remove is minted in `USER` and confirmed with `?ns=HSCUSTOM` | 200. `USER`'s partner is gone; `HSCUSTOM`'s `PartnerText` is unchanged | No error expected |
| Entry remove, confirmed from another namespace | Table `OcuProbe205Ns` holds `k=same` and `keep=1` in both namespaces; remove `k` minted in `USER`, confirmed with `?ns=HSCUSTOM` | 200. `USER` reads `keep=1`; `HSCUSTOM` still reads `k=same;keep=1` | No error expected |
| Table delete, confirmed from another namespace | Table `OcuProbe205Ns` holds `a=1` in both namespaces; delete minted in `USER`, confirmed with `?ns=HSCUSTOM` | 200. `USER` has no such table; `HSCUSTOM` still reads `a=1` | No error expected |
| Same-namespace confirm (existing legs) | The sibling control tests confirm with `?ns=USER` | Unchanged | Unchanged |

</intent-contract>

## Code Map

- `src/OcuPilot/Screen/Tool/InteropPartnerRemove.cls:31` -- `FINGERPRINTSUBJECT`, the 14 fields plus `NamedBy`; card rows come from `REMOVALROWS` (line 36). Story 20.26.
- `src/OcuPilot/Screen/Tool/InteropLookupEntryRemove.cls:29` -- `FINGERPRINTSUBJECT = "Key,Value"`. Story 20.5.
- `src/OcuPilot/Screen/Tool/InteropLookupTableDelete.cls:39` -- `FINGERPRINTSUBJECT = "Name,Entries,Modified"`; `READANSWERS` already declares `Namespace` (line 23). Story 20.5.
- `src/OcuPilot/Screen/Tool/InteropDefaultSettingRemove.cls:27-29` -- the golden example: `Namespace` in the subject and its doc sentence.
- `src/OcuPilot/Screen/Tool/InteropAction.cls:122-140` -- `ArgumentNamespace`/`PortQuery`: the payload's `Namespace`, else `Kernel.Scope.Current()`. Read-only.
- `src/OcuPilot/Kernel/Proposal/Mint.cls:290-306` -- narrows the stored payload to the subject. `Operation.cls:258,477` -- the confirm's query is built from the stored payload. Read-only.
- `src/OcuPilot/Test/InteropLookupDescriptor.cls:22` -- `TOOLS` pins the entry-remove and table-delete subjects (a shared surface).
- `src/OcuPilot/Test/InteropItemControl.cls:427` -- `ConfirmHttp` hard-codes `?ns=` + `NAMESPACE`; 38 other test classes call it.
- `src/OcuPilot/Test/InteropLookupFixture.cls` -- `Put`, `Drop`, `Exists`, `Entries`, `PutPartner`, `PartnerText` and `DropPartners` work in `USER` only; `PutDefault` (line 185) is the sibling that takes `pNamespace`.
- `src/OcuPilot/Test/InteropLookupControl.cls:259-350`, `src/OcuPilot/Test/InteropDefaultSettingEdges.cls` (`TestARemoveConfirmedFromAnotherNamespaceActsWhereItRead`) -- golden test shapes: mint, governance on, confirm, assert, restore.
- `scripts/ci-throwaway.sh:567` -- the `OCUPILOT_ALLOW_PRINCIPALS` roster's `# classes:` lines, which `ui/tools/ci.test.mjs` reads. Epic 21 changed this file, so edits here are add-only.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Screen/Tool/InteropPartnerRemove.cls`, `InteropLookupEntryRemove.cls`, `InteropLookupTableDelete.cls` -- append `Namespace` to `FINGERPRINTSUBJECT` and add the `InteropDefaultSettingRemove` sentence to its doc comment -- the stored payload keeps the namespace (DW-2827).
- `src/OcuPilot/Test/InteropLookupDescriptor.cls` -- update the two subjects in `TOOLS` -- the subject pin.
- `src/OcuPilot/Test/InteropItemControl.cls` -- `ConfirmHttp` gains a trailing optional `pNamespace`; empty means `NAMESPACE` -- lets a test confirm from another namespace without copying the method.
- `src/OcuPilot/Test/InteropLookupFixture.cls` -- add a trailing optional `pNamespace` (empty means `NAMESPACE`) to `Put`, `Drop`, `Exists`, `Entries`, `PutPartner`, `PartnerText` and `DropPartners`, as `PutDefault` already does; leave `Clear` as it is.
- `src/OcuPilot/Test/InteropConfirmNamespace.cls` (new, `ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS"`) -- one method per Matrix row 1-3. Mint through `InteropPartnerControl.Mint` or `InteropLookupControl.Mint` (scoped to `USER`), turn on the tool's governance key, and confirm through `ConfirmHttp(..., "HSCUSTOM")`. `OnBeforeOneTest` and `OnAfterOneTest` call `Clear()`, then `Drop` the probe table and `DropPartners` the probe partner in `HSCUSTOM`. Each method deletes its turn's ledger rows and restores the policy.
- `scripts/ci-throwaway.sh` -- add a comment and a `# classes: InteropConfirmNamespace` line under the `OCUPILOT_ALLOW_PRINCIPALS` block, after the default-setting lines. Add-only.
- `src/OcuPilot/Test/ConfirmNamespaceRoster.cls` (new; a second class by port group if one passes about 500 lines; arm it only if `ui/tools/ci.test.mjs` or the sweep requires it) -- the permanent form of the Roster sweep (orchestrator order, in scope). For every write tool `OcuPilot.Screen.Tool.Registry.ListTools` returns: set the request scope (`OcuPilot.Kernel.Scope`) to sentinel A and build the payload the mint stores (the tool's `MergeUpdate` over a read answering every `READANSWERS` field, narrowed by `FingerprintSubject`; or `ComposeCreate`, with the arguments its mint builds where the mint puts `Namespace` into them); set the scope to sentinel B; build the confirm's port query with `Operation.Query`; assert the query names A. Restore the scope in every path. Exempt only namespace-free and person-only tools, from a declared roster with one reason per entry (a port class, or a tool name for the person-only and the one-off cases), and assert each roster entry matches a registered write tool and that an exempt tool declares instance scope or is person-only. Floor assertions: the write tools walked, and the tools checked, are each above 0; pin the exemption roster's size. Counts in Design Notes are scratch measurements; the class measures its own on the instance.

**Acceptance Criteria:**

- Given a partner, an entry or a table held identically in `USER` and `HSCUSTOM`, when the agent's remove or delete is minted in `USER` and confirmed by a request scoped to `HSCUSTOM`, then the confirm answers 200, `USER`'s row is gone and `HSCUSTOM`'s row is unchanged (Matrix rows 1-3, one test each).
- Given every registered write tool outside the declared exemption roster, when the roster test builds a proposal's stored payload in one namespace and the confirm's port query in another, then the query names the first namespace; the new roster test passes on its first run on a fresh instance, forward and reverse.
- Given the three tools, when `InteropLookupDescriptor`, `InteropLookupControl`, `InteropPartnerControl` and the full ObjectScript sweep run, then each is green and the cards show the same rows as before.

## Spec Change Log

- 2026-11-21, implement: the orchestrator ordered the roster guard test added to this pass (Task `ConfirmNamespaceRoster`, one acceptance bullet, a fourth mutation). The test supplies each tool's declared namespace field in the read it merges, so the inference in Design Notes › Roster ("carries" assumes each read answers its declared field) still stands.

## Review Triage Log

### 2026-11-21 — Review pass

- verdicts: 9 findings — high 0, medium 1, low 2, false 6, maybe-false 0
- findings:
  - `[low]` `[defer]` The roster test puts `Namespace` into the arguments of three creates itself, so a mint that stopped doing so would not redden it — the real mints (`ExplorerCreateMint`, `RestServiceCreateMint`) set the argument and no test confirms those creates from another namespace; a pre-existing coverage gap the roster does not widen, deferred with a mint-level test as its settle.
  - `[medium]` `[patch]` The roster's own guards (an exemption on a namespace-scoped tool, a person exemption with no gate, a dropped or needless `MINTARGUMENT` entry) had no observed mutation — four mutations observed on `ocupilot-b-ci` and recorded under Mutations; no code changed, every revert byte-identical (md5).
  - `[false]` `[reject]` The partner remove's subject has no source-text pin — covered behaviourally: the partner mutation reds `InteropConfirmNamespace` alone (run 41).
  - `[false]` `[reject]` The doc sentence on the three subjects ("the confirm and the script form act where the proposal read") is untested — it is the sentence `InteropDefaultSettingRemove` carries, the golden example the spec names; no claim of its own.
  - `[false]` `[reject]` The roster walk reads and restores `^||OcuPilotScope` directly — `Scope.Current` falls back to `$Namespace`, so only the global tells an unset scope from a set one, and the walk must put back exactly what it found.
  - `[false]` `[reject]` The roster class has no arming variable — it writes nothing: it composes payloads and builds queries, and sets and restores the request scope; it ran green on the throwaway.
  - `[low]` `[reject]` The copy-out draft is not asserted — the intent names it as part of what `PortQuery` sends, not as a new behavior; the fix is the one the default-setting tool already carries, and a test of it would be a new surface for no new risk.
  - `[false]` `[reject]` The table leg does not assert the two tables' `Modified` stamps match — the stamp is read in `USER` and the fixed confirm acts in `USER`; `HSCUSTOM`'s stamp plays no part, and the leg's assertions are the rows.
  - `[false]` `[reject]` The roster test reaches other ports' tools — it only reads them and edits none; ordered by the orchestrator and recorded in the Spec Change Log.

### 2026-11-21 — Code review (three layers)

- verdicts: 12 findings — high 0, medium 2, low 4, false 6, maybe-false 0
- findings:
  - `[medium]` `[patch]` An exemption is accepted on instance scope alone, so a port line can drop tools that carry the namespace (`SqlPrivilegePort`) and an exempt port that starts reading the request scope stays green — `ExemptionProblem` now also refuses a port that names the request scope in any method it compiles, and the main test asserts at least `CHECKEDFLOOR` (115) tools are asked.
  - `[medium]` `[patch]` `Carries` accepted the mint's namespace under any query key — it now reads only the port's `NAMESPACEKEY` (else `NAMESPACEQUERY`) and reports a port that declares neither.
  - `[low]` `[patch]` The class header and the Spec Change Log claimed the roster proves the stored payload of a real read; both now say the test supplies the read's namespace field, and the inference stands.
  - `[low]` `[patch]` The main roster test passed on an empty walk; the floor now sits in it.
  - `[low]` `[patch]` The size test's documented mutation and AC3 had no observed mutation — both run and recorded under Mutations.
  - `[low]` `[reject]` No registry-wide check that a no-subject tool's real port read answers its namespace field — pre-existing, needs a mint per port; wontfix-accepted, reopen_if a confirm of a no-subject tool from another namespace acts in the confirming namespace.
  - `[false]` `[reject]` A proposal minted before the upgrade closes target-changed — intended and named under Shared surfaces; nothing is written and the person proposes again.
  - `[false]` `[reject]` A pre-upgrade partner remove's copy-out script renders `Set $NAMESPACE = ""` — it did so for every such proposal before this change, which fixes it for new ones; old proposals expire.
  - `[false]` `[reject]` A malformed `Exemptions` line raises `<SUBSCRIPT>` — the test errors loudly, which is the wanted outcome.
  - `[false]` `[reject]` A duplicate `Exemptions` line with a bumped count passes the size test — needs a deliberate duplicate and count edit; no realistic path.
  - `[false]` `[reject]` `Carries` leaves the scope set when called directly — only `Walk` calls it, and `Walk` restores the scope on every path.
  - `[false]` `[reject]` Missing QA tests for the three tools — conditions (a)-(d) are covered: `InteropConfirmNamespace` (cross-namespace, other row untouched, mutations runs 41/44/45) and the same-namespace legs `InteropPartnerControl.TestTheAgentsRemoveConfirmsOverHttp`, `InteropLookupControl.TestTheAgentsRemoveConfirmsOverHttp` and `TestTheAgentsDeleteConfirmsOverHttp`.

## Design Notes

**Roster** (Task 0, measured 2026-11-21 on `ocupilot-b-ci`, namespace `HSCUSTOM`).

Method: a scratch class (`OcuScratch.NsRoster`, deleted afterwards) listed `OcuPilot.Screen.Tool.Registry.ListTools`. For each tool of kind `write`, it built the payload the mint stores: the tool's own `MergeUpdate` over a read answering every `READANSWERS` field, narrowed by `FingerprintSubject`, or its `ComposeCreate`. The request scope was set to a mint sentinel while it built the payload. It then switched the scope to a confirm sentinel and built the confirm's port query with `Operation.Query`. A tool **carries** the namespace when that query names the mint sentinel. Four creates whose mint puts `Namespace` into their arguments were run again with those arguments. Only 8 ports read the request scope (Analytics, Atelier, DevTool, DocDb, Global, Interop, Mgmnt, Sql), and each reads it only when the query names no `namespace` (`grep` of `src/OcuPilot/Port`). `SqlPrivilegePort` reads the query alone.

| Group | Count | How |
|---|---|---|
| Write tools in the registry (of 570 tools) | 335 | |
| Namespace-free | 218 | The port never reads the request scope: the Admin API and the other instance ports. `logs.applicationerrors.delete` names its namespace in its id (AD-48). |
| Carry the namespace | 111 | 75 through the fingerprint subject, 17 through the merged read, 19 creates whose `ComposeCreate` stores the mint's scope |
| Person-only | 3 | `explorer.classmethod.run`, `explorer.command.run`, `explorer.unittests.run` (`ADVERTISED` 0, `PERSONGATE`): they mint no proposal, so nothing is stored |
| **Lose the namespace** | **3** | `interop.businesspartners.remove` (`InteropPartnerRemove`, Story 20.26), `interop.lookupentries.remove` (`InteropLookupEntryRemove`, Story 20.5) and `interop.lookuptables.delete` (`InteropLookupTableDelete`, Story 20.5). All three are `InteropPort` tools of Epic 20. |

The committed roster test exempts 220 and asks 115, one fewer exempt than this table: `security.auditing.copy` (`AuditCopy`, `AuditPort`) is counted namespace-free here, since its port never reads the request scope, but it names a namespace in its query (`CopyNamespace`), so the test asks it rather than exempt it (read from the roster class and `ocupilot-b-ci`, 2026-11-21; `logs.applicationerrors.delete` stays exempt through `LogSourcePort`).

"Carries" assumes each port's read answers the namespace field its `READANSWERS` declares (inference). It is measured end to end only for `interop.defaultsettings.remove`. The losers are exactly DW-2827's three, so the stop rule's first branch applies.

**Why per tool, not the kernel.** All 111 tools that carry the namespace do it the per-tool way, through `PortQuery` (AD-52, AD-62 item 3). The kernel already records the mint's namespace in a namespace-scoped proposal's `targetRef` (`EntityRef.ScopeFor`), and `Confirm.FingerprintMatches` parses it but ignores it. A kernel switch would cover future tools as well (inference). That option is left to the orchestrator.

**Table delete.** Without the fix, the table leg's confirm answers 200 and deletes `HSCUSTOM`'s table, as the other two legs do (measured on `ocupilot-b-ci`, 2026-11-21).

**Decided in-stage:** a new test class, because the sibling classes are at 357-490 lines; probe names under the prefixes the siblings already clean (`OcuProbe205`, `OcuProbe226`); cleanup of `HSCUSTOM` stays in the new class, so `Clear`, which 15 classes share, is unchanged; `ConfirmHttp` and the fixture are extended rather than copied (Rule 2).

**Out of scope:** `InteropAction.PrivilegePairs` judges the confirming request's database pairs. The port's own gate (AD-62 item 2) judges the namespace the write lands in.

**Governing ADs:** AD-6, AD-51, AD-52, AD-53, AD-58, AD-59, AD-62. **Integration AC:** the consumer is the confirm route `/proposal/{id}/confirm?ns=HSCUSTOM` over HTTP, the outermost surface. **Owned ledger:** DW-2827, addressed by every task.

## Verification

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.InteropConfirmNamespace`, one call each, then `ConfirmNamespaceRoster`, `InteropLookupDescriptor`, `InteropLookupControl`, `InteropLookupEdges`, `InteropLookupRefusals`, `InteropPartnerControl`, `InteropPartnerRefusals`, `InteropPartnerGate`, `InteropLookupGate`, `InteropDefaultSettingEdges` and `DraftRegistry`. Expected: green; each new class is green on its first run.
- `(loop)` `cd ui && node --test tools/ci.test.mjs` and `uv run scripts/check-objectscript.py`. Expected: green.
- `(once)` The full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17` for k = 1 to 17, one call each. Expected: green. The browser suite is left to CI, and no client code changes.

**Shared surfaces:** the `OCUPILOT_ALLOW_PRINCIPALS` arming roster; `InteropLookupDescriptor`'s `TOOLS`; the stored payload and fingerprint of the three tools (a proposal minted before the change closes target-changed); the probe lookup tables and partners in `USER` and `HSCUSTOM`. Every test added or changed passes on a fresh environment, in either order.

**Mutations** (`mutation: <change> -> <test>`, filled in at implement):

- mutation: take `Namespace` out of `InteropPartnerRemove.FINGERPRINTSUBJECT` -> observed on `ocupilot-b-ci` (run 41): the partner leg reds alone (1 of 3); the confirm answers 200, `USER`'s partner is left and `HSCUSTOM`'s is removed. Reverted byte-identical (md5), green on run 46.
- mutation: take `Namespace` out of `InteropLookupEntryRemove.FINGERPRINTSUBJECT` -> observed (run 44): the entry leg reds alone; `USER`'s `k` is left and `HSCUSTOM`'s is removed. Reverted byte-identical (md5), green on run 46.
- mutation: take `Namespace` out of `InteropLookupTableDelete.FINGERPRINTSUBJECT` -> observed (run 45): the table leg reds alone; the confirm still answers 200 (the status assertion stays green), `USER`'s table is left and `HSCUSTOM`'s is deleted. Reverted byte-identical (md5), green on run 46.
- mutation: take `Namespace` out of `InteropPartnerRemove.FINGERPRINTSUBJECT` again, load, none of the three tools has a subclass -> observed (run 43): `ConfirmNamespaceRoster` reds alone in `TestEveryWriteToolAsksItsPortInTheNamespaceItsProposalRead`, and the failed assertion's description names `interop.businesspartners.remove (OcuPilot.Screen.Tool.InteropPartnerRemove)`. Reverted byte-identical (md5), green on run 47.
- mutation: add the entry `port|OcuPilot.Port.NoSuchPort` to the roster's `Exemptions` -> observed (run 49): `TestEveryExemptionNamesARegisteredWriteTool` and `TestTheWalkIsNotEmptyAndTheRosterHasItsSize` red, the third stays green. Reverted byte-identical (md5), green on run 50.
- mutation: exempt a namespace-scoped tool (`tool|interop.businesspartners.remove|mutation` in `Exemptions`) -> observed on the rebuilt throwaway (run 16): `TestEveryWriteToolAsksItsPortInTheNamespaceItsProposalRead` reds, naming the tool as exempt as instance-scoped while its descriptor declares namespace; the size test reds with it.
- mutation: exempt a tool as a person's alone with no person's gate (`person|interop.businesspartners.remove|mutation`) -> observed (run 17): the same test reds, "declares no person's gate".
- mutation: drop `RestServiceCreate` from `MINTARGUMENT` -> observed (run 18): the same test reds alone, naming `webapp.restapis.create`.
- mutation: add `AnalyticsListingAdd` to `MINTARGUMENT` -> observed (run 19): `TestEveryExemptionNamesARegisteredWriteTool` reds alone, naming `analytics.listinggrouplistings.add`. Each reverted byte-identical (md5), green on run 20.
- mutation (review): exempt `port|OcuPilot.Port.SqlPrivilegePort` with `EXEMPTIONCOUNT` 43 -> observed (run 877): the main roster test reds alone on the floor, "at least 115 write tools are asked: 111".
- mutation (review): drop the `WalletPort` line from `Exemptions` -> observed (run 878): the size test reds, and the main test names the wallet tools, whose port declares no namespace key.
- mutation (review): add a `WalletPort` method that returns `Kernel.Scope.Current()` -> observed (run 880): the main test reds alone, "its port OcuPilot.Port.WalletPort reads the request scope".
- mutation (review): `InteropAction.PortQuery` sends the namespace as `Namespace`, not `namespace` -> observed (run 881): the main test reds alone, naming the Interop tools; the earlier any-key check stayed green on it.
- mutation (review, AC3): take `Namespace` out of `InteropLookupEntryRemove.FINGERPRINTSUBJECT` -> observed (run 884): `InteropLookupDescriptor.TestTheFourWriteToolsAreDeclaredAsThePlanPlacesThem` reds alone; the card rows come from `REMOVALROWS`, which the diff leaves as it was. Each review mutation was made on the throwaway's source copy only and reverted (`diff -rq` identical); green after on runs 882, 883 and 885.

### QA

- No test added: the QA layer found every orchestrator condition covered (see the code review triage).

## Auto Run Result

Status: done
Blocking condition: none

**Change.** `interop.businesspartners.remove`, `interop.lookupentries.remove` and `interop.lookuptables.delete` keep `Namespace` in their `FINGERPRINTSUBJECT`, so a confirm sent from another namespace asks the port in the namespace the proposal read (DW-2827). Without the fix the table leg's confirm answers 200 and deletes `HSCUSTOM`'s table, as the other two legs do.

**Files.**

- `src/OcuPilot/Screen/Tool/InteropPartnerRemove.cls`, `InteropLookupEntryRemove.cls`, `InteropLookupTableDelete.cls`: `Namespace` appended to the subject, with the doc sentence.
- `src/OcuPilot/Test/InteropLookupDescriptor.cls`: the two subjects in `TOOLS`.
- `src/OcuPilot/Test/InteropItemControl.cls`, `InteropLookupFixture.cls`: optional trailing `pNamespace`.
- `src/OcuPilot/Test/InteropConfirmNamespace.cls` (new): Matrix rows 1-3, one HTTP leg each.
- `src/OcuPilot/Test/ConfirmNamespaceRoster.cls` (new, orchestrator order): every registered write tool outside a 43-entry declared exemption roster asks its port in the minting namespace. After the integration of feature 1d3cc3a3b (Story 21.37), 337 write tools are walked, 222 exempt and 115 asked: the guard reddened on 21.37's two page-resource writes, and `PortalResourcePort` joins the roster as instance-scoped, since page resources live in `%SYS` and the port never reads the request scope.
- `scripts/ci-throwaway.sh`: add-only `# classes: InteropConfirmNamespace` line.

**Review.** 9 findings: 1 medium patched (four roster-guard mutations observed, no code change), 1 low deferred (mint-level cross-namespace test for three creates), 1 low and 6 false rejected, reasons in the Triage Log. Follow-up review recommended: false.

**Verification.** On the rebuilt `ocupilot-b-ci`: both new classes green on their first run (runs 1 and 2), then forward and reverse; `InteropLookupDescriptor`, `InteropLookupControl`, `InteropLookupEdges`, `InteropLookupRefusals`, `InteropLookupGate`, `InteropPartnerControl`, `InteropPartnerRefusals`, `InteropPartnerGate`, `InteropDefaultSettingEdges` and `DraftRegistry` green; the Rule 29 sweep, shards 1-17 of 17, 0 failed, no flake; `check-objectscript.py` 0 problems; `npm run test:tools` 2385 passed; `lint-docs.sh` 0 problems. Nine mutations observed, each reverted byte-identical.

**Residual risks.** The test checks that each exempt tool declares instance scope and that no method its port compiles from an OcuPilot class names the request scope; a helper outside the port that reads it is not seen. `ci-timings.json` is not refreshed here; the merge gate does it.

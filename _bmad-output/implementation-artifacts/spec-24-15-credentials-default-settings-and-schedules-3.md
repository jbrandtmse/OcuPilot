---
title: 'Story 24.15: Credentials, default settings and schedules (Batch 1b: a confirmed write acts in its proposal''s namespace)'
type: 'bugfix'
created: '2026-11-21'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-15-credentials-default-settings-and-schedules.md'
warnings: ['oversized']
deferred: []
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

**Acceptance Criteria:**

- Given a partner, an entry or a table held identically in `USER` and `HSCUSTOM`, when the agent's remove or delete is minted in `USER` and confirmed by a request scoped to `HSCUSTOM`, then the confirm answers 200, `USER`'s row is gone and `HSCUSTOM`'s row is unchanged (Matrix rows 1-3, one test each).
- Given the three tools, when `InteropLookupDescriptor`, `InteropLookupControl`, `InteropPartnerControl` and the full ObjectScript sweep run, then each is green and the cards show the same rows as before.

## Spec Change Log

## Review Triage Log

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

"Carries" assumes each port's read answers the namespace field its `READANSWERS` declares (inference). It is measured end to end only for `interop.defaultsettings.remove`. The losers are exactly DW-2827's three, so the stop rule's first branch applies.

**Why per tool, not the kernel.** All 111 tools that carry the namespace do it the per-tool way, through `PortQuery` (AD-52, AD-62 item 3). The kernel already records the mint's namespace in a namespace-scoped proposal's `targetRef` (`EntityRef.ScopeFor`), and `Confirm.FingerprintMatches` parses it but ignores it. A kernel switch would cover future tools as well (inference). That option is left to the orchestrator.

**Table delete.** `Modified` is the vendor's millisecond stamp, so the vendor's own calls cannot make `HSCUSTOM`'s table identical. Without the fix, that leg therefore reds as 409 `PROPOSAL.TARGETCHANGED`, not as a deletion. A table copied with its global keeps its stamp and would be deleted (inference).

**Decided in-stage:** a new test class, because the sibling classes are at 357-490 lines; probe names under the prefixes the siblings already clean (`OcuProbe205`, `OcuProbe226`); cleanup of `HSCUSTOM` stays in the new class, so `Clear`, which 15 classes share, is unchanged; `ConfirmHttp` and the fixture are extended rather than copied (Rule 2).

**Out of scope:** `InteropAction.PrivilegePairs` judges the confirming request's database pairs. The port's own gate (AD-62 item 2) judges the namespace the write lands in.

**Governing ADs:** AD-6, AD-51, AD-52, AD-53, AD-58, AD-59, AD-62. **Integration AC:** the consumer is the confirm route `/proposal/{id}/confirm?ns=HSCUSTOM` over HTTP, the outermost surface. **Owned ledger:** DW-2827, addressed by every task.

## Verification

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.InteropConfirmNamespace`, one call each, then `InteropLookupDescriptor`, `InteropLookupControl`, `InteropPartnerControl`, `InteropLookupEdges` and `InteropDefaultSettingEdges`. Expected: green; the new class is green on its first run.
- `(loop)` `cd ui && node --test tools/ci.test.mjs` and `uv run scripts/check-objectscript.py`. Expected: green.
- `(once)` The full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17` for k = 1 to 17, one call each. Expected: green. The browser suite is left to CI, and no client code changes.

**Shared surfaces:** the `OCUPILOT_ALLOW_PRINCIPALS` arming roster; `InteropLookupDescriptor`'s `TOOLS`; the stored payload and fingerprint of the three tools (a proposal minted before the change closes target-changed); the probe lookup tables and partners in `USER` and `HSCUSTOM`. Every test added or changed passes on a fresh environment, in either order.

**Mutations** (`mutation: <change> -> <test>`, filled in at implement):

- mutation: take `Namespace` out of `InteropPartnerRemove.FINGERPRINTSUBJECT` -> the partner leg reds: `HSCUSTOM`'s partner is removed and `USER`'s is left.
- mutation: take `Namespace` out of `InteropLookupEntryRemove.FINGERPRINTSUBJECT` -> the entry leg reds: `HSCUSTOM`'s `k` is removed.
- mutation: take `Namespace` out of `InteropLookupTableDelete.FINGERPRINTSUBJECT` -> the table leg reds: 409 target-changed, and `USER`'s table is still there.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

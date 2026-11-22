---
title: 'Story 24.15: Credentials, default settings and schedules (Batch 2: credentials)'
type: 'feature'
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

**Problem:** An interoperability namespace's credentials (`Ens.Config.Credentials`, the classic `EnsPortal.Credentials` page) have no OcuPilot screen or tool. The agent's own provider can read its key from one of these rows (the `creds` rung), so an agent write could disable the agent itself.

**Approach:** Batch 2 of three (Batch 1's Design Notes › Questions 1). Interoperability gains **Credentials**: a list read through `InteropPort`, with add, edit (user name and business partner), set password and remove, each one operation reached by the screen and by the agent, built on Batch 1's family pattern. The agent's remove and password change of a credential an enabled agent definition names are refused when proposed. "Round-trips over its backing class" means: a credential added or edited from either caller reads back from `Ens.Config.Credentials` exactly as sent, a password set from either caller reads as stored, and a removed one is gone.

## Boundaries & Constraints

**Always:**

- **One port (AD-62).** `InteropPort` gains `Credentials` (`LIST`, `CREDENTIAL`, `ADDCREDENTIAL`, `SETCREDENTIAL`, `PASSWORDCREDENTIAL`, `REMOVECREDENTIAL`) over `Ens.Config.Credentials` (`%New`, `%OpenId` at concurrency 4, `%Save`, `%DeleteId`; SQL read with `%ExecDirectNoPriv` after the gate), switched, with no `OcuPilot.*` call while switched.
- **Rows** `{Name, Username, BusinessPartner, Password, Namespace}`, id `Name` kept exactly, capped with truncation reported (AD-36). `Password` is `stored` or `not stored` and **the password is never read**: no `PasswordGet`, no `PasswordSQL`, no `SecondaryGet`; the stored test is the vendor's secondary node's existence and non-empty length in one expression (Task 0 (e) fixes the exact test), never bound to a variable, compared, returned or logged (AD-35).
- **Gate (AD-29, AD-8), before any vendor call.** Read: `%Ens_Portal:USE`, `%Ens_Credentials:READ`, then `Admit` (interoperability, globals-database READ). Write: `%Ens_Credentials:WRITE` and globals-database WRITE, plus any pair Task 0 (b) measures. Never cached.
- **Write refusals by name, before any vendor call:** a name empty, over the vendor's limit (Task 0 (d)) or holding a control character (422 `NAME`); an add whose name an existing one equals ignoring letter case (409 `TAKEN`, because the vendor's adapters resolve names ignoring case); an edit, password or remove whose name is absent (404); a business partner that is not empty and not one of the namespace's partners (422 `PARTNER`); a user name the vendor refuses (422 `VALUE`, its text logged, never shown).
- **Writes (AD-3, AD-6, AD-34, AD-51 to AD-56, AD-58, AD-59, AD-14, AD-10, AD-22).** Four tools `interop.credentials.add|update|password|remove` over one fresh read. The add is a create (AD-54) whose password is a composed secret (`COMPOSEDSECRETS`, as `WalletSecretCreate`), typed on the card or in the dialog, and may be empty (no password stored). Edit changes `Username` and `BusinessPartner` only, sending the fields the person changed (`SCREENOPTIONAL`). Set password is secret-only (`SECRETBODY`, as `TaskMailPassword`, no `CLEARABLESECRETS`: an empty password is not a secret supplied). The name never changes: a rename is a remove and an add. Every non-create tool's stored subject carries `Namespace`. Read-back through the update's read (`Password` reads `stored` after a password write). A script form per tool whose password renders `<Password>` only. Keys `add`, `update`, `password` `true`; `remove` `false` (destructive). A screen action mints nothing and is not gated by read-only or the kill switch.
- **Audit (AD-15).** The agent's marker on every agent write; OcuPilot's own `ConfigChange` from either caller through `AuditRuntime`, naming the namespace, the credential and the changed field names, never a value or password (Task 0 (a) confirms the vendor records nothing).
- **BINDING orchestrator conditions (U-135 Q3, strict approved), verbatim:**
  - The check reads the credential name from the provider configuration as stored at proposal time (no cache, no parameter); every enabled provider definition counts, not only the demo one.
  - Refuse at proposal time: no card minted. The `Kernel/Proposal/Prohibited.cls` term is append-only. The refusal sentence is a Proposed string the orchestrator rules with this plan's strings.
  - Scope: only the agent's remove and password change are refused. The screen path stays open behind its normal confirm; the agent's add and its edit of other fields stay open.
  - Tests, each with a mutation line: agent remove refused; agent password change refused; the same credential through the screen allowed; a credential no provider names allowed; a provider renamed to another credential moves the refusal with it.
  - Wallet-secret parity is ledgered separately (DW-2822, burndown); do not widen this batch to cover it.
- **How the binding check is built.** `Prohibited.cls` gains, append-only, `PROVIDERCREDENTIAL = "PROHIBITED.PROVIDERCREDENTIAL"`, its `…REASON`, one term in `Codes()`, one `ReasonFor` line and one class method that answers whether a name is one an enabled `creds` definition (`OcuPilot.Kernel.State.Agent`: `Enabled` 1, `CredType` `creds`) names in `CredentialName`, matched exactly, read through a new guarded `Agent` reader at the call; a failed read refuses. The remove and password tools override `RefusedBeforeState` to ask it only when `OcuPilot.Kernel.Proposal.Caller.IsTurn()` and the route's namespace is the process's own (`Prohibited.IsOwnNamespace`, the namespace the provider reads its credential in): the mint answers 403 with the sentence and stores nothing; the screen action route (`ScreenAction.cls:401`), running in no turn, is not refused.

**Never:**

- `%Api.InteropEditors`; `EnsPortal.*` methods; the classic page's `?ID=` load, which places the password in the form.
- A password in any row, proposal, diff, draft, read-back, audit payload, log, screen context or error.
- A source-control refusal (the classic page and the vendor have none; credentials are no source-controlled document) (inference on the last clause).
- The wallet rung's secrets (DW-2822); DW-2827's sibling removes (Batch 1b); schedules (Batch 3); default settings; import or export.
- `src/OcuPilot/Api/Error.cls` (frozen); `ui/angular.json`; `ui/vitest-base.config.mjs`; `scripts/ci-throwaway.sh` beyond add-only roster lines; any logic edit in `Prohibited.cls` beyond the appended parameters, terms and methods in Code Map; a spine edit.

## I/O & Edge-Case Matrix

Route namespace USER unless named; HSCUSTOM is the throwaway's install namespace. Probe credentials are named `OcuProbe2415*`; probe agent definitions are never the default, enabled only inside the test that needs one, and removed after.

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Add, both callers | `OcuProbe2415A`, user `probe`, a partner, a password | Row reads back; `Password` stored; read-back `matches` | - |
| Add, no password | Same, password empty | Row saved; `Password` not stored | - |
| Edit | User name only, from the screen | User name changed; partner and password kept | - |
| Set password | A new password, both callers | `Password` stored; no value anywhere | - |
| Remove | A probe credential | Gone, its password node gone; card destructive | - |
| Taken / absent | Add `ocuprobe2415a` beside `OcuProbe2415A`; edit, set or remove a missing name | Refused | 409 `INTEROP.CREDENTIAL.TAKEN`; 404 |
| Invalid | Name over the limit or with a control character; unknown partner | Refused | 422 `INTEROP.CREDENTIAL.NAME`; 422 `INTEROP.CREDENTIAL.PARTNER` |
| Gate | No `%Ens_Credentials:WRITE`; no read pair | Refused before any vendor call | 403 naming the pair |
| Provider, agent | An enabled `creds` definition names `OcuProbe2415P` in HSCUSTOM; agent remove; agent password | No card minted | 403 `PROHIBITED.PROVIDERCREDENTIAL` |
| Provider, open paths | Same credential: screen remove and password; agent edit of its user name; agent add of another credential; `OcuProbe2415P` in USER; a credential only a disabled definition names | Each succeeds | - |
| Provider moved | The definition renamed from `…P` to `…Q` | `…P` agent remove proposed; `…Q` refused | 403 on `…Q` |

</intent-contract>

## Code Map

Paths under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-24` (HEAD `3ae1d87a3`; Batch 1 code head `fc4a22869`). Batch 1b (DW-2827) may move `InteropPort` lines first: re-anchor by symbol. **Contended with Epic 21 (add-only):** `Prohibited.cls`, `Kernel/EntityType.cls`, `Kernel/Governance/Baseline.cls`, `Screen/Titles.cls`, `Screen/Registry.cls`, `ui/src/app/core/{strings,screens.generated,screen-actions,navigation,proposal-view}.ts`, `ui/src/app/shell/{screen-outlet,screen-action-handler}.ts`, `ui/tools/{navigation,screen-mirror,proposal-view}.test.mjs`, `ui/tools/client-lint.mjs`, `Test/{SurfaceCoverage,ReadTool,ToolRoundTrip,ToolEmit,StageTwoTools,Prohibited,Descriptor,InteropDescriptor}.cls`, `scripts/ci-throwaway.sh`. Re-check each with `git log --no-merges origin/OCU-1-epic21 ^origin/feature/OCU-1_ocupilot-mvp -- <path>` before editing.

- **`Port/InteropPort.cls`** (sibling: default settings, extend the pattern): `ENDPOINTDEFAULTSETTINGS` :187, `DEFAULTSETTINGPAIRS`/`WRITEPAIR` :275-278, types :508-517, `ENTITYPARTNER` :731, verbs :767-771; `IsDefaultSettingWrite` :1060 and `IsAnyWrite` :1073; `Pairs` :1103, `Serves` :1163, `Invoke` :1275 (route like `InvokeDefaultSetting` :1329); `ListPartners` :7426 (partner check); `DefaultSettingWriteRefusal` :8111, `ReadDefaultSetting` :8126, `InvokeDefaultSetting` :8150, `PerformDefaultSetting` :8199; audit like `PerformPartner`'s `AuditRuntime` block :7843; `SnippetForm` :6294, `Snippet` :6321, `DefaultSettingSnippet` :8414.
- **Vendor:** `irislib/Ens/Config/Credentials.cls` (id `SystemName` :64; password in `^Ens.SecondaryData.Password` via `%SYS.Ensemble.SecondarySet`, which checks `%Ens_Credentials:W` itself, `irislib/%SYS/Ensemble.cls:517`; `%OnDelete` removes it; no audit); `irislib/EnsPortal/Credentials.cls` (`%Ens_Credentials:READ`/`WRITE` :13/:16).
- **`Api/InteropError.cls`:** codes `CREDENTIALTAKEN`, `NAME`, `PARTNER`, `VALUE`, consequences `CREDENTIALREMOVE`, `CREDENTIALCHANGE`, beside the default-setting block :436-470; a `CredentialCodes`/`CredentialPreconditionCodes` pair like :724/:732, joined into `Codes` :641, `ConsequenceCodes` :647, `PreconditionCodes` :806; `ReasonFor` :813.
- **Tools (new, `Screen/Tool/`):** `InteropCredentialAction` (abstract, like `InteropDefaultSettingAction`, `WRITERESOURCE` `%Ens_Credentials`), `InteropCredentialAdd` (`COMPOSEDSECRETS` as `WalletSecretCreate.cls:50`), `InteropCredentialUpdate` (`SCREENOPTIONAL` `edit=Username:BusinessPartner`), `InteropCredentialPassword` (as `TaskMailPassword.cls`: `WRITETYPE`, `SENDSBODY` 0, `SECRETBODY` `Password`, `SCREENACTIONS` `password`), `InteropCredentialRemove` (`DESTRUCTIVE`, `FINGERPRINTSUBJECT` with `Namespace`, as `InteropDefaultSettingRemove.cls:29`); the last two override `RefusedBeforeState` (hook `Screen/Tool/Write.cls:608`; mint caller `Kernel/Proposal/Mint.cls:247`; `Kernel/Proposal/Caller.cls:38`).
- **Kernel:** `Prohibited.cls` (append-only): code and reason beside `ALLOWLISTAGENT` :161/:165 and `PROVIDERSSL` :288/:292 (live read, failed read refuses: `ProviderSsl` :7053), `Codes()` :1245, `ReasonFor` :1253, `IsOwnNamespace` :3681; `TYPEINTEROPCREDENTIAL` beside `TYPEDEFAULTSETTING` :850, `COVEREDTYPES` :311, the condition term :1717, arms like Batch 1's in `PermittedChangeFields` :1445, create fields :1632, created arm :1928, `ReviewedFewOnly` :2222. `Kernel/State/Agent.cls`: new guarded reader beside `GuardedCredentialOwned` :430 (`Enabled` :145, `CredType` :78, `CredentialName` :88). `Kernel/EntityType.cls` :159 adds `interop-credential`; `Kernel/Governance/Baseline.cls` four keys after :325.
- **Save route (new):** `Area/Interop/CredentialSave.cls` extending `ItemSave` like `DefaultSettingSave.cls`; `POST /interop/credentials` in `Api/Router.cls` beside :299, handler beside :2117.
- **Descriptor (new):** `InteropCredentialList` (route `interoperability/credentials`, side bar 14, `list`, entity type `interop-credential`, primary `add`, rows `edit`, `password`, `remove`, `secretArguments` `["Password"]` as `TaskMailSettingList.cls:38`, `classicPage` `EnsPortal.Credentials`).
- **Client (`ui/src/app/`):** `areas/interoperability/interop-credential-{list.page,dialog,store}.ts` modeled on the default-setting files; partner select fed by the partner list (`interop-business-partner.store.ts:9`; select precedent `interop-item-change-class-dialog.ts:35`); password inputs as `shell/set-password-dialog.ts`, whose dialog the Set password action reuses (`screen-action-handler.ts` `VALUE_ACTIONS` :516, `submitPassword` :1427); `screen-outlet.ts` :279, `screen-actions.ts` :305, `screen-action-handler.ts` :150/:613/:813/:930; `core/strings.ts`; regenerate `screens.generated.ts` and `Screen/Titles.cls`.
- **Tests (new; principal legs armed by `OCUPILOT_ALLOW_PRINCIPALS`, `# classes:` lines in `scripts/ci-throwaway.sh` after :567):** `Test/InteropCredentialControl.cls` (both callers, round trip, read-back, audit, draft), `Test/InteropCredentialRefusals.cls` (matrix and gate as principals), `Test/InteropCredentialProvider.cls` (the five binding tests). Fixture: extend `Test/InteropLookupFixture.cls` (`PutDefault` :185, `DropDefaults` :275) with credential rows by marker; probe agent definitions as `Test/CredentialRepoint.cls`/`Test/AgentCredential.cls` make them. Browser: `ui/browser/interop-credentials.browser-spec.mjs`, sharing `interop-default-settings.browser-spec.mjs`'s helpers by import. `ui/tools/self-protection.test.mjs` :330 gains `['PROVIDERCREDENTIAL', <key>]`.
- **Rosters (Rule 30):** re-grep `default-setting`, `InteropDefaultSettingList` and `interop.defaultsettings` across `src/OcuPilot/Test`, `ui/tools`, `ui/browser`, `ui/src`; Batch 1's sweep reddened `ToolEmit`, `CompositeMintSweep`, `InteropMessageDescriptor`, `ToolWrite` (other-port count), `ToolDispatch`, plus `DraftRegistry`, `SaveHoldCoverage`, `Prohibited`, `GovernanceBaseline`.
- **EXPERIENCE.md:** one Fixed strings row after the table's last row, once the strings are ruled.

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0** (`ocupilot-b-ci`, USER and HSCUSTOM, every probe row and node removed after; record under Design Notes › Measured): (a) with auditing on, the vendor records no audit row for a save, a password set and a delete; (b) a principal holding `%Ens_Portal:USE`, `%Ens_Credentials:READ` and the database's READ lists rows; with `%Ens_Credentials:WRITE` and database WRITE it saves, sets a password and deletes; name any further pair, and the database `^Ens.SecondaryData.Password` maps to; (c) whether two names differing only in case can both be saved, and whether `%OpenId` resolves a name in another case (if it does, the provider match folds case); (d) `SystemName`'s length limit and what a control character answers; (e) the secondary node's state after an add with an empty password, a password set and a delete, fixing the `stored` test; (f) that `Kernel/Secret/Ladder.Credential` opens the row in the process's own namespace. HALT if a read writes, or if (a) finds a vendor row.
- [ ] `InteropPort.cls`, `InteropError.cls`: endpoint, gate, read, four writes, snippets, codes.
- [ ] The four tools, `CredentialSave.cls`, the route, descriptor, entity type, baseline keys, `Agent.cls` reader, `Prohibited.cls` additions.
- [ ] Client page, dialog, store, maps, strings, regenerated mirror and titles, EXPERIENCE.md row.
- [ ] Tests: the matrix in the three new classes, the browser spec, component specs, `self-protection.test.mjs`, every roster.

**Acceptance Criteria:**

- **AC1 (round trip, both callers).** Given the probe names, when a person adds, edits, sets a password on and removes a credential from the screen, and the agent's confirmed proposals do the same to another, then each reads back from `Ens.Config.Credentials` exactly as sent, the password reads stored, the removed row and its password are gone, and the read-back says `matches`.
- **AC2 (refusals and gate).** Given each refusal row of the matrix, when either caller writes, then the named code answers before any vendor call and the class is unchanged.
- **AC3 (no password anywhere).** Given a stored password, when the list, the agent's read, a proposal, a draft, the audit row and the read-back are produced, then no password value appears; the draft shows `<Password>`.
- **AC4 (provider self-protection; Integration, Rule 1).** Given an enabled `creds` agent definition naming a probe credential in the install namespace, when the agent proposes its remove or password change, then no proposal is stored and the answer is 403 `PROHIBITED.PROVIDERCREDENTIAL` with the ruled sentence; when a person removes it or sets its password on the screen, or the agent proposes a credential no enabled definition names, it proceeds; when the definition is changed to name another credential, the refusal follows it.
- **AC5 (browser).** Given a fresh instance, when a person adds, edits, sets the password of and removes a probe credential on the screen, then the list shows each change and never a password.
- **AC6 (fresh, either order).** Given any new or changed test, run first on a fresh instance in either order, when it ends, then no probe credential, password node or probe agent definition remains.

## Spec Change Log

## Review Triage Log

## Design Notes

**Veto items (recommended option first).**

1. **The self-protection refusal sentence** (Proposed string, the orchestrator rules it): "An enabled agent definition reads its provider key from this credential, so it is removed or given a new password on the Credentials screen alone." Caller-neutral, as `ALLOWLISTAGENTREASON`.
2. **Namespace scope of the refusal.** Recommended: only in the process's own namespace, where the `creds` rung opens the row (Task 0 (f)); a same-named credential elsewhere is not the provider's. Alternative: every namespace, which refuses with a sentence that is untrue there.
3. **An add whose name differs only in case from an existing one is refused** (stricter than the classic page, which compares exactly), since the vendor's adapters resolve names ignoring case (`Credentials.cls:120`).
4. **The business partner is empty or an existing partner** (stricter than the vendor's free text); the dialog offers the namespace's partners.
5. **No source-control refusal** (looser than the family, equal to the classic page and vendor).
6. **The stored test reads the vendor's secondary node** (`^Ens.SecondaryData.Password`, existence and non-empty length) rather than calling a vendor method, because every vendor method that answers it returns the password.
7. **Proposed strings** (reused: "Name", "User name", "Password", "Set password", "None", "Stored"; the remove consequence "Anything that names this credential can no longer use it. This cannot be undone." from EXPERIENCE.md :490):
   - Labels and fields: "Credentials" · "Business partner" · "Not stored" · "New credential" · "Edit <name>" · "Remove <name>".
   - Help: "Production settings name a credential to sign in to other systems. Its password is never shown here."
   - Consequence (`CHANGE`, edit and password): "Anything that signs in with this credential uses the change from its next connection."
   - Refusals: `TAKEN` "This namespace already has a credential with that name, in some letter case." · `NAME` "A credential name is 1 to 50 characters and holds no control characters." (50 if Task 0 (d) measures it) · `PARTNER` "This namespace has no business partner with that name." · `VALUE` "The instance did not accept this user name."
   - Empty state: "This namespace has no credentials." (agent phrase "add a credential").
   - Prompts: "Which credentials does this namespace hold?" · "Which credentials have no password stored?" · "Add a credential for a business partner."

**Proposed spine lines (the orchestrator's update; never written here).** AD-10: "**The provider's credential** (Story 24.15): the agent's remove or password change of an `Ens.Config.Credentials` row that an enabled `creds` agent definition names, in the process's own namespace, is refused `PROHIBITED.PROVIDERCREDENTIAL` when proposed; the screen is not refused; a failed read refuses." AD-62: "Credentials (Story 24.15): `InteropPort` gains `Credentials` behind `%Ens_Credentials`; the password is never read, only whether one is stored." AD-15: the named `ConfigChange` case. AD-22: the four keys.

**Decided in-stage (plan).**

1. The refusal sits in the tools' `RefusedBeforeState`, gated by `Caller.IsTurn()`: the mint calls it before storing anything (no card), and the screen route calls it in no turn, so one hook serves "agent refused, screen open". `Prohibits` (run at confirm and on screen saves for both callers) gains no provider term; per the binding condition the check is made when proposed, so a definition changed between proposal and confirm is not re-checked.
2. A failed read of the definitions refuses, as `PROVIDERSSL`.
3. Disabled definitions do not count; the binding names enabled ones.
4. No harvest: no plan exists for the MCP suite's `CredentialManage`, and AD-62 confines the vendor calls to `InteropPort` (AD-23 not engaged).
5. Side-bar position 14, after Compare default settings.

**Governing ADs (Rule 6):** AD-3, AD-4, AD-5, AD-6, AD-8, AD-10, AD-13, AD-14, AD-15, AD-16, AD-22, AD-29, AD-34, AD-35, AD-36, AD-44, AD-51, AD-52, AD-53, AD-54, AD-55, AD-56, AD-58, AD-59, AD-60, AD-62. Not engaged: AD-21, AD-23, AD-63, AD-65, AD-66.

**Integration and linkage (Rules 1, 2, 31).** Integration: AC4 (the mint consumes the stored agent definitions) and AC1's agent leg. Consumes: `InteropPort` (`Admit`, `AuditRuntime`, `ListPartners`, Batch 1's write pattern), `ItemSave`, `Agent`'s guarded reads, the kernel's proposal, confirm, governance and audit, `InteropLookupFixture`. Consumed-by: Batch 3 reuses the family; Story 24.20's undo snapshots these writes (it never snapshots a password). Extends, not copies: `InteropDefaultSetting*` (tools, save), `GuardedCredentialOwned` (reader), `set-password-dialog.ts`.

**Ledger inbox (Rule 17; `owned_ledger=1`).** DW-2827 is declined here: the orchestrator scheduled it as Batch 1b, before this batch; this batch's own remove and password tools carry `Namespace` from the start.

## Verification

**Commands** (one `ci-runner` call per message; `ocupilot-b-ci` only):

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.InteropCredentialControl`, then likewise `InteropCredentialRefusals`, `InteropCredentialProvider`, `DraftRegistry`, `Prohibited`, `GovernanceBaseline`, `InteropDefaultSettingControl`, and every class the roster sweep changes. Expected: green; new classes green on their first run.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/interop-credentials.browser-spec.mjs browser/interop-default-settings.browser-spec.mjs`. Expected: green.
- `(once)` The full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17` for k = 1 to 17, one call each. Expected: green. The full browser suite is left to CI.
- `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`. Expected: clean.

**Shared surfaces:** the Interoperability side bar; the entity-type vocabulary; the governance baseline; `COVEREDTYPES` and `Prohibited.Codes()`; the read-tool, coverage, endpoint, draft and other-port write rosters; `InteropError`'s code lists; `screen-mirror.test.mjs`; `self-protection.test.mjs`; the arming roster; USER's and HSCUSTOM's credentials; the agent definitions.

**Hermeticity:** every test added or changed passes on its first run on a fresh instance, in either order; it asserts on its own probe rows by marker and removes them, its password nodes and its probe agent definitions.

**Mutations** (each AC's pinning test, and each binding test, shown red, reverted byte-identical, recorded here as `mutation: <change> -> <test>`; the planned ones):

- mutation: AC1, `PerformCredential` drops `BusinessPartner` on a set -> `InteropCredentialControl` round-trip test red.
- mutation: AC2, the add's case-folded taken test compares exactly -> `InteropCredentialRefusals` taken test red.
- mutation: AC3, the password snippet renders the stored argument -> `DraftRegistry.TestNoSecretReachesAnyRenderedScript` red.
- mutation: binding 1, `InteropCredentialRemove.RefusedBeforeState` answers 0 -> `InteropCredentialProvider` agent-remove test red.
- mutation: binding 2, `InteropCredentialPassword.RefusedBeforeState` answers 0 -> agent-password test red.
- mutation: binding 3, drop the `Caller.IsTurn()` condition -> screen-allowed test red.
- mutation: binding 4, the provider method answers 1 for any name -> unnamed-credential test red.
- mutation: binding 5, the provider method reads a value captured once per process -> renamed-provider test red.
- mutation: AC5, the page's Set password sends no password (bundle rebuilt and redeployed) -> browser spec red on `stored`.
- mutation: AC6, the fixture's credential drop removes nothing -> `InteropCredentialControl` red on its `none survives` leg.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

**Plan.** Batch 2 of three: Credentials (list, add, edit, set password, remove) through `InteropPort`, with the agent's remove and password change of an enabled agent definition's credential refused when proposed (the orchestrator's binding conditions, copied under Boundaries). Veto items: Design Notes 1 to 7, the refusal sentence first. Epic context reused as committed (orchestrator instruction); the 24.15 block, the EXPERIENCE.md rows, AD-10, AD-35, AD-56, AD-59 and AD-62 were read at their current commits. Read-only probes on `ocupilot-b-ci` (identity checked, 52777): USER holds no credentials; `Ens.Config.Credentials` declares `SystemName` with the default length, `Username` 3640873, `BusinessPartner` 255. Nothing was written to the instance; no scratch class or row was left.

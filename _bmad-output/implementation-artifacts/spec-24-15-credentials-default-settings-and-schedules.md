---
title: 'Story 24.15: Credentials, default settings and schedules (Batch 1: system default settings and their comparison)'
type: 'feature'
created: '2026-11-21'
status: 'ready-for-dev'
baseline_revision: '928133ddf3c06d0cd34ded2089103b8707815383'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-3-interoperability-parity.md'
warnings: ['oversized', 'multiple-goals']
deferred: []
---

<intent-contract>

## Intent

**Problem:** OcuPilot has no screen or tool for an interoperability namespace's credentials (`Ens.Config.Credentials`), system default settings (`Ens.Config.DefaultSettings`) or schedule specs (`Ens.Util.Schedule`); the classic `EnsPortal.Credentials`, `EnsPortal.DefaultSettings`/`DefaultSetting` and `EnsPortal.ScheduleEditor` pages are the only way. Compare namespaces (Story 24.8) cannot show which default settings differ between two namespaces (DW-2636, catalog DT-09).

**Approach:** Three surfaces, built in three batches (Design Notes › Questions 1); this spec is Batch 1. Interoperability gains **System default settings**: a list read through `InteropPort`, with add, edit and remove, each one operation reached by the screen and by the agent. It also gains **Compare default settings**, a read-only list of the settings that differ between the route's namespace and another, read through the same port in each namespace (DW-2636). "Round-trips over its backing class" means: a setting added or edited from either caller reads back from `Ens.Config.DefaultSettings` exactly as sent, and a removed one is gone from it.

## Boundaries & Constraints

**Always:**

- **One port (AD-62).** `InteropPort` gains `DefaultSettings` (`LIST`, `DEFAULTSETTING`, `ADDDEFAULT`, `SETDEFAULT`, `REMOVEDEFAULT`) and `DefaultSettingsDiff` (`LIST`, criterion `target`). It calls `Ens.Config.DefaultSettings` (`%New`, `%OpenId` at concurrency 4, `%Save`, `%DeleteId`, SQL read with `%ExecDirectNoPriv` after the gate) switched, with no `OcuPilot.*` call while switched.
- **Rows.** `{Production, Item, HostClass, Setting, Value, Description, Deployable, Secret, Namespace}`; id composite `[Production, Item, HostClass, Setting]`, each part kept exactly; capped, truncation reported (AD-36). A setting whose name `Kernel/Audit/Log.IsCredentialName` matches reads `Value` empty and `Secret` true (AD-35, as `SettingRow`).
- **Gate (AD-29, AD-8), before any vendor call.** Read: `%Ens_Portal:USE`, `%Ens_SystemDefaultConfig:READ`, then `Admit` (interoperability, globals-database READ). Write: `%Ens_SystemDefaultConfig:WRITE` and globals-database WRITE. The classic page's per-setting rules, evaluated at call time and never cached:
  - `Enabled` also needs `%Ens_ConfigItemRun:USE`;
  - a holder of `%Ens_RestrictedUI_SystemDefaultSettings:USE` without the `%All` role writes only a setting named `N` for which they hold `%Ens_SystemDefaultSettings_N:USE`, and never the setting `*`.
- **Write refusals by name, before any vendor call:** a source-controlled namespace; a secret-named setting; a key part empty, over 255 characters, holding a control character or `||`; a value or description over 2,000; an add whose key exists; an edit or remove whose key is absent (404); a value the vendor's `%OnValidateObject` refuses (its text logged, never shown).
- **Edit** changes `Value`, `Description` and `Deployable` only; it sends the fields the person changed (`SCREENOPTIONAL`) and the port keeps the rest. The key never changes: a different key is a remove and an add.
- **Compare.** Both namespaces pass the read gate and report interoperability (else 409 `INTEROP.NAMESPACE` naming the one refused). Keyed by the exact composite; `Change` is only here, only there, or differs (any of `Value`, `Description`, `Deployable`). Rows show `Value` and `OtherValue`; a secret-named setting shows neither and still compares. A side over the cap refuses `INTEROP.DEFAULTSETTING.TOOMANY` naming its namespace. Identical settings are not listed.
- **Write path (AD-3, AD-6, AD-34, AD-51 to AD-55, AD-58, AD-59, AD-14, AD-10, AD-22).** Three tools `interop.defaultsettings.add|update|remove` over one fresh read; the add is a create (AD-54); read-back through the update's read; a script form for each (`SnippetForm`/`Snippet`); keys `add` and `update` `true`, `remove` `false` (destructive). A screen action mints nothing and is not gated by read-only or the kill switch.
- **Audit (AD-15).** The agent's marker on every agent write; the vendor's own default-setting event if Task 0 measures it recorded, else OcuPilot's own `ConfigChange` from either caller (a named case).

**Never:**

- `%Api.InteropEditors`; the harvested `DefaultSettingsManage`/`DefaultSettingsList` bodies (Design Notes); `EnsPortal.*` methods, whose checks cache in `%session`.
- A value of a secret-named setting in any row, proposal, diff, draft, audit payload or log.
- Credentials and schedules (Batches 2 and 3); import or export of default settings; any change to `NamespaceDiff`, promote, or Compare namespaces.
- `src/OcuPilot/Api/Error.cls` (frozen); `ui/angular.json`; `ui/vitest-base.config.mjs`; `scripts/ci-throwaway.sh` beyond add-only roster lines; a logic edit in `Kernel/Proposal/Prohibited.cls` beyond the appended terms in Code Map; a spine edit.

## I/O & Edge-Case Matrix

USER on `ocupilot-b-ci`; the compare also HSCUSTOM. Probe rows use production `OcuProbe2415.Production` (never compiled) and are removed after.

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Add, both callers | Key `[OcuProbe2415.Production, *, *, ArchiveIO]`, value `1`, description, Deployable true | Row reads back exactly; read-back `matches` | - |
| Edit | Change Value only, from the screen | Value changed; Description and Deployable kept | - |
| Remove | The probe row | Gone from the class; card is destructive | - |
| Taken / absent | Add an existing key; edit or remove a missing one | Refused | 409 `INTEROP.DEFAULTSETTING.TAKEN`; 404 |
| Secret | Setting `SSLPassword`; a stored one listed | Write refused; row `Value` empty, `Secret` true | 409 `INTEROP.DEFAULTSETTING.SECRET` |
| Invalid | Setting `PoolSize` value `0`; a part with `\|\|`; 256 characters | Refused | 422 `INTEROP.DEFAULTSETTING.VALUE`; 422 `INTEROP.DEFAULTSETTING.KEY` |
| Gate | No `%Ens_SystemDefaultConfig:WRITE`; `Enabled` without `%Ens_ConfigItemRun:USE`; restricted UI without the setting's resource, or `*` | Refused before any vendor call | 403; 403 `INTEROP.DEFAULTSETTING.RESTRICTED` |
| Source control | A namespace the port reads as source-controlled | Every write refused | 409 `INTEROP.DEFAULTSETTING.SOURCECONTROL` |
| Compare | One probe row only in USER, one only in HSCUSTOM, one in both with different values, one identical | Three rows, the identical one absent | - |
| Compare refusals | `target` the same namespace, unknown, `%SYS`; the caller lacks the read pair in `target` | Refused before any vendor call | 400; the port's existing unknown-namespace answer; 409 `INTEROP.NAMESPACE`; 403 |

</intent-contract>

## Code Map

Paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-24` (HEAD `928133ddf`). **Contention:** at plan time Epic 21 has changed none of these files beyond feature. The implement stage re-runs `git log --no-merges origin/OCU-1-epic21 ^origin/feature/OCU-1_ocupilot-mvp -- <path>` for each, and treats every shared roster below as (contended: add-only). `Kernel/Proposal/Prohibited.cls` is (contended: add-only) always.

- **`Port/InteropPort.cls`** (sibling: business partners, Story 20.26):
  - declarations beside `ENDPOINTBUSINESSPARTNERS` :183, `PARTNERWRITEPAIR` :261, `TYPEADDPARTNER` :470, `PARTNERCODEPREFIX` :675, audit names :690-707;
  - `IsAnyWrite` :996 gains the family; `Pairs` :1026, `Serves` :1083, `Invoke` :1193 (route like `InvokePartner` :1243/:7632);
  - fresh read like `ReadPartner` :7608 (source control at :7611, `SourceControlled` :1634); write like `PerformPartner` :7673 (namespace switch, concurrency-4 open, changed fields only, outcome mapping :7749, `AuditRuntime` :6196);
  - list like `ListPartners` :7337; the secret rule as `SettingRow` :3211; refusal helpers `Conflict` :3533, `Absent` :3546;
  - `SnippetForm` :6208 and `Snippet` :6234 gain the three types, like `PartnerSnippet` :8114.
- **`Api/InteropError.cls`:** codes `DEFAULTSETTINGTAKEN`, `SECRET`, `KEY`, `VALUE`, `RESTRICTED`, `SOURCECONTROL`, `REMOVE` (consequence), `TOOMANY`, with reasons, beside the partner codes :405-431; their lists like `PartnerCodes`/`PartnerPreconditionCodes` :670/:677, joined into `Codes` :602, `ConsequenceCodes` :608, `PreconditionCodes` :751; `ReasonFor` :758.
- **Tools (new, `Screen/Tool/`):** `InteropDefaultSettingAction` (abstract, like `InteropPartnerAction`), `InteropDefaultSettingAdd`, `InteropDefaultSettingUpdate`, `InteropDefaultSettingRemove`, extending `InteropAction`; `WRITERESOURCE` `%Ens_SystemDefaultConfig`.
- **Save route (new):** `Area/Interop/DefaultSettingSave.cls` extending `ItemSave` (like `PartnerSave.cls`), `POST /interop/default-settings` in `Api/Router.cls` beside :298 and its handler beside :2107.
- **Descriptors (new):** `InteropDefaultSettingList` (route `interoperability/default-settings`, side bar 12, `list`, entity type `default-setting`, primary `add`, rows `edit`, `remove`, `classicPage` `EnsPortal.DefaultSettings`) and `InteropDefaultSettingDiff` (route `interoperability/default-settings-diff`, side bar 13, `list (server criteria)`, criterion `target`, no actions, no `classicPage` with an exemption: no classic page compares).
- **Kernel:** `Kernel/EntityType.cls` :156 adds `default-setting`; `Kernel/Governance/Baseline.cls` the three keys after :322; `Kernel/Proposal/Prohibited.cls` (contended: add-only): `TYPEDEFAULTSETTING` beside :845, appended to `COVEREDTYPES` :311, one term in the :1708 condition, one arm each in `PermittedChangeFields` :1398 (`Value,Description,Deployable`) and the create fields beside :1622; AD-10 names no effect, so the reviewed-few sweep only.
- **Client (`ui/src/app/`):** `areas/interoperability/interop-default-setting-{list.page,dialog,store}.ts` modeled on the partner files; the compare has no page of its own: the `list (server criteria)` archetype page (`screen-outlet.ts` :56) draws its `target` text criterion; `shell/screen-outlet.ts` `DESCRIPTOR_PAGES` beside :276; `core/screen-actions.ts` beside :298; `shell/screen-action-handler.ts` beside :583/:804; `core/strings.ts` once ruled; `core/screens.generated.ts` and `Screen/Titles.cls` regenerated.
- **Tests (new, armed by `OCUPILOT_ALLOW_PRINCIPALS`, roster lines in `scripts/ci-throwaway.sh` :550-561 and `ui/tools/ci.test.mjs`):** `Test/InteropDefaultSettingControl.cls` (both callers, round trip, read-back, audit, draft), `Test/InteropDefaultSettingRefusals.cls` (matrix refusals and the gate as principals), `Test/InteropDefaultSettingDiff.cls` (compare, both namespaces). Fixture: extend `Test/InteropLookupFixture.cls` (`PutPartner` :207, `Clear` :144) with default-setting rows by marker; `ProductionProbe.PutDefault` :317 is the vendor-call precedent. Browser: `ui/browser/interop-default-settings.browser-spec.mjs`, sharing `interop-business-partners.browser-spec.mjs`'s helpers by import.
- **Rosters (Rule 30):** `Test/{SurfaceCoverage,EndpointCoverage,Descriptor,ReadTool,ToolRoundTrip,StageTwoTools,Governance,GovernanceBaseline,InteropFloor,SaveHoldCoverage,Navigation,Prohibited,DraftRegistry}.cls`, `ui/tools/{screen-mirror,navigation,name-links,interop}.test.mjs`; re-grep `business-partner`, `InteropBusinessPartnerList` and `interop.businesspartners` for each.
- **EXPERIENCE.md:** one Fixed strings row after :608, once the strings are ruled.

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0** (`ocupilot-b-ci`, USER, every probe row removed after; record under Design Notes › Measured): (a) with auditing on, whether the vendor records an audit row for an insert, update and delete, and whether its `EventData` carries a value; (b) a least-privileged principal (`%Ens_Portal:USE`, `%Ens_SystemDefaultConfig:READ`, `%DB_USER:R`) reads the rows, and with `WRITE` saves one: name any further pair the vendor needs; (c) a key that differs only in letter case is a second row, and `%GetSetting` matches exactly; (d) `PoolSize` `0` and a non-integer for an integer setting fail `%Save`; (e) that a running probe production picks up a saved default only once it is updated, which the add and edit consequence states; HALT if it measures otherwise, or if a read writes.
- [ ] `InteropPort.cls`, `InteropError.cls`: endpoints, reads, writes, snippets, codes.
- [ ] The three tools, `DefaultSettingSave.cls`, the route, both descriptors, entity type, baseline keys, `Prohibited.cls` terms.
- [ ] Client page, dialog, store, maps, strings, regenerated mirror and titles, EXPERIENCE.md row.
- [ ] Tests: the matrix in the three new classes, the browser spec, component specs, and every roster.

**Acceptance Criteria:**

- **AC1 (round trip, both callers).** Given the probe key, when a person adds it from the dialog and edits its value, and the agent's confirmed proposals add, edit and remove another, then each reads back from `Ens.Config.DefaultSettings` exactly as sent, the removed one is absent, and the read-back says `matches`.
- **AC2 (refusals and gate).** Given each refusal row of the matrix, when either caller writes, then the named code answers before any vendor call and the class is unchanged.
- **AC3 (secrets).** Given a stored secret-named setting, when the list, the agent's read, the compare and a draft run, then no value appears, and a write to it is refused.
- **AC4 (compare; Integration, Rule 1).** Given probe rows in USER and HSCUSTOM, when Compare default settings runs from the screen and through its derived read tool, then it lists exactly the only-here, only-there and differing rows (DW-2636).
- **AC5 (browser).** Given a fresh instance, when a person adds, edits and removes a probe default setting on the screen and opens Compare default settings for HSCUSTOM, then the list and the compare show each change.
- **AC6 (fresh, either order).** Given any new or changed test, run first on a fresh instance in either order, when it ends, then no probe default setting remains in either namespace.

## Spec Change Log

- 2026-11-21, spec gate (runner, veto item U-135): Question 1 three batches kept; Question 2 the separate Compare default settings screen kept; Question 3 ruled the stricter option for Batch 2 (refuse the agent's remove or password change of the credential the provider configuration names; the screen is not refused), since the agent must not disable itself; Question 4 the audit masking kept in Batch 1 with its proposed AD-35 line; Question 5 the proposed strings kept.

## Review Triage Log

## Design Notes

**Questions for the runner (intent gap; veto items).**

1. **Batches (Rule 5 tier 2).** Three catalog rows (IO-32, IO-33, IO-43), each with its own writes. Recommended: three batches, each planned after the previous code head lands.
   - **Batch 1 (this spec):** default settings and DW-2636.
   - **Batch 2, credentials:** list (Name, Username, Business partner; the password never read, shown as stored or not); add (name, username, partner, password typed at confirm or in the dialog, a composed secret as `WalletSecretCreate`); edit username and partner; set password (secret-only, as `TaskMailPassword`); remove (destructive, key `false`). Pairs `%Ens_Credentials:READ`/`WRITE`. The vendor audits nothing, so OcuPilot records `ConfigChange`.
   - **Batch 3, schedules:** list (Name, Description, Spec, Deployable); add, edit, remove. The spec is checked by `Ens.ScheduleHandler.ParseScheduleSpec` before saving; the vendor's save tells a running production that uses the schedule. Pairs `%Ens_ProductionConfig:READ`/`WRITE` (stricter than classic, whose delete needs READ only). No vendor audit, so `ConfigChange`. Source control as the classic `.SDD` document.
2. **DW-2636's shape.** Recommended: Compare default settings, a separate read-only Interoperability screen (above). `InteropPort` stays the only reader (AD-62), rows show values, and Compare namespaces and promote (Story 24.9 reads `NamespaceDiff`'s rows) are untouched. Alternative: a `kind` criterion on Compare namespaces, which changes its pinned criteria and its row shape.
3. **The credential the agent's provider uses (decided now for Batch 2; veto: security posture).** The `creds` rung (`Kernel/Secret/Ladder.cls`) reads an `Ens.Config.Credentials` row. Recommended: no new prohibited effect, as for the wallet rung's secret; a removed or changed credential makes the provider answer not configured. Alternative (stricter): refuse the agent's remove or password change of the credential the provider configuration names.
4. **The vendor's audit rows for a secret-named default setting (AD-35).** `Ens.Util.Auditing.AuditModifyDefaultSetting` (:213) writes `SettingValue`'s new and old values in plain text. OcuPilot never writes one (AC3), but Logs › Audit shows rows the classic page made. Recommended: Batch 1 adds the declaration (that event's value lines, when its `SettingName` line matches the credential pattern, masked on both audit paths), measured in Task 0, with the spine line proposed below. Alternative: a ledger entry for a later story.
5. **Proposed strings (veto).** Reused where a sentence already exists (Name, Description, Value, Setting, Edit, Remove, the confirm dialog's typed name).
   - Labels: "System default settings" · "Compare default settings".
   - Columns and fields: "Production" · "Item" · "Host class" · "Setting" · "Value" · "Deployable" · "Change" · "Value here" · "Value there" · "Other namespace".
   - Actions and dialog titles: "New default setting" · "Edit <setting>" · "Remove <setting>".
   - Help: "A system default setting gives a setting its value in every production, item and host class it matches, unless the production sets its own value. Use * to match any." · "Deployable settings are exported with a production's deployment package."
   - Consequences: `REMOVE`: "Items that took this value use their own setting or the class default again, and it cannot be restored from OcuPilot." Add and edit: "A running production uses the new value once it is updated." (Task 0 (e) confirms it).
   - Refusals: `TAKEN` "This namespace already has a default setting for that production, item, host class and setting." · `SECRET` "This setting names a credential, so OcuPilot neither shows nor sets its value. Set it in the classic System Default Settings page." · `KEY` "Production, item, host class and setting are each 1 to 255 characters, may be * for any, and may not contain two vertical bars." · `VALUE` "This value is not valid for that setting." · `RESTRICTED` "You may not change the default for this setting." · `SOURCECONTROL` "This namespace uses source control, so change default settings in the classic System Default Settings page." · `TOOMANY` "One of these namespaces has more default settings than one comparison covers."
   - Empty states: "This namespace has no system default settings." (agent phrase "add a default setting") · "These two namespaces have the same default settings." (no agent phrase).
   - Prompts, list: "Which default settings apply to this production?" · "Explain what this default setting changes." · "Add a default setting for an item's pool size." Compare: "Summarize how these namespaces' default settings differ." · "Which differing settings would change how a production runs?" · "Which settings exist in only one namespace?"

**Proposed spine lines (the owner's attended update; never written here).** AD-62: "System default settings (Story 24.15): `InteropPort` gains `DefaultSettings` and `DefaultSettingsDiff` over `Ens.Config.DefaultSettings`, behind `%Ens_SystemDefaultConfig` and the classic page's `Enabled` and restricted-UI rules, evaluated at the call; a secret-named setting is never read or written." AD-22: the three keys. AD-15 (if Task 0 (a) finds no vendor row): the named case. AD-35 (if Question 4 is ruled in): the declaration.

**Decided in-stage (plan).**

1. **The harvest seam is not engaged** (AD-23, Rules 2 and 31): `DefaultSettingsManage` sets no description and types the composite id as a number (inference), and AD-62 confines interoperability configuration to `InteropPort`; 24.3's precedent.
2. **The per-setting rules are re-stated in the port, not called**: the classic `canEditAllSettings`/`canEditSettingName` cache their answer in `%session`, which AD-8 forbids.
3. **Source control refuses every write**, as for partners and lookups, though the classic page does not check it.
4. **Side-bar positions 12 and 13**, after Messages.
5. **The compare's `target` is a text criterion** drawn by the archetype page, as the agent's tool sees it; no client page is added or extended for it.
6. **Both namespaces must report interoperability** for the compare, rather than reading a namespace without it as having no settings, so a refusal is never shown as a difference.

**Governing ADs (Rule 6):** AD-3, AD-4, AD-5, AD-6, AD-8, AD-10, AD-13, AD-14, AD-15, AD-16, AD-22, AD-29, AD-34, AD-35, AD-36, AD-44, AD-51, AD-52, AD-53, AD-54, AD-55, AD-56 (ii), AD-58, AD-59, AD-60, AD-62. Checked and not engaged: AD-23 (above), AD-21 (no path; key parts bound), AD-63, AD-65, AD-66.

**Integration and linkage (Rules 1, 2).**

- **Integration:** AC4 (Compare default settings consumes the `DefaultSettings` read per namespace) and AC1's agent leg.
- **Consumes:** `InteropPort` (`Admit`, `AuditRuntime`, partner write pattern), `ItemSave`, the kernel's proposal, confirm, governance and audit; `InteropLookupFixture`.
- **Consumed-by:** Batch 2 and Batch 3 reuse the family's tool, save and fixture pattern; Story 24.20's undo snapshots these writes.

**Ledger inbox (Rule 17; `owned_ledger=1`).** DW-2636 is folded into Batch 1 (AC4); the runner closes it `resolved-by` at this batch's adjudication.

## Verification

**Commands** (one `ci-runner` call per message; `ocupilot-b-ci` only):

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.InteropDefaultSettingControl`, then likewise `InteropDefaultSettingRefusals`, `InteropDefaultSettingDiff`, `DraftRegistry`, `Prohibited`, `GovernanceBaseline`, `InteropPartnerControl` and every class the roster sweep changes. Expected: green; new classes green on their first run.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/interop-default-settings.browser-spec.mjs browser/interop-business-partners.browser-spec.mjs`. Expected: green.
- `(once)` The full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17` for k = 1 to 17, one call each. Expected: green. The full browser suite is left to CI.
- `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`. Expected: clean.

**Shared surfaces:** the Interoperability side bar; the entity-type vocabulary; the governance baseline; `COVEREDTYPES`; the read-tool, coverage, endpoint and draft rosters; `InteropError`'s code lists; `screen-mirror.test.mjs`; the arming roster; USER's and HSCUSTOM's default settings.

**Hermeticity:** every test added or changed passes on its first run on a fresh instance, in either order; it asserts on its own probe rows by marker, never on a namespace's whole table, and removes them.

**Mutations:** each AC's pinning test is shown red against a named mutation, reverted, and recorded here as `mutation: <change> -> <test>`.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

**Plan.** Batch 1 of three (Questions 1): System default settings (list, add, edit, remove through `InteropPort`) and Compare default settings (DW-2636, folded in as AC4). Veto items for the spec gate: Questions 1 to 5 (batches, DW-2636's shape, the provider's credential, the vendor's audit rows for secret-named settings, the proposed strings). Read-only probes on `ocupilot-b-ci` only: the three vendor classes exist; USER and HSCUSTOM report interoperability; `%Ens_SystemDefaultConfig` and `%Ens_Credentials` exist. Nothing was written to the instance.

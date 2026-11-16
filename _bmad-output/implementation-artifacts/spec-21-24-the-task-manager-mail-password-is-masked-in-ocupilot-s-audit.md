---
title: "Story 21.24: The Task Manager mail password is masked in OcuPilot's audit read"
type: 'bugfix'
created: '2026-11-15'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** `%SYS.Task.Config.AuthPassSet` writes the Task Manager mail password, Base64-encoded, as the `Old value` and `New value` of a `%System/%System/ConfigurationChange` audit row described "Modify Task Config.MailAuthPassword". OcuPilot's audit read returns that row unmasked (DW-2625, measured on `ocupilot-ci`), which breaks AD-35.

**Approach:** Add one declaration to `AuditPort` for that row. The row has no `<key> modified:` header, so the existing grammar cannot express it, and the smallest extension is a fourth declaration family whose matched rows have every `Old value` and `New value` line masked. `Screen.Read.Execute` already runs `MaskVendorSecrets` for both the screen and the read tool, so no caller changes.

## Boundaries & Constraints

**Always:**

- The mask is declared per vendor event, by source and description, and is never a pattern over free text (AD-35, Conventions › Secrets).
- An empty value stays empty. The audit database keeps what the vendor wrote.
- Tests use probe values only. They restore `MailAuthPassword`'s prior stored value through `GetData` and `UpdateData` after every method.

**Never:**

- No AD or spine edit, no new user-facing string, and no edit to `Screen/Read.cls`.
- No write to `ocupilot` or any slot instance. The mail password is set on `ocupilot-ci` only.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Set | `AuthPassSet(p1)` from empty | Row reads `Old value:` (empty, unchanged) and `New value: *****` on both paths; the database row holds `Base64(p1)` | none |
| Change | `p1` stored, then `AuthPassSet(p2)` | Both lines read `*****`; neither Base64 value appears in either answer | none |
| Clear | `p2` stored, then `AuthPassSet("")` | `Old value: *****`; `New value:` stays empty | none |
| Other Task Config row | "Modify Task Config.MailServer" | Unchanged | none |
| Same text, other event | the declared description under `%System/%Security/SystemChange` | Unchanged | none |

</intent-contract>

## Code Map

- `src/OcuPilot/Port/AuditPort.cls:106-150` -- the three declaration families (`VENDORSECRETS`, `VENDORSYSTEMSECRETS`, `VENDORSETTINGSECRETS`) and their `*SOURCE` parameters. Epic 24 has not touched this file.
- `src/OcuPilot/Port/AuditPort.cls:159-172` -- `MaskVendorSecrets`, the one hook. `:177-195` `SecretKeys` and `:271-286` `SettingKeys` repeat the same longest whole-word description match. `:201-226` `MaskedEventData` masks `Old value`/`New value` lines only after a header. `:232` `MaskedAfter` leaves an empty value alone.
- `src/OcuPilot/Screen/Read.cls:858` -- calls `MaskVendorSecrets` on every `Security.Audit.Record` answer before projection. Read-only for this story.
- `src/OcuPilot/Screen/Tool/Read.cls:281,315` -- the `logs.audit.read` tool's `View` calls `Screen.Read.Execute`, which is the same hook (code read; the tests measure it). `Screen/Tool/Registry.cls:712` `InvokeTool` is the agent's one call into a tool.
- `src/OcuPilot/Test/AuditVendorSecrets.cls` -- the model test. `ReadScreen`, `ReadTool`, `Named`, `Present` and `Row` are reusable class methods. `VendorCarries` (:272) hard-codes the OAuth2 event.
- `irissys/%SYS/Task/Config.cls:43-63,98-104,181` -- `UpdateData` writes `"  Old value: <old>" CRLF "  New value: <new>"` only when the value changed; `AuthPassSet` Base64-encodes a non-empty password; `EmailSet("AuthPassword")` routes to it.
- `scripts/ci-throwaway.sh:870-878` -- the `OCUPILOT_ALLOW_CONFIG_SETTINGS` block and its `# classes:` roster, which `ui/tools/ci.test.mjs` holds equal to the classes declaring the variable.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Port/AuditPort.cls` -- add `VENDORCONFIGSECRETS = "Modify Task Config.MailAuthPassword"` (semicolon-separated `<event>` entries whose rows carry only the named setting's secret on their value lines) and `VENDORCONFIGSOURCE = "%System/%System/ConfigurationChange"`. Extract the description match into a private `DeclaredEntry(pDescription, pDeclared)` that `SecretKeys`, `SettingKeys` and a new `ConfigSecret(pRow) As %Boolean` share. Give `MaskedEventData` an optional `pEveryValue As %Boolean = 0` that masks every `Old value`/`New value` line without a header. In `MaskVendorSecrets`, a `ConfigSecret` row goes through `MaskedEventData(data, "", 1)`. Update the doc comments of `MaskVendorSecrets` and `MaskedEventData` to state the fourth family -- the declaration, and the set/change/clear masking.
- `src/OcuPilot/Test/AuditVendorSecrets.cls` -- `VendorCarries` gains an optional `pEvent = "%System/%Security/OAuth2"` (`<source>/<type>/<name>`), bound as `?` parameters -- so the new class can reuse it.
- `src/OcuPilot/Test/TaskMailAuditMask.cls` -- new, armed by `OCUPILOT_ALLOW_CONFIG_SETTINGS`. It reuses `AuditVendorSecrets`' class methods. Methods: the declaration pin; a synthetic mask-alone test (the matrix's last three rows plus empty values); and set, change and clear, one method each. Each method arms any preparatory set first, waits 1.1 s, and only then takes its own since-time, so the method reads exactly one declared row. Each asserts `VendorCarries` sees the Base64 value, both answers omit it, and the value lines read the mask or stay empty. `OnBeforeAllTests` refuses unarmed, then stores `GetData("MailAuthPassword")` in `%SYS` (namespace saved and restored). `OnAfterOneTest` writes it back with `UpdateData` and asserts it reads back.
- `scripts/ci-throwaway.sh` -- add `# classes: TaskMailAuditMask` with one comment line to the `OCUPILOT_ALLOW_CONFIG_SETTINGS` block.

**Acceptance Criteria:**

- Given the mail password set, changed or cleared on `ocupilot-ci`, when the Logs audit screen's read over HTTP and `logs.audit.read` through `Registry.InvokeTool` read the row, then old and new values read `*****` (an empty one stays empty), while `%SYS.Audit` still holds the Base64 value.
- Given the survey below, when the vendor's other `OldValue`/`NewValue` audit writers are checked, then the one setter of this shape is declared and none is left to ledger.
- DW-2625: closed by the two criteria above.

## Spec Change Log

## Review Triage Log

## Design Notes

**ADs:** AD-35 (vendor audit secrets masked on both paths, declared per event), AD-36 (one read for screen and tool), AD-60 (the sanitizer leaves an existing `*****` alone; `SanitizeAuditMask` pins that composition).

**Consumes:** `Screen.Read.Execute` (the Logs audit screen and `logs.audit.read`). No new service; Rule 1's integration criterion is the first acceptance criterion, measured on both callers.

**Extend, don't copy:** the new matcher shares the extracted `DeclaredEntry` with `SecretKeys` and `SettingKeys`; masking extends `MaskedEventData`; the test reuses `AuditVendorSecrets`' helpers and extends `VendorCarries`.

**Contention:** `git log origin/OCU-1-epic24 ^origin/feature/OCU-1_ocupilot-mvp -- AuditPort.cls Read.cls` names `c25e3207b` (Story 24.3), which changes `Read.cls`'s interop branch (around line 621) only. This story does not edit `Read.cls`. `origin/OCU-1-epic22` does not exist.

**Survey (`OldValue`/`NewValue` writers in `irissys/`; `irislib/` holds copies of the same files):**

- `%SYS/Task/Config.cls:43-63,98-104,181` -- the mail password. Declared.
- `%SYS/X509Credentials.cls:363,383-384` -- the vendor redacts `PrivateKey`, `PrivateKeyPassword` and `Certificate` itself.
- `%SYS/Wallet/Secret.cls:191-193` -- the generator writes `Storage` as `********`. `Secret` and `Secret64` are transient (`%Wallet/Secret.cls:46,49`) and the generator skips them.
- `%SYS/PhoneProviders.cls:339-340` (`Name`, `SMSGateway`), `%Wallet/Collection.cls:297-305` (resource names) and `%CSP/Portal/Utils.cls:647-648` (a boolean) -- none of these values is a secret.
- `OAuth2/*` -- already declared (`VENDORSECRETS`, `VENDORSETTINGSECRETS`) or masked by the vendor.

No proposed ledger entries.

**Decided in-stage:**

- The grammar extension is a fourth family, rather than a key token inside an existing one, because this row's source and line shape are both new.
- The class is armed by `OCUPILOT_ALLOW_CONFIG_SETTINGS`, since it changes one instance setting and restores it.
- The description match keeps the existing whole-word rule. A task deliberately named `Config.MailAuthPassword …` would have its value lines over-masked, which errs on the safe side. Slot A's read-only probe found only "Modify Task Purge Audit Database" and demo task names.

## Verification

**Shared surfaces:** `AuditPort`'s declarations and `MaskVendorSecrets` (`AuditVendorSecrets`, `OAuthResourceServerAuditMask`, `OAuthAuthorizationServerSecret`, `OAuthRegisteredClientSecret`, `AuthOptionsDescriptor`, `SanitizeAuditMask`, `SecretLeak`), and the `OCUPILOT_ALLOW_CONFIG_SETTINGS` roster (`ui/tools/ci.test.mjs`). *Every test added or changed passes on a fresh environment, in either order.*

**Commands.** One per foreground call, `timeout: 600000`, against `ocupilot-ci` only, never two test calls in one message.

- `(loop)` `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/4667058b-f052-49c9-b08a-221f7f41dfab/scratchpad/e21u/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` -- expected: `LOADERRORS=0`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.TaskMailAuditMask`, then the same command for each shared-surface class above and for `PortGate`, one class per call -- expected: green.
- `(loop)` `uv run scripts/check-objectscript.py`, `uv run scripts/test_check_objectscript.py`, `bash scripts/lint-docs.sh`, `cd ui && node --test tools/ci.test.mjs` -- expected: clean and green.
- `(once)` `cd ui && npm run test:tools` -- expected: green.
- `(once)`, runner-owned: the full ObjectScript sweep, one class per call; `smoke.sh --container ocupilot-ci`; Rule 30's fresh check. No browser spec is touched, and the browser suite is left to CI.

**Mutations (Rule 19), each applied, observed red, reverted (tree identical by `git status --short` and `git diff --stat`), the reverted source reloaded:**

- AC1: `VENDORCONFIGSECRETS` emptied -> `TaskMailAuditMask`'s set, change, clear and mask-alone methods go red, and the other shared-surface classes stay green.
- AC2: the declaration pin is the survey's executable half, and the same mutation reddens it.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

---
title: 'Story 18.48: Epic 18 burn-down, part 2 (encryption, journals, LDAP, agent reads)'
type: 'bugfix'
created: '2026-10-14'
status: 'done'
baseline_revision: '6ad16de0b6dc785e7c4aee1637ff45239b8d2943'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['multiple-goals', 'oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Epic 18 routed twelve entries here (DW-1896, 1966, 2085, 2086, 2087, 2100, 2126, 2335, 2424, 2425, 2427, 2429); each one's `ledger.sh show` trailers carry its ruling.

**Approach:** Task 0 measures on `ocupilot-ci` what rests on inference; each entry is then fixed where its ruling places it, extending the named sibling, with one pinning test and one `mutation:` line, or closed on the recorded evidence.

## Boundaries & Constraints

**Always:** configuration probes on `ocupilot-ci` only. A refusal's sentence is the server's (AD-39): one sentence, cause and way out, in its class's voice. New codes go in the area's error class or `Prohibited.cls`, never `Api/Error.cls`; a published sentence is an add-only `strings.ts` key in EXPERIENCE.md's Fixed strings (in place; literals 3,390, bound 3800). Rule 11: Epic 20's files take add-only edits, except `Prohibited.cls` (pre-authorized) and For the lead's asks. A test creates and removes what it asserts on, on every path; class cleanup returns first when unarmed.

**Never:** a start arm wider than the decision rule names; a stored secret's value read; a vendor class outside `AdminPort` and AD-27's ports; a hand edit of `screens.generated.ts`.

## I/O & Edge-Case Matrix

| Entry | State | Behavior | Edge |
|---|---|---|---|
| 2100 | change leaving a start Task 0 saw fail | refused, no write | else unchanged |
| 2085 | `Encrypted` create, key active | default key's id sent; reads encrypted | no key: 422 `DATABASE.ENCRYPT.NOKEY`; control `aria-disabled` |
| 2086 | file's keys changed since mint | 409 `ENCRYPTION.KEYFILE.CHANGED` | screen compares nothing |
| 2087 | database activate, no key active | minted destructive | key active: ordinary |
| 2126 | RSA replace over a certificate | card and dialog name its loss | -- |
| 1966 | journal dir = a database or volume dir | 422 `JOURNAL.DIRECTORY.DATABASE` | failed read: 500 |
| 1896 | last attribute removed | saved, read-back empty | no `%Admin_Secure`: 403 |
| 2335 | the three forms' write fields | read-tool answered, or recorded form-only | `Password` form-only |
| 2424 | egress `TLSMinVersion` < 16 | 422 `EGRESS.SSLWEAK` | 16+: saved |
| 2425 | app granting a privileged role | enabling, or `Resource` public for `U`: `GRANT.PRIVILEGED` | else ordinary; failed read: public |
| 2427 | #5022, #1219, #1204 at measured keys | unlogged | other codes logged |
| 2429 | startup settings refused #1231, #1233 (and #1217) | field refusal on the start mode, unlogged | other codes logged |

</intent-contract>

## Code Map

Under `src/OcuPilot/` at `3a91b5ee`; client under `ui/src/app/areas/`.

- `Kernel/Proposal/Prohibited.cls` :535-545, `EncryptionStartup` :3076, `WeakensByEffect` :2063, web grant arm :4644, `WidensPrivilegedReach` :5996.
- `Port/EncryptionPort.cls` `ActiveKeys` :577, `FileKeys` :668, `Activate` :703, `DatabaseEncryption` :1156; `Screen/Tool/EncryptionKeyWrite.cls:218`; `TaskImport.cls` :54-156, `Port/TaskTransferPort.cls:314`.
- `Screen/Tool/LocalDatabaseCreate.cls:37`, `Port/DatabasePort.cls` :72, :819, `Area/OsMgmt/DatabaseRules.cls:396`, `os-management/database-wizard.*`.
- `Api/WalletKeyError.cls:98`; `Port/JournalPort.cls:319`, `PathPort.cls:546`; `Area/Security/LdapRules.cls:145`; `Port/AdminPort.cls` :641, :736, :2236.
- `Screen/Descriptor/UserList.cls:96`, `SuperserverList.cls:51`; `Kernel/SwitchRules.cls:103`; `Area/Permissions/ResourceRules.cls:267`; `web-applications/web-app-editor.page.ts:737`, `routine-app-form.page.ts:460`; `logs/log-viewer.spec.ts:344` (vitest forks, `isolate` false; local Node 26.8.1 only).

## Tasks & Acceptance

**Task 0** (lead-side probe before implement, `ocupilot-ci`, after `LOAD-OK`; implement starts from its results on a freshly rebuilt throwaway; evidence in `/Users/jbrandt/git/OcuPilot/.worktrees/.coordination/carry-2026-10-10/epic-18-r/1848/t0/`; results in `## Verification`).

*Part A, no restart:* **A1** DW-2427 via `EncryptionPort`: `KeyInFile` `LIST` of a file with no readable key (#5022); `AddKey` and `ActivateDB` with a wrong password (#1219); `AddKey` with an unlisted administrator via a fixture skipping `Listed` (#1204); record endpoint, type, status. **A2** DW-1896: a `ServiceLdapProbe` configuration with one attribute; as a principal holding only the LDAP screen's pairs, `Security.LDAPConfigs.Modify(name, .p)`, `p("LDAPAttributes")=""`, in `%SYS`; record the read-back; again without `%Admin_Secure`. **A3** DW-2126: an RSA secret with `Certificate` and `PrivateKey` (`X509Material`), generate-replaced; record `HasCertificate`. **A4** DW-2335: a `Security.Superserver` `LIST`'s row keys. **A5** DW-2415: under Node 22.22.3 (official tarball, evidence folder), the spec files run 38532797700 attempt 1's 22.22.3 `gates` log ran before `log-viewer.spec.ts`, then it, one worker, up to five times; on a non-zero AC6, each leaked timer's creating stack.

*Part B, restarts* (`docker restart -t 120 ocupilot-ci`; "finishes" = healthy in 10 minutes). From S0 activate probe key K1 (again after restarts as needed): **M3** `DBEncJournal` on under Interactive, none of the three encrypted, restart; **Setup** Unattended over F1 holding K1, `DBEncIRISTemp` on, restart; **M2** a `Security.KMIPServer` at an unreachable host, mode KMIP, restart if accepted; **M1** Unattended over F2 holding only K2, restart if accepted. Record vendor answers, new `messages.log` lines, health, the three databases' key ids. A start that does not finish, and M1's end, HALT `blocked`: `Task 0 complete through <step>; throwaway rebuild needed: <state>` (planned); the runner rebuilds (`ci-throwaway.sh down`, `up` with the slot's `--dir`, `--project`, `--web 52776`, `--super 1975`) and re-dispatches at the next step, last at Execution.

**Decision rule (DW-2100).** A start that does not finish widens AD-10's start arm as below (before any write, either caller, on `DBEncStartMode`); a vendor refusal (of the change or M2's server) or a finished start keeps it, recorded. Anything else (a half-applied write, a fact moved by a refusal, Setup not finishing) is an `intent gap` HALT.

- **M1 → `PROHIBITED.STARTUPKEYFILE`:** Unattended over a file whose keys (`FileKeys` at the write; a failed read refuses) lack the key encrypting IRISAUDIT, IRISSECURITY or IRISTEMP on disk, or the default database key for a flag not yet on disk.
- **M2 → `PROHIBITED.STARTUPKMIP`:** KMIP while any of the three is encrypted now or at the next start; the sentence names the classic page.
- **M3 → `PROHIBITED.STARTUPJOURNAL`:** Interactive while `DBEncJournal` is set (payload or target) or `%SYS.Journal.System.OKNoDBEncKeyAtStartup()` errs (in `%SYS`, caller's `%Admin_Secure`; a failed read refuses).

**Execution** (change; pinning test; mutation):

1. **DW-2100:** each widened case (`STARTUPJOURNAL`, `STARTUPKMIP`; Task 0 results) joins `EncryptionStartup` (`Codes()`, `ReasonFor`, a `strings.ts` key pinned in `self-protection.test.mjs`, EXPERIENCE.md's STARTUPINTERACTIVE row); `DatabaseEncryption` also answers key ids. Test: `EncryptionStartupWrite` legs per case, both callers (as `ArmOnDisk`). Mutation: drop the case.
2. **DW-2085:** `Encrypted` joins `LocalDatabaseCreate` `ARGUMENTS` (and `DESCRIPTION`) and `CREATEARGUMENTS`; `DatabaseRules` and `Create` refuse it while `ActiveKeys(DATABASEKEYS)` has no default key (`DATABASE.ENCRYPT.NOKEY`); `FileBody` sends it with that key's `EncryptionKeyID`; `HandleForm` answers `EncryptionKeyID` or `""`, and on `""` the wizard's "Encrypt database" is `aria-disabled` with the refusal's sentence. Test: new `Test/DatabaseCreateEncrypted.cls` (`OCUPILOT_ALLOW_ENCRYPTION_CONFIG`): a no-key leg via a port seam; a live leg over a probe key reading `EncryptedDB` 1 and the key id, then removing it; the wizard spec; a `local-databases` browser no-key leg. Mutation: `FileBody` drops `Encrypted`.
3. **DW-2086:** both activate tools carry `FileKeys` as `TaskImport` carries `tasks` (`SettableFields`, `READANSWERS`, `FINGERPRINTSUBJECT`, `PortQuery`); `Activate` compares the file's keys with it as sets, else 409 `ENCRYPTION.KEYFILE.CHANGED`; an empty list compares nothing. Test: `EncryptionKeyWrite` leg (mint, `AddKeyToFile`, confirm refused, nothing active). Mutation: drop the comparison.
4. **DW-2087:** `WeakensByEffect` gains a `TYPEDATABASEKEYS` arm: a non-removing write whose target has `ActiveCount` 0 answers effect `ENCRYPTION.KEY.ACTIVATE`, so the mint is destructive and the card keeps the tool's consequence (it names the start-mode change; the screen dialog already shows it); governance key stays `false`. Test: `EncryptionKeyWrite` mint legs (first `destructive` 1, second 0). Mutation: drop the arm.
5. **DW-2126:** if A3 reads 0, `REASONREPLACERSA` and `walletKeyReplaceRsaConsequence` open "Replaces the whole key pair, and a stored certificate is removed unless the import carries one."; EXPERIENCE.md :416 in place. Test: `WalletKeyReplace` leg over a certificate (card sentence; `HasCertificate` false after). Mutation: the old sentence.
6. **DW-1966:** `ResolveDirectory` refuses a directory equal (normalized, any case) to one `DatabaseDirectories` answers, `JOURNAL.DIRECTORY.DATABASE`; a failed read answers 500. Test: `JournalSettingsRules` leg (`USER`'s and OcuPilot's directories, both fields, settings unchanged); `JournalDescriptor` 13. Mutation: drop the check.
7. **DW-1896:** if A2 clears under `%Admin_Secure` alone, `AdminPort` completes a `Security.LDAP` `PUT` with an empty or all-blank `LDAPAttributes` as AD-27's next named case (extending `CompleteThroughClass`): the vendor `PUT` without the field, then A2's `Modify` in `%SYS` behind the same gate, `VerifyApplied` comparing as a set; the `LASTONE` rule and code deleted. Test: `LdapEdit` and `LdapUpdate` legs become "the last attribute is removed" (`[]`, `[""]`), plus 403 without `%Admin_Secure`; an `ldap-editor` browser leg. Mutation: drop the completion.
8. **DW-2335:** `UserList` `read.fields`, `rowGet.fields`, `context.fields` gain the eleven copy fields; `SuperserverList` each field A4 shows; `node tools/screen-mirror.mjs`. New `Test/FormReadCoverage.cls`: each scalar `ToolFields` field of the superserver, `osmgmt.localdatabases.update` and `permissions.users.copy` tools is answered by a named read tool's descriptor or listed form-only with its reason; a `permissions.users.read` run's row carries the eleven. Mutation: remove a widened field.
9. **DW-2415:** withdrawn (orchestrator 2026-10-14): Epic 20's Story 20.8 fixes AC6's isolation; `log-viewer.spec.ts` is unchanged here.
10. **DW-2424:** `ValidateEgress` raises `EGRESS.SSLWEAK` on `sslConfiguration` for an enabled verifying client below `ProviderPort.#MINTLSVERSION`; key `egressRefusalSslWeak`, EXPERIENCE.md :349, a sixth `EGRESS_SENTENCES` row. Test: `EgressSslProbe` kind `weak` (`VerifyPeer` 1, floor 8); an `EgressSettingsWire` case. Mutation: drop the floor.
11. **DW-2425:** `WidensPrivilegedReach` also counts a `Resource` changed to one whose public permission holds `U` (read via `AdminPort` `Security.Resource` `GET`, as `ResourceRules.Present`; a failed read counts), and the web arm calls it; `web-app-editor` shows `privilegedGrantEffect` at Enabled and Resource while a granted role is privileged, as `routine-app-form`. Test: `WebAppWeakening` legs (enabling; public; unprivileged and non-public ordinary) over a probe resource it creates and removes; a `RoutineAppGrant` leg; the editor spec. Mutation: drop the public clause; drop the web call.
12. **DW-2427, DW-2429:** `UNLOGGEDREFUSALS` gains `<endpoint>/<type>/<status>/#<code>` per code at its A1 key, and `Security.Encryption.Settings/PUT/500/#1217`, `/#1231`, `/#1233` (measured in Part B). `EncryptionPort` maps #1231 and #1233 to field refusals on the start-mode field beside #1217's `ENCRYPTION.STARTUP.REQUIRED`: two new `EncryptionError` codes, each sentence saying what the person can change, with `strings.ts` keys. Test: `AdminPortRefusals` legs; an `EncryptionKeyFileWrite` wrong-password leg logs no `failed` line; an `EncryptionStartupWrite` leg per new code through a port seam (no restart). Mutation: drop an entry; drop a mapping.
13. **Rule 30 sweep:** grep the four test trees for `STARTUPINTERACTIVE`, `DBEncJournal`, `CREATEARGUMENTS`, `FileKeys`, `REASONREPLACERSA`, `JOURNAL.DIRECTORY`, `LASTONE`, `UNLOGGEDREFUSALS`, `EGRESS_SENTENCES`, `EnabledVerifyingClient`, `WidensPrivilegedReach`, `SuperserverList`, `UserList`; update old-shape assertions; changed files join `(loop)`.

**Acceptance Criteria:**

- Given each matrix row, when the story is done, then its task's pinning test shows it holding and its recorded mutation reddens that test.
- Given a Task 0 outcome that closes an entry instead (DW-2100 kept everywhere, DW-2126's certificate kept, DW-1896 not clearing, a code not driven), when the story is done, then `## Verification` records the evidence.

## Spec Change Log

- 2026-10-14 (lead, orchestrator ruling): DW-2415 withdrawn after implement; Epic 20's 20.8 fixes AC6's isolation. Task 9's `log-viewer.spec.ts` hunk reverted to its pre-story content.

## Review Triage Log

### 2026-10-14 - Review pass

- verdicts: 32 findings - high 0, medium 3, low 20, false 9, maybe-false 0
- findings:
  - `[medium]` `[patch]` Data-element activation's `FileKeys` wiring and 409 unpinned - added `EncryptionKeyWrite.TestADataElementKeyFileChangedSinceTheMintIsRefusedAtTheConfirm`; emptying `MINTARGUMENTS` reddens it (run 126).
  - `[low]` `[patch]` Encrypted-create script (`DatabasePort.Snippet`) unpinned - `DraftPorts.TestDatabasePort` gains the flag-and-key and no-flag legs through new seam `Test/DatabaseKeyPort`; mutation red (run 127).
  - `[low]` `[patch]` LDAP cleared-list script step unpinned - `DraftPorts.TestAdminPort` gains the two-step leg; mutation red (run 128).
  - `[low]` `[patch]` DW-2085 refusals had no recorded mutation, failed-key-read branches untested - both refusal mutations run and recorded (runs 130, 131); no failed-read leg added: the fallbacks answer a vendor read failure and no matrix edge names them.
  - `[low]` `[reject]` Post-PUT half of `CompleteClearedList` pinned on the happy path only - the read-back-empty assertion pins the effect; the failure legs need a seam over a non-overridable vendor call, more than a direct correction.
  - `[low]` `[reject]` AC6 hardening unverified in the failing configuration - the failure never reproduced in Task 0; the chain run on Node 22.22.3 reads 0 timers in eleven cases (418 passed).
  - `[low]` `[reject]` `walletKeyReplaceRsaConsequence` generalizes one measurement - the sentence is the spec's Task 5 text and is conditional ("unless the import carries one"); spec-bound.
  - `[low]` `[patch]` `DatabaseCreateEncrypted` after-hooks run unarmed - an `Armed()` guard returns first in both hooks (grouped with the intent layer's cleanup row).
  - `[low]` `[reject]` No recorded order/fresh-environment run - that is the runner's Rule 30 `fresh_check`; the class header now states its S0 need (no key active).
  - `[low]` `[patch]` `FormReadCoverage` floors weak - a per-tool "classifies at least one field" assertion added; the superserver form-only leg still discriminates (it asserts the read does not answer them).
  - `[low]` `[patch]` Users `context.fields` widening unpinned - `TestTheUsersScreenContextCarriesTheCopyFormsFields` added; mutation red (run 139).
  - `[medium]` `[patch]` The port's own `JournalStartup` read was never exercised (seam only) - `EncryptionStartupRead.TestThePortsOwnJournalStartupReadAnswersTheVendorsVerdict` compares it with the vendor verdict; negating it reddens the test (run 129).
  - `[false]` `[reject]` `PROHIBITED.*` start refusals are 403 envelopes, the start-mode placement is client-side - Task 1 specifies the cases inside `EncryptionStartup`; `STARTUP_MODE_REFUSALS` is pinned against the kernel codes in `self-protection.test.mjs`.
  - `[false]` `[reject]` Two existing tests rewritten against Decision 8 - the journal arm is Task 0's M3 result, which that decision predates.
  - `[false]` `[reject]` KMIP arm reads encryption on disk - Task 0's M2 rule says "encrypted now or at the next start" and the arm mirrors the Interactive arm.
  - `[false]` `[reject]` #1217 only unlogged, still a 409 - Task 12 says the new mappings sit "beside #1217's `ENCRYPTION.STARTUP.REQUIRED`".
  - `[low]` `[reject]` "Unlogged" proven live for #1219 and #5022 only - the other keys were measured live in Task 0 A1; the predicate over them is what the tests pin.
  - `[low]` `[reject]` 2415's recorded run names no Node version - the Node 22.22.3 chain was run in review (418 passed, 0 timers).
  - `[low]` `[reject]` Epic 20's branch holds a second AC6 fix (`c8410546`) - not a defect here (the ledger trailer rules this Epic 18's test); a Rule 22 merge matter, reported in the result.
  - `[low]` `[reject]` 2085 has no browser leg with a key active - the live server leg and the wizard component specs pin it; a browser key activation would change throwaway state.
  - `[false]` `[reject]` A failed key read and "no key" both disable the control - the spec says the form answers `EncryptionKeyID` or `""`.
  - `[low]` `[reject]` 2087's dialog untested here - Task 4 says the screen dialog already names the start-mode change; the mint is what this story changes.
  - `[low]` `[reject]` 2126's dialog sentence pinned as text only - `strings.test.mjs` and `self-protection.test.mjs` pin it against the server sentence; it is a constant the dialog renders.
  - `[low]` `[reject]` 1966 asserts no volume directory - volume directories come from `PathPort.DatabaseDirectories`, unchanged.
  - `[low]` `[reject]` 1896's 403 leg runs at the port - the gate is the port's; the REST leg covers the 200.
  - `[false]` `[reject]` Form-only record sits in test constants - Design Notes carry it, as the spec places it.
  - `[false]` `[reject]` 2424 boundary unread - the existing verified probe is TLS 1.2 (16) and is stored in the same test.
  - `[low]` `[reject]` 2425's failed read tested with a missing resource only - one code path (`ISERR` or no object); the editor line matches `routine-app-form`, as the spec says.
  - `[false]` `[reject]` New sentences are two sentences - AD-39's "one sentence" is one message, cause and way out, as the sibling sentences read.
  - `[false]` `[reject]` One `mutation:` line per task bundles several - the spec's lines are per task.
  - `[low]` `[patch]` Unarmed cleanup in `DatabaseCreateEncrypted` (intent layer) - same root as the gap layer's row; one guard.
  - `[medium]` `[patch]` (found by the stage agent while writing the context leg) `TestAUsersReadRowCarriesTheCopyFormsFields` read `tJ = N + 1` left to right, so every pass tested `Routine` and its mutation could not redden - the loop is `tJ > tCount`, and the leg now asserts the detail call's `rowGet.fields` carries the eleven; dropping `PhoneProvider` reddens it (run 142).

## Design Notes

**Governing ADs:** AD-2, 3, 5, 8, 10, 16, 21, 27, 32, 35, 36, 39, 51, 53, 54, 58.

**Rule 31.** Tasks extend the symbols they name. Copied: `TaskTransferPort.Import`'s reviewed-list check (another port and vendor API).

**DW-2335 record** (inference). The ten `osmgmt.localdatabases.update` fields (`ToolFields` :129-140) are answered by `osmgmt.databasedetails.read` (criterion `dir`). The twelve `permissions.users.copy` fields (:215-233) are widened, except `Password`: form-only, write-only, typed at confirm. A superserver field the `LIST` lacks is form-only: only a `GET` keyed by port and bind address answers it, which one-key `rowGet` cannot send.

**Integration.** No new service; consumes 18.3, 18.7, 18.18, 18.22-24, 18.27, 18.40, 18.47; Integration AC: task 2's live leg. None declined.

**For the lead** (Rule 20):

- **Spine:** AD-10 (the start arm; DW-2087; DW-2425), AD-2 :104 (DW-2427), AD-27 (DW-1896 if built; `OKNoDBEncKeyAtStartup` if M3 widens), AD-32 (DW-2424), AD-51 (DW-2086). AD-21 :563 already carries DW-1966.
- **Task 0** runs lead-side (orchestrator 2026-10-14): the probe runs only `docker restart -t 120 ocupilot-ci`, after checking the target's name and ports (52776/1975); rebuilds are the runner's; key files and KMIP material stay in the throwaway's directory and are deleted when Part B ends.
- **Rule 11 asks** (approved, orchestrator 2026-10-14): `Prohibited.cls` hunks for DW-2100 and DW-2087 (Epic 20's diff omits the file at `5d766aae`); the `strings.ts` value `walletKeyReplaceRsaConsequence`; `screen-mirror.test.mjs:704-714`'s users `rowGet` fields. Add-only otherwise.
- **Ledger:** each `resolved-by:18-48-epic-18-burn-down-part-2`, or its Task 0 closure (DW-2100 or DW-2126 kept: `dropped`; DW-1896: `wontfix-accepted reopen_if=Modify clears the list under %Admin_Secure alone`).

## Verification

**Task 0 results** (lead-side, `ocupilot-ci`, 2026-10-14; evidence `1848/t0/part-a-results.md`, `part-b-results.md`). Task 0 is complete; implement starts at Execution and does not repeat it.

- A1: `Security.Encryption.KeyInFile/LIST/500/#5022`, `Security.Encryption.KeyInFile/POST/500/#1219`, `Security.Encryption.File/ACTIVATE/500/#1219`, `Security.Encryption.KeyInFile/POST/500/#1204`, each logged. Named limit: a failed `ActivateDB` also writes the vendor's own severity-2 line.
- A2: `Modify` with `LDAPAttributes` `""` cleared the list for a principal holding exactly `%Admin_Secure:USE` and `%DB_IRISSYS:READ`; without `%Admin_Secure` it answered #822 and changed nothing. Task 7 builds.
- A3: `HasCertificate` read 1, then 0 after a generate-replace. Task 5 builds.
- A4: a `Security.Superserver` `LIST` row carries `Port`, `BindAddress`, `Enabled`, `SystemDefault`.
- A5: AC6 read 0 timers in 10 runs under Node 22.22.3 (order inferred from the CI log). No source cause found; DW-2415 is withdrawn (Spec Change Log).
- M3 did not finish (Interactive, `DBEncJournal` on; `OKNoDBEncKeyAtStartup` answered #1212): `PROHIBITED.STARTUPJOURNAL` is built. M2 was refused (#1231, a server with no startup key list); M2b, KMIP over a startup-configured server at an unreachable host, was accepted and did not finish: `PROHIBITED.STARTUPKMIP` is built. M1 is kept, and `PROHIBITED.STARTUPKEYFILE` is not built: the vendor refused a file switch (#1233) and a move to None (#1217), and a first Unattended over a file lacking the default key finished.

**Commands** (one run per call, `timeout: 600000`):

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/carry-2026-10-08/epic-18-d8/load-ocupilot-ci.sh`: `LOAD-OK`, `STARTPATH-OK`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one at a time, totals from `%UnitTest_Result`: each class tasks 1-13 name or change, plus `Prohibited`, `ReadTool`, `Descriptor`, `SurfaceCoverage`, `StageTwoTools`.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`.
- `(loop)` with the slot's `OCUPILOT_BROWSER_ORIGIN` and `OCUPILOT_BROWSER_CONTAINER`, rebuilt and redeployed: `node --test --test-concurrency=1 browser/<name>.browser-spec.mjs`, one file per call: `local-databases`, `web-applications-editor`, `ldap-editor`, `switches`, `encryption-startup`. Initial bundle under 1992 kB, lazy chunks under 88 kB.
- `uv run scripts/check-objectscript.py`, `bash scripts/lint-docs.sh`: 0 problems.

**Mutations (Rule 19).** Each was applied, the mutated class and every descendant recompiled on `ocupilot-ci` (client code rebuilt and redeployed before a browser spec read it), the red test observed, then reverted with the file byte-identical (sha) and `git status --short` and `git diff --stat` unchanged.

- mutation: Task 1, `Prohibited.EncryptionStartup` journal arm to `If 0` -> `EncryptionStartupWrite.TestInteractiveIsRefusedWhileTheJournalNeedsItsKeyOnBothCallers`; the KMIP arm to `If 0` -> `TestKmipIsRefusedWhileADatabaseNeedsItsKeyOnBothCallers`; `STARTUPKMIP` out of `Codes()` -> `EncryptionStartupDescriptor` (two tests) and `AuditingUpdate`; `STARTUP_JOURNAL_CODE` out of the store's `STARTUP_MODE_REFUSALS` -> `encryption-startup.store.spec`.
- mutation: Task 2, `DatabasePort.FileBody` drops `Encrypted` -> `DatabaseCreateEncrypted` (flag and live legs); `Encrypted` out of `DatabaseCreateFields` -> `DatabaseDescriptor` and `RemoteDatabaseDescriptor`; the wizard store's `encryptAvailable` true -> the `local-databases` browser no-key leg; its `setEncrypted` guard removed -> `database-wizard.store.spec`.
- mutation: Task 3, `EncryptionPort.Activate` without the `SameKeys` comparison -> `EncryptionKeyWrite.TestAKeyFileChangedSinceTheMintIsRefusedAtTheConfirm`; `FileKeys` out of `KEYARGUMENTS` -> `EncryptionKeyRead` and `EncryptionKeyWrite`; `KEYFILECHANGED` out of `Codes()` -> `EncryptionDescriptor`.
- mutation: Task 4, the `TYPEDATABASEKEYS` first-key line of `WeakensByEffect` dropped -> `EncryptionKeyWrite` (two tests).
- mutation: Task 5, `REASONREPLACERSA` back to the old sentence -> `WalletKeyReplace.TestAGeneratedReplaceRemovesAStoredCertificateAndTheCardSaysSo`; the published sentence changed in `strings.ts` -> `self-protection.test.mjs` and `strings.test.mjs`.
- mutation: Task 6, `JournalPort.ResolveDirectory` without the refusal -> `JournalSettingsRules.TestADatabasesDirectoryIsRefusedOnEachPathField`; `DIRECTORYDATABASE` out of `Codes()` -> `JournalDescriptor`.
- mutation: Task 7, `Security.LDAP/PUT=LDAPAttributes` out of `CLASSCOMPLETEDTYPES` -> `LdapEdit.TestTheLastAttributeIsRemoved`, `LdapUpdate.TestTheLastAttributeIsRemovedByAConfirmedProposal` and the `ldap-editor` browser leg.
- mutation: Task 8, `Comment` out of `UserList` `read.fields` -> `FormReadCoverage.TestEveryFormFieldIsAnsweredOrListedFormOnly` and `ScreenReadWire.TestTheUsersListReadsOverTheWire`.
- mutation: Task 10, the `TLSMinVersion` floor of `SwitchRules.ValidateEgress` to `ElseIf 0` -> `EgressSettingsWire.TestAConfigurationIsNamedOnlyAsAnEnabledClientThatVerifiesThePeer`.
- mutation: Task 11, `RepointsToPublicResource` out of `WidensPrivilegedReach` -> `WebAppWeakening.TestEnablingAndAPublicResourceAreGrantsWhileAPrivilegedRoleIsGranted` and `RoutineAppGrant.TestAResourceTheBroadPublicMayUseIsAGrantUnderAPrivilegedRole`; the web application's `WidensPrivilegedReach` call dropped -> `WebAppWeakening`; the editor stating its line at Resource only -> `web-app-editor.page.spec`.
- mutation: Task 12, the `#1204` entry out of `UNLOGGEDREFUSALS` -> `AdminPortRefusals.TestTheEncryptionRefusalsAreUnloggedForTheirOwnCodeAlone` (`EncryptionKeyFileWrite` does not reach `#1204`); the `#1219` entry -> `AdminPortRefusals` and `EncryptionKeyFileWrite.TestAFieldRefusalOfTheVendorLogsNoLine`; the `PROPERTYFAULTS` mapping for `#1231` -> `EncryptionStartupWrite.TestAVendorRefusalArrivesAsOcuPilotsSentence`.
- mutation (review patches, Rule 19): `DataElementKeyActivate.MINTARGUMENTS` emptied -> `EncryptionKeyWrite.TestADataElementKeyFileChangedSinceTheMintIsRefusedAtTheConfirm` (run 126); `DatabasePort.Snippet`'s `DefaultKey` lookup behind `If 0` -> `DraftPorts.TestDatabasePort` (run 127); `AdminPort.Snippet`'s cleared-list branch behind `If 0` -> `DraftPorts.TestAdminPort` (run 128); `EncryptionPort.JournalStartup`'s verdict negated -> `EncryptionStartupRead.TestThePortsOwnJournalStartupReadAnswersTheVendorsVerdict` (run 129); Task 2's refusals: `DatabasePort.Create`'s no-key refusal behind `If 0` -> `DatabaseCreateEncrypted.TestAnEncryptedCreateIsRefusedWhileNoKeyIsActive` (run 130), and `DatabaseRules.Validate`'s violation behind `If 0` -> the same test (run 131); `UserList` `context.fields` without `PhoneNumber` -> `FormReadCoverage.TestTheUsersScreenContextCarriesTheCopyFormsFields` (run 139), and `rowGet.fields` without `PhoneProvider` -> `FormReadCoverage.TestAUsersReadRowCarriesTheCopyFormsFields` (run 142). Each reverted byte-identical (sha, `git status --short`, `git diff --stat`) and reloaded.

**Results (implement).** 48 ObjectScript classes (441 tests) green on `ocupilot-ci`, one at a time; `npm run test:tools` 1993 of 1993; `npm run test:components` 3119 of 3119 (245 files); browser: `local-databases` 8, `web-applications-editor` 7, `ldap-editor` 7, `switches` 5, `encryption-startup` 3, all green; initial bundle 1926.7 kB (the sum of the initial chunks' raw sizes), largest lazy chunk 83.32 kB (`data-browser-page`); `check-objectscript.py` and `lint-docs.sh`: 0 problems. The throwaway reads S0 (start mode None, no key active, nothing encrypted).

**Results (review).** After the patches, green on `ocupilot-ci` one at a time: `DraftPorts` 13 (run 133), `EncryptionKeyWrite` 11 (144), `EncryptionStartupRead` 6 (145), `FormReadCoverage` 3 (143), `DatabaseCreateEncrypted` 3 (132), `JournalDescriptor` 13 (134); `check-objectscript.py` 0 problems. The throwaway reads S0.

**Shared surfaces:** prohibited, `EGRESS`, `ENCRYPTION`, `JOURNAL`, `LDAP`, `DATABASE` codes, sentences, counts; `UNLOGGEDREFUSALS`; the activate fingerprints; the create's arguments and form; the users and superserver reads; the screen mirror; the web editor's lines; AC6's timers.

every test added or changed passes on a fresh environment, in either order

## Auto Run Result

Status: done
Blocking condition: none

**Change.** All twelve entries are built; none closed on evidence alone. DW-2100: `PROHIBITED.STARTUPJOURNAL` and `PROHIBITED.STARTUPKMIP` (38 codes); `STARTUPKEYFILE` is not built (M1 kept). DW-2085: `Encrypted` on the create, refused `DATABASE.ENCRYPT.NOKEY`, the file body carries the default key's id, the wizard control is `aria-disabled` without a key. DW-2086: the activate tools carry `FileKeys`; a changed file is 409 `ENCRYPTION.KEYFILE.CHANGED`. DW-2087: the first database key activation is destructive. DW-2126: the RSA replace sentence names the lost certificate. DW-1966: `JOURNAL.DIRECTORY.DATABASE`. DW-1896: `AdminPort` completes an empty or blank `LDAPAttributes` through `Security.LDAPConfigs.Modify`; `LASTONE` deleted. DW-2335: `UserList` answers the copy form's fields. DW-2424: `EGRESS.SSLWEAK`. DW-2425: enabling a privileged web application, or a publicly held `Resource`, is a grant; the editor states it. DW-2427, DW-2429: seven `UNLOGGEDREFUSALS` entries; #1231 and #1233 are field refusals on the start mode.

**Files.** Product: `Api/{Database,Egress,Encryption,Journal,Ldap,WalletKey}Error.cls` (codes and sentences); `Area/OsMgmt/DatabaseRules.cls`, `Area/Security/LdapRules.cls`; `Kernel/Proposal/Prohibited.cls`, `Kernel/SwitchRules.cls`; `Port/{Admin,Database,Encryption,Journal}Port.cls`; `Screen/Descriptor/UserList.cls`, `Screen/Tool/{DataElementKeyActivate,DatabaseKeyActivate,EncryptionKeyWrite,LocalDatabaseCreate}.cls`; client `os-management/database-wizard.*`, `security/encryption-startup.store.ts`, `web-applications/web-app-editor.*`, `core/strings.ts`, `core/screens.generated.ts` (regenerated); EXPERIENCE.md Fixed strings rows; `scripts/ci-throwaway.sh` (roster comment). Tests: new `Test/{DatabaseCreateEncrypted,DatabaseNoKeyPort,DatabaseKeyPort,FormReadCoverage}.cls`; legs added or changed in the classes the Rule 30 sweep names, `log-viewer.spec.ts`, the wizard and editor specs, `local-databases` and `ldap-editor` browser specs, `screen-mirror.test.mjs`, `self-protection.test.mjs`.

**Review.** 32 findings (Review Triage Log): patched 10 rows in 9 entries (3 medium, 6 low), deferred 0, rejected 22, each with its reason in the log. The patches are tests, one test seam class and one cleanup guard, each with a recorded mutation.

**Follow-up review recommended: true.** Three medium entries were patched. The risks left unverified: the patch tests were not read by a second reviewer, and `STARTUPJOURNAL` and `STARTUPKMIP` are judged end to end only through seams and Task 0's measurements, since a real Interactive or KMIP write needs a restart.

**Verification.** Implement and review runs are in `## Verification`: 48 classes (441 tests) plus the review's six classes green on `ocupilot-ci`; `test:tools` 1993/1993 and `test:components` 3119/3119 at implement; five browser specs green; initial bundle 1926.7 kB (warning 1992), largest lazy chunk 83.32 kB (cap 88); `check-objectscript.py` and `lint-docs.sh` 0 problems; throwaway at S0.

**Residual risks.** EXPERIENCE.md rows 349, 364, 377 and 416 are edited in place and Epic 20 also edits that file: expect a textual merge conflict. Epic 20's branch holds `c8410546`, a second change to the AC6 test; whichever lands second resolves it. `ui/tools/ci-timings.json` lists none of the three new test classes; the merge gate's refresh adds them.

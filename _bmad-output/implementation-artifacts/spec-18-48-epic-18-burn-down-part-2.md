---
title: 'Story 18.48: Epic 18 burn-down, part 2 (encryption, journals, LDAP, agent reads)'
type: 'bugfix'
created: '2026-10-14'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['multiple-goals', 'oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Epic 18 routed thirteen entries here (DW-1896, 1966, 2085, 2086, 2087, 2100, 2126, 2335, 2415, 2424, 2425, 2427, 2429); each one's `ledger.sh show` trailers carry its ruling.

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
| 2415 | AC6 after other files, one worker | 0 timers, Node 22.22.3 | -- |
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
9. **DW-2415:** fix A5's cause at its source if found; also AC6 in its own `describe`, `vi.useFakeTimers()` in `beforeEach`, `vi.clearAllTimers(); vi.useRealTimers()` in `afterEach`, timers present before each mount cleared, :345's comment corrected. Mutation: tail starts with Live tail off.
10. **DW-2424:** `ValidateEgress` raises `EGRESS.SSLWEAK` on `sslConfiguration` for an enabled verifying client below `ProviderPort.#MINTLSVERSION`; key `egressRefusalSslWeak`, EXPERIENCE.md :349, a sixth `EGRESS_SENTENCES` row. Test: `EgressSslProbe` kind `weak` (`VerifyPeer` 1, floor 8); an `EgressSettingsWire` case. Mutation: drop the floor.
11. **DW-2425:** `WidensPrivilegedReach` also counts a `Resource` changed to one whose public permission holds `U` (read via `AdminPort` `Security.Resource` `GET`, as `ResourceRules.Present`; a failed read counts), and the web arm calls it; `web-app-editor` shows `privilegedGrantEffect` at Enabled and Resource while a granted role is privileged, as `routine-app-form`. Test: `WebAppWeakening` legs (enabling; public; unprivileged and non-public ordinary) over a probe resource it creates and removes; a `RoutineAppGrant` leg; the editor spec. Mutation: drop the public clause; drop the web call.
12. **DW-2427, DW-2429:** `UNLOGGEDREFUSALS` gains `<endpoint>/<type>/<status>/#<code>` per code at its A1 key, and `Security.Encryption.Settings/PUT/500/#1217`, `/#1231`, `/#1233` (measured in Part B). `EncryptionPort` maps #1231 and #1233 to field refusals on the start-mode field beside #1217's `ENCRYPTION.STARTUP.REQUIRED`: two new `EncryptionError` codes, each sentence saying what the person can change, with `strings.ts` keys. Test: `AdminPortRefusals` legs; an `EncryptionKeyFileWrite` wrong-password leg logs no `failed` line; an `EncryptionStartupWrite` leg per new code through a port seam (no restart). Mutation: drop an entry; drop a mapping.
13. **Rule 30 sweep:** grep the four test trees for `STARTUPINTERACTIVE`, `DBEncJournal`, `CREATEARGUMENTS`, `FileKeys`, `REASONREPLACERSA`, `JOURNAL.DIRECTORY`, `LASTONE`, `UNLOGGEDREFUSALS`, `EGRESS_SENTENCES`, `EnabledVerifyingClient`, `WidensPrivilegedReach`, `SuperserverList`, `UserList`; update old-shape assertions; changed files join `(loop)`.

**Acceptance Criteria:**

- Given each matrix row, when the story is done, then its task's pinning test shows it holding and its recorded mutation reddens that test.
- Given a Task 0 outcome that closes an entry instead (DW-2100 kept everywhere, DW-2126's certificate kept, DW-1896 not clearing, a code not driven), when the story is done, then `## Verification` records the evidence.

## Spec Change Log

## Review Triage Log

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
- A5: AC6 read 0 timers in 10 runs under Node 22.22.3 (order inferred from the CI log). Task 9 hardens the isolation; no source cause found.
- M3 did not finish (Interactive, `DBEncJournal` on; `OKNoDBEncKeyAtStartup` answered #1212): `PROHIBITED.STARTUPJOURNAL` is built. M2 was refused (#1231, a server with no startup key list); M2b, KMIP over a startup-configured server at an unreachable host, was accepted and did not finish: `PROHIBITED.STARTUPKMIP` is built. M1 is kept, and `PROHIBITED.STARTUPKEYFILE` is not built: the vendor refused a file switch (#1233) and a move to None (#1217), and a first Unattended over a file lacking the default key finished.

**Commands** (one run per call, `timeout: 600000`):

- `(loop)` `sh /Users/jbrandt/git/OcuPilot/.worktrees/.coordination/carry-2026-10-08/epic-18-d8/load-ocupilot-ci.sh`: `LOAD-OK`, `STARTPATH-OK`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one at a time, totals from `%UnitTest_Result`: each class tasks 1-13 name or change, plus `Prohibited`, `ReadTool`, `Descriptor`, `SurfaceCoverage`, `StageTwoTools`.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`.
- `(loop)` with the slot's `OCUPILOT_BROWSER_ORIGIN` and `OCUPILOT_BROWSER_CONTAINER`, rebuilt and redeployed: `node --test --test-concurrency=1 browser/<name>.browser-spec.mjs`, one file per call: `local-databases`, `web-applications-editor`, `ldap-editor`, `switches`, `encryption-startup`. Initial bundle under 1992 kB, lazy chunks under 88 kB.
- `uv run scripts/check-objectscript.py`, `bash scripts/lint-docs.sh`: 0 problems.

**Shared surfaces:** prohibited, `EGRESS`, `ENCRYPTION`, `JOURNAL`, `LDAP`, `DATABASE` codes, sentences, counts; `UNLOGGEDREFUSALS`; the activate fingerprints; the create's arguments and form; the users and superserver reads; the screen mirror; the web editor's lines; AC6's timers.

every test added or changed passes on a fresh environment, in either order

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

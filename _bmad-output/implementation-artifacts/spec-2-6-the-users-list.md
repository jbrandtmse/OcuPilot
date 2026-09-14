---
title: 'Story 2.6: The users list'
type: 'feature'
created: '2026-09-14'
status: 'draft'
baseline_revision: 'e3a8b77f86f75b9e7679746445c11aadb6c4d79d'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings: []
deferred: []
---

# Story 2.6: The users list

Planning halted on an intent gap before the intent could be fixed, so this spec has no intent-contract block yet. The re-plan writes it.

## Code Map

Read-only probes on `ocupilot-iris`, 2026-09-14. No security object was created or changed.

- **The vendor LIST row** (`AdminPort.Invoke("Security.User","LIST")`, HTTP 200, 10 rows): exactly `Name`, `FullName`, `Namespace`, `Routine`, `Type` (string, `Password user`), `Enabled` (boolean). **No `Roles` key and no expiry key.**
- **Why.** `%Api.Admin.Endpoints.Security.User:RunList` runs `Security.Users:Detail`, which returns 34 columns including `Roles`, `ExpirationDate`, `AccountNeverExpires` and `PasswordNeverExpires`. It then rebuilds each row with those six keys only. The vendor's own comment says it keeps the six the classic page shows. The only query parameter is `names`.
- **The per-user GET** (`Invoke("Security.User","GET")` with `name`) returns `Roles` (array), `EscalationRoles`, `ExpirationDate`, `AccountNeverExpires`, `PasswordNeverExpires`, `ChangePassword`, `Enabled` and `NameSpace` (GET spelling). It returns no password. Timing: 100 GETs took 30.5 ms and 20 LISTs took 30.2 ms, in process.
- **Classic page.** `%CSP.UI.Portal.Users` is compiled in this case, with `RESOURCE = "%Admin_Secure"` (`irislib/%CSP/UI/Portal/Users.cls:22`). Its columns are Name, Full Name, Enabled, Namespace, Routine and Type (`:68-74`). The classic list shows neither roles nor expiry.
- **Gate.** `ResourcesOR()` answers `%Admin_Secure`. `AdminPort.cls:400` switches to `%SYS`. `%DB_IRISSYS` and `%DB_IRISSECURITY` both have an empty `PublicPermission`. The permissions area already declares `%Admin_Secure:USE` (`Screen/Area.cls:41`). `Test/Screen/Gated.cls:20` already models the two-pair set `%DB_IRISSYS:READ` + `%Admin_Secure:USE`. Whether that set is sufficient on its own, or `%DB_IRISSECURITY:READ` is needed as well, needs a real principal on the throwaway (not probed).
- **Id.** `_SYSTEM` is already in both encoder corpora and encodes to itself (`ui/tools/entity-id.test.mjs:34`, `Test/EntityId.cls:37,90`). The story only needs to pin it at the route.
- **Secret fields.** None of the six LIST keys matches the credential pattern, so `secretFields: []` holds.
- **DW-186, the two engines.** `ui/tools/classic-links.mjs:101-135` `classicLinkProblem` (`exempt === true`) and `Screen/Registry.cls:596-648` `ClassicLinkProblem`, fed by `Descriptor/Base.cls:326` `''..NestedField(...)`, which treats JSON `1` as exempt.
  - The sentences differ in quoting (`"` against `'`). The unknown-archetype wording also differs.
  - Precedent for a shared corpus: `Test/ReadViewCorpus.cls` XData `Cases`, read by `ui/tools/screen-read.test.mjs:33,121` through `extractXData` from `screen-mirror.mjs`.

## Design Notes

**Governing ADs:** AD-2, AD-27 (the port and the LIST), AD-5 (one descriptor), AD-8 and AD-29 (the pair set), AD-13 (`_SYSTEM` in one segment), AD-24 (context and secret fields), AD-36 (one read for screen and tool), AD-44 (list archetype, no link-out, classic union).

**Ledger inbox:** DW-186 is to be addressed once the plan resumes, with one shared corpus class read by both engines.
- Its cases are declarations, each paired with the expected sentence or `null`.
- One sentence per refusal in both engines.
- Any `exempt` that is not a JSON boolean is refused.
- `Test/Descriptor.cls` and `classic-links.test.mjs` each run the whole corpus.

## Spec Change Log

- 2026-09-14, lead (owner-delegated decision on the plan's intent gap): amendment A accepted. AD-36 now allows one per-row detail call (`source.rowGet`) after the cap, merging declared detail fields; a 404 drops the row, any other row fault fails the read. epics.md Story 2.6 AC1 names roles from the detail call and AC2 defines expired as `ExpirationDate` set and earlier than today on the instance clock. Privilege pairs `%DB_IRISSYS:READ` + `%Admin_Secure:USE`, proven with a real principal on the throwaway (add `%DB_IRISSECURITY:READ` only if the principal proves it necessary). Re-plan from the amended text and write the intent contract now.

## Auto Run Result

Status: blocked
Blocking condition: intent gap

**The gap.** Two of Story 2.6's acceptance criteria, plus FR-35 and EXPERIENCE.md `:113`, ask for data that the one read the architecture allows cannot observe:

1. **Roles.** AC1 says the list shows "name, full name, enabled, type and roles from `GET /security/users` through `AdminPort`". The vendor `Security.User` LIST row has no `Roles` key. Roles come only from the per-user GET. The read grammar (AD-36, Story 2.3) declares exactly one `source` call, and `Read.Project` would write `null` for `Roles` on every row.
2. **Expired.** AC2 says "a user account that is disabled or expired" reads as a word. Disabled is observable: `Enabled` false renders as "No". Expired is neither a LIST field nor derivable from one. It needs the per-user GET's `ExpirationDate`, `AccountNeverExpires`, `PasswordNeverExpires` or `ChangePassword`, and "expired" has at least three readings that produce different rows:
   - account expiry date passed
   - password must be changed (the state UJ-5 calls "expired password")
   - password or account aged past the system policy

   Whether IRIS clears `Enabled` when an account's date passes was not observed (inference: it does not).

Delivering either one means changing the read architecture or narrowing a criterion. Both are the owner's call under Rule 5.

**Questions.**
- Q1: Should the users read enrich each LIST row with fields from the same endpoint's GET, through AdminPort, or should Roles leave Story 2.6?
- Q2: If expiry stays, which state is "expired", and does it render as its own column or as one state word alongside disabled?

**Recommended amendment (A, keeps UJ-1 answerable).**
- Amend AD-36's Rule and the read grammar in the spine: a `list` read may declare `source.rowGet` (the key field, the GET query parameter, and the GET fields to merge). It runs inside `Screen.Read.Execute` through AdminPort, one GET per row after the cap is applied. It is still one declared read for the screen and the tool. Measured cost is about 0.3 ms per row.
- `Registry.Validate` and `screen-mirror.mjs` both refuse a malformed `rowGet`.
- Amend Story 2.6 AC2 to name the reading. Recommended: "expired" means `ExpirationDate` is set and earlier than today on the instance clock. A Roles column renders the array joined by `, `, and a server-derived `Expired` field uses the `status` kind.

**Alternative (B, smaller, narrows the story).**
- Story 2.6 ships the LIST's six keys, which is parity with `%CSP.UI.Portal.Users`. Disabled reads "No".
- Roles and expiry move to a named later story (the User editor, or an Epic 4 read-tool story).
- FR-35 and UJ-1's "expired" answer are amended to match.

**Not blocked by the gap:** `%DB_IRISSYS:READ` + `%Admin_Secure:USE` as the pair set, to be proven sufficient and each pair necessary with a principal on the throwaway. Also `_SYSTEM` in the id route, DW-186's shared corpus, and a `users` smoke check.

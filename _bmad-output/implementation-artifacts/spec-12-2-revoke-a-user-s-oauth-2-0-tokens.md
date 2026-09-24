---
title: 'Story 12.2: Revoke a user''s OAuth 2.0 tokens'
type: 'feature'
created: '2026-09-24'
status: 'in-progress'
baseline_revision: '79f62a6ba4b3eb4cce4a7f2fcc55356a5540d000'
baseline_commit: '79f62a6ba4b3eb4cce4a7f2fcc55356a5540d000'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-12-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-7-2-user-enable-disable-delete-password-and-roles.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** An administrator cannot revoke the OAuth 2.0 access tokens this instance's authorization server issued to a user without the classic "OAuth 2.0 Administration" page. The agent cannot propose it either. An access decision therefore waits for token expiry.

**Approach:** Add one destructive row action, **Revoke OAuth 2.0 tokens**, on Permissions › Users. Its write tool, `permissions.users.revoketokens`, is also the agent's tool. The row action runs through AD-53's typed-name dialog. The agent's call mints a proposal that the user confirms (AD-6). The write is the admin API's `Security.OAuth2.Server` `REVOKE`, which is `POST /v2/security/oauth2/server/revoke?user=`. The tool reaches it through a new `Port/TokenPort` that extends `AdminPort` (AD-52), because the target's own record is the user's `Security.User` row.

## Boundaries & Constraints

**Always:**

- The tool declares `WRITETYPE` `REVOKE`, `SENDSBODY` 0, `IdParam` `user` and `Endpoint` `Security.OAuth2.Server`. It never uses the published `/v2/security/oauth2/revoke`, which answers 404.
- The revoke is sent under the account's **stored** `Name`, which the port reads from the `Security.User` `LIST` (`names=<id>`), keeping the row whose `Name` equals the id without regard to case. The kernel folds a user id to lower case (AD-13), while the vendor matches the token's `Username` exactly (measured).
- Both callers run as the caller. The pair set is the Users list's (`%Admin_Secure:USE`, `%DB_IRISSYS:READ`) plus `%Admin_OAuth2_Registration:USE`. A caller missing a pair is refused by name before any port call (AD-8).
- No token, hash or token count is read, stored, shown, logged or put in screen context (AD-3, AD-35).
- Every visible word is a `STRINGS.<key>` with a Fixed strings row, appended at the table's end. Styling uses tokens only.

**Never:**

- Edit any file under `Kernel/Proposal/**`, `Screen/Registry.cls`, `Api/Router.cls`, `ui/tools/screen-mirror.mjs`, `ui/src/app/shell/screen-outlet.ts`, `Screen/Tool/Classification.cls` or `ToolFields.cls`. This story adds no kernel mechanism and no AD-10 arm.
- Change anything of Epic 9's in `UserList.cls`. Add a self-protection rule, a free-text user dialog, revoke-by-client, or any action on the OAuth 2.0 tabs.
- Emit an OcuPilot audit event on the screen path (AD-53: the marker is the agent's).
- Name an `%Api.Admin.*` class outside `AdminPort` (AD-27).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Screen revoke | Probe user `OcuPilotTestRevoke` holds 2 tokens; `OcuPilotTestRevokeOther` holds 1 | Row menu → typed-name dialog titled "Revoke OAuth 2.0 tokens", naming the user and stating the consequence; the exact name sends `{action: "revoke-tokens", id}` → 200 `updated`; the user's 2 tokens are gone and the other's 1 remains; the row is highlighted | Mismatch keeps the button `aria-disabled`; nothing is sent |
| Other capitalization | A token stored under `ocupilottestrevoke` | Survives: the revoke matches the stored `Name` exactly (vendor behavior, measured) | None |
| No tokens | A user holding none | 200; nothing is deleted | None |
| Absent account | Id no `Security.User` row matches | 404 on the screen; the mint refuses "not present" | Nothing is sent |
| Signed-in user | Revoke the caller's own tokens | Permitted; OcuPilot's session keeps answering | None |
| Missing pair | Caller without `%Admin_OAuth2_Registration:USE` | 403 naming that pair, from the screen and from the mint | Tokens intact |
| Wildcard id | Id `OcuPilot*` | 404: no row's `Name` equals it | Nothing revoked |

</intent-contract>

## Code Map

- Vendor `%Api.Admin.Endpoints.Security.OAuth2.Server` (read on `ocupilot-slot-b`, `%SYS`):
  - `ResourcesOR()` answers `%Admin_OAuth2_Registration` for `TYPEREVOKE` (10) and `%Admin_OAuth2_Server` otherwise.
  - `NeedsRequestBody()` is a put or `CHANGEPWD`.
  - `RunRevoke` is `OAuth2.Server.AccessToken.RevokeUser(GetRequiredQueryParam("user"))` and returns `{}`. The method's count output is discarded.
  - `RevokeByProperty` refuses without `%Admin_Secure:USE` and deletes `WHERE Username = ?`.
- `src/OcuPilot/Port/TaskPort.cls` is the model for an `Invoke` override that extends `AdminPort` (61 lines). `WalletPort.cls` is the model for a port-decided 404 (`Absent`).
- `src/OcuPilot/Screen/Tool/UserPassword.cls` is the model tool: a Users-list action write with a `STATEFIELD` label row. `OAuthClientDelete.cls` is the model for `PrivilegePairs`, which appends `WRITERESOURCE`, and for the destructive removal row.
- `src/OcuPilot/Port/AdminPort.cls`:
  - `MUTATINGTYPES` :244 and `BODYLESSTYPES` :260;
  - the doc paragraphs above :244;
  - `IsMutating` :1664 and `EndpointType` :1690. `Run` is overridden, so `ImplementsRead` admits `REVOKE`.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` (read only):
  - `User` :860 with `RemovesOf` = 0 for `CHANGEACTION` `updated`;
  - `SkippedFields` :2163 skips `STATEFIELD` and the subject.

  So the arm permits revoke for any account, the caller and `_SYSTEM` included.
- `src/OcuPilot/Kernel/EntityRef.cls` :59: `user:foldcase`. Confirm's write id is the canonical id (`Confirm.cls` :579), which is why the port resolves the stored name.
- `UserList.cls`: plan against `git show origin/OCU-1-epic9:src/OcuPilot/Screen/Descriptor/UserList.cls`, whose `rowActions` end with `delete`.
- `ui/src/app/core/screen-actions.ts`: the UserList labels are at :98. Epic 9 does not touch this file.
- `ui/src/app/shell/screen-action-handler.ts`:
  - `DESTRUCTIVE_ACTIONS` :135 and `DESTRUCTIVE_CONSEQUENCES` :145 on this branch;
  - :173 and :187 on `origin/OCU-1-epic9`, which rewrites 290 lines of this file.
- `ui/src/app/core/strings.ts`: the Users strings are at :1545. Append before `} as const;` :1691. EXPERIENCE.md's Fixed strings table ends at :467.
- Test precedents:
  - `Test/UserUpdate.cls` :292 is a mint → confirm with ledger `AuditMarked` (AD-15), and :425 is a lost pair refused by name.
  - `Test/OAuthDelete.cls` :197-229: the OAuth family's bodyless roster is "exactly the two deletes" at :226.
  - `Test/ToolWrite.cls` :1126 holds `MUTATINGTYPES` equal to the reached pairs.
  - The tool rosters are `ReadTool.cls` :94, `ToolRoundTrip.cls` `REFUSEEMPTY` :35 and `SurfaceCoverage.cls` :125-127.
  - `ui/browser/oauth-delete.browser-spec.mjs` is the model for a typed-name row-action leg (`irisSession`, `clickRowCentre`). `structural-walk.mjs` exports `detectScreen`, `collapse`, `compare`, `readBaseline` and `INVARIANTS`.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Port/TokenPort.cls` (new, extends `AdminPort`) -- override `Invoke` for endpoint `Security.OAuth2.Server` only:
  - `HOLDER`: call `##super("Security.User", "LIST", names=<pQuery("user")>)` and answer the one row whose `Name` equals the id without regard to case. With no such row, answer 404 on the `not_found` slug.
  - `REVOKE`: run the same lookup. On a 404 nothing is sent. Otherwise set `pQuery("user")` to the row's stored `Name` and call `##super`.
  - Every other call is `##super` unchanged. The class names no `%Api.Admin` class.
- `src/OcuPilot/Screen/Tool/UserTokenRevoke.cls` (new) -- the tool:
  - `TOOLNAME` `permissions.users.revoketokens`, `DESCRIPTORCLASS` UserList, `SCREENACTIONS` `revoke-tokens`;
  - `PORTCLASS` TokenPort, `READTYPE` `HOLDER`, `WRITETYPE` `REVOKE`, `SENDSBODY` 0;
  - `CHANGEACTION` `updated`, `DESTRUCTIVE` 1;
  - `READANSWERS` `Name,FullName,Namespace,Routine,Type,Enabled`, `PRECONDITIONFIELD` and `FINGERPRINTSUBJECT` `Name`, `STATEFIELD` `OAuthTokens`;
  - `WRITERESOURCE` `%Admin_OAuth2_Registration`:`USE` through `PrivilegePairs`, as in `OAuthClientDelete`;
  - `Endpoint` `Security.OAuth2.Server`, `IdArgument` `Name`, `IdParam` `user`.

  Its `StateDiff` answers one row, `{field: "OAuthTokens", before: <Name>, after: "", removed: 1}`. A read with no `Name` is a problem. Its `DESCRIPTION` and the id's schema description say that the call revokes every token this instance issued to the account, that it takes the account's name exactly as the users list reports it, and that it changes nothing until the user confirms.
- `src/OcuPilot/Screen/Descriptor/UserList.cls` -- re-read the Epic 9 version immediately before editing:
  - append `{"id": "revoke-tokens", "selfProtection": ""}` after `delete`;
  - append one doc `<p>` naming the eighth row action and its tool.

  Change nothing else.
- `src/OcuPilot/Port/AdminPort.cls` -- append `Security.OAuth2.Server/REVOKE` to `MUTATINGTYPES` and to `BODYLESSTYPES`, with one doc paragraph of the measured facts (this spec's Design Notes). Read the Epic 9 version first and add only this entry.
- `ui/src/app/core/screen-actions.ts` -- add `'revoke-tokens': STRINGS.userActionRevokeTokens` under UserList.
- `ui/src/app/shell/screen-action-handler.ts` -- re-read `origin/OCU-1-epic9`'s version first. Add `'revoke-tokens'` to `DESTRUCTIVE_ACTIONS` and `'revoke-tokens': STRINGS.userRevokeTokensConsequence` under `USER_LIST`. Change no other line.
- `ui/src/app/core/strings.ts` and EXPERIENCE.md:
  - append `userActionRevokeTokens: 'Revoke OAuth 2.0 tokens'`;
  - append `userRevokeTokensConsequence: 'Revoking deletes every OAuth 2.0 access token this instance issued under this user name, and applications holding one must sign the user in again. This cannot be undone.'`;
  - append one Fixed strings row at the table's end (Story 12.2, FR-75).
- `ui/src/app/core/screens.generated.ts` -- regenerate with `node tools/screen-mirror.mjs`. Never hand-edit it.
- `src/OcuPilot/Test/TokenProbe.cls` (new) -- the fixture `Create()`, `Count(pName)` (exact) and `Remove()`. It creates the probe users and `OAuth2.Server.AccessToken` rows in `%SYS` under the `OcuPilotTestRevoke` code prefix: 2 for `OcuPilotTestRevoke`, 1 for `ocupilottestrevoke` and 1 for `OcuPilotTestRevokeOther`. It uses AD-16's save and restore. Rows are created directly because the throwaway has no authorization server (a stand-in for issuance). Remove objects by exact name only.
- `src/OcuPilot/Test/TokenRevoke.cls` (new, <500 lines) -- legs:
  - the declarations and the resolved pair set;
  - the port's `HOLDER` for a re-cased id, an absent id and `OcuPilot*`;
  - the screen route over the matrix, with exact counts;
  - mint → confirm, with the tokens gone and the ledger `AuditMarked` yes;
  - the prohibited set permitting the caller and `_SYSTEM`;
  - a principal holding the list's pairs only, refused 403 naming `%Admin_OAuth2_Registration`. `TokenProbe` creates this principal as `OcuPilotTestRevokePrincipal`, and the leg's request is made as that principal.

  The class creates principals, so it arms `OCUPILOT_ALLOW_PRINCIPALS`. Add it to that block's `# classes:` roster in `scripts/ci-throwaway.sh` and wherever `ui/tools/ci.test.mjs` pins that roster.
- Rosters, this story's member only:
  - `OAuthDelete.cls` :226 gains `permissions.users.revoketokens`;
  - `ReadTool.cls` :94 gets the name and the counts;
  - `ToolRoundTrip.cls` `REFUSEEMPTY` gets `permissions.users.revoketokens:TOOL.ARGUMENTS`;
  - `SurfaceCoverage.cls` gets a row pointing at `TokenRevoke`.
- `ui/src/app/shell/screen-action-revoke.spec.ts` (new file; the handler spec is Epic 9's hot spot) -- `revoke-tokens` opens the typed-name dialog with the verb, the row name and the consequence, and it sends only after the exact name.
- `ui/browser/token-revoke.browser-spec.mjs` (new) -- modeled on `oauth-delete`:
  - `before` refuses the live container and calls `TokenProbe.Create()`; `after` calls `Remove()`.
  - Filter to the probe row and run Revoke from the row menu. Assert the dialog title, the consequence and the disabled button. Type the name and confirm.
  - Assert one action request, then exact counts 0 / 1 / 1.
  - With the dialog open, run `detectScreen` at 1280 light (`INVARIANTS`), at 720 light (`name`, `min-width`, `overflow`) and at 1280 dark (`contrast`), each with `route: 'permissions/users'`, and assert that `compare(...).fresh` is empty.

- [ ] [CI] browser: `ui/browser/users-actions.browser-spec.mjs:236` (test 274, run 36006886901) pins the Users row menu as six actions; this story adds a seventh. Add `STRINGS.userActionRevokeTokens` after `STRINGS.actionDelete` in that roster, make the message say seven, and change no other line (Epic 9 edits this file's later legs). Verify with that one browser file over a rebuilt, redeployed bundle, and record its mutation (drop the revoke row action → red).

**Acceptance Criteria:**

- **AC1.** Given a user with issued tokens, when an administrator revokes them from the Users list's row action and types the user's name, then every token stored under that account's name is deleted, other users' tokens remain, and the write ran with the caller's own privileges.
- **AC2.** Given the agent proposes `permissions.users.revoketokens` for a user, when the proposal is minted, then it is destructive and names the user (its target and its `OAuthTokens` row), and nothing is revoked. When the user confirms it, the tokens are deleted and the audit database carries OcuPilot's marked event for that proposal (AD-15).
- **AC3.** Given a caller without `%Admin_OAuth2_Registration:USE`, when either caller attempts the revoke, then it is refused 403 naming that pair before any port call, and no token is touched.
- **AC4 (DW-1337).** Given the revoke dialog open on the Users list, when it is measured at 1280 px light, 720 px light and 1280 px dark, then no structural or contrast violation is found beyond the baseline's existing entries for `permissions/users`.

### Review Findings

Code review 2026-09-24 (four layers, `full-opus`). Fields: severity · fix-risk · footprint · spec-status.

- [x] [Review][Patch] The tool's `DESCRIPTION`, schema description, class doc and the `UserList` paragraph said every token issued to the account is revoked; only tokens under the stored-name spelling are (the matrix's "Other capitalization" row). Now worded "under the account's stored name", naming the other-capitalization case [`Screen/Tool/UserTokenRevoke.cls`, `Screen/Descriptor/UserList.cls`] · med · low (text only) · in-story · clear
- [x] [Review][Patch] `TokenProbe` and `TokenRevoke` docs and refusal texts counted three accounts and one role after QA added the self-caller [`Test/TokenProbe.cls`, `Test/TokenRevoke.cls`] · low · low · in-story · clear
- [x] [Review][Patch] The screen-route leg's doc cited `<parameter>SELFCALLER</parameter>`, a `TokenProbe` parameter, and argued its own case [`Test/TokenRevoke.cls`] · low · low · in-story · clear
- [x] [Review][Patch] The self-caller's signed-in session was never signed out before `Remove()`; the leg now calls `OcuPilot.Test.Token.Logout` [`Test/TokenRevoke.cls`] · low · low · in-story · clear
- [x] [Review][Patch] AC3's count assertion was labeled "before any port call", which counts cannot show because the vendor also refuses this principal; relabeled, and the doc names the gate order as the kernel's [`Test/TokenRevoke.cls`] · low · low · in-story · clear
- [x] [Review][Patch] The `UserList` label block's comment still read "three value-carrying row actions" [`ui/src/app/core/screen-actions.ts`] · low · low · in-story · clear
- [x] [Review][Patch] The browser leg's "re-cased name sends nothing" check read `writes` before a frame had passed [`ui/browser/token-revoke.browser-spec.mjs`] · low · low · in-story · clear
- [x] [Review][Patch] `TokenPort.Invoke` set `pHttpStatus` to 0 just before `Fail`, which sets it [`Port/TokenPort.cls`] · low · low · in-story · clear
- [x] [Review][Patch] AC2's marker assertion had no demonstrated red (Rule 19); mutation applied, observed and recorded under Verification · low · low · in-story · clear
- [x] [Review][Patch] The component spec's "no self-protection" test had no mutation of its own (Rule 19); applied, observed and recorded under Verification · low · low · in-story · clear
- [x] [Review][Defer] AD-15's "either record locates the other" cannot hold for the agent's revoke, since the vendor records no event, and only AD-53 (screen path) names that gap [spine AD-15] — deferred: DW-1616 `escalated owner=burndown`; a one-line AD-15 named case for the lead (Rule 20), with no code change · med · low · out-of-footprint · clear

Rejected:

- The Auto Run Result's review tally and its "no demonstrated red" residual risk are stale: the fix edits the spec under review. The QA `mutation:` line supersedes the residual-risk claim.
- The self-revoke leg "cannot see" the session property: false. The same bearer answering `/navigation` after the revoke is the matrix outcome, and a revocable session would make it fail.
- QA's changes are uncommitted and earlier verification predates them: not a code defect. This pass re-ran `TokenRevoke` (run 486), `ToolWrite` (run 487) and the browser spec on the current tree.
- The prohibited-set loop's caller case may duplicate `_SYSTEM`: low. The self-caller leg exercises caller-equals-target through the real route.
- The dialog title reads "Revoke OAuth 2.0 tokens <name>": by-design. The verb string and the title's shape are the spec's and EXPERIENCE.md :468.
- Tokens of a deleted account or of a non-IRIS holder are unreachable (404): by-design (Design Notes trade-off; the "Absent account" row).
- Tokens under another capitalization survive the revoke: by-design (the "Other capitalization" row). Only the wording was patched.
- `Holder` skips a `Name` the `LIST` answers as a JSON number: wontfix-theoretical, real only for an account named only in digits and serialized as a number.
- The agent-side AC3 refusal uses `DenyPair` rather than the principal: false. It matches the spec's task, and the principal's missing pair is checked on the route and through `HoldsPair`.
- `UserList`'s leading comma: false. It is deliberate, so Epic 9's `delete` line stays byte-identical.
- `ci-throwaway.sh`'s roster line position: low and cosmetic, since the roster check sorts.

## Spec Change Log

- 2026-09-24, rework 1 (runner): CI run 36006886901 failed in `browser` on `users-actions.browser-spec.mjs`, the Users menu roster. The spec is re-opened with one `[CI]` task.

- 2026-09-24, spec gate (runner): the orchestrator took all four recommendations. AD-8 is widened, with this tool as its named case. AD-53 carries the named gap. EXPERIENCE.md rows :148, :166 and :168 were amended in place, with no line-count change. `screen-action-handler.ts` is allowed two appended map entries, read from `origin/OCU-1-epic9` immediately before editing. AC3's pinning test must redden when the declared pair is removed (already the planned mutation). No task changes.

## Review Triage Log

### 2026-09-24 — Review pass

- verdicts: 13 findings — high 0, medium 6, low 5, false 2, maybe-false 0
- findings:
  - `[medium]` `[patch]` Self-revoke "session keeps answering" leg used fresh Basic auth, so it could not fail — the leg now signs in via `/login`, revokes the caller's own tokens with that bearer, and asserts the same bearer still answers `/navigation`.
  - `[medium]` `[patch]` AC4 overflow cannot see inside the scroll-container dialog body; the named 1400px mutation stayed green — the browser spec asserts `.ocu-dialog-body` `scrollWidth <= clientWidth` on every pass; the named mutation now reddens it.
  - `[low]` `[patch]` Browser leg named as an AC1 pin had no AC1 mutation — `WRITETYPE` `DELETE` recompiled on the throwaway reddens it; line recorded.
  - `[medium]` `[patch]` AC3 agent side re-ran `HoldsPair` rather than observing a dispatch refusal — `DispatchRefusal` drives the shipped chain through `ToolDispatchProbe` over the shipped registry and asserts `1|AUTH.NOPRIVILEGE|%Admin_OAuth2_Registration:USE` with counts intact; the `WRITERESOURCE` mutation reddens it.
  - `[low]` `[patch]` AC2 read the ledger's `AuditMarked` rather than the audit row — the leg now asserts one `AuditMarker.MarkerRows` row naming the proposal id.
  - `[low]` `[reject]` "No tokens" is exercised as a second revoke of the drained holder, not a never-held account — the state is the same (a user holding none) and the vendor path is identical; no realistic difference.
  - `[medium]` `[patch]` (grouped with the session finding) Signed-in reading C1 not observed — same patch.
  - `[medium]` `[patch]` (grouped with the AC3 finding) Missing-pair "from the mint" was a declared-pairs check — same patch.
  - `[low]` `[reject]` Agent path is pinned by in-process kernel calls, not the chat wire or the card UI — the spec's task names the mint → confirm tier (the `UserUpdate` precedent), and the dispatch refusal is now driven; the generic wire is pinned elsewhere.
  - `[false]` `[reject]` No test checks that a proposal, response or context carries no token count — nothing can: the port reads only `Security.User`, and no admin endpoint answers token state.
  - `[low]` `[patch]` No check that the screen path emits no agent marker (AD-53) — the screen leg asserts `MarkerRows(since, tool) = 0`.
  - `[false]` `[reject]` The card's `OAuthTokens` label is not a `STRINGS` key — the card draws the instance's field names for every write tool (`State`, `Total`, `NextScheduled`; AD-3, the instance owns the diff).
  - `[medium]` `[patch]` (grouped with the AC4 finding) The recorded AC4 mutation did not falsify — same patch.

## Design Notes

**Governing ADs:** AD-2, AD-3, AD-6, AD-8, AD-10, AD-13, AD-14, AD-15, AD-24, AD-27, AD-29, AD-34, AD-35, AD-40, AD-51, AD-52, AD-53, AD-56. The DW-1337 gate applies. AD-4 is not engaged, because nothing is sent.

- **Why the Users list, not an OAuth 2.0 tab.**
  - The action's subject is a user, and AD-13 makes the proposal's target the entity the id names. On the Authorization server tab the id would have to be the configuration, and the user would become a query argument that the write path cannot carry.
  - Such a tab action would also need a new value-dialog kind, an AD-10 arm for `oauth2-server` (in `Prohibited.cls`, which is contended), a fresh read gated on `%Admin_OAuth2_Server`, and a third privilege pair. It would disappear whenever no server is configured.
  - The Users row already has the typed-name dialog, and the list already holds the `%Admin_Secure:USE` that the vendor class checks.
  - The trade-off: token holders that are not IRIS accounts, which a custom `ValidateUserClass` can mint, are not reachable (inference: rare). The classic page takes free text.
- **Why a port.** One `Endpoint` serves both the read and the write. `TokenPort` answers the tool's read type `HOLDER` from `Security.User` `LIST` and routes `REVOKE` to the vendor under the stored name, so the mint, the confirm's re-read, the prohibited set and the screen route all read the user (the TaskPort and WalletPort precedent, AD-52). The `GET` does not answer `Name` (measured), hence the `LIST`.
- **The fingerprint subject is `Name`** (AD-51 adequacy). It is the one field the write's precondition reads: the port addresses the revoke by it. No token state is readable through any admin endpoint.
- **No self-protection.** OcuPilot's JWT pair is not an `OAuth2.Server.AccessToken` row. After a login the table held 0 rows, and after revoking `_SYSTEM`'s tokens that same bearer still answered 200. Revoking touches no AD-10 effect, so the action stays permitted behind the typed confirmation (owner, 2026-09-23).
- **No new AD-27 case.** The admin API carries the whole call. It drops only the vendor's revoked count, which no AC asks for.
- **Measured on `ocupilot-b-ci`, 2026-09-24.** Probe users, roles and tokens were removed by exact name. Afterwards the throwaway held 0 tokens and none of the probe principals.

  | Probe | Answer |
  | --- | --- |
  | `POST …/server/revoke?user=<unknown>` | 200 `{}` |
  | Same call for a user holding 2 tokens | 200 `{}`; both deleted, and a token under the lower-cased spelling survived |
  | No `user` | 400 `#40300` |
  | `user=` | 200 `{}` |
  | `POST …/oauth2/revoke` | 404, empty body |
  | `GET …/oauth2/server` | 404 `#8864` (no server configured) |
  | Principal with `%Admin_OAuth2_Registration:U` only | 500 `#921` "requires %Admin_Secure:USE" |
  | Principal with `%Admin_Secure:U` only | 403 |
  | Principal with both | 200 |
  | Audit after a revoke | no vendor event recorded (auditing on) |
  | `users?names=_system` | row `Name` `_SYSTEM` |
  | `names=_S*` | wildcard match |
  | `GET user?name=_system` | no `Name` key |

- **Contention.**
  - `UserList.cls` is append-only.
  - `screen-action-handler.ts` and `AdminPort.cls` take own entries only; read the Epic 9 versions first.
  - `strings.ts`, EXPERIENCE.md and the rosters are shared-append.
  - The bundle grows by two strings and two map entries, far below 1378 kB.
- **Integration ACs.** `TokenPort` is introduced, and its one consumer is this story's tool through the mint, the confirm and the screen route (AC1, AC2). Consumes: Story 7.2's Users row actions, AD-53's route and the typed-name dialog. Consumed-by: none.
- **Ledger inbox:** empty.
- **Rulings applied at the spec gate (orchestrator, 2026-09-24):** AD-8 now names this tool's `%Admin_OAuth2_Registration:USE` as its second pair exception (vendor `ResourcesOR()`, measured). AD-53 records the no-audit-row gap for the screen path. EXPERIENCE.md :148, :166 and :168 were amended in place. `screen-action-handler.ts` takes the two map entries only, under the contended-edit discipline.

## Verification

Slot B. Every IRIS MCP call carries `server: "ocupilot-slot-b"`. Stateful runs happen on `ocupilot-b-ci` only (web 52777, super 1976). Run one test class per call, and wait until it lands in `%UnitTest_Result` before sending the next.

**Commands:**

- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/` (loop) -- expected: the bundle under test is the one just built.
- `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/token-revoke.browser-spec.mjs` (loop) -- expected: every leg passes.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class <C>`, one call each for `TokenRevoke`, `OAuthDelete`, `ToolWrite`, `ToolRoundTrip`, `ReadTool` and `SurfaceCoverage` (loop) -- expected: 0 failures each.
- `cd ui && npm run test:components && npm run test:tools && node tools/screen-mirror.mjs --check` (loop) -- expected: 0 failures, no drift.
- `uv run scripts/check-objectscript.py <changed .cls> && bash scripts/lint-docs.sh` (loop) -- expected: clean.
- The full ObjectScript sweep on `ocupilot-b-ci`, one class per call, with totals checked against `%UnitTest_Result` (once, before dev_complete) -- expected: 0 failed and a non-zero count.
- `cd ui && npm run build && npm test`, then `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` (once, before dev_complete) -- expected: green, and a non-zero smoke count.
- The full browser suite is not run locally. CI's `browser` job runs it (Rule 29).

**Pinning tests and mutations (Rule 19; the implementer records each as `mutation: … → …`):**

- AC1: the `TokenRevoke` screen leg and the browser leg. Mutations: the port sends the id as given rather than the stored `Name` (the re-cased leg goes red); `WRITETYPE` `DELETE`.
- AC2: the `TokenRevoke` mint and confirm leg. Mutations: `DESTRUCTIVE` 0; drop `STATEFIELD`'s row.
- AC3: the least-privilege leg. Mutation: drop `WRITERESOURCE` from `PrivilegePairs`.
- AC4: the browser structural assertion. Mutation: give the consequence text a 1400px `min-inline-size` in the dialog.

- mutation: `TokenPort.Invoke` sends `user` as given, reloaded on `ocupilot-b-ci` → `TokenRevoke.TestTheScreenRouteRevokesExactlyTheAccountsTokens` and `TestTheAgentsRevokeIsMintedDestructiveAndConfirmedMarked` red (AC1)
- mutation: `UserTokenRevoke.WRITETYPE` `DELETE` → the screen-route, agent and declaration legs red, 501 `PORT.NOTIMPLEMENTED` (AC1)
- mutation: `UserTokenRevoke.DESTRUCTIVE` 0 → `TestTheAgentsRevokeIsMintedDestructiveAndConfirmedMarked` red on "and is destructive" (AC2)
- mutation: `UserTokenRevoke.StateDiff` pushes no row → `TestTheAgentsRevokeIsMintedDestructiveAndConfirmedMarked` red on "one removal row naming the account" (AC2)
- mutation: `WRITERESOURCE` dropped from `UserTokenRevoke.PrivilegePairs` → `TestAPrincipalWithoutTheRegistrationPairIsRefusedByName` red on the principal pair check, the shipped dispatch chain's refusal and the screen route (403 `PORT.ACCESSDENIED`, no `failedPair`), and the declaration leg red (AC3)
- mutation: `.ocu-typed-name-consequence` `min-inline-size: 1400px`, rebuilt and redeployed → `token-revoke.browser-spec.mjs` red on the dialog-body overflow assertion (`scroll` 1400 > `client` 390) (AC4)
- mutation: the dialog's `.ocu-button-destructive` drawn 12px wide (border-box), rebuilt and redeployed → `token-revoke.browser-spec.mjs` red on `min-width` at 1280 and 720 (AC4)
- mutation: `.ocu-theme-dark .ocu-typed-name-consequence` colored `--ocu-surface-container-lowest`, rebuilt and redeployed → `token-revoke.browser-spec.mjs` red on dark `contrast` 1:1 (AC4)
- mutation: `'revoke-tokens'` dropped from `DESTRUCTIVE_ACTIONS` → `screen-action-revoke.spec.ts` both tests red
- mutation: `UserTokenRevoke.CHANGEACTION` `deleted` → `TestTheProhibitedSetPermitsTheCallerAndTheSystemAccount` red for the caller and `_SYSTEM`
- mutation: `TokenPort.Holder` compares `Name` exactly → the port, screen-route and agent legs red
- mutation: `UserTokenRevoke.WRITETYPE` `DELETE`, recompiled on `ocupilot-b-ci` → `token-revoke.browser-spec.mjs` red: the list never marks the row (AC1, browser)
- (QA) mutation: `TokenPort.Invoke`'s `REVOKE` branch also disables the resolved account after a successful revoke (a plausible "revoke also kills the caller's own session" regression), recompiled on `ocupilot-b-ci` → `TokenRevoke.TestTheScreenRouteRevokesExactlyTheAccountsTokens` red on "and the same access token still answers" (AC1, signed-in-user leg). The leg was switched from the shared `_SYSTEM` test account to a dedicated `TokenProbe.SELFCALLER` account holding all three required pairs, so the account this mutation disables is the fixture's own and safe to touch on the shared throwaway; reverted, `git diff --stat` clean, class green again (run 484).
- (CR) mutation: `Kernel/Audit/Event.RecordAgentWrite` writes an empty `proposalId`, compiled on `ocupilot-b-ci` only → `TestTheAgentsRevokeIsMintedDestructiveAndConfirmedMarked` red on "one agent-write marker naming this proposal" alone, with the ledger's `AuditMarked` still green (run 485); reverted, green (run 486) (AC2)
- (CR) mutation: `UserList.cls` `revoke-tokens` given `protected-account`, mirror regenerated → `screen-action-revoke.spec.ts` both tests red; reverted, mirror regenerated, tree byte-identical (matrix "Signed-in user", client)

## Auto Run Result

Status: done
Blocking condition: none

- **Change:** the Users list's destructive `revoke-tokens` row action and the agent tool `permissions.users.revoketokens` (`Security.OAuth2.Server` `REVOKE`, bodyless), through the new `Port/TokenPort` (`HOLDER` from the `Security.User` `LIST`; revoke under the stored `Name`; 404 for an absent id or a wildcard). Pairs: the list's two plus `%Admin_OAuth2_Registration:USE`.
- **Files:**
  - new: `Port/TokenPort.cls`, `Screen/Tool/UserTokenRevoke.cls`, `Test/TokenProbe.cls` (fixture), `Test/TokenRevoke.cls` (6 legs), `ui/browser/token-revoke.browser-spec.mjs`, `ui/src/app/shell/screen-action-revoke.spec.ts`;
  - appended: `AdminPort.cls` (roster entries and doc), `UserList.cls` (row action and doc), `screen-action-handler.ts` (two map entries), `screen-actions.ts`, `strings.ts`, EXPERIENCE.md :468, `screens.generated.ts` (regenerated);
  - rosters: `OAuthDelete`, `ReadTool`, `ToolRoundTrip`, `SurfaceCoverage`, the `ci-throwaway.sh` arming roster;
  - outside the spec's list, each required by an existing test: `PortFixture.cls` `MUTATINGTYPES`, `ProhibitedRoute.cls` (users write verbs four to five), `PortGate.cls` `ROSTER` (the sweep reddened without the `TokenPort` row), and one line in `screen-action-handler.spec.ts`.
- **Review:** 13 findings. 6 medium and 5 low were patched (tests only), and the review pass records every finding with its reason. Rejected: 2 low (the "no tokens" state is the same; the agent tier is the one the spec names) and 2 false (no token state is readable; the card draws the instance's field names). Nothing deferred.
- **Follow-up review recommended: true.** First pass, and three medium entries were patched. The named unverified risk: the new bearer-held self-revoke leg has no demonstrated red, because making OcuPilot's session revocable is not a mutation this story can apply.
- **Verification:**
  - Throwaway `ocupilot-b-ci` holds this tree (`src` identical).
  - Full ObjectScript sweep: 224 classes, 1997 tests, 0 failed after the `PortGate` roster fix and its re-run (checked against `%UnitTest_Result`).
  - Client: `npm run build` at 1.32 MB initial (no budget warning); `npm test` 1375 tools and 1046 components green.
  - `token-revoke.browser-spec.mjs` green on a redeployed bundle.
  - `smoke.sh`: 49/49.
  - `check-objectscript`, `lint-docs` and `screen-mirror --check` clean. The secrets scan printed 0.
- **Residual risks:**
  - Merging with `origin/OCU-1-epic9` will give append-only conflicts, each resolved by keeping both sides: the single-line rosters in `ReadTool` and `ToolRoundTrip`, and the ends of `strings.ts` and EXPERIENCE.md. `UserList`, `screen-action-handler.ts`, `AdminPort` and `ci-throwaway.sh` merge clean (simulated).
  - The AC3 agent-side refusal is driven through `ToolDispatchProbe` with the pair denied, and the real principal's missing pair is checked separately.

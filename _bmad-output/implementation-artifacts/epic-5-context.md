# Epic 5 Context: Propose, confirm, and find it in the audit database

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

A user asks the agent to change something, reviews a diff the **instance** computed from a fresh read,
presses Confirm, watches the affected screen re-fetch and highlight what changed, and then finds that
same change in the IRIS audit database marked as having come through the agent — in **each** of the six
areas. This is the product's entire claim and the end of build step 2: SM-3 (six areas, six confirmed
writes) and SM-4 (the one-minute demo) are both met here. Stories 5.1 to 5.7 build the write path once —
the server-minted proposal, the card, confirm as one atomic transition, execution as the user, the
prohibited set, the audit marker, the change-event bus — and 5.8 to 5.13 exercise it once per area.

## Stories

All 14 are backlog. 5.0 was inserted at the retro-review gate as this epic's x0 cleanup story.

- Story 5.0: Epic 4 deferred cleanup (x0, 12 routed ledger items)
- Story 5.1: The proposal is minted on the instance, from a fresh read
- Story 5.2: The proposal card — the diff the user reviews
- Story 5.3: Confirm is user-originated, and the write is one atomic transition
- Story 5.4: Execution strictly as the user
- Story 5.5: Prohibited actions are absent from the tool set
- Story 5.6: The agent marker, and what happens when it fails
- Story 5.7: The screen shows the change
- Story 5.8: Web applications — enable a disabled application and grant it a resource
- Story 5.9: Permissions — the area's first confirmed user write
- Story 5.10: Security and secrets — disable and re-enable auditing
- Story 5.11: Tasks — resume a task suspended after an error
- Story 5.12: OS management — suspend and resume a process
- Story 5.13: Logs — delete application errors by namespace

## Requirements & Constraints

- **The instance mints the proposal; the client never authors one.** It holds a server-issued
  unguessable id, the user, the conversation, the tool, the full resolved arguments, the scoped target
  identity, a fingerprint of the target **as freshly read at proposal time**, the diff and a single-use
  token. Expiry is a server-side 10 minutes. A write tool call with no valid, unexpired, unburned token
  is refused by **the write path itself**, not by its caller. Secret-typed values are never stored and
  were never accepted from the model.
- **Target identity is the triple `(entity type, scope, id)`** — the namespace for a namespace-scoped
  object, the literal `instance` for a configuration object — so a confirm cannot re-read a different
  `Nightly purge`. The fingerprint covers the **complete property set the write will send**, minus only
  side-effect fields (next-scheduled time, last-modified stamp) declared in the descriptor; a slice never
  picks its own fingerprint fields.
- **The payload is the whole object; the diff is what the user reviews.** Read fresh, apply the diff,
  send the complete merged set, merging over the fresh read's whole object rather than a derived field
  list.
- **Confirm is a separate, authenticated, user-originated request** carrying the proposal id and only
  the descriptor's declared secret fields — any other key is **rejected outright, not ignored** — and
  executes the **stored** arguments. Only the minting user can confirm. It re-evaluates privileges,
  enforced read-only, the per-user read-only state, the definition's read-only flag and the kill switch,
  re-reads the target, and refuses on all five FR-17 conditions: user, conversation, definition,
  read-only state, fingerprint.
- **Execution is strictly as the user**: in-process, no service account, no credential but the user's
  own. The **full** tool set is always advertised — privilege is checked at call time, never by hiding
  tools — and a tool's 403 is the screen's 403, reported and never retried. Any token held during a turn
  lives in process memory only. A metric, log line or audit row reaches a user only if that user could
  have read it directly.
- **Prohibited actions are absent from the tool set, defined by effect not verb**: deleting or disabling
  the current user, the last `%All` holder or `_SYSTEM`; **granting privilege through any path** (a web
  application's `MatchRoles`/`Roles`, a role added to a resource, `%All` or any `%Admin_*` added to a
  user or role); disabling OcuPilot's web application, the web service behind it or the superserver;
  terminating IRIS system processes; deleting OcuPilot's own applications, resource, role or database.
  Governance can disable a permitted tool and can never enable a prohibited one. A screen's
  self-protection rule is an affordance, never the prohibition.
- **Every confirmed write emits a marker** — proposal id, tool, target identity, user — alongside the
  vendor's own change event, either record locating the other; the same change made by hand emits none. A
  failed marker never fails the write and never propagates: it is recorded on the ledger row and shown as
  "done · audit not marked" on the tool-call card's **collapsed** line. Auditing off shows the panel
  banner "Agent writes are not being marked. Auditing is off on this instance." to every user.
- **A confirmed write publishes one change event and the screen re-fetches in place**, preserving sort,
  filter, selection and scroll and highlighting within **two seconds**. No screen mutates its own rows
  from a write response; a screen editor's Save publishes to the same bus; the bus does not cross tabs.
- **The six area writes.** A web application enabled and given a resource (5.8); a routine account
  change (5.9); auditing disabled **and** re-enabled as a single demo sequence, never a resting state
  (5.10); a suspended task resumed (5.11); a process suspended and resumed (5.12); a namespace's
  application errors deleted (5.13).

## Technical Decisions

- **Governing ADs.** 5.1: AD-6, 4, 13, 3, 35, 43. 5.2: AD-6, 39, 11. 5.3: AD-40, 34, 6, 8, 30. 5.4:
  AD-1, 8, 9, 29, 31. 5.5: AD-10, 34, 40. 5.6: AD-15, 41, 46. 5.7: AD-14, 43, 13. The area stories add
  AD-2, and 5.13 adds AD-48. AD-7, AD-9, AD-33 and AD-12/AD-39 hold throughout.
- **The confirm barrier is explicit because in-process tools removed the HTTP one.** The kernel carries
  an "acting on behalf of the model" marker through the turn job and every tool call; confirm is not a
  tool, is not in the registry, and refuses any call whose originating context is a turn. A proposal
  whose turn ended **abnormally** is not confirmable; a turn that ended normally leaves its proposals
  confirmable until their own expiry — and a turn ends the moment it emits the card, so the ordinary path
  must not trip this. The turn record carries its terminal state and outlives the job for at least the
  expiry window.
- **Every write gate is evaluated at the write, inside one atomic transition**, never at the tool call
  that minted the proposal. Burning the token and committing are one transition under a lock or
  conditional update exactly one caller wins; the loser is refused with the terminal state, never
  retried. Siblings on the same scoped target are canceled **in that same transition**. Prohibited-set
  predicates read live state (who holds `%All`, which application serves OcuPilot) so they run inside it
  too, and the set has **exactly one home in the kernel** — never a screen, descriptor or policy file,
  and never a match on request fields.
- **Merge is OcuPilot's, not the API's.** Only 19 of 47 vendor `RunPut` implementations merge; the 28
  that do not include `Security.User`, `Task.CRUD`, `Security.Resource`, `Security.X509Credential`,
  `Wallet.Secret`, `Security.Audit.Event` and all four `Security.OAuth2.*`. `Wallet.Secret` and
  `Security.Audit.Event` PUTs are **upserts**, so a body against a target deleted since the read creates
  a stub — which the fresh read plus fingerprint covers. `Process`, `Lock` and `Task.Manager` publish
  **no body template** and are action-style with a trivial body, never a hand-typed field list;
  `Security.Audit.Event`'s field list is derived from the underlying class and pinned by a test.
- **Field lists and secret classification come from the build-time derivation**, not from a story: an
  unclassified derived field is emitted `secret`, and a credential-pattern string placeholder that is not
  classified secret fails the build. Redaction is schema-driven with the name pattern as an add-only
  backstop.
- **The entity-type vocabulary is one closed enum owned by the kernel** and the build fails on an
  unknown value. Change events, proposal targets, highlight targets and audit markers all carry the
  scoped triple, ids percent-encoded in one segment by the single shared encode/decode pair.
- **Audit events must be registered.** `$System.Security.Audit()` silently returns 0 and drops the
  event when its Source/Type/Name triple was never created, so the return value is checked.
- **5.13 has no admin API endpoint and no invariant relaxes.** It goes through
  `SYS.ApplicationError.DeleteByNamespace` with one explicit save/restore to `%SYS` and the target
  namespace as a **parameter**; the namespace is the drilled level carried in descriptor state and the
  route's `?ns=` does not reach the port; the gate resolves **per namespace** at call time; the
  fingerprint is the **enumerated id set** captured at proposal time, never a count and never a
  re-query, and confirm deletes exactly those ids; the read tool returns summary fields only — the
  captured variable tables never reach the model.
- **Proposal state is OcuPilot's own protected state** (privileged routine application, `New $ROLES`
  frame, nothing spawned or re-entered from inside it), written through `Kernel/State`'s row-versioned
  guarded save (`STATE.CONFLICT`, 409); a `%Persistent` class name including its package stays within 29
  characters; references to IRIS objects are **weak** — scoped identity as data, never a foreign key.
- **One envelope `{error, reason, code, detail}`**: screens render `reason`, tool results `code`, vendor
  `%Status` text is normalized at the port boundary with the raw kept for log and ledger only, and
  `detail.violations[]` carries `{field, code, reason}`.
- **Client and tests.** Zoneless `OnPush`; every user-visible string from `core/strings.ts` and present
  in EXPERIENCE.md; design tokens only. Geometry belongs in the browser runner, which loads the
  **deployed** bundle (`npm run build`, then `docker cp dist/ocupilot-ui/browser/.
  <throwaway>:/durable/iris/csp/ocupilot/`). `%UnitTest` classes run one at a time through
  `node ui/tools/ci-runner.mjs --container ocupilot-ci --class <Class>`, each landed in
  `%UnitTest_Result` before the next. Every handler gets an HTTP test on status, content type and body
  shape; every tool a round-trip test over its generated schema; a denial test uses a purpose-built
  least-privileged role, never `%Operator`.

## UX & Interaction Patterns

- **The card.** Target heading; changed fields as diff rows (label, before in `code` `destructive`
  struck through, `→`, after in `code` 600 `success`); the rest of the payload under an "N unchanged
  fields" disclosure with every field still available; "Agent's rationale" and "Expected impact" as the
  agent's **labeled** text on the agent tint; "Reverse: <how to undo>" where a reversal exists. Footer:
  "Runs as <user name>, with your privileges." and "Confirm here; sending a message cancels this
  proposal". Countdown "Expires in m:ss" from 10:00, `warning` from 1:00, announced to assistive
  technology **once**, at 1:00, never per second. Spoken diff form is "<field>: was …, now …" with the
  arrow `aria-hidden`; secrets read `••••••••` both sides; empty reads "(none)".
- **Delete proposals** show identifying fields as `field · value → (removed)`, with **no after-state
  and no Reverse line**. A destructive write adds the typed-name field and a `button-destructive` Confirm
  (build step 7 / Story 14.7); a secret in the payload is a masked-secret field filled at confirmation.
- **One decision at a time.** Cards stack in order with their own Confirm and Cancel and there is **no
  "Confirm all"**; while one is live Send drops to secondary so Confirm is the view's only filled button.
- **Terminal transitions replace the buttons with a status line** that takes focus and is announced —
  "Confirmed by <user name> · hh:mm:ss", "Canceled — by your message", "Canceled — a sibling proposal was
  confirmed", "Expired", "target changed, re-propose". Buttons are `aria-disabled` for the transition,
  never removed while focused. The restrained treatment is **by role, never by opacity**, so the diff
  stays readable at AA. A card restored from a reload is **always** expired, with Re-propose.
- **A typed message cancels every live proposal** and the agent's next reply says so and offers to
  re-propose; New conversation cancels the same way; **Stop cancels nothing**.
- **The changed row** takes `change-highlight` with a 3px `agent-accent` bar and a "Changed" tag,
  settles over 2s, holds until the next interaction, scrolls into view. Yellow is never a control. A
  deleted row leaves and clears selection and the locator's entity segment; a created row appears
  highlighted and selected.
- **Toasts** name the change in one sentence with "Open in <screen>" when that screen is closed: three
  deep, 10s without an action and 30s with one, paused while hovered or focused, always dismissible.
  Never for errors (those are banners) and never to confirm what the user just did on the open screen.
- **Auto-refresh pauses under a live proposal** — "Auto-refresh paused — a proposal is awaiting
  confirmation" — resuming on confirm, cancel or expiry, so the diff under review cannot move.

## Cross-Story Dependencies

- **Inside the epic.** 5.0 clears Epic 4's residue first; 5.1 mints, 5.2 renders, 5.3 confirms, and
  5.4–5.7 are the properties every area write inherits, so 5.8–5.13 are exercises of one mechanism rather
  than six implementations. 5.10's write must be the **same operation** Story 7.4's Auditing
  configuration screen later calls.
- **From Epic 4.** The turn job with its progress and lease contract, `Dispatch`'s gate chain and its
  restraint branch for write-kind tools, the "acting on behalf of the model" marker, the ledger (one row
  per call, `RequiredPairs`, schema-driven redaction, finalized **after** the write and recording what
  was actually executed), the panel with its banner order, and the tool-call card.
- **From Epic 2.** `AdminPort`'s eight-step vendor dispatch — the only code naming an `%Api.Admin.*`
  class — the descriptor-declared reads each write reads fresh through, the **audit viewer with its
  agent-marker filter** (where 5.8's "Shall I show you the audit entry?" lands), and the **application
  error drill-down**, built that early precisely so 5.13's delete can take its namespace from the
  drilled level.
- **From Epic 3 and Epic 1.** The kill switch, enforced read-only and the definition's read-only flag,
  all re-evaluated at confirm; protected storage and its resource, the closed entity-type enum, the
  descriptor mechanism, the string table, the registered audit events, and the smoke script that defines
  "step complete".
- **Deliberate forward references.** 5.11 navigates to the **Task schedule list** with the task
  selected because Task details lands at 6.7; retargeting that allow-listed route identifier is Story
  7.6's one-line change. 5.6's and 5.10's banner carries its sentence alone until Story 7.4 makes its
  link and "Turn auditing on" live. The typed-name confirmation arrives in full at 14.7. Epic 8 depends
  on Epics 5 and 6; Epic 11 on 4, 5, 6 and 10.
- **Routed ledger entries bind their story** — address each or decline with a reason. 5.0 carries twelve
  (DW-1123, 1162, 1173, 1161, 1097, 1126, 1150, 1128, 1133, 1151, 1134, 1168); 5.1 carries DW-445, 1052,
  1170, 1121; 5.4 DW-444 and 1120; 5.6 DW-1174; 5.10 DW-1171; 5.11 DW-269 (the vendor tasks LIST coerces
  every task's `Suspended` to false, so the suspended-task read needs AD-36's `INFO` `rowGet` or a stated
  reason it does not).

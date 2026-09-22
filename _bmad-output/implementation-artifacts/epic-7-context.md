# Epic 7 Context: Act on any row

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Build step 4, and the last floor requirement below the create-and-edit line. A user does the small
things that make up most daily administration — enable, disable, run, suspend, resume, terminate and
delete — from the row menu or the command bar, with the row updating in place, and can ask the agent
to do any of them instead through a confirmed proposal. Epic 5 built the write path once and proved it
with **one** write per area; Epic 6 built the screens these actions hang on. This epic fills in the
rest of the verbs on screens that already exist, so nothing new is designed: each story is a
descriptor declaration, a derived write tool, a row handler and a dialog, over machinery that is
already shipped and tested.

## Stories

- Story 7.1: Enable, disable and delete a web application
- Story 7.2: User enable, disable, delete, password and roles
- Story 7.3: Delete an OAuth 2.0 client configuration or server client description
- Story 7.4: Turn auditing on and off from the screen
- Story 7.5: Run an on-demand task
- Story 7.6: Run, suspend, resume and delete a task (and the UJ-6 end-to-end replay)
- Story 7.8: Terminate, suspend and resume a process
- Story 7.10: The remaining application error delete scopes
- Story 7.11: System and user audit event configuration

There is no 7.0 cleanup story, and 7.7 (Task Manager control) and 7.9 (lock removal) moved to Epic 16
as 16.11 and 16.12 — build step 4's list never named them.

## Requirements & Constraints

These apply to every story, and the story specs do not repeat them:

- **Every action is two callers of one operation** — the row (or command bar) and the agent's write
  tool. A story is not done when the button works. The write tool follows the full model every time:
  a server-minted proposal from a fresh read, an instance-computed diff, an explicit confirmation on
  a separate authenticated browser request executed from the **stored** arguments, the prohibited set
  and both switches evaluated at the write inside the atomic transition, the change event, and the
  agent audit marker.
- **Self-protection rules are UI affordances, never prohibitions.** Refusing to disable the current
  user, delete OcuPilot's own applications, or terminate an IRIS system process is enforced on the
  instance whatever the caller, and merely *explained* in the row menu. A rule a screen enforces only
  in its UI is not a prohibition, and a second, broader predicate in a screen is forbidden — the
  prohibited set has exactly one home, in the kernel.
- **Privilege grants stay prohibited at any confirmation level.** Adding `%All` or any `%Admin_*`
  role, setting application roles, or adding a role to a resource is refused through the agent path
  entirely, while the screen's own role management remains available to a privileged user (7.2).
- **Three warnings carry a consequence before a non-delete write**: disabling auditing ("agent writes
  will no longer be marked"), disabling OcuPilot's own web service, and suspending the Task Manager
  (the last now Epic 16's). These use a primary action button, not a destructive one — nothing is
  being deleted.
- **Secrets are write-only end to end.** A set-password dialog never pre-fills, never echoes a stored
  value, accepts pastes untrimmed, sends the value once, and no read returns it. Redaction is
  schema-driven: a field is secret because its descriptor says so.
- **The prohibited predicate for process control is narrow and settled**: the process serving this
  request (`$JOB` at confirm, since killing it kills the write inside the atomic transition) and any
  OcuPilot turn job whoever owns it, plus IRIS system processes for terminate. It is deliberately
  **not** "the user's own process" — that reading was reversed during Epic 5 and 7.8's clause has been
  amended to match. Do not re-broaden it in the screen.
- **The application error deletes complete here** with all three scopes — by namespace, **by date**
  and by individual error — with `DeleteByDate` either implemented or explicitly refused. The
  fingerprint is always the enumerated id set captured at proposal time, never a count and never a
  re-query at confirm; residue from errors logged in between is correct and the card says so. The
  namespace comes from the level the user has drilled to, never from the route's `?ns=`, and the gate
  resolves per namespace.
- **Two write families need care with their bodies.** `Security.Audit.Event` (7.11) publishes no body
  template, so its field list derives from `Security.Events` and is pinned by a test that fails when
  the instance disagrees, and its PUT is an **upsert** whose path is covered explicitly. All four
  `Security.OAuth2.*` endpoints (7.3) do not merge, so every write there reads fresh and sends the
  complete property set. `Process`, `Lock` and `Task.Manager` are action-style with empty bodies.
- **One floor-blocking ledger item is a design change, not a fix**: the service-account arm of the
  prohibited set is gated inside the disable branch while the last-`%All`-holder rule is scoped by
  effect, so a roles-only delta stripping `%All` from the serving account is permitted. Moving the arm
  needs an AD-10 amendment under Rule 20 — it is not a local edit.

## Technical Decisions

- **A row action is a descriptor declaration.** A screen is declared once; adding an action adds the
  row action with its self-protection rule and the derived write tool, not a rewrite of the list page.
  A descriptor becomes write-capable when it declares a primary or row action, which is what the empty
  state's agent invitation keys off. No inert controls: an action ships with its handler.
- **Write tool field lists are derived, never transcribed**, from the endpoint's own body-template
  method, with the semantic half (required, enum, description) authored once per tool and reviewed.
  Derivation is where fields are classified `ordinary`, `secret` or `opaque`; an unclassified field is
  emitted secret and a misclassified credential fails the build. For a merge write OcuPilot computes
  the merge itself and sends the complete body — get-merge-put is not a property of the admin API.
- **An action-style write is a first-class kind** (AD-51): it declares the admin request type it
  issues, admits no settable fields and sends no body, and its fingerprint covers the **fresh read**
  under a subject the tool declares — every field the action's own precondition reads, drawn from what
  its read type answers. Identity is *not* part of the subject; it comes from the proposal's target
  reference. An empty subject is refused, and the subject is validated by the same builder that
  validates the merge write's exclusions. Every other gate is unmoved: an action write is a narrower
  body, never a lighter path.
- **A write tool declares the port it reaches its target through** (AD-52), defaulting to `AdminPort`.
  The application error deletes go through `LogSourcePort`; the mint's fresh read, the confirm's
  re-read, the prohibited evaluation and the write all resolve through that one declaration. "No
  `AdminPort` call" never means "not a real write".
- **Confirm is user-originated only** — not a tool, not in the registry, refused when the "acting on
  behalf of the model" marker is set — and every gate that decides whether a write may happen is
  evaluated at the write, inside the single atomic transition. Confirming one proposal cancels its
  siblings on the same scoped target in that same transition.
- **Every reference carries `(entity type, scope, id)`**, with the canonical spelling decided in the
  identity layer per entity type; a type this epic adds a write for adds its own canonicalization rule,
  and a type with no rule canonicalizes to itself.
- **A confirmed write publishes one change event** on the client bus from the kernel's closed entity-type
  enum; the screen re-fetches in place preserving sort, filter, selection and scroll, and highlights the
  affected row or field. No screen patches its own rows from a write response. The proposal lifecycle
  also publishes open/closed events, which is what pauses auto-refresh on the seven refreshing screens.
- **The agent marker never fails a write**; a dropped marker surfaces as "done · audit not marked". The
  one write that closes the audit channel (disabling auditing) cannot be marked at all — a recorded
  physical constraint, not a relaxation.
- **Vendor quirk, tasks:** the task list's `Suspended` field does not reflect a suspend or resume just
  applied, while the task's own `INFO` read does. The in-place row update and the write's verification
  read task info, never the list's field.

## UX & Interaction Patterns

- **Row menu.** The row-overflow menu lists actions in command-bar order, destructive last. Refused
  (self-protection) and privilege-gated actions stay listed and arrow-reachable as non-selectable rows
  with the reason inline after the label — never Material-disabled items, which the menu skips.
- **Destructive dialog.** One level deep, never stacked. The title names action and target; the body
  states the consequence; a typed-name field ("Type `<name>` to confirm") requires an exact,
  case-sensitive match — paste allowed, mismatch on blur reads "Does not match" with `aria-invalid`,
  Enter submits only once it matches — and the action button is destructive, labeled verb plus target,
  and `aria-disabled` until then. Initial focus is the typed-name field; Escape and Cancel close
  without effect and return focus to the opener.
- **A destructive proposal card** carries the same typed-name field, with a destructive Confirm; a
  proposal to disable auditing carries its warning sentence. After the write the card's buttons become
  a focused status line, the screen re-fetches and highlights within 2 s, an off-screen change raises a
  toast naming the entity and linking to its screen, and the reply offers the audit entry.
- **Banners.** "Agent writes are not being marked" appears the moment auditing goes off and clears the
  moment it returns, with a link to Auditing configuration and, for OcuPilot administrators, "Turn
  auditing on".
- **Strings.** Every new user-facing string is added to the EXPERIENCE.md Fixed strings table with its
  `strings.ts` key in one pass — the test demands exact set equality and values are unique. Inserting a
  row shifts later line anchors, which two other test files pin; `npm run test:tools` is the covering
  checker, not `lint-docs`.

## Cross-Story Dependencies

- **Upstream:** Epic 5 for the whole write path (mint, card, confirm, prohibited set, marker, screen
  refresh) and for each area's first write — 7.1 extends 5.8's web-application enable-and-grant, 7.2
  extends 5.9, 7.4 and 7.11 extend 5.10's auditing disable/re-enable, 7.6 extends 5.11's task resume,
  7.8 extends 5.12's process suspend/resume, 7.10 extends 5.13's delete-by-namespace. Epic 6 for the
  screens: 7.5 on the on-demand list, 7.6 on Task details and the schedule, 7.8 on Processes and
  Process details, 7.3 on the OAuth tabs, 7.10 on the error drill-down.
- **Within this epic:** 7.6 owns the UJ-6 replay end to end — the agent navigates to Task details, the
  Status field highlights, a toast reads the change with "Open in Task schedule" — so no earlier story
  is left unverified. 7.4 and 7.11 are the two halves of the Auditing screen; 7.4 embeds the system-
  and user-event lists its rows 7.11 acts on.
- **Epic 8 runs in parallel** over the same areas but different screens and entities (create flows and
  new editors). The shared-create rule applies across the whole overlap: either epic creates files
  freely in shared trees, and modifying a file the other created or has modified is a clarification.
  Genuinely contended single files both must edit: `Port/AdminPort.cls` (shared-append — add your own
  request types, never reorder another's), `ui/src/styles/_components.scss` (shared-append),
  `ui/src/app/core/strings.ts`, and the `epics.md` ledger bullet runs. `src/OcuPilot/Install/Smoke.cls`
  is this epic's while the rest of `Install/` is Epic 8's. Exclusive to this epic:
  `Kernel/Proposal/**`, `Kernel/Restraint.cls`, `Port/LogSourcePort.cls`.
- **Downstream:** Epics 9 and 12 become eligible once both this epic and Epic 8 have merged; Epic 12's
  five OAuth editors build on 7.3's deletes and remove the area's one classic-link exemption; Epic 16
  takes Task Manager control (16.11) and lock removal (16.12), which warns from the endpoint's own 409.

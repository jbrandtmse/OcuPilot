# Epic 3 Context: Configure the agent, and hold the switches that restrain it

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

An administrator picks a provider, pastes a key, proves it works before enabling it, and from then
on holds two switches — the kill switch and enforced read-only — that restrain or silence the agent
instance-wide without any screen losing function; a user with no agent configured still gets every
screen plus a panel showing what a proposal would look like. Definitions and Switches are ordinary
screens that must work **before** any agent does, which makes this epic standalone and a
prerequisite for every turn in Epics 4 and 5.

## Stories

- Story 3.0: Epic 2 deferred cleanup
- Story 3.1: Agent definitions and the rules that keep them honest
- Story 3.2: The provider contract and the Anthropic adapter
- Story 3.3: Credentials resolve at call time, never stored where OcuPilot can show them
- Story 3.4: Test connection
- Story 3.5: The Definition form
- Story 3.6: The first-login gate and the configuration-empty state
- Story 3.7: Switches — the kill switch and enforced read-only
- Story 3.8: Every configuration change is resource-gated and audited

## Requirements & Constraints

**The definition and its rules.** It carries **no `ApiKey` property at all** — that absence is the
schema invariant, locked by a test. Eleven server-side validation rules plus the XOR credential
invariant (whichever of env-var name / credential name was not selected is cleared) are enforced on
the instance and **accumulate into one response**, never one error at a time. Changing provider
cascades that provider's canonical defaults while preserving customized values, and model
suggestions come from one source. Any provider, endpoint or credential change disables the
definition until Test connection passes again. Exactly one is default; all users see definitions for
selection, only OcuPilot administrators edit. Retention renders disabled and captioned as not yet
enforced, the purge task shipping in Story 14.4 — a field must not promise what nothing performs.

**Credentials.** Store only the credential type and the variable or credential name. A key entered
in the form is written once to the chosen store and returned by no API call, ever. The ladder
resolves at call time and never returns a value into a status or an error: the environment-variable
rung works in any namespace; the IRIS-credentials rung is offered only where the install namespace
is interoperability-enabled, because plain IRIS Community may not have it. Per-provider shape checks
catch obvious paste errors before any call.

**What enforced read-only means, and who owns it.** Story 3.7 is the single enforcement point for
the instance-wide state: while enforced read-only — or a definition's own read-only flag — is in
force, **every write tool returns a structured "blocked by read-only mode" result, the agent states
what it would have changed and on which screen, and no proposal card is minted**; a write in flight
when the switch flips is abandoned at the next step boundary, never half-applied. Story 10.4 adds
only the per-user toggle's data and UI **over** that gate, never a second enforcement point — so
cutting build step 7 cannot leave a banner over an agent that still mints proposals.

**Switch semantics.** Both switches are instance state in the protected database, evaluated on the
instance at the point of effect — inside the write path and inside the turn loop — never only in the
client and never cached for a turn's length. The turn re-reads them between steps and confirm
re-evaluates them, so a proposal minted before a switch cannot be applied after it. The kill switch
is **off** by default: the agent's initial silence comes from having no enabled definition, a
distinct state, not a switch someone must find and clear.

**Privilege and audit.** Every configuration endpoint checks the OcuPilot administrative resource
server-side, not only in the client. Every change to a definition, either switch, the
context-sharing default or the turn limits emits an audit event naming actor, target and **old and
new values** — an endpoint change recorded as old endpoint and new endpoint specifically. Event
types must be registered with `Security.Events.Create()` at install or `$System.Security.Audit()`
silently returns 0 and drops them. The OcuPilot API web application carries no application roles and
no matching roles, and the installer asserts it; the turn endpoint refuses a user holding no
`%Admin_*` resource. Story 1.3 proved the SQL-and-global half of the state-protection test; this
epic adds the endpoint half.

**Ledger items routed here** — address in the story or decline with a reason:

- DW-307 (3.0): write the burn-down's unwritten third verification leg — a throwaway real-principal
  observation of the port's named 403 over HTTP, its status, `code` and `detail.failedPair` recorded
  inside a recorded and reverted mutation window.
- DW-297 (3.0): every named refusal on the application error log renders one generic sentence; each
  gets its own published sentence and string-table row, added with the code.
- DW-20 (3.1): define the fallback when the single default definition is disabled or deleted —
  promote another enabled definition, else the configuration-empty state.
- DW-21 (3.2): validate the **resolved** address at call time, not only the URL literal.
- DW-22 (3.3): an unresolvable credential fails the turn with a named reason and flags the
  definition.
- DW-335 (3.3): the installer's TLS drift repair re-enables a disabled provider SSL configuration
  and no test pins that branch; drift `Enabled` in the adjacent repair test and falsify it there.
- DW-330 (3.4): an explicit set-default onto a **disabled** definition is accepted and then silently
  relocated by the next unrelated write; refuse it, or say in the response that the marker will move.
- DW-339, DW-340, DW-344 (3.5): render the key-shape refusal inline (`aria-invalid` through
  `aria-describedby`, on blur); the key field empty after save, published caption, labeled reveal
  toggle, pastes untrimmed; and `credentialName`'s 128 characters against a credential's 50, which
  refuses an over-long reference at store time with a 500 instead of at save time with a 422.
- DW-44 (3.8): emit RoleGranted only on an actual grant, reword Story 1.3's AC9, flip its row-count
  test.
- DW-329 (3.8): the change-record redactor matches a credential name as a **substring**, masking a
  bound such as `maxTokens`; anchor the match as the build-time credential pattern is anchored.
- DW-331 (3.8): a create's change record is diffed against the class initial expressions, so fields
  created at their default are absent; 3.8 owns the audit row shape and what a create row carries.

## Technical Decisions

- **Provider layer.** One base with adapters behind a single contract, Anthropic's message shape
  canonical; adding a family is one adapter plus one form entry with **no change to the agent loop,
  the tools or the screens**. Use a registry, not the harvested four-branch `If/ElseIf`. Keep the
  harvested never-throw discipline and `Invoke()` template: a failure surfaces as an error
  stop-reason and a turn error, never an exception to the client.
- **Egress is an allow-list, not free text.** Writing the endpoint requires the administrative
  resource; it validates to an absolute HTTPS URL (or an explicitly declared local address for the
  OpenAI-compatible adapter); it cannot name the instance itself or a loopback or link-local address
  unless the definition is marked local; and the change is audited as a security change. One
  classifier makes that judgement, at write time and again at call time, so setup and a real turn
  cannot disagree about where data may go.
- **TLS is configured at install, never defaulted** — a named SSL configuration the installer
  creates if absent, server-identity checking on, never hardcoded to the harvested code's choice and
  never left to `DefaultSSL`. Proxy settings are configuration, not code.
- **Retry** only on a retryable status, delay the greater of the provider's `Retry-After` hint and
  exponential backoff, bounded count, bounded timeout per call. **A call that threw mid-flight is
  never retried** — the request may already have been processed.
- **Secrets never reach a surface OcuPilot itself displays.** The key is fetched at the point of
  use, held in a variable cleared before return, never interpolated into a URL, message, status, log
  line or trap; a test asserts that a forced provider failure leaves no credential material in the
  application error log or messages.log, both of which OcuPilot renders.
- **Protected state.** Definitions, switches, ledger, transcripts and proposals are globals in the
  guarded database, reached only through the privileged routine application inside a `New $ROLES`
  frame; nothing is spawned from, or re-enters from, an escalated frame. Stored references to
  instance objects are **weak** — scoped identity as data, never a foreign key — rendering "no
  longer present" rather than failing the screen.

## UX & Interaction Patterns

Exact copy for every banner, caption and result string is fixed in the canonical string table; use
it verbatim rather than paraphrasing.

- **Definition form** is the epic's first `form-page`: single column, sticky Save/Cancel, validation
  on blur and on Save, an error-summary banner taking focus on a failed Save with a link per field,
  `aria-invalid` plus `aria-describedby` with the first invalid field focused. Name, provider,
  model, endpoint, key and Test connection sit above the fold; tuning fields and retention collapse
  under "Advanced", closed by default. Unsaved-changes navigation asks first — **and agent
  navigation waits for the same answer**. The key field is a masked secret: empty after save,
  captioned that a value is stored, never pre-filled, labeled reveal toggle, pastes untrimmed. Save
  on a create opens the new definition's editor; on an edit the editor stays open and the bar shows
  "Saved", with "Go to Home" offered beside it on the first successful definition save.
- **Test connection** is the view's primary button: inline progress, `aria-disabled` for the
  duration with focus staying on it, result as a polite status. It reports the model's own first
  words on success and the provider's own error text — not its raw JSON — on failure; the definition
  stays disabled and Save still works, saying so. The link-local metadata range is refused **with no
  escape**, because that range is the instance metadata service; private-network hosts are allowed
  outright, the classifier not refusing RFC-1918; and a loopback or instance address is allowed only
  where the definition is **marked local** and its provider's catalog row admits it — the same
  judgement made at write time and at call time.
- **First-login gate**: an administrator signing in with no enabled definition is redirected onto
  the Definition form under the gate landing banner; bypassable; fires on every login until one is
  enabled and never afterwards, with a non-dismissible panel reminder meanwhile.
- **Configuration-empty panel** for non-administrators: the who-can-configure line, then a **static
  example proposal card** labeled as an example — same bar, header, two changed diff rows, collapsed
  unchanged disclosure, agent text and Reverse line as a live card, but no countdown, no buttons,
  nothing focusable, live colors kept. **Built once here; Story 5.2 makes it live.** Then three
  sentences on privileges, confirmation and the audit marker. The composer stays focusable and
  `aria-disabled` with the reason; the context chip is **absent**, there being no endpoint to name.
- **Panel banners, in order**: kill switch · enforced read-only · agent-writes-not-being-marked ·
  administrator reminder · lock. The footer read-only status line is **always** present in both
  states, naming which of the three sources is in force, so the mode is learnable. The kill switch
  puts the panel in its disabled state with the administrator's reason, makes the transcript
  read-only, keeps composer and Send focusable and `aria-disabled`, replaces any live proposal's
  buttons with a status line that takes focus, and every screen keeps working.
- **Gating.** For non-administrators, Definitions and Switches render as side-bar entries gated
  naming the OcuPilot administrative resource; the Agent co-pilot rail item itself **never** gates —
  its attention dot, reason in its accessible name, is the signal, and clears when one is enabled.

## Cross-Story Dependencies

- 3.0 closes Epic 2 overflow first, so the agent stories build on ports that refuse what they cannot
  serve and screens whose refusals are distinguishable.
- 3.2 needs 3.1's schema and 3.3's ladder; 3.4 needs 3.2's call path, because Test connection must
  exercise the same path a real turn does so a TLS misconfiguration surfaces at setup. 3.5 renders
  3.1–3.4; 3.6's gate lands on 3.5's form; 3.7 and 3.8 must work with the agent off.
- The installer (Epic 1) owes this epic the named SSL configuration, the registered audit event
  types and the administrative resource; 3.8 asserts all three.
- Downstream: Epic 4's turn loop and Epic 5's confirm path re-read 3.7's switches between steps;
  Story 5.2 makes 3.6's example card live; Story 14.4 enables 3.1's retention field and creates the
  purge task Story 13.1's uninstall hook expects; Story 10.4 layers the per-user toggle over 3.7's
  single gate.

---
title: 'Story 4.4: Screen context on every turn, capped, with its toggle and chip'
type: 'feature'
created: '2026-09-16'
status: 'draft'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['multiple-goals']
deferred: []
---

# Story 4.4: Screen context on every turn, capped, with its toggle and chip

Planning halted before the intent contract was written. Nothing is implemented. Reset `status` to `draft` after the amendments below; the re-plan writes the intent contract fresh and can reuse the Code Map.

## Intent

Pending re-plan: the plan halted on the intent gaps below.

## Boundaries & Constraints

Pending re-plan.

## I/O & Edge-Case Matrix

Pending re-plan.

## Intent gaps

Each gap names the evidence and a recommended amendment. Items marked **ask first** change product behavior (Rule 5 tier 2).

1. **Size: split the story (ask first).** The ACs need a server serializer with three bounds, secret exclusion with a backstop, a new AD-11 channel for context, a new operator setting, a per-user preference store, a new egress classification exposed to non-administrators, DW-452, DW-281, DW-398 and DW-399. They also need a client chip, pill, key glyph and toggle, live row counting, and a paste warning. Story 4.3 was client-only and its spec reached 40 KB. Recommended split:
   - **4.4 (server): screen context reaches the turn, capped and secret-free.** `POST /turn` accepts `context`. The kernel applies the row cap, total size and per-field cuts, and excludes secret fields by schema plus the backstop. It carries the namespace as the tools' scope and records the rows sent. The context bounds and tool-result bounds share one cutter (DW-281), and the reply has a budget (DW-452). Also DW-398 and DW-399, plus the operator cap field on Switches. The integration AC is a `TurnWire` test in which `turnprobe` records the context, the cap, the exclusion and `share:false`.
   - **New client story, placed after 4.5: the context chip, its toggle and the paste warning.** It covers the chip, pill, key glyph, toggle and live updates, plus the context assembler that 4.5's Send calls. The paste warning needs a Send to act on, and Send is Story 4.5 (`panel.ts:136-143` is `aria-disabled` with no handler; no client code posts `/turn`).
2. **Where the toggle is remembered (ask first).** Two readings conflict:
   - "For the session" / "per session": `prd.md:320`, `:1095`, EXPERIENCE.md `:342`.
   - "Remembered per user": `prd.md:329`, EXPERIENCE.md `:370`, the story AC.

   Browser storage (`core/preferences.ts`) and instance storage give different results on a second browser. No per-user preference store exists (`Kernel/State/Hold.cls` holds only kill-switch holds). Recommendation: store it on the instance, per user, in a new `Kernel/State` store. When the user has no row, `Switch.ShareContextByDefault` (`Switch.cls:44`) supplies the value. A later change to the instance default does not override a user's explicit choice. Amend PRD `:320`, `:1095` and EXPERIENCE.md `:342` to say "remembered per user".
3. **"Operator-settable" 200-row cap has no surface (ask first; Rule 5).** No screen, resource, range, storage or Fixed-strings row exists. Switches (Story 3.7, done) lists no cap, and `Limits.cls:7` defers limits to Story 14.6. EXPERIENCE.md `:68` still says "50 is a safe ceiling". Recommendation: add a `contextRowCap` field on `Kernel/State/Switch` and the Switches screen. Gate it by `OcuPilotAdmin:USE` and audit it as a Story 3.8 change. Integer 1-1,000 (the read default `Screen/Read.cls:40`), default 200. It governs both the context rows and `Dispatch`'s `TOOLROWS`. Add a Fixed strings row for its label, and delete the "50" note at `:68`.
4. **No numbers for total size, per-field maximum or the cut mark (ask first).** AD-24, the PRD and the UX give none. Recommendation:
   - Total serialized context of 65,536 characters (`Limits.TOOLRESULTMAXLENGTH`), cut whole rows from the end.
   - A per-field default of 1,000 characters (`Limits.SUMMARYMAXLENGTH`). A descriptor may declare a lower `maxLength` per context field.
   - A cut value ends in U+2026. The payload carries `rowsSent`, `rowsAvailable`, `truncated` and `truncatedFields`.
5. **"A serializer that emits an uncapped collection or an unbounded field fails review" is not measurable (Rule 5).** A review verdict cannot be tested. Recommended amendment to the story AC and AD-24's last sentence: "The kernel applies the row, total-size and per-field bounds to every context payload and every read tool result itself, so no serializer's output can leave unbounded, and the descriptor registry refuses a context field whose declared maximum exceeds the default." This changes an AD Rule, so the spine changes in the same commit (Rule 20).
6. **"Visible rows" has two readings.** The viewport rows are about 16 (EXPERIENCE.md `:68`, `:370` "as the viewport's rows change"). The screen's filtered and sorted view is capped at 200 (AD-24, AD-36, UX-DR81 at `epics.md:492`). The chip's `<N rows>` and the payload differ between them. The rendered range is private to `DataTable` (`data-table.ts:368`). Recommendation: the screen's view is `applyView` (`core/screen-read.ts:105`) over the store's data, cut to the cap. `<N rows>` is the count that would be sent. Amend EXPERIENCE.md `:68` and `:370`.
7. **"Private network" is undefined (ask first).** `Kernel/Egress.cls:21-22` deliberately has no private-range kind. The non-admin definitions row carries no endpoint (`State/Agent.cls:431-440`). Recommendation: omit the pill only when the definition is marked local, or when every resolved address of the endpoint host is loopback, link-local, RFC 1918 or `fc00::/7`. An unresolvable host shows the pill. Compute this on the instance from `ProviderPort.Dispatch`'s own resolution (`endpointUrl`, else the catalog default). Expose `provider`, `endpointHost` and `leavesInstance` on the default definition's status read.
8. **"Looks like a password or key" has no heuristic (ask first).** Recommendation: the trimmed draft contains a whitespace-free run of at least 12 characters using at least three of lower case, upper case, digit and symbol, or it starts a run with `sk-`, `-----BEGIN` or `AKIA`. The warning shows regardless of the sharing toggle, because the message itself is sent. It shows once per draft text. Send anyway sends that text; Edit returns focus to the composer.
9. **Warning form and strings.** EXPERIENCE.md `:524` says an inline warning, but DESIGN.md `:1145` says "a `banner`". Neither "This looks like a password or key. Send anyway?", "Send anyway", "Edit" nor a key-glyph accessible name is in the Fixed strings table. `ui/tools/strings.test.mjs:390` refuses any `strings.ts` value outside it. Recommendation: inline, per EXPERIENCE.md, which `:250` makes canonical. The lead adds the three rows plus the key glyph's name, for example "Secret fields on this screen are never sent".
10. **Decision with architectural weight for the lead (Rule 20), not a question.** AD-11 rule 1 lets untrusted text enter only as delimited tool-result content, and screen context carries entity names. Today message 1 is a plain user string (`Loop.cls:88-91`). Recommendation: context enters as a synthetic `screen.context` assistant `tool_use` plus its `tool_result`, placed before the user's message and never advertised as a tool. Record this as an AD-11 clarification.

## Ledger inbox (proposed dispositions, applied on re-plan)

- **DW-281:** addressed by the server story. One per-field cutter serves context and `Dispatch.Capped` (`Dispatch.cls:292-343`, which cuts rows only).
- **DW-452:** addressed by the server story. A per-reply budget goes in `Loop.AnswerTools` (`Loop.cls:321-341`); every reply is budgeted by the recommended total.
- **DW-398:** addressed by the server story. Match credential words at camel-case or separator boundaries rather than as a final suffix, measured against the shipped key set (`Kernel/Audit/Log.cls:53,63,172`).
- **DW-399:** addressed by the server story with a node test that reads `Log.cls`'s parameters and compares them with `CREDENTIAL_RE` (`ui/tools/field-lists.mjs:59`). The two already differ: the server adds suffix `credential` and exact `credentialname`, which neither the client nor the spine Conventions › Secrets row has. Reconciling them changes that Conventions row (Rule 20).

## Code Map

- `src/OcuPilot/Api/Turn.cls` -- `HandleStart` (~:27) parses the body with no key allow-list, so `context` is ignored today. `MessageViolation` (~:163). The job values are built after `GuardedReserve` and passed to `Job.Start` (AD-9: context resolved here, passed as a JSON string).
- `src/OcuPilot/Kernel/Agent/Job.cls`, `Loop.cls` -- positional `JOB` args to `Run` and then `Loop.Run`. First message at `Loop.cls:88-91`. System prompt at `:113`. Tool results as a user message at `:345-347`. `AnswerTools` at `:292-349`.
- `src/OcuPilot/Kernel/Agent/Limits.cls` -- `TOOLROWS` 200 (:45), `TOOLRESULTMAXLENGTH` 65536 (:49), `SUMMARYMAXLENGTH` 1000 (:34), `MESSAGEMAXLENGTH` 16000 (:28).
- `src/OcuPilot/Kernel/Agent/Dispatch.cls` -- `Answer` :110, `AnswerOne` hands `pRows` to `InvokeTool` :225, `Capped` :292-343.
- `src/OcuPilot/Screen/Descriptor/Base.cls` -- `ContextFields()` :277, `ContextSecretFields()` :284. `Screen/Registry.cls:688-746` validates `context {fields, secretFields}`, secret-sort/filter overlap at :1240, and secret columns at :1126. Only `AgentDefinitionForm` declares a secret field (`apiKey`). `AuditList` keeps `EventData` out of `context.fields`.
- `src/OcuPilot/Screen/Read.cls:188-192` strips secret fields. `Screen/Tool/Read.cls:161` `View` narrows to the context cap.
- `scripts/check-objectscript.py` rule 19 (:853-883): `Kernel/Agent/` may name no `Screen.*` except `Screen.Tool.Registry`, so a descriptor-reading serializer lives under `Screen/` and is called from `Api/Turn`.
- `src/OcuPilot/Kernel/Scope.cls` -- `Current()` falls back to `$Namespace` inside the job. `Turn` passes `$Namespace`, not `?ns=` (`Router.cls:434,493`).
- `src/OcuPilot/Kernel/State/Switch.cls` -- `ShareContextByDefault` :44 (no reader yet), `Resolve` :57, `SetGuarded` :94. `Api/Switches.cls` covers `Fields()` :55, `IsAdministrator` :411 and audit `RecordAudit` :524.
- `src/OcuPilot/Kernel/Egress.cls` -- `HostOf` :53, `Classify` :86, `IsPermitted` :121, `KindOf` :218. `Port/ProviderPort.cls` `Dispatch` :220-250 resolves the endpoint. `turnprobe` endpoint `https://192.0.2.10/v1/messages` (`Kernel/Provider/Catalog.cls:69`).
- `src/OcuPilot/Test/TurnProvider.cls` -- records `messages` per call (:97). `TurnWireFixture.StartBody` :266 sends `{message}` only; `AwaitCall` :292. `Test/TurnTools.cls:249` has the AD-11 placement test pattern.
- `ui/src/app/shell/panel.ts` -- chip slot :100, subscriptions :180-191, Send :136-143.
- `ui/src/app/core/screen-store.ts` -- `ScreenStores.for` :334 (read-only use as in `command-bar.ts:323`), `data/selection/sort/direction/filter` :104-256. `core/screen-read.ts:105` `applyView`. `core/navigation.ts:287` `screenForUrl`. `core/scope.ts:201` `namespace()`.
- `ui/src/app/core/agent-status.ts:14-44` -- definitions and restraint reads, no provider host.
- `ui/src/app/core/strings.ts` -- `contextChipLeavesInstance` :69, `contextChipSentToHost` :71, `contextChipScreenSegment` :73, `contextChipSharingOff` :75, `agentShareContextLabel` :297, `agentSwitchesShareContext` :541. `ui/tools/strings.test.mjs:366,390` ties them to EXPERIENCE.md.
- `ui/tools/field-lists.mjs:59` `CREDENTIAL_RE`. `ui/tools/screen-mirror.test.mjs:644-678` applies the backstop to descriptor names.
- Story 3.7's spec `:386` says `shareContextByDefault` "has no reader until Story 4.3". The reader is this story. Correct it at its origin.

## Tasks & Acceptance

Pending re-plan.

## Design Notes

**Governing ADs:** AD-5, AD-9, AD-11, AD-19, AD-24, AD-36, AD-42, AD-48 (the error detail never enters context), and AD-7 unchanged.

**Integration ACs (for the re-plan).** The server story's consumer is 4.1's turn: `POST /turn` with `context` → `turnprobe`'s recorded `messages` carry the capped, secret-free context in a `tool_result`, and carry none when `share` is false. Consumed-by: the client chip story (count sent, `leavesInstance`), 4.5 (Send posts the assembled context; the read tool-call card shows rows sent), 4.7 (navigation changes next turn's context), and Epic 14.6 (per-user limits replace the constants).

## Verification

Pending re-plan.

## Spec Change Log

- 2026-09-17, the orchestrator answered the plan halt's ten questions under the owner's standing autonomy instruction: the story splits (this story is the server side; the chip, toggle and paste warning are Story 4.11 after 4.5) and is retitled; toggle per user on the instance with the instance default as fallback; `contextRowCap` 1-1,000 default 200 on Switches, also bounding read tool results; 65,536 characters total by whole rows, 1,000 per field unless declared lower, U+2026 cut mark, `rowsSent`/`rowsAvailable`/`truncated`/`truncatedFields`; AD-24 amended to kernel-enforced bounds with the registry refusing a context field declared above the default (context fields only; Epic 6's criteria and parameter `maxLength` declarations are untouched); visible rows mean the filtered and sorted view cut to the cap; the leaves-the-instance classification per the amended Story 4.4 AC on the status read; context enters as a synthetic `screen.context` tool call and result (AD-11 rule 1), a model-issued call with that name refused as unknown; DW-399 reconciles both credential lists to the spine's Secrets row. The paste heuristic and its strings belong to Story 4.11. Re-plan from the amended ACs; the Intent gaps section is superseded.

## Review Triage Log

## Auto Run Result

Status: blocked
Blocking condition: intent gap -- the story is not one reviewable story (recommended server/client split, client half after 4.5). Unresolved: (a) whether the toggle is remembered for the session, per browser or per user on the instance; (b) the operator cap's surface, resource and range; (c) the total-size and per-field numbers and cut mark; (d) the unmeasurable "fails review" NFR (AD-24 amendment); (e) whether "visible rows" means the viewport or the capped screen view; (f) what "private network" means for the pill; (g) the "looks like a password or key" heuristic; (h) the warning form and missing Fixed strings rows. Recommended amendments and evidence are under ## Intent gaps; also an AD-11 channel decision for the lead (item 10).

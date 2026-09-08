---
title: 'Reconciliation: research report vs PRD and addendum'
status: draft
created: '2026-09-08'
inputs:
  research: '../../research/technical-ocupilot-portal-feature-landscape-2026-09-08/research.md'
  digest: 'extract-research.md'
  prd: 'prd.md'
  addendum: 'addendum.md'
method: 'research.md read in full (580 lines) and checked against prd.md and addendum.md; the digest used to orient only; disputed facts re-checked in feature-catalog.md and the auth-spike, api-coverage and api-coverage-verify digests'
---

# Reconciliation: what the research says that the PRD and addendum dropped, weakened or contradict

Section references: research sections are D1 to D8, Rec n (Recommendations), Insight n (Cross-dimension insights), OQ (Open questions table). PRD references are section numbers, FR-n, NFR-n, UJ-n, SM-n, OQ n (PRD section 13). Addendum references are §n.

## 1. Carried forward correctly

Recommendations:

| Research | PRD location |
| --- | --- |
| Rec 1 scope to the six areas, agent core, minimal shell, deliverables | §10.1, §9, brief decision 1 |
| Rec 2 build P0 on `/api/admin` v2, `/api/monitor`, `/api/mgmnt`; custom endpoints for messages.log, app error log, agent runtime; pin v2, check `apiVersion`, keep the OpenAPI document under test | §1, §8, FR-3, NFR-8, FR-62, FR-63, §3 of the addendum |
| Rec 3 silent-first JWT: REST app JWT-enabled, in `%ISCMgtPortal`, `UseSession=0`, shell tries empty-body login then form, Bearer everywhere, JSON refresh, logout with cookie; JWT-only as fallback | FR-1, FR-2, FR-65, NFR-3, addendum §2 (settings table and Design B) |
| Rec 4 agent runtime = session-agent core + MCP-suite governance + progress, propose-review-confirm, run-as-user, read-only, agent marker, test connection, first-login gate, log sanitization | §5.2 to §5.4 (FR-10 to FR-29), NFR-2, NFR-6, addendum §4 and §5 |
| Rec 5 one IPM module (`WebApplication` + `FileCopy`, second app with dispatch class, installer `Invoke`), build-time load, idempotent re-check at start, `%CSP.REST` deep-link handler | FR-64 to FR-67, addendum §6 |
| Rec 6 list on 2026-09-14 with a submittable build, improve through 2026-10-04, article, video, short, demo, Ideas link, re-check bonuses | SM-2, FR-69, FR-79, §10.1 last paragraph |
| Rec 7 post-contest order P2 admin API, P2 Explorer, P2 Interop, P3 custom REST, P4 | §10.3 Stages 2 to 6 |
| Rec 8 pull legacy CSP pages before building the task wizard and log viewers | FR-52, FR-53, FR-56, FR-62, FR-63 consequences; §12 risk row; OQ 7 |
| Rec 9 positioning (no incumbent, vendor modernization has not reached administration, execute-with-approval and distinct audit open, local model) | §2 bullets two and three; §1 last paragraph; SM-6 (positioning line itself not carried, see section 5) |
| Rec 10 correct the rule file about `/api/mgmnt/v2` and the interop-editors spec | addendum §12 risk row only (housekeeping; the rule file is still uncorrected) |

Insights:

| Research | PRD location |
| --- | --- |
| Insight 1 auth settled by the spike | FR-1, glossary "silent login", addendum §2 |
| Insight 2 contest floor is API-backed, P0 is screens plus an agent | §1 paragraph two, §8 first bullet |
| Insight 3 hidden admin API is the vendor's direction and the biggest dependency | §2 bullet two, §8, §12 first risk row |
| Insight 4 MCP-suite handlers fill the custom-REST gap; build on iris-couch patterns, not `%Atelier.REST` | addendum §3 last paragraph, §5 harvest map, Stage 5 |
| Insight 5 co-pilot core exists, safety layer from the MCP suite | §5.3, addendum §4, §5 |
| Insight 6 streaming is the largest gap; users punish slow turns; P0 needs progress at least | NFR-2, FR-12, §12 risk row, OQ 14, addendum decision 7 |
| Insight 7 legacy CSP pages are the blind spot inside contest areas | §12 risk row, OQ 7 |
| Insight 8 embed vs rebuild splits on the URL contract; interop can wait | §10.3 Stage 4, §8 vendor editors bullet, §9 non-goal on bundles |
| Insight 9 four install patterns contradict; durable `%SYS` unverified | FR-67, OQ 5, addendum §6 |
| Insight 10 list early, improve continuously | SM-2, §10.1 |

Dimension facts and mechanics:

- D1 dates, prizes, criteria, hard requirements, bonus precedent, three-submission cap, team profile links, obfuscation ban, IP grant → addendum §13, FR-69, OQ 9. Every date and amount in the PRD and addendum matches the research.
- D2 prior art (bg-iris-agent, irislab), empty field, vendor's interop-only modernization, AI Hub → §2, addendum §9.
- D3a to D3c resource gates, custom-resource keys, runtime edition gating, background-task whitelist, auto-refresh, namespace switching, directory allow-list, header conventions → addendum §7; FR-4 to FR-7.
- D4 coverage of the six areas, five UrlMap-only sub-areas, `/api/mgmnt` refusal, unauthenticated `/api/monitor`, Atelier rejects JWT and executes any SQL, write payloads unobserved → addendum §3 and §12, §8, FR-34, NFR-8, Stage 3 gate. `%Admin_Wallet` gating of FR-46 is supported by the api-coverage digest (`/info` privilege map, wallet row).
- D5 embedding verdicts, `VSCODE=1` password hazard, no origin check, no license text, sessionStorage pre-write idea → §8, §9, NFR-3, addendum §2 and §12, Stage 4.
- D6 names to avoid, reuse verdicts, session-agent gaps, MCP governance keys, table-editor limits, iris-couch gaps → FR-66, addendum §5, §6 and §12. FR-23's Retry-After is in catalog row CP-19. Stage 4's "guided workflows harvested from the MCP suite's prompts" is supported by the harvest digest (11 MCP prompts).
- D7 IPM elements, `CSPApplication` deprecation, per-namespace IPM, namespace choice in `iris.script`, deep-link fallback, pitfalls → addendum §6.
- D8 panel, context toggle, propose-review-confirm, run-as-user, read-only, kill switch, agent marker, citations, egress disclosure, cost bounds, tiered autonomy → §5.2, §5.3, §7, addendum §4, §8, §9.
- Prioritized list: the P0 row groups (SH, CP, WA, PM, SS, TM, OS, LG, PK) map one-to-one onto §5.1 to §5.11; the P1 groups onto FR-70 to FR-79; the cut line onto §10.1; the 26 judgment calls onto addendum §11; CP-42 and CP-43 onto FR-14 and FR-15.
- Open questions: 14 of the research's 18 rows are in PRD §13 or the Stage gates; see section 2 for the four not carried.

## 2. Gaps

Rated high / medium / low by what a PRD reader would miss without it.

### High

**G1. Token lifetime versus turn duration.** Research: access tokens live 60 s and refresh tokens 900 s, set by the issuing application (spike §4); the shell logs in at `/api/admin`, so "the shell will mostly carry `/api/admin`-minted tokens, whose lifetimes are `/api/admin`'s" (spike §7, quoted in addendum §2 only as "or raise access to 300"); the harvested loop is one blocking call per turn with a 90 s provider timeout and a 300 s gateway timeout (D6a). PRD FR-18 says every tool call uses only "the user's own token pair" and FR-17 says the write uses "the same endpoint the screen uses". A turn that runs longer than 60 s will therefore make admin-API calls with an expired access token unless the server refreshes mid-turn, the shell mints its tokens from `/api/ocupilot/login` (in-group, so still silent) with a longer `JWTAccessTokenTimeout` (any JWT application accepts any valid token, spike row 5), or tools run in-process under the authenticated `$USERNAME` rather than over HTTP. The PRD is silent. Land in: FR-1 or FR-18 consequence, NFR-3, addendum §2 settings table (which login endpoint the shell uses and why).

**G2. The admin API's privilege map and authorization are coarser than the classic portal's gates.** Research (api-coverage digest, `/info` and the UrlMap resource column): `GET /api/admin/info` computes `privileges` only over eleven `%Admin_*` resources and **returns 403 if the caller holds none**; per-endpoint authorization is `ResourcesOR` over `%Admin_*` resources with USE (Security endpoints need `%Admin_Secure`, processes and monitor `%Admin_Operate`, tasks `%Admin_Task`, databases `%Admin_Manage`); web-apps, web-sessions, devices, license and DocDB resources were not probed. The classic gates (addendum §7) additionally need `%DB_IRISSYS` READ or READ+WRITE. Consequences the PRD does not state: FR-3's guard call fails with 403 for any user without an `%Admin_*` resource, so such a user cannot enter OcuPilot at all; FR-4's "mirroring the classic portal's resource checks" cannot hold, because a user with `%DB_IRISSYS:READ` and no `%Admin_Secure` can view Users in the classic portal but gets 403 from `/security/users`; the gate must mirror the admin API's requirements, not the classic portal's. Land in: FR-3 (behavior on 403 from `/info`), FR-4 (gate source is the admin API's `ResourcesOR`, with the classic mapping as reference only), addendum §7.

**G3. Progress delivery needs a transport the harvested loop and the endpoint list do not provide.** Research D6a: "the loop is fully synchronous and non-streaming, one blocking call per turn ... nothing exists for progress or streaming"; Insight 6: "P0 needs at least progress delivery for multi-step turns; server-sent events can follow". PRD FR-12 requires tool-call cards to appear "while the turn is still running" and NFR-2 forbids a turn appearing frozen between tool calls, but addendum §3's custom endpoint list (run turn, load transcript, lock state, agent definition CRUD, credentials list, tool list) has no progress channel: either the turn endpoint streams events (SSE or chunked) or a progress-poll endpoint reads a per-turn progress record. Land in: FR-12 consequence and addendum §3 (add the progress endpoint or state that the turn endpoint streams step events).

**G4. Classic-portal sign-in from an OcuPilot-first login is unobserved** (detail in section 4, item 1). It matters here because FR-9, the cut-line fallback for every unfinished large editor, assumes "the user is already signed in there". If the classic portal does not pick up a JWT-issued `CSPBrowserId`, every FR-9 link costs a classic login. Land in: FR-9 consequence (state the fallback if the classic tab is not signed in), OQ list, and the spike's not-tested list.

### Medium

**G5. Plain IRIS Community Edition is untested and its default namespace is not interop-enabled.** Research [21] and the verify digest: the "second container" is port 52773, `product "irisforhealth"`, the same `irishealth-community` image; no plain `iris-community` image was probed, and HSCUSTOM does not exist there, so FR-67 falls to `USER`. Research D6a: the harvested installer "requires an interop-enabled namespace", and the credentials rung stores keys in `Ens.Config.Credentials`. PRD FR-26 relies on that rung and FR-68 claims automated tests on both stock images. Land in: FR-68 (mark plain Community as unverified until probed), FR-26 (what the credential rung does in a namespace without `Ens.Config.Credentials`), FR-67 (whether the installer interop-enables `USER` or falls back to the environment-variable rung), OQ list.

**G6. Outbound TLS for provider calls.** Research D6a: all four adapters "hard-code the SSL configuration name `DefaultSSL`, set no proxy". Addendum §5 says not to inherit the hard-coded name and §10.3 puts proxy and custom-CA at Stage 2, but nothing in Release 1 says who creates the SSL/TLS configuration that outbound HTTPS to OpenAI, Anthropic or Gemini needs on a fresh Community container. Land in: FR-24 (SSL configuration is a field of the definition or a named default the installer creates), FR-66 (installer creates it idempotently), UJ-2.

**G7. Rollback path in the proposal.** Research D8 requirements paragraph: "every write as a proposal with rationale, expected impact and, where possible, a rollback path"; practitioner caution [43]: approve "the specific proposed change, its expected impact, and the rollback plan". PRD glossary "proposal" and FR-17 stop at target, diff, rationale, expected impact. Land in: glossary "proposal", FR-17 consequence one ("and, where the write is reversible, the reverse write"). Undo (Stage 5) is a different feature; a stated rollback path costs one line per write tool.

**G8. Context-window trimming is absent from Release 1 while transcripts persist.** Research D6a: "context-window trimming (history is replayed in full each turn)" is on the must-add list. PRD FR-12 loads the transcript on open and keeps it across reloads; §10.3 defers "context-window management" to Stage 2. Release 1 turns therefore grow unboundedly in tokens and latency with conversation length, against NFR-1 and the per-turn token bound in §7.3. Land in: FR-12 or NFR-1 (a Release 1 cap: last N turns or a token budget), Stage 2 keeps the full feature.

**G9. UJ-1 depends on a polish-week feature.** UJ-1's climax is "cites the rows it used, and clicking a citation selects the row"; catalog CP-27 (citation chips with click-through) is P1 and lands in FR-71. FR-16 gives read tools row identifiers in P0, so a minimal citation (chip without click-through) is cheap. Land in: UJ-1 (soften the climax) or FR-16 (promote plain citations to Release 1 and leave click-through in FR-71).

**G10. Tool-result size ceiling.** Research D6b: the MCP suite enforces "a 32,768-character response ceiling with truncation markers"; FR-16 read tools return "the same fields the screen shows" over lists that NFR-1 sizes at one thousand rows and FR-11 sends "the visible rows" on every turn. No bound is stated for what reaches the model. Land in: FR-16 or NFR-1 (a per-tool-result and per-context cap with a truncation marker).

**G11. Read-only "default tier" versus switches.** Research D8: the field converges on "read-only as the default tier". Brief decision 2 makes read-only a switch, not a default. This is a deliberate inherited override, not drift, but the PRD never says so; §7.1 should record that the field default was considered and rejected for the contest. Land in: §7.1 or addendum §1.

**G12. Instance identity field.** Verify digest: "the two containers are distinguishable by `namespaces`, not by `serverVersion`" (identical build string). FR-3's "instance identity matches what it last saw" names no field; catalog SH-11 lists serverVersion, namespaces, apiVersion. The stable identifier observed is the JWT `iss` claim (instance name `<host>/IRIS`). Land in: FR-3 consequence two.

### Low

**G13. Contest fine print not carried:** dates may be moved by notice on the contest page and Rules override Terms (D1 [3]); approval is discretionary "based on the criteria of complexity and usefulness", final and not subject to appeal (D1 [2]); the OE page lists IRIS Cloud SQL as a platform (contradiction; the announcement governs); prize amounts are single-source. Land in: addendum §13.

**G14. Refresh work order.** Research staleness map: re-check contest claims again on 2026-09-28 (voting post), api-coverage and embeddability claims on the next IRIS release or by 2026-12-08, packaging claims when IPM 0.10.10 leaves beta. PRD OQ 1 covers only the 2026-09-14 re-check. Land in: FR-79 or §13.

**G15. Competitive leads not carried:** an Angular rebuild of the Production Monitor announced around March 2026 is "a plausible entrant" (D2 [35]); IrisWebClient took a $100 tier in Full Stack 2026; the kick-off panel includes the Analytics and AI product manager, "the only organizer-side signal that AI is in scope" (D2 [37]). Land in: addendum §9, §2.

**G16. Stage 3 and 4 gates omit the API role requirements:** `/api/atelier` needs `%Development`; `/api/interop-editors` needs `%EnsRole_InteropEditorsAPI` (D4 [22]). Land in: §10.3 table.

**G17. Four research open questions not in PRD §13:** the Mirror Monitor's absent async-authorization dialog (Stage 5); whether Configure User Events really offers export and import (touches FR-47, which safely does not claim them); whether the off-menu Provider pages are reachable (P4); whether `/api/security-config` is an official credentials and OAuth surface on IRIS for Health (could back FR-44 there); the classic portal's client-side auto-logout timer (relevant to FR-1 and FR-9). Land in: §13 or the Stage gates.

**G18. Shell details for the polish week:** the System Information panel refreshes every 10 s only with auto-refresh on and hides below 1,100 px; menu search is a 220 ms typeahead over name, title and tags only; About shows 14 fields and a 17-language selector (D3c [16]). Land in: FR-73 or addendum §7.

**G19. Provider set boundaries:** "Not present: Azure OpenAI, Bedrock, Vertex, Cohere, Mistral" and the caveat that "one subclass plus one registry entry" holds only for the server core because provider literals live in five places (D6a). Land in: §9 non-goals (which providers are out) and addendum §5.

**G20. The eleven validation rules are named but not enumerated** anywhere in the PRD or addendum (FR-24); they live in the harvest digest. Land in: addendum §5 pointer to `digests/harvest-session-agent-r1-1.md`.

**G21. Chat-history retention default.** Research D8 cites Gemini's 180 days as the precedent; FR-72's purge task states no default. Land in: FR-72.

**G22. Rec 10 housekeeping is still open:** `.claude/rules/reference-folders.md` still says the interop-editors OpenAPI document is available live from `/api/mgmnt/v2`; the research observed that it is not. Not a PRD item; record as a task.

## 3. Contradictions

Deliberate PRD-time overrides (addendum §1) or brief-inherited decisions, not drift:

- Streaming: research places "co-pilot streaming" at P2; PRD Stage 5 (addendum decision 7, OQ 14).
- Token metering: research P1; PRD Stage 2 (addendum decision 15).
- Agent picker: research D8 lists it as a recurring pattern; catalog CP-36 at P2; PRD Stage 3 (addendum decision 9).
- Read-only as the field's default tier (D8) versus read-only as a switch (brief decision 2) — inherited override, unrecorded in the PRD (G11).
- Analytics rows on Stage 4 (addendum decision 8).
- Platform floor IRIS 2026.2 (addendum decision 13) versus the harvested core's 2024.1 floor.

Drift or unresolved:

1. **"22 large P0 rows" versus 12.** Research prose ("Twenty-two of the 119 P0 rows are rated large") and the brief's cut line say 22; the catalog rates 12. Re-checked in `feature-catalog.md`: exactly 12 P0 rows carry complexity L (CP-12, CP-13, WA-05, PM-07, PM-12, PM-16, SS-14, SS-15, SS-16, TM-12, TM-13, LG-02). The research prose is the error; PRD OQ 13 can be closed and the brief's cut line corrected.
2. **NFR-13 versus addendum §6.** NFR-13 says IRIS 2026.2 or later; addendum §6 says the module's `<SystemRequirements>` declares IRIS 2022.1+. The research's 2022.1+ is IPM 0.10.x's own support floor (D7 [28]), not OcuPilot's. One of the two must change.
3. **Rec 2 and brief decision 5 say custom endpoints "only for messages.log, the application error log and the agent runtime"**; catalog row LG-01 and PRD FR-60 add a fourth, the alerts.log history tail, and addendum §3 adds read-only and kill-switch state. The catalog is the source of the alerts tail, so this is research-internal; the PRD should state that it follows the catalog rather than Rec 2's count.
4. **FR-4 "mirroring the classic portal's resource checks"** contradicts the admin API's `%Admin_*`-only authorization (G2).
5. **§3.2 "a thin interface by the contest's own rule."** The research's executive summary recommends exactly "a thin Angular UI over the REST services already on the instance"; the rule bans a thin interface "of an existing library or app". The PRD's reading that screens-only would fail the rule is not supported.
6. **PRD §8 and §12 treat the Atelier API's cookie-only call as "hangs on the browser's Basic prompt"**; the research says it "triggers" the prompt. Wording only.

No contradiction found in dates, prize amounts, timeline, judging criteria, hard requirements, tier placements of the P0 and P1 rows, API facts in addendum §3, or auth behaviors in addendum §2 (all match the research and the spike).

## 4. Requirements the research cannot support

1. **FR-1 consequence two, FR-2 consequence one, FR-9 consequence two, UJ-1 edge case: OcuPilot's form login "also signs the browser into the classic portal", sign-out "signs out the classic portal too", the classic link "is already signed in".** The spike observed: a JWT login sets `CSPBrowserId`; that cookie mints JWTs on in-group JWT applications; the Rule Editor iframe signs in from it (H4). No row opens a classic `/csp/sys` page in the `clean-jwt` context, and the classic portal is a CSP-session application, not a JWT one. "The classic portal ... logged out as well (row 23)" in spike §7 is an inference from minting stopping, not an observed classic-session end. The digest (§10 "OcuPilot-first") carried the inference as fact and the PRD inherited it. Treat as unverified; add to the spike's not-tested list and OQ.
2. **FR-68 consequence: "automated tests run against both stock images and confirm the admin API is present on each."** Both probed containers are `irishealth-community` (product `irisforhealth`, identical build 221U). Plain `iris-community` was never probed (G5).
3. **FR-22 consequence one: "The audit event for an agent write carries the agent marker in its description; the same write made by hand does not."** Catalog CP-16 backs the marker with OcuPilot's own `$System.Security.Audit` call. The system's own audit event for the underlying write (emitted by `Security.*` through the admin API) is identical whether the write came from a screen or the agent; nothing in the research shows the admin API accepting a caller-supplied description. The marker is therefore a separate OcuPilot-sourced event correlated by user, time and target, and FR-61's filter must look for that event. Reword rather than drop; UJ-3's resolution is still achievable.
4. **§3.2 non-user rationale** ("thin interface by the contest's own rule") — see section 3 item 5.
5. **PRD additions with no research basis, reasonable but unsourced** (owner-confirmed ones per addendum decision 10 are marked): FR-8 connectivity probe distinguishing unreachable from refused; FR-10 remembered panel width; FR-11 toggle resets to on per session; FR-32 refusal to delete OcuPilot's own applications (owner-confirmed); FR-37 refusal to disable or delete the current user; FR-39 role-delete warning with member count; FR-40 system resources not deletable; FR-41 web-service warning (owner-confirmed); FR-47 auditing-off warning (owner-confirmed); FR-51 Task Manager suspend warning; FR-55 refusal to act on the user's own process; FR-57 transaction warning on lock removal; FR-26 key entry written to the credential store (the harvested form has only a credentials picker). None conflicts with the research; each should be traced to the owner or to the classic page once its source is pulled (Rec 8).
6. **FR-3 "no area screen loads" on a version mismatch** is a PRD choice; the research asks only to pin v2 and check `apiVersion`. Supported as a design decision; noting it is stricter than the source.

## 5. Qualitative material the FR structure dropped

- **Positioning line (Rec 9):** "the agentic management portal built on IRIS's own management APIs". The PRD §1 opens with "an Angular replacement for the ... System Management Portal"; the research's line puts the agent first and the vendor's API second, which is the contest's own wording. Land in §1 first sentence.
- **What winning looks like (D2 [36]):** fields are small (17 in Developer Tools 2025, 16 in Full Stack 2026) and the $100 tier for places 6 to 10 means roughly the top 60 percent receive something; winners posts publish placements only, never votes, scores or rationale; a stable cohort recurs, Community voting favored it in 2026 and diverged from the Experts winner; the Experts top three in Developer Tools 2025 were editor and workflow tooling, not standalone web UIs; whether Docker, IPM or a demo video correlates with placement was not established. SM-1 targets first place in the Experts nomination without this calibration; only the cohort fact survives, in addendum §12. Land in §11 (a line under SM-1) and addendum §9.
- **Community voting mechanics (D1 [8]):** trusted DC members, one changeable vote each, blind counts with a daily leaderboard, earlier submissions listed higher. Only the last survives (§2). Land in addendum §13.
- **How the field's users describe what they praise and punish (D8 [43]):** praise for page context, follow-up memory and precise investigations ("identified the specific line ... throwing the ... 400 error"); punishment for "unreliable and irrelevant information that required too many steps", hallucination and ignored instructions; "the genuinely beneficial functionalities currently available are more limited than the marketing might imply". Addendum §8 keeps one sentence; the PRD's §12 compresses it to "slow, non-streaming turns". The research's actual complaint is relevance and reliability first, speed second, which argues for citations and screen-context accuracy over streaming. Land in §3.1 (the design target's expectations) and §12.
- **The practitioner rule (D8 [43]):** approve "the specific proposed change, its expected impact, and the rollback plan rather than simply instructing the agent to 'fix the database'". Dropped with the rollback path (G7). Land in §7.1.
- **Design principles stated in the research and not in the PRD:** "screens and an agent, not a backend" (Insight 2; the brief's gloss survives in §1 without the phrase); "recover before clean" (D6b; addendum §4 only); "reference in place, never copy" for the vendor bundles (§9 has it); "link an unfinished editor rather than ship it half-done" (FR-9 has it); "read the system class source before using it" and "the instance is authoritative, the exports drift" (research-first rule; addendum §12 last rows).
- **Interaction vocabulary not in any FR:** pre-populated hand-off forms, inline contextual insights beside errors, record-and-generate of console actions into scripts (D8 patterns). Addendum §8 lists them as vocabulary; no stage claims them. Land in Stage 4 or 5, or state them as out of scope.
- **The organizer-side AI signal (D2 [37]):** the kick-off panel includes the Analytics and AI product manager. Not carried; it is the only evidence that an agent-centred entry matches the organizers' intent before the bonuses post. Land in §2 or §12.
- **Data-source honesty framing (D8):** every shipped console assistant discloses where data goes; OcuPilot's local-model option is "the privacy-preserving default for regulated shops". §7.2 states the mechanics; the framing as a selling point for regulated IRIS shops (Rec 9) is absent from §2 and §3.1's production-administrator job. Land in §2 bullet three.

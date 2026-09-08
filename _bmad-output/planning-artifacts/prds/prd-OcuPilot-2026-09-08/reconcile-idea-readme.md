---
title: 'Reconciliation: initial-idea.md and README.md against the PRD'
status: draft
created: '2026-09-08'
inputs:
  - '../../../../docs/initial-idea.md'
  - '../../../../README.md'
against:
  - 'prd.md'
  - 'addendum.md'
  - '../../briefs/brief-OcuPilot-2026-09-08/addendum.md (for the inherited decisions)'
---

# Reconciliation: initial-idea.md and README.md against the PRD

What the two owner-supplied inputs say that the PRD and its addendum carried forward, failed to carry, contradicted, or silently weakened. Line numbers refer to the inputs as read on 2026-09-08. Ratings: **high** = touches the product's stated differentiator or a contest deliverable; **medium** = changes a requirement's meaning or leaves a decision unrecorded; **low** = traceability, wording, or a downstream-document matter.

Where an item says "verified", the claim was checked against source outside the four documents: `iris-session-agent/src/SessionAgent/Config/Agent.cls` for the agent option list.

## 1. Carried forward correctly

### initial-idea.md

| Input statement | Where it landed |
| --- | --- |
| L1 "Agentic System Management Portal for InterSystems IRIS ... take first place in the contest" | PRD §1 Vision para 2; SM-1 |
| L3 "a co-pilot like agent on the right hand side" | §1; §5.2 description; FR-10 (CP-01); brief inherited decision 3 |
| L3 "Always visible" | FR-10 "never closed by navigation", "no close control in Release 1" |
| L3 "base this on preliminary work done in ../iris-session-agent" | §8 sibling projects; addendum §5 harvest map row 1; FR-24 (eleven validation rules, provider cascade); FR-25 (adapters) |
| L3 "context aware of what is on the screen" | FR-11 (CP-09, CP-10); Glossary "screen context"; FR-12 transcript keyed by screen context |
| L3 "Edits to settings should be allowed through tools that the agent has access to" | §5.3; FR-17 (CP-13); FR-18 |
| L5 "Incremental build ... limited timeframe" | §10.1 cut line; §10.3 stages; SM-2; SM-C3 |
| L5 "minimum requirements mentioned in the contest rules as the top priority" | §10.1 (P0 = the six areas); brief inherited decision 1; §3.2 "thin interface" rule |
| L5 harvest from iris-session-agent, iris-execute-mcp-v2, iris-table-editor and the classic portal | §8; §10.3 Stages 3 to 5; addendum §5 (adds iris-couch as a fourth source, an owner extension, not a loss); addendum §7 for the classic portal's mechanics |
| L7 "built in Angular and served from IRIS" | §1; FR-65; addendum §6 "Serving the SPA" |
| L7 "packaged as this workspace with a docker instance" | FR-67 (PK-14) |
| L7 "deployed with ZPM/IPM" | FR-64 (PK-10, PK-15); NFR-13 (IPM 0.10.x); addendum §6 |
| L8 "If necessary, we will also add our own custom Api" | §1 para 2 ("the only new server code ..."); Glossary "OcuPilot API"; addendum §3 custom endpoints |
| L8 "any custom API should attempt to self install or be deployed with IPM" | FR-64, FR-66, FR-67; NFR-9 |
| L8 "should not assume that any of my previous projects are installed ... avoid package collisions" | FR-66 third consequence; §8 penultimate bullet; §9 non-goal; addendum §6 "Names to avoid" |
| L8 "install in HSCUSTOM namespace if present or User namespace if not" | §5.11 description; FR-67 first consequence; addendum §2 table; addendum §6 "Namespace choice"; brief inherited decision 8 |
| L10 "The portal must have an agent configured to run properly" | §3.2 (no definition = thin interface); FR-20 third consequence (the unconfigured state until a definition is enabled, decision 16); FR-28. Note: FR-66 still says the installer seeds "the seed agent state disabled", which decision 16 now distinguishes from the kill switch; align the wording |
| L10 configuration screen "similar to ... iris-session-agent" shown after login when unconfigured | FR-28 (CP-08); FR-24; UJ-2 |
| L10 "All of the agent model options in ../iris-session-agent" | FR-25 four provider families (CP-04, CP-05); FR-24 field list, partially (see G-A4) |
| L12 parity with the classic portal + all iris-session-agent functions + UI equivalents of iris-execute-mcp-v2 | §1 para 3; §10.3 Stages 2 to 6; addendum §14 |
| L14 "use the pre-built editors ... by embedding them" | §8 (Stage 4); §10.3 Stage 4 "embedded in place with silent sign-in"; §9 "loaded in place from the instance"; addendum §2 "Embedded editors" (Rule, DTL, BPL only; see G-A5) |
| L16 review instruction (irisdocs, irissys/%Api*, irislib/%Atelier, the two sibling repos, EnsPortal) | Satisfied through research.md and its digests: %Api in §2 and §8; %Atelier in §8 and Stage 3; the classic portal's `%CSP.UI` mechanics in addendum §7; both sibling repos in addendum §5 |

### README.md

| Input statement | Where it landed |
| --- | --- |
| L7-12 product overview (Angular rebuild, served from IRIS, docked right like VS Code, knows the screen, runs as the user, propose/review/confirm) | §1 Vision, near-verbatim; FR-10, FR-11, FR-17, FR-18 |
| L14-17 contest 48, deadline 2026-09-27 23:59 EST | §2; addendum §13; FR-69 |
| L17-26 the six areas and their enumerations | §5.5 to §5.10, FR-30 to FR-63 (PRD is a superset: adds Kerberos in FR-45) |
| L19 "chiefly the hidden `/api/admin` v2 service" | Glossary "admin API"; §8; FR-3; NFR-8 |
| L28-29 "Only a handful of endpoints ... are new server code" | §1 para 2; addendum §3 |
| L29-31 bring-your-own-model, four providers including local, configured on first login | FR-25; FR-28 |
| L31-33 one IPM module; Compose self-installs; Community and IRIS for Health Community | FR-64; FR-67; FR-68; NFR-13 |
| L35-38 parity, harvest from siblings, "the administration portal InterSystems itself points at" | §1 para 3; §10.3; SM-6 |
| L50-55, L119-133 durable storage on `./iris-data` | FR-67 "including on a durable data volume"; addendum §6 Docker bullet |
| L57 "`HSCUSTOM` namespace is the default target for everything here" | §5.11; FR-67; addendum §2 |
| L63 ObjectScript under `src/OcuPilot/` | addendum §6 last bullet |
| L101-104 expired `_SYSTEM` password on Community images | UJ-5 edge case; FR-67 first consequence; addendum §6 pitfalls |
| L71, L352 MIT license | OQ 9 knows it is MIT; FR-69 requires "an open-source license file" (name not carried, see G-B3) |

## 2. Gaps

### initial-idea.md

**G-A1 (high). The agent as "the main conduit for editing within the portal" (L3).**
The PRD says "with the agent as the primary way changes are made" only in §1's post-contest paragraph. Release 1's FR structure makes screens and agent peers: one FR per screen editor, the agent's tools stated once in §5.3, the cut line (§10.1) dropping hand-built editor forms last, and FR-9 sending unfinished editors to the classic page in a new tab where the agent is absent. No requirement, constraint or metric says the agent is the primary editing path in Release 1. SM-C1 has the right instinct ("an action without its write tool counts against SM-3") but does not state the converse: an action whose write tool and proposal card work counts toward SM-3 even when its form is cut.
Land: §1 para 2 (Release 1 sentence); §5.3 description; §10.1 cut line; SM-3 and SM-C1 wording.

**G-A2 (medium). "context aware of what is on the screen at all times" (L3).**
FR-11 sends context per turn and allows a session-long off toggle; awareness is per turn, not continuous. Nothing requires the panel to follow navigation between turns: update the context chip, re-key the transcript, or tell the agent the user moved mid-conversation. FR-12 loads "the transcript for the current screen context" which implies re-keying but does not state it.
Land: FR-11 consequence ("the context chip and transcript key follow navigation without a new turn"); FR-12.

**G-A3 (medium). "the framework should be extendable like ../iris-session-agent" (L10).**
FR-16 requires tool extensibility through a registry. FR-25 is titled "Four provider families" and fixes the count; no consequence says a fifth provider is added by implementing the provider base without touching the loop, the config form's cascade or the validation rules. Addendum §5 reuses "provider base and the four adapters" as-is, which implies it, but a harvest note is not a requirement.
Land: FR-25 consequence, or a new FR in §5.4 "Extensible provider and tool framework".

**G-A4 (medium). "All of the agent model options in ../iris-session-agent should be supported" (L10).**
Verified: `SessionAgent.Config.Agent` holds AgentName, Provider, Model, MaxTokens, Temperature, SystemPromptOverride (8,192), CredentialName, EnvVarName, EndpointUrl, ReadOnly, Enabled, SearchChatRetentionDays, MaxIterationsPerTurn. FR-24 carries eleven. Dropped or remodeled: per-definition `ReadOnly` (the PRD's read-only is instance-wide plus per-user, decision 2) and per-definition `SearchChatRetentionDays` (FR-72 has one retention purge task, no per-definition setting). A per-definition read-only flag is exactly what Stage 3's "a developer agent and an operations agent can differ by area" needs.
Land: FR-24 field list; FR-19 (a third read-only source: the definition); FR-72.

**G-A5 (medium). "use the pre-built editors ... by embedding them" (L14), applied to the six areas.**
Embedding is deferred to Stage 4 and covers only the interop-editors Angular apps. For the six contest areas the pre-built editors are the classic Zen/CSP pages (task wizard, edit task, SSL editor, OAuth editors), and FR-9 opens them in a new tab instead of embedding them same-origin in the shell. Addendum §2 documents the cookie-based silent sign-in that would make an in-shell iframe work with no host involvement. The PRD records neither why embedding is not applied to the six areas nor that none of the twelve vendor Angular apps in `irisui/` covers a contest area.
Land: FR-9 (choose new-tab link vs same-origin iframe inside the shell, keeping the panel visible; record the choice); §9 rationale sentence.

**G-A6 (medium). "should self install when the container is upped" (L8).**
FR-67 states the observable result and defers build-vs-start to OQ 5; addendum §6 cites the idea and proposes build-time load plus a start-time idempotent re-check. Missing: (a) the upgrade trigger: a newer image or module on an existing durable `./iris-data` volume must upgrade OcuPilot on start (README L121-123 says durable storage survives image upgrades); NFR-9 says upgrade is safe to repeat but no FR says when it runs; (b) a start-time hook is the only mechanism that satisfies both the idea and durable `%SYS`, so the PRD could commit to it and leave only the build-time pre-load as an optimisation.
Land: FR-67 consequence; OQ 5 narrowed.

**G-A7 (medium). "HSCUSTOM if present or USER" for "any custom ObjectScript" (L8), on the IPM path.**
The rule is stated for the Docker path (FR-67) and in the §5.11 description, but FR-64 (IPM install) is silent, and addendum §6 notes the manifest cannot choose the namespace because IPM is per-namespace since 0.9.0. Under `zpm "install ocupilot"` the module lands wherever `zpm` runs, possibly neither HSCUSTOM nor USER. The PRD does not say whether the installer redirects, refuses or accepts the caller's namespace.
Land: FR-64 consequence; addendum §6.

**G-A8 (low-medium). "although they may be present" (L8): coexistence, not only name isolation.**
FR-66 isolates names; nothing requires OcuPilot to install and run on an instance where iris-session-agent's `%ALL` mapping, web applications and purge tasks, and iris-execute-mcp-v2's `/api/executemcp/v2` application and `ExecuteMCPv2.*` package are present. The README's development sandbox is such an instance as soon as the MCP suite is registered (its bootstrap is a TypeScript-driven self-install, addendum §5).
Land: FR-66 or FR-68 consequence: install and the six-area smoke test pass with the sibling projects installed.

**G-A9 (low). "ui equivalents of the functions supported in ../iris-execute-mcp-v2" (L12).**
§1 says "a screen for every tool"; §10.3 Stage 5 harvests handler bodies into 128 endpoints. No coverage matrix ties each of the suite's tools (five servers: dev, admin, interop, ops, data) to a screen or agent tool; the `iris-dev` tools (globals, compile, unit tests, macro info, env diff and promote) are only implied under Stage 3 "System Explorer" and Stage 5 "developer tools".
Land: §10.3 Stage 5 gate ("MCP-tool-to-screen coverage matrix"); `extract-stages.md`.

**G-A10 (low). "all the functions in ../iris-session-agent" (L12): PRD and addendum disagree on a stage.**
Addendum §5 places the 28 read-only interoperability tools at Stage 4; PRD §10.3 Stage 5 says "The agent gains the 28 iris-session-agent tools on the interoperability screens". One is wrong.
Land: §10.3; addendum §5.

**G-A11 (low). ZPM/IPM references (L7: two YouTube links, "search for the official IPM documentation").**
Addendum §6 reflects IPM 0.10.x research (deprecated `<CSPApplication>`, `${dbrole}`) but cites neither the videos nor the official IPM documentation. Traceability only.
Land: addendum §6 citation line.

**G-A12 (low). "Where possible ... official APIs ... documented in ./irisdocs/" (L8): the preference order is never stated.**
The PRD adopts the hidden admin API (see C-A1) but nowhere states the principle "documented `%Api` route first, admin API second, custom endpoint last". FR-33/34 use the documented `/api/mgmnt` and FR-60 the documented `/api/monitor`, so the practice exists. The principle would settle Stage 2 to 5 choices where a documented route and an admin-API route both exist.
Land: §8 first bullet or §7.

### README.md

**G-B1 (medium). "the Docker Compose workspace in this repo self-installs it on start" (L31-32).**
The PRD leaves build vs start open (FR-67, OQ 5). The README promises the mechanism; the PRD promises only the result. Either the PRD commits or the README softens; today a judge reading both sees a promise the requirements do not make.
Land: FR-67; OQ 5.

**G-B2 (medium). The sandbox and the MCP suite share the container (L50-55, L283-350).**
The README positions this container as the development sandbox the iris-execute-mcp-v2 suite is registered against. FR-66 avoids that suite's names, but nothing requires OcuPilot to be tested on the sandbox with the suite's server side present, nor states that OcuPilot's self-install and the suite's self-install (both create web applications and packages on first contact) must not race or clobber each other.
Land: FR-66 or FR-68 test matrix; addendum §6.

**G-B3 (low-medium). License: MIT (L71, L352).**
FR-69 requires "an open-source license file" without naming it; OQ 9 asks whether MIT is compatible with the contest IP grant; the brief addendum says "read the terms before choosing a license" as if the choice were open. The README has already chosen.
Land: FR-69 consequence ("the license is MIT unless OQ 9 forces a change"); OQ 9 gets an owner date before the 2026-09-14 listing.

**G-B4 (low-medium). Durable storage "survives ... image upgrades" (L121-123).**
FR-67 covers `down` then `up`; the upgrade case (new OcuPilot version on an old durable volume) is only implied by NFR-9. Overlaps G-A6.
Land: FR-67; NFR-9.

**G-B5 (low). Host port offsets 52774 and 1973 (L67, L96, L147-158).**
The PRD states no URL or port; UJ-2 and UJ-5 "open `/ocupilot`". The README install steps FR-69 requires, and the demo video, must state `http://localhost:52774/ocupilot`; the offset exists to coexist with a second container on this machine, which a judge will not have, but the README's ports are what they will type. Addendum §2's dev-proxy note (SameSite=Strict cookie) is the only port-sensitive design point and is covered.
Land: FR-69 consequence; FR-67.

**G-B6 (low). Status line "planning is complete and implementation is starting" (L40).**
The PRD front matter is `status: draft` with 14 open questions, and the README links the idea, research, catalog and brief but not the PRD.
Land: README status line and PRD link after finalization; PRD `status`.

**G-B7 (low). "Only a handful of endpoints (`messages.log`, the application error log, the agent runtime)" (L28-29).**
Addendum §3, as revised by decision 16, names the alerts.log history tail as a fourth custom endpoint, and the agent runtime alone is "roughly six" (run turn, load transcript, lock state, definition CRUD including the read-only and kill-switch state, credentials list, tool list). The README understates; a judge will check the README's list against the repository.
Land: README once architecture fixes the endpoint list; the PRD Glossary is already accurate.

**G-B8 (low). One image in the sandbox vs FR-68 "both stock images" (L50, L67).**
The workspace runs only `irishealth-community`; FR-68's consequence needs a second compose profile or a CI matrix (FR-79) that the README does not provide.
Land: FR-68; FR-79; README "Development sandbox".

**G-B9 (low). `src/OcuPilot/` will hold "eventually the IPM module manifest" (L63) vs addendum §6 `<SourcesRoot>src</SourcesRoot>`.**
IPM convention puts `module.xml` at the repository root with `SourcesRoot` pointing at `src`; the README places the manifest under `src/OcuPilot/`. Neither README, CLAUDE.md nor the PRD says where the Angular workspace lives or how the built bundle enters the module (`<FileCopy>`).
Land: architecture; README table row; addendum §6.

**G-B10 (informational; README maintenance, not PRD).** The README's MCP registration (L302-347) registers user-scope servers with `IRIS_PORT=52774`, while CLAUDE.md says the user-scope `IRIS_*` variables point at 52773 and this project's profile comes from the code-workspace through `IRIS_SERVER_MANAGER=auto` as `ocupilot-iris`; L172 "No password is stored in the repo" sits beside `IRIS_PASSWORD=SYS` at L307. The profile-name rule (L199-235, profile must not equal the lowercased folder name) is a VS Code extension constraint with no PRD analogue and is correctly absent from the PRD; addendum §6's ban on `IRIS_*` environment variables in OcuPilot is consistent with it.

## 3. Contradictions

### initial-idea.md

**C-A1. Official, documented APIs vs the hidden admin API.**
Idea L8: "use the official APIs exposed in IRIS through the %Api classes ... and documented in ./irisdocs/". PRD §8 and Glossary: the admin API "is hidden, undocumented and unsupported". `%Api.Admin` is a `%Api` class but is absent from `irisdocs/` (reference-folders.md: "treat it as undocumented/internal").
Classification: deliberate, inherited (brief decision 5, owner-set), reinforced by §2's "powered by InterSystems IRIS management APIs" argument. The PRD never acknowledges that it overrides the idea's "documented" clause; the only mitigations are OQ 3 (support stance) and NFR-8 (OpenAPI document under test).
Recommend: one sentence in §8 or addendum §1 recording the override and the reason: the documented `%Api` set (Atelier, mgmnt, monitor, DocDB, DeepSee, interop-editors) covers none of security, tasks, processes, databases or devices.

**C-A2. "at all times" vs the screen-context toggle.**
Idea L3 vs FR-11 and §7.2: context sharing can be switched off for a session.
Classification: drift. The toggle comes from the field survey (addendum §8, "page-context sharing on by default and toggleable"), not from the owner: it is in neither the brief's eight inherited decisions nor addendum §1's sixteen, and decision 10's confirmed-assumption list does not name it. §7.2 supplies a privacy rationale after the fact.
Recommend: record it as an owner decision in addendum §1, or drop the toggle from Release 1 and rely on read-only mode plus a local model for privacy.

**C-A3. Configuration screen "presented to the user" vs OcuPilot administrators only.**
Idea L10 vs FR-28 and decision 1 (non-administrators see the configuration-empty state).
Classification: deliberate, recorded (addendum §1 decision 1). Consistent. README L31 "configured on first login" glosses over who.

**C-A4. "the main conduit for editing" vs the Release 1 peer model.**
Idea L3 vs §1 para 2, §10.1 and FR-9.
Classification: drift. Brief inherited decision 2 ("read/write") and decision 1 ("the six areas ... as screens") neither demote nor promote the agent; the PRD's FR structure makes the screens primary by weight. See G-A1.

**C-A5. Self-install "when the container is upped" vs build-vs-start open.**
Idea L8 and README L31-32 vs FR-67 and OQ 5.
Classification: deliberate deferral, recorded in addendum §6 with the idea cited. Both inputs say start; only the PRD hedges. See G-A6, G-B1.

**C-A6. A custom API "like I have previously done for ../iris-execute-mcp-v2" vs iris-couch patterns.**
Idea L8 vs addendum §3 ("not the MCP suite's `%Atelier.REST` envelope") and §5 (do not inherit the TypeScript-driven self-install or the `%Development`-gated web application).
Classification: deliberate, recorded. The idea's intent, a self-installing custom API, survives; only the envelope and bootstrap differ. No action.

**C-A7. "pre-built editors ... by embedding them" vs FR-9 new-tab links.**
Classification: partly deliberate. "Link an unfinished large editor to the classic portal page" is a brief-time decision ("List early, cut cleanly"), so linking is owner-set for unfinished editors; but the idea's embedding preference was never weighed against it, and an in-shell iframe would honour both the brief's link and inherited decision 3 (panel always visible). See G-A5.

**C-A8. HSCUSTOM-else-USER vs IPM's per-namespace install.**
Classification: latent and unacknowledged in the PRD body; addendum §6 records the mechanism constraint without stating that FR-64 cannot honour the rule as written. See G-A7.

**C-A9. Three harvest sources vs four.**
The idea names iris-session-agent, iris-execute-mcp-v2 and iris-table-editor; the PRD and README add iris-couch (owner extension made mid-research on 2026-09-08). Not a contradiction; the idea document is now behind the plan.

### README.md

**C-B1. "self-installs it on start" vs OQ 5.** README more specific than the PRD. See G-B1.

**C-B2. "Status: planning is complete" vs PRD `status: draft` with 14 open questions.** README written ahead of the PRD's state. See G-B6.

**C-B3. Harvest scope.** README L36-37 harvests iris-execute-mcp-v2 "for its governance model"; the idea (L12) and PRD §10.3 Stage 5 harvest its handler bodies for 128 endpoints and "a screen for every tool". The README also omits iris-table-editor and iris-couch. README understates the idea and the PRD.

**C-B4. "configured on first login" vs the administrators-only gate (FR-28).** README glosses; PRD deliberate (decision 1).

**C-B5. Three custom endpoints vs addendum §3's list.** README-side understatement. See G-B7.

**C-B6. License sequence.** README fixed MIT before the brief addendum's "read the terms before choosing a license" was answered; PRD OQ 9 still open. Flag for the owner: is MIT a decision or a placeholder?

## 4. Qualitative ideas the FR structure dropped

### initial-idea.md

- **"co-pilot like" (L3).** The PRD's panel is a chat with context and tool-call cards. The co-pilot connotation, a companion that volunteers help, notices what the user is doing and offers the next step, survives only as UJ-6's "the Task Manager line in the panel's suggested view" (which no FR defines) and polish-week FR-70 suggested prompts. Addendum §8 lists "inline contextual insights beside errors" and "investigate entry points" as field patterns; the former has no FR at any stage, the latter is Stage 4. Land: §5.2 description; a Release 1 consequence defining the "suggested view" UJ-6 already relies on; UX EXPERIENCE.md.
- **"Always visible" (L3).** FR-10 carries it, but three exits weaken it silently: narrow viewports (a UX decision), FR-9's new-tab links to classic pages, and full-screen mode. State the invariant positively in FR-10 ("on every OcuPilot route, at every width, the panel is reachable without navigation") and keep the shell around classic pages in FR-9.
- **"the main conduit for editing" (L3).** See G-A1, C-A4. The strongest single loss.
- **"context aware ... at all times" (L3).** See G-A2, C-A2.
- **Incremental build (L3, L5, L12).** Carried as tiers, the cut line and SM-2. Dropped nuance: incrementalism as a framework property, that adding a screen is cheap. FR-16 makes adding a tool cheap; nothing says screens are built from a shared list, detail and editor pattern. Land: §5.1 description or architecture.
- **"take first place" (L1).** SM-1 carries the target. Dropped nuance: the judging criteria (Complexity, Clarity of Instructions, Developer Experience, Applicability, Usability) order the polish week (§5.12) but not Release 1's P0 work, and "Clarity of Instructions" and "Developer Experience" are README and repository qualities that FR-69 states minimally. FR-79 (bonuses) and SM-4 (the one-minute demo) carry the rest of the ambition. Land: §10.1 (tie cut-line order to the criteria); FR-69 (a README quality bar; UJ-5 already implies "a stranger installs from the README alone").
- **"comprehensive" (L3).** Carried as parity (§1, §10.3).
- **"harvesting from ... the original System Management Portal" (L5).** The classic portal's conventions (header strip, favorites, recents, About, Help, "Did you know") are in addendum §7 and FR-73 at polish week. Carried.

### README.md

- **"the way VS Code docks its secondary side bar" (L9).** Carried in §5.2. The analogy also implies a keyboard toggle and a remembered layout; FR-10 has remembered width, NFR-12 keyboard operation, no explicit keyboard focus or toggle for the panel. Low; UX.
- **"A throwaway IRIS an agent can safely drive, break, and rebuild" (L55).** The disposable-sandbox philosophy matches FR-67's "from a clean clone", but the PRD does not require a documented reset-and-reinstall path for judges (UJ-5's edge case covers only the expired password). Low; FR-69.
- **"until OcuPilot is the administration portal InterSystems itself points at" (L38).** Carried in §1 and SM-6.
- **"every write it proposes is shown, reviewed, and confirmed before it runs" (L11-12).** Carried in FR-17, §7.1.

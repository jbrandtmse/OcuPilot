# Extract: research report and digests for the OcuPilot PRD

**Extracted:** 2026-09-08 from `_bmad-output/planning-artifacts/research/technical-ocupilot-portal-feature-landscape-2026-09-08/` — `research.md` (decision report), `spike-auth-handoff.md`, `digests/auth-spike-r2-1.md`, `digests/contest-field-r1-1.md`, `digests/agent-patterns-r1-1.md`. `feature-catalog.md` was **not** read (separate extract).

**Citation keys used below.** `D1`–`D8` are research.md dimension sections (`D3a`–`D3d`, `D6a`–`D6d` are sub-sections); `Rec N` is a numbered Recommendation; `insight N` is a numbered cross-dimension insight; `[n]` is a research.md source-appendix reference; `spike row N` is a row of the observation log in `digests/auth-spike-r2-1.md` §2; `spike §N` is a section of that digest; `contest-field digest` and `agent-patterns digest` are the other two digests; `handoff §N` is `spike-auth-handoff.md`. Catalog row IDs (SH-01, CP-42, …) are quoted where research.md uses them.

---

## 1. Contest facts

### The task, verbatim (D1 [2])

> Create a GUI powered by InterSystems IRIS management APIs for the following Management Portal tasks:
> - Manage web apps and explore REST APIs
> - Permission management
> - Security and Secrets management (with wallet, x509 creds, OAuth setup, etc.)
> - Task management
> - Operating system management (processes, disks, CPU, memory, devices, etc.)
> - All the logs - what's being reported to the user from various sub-systems
> - Feel free to add any other screens or actions you frequently use!

- The Open Exchange (OE) page carries the shorter form "Create a GUI powered by InterSystems IRIS management APIs for certain Management Portal tasks" (D1 [1]; contest-field digest).
- **Whether an entry covering only some of the six areas is accepted is not stated**; approval is at the experts' discretion "based on the criteria of complexity and usefulness", final and not subject to appeal (D1 [2]; Open questions row 2).
- Contest number: 48 on Open Exchange (contest-field digest).

### Timeline (D1 [1][2][4]; verified by two InterSystems sources for every dated row except the webinar; both pages write the timezone as "EST")

| Event | Date | Days from 2026-09-08 |
| --- | --- | --- |
| Contest opens, registration starts | 2026-09-14 00:00 EST | 6 |
| Kick-off webinar (Derek Gervais, DevRel Evangelist; Raj Singh, PM Developer Experience; Carmen Logue, PM Analytics and AI) | 2026-09-14 12:00 EDT | 6 |
| Submission deadline | 2026-09-27 23:59 EST | 19 |
| Voting period | 2026-09-28 to 2026-10-04 23:59 EST | 20 to 26 |
| Winners announced | not stated anywhere read | |

- Improvements and bug fixes are explicitly allowed through the voting week (D1 [1][2]; [8]).
- InterSystems may move dates by notice on the contest page; contest-specific Rules override the generic Terms (D1 [3]).
- Kick-off agenda text: organizers will "discuss the topics we'd like participants to explore and show you how to develop, build, and deploy applications". Suggested starting templates: `iris-fullstack-template`, `iris-dev-template`, `rest-api-contest-template` (contest-field digest; [4]).

### Hard pass/fail requirements (D1 [1][2][3][6]; contest-field digest)

1. Fully functional.
2. Not "an import or a direct interface for an already existing library" — not a thin interface or copy-paste of an existing library or app.
3. New to Open Exchange, or an existing app "with a significant improvement".
4. Runs on IRIS Community Edition or IRIS for Health Community Edition (the OE page also lists IRIS Cloud SQL, a minor contradiction; the newer announcement governs).
5. Open source on GitHub or GitLab.
6. README in English with installation steps and **either a video demo or a description**. The OE page alone adds **"a link to the idea"** to the README requirement (single-source, cheap to satisfy) [1].
7. At most three submissions per developer or team.
8. The application must already be a **published Open Exchange listing before applying** (applications go through the contest page, the app's Contest tab, or the developer portal) [6][3] — medium confidence: the verifier found this only indirectly supported on the contest pages themselves.
9. Deliberately obfuscated source is not allowed [3].
10. Teams of 2 to 5 must link every member's Developer Community (DC) profile in the README [2].

### Judging criteria (D1 [1])

Complexity, Clarity of Instructions, Developer Experience, Applicability, and Usability — single-source (OE page); "reads like the standard contest template".

### Prize tiers (D1 [2]; amounts single-source)

- **Experts nomination:** $5,000 / $2,500 / $1,000 / $500 / $300, then $100 for places 6 to 10.
- **Community nomination:** $600 / $400 / $100 (versus $1,000 / $600 / $250 in Developer Tools 2025 — contest-field digest).
- **Freshmen nomination (new this round):** $600 / $400 / $100, eligible if "no more than 5 previous InterSystems programming contests" and "never placed 1st, 2nd, or 3rd".
- Total pool stated on the tag-page teaser: $12,000 (contest-field digest).
- Community voting, by precedent from the immediately preceding contest (medium confidence [8]): trusted DC members, one changeable vote each, blind counts with a daily leaderboard, and **earlier submissions listed higher on the contest page**.

### Technology bonuses (D1 [1][2][5][8])

- **No bonuses post exists for this contest as of 2026-09-08**; the contest page says "Look forward to the announcement of the technology bonuses", so one is coming (verified; low confidence on content). A bonuses post is likely around the 2026-09-14 kick-off.
- **Precedent (Full Stack Contest 2026 [5]):** Vector Search 3, Embedded Python 3, DC Idea 2, Docker 2, IPM 2, Online Demo 2, Find a Bug 2, First DC Article 2, Second Article 1, YouTube Video 3, YouTube Short 1, First-Time Contribution 3 — stated maximum 26. **No Angular, AI, REST, or code-quality bonus appeared.**

### What the rules do not say (D1 [3][7]; medium confidence, absence across six InterSystems pages)

No framework restriction, no mandate to use REST, no prohibition on reusing InterSystems portal code or UI bundles, no named license, no definition of "management APIs", no winners date. The Terms include an **intellectual-property grant to InterSystems; read it before choosing a license** [3][7].

### The field of entrants (D2 [34][35][36]; contest-field digest)

- **Empty as of 2026-09-08:** the OE contest page's embedded JSON has `"participants":[]` (three occurrences); the announcement has one comment (Anton Yartsev asking whether the Community Bounty Program counts against Freshmen eligibility; unanswered); the Management Portal tag carries no entrant posts [34].
- **One unread lead:** Raef Youssef, "Rebuilding the IRIS Production Monitor as a Modern Angular App — Looking for Feedback" (~March 2026), a plausible entrant with an Angular admin-style app already in progress (D2 [35]).
- **Prior art on Open Exchange** (D2 [35]; contest-field digest table): bg-iris-agent (Banksia Global, ObjectScript "AI IRIS Agent" that reads portal data and modifies non-critical settings; 2 stars; last push 2025-06-23; nearest conceptual competitor); irislab (caretdev/Dmitry Maslennikov, TypeScript + Python/Flask, explicitly pitched as "a modern compelling replacement for System Management Portal"; 0 stars; dormant since 2024-08-27); apptools-admin (Sergey Mikhailenko; globals, SQL, export; 2023 Developer Tools entrant); iris-history-monitor (diashenrique; 16 stars, last push 2022-05-15; featured on the contest page's app strip); iris-user-manager (Oliver Wilms); IrisWebClient (Dmitry Konnov, Pascal GUI, $100 tier in Full Stack 2026); WebTerminal (featured on app strip; deprecation string unverified); production-monitor (Oliver Wilms, $100 tier 2022); gj::configExplorer (John Murray, VS Code); dark-mode workarounds (Yuri Marx, Julian Matthews). Rules allow dormant apps to re-enter "with a significant improvement". **Nothing found covers the six administration areas coherently.**
- **What winning looks like** (D2 [36]): fields are small (17 apps in Developer Tools 2025, 16 in Full Stack 2026); a $100 tier for places 6 to 10 means roughly the top 60 percent of a field receives something; winners posts publish placements only, never votes, scores or rationale; a stable cohort recurs (Pereira/Dias team, Yuri Marx, Muhammad Waseem, John Murray, Dmitry Maslennikov); Community voting favored that cohort in 2026 (withLove 1st) while diverging from the Experts winner (Iris Global Guard AI); Developer Tools 2025 Experts top three were editor/workflow tooling (two VS Code extensions and an ORM driver), not standalone web UIs. Whether Docker, IPM or a demo video correlates with placement was not established.
- **Freshmen eligibility for this entrant:** iris-table-editor took a $100 tier in Full Stack 2026, which is not a top-three finish, so the Freshmen nomination may still be open depending on the number of prior contests entered (D2 [36]; Open questions row 16).
- **Organizer AI signal:** the kick-off panel includes the Analytics and AI product manager (Carmen Logue) — the only organizer-side signal that AI is in scope (D2 [37]; contest-field digest).

---

## 2. Recommendations

**Rec 1 — Scope the contest build to the six named areas, the co-pilot core, a minimal shell and the submission deliverables, and nothing else before 2026-09-27.** Feeds the brief's scope and the PRD's must-have tier. High confidence: the task statement is verbatim and verified [2], and three of the six areas live in each of two portal sections (System Administration [18], System Operation [11]). Depends on: D1 task statement; D3a/D3b page mapping; the D4 coverage table.

**Rec 2 — Build P0 on the hidden `/api/admin` v2 service, `/api/monitor` and `/api/mgmnt`, adding custom endpoints only for messages.log, the application error log and the agent runtime.** Feeds the architecture spine. High confidence on existence and routes (verified live on two containers) [21]; the dependency risk is real because the API is undocumented, so **pin v2, check `apiVersion` at startup and keep the generated OpenAPI document under test.** Depends on: D4 coverage map; the `/api/admin` risk paragraph; D6b for handler bodies of the custom endpoints.

**Rec 3 — Adopt the silent-first JWT design: OcuPilot's REST application enables JWT and joins `%ISCMgtPortal`, the shell logs in silently first and by form second, and JWT-only login is the built-in fallback.** Settings: the static shell at AutheEnabled 64 like `/ui/interop`, no group needed; the REST application password-enabled with JWT on, `UseSession=0`, in the vendor's group; the shell tries an empty-body `POST /api/admin/login`, then its own form; Bearer on every JWT-enabled API; JSON refresh; logout with the cookie. Feeds the architecture spine and the PRD's login and session requirements. High confidence: observed on the instance in both flows, with a no-group control and a curl reproduction [46]; the residual risk is the documented deprecation of Group by ID, covered by the fallback. Depends on: spike §6–§8 (Design A); insight 1.

**Rec 4 — Assemble the agent runtime from the session-agent server core plus the MCP suite's governance model, and add what neither has:** progress or streaming, propose-review-confirm for writes, execution strictly as the user, a read-only mode, distinct audit marking of agent-initiated changes, a test-connection action, a first-login configuration gate, and sanitization of log content before it reaches the model. Feeds the PRD's co-pilot requirements and non-functional requirements. High confidence on what exists and what is missing [10][27]; medium on the pattern set, which rests on vendor documentation [39][41] and one practitioner framework [43]. Depends on: D6a, D6b, D8; insights 5 and 6.

**Rec 5 — Package as one IPM module with `<WebApplication>` plus `<FileCopy>` for the committed Angular bundle, a second web application with a dispatch class, and an installer `<Invoke>`; have the Dockerfile load it at build time and an idempotent installer re-check it at start; serve deep links through a `%CSP.REST` static handler in the IRISCouch style.** Feeds the architecture spine and the PRD's install requirement. Medium confidence: the manifest elements are current [28], the templates are dated [29], and **the durable-volume interaction is unverified.** Depends on: D7; D6d (IRISCouch static handler and installer); insight 9; Open questions row 5.

**Rec 6 — List on Open Exchange and apply on 2026-09-14 with a submittable build, then improve visibly through 2026-10-04; publish a Developer Community article, a YouTube video and short, an online demo, and an Ideas Portal link in that window; re-check the bonuses post after the kick-off.** Feeds the brief's go-to-market section. High confidence on the rules [1][2][6][8]; the bonus list itself is precedent only [5]. Depends on: D1 rules and bonus precedent; insight 10.

**Rec 7 — Sequence post-contest work as P2 (API-backed parity: the rest of `/api/admin`, System Explorer over Atelier with the table-editor grid, Interoperability over the v7 API with the three document editors embedded), then P3 (custom-REST parity harvested from the MCP suite's handlers), then P4 as demand shows.** Feeds the PRD roadmap and epics; the itemized order is in `feature-catalog.md`. High confidence on the API boundary [20][21]; embeddability verdicts are inferences [24]. Depends on: D4, D5, D6b, D6c; the Prioritized feature list.

**Rec 8 — Pull the legacy CSP pages out of the container before writing the task-builder and log-viewer forms.** Feeds PRD screen specifications. High confidence that they are the blind spot [11][18]. Depends on: D3a/D3b legacy-CSP lists; insight 7; Open questions row 6.

**Rec 9 — Position the product as the agentic management portal built on IRIS's own management APIs:** no incumbent covers the six areas, the vendor's modernization has not reached administration, execute-with-approval and distinct audit are open differentiators, and a local model option keeps data on the instance. Feeds the brief's positioning and the PRD's differentiation. Medium confidence: the field is empty today [34] and prior art is dormant [35], but the bonuses and the kick-off scoping are still unknown. Depends on: D2, D8; insights 3 and 5.

**Rec 10 — Correct the project rule file that says the interop-editors OpenAPI document can be pulled from `/api/mgmnt/v2`; on this build it cannot.** Housekeeping; high confidence, observed live [20]. Depends on: D4 ("`/api/mgmnt/v2` refuses to return the spec for InteropEditors and lists only spec-based services").

**Inside-P0 cut line (Prioritized feature list, inference from complexity ratings).** If the sprint runs short, ship in this order, and link any unfinished large editor to the classic portal page rather than ship it half-done: (1) every list and detail screen with its co-pilot read tool; (2) the co-pilot core; (3) the small write actions in permissions, tasks and OS management (enable, disable, run, suspend, resume, terminate, delete); (4) the medium editors (web application create, user and role create, resource, device, wallet); (5) the large editors (web application edit, user and role edit, service edit, SSL and LDAP editors, the task wizard). Twenty-two of the 119 P0 rows are rated large.

**Tier sizes (Prioritized feature list):** 538 catalog rows (535 distinct): P0 119 (contest MVP, submittable by 2026-09-27), P1 62 (polish and bonuses, 2026-09-28 to 2026-10-04), P2 137 (API-backed parity), P3 164 (custom-REST parity), P4 56 (long tail kept with reasons). **Judgment calls the PRD should revisit** (26 listed in the catalog; five named): locks view and removal at P0 although tier rules put locks at P2; wallet at P0 on an undocumented route because the contest names it; interoperability and Analytics logs at P1 although both need custom endpoints; web sessions at P1 rather than P0; the memory configuration page at P3 while memory monitoring is P0.

---

## 3. Insights (cross-dimension)

**Insight 1 — Authentication was the one cross-cutting decision every other dimension waited on, and the spike settled it.** Each REST application keeps its own path-scoped session cookie [22], but that cookie is not what carries a login: a browser-id cookie set by any login mints JWTs on every API that shares the issuer's Group by ID, one Bearer is accepted by every JWT-enabled application, and the embedded editors mint their own tokens from the same cookie, whether it came from the classic portal or from OcuPilot's own login [46]. The design that follows is Rec 3: the shell tries an empty-body `POST /api/admin/login` first (silent for users arriving from the classic portal), falls back to its own login form, keeps one token pair in sessionStorage, sends Bearer to every JWT-enabled API, refreshes on a timer and on 401, and logs out with the cookie so the whole browser-level login ends. Residual risk: the documentation's deprecation of Group by ID, mitigated by the JWT-only path that needs no group. The table-editor core's per-call Basic auth [9] still applies to Atelier, which accepts no JWT.

**Insight 2 — The contest floor is already API-backed, so P0 is a thin UI over existing REST plus two custom endpoints.** The six contest areas [2] map onto about 40 pages in two portal sections [11][18]; five of the six are fully served by the hidden `/api/admin` v2 service and `/api/monitor` [21]; only "all the logs" needs custom endpoints, for messages.log and the application error log, because no REST route and no backing class exist for either [20]. This changes the 19-day plan from "build a backend" to "build screens and an agent".

**Insight 3 — The hidden admin API is where InterSystems itself is heading, which makes it both the safest bet and the biggest dependency.** The dispatcher rewrites Location headers to an `/iris/api/admin/` prefix [21]; the vendor's Angular work has modernized only interoperability screens [37]; its own new-UI web apps carry the same Group by ID and JWT pattern as `/api/admin` [22][25]. Inference: the vendor is building the administration API before the administration UI. Building on it also satisfies the contest's "powered by InterSystems IRIS management APIs" wording verbatim [2]. Counterweight: the API is hidden and undocumented [21]; mitigation is in D4 and Rec 2.

**Insight 4 — The sibling MCP suite fills the custom-REST gap almost exactly.** D4's list of functions with no route anywhere [20] is, handler for handler, what the MCP suite's ObjectScript already wraps [27]. Harvest those handler bodies into OcuPilot's own `%CSP.REST` dispatcher built on the IRISCouch patterns [26] rather than inheriting the suite's `%Atelier.REST` envelope or its TypeScript-driven bootstrap.

**Insight 5 — The co-pilot's core exists; its safety layer does not, and the MCP-suite sibling has it.** The session-agent core supplies providers, tool contract, registry, audit and chat history [10]; the field converges on run-as-user, propose-review-confirm, read-only default, kill switch and distinct audit attribution [39][41][43]; the session agent has none of those for writes because it blocks writes outright [10]; the MCP suite's governance (tool and action keys, default-disabled writes, a read-only preset, server-side confirm gates, a redacted audit log) is that missing layer [27]. Combining the two is the agent runtime. **Differentiators the field leaves open:** distinct audit marking of agent-initiated changes, execute-with-approval from the panel, and a local OpenAI-compatible model that keeps data on the instance [10][39][41].

**Insight 6 — Streaming is the largest engineering gap, and users punish exactly the symptom it causes.** The harvested loop is one blocking call per turn with a 90-second provider timeout and a 300-second gateway timeout [10]; the loudest complaint about console assistants is that they are slow, irrelevant and take too many steps [43]. **P0 needs at least progress delivery for multi-step turns; server-sent events can follow** (streaming is P2 in the catalog).

**Insight 7 — The legacy CSP pages are the inventory's blind spot, and they cluster inside the contest areas.** Backup, SQL Gateway, Web Gateway Management, task-manager email, enable and disable auditing and the Security Advisor [18], plus the task-builder wizard with about 60 fields, the application error log, the messages log, system usage and the dashboard [11], have no exported source. Task creation and two of the log viewers are contest-area screens. Pull those `.csp` files from the container before writing the P0 forms.

**Insight 8 — Embed versus rebuild splits cleanly along the URL contract, and interoperability can wait.** Of the 68 interoperability leaves, 67 are Zen [13]; the three document editors (rule, DTL, BPL) embed with a hidden embedded mode and events, production configuration and the message viewer embed as opaque pages, and the rest must be rebuilt or linked [24]. None of it is in the contest's six areas [2], so interoperability is post-contest work where embedding buys the three hardest editors for little cost once authentication is solved.

**Insight 9 — The four install patterns in evidence contradict each other, and this repository already uses durable `%SYS`.** The vendor templates install at image build time [29]; the MCP suite bootstraps at runtime over the Atelier API [27]; IRISCouch commits its bundle and relies on an installer class [26]; the idea behind this project wants install on container start with a bind-mounted data directory. Reconciliation: one IPM module as the single source of truth (web applications, file copy, an installer invoke) that the Dockerfile loads at build time and an idempotent installer re-checks at start — **but the build-time and durable-volume interaction is unverified.**

**Insight 10 — The rules reward listing early and improving continuously.** The Open Exchange listing must exist before applying, earlier submissions are listed higher on the contest page, improvements are allowed through the voting week, and the field is empty [2][6][8][34]. Strategy: a submittable build listed on 2026-09-14, then two weeks of visible improvement, rather than a single drop on 2026-09-27.

**Contrary evidence (research.md "Contrary evidence").** The red-team pass was off; no adversarial search for disconfirming evidence was made. The strongest counter-arguments surfaced incidentally: the documentation's "do not use" on Group by ID versus the vendor's own use of it [20][22], and the unsupported status of the hidden admin API [21].

**Evidence standing (Executive summary).** 46 sources; 28 ledger claims, 12 verified by fresh-context checks or the spike, 1 disputed (the MCP suite's exact tool count, 104 vs 108 [27]), 15 resting on a single credible source; a semantic citation sample of 12 found no unsupported claim but three numeric corrections, now applied.

---

## 4. Competitive and comparable landscape

### The vendor's own portal (D2 [37][38]; D3; contest-field digest)

- The classic System Management Portal (SMP) is Zen; **Zen is deprecated** [38]. Its inventory: System Administration 90 menu leaves (Configuration 54, Security 30, Licensing 2, Encryption 4; ~209 of 296 exported portal classes) (D3a [18]); System Operation 19 top-level entries, 36 leaves (19 Zen, 17 legacy CSP), ~70 screens (D3b [11]); shell + System Explorer (11 leaves, 38 classes) + Analytics (18 leaves, 87 `%DeepSee.UI` classes) (D3c [16][17]); Interoperability 68 live leaves, 76 in source, 224 EnsPortal classes (D3d [13][14]).
- **InterSystems' modernized (Angular-era) UI is opt-in and covers interoperability surfaces only**: 2026.1 lists Production Configuration, Message Viewer and Search, the BPL Editor embedded in VS Code, Rule Editor (30-minute activity timeout); 2026.2 adds a read-only Schema Viewer and states "All other Interoperability screens remain in the Standard user interface" (medium/low confidence, search extracts) [37]. **No evidence that security, users and roles, OAuth and X.509, tasks, OS views or logs have moved.** On the instance, exactly one leaf is Angular by default (Build > Business Rules); three more flip to Angular only when `^%SYS("Interop","DefaultNewUI")` is set (D3d [13]).
- A community question (2025-10-30) asks how to add custom portal pages "the new way", described second-hand as REST pages with JWT authentication bootstrapped from the session cookie (low confidence; now confirmed by the spike) [38][23][46].
- Read with D4's hidden admin API and its `/iris/api/admin/` Location-header prefix: **InterSystems appears to be building the administration API before the administration UI, and the contest targets exactly that gap** (D2; insight 3).
- Community demand for cosmetic/accessibility improvements (dark mode requests and workarounds, banner colour changer) exists between Aug 2025 and Aug 2026 (contest-field digest).
- **InterSystems ships no AI assistant inside the IRIS Management Portal** (D8 [44]; agent-patterns digest). Adjacent first-party pieces: **IRIS AI Hub** (early access; ObjectScript agents SDK, bidirectional MCP, "Enforce role-based access to models and tools, hold credentials in the InterSystems IRIS Wallet", integrates with Interoperability "human workflow facilities to set up advanced approval workflows" — a possible integration point for OcuPilot's confirm step); **Data Studio AI Assistant** (separate product; admin-configured LLM vendors; optional Langfuse trace logging).

### Other contest entries and community prior art (D2 [35][36]; contest-field digest — see section 1 for the table)

- Nearest conceptual competitor: **bg-iris-agent** (agent that reads portal data and modifies non-critical settings; 2 stars; dormant since 2025-06). Nearest in intent: **irislab** (explicit portal replacement; TypeScript + Flask; dormant since 2024-08; author Dmitry Maslennikov is a repeat Experts placer). Both could re-enter with "a significant improvement".
- Community AI precedents in the ecosystem (D8 [44]; agent-patterns digest): `iris-session-agent` (2026-05-08; embeds Search and Inspection agents inside the Interoperability Message Viewer and Visual Trace pages, pure ObjectScript, "17 disciplined tool calls", **citations to rows**, per-namespace provider/model/credential config — the project owner's own sibling); `iris-copilot` (2026-02-20; lifecycle agent where "deployment is executed only after explicit human approval" with "Rollback by version snapshot"); `iris-mcp-data-exposure-toolkit` (2026-08-30; tool allowlisting through a dedicated IRIS user/role).

### AI admin copilots in adjacent products (D8 [39]–[45]; agent-patterns digest exemplar table)

| Product | Panel | Context | Acts or drafts | Confirmation / permissions | Audit | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Microsoft Azure Copilot agents (Troubleshooting, Deployment, Optimization, Resiliency, Migration, Observability) | "sidecar mode" panel or full-screen chat; agent chosen from New-chat dropdown | Azure resource context | **Acts** on the user's behalf; also produces scripts | "No actions are performed without approval"; "An agent cannot perform any action that the user themselves could not perform directly" (secondary) | Activity Log under the user's identity, **no agent marker** (acknowledged gap) | Observability GA, others preview; tenant toggle on by default; per-agent disable; Entra scoping |
| Amazon Q Developer in the AWS console | sidebar icon opens chat on every page | page context; list/describe resources (preview); error diagnosis; Cost Explorer | **Drafts only** — "Can I ask Amazon Q Developer to make application changes from the console? No." | IAM `q:*` actions + `q:PassRequest`; `Deny q:*` blocks | not found | Free tier / Pro $19 per user per month; Organizations AI-services opt-out |
| Google Gemini Cloud Assist chat panel | spark icon side panel, expandable to full page | "Page context sharing" **on by default**, user can disable | **Drafts** copyable snippets and "an equivalent query you can run yourself to verify"; "Create investigation" button pre-populated from chat | investigations need Investigation Creator IAM role | chat history auto-deleted after 180 days; conversations may be stored in any Google data center | free in preview; investigation creation reportedly Private Preview since 2026-04-10 (contradiction noted) |
| Google Database Observability / Onboarding agents | Cloud Assist chat; in-product investigations; CLI; MCP; IDEs | telemetry, Monitoring, Logging, Trace | **Acts with approval** — "can execute validated actions with your approval, such as adding indexes" | shows "the rationale and expected impact before you commit to the change" | not specified | remediations "in preview with select customers" |
| Elastic AI Assistant for Observability | upper-right flyout + inline **contextual insights** beside errors | `get_data_on_screen` reads the current page | reads, generates, **executes** queries; calls ES/Kibana APIs | "with the same level of permissions as the user"; Kibana privilege gate | not specified | data "not anonymized… processed by third-party AI providers"; deprecated in 9.4 for Elastic AI Agent |
| Grafana Assistant | Grafana Cloud UI | telemetry | troubleshoot, manage dashboards | "conversations respect RBAC"; vetted providers | — | thin page |
| Datadog Bits AI | — | — | seven features incl. Detection (autonomous) and **Remediation** | not on overview | — | priced in AI Credits |
| ServiceNow Now Assist for ITOM | AI Agent Studio | consumes Gemini investigations | investigates alerts | GCP **service account**, not the user | — | Zurich release |
| IBM Db2 Console as a Service 1.0 | multi-tenant console | — | AI assistant | admin-configured LLM provider | **LLM token metering per user and per tenant** | only console found that meters AI cost in the admin UI |
| Microsoft Database Hub (Fabric) + Copilot in SSMS 22 | Fabric portal; SSMS chat | estate signals | "agent-assisted, human-in-the-loop" | human in the loop | — | early access / GA |
| JetBrains DataGrip 2026.1 | IDE chat; "Analyze SQL Plan with AI" | schema, plan | drafts only | — | — | bundled |

Not reached by the research: Kubernetes dashboard assistants, MongoDB Atlas/Compass, pgAdmin, DBeaver, Oracle Cloud console AI, MuleSoft, Boomi (agent-patterns digest Gaps).

### What OcuPilot differentiates on (Rec 9; insights 3 and 5; D8)

1. **No incumbent covers the six contest areas**; the field is empty and prior art is dormant [34][35].
2. **The vendor's modernization has not reached administration** [37]; OcuPilot builds on the vendor's own hidden admin API, satisfying "powered by InterSystems IRIS management APIs" verbatim [2][21].
3. **Execute-with-approval from the panel** — rare in the field, mostly preview-gated (Google DB agents) or refused (AWS) [39][41].
4. **Distinct audit marking of agent-initiated changes** — even Azure lacks it [39].
5. **A local OpenAI-compatible model option that keeps data on the instance** — turns the egress concern into a selling point for regulated IRIS shops (already in the harvested provider set [10]).
6. **An always-on co-pilot** as the differentiator the rules invite under "any other screens or actions" (Executive summary; D1).

---

## 5. Authentication as testable behaviors

All facts in this section are from `digests/auth-spike-r2-1.md` [46] unless noted; research.md D4 "Auth and session model" [22], D5, Rec 3 and insight 1 integrate them. Instance: IRIS for Health Community 2026.2, container `ocupilot`, JWT `iss` = `b066ba383583/IRIS`. Method: two throw-away static web applications (`/ocupilot-spike` with `GroupById=%ISCMgtPortal`, `/ocupilot-spike-nogroup` without; both `AutheEnabled=64`), curl, and Chrome in three contexts (default = classic portal form login; clean-jwt = isolated, JWT login only; clean-portal = isolated, classic login only). Everything created was removed.

### Established before the spike (handoff §2; [22][25])

- Web-application settings observed live: `/csp/sys` AutheEnabled 96 (password + unauthenticated), CSRFToken 1, GroupById `%ISCMgtPortal`, cookie path `/csp/sys/`; `/ui/interop` AutheEnabled 64, GroupById `%ISCMgtPortal`, CSRFToken 1; `/api/interop-editors` and `/api/admin` AutheEnabled 32, JWTAuthEnabled 1, GroupById `%ISCMgtPortal`, `UseSession=0`, own cookie paths; `/api/atelier` AutheEnabled 32, **no JWT, no group**, `UseSession=1`, cookie path `/api/atelier/`; all SessionScope 2 (SameSite Strict).
- `/api/monitor` is unauthenticated with the `%DB_IRISSYS` role; `/api/atelier` requires the `%Development` resource; `/api/interop-editors` requires the `%EnsRole_InteropEditorsAPI` role; no REST application sets a CSRF token (D4 [22]).
- `/ui/interop` static files are served unauthenticated with **no X-Frame-Options and no Content-Security-Policy**; only `/csp/sys/UtilHome.csp` sends `X-FRAME-OPTIONS: SAMEORIGIN` (D5 [25]).
- The Rule Editor must be loaded at exactly `/ui/interop/rule-editor/index.html?$NAMESPACE=<ns>&rule=<class>`; its API root is derived from `/ui/interop` in its own URL (D5 [24]).

### The mechanism, as established (spike §6)

1. **One browser-level login identity: the `CSPBrowserId` cookie** (`path=/`, `httpOnly`, `SameSite=Strict`, no `Expires`). Issued by (a) a classic portal login that goes through the CSRF-token path (`/csp/sys` has `CSRFToken=1`; **a form POST without the hidden `IRISSessionToken` field still logs in but is not issued a browser id** — spike rows 24–26) and (b) any JWT login on a JWT-enabled application (row 1).
2. **Minting:** `POST <jwt-app-root>/login` with an **empty body** and that cookie returns a fresh access/refresh pair for the same user, **only if the JWT application carries the same `GroupById` as the application that issued the cookie**. Out-of-group JWT applications answer 401 (rows 17–19, 27). Members of `%ISCMgtPortal` on the instance: the classic portal, `/ui/interop`, `/api/admin`, `/api/interop-editors`, `/api/security-config`, `/csp/fhir-management/api`, the two OAuth2 API apps and `/csp/healthshare/hssys/app/api`.
3. **Authorization:** only `Authorization: Bearer <access>` authorizes a data call on these applications; **cookies alone never do** (`UseSession=0`) (rows 3, 20, 29, 34, 40). **Any JWT-enabled application accepts any valid, unrevoked token from this instance regardless of group or `app` claim** (rows 5, 13, 15). `/api/atelier` and `/api/mgmnt` (`JWTAuthEnabled=0`) accept only Basic or their own CSP session (row 6).
4. **Renewal:** `POST <root>/refresh` with JSON `{"refresh_token": …}` returns a new pair under the same `sid` (row 7); the refresh token sent as a Bearer header instead → 401 `WWW-Authenticate: Bearer` (row 8). The vendor bundles refresh at `exp − iat` minus a cushion, and on any 401 they refresh and retry once (`refreshTokens()` in `ui/interop/rule-editor/main.*.js`).
5. **Ending:** `POST <root>/logout` (null body, Bearer) ends that `sid`; **when the browser-id cookie accompanies it, the browser-level login ends as well**, so every in-group application stops minting (rows 22–23). `POST <root>/revoke` `{"refresh_token"}` ends the `sid` only (row 10). The classic `?IRISLogout=end` ends the browser-level login too (row 28).
6. **The embedded editors need nothing from the host.** Loaded same-origin in an iframe, they call `doLogin()` with no arguments, mint from the cookie, keep their tokens in the frame's `sessionStorage` (`Rule_Editor-0-accessToken`, `-user`, `-refreshToken`), and render — whether the browser id came from the classic portal or from OcuPilot's own JWT login (rows 31, 38, 41).

### Decoded JWT claims (spike §4)

All tokens: header `{"alg":"ES256","typ":"JWT"}`. Access token payload `{iat, exp, iss, sub, sid, app}`; refresh token payload `{iat, exp, iss, sid, app}` (no `sub`). Login response also carries top-level `access_token`, `refresh_token`, `sub`, `iat`, `exp`. **Access lifetime 60 s; refresh lifetime 900 s** — the `JWTAccessTokenTimeout` / `JWTRefreshTokenTimeout` of the issuing application, defaults applied by `Security.Applications.Create`. `app` claim values: `/api/admin/`, `/api/interop-editors/`, `/csp/fhirsql/api/ui/`. **The `app` claim is not enforced on acceptance.** A refreshed pair keeps the same `sid`.

### Every observed HTTP status and failure mode (spike §1 verdict table and §2 observation log)

| Behavior | Observed |
| --- | --- |
| `POST /api/admin/login` JSON `{"user","password"}`, no cookies (curl) | **200**, tokens, `Set-Cookie: CSPBrowserId=…; path=/; httpOnly; sameSite=strict` (row 1) |
| `POST /api/admin/login` empty body, no cookies | **401** (row 2) |
| `GET /api/admin/info`, no credentials | **401** (row 3) |
| `POST /api/interop-editors/login` empty body, no cookies | **401** (row 4) |
| `GET /api/admin/v2/namespaces`, `/api/admin/info`, `/api/interop-editors/v7/HSCUSTOM/mgmt-url`, `/api/security-config/credential/v1/credentials` with admin Bearer or interop-editors Bearer | **200** on all four, both Bearers (row 5) |
| `GET /api/atelier/`, `GET /api/mgmnt/v2/` with either Bearer | **401 / 401** (row 6) |
| `POST /api/admin/refresh` JSON `{"refresh_token"}` | **200**, new pair, same `sid` (row 7) |
| `POST /api/admin/refresh` with refresh token as Bearer, empty body | **401** `WWW-Authenticate: Bearer` (row 8) |
| `POST /api/admin/logout` access Bearer only | **200**; then namespaces with that Bearer 401; refresh with that refresh token 401 (row 9) |
| `POST /api/admin/revoke` Bearer + JSON `{"refresh_token"}` | **200**; refresh afterwards 401 (row 10) |
| Wrong password | **401** (row 11) |
| Bearer with last character altered (tampered signature) | **401** (row 12) |
| `GET /csp/fhirsql/api/ui/` none / Basic / admin Bearer | **401 / 200 / 200** (row 13) |
| `POST /csp/fhirsql/api/ui/login` JSON | **200**, token `app="/csp/fhirsql/api/ui/"` (row 14) |
| fhirsql Bearer (out-of-group app) → `/api/admin/v2/namespaces`, `…/mgmt-url` | **200 / 200** (row 15) |
| `GET /csp/fhir-management/api/` none / admin Bearer | **401 / 404** (authenticated, route absent) (row 16) |
| `POST /api/interop-editors/login` with `Cookie: CSPBrowserId=<from admin login>` only | **200**, token `app="/api/interop-editors/"`, different `sid` (row 17) |
| `POST /api/admin/login` same cookie only | **200** (row 18) |
| `POST /csp/fhirsql/api/ui/login` same cookie only (no group) | **401** (row 19) |
| `GET /api/admin/info` same cookie only | **401** (row 20) |
| `POST /api/interop-editors/login` with garbage `CSPBrowserId` | **401** (row 21) |
| Bearer-only logout, then cookie-only login | 200; then **200** (cookie survives a Bearer-only logout) (row 22) |
| Bearer + cookie logout, then cookie-only login | 200; then **401** (row 23) |
| Classic form login with hidden `IRISSessionToken` | **302** to home; `Set-Cookie` csp-sys session, `CSPBrowserId`, `CSPWSERVERID` (row 24) |
| Classic form login **without** the hidden token | **200** logged in ("Welcome, _SYSTEM"); `Set-Cookie` csp-sys session, `IRISSessionToken`, `CSPWSERVERID`, **no `CSPBrowserId`** (row 25) |
| Both login endpoints with cookies from row 25 in every combination (each alone, all, all-but-one) | **401** on every combination (row 26) |
| `CSPBrowserId` from row 24 only → interop-editors login / admin login / fhirsql login | **200 / 200 / 401** (row 27) |
| Classic `?IRISLogout=end`, then cookie-only login | 200; then **401** (row 28) |
| Browser, default context, spike page: `GET /api/admin/info`, `…/mgmt-url`, `/api/admin/v2/namespaces` cookies only | **401 / 401 / 401** (row 29) |
| Same page: `POST /api/interop-editors/login`, `POST /api/admin/login` cookies only, empty body | **200 / 200**; request `Cookie: CSPWSERVERID; IRISSessionToken; CSPBrowserId` (the `/csp/sys/` session cookie is path-excluded) (row 30) |
| Iframe `/ui/interop/rule-editor/index.html?$NAMESPACE=HSCUSTOM`: frame's `POST /api/interop-editors/login`, then `info`, `mgmt-url` ×2, `%25SYS/system-mode`, `sourcecontrol/enabled` | **200** on all; toolbar New / Open / Save / Save As / Compile / Test rendered, no login form (row 31) |
| Same from `/ocupilot-spike-nogroup` | **identical statuses**; editor rendered — the serving application's Group by ID is irrelevant (row 32; H1-control) |
| Iframe `…&VSCODE=1`: parent receives `{"direction":"vscode","type":"compatible"}` after 225 ms, then `{"type":"changed","dirty":false}`; parent posts `{type:"auth",username,password}` | `POST /api/interop-editors/login` body `{"user":"_SYSTEM","password":"SYS"}` → **200**; editor rendered without top banner; **the password crosses into the frame and onto the wire** (row 33) |
| clean-jwt: `POST /api/admin/login` JSON; then `GET /api/admin/info` cookies only; then `POST /api/interop-editors/login` empty body | **200; 401; 200** (row 34) |
| clean-jwt: `GET /api/atelier/` cookies only from a page | **pending forever**: 401 with `WWW-Authenticate: Basic` opens Chrome's native credential dialog and blocks the fetch (row 35) |
| clean-jwt, ~7 min later, the 60-second Bearer expired | **401 / 401** (row 36) |
| `POST /api/admin/refresh` JSON; then both GETs with refreshed Bearer | **200; 200 / 200** (row 37) |
| clean-jwt iframe | 200 on all; editor rendered; frame sessionStorage keys `Rule_Editor-0-accessToken/-user/-refreshToken` (row 38) |
| clean-portal: classic form login in browser | 302; `Set-Cookie` csp-sys session, `CSPBrowserId`, `CSPWSERVERID` (row 39) |
| clean-portal page: both empty-body logins; `GET /api/admin/info` cookies only | **200 (`sub=_SYSTEM`) / 200 / 401** (row 40) |
| clean-portal iframe | editor rendered, banner `RULE EDITOR account_circle _SYSTEM`, no password field (row 41) |
| clean-portal after `?IRISLogout=end` in a sibling tab: both empty-body logins; frame's stored Bearer → `…/mgmt-url` | **401 / 401 / 401** (last is consistent with either revocation or the 60-second expiry; not isolated) (row 42) |

**Verdicts (spike §1):** H1 (shared session, portal-first) pass with the correction that cookies never authorize data calls; H1-control identical (Group by ID on the serving page is irrelevant); H2 (JWT-only, no portal login) pass; H3 carrier = `CSPBrowserId`; H4 (OcuPilot-first) pass silently, no `VSCODE=1` needed. **One login covers every JWT-enabled application on the instance, in or out of the group.**

### Recommended web-application settings (spike §7; Rec 3)

| Setting | `/ocupilot` — static Angular shell | `/api/ocupilot` — OcuPilot's own REST | Rationale |
| --- | --- | --- | --- |
| Type | CSP application, `ServeFiles=1`, `Path` = built bundle directory | REST, `DispatchClass` = the `%CSP.REST` subclass | as `/ui/interop` and `/api/admin` |
| `NameSpace` | `HSCUSTOM` if present, else `USER` | same | project rule |
| `AutheEnabled` | **64** (unauthenticated static files, exactly like `/ui/interop`); the SPA performs the login itself | **32** (password) | rows 24, 34 |
| `JWTAuthEnabled` | n/a | **1** | rows 5, 15 |
| `JWTAccessTokenTimeout` / `JWTRefreshTokenTimeout` | n/a | 60 / 900 to match the vendor, or raise access to 300 to cut refresh traffic; the shell will mostly carry `/api/admin`-minted tokens whose lifetimes are `/api/admin`'s | spike §4 |
| `GroupById` | **not needed** (H1-control); harmless if set | **`%ISCMgtPortal`** for Design A (silent minting); omit for Design B | rows 17–19, 27 |
| `UseSession` (dispatch class parameter) | n/a | **0** | `/api/admin`, `/api/interop-editors` |
| `CookiePath`, `SessionScope` | defaults (`/ocupilot/`, Strict) | defaults | `CSPSESSIONID-*` plays no role; `CSPBrowserId` is `path=/` regardless |
| `CSRFToken` | 0 | 0 | protects CSP login forms only |

### What the Angular shell does (spike §7; Rec 3; insight 1) — testable behaviors

1. **Startup:** `POST /api/admin/login` with an **empty body** and `credentials: "include"`. **200** → the user is logged in (portal-first case, or a returning tab); store the pair. **401** → show OcuPilot's own login form and `POST /api/admin/login` with `{"user","password"}` (OcuPilot-first case). Either way the response sets or refreshes `CSPBrowserId`.
2. **Token storage:** `sessionStorage` (per tab, as the vendor does), **never `localStorage`**; the shell adds `Authorization: Bearer` to every call to `/api/admin`, `/api/interop-editors`, `/api/security-config` and `/api/ocupilot`. One token serves all of them.
3. **Refresh:** schedule `POST /api/admin/refresh` `{"refresh_token"}` at `exp − iat − 10 s`; on any 401, refresh once and retry; if the refresh fails, return to the login form.
4. **Logout:** `POST /api/admin/logout` with the Bearer **and** `credentials: "include"`, then clear `sessionStorage`. This ends the browser-level login too, so the classic portal and the embedded editors are logged out as well (row 23).
5. **Atelier (`/api/atelier`):** the token is not accepted, and a cookie-only call from the page triggers the browser's native Basic-auth prompt (row 35). **Never call it without an explicit `Authorization: Basic` header, or route Atelier-backed features through `/api/ocupilot`.** Lead: `Security.Applications` could enable JWT on `/api/atelier` by configuration; not tested because it changes a vendor application (Open questions row 14). The iris-table-editor core's per-call Basic auth [9] applies here (D6c).
6. **Embedded editors:** iframe `/ui/interop/<editor>/index.html?$NAMESPACE=…&rule|DTL|BP=…` in normal mode; they log in silently after either login path. Use `VSCODE=1` only where the host needs the `saved` / `compiled` / `bad*` events, and then post the `auth` message knowing the password enters the frame (row 33). **Untested alternative:** because the frame is same-origin and shares the tab's `sessionStorage`, the host could write `Rule_Editor-0-accessToken` / `-refreshToken` / `-user` before loading `?VSCODE=1`, so the editor starts authenticated without ever seeing a password (spike §7; D5).
7. **Embedded-mode contract** (D5 [24]): `VSCODE=1` hides the top bar, suppresses the automatic login, honors `READONLY=1`, posts `compatible`, `saved`, `compiled` and `badrule` / `baddtl` / `badbpl` events to the parent, and accepts inbound `auth`, `compile`, `revert`, `undo` and `redo` messages, **with no origin check**. The HealthShare bundles have no such contract. **Normal-mode chrome escapes the frame**: the logo link navigates the frame to the classic portal home, and cross-app links open sibling editors in new tabs.

### Two viable designs (spike §8)

- **Design A — silent-first with Group by ID (recommended for the contest; = Rec 3).** The shell tries the empty-body login first, so a user arriving from the classic portal is never asked to log in, and OcuPilot's own REST application joins `%ISCMgtPortal`. Trade-off: depends on a setting the documentation deprecates, but it is exactly what the vendor's shipped portal, editors and admin API use, and the JWT-only fallback is built in.
- **Design B — JWT-only, no Group by ID on OcuPilot's own applications.** The shell always shows its own login; `/api/ocupilot` accepts Bearers (any JWT app does) but never mints from the browser cookie. Trade-off: one extra login when the user comes from the classic portal, in exchange for not depending on Group by ID for anything OcuPilot owns; the embedded editors still log in silently because their API is in the vendor's group and OcuPilot's JWT login issued the cookie.
- Both designs give: one login, one token for every API the contest needs, embedded editors with no password hand-off, and a logout that ends everything.

### Deprecation and documentation caveats (spike §5; D4 [20][22])

- `irisdocs/guides/GSA_manage_applications.md` line 793–795, **Group by ID**: "Do not use. This field is for migrated legacy applications only and documentation is available for it."
- Lines 761–771, JWT: documents only "Use JWT Authentication", "JWT Access Token Timeout", "JWT Refresh Token Timeout" — **nothing about the login, refresh, logout or revoke endpoints, the request shapes, or the browser-id cookie.**
- Lines 861–867, Session Cookie Path: describes `CSPSESSIONID-*`, which is path-scoped and played no part; does not describe `CSPBrowserId`.
- `irissys/Security/Applications.cls` Documatic, `GroupById`: "Indicates whether this application's authentication will move in sync with other applications in the same id group. For CSP Web Application only." — the "For CSP Web Application only" qualifier is **contradicted** by `/api/admin` and `/api/interop-editors`, both REST applications, honouring it.
- **Net:** the documentation deprecates the mechanism the vendor's own portal, Angular editors and hidden admin API rely on, and documents neither the browser-id cookie nor the JWT endpoints. Open questions row 3 asks whether InterSystems will keep Group by ID and the browser-id cookie across releases; the exposure if not is one extra login for portal-first users.

### Not tested (spike §9)

- Cookie deletion inside Chrome (no tool; cookies are httpOnly) — isolation was done in curl instead (rows 17–28).
- Whether the classic logout revoked the frame's outstanding tokens or they merely hit the 60-second expiry (row 42).
- Group by ID on OcuPilot's own JWT application (no ObjectScript written); the inference rests on `/api/admin`, `/api/interop-editors` and the negative control `/csp/fhirsql/api/ui`.
- **HTTPS, a reverse proxy, or a cross-origin dev server.** `CSPBrowserId` is `SameSite=Strict`; **an `ng serve` on another port will not carry it. Local development must proxy through the IRIS origin** (inference from cookie attributes).
- The Web Gateway 404 after `Security.Applications.Create()` (handoff §4 step 4; [27] "Known gateway caveat") **did not occur**: both spike applications served `index.html` with 200 immediately.

---

## 6. Backend API surface

### Which service backs which portal area (D4 [2][11][18][20][21]; coverage table, inference from the map and D3)

| Contest area | Portal pages (section) | Served by | Gap |
| --- | --- | --- | --- |
| Manage web apps and explore REST APIs | Web Applications (Administration > Security > Applications); Web Sessions (Operation) | `/api/admin` web-apps and web-sessions; `/api/mgmnt` discovery and OpenAPI documents; Atelier cspapps list | `/api/mgmnt/v2` refuses to return the spec for InteropEditors and lists only spec-based services |
| Permission management | Users, Roles, Resources, Services and the SQL-privilege dialogs (Administration > Security) | `/api/admin` users, roles, resources, services, SQL privileges | none found |
| Security and secrets (wallet, x509, OAuth) | SSL/TLS, X.509 Credentials, OAuth 2.0, Encryption, LDAP, Managed File Transfer (Administration > Security and Encryption); **no wallet page exists** in the classic portal | `/api/admin` SSL, X.509, OAuth 2.0 server, client and resource server, wallet collections and secrets, encryption, LDAP | X.509 backing class not identified on this instance |
| Task management | Task Manager group: schedule, new task, on-demand, upcoming, history, import (Operation) | `/api/admin` tasks, run, suspend, resume, history, upcoming, task manager | none found |
| OS management (processes, disks, CPU, memory, devices) | Processes and details, System Usage, System Dashboard, Databases and details (Operation); Devices (Administration > Device Settings) | `/api/admin` processes with terminate, suspend, resume, broadcast; system-usage and shared-memory; dashboards; database directories and volumes; devices; `/api/monitor/metrics` | freeze and thaw absent |
| All the logs | System Logs group (Application Error Log, Messages Log, xDBC, System Monitor, SQL Diagnostics) and Background Tasks (Operation); View Audit Database (Security > Auditing); Event Log (Interoperability) | `/api/monitor/alerts` (since last scrape only); `/api/admin` audit records; Atelier compile console; per-host interop logs | **messages.log, application errors, production-wide event log: custom** |

Beyond the contest areas (D4 [20]): documented `%Api.*` services cover source code and SQL execution (Atelier v1 to v8), Prometheus metrics and alerts (`/api/monitor`), REST-service discovery (`/api/mgmnt`), analytics (`/api/deepsee`), DocDB, and — undocumented on the website but public in the class reference — the full Interop Editors v7 API (`/api/interop-editors/v7/`) for productions, hosts, settings, per-host queues, logs, jobs and messages, message search, resend and trace, rules, DTLs, BPLs, lookup tables and schemas. All six Angular twins call that one backend (D3d [15]). Production lifecycle in the classic page runs through `Ens.Director`, `Ens.Job`, `Ens.Queue` (D3d [13]).

### The hidden `/api/admin` service (D4 [21])

- `%Api.Admin` with dispatch classes v1 and v2; **84 Hidden classes** (82 in the package proper, 2 `%SYS.Api.Admin.Util` helpers); authorization via ResourcesOR.
- Covers namespaces, databases, journals, locks, processes, tasks, license, ECP, devices, web applications and sessions, wallet secrets, monitors and every security object.
- **Observed live:** sixteen probed GET routes returned 200 to Basic auth; an independent verifier confirmed the web-application settings, the class count, the envelope on five v2 routes, and that **the stock image on a second container serves the same API**. The spike additionally exercised `POST /api/admin/login`, `/refresh`, `/logout`, `/revoke` and `GET /api/admin/info`, `GET /api/admin/v2/namespaces` [46].
- **Inferred (UrlMap-only, not re-confirmed by the OpenAPI keyword scan):** web applications, external language servers, DocDB, SQL privileges, web-authentication settings — "treat those five as UrlMap-only until exercised."
- **Write payloads:** no write route (create/update/delete) was exercised in the research; routes come from the dispatch class's UrlMap read on the instance. Write shapes are therefore unobserved.
- **Risk and mitigation:** unsupported and unversioned in the documentation. Pin to `/v2`; check `apiVersion` from `GET /api/admin/info` at startup; keep the auto-generated OpenAPI document from `GET /api/mgmnt/v1/%25SYS/spec/api/admin` under test; keep a custom-endpoint fallback plan for any route that disappears (Rec 2; catalog SH-11 "instance-identity and API-version guard on load"; PK "admin-API version guard").
- The dispatcher rewrites Location headers to an `/iris/api/admin/` prefix, suggesting InterSystems is building its own new portal front end on this API (insight 3).
- `/api/admin` is neither in the `%SYS` export nor in the documentation index; treat it as undocumented/internal (reference-folders rule; D4).

### Other services, observed facts

- **Atelier query action** (`POST /api/atelier/v1/{ns}/action/query`) executes whatever SQL it receives under the caller's privileges and filters only its output (to SELECT and CALL results, types 1/45), with no row limit — **so a DML and DDL guard for agent use must live in OcuPilot** (D4 [20]; staleness [20] verified). It accepts neither the JWT nor a cookie-only call from a page (row 35) — explicit Basic header or a route through OcuPilot's own REST [46].
- **Atelier jobs endpoint returned an empty list**, whereas `/api/admin/v2/processes` returned the full table — the hidden API is the better process source (D4 [20]).
- **`/api/mgmnt/v2`** refuses to return the spec for InteropEditors and lists only spec-based services; the project rule file claiming otherwise must be corrected (Rec 10).
- **`/api/security-config`** (HealthShare security REST service) accepted the Bearer (`/api/security-config/credential/v1/credentials` → 200, row 5); whether it is an official surface for credentials and OAuth on IRIS for Health is Open questions row 13.
- **`/csp/fhir-management/api/`** with Bearer → 404 (authenticated, route absent) (row 16).

### Where custom REST is unavoidable (D4 [20][21]; no route in any `%Api.*` class or in `/api/admin` v1/v2; backing ObjectScript exists unless noted)

memory, startup, SQL and NLS configuration settings (`Config.config`, `Config.Startup`, `Config.SQL`, `Config.NLS.Locales`); backup and restore (`Backup.General`, `Backup.Task`; restore class not identified); mirror configuration and status (`SYS.Mirror`, `%SYSTEM.Mirror`); globals (`%SYS.GlobalQuery`, `%Library.GlobalEdit`); **messages.log and application errors (no backing class found; a file-reading endpoint is needed)**; journal purge; database freeze and thaw; interoperability credentials, default settings, managed alerts and purge (`Ens.Config.Credentials`, `Ens.Config.DefaultSettings`, `Ens.Alerting.ManagedAlert`, `Ens.Purge`); a production-wide event log (v7 exposes logs per host only); SQL plans, statement index, statistics and tune (`%SQL.Manager.Catalog`, `%SYSTEM.SQL`, `%SYS.PTools.SQLStats`).

### The three custom endpoints for P0 and why each is needed (Rec 2; insight 2; D6a)

1. **messages.log viewer** — no REST route and no backing class exist; a file-reading endpoint is required (D4 [20]; catalog LG rows).
2. **Application error log viewer** — same: no route, no backing class (D4 [20]).
3. **The agent runtime** — the harvested session-agent core has no REST surface; by inference roughly six endpoints: run turn, load transcript, lock state, agent-config CRUD, credentials list, tool list (D6a [10]).

The MCP suite's ObjectScript handlers implement, handler for handler, the functions in D4's custom-REST list; their bodies are the shortest path to OcuPilot's custom endpoints (insight 4; D6b [27]). Build them into OcuPilot's own `%CSP.REST` dispatcher on the IRISCouch patterns, not the suite's `%Atelier.REST` envelope.

### Legacy CSP pages with no exported source (D3a [18]; D3b [11][12]; D3c [16]; insight 7; Rec 8; Open questions row 6)

- **System Administration (11 leaves → 7 legacy CSP pages):** SQL Gateway, all five Database Backup entries, Web Gateway Management, Task Manager Email, Enable and Disable Auditing, Security Advisor.
- **System Operation (17 legacy CSP leaves, ~27 legacy screens):** all Backup pages, all Journal pages, the System Dashboard, Shadow Servers, **the New Task wizard (frameset, about 60 fields)**, **the Application Error Log (three levels)**, **Messages Log**, System Usage, Diagnostic Reports. Several render empty on GET and are probably POST-driven.
- **System Explorer:** Globals view and edit, find and replace, SQL open table, SQL import/export/link wizards (legacy `%CSP.Util.AutoPage`), Documatic (plain CSP).
- Their `.csp` source is not in the export, so those rows rest on pane classes and live renders. Task creation and two of the log viewers are contest-area screens. Copy `csp/sys/mgr`, `csp/sys/sec` and `csp/sys/op` out of the container and read them.
- Also absent: 12 Hidden portal classes (Shadows, FileMan, Zen Report twins) and nine Hidden EnsPortal classes; five referenced classes do not exist on the instance at all (a move-globals wizard, three sharding dialogs, an async-mirror-authorization dialog) — dead references, not parity targets (D3a [19]; D3d [14]).

### Portal mechanics a replacement must reproduce (D3a–D3d)

- **Resource gates:** Configuration and Licensing need `%Admin_Manage:USE` plus READ and WRITE on `%DB_IRISSYS`; Security needs `%DB_IRISSYS:READ`; Encryption needs `%Admin_Secure:USE`; Journal Settings needs `%Admin_Journal`; Compatibility, Web Gateway Management and Security Advisor additionally need `%Admin_Secure`; OAuth 2.0 pages use `%Admin_OAuth2_*`. System Operation is invisible without `%Admin_Operate:USE`; Task Manager items and Diagnostic Reports need `%Admin_Task:USE`. Explorer needs `%Development`; Interoperability `%Ens_Portal` (30-plus `%Ens_*` resources with separate view and edit); Analytics `%DeepSee_Portal` / `%DeepSee_PortalEdit`. `%CheckResources` infers resources from URL path prefix (`/op` → `%Admin_Operate`, `/exp` → `%Development`, `/mgr` → `%Admin_Manage`, `/sec` → `%Admin_Secure`) plus a per-page custom resource overlay assignable by `%Admin_Secure` holders; **custom resources are keyed by normalized page URL, so a portal with different routes must map its routes back to those keys or lose existing assignments** (D3c [16]).
- **Edition and feature gating is runtime**: Sharding disabled unless licensed (not on Community); Mirror leaves depend on mirror-service state; Client Applications only on Windows; SQL Gateway and External Language Servers hidden on VMS; Mirror Monitor branches on `$System.Mirror.IsMember()`; Transactions degrades when the System Monitor is not running (D3a, D3b).
- **Long-running work** goes through `%CSP.UI.System.BackgroundTask.RunTask` (44-entry whitelist, JOBs a worker, progress in `^IRIS.Temp.MgtPortalTask` read by the Background Tasks page); Compact, Defragment, Integrity Check and mirror database actions use it; truncate, mount, dismount, lock removal, process control, session end and deletes are synchronous (D3b [11]).
- **Auto-refresh** is a shared framework feature (timer plus persisted rate, state and sort column) used by Databases, Database Details, Processes, Process Details, Transactions, Mirror Monitor, Task Details, License Usage, Web Sessions and Background Tasks (D3b).
- **Namespace switching** rewrites the target URL into the namespace's own CSP application; list from `List^%SYS.NAMESPACE` filtered to namespaces the user can read and write; visits to `%SYS` without a namespace parameter redirect to the user's startup namespace (D3c [16]).
- **Portal-wide directory allow-list** restricts server file paths used by browse dialogs, relevant to every export and import feature (D3c).
- **Detail pages are hybrids**: Database, Process and Task details host a legacy HTML dashboard pane of value meters built in code (D3b).

---

## 7. Open questions (research.md table, verbatim rows)

| Question | What it would take |
| --- | --- |
| What technology bonuses apply to this contest, and are AI or Angular among them? | Re-run D1 after the 2026-09-14 kick-off; the contest page promises an announcement [1] |
| Is an entry covering only some of the six areas accepted? | Ask in the announcement comments or the contest Discord channel; approval is discretionary [2] |
| Will InterSystems keep Group by ID and the browser-id cookie across releases? | Ask at the kick-off; the JWT-only path needs neither, so the exposure is one extra login for portal-first users [46] |
| Will `/api/admin` survive releases unchanged, and what is InterSystems' support stance? | Ask at the kick-off webinar; keep the generated spec under test; pin v2 and check `apiVersion` [21] |
| Build-time or start-time install with a durable `%SYS` volume? | Test the vendor template pattern against this repository's compose file with the data directory bind-mounted [29] |
| What exactly do the eleven legacy CSP pages do (fields, POST actions)? | Copy `csp/sys/mgr`, `csp/sys/sec` and `csp/sys/op` out of the container and read them [11][18] |
| Which classes back X.509 credentials, messages.log, application errors, journal purge and restore? | Class-dictionary probes on the instance; the exported names do not exist there [20] |
| What `{action}` values does the interop-editors production-update endpoint accept? | Read the v7 or v6 implementation class on the instance [20] |
| Are the two MCP-suite defects from 2026-04-20 fixed? | Read the current task and security handler bodies [27] |
| What does the Mirror Monitor's absent async-authorization dialog do? | Fetch the hidden class from the instance before scoping mirror features [11] |
| Does Configure User Events really offer export and import, as its menu text says? | Open the live page; the exported code does not show them [18] |
| Are the off-menu Provider pages (Kits, Installs, Instances, Machines, Manifests) reachable from any application? | Search the instance's web-application definitions [18] |
| Is the HealthShare security REST service (`/api/security-config`) an official surface for credentials and OAuth on IRIS for Health? | Read its dispatch class and the FHIR management documentation [20] |
| Can JWT be enabled on `/api/atelier` by configuration so one token covers it too? | Untested because it changes a vendor application; try it on the dev container [46] |
| Five shell details were not read: product-name macros per edition, the per-page namespace-link rule, the client-side auto-logout timer, class delete semantics, and live confirmation of the Explorer and Analytics menus | Read the Zen base classes and open the live portal once [16] |
| Is the Freshmen nomination open to this entrant? | Count prior contests entered; the $100 tier in Full Stack 2026 is not a top-three finish [36] |
| When are winners announced? | Not stated anywhere read; historically after voting closes [2] |

Additional open leads recorded in the digests: the agent-patterns digest's contradiction on Gemini investigation availability; whether Azure has added an agent marker to Activity Log since July 2026; whether AI Hub includes a Management Portal co-pilot; the contest-field digest's unread Tani Frankel 2026.1 highlight posts and the 2026.2 release notes; whether the `intersystemsdc` images still ship IPM preinstalled (D7 [28]).

---

## 8. NFR-shaped material

### Performance and responsiveness

- The harvested agent loop is **fully synchronous and non-streaming**: one blocking call per turn, a **90-second provider timeout**, and a README instruction to **raise the Web Gateway timeout to 300 seconds**; nothing exists for progress or streaming (D6a [10]). The Web Gateway timeout is a listed P0 deliverable ("the Web Gateway timeout prerequisite", PK rows).
- **P0 needs at least progress delivery for multi-step turns; server-sent events can follow** (insight 6; CP "progress indication" P0; "co-pilot streaming" P2).
- Context-window trimming is missing (history is replayed in full each turn) (D6a [10]).
- Provider adapters retry four times with exponential backoff on 429 and 5xx (D6a [10]).
- Vendor bundles refresh JWTs at `exp − iat` minus a cushion; recommended `exp − iat − 10 s`; access token 60 s, refresh 900 s; optionally raise OcuPilot's own access timeout to 300 s to cut refresh traffic (spike §4, §7).
- Auto-refresh framework with persisted rate, state and sort column (D3b); the home System Information panel refreshes every 10 seconds only when auto-refresh is enabled and hides below 1,100 px (D3c [16]); menu search typeahead at 220 ms (D3c).
- MCP suite precedent: a 32,768-character response ceiling with truncation markers (D6b [27]).
- Table-editor precedent limitations: `%VID` offset paging re-reads preceding rows on each page; count failures show zero rows (D6c [9]).
- Vendor: "Improved UI performance for larger productions, such as those with more than 2,000 hosts" (contest-field digest, 2026.1 notes) — a scale reference for interop screens.
- Gemini investigations take "about 3–5 minutes" (agent-patterns digest) — the field's precedent for a long multi-step run needing progress UI.

### Security

- **Run strictly as the user with no new privileges** (D8 [39][42]; Rec 4; CP "execution as the user"). Azure: "An agent cannot perform any action that the user themselves could not perform directly."
- **Read-only as the default tier; explicit approval per write** (propose, review, confirm with rationale, expected impact and where possible a rollback path) (D8; Rec 4; CP rows).
- **Tiered autonomy** (practitioner framework [43]): L0 observe; L1 simulate and recommend; L2 bounded actions with machine-checkable preconditions, resource limits and abort criteria (e.g. terminating a known runaway query); L3 human authorization for schema changes, backfills, failovers, access or retention changes; L4 prohibited actions (deleting backups, dropping production databases) kept **outside the agent's credentials entirely**.
- **Administrator kill switch and per-agent enablement** (D8; CP "administrator kill switch" P0; "read-only mode" P0).
- **Governance model to copy** (D6b [27]): `tool` or `tool:action` keys with a frozen baseline where new write-classified keys are disabled by default; configuration cascade environment → file → preset → default; a read-only preset; a call-time gate returning a structured `GOVERNANCE_DISABLED` result while tools stay advertised; server-side confirmation gates in ObjectScript (`dryRun:false` and `confirm:true` for filtered resend; explicit flags for production clean with data wipe, audit purge, overwriting a `%`-global mapping); "recover before clean".
- **DML and DDL guard** for any SQL path through the Atelier query action must live in OcuPilot (D4 [20]; P2 "free-form SQL console with its DML and DDL guard").
- **Prompt injection:** the session agent has no safeguards (D6a); **no source in the field documented a defense for tool or log content** (D8 [43]; agent-patterns digest Gaps). **Sanitization of log content before it reaches the model** is a named requirement (Rec 4; P1 "log-content sanitization").
- **Secrets:** API keys are never persisted; resolution is environment variable → `Ens.Config.Credentials` password → an unimplemented AES-store stub; shape checks `sk-`, `sk-ant-`, `AIzaSy`; all adapters hard-code SSL configuration `DefaultSSL`, set no proxy — proxy and custom-CA support must be added (D6a [10]). IRIS Wallet is the vendor's credential store for AI Hub (D8 [44]) and a contest-named area.
- **Never send the password into an iframe**: the `VSCODE=1` `auth` message puts the password on the wire from the frame (row 33); normal mode needs no hand-off; the sessionStorage pre-write is the untested password-free alternative (spike §7).
- **Token hygiene:** sessionStorage per tab, never localStorage; Bearer only, cookies never authorize; logout with cookie ends the browser-level login (spike §7).
- **Gaps to avoid inheriting from IRISCouch:** no CSRF, SameSite or Secure flag on its session cookie, no CORS handling (D6d [26]). IRISCouch's good patterns: `Security.Users.CheckPassword` in `%SYS` rather than `$System.Security.Login`; stateless HMAC-SHA256 cookies with constant-time comparison; path-traversal checks in the static server (D6d).
- **Never concatenate caller-supplied values into SQL**; validate shape then bind (D6b; project rules).
- The embedded editors' postMessage contract has **no origin check** (D5 [24]).
- A dedicated user/role tool-allowlisting precedent exists (`iris-mcp-data-exposure-toolkit`, D8 [44]).

### Privacy and data egress

- **Explicit data-egress disclosure and opt-outs** are a field norm: Gemini (conversations may be stored in any Google data center; do not enter residency-regulated data), Elastic (data "not anonymized… processed by third-party AI providers"; optional anonymization pipeline), AWS (Organizations opt-out policy), Grafana ("vetted service providers") (D8 [40][41][42]; P1 "egress disclosure").
- **A local OpenAI-compatible endpoint** (default `localhost:11434/v1`, Ollama-style; models qwen2.5:32b, llama3.3:70b) is already in the harvested provider set and keeps data on the instance — the selling point for regulated IRIS shops (D6a [10]; D8; Rec 9).
- Chat history retention policy (Gemini 180 days) is a pattern; P1 "history retention".
- Prompt caching on the system block and last tool is on for Anthropic (D6a).

### Audit and attribution

- **Distinct audit marking of agent-initiated changes** is a P0 co-pilot requirement and an open differentiator (Rec 4; insight 5; CP rows) — Azure logs under the user's identity with no agent marker [39].
- Per-call audit rows exist in the session agent (D6a [10]); the MCP suite has a secrets-redacted JSONL audit log that governance cannot disable (D6b [27]); IRISCouch has a single `Audit.Emit` choke point wrapping `$System.Security.Audit` in Try/Catch, structured JSON console logging, and an installer that registers 17 audit event types guarded by existence checks (D6d [26]).
- `$System.Security.Audit` silently drops events whose Source/Type/Name were never registered with `Security.Events.Create()` in `%SYS` — register in an install/upgrade routine (project rules; D6d pattern).
- Citations back to the rows and API calls used (session-agent precedent; P1 "citations"); token usage per user (IBM Db2 precedent; P1 "token metering"); an agent audit viewer (P1).
- Cost: usage tokens are captured but pricing is README-only in the session agent (D6a).

### Privilege model and access gating

- Execution as the logged-in user; route and menu gating driven by the admin API's privilege map (SH rows); an instance-identity and API-version guard on load (SH-11).
- Portal resource gates and the custom-resource overlay keyed by normalized page URL — see section 6 "Portal mechanics" (D3a–D3c).
- Web application auth requirements: `/api/atelier` `%Development`; `/api/interop-editors` `%EnsRole_InteropEditorsAPI`; `/api/monitor` unauthenticated with `%DB_IRISSYS` role (D4 [22]). Session-agent view gate is only `%Ens_Portal:USE` (D6a).

### Install and packaging constraints (D7 [28]–[33]; Rec 5; insight 9; D6)

- **One IPM module** declaring `<WebApplication>` plus `<FileCopy>` for the built Angular bundle, a second `<WebApplication>` with a `DispatchClass` for REST, `<SourcesRoot>src</SourcesRoot>` with package resources, and an `<Invoke>` for anything IPM cannot express. **Avoid `<CSPApplication>`** (deprecated since IPM 0.9.0 though both InterSystems templates still use it) and `${dbrole}` (use `${globalsDbRole}`).
- **IPM state:** 0.10.x line; 0.10.8 latest stable; 0.10.10 in beta as of 2026-08-26; 0.10.x supports IRIS 2022.1+ (single source). **Since 0.9.0 IPM is no longer mapped across namespaces, so `zpm` may not exist in HSCUSTOM on a Community image** — install it there or run `zpm "enable -map -globally"`. Whether `intersystemsdc` images still ship IPM preinstalled is unverified; install explicitly.
- **Docker self-install:** both InterSystems templates install during `docker build`, not at container start — a `RUN` with a bind mount starts IRIS, pipes `iris.script` in (unexpire passwords in `%SYS`, create the namespace through a `%Installer` class, switch, `zpm "load <dir> -v":1:1`), stops IRIS; the 2026 dev template adds `iris merge` of a CPF file. **Namespace choice ("HSCUSTOM if present, else USER") belongs in `iris.script` or an installer method, not in module.xml**, because the manifest is evaluated after the namespace is fixed.
- **This repository already uses durable `%SYS`** (`./iris-data` bind-mounted to `/durable`, `ISC_DATA_DIRECTORY=/durable/iris`) and the idea document wants install on container start; no source showed the build-time pattern working against a durable-`%SYS` volume, and no start-time hook (`%ZSTART`, `-a` after-install argument, `ISC_CPF_MERGE_FILE`) was retrieved. **The architecture must settle build-time versus start-time install before the Dockerfile is written** (Open questions row 5). Reconciliation proposed: IPM module as single source of truth, loaded at build time, re-checked by an idempotent installer at start (insight 9).
- **Serving the SPA:** static bundle in a CSP directory with `ServeFiles`, separate password-authenticated REST application; deep links for client-side routes need a `%CSP.REST` catch-all GET that rewrites non-asset paths to `index.html` via `%CSP.StreamServer.Page()` on a web application with both a physical path and a dispatch class; base href set at build time to the mount path; "Serve Files Always" in development to defeat gateway caching; IRISCouch's handler adds path-traversal checks, immutable cache headers for hashed assets, no-cache for `index.html` (D7 [29][30][31]; D6d [26]). The built bundle is committed or produced in a first build stage so the same files are in the IPM archive.
- **Pitfalls:** gateway serving stale static files; deep links returning 404 on a serve-files-only application; the portal hiding the physical-path field once a dispatch class is set; the expired `_SYSTEM` password on Community images (surfaces as HTTP 401); the old `%ZPM.PackageManager` class name in template Dockerfiles; the Web Gateway may return 404 for a newly created web application until it is saved once in the portal or the gateway restarts (`Security.Applications.Create()` may not notify the gateway — did not occur in the spike).
- **Sibling anti-patterns:** the MCP suite's TypeScript-driven runtime bootstrap over Atelier and its stale IPM manifest (omits the REST base class and 15 other classes; would most likely not compile) (D6b [27]); IRISCouch's documented "ZPM creates the web app" behavior is not implemented — the working install is the Installer class; it has no Docker artifacts (D6d [26]).
- **Installer patterns to reuse:** idempotent (create web application only if absent), admin role, audit events guarded by existence checks, namespace restored in the Catch block (D6d); session-agent installer creates `%SYS` audit event types, a read-only role with SELECT grants, scheduled tasks, seed rows — but no web application, no resource, no global mapping, **no uninstall hook**, no declared dependencies (D6a). An uninstall hook is P1.
- **Name-collision avoidance** (D6 table; PK "name-collision avoidance" P0): packages `SessionAgent.*`, `ExecuteMCPv2.*`, `IRISCouch.*`; web paths `/csp/<ns>/sa-static/`, `/api/executemcp/v2`, `/iris-couch/`; roles `SessionAgent_ReadOnly`, `IRISCouch_Admin`; audit sources `SessionAgent`, `IRISCouch`; globals `^SessionAgent.*`, `^IRISCouch.*`, `^UnitTestRoot`; credentials `SessionAgentOpenAI/Anthropic/Gemini`; tasks `SessionAgent.Purge*`, `SessionAgent.UserVocabularyDecay`; `%ALL` mapping, `ExecuteMCPv2.Setup_*` SqlProcs, `iris_*` tool prefix, `IRIS_*` env vars.
- **Multi-namespace:** session-agent install is an operator-run package mapping validated by `InstallIntoNamespace`, which rejects `%SYS` and requires an interop-enabled namespace (D6a).
- **Third-party Python packages** are an operator-run prerequisite, never an install-hook action (project rules).

### Supported IRIS editions and versions

- Must run on **IRIS Community Edition or IRIS for Health Community Edition** (D1 [2]); the OE page also lists IRIS Cloud SQL (contradiction; announcement governs).
- Research instance: IRIS for Health Community 2026.2, build 221U (`intersystems/irishealth-community:latest-cd`); `/api/admin` present in the stock image on a second container [21].
- Session agent requires IRIS 2024.1+ per its README (D6a [10]); IPM 0.10.x supports IRIS 2022.1+ (D7 [28]).
- Edition gating at runtime: Sharding disabled on Community; Mirror leaves depend on service state; Windows-only and VMS-hidden items (D3a); HealthShare injects a "Health" top-level entry outside the exported application class (D3a [19]).

### Test and quality

- IRISCouch's 78 `%UnitTest` classes with an HTTP harness and a no-double-envelope assertion are reusable as-is after renaming (D6d [26]); P1 rows include unit-test harness, CI, registry publishing.
- Keep the generated OpenAPI document for `/api/admin` under test (Rec 2).
- Judging criteria include Clarity of Instructions and Developer Experience (D1 [1]).

---

## 9. Qualitative material

- **Positioning line (Rec 9):** "the agentic management portal built on IRIS's own management APIs". The task wording "powered by InterSystems IRIS management APIs" is satisfied verbatim by building on `/api/admin` (insight 3).
- **The co-pilot is "always-on"** — "the always-visible panel docked like VS Code's secondary side bar (present on every route, resizable, full-screen toggle, never dismissed)" (Prioritized feature list, CP-01 to CP-22). The rules invite it under "any other screens or actions you frequently use" (D1).
- **How it should feel, from the field's praise and complaints (D8 [43]; agent-patterns digest):** users praise page context, follow-up memory and precise investigations ("identified the specific line… throwing the… 400 error"); the loudest complaint is irrelevance and unreliability — "unreliable and irrelevant information that required too many steps", "none provide any real assistance", hallucinations and ignored instructions. The practitioner caution: approve "the specific proposed change, its expected impact, and the rollback plan rather than simply instructing the agent to 'fix the database'"; "the genuinely beneficial functionalities currently available are more limited than the marketing might imply".
- **Interaction vocabulary to adopt (D8 recurring patterns 1–12):** persistent side panel with full-screen toggle; page-context sharing on by default and toggleable; draft-first copy-out artifacts; propose → review → confirm with rationale and expected impact; "Investigate" entry points on alerts and log entries; pre-populated hand-off forms; an agent picker inside the chat; citations back to the rows used; suggested prompts grouped by task; inline contextual insights beside errors; record-and-generate of console actions into scripts; chat history with a retention policy. **Not evidenced anywhere in the field:** undo/rollback UI, visual diffs before apply, slash commands, streaming — all open ground.
- **"Explain this screen" and "explain this log entry" as first-class actions** (D8 requirements paragraph; P1).
- **Screen synchronisation after agent writes and agent-driven navigation** (added at the owner's direction on 2026-09-08, CP-42, CP-43): the affected list or form re-fetches in place and highlights the change, with a linked toast for screens not open; the agent navigates the user to the relevant screen.
- **Harvestable UI details from the session agent** (D6a): the eleven validation rules and provider-change cascade of canonical defaults; the config-empty state; the lock banner (per-conversation locking); citation chips; the vendored Markdown pipeline; the 8,192-character system-prompt counter.
- **Portal-shell conventions users expect** (D3c [16]): header strip (server, namespace with switch link, user with change-password link, escalation role with escalate/remove links, licensed-to, instance, and a Live / Test / Failover / Development badge); small menu Home, About, Help, Contact, Logout; a fixed 16-link "Menu" drop-down filtered by access; breadcrumb locator; per-page ribbon commands; favorites and recent items per user; a "Did you know" tip; search over menu metadata only; About with 14 system-overview fields and a 17-language selector; Help opens DocBook per page.
- **Theming:** vendor bundles have fixed theming (Tailwind and Material tokens, Noto Sans, InterSystems logo in the top bar unless hidden) and no license text — reference in place, never copy (D5 [24]); iris-table-editor has a clean `--ite-*` token layer that a theme-bridge file can adapt (D6c [9]); the community has asked repeatedly for dark mode (contest-field digest); "theme" is a P1 row.
- **Ship-quality rule:** "link any unfinished large editor to the classic portal page rather than ship it half-done" (P0 cut line).
- **Demo and submission feel:** README in English with installation steps and a video demo or description, plus a link to the idea; an online demo, a Developer Community article, a YouTube video and a short are precedent bonus items; list early and "improve visibly through the voting week" (Rec 6; insight 10). Judging weighs Complexity, Clarity of Instructions, Developer Experience, Applicability, Usability (D1 [1]).
- **Naming rules (project rules; D6):** no `%` or `_` in class or property names; parameters `p`-prefixed, locals `t`-prefixed; class parameters camel case or all caps; avoid the sibling names listed in section 8; profile name `ocupilot-iris` must never equal the folder name (CLAUDE.md, referenced by the research setup).
- **Data-source honesty:** the vendor's shipped console assistants disclose where data goes; OcuPilot's local-model option is framed as the privacy-preserving default for regulated shops (D8; Rec 9).

---

## 10. Target users and journeys

- **Primary user:** an IRIS administrator or operator who today uses the classic System Management Portal for the six contest areas (web apps and REST, permissions, security and secrets, tasks, OS management, logs) and "other screens or actions you frequently use" (D1 [2]). SQL and Classes are "the most-used developer surfaces" for the invitation (D3c).
- **Regulated IRIS shops** are the audience for the local-model / no-egress option (D8; Rec 9).
- **Two arrival journeys (spike §7; Rec 3):** *portal-first* — the user already logged into the classic portal in this browser; OcuPilot's empty-body login succeeds silently and no form is shown; *OcuPilot-first* — a clean browser; OcuPilot's login form appears once; thereafter the classic portal and the embedded editors are logged in too because the JWT login issued `CSPBrowserId`. Logout from OcuPilot ends the classic portal and the editors' logins as well (row 23).
- **Session shape:** one token pair per tab in sessionStorage; access token 60 s with scheduled refresh; refresh 900 s; on refresh failure return to the login form; conversation history keyed on route/screen context with per-conversation locking (D6a adapt list); history retention policy (P1).
- **Namespace journey:** a namespace switch dialog; lists only namespaces the user can read and write; `%SYS` visits without a parameter redirect to the startup namespace (D3c).
- **First-login gate:** the agent-configuration screen (agent selector, provider selector, editable model combobox with per-provider suggestions, endpoint URL for openai-compatible, credential type env-var or `Ens.Config.Credentials` with picker, max tokens, temperature, max iterations, system-prompt override, enabled flag) becomes the first-login gate; a test-connection action is new (D6a [10]; Rec 4).
- **Co-pilot turn journey:** ask in the docked panel with screen context injected (toggleable); read tools answer with citations; a write is proposed with rationale and expected impact, reviewed, confirmed, executed as the user, audited with an agent marker, and the affected screen re-fetches and highlights (CP rows; CP-42/43); progress is shown for multi-step turns (insight 6).
- **Administrator journey:** kill switch, read-only mode, per-agent enablement, governance keys, token metering, agent audit viewer (Rec 4; P1).
- **Contest journeys (D1, D2, Rec 6, insight 10):** *Experts judges* apply discretionary approval "based on the criteria of complexity and usefulness" and the OE criteria; *Community voters* are trusted DC members with one changeable vote, blind counts and a daily leaderboard, who favored a recurring cohort in 2026; *Freshmen* nomination possibly open to this entrant. The demo scenario is a submittable build listed on 2026-09-14, visible improvements through 2026-10-04, a README with install steps and video or description, an online demo, a DC article, a YouTube video and short.
- **Kick-off webinar (2026-09-14 12:00 EDT)** is where the bonuses, the partial-coverage question, Group by ID longevity and `/api/admin` support stance should be asked (Open questions rows 1–4).

---

## 11. Risks

| Risk | Source | Mitigation stated in the research |
| --- | --- | --- |
| Group by ID is documented "Do not use… migrated legacy applications only" while the vendor's own portal, editors and admin API rely on it; it may not survive releases | spike §5; D4 [20][22]; Open questions row 3 | Design B / JWT-only fallback needs no group; exposure is one extra login for portal-first users (Rec 3; insight 1) |
| `/api/admin` is hidden, undocumented, unsupported, unversioned; routes may change or vanish | D4 [21]; Rec 2; Open questions row 4 | Pin v2; check `apiVersion` from `GET /api/admin/info` at startup; keep the generated OpenAPI doc (`GET /api/mgmnt/v1/%25SYS/spec/api/admin`) under test; custom-endpoint fallback plan; ask at kick-off |
| Five `/api/admin` sub-areas (web applications, external language servers, DocDB, SQL privileges, web-authentication settings) are UrlMap-only, not confirmed by the OpenAPI scan; no write payloads observed | D4 [21] | Treat as unverified until exercised |
| Agent turns are slow and non-streaming (90 s provider timeout, 300 s gateway); users punish "too many steps" | D6a [10]; D8 [43]; insight 6 | Progress delivery in P0; SSE/streaming P2; raise Web Gateway timeout as a documented prerequisite |
| Legacy CSP pages (task wizard ~60 fields, Application Error Log, Messages Log, Backup, Security Advisor, etc.) have no exported source; two log viewers and task creation are contest-area screens | D3a [18]; D3b [11]; insight 7 | Rec 8: copy `csp/sys/mgr`, `csp/sys/sec`, `csp/sys/op` out of the container before writing P0 forms |
| Install patterns contradict (build-time templates vs runtime bootstrap vs installer class vs start-time wish) and this repo uses durable `%SYS`; build-time + durable-volume interaction unverified | D7 [29]; insight 9; Open questions row 5 | One IPM module as single source of truth loaded at build time, idempotent installer re-check at start; test against the compose file |
| Partial coverage of the six areas may not be accepted; approval is discretionary and final | D1 [2]; Open questions row 2 | Scope P0 to all six areas (Rec 1); ask in comments or Discord |
| Technology bonuses unknown; precedent has no AI/Angular bonus | D1 [5]; Open questions row 1 | Re-check after kick-off; prepare precedent items (Docker, IPM, online demo, article, video, short, idea) (Rec 6) |
| Freshmen eligibility unknown | D2 [36] | Count prior contests entered |
| `/api/atelier` rejects the JWT; cookie-only page calls trigger the browser's native Basic prompt and hang the fetch | spike row 35; D4 | Explicit `Authorization: Basic` or route Atelier-backed features through `/api/ocupilot`; untested lead: enable JWT on `/api/atelier` by configuration |
| Atelier query executes any SQL under the caller's privileges | D4 [20] | DML/DDL guard in OcuPilot for agent and console use |
| `VSCODE=1` auth message sends the user's password into the iframe and onto the wire; postMessage has no origin check | spike row 33; D5 [24] | Use normal mode (silent login) or the untested sessionStorage pre-write; avoid the auth message |
| Normal-mode editor chrome escapes the frame (logo → classic portal home; cross-app links → new tabs) | D5 [24] | Accept, or use `VSCODE=1` which hides the top bar |
| Vendor Angular bundles have no license text and must be loaded at exactly `/ui/interop/...` | D5 [24] | Reference in place; never copy |
| Contest Terms include an IP grant to InterSystems | D1 [3][7] | Read before choosing a license |
| Cross-origin dev server (`ng serve`) will not carry the `SameSite=Strict` `CSPBrowserId` cookie | spike §9 | Proxy local development through the IRIS origin |
| Web Gateway may 404 a newly created web application until saved once or gateway restart | handoff §2; D6b [27] | Did not occur in the spike; keep the workaround documented |
| Name collisions with sibling packages, paths, roles, globals, tasks, credentials | D6 table | Project-specific names; PK "name-collision avoidance" P0 |
| MCP suite's IPM manifest is stale and would not compile; its bootstrap is TypeScript-driven over Atelier | D6b [27] | Harvest handler bodies only; do not inherit its envelope or bootstrap (insight 4) |
| Two MCP-suite defects (task-history filter ignored; resource creation with description failing) have unverified fix status | D6b [27]; Open questions row 9 | Read current handler bodies before harvesting |
| Backing classes not identified: X.509 credentials, messages.log, application errors, journal purge, restore | D4; Open questions row 7 | Class-dictionary probes on the instance |
| Prompt injection via tool and log content; no field precedent for a defense; session agent has none | D6a; D8 [43] | Sanitize log content before it reaches the model (Rec 4; P1) |
| Secret handling: AES store is a stub; hard-coded `DefaultSSL`; no proxy | D6a [10] | Keep env-var and `Ens.Config.Credentials` rungs; add proxy and custom-CA support |
| IRISCouch gaps: no CSRF, SameSite or Secure flag on its cookie, no CORS, mount path baked into four places | D6d [26] | Do not inherit; OcuPilot uses Bearer not cookies for data calls |
| Table-editor limitations: single-column PK only, identifier regex rejects delimited names, `rowsAffected` always 1, `%VID` paging cost | D6c [9] | Carry into any port knowingly |
| Custom portal resources are keyed by normalized page URL; different routes lose existing assignments | D3c [16] | Map OcuPilot routes back to classic keys |
| `/api/mgmnt/v2` cannot serve the InteropEditors spec; a project rule file says otherwise | D4; Rec 10 | Correct the rule file |
| MCP tool count disputed (104 vs 108) | D6b [27] | Direction of the dependency claim unaffected |
| 22 of 119 P0 rows are rated large; 19-day window | Prioritized feature list | Cut line inside P0; link unfinished large editors to the classic page |
| Wallet at P0 on an undocumented route; locks at P0 against tier rules | Judgment calls | Revisit in the PRD |
| Row 42 ambiguity: classic logout may or may not revoke frame tokens (vs 60 s expiry) | spike §9 | Not separated; treat logout-with-cookie as authoritative |
| Reference exports drift from the running instance; hidden classes are absent from exports | reference-folders rule; D3a [19]; D3d [14] | The running instance is authoritative; fetch hidden classes live |
| Community voting favored a recurring cohort and diverged from the Experts winner in 2026 | D2 [36] | Go-to-market in the voting week (Rec 6) |
| Five dead references in portal code (move-globals wizard, three sharding dialogs, async-mirror-authorization dialog) | D3a [19] | Not parity targets |
| Red-team pass was off; no adversarial search for disconfirming evidence | Contrary evidence | Known limitation of the research |

---

## 12. Harvest sources

### iris-session-agent (D6a [10]; v1.0.4; package `SessionAgent`; pure ObjectScript; IRIS 2024.1+)

**Supplies (reuse as-is):** provider base and four working LLM adapters — `openai` (default gpt-4.1-mini; Bearer key with `sk-` check; chat-completions endpoint, overridable), `anthropic` (default claude-haiku-4-5-20251001; x-api-key with `sk-ant-` check; Messages API is the canonical wire shape; prompt caching on system block and last tool), `gemini` (default gemini-2.5-flash; x-goog-api-key with `AIzaSy` check; generateContent with functionDeclarations), `openai-compatible` (default qwen2.5:32b; endpoint URL required, default localhost:11434/v1; Bearer only if a key resolves); message and tool-definition adapters; EnvSecret; RetryWithBackoff (four retries, exponential, on 429/5xx); Json; tool base classes and reflection registry with an MCP-shaped contract (JSON-Schema subset in, MCP content envelope out, discovery by scanning direct subclasses); **28 read-only tools** (inspection: session_summary, session_timeline, message_headers, event_log, rule_log, explain_error, get_message_detail, get_message_body, get_business_process_instance, get_business_process_source, list_business_process_methods, find_related_sessions, find_sessions_by_body, get_rule_source, get_class_source, get_queue_state, get_production_config_item; search: search_by_session, search_by_status, search_by_time, search_by_source, search_by_target, search_by_message_class, search_by_super_session, search_by_body_field, inspect_body_candidates, vocab_lookup, find_sessions_using_class) — these become co-pilot tools on interoperability screens at P3.
**Supplies (adapt):** agent loop, CallerContext, TurnResult (remove two hard-coded agent names, key sessions on screen context, add streaming/progress); `Config.Agent`, AgentDefaults, `Chat.History` with per-conversation locking, sweep tasks, Audit ledger (agent registry instead of two literals, strip hand-written Storage XData, key history on route context); installer and role patterns (idempotent; creates `%SYS` audit event types, `SessionAgent_ReadOnly` role, three scheduled tasks, seed rows).
**Supplies (rewrite for Angular, harvesting logic):** the agent-config form (eleven validation rules, provider cascade), chat panel (1,944-line vanilla JS over Zen hyperevents), citation chips, lock banner, config-empty state, vendored Markdown pipeline.
**Constraints:** synchronous, non-streaming loop; 90 s provider timeout; 300 s gateway timeout; provider selection is an If/ElseIf chain with literals in five places; keys never persisted (env var → `Ens.Config.Credentials` → AES stub); hard-coded `DefaultSSL`; no proxy; not present: Azure OpenAI, Bedrock, Vertex, Cohere, Mistral; no test-connection, no first-login redirect, view gate only `%Ens_Portal:USE`; registry hard-blocks any mutating tool; creates no web application, no resource, no uninstall hook, no declared dependencies.

### iris-execute-mcp-v2 (D6b [27]; last commit 2026-08-19; package `ExecuteMCPv2`, 29 classes, `/api/executemcp/v2`)

**Supplies:** the **104 (disputed: 108) tool backlog** — the "UI-equivalent" feature list (dev 28, admin 26, interop 22, ops 21 or 25, data 7); 80 tools depend on its custom REST application (~85 routes on a `%Atelier.REST` subclass); reusable ObjectScript handler bodies — security handler (3,494 lines over `Security.*`, `OAuth2.*`), interop handler (2,728 lines over `Ens.Director`, `Ens.Config.*`), monitor handler (1,427 lines over `%SYS.ProcessQuery`, `%SYS.LockQuery`, `%SYS.Journal.System`, `$SYSTEM.Mirror`, `$SYSTEM.License`, `SYS.Database`), config handler (`Config.Namespaces`, `Config.Databases`, mappings), task handler (`%SYS.Task`), system-config handler (`Config.config`, `Config.Startup`), composite health check, Mermaid message-trace generator, shared namespace-switch / error-sanitize / UTF-8 body plumbing. **These implement D4's custom-REST list handler for handler** (insight 4).
**Governance model to copy into the co-pilot:** `tool` / `tool:action` keys with frozen baseline, write keys disabled by default, env → file → preset → default cascade, read-only preset, structured `GOVERNANCE_DISABLED` result, server-side confirm gates (`dryRun:false` + `confirm:true`; explicit flags for destructive actions), "recover before clean", secrets-redacted JSONL audit log that governance cannot disable, 32,768-char response ceiling.
**Do not inherit:** the `%Atelier.REST` envelope; the TypeScript-driven self-install (content-hash stamp, Atelier SqlProc probe, `PUT /doc` + compile, `%ALL` mapping, four-state self-heal); the stale IPM manifest; the `%Development`-gated web app pattern. Two 2026-04-20 defects unverified.

### iris-table-editor (D6c [9]; v0.2.3; last commit 2026-02-26; no ObjectScript)

**Supplies (wrap):** SqlBuilder, DataTypeFormatter, UrlBuilder, models (~1,300-line pure TypeScript core). **Adapt:** AtelierApiService, QueryExecutor, TableMetadataService (right logic; Basic-auth headers built with Node's Buffer per call — for OcuPilot the Atelier path still needs an explicit Basic header or a route through `/api/ocupilot` [46]); theme.css / grid-styles.css (`--ite-*` tokens, theme bridge); GridPanelManager export-all and XLSX import (port to a browser ExcelJS build). **Rewrite:** grid.js and main.js (~7,600-line vanilla DOM; harvest the keyboard model, filters, date picker, new-row staging, CSV loop). **Discard:** VS Code, Electron, Express hosts and message bridges.
**Features it proves:** namespace and table browsing from INFORMATION_SCHEMA, paged grid (TOP + `%VID` subquery + separate COUNT), type-aware formatting and editors, one-cell-per-request UPDATE, parameterized INSERT/DELETE, filter row, sort, keyboard model, CSV export — the P2 System Explorer SQL grid. Data path is one `POST /api/atelier/v1/{ns}/action/query` with `{query, parameters}`.
**Limitations carried:** single-column PK (IS_IDENTITY, fallback `ID`); identifier regex rejects delimited names; `rowsAffected` always 1; count failures show zero; undo edit-mode only; stale CLAUDE.md.

### iris-couch (D6d [26]; last commit 2026-04-19; package `IRISCouch`, `/iris-couch/`)

**Supplies (reuse as-is after renaming):** the error and response envelope (`Util.Error.Render` with slug constants; overrides of `ReportHttpStatusCode` and `Http405`; internal exceptions logged fully, reported generically); `Audit.Emit` with the structured JSON logger; the HTTP test harness (78 `%UnitTest` classes, header-capturing variants, no-double-envelope assertion, pure builder methods).
**Adapt:** the `%CSP.REST` router with a UrlMap of thin wrappers delegating to handler classes and recording metrics (route ordering is load-bearing, with a regression test); `OnPreDispatch` middleware seam (trailing-slash normalization, auth ladder cookie → JWT → proxy headers → Basic, static-UI intercept for multi-segment deep links, per-resource enforcement); the static-file SPA handler (configurable directory, path-traversal checks, immutable cache headers for hashed assets, no-cache for `index.html`, `index.html` fallback); the idempotent installer (web app only if absent, admin role, 17 audit events guarded, namespace restored in Catch); the config pattern; the Prometheus collector (lock-free `$Increment` globals, bounded label set). Angular 18 standalone app with baked base href, committed bundle, initializer/guard/interceptor pattern (nothing client-side; HttpOnly cookie as session; 401 clears state).
**Not applicable:** per-database RBAC, users-database sync, everything CouchDB-shaped. **Gaps not to inherit:** no CSRF/SameSite/Secure/CORS; mount path baked in four places; config "only reader" rule violated twice; no Docker artifacts; minimal module.xml (docs overclaim).

### What is new for OcuPilot (D6a "must add"; Rec 4; insights 2, 5, 6; CP rows; Prioritized feature list)

- The **Angular shell and every screen** — the six contest areas (~40 screens), the shell (SH-01 to SH-11), and later parity; no sibling has an Angular admin UI.
- The **agent REST surface** (~six endpoints: run turn, load transcript, lock state, agent-config CRUD, credentials list, tool list) and the **two log endpoints** (messages.log, application error log).
- **Streaming or progressive turn delivery** (progress P0, SSE P2).
- **A permission model for mutating tools** — propose, review, confirm; execution strictly as the user; read-only mode; tiered autonomy; prohibited operations outside the agent's reach; administrator kill switch (combining session-agent core with MCP-suite governance).
- **Distinct audit marking of agent-initiated changes**; citations to rows and API calls; token usage per user.
- **First-login configuration gate** and a **test-connection action**.
- **Context-window trimming**; **prompt-injection safeguards / log-content sanitization**; **proxy and custom-CA support**; **cost computation**; **an uninstall hook**.
- **Screen synchronisation after agent writes and agent-driven navigation** (CP-42, CP-43).
- **Screen-context injection with a user toggle**; per-screen suggested prompts; explain-this-screen / explain-this-log-entry (P1).
- **One read tool per P0 screen** and write tools for the P0 write actions; widen the registry's superclass scan.
- **Silent-first JWT authentication** and the `%ISCMgtPortal` membership for OcuPilot's REST application; the `/api/admin` version guard.
- **IPM module + Dockerfile + idempotent installer** reconciling the four contradictory install patterns; static SPA handler with deep-link fallback.
- **Embedding host** for the vendor's Rule, DTL and BPL editors (iframe host component, event bridge) — post-contest (P2).

---
title: 'OcuPilot PRD review: contest compliance and judging'
status: review
created: '2026-09-08'
reviewed: 'prd.md, addendum.md (sections 9 and 13), extract-research.md section 1, research.md D1 and D2, digests/contest-rules-r1-1.md, digests/contest-field-r1-1.md, feature-catalog.md (PK, LG, OS, SS, WA rows)'
contest: 'InterSystems "Build Your Own Management Portal", Open Exchange contest 48'
---

# Contest compliance and judging review of the OcuPilot PRD

**Reviewer lens:** would the product the PRD specifies be accepted into contest 48, how would it score against the five published criteria and the bonus precedent, and what does the contest demand that the PRD fails to require.

**Evidence used beyond the documents.** Four things were checked against primary sources rather than taken from the PRD, because they decide findings below: (1) the contest Terms at `openexchange.intersystems.com/assets/doc/contest-terms.md` (IP clause, "quality of code" scoring sentence, obfuscation rule); (2) the running `ocupilot` container: `GET /api/admin/info` (privileges include `Wallet`), `GET /api/admin/v2/wallet/collections` (HTTP 200; the route needs the `/v2/` prefix, without it 404), and the generated admin API spec from `GET /api/mgmnt/v1/%25SYS/spec/api/admin` (305 paths, 185 under `/v2/`, which confirms every P0 route including `web-app`/`web-apps`, `security/audit/records`, `oauth2/server`, `oauth2/client/*`, `resource-server`, `x509-credential`, `task/*`, `monitor/dashboard/system-resources`, `security/ldap/test`, `security/ssl-configuration/test`, `audit/record/copy|purge`); (3) `GET /api/monitor/metrics` on the instance, which exposes `iris_cpu_usage`, `iris_cpu_pct{id}`, `iris_phys_mem_percent_used`, `iris_disk_percent_full{id,dir}`, `iris_jrn_free_space{id,dir}`, `iris_jrn_size`, `iris_db_free_space`; (4) the container's Web Gateway configuration, `/usr/irissys/csp/bin/CSP.ini`, which has `Server_Response_Timeout=60`.

---

## 1. Verdict

**Accepted, and a contender for the Experts top three; first place is not yet secured by what the PRD requires.** The product the PRD specifies satisfies every hard requirement that the PRD controls: it is new to Open Exchange, open source under MIT (the Terms' IP clause is a nonexclusive promotional licence and is compatible, so Open Question 9 can be closed), runs on both Community editions, installs by IPM and Docker, carries an English README with install steps, a video and an idea link (FR-69), and covers all six named areas with live reads and at least one confirmed write each (SM-3). The agent co-pilot with propose-review-confirm, run-as-user execution and an audit marker is a differentiator no prior entrant or adjacent product has, and it maps well onto Complexity and Applicability. The exposure is in three places the PRD leaves to chance. First, "fully functional" is judged by what a judge experiences on a clean machine, and the PRD's judge path (UJ-5) depends on an LLM API key the judge may not have, on a Web Gateway timeout the installer is forbidden to fix (verified at 60 s in the stock container), and, if the cut line bites, on classic-portal link-outs the contest exists to replace. Second, two parentheticals in the task statement, "OAuth setup" and "all the logs", are met only in the polish week after the 2026-09-27 deadline: Release 1 lists and deletes OAuth entries but cannot set one up, and ships two of the five classic "System Logs" viewers. Third, "submittable build" (SM-2, 10.1) is never defined, so an early cut-line stop could submit a read-only portal with the classic portal one click away, which is exactly what discretionary approval "based on complexity and usefulness" is there to reject. Expected score if the P0 scope lands as written: high on Complexity and Applicability, good on Usability, at risk on Clarity of Instructions and Developer Experience for reasons the README rather than the code decides. Fix the two criticals and the seven highs below and the entry is positioned for first.

---

## 2. The six named areas against the PRD

Task statement, verbatim: "Create a GUI powered by InterSystems IRIS management APIs for the following Management Portal tasks" (research D1 [2]).

| # | Area as named | Parenthetical items named | PRD coverage at the 2026-09-27 deadline (P0) | Deferred to the polish week (P1) or later | Verdict |
| --- | --- | --- | --- | --- | --- |
| 1 | Manage web apps and explore REST APIs | — | FR-30 list/detail/full editor (L, cut-line step 5); FR-31 create; FR-32 enable/disable/delete; FR-33 REST explorer list; FR-34 OpenAPI path-and-verb viewer. Routes confirmed in the generated spec (`web-app` DGP, `web-apps` G). | Try-it console (WA-08), web sessions (WA-09). | **Covered.** "Explore" is a viewer, not a client, until WA-08; acceptable. |
| 2 | Permission management | — | FR-35 to FR-41: users, roles, resources, services, with create, edit, delete, enable/disable, password, role membership. All routes confirmed. | Effective privileges, "does X hold Y" agent question (PM-17, PM-18). | **Covered.** Strongest area. |
| 3 | Security and Secrets management | **wallet, x509 creds, OAuth setup, etc.** | FR-42 SSL/TLS full editor (L, step 5); FR-43 X.509 list, import, edit, delete; FR-44 OAuth 2.0 **lists, views and deletes only**, every entry linking to the classic editor; FR-45 LDAP/Kerberos editor (L, step 5); FR-46 wallet collections and secrets CRUD (route verified live at `/v2/wallet/collections`); FR-47 auditing controls. | **All OAuth 2.0 editors** (FR-75), SSL/LDAP tests, X.509 detail, token revocation, audit copy/purge. | **Partial at the deadline.** Wallet and x509 are met. "OAuth setup" is not: no create or edit of any OAuth 2.0 object, in the UI or through an agent write tool (FR-17 covers "every write action in 5.5 through 5.10" and FR-44's only writes are deletes). The spec confirms `oauth2/client/server-definition` POST/PUT, `client-configuration` PUT and `register-client`, `oauth2/server` PUT, `resource-server` PUT are all available. See finding H1. |
| 4 | Task management | — | FR-48 schedule, on-demand, upcoming; FR-49 history; FR-50 details; FR-51 run/suspend/resume/delete and Task Manager control; FR-52 New Task wizard and FR-53 Edit task (both L, **last items before the cut line**). | Export/import, background tasks (TM-14 to TM-16). | **Covered if step 5 ships.** If the wizard is cut, task creation exists only as an agent write tool over a roughly 60-field payload (finding M6). |
| 5 | Operating system management | **processes, disks, CPU, memory, devices, etc.** | FR-54/55 processes with details and control; FR-56 system usage, shared memory, "CPU, memory and performance meters of the system dashboard"; FR-57 locks; FR-58 databases as "disks" (size, max, free space, directory, mounted); FR-59 devices CRUD. | Broadcast, license usage, full dashboard meter groups. | **Covered, with two readings to firm up.** *Disks:* the databases list is the classic portal's nearest analogue and is defensible, but the monitoring API the PRD already uses exposes literal disk metrics (`iris_disk_percent_full{dir}`, journal and WIJ free space) that make the word literal for a few rows of work (M1). *CPU and memory:* FR-56 ties them to classic dashboard meters whose names are uncaptured (OQ 7), and the classic dashboard has no CPU meter; `iris_cpu_usage`, `iris_cpu_pct{id}`, `iris_phys_mem_percent_used` and `/v2/monitor/dashboard/system-resources` are verified and should be named (M2). *Memory as monitoring, not configuration* (addendum §11) holds: no admin API route exists for memory configuration. |
| 6 | All the logs | **"what's being reported to the user from various sub-systems"** | FR-60 alerts.log; FR-61 audit database; FR-62 messages.log; FR-63 application error log. Four viewers. | System Monitor log, background-task error log, xDBC error log, SQL diagnostics log, interoperability event log, analytics log, and the unified log hub (FR-77, LG-05 to LG-10). | **Thin at the deadline.** The classic portal's System Logs menu has five entries; P0 ships two of them (messages.log, application errors) plus two logs from other menus. The word "all" and the sub-system phrasing point at the hub the PRD schedules after the deadline. On IRIS for Health, judges will also expect the interoperability event log. See H2. |

**Reading of "disks", "memory" and "all the logs":** "memory" holds; "disks" is defensible but easily made literal; "all the logs" does not hold for the deadline build and is the area most likely to be marked down by a judge reading the task statement line by line.

---

## 3. Hard pass/fail requirements against the PRD

Sources: DC announcement [2], Open Exchange contest page [1], Terms [3], Open Exchange docs [6].

| Requirement (verbatim or near) | Status | Where the PRD requires it | Note |
| --- | --- | --- | --- |
| "Fully functional" | **At risk** | §5 throughout; SM-3; SM-4; UJ-5 | Functional as specified, but the judge's path depends on an LLM credential (C2), a 60 s gateway timeout the installer only reports (H3), and classic-portal link-outs for cut editors (H4). No definition of the minimum build that may be submitted (C1). |
| Not "an import or a direct interface for an already existing library" nor "a copy-paste of an existing application or library" | Pass, with one caution | §1, §8 (harvest map), addendum §5 | The rule targets wrappers over foreign-language libraries and copy-pastes. OcuPilot is neither. Caution: the agent runtime is harvested from iris-session-agent, which is already an Open Exchange package by the same author; the README must credit it and state what is new (L5). The PRD's own §3.2 misreads this rule as applying to a screens-only build (L6). |
| New to Open Exchange, or existing "with a significant improvement" | Pass | §1; FR-69 | New listing. Do not file it as an update of iris-session-agent. |
| Works on IRIS Community or IRIS for Health Community | **At risk** | FR-68; NFR-13; OQ 16 | Verified on IRIS for Health CE (this container). Plain IRIS CE, where install falls to `USER` and the IRIS-credentials rung may be unavailable, is untested and scheduled "before the listing". The wallet route is verified here but not on plain CE. |
| Open source, published on GitHub or GitLab | Pass | FR-69; OQ 9 | MIT licence is in the repository. The Terms grant InterSystems "a perpetual, nonexclusive, unrestricted right to use your Contest submission(s) ... for the promotion or management of InterSystems online communities, marketing, or research"; you "retain all rights". Compatible with MIT. Close OQ 9 (L1). |
| README in English with installation steps and a video demo or description; the OE page adds "a link to the idea" | **At risk** | FR-69; PK-01; PK-05 | Required, but the inputs are unscheduled: the Ideas Portal idea must exist before the README can link it, and the video must be recorded before the listing goes up on 2026-09-14 (M8). Nothing requires the README to document the LLM provider prerequisite or the gateway timeout (H3, C2). |
| At most three submissions per developer or team | Pass | — | One entry. |
| Published Open Exchange listing before applying; apply through the contest page after 2026-09-14 | **At risk** | FR-69; SM-2; PK-03 | Open Exchange listings are reviewed before publication; the PRD budgets no lead time and puts listing, video, README and idea on the same day (H5). |
| "Deliberately obfuscated source code is not allowed" | Pass, with one caution | FR-64; PK-15 | The built Angular bundle inside the IPM archive is fine. If the minified bundle is also committed to the repository, the TypeScript sources must be alongside it and the README must say the bundle is a build artifact (L4). |
| Team members' DC profile links in the README (teams of 2 to 5) | Pass (n/a) | FR-69 ("where applicable") | Solo entrant. Link the author's DC profile anyway; it costs nothing and voters use it (L7). |
| Discretionary approval "based on the criteria of complexity and usefulness" | **At risk** | §10.1 cut line; SM-2 | The floor below which the build must not be submitted is undefined (C1). |
| Terms: "you will receive a score based on the success of your solution to the Prompt and the quality of code" | **At risk** | FR-79 (P1) | Unit tests, the HTTP harness and CI are polish-week items, after the deadline (H6). |

---

## 4. Judging criteria assessment

Criteria (Open Exchange page, single-source): Complexity, Clarity of Instructions, Developer Experience, Applicability, Usability. No weights are published. The Terms add "quality of code".

### Complexity — strong

*Earns it:* six areas rebuilt over a hidden vendor API with a version guard and a spec under test (FR-3, NFR-8); an agent runtime with four provider families (FR-25), a tool registry with one read tool per screen and one write tool per action (FR-16, FR-17), server-side confirmation binding (FR-17), execution strictly as the user (FR-18), read-only mode and kill switch (FR-19, FR-20), an audit ledger plus an agent marker in the IRIS audit database (FR-21, FR-22), screen synchronisation and agent-driven navigation (FR-14, FR-15), silent-first JWT sign-in (FR-1), and an IPM module with Docker self-install (FR-64, FR-67).
*Loses it:* the cut line. Every large editor that ships as a classic link (FR-9) is visible incompleteness; judges who know iris-session-agent may discount the harvested core unless the README states what is new (L5). Complexity that a judge cannot exercise (the agent without a key) does not score (C2).

### Clarity of Instructions — at risk, decided by the README

*Earns it:* FR-69's "installation steps that work first time on a clean machine"; UJ-5's install-to-first-write path; FR-23's requirement that the install documentation state the gateway timeout; FR-67's one-command Docker path with the `_SYSTEM` password unexpired.
*Loses it:* nothing in the PRD requires the README to cover the things a judge will actually trip on: which LLM providers work and how to get a key or run a local model (C2); why the web port is 52774 rather than the 52773 every InterSystems template uses (L8); the `HSCUSTOM`-else-`USER` namespace choice (FR-64); what the first-login gate is and that non-administrators can skip it (FR-28); that the gateway timeout must be raised on a non-Docker install (H3); that the agent writes two audit events per change (L9). Add a "README contents" consequence list to FR-69 (M7).

### Developer Experience — good, two gaps

*Earns it:* one IPM module with the bundle inside so no Node toolchain is needed (FR-64); idempotent installer and name isolation (FR-66); Docker self-install on a durable volume with upgrade-in-place (FR-67); uniform error envelope (FR-8); API pinning (NFR-8); no CDN dependency (NFR-10); provider adapters behind one contract (FR-25).
*Loses it:* `zpm "install ocupilot"` needs the package on the community registry, which is P1 (PK-24); before that the README can only offer `zpm "load ..."` (M9). Tests and CI are P1 (H6). The gateway timeout is an operator chore the installer refuses to do (H3).

### Applicability — strong, one tone risk

*Earns it:* the six areas are real daily administration (§3.1 jobs); production switches for regulated shops (UJ-4, FR-19, FR-20, FR-25 local models, §7.2); the agent never exceeds the user's privileges (FR-18, §7.1); the API preference order rides the vendor's own direction (§2, §8).
*Loses it:* the jury is InterSystems staff. Building on a `[Hidden]`, undocumented `%Api.Admin` service is literally "powered by InterSystems IRIS management APIs" and is not a disqualification risk (L2), but a jury member may mark Applicability down for depending on an API that could change in 2026.3 unless the README is candid about the guard and the fallback. §1's "the administration portal InterSystems has not yet built and can point at" is positioning, not a requirement; keep that tone out of the README and the listing (L10).

### Usability — good, three self-inflicted risks

*Earns it:* always-present context-aware panel (FR-10, FR-11); tool-call progress cards and a conversation lock (FR-12); refresh-and-highlight after writes (FR-14); proposal cards with diff, rationale, impact and reversal (FR-17); privilege-gated navigation with tooltips instead of hidden entries (FR-4); auto-refresh that pauses under an open proposal (FR-7); uniform errors with the action to take (FR-8); keyboard and WCAG 2.1 AA floor (NFR-12).
*Loses it:* a panel with no close or collapse control (FR-10) on a judge's 13-inch laptop (M4); ten seconds to first visible progress and no streaming until Stage 5 (NFR-1, NFR-2, OQ 14); Chrome-only testing while judges use whatever browser they have (NFR-11, M5); dark mode, a documented community request, only in the polish week (L11); the first-login redirect that takes an administrator to a configuration form before any screen (FR-28, softened to bypassable; acceptable).

### Quality of code (Terms) — at risk

The Terms score "the quality of code". The PRD's tests, harness, lint and CI are all FR-79, P1. A judge reading the repository on 2026-09-27 finds none (H6).

---

## 5. Bonus precedent and the polish-week plan

No bonuses post exists for contest 48 as of 2026-09-08; the precedent is the Full Stack Contest 2026 list (addendum §13). Against it:

| Precedent bonus | Points | PRD position | Assessment |
| --- | --- | --- | --- |
| Docker | 2 | FR-67, P0 | Collected. |
| IPM | 2 | FR-64, P0 | Collected. |
| Developer Community Idea | 2 | PK-05, P0 (also the README "link to the idea") | Collected if the idea is posted before the README is written; not scheduled (M8). |
| Online Demo | 2 | FR-79, **optional**, unfunded (OQ 8) | At risk. The demo is also the one reliable way for a judge to try the agent without a key (C2). Make it required. |
| First DC article / Second article | 2 / 1 | FR-79, optional, last in the polish week | At risk. The article is also the Community-vote instrument (H7). |
| YouTube video / Short | 3 / 1 | Video required by FR-69; Short optional | Video collected; Short is a five-minute cut of the same footage. |
| Embedded Python | 3 | **Forbidden** by §9 and the project rule | Forfeited by policy. A deliberate trade; record it (M10). |
| Vector Search | 3 | Not mentioned | Not applicable without contrivance; skip. |
| Find a Bug | 2 | Not mentioned | Cheap and unplanned: the research already found `/api/mgmnt/v2` refusing the InteropEditors spec and admin API quirks (M10). |
| First-Time Contribution | 3 | n/a | The author has entered before. |

Precedent maximum 26; OcuPilot's reachable total under the precedent list is 13 (Docker, IPM, Idea, Demo, two articles, video, short) plus Find a Bug for 15, versus 9 if the optional items slip. The polish-week ordering in §10.2 puts bonus deliverables after FR-70 and FR-71, so they are the first things lost if the week runs short; the article and video are better placed at the deadline, when they also serve the vote (H7). The PRD correctly flags that the real list arrives around 2026-09-14 (OQ 1, FR-79) and that an AI or Angular bonus has no precedent.

---

## 6. Timeline against the contest dates

| Date | Contest | PRD | Assessment |
| --- | --- | --- | --- |
| 2026-09-08 | Field empty | PRD finalised | 6 days to listing, 19 to deadline. |
| 2026-09-11 to 13 | — | nothing scheduled | Open Exchange listing review lead time is not budgeted (H5); Ideas Portal idea and video not scheduled (M8); OQ 15 and OQ 16 must be tested "before the listing" but have no date. |
| 2026-09-14 | Registration opens; kick-off webinar 12:00 EDT; bonuses post expected | Listing live with a "submittable build" (SM-2, 10.1); FR-79 re-plans after the kick-off | Earlier submissions list higher during voting, so the day matters. "Submittable" is undefined (C1). |
| 2026-09-15 to 27 | Submission window | P0 build "improves visibly" | Sound. Add the tagged-release rule (M11). |
| 2026-09-27 23:59 "EST" | Deadline | FR-69 | The organizers write "EST" in a month when the US East is on EDT; the OE JSON carries no zone. Treat the deadline as 23:59 EDT, 03:59 UTC on 2026-09-28 (L12). |
| 2026-09-28 to 10-04 | Voting; improvements allowed | 61 P1 rows, one visible change per day (SM-2) | Sound, with two caveats: judges may evaluate the deadline snapshot, so nothing the task statement names should wait for this week (H1, H2); daily pushes to the listed repository must not break a judge's install (M11). |
| Not stated | Winners announced | OQ 12 | Nothing to do. |

---

## 7. Findings

### Critical

- **[critical]** No definition of the minimum build that may be submitted (§10.1 cut line; SM-2; SM-3) — the cut line orders what to drop but never states the floor. Stopping after steps 1 and 2 submits lists, read tools and an agent that can only propose deletes and toggles, with every editor linking to the classic portal (FR-9). Approval is at the experts' discretion "based on the criteria of complexity and usefulness" and is final; a read-only portal over the portal it claims to replace is the entry most likely to be refused or placed in the $100 tier. The PRD's own §3.2 says screens without the agent are "a thin interface by the contest's own rule". *Fix:* add to §10.1 a "minimum submittable build" clause: steps 1 to 3 complete, at least one create-or-edit form per area (step 4), zero classic link-outs on any list screen of the six areas, SM-3 met, and the UJ-3 demo recordable end to end. State that the 2026-09-14 listing may carry less, but the 2026-09-27 application may not.

- **[critical]** The judge's path to the differentiator depends on a credential the judge may not have (UJ-5; FR-28; FR-79; OQ 8; SM-4) — every scored strength of OcuPilot lives behind the first-login gate. A judge who clones, runs `docker compose up` and has no OpenAI, Anthropic or Gemini key, and no local model, sees an empty panel with a banner and a portal the PRD itself calls a thin interface. The online demo that would remove this is optional and unfunded, and the README is not required to explain provider setup. *Fix:* (1) make the online demo a required Release 1 deliverable with a pre-configured provider, instance-wide read-only mode on and a spending cap, decided by 2026-09-14 (closes OQ 8); (2) add an optional Compose profile that starts a local OpenAI-compatible model with tool calling so `docker compose --profile demo up` reaches UJ-3 with no key; (3) require the README to carry a "get a key in two minutes" section per provider and the local-model path; (4) require the demo video to show UJ-2 and UJ-3 in full so a judge without a key still sees the agent write.

### High

- **[high]** "OAuth setup" is named in the task statement and is absent from Release 1 (FR-44; FR-17; FR-75; §10.1 step 3) — the deadline build lists OAuth 2.0 objects, links each to the classic editor and deletes them. No OAuth object can be created or edited through a screen or through an agent write tool, because FR-17 covers only the write actions 5.5 to 5.10 declare and FR-44 declares only deletes. All the editors are FR-75, after the deadline. The generated spec confirms `oauth2/client/server-definition` POST and PUT, `client-configuration` PUT and `register-client`, `oauth2/server` PUT and `resource-server` PUT on the instance. *Fix:* move a minimal "OAuth setup" into P0: create and edit of a client server description and a client configuration (the canonical set-up-a-client flow), as an M-size cut-line step 4 item, with their write tools; leave the authorization-server and resource-server editors in FR-75. If the forms cannot ship, at least the two write tools must, so the agent can set up OAuth from a proposal.

- **[high]** "All the logs" ships as four viewers at the deadline and the rest after it (FR-60 to FR-63; FR-77; §5.10) — the classic System Logs menu holds Application Error Log, Messages Log, xDBC Error Log, System Monitor Log and SQL Diagnostics Log; P0 covers two. The System Monitor log is the same file-tail mechanism as messages.log (an S row, LG-05), and the log hub (LG-10) is the screen that makes "what's being reported from various sub-systems" visible in one place. On IRIS for Health, judges will also look for the interoperability event log. *Fix:* pull LG-05 (System Monitor log, reusing FR-62's endpoint with a fixed second path) and LG-06 (background-task error log, an S row) into P0, and ship a first version of the log hub (counts and last entry per source, links to viewers) before the deadline; keep xDBC, SQL diagnostics and the interoperability log in FR-77 but schedule them first in the week.

- **[high]** Web Gateway timeout: the stock container answers in 60 seconds and the installer is forbidden to change it (FR-23; §8 last bullet; FR-67) — verified: `/usr/irissys/csp/bin/CSP.ini` in the `ocupilot` container has `Server_Response_Timeout=60`. The harvested loop assumes 300 s. Any turn whose single HTTP request outlasts 60 s ends with a gateway error on the judge's first multi-tool question. FR-23 says the installer reports and does not change the value "because the gateway is outside the module's scope", which is right for an IPM install on a customer instance and wrong for the repository's own Docker image. *Fix:* require, in FR-67, that the Docker path sets the gateway timeout (Dockerfile or start script editing `CSP.ini`, or the equivalent for the container's web server) so a clean clone needs no manual step; keep FR-23's report-only behavior for IPM installs and require the README to state the value and how to set it. Alternatively, and additionally, let architecture run turns out-of-request (job plus polling, addendum §3) so no browser request outlasts the gateway regardless of its setting.

- **[high]** Classic-portal link-outs undermine "fully functional" and depend on an untested sign-in direction (FR-9; §10.1; OQ 15) — a link from an OcuPilot screen to the portal the contest asks entrants to replace is a visible admission, and OQ 15 (whether an OcuPilot form login signs the browser into the classic portal) is unresolved, so the link may land on a login form. *Fix:* test OQ 15 on the development container before 2026-09-14; count each link-out on a P0 list screen against SM-C1; set the submission floor to zero link-outs (C1); where a large editor must be cut, ship a reduced form with the fields that daily administration uses rather than a link.

- **[high]** Open Exchange listing lead time and the 2026-09-14 day are not planned (SM-2; FR-69; PK-03; §10.1) — the listing must exist before applying, listings are reviewed before publication, and the PRD puts listing, README, video, Ideas Portal idea, OQ 15 and OQ 16 verification on or before one day with no dates. Earlier applications list higher during voting. *Fix:* add a submission mini-plan to §10.1: idea posted and video recorded by 2026-09-11; listing submitted for Open Exchange review by 2026-09-11 with the README pointing at a tagged preview; OQ 15 and OQ 16 tested by 2026-09-12; apply through the contest tab on 2026-09-14 in the first hours.

- **[high]** Code quality is scored by the Terms and the PRD defers every quality artifact past the deadline (FR-79; PK-22, PK-23; §10.2) — the Terms say the score is based on "the success of your solution to the Prompt and the quality of code". The unit suite, HTTP harness, lint and CI are polish-week items. The harness already exists in iris-couch (addendum §5). *Fix:* move PK-22 and PK-23 into P0 at reduced scope: the HTTP harness, one test per OcuPilot API endpoint, the confirmation-binding test (FR-17) and the audit-marker round trip (FR-22), with CI running them; keep coverage growth in the polish week.

- **[high]** No go-to-market for the Community vote (SM-1; §10.2; FR-79; addendum §12 "Community voting favored a recurring cohort") — SM-1 makes a Community placement the floor, the research says the vote follows a known cohort, and the PRD's only lever is "one visible change per day". The article, the announcement and the video are optional and last. *Fix:* require, by the deadline: the video on YouTube, a Developer Community article announcing the entry with the demo, and a comment on the contest announcement; in the voting week: the second article on the agent's safety model, and the Short. Order them before FR-70 and FR-71 in §10.2, not after.

### Medium

- **[medium]** "Disks" is read as databases when literal disk metrics are already available (FR-58; addendum §11; catalog OS-10) — `GET /api/monitor/metrics` on the instance exposes `iris_disk_percent_full{id,dir}` per database directory, `iris_jrn_free_space{id,dir}` for primary, secondary and WIJ, and `iris_jrn_size`. The databases list satisfies a generous reader; a literal reader wants disk space. *Fix:* add to FR-58 a "Disks" view or column set from the monitoring API: directory, percent full, journal and WIJ directories with free space; S-size, no new server code.

- **[medium]** "CPU" and "memory" rest on uncaptured dashboard meters (FR-56; OQ 7; catalog OS-09) — FR-56 says "the CPU, memory and performance meters of the system dashboard" and defers meter names to a page-source pull; the classic dashboard has no CPU meter. Verified sources exist: `iris_cpu_usage`, `iris_cpu_pct{id}` per system process, `iris_phys_mem_percent_used`, shared memory from `/v2/monitor/system-usage/shared-memory`, and `/v2/monitor/dashboard/system-resources`. *Fix:* name those metrics as the CPU and memory consequences of FR-56 so the parenthetical is met independently of OQ 7; keep the classic meter groups as FR-76.

- **[medium]** Task creation has no fallback below the 60-field wizard (FR-52; FR-53; §10.1 step 5) — the wizard and edit task are the last items before the cut line; if cut, the only create path is an agent write tool whose proposal card would show a roughly 60-field diff. *Fix:* define an M-size "quick task" create (name, description, namespace, task type, run-as user, schedule daily/weekly/on-demand) as a step 4 item that FR-52 later extends; the same reduced payload becomes the write tool's default shape.

- **[medium]** The panel has no close or collapse control (FR-10) — a permanent right-hand panel with a minimum width, on a judge's laptop, reflows every list screen into the remaining space; narrow-viewport behavior is left to UX. *Fix:* require a collapse-to-rail state in Release 1 (the conversation persists; one click restores), and let the UX decide the narrow-viewport treatment.

- **[medium]** Chrome is the only tested browser (NFR-11) — judges and voters use what they have; Safari is common on the laptops that record demo videos. *Fix:* keep Chrome as supported, but add a pre-deadline smoke pass of UJ-2 and UJ-3 on current Firefox and Safari and fix blockers only.

- **[medium]** Voting-week pushes can break a judge's install (SM-2; §10.2) — "nothing may break a Release 1 screen" is stated, but the mechanism is not: the listing points at a repository whose `main` changes daily. *Fix:* require tagged releases (`v1.0.0` at the deadline, `v1.0.x` in the week), the Open Exchange listing pinned to a tag, the Docker path building from the tag, and a rollback rule if a daily push fails the smoke test.

- **[medium]** README contents are not specified (FR-69) — the requirement lists install steps, video, idea link and profiles, and leaves out what judges will need. *Fix:* add a consequences list: prerequisites (Docker, or IRIS 2026.2 with IPM 0.10.x), the provider key or local-model section, the 52774 port and why, the namespace choice, the first-login gate, the gateway timeout for non-Docker installs, the two audit events per agent write and how to filter them, the privilege model (`%Admin_*` and the OcuPilot administrative resource), what is harvested from which sibling and what is new, and a "known limitations" section naming the hidden admin API and the version guard.

- **[medium]** The Ideas Portal idea and the video have no owner or date (FR-69; PK-01; PK-05; FR-79) — both are inputs to the README and to the 2026-09-14 listing. *Fix:* date them in the submission mini-plan (H5): idea posted 2026-09-10 so it is live before the listing; demo video recorded from the 2026-09-13 build and re-cut from the deadline build.

- **[medium]** `zpm "install ocupilot"` is unavailable until registry publication, which is P1 (FR-64; PK-24) — judges who read "one IPM command" will try the registry first. *Fix:* publish to the community registry from the deadline tag, and until then make the README's IPM command the `load` form with the exact path.

- **[medium]** Bonus points left on the table by policy and by omission (§9 no embedded Python; FR-79) — the Python prohibition forfeits a 3-point precedent bonus, which is a defensible trade for install robustness but should be recorded as one; "Find a Bug" (2 points) is unplanned though the research already surfaced reportable defects (`/api/mgmnt/v2` refusing the InteropEditors spec; task-history filter and resource-creation defects). *Fix:* record the Python trade in §9 with its cost; add to FR-79 "file at least one reproducible IRIS defect report on the Developer Community during the submission window".

### Low

- **[low]** Open Question 9 can be closed: the IP grant is compatible with MIT (OQ 9; FR-69; addendum §12) — the Terms say "You retain all rights to your submitted source code ... except that you grant to InterSystems a perpetual, nonexclusive, unrestricted right to use your Contest submission(s) ... for the promotion or management of InterSystems online communities, marketing, or research relating to technologies used in your submissions." A nonexclusive promotional licence sits inside what MIT already grants everyone. The Terms also require that you own the rights you submit; the harvested siblings are the author's, and §9 forbids copying vendor bundles. *Fix:* close OQ 9 in §13 and drop "subject to Open Question 9" from FR-69.

- **[low]** The hidden admin API is a management API, and the risk is fragility, not eligibility (§8; FR-3; NFR-8) — the task says "powered by InterSystems IRIS management APIs" without defining them (research D1 "what the rules do not say"); `%Api.Admin` is InterSystems' own administration REST service. Disqualification on this ground is not plausible. The residual risk is an InterSystems juror marking Applicability down for an unsupported dependency. *Fix:* keep FR-3 and NFR-8; add the candid "known limitations" paragraph to the README (M7); ask the support-stance question at the kick-off (OQ 3) and record the answer in the listing.

- **[low]** The addendum's "UrlMap-only, not confirmed by the OpenAPI scan" note on web-apps routes is stale (addendum §3, first row) — the generated spec from `GET /api/mgmnt/v1/%25SYS/spec/api/admin` confirms `web-app` (DELETE, GET, PUT), `web-apps` (GET), `web-app/pct-access` and `web-sessions`. *Fix:* update the row; the write payload shapes remain unobserved and the epics' "exercise the payload first" rule still applies.

- **[low]** A committed minified bundle can read as obfuscated source (PK-15; FR-64) — the Terms forbid deliberately obfuscated code; a `dist/` of minified JavaScript in the repository without its sources invites the question. *Fix:* keep the Angular sources in the repository, build the bundle in CI for the IPM archive, and if the bundle is committed, say in the README that it is a build artifact reproducible with one command.

- **[low]** The harvest from an Open Exchange package by the same author needs crediting (§8; addendum §5; the "copy-paste" rule) — iris-session-agent is already listed on Open Exchange; a juror who knows it may see the provider adapters and agent loop as reused. *Fix:* the README's "what is harvested and what is new" section (M7) with the addendum §5 "New for OcuPilot" list as its basis; make sure the Open Exchange listing is a new package, not an update.

- **[low]** §3.2 misreads the "thin interface" rule (§3.2 Non-Users) — the rule's verbatim text targets "an import or a direct interface for an already existing library in another language" and "a copy-paste of an existing application or library". A GUI over management APIs is what the contest asks for and is not a thin interface under that rule. The misreading is harmless inside the PRD but must not reach the README or the listing text. *Fix:* reword §3.2 to "only the rebuilt screens, without the differentiator the entry is positioned on".

- **[low]** Author profile link is treated as optional (FR-69 "where applicable") — teams must link every member; a solo entrant is not required to, but the Community vote is by Developer Community members who click through. *Fix:* require the author's DC profile link in the README.

- **[low]** The non-default web port is undocumented as a requirement (FR-67; docker-compose.yml) — 52774 exists to coexist with another container on the author's machine; every InterSystems template uses 52773 and judges will type it. *Fix:* FR-67 should require the README to state the port on the first screen of the install section, or the shipped compose should default to 52773 with the offset as a documented override.

- **[low]** Two audit events per agent write will surprise a juror reading the audit database (FR-22) — the agent marker is OcuPilot's own event beside the IRIS system event. Correct, since vendor events cannot be altered, but a juror expecting the IRIS event's description to say "via agent" will find two rows. *Fix:* the README's audit section (M7) and a one-line explanation in the audit viewer's agent-marker filter.

- **[low]** Positioning tone toward the jury (§1 "the administration portal InterSystems has not yet built and can point at"; §2) — fine in a PRD, risky in a README read by InterSystems product managers. *Fix:* keep the README's framing to "built on IRIS's own management APIs; complements the Management Portal", and let the demo make the argument.

- **[low]** Dark mode is a documented community request scheduled after the deadline (FR-73; addendum §8) — voters see it; it is an S-to-M theming item. *Fix:* ship it on the first day of the voting week, ahead of the rest of FR-73.

- **[low]** Deadline timezone (§1; §2; addendum §13) — "23:59 EST" on 2026-09-27 falls in daylight time. *Fix:* plan to 23:59 EDT (03:59 UTC 2026-09-28) and apply well before that hour.

---

## 8. Finding counts

| Severity | Count |
| --- | --- |
| Critical | 2 |
| High | 7 |
| Medium | 10 |
| Low | 12 |
| **Total** | **31** |

## 9. What the PRD gets right for the contest

For balance, the choices that a reviewer would otherwise have to ask for and that the PRD already requires: all six areas in Release 1 rather than a subset (moots OQ 2); at least one confirmed write per area as a success metric (SM-3); the contest deliverables as functional requirements rather than a checklist (FR-69); listing early and improving through the voting week, which the rules reward (SM-2, addendum §1 item 16); Community Edition compatibility tested against both stock images (FR-68); an API version guard and a spec under test for the one dependency that could break the entry (FR-3, NFR-8); no CDN so the demo works offline (NFR-10); server-side confirmation binding so the safety claim survives a curious juror with curl (FR-17); the wallet kept at P0 because the contest names it, with its route now verified on the instance (FR-46); the counter-metrics that stop screen count from crowding out working writes (SM-C1 to SM-C3); and the bonus re-plan after the kick-off (FR-79, OQ 1).

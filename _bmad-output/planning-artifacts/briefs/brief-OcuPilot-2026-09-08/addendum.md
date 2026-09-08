---
title: 'OcuPilot brief addendum'
status: final
created: '2026-09-08'
updated: '2026-09-08'
---

# OcuPilot brief addendum

This addendum holds depth that belongs downstream, in the PRD, architecture, and epics, or that earned a place but does not fit the brief. Citations refer to `research.md` and `feature-catalog.md` in `_bmad-output/planning-artifacts/research/technical-ocupilot-portal-feature-landscape-2026-09-08/`.

## Naming

The feature is the **agent co-pilot** in every document, never plain "co-pilot", so it is not confused with Microsoft Copilot. The software inside the panel is "the agent". The panel is "the agent co-pilot panel" or "the panel".

## Decisions

The owner set all of these on 2026-09-08. The inherited ones came before the brief and are inputs to it, not outputs of it. The brief-time ones answer the three questions the sources left open.

### Inherited, set before the brief

1. **Contest scope.** The six areas the contest names verbatim, plus the agent co-pilot as the differentiator. The six are: manage web apps and explore REST APIs; permission management; security and secrets, including wallet, X.509, and OAuth; task management; OS management, meaning processes, disks, CPU, memory, and devices; and all the logs. Nothing else ships before 2026-09-27. Matches research Rec 1.
2. **Agent co-pilot write model.** Read/write. Every write is proposed, reviewed, and confirmed, then executes strictly as the logged-in user. Read-only mode and an administrator kill switch exist as switches, not defaults.
3. **Panel.** Always visible on every route, resizable, never dismissed by navigation. Docked like VS Code's secondary side bar.
4. **Interactive screens.** A confirmed agent write refreshes and highlights the affected screen (catalog CP-42). The agent can navigate the user to the relevant screen (CP-43).
5. **Backend.** Build on the instance's existing REST services: the hidden `/api/admin` v2 service, `/api/monitor`, and `/api/mgmnt`. Custom endpoints only where no route exists: `messages.log`, the application error log, and the agent runtime. Matches research Rec 2. Pin v2, check `apiVersion` at startup, and keep the generated OpenAPI document under test. The owner's gloss: "screens and an agent, not a backend" means every screen is wired live to these services. It is a working system, not demo screens.
6. **Authentication.** Silent-first JWT. OcuPilot's REST application enables JWT and joins the `%ISCMgtPortal` group. The shell tries an empty-body `POST /api/admin/login` first, falls back to its own login form, and sends one Bearer token to every JWT-enabled API. Embedded vendor editors log in silently. Group by ID is deprecated in the docs but is what the vendor's own portal uses. It is accepted for the contest. Matches research Rec 3 and the auth spike (`digests/auth-spike-r2-1.md`).
7. **Providers.** OpenAI, Anthropic, Gemini, and OpenAI-compatible local models, harvested from iris-session-agent, with a first-login configuration gate and a test-connection action.
8. **Packaging.** One IPM module plus a Docker Compose workspace that self-installs. ObjectScript lives under `src/OcuPilot`. Install into `HSCUSTOM` if present, otherwise into `USER`. Matches research Rec 5.

### Made while writing the brief

- **Post-contest success is vendor attention.** Parity is the credibility ticket, not the measure. The brief's "After the contest" section lists the three signals.
- **List early, cut cleanly.** List on Open Exchange with a submittable build on 2026-09-14 and improve visibly through 2026-10-04. Inside P0, follow the "Cut line inside P0" section below, and link an unfinished large editor to the classic portal page rather than ship it half-done.
- **Developer-administrators are the design target.** Production administrators get read-only mode, the kill switch, and a local model.

## Harvest map for the agent runtime

From research insight 5 and Rec 4.

| Source | Supplies |
| --- | --- |
| iris-session-agent | Providers, the tool contract, the registry, an audit log, and chat history |
| iris-execute-mcp-v2 | The governance model: tool and action keys, default-disabled writes, a read-only preset, server-side confirm gates, and a redacted audit log |
| New for OcuPilot | Progress reporting and streaming, propose-review-confirm for writes, execution as the logged-in user, a test-connection action, a first-login gate, and sanitization of log content before it reaches the model |

## Cut line inside P0

From the research's prioritized feature list, for the PRD's must-have ordering:

1. Every list and detail screen with its agent co-pilot read tool.
2. The agent co-pilot core.
3. Small write actions in permissions, tasks, and OS management: enable, disable, run, suspend, resume, terminate, and delete.
4. Medium editors: web application create, user and role create, and the resource, device, and wallet editors.
5. Large editors, 22 of the 119 P0 rows: web application edit, user and role edit, service edit, SSL, LDAP, and the task wizard.

## Post-contest sequence

The order follows API readiness (research, Rec 7 and the catalog tiers):

1. The rest of the hidden `/api/admin` service (P2).
2. System Explorer over the Atelier API, with the grid harvested from iris-table-editor (P2).
3. Interoperability over the interop-editors v7 API, with the three vendor document editors for BPL, DTL, and rules embedded (P2).
4. Custom-REST parity harvested from the MCP suite's handlers (P3).
5. The long tail, as demand shows (P4).

The agent grows in step with the phases: confirmed single writes, then guided multistep workflows, undo, and streaming.

## Judgment calls

The catalog lists 26. The five that touch the brief's scope:

- Locks view and removal at P0, although the tier rules put locks at P2.
- Wallet at P0 on an undocumented route, because the contest names it.
- The interoperability and analytics logs at P1, although both need custom endpoints.
- Web sessions at P1 rather than P0.
- The memory configuration page at P3, while memory monitoring is P0.

## Contest facts

From research D1 and D2.

| Item | Value |
| --- | --- |
| Registration and kickoff webinar | 2026-09-14 |
| Submission deadline | 2026-09-27 23:59 EST |
| Voting | 2026-09-28 to 2026-10-04 23:59 EST |
| Experts nomination prizes | $5,000 / $2,500 / $1,000 / $500 / $300, then $100 for places 6 to 10 |
| Community nomination prizes | $600 / $400 / $100 |
| Freshmen nomination prizes | $600 / $400 / $100, for entrants with at most five prior contests and no prior top-three finish |
| Judging criteria, from one published list | Complexity, Clarity of Instructions, Developer Experience, Applicability, Usability |
| Bonus precedent (Full Stack 2026) | Vector Search, Embedded Python, DC Idea, Docker, IPM, Online Demo, Find a Bug, DC Article, YouTube Video and Short, First-Time Contribution |
| Field of entrants | Empty as of 2026-09-08. Prior contests drew 16 to 17 entries. |

Hard requirements, each pass or fail:

- Fully functional.
- Not a thin interface over an existing library or app.
- Open source on GitHub or GitLab.
- English README with install steps and a video or description.
- Runs on IRIS Community or IRIS for Health Community.
- The Open Exchange listing exists before applying.
- At most three submissions per developer.

## Secondary risks

Moved out of the brief to keep it short. Each is real.

- **Group by ID.** It is deprecated in the docs while the vendor's own portal depends on it. The JWT-only login path needs no group and is the fallback (research, Rec 3).
- **License.** The contest terms include an intellectual-property grant to InterSystems. Read the terms before choosing a license (research, D1).
- **Freshmen nomination eligibility.** It depends on prior contests entered and on prior top-three finishes. The $100 tier in Full Stack 2026 is not a top-three finish (research, D2).
- **Durable volume.** How a build-time install interacts with a durable `%SYS` volume is unverified (research, insight 9).
- **Legacy CSP pages.** They are a blind spot inside the contest areas: the task wizard, the application error log, and `messages.log` have no exported source. Pull their source from the container before writing those screens (research, insight 7).

## Open questions carried from the research

The full table is in the "Open questions" section of `research.md`. The ones that touch the brief and are not already under Secondary risks:

- Technology bonuses, to recheck after 2026-09-14.
- Whether partial coverage of the six areas is accepted.
- InterSystems' support stance on `/api/admin`.
- Which classes back X.509, `messages.log`, and application errors.
- The winners' announcement date.

Group by ID, the durable-volume install, and Freshmen eligibility are under Secondary risks.

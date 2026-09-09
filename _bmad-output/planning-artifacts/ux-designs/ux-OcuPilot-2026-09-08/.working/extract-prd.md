# PRD extract for UX — OcuPilot

Sources: `prd.md` (1121 lines, status final, 2026-09-08) and `addendum.md` (295 lines). Citation keys: `§n` PRD section · `FR-n` / `NFR-n` / `UJ-n` / `SM-n` PRD items · `OQn` PRD §12 open question · `A§n` addendum section · `Dn` addendum §1 decision · `XX-nn` catalog row. Nothing here is proposed; everything is what the sources state.

## 1. Product framing

**What it is (§1, verbatim):**
> "OcuPilot is an Angular replacement for the InterSystems IRIS System Management Portal, served from the IRIS instance it manages. Its defining feature is the agent co-pilot: a panel docked on the right of every screen, present on every route, that knows which screen the user is looking at, answers questions about it, and changes the instance through tools that run strictly as the logged-in user. Every write the agent proposes is shown with its rationale and expected impact, reviewed, and confirmed before it runs. After the write, the affected screen refreshes and highlights what changed, and the IRIS audit database records that the change came through the agent. The agent is the main conduit for editing: every write the six areas offer is reachable through it, and the screens' own editors are the second path."

> "Two lines do not move at any stage: the agent never holds a privilege the user does not, and every agent write stays visibly marked in the audit database."

**Problem (§1):** the classic portal is "a Zen-era portal that InterSystems has deprecated but only partly replaced"; the six areas "span about forty classic pages with terse errors and no help beyond a documentation link, and nobody ships an assistant inside the IRIS portal."

**Purpose of Release 1 (§1, §1.1):** first place in Open Exchange contest 48 ("Build Your Own Management Portal"), submissions close 2026-09-27 23:59 EST. "The release is a working system, not demo screens: every list reads live, every editor writes live." Judging criteria (A§14): Complexity, Clarity of Instructions, Developer Experience, Applicability, Usability. "A screens-only build is admissible for the listing but not for the application" (§1.1).

**Target users (§3.1):**

| Persona class | PRD role | Jobs to be done |
| --- | --- | --- |
| Developer-administrators | "the design target"; "administer their own development and test instances, often Community Edition in Docker, and are also the Developer Community voting audience" | get to the right screen in one step; understand a screen/setting/log entry without leaving for docs; make a routine change "by saying what they want and confirming what the agent proposes"; "Trust that nothing changed except what they confirmed, and be able to prove it from the audit database"; install once, one step |
| Production IRIS administrators | "served by read-only mode and the kill switch"; live, regulated, change-controlled instances | same portal with the agent restrained (read-only, kill switch, local model); see in the audit DB what the agent did vs the human; agent never holds a privilege the operator does not |
| The builder | project owner, 19-day solo build | a cut line inside Release 1, stages after |

**Non-users (§3.2):** operators who cannot expose an LLM provider or host a local model; interoperability/analytics/SQL developers (System Explorer, productions are later stages); "Mobile or tablet users. Release 1 targets desktop browsers."; anyone needing a non-English UI.

**Platform / form factor:** Angular SPA at `/ocupilot`, REST at `/api/ocupilot` (A§6); served from the single instance it manages (§9); desktop browsers; "Current Chrome on desktop is the supported and tested browser. Current Edge, Firefox and Safari are best effort and are not tested against" (NFR-11, D12); no CDN, every library vendored (NFR-10, FR-13); English only (NFR-14); dev server must proxy through the IRIS origin (A§2). The panel is "like VS Code's secondary side bar" (§5.2).

**UI system / component library:** none named. A§8: "Theming: vendor bundles have fixed theming (Tailwind and Material tokens, Noto Sans) and no license text; reference in place, never copy. iris-table-editor's `--ite-*` token layer is the theme bridge candidate. Dark mode is a repeated community request and a polish-week row."

**Brand:** name "OcuPilot" (working title confirmed, §0). Logo `logo/OcuPilot-Logo-web.png`; D6: "The web-optimized PNG at 360 px wide, the same convention as the README". Naming: "agent co-pilot — the feature: the panel plus the agent plus its tools. Never shortened to 'co-pilot' alone" (§4).

## 2. Key user journeys (§3.3)

Protagonists exactly as written: **Dana Okafor** (UJ-1, UJ-2, UJ-3, UJ-6), **Marcus Lindqvist** (UJ-4), **Priya** (UJ-5, no surname). D3: journeys were "drafted, not narrated" and confirmed by the owner (D10).

**UJ-1 — Dana arrives from the classic portal and asks what she is looking at.** Dana Okafor, developer administering her own IRIS for Health Community container; classic portal open in another tab. FRs: FR-1, FR-4, FR-5, FR-10, FR-11, FR-16 (citations: FR-71 in polish week — see §10 conflict).
1. Opens `/ocupilot` for the first time today; silent login; "shows Home with no form".
2. Navigates to Permissions, then Users.
3. "The panel on the right already shows the screen context chip 'Users, HSCUSTOM'."
4. Types "which of these users can't log in and why?"; the agent calls the users read tool, answers with disabled and expired accounts, "and cites the rows it used".
5. **Climax:** "The answer names two accounts and the reason for each, and clicking a citation selects the row in the list."
6. Resolution: never left the screen or tab; nothing written. Edge: silent login fails → "OcuPilot shows its own login form once" (OQ15 on classic-portal sign-in).

**UJ-2 — Dana installs OcuPilot from a clean clone and meets the first-login gate.** Not authenticated; fresh clone. FRs: FR-1, FR-24–FR-28, FR-64, FR-67, FR-69.
1. `docker compose up -d`, waits for startup log. 2. Opens `/ocupilot`, sees the login form, signs in as `_SYSTEM`.
3. No agent definition enabled → redirected to the agent configuration screen. 4. Picks Anthropic, pastes an API key, presses Test connection.
5. **Climax:** "Test connection returns success with the model's reply in under ten seconds, and Save enables the agent. Home opens with the panel live."
6. Edge: Test fails → "the form shows the provider's error text, the definition stays disabled, and Dana can still browse every screen with the panel in its configuration-empty state and a persistent reminder banner until she comes back and enables one."

**UJ-3 — Dana fixes a disabled web application through the agent in under a minute.** Recording the contest demo on a video call. The SM-4 / smoke-script path. FRs: FR-12, FR-14, FR-16, FR-17, FR-18, FR-22, FR-30, FR-32, FR-61.
1. On the Web Applications list showing `/csp/myapp` disabled. 2. Types "enable /csp/myapp and give it the %Development resource".
3. Agent calls the read tool, then "produces one proposal card: the target, the two field changes as a before/after diff, the rationale, and the expected impact ('users holding %Development can reach the application')". 4. Dana presses Confirm.
5. **Climax:** "The write runs as Dana. The Web Applications list re-fetches in place and highlights the `/csp/myapp` row, now enabled. The panel shows the tool call card with its result."
6. Resolution: opens the audit database viewer, finds the event "under her own user name with the description marked as coming through the OcuPilot agent co-pilot." Edge: lacking privilege → "the write fails with the same 403 the screen would show, and the agent says so instead of retrying."

**UJ-4 — Marcus runs OcuPilot read-only on a production instance.** Marcus Lindqvist, operations administrator at a regional hospital, change-controlled IRIS for Health. FRs: FR-11, FR-19, FR-20, FR-25, FR-62. Note: local model is a step 7 item, so this journey is not reproducible at the Anthropic-only floor.
1. Authenticated through the form. Administrator has turned on enforced read-only mode and configured a local model. 2. Opens the messages.log viewer, finds a repeating warning, asks the agent to explain it; agent reads through its read tool and explains cause and remedy.
3. Asks it to apply the remedy. 4. **Climax:** "The agent declines the write, states that the instance is in read-only mode, and tells him what he would change on which screen."
5. Resolution: "The context chip names the local provider and host, so Marcus can see that the log text never left the instance." Edge: kill switch engaged → "Marcus's panel shows a disabled state on his next turn and the screens keep working."

**UJ-5 — Priya evaluates the entry as a judge.** Developer Community member judging/voting, thirty minutes and a laptop; starts on the Open Exchange listing. FRs: FR-4, FR-66, FR-67, FR-69, SM-3.
1. Follows the README: clone, `docker compose up -d`, open the URL. 2. Reads the walkthrough (or video), repeats UJ-2 and UJ-3.
3. "She opens each of the six areas from the navigation and, in each, sees at least one list backed by live data and at least one action the agent can propose."
4. **Climax:** "The README's promised path, install to first confirmed agent write, works without a workaround."
5. Edge: expired `_SYSTEM` password → "the login form explains the expiry and links to the fix."

**UJ-6 — Dana troubleshoots a suspended task and lets the agent take her there.** On Home; "notices the Task Manager line in the panel's suggested view". FRs: FR-14, FR-15, FR-17, FR-48–FR-51.
1. Asks "why did the nightly purge task stop?"; agent reads the task list and history, finds it suspended after an error, offers to open it. 2. Dana says yes.
3. "The agent navigates the browser to the task details screen with that task selected, then proposes Resume with the last error as context." 4. Dana confirms.
5. **Climax:** "The task resumes, the details screen highlights the status field, and a toast links to the row in the task list."
6. Resolution: history shows the manual resume attributed to Dana through the agent. Edge: error recurs → "the agent's follow-up answer cites that row rather than claiming success."

## 3. Surface inventory

Build step = §10.1 step; "1/3" = the one list chosen for step 1 for that area, otherwise step 3. Priority P0 unless P1 (polish week). Every list/detail carries a read tool and every action a write tool (FR-16, FR-17) — not repeated per row.

| Surface | Area | FRs | What it shows | Actions / writes | Step | Pri |
| --- | --- | --- | --- | --- | --- | --- |
| Form login | shell | FR-1, UJ-5 | user + password; expired-password explanation with link to fix (UJ-5 edge) | sign in | 0 | P0 |
| Sign-out | shell | FR-2 | — | ends browser-level login; lands on form login | 0 | P0 |
| Version-mismatch blocking notice | shell | FR-3 | "naming the mismatch and linking to the classic portal, and no area screen loads" | link out | 0 | P0 |
| No-admin-privileges notice | shell | FR-3, FR-65 | "no administrative privileges on this instance" | sign-out link | 0 | P0 |
| Navigation (category selector + finder view of each area's screens) | shell | FR-4 | six areas; privilege-disabled entries with tooltip naming resource | navigate | 0 | P0 |
| Home | shell | UJ-1, UJ-2, UJ-6; FR-73 | landing after login; "panel's suggested view" (UJ-6); system information panel is P1 | — | 0 | P0 |
| Header strip | shell | FR-5 (SH-03/04, EX-01) | server, instance, namespace, user, licensed-to, server flag (Live/Test/Failover/Development) | namespace switch (RW namespaces only) | 0/1 | P0 |
| Locator bar | shell | FR-6 | area › screen › selected entity, each segment navigates | navigate | 0 | P0 |
| Command bar (per page) | shell | FR-6 | screen's actions, view options, sort, search | screen actions | 0 | P0 |
| Auto-refresh controls | shell | FR-7 | on/off, rate, last-update stamp; persisted sort/filter/page size/max rows | toggle, set rate | 1/3 | P0 |
| Error presentation | shell | FR-8 | one consistent message "with the action to take"; unreachable vs refused | retry/sign-in | 0 | P0 |
| Classic-portal fallback link | shell | FR-9, FR-44 | link on reduced forms and OAuth lists; opens in new tab | link out | 6 | P0 |
| Docked panel (resize, full screen) | agent panel | FR-10 | conversation, chip, cards, input | resize, expand | 2 | P0 |
| Screen context chip + toggle | agent panel | FR-11 | what is shared, provider, endpoint host, "leaves the instance" | toggle context sharing | 2 | P0 |
| Secret-like message warning | agent panel | FR-11 | warns before sending password/key-shaped text on secret-field screens | send / cancel | 2 | P0 |
| Message input + transcript | agent panel | FR-12 | turns; transcript survives reload | send turn | 2 | P0 |
| Tool-call card | agent panel | FR-12, FR-22 | name, arguments summary, result status, audit-emission failure | — | 2 | P0 |
| Lock banner | agent panel | FR-12 | second message refused while a turn runs | — | 2 | P0 |
| Error card | agent panel | FR-12, FR-23 | timeout / "which step timed out" | — | 2 | P0 |
| Reply (sanitized Markdown, code highlighting) | agent panel | FR-13 | inert external links with full host visible | explicit click | 2 | P0 |
| Proposal card | agent panel | FR-17, FR-47 | target, before/after diff, every payload field, rationale + impact "labeled as the agent's text", reversal, masked secret input, typed-name for destructive, expired state | Confirm, Cancel | 2 (fingerprint + typed name: 7) | P0 |
| Change highlight | every list/detail | FR-14 | changed row/field highlighted ≤ 2 s after write | clears on next interaction | 2 | P0 |
| Off-screen change toast | shell | FR-14, UJ-6 | names the change, links to screen with entity selected | navigate | 2 | P0 |
| Agent navigation announcement | agent panel | FR-15 | "announces where it is taking the user before doing so" | browser back undoes | 2 | P0 |
| Read-only blocked result | agent panel | FR-19 | "blocked by read-only mode"; what it would have changed and on which screen; no card | — | 2 | P0 |
| Enforced-state indicator | agent panel | FR-19 | enforced read-only "visible in the panel of every user" | — | 2 | P0 |
| Per-user read-only toggle | agent panel | FR-19 | default off; cannot override enforced | toggle (stored on instance) | 7 | P0 |
| Disabled state (kill switch) | agent panel | FR-20 | "disabled state with the reason" | — | 2 | P0 |
| "agent writes are not being marked" banner | agent panel | FR-22 | shown to every user when auditing/OcuPilot events off | — | 2 | P0 |
| Configuration-empty state | agent panel | FR-28 | "naming who can configure it" | — | 2 | P0 |
| Administrator reminder banner | agent panel | FR-28, UJ-2 | persistent until a definition is enabled | go to config | 2 | P0 |
| Agent definition list + form | agent config | FR-24, FR-25, FR-26 | name, provider, model, endpoint URL, credential type + reference, max tokens, temperature, max iterations, system prompt override, read-only flag, retention, enabled, default; provider cascade; suggested default models; plain-HTTP acknowledgment | create, edit, enable, disable, delete, set default, enter key (write-once) | 2 (other providers 7) | P0 |
| Test connection | agent config | FR-27 | success + model's reply (truncated) or provider's error text | test as edited, before save | 2 | P0 |
| First-login gate redirect | agent config | FR-28 | admin sent to config on login; may leave | — | 2 | P0 |
| Switches screen (independent of the agent) | agent config | FR-19, FR-20, FR-29 | kill switch (global / per user), enforced read-only, context-sharing default, per-user turn limits | set; each change audited | 2 (turn limits 7) | P0 |
| Governance policy screen | agent config | FR-72 | per tool/action enable, read-only / full presets, effective policy | set | polish | P1 |
| Agent audit viewer | agent config | FR-71 | ledger rows; filters user, screen, date; arguments + result | open row | polish | P1 |
| Transcript viewer (admin, any user) | agent config | FR-72 | per-user transcripts with screen context; gated by recorded resources | open | polish | P1 |
| Web applications list | web apps | FR-30 (WA-01) | name, namespace, type, enabled, dispatch class, resource; filter | enable, disable, delete (FR-32) | 1/3 | P0 |
| Web application editor | web apps | FR-30 (WA-05) | type, enabled, namespace, default app, dispatch class, resource, group by id, auth methods, session timeout, JWT, CORS, CSP file settings, serve files, Python protocol, application + matching roles | Save; enable/disable/delete | 6 | P0 |
| Create web application | web apps | FR-31 (WA-04) | type (CSP/REST/WSGI/ASGI), namespace, dispatch class, resource, auth methods | create → opens editor | 5 | P0 |
| Delete confirmation (web app) | web apps | FR-32 | names the application; OcuPilot's own refused with explanation | confirm | 4 | P0 |
| REST API explorer list | web apps | FR-33 (WA-06) | REST-enabled apps + spec-based services per namespace | open document view | 3 | P0 |
| OpenAPI document viewer | web apps | FR-34 (WA-07) | "path-and-verb browser"; refusal shown, not empty | — | 3 | P0 |
| Try-it request; web sessions list | web apps | FR-74 | request round-trip; sessions | send; end session | polish | P1 |
| Users list | permissions | FR-35 (PM-01) | name, full name, enabled, type, roles; filter | enable, disable, delete, set password, roles (FR-37) | 1/3 | P0 |
| User editor | permissions | FR-35 (PM-07) | account settings, comment, expiry, enabled, change-password-on-login, startup namespace/routine, email, mobile, two-factor, roles tab | Save; row actions | 6 (first large editor) | P0 |
| Create user | permissions | FR-36 (PM-06) | name, password, full name, roles, expiry, startup namespace/routine | create → opens editor | 5 | P0 |
| User actions (row + editor) | permissions | FR-37 (PM-02..05) | set password dialog with change-on-login flag; add/remove roles | act; current user refused with explanation | 4 | P0 |
| Roles list / Role editor | permissions | FR-38 (PM-08/12) | description, escalation-only, resource grants, members, granted-to | Save | 3 / 6 | P0 |
| Role create; resource grant editor; role delete | permissions | FR-39 (PM-09..11) | grant = resource + permissions, "shows the current grant and the result"; delete warns with user count | create, add/edit/remove grant, delete | 5 | P0 |
| Resources list + editor | permissions | FR-40 (PM-13/14) | search; name, description, public permission; system resources not deletable | create, edit, delete | 3 / 5 | P0 |
| Services list + editor | permissions | FR-41 (PM-15/16) | enabled, allowed IPs, roles, auth methods; warning on disabling OcuPilot's web service | Save | 3 / 6 | P0 |
| Effective privileges view | permissions | FR-74 | a user's effective privileges | — | polish | P1 |
| SSL/TLS list + editor | security | FR-42 (SS-01/15) | certificates, key, CA, CRL, protocol min/max, ciphers, DH bits, OCSP, peer verification | create, edit, delete | 3 / 6 | P0 |
| X.509 list + import/edit/delete | security | FR-43 (SS-02/11) | subject, issuer, validity; import cert + optional key | import, edit, delete | 3 / 5 | P0 |
| OAuth 2.0 lists (client server descriptions, client configs, resource servers, server client descriptions) + auth server view | security | FR-44 (SS-03..07) | lists; each entry links to classic editor until FR-75 | delete client configs, server client descriptions (confirmation naming entry) | 3 / 4 | P0 |
| LDAP / Kerberos list + editor | security | FR-45 (SS-08/16) | fields of `%CSP.UI.Portal.LDAP` | create, edit, delete | 3 / 6 | P0 |
| Wallet collections list; secrets list + editor | security | FR-46 (SS-10) | collections; secrets (values write-only); disabled without wallet resource | create, edit, delete secret | 3 / 5 | P0 |
| Auditing configuration (on/off, system events, user events, selective SQL auditing wizard) | security | FR-47 (SS-09/12/13) | events, counters | enable/disable auditing (warns), enable/disable/reset events, create/delete user events | 4 / 5 | P0 |
| SSL test, X.509 details, LDAP test, OAuth token revoke, audit copy/purge, OAuth 2.0 full editors | security | FR-75 | result text; editors | test, revoke, copy, purge, CRUD | polish (OAuth editors first) | P1 |
| Task schedule list | tasks | FR-48 (TM-01) | Task Manager status; filter name/namespace; last and next run; auto-refresh | run, suspend, resume, delete (FR-51) | 1/3 | P0 |
| On-demand tasks list | tasks | FR-48 (TM-02) | on-demand tasks | Run | 3 / 4 | P0 |
| Upcoming tasks list | tasks | FR-48 (TM-03) | horizon (hours or date); ordered by next run | set horizon | 3 | P0 |
| Task history (all / one task) | tasks | FR-49 (TM-04/05) | start, end, status, error text, running user; filter | — | 3 | P0 |
| Task details | tasks | FR-50 (TM-11) | properties, schedule, last/next run; auto-refresh; links to history and Edit | — | 3 | P0 |
| Task actions + Task Manager control | tasks | FR-51 (TM-06..10) | delete confirmation naming task; suspend Task Manager warning | run, suspend, resume, delete; start/suspend/resume Task Manager | 4 | P0 |
| New task wizard | tasks | FR-52 (TM-12) | name, description, namespace, task type, priority, run-as user, output file, suspend-on-error, reschedule-after-restart, schedule (daily/weekly/monthly/after task/on demand), expiry, email | create | 6 (last) | P0 |
| Edit task | tasks | FR-53 (TM-13) | wizard fields with current values | Save | 6 (last) | P0 |
| Task export/import, background tasks, broadcast, license usage, full dashboard meter groups | tasks/OS | FR-76 | — | export, import, cancel/pause/resume, broadcast | polish | P1 |
| Processes list | OS | FR-54 (OS-01) | filter, page size, max rows, persisted sort, auto-refresh | terminate, suspend, resume (FR-55) | 1/3 | P0 |
| Process details | OS | FR-54 (OS-08) | dashboard meters, client executable + address, open devices, current SQL statement | control actions | 3 | P0 |
| Process control confirmation | OS | FR-55 (OS-02..04) | terminate: optional error-to-job flag; confirmation naming pid; own process refused | confirm | 4 | P0 |
| System usage + dashboard meters | OS | FR-56 (OS-05/09) | global refs, routine calls, block reads/writes, journal entries, shared memory; CPU/memory/performance meters; refresh interval | set interval | 3 | P0 |
| Locks view | OS | FR-57 (OS-06/07) | by namespace, filter, owner details (owner links to process details) | remove one / all of process / all of remote client; warns if in transaction | 3 / 4 | P0 |
| Databases list (general / free-space views) + details | OS | FR-58 (OS-10/11) | size, max, free space (async, "shows them as they arrive"), status, directory, mounted; details: properties, volume files, background tasks; auto-refresh | — | 3 | P0 |
| Devices list + editor | OS | FR-59 (OS-12) | fields of `%CSP.UI.Portal.Config.Device` | create, edit, delete | 3 / 5 | P0 |
| alerts.log viewer | logs | FR-60 (LG-01) | recent (monitoring API) + history (bounded file tail) | — | 3 | P0 |
| Audit database viewer + event detail | logs | FR-61 (LG-02/SS-14) | filters: time range, source, type, name, user, pid, namespace, authentication, text; agent-marker filter; detail with description + JSON payload | — | 3 | P0 |
| messages.log viewer | logs | FR-62 (LG-03) | bounded pages; search, highlight, go to top/bottom, tail | — | 1 (endpoint) / 3 | P0 |
| Application error log | logs | FR-63 (LG-04) | drill namespaces → dates → errors; text, time, routine, line | delete by namespace or individually (confirmation naming scope) — the Logs area's SM-3 write | 1 (endpoint) / 3 / 4 | P0 |
| Secondary log viewers + unified log hub | logs | FR-77 | System Monitor, background task error, xDBC, SQL diagnostics, interop event, analytics; hub with counts, last entry, explain entry points | — | polish | P1 |
| "Explain this screen"; per-entry explain; suggested prompts (≥3 per screen, grouped by task) | agent panel | FR-70 | — | one-click send | polish | P1 |
| Citation chips; data-egress line | agent panel | FR-71 | chips select row / open screen; provider + "whether screen data leaves the instance" | click-through | polish (chip disclosure in R1 via FR-11) | P1 |
| Copy-out draft option on a proposal | agent panel | FR-72 | ObjectScript / CLI / REST snippet instead of execution | choose script | polish | P1 |
| Shell conveniences | shell | FR-73 (SH-12..22) | change password, favorites, recents, menu search, About, per-screen Help, shortcuts menu, links panel, Home system information panel, persisted UI state, light/dark theme | — | polish | P1 |
| External language servers list + editor + activity log | OS (unmapped) | FR-78 (SA-01/02) | status; log | start, stop, create, edit, delete | polish | P1 |
| README walkthrough + demo fixtures | install | FR-66, FR-69 | screenshots of UJ-2/UJ-3; `demo` option seeds a disabled web app, a task suspended after error, application errors | — | 0 | P0 |

## 4. Stated behaviors

### (a) Shell and navigation (FR-1..9)
- **Sign-in (FR-1):** "On load the shell attempts silent login first; a success shows no form." Failure → form login; success also signs the browser into the vendor's editors (classic portal: OQ15). Token pair per tab, never persistent storage; refreshed before expiry and once on 401; "a failed refresh returns the user to the form login with the current route preserved." "Cookies alone never authorize a data call."
- **Sign-out (FR-2):** "Tab storage is cleared and the user lands on the form login."
- **Version guard (FR-3):** API not v2 or absent → "a blocking notice naming the mismatch and linking to the classic portal, and no area screen loads." Holder of no `%Admin_*` resource → rendered as "no administrative privileges on this instance" with a sign-out link, "not as a version mismatch." Header instance name and version come from the same call.
- **Navigation (FR-4):** gated by the admin API privilege map (`%Admin_*` only; finer classic gates not reproduced). "A screen the user lacks privilege for is shown disabled with a tooltip naming the required resource, not hidden." "Navigation offers a category selector and a finder view of each area's screens." A§7 notes custom portal resources are keyed by classic page URL and OcuPilot routes "must map back to those keys".
- **Header strip (FR-5):** server, instance, namespace, user, licensed-to, server flag "at all times"; namespace selector lists only RW namespaces; "The chosen namespace is carried on routes and included in screen context." Flag: Live, Test, Failover or Development. (A§7 lists the classic conventions "users expect": namespace switch link, user with change-password link, escalation role, Home/About/Help/Contact/Logout menu, breadcrumbs, per-page ribbon, favorites, recents, "Did you know", menu-only search — most are FR-73 polish.)
- **Page chrome (FR-6):** "The locator bar shows the area, the screen and the selected entity, and each segment navigates." "The command bar holds the screen's actions, view options, sort and search."
- **Auto-refresh (FR-7):** on/off, rate, last-update stamp; sort, filter, page size, max rows persisted per screen; used by Processes, Databases, Task details, Task schedule; "refresh does not reset the user's sort, filter or selection." "Refresh pauses while a proposal is awaiting confirmation on that screen, so the diff under review does not move; the pause ends when the proposal is resolved or expires."
- **Errors (FR-8):** "Every server failure reaches the user as one consistent message with the action to take." 401 → refresh-and-retry; "a 403 names the missing privilege"; connectivity probe "distinguishes 'instance unreachable' from 'request refused'"; internal exceptions "reported generically to the browser."
- **Fallback links (FR-9):** "A cut large editor ships as a reduced form of the fields that daily administration uses plus a link to the classic page for the rest, never as a half-working full form; a list screen never links out." Link opens in a new tab. SM-C1: every link-out counts against the metric.

### (b) Agent panel (FR-10..15)
- **Dock (FR-10):** "The panel has a minimum width and a remembered width per browser; screen content reflows to the remaining width." "Route changes keep the panel and its conversation." "There is no close control in Release 1. Narrow-viewport behavior below about 900 px is a UX decision, not a requirement here."
- **Context (FR-11):** includes "route, namespace, selected entity and the visible rows of the current list or the current form's values"; assembled fresh each turn. "A context chip in the panel names what is being shared, the provider and endpoint host of the agent definition in use, and says 'leaves the instance' when that host is not on a private network; with context off, no screen data is sent on subsequent turns, and the chip says so." Secret-typed fields excluded unconditionally; on such screens "the panel warns before sending a message that looks like a password or key." Toggle defaults on, remembered per user; admin can set instance default off.
- **Turn (FR-12):** "Each tool call the agent makes during a turn appears as a card with its name, arguments summary and result status, in order, while the turn is still running." "While a turn is in progress on the same conversation, a second message is refused with a visible lock banner until the turn completes." Transcript loaded on open, survives reload; new tab = new conversation. "A turn that exceeds the provider timeout ends with an error card, not a silent stop."
- **Reply (FR-13):** sanitized Markdown with code highlighting; "images render only from same-origin or inline sources, external links are rendered inert with the full host visible and open only on an explicit click".
- **Sync (FR-14):** "The active screen, when it shows that entity type, re-fetches and highlights the changed row or field within two seconds of the write completing." "When the affected screen is not open, a toast names the change and links to the screen with the entity selected." "Highlights clear on the next user interaction with that row or field."
- **Navigation (FR-15):** "The agent announces where it is taking the user before doing so; the user can undo the navigation with the browser back button." Only allow-listed route identifiers and entity ids.

### (c) Write model and governance (FR-16..23)
- **Read tools (FR-16):** same endpoint and fields as the screen; "accept the same filters the screen offers and return row identifiers the panel can turn into citations."
- **Proposal card (FR-17):** server-minted; "shows the target entity, a before/after diff computed on the instance from the stored arguments and that fresh read, every field the payload will send, the agent's rationale and expected impact labeled as the agent's text, and, where a reversal exists, how to reverse the change." Write runs only on Confirm on that card; confirmation "is a separate authenticated request from the user's browser". Single-use, expires after a fixed interval, refused if user/conversation/definition/read-only state changed; "target changed, re-propose" on fingerprint mismatch (step 7). Canceled on Cancel, on a new turn, or when a sibling proposal on the same entity is confirmed; "A card restored from a reloaded transcript is shown expired, never live." Secret fields: "the card renders a masked input the user fills at confirmation". Destructive: "requires the user to type the target's name in the card, matching the screens' own delete confirmations" (step 7). Several proposals per turn, each confirmed or canceled individually. SM-C2: never below one explicit confirmation per proposal; §7.1: "no batch approval".
- **As the user (FR-18):** 403 identical to the screen's; "the agent reports the failure instead of retrying with other credentials." "The tool set advertised to the agent is the full set; privilege is checked at call time, not by hiding tools." Prohibited set never advertised (current user, last `%All`, `_SYSTEM`, OcuPilot's web service/apps/resource/role, IRIS system processes).
- **Read-only (FR-19):** "every write tool returns a structured 'blocked by read-only mode' result, the agent tells the user what it would have changed and on which screen, and no proposal card appears." Per-user toggle in panel, default off, cannot override enforced state, stored on the instance (step 7). "The enforced state is stored on the instance and visible in the panel of every user." In-flight turn "stops at its next step when the state changes."
- **Kill switch (FR-20):** "A disabled agent renders the panel in a disabled state with the reason"; screens keep working; pending proposal can no longer be confirmed; off by default; the unconfigured state "is distinct from the kill switch and is not a switch an administrator has to clear." Switches "always reachable by an OcuPilot administrator through a screen that does not depend on the agent."
- **Marker (FR-22):** audit viewer filters on the marker; audit-emission failure "is recorded on the ledger row and shown on the tool-call card"; when auditing is off "the panel shows an 'agent writes are not being marked' banner to every user".
- **Provider (FR-23):** retry with backoff on 429/5xx; fixed timeout; "the turn reports which step timed out."

### (d) Agent configuration and first-login gate (FR-24..29)
- Definition fields: name, provider, model, endpoint URL (where needed), credential type and reference, max tokens, temperature, max iterations per turn, optional system prompt override (A§8: "8,192-character system-prompt counter" harvestable), read-only flag, transcript retention, enabled flag; one default. "Changing provider cascades the provider's canonical defaults into the form"; eleven server-side validation rules. Changing provider/endpoint/credential "disables it until Test connection passes again." No picker in Release 1 (D9).
- Providers (FR-25): Anthropic first; others step 7. "Default models per provider are configuration ... shown as suggestions in the form." Plain HTTP only with no credential "or with an explicit acknowledgment stored on the definition."
- Credentials (FR-26): key "written to the chosen credential store once and is never returned"; "Key shape checks per provider catch obvious paste errors"; IRIS-credentials rung "offered only where the install namespace is interoperability-enabled."
- Test connection (FR-27): "reports success with the model's reply, or the provider's error text"; "uses the definition as edited, before save"; reply truncated; link-local endpoints refused, loopback/private allowed.
- Gate (FR-28): admin "is taken to agent configuration and may leave it; a persistent banner in the panel reminds them on every screen until one definition is enabled." Non-admins: "only the panel is in its empty state, naming who can configure it."
- Admin privilege (FR-29): every switch/definition change audited with old and new values.

### (e) Per-area behaviors
- **Web apps:** "Save writes through the admin API and the list reflects the change without a manual refresh"; create "opens the new application's editor on success"; "Delete asks for confirmation naming the application; enable and disable act immediately and the row updates"; "Deleting OcuPilot's own web applications is refused with an explanation"; explorer "links each entry to its document view"; refused documents "show that refusal rather than an empty view."
- **Permissions:** create user → "the new user opens in the editor"; "Each action is available from the list row and the editor and updates the row in place"; "Disabling or deleting the current user is refused with an explanation"; grant editing "shows the current grant and the result"; "Deleting a role that is granted to users warns with the count first"; "System resources are shown but not deletable"; disabling OcuPilot's web service "warns before proceeding, since it locks the user out."
- **Security:** private keys never returned; X.509 list shows subject, issuer, validity; OAuth lists link to the classic editor per entry; "Delete asks for confirmation naming the entry"; wallet "Secret values are write-only"; wallet screen disabled without its resource (FR-4 pattern); "Disabling auditing warns that agent writes will no longer be marked in the audit database, and the agent never proposes disabling auditing ... without that warning in the proposal card."
- **Tasks:** schedule shows last and next run; upcoming ordered by next run; history rows: start, end, status, error text, running user; details link to history and Edit; "Each action updates the task row in place; delete asks for confirmation naming the task"; "Suspending the Task Manager warns that no scheduled task will run until it is resumed"; edit shows wizard fields with current values.
- **OS:** "Terminate offers the optional error-to-job flag and asks for confirmation naming the process id"; "Acting on the user's own process is refused with an explanation"; lock owner "links to the process details"; lock removal "warns when the owning process is in a transaction"; database free-space "figures come from the asynchronous directory call and the screen shows them as they arrive."
- **Logs:** messages.log "never loads the whole file into the browser at once"; application errors "delete asks for confirmation naming the scope"; audit detail "shows the full event including its description and any JSON payload."

### (f) Polish week (FR-70..79)
- FR-70: "'Explain this screen' is a one-click action in the panel on every screen; the reply names the screen's purpose, the data shown and the actions available, and cites the read tool it used." Every log/audit entry gets an explain entry point sending "that entry, and only that entry". "Each screen offers at least three suggested prompts grouped by task; choosing one sends it as a turn."
- FR-71: "Every reply that used a read tool carries citation chips; clicking a chip selects the cited row or opens the cited screen." Data-egress line on every context-on turn. Agent audit viewer with user/screen/date filters.
- FR-72: "On any proposal the user can choose the script instead" (ObjectScript, CLI or REST snippet, no write). Governance policy per tool/action with read-only and full presets; disabled tool "stays advertised". Transcripts per user; admin opening another's is ledgered and gated by recorded resources.
- FR-73: change password, favorites, recents, menu search, About, per-screen Help, shortcuts menu, links panel, Home system information panel, UI state across sessions, "choose a light or dark theme"; "the theme choice persists."
- FR-74..78: try-it, web sessions, effective privileges, permission-check tool "answers yes or no with the granting role"; security tests/editors; task export/import, background tasks, broadcast, license usage, dashboard meter groups; secondary logs + hub; external language servers.
- §10.2 order: step-7 leftovers, then FR-70 and FR-71 "because voters see them", then OAuth editors, then bonuses; "Nothing in the polish week may break a Release 1 screen or a Release 1 agent write."

## 5. States the UI must represent

| State | Where | FR |
| --- | --- | --- |
| Silent login in progress / succeeded (no form) | shell on load | FR-1 |
| Form login (cold arrival, failed refresh, after sign-out); route preserved | shell | FR-1, FR-2 |
| Expired `_SYSTEM` password explanation with link to fix | form login | UJ-5 |
| Version mismatch / admin API absent (blocking, links to classic portal) | shell | FR-3 |
| No administrative privileges (sign-out link) | shell | FR-3, FR-65 |
| Privilege-hidden → shown **disabled with tooltip** naming required resource | nav, wallet screen | FR-4, FR-46 |
| Loading first page (≤ 2 s target, 1,000 rows) | lists | NFR-1 |
| Async values arriving (database free space) | Databases list | FR-58 |
| Empty result / refused document | OpenAPI viewer, lists | FR-34 |
| Error: instance unreachable vs request refused; 403 naming privilege; generic internal error | everywhere | FR-8 |
| Auto-refresh on/off, last-update stamp, paused under open proposal | lists | FR-7 |
| Stale data (refresh paused; highlights until next interaction) | lists/details | FR-7, FR-14 |
| Row/field highlighted after agent write (≤ 2 s) | lists/details | FR-14 |
| Off-screen change toast | shell | FR-14 |
| Panel: unconfigured (configuration-empty, names who can configure) | panel | FR-28 |
| Panel: admin reminder banner (gate bypassed) | panel | FR-28 |
| Panel: idle with context chip (on / off / "leaves the instance") | panel | FR-11 |
| Panel: agent busy — tool-call cards in order, first progress ≤ 10 s | panel | FR-12, NFR-1, NFR-2 |
| Panel: locked (second message refused, lock banner) | panel | FR-12 |
| Panel: error card (timeout, which step; provider unreachable/rate-limited after retries) | panel | FR-12, FR-23 |
| Panel: proposal live / confirmed / canceled / expired / target changed re-propose / blocked by read-only / governance-disabled (polish) | panel | FR-17, FR-19, FR-72 |
| Panel: destructive proposal awaiting typed name; secret masked input | panel | FR-17 |
| Panel: read-only (enforced, per-user, definition flag) — blocked result text, no card | panel | FR-19 |
| Panel: disabled by kill switch (with reason); in-flight turn stops | panel | FR-20 |
| Panel: "agent writes are not being marked" banner | panel | FR-22 |
| Panel: audit-emission failure on a tool-call card | panel | FR-22 |
| Panel: secret-like message warning before send | panel | FR-11 |
| Panel: agent announcing navigation | panel | FR-15 |
| Panel: transcript restored after reload (cards expired) | panel | FR-12, FR-17 |
| Token expired mid-turn / 60-second problem — must complete "without an authentication failure" | runtime | FR-18, OQ17, A§2 |
| Test connection: success with reply / provider error text; definition disabled until it passes | agent config | FR-27, FR-24 |
| Confirmation dialogs naming the target (delete, terminate, remove locks); warnings (role in use count, Task Manager suspend, auditing off, OcuPilot web service, own process) | area screens | FR-32, 37, 39, 41, 47, 51, 55, 57, 63 |
| Cut-editor reduced form with classic-portal link | area editors | FR-9 |
| Narrow viewport < ~900 px | shell + panel | FR-10 (UX decision) |

## 6. Voice, microcopy and language constraints

- **Fixed strings the PRD names:** "no administrative privileges on this instance" (FR-3); "blocked by read-only mode" (FR-19); "agent writes are not being marked" (FR-22); "target changed, re-propose" (FR-17); "leaves the instance" (FR-11); context chip example "Users, HSCUSTOM" (UJ-1); "Explain this screen" (FR-70); "Test connection", "Confirm", "Cancel", "Save", "Resume" as action names; "instance unreachable" / "request refused" (FR-8); expected-impact example "users holding %Development can reach the application" (UJ-3); audit description "marked as coming through the OcuPilot agent co-pilot" (UJ-3).
- **Agent text labeling:** rationale and expected impact are "labeled as the agent's text" (FR-17). The agent "announces where it is taking the user" (FR-15), "tells the user what it would have changed and on which screen" (FR-19), "says so instead of retrying" on 403 (UJ-3, FR-18), "cites that row rather than claiming success" (UJ-6).
- **Errors:** "one consistent message with the action to take" (FR-8); provider errors shown as "the provider's error text" (FR-27, UJ-2); privilege errors name the resource.
- **Confirmations:** delete/terminate/remove confirmations always name the target (application, entry, task, process id, scope); destructive proposals require typing the target's name "matching the screens' own delete confirmations" (FR-17); warnings carry consequences ("no scheduled task will run until it is resumed", "locks the user out of OcuPilot", "agent writes will no longer be marked").
- **Restraint:** copy-out draft instead of execution (FR-72); no batch approval (§7.1); the field's loudest complaints "irrelevance, unreliability, hallucination and 'too many steps'" (A§8).
- **Naming rules:** avoid sibling names (A§6 table): no `iris_*` tool prefix, no `IRIS_*` env vars, no `SessionAgent*` / `IRISCouch*`; OcuPilot uses `/ocupilot`, `/api/ocupilot`, package `OcuPilot`.
- **Glossary (§4, "Downstream documents must use these terms exactly"):** OcuPilot (the product: portal + OcuPilot API + agent runtime + installer, one IPM module) · classic portal (`/csp/sys/`) · instance (exactly one) · admin API (`/api/admin` v2, hidden) · OcuPilot API (own REST app) · area (six contest groups: Web applications and REST API explorer; Permissions; Security and secrets; Tasks; OS management; Logs) · screen (one route: list, detail, editor, wizard or viewer) · agent co-pilot (panel + agent + tools; never "co-pilot") · the panel (docked right of every screen) · the agent (LLM loop with tools) · agent definition (named instance-level config; one default) · provider (OpenAI, Anthropic, Google Gemini, OpenAI-compatible incl. local) · turn (one message through final reply) · conversation (per browser tab, continues across routes, one turn at a time) · transcript (stored per user) · screen context (route, namespace, selected entity, visible rows) · read tool (never writes) · write tool (always produces a proposal first) · proposal (card: target, before/after diff, rationale, expected impact) · confirmation (explicit approval bound to one proposal) · change event (entity type, id, action) · agent marker (fixed text in the IRIS audit description) · agent audit ledger (OcuPilot's own record of LLM/tool calls) · audit database (IRIS audit DB; distinct from the ledger) · read-only mode (instance-wide enforced or per user) · kill switch (global or per user; screens keep working) · OcuPilot administrator (holds the install-created resource) · first-login gate · silent login · form login · token pair · embedded editor (not R1) · catalog row · tier P0–P4 · size S/M/L · Release 1 · Stage 2–6 · cut line.

## 7. Non-functional and accessibility constraints

- **NFR-1:** list first page ≤ 2 s (1,000 rows, Community container); confirmed-write refresh ≤ 2 s; first visible progress of a turn ≤ 10 s against a current cloud model; local models may be slower (D11).
- **NFR-2:** per-step progress in Release 1; "No turn may appear frozen for longer than the interval between tool calls"; streaming Stage 5 (OQ14).
- **NFR-3/4/5:** token only as Bearer from per-tab storage; no caller SQL/path; secrets write-only, redacted everywhere.
- **NFR-6:** untrusted-content boundary — reply renderer makes no external request; navigation allow-listed; seeded-injection test (step 7).
- **NFR-7:** every agent write recoverable from audit DB by marker and from the ledger by turn.
- **NFR-10:** "The whole shell, panel included, loads with no reachable CDN, every library vendored in the bundle."
- **NFR-11:** Chrome desktop supported; Edge/Firefox/Safari best effort, untested.
- **NFR-12:** "Keyboard operation of every screen and of the panel, visible focus, and text contrast meeting WCAG 2.1 AA for the default theme; formal certification is not claimed." D10 confirms "WCAG 2.1 AA and keyboard as the accessibility floor".
- **NFR-13:** IRIS 2026.2+, Community and IRIS for Health Community. **NFR-14:** English only.
- **Dark mode:** FR-73 (polish) "choose a light or dark theme"; A§8 "Dark mode is a repeated community request and a polish-week row." No offline mode stated; no i18n (§9).
- **§7 items visible in UI:** tiered autonomy L0–L4 (A§4 table); context sharing on by default, toggleable; egress disclosure in chip; transcripts per user with retention; cost bounded by max tokens/iterations and per-user turn limits; Test connection minimal budget.
- **Latency of concern:** access token 60 s vs 90 s provider / 300 s gateway timeouts (A§2); Web Gateway timeout is an install prerequisite the installer reports (FR-23).

## 8. Owner decisions that bind UX (A§1) — [UI] marks direct UI impact

1. Agent configuration instance-level and shared; one key per provider, never shown back. [UI]
2. Switches: admin (kill switch, enforced read-only) plus per-user read-only toggle in the panel (toggle deferred to step 7 by D22). [UI]
3. Journeys drafted with named protagonists, owner-confirmed.
4. PRD plans through parity (Stages 2–6).
5. Catalog sizing authoritative (12 large P0 rows).
6. Logo: web PNG at 360 px, README convention. [UI]
7. Streaming stays last (Stage 5); OQ14 may pull it forward.
8. Analytics rides on Stage 4.
9. No agent picker in Release 1; default definition used. [UI]
10. Assumptions confirmed: disabled-with-tooltip gating; refresh pauses under an open proposal; all tools advertised, gated at call time; installer reports gateway timeout; self-protection of OcuPilot's apps; warnings on disabling the web service and auditing; untrusted-content boundary; WCAG 2.1 AA + keyboard floor. [UI]
11. Responsiveness: 10 s first progress, 2 s screen targets. [UI]
12. Browsers: Chrome supported; others best effort. [UI]
13. Platform floor IRIS 2026.2.
14. Transcript visibility: users their own, admins every user's. [UI]
15. Usage analytics / token metering (CP-28) → Stage 2; ledger still captures usage.
16. Reconciliation with brief: server-side confirmation in R1; kill switch off by default; unconfigured state is separate from the kill switch; daily improvement over the voting week; alerts.log tail kept. [UI]
17. Reconciliation with idea/README: agent is the main editing conduit; cut editors still get write tools; per-definition read-only flag and retention period; install to `HSCUSTOM` else `USER`; MIT.
18. Reconciliation with research: long turns survive the 60 s token (mechanism open); admin API authorizes by `%Admin_*` only; no claim that OcuPilot login signs in the classic portal (OQ15); agent marker is OcuPilot's own event; proposal card shows reversal. [UI]
19. Reconciliation with catalog: write tools for every write incl. deletes on read-tagged rows; app error log delete is the Logs area's SM-3 write; REST path `/api/ocupilot`.
20. First-login gate is bypassable with a persistent reminder banner; DC article and online demo optional. [UI]
21. Agent-safety review folded in: server-minted/single-use/expiring proposals, secret fields masked at confirmation, typed name for destructive tools, no remote resources in replies, allow-listed navigation, provider/host disclosure in R1 context chip, loopback/private endpoints allowed. [UI]
22. Build order is the cut line; trims to step 7: per-user read-only toggle; OpenAI/Gemini/OpenAI-compatible adapters (Release 1 starts Anthropic-only); fingerprint re-read, typed-name confirmation, per-user turn limits, seeded-injection test. Navigation tools stay in the floor. OAuth 2.0 editors polish week ("OAuth setup absent at the deadline" risk accepted). No local-model Compose profile, no hosted demo; article and video optional. [UI]

**Trims recorded in the PRD (§1.1, §10.1, §11):** demo video optional; judge without a key sees screenshots in the README walkthrough; no hosted demo; Anthropic only in the floor; read-only toggle step 7; OAuth editors polish week; SM-C3 "Do not start a P1 item while any cut-line step 1 or 2 item is unfinished."

## 9. Build order and cut line (§10.1)

| Step | Delivers (screens) |
| --- | --- |
| 0 | Shell and install: sign-in, navigation, page chrome, error handling, version guard, IPM, Docker, installer, API skeleton |
| 1 | Header/shell reads + one live list per area with read tool; messages.log and application error log endpoints |
| 2 | Agent co-pilot core: panel, turns with progress, proposal lifecycle (floor form), agent marker, Anthropic, agent configuration + first-login gate, enforced read-only + kill switch (switches screen), screen sync + navigation; one confirmed write per area; demo fixtures. **SM-3 met here.** |
| 3 | Remaining list and detail screens with read tools |
| 4 | Remaining small write actions: enable/disable/run/suspend/resume/terminate/delete, auditing on/off, OAuth deletes, on-demand run, app error deletes (FR-32, 37, 44, 47, 48, 51, 55, 57, 63) |
| 5 | Medium editors: web app create, user and role create, resource, device, wallet editors, X.509 import, audit event configuration (FR-31, 36, 39, 40, 43, 46, 47, 59) |
| 6 | Large editors in order: user edit, web application edit, then role edit, service edit, SSL/TLS, LDAP, task wizard, edit task (FR-35, 30, 38, 41, 42, 45, 52, 53) |
| 7 | Stretch: other provider adapters (FR-25); per-user read-only toggle (FR-19); fingerprint re-read, typed-name confirmation, per-user turn limits, seeded-injection test |

**Dates:** 2026-09-09 OQ17 transport + export endpoint classes · 09-10 install path proven · 09-11 legacy CSP pages pulled; README tagged · 09-12 OQ15/16 tested · 09-13 gateway timeout proven · **listing build, undated** (steps 0–1 + README; panel read-only Q&A if step 2 begun, else configuration-empty state) · **2026-09-23 demo freeze** (anything touching UJ-3 after it forces redo of description/video) · **2026-09-24 release target** (repository made public, listing created, application submitted; three days of buffer before the deadline) · **2026-09-27 application floor** (steps 0–4 complete; ≥1 create/edit form per area from step 5; no list links out; SM-3; UJ-3 reproducible on clean install) · **polish week 2026-09-28 to 2026-10-04** (61 P1 rows; one visible change per day; three days reserved for feedback).

**Owner's stealth decision, 2026-09-09 — supersedes the dated submission plan above.** Nothing is published before the release, which targets **2026-09-24**: the repository stays **private**, the Open Exchange listing is not created early, and no bonus item — Developer Community article, YouTube video or short, Ideas Portal idea — appears before then. The former "09-11 idea posted" and "09-12 listing submitted" steps are withdrawn, and the listing build stops being a calendar gate and becomes a readiness bar the build simply waits at. The reason is idea protection: the always-on co-pilot is the entry's differentiator and the most copyable thing about it. The target is 09-24 rather than the deadline because Open Exchange approval is discretionary and not instantaneous. **UX consequences:** UJ-5's entry state — "On the Open Exchange listing" — does not exist until 2026-09-24, so the judge-facing surface has three days rather than thirteen to be found before the deadline; and "visible improvement" moves almost entirely into the voting week. Recorded in full in `epics.md`, Epic 17.

## 10. Open questions and assumptions touching UX (§12, §13)

- **OQ17 (due 2026-09-09):** tools in-process under the user's session vs over HTTP with the user's token. Settles FR-18's 60-second token problem, "the progress channel" (A§3: "polling or server-sent events so the panel can render tool-call cards while a turn runs") and the cost of write tools. Affects how live the tool-call cards can be.
- **OQ15 (test by 2026-09-12):** does form login sign the browser into the classic portal, and does sign-out end it? Affects FR-9 link-out expectations and the sign-out message.
- **OQ16:** plain IRIS Community (`USER` namespace) — affects whether the IRIS-credentials rung appears in the config form (FR-26).
- **OQ7 (2026-09-11):** field lists for the task wizard, edit task, dashboard meters, messages.log, app error log, auditing page, system usage, task action pages come from legacy CSP source. Form layouts for FR-52/53/56 unknown until pulled.
- **OQ4/OQ6:** X.509, messages.log, app-error backing classes; endpoint schemas exported 2026-09-09 — drive form field sets.
- **OQ5:** install at build vs start — no UI impact beyond README.
- **OQ14 (Stage 2 planning):** streaming pull-forward; R1 is per-step progress only (NFR-2).
- **OQ1/2/3/10/12:** contest bonuses, partial coverage, vendor stance, Freshmen, winners date — no direct UI impact. **Closed 2026-09-09 from the live contest pages:** partial coverage (the task text lists the six areas and then invites "add any *other* screens", so all six are the baseline) and Freshmen (two stated conditions — no more than five previous contests *and* never having placed top three — with no opt-in and nothing to do). **Still live:** the bonus list, joined by a new question of whether a bonus item published during the voting week still counts, both at the 2026-09-14 kick-off; the vendor stance on `/api/admin`, now asked by private direct message rather than on a public contest thread; and the winners date.
- §13: "No open assumptions remain."

## 11. Explicit look-and-feel statements (verbatim, complete)

- §1: "a panel docked on the right of every screen, present on every route".
- §5.2: "The panel is docked on the right of every screen like VS Code's secondary side bar. It is present on every route, is never dismissed by navigation, resizes, and can go full screen."
- FR-10: "The panel has a minimum width and a remembered width per browser; screen content reflows to the remaining width." / "There is no close control in Release 1. Narrow-viewport behavior below about 900 px is a UX decision, not a requirement here."
- A§8: "Narrow-viewport behavior of the panel below about 900 px (bottom sheet or overlay) is a UX decision."
- A§8: "Theming: vendor bundles have fixed theming (Tailwind and Material tokens, Noto Sans) and no license text; reference in place, never copy. iris-table-editor's `--ite-*` token layer is the theme bridge candidate. Dark mode is a repeated community request and a polish-week row."
- A§8 harvestable UI details: "the config-empty state; the per-conversation lock banner; citation chips; the vendored Markdown pipeline; the 8,192-character system-prompt counter."
- A§8 interaction vocabulary from the field survey: "Persistent side panel with full-screen toggle; page-context sharing on by default and toggleable; draft-first copy-out artifacts; propose, review, confirm with rationale and expected impact; 'Investigate' entry points on alerts and log entries; pre-populated hand-off forms; an agent picker inside the chat; citations back to the rows used; suggested prompts grouped by task; inline contextual insights beside errors; chat history with a retention policy." Open ground: "undo and rollback UI, visual diffs before apply, slash commands, streaming."
- D6: "Logo. The web-optimized PNG at 360 px wide, the same convention as the README".
- FR-4: "shown disabled with a tooltip naming the required resource, not hidden."; "a category selector and a finder view".
- FR-6: "a locator bar and a per-page command bar".
- FR-13: "external links are rendered inert with the full host visible".
- FR-14: "highlights the changed row or field within two seconds"; "Highlights clear on the next user interaction"; "a toast names the change".
- FR-17: "a masked input"; "type the target's name in the card".
- FR-34: "a path-and-verb browser".
- UJ-1: 'the screen context chip "Users, HSCUSTOM"'.
- NFR-12: "visible focus, and text contrast meeting WCAG 2.1 AA for the default theme".
- FR-73: "choose a light or dark theme".
- A§7 classic header conventions "users expect": "server, namespace with switch link, user with change-password link, escalation role, licensed-to, instance, a Live / Test / Failover / Development badge; a small menu of Home, About, Help, Contact, Logout; a fixed 16-link menu filtered by access; breadcrumbs; per-page ribbon; favorites and recents; 'Did you know'; menu-only search; About with 14 fields; Help opening DocBook per page."

No statements exist about color, typography, spacing, iconography, density or motion beyond the above.

## 12. Gaps for UX to decide

**DESIGN.md (visual system) — nothing specified for:**
- Color palette (primary, semantic success/warning/danger, agent-vs-human distinction, highlight color for changed rows/fields, "leaves the instance" emphasis), light theme first and dark theme later (FR-73).
- Typography (no font named; vendor's Noto Sans is reference-only), type scale, code font for Markdown/code highlighting and log viewers.
- Spacing, density (admin tables with 1,000 rows, log viewers), radii, elevation, borders.
- Iconography set (none named); logo placement and size in the header; favicon.
- Panel dimensions: minimum width, default width, full-screen mode, resize handle; the < 900 px behavior (bottom sheet vs overlay).
- Component visuals: proposal card, tool-call card, error card, context chip, lock banner, reminder banner, "not being marked" banner, disabled panel state, configuration-empty state, citation chips, toast, locator bar, command bar, category selector + finder, header strip, server-flag badge, auto-refresh controls, confirmation dialogs, typed-name confirmation, masked secret input, before/after diff rendering, OpenAPI path-and-verb browser, log viewer with highlight/tail, dashboard meters.
- Focus-visible style and contrast targets per token (NFR-12).

**EXPERIENCE.md (behavior) — nothing specified for:**
- Information architecture: order and grouping of the six areas, screen names inside each area, what "category selector" and "finder view" are, Home content in Release 1, where the switches screen and agent configuration sit in navigation, where the audit database viewer lives (Logs vs Security — catalog LG-02 = SS-14).
- Panel interaction primitives: how a turn is sent (Enter/Shift+Enter), how progress cards collapse/expand, how citations look and behave in Release 1 (UJ-1 expects click-to-select; FR-71 places chips in polish week), how multiple proposals in one turn are laid out, how the context toggle and read-only toggle are presented, how the chip shows provider/host.
- Proposal card flow: Confirm/Cancel placement, expiry countdown or not, expired-card look, "target changed, re-propose" affordance, reversal text placement, destructive typed-name flow, secret masked-input flow.
- Screen-sync details: highlight duration, toast persistence and stacking, selection behavior after agent navigation, undo via browser back messaging.
- Error/voice: exact copy for every named state (mismatch, no privileges, unreachable vs refused, lock banner, read-only refusal, kill-switch reason, gate banner, expired password), tone of agent rationale labels.
- First-login gate flow layout; Test connection result presentation; provider cascade UX; key entry once-only affordance.
- List conventions: filter/sort/search placement, pagination vs max rows, row actions vs command bar, selection model, persisted state UI.
- Editor conventions: tabs vs sections for large editors (user, web app, SSL, LDAP), reduced-form + classic link layout (FR-9), wizard step model for the task wizard, unsaved-changes handling.
- Keyboard model for the panel and grids (NFR-12), focus order between screen and panel, shortcuts (A§8 lists slash commands as open ground).
- Accessibility specifics: ARIA live regions for progress/toasts/highlights, announcements for agent navigation.
- Loading/skeleton and auto-refresh visual behavior; how async database free-space "arrives".
- Polish-week placement of "Explain this screen", suggested prompts, explain entry points on log rows, copy-out script option, egress line, theme switch.

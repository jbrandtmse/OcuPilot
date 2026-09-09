---
review: feasibility
target: ARCHITECTURE-SPINE.md
project: OcuPilot
reviewer: architecture feasibility lens
date: '2026-09-09'
context: 'One solo developer. Listing build 2026-09-14. Contest floor 2026-09-27. PRD feasibility budget: ~46 developer-days specified against 19 available. Full scope is the owner''s standing decision; this review does not recommend cuts.'
verdict: 'Net positive and material — roughly 9 to 11 days off the 46 as written, 12 to 14 with the corrections below. But two of the three headline savings rest on a single probe of a single endpoint, one is overstated by about half for Release 1, and three decisions are timed to land earlier than the build order needs them.'
---

# Feasibility review — ARCHITECTURE-SPINE.md

## 0. Verdict

The spine makes 2026-09-27 **more** reachable, and by a margin that matters: roughly **9 to 11 developer-days** off the PRD's 46-day estimate as the spine is written, and **12 to 14** if the five corrections in §6 are applied. On the floor arithmetic that is the difference between "24 to 26 days against 19, closes only with the reserve spent" and roughly **19 to 22 against 19** — the first version of this budget that touches the available days.

It does not get there for free. Three specific problems:

1. **AD-3's claim is half true and is stated in a way that will stall the builder.** Verified on the running instance: `RequestBodySchema()` exists on **21 of 70** endpoint classes, not all of them, and is **not on the base class at all**. Counting all four naming conventions the vendor actually uses, **40 of 50 mutating endpoints** publish a field template; **10 publish nothing**, two of which are Release 1 rows.
2. **AD-5, AD-9 and AD-22 are each timed to land before the build step that needs them**, which is exactly the property the owner's incremental build order was designed to prevent.
3. **The single missing decision is OcuPilot's own authentication.** The spine names Bearer zero times and CSPBrowserId zero times. It is step-0 work, due in the 2026-09-14 listing build, and the addendum already contains the answer.

Everything below is evidenced against the running `ocupilot` container (IRIS for Health 2026.2 build 221U) or against the four harvest maps.

---

## 1. Decisions that REDUCE the estimate

### AD-1 + AD-2 — in-process tools calling the vendor's own endpoint objects · **saves ≈ 3.5 to 4.5 days** · confidence **high**

This is the strongest decision in the document and the claim survives scrutiny.

**Verified independently.** `%Api.Admin.Endpoint` is a plain `%RegisteredObject` (marked `[ Hidden ]`). `%Api.Admin.Dispatch.v1:Main()` at line 1485 of 1662 is a ~90-line wrapper whose whole body is: `ResourcesOR()` → `$SYSTEM.Security.Check(res,"U")` per entry → content-type check → `SaveQueryParams()` → `ValidateQueryParams()` → body parse → `ValidateRequest()` → `ValidateSemantics()` → async branch → `BeginCaptureOutput` → `Run(.sc, requestBody)` → `EndCaptureOutput` → `RenderResponseBody`. There is genuinely nothing else in the HTTP path. Re-implementing that once in `AdminPort` is 150–250 lines plus tests.

**What it removes from the budget.** The 60 s access-token versus 90 s turn mismatch and its refresh path (addendum §2 lists this as the open decision behind OQ17); a per-tool HTTP client and its error taxonomy; the "probe one write per family" line; and the marshalling cost inside the budget's "Plain list screens (about 22) with generated read tools · 3.0 d" and "Small write actions (about 20) end to end · 3.0 d". Against a budget that assumed HTTP tools carrying the user's token, this is **3.5 to 4.5 days**.

**What it costs.** `AdminPort` itself, plus two things the spine's stated sequence omits — see §3.2. Call it 1 day, already netted into the figure above.

**Two claims in AD-2 that are wrong as written, and should be corrected rather than deleted.**

*"All 70 endpoint classes are free of `%request` / `%response` references."* False. Five subclasses reference them:

| Class | Refs | Release 1? |
| --- | --- | --- |
| `%Api.Admin.Endpoints.Database.AsyncTaskSysBackground` | 6 | no |
| `%Api.Admin.Endpoints.Database.Actions` | 3 | no |
| `%Api.Admin.Endpoints.Security.Encryption.Settings` | 2 | no |
| `%Api.Admin.Endpoints.Journal.Record` | 1 | no |
| **`%Api.Admin.Endpoints.Security.Audit.Record`** | **1** | **yes — FR-61 / LG-04 / SS-14** |

The base class also touches them, in `SaveQueryParams()`, `NormalizeLocationHeader()`, `SetRespStatus()` and `SetRespHeader()` — the last two guarded by `If '..IsRunningAsync`, which is precisely why `IsRunningAsync = 1` works. The **decision** survives at 65 of 70 clean. The **invariant as stated** does not, and a builder who trusts it will not write the test that catches the one Release 1 exception.

*The undocumented-surface risk should be stated.* `/api/admin` is, by this project's own reference-folders rule, "neither in the `%SYS` export nor in the documentation index; treat it as undocumented/internal". NFR-8 pins the admin API to **v2 at the route level**; AD-2 binds OcuPilot to **class-internal method names** (`Run`, `ValidateRequest`, `ValidateSemantics`, `ResourcesOR`, `SaveOneQueryParam`, `IsRunningAsync`) that no published contract covers. This is an acceptable bet — the alternative is reimplementing 70 endpoints — and the architecture already confines it correctly to one file. It should be named as an accepted risk in AD-2 so that a version bump has an obvious blast radius.

### AD-3 — write payload schemas generated, never authored · **saves ≈ 2 to 2.5 days, not the ~4 the wording implies** · confidence **medium**

The memlog resolved this from one probe: `%Api.Admin.Endpoints.WebApp.App` PUT → 45 fields. That endpoint is one of the 21 that happens to have the method. Generalising from it produced the claim "every endpoint publishes `RequestBodySchema()`". Measured across all 70:

| Schema method | Classes |
| --- | --- |
| `RequestBodySchema` | 21 |
| `PutRequestBodySchema` | 17 |
| `PutAndPostSchema` | 1 (`Task.CRUD`) |
| `Schema` | 1 (`Security.User`) |
| **none** | the remaining 31 (10 of which mutate) |

`RequestBodySchema` **is not declared on `%Api.Admin.Endpoint`**. There is no base-class contract, no default, no compile-time guarantee — it is an ad-hoc convention that the vendor applied under four names.

**Of the 50 classes that define `RunPut` or `RunPost`, 40 publish some template and 10 publish none:**

`FSAccess.Path`, `FSAccess.Purpose`, **`Security.Audit.Event`**, `Security.Encryption.AdminInFile`, `Security.Encryption.File`, `Security.Encryption.KeyInFile`, `Security.SQLPrivilege.Admin`, `Security.SQLPrivilege.Column`, `Security.SQLPrivilege.Standard`, **`Wallet.Secret`**.

The two in bold are Release 1: `Security.Audit.Event` backs FR-47 (audit event configuration, build step 5) and `Wallet.Secret` backs FR-46 (wallet editor, build step 5) — and the PRD already flagged wallet as having "no SMP page, no MCP tool, no observed payloads".

**What is returned is not a JSON Schema.** `Task.CRUD:PutAndPostSchema()` returns a prototype object of placeholder values:

```
{ "Name": "", "RunAsUser": "", "EmailOnCompletion": [""], "EmailOutput": true,
  "Expires": true, "ExpiresDays": "", "Priority": "", "TaskClass": "",
  "IsBatch": true, // this isn't editable in smp?
  "NameSpace": "", // just be careful of spelling
  ... }
```

Field names and coarse types by implication (`""` string, `true` boolean, `[""]` array-of-string). No `required`, no `enum`, no `description`, no bounds — and the vendor's own TODO comments in it confirm it is an internal convenience, not a contract. The real constraints live in each class's `ValidateRequest()` (53 overrides). `Security.User:Schema()` behaves identically and `UpdateUser` iterates it with `json.%IsDefined(key)` — which is also a second confirmation of AD-4's get-merge-put finding on a different family.

**Consequence for the LLM-facing tool schema.** The harvest map's own locked cross-vendor subset needs `description` on every property (`iris-execute-mcp-v2` stresses that `.describe()` text "becomes the JSON-Schema descriptions the LLM reads"). Generation gives you field names and types for free; descriptions, enums and required-ness are still authored. That is real work AD-3 currently reads as eliminated.

**Release 1 write families and their actual schema source:**

| FR / step | Endpoint | Schema method |
| --- | --- | --- |
| FR-30/31 web app (step 6, 5) | `WebApp.App` | `RequestBodySchema` |
| FR-35 user edit (step 6, first Large) | `Security.User` | **`Schema`** |
| FR-38 role edit / FR-39 resource | `Security.Role`, `Security.Resource` | `PutRequestBodySchema` |
| FR-41 service / FR-42 SSL / FR-45 LDAP | `Security.Service`, `.SSLConfig`, `.LDAP` | `PutRequestBodySchema` |
| FR-43 X.509 (step 5) | `Security.X509Credential` | `RequestBodySchema` |
| FR-44 OAuth2 deletes (step 4) | six `Security.OAuth2.*` | `PutRequestBodySchema` |
| FR-46 wallet (step 5) | `Wallet.Collection` / **`Wallet.Secret`** | `RequestBodySchema` / **none** |
| FR-47 auditing on-off / event config (steps 4, 5) | `Security.Audit.Enabled` / **`Security.Audit.Event`** | `RequestBodySchema` / **none** |
| FR-52/53 task wizard + edit (step 6, two Large) | `Task.CRUD` | **`PutAndPostSchema`** |

**Rewrite AD-3 as:** the generator resolves the endpoint's schema by probing, in order, `RequestBodySchema`, `PutRequestBodySchema`, `PutAndPostSchema`, `Schema`; where none exists the tool's field list is hand-authored **and the story carries an instance payload probe as its first task**. Cost of the fix now: **~0.5 day**. Cost of discovering it story-by-story in step 5: a day of churn plus the risk that FR-46 and FR-47 are the rows that get cut.

**One safety net AD-3 currently deletes and should not, entirely.** Addendum §3 mandates "exercise the payload on the instance" as the first task of every write story, and AD-3's Prevents line explicitly removes it. For the 40 with a template that is a fair trade. For the 10 without — and specifically for `Wallet.Secret` and `Security.Audit.Event` — the probe is the only thing standing between the builder and an unverified contract on a P0 row.

### Reductions the spine does not claim but earns

- **AD-4, send only changed fields · ≈ 0.5 to 1 day.** Verified twice (`WebApp.App:RunPut` via `MergeJsonAndProperties`; `Security.User:UpdateUser` via `%IsDefined` per schema key). Beyond the stated benefit it is what makes FR-9 real — a cut Large editor still gets a working write tool as a partial PUT, which is the mechanism the build order relies on when a step becomes the cut.
- **AD-23, the `RenderResponseBody` seam · ≈ 0.5 day in Release 1, several days in Stage 5.** 738 call sites, one signature, zero edits. Only the two log endpoints need it before 2026-09-27, so the in-window saving is modest; it is correctly scoped as mostly Stage 5.
- **AD-12, AD-13, AD-16, AD-21 and the Consistency Conventions table · ≈ 1.5 to 2 days of avoided debugging, at essentially zero cost to state.** These are harvested from bugs the sibling repos actually shipped — iris-couch's `}{` double envelope from a bare `Quit` in a nested `Catch` (fixed at 7 sites), the `%EXACT()`-renames-the-column trap, the `$Char(0)` sentinel, the hashed-global name overflow (`^IRISCouch.Proje4479.MangoIndexD`, `^SessionAgenC88B.*`). Each is a half-day of solo debugging that now does not happen. This is the quiet best value in the document.

**Subtotal, decisions that reduce: ≈ 9 to 11 days** (AD-1/2 3.5–4.5, AD-3 2–2.5, AD-4 0.5–1, AD-23 0.5, conventions 1.5–2), taking "as specified" from 46 to roughly **35 to 37 against 19**.

---

## 2. Decisions that ADD cost — and whether each is worth it before 2026-09-27

### AD-5 — the screen descriptor machinery · **costs ≈ 6 days ± 2** · verdict: **keep the idea, stage the delivery**

**Is building the generator cheaper than writing 60 screens by hand?** Marginally, and only if it works first time.

Build cost, itemised: descriptor class model and registry 0.5 d; route and nav derivation on the Angular side 0.5 d; read-tool generation and dispatch 1.0 d; write-tool schema generation across the four vendor method names, with narrowing and secret-field marking 1.5 d; context serializer and change-event key 0.5 d; the ObjectScript→TypeScript mirror and its build wiring 1.0 d; debugging the generator across the first five screens 1.0 d. **≈ 6 days**, and codegen debugging is the classic solo-developer time sink, so ±2 is honest.

Hand-written comparison, after three screens establish the pattern: a plain list screen (page + store + route line + nav line + read tool) ≈ 0.3–0.4 d; a detail ≈ 0.5 d.

**Break-even.** Note the budget's 22 list screens in 3.0 days is 0.14 d each — that figure *already assumes* generation (the PRD says so: "the sizing of CP-12 and CP-13 rests on this"). So the honest comparison is generator (6 + 22×0.14 = 9.1 d) versus hand (22×0.35 = 7.7 d) **for lists alone — the generator loses**. It only wins once the derived-artifact count is counted: ~7 artifacts per screen (route, nav entry, privilege gate, read tool, write tools, context serializer, change-event key). On that basis break-even is **≈ 28 to 32 screens if the generator works first time, ≈ 45+ at the pessimistic end**. The six areas hold ~50 screens on the budget's own decomposition (22 lists + 10 details + 10 medium + 8 large). **AD-5 is above break-even, but only just.**

**The thing that pushes it below break-even is non-uniformity, and AD-5 does not address it.** The word "archetype" appears exactly once in the spine, as an undefined descriptor field. The six areas contain at least five screens that no generic archetype will cover: the REST API explorer with try-it (WA), the System Dashboard meter groups (OS), the two log tails with byte-offset paging (LG), and the task wizard (TM). Each escape hatch is a screen the generator does not save and a branch it does add.

**The real problem is timing, not total.** The generator must exist before build step 1 (one live list per area), and step 1 is due in the **2026-09-14 listing build** — five days from now, alongside all of step 0 (shell, sign-in, install path, Docker, installer, REST skeleton), which the budget puts at 5.5 days on its own. Step 0 plus a 6-day generator does not fit in five days, and a half-built generator is precisely the "half-built step" the owner's build order exists to prevent.

**Recommendation (sequencing, not scope).** Keep "one descriptor is the source of everything" as the invariant. Land it in three passes:
- **Step 1:** the descriptor **class** exists and is hand-consumed. Route, nav and read tool are written by hand *from* it. One place to be consistent in, zero codegen.
- **Steps 2–3:** derive route, nav, privilege gate and read tool from the registry. This is where the 22 lists arrive and where the generator pays.
- **Step 4:** derive write-tool schemas (the four-name resolver from §1).

That preserves every consistency property AD-5 claims, keeps the listing build achievable, and means any step can still be the cut with nothing half-built.

**Also unstated and needed on day one:** how the TypeScript mirror is produced — a build-time emitter from the class, or a runtime `GET /api/ocupilot/descriptors` the shell consumes. That is a build-tooling decision, not a detail, and it gates the Angular workspace setup.

### AD-9 — protected state via a privileged routine application · **costs ≈ 2 to 2.5 days** · verdict: **keep, but split it across steps 0 and 2**

**The mechanism is sound — better than the spine claims.** `Security.Applications.Routines` documents its format as `Routine/Class:dbname:Flag`, where "**Flag=0 is a routine, Flag=1 is a class name**". So the privileged application can name OcuPilot's storage **classes** directly; the trap I expected — having to list compiler-generated `.INT` routine names that change on every recompile — does not apply. Combined with the memlog's proven `New $ROLES` containment, AD-9 works as described.

**Cost.** A dedicated database created at install, a dedicated resource, a role, global and package mappings, the privileged routine application, and the storage base class. Note that **neither sibling installer does this**: iris-couch's harvest lists "Dedicated database ❌ (operator must pre-create) / Dedicated resource (`%DB_*`) ❌ / mappings ❌". So this is new work, in the 2.5-day low-confidence packaging line. **≈ 2 to 2.5 days.**

**A coupling the spine misses.** The privileged application's `Routines` list is a **third consumer of AD-17's generated roster**, alongside the installer's compile list and `module.xml`. Add a storage class without regenerating that list and escalation fails silently at runtime — the same class of failure AD-17 was written to prevent for the other two consumers. AD-17 should say the roster feeds all three.

**Why split it.** FR-29's acceptance test is: a holder of `%DB_<ns>:RW` plus `%Admin_Operate`, without the OcuPilot resource, can neither read nor write any OcuPilot table or global. **The database + resource + mappings half satisfies that test on its own.** The escalation half only becomes necessary when OcuPilot's own code must reach the protected data — which is step 2, when agent definitions, the ledger and proposals first exist. As written AD-9 reads as one indivisible day-one item and pushes ~1.5 days of escalation plumbing into the week the listing build is due.

- **Step 0 (≈ 1 d):** database, resource, role, mappings. FR-29 demonstrable.
- **Step 2 (≈ 1 to 1.5 d):** the privileged routine application and the storage base class.

### AD-22 — governance on the instance · **costs ≈ 2.5 to 3 days** · verdict: **right in substance, wrong in timing; reduce the Release 1 obligation to ~0.25 day**

The PRD puts governance squarely in the **polish week** (FR-72, CP-33, 2026-09-28 onward). AD-22 quietly drags part of it forward: it requires "a frozen baseline captured at the Release 1 freeze", which means the baseline generator and the key-derivation shared between generator and gate must exist **before 2026-09-27** — inside the contest window.

**Port cost.** The source is 100% TypeScript with zero IRIS dependency: `governance.ts` 1,045 lines, `governance-baseline-derivation.ts` 131, `baseline-classifications.ts` 243, the gate in `server-base.ts` 1373–1456, plus a 1,555-line CLI. An honest ObjectScript port of the engine, the four-layer `??` cascade, the read-only preset and the call-time gate is **2.5 to 3 days** — and not one hour of it is visible to a judge or a voter during the week SM-3 is due.

**What Release 1 actually needs** is already specified elsewhere: enforced instance-wide read-only (FR-19, step 2) and the kill switch (FR-20, step 2). Those are two flags evaluated at the same chokepoint, not a policy engine.

**Recommendation.** Reduce AD-22's Release 1 obligation to two properties that cost ~0.25 day and make a later baseline capture mechanical:
1. The tool dispatcher has **exactly one** gate point, after argument resolution and before the tool body runs.
2. Every tool declares `mutates` (`read` | `write`) at registration, enforced at registration time — the `assertGovernanceClassification` idea, which is one guard.

The frozen baseline, the cascade, the presets and the `GOVERNANCE_DISABLED` envelope stay in the polish week where the PRD put them. Say this in AD-22 explicitly, or a builder reads "governance runs on the instance, defaults new writes to disabled, and fails safe" as step-2 work and spends three days on it.

### AD-17 — one installer, generated roster · **costs ≈ 0.5 day** · verdict: **highest value-per-day decision in the spine; keep and do it in step 0**

Both sibling projects shipped a broken manifest, and the harvest documents both failures precisely: iris-execute-mcp-v2's `ipm/module.xml` lists **13** production classes while the bootstrap embeds **29** (missing `REST.Base`, `REST.Health`, all 7 `Diagram.*`, all 3 `Loc.*`), so "an IPM install today would fail to compile", and it drifted because the project's own rule listing required rosters omitted the manifest. iris-couch's `module.xml` has no `<Invoke>`, no `<CSPApplication>` and no UI-dist resource, so "a ZPM install only compiles classes and never creates the web app".

The IPM path **is** the Open Exchange listing's install path (FR-64, SM-2). A broken manifest on 2026-09-14 is a listing that does not install, on the day the listing is the deliverable. Half a day to generate the roster and emit both consumers (three, per AD-9 above) is the cheapest insurance in the document.

**One gap.** AD-17 says roster and manifest come from one source but never says the manifest is **tested**. iris-couch's `InstallerTest.TestInstallIdempotent` asserts idempotency; nothing in either sibling asserts the manifest actually installs. FR-66's smoke script already exists — add "a clean-container IPM install is part of the smoke script". That is a line, not a day.

### AD-7 — the turn runs in a background job · **costs ≈ 1 to 1.5 days, and buys back at least as much** · verdict: **keep**

Cost against the synchronous alternative (~0.5 d): the job, the progress protocol, the polling endpoint, the stop flag, cleanup. So **+0.5 to 1 day** of direct cost.

What it buys:
- **It removes the Web Gateway 300 s timeout from the install prerequisites.** FR-23 and addendum §6 both carry that timeout as a prerequisite the installer must report, and PRD §10.1 dedicates a dated first-week slot — 2026-09-13 — to "the Web Gateway timeout set in the image and proven with a turn longer than 60 seconds". With no request held open, that dated task and its README caveat largely evaporate. That alone is worth ~0.5 day plus a risk item.
- Stop becomes a flag the job checks between steps, rather than a cancellation problem.
- A turn survives a browser reload — which matters on demo day, because SM-4's one-minute demo runs on a stranger's machine.

Net: **roughly cost-neutral, possibly +0.5 day saved**, and it retires a dated risk. Correct call.

**Under-specified detail worth a paragraph now.** The spine says the job "writes per-step progress to a temp global keyed by turn id" and stops there. Unstated: the key shape, the size bound, who purges it, and what happens to a job whose parent request has gone. A process-private global cannot cross the job boundary, so this must be a real global with a purge task — and an unbounded progress global on a long turn is exactly the kind of thing that is found on 2026-09-26. Half a day if discovered late; three sentences if written now.

---

## 3. Under-specified on the critical path

### 3.1 The missing decision: OcuPilot's own authentication

**This is the answer to "name the specific decision that is missing."**

The spine contains no architecture decision for sign-in, token carriage, refresh, or the authentication settings of its own web applications. Measured against the document: **"Bearer" appears 0 times. "CSPBrowserId" appears 0 times. "JWT" appears once — and only about *Atelier*, in the Deferred table.** The Capability map assigns "5.1 Shell and sign-in (FR-1…FR-9)" to AD-19, AD-20, AD-12, AD-13 — reactivity model, absolute URLs, error envelope, id encoding. Not one of them is an authentication decision.

**What is unresolved that a builder cannot proceed without:**
- Does `/api/ocupilot` join `GroupById = %ISCMgtPortal` (addendum §2 Design A, the silent-first design) or stand alone (Design B, the addendum's named fallback)? FR-1's headline behaviour — "a user arriving from the classic portal is never asked to log in" — depends entirely on this.
- Access-token lifetime: 60 s as the vendor sets it, or raised to 300?
- Where does the refresh loop live, and what does the `%CSP.REST` router do on a 401?
- Is `/ocupilot` static `AutheEnabled = 64` (unauthenticated, as `/ui/interop` is)?

**Why it stalls, specifically:**
- It is **step 0** work, due in the **2026-09-14 listing build**.
- **AD-7 depends on it.** AD-7 says the job "inherits `$USERNAME` and `$ROLES` from the request process". Which authentication puts a real user in that process? With `UseSession = 0` and JWT, the answer is the token's subject — but that is a consequence of a decision nobody has made yet.
- **AD-17 depends on it.** The installer creates the two web applications and must set `JWTAuthEnabled`, `GroupById`, `AutheEnabled` and the token timeouts. It cannot until the values are chosen — and `Security.Applications.Create()` does not notify the CSP Gateway, so getting this wrong once costs a Gateway restart to observe.
- **The dev loop depends on it.** `CSPBrowserId` is `SameSite=Strict`, so `ng serve` on another port will not carry it; local development must proxy through the IRIS origin. The spine has no decision on the dev inner loop either, and the iris-couch harvest flags its own proxy config as "brittle by construction… Redesign for OcuPilot."

**Cost.** The work is already done — addendum §2 has the full spike result plus a recommended per-application settings table. Writing **AD-24 — Authentication** from it is **about one hour**. Discovering it mid-step-0 and choosing wrong costs **1 to 2 days** and can silently break the silent-first sign-in the PRD makes a headline feature (FR-1, UJ-1, SM-4).

### 3.2 AdminPort's response translation is incomplete

AD-2's stated sequence is `ResourcesOR` → `Check` → `ValidateRequest` → `ValidateSemantics` → `Run`. The vendor's `Main()` does two more things around `Run()`:

```objectscript
Set tSC = ##class(%Api.Admin.Util.General).BeginCaptureOutput(.tCookie)
Set responseBody = endpoint.Run(.tSC, requestBody)
...
Catch e {
    If e.%IsA("%Exception.SystemException") && (e.Name = "<PROTECT>") {
        Set %response.Status = ..#HTTP403FORBIDDEN
    }
}
If $Data(tCookie) Do ##class(%Api.Admin.Util.General).EndCaptureOutput(tCookie,.tMsgArray)
```

- **Without the output capture**, an endpoint that `Write`s sprays into the background job's device or into the REST response — directly violating AD-12's "handlers never `Write` to the response" and its `}{` test.
- **Without the `<PROTECT>` mapping**, a privilege failure raised *inside* an endpoint surfaces to the agent as a 500 `server_error` instead of the 403 that AD-8 promises "is identical to a 403 from a screen and is reported, never retried."

**~0.25 day each if known now.** Both belong in AD-2's rule.

### 3.3 The async-endpoint deferral is wrong on three counts, and one of them is a Release 1 read

The Deferred table says: *"Only 4 of 70 endpoint classes override `ShouldRunAsync`; none is on a Release 1 path."*

Measured: **7** override it — `Database.Actions`, `Database.SysCRUD`, `ECP.DataServer`, `Journal.File`, `Namespace.Namespace`, `Security.Audit.Record`, `Security.LDAP` — all conditionally on `Type`. And:

```objectscript
// %Api.Admin.Endpoints.Security.Audit.Record
Method ShouldRunAsync() As %Boolean
{
    /// The list endpoint also runs async, but it does its own logic
    /// to queue up a special async task
    Return (..Type = ..#TYPECOPY) || (..Type = ..#TYPEPURGE)
}

Method RunList(ByRef sc As %Status, requestBody As %DynamicObject) As %DynamicObject
{
    ...
    Set task.TaskName = ..GetName(%request)      // <-- dereferences %request
    ...
    Set sc = task.AddToAsyncQueue()
```

So: **the audit database viewer's list is async, and it dereferences `%request`** — which does not exist in AD-7's background job, and `%Api.Admin.Endpoint:GetName(request)` then does `$PIECE(request.URL, ...)` on an undefined variable. That screen is a **Release 1 P0 read** (FR-61 / LG-04 / SS-14), and it is the screen NFR-7 and AD-15's "either record locates the other" correlation story actually point at. The dispatcher's own async path is no help either: `%Api.Admin.Util.AsyncTaskEndpoint.%New(%request, endpoint)` takes `%request` as its first argument.

Two others matter sooner than "Stage 2": `Database.SysCRUD` with `Type = INFO` is the `POST /database-dir/info` that addendum §3 already flags as "asynchronous with unverified polling semantics" for OS management, and `Security.LDAP` with `Type = TEST` backs FR-75's LDAP test.

**Cost of deciding now:** ~0.25 day to name the audit-record list as the one Release 1 async read and choose its path (synthesize the async task, or bypass the endpoint and read `%SYS.Audit` / SQL directly for the list), then ~1 day to build. **Cost of discovering it on 2026-09-25:** FR-61 is the row that gets cut, and it is the row that demonstrates the agent marker.

### 3.4 The archetype set is undefined

See §2/AD-5. A builder cannot write descriptor #1 without knowing what archetypes exist and what each one generates. ~0.5 day to enumerate them (list, detail, form, tail, dashboard, explorer) with each one's contract; 1–2 days of churn if discovered per screen.

### 3.5 Progress-global lifecycle, and the dev inner loop

Both covered above (§2/AD-7, §3.1). Each is a paragraph now or half a day later.

---

## 4. Does the architecture support the build order?

**Mostly yes — with three decisions forced earlier than their step.**

| Step | Supported by | Assessment |
| --- | --- | --- |
| **0** shell, install, Docker, installer, API skeleton | AD-12, AD-13, AD-16, AD-17, AD-18, AD-20 | Well served and cheap. **Blocked by the missing auth decision (§3.1).** AD-9 and AD-5 both pull work in here that step 0 does not need. |
| **1** one live list per area + two log endpoints | AD-2, AD-5, AD-23 | AD-2 makes the five admin-backed areas genuinely cheap. Logs is the odd one out — custom endpoints plus AD-23's base class — and AD-23 earns ~0.5 d here. |
| **2** agent core, one confirmed write per area (SM-3) | AD-6, AD-7, AD-8, AD-10, AD-11, AD-15 | Complete and correctly scoped. AD-22 does **not** need to land here and will be read as if it does. |
| **3** remaining lists and details | AD-5 | This is where the descriptor machinery pays, or does not. |
| **4** small write actions | AD-3, AD-4 | AD-3's four-name resolver matters here; AD-4 keeps payloads small. |
| **5–6** medium and large editors | AD-3, AD-5 | AD-3's gaps bite exactly here: `Security.User`→`Schema()`, `Task.CRUD`→`PutAndPostSchema()`, `Security.Audit.Event` and `Wallet.Secret`→nothing. |
| **7** stretch | AD-8, AD-19, Deferred | Consistent. |

**Every step ends in a publishable build?** Yes — step 1 renders lists without the agent (AD-19's per-screen stores and the panel-as-shell-component make that clean), and AD-4 plus FR-9 mean a cut editor still leaves a working write tool behind. The one thing that breaks the property is a **half-built descriptor generator**, which is the strongest argument for the staging in §2.

**Work forced earlier than its step — named:**

1. **AD-5's generator into step 0/1.** Forced by the 2026-09-14 listing build. Fix: stage it (descriptor class in step 1, derivation in steps 2–4).
2. **AD-9's escalation half into step 0.** Forced by being one indivisible decision. Fix: split (database/resource step 0, privileged application step 2).
3. **AD-22's baseline capture into the contest window.** Forced by "captured at the Release 1 freeze". Fix: reduce the Release 1 obligation to one gate point plus a `mutates` declaration.

One observation, not a defect: AD-17 correctly loads the installer with auditing enablement, event registration and the `_SYSTEM` unexpire — matching the owner's standing note that the installer must enable auditing. That makes the installer the busiest single class in step 0, and it is the budget's 2.5-day **low-confidence** line. It is the right place for that work; it is worth knowing that step 0's risk is concentrated there.

---

## 5. The highest-risk bet, and the cheapest 48-hour de-risk

### The bet

**That OcuPilot can drive ~50 undocumented, `[ Hidden ]` vendor endpoint objects in-process — for writes as well as reads, from a background job as well as a request, for a low-privilege user as well as `%All` — across all six areas.** AD-1, AD-2, AD-3 and AD-4 all rest on it, and it is where the largest budget reductions are drawn.

Everything else in the spine has a fallback. This one does not: if it fails, the write path for five of six areas has no backing, SM-3 fails, and the entry drops below the 2026-09-27 application floor into "the thin interface the rules reject."

**Why it is riskier than the memlog implies.** The proof on record is **one endpoint, one type, one read**: `%Api.Admin.Endpoints.WebApp.App` with `type=0`, returning 42 web applications. Not yet shown:
- that a **write** (`Type = TYPEPUT`) succeeds in-process;
- that it succeeds **in a `JOB`ed process with no `%request` and no `%session`** — AD-7's actual mode;
- that the resource gate **denies** correctly, rather than merely allowing. The probe ran as `_SYSTEM` holding `%All`, which is the one identity that cannot distinguish "the gate works" from "the gate is irrelevant";
- that the four schema conventions cover what the Release 1 write tools need;
- that the `<PROTECT>` and output-capture paths behave (§3.2).

### The de-risk — half a day, before any Angular exists

One throwaway class, `OcuPilotProbe.AdminPortSpike`, with one class method and five assertions:

1. Create two disposable users: one holding only `%Admin_Secure`, one holding nothing.
2. **As the `%Admin_Secure` user**, instantiate `%Api.Admin.Endpoints.WebApp.App` with `Type = TYPEPUT` and `IsRunningAsync = 1`, seed `name` via `SaveOneQueryParam()`, and run `ResourcesOR` → `$System.Security.Check` → `ValidateRequest` → `ValidateSemantics` → `Run` with a **one-field** body against a throwaway web application. Assert the write landed **and only that field changed** — this proves AD-2 and AD-4 together.
3. Repeat the identical call **from a `JOB`ed process** (no `%request`, no `%session`), writing the outcome to a global. Assert identical result. This is the AD-7 mode and the one nobody has exercised.
4. Repeat **as the no-privilege user**. Assert `allowed = 0` and that no write occurred.
5. Iterate all 70 endpoint classes, calling whichever of `RequestBodySchema` / `PutRequestBodySchema` / `PutAndPostSchema` / `Schema` exists (guarded by a `%Dictionary.CompiledMethod` lookup), and emit a table: class → schema method → field count, plus the list with none. Assert the Release 1 write families are covered or explicitly listed as not.

**Plus one 30-minute probe:** instantiate `%Api.Admin.Endpoints.Security.Audit.Record` with `Type = TYPELIST` in a `JOB`ed process and confirm it fails on `%request`. That converts §3.3 from a 2026-09-25 surprise into a dated, known exception with a chosen workaround.

**Total: half a day.** It converts the entire Release 1 write path from an inference drawn from a single read into a demonstrated fact, and it produces the schema-coverage table that AD-3 needs in order to be written correctly. Delete the probe class afterwards, per the project's debugging rule.

**Second-cheapest, same window, ~1 hour:** write **AD-24 — Authentication** from addendum §2's recommended settings table, adopting Design A (`GroupById = %ISCMgtPortal`, silent-first) with Design B named as the documented fallback. It is the missing decision, the research is already done, and it unblocks step 0 and the listing build.

---

## 6. Summary of recommended corrections

None of these is a scope cut. All five are corrections or resequencing.

| # | Change | Cost now | Cost if not done |
| --- | --- | --- | --- |
| 1 | **Write AD-24 — Authentication** from addendum §2. Design A, Design B as fallback. Include the `ng serve` / SameSite=Strict dev-proxy consequence. | 1 hour | 1–2 d mid-step-0, and FR-1's silent-first sign-in at risk |
| 2 | **Rewrite AD-3's rule** to resolve four schema method names in order, with a documented hand-authored fallback and a retained instance probe for the 10 endpoints with none (`Wallet.Secret` and `Security.Audit.Event` by name). | 0.5 d | 1 d of churn in step 5, FR-46/FR-47 at risk |
| 3 | **Stage AD-5** — descriptor class hand-consumed in step 1; derivation in steps 2–3; write-schema generation in step 4. **Enumerate the archetypes** and decide how the TypeScript mirror is produced. | 0.5 d | The 2026-09-14 listing build, and a half-built generator when a cut lands |
| 4 | **Split AD-9** — database + resource + mappings in step 0 (satisfies FR-29 alone); privileged routine application + storage base in step 2. Note the `Routines` list is a third consumer of AD-17's roster. | 0.25 d | ~1.5 d pulled into the listing-build week |
| 5 | **Reduce AD-22's Release 1 obligation** to one gate point plus a `mutates` declaration per tool; frozen baseline, cascade and presets stay in the polish week per the PRD. | 0.25 d | ~2.5–3 d spent during the week SM-3 is due |
| 6 | **Correct AD-2's two factual claims** (65/70 free of `%request`, not 70/70; add `BeginCaptureOutput`/`EndCaptureOutput` and the `<PROTECT>`→403 mapping) and **the async Deferred row** (7 overrides, `Security.Audit.Record`'s list is a Release 1 async read that touches `%request`). | 0.25 d | FR-61 becomes the row that gets cut |
| 7 | **Specify the progress global's lifecycle** in AD-7: key shape, size bound, purge, orphaned-job behaviour. | 3 sentences | 0.5 d late in the window |
| 8 | **Add "a clean-container IPM install passes the smoke script"** to AD-17 / FR-66. | 1 line | A listing that does not install on 2026-09-14 |

**Arithmetic.**

| | Days for the specified work |
| --- | --- |
| PRD feasibility budget, as specified | 46–47 |
| With the spine as written | ≈ 35–37 |
| With the spine plus corrections 1–8 | ≈ 32–34 |
| Available | **19** |
| Application floor (steps 0–4 + one form per area) — PRD estimate with trims | 24–26 |
| Same floor, with the spine plus corrections | **≈ 19–22** |

The gap does not close. It was never going to close on architecture alone, and the owner has already made that call. What the spine does is bring the **floor** — steps 0 to 4 plus one form per area, which is what the 2026-09-27 application actually requires — from "closes only with the whole reserve spent" to "reachable with the reserve intact." That is the right thing for an architecture to buy in this situation, and it buys it.

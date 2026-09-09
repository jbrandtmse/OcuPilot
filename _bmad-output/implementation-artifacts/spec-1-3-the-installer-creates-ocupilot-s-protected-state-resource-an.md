---
title: "Story 1.3 — The installer creates OcuPilot's protected state, resource and role"
type: 'feature'
created: '2026-09-09'
status: 'ready-for-dev'
baseline_revision: 'db2667ad946a969c74c4f5112375d9ded159258e'
baseline_commit: 'db2667ad946a969c74c4f5112375d9ded159258e'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/.claude/rules/objectscript-basics.md'
  - '{project-root}/.claude/rules/objectscript-testing.md'
  - '{project-root}/.claude/rules/iris-persistent-storage.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** OcuPilot has no installer and no protected storage. Its agent definitions, switches, ledger and transcripts would land in the install namespace's ordinary database, where any holder of `%DB_<install-namespace>:RW` plus `%Admin_Operate` could read or forge them — the developers the portal is for. FR-29's acceptance test would fail, and there is nowhere for Stories 1.4, 1.5 and Epics 3 and 5 to put state.

**Approach:** One `Installer` class under `Install/` creates, guard-then-act and idempotently, a dedicated database holding OcuPilot's **globals only**, a `%DB_` resource guarding it that no ordinary role holds, the OcuPilot administrative resource and a role granting it, a privileged routine application, and one global mapping — leaving OcuPilot's **code** in the install namespace's normal database. One class in `Kernel/State/` is the sole escalation point: it obtains the guarding role through that application inside a `New $ROLES` frame, and one `%Persistent` class riding on it proves the protection from both sides — a denied user is refused on a global and on a table, an escalated caller succeeds on the same two.

## Boundaries & Constraints

**Always:**

- **Protect the data, never the code (AD-9).** Only globals move to the guarded database. No package mapping and no routine mapping is created; database READ is routine-execution permission, so hiding the packages would make OcuPilot unrunnable by exactly the users it serves.
- **One escalation point.** `New $ROLES` and `$SYSTEM.Security.AddRoles(...)` appear in `src/OcuPilot/Kernel/State/Base.cls` and in the denial-probe test class, and nowhere else in the tree. Nothing inside an escalated frame spawns a `JOB` or calls into `Api`, `Port`, `Screen` or `Area`.
- **`New $ROLES` unwinds with the method frame, not the block.** Escalation and the guarded access happen in the *same* method; a helper that escalates and returns has already lost the role.
- **Guard-then-act, and verify-and-repair (AD-17).** Every object is guarded by an existence check; on the existing-object path the installer still compares the live properties against the intended ones and repairs drift. Existence alone is not "installed".
- **Namespace by explicit save and restore (AD-16)**, through `OcuPilot.Kernel.Utils.SwitchNamespace` / `RestoreNamespace`, with the restore as the **first line of every `Catch`**. `New $NAMESPACE` never appears. `Security.*`, `Config.*` and `SYS.Database` exist only in `%SYS`.
- **Reuse Story 1.1's surface.** All installer reporting goes through `OcuPilot.Kernel.Audit.Log`; no class here may contain a bare `Write`.
- **Every `%Status` is checked** with `$$$ISERR`; `Set tSC = $$$OK` first line, `Quit tSC` last; argumented `Quit` never inside `Try`/`Catch`.
- **Weak references (AD-37).** The username the administrative role was granted to is stored as data on the install stamp, never as a foreign key, and a stamp naming a user who no longer exists reads as "no longer present" rather than failing.
- **The database directory comes from `$System.Util.ManagerDirectory()` at runtime (AD-21)** — never from a caller, never cached, never a literal path.
- Class names, package dots included, are **29 characters or fewer**; `iris_`, `IRIS_*`, `%Atelier`, `IRISCouch`, `SessionAgent`, `ExecuteMCPv2` are forbidden substrings anywhere under `src/OcuPilot/`.

**Never:**

- **No web applications.** `/ocupilot` and `/api/ocupilot` are Story 1.5's, wired by 1.4. The only `Security.Applications` entry created here is the privileged **routine** application (`Type = 4`), which the CSP Gateway never serves — so AD-17's Gateway-registration report belongs to 1.4/1.5, not here.
- **No container start hook, no image pin, no demo fixture, no `_SYSTEM` unexpire, no schema-version stamp and no "installing"/"upgrade required" refusal.** All Story 1.4. This story ships the class 1.4 invokes.
- **No agent definition is seeded** (FR-66), so the first-login gate is active on first login.
- **No hardcoded grant to a vendor account.** The sibling's unconditional `_SYSTEM` grant is not copied.
- **No hand-rolled role read-modify-write** — use `Security.Users.AddRoles()`.
- **No hand-written Storage section**, no `list Of` property, no dynamic class-method invocation by name (Story 1.1 declined `InvokeWithArgs` as an avoidable surface under AD-8; do not reintroduce it).
- **No test calls `Uninstall("")`.** The production objects are this story's deliverable and Stories 1.4+ inherit them.
- **No test changes the instance's `AuditEnabled` setting.**

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Fresh install | Profile `""`; none of the named objects exist | Database `OCUPILOT` at `<ManagerDirectory>ocupilot/` guarded by `%DB_OCUPILOT`; resource+role `OcuPilotAdmin`; privileged routine application `OcuPilotState`; one global mapping `OcuPilot*` → `OCUPILOT` in the install namespace; audit event `OcuPilot/Security/RoleGranted`; auditing enabled; `$$$OK` | Any failure returns the underlying `%Status`; `$NAMESPACE` restored first in the `Catch` |
| Re-install (upgrade path) | Every object already exists and is correct | `$$$OK`; the ensure steps still run; `StateFingerprint()` is byte-identical to the first run | As above |
| Drifted object | The privileged routine application exists with `Enabled = 0` | The second run repairs it to `Enabled = 1` and reports the repair through the logger | Repair failure returns an error status, not a silent OK |
| Denied user, global | A user holding `%DB_<install-ns>:RW` and `%Admin_Operate:U` through a purpose-built role, not `OcuPilotAdmin`, not `%DB_OCUPILOT` | Direct read **and** write of `^OcuPilot…` both raise `<PROTECT>` | The exception is captured inside the impersonating frame and asserted outside it |
| Denied user, table | Same user, `SELECT` and `INSERT` against the stamp table | `%SQLCODE < 0` on both | Assert the code observed, and pair with the escalated success below so a mistyped table cannot pass as a denial |
| **Integration AC** — escalated consumer | `OcuPilot.Kernel.State.Stamp` writes a row and reads it back through `OcuPilot.Kernel.State.Base` | The row round-trips with its values intact; the same row is invisible to the denied user in the two rows above | A failed escalation returns an error status; the frame still unwinds |
| Escalation frame | Inside `Base`'s guarded method | `%DB_OCUPILOT` is present in `$ROLES` inside the frame and absent immediately after the method returns, on the normal path **and** after an exception | Exception is re-raised as a `%Status`; role never survives |
| Grant, real account | `$Username` is a named account that exists | The role is granted (idempotently), the outcome and the username are recorded on the stamp, and an `OcuPilot/Security/RoleGranted` audit row is written | Grant failure is reported and returned, not swallowed |
| Grant, placeholder | `$Username` is `""`, `UnknownUser` or `_PUBLIC` | No grant; the exact `Security.Users.AddRoles(...)` command an operator must run is reported through the logger and recorded on the stamp | Never a silent skip |
| `Uninstall`, absent | Profile whose objects do not exist | `$$$OK`, nothing changed | — |
| `Uninstall`, unconfirmed | Profile exists, `pConfirmDataLoss = 0` | Error status naming what would be destroyed; **nothing is changed** | — |
| `Uninstall`, confirmed | Profile exists, `pConfirmDataLoss = 1` | Mapping, application, role, both resources, config entry, `IRIS.DAT` and the directory are all gone | Partial failure returns the first error; already-removed objects are not errors |

</intent-contract>

## Code Map

**What exists today (extend, never duplicate).**

- `src/OcuPilot/Install/` — holds only `.gitkeep`. This story creates the first class in it.
- `src/OcuPilot/Kernel/Utils.cls` — `SwitchNamespace(pNamespace, Output pOriginal)` (:35) and `RestoreNamespace(pOriginal)` (:50). Its header records that the class has **no production consumer and has never executed**, and instructs the first consumer to add a test host alongside its first call site. **This story is that first consumer** for the namespace pair. The class's other deferred defects (`ReadRequestBody`, DW-23) stay routed to Story 1.5 — do not claim them.
- `src/OcuPilot/Kernel/Audit/Log.cls` — `Info` / `Warn` / `Error` / `Debug` (:16-:34), never throw. **The installer's only output channel.** Not the IRIS audit database.
- `src/OcuPilot/Api/Error.cls:129` `LogError` and `src/OcuPilot/Kernel/Audit/Log.cls:76` `WriteConsole` — the **seam + probe-subclass + `^||` capture** pattern (`Test/LogProbe.cls`, `Test/ErrorProbe.cls`). Copy this shape if a side effect needs intercepting.
- `src/OcuPilot/Test/` — `Http`, `Dispatch`, `RouterFixture`, `LogProbe`, `ErrorProbe`. **None is useful here** (no HTTP surface, no dispatch). No test class in the tree declares `%OnNew`, `OnBeforeOneTest` or `OnAfterOneTest`; this story writes the tree's first setup/teardown discipline. Existing convention: class `OcuPilot.Test.<Subject>`, instance `Method Test<Claim>()`, every assertion carrying a message.
- `scripts/check-objectscript.py` — five rules, exit `1` if any problem. `WRITE_ALLOWED` (:258 region) is an **exact relative-path allow-list**; copy that shape for the new rules. `FIXED_PACKAGES` requires `OcuPilot.<Api|Kernel|Screen|Area|Port|Install|Test>.…` with **at least three** dot-separated segments. `MAX_CLASS_NAME_LENGTH = 29` counts the full dotted name. Invoked by `.githooks/pre-commit` on staged `src/OcuPilot/**/*.cls`.
- `docker-compose.yml` — 12 lines, no `command:`, no `entrypoint:`, no init script. **There is no start hook yet**; Story 1.4 creates it. Verify this story by invoking the class through the IRIS MCP tools.

**Harvest source — shape only, never names** (`/Users/jbrandt/git/iris-couch/src/IRISCouch/Installer.cls`, 208 lines).

- Copy: `Set tOrigNS = $NAMESPACE` before the `Try`; `Set $NAMESPACE = $Get(tOrigNS, $Namespace)` as the **first line of every `Catch`** (:99, :186, :205); the existing-object early path that **still** runs the ensure steps (:74-79); `Uninstall` returning `$$$OK` when absent (:176-179); the `Install`-twice test (`Test/InstallerTest.cls` `TestInstallIdempotent`).
- **Do not copy:** the early return that never verifies the existing object's configuration (its own doc comment, :57-58, admits it returns OK against a stale `DispatchClass` forever — the single largest defect, and the reason this story does verify-and-repair); the hand-rolled `GrantAdminRole` read-modify-write (:138) instead of `Security.Users.AddRoles`; the unconditional `_SYSTEM` grant (:120-122); discarded `%Status` on three privileged calls; `IsInstalled()` conflating "not installed" with "could not check" (:205); the dead `Parameter DEFAULTWEBAPPPATH`; `module.xml` (no `<Invoke>` — Story 1.16's problem).
- **Gaps confirmed against the source, not just the harvest map:** `grep` over `iris-couch/src/` returns **zero** hits for `Security.Resources`, `Config.Databases`, `SYS.Database` and `Config.Map*`. It creates no database, no resource and no mapping, and `Auth/Users.cls:181` hardcodes `%DB_IRISCOUCH` — proof the operator was expected to pre-create the database. It also never enables auditing (`Security.System` appears nowhere).

**System behaviour verified on `ocupilot-iris` (IRIS for Health 2026.2 build 221U) during planning.** Do not re-derive; do re-check anything you change.

- **A database's resource name must begin with `%DB_`.** `CreateDatabase(dir,1,8192,0,"OcuPilotDb")` → `ERROR #896: Invalid resource name`; `ModifyDatabase` with a valid non-`%DB_` resource → `<FUNCTION>` at `%SaveData+103^SYS.Database.1`. Hence `%DB_OCUPILOT`.
- **`SYS.Database` does not validate that the resource exists** — assigning a non-existent one returns OK and yields a database only `%All` can reach. **Create the resource first.**
- **Creating a `%DB_*` resource auto-creates a matching implicit role** granted to nobody (audit timestamps 5 ms apart); deleting the resource deletes the role. `Security/Roles.cls:21`: `%DB_*` implicit roles cannot be modified.
- **Creation is three calls, in order:** `%File.CreateDirectoryChain(dir)` → `SYS.Database.CreateDatabase(dir, size, blocksize, 0, resource)` → `Config.Databases.Create(NAME, .Props)` with `Props("Directory")`. `Config.Databases` performs no file operations (its own class header says so).
- **Re-running `CreateDatabase` against an existing `IRIS.DAT` reinitializes it.** Guard with `##class(%File).Exists(dir_"IRIS.DAT")`.
- **Removal is four calls:** `Config.Databases.Delete(NAME)`, `SYS.Database.DeleteDatabase(dir)` (no dismount needed; deletes only `IRIS.DAT`), `Security.Resources.Delete("%DB_…")`, `%File.RemoveDirectoryTree(dir)`. Verified round-trip clean, including the CPF.
- **`Config.MapGlobals.Create(namespace, "OcuPilot*", .props)` with `props("Database")` works and is live on the next global reference** with the default flags. Verified: the pattern routes the exact root global and every global whose name starts with the prefix, and leaves non-matching globals in place. `LockDatabase` defaults to the target database. The SMP exposes no wildcard field — this is an API capability.
- **Signatures** (`irissys/`): `Security.Resources.Create(Name, Description, PublicPermission, Type)` — Type **2** for a database resource, **0** for an ordinary one, `PublicPermission ""` for not-public. `Security.Roles.Create(Name, Description, Resources, GrantedRoles, EscalationOnly=0)` — `Resources` is `"Name:RWU,Name2:U"`; `Roles.cls:255` warns that `Modify` with `Resources=""` **removes all resources**; `Roles.cls:36-40` requires `Properties("ForceSave")=2` on `Modify` during installation. `Security.Users.AddRoles(Username, ByRef Roles, Admin=0)` is additive; `Get(user,.p)` → `p("Roles")` is the directly-assigned list.
- **Privileged routine application** (`Security/Applications.cls`): `Type = 4` (`$$$AppTypePrivRoutine`). Meaningful properties are `Name`, `Description`, `Enabled`, `Type`, `Resource`, `MatchRoles` and `Routines` only — `NameSpace`, `DispatchClass`, `AutheEnabled` and the rest are CSP-only. `Routines` entries are `Class:dbname:1` where `dbname` is the **configured database name** of the database holding the code, not a namespace and not a path. `MatchRoles` entry `:<Role>` (empty match) grants unconditionally. `Get()` may omit the `Routines` key entirely — read it with `$Get()`.
- **`New $ROLES` stacks both `$ROLES` and `$USERNAME` and restores on normal return and on exception unwind** (verified). It is **frame-scoped, not block-scoped**: a `New $ROLES` inside a `Try` unwinds when the *method* returns. Role names normalise to upper case in `$ROLES` — never compare case-sensitively. `Set $ROLES = ""` clears only *Added* roles, so it cannot de-privilege `_SYSTEM`.
- **`JOB` children inherit `$ROLES` and `$USERNAME` at the moment of the spawn** (documented, `RCOS_vroles` and `RCOS_cjob`). *Inference, labelled:* that the child keeps them after the parent's frame unwinds is not stated in any source found; it follows from `$ROLES` being per-process state with no cross-process revocation channel. AC6 enforces the ordering rule mechanically rather than relying on the inference.
- **CSP request boundaries do not carry added roles forward** (`GSA_manage_applications.md:277`) — escalation cannot leak across REST requests.
- **`%DB_IRISSYS:RW` is a self-escalation primitive.** A user holding it can `Set $ROLES` to anything and can `$SYSTEM.Security.Login("_SYSTEM")` with no password — verified end to end. `%Operator` carries it. **The AC's test user must not hold `%Operator`**; build a purpose-built role carrying exactly `%Admin_Operate:U`.
- **`%Admin_Operate` is a resource, not a role**, and `Security.Users.Create/Modify` **silently accepts a non-existent role name** — a test written literally against the AC's wording would grant nothing and still pass its own setup.
- **Denial signatures:** global → `<PROTECT>`, `e.Code = 202`, `e.Data = "^Global,/path/to/db/"`, raised even for a node that does not exist. SQL → `%SQLCODE = -99` *or* `-30` ("table not found") depending on visibility, so assert `%SQLCODE < 0` **and** pair with an escalated success on the same table.
- **`Security.Events.Create(Source, Type, Name, Description, Enabled=1, Flags=0)`** — each field ≤64 chars, no `/`, and **Source and Type may not start with `%`** (system-reserved). `Security.Events.Exists` accepts either three arguments or one `"Source/Type/Name"` string. `$System.Security.Audit(...)` on an unregistered triple returns a **bare `0` status with no error text** — `$$$ISERR` catches it, `GetErrorText` says nothing useful.
- **Auditing** is enabled through `Security.System.Modify("SYSTEM", .props)` with `props("AuditEnabled") = 1`; unnamed properties are left untouched. **Never include `AuditEncrypt`** — changing it deletes the audit database and everything in it. `Security.System.IsAuditingEnabled()` reads the flag. Auditing is currently **on** on this instance, and 75 system event types are registered; there are **no** user-defined types.
- **Instance baseline:** nothing named like OcuPilot exists — no database, resource, role, application, namespace or global. Install directory `/usr/irissys/`, **manager directory `/durable/iris/mgr/`** (they differ; only the manager directory is on the durable bind mount). `HSCUSTOM` exists, so it is the install namespace here. `iris_database_list`'s `resource` field is empty for **every** database and must not be used to assert this story's central claim — read `SYS.Database.%OpenId(dir).ResourceName`.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Install/Installer.cls` — new `OcuPilot.Install.Installer` (26 chars) — the one installer class (AD-17). Public: `Install(pProfile As %String = "") As %Status`, `Uninstall(pProfile As %String = "", pConfirmDataLoss As %Boolean = 0) As %Status`, `StateFingerprint(pProfile As %String = "") As %String`, `ResolveNamespace() As %String` (`HSCUSTOM` when it exists, else `USER`). Private: `Names(pProfile, Output pNames)`, and one guard-then-act ensure step per object — database, database resource, administrative resource, administrative role, privileged routine application, global mapping, audit event, auditing, grant. Each ensure step **creates when absent and repairs when present but wrong**, returns a `%Status`, and reports what it did through `Kernel.Audit.Log`. `pProfile` is validated to `""` or `"probe"` and nothing else.
- `src/OcuPilot/Kernel/State/Base.cls` — new `OcuPilot.Kernel.State.Base` (26 chars) — the tree's **only** escalation point (AD-9). Abstract `%Persistent` base providing guarded save / open / exists and guarded global get / set, each performing `New $ROLES` and `$SYSTEM.Security.AddRoles(<application>)` **in the same method frame** as the access it guards. Contains no `JOB` and no reference to `OcuPilot.Api`, `.Port`, `.Screen` or `.Area`. Header states the two ordering rules verbatim.
- `src/OcuPilot/Kernel/State/Stamp.cls` — new `OcuPilot.Kernel.State.Stamp` (27 chars) extending `Base` — one row per install run: timestamp (ISO-8601 UTC via `$ZTimeStamp`), the profile, **one scalar property per created object name** (database, database resource, administrative resource, administrative role, privileged routine application, mapping), the grant outcome and the **granted username as data, never a foreign key** (AD-37), and a resolver that renders an absent user as "no longer present". Named scalars deliberately, **not** a `list Of %String` — a list would need a subtable projection under the persistent-storage rule for no gain here. No hand-written Storage.
- `src/OcuPilot/Test/Installer.cls` — new `OcuPilot.Test.Installer` (23 chars) — the create/repair/idempotency/uninstall suite, run against the `probe` profile except where an AC names production. `OnAfterOneTest` calls `Uninstall("probe", 1)` unconditionally.
- `src/OcuPilot/Test/State.cls` — new `OcuPilot.Test.State` (19 chars) — escalation, denial and integration. Owns the throwaway denial user and its purpose-built role, created in `OnBeforeOneTest` and deleted in `OnAfterOneTest`. No property name begins with `Test`; `%OnNew(initvalue)` forwards to `##super`.
- `scripts/check-objectscript.py` — add two rules with the existing exact-path allow-list shape: (a) `New $ROLES` / `$SYSTEM.Security.AddRoles` may appear only in `src/OcuPilot/Kernel/State/Base.cls` and `src/OcuPilot/Test/State.cls`; (b) files under `src/OcuPilot/Kernel/State/` may not contain a `JOB` command or a reference to `OcuPilot.Api`, `OcuPilot.Port`, `OcuPilot.Screen` or `OcuPilot.Area`. Both skip comment lines and `XData` bodies exactly as `check_write_discipline` does. Update the module docstring's rule count.
- `README.md` — one short subsection recording that install **enables instance auditing** and registers OcuPilot's event types, as a deliberate security-posture change (FR-66), and naming the one command that grants the administrative role when install could not.

**Acceptance Criteria:**

- **AC1** — Given a profile whose objects do not exist, when `Install(pProfile)` runs, then a database exists at `<ManagerDirectory><name>/` with an `IRIS.DAT`, its `SYS.Database` `ResourceName` is that profile's `%DB_` resource, and that resource exists with `PublicPermission = ""` and `Type = 2`.
- **AC2** — Given the same run, when it completes, then the administrative resource and a role of the same name exist, the role's `Resources` grants **only** the administrative resource with `U`, and the role does **not** grant the `%DB_` resource — no ordinary role holds the guarding resource (AD-9).
- **AC3** — Given the same run, when it completes, then exactly one global mapping exists in the install namespace whose name is the profile's global prefix followed by `*` and whose `Database` is the profile's database, and **no** package mapping and **no** routine mapping was created, so OcuPilot's code remains in the install namespace's normal databases.
- **AC4** — Given a user holding `%DB_<install-namespace>:RW` and `%Admin_Operate:U` through a purpose-built role, holding neither `OcuPilotAdmin` nor `%DB_OCUPILOT`, when that user reads and writes an `^OcuPilot…` global directly and selects from and inserts into the stamp table, then all four attempts are refused — `<PROTECT>` for the two global attempts and `%SQLCODE < 0` for the two SQL attempts — **and** the same global reference and the same table are read successfully through the escalated path in the same test, so a mistyped name cannot pass as a denial.
- **AC5** *(Integration AC, Rule 1)* — Given the consumer `OcuPilot.Kernel.State.Stamp`, when it writes a row and reads it back through `OcuPilot.Kernel.State.Base`, then the row round-trips with its values intact, the guarding role is present in `$ROLES` **inside** the guarded frame and absent immediately after the method returns — on the normal path and after an exception raised inside the frame — and that row is one of the objects AC4's denied user cannot see.
- **AC6** — Given the whole source tree, when the mechanical checker runs, then `New $ROLES` and `$SYSTEM.Security.AddRoles` appear only in `Kernel/State/Base.cls` and `Test/State.cls`, and no file under `Kernel/State/` contains a `JOB` command or a reference to `OcuPilot.Api`, `.Port`, `.Screen` or `.Area` — the two ordering rules of AD-9 enforced mechanically rather than by inference.
- **AC7** — Given a profile already fully installed, when `Install(pProfile)` runs a second time, then it returns `$$$OK`, `StateFingerprint(pProfile)` is byte-identical to its value after the first run, and the ensure steps still executed (AD-17) — *nothing changes* means the net state, not that steps were skipped.
- **AC8** — Given a profile installed but drifted, when `Install(pProfile)` runs against it, then the drift is repaired and the repair is reported; existence alone never counts as installed.
- **AC9** *(DW-16)* — Given `$Username` is an existing named account, when install completes, then the administrative role is granted to it, the grant is idempotent across runs, an `OcuPilot/Security/RoleGranted` audit row naming the actor and the target is written, and the stamp records the outcome and the username. Given `$Username` is `""`, `UnknownUser` or `_PUBLIC`, when install completes, then no grant is made, the exact `Security.Users.AddRoles(...)` command an operator must run is reported through the logger, and the stamp records that outcome — never a silent skip.
- **AC10** — Given auditing, when install runs, then it enables auditing if it is off and reports which of the two happened as a distinct outcome, the profile's audit event triple is registered, and an event emitted through `$System.Security.Audit` produces a matching row in the audit database — the round trip, not the registration alone.
- **AC11** — Given `Uninstall(pProfile, pConfirmDataLoss)`, when the profile's objects are absent it returns `$$$OK` having changed nothing; when they are present and `pConfirmDataLoss = 0` it returns an error naming what would be destroyed and changes nothing; when they are present and `pConfirmDataLoss = 1` the mapping, application, role, both resources, config entry, `IRIS.DAT`, directory and audit event are all gone, proved by a fresh listing and by `%File.DirectoryExists`.
- **AC12** — Given any error path in `Install` or `Uninstall`, when it is taken, then `$NAMESPACE` is restored as the **first** line of the `Catch` and equals the caller's namespace on return, and `Kernel.Utils.SwitchNamespace` / `RestoreNamespace` have a direct test host — this story is their first consumer.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing architecture decisions** (`ARCHITECTURE-SPINE.md`, `status: final`, 48 ADs; line anchors from the spine):

- **AD-9** (:172) — globals only behind the resource, code stays put; the storage classes and only they escalate through a privileged routine application inside `New $ROLES`; the two ordering rules (nothing spawned, nothing re-enters). The spine's structural seed (:617) calls `Kernel/State/` "protected-storage base, **the only class that escalates**" — singular. **Resolved reading:** one base class owns escalation, every other storage class inherits it. This satisfies both AD-9's plural "storage classes" and the seed's singular, and turns "no other class in the tree escalates" into the one-line mechanical assertion of AC6.
- **AD-17** (:244) — one installer class, guard-then-act, safe to repeat, re-runs its privileged steps, enables auditing and registers events. **AD-38** (:406) — install completes or fails loudly before traffic (the start path is 1.4's; this story ships the idempotent, fast, populated-instance-safe class it calls). **AD-16** (:238) — explicit save and restore, restore first in every `Catch`. **AD-8** (:166) — privilege is the process's at call time; AD-9's escalation is the one permitted exception. **AD-21** (:268) — bind SQL parameters, accept no caller path, the directory comes from `$System.Util.ManagerDirectory()`, and reject `UnknownUser` / `_PUBLIC` explicitly (which is what AC9's placeholder branch does). **AD-37** (:400) — weak references, stored as data.
- Also binding, found by reading all 48: **AD-10** (:184) — the prohibited set names "deleting OcuPilot's own web applications, resource, role or database", so the names this story creates must be kernel-visible constants rather than installer locals, and `Uninstall` is an operator action outside the agent's write path. **AD-15** (:232) — events registered with `Security.Events.Create()` at install, emission never fails a write. **AD-45** (:464) — the smoke path is owned by `Install/` (Story 1.17). **AD-32** (:370) — the installer also creates an SSL configuration later; same idempotence discipline. **AD-25** (:307) — the only mention of uninstall in the spine ("uninstall removes it"), which is why `Uninstall` ships here rather than being invented in 1.4. **AD-30** (:356), **AD-33** (:376), **AD-34** (:382), **AD-41** (:430), **AD-46** (:472) — later consumers of the protected store; none of their state is built here, but the store must not preclude them.
- Consistency Conventions: ObjectScript naming (:512, the 29-character bound), names never inherited from siblings (:513), config in the protected database (:527), collections (:524), status handling (:523), dates (:520), tests (:528), logging (:526).

**Resolved readings** (recorded so a reviewer can check the reasoning rather than re-derive it):

1. **AC2's "but not the OcuPilot administrative resource" is a description of the test subject, not a claim that the administrative resource grants data access.** AD-9 is explicit that the guarding resource is held by no ordinary role and reached only through the privileged routine application. So `OcuPilotAdmin` grants **only** `OcuPilotAdmin:U`; it never grants `%DB_OCUPILOT`. Both readings of the AC produce the same test and the same observable outcome for the described user, so this is a naming clarification, not an intent gap.
2. **Mappings: one global mapping, no package or routine mapping.** The story's ACs never mention mappings; AD-9 requires the code to stay in the install namespace's normal database, and a package or routine mapping into the guarded database would contradict it directly. A global mapping is the mechanism that makes AD-9 true at all, and was verified working on the instance.
3. **AC7's "nothing changes" is about net state, not about skipped steps.** AD-17 requires the privileged steps to re-run on the existing-object path. `StateFingerprint()` makes the net-state half measurable; the drift-repair test (AC8) makes the re-run half falsifiable. The two together are what NFR-9 means by "safe to repeat".
4. **The privileged routine application carries no `Resource`.** A resource on it would restrict who may escalate, and OcuPilot's storage must be reachable by exactly the users OcuPilot serves (AD-9's own reasoning about code placement). Containment comes from the `Routines` allow-list — only `Kernel.State.Base` may call `AddRoles` — plus the `New $ROLES` frame, plus AC6's mechanical check.
5. **The `probe` profile is a test seam, not a feature.** Without a second, disposable name set, every create-path AC would be vacuous on an already-installed instance ("it exists" is true because a previous run made it) — precisely the unfalsifiable-gate failure Stories 1.1 and 1.2 were both reviewed for. `Install()` with no argument is exactly the production profile; the profile argument accepts nothing but `""` and `"probe"`. The probe's global prefix is deliberately **not** nested inside the production prefix, so the two mappings cannot overlap and the test never depends on IRIS's most-specific-match behaviour, which was not verified. **What the probe profile does and does not exercise:** it exercises the installer's object management — create, verify-and-repair, fingerprint, remove — including a real privileged routine application, which is why that application is created for the probe even though nothing escalates into the probe database. It does **not** exercise escalation, denial or the integration AC: `Kernel.State.Base` names exactly one application and one guarding role, so AC4 and AC5 necessarily run against production.
6. **The `OcuPilot*` mapping captures `^OcuPilotTest` too** — Story 1.1's `Test.Http` configuration global. That is correct by AD-9 (it is an OcuPilot global) and harmless today because `Test.Http` runs as `_SYSTEM`. Recorded so it is not later mistaken for a bug.
7. **No CSP Gateway report here.** AD-17 requires the installer to report the Gateway-registration gap; that gap applies to *web* applications, which this story does not create. The obligation travels with Stories 1.4/1.5.
8. **AD-7 (:160) says progress records live in a temp global; AD-33 (:380) says they live in protected storage.** That contradiction is Epic 5's to settle. This story neither settles nor forecloses it: a temp global is simply not named `^OcuPilot…` and so is not captured by the mapping.

**Ledger inbox (Rule 17).** One entry, **DW-16** — "Installer creates the administrative resource and role but grants the role to nobody". **Addressed**, by AC9 and its task, taking *both* halves of the guard rather than choosing between them: install grants the role to the installing user when `$Username` is a real named account, **and** reports the exact grant command whenever it does not. FR-29's own testable consequence is "the installer creates the resource and a role granting it, **and documents which users to grant it to**", and the ledger's evidence is that granting to nobody leaves no one able to configure the agent; doing both satisfies each. The sibling's precedent was weighed and **rejected in part**: `$Username` is kept, the hardcoded `_SYSTEM` grant is not — a shipped installer must not grant a role to a named vendor account, and `_SYSTEM` is this container's dev credential. The grant is audited (AC10), recorded on the stamp, idempotent, and reversible with one documented command.

**Consumes:** `OcuPilot.Kernel.Utils` (`SwitchNamespace` / `RestoreNamespace` — first production consumer; adds the direct test host its header asks for), `OcuPilot.Kernel.Audit.Log` (all reporting; the installer may not `Write`). Neither Story 1.1 nor 1.2 listed Story 1.3 under `Consumed-by:`; this closes that gap from the consumer side.

**Consumed-by:**

- **1.4** — invokes `Installer.Install()` from the container start path, adds the image pin, `_SYSTEM` unexpire, demo fixtures, the schema version stamp on `Kernel.State.Stamp` and the migration path.
- **1.5** — extends the same `Installer` with the two web applications and the Gateway-registration report.
- **1.16** — generates `module.xml` from the same class roster the installer compiles.
- **1.17** — the smoke script and readiness endpoint, both owned by `Install/`, read the stamp.
- **Epic 3** — the instance-wide read-only switch and kill switch are rows in this protected store (AD-30).
- **Epic 5** — the ledger, transcripts, proposals and progress records (AD-33, AD-34, AD-41, AD-46).
- **Epic 10** — per-user UI state and the per-user toggle.

**Golden example — the frame constraint, which is the single easiest thing to get wrong.** `New $ROLES` unwinds with the *method* frame, so a helper that escalates and returns has already lost the role before the caller does anything:

```objectscript
; WRONG — the role is gone the moment Escalate() returns.
Do ..Escalate()  Set tSC = pObject.%Save()

; RIGHT — escalation and the guarded access share one frame.
ClassMethod SaveGuarded(pObject As %Persistent) As %Status
{
    Set tSC = $$$OK
    New $ROLES
    Try {
        Set tSC = $SYSTEM.Security.AddRoles(..#PRIVAPP)
        If $$$ISERR(tSC) Quit
        Set tSC = pObject.%Save()
    }
    Catch ex { Set tSC = ex.AsStatus() }
    Quit tSC
}
```

**Two traps that have already cost time.** `$$$ISOK` is a compile-time macro and is unavailable to ad-hoc MCP command execution — use `$System.Status.IsOK()` there, and note that a `<SYNTAX>` failure from that tool is **not** atomic: earlier commands on the same line have already run. And IRIS SQL has no `[_]` bracket escaping — `LIKE '%DB[_]%'` silently returns zero rows; use `%STARTSWITH`.

## Verification

**Commands:**

- IRIS MCP `iris_doc_load` + `iris_doc_compile` (`server: "ocupilot-iris"`, namespace `HSCUSTOM`, path `/Users/jbrandt/git/OcuPilot/src/**/*.cls`, `compile: true`, flags `cku`) -- expected: every class compiles with no errors. Use the `src/**` form, not `src/OcuPilot/*.cls`, which swallows the package into the base directory and loads the class unqualified. Read the error text; a clean local file is not evidence.
- IRIS MCP `iris_execute_classmethod` on `OcuPilot.Install.Installer` `Install` with no argument (`server: "ocupilot-iris"`) -- expected: `$$$OK`, and the production objects exist afterwards. There is no container start hook yet; this is how install is invoked until Story 1.4.
- IRIS MCP `iris_execute_tests` **per class** (`level: "class"`) for `OcuPilot.Test.Installer`, `OcuPilot.Test.State`, then the four Story 1.1 classes (`Routing`, `Envelope`, `Log`, `EntityId`) -- expected: zero failures each, and the epic total rises from 30 by exactly the number of new `Test*` methods. Aggregate the totals yourself.
- The `%UnitTest_Result` SQL probe from `.claude/rules/objectscript-testing.md` -- expected: the per-class totals match the aggregate above. **Mandatory before claiming the suite green** — the MCP runner envelope truncates per-class result lists and can under-report.
- `uv run scripts/check-objectscript.py` -- expected: exit 0 over `src/OcuPilot/**` and `ui/**`, including the two new rules. A bare `python3` runs outside the project environment.
- `bash scripts/lint-docs.sh` -- expected: exit 0 over the authored Markdown, including the new README subsection.
- `grep -rn "New \$ROLES\|AddRoles" src/OcuPilot/ --include=*.cls` -- expected: matches only in `Kernel/State/Base.cls` and `Test/State.cls`. This is the human-readable form of AC6; the checker is the enforced form.

**Mutations (Rule 19 — one per acceptance criterion and per pinning test; after each, revert and confirm `git status --short` and `git diff --stat` are unchanged):**

- **AC1** — mutation: in `Installer.cls`'s ensure-database step, pass `"%DB_%DEFAULT"` instead of the profile's `%DB_` resource to `SYS.Database.CreateDatabase` **and** to the repair path -> `TestCreatesGuardedDatabase` in `Test/Installer.cls` goes red naming the observed `ResourceName` against the expected one. Read the resource with `SYS.Database.%OpenId(dir).ResourceName`; `iris_database_list` reports it empty for every database and would make this assertion vacuous.
- **AC2** — mutation: create the administrative role with `Resources = ""` -> `TestAdminRoleGrantsOnlyTheAdminResource` goes red naming the empty resource list; the companion assertion that the role does **not** carry the `%DB_` resource stays green, proving the two halves are independent.
- **AC3** — mutation: change the mapping's `Database` property to the install namespace's own database -> `TestGlobalMappingTargetsTheGuardedDatabase` goes red naming the wrong target. Second mutation: add a `Config.MapPackages.Create` call for `OcuPilot` -> `TestNoPackageOrRoutineMappingIsCreated` goes red naming the package mapping.
- **AC4** — mutation: in the ensure-database repair path, stop repairing a drifted `ResourceName`, then set the production database's resource to `%DB_%DEFAULT` and re-run `Install()` -> `TestDeniedUserCannotReachTheGlobal` and `TestDeniedUserCannotReachTheTable` in `Test/State.cls` both go red because the reads succeed. **Revert by restoring the repair and re-running `Install()`, which repairs the resource; verify with `SYS.Database.%OpenId(dir).ResourceName` before continuing.** This is the one mutation that temporarily leaves the guarded database unprotected, and it is unavoidable: `Kernel.State.Base` names one application and one guarding role, so AC4 cannot be exercised against the `probe` profile. Do it **last**, on a store that at this point in the epic holds nothing but this story's own test rows, and confirm the revert before moving on.
- **AC5** — mutation: in `Base.cls`, move the `New $ROLES` out of the guarded method into a helper the method calls -> `TestGuardedSaveRoundTrips` goes red with a `<PROTECT>` on the save, and `TestRoleIsAbsentAfterTheFrameReturns` stays green — which is the point: the role is absent because it was never obtained. Second mutation: delete the `New $ROLES` line entirely -> `TestRoleIsAbsentAfterTheFrameReturns` goes red naming the surviving role in `$ROLES`.
- **AC6** — mutation: add `New $ROLES` to `src/OcuPilot/Api/Router.cls` -> `uv run scripts/check-objectscript.py` exits 1 naming file, line and rule. Second mutation: add a `JOB` command to `src/OcuPilot/Kernel/State/Base.cls` -> the same command exits 1 naming the spawn rule. Both must be demonstrated, because Story 1.1's escalated DW-32 recorded that authoring an unvalidated gate is itself the failure mode.
- **AC7** — the pinning test is **not** `TestInstallIsIdempotent`: a fingerprint compared against itself stays equal however wrong the fingerprint is, so that test alone cannot go red. It is pinned by `TestFingerprintChangesWhenAnObjectChanges` in `Test/Installer.cls`, which installs the `probe` profile, disables its privileged routine application, takes the fingerprint, re-installs (repairing it), takes it again, and asserts the two differ. mutation: drop `Enabled` from `StateFingerprint()`'s composition -> `TestFingerprintChangesWhenAnObjectChanges` goes red because the two fingerprints are equal. `Uninstall("probe", 1)` in `OnAfterOneTest` removes everything the test created.
- **AC8** — mutation: replace the ensure-application step's verify-and-repair with a bare `Exists()` early return -> `TestSecondRunRepairsDriftedApplication` goes red naming the still-disabled application. This is the sibling's exact defect, reproduced and pinned.
- **AC9** — mutation: change the placeholder guard to accept `UnknownUser` -> `TestPlaceholderUserIsNotGranted` goes red naming the granted placeholder. Second mutation: remove the reported grant command from the skip branch -> `TestSkippedGrantReportsTheRequiredCommand` goes red naming the empty report, captured through a `Kernel.Audit.Log` probe subclass in the `LogProbe` shape.
- **AC10** — mutation: remove the `Security.Events.Create` guard-then-act call from the ensure-events step -> `TestAuditEventRoundTrips` goes red because `$System.Security.Audit` returns a bare `0` and no row appears in the audit database. Second mutation: make the auditing ensure step always report `enabled-now` -> `TestSecondRunReportsAuditingAlreadyEnabled` goes red naming the wrong outcome. **No mutation disables instance auditing**, and no test writes `AuditEnabled`.
- **AC11** — mutation: make `Uninstall` proceed without checking `pConfirmDataLoss` -> `TestUninstallRefusesWithoutConfirmation` goes red because the probe objects are gone when the test asserts they remain. Second mutation: drop the `%File.RemoveDirectoryTree` call -> `TestUninstallLeavesNoResidue` goes red naming the surviving directory.
- **AC12** — mutation: move the `$NAMESPACE` restore below the `Set tSC = ex.AsStatus()` line in `Install`'s `Catch`, and force a failure inside `%SYS` -> `TestNamespaceIsRestoredFirstOnTheErrorPath` goes red naming the namespace on return. Second mutation: make `Kernel.Utils.RestoreNamespace` a no-op -> the direct test host in `Test/Installer.cls` goes red.

**How each test cleans up, and what is deliberately not reversible:**

- **`Test/Installer.cls`** runs every create, repair and uninstall assertion against the **`probe`** profile. `OnAfterOneTest` calls `Uninstall("probe", 1)` unconditionally, and the residue assertion re-lists databases, resources, roles, applications, mappings and audit events plus `%File.DirectoryExists` on the probe directory. Only two of its methods touch production: the idempotency pair, which calls `Install("")` twice — safe by definition, since a second install is a no-op.
- **`Test/State.cls`** creates one throwaway user and one purpose-built role in `OnBeforeOneTest` and deletes both in `OnAfterOneTest`, checking `Exists()` on each afterwards. It must **not** grant `%Operator`: that role carries `%DB_IRISSYS:RW`, which is a self-escalation primitive — the "denied" user could then `Set $ROLES` to anything and log in as `_SYSTEM`, and the denial assertions would fail for a reason unrelated to this story. Grant `%Admin_Operate:U` through the purpose-built role instead, and assert with `$SYSTEM.Security.CheckUserPermission` in setup that the user actually holds it — `Security.Users.Create` silently accepts a role name that does not exist.
- **Impersonation is confined to one method frame:** `New $ROLES` then `$SYSTEM.Security.Login(<user>)`, the guarded access inside a `Try`, the exception captured, and the assertion made **after** the method returns. `New $ROLES` restores both `$ROLES` and `$USERNAME` on the normal path and on the exception path (verified). Do the absolute minimum inside the frame — a de-privileged process cannot necessarily execute further code. Never rehearse this at a terminal: `NEW` in direct mode raises a stack level that persists until `QUIT`, so it will look broken when it is not.
- **Deliberately not reversible, by design:** the production install itself — the `OCUPILOT` database, `%DB_OCUPILOT`, `OcuPilotAdmin` (resource and role), the `OcuPilotState` application, the `OcuPilot*` mapping, the registered audit event, the role grant, and `AuditEnabled = 1`. These are the story's deliverable and Stories 1.4, 1.5, 1.16, 1.17 and Epics 3, 5 and 10 inherit them. **No test calls `Uninstall("")`**, and no test writes `AuditEnabled`.
- **Residue that survives every cleanup and cannot be removed:** audit rows. `Security.Users.Delete()` does not touch `%SYS.Audit`, so the throwaway user's denial rows and the security-change rows for every created and deleted object remain permanently. That is correct — erasing audit history to tidy a test run would be worse than the noise — and it is also useful evidence when reading a failed run.
- Any agent probing this instance concurrently should use a per-agent name suffix, not a bare shared prefix: IRIS role and resource names are case-insensitive (`NameLowerCase` is the IdKey), so two agents using the same prefix in different cases will delete each other's objects and each report a clean sweep.

**Manual checks:**

- Confirm the compiled `%Persistent` classes were given their **natural** data globals (`^OcuPilot.Kernel.State.StampD`, not a hashed name) and that those globals resolve to the guarded database — read `^|"^^<manager-dir>ocupilot/"|…` directly. A hashed global name would silently escape the `OcuPilot*` mapping and defeat the whole story; this is what the 29-character class-name rule exists to prevent.
- Confirm no `.cls` under `src/OcuPilot/` contains the substring `iris_` — the checker forbids it, and installer doc comments naturally want to name the MCP tools that load and compile them. Keep tool names in this spec, not in the source.
- Confirm `.vscode/settings.json` still carries `objectscript.conn.active: false`; loading and compiling go through the MCP tools only.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

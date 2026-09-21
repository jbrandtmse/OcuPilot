# OcuPilot

<p align="center">
  <img src="logo/OcuPilot-Logo-web.png" alt="OcuPilot logo" width="360">
</p>

**OcuPilot is an agentic System Management Portal for InterSystems IRIS** — an Angular rebuild of the
IRIS Management Portal, served from the IRIS instance itself, built around an **agent co-pilot**: a
panel docked on the right of every screen, the way VS Code docks its secondary side bar. The agent
knows which screen the user is looking at, answers questions about it, and changes settings through
tools that run strictly as the logged-in user — every write it proposes is shown, reviewed, and
confirmed before it runs.

It's being built for InterSystems' [**"Build Your Own Management
Portal"**](https://openexchange.intersystems.com/contest/48) programming contest
([announcement](https://community.intersystems.com/post/intersystems-programming-contest-build-your-own-management-portal)),
Open Exchange contest 48 — submissions close **2026-09-27 23:59 EST**. The contest names six portal
areas, and OcuPilot rebuilds all six as screens wired live to IRIS's own REST management APIs, chiefly
the hidden `/api/admin` v2 service:

- Web applications and a REST API explorer
- Users, roles, resources, and services (permissions)
- Security and secrets — SSL/TLS, X.509, LDAP, OAuth 2.0, wallet, and audit configuration
- Task scheduling and history
- OS management — processes, locks, system usage, CPU/memory, databases, and devices
- The logs

Only a handful of endpoints (`messages.log`, the application error log, the agent runtime) are new
server code — the rest is UI and an agent layered over an API IRIS already exposes. The agent is
bring-your-own-model: OpenAI, Anthropic, Google Gemini, or any OpenAI-compatible endpoint,
configured on first login. OcuPilot installs as one IPM module, and the Docker Compose
workspace in this repo self-installs it on start; it runs on IRIS Community and IRIS for Health
Community.

**The OpenAI-compatible option is the privacy option.** A small model served on your own network —
Ollama, vLLM or LM Studio on the instance's host or beside it — is configured by declaring the
endpoint local, needs no API key, and sends no screen data and no log text off your own network:
the context chip says as much, and a call to such an endpoint does not go through a configured
outbound proxy either. The caveat is capability, not privacy: OcuPilot's read path works with a modest local
model, while the write path asks the model for tool calls carrying several fields at once, so a
model that cannot form those reliably will propose changes you have to reject. Size the local model
for what you intend to do with it. (The capability sentence is an **inference** from the write
path's multi-field tool-call shape, not a measurement: no verification here makes a live provider
call.)

Past the contest, the goal is full parity with the classic System Management Portal, harvesting from
sibling projects — **iris-session-agent** for the agent core and
[**iris-execute-mcp-v2**](https://github.com/jbrandtmse/iris-execute-mcp-v2) for its governance model —
until OcuPilot is the administration portal InterSystems itself points at.

**Status:** planning is complete and implementation is starting under [src/OcuPilot/](src/OcuPilot/).
See the [original idea](docs/initial-idea.md), the [research
report](_bmad-output/planning-artifacts/research/technical-ocupilot-portal-feature-landscape-2026-09-08/research.md),
the [feature
catalog](_bmad-output/planning-artifacts/research/technical-ocupilot-portal-feature-landscape-2026-09-08/feature-catalog.md),
and the [product brief](_bmad-output/planning-artifacts/briefs/brief-OcuPilot-2026-09-08/brief.md) for
the full plan.

## Development sandbox

This repo doubles as the **InterSystems IRIS for Health Community Edition** sandbox OcuPilot is built
and tested against — one Docker Compose service with **durable storage**, wired up two ways: for VS
Code, so ObjectScript editing, compiling, and debugging work out of the box; and for agents — Claude
Code, Copilot, Cursor — via the [IRIS MCP server suite](#optional-iris-mcp-server-suite), which gives
them direct tooling for development, administration, interoperability, operations, and data against
this instance. A throwaway IRIS an agent can safely drive, break, and rebuild.

The `HSCUSTOM` namespace is the default target for everything here.

## What this project is

| Piece | Purpose |
| --- | --- |
| [src/OcuPilot/](src/OcuPilot/) | Project ObjectScript source — classes, includes, and eventually the IPM module manifest. The container start hook loads and compiles this whole tree on every start; see [Project source layout](CLAUDE.md#project-source-layout) |
| [docs/initial-idea.md](docs/initial-idea.md) | The owner's original project brief |
| [_bmad-output/planning-artifacts/](_bmad-output/planning-artifacts/) | Research, feature catalog, and product brief produced by the BMAD Method planning process |
| [logo/](logo/) | The OcuPilot logo, full-size and web-optimized |
| [docker-compose.yml](docker-compose.yml) | Runs `intersystems/irishealth-community` at the explicit `2026.2` tag as `ocupilot`, publishing 1973→1972 (SuperServer) and 52774→52773 (Management Portal), with `ISC_DATA_DIRECTORY=/durable/iris`, the `--after` start hook and the install health check |
| [scripts/container-start.sh](scripts/container-start.sh) | The `--after` start hook: resolves the install namespace, marks an `installed` version stamp `installing`, compiles `src/OcuPilot/`, calls `Installer.StartPath`, records that this container start's install succeeded, exits non-zero on failure |
| [scripts/container-health.sh](scripts/container-health.sh) | The compose health probe: reports healthy only once this container start's install has recorded success and `Installer.GateStatus()` reads `installed` at the deployed schema version |
| [scripts/smoke.sh](scripts/smoke.sh) | The one smoke entry point CI and Epic 17's clean-clone run both call; its assertions live in `OcuPilot.Install.Smoke`, inside the instance — see [The smoke script](#the-smoke-script-story-117) |
| [.github/workflows/ci.yml](.github/workflows/ci.yml) | Every gate this repository has, run on every change — see [What CI runs](#what-ci-runs-story-117) |
| [iris-data/](iris-data/) | The durable-storage bind mount (`./iris-data` → `/durable`). Tracked in git as an empty folder — see [Durable storage](#durable-storage) |
| [ATTRIBUTIONS.md](ATTRIBUTIONS.md) | Third-party material redistributed inside OcuPilot and where each license travels — the two vendored font families and their OFL texts, the npm license file, and the read-only InterSystems reference exports |
| [ocupilot.code-workspace](ocupilot.code-workspace) | The `intersystems.servers` definition for the container — the connection profile Server Manager and the ObjectScript extension resolve against |
| [.vscode/settings.json](.vscode/settings.json) | The `objectscript.conn` that references that profile, including the `active` toggle — see [VS Code / ObjectScript setup](#vs-code--objectscript-setup) |
| [LICENSE](LICENSE) | MIT |

## Prerequisites

- **[Docker Desktop](https://www.docker.com/products/docker-desktop/)** (or any Docker Engine with Compose v2) — running before you start.
- **[InterSystems ObjectScript Extension Pack](https://marketplace.visualstudio.com/items?itemName=intersystems-community.objectscript-pack)** for VS Code (extension ID `intersystems-community.objectscript-pack`). This bundles the ObjectScript language server, the Server Manager, and the InterSystems Language Server.

## Bringing the container up

```bash
# from the project root
docker compose up -d --wait
```

One command, first time, on a clean clone (FR-67): this pulls the image (pinned to an explicit
`2026.2` tag, never the vendor's rolling continuous-delivery alias — see [Installer: protected state,
auditing and the start path](#installer-protected-state-auditing-and-the-start-path)), initializes
the instance into `./iris-data`, and then runs OcuPilot's own install to completion before the
container reports healthy. `--wait` blocks until that health check passes rather than returning as
soon as the container starts, so the command's own exit is the "installed and reachable" signal —
no separate "watch the log until it looks done" step. First start takes a few minutes; watch
progress with:

```bash
docker compose logs -f iris
```

**`durable-init` runs first.** A one-shot service, as root in the same pinned image, makes
`./iris-data` writable by the image's own user (`irisowner`, uid 51773) before `iris` starts: IRIS
has to create `/durable/iris`, and on Linux a bind mount keeps the host's ownership, so a directory
your user or root owns is one IRIS cannot write. When uid 51773 can already write it (Docker
Desktop, or a directory it already owns) the service changes nothing; otherwise it takes ownership
of `./iris-data` itself, never of anything under it. `iris` starts only once it has exited 0, and
`docker compose logs durable-init` says which it did.

If install fails, the start hook exits non-zero and the container stops with exit code 1. The
compose file's restart policy, `on-failure:3`, starts it again up to three times and then leaves
it stopped, so a failure that repeats does not re-run install in an endless loop. The restarts
come within seconds of each other (a deterministic failure used all four attempts in about eight
seconds on a throwaway container), so they only help with a failure that clears that quickly.
`docker compose ps -a` then shows the container exited and `docker compose logs iris` names the
failing step; fix the cause and run `docker compose up -d --wait` again.

The three restarts are counted over the container's whole life, not per incident: any non-zero
exit uses one, including a crash long after a healthy start, and the count starts again only
when the container is started by hand (`docker compose up -d --wait`). Docker's documentation
also says an `on-failure` container is not restarted after a Docker Desktop restart or a reboot;
bring it back the same way.

### Verify

- **Management Portal:** <http://localhost:52774/csp/sys/UtilHome.csp>
- **Credentials:** `_SYSTEM` / `SYS` — the container start path unexpires this account's password
  on its first install (see below), so there is no manual step and no forced change-password
  prompt. An install through IPM never unexpires anything.
- **Namespace:** `HSCUSTOM`
- **Shell into the instance:** `docker compose exec iris iris session iris -U HSCUSTOM`
- **Confirmed authenticated:** `curl -I -u _SYSTEM:SYS http://localhost:52774/api/atelier/` →
  `HTTP 200`, which is also the check that proves the password is unexpired.

### Everyday commands

```bash
docker compose stop        # stop, keep the data
docker compose start       # start again
docker compose restart     # restart
docker compose down        # remove the container (data in ./iris-data survives)
docker compose ps          # status
```

To start completely fresh, `docker compose down` and then delete the contents of `./iris-data` (keeping
`.gitkeep`) before bringing it back up.

## Durable storage

`ISC_DATA_DIRECTORY=/durable/iris` tells IRIS to keep its databases, journals, and configuration on the
bind-mounted `./iris-data` directory instead of inside the container's writable layer, so the instance
survives `docker compose down` and image upgrades.

Those files are machine-local instance state and must never be committed. [.gitignore](.gitignore) keeps
the folder in the repository while ignoring everything in it:

```gitignore
iris-data/*
!iris-data/.gitkeep
```

So a fresh clone gets an empty `iris-data/` ready to be populated on first `docker compose up`.

## Installer: protected state, auditing and the start path

`OcuPilot.Install.Installer` (Story 1.3) creates OcuPilot's own protected state — a dedicated
database, guarded by a `%DB_` resource no ordinary role holds, plus the `OcuPilotAdmin`
resource and role, a privileged routine application, and a global mapping — so agent
definitions, switches, the ledger and transcripts land somewhere a holder of
`%DB_<install-namespace>:RW` plus `%Admin_Operate` cannot read or forge (AD-9, FR-29).

That protects the **data**, and only the data. OcuPilot's **code** deliberately stays in the
install namespace's ordinary database, because in IRIS database READ *is* routine-execution
permission and hiding the packages would make OcuPilot unrunnable by exactly the users it is
for. So the same `%DB_<install-namespace>:RW` holder can still rewrite
`OcuPilot.Kernel.State.Base`, the one class the privileged routine application whitelists, and
reach the protected globals that way. Code integrity is a separate control (source review,
deployment discipline), not something this database boundary provides — see AD-9.

As a deliberate security-posture change, install also **enables instance auditing** if it is
off and registers OcuPilot's own audit event (`OcuPilot/Security/RoleGranted`) under
`Security.Events` — a Community Edition container that has never had auditing touched starts
producing audit rows for OcuPilot's writes from its first install onward (FR-66).

Install grants the `OcuPilotAdmin` role to the installing user when that user is a real named
account. When it is not — an empty identity, `UnknownUser`, `_PUBLIC`, or any name that does
not resolve to an account on this instance — the grant is skipped (never silently) and the run
reports the exact command an operator must run to grant it by hand:

```objectscript
Set $NAMESPACE="%SYS" Set tRoles="OcuPilotAdmin" Do ##class(Security.Users).AddRoles("<a named account that exists on this instance>", .tRoles)
```

The `%SYS` switch is not optional: `Security.Users` is mapped into `%SYS` only, so without it
the command raises `<CLASS DOES NOT EXIST>` in the install namespace. And the target is always
supplied by the operator — the installer never names a rejected placeholder back as something
to grant to, since granting OcuPilot's administrative role to `UnknownUser` would hand it to
every anonymous caller (AD-21).

`Uninstall(profile, 1)` reverses the objects above — mapping, application, role, both
resources, the database config entry, `IRIS.DAT`, the directory and the audit event
registration. It **does not** turn instance auditing back off: other event types depend on it,
and that switch was an instance-wide posture change rather than one of OcuPilot's own objects.
Without `pConfirmDataLoss = 1` the call changes nothing and returns an error naming what it
would have destroyed.

Uninstall removes the opt-in demo fixtures first, reading the inventory install recorded for
them. If any fixture object cannot be removed, that inventory is kept for a retry, and Uninstall
then stops before it removes the database the inventory lives in: it removes nothing else, logs
each inventory row that remains with whether its object is still on the instance, and returns an
error naming them. Clear what blocked the removal (the logged warnings say which delete failed)
and run it again; the retry skips whatever the first attempt already removed.

It also stops, the same way, when it cannot read that inventory at all after removing the
fixtures, because it cannot tell what the inventory still records. The inventory of every
profile is stored in the production profile's protected database, so the remedy is to repair
that state (run `Install` with no profile) and run Uninstall again. The one exception is an
inventory whose privileged routine application (`OcuPilotState`) no longer exists: only a
production uninstall deletes that application, after this check has passed, so a repeat
uninstall reports that it could not check the inventory and completes, rather than failing.
Uninstall cannot tell that apart from `OcuPilotState` having been deleted by hand while demo
fixtures were still recorded, and then it removes the database with their inventory and leaves
those objects behind, so never delete `OcuPilotState` by hand: run Uninstall instead.

### The container start path (Story 1.4)

`docker-compose.yml`'s `--after` hook (`scripts/container-start.sh`) resolves the install
namespace — `HSCUSTOM` if it exists, else `USER`, unless `OCUPILOT_NAMESPACE` names another, and a
namespace that does not exist fails the start rather than falling back
([Choosing the install namespace](#choosing-the-install-namespace-and-the-two-overrides)) —
marks an `installed` version stamp `installing` (see below), loads and compiles
`src/OcuPilot/` from a read-only bind mount, and calls
`OcuPilot.Install.Installer.StartPath(pDemo, pBundleSource)` — the single install entry point the
container uses. The second argument is the built client bundle's directory on the `./ui` mount,
which the hook names on every start, present or not — install is the one place that decides what
an absent bundle means, and it reports a `warn` and carries on (see the next section). The empty
argument means something different: a caller that never asked for a bundle at all, which is every
install run through the IRIS MCP tools or through IPM.
`StartPath` runs `Install("", 1, pBundleSource)` — the second argument asks for the `_SYSTEM` unexpire step,
which only the container start path does (AD-17): on an instance reached through IPM, an expired
`_SYSTEM` may be the operator's choice, so IPM's `Install()` never unexpires anything. Then, only
on success and only when `OCUPILOT_DEMO` is `"1"` in the environment (this repository's own
`docker-compose.yml` sets it), `StartPath` creates the five opt-in demo walkthrough fixtures
(AD-25) through `OcuPilot.Install.Fixture`. Because upgrade is "install
again" (AD-17), this runs on **every** container start against the same durable volume, not only
the first.

Install grants OcuPilot's protected SQL schema to the role that guards its own database, because
the gate above reads the version stamp through dynamic SQL and SQL privileges are enforced
independently of the escalation role's database privilege — without the grant the gate answers
`INSTALL.UNREADABLE` to every caller who does not hold `%All`. Install derives the schema from the
class dictionary and reads every table's grant back, failing at `EnsureSqlPrivileges` when one did
not take. The grant is idempotent, so a repeat install changes nothing, but it does mean the
installing account needs `GRANT` on that schema: install fails loudly rather than leaving the gate
wedged. `Uninstall` issues no matching
revoke — the grantee is the protected database's own role, which uninstall removes.

Install does not wait for the demo task fixture (`OcuPilotDemo nightly purge`). It schedules the
task and asks the Task Manager for one run, and the Task Manager runs it at its next once-a-minute
pass, where the task fails by design and suspends itself. The container can therefore report
healthy up to a minute before that task shows as suspended after an error.

Before any web application accepts traffic, `OcuPilot.Api.Router`'s `OnPreDispatch` checks a
version stamp (`OcuPilot.Kernel.State.Version`) and refuses with a `503` envelope
(`INSTALL.INSTALLING`, `INSTALL.FAILED`, `INSTALL.UPGRADEREQUIRED` or `INSTALL.UNREADABLE`) until the stamp reads
`installed` at the deployed schema version (AD-38) — a request arriving mid-install finds a
clear refusal, never half a schema.

A restart at the same schema version installs again too, so the stamp alone cannot tell this
start's install from the one before it. Two things close that gap (AD-38 as amended
2026-09-11):

- Before the hook recompiles `src/OcuPilot/`, it calls `Installer.MarkInstalling()`, which turns
  an `installed` stamp into `installing` without touching its schema version, so the API refuses
  traffic from the start of the recompile until this start's install records its own outcome. A
  `failed` stamp, or no stamp, is left as it is: both already refuse. The call reaches the class
  the previous start compiled, so on a first start on a volume, and on the first start after the
  mark shipped, there is nothing to call; the hook says so in its log and carries on. A mark that
  fails never fails the start. A start that fails before its own install records an outcome (a
  compile error, say) leaves a marked stamp `installing`, with no failing step, until a later
  start's install records one: the API answers `INSTALL.INSTALLING` meanwhile, the hook's log
  names the failure, and the container stops after its restart retries. For the same reason an
  upgrade on the container path answers `INSTALL.INSTALLING` while it runs, not
  `INSTALL.UPGRADEREQUIRED`: that code is for code newer than an `installed` stamp with no
  install run yet, as after an IPM upgrade before its `<Invoke>`, or a start whose mark was
  skipped or failed.
- The compose `healthcheck` reads the stamp through `iris session` (the image ships no HTTP
  client at all), but only once the hook has written `/tmp/ocupilot-start-ok` after seeing
  `STARTPATH-OK`. That file holds a key for the container start (the kernel's boot id and the
  start time of the container's PID 1), so after a restart an earlier start's file no longer
  matches and the check waits for this start's install, even while the stamp from the last start
  still reads `installed`. A later failed install still turns the check unhealthy, through the
  stamp. The API gate keeps reading the stamp alone: an install through IPM has no start hook.

The trade: the key follows the container, not the IRIS instance inside it. On a throwaway
container, `iris restart` inside the running container left PID 1 and the file in place, the hook
did not run again, and the check stayed healthy on the strength of that container start's install
and the stamp. Restart the container, not IRIS, when you want install to run again.

Installs and uninstalls of one profile never overlap. `Install`, `StartPath`, the mark and
`Uninstall` take that profile's install lock (an extended reference into `%SYS`, so an ordinary
account cannot hold it): `Install` holds it until the stamp records the outcome, `StartPath`
across that install and the demo fixtures it creates afterwards, the mark while it marks, and
`Uninstall` until it returns. A second caller waits up to ten seconds. It runs once the first has
finished, and refuses, naming the profile and changing nothing, only if it is still blocked by
then.

A stored schema version newer than the deployed code (a downgrade) is refused outright, naming
both versions and changing nothing (on the container path the start's mark, made by the newer
code the previous start compiled, has already turned the stamp `installing`, and the refusal
leaves it so); a stored version behind the deployed code runs every
registered migration step in ascending order before the phase becomes `installed`.

Invoking the installer directly through the IRIS MCP tools — `iris_execute_classmethod` on
`OcuPilot.Install.Installer`, method `Install` or `StartPath`, against the `ocupilot-slot-a` server
profile and the `HSCUSTOM` namespace — still works and is how Story 1.3 verified this class
before the start hook existed; the container path above is what a clean clone actually uses.
`StartPath` is that path's own entry: on a genuinely first install it also unexpires `_SYSTEM`,
and with its demo argument set it creates the demo fixtures. `Install` does neither, and it is
the form IPM's `<Invoke>` (Story 1.16) is to call.

### The web applications and the client bundle (Stories 1.5 and 1.17)

Install creates every one of OcuPilot's web applications, so the Docker path and the IPM path
cannot produce different ones, and `Uninstall` removes them:

| Path | Authentication | Dispatch class | Roles | Other |
| --- | --- | --- | --- | --- |
| `/ocupilot` | Unauthenticated | `OcuPilot.Api.StaticHandler` | one matching role, `OcuPilotShell` | serves no files itself; its path is the bundle directory |
| `/api/ocupilot` | Password | `OcuPilot.Api.Router` | none | JWT on, 60 s access / 900 s refresh, group `%ISCMgtPortal` |
| `/api/ocupilot/readiness` | Unauthenticated | `OcuPilot.Api.Readiness` | one matching role, `OcuPilotReadiness` | see [The readiness endpoint](#the-readiness-endpoint-story-117) |

None carries an application resource. `OcuPilotShell` and `OcuPilotReadiness` each grant **read
on the install namespace's code database and nothing else**: in IRIS database READ is
routine-execution permission, so without it an anonymous request cannot load the application's
dispatch class and IRIS answers `500` with a `<PROTECT>` error that also names the database
directory. They buy the right to run OcuPilot's own code and no data privilege beyond it —
OcuPilot's state lives in the separate protected database, which neither role reaches (AD-9,
AD-21). The authenticated API carries no matching role at all, so a request there runs with
exactly the privileges its own account holds (AD-8).

**An API account needs that same read, as a prerequisite.** Because database READ is
routine-execution permission, an account calling `/api/ocupilot` must hold read on the install
namespace's database, on top of whatever a screen's own privilege set requires. Two grants are
really at issue and on this container they are one: the framework's access check tests the
resource guarding the namespace's **default global** database
(`$Piece($zu(90,21,<namespace>),"^",4)`, `%DB_HSCUSTOM` here), while loading OcuPilot's own classes
needs read on the resource guarding its **routine** database — what
`OcuPilot.Install.Installer.CodeDatabaseResource` derives from `SYS.Database`, also `%DB_HSCUSTOM`
here because `HSCUSTOM`'s two databases are the same one. On a namespace configured with separate
globals and routines databases they are two grants, and an account needs both. Without the first
the framework's own access check refuses the request before any OcuPilot code runs, and the caller
is answered **`403` with an empty body**:
`%CSP.REST.Page()` sets that status inline rather than through OcuPilot's response writer, so
there is no envelope to read and nothing names the missing grant. Measured on a throwaway
container, 2026-09-21, for an account granted `%Admin_Secure:USE` and `%DB_IRISSYS:READ` and no
read on that database; `POST /api/ocupilot/login` still answers `200`, because the JWT token
endpoints are the framework's own and reach no OcuPilot class. Grant the read and the refusal
becomes whichever of OcuPilot's own gates actually applies, with the envelope that names it.

**The list of applications is one declaration.** Each is a single entry in the `XData Manifest`
block of [src/OcuPilot/Install/Roster.cls](src/OcuPilot/Install/Roster.cls), carrying its path,
its description, the name of its one matching role, the properties `module.xml` states and the
properties install computes. The installer iterates that list; so do the generated manifest, the
install-time assertion and the state fingerprint. A fourth application is one edit to the roster
and no edit anywhere else.

**Install refuses to adopt an application it did not put there.** A web application at one of
those three paths is OcuPilot's when `OcuPilot.Kernel.State.WebApp` holds a provenance record
for it, or — on an instance installed before that record existed, and on the IPM path, where
IPM's own `<WebApplication>` elements create the applications before the `<Invoke>` runs — when
it dispatches to the class the roster declares. Anything else at one of those paths is somebody
else's, and install refuses naming the path, the class the roster declares and the class it
found, creating and repairing nothing. `Uninstall` is the other half: it removes only what the
record says install created, and reports anything else it finds at those paths rather than
deleting it.

**Two things an API caller needs.** Read on that same database, or the framework's own
`%CSP.REST.AccessCheck` refuses the request before any OcuPilot code runs and answers a bare `403`
that OcuPilot never sees — see the roles section above for which resource and what was measured.
And `USE` on at least one `%Admin_*` resource, or the router answers one `403` envelope with the
code `AUTH.NOADMIN` (FR-65).

**The bundle.** Build it with `npm --prefix ui run build`; the output lands in
`ui/dist/ocupilot-ui/browser/`, which the container sees through the read-only `./ui` mount. The
start hook passes that directory to `StartPath`, and install copies it into the shell
application's own directory — `<data directory>csp/ocupilot/`, resolved on the instance from the
matched application's name and never from anything a request carries. Install **never fails**
because the bundle is missing: it reports one `warn` naming the directory, completes, and
`/ocupilot` answers `503` with the code `STATIC.NOBUNDLE` until a build arrives and the container
is restarted. An install run without that argument — through the IRIS MCP tools, or the
`Install()` the IPM manifest invokes — leaves whatever bundle is already installed exactly as it
is. On the IPM path as a whole the bundle still moves: IPM's own `<FileCopy>` puts it in place
during `Activate`, before the `When="After"` `<Invoke>` runs, so `Install()` finds it already
there and correctly leaves it alone.

`index.html` is served with `Cache-Control: no-store, no-cache, must-revalidate` and every hashed
asset with `public, max-age=31536000, immutable`, so a restart that installs a new bundle is one
reload away from being current (DW-3). Each document response also carries a
`Content-Security-Policy` naming only the instance's own origin, with a freshly generated nonce
substituted into the `ngCspNonce` placeholder the built page carries — that nonce is what admits
the style elements Angular injects at runtime, and nothing else.

Anything the handler cannot resolve to a file inside the bundle directory answers `index.html`
with `200`, which is what makes a pasted or reloaded client route work. A missing hashed asset
therefore reaches the browser as a MIME-type error rather than a `404` — an accepted trade-off,
recorded in AD-21.

### The readiness endpoint (Story 1.17)

**One URL a machine outside the instance can ask, and get a believable answer to.** Before it,
nothing in this repository could say "installed and working" and be believed: the only way to ask
was an `iris session` inside the container.

```bash
curl -s http://localhost:52774/api/ocupilot/readiness/
# {"installed":true,"version":"1","state":"installed"}
```

**The trailing slash is required**, and that is IRIS's own rule for every REST web application
rather than anything of OcuPilot's: the vendor's own `/api/atelier` answers 404 without it and
200 with it. Here the bare path additionally resolves to the parent `/api/ocupilot` application,
which is password-authenticated and has no such route, so it answers 401 to an anonymous caller.

It reports three things and nothing else (AD-45): whether the instance is installed, the version
stamp, and which of the install gate's five states it is in — `installed`, `installing`, `failed`,
`upgraderequired` or `unreadable`. It names no namespace, no directory, no account and **no failing step**: a
failed install is distinguishable from one that never started, which is what the state is for, and
the step that failed stays on the version row and in the container logs. It requires no
credentials, resolves no user, and reads the same `Installer.GateStatus()` ladder
`scripts/container-health.sh` reads. The two differ only where SQL privileges matter: the health
probe runs in an `iris session` holding `%All`, so a grant revoked after start still reads
`installed` there while readiness reports `unreadable`.

The container health check is deliberately **not** rewritten to call it: the pinned image ships no
HTTP client at all, which is why the probe shells `iris session`.

### The smoke script (Story 1.17)

**`scripts/smoke.sh` is the definition of installed-and-working.** CI runs it against a throwaway
container, and so will Epic 17's clean-clone run; the two differ only in what created the
instance.

```bash
sh scripts/smoke.sh --container ocupilot-fresh --user _SYSTEM --password SYS
```

It takes `--container NAME`, or `--compose-file FILE [--project NAME]`, or neither (an instance
with `iris` on the PATH). Its assertions are **not** in the shell script: they live in
`OcuPilot.Install.Smoke`, inside the instance, which is what makes "the same script with the same
assertions" literally true rather than a claim about two implementations that happen to agree.
The script locates an instance, runs that class, prints what it returns and maps its verdict to
an exit code.

It checks readiness over real HTTP as an anonymous caller, the static shell, a deep link, sign-in
minting a token pair, `GET /instance`, `GET /namespaces`, `GET /navigation`, the web applications,
users and SSL/TLS configurations lists' and the task schedule's screen reads
(`GET /screens/webapp.list/read?maxRows=1`,
`GET /screens/permissions.users/read?maxRows=1`, `GET /screens/security.ssl/read?maxRows=1` and
`GET /screens/tasks.schedule/read?maxRows=1`, each needing `%DB_IRISSYS:READ` with
`%Admin_Secure:USE` for the first three and `%Admin_Task:USE` for the fourth),
a bounded page of the instance's console log (`GET /logs/messages?maxBytes=4096`, needing
`%Admin_Operate:USE`),
signing that pair out again (a Bearer `POST /logout`, then a refresh with the minted refresh token
that must be refused), the audit-event registration, and the demo fixtures when the opt-in flag
was set. It reports the counts it executed on every run, passed or failed, and it lists what it
cannot check yet — the first live list of each remaining portal area (Epic 2), the confirmed
agent write and the audit row it leaves (Epic 3) — naming the epic that makes each real.

**A run that executed nothing is a failure.** Every check skipped, or an empty check list, exits
non-zero and says so. A gate that reports "found nothing wrong" when it looked at nothing is
indistinguishable from one that passed, and a smoke script is exactly the gate a release leans on.

### What CI runs (Story 1.17)

[.github/workflows/ci.yml](.github/workflows/ci.yml) is the first place in this repository where a
gate is run rather than described. Four jobs, split by what each needs:

| Job | Needs | Runs |
| --- | --- | --- |
| `gates` | a checkout, Node and uv | `npm ci`, `npm run build`, `npm test`, `uv run scripts/check-objectscript.py`, `uv run scripts/test_check_objectscript.py`, `bash scripts/lint-docs.sh` — **once per Node band** `ui/package.json` declares (`22.22.3`, `24.15.0`, `26.0.0`, each band's floor), `fail-fast: false`. `ui/tools/ci.test.mjs` holds that list equal to `engines.node` in both directions, so a declared band CI never runs is red |
| `instance` | a throwaway container | first `scripts/ci-durable-ownership.sh` (the Linux durable-directory reproduction, on named volumes), then the client build, `scripts/ci-throwaway.sh up`, `scripts/wait-readiness.sh`, `ui/tools/ci-runner.mjs`, `scripts/smoke.sh`, `npm run test:browser`, then — on failure only — `scripts/ci-throwaway.sh logs`, and always `scripts/ci-throwaway.sh down` |
| `images` | both stock Community editions at the pinned `2026.2` | `scripts/ci-image-compile.sh` per edition: `src/OcuPilot/` compiles, and the admin API reports v2 through `AdminPort`'s own version read — a compile and a version read, not an HTTP request (NFR-13) |
| `package` | two throwaway containers with **no network at all** | the client build, then `scripts/ci-ipm-archive.sh`: the distributable IPM archive is built on one fresh instance and loaded on a second, which `scripts/smoke.sh` then reports on. Runs beside `instance` rather than after it |

**The ObjectScript suite runs one class at a time.** `ui/tools/ci-runner.mjs` drives
`scripts/ci-unit-test.sh` once per class and confirms each run landed — its index, its method
count, its failure count — before the next starts, then reports the job red if any two of its own
runs overlapped in wall-clock time. The suite's classes share one instance and one set of
fixtures; on 2026-09-11 eighteen were started together, a probe uninstall raced a probe install,
and the probe database was left mounted over a deleted directory until a human restarted the
instance.

**Every tool is pinned, and every script runs under its own shell.** Each action is pinned to the
full commit SHA its tag resolved to, every job runs on `ubuntu-24.04`, `setup-uv` installs uv
`0.12.9`, `.python-version` pins Python `3.12.14` for every `uv run`, and both markdownlint call
sites run `markdownlint-cli2@0.23.2`. Each `scripts/*.sh` is invoked with the shell its shebang
declares. `ui/tools/ci.test.mjs` asserts every pin and every shell, and
`ui/tools/shell-scripts.test.mjs` parses every script under its shell (and under dash for `sh`)
and executes `wait-readiness.sh`, `ci-image-compile.sh` and `container-health.sh` against stubs.

**Nothing in CI publishes, lists, releases or pushes to any registry**, and nothing references a
secret. `ui/tools/ci.test.mjs` asserts each of those absences, and holds the gates it declares
equal to the workflow's own `run:` commands in both directions, so a gate deleted from either
side is red under `npm test`.

Every gate reports the size of what it looked at — the file count a checker scanned, the class
count the runner ran, the checks the smoke script executed — so "found nothing wrong" and "looked
at nothing" are distinguishable.

### Verifying the start path against a throwaway container

The running `ocupilot` container and its `./iris-data` volume hold state every later story
depends on and must never be reset, restarted, or recreated to test this. Verifying the pin, the
one-command bring-up, and the "fails loudly" behavior instead uses a **throwaway** container
started from a standalone Compose file of its own, written by hand in a scratch directory. Never
point `docker compose` at this repository's `docker-compose.yml` for a throwaway, under any
project name and with any override: that file names the container `ocupilot` and mounts
`./iris-data`, so one missing override line reaches the live instance. The scratch file gives the
throwaway its own project and container name, its own host ports (never 52774/1973), its own
data directory, and scratch copies of `src/` and `scripts/`, so a mutation for a check never
touches this repository's files:

```yaml
# <scratch-dir>/compose.yml -- THROWAWAY ONLY, never this repository's docker-compose.yml
name: ocupilot-fresh
services:
  iris:
    image: intersystems/irishealth-community:2026.2
    container_name: ocupilot-fresh
    restart: on-failure:3
    ports:
      - "1975:1972"
      - "52776:52773"
    environment:
      ISC_DATA_DIRECTORY: /durable/iris
      OCUPILOT_DEMO: "1"
    volumes:
      - <scratch-dir>/data:/durable
      - <scratch-dir>/src:/opt/ocupilot/src:ro
      - <scratch-dir>/scripts:/opt/ocupilot/scripts:ro
      # Copy ui/dist/ocupilot-ui/browser/ into <scratch-dir>/ui/dist/ocupilot-ui/browser/ to
      # exercise the bundle copy, or leave the directory out to exercise the STATIC.NOBUNDLE
      # path. Never mount this repository's own ui/ — `npm test` deletes ui/dist.
      - <scratch-dir>/ui:/opt/ocupilot/ui:ro
    command: ["--after", "sh /opt/ocupilot/scripts/container-start.sh"]
    depends_on:
      durable-init:
        condition: service_completed_successfully
    healthcheck:
      test: ["CMD", "sh", "/opt/ocupilot/scripts/container-health.sh"]
      interval: 10s
      timeout: 15s
      retries: 30
      start_period: 60s
  durable-init:
    image: intersystems/irishealth-community:2026.2
    user: "0:0"
    entrypoint: ["sh", "/opt/ocupilot/scripts/durable-init.sh"]
    restart: "no"
    volumes:
      - <scratch-dir>/data:/durable
      - <scratch-dir>/scripts:/opt/ocupilot/scripts:ro
```

The `durable-init` service is what lets IRIS write `<scratch-dir>/data` on Linux, exactly as it
does for `./iris-data`. Afterwards the tree belongs to uid 51773 and `rm -rf` refuses it, so
remove the data directory as root — `docker run --rm --user 0:0 --entrypoint sh -v
<scratch-dir>:/scratch intersystems/irishealth-community:2026.2 -c 'rm -rf /scratch/data'`.
`scripts/ci-throwaway.sh` writes this file and does the removal for you.

```bash
docker compose -f <scratch-dir>/compose.yml up -d --wait
# ... assert against the throwaway container only ...
docker compose -f <scratch-dir>/compose.yml down -v
```

Copy the `restart` policy, `depends_on`, `healthcheck`, `command` and the `durable-init` service
from `docker-compose.yml` when they change,
so a failing start behaves on the throwaway as it would here, and remove the scratch directory
afterwards.

## Installing with IPM (Story 1.16)

The container start path is one way in; [module.xml](module.xml) at the repository root is the
other. An operator who already runs the InterSystems Package Manager installs OcuPilot with
`zpm`, and gets exactly the install the container gets: the manifest's `<Invoke>` calls
`OcuPilot.Install.Installer.Install()` — the same method `StartPath` delegates to, with no
second entry point and no install logic in the XML (AD-17).

```objectscript
; From an IRIS session in the namespace you want OcuPilot installed into:
zpm "load -dev /path/to/OcuPilot"   ; from a clone, with the client bundle already built
zpm "install ocupilot"              ; once a registry carries it -- none does yet
```

Three things follow from that single entry point, and each is deliberate:

- **The install namespace is the namespace you install from.** `zpm install` runs the lifecycle
  in your current namespace, and install accepts it. It refuses only a system namespace (`%SYS`,
  any `%`-prefixed name, and the vendor's own library namespaces), and it refuses outright on an
  instance carrying neither `HSCUSTOM` nor `USER`, naming both candidates rather than guessing.
- **An IPM install never unexpires an account.** The `<Invoke>` carries no `<Arg>`, so
  `Install()`'s `pUnexpire` keeps its `0` default. A fresh Community instance expires `_SYSTEM`
  on first login and the container start path clears that; on an instance reached through IPM an
  expired account may be your deliberate choice, so nothing here touches it.
- **No demo fixtures.** Those are the container start path's, behind `OCUPILOT_DEMO` (AD-25).

The manifest ships `<Resource Name="OcuPilot.PKG"/>` and, out of scope for a shipped install,
`<Resource Name="OcuPilot.Test.PKG" Scope="test"/>`. The built Angular bundle travels with the
package as a `<FileCopy>`, so installing needs no Node toolchain — but **`zpm load` from a clone
does need the bundle built first** (`cd ui && npm run build`), because the copy's source is
`ui/dist/ocupilot-ui/browser/` and IPM fails the Activate phase if it is not there.

### Choosing the install namespace, and the two overrides

| Path | Namespace | Override |
| --- | --- | --- |
| IPM | whichever namespace `zpm` runs in | run `zpm` from the namespace you want |
| Container start | `HSCUSTOM` if it exists, else `USER` | `OCUPILOT_NAMESPACE` |
| Either, on an instance with neither `HSCUSTOM` nor `USER` | none — install refuses, naming both | create one of them |

`OCUPILOT_NAMESPACE` is an optional environment variable on the container, the same shape as
`OCUPILOT_DEMO`: nothing is required to run. Set it in `docker-compose.yml`'s `environment:`
block to install into a namespace other than the default. **A namespace that does not exist is a
failed start, naming it** — the hook never falls back to a default you did not ask for, so a
typo stops the container rather than installing somewhere unexpected. `scripts/container-health.sh`
reads the same override, so the health check and the install always agree about which namespace
they are talking about.

### `module.xml` is generated, not edited

The manifest is generated from the `XData Manifest` block in
[src/OcuPilot/Install/Roster.cls](src/OcuPilot/Install/Roster.cls) — the same block
`OcuPilot.Install.Installer` reads when it asserts the two web applications' settings, and
`scripts/check-objectscript.py` reads for its fixed package folder set. One declaration, three
consumers, so the manifest and the installer cannot drift.

```bash
cd ui && node tools/ipm-manifest.mjs           # regenerate module.xml from the roster
cd ui && node tools/ipm-manifest.mjs --check    # report drift; exits 1 with the element named
```

The `--check` form runs in `prebuild`, in `prestart` and in `.githooks/pre-commit`, and the
comparison is an equality in both directions: a roster edited without regenerating and a
`module.xml` edited by hand fail identically. To change what OcuPilot installs — a web
application's asserted property, a package folder, the module version — edit the roster and
regenerate.

### Verifying an IPM install against a throwaway container

**An IPM install is a destructive, whole-instance operation, and IPM is not part of this
project's runtime (AD-18).** Never load IPM into, or `zpm install` against, the `ocupilot`
container. [scripts/ci-ipm-archive.sh](scripts/ci-ipm-archive.sh) does the whole rehearsal on
throwaways of its own, and CI's `package` job runs it on every push: it builds the distributable
archive with IPM's local `package` verb on one fresh instance, loads that `.tgz` on a second one,
and reports `scripts/smoke.sh`'s verdict over the result. **Both containers run with
`--network none`**, so nothing either of them does can reach a package registry — and the script
asserts that `%IPM_Repo.Definition` is empty on each, checks the archive's members and its
manifest host-side, removes both containers on exit, interrupt or termination, and refuses the
name of the live instance, of any `ocupilot-slot-*` and of any slot's throwaway. IPM 0.10.5 prints no line naming
the file `package` wrote, so the script reads the artifact back from the directory it wrote into
rather than predicting its name.

```bash
(cd ui && npm run build)   # the manifest copies this bundle into the package
sh scripts/ci-ipm-archive.sh --image intersystems/irishealth-community:2026.2
```

The image ships that offline IPM installer at `/usr/irissys/dist/install/misc/zpm.xml`
(version 0.10.5) but loads none of it: a stock instance carries no `%IPM` or `%ZPM` class at
all, which is what AD-18 means by "a distribution channel, never a runtime dependency". `zpm
test` and `zpm verify` are not used here — `verify` provisions a namespace of its own and
`test` runs `%UnitTest` under a second manager.

**`zpm uninstall` is not `OcuPilot.Install.Installer.Uninstall`.** It removes what the manifest
created — the two web applications, the copied bundle and the loaded classes — and nothing
else. OcuPilot's protected database, its roles and its privileged routine application hold
state, so removing them is a deliberate act behind `Uninstall`'s own `pConfirmDataLoss` flag,
not something an `uninstall` command should do on the operator's behalf. Run
`##class(OcuPilot.Install.Installer).Uninstall("", 1)` **before** `zpm uninstall` if you want
the instance returned to its pre-OcuPilot state; afterwards the installer class is gone.

## VS Code / ObjectScript setup

Open [ocupilot.code-workspace](ocupilot.code-workspace) (**File → Open
Workspace from File…**) rather than the plain folder. This matters for more than convenience — see
[Where the `active` toggle lives](#where-the-active-toggle-lives) below.

The connection is expressed the way the [InterSystems Settings
Reference](https://docs.intersystems.com/components/csp/docbook/DocBook.UI.Page.cls?KEY=GVSCO_settings)
prescribes — a named **server profile**, referenced by name from the connection — split across two files:

| File | Scope | Setting | Holds |
| --- | --- | --- | --- |
| [ocupilot.code-workspace](ocupilot.code-workspace) | Workspace | `intersystems.servers` | The `ocupilot-slot-a` profile: `webServer` scheme/host/port, `superServer` port, `username` |
| [.vscode/settings.json](.vscode/settings.json) | Workspace Folder | `objectscript.conn` | `server` (the profile name), `ns`, `active` |

```jsonc
// ocupilot.code-workspace
"intersystems.servers": {
  "ocupilot-slot-a": {
    "webServer": { "scheme": "http", "host": "localhost", "port": 52774 },
    "superServer": { "port": 1973 },
    "username": "_SYSTEM"
  }
}

// .vscode/settings.json
"objectscript.conn": {
  "server": "ocupilot-slot-a",
  "ns": "HSCUSTOM",
  "active": false        // ← flip this to connect
}
```

`active` ships as **`false`** on purpose, so opening the workspace never attempts a connection to a
container that may not be running. Flip it here, or use the ObjectScript status-bar item — which writes to
this same file.

**No password is stored in the repo.** Server Manager prompts on first connect and saves it in your OS
keychain; an inline `password` property is deprecated by the extension.

### Why a server profile rather than inline host/port

`objectscript.conn` also accepts `host`, `port`, and `https`, but the extension's connection resolver
**never reads them**. It has exactly two branches:

```js
let s = (conn["docker-compose"] && extensionKind !== ExtensionKind.Workspace)
        || !conn.server
        || !config("intersystems.servers", folder).has(conn.server)
      ? "" : conn.server;

if (s !== "") {
  // resolve scheme/host/port/pathPrefix/auth/superServer from intersystems.servers[s]
} else if (conn["docker-compose"]) {
  // probe the running container for its mapped port
}
// ← no third branch: inline host/port is dead config
```

Hence the docs' note on `objectscript.conn.server`: *"Specify only `ns` and `active` when using this
setting."* Note the first clause too — a `docker-compose` block **outranks** `server`, so the two are
mutually exclusive rather than complementary. This project publishes fixed ports (1973, 52774) on
`localhost`, so the profile names them directly and no `docker-compose` block is used.

### The profile name must not match the workspace folder name

Non-obvious, and it silently breaks the `active` toggle. `AtelierAPI.setConnection` starts by testing the
**workspace folder name** against `intersystems.servers`:

```js
let s = configName.toLowerCase();                       // configName = the workspace FOLDER name
if (config("intersystems.servers", configName).has(s)) {
  this.externalServer = true;                           // ← folder name matches a server name
} else {
  s = (...) ? "" : conn.server;
}

this._config = {
  serverName: s,
  active: this.externalServer
        ? !inactiveServerIds.has(s)                     // ← conn.active is IGNORED
        : conn.active,                                  // ← conn.active is honored
  ...
};
```

A match puts the folder in **`externalServer`** mode — intended for server-side `isfs` folders named after
a server — where `active` is read from `inactiveServerIds`, an in-memory set populated only at runtime by
connection failures. Your `"active": false` is parsed and then discarded, so the file watcher's gate
(`api.active && syncLocalChanges != "off"`) stays open and sync keeps running. The write path is guarded
the same way (`externalServer || await Se(...)`, where `Se` persists `conn.active`), so the extension
never records the toggle either.

This folder is `OcuPilot` — which lowercases to `ocupilot` — so the profile is named
**`ocupilot-slot-a`** to stay clear of it. If you rename the directory, check it still differs from the
profile name.

> This bit us once already: the project was renamed from `iris-community-edition` to `OcuPilot` and the
> profile renamed to `ocupilot` at the same time, which collided and silently re-armed the watcher. The
> symptom is that `"active": false` has no effect *and* **Toggle Connection** vanishes from the command
> menu — `externalServer || x.push({... "Disable current connection" ...})` never pushes the item.

### Where the `active` toggle lives

The toggle is in `.vscode/settings.json` deliberately. The extension picks its write target by inspecting
which scope already defines `objectscript.conn`:

```js
const target = config.inspect("conn").workspaceFolderValue
  ? ConfigurationTarget.WorkspaceFolder   // → .vscode/settings.json
  : ConfigurationTarget.Workspace;        // → the .code-workspace file
config.update("conn", { ...existing, active: newValue }, target);
```

Because `.vscode/settings.json` defines the whole `objectscript.conn` object, that first branch always
wins: every connect/disconnect lands there and never churns the shared workspace file. Keeping the object
*complete* at folder scope also means nothing depends on VS Code merging one setting across two files.

This depends on opening the **workspace file**. A folder opened directly makes `.vscode/settings.json`
*Workspace* scope, leaving `workspaceFolderValue` undefined and sending the toggle back to the
`.code-workspace` — and worse, the `.code-workspace` file's own settings are not loaded at all, so the
`intersystems.servers` profile would go missing entirely. Opening a `.code-workspace` — even one with a
single folder entry, as here — is what makes `.vscode/settings.json` *Folder* scope.

### Reaching the gitignored reference folders from Claude Code

`irislib/`, `irissys/`, `irisui/` and `irisdocs/` are gitignored (they are regenerable container
exports, not source), but they are exactly the material worth searching and `@`-mentioning. The
Claude Code VS Code extension filters `.gitignore` matches out of its file searches by default, so
out of the box none of those ~25,000 files can be `@`-mentioned, and opening one does not even share
the active file or selection with Claude — the extension suppresses that context for git-ignored
files. The workspace turns the filter off:

```jsonc
// ocupilot.code-workspace
"claudeCode.respectGitIgnore": false
```

It belongs in the `.code-workspace` file, not `.vscode/settings.json`: the setting is *window*-scoped,
and window-scoped keys at folder scope are ignored — the same "open the workspace file, not the
folder" dependency as everything above.

Exclusions other than `.gitignore` still apply with the filter off — `search.exclude`,
`files.exclude`, and a `.ignore` file — so individual paths can be put back out of reach without
turning the setting back on. This changes only what the editor will *search and show*; the folders
remain read-only and must never be loaded into IRIS (see
[.claude/rules/reference-folders.md](.claude/rules/reference-folders.md)).

## Optional: IRIS MCP server suite

The [iris-execute-mcp-v2](https://github.com/jbrandtmse/iris-execute-mcp-v2) suite gives AI coding
assistants (Claude Code, Copilot, Cursor) direct tooling against this container — five MCP servers
covering dev, admin, interop, ops, and data.

It is **not vendored into this repo** — it gets cloned and built wherever you keep checkouts.

### The easy way: let Claude Code do it

If you use [Claude Code](https://claude.com/claude-code), you do not have to run any of the registration
commands yourself — hand it the job. Open this project in Claude Code and paste:

```text
Set up the IRIS MCP server suite for this project.

1. Clone https://github.com/jbrandtmse/iris-execute-mcp-v2 if I don't already have a
   checkout, then build it: `pnpm install && pnpm turbo run build` (needs Node 18+ and
   pnpm 9+; install pnpm with `npm install -g pnpm` if it's missing).
2. Register all five servers -- iris-dev, iris-admin, iris-interop, iris-ops, iris-data --
   with `claude mcp add` at **user** scope, so they're available in every project.
   Each one runs `node <checkout>/packages/iris-<name>-mcp/dist/index.js`.
3. Point them at the container this repo's docker-compose.yml starts, using these
   environment variables:
   IRIS_HOST=localhost, IRIS_PORT=52774, IRIS_USERNAME=_SYSTEM, IRIS_PASSWORD=SYS,
   IRIS_NAMESPACE=HSCUSTOM, IRIS_HTTPS=false
   If I've already changed the _SYSTEM password, ask me for the current one instead of
   using SYS.
4. Make sure the container is up (`docker compose up -d`) and confirm the result with
   `claude mcp list`.

Tell me what you changed and what I need to restart.
```

Claude Code will need to be restarted afterwards for the new servers to load.

### Manual registration (Claude Code CLI)

> Both this section and the one above are **specific to Claude Code** — `claude mcp add` is the Claude
> Code CLI. For any other MCP client (Copilot, Cursor, Cline, Claude Desktop, …), configure the same five
> commands and environment variables in that client's own MCP config, or use the suite's
> `iris-mcp-clients` CLI / the IRIS MCP Launcher extension, which wire up 13 supported clients for you.

Clone and build the suite (Node.js 18+ and pnpm 9+ required):

```bash
git clone https://github.com/jbrandtmse/iris-execute-mcp-v2.git
cd iris-execute-mcp-v2
pnpm install
pnpm turbo run build
```

Then register the servers with **user scope** so they are available in every project, pointed at this
container with `HSCUSTOM` as the default namespace. One per server (`iris-dev`, `iris-admin`,
`iris-interop`, `iris-ops`, `iris-data`):

```bash
REPO=/path/to/iris-execute-mcp-v2
for s in dev admin interop ops data; do
  claude mcp add "iris-$s" -s user \
    -e IRIS_HOST=localhost -e IRIS_PORT=52774 \
    -e IRIS_USERNAME=_SYSTEM -e IRIS_PASSWORD=SYS \
    -e IRIS_NAMESPACE=HSCUSTOM -e IRIS_HTTPS=false \
    -- node "$REPO/packages/iris-$s-mcp/dist/index.js"
done
```

Verify with `claude mcp list`. The container must be up for the servers to connect.

## License

[MIT](LICENSE).

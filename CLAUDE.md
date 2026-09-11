# OcuPilot

## IRIS MCP calls: always pass `server: "ocupilot-iris"`

**Every call to an IRIS MCP tool (`iris-dev`, `iris-admin`, `iris-interop`, `iris-ops`,
`iris-data`) must set the `server` parameter to `ocupilot-iris`.** Omitting it does not fail —
it silently routes to a *different* IRIS instance.

```jsonc
// correct — this project's container
{ "server": "ocupilot-iris", "namespace": "HSCUSTOM", ... }

// WRONG — silently hits the unrelated iris-community-edition container
{ "namespace": "HSCUSTOM", ... }
```

### Why this matters

Two IRIS containers run on this machine, from the same image, both answering on localhost:

| Profile         | Container                | Web port | SuperServer | What it is                         |
| --------------- | ------------------------ | -------- | ----------- | ---------------------------------- |
| `ocupilot-iris` | `ocupilot`               | 52774    | 1973        | **This project.** Always use this. |
| `default`       | `iris-community-edition` | 52773    | 1972        | Unrelated. Not this project.       |

The MCP suite's reserved `default` profile is built from the `IRIS_*` values on each MCP server's
own registration — the `env` block in `~/.claude.json` under Claude Code, **not** shell or
user-scope environment variables. Here those point at **52773**, the other container. Since
`default` is what a call without `server` resolves to, an unqualified tool call reads and writes
the wrong instance and returns plausible-looking results. There is no error to catch: both
instances are healthy, both have an `HSCUSTOM` namespace, and both accept `_SYSTEM`/`SYS`.

52773/1972 are the IRIS defaults, so on any other machine `default` is likely to be some
unrelated instance too — never assume it is this project's.

Verify at any time with `iris_server_profiles`; the roster's `baseUrl` distinguishes them.
The instance GUIDs also differ, which is the definitive check.

### How the `ocupilot-iris` profile is defined

It is **not** in the MCP client config. The five servers are registered with
`IRIS_SERVER_MANAGER=auto` and `IRIS_SM_WORKSPACE=/Users/jbrandt/git/OcuPilot`, so the suite
imports the `intersystems.servers` definition out of
[ocupilot.code-workspace](ocupilot.code-workspace) — host, port, username and password
included — and exposes it as the profile named `ocupilot-iris` (`source: "server-manager"`).

That file is the single source of truth for this connection. **If you change the ports in
[docker-compose.yml](docker-compose.yml), change them in
[ocupilot.code-workspace](ocupilot.code-workspace) too** — the MCP profile, the VS Code
ObjectScript connection in [.vscode/settings.json](.vscode/settings.json), and Server
Manager all read from there. No MCP re-registration is needed after a port change, but
already-running MCP server processes cache the profile at startup, so restart the Claude
Code session to pick it up.

### The profile name must never match the folder name

**`ocupilot-iris` is deliberately not `ocupilot`.** The ObjectScript extension lowercases the
*workspace folder name* and tests it against `intersystems.servers`; a match puts the folder into
`externalServer` mode, where `objectscript.conn.active` is parsed and then **discarded** (it reads
`active` from an in-memory `inactiveServerIds` set instead) and the **Toggle Connection** command is
removed from the UI — so the connection cannot be disabled at all, and the file-sync watcher stays
armed. The folder here is `OcuPilot` → `ocupilot`, so the profile must be named something else.

If you rename this directory, or rename the profile, check the two still differ.

<!-- bmad:context -->
<!-- Verified 2026-09-09 against 17f662e. Managed by bmad-project-context; edits inside this block are replaced on refresh. Keep anything you want preserved outside the markers. -->

An agent co-pilot for the InterSystems IRIS System Management Portal — an Angular 22 shell over an
ObjectScript REST API, installed into an IRIS for Health 2026.2 instance. Greenfield:
[src/OcuPilot/](src/OcuPilot/) is empty and `ui/` does not exist yet, so the work in flight is
planning documents, not code. Planning artifacts live in `_bmad-output/planning-artifacts/`;
[README.md](README.md) is the long-form container and VS Code setup reference. The MCP-server rule
above and the container detail below this block are the operational essentials.

## Policy

- Never publish, list, or post publicly about OcuPilot before the owner's release, targeting
  2026-09-24 — no Open Exchange listing, Developer Community article, video, or Ideas Portal entry.
- Never commit implementation to `main`, `master`, or `develop`. Work lands on the epic branch
  `{TICKET}-epic{N}` and reaches a trunk only through the `/epic-cycle` merge gate (Rule SC-6 in
  [.claude/commands/epic-cycle.md](.claude/commands/epic-cycle.md)).
- Exclude `irislib/`, `irissys/`, `irisui/` and `irisdocs/` from searches — they hold 25,372 files
  against 385 tracked ones. Never edit, load, compile, promote or sync them; see **Docs** below.

## Where things are

- Read
  `_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md`
  in full before writing code — all 48 ADs, not the ones that look relevant. It is a contract:
  change an AD there rather than working around it in a slice.
- Epics and stories: `_bmad-output/planning-artifacts/epics.md` (23 epics). PRD, UX and research sit
  beside it under `_bmad-output/planning-artifacts/`.
- ObjectScript and IRIS rules load automatically from [.claude/rules/](.claude/rules/) — ObjectScript
  basics, testing, debugging, persistent storage, interoperability, reference folders,
  research-first. They were harvested from four sibling IRIS projects, so treat them as inherited
  standards rather than as this project's own scar tissue.

## Running and verifying

- Load and compile ObjectScript through the IRIS MCP tools, not the VS Code extension:
  `objectscript.conn.active` is deliberately `false` and must stay that way.
- Run BMAD scripts through `uv run` (`uv run _bmad/scripts/resolve_config.py --project-root .`); a
  bare `python3` runs outside the project environment, and `/epic-cycle` halts without `uv`.
- Check authored Markdown with `bash scripts/lint-docs.sh` (`--fix` repairs structure). A bare
  `npx markdownlint-cli2` lints nothing: the config carries rules only, and the document set lives
  in `scripts/check-prose.py`. The `.githooks/pre-commit` hook runs both on staged files once you
  have run `git config core.hooksPath .githooks` in the clone.
- TODO once code exists: the Angular build and test invocations. The spine pins Angular 22.1.x,
  TypeScript 6.0.x exactly, and Node `^22.22.3 || ^24.15.0 || ^26.0.0`; Node 20 and TypeScript 5.9
  or 7 are refused by the toolchain.

## Conventions that differ from defaults

- Code harvested from the four sibling projects keeps its call sites but never its names. Rename
  packages (`SessionAgent.*`, `ExecuteMCPv2.*`, `IRISCouch.*`), web paths, roles, audit sources,
  globals, credentials and the `iris_` tool prefix into OcuPilot's own. Harvest plans are under
  `_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/harvest/`.

## Known pitfalls

Every one of these was caught in review here, repeatedly, while writing the planning documents.

- Do not generalize one probe into a claim about a population. Three reviewers caught this on three
  separate claims — one endpoint class was probed and "every endpoint" was asserted; 5 of 70 turned
  out to differ. A universal claim needs a query over the whole set.
- Do not report a count taken from grep or substring matching without checking it against the
  structure, and never read a failed lookup as a negative result — a probe undercounted 7 classes as
  4 because three `GetTextAsString` failures were scored as "no match".
- Correct a wrong claim at its origin, not only where you noticed it. Superseded claims left in
  memlogs and reconcile tables get mined later as evidence and propagate again.
- Never mark a fact verified that you did not check. A TypeScript version recalled rather than
  looked up shipped inside a table headed "Verified against the live instance".
- Label an inference as an inference every time it crosses a document boundary. One inference read
  as an observation reached three documents before review caught it.

<!-- /bmad:context -->

## Container

```bash
docker compose up -d --wait   # start, and block until OcuPilot is installed and reachable
docker compose ps             # confirm 1973->1972 and 52774->52773
docker compose logs -f iris   # follow progress; first start takes a few minutes
```

`--wait` is the point: since Story 1.4 the container's health check runs OcuPilot's own install
to completion before it reports healthy, so the command's own exit is the "installed and
reachable" signal. **IRIS startup is no longer the readiness signal** — a container that is up is
not necessarily installed. Never read `docker compose logs` for a "looks done" line; the health
check is the contract. The image is pinned to an explicit `2026.2` tag, never the vendor's
rolling `latest-cd` alias.

- **Management Portal:** <http://localhost:52774/csp/sys/UtilHome.csp>
- **Credentials:** `_SYSTEM` / `SYS` · **Default namespace:** `HSCUSTOM`
- **Shell:** `docker compose exec iris iris session iris -U HSCUSTOM`

Host ports are deliberately offset by one from the IRIS defaults (52774/1973 instead of
52773/1972) to coexist with the other container. Container-internal ports remain the
defaults; only the host side is remapped.

### Fresh container: expired password

Community Edition expires `_SYSTEM`'s password on first login, which surfaces as **HTTP 401**
from MCP tools and the Atelier API rather than as a password prompt. As of Story 1.4, the
container's own `--after` start hook unexpires `_SYSTEM` on a genuinely first install
(`OcuPilot.Install.Installer.EnsureUnexpired`, gated on the version row's absence, never the
all-users form) — a clean `docker compose up -d --wait` needs no manual step.

If you ever land in the expired state anyway (an older `iris-data/` predating Story 1.4, or the
installer's own unexpire step failed), clear it by hand:

```bash
docker compose exec -T iris iris session iris -U "%SYS" '##class(Security.Users).UnExpireUserPasswords("_SYSTEM")'
```

Confirm with: `curl -I -u _SYSTEM:SYS http://localhost:52774/api/atelier/` → `HTTP 200`. Target
`_SYSTEM` by name, never the `"*"` all-users form — the same discipline the installer's own step
follows.

## Durable storage

`./iris-data` is bind-mounted to `/durable` with `ISC_DATA_DIRECTORY=/durable/iris`, so
instance state survives `docker compose down`. Deleting that directory resets the instance
— and re-triggers the expired-password step above.

## Project source layout

**All project ObjectScript source (`.cls`, `.mac`, `.inc`) lives under [src/OcuPilot/](src/OcuPilot/).**
Nothing ObjectScript goes anywhere else in the repository. When loading or compiling project
classes into IRIS with the MCP tools, load from that folder. The `irislib/`, `irissys/`,
`irisui/` and `irisdocs/` trees are read-only exports, never project source (see below).

## Docs

[README.md](README.md) is the long-form reference, including the VS Code / ObjectScript
setup rationale — in particular the full write-up of the `externalServer` name-collision
trap described above.

`irislib/`, `irissys/`, `irisui/` and `irisdocs/` are **read-only reference material** (container
exports and a mirror of the official `%Api` docs), not project source — never edit them or load
them into IRIS. The rule in
[.claude/rules/reference-folders.md](.claude/rules/reference-folders.md) spells this out and lists
where the official `%Api` documentation lives on docs.intersystems.com.

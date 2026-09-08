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

The MCP suite's reserved `default` profile comes from the user-scope `IRIS_*` environment
variables, which point at **52773** — the other container. Since `default` is what a call
without `server` resolves to, an unqualified tool call reads and writes the wrong instance
and returns plausible-looking results. There is no error to catch: both instances are
healthy, both have an `HSCUSTOM` namespace, and both accept `_SYSTEM`/`SYS`.

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

## Container

```bash
docker compose up -d      # start
docker compose ps         # confirm 1973->1972 and 52774->52773
docker compose logs -f    # ready when startup completes
```

- **Management Portal:** <http://localhost:52774/csp/sys/UtilHome.csp>
- **Credentials:** `_SYSTEM` / `SYS` · **Default namespace:** `HSCUSTOM`
- **Shell:** `docker compose exec iris iris session iris -U HSCUSTOM`

Host ports are deliberately offset by one from the IRIS defaults (52774/1973 instead of
52773/1972) to coexist with the other container. Container-internal ports remain the
defaults; only the host side is remapped.

### Fresh container: expired password

Community Edition expires `_SYSTEM`'s password on first login, which surfaces as **HTTP 401**
from MCP tools and the Atelier API rather than as a password prompt. Clear it once per new
container (this includes any time `iris-data/` is wiped):

```bash
docker compose exec -T iris iris session iris -U "%SYS" '##class(Security.Users).UnExpireUserPasswords("*")'
```

Confirm with: `curl -I -u _SYSTEM:SYS http://localhost:52774/api/atelier/` → `HTTP 200`.

## Durable storage

`./iris-data` is bind-mounted to `/durable` with `ISC_DATA_DIRECTORY=/durable/iris`, so
instance state survives `docker compose down`. Deleting that directory resets the instance
— and re-triggers the expired-password step above.

## Docs

[README.md](README.md) is the long-form reference, including the VS Code / ObjectScript
setup rationale — in particular the full write-up of the `externalServer` name-collision
trap described above.

`irislib/`, `irissys/`, `irisui/` and `irisdocs/` are **read-only reference material** (container
exports and a mirror of the official `%Api` docs), not project source — never edit them or load
them into IRIS. The rule in
[.claude/rules/reference-folders.md](.claude/rules/reference-folders.md) spells this out and lists
where the official `%Api` documentation lives on docs.intersystems.com.

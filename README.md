# IRIS Community Edition

A minimal, reproducible **InterSystems IRIS for Health Community Edition** sandbox built for **AI coding
agents** to work against. One Docker Compose service with **durable storage**, wired up two ways: for VS
Code, so ObjectScript editing, compiling, and debugging work out of the box; and for agents — Claude Code,
Copilot, Cursor — via the [IRIS MCP server suite](#optional-iris-mcp-server-suite), which gives them
direct tooling for development, administration, interoperability, operations, and data against this
instance. A throwaway IRIS an agent can safely drive, break, and rebuild.

The `HSCUSTOM` namespace is the default target for everything here.

## What this project is

| Piece | Purpose |
| --- | --- |
| [docker-compose.yml](docker-compose.yml) | Runs `intersystems/irishealth-community:latest-cd` as `ocupilot`, publishing 1973→1972 (SuperServer) and 52774→52773 (Management Portal), with `ISC_DATA_DIRECTORY=/durable/iris` |
| [iris-data/](iris-data/) | The durable-storage bind mount (`./iris-data` → `/durable`). Tracked in git as an empty folder — see [Durable storage](#durable-storage) |
| [ocupilot.code-workspace](ocupilot.code-workspace) | The `intersystems.servers` definition for the container — the connection profile Server Manager and the ObjectScript extension resolve against |
| [.vscode/settings.json](.vscode/settings.json) | The `objectscript.conn` that references that profile, including the `active` toggle — see [VS Code / ObjectScript setup](#vs-code--objectscript-setup) |
| [LICENSE](LICENSE) | MIT |

## Prerequisites

- **[Docker Desktop](https://www.docker.com/products/docker-desktop/)** (or any Docker Engine with Compose v2) — running before you start.
- **[InterSystems ObjectScript Extension Pack](https://marketplace.visualstudio.com/items?itemName=intersystems-community.objectscript-pack)** for VS Code (extension ID `intersystems-community.objectscript-pack`). This bundles the ObjectScript language server, the Server Manager, and the InterSystems Language Server.

## Bringing the container up

```bash
# from the project root
docker compose up -d
```

First start pulls the image and initializes the instance into `./iris-data`, which takes a few minutes.
Watch it finish:

```bash
docker compose logs -f iris
```

The instance is ready when the log reports the IRIS startup as complete.

### Verify

- **Management Portal:** <http://localhost:52774/csp/sys/UtilHome.csp>
- **Credentials:** `_SYSTEM` / `SYS`
- **Namespace:** `HSCUSTOM`
- **Shell into the instance:** `docker compose exec iris iris session iris -U HSCUSTOM`

> On a Community Edition container the default password is expired on first login. The Portal will prompt
> you to change it. The password is not stored in this repo — Server Manager prompts for it on first
> connect and saves it in your OS keychain. If you change it, update it there and in any MCP server
> configuration below.

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

```
iris-data/*
!iris-data/.gitkeep
```

So a fresh clone gets an empty `iris-data/` ready to be populated on first `docker compose up`.

## VS Code / ObjectScript setup

Open [ocupilot.code-workspace](ocupilot.code-workspace) (**File → Open
Workspace from File…**) rather than the plain folder. This matters for more than convenience — see
[Where the `active` toggle lives](#where-the-active-toggle-lives) below.

The connection is expressed the way the [InterSystems Settings
Reference](https://docs.intersystems.com/components/csp/docbook/DocBook.UI.Page.cls?KEY=GVSCO_settings)
prescribes — a named **server profile**, referenced by name from the connection — split across two files:

| File | Scope | Setting | Holds |
| --- | --- | --- | --- |
| [ocupilot.code-workspace](ocupilot.code-workspace) | Workspace | `intersystems.servers` | The `ocupilot-iris` profile: `webServer` scheme/host/port, `superServer` port, `username` |
| [.vscode/settings.json](.vscode/settings.json) | Workspace Folder | `objectscript.conn` | `server` (the profile name), `ns`, `active` |

```jsonc
// ocupilot.code-workspace
"intersystems.servers": {
  "ocupilot-iris": {
    "webServer": { "scheme": "http", "host": "localhost", "port": 52774 },
    "superServer": { "port": 1973 },
    "username": "_SYSTEM"
  }
}

// .vscode/settings.json
"objectscript.conn": {
  "server": "ocupilot-iris",
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
**`ocupilot-iris`** to stay clear of it. If you rename the directory, check it still differs from the
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

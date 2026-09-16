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
[ocupilot.code-workspace](ocupilot.code-workspace) and in [ui/proxy.conf.json](ui/proxy.conf.json)
too** — the MCP profile, the VS Code ObjectScript connection in
[.vscode/settings.json](.vscode/settings.json), and Server Manager all read from the workspace
file, while the Angular dev server's proxy reads its own. Two client tests hold the literal —
`ui/tools/compose.test.mjs` asserts the compose mapping and `ui/tools/angular-json.test.mjs`
asserts the proxy target — so both of those must be edited too; note that neither test compares
the two files, so updating one pair and not the other leaves a dead port with the suite green.
No MCP re-registration is needed after a port change, but
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
- Build and test the client from `ui/`: `npm run build` (its `prebuild` chains six checkers —
  version guard, `client-lint.mjs`, `screen-mirror.mjs --check`, `classic-links.mjs`,
  `ipm-manifest.mjs --check`, `field-lists.mjs --check`) and `npm test`
  (`node --test tools/*.test.mjs` then the Angular component runner on vitest+jsdom). `npm run test:browser` drives a pinned headless Chrome — jsdom
  computes no layout, so anything about geometry belongs there. The spine pins Angular 22.1.x,
  TypeScript 6.0.x exactly, and Node `^22.22.3 || ^24.15.0 || ^26.0.0`; Node 20 and TypeScript 5.9
  or 7 are refused by the toolchain.
- Check ObjectScript with `uv run scripts/check-objectscript.py` (18 rules; the `.githooks/pre-commit`
  hook runs it on staged paths and it blocks the commit) and its own harness with
  `uv run scripts/test_check_objectscript.py`.
- Ask a running instance whether OcuPilot works: `bash scripts/smoke.sh --container ocupilot
  --user _SYSTEM --password SYS`. The assertions live in `OcuPilot.Install.Smoke` inside the
  instance, so CI and a local run ask the same question; zero executed checks is a failure, never
  a pass.
- **CI runs all of the above on every push** (`.github/workflows/ci.yml`, three jobs: `gates`,
  `instance`, `images`). `gates` runs **once per Node band `engines.node` declares, at each
  band's floor** (22.22.3 / 24.15.0 / 26.0.0) — `ui/tools/ci.test.mjs` holds that list and
  `engines.node` equal in both directions, so a declared band with no leg is red. A single-version
  job cannot tell "this works" from "this works on the one version we run": `npm test` ran
  `node --test` over a directory, which Node 26 scans and Node 22 loads as a module, and the job
  died over a suite it never opened while every local gate stayed green. It is the only gate that runs on the platform the project ships from, and
  it is the gate over what was actually committed — the pre-commit hook reads the working tree, so
  a staged fix for an unstaged cause passes locally and fails there. `concurrency` is
  `cancel-in-progress`, so a second push cancels the first push's run.

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

## Prose discipline

The pitfalls above were learned the hard way, and the way they got practised created a second
problem. Story 1.4's three main classes are a third doc comment by line count (`Installer.cls`
2,231 lines and 136 KB, `Fixture.cls` 1,134 lines and 71 KB, `Test/Demo.cls` 841 lines and 52 KB),
about a hundred of those comments narrate review rounds, and the story's spec reached 664 KB against
a template that aims for 900 to 1,600 tokens. Reviewers then review the narration: several of the
story's medium findings were about a claim in a comment or a spec paragraph, not about code. Every
sentence a reviewer can file a finding against is surface area; keep the surface small.

- A doc comment states what the method does, its caller contract, and any constraint a caller
  cannot see from the signature. It does not name review rounds, finding ids, iteration numbers,
  or who found what. That history belongs in the spec's `## Review Triage Log`, which is where the
  next reader looks for it.
- "Correct a wrong claim at its origin" means replace the wrong sentence with the right one. Delete
  the wrong sentence; do not append a paragraph explaining that it was wrong. A correction that is
  longer than the claim it corrects is a new claim to review.
- Label an inference with the one word `(inference)` at the point it is made. The recipe for
  verifying it goes in the ledger entry's `evidence:` line, once, within that grammar's three-line
  limit, and nowhere else.
- A rework's `## Auto Run Result` records what this pass changed and how it was verified, inside
  the template's budget. It does not restate earlier passes, re-argue closed findings, or carry
  residual-risk lists forward verbatim; a closed item is one line naming where it closed.
- A test class header says what the class pins and what it needs from the environment. Why a test
  was rewritten belongs in the commit message, and the commit message is one paragraph.
- When the spec template flags `oversized`, the lead's next re-open appends only the open items.
  Nothing else is added to that spec until it is `done`.

## Container

**The running `ocupilot` container predates Story 1.4. Do not run `docker compose up` or `down` against it.**
It was created from the old compose file: the rolling `latest-cd` image, `unless-stopped`, no start
hook, no health check, no source mounts, no `OCUPILOT_DEMO` (`docker inspect ocupilot`, 2026-09-11).
Compose therefore sees a changed configuration, and any `docker compose up` — with or without
`--wait` — **recreates** it: the new start hook then compiles and installs OcuPilot, demo fixtures
included, against the live `./iris-data` volume, a path so far verified only on fresh throwaway
containers. `docker compose down` removes it, and only a recreating `up` brings it back. Recreating,
removing or restarting it is the owner's call. `docker compose ps` and `logs` change nothing; `exec`
runs whatever you give it inside the live container.

On a clone with no container yet, or once the owner has recreated this one:

```bash
docker compose up -d --wait   # start, and block until the health check reports OcuPilot installed
docker compose ps             # confirm 1973->1972 and 52774->52773
docker compose logs -f iris   # follow progress; first start takes a few minutes
```

**Compose runs a one-shot `durable-init` service before `iris`.** IRIS runs as uid 51773, and a Linux bind mount keeps the host directory's ownership, so a fresh `./iris-data` created by your own user is one IRIS cannot write; `durable-init` changes the owner of that one directory (never recursively) only when uid 51773 cannot already write it, and exits 1 naming the directory if it still cannot. Docker Desktop on macOS maps bind-mount ownership away, so there it changes nothing. `iris` waits for it with `service_completed_successfully`.

`--wait` is the point: since Story 1.4 the container's `--after` start hook compiles OcuPilot and runs
its install on every start, and the health check reports healthy only once **this** start's install has
recorded success and the install gate reads `installed`, so the command's own exit is the "installed and
reachable" signal. What keeps a same-version restart from reading healthy on an earlier start's record is
that start-scoped check, not the version row. The hook also marks an `installed` stamp `installing` before
it recompiles, so the API gate refuses during the recompile, but only as a best effort: IRIS is already
serving before the hook runs, a start whose previously compiled installer lacks the mark carries on
unmarked, and a failed mark does not stop the start (AD-38). **IRIS startup is no
longer the readiness signal** — a container that is up is not necessarily installed. Never read
`docker compose logs` for a "looks done" line; the health check is the contract. The image is pinned
to an explicit `2026.2` tag, never the vendor's rolling `latest-cd` alias.

**Restart policy is `on-failure:3`.** A failed install makes the start hook, and so the container,
exit 1; it is restarted up to three times within seconds and then **left stopped**, so a
deterministic failure cannot loop. The three are counted over the container's life until it is next
started by hand. Per Docker's documentation (not observed here), an `on-failure` container is also
**not** restarted after a reboot or a Docker Desktop restart. If a post-1.4 container is down,
`docker compose ps -a` shows it exited and `docker compose logs iris` says why in its `container-start:`
lines: a failed install step is named on the `STARTPATH-FAILED` line, a compile failure reads `LOAD-FAILED`,
and a session that never reported prints its first errors and last lines. A refusal (a held install
lock, a stored version newer than the code) names no step; its message says what refused. Fix the cause and
bring it back with `docker compose up -d --wait`.

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
(`OcuPilot.Install.Installer.EnsureUnexpired`, `_SYSTEM` by name, never the all-users form; only the
container start path asks for it, never an IPM install, per AD-17), so a clean
`docker compose up -d --wait` needs no manual step. "First" means the volume has no version row yet, or
only a `failed` one that never reached schema version 1.

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

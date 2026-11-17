---
title: 'Story 24.7: Web terminal'
type: 'feature'
created: '2026-11-17'
status: 'blocked'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: []
deferred: []
---

<intent-contract>

## Intent

**Problem:** Story 24.7's acceptance says the web terminal "round-trips over its backing class", built under AD-10's run-code exception (owner answer U-78). The catalog row DT-04 names that backing class: the vendor's Atelier v7 `/%SYS/terminal` WebSocket, `%Atelier.v7.TerminalAgent`. Measured on `ocupilot-b-ci`, that class cannot be reached under the spine as it stands, and no reading of the story that can be built round-trips over it.

**Approach:** None is planned. This is an `intent gap` HALT. The owner chooses one of the amendments under Design Notes, and the story is then re-planned.

</intent-contract>

## Boundaries & Constraints

Not planned while the story is blocked on owner question U-104; the re-plan writes this section.

## I/O & Edge-Case Matrix

Not planned while the story is blocked on owner question U-104; the re-plan writes this section.

## Code Map

- `irissys/%Atelier/v7/TerminalAgent.cls:6,10,368-401,416-697` (read-only) -- a `%CSP.WebSocket` that asks `%Development:USE` (`:375`). It has to be entered from a REST dispatch (`:380`). It runs every command in a child process started by `%Debugger.System.StartTarget` (`:470`), which keeps locals, `$NAMESPACE`, `$TLEVEL` and locks between commands, and it answers `Read` and interrupt messages.
- `irissys/%Api/Atelier/v7.cls:112,122-136` (read-only) -- the `GET /%SYS/terminal` route. `RunTerminal` hands the request to `TerminalAgent.Page(0)`, so the session lives in the upgraded connection, not in a call a port can make in process.
- `src/OcuPilot/Port/DevToolPort.cls` `RunConsole`, `src/OcuPilot/Port/Harvest/ConsoleRun.cls`, and `ui/src/app/areas/system-explorer/console.{page,store}.ts` -- 24.6's command console. This is the sibling for amendment A.

## Tasks & Acceptance

Not planned while the story is blocked on owner question U-104; the re-plan writes this section.

## Design Notes

### Measured on `ocupilot-b-ci` (IRIS for Health 2026.2 build 221U), 2026-11-17

Each probe ran once, from the host. The scripts are under the scratchpad's `e24u/24-7/`.

1. **The route exists, and a session keeps state.** A WebSocket to `ws://localhost:52777/api/atelier/v7/%25SYS/terminal` with a Basic header got `{"type":"init","protocol":1}`. After `config` to `USER`, the second command read a local the first had set (`Set ocu247x=41`, then `Write ocu247x+1` gave `42`). A `TStart` gave the prompt `TL1:USER>` on the next line, so the open transaction carried over to it.
2. **One child process per session, ending with it.** The child's `$JOB` (7636) differs from the server's (`$ZPARENT` 2177). After a clean close (process 7555) and after a dropped TCP connection with a transaction open (7636 and 2177), `$Data(^$JOB(pid))` read 0 for each process.
3. **OcuPilot's credential does not open it.**
   - The tab's access token as `Authorization: Bearer` got 401 from `/api/atelier/`.
   - The WebSocket upgrade with that Bearer, or with no credential, closed with 1006.
   - A browser's `WebSocket` cannot set an `Authorization` header at all (documented browser API; not measured here).

### Why the story as written cannot be built (Rule 6: these ADs, not the code, are the obstacle)

- **AD-28 and the spine's Deferred row "The Atelier port's authentication".** The owner rejected sending a Basic header to `/api/atelier`, and OcuPilot does not enable JWT on a vendor application. Only a Bearer header authorizes OcuPilot's own API, and a browser WebSocket cannot carry one. The browser therefore has no credential that opens either the vendor's terminal or an OcuPilot WebSocket.
- **AD-61.** Atelier is reached only through `AtelierPort`, calling route methods in process. A WebSocket session cannot be called that way.
- **AD-7.** Its Prevents line is "a mutation performed by a detached process". The vendor's terminal runs every command in a debugger child process that outlives each message (measurement 2).
- **AD-10's three rules (U-78).** "The screen action route asks the tool's governance key", and each run is audited (24.6's one `SecurityChange` row) and confirmed. A WebSocket message never passes the screen action route. Holding the key, the audit row and a confirmation to each line would need a new OcuPilot WebSocket endpoint that wraps the vendor's class. That endpoint needs AD-28, AD-7, AD-10 and AD-61 amended, and a new web application (AD-17).

Over OcuPilot's REST route, each run gets a different pooled process, and 24.6 rolls back what the run leaves open. So a "terminal" there keeps no state between lines and does not touch the backing class. That is a different product from the vendor's terminal. Two readings with observably different outcomes, and nothing in the intent to choose between them, make this an intent gap.

### Recommended amendment (the owner's call; amendment A is a Rule 5 ask-first narrowing, as U-45 was for 24.8)

- **A (Recommended): a terminal view over the command console, on this request model only.**
  - System Explorer gets a terminal-shaped page: a `NS>` prompt, a scrolling transcript, and line history with up and down recall.
  - Each line is one run of `explorer.command.run` through `POST /screens/:screen/action`. That means 24.6's key, the warning dialog for each line, one audit row, and output on the screen only.
  - Nothing new on the server: no new tool, key, AD or web application. It extends `console.page.ts` and `console.store.ts` (Rule 2).
  - Named limit, shown on the page: each line runs on its own, so locals, transactions, locks and `Read` input do not carry to the next line. Only the namespace prompt is kept, and the page keeps it.
  - Proposed AC text for `epics.md`, replacing the Given/When/Then: "**Given** the command console's key switched on **When** a person enters a line in the web terminal and confirms **Then** it round-trips over the command console's harvested class, and the transcript keeps the line, its bounded output and the namespace prompt; the page states that nothing else carries between lines."
  - Proposed spine line, AD-10, after the consoles sentence: "**The web terminal** (Story 24.7, owner answer U-<n>) is the Command console's transcript. Each line is one run of `explorer.command.run`, with its key, its dialog and its audit row, and no state carries between lines. The vendor's `/%SYS/terminal` WebSocket is not reached (AD-28, AD-61, AD-7)."
  - AD-22 and AD-53 do not change, because there is no new key or tool.
  - Proposed strings for re-plan: title "Web terminal"; limit note "Each line runs on its own: variables, transactions and locks do not carry to the next line."
- **B: not planned.** DT-04 moves to P4 and into the exclusion register, with this reason: the vendor's terminal is a password-authenticated WebSocket that runs commands in a process outliving every request, and OcuPilot carries no password (AD-28) and runs no write outside its request (AD-7). The Command console is OcuPilot's way to run code, and VS Code's terminal reaches the vendor's. The story keeps its key and lands only the register row and the catalog totals, as 24.8 did for DT-11.
- **C (not recommended): a real stateful terminal.** This is an OcuPilot WebSocket endpoint extending `TerminalAgent`, which checks the key and writes the audit row for each prompt message. It needs a new authentication path for WebSockets, which is owner-only. It also needs AD-7, AD-10 and AD-61 amended and a new web application, which together are more than one story.

**Ledger inbox:** none.

## Verification

Not planned while the story is blocked on owner question U-104; the re-plan writes this section.

## Auto Run Result

Status: blocked
Blocking condition: intent gap -- Story 24.7's AC ("the web terminal round-trips over its backing class", catalog DT-04: `%Atelier.v7.TerminalAgent`, the Atelier v7 `/%SYS/terminal` WebSocket) cannot be built within AD-10's U-78 exception. Measured on `ocupilot-b-ci`: the session keeps locals and transactions in a debugger child process that outlives every message (AD-7). The tab's Bearer token gets 401 at `/api/atelier`, and the WebSocket upgrade closes 1006 (AD-28; the Basic header was rejected by the owner, spine Deferred row). A WebSocket message never passes the screen action route where AD-10 asks the key, and AD-61 calls Atelier in process only. Recommended amendment A: narrow 24.7 to a terminal view over 24.6's command console, where each line is one confirmed, audited run of `explorer.command.run`, no state carries between lines, and that limit is stated on the page; no new tool, key or AD. Alternatives: B, DT-04 not planned and put in the exclusion register; C, a stateful terminal, which needs AD-7, AD-10, AD-28 and AD-61 amended and a new web application. Exact AC and spine text are under Design Notes.

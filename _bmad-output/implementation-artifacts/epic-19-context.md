# Epic 19 Context: Stage 3 - System Explorer over the Atelier API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Give developers a System Explorer inside OcuPilot, built on the IRIS Atelier API. Classes and routines can be listed, viewed, compiled, deleted, exported, imported and edited, with saves checked against the document's ETag. Code can be searched, compared and looked up by macro. The SQL catalog has a query console behind a DML and DDL guard. Rows can be browsed and edited in a data grid harvested from iris-table-editor. Documatic and DocDB, SQL activity, and an agent picker with guarded agent SQL complete the stage. This is the first post-contest stage built on a new port, `Port/AtelierPort`. It must reach Atelier without ever handling the user's password and without modifying a vendor web application. It must also keep the one screen contract every earlier stage followed. Every story lands on the epic branch through `/epic-cycle`.

## Stories

- Story 19.1: Classes and routines, listed and viewed
- Story 19.2: Compile, delete, export and import
- Story 19.3: The source editor, with ETag conflict detection
- Story 19.4: Search, compare and macro lookup
- Story 19.5: The SQL catalog browser
- Story 19.6: The query console and its DML and DDL guard
- Story 19.7: The data browser - tree, grid, filter and sort
- Story 19.8: The data browser - editing, staging and export
- Story 19.9: Documatic and DocDB
- Story 19.10: SQL activity
- Story 19.11: The agent gains guarded SQL and a picker

## Requirements & Constraints

- **One contract (FR-80).**
  - Each screen is declared by one descriptor and reaches outside through one port. Its read tool and its write tools' field lists derive from that descriptor.
  - Every agent write is a server-minted proposal with an instance-computed diff, an explicit confirmation and an agent marker.
  - Every read is bounded and reports truncation. Every gate checks the caller's own privileges at call time.
  - A story's acceptance is this contract plus each catalog row's backing route. The stage has 36 rows: CP-36, OS-23, EX-02 to EX-34 and DT-01. Finer criteria are written at the story's plan, never invented in advance.
- **Backing routes, by story.** Atelier routes are relative to `/api/atelier/v<N>/:ns`.
  - 19.1:
    - `GET docnames/CLS` and `docnames/RTN`, plus `POST modified`;
    - `GET doc/:name`, also with `?format=` and as `.int`;
    - `POST action/index`.
  - 19.2:
    - `POST action/compile`, with flags and streamed output;
    - `DELETE doc/:name` and `DELETE docs`;
    - the v7 routes `action/xml/export`, `xml/load` and `xml/list`, plus `PUT doc`.
  - 19.3: `PUT doc/:name` with the ETag.
  - 19.4: v2 `action/search`, v2 `getmacrodefinition` and `getmacrolocation`, and two document reads diffed in the client.
  - `POST action/query` backs four stories:
    - 19.5: `INFORMATION_SCHEMA` and `CALL %SQL_Manager.Catalog` queries;
    - 19.6: the console, with `{query, parameters}`, and `EXPLAIN`;
    - 19.7 and 19.8: the data browser;
    - 19.10: `INFORMATION_SCHEMA.CURRENT_STATEMENTS`. Cancelling a statement is Stage 4.
  - 19.9: Documatic at `/csp/documatic/%25CSP.Documatic.cls`, and DocDB at `/api/docdb/v1/:ns`.
- **What gates the stage.**
  - `action/query` runs any statement type unguarded and applies no row limit, so the guard ships with the console. The row cap and the truncation report are OcuPilot's to apply.
  - XML export and load are v7 routes and need a version gate that reports an older instance rather than failing obscurely. The 2026.2 floor carries Atelier v1 to v8, so the gate never fires there (inference).
  - Observe the ETag conflict on document `PUT` on a throwaway before building on it.
  - DocDB needs `%Service_DocDB` enabled. Report the requirement; never assume it.
- **Governance (AD-22).** Every new write key gets its line in `Kernel/Governance/Baseline.cls` in the same change. Every new destructive key defaults to disabled. After 2026-10-04, the owner decides how other new keys enter.
- **Limits carried knowingly from the harvest.**
  - Only single-column primary keys are supported.
  - The identifier pattern refuses delimited names.
  - `rowsAffected` always reads 1.
  - `%VID` offset paging re-reads the rows before each page and runs a separate `COUNT(*)` per page. A failed count shows zero rows.
- **Measure, never assume.** Take each pair set from the handler's own checks plus a purpose-built least-privileged role on the throwaway. Never use `%Operator`.

## Technical Decisions

- **The Atelier port (owner decision 2026-09-29).** Atelier features go through the OcuPilot API, which calls the Atelier implementation in process as the signed-in user, the pattern `AdminPort` uses (AD-1, AD-2).
  - No explicit Basic header, and no JWT on `/api/atelier`, since enabling it modifies a vendor web application.
  - The client never calls `/api/atelier` itself: the tab's token is refused there, and a cookie-only call opens the browser's Basic prompt and hangs.
- **Spine amendments (Rule 20).** The design paradigm names five ports, and nothing else may cross the boundary.
  - Adding `AtelierPort`, and whatever carries DocDB, is a spine amendment at the spec gate. The capability map already names `AtelierPort` under AD-5 and AD-21, marked "staged".
  - Each later story writes its own amendments too: AD-8 for extra pairs, AD-10 for new predicates and AD-21 for new SQL cases.
- **Calling Atelier in process (inference).** The `%Api.Atelier.vN` routes are `%CSP.REST` class methods on `%Atelier.REST`, which read `%request` and write a `{status, console, result}` envelope to the device. Expect AD-2's traps:
  - stub CSP objects;
  - captured output, so nothing corrupts AD-12's envelope;
  - the outcome read from both the `%Status` and the response status;
  - vendor text normalized at the port (AD-39).

  Confine every Atelier class name to the port, as AD-27 does for the admin API.
- **The port's own gate (AD-29).** The port declares its pairs and checks them with `$System.Security.Check` before any call. The `/api/atelier` web application requires `%Development`, a check that is skipped when the call runs in process, so the port must check it itself (inference). Switch namespace by explicit save and restore (AD-16).
- **SQL (AD-21).** Every caller value is bound.
  - Table and column names cannot be bound. The harvested `SqlBuilder` validates and escapes them, and AD-21 says validation never substitutes for binding. So the identifier path needs a named AD-21 case, or names resolved against `INFORMATION_SCHEMA` first (inference).
  - The console's statement is the caller's own SQL and is governed by the guard (inference).
- **The DML and DDL guard.** One classifier on the instance serves both the console and the agent's SQL tool. A client-only check is not a gate, because every write gate is evaluated at the write (AD-10, AD-40; inference).
  - In the console, a DML or DDL statement needs an explicit confirmation.
  - From the agent, it is an ordinary confirmed proposal.
  - Release 1 gave the agent catalog SELECTs only.
- **Writes (AD-53, AD-55).** A person's action and the agent's write are one operation with two callers.
  - The screen caller mints no proposal, emits no marker and is not gated by read-only or the kill switch.
  - Both callers get the per-target lock (AD-34), the read-back (AD-58), a `Snippet` (AD-59) and the change event (AD-14).
  - Atelier and SQL writes have no admin API body template. Each tool's spec gate must state and pin four things (inference):
    - how its field list is derived (AD-3);
    - its target triple and canonical spelling (AD-13);
    - its fingerprint subject (AD-6, AD-51, AD-54);
    - its read-back subject.
- **Reads (AD-36, AD-24).** One declared read serves both the screen and the tool, with a row cap and context caps. Source text, query results and cell values are untrusted content to the model (AD-11, AD-60), and secret-typed fields never leave the instance.
- **Streaming.** Handlers never write to the response (AD-12), and today the only incremental channel is a turn's progress poll (AD-33). Streamed compile output therefore needs a stated transport (inference).
- **The iris-table-editor harvest.** Keep call sites and never names. `--ite-*` tokens are bridged to OcuPilot's tokens, never adopted.
  - Lift `SqlBuilder`, `DataTypeFormatter`, `UrlBuilder`, `ErrorHandler`, the model types, the `theme.css` token contract, `grid-styles.css` and the CSV helpers.
  - Port three algorithms out of `grid.js`:
    - keyboard navigation;
    - the filter row and tri-state sort;
    - staging with primary-key reconciliation and stale-index recovery after pagination.

    Delete its nine drifted formatter clones.
  - Rework the Atelier services behind a transport seam aimed at the OcuPilot API. They hardcode Basic, pass username and password positionally, use Node-only `Buffer.from` and treat a 401 as terminal.
  - Never carry the plaintext-password-in-server-memory session.
- **Documatic and agent definitions.**
  - Documatic loads from the instance under the browser-level session. A token never enters a frame (AD-28, NFR-3), and the bundle's content-security policy names only the instance's origin (AD-47).
  - The picker chooses among enabled definitions. Moving the default marker stays a security change, and the egress chip and line follow the definition a turn uses (AD-42).

## UX & Interaction Patterns

- **The area is unspecified.** EXPERIENCE.md has no System Explorer area yet: no rail position, side-bar list or aliases.
  - The first story to add a screen adds its rail position, side-bar list, aliases and Fixed strings.
  - Every screen registers the 10-item screen contract. The side bar lists only built screens.
  - SQL activity's catalog row sits under OS management.
- **Code and tables.**
  - Source, XML, `.int`, query text and raw output render on `code-surface` in the monospace face. Identifiers are set in `code`.
  - Lists use the shared data-table: an APG grid with one Tab stop, `aria-activedescendant` and the max-rows footer.
  - The harvested grid's roving tabindex gives way to the portal's model (19.8). So does its CSV writer, in favor of the shipped Download CSV convention (inference).
  - The grid uses OcuPilot's design tokens only; lint refuses hardcoded colors.
- **Dialogs and confirmations.**
  - Dialogs are a closed set. Each new one (shortcuts help, go-to-row, the DML confirmation) joins EXPERIENCE.md's Dialogs line, and dialogs never stack.
  - A destructive action uses the one-level confirm dialog, which names the action and target and ends "This cannot be undone."
- **The editor** follows form-page conventions: a sticky Save and an unsaved-changes guard, which can also refuse an agent navigation. An ETag conflict is refused by name and never silently overwritten.

## Cross-Story Dependencies

- **19.1 comes first.** It lands the port, the slice, the area and the first descriptors, and every other story builds on them.
- **The guard is shared.** 19.6's third criterion and 19.11's second describe the same agent SQL tool behind the one guard. Whichever story introduces the tool wires it through the guard.
- **Data screens.** 19.7 and 19.8 can issue 19.5's declared catalog reads rather than write a second query (AD-5). 19.8 edits 19.7's grid.
- **New libraries.** Sprint planning flagged that 19.3 and 19.4 may need a new client library, such as an editor or a diff. Rule 5 applies: ask the owner first. Anything added is vendored, with no CDN (NFR-10).
- **Server files.** 19.2's import, and any server-side export file, name a server file through `PathPort` as a root plus a relative name, never a path (AD-21's sixth case, Story 18.1).
- **19.11** builds on the agent definitions and on 16.15's egress line.
- **Shipped machinery to reuse:**
  - governance (14.2);
  - the copy-out draft (14.1);
  - the sanitizer (14.3);
  - the read-back (16.17);
  - Download CSV (16.23).
- **Slot A.**
  - Use the `ocupilot-slot-a` profile and the `ocupilot-ci` throwaway (web 52776, SuperServer 1975). Run one test class at a time.
  - Epic 18 runs in parallel on slot B, so keep edits to shared files add-only:
    - the kernel, the registry, `Error.cls`, `Router.cls` and `Baseline.cls`;
    - the test rosters, `ci-throwaway.sh` and `ci.test.mjs`;
    - `strings.ts` and EXPERIENCE.md.
  - Regenerate `screens.generated.ts` and `ToolFields.cls`; never hand-merge them.
  - The ledger routes no items to this range.

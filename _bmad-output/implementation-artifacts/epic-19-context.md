# Epic 19 Context: Stage 3 - System Explorer over the Atelier API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Give developers a System Explorer inside OcuPilot, built on the IRIS Atelier API. Classes and routines can be listed, viewed, compiled, deleted, exported, imported and edited, with saves checked against the document's ETag. Code can be searched, compared and looked up by macro. The SQL catalog gets a query console behind a DML and DDL guard, and rows can be browsed and edited in a data grid harvested from iris-table-editor. Documatic, DocDB, SQL activity, and an agent picker with guarded agent SQL complete the stage. It is the first post-contest stage built on a new port, `Port/AtelierPort`. It reaches Atelier without ever handling the user's password and without modifying a vendor web application, it admits a `%Development` holder as the classic portal does, and it keeps the one screen contract every earlier stage followed.

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
- Story 19.12: A %Development holder reaches System Explorer, as the classic portal allows

## Requirements & Constraints

- **One contract (FR-80).** Each screen is declared by one descriptor and reaches outside through one port, and its read tool and write tools' field lists derive from that descriptor. Every agent write is a server-minted proposal with an instance-computed diff, an explicit confirmation and an agent marker. Every read is bounded and reports truncation, and every gate checks the caller's own privileges at call time. Acceptance is this contract plus each catalog row's backing route, over 36 rows: CP-36, OS-23, EX-02 to EX-34 and DT-01. Finer criteria are written at each story's plan, never invented in advance.
- **Backing routes.** Atelier routes are relative to `/api/atelier/v<N>/:ns`.
  - 19.1 (done): `GET docnames/CLS` and `docnames/RTN`; `GET doc/:name`, also with `?format=xml` and as `.int`; `POST action/index`.
  - 19.2: `POST action/compile`, with flags and streamed output; `DELETE doc/:name` and `DELETE docs`; the v7 routes `action/xml/export`, `xml/load` and `xml/list`; `PUT doc`.
  - 19.3: `PUT doc/:name` with the ETag.
  - 19.4: v2 `action/search`, v2 `getmacrodefinition` and `getmacrolocation`, and two document reads diffed in the client.
  - `POST action/query`: 19.5 (`INFORMATION_SCHEMA` and `CALL %SQL_Manager.Catalog`), 19.6 (`{query, parameters}` and `EXPLAIN`), 19.7 and 19.8 (the data browser), 19.10 (`INFORMATION_SCHEMA.CURRENT_STATEMENTS`; cancelling a statement is Stage 4).
  - 19.9: Documatic at `/csp/documatic/%25CSP.Documatic.cls`, and DocDB at `/api/docdb/v1/:ns`.
  - 19.12: no new route; it changes who passes the API's floor and which pairs each screen declares.
- **What gates the stage.**
  - `action/query` runs any statement type unguarded and applies no row limit, so the guard ships with the console. The row cap and the truncation report are OcuPilot's to apply.
  - XML export and load are v7 routes behind the port's version gate. The 2026.2 floor carries Atelier v8, so it never fires there.
  - Observe the ETag conflict on document `PUT` on a throwaway before building on it.
  - DocDB needs `%Service_DocDB` enabled. Report the requirement; never assume it.
- **Who gets in (19.12).** The classic portal admits a `%Developer` account to System Explorer: `/csp/sys` carries no resource; `ClassList`, `RoutineList`, `GlobalList` and `SQL/Home` declare `RESOURCE = "%Development"`, and `SQL/QButtons/RuntimeStats` `%Development:USE`. A `%Development`-only caller must reach System Explorer and be refused everywhere a classic `%Developer` is refused, proven with a real `%Developer`-only principal on the throwaway and a mutation restoring the old floor that reddens.
- **Governance (AD-22).** Every new write key gets its line in `Kernel/Governance/Baseline.cls` in the same change, and every new destructive key defaults to disabled. After 2026-10-04 the owner decides how other new keys enter.
- **Limits carried knowingly from the harvest.** Only single-column primary keys; the identifier pattern refuses delimited names; `rowsAffected` always reads 1; `%VID` offset paging re-reads earlier rows and runs a separate `COUNT(*)` per page, and a failed count shows zero rows.
- **Measure, never assume.** Take each pair set from the handler's own checks plus a purpose-built least-privileged role on the throwaway; never use `%Operator`. Read a classic page's `RESOURCE` in `irissys/`, never recall it.

## Technical Decisions

- **AD-61, the Atelier port.** `Port/AtelierPort` is the only class that names an `%Api.Atelier.*` class, and only through parameters. The literal `%Atelier` is forbidden under `src/` and `ui/`, comments included. The port calls `%Api.Atelier.v8`'s route methods in the caller's process, as the signed-in user, one route at a time. The browser never calls `/api/atelier`, nothing sends a Basic header, and JWT is never enabled on the vendor application.
  - **Gate first (AD-29), measured.** Before any vendor call: `%Development:USE`, and, per namespace at call time, READ on the resources of its routines and globals databases and of every database it maps code from except IRISSYS. The mapped set comes from the vendor-internal `findmappings^%R`, whose signature a test pins. The vendor alone is not enough: without `%Development:USE`, `GET doc` answers 200 with a soft error, and with a mapped code database's READ withdrawn, `docnames` answers 200 with no rows. A refusal names the failed pair and never reads as an empty list. Descriptors and the area declare `%Development:USE` alone; the database pairs live in the port's gate.
  - **Version.** The port calls `v<min(N, 8)>`. Each endpoint declares its minimum version (the port's `MINVERSIONS`), and an older instance is refused `PORT.NOTIMPLEMENTED`, naming both versions, before any call. This is 19.2's v7 gate.
  - **Stub CSP state.** `New %request, %response, %session, %SourceControl`, with query parameters seeded into `%request.Data` and trailing route arguments omitted. A route that checks the body's content type uses the port-owned `Port/AtelierRequest`.
  - **Namespace (AD-16).** Explicit save and restore around the vendor call only; the restore is the first line of every `Catch`, and no `OcuPilot.*` class is called while switched.
  - **Capture.** Output is captured so the route's envelope never reaches OcuPilot's response (AD-12); an answer above about 3.6 million characters is refused `PORT.UNAVAILABLE`. `action/index` is the one exception: under the capture it ends the process with signal 11, so its answer goes to a port-owned temporary file, read back under the same ceiling and deleted on every path with the device restored (`FILEDEVICEROUTES`). A later route that needs the file device is named in AD-61.
  - **Outcome from four places:** the `%Status`, `%response.Status`, the envelope's `status.errors` and the result's own `status`. A 404 is `PORT.NOTFOUND`, unlogged on a read; 400 is `PORT.VALIDATION`; `<PROTECT>` is `PORT.ACCESSDENIED`. Vendor text is logged, never sent (AD-39).
  - **Never** send `docnames`' `filter` parameter, which the vendor splices into SQL; the port filters parsed rows before the cap (AD-21, AD-36). **Never** call `POST modified`, which writes `^ISC.Src.Jrn` in every mapped database.
  - **Cost.** `docnames` may rebuild a stale `^rINDEX`, which AD-7 permits; `GET doc` runs the namespace's source-control hooks (inference).
  - A call Atelier cannot carry, such as DocDB, needs its own named entry in AD-61 or a new port, a spine amendment at that story's spec gate (inference).
- **The administrative floor (AD-8, decided; Story 19.12 implements it).** Before any route runs, the API refuses a caller holding no member of `Screen.Gate`'s `ADMINRESOURCES`; `Screen/Gate.cls` is that list's one home, and the router and `ProviderPort` derive from it. Until 19.12 ships the floor is `%Admin_*` alone, and a `%Developer`-only account cannot open System Explorer.
  - 19.12 widens it to any `ADMINRESOURCES` member or `%Development:USE`.
  - Every screen, route and tool that relied on the floor alone then declares its own pair matching its classic page's `RESOURCE`, unioned with any custom resource on that page (AD-44). Nothing past the floor may open what the classic portal refuses (DW-1853: Logs' analytics log opens for any caller past the floor, because `%DeepSee_Portal:USE` is public).
  - A `%Development`-only caller reaches the agent only through tools whose own pairs it holds; 19.12's spec states how `ProviderPort`'s floor changes.
  - An area opens when any listed screen's own gate passes, and each screen keeps its own gate (AD-8).
- **Reads (AD-36, AD-24).** One declared read serves both the screen and the tool, with the row cap and the context caps.
  - A `text` or `choice` criterion may declare a `default`. An omitted criterion takes it, and `criteria` reports it; one sent empty stays unset. `datetime` takes no `default`.
  - Source, XML and `.int` text is AD-36's screen-only `document`. It never reaches a tool's view or screen context. The agent reads structure rows, with `Description` cut at 1,000 characters and sanitized.
  - Query results and cell values are untrusted content to the model (AD-11, AD-60), and secret-typed fields never leave the instance.
- **Writes (AD-52, AD-53, AD-55).** A write tool declares `AtelierPort` as its port. A person's action and the agent's write are one operation with two callers.
  - The screen caller mints no proposal, emits no marker, and is not gated by read-only or the kill switch.
  - Both callers get the per-target lock (AD-34), the read-back (AD-58) and the change event (AD-14).
  - The port defines a `Snippet` mirroring every `Invoke` branch, or the registry test fails (AD-59).
  - Atelier and SQL writes have no admin API body template. Each tool's spec gate states and pins four things: its field-list derivation (AD-3), its target triple and canonical spelling (AD-13), its fingerprint subject (AD-6, AD-51, AD-54), and its read-back subject (inference).
- **SQL (AD-21).** Every caller value is bound. Table and column names cannot be bound, and validation never substitutes for binding, so the identifier path needs a named AD-21 case or names resolved against `INFORMATION_SCHEMA` first (inference). The console's statement is the caller's own SQL, governed by the guard (inference).
- **The DML and DDL guard.** One classifier on the instance serves both the console and the agent's SQL tool. A client-only check is not a gate, because write gates are evaluated at the write (AD-10, AD-40; inference).
  - In the console, a DML or DDL statement needs an explicit confirmation.
  - From the agent, it is an ordinary confirmed proposal.
  - Release 1 gave the agent catalog SELECTs only.
- **Streaming.** Handlers never write to the response (AD-12), and the only incremental channel is a turn's progress poll (AD-33). Streamed compile output therefore needs a stated transport (inference).
- **The iris-table-editor harvest.** Keep its call sites and never its names, and bridge `--ite-*` tokens to OcuPilot's tokens rather than adopting them.
  - Lift `SqlBuilder`, `DataTypeFormatter`, `UrlBuilder`, `ErrorHandler`, the model types, the token contract, `grid-styles.css` and the CSV helpers.
  - Port three algorithms out of `grid.js`: keyboard navigation; the filter row and tri-state sort; and staging with primary-key reconciliation and stale-index recovery. Delete its nine drifted formatter clones.
  - Rework its Atelier services behind a transport seam aimed at the OcuPilot API. They hardcode Basic, use Node-only `Buffer.from` and treat a 401 as terminal.
  - Never carry the plaintext-password-in-server-memory session.
- **Documatic and agent definitions.** Documatic loads from the instance under the browser-level session. A token never enters a frame (AD-28), and the content-security policy names only the instance's origin (AD-47). The picker chooses among enabled definitions. Moving the default marker stays a security change, and the egress chip and line follow the definition a turn uses (AD-42).

## UX & Interaction Patterns

- **The area (built by 19.1).** "System Explorer" is rail position 8, after Security and secrets; Agent co-pilot is 9, pinned at the bottom, and Home's seventh tile reads "Classes · Routines".
  - Its side bar lists Classes (1) and Routines (2). Each list's document viewer is an unlisted screen at `<list route>/document`, archetype `viewer (source)`, with five views: Source, XML, Intermediate code, Structure and Documentation (the index's description text; the full Documatic page is 19.9's).
  - The lists carry the classic filters as server criteria with declared defaults. "Look in: Database" is not carried: a database is reached through a namespace.
  - Prompts use the group "Code". Where later stories' screens sit is decided at each story's plan; the catalog files SQL activity under system operation.
- **Every screen** registers the 10-item screen contract, at least three suggested prompts, aliases and Fixed strings, and the side bar lists only built screens.
- **Line-cited documents.** Code cites EXPERIENCE.md and DESIGN.md by line number. Append Fixed-strings rows below the existing ones (System Explorer's start at EXPERIENCE.md :586), edit DESIGN.md only in place, and update every citation the suites hold, EXPERIENCE.md's own included (`npm run test:tools` names them).
- **Code and tables.**
  - Source, XML, `.int`, query text and raw output render as text on `code-surface` in `<pre tabindex=0>`, never as markup. Identifiers are set in `code`.
  - Lists use the shared data-table with the max-rows footer. The harvested grid's roving tabindex gives way to the portal's model, and its CSV writer to the shipped Download CSV convention (inference).
  - Use design tokens only; lint refuses hardcoded colors.
- **Dialogs** are a closed set: each new one (shortcuts help, go-to-row, the DML confirmation) joins EXPERIENCE.md's Dialogs line, and dialogs never stack. A destructive action uses the one-level confirm dialog naming the action and target.
- **The editor** follows form-page conventions: a sticky Save, and an unsaved-changes guard that can also refuse an agent navigation. An ETag conflict is refused by name and never silently overwritten.

## Cross-Story Dependencies

- **19.1 is done.** It landed `Port/AtelierPort` and `Port/AtelierRequest`, per-endpoint `MINVERSIONS`, `FILEDEVICEROUTES`, the criterion `default`, the area, and four read tools with no write tool and no governance key. Its named limit: a namespace listing more than about 3.6 million characters of document names is refused `PORT.UNAVAILABLE` (HSCUSTOM's classes use 1.83 MB).
- **19.12 runs next, before 19.2.** It is product-wide: `Screen/Gate.cls`, the router, `ProviderPort`, and an own pair on existing descriptors and tools in every area. Adding System Explorer moved the area rosters (`WireAreaAnyScreen`, `Wire`, `Navigation`, `rail-wire.spec.ts`, `navigation-wire.test.mjs`); a wider floor likely moves them too (inference).
- **Later screens** declare their own pair matching their classic page's `RESOURCE` from the start, rather than relying on the floor.
- **On `AtelierPort`:** 19.2 adds write endpoints, and its v7 gate uses `MINVERSIONS`; 19.3 uses the viewer read's `ts` as the ETag.
- **The guard is shared.** 19.6's third criterion and 19.11's second describe the same agent SQL tool behind the one guard; whichever story introduces the tool wires it through the guard.
- **Data screens.** 19.7 and 19.8 can issue 19.5's declared catalog reads rather than write a second query (AD-5), and 19.8 edits 19.7's grid.
- **New libraries.** 19.3 and 19.4 may need an editor or a diff library. Ask the owner first (Rule 5); anything added is vendored, with no CDN (NFR-10).
- **Server files.** 19.2's import, and any server-side export file, name a file through `PathPort` as a root plus a relative name, never a path (AD-21's sixth case).
- **19.11** builds on the agent definitions and on 16.15's egress line.
- **Shipped machinery to reuse:** governance (14.2), the copy-out draft (14.1), the sanitizer (14.3), the read-back (16.17) and Download CSV (16.23).
- **Bundle.** After 19.1 the initial bundle is 2,419,803 bytes against a 2,420 kB warning. A client story that exceeds it re-bases `maximumWarning` in `ui/angular.json` and `angular-json.test.mjs` to the measured size, and stops to ask above 3,800 kB.
- **Slot A.**
  - Use the `ocupilot-slot-a` profile. The throwaway is `ocupilot-a2-ci` (52780/1979, `/tmp/ocupilot-a2-ci`), which this epic's runner brought up and owns. `ocupilot-ci` is left for the owner: never load into it, restart it or tear it down. Run one test class at a time.
  - Story 23.3 runs on slot B, and Epic 18 is paused until it finishes, resuming with 18.16. Before editing a shared file, check both `.worktrees/epic-18` and `.worktrees/epic-23`.
  - Shared-file edits stay add-only: the kernel, the registry, `Error.cls`, `Router.cls`, `Baseline.cls`, the test rosters, `ci-throwaway.sh`, `ci.test.mjs`, `strings.ts` and EXPERIENCE.md.
  - Regenerate `screens.generated.ts` and `ToolFields.cls`; never hand-merge them.
  - The ledger routes DW-1903 to 19.12. DW-1905, whether to report the `index` crash to InterSystems, is the owner's; no story acts on it.

# Epic 19 Context: Stage 3 - System Explorer over the Atelier API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Give developers a System Explorer inside OcuPilot, built on the IRIS Atelier API. Classes and routines are listed, viewed, compiled, deleted, exported, imported and edited, and a save is checked against the ETag it read. Code can be searched, compared and looked up by macro. The SQL catalog gets a query console behind a DML and DDL guard, and rows are browsed and edited in a grid harvested from iris-table-editor. Documatic, DocDB, SQL activity, and an agent picker with guarded agent SQL complete the stage. It is the first post-contest stage built on a new port, `Port/AtelierPort`, which reaches Atelier in process as the signed-in user, never handles the user's password and never modifies a vendor web application. Like the classic portal, it admits a `%Development` holder who holds no administrative resource, and every screen keeps the one contract earlier stages followed.

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
- **Backing routes**, relative to `/api/atelier/v<N>/:ns`:
  - 19.2: `POST action/compile`, with its flags (`k`, `b`, `u`) and streamed output; `DELETE doc/:name` and `DELETE docs`; the v7 routes `action/xml/export`, `xml/load` and `xml/list`; `PUT doc` for imported source.
  - 19.3: `PUT doc/:name` carrying the ETag.
  - 19.4: v2 `action/search`, v2 `getmacrodefinition` and `getmacrolocation`, and two document reads diffed in the client.
  - `POST action/query`: 19.5 (`INFORMATION_SCHEMA` and `CALL %SQL_Manager.Catalog`), 19.6 (`{query, parameters}` and `EXPLAIN`), 19.7 and 19.8 (the data browser), 19.10 (`INFORMATION_SCHEMA.CURRENT_STATEMENTS`; cancelling a statement is Stage 4).
  - 19.9: Documatic at `/csp/documatic/%25CSP.Documatic.cls`, and DocDB at `/api/docdb/v1/:ns`.
- **What gates the stage.** `action/query` runs any statement type unguarded and applies no row limit, so the guard ships with the console, and the row cap and the truncation report are OcuPilot's to apply. XML export and load need Atelier v7; the 2026.2 floor carries v8, so that version gate never fires there. Observe the ETag conflict on document `PUT` on a throwaway before building on it. DocDB needs `%Service_DocDB` enabled: report the requirement, never assume it.
- **Who gets in.** A caller holding neither an `%Admin_*` resource nor `%Development` is shown "no administrative privileges on this instance", and the turn endpoint refuses them with the same message. A `%Development`-only caller reaches System Explorer and is refused everywhere a classic `%Developer` is refused.
- **Governance (AD-22).** Every new write key gets its line in `Kernel/Governance/Baseline.cls` in the same change, and every new destructive key (a delete) ships disabled. After 2026-10-04 the owner decides how other new keys enter.
- **Limits carried knowingly from the harvest.** Only single-column primary keys; the identifier pattern refuses delimited names; `rowsAffected` always reads 1; `%VID` offset paging re-reads earlier rows and runs a separate `COUNT(*)` per page, and a failed count shows zero rows.
- **Measure, never assume.** Take each pair set from the handler's own checks plus a purpose-built least-privileged principal on the throwaway, never `%Operator`. Read a classic page's `RESOURCE` in `irissys/`, never recall it.

## Technical Decisions

- **AD-61, the Atelier port.** `Port/AtelierPort` is the only class that names an `%Api.Atelier.*` class, and only through parameters; the literal `%Atelier` is forbidden under `src/` and `ui/`, comments included. It calls `%Api.Atelier.v8`'s route methods in the caller's process, as the signed-in user, one route at a time. The browser never calls `/api/atelier`, nothing sends a Basic header, and JWT is never enabled on the vendor application.
  - **Gate first (AD-29).** `%Development:USE`, then, per namespace at call time, READ on its routines and globals databases and on every database it maps code from except IRISSYS (from `findmappings^%R`, whose signature a test pins). Without them `GET doc` can answer 200 with a soft error and `docnames` 200 with no rows, so a refusal names the failed pair and never reads as an empty list. Descriptors and the area declare `%Development:USE` alone; the database pairs live in the port's gate.
  - **Version.** The port calls `v<min(N, 8)>`. Each endpoint declares its minimum in `MINVERSIONS`, and an older instance is refused `PORT.NOTIMPLEMENTED`, naming both versions, before any call. This is 19.2's v7 gate.
  - **Stub CSP state and namespace.** `New %request, %response, %session, %SourceControl`, query parameters seeded into `%request.Data`, trailing route arguments omitted, and `Port/AtelierRequest` where a route checks the body's content type. The namespace is switched by explicit save and restore around the vendor call only (AD-16), restored first in every `Catch`, with no `OcuPilot.*` call while switched.
  - **Capture.** Route output is captured so its envelope never reaches OcuPilot's response (AD-12). An answer above about 3.6 million characters is refused `PORT.UNAVAILABLE`, which a large export or compile log could reach (inference). `action/index` alone writes to a port-owned temporary file (`FILEDEVICEROUTES`), because under the capture it ends the process with signal 11, reproduced on a healthy instance. A later route that needs the file device is named in AD-61.
  - **Outcome from four places:** the `%Status`, `%response.Status`, the envelope's `status.errors` and the result's own `status`. A 404 is `PORT.NOTFOUND`, unlogged on a read and logged on a write; 400 is `PORT.VALIDATION`; `<PROTECT>` is `PORT.ACCESSDENIED`. Vendor text is logged, never sent (AD-39).
  - **Never** send `docnames`' `filter`, which the vendor splices into SQL; the port filters parsed rows before the cap. **Never** call `POST modified`, which writes `^ISC.Src.Jrn` in every mapped database.
  - A call Atelier cannot carry, such as DocDB, needs its own named entry in AD-61 or a new port, as a spine amendment at that story's spec gate (inference).
- **The API's floor (AD-8), shipped by 19.12.** Before any route runs, the API refuses a caller holding no member of `Screen.Gate.FloorResources()`: `ADMINRESOURCES` plus `%Development`, each at USE. `Screen/Gate.cls` is its one home. The router (`FLOORRESOURCES`), `ProviderPort` (`INVOKEPAIRS`, from `FloorPairSpec()`) and the turn's per-step check derive it at compile time, and `%Development` never joins `ADMINRESOURCES`. A `%Developer` with READ on the install namespace's code database opens Home, the Agent screens, System Explorer and the analytics log, and is refused everything else by a named pair.
  - Every new System Explorer screen, route and tool declares its own `%Development`-class pair, matching its classic page's `RESOURCE` and unioned with any custom resource on that page (AD-44). A write tool names in `CLASSICPAGES` each further classic page whose operation it performs.
  - An area opens when any listed screen's own gate passes, and each screen keeps its own gate.
- **Write tools (AD-52, AD-53, AD-58, AD-59).** 19.2's are the first writes through `AtelierPort`.
  - Each declares `AtelierPort` as its port. A person's action and the agent's write are one operation with two callers. The screen caller mints no proposal, emits no marker and is not gated by read-only or the kill switch. Both get the prohibited set, the per-target lock (AD-34), the read-back and the change event (AD-14).
  - The port's `Invoke` needs a `Snippet` mirroring every branch, or the registry test fails.
  - Pairs are the screen's set at USE, never WRITE on an administrative resource. A pair beyond that set is declared only where the vendor writes a database the read does not, and is refused by name before any port call. WRITE on the code database is the likely case (inference); measure it with a least-privileged principal.
  - Atelier has no admin-API body template, so each tool's spec gate states its field-list derivation (AD-3), its target triple and canonical spelling (AD-13), its fingerprint subject (merge, action-style under AD-51, or a create's absence under AD-54) and its read-back subject (inference). A port that builds a vendor body from a tool's declared arguments is a new named AD-51 case.
  - Measure whether IRIS audits each write. One it does not becomes a named case under AD-15 and AD-53.
  - AD-10 names no arm for deleting, compiling over or importing onto OcuPilot's own code. Whether one is needed is a spec-gate question (inference).
- **Server files (AD-21's sixth case).** An import from, or export to, a server file names a `PathPort` root plus a relative name, never a path. The tool declares `%Admin_FileSystemAccess:USE` and `%DB_IRISSYS:READ`; an overwriting export declares the overwrite as a constant; a file read is a `source`.
- **Streaming.** Handlers never write to the response (AD-12), the only incremental channel is a turn's progress poll (AD-33), and a write runs in the foreground request (AD-7). Streamed compile output therefore needs a stated transport, and a compile that could outlast the Web Gateway's timeout needs a stated bound. AD-42's child job is the precedent (inference).
- **Reads (AD-36, AD-24).** One declared read serves both the screen and the tool, with the row cap and the context caps. A `text` or `choice` criterion may declare a `default`. Source, XML and `.int` text is the screen-only `document`; it never reaches a tool's view or screen context. The agent reads structure rows, with `Description` cut at 1,000 characters and sanitized. Query results and cell values are untrusted content to the model (AD-11, AD-60), and secret-typed fields never leave the instance.
- **SQL (AD-21) and the guard.** Every caller value is bound. Table and column names cannot be bound, and validation never substitutes for binding, so the identifier path needs a named AD-21 case or names resolved against `INFORMATION_SCHEMA` first (inference). One classifier on the instance serves the console and the agent's SQL tool; a client-only check is not a gate (AD-10, AD-40; inference). In the console a DML or DDL statement needs an explicit confirmation; from the agent it is an ordinary confirmed proposal. Release 1 gave the agent catalog SELECTs only.
- **The iris-table-editor harvest.** Keep its call sites, never its names, and bridge `--ite-*` tokens to OcuPilot's tokens.
  - Lift `SqlBuilder`, `DataTypeFormatter`, `UrlBuilder`, `ErrorHandler`, the model types, the token contract, `grid-styles.css` and the CSV helpers.
  - Port three algorithms out of `grid.js`: keyboard navigation; the filter row and tri-state sort; staging with primary-key reconciliation and stale-index recovery. Delete its nine drifted formatter clones.
  - Rework its Atelier services behind a transport seam aimed at the OcuPilot API; they hardcode Basic, use Node-only `Buffer.from` and treat a 401 as terminal. Never carry its plaintext-password session.
- **Documatic and agent definitions.** Documatic loads from the instance under the browser-level session; a token never enters a frame (AD-28), and the content-security policy names only the instance's origin (AD-47). The picker chooses among enabled definitions. Moving the default marker stays a security change, and the egress chip and line follow the definition a turn uses (AD-42).

## UX & Interaction Patterns

- **The area.** "System Explorer" is rail position 8; Agent co-pilot is 9, pinned at the bottom. Its side bar lists Classes and Routines, each with an unlisted viewer at `<list route>/document` (Source, XML, Intermediate code, Structure, Documentation). Home's tile reads "Classes · Routines", and prompts use the group "Code". Where later screens sit is decided at each story's plan; the catalog files SQL activity under system operation.
- **Every screen** registers the 10-item screen contract, at least three suggested prompts, aliases and Fixed strings, and the side bar lists only built screens.
- **Line-cited documents.** System Explorer's Fixed-strings rows are EXPERIENCE.md :586 to :588; append new rows after :588. Edit DESIGN.md only in place, and update every citation the suites hold, EXPERIENCE.md's own included (`npm run test:tools` names them).
- **Code and tables.** Source, XML, `.int`, query text and compile output render as text on `code-surface` in `<pre tabindex=0>`, never as markup, with identifiers set in `code`. Lists use the shared data-table with the max-rows footer. The harvested grid's roving tabindex gives way to the portal's model, and its CSV writer to the shipped Download CSV (inference). Design tokens only.
- **Dialogs** are a closed set (EXPERIENCE.md :173). Each new one (a document delete, an import, shortcuts help, go-to-row, the DML confirmation) joins it, and dialogs never stack. A destructive action uses the one-level confirm dialog naming the action and target.
- **The editor (19.3)** follows form-page conventions: a sticky Save, and an unsaved-changes guard that can also refuse an agent navigation. An ETag conflict is refused by name, never silently overwritten.

## Cross-Story Dependencies

- **19.1 (done)** landed `Port/AtelierPort`, `Port/AtelierRequest`, `MINVERSIONS`, `FILEDEVICEROUTES`, the criterion `default`, the area and four read tools, with no write tool and no governance key. Its named limit: a namespace listing more than about 3.6 million characters of names is refused `PORT.UNAVAILABLE` (HSCUSTOM's classes use 1.83 MB). `ExplorerDescriptor.TestTheAreaIsReadOnly` asserts the area has only its four reads and no baseline key: 19.2 trips it on purpose and replaces it, never deletes it.
- **19.12 (done)** widened the floor; its audit of every descriptor, tool and route found that no existing surface needed a new pair. `Test.DeveloperFloor`, `DeveloperFloorRoutes` (GET routes only) and `DeveloperFloorTurn` pin a real `%Developer` principal to 4 areas, 10 screens, 10 tools and 29 routes. Every later screen, tool and route joins those rosters, so their counts move. A test class that arms principals needs its `# classes:` line in `scripts/ci-throwaway.sh`.
- **19.2 is next.** It owns DW-1922: the Routines list shows routines its viewer answers `PORT.NOTFOUND` for (`EnsJob.mac` in HSCUSTOM, `Ens*.mac` in USER), and `DeveloperFloor`'s USER own-database assertion rests on those rows.
- **On `AtelierPort`:** 19.3 uses the viewer read's `ts` as the ETag; 19.4 adds search and macro lookup; 19.5 to 19.8, 19.10 and 19.11 go through `action/query`.
- **The guard is shared.** 19.6's third criterion and 19.11's second describe the same agent SQL tool behind one guard; whichever story introduces the tool wires it through the guard.
- **Data screens.** 19.7 and 19.8 can issue 19.5's declared catalog reads rather than write a second query (AD-5), and 19.8 edits 19.7's grid.
- **New libraries.** 19.3 and 19.4 may need an editor or a diff library. Ask the owner first (Rule 5); anything added is vendored, with no CDN.
- **19.11** builds on the agent definitions and on 16.15's egress line. Reuse shipped machinery: governance (14.2), the copy-out draft (14.1), the sanitizer (14.3), the read-back (16.17) and Download CSV (16.23).
- **Bundle.** The initial bundle measured 2,419,803 bytes at 19.1 against a 2,420 kB warning. A client story that exceeds it re-bases `maximumWarning` in `ui/angular.json` and `angular-json.test.mjs` to the measured size, and stops to ask above 3,800 kB.
- **Slot A.**
  - Use the `ocupilot-slot-a` profile. The throwaway is `ocupilot-a2-ci` (52780/1979, `/tmp/ocupilot-a2-ci`), brought up and owned by this epic's runner; `ocupilot-ci` was torn down on the owner's instruction. Run one test class at a time.
  - Story 23.3 is running on slot B, and Epic 18 is paused until it finishes, resuming with 18.16. Before editing a shared file, check both `.worktrees/epic-18` and `.worktrees/epic-23`.
  - Shared-file edits stay add-only: the kernel, the registry, `Error.cls`, `Router.cls`, `Baseline.cls`, the test rosters, `ci-throwaway.sh`, `ci.test.mjs`, `strings.ts` and EXPERIENCE.md. Regenerate `screens.generated.ts` and `ToolFields.cls`; never hand-merge them.
  - DW-1905, whether to report the `index` crash to InterSystems, is the owner's; no story acts on it.

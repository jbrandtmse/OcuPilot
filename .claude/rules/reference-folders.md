# `irislib/`, `irissys/`, `irisui/`, `irisdocs/` are read-only reference material

These top-level folders are **exports pulled out of the `ocupilot` IRIS container** (and, for `irisdocs/`, a mirror of the official documentation)
(`intersystems/irishealth-community:latest-cd`, IRIS for Health 2026.2 build 221U). They exist so
the InterSystems system code and the portal's Angular bundles can be read and searched as reference. They are gitignored and are **not**
this project's source.

| Folder | What it holds | How it was produced |
| --- | --- | --- |
| `irislib/` | Every source document in the `HSCUSTOM` namespace — 13,659 files: `%`-system classes (IRISLIB), `HS.*`, `Ens.*`, `EnsLib.*`, routines/includes, DTL/BPL/HL7/X12 definitions | `iris_doc_export` (MCP), source documents only (no generated `.int` stubs) |
| `irissys/` | Every source document in `%SYS` (4,167 files) plus, under `irissys/_csp-static/`, the CSP/static web trees the Atelier API cannot serve | `iris_doc_export` + `tar` out of the container |
| `irisdocs/` | Offline mirror of the **official InterSystems documentation for the `%Api` package** — 19 DocBook guide pages and 45 Documatic class-reference pages as Markdown (raw HTML under `irisdocs/html/`); `irisdocs/README.md` is the index | `scripts/fetch-irisdocs.py` from docs.intersystems.com, falling back to the container's own Documatic for classes the website does not publish (`%Api.InteropEditors.v7.*`) |
| `irisui/` | The twelve Angular apps that form the non-Zen parts of the portal — production bundles (no source maps), `irisui/README.md` explaining how IRIS serves and maps them, and `irisui/_analysis/inventory.json` (selectors, routes, endpoints per app) | `tar` out of `/usr/irissys/ui/interop` and `/usr/irissys/csp/hslib/ui` |

## Rules

- **Do not modify anything in these folders.** Treat every file as read-only.
- **Do not load, import, compile, promote, or sync them into IRIS.** Never point `iris_doc_load`,
  `iris_doc_put`, `iris_doc_compile`, `iris_doc_xml_export` (import), `iris_env_promote`, or the
  VS Code ObjectScript extension's import/sync at these paths. They are InterSystems-owned system
  classes; writing any of them back would overwrite the instance's own code. (This is also why
  `objectscript.conn.active` is kept `false` — see the README's `externalServer` section.)
- **They are not "the codebase".** When looking for this project's own code, search only the
  project folders or exclude these four (`grep --exclude-dir=irislib --exclude-dir=irissys
  --exclude-dir=irisui --exclude-dir=irisdocs …`). Do not "fix" anything found inside them.
- **They are snapshots — the running instance is authoritative.** `irissys/` was exported *before*
  the container was wiped and recreated on 2026-09-07, so some `%SYS` classes there may reflect a
  recompiled state; `irislib/` and `irisui/` were unaffected by that reset but can still drift. When
  exact current behavior matters, query the instance through the IRIS MCP servers with
  `server: "ocupilot-slot-a"` (see `CLAUDE.md`).
- **Hidden classes are absent.** The Atelier document list omits classes marked `[ Hidden ]`, so
  e.g. `EnsPortal.Util.PageLinks` is not in `irislib/`. Fetch such a class from the instance with
  `%Compiler.UDL.TextServices.GetTextAsString` via `iris_execute_command`; the one copy already made
  lives in `irisui/_analysis/`.
- **Regenerate, don't hand-edit.** `irislib/`: `iris_doc_export` on `HSCUSTOM` with
  `system: "true"`, per category, `overwrite: "ifDifferent"`. `irissys/`: same on `%SYS`, then the
  `tar` commands in `irisui/README.md` for the static trees. `irisui/`: the two `tar` commands in
  `irisui/README.md` → *Regenerating this folder*. `irisdocs/`: `python3 scripts/fetch-irisdocs.py`.

## Where the official `%Api` documentation is

`irissys/%Api/` holds the dispatch classes behind IRIS's built-in `/api/*` web applications
(`Atelier` v1–v8, `Monitor`, `Mgmnt` v2, `DocDB` v1, `DeepSee`, `IAM` v1, `InteropEditors` v1–v7,
`InteropMetrics` v1, `iKnow`). The exported source is handy for reading `UrlMap`s and OpenAPI
`spec` classes, but the **official documentation is on docs.intersystems.com** — and every page
listed below is **already mirrored locally**: guides in `irisdocs/guides/<KEY>.md`, class reference in
`irisdocs/classref/<Class>.md`, index in `irisdocs/README.md`. **Read the local copy first**; go online
only for pages that are not mirrored.

**Class reference (Documatic)** — one URL pattern serves every class; replace the `CLASSNAME`
value and write `%` as `%25`:

```text
https://docs.intersystems.com/irislatest/csp/documatic/%25CSP.Documatic.cls?LIBRARY=%25SYS&CLASSNAME=%25Api.Atelier
```

Use `irisforhealthlatest` instead of `irislatest` for the IRIS for Health edition (identical
classes). The **same reference is served offline by the container** — exact for the installed
build — at `http://localhost:52774/csp/documatic/%25CSP.Documatic.cls?LIBRARY=%25SYS&CLASSNAME=%25Api.Atelier`
(`_SYSTEM` / `SYS`).

**Which `/api/*` app maps to which `%Api.*` class** — the "InterSystems IRIS Built-In Web
Applications" table in the System Administration Guide:
`https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GSA_manage_applications`

**Per-API guides** (`https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=<KEY>`):

| Web app | Dispatch class | Guide page (`KEY=`) |
| --- | --- | --- |
| `/api/atelier` | `%Api.Atelier`, `%Api.Atelier.v1`…`v8` | **Source Code File REST API Reference** `GSCF_ref`; tutorial `GSCF_tutorial`. The endpoints keep the name "atelier" from the retired Eclipse IDE; the VS Code extension and the IRIS MCP servers use this API. |
| `/api/monitor` | `%Api.Monitor` | **Monitoring InterSystems IRIS via REST** `GCM_rest` — `/metrics` (Prometheus/OpenMetrics), `/alerts`, `/interop/…` |
| `/api/mgmnt` | `%Api.Mgmnt.v2` (`.disp`/`.impl`/`.spec`) | **Creating REST Services** `GREST` → discovery `GREST_discover_doc`, endpoint reference `GREST_reference`, create/delete `GREST_mgmnt` |
| `/api/docdb` | `%Api.DocDB`, `%Api.DocDB.v1` | **Using Document Database → REST Client Methods** `GDOCDB_rest` (requires `%Service_DocDB` enabled) |
| `/api/deepsee` | `%Api.DeepSee` (+ `%DeepSee.REST.v3`) | **Business Intelligence REST API** `D2CLIENT_rest_api`; using it `D2CLIENT_intro` |
| `/api/iam` | `%Api.IAM.v1` | **InterSystems API Manager** `PAGE_apimgr` (the endpoint only handles the IAM license handshake) |
| `/api/interop-editors` | `%Api.InteropEditors`, `.v1`…`.v7` | **No guide exists** — class reference only; the web-apps table calls it the "Rule Editor REST API". Read the OpenAPI 2.0 spec from `irissys/%Api/InteropEditors/v7/spec.cls` — **not** live: `impl.cls` deliberately hides the spec, so `GET /api/mgmnt/v2/%25SYS/%25Api.InteropEditors.v1`…`v7` all return `ERROR #8753: REST application not found`, even though the `/api/mgmnt/v2/%25SYS/` listing advertises a `swaggerSpec` URL for each. |
| `/api/monitor/interop` (routed by `/api/monitor`, which recurses — there is no separate web app) | `%Api.InteropMetrics.v1` | Class is marked *deprecated*; its functionality is documented under `GCM_rest` |
| `/api/iknow` | `%Api.iKnow` | Deprecated NLP API — class reference only |

`/api/admin` (`%Api.Admin`) exists as a web app on the instance but is neither in the `%SYS`
export nor in the documentation index; treat it as undocumented/internal.

A **spec-based** REST service's OpenAPI document can be pulled from the running instance with
`GET http://localhost:52774/api/mgmnt/v2/%25SYS/<spec class>` (see `GREST_reference`) — verified for
`%Api.Mgmnt.v2`, `%Api.IAM.v1` and `%Api.InteropMetrics.v1`. It does **not** work for hand-coded
`%CSP.REST` services, which have no `RESTSpec`: `%Api.Atelier`, `%Api.Admin`, `%Api.Monitor`,
`%Api.DeepSee`, `%Api.DocDB` and `%Api.iKnow` are absent from the v2 listing and return 404. For the
admin API use the v1 form instead: `GET /api/mgmnt/v1/%25SYS/spec/api/admin`.

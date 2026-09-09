# Harvest map — iris-table-editor (OcuPilot Stage 3)

Repo `/Users/jbrandt/git/iris-table-editor` v0.2.3, npm workspaces. 91 `.ts` (~39.7k lines) + ~10.9k lines vanilla JS/CSS in `packages/webview`.

**The single best fact:** `@iris-te/core` is a true leaf — no `dependencies` block at all, no host package depends on another host package. Clean star graph.

## Lift as-is (zero host coupling)

| Path | Lines | API |
|---|---|---|
| `packages/core/src/utils/SqlBuilder.ts` | 201 | `validateAndEscapeIdentifier`, `validateNumeric`, `parseQualifiedTableName`, `escapeTableName`, `buildFilterWhereClause(filters,schema)→{whereClause,filterParams}`, `buildOrderByClause`. Wildcard `*`→`%`, `?`→`_`, `LIKE ? ESCAPE '\'`, AND-joined, unknown columns dropped. Injection guards included. |
| `packages/core/src/utils/DataTypeFormatter.ts` | 338 | 9 fns: IRIS date/time/timestamp/numeric parse+format round trips. `ITimeParts`, `ITimestampParts`, `INumericParseResult`. |
| `packages/core/src/utils/UrlBuilder.ts` | 88 | `UrlBuilder.buildBaseUrl/buildQueryUrl/encodeNamespace/buildEndpointUrl`. Carries the `%SYS`→`%25SYS` encoding gotcha. |
| `packages/core/src/utils/ErrorHandler.ts` | 256 | `parse(unknown,context)`, `createError(code,context,msg?)`, 10-code `ErrorCodes` taxonomy, Atelier `status.errors` parsing. |
| `packages/core/src/models/*.ts` (not `IMessageBridge.ts`) | ~650 | `IColumnInfo`, `ITableSchema`, `ITableRow`, `ITableDataResult`, `IServerSpec`, `IFilterCriterion`, `SortDirection`, `IUserError`. |
| `packages/webview/src/theme.css` | 135 | The 84-token `--ite-*` contract. Bridge = one `:root` block defining `--ite-theme-*` from OcuPilot tokens. |
| `packages/webview/src/grid-styles.css` | 2064 | 258 `var(--ite-*)` uses, zero definitions. Cell-state rules: `--saving` pulse (1042), `--save-success` (1005+), `--error`, new-row states (921/927/938). |

Also portable: `csvEscapeValue`, `generateCsvContent`, `downloadCsv` (Blob + UTF-8 BOM), `_parseCsv`, `_convertExcelValue`.

Only non-portable line in core: `Buffer.from` at `AtelierApiService.ts:298`.

## The three grid algorithms to port (`packages/webview/src/grid.js`, 6023 lines, IIFE)

| Concern | Lines | Contents |
|---|---|---|
| Keyboard nav | **3358–3553** `handleCellKeydown` | arrows, Tab/Shift+Tab with row wrap, Home/End, Ctrl+Home/End, PageUp/Down (`getVisibleRowCount` 3554–3572), F2/Enter→edit, Delete→empty, Backspace→edit-cleared, Ctrl+Shift+N→NULL, Space→toggle bool, printable→overwrite |
| | 5894–6011 `handleKeyboardNavigation` | document-level shortcuts (Ctrl+N/-/D/S/E/F/G, F5, F1) |
| | 3224–3357 | `getCellElement`, `selectCell(r,c,focus)` (scrollIntoView + roving tabindex), `handleCellClick` |
| | 3053–3150 `handleEditInputKeydown` | Enter commit+down, Tab commit+right, Escape cancel |
| Filters | 3681–3809 `renderFilterRow` · 3810–3843 `applyFilter` · 3845–3939 clear/toggle · 3940–3955 `requestFilteredData` · 3956–4000 `handleColumnSort` (tri-state) · 4001–4124 filter panel chips · 20–166 `AppState.filters: Map`, `getFilterCriteria()` | server half already free in `SqlBuilder` |
| Staging / dirty cells | **20–166** `class AppState`: `pendingSaves: Map<"pk:col",{rowIndex,colIndex,columnName,oldValue,newValue,primaryKeyValue}>`, `newRows`, `editingCell` | |
| | 587–666 `saveCellValue` (optimistic write) · 1597–1834 `exitEditMode` · 1857–1904 `rollbackCellValue` · 1905–1927 `showSaveSuccess` · **1928–2005 `handleSaveCellResult`** (PK-keyed reconciliation, stale-index recovery after pagination 1949–1966, refetch-when-filtered 1979–1987) · 1835–1856 `findPrimaryKeyColumn` · 2556–2890 new-row staging · 5587–5599 Map rehydration | |

`grid.js` carries **9 hand-copied clones** of `DataTypeFormatter.ts` (lines 229, 715, 771, 794, 854, 895, 918, 952, 1011) — drifted. Delete on port.

## Atelier services — rework required

`AtelierApiService.ts` (304) · `QueryExecutor.ts` (381) · `TableMetadataService.ts` (290).

Only **two endpoints**: `GET {base}` (root descriptor; also `getNamespaces`) and `POST {base}/v1/{ns}/action/query` with `{query,parameters}`. Everything is SQL. Tables = `INFORMATION_SCHEMA.TABLES`, schema = `INFORMATION_SCHEMA.COLUMNS` (`IS_IDENTITY='YES'`→readOnly+PK, `IS_GENERATED='YES'`→readOnly). Paging via IRIS `%VID` in a `SELECT TOP` subquery (`QueryExecutor.ts:88-102`), plus a **separate `SELECT COUNT(*)` per page**.

Breaks under OcuPilot's JWT-less Atelier model:
- Basic hardcoded at `AtelierApiService.ts:293-303`; `(username,password)` positional on ~9 public methods; no auth seam.
- `Buffer.from` — Node-only, breaks a browser build.
- 3 raw `fetch` calls (`AtelierApiService.ts:79,:190`, `TableMetadataService.ts:43`); no interceptor, no `credentials:'include'`.
- 401 terminal → `AUTH_FAILED`; `AUTH_EXPIRED` exists but is never emitted. No refresh hook.
- `TableMetadataService.getNamespaces` (36–115) bypasses `AtelierApiService` and calls `fetch` directly — consolidate first.

Seam: inject a headers-provider / `IAtelierTransport.post(url,body)`. ~9 signatures; SQL and parsing bodies untouched.

## Discard (~24k lines host code + ~24k lines host tests)

`packages/vscode/**` (`GridPanelManager.ts` 2043 lines mixes vscode UI + webview HTML/CSP + export/import + exceljs), `packages/desktop/**`, `packages/web/**`, `packages/webview/src/main.js`, `*ThemeBridge.css`, `*MessageBridge.js`, `preload.ts`.

Read before deleting: `packages/web/src/server/commandHandler.ts` (462) — its `ServiceFactory` / `ConnectionContext` seam is the closest thing to the DI shape Angular wants.

**Do not carry forward:** `packages/web/src/server/sessionManager.ts:57` keeps the plaintext password in server memory keyed by an HTTP-only cookie.

Stranded logic worth rebuilding: `ServerConnectionManager.ts:48-50` `_schemaCache` (1h TTL) trapped in the VS Code host.
